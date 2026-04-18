-- Central definition of all RemoteEvents.
-- Server creates them; client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local function makeEvent(parent: Instance, name: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name  = name
	e.Parent = parent
	return e
end

if RunService:IsServer() then
	local folder      = Instance.new("Folder")
	folder.Name       = "Remotes"
	folder.Parent     = ReplicatedStorage

	return {
		PlaceBlock  = makeEvent(folder, "PlaceBlock"),  -- (itemId, CFrame)
		StartDrag   = makeEvent(folder, "StartDrag"),   -- (block: BasePart)
		StopDrag    = makeEvent(folder, "StopDrag"),    -- ()
		FreezeBlock = makeEvent(folder, "FreezeBlock"), -- ()
	}
else
	local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
	return {
		PlaceBlock  = folder:WaitForChild("PlaceBlock",  10),
		StartDrag   = folder:WaitForChild("StartDrag",   10),
		StopDrag    = folder:WaitForChild("StopDrag",    10),
		FreezeBlock = folder:WaitForChild("FreezeBlock", 10),
	}
end
