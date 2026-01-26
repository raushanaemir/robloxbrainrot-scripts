-- SHARED DATA MODULE
-- Stores shared state between server scripts

local Shared = {}

-- Track which player owns which base
Shared.playerToBase = {} -- playerToBase[player] = basePart/baseModel

-- Track player base levels
Shared.playerBaseLevels = {} -- playerBaseLevels[player] = level (1, 2, or 3)

-- Track accumulated coins per base (set by BaseManager)
Shared.baseAccumulatedCoins = {}

-- Helper function to check if a position is inside a base
function Shared.isInBase(base, position)
	if not base then return false end

	local basePart = base
	if base:IsA("Model") then
		basePart = base.PrimaryPart or base:FindFirstChildWhichIsA("BasePart")
	end

	if not basePart then return false end

	local baseCFrame = basePart.CFrame
	local baseSize = basePart.Size

	-- Convert position to local space
	local localPos = baseCFrame:PointToObjectSpace(position)

	-- Check if within bounds (with some tolerance)
	local halfSize = baseSize / 2
	local tolerance = 2 -- studs of tolerance

	return math.abs(localPos.X) <= halfSize.X + tolerance
		and math.abs(localPos.Y) <= halfSize.Y + tolerance + 10 -- Extra Y tolerance for height
		and math.abs(localPos.Z) <= halfSize.Z + tolerance
end

-- Helper function to get player's current base level
function Shared.getPlayerBaseLevel(player)
	return Shared.playerBaseLevels[player] or 1
end

-- Helper function to get a specific container by level (returns nil if hidden/invisible)
function Shared.getContainerByLevel(player, level)
	local base = Shared.playerToBase[player]
	if not base then return nil end

	local baseLevel = base:FindFirstChild("BaseLevel" .. level)
	if not baseLevel then return nil end

	local container = baseLevel:FindFirstChild("Container")
	if not container then return nil end

	-- Check if container is visible (not hidden)
	if container:IsA("BasePart") then
		if container.Transparency >= 1 then
			return nil -- Container is hidden
		end
	elseif container:IsA("Model") then
		-- Check first BasePart in model
		local firstPart = container:FindFirstChildWhichIsA("BasePart")
		if firstPart and firstPart.Transparency >= 1 then
			return nil -- Container is hidden
		end
	end

	return container
end

-- Helper function to get the current container for a player's base (based on player's level)
function Shared.getCurrentContainer(player)
	local level = Shared.playerBaseLevels[player] or 1
	return Shared.getContainerByLevel(player, level)
end

-- Helper function to check if a position is inside a container
function Shared.isInContainer(container, position)
	if not container then return false end

	local containerCFrame, containerSize
	if container:IsA("BasePart") then
		containerCFrame = container.CFrame
		containerSize = container.Size
	elseif container:IsA("Model") then
		containerCFrame, containerSize = container:GetBoundingBox()
	else
		return false
	end

	-- Convert position to local space
	local localPos = containerCFrame:PointToObjectSpace(position)

	-- Check if within bounds
	local halfSize = containerSize / 2
	local tolerance = 1

	return math.abs(localPos.X) <= halfSize.X + tolerance
		and math.abs(localPos.Y) <= halfSize.Y + tolerance + 5
		and math.abs(localPos.Z) <= halfSize.Z + tolerance
end

-- Helper function to check if a position is inside ANY visible plot (any unlocked level)
function Shared.isInPlot(player, position)
	local base = Shared.playerToBase[player]
	if not base then return false, nil end

	local maxLevel = Shared.playerBaseLevels[player] or 1

	-- Check all unlocked plots (levels 1 to maxLevel)
	for level = 1, maxLevel do
		local baseLevel = base:FindFirstChild("BaseLevel" .. level)
		if baseLevel then
			local plot = baseLevel:FindFirstChild("Plot")
			if plot then
				local plotCFrame, plotSize
				if plot:IsA("BasePart") then
					plotCFrame = plot.CFrame
					plotSize = plot.Size
				elseif plot:IsA("Model") then
					plotCFrame, plotSize = plot:GetBoundingBox()
				end

				if plotCFrame and plotSize then
					local localPos = plotCFrame:PointToObjectSpace(position)

					local halfSize = plotSize / 2
					local tolerance = 5 -- Increased tolerance

					local inThisPlot = math.abs(localPos.X) <= halfSize.X + tolerance
						and math.abs(localPos.Y) <= halfSize.Y + tolerance + 15 -- More Y tolerance
						and math.abs(localPos.Z) <= halfSize.Z + tolerance

					if inThisPlot then
						return true, level
					end
				end
			end
		end
	end

	return false, nil
end

-- Helper function to find which container an NPC should be in based on its position
function Shared.findContainerForPosition(player, position)
	local base = Shared.playerToBase[player]
	if not base then return nil, nil end

	local maxLevel = Shared.playerBaseLevels[player] or 1

	-- Check all unlocked containers
	for level = 1, maxLevel do
		local container = Shared.getContainerByLevel(player, level)
		if container and Shared.isInContainer(container, position) then
			return container, level
		end
	end

	-- Default to level 1 container if not found
	return Shared.getContainerByLevel(player, 1), 1
end

-- Functions to be set by BaseManager
Shared.addCoinsToBase = function() end
Shared.getBaseAccumulatedCoins = function() return 0 end
Shared.collectBaseCoins = function() return 0 end

return Shared