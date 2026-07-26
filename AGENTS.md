# SpendOS agent instructions

Follow `CLAUDE.md` for product, architecture, safety, and workflow rules.

Jac is a young and fast-moving language. Before editing `.jac` or `jac.toml`:

1. Run `jac --version`.
2. Use `jac guide --search <topic>` and read the relevant guide completely.
3. Consult https://docs.jaseci.org/reference/ and the latest release notes.
4. Validate code with `jac check .`, `jac check --lint .`, `jac fmt`, and
   `jac test`.
5. Use the project `jac mcp` server for live compiler/documentation tools when
   MCP is available.

Do not invent syntax, reuse deprecated commands, or rely on historical
project notes over the installed compiler's version-matched guide.

Use functions for pure computation and walkers for persistent graph traversal
and workflows. Keep the graph load-bearing, use typed byLLM outputs with `sem`
annotations, and enforce financial calculations and authorization
deterministically.

## 21st.dev UI workflows

Before substantial UI work, read the project's existing components, tokens,
spacing, naming, and responsive conventions. Reuse them instead of introducing
a parallel design system.

- Use `21st-ui-explore` when choosing a direction. Produce three meaningfully
  different approaches, compare their trade-offs side by side, and wait for a
  selection before implementing.
- Use `21st-ui-build` to build or substantially change a page or component.
  Reuse project primitives, pull proven patterns from 21st when useful, cover
  loading/empty/error/long-content states, and verify light/dark plus mobile and
  desktop before running typecheck and build.
- Use `21st-ui-review` for UI audits. Report evidence, fix only
  high-confidence defects, list judgment calls separately, and check both color
  schemes.
- Use `21st-design-sync` to publish project tokens. Confirm complete `:root`
  and `.dark` blocks and inspect the published preview in both schemes.
- Use `21st-registry` to publish or manage team components. Confirm imports and
  dependencies, inspect every demo in light/dark, propose metadata changes
  before applying them, and never delete or unpublish without explicit
  approval.

The repository config expects `API_KEY_21ST` in the environment. Never put a
real API key in source control, prompts, logs, screenshots, or generated files.
See `docs/21st.md` for setup and exact workflow templates.
