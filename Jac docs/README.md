# Jac docs

Local, source-backed reference corpus for humans and LLMs building with the
Jac programming language.

This folder contains the current official compiler/runtime source,
documentation source, agent guides, examples, templates, editor grammar,
website source, workshop material, MCP examples, and the language-design book.
Each upstream project remains a Git checkout so its origin and revision are
auditable.

## Start here

For an LLM or coding agent:

1. Read [`AGENTS.md`](AGENTS.md).
2. Read the upstream [`SKILL.md`](upstream/jac/SKILL.md).
3. Use [`REFERENCE_INDEX.md`](REFERENCE_INDEX.md) to select the narrowest
   authoritative reference for the task.
4. Validate generated code with `jac check`, `jac fmt`, and `jac test`.

For a compact project prompt, copy the code box in
[`CODEX_PROMPT.md`](CODEX_PROMPT.md).

For a person:

1. Read [`INSTALL_AND_RUN.md`](INSTALL_AND_RUN.md).
2. Follow the official quick guide in
   [`official-docs/quick-guide`](official-docs/quick-guide).
3. Start with the core examples in [`core-examples`](core-examples).

## Folder map

| Path | Contents |
|---|---|
| `official-docs/` | Symlink to the complete current documentation source |
| `agent-skills/` | Symlink to Jac's built-in, task-specific agent guides |
| `core-examples/` | Symlink to examples shipped with the core repository |
| `reference/llms.txt` | Official model-oriented documentation index |
| `reference/jac-llmdocs.md` | Official condensed Jac context for LLMs |
| `reference/jac-language-design-book.pdf` | Jac's design and theory |
| `reference/papers/` | OSP, MTP, Jaseci runtime, and serverless papers |
| `examples/current-book-recommender/` | Small current-syntax Jac + byLLM example |
| `upstream/jac/` | Compiler, runtime, CLI, docs, tests, examples, and install script |
| `upstream/jac_site/` | Official website source |
| `upstream/this_is_jac/` | Official full-stack showcase application |
| `upstream/jac-client-examples/` | Full-stack client examples |
| `upstream/jac-client-templates/` | Starter templates |
| `upstream/jac-client-playground/` | Client compiler and UI experiments |
| `upstream/jacpacks/` | Ready-to-run official project packs |
| `upstream/jac-shadcn/` | shadcn component integration |
| `upstream/the-jac-workshop/` | Official workshop material |
| `upstream/jac-mcp-playground/` | MCP examples and experiments |
| `upstream/tree-sitter-jac/` | Jac grammar and editor parser |
| `upstream/jac-vscode/` | Official editor extension |
| `upstream/jaseci-llmdocs/` | Generator and releases for condensed LLM context |

## Source policy

Prefer sources in this order:

1. Current files in `upstream/jac/docs/docs/`.
2. Current compiler/runtime behavior and tests in `upstream/jac/jac/`.
3. Current built-in agent guides in `agent-skills/`.
4. Current official examples and templates.
5. The official website and workshop.

Do not copy old syntax from third-party blog posts when it conflicts with the
current docs or compiler. Jac is evolving quickly; always run the checker.

See [`SOURCES.md`](SOURCES.md) for exact revisions and online origins.
