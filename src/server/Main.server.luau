--!strict
-- Main Server Bootstrapper for Scrap Odyssey
print("==================================================")
print("       SCRAP ODYSSEY: SERVER BOOTSTRAP            ")
print("==================================================")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.Remotes)

-- 1. Initialize Remotes first
Remotes.init()
print("[Bootstrapper] Remotes initialized.")

-- 2. Bootstrap Core Systems
local SystemsFolder = script.Parent.Systems

local DataService = require(SystemsFolder.DataService)
local CurrencyService = require(SystemsFolder.CurrencyService)
local ZoneService = require(SystemsFolder.ZoneService)
local ActionService = require(SystemsFolder.ActionService)

-- Optional later services
local function safeInit(name: string)
	local module = SystemsFolder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local success, err = pcall(function()
			local service = require(module)
			if type(service) == "table" and type(service.init) == "function" then
				service.init()
			end
		end)
		if success then
			print(string.format("[Bootstrapper] %s initialized.", name))
		else
			warn(string.format("[Bootstrapper] Failed to initialize %s: %s", name, tostring(err)))
		end
	end
end

-- Initialize Core & Progression Systems
safeInit("DataService")
safeInit("CurrencyService")
safeInit("ZoneService")
safeInit("ActionService")
safeInit("ShopService")
safeInit("BackpackService")
safeInit("PetService")
safeInit("RebirthService")
safeInit("QuestService")
safeInit("LeaderboardService")
safeInit("MonetizationService")
safeInit("DebugService")
safeInit("EventService")

print("==================================================")
print("       SCRAP ODYSSEY: SERVER READY!               ")
print("==================================================")
