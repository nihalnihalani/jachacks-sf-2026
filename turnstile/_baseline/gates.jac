"""Gate nodes. Abilities live on NODES (`with Payment entry`) so schema.jac never imports gates.jac."""
import from schema { Payment, Gate, Chain, Escalates }
import from tribunal { Ruling, judge_intent, adjudicate }
import from memory { match_precedent, write_precedent }

node CapGate(Gate) {
    has limit: float = 500.0;
    can screen with Payment entry {
        if visitor.amount > self.limit {
            visitor.verdict = "BLOCKED";
            visitor.halted_at = "CapGate";
            visitor.reason = f"${visitor.amount} exceeds per-txn cap ${self.limit}";
            disengage;
        }
        visitor.signals.append("cap:ok");
        visit [->:Chain:->];
    }
}

node VelocityGate(Gate) {
    has window_max: float = 1000.0, spent: float = 0.0;
    can screen with Payment entry {
        if self.spent + visitor.amount > self.window_max {
            visitor.verdict = "BLOCKED";
            visitor.halted_at = "VelocityGate";
            visitor.reason = f"weekly velocity ${self.window_max} would be exceeded";
            disengage;
        }
        self.spent += visitor.amount;
        visitor.signals.append("velocity:ok");
        visit [->:Chain:->];
    }
}

node SanctionsGate(Gate) {
    has blocklist: list[str] = [];
    can screen with Payment entry {
        if visitor.merchant in self.blocklist {
            visitor.verdict = "BLOCKED";
            visitor.halted_at = "SanctionsGate";
            visitor.reason = f"merchant '{visitor.merchant}' is on the OFAC SDN list";
            disengage;
        }
        visitor.signals.append("sanctions:ok");
        visit [->:Chain:->];
    }
}

node IntentMatchGate(Gate) {
    has mandate_text: str = "";
    can screen with Payment entry {
        fp = visitor.fingerprint();
        pre = match_precedent(fp);
        if pre {
            visitor.verdict   = pre.verdict;
            visitor.halted_at = "IntentMatchGate(cached)";
            visitor.reason    = f"precedent: {pre.reason}";
            visitor.signals.append("precedent:hit");
            disengage;
        }
        r = judge_intent(visitor.cart, self.mandate_text);
        visitor.tokens_used += r.tokens;
        if r.blocked {
            visitor.verdict   = "BLOCKED";
            visitor.halted_at = "IntentMatchGate";
            visitor.reason    = r.reason;
            write_precedent(fp, "BLOCKED", r.reason);
            disengage;
        }
        if r.uncertain {
            visitor.signals.append("intent:uncertain");
            visit [->:Escalates:->];
        } else {
            visitor.signals.append("intent:ok");
            visit [->:Chain:->];
        }
    }
}

node TribunalGate(Gate) {
    has mandate_text: str = "";
    can screen with Payment entry {
        r = adjudicate(visitor.cart, self.mandate_text, visitor.signals);
        visitor.tokens_used += r.tokens;
        if r.blocked {
            visitor.verdict = "BLOCKED"; visitor.halted_at = "TribunalGate";
            visitor.reason = r.reason;
            write_precedent(visitor.fingerprint(), "BLOCKED", r.reason);
            disengage;
        }
        visitor.verdict = "REVIEW"; visitor.halted_at = "TribunalGate";
        visitor.reason = r.reason;
        disengage;
    }
}

node Settled(Gate) {
    can screen with Payment entry {
        visitor.verdict = "SETTLED";
        visitor.halted_at = "Settled";
        visitor.reason = "cleared every gate";
        disengage;
    }
}

def build_chain(mandate: str, blocklist: list) -> CapGate {
    """Wires the canonical gate chain off root. Returns the head.""";
    c = CapGate(name="CapGate", limit=500.0);
    v = VelocityGate(name="VelocityGate", window_max=1000.0);
    s = SanctionsGate(name="SanctionsGate", blocklist=blocklist);
    i = IntentMatchGate(name="IntentMatchGate", mandate_text=mandate);
    t = TribunalGate(name="TribunalGate", mandate_text=mandate);
    z = Settled(name="Settled");
    root +>:Chain():+> c;
    c +>:Chain():+> v;
    v +>:Chain():+> s;
    s +>:Chain():+> i;
    i +>:Chain():+> z;
    i +>:Escalates():+> t;
    return c;
}

def reset_graph -> None {
    """Idempotency guard. Detach every gate + precedent from root so a re-run
       is byte-identical to a first run. Demo-safety rule D1.""";
    for n in [root --> ] {
        del n;
    }
}
