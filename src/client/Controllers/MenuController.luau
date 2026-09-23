--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DroneVisuals = require(ReplicatedStorage.Modules.DroneVisuals)
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

local MenuController = {}

local mainGui: ScreenGui
local activePanel: Frame? = nil
local panels: { [string]: Frame } = {}
local currentData: Types.PlayerData? = nil

-- References for reactive updates
local upgradeRowRefs: { [string]: { LevelLabel: TextLabel, BuyButton: TextButton, Row: Frame } } = {}
local gearsPerkRowRefs: { [string]: { BuyButton: TextButton, StatusLabel: TextLabel } } = {}
local teleportRowRefs: { [number]: { WarpButton: TextButton, StatusLabel: TextLabel } } = {}
local petListScroll: ScrollingFrame
local currentDroneTab = "Hatch"
local switchDroneTabFn: ((string) -> ())? = nil
local lastRenderedPetsSignature = ""
local renderDroneInventoryFn: ((Types.PlayerData) -> ())? = nil
local eggCardRefs: { [string]: { Card: Frame, HatchBtn: TextButton, StatusLabel: TextLabel, CostLabel: TextLabel } } = {}
local myDronesTabBtnRef: TextButton? = nil
local rebirthInfoLabel: TextLabel
local rebirthButton: TextButton
local gearsShopHeaderLabel: TextLabel
local questRowRefs: { [string]: { Fill: Frame, Label: TextLabel, ClaimButton: TextButton } } = {}
local toolRowRefs: { [string]: { EquipButton: TextButton, Card: Frame } } = {}
local storeRowRefs: { [string]: { BuyButton: TextButton } } = {}
local dailyRewardBtnRef: TextButton? = nil
local dailyRewardSubLabelRef: TextLabel? = nil
local dailyDayCards: { [number]: { Frame: Frame, DayLabel: TextLabel, RewardLabel: TextLabel, Status: TextLabel, Stroke: UIStroke } } = {}

local function playSound(soundId: string, pitch: number?)
	if not SoundController.isSFXEnabled() then return end
	if soundId == "rbxassetid://6895079853" then
		SoundController.playUIClick()
	elseif soundId == "rbxassetid://5153734608" then
		SoundController.playSuccess()
	else
		SoundController.playUIClick()
	end
end

local function setupMusic()
	-- Centrally initialized and controlled via SoundController
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

-- Stacked Toast Notification System
local activeToasts: { Frame } = {}
local MAX_TOASTS = 3
local TOAST_HEIGHT = 72
local TOAST_SPACING = 10
local TOAST_TOP_MARGIN = 24
local lastToastMsg = ""
local lastToastTime = 0

local function updateToastPositions()
	for i, t in ipairs(activeToasts) do
		if t and t.Parent then
			local targetY = TOAST_TOP_MARGIN + (i - 1) * (TOAST_HEIGHT + TOAST_SPACING)
			TweenService:Create(t, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -240, 0, targetY),
			}):Play()
		end
	end
end

local function removeToast(t: Frame)
	local idx = table.find(activeToasts, t)
	if idx then
		table.remove(activeToasts, idx)
	end
	if t and t.Parent then
		local slideOut = TweenService:Create(t, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -240, 0, -100),
			BackgroundTransparency = 1,
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			t:Destroy()
		end)
	end
	updateToastPositions()
end

function MenuController.showNotification(title: string, message: string, color: Color3?)
	if not mainGui then
		local pGui = getPlayerGui()
		if pGui then
			mainGui = pGui:FindFirstChild("ScrapOdysseyHUD") :: ScreenGui
		end
	end
	if not mainGui then return end

	-- Debounce duplicate notifications within 1.2s to prevent spam overlap
	local now = os.clock()
	if message == lastToastMsg and (now - lastToastTime) < 1.2 then
		return
	end
	lastToastMsg = message
	lastToastTime = now

	playSound("rbxassetid://5153734608", 1.4)

	-- If at maximum active notifications, smoothly slide out the oldest
	while #activeToasts >= MAX_TOASTS do
		local oldest = table.remove(activeToasts, 1)
		if oldest and oldest.Parent then
			local pushOldest = TweenService:Create(oldest, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -240, 0, -100),
				BackgroundTransparency = 1,
			})
			pushOldest:Play()
			task.delay(0.2, function()
				if oldest and oldest.Parent then oldest:Destroy() end
			end)
		end
	end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 480, 0, TOAST_HEIGHT)
	toast.Position = UDim2.new(0.5, -240, 0, -100)
	toast.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	toast.BackgroundTransparency = 0.05
	toast.ZIndex = 99
	toast.Parent = mainGui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 12)
	tCorner.Parent = toast

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = color or Color3.fromRGB(255, 215, 0)
	tStroke.Thickness = 2
	tStroke.Parent = toast

	local tTitle = Instance.new("TextLabel")
	tTitle.Size = UDim2.new(1, -32, 0, 24)
	tTitle.Position = UDim2.new(0, 16, 0, 8)
	tTitle.BackgroundTransparency = 1
	tTitle.Font = Enum.Font.GothamBlack
	tTitle.TextSize = 15
	tTitle.TextColor3 = color or Color3.fromRGB(255, 215, 0)
	tTitle.TextXAlignment = Enum.TextXAlignment.Left
	tTitle.Text = title
	tTitle.ZIndex = 100
	tTitle.Parent = toast

	local tMsg = Instance.new("TextLabel")
	tMsg.Size = UDim2.new(1, -32, 0, 32)
	tMsg.Position = UDim2.new(0, 16, 0, 32)
	tMsg.BackgroundTransparency = 1
	tMsg.Font = Enum.Font.GothamMedium
	tMsg.TextSize = 13
	tMsg.TextColor3 = Color3.fromRGB(220, 225, 235)
	tMsg.TextXAlignment = Enum.TextXAlignment.Left
	tMsg.TextYAlignment = Enum.TextYAlignment.Top
	tMsg.TextWrapped = true
	tMsg.Text = message
	tMsg.ZIndex = 100
	tMsg.Parent = toast

	table.insert(activeToasts, toast)
	updateToastPositions()

	task.delay(3.5, function()
		removeToast(toast)
	end)
end

local function showToast(message: string, color: Color3?)
	MenuController.showNotification("NOTICE", message, color)
end
MenuController.showToast = showToast

local modalBackdrop: TextButton? = nil

local function getOrCreateBackdrop(): TextButton
	if not modalBackdrop then
		modalBackdrop = Instance.new("TextButton")
		modalBackdrop.Name = "ModalBackdrop"
		modalBackdrop.Size = UDim2.new(1, 0, 1, 0)
		modalBackdrop.Position = UDim2.new(0, 0, 0, 0)
		modalBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		modalBackdrop.BackgroundTransparency = 0.55
		modalBackdrop.Text = ""
		modalBackdrop.AutoButtonColor = false
		modalBackdrop.ZIndex = 18
		modalBackdrop.Visible = false
		modalBackdrop.Parent = mainGui

		-- Clicking outside the modal immediately closes it (touch and mouse compatible)
		modalBackdrop.Activated:Connect(function()
			playSound("rbxassetid://6895079853", 0.9)
			MenuController.closeActivePanel()
		end)
	end
	return modalBackdrop
end

local function createStyledPanel(titleText: string): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = titleText .. "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.new(0.85, 0, 0.82, 0)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 22
	panel.Parent = mainGui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(580, 520)
	sizeConstraint.MinSize = Vector2.new(340, 380)
	sizeConstraint.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(36, 46, 64)
	stroke.Thickness = 1
	stroke.Parent = panel

	local topAccent = Instance.new("Frame")
	topAccent.Name = "TopAccent"
	topAccent.Size = UDim2.new(1, 0, 0, 2)
	topAccent.BackgroundColor3 = Color3.fromRGB(240, 180, 50)
	topAccent.BorderSizePixel = 0
	topAccent.ZIndex = 23
	topAccent.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 54)
	header.BackgroundColor3 = Color3.fromRGB(15, 19, 28)
	header.BorderSizePixel = 0
	header.ZIndex = 23
	header.Parent = panel

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local headerLine = Instance.new("Frame")
	headerLine.Name = "HeaderLine"
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.new(0, 0, 1, -1)
	headerLine.BackgroundColor3 = Color3.fromRGB(32, 40, 56)
	headerLine.BorderSizePixel = 0
	headerLine.ZIndex = 24
	headerLine.Parent = header

	local titleTag = Instance.new("TextLabel")
	titleTag.Name = "CategoryTag"
	titleTag.Size = UDim2.new(1, -70, 0, 14)
	titleTag.Position = UDim2.new(0, 20, 0, 8)
	titleTag.BackgroundTransparency = 1
	titleTag.Font = Enum.Font.GothamBold
	titleTag.TextSize = 10
	titleTag.TextColor3 = Color3.fromRGB(120, 140, 170)
	titleTag.TextXAlignment = Enum.TextXAlignment.Left
	titleTag.Text = "SYSTEM CONSOLE"
	titleTag.ZIndex = 24
	titleTag.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -70, 0, 26)
	title.Position = UDim2.new(0, 20, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 17
	title.TextColor3 = Color3.fromRGB(245, 248, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.ZIndex = 24
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 13
	closeBtn.TextColor3 = Color3.fromRGB(180, 195, 215)
	closeBtn.Text = "X"
	closeBtn.ZIndex = 30
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 5)
	btnCorner.Parent = closeBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(45, 55, 75)
	btnStroke.Thickness = 1
	btnStroke.Parent = closeBtn

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(190, 45, 55),
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}):Play()
	end)

	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(22, 26, 36),
			TextColor3 = Color3.fromRGB(180, 195, 215),
		}):Play()
	end)

	closeBtn.Activated:Connect(function()
		playSound("rbxassetid://6895079853", 0.9)
		MenuController.closeActivePanel()
	end)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -32, 1, -74)
	body.Position = UDim2.new(0, 16, 0, 64)
	body.BackgroundTransparency = 1
	body.ZIndex = 23
	body.Parent = panel

	return panel, body
end

function MenuController.closeActivePanel()
	if activePanel then
		activePanel.Visible = false
		activePanel = nil
	end
	if modalBackdrop then
		modalBackdrop.Visible = false
	end
end

function MenuController.openPanel(name: string)
	local target = panels[name]
	if not target then return end

	playSound("rbxassetid://6895079853", 1.1)

	if activePanel == target then
		MenuController.closeActivePanel()
		return
	end

	if activePanel then
		activePanel.Visible = false
	end

	local backdrop = getOrCreateBackdrop()
	backdrop.Visible = true

	target.Visible = true
	activePanel = target

	if name == "Drones" then
		lastRenderedPetsSignature = ""
	end

	target.Size = UDim2.new(0.80, 0, 0.77, 0)
	local tween = TweenService:Create(target, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.85, 0, 0.82, 0),
	})
	tween:Play()

	if currentData then
		MenuController.updateUI(currentData)
	end
end

-- 1. Upgrades Panel Builder (Clean, uniform cards with icons)
function MenuController.buildUpgradesPanel()
	local panel, body = createStyledPanel("UPGRADES WORKSHOP")
	panels["Upgrades"] = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 200, 110)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.Parent = scroll

	local upgradeIcons = {
		ScrapPower = "⚡",
		ScrapSpeed = "⏱️",
		BackpackCapacity = "🎒",
	}

	for key, conf in pairs(Config.Upgrades) do
		local row = Instance.new("Frame")
		row.Name = key
		row.Size = UDim2.new(1, -6, 0, 95)
		row.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
		row.BorderSizePixel = 0
		row.ZIndex = 25
		row.Parent = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(45, 52, 70)
		stroke.Thickness = 1.5
		stroke.Parent = row

		-- Left Icon Box
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, 52, 0, 52)
		iconBox.Position = UDim2.new(0, 10, 0.5, -26)
		iconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		iconBox.BorderSizePixel = 0
		iconBox.ZIndex = 26
		iconBox.Parent = row

		local ibCorner = Instance.new("UICorner")
		ibCorner.CornerRadius = UDim.new(0, 10)
		ibCorner.Parent = iconBox

		local ibStroke = Instance.new("UIStroke")
		ibStroke.Color = Color3.fromRGB(60, 75, 100)
		ibStroke.Thickness = 1
		ibStroke.Parent = iconBox

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(1, 0, 1, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Font = Enum.Font.GothamBold
		iconLbl.TextSize = 24
		iconLbl.Text = upgradeIcons[key] or "⚙️"
		iconLbl.ZIndex = 27
		iconLbl.Parent = iconBox

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.65, -55, 0, 26)
		nameLabel.Position = UDim2.new(0, 70, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextSize = 17
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = conf.Name
		nameLabel.ZIndex = 26
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.65, -55, 0, 22)
		descLabel.Position = UDim2.new(0, 70, 0, 36)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 13
		descLabel.TextColor3 = Color3.fromRGB(170, 180, 200)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Text = conf.Description
		descLabel.ZIndex = 26
		descLabel.Parent = row

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(0.65, -55, 0, 22)
		levelLabel.Position = UDim2.new(0, 70, 0, 62)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextSize = 14
		levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		levelLabel.TextXAlignment = Enum.TextXAlignment.Left
		levelLabel.Text = "Level 1 / " .. tostring(conf.MaxLevel)
		levelLabel.ZIndex = 26
		levelLabel.Parent = row

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(0, 130, 0, 48)
		buyBtn.Position = UDim2.new(1, -145, 0.5, -24)
		buyBtn.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.TextSize = 15
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Text = "25 SCRAP"
		buyBtn.ZIndex = 26
		buyBtn.Parent = row

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = buyBtn

		buyBtn.Activated:Connect(function()
			playSound("rbxassetid://5153734608", 1.2)
			local purchaseRemote = Remotes.getEvent("PurchaseUpgrade")
			purchaseRemote:FireServer(key)
		end)

		upgradeRowRefs[key] = {
			LevelLabel = levelLabel,
			BuyButton = buyBtn,
			Row = row,
		}
	end
end

-- 2. Gears Prestige Shop Builder
function MenuController.buildGearsShopPanel()
	local panel, body = createStyledPanel("PRESTIGE WORKSHOP")
	panels["GearsShop"] = panel

	gearsShopHeaderLabel = Instance.new("TextLabel")
	gearsShopHeaderLabel.Name = "GearsBalance"
	gearsShopHeaderLabel.Size = UDim2.new(1, 0, 0, 30)
	gearsShopHeaderLabel.BackgroundTransparency = 1
	gearsShopHeaderLabel.Font = Enum.Font.GothamBlack
	gearsShopHeaderLabel.TextSize = 16
	gearsShopHeaderLabel.TextColor3 = Color3.fromRGB(80, 210, 255)
	gearsShopHeaderLabel.Text = "AVAILABLE: 0 GEARS (EARNED VIA REBIRTH)"
	gearsShopHeaderLabel.ZIndex = 24
	gearsShopHeaderLabel.Parent = body

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -40)
	scroll.Position = UDim2.new(0, 0, 0, 35)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 190, 255)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.Parent = scroll

	for perkId, perk in pairs(Config.GearsShop) do
		local row = Instance.new("Frame")
		row.Name = perkId
		row.Size = UDim2.new(1, -10, 0, 85)
		row.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
		row.BorderSizePixel = 0
		row.ZIndex = 25
		row.Parent = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(50, 140, 220)
		stroke.Thickness = 1.5
		stroke.Parent = row

		-- Left Icon Box
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, 48, 0, 48)
		iconBox.Position = UDim2.new(0, 10, 0.5, -24)
		iconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
		iconBox.BorderSizePixel = 0
		iconBox.ZIndex = 26
		iconBox.Parent = row

		local ibCorner = Instance.new("UICorner")
		ibCorner.CornerRadius = UDim.new(0, 8)
		ibCorner.Parent = iconBox

		local ibStroke = Instance.new("UIStroke")
		ibStroke.Color = Color3.fromRGB(50, 140, 220)
		ibStroke.Thickness = 1
		ibStroke.Parent = iconBox

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(1, 0, 1, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Font = Enum.Font.GothamBold
		iconLbl.TextSize = 24
		iconLbl.Text = perk.Icon or "⚙️"
		iconLbl.ZIndex = 27
		iconLbl.Parent = iconBox

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.6, -20, 0, 24)
		nameLbl.Position = UDim2.new(0, 68, 0, 10)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextSize = 15
		nameLbl.TextColor3 = Color3.fromRGB(80, 210, 255)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text = perk.Name
		nameLbl.ZIndex = 26
		nameLbl.Parent = row

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(0.6, -20, 0, 40)
		descLbl.Position = UDim2.new(0, 68, 0, 34)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.Gotham
		descLbl.TextSize = 12
		descLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextWrapped = true
		descLbl.Text = perk.Description
		descLbl.ZIndex = 26
		descLbl.Parent = row

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(0, 115, 0, 44)
		buyBtn.Position = UDim2.new(1, -125, 0.5, -22)
		buyBtn.BackgroundColor3 = Color3.fromRGB(30, 150, 220)
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.TextSize = 15
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Text = string.format("%d GEARS", perk.Cost)
		buyBtn.ZIndex = 26
		buyBtn.Parent = row

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = buyBtn

		buyBtn.Activated:Connect(function()
			playSound("rbxassetid://5153734608", 1.2)
			local purchasePerk = Remotes.getEvent("PurchaseGearsPerk")
			purchasePerk:FireServer(perkId)
		end)

		gearsPerkRowRefs[perkId] = {
			BuyButton = buyBtn,
			StatusLabel = nameLbl,
		}
	end
end

-- Cyber Store & Gamepasses Panel Builder
function MenuController.buildStorePanel()
	local panel, body = createStyledPanel("CYBER STORE & PASSES")
	panels["Store"] = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 255)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local uipadding = Instance.new("UIPadding")
	uipadding.PaddingTop = UDim.new(0, 6)
	uipadding.PaddingBottom = UDim.new(0, 24)
	uipadding.PaddingLeft = UDim.new(0, 6)
	uipadding.PaddingRight = UDim.new(0, 6)
	uipadding.Parent = scroll

	-- Section 1 Header: Permanent Gamepasses
	local sec1 = Instance.new("TextLabel")
	sec1.Size = UDim2.new(1, 0, 0, 26)
	sec1.BackgroundTransparency = 1
	sec1.Font = Enum.Font.GothamBold
	sec1.TextSize = 13
	sec1.TextColor3 = Color3.fromRGB(0, 220, 255)
	sec1.TextXAlignment = Enum.TextXAlignment.Left
	sec1.Text = "PERMANENT PASSES & CORE ENHANCEMENTS"
	sec1.LayoutOrder = 1
	sec1.ZIndex = 25
	sec1.Parent = scroll

	local details = (Config.Monetization and Config.Monetization.GamepassDetails) or {}
	local passesList = {
		{
			Key = "SuperSprint",
			Name = (details.SuperSprint and details.SuperSprint.Name) or "Hyper Thrusters",
			Desc = (details.SuperSprint and details.SuperSprint.Description) or "+8 Sprint Speed, +4 Walk Speed, and high-velocity warp FOV!",
			Price = (details.SuperSprint and details.SuperSprint.Price) or 149,
			Icon = (details.SuperSprint and details.SuperSprint.Icon) or "⚡",
			Color = (details.SuperSprint and details.SuperSprint.Color) or Color3.fromRGB(0, 220, 255),
		},
		{
			Key = "DoubleScrap",
			Name = (details.DoubleScrap and details.DoubleScrap.Name) or "2x Scrap Multiplier",
			Desc = (details.DoubleScrap and details.DoubleScrap.Description) or "Permanently doubles all scrap collected from dismantling scrap nodes.",
			Price = (details.DoubleScrap and details.DoubleScrap.Price) or 199,
			Icon = (details.DoubleScrap and details.DoubleScrap.Icon) or "💰",
			Color = (details.DoubleScrap and details.DoubleScrap.Color) or Color3.fromRGB(255, 200, 40),
		},
		{
			Key = "AutoScrap",
			Name = (details.AutoScrap and details.AutoScrap.Name) or "Auto-Scrapper Protocol",
			Desc = (details.AutoScrap and details.AutoScrap.Description) or "Hands-free continuous dismantling without clicking.",
			Price = (details.AutoScrap and details.AutoScrap.Price) or 299,
			Icon = (details.AutoScrap and details.AutoScrap.Icon) or "⚙️",
			ImageId = (details.AutoScrap and details.AutoScrap.ImageId) or "rbxassetid://10709775087",
			Color = (details.AutoScrap and details.AutoScrap.Color) or Color3.fromRGB(80, 220, 120),
		},
		{
			Key = "DoubleLuck",
			Name = (details.DoubleLuck and details.DoubleLuck.Name) or "Quantum Luck Core",
			Desc = (details.DoubleLuck and details.DoubleLuck.Description) or "Doubles the chance of hatching Rare, Epic, and Mythic companion drones!",
			Price = (details.DoubleLuck and details.DoubleLuck.Price) or 399,
			Icon = (details.DoubleLuck and details.DoubleLuck.Icon) or "🍀",
			Color = (details.DoubleLuck and details.DoubleLuck.Color) or Color3.fromRGB(180, 70, 255),
		},
	}

	for _, item in ipairs(passesList) do
		local card = Instance.new("Frame")
		card.Name = item.Key .. "Card"
		card.Size = UDim2.new(1, -6, 0, 72)
		card.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		card.BorderSizePixel = 0
		card.ZIndex = 25
		card.Parent = scroll

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 8)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = item.Color
		cStroke.Thickness = 1.2
		cStroke.Parent = card

		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, 42, 0, 42)
		iconBox.Position = UDim2.new(0, 10, 0.5, -21)
		iconBox.BackgroundColor3 = item.Color
		iconBox.BackgroundTransparency = 0.85
		iconBox.ZIndex = 26
		iconBox.Parent = card

		local ibCorner = Instance.new("UICorner")
		ibCorner.CornerRadius = UDim.new(0, 6)
		ibCorner.Parent = iconBox

		if item.ImageId then
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(0, 26, 0, 26)
			img.Position = UDim2.new(0.5, 0, 0.5, 0)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.BackgroundTransparency = 1
			img.Image = item.ImageId
			img.ImageColor3 = item.Color
			img.ZIndex = 27
			img.Parent = iconBox
		else
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(1, 0, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Font = Enum.Font.GothamBlack
			iconLabel.TextSize = 20
			iconLabel.Text = item.Icon
			iconLabel.ZIndex = 27
			iconLabel.Parent = iconBox
		end

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -210, 0, 20)
		titleLabel.Position = UDim2.new(0, 60, 0, 8)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 14
		titleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Text = item.Name
		titleLabel.ZIndex = 26
		titleLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -210, 0, 18)
		descLabel.Position = UDim2.new(0, 60, 0, 28)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.GothamMedium
		descLabel.TextSize = 11
		descLabel.TextColor3 = Color3.fromRGB(150, 165, 185)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextTruncate = Enum.TextTruncate.AtEnd
		descLabel.Text = item.Desc
		descLabel.ZIndex = 26
		descLabel.Parent = card

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(0, 120, 0, 36)
		buyBtn.Position = UDim2.new(1, -128, 0.5, -18)
		buyBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextSize = 12
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.Text = string.format("R$ %d", item.Price)
		buyBtn.AutoButtonColor = true
		buyBtn.ZIndex = 27
		buyBtn.Parent = card

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = buyBtn

		storeRowRefs[item.Key] = { BuyButton = buyBtn }

		buyBtn.MouseButton1Click:Connect(function()
			playSound("rbxassetid://6895079853", 1.0)
			local promptEv = Remotes.getEvent("PromptGamepass")
			promptEv:FireServer(item.Key)
		end)
	end

	-- Section 2 Header: Instant Currency Drops
	local sec2 = Instance.new("TextLabel")
	sec2.Size = UDim2.new(1, 0, 0, 26)
	sec2.BackgroundTransparency = 1
	sec2.Font = Enum.Font.GothamBold
	sec2.TextSize = 13
	sec2.TextColor3 = Color3.fromRGB(255, 200, 40)
	sec2.TextXAlignment = Enum.TextXAlignment.Left
	sec2.Text = "INSTANT RESOURCE CRATES (DEV PRODUCTS)"
	sec2.LayoutOrder = 30
	sec2.ZIndex = 25
	sec2.Parent = scroll

	local productsList = {
		{
			Key = "ScrapPackSmall",
			Name = "Emergency Scrap Supply",
			Desc = "+10,000 instant Scrap dropped directly into your account.",
			Price = 49,
			Icon = "📦",
			Color = Color3.fromRGB(255, 180, 40),
		},
		{
			Key = "ScrapPackMedium",
			Name = "Industrial Scrap Vault",
			Desc = "+100,000 instant Scrap for high-tier upgrades and eggs.",
			Price = 199,
			Icon = "💎",
			Color = Color3.fromRGB(255, 140, 20),
		},
		{
			Key = "GearsPack",
			Name = "Prestige Gear Cache",
			Desc = "+25 Prestige Gears to unlock permanent high-tier perks immediately.",
			Price = 99,
			Icon = "⚙️",
			Color = Color3.fromRGB(60, 190, 255),
		},
	}

	for idx, prod in ipairs(productsList) do
		local card = Instance.new("Frame")
		card.Name = "ProductItem_" .. prod.Key
		card.Size = UDim2.new(1, -8, 0, 56)
		card.BackgroundColor3 = Color3.fromRGB(15, 19, 28)
		card.LayoutOrder = 40 + idx
		card.ZIndex = 25
		card.Parent = scroll

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 8)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(32, 40, 56)
		cStroke.Thickness = 1
		cStroke.Parent = card

		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, 42, 0, 42)
		iconBox.Position = UDim2.new(0, 8, 0.5, -21)
		iconBox.BackgroundColor3 = prod.Color
		iconBox.BackgroundTransparency = 0.85
		iconBox.ZIndex = 26
		iconBox.Parent = card

		local ibCorner = Instance.new("UICorner")
		ibCorner.CornerRadius = UDim.new(0, 6)
		ibCorner.Parent = iconBox

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 1, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBlack
		iconLabel.TextSize = 20
		iconLabel.Text = prod.Icon
		iconLabel.ZIndex = 27
		iconLabel.Parent = iconBox

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -210, 0, 20)
		titleLabel.Position = UDim2.new(0, 60, 0, 8)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 14
		titleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Text = prod.Name
		titleLabel.ZIndex = 26
		titleLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -210, 0, 18)
		descLabel.Position = UDim2.new(0, 60, 0, 28)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.GothamMedium
		descLabel.TextSize = 11
		descLabel.TextColor3 = Color3.fromRGB(150, 165, 185)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextTruncate = Enum.TextTruncate.AtEnd
		descLabel.Text = prod.Desc
		descLabel.ZIndex = 26
		descLabel.Parent = card

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(0, 120, 0, 36)
		buyBtn.Position = UDim2.new(1, -128, 0.5, -18)
		buyBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextSize = 12
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.Text = string.format("R$ %d", prod.Price)
		buyBtn.AutoButtonColor = true
		buyBtn.ZIndex = 27
		buyBtn.Parent = card

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			playSound("rbxassetid://6895079853", 1.0)
			local promptEv = Remotes.getEvent("PromptProduct")
			promptEv:FireServer(prod.Key)
		end)
	end
end

-- 3. Drones Panel Builder
function MenuController.buildDronesPanel()
	local panel, body = createStyledPanel("DRONE HANGAR")
	panels["Drones"] = panel

	-- Sub-tab navigation bar (Hatch / Buy vs My Drones)
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Position = UDim2.new(0, 0, 0, 0)
	tabBar.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	tabBar.BorderSizePixel = 0
	tabBar.ZIndex = 24
	tabBar.Parent = body

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 8)
	tbCorner.Parent = tabBar

	local tbStroke = Instance.new("UIStroke")
	tbStroke.Color = Color3.fromRGB(36, 46, 64)
	tbStroke.Thickness = 1
	tbStroke.Parent = tabBar

	local hatchTabBtn = Instance.new("TextButton")
	hatchTabBtn.Name = "HatchTabBtn"
	hatchTabBtn.Size = UDim2.new(0.5, -3, 1, -4)
	hatchTabBtn.Position = UDim2.new(0, 2, 0, 2)
	hatchTabBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 95)
	hatchTabBtn.Font = Enum.Font.GothamBold
	hatchTabBtn.TextSize = 12
	hatchTabBtn.TextColor3 = Color3.new(1, 1, 1)
	hatchTabBtn.Text = "HATCH CAPSULES (BUY)"
	hatchTabBtn.ZIndex = 25
	hatchTabBtn.AutoButtonColor = false
	hatchTabBtn.Parent = tabBar

	local htbCorner = Instance.new("UICorner")
	htbCorner.CornerRadius = UDim.new(0, 6)
	htbCorner.Parent = hatchTabBtn

	local myDronesTabBtn = Instance.new("TextButton")
	myDronesTabBtn.Name = "MyDronesTabBtn"
	myDronesTabBtn.Size = UDim2.new(0.5, -3, 1, -4)
	myDronesTabBtn.Position = UDim2.new(0.5, 1, 0, 2)
	myDronesTabBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	myDronesTabBtn.Font = Enum.Font.GothamBold
	myDronesTabBtn.TextSize = 12
	myDronesTabBtn.TextColor3 = Color3.fromRGB(150, 165, 190)
	myDronesTabBtn.Text = "MY DRONES (0/3)"
	myDronesTabBtn.ZIndex = 25
	myDronesTabBtn.AutoButtonColor = false
	myDronesTabBtn.Parent = tabBar
	myDronesTabBtnRef = myDronesTabBtn

	local mdtbCorner = Instance.new("UICorner")
	mdtbCorner.CornerRadius = UDim.new(0, 6)
	mdtbCorner.Parent = myDronesTabBtn

	-- 1. Hatch Capsules Container (Buy Section)
	local hatchScroll = Instance.new("ScrollingFrame")
	hatchScroll.Name = "HatchScroll"
	hatchScroll.Size = UDim2.new(1, 0, 1, -44)
	hatchScroll.Position = UDim2.new(0, 0, 0, 44)
	hatchScroll.BackgroundTransparency = 1
	hatchScroll.ScrollBarThickness = 6
	hatchScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 140, 180)
	hatchScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hatchScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	hatchScroll.ZIndex = 24
	hatchScroll.Visible = true
	hatchScroll.Parent = body

	local hatchList = Instance.new("UIListLayout")
	hatchList.Padding = UDim.new(0, 10)
	hatchList.Parent = hatchScroll

	-- 2. My Drones Container (Inventory Section)
	local invContainer = Instance.new("Frame")
	invContainer.Name = "InvContainer"
	invContainer.Size = UDim2.new(1, 0, 1, -44)
	invContainer.Position = UDim2.new(0, 0, 0, 44)
	invContainer.BackgroundTransparency = 1
	invContainer.ZIndex = 24
	invContainer.Visible = false
	invContainer.Parent = body

	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "InvTitle"
	invTitle.Size = UDim2.new(1, 0, 0, 24)
	invTitle.Position = UDim2.new(0, 0, 0, 0)
	invTitle.BackgroundTransparency = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 13
	invTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.Text = "YOUR DRONES (EQUIPPED: 0/3):"
	invTitle.ZIndex = 24
	invTitle.Parent = invContainer

	petListScroll = Instance.new("ScrollingFrame")
	petListScroll.Name = "PetList"
	petListScroll.Size = UDim2.new(1, 0, 1, -28)
	petListScroll.Position = UDim2.new(0, 0, 0, 28)
	petListScroll.BackgroundTransparency = 1
	petListScroll.ScrollBarThickness = 6
	petListScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 140, 180)
	petListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	petListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	petListScroll.ZIndex = 24
	petListScroll.Parent = invContainer

	local petListLayout = Instance.new("UIListLayout")
	petListLayout.Padding = UDim.new(0, 8)
	petListLayout.Parent = petListScroll

	local function switchDroneTab(tabName: string)
		currentDroneTab = tabName
		if tabName == "Hatch" then
			hatchScroll.Visible = true
			invContainer.Visible = false
			hatchTabBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 95)
			hatchTabBtn.TextColor3 = Color3.new(1, 1, 1)
			myDronesTabBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
			myDronesTabBtn.TextColor3 = Color3.fromRGB(150, 165, 190)
		else
			hatchScroll.Visible = false
			invContainer.Visible = true
			myDronesTabBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 95)
			myDronesTabBtn.TextColor3 = Color3.new(1, 1, 1)
			hatchTabBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
			hatchTabBtn.TextColor3 = Color3.fromRGB(150, 165, 190)
			if renderDroneInventoryFn and currentData then
				lastRenderedPetsSignature = ""
				renderDroneInventoryFn(currentData)
			end
		end
	end
	switchDroneTabFn = switchDroneTab

	hatchTabBtn.Activated:Connect(function()
		playSound("rbxassetid://6895079853", 1.0)
		switchDroneTab("Hatch")
	end)
	myDronesTabBtn.Activated:Connect(function()
		playSound("rbxassetid://6895079853", 1.0)
		switchDroneTab("Inventory")
	end)

	-- Populate the 5 Egg Capsule cards in hatchScroll
	local orderedEggs = { "RustEgg", "JunkyardEgg", "FoundryEgg", "CyberEgg", "VoidEgg" }
	for _, eggKey in ipairs(orderedEggs) do
		local eggConf = Config.Eggs[eggKey]
		if eggConf then
			local card = Instance.new("Frame")
			card.Name = eggKey .. "Card"
			card.Size = UDim2.new(1, -6, 0, 96)
			card.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
			card.BorderSizePixel = 0
			card.ZIndex = 25
			card.Parent = hatchScroll

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 10)
			cCorner.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = eggConf.Color
			cStroke.Thickness = 1.5
			cStroke.Parent = card

			-- 3D Egg Capsule Viewport Box (Rotating 3D Preview!)
			local vpBox = Instance.new("Frame")
			vpBox.Name = "ViewportBox"
			vpBox.Size = UDim2.new(0, 78, 0, 78)
			vpBox.Position = UDim2.new(0, 9, 0.5, -39)
			vpBox.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
			vpBox.BorderSizePixel = 0
			vpBox.ZIndex = 26
			vpBox.Parent = card

			local vpCorner = Instance.new("UICorner")
			vpCorner.CornerRadius = UDim.new(0, 8)
			vpCorner.Parent = vpBox

			local vpStroke = Instance.new("UIStroke")
			vpStroke.Color = eggConf.Color
			vpStroke.Thickness = 1
			vpStroke.Parent = vpBox

			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.new(1, 0, 1, 0)
			vp.BackgroundTransparency = 1
			vp.ZIndex = 27
			vp.Parent = vpBox
			DroneVisuals.setupEggViewport(vp, eggKey, { CamDist = 3.3, Spin = true })

			-- Egg Info (Name, Zone, Odds)
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.55, -8, 0, 22)
			nameLbl.Position = UDim2.new(0, 96, 0, 8)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextSize = 15
			nameLbl.TextColor3 = eggConf.Color
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Text = string.upper(eggConf.Name)
			nameLbl.ZIndex = 26
			nameLbl.Parent = card

			local statusLbl = Instance.new("TextLabel")
			statusLbl.Name = "StatusLabel"
			statusLbl.Size = UDim2.new(0.55, -8, 0, 16)
			statusLbl.Position = UDim2.new(0, 96, 0, 30)
			statusLbl.BackgroundTransparency = 1
			statusLbl.Font = Enum.Font.GothamBold
			statusLbl.TextSize = 11
			statusLbl.TextColor3 = Color3.fromRGB(50, 200, 100)
			statusLbl.TextXAlignment = Enum.TextXAlignment.Left
			statusLbl.Text = string.format("AVAILABLE • ZONE %d", eggConf.ZoneId or 1)
			statusLbl.ZIndex = 26
			statusLbl.Parent = card

			local oddsLbl = Instance.new("TextLabel")
			oddsLbl.Size = UDim2.new(0.55, -8, 0, 38)
			oddsLbl.Position = UDim2.new(0, 96, 0, 48)
			oddsLbl.BackgroundTransparency = 1
			oddsLbl.Font = Enum.Font.GothamMedium
			oddsLbl.TextSize = 11
			oddsLbl.TextColor3 = Color3.fromRGB(160, 175, 200)
			oddsLbl.TextXAlignment = Enum.TextXAlignment.Left
			oddsLbl.TextWrapped = true
			oddsLbl.Text = eggConf.SubText and string.gsub(eggConf.SubText, "\n", "  |  ") or ""
			oddsLbl.ZIndex = 26
			oddsLbl.Parent = card

			-- Right Action: Cost & Hatch Button
			local costLbl = Instance.new("TextLabel")
			costLbl.Name = "CostLabel"
			costLbl.Size = UDim2.new(0, 130, 0, 20)
			costLbl.Position = UDim2.new(1, -138, 0, 12)
			costLbl.BackgroundTransparency = 1
			costLbl.Font = Enum.Font.GothamBold
			costLbl.TextSize = 13
			costLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
			costLbl.TextXAlignment = Enum.TextXAlignment.Right
			costLbl.Text = string.format("%s SCRAP", formatNumber(eggConf.Cost))
			costLbl.ZIndex = 26
			costLbl.Parent = card

			local hatchBtn = Instance.new("TextButton")
			hatchBtn.Name = "HatchBtn"
			hatchBtn.Size = UDim2.new(0, 130, 0, 42)
			hatchBtn.Position = UDim2.new(1, -138, 0, 38)
			hatchBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
			hatchBtn.Font = Enum.Font.GothamBlack
			hatchBtn.TextSize = 13
			hatchBtn.TextColor3 = Color3.new(1, 1, 1)
			hatchBtn.Text = "HATCH"
			hatchBtn.ZIndex = 26
			hatchBtn.AutoButtonColor = false
			hatchBtn.Parent = card

			local hbCorner = Instance.new("UICorner")
			hbCorner.CornerRadius = UDim.new(0, 8)
			hbCorner.Parent = hatchBtn

			local capturedEggKey = eggKey
			hatchBtn.Activated:Connect(function()
				playSound("rbxassetid://6895079853", 1.2)
				local hatchRemote = Remotes.getEvent("HatchEgg")
				hatchRemote:FireServer(capturedEggKey)
			end)

			eggCardRefs[eggKey] = {
				Card = card,
				HatchBtn = hatchBtn,
				StatusLabel = statusLbl,
				CostLabel = costLbl,
			}
		end
	end
end

-- 4. Fast-Travel / World Map Panel Builder (Instant warp to any unlocked zone!)
function MenuController.buildTeleportPanel()
	local panel, body = createStyledPanel("SECTOR NAVIGATION")
	panels["Teleport"] = panel

	-- Quick Hub Warp Button (Sell Cargo Fast!)
	local hubWarpBtn = Instance.new("TextButton")
	hubWarpBtn.Name = "WarpHubButton"
	hubWarpBtn.Size = UDim2.new(1, 0, 0, 50)
	hubWarpBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 90)
	hubWarpBtn.Font = Enum.Font.GothamBlack
	hubWarpBtn.TextSize = 15
	hubWarpBtn.TextColor3 = Color3.new(1, 1, 1)
	hubWarpBtn.Text = "TRAVEL TO CENTRAL HUB"
	hubWarpBtn.ZIndex = 25
	hubWarpBtn.Parent = body

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 10)
	hCorner.Parent = hubWarpBtn

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = Color3.fromRGB(100, 255, 140)
	hStroke.Thickness = 1.5
	hStroke.Parent = hubWarpBtn

	hubWarpBtn.Activated:Connect(function()
		playSound("rbxassetid://6895079853", 1.2)
		local teleportRemote = Remotes.getEvent("TeleportZone")
		teleportRemote:FireServer(1)
		MenuController.closeActivePanel()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -64)
	scroll.Position = UDim2.new(0, 0, 0, 60)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 140, 180)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	for _, zone in ipairs(Config.Zones) do
		local row = Instance.new("Frame")
		row.Name = "ZoneRow_" .. tostring(zone.Id)
		row.Size = UDim2.new(1, -10, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
		row.BorderSizePixel = 0
		row.LayoutOrder = zone.Id
		row.ZIndex = 25
		row.Parent = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = zone.Color
		stroke.Thickness = 1.5
		stroke.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.62, 0, 0, 24)
		nameLbl.Position = UDim2.new(0, 14, 0, 10)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextSize = 15
		nameLbl.TextColor3 = zone.Color
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text = string.format("ZONE %d: %s", zone.Id, zone.Name:upper())
		nameLbl.ZIndex = 26
		nameLbl.Parent = row

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(0.62, 0, 0, 28)
		descLbl.Position = UDim2.new(0, 14, 0, 34)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.Gotham
		descLbl.TextSize = 12
		descLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.Text = string.format("Base Yield: %d Scrap | %s", zone.BaseYield, zone.Description)
		descLbl.ZIndex = 26
		descLbl.Parent = row

		local warpBtn = Instance.new("TextButton")
		warpBtn.Name = "WarpButton"
		warpBtn.Size = UDim2.new(0, 115, 0, 44)
		warpBtn.Position = UDim2.new(1, -125, 0.5, -22)
		warpBtn.BackgroundColor3 = (zone.Id == 1) and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(90, 95, 110)
		warpBtn.Font = Enum.Font.GothamBlack
		warpBtn.TextSize = 14
		warpBtn.TextColor3 = Color3.new(1, 1, 1)
		warpBtn.Text = (zone.Id == 1) and "TRAVEL" or string.format("LOCKED\n(%s SCRAP)", formatNumber(zone.UnlockCost))
		warpBtn.ZIndex = 26
		warpBtn.Parent = row

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = warpBtn

		local zId = zone.Id
		warpBtn.Activated:Connect(function()
			playSound("rbxassetid://6895079853", 1.2)
			local teleportRemote = Remotes.getEvent("TeleportZone")
			teleportRemote:FireServer(zId)
			MenuController.closeActivePanel()
		end)

		teleportRowRefs[zone.Id] = {
			WarpButton = warpBtn,
			StatusLabel = nameLbl,
		}
	end
end

-- 5. Rebirth Panel Builder
function MenuController.buildRebirthPanel()
	local panel, body = createStyledPanel("QUANTUM REBIRTH")
	panels["Rebirth"] = panel

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, 0, 0, 75)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextColor3 = Color3.fromRGB(200, 210, 230)
	desc.TextWrapped = true
	desc.Text = "PRESTIGE REBIRTH CONDITIONS:\n• RESETS: Scrap, Cargo, Regular Upgrades (to Tier 1), and Unlocked Sectors\n• PRESERVES: Gears, Drones, Prestige Perks, and Scrapper Tools\n• BONUS: Permanent +50% Scrap multiplier per Rebirth level"
	desc.ZIndex = 24
	desc.Parent = body

	local statFrame = Instance.new("Frame")
	statFrame.Size = UDim2.new(1, 0, 0, 130)
	statFrame.Position = UDim2.new(0, 0, 0, 96)
	statFrame.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	statFrame.BorderSizePixel = 0
	statFrame.ZIndex = 24
	statFrame.Parent = body

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 12)
	sCorner.Parent = statFrame

	rebirthInfoLabel = Instance.new("TextLabel")
	rebirthInfoLabel.Name = "RebirthInfoLabel"
	rebirthInfoLabel.Size = UDim2.new(1, -24, 1, -20)
	rebirthInfoLabel.Position = UDim2.new(0, 12, 0, 10)
	rebirthInfoLabel.BackgroundTransparency = 1
	rebirthInfoLabel.Font = Enum.Font.GothamBold
	rebirthInfoLabel.TextSize = 16
	rebirthInfoLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	rebirthInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthInfoLabel.Text = "Required Scrap: 100K\nReward: +1 Gears\nCurrent Multiplier: +0%"
	rebirthInfoLabel.ZIndex = 25
	rebirthInfoLabel.Parent = statFrame

	rebirthButton = Instance.new("TextButton")
	rebirthButton.Name = "RebirthButton"
	rebirthButton.Size = UDim2.new(1, 0, 0, 60)
	rebirthButton.Position = UDim2.new(0, 0, 0, 240)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
	rebirthButton.Font = Enum.Font.GothamBlack
	rebirthButton.TextSize = 18
	rebirthButton.TextColor3 = Color3.new(1, 1, 1)
	rebirthButton.Text = "QUANTUM REBIRTH"
	rebirthButton.ZIndex = 25
	rebirthButton.Parent = body

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 12)
	rCorner.Parent = rebirthButton

	rebirthButton.Activated:Connect(function()
		playSound("rbxassetid://743521656", 1.0)
		local rebirthRemote = Remotes.getEvent("RequestRebirth")
		rebirthRemote:FireServer()
	end)
end

-- 6. Rewards Panel Builder
function MenuController.buildRewardsPanel()
	local panel, body = createStyledPanel("REQUISITIONS & CODES")
	panels["Rewards"] = panel

	local dailySection = Instance.new("Frame")
	dailySection.Name = "DailySection"
	dailySection.Size = UDim2.new(1, 0, 0, 204)
	dailySection.Position = UDim2.new(0, 0, 0, 0)
	dailySection.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	dailySection.BorderSizePixel = 0
	dailySection.ZIndex = 24
	dailySection.Parent = body

	local dsCorner = Instance.new("UICorner")
	dsCorner.CornerRadius = UDim.new(0, 10)
	dsCorner.Parent = dailySection

	local dsStroke = Instance.new("UIStroke")
	dsStroke.Color = Color3.fromRGB(38, 48, 68)
	dsStroke.Thickness = 1
	dsStroke.Parent = dailySection

	local dTitle = Instance.new("TextLabel")
	dTitle.Name = "DailyTitle"
	dTitle.Size = UDim2.new(1, -24, 0, 22)
	dTitle.Position = UDim2.new(0, 12, 0, 8)
	dTitle.BackgroundTransparency = 1
	dTitle.Font = Enum.Font.GothamBlack
	dTitle.TextSize = 14
	dTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
	dTitle.TextXAlignment = Enum.TextXAlignment.Left
	dTitle.Text = "DAILY LOGIN STREAK REWARDS"
	dTitle.ZIndex = 25
	dTitle.Parent = dailySection

	local dSub = Instance.new("TextLabel")
	dSub.Name = "DailySub"
	dSub.Size = UDim2.new(1, -24, 0, 16)
	dSub.Position = UDim2.new(0, 12, 0, 28)
	dSub.BackgroundTransparency = 1
	dSub.Font = Enum.Font.GothamMedium
	dSub.TextSize = 11
	dSub.TextColor3 = Color3.fromRGB(140, 155, 180)
	dSub.TextXAlignment = Enum.TextXAlignment.Left
	dSub.Text = "Log in every day to claim escalating Scrap & rare Gears! Streak resets after 48h."
	dSub.ZIndex = 25
	dSub.Parent = dailySection
	dailyRewardSubLabelRef = dSub

	-- 7-Day Mini Cards Grid
	local cardsContainer = Instance.new("Frame")
	cardsContainer.Name = "CardsGrid"
	cardsContainer.Size = UDim2.new(1, -24, 0, 82)
	cardsContainer.Position = UDim2.new(0, 12, 0, 48)
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.ZIndex = 25
	cardsContainer.Parent = dailySection

	local cList = Instance.new("UIListLayout")
	cList.FillDirection = Enum.FillDirection.Horizontal
	cList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cList.VerticalAlignment = Enum.VerticalAlignment.Center
	cList.Padding = UDim.new(0, 4)
	cList.Parent = cardsContainer

	dailyDayCards = {}
	for day = 1, 7 do
		local rInfo = Config.DailyRewards[day]
		local card = Instance.new("Frame")
		card.Name = "Day" .. tostring(day)
		card.Size = UDim2.new(1 / 7, -4, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
		card.BorderSizePixel = 0
		card.ZIndex = 26
		card.Parent = cardsContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 6)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(45, 55, 75)
		cStroke.Thickness = 1
		cStroke.Parent = card

		local dayLbl = Instance.new("TextLabel")
		dayLbl.Size = UDim2.new(1, 0, 0, 16)
		dayLbl.Position = UDim2.new(0, 0, 0, 4)
		dayLbl.BackgroundTransparency = 1
		dayLbl.Font = Enum.Font.GothamBlack
		dayLbl.TextSize = 10
		dayLbl.TextColor3 = Color3.fromRGB(200, 215, 235)
		dayLbl.Text = "DAY " .. tostring(day)
		dayLbl.ZIndex = 27
		dayLbl.Parent = card

		local rewLbl = Instance.new("TextLabel")
		rewLbl.Size = UDim2.new(1, -4, 0, 32)
		rewLbl.Position = UDim2.new(0, 2, 0, 20)
		rewLbl.BackgroundTransparency = 1
		rewLbl.Font = Enum.Font.GothamBold
		rewLbl.TextSize = 10
		rewLbl.TextColor3 = (rInfo and rInfo.Type == "Gears") and Color3.fromRGB(70, 190, 255) or Color3.fromRGB(255, 215, 60)
		rewLbl.Text = rInfo and string.format("+%s\n%s", formatNumber(rInfo.Amount), (rInfo.Type == "Gears" and "GEAR" or "SCRAP")) or ""
		rewLbl.ZIndex = 27
		rewLbl.Parent = card

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(1, 0, 0, 14)
		statusLbl.Position = UDim2.new(0, 0, 1, -18)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.TextSize = 9
		statusLbl.TextColor3 = Color3.fromRGB(110, 125, 145)
		statusLbl.Text = "LOCKED"
		statusLbl.ZIndex = 27
		statusLbl.Parent = card

		dailyDayCards[day] = {
			Frame = card,
			DayLabel = dayLbl,
			RewardLabel = rewLbl,
			Status = statusLbl,
			Stroke = cStroke,
		}
	end

	-- Daily Claim Button
	local dailyBtn = Instance.new("TextButton")
	dailyBtn.Name = "DailyClaimBtn"
	dailyBtn.Size = UDim2.new(1, -24, 0, 48)
	dailyBtn.Position = UDim2.new(0, 12, 0, 144)
	dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	dailyBtn.Font = Enum.Font.GothamBlack
	dailyBtn.TextSize = 15
	dailyBtn.TextColor3 = Color3.new(1, 1, 1)
	dailyBtn.Text = "CLAIM DAILY REWARD"
	dailyBtn.AutoButtonColor = true
	dailyBtn.ZIndex = 26
	dailyBtn.Parent = dailySection
	dailyRewardBtnRef = dailyBtn

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 8)
	dCorner.Parent = dailyBtn

	dailyBtn.Activated:Connect(function()
		local now = os.time()
		local lastClaim = (currentData and currentData.LastDailyRewardClaim) or 0
		local COOLDOWN = 20 * 3600
		local elapsed = (lastClaim > 0) and (now - lastClaim) or (COOLDOWN + 1)

		if lastClaim > 0 and elapsed < COOLDOWN then
			local rem = COOLDOWN - elapsed
			local h = math.floor(rem / 3600)
			local m = math.floor((rem % 3600) / 60)
			local s = rem % 60
			playSound("rbxassetid://6895079853", 0.8)
			showToast(string.format("Daily reward on cooldown! Ready in %02d:%02d:%02d.", h, m, s), Color3.fromRGB(240, 90, 90))
			return
		end

		playSound("rbxassetid://5153734608", 1.3)
		local claimRemote = Remotes.getEvent("ClaimDailyReward")
		claimRemote:FireServer()
	end)

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 0, 220)
	divider.BackgroundColor3 = Color3.fromRGB(32, 40, 56)
	divider.BorderSizePixel = 0
	divider.ZIndex = 24
	divider.Parent = body

	-- Promo Codes Section
	local codeTitle = Instance.new("TextLabel")
	codeTitle.Size = UDim2.new(1, 0, 0, 20)
	codeTitle.Position = UDim2.new(0, 0, 0, 232)
	codeTitle.BackgroundTransparency = 1
	codeTitle.Font = Enum.Font.GothamBlack
	codeTitle.TextSize = 14
	codeTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
	codeTitle.TextXAlignment = Enum.TextXAlignment.Left
	codeTitle.Text = "PROMO CODE REDEMPTION"
	codeTitle.ZIndex = 24
	codeTitle.Parent = body

	local codeSub = Instance.new("TextLabel")
	codeSub.Size = UDim2.new(1, 0, 0, 16)
	codeSub.Position = UDim2.new(0, 0, 0, 254)
	codeSub.BackgroundTransparency = 1
	codeSub.Font = Enum.Font.GothamMedium
	codeSub.TextSize = 11
	codeSub.TextColor3 = Color3.fromRGB(140, 155, 180)
	codeSub.TextXAlignment = Enum.TextXAlignment.Left
	codeSub.Text = "Enter promo codes below: (RELEASE / SCRAPPER / GEARS)"
	codeSub.ZIndex = 24
	codeSub.Parent = body

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(0.70, -6, 0, 46)
	codeBox.Position = UDim2.new(0, 0, 0, 278)
	codeBox.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	codeBox.Font = Enum.Font.GothamBold
	codeBox.TextSize = 15
	codeBox.TextColor3 = Color3.new(1, 1, 1)
	codeBox.PlaceholderText = "Enter promo code..."
	codeBox.PlaceholderColor3 = Color3.fromRGB(100, 115, 135)
	codeBox.ClearTextOnFocus = false
	codeBox.ZIndex = 24
	codeBox.Parent = body

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = codeBox

	local cbStroke = Instance.new("UIStroke")
	cbStroke.Color = Color3.fromRGB(45, 55, 75)
	cbStroke.Thickness = 1
	cbStroke.Parent = codeBox

	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Size = UDim2.new(0.30, -2, 0, 46)
	redeemBtn.Position = UDim2.new(0.70, 8, 0, 278)
	redeemBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
	redeemBtn.Font = Enum.Font.GothamBlack
	redeemBtn.TextSize = 15
	redeemBtn.TextColor3 = Color3.new(1, 1, 1)
	redeemBtn.Text = "REDEEM"
	redeemBtn.ZIndex = 24
	redeemBtn.Parent = body

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 8)
	rbCorner.Parent = redeemBtn

	redeemBtn.Activated:Connect(function()
		local text = codeBox.Text
		if #text > 0 then
			playSound("rbxassetid://5153734608", 1.1)
			local redeemRemote = Remotes.getEvent("RedeemCode")
			redeemRemote:FireServer(text)
			codeBox.Text = ""
		end
	end)
end

-- 7. Daily Quests Panel Builder
function MenuController.buildQuestsPanel()
	local panel, body = createStyledPanel("DAILY OBJECTIVES")
	panels["Quests"] = panel

	local subheader = Instance.new("TextLabel")
	subheader.Size = UDim2.new(1, 0, 0, 24)
	subheader.BackgroundTransparency = 1
	subheader.Font = Enum.Font.GothamMedium
	subheader.TextSize = 13
	subheader.TextColor3 = Color3.fromRGB(160, 175, 195)
	subheader.Text = "Complete daily scrap objectives to earn bonus Scrap and rare Gears!"
	subheader.ZIndex = 24
	subheader.Parent = body

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "QuestsScroll"
	scroll.Size = UDim2.new(1, 0, 1, -34)
	scroll.Position = UDim2.new(0, 0, 0, 32)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 95, 125)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 14)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = scroll

	for _, quest in ipairs(Config.Quests) do
		local row = Instance.new("Frame")
		row.Name = quest.Id
		row.Size = UDim2.new(1, -10, 0, 95)
		row.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		row.BorderSizePixel = 0
		row.ZIndex = 25
		row.Parent = scroll

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 12)
		rCorner.Parent = row

		local rStroke = Instance.new("UIStroke")
		rStroke.Color = Color3.fromRGB(45, 55, 75)
		rStroke.Thickness = 1.5
		rStroke.Parent = row

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(0.60, 0, 0, 26)
		desc.Position = UDim2.new(0, 14, 0, 10)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamBlack
		desc.TextSize = 15
		desc.TextColor3 = Color3.new(1, 1, 1)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = quest.Description
		desc.ZIndex = 26
		desc.Parent = row

		local rewardBadge = Instance.new("TextLabel")
		rewardBadge.Size = UDim2.new(0.35, 0, 0, 26)
		rewardBadge.Position = UDim2.new(0.63, 0, 0, 10)
		rewardBadge.BackgroundTransparency = 1
		rewardBadge.Font = Enum.Font.GothamBold
		rewardBadge.TextSize = 14
		rewardBadge.TextColor3 = quest.RewardType == "Gears" and Color3.fromRGB(70, 180, 255) or Color3.fromRGB(255, 215, 0)
		rewardBadge.TextXAlignment = Enum.TextXAlignment.Right
		rewardBadge.Text = string.format("+%s %s", formatNumber(quest.RewardAmount), string.upper(quest.RewardType))
		rewardBadge.ZIndex = 26
		rewardBadge.Parent = row

		-- Progress Bar Background
		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0.60, 0, 0, 22)
		barBg.Position = UDim2.new(0, 14, 0, 52)
		barBg.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
		barBg.BorderSizePixel = 0
		barBg.ZIndex = 26
		barBg.Parent = row

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 6)
		barCorner.Parent = barBg

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
		fill.BorderSizePixel = 0
		fill.ZIndex = 27
		fill.Parent = barBg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 6)
		fillCorner.Parent = fill

		local progLabel = Instance.new("TextLabel")
		progLabel.Name = "ProgLabel"
		progLabel.Size = UDim2.new(1, 0, 1, 0)
		progLabel.BackgroundTransparency = 1
		progLabel.Font = Enum.Font.GothamBlack
		progLabel.TextSize = 11
		progLabel.TextColor3 = Color3.new(1, 1, 1)
		progLabel.Text = string.format("0 / %s", formatNumber(quest.Target))
		progLabel.ZIndex = 28
		progLabel.Parent = barBg

		local claimBtn = Instance.new("TextButton")
		claimBtn.Name = "ClaimButton"
		claimBtn.Size = UDim2.new(0.32, 0, 0, 36)
		claimBtn.Position = UDim2.new(0.66, 0, 0, 46)
		claimBtn.BackgroundColor3 = Color3.fromRGB(40, 48, 65)
		claimBtn.Font = Enum.Font.GothamBlack
		claimBtn.TextSize = 12
		claimBtn.TextColor3 = Color3.new(1, 1, 1)
		claimBtn.Text = "IN PROGRESS"
		claimBtn.ZIndex = 26
		claimBtn.Parent = row

		local cbCorner = Instance.new("UICorner")
		cbCorner.CornerRadius = UDim.new(0, 8)
		cbCorner.Parent = claimBtn

		local questId = quest.Id
		claimBtn.Activated:Connect(function()
			if currentData and currentData.Quests and currentData.Quests[questId] then
				local qState = currentData.Quests[questId]
				if qState.Completed and not qState.Claimed then
					playSound("rbxassetid://5153734608", 1.2)
					local claimRemote = Remotes.getEvent("ClaimQuest")
					claimRemote:FireServer(questId)
				end
			end
		end)

		questRowRefs[quest.Id] = {
			Fill = fill,
			Label = progLabel,
			ClaimButton = claimBtn,
		}
	end
end

-- 8. Settings & Social Panel Builder
function MenuController.buildSettingsPanel()
	local panel, body = createStyledPanel("SYSTEM SETTINGS")
	panels["Settings"] = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(160, 175, 195)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 14)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = scroll

	-- 1. Music Setting Card
	local musicCard = Instance.new("Frame")
	musicCard.Size = UDim2.new(1, -6, 0, 68)
	musicCard.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	musicCard.BorderSizePixel = 0
	musicCard.ZIndex = 25
	musicCard.Parent = scroll

	local mcCorner = Instance.new("UICorner")
	mcCorner.CornerRadius = UDim.new(0, 12)
	mcCorner.Parent = musicCard

	local mcStroke = Instance.new("UIStroke")
	mcStroke.Color = Color3.fromRGB(45, 55, 75)
	mcStroke.Thickness = 1.5
	mcStroke.Parent = musicCard

	local mIconBox = Instance.new("Frame")
	mIconBox.Size = UDim2.new(0, 44, 0, 44)
	mIconBox.Position = UDim2.new(0, 12, 0.5, -22)
	mIconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	mIconBox.BorderSizePixel = 0
	mIconBox.ZIndex = 26
	mIconBox.Parent = musicCard

	local micCorner = Instance.new("UICorner")
	micCorner.CornerRadius = UDim.new(0, 8)
	micCorner.Parent = mIconBox

	local mIcon = Instance.new("TextLabel")
	mIcon.Size = UDim2.new(1, 0, 1, 0)
	mIcon.BackgroundTransparency = 1
	mIcon.Font = Enum.Font.GothamBold
	mIcon.TextSize = 22
	mIcon.Text = "🎵"
	mIcon.ZIndex = 27
	mIcon.Parent = mIconBox

	local mTitle = Instance.new("TextLabel")
	mTitle.Size = UDim2.new(0.65, -50, 1, 0)
	mTitle.Position = UDim2.new(0, 66, 0, 0)
	mTitle.BackgroundTransparency = 1
	mTitle.Font = Enum.Font.GothamBold
	mTitle.TextSize = 16
	mTitle.TextColor3 = Color3.new(1, 1, 1)
	mTitle.TextXAlignment = Enum.TextXAlignment.Left
	mTitle.Text = "Background Music"
	mTitle.ZIndex = 26
	mTitle.Parent = musicCard

	local mToggle = Instance.new("TextButton")
	mToggle.Size = UDim2.new(0, 120, 0, 42)
	mToggle.Position = UDim2.new(1, -136, 0.5, -21)
	local isMusic = SoundController.isMusicEnabled()
	mToggle.BackgroundColor3 = isMusic and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 50, 50)
	mToggle.Font = Enum.Font.GothamBlack
	mToggle.TextSize = 14
	mToggle.TextColor3 = Color3.new(1, 1, 1)
	mToggle.Text = isMusic and "ENABLED" or "MUTED"
	mToggle.ZIndex = 26
	mToggle.Parent = musicCard

	local mtCorner = Instance.new("UICorner")
	mtCorner.CornerRadius = UDim.new(0, 8)
	mtCorner.Parent = mToggle

	mToggle.Activated:Connect(function()
		local on = SoundController.toggleMusic()
		mToggle.BackgroundColor3 = on and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 50, 50)
		mToggle.Text = on and "ENABLED" or "MUTED"
		SoundController.playUIClick()
	end)

	-- 2. SFX Setting Card
	local sfxCard = Instance.new("Frame")
	sfxCard.Size = UDim2.new(1, -6, 0, 68)
	sfxCard.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	sfxCard.BorderSizePixel = 0
	sfxCard.ZIndex = 25
	sfxCard.Parent = scroll

	local scCorner = Instance.new("UICorner")
	scCorner.CornerRadius = UDim.new(0, 12)
	scCorner.Parent = sfxCard

	local scStroke = Instance.new("UIStroke")
	scStroke.Color = Color3.fromRGB(45, 55, 75)
	scStroke.Thickness = 1.5
	scStroke.Parent = sfxCard

	local sIconBox = Instance.new("Frame")
	sIconBox.Size = UDim2.new(0, 44, 0, 44)
	sIconBox.Position = UDim2.new(0, 12, 0.5, -22)
	sIconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	sIconBox.BorderSizePixel = 0
	sIconBox.ZIndex = 26
	sIconBox.Parent = sfxCard

	local sicCorner = Instance.new("UICorner")
	sicCorner.CornerRadius = UDim.new(0, 8)
	sicCorner.Parent = sIconBox

	local sIcon = Instance.new("TextLabel")
	sIcon.Size = UDim2.new(1, 0, 1, 0)
	sIcon.BackgroundTransparency = 1
	sIcon.Font = Enum.Font.GothamBold
	sIcon.TextSize = 22
	sIcon.Text = "🔊"
	sIcon.ZIndex = 27
	sIcon.Parent = sIconBox

	local sTitle = Instance.new("TextLabel")
	sTitle.Size = UDim2.new(0.65, -50, 1, 0)
	sTitle.Position = UDim2.new(0, 66, 0, 0)
	sTitle.BackgroundTransparency = 1
	sTitle.Font = Enum.Font.GothamBold
	sTitle.TextSize = 16
	sTitle.TextColor3 = Color3.new(1, 1, 1)
	sTitle.TextXAlignment = Enum.TextXAlignment.Left
	sTitle.Text = "Sound Effects (SFX)"
	sTitle.ZIndex = 26
	sTitle.Parent = sfxCard

	local sToggle = Instance.new("TextButton")
	sToggle.Size = UDim2.new(0, 120, 0, 42)
	sToggle.Position = UDim2.new(1, -136, 0.5, -21)
	local isSFX = SoundController.isSFXEnabled()
	sToggle.BackgroundColor3 = isSFX and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 50, 50)
	sToggle.Font = Enum.Font.GothamBlack
	sToggle.TextSize = 14
	sToggle.TextColor3 = Color3.new(1, 1, 1)
	sToggle.Text = isSFX and "ENABLED" or "MUTED"
	sToggle.ZIndex = 26
	sToggle.Parent = sfxCard

	local stCorner = Instance.new("UICorner")
	stCorner.CornerRadius = UDim.new(0, 8)
	stCorner.Parent = sToggle

	sToggle.Activated:Connect(function()
		local on = SoundController.toggleSFX()
		sToggle.BackgroundColor3 = on and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 50, 50)
		sToggle.Text = on and "ENABLED" or "MUTED"
		SoundController.playUIClick()
	end)

	-- 3. Screen Shake & Camera Juice Setting Card
	local shakeCard = Instance.new("Frame")
	shakeCard.Size = UDim2.new(1, -6, 0, 68)
	shakeCard.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	shakeCard.BorderSizePixel = 0
	shakeCard.ZIndex = 25
	shakeCard.Parent = scroll

	local shkCorner = Instance.new("UICorner")
	shkCorner.CornerRadius = UDim.new(0, 12)
	shkCorner.Parent = shakeCard

	local shkStroke = Instance.new("UIStroke")
	shkStroke.Color = Color3.fromRGB(45, 55, 75)
	shkStroke.Thickness = 1.5
	shkStroke.Parent = shakeCard

	local shkIconBox = Instance.new("Frame")
	shkIconBox.Size = UDim2.new(0, 44, 0, 44)
	shkIconBox.Position = UDim2.new(0, 12, 0.5, -22)
	shkIconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	shkIconBox.BorderSizePixel = 0
	shkIconBox.ZIndex = 26
	shkIconBox.Parent = shakeCard

	local shkicCorner = Instance.new("UICorner")
	shkicCorner.CornerRadius = UDim.new(0, 8)
	shkicCorner.Parent = shkIconBox

	local shkIcon = Instance.new("TextLabel")
	shkIcon.Size = UDim2.new(1, 0, 1, 0)
	shkIcon.BackgroundTransparency = 1
	shkIcon.Font = Enum.Font.GothamBold
	shkIcon.TextSize = 22
	shkIcon.Text = "📳"
	shkIcon.ZIndex = 27
	shkIcon.Parent = shkIconBox

	local shkTitle = Instance.new("TextLabel")
	shkTitle.Size = UDim2.new(0.65, -50, 1, 0)
	shkTitle.Position = UDim2.new(0, 66, 0, 0)
	shkTitle.BackgroundTransparency = 1
	shkTitle.Font = Enum.Font.GothamBold
	shkTitle.TextSize = 16
	shkTitle.TextColor3 = Color3.new(1, 1, 1)
	shkTitle.TextXAlignment = Enum.TextXAlignment.Left
	shkTitle.Text = "Camera Shake Impact"
	shkTitle.ZIndex = 26
	shkTitle.Parent = shakeCard

	local shkToggle = Instance.new("TextButton")
	shkToggle.Size = UDim2.new(0, 120, 0, 42)
	shkToggle.Position = UDim2.new(1, -136, 0.5, -21)
	local isShake = VFXController.isScreenShakeEnabled()
	shkToggle.BackgroundColor3 = isShake and Color3.fromRGB(120, 55, 165) or Color3.fromRGB(45, 50, 60)
	shkToggle.Font = Enum.Font.GothamBlack
	shkToggle.TextSize = 14
	shkToggle.TextColor3 = Color3.new(1, 1, 1)
	shkToggle.Text = isShake and "ACTIVE" or "DISABLED"
	shkToggle.ZIndex = 26
	shkToggle.Parent = shakeCard

	local shktCorner = Instance.new("UICorner")
	shktCorner.CornerRadius = UDim.new(0, 8)
	shktCorner.Parent = shkToggle

	shkToggle.Activated:Connect(function()
		local on = VFXController.toggleScreenShake()
		shkToggle.BackgroundColor3 = on and Color3.fromRGB(120, 55, 165) or Color3.fromRGB(45, 50, 60)
		shkToggle.Text = on and "ACTIVE" or "DISABLED"
		SoundController.playUIClick()
	end)

	-- 4. Social & Trading Card (Notepad Phase 6 Stub)
	local tradeCard = Instance.new("Frame")
	tradeCard.Size = UDim2.new(1, -6, 0, 80)
	tradeCard.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	tradeCard.BorderSizePixel = 0
	tradeCard.ZIndex = 25
	tradeCard.Parent = scroll

	local tcCorner = Instance.new("UICorner")
	tcCorner.CornerRadius = UDim.new(0, 12)
	tcCorner.Parent = tradeCard

	local tcStroke = Instance.new("UIStroke")
	tcStroke.Color = Color3.fromRGB(45, 55, 75)
	tcStroke.Thickness = 1.5
	tcStroke.Parent = tradeCard

	local tIconBox = Instance.new("Frame")
	tIconBox.Size = UDim2.new(0, 44, 0, 44)
	tIconBox.Position = UDim2.new(0, 12, 0.5, -22)
	tIconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	tIconBox.BorderSizePixel = 0
	tIconBox.ZIndex = 26
	tIconBox.Parent = tradeCard

	local ticCorner = Instance.new("UICorner")
	ticCorner.CornerRadius = UDim.new(0, 8)
	ticCorner.Parent = tIconBox

	local tIcon = Instance.new("TextLabel")
	tIcon.Size = UDim2.new(1, 0, 1, 0)
	tIcon.BackgroundTransparency = 1
	tIcon.Font = Enum.Font.GothamBold
	tIcon.TextSize = 22
	tIcon.Text = "🤝"
	tIcon.ZIndex = 27
	tIcon.Parent = tIconBox

	local tTitle = Instance.new("TextLabel")
	tTitle.Size = UDim2.new(1, -70, 0, 24)
	tTitle.Position = UDim2.new(0, 66, 0, 14)
	tTitle.BackgroundTransparency = 1
	tTitle.Font = Enum.Font.GothamBlack
	tTitle.TextSize = 15
	tTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	tTitle.TextXAlignment = Enum.TextXAlignment.Left
	tTitle.Text = "Player Trading Hub"
	tTitle.ZIndex = 26
	tTitle.Parent = tradeCard

	local tDesc = Instance.new("TextLabel")
	tDesc.Size = UDim2.new(1, -75, 0, 32)
	tDesc.Position = UDim2.new(0, 66, 0, 38)
	tDesc.BackgroundTransparency = 1
	tDesc.Font = Enum.Font.GothamMedium
	tDesc.TextSize = 12
	tDesc.TextColor3 = Color3.fromRGB(160, 175, 195)
	tDesc.TextXAlignment = Enum.TextXAlignment.Left
	tDesc.TextWrapped = true
	tDesc.Text = "COMING SOON: Secure two-player trade verification for scrap, parts, and companion drones."
	tDesc.ZIndex = 26
	tDesc.Parent = tradeCard
end

function MenuController.buildToolArmoryPanel()
	local panel, body = createStyledPanel("TOOL ARMORY")
	panels["ToolArmory"] = panel

	local subBanner = Instance.new("Frame")
	subBanner.Size = UDim2.new(1, 0, 0, 36)
	subBanner.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	subBanner.BorderSizePixel = 0
	subBanner.ZIndex = 24
	subBanner.Parent = body

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(0, 10)
	sbCorner.Parent = subBanner

	local bannerText = Instance.new("TextLabel")
	bannerText.Size = UDim2.new(1, -20, 1, 0)
	bannerText.Position = UDim2.new(0, 10, 0, 0)
	bannerText.BackgroundTransparency = 1
	bannerText.Font = Enum.Font.GothamBold
	bannerText.TextSize = 12
	bannerText.TextColor3 = Color3.fromRGB(255, 180, 50)
	bannerText.Text = "Forge higher-tier tools to increase hit damage, reach, and swing speed!"
	bannerText.ZIndex = 25
	bannerText.Parent = subBanner

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -44)
	scroll.Position = UDim2.new(0, 0, 0, 44)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 140, 40)
	scroll.CanvasSize = UDim2.new(0, 0, 0, #Config.Tools * 74 + 16)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local uipadding = Instance.new("UIPadding")
	uipadding.PaddingTop = UDim.new(0, 4)
	uipadding.PaddingBottom = UDim.new(0, 12)
	uipadding.PaddingLeft = UDim.new(0, 4)
	uipadding.PaddingRight = UDim.new(0, 4)
	uipadding.Parent = scroll

	for idx, tool in ipairs(Config.Tools) do
		local card = Instance.new("Frame")
		card.Name = "ToolCard_" .. tool.Id
		card.Size = UDim2.new(1, -6, 0, 68)
		card.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
		card.BorderSizePixel = 0
		card.LayoutOrder = idx
		card.ZIndex = 25
		card.Parent = scroll

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 12)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(45, 52, 68)
		cStroke.Thickness = 1.4
		cStroke.Parent = card

		-- Left Emoji Icon Box
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, 52, 0, 52)
		iconBox.Position = UDim2.new(0, 8, 0.5, -26)
		iconBox.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
		iconBox.ZIndex = 26
		iconBox.Parent = card

		local ibCorner = Instance.new("UICorner")
		ibCorner.CornerRadius = UDim.new(0, 10)
		ibCorner.Parent = iconBox

		local ibStroke = Instance.new("UIStroke")
		ibStroke.Color = tool.Color
		ibStroke.Thickness = 1.5
		ibStroke.Parent = iconBox

		local emojiLbl = Instance.new("TextLabel")
		emojiLbl.Size = UDim2.new(1, 0, 1, 0)
		emojiLbl.BackgroundTransparency = 1
		emojiLbl.Font = Enum.Font.GothamBlack
		emojiLbl.TextSize = 26
		emojiLbl.Text = tool.Emoji
		emojiLbl.ZIndex = 27
		emojiLbl.Parent = iconBox

		-- Name & Tier
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -220, 0, 22)
		nameLbl.Position = UDim2.new(0, 68, 0, 6)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextSize = 14
		nameLbl.TextColor3 = tool.Color
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text = string.format("%s (Tier %d)", tool.Name, tool.Tier)
		nameLbl.ZIndex = 26
		nameLbl.Parent = card

		-- Stats Row
		local statsLbl = Instance.new("TextLabel")
		statsLbl.Size = UDim2.new(1, -220, 0, 18)
		statsLbl.Position = UDim2.new(0, 68, 0, 26)
		statsLbl.BackgroundTransparency = 1
		statsLbl.Font = Enum.Font.GothamBold
		statsLbl.TextSize = 12
		statsLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
		statsLbl.TextXAlignment = Enum.TextXAlignment.Left
		statsLbl.Text = string.format("DMG: %d   SPD: %.2fs   RNG: %d Studs", tool.Damage, tool.Cooldown, tool.Range)
		statsLbl.ZIndex = 26
		statsLbl.Parent = card

		-- Description
		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(1, -220, 0, 16)
		descLbl.Position = UDim2.new(0, 68, 0, 44)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.GothamMedium
		descLbl.TextSize = 11
		descLbl.TextColor3 = Color3.fromRGB(150, 165, 185)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextTruncate = Enum.TextTruncate.AtEnd
		descLbl.Text = tool.Description
		descLbl.ZIndex = 26
		descLbl.Parent = card

		-- Action Button (BUY / EQUIP / EQUIPPED)
		local actionBtn = Instance.new("TextButton")
		actionBtn.Name = "ActionBtn"
		actionBtn.Size = UDim2.new(0, 135, 0, 40)
		actionBtn.Position = UDim2.new(1, -145, 0.5, -20)
		actionBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
		actionBtn.Font = Enum.Font.GothamBlack
		actionBtn.TextSize = 13
		actionBtn.TextColor3 = Color3.new(1, 1, 1)
		actionBtn.Text = tool.Cost == 0 and "EQUIPPED" or string.format("BUY (%s SCRAP)", formatNumber(tool.Cost))
		actionBtn.ZIndex = 26
		actionBtn.Parent = card

		local abCorner = Instance.new("UICorner")
		abCorner.CornerRadius = UDim.new(0, 10)
		abCorner.Parent = actionBtn

		actionBtn.Activated:Connect(function()
			if not currentData then return end
			local isOwned = (currentData.OwnedTools and currentData.OwnedTools[tool.Id]) or (tool.Cost == 0)

			playSound("rbxassetid://6895079853", 1.2)
			if isOwned then
				local equipEvent = Remotes.getEvent("EquipTool")
				equipEvent:FireServer(tool.Id)
				showToast(string.format("Equipped %s (%s)!", tool.Name, tool.Emoji), tool.Color)
			else
				if (currentData.Scrap or 0) < tool.Cost then
					local diff = tool.Cost - (currentData.Scrap or 0)
					showToast(string.format("Need %s more Scrap to forge %s!", formatNumber(diff), tool.Name), Color3.fromRGB(255, 75, 75))
				else
					local buyEvent = Remotes.getEvent("PurchaseTool")
					buyEvent:FireServer(tool.Id)
				end
			end
		end)

		toolRowRefs[tool.Id] = {
			EquipButton = actionBtn,
			Card = card,
		}
	end
end

function MenuController.buildDebugPanel()
	local isDev = RunService:IsStudio() or player.Name == "ExodusNeo" or (game.CreatorId ~= 0 and player.UserId == game.CreatorId)
	if not isDev then return end

	local panel, body = createStyledPanel("DEVELOPER CONSOLE")
	panels["Debug"] = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 65, 100)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 24
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local uipadding = Instance.new("UIPadding")
	uipadding.PaddingTop = UDim.new(0, 6)
	uipadding.PaddingBottom = UDim.new(0, 24)
	uipadding.PaddingLeft = UDim.new(0, 6)
	uipadding.PaddingRight = UDim.new(0, 6)
	uipadding.Parent = scroll

	local subDesc = Instance.new("TextLabel")
	subDesc.Size = UDim2.new(1, 0, 0, 24)
	subDesc.BackgroundTransparency = 1
	subDesc.Font = Enum.Font.GothamMedium
	subDesc.TextSize = 12
	subDesc.TextColor3 = Color3.fromRGB(255, 160, 175)
	subDesc.Text = "Authorized Developer Testing Controls (Authorized for " .. player.Name .. " & Studio)"
	subDesc.LayoutOrder = 1
	subDesc.ZIndex = 25
	subDesc.Parent = scroll

	local debugActions = {
		{
			Title = "Interactive Player Tutorial",
			Desc = "Launches the 5-stage new player orientation briefing and waypoint guide.",
			Action = "PlayTutorial",
			Arg = nil,
			Color = Color3.fromRGB(0, 220, 255),
			BtnText = "PLAY TUTORIAL",
		},
		{
			Title = "Unlock All Zones (1-5)",
			Desc = "Instant access to all worlds & fast travel warp points without grinding.",
			Action = "UnlockAllZones",
			Arg = nil,
			Color = Color3.fromRGB(40, 200, 90),
			BtnText = "UNLOCK ALL ZONES",
		},
		{
			Title = "Add +100 Gears",
			Desc = "Prestige currency to purchase all permanent upgrades and boosts.",
			Action = "AddGears",
			Arg = 100,
			Color = Color3.fromRGB(50, 180, 255),
			BtnText = "+100 GEARS",
		},
		{
			Title = "Add +1,000,000 Scrap",
			Desc = "Massive scrap injection for purchasing all stats and eggs.",
			Action = "AddScrap",
			Arg = 1000000,
			Color = Color3.fromRGB(255, 200, 40),
			BtnText = "+1M SCRAP",
		},
		{
			Title = "Max All Upgrades",
			Desc = "Maxes out Scrapper Power, Speed, and Magnetic Cargo instantly.",
			Action = "MaxUpgrades",
			Arg = nil,
			Color = Color3.fromRGB(255, 140, 30),
			BtnText = "MAX UPGRADES",
		},
		{
			Title = "Unlock All Prestige Perks",
			Desc = "Activates Overclock, Scrapper Luck, Magnet Range, Rebirth Discount, etc.",
			Action = "UnlockAllPerks",
			Arg = nil,
			Color = Color3.fromRGB(255, 215, 0),
			BtnText = "ALL PERKS",
		},
		{
			Title = "Grant All Drones",
			Desc = "Adds 1 copy of every companion drone to your Drone Hangar.",
			Action = "GiveAllPets",
			Arg = nil,
			Color = Color3.fromRGB(180, 70, 255),
			BtnText = "GRANT DRONES",
		},
		{
			Title = "Unlock All 5 Tools",
			Desc = "Grants all 5 scrapper tools and equips Tier 5 Void Ripper.",
			Action = "UnlockAllTools",
			Arg = nil,
			Color = Color3.fromRGB(175, 60, 255),
			BtnText = "ALL TOOLS",
		},
		{
			Title = "Add +5 Rebirths",
			Desc = "Increases Rebirth tier by +5 and awards +25 bonus gears.",
			Action = "AddRebirth",
			Arg = 5,
			Color = Color3.fromRGB(90, 140, 255),
			BtnText = "+5 REBIRTHS",
		},
		{
			Title = "Trigger Drop Pod (Current Zone)",
			Desc = "Drops an orbital salvage pod directly into whichever zone you are standing in.",
			Action = "SpawnMeteor",
			Arg = "Current",
			Color = Color3.fromRGB(255, 120, 20),
			BtnText = "SPAWN HERE",
		},
		{
			Title = "Trigger Drop Pod (Random Zone)",
			Desc = "Drops an orbital pod into a cycled random zone (anti-repeat rotation across Zones 1-5).",
			Action = "SpawnMeteor",
			Arg = "Random",
			Color = Color3.fromRGB(255, 160, 35),
			BtnText = "SPAWN RANDOM",
		},
		{
			Title = "Trigger Drop Pod (Zone 5 End-Game)",
			Desc = "Drops an orbital salvage pod directly into Zone 5 (Orbital Crashsite).",
			Action = "SpawnMeteor",
			Arg = 5,
			Color = Color3.fromRGB(160, 50, 255),
			BtnText = "SPAWN ZONE 5",
		},
		{
			Title = "Clear All Stats (Scrap & Gears)",
			Desc = "Resets Scrap, Gears, Cargo, and Rebirths to 0 while keeping unlocks.",
			Action = "ClearStats",
			Arg = nil,
			Color = Color3.fromRGB(240, 90, 40),
			BtnText = "CLEAR STATS",
		},
		{
			Title = "Clear Backpack Cargo",
			Desc = "Empties your backpack storage to 0 / Max.",
			Action = "ClearCargo",
			Arg = nil,
			Color = Color3.fromRGB(160, 175, 195),
			BtnText = "CLEAR CARGO",
		},
		{
			Title = "Reset Daily Reward Cooldown",
			Desc = "Instantly clears the 20-hour cooldown so daily reward is ready to test claim.",
			Action = "ResetDailyReward",
			Arg = nil,
			Color = Color3.fromRGB(255, 170, 0),
			BtnText = "RESET REWARD CD",
		},
		{
			Title = "Reset Daily Objectives",
			Desc = "Resets all daily quests to 0 progress so you can test progression & claim.",
			Action = "ResetDailyQuests",
			Arg = nil,
			Color = Color3.fromRGB(40, 210, 120),
			BtnText = "RESET OBJECTIVES",
		},
		{
			Title = "Toggle Hyper Thrusters Gamepass",
			Desc = "Toggles Super Sprint Gamepass (+8 Sprint Speed, +4 Walk Speed) on/off.",
			Action = "ToggleSuperSprint",
			Arg = nil,
			Color = Color3.fromRGB(0, 220, 255),
			BtnText = "TOGGLE PASS",
		},
		{
			Title = "Reset Save Profile (Full Wipe)",
			Desc = "Wipes entire save profile back to fresh beginner account.",
			Action = "ResetSave",
			Arg = nil,
			Color = Color3.fromRGB(225, 45, 55),
			BtnText = "WIPE PROFILE",
		},
	}

	for idx, def in ipairs(debugActions) do
		local row = Instance.new("Frame")
		row.Name = "DebugRow_" .. def.Action
		row.Size = UDim2.new(1, -8, 0, 50)
		row.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
		row.BorderSizePixel = 0
		row.LayoutOrder = 10 + idx
		row.ZIndex = 25
		row.Parent = scroll

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 10)
		rCorner.Parent = row

		local rStroke = Instance.new("UIStroke")
		rStroke.Color = Color3.fromRGB(45, 52, 70)
		rStroke.Thickness = 1.2
		rStroke.Parent = row

		local tTitle = Instance.new("TextLabel")
		tTitle.Size = UDim2.new(1, -165, 0, 22)
		tTitle.Position = UDim2.new(0, 14, 0, 5)
		tTitle.BackgroundTransparency = 1
		tTitle.Font = Enum.Font.GothamBold
		tTitle.TextSize = 13
		tTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
		tTitle.TextXAlignment = Enum.TextXAlignment.Left
		tTitle.Text = def.Title
		tTitle.ZIndex = 26
		tTitle.Parent = row

		local tRowDesc = Instance.new("TextLabel")
		tRowDesc.Size = UDim2.new(1, -165, 0, 18)
		tRowDesc.Position = UDim2.new(0, 14, 0, 27)
		tRowDesc.BackgroundTransparency = 1
		tRowDesc.Font = Enum.Font.GothamMedium
		tRowDesc.TextSize = 11
		tRowDesc.TextColor3 = Color3.fromRGB(150, 165, 185)
		tRowDesc.TextXAlignment = Enum.TextXAlignment.Left
		tRowDesc.Text = def.Desc
		tRowDesc.ZIndex = 26
		tRowDesc.Parent = row

		local actionBtn = Instance.new("TextButton")
		actionBtn.Size = UDim2.new(0, 140, 0, 36)
		actionBtn.Position = UDim2.new(1, -150, 0.5, -18)
		actionBtn.BackgroundColor3 = def.Color
		actionBtn.Font = Enum.Font.GothamBlack
		actionBtn.TextSize = 12
		actionBtn.TextColor3 = Color3.new(1, 1, 1)
		actionBtn.Text = def.BtnText
		actionBtn.ZIndex = 27
		actionBtn.Parent = row

		local aCorner = Instance.new("UICorner")
		aCorner.CornerRadius = UDim.new(0, 8)
		aCorner.Parent = actionBtn

		actionBtn.Activated:Connect(function()
			playSound("rbxassetid://6895079853", 1.2)
			if def.Action == "PlayTutorial" then
				MenuController.closeActivePanel()
				local TutorialController = require(controllersFolder:WaitForChild("TutorialController"))
				TutorialController.startTutorial()
				return
			end
			local debugEvent = Remotes.getEvent("DebugAction")
			debugEvent:FireServer(def.Action, def.Arg)
		end)
	end
end

local function computePetsSignature(pets: { Types.PetInstance }?): string
	if not pets or #pets == 0 then return "EMPTY" end
	local parts = {}
	for _, pet in ipairs(pets) do
		table.insert(parts, pet.UUID .. ":" .. tostring(pet.Equipped))
	end
	return table.concat(parts, "|")
end

local function renderDroneInventory(data: Types.PlayerData)
	if not petListScroll then return end
	local dronesPanel = panels["Drones"]
	if not dronesPanel or not dronesPanel.Visible then
		return
	end

	local petsList = data.Pets or {}
	local sig = computePetsSignature(petsList)
	if sig == lastRenderedPetsSignature then
		return
	end
	lastRenderedPetsSignature = sig

	for _, child in ipairs(petListScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if #petsList == 0 then
		local emptyFrame = Instance.new("Frame")
		emptyFrame.Name = "EmptyState"
		emptyFrame.Size = UDim2.new(1, -10, 0, 150)
		emptyFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		emptyFrame.BorderSizePixel = 0
		emptyFrame.ZIndex = 25
		emptyFrame.Parent = petListScroll

		local eCorner = Instance.new("UICorner")
		eCorner.CornerRadius = UDim.new(0, 10)
		eCorner.Parent = emptyFrame

		local eStroke = Instance.new("UIStroke")
		eStroke.Color = Color3.fromRGB(45, 55, 75)
		eStroke.Thickness = 1
		eStroke.Parent = emptyFrame

		local vpBox = Instance.new("Frame")
		vpBox.Size = UDim2.new(0, 56, 0, 56)
		vpBox.Position = UDim2.new(0.5, -28, 0, 12)
		vpBox.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
		vpBox.BorderSizePixel = 0
		vpBox.ZIndex = 26
		vpBox.Parent = emptyFrame

		local vpc = Instance.new("UICorner")
		vpc.CornerRadius = UDim.new(1, 0)
		vpc.Parent = vpBox

		local vps = Instance.new("UIStroke")
		vps.Color = Color3.fromRGB(160, 130, 110)
		vps.Thickness = 1.5
		vps.Parent = vpBox

		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, 0, 1, 0)
		vp.BackgroundTransparency = 1
		vp.ZIndex = 27
		vp.Parent = vpBox
		DroneVisuals.setupViewport(vp, Config.Pets.List[1], { CamDist = 3.4, Spin = true })

		local eLabel = Instance.new("TextLabel")
		eLabel.Size = UDim2.new(1, -24, 0, 32)
		eLabel.Position = UDim2.new(0, 12, 0, 72)
		eLabel.BackgroundTransparency = 1
		eLabel.Font = Enum.Font.GothamMedium
		eLabel.TextSize = 12
		eLabel.TextColor3 = Color3.fromRGB(160, 175, 195)
		eLabel.TextWrapped = true
		eLabel.Text = "You don't have any companion drones yet! Hatch salvage capsules to recruit helper drones."
		eLabel.ZIndex = 26
		eLabel.Parent = emptyFrame

		local goHatchBtn = Instance.new("TextButton")
		goHatchBtn.Size = UDim2.new(0, 180, 0, 32)
		goHatchBtn.Position = UDim2.new(0.5, -90, 0, 108)
		goHatchBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 220)
		goHatchBtn.Font = Enum.Font.GothamBold
		goHatchBtn.TextSize = 12
		goHatchBtn.TextColor3 = Color3.new(1, 1, 1)
		goHatchBtn.Text = "HATCH CAPSULES (BUY)"
		goHatchBtn.ZIndex = 26
		goHatchBtn.Parent = emptyFrame

		local ghCorner = Instance.new("UICorner")
		ghCorner.CornerRadius = UDim.new(0, 6)
		ghCorner.Parent = goHatchBtn

		goHatchBtn.Activated:Connect(function()
			if switchDroneTabFn then
				switchDroneTabFn("Hatch")
			end
		end)
	else
		for _, pet in ipairs(petsList) do
			local template: Types.PetTemplate? = nil
			for _, t in ipairs(Config.Pets.List) do
				if t.Id == pet.Id then
					template = t
					break
				end
			end

			local row = Instance.new("Frame")
			row.Name = pet.UUID
			row.Size = UDim2.new(1, -10, 0, 56)
			row.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
			row.BorderSizePixel = 0
			row.ZIndex = 25
			row.Parent = petListScroll

			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0, 8)
			rCorner.Parent = row

			local rStroke = Instance.new("UIStroke")
			rStroke.Color = template and template.Color or Color3.fromRGB(100, 100, 100)
			rStroke.Thickness = 1.5
			rStroke.Parent = row

			-- 3D Drone Viewport Icon Preview
			local iconBox = Instance.new("Frame")
			iconBox.Size = UDim2.new(0, 42, 0, 42)
			iconBox.Position = UDim2.new(0, 8, 0.5, -21)
			iconBox.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
			iconBox.BorderSizePixel = 0
			iconBox.ZIndex = 26
			iconBox.Parent = row

			local ibCorner = Instance.new("UICorner")
			ibCorner.CornerRadius = UDim.new(0, 8)
			ibCorner.Parent = iconBox

			local ibStroke = Instance.new("UIStroke")
			ibStroke.Color = template and template.Color or Color3.fromRGB(120, 130, 150)
			ibStroke.Thickness = 1.2
			ibStroke.Parent = iconBox

			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.new(1, 0, 1, 0)
			vp.BackgroundTransparency = 1
			vp.ZIndex = 27
			vp.Parent = iconBox

			if template then
				DroneVisuals.setupViewport(vp, template, { CamDist = 3.4, Spin = true })
			end

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.65, -55, 1, 0)
			nameLabel.Position = UDim2.new(0, 58, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 14
			nameLabel.TextColor3 = template and template.Color or Color3.new(1, 1, 1)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Text = string.format("%s (+%.1fx Scrap)", template and template.Name or "Drone", template and template.Multiplier or 1.0)
			nameLabel.ZIndex = 26
			nameLabel.Parent = row

			local toggleBtn = Instance.new("TextButton")
			toggleBtn.Size = UDim2.new(0, 100, 0, 36)
			toggleBtn.Position = UDim2.new(1, -108, 0.5, -18)
			toggleBtn.BackgroundColor3 = pet.Equipped and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(40, 180, 80)
			toggleBtn.Font = Enum.Font.GothamBlack
			toggleBtn.TextSize = 13
			toggleBtn.TextColor3 = Color3.new(1, 1, 1)
			toggleBtn.Text = pet.Equipped and "UNEQUIP" or "EQUIP"
			toggleBtn.ZIndex = 26
			toggleBtn.Parent = row

			local tbCorner = Instance.new("UICorner")
			tbCorner.CornerRadius = UDim.new(0, 6)
			tbCorner.Parent = toggleBtn

			local petUuid = pet.UUID
			toggleBtn.Activated:Connect(function()
				playSound("rbxassetid://6895079853", 1.2)
				local equipRemote = Remotes.getEvent("EquipPet")
				equipRemote:FireServer(petUuid)
			end)
		end
	end
end
renderDroneInventoryFn = renderDroneInventory

local function updateDailyRewardUI()
	if not dailyRewardBtnRef then return end
	if not currentData then return end

	local now = os.time()
	local lastClaim = currentData.LastDailyRewardClaim or 0
	local COOLDOWN = 20 * 3600
	local STREAK_EXPIRY = 48 * 3600

	local elapsed = (lastClaim > 0) and (now - lastClaim) or (COOLDOWN + 1)
	local remaining = math.max(0, COOLDOWN - elapsed)

	local streak = currentData.DailyLoginStreak or 1
	if lastClaim > 0 and elapsed > STREAK_EXPIRY then
		streak = 1
	end
	streak = math.clamp(streak, 1, 7)

	if dailyRewardSubLabelRef then
		dailyRewardSubLabelRef.Text = string.format(
			"Log in daily to claim escalating Scrap & rare Gears! (Current Streak: Day %d/7)",
			streak
		)
	end

	-- Update 7-day mini cards
	for day = 1, 7 do
		local card = dailyDayCards[day]
		if card then
			if remaining > 0 then
				-- On cooldown: player already claimed today.
				local justClaimedDay = (streak == 1) and 7 or (streak - 1)
				if day <= justClaimedDay and not (streak == 1 and day == 7) then
					card.Frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
					card.Stroke.Color = Color3.fromRGB(36, 45, 60)
					card.Status.Text = "CLAIMED"
					card.Status.TextColor3 = Color3.fromRGB(80, 180, 110)
				elseif day == streak then
					card.Frame.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
					card.Stroke.Color = Color3.fromRGB(70, 100, 140)
					card.Status.Text = "NEXT"
					card.Status.TextColor3 = Color3.fromRGB(130, 175, 230)
				else
					card.Frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
					card.Stroke.Color = Color3.fromRGB(32, 38, 50)
					card.Status.Text = "LOCKED"
					card.Status.TextColor3 = Color3.fromRGB(75, 85, 105)
				end
			else
				-- Ready to claim right now!
				if day < streak then
					card.Frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
					card.Stroke.Color = Color3.fromRGB(36, 45, 60)
					card.Status.Text = "CLAIMED"
					card.Status.TextColor3 = Color3.fromRGB(80, 180, 110)
				elseif day == streak then
					card.Frame.BackgroundColor3 = Color3.fromRGB(45, 34, 12)
					card.Stroke.Color = Color3.fromRGB(255, 185, 30)
					card.Status.Text = "READY!"
					card.Status.TextColor3 = Color3.fromRGB(255, 215, 50)
				else
					card.Frame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
					card.Stroke.Color = Color3.fromRGB(32, 38, 50)
					card.Status.Text = "LOCKED"
					card.Status.TextColor3 = Color3.fromRGB(75, 85, 105)
				end
			end
		end
	end

	local reward = Config.DailyRewards[streak]
	if remaining > 0 then
		local h = math.floor(remaining / 3600)
		local m = math.floor((remaining % 3600) / 60)
		local s = remaining % 60
		dailyRewardBtnRef.Text = string.format("CLAIMED • READY IN %02d:%02d:%02d", h, m, s)
		dailyRewardBtnRef.BackgroundColor3 = Color3.fromRGB(48, 54, 70)
		dailyRewardBtnRef.TextColor3 = Color3.fromRGB(150, 165, 185)
		dailyRewardBtnRef.AutoButtonColor = false
	else
		local amtStr = reward and formatNumber(reward.Amount) or "0"
		local typeStr = reward and string.upper(reward.Type) or "SCRAP"
		dailyRewardBtnRef.Text = string.format("CLAIM DAY %d REWARD (+%s %s)", streak, amtStr, typeStr)
		dailyRewardBtnRef.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		dailyRewardBtnRef.TextColor3 = Color3.fromRGB(255, 255, 255)
		dailyRewardBtnRef.AutoButtonColor = true
	end
end

-- Reactive Data Updating: Updates all active UI elements when data arrives from server!
function MenuController.updateUI(data: Types.PlayerData)
	currentData = data

	-- 1. Update Upgrades (Strictly clean Level %d / %d with NO trailing cargo string)
	for key, conf in pairs(Config.Upgrades) do
		local refs = upgradeRowRefs[key]
		if refs then
			local currentLevel = (data.Upgrades and data.Upgrades[key]) or 1
			refs.LevelLabel.Text = string.format("Level %d / %d", currentLevel, conf.MaxLevel)

			if currentLevel >= conf.MaxLevel then
				refs.BuyButton.Text = "MAXED"
				refs.BuyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
			else
				local nextCost = math.floor(conf.BaseCost * (conf.CostMultiplier ^ (currentLevel - 1)))
				refs.BuyButton.Text = string.format("%s SCRAP", formatNumber(nextCost))
				if data.Scrap >= nextCost then
					refs.BuyButton.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
				else
					refs.BuyButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
				end
			end
		end
	end

	-- 2. Update Gears Shop
	if gearsShopHeaderLabel then
		gearsShopHeaderLabel.Text = string.format("AVAILABLE: %d GEARS (EARNED VIA REBIRTH)", data.Gears or 0)
	end
	for perkId, refs in pairs(gearsPerkRowRefs) do
		local perk = Config.GearsShop[perkId]
		local isOwned = data.GearsPerks and data.GearsPerks[perkId]

		if isOwned then
			refs.BuyButton.Text = "OWNED"
			refs.BuyButton.BackgroundColor3 = Color3.fromRGB(50, 170, 90)
		else
			refs.BuyButton.Text = string.format("%d GEARS", perk.Cost)
			if (data.Gears or 0) >= perk.Cost then
				refs.BuyButton.BackgroundColor3 = Color3.fromRGB(30, 150, 220)
			else
				refs.BuyButton.BackgroundColor3 = Color3.fromRGB(130, 60, 60)
			end
		end
	end

	-- Update Store Items (Gamepass ownership)
	if storeRowRefs["SuperSprint"] then
		local isOwned = (data.HasSuperSprintPass == true)
		if isOwned then
			storeRowRefs["SuperSprint"].BuyButton.Text = "OWNED"
			storeRowRefs["SuperSprint"].BuyButton.BackgroundColor3 = Color3.fromRGB(50, 170, 90)
		else
			local price = (Config.Monetization and Config.Monetization.GamepassDetails and Config.Monetization.GamepassDetails.SuperSprint and Config.Monetization.GamepassDetails.SuperSprint.Price) or 149
			storeRowRefs["SuperSprint"].BuyButton.Text = string.format("R$ %d", price)
			storeRowRefs["SuperSprint"].BuyButton.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
		end
	end

	-- 3. Update Fast-Travel Map Rows
	local maxZone = data.MaxZoneReached or 1
	for zoneId, refs in pairs(teleportRowRefs) do
		local zone = Config.Zones[zoneId]
		if zone then
			if zoneId <= maxZone then
				refs.WarpButton.Text = "TRAVEL"
				refs.WarpButton.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
			else
				refs.WarpButton.Text = string.format("LOCKED\n(%s SCRAP)", formatNumber(zone.UnlockCost))
				refs.WarpButton.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
			end
		end
	end

	-- 4. Update Drones list and Egg Capsule Hatch Cards
	local maxZone = data.MaxZoneReached or 1
	for eggKey, refs in pairs(eggCardRefs) do
		local eggConf = Config.Eggs[eggKey]
		if eggConf then
			local reqZone = eggConf.ZoneId or 1
			if reqZone > maxZone then
				refs.StatusLabel.Text = string.format("LOCKED • REQUIRES ZONE %d", reqZone)
				refs.StatusLabel.TextColor3 = Color3.fromRGB(230, 60, 60)
				refs.HatchBtn.Text = string.format("ZONE %d REQ", reqZone)
				refs.HatchBtn.BackgroundColor3 = Color3.fromRGB(65, 70, 85)
			else
				refs.StatusLabel.Text = string.format("AVAILABLE • ZONE %d", reqZone)
				refs.StatusLabel.TextColor3 = Color3.fromRGB(50, 200, 100)
				if (data.Scrap or 0) >= eggConf.Cost then
					refs.HatchBtn.Text = "HATCH"
					refs.HatchBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
				else
					refs.HatchBtn.Text = "NEED SCRAP"
					refs.HatchBtn.BackgroundColor3 = Color3.fromRGB(180, 110, 40)
				end
			end
		end
	end

	local petsList = data.Pets or {}
	local equippedCount = 0
	for _, pet in ipairs(petsList) do
		if pet.Equipped then equippedCount = equippedCount + 1 end
	end

	local dronesPanel = panels["Drones"]
	local dronesBody = dronesPanel and dronesPanel:FindFirstChild("Body")
	local invContainer = dronesBody and dronesBody:FindFirstChild("InvContainer")
	local invTitle = invContainer and invContainer:FindFirstChild("InvTitle") :: TextLabel?
	if invTitle then
		invTitle.Text = string.format("YOUR DRONES (EQUIPPED: %d/%d):", equippedCount, Config.Defaults.MaxEquippedPets)
	end
	if myDronesTabBtnRef then
		myDronesTabBtnRef.Text = string.format("MY DRONES (%d/%d)", equippedCount, Config.Defaults.MaxEquippedPets)
	end

	renderDroneInventory(data)

	-- 5. Update Rebirth Panel
	if rebirthInfoLabel then
		local rebirths = data.Rebirths or 0
		local cost = math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.CostMultiplier ^ rebirths))
		local gearsEarned = Config.Rebirth.GearsRewardFormula(rebirths)
		local multPercent = math.floor(rebirths * Config.Rebirth.MultiplierPerRebirth * 100)

		rebirthInfoLabel.Text = string.format(
			"Rebirth Level: %d\nPermanent Bonus: +%d%%\nRequired Scrap: %s\nReward: +%d Gears",
			rebirths,
			multPercent,
			formatNumber(cost),
			gearsEarned
		)

		if rebirthButton then
			if data.Scrap >= cost then
				rebirthButton.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
				rebirthButton.Text = "REBIRTH"
			else
				rebirthButton.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
				rebirthButton.Text = string.format("NEED %s SCRAP", formatNumber(cost))
			end
		end
	end

	-- 6. Update Daily Quests
	if data.Quests then
		for _, q in ipairs(Config.Quests) do
			local qRef = questRowRefs[q.Id]
			local qState = data.Quests[q.Id]
			if qRef and qState then
				local prog = math.min(q.Target, qState.Progress or 0)
				local frac = math.clamp(prog / q.Target, 0, 1)
				qRef.Fill.Size = UDim2.new(frac, 0, 1, 0)
				qRef.Label.Text = string.format("%s / %s", formatNumber(prog), formatNumber(q.Target))

				if qState.Claimed then
					qRef.ClaimButton.Text = "CLAIMED"
					qRef.ClaimButton.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
				elseif qState.Completed then
					qRef.ClaimButton.Text = "CLAIM REWARD"
					qRef.ClaimButton.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
				else
					qRef.ClaimButton.Text = "IN PROGRESS"
					qRef.ClaimButton.BackgroundColor3 = Color3.fromRGB(40, 48, 65)
				end
			end
		end
	end

	-- 7. Update Tool Armory
	for _, tool in ipairs(Config.Tools) do
		local refs = toolRowRefs[tool.Id]
		if refs then
			local isEquipped = (data.EquippedTool == tool.Id) or (not data.EquippedTool and tool.Id == "OmniWrench")
			local isOwned = (data.OwnedTools and data.OwnedTools[tool.Id]) or (tool.Cost == 0)

			if isEquipped then
				refs.EquipButton.Text = "EQUIPPED"
				refs.EquipButton.BackgroundColor3 = Color3.fromRGB(80, 85, 100)
			elseif isOwned then
				refs.EquipButton.Text = "EQUIP"
				refs.EquipButton.BackgroundColor3 = Color3.fromRGB(50, 160, 255)
			else
				refs.EquipButton.Text = string.format("BUY (%s SCRAP)", formatNumber(tool.Cost))
				if data.Scrap >= tool.Cost then
					refs.EquipButton.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
				else
					refs.EquipButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
				end
			end
		end
	end

	-- 8. Update Daily Rewards
	updateDailyRewardUI()
end

-- Egg Hatch Reveal Modal
function MenuController.showHatchReveal(info: any)
	local template = info.Template
	if not template then return end

	if not mainGui then
		local pGui = getPlayerGui()
		if pGui then
			mainGui = pGui:FindFirstChild("ScrapOdysseyHUD") :: ScreenGui
		end
	end
	if not mainGui then return end

	local existing = mainGui:FindFirstChild("HatchRevealOverlay")
	if existing then
		existing:Destroy()
	end

	playSound("rbxassetid://743521656", 1.0)

	local overlay = Instance.new("Frame")
	overlay.Name = "HatchRevealOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.ZIndex = 60
	overlay.Parent = mainGui

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 350, 0, 420)
	card.Position = UDim2.new(0.5, -175, 0.5, -210)
	card.BackgroundColor3 = Color3.fromRGB(16, 19, 28)
	card.ZIndex = 61
	card.Parent = overlay

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 18)
	cCorner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = template.Color
	stroke.Thickness = 3.5
	stroke.Parent = card

	-- Close 'X' Button
	local closeHatchBtn = Instance.new("TextButton")
	closeHatchBtn.Name = "CloseButton"
	closeHatchBtn.Size = UDim2.new(0, 32, 0, 32)
	closeHatchBtn.Position = UDim2.new(1, -40, 0, 10)
	closeHatchBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 55)
	closeHatchBtn.Font = Enum.Font.GothamBlack
	closeHatchBtn.TextSize = 16
	closeHatchBtn.TextColor3 = Color3.new(1, 1, 1)
	closeHatchBtn.Text = "X"
	closeHatchBtn.ZIndex = 65
	closeHatchBtn.Parent = card

	local chCorner = Instance.new("UICorner")
	chCorner.CornerRadius = UDim.new(1, 0)
	chCorner.Parent = closeHatchBtn

	closeHatchBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

	-- Top Header Tags
	local eggNameTag = Instance.new("TextLabel")
	eggNameTag.Size = UDim2.new(1, 0, 0, 18)
	eggNameTag.Position = UDim2.new(0, 0, 0, 16)
	eggNameTag.BackgroundTransparency = 1
	eggNameTag.Font = Enum.Font.GothamBold
	eggNameTag.TextSize = 11
	eggNameTag.TextColor3 = Color3.fromRGB(160, 175, 200)
	eggNameTag.Text = string.upper(info.EggName or "SALVAGE CAPSULE") .. " UNLOCKED!"
	eggNameTag.ZIndex = 62
	eggNameTag.Parent = card

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Size = UDim2.new(1, 0, 0, 26)
	tierLabel.Position = UDim2.new(0, 0, 0, 34)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Enum.Font.GothamBlack
	tierLabel.TextSize = 20
	tierLabel.TextColor3 = template.Color
	tierLabel.Text = string.format("[%s TIER]", template.Tier:upper())
	tierLabel.ZIndex = 62
	tierLabel.Parent = card

	-- 3D Drone Viewport Container (Rotating 3D Model!)
	local vpBox = Instance.new("Frame")
	vpBox.Name = "DroneViewportBox"
	vpBox.Size = UDim2.new(0, 140, 0, 140)
	vpBox.Position = UDim2.new(0.5, -70, 0, 68)
	vpBox.BackgroundColor3 = Color3.fromRGB(10, 13, 20)
	vpBox.BorderSizePixel = 0
	vpBox.ZIndex = 62
	vpBox.Parent = card

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(1, 0)
	vpCorner.Parent = vpBox

	local vpStroke = Instance.new("UIStroke")
	vpStroke.Color = template.Color
	vpStroke.Thickness = 2.5
	vpStroke.Parent = vpBox

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.BackgroundTransparency = 1
	vp.ZIndex = 63
	vp.Parent = vpBox

	DroneVisuals.setupViewport(vp, template, { CamDist = 3.2, Spin = true })

	-- Drone Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 32)
	nameLabel.Position = UDim2.new(0, 0, 0, 222)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 24
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = template.Name
	nameLabel.ZIndex = 62
	nameLabel.Parent = card

	-- Multiplier Badge
	local multBadge = Instance.new("Frame")
	multBadge.Size = UDim2.new(0, 220, 0, 32)
	multBadge.Position = UDim2.new(0.5, -110, 0, 260)
	multBadge.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	multBadge.BorderSizePixel = 0
	multBadge.ZIndex = 62
	multBadge.Parent = card

	local mbCorner = Instance.new("UICorner")
	mbCorner.CornerRadius = UDim.new(0, 8)
	mbCorner.Parent = multBadge

	local mbStroke = Instance.new("UIStroke")
	mbStroke.Color = Color3.fromRGB(255, 215, 50)
	mbStroke.Thickness = 1
	mbStroke.Parent = multBadge

	local multLabel = Instance.new("TextLabel")
	multLabel.Size = UDim2.new(1, 0, 1, 0)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 15
	multLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
	multLabel.Text = string.format("⚡ +%.1fx Scrap Multiplier", template.Multiplier)
	multLabel.ZIndex = 63
	multLabel.Parent = multBadge

	-- Follows Player Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -30, 0, 22)
	descLabel.Position = UDim2.new(0, 15, 0, 302)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.GothamMedium
	descLabel.TextSize = 12
	descLabel.TextColor3 = Color3.fromRGB(160, 175, 200)
	descLabel.Text = "Automatically hovers near you and multiplies your scrap gains!"
	descLabel.TextWrapped = true
	descLabel.ZIndex = 62
	descLabel.Parent = card

	-- Action Buttons: EQUIP NOW & AWESOME
	local equipBtn = Instance.new("TextButton")
	equipBtn.Size = UDim2.new(0, 140, 0, 42)
	equipBtn.Position = UDim2.new(0.5, -145, 1, -62)
	equipBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
	equipBtn.Font = Enum.Font.GothamBlack
	equipBtn.TextSize = 14
	equipBtn.TextColor3 = Color3.new(1, 1, 1)
	equipBtn.Text = "EQUIP NOW"
	equipBtn.ZIndex = 62
	equipBtn.Parent = card

	local ebCorner = Instance.new("UICorner")
	ebCorner.CornerRadius = UDim.new(0, 8)
	ebCorner.Parent = equipBtn

	local okBtn = Instance.new("TextButton")
	okBtn.Size = UDim2.new(0, 130, 0, 42)
	okBtn.Position = UDim2.new(0.5, 5, 1, -62)
	okBtn.BackgroundColor3 = template.Color
	okBtn.Font = Enum.Font.GothamBlack
	okBtn.TextSize = 14
	okBtn.TextColor3 = Color3.new(1, 1, 1)
	okBtn.Text = "AWESOME!"
	okBtn.ZIndex = 62
	okBtn.Parent = card

	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 8)
	okCorner.Parent = okBtn

	local petUuid = info.Pet and info.Pet.UUID
	equipBtn.MouseButton1Click:Connect(function()
		if petUuid then
			playSound("rbxassetid://6895079853", 1.2)
			local equipRemote = Remotes.getEvent("EquipPet")
			equipRemote:FireServer(petUuid)
		end
		overlay:Destroy()
	end)

	okBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)
end

-- Modern High-Tech Navigation Dock
function MenuController.buildIconBar()
	local buttons = {
		{ Name = "Upgrades", Label = "UPGRADES", Icon = "🛠️", Color = Color3.fromRGB(45, 200, 110) },
		{ Name = "ToolArmory", Label = "ARMORY", Icon = "🔧", Color = Color3.fromRGB(255, 140, 40) },
		{ Name = "GearsShop", Label = "PRESTIGE", Icon = "⚙️", Color = Color3.fromRGB(60, 190, 255) },
		{ Name = "Store", Label = "STORE", Icon = "⚡", Color = Color3.fromRGB(0, 220, 255) },
		{ Name = "Drones", Label = "DRONES", Icon = "DRN", ImageId = "rbxassetid://10709775087", Color = Color3.fromRGB(255, 175, 30) },
		{ Name = "Quests", Label = "OBJECTIVES", Icon = "🎯", Color = Color3.fromRGB(255, 215, 50) },
		{ Name = "Teleport", Label = "SECTORS", Icon = "🚀", Color = Color3.fromRGB(180, 80, 255) },
		{ Name = "Rebirth", Label = "REBIRTH", Icon = "🔄", Color = Color3.fromRGB(90, 150, 255) },
		{ Name = "Rewards", Label = "REWARDS", Icon = "🎁", Color = Color3.fromRGB(245, 80, 140) },
		{ Name = "Settings", Label = "SETTINGS", Icon = "⚙️", Color = Color3.fromRGB(160, 175, 195) },
	}

	local isDev = RunService:IsStudio() or player.Name == "ExodusNeo" or (game.CreatorId ~= 0 and player.UserId == game.CreatorId)
	if isDev then
		table.insert(buttons, { Name = "Debug", Label = "DEV CONSOLE", Icon = "💻", Color = Color3.fromRGB(255, 65, 100) })
	end

	local totalButtons = #buttons
	local barHeight = 16 + totalButtons * 40 + (totalButtons - 1) * 6

	local bar = Instance.new("Frame")
	bar.Name = "SideIconBar"
	bar.Size = UDim2.new(0, 56, 0, barHeight)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 16, 0.5, 0)
	bar.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	bar.BackgroundTransparency = 0.08
	bar.BorderSizePixel = 0
	bar.Parent = mainGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = bar

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(38, 48, 64)
	bStroke.Thickness = 1
	bStroke.Parent = bar

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = bar

	for _, info in ipairs(buttons) do
		local btn = Instance.new("TextButton")
		btn.Name = info.Name .. "Btn"
		btn.Size = UDim2.new(0, 44, 0, 38)
		btn.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Selectable = true
		btn.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(36, 44, 60)
		stroke.Thickness = 1
		stroke.Parent = btn

		local ind = Instance.new("Frame")
		ind.Name = "Indicator"
		ind.Size = UDim2.new(0, 3, 0.7, 0)
		ind.Position = UDim2.new(0, 0, 0.15, 0)
		ind.BackgroundColor3 = info.Color
		ind.BorderSizePixel = 0
		ind.Parent = btn

		local icCorner = Instance.new("UICorner")
		icCorner.CornerRadius = UDim.new(0, 2)
		icCorner.Parent = ind

		if info.ImageId then
			local img = Instance.new("ImageLabel")
			img.Name = "IconImage"
			img.Size = UDim2.new(0, 22, 0, 22)
			img.Position = UDim2.new(0.5, 2, 0.5, 0)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.BackgroundTransparency = 1
			img.Image = info.ImageId
			img.ImageColor3 = info.Color
			img.ZIndex = 2
			img.Parent = btn
		else
			local iconLbl = Instance.new("TextLabel")
			iconLbl.Name = "IconLabel"
			iconLbl.Size = UDim2.new(1, -4, 1, 0)
			iconLbl.Position = UDim2.new(0, 4, 0, 0)
			iconLbl.BackgroundTransparency = 1
			iconLbl.Font = Enum.Font.GothamBold
			iconLbl.TextSize = 18
			iconLbl.Text = info.Icon
			iconLbl.ZIndex = 2
			iconLbl.Parent = btn
		end

		-- Hover Tooltip Label
		local tooltip = Instance.new("Frame")
		tooltip.Name = "Tooltip"
		tooltip.Size = UDim2.new(0, 110, 0, 26)
		tooltip.Position = UDim2.new(1, 10, 0.5, -13)
		tooltip.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
		tooltip.BackgroundTransparency = 1
		tooltip.BorderSizePixel = 0
		tooltip.ZIndex = 10
		tooltip.Parent = btn

		local tipCorner = Instance.new("UICorner")
		tipCorner.CornerRadius = UDim.new(0, 5)
		tipCorner.Parent = tooltip

		local tipStroke = Instance.new("UIStroke")
		tipStroke.Color = info.Color
		tipStroke.Thickness = 1
		tipStroke.Transparency = 1
		tipStroke.Parent = tooltip

		local tipText = Instance.new("TextLabel")
		tipText.Size = UDim2.new(1, 0, 1, 0)
		tipText.BackgroundTransparency = 1
		tipText.Font = Enum.Font.GothamBold
		tipText.TextSize = 11
		tipText.TextColor3 = info.Color
		tipText.TextTransparency = 1
		tipText.Text = info.Label
		tipText.ZIndex = 11
		tipText.Parent = tooltip

		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = Color3.fromRGB(26, 32, 46),
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.12), { Color = info.Color }):Play()
			TweenService:Create(tooltip, TweenInfo.new(0.12), { BackgroundTransparency = 0.05 }):Play()
			TweenService:Create(tipStroke, TweenInfo.new(0.12), { Transparency = 0 }):Play()
			TweenService:Create(tipText, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
		end)

		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = Color3.fromRGB(18, 22, 32),
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(36, 44, 60) }):Play()
			TweenService:Create(tooltip, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(tipStroke, TweenInfo.new(0.12), { Transparency = 1 }):Play()
			TweenService:Create(tipText, TweenInfo.new(0.12), { TextTransparency = 1 }):Play()
		end)

		btn.Activated:Connect(function()
			playSound("rbxassetid://6895079853", 1.1)
			MenuController.openPanel(info.Name)
		end)
	end
end

function MenuController.init()
	local pGui = getPlayerGui()
	if not pGui then return end
	mainGui = pGui:WaitForChild("ScrapOdysseyHUD") :: ScreenGui
	mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	setupMusic()
	MenuController.buildIconBar()
	MenuController.buildUpgradesPanel()
	MenuController.buildToolArmoryPanel()
	MenuController.buildGearsShopPanel()
	MenuController.buildStorePanel()
	MenuController.buildDronesPanel()
	MenuController.buildQuestsPanel()
	MenuController.buildTeleportPanel()
	MenuController.buildRebirthPanel()
	MenuController.buildRewardsPanel()
	MenuController.buildSettingsPanel()
	MenuController.buildDebugPanel()

	-- Sync Data listener
	local syncEvent = Remotes.getEvent("SyncData")
	syncEvent.OnClientEvent:Connect(function(data)
		MenuController.updateUI(data)
	end)

	-- Initial fetch
	local getFunction = Remotes.getFunction("GetPlayerData")
	task.spawn(function()
		local initialData = getFunction:InvokeServer()
		if initialData then
			MenuController.updateUI(initialData)
		end
	end)

	-- In-world teleport pad listener (signals from server pad to open map)
	local teleportEvent = Remotes.getEvent("TeleportZone")
	teleportEvent.OnClientEvent:Connect(function(zoneId)
		if zoneId == -1 then
			if activePanel ~= panels["Teleport"] then
				MenuController.openPanel("Teleport")
			end
		end
	end)

	-- In-world Tool Armory kiosk signal
	local equipEvent = Remotes.getEvent("EquipTool")
	equipEvent.OnClientEvent:Connect(function(arg)
		if arg == "OPEN_ARMORY" then
			if activePanel ~= panels["ToolArmory"] then
				MenuController.openPanel("ToolArmory")
			end
		end
	end)

	-- Close modals with Escape key or Gamepad Button B, or toggle Debug with F4
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if activePanel then
				MenuController.closeActivePanel()
			end
		elseif input.KeyCode == Enum.KeyCode.F4 then
			local isDev = RunService:IsStudio() or player.Name == "ExodusNeo" or (game.CreatorId ~= 0 and player.UserId == game.CreatorId)
			if isDev then
				if activePanel == panels["Debug"] then
					MenuController.closeActivePanel()
				else
					MenuController.openPanel("Debug")
				end
			end
		end
	end)

	-- Notification Toast Listener
	local notifEvent = Remotes.getEvent("ShowNotification")
	notifEvent.OnClientEvent:Connect(function(title, message, color)
		MenuController.showNotification(title, message, color)
	end)

	local hatchResultEvent = Remotes.getEvent("HatchResult")
	hatchResultEvent.OnClientEvent:Connect(function(info)
		MenuController.showHatchReveal(info)
	end)

	-- 1-second countdown refresh loop for daily rewards when panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			if panels["Rewards"] and panels["Rewards"].Visible then
				updateDailyRewardUI()
			end
		end
	end)

	print("[MenuController] Initialized with 6-Icon Navigation and World Map Fast Travel.")
end

return MenuController
