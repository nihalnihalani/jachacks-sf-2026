"""TURNSTILE gate chain.

The payment IS the walker. Authorization is a route it must survive.

Design note (learned the hard way -- see CLAUDE.md): `disengage` is only
valid inside a WALKER ability (error[E2083]). So the walker owns traversal
control, and each Gate subtype owns its own `judge()`. The gate still
reasons about itself -- polymorphic dispatch on `here` -- but there is
exactly one place where a payment can die, which is also exactly one place
to instrument.

This module runs standalone with ZERO LLM calls. That is the demo-safety
floor: the deterministic layer is a complete product on its own, and every
agentic layer is additive.
"""

include schema;

# -------------------- gate hierarchy --------------------

node Gate {
    has label: str = "Gate";

    def judge(amount: float, merchant: str, category: str) -> Ruling {
        return Ruling(blocked=False);
    }
}

node CapGate(Gate) {
    has limit: float = 500.0;

    def judge(amount: float, merchant: str, category: str) -> Ruling {
        if amount > self.limit {
            return Ruling(blocked=True, confidence=1.0,
                reason=f"${amount:.2f} exceeds per-transaction cap of ${self.limit:.2f}");
        }
        return Ruling(blocked=False);
    }
}

node VelocityGate(Gate) {
    has max_in_window: int = 3,
        seen: int = 0;

    def judge(amount: float, merchant: str, category: str) -> Ruling {
        self.seen += 1;
        if self.seen > self.max_in_window {
            return Ruling(blocked=True, confidence=1.0,
                reason=f"{self.seen} charges in window, limit is {self.max_in_window}");
        }
        return Ruling(blocked=False);
    }
}

node SanctionsGate(Gate) {
    has blocklist: list[str] = [];

    def judge(amount: float, merchant: str, category: str) -> Ruling {
        for bad in self.blocklist {
            if bad.lower() in merchant.lower() {
                return Ruling(blocked=True, confidence=1.0,
                    reason=f"'{merchant}' matches sanctions entry '{bad}'");
            }
        }
        return Ruling(blocked=False);
    }
}

node IntentMatchGate(Gate) {
    has mandate_text: str = "",
        allowed_categories: list[str] = [];

    # Seam for the real `by llm()` judgment -- tribunal.jac overrides this.
    # The deterministic stand-in keeps smoke fast, free and repeatable.
    def judge(amount: float, merchant: str, category: str) -> Ruling {
        if self.allowed_categories and category not in self.allowed_categories {
            return Ruling(blocked=True, confidence=0.9,
                reason=f"mandate authorizes {self.allowed_categories}; this cart is '{category}'");
        }
        return Ruling(blocked=False, confidence=0.6);
    }
}

node Settled(Gate) {}

# -------------------- the walker --------------------

walker Payment {
    has payment_id: str = "",
        amount: float = 0.0,
        cart: dict = {},
        merchant: str = "",
        category: str = "",
        agent_handle: str = "",
        verdict: str = "OK",
        halted_at: str = "",
        reason: str = "",
        signals: list[str] = [],
        tokens_used: int = 0;

    # One control site: every payment that dies, dies here.
    can screen with Gate entry {
        if isinstance(here, Settled) {
            self.verdict = "ALLOWED";
            self.halted_at = here.label;
            self.reason = "all gates cleared";
            disengage;
        }
        r = here.judge(self.amount, self.merchant, self.category);
        self.tokens_used += r.tokens;
        if r.blocked {
            self.verdict = "BLOCKED";
            self.halted_at = here.label;
            self.reason = r.reason;
            disengage;
        }
        self.signals.append(f"{here.label}:ok");
        visit [-->];
    }
}
