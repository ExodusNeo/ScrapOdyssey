--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local DebugService = {}

local function isAuthorized(player: Player): boolean
	if RunService:IsStudio() then return true end
	if player.Name == "ExodusNeo" then return true end
	if player.UserId == game.CreatorId then return true end
	return false
end

function DebugService.handleAction(player: Player, action: string, arg: any?)
	if not isAuthorized(player) then
		warn(string.format("[DebugService] Unauthorized debug attempt from %s (UserId: %d)", player.Name, player.UserId))
		return
	end

	local data = DataService.get(player)
	if not data then return end

	local notif = Remotes.getEvent("ShowNotification")

	if action == "AddScrap" then
		local amount = type(arg) == "number" and arg or 100000
		CurrencyService.addScrap(player, amount, false)
		notif:FireClient(player, "DEBUG: Scrap Added", string.format("+%d Scrap added!", amount), Color3.fromRGB(255, 215, 0))

	elseif action == "AddGears" then
		local amount = type(arg) == "number" and arg or 25
		CurrencyService.addGears(player, amount)
		notif:FireClient(player, "DEBUG: Gears Added", string.format("+%d Gears added!", amount), Color3.fromRGB(70, 180, 255))

	elseif action == "UnlockAllZones" then
		data.MaxZoneReached = 5
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: Zones Unlocked", "All 5 Zones (1 to 5) unlocked! Fast travel is now fully open.", Color3.fromRGB(80, 220, 120))

	elseif action == "MaxUpgrades" then
		data.Upgrades = data.Upgrades or {}
		for key, conf in pairs(Config.Upgrades) do
			data.Upgrades[key] = conf.MaxLevel
		end
		DataService.sync(player)
		CurrencyService.updateLeaderstats(player)
		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.createBackpack(player)
		end)
		notif:FireClient(player, "DEBUG: Upgrades Maxed", "Scrapper Power, Speed, and Magnetic Cargo are now MAX level!", Color3.fromRGB(40, 210, 90))

	elseif action == "UnlockAllPerks" then
		data.GearsPerks = data.GearsPerks or {}
		for perkId, _ in pairs(Config.GearsShop) do
			data.GearsPerks[perkId] = true
		end
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: Perks Active", "All Gears Prestige Shop Perks unlocked and active!", Color3.fromRGB(255, 170, 0))

	elseif action == "UnlockAllTools" then
		data.OwnedTools = data.OwnedTools or {}
		for _, t in ipairs(Config.Tools) do
			data.OwnedTools[t.Id] = true
		end
		data.EquippedTool = "VoidRipper"
		DataService.sync(player)
		local ActionService = require(script.Parent.ActionService)
		ActionService.giveScrapperTool(player)
		notif:FireClient(player, "DEBUG: All Tools Unlocked", "Unlocked all 5 tools & equipped Tier 5 Void Singularity Ripper!", Color3.fromRGB(175, 60, 255))

	elseif action == "GiveAllPets" then
		data.Pets = data.Pets or {}
		for _, template in ipairs(Config.Pets.List) do
			table.insert(data.Pets, {
				UUID = HttpService:GenerateGUID(false),
				Id = template.Id,
				Level = 1,
				Equipped = false,
			})
		end
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: All Drones Added", "Added 1 of every Drone companion to your hangar!", Color3.fromRGB(180, 70, 255))

	elseif action == "AddRebirth" then
		local count = type(arg) == "number" and arg or 1
		data.Rebirths = (data.Rebirths or 0) + count
		local gearsEarned = count * 5
		data.Gears = (data.Gears or 0) + gearsEarned
		CurrencyService.updateLeaderstats(player)
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: Rebirths Added", string.format("+%d Rebirths and +%d Gears awarded!", count, gearsEarned), Color3.fromRGB(90, 140, 255))

	elseif action == "ClearCargo" then
		data.Backpack = 0
		CurrencyService.updateLeaderstats(player)
		DataService.sync(player)
		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCoreColor(player)
		end)
		notif:FireClient(player, "DEBUG: Cargo Cleared", "Backpack emptied.", Color3.fromRGB(200, 200, 200))

	elseif action == "ClearStats" then
		data.Scrap = 0
		data.Backpack = 0
		data.Gears = 0
		data.Rebirths = 0
		CurrencyService.updateLeaderstats(player)
		DataService.sync(player)
		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCoreColor(player)
		end)
		notif:FireClient(player, "DEBUG: Stats Cleared", "Scrap, Gears, Cargo, and Rebirths reset to 0!", Color3.fromRGB(255, 120, 50))

	elseif action == "ResetSave" then
		data.Scrap = 0
		data.Backpack = 0
		data.Gears = 0
		data.Rebirths = 0
		data.CurrentZone = 1
		data.MaxZoneReached = 1
		data.Upgrades = { ScrapPower = 1, ScrapSpeed = 1, BackpackCapacity = 1 }
		data.GearsPerks = {}
		data.Pets = {}
		data.OwnedTools = { ["OmniWrench"] = true }
		data.EquippedTool = "OmniWrench"
		CurrencyService.updateLeaderstats(player)
		DataService.sync(player)
		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.createBackpack(player)
		end)
		local ActionService = require(script.Parent.ActionService)
		ActionService.giveScrapperTool(player)
		notif:FireClient(player, "DEBUG: Profile Reset", "Data reset to fresh defaults.", Color3.fromRGB(255, 70, 70))
	end
end

function DebugService.init()
	local debugEvent = Remotes.getEvent("DebugAction")
	debugEvent.OnServerEvent:Connect(function(player, action, arg)
		if type(action) == "string" then
			DebugService.handleAction(player, action, arg)
		end
	end)

	print("[DebugService] Initialized with Developer Admin Console.")
end

return DebugService
