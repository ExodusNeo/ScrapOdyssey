--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

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

-- References for reactive updates
local upgradeRowRefs: { [string]: { LevelLabel: TextLabel, BuyButton: TextButton, Row: Frame } } = {}
local gearsPerkRowRefs: { [string]: { BuyButton: TextButton, StatusLabel: TextLabel } } = {}
local teleportRowRefs: { [number]: { WarpButton: TextButton, StatusLabel: TextLabel } } = {}
local petListScroll: ScrollingFrame
local rebirthInfoLabel: TextLabel
local rebirthButton: TextButton
local gearsShopHeaderLabel: TextLabel

local function playSound(soundId: string, pitch: number?)
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Pitch = pitch or 1.0
		sound.Volume = 0.5
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

		-- Clicking outside the modal immediately closes it!
		modalBackdrop.MouseButton1Click:Connect(function()
			playSound("rbxassetid://6895079853", 0.9)
			MenuController.closeActivePanel()
		end)
	end
	return modalBackdrop
end

local function createStyledPanel(titleText: string): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = titleText .. "Panel"
	panel.Size = UDim2.new(0, 520, 0, 470)
	panel.Position = UDim2.new(0.5, -260, 0.5, -235)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 22
	panel.Parent = mainGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(50, 60, 80)
	stroke.Thickness = 2
	stroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 55)
	header.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	header.BorderSizePixel = 0
	header.ZIndex = 23
	header.Parent = panel

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -70, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.ZIndex = 24
	title.Parent = header

	-- High-visibility circular red close button with bold ASCII "X"
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -48, 0, 9)
	closeBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 55)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 20
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Text = "X"
	closeBtn.ZIndex = 30
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = header

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(1, 0) -- Round circle
	btnCorner.Parent = closeBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(255, 140, 140)
	btnStroke.Thickness = 1.8
	btnStroke.Parent = closeBtn

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.12), {
			Size = UDim2.new(0, 40, 0, 40),
			Position = UDim2.new(1, -50, 0, 7),
			BackgroundColor3 = Color3.fromRGB(255, 70, 70),
		}):Play()
	end)

	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.12), {
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(1, -48, 0, 9),
			BackgroundColor3 = Color3.fromRGB(225, 45, 55),
		}):Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://6895079853", 0.9)
		MenuController.closeActivePanel()
	end)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -28, 1, -75)
	body.Position = UDim2.new(0, 14, 0, 65)
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

	target.Size = UDim2.new(0, 490, 0, 440)
	local tween = TweenService:Create(target, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 520, 0, 470),
	})
	tween:Play()

	if currentData then
		MenuController.updateUI(currentData)
	end
end

-- 1. Upgrades Panel Builder (Clean, uniform cards with no confusing text)
function MenuController.buildUpgradesPanel()
	local panel, body = createStyledPanel("🛒 UPGRADES WORKSHOP")
	panels["Upgrades"] = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.Parent = body

	for key, conf in pairs(Config.Upgrades) do
		local row = Instance.new("Frame")
		row.Name = key
		row.Size = UDim2.new(1, 0, 0, 95)
		row.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
		row.BorderSizePixel = 0
		row.Parent = body

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(45, 52, 70)
		stroke.Thickness = 1.5
		stroke.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.65, 0, 0, 26)
		nameLabel.Position = UDim2.new(0, 14, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextSize = 17
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = conf.Name
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.65, 0, 0, 22)
		descLabel.Position = UDim2.new(0, 14, 0, 36)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 13
		descLabel.TextColor3 = Color3.fromRGB(170, 180, 200)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Text = conf.Description
		descLabel.Parent = row

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(0.65, 0, 0, 22)
		levelLabel.Position = UDim2.new(0, 14, 0, 62)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextSize = 14
		levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		levelLabel.TextXAlignment = Enum.TextXAlignment.Left
		levelLabel.Text = "Level 1 / " .. tostring(conf.MaxLevel)
		levelLabel.Parent = row

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(0, 130, 0, 48)
		buyBtn.Position = UDim2.new(1, -145, 0.5, -24)
		buyBtn.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.TextSize = 15
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Text = "25 🔩"
		buyBtn.Parent = row

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
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
	local panel, body = createStyledPanel("⚙️ GEARS PRESTIGE SHOP")
	panels["GearsShop"] = panel

	gearsShopHeaderLabel = Instance.new("TextLabel")
	gearsShopHeaderLabel.Name = "GearsBalance"
	gearsShopHeaderLabel.Size = UDim2.new(1, 0, 0, 30)
	gearsShopHeaderLabel.BackgroundTransparency = 1
	gearsShopHeaderLabel.Font = Enum.Font.GothamBlack
	gearsShopHeaderLabel.TextSize = 16
	gearsShopHeaderLabel.TextColor3 = Color3.fromRGB(80, 210, 255)
	gearsShopHeaderLabel.Text = "AVAILABLE: 0 ⚙️ GEARS (EARN FROM REBIRTHS)"
	gearsShopHeaderLabel.Parent = body

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -40)
	scroll.Position = UDim2.new(0, 0, 0, 35)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
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
		row.Parent = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(50, 140, 220)
		stroke.Thickness = 1.5
		stroke.Parent = row

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(0, 45, 1, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Font = Enum.Font.GothamBold
		iconLbl.TextSize = 28
		iconLbl.Text = perk.Icon or "⚙️"
		iconLbl.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.6, 0, 0, 24)
		nameLbl.Position = UDim2.new(0, 50, 0, 10)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextSize = 15
		nameLbl.TextColor3 = Color3.fromRGB(80, 210, 255)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text = perk.Name
		nameLbl.Parent = row

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(0.6, 0, 0, 40)
		descLbl.Position = UDim2.new(0, 50, 0, 34)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.Gotham
		descLbl.TextSize = 12
		descLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextWrapped = true
		descLbl.Text = perk.Description
		descLbl.Parent = row

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(0, 115, 0, 44)
		buyBtn.Position = UDim2.new(1, -125, 0.5, -22)
		buyBtn.BackgroundColor3 = Color3.fromRGB(30, 150, 220)
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.TextSize = 15
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Text = string.format("%d ⚙️", perk.Cost)
		buyBtn.Parent = row

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = buyBtn

		buyBtn.MouseButton1Click:Connect(function()
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

-- 3. Drones Panel Builder
function MenuController.buildDronesPanel()
	local panel, body = createStyledPanel("🤖 DRONE HANGAR")
	panels["Drones"] = panel

	local banner = Instance.new("Frame")
	banner.Name = "EggGuideBanner"
	banner.Size = UDim2.new(1, 0, 0, 52)
	banner.BackgroundColor3 = Color3.fromRGB(25, 30, 44)
	banner.BorderSizePixel = 0
	banner.Parent = body

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(50, 70, 100)
	bStroke.Thickness = 1.2
	bStroke.Parent = banner

	local bIcon = Instance.new("TextLabel")
	bIcon.Size = UDim2.new(0, 40, 1, 0)
	bIcon.BackgroundTransparency = 1
	bIcon.Font = Enum.Font.GothamBold
	bIcon.TextSize = 22
	bIcon.Text = "🥚"
	bIcon.Parent = banner

	local bText = Instance.new("TextLabel")
	bText.Size = UDim2.new(1, -50, 1, 0)
	bText.Position = UDim2.new(0, 44, 0, 0)
	bText.BackgroundTransparency = 1
	bText.Font = Enum.Font.GothamMedium
	bText.TextSize = 13
	bText.TextColor3 = Color3.fromRGB(170, 215, 255)
	bText.TextXAlignment = Enum.TextXAlignment.Left
	bText.TextWrapped = true
	bText.Text = "Hatch new Drones at the physical Egg Pods in the Central Hub! (Rust, Plasma & Cyber Pods)"
	bText.Parent = banner

	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "InvTitle"
	invTitle.Size = UDim2.new(1, 0, 0, 24)
	invTitle.Position = UDim2.new(0, 0, 0, 62)
	invTitle.BackgroundTransparency = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 14
	invTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.Text = "YOUR DRONES (EQUIPPED: 0/3):"
	invTitle.Parent = body

	petListScroll = Instance.new("ScrollingFrame")
	petListScroll.Name = "PetList"
	petListScroll.Size = UDim2.new(1, 0, 1, -94)
	petListScroll.Position = UDim2.new(0, 0, 0, 90)
	petListScroll.BackgroundTransparency = 1
	petListScroll.ScrollBarThickness = 6
	petListScroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = petListScroll
end

-- 4. Fast-Travel / World Map Panel Builder (Instant warp to any unlocked zone!)
function MenuController.buildTeleportPanel()
	local panel, body = createStyledPanel("🗺️ WORLD MAP & FAST TRAVEL")
	panels["Teleport"] = panel

	-- Quick Hub Warp Button (Sell Cargo Fast!)
	local hubWarpBtn = Instance.new("TextButton")
	hubWarpBtn.Name = "WarpHubButton"
	hubWarpBtn.Size = UDim2.new(1, 0, 0, 54)
	hubWarpBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 90)
	hubWarpBtn.Font = Enum.Font.GothamBlack
	hubWarpBtn.TextSize = 16
	hubWarpBtn.TextColor3 = Color3.new(1, 1, 1)
	hubWarpBtn.Text = "⚡ WARP TO CENTRAL HUB & RECYCLER"
	hubWarpBtn.Parent = body

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 10)
	hCorner.Parent = hubWarpBtn

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = Color3.fromRGB(100, 255, 140)
	hStroke.Thickness = 1.5
	hStroke.Parent = hubWarpBtn

	hubWarpBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://6895079853", 1.2)
		local teleportRemote = Remotes.getEvent("TeleportZone")
		teleportRemote:FireServer(1)
		MenuController.closeActivePanel()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -66)
	scroll.Position = UDim2.new(0, 0, 0, 64)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.Parent = scroll

	for _, zone in ipairs(Config.Zones) do
		local row = Instance.new("Frame")
		row.Name = "ZoneRow_" .. tostring(zone.Id)
		row.Size = UDim2.new(1, -10, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
		row.BorderSizePixel = 0
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
		nameLbl.Parent = row

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(0.62, 0, 0, 28)
		descLbl.Position = UDim2.new(0, 14, 0, 34)
		descLbl.BackgroundTransparency = 1
		descLbl.Font = Enum.Font.Gotham
		descLbl.TextSize = 12
		descLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.Text = string.format("Base Yield: %d 🔩 • %s", zone.BaseYield, zone.Description)
		descLbl.Parent = row

		local warpBtn = Instance.new("TextButton")
		warpBtn.Name = "WarpButton"
		warpBtn.Size = UDim2.new(0, 115, 0, 44)
		warpBtn.Position = UDim2.new(1, -125, 0.5, -22)
		warpBtn.BackgroundColor3 = (zone.Id == 1) and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(90, 95, 110)
		warpBtn.Font = Enum.Font.GothamBlack
		warpBtn.TextSize = 14
		warpBtn.TextColor3 = Color3.new(1, 1, 1)
		warpBtn.Text = (zone.Id == 1) and "WARP ⚡" or string.format("LOCKED 🔒\n(%s 🔩)", formatNumber(zone.UnlockCost))
		warpBtn.Parent = row

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = warpBtn

		local zId = zone.Id
		warpBtn.MouseButton1Click:Connect(function()
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
	local panel, body = createStyledPanel("🌀 PRESTIGE & REBIRTH")
	panels["Rebirth"] = panel

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, 0, 0, 75)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextColor3 = Color3.fromRGB(200, 210, 230)
	desc.TextWrapped = true
	desc.Text = "⚡ PRESTIGE REBIRTH RULES:\n• RESETS: Scrap, Cargo, Regular Upgrades (to Lvl 1), & Zones.\n• KEEPS: All Drones, Gears, & Prestige Perks!\n• AWARDS: +50% Permanent Multiplier & Prestige Gears (⚙️)!"
	desc.Parent = body

	local statFrame = Instance.new("Frame")
	statFrame.Size = UDim2.new(1, 0, 0, 130)
	statFrame.Position = UDim2.new(0, 0, 0, 96)
	statFrame.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	statFrame.BorderSizePixel = 0
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
	rebirthInfoLabel.Text = "Required Scrap: 100K 🔩\nReward: +1 Gears ⚙️\nCurrent Multiplier: +0%"
	rebirthInfoLabel.Parent = statFrame

	rebirthButton = Instance.new("TextButton")
	rebirthButton.Name = "RebirthButton"
	rebirthButton.Size = UDim2.new(1, 0, 0, 60)
	rebirthButton.Position = UDim2.new(0, 0, 0, 240)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
	rebirthButton.Font = Enum.Font.GothamBlack
	rebirthButton.TextSize = 20
	rebirthButton.TextColor3 = Color3.new(1, 1, 1)
	rebirthButton.Text = "REBIRTH NOW 🌀"
	rebirthButton.Parent = body

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 12)
	rCorner.Parent = rebirthButton

	rebirthButton.MouseButton1Click:Connect(function()
		playSound("rbxassetid://743521656", 1.0)
		local rebirthRemote = Remotes.getEvent("RequestRebirth")
		rebirthRemote:FireServer()
	end)
end

-- 6. Rewards Panel Builder
function MenuController.buildRewardsPanel()
	local panel, body = createStyledPanel("🎁 DAILY REWARDS & CODES")
	panels["Rewards"] = panel

	local dailyBtn = Instance.new("TextButton")
	dailyBtn.Size = UDim2.new(1, 0, 0, 65)
	dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	dailyBtn.Font = Enum.Font.GothamBlack
	dailyBtn.TextSize = 18
	dailyBtn.TextColor3 = Color3.new(1, 1, 1)
	dailyBtn.Text = "CLAIM DAILY REWARD 📅"
	dailyBtn.Parent = body

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 12)
	dCorner.Parent = dailyBtn

	dailyBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://5153734608", 1.3)
		local claimRemote = Remotes.getEvent("ClaimDailyReward")
		claimRemote:FireServer()
	end)

	local codeLabel = Instance.new("TextLabel")
	codeLabel.Size = UDim2.new(1, 0, 0, 30)
	codeLabel.Position = UDim2.new(0, 0, 0, 95)
	codeLabel.BackgroundTransparency = 1
	codeLabel.Font = Enum.Font.GothamBold
	codeLabel.TextSize = 15
	codeLabel.TextColor3 = Color3.new(1, 1, 1)
	codeLabel.TextXAlignment = Enum.TextXAlignment.Left
	codeLabel.Text = "Redeem Promo Code (RELEASE / SCRAPPER / GEARS):"
	codeLabel.Parent = body

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(0.68, 0, 0, 50)
	codeBox.Position = UDim2.new(0, 0, 0, 130)
	codeBox.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
	codeBox.Font = Enum.Font.GothamBold
	codeBox.TextSize = 16
	codeBox.TextColor3 = Color3.new(1, 1, 1)
	codeBox.PlaceholderText = "Enter code..."
	codeBox.ClearTextOnFocus = false
	codeBox.Parent = body

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 10)
	cbCorner.Parent = codeBox

	local redeemBtn = Instance.new("TextButton")
	redeemBtn.Size = UDim2.new(0.28, 0, 0, 50)
	redeemBtn.Position = UDim2.new(0.72, 0, 0, 130)
	redeemBtn.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
	redeemBtn.Font = Enum.Font.GothamBlack
	redeemBtn.TextSize = 16
	redeemBtn.TextColor3 = Color3.new(1, 1, 1)
	redeemBtn.Text = "REDEEM"
	redeemBtn.Parent = body

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 10)
	rbCorner.Parent = redeemBtn

	redeemBtn.MouseButton1Click:Connect(function()
		local text = codeBox.Text
		if #text > 0 then
			playSound("rbxassetid://5153734608", 1.1)
			local redeemRemote = Remotes.getEvent("RedeemCode")
			redeemRemote:FireServer(text)
			codeBox.Text = ""
		end
	end)
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
				refs.BuyButton.Text = string.format("%s 🔩", formatNumber(nextCost))
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
		gearsShopHeaderLabel.Text = string.format("AVAILABLE: %d ⚙️ GEARS (EARN FROM REBIRTHS)", data.Gears or 0)
	end
	for perkId, refs in pairs(gearsPerkRowRefs) do
		local perk = Config.GearsShop[perkId]
		local isOwned = data.GearsPerks and data.GearsPerks[perkId]

		if isOwned then
			refs.BuyButton.Text = "ACTIVE ✅"
			refs.BuyButton.BackgroundColor3 = Color3.fromRGB(50, 170, 90)
		else
			refs.BuyButton.Text = string.format("%d ⚙️", perk.Cost)
			if (data.Gears or 0) >= perk.Cost then
				refs.BuyButton.BackgroundColor3 = Color3.fromRGB(30, 150, 220)
			else
				refs.BuyButton.BackgroundColor3 = Color3.fromRGB(130, 60, 60)
			end
		end
	end

	-- 3. Update Fast-Travel Map Rows
	local maxZone = data.MaxZoneReached or 1
	for zoneId, refs in pairs(teleportRowRefs) do
		local zone = Config.Zones[zoneId]
		if zone then
			if zoneId <= maxZone then
				refs.WarpButton.Text = "WARP ⚡"
				refs.WarpButton.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
			else
				refs.WarpButton.Text = string.format("LOCKED 🔒\n(%s 🔩)", formatNumber(zone.UnlockCost))
				refs.WarpButton.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
			end
		end
	end

	-- 4. Update Drones list
	if petListScroll then
		for _, child in ipairs(petListScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		local equippedCount = 0
		for _, pet in ipairs(data.Pets or {}) do
			if pet.Equipped then equippedCount = equippedCount + 1 end
		end

		local invTitle = panels["Drones"] and panels["Drones"]:FindFirstChild("Body", true) and panels["Drones"].Body:FindFirstChild("InvTitle") :: TextLabel
		if invTitle then
			invTitle.Text = string.format("YOUR DRONES (EQUIPPED: %d/%d):", equippedCount, Config.Defaults.MaxEquippedPets)
		end

		for _, pet in ipairs(data.Pets or {}) do
			local template: Types.PetTemplate? = nil
			for _, t in ipairs(Config.Pets.List) do
				if t.Id == pet.Id then
					template = t
					break
				end
			end

			local row = Instance.new("Frame")
			row.Name = pet.UUID
			row.Size = UDim2.new(1, -10, 0, 52)
			row.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
			row.BorderSizePixel = 0
			row.Parent = petListScroll

			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0, 8)
			rCorner.Parent = row

			local rStroke = Instance.new("UIStroke")
			rStroke.Color = template and template.Color or Color3.fromRGB(100, 100, 100)
			rStroke.Thickness = 1.5
			rStroke.Parent = row

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
			nameLabel.Position = UDim2.new(0, 12, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 14
			nameLabel.TextColor3 = template and template.Color or Color3.new(1, 1, 1)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Text = string.format("%s (+%.1fx Scrap)", template and template.Name or "Drone", template and template.Multiplier or 1.0)
			nameLabel.Parent = row

			local toggleBtn = Instance.new("TextButton")
			toggleBtn.Size = UDim2.new(0, 100, 0, 36)
			toggleBtn.Position = UDim2.new(1, -108, 0.5, -18)
			toggleBtn.BackgroundColor3 = pet.Equipped and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(40, 180, 80)
			toggleBtn.Font = Enum.Font.GothamBlack
			toggleBtn.TextSize = 13
			toggleBtn.TextColor3 = Color3.new(1, 1, 1)
			toggleBtn.Text = pet.Equipped and "UNEQUIP" or "EQUIP"
			toggleBtn.Parent = row

			local tbCorner = Instance.new("UICorner")
			tbCorner.CornerRadius = UDim.new(0, 6)
			tbCorner.Parent = toggleBtn

			local petUuid = pet.UUID
			toggleBtn.MouseButton1Click:Connect(function()
				playSound("rbxassetid://6895079853", 1.2)
				local equipRemote = Remotes.getEvent("EquipPet")
				equipRemote:FireServer(petUuid)
			end)
		end
	end

	-- 5. Update Rebirth Panel
	if rebirthInfoLabel then
		local rebirths = data.Rebirths or 0
		local cost = math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.CostMultiplier ^ rebirths))
		local gearsEarned = Config.Rebirth.GearsRewardFormula(rebirths)
		local multPercent = math.floor(rebirths * Config.Rebirth.MultiplierPerRebirth * 100)

		rebirthInfoLabel.Text = string.format(
			"Current Rebirths: %d\nPermanent Multiplier: +%d%%\nRequired Scrap: %s 🔩\nRebirth Reward: +%d Gears ⚙️",
			rebirths,
			multPercent,
			formatNumber(cost),
			gearsEarned
		)

		if rebirthButton then
			if data.Scrap >= cost then
				rebirthButton.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
				rebirthButton.Text = "REBIRTH NOW 🌀"
			else
				rebirthButton.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
				rebirthButton.Text = string.format("NEED %s 🔩", formatNumber(cost))
			end
		end
	end
end

-- Egg Hatch Reveal Modal
function MenuController.showHatchReveal(info: any)
	local template = info.Template
	if not template then return end

	playSound("rbxassetid://743521656", 1.0)

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
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	card.ZIndex = 51
	card.Parent = overlay

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 20)
	cCorner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = template.Color
	stroke.Thickness = 4
	stroke.Parent = card

	local closeHatchBtn = Instance.new("TextButton")
	closeHatchBtn.Name = "CloseButton"
	closeHatchBtn.Size = UDim2.new(0, 32, 0, 32)
	closeHatchBtn.Position = UDim2.new(1, -42, 0, 10)
	closeHatchBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 55)
	closeHatchBtn.Font = Enum.Font.GothamBlack
	closeHatchBtn.TextSize = 18
	closeHatchBtn.TextColor3 = Color3.new(1, 1, 1)
	closeHatchBtn.Text = "X"
	closeHatchBtn.ZIndex = 58
	closeHatchBtn.Parent = card

	local chCorner = Instance.new("UICorner")
	chCorner.CornerRadius = UDim.new(1, 0)
	chCorner.Parent = closeHatchBtn

	closeHatchBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)

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

-- Side Navigation Bar with 6 100% Reliable, Vibrant Emoji Icons
function MenuController.buildIconBar()
	local bar = Instance.new("Frame")
	bar.Name = "SideIconBar"
	bar.Size = UDim2.new(0, 64, 0, 390)
	bar.Position = UDim2.new(0, 20, 0.5, -195)
	bar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	bar.BackgroundTransparency = 0.15
	bar.BorderSizePixel = 0
	bar.Parent = mainGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 16)
	bCorner.Parent = bar

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(50, 60, 80)
	bStroke.Thickness = 2
	bStroke.Parent = bar

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = bar

	local buttons = {
		{ Name = "Upgrades", Label = "UPGRADES", Emoji = "🛒", Color = Color3.fromRGB(40, 200, 90) },
		{ Name = "GearsShop", Label = "PRESTIGE SHOP", Emoji = "⚙️", Color = Color3.fromRGB(50, 180, 255) },
		{ Name = "Drones", Label = "DRONE HANGAR", Emoji = "🤖", Color = Color3.fromRGB(255, 160, 20) },
		{ Name = "Teleport", Label = "FAST TRAVEL", Emoji = "🗺️", Color = Color3.fromRGB(180, 70, 255) },
		{ Name = "Rebirth", Label = "REBIRTH", Emoji = "🌀", Color = Color3.fromRGB(90, 140, 255) },
		{ Name = "Rewards", Label = "DAILY REWARDS", Emoji = "🎁", Color = Color3.fromRGB(240, 70, 130) },
	}

	for _, info in ipairs(buttons) do
		local btn = Instance.new("TextButton")
		btn.Name = info.Name .. "Btn"
		btn.Size = UDim2.new(0, 48, 0, 48)
		btn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 13)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = info.Color
		stroke.Thickness = 1.8
		stroke.Parent = btn

		-- 100% Reliable Emoji Icon (Visible on all platforms, zero asset loading failures!)
		local iconLbl = Instance.new("TextLabel")
		iconLbl.Name = "EmojiIcon"
		iconLbl.Size = UDim2.new(1, 0, 1, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Font = Enum.Font.GothamBlack
		iconLbl.TextSize = 24
		iconLbl.TextColor3 = Color3.new(1, 1, 1)
		iconLbl.Text = info.Emoji
		iconLbl.ZIndex = 2
		iconLbl.Parent = btn

		-- Hover Tooltip Label
		local tooltip = Instance.new("Frame")
		tooltip.Name = "Tooltip"
		tooltip.Size = UDim2.new(0, 130, 0, 30)
		tooltip.Position = UDim2.new(1, 14, 0.5, -15)
		tooltip.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
		tooltip.BackgroundTransparency = 1
		tooltip.BorderSizePixel = 0
		tooltip.ZIndex = 10
		tooltip.Parent = btn

		local tipCorner = Instance.new("UICorner")
		tipCorner.CornerRadius = UDim.new(0, 8)
		tipCorner.Parent = tooltip

		local tipStroke = Instance.new("UIStroke")
		tipStroke.Color = info.Color
		tipStroke.Thickness = 1.5
		tipStroke.Transparency = 1
		tipStroke.Parent = tooltip

		local tipText = Instance.new("TextLabel")
		tipText.Size = UDim2.new(1, 0, 1, 0)
		tipText.BackgroundTransparency = 1
		tipText.Font = Enum.Font.GothamBlack
		tipText.TextSize = 12
		tipText.TextColor3 = info.Color
		tipText.TextTransparency = 1
		tipText.Text = info.Label
		tipText.ZIndex = 11
		tipText.Parent = tooltip

		-- Hover Animations
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 52, 0, 52),
				BackgroundColor3 = Color3.fromRGB(32, 38, 55),
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.15), { Thickness = 2.5 }):Play()
			TweenService:Create(tooltip, TweenInfo.new(0.15), { BackgroundTransparency = 0.1 }):Play()
			TweenService:Create(tipStroke, TweenInfo.new(0.15), { Transparency = 0 }):Play()
			TweenService:Create(tipText, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
		end)

		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 48, 0, 48),
				BackgroundColor3 = Color3.fromRGB(24, 28, 40),
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.15), { Thickness = 1.8 }):Play()
			TweenService:Create(tooltip, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(tipStroke, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			TweenService:Create(tipText, TweenInfo.new(0.15), { TextTransparency = 1 }):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			playSound("rbxassetid://6895079853", 1.1)
			TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {
				Size = UDim2.new(0, 42, 0, 42),
			}):Play()
			MenuController.openPanel(info.Name)
		end)
	end
end

function MenuController.init()
	mainGui = playerGui:WaitForChild("ScrapOdysseyHUD") :: ScreenGui

	MenuController.buildIconBar()
	MenuController.buildUpgradesPanel()
	MenuController.buildGearsShopPanel()
	MenuController.buildDronesPanel()
	MenuController.buildTeleportPanel()
	MenuController.buildRebirthPanel()
	MenuController.buildRewardsPanel()

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

	-- Close modals with Escape key or Gamepad Button B
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if activePanel then
				MenuController.closeActivePanel()
			end
		end
	end)

	-- Notification Toast (Spacious, multi-line, animated slide-in)
	local notifEvent = Remotes.getEvent("ShowNotification")
	notifEvent.OnClientEvent:Connect(function(title, message, color)
		playSound("rbxassetid://5153734608", 1.4)
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(0, 480, 0, 76)
		toast.Position = UDim2.new(0.5, -240, 0, -90)
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
		tTitle.TextSize = 16
		tTitle.TextColor3 = color or Color3.fromRGB(255, 215, 0)
		tTitle.TextXAlignment = Enum.TextXAlignment.Left
		tTitle.Text = title
		tTitle.ZIndex = 100
		tTitle.Parent = toast

		local tMsg = Instance.new("TextLabel")
		tMsg.Size = UDim2.new(1, -32, 0, 36)
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

		TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -240, 0, 24),
		}):Play()

		task.delay(3.8, function()
			if toast and toast.Parent then
				local slideOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, -240, 0, -90),
					BackgroundTransparency = 1,
				})
				slideOut:Play()
				slideOut.Completed:Connect(function()
					toast:Destroy()
				end)
			end
		end)
	end)

	local hatchResultEvent = Remotes.getEvent("HatchResult")
	hatchResultEvent.OnClientEvent:Connect(function(info)
		MenuController.showHatchReveal(info)
	end)

	print("[MenuController] Initialized with 6-Icon Navigation and World Map Fast Travel.")
end

return MenuController
