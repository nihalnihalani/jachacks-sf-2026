#!/usr/bin/env bash

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
file_path=""

if command -v jq >/dev/null 2>&1 && [[ -n "$payload" ]]; then
  file_path="$(
    printf '%s' "$payload" |
      jq -r '
        .tool_input.file_path //
        .tool_input.path //
        .input.file_path //
        .input.path //
        empty
      ' 2>/dev/null |
      head -n 1
  )"
fi

if [[ -z "$file_path" && $# -gt 0 ]]; then
  file_path="$1"
fi

if [[ "$file_path" != *.jac ]]; then
  exit 0
fi

if [[ ! -f "$file_path" ]]; then
  printf '[jac-codex] Skipped validation: file not found: %s\n' "$file_path"
  exit 0
fi

if ! command -v jac >/dev/null 2>&1; then
  printf '[jac-codex] Jac is not installed; run the official installer before validation.\n'
  exit 0
fi

printf '[jac-codex] Validating %s\n' "$file_path"
if jac check "$file_path"; then
  printf '[jac-codex] Validation passed.\n'
else
  status=$?
  printf '[jac-codex] Validation failed. Fix the diagnostics before finalizing.\n'
  exit "$status"
fi
