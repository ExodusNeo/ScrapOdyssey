--!strict
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundController = {}

local sfxEnabled = true
local musicEnabled = true
local backgroundMusic: Sound? = nil

-- Verified, high-quality audio assets
local AUDIO = {
	Swing = "rbxasset://sounds/swordslash.wav",
	HitSnap = "rbxasset://sounds/snap.wav",
	HitClink = "rbxasset://sounds/unsheath.wav",
	HitBass = "rbxasset://sounds/bass.wav",
	HitPing = "rbxasset://sounds/electronicpingshort.wav",
	Shatter = "rbxassetid://3802269741", -- Explosion Sound
	LootChime = "rbxassetid://4612375233", -- gem_pickup
	UIClick = "rbxassetid://6895079853", -- UI Click
	UIOpen = "rbxassetid://6042053626", -- Button Click
	Success = "rbxassetid://5153734608", -- Notification Fanfare
	Error = "rbxassetid://138090596", -- Error Beep
	Music = "rbxassetid://9043887091", -- Lo-fi Chill A (APMOfficial)
}

local function createSpatialAnchor(pos: Vector3, lifetime: number): Attachment
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = Workspace.Terrain
	task.delay(lifetime, function()
		att:Destroy()
	end)
	return att
end

-- Reusable sound player
local function playAt(soundId: string, parent: Instance?, pitch: number?, volume: number?, maxDist: number?): Sound?
	if not sfxEnabled then return nil end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Pitch = pitch or 1.0
	sound.Volume = volume or 0.5
	if maxDist then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.MaxDistance = maxDist
		sound.EmitterSize = 5
	end
	sound.Parent = parent or SoundService
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	-- Safety cleanup
	task.delay(4, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)

	return sound
end

-- 1. Tool Swing Whoosh
function SoundController.playSwing(speedMult: number?)
	local pitch = (1.1 + math.random() * 0.2) * (speedMult or 1.0)
	playAt(AUDIO.Swing, SoundService, pitch, 0.45)
end

-- 2. Crunchy Metallic Hit (Layered)
function SoundController.playHit(isDense: boolean, position: Vector3?)
	local parent: Instance = SoundService
	local maxDist: number? = nil

	if position then
		parent = createSpatialAnchor(position, 2)
		maxDist = 60
	end

	if isDense then
		-- Dense Mega Deposit: Heavy bass + resonant sci-fi ping + metallic clink
		playAt(AUDIO.HitBass, parent, 1.05 + math.random() * 0.1, 0.7, maxDist)
		playAt(AUDIO.HitPing, parent, 1.25 + math.random() * 0.15, 0.5, maxDist)
		playAt(AUDIO.HitClink, parent, 1.45 + math.random() * 0.1, 0.5, maxDist)
	else
		-- Standard Scrap Pile: Punchy snap crack + bright metallic clink
		playAt(AUDIO.HitSnap, parent, 1.05 + math.random() * 0.15, 0.6, maxDist)
		playAt(AUDIO.HitClink, parent, 1.30 + math.random() * 0.15, 0.45, maxDist)
	end
end

-- 3. Node Shatter / Cleared
function SoundController.playShatter(isDense: boolean, position: Vector3?)
	local parent: Instance = SoundService
	local maxDist: number? = nil

	if position then
		parent = createSpatialAnchor(position, 3)
		maxDist = 80
	end

	-- Crunchy shatter explosion + crystal loot chime
	playAt(AUDIO.Shatter, parent, isDense and 1.05 or 1.25, 0.65, maxDist)
	playAt(AUDIO.LootChime, parent, isDense and 1.2 or 1.05, 0.65, maxDist)
	if isDense then
		playAt(AUDIO.HitPing, parent, 1.4, 0.55, maxDist)
	end
end

-- 4. Scrap Recycler Cha-Ching / Cash Ring
function SoundController.playRecycle(position: Vector3?)
	local parent: Instance = SoundService
	local maxDist: number? = nil

	if position then
		parent = createSpatialAnchor(position, 3)
		maxDist = 80
	end

	-- Rapid arpeggio of loot chimes for satisfying deposit feel
	task.spawn(function()
		playAt(AUDIO.LootChime, parent, 1.0, 0.6, maxDist)
		task.wait(0.08)
		playAt(AUDIO.LootChime, parent, 1.2, 0.65, maxDist)
		task.wait(0.08)
		playAt(AUDIO.LootChime, parent, 1.4, 0.7, maxDist)
		playAt(AUDIO.HitPing, parent, 1.6, 0.5, maxDist)
	end)
end

-- 5. UI Click
function SoundController.playUIClick()
	playAt(AUDIO.UIClick, SoundService, 1.0 + math.random() * 0.05, 0.45)
end

-- 6. UI Menu Open / Pop
function SoundController.playUIOpen()
	playAt(AUDIO.UIOpen, SoundService, 1.25, 0.45)
end

-- 7. Success / Milestone / Unlock Fanfare
function SoundController.playSuccess()
	playAt(AUDIO.Success, SoundService, 1.1, 0.65)
end

-- 8. Error / Cargo Full / Insufficient Currency
function SoundController.playError()
	playAt(AUDIO.Error, SoundService, 1.0, 0.55)
end

-- Background Music Management
function SoundController.startBackgroundMusic()
	if backgroundMusic then
		backgroundMusic:Play()
		return
	end

	backgroundMusic = Instance.new("Sound")
	backgroundMusic.Name = "AtmosphericBGM"
	backgroundMusic.SoundId = AUDIO.Music
	backgroundMusic.Looped = true
	backgroundMusic.Volume = 0
	backgroundMusic.Parent = SoundService
	backgroundMusic:Play()

	if musicEnabled then
		TweenService:Create(backgroundMusic, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0.14,
		}):Play()
	end
end

function SoundController.stopBackgroundMusic()
	if backgroundMusic then
		TweenService:Create(backgroundMusic, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0,
		}):Play()
	end
end

-- Toggles & Getters
function SoundController.toggleSFX(): boolean
	sfxEnabled = not sfxEnabled
	SoundService:SetAttribute("SFXEnabled", sfxEnabled)
	if sfxEnabled then
		SoundController.playUIClick()
	end
	return sfxEnabled
end

function SoundController.toggleMusic(): boolean
	musicEnabled = not musicEnabled
	SoundService:SetAttribute("MusicEnabled", musicEnabled)
	if musicEnabled then
		SoundController.startBackgroundMusic()
		if backgroundMusic then
			TweenService:Create(backgroundMusic, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Volume = 0.14,
			}):Play()
		end
	else
		SoundController.stopBackgroundMusic()
	end
	return musicEnabled
end

function SoundController.isSFXEnabled(): boolean
	return sfxEnabled
end

function SoundController.isMusicEnabled(): boolean
	return musicEnabled
end

function SoundController.init()
	-- Preload all audio assets for zero stutter on first playback
	task.spawn(function()
		local preloadList = {}
		for _, id in pairs(AUDIO) do
			local s = Instance.new("Sound")
			s.SoundId = id
			table.insert(preloadList, s)
		end
		pcall(function()
			ContentProvider:PreloadAsync(preloadList)
		end)
		for _, s in ipairs(preloadList) do
			s:Destroy()
		end
	end)

	-- Start ambient music
	SoundController.startBackgroundMusic()
	print("[SoundController] Audio Engine Initialized with 12-channel SFX & BGM.")
end

return SoundController
