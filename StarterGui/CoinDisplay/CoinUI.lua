-- =====================================================
-- COIN UI - UIListLayout VERSION (BEST PRACTICE)
-- =====================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- =====================================================
-- CONFIG
-- =====================================================
local CONFIG = {
	coinImage = "rbxassetid://140561848794204",
	useCommas = false,
	abbreviateAt = 1000,
	iconSize = 24,
	padding = 0, -- No automatic padding
	iconAfterText = true, -- true = [TEXT][ICON], false = [ICON][TEXT]
}
-- =====================================================

local screenGui = script.Parent -- should be CoinDisplay (ScreenGui)
local coinFrame = screenGui:WaitForChild("CoinFrame")
local coinLabel = coinFrame:WaitForChild("CoinLabel")

-- Create layout if not present
local layout = coinFrame:FindFirstChild("UIListLayout")
if not layout then
	layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, 0)
	layout.Parent = coinFrame
end

-- Create CoinIcon if not present
local coinIcon = coinFrame:FindFirstChild("CoinIcon")
if not coinIcon then
	coinIcon = Instance.new("ImageLabel")
	coinIcon.Name = "CoinIcon"
	coinIcon.BackgroundTransparency = 1
	coinIcon.Size = UDim2.fromOffset(CONFIG.iconSize, CONFIG.iconSize)
	coinIcon.Image = CONFIG.coinImage
	coinIcon.Parent = coinFrame
end

coinIcon.Visible = true

-- Text settings
coinLabel.AutomaticSize = Enum.AutomaticSize.X
coinLabel.TextXAlignment = Enum.TextXAlignment.Left
coinLabel.TextYAlignment = Enum.TextYAlignment.Center

-- Order control
if CONFIG.iconAfterText then
	coinLabel.LayoutOrder = 1
	coinIcon.LayoutOrder = 2
else
	coinLabel.LayoutOrder = 2
	coinIcon.LayoutOrder = 1
end

-- =====================================================
-- NUMBER FORMATTING
-- =====================================================

local function formatAbbrev(num)
	if num >= 1e9 then
		return string.format("%.1fB", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.1fM", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fK", num / 1e3)
	else
		return tostring(math.floor(num))
	end
end

local function formatCommas(num)
	local s = tostring(math.floor(num))
	while true do
		local new, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = new
		if k == 0 then break end
	end
	return s
end

local function formatNumber(num)
	if CONFIG.useCommas then
		return formatCommas(num)
	elseif num >= CONFIG.abbreviateAt then
		return formatAbbrev(num)
	else
		return tostring(math.floor(num))
	end
end

-- =====================================================
-- UPDATE UI
-- =====================================================

local function updateCoinDisplay(value)
	coinLabel.Text = formatNumber(value)
end

-- =====================================================
-- DATA HOOK
-- =====================================================

local event = ReplicatedStorage:FindFirstChild("UpdateCoins")
if event then
	event.OnClientEvent:Connect(updateCoinDisplay)
end

task.spawn(function()
	task.wait(1)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local coins = stats:FindFirstChild("Coins")
		if coins then
			updateCoinDisplay(coins.Value)
			coins.Changed:Connect(updateCoinDisplay)
		end
	end
end)

print("✅ Coin UI (UIListLayout) Loaded")
