from studio_client import StudioClient
import json

def test_all():
    client = StudioClient()
    print("Running integration tests in Studio Edit Datamodel...")

    code = """
    local SSS = game:GetService("ServerScriptService")
    local RS = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")

    local psClone = SSS.Systems.PetService:Clone()
    psClone.Parent = SSS.Systems
    local PetService = require(psClone)
    psClone:Destroy()

    local zsClone = SSS.Systems.ZoneService:Clone()
    zsClone.Parent = SSS.Systems
    local ZoneService = require(zsClone)
    zsClone:Destroy()
    local Config = require(RS.Modules.Config)

    local results = {}

    -- TEST 1: Drone lockstep position & nametag
    local rustTemplate = Config.Pets.List[1]
    local droneModel = PetService.createDroneModel(rustTemplate)
    droneModel.Parent = Workspace
    local core = droneModel.PrimaryPart
    local body = droneModel:FindFirstChild("Body")
    local tag = core and core:FindFirstChild("DroneTag")

    droneModel:PivotTo(CFrame.new(75, 15, -45))
    local pCore = core.Position
    local pBody = body.Position
    local droneDist = (pCore - pBody).Magnitude
    table.insert(results, string.format("TEST 1 - Drone Alignment: Core=(%.1f, %.1f, %.1f), Body=(%.1f, %.1f, %.1f), Offset=%.2f studs, TagFound=%s",
        pCore.X, pCore.Y, pCore.Z, pBody.X, pBody.Y, pBody.Z, droneDist, tostring(tag ~= nil)))
    droneModel:Destroy()

    -- TEST 2: Zone 2 Gate Barrier & Collisions
    local bridgesFolder = Workspace:FindFirstChild("Bridges")
    local gate2 = bridgesFolder and bridgesFolder:FindFirstChild("Gate_Zone2")
    local barrier = gate2 and gate2:FindFirstChild("Forcefield")
    local prompt = gate2 and gate2:FindFirstChildWhichIsA("ProximityPrompt", true)

    table.insert(results, string.format("TEST 2 - Gate 2 Initial State: GateFound=%s, BarrierFound=%s, CanCollide=%s, Transparency=%.2f, PromptFound=%s",
        tostring(gate2 ~= nil),
        tostring(barrier ~= nil),
        barrier and tostring(barrier.CanCollide) or "nil",
        barrier and barrier.Transparency or -1,
        tostring(prompt ~= nil)))

    -- TEST 3: Recyclers in every zone
    local recyclers = {}
    for i = 1, 5 do
        local f = (i == 1 and Workspace:FindFirstChild("CentralHub")) or Workspace:FindFirstChild("Zone_" .. i)
        local r = f and (f:FindFirstChild("ScrapRecycler_Zone" .. i) or f:FindFirstChild("ScrapRecycler"))
        local pad = r and r:FindFirstChild("RecyclerDepositPad")
        local pPrompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt")
        table.insert(recyclers, string.format("Z%d: Recycler=%s, Pad=%s, Prompt=%s",
            i, tostring(r ~= nil), tostring(pad ~= nil), tostring(pPrompt ~= nil)))
    end
    table.insert(results, "TEST 3 - Recyclers at all zones:\\n  " .. table.concat(recyclers, "\\n  "))

    -- TEST 4: Portal pad clearance on Zone 2
    local z2 = Workspace:FindFirstChild("Zone_2")
    local portal = z2 and z2:FindFirstChild("PortalPad_Zone2")
    local node3 = z2 and z2:FindFirstChild("ScrapPile_2_3")
    local root3 = node3 and (node3:FindFirstChild("Root") or node3:FindFirstChild("Core") or (node3:IsA("BasePart") and node3))
    local portalDist = (portal and root3) and (portal.Position - root3.Position).Magnitude or -1
    table.insert(results, string.format("TEST 4 - Portal Pad Clearance from Scrap Node 3: %.1f studs (Safe clearance >20 studs)", portalDist))

    return table.concat(results, "\\n")
    """

    res = client.execute_luau(code)
    print("=== INTEGRATION VERIFICATION RESULTS ===")
    content = res.get("result", {}).get("content", [{}])[0].get("text", "")
    print(content)
    print("========================================")
    client.close()

if __name__ == "__main__":
    test_all()
