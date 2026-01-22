-- NPC SPAWNING & BEHAVIOR SCRIPT (REFACTORED)
-- This Script is mapped under ServerScriptService (folder "Server") via Rojo.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")

local startPoint = Workspace:WaitForChild("StartPoint")
local endPoint = Workspace:WaitForChild("EndPoint")

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

		-- Get random status (universal - works for ANY brainrot!)
		local status = NPCConfig.getRandomStatus()
		local rarityInfo = NPCConfig.getRarityInfo(brainrotType.rarity)

		-- Set attributes (support both lowercase/capital keys from config

		npc:SetAttribute("Status", status.name)
		npc:SetAttribute("NPCType", brainrotType.modelName)
		npc:SetAttribute("DisplayName", brainrotType.displayName or brainrotType.modelName)
		npc:SetAttribute("Rarity", brainrotType.rarity)
		npc:SetAttribute("WalkSpeed", brainrotType.walkSpeed)
		npc:SetAttribute("FollowSpeed", brainrotType.followSpeed)

		-- Create custom name display with BillboardGui
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NameDisplay"
		billboard.Size = UDim2.new(0, 300, 0, 72)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = rootPart

		local container = Instance.new("Frame")
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundTransparency = 1
		container.Parent = billboard

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, 0, 0.28, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, -6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 22
		nameLabel.TextColor3 = rarityInfo.color
		nameLabel.TextStrokeTransparency = 0
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		local displayName = npc:GetAttribute("DisplayName") or "NPC"
		nameLabel.Text =
			rarityInfo.displayText ~= ""
			and (rarityInfo.displayText .. " " .. displayName)
			or displayName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Parent = container

		if status.displayText ~= "" then
			local statusLabel = Instance.new("TextLabel")
			statusLabel.Name = "StatusLabel"
			statusLabel.Size = UDim2.new(1, 0, 0.32, 0)
			statusLabel.Position = UDim2.new(0, 0, 0.3, -4)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Font = Enum.Font.GothamBold
			statusLabel.TextSize = 18
			statusLabel.TextStrokeTransparency = 0
			statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			statusLabel.Text = status.displayText
			statusLabel.TextColor3 = status.color
			statusLabel.TextXAlignment = Enum.TextXAlignment.Center
			statusLabel.Parent = container
		end

		local infoFrame = Instance.new("Frame")
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