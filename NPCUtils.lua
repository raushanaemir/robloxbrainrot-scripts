-- NPC UTILITIES MODULE
-- Place this as a ModuleScript INSIDE the main NPCSpawner script, named "NPCUtils"

local NPCUtils = {}

function NPCUtils.resetNPCOwnership(npc, rootPart)
	npc:SetAttribute("Owned", false)
	npc:SetAttribute("Owner", "")
	npc:SetAttribute("Equipped", false)
	npc:SetAttribute("Contained", false)

	-- Reset name display
	local billboard = rootPart:FindFirstChild("NameDisplay")
	if billboard then
		billboard.Size = UDim2.new(0, 300, 0, 60)

		local container = billboard:FindFirstChildOfClass("Frame")
		if container then
			local nameLabel = container:FindFirstChild("NameLabel")
			local statusLabel = container:FindFirstChild("StatusLabel")
			local status = npc:GetAttribute("Status")

			if status and status ~= "None" then
				if nameLabel then
					nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
					nameLabel.Position = UDim2.new(0, 0, 0, -6) -- RAISED
					nameLabel.Text = "NPC"
					nameLabel.TextXAlignment = Enum.TextXAlignment.Center
					nameLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
				end

				if not statusLabel then
					statusLabel = Instance.new("TextLabel")
					statusLabel.Name = "StatusLabel"
					statusLabel.Size = UDim2.new(1, 0, 0.33, 0)
					statusLabel.Position = UDim2.new(0, 0, 0.33, 0)
					statusLabel.BackgroundTransparency = 1
					statusLabel.Font = Enum.Font.GothamBold
					statusLabel.TextSize = 18
					statusLabel.TextStrokeTransparency = 0
					statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					statusLabel.TextXAlignment = Enum.TextXAlignment.Center
					statusLabel.Parent = container
				end

				-- Get status display info from universal statuses
				local NPCConfig = require(script.Parent.Parent.NPCConfig)
				for _, statusData in ipairs(NPCConfig.statuses) do
					if statusData.name == status then
						statusLabel.Text = statusData.displayText
						statusLabel.TextColor3 = statusData.color
						break
					end
				end
			else
				if nameLabel then
					nameLabel.Size = UDim2.new(1, 0, 0.66, 0)
					nameLabel.Position = UDim2.new(0, 0, 0, 0)
					nameLabel.Text = "NPC"
					nameLabel.TextXAlignment = Enum.TextXAlignment.Center
					nameLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
				end
				if statusLabel then
					statusLabel:Destroy()
				end
			end

			if not infoFrame then
				infoFrame = Instance.new("Frame")
				infoFrame.Name = "InfoRow"
				infoFrame.Size = UDim2.new(1, 0, 0.34, 0)
				infoFrame.Position = UDim2.new(0, 0, 0.6, -2)
				infoFrame.BackgroundTransparency = 1
				infoFrame.Parent = container

				local infoLayout = Instance.new("UIListLayout")
				infoLayout.Parent = infoFrame
				infoLayout.FillDirection = Enum.FillDirection.Horizontal
				infoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				infoLayout.Padding = UDim.new(0, 4)
			end
		end
	end
end

return NPCUtils