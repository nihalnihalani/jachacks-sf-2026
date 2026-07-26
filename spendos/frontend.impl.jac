"""Implementations for the SpendOS frontend component.

All animation state is derived inline in `frontend.cl.jac`, so there is
nothing to implement out-of-line yet. Backend-wired walkers land here.
"""

# The live call. `root spawn` crosses cl -> sv with no fetch and no REST
# client. gate_index is authoritative: the UI reddens a box by index, so a
# gate rename on the backend can never desync the visual.
#
# `Funds` is an EDGE, not a box in the row, and reports gate_index -1 -- the
# payment died before reaching gate 0, so no box reddens and the reason line
# carries the kill. A SETTLED payment also maps to -1 (nothing red).
impl app.launch(k: str) -> None {
    tick = 0;
    key = k;
    started = True;
    running = True;
    s = SCENARIOS[k];
    try {
        result = root spawn ScreenPayment(
            payment_id=f"{k}-{len(history)}",
            amount=s["amount"],
            merchant=s["merchant"],
            category=s["category"]
        );
        r = result.reports[0];
        hi = r["gate_index"];
        if r["verdict"] == "SETTLED" { hi = -1; }
        history = history + [{
            "label": s["label"],
            "amount": s["amount"], "merchant": s["merchant"],
            "category": s["category"],
            "halt": hi, "think_at": s["think_at"], "cached": r["cached"],
            "verdict": r["verdict"], "halted_at": r["halted_at"],
            "reason": r["reason"], "reasoning": r["reasoning"],
            "tokens": r["tokens"], "latency": s["latency"], "live": True
        }];
    } except Exception as e {
        history = history + [s];
    }
}
