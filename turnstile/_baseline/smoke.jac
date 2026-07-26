"""TURNSTILE end-to-end smoke test. ZERO LLM calls. Run: jac run smoke.jac"""
import from schema { Payment }
import from gates { build_chain, reset_graph }

glob FAILS: int = 0;

def check(label: str, got: str, want: str) -> None {
    if got == want { print(f"  PASS  {label}: {got}"); }
    else { FAILS += 1; print(f"  FAIL  {label}: got '{got}' want '{want}'"); }
}

def run_payment(pid: str, amount: float, merchant: str, cart: dict) -> Payment {
    p = Payment(payment_id=pid, amount=amount, merchant=merchant,
                agent_handle="shopper-01", cart=cart);
    root spawn p;
    return p;
}

with entry:__main__ {
    print("== TURNSTILE smoke ==");
    reset_graph();
    build_chain("groceries, under $200/week", ["ShadyCorp"]);

    print("[1] over-cap charge should die at CapGate");
    p1 = run_payment("p1", 900.0, "Safeway", {"category":"grocery","amount":900.0});
    check("halted_at", p1.halted_at, "CapGate");
    check("verdict", p1.verdict, "BLOCKED");

    print("[2] sanctioned merchant should die at SanctionsGate");
    p2 = run_payment("p2", 50.0, "ShadyCorp", {"category":"grocery","amount":50.0});
    check("halted_at", p2.halted_at, "SanctionsGate");

    print("[3] THE MONEY SHOT: $340 gift card, allowlisted, under cap");
    p3 = run_payment("p3", 340.0, "Safeway", {"category":"giftcard","amount":340.0});
    check("halted_at", p3.halted_at, "IntentMatchGate");
    check("verdict", p3.verdict, "BLOCKED");
    check("tokens", str(p3.tokens_used), "0");

    print("[4] replay of [3] must hit the precedent cache");
    p4 = run_payment("p4", 340.0, "Safeway", {"category":"giftcard","amount":340.0});
    check("halted_at", p4.halted_at, "IntentMatchGate(cached)");

    print("[5] legit grocery run should settle");
    p5 = run_payment("p5", 45.0, "Safeway", {"category":"grocery","amount":45.0});
    check("halted_at", p5.halted_at, "Settled");
    check("verdict", p5.verdict, "SETTLED");

    print("");
    if FAILS == 0 { print("SMOKE: ALL GREEN"); }
    else { print(f"SMOKE: {FAILS} FAILURE(S)"); }
}
