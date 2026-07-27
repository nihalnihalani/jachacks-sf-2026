#!/usr/bin/env python3
"""Minimal Streamable HTTP transport for the SpendOS safe MCP bridge."""

from __future__ import annotations

import argparse
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from mcp_server import dispatch, get_activity


class Handler(BaseHTTPRequestHandler):
    server_version = "SpendOSMCP/0.1"

    def _authorized(self) -> bool:
        token = os.environ.get("SPENDOS_MCP_TOKEN", "")
        if not token:
            return True
        return self.headers.get("Authorization") == f"Bearer {token}"

    def _headers(self, status: int, content_type: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "http://localhost:8011")
        self.end_headers()

    def do_HEAD(self) -> None:
        if self.path != "/mcp":
            self._headers(404)
            return
        self._headers(200)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._headers(200)
            self.wfile.write(b'{"status":"ok","service":"spendos-hermes-bridge"}')
            return
        if self.path.startswith("/events"):
            after = 0
            if "after=" in self.path:
                try:
                    after = int(self.path.split("after=", 1)[1].split("&", 1)[0])
                except ValueError:
                    after = 0
            encoded = json.dumps({"events": get_activity(after)}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Access-Control-Allow-Origin", "http://localhost:8011")
            self.end_headers()
            self.wfile.write(encoded)
            return
        if self.path == "/mcp":
            self._headers(405)
            self.wfile.write(b'{"error":"MCP requests use POST"}')
            return
        self._headers(404)

    def do_POST(self) -> None:
        if self.path != "/mcp":
            self._headers(404)
            return
        if not self._authorized():
            self._headers(401)
            self.wfile.write(b'{"error":"Unauthorized"}')
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            message = json.loads(self.rfile.read(length))
            if not isinstance(message, dict):
                raise ValueError("JSON-RPC request must be an object")
            result = dispatch(message)
            if result is None:
                self._headers(202)
                return
            request_id, value, error = result
            payload: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id}
            if error is None:
                payload["result"] = value
            else:
                payload["error"] = error
            encoded = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(encoded)
        except (json.JSONDecodeError, ValueError) as error:
            self._headers(400)
            self.wfile.write(
                json.dumps({"error": f"Invalid request: {error}"}).encode("utf-8")
            )

    def log_message(self, format: str, *args: Any) -> None:
        # Keep stdout clean and never log tool arguments or financial payloads.
        return


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"SpendOS safe MCP listening on http://{args.host}:{args.port}/mcp")
    server.serve_forever()


if __name__ == "__main__":
    main()
