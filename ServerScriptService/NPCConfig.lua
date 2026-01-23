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
		spawnChance = 50, -- 70% of spawns
		rarity = "Common",
		walkSpeed = 4,
		followSpeed = 16,
		basePrice = 100,
		coinsPerSecond = 2, -- <<<<<<<< Example: Dummy gives 2 cps
		effect = {
			walkSpeedBonus = 20,
			jumpPowerBonus = 50,
			description = "Faster walkspeed"
		}
	},
	{
		modelName = "TripleT",
		displayName = "Tung Tung Tung Sahur",
		spawnChance = 50, -- 70% of spawns
		rarity = "Legendary",
		walkSpeed = 4,
		followSpeed = 16,
		basePrice = 500,
		coinsPerSecond = 5, -- <<<<<<<< Example: TripleT gives 5 cps
		effect = {
			walkSpeedBonus = 8,
			jumpPowerBonus = 25,
			description = "Higher jump"
		}
	}
}

-- ========================================
-- UNIVERSAL STATUSES
-- ========================================
-- These can apply to ANY brainrot!
NPCConfig.statuses = {
	{
		name = "Diamond",
		displayText = "(DIAMOND)",
		color = Color3.fromRGB(19, 235, 255),
		chance = 5,
		hueShift = true,
		tintColor = Color3.fromRGB(100, 200, 255),
		priceMultiplier = 3.0,
	},
	{
		name = "Gold",
		displayText = "(GOLD)",
		color = Color3.fromRGB(255, 200, 0),
		chance = 10,
		hueShift = true,
		tintColor = Color3.fromRGB(255, 220, 100),
		priceMultiplier = 2.0,
	},
	{
		name = "Shiny",
		displayText = "(SHINY)",
		color = Color3.fromRGB(255, 41, 226),
		chance = 35,
		hueShift = true,
		tintColor = Color3.fromRGB(240, 34, 255),
		priceMultiplier = 1.5,
	},
	{
		name = "None",
		displayText = "",
		color = Color3.fromRGB(85, 255, 127),
		chance = 50,
		hueShift = false,
		priceMultiplier = 1.0,
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

-- Apply visual effects to model based on status
function NPCConfig.applyStatusVisuals(npc, status)
	if not status.hueShift then return end

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
	if status.name == "Shiny" or status.name == "Diamond" then
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "StatusSparkle"
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(status.tintColor)
			sparkle.Size = NumberSequence.new(0.2)
			sparkle.Transparency = NumberSequence.new(0.5)
			sparkle.Lifetime = NumberRange.new(1, 2)
			sparkle.Rate = 15
			sparkle.Speed = NumberRange.new(1, 2)
			sparkle.Parent = rootPart
		end
	end
end

function NPCConfig.calculatePrice(brainrotType, status)
	local basePrice = brainrotType.basePrice or 100
	local multiplier = 1.0

	if status and status.priceMultiplier then
		multiplier = status.priceMultiplier
	end

	return math.floor(basePrice * multiplier)
end

function NPCConfig.getTypeEffect(brainrotType)
	return brainrotType.effect or {walkSpeedBonus = 0, jumpPowerBonus = 0, description = ""}
end

return NPCConfig