--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Remotes)

local ActionController = {}
local player = Players.LocalPlayer

local function onToolActivated()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local closestModel: Model? = nil
	local closestDist = 24

	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Model") and string.sub(desc.Name, 1, 10) == "ScrapPile_" then
			local hitbox = desc:FindFirstChild("Hitbox")
			if hitbox and hitbox:IsA("BasePart") then
				local dist = (root.Position - hitbox.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestModel = desc
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
	if tool:IsA("Tool") and tool.Name == "OmniScrapper" then
		tool.Activated:Connect(onToolActivated)
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

	print("[ActionController] Initialized with OmniScrapper tool listener.")
end

return ActionController
