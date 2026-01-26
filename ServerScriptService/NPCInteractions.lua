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

local TEXT_SIZE = 18 -- same consistent size

local function updateNameDisplay(npc, rootPart, ownerName)
	-- Find billboard on rootPart
	local billboard = rootPart:FindFirstChild("NameDisplay")

	if not billboard then return end

	local container = billboard:FindFirstChildOfClass("Frame")
	if not container then return end

	local nameLabel = container:FindFirstChild("NameLabel")
	local statusLabel = container:FindFirstChild("StatusLabel")
	local cpsLabel = container:FindFirstChild("CPSLabel")
	local spacer = container:FindFirstChild("Spacer")
	local priceLabel = container:FindFirstChild("PriceLabel")
	local status = npc:GetAttribute("Status")

	local NPCConfig = require(script.Parent.Parent.NPCConfig)
	local rarity = npc:GetAttribute("Rarity") or "Common"
	local rarityInfo = NPCConfig.getRarityInfo(rarity)

	local displayName = npc:GetAttribute("DisplayName") or "NPC"
	local hasStatus = status and status ~= "None" and status ~= ""

	-- Update name label: keep fixed size and font
	if nameLabel then
		nameLabel.TextColor3 = rarityInfo.color
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextScaled = true -- Enable scaling
		if ownerName then
			nameLabel.Text = rarityInfo.displayText ~= ""
				and (rarityInfo.displayText .. " " .. displayName .. " (" .. ownerName .. "'s)")
				or (displayName .. " (" .. ownerName .. "'s)")
		else
			nameLabel.Text = rarityInfo.displayText ~= ""
				and (rarityInfo.displayText .. " " .. displayName)
				or displayName
		end
	end

	-- Update status label visibility and keep fixed formatting
	if statusLabel then
		statusLabel.Font = Enum.Font.GothamBlack
		statusLabel.TextScaled = true -- Enable scaling
		if hasStatus then
			for _, statusData in ipairs(NPCConfig.statuses) do
				if statusData.name == status then
					statusLabel.Text = statusData.displayText
					-- Rainbow status: animate label color
					if statusData.isRainbow then
						coroutine.wrap(function(lbl)
							while lbl.Parent do
								local t = tick()
								local r = 0.5 + 0.5 * math.sin(t * 2)
								local g = 0.5 + 0.5 * math.sin(t * 2 + 2)
								local b = 0.5 + 0.5 * math.sin(t * 2 + 4)
								lbl.TextColor3 = Color3.new(r, g, b)
								wait(0.03)
							end
						end)(statusLabel)
					else
						statusLabel.TextColor3 = statusData.color
					end
					break
				end
			end
			statusLabel.Visible = true
		else
			statusLabel.Visible = false
		end
	end

	-- Make all info labels big and toggle price/spacer visibility
	if priceLabel then
		priceLabel.Font = Enum.Font.GothamBlack
		priceLabel.TextScaled = true
	end
	if cpsLabel then
		cpsLabel.Font = Enum.Font.GothamBlack
		cpsLabel.TextScaled = true
	end

	-- Hide price and spacer when owned
	if npc:GetAttribute("Owned") then
		if priceLabel then priceLabel.Visible = false end
		if spacer then spacer.Visible = false end
		if cpsLabel then cpsLabel.Visible = true end
	else
		if priceLabel then priceLabel.Visible = true end
		if spacer then spacer.Visible = true end
		if cpsLabel then cpsLabel.Visible = true end
	end
end

local function applyTypeEffect(player, npc)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local walkSpeedBonus = npc:GetAttribute("Effect_WalkSpeedBonus") or 0
	local jumpPowerBonus = npc:GetAttribute("Effect_JumpPowerBonus") or 0
	local description = npc:GetAttribute("Effect_Description") or ""

	if not player:GetAttribute("OriginalWalkSpeed") then
		player:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
	end
	if not player:GetAttribute("OriginalJumpPower") then
		player:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
	end

	humanoid.WalkSpeed = (player:GetAttribute("OriginalWalkSpeed") or 16) + walkSpeedBonus
	humanoid.JumpPower = (player:GetAttribute("OriginalJumpPower") or 50) + jumpPowerBonus

	player:SetAttribute("ActiveTypeEffect", description)
	print(player.Name .. " gained effect: " .. description)

	-- When equipped, player does NOT get coins per second (coins only from contained unequipped NPCs)
	if _G.CoinSystem then
		_G.CoinSystem.SetCoinsPerSecond(player, 0)
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

	-- Remove coins per second when unequipped (will be handled by NPC's container coin generation)
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