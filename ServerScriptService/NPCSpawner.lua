-- NPC SPAWNING & BEHAVIOR SCRIPT (REFACTORED)
-- This Script is mapped under ServerScriptService (folder "Server") via Rojo.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")

local startPoint = Workspace:WaitForChild("StartPoint")

print("=== NPC SPAWNER & BEHAVIOR LOADED ===")

-- Load configuration and shared data
local NPCConfig = require(script.Parent.NPCConfig)
local Shared = require(script.Parent.SharedData)

-- Setup collision groups
local success, err = pcall(function()
	PhysicsService:CreateCollisionGroup("NPCs")
end)

if success then
	PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
	print("NPC collision group created - NPCs won't collide with each other")
else
	warn("Failed to create NPC collision group:", err)
end

-- Spawn NPCs continuously
task.spawn(function()
	while true do
		task.wait(6)

		-- Get random brainrot type based on spawn chances
		local brainrotType = NPCConfig.getRandomBrainrotType()
		local template = ServerStorage:FindFirstChild(brainrotType.modelName)

		if not template then
			warn("Model '" .. brainrotType.modelName .. "' not found in ServerStorage!")
			continue
		end

		local npc = template:Clone()
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local rootPart = npc:FindFirstChild("HumanoidRootPart")

		if not humanoid or not rootPart then
			warn("NPC missing Humanoid or RootPart!")
			npc:Destroy()
			continue
		end

		-- Immortal + setup
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.WalkSpeed = brainrotType.walkSpeed
		humanoid.PlatformStand = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.HealthChanged:Connect(function()
			humanoid.Health = math.huge
		end)

		-- === Load and assign animations from NPCConfig ===
		if brainrotType.idleAnimationId then
			local idleAnim = Instance.new("Animation")
			idleAnim.Name = "IdleAnimation"
			idleAnim.AnimationId = brainrotType.idleAnimationId
			idleAnim.Parent = npc
			npc:SetAttribute("IdleAnimationId", brainrotType.idleAnimationId)
		end
		if brainrotType.walkAnimationId then
			local walkAnim = Instance.new("Animation")
			walkAnim.Name = "WalkAnimation"
			walkAnim.AnimationId = brainrotType.walkAnimationId
			walkAnim.Parent = npc
			npc:SetAttribute("WalkAnimationId", brainrotType.walkAnimationId)
		end

		-- Get random status (universal - works for ANY brainrot!)
		local status = NPCConfig.getRandomStatus()
		local rarityInfo = NPCConfig.getRarityInfo(brainrotType.rarity)

		-- Use coins/s with status multiplier (pass the full status table!)
		local coinsPerSecond = NPCConfig.getCoinsPerSecond(brainrotType, status)

		-- Set attributes (support both lowercase/capital keys from config

		npc:SetAttribute("Status", status.name)
		npc:SetAttribute("NPCType", brainrotType.modelName)
		npc:SetAttribute("DisplayName", brainrotType.displayName or brainrotType.modelName)
		npc:SetAttribute("Rarity", brainrotType.rarity)
		npc:SetAttribute("WalkSpeed", brainrotType.walkSpeed)
		npc:SetAttribute("FollowSpeed", brainrotType.followSpeed)

		local npcPrice = NPCConfig.calculatePrice(brainrotType, status)
		npc:SetAttribute("Price", npcPrice)

		-- Store effect info for later use
		if brainrotType.effect then
			npc:SetAttribute("Effect_WalkSpeedBonus", brainrotType.effect.walkSpeedBonus or 0)
			npc:SetAttribute("Effect_JumpPowerBonus", brainrotType.effect.jumpPowerBonus or 0)
			npc:SetAttribute("Effect_Description", brainrotType.effect.description or "")
		end

		-- Calculate model height for billboard positioning
		local modelHeight = 0
		-- Fallback: find highest point relative to rootPart
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				local topY = (part.Position.Y + part.Size.Y / 2) - rootPart.Position.Y
				if topY > modelHeight then
					modelHeight = topY
				end
			end
		end
		-- Place the billboard way above the model (much higher than before)
		local billboardOffset = modelHeight + 3
		-- Create an Attachment on the rootPart so the billboard stays a fixed position above the model
		local attach = rootPart:FindFirstChild("NameDisplayAttachment")
		if not attach then
			attach = Instance.new("Attachment")
			attach.Name = "NameDisplayAttachment"
			attach.Parent = rootPart
		end
		attach.Position = Vector3.new(0, billboardOffset, 0)

		-- Common text size for all labels (fixed size, not scaled)
		local TEXT_SIZE = 20

		-- Create custom name display with BillboardGui attached to the attachment
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NameDisplay"
		billboard.Size = UDim2.new(8, 0, 4, 0) -- Bigger overall
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 50
		billboard.Adornee = attach
		billboard.Parent = rootPart

		local container = Instance.new("Frame")
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundTransparency = 1
		container.Parent = billboard

		-- UIListLayout for vertical stacking
		local layout = Instance.new("UIListLayout")
		layout.Parent = container
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, 2) -- Reduced padding
		layout.SortOrder = Enum.SortOrder.LayoutOrder

		-- 1. Name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, 0, 0.28, 0) -- Bigger
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = rarityInfo.color
		nameLabel.TextStrokeTransparency = 0
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		local displayName = npc:GetAttribute("DisplayName") or "NPC"
		nameLabel.Text =
			rarityInfo.displayText ~= ""
			and (rarityInfo.displayText .. " " .. displayName)
			or displayName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.LayoutOrder = 1
		nameLabel.Parent = container

		-- 2. Status label (if any)
		local hasStatus = status.displayText ~= ""
		local statusLabel
		if hasStatus then
			statusLabel = Instance.new("TextLabel")
			statusLabel.Name = "StatusLabel"
			statusLabel.Size = UDim2.new(1, 0, 0.18, 0)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Font = Enum.Font.GothamBlack
			statusLabel.TextScaled = true
			statusLabel.TextStrokeTransparency = 0
			statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			statusLabel.Text = status.displayText
			statusLabel.TextXAlignment = Enum.TextXAlignment.Center
			statusLabel.LayoutOrder = 2
			statusLabel.Parent = container

			-- Rainbow status: animate label color
			if status.isRainbow then
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
				statusLabel.TextColor3 = status.color
			end
		end

		-- 3. Coins/s label
		local cpsLabel = Instance.new("TextLabel")
		cpsLabel.Name = "CPSLabel"
		cpsLabel.Size = UDim2.new(1, 0, 0.18, 0)
		cpsLabel.BackgroundTransparency = 1
		cpsLabel.Font = Enum.Font.GothamBlack
		cpsLabel.TextScaled = true
		cpsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		cpsLabel.TextStrokeTransparency = 0
		cpsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		cpsLabel.Text = tostring(coinsPerSecond) .. " coins/s"
		cpsLabel.TextXAlignment = Enum.TextXAlignment.Center
		cpsLabel.LayoutOrder = 3
		cpsLabel.Parent = container

		-- 4. Spacer (empty line)
		local spacer = Instance.new("Frame")
		spacer.Name = "Spacer"
		spacer.Size = UDim2.new(1, 0, 0.10, 0)
		spacer.BackgroundTransparency = 1
		spacer.LayoutOrder = 4
		spacer.Parent = container

		-- 5. Price label
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Name = "PriceLabel"
		priceLabel.Size = UDim2.new(1, 0, 0.18, 0) -- Bigger
		priceLabel.BackgroundTransparency = 1
		priceLabel.Font = Enum.Font.GothamBlack
		priceLabel.TextScaled = true
		priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		priceLabel.TextStrokeTransparency = 0
		priceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		priceLabel.Text = npcPrice .. " Coins"
		priceLabel.TextXAlignment = Enum.TextXAlignment.Center
		priceLabel.LayoutOrder = 5
		priceLabel.Parent = container

		-- Hide default humanoid display
		humanoid.DisplayName = ""
		npc.Name = ""

		-- Apply visual tinting for Diamond/Gold/Shiny/etc
		NPCConfig.applyStatusVisuals(npc, status)

		-- Parts setup + No Collision with Players
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
				part.CollisionGroup = "NPCs"

				for _, player in ipairs(Players:GetPlayers()) do
					if player.Character then
						for _, playerPart in ipairs(player.Character:GetDescendants()) do
							if playerPart:IsA("BasePart") then
								local noCollision = Instance.new("NoCollisionConstraint")
								noCollision.Part0 = part
								noCollision.Part1 = playerPart
								noCollision.Parent = part
							end
						end
					end
				end
			end
		end

		local function setupNoCollisionForPlayer(player)
			player.CharacterAdded:Connect(function(character)
				task.wait(0.5)
				if npc and npc.Parent then
					for _, npcPart in ipairs(npc:GetDescendants()) do
						if npcPart:IsA("BasePart") then
							for _, playerPart in ipairs(character:GetDescendants()) do
								if playerPart:IsA("BasePart") then
									local noCollision = Instance.new("NoCollisionConstraint")
									noCollision.Part0 = npcPart
									noCollision.Part1 = playerPart
									noCollision.Parent = npcPart
								end
							end
						end
					end
				end
			end)
		end

		for _, player in ipairs(Players:GetPlayers()) do
			setupNoCollisionForPlayer(player)
		end
		Players.PlayerAdded:Connect(setupNoCollisionForPlayer)

		-- Initialize attributes
		npc:SetAttribute("Owner", "")
		npc:SetAttribute("Owned", false)
		npc:SetAttribute("Equipped", false)
		npc:SetAttribute("Contained", false)

		npc.Parent = Workspace
		task.wait(0.3)

		-- Spawn position
		local spawnCFrame = CFrame.new(startPoint.Position.X, startPoint.Position.Y + 3, startPoint.Position.Z)
		npc:SetPrimaryPartCFrame(spawnCFrame)
		task.wait(0.5)

		-- Create prompts
		local buyPrompt = Instance.new("ProximityPrompt")
		buyPrompt.Name = "BuyPrompt"
		buyPrompt.ActionText = "Buy"
		buyPrompt.ObjectText = displayName
		buyPrompt.HoldDuration = 1.0
		buyPrompt.MaxActivationDistance = 10
		buyPrompt.RequiresLineOfSight = false
		buyPrompt.KeyboardKeyCode = Enum.KeyCode.E -- Set E for buy
		buyPrompt.Parent = rootPart

		local stealPrompt = Instance.new("ProximityPrompt")
		stealPrompt.Name = "StealPrompt"
		stealPrompt.ActionText = "Steal"
		stealPrompt.ObjectText = displayName
		stealPrompt.HoldDuration = 3.5
		stealPrompt.MaxActivationDistance = 10
		stealPrompt.RequiresLineOfSight = false
		stealPrompt.Enabled = false
		stealPrompt.Parent = rootPart

		local equipPrompt = Instance.new("ProximityPrompt")
		equipPrompt.Name = "EquipPrompt"
		equipPrompt.ActionText = "Equip"
		equipPrompt.ObjectText = displayName
		equipPrompt.HoldDuration = 0.5
		equipPrompt.MaxActivationDistance = 10
		equipPrompt.KeyboardKeyCode = Enum.KeyCode.E
		equipPrompt.RequiresLineOfSight = false
		equipPrompt.Enabled = false
		equipPrompt.Parent = rootPart

		local unequipPrompt = Instance.new("ProximityPrompt")
		unequipPrompt.Name = "UnequipPrompt"
		unequipPrompt.ActionText = "Unequip"
		unequipPrompt.ObjectText = displayName
		unequipPrompt.HoldDuration = 0
		unequipPrompt.MaxActivationDistance = 10
		unequipPrompt.KeyboardKeyCode = Enum.KeyCode.E
		unequipPrompt.RequiresLineOfSight = false
		unequipPrompt.Enabled = false
		unequipPrompt.Parent = rootPart

		-- Set info attributes for client GUI
		npc:SetAttribute("Info_Name", displayName)
		npc:SetAttribute("Info_Rarity", brainrotType.rarity)
		npc:SetAttribute("Info_Price", npcPrice)
		npc:SetAttribute("Info_Effect", (brainrotType.effect and brainrotType.effect.description) or "")
		npc:SetAttribute("Info_CPS", coinsPerSecond) -- Always use the correct value

		-- Network ownership to server
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part:SetNetworkOwner(nil)
			end
		end

		-- Load behavior script
		require(script.NPCBehavior)(npc, humanoid, rootPart, brainrotType, equipPrompt, unequipPrompt)

		-- Load interaction handlers
		require(script.NPCInteractions)(npc, humanoid, rootPart, buyPrompt, stealPrompt, equipPrompt, unequipPrompt)
	end
end)