# =============================================================
# TURNSTILE - schema.jac
# Nodes, typed edges, edge abilities, shared value objects.
# Owner: GraphArchitect.  Reconciled by the walker/traversal pass:
#   + Payment.agent_handle          (shared walker contract)
#   + Payment.verdict default "OK"  (shared walker contract)
#   + Payment.funding_source        (lets SettledGate commit the debit)
#   ~ Funds.meter is now CHECK-ONLY; the debit commits at SettledGate
#     so a payment blocked downstream does not consume the treasury.
#   + edge Enters: AgentIdentity --> Gate  (agent -> head of the chain)
# =============================================================

# ---------- shared value objects ----------

obj Ruling {
    has blocked: bool = False,
        uncertain: bool = False,
        reason: str = "",
        confidence: float = 0.0,
        tokens: int = 0;
}

obj Attack {
    has merchant: str = "",
        amount: float = 0.0,
        category: str = "",
        pitch: str = "",
        strategy: str = "";
}

# ---------- identity & authority ----------

node Principal    { has name: str; }
node AgentIdentity{ has handle: str, model: str = ""; }
node Treasury     { has label: str; }
node Merchant     { has name: str, category: str = "", allowlisted: bool = False; }

node Mandate {
    has intent_text: str,
        granted_at: str = "",
        expires_at: str = "",
        revoked: bool = False;
}

# ---------- memory & audit ----------

node Precedent {
    has fingerprint: str,
        verdict: str,
        reason: str = "",
        hit_count: int = 0;
}

node CaseFile {
    has payment_id: str,
        verdict: str,
        halted_at: str = "",
        reason: str = "",
        signals: list[str] = [],
        tokens_used: int = 0,
        latency_ms: float = 0.0,
        cached: bool = False;
}

# ---------- the route ----------
# Minimal base ONLY. gates.jac defines the real gates as subtypes.
# Endpoint types are BOUNDS, so `Gate --> Gate` accepts any subtype pair.

node Gate { has label: str; }

# ---------- the payment carrier ----------
# Declared here (not gates.jac) because the Funds edge ability below
# must name the walker type. Fields + pure helpers only; every ability
# that acts on a Payment lives on the gate NODES in gates.jac.

walker Payment {
    has payment_id: str,
        amount: float,
        cart: dict = {},
        merchant: str = "",
        agent_handle: str = "",
        verdict: str = "OK",
        halted_at: str = "",
        reason: str = "",
        signals: list[str] = [],
        tokens_used: int = 0,
        category: str = "",
        mandate_text: str = "",
        cached: bool = False,
        funding_source: Treasury | None = None;

    def fingerprint() -> str {
        return f"{self.merchant}|{self.category}|{int(self.amount)}";
    }

    def halt(gate: str, verdict: str, reason: str) -> None {
        self.verdict = verdict;
        self.halted_at = gate;
        self.reason = reason;
    }

    # ---- off-chain abilities: they steer the walker INTO the chain.
    # They live here because an imported archetype cannot be reopened
    # from gates.jac; re-declaring `walker Payment` there would create
    # a second, unrelated walker type.

    # Entry at root: find the treasury that funds this agent.
    can begin with Root entry {
        tre = [-->][?:Treasury];
        if not tre {
            self.halt("root", "ERROR", "graph not seeded - no Treasury under root");
            disengage;
        }
        visit tre;
    }

    # THE EDGE-ABILITY DEMO. `visit [edge ...]` wakes Funds.meter;
    # a plain `visit [-->]` would cross it silently and never meter.
    can fund with Treasury entry {
        self.funding_source = here;
        visit [edge ->:Funds:->];
    }

    # Funds.meter may have disengaged us already. If we are here the
    # budget cleared -- step onto the head of the gate chain.
    can enter_chain with AgentIdentity entry {
        # Only adopt the funded identity's handle when the caller did not name
        # one. The caller-supplied handle is WHO INITIATED the charge, which
        # may be a sub-agent; `here` is merely the identity whose treasury
        # edge funds it. Overwriting silently relabels a sub-agent attack as
        # its authorized parent, which is precisely the confused-deputy case
        # trace_provenance exists to catch -- it made the attack invisible.
        if not self.agent_handle {
            self.agent_handle = here.handle;
        }
        visit [->:Enters:->];
    }

    # UI contract. `gate_index` is AUTHORITATIVE and must be an int -- the
    # frontend keys the red box off it, so renaming a gate can never break
    # the visual. `halted_at` is a display string only.
    # Order is fixed: 0 CapGate, 1 VelocityGate, 2 SanctionsGate,
    #                 3 IntentMatchGate, 4 TribunalGate, 5 SettledGate.
    # `Funds` is an EDGE, not a box in the row -- a payment killed there
    # never reached gate 0, so it maps to -1 and the UI shows the kill
    # upstream of the chain rather than inventing a box for it.
    def gate_index() -> int {
        order = ["CapGate", "VelocityGate", "SanctionsGate",
                 "IntentMatchGate", "TribunalGate", "SettledGate"];
        if self.halted_at in order {
            return order.index(self.halted_at);
        }
        return -1;
    }

    def outcome() -> dict {
        return {
            "payment_id": self.payment_id,
            "amount": self.amount,
            "merchant": self.merchant,
            "category": self.category,
            "verdict": self.verdict,
            "gate_index": self.gate_index(),
            "halted_at": self.halted_at,
            "reason": self.reason,
            "reasoning": "\n".join(self.signals),
            "signals": self.signals,
            "tokens": self.tokens_used,
            "tokens_used": self.tokens_used,
            "cached": self.cached
        };
    }
}

# ---------- typed edges ----------

edge Authorizes: Principal --> Mandate {}

edge Delegates: Mandate --> AgentIdentity {
    has scope: str = "";
}

edge Funds: Treasury --> AgentIdentity {
    has cap: float, spent: float = 0.0;

    # Fires ONLY on `visit [edge -->]`. A plain `visit [-->]` silently
    # crosses this edge without metering.
    #
    # CHECK-ONLY: it does not commit `spent`. SettledGate commits the
    # debit once the payment has survived the whole route. Otherwise
    # every blocked attack would drain the treasury.
    can meter with Payment entry {
        if self.spent + visitor.amount > self.cap {
            visitor.halt(
                "Funds",
                "BLOCKED",
                f"treasury cap ${self.cap} exhausted: ${self.spent} spent + ${visitor.amount} requested"
            );
            disengage;
        }
        visitor.signals.append("funds:ok");
    }
}

edge Enters: AgentIdentity --> Gate {}
edge Next: Gate --> Gate {}
edge Escalates: Gate --> Gate {}
