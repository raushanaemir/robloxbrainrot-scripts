-- BASE MANAGER SCRIPT
-- Handles assigning players to bases when they join

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.SharedData)

print("=== BASE MANAGER LOADED ===")

-- Configuration
local BASE_NAMES = {"Base1", "Base2", "Base3", "Base4", "Base5", "Base6", "Base7", "Base8"} -- Add more bases here as needed: {"Base1", "Base2", "Base3"}
local MAX_BASE_LEVEL = 3
local FORCEFIELD_DURATION = 30 -- seconds

-- Upgrade costs per level
local UPGRADE_COSTS = {
	[2] = 500,   -- Cost to upgrade from level 1 to level 2
	[3] = 2000,  -- Cost to upgrade from level 2 to level 3
}

-- Track which bases are occupied
local baseOccupancy = {} -- baseOccupancy[baseName] = playerName or nil

-- Track player base levels
local playerBaseLevels = {} -- playerBaseLevels[player] = currentLevel (1, 2, or 3)

-- Track forcefields per base
local baseForcefields = {} -- baseForcefields[base] = forcefield part

-- Track forcefield state per base
local baseForcefieldState = {} -- baseForcefieldState[base] = {enabled = bool, ownerPlayer = player}

-- Track accumulated coins per base
local baseAccumulatedCoins = {} -- baseAccumulatedCoins[base] = number

-- Initialize base occupancy tracking
for _, baseName in ipairs(BASE_NAMES) do
	baseOccupancy[baseName] = nil
end

-- Export accumulated coins tracking for other scripts
Shared.baseAccumulatedCoins = baseAccumulatedCoins

-- Function to add coins to a base's accumulated pool
function Shared.addCoinsToBase(base, amount)
	if not base then return end
	baseAccumulatedCoins[base] = (baseAccumulatedCoins[base] or 0) + amount
end

-- Function to get accumulated coins for a base
function Shared.getBaseAccumulatedCoins(base)
	return baseAccumulatedCoins[base] or 0
end

-- Function to collect all coins from a base
function Shared.collectBaseCoins(base)
	local coins = baseAccumulatedCoins[base] or 0
	baseAccumulatedCoins[base] = 0
	return coins
end

-- Function to completely hide/destroy base level parts (Container and Plot)
local function setBaseLevelVisible(base, level, visible)
	local baseLevel = base:FindFirstChild("BaseLevel" .. level)
	if not baseLevel then return end

	local container = baseLevel:FindFirstChild("Container")
	local plot = baseLevel:FindFirstChild("Plot")

	if container then
		if container:IsA("BasePart") then
			container.Transparency = 1 -- Always fully transparent
			container.CanCollide = false
		elseif container:IsA("Model") then
			for _, part in ipairs(container:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1 -- Always fully transparent
					part.CanCollide = false
				end
			end
		end
	end

	if plot then
		if plot:IsA("BasePart") then
			plot.Transparency = visible and 0 or 1
			plot.CanCollide = visible
		elseif plot:IsA("Model") then
			for _, part in ipairs(plot:GetDescendants()) do
				if part:IsA("BasePart") then
					plot.Transparency = visible and 0 or 1
					part.CanCollide = visible
				end
			end
		end
	end
end

-- Function to create forcefield around level 3 container (kills other players)
local function createForcefield(base, ownerPlayer)
	local baseLevel = base:FindFirstChild("BaseLevel3")
	if not baseLevel then 
		warn("BaseLevel3 not found in " .. base.Name)
		return nil 
	end

	local container = baseLevel:FindFirstChild("Container")
	if not container then 
		warn("Container not found in BaseLevel3")
		return nil 
	end

	-- Calculate container bounds
	local containerCFrame, containerSize
	if container:IsA("BasePart") then
		containerCFrame = container.CFrame
		containerSize = container.Size
	elseif container:IsA("Model") then
		containerCFrame, containerSize = container:GetBoundingBox()
	else
		return nil
	end

	-- Create forcefield part slightly larger than container
	local padding = 1.5 -- studs of padding around container (reduced from 2 to 1.5)
	local forcefield = Instance.new("Part")
	forcefield.Name = "Forcefield_Level3"
	forcefield.Size = containerSize + Vector3.new(padding * 2, padding * 2, padding * 2)
	forcefield.Anchored = true
	forcefield.CanCollide = false -- Don't block, we'll use Touched to kill
	forcefield.Transparency = 0 -- Fully visible
	forcefield.Color = Color3.fromRGB(0, 170, 255) -- Bright blue color
	forcefield.Material = Enum.Material.ForceField
	forcefield.CastShadow = false
	forcefield.Parent = baseLevel

	-- Set forcefield's CFrame to match container's CFrame (rotation and position)
	forcefield.CFrame = containerCFrame

	-- Create timer labels for 4 side surfaces only (not top/bottom)
	local allTimerLabels = {}
	local surfaces = {
		Enum.NormalId.Front,
		Enum.NormalId.Back,
		Enum.NormalId.Left,
		Enum.NormalId.Right,
	}

	for _, face in ipairs(surfaces) do
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "TimerDisplay_" .. face.Name
		surfaceGui.Face = face
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 12 -- Bigger text
		surfaceGui.Parent = forcefield

		local timerLabel = Instance.new("TextLabel")
		timerLabel.Name = "TimerLabel"
		timerLabel.Size = UDim2.new(1, 0, 1, 0)
		timerLabel.Position = UDim2.new(0, 0, 0, 0)
		timerLabel.BackgroundTransparency = 1
		timerLabel.Font = Enum.Font.GothamBlack
		timerLabel.TextScaled = true
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		timerLabel.TextStrokeTransparency = 0
		timerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		timerLabel.Text = tostring(FORCEFIELD_DURATION) .. "s"
		timerLabel.Parent = surfaceGui

		table.insert(allTimerLabels, timerLabel)
	end

	-- Start countdown timer
	task.spawn(function()
		local timeLeft = FORCEFIELD_DURATION
		while timeLeft > 0 and forcefield.Parent do
			-- Update all timer labels
			for _, timerLabel in ipairs(allTimerLabels) do
				timerLabel.Text = tostring(timeLeft) .. "s"

				-- Change color as time runs out
				if timeLeft <= 5 then
					timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
				elseif timeLeft <= 10 then
					timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
				else
					timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end

			task.wait(1)
			timeLeft = timeLeft - 1
		end
	end)

	-- Connect touch event to kill other players
	forcefield.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local player = Players:GetPlayerFromCharacter(character)
			if player and player ~= ownerPlayer then
				-- Kill the player
				humanoid.Health = 0
				print(player.Name .. " was killed by " .. ownerPlayer.Name .. "'s forcefield!")
			end
		end
	end)

	return forcefield
end

-- Function to remove forcefield
local function removeForcefield(base)
	local baseLevel = base:FindFirstChild("BaseLevel3")
	if baseLevel then
		local forcefield = baseLevel:FindFirstChild("Forcefield_Level3")
		if forcefield then
			forcefield:Destroy()
		end
	end

	baseForcefields[base] = nil
end

-- Function to toggle forcefield (works at any level, always surrounds level 3 container)
local function enableForcefield(base, ownerPlayer)
	-- Check if already enabled
	if baseForcefields[base] then
		print("Forcefield already active for " .. ownerPlayer.Name)
		return false
	end

	-- Create forcefield (always around level 3 container regardless of current level)
	local forcefield = createForcefield(base, ownerPlayer)
	if forcefield then
		baseForcefields[base] = forcefield
		baseForcefieldState[base] = {enabled = true, ownerPlayer = ownerPlayer}
		print("Forcefield enabled for " .. ownerPlayer.Name .. " (30 seconds)")

		-- Auto-disable after 30 seconds
		task.delay(FORCEFIELD_DURATION, function()
			if baseForcefields[base] then
				removeForcefield(base)
				baseForcefieldState[base] = {enabled = false, ownerPlayer = ownerPlayer}
				print("Forcefield expired for " .. ownerPlayer.Name)
			end
		end)

		return true
	end

	return false
end

-- Function to setup forcefield button for a base (step on to activate)
local function setupForcefieldButton(base, ownerPlayer)
	local forcefieldButton = base:FindFirstChild("ForcefieldPlate")
	if not forcefieldButton then
		warn("ForcefieldPlate not found in " .. base.Name)
		return
	end

	-- Remove any existing connections (we'll use a tag to track)
	local existingTag = forcefieldButton:FindFirstChild("ForcefieldSetup")
	if existingTag then
		existingTag:Destroy()
	end

	-- Add a tag to track setup
	local setupTag = Instance.new("BoolValue")
	setupTag.Name = "ForcefieldSetup"
	setupTag.Parent = forcefieldButton

	-- Store owner reference
	forcefieldButton:SetAttribute("OwnerUserId", ownerPlayer.UserId)

	-- Handle stepping on the plate
	forcefieldButton.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Only the owner can activate
		if player ~= ownerPlayer then return end

		-- Check if forcefield is on cooldown
		if baseForcefields[base] then return end

		-- Enable forcefield
		enableForcefield(base, ownerPlayer)
	end)
end

-- Function to setup collect plate for a base (step on to collect accumulated coins)
local function setupCollectPlate(base, ownerPlayer)
	local collectPlate = base:FindFirstChild("CollectPlate")
	if not collectPlate then
		warn("CollectPlate not found in " .. base.Name)
		return
	end

	-- Remove any existing connections
	local existingTag = collectPlate:FindFirstChild("CollectSetup")
	if existingTag then
		existingTag:Destroy()
	end

	-- Add a tag to track setup
	local setupTag = Instance.new("BoolValue")
	setupTag.Name = "CollectSetup"
	setupTag.Parent = collectPlate

	-- Store owner reference
	collectPlate:SetAttribute("OwnerUserId", ownerPlayer.UserId)

	-- Remove existing display if any
	local existingDisplay = collectPlate:FindFirstChild("CoinDisplay")
	if existingDisplay then
		existingDisplay:Destroy()
	end

	-- Create SurfaceGui on top surface of the CollectPlate
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "CoinDisplay"
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = collectPlate

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = surfaceGui

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.Size = UDim2.new(1, 0, 1, 0)
	coinLabel.Position = UDim2.new(0, 0, 0, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Font = Enum.Font.GothamBlack
	coinLabel.TextScaled = true
	coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	coinLabel.TextStrokeTransparency = 0
	coinLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	coinLabel.Text = "0 ¢"
	coinLabel.AnchorPoint = Vector2.new(0, 0) -- (default, but explicit for clarity)
	coinLabel.Parent = container

	-- Update coin display periodically
	task.spawn(function()
		while base.Parent and collectPlate.Parent do
			local coins = math.floor(baseAccumulatedCoins[base] or 0)
			coinLabel.Text = coins .. " ¢"

			task.wait(0.25)
		end
	end)

	-- Handle stepping on the plate to collect coins
	collectPlate.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Only the owner can collect
		if player ~= ownerPlayer then return end

		-- Collect coins
		local coins = Shared.collectBaseCoins(base)
		if coins > 0 then
			local CoinSystem = _G.CoinSystem
			if CoinSystem then
				CoinSystem.AddCoins(player, math.floor(coins))
				print(player.Name .. " collected " .. math.floor(coins) .. " coins from base!")
			end
		end
	end)
end

-- Function to initialize base levels (show level 1, hide 2 and 3)
local function initializeBaseLevels(base)
	setBaseLevelVisible(base, 1, true)  -- Show level 1
	setBaseLevelVisible(base, 2, false) -- Hide level 2
	setBaseLevelVisible(base, 3, false) -- Hide level 3
end

-- Function to upgrade player's base to next level (costs coins, deletes old container/plot)
local function upgradePlayerBase(player)
	local base = Shared.playerToBase[player]
	if not base then
		warn("Player " .. player.Name .. " has no base to upgrade")
		return false
	end

	local currentLevel = playerBaseLevels[player] or 1
	local nextLevel = currentLevel + 1

	if nextLevel > MAX_BASE_LEVEL then
		print(player.Name .. " already at max base level (" .. MAX_BASE_LEVEL .. ")")
		return false
	end

	-- Check if player can afford the upgrade
	local upgradeCost = UPGRADE_COSTS[nextLevel] or 0
	local CoinSystem = _G.CoinSystem

	if not CoinSystem then
		warn("CoinSystem not initialized!")
		return false
	end

	if not CoinSystem.CanAfford(player, upgradeCost) then
		print(player.Name .. " cannot afford upgrade to level " .. nextLevel .. " (need " .. upgradeCost .. " coins)")
		return false
	end

	-- Deduct coins
	local success = CoinSystem.RemoveCoins(player, upgradeCost)
	if not success then
		print(player.Name .. " upgrade failed - could not remove coins!")
		return false
	end

	-- Hide/delete the current level's container and plot
	setBaseLevelVisible(base, currentLevel, false)

	-- Show the next level's parts
	setBaseLevelVisible(base, nextLevel, true)

	-- Update player's level
	playerBaseLevels[player] = nextLevel

	-- Update SharedData for other systems to access
	Shared.playerBaseLevels = Shared.playerBaseLevels or {}
	Shared.playerBaseLevels[player] = nextLevel

	print(player.Name .. " upgraded base to level " .. nextLevel .. " for " .. upgradeCost .. " coins")
	return true
end

-- Function to setup upgrade button for a base
local function setupUpgradeButton(base, ownerPlayer)
	local upgradeButton = base:FindFirstChild("UpgradeBaseButton")
	if not upgradeButton then
		warn("UpgradeBaseButton not found in " .. base.Name)
		return
	end

	-- Remove any existing prompt or embedded UI
	local existingPrompt = upgradeButton:FindFirstChild("UpgradePrompt")
	if existingPrompt then
		existingPrompt:Destroy()
	end
	local existingGui = upgradeButton:FindFirstChild("UpgradeSurfaceGui")
	if existingGui then
		existingGui:Destroy()
	end

	-- Create SurfaceGui on top of the button
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "UpgradeSurfaceGui"
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = upgradeButton

	local buttonFrame = Instance.new("Frame")
	buttonFrame.Name = "ButtonFrame"
	buttonFrame.Size = UDim2.new(1, 0, 1, 0)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = surfaceGui

	-- Use a non-interactive label so GUI does NOT block ClickDetector clicks
	local upgradeTextLabel = Instance.new("TextLabel")
	upgradeTextLabel.Name = "UpgradeTextLabel"
	upgradeTextLabel.Size = UDim2.new(0.9, 0, 0.7, 0)
	upgradeTextLabel.Position = UDim2.new(0.05, 0, 0.15, 0)
	upgradeTextLabel.BackgroundTransparency = 1
	upgradeTextLabel.BorderSizePixel = 0
	upgradeTextLabel.Font = Enum.Font.GothamBlack
	upgradeTextLabel.TextScaled = true
	upgradeTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgradeTextLabel.TextStrokeTransparency = 0
	upgradeTextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	upgradeTextLabel.Parent = buttonFrame

	-- Update button text based on current level and cost
	local function updateButtonText()
		local currentLevel = playerBaseLevels[ownerPlayer] or 1
		if currentLevel >= MAX_BASE_LEVEL then
			upgradeTextLabel.Text = "Max Level"
			upgradeTextLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		else
			local nextLevel = currentLevel + 1
			local cost = UPGRADE_COSTS[nextLevel] or 0
			upgradeTextLabel.Text = "Upgrade Base ($" .. cost .. ")"
			upgradeTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	updateButtonText()

	-- Helper to get a BasePart we can attach the ClickDetector to and use for position
	local function getClickablePart(obj)
		if obj:IsA("BasePart") then
			return obj
		end
		if obj:IsA("Model") then
			if obj.PrimaryPart then
				return obj.PrimaryPart
			end
			local firstPart = obj:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				return firstPart
			end
		end
		return nil
	end

	-- Remove any existing ClickDetector to avoid duplicates (search descendants)
		for _, d in ipairs(upgradeButton:GetDescendants()) do
			if d:IsA("ClickDetector") and d.Name == "UpgradeClickDetector" then
				d:Destroy()
			end
		end

		local clickablePart = getClickablePart(upgradeButton)
		if not clickablePart then
			warn("No clickable BasePart found for UpgradeBaseButton in " .. base.Name)
			return
		end

		-- Use a ClickDetector so we know WHICH player clicked the button
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.Name = "UpgradeClickDetector"
		clickDetector.MaxActivationDistance = 10
		clickDetector.Parent = clickablePart

		clickDetector.MouseClick:Connect(function(clickingPlayer)
			-- Only the owner can upgrade
			if clickingPlayer ~= ownerPlayer then return end

			-- Ensure the clicking player is close enough (safety check)
			local character = clickingPlayer.Character
			if not character then return end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end

			local buttonPos = clickablePart.Position
			local dist = (buttonPos - hrp.Position).Magnitude
			if dist > 10 then return end

			local success = upgradePlayerBase(ownerPlayer)
			if success then
				updateButtonText()
			end
		end)
	end

-- Function to create name display above base
local function createBaseNameDisplay(base, playerName)
	-- Find BaseLevel1 inside the base for billboard positioning
	local baseLevel = base:FindFirstChild("BaseLevel1")
	if not baseLevel then
		warn("BaseLevel1 not found in " .. base.Name .. ", falling back to Spawn")
		baseLevel = base:FindFirstChild("Spawn") or base.PrimaryPart or base:FindFirstChildWhichIsA("BasePart")
	end

	if not baseLevel then
		warn("No suitable part found in base for billboard attachment")
		return
	end

	-- Remove existing display if any
	local existingDisplay = base:FindFirstChild("OwnerDisplayPart")
	if existingDisplay then
		existingDisplay:Destroy()
	end

	-- Calculate position for the sign
	local basePosition = Vector3.zero
	local baseHeight = 0
	if baseLevel:IsA("Model") then
		local cf, size = baseLevel:GetBoundingBox()
		basePosition = cf.Position
		baseHeight = size.Y
	elseif baseLevel:IsA("BasePart") then
		basePosition = baseLevel.Position
		baseHeight = baseLevel.Size.Y
	end

	-- Create a small anchored part at the fixed position to hold the billboard
	local anchorPart = Instance.new("Part")
	anchorPart.Name = "OwnerDisplayPart"
	anchorPart.Size = Vector3.new(0.1, 0.1, 0.1)
	anchorPart.Position = basePosition + Vector3.new(0, baseHeight / 2 + 20, 0)
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.Transparency = 1
	anchorPart.CastShadow = false
	anchorPart.Parent = base

	-- Create BillboardGui attached to the anchored part
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OwnerDisplay"
	billboard.Size = UDim2.new(30, 0, 6, 0)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = math.huge
	billboard.Adornee = anchorPart
	billboard.Parent = anchorPart

	-- Create name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Text = playerName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = billboard

	return anchorPart
end

-- Function to remove name display from base
local function removeBaseNameDisplay(base)
	-- Remove the sign part directly from the base
	local signPart = base:FindFirstChild("OwnerDisplayPart")
	if signPart then
		signPart:Destroy()
		return
	end

	local baseLevel = base:FindFirstChild("BaseLevel1")
	if baseLevel then
		local existingDisplay = baseLevel:FindFirstChild("OwnerDisplay")
		if existingDisplay then
			existingDisplay:Destroy()
			return
		end
	end

	local spawnPart = base:FindFirstChild("Spawn") or base.PrimaryPart or base:FindFirstChildWhichIsA("BasePart")
	if spawnPart then
		local existingDisplay = spawnPart:FindFirstChild("OwnerDisplay")
		if existingDisplay then
			existingDisplay:Destroy()
		end
	end
end

-- Function to find an available base
local function findAvailableBase()
	for _, baseName in ipairs(BASE_NAMES) do
		if baseOccupancy[baseName] == nil then
			local base = Workspace:FindFirstChild(baseName)
			if base then
				return baseName, base
			end
		end
	end
	return nil, nil
end

-- Function to clean up forcefield for a base
local function cleanupForcefield(base)
	removeForcefield(base)
	baseForcefieldState[base] = nil
end

-- Function to assign a player to a base
local function assignPlayerToBase(player)
	local baseName, base = findAvailableBase()

	if not base then
		warn("No available base for player: " .. player.Name)
		return nil
	end

	-- Mark base as occupied
	baseOccupancy[baseName] = player.Name

	-- Update SharedData for NPC system
	Shared.playerToBase[player] = base

	-- Initialize player's base level to 1
	playerBaseLevels[player] = 1
	Shared.playerBaseLevels = Shared.playerBaseLevels or {}
	Shared.playerBaseLevels[player] = 1

	-- Initialize accumulated coins
	baseAccumulatedCoins[base] = 0

	-- Initialize base levels (show 1, hide 2 and 3)
	initializeBaseLevels(base)

	-- Setup upgrade button
	setupUpgradeButton(base, player)

	-- Setup forcefield button
	setupForcefieldButton(base, player)

	-- Setup collect plate
	setupCollectPlate(base, player)

	-- Create name display
	createBaseNameDisplay(base, player.Name)

	-- Teleport player to spawn point in their base
	local spawnPart = base:FindFirstChild("Spawn")
	if spawnPart then
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)

		if humanoidRootPart then
			humanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
		end
	end

	print(player.Name .. " assigned to " .. baseName .. " at level 1")
	return base
end

-- Function to release a base when player leaves
local function releasePlayerBase(player)
	for baseName, ownerName in pairs(baseOccupancy) do
		if ownerName == player.Name then
			baseOccupancy[baseName] = nil

			Shared.playerToBase[player] = nil

			playerBaseLevels[player] = nil
			if Shared.playerBaseLevels then
				Shared.playerBaseLevels[player] = nil
			end

			local base = Workspace:FindFirstChild(baseName)
			if base then
				removeBaseNameDisplay(base)

				-- Clean up forcefield
				cleanupForcefield(base)

				-- Reset accumulated coins
				baseAccumulatedCoins[base] = 0

				-- Reset base levels to initial state for next player
				initializeBaseLevels(base)

				-- Remove upgrade prompt
				local upgradeButton = base:FindFirstChild("UpgradeBaseButton")
				if upgradeButton then
					local prompt = upgradeButton:FindFirstChild("UpgradePrompt")
					if prompt then
						prompt:Destroy()
					end

					-- Remove ClickDetector if present (remove anywhere under the button)
					local upgradeButton = base:FindFirstChild("UpgradeBaseButton")
					if upgradeButton then
						for _, d in ipairs(upgradeButton:GetDescendants()) do
							if d:IsA("ClickDetector") and d.Name == "UpgradeClickDetector" then
								d:Destroy()
							end
						end
					end
				end
			end

			print(player.Name .. " released " .. baseName)
			break
		end
	end
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	assignPlayerToBase(player)

	player.CharacterAdded:Connect(function(character)
		local base = Shared.playerToBase[player]
		if base then
			local spawnPart = base:FindFirstChild("Spawn")
			if spawnPart then
				local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
				if humanoidRootPart then
					task.wait(0.1)
					humanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
				end
			end
		end
	end)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	releasePlayerBase(player)
end)

-- Handle players already in game (for studio testing)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		assignPlayerToBase(player)

		player.CharacterAdded:Connect(function(character)
			local base = Shared.playerToBase[player]
			if base then
				local spawnPart = base:FindFirstChild("Spawn")
				if spawnPart then
					local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
					if humanoidRootPart then
						task.wait(0.1)
						humanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
					end
				end
			end
		end)
	end)
end

print("Base Manager initialized with " .. #BASE_NAMES .. " bases")
