-- ========================================
-- SHOP UI CLIENT - USES YOUR ROBLOX GUI
-- Place in: StarterGui > ShopGui (ScreenGui) > This LocalScript
-- ========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for your GUI (must be in StarterGui)
local shopGui = script.Parent
if not shopGui or not shopGui:IsA("ScreenGui") then
	error("ShopUI script must be inside a ScreenGui in StarterGui!")
end

-- Get your GUI elements (customize these names to match YOUR gui)
local mainFrame = shopGui:WaitForChild("MainFrame") -- Your main shop frame
local itemsContainer = mainFrame:WaitForChild("ItemsContainer") -- ScrollingFrame with UIGridLayout
local templateCard = mainFrame:WaitForChild("TemplateCard") -- Template item card (will be cloned)
local closeButton = mainFrame:WaitForChild("CloseButton", 5) -- Optional close button

-- Get remote events
local buyFoodEvent = ReplicatedStorage:WaitForChild("BuyFood")
local getShopDataFunction = ReplicatedStorage:WaitForChild("GetShopData")

-- Wait for shop area part
local shopArea = workspace:WaitForChild("ShopArea")

-- ========================================
-- SETTINGS (Easy to adjust!)
-- ========================================
local SETTINGS = {
	autoRotateModels = true, -- Auto-rotate viewport models
	rotationSpeed = 30, -- Degrees per second
}

-- Track if player is on shop area
local isOnShopArea = false

-- ========================================
-- HELPER: Find child by class (flexible)
-- ========================================
local function findChildOfClass(parent, className)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

-- ========================================
-- CREATE VIEWPORT MODEL
-- ========================================
local function createViewportModel(parent, modelName)
	local viewportFrame = findChildOfClass(parent, "ViewportFrame")
	if not viewportFrame then
		warn("No ViewportFrame found in template card")
		return
	end

	-- Create camera
	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	-- Try to load model from ReplicatedStorage or ServerStorage
	local modelSource = ReplicatedStorage:FindFirstChild(modelName) or game:GetService("ServerStorage"):FindFirstChild(modelName)

	if not modelSource then
		warn("Model not found: " .. modelName)
		return
	end

	-- Clone the model
	local model
	if modelSource:IsA("Tool") then
		local handle = modelSource:FindFirstChild("Handle")
		if handle then
			model = handle:Clone()
		end
	elseif modelSource:IsA("Model") then
		model = modelSource:Clone()
	elseif modelSource:IsA("Part") or modelSource:IsA("MeshPart") then
		model = modelSource:Clone()
	end

	if not model then
		warn("Could not extract model from: " .. modelName)
		return
	end

	model.Parent = viewportFrame

	-- Calculate camera position
	local size
	if model:IsA("Model") then
		size = model:GetExtentsSize()
		local cf, s = model:GetBoundingBox()
		size = s
	else
		size = model.Size
	end

	local maxDim = math.max(size.X, size.Y, size.Z)
	local distance = maxDim * 2.5

	local modelPos = model:IsA("Model") and model:GetPivot().Position or model.Position
	camera.CFrame = CFrame.new(modelPos + Vector3.new(distance, distance * 0.5, distance), modelPos)

	-- Auto-rotate
	if SETTINGS.autoRotateModels then
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			if not model or not model.Parent then
				connection:Disconnect()
				return
			end

			if model:IsA("Model") then
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(SETTINGS.rotationSpeed) * dt, 0))
			else
				model.CFrame = model.CFrame * CFrame.Angles(0, math.rad(SETTINGS.rotationSpeed) * dt, 0)
			end
		end)
	end
end

-- ========================================
-- CREATE FOOD CARD FROM TEMPLATE
-- ========================================
local function createFoodCard(foodData)
	local card = templateCard:Clone()
	card.Name = foodData.name
	card.Visible = true

	-- Update text labels (finds TextLabels automatically)
	for _, child in ipairs(card:GetDescendants()) do
		if child:IsA("TextLabel") then
			if child.Name == "NameLabel" or child.Name == "ItemName" then
				child.Text = foodData.displayName
			elseif child.Name == "PriceLabel" or child.Name == "Price" then
				child.Text = "💰 " .. foodData.price
			elseif child.Name == "Description" or child.Name == "DescLabel" then
				child.Text = foodData.description or ""
			end
		end
	end

	-- Setup viewport if exists
	createViewportModel(card, foodData.modelName)

	-- Find and setup buy button
	local buyButton = findChildOfClass(card, "TextButton")
	if buyButton then
		buyButton.MouseButton1Click:Connect(function()
			-- Check if player can afford
			if _G.CoinSystem then
				local coins = _G.CoinSystem.GetCoins(player)
				if coins and coins >= foodData.price then
					buyFoodEvent:FireServer(foodData.name)
					print("Buying: " .. foodData.displayName)
				else
					-- Visual feedback
					local originalText = buyButton.Text
					buyButton.Text = "NOT ENOUGH COINS!"
					task.wait(1)
					buyButton.Text = originalText
				end
			else
				-- No coin system, just buy
				buyFoodEvent:FireServer(foodData.name)
			end
		end)
	end

	return card
end

-- ========================================
-- POPULATE SHOP
-- ========================================
local function populateShop()
	-- Clear existing items (except template)
	for _, child in ipairs(itemsContainer:GetChildren()) do
		if child ~= templateCard and (child:IsA("Frame") or child:IsA("ImageButton")) then
			child:Destroy()
		end
	end

	-- Get shop data from server
	local success, shopData = pcall(function()
		return getShopDataFunction:InvokeServer()
	end)

	if not success then
		warn("Failed to get shop data: " .. tostring(shopData))
		return
	end

	if shopData then
		for i, foodData in ipairs(shopData) do
			local card = createFoodCard(foodData)
			card.LayoutOrder = i
			card.Parent = itemsContainer
		end

		-- Update canvas size if ScrollingFrame
		if itemsContainer:IsA("ScrollingFrame") then
			task.wait(0.1)
			local layout = findChildOfClass(itemsContainer, "UIGridLayout") or findChildOfClass(itemsContainer, "UIListLayout")
			if layout then
				itemsContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
			end
		end
	end
end

-- ========================================
-- SHOP AREA TOUCH DETECTION
-- ========================================
local function openShop()
	if not isOnShopArea then
		isOnShopArea = true
		mainFrame.Visible = true
		populateShop()
		print("Shop opened!")
	end
end

local function closeShop()
	if isOnShopArea then
		isOnShopArea = false
		mainFrame.Visible = false
		print("Shop closed!")
	end
end

-- Helper to check if a part belongs to the local player's character
local function isLocalPlayerPart(part)
	local character = player.Character
	if not character then return false end
	return part:IsDescendantOf(character)
end

-- Connect touch events
shopArea.Touched:Connect(function(hit)
	if isLocalPlayerPart(hit) then
		openShop()
	end
end)

shopArea.TouchEnded:Connect(function(hit)
	if isLocalPlayerPart(hit) then
		-- Small delay to prevent flickering when multiple parts leave
		task.wait(0.1)
		
		-- Double-check player is actually off the shop area
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Check if any part of the character is still touching
				local partsInArea = workspace:GetPartsInPart(shopArea)
				for _, part in ipairs(partsInArea) do
					if part:IsDescendantOf(character) then
						return -- Still on shop area, don't close
					end
				end
			end
		end
		
		closeShop()
	end
end)

-- Close button (optional)
if closeButton then
	closeButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
	end)
end

-- Hide template card and main frame initially
templateCard.Visible = false
mainFrame.Visible = false

print("✅ Shop UI Loaded (Touch-based detection)")
