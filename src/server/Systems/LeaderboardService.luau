--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	local old = Workspace:FindFirstChild("GlobalLeaderboard")
	if old then old:Destroy() end

	local model = Instance.new("Model")
	model.Name = "GlobalLeaderboard"

	-- Centered along the East perimeter (+X) facing inward toward Central Spawn (0, 0, 0)
	local boardCenter = Vector3.new(42, 8.5, 0)
	local boardCF = CFrame.lookAt(boardCenter, Vector3.new(0, 8.5, 0))

	-- 1. Outer Grounded Steel Support Pillars (Flanking outside the 18-stud display at Z = -10 and +10 to prevent any occlusion)
	for _, zOff in ipairs({ -10, 10 }) do
		local footing = Instance.new("Part")
		footing.Name = "LeaderboardFooting"
		footing.Size = Vector3.new(2.8, 0.8, 2.8)
		footing.Position = Vector3.new(42, 0.4, zOff)
		footing.Anchored = true
		footing.Material = Enum.Material.Concrete
		footing.Color = Color3.fromRGB(38, 42, 50)
		footing.Parent = model

		local pillar = Instance.new("Part")
		pillar.Name = "LeaderboardPillar"
		pillar.Size = Vector3.new(1.8, 14, 1.8)
		pillar.Position = Vector3.new(42, 7.0, zOff)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Metal
		pillar.Color = Color3.fromRGB(30, 32, 40)
		pillar.Parent = model

		-- Horizontal Mounting Bracket connecting the pillar to the side of the display
		local bracket = Instance.new("Part")
		bracket.Name = "MountBracket"
		bracket.Size = Vector3.new(1.2, 1.2, 1.2)
		bracket.Position = Vector3.new(42, 8.5, zOff > 0 and 9.4 or -9.4)
		bracket.Anchored = true
		bracket.Material = Enum.Material.Metal
		bracket.Color = Color3.fromRGB(48, 52, 64)
		bracket.Parent = model
	end

	-- 2. Golden-Amber Backing Bezel Plate (Positioned strictly BEHIND the display at +Z in boardCF space)
	local backplate = Instance.new("Part")
	backplate.Name = "Backplate"
	backplate.Size = Vector3.new(18.6, 11.6, 0.4)
	backplate.CFrame = boardCF * CFrame.new(0, 0, 0.5)
	backplate.Anchored = true
	backplate.Material = Enum.Material.SmoothPlastic
	backplate.Color = Color3.fromRGB(240, 160, 30)
	backplate.Parent = model

	-- 3. Main Display Screen Part (Width 18, Height 11, Depth 0.8)
	boardPart = Instance.new("Part")
	boardPart.Name = "Display"
	boardPart.Size = Vector3.new(18, 11, 0.8)
	boardPart.CFrame = boardCF
	boardPart.Anchored = true
	boardPart.Material = Enum.Material.SmoothPlastic
	boardPart.Color = Color3.fromRGB(15, 17, 24)
	boardPart.Parent = model

	-- 4. Overhead Industrial Down-Lamps
	for _, lz in ipairs({ -5, 5 }) do
		local lamp = Instance.new("Part")
		lamp.Name = "LeaderboardLamp"
		lamp.Size = Vector3.new(1.4, 0.8, 1.4)
		lamp.CFrame = boardCF * CFrame.new(lz, 6.0, -1.2)
		lamp.Anchored = true
		lamp.Material = Enum.Material.SmoothPlastic
		lamp.Color = Color3.fromRGB(235, 230, 215)
		lamp.Parent = model

		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(255, 245, 220)
		pLight.Brightness = 0.5
		pLight.Range = 14
		pLight.Parent = lamp
	end

	-- 5. High-Definition SurfaceGui on Front Face (FixedSize 1800x1100, LightInfluence=0 for crisp OLED glow)
	surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "LeaderboardGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(1800, 1100)
	surfaceGui.AlwaysOnTop = false
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = boardPart

	-- Root Background Frame
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	root.BorderSizePixel = 0
	root.Parent = surfaceGui

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = Color3.fromRGB(255, 170, 30)
	rootStroke.Thickness = 4
	rootStroke.Parent = root

	-- Header Bar
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -40, 0, 110)
	header.Position = UDim2.new(0, 20, 0, 18)
	header.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	header.BorderSizePixel = 0
	header.Parent = root

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 12)
	hCorner.Parent = header

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = Color3.fromRGB(255, 195, 45)
	hStroke.Thickness = 3
	hStroke.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -30, 0, 64)
	title.Position = UDim2.new(0, 15, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 42
	title.TextColor3 = Color3.fromRGB(255, 215, 50)
	title.Text = "TOP OPERATORS // SECTOR RANKING"
	title.Parent = header

	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.Size = UDim2.new(1, -30, 0, 30)
	sub.Position = UDim2.new(0, 15, 0, 68)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 20
	sub.TextColor3 = Color3.fromRGB(100, 220, 255)
	sub.Text = "[ LIVE TELEMETRY // REAL-TIME SYNC ]"
	sub.Parent = header

	-- Column Header Strip
	local colStrip = Instance.new("Frame")
	colStrip.Name = "ColStrip"
	colStrip.Size = UDim2.new(1, -40, 0, 40)
	colStrip.Position = UDim2.new(0, 20, 0, 140)
	colStrip.BackgroundTransparency = 1
	colStrip.Parent = root

	local colRank = Instance.new("TextLabel")
	colRank.Size = UDim2.new(0, 120, 1, 0)
	colRank.BackgroundTransparency = 1
	colRank.Font = Enum.Font.GothamBlack
	colRank.TextSize = 22
	colRank.TextColor3 = Color3.fromRGB(160, 175, 195)
	colRank.TextXAlignment = Enum.TextXAlignment.Center
	colRank.Text = "RANK"
	colRank.Parent = colStrip

	local colName = Instance.new("TextLabel")
	colName.Size = UDim2.new(0.5, -120, 1, 0)
	colName.Position = UDim2.new(0, 140, 0, 0)
	colName.BackgroundTransparency = 1
	colName.Font = Enum.Font.GothamBlack
	colName.TextSize = 22
	colName.TextColor3 = Color3.fromRGB(160, 175, 195)
	colName.TextXAlignment = Enum.TextXAlignment.Left
	colName.Text = "OPERATOR IDENTIFIER"
	colName.Parent = colStrip

	local colScore = Instance.new("TextLabel")
	colScore.Size = UDim2.new(0.5, -30, 1, 0)
	colScore.Position = UDim2.new(0.5, 10, 0, 0)
	colScore.BackgroundTransparency = 1
	colScore.Font = Enum.Font.GothamBlack
	colScore.TextSize = 22
	colScore.TextColor3 = Color3.fromRGB(160, 175, 195)
	colScore.TextXAlignment = Enum.TextXAlignment.Right
	colScore.Text = "TOTAL RECYCLED SCRAP"
	colScore.Parent = colStrip

	-- List Frame
	listContainer = Instance.new("Frame")
	listContainer.Name = "List"
	listContainer.Size = UDim2.new(1, -40, 1, -195)
	listContainer.Position = UDim2.new(0, 20, 0, 185)
	listContainer.BackgroundTransparency = 1
	listContainer.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = listContainer

	-- Pre-allocate an 8-row pool (All 8 rows ALWAYS visible so the board is never empty)
	boardRows = {}
	for i = 1, 8 do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. tostring(i)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 95)
		row.BackgroundColor3 = (i == 1 and Color3.fromRGB(42, 36, 22)) or (i % 2 == 0 and Color3.fromRGB(22, 26, 36) or Color3.fromRGB(18, 21, 30))
		row.BorderSizePixel = 0
		row.Visible = true
		row.Parent = listContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local stroke = Instance.new("UIStroke")
		stroke.Color = (i == 1 and Color3.fromRGB(255, 195, 45)) or Color3.fromRGB(45, 52, 70)
		stroke.Thickness = (i == 1 and 2.5) or 1.5
		stroke.Parent = row

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Name = "RankLabel"
		rankLabel.Size = UDim2.new(0, 120, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Font = Enum.Font.GothamBlack
		rankLabel.TextSize = 36
		rankLabel.TextColor3 = (i == 1 and Color3.fromRGB(255, 215, 0))
			or (i == 2 and Color3.fromRGB(220, 230, 245))
			or (i == 3 and Color3.fromRGB(235, 155, 75))
			or Color3.fromRGB(160, 175, 195)
		rankLabel.Text = "#" .. tostring(i)
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(0.5, -120, 1, 0)
		nameLabel.Position = UDim2.new(0, 140, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 28
		nameLabel.TextColor3 = Color3.fromRGB(110, 125, 150)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = "[ STANDBY // VACANT ]"
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "ScoreLabel"
		scoreLabel.Size = UDim2.new(0.5, -30, 1, 0)
		scoreLabel.Position = UDim2.new(0.5, 10, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Font = Enum.Font.GothamBlack
		scoreLabel.TextSize = 28
		scoreLabel.TextColor3 = Color3.fromRGB(130, 120, 80)
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Text = "-- SCRAP"
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

	-- In Edit Mode, trigger a tiny property cycle to immediately invalidate viewport cache
	if RunService:IsEdit() then
		boardPart.Size = boardPart.Size + Vector3.new(0.002, 0, 0)
		boardPart.Size = boardPart.Size - Vector3.new(0.002, 0, 0)
	end

	-- Immediately populate with active player telemetry
	LeaderboardService.updateBoard()
end

function LeaderboardService.updateBoard()
	if not listContainer or #boardRows == 0 then return end

	-- Get all players and sort by Scrap / Rebirths
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

	-- Update all 8 pre-allocated rows (Populates real player data, or displays crisp standby telemetry for empty slots)
	for i = 1, 8 do
		local rowData = boardRows[i]
		local entry = playerStats[i]
		if entry then
			rowData.NameLabel.Text = entry.Name
			rowData.NameLabel.TextColor3 = Color3.new(1, 1, 1)

			rowData.ScoreLabel.Text = string.format("%s SCRAP | TIER %d", CurrencyService.formatNumber(entry.Scrap), entry.Rebirths)
			rowData.ScoreLabel.TextColor3 = Color3.fromRGB(255, 205, 50)

			rowData.Frame.BackgroundColor3 = (i == 1 and Color3.fromRGB(42, 36, 22)) or (i % 2 == 0 and Color3.fromRGB(22, 26, 36) or Color3.fromRGB(18, 21, 30))
			rowData.Stroke.Color = (i == 1 and Color3.fromRGB(255, 195, 45)) or Color3.fromRGB(45, 52, 70)
		else
			-- Standby slot
			rowData.NameLabel.Text = "[ STANDBY // VACANT ]"
			rowData.NameLabel.TextColor3 = Color3.fromRGB(110, 125, 150)

			rowData.ScoreLabel.Text = "-- SCRAP"
			rowData.ScoreLabel.TextColor3 = Color3.fromRGB(130, 120, 80)

			rowData.Frame.BackgroundColor3 = (i % 2 == 0 and Color3.fromRGB(18, 21, 30)) or Color3.fromRGB(16, 18, 26)
			rowData.Stroke.Color = Color3.fromRGB(35, 40, 54)
		end
		-- Keep every row visible so the leaderboard is never blank
		rowData.Frame.Visible = true
	end
end

function LeaderboardService.init()
	LeaderboardService.createInWorldBoard()

	-- Dynamic auto-updates on join/leave
	Players.PlayerAdded:Connect(function()
		task.wait(0.5)
		LeaderboardService.updateBoard()
	end)
	Players.PlayerRemoving:Connect(function()
		task.wait(0.2)
		LeaderboardService.updateBoard()
	end)

	-- Periodic 5-second polling loop for real-time scrap gains
	task.spawn(function()
		while true do
			LeaderboardService.updateBoard()
			task.wait(5)
		end
	end)

	print("[LeaderboardService] Initialized with full-bleed high-definition telemetry.")
end

return LeaderboardService
