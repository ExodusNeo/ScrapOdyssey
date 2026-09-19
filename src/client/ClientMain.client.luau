--!strict
-- Main Client Bootstrapper for Scrap Odyssey
print("==================================================")
print("       SCRAP ODYSSEY: CLIENT BOOTSTRAP            ")
print("==================================================")

local ControllersFolder = script.Parent:WaitForChild("Controllers")

local HUDController = require(ControllersFolder:WaitForChild("HUDController"))
local ActionController = require(ControllersFolder:WaitForChild("ActionController"))
local MenuController = require(ControllersFolder:WaitForChild("MenuController"))

HUDController.init()
ActionController.init()
MenuController.init()

print("==================================================")
print("       SCRAP ODYSSEY: CLIENT READY!               ")
print("==================================================")
