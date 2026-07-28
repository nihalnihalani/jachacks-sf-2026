# How we use Jac and Jaseci

*Paste-ready answer for the Devpost question: "Explain how you use Jac and/or
other Jaseci tools in your project."*

---

SpendOS is not a Python app with Jac sprinkled on top. **It is 5,686 lines of Jac
across nine files, and nothing else** — no Express server, no hand-written REST
client, no separate React project. Jac is the database layer, the workflow engine,
the LLM integration, the API, and the UI. Here is exactly where each construct
does load-bearing work.

### The graph is the database

Twenty `node` archetypes and fourteen typed `edge` archetypes in `schema.jac` and
`purchase.jac` — statements, transactions, merchants, subscriptions, evidence,
cases, decisions, precedents, budget plans, purchase proposals. There is no ORM,
no migration file, no second source of truth. `root ++> Evidence(...)` persists,
and `root` survives restarts, which is how precedent and user preferences carry
across sessions.

Edges carry their own data:

```jac
edge RecursAs: Transaction --> Subscription {
    has first_seen: str = "",
        last_seen: str = "";
}
```

"This transaction is an instance of that subscription, first seen here, last seen
there" is one typed edge — not a join table with nullable columns.

### Walkers are the workflows, and they are the API

Five `walker:pub` archetypes in `endpoints.sv.jac` — `ImportStatement`,
`AnalyzePortfolio`, `InvestigateSubscription`, `DecideCase`,
`SimulateCancellation` — plus 18 `def:pub` functions. Declaring them public is the
entire API layer; they become REST endpoints automatically.

Traversal is type-dispatched. `AnalyzePortfolio` uses `can find_merchants with
Root entry` to fan out across every merchant, then `can analyze with Merchant
entry` to run per-merchant, `skip`ping any merchant that is not recurring.
`disengage` ends a walk early when an idempotency check finds existing work.

Querying is filter-in-traversal, not SQL:

```jac
visit [here-->[?:Subscription, subscription_id==self.subscription_id]];
linked: list[Transaction] = [here<-:RecursAs:<-[?:Transaction]];
```

Node-type filter, field predicate, and typed-edge direction inline — and that
second line reads the graph *backward along a named edge*, which is a join in SQL
and a phrase here.

### byLLM does judgment, and only judgment

One `by llm()` call, and it is a real ReAct agent:

```jac
def assess_subscription(packet: InvestigationPacket) -> AgentAssessment by llm(
    tools=[read_charge_history, read_price_changes, read_user_preferences,
           read_prior_precedent, compare_portfolio_overlap],
    temperature=0.1, max_react_iterations=6, max_output_retries=2
);
```

The model chooses which of the five graph-backed evidence tools to consult and in
what order, bounded at six iterations, and returns a **typed** `AgentAssessment` —
no string parsing.

The prompt surface is `sem`, wired at every level the language allows: **22 `sem`
declarations in `agent.jac` alone** — ten packet fields, five tools plus their
five parameters, and the function plus its parameter. Prompts live beside the
types they describe instead of inside docstrings.

Crucially, **Jac validates the model afterward.** `citations_are_valid()` checks
every returned evidence ID against the whitelist SpendOS itself minted;
`min()` clamps the model's confidence against the deterministic recurrence
confidence; anything unsupported or below 0.65 becomes `REVIEW`. A protected
subscription never reaches the model at all. The call sits inside `try/except` that
degrades to the deterministic path, so **the whole product runs with no API key**
and honestly labels those findings `deterministic`.

What byLLM deliberately does *not* touch: arithmetic. Recurrence detection, Safe to
Spend, proration, and the purchase policy are pure Jac `def`s. Walkers own
traversal and mutation; functions own math; the model owns judgment.

### Codespaces make it one program

`main.jac` is 43 lines and is the entire integration layer:

```jac
import from endpoints { ImportStatement, AnalyzePortfolio, get_dashboard, ... }

cl {
    import from .frontend { app as SpendOSApp }
    def:pub app -> JsxElement { return <SpendOSApp/>; }
}
```

Importing a walker mounts it as a server endpoint. The `cl { }` codespace marks
the client half. `frontend.cl.jac` is a **2,390-line React client written in Jac**
that calls server functions directly across the generated boundary — no fetch
layer, no API contract to keep in sync by hand, no client that can drift from its
server.

### jac.toml is the whole control plane

Project kind (`web-app`), entry point, npm dependencies, serve route, test
discovery, and model configuration all live in one file. One hard-won detail: the
byLLM key path is `[byllm.*]`, **not** `[plugins.byllm.*]` — under the wrong path
the block is silently ignored and every call falls through to a default with no
credentials.

### The Jaseci toolchain is the whole dev loop

Jac ships as a single native binary; nothing is installed with pip.

```bash
jac install          # dependencies
jac check .          # type checking
jac check --lint .   # linting
jac test             # 28 tests, 4.70s
jac build
jac start --dev      # full-stack server + client
```

`jac test` runs `test` blocks in `tests/*.jac` discovered via the `[test]` section
— 28 tests covering parsing, deterministic recurrence, duplicate-free reimport,
idempotent simulation, Safe to Spend arithmetic, and purchase-policy thresholds.
`jac clean --data --force` resets the persisted graph, which matters because
`root` really does survive between runs.

---

**In short:** Jac's graph gave us persistence and evidence lineage with no
database; walkers gave us workflows that are also the API; byLLM gave us a
tool-using agent whose output we can validate in the same language; and codespaces
let one program be both server and client. Every one of those is doing work we
would otherwise have written by hand.
