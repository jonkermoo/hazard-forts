-- Manages loot box interaction: clicking, destruction, drop spawning, and pickup.

local Players          = game:GetService("Players")
local ItemTypes        = require(game.ReplicatedStorage.Shared.ItemTypes)
local InventoryManager = require(script.Parent.InventoryManager)

local LootBoxManager = {}

local activeConnections = {}
local currentMapFolder  = nil

-- ── drop pickup ──────────────────────────────────────────

local function spawnDrop(itemId: string, position: Vector3)
	local data = ItemTypes[itemId]

	-- Glowing pickup sphere
	local drop          = Instance.new("Part")
	drop.Name           = "Drop"
	drop.Shape          = Enum.PartType.Ball
	drop.Size           = Vector3.new(1.2, 1.2, 1.2)
	drop.BrickColor     = data.brickColor
	drop.Material       = Enum.Material.Neon
	drop.CastShadow     = false
	drop.CanCollide     = true
	drop.Position       = position + Vector3.new(
		math.random(-2, 2), 1.5, math.random(-2, 2)
	)
	drop.Parent         = currentMapFolder

	-- Tag so building system can ignore drops
	local tag   = Instance.new("StringValue")
	tag.Name    = "ItemId"
	tag.Value   = itemId
	tag.Parent  = drop

	-- Floating label
	local gui              = Instance.new("BillboardGui")
	gui.Size               = UDim2.new(0, 120, 0, 28)
	gui.StudsOffset        = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop        = false
	gui.Parent             = drop

	local lbl              = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = data.displayName
	lbl.TextColor3         = Color3.new(1, 1, 1)
	lbl.TextStrokeColor3   = Color3.new(0, 0, 0)
	lbl.TextStrokeTransparency = 0.5
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.Parent             = gui

	-- Pickup on touch — claimed flag prevents double-collect
	local claimed = false
	local conn
	conn = drop.Touched:Connect(function(hit)
		if claimed then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		claimed = true
		conn:Disconnect()
		drop:Destroy()
		InventoryManager.addItem(player, itemId, 1)
	end)

	-- Auto-despawn after 45 s if nobody picked it up
	task.delay(45, function()
		if drop.Parent then drop:Destroy() end
	end)
end

-- ── loot box setup ───────────────────────────────────────

local function setupBox(box: Part)
	local cd                    = Instance.new("ClickDetector")
	cd.MaxActivationDistance    = 15
	cd.Parent                   = box

	local conn = cd.MouseClick:Connect(function(_player: Player)
		local hp = box:FindFirstChild("HP")
		if not hp then return end

		hp.Value -= 1

		-- Visual feedback: darken the box slightly each hit
		box.Transparency = 1 - (hp.Value / 3)

		if hp.Value <= 0 then
			local pos = box.Position
			box:Destroy()

			local dropCount = math.random(2, 4)
			for _ = 1, dropCount do
				spawnDrop(ItemTypes.randomId(), pos)
			end
		end
	end)

	table.insert(activeConnections, conn)
end

-- ── public ───────────────────────────────────────────────

-- Call this right after MapManager.createMap()
function LootBoxManager.initMap(mapFolder: Folder)
	currentMapFolder = mapFolder

	for _, obj in mapFolder:GetDescendants() do
		if obj:IsA("Part") and obj.Name == "LootBox" then
			setupBox(obj)
		end
	end
end

-- Call this when the map is destroyed
function LootBoxManager.cleanup()
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	activeConnections  = {}
	currentMapFolder   = nil
end

return LootBoxManager
