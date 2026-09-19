--!strict
-- Shared game configuration

local Config = {
	GameName = "MyRobloxGame",
	Version = "0.1.0",
	Debug = true,

	Player = {
		DefaultWalkSpeed = 16,
		DefaultJumpPower = 50,
		RespawnTime = 3,
	},
}

return table.freeze(Config)
