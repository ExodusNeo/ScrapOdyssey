--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerService = {}

function PlayerService.onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.Player.DefaultWalkSpeed
	humanoid.JumpPower = Config.Player.DefaultJumpPower

	if Config.Debug then
		print(string.format("[PlayerService] %s spawned at %s", player.Name, tostring(character:GetPivot().Position)))
	end
end

function PlayerService.onPlayerAdded(player: Player)
	if Config.Debug then
		print(string.format("[PlayerService] Player joined: %s (%d)", player.Name, player.UserId))
	end

	player.CharacterAdded:Connect(function(character)
		PlayerService.onCharacterAdded(player, character)
	end)

	if player.Character then
		PlayerService.onCharacterAdded(player, player.Character)
	end
end

function PlayerService.onPlayerRemoving(player: Player)
	if Config.Debug then
		print(string.format("[PlayerService] Player left: %s", player.Name))
	end
end

function PlayerService.init()
	Players.RespawnTime = Config.Player.RespawnTime

	Players.PlayerAdded:Connect(PlayerService.onPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerService.onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerService.onPlayerAdded, player)
	end

	print("[PlayerService] Initialized successfully.")
end

return PlayerService
