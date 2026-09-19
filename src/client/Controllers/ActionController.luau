--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Remotes)

local ActionController = {}
local player = Players.LocalPlayer

function ActionController.init()
	-- Keyboard shortcut: Spacebar or E near nodes triggers prompt automatically
	print("[ActionController] Initialized.")
end

return ActionController
