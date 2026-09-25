--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes = require(ReplicatedStorage.Modules.Remotes)
local controllersFolder = (script and script.Parent) or game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")
local SoundController = require(controllersFolder:WaitForChild("SoundController"))
local VFXController = require(controllersFolder:WaitForChild("VFXController"))

local ActionController = {}
local player = Players.LocalPlayer

local lastSwingTime = 0
local hookedTools: { [Tool]: boolean } = {}
local comboStep = 0

-- Replaceable character lifecycle state
local generation = 0
local characterConnections: { RBXScriptConnection } = {}
local currentCharacter: Model? = nil
local currentAnimator: Animator? = nil
local loadedTracks: { [string]: AnimationTrack } = {}
local createdAnimations: { Animation } = {}

local function clearCharacter()
	generation += 1
	for _, conn in ipairs(characterConnections) do
		conn:Disconnect()
	end
	table.clear(characterConnections)

	for _, track in pairs(loadedTracks) do
		pcall(function()
			track:Stop(0.05)
			track:Destroy()
		end)
	end
	table.clear(loadedTracks)

	for _, anim in ipairs(createdAnimations) do
		pcall(function()
			anim:Destroy()
		end)
	end
	table.clear(createdAnimations)

	currentAnimator = nil
	currentCharacter = nil
end

local function bindCharacter(character: Model)
	if player.Character ~= character then return end
	clearCharacter()
	currentCharacter = character
	local thisGeneration = generation

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root or generation ~= thisGeneration then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	currentAnimator = animator

	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15

	-- Official verified responsive swing/slash and lunge/thrust animation tracks
	local slashId = isR15 and "rbxassetid://522635514" or "rbxassetid://129967390"
	local lungeId = isR15 and "rbxassetid://522638767" or "rbxassetid://129967342"

	local function loadTrack(id: string, name: string): AnimationTrack?
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		table.insert(createdAnimations, anim)
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		loadedTracks[name] = track
		return track
	end

	pcall(function()
		loadTrack(slashId, "Slash")
		loadTrack(lungeId, "Lunge")
	end)

	table.insert(characterConnections, humanoid.Died:Connect(function()
		if generation == thisGeneration then
			clearCharacter()
		end
	end))
end

local function playToolAnimation(tool: Tool, cooldown: number)
	local toolId = tool:GetAttribute("ToolId") or tool.Name
	local trackToPlay: AnimationTrack? = nil
	local animSpeed = 1.0

	-- Scale animation speed so it fits nicely inside the tool's attack rate
	local baseRate = math.clamp(0.4 / math.max(0.15, cooldown), 0.8, 2.2)

	if toolId == "PneumaticDrill" then
		trackToPlay = loadedTracks["Lunge"] or loadedTracks["Slash"]
		animSpeed = baseRate * 1.35
	elseif toolId == "PlasmaCutter" then
		trackToPlay = loadedTracks["Slash"]
		animSpeed = baseRate * 1.25
	elseif toolId == "CyberScythe" then
		trackToPlay = loadedTracks["Slash"]
		animSpeed = baseRate * 1.15
	elseif toolId == "VoidRipper" then
		comboStep = (comboStep % 2) + 1
		if comboStep == 1 then
			trackToPlay = loadedTracks["Slash"]
		else
			trackToPlay = loadedTracks["Lunge"] or loadedTracks["Slash"]
		end
		animSpeed = baseRate * 1.2
	else
		-- OmniWrench / Default
		trackToPlay = loadedTracks["Slash"] or loadedTracks["Lunge"]
		animSpeed = baseRate * 1.05
	end

	if trackToPlay then
		trackToPlay:AdjustSpeed(animSpeed)
		trackToPlay:Play(0.04)
	end

	-- Tactile tool recoil kickback in character hand
	task.spawn(function()
		local origGrip = tool.Grip
		tool.Grip = origGrip * CFrame.Angles(math.rad(-14), 0, 0) * CFrame.new(0, 0, -0.22)
		task.wait(0.07)
		if tool and tool.Parent then
			tool.Grip = origGrip
		end
	end)
end

local function onToolActivated(tool: Tool)
	local now = os.clock()
	local cooldown = tool:GetAttribute("Cooldown") or 0.45
	if now - lastSwingTime < (cooldown * 0.85) then return end
	lastSwingTime = now

	-- Instant responsive swing audio, trail flash, and character animation
	SoundController.playSwing()
	VFXController.pulseToolTrail(tool)
	playToolAnimation(tool, cooldown)

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local toolRange = (tool:GetAttribute("Range") or 22) + 4
	local closestModel: Model? = nil
	local closestDist = toolRange

	local scrapNodes = CollectionService:GetTagged("ScrapNode")
	local rootPos = root.Position

	for _, node in ipairs(scrapNodes) do
		if node:IsA("Model") and node.Parent then
			local hitbox = node:FindFirstChild("Hitbox")
			if hitbox and hitbox:IsA("BasePart") then
				local dist = (rootPos - hitbox.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestModel = node
				end
			end
		end
	end

	if closestModel then
		local requestAction = Remotes.getEvent("RequestAction")
		requestAction:FireServer(closestModel)
	end
end

local function hookTool(tool: Instance)
	if tool:IsA("Tool") and not hookedTools[tool :: Tool] and (tool:GetAttribute("IsScrapperTool") or tool.Name == "ScrapperTool" or tool.Name == "OmniScrapper" or tool.Name == "PlasmaDismantler" or tool:FindFirstChild("Handle")) then
		hookedTools[tool :: Tool] = true
		VFXController.attachToolTrail(tool :: Tool)
		tool.Activated:Connect(function()
			onToolActivated(tool :: Tool)
		end)
		tool.Destroying:Connect(function()
			hookedTools[tool :: Tool] = nil
		end)
	end
end

function ActionController.init()
	local function hookContainer(container: Instance)
		container.ChildAdded:Connect(hookTool)
		for _, child in ipairs(container:GetChildren()) do
			hookTool(child)
		end
	end

	local backpack = player:WaitForChild("Backpack")
	hookContainer(backpack)

	player.CharacterRemoving:Connect(function(character)
		if currentCharacter == character then
			clearCharacter()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		hookContainer(character)
		bindCharacter(character)
	end)
	if player.Character then
		hookContainer(player.Character)
		task.defer(bindCharacter, player.Character)
	end

	print("[ActionController] Initialized with 5-Tier Scrapper Tool animations and activation listener.")
end

return ActionController
