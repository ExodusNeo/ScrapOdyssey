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
		return math.floor(50 * (1.24 ^ (level - 1)))
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

	-- 5 Progressively unlocked zones with calibrated long-term progression
	Zones = {
		{
			Id = 1,
			Name = "Rusty Outpost",
			UnlockCost = 0,
			BaseYield = 10,
			ActionTime = 1.0,
			Color = Color3.fromRGB(140, 100, 70),
			Description = "A forgotten depot piled with rusted iron and copper cables.",
			BaseHP = 3,
			DenseHP = 6,
			DenseYieldMultiplier = 2.0,
		},
		{
			Id = 2,
			Name = "Automotive Graveyard",
			UnlockCost = 2500,
			BaseYield = 35,
			ActionTime = 1.2,
			Color = Color3.fromRGB(90, 120, 140),
			Description = "Crushed vehicles and electric motor batteries ripe for extraction.",
			BaseHP = 8,
			DenseHP = 16,
			DenseYieldMultiplier = 2.0,
		},
		{
			Id = 3,
			Name = "Industrial Foundry",
			UnlockCost = 35000,
			BaseYield = 140,
			ActionTime = 1.5,
			Color = Color3.fromRGB(220, 100, 30),
			Description = "Abandoned blast furnaces and titanium hydraulic machinery.",
			BaseHP = 20,
			DenseHP = 40,
			DenseYieldMultiplier = 2.2,
		},
		{
			Id = 4,
			Name = "Cybernetic Wasteland",
			UnlockCost = 350000,
			BaseYield = 650,
			ActionTime = 1.8,
			Color = Color3.fromRGB(30, 220, 200),
			Description = "Neon scrap, quantum microchips, and sentient AI circuits.",
			BaseHP = 50,
			DenseHP = 100,
			DenseYieldMultiplier = 2.5,
		},
		{
			Id = 5,
			Name = "Orbital Crashsite",
			UnlockCost = 2500000,
			BaseYield = 3000,
			ActionTime = 2.0,
			Color = Color3.fromRGB(160, 50, 255),
			Description = "Fallen starship wreckage containing antimatter warp drives.",
			BaseHP = 120,
			DenseHP = 250,
			DenseYieldMultiplier = 3.0,
		},
	} :: { Types.ZoneConfig },

	-- Upgrades configuration (Expanded 40-50 levels for sustained progression)
	Upgrades = {
		ScrapPower = {
			Name = "Scrapper Power",
			Description = "Increases scrap gathered per action",
			MaxLevel = 50,
			BaseCost = 50,
			CostMultiplier = 1.22,
			EffectPerLevel = 0.20, -- +20% per level (+980% bonus at max)
		},
		ScrapSpeed = {
			Name = "Scrap Speed",
			Description = "Reduces time required to dismantle scrap",
			MaxLevel = 25,
			BaseCost = 75,
			CostMultiplier = 1.26,
			EffectPerLevel = 0.015, -- -0.015s per level (-0.36s at max)
		},
		BackpackCapacity = {
			Name = "Magnetic Cargo",
			Description = "Increases maximum scrap capacity before selling",
			MaxLevel = 40,
			BaseCost = 100,
			CostMultiplier = 1.24,
			EffectPerLevel = 1, -- Scales smoothly via getBackpackCapacity
		},
	} :: { [string]: Types.UpgradeConfig },

	-- Rebirth system (Late-game prestige requiring Zone 5 with instant reward gratification)
	Rebirth = {
		BaseCost = 5000000,
		RequiredZone = 5,
		CostMultiplier = 3.0,
		MultiplierPerRebirth = 0.75, -- +75% permanent scrap multiplier
		GearsRewardFormula = function(currentRebirths: number): number
			return 3 + (currentRebirths * 2)
		end,
	},

	-- Pet / Drone Hatching system (Additive bonuses to prevent runaway exponential inflation)
	Pets = {
		EggCost = 500,
		List = {
			{
				Id = "drone_rust",
				Name = "Rust Bot",
				Tier = "Common",
				Multiplier = 0.25, -- +25% Scrap
				Weight = 50,
				Color = Color3.fromRGB(160, 130, 110),
			},
			{
				Id = "drone_spark",
				Name = "Spark Drone",
				Tier = "Uncommon",
				Multiplier = 0.60, -- +60% Scrap
				Weight = 28,
				Color = Color3.fromRGB(80, 200, 120),
			},
			{
				Id = "drone_welder",
				Name = "Plasma Welder",
				Tier = "Rare",
				Multiplier = 1.50, -- +150% Scrap
				Weight = 14,
				Color = Color3.fromRGB(50, 150, 255),
			},
			{
				Id = "drone_hound",
				Name = "Scrap Hound",
				Tier = "Epic",
				Multiplier = 3.50, -- +350% Scrap
				Weight = 6,
				Color = Color3.fromRGB(180, 60, 240),
			},
			{
				Id = "drone_mech",
				Name = "Cyber Mech",
				Tier = "Legendary",
				Multiplier = 8.00, -- +800% Scrap
				Weight = 1.8,
				Color = Color3.fromRGB(255, 170, 0),
			},
			{
				Id = "drone_titan",
				Name = "Void Titan",
				Tier = "Mythic",
				Multiplier = 20.00, -- +2,000% Scrap
				Weight = 0.2,
				Color = Color3.fromRGB(255, 40, 100),
			},
		} :: { Types.PetTemplate },
	},

	-- The 5 Physical In-World Egg Pods distributed across Zones 1 to 5
	Eggs = {
		RustEgg = {
			Id = "RustEgg",
			Name = "Rust Egg",
			ZoneId = 1,
			Cost = 500,
			Color = Color3.fromRGB(160, 130, 110),
			SubText = "Rust Bot (+25%)\nSpark Drone (+60%)",
			Pool = {
				{ Id = "drone_rust", Weight = 70 },
				{ Id = "drone_spark", Weight = 30 },
			},
		},
		JunkyardEgg = {
			Id = "JunkyardEgg",
			Name = "Junkyard Egg",
			ZoneId = 2,
			Cost = 7500,
			Color = Color3.fromRGB(90, 150, 180),
			SubText = "Spark Drone (+60%)\nPlasma Welder (+150%)",
			Pool = {
				{ Id = "drone_spark", Weight = 65 },
				{ Id = "drone_welder", Weight = 35 },
			},
		},
		FoundryEgg = {
			Id = "FoundryEgg",
			Name = "Foundry Egg",
			ZoneId = 3,
			Cost = 75000,
			Color = Color3.fromRGB(220, 110, 30),
			SubText = "Plasma Welder (+150%)\nScrap Hound (+350%)",
			Pool = {
				{ Id = "drone_welder", Weight = 60 },
				{ Id = "drone_hound", Weight = 40 },
			},
		},
		CyberEgg = {
			Id = "CyberEgg",
			Name = "Cyber Egg",
			ZoneId = 4,
			Cost = 600000,
			Color = Color3.fromRGB(30, 220, 200),
			SubText = "Scrap Hound (+350%)\nCyber Mech (+800%)",
			Pool = {
				{ Id = "drone_hound", Weight = 65 },
				{ Id = "drone_mech", Weight = 35 },
			},
		},
		VoidEgg = {
			Id = "VoidEgg",
			Name = "Void Egg",
			ZoneId = 5,
			Cost = 4000000,
			Color = Color3.fromRGB(180, 50, 255),
			SubText = "Cyber Mech (+800%)\nVoid Titan (+2,000%)",
			Pool = {
				{ Id = "drone_mech", Weight = 75 },
				{ Id = "drone_titan", Weight = 25 },
			},
		},
		-- Backward-compatibility alias
		PlasmaEgg = {
			Id = "PlasmaEgg",
			Name = "Foundry Egg",
			ZoneId = 3,
			Cost = 75000,
			Color = Color3.fromRGB(220, 110, 30),
			SubText = "Plasma Welder (60%)\nScrap Hound (40%)",
			Pool = {
				{ Id = "drone_welder", Weight = 60 },
				{ Id = "drone_hound", Weight = 40 },
			},
		},
	},

	-- Gears Prestige Shop (High-value permanent perks)
	GearsShop = {
		AutoScrap = {
			Id = "AutoScrap",
			Name = "Auto-Scrapper Protocol",
			Description = "Hands-free dismantling. Automatically strikes nearest scrap pile every 1.5s.",
			Cost = 3,
			Icon = "⚙️",
		},
		SuperLuck = {
			Id = "SuperLuck",
			Name = "Quantum Luck Core",
			Description = "Permanently doubles the probability of Rare, Epic, Legendary, and Mythic drops.",
			Cost = 5,
			Icon = "🍀",
		},
		SpeedDemon = {
			Id = "SpeedDemon",
			Name = "Speed Demon",
			Description = "Permanently boosts base walk speed (+2) and sprint speed to 32 WalkSpeed.",
			Cost = 2,
			Icon = "⚡",
		},
		QuantumDrone = {
			Id = "QuantumDrone",
			Name = "Apex Quantum Drone",
			Description = "Grants an exclusive Mythic companion with a massive +10.0x (+1,000%) Scrap multiplier.",
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
		{ Day = 2, Type = "Scrap", Amount = 500 },
		{ Day = 3, Type = "Gears", Amount = 1 },
		{ Day = 4, Type = "Scrap", Amount = 1500 },
		{ Day = 5, Type = "Scrap", Amount = 3500 },
		{ Day = 6, Type = "Gears", Amount = 2 },
		{ Day = 7, Type = "Gears", Amount = 5 },
	},

	-- Quests (Daily cycling objectives)
	Quests = {
		{
			Id = "Scrap_50",
			Description = "Scrap 50 items",
			Target = 50,
			RewardType = "Scrap",
			RewardAmount = 1500,
		},
		{
			Id = "Dismantle_Rare",
			Description = "Dismantle 10 Dense Scrap nodes",
			Target = 10,
			RewardType = "Scrap",
			RewardAmount = 5000,
		},
		{
			Id = "Recycle_200",
			Description = "Recycle 200 Scrap at Central Hub",
			Target = 200,
			RewardType = "Gears",
			RewardAmount = 1,
		},
	},

	-- 5 Tools (Upgraded Dismantlers calibrated with zone tiers)
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
			Cost = 3500,
			Damage = 2,
			Cooldown = 0.40,
			Range = 24,
			Color = Color3.fromRGB(255, 120, 20),
			Description = "High-frequency percussive impact drill designed for crushed cyber-metal.",
			Emoji = "🔨",
		},
		{
			Id = "PlasmaCutter",
			Name = "Thermal Plasma Torch",
			Tier = 3,
			Cost = 45000,
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
			Cost = 400000,
			Damage = 8,
			Cooldown = 0.24,
			Range = 28,
			Color = Color3.fromRGB(255, 45, 125),
			Description = "Electrified high-density carbon scythe that cleaves massive quantum alloy.",
			Emoji = "⚔️",
		},
		{
			Id = "VoidRipper",
			Name = "Void Singularity Ripper",
			Tier = 5,
			Cost = 3000000,
			Damage = 16,
			Cooldown = 0.18,
			Range = 32,
			Color = Color3.fromRGB(175, 60, 255),
			Description = "Experimental gravity-warping blade that fractures molecular scrap bonds in seconds.",
			Emoji = "🌀",
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

	-- Active Gameplay Engagement: Combos & Critical Salvage
	Engagement = {
		ComboWindow = 3.8, -- Seconds before combo resets
		MaxCombo = 10, -- Maximum combo streak
		BonusPerCombo = 0.05, -- +5% scrap bonus per combo tier (up to +45% at x10)
		CritChance = 0.12, -- 12% critical salvage chance
		CritMultiplier = 2.0, -- 2x yield on critical strike
	},

	-- Character Movement & Sprinting
	Sprint = {
		DefaultWalkSpeed = 16,
		DefaultSprintSpeed = 26,
		SpeedDemonBonus = 6,
		SuperSprintBonus = 8,
		FovWalk = 70,
		FovSprint = 78,
		FovTweenTime = 0.25,
	},

	-- Developer products & Gamepasses
	Monetization = {
		Gamepasses = {
			DoubleScrap = 1985757130,
			AutoScrap = 1987292876,
			DoubleLuck = 1982739466,
			SuperSprint = 1986513102,
		},
		GamepassDetails = {
			SuperSprint = {
				Id = 1986513102,
				Name = "Hyper Thrusters",
				Description = "+8 Sprint Speed, +4 Walk Speed, and dynamic warp camera FOV!",
				Price = 149,
				Icon = "⚡",
				Color = Color3.fromRGB(0, 220, 255),
			},
			DoubleScrap = {
				Id = 1985757130,
				Name = "2x Scrap Multiplier",
				Description = "Permanently doubles all scrap collected across every world.",
				Price = 199,
				Icon = "💰",
				Color = Color3.fromRGB(255, 200, 40),
			},
			AutoScrap = {
				Id = 1987292876,
				Name = "Auto-Scrapper Protocol",
				Description = "Hands-free dismantling! Automatically strikes nearest nodes.",
				Price = 299,
				Icon = "⚙️",
				Color = Color3.fromRGB(80, 220, 120),
			},
			DoubleLuck = {
				Id = 1982739466,
				Name = "Quantum Luck Core",
				Description = "Doubles the hatch chance for Epic, Legendary, and Mythic drones!",
				Price = 399,
				Icon = "🍀",
				Color = Color3.fromRGB(180, 70, 255),
			},
		},
		DevProducts = {
			ScrapPackSmall = 3713740033,
			ScrapPackMedium = 3713740070,
			GearsPack = 3713740130,
		},
	},
}

return Config
