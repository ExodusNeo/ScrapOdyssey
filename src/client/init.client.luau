--!strict
-- Client Entry Point
local ControllersFolder = script:WaitForChild("Controllers")
local UIController = require(ControllersFolder:WaitForChild("UIController"))

UIController.init()

print("[Client] All controllers initialized successfully.")
