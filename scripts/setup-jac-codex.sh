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
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Using $(jac --version)"
echo "Exporting version-matched Jac skills to $codex_home/skills..."
jac guide --export "$codex_home/skills"

echo "Checking the Jac MCP inventory..."
jac mcp --inspect

if command -v codex >/dev/null 2>&1; then
  if ! codex plugin list | grep -Fq 'Marketplace `jachacks-sf-2026`'; then
    echo "Registering the repository's Codex plugin marketplace..."
    codex plugin marketplace add "$repo_root"
  fi

  echo "Installing the Jac Codex plugin..."
  codex plugin add jac-codex@jachacks-sf-2026

  if ! codex plugin list | grep -Fq 'jac-codex@jachacks-sf-2026'; then
    echo "Jac Codex plugin installation could not be verified."
    exit 1
  fi
else
  echo "Codex CLI is not on PATH; Jac CLI, MCP, and skills are configured."
  echo "Install the plugin later with: codex plugin marketplace add \"$repo_root\""
fi

echo "Jac MCP, skills, validation hook, and Codex plugin are ready."
echo "Restart Codex or open a new thread to reload them."
