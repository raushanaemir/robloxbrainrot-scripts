-- FruitShopServer Script
-- Place this in ServerScriptService

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load config
local FruitShopConfig = require(script.Parent:WaitForChild("FruitShopConfig"))

-- Get fruits folder
local fruitsFolder = ServerStorage:WaitForChild("Fruits")

-- Create a folder in ReplicatedStorage for fruit models (so clients can see them)
local fruitModelsFolder = ReplicatedStorage:FindFirstChild("FruitModels")
if not fruitModelsFolder then
	fruitModelsFolder = Instance.new("Folder")
	fruitModelsFolder.Name = "FruitModels"
	fruitModelsFolder.Parent = ReplicatedStorage
end

-- Create Remote Events if they don't exist
local purchaseFruitEvent = ReplicatedStorage:FindFirstChild("PurchaseFruit")
if not purchaseFruitEvent then
	purchaseFruitEvent = Instance.new("RemoteEvent")
	purchaseFruitEvent.Name = "PurchaseFruit"
	purchaseFruitEvent.Parent = ReplicatedStorage
end

local purchaseResultEvent = ReplicatedStorage:FindFirstChild("PurchaseResult")
if not purchaseResultEvent then
	purchaseResultEvent = Instance.new("RemoteEvent")
	purchaseResultEvent.Name = "PurchaseResult"
	purchaseResultEvent.Parent = ReplicatedStorage
end

local getFruitsEvent = ReplicatedStorage:FindFirstChild("GetFruits")
if not getFruitsEvent then
	getFruitsEvent = Instance.new("RemoteFunction")
	getFruitsEvent.Name = "GetFruits"
	getFruitsEvent.Parent = ReplicatedStorage
end

-- Functions
local function getFruitData()
	local fruitsData = {}

	for _, fruitConfig in ipairs(FruitShopConfig.Fruits) do
		local tool = fruitsFolder:FindFirstChild(fruitConfig.ToolName)
		if tool then
			-- Clone tool to ReplicatedStorage so clients can access it for viewports
			local replicatedTool = fruitModelsFolder:FindFirstChild(fruitConfig.ToolName)
			if not replicatedTool then
				replicatedTool = tool:Clone()
				replicatedTool.Name = fruitConfig.ToolName
				replicatedTool.Parent = fruitModelsFolder
			end

			table.insert(fruitsData, {
				Name = fruitConfig.Name,
				Description = fruitConfig.Description,
				Price = fruitConfig.Price,
				ToolName = fruitConfig.ToolName,
				-- Don't send the model object, just the name - client will get it from ReplicatedStorage
			})
		else
			warn("Tool not found in ServerStorage > Fruits: " .. fruitConfig.ToolName)
		end
	end

	return fruitsData
end

local function getPlayerMoney(player)
	-- Replace this with your game's currency system
	-- This example uses leaderstats with a "Cash" value
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			return cash.Value
		end
	end
	return 0
end

local function setPlayerMoney(player, amount)
	-- Replace this with your game's currency system
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = amount
		end
	end
end

local function purchaseFruit(player, fruitName)
	-- Find fruit config
	local fruitConfig = nil
	for _, config in ipairs(FruitShopConfig.Fruits) do
		if config.Name == fruitName then
			fruitConfig = config
			break
		end
	end

	if not fruitConfig then
		warn("Fruit not found in config: " .. fruitName)
		return false
	end

	-- Check if player has enough money
	local playerMoney = getPlayerMoney(player)
	if playerMoney < fruitConfig.Price then
		-- Not enough money
		warn(player.Name .. " doesn't have enough money. Has: " .. playerMoney .. ", Needs: " .. fruitConfig.Price)
		return false
	end

	-- Get the tool
	local tool = fruitsFolder:FindFirstChild(fruitConfig.ToolName)
	if not tool then
		warn("Tool not found: " .. fruitConfig.ToolName)
		return false
	end

	-- Check if it's actually a Tool
	if not tool:IsA("Tool") then
		warn(fruitConfig.ToolName .. " is not a Tool object! It's a " .. tool.ClassName)
		return false
	end

	-- Deduct money
	setPlayerMoney(player, playerMoney - fruitConfig.Price)

	-- Give tool to player's Backpack
	local toolClone = tool:Clone()

	-- Make sure the tool is properly configured
	if toolClone:FindFirstChild("Handle") then
		toolClone.Parent = player.Backpack
		print("? " .. player.Name .. " purchased " .. fruitName .. " for " .. fruitConfig.Price)
		return true
	else
		warn("Tool " .. fruitConfig.ToolName .. " has no Handle! Cannot give to player.")
		-- Refund the money
		setPlayerMoney(player, playerMoney)
		return false
	end
end

-- Remote Event Connections
purchaseFruitEvent.OnServerEvent:Connect(function(player, fruitName)
	local success = purchaseFruit(player, fruitName)
	-- Send result back to client
	purchaseResultEvent:FireClient(player, success, fruitName)
end)

getFruitsEvent.OnServerInvoke = function(player)
	return getFruitData()
end

-- Setup leaderstats for players (OPTIONAL - Remove if you have your own currency system)
Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = 500 -- Starting money
		cash.Parent = leaderstats
	end
end)