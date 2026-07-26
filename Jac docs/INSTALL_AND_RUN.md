# Install and run Jac

These instructions reflect the official repository and documentation captured
in this folder.

## macOS and Linux

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
jac --version
```

The installer places the self-contained binary at `~/.local/bin/jac`. If the
command is not found, add `~/.local/bin` to `PATH`.

The older `jaseci-labs/jac/.../install.sh` URL should not be used in new
instructions. The official current installer URL uses `jaseci-labs/jaseci`;
GitHub currently resolves the `jac` and `jaseci` repository names to the same
upstream project.

## Windows

Jac currently runs on Windows through WSL:

1. Open PowerShell as Administrator.
2. Run:

   ```powershell
   wsl --install
   ```

3. Restart if prompted.
4. Open Ubuntu and complete its initial setup.
5. In Ubuntu, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
   jac --version
   ```

## First program

Create `hello.jac`:

```jac
with entry {
    print("Hello from Jac!");
}
```

Run it:

```bash
jac run hello.jac
```

## Create and run a website

```bash
jac create myapp --kind web-app
cd myapp
jac install
jac start
```

Open the URL printed by `jac start`. The default entry point is `main.jac`.

## Run an existing project

From a folder containing `jac.toml`:

```bash
jac install
jac check
jac test
jac start
```

For a standalone file:

```bash
jac run app.jac
```

## Essential commands

| Command | Purpose |
|---|---|
| `jac run` | Run the current project or a Jac file |
| `jac create` | Scaffold a project |
| `jac install` | Resolve project dependencies |
| `jac start` | Start an API or full-stack application |
| `jac dev` | Development loop with hot reload |
| `jac check` | Type-check |
| `jac fmt` | Format |
| `jac test` | Run tests |
| `jac build` | Build a sealed application bundle |
| `jac guide` | Read built-in guides |
| `jac mcp` | Start the built-in MCP server for AI assistants |

For the complete and current command surface, read
`official-docs/reference/cli/index.md`.

## Alternative installations

Docker:

```bash
docker pull jaseci/jaclang
docker run --rm -v "$(pwd):/app" -w /app jaseci/jaclang run main.jac
```

Arch Linux:

```bash
paru -S jaclang
```

## Help

- Documentation: https://docs.jaseci.org
- Repository: https://github.com/jaseci-labs/jac
- Discord: https://discord.gg/6j3QNdtcN6
