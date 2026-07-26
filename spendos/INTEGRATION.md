# SpendOS — Integration Contract, Runbook & Risk Register

Owner: IntegrationLead. **This file is the tie-breaker.** If your module disagrees with this
document, this document wins — or you change this document first and tell the team.

Everything below marked **[V]** was verified by execution against jac 0.34.5 on this machine.
Everything marked **[U]** is unverified and flagged as such.

---

## 0. STOP — live build blocker (as of writing)

`jac run smoke.jac` in `spendos/` **fails**:

```
error[E0077]: Duplicate declaration of 'Gate' (already declared as node)
  --> gates.jac:21
```

`schema.jac:68` and `gates.jac:21` **both declare `node Gate`**. Two owners claimed one type.

**Resolution (schema.jac wins — it is the leaf module):**
1. `gates.jac`: delete the entire `node Gate { ... }` block (lines 21–27).
2. `schema.jac`: add the default `judge` to its `Gate` so subtype dispatch has a base:
   ```jac
   node Gate {
       has label: str = "";
       def judge(amount: float, merchant: str, category: str) -> Ruling {
           return Ruling(blocked=False);
       }
   }
   ```
3. `gates.jac` keeps only the subtypes (`CapGate(Gate)`, `VelocityGate(Gate)`, …).

Until this lands, `spendos/_baseline/` holds a **verified-green** parallel implementation
(`jac run smoke.jac` → `SMOKE: ALL GREEN`, zero LLM calls). That is the demo floor.

---

## 1. Hard language facts (all verified by execution)

These cost me real time. Do not re-discover them.

| # | Fact | Evidence |
|---|---|---|
| L1 | **Circular `import from` is a hard failure.** `schema ↔ gates` → `cannot import name 'Treasury' from partially initialized module`. | **[V]** |
| L2 | **A docstring inside a `def` body needs a trailing semicolon**: `"""text""";`. Without it the parser swallows the next statement and reports a bogus error at the *closing brace*. Module-level docstrings are fine unterminated. | **[V]** |
| L3 | **There is no `global` statement.** Assigning a `glob` inside a function rebinds it directly. `global X;` is a parse error. | **[V]** |
| L4 | **Node type filter is `[-->][?:Type]`**, not `[--> (\`?Type)]`. Typed edges: `[->:Edge:->]`; edge objects: `[edge -->]`. | **[V]** |
| L5 | **Root ability is `with Root entry`** (capital `Root`). `` with `root entry `` parses but dies at runtime with `name 'root' is not defined`. | **[V]** |
| L6 | **Edge references cannot appear inside an f-string.** `f"{[edge t ->:Funds:->][0].spent}"` → `Missing ']'`. Assign to a local first. | **[V]** |
| L7 | **`disengage` is legal in node abilities AND edge abilities.** The E2083 in CLAUDE.md is wrong as stated — that error came from using `here` in a *node* ability. | **[V]** |
| L8 | **In a node/edge ability the archetype is `self` and the walker is `visitor`.** `here` exists only in *walker* abilities. Mixing these is the #1 source of confusing runtime errors. | **[V]** |
| L9 | **`visit [-->]` does NOT fire edge abilities; `visit [edge -->]` does**, then auto-continues to the target node. Measured: `spent=0.0` vs `spent=10.0`. | **[V]** |
| L10 | **Walker subtypes DO fire base-typed abilities.** `walker EdgeVisit(Payment)` triggers `can meter with Payment entry`. GraphArchitect's `Metered` base design is sound. | **[V]** |

### L11 — the one that shapes the architecture

**An `obj` used as a `by llm()` return type MUST be declared in the same physical module as the
`by llm()` function.** Neither `import from` nor `include` works. **[V]**

| Ruling location | Result of calling a `by llm()` returning it |
|---|---|
| Same module | reaches the API (only `AuthenticationError` for the missing key) — correct |
| `import from other { Ruling }` | `AttributeError: 'str' object has no attribute 'fields'` |
| `include other;` | `NameError: name 'Ruling' is not defined` |

Isolated with an identical 4-field `Ruling` in all three cases, so it is the module boundary,
not the shape.

**Consequence:** `obj Ruling` in `schema.jac` is fine for *constructing and annotating* everywhere
(that works across modules **[V]**), but **every `def ... -> Ruling by llm()` must live in the
module that declares `Ruling`.** Since `schema.jac` cannot import byLLM without becoming a
non-leaf, the rule is:

> **R3. `tribunal.jac` declares its own local `obj Ruling` and owns *every* `by llm()` that
> returns a Ruling** — including `judge_intent()` that `IntentMatchGate` calls. `gates.jac`
> imports the *function*, never declares a `by llm()` returning Ruling.
> `probe.jac` declares its own local `obj Attack` and owns its own `by llm()`. Self-contained.

Gates keep their logic; they just call `judge_intent(...)` instead of hosting the LLM decl.
This also means **the node-level `def ... by llm()` in SpendOS.md §6 cannot be used as written.**

---

## 2. Module DAG — strictly acyclic, one direction only

```
schema.jac      LEAF. imports NOTHING local. (nodes, edges, Metered/Payment base, Ruling, Attack)
   ↑
memory.jac      imports schema           (match_precedent, write_precedent)
   ↑
tribunal.jac    imports schema, memory   (local Ruling + ALL by llm())
   ↑
gates.jac       imports schema, memory, tribunal   (Gate SUBTYPES + Payment walker)
   ↑
probe.jac       imports schema, gates    (local Attack + its own by llm())
seed.jac        imports schema, gates
   ↑
main.jac / smoke.jac   imports everything below
```

**Never** point an arrow downward. `schema.jac` importing anything local re-creates L1.

### `import` vs `include`
- `include x;` splices declarations into your namespace. Chains work (A→B→C **[V]**), but it is
  **not idempotent under diamonds** and it breaks L11 harder than `import`.
- **Use `import from x { Name }`.** Explicit, greppable, and diamond-safe.
- The team's current files use `include`. That is tolerable *only* while the DAG is a straight
  line. The moment two modules include a common third, expect duplicate-declaration errors.

---

## 3. Shared type contract — exact field names

Any change here requires a message to the team. The UI and seed depend on these strings.

```jac
# schema.jac — LEAF
walker Metered {                 # base; the Funds edge ability targets this
    has amount: float = 0.0, verdict: str = "OK", halted_at: str = "",
        reason: str = "", signals: list[str] = [], tokens_used: int = 0;
}

# gates.jac
walker Payment(Metered) {
    has payment_id: str = "", cart: dict = {}, merchant: str = "",
        category: str = "", agent_handle: str = "";
    def fingerprint -> str;      # REQUIRED by memory.jac — currently MISSING
}

obj Ruling  { blocked: bool, uncertain: bool, reason: str, confidence: float, tokens: int }
obj Attack  { label: str, amount: float, merchant: str, category: str, cart: dict, technique: str }
```

**`verdict` is a closed set — exactly these four strings:**

`"OK"` (in flight) · `"BLOCKED"` · `"ALLOWED"` · `"REVIEW"`

> The two implementations currently disagree: `_baseline` emits `SETTLED`, `gates.jac` emits
> `ALLOWED`. **`ALLOWED` wins** (gates.jac is the real one). FrontendScout: key off `ALLOWED`.

**`halted_at` is a closed set, and it is the audit record.** Exact spellings, because the UI
matches on them to light up a node:

`"CapGate"` · `"VelocityGate"` · `"SanctionsGate"` · `"IntentMatchGate"` ·
`"IntentMatchGate(cached)"` · `"TribunalGate"` · `"Funds"` · `"Settled"`

### Two gaps to close
1. **`Payment.fingerprint()` does not exist** in `gates.jac`. `memory.jac` needs it for the
   precedent cache, which is the "it learned" beat at 2:10. Contract:
   `f"{merchant}|{category}|{int(amount)}"`.
2. **`gates.jac` carries both `cart: dict` and `category: str`.** Pick one source of truth.
   Recommend: `category` is the canonical scalar the gates read; `cart` is the display payload
   for the UI. Say so, or they will drift.

---

## 4. Three-layer demo safety

The audience must never see a stack trace. Detection is **explicit**, never an uncaught exception.

### Layer 1 — full live system (LLM)
Active when `ANTHROPIC_API_KEY` is set and `SPENDOS_FORCE_DETERMINISTIC` is empty.

### Layer 2 — deterministic gates only (**the real demo floor**)
> **Right now this is the DEFAULT, not the fallback: there is no `ANTHROPIC_API_KEY` and no
> `OPENAI_API_KEY` in this shell. [V]** Every rehearsal so far has been Layer 2.

Detection + degradation live in exactly one function, and it **never raises**:

```jac
def llm_live -> bool {
    if os.environ.get("SPENDOS_FORCE_DETERMINISTIC", "") { return False; }
    return bool(os.environ.get("ANTHROPIC_API_KEY", ""));
}

def judge_intent(cart: dict, mandate: str) -> Ruling {
    if llm_live() {
        try { return _judge_llm(cart, mandate); }
        except Exception as e { return _judge_rules(cart, mandate); }   # API down mid-demo
    }
    return _judge_rules(cart, mandate);
}
```

Two independent triggers — **no key** (checked before the call) and **any exception** (covers
timeout, rate-limit, 500, bad JSON). Verified: with no key, `judge_intent` returns a correct
deterministic `Ruling` with `tokens=0` and prints nothing alarming. **[V]**

`SPENDOS_FORCE_DETERMINISTIC=1` is the **panic switch** — set it and the demo is provably
repeatable regardless of network.

### Layer 3 — backend down → static JSON
UI fetches `/api/...`; on any non-200 or network error it renders `web/demo_case.json`.
The file must be a **recorded real run** of the Layer-2 smoke, not hand-written, or the
fallback will disagree with the live path on stage. **`web/demo_case.json` does not exist yet
— FrontendScout + DataSeeder own this.**

### Demo noise to suppress
- `warning: native seam -- demoting Payment.fingerprint to Python-only` prints on **every run**. **[V]**
- byLLM auth failures print a red `ERROR` line via loguru **before** your handler catches it. **[V]**
- SQLite quarantine `WARNING`s print when an entrypoint doesn't import a persisted class. **[V]**

Run the demo through `jac run -e none` and keep stderr off the projected screen.

---

## 5. Runbook (assume 5:45pm, stressed)

```bash
cd /Users/nihalnihalani/Desktop/Github/jachacks/spendos
```

**Never run from `…/jachacks/jac/`** — that directory's `jac.toml` enables a dev-mode compiler
(`🛠 jac dev mode — using compiler source`) **[V]** and sets
`select = ["all", "strip-comments", "strip-docstrings"]`, which **strips every comment and
docstring from `.jac` files on format** **[V]**. Do not run `jac format` from there.

### Step 1 — clean slate (5s)
```bash
rm -rf .jac/data
```
Expected: no output. **This is mandatory before every rehearsal** — see R1.

### Step 2 — deterministic smoke (10s) — THE health check
```bash
jac run -e none smoke.jac
```
Expected: every line `PASS`, final line `SMOKE: ALL GREEN` (or the team's `all gates halted where expected`).
Exit code is **not** a reliable signal — a green run returned `exit=1` **[V]**. **Read the text.**

If it fails, fall back immediately:
```bash
cd _baseline && rm -rf .jac && jac run -e none smoke.jac    # known green
```

### Step 3 — verify which layer you are in
```bash
echo "key set: ${ANTHROPIC_API_KEY:+YES}${ANTHROPIC_API_KEY:-NO}"
```
- `NO` → Layer 2. This is a complete demo. Proceed.
- `YES` → Layer 1. Run one live payment before going on stage.

### Step 4 — start the UI
```bash
jac start main.jac --port 8080
```
`jac start` takes `-p/--port` (client) **and** `-a/--api-port` — they are different ports. **[U]**
— nobody has run the server yet; the UI entrypoint `main.jac` does not exist.
If port 8080 is taken: `lsof -ti:8080 | xargs kill -9`.

### Step 5 — 60-second pre-demo checklist
1. `rm -rf .jac/data` — chain not duplicated.
2. `jac run -e none smoke.jac` → ALL GREEN.
3. **Close every other `jac run`/`jac start`.** Two processes on one project = `WriteConflict` **[V]**.
4. Browser open, hard-refreshed, zoomed so gate labels are legible from the back.
5. `web/demo_case.json` present (Layer 3 net).
6. Decide Layer 1 vs 2 **now** and do not change it. If unsure: `export SPENDOS_FORCE_DETERMINISTIC=1`.
7. Terminal font large; stderr not on the projected screen.

---

## 6. Risk register — ranked by likelihood × blast radius

| # | Risk | L×B | Owner | Mitigation |
|---|---|---|---|---|
| 1 | **Duplicate `node Gate`** — build is red right now. | **certain × total** | GraphArchitect + WalkerEngine | §0. schema.jac wins; gates.jac deletes its block. **Do this first.** |
| 2 | **`by llm()` cannot resolve an imported `Ruling`** (L11). Hits the moment the LLM layer is wired — i.e. during the 1:30–2:30 slot, under time pressure. | **certain × high** | TribunalDesigner | R3: tribunal.jac declares its own `Ruling` + owns all `by llm()`. Gates call the function. |
| 3 | **Graph persists across runs → chain duplicated, verdicts drift.** Run 2 of my smoke silently changed `IntentMatchGate` → `VelocityGate`. Fails *the second rehearsal*, not the first. | **high × high** | IntegrationLead | `rm -rf .jac/data` in the runbook **+** a `reset_graph()` that deletes everything off root. Verified idempotent across 3 runs. **[V]** |
| 4 | **Model config disagreement.** `jac.toml` says `gpt-4o-mini` (OpenAI); `_baseline`/tribunal use `anthropic/claude-sonnet-4-6`; `schema.jac` hardcodes `model: str = "gpt-4o-mini"` on AgentIdentity. **Neither `OPENAI_API_KEY` nor `ANTHROPIC_API_KEY` is set. [V]** | **high × high** | TribunalDesigner | Pick ONE provider and set it in `jac.toml` **and** every `Model(...)`. Anthropic is the safer bet (jac's own default). Otherwise Layer 1 silently never activates. |
| 5 | **Two `jac run` processes → `WriteConflict` on the root anchor.** Reproduced by running smoke while another entrypoint ran. Very easy to trigger with `jac start` up and someone running smoke. | **med × high** | all | One process at a time. `_baseline/` has its own `jac.toml` name so it uses a **separate** db. |
| 6 | **Persisted-class quarantine.** An entrypoint that doesn't import a module whose nodes are in the db → `Refused to deserialize … Moving to anchors_quarantine`, data silently dropped. **[V]** | **med × med** | IntegrationLead | Every entrypoint imports the full DAG; always `rm -rf .jac/data` after changing module layout. |
| 7 | **UI/backend JSON shape mismatch.** `verdict` is `SETTLED` in one impl, `ALLOWED` in the other; `halted_at` strings are matched literally by the UI. | **med × med** | FrontendScout + WalkerEngine | §3 closed sets. `demo_case.json` must be a **recorded** run, not hand-authored. |
| 8 | **`jac.toml` byLLM config was silently dead.** `[plugins.byllm.*]` is **ignored** — every call fell through to litellm's **OpenAI** default (`OpenAIException - Missing credentials`), so Layer 1 could never have worked and the `system_prompt` was never applied. `[byllm.*]` is read correctly. **[V]** | **certain × high** | IntegrationLead | **FIXED** — `jac.toml` now uses `[byllm.*]` + `anthropic/claude-sonnet-4-6`. Do not revert to `[plugins.*]`. Still open: `schema.jac` hardcodes `AgentIdentity.model = "gpt-4o-mini"` (cosmetic, but it will show on stage). |

---

## 7. What I could not verify

- **`jac start` / `walker:pub` / the served UI.** No `main.jac` or `pages/index.jac` exists yet.
  Ports, API shape, and the client toolchain (bun/node) are all untested. SpendOS.md §9 says to
  abandon the Jac frontend within 20 minutes if the toolchain fights back — **that clock has not
  started**, and it is the largest unquantified risk left.
- **Any live LLM call.** No API key present, so Layer 1 is entirely unexercised end-to-end. The
  degradation path is verified; the *success* path is not.
- **`[plugins.byllm.*]` config keys** actually being read (risk #8).
- **`ModelPool`, `on_iteration`, `conversation=`, `StreamEvent`** — features 6/7/8/10 in the brief.
  Untouched. All require a working key to exercise.
