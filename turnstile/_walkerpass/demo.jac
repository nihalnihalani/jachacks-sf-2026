# TURNSTILE - demo driver. Zero LLM calls.
import from schema { Treasury, Payment, Funds }
import from gates { seed_turnstile, CapGate, VelocityGate, SanctionsGate,
                    IntentMatchGate, TribunalGate, SettledGate }

def submit(tre: Treasury, pid: str, amt: float, mer: str, cat: str) -> Payment {
    p = Payment(
        payment_id=pid, amount=amt, merchant=mer, category=cat,
        cart={"category": cat, "merchant": mer, "total": amt}
    );
    tre spawn p;
    mark = "OK ";
    if p.verdict == "BLOCKED" { mark = "BLK"; }
    if p.verdict == "REVIEW"  { mark = "REV"; }
    print(f"[{mark}] {pid}  ${amt:>7.2f}  {cat:<14} {mer:<22} -> {p.verdict:<8} @ {p.halted_at}");
    print(f"        reason : {p.reason}");
    print(f"        signals: {p.signals}");
    return p;
}

with entry {
    tre = seed_turnstile();
    print("=" * 100);
    print("TURNSTILE gate chain  |  route: Funds(edge) > CapGate > VelocityGate > SanctionsGate > IntentMatchGate > [Tribunal] > Settled");
    print("=" * 100);

    res = [
        submit(tre, "p-001",   45.00, "FreshMart",           "grocery"),
        submit(tre, "p-002",  340.00, "FreshMart",           "grocery"),
        submit(tre, "p-003",   75.00, "Nordvik Trading OOO", "grocery"),
        submit(tre, "p-004",  180.00, "QuickBuy Digital",    "gift_card"),
        submit(tre, "p-005",   60.00, "FreshMart",           "electronics"),
        submit(tre, "p-006",  150.00, "FreshMart",           "grocery"),
        submit(tre, "p-007",  150.00, "FreshMart",           "grocery"),
        submit(tre, "p-008",  100.00, "FreshMart",           "grocery"),
        submit(tre, "p-009",   20.00, "FreshMart",           "grocery")
    ];

    print("=" * 100);
    for e in [edge tre ->:Funds:->] {
        print(f"funding edge after run: spent ${e.spent} / cap ${e.cap}");
    }
    print("-" * 100);
    print("HALT LOCATION SCOREBOARD (the node IS the audit record)");
    tally: dict = {};
    for p in res {
        k = f"{p.halted_at} [{p.verdict}]";
        tally[k] = tally.get(k, 0) + 1;
    }
    for (k, v) in tally.items() { print(f"   {v} x  {k}"); }
    print(f"   LLM calls: 0    tokens used: {sum([p.tokens_used for p in res])}");
}
