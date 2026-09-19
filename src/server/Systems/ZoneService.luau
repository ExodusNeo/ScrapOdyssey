--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)

local ZoneService = {}
local activeNodes = {}
local zoneGates: { [number]: { Model: Model, Barrier: Part, Prompt: ProximityPrompt } } = {}

-- Safe zone center coordinates for each zone (Zone 1 is Central Hub)
local ZONE_CENTERS = {
	[1] = Vector3.new(0, 0, 0),
	[2] = Vector3.new(160, 0, 0),
	[3] = Vector3.new(320, 0, 0),
	[4] = Vector3.new(480, 0, 0),
	[5] = Vector3.new(640, 0, 0),
}

-- 1. Calm, Eye-Friendly Lighting Setup (Soft Daylight without harsh glare or eye-strain)
function ZoneService.setupLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.Brightness = 1.15
	Lighting.ClockTime = 14.5 -- Comfortable afternoon sunlight
	Lighting.GeographicLatitude = 30
	Lighting.OutdoorAmbient = Color3.fromRGB(85, 90, 100)
	Lighting.Ambient = Color3.fromRGB(70, 75, 85)
	Lighting.ShadowSoftness = 0.4

	-- Clear old post-processing effects
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.15
	atmosphere.Offset = 0.0
	atmosphere.Color = Color3.fromRGB(190, 200, 215)
	atmosphere.Decay = Color3.fromRGB(160, 170, 185)
	atmosphere.Glare = 0 -- NO sun glare piercing the camera
	atmosphere.Haze = 0 -- Clean, crisp air without blinding haze
	atmosphere.Parent = Lighting

	-- Extremely subtle bloom to prevent glowing eye-bleed
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.04
	bloom.Size = 8
	bloom.Threshold = 2.2
	bloom.Parent = Lighting

	-- Clean, natural color profile without oversaturated neons
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.0
	cc.Contrast = 0.04
	cc.Saturation = 0.02
	cc.TintColor = Color3.fromRGB(255, 255, 255)
	cc.Parent = Lighting

	-- Note: SunRaysEffect is intentionally omitted to eliminate blinding sun glare!

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 10
	sky.Parent = Lighting

	print("[ZoneService] Eye-friendly soft lighting configured.")
end

-- Helper to create a Fast-Travel Portal Pad on any platform
local function createPortalPad(parent: Instance, position: Vector3, zoneId: number)
	local pad = Instance.new("Part")
	pad.Name = "PortalPad_Zone" .. tostring(zoneId)
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.6, 7, 7)
	pad.Position = position
	pad.Orientation = Vector3.new(0, 0, 90)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(150, 90, 215)
	pad.Parent = parent

	local padRim = Instance.new("Part")
	padRim.Name = "Rim"
	padRim.Shape = Enum.PartType.Cylinder
	padRim.Size = Vector3.new(0.8, 7.8, 7.8)
	padRim.Position = position - Vector3.new(0, 0.1, 0)
	padRim.Orientation = Vector3.new(0, 0, 90)
	padRim.Anchored = true
	padRim.Material = Enum.Material.Metal
	padRim.Color = Color3.fromRGB(35, 38, 48)
	padRim.Parent = parent

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 45)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = pad

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(220, 160, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Text = "🗺️ FAST TRAVEL\n[Press E or Step Here]"
	lbl.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Fast Travel"
	prompt.ActionText = "Open Map"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local portalDebounces: { [Player]: number } = {}

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
end

-- 2. Helper to build an Industrial Scrap Recycler with furnace core, smokestacks, and green deposit pad
function ZoneService.constructRecycler(parent: Instance, basePos: Vector3, zoneId: number): Model
	local recyclerModel = Instance.new("Model")
	recyclerModel.Name = "ScrapRecycler_Zone" .. tostring(zoneId)

	local baseUnit = Instance.new("Part")
	baseUnit.Name = "BaseUnit"
	baseUnit.Size = Vector3.new(12, 8, 12)
	baseUnit.Position = basePos + Vector3.new(0, 4, 0)
	baseUnit.Anchored = true
	baseUnit.Material = Enum.Material.DiamondPlate
	baseUnit.Color = Color3.fromRGB(35, 38, 48)
	baseUnit.Parent = recyclerModel

	local furnaceWindow = Instance.new("Part")
	furnaceWindow.Name = "FurnaceCore"
	furnaceWindow.Size = Vector3.new(5, 3.5, 0.4)
	furnaceWindow.Position = basePos + Vector3.new(0, 3.2, 6.2)
	furnaceWindow.Anchored = true
	furnaceWindow.Material = Enum.Material.SmoothPlastic
	furnaceWindow.Color = Color3.fromRGB(225, 115, 30)
	furnaceWindow.Parent = recyclerModel

	local fLight = Instance.new("PointLight")
	fLight.Color = Color3.fromRGB(255, 130, 30)
	fLight.Brightness = 0.5
	fLight.Range = 8
	fLight.Parent = furnaceWindow

	local funnel = Instance.new("Part")
	funnel.Name = "Funnel"
	funnel.Shape = Enum.PartType.Cylinder
	funnel.Size = Vector3.new(3, 8.5, 8.5)
	funnel.Position = basePos + Vector3.new(0, 9.5, 0)
	funnel.Orientation = Vector3.new(0, 0, 90)
	funnel.Anchored = true
	funnel.Material = Enum.Material.Metal
	funnel.Color = Color3.fromRGB(55, 60, 70)
	funnel.Parent = recyclerModel

	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210))
	steam.Size = NumberSequence.new(1.5, 4.0)
	steam.Transparency = NumberSequence.new(0.3, 1.0)
	steam.Rate = 12
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Speed = NumberRange.new(4, 7)
	steam.SpreadAngle = Vector2.new(20, 20)
	steam.Acceleration = Vector3.new(0, 3, 0)
	steam.Parent = funnel

	-- Smokestacks
	local stackCoords = { basePos + Vector3.new(-5.2, 8, 0), basePos + Vector3.new(5.2, 8, 0) }
	for _, sPos in ipairs(stackCoords) do
		local stack = Instance.new("Part")
		stack.Name = "Smokestack"
		stack.Shape = Enum.PartType.Cylinder
		stack.Size = Vector3.new(10, 1.8, 1.8)
		stack.Position = sPos
		stack.Orientation = Vector3.new(0, 0, 90)
		stack.Anchored = true
		stack.Material = Enum.Material.Metal
		stack.Color = Color3.fromRGB(25, 27, 34)
		stack.Parent = recyclerModel
	end

	-- Recycler Billboard
	local rbb = Instance.new("BillboardGui")
	rbb.Size = UDim2.new(0, 260, 0, 60)
	rbb.StudsOffset = Vector3.new(0, 7.5, 0)
	rbb.AlwaysOnTop = true
	rbb.Parent = baseUnit

	local rTitle = Instance.new("TextLabel")
	rTitle.Size = UDim2.new(1, 0, 1, 0)
	rTitle.BackgroundTransparency = 1
	rTitle.Font = Enum.Font.GothamBlack
	rTitle.TextSize = 22
	rTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	rTitle.TextStrokeTransparency = 0.2
	rTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
	rTitle.Text = string.format("⚙️ SCRAP RECYCLER %s⚙️\n[DEPOSIT & SELL CARGO]", zoneId > 1 and ("(Z" .. tostring(zoneId) .. ") ") or "")
	rTitle.Parent = rbb

	-- Deposit Sell Pad
	local depositPad = Instance.new("Part")
	depositPad.Name = "RecyclerDepositPad"
	depositPad.Size = Vector3.new(14, 0.4, 10)
	depositPad.Position = basePos + Vector3.new(0, 0.2, 7)
	depositPad.Anchored = true
	depositPad.CanCollide = true
	depositPad.Material = Enum.Material.SmoothPlastic
	depositPad.Color = Color3.fromRGB(45, 165, 95)
	depositPad.Parent = recyclerModel

	local depositPrompt = Instance.new("ProximityPrompt")
	depositPrompt.Name = "RecyclePrompt"
	depositPrompt.ObjectText = "Scrap Recycler"
	depositPrompt.ActionText = "Sell Cargo"
	depositPrompt.HoldDuration = 0.1
	depositPrompt.MaxActivationDistance = 14
	depositPrompt.RequiresLineOfSight = false
	depositPrompt.Parent = depositPad

	depositPrompt.Triggered:Connect(function(player)
		local CurrencyService = require(script.Parent.CurrencyService)
		CurrencyService.recycleBackpack(player)
	end)

	local sellDebounce: { [Player]: number } = {}
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
		-- Silently ignore if cargo is already 0, so walking across doesn't spam "Cargo Empty" notifications!
		if not data or (data.Backpack or 0) <= 0 then
			return
		end

		local CurrencyService = require(script.Parent.CurrencyService)
		CurrencyService.recycleBackpack(player)
	end)

	recyclerModel.Parent = parent
	return recyclerModel
end

-- 3. Build the Central Town Hub (Plaza, Pedestals, Recycler Machine, Props)
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

	-- Main Plaza Floor: 100 x 4 x 100 centered at (0, -2, 0) -> X spans -50 to +50
	local plaza = Instance.new("Part")
	plaza.Name = "PlazaGround"
	plaza.Size = Vector3.new(100, 4, 100)
	plaza.Position = Vector3.new(0, -2, 0)
	plaza.Anchored = true
	plaza.Material = Enum.Material.Concrete
	plaza.Color = Color3.fromRGB(50, 53, 62)
	plaza.Parent = hubFolder

	-- Beveled Decorative Curbs
	local curbThickness = 3
	local curbHeight = 0.6
	local curbNorth = Instance.new("Part")
	curbNorth.Name = "CurbN"
	curbNorth.Size = Vector3.new(100, curbHeight, curbThickness)
	curbNorth.Position = Vector3.new(0, 0.3, -48.5)
	curbNorth.Anchored = true
	curbNorth.Material = Enum.Material.SmoothPlastic
	curbNorth.Color = Color3.fromRGB(255, 170, 0)
	curbNorth.Parent = hubFolder

	local curbSouth = curbNorth:Clone()
	curbSouth.Position = Vector3.new(0, 0.3, 48.5)
	curbSouth.Parent = hubFolder

	local curbWest = Instance.new("Part")
	curbWest.Name = "CurbW"
	curbWest.Size = Vector3.new(curbThickness, curbHeight, 100)
	curbWest.Position = Vector3.new(-48.5, 0.3, 0)
	curbWest.Anchored = true
	curbWest.Material = Enum.Material.SmoothPlastic
	curbWest.Color = Color3.fromRGB(255, 170, 0)
	curbWest.Parent = hubFolder

	-- East edge opening curb segments (Bridge connects at X = 50, width = 22)
	local curbEastNorth = Instance.new("Part")
	curbEastNorth.Size = Vector3.new(curbThickness, curbHeight, 39)
	curbEastNorth.Position = Vector3.new(48.5, 0.3, -30.5)
	curbEastNorth.Anchored = true
	curbEastNorth.Material = Enum.Material.SmoothPlastic
	curbEastNorth.Color = Color3.fromRGB(255, 170, 0)
	curbEastNorth.Parent = hubFolder

	local curbEastSouth = curbEastNorth:Clone()
	curbEastSouth.Position = Vector3.new(48.5, 0.3, 30.5)
	curbEastSouth.Parent = hubFolder

	-- Spawn Location in Plaza Center
	local spawn = Workspace:FindFirstChild("SpawnLocation") :: SpawnLocation
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(12, 0.5, 12)
	spawn.Position = Vector3.new(0, 0.25, 15)
	spawn.Anchored = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(45, 115, 195)
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then decal:Destroy() end

	-- Scrap Recycler Machine & Sell Pad
	ZoneService.constructRecycler(hubFolder, Vector3.new(0, 0, -15), 1)

	-- Drone Incubator Pedestals
	local eggConfigs = {
		{
			Type = "RustEgg",
			Name = "Rust Egg",
			Cost = 250,
			Pos = Vector3.new(-18, 0.4, 0),
			Color = Color3.fromRGB(160, 130, 110),
			SubText = "Rust Bot (65%)\nSpark Drone (35%)",
		},
		{
			Type = "PlasmaEgg",
			Name = "Plasma Egg",
			Cost = 1500,
			Pos = Vector3.new(-24, 0.4, 0),
			Color = Color3.fromRGB(50, 150, 255),
			SubText = "Plasma Welder (70%)\nScrap Hound (30%)",
		},
		{
			Type = "CyberEgg",
			Name = "Cyber Egg",
			Cost = 10000,
			Pos = Vector3.new(-30, 0.4, 0),
			Color = Color3.fromRGB(255, 40, 100),
			SubText = "Cyber Mech (85%)\nVoid Titan (15%)",
		},
	}

	for _, eggInfo in ipairs(eggConfigs) do
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal_" .. eggInfo.Type
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = Vector3.new(2.4, 3.8, 3.8)
		pedestal.Position = eggInfo.Pos + Vector3.new(0, 1.2, 0)
		pedestal.Orientation = Vector3.new(0, 0, 90)
		pedestal.Anchored = true
		pedestal.Material = Enum.Material.DiamondPlate
		pedestal.Color = Color3.fromRGB(28, 30, 38)
		pedestal.Parent = hubFolder

		local capsule = Instance.new("Part")
		capsule.Name = "Capsule"
		capsule.Shape = Enum.PartType.Cylinder
		capsule.Size = Vector3.new(3.8, 3.4, 3.4)
		capsule.Position = eggInfo.Pos + Vector3.new(0, 4.3, 0)
		capsule.Orientation = Vector3.new(0, 0, 90)
		capsule.Anchored = true
		capsule.Material = Enum.Material.Glass
		capsule.Color = eggInfo.Color
		capsule.Transparency = 0.55
		capsule.CanCollide = false
		capsule.Parent = hubFolder

		local egg = Instance.new("Part")
		egg.Name = "DisplayEgg_" .. eggInfo.Type
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(2.0, 2.8, 2.0)
		egg.Position = eggInfo.Pos + Vector3.new(0, 4.3, 0)
		egg.Anchored = true
		egg.CanCollide = false
		egg.Material = Enum.Material.SmoothPlastic
		egg.Color = eggInfo.Color
		egg.Parent = hubFolder

		local baseEggY = eggInfo.Pos.Y + 4.3
		task.spawn(function()
			while egg.Parent do
				local t = os.clock() * 2
				egg.Position = Vector3.new(eggInfo.Pos.X, baseEggY + math.sin(t) * 0.25, eggInfo.Pos.Z)
				egg.CFrame = CFrame.new(egg.Position) * CFrame.Angles(0, math.rad(t * 30 % 360), 0)
				task.wait(0.04)
			end
		end)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ObjectText = eggInfo.Name
		prompt.ActionText = string.format("Hatch (%d 🔩)", eggInfo.Cost)
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = capsule

		prompt.Triggered:Connect(function(player)
			local PetService = require(script.Parent.PetService)
			PetService.hatchEgg(player, eggInfo.Type)
		end)
	end

	-- Fast-Travel Portal Pad in Hub
	createPortalPad(hubFolder, Vector3.new(-18, 0.3, 25), 1)

	-- 4 Scrap Nodes in Hub (Zone 1)
	local zone1Offsets = {
		Vector3.new(22, 0, -25),
		Vector3.new(38, 0, -25),
		Vector3.new(22, 0, 25),
		Vector3.new(38, 0, 25),
	}
	for i, off in ipairs(zone1Offsets) do
		local pile = ZoneService.createScrapPile(Config.Zones[1], off, i)
		pile.Parent = hubFolder
		table.insert(activeNodes, pile)
	end

	-- Thematic Environmental Sci-Fi Props for Zone 1 (Rusty Outpost)
	ZoneService.buildZone1Props(hubFolder, Vector3.new(0, 0, 0))
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

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(6.0, 2.8, 6.0)
	base.Position = position + Vector3.new(0, 1.4, 0)
	base.Anchored = true
	base.Color = zone.Color
	base.Material = Enum.Material.CorrodedMetal
	base.Parent = model

	local pipe = Instance.new("Part")
	pipe.Name = "Pipe"
	pipe.Shape = Enum.PartType.Cylinder
	pipe.Size = Vector3.new(5.5, 1.2, 1.2)
	pipe.Position = position + Vector3.new(0.5, 2.6, 0.5)
	pipe.Orientation = Vector3.new(15, 45, 65)
	pipe.Anchored = true
	pipe.Color = Color3.fromRGB(80, 75, 70)
	pipe.Material = Enum.Material.Metal
	pipe.Parent = model

	local barrel = Instance.new("Part")
	barrel.Name = "SalvageBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(2.4, 1.5, 1.5)
	barrel.Position = position + Vector3.new(-1.6, 1.2, 1.4)
	barrel.Orientation = Vector3.new(20, 10, 80)
	barrel.Anchored = true
	barrel.Color = Color3.fromRGB(130, 45, 40)
	barrel.Material = Enum.Material.Metal
	barrel.Parent = model

	local girder = Instance.new("Part")
	girder.Name = "SteelGirder"
	girder.Size = Vector3.new(1.0, 5.0, 1.0)
	girder.Position = position + Vector3.new(1.4, 2.5, -1.2)
	girder.Orientation = Vector3.new(35, 25, -20)
	girder.Anchored = true
	girder.Color = Color3.fromRGB(55, 60, 70)
	girder.Material = Enum.Material.DiamondPlate
	girder.Parent = model

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.8, 1.8, 1.8)
	core.Position = position + Vector3.new(0, 3.4, 0)
	core.Anchored = true
	core.Color = zone.Color
	core.Material = Enum.Material.SmoothPlastic
	core.Parent = model

	local light = Instance.new("PointLight")
	light.Color = zone.Color
	light.Brightness = 0.4
	light.Range = 6
	light.Parent = core

	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoGui"
	gui.Size = UDim2.new(0, 140, 0, 45)
	gui.StudsOffset = Vector3.new(0, 4.8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = root

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(1, 0, 1, 0)
	badge.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	badge.BackgroundTransparency = 0.2
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
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 13
	label.Text = string.format("🔨 %s\n[HP: 3/3]", zone.Name:upper())
	label.Parent = badge

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScrapPrompt"
	prompt.ObjectText = zone.Name
	prompt.ActionText = "Strike Scrap (E)"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	model:SetAttribute("ZoneId", zone.Id)
	model:SetAttribute("BaseYield", zone.BaseYield)
	model:SetAttribute("MaxHP", 3)
	model:SetAttribute("CurrentHP", 3)

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

-- Zone 1: Rusty Outpost Props (Industrial Salvage Crane, Cargo Shipping Containers, Fuel Silo, Rusted Drums)
function ZoneService.buildZone1Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone1"
	props.Parent = folder

	-- 1. Heavy Shipping Container A (North-West, Angled)
	local c1Pos = center + Vector3.new(-36, 4, -36)
	local c1Rot = CFrame.Angles(0, math.rad(18), 0)
	createPropPart(props, "ShippingContainer_A", Vector3.new(12, 8, 20), CFrame.new(c1Pos) * c1Rot, Color3.fromRGB(145, 75, 42), Enum.Material.CorrodedMetal)
	createPropPart(props, "ContA_Rib1", Vector3.new(12.4, 8.2, 1), CFrame.new(c1Pos + c1Rot * Vector3.new(0, 0, -9.5)) * c1Rot, Color3.fromRGB(50, 45, 45), Enum.Material.Metal)
	createPropPart(props, "ContA_Rib2", Vector3.new(12.4, 8.2, 1), CFrame.new(c1Pos + c1Rot * Vector3.new(0, 0, 9.5)) * c1Rot, Color3.fromRGB(50, 45, 45), Enum.Material.Metal)

	-- 2. Heavy Shipping Container B (North-East, Weathered Industrial Olive)
	local c2Pos = center + Vector3.new(36, 4, -36)
	local c2Rot = CFrame.Angles(0, math.rad(-15), 0)
	createPropPart(props, "ShippingContainer_B", Vector3.new(12, 8, 20), CFrame.new(c2Pos) * c2Rot, Color3.fromRGB(80, 95, 75), Enum.Material.Metal)
	createPropPart(props, "ContB_Rib1", Vector3.new(12.4, 8.2, 1), CFrame.new(c2Pos + c2Rot * Vector3.new(0, 0, -9.5)) * c2Rot, Color3.fromRGB(45, 50, 45), Enum.Material.Metal)
	createPropPart(props, "ContB_Rib2", Vector3.new(12.4, 8.2, 1), CFrame.new(c2Pos + c2Rot * Vector3.new(0, 0, 9.5)) * c2Rot, Color3.fromRGB(45, 50, 45), Enum.Material.Metal)

	-- 3. Heavy Industrial Salvage Crane (South-West)
	local cranePos = center + Vector3.new(-38, 0, 36)
	createPropPart(props, "CraneBase", Vector3.new(8, 2, 8), CFrame.new(cranePos + Vector3.new(0, 1, 0)), Color3.fromRGB(40, 42, 48), Enum.Material.Concrete)
	createPropPart(props, "CraneMast", Vector3.new(3.5, 26, 3.5), CFrame.new(cranePos + Vector3.new(0, 14, 0)), Color3.fromRGB(215, 145, 30), Enum.Material.Metal)
	createPropPart(props, "CraneBoom", Vector3.new(3, 3, 24), CFrame.new(cranePos + Vector3.new(0, 26, -5)), Color3.fromRGB(215, 145, 30), Enum.Material.Metal)
	createPropPart(props, "CraneCounterweight", Vector3.new(5, 4, 6), CFrame.new(cranePos + Vector3.new(0, 26, 10)), Color3.fromRGB(55, 55, 60), Enum.Material.Concrete)
	createPropPart(props, "CraneCable", Vector3.new(0.3, 10, 0.3), CFrame.new(cranePos + Vector3.new(0, 19, -12)), Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
	createPropPart(props, "CraneMagnet", Vector3.new(1.8, 6, 6), CFrame.new(cranePos + Vector3.new(0, 14, -12)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(65, 65, 75), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- 4. Rusted Coolant Silo (South-East)
	local siloPos = center + Vector3.new(38, 0, 36)
	createPropPart(props, "SiloBody", Vector3.new(18, 7.5, 7.5), CFrame.new(siloPos + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 85, 50), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	createPropPart(props, "SiloDome", Vector3.new(7.5, 5, 7.5), CFrame.new(siloPos + Vector3.new(0, 19, 0)), Color3.fromRGB(130, 75, 45), Enum.Material.Metal, Enum.PartType.Ball)
	createPropPart(props, "SiloCatwalk", Vector3.new(1, 9, 9), CFrame.new(siloPos + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- 5. Rusted Oil Drum Clusters (Base resting on ground at Y = 1.4, stacked drum at Y = 4.2)
	local drumOffsets = {
		Vector3.new(-28, 1.4, -36),
		Vector3.new(-26, 1.4, -34),
		Vector3.new(-27, 4.2, -35),
		Vector3.new(28, 1.4, -36),
		Vector3.new(26, 1.4, -34),
	}
	for i, dOff in ipairs(drumOffsets) do
		createPropPart(props, "Drum_" .. i, Vector3.new(2.8, 1.8, 1.8), CFrame.new(center + dOff) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(125, 65, 40), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	end
end

-- Zone 2: Automotive Graveyard Props (Hydraulic Car-Crusher, Crushed Cyber-Car Stacks, Giant Tire Pyramids, Generator Block)
function ZoneService.buildZone2Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone2"
	props.Parent = folder

	-- 1. Heavy Hydraulic Car-Crusher Press (North Center Behind Recycler)
	local crusherPos = center + Vector3.new(0, 0, -44)
	createPropPart(props, "CrusherCol1", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(-9, 9, -3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherCol2", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(9, 9, -3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherCol3", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(-9, 9, 3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherCol4", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(9, 9, 3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherTop", Vector3.new(22, 3.5, 8), CFrame.new(crusherPos + Vector3.new(0, 18, 0)), Color3.fromRGB(45, 55, 65), Enum.Material.Metal)
	createPropPart(props, "PistonL", Vector3.new(10, 1.8, 1.8), CFrame.new(crusherPos + Vector3.new(-4.5, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 190, 205), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "PistonR", Vector3.new(10, 1.8, 1.8), CFrame.new(crusherPos + Vector3.new(4.5, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 190, 205), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "CrushRam", Vector3.new(17, 2, 6.5), CFrame.new(crusherPos + Vector3.new(0, 7, 0)), Color3.fromRGB(100, 115, 130), Enum.Material.Metal)

	-- 2. Crushed Cyber-Car Stack (North-West Corner - Flush Contact)
	local carPos1 = center + Vector3.new(-38, 0, -32)
	createPropPart(props, "CarLower_1", Vector3.new(7.5, 2.2, 12), CFrame.new(carPos1 + Vector3.new(0, 1.1, 0)), Color3.fromRGB(60, 95, 120), Enum.Material.Metal)
	createPropPart(props, "CarLower_Windshield", Vector3.new(6.5, 1.0, 4), CFrame.new(carPos1 + Vector3.new(0, 2.7, -1)), Color3.fromRGB(20, 30, 40), Enum.Material.SmoothPlastic)
	local rotCar2 = CFrame.Angles(math.rad(6), math.rad(14), math.rad(-4))
	createPropPart(props, "CarUpper_1", Vector3.new(7, 2, 11), CFrame.new(carPos1 + Vector3.new(0.4, 2.9, 0)) * rotCar2, Color3.fromRGB(140, 50, 60), Enum.Material.Metal)

	-- 3. Crushed Cyber-Car Stack (North-East Corner - Flush Contact)
	local carPos2 = center + Vector3.new(38, 0, -32)
	local rotCar3 = CFrame.Angles(math.rad(-5), math.rad(-16), math.rad(6))
	createPropPart(props, "CarStack2_Base", Vector3.new(8, 2.2, 12), CFrame.new(carPos2 + Vector3.new(0, 1.1, 0)), Color3.fromRGB(160, 120, 40), Enum.Material.Metal)
	createPropPart(props, "CarStack2_Top", Vector3.new(7.2, 2.0, 10.5), CFrame.new(carPos2 + Vector3.new(-0.3, 2.9, 0)) * rotCar3, Color3.fromRGB(75, 80, 95), Enum.Material.Metal)

	-- 4. Giant Radial Tire Stacks (South-East & South-Center - Ground & Stack Flush)
	local tireClusters = {
		Vector3.new(38, 0, 34),
		Vector3.new(0, 0, 42),
	}
	for idx, tPos in ipairs(tireClusters) do
		createPropPart(props, "Tire1_" .. idx, Vector3.new(1.6, 5.0, 5.0), CFrame.new(center + tPos + Vector3.new(-2.6, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 26, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		createPropPart(props, "Tire2_" .. idx, Vector3.new(1.6, 5.0, 5.0), CFrame.new(center + tPos + Vector3.new(-2.6, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 26, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		createPropPart(props, "Tire3_" .. idx, Vector3.new(1.6, 5.0, 5.0), CFrame.new(center + tPos + Vector3.new(-2.6, 4.0, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 26, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		createPropPart(props, "Tire4_" .. idx, Vector3.new(1.6, 4.6, 4.6), CFrame.new(center + tPos + Vector3.new(2.4, 0.8, 0.5)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		createPropPart(props, "Tire5_" .. idx, Vector3.new(1.6, 4.6, 4.6), CFrame.new(center + tPos + Vector3.new(2.4, 2.4, 0.5)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

-- Zone 3: Industrial Foundry Props (Blast Smelting Chimneys, Molten Slag Crucible, Overhead Conveyor Truss, Ingot Stacks)
function ZoneService.buildZone3Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone3"
	props.Parent = folder

	-- 1. Twin Blast Smelting Chimney Kilns (North edge)
	local chimneyOffsets = { Vector3.new(-18, 0, -44), Vector3.new(18, 0, -44) }
	for idx, cOff in ipairs(chimneyOffsets) do
		local chPos = center + cOff
		createPropPart(props, "Chimney_" .. idx, Vector3.new(24, 7, 7), CFrame.new(chPos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(65, 48, 42), Enum.Material.Metal, Enum.PartType.Cylinder)
		createPropPart(props, "ChimneyRim_" .. idx, Vector3.new(2, 8.2, 8.2), CFrame.new(chPos + Vector3.new(0, 23.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(45, 35, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
		local hatch = createPropPart(props, "FurnaceHatch_" .. idx, Vector3.new(3.5, 3, 0.6), CFrame.new(chPos + Vector3.new(0, 2.5, 3.6)), Color3.fromRGB(245, 110, 20), Enum.Material.SmoothPlastic)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 30)
		light.Brightness = 0.4
		light.Range = 8
		light.Parent = hatch
	end

	-- 2. Molten Slag Crucible Cauldron (North-West)
	local crucPos = center + Vector3.new(-38, 0, -32)
	createPropPart(props, "CrucibleStandL", Vector3.new(1.8, 8, 1.8), CFrame.new(crucPos + Vector3.new(-4.5, 4, 0)), Color3.fromRGB(50, 48, 55), Enum.Material.Metal)
	createPropPart(props, "CrucibleStandR", Vector3.new(1.8, 8, 1.8), CFrame.new(crucPos + Vector3.new(4.5, 4, 0)), Color3.fromRGB(50, 48, 55), Enum.Material.Metal)
	createPropPart(props, "CruciblePot", Vector3.new(6, 6.5, 6.5), CFrame.new(crucPos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 38, 45), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "MoltenSlag", Vector3.new(0.5, 5.5, 5.5), CFrame.new(crucPos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 105, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 3. Overhead Conveyor Truss Span (South Border)
	local convPos = center + Vector3.new(0, 0, 42)
	createPropPart(props, "ConvTowerL", Vector3.new(2.5, 16, 2.5), CFrame.new(convPos + Vector3.new(-18, 8, 0)), Color3.fromRGB(180, 85, 25), Enum.Material.Metal)
	createPropPart(props, "ConvTowerR", Vector3.new(2.5, 16, 2.5), CFrame.new(convPos + Vector3.new(18, 8, 0)), Color3.fromRGB(180, 85, 25), Enum.Material.Metal)
	createPropPart(props, "ConvTrack", Vector3.new(38, 2.5, 3.5), CFrame.new(convPos + Vector3.new(0, 16, 0)), Color3.fromRGB(190, 95, 30), Enum.Material.Metal)

	-- 4. Titanium Ingot Pallet Stack (South-East - Perfectly Flush Resting)
	local palletPos = center + Vector3.new(38, 0, 32)
	createPropPart(props, "Pallet", Vector3.new(8, 0.8, 8), CFrame.new(palletPos + Vector3.new(0, 0.4, 0)), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
	for layer = 1, 3 do
		for bar = 1, 3 do
			local ingotY = 0.8 + ((layer - 0.5) * 0.8)
			createPropPart(props, "Ingot_" .. layer .. "_" .. bar, Vector3.new(7.2, 0.8, 1.8), CFrame.new(palletPos + Vector3.new(0, ingotY, (bar - 2) * 2.2)), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		end
	end
end

-- Zone 4: Cybernetic Wasteland Props (AI Server Mainframe Banks, Quantum Transmitter Tower, Data Consoles)
function ZoneService.buildZone4Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone4"
	props.Parent = folder

	-- 1. Twin Monolithic Server Mainframe Banks (North Border)
	local serverOffsets = { Vector3.new(-18, 0, -44), Vector3.new(18, 0, -44) }
	for idx, sOff in ipairs(serverOffsets) do
		local sPos = center + sOff
		createPropPart(props, "ServerFrame_" .. idx, Vector3.new(10, 14, 4), CFrame.new(sPos + Vector3.new(0, 7, 0)), Color3.fromRGB(28, 32, 42), Enum.Material.Metal)
		createPropPart(props, "ServerGlass_" .. idx, Vector3.new(9.2, 13, 0.4), CFrame.new(sPos + Vector3.new(0, 7, 2)), Color3.fromRGB(30, 200, 180), Enum.Material.Glass)
		for row = 1, 4 do
			createPropPart(props, "ServerBlade_" .. idx .. "_" .. row, Vector3.new(8.5, 0.5, 0.4), CFrame.new(sPos + Vector3.new(0, 2 + (row * 2.5), 1.9)), Color3.fromRGB(40, 190, 180), Enum.Material.SmoothPlastic)
		end
	end

	-- 2. Quantum Transmitter Tower Spire (South Border Center)
	local towerPos = center + Vector3.new(0, 0, 42)
	createPropPart(props, "TowerBase", Vector3.new(6, 2, 6), CFrame.new(towerPos + Vector3.new(0, 1, 0)), Color3.fromRGB(35, 40, 52), Enum.Material.Metal)
	createPropPart(props, "TowerSpire", Vector3.new(3, 26, 3), CFrame.new(towerPos + Vector3.new(0, 14, 0)), Color3.fromRGB(45, 55, 70), Enum.Material.Metal)
	createPropPart(props, "ArrayRing1", Vector3.new(0.6, 7.5, 7.5), CFrame.new(towerPos + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 210, 190), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	createPropPart(props, "ArrayRing2", Vector3.new(0.6, 5.5, 5.5), CFrame.new(towerPos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 210, 190), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 3. Slanted Data Consoles (North-West & North-East Corners)
	local consoleOffsets = { Vector3.new(-38, 0, -30), Vector3.new(38, 0, -30) }
	for idx, cOff in ipairs(consoleOffsets) do
		local cPos = center + cOff
		createPropPart(props, "ConsolePedestal_" .. idx, Vector3.new(5, 3.5, 3), CFrame.new(cPos + Vector3.new(0, 1.75, 0)), Color3.fromRGB(30, 35, 48), Enum.Material.Metal)
		local scrRot = CFrame.Angles(math.rad(-30), 0, 0)
		createPropPart(props, "ConsoleScreen_" .. idx, Vector3.new(4.5, 2.5, 0.4), CFrame.new(cPos + Vector3.new(0, 4.2, 0)) * scrRot, Color3.fromRGB(40, 220, 200), Enum.Material.SmoothPlastic)
	end
end

-- Zone 5: Orbital Crashsite Props (Fallen Starship Ion Thruster, Warp Core Housing, Armor Bulkhead, Void Crystals)
function ZoneService.buildZone5Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone5"
	props.Parent = folder

	-- 1. Massive Starship Ion Thruster Bell (North-West, 28 deg Impact Tilt)
	local thrustPos = center + Vector3.new(-22, 0, -40)
	local thrustRot = CFrame.Angles(math.rad(28), math.rad(15), 0)
	createPropPart(props, "ThrusterBell", Vector3.new(12, 11, 11), CFrame.new(thrustPos + Vector3.new(0, 6, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 36, 54), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "ThrusterRing", Vector3.new(2, 12.5, 12.5), CFrame.new(thrustPos + Vector3.new(0, 8.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 50, 75), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "ThrusterCore", Vector3.new(1, 8.5, 8.5), CFrame.new(thrustPos + Vector3.new(0, 4.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 50, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 2. Warp Drive Antimatter Containment Housing (North-East)
	local warpPos = center + Vector3.new(22, 0, -40)
	createPropPart(props, "WarpHousingBase", Vector3.new(8, 2, 8), CFrame.new(warpPos + Vector3.new(0, 1, 0)), Color3.fromRGB(38, 32, 48), Enum.Material.Metal)
	createPropPart(props, "WarpHousingTop", Vector3.new(8, 2, 8), CFrame.new(warpPos + Vector3.new(0, 10, 0)), Color3.fromRGB(38, 32, 48), Enum.Material.Metal)
	createPropPart(props, "WarpStrut1", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(-3, 5.5, -3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "WarpStrut2", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(3, 5.5, -3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "WarpStrut3", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(-3, 5.5, 3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "WarpStrut4", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(3, 5.5, 3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "SingularityCore", Vector3.new(4, 4, 4), CFrame.new(warpPos + Vector3.new(0, 5.5, 0)), Color3.fromRGB(175, 60, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)

	-- 3. Fractured Dreadnought Armor Bulkhead Slab (South Border)
	local slabPos = center + Vector3.new(0, 0, 42)
	local slabRot = CFrame.Angles(math.rad(-20), 0, math.rad(5))
	createPropPart(props, "HullArmorSlab", Vector3.new(28, 8, 2.5), CFrame.new(slabPos + Vector3.new(0, 4, 0)) * slabRot, Color3.fromRGB(48, 42, 60), Enum.Material.Metal)
	createPropPart(props, "HullArmorRib", Vector3.new(28.4, 1.5, 3.2), CFrame.new(slabPos + Vector3.new(0, 6, 0)) * slabRot, Color3.fromRGB(65, 55, 80), Enum.Material.Metal)

	-- 4. Alien Void Crystal Formations (North-West & South-East)
	local crystalClusters = {
		Vector3.new(-38, 0, -28),
		Vector3.new(38, 0, 32),
	}
	for idx, crOff in ipairs(crystalClusters) do
		local crPos = center + crOff
		createPropPart(props, "CrystalSpike1_" .. idx, Vector3.new(1.8, 8, 1.8), CFrame.new(crPos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(math.rad(15), 0, math.rad(-10)), Color3.fromRGB(160, 50, 240), Enum.Material.SmoothPlastic)
		createPropPart(props, "CrystalSpike2_" .. idx, Vector3.new(1.4, 5.5, 1.4), CFrame.new(crPos + Vector3.new(2, 2.5, 1)) * CFrame.Angles(math.rad(-12), math.rad(20), math.rad(15)), Color3.fromRGB(180, 70, 255), Enum.Material.SmoothPlastic)
		createPropPart(props, "CrystalSpike3_" .. idx, Vector3.new(1.2, 4, 1.2), CFrame.new(crPos + Vector3.new(-1.8, 1.8, -1)) * CFrame.Angles(math.rad(8), math.rad(-25), math.rad(-18)), Color3.fromRGB(140, 40, 220), Enum.Material.SmoothPlastic)
	end
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

	-- Solid Non-flickering Platform Floor: 100 x 4 x 100
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(100, 4, 100)
	platform.Position = centerPos - Vector3.new(0, 2, 0)
	platform.Anchored = true
	platform.Material = Enum.Material.Concrete
	platform.Color = Color3.fromRGB(42, 45, 54)
	platform.Parent = folder

	-- Elevated border trims (SmoothPlastic matte finish, no eye-straining glow)
	local trimN = Instance.new("Part")
	trimN.Size = Vector3.new(100, 0.6, 2)
	trimN.Position = centerPos + Vector3.new(0, 0.3, -49)
	trimN.Anchored = true
	trimN.Material = Enum.Material.SmoothPlastic
	trimN.Color = zone.Color
	trimN.Parent = folder

	local trimS = trimN:Clone()
	trimS.Position = centerPos + Vector3.new(0, 0.3, 49)
	trimS.Parent = folder

	-- West Curb Opening (Bridge from previous zone connects at X = centerPos.X - 50, width = 22)
	local curbWN = Instance.new("Part")
	curbWN.Size = Vector3.new(2, 0.6, 39)
	curbWN.Position = centerPos + Vector3.new(-49, 0.3, -30.5)
	curbWN.Anchored = true
	curbWN.Material = Enum.Material.SmoothPlastic
	curbWN.Color = zone.Color
	curbWN.Parent = folder

	local curbWS = curbWN:Clone()
	curbWS.Position = centerPos + Vector3.new(-49, 0.3, 30.5)
	curbWS.Parent = folder

	-- Zone Signboard (Elevated above the zone recycler)
	local sign = Instance.new("Part")
	sign.Name = "ZoneSign"
	sign.Size = Vector3.new(24, 8, 1.5)
	sign.Position = centerPos + Vector3.new(0, 13, -46)
	sign.Anchored = true
	sign.Color = Color3.fromRGB(18, 20, 28)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Parent = folder

	local sgui = Instance.new("SurfaceGui")
	sgui.Face = Enum.NormalId.Front
	sgui.Parent = sign

	local signBox = Instance.new("Frame")
	signBox.Size = UDim2.new(1, 0, 1, 0)
	signBox.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	signBox.Parent = sgui

	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, -20, 1, 0)
	signText.Position = UDim2.new(0, 10, 0, 0)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBlack
	signText.TextSize = 34
	signText.TextColor3 = zone.Color
	signText.Text = string.format("ZONE %d: %s\n%s", zone.Id, zone.Name:upper(), zone.Description)
	signText.Parent = signBox

	-- Scrap Recycler Machine & Deposit Sell Pad on this zone platform
	ZoneService.constructRecycler(folder, centerPos + Vector3.new(0, 0, -36), zone.Id)

	-- 4 Scrap Nodes per zone
	local offsets = {
		Vector3.new(-22, 0, -22),
		Vector3.new(22, 0, -22),
		Vector3.new(-22, 0, 22),
		Vector3.new(22, 0, 22),
	}

	for i, offset in ipairs(offsets) do
		local pile = ZoneService.createScrapPile(zone, centerPos + offset, i)
		pile.Parent = folder
		table.insert(activeNodes, pile)
	end

	-- Fast Travel Portal on this platform (Safely placed in the corner at (-38, 38) with >22 studs clearance from scrap nodes)
	createPortalPad(folder, centerPos + Vector3.new(-38, 0.3, 38), zone.Id)

	-- Thematic Environmental Sci-Fi Props for Zones 2 to 5
	if zone.Id == 2 then
		ZoneService.buildZone2Props(folder, centerPos)
	elseif zone.Id == 3 then
		ZoneService.buildZone3Props(folder, centerPos)
	elseif zone.Id == 4 then
		ZoneService.buildZone4Props(folder, centerPos)
	elseif zone.Id == 5 then
		ZoneService.buildZone5Props(folder, centerPos)
	end
end

-- 5. Construct Seamless Connecting Bridges with Solid Safety Guardrails
function ZoneService.constructBridge(zoneId: number)
	local fromCenter = ZONE_CENTERS[zoneId - 1]
	local toCenter = ZONE_CENTERS[zoneId]
	local targetZone = Config.Zones[zoneId]
	if not fromCenter or not toCenter or not targetZone then return end

	local bridgeX = (fromCenter.X + 50 + toCenter.X - 50) / 2 -- Exactly 80, 240, 400, 560
	local bridgeLength = (toCenter.X - 50) - (fromCenter.X + 50) -- Exactly 60 studs!
	local bridgeWidth = 22

	local bridgeFolder = Workspace:FindFirstChild("Bridges") :: Folder
	if not bridgeFolder then
		bridgeFolder = Instance.new("Folder")
		bridgeFolder.Name = "Bridges"
		bridgeFolder.Parent = Workspace
	end

	local oldBridge = bridgeFolder:FindFirstChild(string.format("Bridge_%d_to_%d", zoneId - 1, zoneId))
	if oldBridge then oldBridge:Destroy() end
	local oldGate = bridgeFolder:FindFirstChild("Gate_Zone" .. tostring(zoneId))
	if oldGate then oldGate:Destroy() end

	-- Solid Bridge Floor
	local bridge = Instance.new("Part")
	bridge.Name = string.format("Bridge_%d_to_%d", zoneId - 1, zoneId)
	bridge.Size = Vector3.new(bridgeLength, 4, bridgeWidth)
	bridge.Position = Vector3.new(bridgeX, -2, 0)
	bridge.Anchored = true
	bridge.Material = Enum.Material.DiamondPlate
	bridge.Color = Color3.fromRGB(36, 40, 50)
	bridge.Parent = bridgeFolder

	-- North Safety Guardrail (Prevents falling off!)
	local railN = Instance.new("Part")
	railN.Name = "GuardrailN"
	railN.Size = Vector3.new(bridgeLength, 3.5, 1.5)
	railN.Position = Vector3.new(bridgeX, 1.75, -(bridgeWidth / 2) + 0.75)
	railN.Anchored = true
	railN.Material = Enum.Material.Metal
	railN.Color = Color3.fromRGB(28, 30, 38)
	railN.Parent = bridgeFolder

	local neonStripN = Instance.new("Part")
	neonStripN.Size = Vector3.new(bridgeLength, 0.4, 0.4)
	neonStripN.Position = Vector3.new(bridgeX, 3.4, -(bridgeWidth / 2) + 0.75)
	neonStripN.Anchored = true
	neonStripN.Material = Enum.Material.SmoothPlastic
	neonStripN.Color = targetZone.Color
	neonStripN.Parent = bridgeFolder

	-- South Safety Guardrail (Prevents falling off!)
	local railS = Instance.new("Part")
	railS.Name = "GuardrailS"
	railS.Size = Vector3.new(bridgeLength, 3.5, 1.5)
	railS.Position = Vector3.new(bridgeX, 1.75, (bridgeWidth / 2) - 0.75)
	railS.Anchored = true
	railS.Material = Enum.Material.Metal
	railS.Color = Color3.fromRGB(28, 30, 38)
	railS.Parent = bridgeFolder

	local neonStripS = Instance.new("Part")
	neonStripS.Size = Vector3.new(bridgeLength, 0.4, 0.4)
	neonStripS.Position = Vector3.new(bridgeX, 3.4, (bridgeWidth / 2) - 0.75)
	neonStripS.Anchored = true
	neonStripS.Material = Enum.Material.SmoothPlastic
	neonStripS.Color = targetZone.Color
	neonStripS.Parent = bridgeFolder

	-- Grand Archway Forcefield Gate in Bridge Center
	local gateModel = Instance.new("Model")
	gateModel.Name = "Gate_Zone" .. tostring(zoneId)

	local pL = Instance.new("Part")
	pL.Size = Vector3.new(3, 16, 3)
	pL.Position = Vector3.new(bridgeX, 8, -(bridgeWidth / 2) + 1.5)
	pL.Anchored = true
	pL.Color = Color3.fromRGB(25, 28, 38)
	pL.Material = Enum.Material.Metal
	pL.Parent = gateModel

	local pR = pL:Clone()
	pR.Position = Vector3.new(bridgeX, 8, (bridgeWidth / 2) - 1.5)
	pR.Parent = gateModel

	local top = Instance.new("Part")
	top.Size = Vector3.new(3, 3, bridgeWidth)
	top.Position = Vector3.new(bridgeX, 16, 0)
	top.Anchored = true
	top.Color = Color3.fromRGB(25, 28, 38)
	top.Material = Enum.Material.Metal
	top.Parent = gateModel

	local barrier = Instance.new("Part")
	barrier.Name = "Forcefield"
	barrier.Size = Vector3.new(1.2, 14, bridgeWidth - 3)
	barrier.Position = Vector3.new(bridgeX, 7, 0)
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.Transparency = 0.35
	barrier.Material = Enum.Material.ForceField
	barrier.Color = targetZone.Color
	barrier.Parent = gateModel

	local promptPart = Instance.new("Part")
	promptPart.Size = Vector3.new(4, 4, 4)
	promptPart.Position = Vector3.new(bridgeX - 4, 3, 0)
	promptPart.Anchored = true
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.Parent = gateModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = targetZone.Name
	prompt.ActionText = string.format("Unlock Zone (%d Scrap)", targetZone.UnlockCost)
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
end

-- 6. Void Fall Protection (Catch falling players and safely teleport them)
function ZoneService.setupVoidProtection()
	local rescueFolder = Workspace:FindFirstChild("SafetyNet") :: Folder
	if not rescueFolder then
		rescueFolder = Instance.new("Folder")
		rescueFolder.Name = "SafetyNet"
		rescueFolder.Parent = Workspace
	end

	-- Massive trigger plate covering the entire game area at Y = -16
	local net = Instance.new("Part")
	net.Name = "VoidRescueTrigger"
	net.Size = Vector3.new(2400, 2, 800)
	net.Position = Vector3.new(350, -16, 0)
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
		local gate = zoneGates[zoneId]
		if gate and gate.Barrier then
			gate.Barrier.CanCollide = false
			gate.Barrier.Transparency = 1
			gate.Prompt.Enabled = false
		end
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

		local gate = zoneGates[zoneId]
		if gate and gate.Barrier then
			TweenService:Create(gate.Barrier, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			gate.Barrier.CanCollide = false
			gate.Prompt.Enabled = false
		end
		return true
	else
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Need More Scrap", string.format("Need %d Scrap to unlock %s.", zone.UnlockCost, zone.Name), Color3.fromRGB(255, 70, 70))
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
	if not root then return end

	-- Zone 0 or 1: Warp to Central Hub Recycler / Spawn
	if zoneId <= 1 then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(0, 3.5, 5) -- Right in front of Recycler
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "WARPED", "Welcome to Central Hub & Scrap Recycler!", Color3.fromRGB(40, 220, 120))
		return
	end

	local zone = Config.Zones[zoneId]
	if not zone then return end

	local maxZone = data.MaxZoneReached or 1
	if maxZone < zoneId then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Zone Locked", string.format("You haven't unlocked %s yet! (%d Scrap)", zone.Name, zone.UnlockCost), Color3.fromRGB(255, 70, 70))
		return
	end

	local targetCenter = ZONE_CENTERS[zoneId]
	if targetCenter then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(targetCenter + Vector3.new(0, 3.5, 0))
		data.CurrentZone = zoneId
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "WARPED", string.format("Warped to Zone %d: %s!", zone.Id, zone.Name), zone.Color)
	end
end

function ZoneService.init()
	ZoneService.setupLighting()

	-- Clean up old bridges and duplicate gates
	local oldBridges = Workspace:FindFirstChild("Bridges")
	if oldBridges then
		oldBridges:Destroy()
	end
	table.clear(zoneGates)

	ZoneService.constructCentralHub()

	-- Construct outer zones (Zone 2 to 5)
	for i = 2, #Config.Zones do
		local zone = Config.Zones[i]
		local centerPos = ZONE_CENTERS[i]
		ZoneService.constructZonePlatform(zone, centerPos)
		ZoneService.constructBridge(i)
	end

	-- Void fall safety net
	ZoneService.setupVoidProtection()

	-- Gate auto-open for players who already unlocked the zone
	Players.PlayerAdded:Connect(function(player)
		task.delay(1.5, function()
			if not player.Parent then return end
			local data = DataService.get(player)
			if data then
				local maxZ = data.MaxZoneReached or 1
				for z = 2, maxZ do
					local gate = zoneGates[z]
					if gate and gate.Barrier then
						gate.Barrier.CanCollide = false
						gate.Barrier.Transparency = 1
						gate.Prompt.Enabled = false
					end
				end
			end
		end)
	end)

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
	end

	print("[ZoneService] Polished Central Hub, Seamless Bridges, and Anti-Gravity Protection initialized.")
end

return ZoneService
