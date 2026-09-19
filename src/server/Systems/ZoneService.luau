--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)

local ZoneService = {}
local activeNodes = {}

local ZONE_SPAWN_OFFSETS = {
	Vector3.new(0, 0, 0),         -- Zone 1: Rusty Outpost (center)
	Vector3.new(120, 0, 0),       -- Zone 2: Automotive Graveyard
	Vector3.new(240, 0, 0),       -- Zone 3: Industrial Foundry
	Vector3.new(360, 0, 0),       -- Zone 4: Cybernetic Wasteland
	Vector3.new(480, 0, 0),       -- Zone 5: Orbital Crashsite
}

local function createScrapPile(zone: Types.ZoneConfig, position: Vector3, index: number): Model
	local model = Instance.new("Model")
	model.Name = string.format("ScrapPile_%d_%d", zone.Id, index)

	local root = Instance.new("Part")
	root.Name = "Hitbox"
	root.Size = Vector3.new(6, 4, 6)
	root.Position = position + Vector3.new(0, 2, 0)
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Parent = model

	-- Visual mesh/parts for junk pile
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 2.5, 5)
	base.Position = position + Vector3.new(0, 1.25, 0)
	base.Anchored = true
	base.Color = zone.Color
	base.Material = Enum.Material.CorrodedMetal
	base.Parent = model

	-- Top decorative part
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Size = Vector3.new(3, 1.5, 3)
	top.Position = position + Vector3.new(0, 2.8, 0)
	top.Anchored = true
	top.Color = zone.Color
	top.Material = Enum.Material.Metal
	top.Orientation = Vector3.new(15, 30, -10)
	top.Parent = model

	-- Billboard display showing zone and status
	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoGui"
	gui.Size = UDim2.new(0, 140, 0, 40)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Text = "🔨 SCRAP ME"
	label.Parent = gui

	-- ProximityPrompt for natural interaction
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScrapPrompt"
	prompt.ObjectText = zone.Name
	prompt.ActionText = "Dismantle Scrap"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	model:SetAttribute("ZoneId", zone.Id)
	model:SetAttribute("BaseYield", zone.BaseYield)
	model:SetAttribute("ActionTime", zone.ActionTime)
	model:SetAttribute("Active", true)

	return model
end

function ZoneService.spawnZoneNodes(zone: Types.ZoneConfig, centerPos: Vector3)
	local folder = Workspace:FindFirstChild("Zone_" .. tostring(zone.Id)) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Zone_" .. tostring(zone.Id)
		folder.Parent = Workspace
	end

	-- Create Zone Floor/Platform
	local platform = folder:FindFirstChild("Platform") :: Part
	if not platform then
		platform = Instance.new("Part")
		platform.Name = "Platform"
		platform.Size = Vector3.new(80, 2, 80)
		platform.Position = centerPos - Vector3.new(0, 1, 0)
		platform.Anchored = true
		platform.Material = Enum.Material.Concrete
		platform.Color = zone.Color
		platform.Parent = folder

		-- Zone Title sign
		local sign = Instance.new("Part")
		sign.Name = "ZoneSign"
		sign.Size = Vector3.new(20, 8, 2)
		sign.Position = centerPos + Vector3.new(0, 10, -38)
		sign.Anchored = true
		sign.Material = Enum.Material.SmoothPlastic
		sign.Color = Color3.fromRGB(30, 30, 35)
		sign.Parent = folder

		local sgui = Instance.new("SurfaceGui")
		sgui.Face = Enum.NormalId.Front
		sgui.Parent = sign

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Text = string.format("ZONE %d\n%s", zone.Id, zone.Name:upper())
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.Parent = sgui
	end

	-- Spawn 4 Scrap Piles per zone
	local offsets = {
		Vector3.new(-18, 0, -18),
		Vector3.new(18, 0, -18),
		Vector3.new(-18, 0, 18),
		Vector3.new(18, 0, 18),
	}

	for i, offset in ipairs(offsets) do
		local pilePos = centerPos + offset
		local pile = createScrapPile(zone, pilePos, i)
		pile.Parent = folder
		table.insert(activeNodes, pile)
	end
end

function ZoneService.unlockZone(player: Player, zoneId: number): boolean
	local data = DataService.get(player)
	if not data then return false end

	local zone = Config.Zones[zoneId]
	if not zone then return false end

	if (data.MaxZoneReached or 1) >= zoneId then
		return true -- Already unlocked
	end

	if (data.MaxZoneReached or 1) + 1 ~= zoneId then
		return false -- Must unlock sequentially
	end

	local CurrencyService = require(script.Parent.CurrencyService)
	if CurrencyService.removeScrap(player, zone.UnlockCost) then
		data.MaxZoneReached = zoneId
		data.CurrentZone = zoneId
		DataService.sync(player)

		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Zone Unlocked!", string.format("You unlocked %s!", zone.Name), zone.Color)
		return true
	end

	return false
end

function ZoneService.init()
	-- Create physical zones in Workspace
	for i, zone in ipairs(Config.Zones) do
		local centerPos = ZONE_SPAWN_OFFSETS[i] or Vector3.new(i * 100, 0, 0)
		ZoneService.spawnZoneNodes(zone, centerPos)
	end

	-- Listen for UnlockZone requests
	local unlockEvent = Remotes.getEvent("UnlockZone")
	unlockEvent.OnServerEvent:Connect(function(player, zoneId)
		if type(zoneId) == "number" then
			ZoneService.unlockZone(player, zoneId)
		end
	end)

	print("[ZoneService] Initialized with 5 zones and interactive scrap nodes.")
end

return ZoneService
