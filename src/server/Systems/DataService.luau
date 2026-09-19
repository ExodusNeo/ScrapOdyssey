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
		RedeemedCodes = {},
		TotalScrapsMined = 0,
	}
end

function DataService.loadData(player: Player): Types.PlayerData
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
	end

	sessionData[player.UserId] = data
	DataService.sync(player)
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
	local data = sessionData[player.UserId]
	if data then
		local syncEvent = Remotes.getEvent("SyncData")
		syncEvent:FireClient(player, data)
	end
end

function DataService.saveData(player: Player): boolean
	local data = sessionData[player.UserId]
	if not data then return false end

	if isDataStoreAvailable and dataStore then
		local key = "Player_" .. tostring(player.UserId)
		local success, err = pcall(function()
			dataStore:SetAsync(key, data)
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
		DataService.saveData(player)
		sessionData[player.UserId] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.saveData(player)
		end
	end)

	-- Handle existing players in case of hot reload
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.loadData, player)
	end

	-- Auto-save loop every 120 seconds
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.saveData(player)
			end
		end
	end)

	local getFunction = Remotes.getFunction("GetPlayerData")
	getFunction.OnServerInvoke = function(player)
		return sessionData[player] or getDefaultData()
	end

	print("[DataService] Initialized.")
end

return DataService
