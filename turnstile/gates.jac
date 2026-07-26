"""TURNSTILE gate chain.

The payment IS the walker. Authorization is a route it must survive.

Design notes (learned the hard way -- see CLAUDE.md):
  * `disengage` is only valid inside a WALKER ability (error[E2083]). So the
    walker owns traversal control and each gate owns its own `judge()`. The
    gate still reasons about itself -- polymorphic dispatch on `here` -- but
    there is exactly one place a payment can die, which is also exactly one
    place to instrument.
  * schema.jac owns `node Gate` as pure DATA. Behavior lives here, on
    `ScreenGate(Gate)`, so the two files never fight over a declaration.
  * We count LLM CALLS, never tokens. A token count coming back inside an
    LLM-generated `Ruling` would be a number the model invented.

This module runs standalone with ZERO LLM calls. That is the demo-safety
floor: the deterministic layer is a complete product on its own, and every
agentic layer is additive.
"""

include schema;

# -------------------- behavioral gate base --------------------

node ScreenGate(Gate) {
    def judge(amount: float, merchant: str, category: str) -> Ruling {
        return Ruling(blocked=False);
    }
}

node CapGate(ScreenGate) {
    has limit: float = 500.0;

    def judge(amount: float, merchant: str, category: str) -> Ruling {
        if amount > self.limit {
            return Ruling(blocked=True, confidence=1.0,
                reason=f"${amount:.2f} exceeds per-transaction cap of ${self.limit:.2f}");
        }
        return Ruling(blocked=False);
    }
}

node VelocityGate(ScreenGate) {
    has max_in_window: int = 8,
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

node SanctionsGate(ScreenGate) {
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

node IntentMatchGate(ScreenGate) {
    has mandate_text: str = "",
        allowed_categories: list[str] = [];

    # Seam for the real `by llm()` judgment. tribunal.jac subtypes this and
    # overrides `judge` -- note it takes NO mandate parameter, because the
    # LLM form reads `self.mandate_text` off the node. That is what makes the
    # node-level `by llm()` load-bearing instead of decorative.
    def judge(amount: float, merchant: str, category: str) -> Ruling {
        if self.allowed_categories and category not in self.allowed_categories {
            return Ruling(blocked=True, confidence=0.9,
                reason=f"mandate authorizes {self.allowed_categories}; this cart is '{category}'");
        }
        return Ruling(blocked=False, confidence=0.6);
    }
}

node Settled(ScreenGate) {}

# -------------------- the walker --------------------

walker Payment(Metered) {
    has payment_id: str = "",
        cart: dict = {},
        merchant: str = "",
        category: str = "",
        agent_handle: str = "",
        llm_calls: int = 0;

    # One control site: every payment that dies, dies here.
    can screen with ScreenGate entry {
        if isinstance(here, Settled) {
            self.verdict = "ALLOWED";
            self.halted_at = here.label;
            self.reason = "all gates cleared";
            disengage;
        }
        r = here.judge(self.amount, self.merchant, self.category);
        if r.blocked {
            self.block(here.label, r.reason);
            disengage;
        }
        self.pass_gate(f"{here.label}:ok");
        visit [-->];
    }
}
