local SharedData = {}

local function isInBase(basePart, position)
	local relativePos = basePart.CFrame:PointToObjectSpace(position)
	local size = basePart.Size / 2
	return math.abs(relativePos.X) <= size.X and
		math.abs(relativePos.Y) <= size.Y and
		math.abs(relativePos.Z) <= size.Z
end

SharedData.isInBase = isInBase
SharedData.playerToBase = {}
SharedData.assignments = {}
SharedData.bases = {}

return SharedData