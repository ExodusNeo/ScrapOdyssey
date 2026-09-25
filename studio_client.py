import subprocess
import json
import sys
import time

import os

import glob

def find_mcp_path():
    versions_dir = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions")
    candidates = glob.glob(os.path.join(versions_dir, "*", "StudioMCP.exe"))
    if candidates:
        # Pick the most recently modified StudioMCP.exe
        candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return candidates[0]
    return r"C:\Users\ddgut\AppData\Local\Roblox\Versions\version-c792f79abddd41bd\StudioMCP.exe"

MCP_PATH = find_mcp_path()

class StudioClient:
    def __init__(self):
        log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mcp_stderr.log")
        self.stderr_file = open(log_path, "w", encoding="utf-8")
        self.proc = subprocess.Popen(
            [MCP_PATH],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.stderr_file,
            text=True,
            encoding="utf-8",
            bufsize=1
        )
        self.req_id = 0
        self._initialize()
        self.studio_id = self._get_studio_id()

    def _call(self, method, params=None):
        self.req_id += 1
        payload = {"jsonrpc": "2.0", "id": self.req_id, "method": method, "params": params or {}}
        self.proc.stdin.write(json.dumps(payload) + "\n")
        self.proc.stdin.flush()
        line = self.proc.stdout.readline()
        return json.loads(line)

    def _notify(self, method, params=None):
        payload = {"jsonrpc": "2.0", "method": method, "params": params or {}}
        self.proc.stdin.write(json.dumps(payload) + "\n")
        self.proc.stdin.flush()

    def _initialize(self):
        self._call("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "Antigravity", "version": "1.0.0"}
        })
        self._notify("notifications/initialized")

    def _get_studio_id(self):
        for _ in range(15):
            time.sleep(1)
            res = self._call("tools/call", {"name": "list_roblox_studios", "arguments": {}})
            content = res.get("result", {}).get("content", [])
            for c in content:
                try:
                    parsed = json.loads(c.get("text", ""))
                    studios = parsed.get("studios", []) if isinstance(parsed, dict) else parsed
                    if studios:
                        return studios[0]["id"]
                except Exception:
                    pass
        raise RuntimeError("No connected Roblox Studio found")

    def call_tool(self, name, args):
        args["studio_id"] = self.studio_id
        return self._call("tools/call", {"name": name, "arguments": args})

    def execute_luau(self, code, datamodel_type="Edit"):
        return self.call_tool("execute_luau", {"code": code, "datamodel_type": datamodel_type})

    def get_console_output(self):
        return self.call_tool("get_console_output", {})

    def search_game_tree(self, path="Workspace", max_depth=3, datamodel_type="Edit"):
        return self.call_tool("search_game_tree", {"path": path, "max_depth": max_depth, "datamodel_type": datamodel_type})

    def close(self):
        self.proc.terminate()
        self.stderr_file.close()

if __name__ == "__main__":
    client = StudioClient()
    print("Connected to Studio ID:", client.studio_id)
    
    # Check what exists in ServerScriptService and ReplicatedStorage
    res = client.execute_luau("""
    local sss = {}
    for _, c in ipairs(game:GetService("ServerScriptService"):GetChildren()) do
        table.insert(sss, c.Name .. " (" .. c.ClassName .. ")")
    end
    local rep = {}
    for _, c in ipairs(game:GetService("ReplicatedStorage"):GetChildren()) do
        table.insert(rep, c.Name .. " (" .. c.ClassName .. ")")
    end
    return game:GetService("HttpService"):JSONEncode({ServerScriptService = sss, ReplicatedStorage = rep})
    """)
    print("Services content:", res.get("result", {}).get("content", [{}])[0].get("text", ""))
    client.close()
