from studio_client import StudioClient

def rebuild():
    client = StudioClient()
    print("Rebuilding Central Hub in Studio with fresh Config...")
    code = """
    local RS = game:GetService("ReplicatedStorage")
    local SSS = game:GetService("ServerScriptService")

    local origConfig = RS.Modules.Config
    local freshConfig = origConfig:Clone()
    origConfig.Name = "Config_Old"
    freshConfig.Name = "Config"
    freshConfig.Parent = RS.Modules

    local origZS = SSS.Systems.ZoneService
    local freshZS = origZS:Clone()
    origZS.Name = "ZoneService_Old"
    freshZS.Name = "ZoneService"
    freshZS.Parent = SSS.Systems

    local ZoneService = require(freshZS)
    ZoneService.init()

    local results = {}
    local zones = { "CentralHub", "Zone_2", "Zone_3", "Zone_4", "Zone_5" }
    for _, zName in ipairs(zones) do
        local f = workspace:FindFirstChild(zName)
        if f then
            for _, child in ipairs(f:GetChildren()) do
                if child.Name:match("^ScrapPile") then
                    local maxHP = child:GetAttribute("MaxHP")
                    local isDense = child:GetAttribute("IsDense")
                    local baseYield = child:GetAttribute("BaseYield")
                    table.insert(results, string.format("%s (%s): MaxHP=%s, Dense=%s, BaseYield=%s", zName, child.Name, tostring(maxHP), tostring(isDense), tostring(baseYield)))
                end
            end
        end
    end

    freshZS:Destroy()
    origZS.Name = "ZoneService"

    freshConfig:Destroy()
    origConfig.Name = "Config"

    return table.concat(results, "\\n")
    """
    res = client.execute_luau(code)
    print("=== REBUILD RESULT ===")
    print(res.get("result", {}).get("content", [{}])[0].get("text", ""))
    print("======================")
    client.close()

if __name__ == "__main__":
    rebuild()
