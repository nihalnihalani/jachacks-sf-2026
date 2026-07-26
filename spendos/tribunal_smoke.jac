"""End-to-end proof against the real schema.jac, with no API key."""
import from schema { Principal, Mandate, AgentIdentity, Precedent, Authorizes, Delegates }
import from tribunal {
    Ruling, TribunalGate, run_tribunal, apply_convergence, judge_intent,
    compare_to_intent, trace_provenance, check_sanctions, read_precedent,
    fingerprint_of, reset_evidence, adverse_sources, llm_live, TRIBUNAL_LIVE
}

with entry {
    p = Principal(name="nihal");
    m = Mandate(intent_text="groceries, under $200/week");
    a = AgentIdentity(handle="shopper-01");
    root ++> p;
    p +>: Authorizes :+> m;
    m +>: Delegates(scope="grocery") :+> a;
    root ++> Precedent(fingerprint="QuickCart Digital|stored_value|340",
                       verdict="BLOCKED",
                       reason="a prior tribunal ruled gift cards outside the grocery mandate");

    print(f"TRIBUNAL_LIVE={TRIBUNAL_LIVE} llm_live={llm_live()}");

    print("\n--- 1. TOOLS STANDALONE ---");
    reset_evidence();
    print(compare_to_intent("1x digital gift card, $340.00", "groceries, under $200/week"));
    print(trace_provenance("shopper-01"));
    print(trace_provenance("shopper-01-sub"));
    print(check_sanctions("QuickCart Digital", "US"));
    print(check_sanctions("Nordvind Logistics", "US"));
    print(read_precedent(fingerprint_of("QuickCart Digital", "stored_value", 340.0)));
    print(f"adverse_sources={adverse_sources()}");

    print("\n--- 2. CONVERGENCE RULE ---");
    reset_evidence();
    compare_to_intent("1x digital gift card, $340.00", "groceries, under $200/week");
    r1 = apply_convergence(Ruling(blocked=True, reason="gift card", confidence=0.9));
    print(f"1 signal  -> blocked={r1.blocked} uncertain={r1.uncertain}  ({r1.reason[:60]}...)");
    trace_provenance("shopper-01-sub");
    r2 = apply_convergence(Ruling(blocked=True, reason="gift card", confidence=0.9));
    print(f"2 signals -> blocked={r2.blocked} uncertain={r2.uncertain} conf={r2.confidence}");
    print(f"            {r2.reason}");
    r3 = apply_convergence(Ruling(blocked=False, reason="looks fine", confidence=0.9));
    print(f"2 signals, model says allow -> blocked={r3.blocked} uncertain={r3.uncertain}");
    reset_evidence();
    r0 = apply_convergence(Ruling(blocked=True, reason="vibes", confidence=0.99));
    print(f"0 signals, model says block -> blocked={r0.blocked} uncertain={r0.uncertain}");

    print("\n--- 3. FULL ReAct TRIBUNAL, no key ---");
    cart = {"items": [{"desc": "digital gift card", "category": "stored_value",
                       "qty": 1, "price": 340.0}],
            "total": 340.0};
    res = run_tribunal(cart, "groceries, under $200/week", ["cap:ok", "velocity:ok"],
                       agent_handle="shopper-01-sub", merchant="QuickCart Digital",
                       category="stored_value", amount=340.0);
    print(f"blocked={res.ruling.blocked} uncertain={res.ruling.uncertain} conf={res.ruling.confidence}");
    print(f"reason: {res.ruling.reason}");
    print(f"sources={res.adverse_sources} iters={res.iterations} aborted={res.aborted} live={res.live}");
    for e in res.evidence { print(f"   [{e['source']}] adverse={e['adverse']} {e['detail'][:80]}"); }

    print("\n--- 4. NODE-LEVEL by llm() WITH TOOLS (TribunalGate) ---");
    tg = TribunalGate(label="TribunalGate", mandate_text="groceries, under $200/week");
    root ++> tg;
    out = tg.rule_on(cart, ["cap:ok", "velocity:ok"],
                     agent_handle="shopper-01-sub", merchant="QuickCart Digital",
                     category="stored_value", amount=340.0);
    print(f"convened={tg.convened} blocked={out.ruling.blocked} uncertain={out.ruling.uncertain}");
    print(f"reason: {out.ruling.reason}");
    print(f"sources={out.adverse_sources} tokens={out.ruling.tokens}");

    print("\n--- 5. judge_intent (what gates.jac calls) ---");
    j1 = judge_intent("groceries, under $200/week", ["grocery"], 340.0,
                      "QuickCart Digital", "stored_value", cart);
    print(f"wrong category -> blocked={j1.blocked} uncertain={j1.uncertain} tokens={j1.tokens}");
    print(f"   {j1.reason}");
    j2 = judge_intent("groceries, under $200/week", ["grocery"], 42.0,
                      "Whole Foods", "grocery", {});
    print(f"ordinary       -> blocked={j2.blocked} uncertain={j2.uncertain}  {j2.reason}");
    j3 = judge_intent("groceries, under $200/week", [], 340.0,
                      "QuickCart Digital", "gift_card", {});
    print(f"no allowlist   -> blocked={j3.blocked} uncertain={j3.uncertain}  {j3.reason[:80]}");
}
