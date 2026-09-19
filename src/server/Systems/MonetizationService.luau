--!strict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local MonetizationService = {}
local processedPurchases: { [string]: boolean } = {}

function MonetizationService.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	if processedPurchases[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player not currently in server, wait for rejoin
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Identify product and grant reward
	if productId == Config.Monetization.DevProducts.ScrapPackSmall then
		CurrencyService.addScrap(player, 10000, false)
	elseif productId == Config.Monetization.DevProducts.ScrapPackMedium then
		CurrencyService.addScrap(player, 100000, false)
	elseif productId == Config.Monetization.DevProducts.GearsPack then
		CurrencyService.addGears(player, 25)
	else
		-- Default grant for generic testing
		CurrencyService.addScrap(player, 5000, false)
	end

	processedPurchases[purchaseId] = true
	print(string.format("[MonetizationService] Processed purchase %s for %s", purchaseId, player.Name))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt
	print("[MonetizationService] Initialized with idempotent ProcessReceipt handling.")
end

return MonetizationService
