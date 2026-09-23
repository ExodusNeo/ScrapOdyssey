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
	"PurchaseGearsPerk",
	"RecycleScrap",
	"RecycleCompleted",
	"SendTrade",
	"TradeUpdate",
	"ShowNotification",
	"ClaimQuest",
	"DebugAction",
	"PurchaseTool",
	"EquipTool",
	"OrbitalEventAnnounce",
	"OrbitalEventImpact",
	"PromptGamepass",
	"PromptProduct",
	"CompleteTutorial",
}

local REMOTE_FUNCTIONS = {
	"GetPlayerData",
	"CheckGamepass",
}

local function isServerOrEdit(): boolean
	return RunService:IsServer() or RunService:IsEdit()
end

local function getOrCreateFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not folder then
		if isServerOrEdit() then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder?
		end
	end
	return folder or ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.init()
	local folder = getOrCreateFolder()
	if isServerOrEdit() then
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
	local remote = folder:FindFirstChild(name) :: RemoteEvent?
	if not remote then
		if isServerOrEdit() then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name, 8) :: RemoteEvent?
		end
	end
	return remote :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	local folder = getOrCreateFolder()
	local remote = folder:FindFirstChild(name) :: RemoteFunction?
	if not remote then
		if isServerOrEdit() then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name, 8) :: RemoteFunction?
		end
	end
	return remote :: RemoteFunction
end

return Remotes
