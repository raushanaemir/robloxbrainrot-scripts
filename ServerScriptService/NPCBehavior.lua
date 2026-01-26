-- NPC BEHAVIOR MODULE (NO AVOIDANCE)
-- Place this as a ModuleScript INSIDE the main NPCSpawner script, named "NPCBehavior"

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Parent.SharedData)
local startPoint = Workspace:WaitForChild("StartPoint")

-- Function to generate a circular/oval loop path starting and ending at startPos
local function generateCircularPath(startPos, radius, numWaypoints, ovalStretchX, ovalStretchZ)
	numWaypoints = numWaypoints or 20
	ovalStretchX = ovalStretchX or 1
	ovalStretchZ = ovalStretchZ or 1

	local waypoints = {}

	-- Center is offset from start so the circle passes through startPos
	local centerPos = startPos + Vector3.new(radius * ovalStretchX, 0, 0)

	-- Generate points around a circle/oval, starting from π (left side of circle)
	-- Skip i=0 since that's the start position (NPC is already there)
	-- NEGATIVE angle increment = clockwise (opposite direction)
	for i = 1, numWaypoints do
		local angle = math.pi - (i / numWaypoints) * math.pi * 2  -- Subtract instead of add for opposite direction

		local x = math.cos(angle) * radius * ovalStretchX
		local z = math.sin(angle) * radius * ovalStretchZ

		local point = centerPos + Vector3.new(x, 0, z)
		table.insert(waypoints, point)
	end

	return waypoints
end

return function(npc, humanoid, rootPart, npcType, equipPrompt, unequipPrompt)
	-- === Animation setup ===
	local idleAnimTrack, walkAnimTrack
	local lastMoving = false

	local idleAnimId = npc:GetAttribute("IdleAnimationId")
	local walkAnimId = npc:GetAttribute("WalkAnimationId")

	if idleAnimId then
		local idleAnim = npc:FindFirstChild("IdleAnimation")
		if idleAnim and idleAnim:IsA("Animation") then
			idleAnimTrack = humanoid:LoadAnimation(idleAnim)
			idleAnimTrack.Priority = Enum.AnimationPriority.Idle
			idleAnimTrack.Looped = true
			idleAnimTrack:Play()
		end
	end
	if walkAnimId then
		local walkAnim = npc:FindFirstChild("WalkAnimation")
		if walkAnim and walkAnim:IsA("Animation") then
			walkAnimTrack = humanoid:LoadAnimation(walkAnim)
			walkAnimTrack.Priority = Enum.AnimationPriority.Movement
			walkAnimTrack.Looped = true
		end
	end

	-- === Main behavior function ===
	task.spawn(function()
		local lastOwnerPosition = nil
		local ownerStillTime = 0
		local isReturningToBase = false
		local pathUpdateTime = 0
		local lastCoinTime = tick()

		-- Track which container level this NPC belongs to (set when first contained)
		local assignedContainerLevel = nil

		-- Generate circular path for this NPC starting at startPoint
		local curvedWaypoints = generateCircularPath(
			startPoint.Position,
			62.5,  -- Radius of the circle (increased from 50 to 100 for bigger loop)
			40,   -- Number of waypoints (increased for smoother path on bigger circle)
			1,    -- X stretch (1 = circle, >1 = wider oval)
			1     -- Z stretch (1 = circle, >1 = taller oval)
		)
		local currentWaypointIndex = 1

		-- Debug
		print("NPC spawned, path has " .. #curvedWaypoints .. " waypoints")

		-- Function to move directly
		local function moveToTarget(targetPos)
			if rootPart and humanoid then
				humanoid:MoveTo(targetPos)
			end
		end

		-- Helper: get a random point inside a container (BasePart or Model)
		local function getRandomPointInContainer(container)
			if not container then return nil end
			local cframe, size
			if container:IsA("BasePart") then
				cframe = container.CFrame
				size = container.Size
			elseif container:IsA("Model") then
				cframe, size = container:GetBoundingBox()
			else
				return nil
			end
			local half = size / 2
			local x = math.random() * size.X - half.X
			local y = 0 -- keep on floor
			local z = math.random() * size.Z - half.Z
			return cframe.Position + cframe.RightVector * x + cframe.LookVector * z
		end

		-- Main behavior loop
		while npc.Parent do
			if rootPart and rootPart.Parent and humanoid.Health > 0 then
				-- === Animation switching ===
				local isMoving = humanoid.MoveDirection.Magnitude > 0.1 or humanoid.WalkSpeed > 0
				if walkAnimTrack and idleAnimTrack then
					if isMoving and not lastMoving then
						if idleAnimTrack.IsPlaying then idleAnimTrack:Stop() end
						if not walkAnimTrack.IsPlaying then walkAnimTrack:Play() end
						lastMoving = true
					elseif not isMoving and lastMoving then
						if walkAnimTrack.IsPlaying then walkAnimTrack:Stop() end
						if not idleAnimTrack.IsPlaying then idleAnimTrack:Play() end
						lastMoving = false
					end
				end

				local ownerName = npc:GetAttribute("Owner")
				local isOwned = npc:GetAttribute("Owned")
				local isEquipped = npc:GetAttribute("Equipped")
				local isContained = npc:GetAttribute("Contained")

				-- Update prompt visibility
				if isOwned and ownerName ~= "" then
					local ownerPlayer = Players:FindFirstChild(ownerName)
					if ownerPlayer then
						local inPlot, _ = Shared.isInPlot(ownerPlayer, rootPart.Position)

						equipPrompt.Enabled = (not isEquipped and inPlot == true)
						unequipPrompt.Enabled = (isEquipped == true and inPlot == true)
					end
				else
					equipPrompt.Enabled = false
					unequipPrompt.Enabled = false
				end

				-- Generate coins when contained (unequipped in base) - NOT when equipped
				if isOwned and isContained and not isEquipped then
					-- Roam logic: pick a random point in container and move to it
					local ownerPlayer = Players:FindFirstChild(ownerName)
					local container = nil
					if ownerPlayer then
						local containerLevel = assignedContainerLevel or (Shared.playerBaseLevels[ownerPlayer] or 1)
						container = Shared.getContainerByLevel(ownerPlayer, containerLevel)
					end

					-- Only roam if container exists
					if container then
						roamCooldown = roamCooldown - 0.1
						if not roamTarget or roamCooldown <= 0 or (rootPart.Position - roamTarget).Magnitude < 3 then
							roamTarget = getRandomPointInContainer(container)
							roamCooldown = math.random(2, 5) -- roam every 2-5 seconds
						end
						if roamTarget then
							humanoid.WalkSpeed = npcType.walkSpeed
							humanoid:MoveTo(roamTarget)
						end
					else
						-- fallback: stand still
						humanoid.WalkSpeed = 0
						humanoid:MoveTo(rootPart.Position)
					end

					-- Coin generation
					local currentTime = tick()
					local timeSinceLastCoin = currentTime - lastCoinTime
					-- Use coins/s with status multiplier (get the real status table)
					local statusName = npc:GetAttribute("Status")
					local NPCConfig = require(script.Parent.Parent.NPCConfig)
					local statusTable
					for _, s in ipairs(NPCConfig.statuses) do
						if s.name == statusName then
							statusTable = s
							break
						end
					end
					local cps = NPCConfig.getCoinsPerSecond(npcType, statusTable) or npc:GetAttribute("Info_CPS") or 0
					if cps > 0 and timeSinceLastCoin >= 1 then
						if ownerPlayer then
							local base = Shared.playerToBase[ownerPlayer]
							if base and Shared.addCoinsToBase then
								Shared.addCoinsToBase(base, cps * timeSinceLastCoin)
							end
						end
						lastCoinTime = currentTime
					end
				else
					roamTarget = nil -- reset roam target if not contained/unequipped
				end

				if isOwned and ownerName ~= "" then
					local ownerPlayer = Players:FindFirstChild(ownerName)
					if ownerPlayer and ownerPlayer.Character then
						local ownerRoot = ownerPlayer.Character:FindFirstChild("HumanoidRootPart")
						if ownerRoot then
							local ownerBase = Shared.playerToBase[ownerPlayer]
							local inPlot, plotLevel = Shared.isInPlot(ownerPlayer, rootPart.Position)

							-- Inside plot area
							if inPlot == true then
								isReturningToBase = false
								if not npc:GetAttribute("Contained") then
									npc:SetAttribute("Contained", true)
									lastCoinTime = tick()

									-- Assign this NPC to the current plot level's container (first time only)
									if not assignedContainerLevel then
										assignedContainerLevel = plotLevel or (Shared.playerBaseLevels[ownerPlayer] or 1)
										npc:SetAttribute("AssignedContainerLevel", assignedContainerLevel)
										print(npc.Name .. " assigned to container level " .. assignedContainerLevel)
									end

									print(npc.Name .. " entered " .. ownerPlayer.Name .. "'s base (container level " .. (assignedContainerLevel or "?") .. ")")
								end

								if not isEquipped then
									-- Unequipped in base - stand still (no roaming)
									humanoid.WalkSpeed = 0
									humanoid:MoveTo(rootPart.Position)

									-- Still assign to container level for tracking purposes
									if not assignedContainerLevel then
										assignedContainerLevel = plotLevel or (Shared.playerBaseLevels[ownerPlayer] or 1)
										npc:SetAttribute("AssignedContainerLevel", assignedContainerLevel)
										print(npc.Name .. " assigned to container level " .. assignedContainerLevel)
									end
								else
									-- Equipped in base - follow owner (no coin generation)
									local ownerIsMoving = false
									if lastOwnerPosition then
										local movementDist = (ownerRoot.Position - lastOwnerPosition).Magnitude
										if movementDist > 0.5 then
											ownerIsMoving = true
											ownerStillTime = 0
										else
											ownerStillTime = ownerStillTime + 0.1
										end
									end
									lastOwnerPosition = ownerRoot.Position

									local distToOwner = (rootPart.Position - ownerRoot.Position).Magnitude
									local currentTime = tick()

									if ownerIsMoving or ownerStillTime < 1.5 then
										humanoid.WalkSpeed = npcType.followSpeed
										local followDistance = 10

										if distToOwner > followDistance then
											moveToTarget(ownerRoot.Position)
										else
											humanoid:MoveTo(rootPart.Position)
											humanoid.WalkSpeed = 0
										end
									end
								end

							elseif isEquipped then
								-- Outside base AND equipped - follow owner
								if npc:GetAttribute("Contained") then
									npc:SetAttribute("Contained", false)
									print(npc.Name .. " left base")
								end

								local ownerIsMoving = false
								if lastOwnerPosition then
									local movementDist = (ownerRoot.Position - lastOwnerPosition).Magnitude
									if movementDist > 0.5 then
										ownerIsMoving = true
										ownerStillTime = 0
									else
										ownerStillTime = ownerStillTime + 0.05
									end
								end
								lastOwnerPosition = ownerRoot.Position

								local distToOwner = (rootPart.Position - ownerRoot.Position).Magnitude
								local currentTime = tick()

								if ownerIsMoving or ownerStillTime < 0.05 then
									humanoid.WalkSpeed = npcType.followSpeed
									local followDistance = 10

									if distToOwner > followDistance then
										moveToTarget(ownerRoot.Position)
									else
										humanoid:MoveTo(rootPart.Position)
										humanoid.WalkSpeed = 0
									end
								end

							else
								-- Outside base but NOT equipped - return to base plot
								if npc:GetAttribute("Contained") then
									npc:SetAttribute("Contained", false)
								end

								if ownerBase then
									-- Return to the assigned container level, or level 1 if not assigned
									local containerLevel = assignedContainerLevel or npc:GetAttribute("AssignedContainerLevel") or 1
									local baseLevel = ownerBase:FindFirstChild("BaseLevel" .. containerLevel)
									if baseLevel then
										local plot = baseLevel:FindFirstChild("Plot")
										if plot then
											humanoid.WalkSpeed = npcType.followSpeed
											local plotPos
											if plot:IsA("BasePart") then
												plotPos = plot.Position
											elseif plot:IsA("Model") then
												local cf, _ = plot:GetBoundingBox()
												plotPos = cf.Position
											end
											if plotPos then
												moveToTarget(plotPos)
											end
										end
									end
								else
									humanoid.WalkSpeed = npcType.walkSpeed
								end
							end
						end
					else
						-- Invalid owner: unclaim and reset
						require(script.Parent.NPCUtils).resetNPCOwnership(npc, rootPart)
						humanoid.WalkSpeed = npcType.walkSpeed
						currentWaypointIndex = 1
						assignedContainerLevel = nil
					end
				else
					-- Unowned: follow circular path back to startPoint
					local distToStart = (rootPart.Position - startPoint.Position).Magnitude

					-- Check if completed the loop (back near start after going through waypoints)
					if currentWaypointIndex > #curvedWaypoints and distToStart < 8 then
						print("NPC completed loop, destroying")
						npc:Destroy()
						break
					else
						-- Follow circular waypoints
						if currentWaypointIndex <= #curvedWaypoints then
							local targetWaypoint = curvedWaypoints[currentWaypointIndex]
							local distToWaypoint = (rootPart.Position - targetWaypoint).Magnitude

							-- Move to current waypoint
							moveToTarget(targetWaypoint)

							-- If close enough to waypoint, move to next one
							if distToWaypoint < 8 then
								currentWaypointIndex = currentWaypointIndex + 1
								print("NPC moving to waypoint " .. currentWaypointIndex .. "/" .. #curvedWaypoints)
							end
						else
							-- Reached all waypoints, move back to start
							moveToTarget(startPoint.Position)
						end
					end
				end
			end
			task.wait(0.1)
		end
		-- Stop animations on cleanup
		if idleAnimTrack and idleAnimTrack.IsPlaying then idleAnimTrack:Stop() end
		if walkAnimTrack and walkAnimTrack.IsPlaying then walkAnimTrack:Stop() end
	end)
end