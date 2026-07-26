#!/usr/bin/env bash

set -euo pipefail

if ! command -v jac >/dev/null 2>&1; then
  echo "Installing the official self-contained Jac binary..."
  curl -fsSL \
    https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh |
    bash
fi

if ! command -v jac >/dev/null 2>&1; then
  echo "Jac was installed but is not on PATH. Add ~/.local/bin and rerun."
  exit 1
fi

codex_home="${CODEX_HOME:-$HOME/.codex}"

echo "Using $(jac --version)"
echo "Exporting version-matched Jac skills to $codex_home/skills..."
jac guide --export "$codex_home/skills"

echo "Checking the Jac MCP inventory..."
jac mcp --inspect

echo "Jac MCP and Codex skills are ready. Restart Codex to reload them."
