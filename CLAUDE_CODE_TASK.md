# CLAUDE_CODE_TASK.md — SpendOS Agentic Purchase Layer

You are implementing the SpendOS Purchase Agent (a.k.a. "Version 7"). The full
design spec is in `spendos_agentic_purchase_layer.md`. Read it once, then work
from this file. This file is the source of truth for **what to build, in what
order, and what not to touch.**

---

## How to use this file

- Do **one sub-version per session** (7.0, then 7.1, …). Do not start the next
  until the current one's acceptance test passes from a clean checkout.
- Every session ends with a runnable product and a passing smoke test. If you
  cannot get there, revert your changes rather than leaving the build broken.
- If a task is ambiguous, stop and ask. Do not guess at financial logic.

---

## Non-negotiable rules (apply to EVERY session)

1. **Live data only.** Never fabricate product IDs, prices, quantities, ETAs, or
   balances. No cached/mocked value may be presented as live.
2. **Determinism decides.** Affordability, limits, patterns, and risk are decided
   by deterministic code, not the LLM. The model orchestrates and explains only.
   Recompute every total from tool output.
3. **Simulate before real.** Every order ends as `SIMULATED` and is written to
   the audit history. `checkout_and_pay` stays behind a feature flag that is
   **OFF** until task 7.6.
4. **Validate every tool result** before acting. Malformed/missing → stop before
   any purchase and report.
5. **Gates are deterministic and testable without the LLM.** Each gate is unit-
   testable in isolation and returns `pass | warn | block` with a reason.
6. **No new engines.** Reuse existing SpendOS logic (see below). If you think you
   need a new engine, stop and ask first.

---

## Reuse — do NOT rebuild these

| Need | Reuse |
|---|---|
| Merchant normalization | V1 importer |
| "Is this already recurring / a duplicate?" | V2 recurring detector (killBill port) |
| Day-of-week + per-category frequency | existing spending profile / transaction graph |
| "Can I afford it?" | V5 Safe to Spend (deterministic) |
| Protected / suppressed / always-ask merchants, precedents | V4 preferences |
| Validated tool loop, deterministic recompute, LLM-optional fallback | V3 agent loop |
| Approval + `SIMULATED` marker + audit history | V6 simulation flow |
| Graph storage (order/cart/audit nodes) | Jac graph |

If any of these engines is missing or incomplete, **stop and report it** — do not
paper over it with a mock.

---

## Never touch / never enable (until told)

- Do **not** enable `checkout_and_pay` or any real charge, real bank connection,
  real cancellation, or merchant integration before task 7.6.
- Do **not** put payment credentials in the model context or in prompts. The
  store tool holds the saved method; the model only triggers it.
- Do **not** add continuous account sync, notifications infra, or a large
  dashboard as part of this layer.
- Do **not** modify V0–V6 behavior. You extend the graph and add a walker; you
  do not change existing engines' outputs.

---

## The build ladder

Implement in order. Each task lists Goal / Reuse / Build / Do NOT / Acceptance.

### 7.0 — Simulated order, no gates
- **Goal:** one-line request → correct SIMULATED order from live catalog data.
- **Reuse:** merchant normalization; Jac graph for order/cart nodes.
- **Build:** parse instruction → `resolve_products` → `add_to_cart` →
  `view_cart` → `simulate_order`. Handle missing quantity (assume 1, note it) and
  out-of-stock (note, ask; never auto-substitute).
- **Do NOT:** add any gate yet; call `checkout_and_pay`.
- **Acceptance:** from a clean checkout, "buy 1 kg potato, onion, and tomato from
  Instacart" produces a SIMULATED order with correct line items and a real total
  read from `view_cart`; order is written to audit history marked `SIMULATED`.

### 7.1 — Budget gate (Safe to Spend)
- **Goal:** catch over-budget orders deterministically.
- **Reuse:** V5 Safe to Spend.
- **Build:** budget gate returning `pass` (fits discretionary), `warn` (over
  discretionary, under total available), `block` (over total available). Wire it
  as the first gate in the chain.
- **Acceptance:** an order within Safe to Spend passes; one over discretionary
  returns `warn`; one over total available returns `block`. Numbers match V5
  exactly (assert equality against Safe to Spend, no re-derivation).

### 7.2 — Recurring + duplicate gates
- **Goal:** stop the user re-buying something they already pay for, and block
  exact duplicate orders.
- **Reuse:** V2 recurring detector.
- **Build:** `check_if_recurring` per item during resolve; recurring gate →
  `warn` if item matches a subscription, `block` on an exact duplicate inside the
  repeat window.
- **Acceptance:** requesting a known subscription (e.g. a streaming service)
  raises `warn` before adding; submitting the same cart twice inside the window
  raises `block`.

### 7.3 — Limit + pattern gates
- **Goal:** flag large and out-of-pattern spending.
- **Reuse:** spending profile (rolling average, day-of-week × category).
- **Build:** limit gate (absolute ceiling + relative ×-average trigger); pattern
  gate (category × day-of-week deviation + short-window frequency / bad-habit
  nudge). Mild first deviation → `warn`, not `block`.
- **Acceptance:** an order above the ceiling → `block`; above the ×-average
  trigger → `warn`; an atypical-day treat purchase → `warn` with a plain reason.

### 7.4 — Fraud + preference gates, and approval
- **Goal:** cover fraud signals and honor user preferences; make CONFIRM block.
- **Reuse:** V4 preferences.
- **Build:** fraud gate (new/changed address, price far above market, unknown/
  spoofed store); preference gate (suppressed / always-ask → `warn`; protected-
  never → `block`). Implement `request_approval` as a true interrupt: emit, end
  turn, require a fresh explicit "yes" before `simulate_order` becomes reachable.
- **Acceptance:** any `warn` routes to `request_approval` and nothing simulates
  until an explicit yes; a `block` gate declines with the gate named; silence or
  "no" never purchases.

### 7.5 — Audit + precedent learning
- **Goal:** decisions persist and change the next run.
- **Reuse:** V6 audit; V4 precedents.
- **Build:** `record_audit` for every order (order, gate results, marker,
  approval). Approve/reject/suppress writes a precedent that alters a later
  analysis.
- **Acceptance:** approving an order once and re-running a similar order reflects
  the precedent (e.g. an always-ask merchant now auto-proceeds, or a suppressed
  one is declined); the change is explainable from the stored precedent.

### 7.6 — Enable real checkout (flagged, last)
- **Goal:** allow real payment only after the simulated flow is proven.
- **Build:** `checkout_and_pay` reachable **only** when `real_checkout` flag is
  ON **and** the order reached PROCEED (or CONFIRM + approval). Default flag OFF.
- **Do NOT:** enable the flag in committed config; leave it off by default.
- **Acceptance:** with the flag OFF, no code path reaches a real charge; with the
  flag ON in a test, only an approved/PROCEED order charges, and the audit entry
  is marked `REAL`.

---

## Overall outcome logic (already specified — implement, don't reinvent)

Gate chain order: **budget → recurring → limit → pattern → fraud → preference.**
- Any `block` → **DECLINE** (notify, name the gate, give smallest fix; no purchase).
- Any `warn` → **CONFIRM** (`request_approval`, wait for explicit yes).
- All `pass` and in budget → **PROCEED** (`simulate_order`; real only if 7.6 flag on).
- When two outcomes could apply, choose the more cautious one.

Discounts: auto-apply coupons that reduce cost of items already in cart. "Buy more
to save" deals are only surfaced, and only if the extra still fits Safe to Spend
and isn't a bad-habit category. A discount that pushes over budget is not a saving.

---

## Session protocol

**Start of session:** state which sub-version you're on; confirm the previous one
passes from a clean checkout; list the files you'll touch.

**End of session:** run the smoke test; report pass/fail; if it fails, revert.
Never leave the build red. Never mark a task done without its acceptance test
green from a clean checkout.

## Definition of done (whole layer)

- Clean setup works; all prior SpendOS smoke tests still pass.
- A one-line request produces a correct SIMULATED order from live data.
- All six gates run deterministically and are individually tested.
- CONFIRM truly blocks on human approval; DECLINE never purchases.
- A user decision persists and changes a later run.
- `checkout_and_pay` is unreachable unless the flag is explicitly ON.

---

## Progress log

### 7.0 — DONE (session: 2026-07-26)

Implemented: `purchase.jac` (catalog, cart, order domain model + pure parsing),
`data/catalog.csv` (live store catalog fixture), six new endpoints in
`endpoints.sv.jac` (`resolve_products`, `add_to_cart`, `view_cart`,
`simulate_order`, `record_audit`, `place_purchase`), `tests/purchase_tests.jac`.
No gates yet — every order still requires every requested item to resolve to an
in-stock catalog match, or nothing is added to the cart and nothing simulates.
`checkout_and_pay` does not exist yet (not needed until 7.6). Acceptance test
passes from a clean checkout (`jac clean --all --force && jac test`). See
`spendos/README.md` for the file-responsibility table update.

Next: 7.1 budget gate.
