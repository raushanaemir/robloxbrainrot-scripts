-- Advanced Punch Combo System (CLIENT)
-- Place this LocalScript in StarterPlayer > StarterCharacterScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for character to be fully ready
repeat task.wait() until player.Character
local character = player.Character
repeat task.wait() until character:FindFirstChild("Humanoid")
repeat task.wait() until character:FindFirstChild("HumanoidRootPart")

local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

print("Punch System Loaded for " .. player.Name)

-- Configuration
local CONFIG = {
	PUNCH_RANGE = 6,
	BASE_KNOCKBACK = 15,
	COMBO_1_MULTIPLIER = 2.5,
	COMBO_1_LIFT = 10,
	COMBO_2_MULTIPLIER = 6,
	COMBO_2_LIFT = 25,
	COMBO_2_STUN_DURATION = 2,
	COMBO_3_MULTIPLIER = 30,
	COMBO_3_LIFT = 125,
	COMBO_3_STUN_DURATION = 4,
	COMBO_TIMEOUT = 2,
	MAX_BEATS = 15,
	PUNCH_COOLDOWN = 0.3,
	OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
	LUNGE_DISTANCE = 1.5,
}

-- Attacker Animation IDs
local ATTACKER_ANIMATIONS = {
	BASE_1 = "rbxassetid://92004414514618",
	BASE_2 = "rbxassetid://101632022165938",
	BASE_3 = "rbxassetid://117900906363535",
	BASE_4 = "rbxassetid://136420836830222",
	COMBO_1 = "rbxassetid://75406904124138",
	COMBO_2 = "rbxassetid://75406904124138",
	COMBO_3 = "rbxassetid://75406904124138",
}

-- State variables
local currentBeat = 0
local currentTarget = nil
local lastPunchTime = 0
local canPunch = true
local isEquipped = false
local loadedAttackerAnims = {}
local targetBeatTracker = {}
local clientOutlines = {} -- Track client-side outlines

-- Remote events
local function getOrCreateRemote(name, class)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new(class)
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local punchRemote = getOrCreateRemote("PunchRemote", "RemoteEvent")
local comboLabelRemote = getOrCreateRemote("ComboLabelRemote", "RemoteEvent")

-- Load attacker animations
local function loadAnimations()
	local anims = {}
	for key, animId in pairs(ATTACKER_ANIMATIONS) do
		if animId ~= "rbxassetid://0" then
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			anims[key] = humanoid:LoadAnimation(anim)
		end
	end
	return anims
end

-- Get the correct animation for a beat
local function getAnimationForBeat(beat)
	if beat == 5 then
		return loadedAttackerAnims.COMBO_1
	elseif beat == 10 then
		return loadedAttackerAnims.COMBO_2
	elseif beat == 15 then
		return loadedAttackerAnims.COMBO_3
	end

	local cyclePosition = ((beat - 1) % 5) + 1
	if cyclePosition == 5 then return nil end

	if cyclePosition == 1 then return loadedAttackerAnims.BASE_1
	elseif cyclePosition == 2 then return loadedAttackerAnims.BASE_2
	elseif cyclePosition == 3 then return loadedAttackerAnims.BASE_3
	elseif cyclePosition == 4 then return loadedAttackerAnims.BASE_4
	end
end

-- Check if player has an item equipped
local function checkEquippedItem()
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") then return true end
	end
	return false
end

-- CLIENT-SIDE OUTLINE MANAGEMENT
local function updateClientOutline(target, shouldShow)
	if not target then return end

	-- Remove existing outline
	local existingOutline = target:FindFirstChild("PunchOutline_Client")
	if existingOutline then
		existingOutline:Destroy()
	end

	clientOutlines[target] = nil

	-- Add new outline if needed
	if shouldShow then
		local highlight = Instance.new("Highlight")
		highlight.Name = "PunchOutline_Client"
		highlight.FillTransparency = 1
		highlight.OutlineColor = CONFIG.OUTLINE_COLOR
		highlight.OutlineTransparency = 0
		highlight.Parent = target

		clientOutlines[target] = highlight
	end
end

-- Reset combo
local function resetCombo()
	currentBeat = 0
	targetBeatTracker = {}

	-- Remove all client-side outlines
	for target, outline in pairs(clientOutlines) do
		if outline and outline.Parent then
			outline:Destroy()
		end
	end
	clientOutlines = {}

	currentTarget = nil
end

-- Update combo label
local function updateComboLabel(target, comboLevel)
	comboLabelRemote:FireServer(target, comboLevel)
end

-- Lunge toward target
local function lungeTowardTarget(target)
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local direction = (targetRoot.Position - rootPart.Position).Unit
	local newPosition = rootPart.Position + (direction * CONFIG.LUNGE_DISTANCE)
	newPosition = Vector3.new(newPosition.X, rootPart.Position.Y, newPosition.Z)

	rootPart.CFrame = CFrame.new(newPosition, targetRoot.Position)
end

-- Find target in range (ONLY OTHER PLAYERS)
local function findTarget()
	local nearestTarget = nil
	local nearestDistance = CONFIG.PUNCH_RANGE

	for _, otherPlayer in pairs(Players:GetPlayers()) do
		-- ONLY target other players, not yourself
		if otherPlayer ~= player and otherPlayer.Character then
			local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = otherPlayer.Character:FindFirstChild("Humanoid")

			if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
				local distance = (rootPart.Position - otherRoot.Position).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearestTarget = otherPlayer.Character
				end
			end
		end
	end

	return nearestTarget
end

-- Perform punch
local function punch()
	print("Punch attempt!")

	if not canPunch then
		print("On cooldown")
		return
	end

	if isEquipped then
		print("Item equipped - punching disabled")
		return
	end

	-- Find target FIRST - only other players
	local target = findTarget()

	-- If no target in range, don't punch at all
	if not target then
		print("No player target in range - punch cancelled")
		return
	end

	local currentTime = tick()
	if (currentTime - lastPunchTime) > CONFIG.COMBO_TIMEOUT then
		print("Combo timed out!")
		resetCombo()
	end

	currentBeat = currentBeat + 1
	if currentBeat > CONFIG.MAX_BEATS then
		currentBeat = 1
	end

	local animToPlay = getAnimationForBeat(currentBeat)
	if animToPlay then
		animToPlay:Play()
		task.spawn(function()
			task.wait(0.3)
			animToPlay:Stop()
		end)
	end

	local success, err = pcall(function()
		lungeTowardTarget(target)
	end)
	if not success then
		warn("Lunge error:", err)
	end

	print("Target found: " .. target.Name)

	-- Handle target switching
	if currentTarget and currentTarget ~= target then
		-- Remove outline from old target if it was ready for combo
		local oldTargetBeat = targetBeatTracker[currentTarget]
		if oldTargetBeat == 4 or oldTargetBeat == 9 or oldTargetBeat == 14 then
			updateClientOutline(currentTarget, false)
		end
		print("Switching target - maintaining combo!")
	end

	currentTarget = target
	lastPunchTime = currentTime

	if not targetBeatTracker[target] then
		targetBeatTracker[target] = 0
	end

	targetBeatTracker[target] = targetBeatTracker[target] + 1

	local targetBeat = targetBeatTracker[target]
	if targetBeat > CONFIG.MAX_BEATS then
		targetBeatTracker[target] = 1
		targetBeat = 1
	end

	local knockbackForce = CONFIG.BASE_KNOCKBACK
	local liftForce = 0
	local stunDuration = 0
	local isCombo = false

	if targetBeat == 5 then
		knockbackForce = CONFIG.BASE_KNOCKBACK * CONFIG.COMBO_1_MULTIPLIER
		liftForce = CONFIG.COMBO_1_LIFT
		isCombo = true
		print("COMBO 1 FINISHER on " .. target.Name .. "!")
		updateComboLabel(target, 1)
	elseif targetBeat == 10 then
		knockbackForce = CONFIG.BASE_KNOCKBACK * CONFIG.COMBO_2_MULTIPLIER
		liftForce = CONFIG.COMBO_2_LIFT
		stunDuration = CONFIG.COMBO_2_STUN_DURATION
		isCombo = true
		print("COMBO 2 FINISHER on " .. target.Name .. "!")
		updateComboLabel(target, 2)
	elseif targetBeat == 15 then
		knockbackForce = CONFIG.BASE_KNOCKBACK * CONFIG.COMBO_3_MULTIPLIER
		liftForce = CONFIG.COMBO_3_LIFT
		stunDuration = CONFIG.COMBO_3_STUN_DURATION
		isCombo = true
		print("COMBO 3 DEVASTATING OBLITERATION on " .. target.Name .. "!")
		updateComboLabel(target, 3)

		-- Reset beat count after combo 3
		targetBeatTracker[target] = 0
	end

	-- CLIENT-SIDE OUTLINE MANAGEMENT (only visible to attacker)
	if targetBeat == 4 then
		updateClientOutline(target, true)
		print("About to combo on " .. target.Name .. " - outline shown (CLIENT-SIDE ONLY)!")
	elseif targetBeat == 9 then
		updateClientOutline(target, true)
		print("About to SECOND combo on " .. target.Name .. " - outline shown (CLIENT-SIDE ONLY)!")
	elseif targetBeat == 14 then
		updateClientOutline(target, true)
		print("About to DEVASTATING OBLITERATION on " .. target.Name .. " - outline shown (CLIENT-SIDE ONLY)!")
	elseif targetBeat == 5 or targetBeat == 10 or targetBeat == 15 then
		updateClientOutline(target, false)
	end

	-- Send to server
	punchRemote:FireServer(target, currentBeat, knockbackForce, liftForce, stunDuration, targetBeat == 15)

	print("Global Beat: " .. currentBeat .. " | Target Beat on " .. target.Name .. ": " .. targetBeat)

	canPunch = false
	task.wait(CONFIG.PUNCH_COOLDOWN)
	canPunch = true
end

-- Handle input
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		punch()
	end
end

-- Monitor equipped items
local function onChildAdded(child)
	if child:IsA("Tool") then
		isEquipped = true
		resetCombo()
	end
end

local function onChildRemoved(child)
	if child:IsA("Tool") then
		task.wait(0.1)
		isEquipped = checkEquippedItem()
	end
end

-- Auto-reset combo on timeout
RunService.Heartbeat:Connect(function()
	if currentTarget and (tick() - lastPunchTime) > CONFIG.COMBO_TIMEOUT then
		resetCombo()
	end
end)

-- Listen for being hit (resets your combo)
punchRemote.OnClientEvent:Connect(function(attacker)
	if attacker and attacker ~= character then
		resetCombo()
		print("Got hit! Combo reset.")
	end
end)

-- Clean up outlines when characters are removed
local function cleanupOutlines()
	for target, outline in pairs(clientOutlines) do
		if not target or not target.Parent then
			if outline and outline.Parent then
				outline:Destroy()
			end
			clientOutlines[target] = nil
		end
	end
end

RunService.Heartbeat:Connect(cleanupOutlines)

-- Initialize
loadedAttackerAnims = loadAnimations()
isEquipped = checkEquippedItem()

UserInputService.InputBegan:Connect(onInputBegan)
character.ChildAdded:Connect(onChildAdded)
character.ChildRemoved:Connect(onChildRemoved)