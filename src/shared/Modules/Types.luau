--!strict
export type CurrencyType = "Scrap" | "Gears"

export type RewardTier = {
	Name: string,
	Weight: number,
	Multiplier: number,
	Color: Color3,
	SoundPitch: number,
}

export type ZoneConfig = {
	Id: number,
	Name: string,
	UnlockCost: number,
	BaseYield: number,
	ActionTime: number,
	Color: Color3,
	Description: string,
}

export type UpgradeConfig = {
	Name: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number,
	CostMultiplier: number,
	EffectPerLevel: number,
}

export type GearsPerk = {
	Id: string,
	Name: string,
	Description: string,
	Cost: number,
	Icon: string,
}

export type PetTemplate = {
	Id: string,
	Name: string,
	Tier: string,
	Multiplier: number,
	Weight: number,
	Color: Color3,
}

export type OwnedPet = {
	UUID: string,
	Id: string,
	Level: number,
	Equipped: boolean,
}

export type QuestProgress = {
	Progress: number,
	Completed: boolean,
	Claimed: boolean,
}

export type PlayerData = {
	Version: number,
	Scrap: number,
	Backpack: number,
	Gears: number,
	Rebirths: number,
	CurrentZone: number,
	MaxZoneReached: number,
	Upgrades: { [string]: number },
	GearsPerks: { [string]: boolean },
	Pets: { OwnedPet },
	EquippedPetCount: number,
	InventoryCount: number,
	DailyLoginStreak: number,
	LastLoginTimestamp: number,
	RedeemedCodes: { [string]: boolean },
	TotalScrapsMined: number,
	Quests: { [string]: QuestProgress },
}

return {}
