local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Track which NPCs we've already set up
local processedNPCs = {}

-- Function to manage outline and steal prompt for an NPC
local function setupNPC(npc)
	if processedNPCs[npc] then return end
	processedNPCs[npc] = true

	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Wait for steal prompt with better error handling
	local stealPrompt = rootPart:FindFirstChild("StealPrompt")
	if not stealPrompt then
		-- If prompt doesn't exist yet, wait for it
		local timeout = 0
		while not stealPrompt and timeout < 50 do
			task.wait(0.1)
			stealPrompt = rootPart:FindFirstChild("StealPrompt")
			timeout = timeout + 1
		end

		if not stealPrompt then
			warn("StealPrompt not found for NPC")
			processedNPCs[npc] = nil
			return
		end
	end

	-- Create Highlight for the entire model
	local highlight = Instance.new("Highlight")
	highlight.Adornee = npc
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = npc
	highlight.Name = "OwnershipHighlight"

	-- Function to update everything based on ownership
	local function updateNPC()
		-- Safety check
		if not npc or not npc.Parent then return end

		local isOwned = npc:GetAttribute("Owned")

		if isOwned then
			local ownerName = npc:GetAttribute("Owner")
			local isOwner = (ownerName == player.Name)
			local isContained = npc:GetAttribute("Contained")

			-- Update outline color
			if isOwner then
				highlight.OutlineColor = Color3.new(0, 1, 0) -- Bright green
			else
				highlight.OutlineColor = Color3.new(1, 0, 0) -- Bright red
			end

			-- Show highlight logic: hide when contained in base, show when outside
			if isContained then
				highlight.Enabled = false
			else
				highlight.Enabled = true
			end

			-- Manage steal prompt visibility
			if stealPrompt then
				stealPrompt.Enabled = not isOwner
			end
		else
			-- Not owned yet, hide highlight
			highlight.Enabled = false
			if stealPrompt then
				stealPrompt.Enabled = false
			end
		end
	end

	-- Initial update (with delay to ensure attributes are set)
	task.wait(0.3)
	updateNPC()

	-- Listen for attribute changes
	npc:GetAttributeChangedSignal("Owner"):Connect(updateNPC)
	npc:GetAttributeChangedSignal("Owned"):Connect(updateNPC)
	npc:GetAttributeChangedSignal("Contained"):Connect(updateNPC)

	-- CONTINUOUS CHECK - Force correct steal prompt state
	if stealPrompt then
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not npc or not npc.Parent then
				connection:Disconnect()
				processedNPCs[npc] = nil
				return
			end

			if npc:GetAttribute("Owned") then
				local ownerName = npc:GetAttribute("Owner")
				if ownerName == player.Name and stealPrompt.Enabled then
					stealPrompt.Enabled = false
				elseif ownerName ~= player.Name and not stealPrompt.Enabled then
					stealPrompt.Enabled = true
				end
			end
		end)
	end

	-- Clean up when NPC is destroyed
	npc.Destroying:Connect(function()
		processedNPCs[npc] = nil
		if highlight then
			highlight:Destroy()
		end
	end)
end

-- Monitor new NPCs being added
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
		task.wait(0.5)
		setupNPC(descendant)
	end
end)

-- Setup existing NPCs
for _, descendant in pairs(workspace:GetDescendants()) do
	if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
		task.spawn(function()
			setupNPC(descendant)
		end)
	end
end