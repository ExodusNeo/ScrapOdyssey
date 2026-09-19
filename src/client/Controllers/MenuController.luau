--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

local function createStyledPanel(titleText: string): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = titleText .. "Panel"
	panel.Size = UDim2.new(0, 520, 0, 470)
	panel.Position = UDim2.new(0.5, -260, 0.5, -235)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	panel.BorderSizePixel = 0
	panel.Visible = false
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
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -46, 0, 9)
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
		playSound("rbxassetid://6895079853", 0.9)
		MenuController.closeActivePanel()
	end)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -28, 1, -75)
	body.Position = UDim2.new(0, 14, 0, 65)
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

	playSound("rbxassetid://6895079853", 1.1)

	if activePanel == target then
		MenuController.closeActivePanel()
		return
	end

	if activePanel then
		activePanel.Visible = false
	end

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

-- 1. Upgrades Panel Builder
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

-- 2. Gears Prestige Shop Builder (True purpose for Gears!)
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
	local panel, body = createStyledPanel("🥚 SCRAPPER DRONES")
	panels["Drones"] = panel

	local hatchBar = Instance.new("Frame")
	hatchBar.Size = UDim2.new(1, 0, 0, 70)
	hatchBar.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
	hatchBar.BorderSizePixel = 0
	hatchBar.Parent = body

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 12)
	hCorner.Parent = hatchBar

	local hatchLabel = Instance.new("TextLabel")
	hatchLabel.Size = UDim2.new(0.6, 0, 1, 0)
	hatchLabel.Position = UDim2.new(0, 14, 0, 0)
	hatchLabel.BackgroundTransparency = 1
	hatchLabel.Font = Enum.Font.GothamBold
	hatchLabel.TextSize = 15
	hatchLabel.TextColor3 = Color3.new(1, 1, 1)
	hatchLabel.TextXAlignment = Enum.TextXAlignment.Left
	hatchLabel.Text = string.format("Hatch Scrapper Drone\nCost: %d 🔩", Config.Pets.EggCost)
	hatchLabel.Parent = hatchBar

	local hatchBtn = Instance.new("TextButton")
	hatchBtn.Size = UDim2.new(0, 130, 0, 48)
	hatchBtn.Position = UDim2.new(1, -145, 0.5, -24)
	hatchBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	hatchBtn.Font = Enum.Font.GothamBlack
	hatchBtn.TextSize = 16
	hatchBtn.TextColor3 = Color3.new(1, 1, 1)
	hatchBtn.Text = "HATCH 🥚"
	hatchBtn.Parent = hatchBar

	local hbCorner = Instance.new("UICorner")
	hbCorner.CornerRadius = UDim.new(0, 10)
	hbCorner.Parent = hatchBtn

	hatchBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://5153734608", 1.0)
		local hatchRemote = Remotes.getEvent("HatchEgg")
		hatchRemote:FireServer()
	end)

	local invTitle = Instance.new("TextLabel")
	invTitle.Name = "InvTitle"
	invTitle.Size = UDim2.new(1, 0, 0, 24)
	invTitle.Position = UDim2.new(0, 0, 0, 80)
	invTitle.BackgroundTransparency = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 14
	invTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.Text = "YOUR DRONES (EQUIPPED: 0/3):"
	invTitle.Parent = body

	petListScroll = Instance.new("ScrollingFrame")
	petListScroll.Name = "PetList"
	petListScroll.Size = UDim2.new(1, 0, 1, -110)
	petListScroll.Position = UDim2.new(0, 0, 0, 108)
	petListScroll.BackgroundTransparency = 1
	petListScroll.ScrollBarThickness = 6
	petListScroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = petListScroll
end

-- 4. Rebirth Panel Builder
function MenuController.buildRebirthPanel()
	local panel, body = createStyledPanel("🌀 PRESTIGE & REBIRTH")
	panels["Rebirth"] = panel

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, 0, 0, 75)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 15
	desc.TextColor3 = Color3.fromRGB(200, 210, 230)
	desc.TextWrapped = true
	desc.Text = "Rebirth resets your current Scrap in exchange for permanent stat multipliers (+50% per Rebirth) and exclusive Gears (⚙️) to spend in the Gears Prestige Shop!"
	desc.Parent = body

	local statFrame = Instance.new("Frame")
	statFrame.Size = UDim2.new(1, 0, 0, 130)
	statFrame.Position = UDim2.new(0, 0, 0, 90)
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

-- 5. Rewards Panel Builder
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

	-- 1. Update Upgrades
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

	-- 3. Update Drones list
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

	-- 4. Update Rebirth Panel
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

-- Side Navigation Bar with 5 icons
function MenuController.buildIconBar()
	local bar = Instance.new("Frame")
	bar.Name = "SideIconBar"
	bar.Size = UDim2.new(0, 64, 0, 330)
	bar.Position = UDim2.new(0, 20, 0.5, -165)
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
		{ Name = "Upgrades", Icon = "🛒", Color = Color3.fromRGB(40, 190, 80) },
		{ Name = "GearsShop", Icon = "⚙️", Color = Color3.fromRGB(50, 170, 255) },
		{ Name = "Drones", Icon = "🥚", Color = Color3.fromRGB(255, 150, 0) },
		{ Name = "Rebirth", Icon = "🌀", Color = Color3.fromRGB(80, 130, 255) },
		{ Name = "Rewards", Icon = "🎁", Color = Color3.fromRGB(240, 70, 120) },
	}

	for _, info in ipairs(buttons) do
		local btn = Instance.new("TextButton")
		btn.Name = info.Name .. "Btn"
		btn.Size = UDim2.new(0, 48, 0, 48)
		btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 24
		btn.Text = info.Icon
		btn.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = info.Color
		stroke.Thickness = 1.5
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
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

	-- Notification Toast
	local notifEvent = Remotes.getEvent("ShowNotification")
	notifEvent.OnClientEvent:Connect(function(title, message, color)
		playSound("rbxassetid://5153734608", 1.4)
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(0, 340, 0, 58)
		toast.Position = UDim2.new(0.5, -170, 0, 20)
		toast.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
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
		tTitle.Size = UDim2.new(1, -20, 0, 24)
		tTitle.Position = UDim2.new(0, 12, 0, 6)
		tTitle.BackgroundTransparency = 1
		tTitle.Font = Enum.Font.GothamBlack
		tTitle.TextSize = 15
		tTitle.TextColor3 = color or Color3.fromRGB(255, 215, 0)
		tTitle.TextXAlignment = Enum.TextXAlignment.Left
		tTitle.Text = title
		tTitle.Parent = toast

		local tMsg = Instance.new("TextLabel")
		tMsg.Size = UDim2.new(1, -20, 0, 20)
		tMsg.Position = UDim2.new(0, 12, 0, 30)
		tMsg.BackgroundTransparency = 1
		tMsg.Font = Enum.Font.Gotham
		tMsg.TextSize = 13
		tMsg.TextColor3 = Color3.fromRGB(220, 225, 235)
		tMsg.TextXAlignment = Enum.TextXAlignment.Left
		tMsg.Text = message
		tMsg.Parent = toast

		task.delay(3.5, function()
			if toast and toast.Parent then
				toast:Destroy()
			end
		end)
	end)

	local hatchResultEvent = Remotes.getEvent("HatchResult")
	hatchResultEvent.OnClientEvent:Connect(function(info)
		MenuController.showHatchReveal(info)
	end)

	print("[MenuController] Initialized with Gears Prestige Shop and Real-Time Sync.")
end

return MenuController
