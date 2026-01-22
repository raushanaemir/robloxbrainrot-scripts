local player = game.Players.LocalPlayer
local shopArea = workspace:WaitForChild("ShopArea")
local buyEvent = game.ReplicatedStorage:WaitForChild("BuyFood")

local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.Parent = player.PlayerGui
gui.Enabled = false

local button = Instance.new("TextButton")
button.Size = UDim2.fromScale(0.3, 0.15)
button.Position = UDim2.fromScale(0.35, 0.75)
button.Text = "Buy Food"
button.Parent = gui

local function isInShop()
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return (hrp.Position - shopArea.Position).Magnitude <= 8
end

task.spawn(function()
	while true do
		gui.Enabled = isInShop()
		task.wait(0.15)
	end
end)

button.MouseButton1Click:Connect(function()
	buyEvent:FireServer()
end)
