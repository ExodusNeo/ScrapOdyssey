--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Types = require(ReplicatedStorage.Modules.Types)
local DataService = require(script.Parent.DataService)

local CurrencyService = {}

function CurrencyService.getMultiplier(player: Player): number
	local data = DataService.get(player)
	if not data then return 1.0 end

	-- 1. Base multiplier
	local multiplier = 1.0

	-- 2. Rebirth multiplier (+50% per rebirth)
	multiplier = multiplier + (data.Rebirths * Config.Rebirth.MultiplierPerRebirth)

	-- 3. Upgrade multiplier
	local scrapPowerLvl = data.Upgrades["ScrapPower"] or 1
	local powerConfig = Config.Upgrades.ScrapPower
	if powerConfig then
		multiplier = multiplier + ((scrapPowerLvl - 1) * powerConfig.EffectPerLevel)
	end

	-- 4. Equipped Pets multiplier
	for _, pet in ipairs(data.Pets) do
		if pet.Equipped then
			for _, template in ipairs(Config.Pets.List) do
				if template.Id == pet.Id then
					multiplier = multiplier * template.Multiplier
					break
				end
			end
		end
	end

	-- 5. Gears Prestige Perk: ScrapSurge (+100% permanent bonus)
	if data.GearsPerks and data.GearsPerks["ScrapSurge"] then
		multiplier = multiplier + 1.0
	end

	return math.max(1.0, multiplier)
end

function CurrencyService.addScrap(player: Player, baseAmount: number, applyMultiplier: boolean?): number
	local data = DataService.get(player)
	if not data then return 0 end

	local mult = 1.0
	if applyMultiplier ~= false then
		mult = CurrencyService.getMultiplier(player)
	end

	local finalAmount = math.floor(baseAmount * mult)
	data.Scrap = math.max(0, data.Scrap + finalAmount)
	data.TotalScrapsMined = (data.TotalScrapsMined or 0) + 1

	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)
	return finalAmount
end

function CurrencyService.removeScrap(player: Player, amount: number): boolean
	if amount <= 0 then return false end
	local data = DataService.get(player)
	if not data or data.Scrap < amount then return false end

	data.Scrap = data.Scrap - amount
	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)
	return true
end

function CurrencyService.addGears(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then return end

	data.Gears = math.max(0, data.Gears + amount)
	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)
end

function CurrencyService.removeGears(player: Player, amount: number): boolean
	if amount <= 0 then return false end
	local data = DataService.get(player)
	if not data or data.Gears < amount then return false end

	data.Gears = data.Gears - amount
	CurrencyService.updateLeaderstats(player)
	DataService.sync(player)
	return true
end

function CurrencyService.updateLeaderstats(player: Player)
	local data = DataService.get(player)
	if not data then return end

	local leaderstats = player:FindFirstChild("leaderstats") :: Folder
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local scrapStat = leaderstats:FindFirstChild("Scrap") :: StringValue
	if not scrapStat then
		scrapStat = Instance.new("StringValue")
		scrapStat.Name = "Scrap"
		scrapStat.Parent = leaderstats
	end
	scrapStat.Value = CurrencyService.formatNumber(data.Scrap)

	local rebirthsStat = leaderstats:FindFirstChild("Rebirths") :: IntValue
	if not rebirthsStat then
		rebirthsStat = Instance.new("IntValue")
		rebirthsStat.Name = "Rebirths"
		rebirthsStat.Parent = leaderstats
	end
	rebirthsStat.Value = data.Rebirths

	local gearsStat = leaderstats:FindFirstChild("Gears") :: IntValue
	if not gearsStat then
		gearsStat = Instance.new("IntValue")
		gearsStat.Name = "Gears"
		gearsStat.Parent = leaderstats
	end
	gearsStat.Value = data.Gears
end

function CurrencyService.formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

function CurrencyService.init()
	Players.PlayerAdded:Connect(function(player)
		-- Wait for data to load
		task.delay(0.5, function()
			CurrencyService.updateLeaderstats(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		CurrencyService.updateLeaderstats(player)
	end

	print("[CurrencyService] Initialized.")
end

return CurrencyService
