--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local DataService = require(script.Parent.DataService)

local BackpackService = {}

-- Visual tier color themes based on bag level
local TIER_THEMES = {
	{ MinLevel = 1, Name = "Rusted Rig", TankColor = Color3.fromRGB(85, 75, 70), TankMat = Enum.Material.CorrodedMetal, TrimColor = Color3.fromRGB(150, 100, 60) },
	{ MinLevel = 5, Name = "Steel Canister", TankColor = Color3.fromRGB(90, 95, 105), TankMat = Enum.Material.DiamondPlate, TrimColor = Color3.fromRGB(40, 180, 255) },
	{ MinLevel = 10, Name = "Titanium Battery", TankColor = Color3.fromRGB(45, 50, 65), TankMat = Enum.Material.Metal, TrimColor = Color3.fromRGB(170, 70, 255) },
	{ MinLevel = 15, Name = "Quantum Rig", TankColor = Color3.fromRGB(25, 28, 40), TankMat = Enum.Material.SmoothPlastic, TrimColor = Color3.fromRGB(255, 170, 0) },
}

local function getThemeForLevel(level: number)
	local selected = TIER_THEMES[1]
	for _, theme in ipairs(TIER_THEMES) do
		if level >= theme.MinLevel then
			selected = theme
		end
	end
	return selected
end

function BackpackService.updateCharacterBackpack(player: Player)
	local character = player.Character
	if not character then return end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not torso or not torso:IsA("BasePart") then
		task.spawn(function()
			local found = character:WaitForChild("UpperTorso", 5) or character:WaitForChild("Torso", 5) or character:WaitForChild("HumanoidRootPart", 5)
			if found and found:IsA("BasePart") and character.Parent then
				BackpackService.updateCharacterBackpack(player)
			end
		end)
		return
	end

	local data = DataService.get(player)
	local bagLevel = (data and data.Upgrades and data.Upgrades["BackpackCapacity"]) or 1
	local cargo = (data and data.Backpack) or 0
	local maxCap = Config.getBackpackCapacity(bagLevel)

	-- Destroy old backpack if present
	local existing = character:FindFirstChild("ScrapBackpack")
	if existing then
		existing:Destroy()
	end

	local theme = getThemeForLevel(bagLevel)
	-- Scale starts at 0.85 and grows by 8.5% with each upgrade level
	local scale = 0.85 + (bagLevel - 1) * 0.085

	local model = Instance.new("Model")
	model.Name = "ScrapBackpack"

	-- 1. Main Harness / Back Mounting Plate
	local frame = Instance.new("Part")
	frame.Name = "MountPlate"
	frame.Size = Vector3.new(1.3 * scale, 1.8 * scale, 0.3 * scale)
	frame.Material = Enum.Material.Metal
	frame.Color = Color3.fromRGB(28, 30, 38)
	frame.CanCollide = false
	frame.Massless = true
	frame.CastShadow = true
	frame.CFrame = torso.CFrame * CFrame.new(0, 0.1, 0.65 + (scale * 0.12))
	frame.Parent = model

	local frameWeld = Instance.new("WeldConstraint")
	frameWeld.Part0 = torso
	frameWeld.Part1 = frame
	frameWeld.Parent = frame

	-- 2. Left Pressurized Scrap Canister
	local tankLeft = Instance.new("Part")
	tankLeft.Name = "TankLeft"
	tankLeft.Shape = Enum.PartType.Cylinder
	tankLeft.Size = Vector3.new(1.7 * scale, 0.55 * scale, 0.55 * scale)
	tankLeft.Orientation = frame.Orientation + Vector3.new(0, 0, 90)
	tankLeft.Position = frame.Position + frame.CFrame.RightVector * (-0.48 * scale) + frame.CFrame.LookVector * (0.28 * scale)
	tankLeft.Material = theme.TankMat
	tankLeft.Color = theme.TankColor
	tankLeft.CanCollide = false
	tankLeft.Massless = true
	tankLeft.CastShadow = true
	tankLeft.Parent = model

	local weldL = Instance.new("WeldConstraint")
	weldL.Part0 = frame
	weldL.Part1 = tankLeft
	weldL.Parent = tankLeft

	-- 3. Right Pressurized Scrap Canister
	local tankRight = Instance.new("Part")
	tankRight.Name = "TankRight"
	tankRight.Shape = Enum.PartType.Cylinder
	tankRight.Size = Vector3.new(1.7 * scale, 0.55 * scale, 0.55 * scale)
	tankRight.Orientation = frame.Orientation + Vector3.new(0, 0, 90)
	tankRight.Position = frame.Position + frame.CFrame.RightVector * (0.48 * scale) + frame.CFrame.LookVector * (0.28 * scale)
	tankRight.Material = theme.TankMat
	tankRight.Color = theme.TankColor
	tankRight.CanCollide = false
	tankRight.Massless = true
	tankRight.CastShadow = true
	tankRight.Parent = model

	local weldR = Instance.new("WeldConstraint")
	weldR.Part0 = frame
	weldR.Part1 = tankRight
	weldR.Parent = tankRight

	-- 4. Central Glowing Energy Core / Capacity Gauge
	local core = Instance.new("Part")
	core.Name = "EnergyGauge"
	core.Shape = Enum.PartType.Cylinder
	core.Size = Vector3.new(1.3 * scale, 0.42 * scale, 0.42 * scale)
	core.Orientation = frame.Orientation + Vector3.new(0, 0, 90)
	core.Position = frame.Position + frame.CFrame.LookVector * (0.35 * scale)
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.fromRGB(50, 180, 100)
	core.CanCollide = false
	core.Massless = true
	core.Parent = model

	local weldCore = Instance.new("WeldConstraint")
	weldCore.Part0 = frame
	weldCore.Part1 = core
	weldCore.Parent = core

	-- Gauge light (Subtle soft accent, no camera flaring)
	local light = Instance.new("PointLight")
	light.Name = "CoreLight"
	light.Range = 3 * scale
	light.Brightness = 0.2
	light.Parent = core

	-- 5. Top Exhaust Nozzles
	local ventL = Instance.new("Part")
	ventL.Name = "VentLeft"
	ventL.Size = Vector3.new(0.35 * scale, 0.3 * scale, 0.35 * scale)
	ventL.Position = tankLeft.Position + frame.CFrame.UpVector * (0.9 * scale)
	ventL.Material = Enum.Material.Metal
	ventL.Color = theme.TrimColor
	ventL.CanCollide = false
	ventL.Massless = true
	ventL.Parent = model

	local weldVL = Instance.new("WeldConstraint")
	weldVL.Part0 = frame
	weldVL.Part1 = ventL
	weldVL.Parent = ventL

	local ventR = Instance.new("Part")
	ventR.Name = "VentRight"
	ventR.Size = Vector3.new(0.35 * scale, 0.3 * scale, 0.35 * scale)
	ventR.Position = tankRight.Position + frame.CFrame.UpVector * (0.9 * scale)
	ventR.Material = Enum.Material.Metal
	ventR.Color = theme.TrimColor
	ventR.CanCollide = false
	ventR.Massless = true
	ventR.Parent = model

	local weldVR = Instance.new("WeldConstraint")
	weldVR.Part0 = frame
	weldVR.Part1 = ventR
	weldVR.Parent = ventR

	-- Subtle steam / energy particles from vents
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Exhaust"
	steam.Color = ColorSequence.new(theme.TrimColor)
	steam.Size = NumberSequence.new(0.2 * scale, 0.6 * scale)
	steam.Transparency = NumberSequence.new(0.4, 1.0)
	steam.Rate = 4
	steam.Lifetime = NumberRange.new(0.6, 1.2)
	steam.Speed = NumberRange.new(1.5, 3.0)
	steam.Acceleration = Vector3.new(0, 2, 0)
	steam.Parent = ventL
	steam:Clone().Parent = ventR

	model.Parent = character

	BackpackService.updateCoreColor(player)
end

function BackpackService.updateCoreColor(player: Player)
	local character = player.Character
	if not character then return end

	local backpack = character:FindFirstChild("ScrapBackpack")
	if not backpack then return end

	local core = backpack:FindFirstChild("EnergyGauge") :: Part?
	if not core then return end

	local light = core:FindFirstChild("CoreLight") :: PointLight?

	local data = DataService.get(player)
	local bagLevel = (data and data.Upgrades and data.Upgrades["BackpackCapacity"]) or 1
	local cargo = (data and data.Backpack) or 0
	local maxCap = Config.getBackpackCapacity(bagLevel)
	local ratio = math.clamp(cargo / math.max(1, maxCap), 0, 1)

	local targetColor: Color3
	if cargo >= maxCap then
		targetColor = Color3.fromRGB(255, 40, 40) -- Flashing red full!
	elseif ratio >= 0.75 then
		targetColor = Color3.fromRGB(255, 170, 20) -- Amber warning
	else
		targetColor = Color3.fromRGB(0, 220, 255) -- Clean cyan
	end

	core.Color = targetColor
	if light then
		light.Color = targetColor
	end
end

function BackpackService.init()
	local function setupPlayer(player: Player)
		local function onCharacter(character: Model)
			task.spawn(function()
				character:WaitForChild("Humanoid", 10)
				local torso = character:WaitForChild("UpperTorso", 5) or character:WaitForChild("Torso", 5) or character:WaitForChild("HumanoidRootPart", 5)
				if torso and character.Parent then
					task.wait(0.15)
					BackpackService.updateCharacterBackpack(player)
				end
			end)
		end

		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	print("[BackpackService] Initialized with dynamic scaling character backpacks.")
end

return BackpackService
