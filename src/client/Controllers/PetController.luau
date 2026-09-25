--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local DroneVisuals = require(ReplicatedStorage.Modules.DroneVisuals)

local PetController = {}
local localPlayer = Players.LocalPlayer

-- Active drone tracking table: [droneModel] = true
local activeDrones: { [Model]: boolean } = {}

-- Cache spinning parts per drone model so we don't query GetDescendants every frame
local droneSpinParts: { [Model]: { BasePart } } = {}

-- Constructs and mounts a PlayerGui BillboardGui with a spinning 3D Sci-Fi Egg Capsule model
-- (Identical 3D rotating capsule preview to the hatch capsules in the Drone Hangar modal)
local function registerEggPod(pod: Instance)
	if not pod:IsA("Model") then return end
	local eggType = pod:GetAttribute("EggType") :: string?
	if not eggType and string.sub(pod.Name, 1, 7) == "EggPod_" then
		eggType = string.sub(pod.Name, 8)
	end
	if not eggType then return end

	local eggConf = Config.Eggs[eggType]
	if not eggConf then return end

	local capsule = pod:FindFirstChild("Capsule") :: BasePart?
	if not capsule then
		capsule = pod:WaitForChild("Capsule", 3) :: BasePart?
	end
	if not capsule then return end

	-- Clean up any legacy server billboard in Workspace so it doesn't duplicate
	for _, child in ipairs(pod:GetChildren()) do
		if child:IsA("BillboardGui") then
			child:Destroy()
		end
	end

	local playerGui = localPlayer and (localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 5)) :: PlayerGui?
	if not playerGui then return end

	local bbName = "EggDisplay_" .. eggType
	local existing = playerGui:FindFirstChild(bbName)
	if existing then existing:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = bbName
	bb.Adornee = capsule
	bb.Size = UDim2.new(0, 310, 0, 84)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	bb.Parent = playerGui

	local bbFrame = Instance.new("Frame")
	bbFrame.Size = UDim2.new(1, 0, 1, 0)
	bbFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	bbFrame.BackgroundTransparency = 0.12
	bbFrame.BorderSizePixel = 0
	bbFrame.Parent = bb

	local bbc = Instance.new("UICorner")
	bbc.CornerRadius = UDim.new(0, 10)
	bbc.Parent = bbFrame

	local bbs = Instance.new("UIStroke")
	bbs.Color = eggConf.Color
	bbs.Thickness = 1.5
	bbs.Parent = bbFrame

	-- 3D Egg Capsule Viewport Box (Exact design from the Hatch Capsules in Drone Hangar)
	local vpBox = Instance.new("Frame")
	vpBox.Name = "ViewportBox"
	vpBox.Size = UDim2.new(0, 60, 0, 60)
	vpBox.Position = UDim2.new(0, 10, 0.5, -30)
	vpBox.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
	vpBox.BorderSizePixel = 0
	vpBox.Parent = bbFrame

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 10)
	vpCorner.Parent = vpBox

	local vpStroke = Instance.new("UIStroke")
	vpStroke.Color = eggConf.Color
	vpStroke.Thickness = 1.2
	vpStroke.Parent = vpBox

	local vp = Instance.new("ViewportFrame")
	vp.Name = "EggViewport"
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.BackgroundTransparency = 1
	vp.ZIndex = 2
	vp.Parent = vpBox

	-- Setup the 3D rotating capsule model matching the hatch capsule visuals
	DroneVisuals.setupEggViewport(vp, eggType, { CamDist = 3.3, Spin = true })

	-- Format comma helper
	local formattedCost = tostring(math.floor(eggConf.Cost))
	while true do
		local k
		formattedCost, k = string.gsub(formattedCost, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end

	-- Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -80, 0, 24)
	nameLabel.Position = UDim2.new(0, 78, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = eggConf.Color
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = string.upper(eggConf.Name)
	nameLabel.Parent = bbFrame

	-- Cost Label
	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, -80, 0, 20)
	costLabel.Position = UDim2.new(0, 78, 0, 26)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamBlack
	costLabel.TextSize = 13
	costLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.Text = string.format("COST: %s SCRAP", formattedCost)
	costLabel.Parent = bbFrame

	-- Odds Label
	if eggConf.SubText then
		local oddsLabel = Instance.new("TextLabel")
		oddsLabel.Size = UDim2.new(1, -80, 0, 24)
		oddsLabel.Position = UDim2.new(0, 78, 0, 48)
		oddsLabel.BackgroundTransparency = 1
		oddsLabel.Font = Enum.Font.GothamMedium
		oddsLabel.TextSize = 10
		oddsLabel.TextColor3 = Color3.fromRGB(180, 195, 215)
		oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
		oddsLabel.Text = string.gsub(eggConf.SubText, "\n", " | ")
		oddsLabel.Parent = bbFrame
	end
end

local function registerDrone(drone: Instance)
	if not drone:IsA("Model") then return end
	if not drone:GetAttribute("OwnerUserId") then return end

	activeDrones[drone] = true

	local spinningParts: { BasePart } = {}
	for _, desc in ipairs(drone:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("SpinType") ~= nil then
			table.insert(spinningParts, desc)
		end
	end
	droneSpinParts[drone] = spinningParts

	drone.Destroying:Connect(function()
		activeDrones[drone] = nil
		droneSpinParts[drone] = nil
	end)
end

function PetController.init()
	-- Collect any existing drones
	for _, drone in ipairs(CollectionService:GetTagged("EquippedDrone")) do
		registerDrone(drone)
	end
	CollectionService:GetInstanceAddedSignal("EquippedDrone"):Connect(registerDrone)
	CollectionService:GetInstanceRemovedSignal("EquippedDrone"):Connect(function(drone)
		if drone:IsA("Model") then
			activeDrones[drone] = nil
			droneSpinParts[drone] = nil
		end
	end)

	-- Also listen to Workspace for any Drone models added dynamically
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") and (child:GetAttribute("OwnerUserId") ~= nil or string.find(child.Name, "Drone_") ~= nil) then
			task.wait(0.05)
			registerDrone(child)
		end
	end)
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and (child:GetAttribute("OwnerUserId") ~= nil or string.find(child.Name, "Drone_") ~= nil) then
			registerDrone(child)
		end
	end

	-- Mount 3D rotating capsule billboards in PlayerGui for each egg pod in the zone
	for _, pod in ipairs(CollectionService:GetTagged("EggPod")) do
		task.spawn(registerEggPod, pod)
	end
	CollectionService:GetInstanceAddedSignal("EggPod"):Connect(function(pod)
		task.spawn(registerEggPod, pod)
	end)
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("Model") and string.sub(desc.Name, 1, 7) == "EggPod_" then
			task.spawn(registerEggPod, desc)
		end
	end)
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Model") and string.sub(desc.Name, 1, 7) == "EggPod_" then
			task.spawn(registerEggPod, desc)
		end
	end

	-- Refresh billboards on character respawn
	localPlayer.CharacterAdded:Connect(function()
		task.wait(0.2)
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("Model") and string.sub(desc.Name, 1, 7) == "EggPod_" then
				task.spawn(registerEggPod, desc)
			end
		end
	end)

	-- High-precision, silky-smooth RenderStepped update loop running at full monitor framerate (60 / 120 / 144 / 240 Hz)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()

		for drone, _ in pairs(activeDrones) do
			if not drone.Parent or not drone.PrimaryPart then
				activeDrones[drone] = nil
				droneSpinParts[drone] = nil
				continue
			end

			local ownerId = drone:GetAttribute("OwnerUserId")
			if not ownerId then continue end

			local ownerPlayer = Players:GetPlayerByUserId(ownerId)
			local character = ownerPlayer and ownerPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

			if rootPart and rootPart.Parent then
				local angleOffset = (drone:GetAttribute("AngleOffset") :: number) or 0
				local dist = (drone:GetAttribute("FollowDist") :: number) or 5
				local slotIdx = (drone:GetAttribute("SlotIndex") :: number) or 1

				-- Gentle floating vertical bobbing
				local bob = math.sin(now * 2.8 + slotIdx * 1.6) * 0.32

				local rootCF = rootPart.CFrame

				-- Target position relative to player
				local targetPosCF = rootCF * CFrame.Angles(0, angleOffset, 0) * CFrame.new(0, 2.2 + bob, dist)
				local lookPos = targetPosCF.Position + rootCF.LookVector * 12

				-- Dynamic aerodynamic banking into motion (leans forward on acceleration, banks into turns)
				local vel = rootPart.AssemblyLinearVelocity
				local localVel = rootCF:VectorToObjectSpace(vel)
				local bankRoll = math.clamp(-localVel.X * 0.014, -0.22, 0.22)
				local pitchTilt = math.clamp(localVel.Z * 0.010, -0.16, 0.16)

				local targetCF = CFrame.lookAt(targetPosCF.Position, lookPos) * CFrame.Angles(pitchTilt, 0, bankRoll)

				local currentCF = drone:GetPivot()
				local distToTarget = (targetPosCF.Position - currentCF.Position).Magnitude

				if distToTarget > 45 then
					-- Instant snap on zone warp / teleport
					drone:PivotTo(targetCF)
				else
					-- Framerate-independent exponential decay smoothing
					-- Guarantees identical response time at 60 FPS, 144 FPS, or 240 FPS
					local lerpFactor = 1 - math.exp(-14 * dt)
					drone:PivotTo(currentCF:Lerp(targetCF, lerpFactor))
				end

				-- Butter-smooth spinning animations at full client framerate
				local core = drone.PrimaryPart
				local spinning = droneSpinParts[drone]
				if core and spinning then
					for _, sp in ipairs(spinning) do
						if sp.Parent then
							local spinType = sp:GetAttribute("SpinType")
							local rate = (sp:GetAttribute("SpinRate") :: number) or 10
							local angle = math.rad((now * rate * 30) % 360)
							if spinType == "Rotor" then
								local offset = (sp:GetAttribute("SpinOffset") :: Vector3) or Vector3.new(0, 1.08, 0)
								sp.CFrame = core.CFrame * CFrame.new(offset) * CFrame.Angles(0, angle, 0)
							elseif spinType == "Orbit" then
								local orbitPos = (sp:GetAttribute("OrbitPos") :: Vector3) or Vector3.new(1.3, 0, 0)
								sp.CFrame = core.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(orbitPos) * CFrame.Angles(math.rad(25), math.rad(45), 0)
							end
						end
					end
				end
			end
		end
	end)

	print("[PetController] Initialized: 144Hz RenderStepped smooth drone movement & animations active.")
end

return PetController
