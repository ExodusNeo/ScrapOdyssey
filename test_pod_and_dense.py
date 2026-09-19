import time
import json
from studio_client import StudioClient

def run_test():
    client = StudioClient()
    print("Connected Studio ID:", client.studio_id)

    print("1. Starting Play Solo...")
    start_res = client.call_tool("start_stop_play", {"is_start": True})
    print("Start result:", start_res)

    # Allow client and server to boot
    time.sleep(7)

    # Run in-game tests via execute_luau in Server datamodel
    test_script = """
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ServerScriptService = game:GetService("ServerScriptService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Config = require(ReplicatedStorage.Modules.Config)

    local player = Players:GetPlayers()[1]
    if not player then
        return "ERROR: No player found"
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then
        return "ERROR: HumanoidRootPart not found"
    end

    local DebugService = require(ServerScriptService.Systems.DebugService)
    local EventService = require(ServerScriptService.Systems.EventService)
    local ActionService = require(ServerScriptService.Systems.ActionService)
    local DataService = require(ServerScriptService.Systems.DataService)
    local CurrencyService = require(ServerScriptService.Systems.CurrencyService)

    local data = DataService.get(player)
    local results = {}

    -- Test 1: Dense node hit test
    local denseNode = nil
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Model") and string.sub(desc.Name, 1, 10) == "ScrapPile_" then
            if desc:GetAttribute("IsDense") == true then
                denseNode = desc
                break
            end
        end
    end

    if denseNode then
        local hb = denseNode:FindFirstChild("Hitbox") or denseNode:FindFirstChild("Base")
        local hpBefore = denseNode:GetAttribute("CurrentHP") or denseNode:GetAttribute("MaxHP")
        local scrapBefore = data.Backpack or 0
        if hb then
            root.CFrame = CFrame.new(hb.Position + Vector3.new(0, 3, 5))
            task.wait(0.2)
            ActionService.performScrapAction(player, denseNode)
            local hpAfter = denseNode:GetAttribute("CurrentHP")
            local scrapAfter = data.Backpack or 0
            results.DenseTest = {
                Found = true,
                DamageRegistered = (hpAfter < hpBefore),
                ScrapEarned = (scrapAfter > scrapBefore),
                HPChange = string.format("%d -> %d", hpBefore, hpAfter)
            }
        end
    else
        results.DenseTest = { Found = false, Note = "No dense node currently active, normal roll" }
    end

    -- Test 2: Trigger Orbital Drop Pod in Zone 1 (Rusty Outpost)
    DebugService.handleAction(player, "SpawnMeteor", 1)
    task.wait(2.5) -- wait for 2.0s descent animation to touchdown

    local pod = EventService.getActivePod()
    if not pod then
        results.PodFound = false
        return game:GetService("HttpService"):JSONEncode(results)
    end

    local hitbox = pod:FindFirstChild("Hitbox")
    local landingPos = hitbox and hitbox.Position or Vector3.zero
    results.PodFound = true
    results.PodLandingPos = string.format("%.1f, %.1f, %.1f", landingPos.X, landingPos.Y, landingPos.Z)

    -- Move player right next to the pod
    root.CFrame = CFrame.new(landingPos + Vector3.new(3, 0, 3))
    task.wait(0.3)

    -- Test 3: Hit the pod repeatedly until broken or verified
    local hits = 0
    local maxHP = pod:GetAttribute("MaxHP") or 180
    local hpTrack = {}
    local gearsBefore = data.Gears or 0

    -- Unlock tool with damage so multiple hits register cleanly
    data.EquippedTool = "VoidRipper"
    data.OwnedTools = data.OwnedTools or {}
    data.OwnedTools["VoidRipper"] = true
    ActionService.giveScrapperTool(player)
    task.wait(0.2)

    while hits < 15 and pod and pod.Parent and (pod:GetAttribute("CurrentHP") or 0) > 0 do
        ActionService.performScrapAction(player, pod)
        hits = hits + 1
        local cur = pod:GetAttribute("CurrentHP") or 0
        table.insert(hpTrack, cur)
        task.wait(0.4)
    end

    local gearsAfter = data.Gears or 0
    results.PodCombat = {
        Hits = hits,
        MaxHP = maxHP,
        HPTrack = hpTrack,
        FinalHP = (pod and pod.Parent) and pod:GetAttribute("CurrentHP") or 0,
        PodDestroyed = (not pod or not pod.Parent or pod:GetAttribute("CurrentHP") == 0),
        GearsGained = (gearsAfter - gearsBefore)
    }

    return game:GetService("HttpService"):JSONEncode(results)
    """

    res = client.execute_luau(test_script, datamodel_type="Server")
    print("Test Execution Result:")
    text_res = res.get("result", {}).get("content", [{}])[0].get("text", "")
    print(text_res)

    print("\nConsole Output (last 2000 chars):")
    console_res = client.call_tool("get_console_output", {})
    console_text = console_res.get("result", {}).get("content", [{}])[0].get("text", "")
    print(console_text[-2000:])

    print("Stopping Play Solo...")
    client.call_tool("start_stop_play", {"is_start": False})
    client.close()

if __name__ == "__main__":
    run_test()
