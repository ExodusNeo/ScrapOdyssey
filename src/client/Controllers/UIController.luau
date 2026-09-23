--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local UIController = {}

function UIController.init()
	local localPlayer = Players.LocalPlayer
	print(string.format("[UIController] Initialized for %s (Game: %s v%s)", localPlayer.Name, Config.GameName, Config.Version))
end

return UIController
