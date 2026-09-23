--!strict
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local VFXController = {}

local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
local screenShakeEnabled = true

-- Camera Shake state variables
local shakeIntensity = 0
local shakeDuration = 0
local shakeElapsed = 0
local shakeRotMultiplier = 1

-- 1. Camera Shake System
function VFXController.shakeCamera(intensity: number, duration: number, rotMultiplier: number?)
	if not screenShakeEnabled then return end
	-- If a larger shake is already active, blend them
	shakeIntensity = math.max(shakeIntensity * 0.5, intensity)
	shakeDuration = duration
	shakeElapsed = 0
	shakeRotMultiplier = rotMultiplier or 1
end

function VFXController.toggleScreenShake(): boolean
	screenShakeEnabled = not screenShakeEnabled
	return screenShakeEnabled
end

function VFXController.isScreenShakeEnabled(): boolean
	return screenShakeEnabled
end

-- 2. Impact Sparks & Debris Burst
function VFXController.spawnHitSparks(position: Vector3, isDense: boolean, zoneColor: Color3?)
	local anchor = Instance.new("Part")
	anchor.Name = "HitFXAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	-- Bright Shrapnel Sparks
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.LightEmission = 1.0
	sparks.LightInfluence = 0.0

	if isDense then
		sparks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 245, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 60, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		})
	else
		local baseCol = zoneColor or Color3.fromRGB(255, 200, 50)
		sparks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 180)),
			ColorSequenceKeypoint.new(0.4, baseCol),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 20)),
		})
	end

	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isDense and 0.5 or 0.35),
		NumberSequenceKeypoint.new(0.8, isDense and 0.25 or 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Speed = NumberRange.new(12, isDense and 32 or 22)
	sparks.SpreadAngle = Vector2.new(120, 120)
	sparks.Acceleration = Vector3.new(0, -42, 0) -- Crisp gravity drop
	sparks.Lifetime = NumberRange.new(0.25, 0.45)
	sparks.Rate = 0
	sparks.Parent = attachment

	-- Micro Flash PointLight
	local flash = Instance.new("PointLight")
	flash.Color = isDense and Color3.fromRGB(0, 240, 255) or Color3.fromRGB(255, 215, 100)
	flash.Range = isDense and 14 or 9
	flash.Brightness = isDense and 5 or 3
	flash.Shadows = false
	flash.Parent = anchor

	TweenService:Create(flash, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Range = 0,
	}):Play()

	-- Emit particle burst
	sparks:Emit(isDense and 28 or 16)

	-- Dense Shockwave Ring
	if isDense then
		local wave = Instance.new("Part")
		wave.Name = "ShockwaveRing"
		wave.Shape = Enum.PartType.Cylinder
		wave.Size = Vector3.new(0.1, 0.5, 0.5)
		wave.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		wave.Material = Enum.Material.Neon
		wave.Color = Color3.fromRGB(0, 240, 255)
		wave.Transparency = 0.2
		wave.Anchored = true
		wave.CanCollide = false
		wave.CanQuery = false
		wave.CanTouch = false
		wave.Parent = Workspace

		local waveTween = TweenService:Create(wave, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, 10, 10),
			Transparency = 1,
		})
		waveTween:Play()
		waveTween.Completed:Connect(function()
			wave:Destroy()
		end)
	end

	Debris:AddItem(anchor, 0.6)
end

-- 3. Shatter & Cleared Explosion
function VFXController.spawnShatterVFX(position: Vector3, isDense: boolean)
	local anchor = Instance.new("Part")
	anchor.Name = "ShatterAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	-- Big Fragment / Debris Burst
	local debrisEmitter = Instance.new("ParticleEmitter")
	debrisEmitter.Name = "DebrisBurst"
	debrisEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	debrisEmitter.LightEmission = 0.8
	debrisEmitter.Color = isDense and ColorSequence.new(Color3.fromRGB(0, 240, 255), Color3.fromRGB(200, 80, 255))
		or ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 120, 30))
	debrisEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.6, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	debrisEmitter.Transparency = NumberSequence.new(0, 1)
	debrisEmitter.Speed = NumberRange.new(18, 38)
	debrisEmitter.SpreadAngle = Vector2.new(180, 180)
	debrisEmitter.Acceleration = Vector3.new(0, -50, 0)
	debrisEmitter.Lifetime = NumberRange.new(0.4, 0.7)
	debrisEmitter.Rate = 0
	debrisEmitter.Parent = attachment

	-- Large Expanding Nova Disc
	local nova = Instance.new("Part")
	nova.Name = "NovaRing"
	nova.Shape = Enum.PartType.Cylinder
	nova.Size = Vector3.new(0.15, 1, 1)
	nova.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	nova.Material = Enum.Material.Neon
	nova.Color = isDense and Color3.fromRGB(0, 240, 255) or Color3.fromRGB(255, 215, 50)
	nova.Transparency = 0.1
	nova.Anchored = true
	nova.CanCollide = false
	nova.CanQuery = false
	nova.CanTouch = false
	nova.Parent = Workspace

	local novaTween = TweenService:Create(nova, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 16, 16),
		Transparency = 1,
	})
	novaTween:Play()
	novaTween.Completed:Connect(function()
		nova:Destroy()
	end)

	-- Bright Flash Light
	local flash = Instance.new("PointLight")
	flash.Color = isDense and Color3.fromRGB(0, 240, 255) or Color3.fromRGB(255, 230, 100)
	flash.Range = 22
	flash.Brightness = 8
	flash.Shadows = false
	flash.Parent = anchor

	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Range = 0,
	}):Play()

	debrisEmitter:Emit(40)
	Debris:AddItem(anchor, 1.0)
end

-- 4. Scrap Recycler Deposit Fountain & Banked Banner
function VFXController.spawnRecycleVFX(position: Vector3, scrapRecycled: number, scrapEarned: number)
	local anchor = Instance.new("Part")
	anchor.Name = "RecycleVFXAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(0, 2, 0)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	-- Golden Geyser of Energy & Sparks
	local geyser = Instance.new("ParticleEmitter")
	geyser.Name = "GoldenGeyser"
	geyser.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	geyser.LightEmission = 1.0
	geyser.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 220, 120)),
	})
	geyser.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	geyser.Speed = NumberRange.new(18, 30)
	geyser.SpreadAngle = Vector2.new(20, 20)
	geyser.EmissionDirection = Enum.NormalId.Top
	geyser.Acceleration = Vector3.new(0, -18, 0)
	geyser.Lifetime = NumberRange.new(0.6, 1.0)
	geyser.Rate = 0
	geyser.Parent = attachment

	-- Floating 3D Cash Pop
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 240, 0, 70)
	billboard.StudsOffsetWorldSpace = position + Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 45
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(80, 240, 140)
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = string.format("+%d SCRAP RECYCLED", scrapEarned)
	label.Parent = billboard

	local floatTween = TweenService:Create(billboard, TweenInfo.new(1.8, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = position + Vector3.new(0, 11, 0),
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextSize = 30,
	})

	floatTween:Play()
	fadeTween:Play()

	geyser:Emit(36)
	Debris:AddItem(anchor, 2.2)
end

-- 5. Dynamic Tool Swing Trail
function VFXController.attachToolTrail(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return end

	local trail = handle:FindFirstChild("SwingTrail") :: Trail?
	if trail then return end

	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, -0.6, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 2.4, 0)
	att1.Parent = handle

	trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 100), Color3.fromRGB(255, 120, 20))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.16
	trail.Enabled = false
	trail.Parent = handle
end

function VFXController.pulseToolTrail(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return end
	local trail = handle:FindFirstChild("SwingTrail") :: Trail?
	if not trail then
		VFXController.attachToolTrail(tool)
		trail = handle:FindFirstChild("SwingTrail") :: Trail?
	end
	if trail then
		trail.Enabled = true
		task.delay(0.22, function()
			if trail and trail.Parent then
				trail.Enabled = false
			end
		end)
	end
end

-- 6. RenderStepped Camera Shake Loop
function VFXController.init()
	RunService.RenderStepped:Connect(function(dt)
		if shakeElapsed < shakeDuration and shakeDuration > 0 and screenShakeEnabled then
			shakeElapsed = shakeElapsed + dt
			local progress = math.clamp(shakeElapsed / shakeDuration, 0, 1)
			-- Exponential decay
			local currentAmp = shakeIntensity * (1 - progress) * (1 - progress)

			local offsetX = (math.random() * 2 - 1) * currentAmp
			local offsetY = (math.random() * 2 - 1) * currentAmp
			local rotZ = math.rad((math.random() * 2 - 1) * currentAmp * 3 * shakeRotMultiplier)
			local rotX = math.rad((math.random() * 2 - 1) * currentAmp * 2 * shakeRotMultiplier)

			camera.CFrame = camera.CFrame * CFrame.Angles(rotX, 0, rotZ) * CFrame.new(offsetX, offsetY, 0)
		else
			shakeIntensity = 0
			shakeDuration = 0
		end
	end)

	-- 7. High-Performance Client-Side Floating Decor Animator (Zero server network overhead, 60+ FPS smooth)
	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera or camera
		if not cam then return end
		local camPos = cam.CFrame.Position
		local t = os.clock()

		for _, decor in ipairs(CollectionService:GetTagged("FloatingDecor")) do
			if decor:IsA("BasePart") and decor.Parent then
				local basePos = decor:GetAttribute("BasePos") :: Vector3?
				if basePos then
					local dx = camPos.X - basePos.X
					local dz = camPos.Z - basePos.Z
					if (dx * dx + dz * dz) < 14400 then -- Within 120 studs of camera
						local bobSpeed = (decor:GetAttribute("BobSpeed") :: number) or 1.5
						local bobAmp = (decor:GetAttribute("BobAmp") :: number) or 0.2
						local spinSpeed = (decor:GetAttribute("SpinSpeed") :: number) or 30
						local tiltAngle = (decor:GetAttribute("TiltAngle") :: number) or 0

						local bobY = math.sin(t * bobSpeed) * bobAmp
						local spin = math.rad((t * spinSpeed) % 360)
						local newPos = basePos + Vector3.new(0, bobY, 0)
						decor.CFrame = CFrame.new(newPos) * CFrame.Angles(0, spin, math.rad(tiltAngle))
					end
				end
			end
		end
	end)

	print("[VFXController] Particle & Camera Juice Engine Initialized.")
end

return VFXController
