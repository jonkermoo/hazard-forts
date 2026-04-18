-- Server-side building: placement, drag ownership, and freezing.

local Players        = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Remotes        = require(game.ReplicatedStorage.Shared.Remotes)
local ItemTypes      = require(game.ReplicatedStorage.Shared.ItemTypes)
local InventoryManager = require(script.Parent.InventoryManager)
local GC             = require(game.ReplicatedStorage.Shared.GameConstants)

local BuildManager = {}

local placedFolder = nil

-- ── hammer ────────────────────────────────────────────────

local function makeHammer(player: Player)
	local tool            = Instance.new("Tool")
	tool.Name             = "Hammer"
	tool.CanBeDropped     = false
	tool.RequiresHandle   = true
	tool.ToolTip          = "Move your own blocks"

	local handle          = Instance.new("Part")
	handle.Name           = "Handle"
	handle.Size           = Vector3.new(0.3, 1.6, 0.3)
	handle.BrickColor     = BrickColor.new("Reddish brown")
	handle.Material       = Enum.Material.Wood
	handle.CanCollide     = false
	handle.Parent         = tool

	local head            = Instance.new("Part")
	head.Name             = "Head"
	head.Size             = Vector3.new(0.8, 0.4, 0.4)
	head.BrickColor       = BrickColor.new("Mid gray")
	head.Material         = Enum.Material.Metal
	head.CanCollide       = false
	head.CFrame           = handle.CFrame * CFrame.new(0, 0.9, 0)
	head.Parent           = tool

	local weld            = Instance.new("WeldConstraint")
	weld.Part0            = handle
	weld.Part1            = head
	weld.Parent           = handle

	tool.Parent = player.Backpack
end

function BuildManager.giveHammers(players: {Player})
	for _, player in players do
		makeHammer(player)
	end
end

function BuildManager.removeHammers(players: {Player})
	for _, player in players do
		local function removeFrom(parent: Instance?)
			if not parent then return end
			for _, child in parent:GetChildren() do
				if child:IsA("Tool") and child.Name == "Hammer" then
					child:Destroy()
				end
			end
		end
		removeFrom(player.Backpack)
		removeFrom(player.Character)
	end
end

-- dragging[player] = Part currently being dragged by that player
local dragging: { [Player]: BasePart } = {}

local lastPlace: { [Player]: number } = {}
local PLACE_COOLDOWN = 0.25

-- ── collision groups ─────────────────────────────────────
-- "Players"      – character parts; doesn't collide with DraggedBlocks
-- "DraggedBlocks"– blocks mid-drag; doesn't collide with Players or each other

local function setupCollisionGroups()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:RegisterCollisionGroup("DraggedBlocks")
	PhysicsService:CollisionGroupSetCollidable("Players",      "DraggedBlocks", false)
	PhysicsService:CollisionGroupSetCollidable("DraggedBlocks","DraggedBlocks", false)
end

local function applyPlayerGroup(character: Model)
	local function tag(p: Instance)
		if p:IsA("BasePart") then
			(p :: BasePart).CollisionGroup = "Players"
		end
	end
	for _, d in character:GetDescendants() do tag(d) end
	character.DescendantAdded:Connect(tag)
end

-- ── validation helpers ───────────────────────────────────

local function inArena(pos: Vector3): boolean
	local half = GC.ARENA_SIZE / 2
	return math.abs(pos.X) <= half
		and math.abs(pos.Z) <= half
		and pos.Y <= GC.FLOOR_Y + GC.WALL_HEIGHT
		and pos.Y >= GC.FLOOR_Y + GC.HAZARD_START_Y
end

local function inRange(player: Player, pos: Vector3): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	return (pos - root.Position).Magnitude <= 35
end

-- Returns true if the block is adjacent to (but not deeply inside) solid geometry.
local function checkTouching(block: BasePart, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local pos  = block.Position
	local size = block.Size
	local rays = {
		Vector3.new(0,              -(size.Y / 2 + 0.2), 0),
		Vector3.new(0,               (size.Y / 2 + 0.2), 0),
		Vector3.new( size.X / 2 + 0.2, 0, 0),
		Vector3.new(-size.X / 2 - 0.2, 0, 0),
		Vector3.new(0, 0,  size.Z / 2 + 0.2),
		Vector3.new(0, 0, -(size.Z / 2 + 0.2)),
	}
	for _, dir in rays do
		if workspace:Raycast(pos, dir, params) then return true end
	end
	return false
end

-- Returns true if the block is significantly overlapping other geometry
-- (used to reject freeze-inside-a-wall attempts).
local function checkOverlapping(block: BasePart, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hits = workspace:GetPartsInPart(block, params)
	return #hits > 0
end

-- ── public ───────────────────────────────────────────────

function BuildManager.initRound(mapFolder: Folder)
	placedFolder      = Instance.new("Folder")
	placedFolder.Name = "PlacedBlocks"
	placedFolder.Parent = mapFolder
end

function BuildManager.init()
	setupCollisionGroups()

	-- Tag existing and future player characters with the Players collision group
	for _, player in Players:GetPlayers() do
		if player.Character then applyPlayerGroup(player.Character) end
		player.CharacterAdded:Connect(applyPlayerGroup)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(applyPlayerGroup)
	end)

	-- ── PlaceBlock ───────────────────────────────────────
	Remotes.PlaceBlock.OnServerEvent:Connect(function(player, itemId, cf)
		if type(itemId) ~= "string"  then return end
		if typeof(cf)   ~= "CFrame"  then return end

		local data = ItemTypes[itemId]
		if not data then return end

		local now = tick()
		if (lastPlace[player] or 0) + PLACE_COOLDOWN > now then return end
		lastPlace[player] = now

		if not placedFolder or not placedFolder.Parent then return end
		if not inArena(cf.Position)      then return end
		if not inRange(player, cf.Position) then return end

		if not InventoryManager.removeItem(player, itemId, 1) then return end

		local block             = Instance.new("Part")
		block.Name              = "PlacedBlock"
		block.Size              = data.size
		block.CFrame            = cf
		block.BrickColor        = data.brickColor
		block.Material          = data.material
		block.Anchored          = false
		block.CollisionGroup    = "Default"
		block.TopSurface        = Enum.SurfaceType.Smooth
		block.BottomSurface     = Enum.SurfaceType.Smooth

		local ownerTag  = Instance.new("StringValue")
		ownerTag.Name   = "Owner"
		ownerTag.Value  = tostring(player.UserId)
		ownerTag.Parent = block

		local itemTag   = Instance.new("StringValue")
		itemTag.Name    = "ItemId"
		itemTag.Value   = itemId
		itemTag.Parent  = block

		block.Parent = placedFolder

		-- Give the placing player physics authority so they can drag immediately
		block:SetNetworkOwner(player)
	end)

	-- ── StartDrag ────────────────────────────────────────
	Remotes.StartDrag.OnServerEvent:Connect(function(player, block)
		if typeof(block) ~= "Instance"    then return end
		if not block:IsA("BasePart")      then return end
		if not block.Parent               then return end
		if dragging[player]               then return end -- already dragging

		local ownerTag = block:FindFirstChild("Owner")
		if not ownerTag or ownerTag.Value ~= tostring(player.UserId) then return end

		dragging[player]       = block
		block.Anchored         = false
		block.CollisionGroup   = "DraggedBlocks"
		block:SetNetworkOwner(player)
	end)

	-- ── StopDrag (drop) ──────────────────────────────────
	Remotes.StopDrag.OnServerEvent:Connect(function(player)
		local block = dragging[player]
		dragging[player] = nil
		if not block or not block.Parent then return end

		block.CollisionGroup = "Default"
		block:SetNetworkOwnershipAuto()
	end)

	-- ── FreezeBlock ──────────────────────────────────────
	Remotes.FreezeBlock.OnServerEvent:Connect(function(player)
		local block = dragging[player]
		dragging[player] = nil
		if not block or not block.Parent then return end

		local char   = player.Character
		local ignore = char and { block, char } or { block }

		-- Must be touching something AND not clipping into it
		if not checkTouching(block, ignore)   then
			-- Not touching anything: revert to droppable, don't freeze
			block.CollisionGroup = "Default"
			block:SetNetworkOwnershipAuto()
			return
		end
		if checkOverlapping(block, ignore) then
			-- Clipping inside geometry: reject freeze
			block.CollisionGroup = "Default"
			block:SetNetworkOwnershipAuto()
			return
		end

		block.Anchored       = true
		block.CollisionGroup = "Default"
		block:SetNetworkOwnershipAuto()
	end)

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		local block = dragging[player]
		if block and block.Parent then
			block.CollisionGroup = "Default"
			block:SetNetworkOwnershipAuto()
		end
		dragging[player]  = nil
		lastPlace[player] = nil
	end)
end

return BuildManager
