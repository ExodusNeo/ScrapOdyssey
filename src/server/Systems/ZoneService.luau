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
	[2] = Vector3.new(150, 0, -90),
	[3] = Vector3.new(240, 0, 40),
	[4] = Vector3.new(150, 0, 180),
	[5] = Vector3.new(-20, 0, 200),
}

-- 1. Calm, Eye-Friendly Lighting Setup (Delegated to EnvironmentService with zero sun glare)
function ZoneService.setupLighting()
	EnvironmentService.setupAtmosphereAndSky()
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
	bb.AlwaysOnTop = false
	bb.MaxDistance = 32
	bb.Parent = pad

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(220, 170, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Text = "FAST TRAVEL TERMINAL\n[Press E or Step to Navigate]"
	lbl.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Fast Travel"
	prompt.ActionText = "Open Map"
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
	rbb.AlwaysOnTop = false
	rbb.MaxDistance = 45
	rbb.Parent = baseUnit

	local rTitle = Instance.new("TextLabel")
	rTitle.Size = UDim2.new(1, 0, 1, 0)
	rTitle.BackgroundTransparency = 1
	rTitle.Font = Enum.Font.GothamBlack
	rTitle.TextSize = 20
	rTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	rTitle.TextStrokeTransparency = 0.2
	rTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
	rTitle.Text = string.format("SCRAP RECYCLER %s\n[DEPOSIT & SELL CARGO]", zoneId > 1 and ("(ZONE " .. tostring(zoneId) .. ") ") or "")
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

	-- Foundation Deck (Extends toward +X Spawn)
	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(12, 0.4, 14)
	deck.Position = pos + Vector3.new(2, 0.2, 0)
	deck.Anchored = true
	deck.Material = Enum.Material.DiamondPlate
	deck.Color = Color3.fromRGB(30, 32, 40)
	deck.Parent = model

	-- Heavy Steel Workbench
	local bench = Instance.new("Part")
	bench.Name = "Workbench"
	bench.Size = Vector3.new(4, 3.2, 9)
	bench.Position = pos + Vector3.new(-1.8, 1.8, 0)
	bench.Anchored = true
	bench.Material = Enum.Material.Metal
	bench.Color = Color3.fromRGB(45, 50, 62)
	bench.Parent = model

	-- Cyber Anvil
	local anvil = Instance.new("Part")
	anvil.Name = "Anvil"
	anvil.Size = Vector3.new(1.6, 1.8, 2.8)
	anvil.Position = pos + Vector3.new(-1.8, 3.8, -2.2)
	anvil.Anchored = true
	anvil.Material = Enum.Material.CorrodedMetal
	anvil.Color = Color3.fromRGB(210, 120, 35)
	anvil.Parent = model

	-- Floating Holographic Preview Tools on Table
	local holoWrench = Instance.new("Part")
	holoWrench.Name = "HoloTool"
	holoWrench.Size = Vector3.new(0.6, 2.4, 0.6)
	holoWrench.Position = pos + Vector3.new(-1.8, 4.2, 1.8)
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

	CollectionService:AddTag(holoWrench, "FloatingDecor")
	holoWrench:SetAttribute("BasePos", pos + Vector3.new(-1.8, 4.2, 1.8))
	holoWrench:SetAttribute("SpinSpeed", 40)
	holoWrench:SetAttribute("BobSpeed", 1.5)
	holoWrench:SetAttribute("BobAmp", 0.2)
	holoWrench:SetAttribute("TiltAngle", 15)

	-- Dual Back Canopy Support Columns (at -X)
	for _, cz in ipairs({ -6, 6 }) do
		local col = Instance.new("Part")
		col.Size = Vector3.new(1.2, 9, 1.2)
		col.Position = pos + Vector3.new(-4.5, 4.7, cz)
		col.Anchored = true
		col.Material = Enum.Material.Metal
		col.Color = Color3.fromRGB(35, 38, 48)
		col.Parent = model
	end

	-- Canopy Roof
	local roof = Instance.new("Part")
	roof.Name = "CanopyRoof"
	roof.Size = Vector3.new(10, 0.8, 15)
	roof.Position = pos + Vector3.new(-1, 9.2, 0)
	roof.Anchored = true
	roof.Material = Enum.Material.Metal
	roof.Color = Color3.fromRGB(25, 28, 36)
	roof.Parent = model

	local roofTrim = Instance.new("Part")
	roofTrim.Name = "CanopyTrim"
	roofTrim.Size = Vector3.new(0.6, 0.4, 15.4)
	roofTrim.Position = pos + Vector3.new(4, 9.2, 0)
	roofTrim.Anchored = true
	roofTrim.Material = Enum.Material.SmoothPlastic
	roofTrim.Color = Color3.fromRGB(255, 140, 30)
	roofTrim.Parent = model

	-- Illuminated Overhead Armory Billboard (Facing East toward Spawn)
	local sign = Instance.new("Part")
	sign.Name = "ArmorySign"
	sign.Size = Vector3.new(0.6, 2.4, 12)
	sign.Position = pos + Vector3.new(4, 10.6, 0)
	sign.Anchored = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(16, 18, 26)
	sign.Parent = model

	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Right -- +X face points East towards Central Spawn
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
	sTitle.TextSize = 20
	sTitle.TextColor3 = Color3.fromRGB(255, 180, 50)
	sTitle.Text = "TOOL ARMORY & FORGE"
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

-- In-World Sci-Fi Egg Pod with hologram billboard, animated floating egg, and ProximityPrompt
function ZoneService.constructEggPod(parentFolder: Instance, pos: Vector3, eggType: string): Model
	local eggConf = Config.Eggs[eggType]
	if not eggConf then return Instance.new("Model") end

	local podModel = Instance.new("Model")
	podModel.Name = "EggPod_" .. eggType
	podModel:SetAttribute("EggType", eggType)
	CollectionService:AddTag(podModel, "EggPod")

	-- Pedestal Base
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(2.4, 4.2, 4.2)
	pedestal.Position = pos + Vector3.new(0, 1.2, 0)
	pedestal.Orientation = Vector3.new(0, 0, 90)
	pedestal.Anchored = true
	pedestal.Material = Enum.Material.DiamondPlate
	pedestal.Color = Color3.fromRGB(28, 30, 38)
	pedestal.Parent = podModel

	-- Glowing Ring on Pedestal
	local glowRing = Instance.new("Part")
	glowRing.Name = "GlowRing"
	glowRing.Shape = Enum.PartType.Cylinder
	glowRing.Size = Vector3.new(0.3, 4.4, 4.4)
	glowRing.Position = pos + Vector3.new(0, 2.3, 0)
	glowRing.Orientation = Vector3.new(0, 0, 90)
	glowRing.Anchored = true
	glowRing.Material = Enum.Material.Neon
	glowRing.Color = eggConf.Color
	glowRing.Parent = podModel

	-- Transparent Glass Containment Capsule
	local capsule = Instance.new("Part")
	capsule.Name = "Capsule"
	capsule.Shape = Enum.PartType.Cylinder
	capsule.Size = Vector3.new(4.2, 3.6, 3.6)
	capsule.Position = pos + Vector3.new(0, 4.3, 0)
	capsule.Orientation = Vector3.new(0, 0, 90)
	capsule.Anchored = true
	capsule.Material = Enum.Material.Glass
	capsule.Color = eggConf.Color
	capsule.Transparency = 0.55
	capsule.CanCollide = false
	capsule.Parent = podModel

	-- Floating 3D Display Egg (Neon energy core inside glass capsule)
	local egg = Instance.new("Part")
	egg.Name = "DisplayEgg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(2.0, 2.8, 2.0)
	egg.Position = pos + Vector3.new(0, 4.3, 0)
	egg.Anchored = true
	egg.CanCollide = false
	egg.Material = Enum.Material.Neon
	egg.Color = eggConf.Color
	egg.Parent = podModel

	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.8
	light.Color = eggConf.Color
	light.Parent = egg

	-- Gentle floating and spinning animation (Client-rendered for zero server replication overhead)
	local baseEggY = pos.Y + 4.3
	CollectionService:AddTag(egg, "FloatingDecor")
	egg:SetAttribute("BasePos", Vector3.new(pos.X, baseEggY, pos.Z))
	egg:SetAttribute("SpinSpeed", 30)
	egg:SetAttribute("BobSpeed", 2.0)
	egg:SetAttribute("BobAmp", 0.25)

	-- Format comma helper
	local formattedCost = tostring(math.floor(eggConf.Cost))
	while true do
		local k
		formattedCost, k = string.gsub(formattedCost, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end



	-- ProximityPrompt for Hatching
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
	-- Main solid circular cylinder platform (Diameter 90, Height 4, smooth top surface at Y = 0)
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Shape = Enum.PartType.Cylinder
	platform.Size = Vector3.new(4, 90, 90) -- Roblox Cylinder: X is height along axis, Y & Z are diameter
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
	apron.Size = Vector3.new(0.08, 44, 44)
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
	innerRing.Size = Vector3.new(0.08, 20, 20)
	innerRing.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	innerRing.Anchored = true
	innerRing.CanCollide = false
	innerRing.Material = Enum.Material.CorrodedMetal
	innerRing.Color = Color3.fromRGB(115, 65, 38)
	innerRing.Parent = folder

	return platform
end

-- Helper to build the Stereotypical Junkyard Corrugated Perimeter Fence with Barricades
local function buildScrapyardPerimeter(folder: Instance, centerPos: Vector3, zone: Types.ZoneConfig, entranceAngle: number?, exitAngle: number?)
	local fenceModel = Instance.new("Model")
	fenceModel.Name = "JunkyardFence_Zone" .. tostring(zone.Id)

	local segments = 24
	local radius = 44

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

			-- Corrugated Sheet Metal Wall Section
			local segLength = (math.pi * 2 / segments) * radius * 1.05
			local wallHeight = 7.5 + ((i % 3) * 0.4)
			local wallTilt = (i % 2 == 0 and 2.5 or -2.5)

			local panelCF = CFrame.new(segPos + Vector3.new(0, wallHeight / 2, 0))
				* CFrame.Angles(0, -lookAngle, 0)
				* CFrame.Angles(0, 0, math.rad(wallTilt))

			local wall = Instance.new("Part")
			wall.Name = "FencePanel_" .. tostring(i)
			wall.Size = Vector3.new(segLength, wallHeight, 1.2)
			wall.CFrame = panelCF
			wall.Anchored = true
			wall.CanCollide = true
			wall.Material = (i % 2 == 0 and Enum.Material.CorrodedMetal or Enum.Material.Metal)
			wall.Color = (i % 3 == 0 and zone.Color or (i % 2 == 0 and Color3.fromRGB(130, 70, 40) or Color3.fromRGB(65, 70, 80)))
			wall.Parent = fenceModel

			-- Steel Post
			local post = Instance.new("Part")
			post.Name = "FencePost_" .. tostring(i)
			post.Size = Vector3.new(1.4, wallHeight + 1.5, 1.4)
			post.Position = segPos + Vector3.new(0, (wallHeight + 1.5) / 2, 0)
			post.Anchored = true
			post.Material = Enum.Material.Metal
			post.Color = Color3.fromRGB(32, 35, 42)
			post.Parent = fenceModel

			-- Top Barbed Wire Bracket
			local bracket = Instance.new("Part")
			bracket.Size = Vector3.new(0.6, 1.6, 0.6)
			bracket.CFrame = CFrame.new(post.Position + Vector3.new(0, (wallHeight + 1.5) / 2, 0)) * CFrame.Angles(0, -lookAngle, math.rad(30))
			bracket.Anchored = true
			bracket.CanCollide = false
			bracket.Material = Enum.Material.Metal
			bracket.Color = Color3.fromRGB(45, 48, 55)
			bracket.Parent = fenceModel

			-- Stereotypical Junkyard Barricade Clutter (Tucked snugly against fence perimeter, clear of pathways)
			if i % 6 == 1 then
				for cubeIdx = 1, 2 do
					local cube = Instance.new("Part")
					cube.Name = "CrushedCarCube"
					cube.Size = Vector3.new(4.5, 3.8, 4.5)
					cube.Position = segPos + (tangent * 3) + Vector3.new(0, 1.9 + (cubeIdx - 1) * 3.8, 0)
					cube.Orientation = Vector3.new(0, deg + (cubeIdx * 15), 0)
					cube.Anchored = true
					cube.Material = Enum.Material.CorrodedMetal
					cube.Color = (cubeIdx == 1 and Color3.fromRGB(90, 75, 60) or Color3.fromRGB(120, 65, 40))
					cube.Parent = fenceModel
				end
			elseif i % 6 == 4 then
				for tIdx = 1, 3 do
					local tire = Instance.new("Part")
					tire.Name = "PerimeterTire"
					tire.Shape = Enum.PartType.Cylinder
					tire.Size = Vector3.new(1.4, 4.0, 4.0)
					tire.CFrame = CFrame.new(segPos - (tangent * 2.5) + Vector3.new(0, 0.7 + (tIdx - 1) * 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
					tire.Anchored = true
					tire.Material = Enum.Material.SmoothPlastic
					tire.Color = Color3.fromRGB(24, 25, 28)
					tire.Parent = fenceModel
				end
			end
		end
	end

	-- Dedicated Centered Gateway Framing Posts (22-stud wide opening, 2 studs outside the 18-stud bridge pier)
	local function createGatewayFrame(gAngle: number, prefix: string)
		local gDir = Vector3.new(math.cos(gAngle), 0, math.sin(gAngle)).Unit
		local gTangent = Vector3.new(-gDir.Z, 0, gDir.X).Unit
		local gPos = centerPos + gDir * radius

		local postL = Instance.new("Part")
		postL.Name = prefix .. "_GatewayPostL"
		postL.Size = Vector3.new(2.4, 11, 2.4)
		postL.Position = gPos + gTangent * 11 + Vector3.new(0, 5.5, 0)
		postL.Anchored = true
		postL.Material = Enum.Material.Metal
		postL.Color = Color3.fromRGB(35, 38, 48)
		postL.Parent = fenceModel

		local stripeL = Instance.new("Part")
		stripeL.Size = Vector3.new(2.6, 1.2, 2.6)
		stripeL.Position = postL.Position + Vector3.new(0, 2.5, 0)
		stripeL.Anchored = true
		stripeL.Material = Enum.Material.SmoothPlastic
		stripeL.Color = Color3.fromRGB(255, 170, 0)
		stripeL.Parent = fenceModel

		local postR = postL:Clone()
		postR.Name = prefix .. "_GatewayPostR"
		postR.Position = gPos - gTangent * 11 + Vector3.new(0, 5.5, 0)
		postR.Parent = fenceModel

		local stripeR = stripeL:Clone()
		stripeR.Position = postR.Position + Vector3.new(0, 2.5, 0)
		stripeR.Parent = fenceModel
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
	ZoneService.constructRecycler(hubFolder, centerPos + Vector3.new(0, 0, -26), 1)

	-- 6. Zone 1 Exclusive Egg Pod along South-West perimeter
	ZoneService.constructEggPod(hubFolder, centerPos + Vector3.new(-18, 0.4, 24), "RustEgg")

	-- 7. Tool Armory Forge Kiosk along West perimeter (Facing East toward Spawn)
	ZoneService.constructToolArmoryKiosk(hubFolder, centerPos + Vector3.new(-28, 0, 0))

	-- 8. Fast-Travel Portal Pad along South-East perimeter
	createPortalPad(hubFolder, centerPos + Vector3.new(18, 0.3, 24), 1)

	-- 9. 8 Scrap Nodes in Hub (Zone 1) - Generously spaced in radial mining bays (clear of all corridors)
	local zone1Offsets = {
		Vector3.new(30, 0, 8),
		Vector3.new(14, 0, -28),
		Vector3.new(-14, 0, -28),
		Vector3.new(-26, 0, -14),
		Vector3.new(-26, 0, 14),
		Vector3.new(-14, 0, 28),
		Vector3.new(14, 0, 28),
		Vector3.new(24, 0, 24),
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

-- Zone 1: Rusty Outpost Props (Industrial Salvage Crane, Cargo Shipping Containers, Fuel Silo, Rusted Drums)
function ZoneService.buildZone1Props(folder: Instance, center: Vector3)
	local props = Instance.new("Model")
	props.Name = "ThematicProps_Zone1"
	props.Parent = folder

	-- 1. Heavy Industrial Salvage Crane (North-West Perimeter: -26, 0, -28 - completely clear of pathways)
	local cranePos = center + Vector3.new(-26, 0, -28)
	createPropPart(props, "CraneBase", Vector3.new(8, 2, 8), CFrame.new(cranePos + Vector3.new(0, 1, 0)), Color3.fromRGB(40, 42, 48), Enum.Material.Concrete)
	createPropPart(props, "CraneMast", Vector3.new(3.5, 26, 3.5), CFrame.new(cranePos + Vector3.new(0, 14, 0)), Color3.fromRGB(215, 145, 30), Enum.Material.Metal)
	createPropPart(props, "CraneBoom", Vector3.new(3, 3, 24), CFrame.new(cranePos + Vector3.new(0, 26, 6)), Color3.fromRGB(215, 145, 30), Enum.Material.Metal)
	createPropPart(props, "CraneCounterweight", Vector3.new(5, 4, 6), CFrame.new(cranePos + Vector3.new(0, 26, -9)), Color3.fromRGB(55, 55, 60), Enum.Material.Concrete)
	createPropPart(props, "CraneCable", Vector3.new(0.3, 10, 0.3), CFrame.new(cranePos + Vector3.new(0, 19, 14)), Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
	createPropPart(props, "CraneMagnet", Vector3.new(1.8, 6, 6), CFrame.new(cranePos + Vector3.new(0, 14, 14)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(65, 65, 75), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- 2. Rusted Coolant Silo (South Border Center: 0, 0, 36)
	local siloPos = center + Vector3.new(0, 0, 36)
	createPropPart(props, "SiloBody", Vector3.new(18, 7.5, 7.5), CFrame.new(siloPos + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 85, 50), Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	createPropPart(props, "SiloDome", Vector3.new(7.5, 5, 7.5), CFrame.new(siloPos + Vector3.new(0, 19, 0)), Color3.fromRGB(130, 75, 45), Enum.Material.Metal, Enum.PartType.Ball)
	createPropPart(props, "SiloCatwalk", Vector3.new(1, 9, 9), CFrame.new(siloPos + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, Enum.PartType.Cylinder)

	-- 3. Rusted Oil Drum Clusters (Placed along South border beside Silo, never on pathways)
	local drumOffsets = {
		Vector3.new(-8, 1.4, 34),
		Vector3.new(-6, 1.4, 36),
		Vector3.new(-7, 4.2, 35),
		Vector3.new(8, 1.4, 34),
		Vector3.new(6, 1.4, 36),
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

	-- 1. Heavy Hydraulic Car-Crusher Press (North Border Directly Behind Recycler)
	local crusherPos = center + Vector3.new(0, 0, -36)
	createPropPart(props, "CrusherCol1", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(-9, 9, -3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherCol2", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(9, 9, -3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherCol3", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(-9, 9, 3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherCol4", Vector3.new(2.2, 18, 2.2), CFrame.new(crusherPos + Vector3.new(9, 9, 3)), Color3.fromRGB(70, 85, 100), Enum.Material.Metal)
	createPropPart(props, "CrusherTop", Vector3.new(22, 3.5, 8), CFrame.new(crusherPos + Vector3.new(0, 18, 0)), Color3.fromRGB(45, 55, 65), Enum.Material.Metal)
	createPropPart(props, "PistonL", Vector3.new(10, 1.8, 1.8), CFrame.new(crusherPos + Vector3.new(-4.5, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 190, 205), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "PistonR", Vector3.new(10, 1.8, 1.8), CFrame.new(crusherPos + Vector3.new(4.5, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 190, 205), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "CrushRam", Vector3.new(17, 2, 6.5), CFrame.new(crusherPos + Vector3.new(0, 7, 0)), Color3.fromRGB(100, 115, 130), Enum.Material.Metal)

	-- 2. Crushed Cyber-Car Stack (North-West Border)
	local carPos1 = center + Vector3.new(-26, 0, -26)
	createPropPart(props, "CarLower_1", Vector3.new(7.5, 2.2, 12), CFrame.new(carPos1 + Vector3.new(0, 1.1, 0)), Color3.fromRGB(60, 95, 120), Enum.Material.Metal)
	createPropPart(props, "CarLower_Windshield", Vector3.new(6.5, 1.0, 4), CFrame.new(carPos1 + Vector3.new(0, 2.7, -1)), Color3.fromRGB(20, 30, 40), Enum.Material.SmoothPlastic)
	local rotCar2 = CFrame.Angles(math.rad(6), math.rad(14), math.rad(-4))
	createPropPart(props, "CarUpper_1", Vector3.new(7, 2, 11), CFrame.new(carPos1 + Vector3.new(0.4, 2.9, 0)) * rotCar2, Color3.fromRGB(140, 50, 60), Enum.Material.Metal)

	-- 3. Crushed Cyber-Car Stack (North-East Border)
	local carPos2 = center + Vector3.new(26, 0, -26)
	local rotCar3 = CFrame.Angles(math.rad(-5), math.rad(-16), math.rad(6))
	createPropPart(props, "CarStack2_Base", Vector3.new(8, 2.2, 12), CFrame.new(carPos2 + Vector3.new(0, 1.1, 0)), Color3.fromRGB(160, 120, 40), Enum.Material.Metal)
	createPropPart(props, "CarStack2_Top", Vector3.new(7.2, 2.0, 10.5), CFrame.new(carPos2 + Vector3.new(-0.3, 2.9, 0)) * rotCar3, Color3.fromRGB(75, 80, 95), Enum.Material.Metal)

	-- 4. Giant Radial Tire Stacks (South Borders)
	local tireClusters = {
		Vector3.new(26, 0, 26),
		Vector3.new(0, 0, 30),
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

	-- 1. Twin Blast Smelting Chimney Kilns (North Border Flanking Recycler)
	local chimneyOffsets = { Vector3.new(-18, 0, -34), Vector3.new(18, 0, -34) }
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

	-- 2. Molten Slag Crucible Cauldron (North-West Border)
	local crucPos = center + Vector3.new(-26, 0, -24)
	createPropPart(props, "CrucibleStandL", Vector3.new(1.8, 8, 1.8), CFrame.new(crucPos + Vector3.new(-4.5, 4, 0)), Color3.fromRGB(50, 48, 55), Enum.Material.Metal)
	createPropPart(props, "CrucibleStandR", Vector3.new(1.8, 8, 1.8), CFrame.new(crucPos + Vector3.new(4.5, 4, 0)), Color3.fromRGB(50, 48, 55), Enum.Material.Metal)
	createPropPart(props, "CruciblePot", Vector3.new(6, 6.5, 6.5), CFrame.new(crucPos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 38, 45), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "MoltenSlag", Vector3.new(0.5, 5.5, 5.5), CFrame.new(crucPos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 105, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 3. Overhead Conveyor Truss Span (South Border Perimeter)
	local convPos = center + Vector3.new(0, 0, 30)
	createPropPart(props, "ConvTowerL", Vector3.new(2.5, 16, 2.5), CFrame.new(convPos + Vector3.new(-18, 8, 0)), Color3.fromRGB(180, 85, 25), Enum.Material.Metal)
	createPropPart(props, "ConvTowerR", Vector3.new(2.5, 16, 2.5), CFrame.new(convPos + Vector3.new(18, 8, 0)), Color3.fromRGB(180, 85, 25), Enum.Material.Metal)
	createPropPart(props, "ConvTrack", Vector3.new(38, 2.5, 3.5), CFrame.new(convPos + Vector3.new(0, 16, 0)), Color3.fromRGB(190, 95, 30), Enum.Material.Metal)

	-- 4. Titanium Ingot Pallet Stack (South-East Border)
	local palletPos = center + Vector3.new(26, 0, 26)
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

	-- 1. Twin Monolithic Server Mainframe Banks (North Border Flanking Recycler)
	local serverOffsets = { Vector3.new(-18, 0, -34), Vector3.new(18, 0, -34) }
	for idx, sOff in ipairs(serverOffsets) do
		local sPos = center + sOff
		createPropPart(props, "ServerFrame_" .. idx, Vector3.new(10, 14, 4), CFrame.new(sPos + Vector3.new(0, 7, 0)), Color3.fromRGB(28, 32, 42), Enum.Material.Metal)
		createPropPart(props, "ServerGlass_" .. idx, Vector3.new(9.2, 13, 0.4), CFrame.new(sPos + Vector3.new(0, 7, 2)), Color3.fromRGB(30, 200, 180), Enum.Material.Glass)
		for row = 1, 4 do
			createPropPart(props, "ServerBlade_" .. idx .. "_" .. row, Vector3.new(8.5, 0.5, 0.4), CFrame.new(sPos + Vector3.new(0, 2 + (row * 2.5), 1.9)), Color3.fromRGB(40, 190, 180), Enum.Material.SmoothPlastic)
		end
	end

	-- 2. Quantum Transmitter Tower Spire (South Border Perimeter)
	local towerPos = center + Vector3.new(0, 0, 30)
	createPropPart(props, "TowerBase", Vector3.new(6, 2, 6), CFrame.new(towerPos + Vector3.new(0, 1, 0)), Color3.fromRGB(35, 40, 52), Enum.Material.Metal)
	createPropPart(props, "TowerSpire", Vector3.new(3, 26, 3), CFrame.new(towerPos + Vector3.new(0, 14, 0)), Color3.fromRGB(45, 55, 70), Enum.Material.Metal)
	createPropPart(props, "ArrayRing1", Vector3.new(0.6, 7.5, 7.5), CFrame.new(towerPos + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 210, 190), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	createPropPart(props, "ArrayRing2", Vector3.new(0.6, 5.5, 5.5), CFrame.new(towerPos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 210, 190), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 3. Slanted Data Consoles (North-West & North-East Perimeter)
	local consoleOffsets = { Vector3.new(-26, 0, -24), Vector3.new(26, 0, -24) }
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

	-- 1. Massive Starship Ion Thruster Bell (North-West Border, 28 deg Impact Tilt)
	local thrustPos = center + Vector3.new(-18, 0, -32)
	local thrustRot = CFrame.Angles(math.rad(28), math.rad(15), 0)
	createPropPart(props, "ThrusterBell", Vector3.new(12, 11, 11), CFrame.new(thrustPos + Vector3.new(0, 6, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(42, 36, 54), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "ThrusterRing", Vector3.new(2, 12.5, 12.5), CFrame.new(thrustPos + Vector3.new(0, 8.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 50, 75), Enum.Material.Metal, Enum.PartType.Cylinder)
	createPropPart(props, "ThrusterCore", Vector3.new(1, 8.5, 8.5), CFrame.new(thrustPos + Vector3.new(0, 4.5, 0)) * thrustRot * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 50, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 2. Warp Drive Antimatter Containment Housing (North-East Border)
	local warpPos = center + Vector3.new(18, 0, -32)
	createPropPart(props, "WarpHousingBase", Vector3.new(8, 2, 8), CFrame.new(warpPos + Vector3.new(0, 1, 0)), Color3.fromRGB(38, 32, 48), Enum.Material.Metal)
	createPropPart(props, "WarpHousingTop", Vector3.new(8, 2, 8), CFrame.new(warpPos + Vector3.new(0, 10, 0)), Color3.fromRGB(38, 32, 48), Enum.Material.Metal)
	createPropPart(props, "WarpStrut1", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(-3, 5.5, -3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "WarpStrut2", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(3, 5.5, -3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "WarpStrut3", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(-3, 5.5, 3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "WarpStrut4", Vector3.new(1.4, 8, 1.4), CFrame.new(warpPos + Vector3.new(3, 5.5, 3)), Color3.fromRGB(55, 45, 70), Enum.Material.Metal)
	createPropPart(props, "SingularityCore", Vector3.new(4, 4, 4), CFrame.new(warpPos + Vector3.new(0, 5.5, 0)), Color3.fromRGB(175, 60, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)

	-- 3. Fractured Dreadnought Armor Bulkhead Slab (South Border Perimeter)
	local slabPos = center + Vector3.new(0, 0, 30)
	local slabRot = CFrame.Angles(math.rad(-20), 0, math.rad(5))
	createPropPart(props, "HullArmorSlab", Vector3.new(28, 8, 2.5), CFrame.new(slabPos + Vector3.new(0, 4, 0)) * slabRot, Color3.fromRGB(48, 42, 60), Enum.Material.Metal)
	createPropPart(props, "HullArmorRib", Vector3.new(28.4, 1.5, 3.2), CFrame.new(slabPos + Vector3.new(0, 6, 0)) * slabRot, Color3.fromRGB(65, 55, 80), Enum.Material.Metal)

	-- 4. Alien Void Crystal Formations (North-West & South-East Perimeter)
	local crystalClusters = {
		Vector3.new(-26, 0, -24),
		Vector3.new(26, 0, 26),
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

	local signPos = centerPos + Vector3.new(0, 21, -38)
	local signWidth = 28
	local signHeight = 8.5
	local signDepth = 1.6

	-- 1. Dual Heavy Structural Support Columns (Left & Right I-Beams grounded on concrete footings)
	local colXOffsets = { -15, 15 }
	for _, colX in ipairs(colXOffsets) do
		local footing = Instance.new("Part")
		footing.Name = "Footing"
		footing.Size = Vector3.new(3.6, 1.2, 3.6)
		footing.Position = centerPos + Vector3.new(colX, 0.6, -38)
		footing.Anchored = true
		footing.Material = Enum.Material.Concrete
		footing.Color = Color3.fromRGB(45, 48, 55)
		footing.Parent = model

		local col = Instance.new("Part")
		col.Name = "TrussColumn"
		col.Size = Vector3.new(2.0, 25, 2.0)
		col.Position = centerPos + Vector3.new(colX, 12.5, -38)
		col.Anchored = true
		col.Material = Enum.Material.Metal
		col.Color = Color3.fromRGB(32, 35, 44)
		col.Parent = model

		-- Diagonal Support Strut
		local strut = Instance.new("Part")
		strut.Name = "DiagonalStrut"
		strut.Size = Vector3.new(1.0, 10, 1.0)
		local strutSign = colX > 0 and -1 or 1
		strut.Position = centerPos + Vector3.new(colX + strutSign * 3.5, 18, -38.2)
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
	ZoneService.constructRecycler(folder, centerPos + Vector3.new(0, 0, -26), zone.Id)

	-- 5. 8 Scrap Nodes per zone - Generously distributed radially across the compound (clear of corridors)
	local offsets = {
		Vector3.new(20, 0, -10),
		Vector3.new(14, 0, -28),
		Vector3.new(-14, 0, -28),
		Vector3.new(-26, 0, -12),
		Vector3.new(-26, 0, 12),
		Vector3.new(-14, 0, 28),
		Vector3.new(14, 0, 28),
		Vector3.new(28, 0, 14),
	}

	for i, offset in ipairs(offsets) do
		local pile = ZoneService.createScrapPile(zone, centerPos + offset, i)
		pile.Parent = folder
		table.insert(activeNodes, pile)
	end

	-- 6. Fast Travel Portal on this platform (along South-West perimeter)
	createPortalPad(folder, centerPos + Vector3.new(-20, 0.3, 24), zone.Id)

	-- 7. Dedicated Zone Egg Pod along South-East perimeter
	local zoneEggTypeMap = {
		[2] = "JunkyardEgg",
		[3] = "FoundryEgg",
		[4] = "CyberEgg",
		[5] = "VoidEgg",
	}
	local eggTypeForZone = zoneEggTypeMap[zone.Id]
	if eggTypeForZone then
		ZoneService.constructEggPod(folder, centerPos + Vector3.new(20, 0.4, 24), eggTypeForZone)
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

	-- Walkable Deck
	local deck = Instance.new("Part")
	deck.Name = "BridgeDeck"
	deck.Size = Vector3.new(length, 3, width)
	deck.CFrame = bridgeCF * CFrame.new(0, -1.5, 0)
	deck.Anchored = true
	deck.Material = mat or Enum.Material.DiamondPlate
	deck.Color = color or Color3.fromRGB(68, 74, 88)
	deck.Parent = parent

	-- Left Guardrail
	local railL = Instance.new("Part")
	railL.Name = "GuardrailL"
	railL.Size = Vector3.new(length, 3.5, 1.2)
	railL.CFrame = bridgeCF * CFrame.new(0, 1.75, -(width / 2) + 0.6)
	railL.Anchored = true
	railL.Material = Enum.Material.Metal
	railL.Color = Color3.fromRGB(28, 30, 38)
	railL.Parent = parent

	local neonL = Instance.new("Part")
	neonL.Size = Vector3.new(length, 0.4, 0.4)
	neonL.CFrame = bridgeCF * CFrame.new(0, 3.5, -(width / 2) + 0.6)
	neonL.Anchored = true
	neonL.Material = Enum.Material.SmoothPlastic
	neonL.Color = accentColor
	neonL.Parent = parent

	-- Left Anti-Jump Wall
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
	antiJumpL.Parent = parent

	-- Right Guardrail
	local railR = Instance.new("Part")
	railR.Name = "GuardrailR"
	railR.Size = Vector3.new(length, 3.5, 1.2)
	railR.CFrame = bridgeCF * CFrame.new(0, 1.75, (width / 2) - 0.6)
	railR.Anchored = true
	railR.Material = Enum.Material.Metal
	railR.Color = Color3.fromRGB(28, 30, 38)
	railR.Parent = parent

	local neonR = Instance.new("Part")
	neonR.Size = Vector3.new(length, 0.4, 0.4)
	neonR.CFrame = bridgeCF * CFrame.new(0, 3.5, (width / 2) - 0.6)
	neonR.Anchored = true
	neonR.Material = Enum.Material.SmoothPlastic
	neonR.Color = accentColor
	neonR.Parent = parent

	-- Right Anti-Jump Wall
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
	antiJumpR.Parent = parent

	-- Underside Box Girders & Cross Trusses
	EnvironmentService.constructBridgeUnderside(parent, bridgeCF, length, width, zoneId)
end

-- Helper to create a floating midway landmark platform
local function buildMidwayIsland(parent: Instance, pos: Vector3, size: Vector3, color: Color3, zoneId: number): Part
	local island = Instance.new("Part")
	island.Name = "MidwayIsland_Zone" .. tostring(zoneId)
	island.Shape = Enum.PartType.Cylinder
	island.Size = Vector3.new(size.Y, size.X, size.X)
	island.CFrame = CFrame.new(pos - Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	island.Anchored = true
	island.Material = Enum.Material.DiamondPlate
	island.Color = color
	island.Parent = parent

	-- Perimeter safety curb
	local ring = Instance.new("Part")
	ring.Name = "MidwayCurb"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.8, size.X + 0.6, size.X + 0.6)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Config.Zones[zoneId] and Config.Zones[zoneId].Color or Color3.fromRGB(80, 140, 200)
	ring.Parent = parent

	return island
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

	-- Left Column
	local pL = Instance.new("Part")
	pL.Name = "GatePillarL"
	pL.Size = Vector3.new(3, 16, 3)
	pL.CFrame = gateCF * CFrame.new(-bridgeWidth / 2 + 1.5, 8, 0)
	pL.Anchored = true
	pL.Color = Color3.fromRGB(25, 28, 38)
	pL.Material = Enum.Material.Metal
	pL.Parent = gateModel

	-- Right Column
	local pR = Instance.new("Part")
	pR.Name = "GatePillarR"
	pR.Size = Vector3.new(3, 16, 3)
	pR.CFrame = gateCF * CFrame.new(bridgeWidth / 2 - 1.5, 8, 0)
	pR.Anchored = true
	pR.Color = Color3.fromRGB(25, 28, 38)
	pR.Material = Enum.Material.Metal
	pR.Parent = gateModel

	-- Top Beam
	local top = Instance.new("Part")
	top.Name = "GateTop"
	top.Size = Vector3.new(bridgeWidth + 1, 3, 3)
	top.CFrame = gateCF * CFrame.new(0, 16, 0)
	top.Anchored = true
	top.Color = Color3.fromRGB(25, 28, 38)
	top.Material = Enum.Material.Metal
	top.Parent = gateModel

	-- Overhead Signboard
	local archSign = Instance.new("Part")
	archSign.Name = "GatewaySign"
	archSign.Size = Vector3.new(bridgeWidth - 4, 3.2, 1.8)
	archSign.CFrame = gateCF * CFrame.new(0, 18.6, 0)
	archSign.Anchored = true
	archSign.Material = Enum.Material.SmoothPlastic
	archSign.Color = Color3.fromRGB(16, 18, 26)
	archSign.Parent = gateModel

	local archTrim = Instance.new("Part")
	archTrim.Name = "GatewayTrim"
	archTrim.Size = Vector3.new(bridgeWidth - 3.6, 0.4, 2.0)
	archTrim.CFrame = gateCF * CFrame.new(0, 20.3, 0)
	archTrim.Anchored = true
	archTrim.Material = Enum.Material.SmoothPlastic
	archTrim.Color = targetZone.Color
	archTrim.Parent = gateModel

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

	-- Main Forcefield barrier
	local barrier = Instance.new("Part")
	barrier.Name = "Forcefield"
	barrier.Size = Vector3.new(bridgeWidth + 2, 26, 2.5)
	barrier.CFrame = gateCF * CFrame.new(0, 13, 0)
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.Transparency = 0.35
	barrier.Material = Enum.Material.ForceField
	barrier.Color = targetZone.Color
	barrier.Parent = gateModel

	-- Archway Perimeter Barrier (Covers only the gate opening - zero global obstruction!)
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
	perimeterBarrier.Parent = gateModel

	-- Bounce handler
	local bounceDebounce: { [Player]: number } = {}
	local function handleBarrierTouch(hit: BasePart)
		local char = hit.Parent
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local now = os.clock()
		if bounceDebounce[player] and now - bounceDebounce[player] < 1.0 then
			return
		end

		local data = DataService.get(player)
		local maxZ = data and (data.MaxZoneReached or 1) or 1
		if maxZ < targetZone.Id then
			bounceDebounce[player] = now
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				local bouncePos = gatePos - approachDir * 12 + Vector3.new(0, 3.5, 0)
				root.CFrame = CFrame.new(bouncePos)
				local notif = Remotes.getEvent("ShowNotification")
				if notif then
					notif:FireClient(player, "SECURITY LOCK", string.format("Zone %d is locked! Unlock it with Scrap to enter.", targetZone.Id), Color3.fromRGB(255, 75, 75))
				end
			end
		end
	end

	barrier.Touched:Connect(handleBarrierTouch)
	perimeterBarrier.Touched:Connect(handleBarrierTouch)

	-- Proximity Prompt Part
	local promptPart = Instance.new("Part")
	promptPart.Name = "UnlockPromptPart"
	promptPart.Size = Vector3.new(4, 4, 4)
	promptPart.Position = gatePos - approachDir * 4 + Vector3.new(0, 3, 0)
	promptPart.Anchored = true
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.Parent = gateModel

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

	local startPos = fromCenter + mainDir * 44
	local endPos = toCenter - mainDir * 44

	-- 1. Initial Straight Approach Pier from Island 1 gateway (Length 14 studs, Width 18 - completely unblocked)
	local pierEnd = startPos + mainDir * 14
	buildBridgeSegment(bridgeContainer, startPos, pierEnd, 18, targetZone.Color, zoneId, Enum.Material.DiamondPlate, Color3.fromRGB(70, 75, 85))

	-- 2. Midway Landmark Island (Circle diameter 24, centered at midway between pierEnd and endPos - 14)
	local midwayPos = (pierEnd + (endPos - mainDir * 16)) / 2
	buildMidwayIsland(bridgeContainer, midwayPos, Vector3.new(24, 4, 24), Color3.fromRGB(48, 45, 52), zoneId)

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

	-- 5. Final Approach Span from Midway Island to Target Zone (Length ~16 studs, Width 18)
	local finalSpanStart = midwayPos + mainDir * 10
	buildBridgeSegment(bridgeContainer, finalSpanStart, endPos, 18, targetZone.Color, zoneId, Enum.Material.DiamondPlate, Color3.fromRGB(70, 75, 85))

	-- 6. Gate Model positioned on the final approach span
	local gatePos = endPos - mainDir * 10
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
							-- Check if player is trespassing inside any locked zone compound (radius < 50)
							for lockedZoneId = maxZone + 1, #Config.Zones do
								local lockedCenter = ZONE_CENTERS[lockedZoneId]
								if lockedCenter then
									local lockedPos2D = Vector3.new(lockedCenter.X, 0, lockedCenter.Z)
									if (playerPos2D - lockedPos2D).Magnitude < 50 then
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
