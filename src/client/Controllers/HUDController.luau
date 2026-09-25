--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)
local controllersFolder = (script and script.Parent) or game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")
local SoundController = require(controllersFolder:WaitForChild("SoundController"))
local VFXController = require(controllersFolder:WaitForChild("VFXController"))

local player = Players.LocalPlayer
local function getPlayerGui(): PlayerGui?
	if not player then
		player = Players.LocalPlayer
	end
	return player and (player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5)) :: PlayerGui?
end

local HUDController = {}

local mainGui: ScreenGui
local scrapLabel: TextLabel
local gearsLabel: TextLabel
local multLabel: TextLabel
local cargoFill: Frame
local cargoLabel: TextLabel
local currentScrap = 0
local currentGears = 0
local currentBackpack = -1
local comboBadge: Frame
local comboLabel: TextLabel
local cbStroke: UIStroke
local lastComboTime = 0
local recentPopups: { { Pos: Vector3, Time: number } } = {}

local function formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

function HUDController.createHUD()
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "ScrapOdysseyHUD"
	mainGui.ResetOnSpawn = false
	mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local pGui = getPlayerGui()
	if pGui then
		mainGui.Parent = pGui
	end

	-- Top Right Currency Module (Banked Spendable Scrap & Gears)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.AnchorPoint = Vector2.new(1, 0)
	topBar.Size = UDim2.new(0, 320, 0, 58)
	topBar.Position = UDim2.new(1, -24, 0, 20)
	topBar.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	topBar.BackgroundTransparency = 0.08
	topBar.BorderSizePixel = 0
	topBar.Parent = mainGui

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 8)
	topCorner.Parent = topBar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(38, 48, 64)
	topStroke.Thickness = 1
	topStroke.Parent = topBar

	-- Top accent line
	local accentLine = Instance.new("Frame")
	accentLine.Name = "TopAccent"
	accentLine.Size = UDim2.new(1, 0, 0, 2)
	accentLine.Position = UDim2.new(0, 0, 0, 0)
	accentLine.BackgroundColor3 = Color3.fromRGB(240, 180, 50)
	accentLine.BorderSizePixel = 0
	accentLine.Parent = topBar

	-- Banked Scrap Section (Left half)
	local scrapContainer = Instance.new("Frame")
	scrapContainer.Name = "ScrapContainer"
	scrapContainer.Size = UDim2.new(0.5, -8, 1, -10)
	scrapContainer.Position = UDim2.new(0, 6, 0, 5)
	scrapContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	scrapContainer.BorderSizePixel = 0
	scrapContainer.Parent = topBar

	local scCorner = Instance.new("UICorner")
	scCorner.CornerRadius = UDim.new(0, 6)
	scCorner.Parent = scrapContainer

	local scTag = Instance.new("TextLabel")
	scTag.Name = "Tag"
	scTag.Size = UDim2.new(1, -16, 0, 14)
	scTag.Position = UDim2.new(0, 10, 0, 6)
	scTag.BackgroundTransparency = 1
	scTag.Font = Enum.Font.GothamBold
	scTag.TextSize = 10
	scTag.TextColor3 = Color3.fromRGB(240, 185, 45)
	scTag.TextXAlignment = Enum.TextXAlignment.Left
	scTag.Text = "🔩 SCRAP"
	scTag.Parent = scrapContainer

	scrapLabel = Instance.new("TextLabel")
	scrapLabel.Name = "Value"
	scrapLabel.Size = UDim2.new(1, -16, 0, 24)
	scrapLabel.Position = UDim2.new(0, 10, 0, 20)
	scrapLabel.BackgroundTransparency = 1
	scrapLabel.Font = Enum.Font.GothamBlack
	scrapLabel.TextSize = 19
	scrapLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	scrapLabel.TextXAlignment = Enum.TextXAlignment.Left
	scrapLabel.Text = "0"
	scrapLabel.Parent = scrapContainer

	-- Gears Section (Right half)
	local gearsContainer = Instance.new("Frame")
	gearsContainer.Name = "GearsContainer"
	gearsContainer.Size = UDim2.new(0.5, -8, 1, -10)
	gearsContainer.Position = UDim2.new(0.5, 2, 0, 5)
	gearsContainer.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	gearsContainer.BorderSizePixel = 0
	gearsContainer.Parent = topBar

	local gcCorner = Instance.new("UICorner")
	gcCorner.CornerRadius = UDim.new(0, 6)
	gcCorner.Parent = gearsContainer

	local gcTag = Instance.new("TextLabel")
	gcTag.Name = "Tag"
	gcTag.Size = UDim2.new(1, -16, 0, 14)
	gcTag.Position = UDim2.new(0, 10, 0, 6)
	gcTag.BackgroundTransparency = 1
	gcTag.Font = Enum.Font.GothamBold
	gcTag.TextSize = 10
	gcTag.TextColor3 = Color3.fromRGB(60, 190, 240)
	gcTag.TextXAlignment = Enum.TextXAlignment.Left
	gcTag.Text = "⚙️ GEARS"
	gcTag.Parent = gearsContainer

	gearsLabel = Instance.new("TextLabel")
	gearsLabel.Name = "Value"
	gearsLabel.Size = UDim2.new(1, -16, 0, 24)
	gearsLabel.Position = UDim2.new(0, 10, 0, 20)
	gearsLabel.BackgroundTransparency = 1
	gearsLabel.Font = Enum.Font.GothamBlack
	gearsLabel.TextSize = 19
	gearsLabel.TextColor3 = Color3.fromRGB(120, 225, 255)
	gearsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gearsLabel.Text = "0"
	gearsLabel.Parent = gearsContainer

	-- Raw Cargo / Backpack Progress Bar (Top Right)
	local cargoContainer = Instance.new("Frame")
	cargoContainer.Name = "CargoContainer"
	cargoContainer.AnchorPoint = Vector2.new(1, 0)
	cargoContainer.Size = UDim2.new(0, 320, 0, 26)
	cargoContainer.Position = UDim2.new(1, -24, 0, 84)
	cargoContainer.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	cargoContainer.BackgroundTransparency = 0.08
	cargoContainer.BorderSizePixel = 0
	cargoContainer.ClipsDescendants = true
	cargoContainer.Parent = mainGui

	local ccCorner = Instance.new("UICorner")
	ccCorner.CornerRadius = UDim.new(0, 6)
	ccCorner.Parent = cargoContainer

	local ccStroke = Instance.new("UIStroke")
	ccStroke.Color = Color3.fromRGB(38, 48, 64)
	ccStroke.Thickness = 1
	ccStroke.Parent = cargoContainer

	cargoFill = Instance.new("Frame")
	cargoFill.Name = "CargoFill"
	cargoFill.Size = UDim2.new(0, 0, 1, 0)
	cargoFill.BackgroundColor3 = Color3.fromRGB(35, 190, 110)
	cargoFill.BorderSizePixel = 0
	cargoFill.Parent = cargoContainer

	local cfCorner = Instance.new("UICorner")
	cfCorner.CornerRadius = UDim.new(0, 6)
	cfCorner.Parent = cargoFill

	cargoLabel = Instance.new("TextLabel")
	cargoLabel.Name = "CargoLabel"
	cargoLabel.Size = UDim2.new(1, -16, 1, 0)
	cargoLabel.Position = UDim2.new(0, 8, 0, 0)
	cargoLabel.BackgroundTransparency = 1
	cargoLabel.Font = Enum.Font.GothamBold
	cargoLabel.TextSize = 11
	cargoLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	cargoLabel.TextStrokeTransparency = 0.4
	cargoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	cargoLabel.Text = "🎒 CARGO: 0 / 50"
	cargoLabel.ZIndex = 2
	cargoLabel.Parent = cargoContainer

	-- Multiplier Badge below cargo bar (Top Right)
	local badge = Instance.new("Frame")
	badge.Name = "MultiplierBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Size = UDim2.new(0, 130, 0, 22)
	badge.Position = UDim2.new(1, -24, 0, 116)
	badge.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	badge.BackgroundTransparency = 0.15
	badge.BorderSizePixel = 0
	badge.Parent = mainGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 5)
	bCorner.Parent = badge

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(45, 85, 140)
	bStroke.Thickness = 1
	bStroke.Parent = badge

	multLabel = Instance.new("TextLabel")
	multLabel.Size = UDim2.new(1, 0, 1, 0)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 11
	multLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	multLabel.Text = "⚡ BOOST: 1.0x"
	multLabel.Parent = badge

	-- Combo Streak Badge (Top Right, immediately left of MultiplierBadge)
	comboBadge = Instance.new("Frame")
	comboBadge.Name = "ComboBadge"
	comboBadge.AnchorPoint = Vector2.new(1, 0)
	comboBadge.Size = UDim2.new(0, 160, 0, 22)
	comboBadge.Position = UDim2.new(1, -160, 0, 116)
	comboBadge.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	comboBadge.BackgroundTransparency = 1
	comboBadge.BorderSizePixel = 0
	comboBadge.Parent = mainGui

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 5)
	cbCorner.Parent = comboBadge

	cbStroke = Instance.new("UIStroke")
	cbStroke.Color = Color3.fromRGB(255, 140, 20)
	cbStroke.Thickness = 1.2
	cbStroke.Transparency = 1
	cbStroke.Parent = comboBadge

	comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "ComboLabel"
	comboLabel.Size = UDim2.new(1, 0, 1, 0)
	comboLabel.BackgroundTransparency = 1
	comboLabel.TextTransparency = 1
	comboLabel.Font = Enum.Font.GothamBlack
	comboLabel.TextSize = 11
	comboLabel.TextColor3 = Color3.fromRGB(255, 160, 30)
	comboLabel.Text = "🔥 STREAK x2 (+5%)"
	comboLabel.Parent = comboBadge
end

function HUDController.updateComboStreak(combo: number)
	if not comboBadge or not comboLabel or not cbStroke then return end
	if combo < 2 then
		TweenService:Create(comboBadge, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cbStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(comboLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		return
	end

	lastComboTime = os.clock()
	local bonusPct = math.min(45, (combo - 1) * 5)
	if combo >= 10 then
		comboLabel.Text = string.format("⚡ OVERDRIVE x%d (+%d%%)!", combo, bonusPct)
		comboLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
		cbStroke.Color = Color3.fromRGB(255, 215, 0)
	else
		comboLabel.Text = string.format("🔥 STREAK x%d (+%d%%)", combo, bonusPct)
		comboLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
		cbStroke.Color = Color3.fromRGB(255, 130, 20)
	end

	comboBadge.BackgroundTransparency = 0.15
	cbStroke.Transparency = 0
	comboLabel.TextTransparency = 0

	local bounce = TweenService:Create(comboBadge, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
		Size = UDim2.new(0, 172, 0, 24),
	})
	bounce:Play()

	task.delay(3.8, function()
		if os.clock() - lastComboTime >= 3.7 and comboBadge and comboLabel and cbStroke then
			TweenService:Create(comboBadge, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(cbStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			TweenService:Create(comboLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

function HUDController.updateCurrencies(data: Types.PlayerData)
	if not scrapLabel or not gearsLabel then return end

	local targetScrap = data.Scrap
	local targetGears = data.Gears

	-- Pop animation for banked scrap
	if targetScrap ~= currentScrap then
		currentScrap = targetScrap
		scrapLabel.Text = formatNumber(targetScrap)
		local tween = TweenService:Create(scrapLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
			TextSize = 25,
			TextColor3 = Color3.fromRGB(255, 255, 255),
		})
		tween:Play()
		task.delay(0.12, function()
			if scrapLabel then
				scrapLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			end
		end)
	end

	-- Pop animation for gears
	if targetGears ~= currentGears then
		currentGears = targetGears
		gearsLabel.Text = formatNumber(targetGears)
		local tween = TweenService:Create(gearsLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
			TextSize = 25,
		})
		tween:Play()
	end

	-- Update Cargo Capacity Bar
	if cargoFill and cargoLabel then
		local bagLevel = (data.Upgrades and data.Upgrades["BackpackCapacity"]) or 1
		local maxCap = Config.getBackpackCapacity(bagLevel)
		local backpack = data.Backpack or 0
		local ratio = math.clamp(backpack / math.max(1, maxCap), 0, 1)

		TweenService:Create(cargoFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0),
		}):Play()

		if backpack >= maxCap then
			cargoFill.BackgroundColor3 = Color3.fromRGB(240, 50, 60)
			cargoLabel.Text = string.format("⚠️ CARGO FULL (%d/%d) — RECYCLE AT HUB", backpack, maxCap)
			cargoLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
		elseif ratio >= 0.8 then
			cargoFill.BackgroundColor3 = Color3.fromRGB(255, 170, 30)
			cargoLabel.Text = string.format("🎒 CARGO: %d / %d", backpack, maxCap)
			cargoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			cargoFill.BackgroundColor3 = Color3.fromRGB(35, 190, 110)
			cargoLabel.Text = string.format("🎒 CARGO: %d / %d", backpack, maxCap)
			cargoLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
		end
	end

	-- Calculate true total multiplier display (Rebirth + Upgrades + Drones + Perks)
	if multLabel then
		local rebirthMult = (data.Rebirths or 0) * (Config.Rebirth.MultiplierPerRebirth or 0.75)
		local powerLvl = (data.Upgrades and data.Upgrades["ScrapPower"]) or 1
		local powerMult = (powerLvl - 1) * (Config.Upgrades.ScrapPower and Config.Upgrades.ScrapPower.EffectPerLevel or 0.20)
		local petMult = 0
		for _, p in ipairs(data.Pets or {}) do
			if p.Equipped then
				for _, t in ipairs(Config.Pets.List) do
					if t.Id == p.Id then
						petMult = petMult + t.Multiplier
						break
					end
				end
			end
		end
		local perkMult = 0
		if data.GearsPerks then
			if data.GearsPerks["ScrapSurge"] then perkMult = perkMult + 1.0 end
			if data.GearsPerks["QuantumDrone"] then perkMult = perkMult + 10.0 end
		end
		local totalMult = 1.0 + rebirthMult + powerMult + petMult + perkMult
		multLabel.Text = string.format("⚡ BOOST: %.1fx", totalMult)
	end

	-- Instant client-side gate collision disable for reached zones
	HUDController.updateGateBarriers(data.MaxZoneReached or 1)
end

function HUDController.updateGateBarriers(maxZone: number)
	local bridgesFolder = Workspace:FindFirstChild("Bridges")
	if not bridgesFolder then return end

	local totalZones = #Config.Zones
	for z = 2, totalZones do
		local gateModel = bridgesFolder:FindFirstChild("Gate_Zone" .. tostring(z))
		if gateModel then
			local barrier = gateModel:FindFirstChild("Forcefield") :: BasePart?
			local perimeterBarrier = gateModel:FindFirstChild("PerimeterForcefield") :: BasePart?
			local isUnlocked = (z <= maxZone)
			if barrier then
				barrier.CanCollide = not isUnlocked
				barrier.Transparency = isUnlocked and 1 or 0.35
			end
			if perimeterBarrier then
				perimeterBarrier.CanCollide = not isUnlocked
				perimeterBarrier.Transparency = isUnlocked and 1 or 0.92
			end
			for _, desc in ipairs(gateModel:GetDescendants()) do
				if desc:IsA("ProximityPrompt") then
					desc.Enabled = not isUnlocked
				end
			end
		end
	end
end

-- Spawn floating "+25 Scrap" text in 3D world with anti-overlap radial dispersal, sound, and juice
function HUDController.spawnRewardPopup(info: any)
	local worldPos = info.Position or Vector3.new(0, 10, 0)
	local isBreak = info.IsBreak == true or (info.CurrentHP ~= nil and info.CurrentHP <= 0)
	local isDense = info.IsDense == true

	-- Audio & Particle FX
	if isBreak then
		SoundController.playShatter(isDense, worldPos)
		VFXController.spawnShatterVFX(worldPos, isDense)
		VFXController.shakeCamera(0.55, 0.22, 1.2)
	else
		SoundController.playHit(isDense, worldPos)
		VFXController.spawnHitSparks(worldPos, isDense, info.TierColor)
		VFXController.shakeCamera(isDense and 0.16 or 0.10, isDense and 0.09 or 0.07, 0.8)
	end

	-- Visual Formatting
	local text: string
	local textColor: Color3
	if isBreak then
		if info.IsOrbital then
			text = string.format("POD SALVAGED\n+%s SCRAP | +%d GEARS\n[%d%% CONTRIBUTION]", formatNumber(info.ScrapEarned), info.GearsEarned or 1, info.DamagePercent or 100)
			textColor = Color3.fromRGB(255, 170, 20)
		elseif info.IsCrit then
			text = string.format("⚡ CRIT HARVEST! +%s SCRAP\n[%s]", formatNumber(info.ScrapEarned), info.TierName or "CRIT")
			textColor = Color3.fromRGB(255, 215, 0)
		elseif isDense then
			text = string.format("HARVESTED +%s SCRAP\n[%s]", formatNumber(info.ScrapEarned), info.TierName or "DENSE")
			textColor = Color3.fromRGB(0, 240, 255)
		else
			text = string.format("HARVESTED +%s SCRAP\n[%s]", formatNumber(info.ScrapEarned), info.TierName or "MAX")
			textColor = Color3.fromRGB(80, 240, 140)
		end
	elseif info.IsOrbital then
		text = string.format("-%d HP", info.DamageDealt or 1)
		textColor = Color3.fromRGB(255, 130, 20)
	elseif info.IsCrit then
		text = string.format("⚡ CRIT +%s", formatNumber(info.ScrapEarned))
		textColor = Color3.fromRGB(255, 215, 0)
	elseif isDense then
		text = string.format("+%s", formatNumber(info.ScrapEarned))
		textColor = Color3.fromRGB(0, 240, 255)
	else
		text = string.format("+%s", formatNumber(info.ScrapEarned))
		textColor = info.TierColor or Color3.fromRGB(255, 215, 0)
	end

	-- Notify Combo Streak UI
	if info.Combo and info.Combo >= 2 then
		HUDController.updateComboStreak(info.Combo)
	end

	-- Anti-overlap dispersal calculation
	local now = os.clock()
	local kept = {}
	for _, entry in ipairs(recentPopups) do
		if now - entry.Time < 0.90 then
			table.insert(kept, entry)
		end
	end
	recentPopups = kept

	local nearbyCount = 0
	for _, entry in ipairs(recentPopups) do
		if (entry.Pos - worldPos).Magnitude < 5.0 then
			nearbyCount = nearbyCount + 1
		end
	end

	table.insert(recentPopups, {
		Pos = worldPos,
		Time = now,
	})

	-- Radial spoke dispersal with vertical staggered elevation
	local spokeAngle = (nearbyCount * (math.pi / 2.7)) + (math.random() * 0.3 - 0.15)
	local horizontalDist = 1.0 + math.min(nearbyCount * 0.75, 3.2)
	local offsetX = math.cos(spokeAngle) * horizontalDist
	local offsetZ = math.sin(spokeAngle) * horizontalDist
	local startY = 1.0 + (nearbyCount * 0.8)
	if isBreak then
		startY = startY + 1.2
	end

	local startWorldPos = worldPos + Vector3.new(offsetX, startY, offsetZ)
	local riseAmount = isBreak and 5.5 or 4.2
	local endWorldPos = startWorldPos + Vector3.new(offsetX * 0.4, riseAmount, offsetZ * 0.4)

	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = startWorldPos
	attachment.Parent = Workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 80, 0, 24)
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 40
	billboard.Parent = mainGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = isBreak and 24 or (info.IsOrbital and 22 or 18)
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.1
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = text
	label.Parent = billboard

	local targetSize = isBreak and UDim2.new(0, 240, 0, 68) or UDim2.new(0, 180, 0, 50)
	local popTween = TweenService:Create(billboard, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = targetSize,
	})
	local floatTween = TweenService:Create(attachment, TweenInfo.new(1.0, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		WorldPosition = endWorldPos,
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	popTween:Play()
	floatTween:Play()
	task.delay(0.2, function()
		if label and label.Parent then
			fadeTween:Play()
		end
	end)

	floatTween.Completed:Connect(function()
		attachment:Destroy()
		billboard:Destroy()
	end)
end

function HUDController.init()
	HUDController.createHUD()

	-- Sync data event
	local syncEvent = Remotes.getEvent("SyncData")
	syncEvent.OnClientEvent:Connect(function(data)
		HUDController.updateCurrencies(data)
	end)

	-- Action completed event (popups, hit sparks, sound)
	local actionCompleted = Remotes.getEvent("ActionCompleted")
	actionCompleted.OnClientEvent:Connect(function(info)
		HUDController.spawnRewardPopup(info)
	end)

	-- Recycle completed event (golden geyser, cha-ching audio)
	local recycleCompleted = Remotes.getEvent("RecycleCompleted")
	recycleCompleted.OnClientEvent:Connect(function(info)
		SoundController.playRecycle(info.Position)
		VFXController.spawnRecycleVFX(info.Position, info.ScrapRecycled or 0, info.ScrapEarned or 0)
		VFXController.shakeCamera(0.28, 0.18, 0.9)
	end)

	-- Orbital Drop Pod incoming announcement and crash impact
	local orbitalAnnounce = Remotes.getEvent("OrbitalEventAnnounce")
	orbitalAnnounce.OnClientEvent:Connect(function(info)
		SoundController.playSuccess()
	end)

	local orbitalImpact = Remotes.getEvent("OrbitalEventImpact")
	orbitalImpact.OnClientEvent:Connect(function(info)
		if info and info.LandingPosition then
			VFXController.spawnShatterVFX(info.LandingPosition, true)
			SoundController.playShatter(true, info.LandingPosition)
			VFXController.shakeCamera(0.85, 0.35, 1.5)
		end
	end)

	-- Initial fetch
	local getFunction = Remotes.getFunction("GetPlayerData")
	task.spawn(function()
		local initialData = getFunction:InvokeServer()
		if initialData then
			HUDController.updateCurrencies(initialData)
		end
	end)

	-- Listen for dynamic Bridges creation
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Bridges" then
			task.wait(0.2)
			local data = getFunction:InvokeServer()
			if data then
				HUDController.updateGateBarriers(data.MaxZoneReached or 1)
			end
		end
	end)

	print("[HUDController] Initialized with audio feedback, camera shake, and particle juice.")
end

return HUDController
