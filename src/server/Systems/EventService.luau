--!strict
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)

local EventService = {}

local activePodModel: Model? = nil

-- Damage tracking per player for the active Drop Pod raid
local playerContributions: { [Player]: number } = {}
local totalRaidDamage = 0

-- Zone center coordinates on the X-axis (platforms are 100 x 170)
local ZONE_CENTERS: { [number]: Vector3 } = {
	[1] = Vector3.new(0, 1.0, 0),
	[2] = Vector3.new(160, 1.0, 0),
	[3] = Vector3.new(320, 1.0, 0),
	[4] = Vector3.new(480, 1.0, 0),
	[5] = Vector3.new(640, 1.0, 0),
}

function EventService.recordDamage(player: Player, amount: number)
	playerContributions[player] = (playerContributions[player] or 0) + amount
	totalRaidDamage = totalRaidDamage + amount
end

function EventService.getContributions(): ({ [Player]: number }, number)
	return playerContributions, totalRaidDamage
end

function EventService.resetContributions()
	table.clear(playerContributions)
	totalRaidDamage = 0
end

-- Collect positions of all interactable objects (Recyclers, Forges, Eggs, Portals, Spawns, and Scrap Piles)
local function getInteractables(): { Vector3 }
	local positions: { Vector3 } = {}

	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			local p = desc.Parent
			if p and p:IsA("BasePart") then
				table.insert(positions, p.Position)
			end
		elseif desc:IsA("SpawnLocation") then
			table.insert(positions, desc.Position)
		elseif desc.Name == "SellPad" or desc.Name == "PortalPad" or desc.Name == "ForgeTable" then
			if desc:IsA("BasePart") then
				table.insert(positions, desc.Position)
			end
		elseif desc:IsA("Model") and string.sub(desc.Name, 1, 10) == "ScrapPile_" and not desc:GetAttribute("IsOrbitalPod") then
			local hb = desc:FindFirstChild("Hitbox") or desc:FindFirstChild("Base")
			if hb and hb:IsA("BasePart") then
				table.insert(positions, hb.Position)
			end
		end
	end

	return positions
end

-- Pick a random spawn position anywhere across the expanded map that is safely away from all interactables
local function pickRandomLandingPosition(): (Vector3, string, number)
	local interactables = getInteractables()
	local minClearance = 24 -- Minimum distance from any interactable

	-- Attempt 50 random candidates across all zones and the expanded 100 x 170 grounds
	for _ = 1, 50 do
		local zoneId = math.random(1, 5)
		local zoneCenter = ZONE_CENTERS[zoneId] or Vector3.new(0, 1.0, 0)
		local zone = Config.Zones[zoneId] or Config.Zones[1]

		-- Pick coordinate across the expanded land bounds:
		-- X: [-40, 40] from zone center, Z: [-75, 75]
		local candX = zoneCenter.X + math.random(-40, 40)
		local candZ = math.random(-75, 75)
		local candidate = Vector3.new(candX, 1.0, candZ)

		local safe = true
		for _, ipos in ipairs(interactables) do
			local dist = (Vector3.new(candidate.X, 0, candidate.Z) - Vector3.new(ipos.X, 0, ipos.Z)).Magnitude
			if dist < minClearance then
				safe = false
				break
			end
		end

		if safe then
			local sector = candZ > 30 and "Southern Wastelands" or (candZ < -30 and "Northern Outpost" or "Open Courtyard")
			local locationName = string.format("%s of %s", sector, zone.Name)
			return candidate, locationName, zoneId
		end
	end

	-- Guaranteed open fallback in the southern expanse of a random zone
	local fbZoneId = math.random(1, 5)
	local fbCenter = ZONE_CENTERS[fbZoneId] or Vector3.new(0, 1.0, 0)
	local fbZone = Config.Zones[fbZoneId] or Config.Zones[1]
	local fbPos = fbCenter + Vector3.new(math.random(-25, 25), 1.0, 58)
	return fbPos, string.format("Southern Wastelands of %s", fbZone.Name), fbZoneId
end

-- Construct 3D High-Tech Orbital Raid Drop Pod
local function constructPodModel(landingPos: Vector3, locationName: string): Model
	local pod = Instance.new("Model")
	pod.Name = "ScrapPile_OrbitalPod"

	-- Substantially higher HP for a collaborative server raid boss event
	local maxHP = 2500
	local totalScrapPool = 80000
	local totalGearsPool = 40

	pod:SetAttribute("IsOrbitalPod", true)
	pod:SetAttribute("MaxHP", maxHP)
	pod:SetAttribute("CurrentHP", maxHP)
	pod:SetAttribute("TotalScrapPool", totalScrapPool)
	pod:SetAttribute("TotalGearsPool", totalGearsPool)
	pod:SetAttribute("LocationName", locationName)

	-- 1. Hitbox (Root detection & PrimaryPart)
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(12, 10, 12)
	hitbox.Position = landingPos + Vector3.new(0, 5, 0)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = true
	hitbox.CanTouch = true
	hitbox.Parent = pod
	pod.PrimaryPart = hitbox

	-- 2. Base Heat Shield
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1.6, 11, 11)
	base.CFrame = CFrame.new(landingPos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Material = Enum.Material.DiamondPlate
	base.Color = Color3.fromRGB(35, 40, 50)
	base.Anchored = true
	base.CanCollide = true
	base.Parent = pod

	-- 3. Molten Plasma Core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(6, 6, 6)
	core.Position = landingPos + Vector3.new(0, 5.0, 0)
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 120, 20)
	core.Anchored = true
	core.CanCollide = false
	core.Parent = pod

	local coreLight = Instance.new("PointLight")
	coreLight.Name = "CoreLight"
	coreLight.Color = Color3.fromRGB(255, 140, 30)
	coreLight.Brightness = 4.5
	coreLight.Range = 28
	coreLight.Shadows = false
	coreLight.Parent = core

	-- 4. Armored Heavy Hull Ribs (4 Quad Stabilizers)
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90)
		local xOff = math.cos(angle) * 3.8
		local zOff = math.sin(angle) * 3.8

		local fin = Instance.new("Part")
		fin.Name = "HullRib_" .. tostring(i)
		fin.Size = Vector3.new(1.6, 7.5, 2.0)
		fin.Position = landingPos + Vector3.new(xOff, 4.8, zOff)
		fin.CFrame = CFrame.lookAt(fin.Position, landingPos + Vector3.new(0, 4.8, 0)) * CFrame.Angles(math.rad(-15), 0, 0)
		fin.Material = Enum.Material.Metal
		fin.Color = Color3.fromRGB(60, 68, 82)
		fin.Anchored = true
		fin.CanCollide = true
		fin.Parent = pod

		-- Neon Hazard Striping
		local stripe = Instance.new("Part")
		stripe.Name = "HazardStripe"
		stripe.Size = Vector3.new(0.35, 5.5, 2.05)
		stripe.CFrame = fin.CFrame
		stripe.Material = Enum.Material.Neon
		stripe.Color = Color3.fromRGB(255, 180, 0)
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.Parent = pod
	end

	-- 5. Sky Beacon: Soaring vertical light beam visible across the whole map
	local beacon = Instance.new("Part")
	beacon.Name = "SkyBeacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(240, 2.5, 2.5)
	beacon.CFrame = CFrame.new(landingPos + Vector3.new(0, 120, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 140, 20)
	beacon.Transparency = 0.5
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.Parent = pod

	-- 6. Exhaust Fire Emitter
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 3.0, 0)
	att.Parent = core

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "ReentryFire"
	fire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 180)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 140, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 10)),
	})
	fire.LightEmission = 1.0
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.7, 2.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	fire.Speed = NumberRange.new(6, 14)
	fire.SpreadAngle = Vector2.new(40, 40)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Acceleration = Vector3.new(0, 12, 0)
	fire.Lifetime = NumberRange.new(0.3, 0.7)
	fire.Rate = 20
	fire.Parent = att

	-- 7. Interactive ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScrapPrompt"
	prompt.ObjectText = "🚀 ORBITAL RAID POD"
	prompt.ActionText = "Dismantle Pod"
	prompt.HoldDuration = 0.05
	prompt.MaxActivationDistance = 24
	prompt.RequiresLineOfSight = false
	prompt.Parent = hitbox

	prompt.Triggered:Connect(function(player)
		local ActionService = require(script.Parent.ActionService)
		ActionService.performScrapAction(player, pod)
	end)

	-- 8. High-Visibility Boss Health Bar Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBillboard"
	billboard.Size = UDim2.new(0, 280, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200
	billboard.Parent = hitbox

	local bg = Instance.new("Frame")
	bg.Name = "CardBG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 10)
	bgCorner.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(255, 140, 30)
	bgStroke.Thickness = 2
	bgStroke.Parent = bg

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "StatusLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.Position = UDim2.new(0, 0, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Text = "🔥 ORBITAL RAID POD 🔥"
	titleLabel.Parent = bg

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.Size = UDim2.new(1, 0, 0, 18)
	hpLabel.Position = UDim2.new(0, 0, 0, 26)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 12
	hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpLabel.Text = string.format("[ %d / %d HP ]", maxHP, maxHP)
	hpLabel.Parent = bg

	local barBG = Instance.new("Frame")
	barBG.Name = "HealthBarBG"
	barBG.Size = UDim2.new(1, -20, 0, 14)
	barBG.Position = UDim2.new(0, 10, 0, 50)
	barBG.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
	barBG.BorderSizePixel = 0
	barBG.ClipsDescendants = true
	barBG.Parent = bg

	local barBGC = Instance.new("UICorner")
	barBGC.CornerRadius = UDim.new(0, 5)
	barBGC.Parent = barBG

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 120, 20)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBG

	local barFC = Instance.new("UICorner")
	barFC.CornerRadius = UDim.new(0, 5)
	barFC.Parent = barFill

	pod.Destroying:Connect(function()
		if activePodModel == pod then
			activePodModel = nil
			EventService.resetContributions()
		end
	end)

	return pod
end

-- Trigger a Drop Pod Crash Event anywhere on the map
function EventService.triggerDropPod(forcedPos: Vector3?): Model?
	if activePodModel and activePodModel.Parent then
		print("[EventService] An Orbital Drop Pod is already active! Waiting for it to resolve.")
		return activePodModel
	end

	EventService.resetContributions()

	-- Pick random position anywhere across the expanded land, avoiding all interactable objects
	local landingPos: Vector3
	local locationName: string
	local zoneId: number

	if forcedPos then
		landingPos = forcedPos
		locationName = "Custom Coords"
		zoneId = 1
	else
		landingPos, locationName, zoneId = pickRandomLandingPosition()
	end

	print(string.format("[EventService] Triggering Orbital Drop Pod at %s (Position: %s)", locationName, tostring(landingPos)))

	-- 1. Broadcast global warning siren & notification
	local notif = Remotes.getEvent("ShowNotification")
	notif:FireAllClients(
		"⚠️ ORBITAL SALVAGE DETECTED!",
		string.format("Raid Pod crashing into %s! Dismantle it together to split the massive Scrap & Gears pool!", locationName:upper()),
		Color3.fromRGB(255, 140, 20)
	)

	local announceEvent = Remotes.getEvent("OrbitalEventAnnounce")
	announceEvent:FireAllClients({
		ZoneId = zoneId,
		ZoneName = locationName,
		LandingPosition = landingPos,
	})

	-- 2. Build the pod model and parent to Workspace
	local pod = constructPodModel(landingPos, locationName)
	activePodModel = pod
	pod.Parent = Workspace

	-- 3. Perfectly Rigid Reentry Descent Animation using Model:PivotTo()
	local targetPivot = pod:GetPivot()
	local dropHeight = 160
	local startPivot = targetPivot + Vector3.new(0, dropHeight, 0)
	pod:PivotTo(startPivot)

	task.spawn(function()
		local descentDuration = 2.0
		local startTime = os.clock()

		while os.clock() - startTime < descentDuration do
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / descentDuration, 0, 1)
			local currentAltitude = dropHeight * (1 - (alpha * alpha))
			pod:PivotTo(targetPivot + Vector3.new(0, currentAltitude, 0))
			task.wait(0.03)
		end

		pod:PivotTo(targetPivot)

		-- Impact Touchdown: Broadcast impact shockwave
		local impactEvent = Remotes.getEvent("OrbitalEventImpact")
		impactEvent:FireAllClients({
			LandingPosition = landingPos,
			ZoneId = zoneId,
		})

		-- Scorch plate on the ground
		local scorch = Instance.new("Part")
		scorch.Name = "ScorchCrater"
		scorch.Shape = Enum.PartType.Cylinder
		scorch.Size = Vector3.new(0.08, 14, 14)
		scorch.CFrame = CFrame.new(landingPos + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
		scorch.Material = Enum.Material.CorrodedMetal
		scorch.Color = Color3.fromRGB(20, 22, 28)
		scorch.Anchored = true
		scorch.CanCollide = false
		scorch.CanQuery = false
		scorch.CanTouch = false
		scorch.Parent = pod

		print(string.format("[EventService] Drop Pod touchdown confirmed at %s!", locationName))
	end)

	-- 4. Auto-Self-Destruct / Despawn if untouched after 240s
	task.delay(240, function()
		if pod and pod.Parent then
			local notifEv = Remotes.getEvent("ShowNotification")
			notifEv:FireAllClients("🚀 POD DEPARTED", "The unharvested Orbital Drop Pod has burned up and departed.", Color3.fromRGB(180, 180, 190))
			pod:Destroy()
			if activePodModel == pod then
				activePodModel = nil
				EventService.resetContributions()
			end
		end
	end)

	return pod
end

function EventService.getActivePod(): Model?
	return activePodModel
end

function EventService.clearActivePod(podModel: Model?)
	if not podModel or activePodModel == podModel then
		activePodModel = nil
		EventService.resetContributions()
	end
end

-- Initialize periodic server event loop
function EventService.init()
	task.spawn(function()
		task.wait(90)
		while true do
			EventService.triggerDropPod()
			local interval = math.random(300, 420)
			task.wait(interval)
		end
	end)

	print("[EventService] Dynamic Orbital Drop Pod & Meteor Event System initialized.")
end

return EventService
