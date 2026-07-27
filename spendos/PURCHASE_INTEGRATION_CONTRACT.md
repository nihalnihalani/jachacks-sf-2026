# SpendOS Purchase Integration Contract

This contract keeps the Version 7 purchase layer, the existing SpendOS graph, and
the Hermes bridge on one workflow. It is deliberately small: Version 7 may add
catalog and cart mechanics, but it must not create a second authority for
financial safety or approval.

## Ownership

- **Hermes owns research:** interpreting the shopping request, resolving products,
  collecting evidence, and returning a verified cart.
- **SpendOS owns authority:** Safe to Spend, deterministic gates, approval,
  simulation, policy memory, and audit history.
- **The user owns irreversible authority:** a warning requires a fresh explicit
  decision bound to the exact proposal. Real checkout is outside the current
  demo.

## Canonical flow

1. SpendOS creates one `ShoppingMission`.
2. Hermes claims it and submits verified candidates.
3. The purchase layer constructs and reads back one cart.
4. SpendOS creates or updates one `PurchaseProposal`.
5. SpendOS runs deterministic gates and stores their structured results.
6. `BLOCK` ends the flow. `WARN` creates a blocking approval request. All-pass
   may proceed to simulation.
7. SpendOS records a `SIMULATED` result. No UI copy may imply a real order.

## State mapping

`ShoppingMission` remains the request/research envelope:

```text
DISPATCHED -> IN_PROGRESS -> READY_FOR_REVIEW
```

`PurchaseProposal` remains the financial-decision envelope:

```text
PROPOSED -> AWAITING_APPROVAL -> APPROVED -> SIMULATED
                         \----> REJECTED
BLOCKED
```

`Cart` and `PurchaseOrder` are Version 7 execution details. They must link to the
canonical mission/proposal rather than introduce a parallel approval state.

## Required identifiers

Every transition must be idempotent and bind to stable identifiers:

- `mission_id`: normalized request, maximum budget, and preferences.
- `cart_fingerprint`: store plus sorted product IDs, quantities, prices, fees,
  taxes, currency, and delivery-address fingerprint.
- `proposal_id`: agent, merchant/store, purpose, amount, and cadence.
- `approval_id`: proposal ID, cart fingerprint, gate-result fingerprint, and
  expiration.
- `order_id`: proposal ID and cart fingerprint.

Changing the cart total, delivery address, or a gate input invalidates any prior
approval.

## Gate result contract

Each deterministic gate returns:

```text
gate_id
gate_version
outcome: PASS | WARN | BLOCK
reason_code
human_explanation
inputs_hash
evaluated_at
```

The ordered chain is:

```text
budget -> recurring -> limit -> pattern -> fraud -> preference
```

Any `BLOCK` produces `DECLINE`; otherwise any `WARN` produces `CONFIRM`; otherwise
the result is `PROCEED`. Hermes may explain these results but may not change them.

## Data truth

- A local CSV catalog is `SIMULATED_CATALOG`, never “live commerce.”
- A real provider response is `PROVIDER_VERIFIED` and includes provider,
  retrieval time, and source identifiers.
- A synthetic bank feed remains visibly labeled synthetic.
- No price, stock state, ETA, balance, or order confirmation may be invented.

## Version 7.0 acceptance

Version 7.0 is complete when:

1. A one-line request resolves against the configured catalog source.
2. Missing quantities are explicitly noted.
3. Out-of-stock or ambiguous items stop before silent substitution.
4. Cart totals are recomputed from stored cart lines.
5. The order is persisted exactly once with status `SIMULATED`.
6. The response says no real charge occurred.
7. Existing SpendOS tests and the two-way Hermes mission test still pass.

Gates, durable approval, and real checkout are not part of Version 7.0.

## Merge boundary

During Version 7.0:

- `purchase.jac` and its focused tests belong to the purchase-layer stream.
- `frontend.cl.jac` and `styles/spendos.css` belong to the product/UI stream.
- Changes to `schema.jac`, `endpoints.sv.jac`, or `main.jac` require a small,
  reviewed export/import change and must preserve the existing public API.

