# Jac CLI, MCP, and skills for Codex

The repository's `.codex/config.toml` registers the MCP server bundled with
Jac:

```toml
[mcp_servers.jac]
command = "jac"
args = ["mcp"]
```

Run the setup script once on each development machine:

```bash
./scripts/setup-jac-codex.sh
```

It installs the self-contained Jac binary when needed, verifies the MCP
inventory, exports Jac's bundled guides to `~/.codex/skills`, registers this
repository as a Codex plugin marketplace, and installs `jac-codex`. Restart
Codex afterward so the current application process reloads its MCP, skills,
and hook inventory.

## How the layers work

- The CLI builds, runs, checks, formats, and tests the project.
- MCP gives Codex live compiler, documentation, execution, and transpilation
  tools.
- The `jac-*` skills give Codex version-matched language and architecture
  guidance.
- The [`jac-codex`](../plugins/jac-codex/) plugin packages 41 Jac workflows for
  Codex and runs `jac check` automatically after Codex writes or edits a
  `.jac` file.

Use all three:

```bash
jac --version
jac guide --search walker
jac check
jac check --lint
jac fmt
jac test
jac mcp --inspect
```

Refresh the Codex skills whenever Jac is upgraded:

```bash
jac guide --export ~/.codex/skills
```

The exported catalog includes the core language, graph/walker, byLLM,
full-stack client/server, persistence, authentication, deployment, native,
testing, and debugging guides.

## Manual plugin installation

If you do not use the setup script:

```bash
codex plugin marketplace add .
codex plugin add jac-codex@jachacks-sf-2026
codex plugin list
```

The validation hook ignores non-Jac edits. For `.jac` files it runs
`jac check <changed-file>` and surfaces compiler diagnostics before Codex
finalizes its work.
