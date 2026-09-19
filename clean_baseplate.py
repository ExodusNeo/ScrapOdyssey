from studio_client import StudioClient

client = StudioClient()

cleanup_code = """
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
    baseplate:Destroy()
    print("Destroyed legacy Baseplate to eliminate Z-fighting!")
end

local legacyPart = workspace:FindFirstChild("Part")
if legacyPart then
    legacyPart:Destroy()
end

return "Workspace cleaned"
"""

res = client.execute_luau(cleanup_code)
print(res)
client.close()
