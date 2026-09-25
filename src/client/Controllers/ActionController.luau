--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Modules.Remotes)
local controllersFolder = (script and script.Parent) or game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")
local SoundController = require(controllersFolder:WaitForChild("SoundController"))
local VFXController = require(controllersFolder:WaitForChild("VFXController"))

local ActionController = {}
local player = Players.LocalPlayer

local lastSwingTime = 0
local hookedTools: { [Tool]: boolean } = {}
local comboStep = 0
local currentEquippedTool: Tool? = nil
local isHoldingAttack = false

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

	-- Strictly upper-body only strike animations (Right Arm & Upper Torso)
	-- NEVER include lower body / leg / hip keyframes so the player's legs run smoothly without freezing
	local chopId = isR15 and "rbxassetid://507768375" or "rbxassetid://129967390"
	local slashId = isR15 and "rbxassetid://522635514" or "rbxassetid://129967390"

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
		loadTrack(chopId, "Chop")
		loadTrack(slashId, "Slash")
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
		trackToPlay = loadedTracks["Chop"] or loadedTracks["Slash"]
		animSpeed = baseRate * 1.35
	elseif toolId == "PlasmaCutter" then
		trackToPlay = loadedTracks["Slash"] or loadedTracks["Chop"]
		animSpeed = baseRate * 1.25
	elseif toolId == "CyberScythe" then
		trackToPlay = loadedTracks["Slash"] or loadedTracks["Chop"]
		animSpeed = baseRate * 1.15
	elseif toolId == "VoidRipper" then
		comboStep = (comboStep % 2) + 1
		if comboStep == 1 then
			trackToPlay = loadedTracks["Slash"] or loadedTracks["Chop"]
		else
			trackToPlay = loadedTracks["Chop"] or loadedTracks["Slash"]
		end
		animSpeed = baseRate * 1.2
	else
		-- OmniWrench / Default
		trackToPlay = loadedTracks["Chop"] or loadedTracks["Slash"]
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

local function isTargetableScrapNode(instance: Instance?): Model?
	if not instance then return nil end
	local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
	if not model or not model:IsDescendantOf(Workspace) then return nil end

	if CollectionService:HasTag(model, "ScrapNode")
		or model:GetAttribute("IsScrapPile")
		or model:GetAttribute("IsOrbitalPod")
		or model.Name:find("ScrapPile")
		or model.Name:find("OrbitalPod") then
		return model
	end
	return nil
end

local function getNodeHitbox(model: Model): BasePart?
	return (model:FindFirstChild("Hitbox") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) :: BasePart?
end

local function calculateNodeDistance(rootPos: Vector3, hitbox: BasePart): number
	local radius = hitbox.Size.Magnitude * 0.35
	return math.max(0, (rootPos - hitbox.Position).Magnitude - radius)
end

local function getBestScrapTarget(character: Model, toolRange: number): Model?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local rootPos = root.Position
	local lookVector = root.CFrame.LookVector
	local camera = Workspace.CurrentCamera

	-- Priority 1: Direct Mouse Target / Cursor Aim
	local mouse = player:GetMouse()
	if mouse and mouse.Target then
		local targetModel = isTargetableScrapNode(mouse.Target)
		if targetModel then
			local hitbox = getNodeHitbox(targetModel)
			if hitbox then
				local dist = calculateNodeDistance(rootPos, hitbox)
				if dist <= toolRange then
					return targetModel
				end
			end
		end
	end

	-- Priority 2: Center-screen / Camera Aim Raycast (crosshair / first-person / third-person view)
	if camera then
		local rayOrigin = camera.CFrame.Position
		local rayDir = camera.CFrame.LookVector * (toolRange + 30)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { character }
		rayParams.IgnoreWater = true

		local rayResult = Workspace:Raycast(rayOrigin, rayDir, rayParams)
		if rayResult and rayResult.Instance then
			local targetModel = isTargetableScrapNode(rayResult.Instance)
			if targetModel then
				local hitbox = getNodeHitbox(targetModel)
				if hitbox then
					local dist = calculateNodeDistance(rootPos, hitbox)
					if dist <= toolRange then
						return targetModel
					end
				end
			end
		end
	end

	-- Priority 3: Spatial Cone & Proximity Scoring across Candidate Nodes
	local candidates: { [Model]: boolean } = {}
	for _, node in ipairs(CollectionService:GetTagged("ScrapNode")) do
		if node:IsA("Model") and node.Parent then
			candidates[node] = true
		end
	end

	-- Hierarchy fallbacks in case tags are still replicating
	local hub = Workspace:FindFirstChild("CentralHub")
	if hub then
		for _, child in ipairs(hub:GetChildren()) do
			if child:IsA("Model") and (child.Name:find("ScrapPile") or child.Name:find("OrbitalPod")) then
				candidates[child] = true
			end
		end
	end
	for i = 2, 5 do
		local zFolder = Workspace:FindFirstChild("Zone_" .. tostring(i))
		if zFolder then
			for _, child in ipairs(zFolder:GetChildren()) do
				if child:IsA("Model") and (child.Name:find("ScrapPile") or child.Name:find("OrbitalPod")) then
					candidates[child] = true
				end
			end
		end
	end
	local podsFolder = Workspace:FindFirstChild("OrbitalPods")
	if podsFolder then
		for _, child in ipairs(podsFolder:GetChildren()) do
			if child:IsA("Model") then
				candidates[child] = true
			end
		end
	end

	local bestModel: Model? = nil
	local bestScore = -9999

	for node in pairs(candidates) do
		local hitbox = getNodeHitbox(node)
		if hitbox then
			local dist = calculateNodeDistance(rootPos, hitbox)
			if dist <= toolRange then
				local toNode = hitbox.Position - rootPos
				local dirToNode = if toNode.Magnitude > 0.01 then toNode.Unit else lookVector
				local forwardDot = lookVector:Dot(dirToNode)

				local camDot = forwardDot
				if camera then
					camDot = camera.CFrame.LookVector:Dot(dirToNode)
				end
				local effectiveDot = math.max(forwardDot, camDot)

				-- Score formula:
				-- Highly rewards frontal alignment so you strike what you look at
				-- Heavily penalizes targets behind the player so back-hits never occur
				local distScore = (1 - (dist / toolRange)) * 50
				local angleScore = effectiveDot * 40
				if effectiveDot < 0 then
					angleScore = angleScore - 50
				end
				local totalScore = distScore + angleScore

				if totalScore > bestScore then
					bestScore = totalScore
					bestModel = node
				end
			end
		end
	end

	return bestModel
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

	local toolRange = (tool:GetAttribute("Range") or 8) + 2
	local targetModel = getBestScrapTarget(character, toolRange)

	if targetModel then
		local requestAction = Remotes.getEvent("RequestAction")
		if requestAction then
			requestAction:FireServer(targetModel)
		end
	end
end

local function hookTool(tool: Instance)
	if tool:IsA("Tool") and not hookedTools[tool :: Tool] and (tool:GetAttribute("IsScrapperTool") or tool.Name == "ScrapperTool" or tool.Name == "OmniScrapper" or tool.Name == "PlasmaDismantler" or tool:FindFirstChild("Handle")) then
		local t = tool :: Tool
		hookedTools[t] = true
		VFXController.attachToolTrail(t)

		t.Equipped:Connect(function()
			currentEquippedTool = t
		end)

		t.Unequipped:Connect(function()
			if currentEquippedTool == t then
				currentEquippedTool = nil
			end
			isHoldingAttack = false
		end)

		t.Activated:Connect(function()
			onToolActivated(t)
		end)

		t.Destroying:Connect(function()
			hookedTools[t] = nil
			if currentEquippedTool == t then
				currentEquippedTool = nil
			end
			isHoldingAttack = false
		end)

		if t.Parent == player.Character then
			currentEquippedTool = t
		end
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
		currentEquippedTool = nil
		isHoldingAttack = false
	end)
	player.CharacterAdded:Connect(function(character)
		hookContainer(character)
		bindCharacter(character)
	end)
	if player.Character then
		hookContainer(player.Character)
		task.defer(bindCharacter, player.Character)
	end

	-- Continuous hold-to-swing mining on Mouse/Touch input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if currentEquippedTool and currentEquippedTool.Parent == player.Character then
				isHoldingAttack = true
				onToolActivated(currentEquippedTool)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isHoldingAttack = false
		end
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		isHoldingAttack = false
	end)

	RunService.Heartbeat:Connect(function()
		if isHoldingAttack and currentEquippedTool and currentEquippedTool.Parent == player.Character then
			local cooldown = currentEquippedTool:GetAttribute("Cooldown") or 0.45
			local now = os.clock()
			if now - lastSwingTime >= cooldown then
				onToolActivated(currentEquippedTool)
			end
		end
	end)

	print("[ActionController] Initialized with precision aim targeting, smart directional cone, and hold-to-swing mining.")
end

return ActionController
