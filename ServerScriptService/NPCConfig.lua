-- NPC CONFIGURATION MODULE
-- Place this as a ModuleScript in ServerScriptService named "NPCConfig"

local NPCConfig = {}

-- ========================================
-- RARITY DEFINITIONS
-- ========================================
NPCConfig.rarities = {
	Common = {
		color = Color3.fromRGB(85, 255, 127), -- Green
		displayText = ""
	},
	Rare = {
		color = Color3.fromRGB(55, 108, 255), -- Blue
		displayText = ""
	},
	Epic = {
		color = Color3.fromRGB(147, 43, 238), -- Purple
		displayText = ""
	},
	Legendary = {
		color = Color3.fromRGB(255, 191, 0), -- Yellow/Gold
		displayText = ""
	}
}

-- ========================================
-- BRAINROT TYPES (Character Models)
-- ========================================
-- Add as many brainrot types as you want!
-- Each has a model name, spawn chance, and RARITY
NPCConfig.brainrotTypes = {
	{
		modelName = "Dummy",
		displayName = "Dummy",
		spawnChance = 33, -- 70% of spawns
		rarity = "Common",
		walkSpeed = 4,
		followSpeed = 16,
		basePrice = 100,
		coinsPerSecond = 2, -- <<<<<<<< Example: Dummy gives 2 cps
		effect = {
			walkSpeedBonus = 20,
			jumpPowerBonus = 50,
			description = "Faster walkspeed"
		},
		idleAnimationId = "rbxassetid://0", -- <<<<<< ADD THIS
		walkAnimationId = "rbxassetid://0"  -- <<<<<< ADD THIS
	},
	{
		modelName = "TripleT",
		displayName = "Tung Tung Tung Sahur",
		spawnChance = 33, -- 70% of spawns
		rarity = "Legendary",
		walkSpeed = 4,
		followSpeed = 16,
		basePrice = 500,
		coinsPerSecond = 5, -- <<<<<<<< Example: TripleT gives 5 cps
		effect = {
			walkSpeedBonus = 8,
			jumpPowerBonus = 25,
			description = "Higher jump"
		},
		idleAnimationId = "rbxassetid://0", -- <<<<<< ADD THIS
		walkAnimationId = "rbxassetid://0"  -- <<<<<< ADD THIS
	},
	{
		modelName = "UDinDinDinDun",
		displayName = "UDinDinDinDun",
		spawnChance = 34, -- 70% of spawns
		rarity = "Legendary",
		walkSpeed = 4,
		followSpeed = 16,
		basePrice = 500,
		coinsPerSecond = 5, -- <<<<<<<< Example: TripleT gives 5 cps
		effect = {
			walkSpeedBonus = 8,
			jumpPowerBonus = 25,
			description = "Higher jump"
		},
		idleAnimationId = "rbxassetid://132471698963073", -- <<<<<< ADD THIS
		walkAnimationId = "rbxassetid://132471698963073"  -- <<<<<< ADD THIS
	}
}

-- ========================================
-- UNIVERSAL STATUSES
-- ========================================
-- These can apply to ANY brainrot!
NPCConfig.statuses = {
	{
		name = "Rainbow",
		displayText = "(RAINBOW)",
		color = Color3.fromRGB(255, 255, 255), -- Placeholder, will be animated in UI
		chance = 97,
		hueShift = true,
		tintColor = Color3.fromRGB(255, 255, 255), -- Will be animated in visuals
		priceMultiplier = 4.0,
		cpsMultiplier = 7.0,
		isRainbow = true,
	},
	{
		name = "Diamond",
		displayText = "(DIAMOND)",
		color = Color3.fromRGB(19, 235, 255),
		chance = 1,
		hueShift = true,
		tintColor = Color3.fromRGB(100, 200, 255),
		priceMultiplier = 3.0,
		cpsMultiplier = 5.0,
	},
	{
		name = "Gold",
		displayText = "(GOLD)",
		color = Color3.fromRGB(255, 200, 0),
		chance = 1,
		hueShift = true,
		tintColor = Color3.fromRGB(255, 220, 100),
		priceMultiplier = 2.0,
		cpsMultiplier = 3.0,
	},
	{
		name = "None",
		displayText = "",
		color = Color3.fromRGB(85, 255, 127),
		chance = 1,
		hueShift = false,
		priceMultiplier = 1.0,
		cpsMultiplier = 1.0,
	}
}

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

function NPCConfig.getDisplayName(brainrotType)
	return brainrotType.displayName or brainrotType.modelName or "Unknown"
end

-- Select random brainrot type based on spawn chances
function NPCConfig.getRandomBrainrotType()
	local totalChance = 0
	for _, brainrot in ipairs(NPCConfig.brainrotTypes) do
		totalChance = totalChance + brainrot.spawnChance
	end

	local roll = math.random(1, totalChance)
	local cumulative = 0

	for _, brainrot in ipairs(NPCConfig.brainrotTypes) do
		cumulative = cumulative + brainrot.spawnChance
		if roll <= cumulative then
			return brainrot
		end
	end

	return NPCConfig.brainrotTypes[1] -- Fallback
end

-- Select random status (works for ANY brainrot)
function NPCConfig.getRandomStatus()
	local totalChance = 0
	for _, status in ipairs(NPCConfig.statuses) do
		totalChance = totalChance + status.chance
	end

	local roll = math.random(1, totalChance)
	local cumulative = 0

	for _, status in ipairs(NPCConfig.statuses) do
		cumulative = cumulative + status.chance
		if roll <= cumulative then
			return status
		end
	end

	return NPCConfig.statuses[#NPCConfig.statuses] -- Fallback to "None"
end

-- Get rarity info from rarity name
function NPCConfig.getRarityInfo(rarityName)
	return NPCConfig.rarities[rarityName] or NPCConfig.rarities.Common
end

function NPCConfig.calculatePrice(brainrotType, status)
	local basePrice = brainrotType.basePrice or 100
	local multiplier = 1.0

	if status and status.priceMultiplier then
		multiplier = status.priceMultiplier
	end

	return math.floor(basePrice * multiplier)
end

-- Helper to get coins per second with status multiplier
function NPCConfig.getCoinsPerSecond(brainrotType, status)
	local baseCps = brainrotType.coinsPerSecond or 0
	local cpsMultiplier = 1.0
	if status and status.cpsMultiplier then
		cpsMultiplier = status.cpsMultiplier
	end
	return baseCps * cpsMultiplier
end

-- Apply visual effects to model based on status
function NPCConfig.applyStatusVisuals(npc, status)
	if not status.hueShift then return end

	-- Rainbow effect: animate color
	if status.isRainbow then
		for _, descendant in ipairs(npc:GetDescendants()) do
			if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
				-- Store original color if not already stored
				if not descendant:GetAttribute("OriginalColor") then
					local originalColor = descendant.Color
					descendant:SetAttribute("OriginalColor", 
						originalColor.R .. "," .. originalColor.G .. "," .. originalColor.B)
				end
				-- Animate color using a coroutine (HSV rainbow)
				coroutine.wrap(function(part)
					while npc.Parent do
						local t = tick()
						local hue = (t * 0.5) % 1
						part.Color = Color3.fromHSV(hue, 1, 1)
						wait(0.05)
					end
				end)(descendant)
			end
		end
		-- Optional: Add sparkle effect for special statuses
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		if rootPart and not rootPart:FindFirstChild("StatusSparkle") then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "StatusSparkle"
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255,255,0)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0,255,0)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0,255,255)),
				ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0,0,255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,255)),
			}
			-- Make particles much more obvious
			sparkle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 2.5)})
			sparkle.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6)})
			sparkle.Lifetime = NumberRange.new(2, 3.5)
			sparkle.Rate = 20
			sparkle.Speed = NumberRange.new(2, 4)
			sparkle.LightEmission = 1
			sparkle.LightInfluence = 0
			sparkle.ZOffset = 2
			sparkle.Rotation = NumberRange.new(0, 360)
			sparkle.RotSpeed = NumberRange.new(-180, 180)
			sparkle.Parent = rootPart
		end
		return
	end

	-- Tint all parts of the model
	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
			-- Store original color if not already stored
			if not descendant:GetAttribute("OriginalColor") then
				local originalColor = descendant.Color
				descendant:SetAttribute("OriginalColor", 
					originalColor.R .. "," .. originalColor.G .. "," .. originalColor.B)
			end

			-- Directly set the color (NO hue shifting)
			descendant.Color = status.tintColor
		end
	end

	-- Optional: Add sparkle effect for special statuses
	if status.name == "Diamond" or status.name == "Rainbow" then
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		if rootPart and not rootPart:FindFirstChild("StatusSparkle") then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "StatusSparkle"
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			if status.isRainbow then
				sparkle.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
					ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255,255,0)),
					ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0,255,0)),
					ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0,255,255)),
					ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0,0,255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,255)),
				}
			else
				sparkle.Color = ColorSequence.new(status.tintColor)
			end
			-- Make particles much more obvious
			sparkle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 2.5)})
			sparkle.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6)})
			sparkle.Lifetime = NumberRange.new(2, 3.5)
			sparkle.Rate = 20
			sparkle.Speed = NumberRange.new(2, 4)
			sparkle.LightEmission = 1
			sparkle.LightInfluence = 0
			sparkle.ZOffset = 2
			sparkle.Rotation = NumberRange.new(0, 360)
			sparkle.RotSpeed = NumberRange.new(-180, 180)
			sparkle.Parent = rootPart
		end
	end
end

function NPCConfig.getTypeEffect(brainrotType)
	return brainrotType.effect or {walkSpeedBonus = 0, jumpPowerBonus = 0, description = ""}
end

return NPCConfig