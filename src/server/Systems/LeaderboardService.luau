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

type BoardRow = {
	Frame: Frame,
	Stroke: UIStroke,
	RankLabel: TextLabel,
	NameLabel: TextLabel,
	ScoreLabel: TextLabel,
}
local boardRows: { BoardRow } = {}

function LeaderboardService.createInWorldBoard()
	local model = Instance.new("Model")
	model.Name = "GlobalLeaderboard"

	boardPart = Instance.new("Part")
	boardPart.Name = "Display"
	boardPart.Size = Vector3.new(16, 12, 1)
	boardPart.CFrame = CFrame.new(24, 9, -70) * CFrame.Angles(0, math.rad(180), 0)
	boardPart.Anchored = true
	boardPart.Material = Enum.Material.SmoothPlastic
	boardPart.Color = Color3.fromRGB(16, 18, 24)
	boardPart.Parent = model

	-- Stylized border
	local border = Instance.new("Part")
	border.Name = "Border"
	border.Size = Vector3.new(16.4, 12.4, 0.8)
	border.CFrame = CFrame.new(24, 9, -70.6) * CFrame.Angles(0, math.rad(180), 0)
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
	title.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 30
	title.TextColor3 = Color3.fromRGB(255, 200, 50)
	title.Text = "TOP OPERATORS // SECTOR RANKING"
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

	-- Pre-allocate an 8-row pool to avoid allocating and destroying 48 UI instances every 5s
	boardRows = {}
	for i = 1, 8 do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. tostring(i)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = i == 1 and Color3.fromRGB(36, 32, 22) or Color3.fromRGB(22, 25, 33)
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = listContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = i == 1 and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(38, 44, 58)
		stroke.Thickness = 1
		stroke.Parent = row

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0, 60, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Font = Enum.Font.GothamBlack
		rankLabel.TextSize = 22
		rankLabel.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(180, 190, 205)
		rankLabel.Text = "#" .. tostring(i)
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, -60, 1, 0)
		nameLabel.Position = UDim2.new(0, 70, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 20
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Size = UDim2.new(0.5, -20, 1, 0)
		scoreLabel.Position = UDim2.new(0.5, 10, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Font = Enum.Font.GothamBlack
		scoreLabel.TextSize = 18
		scoreLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = row

		table.insert(boardRows, {
			Frame = row,
			Stroke = stroke,
			RankLabel = rankLabel,
			NameLabel = nameLabel,
			ScoreLabel = scoreLabel,
		})
	end

	model.Parent = Workspace
end

function LeaderboardService.updateBoard()
	if not listContainer or #boardRows == 0 then return end

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

	-- Update the pre-allocated 8 rows
	for i = 1, 8 do
		local rowData = boardRows[i]
		local entry = playerStats[i]
		if entry then
			rowData.NameLabel.Text = entry.Name
			rowData.ScoreLabel.Text = string.format("%s SCRAP | TIER %d", CurrencyService.formatNumber(entry.Scrap), entry.Rebirths)
			rowData.Frame.Visible = true
		else
			rowData.Frame.Visible = false
		end
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
