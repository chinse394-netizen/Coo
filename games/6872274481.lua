--- 6872274481.orig.lua	2026-11-11 10:00:33.320940994 -0800
+++ /mnt/user-data/outputs/6872274481.lua	2026-11-11 10:38:33.840314353 -0800
@@ -5956,18 +5956,7 @@
 						end
 						local scale = VelocityPrediction.Value / 100
 						velocity = Vector3.new(velocity.X * scale, velocity.Y, velocity.Z * scale)
-		local profileSamples = plr.Player and profiles[plr.Player] and profiles[plr.Player].samples
 		local isArrow = projmeta.projectile:find('arrow', 1, true) ~= nil
-		if profileSamples and #profileSamples >= 3 and os.clock() - profileSamples[#profileSamples].t < 0.12 then
-			local newest = profileSamples[#profileSamples]
-			local previous = profileSamples[#profileSamples - 1]
-			local older = profileSamples[#profileSamples - 2]
-			local dtNew = math.max(newest.t - previous.t, 0.01)
-			local dtOld = math.max(previous.t - older.t, 0.01)
-			local acceleration = ((newest.v - previous.v) / dtNew + (previous.v - older.v) / dtOld) * 0.5
-			acceleration = Vector3.new(math.clamp(acceleration.X, -120, 120), math.clamp(acceleration.Y, -80, 80), math.clamp(acceleration.Z, -120, 120))
-			velocity += acceleration * math.clamp(getLeadTime(), 0, 0.25)
-		end
 						if isTelepearl then
 							velocity = Vector3.zero
 						end
@@ -24343,6 +24332,8 @@
 	local AnimationTween
 	local Limit
 	local LegitAura
+	local SwingLog
+	local CapToCooldown
 	local Particles, Boxes = {}, {}
 	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
 	local swordEffectFunction, swordEffectController
@@ -24492,11 +24483,60 @@
 				end
 
 				local nextAttack = 0
+				-- Hard floor for the gap between hit events, in seconds. No slider or margin
+				-- setting can send faster than this, so saved settings cannot spam the server.
+				-- 0.2857 is 35 events per 10 seconds.
+				local MIN_SEND_GAP = 0.2857
+				local lastSendTime = 0
+				local pauseWhy = {}
+				-- Counts why swings were skipped, only while Swing log is on.
+				local function noteReason(name)
+					if SwingLog.Enabled then
+						pauseWhy[name] = (pauseWhy[name] or 0) + 1
+					end
+				end
+				-- Swing log stats: events sent, damage seen on the target, and gap sizes.
+				local logStats = {sends = 0, hits = 0, gapSum = 0, maxGap = 0, lastHealth = -1}
+				local lastTargetHealth = {}
+				Killaura:Clean(runService.Heartbeat:Connect(function()
+					if not SwingLog.Enabled then
+						return
+					end
+					local target = store.KillauraTarget
+					local health = target and target.Health
+					if type(health) ~= 'number' then
+						return
+					end
+					local before = lastTargetHealth[target]
+					lastTargetHealth[target] = health
+					logStats.lastHealth = health
+					if before and health < before then
+						logStats.hits += 1
+					end
+				end))
+				task.spawn(function()
+					repeat
+						task.wait(10)
+						if SwingLog.Enabled and logStats.sends > 0 then
+							local message = string.format('10s: sent %d, hits seen %d, target health %d, avg gap %dms, max gap %dms', logStats.sends, logStats.hits, math.floor(logStats.lastHealth), math.floor(logStats.gapSum / math.max(logStats.sends - 1, 1) * 1000), math.floor(logStats.maxGap * 1000))
+							warn('[KillauraV2] ' .. message)
+							notif('KillauraV2', message, 5)
+						end
+						logStats.sends = 0
+						logStats.hits = 0
+						logStats.gapSum = 0
+						logStats.maxGap = 0
+						table.clear(lastTargetHealth)
+					until not Killaura.Enabled
+				end)
 				local lastTool
 				repeat
 					local attacked = {}
 					local ok = pcall(function()
 						local sword, meta = getAttackData()
+						if not sword then
+							noteReason('attackBlocked')
+						end
 						Attacking = false
 						store.KillauraTarget = nil
 						local root = entitylib.isAlive and entitylib.character and entitylib.character.RootPart
@@ -24511,15 +24551,20 @@
 								Sort = sortmethods[Sort.Value]
 							})
 
+							if #plrs == 0 then
+								noteReason('noTargetInRange')
+							end
+
 							if #plrs > 0 and not isFuryPotionInUse() then
 								local handItem = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
 								if lastTool ~= sword.tool or (handItem and handItem.Value ~= sword.tool) then
 									local switched = switchItem(sword.tool, 0.08)
 									lastTool = sword.tool
 									if switched then
-										-- EquipItem is asynchronous.  Give the server one short tick to
-										-- accept the new weapon before sending an attack request.
-										nextAttack = math.max(nextAttack, tick() + 0.08)
+										-- switchItem already waited 0.08s for the server to accept the weapon,
+										-- so only a short extra gap is needed here (was a second 0.08s pause).
+										noteReason('switchedWeapon')
+										nextAttack = math.max(nextAttack, tick() + 0.02)
 									end
 								end
 								local selfpos = root.Position
@@ -24544,17 +24589,31 @@
 									-- advertises. Drawing/target selection may extend farther, but firing
 									-- beyond this point produces a local swing with no server damage.
 									local serverRange = math.min(AttackRange.Value, tonumber(meta.sword.attackRange) or 14.4)
-									if delta.Magnitude > serverRange then continue end
+									if delta.Magnitude > serverRange then
+										noteReason('outOfRange')
+										continue
+									end
 
 									local actualRoot = (v.Character and v.Character.PrimaryPart) or v.RootPart
 									local now = tick()
 									local holdingSword = handItem and handItem.Value == sword.tool
 									local targetAlive = v.Character and v.Character.Parent and entitylib.isVulnerable(v)
 									if actualRoot and holdingSword and targetAlive and now >= nextAttack and not isFuryPotionInUse() then
-										-- Fast cadence; movement handling below keeps strafing from pausing attacks.
-										local weaponInterval = 0.05
-										local attackInterval = math.max(weaponInterval + (HitMargin.Value / 1000), 0.03)
-										nextAttack = now + attackInterval + 0.002
+										-- One hit event per swing, like the real game.
+										-- The gap comes from the Attack attempts slider (36 gives about 35 sends per 10 seconds).
+										local weaponInterval = 10 / math.max(AttackRate.Value, 1)
+										-- Optional cap so swings are never faster than the sword cooldown.
+										if CapToCooldown.Enabled then
+											weaponInterval = math.max(weaponInterval, tonumber(meta.sword.attackSpeed) or 0.3)
+										end
+										local attackInterval = math.max(weaponInterval + (HitMargin.Value / 1000), MIN_SEND_GAP)
+										-- Count from the planned time, so a late frame does not stretch the gap
+										-- and the rate stays steady. After a big hitch (50ms+), restart from now.
+										if now - nextAttack > 0.05 then
+											nextAttack = now + attackInterval
+										else
+											nextAttack = nextAttack + attackInterval
+										end
 										if not Swing.Enabled and not LegitAura.Enabled then
 											bedwars.SwordController:playSwordEffect(meta, false)
 											if type(meta.displayName) == 'string' and meta.displayName:find(' Scythe', 1, true) then
@@ -24589,6 +24648,26 @@
 										if sent then
 											store.attackReach = (delta.Magnitude * 100) // 1 / 100
 											store.attackReachUpdate = tick() + 1
+											if SwingLog.Enabled then
+												local gap = now - lastSendTime
+												logStats.sends += 1
+												if lastSendTime > 0 and gap < 2 then
+													logStats.gapSum += gap
+													logStats.maxGap = math.max(logStats.maxGap, gap)
+												end
+												if lastSendTime > 0 and gap > attackInterval + 0.05 then
+													local reasons = {}
+													for name, count in pauseWhy do
+														table.insert(reasons, name .. '=' .. count)
+													end
+													table.sort(reasons)
+													local message = string.format('gap %dms, wanted %dms, fps %d | %s', math.floor(gap * 1000), math.floor(attackInterval * 1000), math.floor(workspace:GetRealPhysicsFPS()), #reasons > 0 and table.concat(reasons, ' ') or 'no reason found')
+													warn('[KillauraV2] ' .. message)
+													notif('KillauraV2', message, 3)
+												end
+												table.clear(pauseWhy)
+												lastSendTime = now
+											end
 										else
 											-- Do not wait out a full attack interval after a failed remote.
 											nextAttack = now + (1 / math.clamp(UpdateRate.Value, 60, 120))
@@ -24710,7 +24789,7 @@
 		Name = 'Attack attempts per 10s',
 		Min = 20,
 		Max = 600,
-		Default = 35,
+		Default = 36,
 		Suffix = ' hits',
 		Tooltip = 'Speed cap. Your sword cooldown sets the real max.'
 	})
@@ -24922,6 +25001,14 @@
 		Name = 'Swing only',
 		Tooltip = 'Only attacks while swinging manually'
 	})
+	SwingLog = Killaura:CreateToggle({
+		Name = 'Swing log',
+		Tooltip = 'Prints each pause between swings and the likely reason.\nTurn on to debug, then off.'
+	})
+	CapToCooldown = Killaura:CreateToggle({
+		Name = 'Cap to sword cooldown',
+		Tooltip = 'On: never swing faster than the sword cooldown (about 0.3s).\nOff: swing gap comes only from the slider. Faster swings than the cooldown get ignored by the server.'
+	})
 
 	task.defer(function()
 		if not Killaura.Enabled then
