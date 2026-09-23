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

local function onToolActivated(tool: Tool)
	local now = os.clock()
	local cooldown = tool:GetAttribute("Cooldown") or 0.45
	if now - lastSwingTime < (cooldown * 0.85) then return end
	lastSwingTime = now

	-- Instant responsive swing audio & visual feedback
	SoundController.playSwing()
	VFXController.pulseToolTrail(tool)

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

	player.CharacterAdded:Connect(function(character)
		hookContainer(character)
	end)
	if player.Character then
		hookContainer(player.Character)
	end

	print("[ActionController] Initialized with 5-Tier Scrapper Tool activation listener.")
end

return ActionController
