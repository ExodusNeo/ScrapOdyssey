--!strict
-- EnvironmentService: Transforms Scrap Odyssey from a greybox prototype into an immersive floating orbital scrapyard world.
-- Features:
-- 1. Deep Space Cosmic Skybox & Atmospheric Depth in Lighting
-- 2. Floating Island Underside Rock Roots (Faceted Asteroid Mantles)
-- 3. Massive Industrial Anti-Gravity Repulsor Cores & Corner Thrusters
-- 4. Bridge Undercarriage Box Girders, Cross-Trusses & Magnetic Stabilizers
-- 5. Surface Diamond-Plate Catwalks, Hazard Stripes & Corner Floodlight Towers
-- 6. Thematic Distant Horizon Vistas (Salvage Crane, Lava Falls, Cyber Data Rings, Starship Wreck)
-- 7. Distant Parallax Asteroid Belt

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)

local EnvironmentService = {}

local ZONE_CENTERS = {
	[1] = Vector3.new(0, 0, 0),
	[2] = Vector3.new(160, 0, 0),
	[3] = Vector3.new(320, 0, 0),
	[4] = Vector3.new(480, 0, 0),
	[5] = Vector3.new(640, 0, 0),
}

-- 1. Setup Celestial Cosmic Skybox, Fog, and Eye-Friendly Atmospheric Lighting (No Sun Glare)
function EnvironmentService.setupAtmosphereAndSky()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	Lighting.Brightness = 1.05
	Lighting.ClockTime = 14.5 -- Comfortable afternoon ambient lighting
	Lighting.GeographicLatitude = 25
	Lighting.OutdoorAmbient = Color3.fromRGB(80, 85, 95)
	Lighting.Ambient = Color3.fromRGB(65, 70, 78)
	Lighting.ShadowSoftness = 0.4

	-- Clear ALL lingering effects in Lighting (including SunRaysEffect, BloomEffect, Sky, etc.)
	for _, child in ipairs(Lighting:GetChildren()) do
		child:Destroy()
	end

	-- Cosmic Deep Space Skybox with Sun & Moon disabled (Zero Sun Glare)
	local sky = Instance.new("Sky")
	sky.Name = "CosmicSalvageSky"
	sky.SkyboxBk = "rbxassetid://159454299"
	sky.SkyboxDn = "rbxassetid://159454296"
	sky.SkyboxFt = "rbxassetid://159454293"
	sky.SkyboxLf = "rbxassetid://159454286"
	sky.SkyboxRt = "rbxassetid://159454300"
	sky.SkyboxUp = "rbxassetid://159454288"
	sky.CelestialBodiesShown = false -- Completely turns off the sun and moon disks!
	sky.SunAngularSize = 0           -- Eliminates sun size calculation
	sky.MoonAngularSize = 0          -- Eliminates moon size calculation
	sky.SunTextureId = ""            -- No bright sun texture
	sky.MoonTextureId = ""           -- No moon texture
	sky.Parent = Lighting

	-- Atmospheric depth: crystal clear space air without blinding sun glare or haze
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.15
	atmosphere.Offset = 0.0
	atmosphere.Color = Color3.fromRGB(160, 175, 200)
	atmosphere.Decay = Color3.fromRGB(130, 145, 170)
	atmosphere.Glare = 0 -- Absolutely zero sun glare piercing camera
	atmosphere.Haze = 0  -- Zero blinding atmospheric haze
	atmosphere.Parent = Lighting

	-- Extremely subtle Bloom (only highest-energy neons get a gentle fringe, no eye-strain)
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.03
	bloom.Size = 6
	bloom.Threshold = 2.4
	bloom.Parent = Lighting

	-- Balanced, clean Color Correction
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.0
	cc.Contrast = 0.04
	cc.Saturation = 0.03
	cc.TintColor = Color3.fromRGB(255, 255, 255)
	cc.Parent = Lighting

	print("[EnvironmentService] Celestial Cosmic Skybox configured: Sun disk and glare eliminated.")
end

-- 2. Construct Floating Island Underside (Faceted Asteroid Root & Anti-Gravity Thruster Units)
function EnvironmentService.constructIslandUnderside(parent: Instance, centerPos: Vector3, zoneId: number, zoneColor: Color3)
	local undersideModel = Instance.new("Model")
	undersideModel.Name = "IslandUnderside_Zone" .. tostring(zoneId)

	local rockMat = Enum.Material.Slate
	local rockColor = Color3.fromRGB(28, 30, 36)
	local darkSteel = Color3.fromRGB(36, 40, 48)

	-- Tier 1: Sub-surface Collar (Inset from platform rim)
	local t1 = Instance.new("Part")
	t1.Name = "RootTier1"
	t1.Size = Vector3.new(94, 6, 164)
	t1.Position = centerPos - Vector3.new(0, 5, 0)
	t1.Anchored = true
	t1.CanCollide = false
	t1.Material = rockMat
	t1.Color = rockColor
	t1.Parent = undersideModel

	-- Tier 2: 8 Angled Faceted Rock Boulders along the perimeter
	local facetOffsets = {
		{ Pos = Vector3.new(-38, -9, -65), Size = Vector3.new(24, 10, 32), Rot = Vector3.new(8, 12, -6) },
		{ Pos = Vector3.new(38, -9, -65),  Size = Vector3.new(24, 10, 32), Rot = Vector3.new(8, -12, 6) },
		{ Pos = Vector3.new(-38, -9, 65),  Size = Vector3.new(24, 10, 32), Rot = Vector3.new(-8, 12, -6) },
		{ Pos = Vector3.new(38, -9, 65),   Size = Vector3.new(24, 10, 32), Rot = Vector3.new(-8, -12, 6) },
		{ Pos = Vector3.new(-42, -9, 0),   Size = Vector3.new(18, 12, 45), Rot = Vector3.new(0, 5, -8) },
		{ Pos = Vector3.new(42, -9, 0),    Size = Vector3.new(18, 12, 45), Rot = Vector3.new(0, -5, 8) },
		{ Pos = Vector3.new(0, -9, -74),   Size = Vector3.new(38, 10, 20), Rot = Vector3.new(8, 0, 0) },
		{ Pos = Vector3.new(0, -9, 74),    Size = Vector3.new(38, 10, 20), Rot = Vector3.new(-8, 0, 0) },
	}

	for i, f in ipairs(facetOffsets) do
		local rock = Instance.new("Part")
		rock.Name = "RockFacet_" .. tostring(i)
		rock.Size = f.Size
		rock.CFrame = CFrame.new(centerPos + f.Pos) * CFrame.Angles(math.rad(f.Rot.X), math.rad(f.Rot.Y), math.rad(f.Rot.Z))
		rock.Anchored = true
		rock.CanCollide = false
		rock.Material = rockMat
		rock.Color = Color3.fromRGB(24, 26, 32)
		rock.Parent = undersideModel
	end

	-- Tier 3: Mid Keel Asteroid Body
	local t3 = Instance.new("Part")
	t3.Name = "RootTier3"
	t3.Size = Vector3.new(68, 12, 118)
	t3.Position = centerPos - Vector3.new(0, 14, 0)
	t3.Anchored = true
	t3.CanCollide = false
	t3.Material = rockMat
	t3.Color = Color3.fromRGB(22, 24, 30)
	t3.Parent = undersideModel

	-- Tier 4: Lower Spire Keel
	local t4 = Instance.new("Part")
	t4.Name = "RootTier4"
	t4.Size = Vector3.new(42, 14, 72)
	t4.Position = centerPos - Vector3.new(0, 25, 0)
	t4.Anchored = true
	t4.CanCollide = false
	t4.Material = rockMat
	t4.Color = Color3.fromRGB(18, 20, 25)
	t4.Parent = undersideModel

	-- Tier 5: Bottom Stalactite Tip
	local t5 = Instance.new("Part")
	t5.Name = "RootTier5"
	t5.Size = Vector3.new(18, 14, 30)
	t5.Position = centerPos - Vector3.new(0, 36, 0)
	t5.Anchored = true
	t5.CanCollide = false
	t5.Material = rockMat
	t5.Color = Color3.fromRGB(14, 15, 20)
	t5.Parent = undersideModel

	-- Thematic Underside Accents
	if zoneId == 3 then
		-- Molten Foundry: Glowing magma veins in rock fissures
		local magma1 = Instance.new("Part")
		magma1.Size = Vector3.new(2, 18, 55)
		magma1.Position = centerPos - Vector3.new(12, 20, 0)
		magma1.Anchored = true
		magma1.CanCollide = false
		magma1.Material = Enum.Material.Neon
		magma1.Color = Color3.fromRGB(255, 90, 20)
		magma1.Parent = undersideModel

		local magma2 = magma1:Clone()
		magma2.Position = centerPos - Vector3.new(-12, 22, -15)
		magma2.Parent = undersideModel
	elseif zoneId == 4 then
		-- Cyber Wasteland: Glowing cyan data conduits running down the keel
		local conduit1 = Instance.new("Part")
		conduit1.Size = Vector3.new(1.2, 24, 1.2)
		conduit1.Position = centerPos - Vector3.new(15, 18, 20)
		conduit1.Anchored = true
		conduit1.CanCollide = false
		conduit1.Material = Enum.Material.Neon
		conduit1.Color = Color3.fromRGB(0, 230, 255)
		conduit1.Parent = undersideModel

		local conduit2 = conduit1:Clone()
		conduit2.Position = centerPos - Vector3.new(-15, 18, -20)
		conduit2.Parent = undersideModel
	elseif zoneId == 5 then
		-- Void Frontier: Floating dark matter crystal clusters jutting from rock
		for cIdx = 1, 4 do
			local crystal = Instance.new("Part")
			crystal.Size = Vector3.new(2.5, 12, 2.5)
			local angle = cIdx * 90
			crystal.CFrame = CFrame.new(centerPos - Vector3.new(0, 30, 0)) * CFrame.Angles(math.rad(25), math.rad(angle), 0) * CFrame.new(0, 0, 10)
			crystal.Anchored = true
			crystal.CanCollide = false
			crystal.Material = Enum.Material.Neon
			crystal.Color = Color3.fromRGB(180, 40, 255)
			crystal.Parent = undersideModel
		end
	end

	-- Giant Central Anti-Gravity Repulsor Turbine Core
	local repulsorCore = Instance.new("Part")
	repulsorCore.Name = "AntiGravRepulsorCore"
	repulsorCore.Shape = Enum.PartType.Cylinder
	repulsorCore.Size = Vector3.new(8, 18, 18)
	repulsorCore.CFrame = CFrame.new(centerPos - Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0, math.rad(90))
	repulsorCore.Anchored = true
	repulsorCore.CanCollide = false
	repulsorCore.Material = Enum.Material.Metal
	repulsorCore.Color = darkSteel
	repulsorCore.Parent = undersideModel

	-- Core Energy Ring
	local coreRing = Instance.new("Part")
	coreRing.Name = "CoreEnergyRing"
	coreRing.Shape = Enum.PartType.Cylinder
	coreRing.Size = Vector3.new(2, 19.5, 19.5)
	coreRing.CFrame = CFrame.new(centerPos - Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0, math.rad(90))
	coreRing.Anchored = true
	coreRing.CanCollide = false
	coreRing.Material = Enum.Material.Neon
	coreRing.Color = zoneColor
	coreRing.Parent = undersideModel

	-- Downward Ion Thrust Particle Emitter
	local thrustEmitter = Instance.new("ParticleEmitter")
	thrustEmitter.Name = "IonThrustEmitter"
	thrustEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.3, zoneColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 50)),
	})
	thrustEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 6),
		NumberSequenceKeypoint.new(1, 14),
	})
	thrustEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	thrustEmitter.Lifetime = NumberRange.new(1.5, 2.5)
	thrustEmitter.Rate = 18
	thrustEmitter.Speed = NumberRange.new(12, 22)
	thrustEmitter.SpreadAngle = Vector2.new(15, 15)
	thrustEmitter.EmissionDirection = Enum.NormalId.Bottom
	thrustEmitter.Acceleration = Vector3.new(0, -10, 0)
	thrustEmitter.Parent = repulsorCore

	-- 4 Auxiliary Corner Stabilization Thrusters
	local cornerCoords = {
		Vector3.new(-36, -9, -60),
		Vector3.new(36, -9, -60),
		Vector3.new(-36, -9, 60),
		Vector3.new(36, -9, 60),
	}

	for cIdx, cPos in ipairs(cornerCoords) do
		local thruster = Instance.new("Part")
		thruster.Name = "AuxThruster_" .. tostring(cIdx)
		thruster.Shape = Enum.PartType.Cylinder
		thruster.Size = Vector3.new(5, 7, 7)
		local tiltX = (cPos.X > 0 and -12) or 12
		local tiltZ = (cPos.Z > 0 and -12) or 12
		thruster.CFrame = CFrame.new(centerPos + cPos) * CFrame.Angles(math.rad(tiltZ), 0, math.rad(90 + tiltX))
		thruster.Anchored = true
		thruster.CanCollide = false
		thruster.Material = Enum.Material.Metal
		thruster.Color = darkSteel
		thruster.Parent = undersideModel

		-- Nozzle Ring
		local nozzle = Instance.new("Part")
		nozzle.Shape = Enum.PartType.Cylinder
		nozzle.Size = Vector3.new(1, 7.6, 7.6)
		nozzle.CFrame = thruster.CFrame * CFrame.new(2.2, 0, 0)
		nozzle.Anchored = true
		nozzle.CanCollide = false
		nozzle.Material = Enum.Material.Neon
		nozzle.Color = zoneColor
		nozzle.Parent = undersideModel

		-- Structural Support Arm connecting to island base
		local arm = Instance.new("Part")
		arm.Size = Vector3.new(3, 8, 3)
		arm.Position = centerPos + cPos + Vector3.new(0, 4, 0)
		arm.Anchored = true
		arm.CanCollide = false
		arm.Material = Enum.Material.DiamondPlate
		arm.Color = Color3.fromRGB(45, 48, 56)
		arm.Parent = undersideModel
	end

	undersideModel.Parent = parent
	return undersideModel
end

-- 3. Construct Bridge Undercarriage (Longitudinal Box Girders, Cross Trusses & Magnetic Stabilizers)
function EnvironmentService.constructBridgeUnderside(parent: Instance, fromCenter: Vector3, toCenter: Vector3, bridgeX: number, bridgeLength: number, bridgeWidth: number, targetZoneId: number)
	local bridgeModel = Instance.new("Model")
	bridgeModel.Name = "BridgeUnderside_Zone" .. tostring(targetZoneId)

	local steelMat = Enum.Material.DiamondPlate
	local steelColor = Color3.fromRGB(38, 42, 50)
	local accentColor = Config.Zones[targetZoneId] and Config.Zones[targetZoneId].Color or Color3.fromRGB(80, 140, 200)

	-- Dual Heavy Longitudinal Box Girders (North & South undersides)
	local beamN = Instance.new("Part")
	beamN.Name = "GirderN"
	beamN.Size = Vector3.new(bridgeLength, 3, 2)
	beamN.Position = Vector3.new(bridgeX, -2.5, -9.5)
	beamN.Anchored = true
	beamN.CanCollide = false
	beamN.Material = steelMat
	beamN.Color = steelColor
	beamN.Parent = bridgeModel

	local beamS = beamN:Clone()
	beamS.Name = "GirderS"
	beamS.Position = Vector3.new(bridgeX, -2.5, 9.5)
	beamS.Parent = bridgeModel

	-- 5 Cross Trusses spaced along the bridge length
	local trussStep = bridgeLength / 6
	for i = 1, 5 do
		local trussX = (bridgeX - (bridgeLength / 2)) + (i * trussStep)
		local crossTruss = Instance.new("Part")
		crossTruss.Name = "CrossTruss_" .. tostring(i)
		crossTruss.Size = Vector3.new(2, 2.2, bridgeWidth - 4)
		crossTruss.Position = Vector3.new(trussX, -2.5, 0)
		crossTruss.Anchored = true
		crossTruss.CanCollide = false
		crossTruss.Material = steelMat
		crossTruss.Color = Color3.fromRGB(48, 52, 62)
		crossTruss.Parent = bridgeModel
	end

	-- Angled Structural Rock Abutment Brackets
	local bracketW = Instance.new("Part")
	bracketW.Size = Vector3.new(8, 12, bridgeWidth + 2)
	bracketW.CFrame = CFrame.new(bridgeX - (bridgeLength / 2) + 3, -7, 0) * CFrame.Angles(0, 0, math.rad(-22))
	bracketW.Anchored = true
	bracketW.CanCollide = false
	bracketW.Material = Enum.Material.Slate
	bracketW.Color = Color3.fromRGB(25, 27, 34)
	bracketW.Parent = bridgeModel

	local bracketE = Instance.new("Part")
	bracketE.Size = Vector3.new(8, 12, bridgeWidth + 2)
	bracketE.CFrame = CFrame.new(bridgeX + (bridgeLength / 2) - 3, -7, 0) * CFrame.Angles(0, 0, math.rad(22))
	bracketE.Anchored = true
	bracketE.CanCollide = false
	bracketE.Material = Enum.Material.Slate
	bracketE.Color = Color3.fromRGB(25, 27, 34)
	bracketE.Parent = bridgeModel

	-- Mid-Span Magnetic Stabilizer Module
	local magPod = Instance.new("Part")
	magPod.Name = "MidSpanMagStabilizer"
	magPod.Shape = Enum.PartType.Cylinder
	magPod.Size = Vector3.new(4, 9, 9)
	magPod.CFrame = CFrame.new(bridgeX, -4.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	magPod.Anchored = true
	magPod.CanCollide = false
	magPod.Material = Enum.Material.Metal
	magPod.Color = Color3.fromRGB(30, 34, 42)
	magPod.Parent = bridgeModel

	local magCore = Instance.new("Part")
	magCore.Shape = Enum.PartType.Cylinder
	magCore.Size = Vector3.new(1.2, 9.8, 9.8)
	magCore.CFrame = magPod.CFrame
	magCore.Anchored = true
	magCore.CanCollide = false
	magCore.Material = Enum.Material.Neon
	magCore.Color = accentColor
	magCore.Parent = bridgeModel

	-- Soft downward anti-grav beam
	local magLight = Instance.new("PointLight")
	magLight.Color = accentColor
	magLight.Brightness = 0.5
	magLight.Range = 16
	magLight.Parent = magCore

	bridgeModel.Parent = parent
	return bridgeModel
end

-- 4. Surface Dressing (Arterial Diamond-Plate Catwalks, Hazard Stripes & Corner Floodlights)
function EnvironmentService.constructSurfaceDressing(parent: Instance, centerPos: Vector3, zone: Types.ZoneConfig)
	local dressFolder = Instance.new("Folder")
	dressFolder.Name = "SurfaceDressing"

	-- Main East-West Spine Catwalk (12 studs wide, 0.08 studs above platform to prevent z-fighting)
	local spineWalk = Instance.new("Part")
	spineWalk.Name = "CatwalkSpine"
	spineWalk.Size = Vector3.new(96, 0.08, 12)
	spineWalk.Position = centerPos + Vector3.new(0, 0.04, 0)
	spineWalk.Anchored = true
	spineWalk.CanCollide = true
	spineWalk.Material = Enum.Material.DiamondPlate
	spineWalk.Color = Color3.fromRGB(52, 56, 66)
	spineWalk.Parent = dressFolder

	-- North Branch Path leading toward Scrap Recycler
	local northBranch = Instance.new("Part")
	northBranch.Name = "CatwalkRecyclerBranch"
	northBranch.Size = Vector3.new(10, 0.08, 62)
	northBranch.Position = centerPos + Vector3.new(0, 0.04, -36)
	northBranch.Anchored = true
	northBranch.CanCollide = true
	northBranch.Material = Enum.Material.DiamondPlate
	northBranch.Color = Color3.fromRGB(48, 52, 60)
	northBranch.Parent = dressFolder

	-- South Branch Path leading toward Portal Pad & Egg Pod
	local southBranch = Instance.new("Part")
	southBranch.Name = "CatwalkPortalBranch"
	southBranch.Size = Vector3.new(10, 0.08, 62)
	southBranch.Position = centerPos + Vector3.new(0, 0.04, 36)
	southBranch.Anchored = true
	southBranch.CanCollide = true
	southBranch.Material = Enum.Material.DiamondPlate
	southBranch.Color = Color3.fromRGB(48, 52, 60)
	southBranch.Parent = dressFolder

	-- Hazard Warning Border Bevels on Catwalk Edges
	local hazardColor = Color3.fromRGB(235, 175, 25)
	local darkStripColor = Color3.fromRGB(30, 32, 38)

	local borderN = Instance.new("Part")
	borderN.Size = Vector3.new(96, 0.12, 0.8)
	borderN.Position = centerPos + Vector3.new(0, 0.06, -6)
	borderN.Anchored = true
	borderN.CanCollide = false
	borderN.Material = Enum.Material.SmoothPlastic
	borderN.Color = hazardColor
	borderN.Parent = dressFolder

	local borderS = borderN:Clone()
	borderS.Position = centerPos + Vector3.new(0, 0.06, 6)
	borderS.Parent = dressFolder

	-- 4 Heavy Industrial Corner Floodlight Towers
	local floodCoords = {
		Vector3.new(-45, 0, -78),
		Vector3.new(45, 0, -78),
		Vector3.new(-45, 0, 78),
		Vector3.new(45, 0, 78),
	}

	for fIdx, fPos in ipairs(floodCoords) do
		local tower = Instance.new("Model")
		tower.Name = "FloodlightTower_" .. tostring(fIdx)

		-- Tower Base Mount
		local baseMount = Instance.new("Part")
		baseMount.Size = Vector3.new(3, 0.6, 3)
		baseMount.Position = centerPos + fPos + Vector3.new(0, 0.3, 0)
		baseMount.Anchored = true
		baseMount.Material = Enum.Material.DiamondPlate
		baseMount.Color = Color3.fromRGB(35, 38, 45)
		baseMount.Parent = tower

		-- Lattice Mast
		local mast = Instance.new("Part")
		mast.Size = Vector3.new(1.4, 16, 1.4)
		mast.Position = centerPos + fPos + Vector3.new(0, 8.3, 0)
		mast.Anchored = true
		mast.Material = Enum.Material.Metal
		mast.Color = Color3.fromRGB(42, 45, 54)
		mast.Parent = tower

		-- Angled Floodlight Head (Tilted toward center platform)
		local dirX = (fPos.X > 0 and -25) or 25
		local dirZ = (fPos.Z > 0 and -25) or 25

		local headCasing = Instance.new("Part")
		headCasing.Size = Vector3.new(2.8, 1.8, 3.2)
		headCasing.CFrame = CFrame.new(centerPos + fPos + Vector3.new(0, 16.5, 0)) * CFrame.Angles(math.rad(dirZ), 0, math.rad(dirX))
		headCasing.Anchored = true
		headCasing.Material = Enum.Material.Metal
		headCasing.Color = Color3.fromRGB(30, 32, 40)
		headCasing.Parent = tower

		-- Glowing Glass Bulb Lens
		local bulb = Instance.new("Part")
		bulb.Size = Vector3.new(2.4, 1.4, 0.2)
		bulb.CFrame = headCasing.CFrame * CFrame.new(0, 0, -1.6)
		bulb.Anchored = true
		bulb.CanCollide = false
		bulb.Material = Enum.Material.Neon
		bulb.Color = Color3.fromRGB(245, 235, 210)
		bulb.Parent = tower

		-- Soft Halogen Pool of Light
		local light = Instance.new("PointLight")
		light.Brightness = 0.65
		light.Range = 26
		light.Color = Color3.fromRGB(245, 230, 200)
		light.Shadows = false
		light.Parent = bulb

		tower.Parent = dressFolder
	end

	-- Edge Prop Clusters (Neatly placed along the empty side corners away from nodes)
	local propClusters = {
		Vector3.new(-42, 0, -60),
		Vector3.new(42, 0, 60),
	}

	for pIdx, pPos in ipairs(propClusters) do
		-- Industrial Cargo Container
		local crate = Instance.new("Part")
		crate.Name = "CargoCrate_" .. tostring(pIdx)
		crate.Size = Vector3.new(6, 5, 8)
		crate.Position = centerPos + pPos + Vector3.new(0, 2.5, 0)
		crate.Anchored = true
		crate.Material = Enum.Material.CorrodedMetal
		crate.Color = (pIdx == 1 and zone.Color) or Color3.fromRGB(55, 60, 70)
		crate.Parent = dressFolder

		-- Stacked Salvage Barrels
		for bIdx = 1, 3 do
			local bOffset = Vector3.new((bIdx == 1 and 4) or (bIdx == 2 and 4) or 4, 1.5, (bIdx == 1 and -2) or (bIdx == 2 and 2) or 0)
			local barrel = Instance.new("Part")
			barrel.Shape = Enum.PartType.Cylinder
			barrel.Size = Vector3.new(3, 2.2, 2.2)
			barrel.CFrame = CFrame.new(centerPos + pPos + bOffset) * CFrame.Angles(0, 0, math.rad(90))
			barrel.Anchored = true
			barrel.Material = Enum.Material.Metal
			barrel.Color = Color3.fromRGB(38, 42, 50)
			barrel.Parent = dressFolder
		end

		-- Steam Exhaust Vent
		local vent = Instance.new("Part")
		vent.Size = Vector3.new(2, 2, 2)
		vent.Position = centerPos + pPos + Vector3.new(-5, 1, 0)
		vent.Anchored = true
		vent.Material = Enum.Material.DiamondPlate
		vent.Color = Color3.fromRGB(40, 44, 52)
		vent.Parent = dressFolder

		local steam = Instance.new("ParticleEmitter")
		steam.Color = ColorSequence.new(Color3.fromRGB(220, 225, 235))
		steam.Size = NumberSequence.new(0.8, 3.0)
		steam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.7, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		steam.Lifetime = NumberRange.new(1.5, 2.5)
		steam.Rate = 5
		steam.Speed = NumberRange.new(3, 6)
		steam.SpreadAngle = Vector2.new(12, 12)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = vent
	end

	dressFolder.Parent = parent
	return dressFolder
end

-- 5. Construct Thematic Background Horizon Vistas (Distant Space Landmarks & Asteroid Belt)
function EnvironmentService.constructBackgroundVistas()
	local oldVistas = Workspace:FindFirstChild("BackgroundVistas")
	if oldVistas then oldVistas:Destroy() end

	local vistasFolder = Instance.new("Folder")
	vistasFolder.Name = "BackgroundVistas"
	vistasFolder.Parent = Workspace

	-- A. Floating Asteroid Belt (20 distant rocky asteroid chunks drifting in the void)
	local asteroidCoords = {
		-- North void background
		{ Pos = Vector3.new(-120, 40, -320), Size = Vector3.new(45, 30, 50), Rot = Vector3.new(15, 25, -10) },
		{ Pos = Vector3.new(0, 70, -360),    Size = Vector3.new(65, 45, 70), Rot = Vector3.new(-10, 45, 15) },
		{ Pos = Vector3.new(140, 25, -310),  Size = Vector3.new(38, 28, 42), Rot = Vector3.new(20, -15, 5) },
		{ Pos = Vector3.new(280, 85, -380),  Size = Vector3.new(55, 40, 60), Rot = Vector3.new(-15, 30, -25) },
		{ Pos = Vector3.new(420, 35, -330),  Size = Vector3.new(42, 32, 48), Rot = Vector3.new(10, -35, 12) },
		{ Pos = Vector3.new(560, 65, -370),  Size = Vector3.new(70, 50, 75), Rot = Vector3.new(-25, 10, 20) },
		{ Pos = Vector3.new(720, 30, -340),  Size = Vector3.new(50, 35, 55), Rot = Vector3.new(18, 50, -8) },
		-- South void background
		{ Pos = Vector3.new(-100, 50, 330),  Size = Vector3.new(40, 30, 45), Rot = Vector3.new(-12, 20, 15) },
		{ Pos = Vector3.new(60, 80, 370),    Size = Vector3.new(60, 42, 65), Rot = Vector3.new(15, -40, -10) },
		{ Pos = Vector3.new(220, 30, 320),   Size = Vector3.new(48, 34, 52), Rot = Vector3.new(-18, 15, 22) },
		{ Pos = Vector3.new(380, 90, 390),   Size = Vector3.new(68, 48, 72), Rot = Vector3.new(25, -25, -15) },
		{ Pos = Vector3.new(520, 45, 340),   Size = Vector3.new(52, 36, 56), Rot = Vector3.new(-10, 35, 18) },
		{ Pos = Vector3.new(680, 75, 380),   Size = Vector3.new(62, 44, 68), Rot = Vector3.new(20, -15, -20) },
		{ Pos = Vector3.new(820, 20, 330),   Size = Vector3.new(44, 30, 50), Rot = Vector3.new(-15, 45, 10) },
		-- Low abyss background
		{ Pos = Vector3.new(100, -70, -260), Size = Vector3.new(75, 45, 80), Rot = Vector3.new(5, 15, -5) },
		{ Pos = Vector3.new(500, -80, 280),  Size = Vector3.new(85, 50, 90), Rot = Vector3.new(-5, -20, 10) },
	}

	for aIdx, a in ipairs(asteroidCoords) do
		local asteroid = Instance.new("Part")
		asteroid.Name = "DistantAsteroid_" .. tostring(aIdx)
		asteroid.Size = a.Size
		asteroid.CFrame = CFrame.new(a.Pos) * CFrame.Angles(math.rad(a.Rot.X), math.rad(a.Rot.Y), math.rad(a.Rot.Z))
		asteroid.Anchored = true
		asteroid.CanCollide = false
		asteroid.CastShadow = false
		asteroid.Material = Enum.Material.Slate
		asteroid.Color = Color3.fromRGB(22, 24, 30)
		asteroid.Parent = vistasFolder
	end

	-- B. Zone 1 Vista: Towering Derelict Salvage Crane Silhouette in the background
	local craneModel = Instance.new("Model")
	craneModel.Name = "Vista_SalvageCrane"

	local craneMast = Instance.new("Part")
	craneMast.Size = Vector3.new(8, 90, 8)
	craneMast.Position = Vector3.new(-75, 42, -260)
	craneMast.Anchored = true
	craneMast.CanCollide = false
	craneMast.CastShadow = false
	craneMast.Material = Enum.Material.Metal
	craneMast.Color = Color3.fromRGB(32, 35, 44)
	craneMast.Parent = craneModel

	local craneArm = Instance.new("Part")
	craneArm.Size = Vector3.new(70, 6, 6)
	craneArm.Position = Vector3.new(-45, 84, -260)
	craneArm.Anchored = true
	craneArm.CanCollide = false
	craneArm.CastShadow = false
	craneArm.Material = Enum.Material.DiamondPlate
	craneArm.Color = Color3.fromRGB(40, 44, 55)
	craneArm.Parent = craneModel

	-- Dangling salvage cable
	local cable = Instance.new("Part")
	cable.Size = Vector3.new(0.6, 45, 0.6)
	cable.Position = Vector3.new(-25, 60, -260)
	cable.Anchored = true
	cable.CanCollide = false
	cable.CastShadow = false
	cable.Material = Enum.Material.Metal
	cable.Color = Color3.fromRGB(20, 22, 28)
	cable.Parent = craneModel

	-- Blinking red aircraft beacon light on crane peak
	local beacon = Instance.new("Part")
	beacon.Size = Vector3.new(1.5, 1.5, 1.5)
	beacon.Position = Vector3.new(-75, 88, -260)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CastShadow = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 40, 40)
	beacon.Parent = craneModel

	craneModel.Parent = vistasFolder

	-- C. Zone 3 Vista: Molten Lava Fall Cascading off the North Platform into the Abyss
	local lavaFallModel = Instance.new("Model")
	lavaFallModel.Name = "Vista_LavaFall"

	local lavaStream = Instance.new("Part")
	lavaStream.Name = "LavaStream"
	lavaStream.Size = Vector3.new(16, 75, 1.5)
	lavaStream.Position = Vector3.new(320, -35, -86)
	lavaStream.Anchored = true
	lavaStream.CanCollide = false
	lavaStream.CastShadow = false
	lavaStream.Material = Enum.Material.Neon
	lavaStream.Color = Color3.fromRGB(255, 95, 20)
	lavaStream.Parent = lavaFallModel

	-- Heat Smoke & Embers billowing up from the lava fall
	local lavaSmoke = Instance.new("ParticleEmitter")
	lavaSmoke.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 60, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 35, 40)),
	})
	lavaSmoke.Size = NumberSequence.new(3, 10)
	lavaSmoke.Transparency = NumberSequence.new(0.3, 1)
	lavaSmoke.Lifetime = NumberRange.new(2.5, 4.0)
	lavaSmoke.Rate = 14
	lavaSmoke.Speed = NumberRange.new(5, 10)
	lavaSmoke.SpreadAngle = Vector2.new(20, 20)
	lavaSmoke.Acceleration = Vector3.new(0, 8, 0)
	lavaSmoke.Parent = lavaStream

	-- Background Blast Furnace Smokestacks
	for s = 1, 2 do
		local sX = (s == 1 and 305) or 335
		local stack = Instance.new("Part")
		stack.Shape = Enum.PartType.Cylinder
		stack.Size = Vector3.new(65, 9, 9)
		stack.CFrame = CFrame.new(sX, 25, -280) * CFrame.Angles(0, 0, math.rad(90))
		stack.Anchored = true
		stack.CanCollide = false
		stack.CastShadow = false
		stack.Material = Enum.Material.Metal
		stack.Color = Color3.fromRGB(30, 28, 32)
		stack.Parent = lavaFallModel

		-- Fiery crown glow
		local crown = Instance.new("Part")
		crown.Shape = Enum.PartType.Cylinder
		crown.Size = Vector3.new(3, 10, 10)
		crown.CFrame = stack.CFrame * CFrame.new(33, 0, 0)
		crown.Anchored = true
		crown.CanCollide = false
		crown.CastShadow = false
		crown.Material = Enum.Material.Neon
		crown.Color = Color3.fromRGB(255, 80, 20)
		crown.Parent = lavaFallModel
	end

	lavaFallModel.Parent = vistasFolder

	-- D. Zone 4 Vista: Floating Holographic Cybernetic Data Ring in the Sky
	local cyberModel = Instance.new("Model")
	cyberModel.Name = "Vista_CyberDataRing"

	local ringCore = Instance.new("Part")
	ringCore.Shape = Enum.PartType.Cylinder
	ringCore.Size = Vector3.new(2.5, 50, 50)
	ringCore.CFrame = CFrame.new(480, 65, -280) * CFrame.Angles(math.rad(30), math.rad(25), 0)
	ringCore.Anchored = true
	ringCore.CanCollide = false
	ringCore.CastShadow = false
	ringCore.Material = Enum.Material.Neon
	ringCore.Color = Color3.fromRGB(0, 230, 255)
	ringCore.Transparency = 0.4
	ringCore.Parent = cyberModel

	local ringInner = Instance.new("Part")
	ringInner.Shape = Enum.PartType.Cylinder
	ringInner.Size = Vector3.new(2.8, 38, 38)
	ringInner.CFrame = ringCore.CFrame
	ringInner.Anchored = true
	ringInner.CanCollide = false
	ringInner.CastShadow = false
	ringInner.Material = Enum.Material.SmoothPlastic
	ringInner.Color = Color3.fromRGB(15, 20, 32)
	ringInner.Parent = cyberModel

	cyberModel.Parent = vistasFolder

	-- E. Zone 5 Vista: Shattered Starship Supercarrier Bow & Dark Matter Singularity
	local voidModel = Instance.new("Model")
	voidModel.Name = "Vista_StarshipWreckage"

	-- Main Supercarrier Bow Hull (Tilted broken command deck)
	local shipBow = Instance.new("Part")
	shipBow.Size = Vector3.new(75, 35, 110)
	shipBow.CFrame = CFrame.new(670, 48, -310) * CFrame.Angles(math.rad(-18), math.rad(35), math.rad(15))
	shipBow.Anchored = true
	shipBow.CanCollide = false
	shipBow.CastShadow = false
	shipBow.Material = Enum.Material.DiamondPlate
	shipBow.Color = Color3.fromRGB(24, 20, 32)
	shipBow.Parent = voidModel

	-- Fractured Supercarrier Bridge Windows
	local shipBridge = Instance.new("Part")
	shipBridge.Size = Vector3.new(30, 8, 45)
	shipBridge.CFrame = shipBow.CFrame * CFrame.new(0, 18, -15)
	shipBridge.Anchored = true
	shipBridge.CanCollide = false
	shipBridge.CastShadow = false
	shipBridge.Material = Enum.Material.Neon
	shipBridge.Color = Color3.fromRGB(160, 40, 255)
	shipBridge.Transparency = 0.3
	shipBridge.Parent = voidModel

	-- Swirling Cosmic Singularity Portal in the Far Abyss
	local vortex = Instance.new("Part")
	vortex.Name = "SingularityVortex"
	vortex.Shape = Enum.PartType.Ball
	vortex.Size = Vector3.new(50, 50, 50)
	vortex.Position = Vector3.new(800, 60, 0)
	vortex.Anchored = true
	vortex.CanCollide = false
	vortex.CastShadow = false
	vortex.Material = Enum.Material.Neon
	vortex.Color = Color3.fromRGB(120, 20, 220)
	vortex.Transparency = 0.5
	vortex.Parent = voidModel

	local vortexEmitter = Instance.new("ParticleEmitter")
	vortexEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 50, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 20, 160)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 10, 25)),
	})
	vortexEmitter.Size = NumberSequence.new(8, 28)
	vortexEmitter.Transparency = NumberSequence.new(0.3, 1)
	vortexEmitter.Lifetime = NumberRange.new(3, 5)
	vortexEmitter.Rate = 22
	vortexEmitter.Speed = NumberRange.new(6, 14)
	vortexEmitter.SpreadAngle = Vector2.new(180, 180)
	vortexEmitter.Parent = vortex

	voidModel.Parent = vistasFolder

	print("[EnvironmentService] Distant Horizon Vistas & Asteroid Belt generated.")
end

function EnvironmentService.init()
	EnvironmentService.setupAtmosphereAndSky()
	EnvironmentService.constructBackgroundVistas()
	print("[EnvironmentService] Initialized.")
end

return EnvironmentService
