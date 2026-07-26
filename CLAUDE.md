# SpendOS contributor guidance

SpendOS is an agentic subscription guardian built as a full-stack Jac
application. The current product loop is:

```text
import -> detect -> investigate -> decide -> simulate -> remember
```

## Documentation authority

Jac changes quickly. Before writing or changing Jac code:

1. Run `jac --version`.
2. Read the relevant version-matched guide with `jac guide`.
3. Check the official language reference and release notes.
4. Validate uncertain syntax with `jac check` or the `jac mcp` compiler tools.
5. Inspect upstream source only when the reference and compiler are insufficient.

Priority:

1. `jac guide`
2. https://docs.jaseci.org/reference/
3. https://docs.jaseci.org/quick-guide/
4. https://docs.jaseci.org/community/release_notes/jaclang/
5. https://github.com/jaseci-labs/jac

Never copy old Jac syntax from killBill, Sentinel, blog posts, or historical
SpendOS notes without compiler verification.

## Native CLI

Jac is one native binary. Do not install `jaclang`, `byllm`, `jac-client`,
`jac-scale`, or `jac-mcp` with pip.

```bash
cd spendos
jac --version
jac install --plan
jac install
jac check .
jac check --lint .
jac fmt
jac test
jac build
jac start --dev
```

Use `jac precommit` as the standard local/CI quality gate after the project is
green. `jac lint` is obsolete; use `jac check --lint`.

## AI-assisted Jac work

```bash
jac guide --search walker
jac guide jac-walker-patterns
jac guide jac-by-llm
jac mcp --inspect
```

The project MCP server is configured under `.codex/config.toml` and
`.mcp.json`. It gives coding agents version-matched documentation plus compiler
validation, formatting, linting, running, and transpilation tools.

Refresh exported agent skills whenever Jac is upgraded:

```bash
jac guide --export .claude/skills
```

## Architecture rules

- The Jac graph is the canonical application state.
- Functions own pure parsing, normalization, statistics, and financial math.
- Walkers own graph traversal, persistent workflows, and user-scoped operations.
- Keep financial records under a per-user root once authentication is enabled.
- Never put private financial records under `root.shared`.
- Every mutating function or walker must be idempotent.
- Avoid module-global mutable request state.
- Typed edges carry relationship data; nodes carry entity data.
- A graph must be load-bearing: investigation must traverse graph evidence,
  preferences, and precedent.
- Client code calls server functions or spawns walkers directly. Do not add
  Express or hand-written REST glue.

## byLLM rules

- Use typed return objects.
- Add `sem` declarations to byLLM functions, parameters, tools, return types,
  and important fields. Docstrings are not model instructions.
- Tools return structured facts and evidence IDs.
- Jac validates cited evidence after the model call.
- Deterministic code recalculates all money values.
- Invalid or unsupported model output becomes `REVIEW`.
- The model cannot execute an action, widen a mandate, or bypass approval.
- No-key mode must remain honest and useful.

## Current compatibility rule

Do not preserve a historical “verified fact” merely because it worked on an old
compiler. Version-sensitive behavior needs a focused executable test.

The existing funding path relies on an edge entry ability. Keep that behavior
only if the pinned compiler and CI test prove it. Otherwise move the check into
a walker or node ability.

## Tests

Place Jac tests under `spendos/tests/` and configure:

```toml
[test]
directory = "tests"
```

Use descriptive filenames such as `import_tests.jac`; avoid `test_*.jac` for
server-side tests.

Required gates:

```bash
jac precommit
jac test
jac build
```

Run persistence stories three consecutive times. The second and third runs must
not duplicate statements, transactions, cases, precedents, or actions.

## Safety and honesty

- Never expose secrets or real financial data.
- Never present cached or simulated output as live.
- Never infer non-use from payments alone.
- Never let an LLM own arithmetic or authorization.
- Never claim real-time monitoring while input is CSV-only.
- Never execute cancellation, communication, purchase, or transfer without the
  required explicit authority.

## Plans

- `SIMPLE_PLAN.md` is the implementation order.
- `PRODUCT_PLAN.md` is the product and architecture contract.
- `SpendOS.md` documents the original payment-firewall prototype and is
  historical context, not current language authority.
