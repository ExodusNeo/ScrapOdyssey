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

-- Zone centers laid out along the X axis
local ZONE_SPAWN_OFFSETS = {
	Vector3.new(0, 0, 0),         -- Zone 1: Rusty Outpost
	Vector3.new(120, 0, 0),       -- Zone 2: Automotive Graveyard
	Vector3.new(240, 0, 0),       -- Zone 3: Industrial Foundry
	Vector3.new(360, 0, 0),       -- Zone 4: Cybernetic Wasteland
	Vector3.new(480, 0, 0),       -- Zone 5: Orbital Crashsite
}

-- 1. AAA Lighting Setup
function ZoneService.setupLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.Brightness = 2.4
	Lighting.ClockTime = 16.8 -- Cinematic Golden Hour / Twilight
	Lighting.GeographicLatitude = 42
	Lighting.OutdoorAmbient = Color3.fromRGB(65, 70, 85)
	Lighting.Ambient = Color3.fromRGB(40, 45, 55)
	Lighting.ShadowSoftness = 0.2

	-- Clear old post-processing effects
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	-- Atmosphere
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(195, 185, 205)
	atmosphere.Decay = Color3.fromRGB(140, 95, 130)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 0.8
	atmosphere.Parent = Lighting

	-- Bloom
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.65
	bloom.Size = 24
	bloom.Threshold = 1.15
	bloom.Parent = Lighting

	-- ColorCorrection
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.14
	cc.Saturation = 0.22
	cc.TintColor = Color3.fromRGB(255, 248, 242)
	cc.Parent = Lighting

	-- SunRays
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.15
	sunRays.Spread = 0.85
	sunRays.Parent = Lighting

	-- Skybox
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 15
	sky.MoonAngularSize = 10
	sky.Parent = Lighting

	print("[ZoneService] High-fidelity lighting and post-processing configured.")
end

-- 2. Create High-Detail Themed Scrap Pile
local function createDetailedScrapPile(zone: Types.ZoneConfig, position: Vector3, index: number): Model
	local model = Instance.new("Model")
	model.Name = string.format("ScrapPile_%d_%d", zone.Id, index)

	local root = Instance.new("Part")
	root.Name = "Hitbox"
	root.Size = Vector3.new(7, 5, 7)
	root.Position = position + Vector3.new(0, 2.5, 0)
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Parent = model

	-- Main chassis / central engine block
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5.5, 3, 5.5)
	base.Position = position + Vector3.new(0, 1.5, 0)
	base.Anchored = true
	base.Color = zone.Color
	base.Material = Enum.Material.CorrodedMetal
	base.Parent = model

	-- Protruding industrial pipes
	local pipe1 = Instance.new("Part")
	pipe1.Shape = Enum.PartType.Cylinder
	pipe1.Size = Vector3.new(6, 1.2, 1.2)
	pipe1.Position = position + Vector3.new(0, 2.8, 1)
	pipe1.Orientation = Vector3.new(0, 45, 75)
	pipe1.Anchored = true
	pipe1.Color = Color3.fromRGB(90, 85, 80)
	pipe1.Material = Enum.Material.Metal
	pipe1.Parent = model

	local pipe2 = Instance.new("Part")
	pipe2.Shape = Enum.PartType.Cylinder
	pipe2.Size = Vector3.new(5, 1, 1)
	pipe2.Position = position + Vector3.new(-1.2, 2.6, -1.2)
	pipe2.Orientation = Vector3.new(20, -30, 80)
	pipe2.Anchored = true
	pipe2.Color = Color3.fromRGB(110, 100, 95)
	pipe2.Material = Enum.Material.Metal
	pipe2.Parent = model

	-- Glowing Power Core / Neon Relic in center
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.8, 1.8, 1.8)
	core.Position = position + Vector3.new(0, 3.8, 0)
	core.Anchored = true
	core.Color = zone.Color
	core.Material = Enum.Material.Neon
	core.Parent = model

	-- Core PointLight for ambient glow
	local light = Instance.new("PointLight")
	light.Color = zone.Color
	light.Brightness = 2.5
	light.Range = 14
	light.Parent = core

	-- Particle Emitter (Sparkling embers)
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Sparks"
	particles.Color = ColorSequence.new(zone.Color, Color3.fromRGB(255, 255, 255))
	particles.Size = NumberSequence.new(0.2, 0.05)
	particles.Rate = 12
	particles.Lifetime = NumberRange.new(0.8, 1.6)
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Acceleration = Vector3.new(0, 4, 0)
	particles.Parent = core

	-- Billboard Gui showing status
	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoGui"
	gui.Size = UDim2.new(0, 150, 0, 45)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = root

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(1, 0, 1, 0)
	badge.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
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
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 14
	label.Text = string.format("🔨 %s\n(+%d Scrap)", zone.Name:upper(), zone.BaseYield)
	label.Parent = badge

	-- ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScrapPrompt"
	prompt.ObjectText = zone.Name
	prompt.ActionText = "Dismantle (E)"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	model:SetAttribute("ZoneId", zone.Id)
	model:SetAttribute("BaseYield", zone.BaseYield)
	model:SetAttribute("ActionTime", zone.ActionTime)

	return model
end

-- 3. Construct Detailed Zone Environments with Props & Lighting
function ZoneService.constructZonePlatform(zone: Types.ZoneConfig, centerPos: Vector3)
	local folder = Workspace:FindFirstChild("Zone_" .. tostring(zone.Id)) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Zone_" .. tostring(zone.Id)
		folder.Parent = Workspace
	end

	-- Clear old parts
	for _, c in ipairs(folder:GetChildren()) do
		c:Destroy()
	end

	-- Main Foundation Platform
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(84, 3, 84)
	platform.Position = centerPos - Vector3.new(0, 1.5, 0)
	platform.Anchored = true
	platform.Material = Enum.Material.DiamondPlate
	platform.Color = Color3.fromRGB(45, 48, 55)
	platform.Parent = folder

	-- Glowing Edge Trims
	local trimNorth = Instance.new("Part")
	trimNorth.Size = Vector3.new(84, 0.6, 1.5)
	trimNorth.Position = centerPos + Vector3.new(0, 0.2, -42)
	trimNorth.Anchored = true
	trimNorth.Material = Enum.Material.Neon
	trimNorth.Color = zone.Color
	trimNorth.Parent = folder

	local trimSouth = trimNorth:Clone()
	trimSouth.Position = centerPos + Vector3.new(0, 0.2, 42)
	trimSouth.Parent = folder

	local trimEast = Instance.new("Part")
	trimEast.Size = Vector3.new(1.5, 0.6, 84)
	trimEast.Position = centerPos + Vector3.new(42, 0.2, 0)
	trimEast.Anchored = true
	trimEast.Material = Enum.Material.Neon
	trimEast.Color = zone.Color
	trimEast.Parent = folder

	local trimWest = trimEast:Clone()
	trimWest.Position = centerPos + Vector3.new(-42, 0.2, 0)
	trimWest.Parent = folder

	-- Cyber Streetlights on four corners
	local cornerOffsets = {
		Vector3.new(-38, 0, -38),
		Vector3.new(38, 0, -38),
		Vector3.new(-38, 0, 38),
		Vector3.new(38, 0, 38),
	}

	for _, cOffset in ipairs(cornerOffsets) do
		local pole = Instance.new("Part")
		pole.Name = "LightPole"
		pole.Size = Vector3.new(1.2, 14, 1.2)
		pole.Position = centerPos + cOffset + Vector3.new(0, 7, 0)
		pole.Anchored = true
		pole.Color = Color3.fromRGB(30, 32, 40)
		pole.Material = Enum.Material.Metal
		pole.Parent = folder

		local lamp = Instance.new("Part")
		lamp.Name = "LampHead"
		lamp.Size = Vector3.new(2.4, 1, 2.4)
		lamp.Position = centerPos + cOffset + Vector3.new(0, 14, 0)
		lamp.Anchored = true
		lamp.Color = zone.Color
		lamp.Material = Enum.Material.Neon
		lamp.Parent = folder

		local pLight = Instance.new("PointLight")
		pLight.Color = zone.Color
		pLight.Brightness = 2.0
		pLight.Range = 28
		pLight.Parent = lamp
	end

	-- Giant Themed Billboard Sign
	local signPost = Instance.new("Part")
	signPost.Name = "ZoneSign"
	signPost.Size = Vector3.new(24, 9, 1.5)
	signPost.Position = centerPos + Vector3.new(0, 12, -41)
	signPost.Anchored = true
	signPost.Material = Enum.Material.SmoothPlastic
	signPost.Color = Color3.fromRGB(18, 20, 26)
	signPost.Parent = folder

	local signBorder = Instance.new("Part")
	signBorder.Size = Vector3.new(24.6, 9.6, 1)
	signBorder.Position = centerPos + Vector3.new(0, 12, -41.3)
	signBorder.Anchored = true
	signBorder.Material = Enum.Material.Neon
	signBorder.Color = zone.Color
	signBorder.Parent = folder

	local sgui = Instance.new("SurfaceGui")
	sgui.Face = Enum.NormalId.Front
	sgui.Parent = signPost

	local titleBox = Instance.new("Frame")
	titleBox.Size = UDim2.new(1, 0, 1, 0)
	titleBox.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
	titleBox.Parent = sgui

	local signTitle = Instance.new("TextLabel")
	signTitle.Size = UDim2.new(1, -20, 0.55, 0)
	signTitle.Position = UDim2.new(0, 10, 0, 5)
	signTitle.BackgroundTransparency = 1
	signTitle.Font = Enum.Font.GothamBlack
	signTitle.TextSize = 48
	signTitle.TextColor3 = zone.Color
	signTitle.Text = string.format("ZONE %d: %s", zone.Id, zone.Name:upper())
	signTitle.Parent = titleBox

	local signDesc = Instance.new("TextLabel")
	signDesc.Size = UDim2.new(1, -20, 0.4, 0)
	signDesc.Position = UDim2.new(0, 10, 0.55, 0)
	signDesc.BackgroundTransparency = 1
	signDesc.Font = Enum.Font.GothamBold
	signDesc.TextSize = 24
	signDesc.TextColor3 = Color3.fromRGB(200, 210, 225)
	signDesc.Text = zone.Description
	signDesc.Parent = titleBox

	-- Spawn 4 Scrap Nodes with generous spacing
	local pilePositions = {
		Vector3.new(-20, 0, -18),
		Vector3.new(20, 0, -18),
		Vector3.new(-20, 0, 18),
		Vector3.new(20, 0, 18),
	}

	for i, offset in ipairs(pilePositions) do
		local pilePos = centerPos + offset
		local pile = createDetailedScrapPile(zone, pilePos, i)
		pile.Parent = folder
		table.insert(activeNodes, pile)
	end

	-- 4. Create Connecting Pathway & Barrier Gate to Next Zone
	if zone.Id < #Config.Zones then
		local nextZone = Config.Zones[zone.Id + 1]
		local gatePos = centerPos + Vector3.new(60, 0, 0)

		-- Pathway bridge
		local bridge = Instance.new("Part")
		bridge.Name = "Bridge"
		bridge.Size = Vector3.new(38, 2, 16)
		bridge.Position = gatePos - Vector3.new(0, 1, 0)
		bridge.Anchored = true
		bridge.Material = Enum.Material.DiamondPlate
		bridge.Color = Color3.fromRGB(35, 38, 45)
		bridge.Parent = folder

		-- Gate Model
		local gateModel = Instance.new("Model")
		gateModel.Name = "Gate_Zone_" .. tostring(nextZone.Id)

		-- Pillars
		local leftPillar = Instance.new("Part")
		leftPillar.Size = Vector3.new(3, 16, 3)
		leftPillar.Position = gatePos + Vector3.new(0, 8, -8)
		leftPillar.Anchored = true
		leftPillar.Material = Enum.Material.Metal
		leftPillar.Color = Color3.fromRGB(25, 28, 35)
		leftPillar.Parent = gateModel

		local rightPillar = leftPillar:Clone()
		rightPillar.Position = gatePos + Vector3.new(0, 8, 8)
		rightPillar.Parent = gateModel

		local crossbar = Instance.new("Part")
		crossbar.Size = Vector3.new(3, 3, 19)
		crossbar.Position = gatePos + Vector3.new(0, 16, 0)
		crossbar.Anchored = true
		crossbar.Material = Enum.Material.Metal
		crossbar.Color = Color3.fromRGB(25, 28, 35)
		crossbar.Parent = gateModel

		-- Forcefield Laser Barrier
		local barrier = Instance.new("Part")
		barrier.Name = "Forcefield"
		barrier.Size = Vector3.new(1.5, 14, 15)
		barrier.Position = gatePos + Vector3.new(0, 7, 0)
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.Transparency = 0.4
		barrier.Material = Enum.Material.ForceField
		barrier.Color = nextZone.Color
		barrier.Parent = gateModel

		-- Floating Holographic Unlock Prompt
		local promptPart = Instance.new("Part")
		promptPart.Name = "PromptPart"
		promptPart.Size = Vector3.new(4, 4, 4)
		promptPart.Position = gatePos + Vector3.new(-4, 4, 0)
		promptPart.Anchored = true
		promptPart.Transparency = 1
		promptPart.CanCollide = false
		promptPart.Parent = gateModel

		local gatePrompt = Instance.new("ProximityPrompt")
		gatePrompt.Name = "UnlockPrompt"
		gatePrompt.ObjectText = nextZone.Name
		gatePrompt.ActionText = string.format("Unlock Zone (%d Scrap)", nextZone.UnlockCost)
		gatePrompt.HoldDuration = 0.5
		gatePrompt.MaxActivationDistance = 14
		gatePrompt.RequiresLineOfSight = false
		gatePrompt.Parent = promptPart

		gatePrompt.Triggered:Connect(function(player)
			ZoneService.unlockZone(player, nextZone.Id)
		end)

		gateModel.Parent = folder
		zoneGates[nextZone.Id] = {
			Model = gateModel,
			Barrier = barrier,
			Prompt = gatePrompt,
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
		notif:FireClient(player, "Locked", "You must unlock previous zones first!", Color3.fromRGB(255, 70, 70))
		return false
	end

	local CurrencyService = require(script.Parent.CurrencyService)
	if CurrencyService.removeScrap(player, zone.UnlockCost) then
		data.MaxZoneReached = zoneId
		data.CurrentZone = zoneId
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "ZONE UNLOCKED!", string.format("Welcome to %s!", zone.Name), zone.Color)

		-- Lower forcefield barrier
		local gateInfo = zoneGates[zoneId]
		if gateInfo and gateInfo.Barrier then
			TweenService:Create(gateInfo.Barrier, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			gateInfo.Barrier.CanCollide = false
			gateInfo.Prompt.Enabled = false
		end

		return true
	else
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Need More Scrap", string.format("Unlocking %s costs %d Scrap.", zone.Name, zone.UnlockCost), Color3.fromRGB(255, 70, 70))
	end

	return false
end

function ZoneService.init()
	ZoneService.setupLighting()

	for i, zone in ipairs(Config.Zones) do
		local centerPos = ZONE_SPAWN_OFFSETS[i] or Vector3.new(i * 120, 0, 0)
		ZoneService.constructZonePlatform(zone, centerPos)
	end

	print("[ZoneService] Initialized high-detail zones, lighting, and interactive gates.")
end

return ZoneService
