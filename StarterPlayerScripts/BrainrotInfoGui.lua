-- Brainrot Info GUI LocalScript

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotInfoGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 400, 0, 310) -- Increased height for stacked layout
frame.Position = UDim2.new(0.5, -200, 0.5, -155)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local CLOSE_DISTANCE = 20 -- studs

-- X Button to close
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.Position = UDim2.new(1, -36, 0, 4)
closeButton.BackgroundTransparency = 0.2
closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 22
closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
closeButton.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Brainrot Info"
title.Parent = frame

-- Info labels (bolder fonts)
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -20, 0, 28) -- Reduced from 36
nameLabel.Position = UDim2.new(0, 10, 0, 44)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 18 -- Reduced from 22
nameLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextWrapped = true
nameLabel.Text = "Name: "
nameLabel.Parent = frame

local rarityLabel = Instance.new("TextLabel")
rarityLabel.Size = UDim2.new(1, -20, 0, 28)
rarityLabel.Position = UDim2.new(0, 10, 0, 72)
rarityLabel.BackgroundTransparency = 1
rarityLabel.Font = Enum.Font.GothamBlack
rarityLabel.TextSize = 18
rarityLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
rarityLabel.TextWrapped = true
rarityLabel.Text = "Rarity: "
rarityLabel.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 28)
statusLabel.Position = UDim2.new(0, 10, 0, 100)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 18
statusLabel.TextColor3 = Color3.fromRGB(19, 235, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Text = "Status: "
statusLabel.Parent = frame

-- Price label (now stacked vertically)
local priceLabel = Instance.new("TextLabel")
priceLabel.Size = UDim2.new(1, -20, 0, 28)
priceLabel.Position = UDim2.new(0, 10, 0, 128)
priceLabel.BackgroundTransparency = 1
priceLabel.Font = Enum.Font.GothamBold
priceLabel.TextSize = 18
priceLabel.TextColor3 = Color3.fromRGB(255, 255, 180)
priceLabel.TextXAlignment = Enum.TextXAlignment.Left
priceLabel.Text = "Price: "
priceLabel.Parent = frame

-- CPS label (below price, same font size)
local cpsLabel = Instance.new("TextLabel")
cpsLabel.Size = UDim2.new(1, -20, 0, 28)
cpsLabel.Position = UDim2.new(0, 10, 0, 156)
cpsLabel.BackgroundTransparency = 1
cpsLabel.Font = Enum.Font.GothamBold
cpsLabel.TextSize = 18
cpsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
cpsLabel.TextXAlignment = Enum.TextXAlignment.Left
cpsLabel.Text = "Coins/sec: "
cpsLabel.Parent = frame

local effectLabel = Instance.new("TextLabel")
effectLabel.Size = UDim2.new(1, -20, 0, 56) -- Increased height for wrapping
effectLabel.Position = UDim2.new(0, 10, 0, 184)
effectLabel.BackgroundTransparency = 1
effectLabel.Font = Enum.Font.GothamBold
effectLabel.TextSize = 14 -- Reduced from 20
effectLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
effectLabel.TextXAlignment = Enum.TextXAlignment.Left
effectLabel.TextYAlignment = Enum.TextYAlignment.Top
effectLabel.TextWrapped = true
effectLabel.Text = "Effect: "
effectLabel.Parent = frame

-- Store current NPC for proximity check
local currentTargetNPC = nil

-- Helper to close GUI
local function closeGui()
	frame.Visible = false
	currentTargetNPC = nil
end

closeButton.MouseButton1Click:Connect(closeGui)

-- Helper: get rarity color from rarity string
local function getRarityColor(rarity)
	if rarity == "Common" then
		return Color3.fromRGB(85, 255, 127)
	elseif rarity == "Rare" then
		return Color3.fromRGB(55, 108, 255)
	elseif rarity == "Epic" then
		return Color3.fromRGB(147, 43, 238)
	elseif rarity == "Legendary" then
		return Color3.fromRGB(255, 191, 0)
	else
		return Color3.fromRGB(200, 200, 255)
	end
end

-- Helper: get status color from status string
local function getStatusColor(status)
	if status == "Diamond" then
		return Color3.fromRGB(19, 235, 255)
	elseif status == "Gold" then
		return Color3.fromRGB(255, 200, 0)
	elseif status == "Shiny" then
		return Color3.fromRGB(255, 41, 226)
	else
		return Color3.fromRGB(200, 255, 200)
	end
end

-- Function to display NPC info
local function displayNPCInfo(npc)
	if not npc or not npc.Parent then return end
	
	-- Get info attributes with multiple fallbacks
	local infoName = npc:GetAttribute("Info_Name") 
		or npc:GetAttribute("DisplayName") 
		or npc:GetAttribute("NPCType")
		or "Unknown"
	local infoRarity = npc:GetAttribute("Info_Rarity") 
		or npc:GetAttribute("Rarity") 
		or "Unknown"
	local infoPrice = npc:GetAttribute("Info_Price") 
		or npc:GetAttribute("Price") 
		or "???"
	local infoEffect = npc:GetAttribute("Info_Effect") 
		or npc:GetAttribute("Effect_Description") 
		or "None"
	local infoStatus = npc:GetAttribute("Status") or "None"
	local infoCPS = npc:GetAttribute("Info_CPS") or 0

	nameLabel.Text = "Name: " .. tostring(infoName)
	rarityLabel.Text = "Rarity: " .. tostring(infoRarity)
	rarityLabel.TextColor3 = getRarityColor(infoRarity)
	statusLabel.Text = "Status: " .. tostring(infoStatus)
	statusLabel.TextColor3 = getStatusColor(infoStatus)
	priceLabel.Text = "Price: $" .. tostring(infoPrice)
	cpsLabel.Text = "Coins/sec: " .. tostring(infoCPS)
	effectLabel.Text = "Effect: " .. tostring(infoEffect)

	currentTargetNPC = npc
	frame.Visible = true
	
	print("Displaying info for: " .. tostring(infoName))
end

-- Proximity check for auto-close
RunService.RenderStepped:Connect(function()
	if frame.Visible and currentTargetNPC and currentTargetNPC.Parent then
		local primary = currentTargetNPC.PrimaryPart or currentTargetNPC:FindFirstChild("HumanoidRootPart") or currentTargetNPC:FindFirstChildWhichIsA("BasePart")
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") and primary then
			local dist = (char.HumanoidRootPart.Position - primary.Position).Magnitude
			if dist > CLOSE_DISTANCE then
				closeGui()
			end
		end
	end
end)

-- Listen for display requests from InteractMenu via BindableEvent
local function setupDisplayEvent()
	local displayEvent = ReplicatedStorage:FindFirstChild("DisplayBrainrotInfo")
	if not displayEvent then
		displayEvent = Instance.new("BindableEvent")
		displayEvent.Name = "DisplayBrainrotInfo"
		displayEvent.Parent = ReplicatedStorage
	end
	
	displayEvent.Event:Connect(function(npc)
		if npc then
			displayNPCInfo(npc)
		end
	end)
end

setupDisplayEvent()

-- Hide GUI on Escape press (removed Q key info display functionality)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and frame.Visible and input.KeyCode == Enum.KeyCode.Escape then
		closeGui()
	end
end)

print("Brainrot Info GUI Loaded!")
