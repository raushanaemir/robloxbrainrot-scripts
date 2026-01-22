-- BASE & FORCEFIELD MANAGEMENT SCRIPT (UPDATED: Kill on Touch, No Push)
-- Place in ServerScriptService

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

print("=== BASE & FORCEFIELD MANAGER LOADED ===")

-- Configuration
local BASE_COUNT = 4
local FORCEFIELD_DURATION = 30

-- Collect bases
local bases = {}
for i = 1, BASE_COUNT do
	local baseName = "Base" .. i
	local base = Workspace:WaitForChild(baseName, 8)
	if not base then
		warn("Missing: " .. baseName)
		continue
	end

	local forcefield = base:FindFirstChild("Forcefield")
	local plate = base:FindFirstChild("ActivationPlate")

	if not forcefield or not plate then
		warn("Missing Forcefield or ActivationPlate in " .. baseName)
		continue
	end

	table.insert(bases, base)
end

if #bases == 0 then
	error("No valid bases found!")
end

print("Loaded " .. #bases .. " bases")

-- Shared data
local Shared = require(script.Parent.SharedData)
Shared.bases = bases

-- State tables (local to this script)
local platePlayers      = {} -- base ? {player = true}
local forcefieldOwners  = {} -- base ? player
local forcefieldActives = {} -- base ? bool
local forcefieldTimers  = {} -- base ? thread

-- Create name GUI above base
local function createNameGui(base, playerName)
	local existing = base:FindFirstChild("NameGui")
	if existing then existing:Destroy() end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameGui"
	gui.Adornee = base
	gui.Size = UDim2.new(15, 0, 5, 0)
	gui.StudsOffset = Vector3.new(0, base.Size.Y/2 + 6, 0)
	gui.LightInfluence = 0
	gui.Parent = base

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1,0,1,0)
	label.BackgroundTransparency = 1
	label.Text = playerName
	label.TextColor3 = Color3.new(1,1,1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0,0,0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = gui
end

-- Activate forcefield
local function activateForcefield(base, owner)
	forcefieldOwners[base] = owner
	forcefieldActives[base] = true

	local ff = base.Forcefield
	ff.Transparency = 0.7
	ff.CanCollide = false

	print(owner.Name .. " activated forcefield on " .. base.Name .. " (30s)")

	if forcefieldTimers[base] then
		task.cancel(forcefieldTimers[base])
	end

	forcefieldTimers[base] = task.delay(FORCEFIELD_DURATION, function()
		forcefieldActives[base] = false
		ff.Transparency = 1
		forcefieldOwners[base] = nil
		forcefieldTimers[base] = nil
		print("Forcefield deactivated ? " .. base.Name)
	end)
end

-- Setup each base
for _, base in ipairs(Shared.bases) do
	local ff = base.Forcefield
	local plate = base.ActivationPlate

	ff.Transparency = 1
	ff.CanCollide = false
	plate.CanCollide = true
	plate.Anchored = true

	platePlayers[base] = {}
	forcefieldActives[base] = false
	forcefieldOwners[base] = nil

	-- KILL players who touch active enemy forcefield
	ff.Touched:Connect(function(hit)
		if not forcefieldActives[base] then return end

		local char = hit:FindFirstAncestorWhichIsA("Model")
		if not char then return end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		local player = Players:GetPlayerFromCharacter(char)

		-- Handle players
		if player then
			if player == forcefieldOwners[base] then return end
			hum.Health = 0
			print(player.Name .. " died touching enemy forcefield ? " .. base.Name)
		else
			-- Handle NPCs
			local npcOwnerName = char:GetAttribute("Owner")
			local owner = forcefieldOwners[base]

			-- Kill NPC if it doesn't belong to the forcefield owner
			if npcOwnerName and npcOwnerName ~= "" and npcOwnerName ~= owner.Name then
				hum.Health = 0
				char:Destroy()
				print("NPC (" .. npcOwnerName .. "'s) died touching " .. owner.Name .. "'s forcefield ? " .. base.Name)
			end
		end
	end)

	-- Plate touch detection
	plate.Touched:Connect(function(hit)
		local char = hit.Parent
		if not char:FindFirstChildOfClass("Humanoid") then return end

		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		if not platePlayers[base][player] then
			platePlayers[base][player] = true
			if Shared.assignments[base] == player then
				activateForcefield(base, player)
			end
		end
	end)

	plate.TouchEnded:Connect(function(hit)
		local char = hit.Parent
		if not char:FindFirstChildOfClass("Humanoid") then return end

		local player = Players:GetPlayerFromCharacter(char)
		if player then
			platePlayers[base][player] = nil
		end
	end)
end

-- Player assignment & cleanup
Players.PlayerAdded:Connect(function(player)
	local assigned = false
	for _, base in ipairs(Shared.bases) do
		if not Shared.assignments[base] then
			Shared.assignments[base] = player
			Shared.playerToBase[player] = base
			createNameGui(base, player.Name)
			print(player.Name .. " assigned ? " .. base.Name)
			assigned = true
			break
		end
	end
	if not assigned then
		warn("No free base for " .. player.Name)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local base = Shared.playerToBase[player]
	if not base then return end

	local gui = base:FindFirstChild("NameGui")
	if gui then gui:Destroy() end

	Shared.assignments[base] = nil
	Shared.playerToBase[player] = nil

	if forcefieldTimers[base] then
		task.cancel(forcefieldTimers[base])
	end

	local ff = base.Forcefield
	ff.Transparency = 1
	forcefieldActives[base] = false
	forcefieldOwners[base] = nil

	print(player.Name .. " left ? freed " .. base.Name)
end)