--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local LeaderboardService = {}

local boardPart: Part
local surfaceGui: SurfaceGui
local listContainer: Frame

function LeaderboardService.createInWorldBoard()
	local model = Instance.new("Model")
	model.Name = "GlobalLeaderboard"

	boardPart = Instance.new("Part")
	boardPart.Name = "Display"
	boardPart.Size = Vector3.new(16, 12, 1)
	boardPart.Position = Vector3.new(0, 9, -20)
	boardPart.Anchored = true
	boardPart.Material = Enum.Material.SmoothPlastic
	boardPart.Color = Color3.fromRGB(20, 20, 25)
	boardPart.Parent = model

	-- Stylized border
	local border = Instance.new("Part")
	border.Name = "Border"
	border.Size = Vector3.new(16.4, 12.4, 0.8)
	border.Position = Vector3.new(0, 9, -20.1)
	border.Anchored = true
	border.Material = Enum.Material.SmoothPlastic
	border.Color = Color3.fromRGB(200, 140, 30)
	border.Parent = model

	surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = boardPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 36
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Text = "🏆 TOP SCRAPPERS 🏆"
	title.Parent = surfaceGui

	listContainer = Instance.new("Frame")
	listContainer.Name = "List"
	listContainer.Size = UDim2.new(1, -20, 1, -90)
	listContainer.Position = UDim2.new(0, 10, 0, 80)
	listContainer.BackgroundTransparency = 1
	listContainer.Parent = surfaceGui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listContainer

	model.Parent = Workspace
end

function LeaderboardService.updateBoard()
	if not listContainer then return end

	-- Clear current rows
	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Get all players and sort by Scrap
	local playerStats = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		local scrap = data and data.Scrap or 0
		local rebirths = data and data.Rebirths or 0
		table.insert(playerStats, {
			Name = player.Name,
			Scrap = scrap,
			Rebirths = rebirths,
		})
	end

	table.sort(playerStats, function(a, b)
		if a.Rebirths ~= b.Rebirths then
			return a.Rebirths > b.Rebirths
		end
		return a.Scrap > b.Scrap
	end)

	-- Render top 8 rows
	for i = 1, math.min(8, #playerStats) do
		local entry = playerStats[i]
		local row = Instance.new("Frame")
		row.Name = "Row_" .. tostring(i)
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = i == 1 and Color3.fromRGB(50, 45, 20) or Color3.fromRGB(30, 30, 38)
		row.BorderSizePixel = 0
		row.Parent = listContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0, 60, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Font = Enum.Font.GothamBlack
		rankLabel.TextSize = 24
		rankLabel.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 200, 200)
		rankLabel.Text = "#" .. tostring(i)
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, -60, 1, 0)
		nameLabel.Position = UDim2.new(0, 70, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 22
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = entry.Name
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Size = UDim2.new(0.5, -20, 1, 0)
		scoreLabel.Position = UDim2.new(0.5, 10, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Font = Enum.Font.GothamBlack
		scoreLabel.TextSize = 22
		scoreLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Text = string.format("%s 🔩 | %d 🌀", CurrencyService.formatNumber(entry.Scrap), entry.Rebirths)
		scoreLabel.Parent = row
	end
end

function LeaderboardService.init()
	LeaderboardService.createInWorldBoard()

	task.spawn(function()
		while true do
			LeaderboardService.updateBoard()
			task.wait(5)
		end
	end)

	print("[LeaderboardService] Initialized.")
end

return LeaderboardService
