-- FruitShopConfig ModuleScript
-- Place this in ServerScriptService

local FruitShopConfig = {}

-- Define your fruits here
-- Add new fruits by adding entries to this table
FruitShopConfig.Fruits = {
	{
		Name = "Apple",
		Description = "A delicious red apple that restores health!",
		Price = 50,
		ToolName = "Apple" -- Must match the Tool name in ServerStorage > Fruits
	},
	{
		Name = "Banana",
		Description = "A yellow banana that gives you speed!",
		Price = 75,
		ToolName = "Banana"
	},
	{
		Name = "Blueberry",
		Description = "A juicy orange packed with vitamin C!",
		Price = 100,
		ToolName = "Blueberry"
	},
	{
		Name = "Rainbow Apple",
		Description = "A massive watermelon that restores all health!",
		Price = 250,
		ToolName = "Rainbow Apple"
	},
	-- Add more fruits here following the same pattern:
	-- {
	-- 	Name = "FruitName",
	-- 	Description = "Description here",
	-- 	Price = 100,
	-- 	ToolName = "ToolName"
	-- },
}

return FruitShopConfig