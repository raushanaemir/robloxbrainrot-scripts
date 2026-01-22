local ReplicatedStorage = game:GetService("ReplicatedStorage")
local feedEvent = ReplicatedStorage:WaitForChild("FeedCreature")
local feedLimitEvent = Instance.new("RemoteFunction")
feedLimitEvent.Name = "GetFeedLimit"
feedLimitEvent.Parent = ReplicatedStorage
local creature = workspace:WaitForChild("FeedTest")

-- CONFIGURABLE: number of feeds to grow
local FEEDS_PER_GROW = 2
-- CONFIGURABLE: growth multiplier each cycle
local GROWTH_MULTIPLIER = 2

-- Feed counter
local feedCount = Instance.new("IntValue")
feedCount.Name = "FeedCount"
feedCount.Value = 0
feedCount.Parent = creature

-- Track how many times the creature has grown
local growthLevel = Instance.new("IntValue")
growthLevel.Name = "GrowthLevel"
growthLevel.Value = 0
growthLevel.Parent = creature

-- Resize function using Scale property
local function uniformResize()
	local model = creature
	if model:IsA("Model") then
		local scale = model:FindFirstChild("Scale")
		if not scale then
			scale = Instance.new("NumberValue")
			scale.Name = "Scale"
			scale.Parent = model
		end

		-- Set the scale based on growth level
		local newScale = GROWTH_MULTIPLIER ^ growthLevel.Value

		-- Apply scale to all BaseParts in the model
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Use the Size property with original size * scale
				-- Or if the model has a PrimaryPart, use Model:ScaleTo()
			end
		end

		-- Better approach: Use Model:ScaleTo() if available
		if model.PrimaryPart then
			model:ScaleTo(newScale)
		end
	end
end

-- RemoteFunction to let client get FEEDS_PER_GROW
feedLimitEvent.OnServerInvoke = function(player)
	return FEEDS_PER_GROW
end

-- Feeding
feedEvent.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end
	local tool = character:FindFirstChild("Food")
	if not tool then return end

	-- Consume food
	tool:Destroy()
	print(player.Name, "fed the creature.")

	-- Increase feed count
	feedCount.Value += 1
	print("Feed count is now:", feedCount.Value .. "/" .. FEEDS_PER_GROW)

	-- Check if feed limit reached
	if feedCount.Value >= FEEDS_PER_GROW then
		-- Increase growth tracker
		growthLevel.Value += 1
		print("Scaling model! Growth level:", growthLevel.Value)
		uniformResize()

		-- Reset feed counter
		feedCount.Value = 0
	end
end)