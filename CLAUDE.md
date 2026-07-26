# CLAUDE.md — TURNSTILE

TURNSTILE is an **authorization firewall for AI agents that spend money**. Every payment enters as a Jac **walker** and traverses a chain of **gate nodes**; failing a gate calls `disengage`, so the payment dies at the gate that killed it and **that node is the audit record**. Arithmetic gates are free and instant; the `IntentMatchGate` asks the question no rule can — *does this cart honor the mandate the human actually signed?* Built for **JacHacks SF 2026** (one-day, Founders Inc.; partial submission **5:50 PM PT**, hard deadline **7:15 PM PT**). Pitch: *"We gave an agent a credit card and said groceries under $200. Here's a charge that passes every rule your bank checks — and should never have happened."*

## Commands
```bash
cd turnstile
cp .env.example .env                      # set ONE key: OPENAI_API_KEY (or ANTHROPIC/GEMINI)
jac run smoke.jac                         # end-to-end, ZERO LLM calls — run after EVERY change
jac run main.jac                          # full demo run (needs a key)
jac start gates.jac --port 8000           # walkers become REST endpoints
python3 scripts/seed.py                   # regenerate synthetic graph + attack corpus
```
`jac` is at `~/.local/bin/jac`. **byLLM is bundled with the binary — do NOT `pip install byllm`.**

## Repo map
- `turnstile/schema.jac` — nodes, typed edges, the self-metering `Funds` edge. Owner: GraphArchitect lane.
- `turnstile/gates.jac` — `walker Payment` + gate chain + `disengage`. The heart. Must run with zero LLM calls.
- `turnstile/tribunal.jac` — `by llm(tools=[...])` adjudicator, `on_iteration` budget, `ModelPool`, convergence rule.
- `turnstile/probe.jac` — adversarial red-team agent (`conversation=` memory) + the 6-attack ladder.
- `turnstile/memory.jac` — `Precedent` read/write + fingerprinting (the zero-token fast path).
- `turnstile/scripts/seed.py` — synthetic graph, payment corpus, OFAC cache. stdlib only, no network at runtime.
- `turnstile/web/demo_case.json` — pre-recorded result; the UI's last-resort fallback.
- `TURNSTILE.md` — **product + demo source of truth.** Design disputes resolve here.
- `README.md` — event rules, judging criteria, deadlines. `killBill/` + `Sentinel/` — prior-event reference projects (read-only).

## Jac 0.34.6 — verified facts (do NOT rediscover these)
- **Version is 0.34.6**, and `jac` on this machine runs in **dev mode against the local compiler source** at `jac/jac/` (every invocation prints `🛠 jac dev mode`). If that repo is pulled or the demo runs on another machine, behavior changes. Re-verify on the demo machine.
- **Import is `import from jaclang.byllm.lib { Model }`** — NOT `byllm.lib`. killBill targeted 0.15 and its `audit.jac:12` is stale. Iteration types: `import from jaclang.byllm.types { IterationAction, IterationContext }`.
- **`jac run` requires a `jac.toml` in the directory.** `jac build` errors with "needs a project" without one.
- **`disengage` is ONLY valid inside a walker ability** (`error[E2083]`). In a node ability it falls back to the server codespace and *appears* to work, because the block path and the no-visit path are observationally identical. Traversal control belongs in the walker.
- **Node-type filter is `[-->][?:Type]`.** Backtick forms (`` (`?Type) ``) are gone in 0.34.6 — `error[E0105]: Unexpected character`.
- **Typed-edge traversal is single-arrow**: `[->:Escalates:->]`, not `-->:Escalates:-->`.
- **In a node ability, the type names the WALKER, not the node**: `can screen with Payment entry`.
- **A walker subtype fires base-typed abilities** — `walker Payment(Metered)` runs `can meter with Metered entry`. This is how schema.jac's `Funds` edge meters a walker declared in gates.jac without an import cycle.
- **`on_iteration` is a NO-OP without `tools=`** (verified by probe wiring test: hook fired 0 times). It caps ReAct iterations *within a single call*, not attempts *across* calls. Do not claim on stage that an agent "ran out of budget mid-thought" across retries — a Jaseci judge knows what it does, and that is the one place you cannot afford a credibility hit.
- **LLM-guided traversal exists**: `visit [-->] by llm(intent="...", select=1)`. The model is shown each successor as an **(edge, node) pair** and picks the next hop; walker state and current node are injected automatically. Documented at `jac/docs/docs/reference/plugins/byllm.md:2558`. Almost nobody knows this exists — it makes routing itself a model decision.
- **`jac create <name> --kind web-app`** works (~865ms, bun present). But there is **no `pages/` dir and no `JsxPage`** — the real API is `main.jac` with a `cl { }` codespace, `frontend.cl.jac` exporting `def:pub app -> JsxElement`, `endpoints.sv.jac` for server, and `[serve] base_route_app = "app"` in jac.toml. Copy the scaffold verbatim; do not write from a description.
- **Plain `visit [-->]` crosses edges WITHOUT firing their abilities.** Only `visit [edge -->]` (or spawning on an edge) wakes them. Get this wrong and the `Funds` edge accounting silently no-ops — no error, just wrong numbers. Verified: `jac/docs/docs/reference/language/osp.md:215-222`.
- **Node-level LLM methods compile**: `node G { def judge(c: dict) -> Ruling by llm(); }` — proven by compile spike, not assumed.
- **Typed edge endpoints work**: `edge Funds: Treasury --> AgentIdentity { has cap: float; }` (`osp.md:248`).
- `visitor`, `here`, and edge abilities all compile at 0.34.6.
- `Model(model_name=...)` constructs at glob scope **without** an API key present — only invocation needs one. This is why Layer-2 degradation works.

## Interface contract (change it in every module in the SAME commit, or don't change it)
```jac
walker Payment {
    has payment_id: str, amount: float, cart: dict, merchant: str, agent_handle: str,
        verdict: str = "OK", halted_at: str = "", reason: str = "",
        signals: list[str] = [], tokens_used: int = 0;
}
obj Ruling { has blocked: bool, uncertain: bool, reason: str, confidence: float; }
```
Gate contract: on failure set `verdict`/`halted_at`/`reason` then `disengage`. On pass append to `signals` then `visit [-->]`. `halted_at` is the gate's node name and is the primary audit field — never leave it empty on a block.

## Persistence laws (this is the #1 way the demo dies on stage)
- **The seed MUST be idempotent.** `root` persists across runs, so an unguarded seed builds an Nth parallel gate chain on run N and the walker traverses *all* of them — every gate fires N times, the LLM gate costs N×, the scoreboard is nonsense. Guard: `existing = [root -->][?:CapGate]; if existing { ... return existing[0]; }`.
- **Windowed counters must reset on reuse.** `VelocityGate.seen` is mutable state on a *persisted* node; it accumulated 3→6→9 across runs and blocked a payment that should pass. A new run is a new window. **This surfaced on run 3, never in dev** — which means on stage, not in rehearsal.
- **Always verify with 4 consecutive runs**, not one. Both bugs above are invisible on run 1.
- If you rename or move a node class, every persisted anchor of the old class quarantines noisily on startup (`Refused to deserialize unregistered class`). `demo.sh` must clear `.jac/data/` and re-seed; rehearse from that script.

## Design laws — non-negotiable
- **The deterministic gate chain must run standalone with ZERO LLM calls.** Every agentic layer is additive. This is the demo-safety floor; if it ever needs a key to run, that's a bug.
- **Convergence rule (from Sentinel):** escalate to `BLOCKED` only on **2+ independent corroborating signals**. A single signal returns `REVIEW`, never a block. One agent's opinion is not a verdict.
- **Count LLM CALLS, never tokens.** A token count returned inside an LLM-generated `Ruling` is a number the model invented. Report "LLM calls avoided" (an integer you can count) plus wall-clock latency.
- **Precedent is the zero-call fast path.** A fingerprint hit blocks with no LLM call. The "it learned" moment must be *measured* on stage and shown as a persistent two-row ledger (first pass above, replay directly below) — a number that changes while you talk is missed by everyone.
- **Attack #5 in the ladder must legitimately PASS.** A system that blocks everything proves nothing. Cutting the passing case destroys credibility.
- **Deterministic where determinism belongs** (killBill's real lesson): cap/velocity/sanctions are arithmetic. Do not spend tokens on comparisons.
- **The graph must be load-bearing — and the gate chain does NOT prove it.** A linear 5-gate chain is a `for` loop in a costume; 5 of 7 subsystems survive replacing the graph with a list. Only two are genuinely graph-shaped: **`trace_provenance`** (unbounded reachability from a charge back to a live principal) and **revocation blast radius** (delete one edge, which set goes dark). Both are ~20 lines each and are **NEVER-CUT**. Lead the demo with *"legal at every hop, authority broken two hops upstream"* — not "watch it travel the gates".
- **Say six load-bearing constructs, not twelve.** A judge who probes six and finds six real is worth far more than one who probes twelve and finds the third is a config flag.

## Honesty rules (judges include people who built these tools)
- Never state a latency, token count, or block rate that wasn't measured in this repo on this machine.
- Anything pre-computed for the demo (cached precedents, pre-authored attacks, `demo_case.json`) is **disclosed unprompted** in the pitch. Never passed off as live.
- Market statistics from research were flagged **medium-confidence** (search summaries, not primary sources). **No specific market number goes on a slide without re-verification.** The demo depends on none of them.
- Synthetic data only. Say so. No real mandates, no real funds, no real merchants.
- Label deterministic gates as deterministic. Sentinel called `if ratio > 3.0` an "agent" and that is exactly the credibility failure we are exploiting.

## Workflow
1. Change → 2. `jac run smoke.jac` (fast, no key, deterministic) → 3. if the agentic layer changed, one real run with a key → 4. commit.
- **Commits must land inside hacking hours (10:45 AM – 7:15 PM PT).** This is an eligibility rule, not a style preference — Sentinel's 4-day commit history would have failed it. Commit continuously.
- Commit trailer: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- **Multi-agent work: file boundaries are law.** schema/gates vs tribunal/probe vs seed/scripts vs web/pages. Never edit outside your lane; route contract changes through the lead.

## Don'ts
- DON'T `pip install byllm` or `jaclang` — bundled with the `jac` binary; a pip copy will shadow it and break imports.
- DON'T use `import from byllm.lib` (0.15 syntax). It's `jaclang.byllm.lib`.
- DON'T use plain `visit [-->]` when you need an edge ability to fire. Silent no-op.
- DON'T build the dashboard first. Sentinel shipped 4,479 lines of React and **zero `by llm()`** — the prettiest artifact at the last event still lost the Jac criterion.
- DON'T add x402 / testnet / wallet integration. The rails are commodity, it costs an hour, and crypto framing splits a Salesforce/Apple/Google panel. Settlement is simulated.
- DON'T let the LLM compute arithmetic (caps, velocity, sums). Graph and Python own numbers; the model owns judgment. Mixing them is how you get a wrong number on stage.
- DON'T let an exception reach the audience. Every layer catches and degrades — Layer 1 (live LLM) → Layer 2 (deterministic gates) → Layer 3 (`demo_case.json`).
- DON'T commit `.env`, `.jac/`, `__jac_gen__/`, or `node_modules/`.
- DON'T edit `killBill/` or `Sentinel/` — reference only, and `jac/` is the upstream language repo (keep it out of the submission).

## Env keys (`turnstile/.env`)
`OPENAI_API_KEY` (default path, `gpt-4o-mini`) · `ANTHROPIC_API_KEY` · `GEMINI_API_KEY` · `TURNSTILE_MODEL` (override model id). ModelPool falls back across whatever is present; **no key at all is a supported mode** and must stay that way.

## When you make a mistake, add the rule here in the same commit as the fix. Keep this file under 150 lines — delete rules the code now makes obvious.
