-- Every placeable object in the game lives here.
-- Adding a new item = add one entry to this table.
--
-- Fields:
--   displayName  shown in hotbar tool name
--   size         actual placed-block size (studs)
--   handleSize   scaled-down preview held in hand
--   brickColor   color used for both the drop pickup and the placed block
--   material     Roblox material for the placed block
--   dropWeight   relative likelihood of dropping from a loot box (higher = more common)

local ItemTypes = {

	WoodPlank = {
		displayName = "Wood Plank",
		size        = Vector3.new(8, 0.5, 2),
		handleSize  = Vector3.new(1.5, 0.1, 0.4),
		brickColor  = BrickColor.new("Reddish brown"),
		material    = Enum.Material.Wood,
		dropWeight  = 4,
	},

	WoodCrate = {
		displayName = "Wood Crate",
		size        = Vector3.new(4, 4, 4),
		handleSize  = Vector3.new(0.8, 0.8, 0.8),
		brickColor  = BrickColor.new("Nougat"),
		material    = Enum.Material.Wood,
		dropWeight  = 3,
	},

	WoodWall = {
		displayName = "Wood Wall",
		size        = Vector3.new(6, 6, 0.5),
		handleSize  = Vector3.new(0.8, 0.8, 0.1),
		brickColor  = BrickColor.new("Bright orange"),
		material    = Enum.Material.Wood,
		dropWeight  = 2,
	},

	WoodLadder = {
		displayName = "Ladder",
		size        = Vector3.new(2, 8, 0.5),
		handleSize  = Vector3.new(0.4, 1.5, 0.1),
		brickColor  = BrickColor.new("Dark orange"),
		material    = Enum.Material.Wood,
		dropWeight  = 1,
	},
}

-- Pre-built weighted pool for random drops (built once at require time)
local weightedPool = {}
for id, data in ItemTypes do
	for _ = 1, data.dropWeight do
		table.insert(weightedPool, id)
	end
end

function ItemTypes.randomId()
	return weightedPool[math.random(1, #weightedPool)]
end

return ItemTypes
