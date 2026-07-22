#!/usr/bin/env python3
"""Minimal MCP-over-HTTP client for PixelLab. Usage:
  pixellab_mcp.py call <tool_name> '<json_args>'
"""
import json, sys, urllib.request

URL = "https://api.pixellab.ai/mcp"
TOKEN = json.load(open("/Users/nicolassutcliffe/brotato-mods/.mcp.json"))["mcpServers"]["pixellab"]["headers"]["Authorization"]

def post(payload, session_id=None):
    headers = {
        "Authorization": TOKEN,
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if session_id:
        headers["Mcp-Session-Id"] = session_id
    req = urllib.request.Request(URL, data=json.dumps(payload).encode(), headers=headers)
    resp = urllib.request.urlopen(req, timeout=120)
    sid = resp.headers.get("Mcp-Session-Id", session_id)
    body = resp.read().decode()
    ctype = resp.headers.get("Content-Type", "")
    if "text/event-stream" in ctype:
        # parse SSE: take data: lines
        msgs = []
        for line in body.splitlines():
            if line.startswith("data:"):
                data = line[5:].strip()
                if data:
                    msgs.append(json.loads(data))
        return msgs, sid
    if body.strip():
        return [json.loads(body)], sid
    return [], sid

def main():
    tool = sys.argv[2] if len(sys.argv) > 2 else None
    args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}

    init = {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "claude-cli", "version": "1.0"},
    }}
    msgs, sid = post(init)
    # send initialized notification
    post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)

    if sys.argv[1] == "list-tools":
        msgs, _ = post({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}, sid)
    else:
        msgs, _ = post({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                        "params": {"name": tool, "arguments": args}}, sid)
    for m in msgs:
        if m.get("id") == 2:
            print(json.dumps(m, indent=2))

if __name__ == "__main__":
    main()
