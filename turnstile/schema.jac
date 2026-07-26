"""TURNSTILE graph schema.

Authorization is reachability: a charge is legitimate only if an unbroken
path of live mandates connects it back to a human principal. Revocation is
edge deletion. Budget lives ON the funding edge and is metered by that
edge's own ability -- money moves along an edge, and the edge is the
accountant.

This module owns DATA SHAPE only and has no imports. Behavior lives in
gates.jac (gate nodes + the Payment walker), tribunal.jac, probe.jac and
memory.jac.
"""

# -------------------- identity & authority --------------------

node Principal {
    has name: str;
}

node AgentIdentity {
    has handle: str,
        model: str = "gpt-4o-mini";
}

node Treasury {
    has label: str;
}

node Mandate {
    has intent_text: str,
        granted_at: str = "",
        expires_at: str = "",
        revoked: bool = False;
}

node Merchant {
    has name: str,
        category: str,
        allowlisted: bool = False;
}

# -------------------- memory --------------------

node Precedent {
    has fingerprint: str,
        verdict: str,
        reason: str,
        hit_count: int = 0;
}

node CaseFile {
    has payment_id: str,
        verdict: str,
        halted_at: str,
        reason: str,
        signals: list[str] = [],
        tokens_used: int = 0,
        elapsed_ms: int = 0;
}

# -------------------- shared value types --------------------

obj Ruling {
    has blocked: bool = False,
        uncertain: bool = False,
        reason: str = "",
        confidence: float = 0.0,
        tokens: int = 0;
}

obj Attack {
    has label: str,
        amount: float,
        merchant: str,
        category: str,
        cart: dict = {},
        technique: str = "";
}

# -------------------- the metered walker base --------------------
# The Funds edge ability below has to name a walker type, but the real
# `Payment` walker lives in gates.jac -- naming it here would be a cycle.
# So schema.jac owns the minimal base that the funding edge needs, and
# gates.jac declares `walker Payment(Metered)`. Walker subtypes DO fire
# base-typed abilities, so `can meter with Metered entry` runs for Payment
# (and for nothing else, unlike an untyped `with entry`).

walker Metered {
    has amount: float = 0.0,
        verdict: str = "OK",
        halted_at: str = "",
        reason: str = "",
        signals: list[str] = [],
        tokens_used: int = 0;

    def block(gate: str, why: str) {
        self.verdict = "BLOCKED";
        self.halted_at = gate;
        self.reason = why;
    }

    def pass_gate(sig: str) {
        self.signals.append(sig);
    }

    # The funding hop. Subtypes inherit this, so gates.jac's Payment meters
    # the treasury for free. `[edge ...]` is what wakes Funds.meter; `:0:`
    # pushes it to the FRONT of the queue so the budget is charged before
    # the walker reaches any gate (the queue is otherwise BFS).
    can fund with Treasury entry {
        visit :0: [edge ->:Funds:->];
    }
}

# -------------------- the route --------------------
# Minimal DATA base only. Behavior lives in gates.jac as ScreenGate(Gate),
# so the two files never fight over a declaration.

node Gate {
    has label: str = "";
}

# -------------------- typed edges --------------------

edge Authorizes: Principal --> Mandate {}

edge Delegates: Mandate --> AgentIdentity {
    has scope: str = "";
}

edge Funds: Treasury --> AgentIdentity {
    has cap: float,
        spent: float = 0.0;

    # Fires ONLY when the itinerary includes the edge itself:
    #     visit :0: [edge ->:Funds:->];
    # A plain `visit [-->]` crosses this edge without waking it and the
    # treasury is silently never debited.
    #
    # No `disengage` here -- gates.jac keeps exactly one control site, in
    # the walker. This edge records the kill; the walker performs it on
    # seeing verdict == "BLOCKED".
    can meter with Metered entry {
        self.spent += visitor.amount;
        if self.spent > self.cap {
            visitor.block("Funds",
                f"treasury cap of ${self.cap:.2f} exhausted (${self.spent:.2f} committed)");
        } else {
            visitor.pass_gate("funds:ok");
        }
    }
}

# Endpoint types are BOUNDS, so `Gate --> Gate` accepts any subtype pair --
# CapGate(ScreenGate(Gate)) --> Settled(ScreenGate(Gate)) type-checks, and
# `[g ->:Next:->]` infers Gate without a `[?:Gate]` filter.
edge Next: Gate --> Gate {}

edge Escalates: Gate --> Gate {}
