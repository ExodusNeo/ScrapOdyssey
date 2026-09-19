--!strict
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)

local ZoneService = {}
local activeNodes = {}
local zoneGates: { [number]: { Model: Model, Barrier: Part, Prompt: ProximityPrompt } } = {}

-- 1. AAA Lighting Setup (Warm Stylized Twilight)
function ZoneService.setupLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 16.5 -- Stylized Golden Twilight
	Lighting.GeographicLatitude = 40
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 75, 90)
	Lighting.Ambient = Color3.fromRGB(50, 55, 65)
	Lighting.ShadowSoftness = 0.25

	-- Clear old post-processing effects
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 190, 210)
	atmosphere.Decay = Color3.fromRGB(150, 110, 140)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.03
	cc.Contrast = 0.12
	cc.Saturation = 0.25
	cc.TintColor = Color3.fromRGB(255, 250, 245)
	cc.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.12
	sunRays.Spread = 0.8
	sunRays.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 10
	sky.Parent = Lighting

	print("[ZoneService] Polished lighting configured.")
end

-- 2. Build the Central Town Hub (Plaza, Pedestals, Recycler Machine, Props)
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

	-- Main Plaza Floor (Single solid piece to guarantee ZERO Z-fighting)
	local plaza = Instance.new("Part")
	plaza.Name = "PlazaGround"
	plaza.Size = Vector3.new(100, 4, 100)
	plaza.Position = Vector3.new(0, -2, 0)
	plaza.Anchored = true
	plaza.Material = Enum.Material.Concrete
	plaza.Color = Color3.fromRGB(50, 53, 62)
	plaza.Parent = hubFolder

	-- Beveled Decorative Curb (Raised to Y = 0.2 to prevent Z-fighting)
	local curbThickness = 3
	local curbHeight = 0.6
	local curbNorth = Instance.new("Part")
	curbNorth.Name = "CurbN"
	curbNorth.Size = Vector3.new(100, curbHeight, curbThickness)
	curbNorth.Position = Vector3.new(0, 0.3, -48.5)
	curbNorth.Anchored = true
	curbNorth.Material = Enum.Material.SmoothPlastic
	curbNorth.Color = Color3.fromRGB(255, 170, 0) -- Warm amber trim
	curbNorth.Parent = hubFolder

	local curbSouth = curbNorth:Clone()
	curbSouth.Position = Vector3.new(0, 0.3, 48.5)
	curbSouth.Parent = hubFolder

	local curbEast = Instance.new("Part")
	curbEast.Name = "CurbE"
	curbEast.Size = Vector3.new(curbThickness, curbHeight, 100)
	curbEast.Position = Vector3.new(48.5, 0.3, 0)
	curbEast.Anchored = true
	curbEast.Material = Enum.Material.SmoothPlastic
	curbEast.Color = Color3.fromRGB(255, 170, 0)
	curbEast.Parent = hubFolder

	local curbWest = curbEast:Clone()
	curbWest.Position = Vector3.new(-48.5, 0.3, 0)
	curbWest.Parent = hubFolder

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
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(40, 140, 255)
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then decal:Destroy() end

	-- In-World Scrap Recycler Machine (Centerpiece monument!)
	local recyclerModel = Instance.new("Model")
	recyclerModel.Name = "ScrapRecycler"

	local baseUnit = Instance.new("Part")
	baseUnit.Name = "BaseUnit"
	baseUnit.Size = Vector3.new(10, 8, 10)
	baseUnit.Position = Vector3.new(0, 4, -15)
	baseUnit.Anchored = true
	baseUnit.Material = Enum.Material.Metal
	baseUnit.Color = Color3.fromRGB(35, 38, 48)
	baseUnit.Parent = recyclerModel

	-- Glowing Funnel Top
	local funnel = Instance.new("Part")
	funnel.Name = "Funnel"
	funnel.Shape = Enum.PartType.Cylinder
	funnel.Size = Vector3.new(3, 8, 8)
	funnel.Position = Vector3.new(0, 9.5, -15)
	funnel.Orientation = Vector3.new(0, 0, 90)
	funnel.Anchored = true
	funnel.Material = Enum.Material.Neon
	funnel.Color = Color3.fromRGB(255, 180, 50)
	funnel.Parent = recyclerModel

	-- Smoke / Steam Particle Emitter from Recycler
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210))
	steam.Size = NumberSequence.new(1.5, 4.0)
	steam.Transparency = NumberSequence.new(0.3, 1.0)
	steam.Rate = 10
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Speed = NumberRange.new(4, 7)
	steam.SpreadAngle = Vector2.new(20, 20)
	steam.Acceleration = Vector3.new(0, 3, 0)
	steam.Parent = funnel

	-- Recycler Billboard Title
	local rbb = Instance.new("BillboardGui")
	rbb.Size = UDim2.new(0, 200, 0, 60)
	rbb.StudsOffset = Vector3.new(0, 7, 0)
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
	rTitle.Text = "⚙️ SCRAP RECYCLER ⚙️\n[DEPOSIT & UPGRADE]"
	rTitle.Parent = rbb

	recyclerModel.Parent = hubFolder

	-- Physical Drone Incubator Pedestals (Shop Eggs on Display!)
	local eggPositions = {
		Vector3.new(-18, 0.4, 0),
		Vector3.new(-24, 0.4, 0),
		Vector3.new(-30, 0.4, 0),
	}

	local eggTitles = { "Common Egg\n(250 🔩)", "Rare Egg\n(1.5K 🔩)", "Mythic Egg\n(10K 🔩)" }
	local eggColors = { Color3.fromRGB(160, 130, 110), Color3.fromRGB(50, 150, 255), Color3.fromRGB(255, 40, 100) }

	for i, pos in ipairs(eggPositions) do
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal_" .. tostring(i)
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = Vector3.new(2.5, 3.5, 3.5)
		pedestal.Position = pos + Vector3.new(0, 1.25, 0)
		pedestal.Orientation = Vector3.new(0, 0, 90)
		pedestal.Anchored = true
		pedestal.Material = Enum.Material.SmoothPlastic
		pedestal.Color = Color3.fromRGB(30, 32, 42)
		pedestal.Parent = hubFolder

		local egg = Instance.new("Part")
		egg.Name = "DisplayEgg"
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(2.2, 3.0, 2.2)
		egg.Position = pos + Vector3.new(0, 3.8, 0)
		egg.Anchored = true
		egg.Material = Enum.Material.Neon
		egg.Color = eggColors[i]
		egg.Parent = hubFolder

		local eggBb = Instance.new("BillboardGui")
		eggBb.Size = UDim2.new(0, 120, 0, 40)
		eggBb.StudsOffset = Vector3.new(0, 2.8, 0)
		eggBb.AlwaysOnTop = true
		eggBb.Parent = egg

		local eggLbl = Instance.new("TextLabel")
		eggLbl.Size = UDim2.new(1, 0, 1, 0)
		eggLbl.BackgroundTransparency = 1
		eggLbl.Font = Enum.Font.GothamBold
		eggLbl.TextSize = 14
		eggLbl.TextColor3 = eggColors[i]
		eggLbl.Text = eggTitles[i]
		eggLbl.Parent = eggBb

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ObjectText = "Drone Incubator"
		prompt.ActionText = "Hatch Egg (250 🔩)"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = egg

		prompt.Triggered:Connect(function(player)
			local PetService = require(script.Parent.PetService)
			PetService.hatchEgg(player)
		end)
	end

	-- Ambient Streetlights around the Plaza
	local lampCoords = {
		Vector3.new(-40, 0, -40),
		Vector3.new(40, 0, -40),
		Vector3.new(-40, 0, 40),
		Vector3.new(40, 0, 40),
	}

	for _, lCoord in ipairs(lampCoords) do
		local pole = Instance.new("Part")
		pole.Size = Vector3.new(1.2, 14, 1.2)
		pole.Position = lCoord + Vector3.new(0, 7, 0)
		pole.Anchored = true
		pole.Color = Color3.fromRGB(28, 30, 38)
		pole.Material = Enum.Material.Metal
		pole.Parent = hubFolder

		local head = Instance.new("Part")
		head.Size = Vector3.new(2.4, 1.2, 2.4)
		head.Position = lCoord + Vector3.new(0, 14, 0)
		head.Anchored = true
		head.Color = Color3.fromRGB(255, 200, 120)
		head.Material = Enum.Material.Neon
		head.Parent = hubFolder

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Brightness = 2.2
		light.Range = 30
		light.Parent = head
	end
end

-- 3. Create Multi-Part High Detail Scrap Nodes with Health
local function createScrapPile(zone: Types.ZoneConfig, position: Vector3, index: number): Model
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

	-- Main heavy scrap mound
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5.5, 2.8, 5.5)
	base.Position = position + Vector3.new(0, 1.4, 0)
	base.Anchored = true
	base.Color = zone.Color
	base.Material = Enum.Material.CorrodedMetal
	base.Parent = model

	-- Protruding Pipes
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

	-- Glowing Power Core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.8, 1.8, 1.8)
	core.Position = position + Vector3.new(0, 3.4, 0)
	core.Anchored = true
	core.Color = zone.Color
	core.Material = Enum.Material.Neon
	core.Parent = model

	local light = Instance.new("PointLight")
	light.Color = zone.Color
	light.Brightness = 2.0
	light.Range = 12
	light.Parent = core

	-- Hit Progress Billboard
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

	-- ProximityPrompt
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

-- 4. Construct Progressive Zones (Zones 2 to 5)
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

	-- Solid Non-flickering Platform Floor
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(84, 4, 84)
	platform.Position = centerPos - Vector3.new(0, 2, 0)
	platform.Anchored = true
	platform.Material = Enum.Material.Concrete
	platform.Color = Color3.fromRGB(42, 45, 54)
	platform.Parent = folder

	-- Elevated border trims (Y = 0.3)
	local trimN = Instance.new("Part")
	trimN.Size = Vector3.new(84, 0.6, 2)
	trimN.Position = centerPos + Vector3.new(0, 0.3, -41)
	trimN.Anchored = true
	trimN.Material = Enum.Material.Neon
	trimN.Color = zone.Color
	trimN.Parent = folder

	local trimS = trimN:Clone()
	trimS.Position = centerPos + Vector3.new(0, 0.3, 41)
	trimS.Parent = folder

	-- Zone Signboard
	local sign = Instance.new("Part")
	sign.Name = "ZoneSign"
	sign.Size = Vector3.new(22, 8, 1.5)
	sign.Position = centerPos + Vector3.new(0, 10, -40)
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
	signText.TextSize = 38
	signText.TextColor3 = zone.Color
	signText.Text = string.format("ZONE %d: %s\n%s", zone.Id, zone.Name:upper(), zone.Description)
	signText.Parent = signBox

	-- 4 Scrap Nodes per zone
	local offsets = {
		Vector3.new(-20, 0, -18),
		Vector3.new(20, 0, -18),
		Vector3.new(-20, 0, 18),
		Vector3.new(20, 0, 18),
	}

	for i, offset in ipairs(offsets) do
		local pile = createScrapPile(zone, centerPos + offset, i)
		pile.Parent = folder
		table.insert(activeNodes, pile)
	end

	-- Connecting Bridge and Forcefield Gate to next zone
	if zone.Id < #Config.Zones then
		local nextZone = Config.Zones[zone.Id + 1]
		local gatePos = centerPos + Vector3.new(58, 0, 0)

		local bridge = Instance.new("Part")
		bridge.Name = "Bridge"
		bridge.Size = Vector3.new(34, 4, 16)
		bridge.Position = gatePos - Vector3.new(0, 2, 0)
		bridge.Anchored = true
		bridge.Material = Enum.Material.DiamondPlate
		bridge.Color = Color3.fromRGB(36, 40, 50)
		bridge.Parent = folder

		local gateModel = Instance.new("Model")
		gateModel.Name = "Gate_" .. tostring(nextZone.Id)

		local pL = Instance.new("Part")
		pL.Size = Vector3.new(3, 14, 3)
		pL.Position = gatePos + Vector3.new(0, 7, -8)
		pL.Anchored = true
		pL.Color = Color3.fromRGB(25, 28, 38)
		pL.Material = Enum.Material.Metal
		pL.Parent = gateModel

		local pR = pL:Clone()
		pR.Position = gatePos + Vector3.new(0, 7, 8)
		pR.Parent = gateModel

		local top = Instance.new("Part")
		top.Size = Vector3.new(3, 3, 19)
		top.Position = gatePos + Vector3.new(0, 14, 0)
		top.Anchored = true
		top.Color = Color3.fromRGB(25, 28, 38)
		top.Material = Enum.Material.Metal
		top.Parent = gateModel

		local barrier = Instance.new("Part")
		barrier.Name = "Forcefield"
		barrier.Size = Vector3.new(1.2, 12, 15)
		barrier.Position = gatePos + Vector3.new(0, 6, 0)
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.Transparency = 0.35
		barrier.Material = Enum.Material.ForceField
		barrier.Color = nextZone.Color
		barrier.Parent = gateModel

		local promptPart = Instance.new("Part")
		promptPart.Size = Vector3.new(4, 4, 4)
		promptPart.Position = gatePos + Vector3.new(-4, 3, 0)
		promptPart.Anchored = true
		promptPart.Transparency = 1
		promptPart.CanCollide = false
		promptPart.Parent = gateModel

		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = nextZone.Name
		prompt.ActionText = string.format("Unlock Zone (%d Scrap)", nextZone.UnlockCost)
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 15
		prompt.Parent = promptPart

		prompt.Triggered:Connect(function(player)
			ZoneService.unlockZone(player, nextZone.Id)
		end)

		gateModel.Parent = folder
		zoneGates[nextZone.Id] = {
			Model = gateModel,
			Barrier = barrier,
			Prompt = prompt,
		}
	end
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

function ZoneService.init()
	ZoneService.setupLighting()
	ZoneService.constructCentralHub()

	-- Zone 1: Rusty Outpost (Spawn side)
	local zone1Offsets = {
		Vector3.new(20, 0, -25),
		Vector3.new(35, 0, -25),
		Vector3.new(20, 0, 25),
		Vector3.new(35, 0, 25),
	}
	local hub = Workspace:FindFirstChild("CentralHub")
	for i, off in ipairs(zone1Offsets) do
		local pile = createScrapPile(Config.Zones[1], off, i)
		pile.Parent = hub or Workspace
		table.insert(activeNodes, pile)
	end

	-- Construct outer zones (Zone 2 to 5)
	for i = 2, #Config.Zones do
		local zone = Config.Zones[i]
		local centerPos = Vector3.new(i * 95, 0, 0)
		ZoneService.constructZonePlatform(zone, centerPos)
	end

	print("[ZoneService] Polished Central Hub and Non-overlapping Zones initialized.")
end

return ZoneService
