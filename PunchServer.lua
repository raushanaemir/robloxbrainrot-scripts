-- Punch System Server Handler
-- Place this Script in ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Configuration
local CONFIG = {
	COMBO_LABEL_DURATION = 2,
	COMBO_LABEL_COLOR_1 = Color3.fromRGB(255, 215, 0),
	COMBO_LABEL_COLOR_2 = Color3.fromRGB(255, 100, 100),
	COMBO_LABEL_COLOR_3 = Color3.fromRGB(255, 0, 0),
	MAX_PUNCH_RANGE = 8, -- Server-side validation range
}

-- Get or create remote events
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

-- Create combo label above character
local function createComboLabel(character, comboLevel)
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local existingLabel = head:FindFirstChild("ComboLabel")
	if existingLabel then
		existingLabel:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ComboLabel"
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(2, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	if comboLevel == 1 then
		label.Text = "*"
		label.TextColor3 = CONFIG.COMBO_LABEL_COLOR_1
	elseif comboLevel == 2 then
		label.Text = "*"
		label.TextColor3 = CONFIG.COMBO_LABEL_COLOR_2
	elseif comboLevel == 3 then
		label.Text = "*"
		label.TextColor3 = CONFIG.COMBO_LABEL_COLOR_3
		billboard.Size = UDim2.new(6, 0, 3, 0)
	end

	task.spawn(function()
		local startTime = tick()
		local duration = CONFIG.COMBO_LABEL_DURATION

		while tick() - startTime < duration do
			if not billboard or not billboard.Parent then break end

			local elapsed = tick() - startTime
			local progress = elapsed / duration

			label.TextTransparency = progress
			label.TextStrokeTransparency = 0.5 + (progress * 0.5)
			billboard.StudsOffset = Vector3.new(2, 2 + (progress * 2), 0)

			task.wait()
		end

		if billboard then
			billboard:Destroy()
		end
	end)
end

-- Apply knockback to target
local function applyKnockback(attacker, target, knockbackForce, liftForce, isUltimateCombo)
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = target:FindFirstChild("Humanoid")

	if not targetRoot or not attackerRoot or not targetHumanoid then return end

	local knockbackDirection = (targetRoot.Position - attackerRoot.Position).Unit

	targetHumanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local spinMultiplier = 1
	local durationMultiplier = 1

	if isUltimateCombo then
		if knockbackForce > 200 then
			spinMultiplier = 5
			durationMultiplier = 3
		else
			spinMultiplier = 2.5
			durationMultiplier = 1.5
		end
	end

	targetRoot.AssemblyLinearVelocity = knockbackDirection * knockbackForce + Vector3.new(0, liftForce, 0)
	targetRoot.AssemblyAngularVelocity = Vector3.new(
		math.random(-2, 2) * spinMultiplier,
		math.random(-3, 3) * spinMultiplier,
		math.random(-2, 2) * spinMultiplier
	)

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	bodyVelocity.Velocity = knockbackDirection * knockbackForce + Vector3.new(0, liftForce, 0)
	bodyVelocity.Parent = targetRoot

	local bodyAngular = Instance.new("BodyAngularVelocity")
	bodyAngular.MaxTorque = Vector3.new(4e4, 4e4, 4e4)
	bodyAngular.AngularVelocity = Vector3.new(
		math.random(-5, 5) * spinMultiplier,
		math.random(-8, 8) * spinMultiplier,
		math.random(-5, 5) * spinMultiplier
	)
	bodyAngular.Parent = targetRoot

	task.spawn(function()
		local startTime = tick()
		local duration = 0.25 * durationMultiplier

		while tick() - startTime < duration and bodyVelocity.Parent do
			local progress = (tick() - startTime) / duration
			local easeOut = 1 - progress

			bodyVelocity.Velocity = (knockbackDirection * knockbackForce + Vector3.new(0, liftForce, 0)) * easeOut
			bodyAngular.AngularVelocity = bodyAngular.AngularVelocity * 0.95

			task.wait()
		end

		if bodyVelocity then bodyVelocity:Destroy() end
		if bodyAngular then bodyAngular:Destroy() end

		if isUltimateCombo then
			task.wait(0.5)
		end

		if targetHumanoid and targetHumanoid.Health > 0 then
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = {target}

			local maxWaitTime = 2
			local waitStart = tick()

			while tick() - waitStart < maxWaitTime do
				local ray = workspace:Raycast(targetRoot.Position, Vector3.new(0, -5, 0), rayParams)
				if ray and ray.Distance < 4 then
					break
				end
				task.wait(0.1)
			end

			targetHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Stun target
local function stunTarget(target, duration)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	task.wait(duration)

	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
end

-- Validate that target is another player's character
local function isValidPlayerTarget(attacker, target)
	if not attacker or not target then return false end

	-- Get players from characters
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	local targetPlayer = Players:GetPlayerFromCharacter(target)

	-- Must be two different players
	if not attackerPlayer or not targetPlayer then return false end
	if attackerPlayer == targetPlayer then return false end

	-- Target must be alive
	local targetHumanoid = target:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false end

	return true
end

-- Handle punch from client
punchRemote.OnServerEvent:Connect(function(player, target, beat, knockbackForce, liftForce, stunDuration, isCombo3)
	if not player.Character or not target then 
		warn("Invalid punch: missing character or target")
		return 
	end

	-- Validate that target is another player
	if not isValidPlayerTarget(player.Character, target) then
		warn("Invalid punch: target is not another player or is same player")
		return
	end

	local attackerRoot = player.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")

	if not attackerRoot or not targetRoot then 
		warn("Invalid punch: missing roots")
		return 
	end

	-- Server-side distance validation
	local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
	if distance > CONFIG.MAX_PUNCH_RANGE then 
		warn("Invalid punch: too far away (" .. distance .. " studs)")
		return 
	end

	-- Apply effects
	applyKnockback(player.Character, target, knockbackForce, liftForce, stunDuration > 0)

	if stunDuration > 0 then
		task.spawn(function()
			stunTarget(target, stunDuration)
		end)
	end

	-- Notify the target that they were hit (resets their combo)
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		punchRemote:FireClient(targetPlayer, player.Character)
	end

	print(player.Name .. " punched " .. targetPlayer.Name .. " (Beat: " .. beat .. ")")
end)

-- Handle combo label requests
comboLabelRemote.OnServerEvent:Connect(function(player, target, comboLevel)
	if not target then return end

	-- Validate that target is another player
	if not isValidPlayerTarget(player.Character, target) then
		return
	end

	createComboLabel(target, comboLevel)

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	print(player.Name .. " hit COMBO " .. comboLevel .. " on " .. (targetPlayer and targetPlayer.Name or "unknown"))
end)

print("Punch Server System Loaded")