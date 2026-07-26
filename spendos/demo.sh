#!/usr/bin/env bash
# SpendOS — clean-start demo runbook.
#
# ALWAYS rehearse from this script. `root` persists across runs, so a demo
# started by hand inherits whatever the last run left behind: a drained
# treasury, a full velocity window, and gate verdicts that drift. Both
# persistence bugs we hit were invisible on run 1 and only appeared on run 3
# — i.e. on stage, not in dev.
#
#   ./demo.sh            clean slate, run the assertion suite, start the UI
#   ./demo.sh --check    verify only, do not start the server (use pre-demo)

set -euo pipefail
cd "$(dirname "$0")"

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

echo "==> stopping any running jac server"
# Two jac processes on one project throw WriteConflict on the root anchor.
pkill -f "jac start" 2>/dev/null || true
sleep 2

echo "==> clearing persisted graph (.jac/data)"
rm -rf .jac/data

echo "==> verifying seed + OFAC dataset"
python3 seed.py --check

echo "==> running the assertion suite (0 LLM calls, no API key needed)"
if ! jac run smoke.jac 2>&1 | tee /tmp/spendos_smoke.out | grep -q "halted where expected"; then
    echo ""
    echo "!! SMOKE FAILED — do not demo. Output:"
    cat /tmp/spendos_smoke.out
    exit 1
fi
grep -E "^\s+\[|all [0-9]+ payments" /tmp/spendos_smoke.out

echo ""
if [[ -f .env ]] && grep -qE "^(OPENAI|ANTHROPIC|GEMINI)_API_KEY=.+" .env; then
    echo "==> LAYER 1: an API key is present — the intent gate can reach a model"
else
    echo "==> LAYER 2: no API key — deterministic gates only."
    echo "    This is a supported, honest mode. Say so on stage."
fi

if [[ $CHECK_ONLY == 1 ]]; then
    echo ""
    echo "==> --check complete. Nothing started."
    exit 0
fi

echo ""
echo "==> starting the UI  (the -d is REQUIRED; bare \`jac start\` serves the API only)"
echo "    Read the App: line below for the real port — it drifts when one is held."
exec jac start -d
