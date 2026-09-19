--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local QuestService = {}

function QuestService.claimDailyReward(player: Player)
	local data = DataService.get(player)
	if not data then return end

	local now = os.time()
	local lastLogin = data.LastLoginTimestamp or 0
	local elapsed = now - lastLogin

	-- 20 hours cooldown for next day claim (or allow claim if streak == 1 on first join)
	local currentStreak = math.clamp(data.DailyLoginStreak or 1, 1, 7)
	local reward = Config.DailyRewards[currentStreak]

	if reward then
		if reward.Type == "Scrap" then
			CurrencyService.addScrap(player, reward.Amount, false)
		elseif reward.Type == "Gears" then
			CurrencyService.addGears(player, reward.Amount)
		end

		data.LastLoginTimestamp = now
		data.DailyLoginStreak = (currentStreak % 7) + 1
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Daily Reward Claimed!", string.format("Day %d: +%d %s", currentStreak, reward.Amount, reward.Type), Color3.fromRGB(255, 200, 50))
	end
end

function QuestService.redeemCode(player: Player, codeStr: string)
	local data = DataService.get(player)
	if not data then return end

	local upperCode = string.upper(codeStr)
	local codeConfig = Config.Codes[upperCode]

	local codeResultEvent = Remotes.getEvent("CodeResult")

	if not codeConfig then
		codeResultEvent:FireClient(player, false, "Invalid code.")
		return
	end

	if data.RedeemedCodes and data.RedeemedCodes[upperCode] then
		codeResultEvent:FireClient(player, false, "Code already redeemed.")
		return
	end

	data.RedeemedCodes = data.RedeemedCodes or {}
	data.RedeemedCodes[upperCode] = true

	if codeConfig.Type == "Scrap" then
		CurrencyService.addScrap(player, codeConfig.Amount, false)
	elseif codeConfig.Type == "Gears" then
		CurrencyService.addGears(player, codeConfig.Amount)
	end

	codeResultEvent:FireClient(player, true, string.format("Redeemed! +%d %s", codeConfig.Amount, codeConfig.Type))
	DataService.sync(player)
end

function QuestService.init()
	local claimEvent = Remotes.getEvent("ClaimDailyReward")
	claimEvent.OnServerEvent:Connect(function(player)
		QuestService.claimDailyReward(player)
	end)

	local redeemEvent = Remotes.getEvent("RedeemCode")
	redeemEvent.OnServerEvent:Connect(function(player, codeStr)
		if type(codeStr) == "string" then
			QuestService.redeemCode(player, codeStr)
		end
	end)

	print("[QuestService] Initialized.")
end

return QuestService
