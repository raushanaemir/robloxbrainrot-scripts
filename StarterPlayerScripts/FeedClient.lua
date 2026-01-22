local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local creature = workspace:WaitForChild("FeedTest")
local feedCount = creature:WaitForChild("FeedCount")
local feedEvent = ReplicatedStorage:WaitForChild("FeedCreature")
local feedLimitEvent = ReplicatedStorage:WaitForChild("GetFeedLimit")

-- Get feed limit from server
local FEEDS_PER_GROW = feedLimitEvent:InvokeServer()

-- Billboard GUI for hover
local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromScale(4, 1)
billboard.StudsOffset = Vector3.new(0, 5, 0)
billboard.AlwaysOnTop = true
billboard.Enabled = false
billboard.Parent = creature.PrimaryPart

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = billboard

-- Update hover text
local function updateText()
	label.Text = feedCount.Value .. "/" .. FEEDS_PER_GROW
end

updateText()
feedCount.Changed:Connect(updateText)

-- Hover detection
RunService.RenderStepped:Connect(function()
	local target = mouse.Target
	if target and target:IsDescendantOf(creature) then
		billboard.Enabled = true
	else
		billboard.Enabled = false
	end
end)

-- Feed on click
mouse.Button1Down:Connect(function()
	if mouse.Target and mouse.Target:IsDescendantOf(creature) then
		feedEvent:FireServer()
	end
end)
