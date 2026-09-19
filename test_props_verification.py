from studio_client import StudioClient

def verify_props():
    client = StudioClient()
    code = """
    local out = {}
    for i = 1, 5 do
        local name = (i == 1 and "CentralHub" or ("Zone_" .. i))
        local f = workspace:FindFirstChild(name)
        if f then
            local t = f:FindFirstChild("ThematicProps_Zone" .. i)
            local count = t and #t:GetChildren() or 0
            table.insert(out, string.format("%s: %d props", name, count))
        else
            table.insert(out, name .. ": NOT FOUND")
        end
    end
    return table.concat(out, " | ")
    """
    res = client.execute_luau(code)
    print("Verification Result:", res.get("result", {}).get("content", [{}])[0].get("text", ""))
    client.close()

if __name__ == "__main__":
    verify_props()
