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
