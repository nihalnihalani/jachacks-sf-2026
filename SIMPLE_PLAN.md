# SpendOS Simple Implementation Plan

## Rule

Build the smallest useful version, keep it working, and add one capability at a
time. Every iteration must end with a runnable product and a passing smoke test.

Do not start with real bank connections, real cancellations, real purchases, a
large dashboard, or several visible agents.

## Version 0 — Preserve the working foundation

Goal: keep the renamed SpendOS project green.

- Verify the existing payment walker and gate chain.
- Fix paths, imports, environment variable names, and smoke scripts after the rename.
- Keep the no-API-key mode working.
- Remove any fallback that makes cached data look live.
- Update the main screen and copy to describe SpendOS honestly.

**Done when:** the existing demo starts and its smoke tests pass from a clean checkout.

## Version 1 — Upload and understand a statement

Goal: turn a real CSV into trustworthy financial data.

- Add one CSV upload flow.
- Initially support `date`, `description`, and `amount`.
- Show a preview before import.
- Normalize merchant names.
- Store transactions in the Jac graph.
- Report malformed and duplicate rows.
- Show total income, total spending, and transaction count.

**Done when:** a user can upload the sample statement and see correct totals from live data.

## Version 2 — Find subscriptions

Goal: deliver the first unmistakably useful feature.

- Port the deterministic recurring-charge detector from killBill.
- Detect monthly, quarterly, and annual cadence.
- Show merchant, amount, frequency, next expected charge, and confidence.
- Calculate total monthly and annual subscription cost.
- Detect simple price increases.
- Add focused tests for recurrence and merchant normalization.

**Done when:** SpendOS reliably finds the subscriptions in the sample statement without an LLM.

## Version 3 — Add one real agent loop

Goal: make SpendOS agentic without making it complicated.

- Give one unified SpendOS agent typed tools:
  - inspect subscriptions;
  - inspect spending totals;
  - inspect price changes;
  - read saved preferences;
  - propose an action.
- Produce `KEEP`, `REVIEW`, `DOWNGRADE`, or `CANCEL`.
- Show one short reason and expandable evidence.
- Validate every agent result.
- Recalculate all savings deterministically.
- Fall back to useful deterministic results if the model is unavailable.

**Done when:** SpendOS investigates live findings and produces supported recommendations.

## Version 4 — Learn from the user

Goal: make the second run better than the first.

- Let users approve, reject, postpone, or suppress a recommendation.
- Store explicit preferences and precedents.
- Never suggest canceling a protected subscription.
- Show why a prior decision changed the current recommendation.
- Add a simple action inbox.

**Done when:** a user decision persists and changes a later analysis.

## Version 5 — Add a minimal budget

Goal: answer one question: “What can I safely spend?”

- Estimate income and fixed recurring obligations.
- Reserve upcoming subscription costs.
- Create broad categories only: essentials, bills, subscriptions, discretionary, and goals.
- Calculate one deterministic Safe to Spend value.
- Ask for confirmation when income or fixed obligations are uncertain.
- Keep detailed budget configuration out of the main experience.

**Done when:** Safe to Spend is mathematically explainable from imported transactions.

## Version 6 — Simulate one action

Goal: prove that SpendOS can move from advice to controlled action.

- Start with subscription cancellation simulation.
- Require explicit approval.
- Show the exact proposed action, expected savings, and evidence.
- Mark the result `SIMULATED`; never imply that a real cancellation occurred.
- Save the action and approval in the audit history.

**Done when:** the complete live flow works:

```text
upload
-> detect subscription
-> recommend action
-> approve
-> simulate
-> remember
```

## Only after Version 6

Add continuous account synchronization, real notifications, merchant
integrations, autonomous household replenishment, price-triggered purchasing,
and authorization for other AI agents.

These features should be implemented separately. Do not begin the next one until
the previous capability is reliable, tested, and understandable to a normal user.

## Immediate work order

1. Run and repair the renamed SpendOS smoke test.
2. Define the smallest transaction and subscription graph nodes.
3. Add the three-column CSV importer.
4. Port recurrence detection.
5. Display live subscription totals.
6. Add one SpendOS recommendation tool loop.
7. Persist one user preference.
8. Calculate Safe to Spend.
9. Simulate one approved cancellation.
10. Test the complete workflow from a clean checkout.

## First milestone acceptance criteria

- Clean setup instructions work.
- Existing SpendOS smoke tests pass.
- A real CSV can be imported.
- Totals are correct and malformed rows are visible.
- Subscriptions are detected deterministically.
- The interface uses live results only.
- The application works without an API key.
- With an API key, one agent produces validated recommendations.
- A user decision persists between runs.
- One cancellation can be approved and simulated.
