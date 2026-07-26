# TURNSTILE — Devpost submission draft

**Partial submission due 5:50 PM PT. Final 7:15 PM PT.**
Repo: https://github.com/nihalnihalani/jachacks-sf-2026 · Team: @nihalnihalani · @mayu99 · @yhinai

---

## Project name
**TURNSTILE** — an authorization firewall for AI agents that spend money.

## Elevator pitch
We gave an AI agent a credit card and said "groceries, under $200." Here's a charge that passes every rule your bank checks — and should never have happened.

## Track
**Agentic AI** *(alternate: Fintech / Open — the demo is identical either way)*

## Inspiration
AI agents now hold spending authority. Every guardrail shipping today is a flat rule list: daily cap, per-transaction cap, merchant allowlist. Those catch a runaway loop burning $10,000. They do **not** catch a $180 charge from an allowlisted merchant that the human never wanted — the shape a prompt-injected agent produces. It arrives clean, fast, and successful, which is the opposite of what fraud systems are trained to flag.

The missing check is semantic: *does the cart the agent assembled match the intent the human signed?* That is a judgment, not a threshold — which is why nobody ships it as a rule.

## What it does
A payment enters as a Jac **walker** and physically travels a chain of **gate nodes**. Pass a gate, move on. Fail one and `disengage` fires — the payment dies at the gate that killed it, and **that node is the audit record**. We don't log why it failed; where it stopped *is* the why.

```
Treasury --Funds(edge)--> Agent --> CapGate --> VelocityGate --> SanctionsGate
        --> IntentMatchGate --Next--> Settled
                           \--Escalates--> TribunalGate
```

Seven distinct halt locations, all verified end to end:

| Payment | Verdict | Died at | Why |
|---|---|---|---|
| $340 grocery | BLOCKED | `CapGate` | arithmetic |
| $75 Nordvik Trading OOO | BLOCKED | `SanctionsGate` | real OFAC SDN hit |
| $180 gift card | BLOCKED | `TribunalGate` | 2 corroborating signals |
| $60 electronics | **REVIEW** | `TribunalGate` | only 1 signal — never a block |
| 3×$150 then $100 | BLOCKED | **`Funds` (an edge)** | cumulative spend |
| 7th in window | BLOCKED | `VelocityGate` | burst limit |
| $45 grocery | SETTLED | `SettledGate` | clean pass |

## How we built it — and how we used Jac
Six load-bearing constructs. We deliberately do **not** claim twelve; these are the ones that survive being probed.

1. **Walkers as the execution model.** A payment *is* a walker; authorization *is* surviving a route. The language construct and the domain concept are the same object.
2. **`disengage` as the audit record.** The halting node is the finding.
3. **Edge abilities** (`visit [edge ->:Funds:->]`). The funding edge meters spend in its *own* ability — money moves along an edge and the edge is the accountant. This is what catches **structuring**: three legs settle legitimately, the fourth dies at the edge on cumulative spend no single transaction can see. Per-transaction reasoning structurally cannot catch it.
4. **`by llm(tools=[...])` ReAct.** The Tribunal plans which of four specialists to consult — not a fixed pipeline.
5. **A byLLM tool that spawns a walker.** `trace_provenance` spawns a walker *mid-traversal* to walk the delegation chain backward and reports *"agent 'shopper-01-sub' is not reachable from any signed mandate."* Reachability is not a table scan.
6. **The entire frontend is Jac.** `.cl.jac` compiles to React; `walker:pub` becomes REST automatically. No Express, no separate React app — the "single-file dev" criterion, literally.

Also used: `on_iteration` budget hooks, `ModelPool` fallback, typed-object returns, typed edge endpoints, and `root` persistence for precedent memory.

Deterministic where determinism belongs — cap, velocity and sanctions are arithmetic and cost zero tokens. The LLM only does judgment.

## Agentic behavior
- **Planning** — the Tribunal's ReAct call decides which specialists to consult per case.
- **Tool use** — four typed tools; one of them spawns a graph traversal.
- **Memory** — rulings persist as `Precedent` nodes under `root`; a repeat attack is blocked from cached case law with zero LLM calls.
- **Multi-agent convergence, enforced in Jac rather than in the prompt** — BLOCK requires 2+ *independent* adverse sources; a single signal is always REVIEW; a model that says "block" with no evidence is downgraded. It holds even when the model ignores its instructions.

## Challenges
Persistence nearly killed us twice. `root` survives across runs, so an unguarded seed built a *new* parallel gate chain every run and the walker traversed all of them. Fixing that exposed a second bug one layer down: a velocity counter living on a persisted node accumulated 3→6→9 and blocked a payment that should have passed. **Both were invisible on run 1 and only appeared on run 3** — i.e. on stage, not in dev. We now verify every change across four consecutive runs.

We also learned that naming a `.jac` file after a Python stdlib module silently imports the stdlib one — no error, symbols just undefined.

## Accomplishments
The whole gate chain runs with **no API key at all**. That's the demo-safety floor: every agentic layer is additive, so a dead key degrades the demo instead of ending it. We measured the same verdict and the same three corroborating signals in all three states — no key, forced-deterministic, and invalid key.

## What we learned
That a graph has to be *load-bearing* to be worth the claim. A linear gate chain is honestly just a `for` loop in a costume — so we put the graph argument where it actually holds: cumulative spend on an **edge**, and **reachability** from a charge back to a live human principal. Those two are the parts a list cannot express.

## What's honest about this demo
- The seed data is **synthetic** — principals, agents, mandates and merchants are generated.
- The **OFAC sanctions list is real**: 19,218 records fetched live from treasury.gov, sha256-verified against the server's own Digest header, and committed.
- The **UI currently runs scripted scenarios** so it demos with the backend dead. The backend independently emits the same contract over REST, verified for all five verdict classes.
- Numbers on screen are produced **live**, not replayed from a pre-computed file.
- We have **not** tested whether it catches an attack we didn't anticipate. The claim is the architecture, not a detection rate.

## What's next
Revocation blast-radius — delete one delegation edge and watch the reachable set go dark. Then connecting the UI to the live walker: a known ~20-minute change, not an unknown.

## Try it
```bash
cd turnstile
jac run smoke.jac      # 9 payments, 7 halt locations, 0 tokens, no API key required
jac start -d           # UI on :8003, API on :8001   (the -d is required)
```

## Built with
Jac · Jaseci · byLLM · OFAC SDN (US Treasury)

---

## Checklist

- [ ] Repo is **public**
- [ ] All commits inside hacking hours (10:45 AM – 7:15 PM PT)
- [ ] Demo video recorded — **1:30 max**, hero moment in the first 20s
- [ ] Video uploaded + linked
- [ ] Track selected
- [ ] Repo linked on Devpost
- [ ] **Partial submission filed by 5:50 PM**
- [ ] Final submitted by 7:15 PM
- [ ] Someone is physically present for the 3-min demo
- [ ] Disclose unprompted in the pitch: synthetic seed data; UI runs scripted scenarios
