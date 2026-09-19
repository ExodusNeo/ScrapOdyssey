--!strict
local Players = game:GetService("Players")
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

	-- Reset scrap, increment rebirth, award gears
	local gearsEarned = Config.Rebirth.GearsRewardFormula(data.Rebirths)
	data.Scrap = 0
	data.Rebirths = data.Rebirths + 1
	data.Gears = data.Gears + gearsEarned

	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)

	local notif = Remotes.getEvent("ShowNotification")
	notif:FireClient(player, "REBIRTH ACHIEVED!", string.format("You reached Rebirth %d! +%d Gears awarded!", data.Rebirths, gearsEarned), Color3.fromRGB(255, 215, 0))

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
