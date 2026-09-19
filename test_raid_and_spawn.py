import time
import json
from studio_client import StudioClient

def run_test():
    client = StudioClient()
    print("Connected Studio ID:", client.studio_id)

    print("1. Starting Play Solo...")
    start_res = client.call_tool("start_stop_play", {"is_start": True})
    print("Start result:", start_res)

    time.sleep(7)

    test_script = """
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ServerScriptService = game:GetService("ServerScriptService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Config = require(ReplicatedStorage.Modules.Config)

    local player = Players:GetPlayers()[1]
    if not player then return "ERROR: No player found" end

    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then return "ERROR: No root part" end

    local DebugService = require(ServerScriptService.Systems.DebugService)
    local EventService = require(ServerScriptService.Systems.EventService)
    local ActionService = require(ServerScriptService.Systems.ActionService)
    local DataService = require(ServerScriptService.Systems.DataService)
    local CurrencyService = require(ServerScriptService.Systems.CurrencyService)

    local data = DataService.get(player)
    local results = {}

    -- 1. Trigger Drop Pod anywhere on the expanded map
    local pod = EventService.triggerDropPod()
    task.wait(2.5) -- wait for 2.0s descent animation to land

    if not pod or not pod.Parent then
        results.SpawnSuccess = false
        return game:GetService("HttpService"):JSONEncode(results)
    end

    local hitbox = pod:FindFirstChild("Hitbox")
    local landingPos = hitbox and hitbox.Position or Vector3.zero
    results.SpawnSuccess = true
    results.LandingPos = string.format("%.1f, %.1f, %.1f", landingPos.X, landingPos.Y, landingPos.Z)
    results.LocationName = pod:GetAttribute("LocationName")
    results.MaxHP = pod:GetAttribute("MaxHP")
    results.HasSkyBeacon = pod:FindFirstChild("SkyBeacon") ~= nil

    -- 2. Check distance to all interactables (must be >= 22 studs)
    local minObservedDistance = 9999
    local closestInteractable = "None"
    for _, desc in ipairs(Workspace:GetDescendants()) do
        local p: Vector3? = nil
        if desc:IsA("ProximityPrompt") and desc.Name ~= "ScrapPrompt" then
            local parentPart = desc.Parent
            if parentPart and parentPart:IsA("BasePart") then p = parentPart.Position end
        elseif desc:IsA("SpawnLocation") then
            p = desc.Position
        elseif desc.Name == "SellPad" or desc.Name == "PortalPad" or desc.Name == "ForgeTable" then
            if desc:IsA("BasePart") then p = desc.Position end
        elseif desc:IsA("Model") and string.sub(desc.Name, 1, 10) == "ScrapPile_" and not desc:GetAttribute("IsOrbitalPod") then
            local hb = desc:FindFirstChild("Hitbox") or desc:FindFirstChild("Base")
            if hb and hb:IsA("BasePart") then p = hb.Position end
        end

        if p then
            local dist = (Vector3.new(landingPos.X, 0, landingPos.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude
            if dist < minObservedDistance then
                minObservedDistance = dist
                closestInteractable = desc:GetFullName()
            end
        end
    end
    results.MinInteractableDistance = math.floor(minObservedDistance * 10) / 10
    results.ClosestInteractable = closestInteractable
    results.IsSafeFromInteractables = (minObservedDistance >= 22)

    -- 3. Teleport player to pod and test partial hits (no loot drops on hit)
    root.CFrame = CFrame.new(landingPos + Vector3.new(3, 0, 3))
    task.wait(0.3)

    data.EquippedTool = "VoidRipper"
    data.OwnedTools = data.OwnedTools or {}
    data.OwnedTools["VoidRipper"] = true
    ActionService.giveScrapperTool(player)
    task.wait(0.2)

    local initialBackpack = data.Backpack or 0
    local initialScrap = data.Scrap or 0
    local initialGears = data.Gears or 0

    -- Perform 3 test hits
    local hpBefore = pod:GetAttribute("CurrentHP")
    for i = 1, 3 do
        ActionService.performScrapAction(player, pod)
        task.wait(0.35)
    end
    local hpAfterHits = pod:GetAttribute("CurrentHP")
    local backpackAfterHits = data.Backpack or 0

    results.PartialHitTest = {
        HPReduced = (hpAfterHits < hpBefore),
        DamageDealt = (hpBefore - hpAfterHits),
        NoLootOnHit = (backpackAfterHits == initialBackpack),
        BackpackChange = string.format("%d -> %d", initialBackpack, backpackAfterHits)
    }

    -- 4. Test Final Defeat and Proportional Rewards Splitting
    -- Simulate finishing the pod
    pod:SetAttribute("CurrentHP", 16)
    task.wait(0.1)
    ActionService.performScrapAction(player, pod) -- Final kill strike!
    task.wait(0.5)

    local finalScrap = data.Scrap or 0
    local finalGears = data.Gears or 0

    results.RewardSplitTest = {
        PodDestroyed = (not pod or not pod.Parent or pod:GetAttribute("CurrentHP") == 0),
        ScrapEarned = (finalScrap - initialScrap),
        GearsEarned = (finalGears - initialGears),
        ActivePodCleaned = (EventService.getActivePod() == nil)
    }

    return game:GetService("HttpService"):JSONEncode(results)
    """

    res = client.execute_luau(test_script, datamodel_type="Server")
    print("\n=== TEST EXECUTION RESULT ===")
    text_res = res.get("result", {}).get("content", [{}])[0].get("text", "")
    print(text_res)
    print("=============================")

    print("\nStopping Play Solo...")
    client.call_tool("start_stop_play", {"is_start": False})
    client.close()

if __name__ == "__main__":
    run_test()
