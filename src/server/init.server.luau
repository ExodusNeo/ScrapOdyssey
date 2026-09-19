--!strict
-- Server Entry Point
print("========================================")
print("  Server Starting - MyRobloxGame       ")
print("========================================")

local ServicesFolder = script:WaitForChild("Services")
local PlayerService = require(ServicesFolder:WaitForChild("PlayerService"))

-- Initialize all server services
PlayerService.init()

print("[Server] All services initialized successfully.")
