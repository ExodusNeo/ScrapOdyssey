--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local PetService = {}
local spawnedDrones: { [Player]: { Model } } = {}

-- Helper to create a standardized drone part
local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Helper to weld partB rigidly to partA
local function weldParts(partA: BasePart, partB: BasePart, offsetCFrame: CFrame): WeldConstraint
	partB.CFrame = partA.CFrame * offsetCFrame
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = partA
	wc.Part1 = partB
	wc.Parent = partB
	return wc
end

-- Creates a multi-part Sci-Fi Drone Model tailored to each drone template
function PetService.createDroneModel(template: Types.PetTemplate?): Model
	local droneModel = Instance.new("Model")
	local petId = template and template.Id or "drone_rust"
	local petName = template and template.Name or "Drone"
	local petTier = template and template.Tier or "Common"
	local petColor = template and template.Color or Color3.fromRGB(160, 130, 110)
	local petMult = template and template.Multiplier or 1.0

	droneModel.Name = "Drone_" .. petName

	-- 1. Primary Core Part (Anchored root that lerps with the player)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.4, 1.4, 1.4)
	core.Transparency = 1
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Anchored = true
	core.Parent = droneModel
	droneModel.PrimaryPart = core

	-- Construct distinct multi-part visual geometry based on drone type
	if petId == "drone_rust" then
		-- RUST BOT: Corroded spherical chassis, cyclops eye, twin ear exhausts, spinning top rotor
		local body = createPart(droneModel, "Body", Vector3.new(1.3, 1.3, 1.3), Color3.fromRGB(150, 115, 90), Enum.Material.CorrodedMetal, Enum.PartType.Ball)
		body.CastShadow = true
		weldParts(core, body, CFrame.new())

		-- Cyclops Eye Rim & Lens
		local eyeRim = createPart(droneModel, "EyeRim", Vector3.new(0.2, 0.6, 0.6), Color3.fromRGB(40, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
		weldParts(core, eyeRim, CFrame.new(0, 0.1, -0.62) * CFrame.Angles(0, math.rad(90), 0))

		local eyeLens = createPart(droneModel, "EyeLens", Vector3.new(0.25, 0.42, 0.42), Color3.fromRGB(225, 135, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, eyeLens, CFrame.new(0, 0.1, -0.68) * CFrame.Angles(0, math.rad(90), 0))

		-- Side ear stabilizers
		local earL = createPart(droneModel, "EarL", Vector3.new(0.4, 0.35, 0.35), Color3.fromRGB(110, 85, 65), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		weldParts(core, earL, CFrame.new(-0.72, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))

		local earR = createPart(droneModel, "EarR", Vector3.new(0.4, 0.35, 0.35), Color3.fromRGB(110, 85, 65), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		weldParts(core, earR, CFrame.new(0.72, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))

		-- Top Mast & Spinning Rotor
		local mast = createPart(droneModel, "Mast", Vector3.new(0.5, 0.12, 0.12), Color3.fromRGB(80, 80, 85), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		weldParts(core, mast, CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)))

		local rotorBlades = createPart(droneModel, "RotorBlades", Vector3.new(1.6, 0.06, 0.22), Color3.fromRGB(45, 45, 50), Enum.Material.SmoothPlastic)
		rotorBlades.CFrame = core.CFrame * CFrame.new(0, 1.08, 0)
		rotorBlades:SetAttribute("SpinType", "Rotor")
		rotorBlades:SetAttribute("SpinOffset", Vector3.new(0, 1.08, 0))
		rotorBlades:SetAttribute("SpinRate", 22)

		-- Bottom exhaust with subtle smoke puff
		local exhaust = createPart(droneModel, "Exhaust", Vector3.new(0.3, 0.38, 0.38), Color3.fromRGB(60, 60, 65), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		weldParts(core, exhaust, CFrame.new(0, -0.68, 0) * CFrame.Angles(0, 0, math.rad(90)))

	elseif petId == "drone_spark" then
		-- SPARK DRONE: Sleek aerodynamic carbon hull, lime stripes, clean visor, twin wing hover nacelles
		local body = createPart(droneModel, "Body", Vector3.new(1.2, 0.55, 1.4), Color3.fromRGB(35, 40, 45), Enum.Material.SmoothPlastic)
		body.CastShadow = true
		weldParts(core, body, CFrame.new())

		local topArmor = createPart(droneModel, "TopArmor", Vector3.new(0.85, 0.18, 1.1), Color3.fromRGB(55, 60, 68), Enum.Material.SmoothPlastic)
		weldParts(core, topArmor, CFrame.new(0, 0.28, 0))

		local neonStripe = createPart(droneModel, "Stripe", Vector3.new(0.2, 0.08, 1.25), Color3.fromRGB(60, 200, 125), Enum.Material.SmoothPlastic)
		weldParts(core, neonStripe, CFrame.new(0, 0.38, 0))

		local visor = createPart(droneModel, "Visor", Vector3.new(0.9, 0.18, 0.15), Color3.fromRGB(60, 200, 125), Enum.Material.SmoothPlastic)
		weldParts(core, visor, CFrame.new(0, 0.05, -0.72))

		-- Twin Outrigger Wings & Hover Nacelles
		local wingL = createPart(droneModel, "WingL", Vector3.new(0.65, 0.08, 0.6), Color3.fromRGB(45, 50, 55), Enum.Material.Metal)
		weldParts(core, wingL, CFrame.new(-0.85, 0, 0))

		local nacelleL = createPart(droneModel, "NacelleL", Vector3.new(0.4, 0.55, 0.55), Color3.fromRGB(35, 40, 45), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, nacelleL, CFrame.new(-1.2, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))

		local ringL = createPart(droneModel, "RingL", Vector3.new(0.44, 0.38, 0.38), Color3.fromRGB(60, 200, 125), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, ringL, CFrame.new(-1.2, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))

		local wingR = createPart(droneModel, "WingR", Vector3.new(0.65, 0.08, 0.6), Color3.fromRGB(45, 50, 55), Enum.Material.Metal)
		weldParts(core, wingR, CFrame.new(0.85, 0, 0))

		local nacelleR = createPart(droneModel, "NacelleR", Vector3.new(0.4, 0.55, 0.55), Color3.fromRGB(35, 40, 45), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, nacelleR, CFrame.new(1.2, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))

		local ringR = createPart(droneModel, "RingR", Vector3.new(0.44, 0.38, 0.38), Color3.fromRGB(60, 200, 125), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, ringR, CFrame.new(1.2, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))

	elseif petId == "drone_welder" then
		-- PLASMA WELDER: Heavy industrial diamond plate chassis, dual cyan fuel tanks, forward plasma blowtorch
		local body = createPart(droneModel, "Body", Vector3.new(1.25, 0.95, 1.3), Color3.fromRGB(65, 75, 85), Enum.Material.DiamondPlate)
		body.CastShadow = true
		weldParts(core, body, CFrame.new())

		local armorBlue = createPart(droneModel, "ArmorBlue", Vector3.new(1.3, 0.55, 0.85), Color3.fromRGB(50, 150, 255), Enum.Material.SmoothPlastic)
		weldParts(core, armorBlue, CFrame.new(0, 0.12, 0))

		local visor = createPart(droneModel, "Visor", Vector3.new(0.8, 0.2, 0.15), Color3.fromRGB(0, 180, 230), Enum.Material.SmoothPlastic)
		weldParts(core, visor, CFrame.new(0, 0.15, -0.68))

		-- Dual rear plasma tanks
		local tankL = createPart(droneModel, "TankL", Vector3.new(0.9, 0.38, 0.38), Color3.fromRGB(0, 140, 210), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, tankL, CFrame.new(-0.48, 0.2, 0.65) * CFrame.Angles(0, 0, math.rad(90)))

		local tankR = createPart(droneModel, "TankR", Vector3.new(0.9, 0.38, 0.38), Color3.fromRGB(0, 140, 210), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, tankR, CFrame.new(0.48, 0.2, 0.65) * CFrame.Angles(0, 0, math.rad(90)))

		-- Articulated forward plasma torch arm
		local arm = createPart(droneModel, "TorchArm", Vector3.new(0.18, 0.18, 0.75), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
		weldParts(core, arm, CFrame.new(0.45, -0.2, -0.85))

		local nozzle = createPart(droneModel, "TorchNozzle", Vector3.new(0.3, 0.25, 0.25), Color3.fromRGB(80, 80, 85), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		weldParts(core, nozzle, CFrame.new(0.45, -0.2, -1.25) * CFrame.Angles(math.rad(90), 0, 0))

		local flame = createPart(droneModel, "TorchFlame", Vector3.new(0.26, 0.26, 0.35), Color3.fromRGB(160, 225, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		weldParts(core, flame, CFrame.new(0.45, -0.2, -1.45))

	elseif petId == "drone_hound" then
		-- SCRAP HOUND: Angular predatory cyber chassis, angled cyber ears, violet visor, twin ion thrusters
		local body = createPart(droneModel, "Body", Vector3.new(1.1, 0.75, 1.65), Color3.fromRGB(42, 34, 56), Enum.Material.Metal)
		body.CastShadow = true
		weldParts(core, body, CFrame.new())

		local head = createPart(droneModel, "Head", Vector3.new(0.85, 0.55, 0.75), Color3.fromRGB(55, 45, 75), Enum.Material.Metal)
		weldParts(core, head, CFrame.new(0, 0.1, -0.95))

		local visor = createPart(droneModel, "Visor", Vector3.new(0.72, 0.16, 0.15), Color3.fromRGB(200, 50, 255), Enum.Material.SmoothPlastic)
		weldParts(core, visor, CFrame.new(0, 0.15, -1.35))

		-- Angled cybernetic ears
		local earL = createPart(droneModel, "EarL", Vector3.new(0.16, 0.45, 0.25), Color3.fromRGB(70, 55, 95), Enum.Material.Metal)
		weldParts(core, earL, CFrame.new(-0.35, 0.45, -0.75) * CFrame.Angles(math.rad(-15), 0, math.rad(-15)))

		local earR = createPart(droneModel, "EarR", Vector3.new(0.16, 0.45, 0.25), Color3.fromRGB(70, 55, 95), Enum.Material.Metal)
		weldParts(core, earR, CFrame.new(0.35, 0.45, -0.75) * CFrame.Angles(math.rad(-15), 0, math.rad(15)))

		-- Rear twin violet ion thrusters
		local jetL = createPart(droneModel, "JetL", Vector3.new(0.5, 0.35, 0.35), Color3.fromRGB(35, 30, 45), Enum.Material.Metal, Enum.PartType.Cylinder)
		weldParts(core, jetL, CFrame.new(-0.36, 0.05, 0.9) * CFrame.Angles(math.rad(90), 0, 0))

		local plumeL = createPart(droneModel, "PlumeL", Vector3.new(0.4, 0.25, 0.25), Color3.fromRGB(175, 45, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, plumeL, CFrame.new(-0.36, 0.05, 1.1) * CFrame.Angles(math.rad(90), 0, 0))

		local jetR = createPart(droneModel, "JetR", Vector3.new(0.5, 0.35, 0.35), Color3.fromRGB(35, 30, 45), Enum.Material.Metal, Enum.PartType.Cylinder)
		weldParts(core, jetR, CFrame.new(0.36, 0.05, 0.9) * CFrame.Angles(math.rad(90), 0, 0))

		local plumeR = createPart(droneModel, "PlumeR", Vector3.new(0.4, 0.25, 0.25), Color3.fromRGB(175, 45, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, plumeR, CFrame.new(0.36, 0.05, 1.1) * CFrame.Angles(math.rad(90), 0, 0))

	elseif petId == "drone_mech" then
		-- CYBER MECH: Heavy military chassis in gold & charcoal, central pulsing reactor, dual wing blasters
		local body = createPart(droneModel, "Body", Vector3.new(1.35, 1.15, 1.4), Color3.fromRGB(215, 155, 25), Enum.Material.Metal)
		body.CastShadow = true
		weldParts(core, body, CFrame.new())

		local chestArmor = createPart(droneModel, "ChestArmor", Vector3.new(1.4, 0.7, 0.8), Color3.fromRGB(40, 42, 48), Enum.Material.SmoothPlastic)
		weldParts(core, chestArmor, CFrame.new(0, 0.1, 0))

		-- Central Glowing Reactor
		local reactor = createPart(droneModel, "Reactor", Vector3.new(0.2, 0.55, 0.55), Color3.fromRGB(230, 175, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, reactor, CFrame.new(0, 0.1, -0.72) * CFrame.Angles(0, math.rad(90), 0))

		local visor = createPart(droneModel, "Visor", Vector3.new(0.75, 0.16, 0.15), Color3.fromRGB(225, 50, 35), Enum.Material.SmoothPlastic)
		weldParts(core, visor, CFrame.new(0, 0.42, -0.65))

		-- Dual Heavy Wing Pylons & Plasma Blaster Cannons
		local wingL = createPart(droneModel, "WingL", Vector3.new(1.15, 0.12, 0.7), Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
		weldParts(core, wingL, CFrame.new(-1.2, 0.2, 0.1) * CFrame.Angles(0, 0, math.rad(10)))

		local gunL = createPart(droneModel, "GunL", Vector3.new(1.3, 0.22, 0.22), Color3.fromRGB(80, 85, 90), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		weldParts(core, gunL, CFrame.new(-1.3, 0.05, -0.3) * CFrame.Angles(math.rad(90), 0, 0))

		local tipL = createPart(droneModel, "TipL", Vector3.new(0.25, 0.24, 0.24), Color3.fromRGB(225, 150, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, tipL, CFrame.new(-1.3, 0.05, -0.98) * CFrame.Angles(math.rad(90), 0, 0))

		local wingR = createPart(droneModel, "WingR", Vector3.new(1.15, 0.12, 0.7), Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
		weldParts(core, wingR, CFrame.new(1.2, 0.2, 0.1) * CFrame.Angles(0, 0, math.rad(-10)))

		local gunR = createPart(droneModel, "GunR", Vector3.new(1.3, 0.22, 0.22), Color3.fromRGB(80, 85, 90), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		weldParts(core, gunR, CFrame.new(1.3, 0.05, -0.3) * CFrame.Angles(math.rad(90), 0, 0))

		local tipR = createPart(droneModel, "TipR", Vector3.new(0.25, 0.24, 0.24), Color3.fromRGB(225, 150, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, tipR, CFrame.new(1.3, 0.05, -0.98) * CFrame.Angles(math.rad(90), 0, 0))

		-- Bottom repulsor turbine
		local repulsor = createPart(droneModel, "Repulsor", Vector3.new(0.15, 0.95, 0.95), Color3.fromRGB(225, 160, 25), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, repulsor, CFrame.new(0, -0.65, 0) * CFrame.Angles(0, 0, math.rad(90)))

	elseif petId == "drone_titan" then
		-- VOID TITAN: Cosmic dark matter singularity core, void crimson energy, floating crown crest, 4 orbiting void shards!
		local body = createPart(droneModel, "Body", Vector3.new(1.25, 1.25, 1.25), Color3.fromRGB(15, 10, 22), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		body.CastShadow = true
		weldParts(core, body, CFrame.new())

		local singularity = createPart(droneModel, "Singularity", Vector3.new(0.85, 0.85, 0.85), Color3.fromRGB(160, 25, 70), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		weldParts(core, singularity, CFrame.new())

		local eye = createPart(droneModel, "VoidEye", Vector3.new(0.2, 0.45, 0.45), Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, eye, CFrame.new(0, 0.05, -0.62) * CFrame.Angles(0, math.rad(90), 0))

		-- Void Crown Horns
		local hornL = createPart(droneModel, "HornL", Vector3.new(0.18, 0.7, 0.3), Color3.fromRGB(180, 25, 70), Enum.Material.SmoothPlastic)
		weldParts(core, hornL, CFrame.new(-0.35, 0.75, -0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(-20)))

		local hornR = createPart(droneModel, "HornR", Vector3.new(0.18, 0.7, 0.3), Color3.fromRGB(180, 25, 70), Enum.Material.SmoothPlastic)
		weldParts(core, hornR, CFrame.new(0.35, 0.75, -0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(20)))

		-- 4 Orbiting Shards
		local shardPositions = {
			Vector3.new(-1.3, 0, 0),
			Vector3.new(1.3, 0, 0),
			Vector3.new(0, 0, -1.3),
			Vector3.new(0, 0, 1.3),
		}

		for sIdx, sPos in ipairs(shardPositions) do
			local shard = createPart(droneModel, "Shard_" .. sIdx, Vector3.new(0.28, 0.55, 0.28), Color3.fromRGB(180, 30, 80), Enum.Material.SmoothPlastic)
			shard.CFrame = core.CFrame * CFrame.new(sPos) * CFrame.Angles(math.rad(25), math.rad(45), 0)
			shard:SetAttribute("SpinType", "Orbit")
			shard:SetAttribute("OrbitPos", sPos)
			shard:SetAttribute("SpinRate", 14)
		end

	else
		-- Fallback generator for custom or Gears perks drones
		local body = createPart(droneModel, "Body", Vector3.new(1.2, 1.2, 1.2), petColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		weldParts(core, body, CFrame.new())

		local eye = createPart(droneModel, "Eye", Vector3.new(0.2, 0.45, 0.45), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, eye, CFrame.new(0, 0.05, -0.58) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- 2. Sci-Fi Floating BillboardGui Tag
	local bb = Instance.new("BillboardGui")
	bb.Name = "DroneTag"
	bb.Size = UDim2.new(0, 130, 0, 36)
	bb.StudsOffset = Vector3.new(0, 1.7, 0)
	bb.AlwaysOnTop = true
	bb.Parent = core

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = petColor
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = petColor
	nameLabel.Text = string.format("[%s] %s", string.upper(petTier), petName)
	nameLabel.Parent = frame

	local multLabel = Instance.new("TextLabel")
	multLabel.Size = UDim2.new(1, 0, 0.45, 0)
	multLabel.Position = UDim2.new(0, 0, 0.52, 0)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamMedium
	multLabel.TextSize = 10
	multLabel.TextColor3 = Color3.fromRGB(220, 230, 240)
	multLabel.Text = string.format("+%.1fx Scrap Bonus", petMult)
	multLabel.Parent = frame

	return droneModel
end

function PetService.rollPet(eggType: string?): Types.PetTemplate
	local eggConf = eggType and Config.Eggs[eggType]
	if eggConf and #eggConf.Pool > 0 then
		local totalWeight = 0
		for _, item in ipairs(eggConf.Pool) do
			totalWeight = totalWeight + item.Weight
		end

		local roll = math.random() * totalWeight
		local cumulative = 0
		local pickedId = eggConf.Pool[1].Id

		for _, item in ipairs(eggConf.Pool) do
			cumulative = cumulative + item.Weight
			if roll <= cumulative then
				pickedId = item.Id
				break
			end
		end

		for _, template in ipairs(Config.Pets.List) do
			if template.Id == pickedId then
				return template
			end
		end
	end

	-- Fallback to global list
	local totalWeight = 0
	for _, pet in ipairs(Config.Pets.List) do
		totalWeight = totalWeight + pet.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, pet in ipairs(Config.Pets.List) do
		cumulative = cumulative + pet.Weight
		if roll <= cumulative then
			return pet
		end
	end

	return Config.Pets.List[1]
end

function PetService.hatchEgg(player: Player, eggType: string?): Types.PetTemplate?
	local data = DataService.get(player)
	if not data then return nil end

	local selectedType = (eggType and Config.Eggs[eggType]) and eggType or "RustEgg"
	local eggConf = Config.Eggs[selectedType]
	local cost = eggConf.Cost

	if not CurrencyService.removeScrap(player, cost) then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Not Enough Scrap", string.format("You need %d Scrap to hatch %s.", cost, eggConf.Name), Color3.fromRGB(255, 70, 70))
		return nil
	end

	local rolled = PetService.rollPet(selectedType)
	local newOwnedPet: Types.OwnedPet = {
		UUID = HttpService:GenerateGUID(false),
		Id = rolled.Id,
		Level = 1,
		Equipped = false,
	}

	table.insert(data.Pets, newOwnedPet)
	DataService.sync(player)

	pcall(function()
		local QuestService = require(script.Parent.QuestService)
		QuestService.recordDroneHatched(player, 1)
	end)

	-- Fire reveal event to client
	local hatchResult = Remotes.getEvent("HatchResult")
	hatchResult:FireClient(player, {
		Template = rolled,
		Pet = newOwnedPet,
		EggName = eggConf.Name,
	})

	return rolled
end

function PetService.toggleEquip(player: Player, uuid: string)
	local data = DataService.get(player)
	if not data then return end

	local targetPet: Types.OwnedPet? = nil
	local currentlyEquippedCount = 0

	for _, p in ipairs(data.Pets) do
		if p.UUID == uuid then
			targetPet = p
		end
		if p.Equipped then
			currentlyEquippedCount = currentlyEquippedCount + 1
		end
	end

	if not targetPet then return end

	if targetPet.Equipped then
		targetPet.Equipped = false
	else
		if currentlyEquippedCount >= Config.Defaults.MaxEquippedPets then
			local notif = Remotes.getEvent("ShowNotification")
			notif:FireClient(player, "Limit Reached", string.format("You can only equip up to %d drones at once.", Config.Defaults.MaxEquippedPets), Color3.fromRGB(255, 170, 0))
			return
		end
		targetPet.Equipped = true
	end

	DataService.sync(player)
	PetService.updateVisualDrones(player)
end

function PetService.updateVisualDrones(player: Player)
	-- Clean up old drones
	if spawnedDrones[player] then
		for _, m in ipairs(spawnedDrones[player]) do
			m:Destroy()
		end
	end
	spawnedDrones[player] = {}

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not rootPart then return end

	local data = DataService.get(player)
	if not data then return end

	local equippedPets = {}
	for _, p in ipairs(data.Pets) do
		if p.Equipped then
			table.insert(equippedPets, p)
		end
	end

	local petAngles = { -45, 45, 0 }
	local petDistances = { 5, 5, 7 }

	for i, pet in ipairs(equippedPets) do
		local template: Types.PetTemplate? = nil
		for _, t in ipairs(Config.Pets.List) do
			if t.Id == pet.Id then
				template = t
				break
			end
		end

		local droneModel = PetService.createDroneModel(template)
		local initialCF = rootPart.CFrame * CFrame.new(0, 2, 5)
		droneModel:PivotTo(initialCF)

		droneModel.Parent = Workspace
		table.insert(spawnedDrones[player], droneModel)

		-- Collect any animated spinning parts for this drone (e.g. rotors, orbiting singularity shards)
		local spinningParts: { BasePart } = {}
		for _, desc in ipairs(droneModel:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("SpinType") ~= nil then
				table.insert(spinningParts, desc)
			end
		end

		-- Drone follower heartbeat
		local angleOffset = math.rad(petAngles[i] or 0)
		local dist = petDistances[i] or 5

		task.spawn(function()
			while droneModel.Parent and player.Parent and character.Parent and rootPart.Parent do
				local now = os.clock()
				local bob = math.sin(now * 2.8 + i * 1.6) * 0.35
				local rootCF = rootPart.CFrame

				-- Target position orbiting behind player
				local targetPosCF = rootCF * CFrame.Angles(0, angleOffset, 0) * CFrame.new(0, 2.2 + bob, dist)
				-- Face towards movement direction
				local lookPos = targetPosCF.Position + rootCF.LookVector * 10
				local targetCF = CFrame.lookAt(targetPosCF.Position, lookPos)

				droneModel:PivotTo(droneModel:GetPivot():Lerp(targetCF, 0.18))

				-- Spin any animated parts in lockstep relative to the core
				for _, sp in ipairs(spinningParts) do
					if sp.Parent and core and core.Parent then
						local spinType = sp:GetAttribute("SpinType")
						local rate = (sp:GetAttribute("SpinRate") :: number) or 10
						local angle = math.rad(now * rate * 30 % 360)
						if spinType == "Rotor" then
							local offset = (sp:GetAttribute("SpinOffset") :: Vector3) or Vector3.new(0, 1.08, 0)
							sp.CFrame = core.CFrame * CFrame.new(offset) * CFrame.Angles(0, angle, 0)
						elseif spinType == "Orbit" then
							local orbitPos = (sp:GetAttribute("OrbitPos") :: Vector3) or Vector3.new(1.3, 0, 0)
							sp.CFrame = core.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(orbitPos) * CFrame.Angles(math.rad(25), math.rad(45), 0)
						end
					end
				end

				task.wait(0.03)
			end
		end)
	end
end

function PetService.init()
	local hatchEvent = Remotes.getEvent("HatchEgg")
	hatchEvent.OnServerEvent:Connect(function(player, eggType)
		PetService.hatchEgg(player, type(eggType) == "string" and eggType or "RustEgg")
	end)

	local equipEvent = Remotes.getEvent("EquipPet")
	equipEvent.OnServerEvent:Connect(function(player, uuid)
		if type(uuid) == "string" then
			PetService.toggleEquip(player, uuid)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(1, function()
				PetService.updateVisualDrones(player)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if spawnedDrones[player] then
			for _, m in ipairs(spawnedDrones[player]) do
				m:Destroy()
			end
			spawnedDrones[player] = nil
		end
	end)

	print("[PetService] Initialized with 3D Sci-Fi Drone Models.")
end

return PetService
