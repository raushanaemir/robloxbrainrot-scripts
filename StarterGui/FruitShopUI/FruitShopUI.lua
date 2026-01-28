-- FruitShopUI LocalScript
-- Place this in StarterGui > FruitShopUI > FruitShopUI (LocalScript, not Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- UI Elements
local screenGui = script.Parent
local mainFrame = screenGui:WaitForChild("MainFrame")
local header = mainFrame:WaitForChild("Header")
local closeButton = header:WaitForChild("CloseButton")
local itemContainer = mainFrame:WaitForChild("ItemContainer")
local itemTemplate = itemContainer:WaitForChild("ItemTemplate")

-- Configuration
local INTERACTION_RANGE = 10 -- Distance to interact with shop
local shopPart = workspace:WaitForChild("FruitShop") -- Make sure you have a part named "FruitShop" in workspace

-- Remote Events
local purchaseFruitEvent = ReplicatedStorage:WaitForChild("PurchaseFruit")
local purchaseResultEvent = ReplicatedStorage:WaitForChild("PurchaseResult")
local getFruitsEvent = ReplicatedStorage:WaitForChild("GetFruits")

-- Fruit Models Folder (where cloned tools are stored for viewports)
-- Wait for it to be created by the server
local fruitModelsFolder
repeat
	fruitModelsFolder = ReplicatedStorage:FindFirstChild("FruitModels")
	if not fruitModelsFolder then
		wait(0.1)
	end
until fruitModelsFolder

print("FruitModels folder found!")

-- Variables
local isInRange = false
local guiOpen = false
local shopPopulated = false -- Track if shop has been populated
itemTemplate.Visible = false
mainFrame.Visible = false

-- Create prompt text
local promptGui = Instance.new("BillboardGui")
promptGui.Name = "ShopPrompt"
promptGui.Size = UDim2.new(0, 200, 0, 50)
promptGui.StudsOffset = Vector3.new(0, 3, 0)
promptGui.AlwaysOnTop = true
promptGui.Parent = shopPart

local promptText = Instance.new("TextLabel")
promptText.Size = UDim2.new(1, 0, 1, 0)
promptText.BackgroundTransparency = 1
promptText.Text = "Press E to open shop"
promptText.TextColor3 = Color3.new(1, 1, 1)
promptText.TextScaled = true
promptText.Font = Enum.Font.FredokaOne
promptText.Parent = promptGui
promptGui.Enabled = false

-- Functions
local function clearItems()
	for _, child in pairs(itemContainer:GetChildren()) do
		if child:IsA("Frame") and child ~= itemTemplate then
			child:Destroy()
		end
	end
end

local function setupViewport(viewportFrame, toolModel)
	-- Clear existing content
	viewportFrame:ClearAllChildren()

	-- Clone the tool for the viewport
	local clonedTool = toolModel:Clone()

	-- Make sure all parts are visible and set to proper properties for viewport
	for _, descendant in pairs(clonedTool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	clonedTool.Parent = viewportFrame

	-- Create camera for viewport
	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	-- Position camera to view the tool
	local toolCamera = toolModel:FindFirstChild("Camera")
	if toolCamera and toolCamera:IsA("Camera") then
		-- Use the custom camera if it exists
		camera.CFrame = toolCamera.CFrame
		print("Using custom camera for: " .. toolModel.Name)
	else
		-- Auto-calculate camera position based on the Handle
		local handle = clonedTool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			-- Calculate bounding box of the entire tool
			local cf, size = clonedTool:GetBoundingBox()

			-- Position camera to view the entire model
			local maxSize = math.max(size.X, size.Y, size.Z)
			local distance = maxSize * 2.5

			-- Position camera at an angle
			local cameraPosition = cf.Position + Vector3.new(distance * 0.7, distance * 0.5, distance * 0.7)
			camera.CFrame = CFrame.new(cameraPosition, cf.Position)

			print("Auto-positioned camera for: " .. toolModel.Name)
		else
			warn("No Handle found in tool: " .. toolModel.Name)
		end
	end

	-- Set viewport properties for better rendering
	viewportFrame.LightingType = Enum.LightingType.Ambient
	viewportFrame.Ambient = Color3.fromRGB(255, 255, 255)
end

local function populateShop(fruitsData)
	clearItems()

	for _, fruitData in ipairs(fruitsData) do
		local newItem = itemTemplate:Clone()
		newItem.Name = fruitData.Name
		newItem.Visible = true
		newItem.Parent = itemContainer

		-- Set fruit info
		newItem:WaitForChild("FruitName").Text = fruitData.Name
		newItem:WaitForChild("Description").Text = fruitData.Description
		newItem.PurchaseButton:WaitForChild("Price").Text = "?? " .. fruitData.Price

		-- Setup viewport (get the model from ReplicatedStorage)
		local viewportFrame = newItem:FindFirstChild("ViewportFrame")
		if viewportFrame then
			local toolModel = fruitModelsFolder:FindFirstChild(fruitData.ToolName)
			if toolModel then
				setupViewport(viewportFrame, toolModel)
			else
				warn("Tool model not found in ReplicatedStorage: " .. fruitData.ToolName)
			end
		end

		-- Purchase button functionality
		newItem.PurchaseButton.MouseButton1Click:Connect(function()
			purchaseFruitEvent:FireServer(fruitData.Name)
		end)
	end
end

local function openShop()
	if not guiOpen then
		guiOpen = true

		-- Request fruit data from server only on first open
		if not shopPopulated then
			local fruitsData = getFruitsEvent:InvokeServer()
			if fruitsData then
				populateShop(fruitsData)
				shopPopulated = true
			end
		end

		-- Reset position before showing
		mainFrame.Position = UDim2.new(0.5, 0, -0.5, 0)
		mainFrame.Visible = true

		-- Tween in
		mainFrame:TweenPosition(
			UDim2.new(0.5, 0, 0.5, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Back,
			0.5,
			true
		)
	end
end

local function closeShop()
	if guiOpen then
		guiOpen = false
		mainFrame:TweenPosition(
			UDim2.new(0.5, 0, -0.5, 0),
			Enum.EasingDirection.In,
			Enum.EasingStyle.Back,
			0.3,
			true,
			function()
				mainFrame.Visible = false
			end
		)
	end
end

local function checkProximity()
	while true do
		wait(0.5)

		if character and humanoidRootPart then
			local distance = (humanoidRootPart.Position - shopPart.Position).Magnitude

			if distance <= INTERACTION_RANGE then
				if not isInRange then
					isInRange = true
					promptGui.Enabled = true
				end
			else
				if isInRange then
					isInRange = false
					promptGui.Enabled = false
					closeShop()
				end
			end
		end
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E and isInRange and not guiOpen then
		openShop()
	end
end)

-- Close button
closeButton.MouseButton1Click:Connect(function()
	closeShop()
end)

-- Purchase result feedback
purchaseResultEvent.OnClientEvent:Connect(function(success, fruitName)
	if success then
		print("? Successfully purchased " .. fruitName .. "!")
		-- You can add a success notification here (optional)
		-- Example: show a green text label that fades out
	else
		warn("? Failed to purchase " .. fruitName .. "! Not enough money or other error.")
		-- You can add an error notification here (optional)
		-- Example: show a red text label that fades out
	end
end)

-- Character respawn handling
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	closeShop()
end)

-- Start proximity checking
spawn(checkProximity)