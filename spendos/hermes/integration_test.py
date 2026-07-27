#!/usr/bin/env python3
"""Exercise the complete safe SpendOS-Hermes MCP shopping loop.

This creates local demo graph records and a SIMULATED order. It never contacts
a merchant, submits an address, uses payment data, or performs checkout.
"""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from typing import Any


EXPECTED_TOOLS = {
    "start_shopping_request",
    "get_financial_snapshot",
    "list_purchase_proposals",
    "check_purchase_preflight",
    "propose_purchase",
    "list_pending_approvals",
    "list_shopping_missions",
    "claim_shopping_mission",
    "submit_shopping_candidate",
    "complete_shopping_mission",
    "resolve_products",
    "add_to_cart",
    "view_cart",
    "simulate_order",
    "browser_navigate",
    "browser_snapshot",
    "browser_click",
    "browser_type",
    "browser_screenshot",
    "browser_request_takeover",
}


class MCPClient:
    def __init__(self, url: str) -> None:
        self.url = url
        self.request_id = 0

    def request(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        self.request_id += 1
        payload = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params,
        }
        request = urllib.request.Request(
            self.url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                result = json.load(response)
        except (urllib.error.URLError, TimeoutError) as error:
            raise RuntimeError(f"Cannot reach SpendOS MCP bridge at {self.url}") from error
        if "error" in result:
            raise RuntimeError(f"MCP error: {result['error']}")
        return result["result"]

    def call(self, name: str, arguments: dict[str, Any]) -> Any:
        result = self.request(
            "tools/call", {"name": name, "arguments": arguments}
        )
        if result.get("isError"):
            detail = result.get("content", [{}])[0].get("text", "Unknown tool error")
            raise RuntimeError(f"{name} failed: {detail}")
        return result["structuredContent"]["result"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8765/mcp")
    args = parser.parse_args()
    client = MCPClient(args.url)

    initialized = client.request(
        "initialize",
        {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "spendos-integration", "version": "0.1.0"},
        },
    )
    assert initialized["serverInfo"]["name"] == "spendos-safe-bridge"
    tools = client.request("tools/list", {})
    names = {tool["name"] for tool in tools["tools"]}
    assert names == EXPECTED_TOOLS, sorted(names)

    snapshot = client.call("get_financial_snapshot", {})
    assert snapshot["notice"].startswith("Read-only snapshot")

    unique = str(time.time_ns())
    mission = client.call(
        "start_shopping_request",
        {
            "request": f"Find one assorted six-count chocolate box at Target [{unique}]",
            "maximum_budget": 25.0,
            "preferences": "No subscription and no recurring delivery.",
        },
    )
    assert mission["status"] == "DISPATCHED"
    mission_id = mission["mission_id"]

    claimed = client.call(
        "claim_shopping_mission",
        {"mission_id": mission_id, "agent_id": "hermes-integration"},
    )
    assert claimed["status"] == "IN_PROGRESS"
    assert claimed["assigned_agent"] == "hermes-integration"

    products = client.call(
        "resolve_products",
        {"store": "Target", "query": "assorted chocolate six count"},
    )
    assert products
    product = products[0]
    assert product["product_id"] == "target-chocolate-assorted-6"
    assert product["in_stock"] is True

    candidate = client.call(
        "submit_shopping_candidate",
        {
            "mission_id": mission_id,
            "agent_id": "hermes-integration",
            "merchant": product["store"],
            "product": product["name"],
            "price": product["price"],
            "shipping": 0.0,
            "recurring_cost": 0.0,
            "product_url": "",
            "evidence": (
                "Matched bundled SIMULATED_CATALOG record "
                f"{product['product_id']}; stock flag is true."
            ),
        },
    )
    assert candidate["within_budget"] is True
    assert candidate["recurring_cost"] == 0.0

    completed = client.call(
        "complete_shopping_mission",
        {"mission_id": mission_id, "agent_id": "hermes-integration"},
    )
    assert completed["status"] == "READY_FOR_REVIEW"
    assert completed["candidates"]

    existing_cart = client.call("view_cart", {"store": "Target"})
    if existing_cart["lines"]:
        previous = client.call("simulate_order", {"store": "Target"})
        assert previous["status"] == "SIMULATED"

    cart = client.call(
        "add_to_cart",
        {
            "store": "Target",
            "product_id": product["product_id"],
            "quantity": 1.0,
        },
    )
    assert len(cart["lines"]) == 1
    assert cart["subtotal"] == product["price"]
    assert cart["grand_total"] == round(product["price"] + 4.99, 2)

    verified_cart = client.call("view_cart", {"store": "Target"})
    assert verified_cart["grand_total"] == cart["grand_total"]

    preflight = client.call(
        "check_purchase_preflight",
        {"amount": verified_cart["grand_total"], "cadence": "ONE_TIME"},
    )
    assert preflight["outcome"] in {"SAFE", "WARN", "BLOCK", "REVIEW"}
    assert preflight["recorded"] is False
    assert preflight["executed"] is False

    order = client.call("simulate_order", {"store": "Target"})
    assert order["status"] == "SIMULATED"
    assert order["grand_total"] == verified_cart["grand_total"]
    assert "No real charge" in order["disclosure"]
    assert client.call("view_cart", {"store": "Target"})["lines"] == []

    print("PASS: Hermes discovered the exact 20-tool SpendOS surface")
    print("PASS: Hermes -> SpendOS mission creation")
    print("PASS: SpendOS -> Hermes mission claim and research queue")
    print("PASS: catalog search and evidence-backed candidate return")
    print("PASS: deterministic cart totals and financial preflight")
    print("PASS: SIMULATED order only; no checkout or payment occurred")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
