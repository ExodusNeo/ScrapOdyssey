--!strict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local MonetizationService = {}
local processedPurchases: { [string]: boolean } = {}

function MonetizationService.ownsGamepass(player: Player, passName: string): boolean
	local passes = Config.Monetization and Config.Monetization.Gamepasses
	if not passes then return false end

	local passId = passes[passName]
	if not passId then return false end

	local data = DataService.get(player)
	if passName == "SuperSprint" and data and data.HasSuperSprintPass == true then
		return true
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return success and owns == true
end

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
	local notif = Remotes.getEvent("ShowNotification")
	if productId == Config.Monetization.DevProducts.ScrapPackSmall then
		CurrencyService.addScrap(player, 10000, false)
		notif:FireClient(player, "PURCHASE SUCCESSFUL!", "+10,000 Scrap added to your account!", Color3.fromRGB(80, 220, 120))
	elseif productId == Config.Monetization.DevProducts.ScrapPackMedium then
		CurrencyService.addScrap(player, 100000, false)
		notif:FireClient(player, "PURCHASE SUCCESSFUL!", "+100,000 Scrap added to your account!", Color3.fromRGB(80, 220, 120))
	elseif productId == Config.Monetization.DevProducts.GearsPack then
		CurrencyService.addGears(player, 25)
		notif:FireClient(player, "PURCHASE SUCCESSFUL!", "+25 Prestige Gears added to your account!", Color3.fromRGB(60, 200, 255))
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

	-- Handle Gamepass Purchase Finished
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if not wasPurchased then return end

		print(string.format("[MonetizationService] Player %s purchased gamepass %d", player.Name, passId))
		local passes = Config.Monetization and Config.Monetization.Gamepasses
		if not passes then return end

		local notif = Remotes.getEvent("ShowNotification")

		if passId == passes.SuperSprint then
			local data = DataService.get(player)
			if data then
				data.HasSuperSprintPass = true
				DataService.sync(player)
			end
			notif:FireClient(player, "GAMEPASS UNLOCKED!", "Hyper Thrusters (+8 Sprint Speed, +4 Walk Speed) are now permanently active!", Color3.fromRGB(0, 220, 255))
		elseif passId == passes.DoubleScrap then
			notif:FireClient(player, "GAMEPASS UNLOCKED!", "2x Scrap Multiplier is now permanently active!", Color3.fromRGB(255, 200, 40))
		elseif passId == passes.AutoScrap then
			notif:FireClient(player, "GAMEPASS UNLOCKED!", "Auto-Scrapper Protocol is now permanently active!", Color3.fromRGB(80, 220, 120))
		elseif passId == passes.DoubleLuck then
			notif:FireClient(player, "GAMEPASS UNLOCKED!", "Quantum Luck Core (2x Rare Hatch) is now permanently active!", Color3.fromRGB(180, 70, 255))
		end
	end)

	-- Client RemoteFunction for checking pass ownership
	local checkGamepassFn = Remotes.getFunction("CheckGamepass")
	checkGamepassFn.OnServerInvoke = function(player: Player, passName: string)
		if type(passName) ~= "string" then return false end
		return MonetizationService.ownsGamepass(player, passName)
	end

	-- Client RemoteEvent for requesting marketplace prompt
	local promptGamepassEv = Remotes.getEvent("PromptGamepass")
	promptGamepassEv.OnServerEvent:Connect(function(player: Player, passName: any)
		if type(passName) ~= "string" then return end
		local passes = Config.Monetization and Config.Monetization.Gamepasses
		local passId = passes and passes[passName]
		if passId then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end
	end)

	local promptProductEv = Remotes.getEvent("PromptProduct")
	promptProductEv.OnServerEvent:Connect(function(player: Player, productName: any)
		if type(productName) ~= "string" then return end
		local prods = Config.Monetization and Config.Monetization.DevProducts
		local prodId = prods and prods[productName]
		if prodId then
			MarketplaceService:PromptProductPurchase(player, prodId)
		end
	end)

	print("[MonetizationService] Initialized with idempotent ProcessReceipt and Gamepass handling.")
end

return MonetizationService
