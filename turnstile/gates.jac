# =============================================================
# TURNSTILE - gates.jac
# The gate chain. A payment is a walker; authorization is a route
# it must survive. Every gate either lets the walker pass or kills
# it with `disengage` -- and the node it died on IS the audit record.
#
# ZERO LLM CALLS in this file. IntentMatchGate's judgment is a
# deterministic placeholder behind `use_llm`; the real `by llm()`
# declaration is the SEAM block below.
#
# THE ROUTE
#   root -> Treasury --Funds(edge ability)--> AgentIdentity --Enters-->
#     CapGate --Next--> VelocityGate --Next--> SanctionsGate
#            --Next--> IntentMatchGate --Next--> SettledGate
#                    \--Escalates--> TribunalGate --Next--> SettledGate
# =============================================================

import from tribunal { judge_intent }
import from schema {
    Ruling, Principal, AgentIdentity, Treasury, Merchant, Mandate,
    Precedent, CaseFile, Gate, Payment,
    Authorizes, Delegates, Funds, Enters, Next, Escalates
}

# =============================================================
# 1. GATE NODES
# =============================================================

# ---- Gate 1: per-transaction cap. Pure arithmetic, zero tokens. ----
node CapGate(Gate) {
    has limit: float = 200.0;

    can screen with Payment entry {
        if visitor.amount > self.limit {
            visitor.halt(
                self.label, "BLOCKED",
                f"${visitor.amount} exceeds per-txn cap ${self.limit}"
            );
            disengage;
        }
        visitor.signals.append("cap:ok");
        visit [->:Next:->];
    }
}

# ---- Gate 2: velocity / burst. Pure arithmetic, zero tokens. ----
# Stateful: the node itself is the rolling window.
node VelocityGate(Gate) {
    has window_cap: float = 1000.0,
        window_spent: float = 0.0,
        max_txns: int = 4,
        txn_count: int = 0;

    can screen with Payment entry {
        self.txn_count += 1;
        if self.txn_count > self.max_txns {
            visitor.halt(
                self.label, "BLOCKED",
                f"{self.txn_count} attempts in window exceeds burst limit {self.max_txns}"
            );
            disengage;
        }
        if self.window_spent + visitor.amount > self.window_cap {
            visitor.halt(
                self.label, "BLOCKED",
                f"${self.window_spent} + ${visitor.amount} exceeds window cap ${self.window_cap}"
            );
            disengage;
        }
        self.window_spent += visitor.amount;
        visitor.signals.append(f"velocity:ok({self.txn_count}/{self.max_txns})");
        visit [->:Next:->];
    }
}

# ---- Gate 3: sanctions. Cached OFAC SDN lookup, zero tokens. ----
# Two tiers: SDN is a hard block; the watchlist is a RISK SIGNAL that
# passes but contributes to the Tribunal's convergence count.
node SanctionsGate(Gate) {
    has sdn_list: list[str] = [],
        watchlist: list[str] = [];

    can screen with Payment entry {
        if visitor.merchant in self.sdn_list {
            visitor.halt(
                self.label, "BLOCKED",
                f"'{visitor.merchant}' is on the OFAC SDN list"
            );
            disengage;
        }
        if visitor.merchant in self.watchlist {
            visitor.signals.append(f"risk:merchant_watchlist({visitor.merchant})");
        }
        visitor.signals.append("sanctions:ok");
        visit [->:Next:->];
    }
}

# ---- Gate 4: intent match. The semantic gate. ----
node IntentMatchGate(Gate) {
    has mandate_text: str = "",
        allowed: list[str] = [],
        forbidden: list[str] = [],
        use_llm: bool = False;

    # ---------------------------------------------------------
    # LLM SEAM -- teammate wiring the real judgment replaces the
    # body of `judge` with the two commented lines below, and the
    # chain flips over by seeding `use_llm=True`. Nothing else in
    # this file changes.
    #
    #   def judge(cart: dict, mandate: str) -> Ruling by llm();
    #   sem judge = """Decide whether this cart honours the human's
    #   mandate. Set blocked=True only for a clear violation; set
    #   uncertain=True when the cart is plausible but not covered.""";
    # ---------------------------------------------------------
    # WIRED. The `by llm()` decl lives in tribunal.jac, NOT here, for two
    # verified reasons:
    #   * a node-level `by llm()` on a node whose base archetype is IMPORTED
    #     crashes the compiler (ClassInfo.__init__ missing kwargs). Every gate
    #     here inherits the imported `Gate`, so hosting the decl on the node is
    #     not an option.
    #   * keeping gates.jac free of `by llm()` is what preserves the zero-key
    #     demo-safety floor -- this file cannot accidentally reach a model.
    # judge_intent degrades on its own (no key -> rules, exception -> rules)
    # and returns tokens=0 on the deterministic path, so `use_llm` stays a
    # pure seed-time switch.
    def judge(cart: dict, mandate: str) -> Ruling {
        if not self.use_llm {
            return self.judge_offline(cart, mandate);
        }
        amt = 0.0;
        if "total" in cart { amt = float(cart["total"]); }
        mer = "";
        if "merchant" in cart { mer = str(cart["merchant"]); }
        cat = "";
        if "category" in cart { cat = str(cart["category"]); }
        return judge_intent(mandate, self.allowed, amt, mer, cat, cart);
    }

    # Deterministic placeholder. Category-based, zero tokens, and the
    # verdict shape (blocked / uncertain / pass) is identical to what
    # the LLM returns -- so swapping it in changes no call site.
    def judge_offline(cart: dict, mandate: str) -> Ruling {
        cat = str(cart.get("category", "unknown"));
        if cat in self.forbidden {
            return Ruling(
                blocked=True, uncertain=False,
                reason=f"mandate authorises {self.allowed}; this cart is '{cat}'",
                confidence=0.93, tokens=0
            );
        }
        if cat in self.allowed {
            return Ruling(
                blocked=False, uncertain=False,
                reason=f"'{cat}' is within mandate", confidence=0.95, tokens=0
            );
        }
        return Ruling(
            blocked=False, uncertain=True,
            reason=f"'{cat}' is not covered by mandate '{mandate}'",
            confidence=0.40, tokens=0
        );
    }

    can screen with Payment entry {
        visitor.mandate_text = self.mandate_text;
        r = self.judge(visitor.cart, self.mandate_text);
        visitor.tokens_used += r.tokens;

        if r.blocked {
            visitor.halt(self.label, "BLOCKED", r.reason);
            disengage;
        }
        if r.uncertain {
            visitor.signals.append(f"risk:intent_mismatch({r.reason})");
            visit [->:Escalates:->];      # route to the Tribunal
        } else {
            visitor.signals.append("intent:ok");
            visit [->:Next:->];
        }
    }
}

# ---- Gate 5: the Tribunal. Reached only on uncertainty. ----
# Sentinel's convergence rule: BLOCK only on `quorum` independent
# corroborating signals. A single signal is REVIEW (human-in-the-loop),
# never a block. That is the precision story.
node TribunalGate(Gate) {
    has quorum: int = 2;

    can screen with Payment entry {
        risks = [s for s in visitor.signals if s.startswith("risk:")];
        visitor.signals.append(f"tribunal:convened({len(risks)} signals)");

        if len(risks) >= self.quorum {
            visitor.halt(
                self.label, "BLOCKED",
                f"{len(risks)} corroborating signals: {risks}"
            );
            disengage;
        }
        if len(risks) == 1 {
            visitor.halt(
                self.label, "REVIEW",
                f"single signal {risks}; below quorum {self.quorum} - escalated to human"
            );
            disengage;
        }
        visitor.signals.append("tribunal:cleared");
        visit [->:Next:->];
    }
}

# ---- Terminal: settlement. Commits the debit on the funding edge. ----
node SettledGate(Gate) {
    can settle with Payment entry {
        if visitor.funding_source is not None {
            for e in [edge visitor.funding_source ->:Funds:->] {
                e.spent += visitor.amount;
                visitor.signals.append(f"debit:${visitor.amount}->{e.spent}/{e.cap}");
            }
        }
        visitor.halt(self.label, "SETTLED", "survived every gate");
    }
}

# =============================================================
# 2. NOTE ON THE WALKER'S OFF-CHAIN ABILITIES
# They live in schema.jac alongside `walker Payment`, not here:
# an imported archetype cannot be reopened -- re-declaring
# `walker Payment { ... }` in this file creates a SECOND, unrelated
# walker type that shadows the import. (Verified: E1030.)
# =============================================================

# =============================================================
# 3. SEED - builds the route.
#
# ORDERING IS LOAD-BEARING. Attaching a node to `root` AFTER wiring
# its edges silently drops those edges (verified on 0.34.5). Anchor
# to root FIRST, then wire outward from the anchored node.
# =============================================================

# `root` is PERSISTENT across `jac run` invocations (.jac/data/<project>.db).
# Without this, a second run starts with the treasury already drained and the
# velocity window already full -- every payment blocks at Funds. Demo-safety:
# call reset_turnstile() before seeding for a byte-identical re-run.
#
# PRECEDENT IS DELIBERATELY PRESERVED. A blanket `for n in [root -->] { del n; }`
# also deletes the Precedent nodes, which silently destroys the single best
# beat in the demo -- replaying a blocked attack and having it die instantly
# from cached case law with zero LLM calls. Transient state (treasury spend,
# velocity window, gate chain) resets; learned rulings survive. That asymmetry
# IS the feature: the system forgets the window, not the lesson.
def reset_turnstile() -> None {
    for n in [root -->] {
        if not isinstance(n, Precedent) {
            del n;
        }
    }
}

def seed_turnstile() -> Treasury {
    existing = [root -->][?:Treasury];
    if existing {
        return existing[0];
    }

    # --- anchor to root BEFORE any wiring ---
    tre = Treasury(label="household");
    root ++> tre;

    prin = Principal(name="Nihal");
    root ++> prin;

    # --- authority chain ---
    man = Mandate(
        intent_text="groceries and household supplies, under $200 per transaction",
        granted_at="2026-07-01", expires_at="2026-12-31"
    );
    prin +>: Authorizes() :+> man;

    agent = AgentIdentity(handle="shopper-01", model="claude-opus-5");
    man +>: Delegates(scope="grocery") :+> agent;

    # the funding edge: the budget lives HERE, on the edge
    tre +>: Funds(cap=400.0) :+> agent;

    # --- the route ---
    g_cap = CapGate(label="CapGate", limit=200.0);
    agent +>: Enters() :+> g_cap;

    g_vel = VelocityGate(label="VelocityGate", window_cap=2000.0, max_txns=6);
    g_cap +>: Next() :+> g_vel;

    g_san = SanctionsGate(
        label="SanctionsGate",
        sdn_list=["Nordvik Trading OOO", "Volga Shipping LLC"],
        watchlist=["QuickBuy Digital"]
    );
    g_vel +>: Next() :+> g_san;

    g_int = IntentMatchGate(
        label="IntentMatchGate",
        mandate_text=man.intent_text,
        allowed=["grocery", "household"],
        forbidden=["crypto", "wire_transfer"],
        use_llm=False
    );
    g_san +>: Next() :+> g_int;

    g_trib = TribunalGate(label="TribunalGate", quorum=2);
    g_int +>: Escalates() :+> g_trib;

    g_end = SettledGate(label="SettledGate");
    g_int +>: Next() :+> g_end;
    g_trib +>: Next() :+> g_end;

    return tre;
}

# =============================================================
# 4. PUBLIC API - auto-REST under `jac start`
# =============================================================

walker:pub SubmitPayment {
    has payment_id: str = "",
        amount: float = 0.0,
        merchant: str = "",
        category: str = "",
        cart: dict = {},
        reports: list[dict] = [];

    can submit with Root entry {
        tre = seed_turnstile();
        c = self.cart;
        if not c {
            c = {"category": self.category, "merchant": self.merchant,
                 "items": [], "total": self.amount};
        }
        pay = Payment(
            payment_id=self.payment_id, amount=self.amount,
            merchant=self.merchant, category=self.category, cart=c
        );
        tre spawn pay;
        report pay.outcome();
    }
}

walker:pub SeedTurnstile {
    has reports: list[str] = [];
    can run with Root entry {
        seed_turnstile();
        report "seeded";
    }
}
