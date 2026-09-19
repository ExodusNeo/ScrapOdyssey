--!strict
-- Main Client Bootstrapper for Scrap Odyssey
print("==================================================")
print("       SCRAP ODYSSEY: CLIENT BOOTSTRAP            ")
print("==================================================")

local ControllersFolder = script.Parent:WaitForChild("Controllers")

local SoundController = require(ControllersFolder:WaitForChild("SoundController"))
local VFXController = require(ControllersFolder:WaitForChild("VFXController"))
local HUDController = require(ControllersFolder:WaitForChild("HUDController"))
local ActionController = require(ControllersFolder:WaitForChild("ActionController"))
local MenuController = require(ControllersFolder:WaitForChild("MenuController"))

SoundController.init()
VFXController.init()
HUDController.init()
ActionController.init()
MenuController.init()

print("==================================================")
print("       SCRAP ODYSSEY: CLIENT READY!               ")
print("==================================================")
