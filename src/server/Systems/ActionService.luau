--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local ActionService = {}
local playerLastActionTime: { [Player]: number } = {}
local nodeCooldown: { [Model]: boolean } = {}
local playerCombo: { [Player]: { Count: number, LastHitTime: number } } = {}

-- Procedural 3D Scrapper Tool Construction (5 Tiers)
function ActionService.buildTool(toolId: string): Tool
	local conf = Config.getTool(toolId) or Config.Tools[1]

	local tool = Instance.new("Tool")
	tool.Name = conf.Name
	tool.ToolTip = string.format("%s (Damage: %d)", conf.Name, conf.Damage)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -0.3) * CFrame.Angles(math.rad(-75), 0, 0)
	tool:SetAttribute("IsScrapperTool", true)
	tool:SetAttribute("ToolId", conf.Id)
	tool:SetAttribute("Damage", conf.Damage)
	tool:SetAttribute("Cooldown", conf.Cooldown)
	tool:SetAttribute("Range", conf.Range)

	-- Main Ergonomic Handle Grip (Fits directly in player's palm)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Material = Enum.Material.Rubber
	handle.Color = Color3.fromRGB(30, 32, 40)
	handle.CanCollide = false
	handle.Parent = tool

	local function getGroup(groupName: string): Model
		local g = tool:FindFirstChild(groupName)
		if not g then
			g = Instance.new("Model")
			g.Name = groupName
			g.Parent = tool
		end
		return g
	end

	-- Helper to create welded tool parts attached to the Handle
	local function createToolPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, partType: Enum.PartType?, groupName: string?): Part
		local p = Instance.new("Part")
		p.Name = name
		if partType then
			p.Shape = partType
		end
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.CanCollide = false
		p.CastShadow = true
		if groupName then
			p.Parent = getGroup(groupName)
		else
			p.Parent = tool
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- 1. OmniWrench: Titan Heavy Hydraulic Scrap-Wrench
	if conf.Id == "OmniWrench" then
		tool.Grip = CFrame.new(0, 0, -0.15) * CFrame.Angles(math.rad(15), 0, 0)
		handle.Size = Vector3.new(0.55, 1.3, 0.55)
		handle.Color = Color3.fromRGB(245, 175, 25) -- Industrial Hazard Yellow
		handle.Material = Enum.Material.DiamondPlate

		-- Textured Grip Ribs (Black rubber rings around yellow handle)
		for r = -2, 2 do
			createToolPart("GripRing_" .. r, Vector3.new(0.62, 0.12, 0.62), handle.CFrame * CFrame.new(0, r * 0.24, 0), Color3.fromRGB(24, 26, 32), Enum.Material.Rubber, nil, "GripComponents")
		end

		-- Heavy Brass Pommel Counterweight
		createToolPart("BrassPommel", Vector3.new(0.4, 0.75, 0.75), handle.CFrame * CFrame.new(0, -0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 165, 45), Enum.Material.Metal, Enum.PartType.Cylinder, "GripComponents")

		-- Knuckle Guard with Battery Status LED
		local guard = createToolPart("KnuckleGuard", Vector3.new(0.25, 1.2, 0.9), handle.CFrame * CFrame.new(0, 0, 0.5), Color3.fromRGB(45, 50, 60), Enum.Material.Metal, nil, "GripComponents")
		createToolPart("StatusLED", Vector3.new(0.15, 0.35, 0.15), guard.CFrame * CFrame.new(0, 0.2, 0.45), Color3.fromRGB(40, 220, 90), Enum.Material.Neon, nil, "GripComponents")

		-- Heavy Motor Housing Chamber (Safety Yellow & DiamondPlate)
		local housing = createToolPart("MotorHousing", Vector3.new(1.8, 1.4, 1.4), handle.CFrame * CFrame.new(0, 1.2, 0), Color3.fromRGB(245, 175, 25), Enum.Material.DiamondPlate, nil, "MotorHousing")
		-- Black Hazard Stripe on Housing
		createToolPart("HazardStripe", Vector3.new(1.85, 0.3, 1.45), housing.CFrame * CFrame.new(0, 0, 0), Color3.fromRGB(25, 26, 30), Enum.Material.SmoothPlastic, nil, "MotorHousing")

		-- High-Pressure Chrome Hydraulic Cylinder & Orange Fluid Hose
		createToolPart("ChromePiston", Vector3.new(1.6, 0.65, 0.65), housing.CFrame * CFrame.new(1.0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(225, 230, 240), Enum.Material.Metal, Enum.PartType.Cylinder, "MotorHousing")
		createToolPart("FluidHose", Vector3.new(1.4, 0.3, 0.3), housing.CFrame * CFrame.new(1.2, 0.2, 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 95, 25), Enum.Material.Rubber, Enum.PartType.Cylinder, "MotorHousing")

		-- Massive Interlocking Forged Jaws (3.4 studs wide total!)
		-- Fixed Base Jaw (Heavy hardened steel with carbon teeth)
		local fixedJaw = createToolPart("FixedJaw", Vector3.new(1.4, 1.8, 0.8), housing.CFrame * CFrame.new(-0.8, 1.3, 0), Color3.fromRGB(55, 60, 72), Enum.Material.DiamondPlate, nil, "JawMechanism")
		createToolPart("JawTeethLower", Vector3.new(0.9, 0.8, 0.85), fixedJaw.CFrame * CFrame.new(0.3, 0.4, 0), Color3.fromRGB(35, 38, 45), Enum.Material.Metal, nil, "JawMechanism")

		-- Upper Articulated Hydraulic Clamp Jaw
		local upperJaw = createToolPart("UpperJaw", Vector3.new(1.5, 1.6, 0.8), housing.CFrame * CFrame.new(0.6, 1.6, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(245, 175, 25), Enum.Material.DiamondPlate, nil, "JawMechanism")
		createToolPart("JawTeethUpper", Vector3.new(0.9, 0.7, 0.85), upperJaw.CFrame * CFrame.new(-0.3, 0.3, 0), Color3.fromRGB(35, 38, 45), Enum.Material.Metal, nil, "JawMechanism")

		-- Knurled Bronze Worm Adjustment Gear in Throat
		createToolPart("WormGear", Vector3.new(0.8, 0.9, 0.9), housing.CFrame * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(215, 155, 40), Enum.Material.Metal, Enum.PartType.Cylinder, "JawMechanism")

		-- Glowing Amber Magnetic Induction Core in Throat
		local core = createToolPart("InductionCore", Vector3.new(0.9, 0.9, 0.9), housing.CFrame * CFrame.new(0, 1.4, 0), Color3.fromRGB(255, 175, 30), Enum.Material.Neon, Enum.PartType.Ball, "EnergyCore")
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 185, 35)
		light.Brightness = 2.8
		light.Range = 14
		light.Parent = core

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "InductionSparks"
		sparks.Texture = "rbxassetid://258129523"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100), Color3.fromRGB(255, 130, 20))
		sparks.Size = NumberSequence.new(0.12, 0.35)
		sparks.Rate = 12
		sparks.Speed = NumberRange.new(2, 6)
		sparks.Lifetime = NumberRange.new(0.2, 0.5)
		sparks.Parent = core

	-- 2. PneumaticDrill: Vortex Impact Breaker Auger
	elseif conf.Id == "PneumaticDrill" then
		tool.Grip = CFrame.new(0, 0, -0.3) * CFrame.Angles(math.rad(75), 0, 0)
		handle.Size = Vector3.new(0.6, 1.4, 0.6)
		handle.Color = Color3.fromRGB(32, 35, 42)
		handle.Material = Enum.Material.Rubber

		-- D-Handle Loop & Safety Trigger
		createToolPart("DHandleLoop", Vector3.new(0.3, 1.5, 1.0), handle.CFrame * CFrame.new(0, 0, -0.6), Color3.fromRGB(48, 52, 62), Enum.Material.Metal, nil, "GripComponents")
		createToolPart("SafetyTrigger", Vector3.new(0.2, 0.5, 0.35), handle.CFrame * CFrame.new(0, 0.2, -0.35), Color3.fromRGB(235, 55, 45), Enum.Material.SmoothPlastic, nil, "GripComponents")

		-- Dual Lateral Grip Handlebars (Extending left and right)
		createToolPart("BarCross", Vector3.new(2.4, 0.35, 0.35), handle.CFrame * CFrame.new(0, -0.4, 0), Color3.fromRGB(45, 48, 56), Enum.Material.Metal, nil, "GripComponents")
		createToolPart("HandleGripL", Vector3.new(0.45, 0.45, 0.45), handle.CFrame * CFrame.new(-1.1, -0.4, 0), Color3.fromRGB(235, 105, 25), Enum.Material.Rubber, nil, "GripComponents")
		createToolPart("HandleGripR", Vector3.new(0.45, 0.45, 0.45), handle.CFrame * CFrame.new(1.1, -0.4, 0), Color3.fromRGB(235, 105, 25), Enum.Material.Rubber, nil, "GripComponents")

		-- Heavy Engine Body (Safety Orange)
		local engine = createToolPart("EngineBody", Vector3.new(1.8, 1.8, 1.8), handle.CFrame * CFrame.new(0, 1.3, 0), Color3.fromRGB(235, 100, 25), Enum.Material.DiamondPlate, nil, "EngineAssembly")
		for f = -1, 1 do
			createToolPart("EngineFin_" .. f, Vector3.new(1.95, 0.15, 1.95), engine.CFrame * CFrame.new(0, f * 0.5, 0), Color3.fromRGB(35, 38, 46), Enum.Material.Metal, nil, "EngineAssembly")
		end

		-- Twin Nitrogen Flasks (Cyan with brass gauges)
		for _, xOff in ipairs({ -1.1, 1.1 }) do
			local flask = createToolPart("NitrogenFlask", Vector3.new(1.6, 0.7, 0.7), engine.CFrame * CFrame.new(xOff, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(45, 185, 215), Enum.Material.Metal, Enum.PartType.Cylinder, "EngineAssembly")
			createToolPart("BrassValve", Vector3.new(0.3, 0.4, 0.4), flask.CFrame * CFrame.new(0.85, 0, 0), Color3.fromRGB(215, 160, 45), Enum.Material.Metal, Enum.PartType.Cylinder, "EngineAssembly")
			createToolPart("GaugeDial", Vector3.new(0.2, 0.35, 0.35), flask.CFrame * CFrame.new(0.3, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 245, 250), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, "EngineAssembly")
		end

		-- Heavy Keyed Chuck Collar
		local chuck = createToolPart("DrillChuck", Vector3.new(0.8, 1.4, 1.4), engine.CFrame * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(50, 54, 64), Enum.Material.DiamondPlate, Enum.PartType.Cylinder, "AugerBit")

		-- Stepped Conical Spiral Auger Bit (Tapering to a glowing chisel tip)
		local augerBase = createToolPart("AugerBaseCone", Vector3.new(1.2, 1.8, 1.8), chuck.CFrame * CFrame.new(0.9, 0, 0), Color3.fromRGB(75, 82, 95), Enum.Material.DiamondPlate, Enum.PartType.Cylinder, "AugerBit")
		local augerMid = createToolPart("AugerMidCone", Vector3.new(1.2, 1.3, 1.3), augerBase.CFrame * CFrame.new(1.0, 0, 0), Color3.fromRGB(255, 115, 20), Enum.Material.Neon, Enum.PartType.Cylinder, "AugerBit")
		local augerTip = createToolPart("AugerChiselTip", Vector3.new(1.0, 0.8, 0.8), augerMid.CFrame * CFrame.new(0.9, 0, 0), Color3.fromRGB(255, 195, 45), Enum.Material.Neon, Enum.PartType.Cylinder, "AugerBit")

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 30)
		light.Brightness = 3.0
		light.Range = 16
		light.Parent = augerTip

		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "DrillExhaust"
		smoke.Texture = "rbxassetid://243098098"
		smoke.Color = ColorSequence.new(Color3.fromRGB(220, 225, 235))
		smoke.Size = NumberSequence.new(0.2, 0.6)
		smoke.Rate = 12
		smoke.Speed = NumberRange.new(3, 7)
		smoke.Lifetime = NumberRange.new(0.3, 0.6)
		smoke.Parent = engine

	-- 3. PlasmaCutter: Thermal Arc Lance & Dismantler
	elseif conf.Id == "PlasmaCutter" then
		tool.Grip = CFrame.new(0, 0, -0.3) * CFrame.Angles(math.rad(75), 0, 0)
		handle.Size = Vector3.new(0.55, 1.4, 0.55)
		handle.Color = Color3.fromRGB(28, 34, 46)
		handle.Material = Enum.Material.Rubber

		-- Ergonomic Pistol Grip & Trigger
		createToolPart("TriggerGuard", Vector3.new(0.2, 1.0, 0.7), handle.CFrame * CFrame.new(0, 0, 0.4), Color3.fromRGB(42, 48, 62), Enum.Material.Metal, nil, "GripComponents")
		createToolPart("PlasmaTrigger", Vector3.new(0.2, 0.45, 0.3), handle.CFrame * CFrame.new(0, 0.2, 0.25), Color3.fromRGB(235, 55, 45), Enum.Material.SmoothPlastic, nil, "GripComponents")

		-- Heavy Plasma Receiver Chassis (Titanium Slate & Cyan Trim)
		local chassis = createToolPart("PlasmaChassis", Vector3.new(1.6, 2.4, 1.4), handle.CFrame * CFrame.new(0, 1.4, 0.1), Color3.fromRGB(36, 44, 58), Enum.Material.DiamondPlate, nil, "ChassisAssembly")
		-- Exposed Glowing Cryo-Plasma Fuel Vial along Spine
		createToolPart("PlasmaFuelVial", Vector3.new(1.8, 0.65, 0.65), chassis.CFrame * CFrame.new(0, 0, -0.65) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 240, 215), Enum.Material.Neon, Enum.PartType.Cylinder, "ChassisAssembly")
		createToolPart("FuelVialGlass", Vector3.new(1.9, 0.8, 0.8), chassis.CFrame * CFrame.new(0, 0, -0.65) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 245, 255), Enum.Material.Glass, Enum.PartType.Cylinder, "ChassisAssembly")

		-- Tactical Underside Foregrip
		createToolPart("TacticalForegrip", Vector3.new(0.5, 1.0, 0.5), chassis.CFrame * CFrame.new(0, -0.4, 0.6), Color3.fromRGB(24, 28, 36), Enum.Material.Rubber, nil, "GripComponents")

		-- Dual Forward-Swept Magnetic Rail Horns
		createToolPart("RailHornL", Vector3.new(0.5, 2.4, 0.7), chassis.CFrame * CFrame.new(-0.8, 1.8, 0) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(215, 150, 45), Enum.Material.Metal, nil, "EmitterHorns")
		createToolPart("RailHornR", Vector3.new(0.5, 2.4, 0.7), chassis.CFrame * CFrame.new(0.8, 1.8, 0) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(215, 150, 45), Enum.Material.Metal, nil, "EmitterHorns")

		-- Massive Continuous Plasma Torch Blade (Electric Cyan & White-Hot Core)
		local bladeCore = createToolPart("PlasmaBladeCore", Vector3.new(0.9, 3.2, 0.35), chassis.CFrame * CFrame.new(0, 2.2, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, nil, "PlasmaBlade")
		local bladeGlow = createToolPart("PlasmaBladeGlow", Vector3.new(1.3, 3.4, 0.55), bladeCore.CFrame, Color3.fromRGB(35, 235, 215), Enum.Material.Neon, nil, "PlasmaBlade")

		-- Holographic Crosshair Reticle Ring
		createToolPart("HoloReticle", Vector3.new(0.15, 0.8, 0.8), chassis.CFrame * CFrame.new(0, 0.6, 0.9) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 245, 220), Enum.Material.Neon, Enum.PartType.Cylinder, "ChassisAssembly")

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(35, 235, 215)
		light.Brightness = 3.5
		light.Range = 18
		light.Parent = bladeGlow

		local plasmaArcs = Instance.new("ParticleEmitter")
		plasmaArcs.Name = "PlasmaArcs"
		plasmaArcs.Texture = "rbxassetid://258129523"
		plasmaArcs.Color = ColorSequence.new(Color3.fromRGB(200, 255, 255), Color3.fromRGB(35, 215, 200))
		plasmaArcs.Size = NumberSequence.new(0.15, 0.45)
		plasmaArcs.Rate = 16
		plasmaArcs.Speed = NumberRange.new(3, 8)
		plasmaArcs.Lifetime = NumberRange.new(0.15, 0.35)
		plasmaArcs.SpreadAngle = Vector2.new(25, 25)
		plasmaArcs.Parent = bladeGlow

	-- 4. CyberScythe: High-Frequency Nanite War-Scythe
	elseif conf.Id == "CyberScythe" then
		tool.Grip = CFrame.new(0, 0, -0.2) * CFrame.Angles(math.rad(15), 0, 0)
		handle.Size = Vector3.new(0.5, 1.4, 0.5)
		handle.Color = Color3.fromRGB(20, 22, 28)
		handle.Material = Enum.Material.Metal

		-- Lower Staff Extension & Grounding Tungsten Spike
		createToolPart("LowerStaff", Vector3.new(0.45, 1.6, 0.45), handle.CFrame * CFrame.new(0, -1.2, 0), Color3.fromRGB(35, 40, 52), Enum.Material.DiamondPlate, nil, "StaffAssembly")
		createToolPart("GroundSpike", Vector3.new(0.5, 0.7, 0.5), handle.CFrame * CFrame.new(0, -2.2, 0), Color3.fromRGB(80, 88, 105), Enum.Material.Metal, nil, "StaffAssembly")

		-- Upper Staff Extension with Dual Spine Neon Conduits
		local upperStaff = createToolPart("UpperStaff", Vector3.new(0.5, 2.2, 0.5), handle.CFrame * CFrame.new(0, 1.6, 0), Color3.fromRGB(35, 40, 52), Enum.Material.DiamondPlate, nil, "StaffAssembly")
		createToolPart("ConduitL", Vector3.new(0.15, 2.4, 0.15), upperStaff.CFrame * CFrame.new(-0.25, 0, 0), Color3.fromRGB(240, 50, 215), Enum.Material.Neon, nil, "StaffAssembly")
		createToolPart("ConduitR", Vector3.new(0.15, 2.4, 0.15), upperStaff.CFrame * CFrame.new(0.25, 0, 0), Color3.fromRGB(40, 220, 245), Enum.Material.Neon, nil, "StaffAssembly")

		-- Articulated Scythe Neck Hub & Gyroscopic Core Ring
		local hub = createToolPart("ScytheHub", Vector3.new(1.4, 1.4, 1.4), upperStaff.CFrame * CFrame.new(0, 1.4, 0), Color3.fromRGB(45, 48, 62), Enum.Material.Metal, nil, "NeckHub")
		createToolPart("GyroRing", Vector3.new(0.5, 1.8, 1.8), hub.CFrame * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(245, 55, 220), Enum.Material.Neon, Enum.PartType.Cylinder, "NeckHub")

		-- Rear Scrapper Claw / Hook (Points backwards +Z)
		createToolPart("RearHook", Vector3.new(0.5, 1.4, 1.2), hub.CFrame * CFrame.new(0, 0.4, 1.0) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(60, 68, 85), Enum.Material.DiamondPlate, nil, "NeckHub")

		-- Colossal Sweeping Crescent Energy Blade (Curving forward -Z!)
		local bladeSpine = createToolPart("BladeSpine", Vector3.new(0.5, 0.8, 3.6), hub.CFrame * CFrame.new(0, 0.8, -1.8) * CFrame.Angles(-math.rad(30), 0, 0), Color3.fromRGB(30, 32, 42), Enum.Material.Metal, nil, "EnergyBlade")
		local bladeEdge = createToolPart("EnergyEdge", Vector3.new(0.25, 0.6, 4.2), bladeSpine.CFrame * CFrame.new(0, -0.4, -0.2), Color3.fromRGB(245, 55, 220), Enum.Material.Neon, nil, "EnergyBlade")
		createToolPart("EdgeTip", Vector3.new(0.2, 1.6, 1.2), bladeEdge.CFrame * CFrame.new(0, -0.5, -1.8) * CFrame.Angles(math.rad(35), 0, 0), Color3.fromRGB(45, 235, 255), Enum.Material.Neon, nil, "EnergyBlade")

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(245, 55, 220)
		light.Brightness = 3.5
		light.Range = 18
		light.Parent = bladeEdge

		local lightning = Instance.new("ParticleEmitter")
		lightning.Name = "NaniteLightning"
		lightning.Texture = "rbxassetid://258129523"
		lightning.Color = ColorSequence.new(Color3.fromRGB(255, 80, 230), Color3.fromRGB(50, 240, 255))
		lightning.Size = NumberSequence.new(0.15, 0.45)
		lightning.Rate = 18
		lightning.Speed = NumberRange.new(3, 8)
		lightning.Lifetime = NumberRange.new(0.2, 0.45)
		lightning.Parent = bladeEdge

	-- 5. VoidRipper: Dark-Matter Graviton Singularity Cleaver
	elseif conf.Id == "VoidRipper" then
		tool.Grip = CFrame.new(0, 0, -0.2) * CFrame.Angles(math.rad(20), 0, 0)
		handle.Size = Vector3.new(0.65, 1.4, 0.65)
		handle.Color = Color3.fromRGB(22, 18, 28)
		handle.Material = Enum.Material.Rubber

		-- Spiked Void Pommel Cap
		createToolPart("VoidPommel", Vector3.new(0.4, 0.8, 0.8), handle.CFrame * CFrame.new(0, -0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(52, 40, 68), Enum.Material.Metal, Enum.PartType.Cylinder, "HiltAssembly")
		createToolPart("PommelSpike", Vector3.new(0.35, 0.6, 0.35), handle.CFrame * CFrame.new(0, -1.2, 0), Color3.fromRGB(180, 50, 255), Enum.Material.Neon, nil, "HiltAssembly")

		-- Massive Dreadnought Armor Crossguard (3.2 studs wide!)
		local guard = createToolPart("DreadnoughtGuard", Vector3.new(3.2, 0.9, 1.2), handle.CFrame * CFrame.new(0, 1.0, 0), Color3.fromRGB(45, 36, 60), Enum.Material.DiamondPlate, nil, "Crossguard")
		createToolPart("GuardFinL", Vector3.new(0.4, 1.4, 1.3), guard.CFrame * CFrame.new(-1.6, 0.4, 0), Color3.fromRGB(185, 55, 255), Enum.Material.Neon, nil, "Crossguard")
		createToolPart("GuardFinR", Vector3.new(0.4, 1.4, 1.3), guard.CFrame * CFrame.new(1.6, 0.4, 0), Color3.fromRGB(185, 55, 255), Enum.Material.Neon, nil, "Crossguard")

		-- Colossal Broad Guillotine Cleaver Blade (Asymmetric Dreadnought Plate)
		-- Width: 2.8 studs, Height: 4.2 studs, Thickness: 0.7 studs
		local bladeBody = createToolPart("CleaverBody", Vector3.new(2.6, 4.2, 0.65), guard.CFrame * CFrame.new(0.4, 2.4, 0), Color3.fromRGB(38, 30, 52), Enum.Material.Metal, nil, "CleaverBlade")

		-- Jagged Serrated Cutting Edge with Glowing Energy Teeth
		local edge = createToolPart("SerratedCuttingEdge", Vector3.new(0.6, 4.4, 0.75), bladeBody.CFrame * CFrame.new(1.3, 0, 0), Color3.fromRGB(60, 48, 80), Enum.Material.DiamondPlate, nil, "CleaverBlade")
		for t = 1, 4 do
			createToolPart("PlasmaTooth_" .. t, Vector3.new(0.5, 0.6, 0.8), edge.CFrame * CFrame.new(0.3, -1.8 + ((t - 1) * 1.2), 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(195, 60, 255), Enum.Material.Neon, nil, "CleaverBlade")
		end

		-- Central Hollow Vortex Aperture Ring
		createToolPart("SingularityAperture", Vector3.new(0.4, 1.8, 1.8), bladeBody.CFrame * CFrame.new(0, -0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 20, 35), Enum.Material.Metal, Enum.PartType.Cylinder, "SingularityCore")

		-- Levitating Dark Matter Singularity Sphere in the aperture
		local core = createToolPart("SingularityCore", Vector3.new(1.2, 1.2, 1.2), bladeBody.CFrame * CFrame.new(0, -0.4, 0), Color3.fromRGB(195, 60, 255), Enum.Material.Neon, Enum.PartType.Ball, "SingularityCore")
		createToolPart("AccretionHalo", Vector3.new(0.2, 1.6, 1.6), core.CFrame * CFrame.Angles(math.rad(45), 0, math.rad(30)), Color3.fromRGB(235, 120, 255), Enum.Material.Neon, Enum.PartType.Cylinder, "SingularityCore")

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(195, 60, 255)
		light.Brightness = 3.8
		light.Range = 18
		light.Parent = core

		local vortex = Instance.new("ParticleEmitter")
		vortex.Name = "VoidVortex"
		vortex.Texture = "rbxassetid://258129523"
		vortex.Color = ColorSequence.new(Color3.fromRGB(240, 100, 255), Color3.fromRGB(130, 30, 220))
		vortex.Size = NumberSequence.new(0.18, 0.65)
		vortex.Rate = 22
		vortex.Speed = NumberRange.new(2, 6)
		vortex.Lifetime = NumberRange.new(0.3, 0.7)
		vortex.SpreadAngle = Vector2.new(180, 180)
		vortex.Parent = core
	end

	return tool
end

-- Give or update the player's equipped scrapper tool
function ActionService.giveScrapperTool(player: Player)
	local data = DataService.get(player)
	local toolId = data and data.EquippedTool or "OmniWrench"
	local conf = Config.getTool(toolId) or Config.Tools[1]

	-- Clear out any existing scrapper tools in Character & Backpack
	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and (item:GetAttribute("IsScrapperTool") or item:GetAttribute("ToolId") ~= nil or item.Name == "ScrapperTool" or item.Name == conf.Name) then
				item:Destroy()
			end
		end
	end

	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and (item:GetAttribute("IsScrapperTool") or item:GetAttribute("ToolId") ~= nil or item.Name == "ScrapperTool" or item.Name == conf.Name) then
				item:Destroy()
			end
		end

		local tool = ActionService.buildTool(toolId)
		tool.Parent = backpack

		-- Auto-equip tool to character's hand if humanoid exists
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				task.defer(function()
					if tool.Parent == backpack and character.Parent then
						humanoid:EquipTool(tool)
					end
				end)
			end
		end
		print(string.format("[ActionService] Successfully granted %s (%s) to %s", conf.Name, toolId, player.Name))
	end
end

-- Equip an owned tool
function ActionService.equipTool(player: Player, toolId: string)
	local data = DataService.get(player)
	if not data then return end
	if not data.OwnedTools then
		data.OwnedTools = { ["OmniWrench"] = true }
	end
	if toolId == "OmniWrench" then
		data.OwnedTools["OmniWrench"] = true
	end
	if not data.OwnedTools[toolId] then return end

	data.EquippedTool = toolId
	DataService.sync(player)
	ActionService.giveScrapperTool(player)

	local conf = Config.getTool(toolId)
	if conf then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Tool Equipped", string.format("Equipped %s (%s)!", conf.Name, conf.Emoji), conf.Color)
	end
end

-- Purchase and equip a tool from the Armory
function ActionService.purchaseTool(player: Player, toolId: string)
	local data = DataService.get(player)
	if not data then return end
	local conf = Config.getTool(toolId)
	if not conf then return end

	data.OwnedTools = data.OwnedTools or { ["OmniWrench"] = true }
	if data.OwnedTools[toolId] then
		ActionService.equipTool(player, toolId)
		return
	end

	if data.Scrap < conf.Cost then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Insufficient Scrap", string.format("You need %s Scrap to purchase the %s!", tostring(conf.Cost), conf.Name), Color3.fromRGB(255, 75, 75))
		return
	end

	data.Scrap -= conf.Cost
	data.OwnedTools[toolId] = true
	data.EquippedTool = toolId
	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)
	ActionService.giveScrapperTool(player)

	local notif = Remotes.getEvent("ShowNotification")
	notif:FireClient(player, "Tool Unlocked!", string.format("Unlocked and equipped %s (%s)!", conf.Name, conf.Emoji), conf.Color)
end

-- Roll reward tier with SuperLuck perk support
function ActionService.rollRewardTier(player: Player): Types.RewardTier
	local data = DataService.get(player)
	local hasSuperLuck = data and data.GearsPerks and data.GearsPerks["SuperLuck"]

	local totalWeight = 0
	local adjustedTiers = {}

	for _, tier in ipairs(Config.RewardTiers) do
		local weight = tier.Weight
		if hasSuperLuck and tier.Name ~= "Common" then
			weight = weight * 2.5
		end
		totalWeight = totalWeight + weight
		table.insert(adjustedTiers, { Tier = tier, Weight = weight })
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, item in ipairs(adjustedTiers) do
		cumulative = cumulative + item.Weight
		if roll <= cumulative then
			return item.Tier
		end
	end

	return Config.RewardTiers[1]
end

-- Multi-Hit Crunchy Dismantling Action
function ActionService.performScrapAction(player: Player, nodeModel: Model)
	if not nodeModel or typeof(nodeModel) ~= "Instance" or not nodeModel:IsA("Model") or not nodeModel:IsDescendantOf(Workspace) then return end
	if nodeCooldown[nodeModel] then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not rootPart then return end

	local nodeHitbox = (nodeModel:FindFirstChild("Hitbox") or nodeModel.PrimaryPart or nodeModel:FindFirstChildWhichIsA("BasePart")) :: BasePart?
	if not nodeHitbox then return end

	local data = DataService.get(player)
	if not data then return end

	local toolConf = Config.getTool(data.EquippedTool or "OmniWrench")
	local maxRange = (toolConf and toolConf.Range or 8) + 4

	-- 1. Distance Sanity Check (requires close melee proximity to node surface)
	local nodeRadius = nodeHitbox.Size.Magnitude * 0.35
	local distance = math.max(0, (rootPart.Position - nodeHitbox.Position).Magnitude - nodeRadius)
	if distance > maxRange then return end

	-- 2. Cooldown & Capacity Check
	local bagLevel = (data.Upgrades and data.Upgrades["BackpackCapacity"]) or 1
	local maxCapacity = Config.getBackpackCapacity(bagLevel)
	local currentBackpack = data.Backpack or 0

	local isOrbital = nodeModel:GetAttribute("IsOrbitalPod") == true

	if not isOrbital and currentBackpack >= maxCapacity then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "CARGO FULL", "Your cargo is full. Step on the Scrap Recycler to bank your scrap.", Color3.fromRGB(255, 70, 70))
		return
	end

	local zoneId = nodeModel:GetAttribute("ZoneId") or 1
	if not isOrbital and zoneId > (data.MaxZoneReached or 1) then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "ZONE RESTRICTED", "Unlock this zone first before harvesting its scrap!", Color3.fromRGB(255, 70, 70))
		return
	end
	local zone = Config.Zones[zoneId]
	local baseActionTime = isOrbital and 1.0 or (zone and zone.ActionTime or 1.0)

	local speedLvl = (data.Upgrades and data.Upgrades["ScrapSpeed"]) or 1
	local speedReduction = (speedLvl - 1) * Config.Upgrades.ScrapSpeed.EffectPerLevel
	local toolCooldown = toolConf and toolConf.Cooldown or 0.45
	local finalActionDelay = math.max(0.12, (baseActionTime * toolCooldown) - speedReduction)

	local now = os.clock()
	local lastTime = playerLastActionTime[player] or 0
	if now - lastTime < (finalActionDelay * 0.65) then return end
	playerLastActionTime[player] = now

	-- 3. Hit Points / Multi-Hit Logic with Tool Damage
	local maxHP = nodeModel:GetAttribute("MaxHP") or 3
	local currentHP = nodeModel:GetAttribute("CurrentHP") or maxHP
	local toolDamage = toolConf and toolConf.Damage or 1
	currentHP = currentHP - toolDamage

	local corePart = nodeModel:FindFirstChild("Core", true) :: BasePart
	local basePart = nodeModel:FindFirstChild("Base", true) :: BasePart
	local statusLabel = nodeModel:FindFirstChild("StatusLabel", true) :: TextLabel

	-- Visual Hit squash & flash (strictly bounded to CoreBaseSize to prevent compounding light growth)
	if corePart then
		local baseSize = nodeModel:GetAttribute("CoreBaseSize") :: Vector3?
		if not baseSize then
			baseSize = corePart.Size
			nodeModel:SetAttribute("CoreBaseSize", baseSize)
		end

		local squashTween = TweenService:Create(corePart, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Size = baseSize * 1.08,
		})
		squashTween:Play()
		task.delay(0.12, function()
			if corePart and corePart.Parent then
				corePart.Size = baseSize
			end
		end)
	end

	if basePart then
		local origColor = basePart.Color
		basePart.Color = Color3.fromRGB(255, 255, 255)
		task.delay(0.1, function()
			if basePart and basePart.Parent then
				basePart.Color = origColor
			end
		end)
	end

	local tier = ActionService.rollRewardTier(player)
	local baseYield = nodeModel:GetAttribute("BaseYield") or (zone and zone.BaseYield) or 10
	local isDense = nodeModel:GetAttribute("IsDense")

	-- Active Gameplay Engagement: Combo Streak & Critical Salvage Calculation
	local comboInfo = playerCombo[player]
	if not comboInfo then
		comboInfo = { Count = 0, LastHitTime = 0 }
		playerCombo[player] = comboInfo
	end
	local comboWindow = (Config.Engagement and Config.Engagement.ComboWindow) or 3.8
	local maxCombo = (Config.Engagement and Config.Engagement.MaxCombo) or 10
	local bonusPerCombo = (Config.Engagement and Config.Engagement.BonusPerCombo) or 0.05

	if now - comboInfo.LastHitTime <= comboWindow then
		comboInfo.Count = math.min(maxCombo, comboInfo.Count + 1)
	else
		comboInfo.Count = 1
	end
	comboInfo.LastHitTime = now

	local comboMult = 1.0 + ((comboInfo.Count - 1) * bonusPerCombo)

	-- Critical Salvage Proc
	local critChance = (Config.Engagement and Config.Engagement.CritChance) or 0.12
	local critMultiplier = (Config.Engagement and Config.Engagement.CritMultiplier) or 2.0
	local isCrit = (math.random() <= critChance)
	local effectiveCritMult = isCrit and critMultiplier or 1.0

	if currentHP > 0 then
		-- Partial Strike: Fill backpack partially
		nodeModel:SetAttribute("CurrentHP", currentHP)
		local isOrbital = nodeModel:GetAttribute("IsOrbitalPod") == true
		if statusLabel then
			if isOrbital then
				statusLabel.Text = "ORBITAL RAID POD"
			elseif isDense then
				statusLabel.Text = string.format("DENSE %s", zone.Name:upper())
			else
				statusLabel.Text = zone.Name:upper()
			end
		end
		local hpLabel = nodeModel:FindFirstChild("HpLabel", true) :: TextLabel?
		if hpLabel then
			hpLabel.Text = string.format("[ %d / %d HP ]", currentHP, maxHP)
		elseif statusLabel then
			statusLabel.Text = string.format("%s\n[HP: %d/%d]", zone.Name:upper(), currentHP, maxHP)
		end

		local barFill = nodeModel:FindFirstChild("HealthBarFill", true) :: Frame?
		if barFill then
			local pct = math.clamp(currentHP / maxHP, 0, 1)
			barFill.Size = UDim2.new(pct, 0, 1, 0)
			if pct > 0.5 then
				barFill.BackgroundColor3 = Color3.fromRGB(40, 215, 95)
			elseif pct > 0.25 then
				barFill.BackgroundColor3 = Color3.fromRGB(245, 175, 30)
			else
				barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
			end
		end

		local damageRatio = math.clamp(toolDamage / maxHP, 0.15, 1.0)
		local strikeScrap = 0
		local added = 0

		if isOrbital then
			local EventService = require(script.Parent.EventService)
			EventService.recordDamage(player, toolDamage)
		else
			strikeScrap = math.max(1, math.floor(((baseYield * tier.Multiplier) * (damageRatio * 0.75)) * comboMult * effectiveCritMult))
			local spaceLeft = math.max(0, maxCapacity - (data.Backpack or 0))
			added = math.min(spaceLeft, strikeScrap)
			data.Backpack = (data.Backpack or 0) + added
			DataService.sync(player)
			CurrencyService.updateLeaderstats(player)

			pcall(function()
				local BackpackService = require(script.Parent.BackpackService)
				BackpackService.updateCoreColor(player)
			end)
		end

		local displayTierName = isOrbital and "ORBITAL RAID" or (isCrit and ("[CRIT] " .. (isDense and "DENSE" or tier.Name)) or (isDense and "Dense Hit" or "Hit"))
		local displayTierColor = isOrbital and Color3.fromRGB(255, 140, 20) or (isCrit and Color3.fromRGB(255, 215, 0) or (isDense and Color3.fromRGB(0, 240, 255) or Color3.fromRGB(200, 200, 200)))
		local soundPitch = isOrbital and 1.35 or (isCrit and 1.55 or (0.9 + math.random() * 0.2))

		local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
		actionCompletedEvent:FireClient(player, {
			IsBreak = false,
			IsDense = (isDense == true),
			IsOrbital = isOrbital,
			DamageDealt = toolDamage,
			MaxHP = maxHP,
			CurrentHP = currentHP,
			TierName = displayTierName,
			TierColor = displayTierColor,
			ScrapEarned = added,
			SoundPitch = soundPitch,
			Combo = comboInfo.Count,
			IsCrit = isCrit,
			Position = nodeHitbox.Position + Vector3.new(0, 3, 0),
		})
	else
		-- Final Break Strike: Big reward into backpack!
		nodeModel:SetAttribute("CurrentHP", 0)
		nodeCooldown[nodeModel] = true

		if isOrbital then
			local EventService = require(script.Parent.EventService)
			EventService.recordDamage(player, toolDamage)

			local totalScrapPool = nodeModel:GetAttribute("TotalScrapPool") or 80000
			local totalGearsPool = nodeModel:GetAttribute("TotalGearsPool") or 40
			local contribs, totalDmg = EventService.getContributions()
			if totalDmg <= 0 then totalDmg = 1 end

			local sortedContributors: { { Player: Player, Damage: number } } = {}
			for contribPlayer, dmg in pairs(contribs) do
				table.insert(sortedContributors, { Player = contribPlayer, Damage = dmg })
			end
			table.sort(sortedContributors, function(a, b) return a.Damage > b.Damage end)

			for _, entry in ipairs(sortedContributors) do
				local cPlayer = entry.Player
				if cPlayer and cPlayer.Parent then
					local fraction = math.clamp(entry.Damage / totalDmg, 0, 1)
					local scrapReward = math.max(1000, math.floor(totalScrapPool * fraction))
					local gearsReward = math.max(1, math.floor(totalGearsPool * fraction))
					local pct = math.floor(fraction * 100)

					CurrencyService.addScrap(cPlayer, scrapReward, true)
					CurrencyService.addGears(cPlayer, gearsReward)

					local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
					actionCompletedEvent:FireClient(cPlayer, {
						IsBreak = true,
						IsOrbital = true,
						ScrapEarned = scrapReward,
						GearsEarned = gearsReward,
						DamagePercent = pct,
						Position = nodeHitbox.Position + Vector3.new(0, 4, 0),
					})

					local notif = Remotes.getEvent("ShowNotification")
					notif:FireClient(
						cPlayer,
						"RAID REWARD CLAIMED",
						string.format("Contribution: %d%% (%d DMG)\n+%d Scrap | +%d Gears", pct, entry.Damage, scrapReward, gearsReward),
						Color3.fromRGB(255, 170, 20)
					)

					pcall(function()
						local QuestService = require(script.Parent.QuestService)
						QuestService.recordProgress(cPlayer, "Scrap_50", 1)
						QuestService.recordProgress(cPlayer, "Dismantle_Rare", 1)
					end)
				end
			end

			-- Top MVP Contributors global announcement
			local topList = {}
			for rank, entry in ipairs(sortedContributors) do
				if rank > 3 then break end
				local fraction = math.clamp(entry.Damage / totalDmg, 0, 1)
				local pct = math.floor(fraction * 100)
				local medal = (rank == 1 and "[#1]") or (rank == 2 and "[#2]") or "[#3]"
				table.insert(topList, string.format("%s %s (%d%%)", medal, entry.Player.Name, pct))
			end

			local notifAll = Remotes.getEvent("ShowNotification")
			notifAll:FireAllClients(
				"ORBITAL DROP POD DESTROYED",
				string.format("Raid Pod neutralized.\nTop Scrappers: %s", #topList > 0 and table.concat(topList, " | ") or player.Name),
				Color3.fromRGB(255, 140, 20)
			)

			pcall(function()
				EventService.clearActivePod(nodeModel)
			end)
			task.delay(1.5, function()
				if nodeModel and nodeModel.Parent then
					nodeModel:Destroy()
				end
				nodeCooldown[nodeModel] = nil
			end)
			return
		end

		if statusLabel then
			statusLabel.Text = "HARVESTED"
		end
		local hpLabel = nodeModel:FindFirstChild("HpLabel", true) :: TextLabel?
		if hpLabel then
			hpLabel.Text = "[ 0 / " .. tostring(maxHP) .. " HP ]"
		end
		local barFill = nodeModel:FindFirstChild("HealthBarFill", true) :: Frame?
		if barFill then
			barFill.Size = UDim2.new(0, 0, 1, 0)
		end

		local breakScrap = math.floor(((baseYield * tier.Multiplier) * 1.5) * comboMult * effectiveCritMult)
		local spaceLeft = math.max(0, maxCapacity - (data.Backpack or 0))
		local added = math.min(spaceLeft, breakScrap)
		data.Backpack = (data.Backpack or 0) + added
		DataService.sync(player)
		CurrencyService.updateLeaderstats(player)

		pcall(function()
			local BackpackService = require(script.Parent.BackpackService)
			BackpackService.updateCoreColor(player)
		end)

		local displayBreakTier = isCrit and ("[CRIT] " .. (isDense and "DENSE" or tier.Name)) or (isDense and ("DENSE " .. tier.Name) or tier.Name)
		local displayBreakColor = isCrit and Color3.fromRGB(255, 215, 0) or (isDense and Color3.fromRGB(0, 240, 255) or tier.Color)
		local breakSoundPitch = isCrit and (tier.SoundPitch * 1.3) or tier.SoundPitch

		local actionCompletedEvent = Remotes.getEvent("ActionCompleted")
		actionCompletedEvent:FireClient(player, {
			IsBreak = true,
			IsDense = (isDense == true),
			IsOrbital = false,
			MaxHP = maxHP,
			CurrentHP = 0,
			TierName = displayBreakTier,
			TierColor = displayBreakColor,
			ScrapEarned = added,
			SoundPitch = breakSoundPitch,
			Combo = comboInfo.Count,
			IsCrit = isCrit,
			Position = nodeHitbox.Position + Vector3.new(0, 4, 0),
		})

		pcall(function()
			local QuestService = require(script.Parent.QuestService)
			QuestService.recordProgress(player, "Scrap_50", 1)
			if isDense == true then
				QuestService.recordProgress(player, "Dismantle_Rare", 1)
			end
		end)

		-- Collapse node
		if corePart then corePart.Transparency = 1 end
		if basePart then basePart.Transparency = 0.8 end
		local halo = nodeModel:FindFirstChild("DenseHalo") :: BasePart?
		if halo then halo.Transparency = 1 end

		-- Respawn after 2.5 seconds with fresh RNG Dense roll (standard piles only)
		task.delay(2.5, function()
			if nodeModel and nodeModel.Parent then
				local rZoneId = nodeModel:GetAttribute("ZoneId") or 1
				local rZone = Config.Zones[rZoneId] or zone
				local isDenseRoll = (math.random() <= 0.28) -- 28% RNG chance on every respawn!

				local ZoneService = require(script.Parent.ZoneService)
				ZoneService.applyNodeVariant(nodeModel, rZone, isDenseRoll)

				nodeCooldown[nodeModel] = false
			end
		end)
	end
end

function ActionService.init()
	local function hookPrompt(prompt: ProximityPrompt)
		prompt.Triggered:Connect(function(player)
			local model = prompt:FindFirstAncestorOfClass("Model")
			if model then
				ActionService.performScrapAction(player, model)
			end
		end)
	end

	CollectionService:GetInstanceAddedSignal("ScrapPrompt"):Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			hookPrompt(descendant)
		end
	end)

	for _, descendant in ipairs(CollectionService:GetTagged("ScrapPrompt")) do
		if descendant:IsA("ProximityPrompt") then
			hookPrompt(descendant)
		end
	end

	local requestActionEvent = Remotes.getEvent("RequestAction")
	requestActionEvent.OnServerEvent:Connect(function(player, targetModel)
		if typeof(targetModel) == "Instance" and targetModel:IsA("Model") then
			ActionService.performScrapAction(player, targetModel)
		end
	end)

	local purchaseToolEvent = Remotes.getEvent("PurchaseTool")
	purchaseToolEvent.OnServerEvent:Connect(function(player, toolId)
		if type(toolId) == "string" then
			ActionService.purchaseTool(player, toolId)
		end
	end)

	local equipToolEvent = Remotes.getEvent("EquipTool")
	equipToolEvent.OnServerEvent:Connect(function(player, toolId)
		if type(toolId) == "string" then
			ActionService.equipTool(player, toolId)
		end
	end)

	-- StarterPack default tool ensures Roblox natively populates hotbar slot 1 on spawn
	local starterPack = game:GetService("StarterPack")
	local defaultTool = starterPack:FindFirstChild("Omni-Wrench")
	if not defaultTool then
		local sTool = ActionService.buildTool("OmniWrench")
		sTool.Parent = starterPack
	end

	-- Give tool on join and spawn (with delay to let engine finish backpack reset)
	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			if player.Parent and character.Parent then
				ActionService.giveScrapperTool(player)
			end
		end)

		if player.Character then
			task.spawn(function()
				task.wait(0.2)
				if player.Parent and player.Character then
					ActionService.giveScrapperTool(player)
				end
			end)
		end
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerLastActionTime[player] = nil
		playerCombo[player] = nil
	end)

	-- AutoScrap Perk Loop: background automatic harvesting for players with the perk!
	-- High performance: queries tagged ScrapNode instances instead of scanning all Workspace descendants
	task.spawn(function()
		while true do
			task.wait(1.8)
			local scrapNodes = CollectionService:GetTagged("ScrapNode")
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data and data.GearsPerks and data.GearsPerks["AutoScrap"] then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						local pPos = root.Position
						local tConf = Config.getTool(data.EquippedTool or "OmniWrench")
						local aRange = (tConf and tConf.Range or 8) + 2
						for _, node in ipairs(scrapNodes) do
							if node:IsA("Model") and node.Parent then
								local hb = (node:FindFirstChild("Hitbox") or node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart")) :: BasePart?
								if hb then
									local nRad = hb.Size.Magnitude * 0.35
									local dist = math.max(0, (pPos - hb.Position).Magnitude - nRad)
									if dist <= aRange then
										ActionService.performScrapAction(player, node)
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	print("[ActionService] Initialized with crunchy multi-hit scrapping and AutoScrap perk support.")
end

return ActionService
