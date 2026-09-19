--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Modules.Config)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)

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

local function playSound(soundId: string, pitch: number?, volume: number?)
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Pitch = pitch or 1.0
		sound.Volume = volume or 0.5
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
end

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
			cargoLabel.Text = string.format("🎒 FULL! (%d/%d) — RECYCLE AT HUB!", backpack, maxCap)
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
end

-- Spawn floating "+25 Scrap [Rare]" text in 3D world with sound and particle burst
function HUDController.spawnRewardPopup(info: any)
	local worldPos = info.Position or Vector3.new(0, 10, 0)
	local text = string.format("+%s Scrap\n[%s]", formatNumber(info.ScrapEarned), info.TierName)

	-- Play hit sound with pitch according to rarity
	playSound("rbxassetid://9114223175", info.SoundPitch or 1.0, 0.6)

	-- If Rare/Epic/Legendary/Mythic, also play chime
	if info.TierName ~= "Common" then
		playSound("rbxassetid://5153734608", 1.0 + (info.SoundPitch or 1.0) * 0.2, 0.4)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 180, 0, 50)
	billboard.StudsOffsetWorldSpace = worldPos
	billboard.AlwaysOnTop = true
	billboard.Parent = mainGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextColor3 = info.TierColor or Color3.fromRGB(255, 215, 0)
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = text
	label.Parent = billboard

	-- Float up and fade out
	local floatTween = TweenService:Create(billboard, TweenInfo.new(1.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = worldPos + Vector3.new(0, 6, 0),
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextSize = 28,
	})

	floatTween:Play()
	fadeTween:Play()

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

	-- Action completed event (popups)
	local actionCompleted = Remotes.getEvent("ActionCompleted")
	actionCompleted.OnClientEvent:Connect(function(info)
		HUDController.spawnRewardPopup(info)
	end)

	-- Initial fetch
	local getFunction = Remotes.getFunction("GetPlayerData")
	task.spawn(function()
		local initialData = getFunction:InvokeServer()
		if initialData then
			HUDController.updateCurrencies(initialData)
		end
	end)

	print("[HUDController] Initialized with audio feedback and popups.")
end

return HUDController
