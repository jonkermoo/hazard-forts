-- Handles item tools (Wood Plank, Wood Crate, etc.).
-- Tool.Activated (left click) → fire PlaceBlock at the mouse cursor.
-- No dragging — that's the Hammer's job.

local Players  = game:GetService("Players")
local ItemTypes = require(game.ReplicatedStorage.Shared.ItemTypes)
local Remotes   = require(game.ReplicatedStorage.Shared.Remotes)

local PlaceClient = {}

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local activeConns: {RBXScriptConnection} = {}

local function getPlaceCFrame(size: Vector3): CFrame
	local mouse  = localPlayer:GetMouse()
	local char   = localPlayer.Character
	local filter : {Instance} = {}
	if char then table.insert(filter, char) end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter

	local ray    = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 100, params)

	local pos: Vector3
	if result then
		local n    = result.Normal
		local half = math.abs(n.X) * size.X / 2
		           + math.abs(n.Y) * size.Y / 2
		           + math.abs(n.Z) * size.Z / 2
		pos = result.Position + n * half
	else
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		pos = root and (root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 2, 0))
		           or (camera.CFrame * CFrame.new(0, 0, -6)).Position
	end

	return CFrame.new(pos)
end

function PlaceClient.onEquip(tool: Tool)
	local tag  = tool:FindFirstChild("ItemId")
	if not tag then return end
	local itemId = (tag :: StringValue).Value
	local data   = ItemTypes[itemId]
	if not data  then return end

	-- Tool.Activated fires on left click — not swallowed by anything
	local conn = tool.Activated:Connect(function()
		Remotes.PlaceBlock:FireServer(itemId, getPlaceCFrame(data.size))
	end)

	table.insert(activeConns, conn)
end

function PlaceClient.onUnequip()
	for _, c in activeConns do c:Disconnect() end
	activeConns = {}
end

return PlaceClient
