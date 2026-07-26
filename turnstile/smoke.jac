"""TURNSTILE end-to-end smoke test. ZERO LLM calls -- fast, free, deterministic.

Run after EVERY change:  jac run smoke.jac

Asserts that each payment halts at the gate that should have caught it.
"""

include gates;

def build_chain() -> CapGate {
    # IDEMPOTENT SEED GUARD -- non-negotiable.
    # `root` persists across runs. Without this guard, run N builds an Nth
    # parallel gate chain and the walker traverses ALL of them: every gate
    # fires N times, the LLM gate costs N x, the scoreboard is nonsense.
    # It only manifests on run 2+, i.e. during rehearsal and on stage.
    existing = [root -->][?:CapGate];
    if existing {
        cap = existing[0];
        # The chain persists, but WINDOWED COUNTERS must not. `seen` is
        # mutable node state living on a persisted node, so without this it
        # accumulates across runs (3 -> 6 -> 9) and eventually blocks a
        # payment that should pass. Surfaced on run 3, never in dev.
        # A new run is a new velocity window.
        for v in [cap -->][?:VelocityGate] { v.seen = 0; }
        return cap;
    }

    cap  = CapGate(label="CapGate", limit=500.0);
    vel  = VelocityGate(label="VelocityGate", max_in_window=8);
    sanc = SanctionsGate(label="SanctionsGate", blocklist=["Nordkraft Holdings", "Volga Trade LLC"]);
    intent = IntentMatchGate(
        label="IntentMatchGate",
        mandate_text="groceries, under $200 per week",
        allowed_categories=["groceries", "household"]
    );
    settled = Settled(label="Settled");

    root ++> cap;
    cap ++> vel;
    vel ++> sanc;
    sanc ++> intent;
    intent ++> settled;
    return cap;
}

def run_one(chain: CapGate, p: Payment) -> Payment {
    chain spawn p;
    return p;
}

with entry {
    chain = build_chain();
    failures = 0;

    cases = [
        # (payment, expected_verdict, expected_halt)
        (Payment(payment_id="p1", amount=980.0, merchant="Whole Foods",
                 category="groceries", agent_handle="grocery-bot"),
         "BLOCKED", "CapGate"),

        (Payment(payment_id="p2", amount=64.20, merchant="Nordkraft Holdings",
                 category="groceries", agent_handle="grocery-bot"),
         "BLOCKED", "SanctionsGate"),

        (Payment(payment_id="p3", amount=340.00, merchant="Whole Foods",
                 category="gift_card", agent_handle="grocery-bot"),
         "BLOCKED", "IntentMatchGate"),

        (Payment(payment_id="p4", amount=87.50, merchant="Safeway",
                 category="groceries", agent_handle="grocery-bot"),
         "ALLOWED", "Settled"),
    ];

    print("\n  TURNSTILE smoke -- deterministic layer, 0 LLM calls\n");
    for (p, want_verdict, want_halt) in cases {
        run_one(chain, p);
        ok = (p.verdict == want_verdict) and (p.halted_at == want_halt);
        mark = "ok  " if ok else "FAIL";
        if not ok { failures += 1; }
        print(f"  [{mark}] {p.payment_id}  {p.verdict:<8} @ {p.halted_at:<16} {p.reason}");
        if not ok {
            print(f"         expected {want_verdict} @ {want_halt}");
        }
    }

    print("");
    if failures == 0 {
        print("  all gates halted where expected\n");
    } else {
        print(f"  {failures} failure(s)\n");
    }
}
