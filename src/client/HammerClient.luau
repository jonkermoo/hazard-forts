-- Handles the Hammer tool.
-- While equipped:
--   • Own placed blocks are highlighted cyan (always visible)
--   • Left click + hold on own block → drag it
--   • R / T / Y → rotate 90° on Y / X / Z while dragging
--   • Right click while dragging → freeze (if touching geometry)
--   • Release left click → drop unfrozen

local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local ItemTypes        = require(game.ReplicatedStorage.Shared.ItemTypes)
local Remotes          = require(game.ReplicatedStorage.Shared.Remotes)

local HammerClient = {}

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera
local mouse       = localPlayer:GetMouse()

-- ── state ────────────────────────────────────────────────

local dragBlock    : BasePart?             = nil
local dragRotation                         = CFrame.identity
local dragBox      : SelectionBox?         = nil
local dragConn     : RBXScriptConnection?  = nil
local watchConn    : RBXScriptConnection?  = nil
local inputConns   : {RBXScriptConnection} = {}

-- own-block highlight boxes; cleaned up when each block is destroyed
local ownBoxes     : {[BasePart]: SelectionBox} = {}

-- ── raycast / positioning ─────────────────────────────────

local function mouseRaycast(): RaycastResult?
	local char   = localPlayer.Character
	local filter : {Instance} = {}
	if char      then table.insert(filter, char) end
	if dragBlock then table.insert(filter, dragBlock) end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter

	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 100, params)
end

local function getDragCFrame(size: Vector3, rotation: CFrame): CFrame
	local result = mouseRaycast()
	local pos: Vector3

	if result then
		local n = result.Normal
		local half = math.abs(n.X) * size.X / 2
		           + math.abs(n.Y) * size.Y / 2
		           + math.abs(n.Z) * size.Z / 2
		pos = result.Position + n * half
	else
		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		pos = root and (root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 2, 0))
		           or (camera.CFrame * CFrame.new(0, 0, -6)).Position
	end

	return CFrame.new(pos) * rotation
end

-- ── ownership check ───────────────────────────────────────

local function isOwnBlock(part: Instance?): boolean
	if not part or not part:IsA("BasePart") then return false end
	if part.Name ~= "PlacedBlock" then return false end
	local tag = part:FindFirstChild("Owner")
	return tag ~= nil and (tag :: StringValue).Value == tostring(localPlayer.UserId)
end

-- ── own-block highlights ─────────────────────────────────

local function addHighlight(block: BasePart)
	if ownBoxes[block] then return end

	local box               = Instance.new("SelectionBox")
	box.Adornee             = block
	box.Color3              = Color3.new(0.35, 0.85, 1)  -- cyan
	box.LineThickness       = 0.04
	box.SurfaceTransparency = 0.88
	box.Parent              = camera -- local only, does not replicate

	ownBoxes[block] = box

	-- Auto-remove if the block is destroyed (e.g. map cleanup / lava)
	block.Destroying:Connect(function()
		box:Destroy()
		ownBoxes[block] = nil
	end)
end

local function clearAllHighlights()
	for _, box in ownBoxes do box:Destroy() end
	ownBoxes = {}
end

local function scanExisting()
	for _, desc in workspace:GetDescendants() do
		if isOwnBlock(desc) then addHighlight(desc :: BasePart) end
	end
end

local function startWatching(): RBXScriptConnection
	return workspace.DescendantAdded:Connect(function(desc)
		-- Owner tag may not have replicated yet — defer one frame
		task.defer(function()
			if isOwnBlock(desc) then addHighlight(desc :: BasePart) end
		end)
	end)
end

-- ── drag ─────────────────────────────────────────────────

local function endDrag(freeze: boolean)
	if not dragBlock then return end

	if freeze then Remotes.FreezeBlock:FireServer()
	else           Remotes.StopDrag:FireServer() end

	if dragBox then dragBox:Destroy(); dragBox = nil end
	dragBlock    = nil
	dragRotation = CFrame.identity
	if dragConn then dragConn:Disconnect(); dragConn = nil end
end

local function beginDrag(block: BasePart)
	dragBlock = block

	local cf = block.CFrame
	dragRotation = CFrame.fromMatrix(Vector3.zero, cf.RightVector, cf.UpVector, -cf.LookVector)

	-- Green drag highlight on top of the existing cyan own-block highlight
	dragBox         = Instance.new("SelectionBox")
	dragBox.Adornee = block
	dragBox.Color3  = Color3.new(0.2, 1, 0.2)
	dragBox.LineThickness = 0.06
	dragBox.SurfaceTransparency = 0.7
	dragBox.Parent  = camera

	Remotes.StartDrag:FireServer(block)

	dragConn = RunService.Heartbeat:Connect(function()
		if not dragBlock or not dragBlock.Parent then
			endDrag(false)
			return
		end
		local idVal = dragBlock:FindFirstChild("ItemId")
		local data  = idVal and ItemTypes[(idVal :: StringValue).Value]
		if not data then return end
		dragBlock.CFrame = getDragCFrame(data.size, dragRotation)
	end)
end

-- ── input ─────────────────────────────────────────────────

local function onMouseDown()
	if dragBlock then return end
	local result = mouseRaycast()
	if isOwnBlock(result and result.Instance) then
		beginDrag(result.Instance :: BasePart)
	end
end

local function onMouseUp()
	if dragBlock then endDrag(false) end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if dragBlock then endDrag(true) end

	elseif input.KeyCode == Enum.KeyCode.R then
		if dragBlock then dragRotation = dragRotation * CFrame.Angles(0, math.rad(90), 0) end
	elseif input.KeyCode == Enum.KeyCode.T then
		if dragBlock then dragRotation = dragRotation * CFrame.Angles(math.rad(90), 0, 0) end
	elseif input.KeyCode == Enum.KeyCode.Y then
		if dragBlock then dragRotation = dragRotation * CFrame.Angles(0, 0, math.rad(90)) end
	end
end

-- ── public ───────────────────────────────────────────────

function HammerClient.onEquip()
	scanExisting()
	watchConn = startWatching()

	-- Mouse events bypass the "processed" flag that Tool.Activated sets
	table.insert(inputConns, mouse.Button1Down:Connect(onMouseDown))
	table.insert(inputConns, mouse.Button1Up:Connect(onMouseUp))
	table.insert(inputConns, UserInputService.InputBegan:Connect(onInputBegan))
end

function HammerClient.onUnequip()
	if dragBlock then endDrag(false) end

	clearAllHighlights()
	if dragBox   then dragBox:Destroy();   dragBox   = nil end
	if dragConn  then dragConn:Disconnect(); dragConn  = nil end
	if watchConn then watchConn:Disconnect(); watchConn = nil end
	for _, c in inputConns do c:Disconnect() end
	inputConns = {}
end

return HammerClient
