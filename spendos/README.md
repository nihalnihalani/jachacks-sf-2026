# SpendOS — Agentic Financial Guardian

SpendOS imports a bank-statement CSV, detects recurring charges, investigates
subscriptions from graph evidence, remembers user decisions, and simulates an
approved cancellation. Its minimal Budget Guard reserves confirmed fixed
obligations, detected subscriptions, and a user-defined safety reserve to
calculate one deterministic Safe to Spend value. Its Purchase Guard also lets
AI agents submit purchase proposals for deterministic budget preflight, while
keeping approval and simulated execution under explicit human control.

The current release deliberately stops before real financial execution. Its
Live Feed is a deterministic, always-on-style simulation for testing the
guardian loop. It does not connect to a bank, cancel a real subscription, move
money, or claim that a real account is being monitored.

A new agentic Purchase Layer (V7, see `../CLAUDE_CODE_TASK.md`) is being built
one gate at a time on top of this. Milestone 7.0 is live: a one-line request
("buy 1 kg potato, onion, and tomato from Instacart") resolves against a live
store catalog, builds a cart, and produces a `SIMULATED` order recorded to
audit history — with no budget, recurring, limit, pattern, fraud, or preference
gates wired in yet, and `checkout_and_pay` not implemented.

## Run it

Requires the native Jac 0.34.7 binary:

```bash
jac install
jac clean --data --force
jac test
jac build
jac start --dev --port 8011
```

Open <http://localhost:8011> and choose **Watch the live demo** to stream the
bundled 55-transaction synthetic bank feed through SpendOS in small batches.
Each batch is imported into the Jac graph, followed immediately by recurrence
and budget analysis.

You can also upload a CSV with these required columns:

```text
date,description,amount
```

For a bank-like activity view, the importer also accepts:

```text
merchant,category,subcategory,account_name,account_mask,transaction_type,
payment_channel,city,region,country,pending
```

Charges are negative and income/refunds are positive. Supported dates are
`YYYY-MM-DD`, `MM/DD/YYYY`, and `MM/DD/YY`. Extra columns are preserved on
transaction nodes and shown in the Live Feed UI.

## Working product loop

```text
preview
→ import
→ detect
→ continuously refresh the dashboard
→ investigate
→ decide
→ approve
→ simulate
→ remember
→ confirm budget guardrails
→ preflight an agent purchase
→ approve or reject
→ simulate
```

- Parsing, fingerprints, totals, recurrence detection, confidence, next-charge
  estimates, price changes, and savings are deterministic.
- Statements, transactions, merchants, subscriptions, evidence, cases,
  preferences, precedents, decisions, and simulated actions persist in the Jac
  graph.
- Import, analysis, investigation, decisions, and simulation are idempotent.
- The synthetic feed imports five transactions per tick, re-runs deterministic
  analysis after every batch, exposes pause/restart controls, and reads its
  detailed activity back from the persisted graph.
- Without an API key, findings are honestly labeled `deterministic`.
- With a supported provider key, `assess_subscription` uses five typed tools.
  Jac validates its evidence citations and applies deterministic safety rules.
- Cancellation always ends at `SIMULATED` with the disclosure:
  **No external action was performed.**
- Budget inputs persist in one idempotently updated `BudgetPlan` node. Safe to
  Spend is always recalculated from the current active-subscription graph.
- Purchase proposals persist with their agent identity, purpose, cadence,
  monthly impact, policy outcome, reasoning, projected Safe to Spend, and
  lifecycle state.
- `SAFE` is never permission. `WARN` requires explicit review, `BLOCK` cannot
  be overridden, and approved proposals still end at `SIMULATED`.

## Architecture

| File | Responsibility |
| --- | --- |
| `schema.jac` | Typed objects, graph nodes and edges, CSV parser, recurrence math |
| `agent.jac` | Typed byLLM assessment and five evidence tools |
| `purchase.jac` | Purchase-layer (V7) domain model: catalog search, cart/order math, instruction parsing — no gates yet (7.0) |
| `endpoints.sv.jac` | Graph workflows and client-facing endpoints |
| `frontend.cl.jac` | Complete responsive client written in Jac |
| `main.jac` | Full-stack entry and endpoint registration |
| `tests/core_tests.jac` | Deterministic, idempotency, and simulation tests |
| `tests/purchase_tests.jac` | Purchase-layer 7.0 tests: parsing, catalog resolution, cart/order totals, out-of-stock and unresolved-item handling, audit |
| `data/sample_statement.csv` | Safe demo statement with one rejected row |
| `data/synthetic_bank_feed.csv` | Detailed two-account, three-month live-feed fixture |
| `data/catalog.csv` | Live store catalog fixture used by `resolve_products` |
| `hermes/` | Constrained MCP bridge and Hermes financial-guardian skill |

The graph is the only persisted application state. Functions own pure parsing
and math. Walkers own graph traversal and mutation. The client calls the server
through Jac’s generated codespace boundary; there is no Express server or
handwritten REST client.

## Agent safety

The optional live assessment can return only `KEEP`, `REVIEW`, `DOWNGRADE`, or
`CANCEL`. It receives graph-derived evidence and may use:

1. charge history;
2. price changes;
3. user preferences;
4. prior precedent; and
5. portfolio overlap.

Unsupported citations become `REVIEW`. Low-confidence results become
`REVIEW`. Protected subscriptions remain `KEEP`. The model cannot approve or
execute an action, and it never owns financial arithmetic.

## Hermes Agent

SpendOS exposes a narrow nine-tool MCP adapter for Hermes. Five tools cover
financial snapshot and purchase-proposal preflight. Four additional tools form
a two-way research loop: SpendOS dispatches a shopping mission, Hermes claims
it, returns evidence-backed candidates, and marks the mission ready for human
review. It deliberately exposes no approve, checkout, purchase, cancellation,
transfer, bank-login, or merchant-contact tool.

Run the bridge beside SpendOS:

```bash
SPENDOS_API_URL=http://127.0.0.1:8012 \
  python3 hermes/mcp_http_server.py --host 0.0.0.0 --port 8765
```

For Docker Hermes, register
`http://host.docker.internal:8765/mcp`. See
[`hermes/README.md`](hermes/README.md) for the complete local setup and safety
boundary.

## Verification

```bash
jac check .
jac check --lint .
jac test
jac build
```

The test suite covers merchant normalization, detailed bank-field parsing,
malformed-row reporting, deterministic recurrence detection, duplicate-free
reimport, idempotent cancellation simulation, Safe to Spend arithmetic,
unsafe-plan warnings, idempotent budget updates, purchase-policy thresholds,
approval restrictions, proposal reevaluation, and simulation.

## Current limitations

- Demo endpoints are public and use the shared guest graph.
- There is no authentication or multi-user isolation yet.
- CSV bank metadata is optional and no automatic bank-format mapper exists yet.
- Currency is selected by the caller and not inferred.
- The deterministic agent can identify overlapping services, but it does not
  infer whether the user uses them.
- Real cancellation and connected bank monitoring remain outside the safety
  boundary.
