--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local RebirthService = {}

function RebirthService.getRebirthCost(currentRebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.CostMultiplier ^ currentRebirths))
end

function RebirthService.rebirth(player: Player): boolean
	local data = DataService.get(player)
	if not data then return false end

	local cost = RebirthService.getRebirthCost(data.Rebirths)
	if data.Scrap < cost then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Cannot Rebirth", string.format("You need %s Scrap to rebirth.", CurrencyService.formatNumber(cost)), Color3.fromRGB(255, 70, 70))
		return false
	end

	-- 1. Reset volatile currencies & cargo
	data.Scrap = 0
	data.Backpack = 0

	-- 2. Reset standard upgrades to Level 1
	data.Upgrades = {
		ScrapPower = 1,
		ScrapSpeed = 1,
		BackpackCapacity = 1,
	}

	-- 3. Reset zones back to Zone 1
	data.CurrentZone = 1
	data.MaxZoneReached = 1

	-- 4. Award permanent Rebirth tier & Prestige Gears
	local gearsEarned = Config.Rebirth.GearsRewardFormula(data.Rebirths)
	data.Rebirths = data.Rebirths + 1
	data.Gears = data.Gears + gearsEarned

	-- 5. Teleport player back to spawn
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local spawn = Workspace:FindFirstChild("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			character.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 3.5, 0)
		else
			character.HumanoidRootPart.CFrame = CFrame.new(0, 3.5, 15)
		end
	end

	-- 6. Shrink physical backpack back to Level 1 starter size
	pcall(function()
		local BackpackService = require(script.Parent.BackpackService)
		BackpackService.updateCharacterBackpack(player)
	end)

	-- 7. Sync and notify
	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)

	local notif = Remotes.getEvent("ShowNotification")
	notif:FireClient(player, "PRESTIGE REBIRTH!", string.format("Rebirth %d reached! +%d Gears awarded! Upgrades & Zones reset for your new run.", data.Rebirths, gearsEarned), Color3.fromRGB(255, 215, 0))

	return true
end

function RebirthService.init()
	local rebirthEvent = Remotes.getEvent("RequestRebirth")
	rebirthEvent.OnServerEvent:Connect(function(player)
		RebirthService.rebirth(player)
	end)

	print("[RebirthService] Initialized.")
end

return RebirthService
