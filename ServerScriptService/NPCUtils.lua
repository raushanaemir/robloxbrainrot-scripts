-- NPC UTILITIES MODULE
-- Place this as a ModuleScript INSIDE the main NPCSpawner script, named "NPCUtils"

local NPCUtils = {}

local TEXT_SIZE = 18 -- consistent size for all NPC display labels
local LINE_PADDING = 6
local LINE_HEIGHT = TEXT_SIZE + LINE_PADDING
local BILLBOARD_WIDTH = 220

function NPCUtils.resetNPCOwnership(npc, rootPart)
	npc:SetAttribute("Owned", false)
	npc:SetAttribute("Owner", "")
	npc:SetAttribute("Equipped", false)
	npc:SetAttribute("Contained", false)

	-- Use LabelPart for label attachment if it exists
	local labelPart = npc:FindFirstChild("LabelPart") or rootPart

	-- Recompute model height and adjust attachment so billboard sits relative to NPC height
	local modelHeight = 0
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			local topY = (part.Position.Y + part.Size.Y / 2) - labelPart.Position.Y
			if topY > modelHeight then
				modelHeight = topY
			end
		end
	end
	-- Place the billboard way above the model (much higher than before)
	local billboardOffset = modelHeight + 12.0  -- was 3.0, now much higher
	local attach = labelPart:FindFirstChild("NameDisplayAttachment")
	if not attach then
		attach = Instance.new("Attachment")
		attach.Name = "NameDisplayAttachment"
		attach.Parent = labelPart
	end
	attach.Position = Vector3.new(0, billboardOffset, 0)

	-- Find billboard on labelPart
	local billboard = labelPart:FindFirstChild("NameDisplay")
	if billboard then
		-- Determine lines (name + optional status + cps + price)
		local status = npc:GetAttribute("Status")
		local numLines = 3 + (status and status ~= "None" and status ~= "" and 1 or 0)
		local totalHeight = (LINE_HEIGHT * numLines) + 8

		-- Use absolute pixel size consistent with NPCSpawner
		billboard.Size = UDim2.new(0, BILLBOARD_WIDTH, 0, totalHeight)

		local container = billboard:FindFirstChildOfClass("Frame")
		if container then
			-- NameLabel
			local nameLabel = container:FindFirstChild("NameLabel")
			if nameLabel then
				nameLabel.LayoutOrder = 1
			end
			-- StatusLabel
			local statusLabel = container:FindFirstChild("StatusLabel")
			if statusLabel then
				statusLabel.LayoutOrder = 2
			end
			-- CPSLabel
			local cpsLabel = container:FindFirstChild("CPSLabel")
			if cpsLabel then
				cpsLabel.LayoutOrder = 3
			end
			-- Spacer
			local spacer = container:FindFirstChild("Spacer")
			if spacer then
				spacer.LayoutOrder = 4
			end
			-- PriceLabel
			local priceLabel = container:FindFirstChild("PriceLabel")
			if priceLabel then
				priceLabel.LayoutOrder = 5
			end
		end
	end
end

return NPCUtils