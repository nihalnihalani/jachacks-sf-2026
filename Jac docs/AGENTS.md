# Instructions for LLMs using this Jac corpus

Use this directory as the authoritative local reference when generating,
reviewing, or debugging Jac code.

## Required workflow

1. Read `upstream/jac/SKILL.md` completely.
2. Read `CODEX_PROMPT.md` for the compact current rules.
3. Identify the task category in `REFERENCE_INDEX.md`.
4. Read only the relevant current documentation and examples.
5. Check nearby compiler tests when syntax or behavior is ambiguous.
6. Never assume Jac is Python. Preserve Jac types, semicolons, braces,
   archetypes, abilities, codespaces, and graph semantics.
7. Prefer deterministic code for arithmetic, validation, and policy. Use
   `by llm()` for semantic judgment and agent tool selection.
8. Treat `root` persistence, walker traversal, access control, and
   client/server boundaries as real application behavior.
9. Validate work using the installed Jac binary:

   ```bash
   jac check <file-or-project>
   jac fmt <file-or-project>
   jac test <path>
   ```

10. Run the application or example and inspect the observed result before
   declaring success.

## Authority and freshness

- The core checkout and its documentation are the primary authority.
- Compiler tests outrank prose if current docs and implementation disagree.
- The repositories are shallow snapshots. Read `SOURCES.md` for captured
  revisions and run `./update-references.sh` when a current refresh is needed.
- Do not silently use deprecated plugin-era syntax. Current Jac capabilities
  are bundled in the self-contained binary; use current `jac.toml` and CLI
  documentation.
- Never invent a Jac feature because a similar Python, TypeScript, or older
  Jaseci feature exists.

## Website work

For full-stack websites, consult these in order:

1. `official-docs/build/fullstack-web.md`
2. `official-docs/tutorials/fullstack/setup.md`
3. `official-docs/reference/plugins/jac-client.md`
4. `agent-skills/jac-fullstack-patterns.md`
5. `agent-skills/jac-cl-components.md`
6. `agent-skills/jac-sv-endpoints.md`
7. `upstream/this_is_jac/`
8. `upstream/jac-client-examples/`

Keep client and server logic in Jac unless an external file is genuinely
required. Use generated cross-codespace calls rather than hand-written glue.
