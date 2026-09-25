--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local controllersFolder = (script and script.Parent) or game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")
local SoundController = require(controllersFolder:WaitForChild("SoundController"))

local player = Players.LocalPlayer
local function getPlayerGui(): PlayerGui?
	if not player then
		player = Players.LocalPlayer
	end
	return player and (player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5)) :: PlayerGui?
end

local TutorialController = {}

type TutorialStep = {
	Badge: string,
	Icon: string,
	Title: string,
	Description: string,
	ProTip: string,
	ActionHint: string,
	TargetType: "None" | "ScrapNode" | "Recycler" | "Upgrades" | "Drones",
}

local STEPS: { TutorialStep } = {
	{
		Badge = "STAGE 1 OF 5 // ORIENTATION",
		Icon = "🚀",
		Title = "WELCOME TO SECTOR 1, OPERATOR!",
		Description = "Welcome aboard Scrap Odyssey! Fractured orbital sectors are rich in precious metallic salvage. Your mission is to harvest scrap debris, upgrade your power rig, and venture deeper into outer cosmic zones.",
		ProTip = "Move with WASD or Left Stick. Hold Shift (or tap SPRINT on mobile) for hyper thrusters.",
		ActionHint = "Press NEXT to begin your field training.",
		TargetType = "None",
	},
	{
		Badge = "STAGE 2 OF 5 // HARVESTING",
		Icon = "🔩",
		Title = "EQUIP & HARVEST RAW SCRAP",
		Description = "Your Omni-Wrench is equipped in your inventory hotbar. Approach any glowing scrap pile or metal wreckage in the sector and Click / Tap to strike it!",
		ProTip = "Each strike deposits raw junk directly into your Cargo Backpack. Multi-hit Dense deposits yield massive bonus scrap!",
		ActionHint = "Follow the golden objective marker pointing to a nearby scrap pile.",
		TargetType = "ScrapNode",
	},
	{
		Badge = "STAGE 3 OF 5 // RECYCLING",
		Icon = "♻️",
		Title = "LIQUEFY CARGO AT THE DEPOT",
		Description = "Your backpack holds raw junk. To spend it on upgrades, step onto the Green Recycler Depot Pad in the Central Hub to convert all cargo into Banked Scrap!",
		ProTip = "Keep an eye on the Cargo Gauge in the top-right HUD. When full, return to the Depot to bank your haul.",
		ActionHint = "Follow the green objective marker to the Central Recycler Furnace.",
		TargetType = "Recycler",
	},
	{
		Badge = "STAGE 4 OF 5 // OVERCLOCKING",
		Icon = "⚡",
		Title = "UPGRADES & TOOL ARMORY",
		Description = "Open the UPGRADES workshop from the right navigation dock (or visit the in-world kiosk). Boost your Scrap Power for higher multipliers, swing faster with Scrap Speed, and expand your Cargo Backpack capacity!",
		ProTip = "Upgrading your backpack also unlocks bigger 3D physical canisters mounted to your character's back.",
		ActionHint = "Follow the cyan marker to the Upgrades Workshop kiosk.",
		TargetType = "Upgrades",
	},
	{
		Badge = "STAGE 5 OF 5 // EXPANSION",
		Icon = "🛸",
		Title = "COMPANION DRONES & WARP GATES",
		Description = "Hatch Salvage Capsules in the Central Hub to recruit autonomous companion drones that follow you and boost your multipliers. When you reach peak scrap, Rebirth for Prestige Gears and unlock Forward Sector Warp Gates!",
		ProTip = "Daily Quests award extra scrap and gears every 24 hours. Check the Quests tab frequently!",
		ActionHint = "Press COMPLETE to finish orientation and claim your +50 Starter Scrap bonus!",
		TargetType = "Drones",
	},
}

local currentStepIndex = 1
local isTutorialActive = false
local tutorialGui: ScreenGui? = nil
local cardFrame: Frame? = nil
local badgeLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local descLabel: TextLabel? = nil
local tipLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local prevBtn: TextButton? = nil
local nextBtn: TextButton? = nil
local skipBtn: TextButton? = nil
local dotsContainer: Frame? = nil

-- In-World Waypoint Highlight & Marker
local currentWaypointHighlight: Highlight? = nil
local currentWaypointBillboard: BillboardGui? = nil
local currentWaypointAttachment: Attachment? = nil

local function cleanupWaypoint()
	if currentWaypointHighlight then
		currentWaypointHighlight:Destroy()
		currentWaypointHighlight = nil
	end
	if currentWaypointBillboard then
		currentWaypointBillboard:Destroy()
		currentWaypointBillboard = nil
	end
	if currentWaypointAttachment then
		currentWaypointAttachment:Destroy()
		currentWaypointAttachment = nil
	end
end

local function findTargetForStep(step: TutorialStep): (Instance?, Vector3?)
	if step.TargetType == "None" then
		return nil, nil
	elseif step.TargetType == "ScrapNode" then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pPos = root and root.Position or Vector3.new(0, 0, 0)
		local bestNode: Model? = nil
		local bestDist = math.huge
		for _, node in ipairs(CollectionService:GetTagged("ScrapNode")) do
			if node:IsA("Model") and node.Parent then
				local hb = node:FindFirstChild("Hitbox") :: BasePart? or node.PrimaryPart
				if hb then
					local d = (hb.Position - pPos).Magnitude
					if d < bestDist then
						bestDist = d
						bestNode = node
					end
				end
			end
		end
		if bestNode then
			local hb = bestNode:FindFirstChild("Hitbox") :: BasePart? or bestNode.PrimaryPart
			return bestNode, hb and (hb.Position + Vector3.new(0, 3.5, 0)) or nil
		end
	elseif step.TargetType == "Recycler" then
		local recycler = Workspace:FindFirstChild("ScrapRecycler_Zone1", true)
		if recycler and recycler:IsA("Model") then
			local pad = recycler:FindFirstChild("RecyclePad") :: BasePart? or recycler.PrimaryPart
			return recycler, pad and (pad.Position + Vector3.new(0, 4, 0)) or Vector3.new(0, 6, -20)
		end
		return nil, Vector3.new(0, 6, -20)
	elseif step.TargetType == "Upgrades" then
		local kiosk = Workspace:FindFirstChild("ToolKiosk_Zone1", true) or Workspace:FindFirstChild("UpgradesKiosk", true)
		if kiosk and kiosk:IsA("Model") then
			local prim = kiosk.PrimaryPart or kiosk:FindFirstChildWhichIsA("BasePart")
			return kiosk, prim and (prim.Position + Vector3.new(0, 4, 0)) or Vector3.new(20, 6, -15)
		end
		return nil, Vector3.new(20, 6, -15)
	elseif step.TargetType == "Drones" then
		local hatchArea = Workspace:FindFirstChild("EggHatchArea", true) or Workspace:FindFirstChild("HatchArea", true)
		if hatchArea and hatchArea:IsA("Model") then
			local prim = hatchArea.PrimaryPart or hatchArea:FindFirstChildWhichIsA("BasePart")
			return hatchArea, prim and (prim.Position + Vector3.new(0, 4, 0)) or Vector3.new(-22, 6, -15)
		end
		return nil, Vector3.new(-22, 6, -15)
	end
	return nil, nil
end

local function spawnWaypoint(step: TutorialStep)
	cleanupWaypoint()
	local targetInst, targetPos = findTargetForStep(step)
	if not targetPos then return end

	-- 1. In-World Highlight if target is a Model
	if targetInst and targetInst:IsA("Model") then
		local hl = Instance.new("Highlight")
		hl.Name = "TutorialTargetHighlight"
		hl.Adornee = targetInst
		hl.FillColor = Color3.fromRGB(0, 230, 255)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.4
		hl.OutlineTransparency = 0.1
		hl.Parent = targetInst
		currentWaypointHighlight = hl
	end

	-- 2. Floating 3D Waypoint Beacon
	local att = Instance.new("Attachment")
	att.Name = "TutorialWaypointAtt"
	att.WorldPosition = targetPos
	att.Parent = Workspace.Terrain
	currentWaypointAttachment = att

	local bb = Instance.new("BillboardGui")
	bb.Name = "TutorialBeacon"
	bb.Adornee = att
	bb.Size = UDim2.new(0, 200, 0, 65)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 250
	bb.Parent = tutorialGui or Workspace.Terrain
	currentWaypointBillboard = bb

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(1, 0, 0, 26)
	arrow.Position = UDim2.new(0, 0, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 22
	arrow.TextColor3 = Color3.fromRGB(0, 240, 255)
	arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
	arrow.TextStrokeTransparency = 0.2
	arrow.Text = "▼ OBJECTIVE ▼"
	arrow.Parent = bb

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Position = UDim2.new(0, 0, 0, 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(255, 225, 100)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Text = step.Title
	label.Parent = bb

	-- Smooth bounce animation
	task.spawn(function()
		local t = 0
		while currentWaypointAttachment == att and att.Parent do
			t += 0.05
			arrow.Position = UDim2.new(0, 0, 0, math.sin(t * 3.5) * 5)
			task.wait(0.03)
		end
	end)
end

local function buildTutorialUI()
	if tutorialGui then return end

	local pGui = getPlayerGui()
	if not pGui then return end

	tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "ScrapOdysseyTutorial"
	tutorialGui.ResetOnSpawn = false
	tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tutorialGui.DisplayOrder = 50
	tutorialGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	tutorialGui.Parent = pGui

	-- Mission Briefing Card
	local card = Instance.new("Frame")
	card.Name = "BriefingCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Size = UDim2.new(0, 560, 0, 230)
	card.Position = UDim2.new(0.5, 0, 1, -28)
	card.BackgroundColor3 = Color3.fromRGB(11, 14, 22)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.Parent = tutorialGui
	cardFrame = card

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 12)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = Color3.fromRGB(0, 190, 255)
	cStroke.Thickness = 2
	cStroke.Parent = card

	-- Top glowing accent bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopGlow"
	topBar.Size = UDim2.new(1, 0, 0, 3)
	topBar.BackgroundColor3 = Color3.fromRGB(0, 235, 255)
	topBar.BorderSizePixel = 0
	topBar.Parent = card

	-- Badge header
	badgeLabel = Instance.new("TextLabel")
	badgeLabel.Name = "Badge"
	badgeLabel.Size = UDim2.new(0.7, 0, 0, 20)
	badgeLabel.Position = UDim2.new(0, 20, 0, 12)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Font = Enum.Font.GothamBlack
	badgeLabel.TextSize = 11
	badgeLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
	badgeLabel.TextXAlignment = Enum.TextXAlignment.Left
	badgeLabel.Text = "STAGE 1 OF 5 // ORIENTATION"
	badgeLabel.Parent = card

	-- Skip Button (top-right)
	skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0, 80, 0, 24)
	skipBtn.Position = UDim2.new(1, -95, 0, 10)
	skipBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.TextSize = 11
	skipBtn.TextColor3 = Color3.fromRGB(160, 175, 195)
	skipBtn.Text = "SKIP ✕"
	skipBtn.Parent = card

	local skCorner = Instance.new("UICorner")
	skCorner.CornerRadius = UDim.new(0, 6)
	skCorner.Parent = skipBtn

	skipBtn.Activated:Connect(function()
		SoundController.playUIClick()
		TutorialController.skipTutorial()
	end)

	-- Title
	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -40, 0, 26)
	titleLabel.Position = UDim2.new(0, 20, 0, 34)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "WELCOME TO SECTOR 1, OPERATOR!"
	titleLabel.Parent = card

	-- Description
	descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -40, 0, 48)
	descLabel.Position = UDim2.new(0, 20, 0, 64)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.GothamMedium
	descLabel.TextSize = 12
	descLabel.TextColor3 = Color3.fromRGB(210, 220, 235)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Text = "Briefing details go here."
	descLabel.Parent = card

	-- ProTip Callout Box
	local tipBox = Instance.new("Frame")
	tipBox.Name = "TipBox"
	tipBox.Size = UDim2.new(1, -40, 0, 36)
	tipBox.Position = UDim2.new(0, 20, 0, 118)
	tipBox.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
	tipBox.BorderSizePixel = 0
	tipBox.Parent = card

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 6)
	tbCorner.Parent = tipBox

	local tbStroke = Instance.new("UIStroke")
	tbStroke.Color = Color3.fromRGB(40, 60, 90)
	tbStroke.Thickness = 1
	tbStroke.Parent = tipBox

	tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "TipText"
	tipLabel.Size = UDim2.new(1, -16, 1, 0)
	tipLabel.Position = UDim2.new(0, 10, 0, 0)
	tipLabel.BackgroundTransparency = 1
	tipLabel.Font = Enum.Font.GothamMedium
	tipLabel.TextSize = 11
	tipLabel.TextColor3 = Color3.fromRGB(255, 205, 80)
	tipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tipLabel.TextWrapped = true
	tipLabel.Text = "💡 TIP: Move with WASD."
	tipLabel.Parent = tipBox

	-- Bottom Navigation Bar inside Card
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, -40, 0, 44)
	bottomBar.Position = UDim2.new(0, 20, 0, 166)
	bottomBar.BackgroundTransparency = 1
	bottomBar.Parent = card

	-- Step Progress Dots
	dotsContainer = Instance.new("Frame")
	dotsContainer.Name = "Dots"
	dotsContainer.Size = UDim2.new(0, 120, 1, 0)
	dotsContainer.Position = UDim2.new(0, 0, 0, 0)
	dotsContainer.BackgroundTransparency = 1
	dotsContainer.Parent = bottomBar

	local dLayout = Instance.new("UIListLayout")
	dLayout.FillDirection = Enum.FillDirection.Horizontal
	dLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dLayout.Padding = UDim.new(0, 8)
	dLayout.Parent = dotsContainer

	for i = 1, #STEPS do
		local dot = Instance.new("Frame")
		dot.Name = "Dot_" .. tostring(i)
		dot.Size = UDim2.new(0, 12, 0, 12)
		dot.BackgroundColor3 = i == 1 and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(40, 50, 70)
		dot.BorderSizePixel = 0
		dot.Parent = dotsContainer

		local dtCorner = Instance.new("UICorner")
		dtCorner.CornerRadius = UDim.new(1, 0)
		dtCorner.Parent = dot
	end

	-- Prev Button
	prevBtn = Instance.new("TextButton")
	prevBtn.Name = "PrevBtn"
	prevBtn.Size = UDim2.new(0, 95, 0, 36)
	prevBtn.Position = UDim2.new(1, -260, 0, 4)
	prevBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	prevBtn.Font = Enum.Font.GothamBold
	prevBtn.TextSize = 12
	prevBtn.TextColor3 = Color3.fromRGB(200, 210, 230)
	prevBtn.Text = "◀ PREV"
	prevBtn.Visible = false
	prevBtn.Parent = bottomBar

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 8)
	pCorner.Parent = prevBtn

	prevBtn.Activated:Connect(function()
		SoundController.playUIClick()
		TutorialController.prevStep()
	end)

	-- Next / Finish Button
	nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.new(0, 150, 0, 36)
	nextBtn.Position = UDim2.new(1, -150, 0, 4)
	nextBtn.BackgroundColor3 = Color3.fromRGB(0, 175, 240)
	nextBtn.Font = Enum.Font.GothamBlack
	nextBtn.TextSize = 12
	nextBtn.TextColor3 = Color3.new(1, 1, 1)
	nextBtn.Text = "NEXT STEP ▶"
	nextBtn.Parent = bottomBar

	local nCorner = Instance.new("UICorner")
	nCorner.CornerRadius = UDim.new(0, 8)
	nCorner.Parent = nextBtn

	nextBtn.Activated:Connect(function()
		SoundController.playUIClick()
		if currentStepIndex >= #STEPS then
			TutorialController.completeTutorial()
		else
			TutorialController.nextStep()
		end
	end)
end

local function updateCardUI()
	if not cardFrame then return end
	local step = STEPS[currentStepIndex]
	if not step then return end

	if badgeLabel then badgeLabel.Text = step.Badge end
	if titleLabel then titleLabel.Text = step.Icon .. "  " .. step.Title end
	if descLabel then descLabel.Text = step.Description end
	if tipLabel then tipLabel.Text = "💡 " .. step.ProTip end

	if prevBtn then
		prevBtn.Visible = (currentStepIndex > 1)
	end

	if nextBtn then
		if currentStepIndex >= #STEPS then
			nextBtn.Text = "CLAIM +50 SCRAP & FINISH"
			nextBtn.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
			nextBtn.Size = UDim2.new(0, 200, 0, 36)
			nextBtn.Position = UDim2.new(1, -200, 0, 4)
		else
			nextBtn.Text = "NEXT STEP ▶"
			nextBtn.BackgroundColor3 = Color3.fromRGB(0, 175, 240)
			nextBtn.Size = UDim2.new(0, 140, 0, 36)
			nextBtn.Position = UDim2.new(1, -140, 0, 4)
		end
	end

	-- Update Dots
	if dotsContainer then
		for i, dot in ipairs(dotsContainer:GetChildren()) do
			if dot:IsA("Frame") then
				local idx = tonumber(string.match(dot.Name, "%d+"))
				if idx then
					if idx == currentStepIndex then
						dot.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
						dot.Size = UDim2.new(0, 14, 0, 14)
					elseif idx < currentStepIndex then
						dot.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
						dot.Size = UDim2.new(0, 10, 0, 10)
					else
						dot.BackgroundColor3 = Color3.fromRGB(40, 48, 65)
						dot.Size = UDim2.new(0, 10, 0, 10)
					end
				end
			end
		end
	end

	-- Smooth punch animation on step transition
	cardFrame.Size = UDim2.new(0, 545, 0, 222)
	TweenService:Create(cardFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 560, 0, 230),
	}):Play()

	spawnWaypoint(step)
end

function TutorialController.startTutorial()
	buildTutorialUI()
	if not cardFrame then return end

	currentStepIndex = 1
	isTutorialActive = true
	cardFrame.Visible = true
	updateCardUI()

	-- Slide in card from below screen
	cardFrame.Position = UDim2.new(0.5, 0, 1, 260)
	TweenService:Create(cardFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -28),
	}):Play()

	SoundController.playSuccess()
end

function TutorialController.nextStep()
	if currentStepIndex < #STEPS then
		currentStepIndex += 1
		updateCardUI()
	else
		TutorialController.completeTutorial()
	end
end

function TutorialController.prevStep()
	if currentStepIndex > 1 then
		currentStepIndex -= 1
		updateCardUI()
	end
end

function TutorialController.skipTutorial()
	cleanupWaypoint()
	if cardFrame then
		local slideOut = TweenService:Create(cardFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 280),
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			if cardFrame then cardFrame.Visible = false end
			isTutorialActive = false
		end)
	else
		isTutorialActive = false
	end

	-- Notify server to set completed so it doesn't auto-pop again
	local completeEvent = Remotes.getEvent("CompleteTutorial")
	completeEvent:FireServer()
end

function TutorialController.completeTutorial()
	cleanupWaypoint()
	if cardFrame then
		local slideOut = TweenService:Create(cardFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 280),
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			if cardFrame then cardFrame.Visible = false end
			isTutorialActive = false
		end)
	else
		isTutorialActive = false
	end

	SoundController.playSuccess()
	local completeEvent = Remotes.getEvent("CompleteTutorial")
	completeEvent:FireServer()
end

function TutorialController.isActive(): boolean
	return isTutorialActive
end

function TutorialController.init()
	local syncEvent = Remotes.getEvent("SyncData")
	local checkedAutoStart = false

	syncEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
		if checkedAutoStart then return end
		checkedAutoStart = true

		if data.HasCompletedTutorial ~= true then
			task.delay(1.5, function()
				if data.HasCompletedTutorial ~= true and not isTutorialActive then
					TutorialController.startTutorial()
				end
			end)
		end
	end)

	print("[TutorialController] Initialized with 5-Stage Interactive Guided Briefing.")
end

return TutorialController
