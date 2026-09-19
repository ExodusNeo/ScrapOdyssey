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
local nodeBusyState: { [Model]: boolean } = {}

-- Create physical Dismantler Tool for player
local function giveScrapperTool(player: Player)
	local backpack = player:WaitForChild("Backpack")
	if backpack:FindFirstChild("PlasmaDismantler") then return end

	local tool = Instance.new("Tool")
	tool.Name = "PlasmaDismantler"
	tool.ToolTip = "Left-Click to dismantle scrap piles!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 3.2, 0.8)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(40, 42, 50)
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(1.2, 1.2, 1.2)
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
	light.Brightness = 1.5
	light.Range = 8
	light.Parent = tip

	-- Local script inside tool for click activation
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

			-- Find closest scrap pile
			local closestModel = nil
			local closestDist = 22

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

	-- 1. Distance Sanity Check (Max 26 studs)
	local distance = (rootPart.Position - nodeHitbox.Position).Magnitude
	if distance > 26 then
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
	if now - lastTime < (finalActionDelay * 0.82) then
		return
	end
	playerLastActionTime[player] = now

	-- 3. Visual "Punch" Feedback on Scrap Pile (Squash & Flash)
	local corePart = nodeModel:FindFirstChild("Core") :: BasePart
	local basePart = nodeModel:FindFirstChild("Base") :: BasePart

	if corePart then
		local origSize = corePart.Size
		local squashTween = TweenService:Create(corePart, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
			Size = origSize * 1.4,
		})
		squashTween:Play()
	end

	if basePart then
		local origColor = basePart.Color
		basePart.Color = Color3.fromRGB(255, 255, 255)
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
		Position = nodeHitbox.Position + Vector3.new(0, 4, 0),
	})
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

	-- Direct RequestAction RemoteEvent
	local requestActionEvent = Remotes.getEvent("RequestAction")
	requestActionEvent.OnServerEvent:Connect(function(player, targetModel)
		if typeof(targetModel) == "Instance" and targetModel:IsA("Model") then
			ActionService.performScrapAction(player, targetModel)
		end
	end)

	-- Give Scrapper Tool on character spawn
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

	Players.PlayerRemoving:Connect(function(player)
		playerLastActionTime[player] = nil
	end)

	print("[ActionService] Initialized with Scrapper Tool distribution and squash effects.")
end

return ActionService
