--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local HUDController = {}

local mainGui: ScreenGui
local scrapLabel: TextLabel
local gearsLabel: TextLabel
local multiplierLabel: TextLabel
local currentScrap = 0
local currentGears = 0

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

	-- Top Bar Container (Left aligned or Center)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0, 360, 0, 70)
	topBar.Position = UDim2.new(0, 20, 0, 20)
	topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	topBar.BackgroundTransparency = 0.2
	topBar.BorderSizePixel = 0
	topBar.Parent = mainGui

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 12)
	topCorner.Parent = topBar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(60, 60, 70)
	topStroke.Thickness = 2
	topStroke.Parent = topBar

	-- Scrap Icon & Label
	local scrapContainer = Instance.new("Frame")
	scrapContainer.Name = "ScrapContainer"
	scrapContainer.Size = UDim2.new(0.5, -10, 1, -12)
	scrapContainer.Position = UDim2.new(0, 10, 0, 6)
	scrapContainer.BackgroundTransparency = 1
	scrapContainer.Parent = topBar

	local scrapIcon = Instance.new("TextLabel")
	scrapIcon.Name = "Icon"
	scrapIcon.Size = UDim2.new(0, 32, 1, 0)
	scrapIcon.BackgroundTransparency = 1
	scrapIcon.Text = "🔩"
	scrapIcon.TextSize = 24
	scrapIcon.Parent = scrapContainer

	scrapLabel = Instance.new("TextLabel")
	scrapLabel.Name = "Value"
	scrapLabel.Size = UDim2.new(1, -38, 1, 0)
	scrapLabel.Position = UDim2.new(0, 36, 0, 0)
	scrapLabel.BackgroundTransparency = 1
	scrapLabel.Font = Enum.Font.GothamBlack
	scrapLabel.TextSize = 20
	scrapLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	scrapLabel.TextXAlignment = Enum.TextXAlignment.Left
	scrapLabel.Text = "0"
	scrapLabel.Parent = scrapContainer

	-- Gears (Prestige) Icon & Label
	local gearsContainer = Instance.new("Frame")
	gearsContainer.Name = "GearsContainer"
	gearsContainer.Size = UDim2.new(0.5, -10, 1, -12)
	gearsContainer.Position = UDim2.new(0.5, 5, 0, 6)
	gearsContainer.BackgroundTransparency = 1
	gearsContainer.Parent = topBar

	local gearsIcon = Instance.new("TextLabel")
	gearsIcon.Name = "Icon"
	gearsIcon.Size = UDim2.new(0, 32, 1, 0)
	gearsIcon.BackgroundTransparency = 1
	gearsIcon.Text = "⚙️"
	gearsIcon.TextSize = 24
	gearsIcon.Parent = gearsContainer

	gearsLabel = Instance.new("TextLabel")
	gearsLabel.Name = "Value"
	gearsLabel.Size = UDim2.new(1, -38, 1, 0)
	gearsLabel.Position = UDim2.new(0, 36, 0, 0)
	gearsLabel.BackgroundTransparency = 1
	gearsLabel.Font = Enum.Font.GothamBlack
	gearsLabel.TextSize = 20
	gearsLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
	gearsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gearsLabel.Text = "0"
	gearsLabel.Parent = gearsContainer
end

function HUDController.updateCurrencies(data: Types.PlayerData)
	if not scrapLabel or not gearsLabel then return end

	local targetScrap = data.Scrap
	local targetGears = data.Gears

	-- Pop animation for scrap
	if targetScrap ~= currentScrap then
		currentScrap = targetScrap
		scrapLabel.Text = formatNumber(targetScrap)
		local tween = TweenService:Create(scrapLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			TextSize = 24,
		})
		tween:Play()
	end

	-- Pop animation for gears
	if targetGears ~= currentGears then
		currentGears = targetGears
		gearsLabel.Text = formatNumber(targetGears)
		local tween = TweenService:Create(gearsLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			TextSize = 24,
		})
		tween:Play()
	end
end

-- Spawn floating "+10 Scrap (Rare!)" text in 3D world
function HUDController.spawnRewardPopup(info: any)
	local worldPos = info.Position or Vector3.new(0, 10, 0)
	local text = string.format("+%s Scrap [%s]", formatNumber(info.ScrapEarned), info.TierName)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 45)
	billboard.StudsOffsetWorldSpace = worldPos
	billboard.AlwaysOnTop = true
	billboard.Parent = mainGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.TextColor3 = info.TierColor or Color3.fromRGB(255, 215, 0)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = text
	label.Parent = billboard

	-- Float up and fade out
	local floatTween = TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = worldPos + Vector3.new(0, 5, 0),
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
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

	print("[HUDController] Initialized.")
end

return HUDController
