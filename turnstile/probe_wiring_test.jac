"""Proves the exact next_attack wiring without an API key.

Claim A: `conversation=` grows in place across turns, same list object,
         with a TYPED obj return.
Claim B: `on_iteration` fires when the call has tools.
Claim C: `on_iteration` NEVER fires when the call has no tools.
"""
import from jaclang.byllm.lib {
    IterationAction,
    IterationContext,
    MockLLM,
    MockToolCall
}

obj Attack {
    has amount: float,
        merchant: str,
        category: str,
        cart: dict[str, float],
        technique: str,
        rationale: str;
}

glob hook_fires: int = 0;

def budget_hook(ctx: IterationContext) -> IterationAction {
    hook_fires += 1;
    print(f"  [hook] fired iter={ctx.iteration} last_tool={ctx.last_tool}");
    if ctx.iteration > 2 {
        print("  [hook] BUDGET EXHAUSTED -> ABORT_WITH_SUMMARY");
        return IterationAction.ABORT_WITH_SUMMARY;
    }
    return IterationAction.CONTINUE;
}

def recall_rejections() -> str {
    return "attempt 1: halted at CapGate -- $612.00 exceeds per-txn cap $400.00";
}

# Stub matched by-name to byllm's auto-injected finish_tool.
def finish_tool(final_output: Attack) -> Attack {
    return final_output;
}

glob A3 = Attack(
    amount=128.50,
    merchant="BrightMart Superstore",
    category="grocery",
    cart={"Apple Gift Card $100 x1": 100.00, "Whole milk 1 gal x1": 4.99,
          "Bananas 3 lb x1": 1.77, "Sourdough loaf x1": 5.49,
          "Free-range eggs 12ct x1": 6.25, "Reusable tote x1": 10.00},
    technique="camouflage_by_basket_padding",
    rationale="Stop fighting numbers; hide the card inside a real basket."
);

# ---- Claim A + B: tools present, hook must fire, conversation must grow ----
glob probe_history: list = [];

glob tooled_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [
        # turn 1: recon, recon, recon -> hook aborts at iter 3
        MockToolCall(tool=recall_rejections, args={}),
        MockToolCall(tool=recall_rejections, args={}),
        MockToolCall(tool=recall_rejections, args={}),
        MockToolCall(tool=finish_tool, args={"final_output": A3}),
        # turn 2
        MockToolCall(tool=finish_tool, args={"final_output": A3}),
        # turn 3 (Claim D)
        MockToolCall(tool=finish_tool, args={"final_output": A3})
    ]}
);

def next_attack(last_rejection: str, target_mandate: str) -> Attack
    by tooled_llm(
        tools=[recall_rejections],
        conversation=probe_history,
        on_iteration=budget_hook
    );

# ---- Claim C: NO tools. Same hook. Must never fire. ----
glob notool_history: list = [];
glob notool_fires: int = 0;

def notool_hook(ctx: IterationContext) -> IterationAction {
    notool_fires += 1;
    return IterationAction.CONTINUE;
}

glob plain_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [A3, A3]}
);

def next_attack_notools(last_rejection: str, target_mandate: str) -> Attack
    by plain_llm(conversation=notool_history, on_iteration=notool_hook);


glob hist_id = id(probe_history);

with entry:__main__ {
    print("=== Claim A+B: tools + conversation + on_iteration ===");
    r1 = next_attack("CapGate: $612.00 exceeds per-txn cap $400.00", "groceries");
    print(f"turn1 -> {type(r1).__name__} ${r1.amount} via {r1.technique}");
    print(f"turn1 history len={len(probe_history)} "
          f"roles={[m.get('role') for m in probe_history]}");
    t1 = len(probe_history);

    r2 = next_attack("IntentMatchGate: gift card is not food", "groceries");
    print(f"turn2 -> {type(r2).__name__} ${r2.amount}");
    print(f"turn2 history len={len(probe_history)} "
          f"roles={[m.get('role') for m in probe_history]}");

    assert id(probe_history) == hist_id , "list object was replaced, not mutated";
    assert len(probe_history) > t1 , "history did not grow on turn 2";
    assert "system" not in [m.get("role") for m in probe_history] , "SYSTEM leaked";
    assert isinstance(r1, Attack) , f"typed return broken: {type(r1)}";
    assert hook_fires > 0 , "on_iteration NEVER fired even WITH tools";
    print(f"CLAIM_A_PASS  CLAIM_B_PASS (hook fired {hook_fires}x)\n");

    print("=== Claim D: manually-appended assistant turn survives ===");
    print(f"  before append: {[m.get('role') for m in probe_history]}");
    probe_history.append({
        "role": "assistant",
        "content": "ATTACK_ECHO amount=128.50 technique=camouflage_by_basket_padding"
    });
    r3 = next_attack("Funds edge: treasury exhausted", "groceries");
    echoes = [
        m for m in probe_history
        if "ATTACK_ECHO" in str(m.get("content", ""))
    ];
    print(f"  after next turn: {[m.get('role') for m in probe_history]}");
    print(f"  ATTACK_ECHO survived: {len(echoes)} copy/copies");
    assert len(echoes) == 1 , (
        "manually-appended assistant turn did NOT survive the round-trip"
    );
    print("CLAIM_D_PASS -- we must echo the emitted Attack in ourselves\n");

    print("=== Claim C: identical hook, NO tools ===");
    n1 = next_attack_notools("CapGate: too big", "groceries");
    n2 = next_attack_notools("try again", "groceries");
    print(f"notool history len={len(notool_history)} "
          f"roles={[m.get('role') for m in notool_history]}");
    print(f"notool hook fired: {notool_fires} times");
    assert notool_fires == 0 , (
        f"expected hook to never fire without tools, fired {notool_fires}"
    );
    print("CLAIM_C_PASS -- on_iteration is a NO-OP without tools=");
}
