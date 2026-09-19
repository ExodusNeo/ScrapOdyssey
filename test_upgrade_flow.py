from studio_client import StudioClient
import time
import json

client = StudioClient()
print("Connected Studio ID:", client.studio_id)

print("Starting Play Solo...")
client.call_tool("start_stop_play", {"is_start": True})
time.sleep(5)

# Award some scrap and purchase upgrade
test_script = """
local player = game.Players:GetPlayers()[1]
if not player then return "No player" end

local CurrencyService = require(game.ServerScriptService.Systems.CurrencyService)
local ShopService = require(game.ServerScriptService.Systems.ShopService)
local DataService = require(game.ServerScriptService.Systems.DataService)

-- Give scrap for testing
CurrencyService.addScrap(player, 1000, false)

-- Purchase ScrapPower upgrade
local success = ShopService.purchaseUpgrade(player, "ScrapPower")
local data = DataService.get(player)

return game:GetService("HttpService"):JSONEncode({
    PurchaseSuccess = success,
    NewLevel = data.Upgrades["ScrapPower"],
    RemainingScrap = data.Scrap
})
"""

res = client.execute_luau(test_script, datamodel_type="Server")
print("Upgrade purchase test result:", res.get("result", {}).get("content", [{}])[0].get("text", ""))

time.sleep(2)
client.call_tool("start_stop_play", {"is_start": False})
client.close()
