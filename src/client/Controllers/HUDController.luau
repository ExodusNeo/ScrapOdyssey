--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local VFXController = require(script.Parent:WaitForChild("VFXController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

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
	mainGui.Parent = playerGui

	-- Top Left Currency Card (Banked Spendable Scrap & Gears)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0, 380, 0, 75)
	topBar.Position = UDim2.new(0, 24, 0, 24)
	topBar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	topBar.BackgroundTransparency = 0.15
	topBar.BorderSizePixel = 0
	topBar.Parent = mainGui

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 14)
	topCorner.Parent = topBar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(50, 60, 80)
	topStroke.Thickness = 2
	topStroke.Parent = topBar

	-- Banked Scrap Section (Left half)
	local scrapContainer = Instance.new("Frame")
	scrapContainer.Name = "ScrapContainer"
	scrapContainer.Size = UDim2.new(0.5, -12, 1, -12)
	scrapContainer.Position = UDim2.new(0, 10, 0, 6)
	scrapContainer.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
	scrapContainer.Parent = topBar

	local scCorner = Instance.new("UICorner")
	scCorner.CornerRadius = UDim.new(0, 10)
	scCorner.Parent = scrapContainer

	local scrapIcon = Instance.new("TextLabel")
	scrapIcon.Name = "Icon"
	scrapIcon.Size = UDim2.new(0, 36, 1, 0)
	scrapIcon.BackgroundTransparency = 1
	scrapIcon.Text = "🔩"
	scrapIcon.TextSize = 24
	scrapIcon.Parent = scrapContainer

	scrapLabel = Instance.new("TextLabel")
	scrapLabel.Name = "Value"
	scrapLabel.Size = UDim2.new(1, -40, 1, 0)
	scrapLabel.Position = UDim2.new(0, 38, 0, 0)
	scrapLabel.BackgroundTransparency = 1
	scrapLabel.Font = Enum.Font.GothamBlack
	scrapLabel.TextSize = 20
	scrapLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	scrapLabel.TextXAlignment = Enum.TextXAlignment.Left
	scrapLabel.Text = "0"
	scrapLabel.Parent = scrapContainer

	-- Gears Section (Right half)
	local gearsContainer = Instance.new("Frame")
	gearsContainer.Name = "GearsContainer"
	gearsContainer.Size = UDim2.new(0.5, -12, 1, -12)
	gearsContainer.Position = UDim2.new(0.5, 2, 0, 6)
	gearsContainer.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
	gearsContainer.Parent = topBar

	local gcCorner = Instance.new("UICorner")
	gcCorner.CornerRadius = UDim.new(0, 10)
	gcCorner.Parent = gearsContainer

	local gearsIcon = Instance.new("TextLabel")
	gearsIcon.Name = "Icon"
	gearsIcon.Size = UDim2.new(0, 36, 1, 0)
	gearsIcon.BackgroundTransparency = 1
	gearsIcon.Text = "⚙️"
	gearsIcon.TextSize = 24
	gearsIcon.Parent = gearsContainer

	gearsLabel = Instance.new("TextLabel")
	gearsLabel.Name = "Value"
	gearsLabel.Size = UDim2.new(1, -40, 1, 0)
	gearsLabel.Position = UDim2.new(0, 38, 0, 0)
	gearsLabel.BackgroundTransparency = 1
	gearsLabel.Font = Enum.Font.GothamBlack
	gearsLabel.TextSize = 20
	gearsLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
	gearsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gearsLabel.Text = "0"
	gearsLabel.Parent = gearsContainer

	-- Raw Cargo / Backpack Progress Bar
	local cargoContainer = Instance.new("Frame")
	cargoContainer.Name = "CargoContainer"
	cargoContainer.Size = UDim2.new(0, 380, 0, 34)
	cargoContainer.Position = UDim2.new(0, 24, 0, 106)
	cargoContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	cargoContainer.BackgroundTransparency = 0.15
	cargoContainer.BorderSizePixel = 0
	cargoContainer.ClipsDescendants = true
	cargoContainer.Parent = mainGui

	local ccCorner = Instance.new("UICorner")
	ccCorner.CornerRadius = UDim.new(0, 10)
	ccCorner.Parent = cargoContainer

	local ccStroke = Instance.new("UIStroke")
	ccStroke.Color = Color3.fromRGB(50, 60, 80)
	ccStroke.Thickness = 1.5
	ccStroke.Parent = cargoContainer

	cargoFill = Instance.new("Frame")
	cargoFill.Name = "CargoFill"
	cargoFill.Size = UDim2.new(0, 0, 1, 0)
	cargoFill.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
	cargoFill.BorderSizePixel = 0
	cargoFill.Parent = cargoContainer

	local cfCorner = Instance.new("UICorner")
	cfCorner.CornerRadius = UDim.new(0, 10)
	cfCorner.Parent = cargoFill

	cargoLabel = Instance.new("TextLabel")
	cargoLabel.Name = "CargoLabel"
	cargoLabel.Size = UDim2.new(1, -16, 1, 0)
	cargoLabel.Position = UDim2.new(0, 8, 0, 0)
	cargoLabel.BackgroundTransparency = 1
	cargoLabel.Font = Enum.Font.GothamBlack
	cargoLabel.TextSize = 13
	cargoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cargoLabel.TextStrokeTransparency = 0.2
	cargoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	cargoLabel.TextWrapped = true
	cargoLabel.Text = "🎒 CARGO: 0 / 50 🔩"
	cargoLabel.ZIndex = 2
	cargoLabel.Parent = cargoContainer

	-- Multiplier Badge below cargo bar
	local badge = Instance.new("Frame")
	badge.Name = "MultiplierBadge"
	badge.Size = UDim2.new(0, 150, 0, 28)
	badge.Position = UDim2.new(0, 24, 0, 148)
	badge.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	badge.BackgroundTransparency = 0.2
	badge.Parent = mainGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = badge

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(80, 140, 255)
	bStroke.Thickness = 1.5
	bStroke.Parent = badge

	multLabel = Instance.new("TextLabel")
	multLabel.Size = UDim2.new(1, 0, 1, 0)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 13
	multLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	multLabel.Text = "⚡ MULT: 1.0x"
	multLabel.Parent = badge
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
			cargoLabel.Text = string.format("🎒 FULL! (%d/%d) — RECYCLE AT DEPOSIT PAD!", backpack, maxCap)
			cargoLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
		elseif ratio >= 0.8 then
			cargoFill.BackgroundColor3 = Color3.fromRGB(255, 170, 30)
			cargoLabel.Text = string.format("🎒 CARGO: %d / %d 🔩", backpack, maxCap)
			cargoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			cargoFill.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
			cargoLabel.Text = string.format("🎒 CARGO: %d / %d 🔩", backpack, maxCap)
			cargoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	-- Calculate approx multiplier display
	if multLabel then
		local rebirthMult = 1 + (data.Rebirths * 0.5)
		multLabel.Text = string.format("⚡ MULT: %.1fx", rebirthMult)
	end

	-- Instant client-side gate collision disable for reached zones
	HUDController.updateGateBarriers(data.MaxZoneReached or 1)
end

function HUDController.updateGateBarriers(maxZone: number)
	local bridgesFolder = Workspace:FindFirstChild("Bridges")
	if not bridgesFolder then return end

	for z = 2, maxZone do
		local gateModel = bridgesFolder:FindFirstChild("Gate_Zone" .. tostring(z))
		if gateModel then
			local barrier = gateModel:FindFirstChild("Forcefield") :: BasePart?
			if barrier then
				barrier.CanCollide = false
				barrier.Transparency = 1
			end
			for _, desc in ipairs(gateModel:GetDescendants()) do
				if desc:IsA("ProximityPrompt") then
					desc.Enabled = false
				end
			end
		end
	end
end

-- Spawn floating "+25 Scrap" text in 3D world with sound, particles, and camera juice
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
			text = string.format("🚀 POD SALVAGED!\n+%s 🔩 | +%d ⚙️\n[%d%% DMG]", formatNumber(info.ScrapEarned), info.GearsEarned or 1, info.DamagePercent or 100)
			textColor = Color3.fromRGB(255, 170, 20)
		elseif isDense then
			text = string.format("💥 CLEARED! +%s 🔩\n[%s]", formatNumber(info.ScrapEarned), info.TierName or "DENSE")
			textColor = Color3.fromRGB(0, 240, 255)
		else
			text = string.format("💥 CLEARED! +%s 🔩\n[%s]", formatNumber(info.ScrapEarned), info.TierName or "MAX")
			textColor = Color3.fromRGB(80, 240, 140)
		end
	elseif info.IsOrbital then
		text = string.format("💥 -%d HP", info.DamageDealt or 1)
		textColor = Color3.fromRGB(255, 130, 20)
	elseif isDense then
		-- Clean dense scrap display: NO "CRIT" text or crit styling, just clean scrap number in dense cyan!
		text = string.format("+%s 🔩", formatNumber(info.ScrapEarned))
		textColor = Color3.fromRGB(0, 240, 255)
	else
		text = string.format("+%s 🔩", formatNumber(info.ScrapEarned))
		textColor = info.TierColor or Color3.fromRGB(255, 215, 0)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 30)
	billboard.StudsOffsetWorldSpace = worldPos
	billboard.AlwaysOnTop = true
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

	-- Punchy bounce scale + float
	local popTween = TweenService:Create(billboard, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 200, 0, 56),
	})
	local floatTween = TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = worldPos + Vector3.new(0, 5, 0),
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	popTween:Play()
	popTween.Completed:Connect(function()
		floatTween:Play()
		fadeTween:Play()
	end)

	fadeTween.Completed:Connect(function()
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
