---
name: jac-codex-workflow
description: End-to-end Codex workflow for creating, migrating, debugging, testing, and verifying Jac projects. Use for repositories containing .jac files or jac.toml, Jacpack templates, Jac compiler diagnostics, Jac hooks, byLLM code, walkers, full-stack Jac applications, or requests to make Jac code work on the installed toolchain.
---

# Jac Codex workflow

Use the bundled task-specific `jac-*` skill matching the request. Always load
`jac-core-cheatsheet`; load `jac-project-kinds` before choosing architecture.

## Workflow

1. Inspect `jac.toml`, the entry point, and `jac --version`.
2. Identify the project kind with `jac run --show` when supported.
3. Load only the relevant bundled Jac skills.
4. Preserve working behavior and secrets; never invent provider keys.
5. Validate incrementally:

   ```bash
   jac check <changed-paths>
   jac fmt <changed-paths> --check
   jac test
   ```

6. For full-stack apps, run `jac install`, start with `jac start --dev`, and
   exercise the actual browser and server endpoints.
7. For LLM features, use mocks in tests. Do not spend API credits merely to
   prove that code renders.

## Migration

Treat compiler diagnostics as authoritative. Fix the first root diagnostic
before cascades. Common obsolete forms include:

- `lambda x: T { ... }` → `lambda (x: T) { ... }`
- `[-->(?:Node)]` → `[-->][?:Node]`
- `import from X { Y };` → `import from X { Y }`

Do not silence errors with `any` or diagnostic suppression unless the user
explicitly accepts that trade-off.

## Jacpacks

Expand and verify a pack with:

```bash
jac create app-name --use ./template.jacpack --skip
cd app-name
jac install
jac check .
jac test
```

`jac jacpack` was removed. Create a pack with:

```bash
jac create --pack ./template-directory --pack_output template.jacpack
```

Read [references/local-corpus.md](references/local-corpus.md) when deeper
language or implementation evidence is needed.
