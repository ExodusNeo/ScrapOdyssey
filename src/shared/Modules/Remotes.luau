--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local REMOTE_EVENTS = {
	"RequestAction",
	"ActionCompleted",
	"SyncData",
	"PurchaseUpgrade",
	"RequestRebirth",
	"HatchEgg",
	"HatchResult",
	"EquipPet",
	"ClaimDailyReward",
	"RedeemCode",
	"CodeResult",
	"UnlockZone",
	"TeleportZone",
	"SendTrade",
	"TradeUpdate",
	"ShowNotification",
}

local REMOTE_FUNCTIONS = {
	"GetPlayerData",
}

local function getOrCreateFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		if RunService:IsServer() then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
		end
	end
	return folder
end

function Remotes.init()
	local folder = getOrCreateFolder()
	if RunService:IsServer() then
		for _, name in ipairs(REMOTE_EVENTS) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end

		for _, name in ipairs(REMOTE_FUNCTIONS) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

function Remotes.getEvent(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	local remote = folder:WaitForChild(name, 5) :: RemoteEvent
	if not remote and RunService:IsServer() then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

function Remotes.getFunction(name: string): RemoteFunction
	local folder = getOrCreateFolder()
	local remote = folder:WaitForChild(name, 5) :: RemoteFunction
	if not remote and RunService:IsServer() then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

return Remotes
