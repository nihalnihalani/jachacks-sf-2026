# SpendOS Simple Build Plan

## Implementation status

The first Subscription Guardian release described below is implemented in
`spendos/`:

- current Jac 0.34.7 project checks, tests, and build pass;
- three-column CSV preview and idempotent graph import work;
- monthly, quarterly, and annual recurrence detection is deterministic;
- subscription totals, expected charges, confidence, and price changes render
  from the graph;
- optional byLLM investigation uses five typed evidence tools;
- no-key investigations are honest and deterministic;
- decisions persist preferences and precedent;
- approved cancellation follows `PROPOSED → APPROVED → SIMULATED`; and
- Budget Guard calculates deterministic Safe to Spend from confirmed inputs;
- Purchase Guard records agent proposals and returns `SAFE`, `WARN`, `BLOCK`,
  or `REVIEW`;
- safe proposals require human approval, warnings cannot self-approve, blocks
  cannot be overridden, and execution remains simulated;
- Hermes connects through a twenty-tool MCP allowlist with no approval or
  real financial-execution capability;
- SpendOS can dispatch a durable shopping mission, Hermes can claim it and
  return structured candidates, and SpendOS independently checks budget and
  recurring-cost violations; and
- the UI always states that no external action was performed.

The stop line remains active: connected accounts, real cancellation,
notifications, and autonomous financial execution are not part of this
release.

## Product to build now

Build one working feature:

> Upload a statement, find subscriptions, investigate the important ones, and
> remember what the user decides.

Do not build a complete financial operating system yet. The financial OS is the
direction; Subscription Guardian is the first product.

## Engineering rules

1. Keep `main` runnable after every change.
2. Finish one live vertical slice before adding another.
3. Deterministic code owns facts and money calculations.
4. The LLM may investigate and explain, but not authorize itself.
5. The Jac graph is the only source of truth.
6. Use functions for parsing and math; use walkers for traversal and workflow.
7. Every mutation is idempotent.
8. Every iteration works without an API key.
9. Never show cached or simulated data as live.
10. Pin and test the Jac behavior the product depends on.

## Iteration 0 — Green SpendOS

Purpose: prove the renamed foundation still works on the current remote code.

- Install and pin the native Jac binary.
- Read the version-matched `jac guide` topics used by the project.
- Export project-local agent skills.
- Verify the project `jac mcp` configuration with `jac mcp --inspect`.
- Run `jac check` and `jac check --lint`.
- Run `jac fmt` and make `jac precommit` the standard quality gate.
- Run the current smoke and tribunal tests.
- Migrate executable tests into `spendos/tests/` and run them with `jac test`.
- Run `jac build` so the whole project and client boundary are checked.
- Run them three times to expose persistence defects.
- Add a tiny compatibility test for edge abilities.
- If edge abilities do not fire on the pinned runtime, move funding checks into
  a walker/node ability.
- Remove stale fallback paths that can impersonate live output.

Done when:

- setup works from a clean checkout;
- no external Python installation is required for Jac;
- the app compiles and starts;
- no-key and live-key paths are explicit;
- `jac precommit`, `jac test`, and `jac build` pass;
- all smoke tests pass three consecutive times; and
- version-sensitive behavior is covered by CI.

## Iteration 1 — Import one CSV correctly

Purpose: establish trustworthy live data.

Support exactly:

```text
date,description,amount
```

Build:

- a pure typed parser;
- an import preview;
- rejected-row reporting;
- signed-amount and currency handling;
- statement and transaction fingerprints;
- an idempotent import walker; and
- `Statement -> Transaction -> Merchant` graph traversal.

Do not add arbitrary bank-format detection yet. Add a manual mapping screen
later.

Done when:

- the sample imports from the UI;
- totals match an independently calculated fixture;
- malformed rows show reasons;
- reimport creates zero duplicates; and
- the UI reads totals back from the graph.

## Iteration 2 — Detect subscriptions without an LLM

Purpose: deliver the first useful result.

Build:

- deterministic merchant normalization;
- monthly, quarterly, and annual recurrence detection;
- amount-variation tolerance;
- next expected charge;
- detection confidence;
- price history and increase detection; and
- `Transaction -> Subscription` relationships with match confidence.

Show only:

- recurring monthly total;
- subscriptions found;
- next expected charge; and
- price changes.

Done when:

- labeled fixtures pass;
- repeat runs are identical;
- subscriptions are traversed from the user's graph; and
- no LLM is needed.

## Iteration 3 — Add one genuine agent investigation

Purpose: make SpendOS agentic in a testable way.

Create one `SubscriptionCase` for a high-value or ambiguous subscription.

Give one typed `assess_subscription` call these tools:

- read charge history;
- read price changes;
- read user preferences;
- read prior precedent;
- compare portfolio overlap.

Require the result to cite evidence ids. Jac validates the citations,
recalculates savings, and enforces the approval rule.

Outcomes:

- `KEEP`
- `REVIEW`
- `DOWNGRADE`
- `CANCEL`

Rules:

- low confidence cannot produce `CANCEL`;
- unsupported claims become `REVIEW`;
- protected subscriptions cannot be canceled;
- no-key mode produces deterministic findings, not fake agent output.

Done when:

- one live case is investigated;
- the result cites valid graph evidence;
- malformed model output is safe; and
- the same financial facts produce the same monetary impact.

## Iteration 4 — Close the learning loop

Purpose: prove the agent improves through use.

Add actions:

- approve;
- reject;
- postpone;
- protect;
- correct merchant.

Persist `Decision`, `Preference`, and `Precedent` nodes. The next investigation
must traverse them.

Done when:

- “never cancel this” prevents later cancel recommendations;
- a corrected merchant is reused;
- repeated analysis avoids unnecessary model work; and
- the behavior change is visible and explainable.

## Iteration 5 — Simulate one cancellation

Purpose: move from advice to controlled action.

Implement:

```text
PROPOSED
-> AWAITING_APPROVAL
-> APPROVED
-> SIMULATED
```

Show:

- exact proposed action;
- evidence;
- expected deterministic savings;
- approval timestamp; and
- a clear “No external action was performed” label.

Done when the full live story passes:

```text
clean graph
-> upload
-> detect
-> investigate
-> approve
-> simulate
-> remember
-> rerun without duplicates
```

Run it three consecutive times.

## Stop line

Do not begin Plaid, notifications, real cancellation, real checkout, multiple
visible agents, or a large dashboard before Iteration 5 is reliable.

## Next capability after the stop line

Add a minimal Budget Guard:

- confirm income;
- reserve fixed and recurring obligations;
- calculate one deterministic Safe to Spend value; and
- warn when a new subscription makes the plan unsafe.

Only after that should SpendOS add connected monitoring and real actions.

### Budget Guard implementation status

The first post-stop-line vertical slice is now implemented:

- the user confirms monthly take-home income, fixed obligations, and a safety
  reserve;
- SpendOS reserves the recurring subscription total already proven by the
  graph;
- `Safe to Spend = income - fixed obligations - subscriptions - reserve`;
- one `BudgetPlan` node is updated idempotently instead of creating snapshots;
- unsafe plans show an explicit deterministic warning; and
- the UI states that SpendOS does not move money.

The next small capability should warn before a proposed new subscription is
approved. Connected accounts, arbitrary category budgeting, and autonomous
spending remain out of scope.

## Immediate execution order

1. Install and pin the Jac version.
2. Restore green compile and smoke tests.
3. Add the edge-ability compatibility test.
4. Define `Statement`, `Transaction`, `Merchant`, and typed edges.
5. Implement the three-column parser and import preview.
6. Implement idempotent graph commit.
7. Port and test recurrence detection.
8. Render live subscription totals.
9. Add one evidence-backed agent case.
10. Persist one user decision and prove the next run changes.
11. Simulate one approved cancellation.
12. Run the full story three times from a clean checkout.

## First release acceptance criteria

- Clean checkout setup works.
- Pinned Jac behavior is verified in CI.
- One real CSV imports safely and idempotently.
- Invalid rows are visible.
- Subscriptions are detected deterministically.
- The graph is traversed during investigation.
- One agent produces a typed, evidence-backed recommendation.
- No-key mode remains honest and useful.
- A user decision changes the next result.
- One approved cancellation is simulated and clearly labeled.
- The complete workflow passes three consecutive runs.
