#!/usr/bin/env python3
"""Safe, zero-dependency MCP adapter from Hermes Agent to SpendOS.

The adapter deliberately exposes no approval, cancellation, purchase execution,
banking, or raw-statement tools. It speaks MCP over stdio and calls the local
SpendOS Jac API over HTTP.
"""

from __future__ import annotations

import json
import os
import sys
import threading
import urllib.error
import urllib.request
from collections import deque
from datetime import datetime, timezone
from http.cookiejar import CookieJar
from typing import Any


API_URL = os.environ.get("SPENDOS_API_URL", "http://127.0.0.1:8012").rstrip("/")
PROTOCOL_VERSION = "2025-06-18"
API_OPENER = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(CookieJar())
)
ACTIVITY_LOCK = threading.Lock()
ACTIVITY_SEQUENCE = 0
ACTIVITY_EVENTS: deque[dict[str, Any]] = deque(maxlen=200)


def record_activity(
    tool: str, phase: str, title: str, detail: str = "", status: str = "active"
) -> dict[str, Any]:
    """Record a display-safe Hermes event without financial payloads or secrets."""
    global ACTIVITY_SEQUENCE
    with ACTIVITY_LOCK:
        ACTIVITY_SEQUENCE += 1
        event = {
            "id": ACTIVITY_SEQUENCE,
            "time": datetime.now(timezone.utc).isoformat(),
            "tool": tool,
            "phase": phase,
            "title": title[:140],
            "detail": detail[:240],
            "status": status,
        }
        ACTIVITY_EVENTS.append(event)
        return event


def get_activity(after: int = 0) -> list[dict[str, Any]]:
    with ACTIVITY_LOCK:
        return [dict(event) for event in ACTIVITY_EVENTS if event["id"] > after]


def activity_description(name: str, arguments: dict[str, Any]) -> tuple[str, str]:
    if name == "start_shopping_request":
        return "Received shopping request", str(arguments.get("request", ""))
    if name == "get_financial_snapshot":
        return "Checking SpendOS guardrails", "Reading the current safe financial boundary."
    if name == "check_purchase_preflight":
        return "Checking affordability", "Computing the deterministic budget impact."
    if name == "propose_purchase":
        return "Submitting purchase proposal", str(arguments.get("merchant", ""))
    if name == "list_shopping_missions":
        return "Looking for shopping work", "Checking the SpendOS mission queue."
    if name == "claim_shopping_mission":
        return "Hermes claimed the mission", str(arguments.get("mission_id", ""))
    if name == "submit_shopping_candidate":
        product = str(arguments.get("product", "Product"))
        merchant = str(arguments.get("merchant", "merchant"))
        return "Found a candidate", f"{product} at {merchant}"
    if name == "resolve_products":
        return "Searching the configured catalog", str(arguments.get("query", ""))
    if name == "add_to_cart":
        return "Building the proposed cart", str(arguments.get("product_id", ""))
    if name == "view_cart":
        return "Verifying cart totals", str(arguments.get("store", ""))
    if name == "simulate_order":
        return "Creating simulated confirmation", str(arguments.get("store", ""))
    if name == "complete_shopping_mission":
        return "Research ready for review", str(arguments.get("mission_id", ""))
    return name.replace("_", " ").title(), "SpendOS tool activity."


TOOLS: list[dict[str, Any]] = [
    {
        "name": "start_shopping_request",
        "description": (
            "Create a SpendOS shopping-research mission directly from a user "
            "request received by Hermes. This authorizes research only."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["request", "maximum_budget"],
            "properties": {
                "request": {"type": "string", "minLength": 1},
                "maximum_budget": {"type": "number", "exclusiveMinimum": 0},
                "preferences": {"type": "string", "default": ""},
            },
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": True,
        },
    },
    {
        "name": "get_financial_snapshot",
        "description": (
            "Read the current SpendOS budget and subscription summary. "
            "This tool is read-only and returns no raw bank transactions."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "list_purchase_proposals",
        "description": (
            "List purchase proposals already recorded by SpendOS. Optionally "
            "filter by proposal state. This tool is read-only."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "state": {
                    "type": "string",
                    "description": "Optional exact state such as PROPOSED, AWAITING_APPROVAL, or BLOCKED.",
                }
            },
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "check_purchase_preflight",
        "description": (
            "Preview the deterministic monthly budget impact of a proposed "
            "purchase without recording or executing it."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["amount", "cadence"],
            "properties": {
                "amount": {"type": "number", "exclusiveMinimum": 0},
                "cadence": {
                    "type": "string",
                    "enum": ["ONE_TIME", "MONTHLY", "QUARTERLY", "ANNUAL"],
                },
            },
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "propose_purchase",
        "description": (
            "Ask SpendOS to record and evaluate a purchase proposal. This does "
            "not approve, buy, subscribe, transfer funds, or execute any action."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["agent_id", "merchant", "purpose", "amount", "cadence"],
            "properties": {
                "agent_id": {
                    "type": "string",
                    "minLength": 1,
                    "description": "Stable identity of the proposing agent.",
                },
                "merchant": {"type": "string", "minLength": 1},
                "purpose": {"type": "string", "minLength": 1},
                "amount": {"type": "number", "exclusiveMinimum": 0},
                "cadence": {
                    "type": "string",
                    "enum": ["ONE_TIME", "MONTHLY", "QUARTERLY", "ANNUAL"],
                },
            },
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": True,
        },
    },
    {
        "name": "list_pending_approvals",
        "description": (
            "List proposals awaiting a human decision. This tool cannot resolve "
            "or bypass an approval."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "list_shopping_missions",
        "description": (
            "List shopping missions dispatched by SpendOS, including their "
            "budget, preferences, state, and returned candidates."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "status": {
                    "type": "string",
                    "description": "Optional exact status such as DISPATCHED or IN_PROGRESS.",
                }
            },
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "claim_shopping_mission",
        "description": (
            "Claim one SpendOS shopping-research mission for Hermes. This "
            "authorizes research only, never checkout or payment."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["mission_id", "agent_id"],
            "properties": {
                "mission_id": {"type": "string", "minLength": 1},
                "agent_id": {"type": "string", "minLength": 1},
            },
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": True,
        },
    },
    {
        "name": "submit_shopping_candidate",
        "description": (
            "Return one evidence-backed product candidate to SpendOS. This "
            "records research only and cannot purchase the item."
        ),
        "inputSchema": {
            "type": "object",
            "required": [
                "mission_id", "agent_id", "merchant", "product", "price", "evidence"
            ],
            "properties": {
                "mission_id": {"type": "string", "minLength": 1},
                "agent_id": {"type": "string", "minLength": 1},
                "merchant": {"type": "string", "minLength": 1},
                "product": {"type": "string", "minLength": 1},
                "price": {"type": "number", "exclusiveMinimum": 0},
                "shipping": {"type": "number", "minimum": 0, "default": 0},
                "recurring_cost": {"type": "number", "minimum": 0, "default": 0},
                "product_url": {"type": "string", "default": ""},
                "evidence": {"type": "string", "minLength": 1},
            },
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": True,
        },
    },
    {
        "name": "complete_shopping_mission",
        "description": (
            "Tell SpendOS that Hermes finished research and the returned "
            "candidates are ready for human review. This cannot approve checkout."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["mission_id", "agent_id"],
            "properties": {
                "mission_id": {"type": "string", "minLength": 1},
                "agent_id": {"type": "string", "minLength": 1},
            },
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": True,
        },
    },
    {
        "name": "resolve_products",
        "description": (
            "Search the configured SpendOS catalog source. Results from the "
            "bundled CSV are simulated demo records, not live merchant data."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["store", "query"],
            "properties": {
                "store": {"type": "string", "minLength": 1},
                "query": {"type": "string", "minLength": 1},
            },
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "add_to_cart",
        "description": (
            "Add a catalog product to the local simulated SpendOS cart. "
            "This never changes a merchant cart or charges a payment method."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["store", "product_id", "quantity"],
            "properties": {
                "store": {"type": "string", "minLength": 1},
                "product_id": {"type": "string", "minLength": 1},
                "quantity": {"type": "number", "exclusiveMinimum": 0},
            },
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": False,
        },
    },
    {
        "name": "view_cart",
        "description": "Read and deterministically recompute the local simulated cart.",
        "inputSchema": {
            "type": "object",
            "required": ["store"],
            "properties": {"store": {"type": "string", "minLength": 1}},
            "additionalProperties": False,
        },
        "annotations": {"readOnlyHint": True, "destructiveHint": False},
    },
    {
        "name": "simulate_order",
        "description": (
            "Create a clearly marked SIMULATED order from the local cart. "
            "No address, payment credential, merchant checkout, or delivery is used."
        ),
        "inputSchema": {
            "type": "object",
            "required": ["store"],
            "properties": {"store": {"type": "string", "minLength": 1}},
            "additionalProperties": False,
        },
        "annotations": {
            "readOnlyHint": False,
            "destructiveHint": False,
            "idempotentHint": False,
        },
    },
]


class SpendOSError(RuntimeError):
    """Raised when the Jac API is unavailable or rejects a request."""


def post_function(name: str, body: dict[str, Any]) -> Any:
    request = urllib.request.Request(
        f"{API_URL}/function/{name}",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with API_OPENER.open(request, timeout=10) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:800]
        raise SpendOSError(f"SpendOS returned HTTP {error.code}: {detail}") from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise SpendOSError(
            f"SpendOS is unavailable at {API_URL}; start its Jac API first"
        ) from error

    if not payload.get("ok"):
        error = payload.get("error") or {}
        raise SpendOSError(error.get("message") or "SpendOS rejected the request")
    return payload.get("data", {}).get("result")


def dashboard() -> dict[str, Any]:
    result = post_function("get_dashboard", {"cache_bust": 0})
    if not isinstance(result, dict):
        raise SpendOSError("SpendOS returned an invalid dashboard")
    return result


def proposals(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    value = snapshot.get("proposals", [])
    return value if isinstance(value, list) else []


def monthly_cost(amount: float, cadence: str) -> float:
    factors = {
        "ONE_TIME": 1.0,
        "MONTHLY": 1.0,
        "QUARTERLY": 1.0 / 3.0,
        "ANNUAL": 1.0 / 12.0,
    }
    if cadence not in factors:
        raise SpendOSError(
            "cadence must be ONE_TIME, MONTHLY, QUARTERLY, or ANNUAL"
        )
    if amount <= 0:
        raise SpendOSError("amount must be greater than zero")
    return round(amount * factors[cadence], 2)


def financial_snapshot(value: dict[str, Any]) -> dict[str, Any]:
    budget = value.get("budget") or {}
    subscriptions = value.get("subscriptions") or []
    return {
        "currency": value.get("currency", "USD"),
        "transaction_count": value.get("transaction_count", 0),
        "subscription_count": len(subscriptions),
        "monthly_subscription_total": value.get("monthly_total", 0),
        "annual_subscription_total": value.get("annual_total", 0),
        "budget": {
            "configured": budget.get("configured", False),
            "monthly_income": budget.get("monthly_income", 0),
            "fixed_obligations": budget.get("fixed_obligations", 0),
            "recurring_obligations": budget.get("recurring_obligations", 0),
            "safety_reserve": budget.get("safety_reserve", 0),
            "safe_to_spend": budget.get("safe_to_spend", 0),
            "status": budget.get("status", "NOT_CONFIGURED"),
        },
        "notice": "Read-only snapshot; SpendOS did not move or spend money.",
    }


def call_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    if name == "start_shopping_request":
        result = post_function(
            "create_shopping_mission",
            {
                "shopping_request": arguments["request"],
                "maximum_budget": arguments["maximum_budget"],
                "preferences": arguments.get("preferences", ""),
            },
        )
    elif name == "get_financial_snapshot":
        result = financial_snapshot(dashboard())
    elif name == "list_purchase_proposals":
        items = proposals(dashboard())
        state = arguments.get("state")
        result = [item for item in items if not state or item.get("state") == state]
    elif name == "list_pending_approvals":
        result = [
            item
            for item in proposals(dashboard())
            if item.get("state") in {"PROPOSED", "AWAITING_APPROVAL"}
        ]
    elif name == "check_purchase_preflight":
        snapshot = financial_snapshot(dashboard())
        budget = snapshot["budget"]
        cost = monthly_cost(float(arguments["amount"]), arguments["cadence"])
        projected = round(float(budget["safe_to_spend"]) - cost, 2)
        if not budget["configured"]:
            outcome = "REVIEW"
            reason = "Configure Budget Guard before evaluating agent spending."
        elif projected < 0:
            outcome = "BLOCK"
            reason = "The proposal would make Safe to Spend negative."
        elif projected < max(100.0, float(budget["safety_reserve"]) * 0.25):
            outcome = "WARN"
            reason = "The proposal leaves only a small configured safety margin."
        else:
            outcome = "SAFE"
            reason = "The proposal remains within the configured Safe to Spend."
        result = {
            "monthly_cost": cost,
            "current_safe_to_spend": budget["safe_to_spend"],
            "projected_safe_to_spend": projected,
            "outcome": outcome,
            "reason": reason,
            "recorded": False,
            "executed": False,
        }
    elif name == "propose_purchase":
        result = post_function(
            "propose_purchase",
            {
                "agent_id": arguments["agent_id"],
                "merchant": arguments["merchant"],
                "purpose": arguments["purpose"],
                "amount": arguments["amount"],
                "cadence": arguments["cadence"],
            },
        )
    elif name == "list_shopping_missions":
        items = dashboard().get("shopping_missions", [])
        status = arguments.get("status")
        result = [
            item
            for item in items
            if isinstance(item, dict) and (not status or item.get("status") == status)
        ]
    elif name == "claim_shopping_mission":
        result = post_function("claim_shopping_mission", arguments)
    elif name == "submit_shopping_candidate":
        result = post_function(
            "submit_shopping_candidate",
            {
                "mission_id": arguments["mission_id"],
                "agent_id": arguments["agent_id"],
                "candidate_input": {
                    "merchant": arguments["merchant"],
                    "product": arguments["product"],
                    "price": arguments["price"],
                    "shipping": arguments.get("shipping", 0),
                    "recurring_cost": arguments.get("recurring_cost", 0),
                    "product_url": arguments.get("product_url", ""),
                    "evidence": arguments["evidence"],
                },
            },
        )
    elif name == "complete_shopping_mission":
        result = post_function("complete_shopping_mission", arguments)
    elif name == "resolve_products":
        result = post_function("resolve_products", arguments)
    elif name == "add_to_cart":
        result = post_function("add_to_cart", arguments)
    elif name == "view_cart":
        result = post_function("view_cart", arguments)
    elif name == "simulate_order":
        result = post_function("simulate_order", arguments)
    else:
        raise SpendOSError(f"Unknown tool: {name}")

    return {
        "content": [
            {
                "type": "text",
                "text": json.dumps(result, indent=2, sort_keys=True),
            }
        ],
        "structuredContent": {"result": result},
        "isError": False,
    }


def response(request_id: Any, result: Any = None, error: Any = None) -> None:
    payload: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id}
    if error is None:
        payload["result"] = result
    else:
        payload["error"] = error
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def dispatch(message: dict[str, Any]) -> tuple[Any, Any, Any] | None:
    method = message.get("method")
    request_id = message.get("id")
    if request_id is None:
        return None
    if method == "initialize":
        return (
            request_id,
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "spendos-safe-bridge", "version": "0.1.0"},
            },
            None,
        )
    if method == "ping":
        return request_id, {}, None
    if method == "tools/list":
        return request_id, {"tools": TOOLS}, None
    if method == "tools/call":
        params = message.get("params") or {}
        tool_name = params.get("name", "")
        arguments = params.get("arguments") or {}
        title, detail = activity_description(tool_name, arguments)
        record_activity(tool_name, "started", title, detail)
        try:
            result = call_tool(tool_name, arguments)
            record_activity(
                tool_name,
                "completed",
                title,
                "Completed safely. No checkout or payment occurred.",
                "complete",
            )
            return (
                request_id,
                result,
                None,
            )
        except (KeyError, TypeError, ValueError, SpendOSError) as error:
            record_activity(
                tool_name, "failed", title, str(error), "error"
            )
            return (
                request_id,
                {
                    "content": [{"type": "text", "text": str(error)}],
                    "isError": True,
                },
                None,
            )
    return (
        request_id,
        None,
        {"code": -32601, "message": f"Method not found: {method}"},
    )


def handle(message: dict[str, Any]) -> None:
    dispatched = dispatch(message)
    if dispatched is not None:
        request_id, result, error = dispatched
        response(
            request_id,
            result=result,
            error=error,
        )


def main() -> None:
    for line in sys.stdin:
        try:
            message = json.loads(line)
            if isinstance(message, dict):
                handle(message)
        except json.JSONDecodeError as error:
            response(
                None,
                error={"code": -32700, "message": f"Parse error: {error.msg}"},
            )


if __name__ == "__main__":
    main()
