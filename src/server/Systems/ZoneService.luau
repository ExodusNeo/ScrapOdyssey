--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local EnvironmentService = require(script.Parent.EnvironmentService)

local ZoneService = {}
local activeNodes = {}
local zoneGates: { [number]: { Model: Model, Barrier: Part, Prompt: ProximityPrompt } } = {}

-- Module-level debounces (cleaned up on PlayerRemoving to prevent leaks)
local portalDebounces: { [Player]: number } = {}
local sellDebounce: { [Player]: number } = {}
local patrolDebounces: { [Player]: number } = {}

-- Safe zone center coordinates for each zone (Zone 1 is Central Hub)
local ZONE_CENTERS = {
	[1] = Vector3.new(0, 0, 0),
	[2] = Vector3.new(180, 0, -110),
	[3] = Vector3.new(280, 0, 60),
	[4] = Vector3.new(170, 0, 230),
	[5] = Vector3.new(-30, 0, 260),
}

-- 1. Calm, Eye-Friendly Lighting Setup (Delegated to EnvironmentService with zero sun glare)
function ZoneService.setupLighting()
	EnvironmentService.setupAtmosphereAndSky()
end

-- Helper to create a Fast-Travel Portal Pad on any platform (Quantum Displacement Platform)
local function createPortalPad(parent: Instance, position: Vector3, zoneId: number)
	local terminalModel = Instance.new("Model")
	terminalModel.Name = "FastTravelTerminal_Zone" .. tostring(zoneId)

	-- 1. Heavy Foundation Platform & Power Conduits
	local foundation = Instance.new("Model")
	foundation.Name = "Foundation"
	foundation.Parent = terminalModel

	-- Outer Heavy Octagonal/Circular Stepped Base Ring
	local baseRing = Instance.new("Part")
	baseRing.Name = "BaseRing"
	baseRing.Shape = Enum.PartType.Cylinder
	baseRing.Size = Vector3.new(0.45, 9.2, 9.2)
	baseRing.Position = Vector3.new(position.X, 0.225, position.Z)
	baseRing.Orientation = Vector3.new(0, 0, 90)
	baseRing.Anchored = true
	baseRing.CanCollide = true
	baseRing.Material = Enum.Material.DiamondPlate
	baseRing.Color = Color3.fromRGB(26, 28, 36)
	baseRing.Parent = foundation

	-- Mid Beveled Steel Collar Frame
	local padRim = Instance.new("Part")
	padRim.Name = "CollarRim"
	padRim.Shape = Enum.PartType.Cylinder
	padRim.Size = Vector3.new(0.50, 8.2, 8.2)
	padRim.Position = Vector3.new(position.X, 0.30, position.Z)
	padRim.Orientation = Vector3.new(0, 0, 90)
	padRim.Anchored = true
	padRim.CanCollide = true
	padRim.Material = Enum.Material.Metal
	padRim.Color = Color3.fromRGB(48, 52, 64)
	padRim.Parent = foundation

	-- Recessed Power Conduit Ring (Glow Inlay)
	local conduitRing = Instance.new("Part")
	conduitRing.Name = "PowerConduitRing"
	conduitRing.Shape = Enum.PartType.Cylinder
	conduitRing.Size = Vector3.new(0.52, 7.4, 7.4)
	conduitRing.Position = Vector3.new(position.X, 0.32, position.Z)
	conduitRing.Orientation = Vector3.new(0, 0, 90)
	conduitRing.Anchored = true
	conduitRing.CanCollide = false
	conduitRing.Material = Enum.Material.Neon
	conduitRing.Color = Color3.fromRGB(140, 70, 220)
	conduitRing.Parent = foundation

	-- 2. Four Quantum Focus Pylons angled around the platform perimeter
	local pylonsGroup = Instance.new("Model")
	pylonsGroup.Name = "FocusPylons"
	pylonsGroup.Parent = terminalModel

	local pylonAngles = { 45, 135, 225, 315 }
	for pIdx, angleDeg in ipairs(pylonAngles) do
		local rad = math.rad(angleDeg)
		local px = position.X + math.cos(rad) * 4.2
		local pz = position.Z + math.sin(rad) * 4.2

		local pylon = Instance.new("Model")
		pylon.Name = "Pylon_" .. tostring(pIdx)
		pylon.Parent = pylonsGroup

		-- Pylon Base Mount
		local pBase = Instance.new("Part")
		pBase.Name = "Mount"
		pBase.Size = Vector3.new(1.2, 0.8, 1.2)
		pBase.Position = Vector3.new(px, 0.6, pz)
		pBase.CFrame = CFrame.new(pBase.Position, Vector3.new(position.X, 0.6, position.Z))
		pBase.Anchored = true
		pBase.Material = Enum.Material.Metal
		pBase.Color = Color3.fromRGB(35, 38, 48)
		pBase.Parent = pylon

		-- Angled Pylon Body leaning towards center
		local pBody = Instance.new("Part")
		pBody.Name = "EmitterBody"
		pBody.Size = Vector3.new(0.8, 2.2, 0.8)
		local pLook = CFrame.new(Vector3.new(px, 1.5, pz), Vector3.new(position.X, 2.2, position.Z))
		pBody.CFrame = pLook * CFrame.Angles(math.rad(15), 0, 0)
		pBody.Anchored = true
		pBody.Material = Enum.Material.DiamondPlate
		pBody.Color = Color3.fromRGB(42, 45, 56)
		pBody.Parent = pylon

		-- Copper Magnetic Coils
		local pCoil = Instance.new("Part")
		pCoil.Name = "MagneticCoil"
		pCoil.Size = Vector3.new(0.95, 0.8, 0.95)
		pCoil.CFrame = pBody.CFrame * CFrame.new(0, -0.2, 0)
		pCoil.Anchored = true
		pCoil.Material = Enum.Material.Foil
		pCoil.Color = Color3.fromRGB(205, 120, 50)
		pCoil.Parent = pylon

		-- Glowing Focus Crystal Tip
		local pCrystal = Instance.new("Part")
		pCrystal.Name = "FocusCrystal"
		pCrystal.Shape = Enum.PartType.Ball
		pCrystal.Size = Vector3.new(0.7, 0.7, 0.7)
		pCrystal.CFrame = pBody.CFrame * CFrame.new(0, 1.2, 0)
		pCrystal.Anchored = true
		pCrystal.Material = Enum.Material.Neon
		pCrystal.Color = Color3.fromRGB(195, 115, 255)
		pCrystal.Parent = pylon
	end

	-- 3. Inner Elevated Active Warp Pad & Swirling Vortex Field
	local warpPadGroup = Instance.new("Model")
	warpPadGroup.Name = "WarpPlatform"
	warpPadGroup.Parent = terminalModel

	local pad = Instance.new("Part")
	pad.Name = "PortalPad_Zone" .. tostring(zoneId)
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.58, 6.8, 6.8)
	pad.Position = Vector3.new(position.X, 0.39, position.Z)
	pad.Orientation = Vector3.new(0, 0, 90)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(150, 75, 230)
	pad.Parent = warpPadGroup

	-- Translucent Vortex Energy Disc atop the pad
	local energyDisc = Instance.new("Part")
	energyDisc.Name = "VortexEnergyDisc"
	energyDisc.Shape = Enum.PartType.Cylinder
	energyDisc.Size = Vector3.new(0.08, 6.2, 6.2)
	energyDisc.Position = Vector3.new(position.X, 0.45, position.Z)
	energyDisc.Orientation = Vector3.new(0, 0, 90)
	energyDisc.Anchored = true
	energyDisc.CanCollide = false
	energyDisc.Material = Enum.Material.Neon
	energyDisc.Color = Color3.fromRGB(190, 120, 255)
	energyDisc.Transparency = 0.4
	energyDisc.Parent = warpPadGroup

	-- Subtle Quantum Warp Particle Spark Emitter
	local warpSparks = Instance.new("ParticleEmitter")
	warpSparks.Name = "WarpSparks"
	warpSparks.Color = ColorSequence.new(Color3.fromRGB(210, 140, 255))
	warpSparks.Size = NumberSequence.new(0.15, 0.35)
	warpSparks.Transparency = NumberSequence.new(0.2, 1.0)
	warpSparks.Rate = 16
	warpSparks.Lifetime = NumberRange.new(1.0, 1.8)
	warpSparks.Speed = NumberRange.new(2.5, 4.5)
	warpSparks.SpreadAngle = Vector2.new(15, 15)
	warpSparks.Acceleration = Vector3.new(0, 2, 0)
	warpSparks.Parent = pad

	local portalLight = Instance.new("PointLight")
	portalLight.Color = Color3.fromRGB(190, 110, 255)
	portalLight.Brightness = 1.2
	portalLight.Range = 14
	portalLight.Parent = pad

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 180, 0, 50)
	bb.StudsOffset = Vector3.new(0, 4.8, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 36
	bb.Parent = pad

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(230, 185, 255)
	lbl.TextStrokeTransparency = 0.15
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Text = "QUANTUM DISPLACEMENT PAD\n[Press E or Step to Warp]"
	lbl.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Quantum Pad"
	prompt.ActionText = "Displace"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local function openMenu(player: Player)
		local now = os.clock()
		if portalDebounces[player] and (now - portalDebounces[player]) < 2.5 then
			return
		end
		portalDebounces[player] = now

		-- Signal client to open Teleport panel (cleanly without toast spam)
		local clientEvent = Remotes.getEvent("TeleportZone")
		clientEvent:FireClient(player, -1)
	end

	prompt.Triggered:Connect(openMenu)
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		if not char then return end
		if hit.Name ~= "HumanoidRootPart" and hit.Name ~= "UpperTorso" and hit.Name ~= "Torso" then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			openMenu(player)
		end
	end)

	terminalModel.Parent = parent
	return terminalModel
end

-- 2. Helper to build an Industrial Scrap Recycler with furnace core, smokestacks, shredder maw, and conveyor deposit pad
function ZoneService.constructRecycler(parent: Instance, basePos: Vector3, zoneId: number): Model
	local recyclerModel = Instance.new("Model")
	recyclerModel.Name = "ScrapRecycler_Zone" .. tostring(zoneId)

	-- 1. Main Smelting Furnace Structure
	local furnaceBody = Instance.new("Model")
	furnaceBody.Name = "FurnaceBody"
	furnaceBody.Parent = recyclerModel

	-- Heavy Reinforced Blast Furnace Hull
	local baseUnit = Instance.new("Part")
	baseUnit.Name = "BaseUnit"
	baseUnit.Size = Vector3.new(13, 8.5, 13)
	baseUnit.Position = basePos + Vector3.new(0, 4.25, 0)
	baseUnit.Anchored = true
	baseUnit.Material = Enum.Material.DiamondPlate
	baseUnit.Color = Color3.fromRGB(30, 32, 40)
	baseUnit.Parent = furnaceBody

	-- Corner Armor Buttresses (4 reinforced structural pillars)
	local cornerOffsets = {
		Vector3.new(-6.2, 4.25, -6.2),
		Vector3.new(6.2, 4.25, -6.2),
		Vector3.new(-6.2, 4.25, 6.2),
		Vector3.new(6.2, 4.25, 6.2),
	}
	for bIdx, cOff in ipairs(cornerOffsets) do
		local buttress = Instance.new("Part")
		buttress.Name = "Buttress_" .. tostring(bIdx)
		buttress.Size = Vector3.new(1.8, 9.0, 1.8)
		buttress.Position = basePos + cOff
		buttress.Anchored = true
		buttress.Material = Enum.Material.Metal
		buttress.Color = Color3.fromRGB(45, 48, 58)
		buttress.Parent = furnaceBody
	end

	-- Molten Inspection Viewport (Glowing Smelting Core)
	local furnaceWindow = Instance.new("Part")
	furnaceWindow.Name = "FurnaceCore"
	furnaceWindow.Size = Vector3.new(6, 4.0, 0.5)
	furnaceWindow.Position = basePos + Vector3.new(0, 3.6, 6.6)
	furnaceWindow.Anchored = true
	furnaceWindow.Material = Enum.Material.Neon
	furnaceWindow.Color = Color3.fromRGB(255, 120, 25)
	furnaceWindow.Parent = furnaceBody

	-- Heavy protective quartz viewport grille
	local windowGrille = Instance.new("Part")
	windowGrille.Name = "ViewportGrille"
	windowGrille.Size = Vector3.new(6.4, 4.4, 0.4)
	windowGrille.Position = basePos + Vector3.new(0, 3.6, 6.8)
	windowGrille.Anchored = true
	windowGrille.Material = Enum.Material.CorrodedMetal
	windowGrille.Color = Color3.fromRGB(35, 25, 20)
	windowGrille.Transparency = 0.35
	windowGrille.Parent = furnaceBody

	local fLight = Instance.new("PointLight")
	fLight.Color = Color3.fromRGB(255, 135, 35)
	fLight.Brightness = 1.4
	fLight.Range = 16
	fLight.Parent = furnaceWindow

	-- Molten Slag Core Particle Sparks
	local fireSparks = Instance.new("ParticleEmitter")
	fireSparks.Name = "CoreSparks"
	fireSparks.Color = ColorSequence.new(Color3.fromRGB(255, 160, 40))
	fireSparks.Size = NumberSequence.new(0.15, 0.35)
	fireSparks.Rate = 10
	fireSparks.Speed = NumberRange.new(2, 5)
	fireSparks.Lifetime = NumberRange.new(0.4, 0.8)
	fireSparks.SpreadAngle = Vector2.new(30, 30)
	fireSparks.Parent = furnaceWindow

	-- Side Radiator Heat Exchanger Vents
	for _, xSide in ipairs({ -6.7, 6.7 }) do
		for vIdx = 1, 3 do
			local vent = Instance.new("Part")
			vent.Name = "HeatVent"
			vent.Size = Vector3.new(0.4, 0.8, 8.0)
			vent.Position = basePos + Vector3.new(xSide, 2.5 + (vIdx * 1.4), 0)
			vent.Anchored = true
			vent.Material = Enum.Material.Metal
			vent.Color = Color3.fromRGB(22, 24, 30)
			vent.Parent = furnaceBody
		end
	end

	-- High-Pressure Pressurized Coolant Manifold Conduits (Industrial Orange & Cyan)
	for _, sideData in ipairs({ { X = -6.7, Col = Color3.fromRGB(240, 110, 30) }, { X = 6.7, Col = Color3.fromRGB(35, 175, 230) } }) do
		local pipe = Instance.new("Part")
		pipe.Name = "CoolantPipe"
		pipe.Shape = Enum.PartType.Cylinder
		pipe.Size = Vector3.new(7.0, 0.7, 0.7)
		pipe.Position = basePos + Vector3.new(sideData.X, 7.2, 0)
		pipe.Orientation = Vector3.new(90, 0, 0)
		pipe.Anchored = true
		pipe.Material = Enum.Material.Metal
		pipe.Color = sideData.Col
		pipe.Parent = furnaceBody
	end

	-- Recycler Billboard Gantry
	local rbb = Instance.new("BillboardGui")
	rbb.Size = UDim2.new(0, 280, 0, 65)
	rbb.StudsOffset = Vector3.new(0, 9.5, 0)
	rbb.AlwaysOnTop = false
	rbb.MaxDistance = 50
	rbb.Parent = baseUnit

	local rTitle = Instance.new("TextLabel")
	rTitle.Size = UDim2.new(1, 0, 1, 0)
	rTitle.BackgroundTransparency = 1
	rTitle.Font = Enum.Font.GothamBlack
	rTitle.TextSize = 20
	rTitle.TextColor3 = Color3.fromRGB(255, 205, 50)
	rTitle.TextStrokeTransparency = 0.15
	rTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
	rTitle.Text = string.format("SCRAP RECYCLER %s\n[DEPOSIT & SELL CARGO]", zoneId > 1 and ("(ZONE " .. tostring(zoneId) .. ") ") or "")
	rTitle.Parent = rbb

	-- 2. Industrial Exhaust & Ventilation System
	local exhaustSystem = Instance.new("Model")
	exhaustSystem.Name = "ExhaustSystem"
	exhaustSystem.Parent = recyclerModel

	-- Central Heavy Extraction Turbine Housing
	local turbineHousing = Instance.new("Part")
	turbineHousing.Name = "TurbineHousing"
	turbineHousing.Shape = Enum.PartType.Cylinder
	turbineHousing.Size = Vector3.new(2.4, 7.5, 7.5)
	turbineHousing.Position = basePos + Vector3.new(0, 9.6, 0)
	turbineHousing.Orientation = Vector3.new(0, 0, 90)
	turbineHousing.Anchored = true
	turbineHousing.Material = Enum.Material.DiamondPlate
	turbineHousing.Color = Color3.fromRGB(42, 45, 55)
	turbineHousing.Parent = exhaustSystem

	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Color = ColorSequence.new(Color3.fromRGB(215, 215, 225))
	steam.Size = NumberSequence.new(1.8, 5.5)
	steam.Transparency = NumberSequence.new(0.25, 1.0)
	steam.Rate = 18
	steam.Lifetime = NumberRange.new(2.5, 4.0)
	steam.Speed = NumberRange.new(5, 9)
	steam.SpreadAngle = Vector2.new(22, 22)
	steam.Acceleration = Vector3.new(0, 4, 0)
	steam.Parent = turbineHousing

	-- Dual Heavy Flared Smokestacks with Guy-Wire Reinforcement Collars
	local stackCoords = { basePos + Vector3.new(-5.4, 9.5, -2), basePos + Vector3.new(5.4, 9.5, -2) }
	for idx, sPos in ipairs(stackCoords) do
		local stack = Instance.new("Part")
		stack.Name = idx == 1 and "Smokestack_Left" or "Smokestack_Right"
		stack.Shape = Enum.PartType.Cylinder
		stack.Size = Vector3.new(11, 2.2, 2.2)
		stack.Position = sPos
		stack.Orientation = Vector3.new(0, 0, 90)
		stack.Anchored = true
		stack.Material = Enum.Material.Metal
		stack.Color = Color3.fromRGB(30, 32, 40)
		stack.Parent = exhaustSystem

		-- Stack Reinforcement Rings
		local collar = Instance.new("Part")
		collar.Name = "StackCollar"
		collar.Shape = Enum.PartType.Cylinder
		collar.Size = Vector3.new(1.2, 2.6, 2.6)
		collar.Position = sPos + Vector3.new(0, 4.5, 0)
		collar.Orientation = Vector3.new(0, 0, 90)
		collar.Anchored = true
		collar.Material = Enum.Material.DiamondPlate
		collar.Color = Color3.fromRGB(215, 140, 30)
		collar.Parent = exhaustSystem

		local stackSmoke = Instance.new("ParticleEmitter")
		stackSmoke.Name = "StackSmoke"
		stackSmoke.Color = ColorSequence.new(Color3.fromRGB(160, 160, 175))
		stackSmoke.Size = NumberSequence.new(1.2, 3.8)
		stackSmoke.Transparency = NumberSequence.new(0.4, 1.0)
		stackSmoke.Rate = 12
		stackSmoke.Lifetime = NumberRange.new(2, 3.5)
		stackSmoke.Speed = NumberRange.new(4, 7)
		stackSmoke.SpreadAngle = Vector2.new(15, 15)
		stackSmoke.Acceleration = Vector3.new(0, 3, 0)
		stackSmoke.Parent = collar
	end

	-- 3. Heavy-Duty Conveyor Feeder Chute & Cargo Deposit Area
	local depositArea = Instance.new("Model")
	depositArea.Name = "DepositArea"
	depositArea.Parent = recyclerModel

	-- Chute Steel Side Rampart Rails (Left & Right)
	for _, xRail in ipairs({ -7.2, 7.2 }) do
		local rail = Instance.new("Part")
		rail.Name = "ChuteGuardrail"
		rail.Size = Vector3.new(1.0, 2.2, 11)
		rail.Position = basePos + Vector3.new(xRail, 1.1, 7.5)
		rail.Anchored = true
		rail.Material = Enum.Material.Metal
		rail.Color = Color3.fromRGB(45, 48, 58)
		rail.Parent = depositArea

		local hazardStrip = Instance.new("Part")
		hazardStrip.Name = "HazardTrim"
		hazardStrip.Size = Vector3.new(1.05, 0.4, 11)
		hazardStrip.Position = rail.Position + Vector3.new(0, 1.0, 0)
		hazardStrip.Anchored = true
		hazardStrip.Material = Enum.Material.SmoothPlastic
		hazardStrip.Color = Color3.fromRGB(245, 175, 20)
		hazardStrip.Parent = depositArea
	end

	-- High-Traction Conveyor Bed Base
	local conveyorBed = Instance.new("Part")
	conveyorBed.Name = "ConveyorBed"
	conveyorBed.Size = Vector3.new(13.4, 0.4, 11)
	conveyorBed.Position = basePos + Vector3.new(0, 0.2, 7.5)
	conveyorBed.Anchored = true
	conveyorBed.CanCollide = true
	conveyorBed.Material = Enum.Material.DiamondPlate
	conveyorBed.Color = Color3.fromRGB(24, 26, 32)
	conveyorBed.Parent = depositArea

	-- Interactive Sell Cargo Deposit Pad (Preserves exact name RecyclerDepositPad)
	local depositPad = Instance.new("Part")
	depositPad.Name = "RecyclerDepositPad"
	depositPad.Size = Vector3.new(12.0, 0.45, 8.5)
	depositPad.Position = basePos + Vector3.new(0, 0.25, 7.5)
	depositPad.Anchored = true
	depositPad.CanCollide = true
	depositPad.Material = Enum.Material.Metal
	depositPad.Color = Color3.fromRGB(38, 145, 85)
	depositPad.Parent = depositArea

	-- Holographic Scanner Beam Arch over deposit entrance
	local scanBeam = Instance.new("Part")
	scanBeam.Name = "ScanningCurtain"
	scanBeam.Size = Vector3.new(12.5, 0.08, 0.2)
	scanBeam.Position = basePos + Vector3.new(0, 2.6, 12.5)
	scanBeam.Anchored = true
	scanBeam.CanCollide = false
	scanBeam.Material = Enum.Material.Neon
	scanBeam.Color = Color3.fromRGB(60, 240, 130)
	scanBeam.Transparency = 0.3
	scanBeam.Parent = depositArea

	local depositPrompt = Instance.new("ProximityPrompt")
	depositPrompt.Name = "RecyclePrompt"
	depositPrompt.ObjectText = "Scrap Recycler"
	depositPrompt.ActionText = "Sell Cargo"
	depositPrompt.HoldDuration = 0.1
	depositPrompt.MaxActivationDistance = 14
	depositPrompt.RequiresLineOfSight = false
	depositPrompt.Parent = depositPad

	depositPrompt.Triggered:Connect(function(player)
		local data = DataService.get(player)
		if data and zoneId > (data.MaxZoneReached or 1) then
			local notif = Remotes.getEvent("ShowNotification")
			if notif then
				notif:FireClient(player, "ZONE RESTRICTED", "Unlock this zone first before using its recycler!", Color3.fromRGB(255, 70, 70))
			end
			return
		end
		local CurrencyService = require(script.Parent.CurrencyService)
		CurrencyService.recycleBackpack(player)
	end)

	depositPad.Touched:Connect(function(hit)
		local char = hit.Parent
		if not char then return end
		if hit.Name ~= "HumanoidRootPart" and hit.Name ~= "UpperTorso" and hit.Name ~= "Torso" then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local now = os.clock()
		if sellDebounce[player] and (now - sellDebounce[player]) < 1.5 then
			return
		end
		sellDebounce[player] = now

		local data = DataService.get(player)
		-- Silently ignore if cargo is already 0 or zone is locked
		if not data or zoneId > (data.MaxZoneReached or 1) or (data.Backpack or 0) <= 0 then
			return
		end

		local CurrencyService = require(script.Parent.CurrencyService)
		CurrencyService.recycleBackpack(player)
	end)

	recyclerModel.Parent = parent
	return recyclerModel
end

-- Helper to build an Industrial Sci-Fi Tool Armory & Forge Stand in Central Hub (Facing East towards Spawn)
function ZoneService.constructToolArmoryKiosk(parent: Instance, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ToolArmoryKiosk"

	-- 1. Foundation Platform
	local foundation = Instance.new("Model")
	foundation.Name = "Foundation"
	foundation.Parent = model

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(13, 0.4, 15)
	deck.Position = pos + Vector3.new(2, 0.2, 0)
	deck.Anchored = true
	deck.Material = Enum.Material.DiamondPlate
	deck.Color = Color3.fromRGB(28, 30, 38)
	deck.Parent = foundation

	-- Deck Hazard Perimeter Trim
	local deckTrim = Instance.new("Part")
	deckTrim.Name = "PerimeterTrim"
	deckTrim.Size = Vector3.new(0.4, 0.45, 15.2)
	deckTrim.Position = pos + Vector3.new(8.5, 0.22, 0)
	deckTrim.Anchored = true
	deckTrim.Material = Enum.Material.SmoothPlastic
	deckTrim.Color = Color3.fromRGB(240, 165, 20)
	deckTrim.Parent = foundation

	-- 2. Heavy Industrial Workstation & Tool Bench
	local workstation = Instance.new("Model")
	workstation.Name = "Workstation"
	workstation.Parent = model

	local bench = Instance.new("Part")
	bench.Name = "Workbench"
	bench.Size = Vector3.new(4.2, 3.2, 9.6)
	bench.Position = pos + Vector3.new(-1.8, 1.8, 0)
	bench.Anchored = true
	bench.Material = Enum.Material.Metal
	bench.Color = Color3.fromRGB(42, 46, 56)
	bench.Parent = workstation

	-- Tool Bench Storage Drawers / Tool Cabinet Units
	for dIdx, dz in ipairs({ -3.0, 0, 3.0 }) do
		local drawer = Instance.new("Part")
		drawer.Name = "DrawerUnit_" .. tostring(dIdx)
		drawer.Size = Vector3.new(0.3, 2.4, 2.4)
		drawer.Position = pos + Vector3.new(0.35, 1.6, dz)
		drawer.Anchored = true
		drawer.Material = Enum.Material.DiamondPlate
		drawer.Color = Color3.fromRGB(30, 32, 40)
		drawer.Parent = workstation
	end

	-- Heavy Industrial Steel Vise clamped to bench
	local vise = Instance.new("Part")
	vise.Name = "BenchVise"
	vise.Size = Vector3.new(1.2, 1.4, 1.4)
	vise.Position = pos + Vector3.new(-0.2, 3.8, 3.8)
	vise.Anchored = true
	vise.Material = Enum.Material.Metal
	vise.Color = Color3.fromRGB(65, 70, 85)
	vise.Parent = workstation

	-- Heavy Forged Anvil with Heat-Treated Temper
	local anvil = Instance.new("Part")
	anvil.Name = "Anvil"
	anvil.Size = Vector3.new(1.8, 1.8, 3.0)
	anvil.Position = pos + Vector3.new(-1.8, 3.8, -2.4)
	anvil.Anchored = true
	anvil.Material = Enum.Material.CorrodedMetal
	anvil.Color = Color3.fromRGB(205, 115, 35)
	anvil.Parent = workstation

	-- Back Pegboard Wall for Hanging Tools
	local pegboard = Instance.new("Part")
	pegboard.Name = "ToolPegboard"
	pegboard.Size = Vector3.new(0.4, 5.0, 9.4)
	pegboard.Position = pos + Vector3.new(-3.8, 5.5, 0)
	pegboard.Anchored = true
	pegboard.Material = Enum.Material.DiamondPlate
	pegboard.Color = Color3.fromRGB(25, 27, 34)
	pegboard.Parent = workstation

	-- Hanging Salvage Tools on Pegboard (Plasma Torch, Spanners, Power Cells)
	local hangingSpanner = Instance.new("Part")
	hangingSpanner.Name = "HangingSpanner"
	hangingSpanner.Size = Vector3.new(0.2, 1.8, 0.4)
	hangingSpanner.Position = pos + Vector3.new(-3.5, 6.0, -2.2)
	hangingSpanner.Orientation = Vector3.new(0, 0, 15)
	hangingSpanner.Anchored = true
	hangingSpanner.Material = Enum.Material.Metal
	hangingSpanner.Color = Color3.fromRGB(180, 185, 195)
	hangingSpanner.Parent = workstation

	local hangingPowerCell = Instance.new("Part")
	hangingPowerCell.Name = "HangingPowerCell"
	hangingPowerCell.Size = Vector3.new(0.3, 1.4, 0.6)
	hangingPowerCell.Position = pos + Vector3.new(-3.5, 6.2, 2.2)
	hangingPowerCell.Anchored = true
	hangingPowerCell.Material = Enum.Material.Neon
	hangingPowerCell.Color = Color3.fromRGB(45, 215, 115)
	hangingPowerCell.Parent = workstation

	-- 3. High-Tech 3D Holographic Weapon Projector Table
	local hologram = Instance.new("Model")
	hologram.Name = "HologramDisplay"
	hologram.Parent = model

	-- Emitter Projector Base on Bench
	local emitterBase = Instance.new("Part")
	emitterBase.Name = "EmitterBase"
	emitterBase.Shape = Enum.PartType.Cylinder
	emitterBase.Size = Vector3.new(0.25, 2.0, 2.0)
	emitterBase.Position = pos + Vector3.new(-1.8, 3.5, 0.6)
	emitterBase.Orientation = Vector3.new(0, 0, 90)
	emitterBase.Anchored = true
	emitterBase.Material = Enum.Material.Neon
	emitterBase.Color = Color3.fromRGB(255, 170, 40)
	emitterBase.Parent = hologram

	-- Holographic Wrench Wireframe Head
	local holoWrench = Instance.new("Part")
	holoWrench.Name = "HoloTool"
	holoWrench.Size = Vector3.new(0.6, 2.6, 0.6)
	holoWrench.Position = pos + Vector3.new(-1.8, 4.8, 0.6)
	holoWrench.Orientation = Vector3.new(25, 45, 15)
	holoWrench.Anchored = true
	holoWrench.CanCollide = false
	holoWrench.Material = Enum.Material.Neon
	holoWrench.Color = Color3.fromRGB(255, 180, 45)
	holoWrench.Transparency = 0.25
	holoWrench.Parent = hologram

	local holoLight = Instance.new("PointLight")
	holoLight.Color = Color3.fromRGB(255, 175, 45)
	holoLight.Brightness = 1.0
	holoLight.Range = 12
	holoLight.Parent = holoWrench

	-- Holographic Scan Particles
	local holoParticles = Instance.new("ParticleEmitter")
	holoParticles.Name = "HoloScan"
	holoParticles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 70))
	holoParticles.Size = NumberSequence.new(0.08, 0.2)
	holoParticles.Rate = 12
	holoParticles.Speed = NumberRange.new(0.5, 1.5)
	holoParticles.Lifetime = NumberRange.new(0.6, 1.2)
	holoParticles.SpreadAngle = Vector2.new(180, 180)
	holoParticles.Parent = holoWrench

	CollectionService:AddTag(holoWrench, "FloatingDecor")
	holoWrench:SetAttribute("BasePos", pos + Vector3.new(-1.8, 4.8, 0.6))
	holoWrench:SetAttribute("SpinSpeed", 40)
	holoWrench:SetAttribute("BobSpeed", 1.8)
	holoWrench:SetAttribute("BobAmp", 0.25)
	holoWrench:SetAttribute("TiltAngle", 15)

	-- 4. Overhead Industrial Truss Canopy Structure
	local canopy = Instance.new("Model")
	canopy.Name = "CanopyStructure"
	canopy.Parent = model

	local pillars = Instance.new("Model")
	pillars.Name = "SupportColumns"
	pillars.Parent = canopy

	for idx, cz in ipairs({ -6.4, 6.4 }) do
		local col = Instance.new("Part")
		col.Name = idx == 1 and "Column_Left" or "Column_Right"
		col.Size = Vector3.new(1.4, 10, 1.4)
		col.Position = pos + Vector3.new(-4.8, 5.2, cz)
		col.Anchored = true
		col.Material = Enum.Material.Metal
		col.Color = Color3.fromRGB(35, 38, 48)
		col.Parent = pillars

		-- Diagonal Truss Bracing
		local brace = Instance.new("Part")
		brace.Name = "TrussBrace"
		brace.Size = Vector3.new(0.8, 4.5, 0.8)
		brace.Position = pos + Vector3.new(-3.0, 9.0, cz)
		brace.Orientation = Vector3.new(0, 0, -35)
		brace.Anchored = true
		brace.Material = Enum.Material.Metal
		brace.Color = Color3.fromRGB(45, 48, 58)
		brace.Parent = pillars
	end

	local roof = Instance.new("Part")
	roof.Name = "CanopyRoof"
	roof.Size = Vector3.new(11, 0.8, 16)
	roof.Position = pos + Vector3.new(-1, 10.2, 0)
	roof.Orientation = Vector3.new(0, 0, 4) -- slight realistic drainage pitch
	roof.Anchored = true
	roof.Material = Enum.Material.CorrodedMetal
	roof.Color = Color3.fromRGB(30, 32, 40)
	roof.Parent = canopy

	local roofTrim = Instance.new("Part")
	roofTrim.Name = "CanopyTrim"
	roofTrim.Size = Vector3.new(0.6, 0.5, 16.4)
	roofTrim.Position = pos + Vector3.new(4.5, 9.9, 0)
	roofTrim.Anchored = true
	roofTrim.Material = Enum.Material.SmoothPlastic
	roofTrim.Color = Color3.fromRGB(245, 155, 25)
	roofTrim.Parent = canopy

	-- Overhead Hanging Cage Worklights (Warm Industrial Halogen Illumination)
	for lIdx, lz in ipairs({ -3.5, 3.5 }) do
		local lampCage = Instance.new("Part")
		lampCage.Name = "WorkLamp_" .. tostring(lIdx)
		lampCage.Shape = Enum.PartType.Cylinder
		lampCage.Size = Vector3.new(1.0, 1.2, 1.2)
		lampCage.Position = pos + Vector3.new(-1.0, 9.4, lz)
		lampCage.Orientation = Vector3.new(0, 0, 90)
		lampCage.Anchored = true
		lampCage.Material = Enum.Material.Neon
		lampCage.Color = Color3.fromRGB(255, 230, 180)
		lampCage.Parent = canopy

		local lampLight = Instance.new("SpotLight")
		lampLight.Face = Enum.NormalId.Bottom
		lampLight.Color = Color3.fromRGB(255, 225, 175)
		lampLight.Brightness = 2.0
		lampLight.Range = 14
		lampLight.Angle = 75
		lampLight.Parent = lampCage
	end

	-- 5. Illuminated Overhead Armory Signage
	local signage = Instance.new("Model")
	signage.Name = "Signage"
	signage.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "ArmorySign"
	sign.Size = Vector3.new(0.6, 2.6, 13)
	sign.Position = pos + Vector3.new(4.5, 11.5, 0)
	sign.Anchored = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(18, 20, 28)
	sign.Parent = signage

	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Right -- +X face points East towards Central Spawn
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 40
	sGui.LightInfluence = 0.15
	sGui.Parent = sign

	local sBox = Instance.new("Frame")
	sBox.Size = UDim2.new(1, 0, 1, 0)
	sBox.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	sBox.BorderSizePixel = 0
	sBox.Parent = sGui

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = Color3.fromRGB(255, 140, 30)
	sStroke.Thickness = 2
	sStroke.Parent = sBox

	local sTitle = Instance.new("TextLabel")
	sTitle.Size = UDim2.new(1, 0, 0.6, 0)
	sTitle.Position = UDim2.new(0, 0, 0.05, 0)
	sTitle.BackgroundTransparency = 1
	sTitle.Font = Enum.Font.GothamBlack
	sTitle.TextSize = 20
	sTitle.TextColor3 = Color3.fromRGB(255, 185, 50)
	sTitle.Text = "SCRAPPER FORGE // ARMORY"
	sTitle.Parent = sBox

	local sSub = Instance.new("TextLabel")
	sSub.Size = UDim2.new(1, 0, 0.35, 0)
	sSub.Position = UDim2.new(0, 0, 0.6, 0)
	sSub.BackgroundTransparency = 1
	sSub.Font = Enum.Font.GothamBold
	sSub.TextSize = 13
	sSub.TextColor3 = Color3.fromRGB(200, 220, 245)
	sSub.Text = "[ UPGRADE TOOLS // MULTIPLY HIT DAMAGE ]"
	sSub.Parent = sBox

	-- Interaction Proximity Prompt (Preserves exact name and connection on bench)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ArmoryPrompt"
	prompt.ObjectText = "Tool Armory"
	prompt.ActionText = "Open Forge"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = bench

	prompt.Triggered:Connect(function(player)
		local equipEvent = Remotes.getEvent("EquipTool")
		equipEvent:FireClient(player, "OPEN_ARMORY")
	end)

	model.Parent = parent
	return model
end

-- In-World Sci-Fi Egg Pod with hologram billboard, animated floating egg, and ProximityPrompt
function ZoneService.constructEggPod(parentFolder: Instance, pos: Vector3, eggType: string): Model
	local eggConf = Config.Eggs[eggType]
	if not eggConf then return Instance.new("Model") end

	local podModel = Instance.new("Model")
	podModel.Name = "EggPod_" .. eggType
	podModel:SetAttribute("EggType", eggType)
	CollectionService:AddTag(podModel, "EggPod")

	-- 1. Heavy Industrial Pedestal Base with Magnetic Stabilizers
	local pedestalBase = Instance.new("Model")
	pedestalBase.Name = "PedestalBase"
	pedestalBase.Parent = podModel

	-- Octagonal Base Footing
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(2.4, 5.0, 5.0)
	pedestal.Position = pos + Vector3.new(0, 1.2, 0)
	pedestal.Orientation = Vector3.new(0, 0, 90)
	pedestal.Anchored = true
	pedestal.Material = Enum.Material.DiamondPlate
	pedestal.Color = Color3.fromRGB(26, 28, 36)
	pedestal.Parent = pedestalBase

	-- Upper Beveled Collar Ring
	local glowRing = Instance.new("Part")
	glowRing.Name = "GlowRing"
	glowRing.Shape = Enum.PartType.Cylinder
	glowRing.Size = Vector3.new(0.35, 5.2, 5.2)
	glowRing.Position = pos + Vector3.new(0, 2.3, 0)
	glowRing.Orientation = Vector3.new(0, 0, 90)
	glowRing.Anchored = true
	glowRing.Material = Enum.Material.Neon
	glowRing.Color = eggConf.Color
	glowRing.Parent = pedestalBase

	-- 4 Magnetic Stabilizer Coils around Pedestal Base
	for cIdx, cDeg in ipairs({ 0, 90, 180, 270 }) do
		local rad = math.rad(cDeg)
		local cx = pos.X + math.cos(rad) * 2.5
		local cz = pos.Z + math.sin(rad) * 2.5

		local coil = Instance.new("Part")
		coil.Name = "StabilizerCoil_" .. tostring(cIdx)
		coil.Shape = Enum.PartType.Cylinder
		coil.Size = Vector3.new(1.4, 0.8, 0.8)
		coil.Position = Vector3.new(cx, pos.Y + 0.8, cz)
		coil.Orientation = Vector3.new(0, 0, 90)
		coil.Anchored = true
		coil.Material = Enum.Material.Metal
		coil.Color = Color3.fromRGB(45, 48, 58)
		coil.Parent = pedestalBase

		local coilCap = Instance.new("Part")
		coilCap.Name = "CoilCap"
		coilCap.Shape = Enum.PartType.Ball
		coilCap.Size = Vector3.new(0.65, 0.65, 0.65)
		coilCap.Position = Vector3.new(cx, pos.Y + 1.6, cz)
		coilCap.Anchored = true
		coilCap.Material = Enum.Material.Neon
		coilCap.Color = eggConf.Color
		coilCap.Parent = pedestalBase
	end

	-- Slanted Diagnostic Status Screen on Pedestal Front
	local diagScreen = Instance.new("Part")
	diagScreen.Name = "DiagnosticTerminal"
	diagScreen.Size = Vector3.new(1.8, 0.8, 0.15)
	diagScreen.Position = pos + Vector3.new(0, 1.4, 2.5)
	diagScreen.Orientation = Vector3.new(-25, 0, 0)
	diagScreen.Anchored = true
	diagScreen.Material = Enum.Material.Neon
	diagScreen.Color = Color3.fromRGB(15, 25, 35)
	diagScreen.Parent = pedestalBase

	-- 2. Cryogenic Glass Containment Capsule with Pressure Rings
	local chamber = Instance.new("Model")
	chamber.Name = "ContainmentChamber"
	chamber.Parent = podModel

	-- Lower Containment Collar
	local lowerCollar = Instance.new("Part")
	lowerCollar.Name = "LowerCollar"
	lowerCollar.Shape = Enum.PartType.Cylinder
	lowerCollar.Size = Vector3.new(0.4, 4.4, 4.4)
	lowerCollar.Position = pos + Vector3.new(0, 2.6, 0)
	lowerCollar.Orientation = Vector3.new(0, 0, 90)
	lowerCollar.Anchored = true
	lowerCollar.Material = Enum.Material.Metal
	lowerCollar.Color = Color3.fromRGB(35, 38, 48)
	lowerCollar.Parent = chamber

	-- Transparent Curved Glass Cylinder (Preserves exact name Capsule for Prompt)
	local capsule = Instance.new("Part")
	capsule.Name = "Capsule"
	capsule.Shape = Enum.PartType.Cylinder
	capsule.Size = Vector3.new(4.5, 4.0, 4.0)
	capsule.Position = pos + Vector3.new(0, 4.6, 0)
	capsule.Orientation = Vector3.new(0, 0, 90)
	capsule.Anchored = true
	capsule.Material = Enum.Material.Glass
	capsule.Color = eggConf.Color
	capsule.Transparency = 0.52
	capsule.CanCollide = false
	capsule.Parent = chamber

	-- Upper Magnetic Cap Ring
	local upperCollar = Instance.new("Part")
	upperCollar.Name = "UpperCollar"
	upperCollar.Shape = Enum.PartType.Cylinder
	upperCollar.Size = Vector3.new(0.6, 4.4, 4.4)
	upperCollar.Position = pos + Vector3.new(0, 6.9, 0)
	upperCollar.Orientation = Vector3.new(0, 0, 90)
	upperCollar.Anchored = true
	upperCollar.Material = Enum.Material.DiamondPlate
	upperCollar.Color = Color3.fromRGB(35, 38, 48)
	upperCollar.Parent = chamber

	-- Cryogenic Mist Particle Emitter inside chamber
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "CryoMist"
	mist.Color = ColorSequence.new(Color3.fromRGB(220, 235, 255))
	mist.Size = NumberSequence.new(0.6, 1.8)
	mist.Transparency = NumberSequence.new(0.5, 1.0)
	mist.Rate = 8
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Parent = capsule

	-- 3. Floating 3D Core with Rotating Plasma Orbit Rings
	local egg = Instance.new("Part")
	egg.Name = "DisplayEgg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(2.0, 2.8, 2.0)
	egg.Position = pos + Vector3.new(0, 4.6, 0)
	egg.Anchored = true
	egg.CanCollide = false
	egg.Material = Enum.Material.Neon
	egg.Color = eggConf.Color
	egg.Parent = chamber

	-- Surrounding Orbital Plasma Ring
	local orbitRing = Instance.new("Part")
	orbitRing.Name = "OrbitRing"
	orbitRing.Shape = Enum.PartType.Cylinder
	orbitRing.Size = Vector3.new(0.12, 3.2, 3.2)
	orbitRing.Position = pos + Vector3.new(0, 4.6, 0)
	orbitRing.Orientation = Vector3.new(45, 0, 90)
	orbitRing.Anchored = true
	orbitRing.CanCollide = false
	orbitRing.Material = Enum.Material.Neon
	orbitRing.Color = eggConf.Color
	orbitRing.Transparency = 0.3
	orbitRing.Parent = chamber

	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 2.0
	light.Color = eggConf.Color
	light.Parent = egg

	-- Floating and spinning animation
	local baseEggY = pos.Y + 4.6
	CollectionService:AddTag(egg, "FloatingDecor")
	egg:SetAttribute("BasePos", Vector3.new(pos.X, baseEggY, pos.Z))
	egg:SetAttribute("SpinSpeed", 30)
	egg:SetAttribute("BobSpeed", 2.0)
	egg:SetAttribute("BobAmp", 0.25)

	CollectionService:AddTag(orbitRing, "FloatingDecor")
	orbitRing:SetAttribute("BasePos", Vector3.new(pos.X, baseEggY, pos.Z))
	orbitRing:SetAttribute("SpinSpeed", -50)
	orbitRing:SetAttribute("BobSpeed", 2.0)
	orbitRing:SetAttribute("BobAmp", 0.25)
	orbitRing:SetAttribute("TiltAngle", 45)

	-- Format comma helper
	local formattedCost = tostring(math.floor(eggConf.Cost))
	while true do
		local k
		formattedCost, k = string.gsub(formattedCost, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end

	-- ProximityPrompt for Hatching (Attached to capsule)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ObjectText = eggConf.Name
	prompt.ActionText = string.format("Hatch (%s Scrap)", formattedCost)
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = capsule

	prompt.Triggered:Connect(function(player)
		local PetService = require(script.Parent.PetService)
		PetService.hatchEgg(player, eggType)
	end)

	podModel.Parent = parentFolder
	return podModel
end

-- Helper to build an authentic Junkyard Patchwork Ground for a zone (Zero Z-Fighting, Solid Cylinder Geometry)
local function buildScrapyardGround(folder: Instance, centerPos: Vector3, zone: Types.ZoneConfig): Part
	-- Main solid circular cylinder platform (Diameter 120, Height 4, smooth top surface at Y = 0)
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Shape = Enum.PartType.Cylinder
	platform.Size = Vector3.new(4, 120, 120) -- Spacious 120-stud diameter
	platform.CFrame = CFrame.new(centerPos - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	platform.Anchored = true
	platform.CanCollide = true
	platform.Material = Enum.Material.Slate
	platform.Color = Color3.fromRGB(36, 38, 44)
	platform.Parent = folder

	-- Platform anti-trespass touch handler for locked zones
	local platformDebounce: { [Player]: number } = {}
	platform.Touched:Connect(function(hit)
		local char = hit.Parent
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local data = DataService.get(player)
		local maxZ = data and (data.MaxZoneReached or 1) or 1
		if maxZ < zone.Id then
			local now = os.clock()
			if platformDebounce[player] and now - platformDebounce[player] < 1.0 then
				return
			end
			platformDebounce[player] = now

			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local safeZoneId = math.clamp(maxZ, 1, #Config.Zones)
				local safeCenter = ZONE_CENTERS[safeZoneId] or Vector3.new(0, 0, 0)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = CFrame.new(safeCenter + Vector3.new(0, 3.5, 0))

				local notif = Remotes.getEvent("ShowNotification")
				if notif then
					notif:FireClient(player, "SECURITY LOCK", string.format("Zone %d is locked! Unlock it with Scrap to enter.", zone.Id), Color3.fromRGB(255, 75, 75))
				end
			end
		end
	end)

	-- Central Junkyard Scrap Apron Disc (Raised by +0.04 to guarantee zero coplanar flicker / Z-fighting)
	local apron = Instance.new("Part")
	apron.Name = "ScrapApron"
	apron.Shape = Enum.PartType.Cylinder
	apron.Size = Vector3.new(0.08, 56, 56)
	apron.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
	apron.Anchored = true
	apron.CanCollide = false
	apron.Material = Enum.Material.DiamondPlate
	apron.Color = Color3.fromRGB(50, 54, 64)
	apron.Parent = folder

	-- Inner accent ring (Raised by +0.08 to guarantee zero Z-fighting)
	local innerRing = Instance.new("Part")
	innerRing.Name = "ApronAccentRing"
	innerRing.Shape = Enum.PartType.Cylinder
	innerRing.Size = Vector3.new(0.08, 26, 26)
	innerRing.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	innerRing.Anchored = true
	innerRing.CanCollide = false
	innerRing.Material = Enum.Material.CorrodedMetal
	innerRing.Color = Color3.fromRGB(115, 65, 38)
	innerRing.Parent = folder

	return platform
end

-- Helper to build the Modular Industrial Corrugated Perimeter Fence with Barricades & Bulkhead Lighting
local function buildScrapyardPerimeter(folder: Instance, centerPos: Vector3, zone: Types.ZoneConfig, entranceAngle: number?, exitAngle: number?)
	local fenceModel = Instance.new("Model")
	fenceModel.Name = "JunkyardFence_Zone" .. tostring(zone.Id)

	local segments = 24
	local radius = 58

	for i = 1, segments do
		local angle = (i - 1) * (math.pi * 2 / segments)
		local deg = math.deg(angle)

		-- Check if near entrance or exit gateway (leave wide 24-degree opening)
		local isGateway = false
		if entranceAngle then
			local diff = math.abs((angle - entranceAngle + math.pi) % (math.pi * 2) - math.pi)
			if diff < math.rad(24) then
				isGateway = true
			end
		end
		if exitAngle then
			local diff = math.abs((angle - exitAngle + math.pi) % (math.pi * 2) - math.pi)
			if diff < math.rad(24) then
				isGateway = true
			end
		end

		if not isGateway then
			local posX = math.cos(angle) * radius
			local posZ = math.sin(angle) * radius
			local segPos = centerPos + Vector3.new(posX, 0, posZ)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)).Unit
			local lookAngle = math.atan2(tangent.Z, tangent.X)

			local segLength = (math.pi * 2 / segments) * radius * 1.05
			local wallHeight = 7.8 + ((i % 3) * 0.4)
			local wallTilt = (i % 2 == 0 and 2.0 or -2.0)

			local segmentModel = Instance.new("Model")
			segmentModel.Name = string.format("Segment_%02d", i)
			segmentModel.Parent = fenceModel

			local panelCF = CFrame.new(segPos + Vector3.new(0, wallHeight / 2, 0))
				* CFrame.Angles(0, -lookAngle, 0)
				* CFrame.Angles(0, 0, math.rad(wallTilt))

			-- 1. Base Concrete & Steel Foundation Curb
			local curb = Instance.new("Part")
			curb.Name = "BaseCurb"
			curb.Size = Vector3.new(segLength, 0.8, 1.8)
			curb.CFrame = CFrame.new(segPos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, -lookAngle, 0)
			curb.Anchored = true
			curb.Material = Enum.Material.DiamondPlate
			curb.Color = Color3.fromRGB(28, 30, 36)
			curb.Parent = segmentModel

			-- 2. Heavy Corrugated Industrial Steel Panel (Preserves exact name FencePanel)
			local wall = Instance.new("Part")
			wall.Name = "FencePanel"
			wall.Size = Vector3.new(segLength * 0.96, wallHeight - 1.2, 0.8)
			wall.CFrame = panelCF
			wall.Anchored = true
			wall.CanCollide = true
			wall.Material = (i % 2 == 0 and Enum.Material.CorrodedMetal or Enum.Material.Metal)
			wall.Color = (i % 3 == 0 and zone.Color or (i % 2 == 0 and Color3.fromRGB(120, 65, 38) or Color3.fromRGB(55, 60, 72)))
			wall.Parent = segmentModel

			-- Secondary Overlapping Scrap Plate (Adds realistic industrial surface relief)
			local subPlate = Instance.new("Part")
			subPlate.Name = "ArmorPlate"
			subPlate.Size = Vector3.new(segLength * 0.45, wallHeight * 0.6, 0.95)
			subPlate.CFrame = panelCF * CFrame.new(segLength * 0.2, 0, 0.1)
			subPlate.Anchored = true
			subPlate.CanCollide = false
			subPlate.Material = Enum.Material.DiamondPlate
			subPlate.Color = Color3.fromRGB(42, 45, 54)
			subPlate.Parent = segmentModel

			-- 3. Heavy Vertical Steel I-Beam Posts (Preserves exact name FencePost)
			local post = Instance.new("Part")
			post.Name = "FencePost"
			post.Size = Vector3.new(1.6, wallHeight + 1.8, 1.6)
			post.Position = segPos + Vector3.new(0, (wallHeight + 1.8) / 2, 0)
			post.Anchored = true
			post.Material = Enum.Material.Metal
			post.Color = Color3.fromRGB(30, 32, 40)
			post.Parent = segmentModel

			-- 4. Top Channel Bar with Alternating Yellow/Black Hazard Stripes
			local topChannel = Instance.new("Part")
			topChannel.Name = "TopChannel"
			topChannel.Size = Vector3.new(segLength * 0.98, 0.6, 1.2)
			topChannel.CFrame = panelCF * CFrame.new(0, (wallHeight - 1.2) / 2 + 0.3, 0)
			topChannel.Anchored = true
			topChannel.Material = Enum.Material.SmoothPlastic
			topChannel.Color = (i % 2 == 0 and Color3.fromRGB(240, 160, 20) or Color3.fromRGB(25, 27, 34))
			topChannel.Parent = segmentModel

			-- 5. Top Barbed Wire Bracket (Preserves exact name TopBracket)
			local bracket = Instance.new("Part")
			bracket.Name = "TopBracket"
			bracket.Size = Vector3.new(0.6, 1.8, 0.6)
			bracket.CFrame = CFrame.new(post.Position + Vector3.new(0, (wallHeight + 1.8) / 2, 0)) * CFrame.Angles(0, -lookAngle, math.rad(30))
			bracket.Anchored = true
			bracket.CanCollide = false
			bracket.Material = Enum.Material.Metal
			bracket.Color = Color3.fromRGB(45, 48, 55)
			bracket.Parent = segmentModel

			-- 6. Bulkhead Warning Cage Light atop alternate posts
			if i % 2 == 0 then
				local bLamp = Instance.new("Part")
				bLamp.Name = "BulkheadLight"
				bLamp.Shape = Enum.PartType.Ball
				bLamp.Size = Vector3.new(0.8, 0.8, 0.8)
				bLamp.Position = post.Position + Vector3.new(0, (wallHeight + 1.8) / 2 + 0.5, 0)
				bLamp.Anchored = true
				bLamp.Material = Enum.Material.Neon
				bLamp.Color = Color3.fromRGB(255, 120, 30)
				bLamp.Parent = segmentModel

				local bLight = Instance.new("PointLight")
				bLight.Color = Color3.fromRGB(255, 130, 30)
				bLight.Brightness = 0.6
				bLight.Range = 10
				bLight.Parent = bLamp
			end

			-- 7. Exterior Structural Diagonal Kickstand Brace
			local outDir = (segPos - centerPos).Unit
			local brace = Instance.new("Part")
			brace.Name = "KickstandBrace"
			brace.Size = Vector3.new(0.6, 5.5, 0.6)
			brace.CFrame = CFrame.new(segPos + outDir * 1.5 + Vector3.new(0, 2.5, 0), segPos + Vector3.new(0, wallHeight * 0.7, 0))
			brace.Anchored = true
			brace.Material = Enum.Material.Metal
			brace.Color = Color3.fromRGB(38, 42, 50)
			brace.Parent = segmentModel

			-- Stereotypical Junkyard Barricade Clutter (Tucked snugly against fence perimeter)
			if i % 6 == 1 then
				local barricade = Instance.new("Model")
				barricade.Name = "CarCubeBarricade"
				barricade.Parent = segmentModel

				for cubeIdx = 1, 2 do
					local cube = Instance.new("Part")
					cube.Name = "CarCube_" .. tostring(cubeIdx)
					cube.Size = Vector3.new(4.5, 3.8, 4.5)
					cube.Position = segPos + (tangent * 3) + Vector3.new(0, 1.9 + (cubeIdx - 1) * 3.8, 0)
					cube.Orientation = Vector3.new(0, deg + (cubeIdx * 15), 0)
					cube.Anchored = true
					cube.Material = Enum.Material.CorrodedMetal
					cube.Color = (cubeIdx == 1 and Color3.fromRGB(90, 75, 60) or Color3.fromRGB(120, 65, 40))
					cube.Parent = barricade
				end
			elseif i % 6 == 4 then
				local tireStack = Instance.new("Model")
				tireStack.Name = "PerimeterTires"
				tireStack.Parent = segmentModel

				for tIdx = 1, 3 do
					local tire = Instance.new("Part")
					tire.Name = "Tire_" .. tostring(tIdx)
					tire.Shape = Enum.PartType.Cylinder
					tire.Size = Vector3.new(1.4, 4.0, 4.0)
					tire.CFrame = CFrame.new(segPos - (tangent * 2.5) + Vector3.new(0, 0.7 + (tIdx - 1) * 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
					tire.Anchored = true
					tire.Material = Enum.Material.SmoothPlastic
					tire.Color = Color3.fromRGB(24, 25, 28)
					tire.Parent = tireStack
				end
			end
		end
	end

	-- Dedicated Centered Gateway Framing Posts
	local function createGatewayFrame(gAngle: number, prefix: string)
		local gDir = Vector3.new(math.cos(gAngle), 0, math.sin(gAngle)).Unit
		local gTangent = Vector3.new(-gDir.Z, 0, gDir.X).Unit
		local gPos = centerPos + gDir * radius

		local frameModel = Instance.new("Model")
		frameModel.Name = prefix .. "_GatewayFrame"
		frameModel.Parent = fenceModel

		local postL = Instance.new("Part")
		postL.Name = "GatewayPost_Left"
		postL.Size = Vector3.new(2.4, 12, 2.4)
		postL.Position = gPos + gTangent * 11 + Vector3.new(0, 6.0, 0)
		postL.Anchored = true
		postL.Material = Enum.Material.DiamondPlate
		postL.Color = Color3.fromRGB(35, 38, 48)
		postL.Parent = frameModel

		local stripeL = Instance.new("Part")
		stripeL.Name = "HazardStripe_Left"
		stripeL.Size = Vector3.new(2.6, 1.4, 2.6)
		stripeL.Position = postL.Position + Vector3.new(0, 3.0, 0)
		stripeL.Anchored = true
		stripeL.Material = Enum.Material.SmoothPlastic
		stripeL.Color = Color3.fromRGB(245, 165, 20)
		stripeL.Parent = frameModel

		local beaconL = Instance.new("Part")
		beaconL.Name = "ClearanceBeacon_Left"
		beaconL.Shape = Enum.PartType.Ball
		beaconL.Size = Vector3.new(1.0, 1.0, 1.0)
		beaconL.Position = postL.Position + Vector3.new(0, 6.5, 0)
		beaconL.Anchored = true
		beaconL.Material = Enum.Material.Neon
		beaconL.Color = Color3.fromRGB(45, 220, 110)
		beaconL.Parent = frameModel

		local postR = postL:Clone()
		postR.Name = "GatewayPost_Right"
		postR.Position = gPos - gTangent * 11 + Vector3.new(0, 6.0, 0)
		postR.Parent = frameModel

		local stripeR = stripeL:Clone()
		stripeR.Name = "HazardStripe_Right"
		stripeR.Position = postR.Position + Vector3.new(0, 3.0, 0)
		stripeR.Parent = frameModel

		local beaconR = beaconL:Clone()
		beaconR.Name = "ClearanceBeacon_Right"
		beaconR.Position = postR.Position + Vector3.new(0, 6.5, 0)
		beaconR.Parent = frameModel
	end

	if entranceAngle then
		createGatewayFrame(entranceAngle, "Entrance")
	end
	if exitAngle then
		createGatewayFrame(exitAngle, "Exit")
	end

	fenceModel.Parent = folder
	return fenceModel
end

-- 3. Build the Central Town Hub (Oval Scrapyard, Spawn, Pedestals, Recycler Machine, Props)
function ZoneService.constructCentralHub()
	local hubFolder = Workspace:FindFirstChild("CentralHub") :: Folder
	if not hubFolder then
		hubFolder = Instance.new("Folder")
		hubFolder.Name = "CentralHub"
		hubFolder.Parent = Workspace
	end

	-- Clear old props
	for _, c in ipairs(hubFolder:GetChildren()) do
		c:Destroy()
	end

	local zone1Config = Config.Zones[1]
	local centerPos = ZONE_CENTERS[1]

	-- 1. Oval Scrapyard Ground Foundation & Patchwork Floor
	buildScrapyardGround(hubFolder, centerPos, zone1Config)

	-- 2. Stereotypical Junkyard Corrugated Perimeter Fence (Exit gateway towards Zone 2)
	local exitDir = (ZONE_CENTERS[2] - centerPos).Unit
	local exitAngle = math.atan2(exitDir.Z, exitDir.X)
	buildScrapyardPerimeter(hubFolder, centerPos, zone1Config, nil, exitAngle)

	-- 3. Floating Island Underside Rock Root & Anti-Gravity Thruster Units
	EnvironmentService.constructIslandUnderside(hubFolder, centerPos, 1, Color3.fromRGB(140, 100, 70))
	EnvironmentService.constructSurfaceDressing(hubFolder, centerPos, zone1Config)

	-- 4. Spawn Location in Central Plaza
	local spawn = Workspace:FindFirstChild("SpawnLocation") :: SpawnLocation
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(12, 0.5, 12)
	spawn.Position = centerPos + Vector3.new(0, 0.25, 0)
	spawn.Anchored = true
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Color = Color3.fromRGB(45, 115, 195)
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then decal:Destroy() end

	-- 5. Scrap Recycler Machine & Sell Pad along North perimeter (Ample clearance from fence)
	ZoneService.constructRecycler(hubFolder, centerPos + Vector3.new(0, 0, -38), 1)

	-- 6. Zone 1 Exclusive Egg Pod along South-West perimeter
	ZoneService.constructEggPod(hubFolder, centerPos + Vector3.new(-26, 0.4, 38), "RustEgg")

	-- 7. Tool Armory Forge Kiosk along West perimeter (Facing East toward Spawn)
	ZoneService.constructToolArmoryKiosk(hubFolder, centerPos + Vector3.new(-42, 0, 0))

	-- 8. Fast-Travel Portal Pad along South-East perimeter (Distance to scrap nodes is >12 studs)
	createPortalPad(hubFolder, centerPos + Vector3.new(26, 0, 38), 1)

	-- 9. 8 Scrap Nodes in Hub (Zone 1) - Generously spaced in radial mining bays (clear of all corridors)
	local zone1Offsets = {
		Vector3.new(42, 0, -18),
		Vector3.new(22, 0, -40),
		Vector3.new(-22, 0, -40),
		Vector3.new(-42, 0, -18),
		Vector3.new(-42, 0, 18),
		Vector3.new(-14, 0, 42),
		Vector3.new(14, 0, 42),
		Vector3.new(42, 0, 18),
	}
	for i, off in ipairs(zone1Offsets) do
		local pile = ZoneService.createScrapPile(zone1Config, centerPos + off, i)
		pile.Parent = hubFolder
		table.insert(activeNodes, pile)
	end

	-- 10. Thematic Environmental Sci-Fi Props for Zone 1 (Rusty Outpost)
	ZoneService.buildZone1Props(hubFolder, centerPos)

	-- 11. Overhead Gantry Billboard for Zone 1 (Grounded behind Recycler)
	ZoneService.constructZoneSign(hubFolder, centerPos, zone1Config)
end

-- Configure a scrap pile dynamically between Standard and Dense variant
function ZoneService.applyNodeVariant(model: Model, zone: Types.ZoneConfig, isDense: boolean)
	local maxHP = isDense and (zone.DenseHP or 6) or (zone.BaseHP or 3)
	local yieldMult = isDense and (zone.DenseYieldMultiplier or 2.0) or 1.0
	local baseYield = math.floor(zone.BaseYield * yieldMult)

	model:SetAttribute("ZoneId", zone.Id)
	model:SetAttribute("BaseYield", baseYield)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("CurrentHP", maxHP)
	model:SetAttribute("IsDense", isDense)

	local core = model:FindFirstChild("Core") :: Part?
	if core then
		core.Size = isDense and Vector3.new(2.4, 2.4, 2.4) or Vector3.new(1.8, 1.8, 1.8)
		core.Position = Vector3.new(core.Position.X, isDense and 3.6 or 3.4, core.Position.Z)
		core.Color = isDense and Color3.fromRGB(255, 195, 45) or zone.Color
		core.Transparency = 0

		local light = core:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = isDense and Color3.fromRGB(255, 215, 60) or zone.Color
			light.Brightness = isDense and 0.85 or 0.4
			light.Range = isDense and 10 or 6
		end
	end

	local halo = model:FindFirstChild("DenseHalo") :: Part?
	if halo then
		halo.Transparency = isDense and 0.2 or 1
		halo.Color = Color3.fromRGB(255, 215, 60)
		if core then
			halo.Position = core.Position
		end
	end

	local basePart = model:FindFirstChild("Base") :: Part?
	if basePart then
		basePart.Transparency = 0
	end

	local statusLabel = model:FindFirstChild("StatusLabel", true) :: TextLabel?
	if statusLabel then
		statusLabel.Text = isDense and string.format("DENSE %s", zone.Name:upper()) or zone.Name:upper()
		statusLabel.TextColor3 = isDense and Color3.fromRGB(255, 215, 50) or Color3.new(1, 1, 1)
	end

	local hpLabel = model:FindFirstChild("HpLabel", true) :: TextLabel?
	if hpLabel then
		hpLabel.Text = string.format("[ %d / %d HP ]", maxHP, maxHP)
		hpLabel.TextColor3 = isDense and Color3.fromRGB(255, 230, 160) or Color3.fromRGB(200, 220, 240)
	end

	local healthBarFill = model:FindFirstChild("HealthBarFill", true) :: Frame?
	if healthBarFill then
		healthBarFill.Size = UDim2.new(1, 0, 1, 0)
		healthBarFill.BackgroundColor3 = Color3.fromRGB(40, 215, 95)
	end

	local root = model:FindFirstChild("Hitbox")
	local badge = root and root:FindFirstChild("InfoGui") and root.InfoGui:FindFirstChild("Frame") :: Frame?
	local bStroke = badge and badge:FindFirstChildOfClass("UIStroke")
	if bStroke then
		bStroke.Color = isDense and Color3.fromRGB(255, 200, 50) or zone.Color
		bStroke.Thickness = isDense and 2 or 1.5
	end

	local oldPrompt = root and root:FindFirstChild("ScrapPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end
end

-- 3. Create Multi-Part High Detail Scrap Nodes with Health
function ZoneService.createScrapPile(zone: Types.ZoneConfig, position: Vector3, index: number): Model
	local model = Instance.new("Model")
	model.Name = string.format("ScrapPile_%d_%d", zone.Id, index)

	local root = Instance.new("Part")
	root.Name = "Hitbox"
	root.Size = Vector3.new(7, 6, 7)
	root.Position = position + Vector3.new(0, 3, 0)
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Parent = model

	-- 1. Main Irregular Scrap Mound Foundation (Preserves exact name Base)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(6.4, 2.6, 6.4)
	base.Position = position + Vector3.new(0, 1.3, 0)
	base.Anchored = true
	base.Color = zone.Color
	base.Material = Enum.Material.CorrodedMetal
	base.Parent = model

	-- Angular Steel Scrap Armor Slabs layered over base
	local plate1 = Instance.new("Part")
	plate1.Name = "ScrapPlate_1"
	plate1.Size = Vector3.new(4.2, 0.6, 3.8)
	plate1.Position = position + Vector3.new(1.2, 2.2, 0.8)
	plate1.Orientation = Vector3.new(15, 30, -10)
	plate1.Anchored = true
	plate1.Material = Enum.Material.DiamondPlate
	plate1.Color = Color3.fromRGB(55, 60, 72)
	plate1.Parent = model

	local plate2 = Instance.new("Part")
	plate2.Name = "ScrapPlate_2"
	plate2.Size = Vector3.new(3.6, 0.5, 4.0)
	plate2.Position = position + Vector3.new(-1.4, 1.9, -1.0)
	plate2.Orientation = Vector3.new(-20, 45, 15)
	plate2.Anchored = true
	plate2.Material = Enum.Material.Metal
	plate2.Color = Color3.fromRGB(42, 45, 54)
	plate2.Parent = model

	-- 2. Exposed Industrial V8 Engine Block
	local engine = Instance.new("Part")
	engine.Name = "EngineBlock"
	engine.Size = Vector3.new(2.4, 1.8, 2.0)
	engine.Position = position + Vector3.new(-0.8, 2.0, 1.2)
	engine.Orientation = Vector3.new(10, 25, 0)
	engine.Anchored = true
	engine.Material = Enum.Material.Metal
	engine.Color = Color3.fromRGB(38, 40, 48)
	engine.Parent = model

	-- 3. Curved Industrial Exhaust Pipe (Preserves exact name Pipe)
	local pipe = Instance.new("Part")
	pipe.Name = "Pipe"
	pipe.Shape = Enum.PartType.Cylinder
	pipe.Size = Vector3.new(5.8, 1.2, 1.2)
	pipe.Position = position + Vector3.new(0.6, 2.8, 0.4)
	pipe.Orientation = Vector3.new(15, 45, 65)
	pipe.Anchored = true
	pipe.Color = Color3.fromRGB(75, 78, 88)
	pipe.Material = Enum.Material.Metal
	pipe.Parent = model

	-- 4. Battered Salvage Oil Drum (Preserves exact name SalvageBarrel)
	local barrel = Instance.new("Part")
	barrel.Name = "SalvageBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(2.6, 1.6, 1.6)
	barrel.Position = position + Vector3.new(-1.8, 1.3, 1.4)
	barrel.Orientation = Vector3.new(20, 15, 75)
	barrel.Anchored = true
	barrel.Color = Color3.fromRGB(140, 45, 38)
	barrel.Material = Enum.Material.CorrodedMetal
	barrel.Parent = model

	-- 5. Twisted Structural Steel I-Beam (Preserves exact name SteelGirder)
	local girder = Instance.new("Part")
	girder.Name = "SteelGirder"
	girder.Size = Vector3.new(1.2, 5.5, 1.2)
	girder.Position = position + Vector3.new(1.5, 2.8, -1.3)
	girder.Orientation = Vector3.new(35, 25, -20)
	girder.Anchored = true
	girder.Color = Color3.fromRGB(50, 54, 65)
	girder.Material = Enum.Material.DiamondPlate
	girder.Parent = model

	-- 6. Exposed High-Voltage Copper Wiring Bundle
	local copperCoil = Instance.new("Part")
	copperCoil.Name = "CopperCoil"
	copperCoil.Shape = Enum.PartType.Cylinder
	copperCoil.Size = Vector3.new(1.6, 1.2, 1.2)
	copperCoil.Position = position + Vector3.new(1.2, 1.0, 1.8)
	copperCoil.Orientation = Vector3.new(0, 0, 90)
	copperCoil.Anchored = true
	copperCoil.Material = Enum.Material.Foil
	copperCoil.Color = Color3.fromRGB(225, 125, 40)
	copperCoil.Parent = model

	-- 7. Energized Scrap Core (Preserves exact name Core)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.8, 1.8, 1.8)
	core.Position = position + Vector3.new(0, 3.4, 0)
	core.Anchored = true
	core.Color = zone.Color
	core.Material = Enum.Material.Neon
	core.Parent = model

	-- Electric Arc Crackle Particles
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "CoreElectricArcs"
	sparks.Color = ColorSequence.new(zone.Color)
	sparks.Size = NumberSequence.new(0.12, 0.3)
	sparks.Rate = 8
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = core

	-- Dense Halo (Preserves exact name DenseHalo)
	local halo = Instance.new("Part")
	halo.Name = "DenseHalo"
	halo.Shape = Enum.PartType.Cylinder
	halo.Size = Vector3.new(0.4, 4.2, 4.2)
	halo.Position = core.Position
	halo.Orientation = Vector3.new(0, 0, 90)
	halo.Anchored = true
	halo.Color = Color3.fromRGB(255, 215, 60)
	halo.Material = Enum.Material.Neon
	halo.Transparency = 1
	halo.CanCollide = false
	halo.Parent = model

	local light = Instance.new("PointLight")
	light.Color = zone.Color
	light.Brightness = 0.4
	light.Range = 6
	light.Parent = core

	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoGui"
	gui.Size = UDim2.new(0, 160, 0, 56)
	gui.StudsOffset = Vector3.new(0, 5.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 36
	gui.Parent = root

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(1, 0, 1, 0)
	badge.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	badge.BackgroundTransparency = 0.15
	badge.Parent = gui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = badge

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = zone.Color
	bStroke.Thickness = 1.5
	bStroke.Parent = badge

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.Size = UDim2.new(1, -8, 0, 18)
	label.Position = UDim2.new(0, 4, 0, 4)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 12
	label.Text = zone.Name:upper()
	label.Parent = badge

	-- Dynamic Graphical Health Bar
	local healthBarBG = Instance.new("Frame")
	healthBarBG.Name = "HealthBarBG"
	healthBarBG.Size = UDim2.new(1, -16, 0, 8)
	healthBarBG.Position = UDim2.new(0, 8, 0, 24)
	healthBarBG.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	healthBarBG.BorderSizePixel = 0
	healthBarBG.Parent = badge

	local hbgCorner = Instance.new("UICorner")
	hbgCorner.CornerRadius = UDim.new(0, 4)
	hbgCorner.Parent = healthBarBG

	local healthBarFill = Instance.new("Frame")
	healthBarFill.Name = "HealthBarFill"
	healthBarFill.Size = UDim2.new(1, 0, 1, 0)
	healthBarFill.BackgroundColor3 = Color3.fromRGB(40, 215, 95)
	healthBarFill.BorderSizePixel = 0
	healthBarFill.Parent = healthBarBG

	local hbfCorner = Instance.new("UICorner")
	hbfCorner.CornerRadius = UDim.new(0, 4)
	hbfCorner.Parent = healthBarFill

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.Size = UDim2.new(1, 0, 0, 16)
	hpLabel.Position = UDim2.new(0, 0, 0, 36)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 11
	hpLabel.TextColor3 = Color3.fromRGB(200, 220, 240)
	hpLabel.Text = "[ HP ]"
	hpLabel.Parent = badge

	-- Randomize initial dense node per zone (25% RNG per pile)
	local isDenseInitial = (math.random(1, 4) == 1)
	ZoneService.applyNodeVariant(model, zone, isDenseInitial)

	CollectionService:AddTag(model, "ScrapNode")

	return model
end

-- ============================================================================
-- THEMATIC ZONE PROPS BUILDERS (Option A: Environmental Storytelling)
-- ============================================================================

local function createPropPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, partType: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if partType then
		p.Shape = partType
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- Zone 1: Rusty Outpost Props (High-Fidelity Lattice Yard Crane, Coolant Silo with Steam Vents, Oil Drum Pallets)
function ZoneService.buildZone1Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone1"
	props.Parent = folder

	-- 1. Heavy Industrial Lattice Salvage Yard Crane
	local crane = Instance.new("Model")
	crane.Name = "SalvageCrane"
	crane.Parent = props

	local cranePos = center + Vector3.new(-38, 0, -38)

	-- Submodel: Foundation
	local foundation = Instance.new("Model")
	foundation.Name = "Foundation"
	foundation.Parent = crane

	createPropPart(foundation, "ConcretePad", Vector3.new(10, 1.8, 10), CFrame.new(cranePos + Vector3.new(0, 0.9, 0)), Color3.fromRGB(48, 50, 56), Enum.Material.Concrete)
	local cornerOffsets = {
		Vector3.new(-4.2, 1.8, -4.2),
		Vector3.new(4.2, 1.8, -4.2),
		Vector3.new(-4.2, 1.8, 4.2),
		Vector3.new(4.2, 1.8, 4.2),
	}
	for i, cOff in ipairs(cornerOffsets) do
		createPropPart(foundation, "AnchorShoe_" .. i, Vector3.new(2.2, 0.6, 2.2), CFrame.new(cranePos + cOff), Color3.fromRGB(35, 38, 45), Enum.Material.DiamondPlate)
	end

	-- Submodel: Turntable
	local turntable = Instance.new("Model")
	turntable.Name = "Turntable"
	turntable.Parent = crane

	createPropPart(turntable, "SlewingGearRing", Vector3.new(1.2, 7.8, 7.8), CFrame.new(cranePos + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 32, 38), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(turntable, "SlewingMotor", Vector3.new(3.2, 2.4, 2.8), CFrame.new(cranePos + Vector3.new(-2.2, 3.8, -2.2)), Color3.fromRGB(200, 130, 25), Enum.Material.CorrodedMetal)

	-- Submodel: MastAssembly (Open-Lattice 4-Chord Mast)
	local mastAssembly = Instance.new("Model")
	mastAssembly.Name = "MastAssembly"
	mastAssembly.Parent = crane

	local mastHeight = 28
	local chordOffsets = {
		Vector3.new(-2.2, 0, -2.2),
		Vector3.new(2.2, 0, -2.2),
		Vector3.new(-2.2, 0, 2.2),
		Vector3.new(2.2, 0, 2.2),
	}
	for i, chOff in ipairs(chordOffsets) do
		createPropPart(mastAssembly, "MastChord_" .. i, Vector3.new(0.8, mastHeight, 0.8), CFrame.new(cranePos + chOff + Vector3.new(0, 3 + (mastHeight / 2), 0)), Color3.fromRGB(215, 140, 28), Enum.Material.DiamondPlate)
	end

	-- Mast Horizontal Battens & Cross Lacing
	local battenModel = Instance.new("Model")
	battenModel.Name = "LatticeBracing"
	battenModel.Parent = mastAssembly

	for b = 1, 6 do
		local bY = 5 + (b * 4)
		createPropPart(battenModel, "BattenRing_" .. b, Vector3.new(5.2, 0.5, 5.2), CFrame.new(cranePos + Vector3.new(0, bY, 0)), Color3.fromRGB(180, 115, 20), Enum.Material.Metal)
	end

	-- Climbing Service Ladder up the back spine
	local ladderModel = Instance.new("Model")
	ladderModel.Name = "ServiceLadder"
	ladderModel.Parent = mastAssembly

	createPropPart(ladderModel, "LadderRailL", Vector3.new(0.3, mastHeight - 4, 0.3), CFrame.new(cranePos + Vector3.new(-0.8, 4 + (mastHeight / 2), -2.6)), Color3.fromRGB(40, 42, 48), Enum.Material.Metal)
	createPropPart(ladderModel, "LadderRailR", Vector3.new(0.3, mastHeight - 4, 0.3), CFrame.new(cranePos + Vector3.new(0.8, 4 + (mastHeight / 2), -2.6)), Color3.fromRGB(40, 42, 48), Enum.Material.Metal)
	for rung = 1, 12 do
		createPropPart(ladderModel, "Rung_" .. rung, Vector3.new(1.6, 0.25, 0.25), CFrame.new(cranePos + Vector3.new(0, 6 + (rung * 1.8), -2.6)), Color3.fromRGB(200, 190, 180), Enum.Material.Metal)
	end

	-- Masthead Landing Platform
	createPropPart(mastAssembly, "MastPlatform", Vector3.new(6.8, 0.6, 6.8), CFrame.new(cranePos + Vector3.new(0, 3 + mastHeight, 0)), Color3.fromRGB(45, 48, 55), Enum.Material.DiamondPlate)

	-- Submodel: OperatorCabin
	local cabin = Instance.new("Model")
	cabin.Name = "OperatorCabin"
	cabin.Parent = crane

	local cabPos = cranePos + Vector3.new(3.8, 3 + mastHeight - 2, 2.5)
	createPropPart(cabin, "CabBody", Vector3.new(4.2, 5.0, 4.8), CFrame.new(cabPos), Color3.fromRGB(38, 42, 50), Enum.Material.Metal)
	createPropPart(cabin, "CabRoof", Vector3.new(4.6, 0.4, 5.2), CFrame.new(cabPos + Vector3.new(0, 2.6, 0)), Color3.fromRGB(200, 130, 25), Enum.Material.Metal)
	createPropPart(cabin, "CabWindshield", Vector3.new(3.6, 2.8, 0.4), CFrame.new(cabPos + Vector3.new(0, 0.4, 2.45)) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(80, 190, 230), Enum.Material.Glass)
	
	local cabDash = createPropPart(cabin, "CabConsole", Vector3.new(2.8, 0.8, 1.2), CFrame.new(cabPos + Vector3.new(0, -0.6, 1.4)), Color3.fromRGB(25, 28, 34), Enum.Material.Metal)
	local cabLight = Instance.new("PointLight")
	cabLight.Color = Color3.fromRGB(255, 175, 50)
	cabLight.Brightness = 0.4
	cabLight.Range = 6
	cabLight.Parent = cabDash

	-- Halogen Work Spotlight under cabin
	local spotMount = createPropPart(cabin, "WorkSpotlight", Vector3.new(1.4, 1.4, 1.8), CFrame.new(cabPos + Vector3.new(0, -2.8, 1.2)) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(245, 240, 220), Enum.Material.Neon)
	local spotLamp = Instance.new("SpotLight")
	spotLamp.Color = Color3.fromRGB(255, 245, 220)
	spotLamp.Brightness = 0.6
	spotLamp.Range = 35
	spotLamp.Angle = 45
	spotLamp.Parent = spotMount

	-- Submodel: BoomAndCounterweight
	local boomAssembly = Instance.new("Model")
	boomAssembly.Name = "BoomAssembly"
	boomAssembly.Parent = crane

	local boomApexY = 3 + mastHeight + 4
	-- A-Frame Apex Tower
	createPropPart(boomAssembly, "ApexTowerL", Vector3.new(0.6, 7.5, 0.6), CFrame.new(cranePos + Vector3.new(-1.8, boomApexY, 0)) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(215, 140, 28), Enum.Material.Metal)
	createPropPart(boomAssembly, "ApexTowerR", Vector3.new(0.6, 7.5, 0.6), CFrame.new(cranePos + Vector3.new(1.8, boomApexY, 0)) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(215, 140, 28), Enum.Material.Metal)

	-- Main Jib Boom (Reaching 28 studs forward into the scrap yard)
	local jibLen = 28
	local jibCenterZ = jibLen / 2
	createPropPart(boomAssembly, "JibChordTop", Vector3.new(2.4, 0.8, jibLen), CFrame.new(cranePos + Vector3.new(0, 3 + mastHeight + 1.8, jibCenterZ)), Color3.fromRGB(215, 140, 28), Enum.Material.Metal)
	createPropPart(boomAssembly, "JibChordBottom", Vector3.new(3.0, 1.0, jibLen), CFrame.new(cranePos + Vector3.new(0, 3 + mastHeight, jibCenterZ)), Color3.fromRGB(195, 125, 22), Enum.Material.DiamondPlate)

	-- Rear Counterweight Arm & Ballast Blocks
	local cjLen = 12
	createPropPart(boomAssembly, "CounterJibDeck", Vector3.new(3.2, 1.2, cjLen), CFrame.new(cranePos + Vector3.new(0, 3 + mastHeight + 0.5, -cjLen / 2)), Color3.fromRGB(180, 115, 20), Enum.Material.Metal)
	local ballastModel = Instance.new("Model")
	ballastModel.Name = "Counterweights"
	ballastModel.Parent = boomAssembly
	for bi = 1, 3 do
		createPropPart(ballastModel, "BallastBlock_" .. bi, Vector3.new(4.8, 3.2, 2.4), CFrame.new(cranePos + Vector3.new(0, 3 + mastHeight + 2.2, -cjLen + 1.8 + ((bi - 1) * 2.6))), Color3.fromRGB(52, 54, 60), Enum.Material.Concrete)
	end

	-- High-Tensile Steel Tension Stay Cables
	createPropPart(boomAssembly, "StayCable_JibTip", Vector3.new(0.3, 19, 0.3), CFrame.new(cranePos + Vector3.new(0, boomApexY + 1, jibCenterZ * 0.9)) * CFrame.Angles(math.rad(48), 0, 0), Color3.fromRGB(70, 75, 85), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(boomAssembly, "StayCable_CounterJib", Vector3.new(0.3, 14, 0.3), CFrame.new(cranePos + Vector3.new(0, boomApexY + 1, -cjLen * 0.5)) * CFrame.Angles(math.rad(-42), 0, 0), Color3.fromRGB(70, 75, 85), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Submodel: HoistAndGrappleClaw
	local hoistClaw = Instance.new("Model")
	hoistClaw.Name = "HoistAndClaw"
	hoistClaw.Parent = crane

	local trolleyPos = cranePos + Vector3.new(0, 3 + mastHeight - 0.6, 18)
	local trolley = createPropPart(hoistClaw, "TrolleyCarriage", Vector3.new(3.4, 0.9, 3.4), CFrame.new(trolleyPos), Color3.fromRGB(36, 40, 48), Enum.Material.Metal)

	local trolleyStrobe = Instance.new("PointLight")
	trolleyStrobe.Color = Color3.fromRGB(255, 185, 30)
	trolleyStrobe.Brightness = 0.5
	trolleyStrobe.Range = 10
	trolleyStrobe.Parent = trolley

	-- Dual Braided Steel Cables
	local cableDrop = 14
	createPropPart(hoistClaw, "CableLeft", Vector3.new(0.2, cableDrop, 0.2), CFrame.new(trolleyPos + Vector3.new(-0.8, -cableDrop / 2, 0)), Color3.fromRGB(30, 32, 36), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(hoistClaw, "CableRight", Vector3.new(0.2, cableDrop, 0.2), CFrame.new(trolleyPos + Vector3.new(0.8, -cableDrop / 2, 0)), Color3.fromRGB(30, 32, 36), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Heavy 4-Jaw Hydraulic Scrap Grapple Claw
	local clawCenter = trolleyPos + Vector3.new(0, -cableDrop, 0)
	local clawHub = createPropPart(hoistClaw, "ClawHub", Vector3.new(1.4, 3.8, 3.8), CFrame.new(clawCenter) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 45, 54), Enum.Material.Metal, Enum.PartType.Cylinder)

	local clawArms = Instance.new("Model")
	clawArms.Name = "ClawJaws"
	clawArms.Parent = hoistClaw

	local clawDirs = {
		{ Ang = 0, Off = Vector3.new(0, -1.2, 1.8) },
		{ Ang = 90, Off = Vector3.new(1.8, -1.2, 0) },
		{ Ang = 180, Off = Vector3.new(0, -1.2, -1.8) },
		{ Ang = 270, Off = Vector3.new(-1.8, -1.2, 0) },
	}
	for i, cData in ipairs(clawDirs) do
		local jaw = createPropPart(clawArms, "ClawJaw_" .. i, Vector3.new(0.9, 3.6, 1.2), CFrame.new(clawCenter + cData.Off) * CFrame.Angles(math.rad(30), math.rad(cData.Ang), 0), Color3.fromRGB(215, 145, 30), Enum.Material.Metal)
		-- Chrome hydraulic cylinder
		createPropPart(clawArms, "HydraulicRam_" .. i, Vector3.new(2.4, 0.5, 0.5), CFrame.new(clawCenter + (cData.Off * 0.6) + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.rad(cData.Ang), math.rad(45)), Color3.fromRGB(195, 205, 215), Enum.Material.Metal, Enum.PartType.Cylinder)
		-- Claw tooth tip
		createPropPart(clawArms, "JawTip_" .. i, Vector3.new(0.8, 1.0, 1.0), jaw.CFrame * CFrame.new(0, -1.8, 0.4), Color3.fromRGB(245, 175, 20), Enum.Material.SmoothPlastic)
	end

	-- 2. Heavy Rusted Cryo-Coolant Silo
	local silo = Instance.new("Model")
	silo.Name = "CoolantSilo"
	silo.Parent = props

	local siloPos = center + Vector3.new(0, 0, 48)

	-- Submodel: Foundation
	local sFoundation = Instance.new("Model")
	sFoundation.Name = "Foundation"
	sFoundation.Parent = silo

	createPropPart(sFoundation, "ConcretePlinth", Vector3.new(1.4, 11, 11), CFrame.new(siloPos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(48, 50, 56), Enum.Material.Concrete, Enum.PartType.Cylinder)

	-- Submodel: SiloVessel
	local sVessel = Instance.new("Model")
	sVessel.Name = "SiloVessel"
	sVessel.Parent = silo

	createPropPart(sVessel, "SiloTankBody", Vector3.new(20, 8.2, 8.2), CFrame.new(siloPos + Vector3.new(0, 11.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(145, 82, 48), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	createPropPart(sVessel, "DomeCap", Vector3.new(8.2, 5.0, 8.2), CFrame.new(siloPos + Vector3.new(0, 21.6, 0)), Color3.fromRGB(125, 70, 40), Enum.Material.Metal, Enum.PartType.Ball)
	
	-- Circumferential Steel Stiffener Rings
	for r = 1, 3 do
		local rY = 4 + (r * 4.5)
		createPropPart(sVessel, "StiffenerRing_" .. r, Vector3.new(0.8, 8.8, 8.8), CFrame.new(siloPos + Vector3.new(0, rY, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 45, 52), Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	-- Submodel: ServiceAccess
	local sAccess = Instance.new("Model")
	sAccess.Name = "ServiceAccess"
	sAccess.Parent = silo

	createPropPart(sAccess, "CatwalkRing", Vector3.new(0.8, 10.6, 10.6), CFrame.new(siloPos + Vector3.new(0, 14.0, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(38, 42, 50), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	createPropPart(sAccess, "SafetyRailing", Vector3.new(0.6, 11.4, 11.4), CFrame.new(siloPos + Vector3.new(0, 16.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(195, 130, 25), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Submodel: ReliefManifold
	local sManifold = Instance.new("Model")
	sManifold.Name = "ReliefManifold"
	sManifold.Parent = silo

	local ventElbow = createPropPart(sManifold, "VentPipeElbow", Vector3.new(1.0, 5.0, 1.0), CFrame.new(siloPos + Vector3.new(4.5, 17, 0)), Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
	local ventNozzle = createPropPart(sManifold, "VentNozzle", Vector3.new(1.4, 1.4, 1.4), CFrame.new(siloPos + Vector3.new(5.0, 19.5, 0)), Color3.fromRGB(35, 38, 45), Enum.Material.Metal)
	
	-- Cryo Steam Vent Particles
	local steamEmitter = Instance.new("ParticleEmitter")
	steamEmitter.Name = "CryoMistEmitter"
	steamEmitter.Texture = "rbxassetid://243098098"
	steamEmitter.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(180, 215, 245))
	steamEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 2.5),
		NumberSequenceKeypoint.new(1, 4.2),
	})
	steamEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	steamEmitter.Lifetime = NumberRange.new(1.5, 2.5)
	steamEmitter.Rate = 12
	steamEmitter.Speed = NumberRange.new(3, 6)
	steamEmitter.SpreadAngle = Vector2.new(20, 20)
	steamEmitter.EmissionDirection = Enum.NormalId.Right
	steamEmitter.Parent = ventNozzle

	-- 3. Palletized Industrial Salvage Oil Drum Cache
	local drumCluster = Instance.new("Model")
	drumCluster.Name = "OilDrumCluster"
	drumCluster.Parent = props

	-- Submodel: Pallets
	local pallets = Instance.new("Model")
	pallets.Name = "WoodenPallets"
	pallets.Parent = drumCluster

	createPropPart(pallets, "PalletWest", Vector3.new(6.5, 0.7, 6.5), CFrame.new(center + Vector3.new(-7, 0.35, 47)), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
	createPropPart(pallets, "PalletEast", Vector3.new(6.5, 0.7, 6.5), CFrame.new(center + Vector3.new(7, 0.35, 47)), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)

	-- Submodel: HazardDrums
	local drums = Instance.new("Model")
	drums.Name = "HazardDrums"
	drums.Parent = drumCluster

	local drumConfigs = {
		{ Pos = Vector3.new(-8.2, 2.1, 46.0), Color = Color3.fromRGB(145, 60, 35), Rot = Vector3.new(90, 0, 0) },
		{ Pos = Vector3.new(-6.0, 2.1, 48.0), Color = Color3.fromRGB(160, 75, 40), Rot = Vector3.new(90, 0, 0) },
		{ Pos = Vector3.new(-7.0, 4.9, 47.0), Color = Color3.fromRGB(195, 135, 30), Rot = Vector3.new(90, 0, 0) },
		{ Pos = Vector3.new(6.2, 2.1, 46.0), Color = Color3.fromRGB(45, 95, 140), Rot = Vector3.new(90, 0, 0) },
		{ Pos = Vector3.new(8.0, 2.1, 48.0), Color = Color3.fromRGB(130, 55, 35), Rot = Vector3.new(90, 0, 0) },
		{ Pos = Vector3.new(7.0, 1.6, 49.5), Color = Color3.fromRGB(140, 60, 35), Rot = Vector3.new(0, 30, 90) }, -- Tipped drum
	}

	for i, dc in ipairs(drumConfigs) do
		local drum = createPropPart(drums, "DrumBarrel_" .. i, Vector3.new(3.0, 1.9, 1.9), CFrame.new(center + dc.Pos) * CFrame.Angles(math.rad(dc.Rot.X), math.rad(dc.Rot.Y), math.rad(dc.Rot.Z)), dc.Color, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		-- Chime Ribs
		createPropPart(drums, "ChimeRibA_" .. i, Vector3.new(0.2, 2.05, 2.05), drum.CFrame * CFrame.new(-0.8, 0, 0), Color3.fromRGB(30, 32, 38), Enum.Material.Metal, Enum.PartType.Cylinder)
		createPropPart(drums, "ChimeRibB_" .. i, Vector3.new(0.2, 2.05, 2.05), drum.CFrame * CFrame.new(0.8, 0, 0), Color3.fromRGB(30, 32, 38), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

-- Zone 2: Automotive Graveyard Props (Hydraulic Cyber-Car Crusher, Crushed Car Stacks, Heavy Mining Radial Tire Pyramids)
function ZoneService.buildZone2Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone2"
	props.Parent = folder

	-- 1. Heavy Industrial Hydraulic Cyber-Car Crusher Press (West Perimeter facing East)
	local crusher = Instance.new("Model")
	crusher.Name = "HydraulicCarCrusher"
	crusher.Parent = props

	local crusherCF = CFrame.new(center + Vector3.new(-38, 0, 0)) * CFrame.Angles(0, math.rad(90), 0)

	-- Submodel: FoundationGrate
	local foundation = Instance.new("Model")
	foundation.Name = "FoundationGrate"
	foundation.Parent = crusher

	createPropPart(foundation, "ConcreteFooting", Vector3.new(24, 1.4, 14), crusherCF * CFrame.new(0, 0.7, 0), Color3.fromRGB(44, 46, 52), Enum.Material.Concrete)
	createPropPart(foundation, "DrainageGrate", Vector3.new(20, 0.4, 10), crusherCF * CFrame.new(0, 1.4, 0), Color3.fromRGB(32, 34, 40), Enum.Material.DiamondPlate)

	-- Submodel: FrameColumns
	local frame = Instance.new("Model")
	frame.Name = "FrameColumns"
	frame.Parent = crusher

	local colCoords = {
		Vector3.new(-9.5, 0, -4.5),
		Vector3.new(9.5, 0, -4.5),
		Vector3.new(-9.5, 0, 4.5),
		Vector3.new(9.5, 0, 4.5),
	}
	for i, cCoord in ipairs(colCoords) do
		-- H-Beam vertical guide column
		createPropPart(frame, "GuideColumn_" .. i, Vector3.new(2.4, 20, 2.4), crusherCF * CFrame.new(cCoord + Vector3.new(0, 10.7, 0)), Color3.fromRGB(60, 75, 92), Enum.Material.DiamondPlate)
		-- Base Gusset Plate
		createPropPart(frame, "GussetPlate_" .. i, Vector3.new(3.4, 1.8, 3.4), crusherCF * CFrame.new(cCoord + Vector3.new(0, 2.0, 0)), Color3.fromRGB(40, 48, 58), Enum.Material.Metal)
	end

	-- Heavy Box-Girder Headstock
	createPropPart(frame, "HeadstockBeam", Vector3.new(24, 4.2, 12), crusherCF * CFrame.new(0, 21.5, 0), Color3.fromRGB(42, 52, 64), Enum.Material.Metal)
	createPropPart(frame, "HazardTrimHead", Vector3.new(24.2, 0.8, 12.2), crusherCF * CFrame.new(0, 19.6, 0), Color3.fromRGB(245, 175, 25), Enum.Material.SmoothPlastic)

	-- Submodel: HydraulicRamAssembly
	local ramAssembly = Instance.new("Model")
	ramAssembly.Name = "HydraulicRamAssembly"
	ramAssembly.Parent = crusher

	-- Twin Chrome Hydraulic Cylinders
	createPropPart(ramAssembly, "HydraulicCylinderL", Vector3.new(10, 2.2, 2.2), crusherCF * CFrame.new(-5, 14.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(195, 205, 218), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(ramAssembly, "HydraulicCylinderR", Vector3.new(10, 2.2, 2.2), crusherCF * CFrame.new(5, 14.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(195, 205, 218), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Reinforced Steel Crusher Ram Plate with Crushing Teeth
	local ramPlate = createPropPart(ramAssembly, "CrusherRamPlate", Vector3.new(18, 2.4, 8), crusherCF * CFrame.new(0, 8.5, 0), Color3.fromRGB(80, 95, 110), Enum.Material.DiamondPlate)
	for t = 1, 4 do
		createPropPart(ramAssembly, "CrushTooth_" .. t, Vector3.new(1.4, 1.2, 1.4), crusherCF * CFrame.new(-6 + ((t - 1) * 4), 7.0, 0), Color3.fromRGB(50, 58, 68), Enum.Material.Metal)
	end

	-- Submodel: CrushedVehicleBed (Inside the crusher press)
	local carBed = Instance.new("Model")
	carBed.Name = "CrushedVehicleBed"
	carBed.Parent = crusher

	local crushedCar = createPropPart(carBed, "CrushedCarChassis", Vector3.new(16, 2.2, 7), crusherCF * CFrame.new(0, 2.5, 0), Color3.fromRGB(150, 48, 55), Enum.Material.Metal)
	createPropPart(carBed, "BentCockpitRoof", Vector3.new(10, 1.4, 5.5), crusherCF * CFrame.new(1, 3.8, 0) * CFrame.Angles(math.rad(8), math.rad(-5), math.rad(4)), Color3.fromRGB(35, 40, 48), Enum.Material.Metal)

	-- Grinding Metal Sparks Emitter
	local grindSparks = Instance.new("ParticleEmitter")
	grindSparks.Name = "MetalSparks"
	grindSparks.Texture = "rbxassetid://258129523"
	grindSparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 20))
	grindSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	grindSparks.Lifetime = NumberRange.new(0.6, 1.2)
	grindSparks.Rate = 8
	grindSparks.Speed = NumberRange.new(5, 12)
	grindSparks.SpreadAngle = Vector2.new(45, 45)
	grindSparks.EmissionDirection = Enum.NormalId.Top
	grindSparks.Parent = crushedCar

	-- Submodel: ControlStation
	local cStation = Instance.new("Model")
	cStation.Name = "ControlStation"
	cStation.Parent = crusher

	local panelCF = crusherCF * CFrame.new(13.5, 0, 4.5)
	createPropPart(cStation, "Pedestal", Vector3.new(1.8, 4.2, 1.8), panelCF * CFrame.new(0, 2.1, 0), Color3.fromRGB(36, 40, 48), Enum.Material.Metal)
	local console = createPropPart(cStation, "ConsoleHead", Vector3.new(2.4, 1.6, 2.2), panelCF * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(50, 58, 68), Enum.Material.Metal)
	local estop = createPropPart(cStation, "EmergencyStop", Vector3.new(0.8, 0.6, 0.8), console.CFrame * CFrame.new(0.6, 0.4, 0), Color3.fromRGB(230, 45, 45), Enum.Material.Neon, Enum.PartType.Cylinder)

	-- 2. Crushed Cyber-Car Stack (North-West Perimeter)
	local carStack1 = Instance.new("Model")
	carStack1.Name = "CrushedCarStack_NorthWest"
	carStack1.Parent = props

	local carPos1 = center + Vector3.new(-26, 0, -26)

	-- Tier 1: Bottom Heavy Cruiser
	local c1Base = createPropPart(carStack1, "Car1_Chassis", Vector3.new(8.5, 2.4, 13), CFrame.new(carPos1 + Vector3.new(0, 1.2, 0)), Color3.fromRGB(52, 85, 115), Enum.Material.Metal)
	createPropPart(carStack1, "Car1_ShatteredWindshield", Vector3.new(7.2, 1.2, 4.5), CFrame.new(carPos1 + Vector3.new(0, 2.6, -1)), Color3.fromRGB(22, 28, 38), Enum.Material.Glass)
	createPropPart(carStack1, "Car1_WheelRimL", Vector3.new(1.4, 3.2, 3.2), CFrame.new(carPos1 + Vector3.new(-4.2, 1.6, 3)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(24, 25, 28), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(carStack1, "Car1_WheelRimR", Vector3.new(1.4, 3.2, 3.2), CFrame.new(carPos1 + Vector3.new(4.2, 1.6, 3)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(24, 25, 28), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Tier 2: Middle Compact Speeder (Oxidized Crimson)
	local rotCar2 = CFrame.Angles(math.rad(6), math.rad(14), math.rad(-5))
	createPropPart(carStack1, "Car2_Chassis", Vector3.new(7.8, 2.0, 11.5), CFrame.new(carPos1 + Vector3.new(0.4, 3.4, 0)) * rotCar2, Color3.fromRGB(145, 52, 60), Enum.Material.CorrodedMetal)
	createPropPart(carStack1, "Car2_CrushedCabin", Vector3.new(6.4, 1.2, 4.0), CFrame.new(carPos1 + Vector3.new(0.6, 4.8, -0.6)) * rotCar2, Color3.fromRGB(25, 26, 32), Enum.Material.Metal)

	-- Tier 3: Top Hover Wedge (Angled and battered)
	local rotCar3 = CFrame.Angles(math.rad(-8), math.rad(-22), math.rad(10))
	createPropPart(carStack1, "Car3_Chassis", Vector3.new(6.8, 1.8, 9.8), CFrame.new(carPos1 + Vector3.new(-0.3, 5.2, 0.4)) * rotCar3, Color3.fromRGB(200, 140, 30), Enum.Material.Metal)

	-- 3. Crushed Cyber-Car Stack (North-East Perimeter)
	local carStack2 = Instance.new("Model")
	carStack2.Name = "CrushedCarStack_NorthEast"
	carStack2.Parent = props

	local carPos2 = center + Vector3.new(26, 0, -26)

	local rotCarB1 = CFrame.Angles(0, math.rad(-15), 0)
	createPropPart(carStack2, "CarStack2_BaseChassis", Vector3.new(9.0, 2.5, 13.5), CFrame.new(carPos2 + Vector3.new(0, 1.25, 0)) * rotCarB1, Color3.fromRGB(165, 125, 38), Enum.Material.Metal)
	createPropPart(carStack2, "CarStack2_FrontBumper", Vector3.new(9.4, 1.6, 1.4), CFrame.new(carPos2 + Vector3.new(0, 1.25, 6.8)) * rotCarB1, Color3.fromRGB(38, 40, 48), Enum.Material.DiamondPlate)

	local rotCarB2 = CFrame.Angles(math.rad(-6), math.rad(-28), math.rad(8))
	createPropPart(carStack2, "CarStack2_TopChassis", Vector3.new(7.6, 2.2, 11), CFrame.new(carPos2 + Vector3.new(-0.4, 3.4, 0)) * rotCarB2, Color3.fromRGB(72, 78, 94), Enum.Material.Metal)
	createPropPart(carStack2, "CarStack2_ExhaustPipes", Vector3.new(3.2, 0.8, 0.8), CFrame.new(carPos2 + Vector3.new(-0.4, 2.8, -5.5)) * rotCarB2, Color3.fromRGB(25, 26, 30), Enum.Material.Metal)

	-- 4. Giant Heavy-Equipment Radial Tire Pyramids (South-East & South Perimeter)
	local tireClusters = {
		{ Pos = Vector3.new(26, 0, 26), Name = "TireStack_SouthEast" },
		{ Pos = Vector3.new(0, 0, 30), Name = "TireStack_South" },
	}
	for _, cluster in ipairs(tireClusters) do
		local tModel = Instance.new("Model")
		tModel.Name = cluster.Name
		tModel.Parent = props

		local tPos = center + cluster.Pos

		-- Bottom row of 3 giant tires
		local tireBaseOffsets = {
			Vector3.new(-4.5, 1.2, 0),
			Vector3.new(0, 1.2, 0.6),
			Vector3.new(4.5, 1.2, -0.2),
		}
		for ti, bOff in ipairs(tireBaseOffsets) do
			local tire = createPropPart(tModel, "BaseTire_" .. ti, Vector3.new(2.2, 5.8, 5.8), CFrame.new(tPos + bOff) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(24, 25, 28), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			-- Rusted Steel Wheel Hub
			createPropPart(tModel, "WheelHub_" .. ti, Vector3.new(2.4, 2.6, 2.6), tire.CFrame, Color3.fromRGB(120, 75, 45), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		end

		-- Middle row of 2 tires
		local tireMidOffsets = {
			Vector3.new(-2.2, 3.4, 0.2),
			Vector3.new(2.2, 3.4, 0.1),
		}
		for ti, mOff in ipairs(tireMidOffsets) do
			createPropPart(tModel, "MidTire_" .. ti, Vector3.new(2.2, 5.6, 5.6), CFrame.new(tPos + mOff) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(26, 27, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end

		-- Apex tire on top
		createPropPart(tModel, "ApexTire", Vector3.new(2.2, 5.4, 5.4), CFrame.new(tPos + Vector3.new(0, 5.6, 0.1)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 29, 32), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

-- Zone 3: Industrial Foundry Props (Blast Smelting Chimneys, Molten Slag Crucible, Overhead Conveyor Truss, Ingot Stacks)
function ZoneService.buildZone3Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone3"
	props.Parent = folder

	-- 1. Twin Heavy Blast Smelting Chimney Kilns (North Border Flanking Recycler)
	local chimneyOffsets = {
		{ Off = Vector3.new(-18, 0, -34), Name = "SmeltingChimney_Left" },
		{ Off = Vector3.new(18, 0, -34), Name = "SmeltingChimney_Right" },
	}
	for _, chData in ipairs(chimneyOffsets) do
		local chModel = Instance.new("Model")
		chModel.Name = chData.Name
		chModel.Parent = props

		local chPos = center + chData.Off

		-- Submodel: RefractoryBase
		local rBase = Instance.new("Model")
		rBase.Name = "RefractoryBase"
		rBase.Parent = chModel

		createPropPart(rBase, "PlinthOctagon", Vector3.new(2.4, 10, 10), CFrame.new(chPos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(48, 42, 40), Enum.Material.Slate, Enum.PartType.Cylinder)

		-- Submodel: BandedStack
		local bStack = Instance.new("Model")
		bStack.Name = "BandedStack"
		bStack.Parent = chModel

		-- Main Tapered Kiln Stack
		local stackCol = createPropPart(bStack, "ChimneyColumn", Vector3.new(26, 7.8, 7.8), CFrame.new(chPos + Vector3.new(0, 14.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(68, 50, 44), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		
		-- Circumferential Steel Structural Tension Bands
		for band = 1, 4 do
			local bY = 5 + (band * 5)
			createPropPart(bStack, "TensionBand_" .. band, Vector3.new(0.8, 8.4, 8.4), CFrame.new(chPos + Vector3.new(0, bY, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(36, 34, 38), Enum.Material.Metal, Enum.PartType.Cylinder)
		end

		-- Flared Exhaust Crown Rim
		local crown = createPropPart(bStack, "ExhaustCrown", Vector3.new(2.2, 9.2, 9.2), CFrame.new(chPos + Vector3.new(0, 27.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 34, 32), Enum.Material.Metal, Enum.PartType.Cylinder)

		-- Crown Interior Smoke & Heat Embers
		local smokeEmitter = Instance.new("ParticleEmitter")
		smokeEmitter.Name = "FurnaceSmoke"
		smokeEmitter.Texture = "rbxassetid://243098098"
		smokeEmitter.Color = ColorSequence.new(Color3.fromRGB(70, 65, 65), Color3.fromRGB(30, 28, 28))
		smokeEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(0.5, 4.5),
			NumberSequenceKeypoint.new(1, 8.0),
		})
		smokeEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.7, 0.6),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		smokeEmitter.Lifetime = NumberRange.new(3, 5)
		smokeEmitter.Rate = 10
		smokeEmitter.Speed = NumberRange.new(4, 8)
		smokeEmitter.SpreadAngle = Vector2.new(15, 15)
		smokeEmitter.EmissionDirection = Enum.NormalId.Top
		smokeEmitter.Parent = crown

		-- Submodel: FurnaceFirebox
		local fBox = Instance.new("Model")
		fBox.Name = "FurnaceFirebox"
		fBox.Parent = chModel

		local fireDoor = createPropPart(fBox, "StokeDoorFrame", Vector3.new(4.2, 4.5, 1.2), CFrame.new(chPos + Vector3.new(0, 3.2, 3.8)), Color3.fromRGB(35, 32, 36), Enum.Material.Metal)
		local glowingInterior = createPropPart(fBox, "MoltenCoreGlow", Vector3.new(3.0, 3.2, 0.6), CFrame.new(chPos + Vector3.new(0, 3.2, 4.2)), Color3.fromRGB(255, 125, 25), Enum.Material.Neon)
		
		local fireLight = Instance.new("PointLight")
		fireLight.Color = Color3.fromRGB(255, 140, 35)
		fireLight.Brightness = 0.8
		fireLight.Range = 14
		fireLight.Parent = glowingInterior
	end

	-- 2. Heavy Molten Slag Crucible Cauldron (North-West Perimeter)
	local crucible = Instance.new("Model")
	crucible.Name = "MoltenSlagCrucible"
	crucible.Parent = props

	local crucPos = center + Vector3.new(-26, 0, -24)

	-- Submodel: AFrameStands
	local stands = Instance.new("Model")
	stands.Name = "AFrameStands"
	stands.Parent = crucible

	createPropPart(stands, "BearingPedestalL", Vector3.new(2.4, 9, 2.4), CFrame.new(crucPos + Vector3.new(-5.2, 4.5, 0)), Color3.fromRGB(48, 45, 52), Enum.Material.DiamondPlate)
	createPropPart(stands, "BearingPedestalR", Vector3.new(2.4, 9, 2.4), CFrame.new(crucPos + Vector3.new(5.2, 4.5, 0)), Color3.fromRGB(48, 45, 52), Enum.Material.DiamondPlate)
	createPropPart(stands, "TrunnionShaftL", Vector3.new(1.8, 1.2, 1.2), CFrame.new(crucPos + Vector3.new(-4.2, 6.5, 0)), Color3.fromRGB(180, 185, 195), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(stands, "TrunnionShaftR", Vector3.new(1.8, 1.2, 1.2), CFrame.new(crucPos + Vector3.new(4.2, 6.5, 0)), Color3.fromRGB(180, 185, 195), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Submodel: LadleCauldron
	local ladle = Instance.new("Model")
	ladle.Name = "LadleCauldron"
	ladle.Parent = crucible

	local tiltRot = CFrame.Angles(math.rad(22), 0, 0)
	local pot = createPropPart(ladle, "CauldronVessel", Vector3.new(7.2, 7.5, 7.5), CFrame.new(crucPos + Vector3.new(0, 6.5, 0)) * tiltRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 38, 44), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(ladle, "ReinforcementBand", Vector3.new(1.2, 8.2, 8.2), pot.CFrame, Color3.fromRGB(60, 52, 58), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(ladle, "PourSpout", Vector3.new(3.0, 1.8, 2.4), CFrame.new(crucPos + Vector3.new(0, 7.2, 3.4)) * tiltRot, Color3.fromRGB(38, 35, 40), Enum.Material.Metal)

	-- Submodel: MoltenSlagSurface
	local slagSurface = Instance.new("Model")
	slagSurface.Name = "MoltenSlagSurface"
	slagSurface.Parent = crucible

	local moltenPool = createPropPart(slagSurface, "SlagPool", Vector3.new(0.6, 6.4, 6.4), pot.CFrame * CFrame.new(2.8, 0, 0), Color3.fromRGB(255, 115, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
	local slagLight = Instance.new("PointLight")
	slagLight.Color = Color3.fromRGB(255, 120, 25)
	slagLight.Brightness = 0.9
	slagLight.Range = 16
	slagLight.Parent = moltenPool

	-- Submodel: PouringStream (Shower of Molten Sparks)
	local streamGroup = Instance.new("Model")
	streamGroup.Name = "PouringStream"
	streamGroup.Parent = crucible

	local pourStream = createPropPart(streamGroup, "MoltenStream", Vector3.new(1.0, 5.0, 1.0), CFrame.new(crucPos + Vector3.new(0, 3.5, 4.4)) * CFrame.Angles(math.rad(15), 0, 0), Color3.fromRGB(255, 140, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
	
	local moltenSparks = Instance.new("ParticleEmitter")
	moltenSparks.Name = "SlagSparks"
	moltenSparks.Texture = "rbxassetid://258129523"
	moltenSparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 90, 10))
	moltenSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	moltenSparks.Lifetime = NumberRange.new(0.5, 1.0)
	moltenSparks.Rate = 16
	moltenSparks.Speed = NumberRange.new(6, 14)
	moltenSparks.SpreadAngle = Vector2.new(35, 35)
	moltenSparks.EmissionDirection = Enum.NormalId.Bottom
	moltenSparks.Parent = pourStream

	-- 3. Overhead Material Conveyor Truss Span (South Border Perimeter)
	local conveyor = Instance.new("Model")
	conveyor.Name = "OverheadConveyor"
	conveyor.Parent = props

	local convPos = center + Vector3.new(0, 0, 30)

	-- Submodel: SupportPylons
	local pylons = Instance.new("Model")
	pylons.Name = "SupportPylons"
	pylons.Parent = conveyor

	local pylonXOffsets = { -18, 18 }
	for pi, px in ipairs(pylonXOffsets) do
		local pylonModel = Instance.new("Model")
		pylonModel.Name = "PylonTower_" .. pi
		pylonModel.Parent = pylons

		createPropPart(pylonModel, "Footing", Vector3.new(4.2, 1.2, 4.2), CFrame.new(convPos + Vector3.new(px, 0.6, 0)), Color3.fromRGB(44, 46, 52), Enum.Material.Concrete)
		createPropPart(pylonModel, "LegL", Vector3.new(1.4, 18, 1.4), CFrame.new(convPos + Vector3.new(px - 1.4, 9.5, 0)), Color3.fromRGB(185, 90, 30), Enum.Material.DiamondPlate)
		createPropPart(pylonModel, "LegR", Vector3.new(1.4, 18, 1.4), CFrame.new(convPos + Vector3.new(px + 1.4, 9.5, 0)), Color3.fromRGB(185, 90, 30), Enum.Material.DiamondPlate)
		createPropPart(pylonModel, "CrossBrace", Vector3.new(3.8, 1.0, 1.2), CFrame.new(convPos + Vector3.new(px, 12, 0)), Color3.fromRGB(140, 70, 24), Enum.Material.Metal)
	end

	-- Submodel: TrussSpan
	local trussSpan = Instance.new("Model")
	trussSpan.Name = "TrussSpan"
	trussSpan.Parent = conveyor

	createPropPart(trussSpan, "BottomChord", Vector3.new(40, 1.4, 4.2), CFrame.new(convPos + Vector3.new(0, 18, 0)), Color3.fromRGB(180, 85, 25), Enum.Material.DiamondPlate)
	createPropPart(trussSpan, "TopChord", Vector3.new(40, 1.2, 4.2), CFrame.new(convPos + Vector3.new(0, 22, 0)), Color3.fromRGB(180, 85, 25), Enum.Material.Metal)

	-- Submodel: ConveyorBelt
	local beltGroup = Instance.new("Model")
	beltGroup.Name = "ConveyorBelt"
	beltGroup.Parent = conveyor

	createPropPart(beltGroup, "RubberBelt", Vector3.new(39.6, 0.4, 2.8), CFrame.new(convPos + Vector3.new(0, 19, 0)), Color3.fromRGB(24, 25, 28), Enum.Material.SmoothPlastic)
	-- Crushed ore/scrap chunks along belt
	for chunk = 1, 8 do
		createPropPart(beltGroup, "OreChunk_" .. chunk, Vector3.new(1.4, 0.8, 1.4), CFrame.new(convPos + Vector3.new(-16 + ((chunk - 1) * 4.5), 19.5, 0)), Color3.fromRGB(140, 80, 45), Enum.Material.Slate)
	end

	-- 4. Titanium/Tungsten Ingot Pallet Cache (South-East Perimeter)
	local ingotStack = Instance.new("Model")
	ingotStack.Name = "IngotPalletStack"
	ingotStack.Parent = props

	local palletPos = center + Vector3.new(26, 0, 26)

	-- Submodel: HeavySteelPallet
	local steelPallet = Instance.new("Model")
	steelPallet.Name = "HeavySteelPallet"
	steelPallet.Parent = ingotStack

	createPropPart(steelPallet, "PalletPlatform", Vector3.new(8.5, 0.9, 8.5), CFrame.new(palletPos + Vector3.new(0, 0.45, 0)), Color3.fromRGB(48, 52, 60), Enum.Material.DiamondPlate)

	-- Submodel: IngotTiers
	local ingotTiers = Instance.new("Model")
	ingotTiers.Name = "IngotTiers"
	ingotTiers.Parent = ingotStack

	for layer = 1, 3 do
		for bar = 1, 3 do
			local ingotY = 0.9 + ((layer - 0.5) * 0.85)
			local ingotCF = (layer % 2 == 1)
				and CFrame.new(palletPos + Vector3.new(0, ingotY, (bar - 2) * 2.3))
				or CFrame.new(palletPos + Vector3.new((bar - 2) * 2.3, ingotY, 0)) * CFrame.Angles(0, math.rad(90), 0)
			createPropPart(ingotTiers, "Ingot_" .. layer .. "_" .. bar, Vector3.new(7.6, 0.8, 1.9), ingotCF, Color3.fromRGB(210, 215, 225), Enum.Material.Metal)
		end
	end
end

-- Zone 4: Cybernetic Wasteland Props (AI Server Mainframe Banks, Quantum Transmitter Tower, Data Consoles)
function ZoneService.buildZone4Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone4"
	props.Parent = folder

	-- 1. Twin Monolithic Server Mainframe Banks (North Border Flanking Recycler)
	local serverOffsets = {
		{ Off = Vector3.new(-18, 0, -34), Name = "ServerBank_Left" },
		{ Off = Vector3.new(18, 0, -34), Name = "ServerBank_Right" },
	}
	for _, sData in ipairs(serverOffsets) do
		local sModel = Instance.new("Model")
		sModel.Name = sData.Name
		sModel.Parent = props

		local sPos = center + sData.Off

		-- Submodel: CabinetHousing
		local housing = Instance.new("Model")
		housing.Name = "CabinetHousing"
		housing.Parent = sModel

		createPropPart(housing, "PlinthPad", Vector3.new(11.2, 1.0, 5.2), CFrame.new(sPos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(24, 28, 36), Enum.Material.DiamondPlate)
		createPropPart(housing, "ChassisBody", Vector3.new(10.5, 15, 4.6), CFrame.new(sPos + Vector3.new(0, 8.5, 0)), Color3.fromRGB(22, 25, 34), Enum.Material.Metal)
		createPropPart(housing, "TopExhaustCowl", Vector3.new(10.8, 0.8, 4.8), CFrame.new(sPos + Vector3.new(0, 16.4, 0)), Color3.fromRGB(35, 40, 52), Enum.Material.Metal)

		-- Submodel: ServerBladeRacks
		local bladeRacks = Instance.new("Model")
		bladeRacks.Name = "ServerBladeRacks"
		bladeRacks.Parent = sModel

		for row = 1, 5 do
			local bladeY = 2.5 + (row * 2.4)
			local blade = createPropPart(bladeRacks, "ServerBlade_" .. row, Vector3.new(9.2, 1.8, 0.6), CFrame.new(sPos + Vector3.new(0, bladeY, 2.1)), Color3.fromRGB(36, 42, 56), Enum.Material.Metal)
			
			-- Array of Blinking Status LEDs
			local ledA = createPropPart(bladeRacks, "LedA_" .. row, Vector3.new(0.4, 0.4, 0.2), CFrame.new(sPos + Vector3.new(-3.8, bladeY, 2.45)), Color3.fromRGB(35, 235, 195), Enum.Material.Neon)
			local ledB = createPropPart(bladeRacks, "LedB_" .. row, Vector3.new(0.4, 0.4, 0.2), CFrame.new(sPos + Vector3.new(-3.0, bladeY, 2.45)), Color3.fromRGB(45, 215, 95), Enum.Material.Neon)
			local ledC = createPropPart(bladeRacks, "LedC_" .. row, Vector3.new(0.4, 0.4, 0.2), CFrame.new(sPos + Vector3.new(-2.2, bladeY, 2.45)), Color3.fromRGB(255, 185, 35), Enum.Material.Neon)
		end

		-- Submodel: FrontInspectionBay
		local bay = Instance.new("Model")
		bay.Name = "FrontInspectionBay"
		bay.Parent = sModel

		createPropPart(bay, "SmokedGlassDoor", Vector3.new(9.6, 13.5, 0.3), CFrame.new(sPos + Vector3.new(0, 8.5, 2.5)), Color3.fromRGB(35, 200, 185), Enum.Material.Glass)

		-- Submodel: CableRaceways
		local cables = Instance.new("Model")
		cables.Name = "CableRaceways"
		cables.Parent = sModel

		createPropPart(cables, "OverheadTray", Vector3.new(11.5, 0.6, 1.8), CFrame.new(sPos + Vector3.new(0, 17.2, 0)), Color3.fromRGB(45, 52, 68), Enum.Material.DiamondPlate)
		createPropPart(cables, "UmbilicalCableL", Vector3.new(0.8, 16, 0.8), CFrame.new(sPos + Vector3.new(-4.8, 8.5, -2.2)), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		createPropPart(cables, "UmbilicalCableR", Vector3.new(0.8, 16, 0.8), CFrame.new(sPos + Vector3.new(4.8, 8.5, -2.2)), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end

	-- 2. Towering Quantum Transmitter Spire (South Border Perimeter)
	local tower = Instance.new("Model")
	tower.Name = "QuantumTransmitterTower"
	tower.Parent = props

	local towerPos = center + Vector3.new(0, 0, 30)

	-- Submodel: LatticeSpire
	local spire = Instance.new("Model")
	spire.Name = "LatticeSpire"
	spire.Parent = tower

	createPropPart(spire, "HexBasePlinth", Vector3.new(2.0, 9.0, 9.0), CFrame.new(towerPos + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(32, 36, 48), Enum.Material.Concrete, Enum.PartType.Cylinder)
	createPropPart(spire, "LowerTowerMast", Vector3.new(4.5, 16, 4.5), CFrame.new(towerPos + Vector3.new(0, 10, 0)), Color3.fromRGB(42, 50, 66), Enum.Material.DiamondPlate)
	createPropPart(spire, "UpperTowerMast", Vector3.new(2.8, 16, 2.8), CFrame.new(towerPos + Vector3.new(0, 24, 0)), Color3.fromRGB(52, 62, 80), Enum.Material.Metal)

	-- Submodel: ParabolicDishes
	local dishes = Instance.new("Model")
	dishes.Name = "ParabolicDishes"
	dishes.Parent = tower

	local dishL = createPropPart(dishes, "DishLeft", Vector3.new(1.0, 5.5, 5.5), CFrame.new(towerPos + Vector3.new(-3.5, 18, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(200, 210, 225), Enum.Material.Metal, Enum.PartType.Cylinder)
	local dishR = createPropPart(dishes, "DishRight", Vector3.new(1.0, 5.5, 5.5), CFrame.new(towerPos + Vector3.new(3.5, 18, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(200, 210, 225), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Submodel: ToroidalEmitters
	local emitters = Instance.new("Model")
	emitters.Name = "ToroidalEmitters"
	emitters.Parent = tower

	local ringLow = createPropPart(emitters, "ResonatorRingLow", Vector3.new(0.8, 8.2, 8.2), CFrame.new(towerPos + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 220, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
	local ringHigh = createPropPart(emitters, "ResonatorRingHigh", Vector3.new(0.8, 6.0, 6.0), CFrame.new(towerPos + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 220, 200), Enum.Material.Neon, Enum.PartType.Cylinder)

	-- Apex Flashing Beacon
	local beacon = createPropPart(emitters, "ApexStrobe", Vector3.new(1.2, 1.2, 1.2), CFrame.new(towerPos + Vector3.new(0, 33, 0)), Color3.fromRGB(40, 240, 215), Enum.Material.Neon, Enum.PartType.Ball)
	local bLight = Instance.new("PointLight")
	bLight.Color = Color3.fromRGB(40, 240, 215)
	bLight.Brightness = 0.8
	bLight.Range = 22
	bLight.Parent = beacon

	-- 3. Angled Holographic Data Workstations (North-West & North-East Perimeter)
	local consoleOffsets = {
		{ Off = Vector3.new(-26, 0, -24), Name = "DataConsole_West" },
		{ Off = Vector3.new(26, 0, -24), Name = "DataConsole_East" },
	}
	for _, cData in ipairs(consoleOffsets) do
		local cModel = Instance.new("Model")
		cModel.Name = cData.Name
		cModel.Parent = props

		local cPos = center + cData.Off

		-- Submodel: ConsolePedestal
		local ped = Instance.new("Model")
		ped.Name = "ConsolePedestal"
		ped.Parent = cModel

		createPropPart(ped, "Footing", Vector3.new(5.6, 0.8, 4.2), CFrame.new(cPos + Vector3.new(0, 0.4, 0)), Color3.fromRGB(28, 32, 44), Enum.Material.DiamondPlate)
		createPropPart(ped, "RiserPillar", Vector3.new(4.2, 3.2, 3.0), CFrame.new(cPos + Vector3.new(0, 2.4, 0)), Color3.fromRGB(36, 42, 56), Enum.Material.Metal)

		-- Submodel: PhysicalControls
		local ctrls = Instance.new("Model")
		ctrls.Name = "PhysicalControls"
		ctrls.Parent = cModel

		local desk = createPropPart(ctrls, "ControlDesk", Vector3.new(5.2, 0.6, 2.6), CFrame.new(cPos + Vector3.new(0, 4.2, 0.4)) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(24, 28, 38), Enum.Material.Metal)
		createPropPart(ctrls, "KeyDeck", Vector3.new(3.8, 0.2, 1.4), desk.CFrame * CFrame.new(0, 0.35, 0), Color3.fromRGB(35, 200, 185), Enum.Material.Neon)

		-- Submodel: HolographicDisplay
		local holo = Instance.new("Model")
		holo.Name = "HolographicDisplay"
		holo.Parent = cModel

		local screenPart = createPropPart(holo, "HoloScreen", Vector3.new(4.8, 3.0, 0.2), CFrame.new(cPos + Vector3.new(0, 6.2, -0.6)) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(30, 220, 200), Enum.Material.Glass)
		local sLight = Instance.new("PointLight")
		sLight.Color = Color3.fromRGB(35, 225, 205)
		sLight.Brightness = 0.5
		sLight.Range = 8
		sLight.Parent = screenPart
	end
end

-- Zone 5: Orbital Crashsite Props (Fallen Starship Ion Thruster, Warp Core Housing, Armor Bulkhead, Void Crystals)
function ZoneService.buildZone5Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone5"
	props.Parent = folder

	-- 1. Massive Derelict Starship Ion Thruster Bell (North-West Border, 28 deg Impact Tilt)
	local thruster = Instance.new("Model")
	thruster.Name = "StarshipIonThruster"
	thruster.Parent = props

	local thrustPos = center + Vector3.new(-18, 0, -32)
	local thrustRot = CFrame.Angles(math.rad(28), math.rad(15), 0)

	-- Submodel: ImpactCrater
	local crater = Instance.new("Model")
	crater.Name = "ImpactCrater"
	crater.Parent = thruster

	createPropPart(crater, "CraterBerm", Vector3.new(20, 2.0, 20), CFrame.new(thrustPos + Vector3.new(0, 1.0, 0)), Color3.fromRGB(32, 28, 40), Enum.Material.Slate)
	for shard = 1, 4 do
		createPropPart(crater, "HullDebris_" .. shard, Vector3.new(4.5, 0.8, 3.0), CFrame.new(thrustPos + Vector3.new(-7 + (shard * 3.5), 1.5, 6)) * CFrame.Angles(math.rad(18), math.rad(shard * 45), 0), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	end

	-- Submodel: ThrusterNozzleBell
	local nozzle = Instance.new("Model")
	nozzle.Name = "ThrusterNozzleBell"
	nozzle.Parent = thruster

	createPropPart(nozzle, "BellConical", Vector3.new(14, 12, 12), CFrame.new(thrustPos + Vector3.new(0, 7.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(46, 38, 58), Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Multi-segment titanium heat shield rings
	createPropPart(nozzle, "HeatShieldRingA", Vector3.new(1.8, 13.4, 13.4), CFrame.new(thrustPos + Vector3.new(0, 9.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 50, 110), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(nozzle, "HeatShieldRingB", Vector3.new(1.8, 14.2, 14.2), CFrame.new(thrustPos + Vector3.new(0, 11.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(65, 55, 90), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Submodel: MagneticInjectionChamber
	local chamber = Instance.new("Model")
	chamber.Name = "MagneticInjectionChamber"
	chamber.Parent = thruster

	local plasmaCore = createPropPart(chamber, "IonPlasmaCore", Vector3.new(1.2, 9.0, 9.0), CFrame.new(thrustPos + Vector3.new(0, 5.0, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(175, 60, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	
	local plasmaLight = Instance.new("PointLight")
	plasmaLight.Color = Color3.fromRGB(180, 65, 255)
	plasmaLight.Brightness = 0.9
	plasmaLight.Range = 18
	plasmaLight.Parent = plasmaCore

	local plasmaEmitter = Instance.new("ParticleEmitter")
	plasmaEmitter.Name = "IonPlasmaVent"
	plasmaEmitter.Texture = "rbxassetid://258129523"
	plasmaEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 100, 255), Color3.fromRGB(130, 40, 230))
	plasmaEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 2.5),
		NumberSequenceKeypoint.new(1, 4.5),
	})
	plasmaEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	plasmaEmitter.Lifetime = NumberRange.new(1.0, 2.0)
	plasmaEmitter.Rate = 12
	plasmaEmitter.Speed = NumberRange.new(4, 9)
	plasmaEmitter.SpreadAngle = Vector2.new(30, 30)
	plasmaEmitter.EmissionDirection = Enum.NormalId.Top
	plasmaEmitter.Parent = plasmaCore

	-- 2. Warp Drive Antimatter Containment Housing (North-East Border)
	local warpDrive = Instance.new("Model")
	warpDrive.Name = "WarpDriveContainment"
	warpDrive.Parent = props

	local warpPos = center + Vector3.new(18, 0, -32)

	-- Submodel: BasePlinth
	local wBase = Instance.new("Model")
	wBase.Name = "BasePlinth"
	wBase.Parent = warpDrive

	createPropPart(wBase, "OctagonPlinth", Vector3.new(9.5, 1.8, 9.5), CFrame.new(warpPos + Vector3.new(0, 0.9, 0)), Color3.fromRGB(36, 30, 46), Enum.Material.DiamondPlate)
	createPropPart(wBase, "CircuitRing", Vector3.new(0.4, 7.8, 7.8), CFrame.new(warpPos + Vector3.new(0, 1.85, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(165, 55, 245), Enum.Material.Neon, Enum.PartType.Cylinder)

	-- Submodel: MagneticPylons
	local pylons = Instance.new("Model")
	pylons.Name = "MagneticPylons"
	pylons.Parent = warpDrive

	local pylonOffsets = {
		Vector3.new(-3.5, 0, -3.5),
		Vector3.new(3.5, 0, -3.5),
		Vector3.new(-3.5, 0, 3.5),
		Vector3.new(3.5, 0, 3.5),
	}
	for pi, po in ipairs(pylonOffsets) do
		createPropPart(pylons, "Pylon_" .. pi, Vector3.new(1.6, 9.5, 1.6), CFrame.new(warpPos + po + Vector3.new(0, 5.8, 0)), Color3.fromRGB(58, 48, 74), Enum.Material.Metal)
		createPropPart(pylons, "FluxEmitter_" .. pi, Vector3.new(1.8, 1.4, 1.8), CFrame.new(warpPos + po + Vector3.new(0, 9.5, 0)), Color3.fromRGB(175, 60, 255), Enum.Material.Neon)
	end
	createPropPart(pylons, "TopContainmentCap", Vector3.new(9.5, 1.6, 9.5), CFrame.new(warpPos + Vector3.new(0, 11, 0)), Color3.fromRGB(36, 30, 46), Enum.Material.Metal)

	-- Submodel: AntimatterSingularity
	local singularity = Instance.new("Model")
	singularity.Name = "AntimatterSingularity"
	singularity.Parent = warpDrive

	local coreSphere = createPropPart(singularity, "SingularityCore", Vector3.new(4.2, 4.2, 4.2), CFrame.new(warpPos + Vector3.new(0, 6.2, 0)), Color3.fromRGB(185, 70, 255), Enum.Material.Neon, Enum.PartType.Ball)
	local singLight = Instance.new("PointLight")
	singLight.Color = Color3.fromRGB(185, 70, 255)
	singLight.Brightness = 0.9
	singLight.Range = 14
	singLight.Parent = coreSphere

	-- Dual Counter-Rotating Magnetic Rings
	createPropPart(singularity, "OrbitRingA", Vector3.new(0.5, 6.2, 6.2), CFrame.new(warpPos + Vector3.new(0, 6.2, 0)) * CFrame.Angles(math.rad(35), 0, math.rad(45)), Color3.fromRGB(210, 110, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	createPropPart(singularity, "OrbitRingB", Vector3.new(0.5, 6.2, 6.2), CFrame.new(warpPos + Vector3.new(0, 6.2, 0)) * CFrame.Angles(math.rad(-35), 0, math.rad(-45)), Color3.fromRGB(210, 110, 255), Enum.Material.Neon, Enum.PartType.Cylinder)

	-- 3. Fractured Dreadnought Hull Armor Bulkhead (South Border Perimeter)
	local armorSlab = Instance.new("Model")
	armorSlab.Name = "DreadnoughtArmorSlab"
	armorSlab.Parent = props

	local slabPos = center + Vector3.new(0, 0, 30)
	local slabRot = CFrame.Angles(math.rad(-20), 0, math.rad(5))

	-- Submodel: CompositeArmorHull
	local hullGroup = Instance.new("Model")
	hullGroup.Name = "CompositeArmorHull"
	hullGroup.Parent = armorSlab

	createPropPart(hullGroup, "OuterArmorSlab", Vector3.new(30, 8.5, 2.6), CFrame.new(slabPos + Vector3.new(0, 4.2, 0)) * slabRot, Color3.fromRGB(45, 38, 56), Enum.Material.Metal)
	createPropPart(hullGroup, "StructuralSpineRib", Vector3.new(30.4, 1.8, 3.4), CFrame.new(slabPos + Vector3.new(0, 6.5, 0)) * slabRot, Color3.fromRGB(68, 56, 84), Enum.Material.DiamondPlate)

	-- Submodel: InternalHoneycombRibs (Exposed fracture edge)
	local ribs = Instance.new("Model")
	ribs.Name = "InternalHoneycombRibs"
	ribs.Parent = armorSlab

	for rib = 1, 6 do
		createPropPart(ribs, "HoneycombRib_" .. rib, Vector3.new(1.2, 6.5, 2.2), CFrame.new(slabPos + Vector3.new(-12 + ((rib - 1) * 4.8), 4.2, 0.4)) * slabRot, Color3.fromRGB(150, 110, 185), Enum.Material.Metal)
	end

	-- 4. Alien Void Crystal Resonant Formations (North-West & South-East Perimeter)
	local crystalClusters = {
		{ Off = Vector3.new(-26, 0, -24), Name = "AlienVoidCrystals_NorthWest" },
		{ Off = Vector3.new(26, 0, 26), Name = "AlienVoidCrystals_SouthEast" },
	}
	for _, crData in ipairs(crystalClusters) do
		local cModel = Instance.new("Model")
		cModel.Name = crData.Name
		cModel.Parent = props

		local crPos = center + crData.Off

		-- Submodel: ImpactFissures
		local fiss = Instance.new("Model")
		fiss.Name = "ImpactFissures"
		fiss.Parent = cModel

		createPropPart(fiss, "CrackedGround", Vector3.new(8.5, 0.6, 8.5), CFrame.new(crPos + Vector3.new(0, 0.3, 0)), Color3.fromRGB(34, 28, 42), Enum.Material.Slate)
		createPropPart(fiss, "FissureGlow", Vector3.new(7.0, 0.7, 1.2), CFrame.new(crPos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, math.rad(35), 0), Color3.fromRGB(160, 50, 240), Enum.Material.Neon)

		-- Submodel: ResonantSpires
		local spires = Instance.new("Model")
		spires.Name = "ResonantSpires"
		spires.Parent = cModel

		local largeSpike = createPropPart(spires, "CrystalSpike_Large", Vector3.new(2.2, 9.5, 2.2), CFrame.new(crPos + Vector3.new(0, 4.2, 0)) * CFrame.Angles(math.rad(15), 0, math.rad(-10)), Color3.fromRGB(165, 50, 245), Enum.Material.Glass)
		createPropPart(spires, "CrystalSpike_Medium", Vector3.new(1.6, 6.5, 1.6), CFrame.new(crPos + Vector3.new(2.4, 3.0, 1.2)) * CFrame.Angles(math.rad(-14), math.rad(25), math.rad(16)), Color3.fromRGB(185, 75, 255), Enum.Material.Glass)
		createPropPart(spires, "CrystalSpike_Small", Vector3.new(1.3, 4.5, 1.3), CFrame.new(crPos + Vector3.new(-2.2, 2.0, -1.2)) * CFrame.Angles(math.rad(10), math.rad(-30), math.rad(-15)), Color3.fromRGB(145, 45, 225), Enum.Material.Glass)

		-- Ambient Rising Void Sparkles
		local voidSparkles = Instance.new("ParticleEmitter")
		voidSparkles.Name = "VoidDust"
		voidSparkles.Texture = "rbxassetid://258129523"
		voidSparkles.Color = ColorSequence.new(Color3.fromRGB(220, 120, 255), Color3.fromRGB(140, 50, 230))
		voidSparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		voidSparkles.Lifetime = NumberRange.new(1.5, 3.0)
		voidSparkles.Rate = 6
		voidSparkles.Speed = NumberRange.new(1, 3)
		voidSparkles.SpreadAngle = Vector2.new(45, 45)
		voidSparkles.EmissionDirection = Enum.NormalId.Top
		voidSparkles.Parent = largeSpike

		local crLight = Instance.new("PointLight")
		crLight.Color = Color3.fromRGB(175, 60, 255)
		crLight.Brightness = 0.6
		crLight.Range = 12
		crLight.Parent = largeSpike
	end
end

-- Helper to construct an Industrial High-Definition Sci-Fi Gantry Billboard for a zone
function ZoneService.constructZoneSign(parent: Instance, centerPos: Vector3, zone: Types.ZoneConfig): Model
	local model = Instance.new("Model")
	model.Name = "SignGantry_Zone" .. tostring(zone.Id)

	local signPos = centerPos + Vector3.new(0, 21, -50)
	local signWidth = 28
	local signHeight = 8.5
	local signDepth = 1.6

	-- 1. Dual Heavy Structural Support Columns (Left & Right I-Beams grounded on concrete footings)
	local pillarsModel = Instance.new("Model")
	pillarsModel.Name = "SupportPillars"
	pillarsModel.Parent = model

	local colXOffsets = { -15, 15 }
	for _, colX in ipairs(colXOffsets) do
		local pillarAssembly = Instance.new("Model")
		pillarAssembly.Name = colX < 0 and "Pillar_Left" or "Pillar_Right"
		pillarAssembly.Parent = pillarsModel

		local footing = Instance.new("Part")
		footing.Name = "Footing"
		footing.Size = Vector3.new(3.6, 1.2, 3.6)
		footing.Position = centerPos + Vector3.new(colX, 0.6, -50)
		footing.Anchored = true
		footing.Material = Enum.Material.Concrete
		footing.Color = Color3.fromRGB(45, 48, 55)
		footing.Parent = pillarAssembly

		local col = Instance.new("Part")
		col.Name = "TrussColumn"
		col.Size = Vector3.new(2.0, 25, 2.0)
		col.Position = centerPos + Vector3.new(colX, 12.5, -50)
		col.Anchored = true
		col.Material = Enum.Material.Metal
		col.Color = Color3.fromRGB(32, 35, 44)
		col.Parent = pillarAssembly

		-- Diagonal Support Strut
		local strut = Instance.new("Part")
		strut.Name = "DiagonalStrut"
		strut.Size = Vector3.new(1.0, 10, 1.0)
		local strutSign = colX > 0 and -1 or 1
		strut.Position = centerPos + Vector3.new(colX + strutSign * 3.5, 18, -50.2)
		strut.Orientation = Vector3.new(0, 0, strutSign * 35)
		strut.Anchored = true
		strut.Material = Enum.Material.Metal
		strut.Color = Color3.fromRGB(38, 42, 52)
		strut.Parent = pillarAssembly
	end

	-- 2. Display Frame (Truss Backing + Main Board + Bezels)
	local displayFrame = Instance.new("Model")
	displayFrame.Name = "DisplayFrame"
	displayFrame.Parent = model

	local trussBack = Instance.new("Part")
	trussBack.Name = "TrussBacking"
	trussBack.Size = Vector3.new(signWidth + 4, 2.2, 1.2)
	trussBack.Position = signPos + Vector3.new(0, 0, -1.2)
	trussBack.Anchored = true
	trussBack.Material = Enum.Material.DiamondPlate
	trussBack.Color = Color3.fromRGB(28, 30, 38)
	trussBack.Parent = displayFrame

	local board = Instance.new("Part")
	board.Name = "BillboardBoard"
	board.Size = Vector3.new(signWidth, signHeight, signDepth)
	board.Position = signPos
	board.Anchored = true
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(15, 17, 24)
	board.Parent = displayFrame

	-- Top & Bottom Beveled Metal Bezel Trim
	local trimTop = Instance.new("Part")
	trimTop.Name = "BezelTop"
	trimTop.Size = Vector3.new(signWidth + 0.6, 0.6, signDepth + 0.4)
	trimTop.Position = signPos + Vector3.new(0, (signHeight / 2) + 0.3, 0)
	trimTop.Anchored = true
	trimTop.Material = Enum.Material.SmoothPlastic
	trimTop.Color = zone.Color
	trimTop.Parent = displayFrame

	local trimBottom = trimTop:Clone()
	trimBottom.Name = "BezelBottom"
	trimBottom.Position = signPos + Vector3.new(0, -(signHeight / 2) - 0.3, 0)
	trimBottom.Parent = displayFrame

	-- 3. Overhead Industrial Down-Lamps
	local lightingModel = Instance.new("Model")
	lightingModel.Name = "OverheadLighting"
	lightingModel.Parent = model

	local lampOffsets = { -8, 8 }
	for _, lx in ipairs(lampOffsets) do
		local lampGroup = Instance.new("Model")
		lampGroup.Name = lx < 0 and "Lamp_Left" or "Lamp_Right"
		lampGroup.Parent = lightingModel

		local lampArm = Instance.new("Part")
		lampArm.Name = "LampArm"
		lampArm.Size = Vector3.new(0.6, 0.6, 2.8)
		lampArm.Position = signPos + Vector3.new(lx, (signHeight / 2) + 0.8, 1.2)
		lampArm.Anchored = true
		lampArm.Material = Enum.Material.Metal
		lampArm.Color = Color3.fromRGB(40, 42, 50)
		lampArm.Parent = lampGroup

		local lampHead = Instance.new("Part")
		lampHead.Name = "LampHead"
		lampHead.Size = Vector3.new(1.8, 0.8, 1.2)
		lampHead.Position = signPos + Vector3.new(lx, (signHeight / 2) + 0.5, 2.4)
		lampHead.Anchored = true
		lampHead.Material = Enum.Material.SmoothPlastic
		lampHead.Color = Color3.fromRGB(240, 235, 210)
		lampHead.Parent = lampGroup

		local spot = Instance.new("PointLight")
		spot.Color = Color3.fromRGB(255, 245, 220)
		spot.Brightness = 0.35
		spot.Range = 12
		spot.Parent = lampHead
	end

	-- 5. High-Definition Sci-Fi SurfaceGui (Front & Back Face)
	local function createDisplayFace(normal: Enum.NormalId)
		local sgui = Instance.new("SurfaceGui")
		sgui.Name = "DisplayGui_" .. normal.Name
		sgui.Face = normal
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 40
		sgui.AlwaysOnTop = false
		sgui.LightInfluence = 0.2
		sgui.Parent = board

		local rootFrame = Instance.new("Frame")
		rootFrame.Size = UDim2.new(1, 0, 1, 0)
		rootFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
		rootFrame.BorderSizePixel = 0
		rootFrame.Parent = sgui

		local bgStroke = Instance.new("UIStroke")
		bgStroke.Color = Color3.fromRGB(45, 52, 68)
		bgStroke.Thickness = 2
		bgStroke.Parent = rootFrame

		-- Top Header Strip: Sector Pill Tag & Multiplier
		local headerBar = Instance.new("Frame")
		headerBar.Size = UDim2.new(1, -40, 0, 42)
		headerBar.Position = UDim2.new(0, 20, 0, 16)
		headerBar.BackgroundTransparency = 1
		headerBar.Parent = rootFrame

		local sectorTag = Instance.new("Frame")
		sectorTag.Size = UDim2.new(0, 260, 1, 0)
		sectorTag.Position = UDim2.new(0, 0, 0, 0)
		sectorTag.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
		sectorTag.Parent = headerBar

		local stCorner = Instance.new("UICorner")
		stCorner.CornerRadius = UDim.new(0, 8)
		stCorner.Parent = sectorTag

		local stStroke = Instance.new("UIStroke")
		stStroke.Color = zone.Color
		stStroke.Thickness = 1.5
		stStroke.Parent = sectorTag

		local stText = Instance.new("TextLabel")
		stText.Size = UDim2.new(1, 0, 1, 0)
		stText.BackgroundTransparency = 1
		stText.Font = Enum.Font.GothamBlack
		stText.TextSize = 16
		stText.TextColor3 = zone.Color
		stText.Text = string.format("SECTOR 0%d // DEPLOYMENT", zone.Id)
		stText.Parent = sectorTag

		local multTag = Instance.new("Frame")
		multTag.Size = UDim2.new(0, 220, 1, 0)
		multTag.Position = UDim2.new(1, -220, 0, 0)
		multTag.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
		multTag.Parent = headerBar

		local mtCorner = Instance.new("UICorner")
		mtCorner.CornerRadius = UDim.new(0, 8)
		mtCorner.Parent = multTag

		local mtStroke = Instance.new("UIStroke")
		mtStroke.Color = Color3.fromRGB(255, 200, 50)
		mtStroke.Thickness = 1.5
		mtStroke.Parent = multTag

		local mtText = Instance.new("TextLabel")
		mtText.Size = UDim2.new(1, 0, 1, 0)
		mtText.BackgroundTransparency = 1
		mtText.Font = Enum.Font.GothamBlack
		mtText.TextSize = 16
		mtText.TextColor3 = Color3.fromRGB(255, 200, 50)
		mtText.Text = string.format("%dx SCRAP MULTIPLIER", zone.BaseYield)
		mtText.Parent = multTag

		-- Main Zone Title
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -40, 0, 80)
		title.Position = UDim2.new(0, 20, 0, 68)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 44
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Text = zone.Name:upper()
		title.Parent = rootFrame

		local tStroke = Instance.new("UIStroke")
		tStroke.Color = zone.Color
		tStroke.Thickness = 2
		tStroke.Parent = title

		-- Glowing Divider Line
		local divider = Instance.new("Frame")
		divider.Size = UDim2.new(1, -120, 0, 3)
		divider.Position = UDim2.new(0, 60, 0, 155)
		divider.BackgroundColor3 = zone.Color
		divider.BorderSizePixel = 0
		divider.Parent = rootFrame

		-- Badges Row
		local badges = Instance.new("Frame")
		badges.Size = UDim2.new(1, -40, 0, 36)
		badges.Position = UDim2.new(0, 20, 0, 168)
		badges.BackgroundTransparency = 1
		badges.Parent = rootFrame

		local badgeList = Instance.new("UIListLayout")
		badgeList.FillDirection = Enum.FillDirection.Horizontal
		badgeList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		badgeList.Padding = UDim.new(0, 16)
		badgeList.Parent = badges

		local badgeData = {
			string.format("TRANSIT: ZONE %d", zone.Id),
			string.format("BASE VALUE: +%d", zone.BaseYield),
			string.format("HAZARD TIER: %d", zone.Id),
		}
		for _, bText in ipairs(badgeData) do
			local bg = Instance.new("Frame")
			bg.Size = UDim2.new(0, 210, 1, 0)
			bg.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
			bg.Parent = badges

			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = bg

			local s = Instance.new("UIStroke")
			s.Color = Color3.fromRGB(55, 65, 85)
			s.Thickness = 1
			s.Parent = bg

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 13
			lbl.TextColor3 = Color3.fromRGB(200, 215, 235)
			lbl.Text = bText
			lbl.Parent = bg
		end

		-- Zone Description / Lore Quote
		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -60, 0, 50)
		desc.Position = UDim2.new(0, 30, 0, 212)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 15
		desc.TextColor3 = Color3.fromRGB(160, 175, 195)
		desc.TextWrapped = true
		desc.Text = string.format("“%s”", zone.Description)
		desc.Parent = rootFrame
	end

	createDisplayFace(Enum.NormalId.Front)
	createDisplayFace(Enum.NormalId.Back)

	model.Parent = parent
	return model
end

-- 4. Construct Progressive Zones (Zones 2 to 5) with seamless wide bridges and guardrails
function ZoneService.constructZonePlatform(zone: Types.ZoneConfig, centerPos: Vector3)
	local folder = Workspace:FindFirstChild("Zone_" .. tostring(zone.Id)) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Zone_" .. tostring(zone.Id)
		folder.Parent = Workspace
	end

	for _, c in ipairs(folder:GetChildren()) do
		c:Destroy()
	end

	-- 1. Oval Scrapyard Ground Foundation & Patchwork Floor
	buildScrapyardGround(folder, centerPos, zone)

	-- 2. Stereotypical Junkyard Corrugated Perimeter Fence with Entry and Exit Gateways
	local enterDir = (ZONE_CENTERS[zone.Id - 1] - centerPos).Unit
	local enterAngle = math.atan2(enterDir.Z, enterDir.X)

	local exitAngle = nil
	if zone.Id < #Config.Zones then
		local exitDir = (ZONE_CENTERS[zone.Id + 1] - centerPos).Unit
		exitAngle = math.atan2(exitDir.Z, exitDir.X)
	end

	buildScrapyardPerimeter(folder, centerPos, zone, enterAngle, exitAngle)

	-- 3. Towering High-Definition Sci-Fi Gantry Billboard for this zone
	ZoneService.constructZoneSign(folder, centerPos, zone)

	-- 4. Scrap Recycler Machine & Deposit Sell Pad on North perimeter (Ample clearance from fence)
	ZoneService.constructRecycler(folder, centerPos + Vector3.new(0, 0, -38), zone.Id)

	-- 5. 8 Scrap Nodes per zone - Generously distributed radially across the compound (clear of corridors)
	local offsets = {
		Vector3.new(38, 0, -18),
		Vector3.new(22, 0, -40),
		Vector3.new(-22, 0, -40),
		Vector3.new(-38, 0, -18),
		Vector3.new(-38, 0, 18),
		Vector3.new(-14, 0, 42),
		Vector3.new(14, 0, 42),
		Vector3.new(38, 0, 18),
	}

	for i, offset in ipairs(offsets) do
		local pile = ZoneService.createScrapPile(zone, centerPos + offset, i)
		pile.Parent = folder
		table.insert(activeNodes, pile)
	end

	-- 6. Fast Travel Portal on this platform (along South-West perimeter)
	createPortalPad(folder, centerPos + Vector3.new(-28, 0, 38), zone.Id)

	-- 7. Dedicated Zone Egg Pod along South-East perimeter
	local zoneEggTypeMap = {
		[2] = "JunkyardEgg",
		[3] = "FoundryEgg",
		[4] = "CyberEgg",
		[5] = "VoidEgg",
	}
	local eggTypeForZone = zoneEggTypeMap[zone.Id]
	if eggTypeForZone then
		ZoneService.constructEggPod(folder, centerPos + Vector3.new(28, 0.4, 38), eggTypeForZone)
	end

	-- 8. Thematic Environmental Sci-Fi Props for Zones 2 to 5
	if zone.Id == 2 then
		ZoneService.buildZone2Props(folder, centerPos)
	elseif zone.Id == 3 then
		ZoneService.buildZone3Props(folder, centerPos)
	elseif zone.Id == 4 then
		ZoneService.buildZone4Props(folder, centerPos)
	elseif zone.Id == 5 then
		ZoneService.buildZone5Props(folder, centerPos)
	end

	-- 9. Floating Island Underside Rock Root & Anti-Gravity Thruster Units
	EnvironmentService.constructIslandUnderside(folder, centerPos, zone.Id, zone.Color)
	EnvironmentService.constructSurfaceDressing(folder, centerPos, zone)
end

-- ============================================================================
-- 5. CREATIVE SPLIT-PATH BRIDGES & FORCEFIELD GATES
-- ============================================================================

-- Helper to create a single bridge deck segment with guardrails, neon trim, anti-jump walls, and underside girders
local function buildBridgeSegment(
	parent: Instance,
	startPos: Vector3,
	endPos: Vector3,
	width: number,
	accentColor: Color3,
	zoneId: number,
	mat: Enum.Material?,
	color: Color3?
)
	local disp = endPos - startPos
	local length = disp.Magnitude
	if length < 0.5 then return end

	local midPoint = (startPos + endPos) / 2
	local bridgeCF = CFrame.lookAt(midPoint, endPos) * CFrame.Angles(0, math.rad(90), 0)

	local segmentModel = Instance.new("Model")
	segmentModel.Name = "BridgeSegment"
	segmentModel.Parent = parent

	-- Walkable Deck
	local deckGroup = Instance.new("Model")
	deckGroup.Name = "Walkway"
	deckGroup.Parent = segmentModel

	local deck = Instance.new("Part")
	deck.Name = "BridgeDeck"
	deck.Size = Vector3.new(length, 3, width)
	deck.CFrame = bridgeCF * CFrame.new(0, -1.5, 0)
	deck.Anchored = true
	deck.Material = mat or Enum.Material.DiamondPlate
	deck.Color = color or Color3.fromRGB(68, 74, 88)
	deck.Parent = deckGroup

	-- Left Guardrail Assembly
	local leftRailGroup = Instance.new("Model")
	leftRailGroup.Name = "LeftGuardrail"
	leftRailGroup.Parent = segmentModel

	local railL = Instance.new("Part")
	railL.Name = "GuardrailL"
	railL.Size = Vector3.new(length, 3.5, 1.2)
	railL.CFrame = bridgeCF * CFrame.new(0, 1.75, -(width / 2) + 0.6)
	railL.Anchored = true
	railL.Material = Enum.Material.Metal
	railL.Color = Color3.fromRGB(28, 30, 38)
	railL.Parent = leftRailGroup

	local neonL = Instance.new("Part")
	neonL.Name = "NeonTrimL"
	neonL.Size = Vector3.new(length, 0.4, 0.4)
	neonL.CFrame = bridgeCF * CFrame.new(0, 3.5, -(width / 2) + 0.6)
	neonL.Anchored = true
	neonL.Material = Enum.Material.SmoothPlastic
	neonL.Color = accentColor
	neonL.Parent = leftRailGroup

	local antiJumpL = Instance.new("Part")
	antiJumpL.Name = "AntiJumpL"
	antiJumpL.Size = Vector3.new(length, 28, 0.6)
	antiJumpL.CFrame = bridgeCF * CFrame.new(0, 14, -(width / 2) + 0.6)
	antiJumpL.Anchored = true
	antiJumpL.CanCollide = true
	antiJumpL.Material = Enum.Material.Glass
	antiJumpL.Color = Color3.fromRGB(180, 200, 220)
	antiJumpL.Transparency = 0.88
	antiJumpL.CastShadow = false
	antiJumpL.Parent = leftRailGroup

	-- Right Guardrail Assembly
	local rightRailGroup = Instance.new("Model")
	rightRailGroup.Name = "RightGuardrail"
	rightRailGroup.Parent = segmentModel

	local railR = Instance.new("Part")
	railR.Name = "GuardrailR"
	railR.Size = Vector3.new(length, 3.5, 1.2)
	railR.CFrame = bridgeCF * CFrame.new(0, 1.75, (width / 2) - 0.6)
	railR.Anchored = true
	railR.Material = Enum.Material.Metal
	railR.Color = Color3.fromRGB(28, 30, 38)
	railR.Parent = rightRailGroup

	local neonR = Instance.new("Part")
	neonR.Name = "NeonTrimR"
	neonR.Size = Vector3.new(length, 0.4, 0.4)
	neonR.CFrame = bridgeCF * CFrame.new(0, 3.5, (width / 2) - 0.6)
	neonR.Anchored = true
	neonR.Material = Enum.Material.SmoothPlastic
	neonR.Color = accentColor
	neonR.Parent = rightRailGroup

	local antiJumpR = Instance.new("Part")
	antiJumpR.Name = "AntiJumpR"
	antiJumpR.Size = Vector3.new(length, 28, 0.6)
	antiJumpR.CFrame = bridgeCF * CFrame.new(0, 14, (width / 2) - 0.6)
	antiJumpR.Anchored = true
	antiJumpR.CanCollide = true
	antiJumpR.Material = Enum.Material.Glass
	antiJumpR.Color = Color3.fromRGB(180, 200, 220)
	antiJumpR.Transparency = 0.88
	antiJumpR.CastShadow = false
	antiJumpR.Parent = rightRailGroup

	-- Underside Box Girders & Cross Trusses
	EnvironmentService.constructBridgeUnderside(segmentModel, bridgeCF, length, width, zoneId)
end

-- Helper to create a floating midway landmark platform
local function buildMidwayIsland(parent: Instance, pos: Vector3, size: Vector3, color: Color3, zoneId: number): Model
	local midwayModel = Instance.new("Model")
	midwayModel.Name = "MidwayIsland_Zone" .. tostring(zoneId)
	midwayModel.Parent = parent

	local island = Instance.new("Part")
	island.Name = "Platform"
	island.Shape = Enum.PartType.Cylinder
	island.Size = Vector3.new(size.Y, size.X, size.X)
	island.CFrame = CFrame.new(pos - Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	island.Anchored = true
	island.Material = Enum.Material.DiamondPlate
	island.Color = color
	island.Parent = midwayModel

	-- Perimeter safety curb
	local ring = Instance.new("Part")
	ring.Name = "MidwayCurb"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.8, size.X + 0.6, size.X + 0.6)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Config.Zones[zoneId] and Config.Zones[zoneId].Color or Color3.fromRGB(80, 140, 200)
	ring.Parent = midwayModel

	return midwayModel
end

-- Helper to construct an authoritative Forcefield Gate with signage, prompt, and collision barriers
local function buildZoneGate(
	bridgeFolder: Instance,
	gatePos: Vector3,
	approachDir: Vector3,
	bridgeWidth: number,
	targetZone: Types.ZoneConfig
): Model
	local gateModel = Instance.new("Model")
	gateModel.Name = "Gate_Zone" .. tostring(targetZone.Id)

	local gateCF = CFrame.lookAt(gatePos, gatePos + approachDir)

	-- 1. Support Pillars
	local pillarsGroup = Instance.new("Model")
	pillarsGroup.Name = "Pillars"
	pillarsGroup.Parent = gateModel

	local pL = Instance.new("Part")
	pL.Name = "GatePillarL"
	pL.Size = Vector3.new(3, 16, 3)
	pL.CFrame = gateCF * CFrame.new(-bridgeWidth / 2 + 1.5, 8, 0)
	pL.Anchored = true
	pL.Color = Color3.fromRGB(25, 28, 38)
	pL.Material = Enum.Material.Metal
	pL.Parent = pillarsGroup

	local pR = Instance.new("Part")
	pR.Name = "GatePillarR"
	pR.Size = Vector3.new(3, 16, 3)
	pR.CFrame = gateCF * CFrame.new(bridgeWidth / 2 - 1.5, 8, 0)
	pR.Anchored = true
	pR.Color = Color3.fromRGB(25, 28, 38)
	pR.Material = Enum.Material.Metal
	pR.Parent = pillarsGroup

	-- 2. Overhead Arch Structure
	local archGroup = Instance.new("Model")
	archGroup.Name = "OverheadArch"
	archGroup.Parent = gateModel

	local top = Instance.new("Part")
	top.Name = "GateTop"
	top.Size = Vector3.new(bridgeWidth + 1, 3, 3)
	top.CFrame = gateCF * CFrame.new(0, 16, 0)
	top.Anchored = true
	top.Color = Color3.fromRGB(25, 28, 38)
	top.Material = Enum.Material.Metal
	top.Parent = archGroup

	local archSign = Instance.new("Part")
	archSign.Name = "GatewaySign"
	archSign.Size = Vector3.new(bridgeWidth - 4, 3.2, 1.8)
	archSign.CFrame = gateCF * CFrame.new(0, 18.6, 0)
	archSign.Anchored = true
	archSign.Material = Enum.Material.SmoothPlastic
	archSign.Color = Color3.fromRGB(16, 18, 26)
	archSign.Parent = archGroup

	local archTrim = Instance.new("Part")
	archTrim.Name = "GatewayTrim"
	archTrim.Size = Vector3.new(bridgeWidth - 3.6, 0.4, 2.0)
	archTrim.CFrame = gateCF * CFrame.new(0, 20.3, 0)
	archTrim.Anchored = true
	archTrim.Material = Enum.Material.SmoothPlastic
	archTrim.Color = targetZone.Color
	archTrim.Parent = archGroup

	-- Sign facing approaching players (Back face of the sign)
	local asgui = Instance.new("SurfaceGui")
	asgui.Face = Enum.NormalId.Back
	asgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	asgui.PixelsPerStud = 35
	asgui.LightInfluence = 0.2
	asgui.Parent = archSign

	local asBox = Instance.new("Frame")
	asBox.Size = UDim2.new(1, 0, 1, 0)
	asBox.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
	asBox.BorderSizePixel = 0
	asBox.Parent = asgui

	local asStroke = Instance.new("UIStroke")
	asStroke.Color = targetZone.Color
	asStroke.Thickness = 2
	asStroke.Parent = asBox

	local asTitle = Instance.new("TextLabel")
	asTitle.Size = UDim2.new(1, 0, 1, 0)
	asTitle.BackgroundTransparency = 1
	asTitle.Font = Enum.Font.GothamBlack
	asTitle.TextSize = 20
	asTitle.TextColor3 = Color3.new(1, 1, 1)
	asTitle.Text = string.format("ZONE %d // %s", targetZone.Id, targetZone.Name:upper())
	asTitle.Parent = asBox

	local asTStroke = Instance.new("UIStroke")
	asTStroke.Color = targetZone.Color
	asTStroke.Thickness = 1.5
	asTStroke.Parent = asTitle

	-- 3. Forcefield Barriers
	local barrierGroup = Instance.new("Model")
	barrierGroup.Name = "Forcefields"
	barrierGroup.Parent = gateModel

	local barrier = Instance.new("Part")
	barrier.Name = "Forcefield"
	barrier.Size = Vector3.new(bridgeWidth + 2, 26, 2.5)
	barrier.CFrame = gateCF * CFrame.new(0, 13, 0)
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.Transparency = 0.35
	barrier.Material = Enum.Material.ForceField
	barrier.Color = targetZone.Color
	barrier.Parent = barrierGroup

	local perimeterBarrier = Instance.new("Part")
	perimeterBarrier.Name = "PerimeterForcefield"
	perimeterBarrier.Size = Vector3.new(bridgeWidth + 4, 26, 2.5)
	perimeterBarrier.CFrame = gateCF * CFrame.new(0, 13, 0)
	perimeterBarrier.Anchored = true
	perimeterBarrier.CanCollide = true
	perimeterBarrier.Transparency = 0.95
	perimeterBarrier.Material = Enum.Material.ForceField
	perimeterBarrier.Color = targetZone.Color
	perimeterBarrier.CastShadow = false
	perimeterBarrier.Parent = barrierGroup

	-- 4. Interactive Unlock Prompt
	local interactGroup = Instance.new("Model")
	interactGroup.Name = "Interactable"
	interactGroup.Parent = gateModel

	local promptPart = Instance.new("Part")
	promptPart.Name = "UnlockPromptPart"
	promptPart.Size = Vector3.new(4, 4, 4)
	promptPart.Position = gatePos - approachDir * 4 + Vector3.new(0, 3, 0)
	promptPart.Anchored = true
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.Parent = interactGroup

	local formattedUnlock = tostring(math.floor(targetZone.UnlockCost))
	while true do
		local k
		formattedUnlock, k = string.gsub(formattedUnlock, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = targetZone.Name
	prompt.ActionText = string.format("Unlock Zone (%s Scrap)", formattedUnlock)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player)
		ZoneService.unlockZone(player, targetZone.Id)
	end)

	gateModel.Parent = bridgeFolder
	zoneGates[targetZone.Id] = {
		Model = gateModel,
		Barrier = barrier,
		Prompt = prompt,
	}

	return gateModel
end

-- 5. Construct Seamless Connecting Bridges with Creative Split Paths and Midway Landmarks
function ZoneService.constructBridge(zoneId: number)
	local fromCenter = ZONE_CENTERS[zoneId - 1]
	local toCenter = ZONE_CENTERS[zoneId]
	local targetZone = Config.Zones[zoneId]
	if not fromCenter or not toCenter or not targetZone then return end

	local bridgeFolder = Workspace:FindFirstChild("Bridges") :: Folder
	if not bridgeFolder then
		bridgeFolder = Instance.new("Folder")
		bridgeFolder.Name = "Bridges"
		bridgeFolder.Parent = Workspace
	end

	-- Clear old bridge & gate for this zone transition
	local oldBridge = bridgeFolder:FindFirstChild(string.format("Bridge_%d_to_%d", zoneId - 1, zoneId))
	if oldBridge then oldBridge:Destroy() end
	local oldGate = bridgeFolder:FindFirstChild("Gate_Zone" .. tostring(zoneId))
	if oldGate then oldGate:Destroy() end

	local bridgeContainer = Instance.new("Model")
	bridgeContainer.Name = string.format("Bridge_%d_to_%d", zoneId - 1, zoneId)
	bridgeContainer.Parent = bridgeFolder

	local mainDir = (toCenter - fromCenter).Unit
	local lateralNorm = Vector3.new(-mainDir.Z, 0, mainDir.X).Unit

	local startPos = fromCenter + mainDir * 58
	local endPos = toCenter - mainDir * 58

	-- 1. Initial Straight Approach Pier from Island 1 gateway (Length 16 studs, Width 18 - completely unblocked)
	local pierEnd = startPos + mainDir * 16
	buildBridgeSegment(bridgeContainer, startPos, pierEnd, 18, targetZone.Color, zoneId, Enum.Material.DiamondPlate, Color3.fromRGB(70, 75, 85))

	-- 2. Midway Landmark Island (Circle diameter 26, centered at midway between pierEnd and endPos - 18)
	local midwayPos = (pierEnd + (endPos - mainDir * 18)) / 2
	buildMidwayIsland(bridgeContainer, midwayPos, Vector3.new(26, 4, 26), Color3.fromRGB(48, 45, 52), zoneId)

	-- 3. Creative Split Paths: Route A (Elevated Catwalk) & Route B (Low Causeway)
	-- Route A begins at pierEnd + lateralNorm * 5, peaks at forkA_Mid (+3.5 Y), ends at midwayPos + lateralNorm * 5
	local forkA_Start = pierEnd + lateralNorm * 5
	local forkA_Mid = (forkA_Start + midwayPos + lateralNorm * 5) / 2 + lateralNorm * 6 + Vector3.new(0, 3.5, 0)
	local forkA_End = midwayPos + lateralNorm * 5
	buildBridgeSegment(bridgeContainer, forkA_Start, forkA_Mid, 10, targetZone.Color, zoneId, Enum.Material.DiamondPlate, Color3.fromRGB(60, 65, 75))
	buildBridgeSegment(bridgeContainer, forkA_Mid, forkA_End, 10, targetZone.Color, zoneId, Enum.Material.DiamondPlate, Color3.fromRGB(60, 65, 75))

	-- Route B begins at pierEnd - lateralNorm * 5, dips at forkB_Mid (-1.2 Y), ends at midwayPos - lateralNorm * 5
	local forkB_Start = pierEnd - lateralNorm * 5
	local forkB_Mid = (forkB_Start + midwayPos - lateralNorm * 5) / 2 - lateralNorm * 6 + Vector3.new(0, -1.2, 0)
	local forkB_End = midwayPos - lateralNorm * 5
	local routeBMat = (zoneId == 2 and Enum.Material.CorrodedMetal) or (zoneId == 3 and Enum.Material.Metal) or Enum.Material.DiamondPlate
	local routeBCol = (zoneId == 2 and Color3.fromRGB(115, 65, 40)) or (zoneId == 3 and Color3.fromRGB(55, 50, 50)) or Color3.fromRGB(45, 48, 56)
	buildBridgeSegment(bridgeContainer, forkB_Start, forkB_Mid, 10, targetZone.Color, zoneId, routeBMat, routeBCol)
	buildBridgeSegment(bridgeContainer, forkB_Mid, forkB_End, 10, targetZone.Color, zoneId, routeBMat, routeBCol)

	-- Central Hazard Chevron at split entrance (smooth transition, prevents falling in gap)
	local chevron = Instance.new("Part")
	chevron.Name = "ForkChevron"
	chevron.Size = Vector3.new(6, 2, 4)
	local forkAngle = math.atan2(mainDir.Z, mainDir.X)
	chevron.CFrame = CFrame.new(pierEnd + mainDir * 2 + Vector3.new(0, 1, 0)) * CFrame.Angles(0, -forkAngle, 0)
	chevron.Anchored = true
	chevron.Material = Enum.Material.Metal
	chevron.Color = Color3.fromRGB(35, 38, 48)
	chevron.Parent = bridgeContainer

	-- Chevron Amber Light
	local chevLight = Instance.new("Part")
	chevLight.Size = Vector3.new(5.6, 0.4, 0.4)
	chevLight.CFrame = chevron.CFrame * CFrame.new(0, 1, -1.8)
	chevLight.Anchored = true
	chevLight.Material = Enum.Material.Neon
	chevLight.Color = Color3.fromRGB(255, 170, 30)
	chevLight.Parent = bridgeContainer

	-- 4. Midway Thematic Landmark
	if zoneId == 2 then
		-- Salvage Beacon Tower
		local beacon = Instance.new("Part")
		beacon.Size = Vector3.new(2.4, 14, 2.4)
		beacon.Position = midwayPos + Vector3.new(0, 7, 0)
		beacon.Anchored = true
		beacon.Material = Enum.Material.Metal
		beacon.Color = Color3.fromRGB(38, 40, 48)
		beacon.Parent = bridgeContainer

		local beaconLight = Instance.new("Part")
		beaconLight.Size = Vector3.new(2.8, 1.8, 2.8)
		beaconLight.Position = midwayPos + Vector3.new(0, 14, 0)
		beaconLight.Anchored = true
		beaconLight.Material = Enum.Material.Neon
		beaconLight.Color = Color3.fromRGB(255, 170, 30)
		beaconLight.Parent = bridgeContainer
	elseif zoneId == 3 then
		-- Smelting Radiator Vent
		local vent = Instance.new("Part")
		vent.Size = Vector3.new(6, 8, 6)
		vent.Position = midwayPos + Vector3.new(0, 4, 0)
		vent.Anchored = true
		vent.Material = Enum.Material.Metal
		vent.Color = Color3.fromRGB(35, 38, 44)
		vent.Parent = bridgeContainer

		local ventGlow = Instance.new("Part")
		ventGlow.Size = Vector3.new(6.2, 1.2, 6.2)
		ventGlow.Position = midwayPos + Vector3.new(0, 8.2, 0)
		ventGlow.Anchored = true
		ventGlow.Material = Enum.Material.Neon
		ventGlow.Color = Color3.fromRGB(255, 100, 20)
		ventGlow.Parent = bridgeContainer
	elseif zoneId == 4 then
		-- Quantum Spire & Orb
		local spire = Instance.new("Part")
		spire.Size = Vector3.new(3, 12, 3)
		spire.Position = midwayPos + Vector3.new(0, 6, 0)
		spire.Anchored = true
		spire.Material = Enum.Material.Metal
		spire.Color = Color3.fromRGB(35, 42, 58)
		spire.Parent = bridgeContainer

		local spireOrb = Instance.new("Part")
		spireOrb.Shape = Enum.PartType.Ball
		spireOrb.Size = Vector3.new(5, 5, 5)
		spireOrb.Position = midwayPos + Vector3.new(0, 13, 0)
		spireOrb.Anchored = true
		spireOrb.Material = Enum.Material.Neon
		spireOrb.Color = Color3.fromRGB(40, 220, 200)
		spireOrb.Parent = bridgeContainer
	elseif zoneId == 5 then
		-- Fractured Dreadnought Hull Fin
		local hullFin = Instance.new("Part")
		hullFin.Size = Vector3.new(18, 12, 2.5)
		hullFin.CFrame = CFrame.new(midwayPos + Vector3.new(0, 7, 0)) * CFrame.Angles(math.rad(15), math.rad(25), math.rad(-10))
		hullFin.Anchored = true
		hullFin.Material = Enum.Material.Metal
		hullFin.Color = Color3.fromRGB(50, 42, 65)
		hullFin.Parent = bridgeContainer
	end

	-- 5. Final Approach Span from Midway Island to Target Zone (Length ~18 studs, Width 18)
	local finalSpanStart = midwayPos + mainDir * 12
	buildBridgeSegment(bridgeContainer, finalSpanStart, endPos, 18, targetZone.Color, zoneId, Enum.Material.DiamondPlate, Color3.fromRGB(70, 75, 85))

	-- 6. Gate Model positioned on the final approach span
	local gatePos = endPos - mainDir * 12
	buildZoneGate(bridgeFolder, gatePos, mainDir, 18, targetZone)
end

-- 6. Void Fall Protection (Catch falling players and safely teleport them)
function ZoneService.setupVoidProtection()
	local rescueFolder = Workspace:FindFirstChild("SafetyNet") :: Folder
	if not rescueFolder then
		rescueFolder = Instance.new("Folder")
		rescueFolder.Name = "SafetyNet"
		rescueFolder.Parent = Workspace
	end

	-- Massive trigger plate covering the entire non-linear game area at Y = -16
	local net = Instance.new("Part")
	net.Name = "VoidRescueTrigger"
	net.Size = Vector3.new(3000, 2, 3000)
	net.Position = Vector3.new(100, -16, 50)
	net.Anchored = true
	net.CanCollide = false
	net.Transparency = 1
	net.Parent = rescueFolder

	local rescueDebounce: { [Player]: number } = {}

	local function rescuePlayer(player: Player)
		local now = os.clock()
		if rescueDebounce[player] and (now - rescueDebounce[player]) < 1.5 then
			return
		end
		rescueDebounce[player] = now

		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end

		-- Teleport safely back to Central Hub Spawn
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.new(0, 3.5, 15)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "ANTI-GRAVITY RESCUE", "You fell off! Safely warped back to Hub.", Color3.fromRGB(80, 200, 255))
	end

	net.Touched:Connect(function(hit)
		local char = hit.Parent
		if not char then return end
		if hit.Name ~= "HumanoidRootPart" and hit.Name ~= "UpperTorso" and hit.Name ~= "Torso" then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			rescuePlayer(player)
		end
	end)

	-- Secondary Heartbeat Safety Loop (checks Y height every 0.5s in case of high speed physics tunneling)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				if char and char.Parent then
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and root.Position.Y < -14 then
						rescuePlayer(player)
					end
				end
			end
		end
	end)

	print("[ZoneService] Void fall protection active.")
end

function ZoneService.unlockZone(player: Player, zoneId: number): boolean
	local data = DataService.get(player)
	if not data then return false end

	local zone = Config.Zones[zoneId]
	if not zone then return false end

	if (data.MaxZoneReached or 1) >= zoneId then
		return true
	end

	if (data.MaxZoneReached or 1) + 1 ~= zoneId then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Locked", "Unlock previous zones first!", Color3.fromRGB(255, 70, 70))
		return false
	end

	local CurrencyService = require(script.Parent.CurrencyService)
	if CurrencyService.removeScrap(player, zone.UnlockCost) then
		data.MaxZoneReached = zoneId
		data.CurrentZone = zoneId
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "ZONE UNLOCKED!", string.format("Welcome to %s!", zone.Name), zone.Color)
		return true
	else
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Need More Scrap", string.format("Need %s Scrap to unlock %s.", CurrencyService.formatNumber(zone.UnlockCost), zone.Name), Color3.fromRGB(255, 70, 70))
	end

	return false
end

-- Teleports a player to any unlocked zone
function ZoneService.teleportPlayer(player: Player, zoneId: number)
	local data = DataService.get(player)
	if not data then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- Zone 0 or 1: Warp to Central Hub Recycler / Spawn
	if zoneId <= 1 then
		if root then
			root.CFrame = CFrame.new(0, 3.5, 0)
		end
		data.CurrentZone = 1
		DataService.sync(player)
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "WARPED", "Traveled to Central Hub.", Color3.fromRGB(80, 200, 255))
		return
	end

	-- Outer Zone verification
	if (data.MaxZoneReached or 1) < zoneId then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "SECTOR LOCKED", string.format("Zone %d is locked! Unlock it first.", zoneId), Color3.fromRGB(255, 70, 70))
		return
	end

	local targetCenter = ZONE_CENTERS[zoneId]
	if targetCenter and root then
		root.CFrame = CFrame.new(targetCenter + Vector3.new(0, 3.5, 0))
		data.CurrentZone = zoneId
		DataService.sync(player)
		local zone = Config.Zones[zoneId]
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "WARPED", string.format("Traveled to Zone %d: %s.", zoneId, zone and zone.Name or ""), zone and zone.Color or Color3.fromRGB(80, 200, 255))
	end
end

-- 7. Continuous Spatial Zone Patrol Loop (Server-authoritative coordinate verification)
function ZoneService.setupZonePatrol()
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				if char and char.Parent then
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						local data = DataService.get(player)
						local maxZone = data and (data.MaxZoneReached or 1) or 1
						if maxZone < #Config.Zones then
							local playerPos2D = Vector3.new(root.Position.X, 0, root.Position.Z)
							-- Check if player is trespassing inside any locked zone compound (radius < 62)
							for lockedZoneId = maxZone + 1, #Config.Zones do
								local lockedCenter = ZONE_CENTERS[lockedZoneId]
								if lockedCenter then
									local lockedPos2D = Vector3.new(lockedCenter.X, 0, lockedCenter.Z)
									if (playerPos2D - lockedPos2D).Magnitude < 62 then
										-- Trespassing! Safely bounce back to the player's highest unlocked zone center
										local safeZoneId = math.clamp(maxZone, 1, #Config.Zones)
										local safeCenter = ZONE_CENTERS[safeZoneId] or Vector3.new(0, 0, 0)
										root.AssemblyLinearVelocity = Vector3.zero
										root.AssemblyAngularVelocity = Vector3.zero
										root.CFrame = CFrame.new(safeCenter + Vector3.new(0, 3.5, 0))

										local now = os.clock()
										if not patrolDebounces[player] or (now - patrolDebounces[player]) >= 1.0 then
											patrolDebounces[player] = now
											local notif = Remotes.getEvent("ShowNotification")
											if notif then
												notif:FireClient(
													player,
													"SECURITY LOCK",
													string.format("Zone %d is locked! Unlock it with Scrap to enter.", lockedZoneId),
													Color3.fromRGB(255, 75, 75)
												)
											end
										end
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
	print("[ZoneService] Server-authoritative spatial zone patrol active.")
end

function ZoneService.init()
	-- Clear old world structures
	for _, name in ipairs({ "CentralHub", "Bridges", "ScrapNodes", "Decorations", "SafetyNet", "GlobalLeaderboard", "BackgroundVistas" }) do
		local old = Workspace:FindFirstChild(name)
		if old then old:Destroy() end
	end
	for i = 1, 10 do
		local old = Workspace:FindFirstChild("Zone_" .. tostring(i))
		if old then old:Destroy() end
	end
	table.clear(zoneGates)

	ZoneService.setupLighting()
	ZoneService.constructCentralHub()

	-- Construct outer zones (Zone 2 to 5)
	for i = 2, #Config.Zones do
		local zone = Config.Zones[i]
		local centerPos = ZONE_CENTERS[i]
		ZoneService.constructZonePlatform(zone, centerPos)
		ZoneService.constructBridge(i)
	end

	-- Initialize Environment, Skybox & Horizon Vistas
	EnvironmentService.init()

	-- Initialize Grounded In-World Leaderboard
	local LeaderboardService = require(script.Parent.LeaderboardService)
	LeaderboardService.createInWorldBoard()

	-- Void fall safety net
	ZoneService.setupVoidProtection()

	-- Server-authoritative spatial zone patrol
	ZoneService.setupZonePatrol()

	-- Remote event listener for TeleportZone
	if RunService:IsServer() then
		local teleportRemote = Remotes.getEvent("TeleportZone")
		if teleportRemote then
			teleportRemote.OnServerEvent:Connect(function(player, zoneId)
				if type(zoneId) == "number" then
					ZoneService.teleportPlayer(player, zoneId)
				end
			end)
		end

		local unlockRemote = Remotes.getEvent("UnlockZone")
		if unlockRemote then
			unlockRemote.OnServerEvent:Connect(function(player, zoneId)
				if type(zoneId) == "number" then
					ZoneService.unlockZone(player, zoneId)
				end
			end)
		end

		Players.PlayerRemoving:Connect(function(player)
			portalDebounces[player] = nil
			sellDebounce[player] = nil
			patrolDebounces[player] = nil
		end)
	end

	print("[ZoneService] Polished Central Hub, Seamless Bridges, and Anti-Gravity Protection initialized.")
end

return ZoneService
