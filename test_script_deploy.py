from studio_client import StudioClient
import os

client = StudioClient()

test_code = """
local s = Instance.new("Script")
s.Name = "TestScript"
s.Source = "print('Hello from MCP')"
s.Parent = game:GetService("ServerScriptService")
return s.Name
"""

res = client.execute_luau(test_code)
print("Execute result:", res)

# Clean up
client.execute_luau("""
local s = game:GetService("ServerScriptService"):FindFirstChild("TestScript")
if s then s:Destroy() end
""")

client.close()
