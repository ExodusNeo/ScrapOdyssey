--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local MenuController = {}

local mainGui: ScreenGui
local activePanel: Frame? = nil
local panels: { [string]: Frame } = {}
local currentData: Types.PlayerData? = nil

local function createStyledPanel(titleText: string): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = titleText .. "Panel"
	panel.Size = UDim2.new(0, 480, 0, 420)
	panel.Position = UDim2.new(0.5, -240, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = mainGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 85)
	stroke.Thickness = 2
	stroke.Parent = panel

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
	header.BorderSizePixel = 0
	header.Parent = panel

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 7)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Text = "✕"
	closeBtn.Parent = header

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		MenuController.closeActivePanel()
	end)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -24, 1, -70)
	body.Position = UDim2.new(0, 12, 0, 60)
	body.BackgroundTransparency = 1
	body.Parent = panel

	return panel, body
end

function MenuController.closeActivePanel()
	if activePanel then
		activePanel.Visible = false
		activePanel = nil
	end
end

function MenuController.openPanel(name: string)
	local target = panels[name]
	if not target then return end

	if activePanel == target then
		MenuController.closeActivePanel()
		return
	end

	if activePanel then
		activePanel.Visible = false
	end

	target.Visible = true
	activePanel = target

	-- Little bounce tween
	target.Size = UDim2.new(0, 460, 0, 400)
	local tween = TweenService:Create(target, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 480, 0, 420),
	})
	tween:Play()
end

-- 1. Upgrades Panel
function MenuController.buildUpgradesPanel()
	local panel, body = createStyledPanel("🛒 UPGRADES")
	panels["Upgrades"] = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.Parent = body

	for key, conf in pairs(Config.Upgrades) do
		local row = Instance.new("Frame")
		row.Name = key
		row.Size = UDim2.new(1, 0, 0, 80)
		row.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
		row.BorderSizePixel = 0
		row.Parent = body

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.65, 0, 0, 26)
		nameLabel.Position = UDim2.new(0, 12, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 16
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = conf.Name
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.65, 0, 0, 20)
		descLabel.Position = UDim2.new(0, 12, 0, 36)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 12
		descLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Text = conf.Description
		descLabel.Parent = row

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(0.65, 0, 0, 18)
		levelLabel.Position = UDim2.new(0, 12, 0, 56)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextSize = 12
		levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		levelLabel.TextXAlignment = Enum.TextXAlignment.Left
		levelLabel.Text = "Level 1 / " .. tostring(conf.MaxLevel)
		levelLabel.Parent = row

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(0, 120, 0, 44)
		buyBtn.Position = UDim2.new(1, -132, 0.5, -22)
		buyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.TextSize = 14
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Text = "25 🔩"
		buyBtn.Parent = row

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
			local purchaseRemote = Remotes.getEvent("PurchaseUpgrade")
			purchaseRemote:FireServer(key)
		end)
	end
end

-- 2. Drones Panel (Hatching + Equipping)
function MenuController.buildDronesPanel()
	local panel, body = createStyledPanel("🥚 SCRAPPER DRONES")
	panels["Drones"] = panel

	-- Top section: Hatch Button
	local hatchBar = Instance.new("Frame")
	hatchBar.Size = UDim2.new(1, 0, 0, 60)
	hatchBar.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	hatchBar.BorderSizePixel = 0
	hatchBar.Parent = body

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 10)
	hCorner.Parent = hatchBar

	local hatchLabel = Instance.new("TextLabel")
	hatchLabel.Size = UDim2.new(0.6, 0, 1, 0)
	hatchLabel.Position = UDim2.new(0, 12, 0, 0)
	hatchLabel.BackgroundTransparency = 1
	hatchLabel.Font = Enum.Font.GothamBold
	hatchLabel.TextSize = 15
	hatchLabel.TextColor3 = Color3.new(1, 1, 1)
	hatchLabel.TextXAlignment = Enum.TextXAlignment.Left
	hatchLabel.Text = "Hatch Random Drone\nCost: 250 🔩"
	hatchLabel.Parent = hatchBar

	local hatchBtn = Instance.new("TextButton")
	hatchBtn.Size = UDim2.new(0, 120, 0, 42)
	hatchBtn.Position = UDim2.new(1, -132, 0.5, -21)
	hatchBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	hatchBtn.Font = Enum.Font.GothamBlack
	hatchBtn.TextSize = 16
	hatchBtn.TextColor3 = Color3.new(1, 1, 1)
	hatchBtn.Text = "HATCH 🥚"
	hatchBtn.Parent = hatchBar

	local hbCorner = Instance.new("UICorner")
	hbCorner.CornerRadius = UDim.new(0, 8)
	hbCorner.Parent = hatchBtn

	hatchBtn.MouseButton1Click:Connect(function()
		local hatchRemote = Remotes.getEvent("HatchEgg")
		hatchRemote:FireServer()
	end)

	-- Scroll section for owned pets
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "PetList"
	scroll.Size = UDim2.new(1, 0, 1, -75)
	scroll.Position = UDim2.new(0, 0, 0, 70)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll
end

-- 3. Rebirth Panel
function MenuController.buildRebirthPanel()
	local panel, body = createStyledPanel("🌀 REBIRTH")
	panels["Rebirth"] = panel

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, 0, 0, 80)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 15
	desc.TextColor3 = Color3.fromRGB(200, 200, 210)
	desc.TextWrapped = true
	desc.Text = "Reset all your Scrap to gain a permanent +50% multiplier and earn Gears (⚙️) for exclusive perks!"
	desc.Parent = body

	local statFrame = Instance.new("Frame")
	statFrame.Size = UDim2.new(1, 0, 0, 100)
	statFrame.Position = UDim2.new(0, 0, 0, 90)
	statFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	statFrame.BorderSizePixel = 0
	statFrame.Parent = body

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 10)
	sCorner.Parent = statFrame

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "RebirthInfoLabel"
	infoLabel.Size = UDim2.new(1, -20, 1, -20)
	infoLabel.Position = UDim2.new(0, 10, 0, 10)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextSize = 16
	infoLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	infoLabel.Text = "Required: 100K 🔩\nReward: +1 ⚙️ Gears\nCurrent Multiplier: +0%"
	infoLabel.Parent = statFrame

	local rebirthBtn = Instance.new("TextButton")
	rebirthBtn.Name = "RebirthButton"
	rebirthBtn.Size = UDim2.new(1, 0, 0, 55)
	rebirthBtn.Position = UDim2.new(0, 0, 0, 210)
	rebirthBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
	rebirthBtn.Font = Enum.Font.GothamBlack
	rebirthBtn.TextSize = 20
	rebirthBtn.TextColor3 = Color3.new(1, 1, 1)
	rebirthBtn.Text = "REBIRTH NOW 🌀"
	rebirthBtn.Parent = body

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 10)
	rCorner.Parent = rebirthBtn

	rebirthBtn.MouseButton1Click:Connect(function()
		local rebirthRemote = Remotes.getEvent("RequestRebirth")
		rebirthRemote:FireServer()
	end)
end

-- 4. Codes & Daily Rewards Panel
function MenuController.buildRewardsPanel()
	local panel, body = createStyledPanel("🎁 REWARDS & CODES")
	panels["Rewards"] = panel

	-- Daily Reward Button
	local dailyBtn = Instance.new("TextButton")
	dailyBtn.Size = UDim2.new(1, 0, 0, 60)
	dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	dailyBtn.Font = Enum.Font.GothamBlack
	dailyBtn.TextSize = 18
	dailyBtn.TextColor3 = Color3.new(1, 1, 1)
	dailyBtn.Text = "CLAIM DAILY REWARD 📅"
	dailyBtn.Parent = body

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 10)
	dCorner.Parent = dailyBtn

	dailyBtn.MouseButton1Click:Connect(function()
		local claimRemote = Remotes.getEvent("ClaimDailyReward")
		claimRemote:FireServer()
	end)

	-- Promo Code input
	local codeLabel = Instance.new("TextLabel")
	codeLabel.Size = UDim2.new(1, 0, 0, 30)
	codeLabel.Position = UDim2.new(0, 0, 0, 85)
	codeLabel.BackgroundTransparency = 1
	codeLabel.Font = Enum.Font.GothamBold
	codeLabel.TextSize = 15
	codeLabel.TextColor3 = Color3.new(1, 1, 1)
	codeLabel.TextXAlignment = Enum.TextXAlignment.Left
	codeLabel.Text = "Redeem Promo Code:"
	codeLabel.Parent = body

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(0.68, 0, 0, 48)
	codeBox.Position = UDim2.new(0, 0, 0, 120)
	codeBox.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	codeBox.Font = Enum.Font.GothamBold
	codeBox.TextSize = 16
	codeBox.TextColor3 = Color3.new(1, 1, 1)
	codeBox.PlaceholderText = "Enter code (e.g. RELEASE)"
	codeBox.ClearTextOnFocus = false
	codeBox.Parent = body

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = codeBox

	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Size = UDim2.new(0.28, 0, 0, 48)
	redeemBtn.Position = UDim2.new(0.72, 0, 0, 120)
	redeemBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
	redeemBtn.Font = Enum.Font.GothamBlack
	redeemBtn.TextSize = 16
	redeemBtn.TextColor3 = Color3.new(1, 1, 1)
	redeemBtn.Text = "REDEEM"
	redeemBtn.Parent = body

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 8)
	rbCorner.Parent = redeemBtn

	redeemBtn.MouseButton1Click:Connect(function()
		local text = codeBox.Text
		if #text > 0 then
			local redeemRemote = Remotes.getEvent("RedeemCode")
			redeemRemote:FireServer(text)
			codeBox.Text = ""
		end
	end)
end

-- Egg Hatch Reveal Modal Animation
function MenuController.showHatchReveal(info: any)
	local template = info.Template
	if not template then return end

	local overlay = Instance.new("Frame")
	overlay.Name = "HatchRevealOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.ZIndex = 50
	overlay.Parent = mainGui

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 320, 0, 380)
	card.Position = UDim2.new(0.5, -160, 0.5, -190)
	card.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	card.ZIndex = 51
	card.Parent = overlay

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 20)
	cCorner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = template.Color
	stroke.Thickness = 4
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = template.Color
	title.Text = string.format("[%s]", template.Tier:upper())
	title.ZIndex = 52
	title.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 120)
	icon.Position = UDim2.new(0, 0, 0, 80)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = 72
	icon.Text = "🤖"
	icon.ZIndex = 52
	icon.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 40)
	nameLabel.Position = UDim2.new(0, 0, 0, 200)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 26
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = template.Name
	nameLabel.ZIndex = 52
	nameLabel.Parent = card

	local multLabel = Instance.new("TextLabel")
	multLabel.Size = UDim2.new(1, 0, 0, 30)
	multLabel.Position = UDim2.new(0, 0, 0, 240)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 18
	multLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	multLabel.Text = string.format("Multiplier: +%.1fx Scrap", template.Multiplier)
	multLabel.ZIndex = 52
	multLabel.Parent = card

	local okBtn = Instance.new("TextButton")
	okBtn.Size = UDim2.new(0, 180, 0, 48)
	okBtn.Position = UDim2.new(0.5, -90, 1, -65)
	okBtn.BackgroundColor3 = template.Color
	okBtn.Font = Enum.Font.GothamBlack
	okBtn.TextSize = 18
	okBtn.TextColor3 = Color3.new(1, 1, 1)
	okBtn.Text = "AWESOME!"
	okBtn.ZIndex = 52
	okBtn.Parent = card

	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 10)
	okCorner.Parent = okBtn

	okBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)
end

-- Side Icon Navigation Bar
function MenuController.buildIconBar()
	local bar = Instance.new("Frame")
	bar.Name = "SideIconBar"
	bar.Size = UDim2.new(0, 60, 0, 260)
	bar.Position = UDim2.new(0, 20, 0.5, -130)
	bar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.Parent = mainGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 14)
	bCorner.Parent = bar

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(70, 70, 85)
	bStroke.Thickness = 2
	bStroke.Parent = bar

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = bar

	local buttons = {
		{ Name = "Upgrades", Icon = "🛒", Tooltip = "Upgrades" },
		{ Name = "Drones", Icon = "🥚", Tooltip = "Drones" },
		{ Name = "Rebirth", Icon = "🌀", Tooltip = "Rebirth" },
		{ Name = "Rewards", Icon = "🎁", Tooltip = "Rewards" },
	}

	for _, info in ipairs(buttons) do
		local btn = Instance.new("TextButton")
		btn.Name = info.Name .. "Btn"
		btn.Size = UDim2.new(0, 46, 0, 46)
		btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 22
		btn.Text = info.Icon
		btn.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			MenuController.openPanel(info.Name)
		end)
	end
end

function MenuController.init()
	mainGui = playerGui:WaitForChild("ScrapOdysseyHUD") :: ScreenGui

	MenuController.buildIconBar()
	MenuController.buildUpgradesPanel()
	MenuController.buildDronesPanel()
	MenuController.buildRebirthPanel()
	MenuController.buildRewardsPanel()

	-- Notification handler
	local notifEvent = Remotes.getEvent("ShowNotification")
	notifEvent.OnClientEvent:Connect(function(title, message, color)
		-- Spawn notification toast at top center
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(0, 320, 0, 55)
		toast.Position = UDim2.new(0.5, -160, 0, 20)
		toast.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		toast.ZIndex = 99
		toast.Parent = mainGui

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 10)
		tCorner.Parent = toast

		local tStroke = Instance.new("UIStroke")
		tStroke.Color = color or Color3.fromRGB(255, 215, 0)
		tStroke.Thickness = 2
		tStroke.Parent = toast

		local tTitle = Instance.new("TextLabel")
		tTitle.Size = UDim2.new(1, -20, 0, 22)
		tTitle.Position = UDim2.new(0, 10, 0, 6)
		tTitle.BackgroundTransparency = 1
		tTitle.Font = Enum.Font.GothamBlack
		tTitle.TextSize = 14
		tTitle.TextColor3 = color or Color3.fromRGB(255, 215, 0)
		tTitle.TextXAlignment = Enum.TextXAlignment.Left
		tTitle.Text = title
		tTitle.Parent = toast

		local tMsg = Instance.new("TextLabel")
		tMsg.Size = UDim2.new(1, -20, 0, 20)
		tMsg.Position = UDim2.new(0, 10, 0, 28)
		tMsg.BackgroundTransparency = 1
		tMsg.Font = Enum.Font.Gotham
		tMsg.TextSize = 12
		tMsg.TextColor3 = Color3.fromRGB(220, 220, 220)
		tMsg.TextXAlignment = Enum.TextXAlignment.Left
		tMsg.Text = message
		tMsg.Parent = toast

		task.delay(3, function()
			if toast and toast.Parent then
				toast:Destroy()
			end
		end)
	end)

	-- Hatch reveal handler
	local hatchResultEvent = Remotes.getEvent("HatchResult")
	hatchResultEvent.OnClientEvent:Connect(function(info)
		MenuController.showHatchReveal(info)
	end)

	print("[MenuController] Initialized.")
end

return MenuController
