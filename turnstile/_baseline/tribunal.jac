"""Owns obj Ruling and EVERY `by llm()` that returns it (contract rule R3)."""
import os;
import from jaclang.byllm.lib { Model }

obj Ruling {
    has blocked: bool = False,
        uncertain: bool = False,
        reason: str = "",
        confidence: float = 0.0,
        tokens: int = 0;
}

glob llm = Model(model_name="anthropic/claude-sonnet-4-6");

def llm_live -> bool {
    if os.environ.get("TURNSTILE_FORCE_DETERMINISTIC", "") { return False; }
    return bool(os.environ.get("ANTHROPIC_API_KEY", ""));
}

def _judge_llm(cart: dict, mandate: str) -> Ruling by llm();

def _judge_rules(cart: dict, mandate: str) -> Ruling {
    """Layer-2 deterministic judge. Zero tokens, fully explainable.""";
    cat = str(cart.get("category", "")).lower();
    allowed = ["grocery", "groceries", "food", "produce"];
    if cat and cat not in allowed {
        return Ruling(blocked=True, confidence=0.9, tokens=0,
            reason=f"cart category '{cat}' is outside mandate scope");
    }
    if float(cart.get("amount", 0.0)) > 200.0 {
        return Ruling(blocked=False, uncertain=True, confidence=0.5, tokens=0,
            reason="in-scope category but unusually large basket");
    }
    return Ruling(blocked=False, confidence=0.8, tokens=0, reason="cart consistent with mandate");
}

def judge_intent(cart: dict, mandate: str) -> Ruling {
    """THE integration seam. Never raises. Degrades L1 -> L2 silently.""";
    if llm_live() {
        try { return _judge_llm(cart, mandate); }
        except Exception as e { return _judge_rules(cart, mandate); }
    }
    return _judge_rules(cart, mandate);
}

def adjudicate(cart: dict, mandate: str, chain: list) -> Ruling {
    """Tribunal. Convergence rule: 2+ signals to BLOCK, else REVIEW.""";
    base = judge_intent(cart, mandate);
    signals = 0;
    if base.blocked { signals += 1; }
    if float(cart.get("amount", 0.0)) > 200.0 { signals += 1; }
    if not cart.get("allowlisted", True) { signals += 1; }
    if signals >= 2 {
        return Ruling(blocked=True, confidence=0.85, tokens=base.tokens,
            reason=f"tribunal: {signals} corroborating signals -- {base.reason}");
    }
    return Ruling(blocked=False, uncertain=True, confidence=0.5, tokens=base.tokens,
        reason=f"tribunal: only {signals} signal, routing to human REVIEW");
}

with entry:__main__ {
    print(f"llm_live={llm_live()}");
    r = judge_intent({"category":"giftcard","amount":340.0}, "groceries under $200/wk");
    print(f"giftcard -> blocked={r.blocked} :: {r.reason}");
    r2 = judge_intent({"category":"grocery","amount":45.0}, "groceries under $200/wk");
    print(f"grocery  -> blocked={r2.blocked} :: {r2.reason}");
}
