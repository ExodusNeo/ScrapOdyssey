--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local PetController = {}
local localPlayer = Players.LocalPlayer

-- Active drone tracking table: [droneModel] = true
local activeDrones: { [Model]: boolean } = {}

-- Cache spinning parts per drone model so we don't query GetDescendants every frame
local droneSpinParts: { [Model]: { BasePart } } = {}

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
