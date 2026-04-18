local Players     = game:GetService("Players")
local HammerClient = require(script.HammerClient)
local PlaceClient  = require(script.PlaceClient)

local localPlayer = Players.LocalPlayer

local function setupCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end

		if child.Name == "Hammer" then
			HammerClient.onEquip()
		elseif child:FindFirstChild("ItemId") then
			PlaceClient.onEquip(child :: Tool)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then return end

		if child.Name == "Hammer" then
			HammerClient.onUnequip()
		else
			PlaceClient.onUnequip()
		end
	end)
end

if localPlayer.Character then
	setupCharacter(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(setupCharacter)
