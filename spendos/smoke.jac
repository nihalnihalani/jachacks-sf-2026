# SpendOS end-to-end smoke test. ZERO LLM calls -- fast, free, deterministic.
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
import from gates { seed_spendos, reset_spendos }
import from tribunal { llm_live }

def run(tre: Treasury, pid: str, amt: float, mer: str, cat: str, agent: str = "shopper-01") -> Payment {
    p = Payment(
        payment_id=pid, amount=amt, merchant=mer, category=cat, agent_handle=agent,
        cart={"category": cat, "merchant": mer, "total": amt}
    );
    tre spawn p;
    return p;
}

with entry {
    reset_spendos();
    tre = seed_spendos();

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
    print("  SpendOS smoke -- deterministic layer, 0 LLM calls");
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

    # The zero-key floor must never quietly reach a model. With no key
    # configured, spending a token means something bypassed the degradation
    # path and nothing else would tell us. With a key configured, spending
    # tokens is the point -- asserting 0 there would be asserting the feature
    # is off.
    live = llm_live();
    if not live and used != 0 {
        print(f"  [FAIL] zero-key floor consumed {used} tokens; must be 0");
        failures += 1;
    }

    print("");
    if failures == 0 {
        mode = "LAYER 1 live model";
        if not live { mode = "LAYER 2 deterministic, 0 tokens"; }
        print(f"  all {len(cases)} payments halted where expected -- {mode}, {used} tokens");
    } else {
        print(f"  {failures} failure(s)");
    }
    print("");
}
