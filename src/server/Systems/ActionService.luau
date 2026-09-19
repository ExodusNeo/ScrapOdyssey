--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local ActionService = {}
local playerLastActionTime: { [Player]: number } = {}
local nodeBusyState: { [Model]: boolean } = {}

-- Weighted RNG roll for reward tier
function ActionService.rollRewardTier(): Types.RewardTier
	local totalWeight = 0
	for _, tier in ipairs(Config.RewardTiers) do
		totalWeight = totalWeight + tier.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, tier in ipairs(Config.RewardTiers) do
		cumulative = cumulative + tier.Weight
		if roll <= cumulative then
			return tier
		end
	end

	return Config.RewardTiers[1]
end

function ActionService.performScrapAction(player: Player, nodeModel: Model)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not rootPart then return end

	local nodeHitbox = nodeModel:FindFirstChild("Hitbox") :: BasePart
	if not nodeHitbox then return end

	-- 1. Distance Sanity Check (Max 25 studs)
	local distance = (rootPart.Position - nodeHitbox.Position).Magnitude
	if distance > 25 then
		warn(string.format("[ActionService] %s failed distance check (%.1f studs)", player.Name, distance))
		return
	end

	-- 2. Cooldown & Speed Check
	local data = DataService.get(player)
	if not data then return end

	local zoneId = nodeModel:GetAttribute("ZoneId") or 1
	local zone = Config.Zones[zoneId]
	local baseActionTime = zone and zone.ActionTime or 1.0

	local speedLvl = data.Upgrades["ScrapSpeed"] or 1
	local speedReduction = (speedLvl - 1) * Config.Upgrades.ScrapSpeed.EffectPerLevel
	local finalActionDelay = math.max(0.2, baseActionTime - speedReduction)

	local now = os.clock()
	local lastTime = playerLastActionTime[player] or 0
	if now - lastTime < (finalActionDelay * 0.85) then
		-- Trying to action faster than server allows
		return
	end
	playerLastActionTime[player] = now

	-- 3. Check node busy state
	if nodeBusyState[nodeModel] then return end
	nodeBusyState[nodeModel] = true

	-- Visual "hit" feedback on scrap pile
	local basePart = nodeModel:FindFirstChild("Base") :: BasePart
	if basePart then
		local origColor = basePart.Color
		basePart.Color = Color3.new(1, 1, 1)
		task.delay(0.12, function()
			if basePart and basePart.Parent then
				basePart.Color = origColor
			end
		end)
	end

	-- 4. Roll reward tier and award scrap
	local tier = ActionService.rollRewardTier()
	local baseYield = zone and zone.BaseYield or 10
	local earnedScrap = CurrencyService.addScrap(player, baseYield * tier.Multiplier)

	-- 5. Fire ActionCompleted to client for juice & floating numbers
	local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
	actionCompletedEvent:FireClient(player, {
		TierName = tier.Name,
		TierColor = tier.Color,
		ScrapEarned = earnedScrap,
		SoundPitch = tier.SoundPitch,
		Position = nodeHitbox.Position + Vector3.new(0, 3, 0),
	})

	-- Node brief cooldown
	task.delay(0.4, function()
		nodeBusyState[nodeModel] = false
	end)
end

function ActionService.init()
	-- Connect ProximityPrompts for all scrap piles
	local function hookPrompt(prompt: ProximityPrompt)
		prompt.Triggered:Connect(function(player)
			local model = prompt:FindFirstAncestorOfClass("Model")
			if model then
				ActionService.performScrapAction(player, model)
			end
		end)
	end

	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") and descendant.Name == "ScrapPrompt" then
			hookPrompt(descendant)
		end
	end)

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "ScrapPrompt" then
			hookPrompt(descendant)
		end
	end

	-- Also listen to direct RequestAction RemoteEvent (for mobile tap / button press)
	local requestActionEvent = Remotes.getEvent("RequestAction")
	requestActionEvent.OnServerEvent:Connect(function(player, targetModel)
		if typeof(targetModel) == "Instance" and targetModel:IsA("Model") then
			ActionService.performScrapAction(player, targetModel)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerLastActionTime[player] = nil
	end)

	print("[ActionService] Initialized.")
end

return ActionService
