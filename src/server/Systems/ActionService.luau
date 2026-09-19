--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local ActionService = {}
local playerLastActionTime: { [Player]: number } = {}
local nodeCooldown: { [Model]: boolean } = {}

-- Create physical Plasma Dismantler Tool for player
local function giveScrapperTool(player: Player)
	local backpack = player:WaitForChild("Backpack")
	if backpack:FindFirstChild("PlasmaDismantler") then return end

	local tool = Instance.new("Tool")
	tool.Name = "PlasmaDismantler"
	tool.ToolTip = "Click to strike scrap piles!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 3.2, 0.7)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(35, 38, 48)
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(1.3, 1.3, 1.3)
	tip.Position = handle.Position + Vector3.new(0, 1.8, 0)
	tip.Material = Enum.Material.Neon
	tip.Color = Color3.fromRGB(255, 170, 0)
	tip.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = handle

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 50)
	light.Brightness = 2.0
	light.Range = 10
	light.Parent = tip

	-- Tool Activation LocalScript
	local toolScript = Instance.new("LocalScript")
	toolScript.Name = "ToolController"
	toolScript.Source = [=[
		local tool = script.Parent
		local player = game.Players.LocalPlayer
		local Remotes = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
		local requestAction = Remotes.getEvent("RequestAction")

		tool.Activated:Connect(function()
			local character = player.Character
			if not character then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end

			local closestModel = nil
			local closestDist = 24

			for _, desc in ipairs(workspace:GetDescendants()) do
				if desc:IsA("Model") and string.sub(desc.Name, 1, 10) == "ScrapPile_" then
					local hitbox = desc:FindFirstChild("Hitbox")
					if hitbox and hitbox:IsA("BasePart") then
						local dist = (root.Position - hitbox.Position).Magnitude
						if dist < closestDist then
							closestDist = dist
							closestModel = desc
						end
					end
				end
			end

			if closestModel then
				requestAction:FireServer(closestModel)
			end
		end)
	]=]
	toolScript.Parent = tool
	tool.Parent = backpack
end

-- Roll reward tier with SuperLuck perk support
function ActionService.rollRewardTier(player: Player): Types.RewardTier
	local data = DataService.get(player)
	local hasSuperLuck = data and data.GearsPerks and data.GearsPerks["SuperLuck"]

	local totalWeight = 0
	local adjustedTiers = {}

	for _, tier in ipairs(Config.RewardTiers) do
		local weight = tier.Weight
		if hasSuperLuck and tier.Name ~= "Common" then
			weight = weight * 2.5
		end
		totalWeight = totalWeight + weight
		table.insert(adjustedTiers, { Tier = tier, Weight = weight })
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, item in ipairs(adjustedTiers) do
		cumulative = cumulative + item.Weight
		if roll <= cumulative then
			return item.Tier
		end
	end

	return Config.RewardTiers[1]
end

-- Multi-Hit Crunchy Dismantling Action
function ActionService.performScrapAction(player: Player, nodeModel: Model)
	if nodeCooldown[nodeModel] then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not rootPart then return end

	local nodeHitbox = nodeModel:FindFirstChild("Hitbox") :: BasePart
	if not nodeHitbox then return end

	-- 1. Distance Sanity Check (26 studs)
	local distance = (rootPart.Position - nodeHitbox.Position).Magnitude
	if distance > 26 then return end

	-- 2. Cooldown & Speed Check
	local data = DataService.get(player)
	if not data then return end

	local zoneId = nodeModel:GetAttribute("ZoneId") or 1
	local zone = Config.Zones[zoneId]
	local baseActionTime = zone and zone.ActionTime or 1.0

	local speedLvl = (data.Upgrades and data.Upgrades["ScrapSpeed"]) or 1
	local speedReduction = (speedLvl - 1) * Config.Upgrades.ScrapSpeed.EffectPerLevel
	local finalActionDelay = math.max(0.18, baseActionTime - speedReduction)

	local now = os.clock()
	local lastTime = playerLastActionTime[player] or 0
	if now - lastTime < (finalActionDelay * 0.80) then return end
	playerLastActionTime[player] = now

	-- 3. Hit Points / Multi-Hit Logic
	local maxHP = nodeModel:GetAttribute("MaxHP") or 3
	local currentHP = nodeModel:GetAttribute("CurrentHP") or maxHP
	currentHP = currentHP - 1

	local corePart = nodeModel:FindFirstChild("Core") :: BasePart
	local basePart = nodeModel:FindFirstChild("Base") :: BasePart
	local statusLabel = nodeModel:FindFirstChild("StatusLabel", true) :: TextLabel

	-- Visual Hit squash & flash
	if corePart then
		local origSize = corePart.Size
		local squashTween = TweenService:Create(corePart, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
			Size = origSize * 1.35,
		})
		squashTween:Play()
	end

	if basePart then
		local origColor = basePart.Color
		basePart.Color = Color3.fromRGB(255, 255, 255)
		task.delay(0.1, function()
			if basePart and basePart.Parent then
				basePart.Color = origColor
			end
		end)
	end

	local tier = ActionService.rollRewardTier(player)
	local baseYield = zone and zone.BaseYield or 10

	if currentHP > 0 then
		-- Partial Strike: Give partial scrap, show hit count
		nodeModel:SetAttribute("CurrentHP", currentHP)
		if statusLabel then
			statusLabel.Text = string.format("🔨 %s\n[HP: %d/%d]", zone.Name:upper(), currentHP, maxHP)
		end

		local strikeScrap = math.max(1, math.floor((baseYield * tier.Multiplier) * 0.35))
		local earned = CurrencyService.addScrap(player, strikeScrap)

		local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
		actionCompletedEvent:FireClient(player, {
			TierName = "Hit",
			TierColor = Color3.fromRGB(200, 200, 200),
			ScrapEarned = earned,
			SoundPitch = 0.9 + math.random() * 0.2,
			Position = nodeHitbox.Position + Vector3.new(0, 3, 0),
		})
	else
		-- Final Break Strike: Huge explosion of rewards and respawn timer!
		nodeModel:SetAttribute("CurrentHP", 0)
		nodeCooldown[nodeModel] = true

		if statusLabel then
			statusLabel.Text = "✨ HARVESTED! ✨"
		end

		local breakScrap = math.floor((baseYield * tier.Multiplier) * 1.5)
		local earned = CurrencyService.addScrap(player, breakScrap)

		local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
		actionCompletedEvent:FireClient(player, {
			TierName = tier.Name,
			TierColor = tier.Color,
			ScrapEarned = earned,
			SoundPitch = tier.SoundPitch,
			Position = nodeHitbox.Position + Vector3.new(0, 4, 0),
		})

		-- Collapse node
		if corePart then corePart.Transparency = 1 end
		if basePart then basePart.Transparency = 0.8 end

		-- Respawn after 2.5 seconds
		task.delay(2.5, function()
			if nodeModel and nodeModel.Parent then
				nodeModel:SetAttribute("CurrentHP", maxHP)
				if corePart then corePart.Transparency = 0 end
				if basePart then basePart.Transparency = 0 end
				if statusLabel then
					statusLabel.Text = string.format("🔨 %s\n[HP: %d/%d]", zone.Name:upper(), maxHP, maxHP)
				end
				nodeCooldown[nodeModel] = false
			end
		end)
	end
end

function ActionService.init()
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

	local requestActionEvent = Remotes.getEvent("RequestAction")
	requestActionEvent.OnServerEvent:Connect(function(player, targetModel)
		if typeof(targetModel) == "Instance" and targetModel:IsA("Model") then
			ActionService.performScrapAction(player, targetModel)
		end
	end)

	-- Give tool on join and spawn
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			giveScrapperTool(player)
		end)
		if player.Character then
			giveScrapperTool(player)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			giveScrapperTool(player)
		end
	end

	-- AutoScrap Perk Loop: background automatic harvesting for players with the perk!
	task.spawn(function()
		while true do
			task.wait(1.8)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data and data.GearsPerks and data.GearsPerks["AutoScrap"] then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart
					if root then
						-- Find nearest pile
						for _, desc in ipairs(Workspace:GetDescendants()) do
							if desc:IsA("Model") and string.sub(desc.Name, 1, 10) == "ScrapPile_" then
								local hb = desc:FindFirstChild("Hitbox") :: BasePart
								if hb and (root.Position - hb.Position).Magnitude <= 22 then
									ActionService.performScrapAction(player, desc)
									break
								end
							end
						end
					end
				end
			end
		end
	end)

	print("[ActionService] Initialized with crunchy multi-hit scrapping and AutoScrap perk support.")
end

return ActionService
