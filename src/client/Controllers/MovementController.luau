--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Types = require(ReplicatedStorage.Modules.Types)

local MovementController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

-- Sprint state
local isSprinting = false
local currentData: Types.PlayerData? = nil
local ownsSuperSprintPass = false

-- Mobile touch button refs
local mobileSprintBtn: TextButton? = nil
local mobileStroke: UIStroke? = nil
local mobileStatusLabel: TextLabel? = nil

-- Lifecycle management
local generation = 0
local connections: { RBXScriptConnection } = {}
local currentHumanoid: Humanoid? = nil
local fovTween: Tween? = nil

function MovementController.updateData(data: Types.PlayerData)
	currentData = data
	MovementController.applySpeed()
end

function MovementController.ownsGamepass(): boolean
	if currentData and currentData.HasSuperSprintPass == true then
		return true
	end
	return ownsSuperSprintPass
end

function MovementController.hasSpeedDemon(): boolean
	return currentData ~= nil and currentData.GearsPerks ~= nil and currentData.GearsPerks["SpeedDemon"] == true
end

function MovementController.getCalculatedSpeed(): number
	local sprintConfig = Config.Sprint or {
		DefaultWalkSpeed = 16,
		DefaultSprintSpeed = 26,
		SpeedDemonBonus = 6,
		SuperSprintBonus = 8,
		FovWalk = 70,
		FovSprint = 78,
		FovTweenTime = 0.25,
	}

	local baseWalk = sprintConfig.DefaultWalkSpeed
	local baseSprint = sprintConfig.DefaultSprintSpeed

	local walkBonus = 0
	local sprintBonus = 0

	if MovementController.hasSpeedDemon() then
		walkBonus += 2
		sprintBonus += sprintConfig.SpeedDemonBonus
	end

	if MovementController.ownsGamepass() then
		walkBonus += 4
		sprintBonus += sprintConfig.SuperSprintBonus
	end

	if isSprinting then
		return baseSprint + sprintBonus
	else
		return baseWalk + walkBonus
	end
end

function MovementController.getHumanoid(): Humanoid?
	if currentHumanoid and currentHumanoid.Parent and currentHumanoid.Health > 0 then
		return currentHumanoid
	end
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid") :: Humanoid?
		if hum and hum.Health > 0 then
			currentHumanoid = hum
			return hum
		end
	end
	return nil
end

local function updateFov()
	if not camera then
		camera = Workspace.CurrentCamera
	end
	if not camera then return end

	local sprintConfig = Config.Sprint or {
		FovWalk = 70,
		FovSprint = 78,
		FovTweenTime = 0.25,
	}

	local hum = MovementController.getHumanoid()
	local isMoving = hum and hum.MoveDirection.Magnitude > 0.05
	local targetFov = (isSprinting and isMoving) and sprintConfig.FovSprint or sprintConfig.FovWalk

	if fovTween then
		fovTween:Cancel()
	end

	fovTween = TweenService:Create(camera, TweenInfo.new(sprintConfig.FovTweenTime or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = targetFov,
	})
	fovTween:Play()
end

function MovementController.applySpeed()
	local hum = MovementController.getHumanoid()
	if not hum or hum.Health <= 0 then return end
	local targetSpeed = MovementController.getCalculatedSpeed()
	hum.WalkSpeed = targetSpeed
	updateFov()
	MovementController.updateMobileUI()
end

function MovementController.setSprinting(sprint: boolean)
	if isSprinting == sprint then return end
	isSprinting = sprint
	MovementController.applySpeed()
end

function MovementController.isSprinting(): boolean
	return isSprinting
end

function MovementController.updateMobileUI()
	if not mobileSprintBtn then return end

	if isSprinting then
		mobileSprintBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
		if mobileStroke then
			mobileStroke.Color = Color3.fromRGB(0, 240, 255)
			mobileStroke.Thickness = 2
		end
		if mobileStatusLabel then
			mobileStatusLabel.Text = "ON"
			mobileStatusLabel.TextColor3 = Color3.fromRGB(0, 255, 220)
		end
	else
		mobileSprintBtn.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
		if mobileStroke then
			mobileStroke.Color = Color3.fromRGB(60, 80, 110)
			mobileStroke.Thickness = 1.5
		end
		if mobileStatusLabel then
			mobileStatusLabel.Text = "OFF"
			mobileStatusLabel.TextColor3 = Color3.fromRGB(150, 170, 195)
		end
	end
end

local function setupMobileButton()
	-- Only display for touch-enabled devices
	if not UserInputService.TouchEnabled then return end

	local pGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5) :: PlayerGui?
	if not pGui then return end

	local hud = pGui:WaitForChild("ScrapOdysseyHUD", 8) :: ScreenGui?
	if not hud then return end

	-- Check if button already exists
	if hud:FindFirstChild("MobileSprintContainer") then
		return
	end

	local container = Instance.new("Frame")
	container.Name = "MobileSprintContainer"
	container.Size = UDim2.new(0, 60, 0, 60)
	container.Position = UDim2.new(1, -95, 1, -168)
	container.BackgroundTransparency = 1
	container.ZIndex = 50
	container.Parent = hud

	local btn = Instance.new("TextButton")
	btn.Name = "MobileSprintBtn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	btn.BackgroundTransparency = 0.25
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.ZIndex = 51
	btn.Parent = container
	mobileSprintBtn = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- Circular
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 80, 110)
	stroke.Thickness = 1.5
	stroke.Parent = btn
	mobileStroke = stroke

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 26)
	iconLabel.Position = UDim2.new(0, 0, 0, 6)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 20
	iconLabel.Text = "⚡"
	iconLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	iconLabel.ZIndex = 52
	iconLabel.Parent = btn

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0, 18)
	status.Position = UDim2.new(0, 0, 0, 32)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.TextSize = 11
	status.Text = "OFF"
	status.TextColor3 = Color3.fromRGB(150, 170, 195)
	status.ZIndex = 52
	status.Parent = btn
	mobileStatusLabel = status

	btn.MouseButton1Click:Connect(function()
		MovementController.setSprinting(not isSprinting)
	end)

	MovementController.updateMobileUI()
end

local function clearCharacter()
	generation += 1
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
	currentHumanoid = nil
	isSprinting = false
	if fovTween then
		fovTween:Cancel()
	end
end

local function bindCharacter(character: Model)
	if not character or not character.Parent then return end
	clearCharacter()
	local thisGen = generation

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

	if not humanoid or not root or generation ~= thisGen then return end
	currentHumanoid = humanoid

	table.insert(connections, humanoid.Died:Connect(function()
		if generation ~= thisGen then return end
		isSprinting = false
		updateFov()
	end))

	table.insert(connections, humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if generation ~= thisGen then return end
		updateFov()
	end))

	MovementController.applySpeed()
end

function MovementController.init()
	-- 1. Bind Inputs (Keyboard Shift, Gamepad L3)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			MovementController.setSprinting(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			MovementController.setSprinting(not isSprinting)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			MovementController.setSprinting(false)
		end
	end)

	-- 2. Bind Character Lifecycle
	player.CharacterRemoving:Connect(function(char)
		if player.Character == char then
			clearCharacter()
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.defer(bindCharacter, player.Character)
	end

	-- 3. Sync Data & Gamepass State
	local syncEvent = Remotes.getEvent("SyncData")
	syncEvent.OnClientEvent:Connect(function(data)
		MovementController.updateData(data)
	end)

	local getFunction = Remotes.getFunction("GetPlayerData")
	task.spawn(function()
		local initialData = getFunction:InvokeServer()
		if initialData then
			MovementController.updateData(initialData)
		end
	end)

	local checkGamepassFn = Remotes.getFunction("CheckGamepass")
	task.spawn(function()
		local owns = checkGamepassFn:InvokeServer("SuperSprint")
		if type(owns) == "boolean" then
			ownsSuperSprintPass = owns
			MovementController.applySpeed()
		end
	end)

	-- 4. Setup Mobile Button if touch enabled
	task.defer(function()
		task.wait(0.5)
		setupMobileButton()
	end)

	print("[MovementController] Initialized with cross-platform sprinting (Shift/L3/Touch) and dynamic FOV.")
end

return MovementController
