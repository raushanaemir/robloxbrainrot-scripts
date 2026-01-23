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

	billboard.Size = UDim2.new(0, 300, 0, 120)
	billboard.StudsOffset = Vector3.new(0, 5, 0)

	local container = billboard:FindFirstChildOfClass("Frame")
	if not container then return end

	local nameLabel = container:FindFirstChild("NameLabel")
	local statusLabel = container:FindFirstChild("StatusLabel")
	local priceCPSFrame = container:FindFirstChild("PriceCPSFrame")
	local status = npc:GetAttribute("Status")

	local NPCConfig = require(script.Parent.Parent.NPCConfig)
	local rarity = npc:GetAttribute("Rarity") or "Common"
	local rarityInfo = NPCConfig.getRarityInfo(rarity)

	if nameLabel then
		nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextColor3 = rarityInfo.color
		local displayName = npc:GetAttribute("DisplayName") or "NPC"
		nameLabel.Text = ownerName
			and (displayName .. " (" .. ownerName .. "'s)")
			or displayName
	end

	local hasStatus = status and status ~= "None"

	-- Always show status if NPC has one
	if hasStatus then
		if not statusLabel then
			statusLabel = Instance.new("TextLabel")
			statusLabel.Name = "StatusLabel"
			statusLabel.Size = UDim2.new(1, 0, 0.2, 0)
			statusLabel.Position = UDim2.new(0, 0, 0.2, 0)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Font = Enum.Font.GothamBold
			statusLabel.TextSize = 18
			statusLabel.TextStrokeTransparency = 0
			statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			statusLabel.TextXAlignment = Enum.TextXAlignment.Center
			statusLabel.Parent = container
		end

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
	end

	-- Price and CPS horizontal frame
	if not priceCPSFrame then
		priceCPSFrame = Instance.new("Frame")
		priceCPSFrame.Name = "PriceCPSFrame"
		priceCPSFrame.BackgroundTransparency = 1
		priceCPSFrame.Size = UDim2.new(1, 0, 0.2, 0)
		priceCPSFrame.Parent = container

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = priceCPSFrame
	end

	-- Price label
	local priceLabel = priceCPSFrame:FindFirstChild("PriceLabel")
	if not priceLabel then
		priceLabel = Instance.new("TextLabel")
		priceLabel.Name = "PriceLabel"
		priceLabel.Size = UDim2.new(0.5, 0, 1, 0)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.TextSize = 16
		priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		priceLabel.TextStrokeTransparency = 0
		priceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		priceLabel.TextXAlignment = Enum.TextXAlignment.Left
		priceLabel.LayoutOrder = 1
		priceLabel.Parent = priceCPSFrame
	end

	-- CPS label
	local cpsLabel = priceCPSFrame:FindFirstChild("CPSLabel")
	if not cpsLabel then
		cpsLabel = Instance.new("TextLabel")
		cpsLabel.Name = "CPSLabel"
		cpsLabel.Size = UDim2.new(0.5, 0, 1, 0)
		cpsLabel.BackgroundTransparency = 1
		cpsLabel.Font = Enum.Font.GothamBold
		cpsLabel.TextSize = 16
		cpsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		cpsLabel.TextStrokeTransparency = 0
		cpsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		cpsLabel.TextXAlignment = Enum.TextXAlignment.Right
		cpsLabel.LayoutOrder = 2
		cpsLabel.Parent = priceCPSFrame
	end

	-- Position priceCPSFrame below status or name
	priceCPSFrame.Position = hasStatus and UDim2.new(0, 0, 0.4, 0) or UDim2.new(0, 0, 0.2, 0)

	local price = npc:GetAttribute("Price") or 100
	local cps = 0
	do
		local NPCConfig = require(script.Parent.Parent.NPCConfig)
		local brainrotTypeName = npc:GetAttribute("NPCType")
		for _, t in ipairs(NPCConfig.brainrotTypes) do
			if t.modelName == brainrotTypeName then
				cps = t.coinsPerSecond or 0
				break
			end
		end
	end

	-- Hide price/cps if owned
	if npc:GetAttribute("Owned") then
		priceCPSFrame.Visible = false
	else
		priceLabel.Text = "$" .. price
		cpsLabel.Text = "+ " .. cps .. "cps"
		priceCPSFrame.Visible = true
	end
end

local function applyTypeEffect(player, npc)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Get effect from NPC attributes
	local walkSpeedBonus = npc:GetAttribute("Effect_WalkSpeedBonus") or 0
	local jumpPowerBonus = npc:GetAttribute("Effect_JumpPowerBonus") or 0
	local description = npc:GetAttribute("Effect_Description") or ""

	-- Store original stats
	if not player:GetAttribute("OriginalWalkSpeed") then
		player:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
	end
	if not player:GetAttribute("OriginalJumpPower") then
		player:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
	end

	-- Apply bonuses
	humanoid.WalkSpeed = (player:GetAttribute("OriginalWalkSpeed") or 16) + walkSpeedBonus
	humanoid.JumpPower = (player:GetAttribute("OriginalJumpPower") or 50) + jumpPowerBonus

	player:SetAttribute("ActiveTypeEffect", description)
	print(player.Name .. " gained effect: " .. description)

	-- === COINS PER SECOND EFFECT ===
	local NPCConfig = require(script.Parent.Parent.NPCConfig)
	local brainrotTypeName = npc:GetAttribute("NPCType")
	local brainrotType
	for _, t in ipairs(NPCConfig.brainrotTypes) do
		if t.modelName == brainrotTypeName then
			brainrotType = t
			break
		end
	end
	local cps = (brainrotType and brainrotType.coinsPerSecond) or 0
	if _G.CoinSystem then
		_G.CoinSystem.SetCoinsPerSecond(player, cps)
	end
end

local function removeTypeEffect(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local originalWalkSpeed = player:GetAttribute("OriginalWalkSpeed") or 16
	local originalJumpPower = player:GetAttribute("OriginalJumpPower") or 50

	humanoid.WalkSpeed = originalWalkSpeed
	humanoid.JumpPower = originalJumpPower

	local activeEffect = player:GetAttribute("ActiveTypeEffect")
	player:SetAttribute("ActiveTypeEffect", "")
	print(player.Name .. " lost effect: " .. (activeEffect or "None"))

	-- === REMOVE COINS PER SECOND EFFECT ===
	if _G.CoinSystem then
		_G.CoinSystem.SetCoinsPerSecond(player, 0)
	end
end

return function(npc, humanoid, rootPart, buyPrompt, stealPrompt, equipPrompt, unequipPrompt)
	local CoinSystem = _G.CoinSystem

	-- Helper to update buyPrompt.Enabled based on player's coins
	local function updateBuyPrompt()
		if npc:GetAttribute("Owned") then
			buyPrompt.Enabled = false
			return
		end
		-- Only show for players who can afford
		buyPrompt.Enabled = false
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			if CoinSystem and CoinSystem.CanAfford(player, npc:GetAttribute("Price") or 100) then
				buyPrompt.Enabled = true
				break
			end
		end
	end

	-- Initial check
	updateBuyPrompt()

	-- Listen for coin changes to update prompt (client UI should also update, but this covers server-side)
	game:GetService("Players").PlayerAdded:Connect(function(player)
		player:GetPropertyChangedSignal("leaderstats"):Connect(updateBuyPrompt)
	end)

	-- Buy logic
	buyPrompt.Triggered:Connect(function(player)
		if npc:GetAttribute("Owned") then return end

		local price = npc:GetAttribute("Price") or 100
		local CoinSystem = _G.CoinSystem

		if not CoinSystem then
			warn("CoinSystem not initialized!")
			return
		end

		-- Check if player can afford
		if not CoinSystem.CanAfford(player, price) then
			print(player.Name .. " cannot afford NPC (need " .. price .. " coins, has " .. CoinSystem.GetCoins(player) .. ")")
			updateBuyPrompt()
			return
		end

		-- Deduct coins
		local success = CoinSystem.RemoveCoins(player, price)
		if not success then
			print(player.Name .. " purchase failed!")
			updateBuyPrompt()
			return
		end

		npc:SetAttribute("Owned", true)
		npc:SetAttribute("Owner", player.Name)
		npc:SetAttribute("Equipped", true)

		updateNameDisplay(npc, rootPart, player.Name)

		local followSpeed = npc:GetAttribute("FollowSpeed")
		humanoid.WalkSpeed = followSpeed or 16
		enableAutoJump(npc, humanoid, rootPart)

		-- Apply brainrot type effect to player
		applyTypeEffect(player, npc)

		print(player.Name .. " bought NPC for " .. price .. " coins (equipped)")

		-- Hide buy prompt and show steal prompt
		buyPrompt.Enabled = false
		stealPrompt.Enabled = true
	end)

	-- Update prompt if coins change (server-side fallback)
	game:GetService("Players").PlayerAdded:Connect(function(player)
		player.leaderstats.Coins.Changed:Connect(updateBuyPrompt)
	end)

	-- Steal logic
	stealPrompt.Triggered:Connect(function(player)
		local currentOwnerName = npc:GetAttribute("Owner")
		if currentOwnerName == "" or currentOwnerName == player.Name then return end

		-- Remove effect from old owner
		local oldOwner = game:GetService("Players"):FindFirstChild(currentOwnerName)
		if oldOwner then
			removeTypeEffect(oldOwner)
		end

		print(player.Name .. " stole NPC from " .. currentOwnerName)
		npc:SetAttribute("Owner", player.Name)
		npc:SetAttribute("Equipped", true)

		updateNameDisplay(npc, rootPart, player.Name)

		local followSpeed = npc:GetAttribute("FollowSpeed")
		humanoid.WalkSpeed = followSpeed or 16
		enableAutoJump(npc, humanoid, rootPart)

		-- Apply brainrot type effect to new owner
		applyTypeEffect(player, npc)
	end)

	equipPrompt.Triggered:Connect(function(player)
		local ownerName = npc:GetAttribute("Owner")
		if ownerName ~= player.Name then return end
		if npc:GetAttribute("Equipped") then return end

		npc:SetAttribute("Equipped", true)
		applyTypeEffect(player, npc)
		print(player.Name .. " equipped NPC")
	end)

	unequipPrompt.Triggered:Connect(function(player)
		local ownerName = npc:GetAttribute("Owner")
		if ownerName ~= player.Name then return end
		if not npc:GetAttribute("Equipped") then return end

		npc:SetAttribute("Equipped", false)
		removeTypeEffect(player)
		print(player.Name .. " unequipped NPC (individual)")

		-- Check if NPC is outside base
		local ownerBase = Shared.playerToBase[player]
		if ownerBase and not Shared.isInBase(ownerBase, rootPart.Position) then
			print(npc.Name .. " is outside base, will return")
		end
	end)
end