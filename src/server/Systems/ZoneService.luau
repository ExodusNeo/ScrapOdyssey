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

-- Helper to build an Industrial Sci-Fi Tool Armory & Forge Stand in Central Hub
function ZoneService.constructToolArmoryKiosk(parent: Instance, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ToolArmoryKiosk"

	-- Foundation Deck
	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(14, 0.4, 12)
	deck.Position = pos + Vector3.new(0, 0.2, 0)
	deck.Anchored = true
	deck.Material = Enum.Material.DiamondPlate
	deck.Color = Color3.fromRGB(30, 32, 40)
	deck.Parent = model

	-- Heavy Steel Workbench
	local bench = Instance.new("Part")
	bench.Name = "Workbench"
	bench.Size = Vector3.new(9, 3.2, 4)
	bench.Position = pos + Vector3.new(0, 1.8, -1.8)
	bench.Anchored = true
	bench.Material = Enum.Material.Metal
	bench.Color = Color3.fromRGB(45, 50, 62)
	bench.Parent = model

	-- Cyber Anvil
	local anvil = Instance.new("Part")
	anvil.Name = "Anvil"
	anvil.Size = Vector3.new(2.8, 1.8, 1.6)
	anvil.Position = pos + Vector3.new(-2.2, 3.8, -1.8)
	anvil.Anchored = true
	anvil.Material = Enum.Material.CorrodedMetal
	anvil.Color = Color3.fromRGB(210, 120, 35)
	anvil.Parent = model

	-- Floating Holographic Preview Tools on Table
	local holoWrench = Instance.new("Part")
	holoWrench.Name = "HoloTool"
	holoWrench.Size = Vector3.new(0.6, 2.4, 0.6)
	holoWrench.Position = pos + Vector3.new(1.8, 4.2, -1.8)
	holoWrench.Orientation = Vector3.new(25, 45, 15)
	holoWrench.Anchored = true
	holoWrench.CanCollide = false
	holoWrench.Material = Enum.Material.SmoothPlastic
	holoWrench.Color = Color3.fromRGB(255, 170, 40)
	holoWrench.Parent = model

	local holoLight = Instance.new("PointLight")
	holoLight.Color = Color3.fromRGB(255, 170, 40)
	holoLight.Brightness = 0.5
	holoLight.Range = 10
	holoLight.Parent = holoWrench

	task.spawn(function()
		while holoWrench.Parent do
			local t = os.clock() * 1.5
			holoWrench.Position = pos + Vector3.new(1.8, 4.2 + math.sin(t) * 0.2, -1.8)
			holoWrench.CFrame = CFrame.new(holoWrench.Position) * CFrame.Angles(0, math.rad(t * 40 % 360), math.rad(15))
			task.wait(0.04)
		end
	end)

	-- Dual Roof Canopy Support Columns
	for _, cx in ipairs({ -6, 6 }) do
		local col = Instance.new("Part")
		col.Size = Vector3.new(1.2, 9, 1.2)
		col.Position = pos + Vector3.new(cx, 4.7, -4.5)
		col.Anchored = true
		col.Material = Enum.Material.Metal
		col.Color = Color3.fromRGB(35, 38, 48)
		col.Parent = model
	end

	-- Canopy Roof
	local roof = Instance.new("Part")
	roof.Name = "CanopyRoof"
	roof.Size = Vector3.new(15, 0.8, 10)
	roof.Position = pos + Vector3.new(0, 9.2, -1)
	roof.Anchored = true
	roof.Material = Enum.Material.Metal
	roof.Color = Color3.fromRGB(25, 28, 36)
	roof.Parent = model

	local roofTrim = Instance.new("Part")
	roofTrim.Name = "CanopyTrim"
	roofTrim.Size = Vector3.new(15.4, 0.4, 0.6)
	roofTrim.Position = pos + Vector3.new(0, 9.2, 4)
	roofTrim.Anchored = true
	roofTrim.Material = Enum.Material.SmoothPlastic
	roofTrim.Color = Color3.fromRGB(255, 140, 30)
	roofTrim.Parent = model

	-- Illuminated Overhead Armory Billboard
	local sign = Instance.new("Part")
	sign.Name = "ArmorySign"
	sign.Size = Vector3.new(12, 2.4, 0.6)
	sign.Position = pos + Vector3.new(0, 10.6, 4)
	sign.Anchored = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(16, 18, 26)
	sign.Parent = model

	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Front
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 40
	sGui.LightInfluence = 0.2
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
	sTitle.TextSize = 22
	sTitle.TextColor3 = Color3.fromRGB(255, 180, 50)
	sTitle.Text = "🛠️ TOOL ARMORY & FORGE 🛠️"
	sTitle.Parent = sBox

	local sSub = Instance.new("TextLabel")
	sSub.Size = UDim2.new(1, 0, 0.35, 0)
	sSub.Position = UDim2.new(0, 0, 0.6, 0)
	sSub.BackgroundTransparency = 1
	sSub.Font = Enum.Font.GothamBold
	sSub.TextSize = 13
	sSub.TextColor3 = Color3.fromRGB(200, 215, 235)
	sSub.Text = "[ UPGRADE TOOLS // MULTIPLY HIT DAMAGE ]"
	sSub.Parent = sBox

	-- Interaction Proximity Prompt
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

	-- Tool Armory Forge Kiosk in Hub
	ZoneService.constructToolArmoryKiosk(hubFolder, Vector3.new(-18, 0, -16))

	-- 4 Scrap Nodes in Hub (Zone 1) - Evenly spaced with >16 studs clearance
	local zone1Offsets = {
		Vector3.new(22, 0, -22),
		Vector3.new(38, 0, -22),
		Vector3.new(22, 0, 22),
		Vector3.new(38, 0, 22),
	}
	for i, off in ipairs(zone1Offsets) do
		local pile = ZoneService.createScrapPile(Config.Zones[1], off, i)
		pile.Parent = hubFolder
		table.insert(activeNodes, pile)
	end

	-- Thematic Environmental Sci-Fi Props for Zone 1 (Rusty Outpost)
	ZoneService.buildZone1Props(hubFolder, Vector3.new(0, 0, 0))

	-- Towering Gantry Billboard for Zone 1
	ZoneService.constructZoneSign(hubFolder, Vector3.new(0, 0, 0), Config.Zones[1])
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
		statusLabel.Text = isDense and string.format("⭐ DENSE %s ⭐", zone.Name:upper()) or string.format("🔨 %s", zone.Name:upper())
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

	local prompt = root and root:FindFirstChild("ScrapPrompt") :: ProximityPrompt?
	if prompt then
		prompt.ObjectText = isDense and string.format("Dense %s Cache", zone.Name) or zone.Name
		prompt.ActionText = "Strike Scrap (E)"
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

	local halo = Instance.new("Part")
	halo.Name = "DenseHalo"
	halo.Shape = Enum.PartType.Cylinder
	halo.Size = Vector3.new(0.4, 4.0, 4.0)
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
	gui.AlwaysOnTop = true
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
	label.Text = string.format("🔨 %s", zone.Name:upper())
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScrapPrompt"
	prompt.ObjectText = zone.Name
	prompt.ActionText = "Strike Scrap (E)"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	-- Randomize initial dense node per zone (25% RNG per pile)
	local isDenseInitial = (math.random(1, 4) == 1)
	ZoneService.applyNodeVariant(model, zone, isDenseInitial)

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

	-- 2. Heavy Shipping Container B (Double-Stacked on Container A in North-West, Weathered Industrial Olive)
	local c2Pos = center + Vector3.new(-35.5, 12, -35.5)
	local c2Rot = CFrame.Angles(0, math.rad(24), 0)
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

-- Helper to construct an Industrial High-Definition Sci-Fi Gantry Billboard for a zone
function ZoneService.constructZoneSign(parent: Instance, centerPos: Vector3, zone: Types.ZoneConfig): Model
	local model = Instance.new("Model")
	model.Name = "SignGantry_Zone" .. tostring(zone.Id)

	local signPos = centerPos + Vector3.new(0, 21, -45)
	local signWidth = 28
	local signHeight = 8.5
	local signDepth = 1.6

	-- 1. Dual Heavy Structural Support Columns (Left & Right I-Beams grounded on concrete footings)
	local colXOffsets = { -15, 15 }
	for _, colX in ipairs(colXOffsets) do
		local footing = Instance.new("Part")
		footing.Name = "Footing"
		footing.Size = Vector3.new(3.6, 1.2, 3.6)
		footing.Position = centerPos + Vector3.new(colX, 0.6, -45)
		footing.Anchored = true
		footing.Material = Enum.Material.Concrete
		footing.Color = Color3.fromRGB(45, 48, 55)
		footing.Parent = model

		local col = Instance.new("Part")
		col.Name = "TrussColumn"
		col.Size = Vector3.new(2.0, 25, 2.0)
		col.Position = centerPos + Vector3.new(colX, 12.5, -45)
		col.Anchored = true
		col.Material = Enum.Material.Metal
		col.Color = Color3.fromRGB(32, 35, 44)
		col.Parent = model

		-- Diagonal Support Strut
		local strut = Instance.new("Part")
		strut.Name = "DiagonalStrut"
		strut.Size = Vector3.new(1.0, 10, 1.0)
		local strutSign = colX > 0 and -1 or 1
		strut.Position = centerPos + Vector3.new(colX + strutSign * 3.5, 18, -45.2)
		strut.Orientation = Vector3.new(0, 0, strutSign * 35)
		strut.Anchored = true
		strut.Material = Enum.Material.Metal
		strut.Color = Color3.fromRGB(38, 42, 52)
		strut.Parent = model
	end

	-- 2. Heavy Steel Cross-Truss Backing
	local trussBack = Instance.new("Part")
	trussBack.Name = "TrussBacking"
	trussBack.Size = Vector3.new(signWidth + 4, 2.2, 1.2)
	trussBack.Position = signPos + Vector3.new(0, 0, -1.2)
	trussBack.Anchored = true
	trussBack.Material = Enum.Material.DiamondPlate
	trussBack.Color = Color3.fromRGB(28, 30, 38)
	trussBack.Parent = model

	-- 3. Main Billboard Display Board
	local board = Instance.new("Part")
	board.Name = "BillboardBoard"
	board.Size = Vector3.new(signWidth, signHeight, signDepth)
	board.Position = signPos
	board.Anchored = true
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(15, 17, 24)
	board.Parent = model

	-- Top & Bottom Beveled Metal Bezel Trim
	local trimTop = Instance.new("Part")
	trimTop.Name = "BezelTop"
	trimTop.Size = Vector3.new(signWidth + 0.6, 0.6, signDepth + 0.4)
	trimTop.Position = signPos + Vector3.new(0, (signHeight / 2) + 0.3, 0)
	trimTop.Anchored = true
	trimTop.Material = Enum.Material.SmoothPlastic
	trimTop.Color = zone.Color
	trimTop.Parent = model

	local trimBottom = trimTop:Clone()
	trimBottom.Name = "BezelBottom"
	trimBottom.Position = signPos + Vector3.new(0, -(signHeight / 2) - 0.3, 0)
	trimBottom.Parent = model

	-- 4. Overhead Industrial Down-Lamps
	local lampOffsets = { -8, 8 }
	for _, lx in ipairs(lampOffsets) do
		local lampArm = Instance.new("Part")
		lampArm.Size = Vector3.new(0.6, 0.6, 2.8)
		lampArm.Position = signPos + Vector3.new(lx, (signHeight / 2) + 0.8, 1.2)
		lampArm.Anchored = true
		lampArm.Material = Enum.Material.Metal
		lampArm.Color = Color3.fromRGB(40, 42, 50)
		lampArm.Parent = model

		local lampHead = Instance.new("Part")
		lampHead.Size = Vector3.new(1.8, 0.8, 1.2)
		lampHead.Position = signPos + Vector3.new(lx, (signHeight / 2) + 0.5, 2.4)
		lampHead.Anchored = true
		lampHead.Material = Enum.Material.SmoothPlastic
		lampHead.Color = Color3.fromRGB(240, 235, 210)
		lampHead.Parent = model

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
		stText.Text = string.format("● SECTOR 0%d // DEPLOYMENT", zone.Id)
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
		mtText.Text = string.format("🔩 %dx SCRAP MULTIPLIER", zone.BaseYield)
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
			string.format("🗺️ FAST TRAVEL: ZONE %d", zone.Id),
			string.format("⚡ BASE VALUE: +%d", zone.BaseYield),
			string.format("🛡️ HAZARD TIER: %d", zone.Id),
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

	-- Solid Non-flickering Platform Floor: 100 x 4 x 100
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(100, 4, 100)
	platform.Position = centerPos - Vector3.new(0, 2, 0)
	platform.Anchored = true
	platform.Material = Enum.Material.Concrete
	platform.Color = Color3.fromRGB(42, 45, 54)
	platform.Parent = folder

	-- Perimeter Safety Curb Barrier
	local curbThickness = 2
	local curbHeight = 0.6

	local curbE = Instance.new("Part")
	curbE.Name = "CurbE"
	curbE.Size = Vector3.new(curbThickness, curbHeight, 100)
	curbE.Position = centerPos + Vector3.new(49, 0.3, 0)
	curbE.Anchored = true
	curbE.Material = Enum.Material.SmoothPlastic
	curbE.Color = zone.Color
	curbE.Parent = folder

	local curbN = Instance.new("Part")
	curbN.Name = "CurbN"
	curbN.Size = Vector3.new(100, curbHeight, curbThickness)
	curbN.Position = centerPos + Vector3.new(0, 0.3, -49)
	curbN.Anchored = true
	curbN.Material = Enum.Material.SmoothPlastic
	curbN.Color = zone.Color
	curbN.Parent = folder

	local curbS = curbN:Clone()
	curbS.Name = "CurbS"
	curbS.Position = centerPos + Vector3.new(0, 0.3, 49)
	curbS.Parent = folder

	-- Outer Safety Border Trim
	local trimN = Instance.new("Part")
	trimN.Name = "TrimN"
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

	-- Towering High-Definition Sci-Fi Gantry Billboard for this zone
	ZoneService.constructZoneSign(folder, centerPos, zone)

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

	-- Overhead Highway Gateway Arch Sign
	local archSign = Instance.new("Part")
	archSign.Name = "GatewaySign"
	archSign.Size = Vector3.new(1.8, 3.2, 18)
	archSign.Position = Vector3.new(bridgeX, 18.6, 0)
	archSign.Anchored = true
	archSign.Material = Enum.Material.SmoothPlastic
	archSign.Color = Color3.fromRGB(16, 18, 26)
	archSign.Parent = gateModel

	local archTrim = Instance.new("Part")
	archTrim.Name = "GatewayTrim"
	archTrim.Size = Vector3.new(2.0, 0.4, 18.4)
	archTrim.Position = Vector3.new(bridgeX, 20.3, 0)
	archTrim.Anchored = true
	archTrim.Material = Enum.Material.SmoothPlastic
	archTrim.Color = targetZone.Color
	archTrim.Parent = gateModel

	-- Sign facing West (towards approaching players from previous zone)
	local asgui = Instance.new("SurfaceGui")
	asgui.Face = Enum.NormalId.Left -- Facing -X towards approaching player
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
	asTitle.TextSize = 22
	asTitle.TextColor3 = Color3.new(1, 1, 1)
	asTitle.Text = string.format("▶ ZONE %d: %s ◀", targetZone.Id, targetZone.Name:upper())
	asTitle.Parent = asBox

	local asTStroke = Instance.new("UIStroke")
	asTStroke.Color = targetZone.Color
	asTStroke.Thickness = 1.5
	asTStroke.Parent = asTitle

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
