--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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

	local currentLevel = (data.Upgrades and data.Upgrades[upgradeKey]) or 1
	if currentLevel >= conf.MaxLevel then
		return false -- Already maxed
	end

	local cost = ShopService.getUpgradeCost(upgradeKey, currentLevel)
	if CurrencyService.removeScrap(player, cost) then
		data.Upgrades = data.Upgrades or {}
		data.Upgrades[upgradeKey] = currentLevel + 1
		DataService.sync(player)

		if upgradeKey == "BackpackCapacity" then
			local success, BackpackService = pcall(function()
				return require(script.Parent.BackpackService)
			end)
			if success and BackpackService then
				BackpackService.updateCharacterBackpack(player)
			end
		end

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Upgrade Purchased!", string.format("%s reached Level %d!", conf.Name, currentLevel + 1), Color3.fromRGB(80, 220, 120))
		return true
	end

	return false
end

-- Gears Prestige Perk Purchase
function ShopService.purchaseGearsPerk(player: Player, perkId: string): boolean
	local data = DataService.get(player)
	if not data then return false end

	local perk = Config.GearsShop and Config.GearsShop[perkId]
	if not perk then return false end

	data.GearsPerks = data.GearsPerks or {}
	if data.GearsPerks[perkId] then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Already Owned", "You already unlocked this perk!", Color3.fromRGB(255, 170, 0))
		return false
	end

	if CurrencyService.removeGears(player, perk.Cost) then
		data.GearsPerks[perkId] = true

		-- Apply immediate perk effects
		if perkId == "QuantumDrone" then
			-- Grant the exclusive drone
			local quantumPet: Types.OwnedPet = {
				UUID = HttpService:GenerateGUID(false),
				Id = "drone_titan",
				Level = 1,
				Equipped = false,
			}
			table.insert(data.Pets, quantumPet)
		end

		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "PERK UNLOCKED!", string.format("%s is now permanently active!", perk.Name), Color3.fromRGB(80, 220, 255))
		return true
	else
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Need More Gears", string.format("You need %d Gears for this perk.", perk.Cost), Color3.fromRGB(255, 70, 70))
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

	local purchasePerkEvent = Remotes.getEvent("PurchaseGearsPerk")
	purchasePerkEvent.OnServerEvent:Connect(function(player, perkId)
		if type(perkId) == "string" then
			ShopService.purchaseGearsPerk(player, perkId)
		end
	end)

	-- Apply persistent perks on character spawn
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.delay(0.5, function()
				local data = DataService.get(player)
				if data and data.GearsPerks and data.GearsPerks["SpeedDemon"] then
					local hum = character:FindFirstChild("Humanoid") :: Humanoid
					if hum then hum.WalkSpeed = 26 end
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	print("[ShopService] Initialized with Upgrades and Gears Prestige Shop.")
end

return ShopService
