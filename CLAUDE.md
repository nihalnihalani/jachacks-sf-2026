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

## Jac 0.34.5 — verified facts (do NOT rediscover these)
- **Import is `import from jaclang.byllm.lib { Model }`** — NOT `byllm.lib`. killBill targeted 0.15 and its `audit.jac:12` is stale. Iteration types: `import from jaclang.byllm.types { IterationAction, IterationContext }`.
- **`jac run` requires a `jac.toml` in the directory.** `jac build` errors with "needs a project" without one.
- **Plain `visit [-->]` crosses edges WITHOUT firing their abilities.** Only `visit [edge -->]` (or spawning on an edge) wakes them. Get this wrong and the `Funds` edge accounting silently no-ops — no error, just wrong numbers. Verified: `jac/docs/docs/reference/language/osp.md:215-222`.
- **Node-level LLM methods compile**: `node G { def judge(c: dict) -> Ruling by llm(); }` — proven by compile spike, not assumed.
- **Typed edge endpoints work**: `edge Funds: Treasury --> AgentIdentity { has cap: float; }` (`osp.md:248`).
- `disengage`, `visitor`, `here`, edge abilities (`can meter with Payment entry`) all compile at 0.34.5.
- `Model(model_name=...)` constructs at glob scope **without** an API key present — only invocation needs one. This is why Layer-2 degradation works.
- `jac create <name> --kind web-app` scaffolds a full-stack app with the frontend written in Jac (`cl`/`sv` codespaces, `JsxPage` routing). **Status: spike pending** — treat as unproven until FrontendScout returns GO with command output.

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

## Design laws — non-negotiable
- **The deterministic gate chain must run standalone with ZERO LLM calls.** Every agentic layer is additive. This is the demo-safety floor; if it ever needs a key to run, that's a bug.
- **Convergence rule (from Sentinel):** escalate to `BLOCKED` only on **2+ independent corroborating signals**. A single signal returns `REVIEW`, never a block. One agent's opinion is not a verdict.
- **Precedent is the zero-token fast path.** A fingerprint hit blocks without any LLM call. The demo's "it learned" moment is this, and it must be *measured* on stage (tokens + latency), never asserted.
- **Attack #5 in the ladder must legitimately PASS.** A system that blocks everything proves nothing. Cutting the passing case destroys credibility.
- **Deterministic where determinism belongs** (killBill's real lesson): cap/velocity/sanctions are arithmetic. Do not spend tokens on comparisons.
- **The graph must be load-bearing.** killBill's graph was write-only — nothing ever traversed it. If you could delete the graph and keep the demo, the thesis is dead. Traversal *is* the algorithm here; keep it that way.

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
