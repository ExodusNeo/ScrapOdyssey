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

function QuestService.recordScrapPile(player: Player, count: number)
	local data = DataService.get(player)
	if not data or not data.Quests then return end

	local quest = data.Quests["scrap_50"]
	if quest and not quest.Completed then
		quest.Progress = quest.Progress + (count or 1)
		if quest.Progress >= 50 then
			quest.Progress = 50
			quest.Completed = true
			local notif = Remotes.getEvent("ShowNotification")
			notif:FireClient(player, "QUEST COMPLETED! 📜", "Completed: Scrap 50 Junk Piles! Claim your reward in the Quests menu.", Color3.fromRGB(80, 220, 120))
		end
		DataService.sync(player)
	end
end

function QuestService.recordScrapEarned(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or not data.Quests then return end

	local quest = data.Quests["earn_10k"]
	if quest and not quest.Completed then
		quest.Progress = quest.Progress + (amount or 0)
		if quest.Progress >= 10000 then
			quest.Progress = 10000
			quest.Completed = true
			local notif = Remotes.getEvent("ShowNotification")
			notif:FireClient(player, "QUEST COMPLETED! 📜", "Completed: Earn 10,000 Scrap! Claim your reward in the Quests menu.", Color3.fromRGB(80, 220, 120))
		end
		DataService.sync(player)
	end
end

function QuestService.recordDroneHatched(player: Player, count: number)
	local data = DataService.get(player)
	if not data or not data.Quests then return end

	local quest = data.Quests["hatch_2"]
	if quest and not quest.Completed then
		quest.Progress = quest.Progress + (count or 1)
		if quest.Progress >= 2 then
			quest.Progress = 2
			quest.Completed = true
			local notif = Remotes.getEvent("ShowNotification")
			notif:FireClient(player, "QUEST COMPLETED! 📜", "Completed: Hatch 2 Drones! Claim your reward in the Quests menu.", Color3.fromRGB(80, 220, 120))
		end
		DataService.sync(player)
	end
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
	notif:FireClient(player, "QUEST REWARD CLAIMED! 🎁", string.format("Received +%d %s!", questConfig.RewardAmount, questConfig.RewardType), Color3.fromRGB(255, 215, 0))
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

	print("[QuestService] Initialized with Live Daily Quests Tracking.")
end

return QuestService
