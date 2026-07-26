#!/usr/bin/env bash

set -euo pipefail

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI is required: https://developers.openai.com/codex/cli"
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Node.js with npx is required: https://nodejs.org/"
  exit 1
fi

if [[ -z "${API_KEY_21ST:-}" ]]; then
  echo "Set API_KEY_21ST in the shell that launches Codex, then rerun this script."
  exit 1
fi

echo "Installing the official 21st skill pack..."
npx --yes @21st-dev/cli@latest install-skill

if codex mcp get 21st >/dev/null 2>&1; then
  echo "The global 21st MCP entry is already configured."
else
  codex mcp add 21st \
    --url https://21st.dev/api/mcp \
    --bearer-token-env-var API_KEY_21ST
fi

echo "21st setup complete. Restart Codex before using the new skills."
