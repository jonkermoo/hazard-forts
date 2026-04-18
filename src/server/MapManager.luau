-- ModuleScript (child of Server script via Rojo)
-- Builds and tears down the lobby and game arena procedurally.

local Workspace = game:GetService("Workspace")
local GC        = require(game.ReplicatedStorage.Shared.GameConstants)

local MapManager  = {}
local lobbyFolder = nil -- lives the whole server session
local mapFolder   = nil -- recreated each round

-- ── helpers ──────────────────────────────────────────────

local function makePart(name, size, position, brickColor, material, parent)
	local p         = Instance.new("Part")
	p.Name          = name
	p.Size          = size
	p.Position      = position
	p.Anchored      = true
	p.BrickColor    = BrickColor.new(brickColor)
	p.Material      = material
	p.TopSurface    = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent        = parent
	return p
end

-- ── lobby ────────────────────────────────────────────────

function MapManager.createLobby()
	lobbyFolder        = Instance.new("Folder")
	lobbyFolder.Name   = "Lobby"
	lobbyFolder.Parent = Workspace

	local cx = GC.LOBBY_POS.X
	local cy = GC.LOBBY_POS.Y
	local cz = GC.LOBBY_POS.Z

	makePart("Floor", Vector3.new(80, 4, 80), Vector3.new(cx, cy, cz),
		"Medium stone grey", Enum.Material.Concrete, lobbyFolder)

	-- Players automatically respawn here (it's the only SpawnLocation)
	local spawn      = Instance.new("SpawnLocation")
	spawn.Name       = "LobbySpawn"
	spawn.Size       = Vector3.new(6, 1, 6)
	spawn.Position   = Vector3.new(cx, cy + 3, cz)
	spawn.Anchored   = true
	spawn.Neutral    = true
	spawn.Duration   = 0
	spawn.BrickColor = BrickColor.new("Cyan")
	spawn.Material   = Enum.Material.Neon
	spawn.Parent     = lobbyFolder
end

function MapManager.lobbySpawnCFrame()
	local s = lobbyFolder and lobbyFolder:FindFirstChild("LobbySpawn")
	if s then return s.CFrame + Vector3.new(0, 5, 0) end
	return CFrame.new(GC.LOBBY_POS + Vector3.new(0, 6, 0))
end

-- ── arena ────────────────────────────────────────────────

function MapManager.createMap()
	mapFolder        = Instance.new("Folder")
	mapFolder.Name   = "Map"
	mapFolder.Parent = Workspace

	local half = GC.ARENA_SIZE / 2
	local fy   = GC.FLOOR_Y
	local wH   = GC.WALL_HEIGHT
	local wT   = GC.WALL_THICKNESS

	-- Floor (top face sits at fy)
	makePart("ArenaFloor",
		Vector3.new(GC.ARENA_SIZE, 4, GC.ARENA_SIZE),
		Vector3.new(0, fy - 2, 0),
		"Sand green", Enum.Material.Ground, mapFolder)

	-- Four walls
	local wallDefs = {
		{ Vector3.new(GC.ARENA_SIZE + wT*2, wH, wT), Vector3.new(0,          fy + wH/2, -(half + wT/2)) },
		{ Vector3.new(GC.ARENA_SIZE + wT*2, wH, wT), Vector3.new(0,          fy + wH/2,  (half + wT/2)) },
		{ Vector3.new(wT, wH, GC.ARENA_SIZE),          Vector3.new(-(half+wT/2), fy + wH/2, 0)            },
		{ Vector3.new(wT, wH, GC.ARENA_SIZE),          Vector3.new( (half+wT/2), fy + wH/2, 0)            },
	}
	for _, w in wallDefs do
		local wall = makePart("Wall", w[1], w[2], "Dark stone grey",
			Enum.Material.SmoothPlastic, mapFolder)
		wall.Transparency = 0.35
	end

	-- Loot boxes
	local rng = Random.new()
	for _ = 1, GC.LOOTBOX_COUNT do
		local x   = rng:NextNumber(-half + 12, half - 12)
		local z   = rng:NextNumber(-half + 12, half - 12)
		local box = makePart("LootBox", GC.LOOTBOX_SIZE,
			Vector3.new(x, fy + GC.LOOTBOX_SIZE.Y / 2, z),
			"Bright yellow", Enum.Material.SmoothPlastic, mapFolder)

		local hp   = Instance.new("IntValue")
		hp.Name    = "HP"
		hp.Value   = GC.LOOTBOX_HP
		hp.Parent  = box
	end

	-- Lava slab — starts below the arena floor
	local lava = makePart("Lava",
		Vector3.new(GC.ARENA_SIZE + 30, 10, GC.ARENA_SIZE + 30),
		Vector3.new(0, fy + GC.HAZARD_START_Y, 0),
		"Bright orange", Enum.Material.Neon, mapFolder)
	lava.CanCollide = true

	return mapFolder
end

function MapManager.getLava()
	return mapFolder and mapFolder:FindFirstChild("Lava") or nil
end

-- Evenly-spread CFrames on the arena floor for N players
function MapManager.arenaSpawnCFrames(count)
	local frames = {}
	local radius = 45
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		frames[i] = CFrame.new(math.cos(a) * radius, GC.FLOOR_Y + 4, math.sin(a) * radius)
	end
	return frames
end

function MapManager.destroyMap()
	if mapFolder then
		mapFolder:Destroy()
		mapFolder = nil
	end
end

return MapManager
