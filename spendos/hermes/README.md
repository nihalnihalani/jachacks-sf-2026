# Hermes Agent integration

This directory contains a narrow MCP bridge between Hermes Agent and the local
SpendOS Jac API. It is intentionally an adapter rather than a second financial
backend: Jac remains authoritative for persisted graph state, financial
arithmetic, policy outcomes, and approvals.

The bridge uses Python's standard library because Jac 0.34.7 provides an MCP
server for compiler/agent tooling (`jac mcp`), not a documented application MCP
server SDK. The adapter has no package install, no model dependency, and no
access to raw statements or credentials.

## Safe tool surface

- `get_financial_snapshot` — summarized budget and subscription totals
- `list_purchase_proposals` — previously recorded proposals
- `check_purchase_preflight` — non-persistent budget-impact preview
- `propose_purchase` — records a proposal; never executes it
- `list_pending_approvals` — proposals awaiting a human decision
- `list_shopping_missions` — missions dispatched from SpendOS
- `claim_shopping_mission` — assigns a research mission to Hermes
- `submit_shopping_candidate` — returns one evidence-backed option
- `complete_shopping_mission` — marks returned research ready for review

There are deliberately no approve, purchase, cancellation, bank, transfer, or
communication tools.

## Run and verify

Start SpendOS in one terminal:

```bash
cd /Users/alhinai/Desktop/repo/jachacks/jachacks-sf-2026/spendos
jac start --dev --port 8012 --client-port 8011
```

Then run the model-free stdio smoke test in another terminal:

```bash
cd /Users/alhinai/Desktop/repo/jachacks/jachacks-sf-2026/spendos
SPENDOS_API_URL=http://127.0.0.1:8012 \
  /usr/bin/python3 hermes/smoke_test.py
```

The test performs MCP initialization, verifies the exact tool allowlist, rejects
unsafe tool names, and calls the live SpendOS financial snapshot. It does not
create a proposal.

## Run for the installed Docker Hermes

The live installation is Hermes Agent v0.19.0 in the `hermes` container. Its
only mount is the Docker volume at `/opt/data`; this repository is not mounted
in the container. Run the bridge on the host:

```bash
cd /Users/alhinai/Desktop/repo/jachacks/jachacks-sf-2026/spendos
SPENDOS_API_URL=http://127.0.0.1:8012 \
  /usr/bin/python3 hermes/mcp_http_server.py --host 0.0.0.0 --port 8765
```

Docker Desktop reaches it at:

```text
http://host.docker.internal:8765/mcp
```

Binding `0.0.0.0` is needed for Docker Desktop but can expose the port to the
local network. Keep this demo bridge short-lived, or set `SPENDOS_MCP_TOKEN` and
configure the same value as an `Authorization: Bearer ...` header in Hermes.
Do not expose this unauthenticated demo through a public tunnel.

## Connect Hermes without changing config automatically

Hermes is installed inside Docker rather than on the host `PATH`. Current
official Hermes documentation and the live v0.19.0 CLI support remote MCP
servers and per-server `tools.include` allowlists:

```bash
docker exec -it hermes hermes mcp add spendos \
  --url http://host.docker.internal:8765/mcp
docker exec -it hermes hermes mcp test spendos
docker exec -it hermes hermes mcp configure spendos
```

For an auditable manual setup, merge the `spendos` block from
`config.example.yaml` into your Hermes configuration. Do not replace the entire
file. The sample explicitly disables MCP resources and prompts and allowlists
only the nine tools above.

Copy `SPENDOS_SKILL.md` into the Hermes skill location appropriate to your
installation, or include its rules in the agent's context. It defines the
required call order and the boundary between analysis, proposal, approval, and
execution.

## Configuration

The only bridge environment variable is:

```text
SPENDOS_API_URL=http://127.0.0.1:8012
```

No secret is required for the current local demo. A production deployment must
add SpendOS authentication and transport security before exposing financial
data beyond loopback.

## Current limits

- The bridge expects SpendOS on a trusted local loopback interface.
- The Jac demo still uses its current guest/user graph behavior.
- Preflight is based on the configured Budget Guard and does not authorize
  spending.
- Shopping missions authorize research only. Hermes returns candidates to
  SpendOS, which independently checks total and recurring costs.
- Background monitoring and scheduled Hermes jobs are a later increment.

Official references:

- https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp
- https://hermes-agent.nousresearch.com/docs/reference/mcp-config-reference
- https://hermes-agent.nousresearch.com/docs/reference/cli-commands
