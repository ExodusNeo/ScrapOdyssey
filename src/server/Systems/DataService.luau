--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)

local DATA_VERSION = 1
local DATASTORE_NAME = "ScrapOdyssey_PlayerData_v" .. tostring(DATA_VERSION)

local DataService = {}
local sessionData: { [number]: Types.PlayerData } = {}
local pendingSyncs: { [Player]: boolean } = {}
local dataStore = nil

-- Attempt to connect to DataStoreService safely
local isDataStoreAvailable = false
if not RunService:IsStudio() then
	local success, ds = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if success and ds then
		dataStore = ds
		isDataStoreAvailable = true
	end
else
	-- In Studio, test if API services are enabled
	local success, ds = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if success and ds then
		local testSuccess = pcall(function()
			ds:GetAsync("__StudioTestKey__")
		end)
		if testSuccess then
			dataStore = ds
			isDataStoreAvailable = true
			print("[DataService] Connected to live DataStoreService in Studio.")
		else
			print("[DataService] Studio API access is disabled. Running in Mock DataStore mode.")
		end
	end
end

local function getDefaultData(): Types.PlayerData
	local initialQuests: { [string]: Types.QuestProgress } = {}
	if Config.Quests then
		for _, q in ipairs(Config.Quests) do
			initialQuests[q.Id] = { Progress = 0, Completed = false, Claimed = false }
		end
	end

	return {
		Version = DATA_VERSION,
		Scrap = Config.Defaults.Scrap,
		Backpack = 0,
		Gears = Config.Defaults.Gears,
		Rebirths = Config.Defaults.Rebirths,
		CurrentZone = Config.Defaults.CurrentZone,
		MaxZoneReached = Config.Defaults.MaxZoneReached,
		Upgrades = {
			ScrapPower = 1,
			ScrapSpeed = 1,
			BackpackCapacity = 1,
		},
		GearsPerks = {},
		Pets = {},
		EquippedPetCount = 0,
		InventoryCount = 0,
		DailyLoginStreak = 1,
		LastLoginTimestamp = os.time(),
		LastDailyRewardClaim = 0,
		LastDailyQuestReset = os.time(),
		RedeemedCodes = {},
		TotalScrapsMined = 0,
		Quests = initialQuests,
		EquippedTool = "OmniWrench",
		OwnedTools = { ["OmniWrench"] = true },
		HasCompletedTutorial = false,
	}
end

function DataService.loadData(player: Player): Types.PlayerData
	if sessionData[player.UserId] then
		return sessionData[player.UserId]
	end

	local data: Types.PlayerData? = nil
	if isDataStoreAvailable and dataStore then
		local key = "Player_" .. tostring(player.UserId)
		local success, savedData = pcall(function()
			return dataStore:GetAsync(key)
		end)

		if success and savedData and type(savedData) == "table" then
			data = savedData
			print(string.format("[DataService] Successfully loaded save for %s", player.Name))
		end
	end

	if not data then
		data = getDefaultData()
		print(string.format("[DataService] Created fresh profile for %s", player.Name))
	else
		-- Reconcile missing fields on legacy saves
		if data.Backpack == nil then data.Backpack = 0 end
		if not data.Upgrades then data.Upgrades = {} end
		if not data.Upgrades.BackpackCapacity then data.Upgrades.BackpackCapacity = 1 end
		if not data.Upgrades.ScrapPower then data.Upgrades.ScrapPower = 1 end
		if not data.Upgrades.ScrapSpeed then data.Upgrades.ScrapSpeed = 1 end
		if not data.Quests then data.Quests = {} end
		if Config.Quests then
			for _, q in ipairs(Config.Quests) do
				if not data.Quests[q.Id] then
					data.Quests[q.Id] = { Progress = 0, Completed = false, Claimed = false }
				end
			end
		end
		if not data.OwnedTools then
			data.OwnedTools = { ["OmniWrench"] = true }
		end
		if not data.EquippedTool or not data.OwnedTools[data.EquippedTool] then
			data.EquippedTool = "OmniWrench"
		end
		if data.HasCompletedTutorial == nil then
			data.HasCompletedTutorial = false
		end
		if data.DailyLoginStreak == nil then
			data.DailyLoginStreak = 1
		end
		if data.LastDailyRewardClaim == nil then
			data.LastDailyRewardClaim = 0
		end
		if data.LastDailyQuestReset == nil then
			data.LastDailyQuestReset = 0
		end
		-- Clean up legacy lowercase or obsolete quest keys from older builds
		if data.Quests then
			data.Quests["scrap_50"] = nil
			data.Quests["earn_10k"] = nil
			data.Quests["hatch_2"] = nil
		end
	end

	sessionData[player.UserId] = data
	DataService.sync(player)

	-- Immediately spawn equipped drones & character backpack upon data load
	task.defer(function()
		if not player.Parent then return end
		local petModule = script.Parent:FindFirstChild("PetService")
		if petModule then
			local success, petService = pcall(require, petModule)
			if success and type(petService) == "table" and type(petService.updateVisualDrones) == "function" then
				petService.updateVisualDrones(player)
			end
		end
		local bpModule = script.Parent:FindFirstChild("BackpackService")
		if bpModule then
			local success, bpService = pcall(require, bpModule)
			if success and type(bpService) == "table" and type(bpService.updateCharacterBackpack) == "function" then
				bpService.updateCharacterBackpack(player)
			end
		end
	end)

	return data
end

function DataService.get(player: Player): Types.PlayerData?
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
	local data = sessionData[player.UserId]
	if not data then
		data = DataService.loadData(player)
	end
	return data
end

function DataService.sync(player: Player)
	if pendingSyncs[player] then return end
	pendingSyncs[player] = true
	task.defer(function()
		pendingSyncs[player] = nil
		if not player.Parent then return end
		local data = sessionData[player.UserId]
		if data then
			local syncEvent = Remotes.getEvent("SyncData")
			syncEvent:FireClient(player, data)
		end
	end)
end

function DataService.saveData(player: Player): boolean
	local data = sessionData[player.UserId]
	if not data then return false end

	if isDataStoreAvailable and dataStore then
		local key = "Player_" .. tostring(player.UserId)
		local success, err = pcall(function()
			dataStore:UpdateAsync(key, function(oldData)
				return data
			end)
		end)

		if success then
			print(string.format("[DataService] Saved data for %s", player.Name))
			return true
		else
			warn(string.format("[DataService] Failed to save for %s: %s", player.Name, tostring(err)))
			return false
		end
	end
	return true
end

function DataService.init()
	Players.PlayerAdded:Connect(function(player)
		DataService.loadData(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingSyncs[player] = nil
		DataService.saveData(player)
		sessionData[player.UserId] = nil
	end)

	game:BindToClose(function()
		local runningSaves = 0
		for _, player in ipairs(Players:GetPlayers()) do
			runningSaves += 1
			task.spawn(function()
				DataService.saveData(player)
				runningSaves -= 1
			end)
		end
		-- Wait for parallel saves to finish up to 10 seconds
		local startWait = os.clock()
		while runningSaves > 0 and (os.clock() - startWait) < 10 do
			task.wait(0.2)
		end
	end)

	-- Handle existing players in case of hot reload
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.loadData, player)
	end

	-- Staggered Auto-save loop every 120 seconds (prevents DataStore rate limit bursts)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				if player and player.Parent then
					DataService.saveData(player)
					task.wait(1.5) -- Stagger saves across frames
				end
			end
		end
	end)

	local getFunction = Remotes.getFunction("GetPlayerData")
	getFunction.OnServerInvoke = function(player)
		return (player and sessionData[player.UserId]) or getDefaultData()
	end

	local completeTutorialEvent = Remotes.getEvent("CompleteTutorial")
	completeTutorialEvent.OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if data and not data.HasCompletedTutorial then
			data.HasCompletedTutorial = true
			local CurrencyService = require(script.Parent.CurrencyService)
			CurrencyService.addScrap(player, 50, false)
			DataService.sync(player)

			local notif = Remotes.getEvent("ShowNotification")
			notif:FireClient(player, "TUTORIAL COMPLETED!", "Welcome aboard, Operator! +50 Starter Scrap awarded!", Color3.fromRGB(80, 220, 120))
		end
	end)

	print("[DataService] Initialized.")
end

return DataService
