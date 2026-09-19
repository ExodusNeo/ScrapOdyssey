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
