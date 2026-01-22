	-- NPC BEHAVIOR MODULE (NO AVOIDANCE)
	-- Place this as a ModuleScript INSIDE the main NPCSpawner script, named "NPCBehavior"

	local Players = game:GetService("Players")
	local PathfindingService = game:GetService("PathfindingService")
	local Workspace = game:GetService("Workspace")

	local Shared = require(script.Parent.Parent.SharedData)
	local endPoint = Workspace:WaitForChild("EndPoint")

	return function(npc, humanoid, rootPart, npcType, equipPrompt, unequipPrompt)
		task.spawn(function()
			local roamTarget = nil
			local lastRoamTime = 0
			local lastOwnerPosition = nil
			local ownerStillTime = 0
			local isReturningToBase = false
			local pathUpdateTime = 0

			-- Function to move directly
			local function moveToTarget(targetPos)
				if rootPart and humanoid then
					humanoid:MoveTo(targetPos)
				end
			end

			-- Main behavior loop
			while npc.Parent do
				if rootPart and rootPart.Parent and humanoid.Health > 0 then
					local ownerName = npc:GetAttribute("Owner")
					local isOwned = npc:GetAttribute("Owned")
					local isEquipped = npc:GetAttribute("Equipped")

					-- Update prompt visibility
					if isOwned and ownerName ~= "" then
						local ownerPlayer = Players:FindFirstChild(ownerName)
						if ownerPlayer then
							local ownerBase = Shared.playerToBase[ownerPlayer]
							local inBase = ownerBase and Shared.isInBase(ownerBase, rootPart.Position)

							equipPrompt.Enabled = (not isEquipped and inBase)
							unequipPrompt.Enabled = (isEquipped and inBase)
						end
					else
						equipPrompt.Enabled = false
						unequipPrompt.Enabled = false
					end

					if isOwned and ownerName ~= "" then
						local ownerPlayer = Players:FindFirstChild(ownerName)
						if ownerPlayer and ownerPlayer.Character then
							local ownerRoot = ownerPlayer.Character:FindFirstChild("HumanoidRootPart")
							if ownerRoot then
								local ownerBase = Shared.playerToBase[ownerPlayer]

								-- Inside base
								if ownerBase and Shared.isInBase(ownerBase, rootPart.Position) then
									isReturningToBase = false
									if not npc:GetAttribute("Contained") then
										npc:SetAttribute("Contained", true)
										print(npc.Name .. " entered " .. ownerPlayer.Name .. "'s base")
									end

									if not isEquipped then
										-- Unequipped - roam in base
										humanoid.WalkSpeed = npcType.walkSpeed

										local currentTime = tick()
										local baseCFrame = ownerBase.CFrame
										local baseSize = ownerBase.Size

										if not roamTarget or (rootPart.Position - roamTarget).Magnitude < 3 or currentTime - lastRoamTime > math.random(3, 8) then
											local safeMargin = math.min(baseSize.X, baseSize.Z) * 0.2
											local halfSize = baseSize / 2
											local safeHalfX = halfSize.X - safeMargin
											local safeHalfZ = halfSize.Z - safeMargin

											local randomX = math.random(-safeHalfX * 100, safeHalfX * 100) / 100
											local randomZ = math.random(-safeHalfZ * 100, safeHalfZ * 100) / 100
											local randomY = 0

											if math.random() < 0.3 then
												roamTarget = rootPart.Position
											else
												local localTarget = Vector3.new(randomX, randomY, randomZ)
												roamTarget = baseCFrame:PointToWorldSpace(localTarget)
											end

											moveToTarget(roamTarget)
											lastRoamTime = currentTime
										end

										-- Safety clamp
										local relativePos = baseCFrame:PointToObjectSpace(rootPart.Position)
										local halfSizeClamp = baseSize / 2
										local clampedX = math.clamp(relativePos.X, -halfSizeClamp.X + 1, halfSizeClamp.X - 1)
										local clampedY = math.clamp(relativePos.Y, -halfSizeClamp.Y + 1, halfSizeClamp.Y - 1)
										local clampedZ = math.clamp(relativePos.Z, -halfSizeClamp.Z + 1, halfSizeClamp.Z - 1)
										local clampedWorld = baseCFrame:PointToWorldSpace(Vector3.new(clampedX, clampedY, clampedZ))
										rootPart.Position = clampedWorld
									else
										-- Equipped in base - follow owner directly
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
											roamTarget = nil
											local distToOwner = (rootPart.Position - ownerRoot.Position).Magnitude
											local followDistance = 10 -- minimum distance to start moving

											if distToOwner > followDistance then
												humanoid.WalkSpeed = npcType.followSpeed
												roamTarget = nil
												moveToTarget(ownerRoot.Position)
											else
												-- player is close enough, stop NPC
												humanoid:MoveTo(rootPart.Position) -- stops movement
												humanoid.WalkSpeed = 0 -- optional: stops walk animation
											end
										else
											humanoid.WalkSpeed = npcType.walkSpeed
											if not roamTarget or (rootPart.Position - roamTarget).Magnitude < 3 or currentTime - lastRoamTime > math.random(3, 8) then
												local roamRadius = 12
												local randomAngle = math.random() * math.pi * 2
												local randomDist = math.random(5, roamRadius)
												local offsetX = math.cos(randomAngle) * randomDist
												local offsetZ = math.sin(randomAngle) * randomDist
												roamTarget = ownerRoot.Position + Vector3.new(offsetX, 0, offsetZ)
												moveToTarget(roamTarget)
												lastRoamTime = currentTime
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
										roamTarget = nil
										local distToOwner = (rootPart.Position - ownerRoot.Position).Magnitude
										local followDistance = 10 -- minimum distance to start moving

										if distToOwner > followDistance then
											humanoid.WalkSpeed = npcType.followSpeed
											roamTarget = nil
											moveToTarget(ownerRoot.Position)
										else
											-- player is close enough, stop NPC
											humanoid:MoveTo(rootPart.Position) -- stops movement
											humanoid.WalkSpeed = 0 -- optional: stops walk animation
										end
									else
										humanoid.WalkSpeed = npcType.walkSpeed
										if not roamTarget or (rootPart.Position - roamTarget).Magnitude < 3 or currentTime - lastRoamTime > math.random(3, 8) then
											local roamRadius = 12
											local randomAngle = math.random() * math.pi * 2
											local randomDist = math.random(5, roamRadius)
											local offsetX = math.cos(randomAngle) * randomDist
											local offsetZ = math.sin(randomAngle) * randomDist
											roamTarget = ownerRoot.Position + Vector3.new(offsetX, 0, offsetZ)
											moveToTarget(roamTarget)
											lastRoamTime = currentTime
										end
									end

								else
									-- Outside base but NOT equipped - return to base
									if npc:GetAttribute("Contained") then
										npc:SetAttribute("Contained", false)
									end

									local ownerBase = Shared.playerToBase[ownerPlayer]
									if ownerBase then
										humanoid.WalkSpeed = npcType.followSpeed
										moveToTarget(ownerBase.Position)
									else
										humanoid.WalkSpeed = npcType.walkSpeed
									end
								end
							end
						else
							-- Invalid owner: unclaim and reset
							require(script.Parent.NPCUtils).resetNPCOwnership(npc, rootPart)
							humanoid.WalkSpeed = npcType.walkSpeed
							roamTarget = nil
						end
					end

					-- Unowned: move straight to endPoint
					if not npc:GetAttribute("Owned") or npc:GetAttribute("Owner") == "" then
						local distToEnd = (rootPart.Position - endPoint.Position).Magnitude
						if distToEnd < 5 then
							npc:Destroy()
							break
						else
							moveToTarget(endPoint.Position)
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end
