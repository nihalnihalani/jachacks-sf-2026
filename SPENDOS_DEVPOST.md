# SpendOS

**An agentic financial guardian, built graph-first in Jac.**

Your AI agents are about to get a credit card. SpendOS is the layer that decides
what they can do with it — a Jac graph that imports your spending, finds every
recurring charge, investigates each one against evidence it must cite, and puts a
human in front of every purchase an agent proposes. The model reasons. It never
touches the arithmetic, and it never gets to say yes.

---

## Inspiration

Two things happened in the same year.

First, subscription spend went invisible. Most people cannot name every recurring
charge on their own statement, and the tools that promise to fix it are either a
spreadsheet or a company that takes read-access to your bank and a cut of your
savings.

Second — and this is why we built a guardian instead of a dashboard — agents
started holding spending authority. Every guardrail shipping for that today is a
flat rule list: daily cap, per-transaction cap, merchant allowlist. Those catch a
runaway loop burning $10,000. They do not catch a $180 charge from an allowlisted
merchant that the human never wanted, which is exactly the shape a confused or
prompt-injected agent produces. It arrives clean, small, and successful — the
opposite of what a fraud model is trained to flag.

So the question we built around is not *"is this transaction fraudulent?"* Banks
already answer that one. It is:

> **Does this charge still earn its place in this person's life — and does this
> agent's purchase fit inside a budget the human actually confirmed?**

That is a judgment question sitting on top of an arithmetic question. Most
products get the stack backwards: they let a model do the math and a rule do the
thinking. SpendOS inverts it, and everything in the architecture follows from
that one decision.

---

## What it does

```text
preview → import → detect → investigate → decide → approve → simulate → remember
                                    ↘ budget guard → purchase preflight ↗
```

**Import.** Drop a `date,description,amount` CSV, or hit *Watch the live demo* and
stream a 55-transaction synthetic bank feed through in five-transaction batches.
The parser also accepts bank-grade columns — `merchant`, `category`,
`account_mask`, `payment_channel`, `city`, `pending` — and preserves anything
extra on the transaction node. Malformed rows are reported, never silently
dropped.

**Detect.** Recurrence detection is fully deterministic: normalize the merchant,
take the median inter-charge interval, and classify only inside real windows —
25–35 days monthly, 80–100 quarterly, 340–390 annual. Anything else returns
nothing rather than guessing. Amount stability sets a confidence score, and price
drift is calculated rather than inferred.

**Investigate.** A case opens, evidence nodes are minted from the real charges,
and portfolio overlap is computed from the graph. With no API key this produces a
complete finding, labeled `deterministic`. With a key, a typed byLLM ReAct agent
with five evidence tools assesses it — and every citation it returns is checked
against the evidence IDs SpendOS handed it.

**Decide.** Keep, protect, postpone, or approve. The decision is written to the
graph, and *protect* creates a durable preference that outranks the agent on every
future run.

**Simulate.** An approved cancellation ends at state `SIMULATED`, shipped with the
disclosure *"No external action was performed."* SpendOS does not email a
merchant, log into a bank, or move money.

**Remember.** Decisions establish precedent. The next investigation of that
merchant reads it back as evidence.

**Budget Guard.** One budget plan node holds income, confirmed fixed obligations,
and a safety reserve you set. **Safe to Spend** is recalculated from the live
subscription graph every single time — never cached, because a stale safety
number is worse than no safety number at all.

**Purchase Guard.** An agent submits a purchase proposal; SpendOS runs a
deterministic preflight and returns `SAFE`, `WARN`, or `BLOCK`. **`SAFE` is not
permission.** It is a fact about arithmetic. A human still approves, and an
approved proposal still ends at `SIMULATED`.

---

## Architecture

![SpendOS architecture — Jac graph, deterministic engine, agentic investigation, human control plane](https://mermaid.ink/img/pako:eNp9Vs1uGzcQfhVC58hxbCtFgyKAIm8TN3YsWLZzqAuB2qUkJlySILlS1CDXPkBfpvc-Sp-k3wx3FUkOrIu4Q84PZ775hl97patU75XoLYL0S3F7_mAFfqPJ_e8PvTfSfhaTJJOqlU0k_GUWnr9uvHGyEv_-I6KsvVG0Ggz6wa1F3Ni0VEmXYq5U9dD7I5u7qL0LCRbX0nxW4ZVvZq1sa50tl84m8jTXdqGCDxprGNeVwmHeCUqzHpvOxmMzy8G_fQEPv8lSvOVPKCIW4azZCK9C1DGpSkRyuA2MfnwamifHwiIZQoYSV9h4FcnEizNB60qoaqEiR_k9I9i_DdJGWSbtLH1eKWjLvDVpZrEM2tMeKxYr3MSWnLCRjPx_rkodW-VxUKWqWsNvGjhMYyOzLrkXN6psQhxGUcoQNAKc6xDTNCplxXNhZLveXk_Z6nGWTnDXc5VUqLVFTlCrwi605Wjc2kahVipshG3qmQp7mSKt8qCMQyvN5k81Rk3mzmjHwVZ8cBoo3NDduFaVllagpiqspOGDJ4P-6aASNeq-RJlw6vTsuH_683ElpLWNNHv-r2SiQpXSlI1BDaZRztU0uWn0uCkDMsmZUVONOi_lyeAlO0EYrvYNVd_olRLz4GqGxqLDiaUrI6kofPV08k7hf7hAiZC2C7tSyN9CdsXn7H1C3RgcBLy98KnkBz2wtaAegQXVSVHsQqa9RRS-S7ZwiNtIv-fm8vIKXmSMKsZp3DErZhthTM3WBx2qO_vJOcOAv1HDMiEXnrZlEjmHUdX9tQ6KsxxUagKumk1wOobsju69F8u9NLrC7ahqOnGi4lQGNV3RBrAg0K-ZVGxsPF1sN6j__vpb3BT3F8XHjh7m7c5MGdDN8dHLwc6hp0t3hiDeNTUgOALcgjOCmosza11agnKE-gLEIsMHqC_hdL9wWUYF5cDeF8WYG_jm-rYY3fLyenI7vv5Q0Ho4xsZ9sWd1out9kxAwqEcS9zNGboGQO1WaTF1icnF1dzm8Lc73zG2pg5u7pRTKTMEtoeMSuKHv7cEMMlU79Losg4tRUAmpQk_ncQAX44ZoDgz2tpGh6qhWEhLEzDW2kmEf-2PAtdxA0wfnXVRT31mALtZEuzota5odHNmby-vRe6HnAgqfQCaAhVXUaitW-Ti8-dCCYG6cC5mYh78WQkchxRyM_IzKSsxfa77WXjxDD7srqmrFpdzGM80BIt3wsmS4UCPvxNRY6roAXM_y7EOWInXK48r8MH8v4bT4gqpSTbl5yMg7xIkSkWlxNRrvBZv3oLbkxfO69OD5gKNHftMNKepfjtI6IfPtMrQFWK387JrUfiaaWHMVusMlA67dnNHINw7zYJ95cwoRwmTpvEevtBKec60IyK242zNs166_lhuQRVQ0UmHV-acz8xPsj4xuMyJNdGINVGDwt0yxF9PdBY6Dy-nJUB2V5ugTRj_0TjA-QPS2ndalEfTGiV6CNohCtUGekwPRASRdEoovHoHGNgtzlShguTkYgAV4g0BcS207d2enO84QiXea3ykLzNawHQ2oCKZcs0OPOxnAw0r0-6_bJ9Huk4nF_EDJ0vyyIWGexVma1yymEXl4lGiqdUQNRyLMiCzBggUdUWdp99V6ogbpPNGaxeCrR7ItueSd7--Zg2tQlFmBaaE9zWsWt92Z5W1nHB7fEbdYzPJWlzfuLn4USCe9u-BPLmrvmejVsCh1Ra_hrw89EFqNh-IrQRQxl41B6b7RMdkkN9nYElspNAqSxlOyzrUEjutW_O1_DmPshA)

---

## How we built it

We are not claiming twelve Jac features. We are claiming **seven load-bearing
ones**, and every one is doing work that would cost real code to replace.

### The whole thing is one language

**5,686 lines of Jac. Zero lines of Express, zero hand-written REST client, zero
separate React app.**

| File | Lines | Responsibility |
|---|---:|---|
| `frontend.cl.jac` | 2,390 | The complete responsive client — dashboard, live feed, findings, budget, purchase, agent panels |
| `endpoints.sv.jac` | 1,497 | 5 walkers + 18 `def:pub` endpoints; all graph workflows |
| `schema.jac` | 712 | 15 nodes, 11 typed edges, CSV parser, recurrence math, Safe to Spend |
| `tests/core_tests.jac` | 401 | Deterministic, idempotency, and simulation tests |
| `purchase.jac` | 290 | Purchase domain: catalog, cart, order math, instruction parsing |
| `tests/purchase_tests.jac` | 163 | Purchase-layer coverage |
| `agent.jac` | 117 | Typed byLLM assessment, five evidence tools, `sem` wiring |
| `tests/purchase_v7_tests.jac` | 73 | Purchase milestone coverage |
| `main.jac` | 43 | Full-stack entry; endpoint registration; client mount |

`main.jac` is the entire integration layer:

```jac
import from endpoints { ImportStatement, AnalyzePortfolio, get_dashboard, ... }

cl {
    import from .frontend { app as SpendOSApp }
    def:pub app -> JsxElement { return <SpendOSApp/>; }
}
```

Importing a walker here mounts it as a server endpoint. The `cl { }` codespace
marks the client half. The compiler decides what runs where and generates the
boundary between them. There is no API contract to keep in sync by hand, no
serializer to write, and no client that can drift from its server — an entire
class of glue code, and an entire class of bug, that does not exist in this
codebase.

### 1. The graph is the database

Twenty node archetypes, fourteen typed edges. No ORM, no migration file, no second
source of truth. `root ++> Evidence(...)` persists.

```jac
edge RecursAs: Transaction --> Subscription {
    has first_seen: str = "",
        last_seen: str = "";
}
```

The relationship carries its own data. "This transaction is an instance of that
subscription, first seen here, last seen there" is one typed edge — not a join
table with a nullable column.

### 2. Filter-in-traversal is the query language

```jac
visit [here-->[?:Subscription, subscription_id==self.subscription_id]];
linked: list[Transaction] = [here<-:RecursAs:<-[?:Transaction]];
overlap: list[Subscription] = [root-->[?:Subscription]];
```

Node-type filter, field predicate, and typed-edge direction — inline, in the
traversal. The middle line reads the graph *backward along a named edge*. In SQL
that is a join. Here it is the shape of the sentence.

### 3. Walkers own workflow; functions own math

Five `walker:pub` archetypes — `ImportStatement`, `AnalyzePortfolio`,
`InvestigateSubscription`, `DecideCase`, `SimulateCancellation` — each of which
becomes a REST endpoint automatically. The split is enforced everywhere:

- **A walker traverses and mutates.** Entry abilities dispatch per node type
  (`can analyze with Merchant entry`); `skip` abandons one node, `disengage` ends
  the walk.
- **A `def` computes.** Parsing, medians, cadence classification, Safe to Spend,
  proration, hashing. Pure, testable, no graph access.

`AnalyzePortfolio` shows it cleanly: `can find_merchants with Root entry` fans out
to every merchant, then `can analyze with Merchant entry` runs per-merchant, calls
the pure `detect_recurrence`, and skips anything that is not recurring. The
traversal *is* the control flow.

### 4. byLLM with typed output, five tools, and `sem` as the prompt surface

```jac
def assess_subscription(packet: InvestigationPacket) -> AgentAssessment by llm(
    tools=[
        read_charge_history,
        read_price_changes,
        read_user_preferences,
        read_prior_precedent,
        compare_portfolio_overlap
    ],
    temperature=0.1,
    max_tokens=700,
    max_react_iterations=6,
    max_output_retries=2
);
```

A real ReAct loop. The model chooses which of the five evidence tools to consult
and in what order, bounded at six iterations, and must return a typed
`AgentAssessment` — not a string we parse with a regex and hope.

The prompt surface is `sem`, not docstrings, wired at every level the language
allows: the function, its parameter, each tool, each tool parameter, and every
field of the evidence packet.

```jac
sem InvestigationPacket.evidence_ids = "The only evidence identifiers the assessment may cite.";
sem read_prior_precedent = "Read prior user decisions for this merchant.";
sem assess_subscription = """... Never infer that the user does not use a service.
Protected preferences require KEEP. Low confidence or unsupported claims require REVIEW. ...""";
```

That last constraint is not decoration. A subscription-killer that tells you "you
haven't used this" from payment data alone is lying — payments cannot observe
usage. The `sem` says so, and the code enforces it.

### 5. The model's output is evidence-checked in Jac, after the call

The decision we are proudest of.

```jac
if assessment.recommendation in allowed_outcomes
and citations_are_valid(assessment.evidence_ids, evidence_ids) {
    recommendation = assessment.recommendation;
    confidence = min(here.confidence, assessment.confidence);
    if confidence < 0.65 {
        recommendation = "REVIEW";
        reason = "The agent assessment was downgraded to review because confidence was low.";
    }
    source = "live agent";
} else {
    recommendation = "REVIEW";
    reason = "The agent returned unsupported evidence, so SpendOS safely requires review.";
    source = "agent output rejected";
}
```

Four things happen there that no prompt can guarantee:

- **Citations are validated against a whitelist SpendOS itself minted.** A
  hallucinated evidence ID does not become a finding. It becomes `REVIEW`.
- **Confidence is clamped by `min()` against the deterministic recurrence
  confidence.** The model cannot be more certain than the data.
- **A protected subscription never reaches the model at all.** A user preference
  outranks an agent structurally, not by instruction.
- **The `source` field is carried through to the UI** — `deterministic`,
  `live agent`, `agent output rejected`, or `deterministic fallback`. The
  interface always says which one produced the finding. We never present a rule as
  an agent.

The whole call sits inside a `try/except` that degrades to the deterministic
result. A dead API key downgrades the product; it never breaks it.

### 6. Idempotency as a first-class property, enforced by content hashing

`root` persists between runs — a gift and a trap. Every mutating path derives a
deterministic ID from content and checks the graph before creating anything:

```jac
def stable_id(prefix: str, value: str) -> str {
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[0:16];
    return f"{prefix}_{digest}";
}

target_case_id = stable_id("case", f"{here.subscription_id}|{here.last_amount:.2f}|{here.transaction_count}");
existing: list[SubscriptionCase] = [root-->[?:SubscriptionCase, case_id==target_case_id]];
if existing { report case_to_view(existing[0]); disengage; }
```

Statements dedupe on a content fingerprint, decisions on case plus choice,
preferences on merchant plus rule. Re-import the same CSV and you get a duplicate
count, not a doubled portfolio. This is a tested property, not an intention.

### 7. `jac.toml` is the whole control plane

```toml
[project]
kind = "web-app"
entry-point = "main.jac"

[test]
directory = "tests"
filter = "*tests.jac"

[byllm.model]
default_model = "gpt-4o-mini"
```

One file declares the project kind, npm dependencies, the serve route, test
discovery, and model configuration.

### Jac feature map

| Construct | Where | What it buys us |
|---|---|---|
| `node` / `edge` archetypes | `schema.jac`, `purchase.jac` | 20 nodes, 14 typed edges; the graph is the only persisted state |
| Edge with attributes | `edge RecursAs { has first_seen, last_seen; }` | Relationship data without a join table |
| `walker:pub` | 5 walkers in `endpoints.sv.jac` | Traversal workflows that are automatically REST endpoints |
| Per-node entry abilities | `can analyze with Merchant entry` | Type-dispatched traversal logic |
| `skip` / `disengage` | `AnalyzePortfolio`, `InvestigateSubscription` | Abandon one node vs. end the walk |
| Filtered traversal | `[root-->[?:Subscription, subscription_id==x]]` | A query language built into the syntax |
| Reverse typed traversal | `[here<-:RecursAs:<-[?:Transaction]]` | Read a relationship backward, natively |
| `by llm(tools=[...])` | `agent.jac:assess_subscription` | Real ReAct with five typed evidence tools |
| Typed LLM return | `-> AgentAssessment` | Structured output; no string parsing |
| `sem` declarations | function, params, 5 tools, 10 packet fields | Prompt surface kept separate from code docs |
| `cl { }` codespace | `main.jac`, `frontend.cl.jac` | A 2,390-line React client written in Jac |
| `def:pub` | 18 endpoints | Callable from the client with no fetch layer |
| `root` persistence | everywhere | Precedents and preferences survive restarts |
| `test` blocks + `[test]` | `tests/*.jac` | 28 tests via `jac test`, 4.70 s |

---

## Depth of agentic behavior

**Planning.** `assess_subscription` is a genuine ReAct loop bounded at six
iterations. The model decides which evidence tools to consult per subscription;
nothing in the code fixes the order.

**Tool use.** Five typed tools, each returning structured facts read from the
graph — charge history, price changes, user preferences, prior precedent,
portfolio overlap. Each has its own `sem` declaration and typed signature.

**Memory, at two levels.** Within the product, a decision establishes precedent,
and the next investigation of that merchant reads it back as evidence through
`read_prior_precedent`; protecting a subscription writes a preference that removes
the model from that loop permanently. Across sessions, it is graph state under
`root`, so it survives a restart. The system forgets the window, not the lesson.

**Multi-agent coordination across a real trust boundary.** SpendOS exposes a
fourteen-tool MCP bridge to an external shopping agent. The interesting part is
what is deliberately absent: no approve, no checkout, no cancel, no transfer, no
bank login, no merchant contact. The bridge cannot be talked into an action that
does not exist in its tool list. What it *can* do is a two-way research loop —
SpendOS dispatches a shopping mission, the agent claims it, submits
evidence-backed candidates, and marks the mission ready for human review. Two
autonomous systems collaborating, with the authority boundary enforced by the
shape of the API rather than by a prompt asking nicely.

---

## The safety model

| Rule | Enforced by |
|---|---|
| The model never owns arithmetic | All money math lives in pure `def`s; the model receives computed facts |
| The model cannot execute an action | No tool it can call performs one |
| The model cannot widen a mandate | Outcomes restricted to a four-value allowlist |
| Unsupported citations are not findings | `citations_are_valid()` after the call → `REVIEW` |
| Low confidence is not a recommendation | Below 0.65 → `REVIEW` |
| A user preference outranks the agent | `protected` short-circuits before the call |
| `SAFE` is not permission | It is an arithmetic fact; a human still approves |
| `BLOCK` cannot be overridden | Enforced in code, not in a prompt |
| Nothing real is executed | Every action path terminates at `SIMULATED` |
| Never infer non-use from payments | Stated in `sem`; no code path claims usage |
| No-key mode stays honest | Findings are labeled `deterministic` in the UI |

The purchase policy itself is four lines of arithmetic and no model at all:

```jac
projected = round(current_safe - monthly_cost, 2);
warning_floor = max(100.0, round(plan.safety_reserve * 0.25, 2));
if projected < 0.0             { outcome = "BLOCK"; state = "BLOCKED"; }
elif projected < warning_floor { outcome = "WARN"; }
else                           { outcome = "SAFE"; state = "PROPOSED"; }
```

We could have made that a model call. It would have demoed identically, been
wrong sometimes, and we would not have been able to tell you when.

---

## Challenges we ran into

**Persistence is a trap that only springs on run three.** `root` survives across
runs. Our early code re-created graph structure on every startup, so run N held N
parallel copies and every total was nonsense. The fix — content-hashed IDs plus an
existence check before every create — is now the house rule for every mutating
path. What made it hurt was the timing: an un-idempotent write is invisible on run
one, so it surfaces on stage rather than in development. We now run persistence
stories three consecutive times and assert that runs two and three add nothing.

**A silently ignored config key.** byLLM configuration lives under `[byllm.*]`. We
had it under `[plugins.byllm.*]`, which is not an error — the block is simply
ignored, every call falls through to a default with no credentials, and the system
prompt never applies. There is a comment in `jac.toml` recording it so the next
person does not lose the same hour.

**Deciding what the model was not allowed to do.** The tempting build lets the
model produce the savings number and the verdict together. We tried it. It was
seductive and occasionally wrong in ways we could not detect. Splitting it —
arithmetic in functions, judgment behind `by llm()`, and a validation gate between
them — cost us a day and is the single reason we can defend any number on screen.

**Resisting the demo that scores well and means nothing.** It is easy to label a
threshold an "agent," and easy to write a graph that gets persisted but never
traversed. We audited our own build against both failure modes. That is why this
project claims seven Jac constructs rather than twelve, and why every finding card
tells you whether a rule or a model produced it.

---

## Accomplishments that we're proud of

**It runs with no API key, and says so.** The deterministic path is a complete
product, not a fallback stub. Without a key, findings are labeled `deterministic`
in the UI. Every agentic layer is additive on top of a floor that always works.

**28 tests, green, in 4.70 seconds.** Coverage includes merchant normalization,
bank-field parsing, malformed-row reporting, deterministic recurrence,
duplicate-free reimport, idempotent cancellation simulation, Safe to Spend
arithmetic, unsafe-plan warnings, idempotent budget updates, purchase-policy
thresholds, approval restrictions, proposal re-evaluation, and simulation.

**A 2,390-line client written entirely in Jac,** talking to the server through the
generated codespace boundary. No Express. No fetch layer. No second language for
the UI.

**The model's output is checked, not trusted** — and when it fails the check, the
UI says `agent output rejected` rather than quietly showing a deterministic answer
as though the agent had produced it.

**An MCP boundary defined by absence.** The safest tool is the one you did not
expose.

---

## What we learned

**Determinism is a feature you ship, not a compromise you make.** Every number in
SpendOS is recomputed by code we can point at. That is precisely what makes the
agentic layer safe to add — the model operates on top of a floor that cannot move
under it.

**A graph has to be load-bearing to be worth claiming.** A linear pipeline in a
graph database is a `for` loop in a costume. The parts of SpendOS that are
genuinely graph-shaped are the ones we lean on: evidence linked to cases linked to
decisions linked to precedent, read backward along typed edges, with the active
subscription set recomputed from live traversal on every Safe to Spend call.

**Say seven things and make all of them true.** Someone who probes seven
constructs and finds seven real ones learns more about a system than someone who
probes twelve and finds the third is a config flag.

---

## What we're upfront about

Stated without being asked, because discovering these unaided is worse than
hearing them from us.

- **All data is synthetic.** A sample statement of 11 rows (one deliberately
  malformed, to prove rejection reporting), a 55-row two-account bank feed, and a
  10-product catalog. No real bank, no real merchant, no real person.
- **The Live Feed is a deterministic simulation,** not a bank connection. It
  streams a bundled fixture in batches to exercise the guardian loop. SpendOS does
  not claim real-time monitoring, and there is no bank integration.
- **Nothing is executed.** Cancellation and purchase both terminate at `SIMULATED`
  with the disclosure "No external action was performed." No email, no merchant
  contact, no money movement.
- **The purchase layer is at its first milestone.** A one-line request resolves
  against the catalog, builds a cart, and produces a simulated order with an audit
  entry. The recurring, limit, pattern, fraud, and preference gates are not wired
  in yet, and checkout is not implemented.
- **There is no authentication yet.** Demo endpoints are public and operate on a
  shared guest graph. Per-user roots are designed for, not shipped.
- **Payment data cannot observe usage,** so SpendOS never claims you stopped using
  something. It identifies overlap and price changes, and the `sem` forbids the
  model from claiming more.
- **We have not tested it against an attack we did not anticipate.** The claim is
  the architecture and the safety boundary, not a detection rate. We report no
  precision figure because we have not earned one.
- **Everything reported here was measured on the demo machine** against the Jac
  binary in this checkout, not estimated.

---

## What's next for SpendOS

1. **Wire the remaining purchase gates** — recurring-charge detection, per-agent
   limits, pattern anomaly, and preference checks in front of every purchase.
2. **Per-user roots and authentication,** so financial records are isolated by
   principal and never sit on a shared graph.
3. **Revocation blast radius** — delete one delegation edge and show exactly which
   pending proposals go dark. This is the graph query no list can express, and the
   natural continuation of the authority model.
4. **A real bank-format mapper,** so an arbitrary export maps to the canonical
   columns without hand-editing.

---

## Demo video

**Watch it here:** `<video link>`

What you are seeing, in order:

**0:00 — Safe to Spend, recomputed live.** The Live Feed streams a synthetic bank
statement in batches. Watch the Safe to Spend figure move as each new subscription
is detected. Nothing on that screen is cached; it is recalculated from the
subscription graph on every tick.

**0:20 — an investigation you can audit.** We open one finding. It carries a
`source` label and the specific evidence it rests on. When the live agent runs, it
must cite evidence IDs that SpendOS minted for it — an unsupported citation is
downgraded to `REVIEW` rather than shown as a finding.

**0:50 — the agent boundary.** An AI agent proposes a purchase. The first is
`BLOCK`ed, and no human in the interface can override it. The second returns
`SAFE` — and *still* requires human approval, and *still* terminates at
`SIMULATED`. `SAFE` is a fact about arithmetic, not a permission.

**1:15 — the disclosure.** All data is synthetic and nothing is executed. We say
it in the demo rather than letting anyone discover it afterward.

---

## Try it out

**Repository:** <https://github.com/nihalnihalani/jachacks-sf-2026>

Requires the native Jac binary. Nothing is installed with pip.

```bash
cd spendos
jac install
jac clean --data --force     # persistence is real; start from a known state
jac test                     # 28 tests
jac build
jac start --dev --port 8011
```

Open <http://localhost:8011> and choose **Watch the live demo**. No API key is
required — findings will be labeled `deterministic`. Add `OPENAI_API_KEY`,
`ANTHROPIC_API_KEY`, or `GOOGLE_API_KEY` to `.env` and the same run switches the
label to `live agent`.

To run the MCP bridge alongside it:

```bash
SPENDOS_API_URL=http://127.0.0.1:8012 \
  python3 hermes/mcp_http_server.py --host 0.0.0.0 --port 8765
```

Verify the build yourself:

```bash
jac check .
jac check --lint .
jac test             # 28 passed in 4.70s
jac build
```

---

## Built with

Jac · Jaseci · byLLM (`by llm(tools=[...])`, typed returns, `sem`) · Jac
codespaces (`cl` / `sv`) · Jac graph persistence (`root`) · Model Context Protocol
· React 18, compiled from `frontend.cl.jac` · Vite · Python · OpenAI, Anthropic,
or Google — any one key, all optional
