local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local buyEvent = ReplicatedStorage:WaitForChild("BuyFood")
local foodTemplate = ServerStorage:WaitForChild("Food")

buyEvent.OnServerEvent:Connect(function(player)
	local backpack = player:WaitForChild("Backpack")
	local newFood = foodTemplate:Clone()
	newFood.Parent = backpack
end)
