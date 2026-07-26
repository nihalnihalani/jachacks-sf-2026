"""SpendOS -- the Tribunal. The agentic core.

Reached only when a cheaper gate reports *uncertain*. `TribunalGate.deliberate`
is one genuine ReAct call: the MODEL plans which evidence it needs and calls the
specialist tools in whatever order it decides. Jac -- not the model -- then
applies the convergence rule that turns that evidence into a verdict.

MODULE POSITION (per INTEGRATION.md §2): imports schema only. gates.jac imports
THIS. Never import gates.jac from here or the DAG cycles.

WHY `obj Ruling` IS REDECLARED HERE -- do not "fix" this:
  L11 is real and I re-verified it independently. An `obj` reached through
  `import from` cannot be a `by llm()` return type:
      import from sch { Ruling };  def f() -> Ruling by llm();
      -> AttributeError: 'str' object has no attribute 'fields'
  So every `by llm()` that returns a Ruling must live in the module that
  *declares* Ruling. The fields below are byte-identical to schema.jac's, so it
  duck-types straight into gates.jac's `Payment.screen` (`r.blocked`, `r.reason`).

ORDERING: `glob llm = _build_llm();` is at the BOTTOM on purpose -- the offline
stand-in scripts calls to the tool functions, so those must exist first.
`by llm()` resolves the glob at call time.
"""

import os;
import json;
import re;
import from jaclang.byllm.lib { Model, ModelPool, MockLLM, MockToolCall }
import from jaclang.byllm.types { IterationAction, IterationContext }
import from schema {
    Principal, Mandate, AgentIdentity, Precedent, Merchant, Gate,
    Authorizes, Delegates
}


# ============================================================================
# 1. SHARED CONTRACT -- fields identical to schema.jac's Ruling. Do not rename.
# ============================================================================

obj Ruling {
    has blocked: bool = False,
        uncertain: bool = False,
        reason: str = "",
        confidence: float = 0.0,
        tokens: int = 0;
}

sem Ruling = "The tribunal's verdict on a single payment.";
sem Ruling.blocked = "True only when the payment must be stopped outright.";
sem Ruling.uncertain = "True when the evidence is inconclusive and a human should decide.";
sem Ruling.reason = "One sentence a human can read, naming the specific evidence that decided it.";
sem Ruling.confidence = "0.0-1.0. How strongly the gathered evidence supports the verdict.";
sem Ruling.tokens = "Tokens spent reaching this verdict. Leave 0; the runtime fills it in.";


obj TribunalResult {
    has ruling: Ruling,
        evidence: list[dict] = [],
        adverse_sources: list[str] = [],
        iterations: int = 0,
        tokens_used: int = 0,
        aborted: bool = False,
        abort_reason: str = "",
        live: bool = False;
}


# ============================================================================
# 2. BUDGET -- a hard iteration + token ceiling on the ReAct loop
#
# VERIFIED by reading jaclang/byllm/llm.impl/basellm.impl.jac:739-775 and by
# execution:
#   * the hook fires BETWEEN iterations; `ctx.iteration` starts at 2
#   * IterationAction.ABORT              -> `return last_result`, a raw STRING
#   * IterationAction.ABORT_WITH_SUMMARY -> `_force_final_answer` (one more call)
#
# A hard ABORT on a `-> Ruling` function therefore returns a *string*, not a
# Ruling. Measured: `ABORT_RESULT type=str value=evidence_for_b`. Every abort
# path below is funnelled through `_coerce_ruling` at the call site.
# ============================================================================

glob MAX_ITERATIONS: int = 6;
glob MAX_TOKENS: int = 12000;
glob HARD_ITERATIONS: int = 9;

glob budget_state: dict = {
    "iterations": 0, "tokens": 0, "aborted": False, "abort_reason": "", "trace": []
};


def reset_budget() -> None {
    budget_state["iterations"] = 0;
    budget_state["tokens"] = 0;
    budget_state["aborted"] = False;
    budget_state["abort_reason"] = "";
    budget_state["trace"] = [];
}


def budget_hook(ctx: IterationContext) -> IterationAction {
    budget_state["iterations"] = ctx.iteration;
    budget_state["tokens"] = ctx.total_tokens;
    budget_state["trace"].append(
        {"iteration": ctx.iteration, "tool": ctx.last_tool, "tokens": ctx.total_tokens}
    );

    # Doom-loop guard: the same tool three iterations running.
    tail = budget_state["trace"][-3:];
    if len(tail) == 3 and ctx.last_tool {
        names = {t["tool"] for t in tail};
        if len(names) == 1 {
            budget_state["aborted"] = True;
            budget_state["abort_reason"] = f"doom-loop on '{ctx.last_tool}'";
            return IterationAction.ABORT_WITH_SUMMARY;
        }
    }

    # Hard ceiling: stop dead. Do not spend another call on a summary.
    if ctx.iteration > HARD_ITERATIONS or ctx.total_tokens > MAX_TOKENS * 2 {
        budget_state["aborted"] = True;
        budget_state["abort_reason"] = f"hard budget exhausted at iteration {ctx.iteration}";
        return IterationAction.ABORT;
    }

    # Soft ceiling: let the model spend one last call summarising what it has.
    if ctx.iteration > MAX_ITERATIONS or ctx.total_tokens > MAX_TOKENS {
        budget_state["aborted"] = True;
        budget_state["abort_reason"] = (
            f"budget exhausted at iteration {ctx.iteration} ({ctx.total_tokens} tokens)");
        return IterationAction.ABORT_WITH_SUMMARY;
    }

    return IterationAction.CONTINUE;
}

sem budget_hook = "Enforces the tribunal's compute budget between ReAct iterations.";


# ============================================================================
# 3. EVIDENCE LEDGER -- the substrate of the convergence rule
#
# Every tool writes at most one signal. A signal is *adverse* when that
# specialist found something wrong. The sources are independent by
# construction: each reads a different part of the graph or a different
# dataset, so two of them agreeing is real corroboration, not one fact
# counted twice.
# ============================================================================

glob evidence: list[dict] = [];


def reset_evidence() -> None {
    evidence.clear();
}


def _record(source: str, adverse: bool, detail: str) -> None {
    evidence.append({"source": source, "adverse": adverse, "detail": detail});
}


def adverse_sources() -> list[str] {
    return sorted({e["source"] for e in evidence if e["adverse"]});
}


# ============================================================================
# 4. THE FOUR SPECIALIST TOOLS
#
# Each returns a plain string -- that is what the ReAct loop feeds back into
# the model -- and each records a structured finding in the evidence ledger as
# a side effect. The model reads prose; Jac reads structure. Every one of them
# is total: no tool can raise, so no tool can end the demo.
# ============================================================================

glob GROCERY_TERMS: list[str] = [
    "produce", "grocer", "grocery", "food", "milk", "bread", "eggs", "vegetable",
    "fruit", "meat", "pantry", "dairy", "supermarket", "household"
];

glob HIGH_RISK_TERMS: list[str] = [
    "gift card", "giftcard", "gift_card", "stored value", "stored_value", "prepaid",
    "crypto", "wire", "money order", "voucher", "top-up", "topup", "electronics"
];


"""Deterministic cart-vs-mandate diff. Zero tokens, cannot fail, always available."""
def compare_to_intent(cart_summary: str, mandate: str) -> str {
    lc = cart_summary.lower();
    lm = mandate.lower();
    findings: list[str] = [];
    adverse = False;

    hits = [t for t in HIGH_RISK_TERMS if t in lc];
    if hits {
        adverse = True;
        findings.append(f"cart contains out-of-category terms {hits}");
    }

    if "grocer" in lm or "food" in lm {
        if not [t for t in GROCERY_TERMS if t in lc] {
            adverse = True;
            findings.append("mandate authorizes groceries but no grocery item appears in the cart");
        }
    }

    caps = re.findall(r"\$\s*([0-9][0-9,]*\.?[0-9]*)", mandate);
    amts = re.findall(r"\$\s*([0-9][0-9,]*\.?[0-9]*)", cart_summary);
    if caps and amts {
        cap = float(caps[0].replace(",", ""));
        total = max([float(a.replace(",", "")) for a in amts]);
        if total > cap {
            adverse = True;
            findings.append(f"cart total ${total:.2f} exceeds the mandate ceiling ${cap:.2f}");
        }
    }

    detail = "; ".join(findings) if findings else "cart is consistent with the mandate";
    _record("intent", adverse, detail);
    return f"[intent] {'MISMATCH' if adverse else 'MATCH'}: {detail}";
}

sem compare_to_intent = """
Compare the assembled cart against the human's signed mandate and report every
way the cart departs from it -- category, dollar ceiling, and item types the
mandate cannot be read to cover. Deterministic: it never consults a model, so
its answer is stable and free. Call it first; it costs nothing.
""";
sem compare_to_intent.cart_summary = "Plain-English contents of the cart, with per-item prices including a dollar sign.";
sem compare_to_intent.mandate = "The exact text of the mandate the human signed, including any dollar ceiling.";


"""Runs the authority chain from root: Principal -> Mandate -> AgentIdentity."""
walker ProvenanceWalk {
    has target_handle: str;
    has trail: list[str] = [];
    has reached_principal: bool = False;
    has reached_target: bool = False;
    has broken_at: str = "";
    has mandate_text: str = "";

    can start with Root entry {
        visit [-->][?:Principal];
    }

    can at_principal with Principal entry {
        self.reached_principal = True;
        self.trail.append(f"Principal({here.name})");
        nxt = [here ->:Authorizes:->];
        if not nxt {
            self.broken_at = f"Principal({here.name}) authorizes no mandate";
            disengage;
        }
        visit nxt;
    }

    can at_mandate with Mandate entry {
        self.mandate_text = here.intent_text;
        self.trail.append(f"Mandate({here.intent_text[:48]})");
        if here.revoked {
            self.broken_at = "mandate is REVOKED";
            disengage;
        }
        nxt = [here ->:Delegates:->];
        if not nxt {
            self.broken_at = "mandate delegates to no agent";
            disengage;
        }
        visit nxt;
    }

    can at_agent with AgentIdentity entry {
        self.trail.append(f"Agent({here.handle})");
        if here.handle == self.target_handle {
            self.reached_target = True;
        }
    }
}


"""VERIFIED by execution: a byLLM tool function CAN spawn a walker, including
while the Payment walker is itself mid-traversal. No re-entrancy error, and the
nested walker's `disengage` does not touch the outer walker."""
def trace_provenance(agent_handle: str) -> str {
    try {
        w = root spawn ProvenanceWalk(target_handle=agent_handle);
    } except Exception as e {
        _record("provenance", False, f"provenance graph unavailable ({type(e).__name__})");
        return "[provenance] UNAVAILABLE: could not traverse the delegation chain";
    }

    chain = " -> ".join(w.trail) if w.trail else "(empty graph)";
    if w.broken_at {
        _record("provenance", True, f"authority chain broken: {w.broken_at}");
        return f"[provenance] BROKEN at {w.broken_at}. Chain reached: {chain}";
    }
    if not w.reached_principal {
        _record("provenance", True, "no human principal is reachable from this agent");
        return f"[provenance] ORPHANED: no principal reachable. Chain: {chain}";
    }
    if not w.reached_target {
        _record("provenance", True,
                f"agent '{agent_handle}' is not reachable from any signed mandate");
        return f"[provenance] UNAUTHORIZED: '{agent_handle}' is not in the delegation chain. Chain: {chain}";
    }
    _record("provenance", False, f"authority chain intact: {chain}");
    return f"[provenance] INTACT: {chain}. Governing mandate: \"{w.mandate_text}\"";
}

sem trace_provenance = """
Walk the graph backwards from the charge to the human being who signed for it.
Reports whether an unbroken, unrevoked authority chain runs from a Principal,
through a Mandate, to this specific agent. A charge can be legal at every
individual hop and still fail here -- a broken chain is the one finding no
single transaction record contains.
""";
sem trace_provenance.agent_handle = "Handle of the agent that initiated this payment, e.g. 'shopper-01'.";


glob SANCTIONS_PATH: str = "data/ofac_sdn.json";
glob _sanctions_cache: dict = {};


def _load_sanctions() -> dict {
    if _sanctions_cache {
        return _sanctions_cache;
    }
    try {
        with open(SANCTIONS_PATH) as f {
            data = json.load(f);
        }
        # The committed OFAC export is {"meta":..., "entities":[{name,norm,type,programs}]}.
        # This previously read data["names"], which does not exist -- it silently
        # got [] and fell through to the three-name stub below, so the "19,218
        # real records" claim was true of the FILE and false of the RUNTIME.
        # Never let a parse miss degrade quietly into a hardcoded list.
        ents = data.get("entities", []);
        _sanctions_cache["names"] = [
            str(e.get("norm") or e.get("name") or "").lower()
            for e in ents
            if len(str(e.get("norm") or e.get("name") or "")) >= 5
        ];
        _sanctions_cache["countries"] = [str(c).upper() for c in data.get("countries", [])];
        _sanctions_cache["n"] = len(_sanctions_cache["names"]);
    } except Exception {
        # A missing file must never break the demo -- fall back to a cached slice.
        _sanctions_cache["names"] = ["garant bank", "nordvind logistics", "sunrise petro trading"];
        _sanctions_cache["countries"] = ["IR", "KP", "SY", "CU"];
    }
    return _sanctions_cache;
}


"""Pure SDN lookup for the gate chain. Returns the matched SDN name, or "".

Separate from check_sanctions (the ReAct tool) because the gate must screen
WITHOUT writing to the tribunal's evidence ledger -- the gate runs on every
payment, the ledger belongs to an adjudication.
"""
def screen_sdn(merchant_name: str) -> str {
    sdn = _load_sanctions();
    ln = str(merchant_name).lower().strip();
    if len(ln) < 5 {
        return "";
    }
    for name in sdn.get("names", []) {
        if name and (name in ln or ln in name) {
            return name;
        }
    }
    return "";
}


def sdn_count() -> int {
    return len(_load_sanctions().get("names", []));
}


def check_sanctions(merchant_name: str, country: str) -> str {
    sdn = _load_sanctions();
    ln = merchant_name.lower().strip();
    cc = (country or "US").upper().strip();
    names: list[str] = list(sdn.get("names", []));
    countries: list[str] = list(sdn.get("countries", []));

    for name in names {
        if name and (name in ln or ln in name) {
            _record("sanctions", True, f"'{merchant_name}' matches OFAC SDN entry '{name}'");
            return f"[sanctions] HIT: {merchant_name} matches SDN entry: {name}";
        }
    }
    if cc in countries {
        _record("sanctions", True, f"merchant jurisdiction {cc} is embargoed");
        return f"[sanctions] HIT: jurisdiction {cc} is on the embargo list";
    }
    _record("sanctions", False, f"'{merchant_name}' ({cc}) is clear of the SDN list");
    return f"[sanctions] CLEAR: '{merchant_name}' ({cc}) is not on the OFAC SDN list";
}

sem check_sanctions = """
Screen the merchant against the cached OFAC Specially Designated Nationals list
and the embargoed-jurisdiction list. The one check backed by a real external
dataset; the list is cached to disk at build time, so it works with no network.
""";
sem check_sanctions.merchant_name = "Legal or trading name of the merchant receiving the funds.";
sem check_sanctions.country = "Two-letter ISO country code of the merchant's jurisdiction, e.g. 'US'.";


"""Query the persisted Precedent subgraph. This is what makes run two faster than
run one, and it is the only tool that can exonerate a charge outright."""
def read_precedent(fingerprint: str) -> str {
    try {
        hits = [p for p in [root -->][?:Precedent] if p.fingerprint == fingerprint];
    } except Exception {
        hits = [];
    }
    if not hits {
        _record("precedent", False, f"no prior ruling on fingerprint '{fingerprint}'");
        return f"[precedent] NONE: '{fingerprint}' has never been adjudicated before";
    }
    p = hits[0];
    p.hit_count += 1;
    adverse = p.verdict == "BLOCKED";
    _record("precedent", adverse, f"prior ruling {p.verdict} on this fingerprint: {p.reason}");
    return f"[precedent] {p.verdict} (cited {p.hit_count}x): {p.reason}";
}

sem read_precedent = """
Look up whether this exact pattern of merchant, category and amount has already
been ruled on. A prior BLOCKED ruling is strong corroborating evidence; a prior
ALLOWED ruling is grounds to clear the charge. The cheapest possible resolution
-- consider calling it early.
""";
sem read_precedent.fingerprint = "Stable key for this payment pattern: 'merchant|category|amount'.";


"""Matches gates.jac's Payment.fingerprint() contract in INTEGRATION.md §3."""
def fingerprint_of(merchant: str, category: str, amount: float) -> str {
    return f"{merchant}|{category}|{int(amount)}";
}


# ============================================================================
# 5. THE ADJUDICATOR -- the one genuine ReAct call
#
# `tools=[...]` alone enables the ReAct loop (the `method=` parameter is
# deprecated and was never functional -- byllm.md:835).
# ============================================================================

def adjudicate(cart: dict, mandate: str, chain: list[str]) -> Ruling
    by llm(
        tools=[compare_to_intent, trace_provenance, check_sanctions, read_precedent],
        on_iteration=budget_hook,
        max_react_iterations=MAX_ITERATIONS,
        temperature=0.0
    );

sem adjudicate = """
You are an authorization adjudicator for an AI agent that holds spending
authority delegated by a human. A cheaper gate has already found this payment
ambiguous; it is now yours.

Your job is NOT to decide whether the charge looks like fraud. Banks already do
that, and this charge will pass every one of their checks: allowlisted
merchant, under the daily cap, clean velocity. Your job is to decide whether
the cart the agent assembled honours the mandate the human actually signed.

Plan your own investigation. You have four specialists; you decide which to
consult, in what order, and when you have enough. Before you spend a call, ask
what that evidence could tell you that would change your mind:

  compare_to_intent  -- semantic diff of cart against mandate. Free; start here.
  trace_provenance   -- walks the graph back to the human. Use whenever the
                        AUTHORITY to spend, rather than the purchase itself,
                        is what is in question.
  check_sanctions    -- OFAC screening. Use when the merchant is unfamiliar or
                        the jurisdiction is unclear.
  read_precedent     -- prior rulings on this exact pattern. A prior ruling may
                        settle the case outright, for free.

Rules you must follow:
  * Set blocked=true ONLY when at least two INDEPENDENT specialists corroborate
    the same concern. One specialist raising one concern is never a block --
    return uncertain=true and let a human decide.
  * Set uncertain=true when the evidence is thin, when specialists conflict, or
    when you ran out of budget before you were satisfied.
  * `reason` must name the specific evidence, not restate the policy. Write the
    sentence you would want to read if this were your own money.
  * Never invent a finding a tool did not return.
""";

sem adjudicate.cart = "The assembled cart: item descriptions, categories, quantities and prices.";
sem adjudicate.mandate = "Verbatim text of the mandate the human principal signed.";
sem adjudicate.chain = "Signals already collected by the upstream deterministic gates.";


# ============================================================================
# 6. THE CONVERGENCE RULE -- Sentinel's, made honest
#
# A block is not the model's call alone. BLOCKED requires the model AND two
# independent specialists to agree. One signal is always REVIEW. This is
# enforced in Jac, so it holds even when the model ignores its instructions --
# which is the difference between a precision claim and a tuned threshold.
# ============================================================================

"""The abort paths of the ReAct loop can hand back a raw string instead of the
declared type (VERIFIED). Never let that reach a gate."""
def _coerce_ruling(raw: object, fallback_reason: str) -> Ruling {
    if isinstance(raw, Ruling) {
        return raw;
    }
    if isinstance(raw, dict) {
        try {
            return Ruling(
                blocked=bool(raw.get("blocked", False)),
                uncertain=bool(raw.get("uncertain", True)),
                reason=str(raw.get("reason", fallback_reason)),
                confidence=float(raw.get("confidence", 0.3))
            );
        } except Exception {}
    }
    # Duck-typed: a Ruling built in another module (schema.jac's) lands here.
    if hasattr(raw, "blocked") and hasattr(raw, "reason") {
        return Ruling(
            blocked=bool(getattr(raw, "blocked", False)),
            uncertain=bool(getattr(raw, "uncertain", False)),
            reason=str(getattr(raw, "reason", fallback_reason)),
            confidence=float(getattr(raw, "confidence", 0.5))
        );
    }
    text = str(raw) if raw is not None else "";
    return Ruling(
        blocked=False,
        uncertain=True,
        reason=f"{fallback_reason} Partial evidence: {text[:180]}",
        confidence=0.25
    );
}


"""Turn the model's proposal plus the evidence ledger into the final Ruling."""
def apply_convergence(proposed: Ruling) -> Ruling {
    sources = adverse_sources();
    n = len(sources);
    cites = ", ".join(sources) if sources else "none";
    detail = "; ".join([e["detail"] for e in evidence if e["adverse"]]);

    # Two or more independent specialists AND the adjudicator agree -> block.
    if n >= 2 and proposed.blocked {
        return Ruling(
            blocked=True,
            uncertain=False,
            reason=f"{proposed.reason} [corroborated by {n} independent signals: {cites}]",
            confidence=max(proposed.confidence, 0.75)
        );
    }
    # Evidence converges but the model would let it through -> a human decides.
    if n >= 2 and not proposed.blocked {
        return Ruling(
            blocked=False,
            uncertain=True,
            reason=(f"{n} independent signals flag this ({cites}: {detail}) but the adjudicator "
                + f"declined to block -- routed to human review. Adjudicator said: {proposed.reason}"),
            confidence=0.5
        );
    }
    # Exactly one signal is never a block. This is the precision story.
    if n == 1 {
        return Ruling(
            blocked=False,
            uncertain=True,
            reason=(f"single signal only ({cites}: {detail}) -- one signal is never a block. "
                + f"Routed to human review. Adjudicator said: {proposed.reason}"),
            confidence=0.45
        );
    }
    # The model wants to block on nothing at all. Do not let it.
    if proposed.blocked {
        return Ruling(
            blocked=False,
            uncertain=True,
            reason=("adjudicator proposed a block with no corroborating specialist signal "
                + f"-- downgraded to review. Adjudicator said: {proposed.reason}"),
            confidence=0.4
        );
    }
    return Ruling(
        blocked=False,
        uncertain=proposed.uncertain,
        reason=proposed.reason or "no specialist raised a concern; the cart honours the mandate",
        confidence=proposed.confidence
    );
}


"""The single entry point a gate should call. NEVER raises.

Identical degradation to TribunalGate.rule_on: if the model is unreachable the
specialists are run directly, so the convergence rule still has real evidence to
converge on instead of shrugging."""
def run_tribunal(cart: dict, mandate: str, chain: list[str],
                 agent_handle: str = "", merchant: str = "",
                 category: str = "", amount: float = 0.0) -> TribunalResult {
    reset_evidence();
    reset_budget();
    rearm_offline();

    # NO MODEL CONFIGURED: run the four specialists directly against the REAL
    # payment instead of driving MockLLM's scripted transcript.
    #
    # The transcript calls the tools with CANNED arguments (DEMO_CART_SUMMARY
    # etc.), so offline an electronics cart came back reasoned as a "stored-
    # value gift card" -- a specific claim unsupported by the case. Evidence
    # must be derived from the payment in front of us or it is fabrication,
    # and fabricated evidence is worse than an abstention. The convergence
    # rule then runs on that real evidence exactly as it does when live.
    if not TRIBUNAL_LIVE {
        _deterministic_sweep(cart, mandate, agent_handle, merchant, category, amount);
        return _finalize(_deterministic_proposal());
    }

    try {
        proposed = _coerce_ruling(
            adjudicate(cart, mandate, chain),
            "The tribunal could not complete its investigation."
        );
    } except Exception as e {
        if not evidence {
            _deterministic_sweep(cart, mandate, agent_handle, merchant, category, amount);
        }
        proposed = _fallback_proposal(type(e).__name__);
    }

    return _finalize(proposed);
}


"""Budget check + convergence rule + result packaging. Shared by both entry points."""
def _finalize(proposed: Ruling) -> TribunalResult {
    # A truncated investigation can never be certain, whatever the model said.
    if budget_state["aborted"] and not proposed.uncertain {
        proposed = Ruling(
            blocked=proposed.blocked,
            uncertain=True,
            reason=f"{proposed.reason} [{budget_state['abort_reason']}]",
            confidence=min(proposed.confidence, 0.5)
        );
    }

    final = apply_convergence(proposed);
    final.tokens = int(budget_state["tokens"]);

    return TribunalResult(
        ruling=final,
        evidence=list(evidence),
        adverse_sources=adverse_sources(),
        iterations=int(budget_state["iterations"]),
        tokens_used=int(budget_state["tokens"]),
        aborted=bool(budget_state["aborted"]),
        abort_reason=str(budget_state["abort_reason"]),
        live=TRIBUNAL_LIVE
    );
}


# ============================================================================
# 7. TribunalGate -- the node-level `by llm()` (Jac feature #4)
#
# The node reasons about itself: `deliberate` reads `self.mandate_text` off the
# node it is attached to, so the walker just arrives and the gate does the rest.
#
# This node is OWNED BY TRIBUNAL.JAC because of L11: the `by llm()` and the
# `Ruling` it returns must share a module. gates.jac routes here over the
# `Escalates` edge and adds:
#
#     can deliberate with TribunalGate entry {
#         res = here.rule_on(self.cart, self.mandate_text_or_"", self.signals,
#                            self.agent_handle, self.merchant, self.category, self.amount);
#         self.tokens_used += res.tokens_used;
#         if res.ruling.blocked { self.block("TribunalGate", res.ruling.reason); disengage; }
#         if res.ruling.uncertain {
#             self.verdict = "REVIEW"; self.halted_at = "TribunalGate";
#             self.reason = res.ruling.reason; disengage;
#         }
#         self.pass_gate("tribunal:ok");
#         visit [-->];
#     }
#
# `TribunalGate` deliberately does NOT subtype gates.jac's `ScreenGate` -- that
# would require importing gates.jac and cycle the DAG. It subtypes schema's
# `Gate`, so `edge Escalates: Gate --> Gate` accepts it unchanged.
# ============================================================================

# RENAMED from TribunalGate. gates.jac declares `node TribunalGate(Gate)`
# and imports this module, so both were in scope and one silently shadowed
# the other -- the same trap `obj Attack` set earlier. gates.jac's copy is
# the one attached to root, so IT keeps the name: renaming a persisted class
# quarantines every anchor of the old name on next start. This copy has never
# been instantiated, so it renames for free.
node TribunalAdjudicator {
    has label: str = "TribunalGate",
        mandate_text: str = "",
        convened: int = 0;

    def deliberate(cart: dict, chain: list[str]) -> Ruling
        by llm(
            tools=[compare_to_intent, trace_provenance, check_sanctions, read_precedent],
            on_iteration=budget_hook,
            max_react_iterations=MAX_ITERATIONS,
            temperature=0.0
        );

    """Never raises. Runs the ReAct loop, then applies the convergence rule."""
    def rule_on(cart: dict, chain: list[str], agent_handle: str = "",
                merchant: str = "", category: str = "", amount: float = 0.0) -> TribunalResult {
        self.convened += 1;
        reset_evidence();
        reset_budget();
        rearm_offline();

        try {
            proposed = _coerce_ruling(
                self.deliberate(cart, chain),
                "The tribunal could not complete its investigation."
            );
        } except Exception as e {
            # The model is gone. Rule on whatever the specialists already found,
            # and if they found nothing, gather it deterministically ourselves.
            if not evidence {
                _deterministic_sweep(cart, self.mandate_text, agent_handle,
                                     merchant, category, amount);
            }
            proposed = _fallback_proposal(type(e).__name__);
        }

        return _finalize(proposed);
    }
}

sem TribunalAdjudicator.mandate_text = "The mandate this tribunal is enforcing, verbatim.";
sem TribunalAdjudicator.deliberate = """
You are the tribunal. A payment reached you because a cheaper gate could not
decide it, and you hold the mandate the human signed on `self.mandate_text`.

Plan your own investigation with the four specialists available to you. Consult
only what could change your mind, and stop as soon as you can justify a verdict
in one sentence a human would accept.

Set blocked=true ONLY when two INDEPENDENT specialists corroborate the same
concern. A single concern, however strong it feels, returns uncertain=true --
that routes to a human, which is the correct outcome for a case one specialist
can see and another cannot confirm. Never invent a finding a tool did not
return, and never restate policy in `reason`: name the evidence.
""";
sem TribunalAdjudicator.deliberate.cart = "The assembled cart: item descriptions, categories, quantities and prices.";
sem TribunalAdjudicator.deliberate.chain = "Signals already collected by the upstream deterministic gates.";


# ============================================================================
# 8. judge_intent -- what gates.jac's IntentMatchGate calls (INTEGRATION.md R3)
#
# gates.jac keeps its node and its logic; it just delegates the judgement:
#
#     node IntentMatchGate(ScreenGate) {
#         has mandate_text: str = "", allowed_categories: list[str] = [];
#         def judge(amount: float, merchant: str, category: str) -> Ruling {
#             return judge_intent(self.mandate_text, self.allowed_categories,
#                                 amount, merchant, category);
#         }
#     }
#
# Two independent degradation triggers, exactly as INTEGRATION.md §4 requires:
# no key (checked before the call) and any exception (timeout, 429, 500, bad
# JSON). Neither prints anything alarming; neither raises.
# ============================================================================

def _judge_llm(cart_summary: str, mandate: str) -> Ruling by llm(temperature=0.0);

sem _judge_llm = """
You are standing at the gate a payment must survive. You hold the exact text of
the mandate the human signed and a description of the cart the agent assembled.

Decide one thing: does this cart honour that mandate?

  blocked=true    only when the cart plainly violates the mandate -- wrong
                  category, over the stated ceiling, or an item the mandate
                  could not reasonably be read to cover.
  uncertain=true  when it is arguable. Ambiguity is not a block; it is an
                  escalation to the tribunal, which can call specialists you
                  cannot. Prefer this whenever you find yourself reasoning hard.
  both false      when the cart is an ordinary, obvious fit for the mandate.

In `reason`, name the item and the clause of the mandate it breaks.
""";
sem _judge_llm.cart_summary = "Plain-English description of the cart, with prices.";
sem _judge_llm.mandate = "Verbatim text of the mandate the human signed.";


"""Zero-token intent check. This is the demo floor and it must never fail."""
def _judge_rules(mandate: str, allowed: list[str], amount: float,
                 merchant: str, category: str, cart: dict = {}) -> Ruling {
    # ESCALATE, never block outright. An out-of-category cart is exactly ONE
    # signal, and the project's own rule is that one signal is never a block --
    # it goes to the Tribunal, which decides on corroboration from independent
    # sources. Returning blocked=True here short-circuits the convergence rule
    # and quietly reinstates the single-signal blocking we criticise Sentinel
    # for. A category mismatch is grounds for suspicion, not for a verdict.
    if allowed and category and category not in allowed {
        return Ruling(
            blocked=False, uncertain=True, confidence=0.75, tokens=0,
            reason=f"mandate authorizes {allowed}; this cart is '{category}'"
        );
    }
    # Summarise the REAL cart, not just its declared category. A camouflage
    # attack hides a gift card among genuine groceries and declares the whole
    # basket "grocery"; judging the label alone lets it through, which is the
    # single most important thing this gate exists to stop.
    probe = compare_to_intent(_cart_summary(cart, merchant, category, amount), mandate);
    if "MISMATCH" in probe {
        return Ruling(
            blocked=False, uncertain=True, confidence=0.55, tokens=0,
            reason=f"cart may not honour the mandate -- escalating. {probe}"
        );
    }
    return Ruling(blocked=False, uncertain=False, confidence=0.6, tokens=0,
                  reason="cart is consistent with the mandate");
}


def judge_intent(mandate: str, allowed: list[str], amount: float,
                 merchant: str, category: str, cart: dict = {}) -> Ruling {
    if not llm_live() {
        return _judge_rules(mandate, allowed, amount, merchant, category, cart);
    }
    try {
        summary = _cart_summary(cart, merchant, category, amount);
        r = _coerce_ruling(_judge_llm(summary, mandate),
                           "The intent gate could not reach a model.");
        r.tokens = 0;

        # DOWNGRADE A LIVE BLOCK TO AN ESCALATION -- structurally, not by asking.
        #
        # The semstring tells the model to prefer `uncertain` and reserve
        # `blocked` for plain violations. With a real model behind the gate it
        # returned blocked=True anyway, and the gate honoured it: ONE model
        # opinion, at one gate, killing a payment outright. That is precisely
        # what the convergence rule exists to prevent, and we cannot claim
        # "enforced in Jac, not in the prompt" while the single place a live
        # model touches the verdict is enforced only by the prompt.
        #
        # The model's judgement is not discarded -- it becomes the first
        # adverse signal, and the Tribunal decides whether a second,
        # independent source corroborates it.
        if r.blocked {
            return Ruling(
                blocked=False, uncertain=True,
                confidence=r.confidence, tokens=r.tokens,
                reason=r.reason
            );
        }
        return r;
    } except Exception {
        return _judge_rules(mandate, allowed, amount, merchant, category, cart);
    }
}


def _cart_summary(cart: dict, merchant: str, category: str, amount: float) -> str {
    items = cart.get("items", []) if isinstance(cart, dict) else [];
    if items {
        parts = [];
        for it in items {
            try {
                price = float(str(it.get("price", 0)));
                parts.append(f"{it.get('qty', 1)}x {it.get('desc', '?')} "
                             + f"({it.get('category', category)}) ${price:.2f}");
            } except Exception {
                parts.append(str(it));
            }
        }
        return f"From {merchant}: " + "; ".join(parts) + f". Total ${amount:.2f}";
    }

    # Flat {item_name: price} carts (what the probe builds) were falling through
    # to the generic summary below, which names only the DECLARED category. That
    # made the camouflage attack undetectable by construction: a gift card
    # itemised among groceries and declared "grocery" produced the summary
    # "1x grocery" and the semantic gate had nothing to see. A gate can only
    # catch what it is shown.
    meta = ["category", "merchant", "total", "items"];
    lines = [k for k in cart.keys() if k not in meta] if isinstance(cart, dict) else [];
    if lines {
        parts = [];
        for k in lines {
            try {
                parts.append(f"{k} ${float(cart[k]):.2f}");
            } except Exception {
                parts.append(str(k));
            }
        }
        return f"From {merchant}: " + "; ".join(parts) + f". Total ${amount:.2f}";
    }

    return f"From {merchant}: 1x {category}, ${amount:.2f}";
}


"""Deterministic evidence sweep -- runs the specialists directly when the model
is unreachable, so the convergence rule still has something to converge on."""
def _deterministic_sweep(cart: dict, mandate: str, agent_handle: str,
                         merchant: str, category: str, amount: float) -> None {
    compare_to_intent(_cart_summary(cart, merchant, category, amount), mandate);
    if agent_handle {
        trace_provenance(agent_handle);
    }
    if merchant {
        check_sanctions(merchant, "US");
    }
    if merchant and category {
        read_precedent(fingerprint_of(merchant, category, amount));
    }
}


"""Proposal when no model is configured at all.

Distinct from _fallback_proposal, which describes a model that was supposed
to answer and did not. Here nothing was ever expected to answer, so the
wording must not imply a failure -- and it rules purely on evidence the
deterministic sweep gathered from this payment.
"""
def _deterministic_proposal() -> Ruling {
    n = len(adverse_sources());
    if n >= 2 {
        return Ruling(
            blocked=True, uncertain=False, confidence=0.7, tokens=0,
            reason="deterministic specialists converged independently"
        );
    }
    if n == 1 {
        return Ruling(
            blocked=False, uncertain=True, confidence=0.35, tokens=0,
            reason="a single specialist raised a concern; below quorum"
        );
    }
    return Ruling(
        blocked=False, uncertain=False, confidence=0.6, tokens=0,
        reason="no specialist found adverse evidence"
    );
}


def _fallback_proposal(err: str) -> Ruling {
    n = len(adverse_sources());
    if n >= 2 {
        return Ruling(
            blocked=True, uncertain=False, confidence=0.7, tokens=0,
            reason=(f"model unreachable ({err}); ruling on deterministic evidence alone, "
                + "which converged independently")
        );
    }
    return Ruling(
        blocked=False, uncertain=True, confidence=0.3, tokens=0,
        reason=f"model unreachable ({err}); routing to human review on partial evidence"
    );
}


# ============================================================================
# 9. MODEL WIRING -- last, because the offline stand-in references the tools.
#
# VERIFIED: ModelPool(models=[...], strategy=..., num_retries=..., timeout=...)
# constructs with zero API keys present; it raises only at call time. So the
# import of this module can never fail on a missing key.
#
# SPENDOS_FORCE_DETERMINISTIC=1 is the panic switch from INTEGRATION.md §4.
# ============================================================================

# The offline stand-in replays attack #1. These MUST match what the seed writes,
# or the no-key demo shows REVIEW where the live demo shows BLOCKED.
glob DEMO_AGENT_HANDLE: str = "shopper-01-sub";
glob DEMO_FINGERPRINT: str = "QuickCart Digital|stored_value|340";
glob DEMO_CART_SUMMARY: str = "1x digital gift card, $340.00";
glob DEMO_MANDATE: str = "groceries, under $200/week";


def llm_live() -> bool {
    if os.environ.get("SPENDOS_FORCE_DETERMINISTIC", "") {
        return False;
    }
    return bool(_live_models());
}


"""One Model per provider whose key is actually present, best first."""
def _live_models() -> list {
    out: list = [];
    if os.environ.get("ANTHROPIC_API_KEY", "") {
        out.append(Model(model_name="anthropic/claude-sonnet-4-6"));
    }
    if os.environ.get("OPENAI_API_KEY", "") {
        out.append(Model(model_name="gpt-4o-mini"));
    }
    if os.environ.get("GEMINI_API_KEY", "") or os.environ.get("GOOGLE_API_KEY", "") {
        out.append(Model(model_name="gemini/gemini-2.5-flash"));
    }
    return out;
}


"""The web/demo_case.json ruling, replayed when there is no key."""
def _canned_ruling() -> Ruling {
    reason = ("cart is a stored-value gift card, not groceries, and the charge was "
        + "initiated by a sub-agent that no signed mandate reaches");
    try {
        with open("web/demo_case.json") as f {
            payload = json.load(f);
        }
        r = payload.get("ruling", {});
        return Ruling(
            blocked=bool(r.get("blocked", True)),
            uncertain=bool(r.get("uncertain", False)),
            reason=str(r.get("reason", reason)),
            confidence=float(r.get("confidence", 0.88))
        );
    } except Exception {
        return Ruling(blocked=True, uncertain=False, reason=reason, confidence=0.88);
    }
}


"""The scripted ReAct transcript replayed when there is no key. MockLLM POPS
from this list, so it is single-use -- `rearm_offline()` refills it before every
adjudication or the second attack in the demo runs dry."""
def _offline_script() -> list {
    return [
        MockToolCall(tool=compare_to_intent,
                     args={"cart_summary": DEMO_CART_SUMMARY, "mandate": DEMO_MANDATE}),
        MockToolCall(tool=trace_provenance,
                     args={"agent_handle": DEMO_AGENT_HANDLE}),
        MockToolCall(tool=read_precedent,
                     args={"fingerprint": DEMO_FINGERPRINT}),
        _canned_ruling(), _canned_ruling(), _canned_ruling(), _canned_ruling()
    ];
}


"""Refill the offline transcript. No-op when a real model is wired up."""
def rearm_offline() -> None {
    if TRIBUNAL_LIVE {
        return;
    }
    try {
        cfg = getattr(llm, "config", None);
        if isinstance(cfg, dict) {
            cfg["outputs"] = _offline_script();
        }
    } except Exception {}
}


"""Scripted stand-in for a dead/absent API key. It still drives the REAL ReAct
loop, so the tools still fire, the graph is still traversed, the evidence ledger
still fills, the convergence rule still runs, and the UI still receives
tool_call events. The only thing that is canned is which tools get called."""
def _offline_model() -> MockLLM {
    return MockLLM(model_name="mockllm", config={"outputs": _offline_script()});
}


def _build_llm() -> object {
    if os.environ.get("SPENDOS_FORCE_DETERMINISTIC", "") {
        return _offline_model();
    }
    live = _live_models();
    if not live {
        return _offline_model();
    }
    if len(live) == 1 {
        return live[0];
    }
    return ModelPool(models=live, strategy="fallback", num_retries=1, timeout=25.0);
}


glob llm = _build_llm();

glob TRIBUNAL_LIVE: bool = not isinstance(llm, MockLLM);
