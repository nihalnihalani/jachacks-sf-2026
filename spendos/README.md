<h1 align="center">SpendOS</h1>

<p align="center"><strong>An authorization firewall for AI agents that spend money.</strong></p>
<p align="center"><em>Every payment is a walker. Authorization is a route it must survive.</em></p>

<p align="center">
  <strong>Track:</strong> Agentic AI ·
  <strong>Built at:</strong> JacHacks SF 2026 ·
  <strong>Stack:</strong> Jac native binary + built-in byLLM
</p>

---

## The problem

AI agents now hold spending authority. Every guardrail shipping today is a flat rule list — daily cap, per-transaction cap, merchant allowlist. Those catch a runaway loop burning $10,000. They do **not** catch a $180 charge from an allowlisted merchant that the human never wanted, which is the shape a prompt-injected agent produces: clean, fast, successful, and completely unauthorized.

The missing check is semantic: *does the cart the agent assembled match the intent the human signed?* That's a judgment, not a threshold.

## How it works

A payment enters as a Jac **walker** and travels a chain of **gate nodes**. Pass a gate, move on. Fail one, and `disengage` fires — the payment dies at the gate that killed it, and **that node is the audit record**.

```
Treasury --Funds(edge)--> Agent --> CapGate --> VelocityGate --> SanctionsGate
        --> IntentMatchGate --Next--> Settled
                           \--Escalates--> TribunalGate
```

Seven halt locations, all asserted in `smoke.jac`:

| Payment | Verdict | Dies at | Why |
|---|---|---|---|
| $340 grocery | BLOCKED | `CapGate` | arithmetic |
| $75 Nordvik Trading OOO | BLOCKED | `SanctionsGate` | real OFAC SDN hit |
| $180 gift card | BLOCKED | `TribunalGate` | 2 corroborating signals |
| $60 electronics | **REVIEW** | `TribunalGate` | 1 signal — never a block |
| 3×$150 then $100 | BLOCKED | **`Funds` — an edge** | cumulative spend |
| 7th in window | BLOCKED | `VelocityGate` | burst limit |
| $45 grocery | SETTLED | `SettledGate` | clean pass |

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
cd spendos
jac install --plan
jac install
jac precommit
jac test
./demo.sh              # clean slate, assert 9/9, start the UI
./demo.sh --check      # verify only — run this before you present
```

Manually:
```bash
jac run smoke.jac      # 9 payments, 0 tokens, no API key required
jac start --dev        # UI + API with hot reload
```

Before changing Jac code, use the version-matched reference bundled with the
compiler:

```bash
jac guide --search walker
jac guide jac-by-llm
jac mcp --inspect
```

Optional — set **one** key in `.env` to enable the LLM intent gate:
```bash
cp .env.example .env   # OPENAI_API_KEY | ANTHROPIC_API_KEY | GEMINI_API_KEY
```
**No key is a fully supported mode.** The gate chain runs identically without one.

## Why this is a graph, honestly

A linear gate chain is a `for` loop in a costume, and we won't pretend otherwise. The graph earns its place in exactly two places — and both are load-bearing:

- **`Funds` is an edge that meters its own spend.** Three legs settle legitimately; the fourth dies at the edge on cumulative spend no single transaction can see. **Per-transaction reasoning structurally cannot catch structuring.**
- **`trace_provenance` walks the delegation chain backward** from a charge to a live human principal. A byLLM tool spawns that walker *mid-traversal*. Reachability is not a table scan.

The three arithmetic gates are arithmetic. We label them as such.

## Jac constructs used

Six load-bearing ones — deliberately not twelve, because these survive being probed:

1. **Walkers as the execution model** — a payment *is* a walker
2. **`disengage`** — the halting node is the audit record
3. **Edge abilities** via `visit [edge ->:Funds:->]` — the edge is the accountant
4. **`by llm(tools=[...])`** ReAct — the Tribunal plans which specialists to consult
5. **A byLLM tool that spawns a walker** — `trace_provenance`
6. **The frontend is Jac** — `.cl.jac` → React, `root spawn` crosses `cl → sv` with no fetch, no REST client, no Express

Plus `on_iteration` budget hooks, `ModelPool` fallback, typed edge endpoints, and `root` persistence for precedent memory.

**The convergence rule is enforced in Jac, not in the prompt:** BLOCK requires 2+ *independent* adverse sources; one signal is always REVIEW; a model that says "block" with no evidence is downgraded. It holds even when the model ignores its instructions.

## Layered degradation

| Layer | Condition | Behavior |
|---|---|---|
| 1 | API key present | LLM intent gate + ReAct tribunal |
| 2 | no key / API down | deterministic gates — **a complete demo** |
| 3 | backend down | UI falls back to `web/demo_case.json` |

Measured in all three states: same verdict, same three corroborating signals. `SPENDOS_FORCE_DETERMINISTIC=1` is the panic switch.

## Project layout

```
schema.jac        nodes, typed edges, the self-metering Funds edge
gates.jac         gate chain + Payment walker + disengage
tribunal.jac      by llm(tools=[...]) adjudicator, convergence rule, budget hook
probe.jac         adversarial red-team agent (conversation= memory)
endpoints.sv.jac  ScreenPayment / ResetDemo — what the client spawns
frontend.cl.jac   the UI, in Jac
smoke.jac         9 asserted verdicts, fails if a token is ever spent
seed.py           synthetic graph + attack corpus + OFAC cache (stdlib only)
demo.sh           clean-start runbook — always rehearse from this
```

## What's honest about this

- **Seed data is synthetic.** Principals, agents, mandates and merchants are generated.
- **The OFAC list is real** — 19,218 records from treasury.gov, sha256-verified against the server's own `Digest` header, committed. Network is touched only under `--refresh-ofac`.
- **Numbers are produced live**, not replayed from a pre-computed file.
- **We have not tested an attack we didn't anticipate.** The claim is the architecture, not a detection rate.

## Not production

This is a one-day hackathon build. It has **no authentication, no rate limiting, no multi-tenancy, no key management, no adversarial security review, and no load testing.** Settlement is simulated — no real funds move. `walker:pub` endpoints are unauthenticated by design so the demo needs no login.

What it *does* have: a deterministic layer that runs with no credentials, an assertion suite that fails on verdict drift or an unexpected token spend, layered degradation measured in three states, and a runbook that starts from a clean graph.

## License

MIT — built for JacHacks SF 2026. Synthetic data only.
