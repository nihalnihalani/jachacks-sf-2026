# SpendOS Product Plan

## Vision

SpendOS is an always-on financial agent that watches spending, subscriptions,
and financial waste so the user does not have to.

Its promise is simple:

> Connect your financial activity once. SpendOS stays on top of the rest.

SpendOS is not another passive budgeting dashboard. It continuously evaluates
financial activity, learns what is normal for the user, recommends useful
actions, and acts automatically only when an explicit mandate allows it.

## Objectives

1. Import real financial transactions from bank-statement CSVs.
2. Detect recurring charges, subscriptions, price changes, waste, and anomalies.
3. Maintain an automatically generated monthly budget.
4. Give the user one reliable Safe to Spend number.
5. Produce prioritized actions instead of passive charts.
6. Learn from approvals, rejections, and corrections.
7. Simulate external actions safely before connecting real financial services.
8. Govern purchases requested by AI agents through explicit user mandates.

## Target users

The long-term audience is any adult who earns and spends money. The product must
not require financial or technical expertise.

The first version is optimized for someone who:

- has checking or credit-card statements;
- pays for several recurring services;
- wants to reduce waste but rarely audits transactions;
- finds manual budgeting tedious; and
- wants automation without surrendering control of consequential actions.

## Primary use cases

### Continuous spending analysis

SpendOS learns normal merchants, categories, amounts, and timing. It detects
unusual charges, accelerating spending, duplicate payments, budget exhaustion,
and transactions requiring review.

### Subscription protection

SpendOS detects monthly, quarterly, and annual recurring charges, price
increases, duplicate or overlapping services, unexpected renewals, and newly
appearing subscriptions.

Subscription recommendations use these outcomes:

- `KEEP`
- `REVIEW`
- `DOWNGRADE`
- `CANCEL`
- `NEGOTIATE`
- `UNKNOWN`

### Automatic budgeting

SpendOS estimates income, fixed obligations, essential variable spending,
subscriptions, discretionary spending, savings goals, and a protected buffer.

The authoritative number is calculated deterministically:

```text
Safe to Spend =
Expected Income
- Fixed Obligations
- Upcoming Recurring Charges
- Goal Contributions
- Protected Buffer
- Expected Essential Spending
- Spending Already Committed
```

### Agent purchase protection

SpendOS evaluates purchase requests against the user's budget and the requesting
agent's mandate. It approves, blocks, or escalates requests while preserving an
auditable authority chain.

Initial simulated purchasing scenarios are:

1. Replenishing approved household essentials.
2. Buying a specified item when price, deadline, and budget conditions are met.
3. Authorizing carts submitted by another AI agent.

## Autonomy and approval model

SpendOS uses progressive autonomy. It may never expand its own authority.

### Automatic

- Parse, normalize, and categorize transactions.
- Detect recurring charges and price changes.
- Calculate budgets and forecasts.
- Identify anomalies and potential waste.
- Draft recommendations and merchant communications.
- Recalculate Safe to Spend.
- Learn from explicit user corrections.
- Simulate actions permitted by a mandate.

### Requires approval

- Cancel or downgrade a subscription.
- Send merchant communications.
- Begin bill negotiation.
- Purchase from an unfamiliar merchant.
- Create a recurring payment.
- Make an expensive or unusual purchase.
- Change protected budget categories.
- Change savings or debt goals.
- Move real money.

### Automatable under an explicit mandate

- Approved household replenishment.
- Planned price-triggered purchases.
- Approved carts from another AI agent.
- Low-risk merchant communication.
- Rebalancing within discretionary budget categories.

## User experience

SpendOS presents one unified agent. Specialist tools remain internal.

### Onboarding

1. Upload one or more bank-statement CSVs.
2. Preview the detected columns and transactions.
3. Confirm only uncertain or consequential assumptions.
4. Select financial priorities.
5. Let SpendOS build the first budget and begin monitoring.

### Home

The home screen contains:

- Safe to Spend;
- one concise financial status;
- the most important recommended action;
- recent SpendOS activity; and
- a way to ask SpendOS a question.

### Agent inbox

Ordinary recommendations are grouped into one approval queue. Users can approve,
reject, postpone, or permanently suppress a recommendation.

### Notifications

Immediate notifications are reserved for unauthorized agent purchases, large
unexpected charges, imminent expensive renewals, and serious budget risk.
Everything else is grouped into a daily or weekly summary.

## Functional requirements

### CSV ingestion

- Detect common date, description, debit, credit, and amount columns.
- Support common date and amount conventions.
- Preview mappings before import.
- Report malformed rows instead of silently discarding them.
- Prevent duplicate imports.
- Record the source of each transaction.

### Financial intelligence

- Normalize merchant identities.
- Distinguish income, transfers, refunds, payments, and spending.
- Detect recurring cadence and expected next charge.
- Track merchant and subscription price history.
- Calculate category and merchant baselines.
- Attach confidence to inferred facts.
- Separate observations from agent interpretations.

### Recommendations

Every recommendation includes:

- proposed action;
- monthly and annual impact;
- supporting evidence;
- confidence;
- reversibility;
- approval level; and
- whether each claim is observed, inferred, or externally verified.

### Preference memory

SpendOS remembers protected merchants, category corrections, rejected
recommendations, approved substitutions, notification preferences, financial
priorities, and agent mandates. Users can inspect and delete learned preferences.

### Simulated actions

The first version produces exact execution previews and audit records without
external side effects. Simulated actions must never appear completed in the real
world.

## Non-functional requirements

### Simplicity

- The home screen must be understandable within five seconds.
- Onboarding must avoid a long questionnaire.
- Advanced evidence is collapsed by default.
- Routine events should not create frequent notifications.

### Reliability

- Financial arithmetic must be deterministic.
- The application must remain useful without an LLM key.
- Identical inputs must produce identical transaction and budget calculations.
- Failed analysis must be visible.
- Cached demo data must never masquerade as live output.

### Privacy and security

- Minimize retention of raw financial files.
- Delete temporary uploads.
- Avoid exposing full financial details in logs.
- Minimize and disclose financial data sent to models.
- Add authentication, encryption, and tenant isolation before real accounts.
- Require explicit mandates and auditable approval for every external action.

### Explainability

Every recommendation must explain what happened, why it matters, what SpendOS
proposes, what evidence supports it, and what approval would do.

## Technical architecture

### Core stack

- **Jac:** graph schema, walkers, persistence, public endpoints, and agent orchestration.
- **Python:** CSV parsing, recurrence detection, statistical baselines, and budget arithmetic.
- **byLLM:** interpretation, prioritization, explanations, and constrained tool selection.
- **Typed Jac objects:** strict contracts for recommendations and agent results.
- **SQLite if needed:** local structured persistence alongside the Jac graph.
- **Plaid later:** read-only transaction synchronization.
- **Merchant integrations later:** verified cancellation and purchasing actions.

### Core graph

```text
User -> Account -> Statement -> Transaction -> Merchant
                                      |
                                      +-> Subscription

User -> Budget -> BudgetCategory
User -> FinancialGoal
User -> Preference
User -> Mandate -> AgentIdentity

Recommendation -> Evidence
Recommendation -> ActionRequest
Decision -> Precedent
```

### Core walkers and components

- `ImportStatement`: validate and import transactions.
- `DetectSubscriptions`: find recurring charges and price changes.
- `BuildBudget`: calculate categories, reserves, and Safe to Spend.
- `MonitorFinances`: compare current behavior against historical baselines.
- `ReviewRecommendation`: investigate findings with typed tools.
- `AuthorizeAction`: enforce mandates and approval requirements.
- `RememberDecision`: turn explicit user decisions into inspectable precedent.
- `SimulateAction`: preview an external action without executing it.

## Delivery phases

### Phase 1 — Functional financial core

- Reliable CSV import.
- Transaction graph.
- Merchant normalization.
- Subscription and price-change detection.
- Automatic first budget.
- Safe to Spend.
- Deterministic tests.

### Phase 2 — Unified SpendOS agent

- Typed analysis tools.
- Prioritized recommendations.
- Evidence records.
- Financial tribunal.
- Preference and precedent memory.
- Graceful no-key behavior.

### Phase 3 — Simple user experience

- Import onboarding.
- Home.
- Agent inbox.
- Subscriptions.
- Minimal budget detail.
- Conversation.
- Mandate settings.

### Phase 4 — Safe action simulation

- Cancellation and downgrade previews.
- Household replenishment mandates.
- Planned price-triggered purchases.
- External-agent purchase authorization.
- Approval and audit lifecycle.

### Phase 5 — Continuous operation

- New-statement monitoring.
- Scheduled analysis.
- Daily or weekly summaries.
- Renewal, price-change, anomaly, and budget-risk alerts.

### Phase 6 — Real connectivity

- Authentication and tenant isolation.
- Read-only bank connectivity.
- Incremental transaction synchronization.
- Encryption and secrets management.
- Real notifications.

### Phase 7 — Controlled execution

Add one capability at a time: merchant communication, subscription
cancellation, household replenishment, price-triggered purchasing, and
agent-to-agent purchase authorization.

## Risks and trade-offs

### CSV input is not genuinely real-time

The first version monitors imported financial state. It must not claim real-time
protection until live account synchronization exists.

### Waste is subjective

Payment history cannot prove non-use. Uncertain cases must be recommendations,
not automatic cancellations.

### Models can hallucinate

Financial totals are recalculated deterministically. External prices,
cancellation channels, and merchant facts must be verified or labeled
unverified. Invalid model output defaults to `REVIEW`.

### Simplicity can hide important reasoning

Show one short explanation by default and make structured evidence expandable.

### Autonomy can undermine trust

Batch ordinary approvals, interrupt only for urgent events, and require an
explicit revocable mandate for every automatic external action.

## Testing and validation

### Unit tests

- CSV mapping and parsing.
- Merchant normalization.
- Duplicate imports.
- Recurrence and cadence.
- Price changes, refunds, and reversals.
- Income detection.
- Budget and Safe to Spend arithmetic.
- Mandate limits.
- Recommendation validation.

### Scenario tests

- Duplicate subscriptions.
- Annual renewal approaching.
- Protected subscription.
- Unusual but legitimate large payment.
- Unfamiliar recurring charge.
- Month-end overspending.
- Household replenishment.
- Price-triggered purchase.
- Unauthorized agent cart.

### End-to-end test

```text
CSV upload
-> graph creation
-> subscription detection
-> budget calculation
-> recommendation
-> user approval
-> simulated action
-> precedent memory
-> changed behavior on the next run
```

### Security tests before live integrations

- Cross-user isolation.
- Malicious file uploads.
- Prompt injection through transaction descriptions.
- Unauthorized walker invocation.
- Mandate escalation.
- Replay attacks.
- Secret and log leakage.

## Acceptance criteria for the first usable version

- A user can upload a real bank-statement CSV.
- Invalid or skipped rows are clearly reported.
- Transactions persist as graph records.
- Recurring charges have cadence and confidence.
- Subscription totals are calculated deterministically.
- SpendOS creates an initial budget and Safe to Spend value.
- At least three useful recommendations are generated from the sample data.
- Every recommendation separates facts from inferences.
- Users can approve, reject, postpone, or suppress recommendations.
- Approved actions are simulated and clearly labeled.
- Decisions affect later recommendations.
- The core remains useful without an LLM key.
- No cached result is presented as live analysis.
- The primary workflow has a passing automated end-to-end test.

## Assumptions

- SpendOS is a responsive web application initially.
- One unified SpendOS agent is visible; specialist tools remain internal.
- Balanced budget optimization is the default.
- CSV data is real; external actions are simulated initially.
- Real purchases and cancellations come after read-only account connectivity.
- Jac walkers, mandates, the tribunal, and precedent memory remain foundational.
- Functionality, trust, and simplicity take priority over visual spectacle.
