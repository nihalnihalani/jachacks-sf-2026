"""SpendOS — the gate chain, rendered in Jac.

Every frame of the animation is DERIVED from a single monotonic `tick`.
No timer ever mutates animation state, so there is no stale-closure class of
bug here and no way for the demo to desync mid-run.
"""

import "./styles/spendos.css";
import from react { useEffect }

# ---- the chain the walker must survive ----
glob GATES: list = [
    {"name": "CapGate",         "kind": "arithmetic"},
    {"name": "VelocityGate",    "kind": "arithmetic"},
    {"name": "SanctionsGate",   "kind": "ofac lookup"},
    {"name": "IntentMatchGate", "kind": "by llm"},
    {"name": "Tribunal",        "kind": "react · tools"},
    {"name": "Settled",         "kind": "terminal"}
];

glob DWELL: int = 7;      # ticks a deterministic gate holds the walker
glob THINK: int = 26;     # extra ticks while the LLM streams its reasoning
glob TICK_MS: int = 110;

# ---- scripted outcomes (mock path: demos with the backend down) ----
sv import from endpoints { ScreenPayment }

glob SCENARIOS: dict = {
    "attack": {
        "label": "$340 · Gift-card reseller",
        "amount": 180.0, "merchant": "QuickBuy Digital", "category": "gift_card",
        "halt": 3, "think_at": 3, "cached": False,
        "verdict": "BLOCKED", "halted_at": "IntentMatchGate",
        "reason": "Mandate authorizes groceries. This cart is a $340 gift card.",
        "reasoning": "Reading mandate: \"groceries, under $200/week\".\nCart: 1x $340 open-loop gift card, merchant allowlisted.\nCap ok. Velocity ok. Sanctions clean.\nSemantic check: a transferable gift card is not groceries.\nProvenance: instruction originated in product-page text,\nnot from the principal.\nTwo corroborating signals -> BLOCK.",
        "tokens": 1840, "latency": 2310
    },
    "replay": {
        "label": "Replay of attack #1",
        "amount": 180.0, "merchant": "QuickBuy Digital", "category": "gift_card",
        "halt": 3, "think_at": -1, "cached": True,
        "verdict": "BLOCKED", "halted_at": "IntentMatchGate (precedent)",
        "reason": "Precedent P-0x41: identical fingerprint ruled BLOCKED. 0 tokens.",
        "reasoning": "", "tokens": 0, "latency": 198
    },
    "legit": {
        "label": "$62 · Whole Foods",
        "amount": 62.0, "merchant": "FreshMart", "category": "grocery",
        "halt": -1, "think_at": 3, "cached": False,
        "verdict": "SETTLED", "halted_at": "Settled",
        "reason": "Cart matches mandate. Within cap and weekly velocity.",
        "reasoning": "Mandate: \"groceries, under $200/week\".\nCart: produce, dairy, pantry — $62.\nWeek-to-date $118 of $200.\nCart honors intent. Pass.",
        "tokens": 940, "latency": 1870
    },
    "cap": {
        "label": "$5,000 · Electronics",
        "halt": 0, "think_at": -1, "cached": False,
        "verdict": "BLOCKED", "halted_at": "CapGate",
        "reason": "$5000 exceeds per-txn cap $500. Zero tokens spent.",
        "reasoning": "", "tokens": 0, "latency": 3
    }
};


def:pub app -> JsxElement {
    has tick: int = 0,
        running: bool = False,
        key: str = "attack",
        started: bool = False,
        history: list = [];

    # The CURRENT record drives every visual: gate lamps, verdict, reasoning.
    # This returned SCENARIOS[key] unconditionally, so the whole panel rendered
    # from the script even when the live walker had already answered -- the real
    # result reached only the scoreboard and was otherwise discarded. A demo
    # that calls a real backend and then draws something else is not a live
    # demo. Prefer the latest result; fall back to the script only before the
    # first run, or when the backend was unreachable.
    def scn -> dict {
        if history {
            return history[len(history) - 1];
        }
        return SCENARIOS[key];
    }

    # Cumulative tick budget through gate `i`.
    def bound(i: int) -> int {
        s = scn();
        total = 0;
        n = 0;
        while n <= i {
            total = total + DWELL;
            if n == s["think_at"] {
                total = total + THINK;
            }
            n = n + 1;
        }
        return total;
    }

    def last_index -> int {
        s = scn();
        if s["halt"] >= 0 {
            return s["halt"];
        }
        return len(GATES) - 1;
    }

    def finished -> bool {
        return started and tick >= bound(last_index());
    }

    # idle | active | pass | halt | cache | dead
    def status(i: int) -> str {
        s = scn();
        if not started {
            return "idle";
        }
        if s["halt"] >= 0 and i > s["halt"] {
            return "dead";
        }
        if tick >= bound(i) {
            if i == s["halt"] {
                if s["cached"] {
                    return "cache";
                }
                return "halt";
            }
            return "pass";
        }
        start = 0;
        if i > 0 {
            start = bound(i - 1);
        }
        if tick >= start {
            return "active";
        }
        return "idle";
    }

    # Reasoning revealed in proportion to elapsed ticks inside the LLM gate.
    def shown -> str {
        s = scn();
        if not started or s["think_at"] < 0 {
            return "";
        }
        txt = s["reasoning"];
        stop = bound(s["think_at"]);
        begin = stop - THINK;
        if tick <= begin {
            return "";
        }
        if tick >= stop {
            return txt;
        }
        frac = (tick - begin) / THINK;
        n = int(len(txt) * frac);
        return txt[0:n];
    }

    def thinking -> bool {
        s = scn();
        if not started or s["think_at"] < 0 {
            return False;
        }
        stop = bound(s["think_at"]);
        return tick > stop - THINK and tick < stop;
    }

    def walker_at -> int {
        i = 0;
        while i < len(GATES) {
            st = status(i);
            if st == "active" or st == "halt" or st == "cache" {
                return i;
            }
            i = i + 1;
        }
        return last_index();
    }

    # LIVE. Implemented in frontend.impl.jac -- it calls the real gate chain
    # via `root spawn ScreenPayment(...)` across the codespace boundary and
    # falls back to the scripted scenario if the backend is unreachable, so
    # the demo cannot show an error.
    async def launch(k: str) -> None;

    # ---- scoreboard, derived from completed runs ----
    def n_screened -> int { return len(history); }

    def n_blocked -> int {
        c = 0;
        for r in history {
            if r["verdict"] == "BLOCKED" { c = c + 1; }
        }
        return c;
    }

    def tokens_saved -> int {
        c = 0;
        for r in history {
            if r["cached"] { c = c + 1840; }
        }
        return c;
    }

    def p50 -> int {
        if len(history) == 0 { return 0; }
        tot = 0;
        for r in history { tot = tot + r["latency"]; }
        return int(tot / len(history));
    }

    # A self-rescheduling timeout re-created on every tick. Because the effect
    # re-runs, the lambda always closes over a fresh `tick` — no stale reads.
    # It stops rescheduling once the run settles, so an idle demo burns nothing.
    # Declared after the helpers above: `def` lowers to a const binding, so
    # calling `finished()` from an earlier line would hit the temporal dead zone.
    useEffect(lambda {
        if not running or finished() {
            return lambda { };
        }
        t = setTimeout(lambda { tick = tick + 1; }, TICK_MS);
        return lambda { clearTimeout(t); };
    }, [tick, running]);

    # Stage control from the keyboard. Reaching for a trackpad mid-pitch costs
    # eye contact and looks like fumbling; 1-4 and R do not.
    useEffect(lambda {
        onkey = lambda (e: any) {
            k = e.key;
            if k == "1" { launch("attack"); }
            elif k == "2" { launch("replay"); }
            elif k == "3" { launch("legit"); }
            elif k == "4" { launch("cap"); }
            elif k == "r" or k == "R" {
                started = False; running = False; tick = 0; history = [];
            }
        };
        window.addEventListener("keydown", onkey);
        return lambda { window.removeEventListener("keydown", onkey); };
    }, []);

    s = scn();
    vclass = "verdict";
    if finished() {
        if s["cached"] { vclass = "verdict v-cached"; }
        elif s["verdict"] == "BLOCKED" { vclass = "verdict v-blocked"; }
        else { vclass = "verdict v-settled"; }
    }

    return
        <div className="shell">
            <div className="hdr">
                <div className="brand">SpendOS</div>
                <div className="tag">authorization firewall for agents that spend money</div>
            </div>
            <div className="tag">
                every payment is a walker · authorization is a route it must survive
            </div>

            <div className="chain" role="list" aria-label="authorization gate chain">
                {[
                    <div className="gwrap" key={i} role="listitem">
                        {i > 0 and <div className={
                            status(i) == "dead" and "link link-dead"
                            or (status(i - 1) == "pass" and "link link-on" or "link")
                        }/>}
                        <div className={"gate g-" + status(i)}>
                            {started and walker_at() == i and <div className={
                                (status(i) == "halt" or status(i) == "cache")
                                and "walker walker-dead" or "walker"
                            }>PAYMENT</div>}
                            <div className="gname">{g["name"]}</div>
                            <div className="gkind">{g["kind"]}</div>
                            <div className="gmark">
                                {status(i) == "pass" and "✓"
                                 or (status(i) == "halt" and "✕"
                                 or (status(i) == "cache" and "⚡" or ""))}
                            </div>
                        </div>
                    </div>
                    for (i, g) in enumerate(GATES)
                ]}
            </div>

            {finished() and
                <div className={vclass} role="status" aria-live="polite">
                    <div className="v-word">{s["verdict"]}</div>
                    <div className="v-why">
                        {s["reason"]}
                        <div className="v-at">halted at {s["halted_at"]} · {s["latency"]}ms · {s["tokens"]} tokens</div>
                    </div>
                </div>}

            <div className="cols">
                <div className="pane">
                    <div className="pane-h">Live reasoning</div>
                    <div className="think">
                        <span className="think-tok">{shown()}</span>
                        {thinking() and <span className="caret"/>}
                        {started and s["think_at"] < 0 and
                            <span style={{"color": "#55637f"}}>
                                {s["cached"]
                                 and "precedent fast-path — 0 tokens, no LLM call"
                                 or "deterministic path — 0 tokens, no LLM call"}
                            </span>}
                    </div>
                </div>

                <div className="pane">
                    <div className="pane-h">Scoreboard</div>
                    <div className="score">
                        <div className="stat">
                            <div className="stat-n">{n_screened()}</div>
                            <div className="stat-l">payments screened</div>
                        </div>
                        <div className="stat">
                            <div className="stat-n n-red">{n_blocked()}</div>
                            <div className="stat-l">blocked</div>
                        </div>
                        <div className="stat">
                            <div className="stat-n n-amber">{tokens_saved()}</div>
                            <div className="stat-l">tokens saved by precedent</div>
                        </div>
                        <div className="stat">
                            <div className="stat-n n-green">{p50()}ms</div>
                            <div className="stat-l">mean latency</div>
                        </div>
                    </div>
                </div>
            </div>

            <div className="bar">
                <button className="btn btn-attack" onClick={lambda { launch("attack"); }}>
                    Run attack · gift card  [1]
                </button>
                <button className="btn btn-replay" onClick={lambda { launch("replay"); }}>
                    Replay · precedent  [2]
                </button>
                <button className="btn btn-good" onClick={lambda { launch("legit"); }}>
                    Legit · groceries  [3]
                </button>
                <button className="btn" onClick={lambda { launch("cap"); }}>
                    Cap breach  [4]
                </button>
                <button className="btn" onClick={lambda {
                    started = False; running = False; tick = 0; history = [];
                }}>
                    Reset  [R]
                </button>
            </div>

            <div className="foot">
                <span className="live"/>
                {s["label"]} · tick {tick} ·
                {s.get("live", False)
                 and <span className="badge-live"> live · real gate chain</span>
                 or <span className="badge-mock"> scripted fallback</span>}
            </div>
        </div>;
}
