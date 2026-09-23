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
			BackpackService.updateCharacterBackpack(player)
		end)
		notif:FireClient(player, "DEBUG: Upgrades Maxed", "Scrapper Power, Speed, and Magnetic Cargo are now MAX level!", Color3.fromRGB(40, 210, 90))

	elseif action == "UnlockAllPerks" then
		data.GearsPerks = data.GearsPerks or {}
		for perkId, _ in pairs(Config.GearsShop) do
			data.GearsPerks[perkId] = true
		end
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: Perks Active", "All Gears Prestige Shop Perks unlocked and active!", Color3.fromRGB(255, 170, 0))

	elseif action == "ToggleSuperSprint" then
		data.HasSuperSprintPass = not (data.HasSuperSprintPass == true)
		DataService.sync(player)
		local statusText = data.HasSuperSprintPass and "ENABLED (+8 Sprint, +4 Walk)" or "DISABLED"
		local statusColor = data.HasSuperSprintPass and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(200, 200, 200)
		notif:FireClient(player, "DEBUG: Super Sprint", "Hyper Thrusters Gamepass: " .. statusText, statusColor)

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

	elseif action == "SpawnMeteor" then
		local EventService = require(script.Parent.EventService)
		local targetZone: number? = nil

		if type(arg) == "number" then
			targetZone = math.clamp(math.floor(arg), 1, 5)
		elseif arg == "Current" or arg == "Here" then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				targetZone = math.clamp(math.floor((root.Position.X + 80) / 160) + 1, 1, 5)
			elseif data.CurrentZone then
				targetZone = math.clamp(data.CurrentZone, 1, 5)
			else
				targetZone = 1
			end
		end

		local pod = EventService.triggerDropPod(nil, targetZone, true)
		if pod then
			local locName = pod:GetAttribute("LocationName")
			local msg = locName and string.format("Summoned an Orbital Raid Pod into %s!", locName)
				or (targetZone and string.format("Summoned an Orbital Raid Pod into Zone %d!", targetZone) or "Summoned an Orbital Raid Pod into the wasteland!")
			notif:FireClient(player, "DEBUG: Pod Incoming", msg, Color3.fromRGB(255, 140, 20))
		end

	elseif action == "ClearCargo" then
		data.Backpack = 0
		CurrencyService.updateLeaderstats(player)
		DataService.sync(player)
		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCoreColor(player)
		end)
		notif:FireClient(player, "DEBUG: Cargo Cleared", "Backpack emptied.", Color3.fromRGB(200, 200, 200))

	elseif action == "ResetDailyReward" then
		data.LastDailyRewardClaim = 0
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: Daily Reward Ready", "Daily reward cooldown reset to 0! You can claim immediately.", Color3.fromRGB(255, 200, 50))

	elseif action == "ResetDailyQuests" then
		data.LastDailyQuestReset = os.time()
		data.Quests = {}
		for _, q in ipairs(Config.Quests) do
			data.Quests[q.Id] = { Progress = 0, Completed = false, Claimed = false }
		end
		DataService.sync(player)
		notif:FireClient(player, "DEBUG: Quests Reset", "Daily objectives have been reset to 0% progress!", Color3.fromRGB(80, 220, 120))

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
		data.EquippedPetCount = 0
		data.InventoryCount = 0
		data.TotalScrapsMined = 0
		data.OwnedTools = { ["OmniWrench"] = true }
		data.EquippedTool = "OmniWrench"

		data.Quests = {}
		if Config.Quests then
			for _, q in ipairs(Config.Quests) do
				data.Quests[q.Id] = { Progress = 0, Completed = false, Claimed = false }
			end
		end

		CurrencyService.updateLeaderstats(player)
		DataService.sync(player)

		-- Despawn any active 3D drones from Workspace
		pcall(function()
			local PetService = require(script.Parent.PetService)
			PetService.updateVisualDrones(player)
		end)

		-- Reset backpack visual model to Tier 1
		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCharacterBackpack(player)
		end)

		-- Reset equipped scrapper tool to default Omni-Wrench
		local ActionService = require(script.Parent.ActionService)
		ActionService.giveScrapperTool(player)

		-- Reset character position back to Central Hub spawn
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = CFrame.new(0, 3.5, 0)
			end
		end

		-- Persist wipe to DataStore
		DataService.saveData(player)

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

	-- ServerDebugInvoker BindableFunction for server-side automation & testing
	local serverInvoker = ReplicatedStorage:FindFirstChild("ServerDebugInvoker") :: BindableFunction?
	if not serverInvoker then
		serverInvoker = Instance.new("BindableFunction")
		serverInvoker.Name = "ServerDebugInvoker"
		serverInvoker.Parent = ReplicatedStorage
	end
	serverInvoker.OnInvoke = function(action: string, player: Player?, arg: any?)
		if action == "HandleAction" and player and type(arg) == "string" then
			DebugService.handleAction(player, arg)
			return true
		elseif action == "UnlockZone" and player and type(arg) == "number" then
			local ZoneService = require(script.Parent.ZoneService)
			return ZoneService.unlockZone(player, arg)
		elseif action == "HatchEgg" and player and type(arg) == "string" then
			local PetService = require(script.Parent.PetService)
			return PetService.hatchEgg(player, arg)
		elseif action == "GetData" and player then
			return DataService.get(player)
		elseif action == "SetScrap" and player and type(arg) == "number" then
			local data = DataService.get(player)
			if data then data.Scrap = arg end
			return true
		end
		return nil
	end

	print("[DebugService] Initialized with Developer Admin Console.")
end

return DebugService
