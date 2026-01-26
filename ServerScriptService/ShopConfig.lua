-- ========================================
-- SHOP CONFIGURATION MODULE
-- Place this as a ModuleScript in ServerScriptService named "ShopConfig"
-- ========================================

local ShopConfig = {}

-- ========================================
-- SHOP SETTINGS
-- ========================================
ShopConfig.settings = {
	shopRange = 15, -- How close player must be to shop area
	shopAreaName = "ShopArea", -- Name of part in Workspace
}

-- ========================================
-- FOOD ITEMS
-- ========================================
-- Each food item needs a matching Tool in ServerStorage!
ShopConfig.foodItems = {
	{
		name = "Apple",
		displayName = "🍎 Apple",
		modelName = "Apple", -- Tool name in ServerStorage
		price = 50,
		description = "A fresh red apple",
		feedValue = 1, -- How much it feeds creatures
		icon = "rbxassetid://0", -- Optional: Image asset ID
	},
	{
		name = "Burger",
		displayName = "🍔 Burger",
		modelName = "Burger",
		price = 150,
		description = "Juicy burger meal",
		feedValue = 3,
		icon = "rbxassetid://0",
	},
	{
		name = "Pizza",
		displayName = "🍕 Pizza",
		modelName = "Pizza",
		price = 300,
		description = "Delicious pizza slice",
		feedValue = 5,
		icon = "rbxassetid://0",
	},
	{
		name = "Cake",
		displayName = "🎂 Cake",
		modelName = "Cake",
		price = 500,
		description = "Sweet birthday cake",
		feedValue = 10,
		icon = "rbxassetid://0",
	},
	-- Add more food items easily!
	-- {
	--     name = "Steak",
	--     displayName = "🥩 Steak",
	--     modelName = "Steak",
	--     price = 400,
	--     description = "Premium beef steak",
	--     feedValue = 8,
	--     icon = "rbxassetid://0",
	-- },
}

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Get food item by name
function ShopConfig.getFoodByName(name)
	for _, food in ipairs(ShopConfig.foodItems) do
		if food.name == name then
			return food
		end
	end
	return nil
end

-- Get all food items
function ShopConfig.getAllFoods()
	return ShopConfig.foodItems
end

return ShopConfig
