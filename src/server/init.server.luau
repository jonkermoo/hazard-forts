-- GameManager: drives the core game loop.
-- Lobby → Building → Hazard → GameOver → repeat

local Players          = game:GetService("Players")
local GC               = require(game.ReplicatedStorage.Shared.GameConstants)
local MapManager       = require(script.MapManager)
local InventoryManager = require(script.InventoryManager)
local LootBoxManager   = require(script.LootBoxManager)
local BuildManager     = require(script.BuildManager)

-- ── state ────────────────────────────────────────────────

local state        = GC.State.LOBBY
local roundPlayers = {}

-- ── utilities ────────────────────────────────────────────

local function teleport(player: Player, cf: CFrame)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = cf end
end

local function isAlive(player: Player): boolean
	if not player or not player.Parent then return false end
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function aliveCount(): number
	local n = 0
	for _, p in roundPlayers do
		if isAlive(p) then n += 1 end
	end
	return n
end

-- ── phases ───────────────────────────────────────────────

local function lobby()
	state = GC.State.LOBBY
	print("[Game] LOBBY — waiting for players")

	while #Players:GetPlayers() < GC.MIN_PLAYERS do
		task.wait(1)
	end

	print(string.format("[Game] Starting in %ds…", GC.LOBBY_COUNTDOWN))
	task.wait(GC.LOBBY_COUNTDOWN)
end

local function building()
	state = GC.State.BUILDING
	print("[Game] BUILDING — " .. GC.BUILD_DURATION .. "s")

	roundPlayers = Players:GetPlayers()

	-- Fresh inventory each round
	for _, player in roundPlayers do
		InventoryManager.clearPlayer(player)
	end

	local mapFolder = MapManager.createMap()
	task.wait(0.5)

	LootBoxManager.initMap(mapFolder)
	BuildManager.initRound(mapFolder)
	BuildManager.giveHammers(roundPlayers)

	local spawns = MapManager.arenaSpawnCFrames(#roundPlayers)
	for i, player in roundPlayers do
		if not player.Character then
			player.CharacterAdded:Wait()
			task.wait(0.1)
		end
		teleport(player, spawns[i])
	end

	task.wait(GC.BUILD_DURATION)
end

local function hazard()
	state = GC.State.HAZARD
	print("[Game] HAZARD — " .. GC.HAZARD_DURATION .. "s")

	local lava = MapManager.getLava()
	if not lava then
		warn("[Game] Lava part missing — skipping hazard phase")
		task.wait(GC.HAZARD_DURATION)
		return
	end

	local conn = lava.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = 0
		end
	end)

	local startY  = lava.Position.Y
	local elapsed = 0

	while elapsed < GC.HAZARD_DURATION do
		local dt  = task.wait(0.05)
		elapsed  += dt

		if lava.Parent then
			lava.Position = Vector3.new(0, startY + elapsed * GC.HAZARD_RISE_SPEED, 0)
		end

		if aliveCount() == 0 then
			print("[Game] All players eliminated")
			break
		end
	end

	conn:Disconnect()
end

local function gameOver()
	state = GC.State.GAME_OVER
	print("[Game] GAME OVER")

	local survivors = {}
	for _, p in roundPlayers do
		if isAlive(p) then table.insert(survivors, p.Name) end
	end

	if #survivors == 0 then
		print("[Game] No survivors!")
	else
		print("[Game] Survivors: " .. table.concat(survivors, ", "))
	end

	task.wait(GC.GAME_OVER_DURATION)

	-- Tear down the round
	LootBoxManager.cleanup()
	MapManager.destroyMap()
	task.wait(0.3)

	-- Clear inventories, remove hammers, return everyone to lobby
	BuildManager.removeHammers(Players:GetPlayers())
	local lobbyCF = MapManager.lobbySpawnCFrame()
	for _, player in Players:GetPlayers() do
		InventoryManager.clearPlayer(player)
		teleport(player, lobbyCF)
	end

	roundPlayers = {}
end

-- ── player lifecycle ─────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	InventoryManager.initPlayer(player)

	player.CharacterAdded:Connect(function()
		if state == GC.State.LOBBY then
			task.wait(1)
			teleport(player, MapManager.lobbySpawnCFrame())
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	InventoryManager.removePlayer(player)
end)

-- ── startup ──────────────────────────────────────────────

MapManager.createLobby()
BuildManager.init()

while true do
	lobby()
	building()
	hazard()
	gameOver()
end
