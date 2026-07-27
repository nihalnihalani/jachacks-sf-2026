#!/usr/bin/env python3
"""Smoke-test MCP discovery and the safe SpendOS snapshot without a model key."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


SERVER = Path(__file__).with_name("mcp_server.py")
EXPECTED = {
    "get_financial_snapshot",
    "list_purchase_proposals",
    "check_purchase_preflight",
    "propose_purchase",
    "list_pending_approvals",
    "list_shopping_missions",
    "claim_shopping_mission",
    "submit_shopping_candidate",
    "complete_shopping_mission",
}
FORBIDDEN_FRAGMENTS = {"approve", "execute", "cancel", "transfer", "bank"}


def send(process: subprocess.Popen[str], payload: dict[str, Any]) -> dict[str, Any]:
    assert process.stdin is not None
    assert process.stdout is not None
    process.stdin.write(json.dumps(payload) + "\n")
    process.stdin.flush()
    line = process.stdout.readline()
    if not line:
        raise RuntimeError("MCP server closed without a response")
    return json.loads(line)


def main() -> int:
    process = subprocess.Popen(
        [sys.executable, str(SERVER)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        initialized = send(
            process,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {},
                    "clientInfo": {"name": "spendos-smoke", "version": "0.1.0"},
                },
            },
        )
        if initialized.get("result", {}).get("serverInfo", {}).get("name") != (
            "spendos-safe-bridge"
        ):
            raise RuntimeError("MCP initialize returned unexpected server metadata")

        listed = send(
            process,
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        )
        names = {
            tool["name"] for tool in listed.get("result", {}).get("tools", [])
        }
        if names != EXPECTED:
            raise RuntimeError(f"Unexpected tool surface: {sorted(names)}")
        forbidden = {
            name
            for name in names
            if any(fragment in name for fragment in FORBIDDEN_FRAGMENTS)
        }
        if forbidden:
            raise RuntimeError(f"Unsafe tools exposed: {sorted(forbidden)}")

        snapshot = send(
            process,
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "get_financial_snapshot",
                    "arguments": {},
                },
            },
        )
        tool_result = snapshot.get("result", {})
        if tool_result.get("isError"):
            message = tool_result.get("content", [{}])[0].get("text", "")
            raise RuntimeError(message)

        print("PASS: MCP initialize")
        print(f"PASS: exact safe tool surface ({len(names)} tools)")
        print("PASS: SpendOS API snapshot at configured SPENDOS_API_URL")
        print("PASS: no model or API key required")
        return 0
    finally:
        process.terminate()
        process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
