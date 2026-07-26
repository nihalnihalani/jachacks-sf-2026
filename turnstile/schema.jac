"""TURNSTILE graph schema.

Authorization is reachability: a charge is legitimate only if an unbroken
path of live mandates connects it back to a human principal. Revocation is
edge deletion. Budget lives ON the funding edge and is metered by that
edge's own ability -- money moves along an edge, and the edge is the
accountant.
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
