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

-- Procedural 3D Scrapper Tool Construction (5 Tiers)
function ActionService.buildTool(toolId: string): Tool
	local conf = Config.getTool(toolId) or Config.Tools[1]

	local tool = Instance.new("Tool")
	tool.Name = conf.Name
	tool.ToolTip = string.format("%s (Damage: %d)", conf.Name, conf.Damage)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, -0.6, 0)
	tool:SetAttribute("IsScrapperTool", true)
	tool:SetAttribute("ToolId", conf.Id)
	tool:SetAttribute("Damage", conf.Damage)
	tool:SetAttribute("Cooldown", conf.Cooldown)
	tool:SetAttribute("Range", conf.Range)

	-- Main Ergonomic Handle Grip
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Material = Enum.Material.Rubber
	handle.Color = Color3.fromRGB(28, 30, 36)
	handle.CanCollide = false
	handle.Parent = tool

	if conf.Id == "OmniWrench" then
		handle.Size = Vector3.new(0.65, 2.6, 0.65)
		-- Shaft
		local shaft = Instance.new("Part")
		shaft.Name = "WrenchShaft"
		shaft.Size = Vector3.new(0.8, 1.4, 0.5)
		shaft.Position = handle.Position + Vector3.new(0, 1.6, 0)
		shaft.Material = Enum.Material.Metal
		shaft.Color = Color3.fromRGB(160, 165, 175)
		shaft.CanCollide = false
		shaft.Parent = tool
		local wShaft = Instance.new("WeldConstraint")
		wShaft.Part0 = handle; wShaft.Part1 = shaft; wShaft.Parent = shaft

		-- Wrench Head (C-Jaw)
		local head = Instance.new("Part")
		head.Name = "WrenchHead"
		head.Size = Vector3.new(1.6, 1.2, 0.6)
		head.Position = handle.Position + Vector3.new(0, 2.6, 0)
		head.Material = Enum.Material.CorrodedMetal
		head.Color = conf.Color
		head.CanCollide = false
		head.Parent = tool
		local wHead = Instance.new("WeldConstraint")
		wHead.Part0 = handle; wHead.Part1 = head; wHead.Parent = head

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Color = ColorSequence.new(conf.Color)
		sparks.Size = NumberSequence.new(0.1, 0.25)
		sparks.Rate = 5
		sparks.Speed = NumberRange.new(1.0, 2.5)
		sparks.Lifetime = NumberRange.new(0.2, 0.5)
		sparks.Parent = head

	elseif conf.Id == "PneumaticDrill" then
		handle.Size = Vector3.new(0.7, 2.2, 0.7)
		-- Drill Chamber
		local chamber = Instance.new("Part")
		chamber.Name = "Chamber"
		chamber.Size = Vector3.new(1.6, 2.2, 1.6)
		chamber.Position = handle.Position + Vector3.new(0, 1.6, 0)
		chamber.Material = Enum.Material.DiamondPlate
		chamber.Color = conf.Color
		chamber.CanCollide = false
		chamber.Parent = tool
		local wChamber = Instance.new("WeldConstraint")
		wChamber.Part0 = handle; wChamber.Part1 = chamber; wChamber.Parent = chamber

		-- Air Tanks
		for _, xOff in ipairs({ -0.85, 0.85 }) do
			local tank = Instance.new("Part")
			tank.Shape = Enum.PartType.Cylinder
			tank.Size = Vector3.new(1.8, 0.6, 0.6)
			tank.Position = chamber.Position + Vector3.new(xOff, 0, 0)
			tank.Orientation = Vector3.new(0, 0, 90)
			tank.Material = Enum.Material.Metal
			tank.Color = Color3.fromRGB(180, 190, 205)
			tank.CanCollide = false
			tank.Parent = tool
			local wTank = Instance.new("WeldConstraint")
			wTank.Part0 = chamber; wTank.Part1 = tank; wTank.Parent = tank
		end

		-- Drill Bit
		local bit = Instance.new("Part")
		bit.Name = "DrillBit"
		bit.Shape = Enum.PartType.Cylinder
		bit.Size = Vector3.new(2.4, 1.0, 1.0)
		bit.Position = chamber.Position + Vector3.new(0, 2.1, 0)
		bit.Orientation = Vector3.new(0, 0, 90)
		bit.Material = Enum.Material.Metal
		bit.Color = Color3.fromRGB(75, 80, 90)
		bit.CanCollide = false
		bit.Parent = tool
		local wBit = Instance.new("WeldConstraint")
		wBit.Part0 = chamber; wBit.Part1 = bit; wBit.Parent = bit

		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Exhaust"
		smoke.Color = ColorSequence.new(Color3.fromRGB(190, 190, 200))
		smoke.Size = NumberSequence.new(0.3, 0.8)
		smoke.Transparency = NumberSequence.new(0.4, 1.0)
		smoke.Rate = 8
		smoke.Speed = NumberRange.new(2, 4)
		smoke.Lifetime = NumberRange.new(0.4, 0.8)
		smoke.Parent = chamber

	elseif conf.Id == "PlasmaCutter" then
		handle.Size = Vector3.new(0.65, 2.8, 0.65)
		-- Housing Head
		local head = Instance.new("Part")
		head.Name = "NozzleHousing"
		head.Size = Vector3.new(1.2, 1.4, 1.2)
		head.Position = handle.Position + Vector3.new(0, 1.8, 0)
		head.Material = Enum.Material.DiamondPlate
		head.Color = Color3.fromRGB(45, 50, 60)
		head.CanCollide = false
		head.Parent = tool
		local wHead = Instance.new("WeldConstraint")
		wHead.Part0 = handle; wHead.Part1 = head; wHead.Parent = head

		-- Dual Plasma Cells
		for _, xOff in ipairs({ -0.65, 0.65 }) do
			local cell = Instance.new("Part")
			cell.Size = Vector3.new(0.35, 1.2, 0.35)
			cell.Position = head.Position + Vector3.new(xOff, -0.2, 0)
			cell.Material = Enum.Material.SmoothPlastic
			cell.Color = conf.Color
			cell.CanCollide = false
			cell.Parent = tool
			local wCell = Instance.new("WeldConstraint")
			wCell.Part0 = head; wCell.Part1 = cell; wCell.Parent = cell
		end

		-- Concentrated Plasma Torch Beam
		local beam = Instance.new("Part")
		beam.Name = "PlasmaBeam"
		beam.Size = Vector3.new(0.45, 2.2, 0.45)
		beam.Position = head.Position + Vector3.new(0, 1.4, 0)
		beam.Material = Enum.Material.SmoothPlastic
		beam.Color = conf.Color
		beam.CanCollide = false
		beam.Parent = tool
		local wBeam = Instance.new("WeldConstraint")
		wBeam.Part0 = head; wBeam.Part1 = beam; wBeam.Parent = beam

		local light = Instance.new("PointLight")
		light.Color = conf.Color
		light.Brightness = 2.5
		light.Range = 12
		light.Parent = beam

		local fire = Instance.new("ParticleEmitter")
		fire.Name = "PlasmaFire"
		fire.Color = ColorSequence.new(conf.Color)
		fire.Size = NumberSequence.new(0.2, 0.6)
		fire.Rate = 12
		fire.Speed = NumberRange.new(2, 5)
		fire.Lifetime = NumberRange.new(0.2, 0.5)
		fire.SpreadAngle = Vector2.new(45, 45)
		fire.Parent = beam

	elseif conf.Id == "CyberScythe" then
		handle.Size = Vector3.new(0.55, 4.4, 0.55)
		handle.Color = Color3.fromRGB(20, 22, 28)

		-- Emitter Hub
		local hub = Instance.new("Part")
		hub.Name = "ScytheHub"
		hub.Size = Vector3.new(1.1, 1.1, 1.1)
		hub.Position = handle.Position + Vector3.new(0, 2.4, 0)
		hub.Material = Enum.Material.Metal
		hub.Color = Color3.fromRGB(40, 42, 52)
		hub.CanCollide = false
		hub.Parent = tool
		local wHub = Instance.new("WeldConstraint")
		wHub.Part0 = handle; wHub.Part1 = hub; wHub.Parent = hub

		-- Curved Energy Blade
		local blade = Instance.new("Part")
		blade.Name = "EnergyBlade"
		blade.Size = Vector3.new(2.8, 0.75, 0.3)
		blade.Position = hub.Position + Vector3.new(1.3, 0.4, 0)
		blade.Orientation = Vector3.new(0, 0, 30)
		blade.Material = Enum.Material.SmoothPlastic
		blade.Color = conf.Color
		blade.CanCollide = false
		blade.Parent = tool
		local wBlade = Instance.new("WeldConstraint")
		wBlade.Part0 = hub; wBlade.Part1 = blade; wBlade.Parent = blade

		local light = Instance.new("PointLight")
		light.Color = conf.Color
		light.Brightness = 2.8
		light.Range = 14
		light.Parent = blade

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "CyberLightning"
		sparks.Color = ColorSequence.new(conf.Color)
		sparks.Size = NumberSequence.new(0.15, 0.45)
		sparks.Rate = 14
		sparks.Speed = NumberRange.new(2, 6)
		sparks.Lifetime = NumberRange.new(0.2, 0.5)
		sparks.Parent = blade

	elseif conf.Id == "VoidRipper" then
		handle.Size = Vector3.new(0.7, 3.4, 0.7)
		handle.Color = Color3.fromRGB(15, 15, 20)

		-- Void Crossguard
		local guard = Instance.new("Part")
		guard.Name = "VoidGuard"
		guard.Size = Vector3.new(2.4, 0.8, 0.7)
		guard.Position = handle.Position + Vector3.new(0, 1.9, 0)
		guard.Material = Enum.Material.DiamondPlate
		guard.Color = Color3.fromRGB(35, 25, 45)
		guard.CanCollide = false
		guard.Parent = tool
		local wGuard = Instance.new("WeldConstraint")
		wGuard.Part0 = handle; wGuard.Part1 = guard; wGuard.Parent = guard

		-- Singularity Core Orb
		local core = Instance.new("Part")
		core.Name = "SingularityCore"
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(1.1, 1.1, 1.1)
		core.Position = guard.Position + Vector3.new(0, 0.4, 0)
		core.Material = Enum.Material.SmoothPlastic
		core.Color = conf.Color
		core.CanCollide = false
		core.Parent = tool
		local wCore = Instance.new("WeldConstraint")
		wCore.Part0 = guard; wCore.Part1 = core; wCore.Parent = core

		-- Dual Cleaver Blades
		for _, xOff in ipairs({ -0.4, 0.4 }) do
			local cBlade = Instance.new("Part")
			cBlade.Name = "VoidBlade"
			cBlade.Size = Vector3.new(0.35, 3.0, 0.8)
			cBlade.Position = guard.Position + Vector3.new(xOff, 2.0, 0)
			cBlade.Material = Enum.Material.CorrodedMetal
			cBlade.Color = Color3.fromRGB(25, 20, 32)
			cBlade.CanCollide = false
			cBlade.Parent = tool
			local wCBlade = Instance.new("WeldConstraint")
			wCBlade.Part0 = guard; wCBlade.Part1 = cBlade; wCBlade.Parent = cBlade
		end

		local light = Instance.new("PointLight")
		light.Color = conf.Color
		light.Brightness = 3.2
		light.Range = 16
		light.Parent = core

		local vortex = Instance.new("ParticleEmitter")
		vortex.Name = "VoidVortex"
		vortex.Color = ColorSequence.new(conf.Color)
		vortex.Size = NumberSequence.new(0.2, 0.7)
		vortex.Rate = 18
		vortex.Speed = NumberRange.new(1.5, 4.5)
		vortex.Lifetime = NumberRange.new(0.4, 0.9)
		vortex.SpreadAngle = Vector2.new(180, 180)
		vortex.Parent = core
	end

	return tool
end

-- Give or update the player's equipped scrapper tool
function ActionService.giveScrapperTool(player: Player)
	local data = DataService.get(player)
	local toolId = data and data.EquippedTool or "OmniWrench"
	local conf = Config.getTool(toolId) or Config.Tools[1]

	-- Clear out any existing scrapper tools in Character & Backpack
	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and (item:GetAttribute("IsScrapperTool") or item:GetAttribute("ToolId") ~= nil or item.Name == "ScrapperTool" or item.Name == conf.Name) then
				item:Destroy()
			end
		end
	end

	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and (item:GetAttribute("IsScrapperTool") or item:GetAttribute("ToolId") ~= nil or item.Name == "ScrapperTool" or item.Name == conf.Name) then
				item:Destroy()
			end
		end

		local tool = ActionService.buildTool(toolId)
		tool.Parent = backpack

		-- Auto-equip tool to character's hand if humanoid exists
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				task.defer(function()
					if tool.Parent == backpack and character.Parent then
						humanoid:EquipTool(tool)
					end
				end)
			end
		end
		print(string.format("[ActionService] Successfully granted %s (%s) to %s", conf.Name, toolId, player.Name))
	end
end

-- Equip an owned tool
function ActionService.equipTool(player: Player, toolId: string)
	local data = DataService.get(player)
	if not data then return end
	if not data.OwnedTools then
		data.OwnedTools = { ["OmniWrench"] = true }
	end
	if toolId == "OmniWrench" then
		data.OwnedTools["OmniWrench"] = true
	end
	if not data.OwnedTools[toolId] then return end

	data.EquippedTool = toolId
	DataService.sync(player)
	ActionService.giveScrapperTool(player)

	local conf = Config.getTool(toolId)
	if conf then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Tool Equipped", string.format("Equipped %s (%s)!", conf.Name, conf.Emoji), conf.Color)
	end
end

-- Purchase and equip a tool from the Armory
function ActionService.purchaseTool(player: Player, toolId: string)
	local data = DataService.get(player)
	if not data then return end
	local conf = Config.getTool(toolId)
	if not conf then return end

	data.OwnedTools = data.OwnedTools or { ["OmniWrench"] = true }
	if data.OwnedTools[toolId] then
		ActionService.equipTool(player, toolId)
		return
	end

	if data.Scrap < conf.Cost then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Insufficient Scrap", string.format("You need %s Scrap to purchase the %s!", tostring(conf.Cost), conf.Name), Color3.fromRGB(255, 75, 75))
		return
	end

	data.Scrap -= conf.Cost
	data.OwnedTools[toolId] = true
	data.EquippedTool = toolId
	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)
	ActionService.giveScrapperTool(player)

	local notif = Remotes.getEvent("ShowNotification")
	notif:FireClient(player, "Tool Unlocked!", string.format("Unlocked and equipped %s (%s)!", conf.Name, conf.Emoji), conf.Color)
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

	local data = DataService.get(player)
	if not data then return end

	local toolConf = Config.getTool(data.EquippedTool or "OmniWrench")
	local maxRange = (toolConf and toolConf.Range or 22) + 6

	-- 1. Distance Sanity Check (scales with tool range)
	local distance = (rootPart.Position - nodeHitbox.Position).Magnitude
	if distance > maxRange then return end

	-- 2. Cooldown & Capacity Check
	local bagLevel = (data.Upgrades and data.Upgrades["BackpackCapacity"]) or 1
	local maxCapacity = Config.getBackpackCapacity(bagLevel)
	local currentBackpack = data.Backpack or 0

	if currentBackpack >= maxCapacity then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "🎒 CARGO FULL!", "Your backpack is full! Step on the Scrap Recycler in the Hub to sell!", Color3.fromRGB(255, 70, 70))
		return
	end

	local zoneId = nodeModel:GetAttribute("ZoneId") or 1
	local zone = Config.Zones[zoneId]
	local baseActionTime = zone and zone.ActionTime or 1.0

	local speedLvl = (data.Upgrades and data.Upgrades["ScrapSpeed"]) or 1
	local speedReduction = (speedLvl - 1) * Config.Upgrades.ScrapSpeed.EffectPerLevel
	local toolCooldown = toolConf and toolConf.Cooldown or 0.45
	local finalActionDelay = math.max(0.12, (baseActionTime * toolCooldown) - speedReduction)

	local now = os.clock()
	local lastTime = playerLastActionTime[player] or 0
	if now - lastTime < (finalActionDelay * 0.75) then return end
	playerLastActionTime[player] = now

	-- 3. Hit Points / Multi-Hit Logic with Tool Damage
	local maxHP = nodeModel:GetAttribute("MaxHP") or 3
	local currentHP = nodeModel:GetAttribute("CurrentHP") or maxHP
	local toolDamage = toolConf and toolConf.Damage or 1
	currentHP = currentHP - toolDamage

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
	local baseYield = nodeModel:GetAttribute("BaseYield") or (zone and zone.BaseYield) or 10
	local isDense = nodeModel:GetAttribute("IsDense")

	if currentHP > 0 then
		-- Partial Strike: Fill backpack partially
		nodeModel:SetAttribute("CurrentHP", currentHP)
		local titleText = isDense and string.format("⭐ DENSE %s ⭐", zone.Name:upper()) or string.format("🔨 %s", zone.Name:upper())
		if statusLabel then
			statusLabel.Text = titleText
		end
		local hpLabel = nodeModel:FindFirstChild("HpLabel", true) :: TextLabel?
		if hpLabel then
			hpLabel.Text = string.format("[ %d / %d HP ]", currentHP, maxHP)
		elseif statusLabel then
			statusLabel.Text = string.format("%s\n[HP: %d/%d]", zone.Name:upper(), currentHP, maxHP)
		end

		local barFill = nodeModel:FindFirstChild("HealthBarFill", true) :: Frame?
		if barFill then
			local pct = math.clamp(currentHP / maxHP, 0, 1)
			barFill.Size = UDim2.new(pct, 0, 1, 0)
			if pct > 0.5 then
				barFill.BackgroundColor3 = Color3.fromRGB(40, 215, 95)
			elseif pct > 0.25 then
				barFill.BackgroundColor3 = Color3.fromRGB(245, 175, 30)
			else
				barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
			end
		end

		local damageRatio = math.clamp(toolDamage / maxHP, 0.15, 1.0)
		local strikeScrap = math.max(1, math.floor((baseYield * tier.Multiplier) * (damageRatio * 0.75)))
		local spaceLeft = math.max(0, maxCapacity - (data.Backpack or 0))
		local added = math.min(spaceLeft, strikeScrap)
		data.Backpack = (data.Backpack or 0) + added
		DataService.sync(player)
		CurrencyService.updateLeaderstats(player)

		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCoreColor(player)
		end)

		local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
		actionCompletedEvent:FireClient(player, {
			IsBreak = false,
			IsDense = isDense == true,
			MaxHP = maxHP,
			CurrentHP = currentHP,
			TierName = isDense and "Dense Hit" or "Hit",
			TierColor = isDense and Color3.fromRGB(255, 215, 50) or Color3.fromRGB(200, 200, 200),
			ScrapEarned = added,
			SoundPitch = 0.9 + math.random() * 0.2,
			Position = nodeHitbox.Position + Vector3.new(0, 3, 0),
		})
	else
		-- Final Break Strike: Big reward into backpack!
		nodeModel:SetAttribute("CurrentHP", 0)
		nodeCooldown[nodeModel] = true

		if statusLabel then
			statusLabel.Text = "✨ HARVESTED! ✨"
		end
		local hpLabel = nodeModel:FindFirstChild("HpLabel", true) :: TextLabel?
		if hpLabel then
			hpLabel.Text = "[ 0 / " .. tostring(maxHP) .. " HP ]"
		end
		local barFill = nodeModel:FindFirstChild("HealthBarFill", true) :: Frame?
		if barFill then
			barFill.Size = UDim2.new(0, 0, 1, 0)
		end

		local breakScrap = math.floor((baseYield * tier.Multiplier) * 1.5)
		local spaceLeft = math.max(0, maxCapacity - (data.Backpack or 0))
		local added = math.min(spaceLeft, breakScrap)
		data.Backpack = (data.Backpack or 0) + added
		DataService.sync(player)
		CurrencyService.updateLeaderstats(player)

		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCoreColor(player)
		end)

		local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
		actionCompletedEvent:FireClient(player, {
			IsBreak = true,
			IsDense = isDense == true,
			MaxHP = maxHP,
			CurrentHP = 0,
			TierName = isDense and ("DENSE " .. tier.Name) or tier.Name,
			TierColor = isDense and Color3.fromRGB(255, 215, 50) or tier.Color,
			ScrapEarned = added,
			SoundPitch = tier.SoundPitch,
			Position = nodeHitbox.Position + Vector3.new(0, 4, 0),
		})

		pcall(function()
			local QuestService = require(script.Parent.QuestService)
			QuestService.recordScrapPile(player, 1)
		end)

		-- Collapse node
		if corePart then corePart.Transparency = 1 end
		if basePart then basePart.Transparency = 0.8 end
		local halo = nodeModel:FindFirstChild("DenseHalo") :: BasePart?
		if halo then halo.Transparency = 1 end

		-- Respawn after 2.5 seconds with fresh RNG Dense roll
		task.delay(2.5, function()
			if nodeModel and nodeModel.Parent then
				local rZoneId = nodeModel:GetAttribute("ZoneId") or 1
				local rZone = Config.Zones[rZoneId] or zone
				local isDenseRoll = (math.random() <= 0.28) -- 28% RNG chance on every respawn!

				local ZoneService = require(script.Parent.ZoneService)
				ZoneService.applyNodeVariant(nodeModel, rZone, isDenseRoll)

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

	local purchaseToolEvent = Remotes.getEvent("PurchaseTool")
	purchaseToolEvent.OnServerEvent:Connect(function(player, toolId)
		if type(toolId) == "string" then
			ActionService.purchaseTool(player, toolId)
		end
	end)

	local equipToolEvent = Remotes.getEvent("EquipTool")
	equipToolEvent.OnServerEvent:Connect(function(player, toolId)
		if type(toolId) == "string" then
			ActionService.equipTool(player, toolId)
		end
	end)

	-- StarterPack default tool ensures Roblox natively populates hotbar slot 1 on spawn
	local starterPack = game:GetService("StarterPack")
	local defaultTool = starterPack:FindFirstChild("Omni-Wrench")
	if not defaultTool then
		local sTool = ActionService.buildTool("OmniWrench")
		sTool.Parent = starterPack
	end

	-- Give tool on join and spawn (with delay to let engine finish backpack reset)
	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			if player.Parent and character.Parent then
				ActionService.giveScrapperTool(player)
			end
		end)

		if player.Character then
			task.spawn(function()
				task.wait(0.2)
				if player.Parent and player.Character then
					ActionService.giveScrapperTool(player)
				end
			end)
		end
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
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
