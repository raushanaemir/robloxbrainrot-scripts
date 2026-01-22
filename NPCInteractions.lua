-- NPC INTERACTIONS MODULE
-- Place this as a ModuleScript INSIDE the main NPCSpawner script, named "NPCInteractions"

local Shared = require(script.Parent.Parent.SharedData)

local RunService = game:GetService("RunService")

local function enableAutoJump(npc, humanoid, rootPart)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { npc }
	rayParams.IgnoreWater = true

	local CONNECTION

	CONNECTION = RunService.Heartbeat:Connect(function()
		if not npc.Parent or humanoid.Health <= 0 then
			CONNECTION:Disconnect()
			return
		end

		-- Only jump while moving
		if humanoid.MoveDirection.Magnitude < 0.1 then
			return
		end

		-- Raycast forward
		local origin = rootPart.Position
		local direction = humanoid.MoveDirection.Unit * 3

		local result = workspace:Raycast(origin, direction, rayParams)
		if not result then return end

		local hitPos = result.Position
		local heightDifference = hitPos.Y - (rootPart.Position.Y - rootPart.Size.Y / 2)

		-- Jump if obstacle is 1 stud or higher
		if heightDifference >= 1 then
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
end


local function updateNameDisplay(npc, rootPart, ownerName)
	local billboard = rootPart:FindFirstChild("NameDisplay")
	if not billboard then return end

	-- ensure size and raised placement
	billboard.Size = UDim2.new(0, 300, 0, 72)
	billboard.StudsOffset = Vector3.new(0, 5, 0)

	local container = billboard:FindFirstChildOfClass("Frame")
	if not container then return end

	local nameLabel = container:FindFirstChild("NameLabel")
	local statusLabel = container:FindFirstChild("StatusLabel")
	local infoFrame = container:FindFirstChild("InfoRow")
	local status = npc:GetAttribute("Status")

	-- Get rarity info
	local NPCConfig = require(script.Parent.Parent.NPCConfig)
	local rarity = npc:GetAttribute("Rarity") or "Common"
	local rarityInfo = NPCConfig.getRarityInfo(rarity)

	if nameLabel then
		nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextColor3 = rarityInfo.color -- Use rarity color!

		-- Display rarity prefix if it exists
		local rarityPrefix = rarityInfo.displayText ~= "" and (rarityInfo.displayText .. " ") or ""
		local displayName = npc:GetAttribute("DisplayName") or "NPC"

		nameLabel.Text = ownerName
			and (rarityPrefix .. displayName .. " (" .. ownerName .. "'s)")
			or  (rarityPrefix .. displayName)
	end

	-- Handle status label based on NPC's status attribute
	if status and status ~= "None" then
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

		-- Find the matching status (universal statuses)
		for _, statusData in ipairs(NPCConfig.statuses) do
			if statusData.name == status then
				statusLabel.Text = statusData.displayText
				statusLabel.TextColor3 = statusData.color
				break
			end
		end
	else
		if statusLabel then
			statusLabel:Destroy()
		end
		if nameLabel then
			nameLabel.Size = UDim2.new(1, 0, 0.66, 0)
			nameLabel.Position = UDim2.new(0, 0, 0, 0)
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

return function(npc, humanoid, rootPart, buyPrompt, stealPrompt, equipPrompt, unequipPrompt)
	-- Buy logic
	buyPrompt.Triggered:Connect(function(player)
		if npc:GetAttribute("Owned") then return end

		npc:SetAttribute("Owned", true)
		npc:SetAttribute("Owner", player.Name)
		npc:SetAttribute("Equipped", true)

		updateNameDisplay(npc, rootPart, player.Name)

		local followSpeed = npc:GetAttribute("FollowSpeed")
		humanoid.WalkSpeed = followSpeed or 16
		enableAutoJump(npc, humanoid, rootPart)

		print(player.Name .. " bought NPC (equipped)")

		-- Hide buy prompt and show steal prompt
		buyPrompt.Enabled = false
		stealPrompt.Enabled = true
	end)

	-- Steal logic
	stealPrompt.Triggered:Connect(function(player)
		local currentOwnerName = npc:GetAttribute("Owner")
		if currentOwnerName == "" or currentOwnerName == player.Name then return end

		print(player.Name .. " stole NPC from " .. currentOwnerName)
		npc:SetAttribute("Owner", player.Name)
		npc:SetAttribute("Equipped", true)

		updateNameDisplay(npc, rootPart, player.Name)

		local followSpeed = npc:GetAttribute("FollowSpeed")
		humanoid.WalkSpeed = followSpeed or 16
		enableAutoJump(npc, humanoid, rootPart)
	end)

	-- Equip prompt logic
	equipPrompt.Triggered:Connect(function(player)
		local ownerName = npc:GetAttribute("Owner")
		if ownerName ~= player.Name then return end
		if npc:GetAttribute("Equipped") then return end

		npc:SetAttribute("Equipped", true)
		print(player.Name .. " equipped NPC")
	end)

	-- Unequip prompt logic
	unequipPrompt.Triggered:Connect(function(player)
		local ownerName = npc:GetAttribute("Owner")
		if ownerName ~= player.Name then return end
		if not npc:GetAttribute("Equipped") then return end

		npc:SetAttribute("Equipped", false)
		print(player.Name .. " unequipped NPC (individual)")

		-- Check if NPC is outside base
		local ownerBase = Shared.playerToBase[player]
		if ownerBase and not Shared.isInBase(ownerBase, rootPart.Position) then
			print(npc.Name .. " is outside base, will return")
		end
	end)
end