-- =====================================================
-- COIN SYSTEM - SERVER SCRIPT
-- Place in: ServerScriptService as a Script named "CoinSystem"
-- =====================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config
local STARTER_COINS = 500
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local activePlayers = {}

-- Create RemoteEvent
local updateCoins = ReplicatedStorage:FindFirstChild("UpdateCoins")
if not updateCoins then
	updateCoins = Instance.new("RemoteEvent")
	updateCoins.Name = "UpdateCoins"
	updateCoins.Parent = ReplicatedStorage
end

-- Default data
local function getDefaultData()
	return {
		Coins = STARTER_COINS
	}
end

-- Load player data
local function loadData(player)
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and data then
		activePlayers[player.UserId] = data
	else
		activePlayers[player.UserId] = getDefaultData()
	end

	return activePlayers[player.UserId]
end

-- Save player data
local function saveData(player)
	local data = activePlayers[player.UserId]
	if not data then return end

	pcall(function()
		PlayerDataStore:SetAsync("Player_" .. player.UserId, data)
	end)
end

-- Setup leaderboard
local function setupLeaderboard(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	return coins
end

-- Update displays
local function updateDisplays(player, amount)
	-- Update leaderboard
	if player:FindFirstChild("leaderstats") then
		local coins = player.leaderstats:FindFirstChild("Coins")
		if coins then
			coins.Value = amount
		end
	end

	-- Update client UI
	updateCoins:FireClient(player, amount)
end

-- =====================================================
-- PUBLIC API (Use these in your other scripts)
-- =====================================================

local CoinSystem = {}

-- Add coins to player
function CoinSystem.AddCoins(player, amount)
	local data = activePlayers[player.UserId]
	if data then
		data.Coins = data.Coins + amount
		updateDisplays(player, data.Coins)
		return true, data.Coins
	end
	return false, 0
end

-- Remove coins from player
function CoinSystem.RemoveCoins(player, amount)
	local data = activePlayers[player.UserId]
	if data and data.Coins >= amount then
		data.Coins = data.Coins - amount
		updateDisplays(player, data.Coins)
		return true, data.Coins
	end
	return false, data and data.Coins or 0
end

-- Check if player can afford
function CoinSystem.CanAfford(player, amount)
	local data = activePlayers[player.UserId]
	return data and data.Coins >= amount
end

-- Get player's coins
function CoinSystem.GetCoins(player)
	local data = activePlayers[player.UserId]
	return data and data.Coins or 0
end

-- =====================================================
-- PLAYER EVENTS
-- =====================================================

Players.PlayerAdded:Connect(function(player)
	local leaderboardCoins = setupLeaderboard(player)
	local data = loadData(player)
	leaderboardCoins.Value = data.Coins

	task.wait(0.5)
	updateCoins:FireClient(player, data.Coins)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	activePlayers[player.UserId] = nil
end)

-- Auto-save every 5 minutes
task.spawn(function()
	while task.wait(300) do
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

-- Make accessible to other scripts
_G.CoinSystem = CoinSystem

print("? Coin System Initialized!")

-- =====================================================
-- HOW TO USE IN YOUR OTHER SCRIPTS:
-- =====================================================
--[[

-- Give coins when player collects NPC:
_G.CoinSystem.AddCoins(player, 10)

-- Check if player can afford something:
if _G.CoinSystem.CanAfford(player, 500) then
    _G.CoinSystem.RemoveCoins(player, 500)
    -- Give them item
end

-- Get player's current coins:
local coins = _G.CoinSystem.GetCoins(player)

]]