# Jac Language Reference for Codex

Copy the block below into a project-level `AGENTS.md` when Codex will write Jac.

```text
# Jac Language Reference (2026)

Use current official Jac documentation and compiler behavior. Jac evolves
quickly; never invent syntax or rely on deprecated Jaseci/plugin examples.

## Local authority

Read these before writing Jac:

1. Jac docs/upstream/jac/SKILL.md
2. Jac docs/REFERENCE_INDEX.md
3. The relevant file under Jac docs/official-docs/
4. Current examples and compiler tests when behavior is ambiguous

The compiler and current tests outrank stale prose.

## Current toolchain

Install on macOS/Linux or inside Windows WSL:

curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
jac --version

Common commands:

jac create <name> --kind web-app
jac install
jac run <file>
jac start
jac build
jac check
jac check --lint
jac fmt
jac test
jac guide
jac guide --export <directory>
jac mcp

Do not use `jac guide --export` without a destination.

## MCP

Run:

jac mcp

MCP configuration:

{
  "mcpServers": {
    "jac": {
      "command": "jac",
      "args": ["mcp"]
    }
  }
}

## Coding rules

- Jac is not Python: preserve mandatory types, semicolons, and braces.
- Use `def f(...) -> T by llm();` for meaning-typed LLM functions.
- Add `sem f = "...";` because semstrings provide prompt semantics;
  docstrings are human documentation and are not prompt instructions.
- `llm` is built in. Import `Model` only when configuring a model in code.
- Prefer the primary walker form `node spawn Walker()`.
- Use `root ++> Node(...)` for untyped graph connections and
  `a +>: EdgeType :+> b` for typed edges.
- A walker processes only nodes it visits. Use `visit [->:EdgeType:->]`
  to continue traversal.
- Declare typed `reports` fields on walkers that report values.
- Keep arithmetic, validation, authorization, and policy deterministic.
  Use `by llm()` for semantic judgment or constrained tool selection.
- Treat `root` persistence and client/server codespace boundaries as real
  application behavior.
- Use `[project].jac-version` in `jac.toml` when deployment must target an
  exact Jac toolchain.

## Required verification

Before completion:

jac check <file-or-project>
jac fmt <file-or-project>
jac check --lint <file-or-project>
jac test <path>

Run the program or application and verify its observed behavior.
```

For a larger model context, also attach `reference/jac-llmdocs.md`. For a live
reference, configure `jac mcp`.
