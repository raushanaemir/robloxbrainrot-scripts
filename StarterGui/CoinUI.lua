-- =====================================================
-- COIN UI - CLIENT SCRIPT (CONFIGURABLE)
-- Place in: StarterGui > CoinDisplay (ScreenGui) > CoinFrame (Frame) > CoinLabel (TextLabel)
-- Then put this LocalScript inside the ScreenGui
-- =====================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- =====================================================
-- ?? EASY CONFIGURATION
-- =====================================================
local CONFIG = {
	coinName = "Coins",        -- Change to "Gold", "Money", "Cash", etc.
	showBefore = false,        -- true = "Coins 500" | false = "500 Coins"
	separator = " ",           -- Space between number and name (can be "" for no space)

	-- Format options
	useCommas = false,         -- true = "1,000" | false = "1000" or "1K"
	abbreviateAt = 1000,       -- Start abbreviating at this number (set to math.huge to never abbreviate)
}
-- =====================================================

-- Get references to your GUI elements
local screenGui = script.Parent
local coinFrame = screenGui:WaitForChild("CoinFrame")
local coinLabel = coinFrame:WaitForChild("CoinLabel")

-- Format large numbers with abbreviations
local function formatNumberAbbreviated(num)
	if num >= 1000000000 then
		return string.format("%.2fB", num / 1000000000)
	elseif num >= 1000000 then
		return string.format("%.2fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.2fK", num / 1000)
	else
		return tostring(math.floor(num))
	end
end

-- Format numbers with commas (1,234,567)
local function formatNumberWithCommas(num)
	local formatted = tostring(math.floor(num))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then
			break
		end
	end
	return formatted
end

-- Main format function
local function formatNumber(num)
	if CONFIG.useCommas then
		return formatNumberWithCommas(num)
	elseif num >= CONFIG.abbreviateAt then
		return formatNumberAbbreviated(num)
	else
		return tostring(math.floor(num))
	end
end

-- Update display with configured format
local function updateCoinDisplay(coins)
	local formattedNumber = formatNumber(coins)

	if CONFIG.showBefore then
		-- Format: "Coins 500"
		coinLabel.Text = CONFIG.coinName .. CONFIG.separator .. formattedNumber
	else
		-- Format: "500 Coins"
		coinLabel.Text = formattedNumber .. CONFIG.separator .. CONFIG.coinName
	end
end

-- Listen for server updates
local updateEvent = ReplicatedStorage:WaitForChild("UpdateCoins")
updateEvent.OnClientEvent:Connect(function(coins)
	updateCoinDisplay(coins)
end)

-- Initial sync from leaderboard
task.spawn(function()
	task.wait(1)
	if player:FindFirstChild("leaderstats") then
		local coins = player.leaderstats:FindFirstChild("Coins")
		if coins then
			updateCoinDisplay(coins.Value)
			-- Listen for changes
			coins.Changed:Connect(function(newValue)
				updateCoinDisplay(newValue)
			end)
		end
	end
end)

print("? Coin UI Loaded! Currency: " .. CONFIG.coinName)

-- =====================================================
-- CONFIGURATION EXAMPLES:
-- =====================================================
--[[

Example 1: Gold with commas before number
CONFIG = {
	coinName = "Gold",
	showBefore = true,
	separator = " ",
	useCommas = true,
	abbreviateAt = math.huge,
}
Result: "Gold 1,234"

Example 2: Cash after number, abbreviated
CONFIG = {
	coinName = "Cash",
	showBefore = false,
	separator = " ",
	useCommas = false,
	abbreviateAt = 1000,
}
Result: "1.23K Cash"

Example 3: Money symbol with no space
CONFIG = {
	coinName = "$",
	showBefore = true,
	separator = "",
	useCommas = true,
	abbreviateAt = math.huge,
}
Result: "$1,234"

Example 4: Gems abbreviated at 10,000
CONFIG = {
	coinName = "??",
	showBefore = false,
	separator = " ",
	useCommas = false,
	abbreviateAt = 10000,
}
Result: "9999 ??" or "10.5K ??"

]]