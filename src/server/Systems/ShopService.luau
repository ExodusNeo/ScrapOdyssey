--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local ShopService = {}

function ShopService.getUpgradeCost(upgradeKey: string, currentLevel: number): number
	local conf = Config.Upgrades[upgradeKey]
	if not conf then return math.huge end
	return math.floor(conf.BaseCost * (conf.CostMultiplier ^ (currentLevel - 1)))
end

function ShopService.purchaseUpgrade(player: Player, upgradeKey: string): boolean
	local data = DataService.get(player)
	if not data then return false end

	local conf = Config.Upgrades[upgradeKey]
	if not conf then return false end

	local currentLevel = data.Upgrades[upgradeKey] or 1
	if currentLevel >= conf.MaxLevel then
		return false -- Already maxed
	end

	local cost = ShopService.getUpgradeCost(upgradeKey, currentLevel)
	if CurrencyService.removeScrap(player, cost) then
		data.Upgrades[upgradeKey] = currentLevel + 1
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Upgrade Purchased!", string.format("%s reached Level %d!", conf.Name, currentLevel + 1), Color3.fromRGB(80, 220, 120))
		return true
	end

	return false
end

function ShopService.init()
	local purchaseEvent = Remotes.getEvent("PurchaseUpgrade")
	purchaseEvent.OnServerEvent:Connect(function(player, upgradeKey)
		if type(upgradeKey) == "string" then
			ShopService.purchaseUpgrade(player, upgradeKey)
		end
	end)

	print("[ShopService] Initialized.")
end

return ShopService
