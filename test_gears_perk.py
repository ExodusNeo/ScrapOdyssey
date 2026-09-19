from studio_client import StudioClient
import time
import json

client = StudioClient()
print("Starting Play Solo for Gears Perk verification...")
client.call_tool("start_stop_play", {"is_start": True})
time.sleep(5)

test_script = """
local player = game.Players:GetPlayers()[1]
if not player then return "No player" end

local CurrencyService = require(game.ServerScriptService.Systems.CurrencyService)
local ShopService = require(game.ServerScriptService.Systems.ShopService)
local DataService = require(game.ServerScriptService.Systems.DataService)

-- Award 10 Gears for testing
CurrencyService.addGears(player, 10)

-- Purchase SpeedDemon perk (cost: 2 Gears)
local success = ShopService.purchaseGearsPerk(player, "SpeedDemon")
local data = DataService.get(player)

return game:GetService("HttpService"):JSONEncode({
    PerkPurchased = success,
    RemainingGears = data.Gears,
    HasSpeedDemon = data.GearsPerks["SpeedDemon"],
    WalkSpeed = player.Character and player.Character.Humanoid.WalkSpeed or 0
})
"""

res = client.execute_luau(test_script, datamodel_type="Server")
print("Gears perk purchase test result:", res.get("result", {}).get("content", [{}])[0].get("text", ""))

time.sleep(2)
client.call_tool("start_stop_play", {"is_start": False})
client.close()
