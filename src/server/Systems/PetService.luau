--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local PetService = {}
local spawnedDrones: { [Player]: { Model } } = {}

function PetService.rollPet(): Types.PetTemplate
	local totalWeight = 0
	for _, pet in ipairs(Config.Pets.List) do
		totalWeight = totalWeight + pet.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, pet in ipairs(Config.Pets.List) do
		cumulative = cumulative + pet.Weight
		if roll <= cumulative then
			return pet
		end
	end

	return Config.Pets.List[1]
end

function PetService.hatchEgg(player: Player): Types.PetTemplate?
	local data = DataService.get(player)
	if not data then return nil end

	local cost = Config.Pets.EggCost
	if not CurrencyService.removeScrap(player, cost) then
		local notif = Remotes.getEvent("ShowNotification")
		notif:FireClient(player, "Not Enough Scrap", string.format("You need %d Scrap to hatch a drone.", cost), Color3.fromRGB(255, 70, 70))
		return nil
	end

	local rolled = PetService.rollPet()
	local newOwnedPet: Types.OwnedPet = {
		UUID = HttpService:GenerateGUID(false),
		Id = rolled.Id,
		Level = 1,
		Equipped = false,
	}

	table.insert(data.Pets, newOwnedPet)
	DataService.sync(player)

	-- Fire reveal event to client
	local hatchResult = Remotes.getEvent("HatchResult")
	hatchResult:FireClient(player, {
		Template = rolled,
		Pet = newOwnedPet,
	})

	return rolled
end

function PetService.toggleEquip(player: Player, uuid: string)
	local data = DataService.get(player)
	if not data then return end

	local targetPet: Types.OwnedPet? = nil
	local currentlyEquippedCount = 0

	for _, p in ipairs(data.Pets) do
		if p.UUID == uuid then
			targetPet = p
		end
		if p.Equipped then
			currentlyEquippedCount = currentlyEquippedCount + 1
		end
	end

	if not targetPet then return end

	if targetPet.Equipped then
		targetPet.Equipped = false
	else
		if currentlyEquippedCount >= Config.Defaults.MaxEquippedPets then
			local notif = Remotes.getEvent("ShowNotification")
			notif:FireClient(player, "Limit Reached", string.format("You can only equip up to %d drones at once.", Config.Defaults.MaxEquippedPets), Color3.fromRGB(255, 170, 0))
			return
		end
		targetPet.Equipped = true
	end

	DataService.sync(player)
	PetService.updateVisualDrones(player)
end

function PetService.updateVisualDrones(player: Player)
	-- Clean up old drones
	if spawnedDrones[player] then
		for _, m in ipairs(spawnedDrones[player]) do
			m:Destroy()
		end
	end
	spawnedDrones[player] = {}

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not rootPart then return end

	local data = DataService.get(player)
	if not data then return end

	local equippedPets = {}
	for _, p in ipairs(data.Pets) do
		if p.Equipped then
			table.insert(equippedPets, p)
		end
	end

	local petAngles = { -45, 45, 0 }
	local petDistances = { 5, 5, 7 }

	for i, pet in ipairs(equippedPets) do
		local template: Types.PetTemplate? = nil
		for _, t in ipairs(Config.Pets.List) do
			if t.Id == pet.Id then
				template = t
				break
			end
		end

		local droneModel = Instance.new("Model")
		droneModel.Name = "Drone_" .. (template and template.Name or "Pet")

		local dronePart = Instance.new("Part")
		dronePart.Name = "Body"
		dronePart.Size = Vector3.new(1.4, 1.4, 1.4)
		dronePart.Color = template and template.Color or Color3.fromRGB(200, 200, 200)
		dronePart.Material = Enum.Material.Neon
		dronePart.CanCollide = false
		dronePart.Anchored = true
		dronePart.Parent = droneModel

		-- Small billboard above drone showing name and multiplier
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 100, 0, 30)
		bb.StudsOffset = Vector3.new(0, 1.6, 0)
		bb.AlwaysOnTop = true
		bb.Parent = dronePart

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = template and template.Color or Color3.new(1, 1, 1)
		label.Text = string.format("%s (x%.1f)", template and template.Name or "Drone", template and template.Multiplier or 1.0)
		label.Parent = bb

		droneModel.Parent = Workspace
		table.insert(spawnedDrones[player], droneModel)

		-- Drone follower heartbeat
		local angleOffset = math.rad(petAngles[i] or 0)
		local dist = petDistances[i] or 5
		task.spawn(function()
			while droneModel.Parent and player.Parent and character.Parent do
				local currentPivot = rootPart.CFrame
				local targetCFrame = currentPivot * CFrame.Angles(0, angleOffset, 0) * CFrame.new(0, 2 + math.sin(os.clock() * 3 + i) * 0.4, dist)
				dronePart.CFrame = dronePart.CFrame:Lerp(targetCFrame, 0.2)
				task.wait(0.03)
			end
		end)
	end
end

function PetService.init()
	local hatchEvent = Remotes.getEvent("HatchEgg")
	hatchEvent.OnServerEvent:Connect(function(player)
		PetService.hatchEgg(player)
	end)

	local equipEvent = Remotes.getEvent("EquipPet")
	equipEvent.OnServerEvent:Connect(function(player, uuid)
		if type(uuid) == "string" then
			PetService.toggleEquip(player, uuid)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(1, function()
				PetService.updateVisualDrones(player)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if spawnedDrones[player] then
			for _, m in ipairs(spawnedDrones[player]) do
				m:Destroy()
			end
			spawnedDrones[player] = nil
		end
	end)

	print("[PetService] Initialized.")
end

return PetService
