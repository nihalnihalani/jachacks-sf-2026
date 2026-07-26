# TURNSTILE end-to-end smoke test. ZERO LLM calls -- fast, free, deterministic.
#
# Run after EVERY change:  jac run smoke.jac
#
# demo.jac prints a scoreboard for humans; this file ASSERTS. It fails loudly
# when a verdict drifts, which is the only thing protecting gate semantics
# while several people edit the chain.
#
# All 7 halt locations are exercised, including the two that ARE the thesis:
#   * TribunalGate on 2-signal convergence (1 signal -> REVIEW, never BLOCKED)
#   * Funds, an EDGE, killing a payment on CUMULATIVE spend no single
#     transaction can see -- per-transaction reasoning cannot catch structuring

import from schema { Treasury, Payment }
import from gates { seed_turnstile, reset_turnstile }

def run(tre: Treasury, pid: str, amt: float, mer: str, cat: str, agent: str = "shopper-01") -> Payment {
    p = Payment(
        payment_id=pid, amount=amt, merchant=mer, category=cat, agent_handle=agent,
        cart={"category": cat, "merchant": mer, "total": amt}
    );
    tre spawn p;
    return p;
}

with entry {
    reset_turnstile();
    tre = seed_turnstile();

    cases = [
        ("s1",  45.00, "FreshMart",           "grocery",     "SETTLED", "SettledGate"),
        ("s2", 340.00, "FreshMart",           "grocery",     "BLOCKED", "CapGate"),
        ("s3",  75.00, "Nordvik Trading OOO", "grocery",     "BLOCKED", "SanctionsGate"),
        ("s4", 180.00, "QuickBuy Digital",    "gift_card",   "BLOCKED", "TribunalGate", "shopper-01-sub"),
        ("s5",  60.00, "FreshMart",           "electronics", "REVIEW",  "TribunalGate"),
        ("s6", 150.00, "FreshMart",           "grocery",     "SETTLED", "SettledGate"),
        ("s7", 150.00, "FreshMart",           "grocery",     "SETTLED", "SettledGate"),
        ("s8", 100.00, "FreshMart",           "grocery",     "BLOCKED", "Funds"),
        ("s9",  20.00, "FreshMart",           "grocery",     "BLOCKED", "VelocityGate")
    ];

    print("");
    print("  TURNSTILE smoke -- deterministic layer, 0 LLM calls");
    print("");

    failures = 0;
    used = 0;
    for c in cases {
        pid = c[0]; amt = c[1]; mer = c[2]; cat = c[3];
        want_v = c[4]; want_h = c[5];
        agent = c[6] if len(c) > 6 else "shopper-01";
        p = run(tre, pid, amt, mer, cat, agent);
        used += p.tokens_used;
        ok = (p.verdict == want_v) and (p.halted_at == want_h);
        mark = "ok  ";
        if not ok { mark = "FAIL"; failures += 1; }
        print(f"  [{mark}] {pid}  {p.verdict:<8} @ {p.halted_at:<14} {p.reason[:56]}");
        if not ok { print(f"         expected {want_v} @ {want_h}"); }
    }

    # The deterministic layer must NEVER reach a model. If this trips, the
    # zero-key demo-safety floor is gone and nothing else would tell us.
    if used != 0 {
        print(f"  [FAIL] deterministic layer consumed {used} tokens; must be 0");
        failures += 1;
    }

    print("");
    if failures == 0 {
        print(f"  all {len(cases)} payments halted where expected, 0 tokens");
    } else {
        print(f"  {failures} failure(s)");
    }
    print("");
}
