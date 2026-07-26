obj Ruling {
    has blocked: bool = False,
        uncertain: bool = False,
        reason: str = "",
        confidence: float = 0.0;
}

node Principal     { has name: str; }
node AgentIdentity { has handle: str, model: str = "claude-sonnet-4-6"; }
node Treasury      { has label: str; }
node Merchant      { has name: str, category: str, allowlisted: bool = False; }
node Mandate       { has intent_text: str, granted_at: str = "", expires_at: str = "", revoked: bool = False; }
node Precedent     { has fingerprint: str, verdict: str, reason: str, hit_count: int = 0; }
node CaseFile      { has payment_id: str, verdict: str, halted_at: str, reason: str,
                         signals: list[str] = [], tokens_used: int = 0; }

node Gate { has name: str = "Gate"; }

walker Payment {
    has payment_id: str = "",
        amount: float = 0.0,
        cart: dict = {},
        merchant: str = "",
        agent_handle: str = "",
        verdict: str = "PENDING",
        halted_at: str = "",
        reason: str = "",
        signals: list[str] = [],
        tokens_used: int = 0;

    can start with Root entry { visit [->:Chain:->]; }

    def fingerprint -> str {
        return f"{self.merchant}|{self.cart.get('category','?')}|{int(self.amount)}";
    }
}

edge Authorizes: Principal --> Mandate {}
edge Delegates:  Mandate --> AgentIdentity { has scope: str = ""; }
edge Chain {}
edge Escalates {}

edge Funds: Treasury --> AgentIdentity {
    has cap: float = 0.0, spent: float = 0.0;
    can meter with Payment entry {
        self.spent += visitor.amount;
        if self.spent > self.cap {
            visitor.verdict   = "BLOCKED";
            visitor.halted_at = "Funds";
            visitor.reason    = f"Treasury cap ${self.cap} exhausted";
        }
    }
}
