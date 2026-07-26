# SpendOS Product and Architecture Plan

## Product thesis

SpendOS is a quiet financial agent that finds money problems, investigates
them, asks only for decisions that matter, and remembers the answer.

The long-term promise is:

> SpendOS stays on top of your spending, subscriptions, and agent purchases so
> you do not have to.

The first product is intentionally narrower:

> Upload a real statement. SpendOS finds recurring charges, investigates the
> most important ones, and gives you a trustworthy action inbox.

This wedge is small enough to make reliable and valuable enough to earn the
right to expand into budgeting, live account monitoring, and controlled
purchasing.

## What changed from the original plan

The original plan was directionally strong but too broad. It combined
subscription management, budgeting, anomaly detection, merchant communication,
household purchasing, price monitoring, agent authorization, and bank
connectivity before proving one complete behavior.

The revised plan makes these corrections:

1. **One vertical slice first.** Subscription Guardian is the initial product.
2. **No false “always-on” claim.** CSV analysis is snapshot-based. Continuous
   monitoring begins only when new data is synced or imported.
3. **One source of truth.** The Jac graph is canonical. Do not add SQLite unless
   measured limitations require it.
4. **The graph is load-bearing.** Agent tools and walkers read the same graph
   that the importer writes.
5. **Walkers are used selectively.** Use functions for pure parsing and
   calculation; use walkers for per-user persistence, traversal, and workflows.
6. **Agentic means a closed loop.** Observe, investigate, propose, obtain
   authority, verify, and learn.
7. **Version-sensitive Jac behavior is gated by executable compatibility
   tests.** Do not make a product invariant depend on an unverified language
   feature.

## Initial user and job

The long-term audience is broad, but the first product is for an adult who:

- has six to eighteen months of bank or card transactions;
- pays for several recurring services;
- does not regularly audit those services;
- wants clear savings actions rather than another finance dashboard; and
- will grant automation only after SpendOS demonstrates good judgment.

Their job to be done is:

> “Tell me what recurring charges deserve attention, explain why, and remember
> what I decide.”

## North-star experience

The user uploads a statement and sees:

```text
SpendOS reviewed 1,842 transactions

12 recurring charges found · $286/month
3 need attention · up to $74/month recoverable

[Review 3 actions]
```

The user should not be asked to configure categories, agents, graphs, or models
before receiving value.

## First complete product loop

```text
Import
-> normalize
-> detect recurring charges
-> create subscription cases
-> investigate high-value cases
-> propose actions
-> user decides
-> simulate the action
-> verify the simulated result
-> store precedent
-> behave differently on the next run
```

This is the minimum acceptable meaning of “agentic” for SpendOS. A chat response
or one-shot classification is insufficient.

## Product scope

### Release 1: Subscription Guardian

Included:

- CSV import with a visible mapping preview.
- Idempotent transaction ingestion.
- Merchant normalization.
- Monthly, quarterly, and annual recurrence detection.
- Subscription price history and increase detection.
- Ranked action inbox.
- `KEEP`, `REVIEW`, `DOWNGRADE`, and `CANCEL` recommendations.
- Evidence-backed explanations.
- Approve, reject, postpone, protect, and correct actions.
- Preference and precedent memory.
- Simulated cancellation or downgrade.
- Deterministic no-key operation.

Not included:

- Real bank connections.
- Real cancellation.
- Money movement.
- Bill negotiation.
- Autonomous shopping.
- Credit, debt, investment, or net-worth products.
- A full budgeting suite.
- Claims of real-time monitoring.

### Release 2: Budget Guard

Add only after Subscription Guardian is reliable:

- Income and fixed-obligation confirmation.
- Upcoming recurring-charge reserve.
- Broad spending groups.
- A deterministic Safe to Spend value.
- Month-end risk forecast.
- One weekly financial summary.

Safe to Spend is not part of Release 1 because incorrect income or transfer
classification can make it actively misleading.

### Release 3: Connected Monitor

- Authentication and per-user roots.
- Read-only account synchronization.
- Incremental transaction ingestion.
- Scheduled monitoring.
- Renewal, price-change, and unusual-charge notifications.
- Explicit retention and deletion controls.

Only this release may use “always on” literally.

### Release 4: Controlled Action

- Verified merchant action channels.
- Real cancellation with explicit approval.
- Execution state machine and failure recovery.
- Post-action verification.
- Revocable mandates for low-risk repeated actions.

### Release 5: Agent Spending

- Household replenishment mandates.
- Planned price-triggered purchases.
- Purchase requests from other AI agents.
- Budget, merchant, purpose, recurrence, and authority checks.

The current payment firewall becomes a capability of SpendOS at this stage,
not the initial consumer surface.

## Experience principles

### One agent

The user sees SpendOS, not a committee of specialist agents. Internal tools can
have distinct responsibilities, but the product owns one voice and one decision
history.

### One primary surface

The home screen contains:

- recurring monthly total;
- potential recoverable amount;
- number of actions needing attention;
- the highest-value action; and
- recent SpendOS activity.

Detailed graphs, agent traces, and raw evidence are secondary inspection views.

### One interruption policy

Interrupt immediately only for:

- an unfamiliar new recurring charge;
- a large unexpected price increase;
- a connected agent purchase outside its mandate; or
- a time-sensitive high-cost renewal.

Group ordinary findings into one digest or action inbox.

### Progressive disclosure

Each action shows:

1. a one-sentence recommendation;
2. expected impact;
3. confidence and approval requirement; and
4. expandable evidence.

### Honest states

Use explicit states:

```text
DETECTED
INVESTIGATING
PROPOSED
AWAITING_APPROVAL
APPROVED
REJECTED
SIMULATED
EXECUTING
SUCCEEDED
FAILED
VERIFIED
```

The first release stops at `SIMULATED`. It must never render a simulation as a
completed external action.

## Decision policy

### Deterministic responsibilities

- CSV validation and row normalization.
- Transaction identity and deduplication.
- Recurrence and cadence calculations.
- Price history.
- Monthly and annual totals.
- Savings arithmetic.
- Confidence thresholds.
- Approval requirements.
- Action-state transitions.
- Mandate enforcement.

### LLM responsibilities

- Explain ambiguous merchant descriptions.
- Compare likely service overlap.
- Prioritize cases based on structured evidence.
- Propose an action and concise rationale.
- Select investigation tools when a case is ambiguous.
- Draft optional merchant communication.

### Prohibited LLM authority

The LLM may not:

- calculate authoritative financial totals;
- invent usage evidence;
- assert current prices or cancellation channels without verification;
- execute an action;
- widen a mandate;
- bypass a required approval; or
- convert malformed output into a default approval.

Invalid or unsupported model output becomes `REVIEW`.

## Jac-native architecture

### Language workflow

Jac implementation work begins with the installed compiler, not remembered
syntax:

```bash
jac --version
jac guide --search <topic>
jac check .
jac check --lint .
jac fmt
jac test
jac build
```

Use `jac precommit` as the combined format/check gate. Use `jac mcp` when an AI
coding assistant needs live documentation and compiler validation. Refresh
project-local exported skills with `jac guide --export .claude/skills` whenever
the pinned Jac version changes.

Check the current release notes before changing syntax, configuration,
persistence, codespaces, or byLLM behavior.

## Architecture rule

Use Jac where topology, persistence, per-user state, and mobile computation
matter. Do not translate every function into a walker merely to increase the
Jac feature count.

### Functions

Use ordinary typed functions for:

- CSV dialect and column detection;
- row parsing;
- merchant string normalization;
- date and amount conversion;
- recurrence statistics;
- deterministic totals; and
- typed validation.

These operations do not become more expressive by traversing a graph.

### Walkers

Use walkers for:

- committing an approved import into a user's graph;
- traversing transactions into merchant and subscription histories;
- creating and updating cases;
- investigating a subscription across evidence, preferences, and precedents;
- processing an approval workflow;
- applying a decision to future cases; and
- authorizing another agent's purchase.

### Public versus private entry points

- Use a simple public function for an unauthenticated CSV mapping preview.
- Use private walkers for user data and persistent workflows once authentication
  is enabled.
- Never place financial records under a shared public root.
- In the prototype, explicitly label the graph single-user and do not imply
  tenant isolation.

### Full-stack boundary

Keep frontend and backend in Jac. The client should spawn typed server walkers
or call public functions directly rather than introducing Express and manual
JSON endpoints.

Client calls must handle:

- loading;
- success;
- empty results;
- typed validation failure;
- server failure; and
- retry without duplicating graph data.

### byLLM contract

Use typed objects and `sem` annotations for delegated judgment. The model
returns a small result:

```text
SubscriptionAssessment
  verdict
  reason
  evidence_ids
  confidence
  proposed_action
```

The result references evidence already present in the graph. Free-form prose is
not accepted as evidence.

Use one agentic call for ambiguous cases:

```text
assess_subscription(
    case_id,
    tools=[
        read_charge_history,
        read_price_change,
        read_user_preference,
        read_precedent,
        compare_portfolio_overlap
    ]
)
```

Jac code validates cited evidence, recomputes impact, and enforces the approval
policy after the call.

### Graph model

Core nodes:

```text
UserRoot
Account
Statement
Transaction
Merchant
Subscription
SubscriptionCase
Evidence
Recommendation
Decision
Preference
Precedent
ActionRequest
ActionAttempt
Mandate
AgentIdentity
```

Meaningful typed edges:

```text
UserRoot -Owns-> Account
Account -ImportedFrom-> Statement
Statement -Contains-> Transaction
Transaction -PaidTo-> Merchant
Transaction -InstanceOf-> Subscription
SubscriptionCase -About-> Subscription
SubscriptionCase -SupportedBy-> Evidence
Recommendation -Proposes-> ActionRequest
Decision -Resolves-> SubscriptionCase
Decision -Creates-> Precedent
Mandate -DelegatesTo-> AgentIdentity
```

Edges should carry relationship data when it belongs to the relationship:

- `Contains.row_number`
- `InstanceOf.match_confidence`
- `SupportedBy.weight`
- `DelegatesTo.scope`
- `DelegatesTo.expires_at`

### Load-bearing graph traversal

`InvestigateSubscription` must traverse:

```text
SubscriptionCase
-> Subscription
-> Transactions
-> Merchant
-> Preferences
-> Prior Decisions
-> Evidence
```

Deleting the graph must change the result. If analysis can run identically from
an isolated dictionary, the graph is decorative and the design should be
revisited.

### Edge-ability compatibility gate

The original project depends on an edge ability for funding metering. Treat this
as version-sensitive behavior rather than a permanent language guarantee.

Before retaining that dependency:

1. Pin the Jac version.
2. Add a five-line executable compatibility test proving the edge ability fires.
3. Run it in CI.
4. Provide a node/walker fallback for the budget check.

Product correctness must not depend on behavior that the pinned runtime and CI
do not prove.

### Persistence and idempotency

Jac graph state persists between runs, so every mutating walker needs an
idempotency key.

Recommended identities:

- statement: hash of normalized file content plus account;
- transaction: account, posted date, normalized description, amount, and source
  row discriminator;
- subscription case: subscription plus analysis version plus observation window;
- action attempt: action request plus execution nonce.

Repeated import or retry must not create duplicate transactions, cases, or
actions.

### Concurrency

Do not use module-global mutable evidence for user workflows. Evidence belongs
to a case or walker instance. Global evidence can leak across simultaneous
requests and makes tests order-dependent.

### Canonical storage

Use the Jac graph as the canonical application state. A relational index may be
added later only after a benchmark demonstrates a query or reporting need.
Avoid dual writes during the prototype.

## Data contracts

### Transaction

Required:

- stable id;
- account id;
- posted date;
- raw description;
- normalized merchant;
- signed amount;
- currency;
- source statement;
- import row;
- classification;
- classification confidence.

### Subscription

- merchant;
- cadence;
- median amount;
- amount variation;
- first and last observed charge;
- next expected charge;
- detection confidence;
- price history;
- protected status.

### Evidence

- id;
- source type;
- observed fact;
- observation window;
- confidence;
- adverse or supporting;
- data provenance;
- created by deterministic code or model.

### Recommendation

- verdict;
- case id;
- cited evidence ids;
- reason;
- deterministic monthly impact;
- deterministic annual impact;
- confidence;
- required approval;
- model and prompt-contract version.

## Import strategy

Do not promise universal CSV detection initially.

Release 1 supports:

```text
date, description, amount
```

and one explicit mapping screen for alternatives. Use adapter tests to add bank
formats incrementally.

The importer must:

- preview before committing;
- show rejected rows and reasons;
- handle debit sign conventions;
- require a currency;
- capture timezone/statement period where available;
- detect duplicate files and rows; and
- make retry safe.

## Recommendation ranking

Rank action inbox items deterministically:

```text
priority =
financial_impact
* confidence
* urgency
* reversibility_weight
```

Apply product rules:

- unknown new recurrence outranks portfolio optimization;
- imminent renewal outranks a distant renewal;
- high-impact price increase outranks small overlap;
- low-confidence advice cannot become `CANCEL`;
- protected subscriptions cannot receive cancel recommendations.

## Success metrics

### First-session value

- Import completion rate.
- Time from upload to first useful finding.
- Percentage of imported rows accepted.
- Subscription detection precision on labeled fixtures.
- Number of actionable cases, not total alerts.

### Trust

- Unsupported-claim rate.
- User correction rate.
- Recommendation rejection rate.
- Duplicate-alert rate.
- Actions shown with valid evidence.

### Agent quality

- Valid typed-output rate.
- Evidence citation validity.
- Correct escalation to `REVIEW`.
- Deterministic outcome stability with the LLM disabled.
- Reduction in repeated model calls after precedent is learned.

Do not use “amount potentially saved” as the sole success metric. Inflated
cancel recommendations can optimize that number while destroying trust.

## Testing strategy

### Jac compatibility tests

- The native Jac binary version is pinned and recorded.
- `jac guide` is refreshed for that version.
- Project compiles.
- Client/server imports compile.
- Private/public visibility behaves as expected.
- Graph persists between runs.
- Edge ability behavior is proven or the fallback is used.
- `jac precommit`, `jac test`, and `jac build` pass.

### Deterministic unit tests

- CSV mapping and parsing.
- Amount sign and currency.
- Duplicate import.
- Merchant normalization.
- Monthly, quarterly, and annual cadence.
- Price changes.
- Refunds and reversals.
- Savings arithmetic.
- Ranking.
- State transitions.

### Graph traversal tests

- Correct nodes and typed edges are created.
- Investigation reaches only the current user's graph.
- Case evidence is traversed rather than passed as a detached blob.
- A learned precedent changes the next walk.
- Repeated imports do not change counts.

### Agent contract tests

- Malformed output becomes `REVIEW`.
- Cited evidence exists and belongs to the case.
- Unsupported claims are rejected.
- Deterministic arithmetic overrides model arithmetic.
- Protected subscriptions cannot be canceled.
- No-key mode remains useful.

### Full story

```text
clean graph
-> import statement
-> detect subscriptions
-> create case
-> investigate
-> approve simulated action
-> store precedent
-> re-import safely
-> rerun
-> observe changed recommendation with no duplicate data
```

Run this story at least three consecutive times because persistence defects often
appear only after the first run.

## Acceptance criteria for Release 1

- Clean checkout setup is documented and reproducible.
- The pinned Jac version compiles and starts the application.
- A real three-column CSV can be previewed and imported.
- Invalid rows are visible with specific reasons.
- Reimporting the same file creates zero duplicates.
- Transactions, merchants, and subscriptions form a traversable typed graph.
- Monthly, quarterly, and annual fixtures are detected deterministically.
- Subscription totals and price changes are correct.
- At least one ambiguous case invokes the typed SpendOS agent.
- Every model-backed recommendation cites valid graph evidence.
- Invalid model output safely becomes `REVIEW`.
- Users can approve, reject, postpone, protect, and correct a recommendation.
- An approved action is clearly simulated and recorded.
- A decision creates precedent that changes the next analysis.
- The application remains useful without an API key.
- No cached result is presented as live analysis.
- The complete story passes three consecutive runs.

## Explicitly unresolved

- Exact pinned Jac version after compatibility verification.
- Authentication approach for the connected release.
- Bank-data provider and supported countries.
- Verified cancellation providers.
- Model/provider selection and data-retention terms.
- How subscription overlap will be externally verified.

These decisions do not block Release 1.
