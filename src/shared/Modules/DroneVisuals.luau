--!strict
-- DroneVisuals: Shared 3D visual generator and ViewportFrame renderer for companion drones & salvage capsules
-- Used by both Server (PetService for in-world floating drones) and Client (MenuController for 3D GUI previews and hatch reveals)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Types)
local Config = require(ReplicatedStorage.Modules.Config)

local DroneVisuals = {}

local function createPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Anchored = false
	p.Parent = parent
	return p
end

local function weldParts(part0: BasePart, part1: BasePart, c0: CFrame): WeldConstraint
	part1.CFrame = part0.CFrame * c0
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = part0
	wc.Part1 = part1
	wc.Parent = part0
	return wc
end

-- Constructs a complete multi-part 3D Sci-Fi Drone Model
function DroneVisuals.createDroneModel(template: Types.PetTemplate?, forViewport: boolean?): Model
	local droneModel = Instance.new("Model")
	local petId = template and template.Id or "drone_rust"
	local petName = template and template.Name or "Drone"
	local petColor = template and template.Color or Color3.fromRGB(160, 130, 110)

	droneModel.Name = "Drone_" .. petName

	-- Primary Core Part
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.4, 1.4, 1.4)
	core.Transparency = 1
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Anchored = (forViewport == true)
	core.Parent = droneModel
	droneModel.PrimaryPart = core

	if petId == "drone_rust" then
		-- RUST BOT (Tier 1 Common): Corroded spherical chassis, cyclops eye, twin ear exhausts, spinning top rotor
		local body = createPart(droneModel, "Body", Vector3.new(1.3, 1.3, 1.3), Color3.fromRGB(150, 115, 90), Enum.Material.CorrodedMetal, Enum.PartType.Ball)
		weldParts(core, body, CFrame.new())

		local eyeRim = createPart(droneModel, "EyeRim", Vector3.new(0.2, 0.6, 0.6), Color3.fromRGB(40, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
		weldParts(core, eyeRim, CFrame.new(0, 0.1, -0.62) * CFrame.Angles(0, math.rad(90), 0))

		local eyeLens = createPart(droneModel, "EyeLens", Vector3.new(0.25, 0.42, 0.42), Color3.fromRGB(225, 135, 30), Enum.Material.Neon, Enum.PartType.Cylinder)
		weldParts(core, eyeLens, CFrame.new(0, 0.1, -0.68) * CFrame.Angles(0, math.rad(90), 0))

		local earL = createPart(droneModel, "EarL", Vector3.new(0.4, 0.35, 0.35), Color3.fromRGB(110, 85, 65), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		weldParts(core, earL, CFrame.new(-0.72, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))

		local earR = createPart(droneModel, "EarR", Vector3.new(0.4, 0.35, 0.35), Color3.fromRGB(110, 85, 65), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		weldParts(core, earR, CFrame.new(0.72, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))

		local mast = createPart(droneModel, "Mast", Vector3.new(0.5, 0.12, 0.12), Color3.fromRGB(80, 80, 85), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		weldParts(core, mast, CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)))

		local rotor = createPart(droneModel, "RotorBlades", Vector3.new(1.6, 0.06, 0.22), Color3.fromRGB(45, 45, 50), Enum.Material.SmoothPlastic)
		weldParts(core, rotor, CFrame.new(0, 1.08, 0))

	elseif petId == "drone_spark" then
		-- SPARK DRONE (Tier 2 Uncommon): Sleek aerodynamic carbon hull, lime stripes, clean visor, twin wing hover nacelles
		local body = createPart(droneModel, "Body", Vector3.new(1.2, 0.55, 1.4), Color3.fromRGB(35, 40, 45), Enum.Material.SmoothPlastic)
		weldParts(core, body, CFrame.new())

		local topArmor = createPart(droneModel, "TopArmor", Vector3.new(0.85, 0.18, 1.1), Color3.fromRGB(55, 60, 68), Enum.Material.SmoothPlastic)
		weldParts(core, topArmor, CFrame.new(0, 0.28, 0))

		local stripe = createPart(droneModel, "Stripe", Vector3.new(0.2, 0.08, 1.25), Color3.fromRGB(60, 200, 125), Enum.Material.Neon)
		weldParts(core, stripe, CFrame.new(0, 0.38, 0))

		local visor = createPart(droneModel, "Visor", Vector3.new(0.9, 0.18, 0.15), Color3.fromRGB(60, 200, 125), Enum.Material.Neon)
		weldParts(core, visor, CFrame.new(0, 0.05, -0.72))

		local wingL = createPart(droneModel, "WingL", Vector3.new(0.65, 0.08, 0.6), Color3.fromRGB(45, 50, 55), Enum.Material.Metal)
		weldParts(core, wingL, CFrame.new(-0.85, 0, 0))

		local nacelleL = createPart(droneModel, "NacelleL", Vector3.new(0.4, 0.55, 0.55), Color3.fromRGB(35, 40, 45), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, nacelleL, CFrame.new(-1.2, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))

		local wingR = createPart(droneModel, "WingR", Vector3.new(0.65, 0.08, 0.6), Color3.fromRGB(45, 50, 55), Enum.Material.Metal)
		weldParts(core, wingR, CFrame.new(0.85, 0, 0))

		local nacelleR = createPart(droneModel, "NacelleR", Vector3.new(0.4, 0.55, 0.55), Color3.fromRGB(35, 40, 45), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, nacelleR, CFrame.new(1.2, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))

	elseif petId == "drone_welder" then
		-- PLASMA WELDER (Tier 3 Rare): Heavy industrial diamond plate chassis, dual cyan fuel tanks, forward plasma blowtorch
		local body = createPart(droneModel, "Body", Vector3.new(1.25, 0.95, 1.3), Color3.fromRGB(65, 75, 85), Enum.Material.DiamondPlate)
		weldParts(core, body, CFrame.new())

		local armorBlue = createPart(droneModel, "ArmorBlue", Vector3.new(1.3, 0.55, 0.85), Color3.fromRGB(50, 150, 255), Enum.Material.SmoothPlastic)
		weldParts(core, armorBlue, CFrame.new(0, 0.12, 0))

		local visor = createPart(droneModel, "Visor", Vector3.new(0.8, 0.2, 0.15), Color3.fromRGB(0, 180, 230), Enum.Material.Neon)
		weldParts(core, visor, CFrame.new(0, 0.15, -0.68))

		local tankL = createPart(droneModel, "TankL", Vector3.new(0.9, 0.38, 0.38), Color3.fromRGB(0, 140, 210), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, tankL, CFrame.new(-0.48, 0.2, 0.65) * CFrame.Angles(0, 0, math.rad(90)))

		local tankR = createPart(droneModel, "TankR", Vector3.new(0.9, 0.38, 0.38), Color3.fromRGB(0, 140, 210), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		weldParts(core, tankR, CFrame.new(0.48, 0.2, 0.65) * CFrame.Angles(0, 0, math.rad(90)))

		local torch = createPart(droneModel, "Torch", Vector3.new(0.35, 0.35, 0.9), Color3.fromRGB(210, 175, 40), Enum.Material.Metal)
		weldParts(core, torch, CFrame.new(0, -0.25, -0.85))

		local flame = createPart(droneModel, "TorchTip", Vector3.new(0.2, 0.2, 0.3), Color3.fromRGB(0, 235, 255), Enum.Material.Neon)
		weldParts(core, flame, CFrame.new(0, -0.25, -1.35))

	elseif petId == "drone_hound" then
		-- SCRAP HOUND (Tier 4 Epic): Robotic canine scout, purple neon visor, cybernetic ears & sensor tail
		local body = createPart(droneModel, "Body", Vector3.new(1.1, 0.8, 1.4), Color3.fromRGB(45, 35, 55), Enum.Material.Metal)
		weldParts(core, body, CFrame.new())

		local head = createPart(droneModel, "Head", Vector3.new(0.85, 0.7, 0.8), Color3.fromRGB(60, 45, 75), Enum.Material.SmoothPlastic)
		weldParts(core, head, CFrame.new(0, 0.3, -0.85))

		local snout = createPart(droneModel, "Snout", Vector3.new(0.55, 0.4, 0.5), Color3.fromRGB(40, 30, 50), Enum.Material.Metal)
		weldParts(core, snout, CFrame.new(0, 0.2, -1.35))

		local eyeVisor = createPart(droneModel, "EyeVisor", Vector3.new(0.7, 0.15, 0.15), Color3.fromRGB(190, 60, 245), Enum.Material.Neon)
		weldParts(core, eyeVisor, CFrame.new(0, 0.42, -1.22))

		local earL = createPart(droneModel, "EarL", Vector3.new(0.18, 0.5, 0.25), Color3.fromRGB(180, 60, 240), Enum.Material.Neon)
		weldParts(core, earL, CFrame.new(-0.4, 0.75, -0.75) * CFrame.Angles(0, 0, math.rad(-15)))

		local earR = createPart(droneModel, "EarR", Vector3.new(0.18, 0.5, 0.25), Color3.fromRGB(180, 60, 240), Enum.Material.Neon)
		weldParts(core, earR, CFrame.new(0.4, 0.75, -0.75) * CFrame.Angles(0, 0, math.rad(15)))

		local tail = createPart(droneModel, "Tail", Vector3.new(0.14, 0.6, 0.14), Color3.fromRGB(190, 60, 245), Enum.Material.Neon, Enum.PartType.Cylinder)
		weldParts(core, tail, CFrame.new(0, 0.45, 0.8) * CFrame.Angles(math.rad(35), 0, 0))

	elseif petId == "drone_mech" or petId == "drone_laser" then
		-- CYBER MECH (Tier 5 Legendary): Golden armored mech drone, dual heavy cannons, visor, glowing thruster
		local body = createPart(droneModel, "Body", Vector3.new(1.3, 1.1, 1.2), Color3.fromRGB(50, 45, 35), Enum.Material.DiamondPlate)
		weldParts(core, body, CFrame.new())

		local chestPlate = createPart(droneModel, "ChestPlate", Vector3.new(1.1, 0.8, 0.3), Color3.fromRGB(245, 175, 25), Enum.Material.SmoothPlastic)
		weldParts(core, chestPlate, CFrame.new(0, 0.05, -0.65))

		local eye = createPart(droneModel, "Visor", Vector3.new(0.85, 0.22, 0.2), Color3.fromRGB(255, 220, 50), Enum.Material.Neon)
		weldParts(core, eye, CFrame.new(0, 0.2, -0.72))

		local cannonL = createPart(droneModel, "CannonL", Vector3.new(0.32, 0.32, 1.3), Color3.fromRGB(180, 130, 20), Enum.Material.Metal, Enum.PartType.Cylinder)
		weldParts(core, cannonL, CFrame.new(-0.85, 0, -0.2))

		local cannonR = createPart(droneModel, "CannonR", Vector3.new(0.32, 0.32, 1.3), Color3.fromRGB(180, 130, 20), Enum.Material.Metal, Enum.PartType.Cylinder)
		weldParts(core, cannonR, CFrame.new(0.85, 0, -0.2))

		local thruster = createPart(droneModel, "Thruster", Vector3.new(0.2, 0.8, 0.8), Color3.fromRGB(255, 195, 30), Enum.Material.Neon, Enum.PartType.Cylinder)
		weldParts(core, thruster, CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90)))

	elseif petId == "drone_titan" then
		-- VOID TITAN (Tier 6 Mythic): Cosmic dark matter singularity core, void crimson energy, crown horns, 4 orbiting void shards
		local body = createPart(droneModel, "Body", Vector3.new(1.25, 1.25, 1.25), Color3.fromRGB(15, 10, 22), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		weldParts(core, body, CFrame.new())

		local singularity = createPart(droneModel, "Singularity", Vector3.new(0.85, 0.85, 0.85), Color3.fromRGB(230, 30, 90), Enum.Material.Neon, Enum.PartType.Ball)
		weldParts(core, singularity, CFrame.new())

		local eye = createPart(droneModel, "VoidEye", Vector3.new(0.2, 0.45, 0.45), Color3.fromRGB(255, 245, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		weldParts(core, eye, CFrame.new(0, 0.05, -0.62) * CFrame.Angles(0, math.rad(90), 0))

		local hornL = createPart(droneModel, "HornL", Vector3.new(0.2, 0.75, 0.3), Color3.fromRGB(240, 35, 95), Enum.Material.Neon)
		weldParts(core, hornL, CFrame.new(-0.38, 0.8, -0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(-20)))

		local hornR = createPart(droneModel, "HornR", Vector3.new(0.2, 0.75, 0.3), Color3.fromRGB(240, 35, 95), Enum.Material.Neon)
		weldParts(core, hornR, CFrame.new(0.38, 0.8, -0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(20)))

		-- 4 Orbiting Shards
		local shardOffsets = {
			Vector3.new(-1.25, 0, 0),
			Vector3.new(1.25, 0, 0),
			Vector3.new(0, 0, -1.25),
			Vector3.new(0, 0, 1.25),
		}
		for sIdx, sPos in ipairs(shardOffsets) do
			local shard = createPart(droneModel, "Shard_" .. sIdx, Vector3.new(0.28, 0.55, 0.28), Color3.fromRGB(255, 40, 110), Enum.Material.Neon)
			weldParts(core, shard, CFrame.new(sPos) * CFrame.Angles(math.rad(25), math.rad(45), 0))
		end
	else
		-- Universal Fallback generator
		local body = createPart(droneModel, "Body", Vector3.new(1.2, 1.2, 1.2), petColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		weldParts(core, body, CFrame.new())

		local eye = createPart(droneModel, "Eye", Vector3.new(0.2, 0.45, 0.45), Color3.fromRGB(240, 240, 245), Enum.Material.Neon, Enum.PartType.Cylinder)
		weldParts(core, eye, CFrame.new(0, 0.05, -0.58) * CFrame.Angles(0, math.rad(90), 0))
	end

	return droneModel
end

-- Constructs a complete 3D Sci-Fi Egg Capsule Model
function DroneVisuals.createEggModel(eggKeyOrConf: any, forViewport: boolean?): Model
	local eggConf = type(eggKeyOrConf) == "table" and eggKeyOrConf or Config.Eggs[eggKeyOrConf]
	if not eggConf then
		eggConf = Config.Eggs["RustEgg"] or {
			Name = "Capsule",
			Color = Color3.fromRGB(160, 130, 110),
		}
	end

	local eggModel = Instance.new("Model")
	eggModel.Name = "Egg_" .. (eggConf.Name or "Capsule")

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.6, 2.4, 1.6)
	core.Transparency = 1
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Anchored = (forViewport == true)
	core.Parent = eggModel
	eggModel.PrimaryPart = core

	local themeColor: Color3 = eggConf.Color or Color3.fromRGB(160, 130, 110)

	-- Base incubator pedestal
	local base = createPart(eggModel, "BasePedestal", Vector3.new(0.35, 1.6, 1.6), Color3.fromRGB(30, 34, 42), Enum.Material.Metal, Enum.PartType.Cylinder)
	weldParts(core, base, CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90)))

	-- Inner glowing energy core
	local innerEgg = createPart(eggModel, "InnerCore", Vector3.new(1.1, 1.7, 1.1), themeColor, Enum.Material.Neon, Enum.PartType.Ball)
	weldParts(core, innerEgg, CFrame.new(0, 0.05, 0))

	-- Outer transparent protective capsule shell
	local outerShell = createPart(eggModel, "OuterShell", Vector3.new(1.35, 2.0, 1.35), themeColor, Enum.Material.Glass, Enum.PartType.Ball)
	outerShell.Transparency = 0.35
	weldParts(core, outerShell, CFrame.new(0, 0.05, 0))

	-- Midsection floating neon containment ring
	local ring = createPart(eggModel, "EnergyRing", Vector3.new(0.12, 1.75, 1.75), themeColor, Enum.Material.Neon, Enum.PartType.Cylinder)
	weldParts(core, ring, CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))

	-- Top crown cap
	local cap = createPart(eggModel, "TopCap", Vector3.new(0.25, 0.8, 0.8), Color3.fromRGB(35, 40, 50), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	weldParts(core, cap, CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)))

	local tip = createPart(eggModel, "TopEmitter", Vector3.new(0.15, 0.35, 0.35), themeColor, Enum.Material.Neon, Enum.PartType.Ball)
	weldParts(core, tip, CFrame.new(0, 1.2, 0))

	return eggModel
end

-- Sets up a 3D ViewportFrame with lighting, camera, and rotating drone model
function DroneVisuals.setupViewport(viewport: ViewportFrame, template: Types.PetTemplate?, options: { CamDist: number?, Spin: boolean? }?): (Model, Camera)
	viewport:ClearAllChildren()

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local model = DroneVisuals.createDroneModel(template, true)
	model.Parent = worldModel

	local camera = Instance.new("Camera")
	local camDist = (options and options.CamDist) or 3.2
	camera.CFrame = CFrame.new(Vector3.new(0, 0.35, camDist), Vector3.new(0, 0.1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	viewport.Ambient = Color3.fromRGB(180, 195, 220)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -2, -1)

	if options and options.Spin ~= false then
		local angle = 0
		task.spawn(function()
			while viewport:IsDescendantOf(game) and model.Parent do
				angle = (angle + 1.6) % 360
				model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(angle), 0))
				task.wait(0.03)
			end
		end)
	end

	return model, camera
end

-- Sets up a 3D ViewportFrame with lighting, camera, and rotating egg capsule model
function DroneVisuals.setupEggViewport(viewport: ViewportFrame, eggKeyOrConf: any, options: { CamDist: number?, Spin: boolean? }?): (Model, Camera)
	viewport:ClearAllChildren()

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local model = DroneVisuals.createEggModel(eggKeyOrConf, true)
	model.Parent = worldModel

	local camera = Instance.new("Camera")
	local camDist = (options and options.CamDist) or 3.4
	camera.CFrame = CFrame.new(Vector3.new(0, 0.15, camDist), Vector3.new(0, 0.05, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	viewport.Ambient = Color3.fromRGB(190, 200, 225)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -2, -1)

	if options and options.Spin ~= false then
		local angle = 0
		task.spawn(function()
			while viewport:IsDescendantOf(game) and model.Parent do
				angle = (angle + 1.4) % 360
				model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(angle), 0))
				task.wait(0.03)
			end
		end)
	end

	return model, camera
end

return DroneVisuals
