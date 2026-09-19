--!strict
local Types = require(script.Parent.Types)

local Config
Config = {
	GameTitle = "Scrap Odyssey",
	Version = "1.0.0",
	Debug = true,

	-- Base player stats
	Defaults = {
		Scrap = 0,
		Backpack = 0,
		Gears = 0,
		Rebirths = 0,
		CurrentZone = 1,
		MaxZoneReached = 1,
		InventoryCount = 0,
		MaxEquippedPets = 3,
		BaseInventoryCapacity = 50,
		BaseActionTime = 1.0,
		BaseScrapYield = 10,
	},

	getBackpackCapacity = function(level: number): number
		level = level or 1
		return math.floor(50 * (1.6 ^ (level - 1)))
	end,

	-- Reward rarity tiers with weights and multipliers
	RewardTiers = {
		{
			Name = "Common",
			Weight = 600, -- 60%
			Multiplier = 1.0,
			Color = Color3.fromRGB(180, 180, 180),
			SoundPitch = 1.0,
		},
		{
			Name = "Uncommon",
			Weight = 250, -- 25%
			Multiplier = 2.5,
			Color = Color3.fromRGB(60, 210, 80),
			SoundPitch = 1.1,
		},
		{
			Name = "Rare",
			Weight = 100, -- 10%
			Multiplier = 6.0,
			Color = Color3.fromRGB(40, 140, 255),
			SoundPitch = 1.25,
		},
		{
			Name = "Epic",
			Weight = 40, -- 4%
			Multiplier = 15.0,
			Color = Color3.fromRGB(180, 50, 240),
			SoundPitch = 1.4,
		},
		{
			Name = "Legendary",
			Weight = 9, -- 0.9%
			Multiplier = 50.0,
			Color = Color3.fromRGB(255, 170, 0),
			SoundPitch = 1.6,
		},
		{
			Name = "Mythic",
			Weight = 1, -- 0.1%
			Multiplier = 250.0,
			Color = Color3.fromRGB(255, 40, 90),
			SoundPitch = 1.8,
		},
	} :: { Types.RewardTier },

	-- 5 Progressively unlocked zones
	Zones = {
		{
			Id = 1,
			Name = "Rusty Outpost",
			UnlockCost = 0,
			BaseYield = 10,
			ActionTime = 1.0,
			Color = Color3.fromRGB(140, 100, 70),
			Description = "A forgotten depot piled with rusted iron and copper cables.",
		},
		{
			Id = 2,
			Name = "Automotive Graveyard",
			UnlockCost = 500,
			BaseYield = 40,
			ActionTime = 1.2,
			Color = Color3.fromRGB(90, 120, 140),
			Description = "Crushed vehicles and electric motor batteries ripe for extraction.",
		},
		{
			Id = 3,
			Name = "Industrial Foundry",
			UnlockCost = 5000,
			BaseYield = 180,
			ActionTime = 1.5,
			Color = Color3.fromRGB(220, 100, 30),
			Description = "Abandoned blast furnaces and titanium hydraulic machinery.",
		},
		{
			Id = 4,
			Name = "Cybernetic Wasteland",
			UnlockCost = 50000,
			BaseYield = 750,
			ActionTime = 1.8,
			Color = Color3.fromRGB(30, 220, 200),
			Description = "Neon scrap, quantum microchips, and sentient AI circuits.",
		},
		{
			Id = 5,
			Name = "Orbital Crashsite",
			UnlockCost = 500000,
			BaseYield = 3500,
			ActionTime = 2.0,
			Color = Color3.fromRGB(160, 50, 255),
			Description = "Fallen starship wreckage containing antimatter warp drives.",
		},
	} :: { Types.ZoneConfig },

	-- Upgrades configuration
	Upgrades = {
		ScrapPower = {
			Name = "Scrapper Power",
			Description = "Increases scrap gathered per action",
			MaxLevel = 25,
			BaseCost = 25,
			CostMultiplier = 1.35,
			EffectPerLevel = 0.5, -- +50% per level
		},
		ScrapSpeed = {
			Name = "Scrap Speed",
			Description = "Reduces time required to dismantle scrap",
			MaxLevel = 15,
			BaseCost = 50,
			CostMultiplier = 1.45,
			EffectPerLevel = 0.04, -- -0.04s per level
		},
		BackpackCapacity = {
			Name = "Magnetic Cargo",
			Description = "Increases maximum scrap capacity before selling",
			MaxLevel = 20,
			BaseCost = 100,
			CostMultiplier = 1.50,
			EffectPerLevel = 50, -- +50 cap per level
		},
	} :: { [string]: Types.UpgradeConfig },

	-- Rebirth system
	Rebirth = {
		BaseCost = 100000,
		CostMultiplier = 3.0,
		MultiplierPerRebirth = 0.5, -- +50% permanent scrap multiplier
		GearsRewardFormula = function(currentRebirths: number): number
			return 1 + currentRebirths
		end,
	},

	-- Pet / Drone Hatching system
	Pets = {
		EggCost = 250,
		List = {
			{
				Id = "drone_rust",
				Name = "Rust Bot",
				Tier = "Common",
				Multiplier = 1.2,
				Weight = 50,
				Color = Color3.fromRGB(160, 130, 110),
			},
			{
				Id = "drone_spark",
				Name = "Spark Drone",
				Tier = "Uncommon",
				Multiplier = 1.6,
				Weight = 28,
				Color = Color3.fromRGB(80, 200, 120),
			},
			{
				Id = "drone_welder",
				Name = "Plasma Welder",
				Tier = "Rare",
				Multiplier = 2.5,
				Weight = 14,
				Color = Color3.fromRGB(50, 150, 255),
			},
			{
				Id = "drone_hound",
				Name = "Scrap Hound",
				Tier = "Epic",
				Multiplier = 5.0,
				Weight = 6,
				Color = Color3.fromRGB(180, 60, 240),
			},
			{
				Id = "drone_mech",
				Name = "Cyber Mech",
				Tier = "Legendary",
				Multiplier = 12.0,
				Weight = 1.8,
				Color = Color3.fromRGB(255, 170, 0),
			},
			{
				Id = "drone_titan",
				Name = "Void Titan",
				Tier = "Mythic",
				Multiplier = 30.0,
				Weight = 0.2,
				Color = Color3.fromRGB(255, 40, 100),
			},
		} :: { Types.PetTemplate },
	},

	-- The 3 Physical In-World Eggs located in the Hub
	Eggs = {
		RustEgg = {
			Id = "RustEgg",
			Name = "Rust Egg",
			Cost = 250,
			Color = Color3.fromRGB(160, 130, 110),
			Pool = {
				{ Id = "drone_rust", Weight = 65 },
				{ Id = "drone_spark", Weight = 35 },
			},
		},
		PlasmaEgg = {
			Id = "PlasmaEgg",
			Name = "Plasma Egg",
			Cost = 1500,
			Color = Color3.fromRGB(50, 150, 255),
			Pool = {
				{ Id = "drone_welder", Weight = 70 },
				{ Id = "drone_hound", Weight = 30 },
			},
		},
		CyberEgg = {
			Id = "CyberEgg",
			Name = "Cyber Egg",
			Cost = 10000,
			Color = Color3.fromRGB(255, 40, 100),
			Pool = {
				{ Id = "drone_mech", Weight = 85 },
				{ Id = "drone_titan", Weight = 15 },
			},
		},
	},

	-- Gears Prestige Shop (High-value permanent perks)
	GearsShop = {
		AutoScrap = {
			Id = "AutoScrap",
			Name = "Auto-Scrapper Protocol",
			Description = "Hands-free dismantling! Automatically strikes nearest scrap pile every 1.5s.",
			Cost = 3,
			Icon = "🤖",
		},
		SuperLuck = {
			Id = "SuperLuck",
			Name = "Quantum Luck Core",
			Description = "Permanently doubles the probability of Rare, Epic, Legendary, and Mythic drops!",
			Cost = 5,
			Icon = "🍀",
		},
		SpeedDemon = {
			Id = "SpeedDemon",
			Name = "Hydraulic Thrusters",
			Description = "Permanently enhances character sprint speed to 26 WalkSpeed!",
			Cost = 2,
			Icon = "⚡",
		},
		QuantumDrone = {
			Id = "QuantumDrone",
			Name = "Apex Quantum Drone",
			Description = "Grants an exclusive Mythic companion with a massive +15.0x Scrap multiplier!",
			Cost = 8,
			Icon = "👑",
		},
		ScrapSurge = {
			Id = "ScrapSurge",
			Name = "Scrap Overcharge",
			Description = "Permanently grants an extra +100% (+1.0x) bonus Scrap multiplier on all actions.",
			Cost = 4,
			Icon = "💥",
		},
	} :: { [string]: Types.GearsPerk },

	-- Promo codes
	Codes = {
		["RELEASE"] = { Type = "Scrap", Amount = 500 },
		["SCRAPPER"] = { Type = "Scrap", Amount = 2500 },
		["GEARS"] = { Type = "Gears", Amount = 5 },
	},

	-- Daily rewards (streak 1 to 7)
	DailyRewards = {
		{ Day = 1, Type = "Scrap", Amount = 200 },
		{ Day = 2, Type = "Scrap", Amount = 600 },
		{ Day = 3, Type = "Gears", Amount = 2 },
		{ Day = 4, Type = "Scrap", Amount = 2000 },
		{ Day = 5, Type = "Gears", Amount = 5 },
		{ Day = 6, Type = "Scrap", Amount = 10000 },
		{ Day = 7, Type = "Gears", Amount = 15 },
	},

	-- Daily Quests
	Quests = {
		{
			Id = "scrap_50",
			Description = "Scrap 50 Junk Piles",
			Target = 50,
			RewardType = "Scrap",
			RewardAmount = 1500,
		},
		{
			Id = "earn_10k",
			Description = "Earn 10,000 Total Scrap",
			Target = 10000,
			RewardType = "Gears",
			RewardAmount = 3,
		},
		{
			Id = "hatch_2",
			Description = "Hatch 2 Scrapper Drones",
			Target = 2,
			RewardType = "Scrap",
			RewardAmount = 3000,
		},
	},

	-- 5 Tiers of 3D Scrapper Tools (Unlockable in Tool Armory)
	Tools = {
		{
			Id = "OmniWrench",
			Name = "Omni-Wrench",
			Tier = 1,
			Cost = 0,
			Damage = 1,
			Cooldown = 0.50,
			Range = 22,
			Color = Color3.fromRGB(240, 160, 40),
			Description = "Standard issue titanium lug wrench. Reliable and sturdy.",
			Emoji = "🔧",
		},
		{
			Id = "PneumaticDrill",
			Name = "Pneumatic Jackdrill",
			Tier = 2,
			Cost = 5000,
			Damage = 2,
			Cooldown = 0.40,
			Range = 24,
			Color = Color3.fromRGB(255, 120, 20),
			Description = "High-frequency percussive impact drill designed for crushed cyber-metal.",
			Emoji = "🔩",
		},
		{
			Id = "PlasmaCutter",
			Name = "Thermal Plasma Torch",
			Tier = 3,
			Cost = 35000,
			Damage = 4,
			Cooldown = 0.32,
			Range = 26,
			Color = Color3.fromRGB(40, 180, 255),
			Description = "Industrial cutting laser that slices through high-tensile titanium with ease.",
			Emoji = "🔥",
		},
		{
			Id = "CyberScythe",
			Name = "Cyber Energy Scythe",
			Tier = 4,
			Cost = 250000,
			Damage = 8,
			Cooldown = 0.25,
			Range = 28,
			Color = Color3.fromRGB(255, 45, 125),
			Description = "Electrified high-density carbon scythe that cleaves massive quantum alloy.",
			Emoji = "⚡",
		},
		{
			Id = "VoidRipper",
			Name = "Void Singularity Ripper",
			Tier = 5,
			Cost = 1500000,
			Damage = 16,
			Cooldown = 0.18,
			Range = 32,
			Color = Color3.fromRGB(175, 60, 255),
			Description = "Experimental gravity-warping blade that fractures molecular scrap bonds in seconds.",
			Emoji = "🌌",
		},
	} :: { Types.ToolConfig },

	getTool = function(toolId: string): Types.ToolConfig?
		for _, t in ipairs(Config.Tools) do
			if t.Id == toolId then
				return t
			end
		end
		return Config.Tools[1]
	end,

	-- Developer products & Gamepasses
	Monetization = {
		Gamepasses = {
			DoubleScrap = 0, -- ID set when published
			AutoScrap = 0,
			DoubleLuck = 0,
		},
		DevProducts = {
			ScrapPackSmall = 0,
			ScrapPackMedium = 0,
			GearsPack = 0,
		},
	},
}

return Config
