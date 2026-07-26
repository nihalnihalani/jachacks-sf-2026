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
inventory, and exports Jac's bundled guides to `~/.codex/skills`. Restart Codex
afterward so the current application process reloads its MCP and skill
inventory.

## How the layers work

- The CLI builds, runs, checks, formats, and tests the project.
- MCP gives Codex live compiler, documentation, execution, and transpilation
  tools.
- The `jac-*` skills give Codex version-matched language and architecture
  guidance.

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
