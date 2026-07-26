# TURNSTILE

**An authorization firewall for AI agents that spend money.**
Every payment is a walker. Authorization is a route it must survive.

Track: **Fintech / Open** · Built for JacHacks SF 2026 · Stack: Jac 0.34.5 (full-stack) + byLLM

---

## 1. The problem

AI agents now hold spending authority. You grant one a mandate — *"order groceries, under $200/week"* — and it transacts on your behalf.

Every production guardrail today is a **flat rule list**: daily cap, per-transaction cap, merchant allowlist. Those catch a runaway loop burning $10,000. They do not catch a **$340 charge from an allowlisted merchant that the human never wanted** — the shape produced by a prompt-injected or hijacked agent. It arrives clean, fast, and successful, which is precisely the opposite of what fraud models are trained to flag.

The missing check is semantic: *does the cart the agent assembled actually match the intent the human signed?* That is a judgment, not a threshold — which is why nobody ships it as a rule.

### Why the timing is right
- Agent payment rails shipped in 2026 (x402, AP2 mandates, Stripe Machine Payments, AWS AgentCore Payments). The rails exist; the **judgment layer** does not.
- Industry press frames delegation chains, revocation, and transitive trust as explicitly unaddressed.
- Disputes on agent-initiated transactions run materially higher than human card-not-present, skewed toward *"did not authorise."*

> **Sourcing note.** The market statistics above came from a research pass with mixed confidence. The *direction* is well supported; specific figures were flagged medium-confidence. **Do not put a specific number on a slide without re-verifying it.** The demo does not depend on any of them.

---

## 2. The idea in one paragraph

A payment request enters the system as a **walker** and physically travels a chain of **gate nodes**. Each gate inspects the payment on arrival. Pass → move on. Fail → `disengage`, and the payment stops dead *at the gate that killed it*. That halting node **is** the audit record — you don't log a reason, the location is the reason.

The first three gates are arithmetic: free, instant, no tokens. The fourth is an LLM that reads the human's original mandate and judges whether this cart honors it. A fifth escalates ambiguity to a **Tribunal** that consults specialist agents and rules. Every ruling persists as a **Precedent** node, so the second identical attack is blocked in milliseconds with zero LLM calls.

A **red-team Probe agent** reads each rejection reason and rewrites its attack to slip past. It plans across attempts and remembers what failed.

---

## 3. What we take from each reference project

### From killBill (its real strengths)
| Pattern | How TURNSTILE uses it |
|---|---|
| **One genuine `by llm(tools=[...])` ReAct call** where the model picks tool order | The Tribunal adjudicator — decides *which* specialists to consult, not a fixed pipeline |
| **Deterministic layer handles the cheap 80%** (`recurrence.py`, zero tokens) | CapGate / VelocityGate / SanctionsGate are pure arithmetic. Also the demo-safety story. |
| **`sem` semstrings** for instruction-grade prompt hints | Every tool and the adjudicator |
| **Multi-provider model fallback** (`_pick_model`) | Upgraded to byLLM's native `ModelPool` (new in 0.34.x) |
| **Cached JSON fallback** so the UI survives a dead agent | `web/demo_case.json` — identical strategy |
| **Parallel fan-out** to fit the demo time budget | Specialist agents run concurrently |
| **A single headline number** | Live scoreboard: blocked / tokens saved / p50 latency |

### From Sentinel (its real strengths)
| Pattern | How TURNSTILE uses it |
|---|---|
| **Multiple specialists over ONE shared graph**, each traversing a different path | Scope / Provenance / Sanctions / Velocity agents, each a different traversal |
| **Convergent evidence before escalating** (2+ agents must agree) | The precision story — a single signal routes to Tribunal, not to BLOCK |
| **Real typed graph schema** | Principal / Agent / Mandate / Gate / Merchant / Precedent |
| **Force-directed graph visualization** | The gate chain animates as the walker traverses it |
| **Concrete metrics as the closing slide** | Scoreboard, but every number is produced live on stage |

### What we fix — the two flaws that cost them
- **killBill's graph is decorative.** `persist_audit_to_graph` writes nodes *after* all analysis; no walker ever traverses them. Delete the graph and the demo is byte-identical. → **In TURNSTILE, traversal IS the algorithm.**
- **Sentinel has zero `by llm()`.** Its "5 agents" are `if claims_ratio > 3.0` inside `::py::` blocks; its "98% precision" is threshold tuning. → **In TURNSTILE, every judgment call is a real LLM decision, and the deterministic gates are honestly labeled as deterministic.**

**Neither project did both.** Sentinel traverses without an LLM; killBill has an LLM that never traverses. That gap is the entire opening.

---

## 4. New Jac features we exploit

All verified against the local `jac/` source at 0.34.5 and a compile spike.

| # | Feature | Why it matters here | Verified |
|---|---|---|---|
| 1 | **`jac create --kind web-app`** — full-stack; frontend written *in Jac* (`cl`/`sv` codespaces, `JsxPage` routing) | Judging criterion says *"single-file dev."* Sentinel shipped 4,479 lines of separate React+Express. We ship one Jac project. | `jac create --help` |
| 2 | **Edge abilities fire on `visit [edge -->]`** | The funding edge decrements *itself*. Money moves along an edge and the edge is the accountant. | `osp.md:215-222` |
| 3 | **Typed edge endpoints** — `edge Funds: Treasury --> AgentIdentity {}` | Traversal infers node type; no filter needed | `osp.md:248` |
| 4 | **Node-level `def ... by llm()`** | The gate reasons about itself; the walker just arrives | **compile spike passed** |
| 5 | **`disengage`** | Payment dies at the gate that killed it = audit record | `library-mode.md` |
| 6 | **`on_iteration` → `IterationAction.ABORT`** | Hard token/compute budget on the ReAct loop. The Probe literally runs out of budget mid-thought. | `byllm.md:824,1008` |
| 7 | **`conversation=`** multi-turn state | Probe remembers every prior rejection and adapts | `byllm.md:825,865` |
| 8 | **`ModelPool`** fallback + load-balance | Dead API key at 6pm doesn't end the demo | `byllm.md:388-458` |
| 9 | **Typed object returns + retry** | `Ruling` obj enforced as schema, auto-retried | `byllm.md:734,761` |
| 10 | **`stream=True, logging=True` → `StreamEvent`** | Agent's reasoning narrates live on screen | `byllm.md:1388` |
| 11 | **`walker:pub`** → auto REST endpoint | No Express server to write | `osp.md:555` |
| 12 | **`root` persistence** | Precedents survive restarts; run two is measurably faster than run one | `osp.md` |

> ⚠️ **Version gotcha.** Import is `jaclang.byllm.lib`, **not** `byllm.lib`. killBill targeted 0.15; we're on 0.34.5. Copying its line 12 will waste 30 minutes.
> ⚠️ Plain `visit [-->]` crosses edges **without** firing their abilities. Only `visit [edge -->]` wakes them, or your funding accounting silently no-ops.
> ⚠️ `jac run` requires a `jac.toml` in the directory.

---

## 5. Graph schema

```jac
node Principal    { has name: str; }
node AgentIdentity{ has handle: str, model: str; }
node Treasury     { has label: str; }
node Merchant     { has name: str, category: str, allowlisted: bool = False; }

node Mandate {
    has intent_text: str,       # "groceries, under $200/week"
        granted_at: str,
        expires_at: str,
        revoked: bool = False;
}

node Precedent {
    has fingerprint: str,       # (merchant, category, pattern)
        verdict: str,
        reason: str,
        hit_count: int = 0;
}

node CaseFile {
    has payment_id: str, verdict: str, halted_at: str,
        reason: str, signals: list[str], tokens_used: int;
}

# --- edges carry the semantics ---
edge Authorizes: Principal --> Mandate {}
edge Delegates:  Mandate --> AgentIdentity { has scope: str; }
edge Funds:      Treasury --> AgentIdentity {
    has cap: float, spent: float = 0.0;
    can meter with Payment entry {          # fires ONLY on visit [edge -->]
        self.spent += visitor.amount;
        if self.spent > self.cap {
            visitor.verdict = "BLOCKED";
            visitor.reason  = f"Treasury cap ${self.cap} exhausted";
        }
    }
}
edge Next: Gate --> Gate {}
```

**Why this is genuinely a graph, not a table with extra steps:**
- Authorization = **reachability** from a charge back to a human principal.
- Revocation = **edge deletion**; blast radius = the reachable set that goes dark.
- The gate chain = an actual **route**, and surviving it is the authorization.
- Budget lives **on the funding edge**, decremented by that edge's own ability.

---

## 6. The gate chain

```
Payment ─▶ CapGate ─▶ VelocityGate ─▶ SanctionsGate ─▶ IntentMatchGate ─▶ Tribunal? ─▶ Settled
            (math)      (math)          (OFAC lookup)    (by llm)          (ReAct)
```

```jac
node CapGate {
    has limit: float;
    can screen with Payment entry {
        if visitor.amount > self.limit {
            visitor.verdict = "BLOCKED";
            visitor.halted_at = "CapGate";
            visitor.reason = f"${visitor.amount} exceeds per-txn cap ${self.limit}";
            disengage;                       # dies HERE — this node is the record
        }
        visitor.signals.append("cap:ok");
        visit [-->];
    }
}

node IntentMatchGate {
    has mandate_text: str;
    def judge(cart: dict, mandate: str) -> Ruling by llm();   # node judges itself
    can screen with Payment entry {
        pre = match_precedent(visitor.fingerprint());          # zero-token fast path
        if pre {
            visitor.verdict = pre.verdict;
            visitor.reason  = f"precedent: {pre.reason}";
            visitor.halted_at = "IntentMatchGate(cached)";
            disengage;
        }
        r = self.judge(visitor.cart, self.mandate_text);
        visitor.tokens_used += r.tokens;
        if r.blocked {
            visitor.verdict = "BLOCKED";
            visitor.halted_at = "IntentMatchGate";
            visitor.reason = r.reason;
            write_precedent(visitor.fingerprint(), "BLOCKED", r.reason);
            disengage;
        }
        if r.uncertain { visit [-->:Escalates:-->]; }          # route to Tribunal
        else { visit [-->]; }
    }
}
```

### The Tribunal — the agentic core
Reached only when a gate is *uncertain*. This is the one `by llm(tools=[...])` ReAct call where the **model plans which evidence it needs**:

```jac
def adjudicate(cart: dict, mandate: str, chain: list[str]) -> Ruling
    by llm(tools=[
        compare_to_intent,        # semantic cart↔mandate diff
        trace_provenance,         # spawns a walker BACK up the delegation chain
        check_sanctions,          # OFAC list — the one real external tool
        read_precedent            # queries the persisted Precedent subgraph
    ], on_iteration=budget_hook);
sem adjudicate = """You are an authorization adjudicator...""";
```

**Sentinel's convergence rule, adopted:** the Tribunal escalates to `BLOCKED` only on **2+ independent corroborating signals**. A single signal returns `REVIEW` (human-in-the-loop) rather than a block. That is the precision story — and unlike Sentinel's, it is enforced by agent agreement, not by a tuned threshold.

### The Probe — adversarial red team
```jac
glob probe_history: list = [];
def next_attack(last_rejection: str) -> Attack
    by llm(conversation=probe_history, on_iteration=budget_hook);
```
Reads *why* it was rejected and rewrites the request. Plans across attempts. `on_iteration` caps it so it cannot doom-loop on stage.

---

## 7. Demo script (3 minutes)

**0:00–0:20 — Hook.**
> "We gave an AI agent a credit card and told it: groceries, under $200 a week. Here's a charge that passes every rule your bank would check — and should never have happened."

**0:20–1:20 — Attack #1.** Submit a $340 charge, allowlisted merchant, under the daily cap.
Gates flash green in sequence: `CapGate ✓ VelocityGate ✓ SanctionsGate ✓`.
Then `IntentMatchGate` **halts the walker red** on the graph, with the agent's reasoning streaming live:
> *"Mandate authorizes groceries. This cart is a $340 gift card. The instruction originated from text embedded in a product page, not from the principal."*

**1:20–2:10 — The Probe fights back.** Red-team agent reads the rejection and retries three times — reworded, re-categorized, split into two charges. Watch it get caught each time for a *different* reason. On attempt 4 it exhausts its `on_iteration` budget and gives up mid-thought.

**2:10–2:40 — It learned.** Replay attack #1 verbatim. **Blocked in ~200ms, zero LLM calls**, citing its own prior ruling. Scoreboard updates live: *tokens saved, p50 latency, precedents accrued.*

**2:40–3:00 — Revocation.** Revoke one `Delegates` edge. The downstream blast radius greys out instantly — every agent and pending charge that inherited authority through it goes dark.

> One graph. Four different questions. The topology answers all of them.

---

## 8. File layout

```
turnstile/
├── jac.toml                 # ModelPool config + byllm defaults
├── schema.jac               # nodes, typed edges, edge abilities
├── gates.jac                # gate nodes + Payment walker + disengage logic
├── tribunal.jac             # by llm(tools=[...]) adjudicator + specialist tools
├── probe.jac                # adversarial agent w/ conversation=
├── memory.jac               # Precedent read/write, fingerprinting
├── seed.py                  # synthetic graph + attack corpus (no network)
├── pages/
│   └── index.jac            # JsxPage — UI written in Jac (cl codespace)
└── web/demo_case.json       # cached fallback if the agent is unreachable
```

---

## 9. Build schedule — ~4 hours

Every hour ends with something runnable. That's non-negotiable.

| Time | Deliverable | Owner |
|---|---|---|
| **+0:00–0:30** | `jac create turnstile --kind web-app`; `schema.jac` compiles; seed graph loads | A |
| **+0:30–1:30** | Gate chain + `Payment` walker + `disengage`. **Zero LLM — this alone is a demo.** | A |
| **+0:30–1:30** | `seed.py`: 40 synthetic payments, 6 attack scenarios, OFAC list cached to JSON | B |
| **+1:30–2:30** | `IntentMatchGate.judge()` + Tribunal `by llm(tools=[...])` + `ModelPool` | A+C |
| **+1:30–2:45** | `pages/index.jac` — gate chain viz + live `StreamEvent` reasoning pane | B |
| **+2:30–3:15** | Probe agent + `Precedent` memory + scoreboard | C |
| **+3:15–3:45** | `demo_case.json` fallback, rehearse the 3 minutes twice | all |
| **+3:45–4:00** | README, Devpost copy, **partial submission** | all |

### Cut list, in order
1. Probe agent → 3 pre-authored attacks (still looks live)
2. Precedent semantic matching → exact `(merchant, category)` string key
3. Revocation blast-radius scene
4. Force-directed layout → static SVG chain with colored nodes
5. Tribunal → fold into `IntentMatchGate` as a single richer `by llm()` call

**Never cut:** the gate chain, `disengage`, one real `by llm()`, the cached fallback.

### Two 20-minute spikes to run FIRST
1. **`jac create --kind web-app` scaffolds and serves.** If the client toolchain fights you (needs bun/node), **abandon the Jac frontend immediately** and ship killBill's approach — one static `index.html`, no build step. Do not spend an hour here.
2. **A byLLM tool function can spawn a walker** (`trace_provenance` depends on it). Both halves are documented; the composition is not. Fallback: plain function tools that read the graph directly — costs elegance, not the demo.

---

## 10. Data — zero friction

- **Synthetic seed graph** (`seed.py`): principals, agents, mandates, merchants, 6 attack scenarios. No network, no keys, no KYC.
- **OFAC SDN list** — free, no API key, cached to JSON at build time. The one real external dataset.
- **Simulated settlement.** No x402, no testnet, no wallet. The rails are commodity — Cloudflare, AWS, and Coinbase all ship them — and a Salesforce/Apple/Google panel splits on crypto framing. Keep it out of the pitch.

---

## 11. How this scores

| Criterion | Argument |
|---|---|
| **Use of Jac & Jaseci** | Twelve constructs, none decorative: walkers as the execution model, `disengage`, edge abilities via `visit [edge -->]`, typed edge endpoints, node-level `by llm()`, `on_iteration`, `conversation=`, `ModelPool`, typed-output retry, `StreamEvent`, `walker:pub`, `root` persistence — **plus the whole frontend written in Jac**, which is the literal "single-file dev" criterion. Neither reference project touched more than four of these. |
| **Depth of agentic behavior** | ReAct tool planning, adversarial red-vs-blue, cross-run memory with a *measurable* effect (latency and token count both drop on stage), budget-constrained reasoning, multi-agent convergence before escalation. |
| **Technical execution** | Deterministic layer works with zero LLM calls; every agentic layer is additive; cached fallback; graceful degradation at every cut point. |
| **Creativity** | Nobody builds the judgment layer — everyone builds rails. |
| **Presentation** | A walker halting red at the exact gate that killed it is a visual only a graph engine produces. |
| **Impact** | Real, current, and unaddressed: agents hold spending authority and nothing checks intent. |

**The test that matters:** hand a single LLM call a payment and a rule list and it produces a plausible verdict. Hand it *"this charge is legal at every hop but the authority chain broke two hops upstream, and here's the precedent that settles it"* — it cannot, because that fact lives in the topology and in no single record.

---

*Built at JacHacks SF 2026. Synthetic data only — no real funds, no real mandates.*
