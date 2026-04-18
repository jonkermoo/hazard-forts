-- Tracks per-player inventories and keeps Backpack tools in sync.
-- Never touches the client directly — tools in Backpack replicate automatically.

local ItemTypes = require(game.ReplicatedStorage.Shared.ItemTypes)

local InventoryManager = {}

-- inventory[player][itemId] = count
local inventory: { [Player]: { [string]: number } } = {}

-- ── internal helpers ─────────────────────────────────────

local function findTool(player: Player, itemId: string): Tool?
	-- Check Backpack first, then equipped (inside Character)
	local function searchIn(parent)
		if not parent then return nil end
		for _, child in parent:GetChildren() do
			if child:IsA("Tool") then
				local tag = child:FindFirstChild("ItemId")
				if tag and tag.Value == itemId then
					return child
				end
			end
		end
		return nil
	end
	return searchIn(player.Backpack) or searchIn(player.Character)
end

local function toolName(itemId: string, count: number): string
	return ItemTypes[itemId].displayName .. "  x" .. count
end

local function createTool(player: Player, itemId: string): Tool
	local data = ItemTypes[itemId]

	local tool          = Instance.new("Tool")
	tool.Name           = data.displayName
	tool.CanBeDropped   = false
	tool.RequiresHandle = true

	-- Tag so we can find it again by itemId
	local tag   = Instance.new("StringValue")
	tag.Name    = "ItemId"
	tag.Value   = itemId
	tag.Parent  = tool

	-- Quantity value (client can read this for UI later)
	local qty   = Instance.new("IntValue")
	qty.Name    = "Quantity"
	qty.Value   = 0
	qty.Parent  = tool

	-- Handle — a scaled-down preview of the item
	local handle          = Instance.new("Part")
	handle.Name           = "Handle"
	handle.Size           = data.handleSize
	handle.BrickColor     = data.brickColor
	handle.Material       = data.material
	handle.CanCollide     = false
	handle.TopSurface     = Enum.SurfaceType.Smooth
	handle.BottomSurface  = Enum.SurfaceType.Smooth
	handle.Parent         = tool

	tool.Parent = player.Backpack
	return tool
end

local function syncTool(player: Player, itemId: string, count: number)
	local tool = findTool(player, itemId)

	if count <= 0 then
		if tool then tool:Destroy() end
		return
	end

	if not tool then
		tool = createTool(player, itemId)
	end

	local qty = tool:FindFirstChild("Quantity")
	if qty then qty.Value = count end
	tool.Name = toolName(itemId, count)
end

-- ── public API ───────────────────────────────────────────

function InventoryManager.initPlayer(player: Player)
	inventory[player] = {}
end

function InventoryManager.removePlayer(player: Player)
	inventory[player] = nil
end

function InventoryManager.addItem(player: Player, itemId: string, amount: number)
	local inv = inventory[player]
	if not inv then return end

	inv[itemId] = (inv[itemId] or 0) + amount
	syncTool(player, itemId, inv[itemId])
end

-- Returns false if the player doesn't have enough
function InventoryManager.removeItem(player: Player, itemId: string, amount: number): boolean
	local inv = inventory[player]
	if not inv then return false end

	local current = inv[itemId] or 0
	if current < amount then return false end

	inv[itemId] = current - amount
	syncTool(player, itemId, inv[itemId])
	return true
end

function InventoryManager.getCount(player: Player, itemId: string): number
	local inv = inventory[player]
	return inv and (inv[itemId] or 0) or 0
end

-- Wipes inventory and removes all item tools from Backpack + Character
function InventoryManager.clearPlayer(player: Player)
	local inv = inventory[player]
	if not inv then return end

	local function clearFrom(parent)
		if not parent then return end
		for _, child in parent:GetChildren() do
			if child:IsA("Tool") and child:FindFirstChild("ItemId") then
				child:Destroy()
			end
		end
	end
	clearFrom(player.Backpack)
	clearFrom(player.Character)

	inventory[player] = {}
end

return InventoryManager
