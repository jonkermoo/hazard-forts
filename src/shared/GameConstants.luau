local GameConstants = {

	-- States
	State = {
		LOBBY     = "Lobby",
		BUILDING  = "Building",
		HAZARD    = "Hazard",
		GAME_OVER = "GameOver",
	},

	-- Timing (seconds)
	MIN_PLAYERS        = 1,  -- 1 for solo testing
	LOBBY_COUNTDOWN    = 10,
	BUILD_DURATION     = 30,
	HAZARD_DURATION    = 60,
	GAME_OVER_DURATION = 5,

	-- Arena
	ARENA_SIZE     = 150,
	WALL_HEIGHT    = 80,
	WALL_THICKNESS = 4,
	FLOOR_Y        = 2,   -- Y of arena floor top face

	-- Lobby (offset so it doesn't overlap the arena at origin)
	LOBBY_POS = Vector3.new(400, 0, 0),

	-- Hazard
	HAZARD_START_Y    = -60, -- relative to FLOOR_Y
	HAZARD_RISE_SPEED = 2, -- studs/second

	-- Loot boxes
	LOOTBOX_COUNT = 8,
	LOOTBOX_SIZE  = Vector3.new(4, 4, 4),
	LOOTBOX_HP    = 3,
}

return GameConstants
