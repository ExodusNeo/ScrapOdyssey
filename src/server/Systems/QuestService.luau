--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local QuestService = {}

local DAILY_COOLDOWN = 20 * 3600 -- 20 hours cooldown between daily reward claims
local STREAK_EXPIRY = 48 * 3600  -- 48 hours to claim before streak resets to Day 1

function QuestService.claimDailyReward(player: Player)
	local data = DataService.get(player)
	if not data then return end

	local now = os.time()
	local lastClaim = data.LastDailyRewardClaim or 0
	local elapsed = (lastClaim > 0) and (now - lastClaim) or (DAILY_COOLDOWN + 1)

	-- Cooldown verification: Prevent rapid spamming
	if lastClaim > 0 and elapsed < DAILY_COOLDOWN then
		local remaining = DAILY_COOLDOWN - elapsed
		local hours = math.floor(remaining / 3600)
		local mins = math.floor((remaining % 3600) / 60)
		local secs = remaining % 60
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(
			player,
			"DAILY REWARD ON COOLDOWN",
			string.format("Already claimed! Next reward available in %02d:%02d:%02d.", hours, mins, secs),
			Color3.fromRGB(240, 90, 90)
		)
		return
	end

	-- Streak verification: Reset to Day 1 if more than 48 hours have passed
	local currentStreak = data.DailyLoginStreak or 1
	if lastClaim > 0 and elapsed > STREAK_EXPIRY then
		currentStreak = 1
	end
	currentStreak = math.clamp(currentStreak, 1, 7)

	local reward = Config.DailyRewards[currentStreak]
	if not reward then return end

	if reward.Type == "Scrap" then
		CurrencyService.addScrap(player, reward.Amount, false)
	elseif reward.Type == "Gears" then
		CurrencyService.addGears(player, reward.Amount)
	end

	data.LastDailyRewardClaim = now
	data.LastLoginTimestamp = now
	data.DailyLoginStreak = (currentStreak % 7) + 1
	DataService.sync(player)

	local notif = Remotes.getEvent("ShowNotification")
	notif:FireClient(
		player,
		"DAILY REWARD CLAIMED!",
		string.format("Day %d Reward: +%s %s! Streak: %d/7", currentStreak, CurrencyService.formatNumber(reward.Amount), reward.Type, currentStreak),
		Color3.fromRGB(255, 200, 50)
	)
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

-- Unified quest progress tracker supporting any objective in Config.Quests
function QuestService.recordProgress(player: Player, questId: string, amount: number)
	if not player or (amount or 0) <= 0 then return end
	local data = DataService.get(player)
	if not data or not data.Quests then return end

	-- Ensure quest entry exists in player data
	local quest = data.Quests[questId]
	if not quest then
		quest = { Progress = 0, Completed = false, Claimed = false }
		data.Quests[questId] = quest
	end

	if quest.Completed then return end

	-- Find quest config
	local questConfig = nil
	for _, q in ipairs(Config.Quests) do
		if q.Id == questId then
			questConfig = q
			break
		end
	end
	if not questConfig then return end

	local target = questConfig.Target or 1
	local oldProg = quest.Progress or 0
	local newProg = oldProg + amount

	if newProg >= target then
		quest.Progress = target
		quest.Completed = true
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(
			player,
			"OBJECTIVE COMPLETED",
			string.format("Completed: %s! Claim your reward in Objectives.", questConfig.Description),
			Color3.fromRGB(80, 220, 120)
		)
	else
		quest.Progress = newProg
	end

	DataService.sync(player)
end

-- Check and refresh daily quests on UTC day turnover
function QuestService.checkDailyQuestReset(player: Player)
	local data = DataService.get(player)
	if not data then return end

	local now = os.time()
	local lastReset = data.LastDailyQuestReset or 0

	if lastReset == 0 then
		data.LastDailyQuestReset = now
		return
	end

	local nowDay = math.floor(now / 86400)
	local lastResetDay = math.floor(lastReset / 86400)

	if nowDay > lastResetDay then
		data.LastDailyQuestReset = now
		data.Quests = {}
		for _, q in ipairs(Config.Quests) do
			data.Quests[q.Id] = { Progress = 0, Completed = false, Claimed = false }
		end
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "OBJECTIVES REFRESHED", "Fresh daily objectives are now available!", Color3.fromRGB(255, 215, 50))
	end
end

-- Backwards-compatible helper functions
function QuestService.recordScrapPile(player: Player, count: number)
	QuestService.recordProgress(player, "Scrap_50", count or 1)
end

function QuestService.recordScrapEarned(player: Player, amount: number)
	QuestService.recordProgress(player, "Recycle_200", amount or 0)
end

function QuestService.recordDroneHatched(player: Player, count: number)
	QuestService.recordProgress(player, "Hatch_Drones", count or 1)
end

function QuestService.claimQuest(player: Player, questId: string)
	local data = DataService.get(player)
	if not data or not data.Quests then return end

	local quest = data.Quests[questId]
	if not quest or not quest.Completed or quest.Claimed then return end

	-- Find quest config
	local questConfig = nil
	for _, q in ipairs(Config.Quests) do
		if q.Id == questId then
			questConfig = q
			break
		end
	end

	if not questConfig then return end

	quest.Claimed = true
	if questConfig.RewardType == "Scrap" then
		CurrencyService.addScrap(player, questConfig.RewardAmount, false)
	elseif questConfig.RewardType == "Gears" then
		CurrencyService.addGears(player, questConfig.RewardAmount)
	end

	DataService.sync(player)

	local notif = Remotes.getEvent("ShowNotification")
	notif:FireClient(player, "QUEST REWARD CLAIMED", string.format("Received +%s %s!", CurrencyService.formatNumber(questConfig.RewardAmount), questConfig.RewardType), Color3.fromRGB(255, 215, 0))
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

	local claimQuestEvent = Remotes.getEvent("ClaimQuest")
	claimQuestEvent.OnServerEvent:Connect(function(player, questId)
		if type(questId) == "string" then
			QuestService.claimQuest(player, questId)
		end
	end)

	-- Check daily quest resets when player joins
	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			QuestService.checkDailyQuestReset(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.delay(1, function()
			QuestService.checkDailyQuestReset(player)
		end)
	end

	-- Periodic check every 60 seconds for players active over midnight UTC
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in ipairs(Players:GetPlayers()) do
				QuestService.checkDailyQuestReset(p)
			end
		end
	end)

	print("[QuestService] Initialized with 20h Daily Reward Cooldown & Unified Objectives Tracking.")
end

return QuestService
