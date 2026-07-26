include gates;

with entry {
    p = Principal(name="Nihal"); t = Treasury(label="household");
    mer = Merchant(name="FreshMart", category="grocery", allowlisted=True);
    root ++> p; root ++> t; root ++> mer;
    m = Mandate(intent_text="groceries, under $200/week");
    ag = AgentIdentity(handle="shopper-01");
    p +>: Authorizes() :+> m;
    m +>: Delegates(scope="grocery") :+> ag;
    t +>: Funds(cap=500.0) :+> ag;
    print("1 typed endpoints :", [t ->:Funds:->][0].handle, "|",
          [p ->:Authorizes:->][0].intent_text, "|",
          [edge m ->:Delegates:-> ag][0].scope);

    g1 = CapGate(label="CapGate", limit=250.0); root ++> g1;
    g2 = IntentMatchGate(label="IntentMatchGate", allowed_categories=["grocery"]);
    g3 = Settled(label="Settled");
    g1 +>: Next() :+> g2;
    g2 +>: Next() :+> g3;
    g1 +>: Escalates() :+> g3;
    print("2 Next/Escalates  :", [g1 ->:Next:->][0].label, "|", [g1 ->:Escalates:->][0].label);

    ok = Payment(payment_id="p1", amount=120.0, merchant="FreshMart", category="grocery");
    g1 spawn ok;
    print("3 PASS            :", ok.verdict, "|", ok.halted_at, "|", ok.signals);

    bad = Payment(payment_id="p2", amount=340.0, merchant="FreshMart", category="grocery");
    g1 spawn bad;
    print("4 BLOCK at gate   :", bad.verdict, "|", bad.halted_at, "|", bad.reason);

    wrong = Payment(payment_id="p3", amount=50.0, merchant="FreshMart", category="giftcard");
    g1 spawn wrong;
    print("5 BLOCK on intent :", wrong.verdict, "|", wrong.halted_at, "|", wrong.reason);

    # Funds edge ability, inherited `can fund with Treasury entry`
    f1 = Payment(payment_id="p4", amount=300.0, merchant="FreshMart"); t spawn f1;
    print("6 meter           :", f1.verdict, f1.signals, "spent =", [edge t ->:Funds:->][0].spent);
    f2 = Payment(payment_id="p5", amount=300.0, merchant="FreshMart"); t spawn f2;
    print("7 cap blown       :", f2.verdict, "|", f2.halted_at, "|", f2.reason);

    r = Ruling(blocked=True, reason="gift card", confidence=0.91);
    atk = Attack(label="recat", amount=340.0, merchant="FreshMart",
                 category="grocery", technique="recategorize");
    pre = Precedent(fingerprint="FreshMart|grocery|340", verdict="BLOCKED", reason="gift card");
    pre.hit_count += 1; root ++> pre;
    cf = CaseFile(payment_id="p2", verdict="BLOCKED", halted_at="CapGate",
                  reason="over cap", signals=["cap:ok"], elapsed_ms=12);
    root ++> cf;
    print("8 value objs      :", r.confidence, "|", atk.technique, "|",
          pre.hit_count, "|", cf.elapsed_ms);

    print("9 before revoke   :", len([m ->:Delegates:->]));
    for e in [edge m ->:Delegates:-> ag] { del e; }
    print("10 after revoke   :", len([m ->:Delegates:->]));
    print("SCHEMA + GATES INTEGRATION OK");
}
