local run = function(func)
	local suc, err = pcall(function()
		if setthreadidentity then setthreadidentity(8) end
		if setidentity then setidentity(8) end
		func()
	end)
	if not suc and err then
		warn('[Vape] Module error: '..tostring(err))
	end
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))

local collectionService = cloneref(game:GetService('CollectionService'))
local proximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local lightingService = cloneref(game:GetService('Lighting'))
local isnetworkowner = identifyexecutor and table.find({'Volcano', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function getFunctionRange(func)
	if not func then return nil end
	local last = false
	for _, v in debug.getconstants(func) do
		if v == 'maxActivationDistance' then
			last = true
		elseif last then
			return v and typeof(v) == 'number' and v or nil
		end
	end
	return nil
end

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function getScaffoldBlockForModule(limitItem)
	if limitItem.Enabled then
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name
		end
		return nil
	else
		local wool = getWool()
		if wool then
			return wool
		else
			for _, item in store.inventory.inventory.items do
				if bedwars.ItemMeta[item.itemType].block then
					return item.itemType
				end
			end
		end
	end
	return nil
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}

local function getBlockDistance(a)
	local pos = (entitylib.isAlive and (entitylib.character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
	return (pos - Vector3.new(a.Position.X, pos.Y, a.Position.Z)).Magnitude
end

local breakmethods = {
	Health = function(a, b)
		return getBlockHits(a, b)
	end,
	Distance = function(a, b)
		return getBlockDistance(a) + getBlockHits(a, b) * 0.01
	end
}
run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()
local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getupvalue, func, index)
    if success then
        return proto
    else
        --warn("function:", func, "index:", index,", WM - proto") 
        return nil
    end
end
run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		SharedConstants = require(replicatedStorage.TS['shared-constants']),		
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = (function()
			local success, result = pcall(function()
				return require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController
			end)
			return success and result or nil
		end)(),
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = safeGetProto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = safeGetProto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = safeGetProto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = safeGetProto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = safeGetProto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = safeGetProto(safeGetProto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = safeGetProto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = safeGetProto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = safeGetProto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = safeGetProto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = safeGetProto(safeGetProto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = safeGetProto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = safeGetProto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = safeGetProto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = safeGetProto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = safeGetProto(Knit.Controllers.ResetController.createBindable, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = safeGetProto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}


	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		if v and type(v) == 'function' then
			local remote = dumpRemote(debug.getconstants(v))
			if remote == '' then
				notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
			end
			remotes[i] = remote
		else
			notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
		end
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		if not remoteName or remoteName == '' then
			return {
				SendToServer = function() end,
				CallServer = function() end,
				CallServerAsync = function() end
			}
		end
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	getBlockHits = function(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function calculatePath(target, blockpos, solidonly, breakmethod)
		local heap = {}
		local function push(cost, node)
			local index = #heap + 1
			heap[index] = {cost, node}

			while index > 1 do
				local parent = index // 2
				if heap[parent][1] <= heap[index][1] then break end
				heap[parent], heap[index] = heap[index], heap[parent]
				index = parent
			end
		end

		local function pop()
			local size = #heap
			if size == 0 then return end
			local root = heap[1]

			heap[1], heap[size], size = heap[size], nil, size - 1
			local index = 1

			while true do
				local left, right, smallest = index * 2, (index * 2) + 1, index
				if left <= size and heap[left][1] < heap[smallest][1] then smallest = left end
				if right <= size and heap[right][1] < heap[smallest][1] then smallest = right end
				if smallest == index then break end

				heap[index], heap[smallest] = heap[smallest], heap[index]
				index = smallest
			end

			return root[1], root[2]
		end

		local visited, distances, exposed, path = {}, {[blockpos] = 0}, {}, {}
		local gaps, sources = {[blockpos] = 0}, {[blockpos] = blockpos}
		push(0, blockpos)

		for _ = 1, 10000 do
			local cost, node = pop()
			if not node then break end
			if visited[node] then continue end
			visited[node] = true
			local current, source = getPlacedBlock(node), sources[node]

			for _, side in sides do
				side = node + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block then
					if current then
						local cells = exposed[node]
						if cells then
							table.insert(cells, side)
						else
							exposed[node] = {side}
						end
					end

					local gap = current and 1 or (gaps[node] + 1)
					if not solidonly and gap <= 2 and (side - blockpos).Magnitude <= 15 and cost < (distances[side] or math.huge) then
						distances[side] = cost
						gaps[side] = gap
						sources[side] = source
						push(cost, side)
					end
					continue
				end

				if block:GetAttribute('NoBreak') or block == target then continue end

				local curdist = cost + (breakmethod or getBlockHits)(block, side)
				if curdist < (distances[side] or math.huge) then
					distances[side] = curdist
					gaps[side] = 0
					sources[side] = side
					path[side] = source
					push(curdist, side)
				end
			end
		end

		local origin = entitylib.character.RootPart.Position
		local candidates = {}
		for node, cells in exposed do
			table.insert(candidates, {distances[node], node, cells})
		end
		table.sort(candidates, function(a, b)
			if a[1] == b[1] then
				return (a[2] - origin).Magnitude < (b[2] - origin).Magnitude
			end
			return a[1] < b[1]
		end)

		local routes = {}
		local function isOpen(cell)
			if routes[cell] ~= nil then
				return routes[cell]
			end
			local queue, seen, open = {cell}, {[cell] = true}, true

			for _ = 1, 400 do
				local current = table.remove(queue)
				if not current then
					open = false
					break
				end
				if (current - blockpos).Magnitude > 15 then break end

				for _, side in sides do
					side = current + side
					if seen[side] or getPlacedBlock(side) then continue end
					seen[side] = true
					table.insert(queue, side)
				end
			end

			for reached in seen do
				routes[reached] = open
			end
			return open
		end

		--[[
			Sampling a line every stud rounds each point to a cell and can report a block
			the line never enters, so the grid is walked one crossing at a time instead.
		]]
		local function boundary(index, component, delta)
			if delta == 0 then
				return 0, math.huge, math.huge
			end
			local step = delta > 0 and 1 or -1
			return step, ((((index + (step * 0.5)) * 3) - component) / delta), (3 / math.abs(delta))
		end

		local sightlines = {}
		local function canSee(cell)
			if sightlines[cell] ~= nil then
				return sightlines[cell]
			end
			local start, direction = bedwars.BlockController:getBlockPosition(origin), cell - origin
			local x, y, z, clear = start.X, start.Y, start.Z, true

			local stepx, nextx, deltax = boundary(x, origin.X, direction.X)
			local stepy, nexty, deltay = boundary(y, origin.Y, direction.Y)
			local stepz, nextz, deltaz = boundary(z, origin.Z, direction.Z)

			for _ = 1, 100 do
				if nextx > 1 and nexty > 1 and nextz > 1 then break end

				if nextx <= nexty and nextx <= nextz then
					x, nextx = x + stepx, nextx + deltax
				elseif nexty <= nextz then
					y, nexty = y + stepy, nexty + deltay
				else
					z, nextz = z + stepz, nextz + deltaz
				end

				if getPlacedBlock(Vector3.new(x, y, z) * 3) then
					clear = false
					break
				end
			end

			sightlines[cell] = clear
			return clear
		end

		local pos, cost = nil, nil
		for _, candidate in candidates do
			if (candidate[2] - origin).Magnitude > 30 then continue end
			local bed = not solidonly and getPlacedBlock(candidate[2]) == target

			for _, cell in candidate[3] do
				if isOpen(cell) and (not bed or canSee(cell)) then
					pos, cost = candidate[2], candidate[1]
					break
				end
			end

			if pos then break end
		end

		if not pos then
			for _, candidate in candidates do
				if solidonly or getPlacedBlock(candidate[2]) ~= target then
					pos, cost = candidate[2], candidate[1]
					break
				end
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end

		return
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, autotool, wallcheck, method)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3, not wallcheck, method or nil)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if autotool then
						local hotbar = getHotbar(tool.tool)
						if hotbar then
							hotbarSwitch(hotbar)
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							if bedwars.BlockBreaker.healthbarMaid then bedwars.BlockBreaker.healthbarMaid:DoCleaning() end
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			local map = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1]
			mapname = map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			store.map = map
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or not bedwars.AppController or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end
run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeIncrease
	local KillauraTarget
	local ClickAim
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and store.hand.toolType == 'sword' and ((not ClickAim.Enabled) or (tick() - bedwars.SwordController.lastSwing) < 0.4) then
						local ent = not KillauraTarget.Enabled and entitylib.EntityPosition({
							Range = Distance.Value,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						}) or store.KillauraTarget
	
						if ent then
							local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local flatDelta = delta * Vector3.new(1, 0, 1)
							if flatDelta.Magnitude <= 0 then return end
							local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
							if angle >= (math.rad(AngleSlider.Value) / 2) then return end
							targetinfo.Targets[ent] = tick() + 1
							gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, ent.RootPart.Position), (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt)
						end
					end
				end))
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffx = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true
	})
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use killaura target'
	})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
end)
	
run(function()
	local old
	
	AutoCharge = vape.Categories.Combat:CreateModule({
	    Name = 'AutoCharge',
	    Function = function(callback)
	        debug.setconstant(bedwars.SwordController.attackEntity, 58, callback and 'damage' or 'multiHitCheckDurationSec')
	        if callback then
	            local chargeSwingTime = 0
	            local canSwing
	
	            old = bedwars.SwordController.sendServerRequest
	            bedwars.SwordController.sendServerRequest = function(self, ...)
	                if (os.clock() - chargeSwingTime) < AutoChargeTime.Value then return end
	                self.lastSwingServerTimeDelta = 0.5
	                chargeSwingTime = os.clock()
	                canSwing = true
	
	                local item = self:getHandItem()
	                if item and item.tool then
	                    self:playSwordEffect(bedwars.ItemMeta[item.tool.Name], false)
	                end
	
	                return old(self, ...)
	            end
	
	            oldSwing = bedwars.SwordController.playSwordEffect
	            bedwars.SwordController.playSwordEffect = function(...)
	                if not canSwing then return end
	                canSwing = false
	                return oldSwing(...)
	            end
	        else
	            if old then
	                bedwars.SwordController.sendServerRequest = old
	                old = nil
	            end
	
	            if oldSwing then
	                bedwars.SwordController.playSwordEffect = oldSwing
	                oldSwing = nil
	            end
	        end
	    end,
	    Tooltip = 'Allows you to get charged hits while spam clicking.'
	})
	AutoChargeTime = AutoCharge:CreateSlider({
	    Name = 'Charge Time',
	    Min = 0,
	    Max = 0.5,
	    Default = 0.4,
	    Decimal = 100
	})
end)
	
run(function()
	local AutoClicker
	local CPS
	local BlockCPS = {}
	local Thread

	local function AutoClick()
		if Thread then
			task.cancel(Thread)
		end

		Thread = task.spawn(function()
			repeat
					if not bedwars.AppController or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					local blockPlacer = bedwars.BlockPlacementController.blockPlacer
					if store.hand.toolType == 'block' and blockPlacer then
						if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
							local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
							if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
								task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
							end
						end
					elseif store.hand.toolType == 'sword' then
						bedwars.SwordController:swingSwordAtMouse(0.39)
					end
				end

				task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
			until not AutoClicker.Enabled
		end)
	end

	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						AutoClick()
					end
				end))

				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end))

				if inputService.TouchEnabled then
					pcall(function()
						AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Down:Connect(AutoClick))
						AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Up:Connect(function()
							if Thread then
								task.cancel(Thread)
								Thread = nil
							end
						end))
					end)
				end
			else
				if Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Default = true,
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
		end
	})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 12,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true
	})
end)
	
run(function()
	local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'NoClickDelay',
		Function = function(callback)
			if callback then
				old = bedwars.SwordController.isClickingTooFast
				bedwars.SwordController.isClickingTooFast = function(self)
					self.lastSwing = os.clock()
					return false
				end
			else
				bedwars.SwordController.isClickingTooFast = old
			end
		end,
		Tooltip = 'Remove the CPS cap'
	})
end)
	
run(function()
	local BlockReach
	local BlockRange
	local BreakReach
	local BreakRange
	local SwordReach
	local SwordRange
	
	local old
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Tooltip = 'Allows you to place, attack, and break further',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
			if callback then
				old = bedwars.BlockSelector.getMouseInfo
				bedwars.BlockSelector.getMouseInfo = function(...)
					local Self, Select, Args = ...
					if not Args then
						Args = {}
					end
					if Select == 0 then
						Args.range = BlockReach.Enabled and BlockRange.Value or 24
					elseif Select == 1 then
						Args.range = BreakReach.Enabled and BreakRange.Value or 18
					end
					return old(Self, Select, Args)
				end
			else
				bedwars.BlockSelector.getMouseInfo = old
				old = nil
			end
		end,
	})
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
			pcall(function()
				SwordRange.Object.Visible = callback
			end)
		end,
		Default = true
	})
	SwordRange = Reach:CreateSlider({
		Name = 'Sword Range',
		Min = 1,
		Max = 18,
		Default = 18,
		Decimal = 5,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Function = function(val)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4
		end
	})
	BlockReach = Reach:CreateToggle({
		Name = 'Placement Reach',
		Function = function(callback)
			BlockRange.Object.Visible = callback
		end
	})
	BlockRange = Reach:CreateSlider({
		Name = 'Placement Range',
		Min = 1,
		Max = 60,
		Default = 18,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Visible = false
	})
	BreakReach = Reach:CreateToggle({
		Name = 'Break Reach',
		Function = function(callback)
			BreakRange.Object.Visible = callback
		end
	})
	BreakRange = Reach:CreateSlider({
		Name = 'Break Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 5,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Visible = false
	})
	Reach:CreateButton({
		Name = 'Reset to default reach',
		Tooltip = 'Resets every range back to default',
		Function = function()
			BreakRange:SetValue(18)
			BlockRange:SetValue(24)
			SwordRange:SetValue(12.4)
		end
	})
end)

run(function()
    local ShopQuickBuy -- coded by seven
    local HoldDelay
    local CPS
    
    local holding = false
    local clickThread
    
    local function getShopId()
        if not entitylib.isAlive then return nil end
        local localPosition = entitylib.character.RootPart.Position
        local id
        for _, v in store.shop do
            if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
                id = v.Id
            end
        end
        return id
    end
    
    local function getHoveredItem()
        local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
        for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
            local obj = v
            while obj and obj ~= lplr.PlayerGui do
                local itemType = obj.Name:match('^(.+)_ShopItemCard$')
                if itemType then
                    return itemType
                end
                obj = obj.Parent
            end
        end
    end
    
    local function canBuy(item)
        if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
        if item.lockedByForge or item.disabled then return false end
        if item.require and item.require.teamUpgrade then
            if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
                return false
            end
        end
        local currency = getItem(item.currency)
        return (currency and currency.amount or 0) >= item.price
    end
    
    local function purchase(itemType, shopId)
        if bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] ~= nil then return end
    
        local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
        if not item or not canBuy(item) then return end
    
        bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
            shopItem = item,
            shopId = shopId
        }):andThen(function(suc)
            if not suc then return end
            bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
            bedwars.Store:dispatch({
                type = 'BedwarsAddItemPurchased',
                itemType = itemType
            })
            if item.tiered then
                bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
            end
        end)
    end
    
    local function startClicking(itemType)
        if clickThread then
            task.cancel(clickThread)
        end
        clickThread = task.spawn(function()
            repeat
	                local shopId = bedwars.AppController and bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
                if shopId then
                    purchase(itemType, shopId)
                end
                task.wait(1 / CPS.Value)
            until not holding
            clickThread = nil
        end)
    end
    
    ShopQuickBuy = vape.Categories.Combat:CreateModule({
        Name = 'Shop Clicker',
        Function = function(callback)
            if callback then
                ShopQuickBuy:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	                    if not bedwars.AppController or not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end
    
                    local itemType = getHoveredItem()
                    if not itemType then return end
    
                    holding = true
                    task.delay(HoldDelay.Value, function()
                        if holding and getHoveredItem() == itemType then
                            startClicking(itemType)
                        end
                    end)
                end))
    
                ShopQuickBuy:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        holding = false
                    end
                end))
            else
                holding = false
                if clickThread then
                    task.cancel(clickThread)
                    clickThread = nil
                end
            end
        end,
        Tooltip = 'Hold on a shop item to rapidly buy it.'
    })
    HoldDelay = ShopQuickBuy:CreateSlider({
        Name = 'Hold Delay',
        Min = 0,
        Max = 1,
        Default = 0.15,
        Decimal = 20,
        Suffix = 'seconds'
    })
    CPS = ShopQuickBuy:CreateSlider({
        Name = 'CPS',
        Min = 1,
        Max = 20,
        Default = 20,
        Darker = true
    })
end)

				run(function()
					local SilentAura
					local ExtendedRange
					local ExtendedRangeSlider
					local WallCheck
					local TargetMode
					local Prediction
					local HitRate
					local MaxAngle
					local silentAttackRemote
					local lastHitTime = 0
					local loopToken = 0
					local BASE_RANGE = 13.8
				
					task.spawn(function()
						silentAttackRemote = bedwars.Client:Get(remotes.AttackEntity)
					end)
				
					local _saT4HitCount = {}
					local _saT4HitTick = {}
				
					local function fireSilentAttack(attackData)
						if not silentAttackRemote then return end
						local _atkPlr = playersService:GetPlayerFromCharacter(attackData.entityInstance)
						if _atkPlr then
							local targetTier = getAccountTier(_atkPlr)
							if targetTier >= 99 then return end
							if targetTier >= 4 and getAccountTier(lplr) == 0 then
								local uid = _atkPlr.UserId
								local now = tick()
								if not _saT4HitTick[uid] or now - _saT4HitTick[uid] >= 10 then
									_saT4HitTick[uid] = now
									_saT4HitCount[uid] = 0
								end
								_saT4HitCount[uid] = (_saT4HitCount[uid] or 0) + 1
								if _saT4HitCount[uid] > 32 then return end
							end
							if not select(2, whitelist:get(_atkPlr)) then return end
						end
						local selfpos = attackData.validate.selfPosition.value
						local targetpos = attackData.validate.targetPosition.value
						local actualDistance = (selfpos - targetpos).Magnitude
						if actualDistance > 14.4 and actualDistance <= 30 then
							local direction = (targetpos - selfpos).Unit
							local moveDistance = math.min(actualDistance - 14.3, 8)
							attackData.validate.selfPosition.value = selfpos + (direction * moveDistance)
							local pullDistance = math.min(actualDistance - 14.3, 4)
							attackData.validate.targetPosition.value = targetpos - (direction * pullDistance)
							attackData.validate.raycast = attackData.validate.raycast or {}
							attackData.validate.raycast.cameraPosition = attackData.validate.raycast.cameraPosition or {}
							attackData.validate.raycast.cursorDirection = attackData.validate.raycast.cursorDirection or {}
							local extendedOrigin = selfpos + (direction * math.min(actualDistance - 12, 15))
							attackData.validate.raycast.cameraPosition.value = extendedOrigin
							attackData.validate.raycast.cursorDirection.value = direction
						end
						return silentAttackRemote:SendToServer(attackData)
					end
				
					local function getMaxRange()
						local base = BASE_RANGE
						if ExtendedRange and ExtendedRange.Enabled and ExtendedRangeSlider then
							base = base + ExtendedRangeSlider.Value
						end
						return base
					end
				
					local function canHitWithHitreg()
						local currentTime = tick()
						local hitreg = (HitRate and HitRate.Value or 34) + (math.random(-3, 3) / 10)
						local delayBetweenHits = 10 / math.max(hitreg, 1)
						if currentTime - lastHitTime >= delayBetweenHits then
							lastHitTime = currentTime
							return true
						end
						return false
					end
				
					local function getSilentTargetPosition(ent, dist)
						local root = ent.RootPart
						local targetPos = root.Position
						local velocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.zero
						local predictionAmount = Prediction and Prediction.Value or 0
				
						if predictionAmount > 0 then
							targetPos += velocity * math.clamp((dist / 55) * predictionAmount, 0, 0.18)
						end
				
						return targetPos
					end
				
					local function gatherSilentTargets(selfpos, maxRange)
						local targets = {}
						local allEnts = entitylib.List
						for i = 1, #allEnts do
							local ent = allEnts[i]
							if not ent.RootPart then continue end
							if not ent.Targetable then continue end
							if not ent.Health or ent.Health <= 0 then continue end
							local dist = (ent.RootPart.Position - selfpos).Magnitude
							if dist <= maxRange then
								if WallCheck and WallCheck.Enabled and entitylib.Wallcheck(selfpos, ent.RootPart.Position, true) then continue end
								
								-- Angle check
								if MaxAngle and MaxAngle.Value < 360 then
									local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
									local delta = (ent.RootPart.Position - selfpos)
									local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
									if angle > (math.rad(MaxAngle.Value) / 2) then continue end
								end
								
								local health = ent.Health or 100
								local velocity = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity or Vector3.zero
								table.insert(targets, {
									ent = ent,
									dist = dist,
									health = health,
									score = (dist * 1.35) + (health * 0.18) + math.min(velocity.Magnitude, 28) * 0.08
								})
							end
						end
						table.sort(targets, function(a, b)
							local mode = TargetMode and TargetMode.Value or 'Smart'
							if mode == 'Health' then
								return a.health == b.health and a.dist < b.dist or a.health < b.health
							end
							if mode == 'Distance' then
								return a.dist < b.dist
							end
							return a.score < b.score
						end)
						return targets
					end
				
					local function cleanupSilentAura()
						loopToken += 1
						lastHitTime = 0
						store.KillauraTarget = nil
						pcall(function()
							if bedwars.SwordController then
								bedwars.SwordController.disableSwingState = false
								bedwars.SwordController.lastAttack = 0
							end
						end)
					end
				
					SilentAura = vape.Categories.Combat:CreateModule({
						Name = 'SilentAura',
						Function = function(callback)
							cleanupSilentAura()
							if not callback then return end
							local activeToken = loopToken
							task.spawn(function()
								repeat
									task.wait(1 / 60)
									if not SilentAura.Enabled then break end
									if activeToken ~= loopToken then break end
				
									if (tick() - bedwars.SwordController.lastSwing) > 0.2 then continue end
				
									local ok, open = pcall(function() return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) end)
									if ok and open then continue end
				
									if tick() - store.silasAbilityTime < 2.2 then continue end
									if tick() - store.terraStompTime < 0.7 then continue end
									if tick() - store.terraKickTime < 0.5 then continue end
				
									if store.hand.toolType ~= 'sword' then continue end
									if bedwars.DaoController and bedwars.DaoController.chargingMaid then continue end
				
									local sword = store.hand
									if not sword or not sword.tool then continue end
									local meta = bedwars.ItemMeta[sword.tool.Name]
									if not meta or not meta.sword then continue end
				
									if not entitylib.isAlive then continue end
									local selfpos = entitylib.character.RootPart.Position
				
									local maxRange = getMaxRange()
									local targets = gatherSilentTargets(selfpos, maxRange)
									if #targets == 0 then continue end
				
									if not canHitWithHitreg() then continue end
				
									local ent = targets[1].ent
									if not ent.RootPart then continue end
				
									local targetPos = getSilentTargetPosition(ent, targets[1].dist)
									local camPos = gameCamera.CFrame.Position
									local dir = (targetPos - camPos).Unit
				
									fireSilentAttack({
										weapon = sword.tool,
										entityInstance = ent.Character,
										chargedAttack = {chargeRatio = 0},
										validate = {
											raycast = {
												cameraPosition = {value = camPos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = targetPos},
											selfPosition = {value = selfpos}
										}
									})
								until not SilentAura.Enabled or activeToken ~= loopToken
							end)
						end
					})
				
					WallCheck = SilentAura:CreateToggle({
						Name = 'Wall Check',
						Tooltip = 'Stops SilentAura from attacking targets behind walls.'
					})
				
					TargetMode = SilentAura:CreateDropdown({
						Name = 'Target Mode',
						List = {'Smart', 'Distance', 'Health'},
						Tooltip = 'Smart balances distance, health and movement speed.'
					})
				
					Prediction = SilentAura:CreateSlider({
						Name = 'Prediction',
						Min = 0,
						Max = 1,
						Default = 0.35,
						Decimal = 100,
						Suffix = 'x'
					})
				
					HitRate = SilentAura:CreateSlider({
						Name = 'Hit Rate',
						Min = 28,
						Max = 38,
						Default = 34,
						Decimal = 10,
						Suffix = 'hz'
					})
				
					ExtendedRange = SilentAura:CreateToggle({
						Name = 'Extended Range',
						Function = function(callback)
							if ExtendedRangeSlider then
								ExtendedRangeSlider.Object.Visible = callback
							end
						end
					})
				
					ExtendedRangeSlider = SilentAura:CreateSlider({
						Name = 'Extend Range',
						Min = 1,
						Max = 3,
						Default = 1,
						Darker = true,
						Visible = false,
						Suffix = function(val)
							return val == 1 and 'stud' or 'studs'
						end
					})
				
					MaxAngle = SilentAura:CreateSlider({
						Name = 'Max Angle',
						Min = 1,
						Max = 360,
						Default = 360,
						Tooltip = 'Maximum angle to attack targets. 360 = all directions.'
					})
				end)
										
run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end) 
				end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
run(function()
	local TriggerBot
	local CPS
	local rayParams = RaycastParams.new()
	local BowCheck
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local doAttack
				if not bedwars.AppController or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
							rayParams.FilterDescendantsInstances = {lplr.Character}
	
							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								local limit = (attackRange)
								for _, ent in entitylib.List do
									doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end
	
							doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						end
						if BowCheck.Enabled then
							if store.hand.toolType == 'bow'  then
								local attackRange = 23
								rayParams.FilterDescendantsInstances = {lplr.Character}
		
								local unit = lplr:GetMouse().UnitRay
								local localPos = entitylib.character.RootPart.Position
								local rayRange = (attackRange)
								local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
								if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
									local limit = (attackRange)
									for _, ent in entitylib.List do
										doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
										if doAttack then
											break
										end
									end
								end
		
								doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
								if doAttack then
									mouse1click()
								end
							end
						end
					end
	
					task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	BowCheck = TriggerBot:CreateToggle({Name='Bow Check'})
end)
	
run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})
	
					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end
					
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
	
local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getLowGround()
		local mag = math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				local pos, debounce = getLowGround(), tick()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Material = Enum.Material[Material.Value]
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							debounce = tick() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if vape.Modules.Fly.Enabled or vape.Modules.InfiniteFly.Enabled or vape.Modules.LongJump.Enabled then
											connection:Disconnect()
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = Vector3.new(top.X, pos.Y, top.Z)
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
	Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)
	
run(function()
	local FastBreak
	local Time
	
	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				repeat
					bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
					task.wait(0.1)
				until not FastBreak.Enabled
			else
				bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)
	
local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				local tpTick, tpToggle, oldy = tick(), true

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end
				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
						local mass = (1.5 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						if not flyAllowed then
							if tpToggle then
								local airleft = (tick() - entitylib.character.AirTime)
								if airleft > 2 then
									if not oldy then
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
										if ray and TP.Enabled then
											tpToggle = false
											oldy = root.Position.Y
											tpTick = tick() + 0.11
											root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
										end
									end
								end
							else
								if oldy then
									if tpTick < tick() then
										local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
										root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
										tpToggle = true
										oldy = nil
									else
										mass = 0
									end
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))
				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
	})
end)
	
run(function()
	local Mode
	local Expand
	local objects, set = {}
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, ent in entitylib.List do
						createHitbox(ent)
					end
				end
			else
				if set then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
					set = nil
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 14.4,
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
				else
					for _, part in objects do
						part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)
	
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AttackRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local swordEffectFunction, swordEffectController
	local scytheAnimationFunction, scytheAnimationController
	local animationHooksInstalled = false
	local ATTACKS_PER_TEN_SECONDS = 35
	local AttackRemote = {FireServer = function() end}
	local nextRemoteRefresh = 0
	local function getAttackRemote()
		-- The game's remote can be replaced after a respawn or a controller reload.
		-- Keep the last known-good instance, but refresh it periodically so one stale
		-- reference cannot make the aura appear to stop.
		if tick() >= nextRemoteRefresh then
			nextRemoteRefresh = tick() + 2
			local ok, remote = pcall(function()
				return bedwars.Client:Get(remotes.AttackEntity).instance
			end)
			if ok and remote then
				AttackRemote = remote
			end
		end
		return AttackRemote
	end
	task.spawn(function()
		getAttackRemote()
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta or not meta.sword then return false end

		if Limit.Enabled then
			if not store.hand or store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					-- Save the live controller upvalues.  Restoring to bedwars.Knit is not
					-- reliable: the game can use a different controller after an update.
					swordEffectFunction = oldSwing or bedwars.SwordController.playSwordEffect
					scytheAnimationFunction = bedwars.ScytheController.playLocalAnimation
					local _, currentSwordEffectController = debug.getupvalue(swordEffectFunction, 6)
					local _, currentScytheAnimationController = debug.getupvalue(scytheAnimationFunction, 3)
					swordEffectController = currentSwordEffectController
					scytheAnimationController = currentScytheAnimationController
					debug.setupvalue(swordEffectFunction, 6, fake)
					debug.setupvalue(scytheAnimationFunction, 3, fake)
					animationHooksInstalled = true

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				-- Schedule attack attempts independently from target scanning.  This keeps
				-- the requested rate stable instead of letting frame/update timing drift it.
				local nextAttack = tick()
				repeat
					local attacked = {}
					local ok = pcall(function()
						local sword, meta = getAttackData()
						Attacking = false
						store.KillauraTarget = nil
						local root = entitylib.isAlive and entitylib.character and entitylib.character.RootPart
						if sword and root then
							local plrs = entitylib.AllPosition({
								Range = SwingRange.Value,
								Wallcheck = Targets.Walls.Enabled or nil,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Limit = MaxTargets.Value,
								Sort = sortmethods[Sort.Value]
							})

							if #plrs > 0 then
								switchItem(sword.tool, 0)
								local selfpos = root.Position
								local flatFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
								-- Looking up/down shortens the projected look vector.  Normalizing it
								-- avoids falsely failing the angle check and dropping nearby targets.
								local localfacing = flatFacing.Magnitude > 0 and flatFacing.Unit or nil

								for _, v in plrs do
									if not Killaura.Enabled then break end
									if not v.RootPart then continue end
									local delta = (v.RootPart.Position - selfpos)
									local flatDelta = delta * Vector3.new(1, 0, 1)
									if flatDelta.Magnitude <= 0 then continue end
									local angle = localfacing and math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1)) or 0
									if angle > (math.rad(AngleSlider.Value) / 2) then continue end

									table.insert(attacked, {
										Entity = v,
										Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
									})
									targetinfo.Targets[v] = tick() + 1

									if not Attacking then
										Attacking = true
										store.KillauraTarget = v
										if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + 10 / ATTACKS_PER_TEN_SECONDS
											bedwars.SwordController:playSwordEffect(meta, false)
											if meta.displayName:find(' Scythe') then
												bedwars.ScytheController:playLocalAnimation()
											end

											if vape.ThreadFix then
												setthreadidentity(8)
											end
										end
									end

									if delta.Magnitude > AttackRange.Value then continue end

									local actualRoot = (v.Character and v.Character.PrimaryPart) or v.RootPart
									local now = tick()
									if actualRoot and now >= nextAttack then
										local attackInterval = 10 / ATTACKS_PER_TEN_SECONDS
										nextAttack = now + attackInterval
										local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
										local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
										bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
										store.attackReach = (delta.Magnitude * 100) // 1 / 100
										store.attackReachUpdate = tick() + 1

										local remote = getAttackRemote()
										remote:FireServer({
											weapon = sword.tool,
											chargedAttack = {chargeRatio = 0},
											entityInstance = v.Character,
											validate = {
												raycast = {
													cameraPosition = {value = pos},
													cursorDirection = {value = dir}
												},
												targetPosition = {value = actualRoot.Position},
												selfPosition = {value = pos}
											}
										})
									end
								end
							end
						end

						for i, v in Boxes do
							v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
							if v.Adornee then
								v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
								v.Transparency = 1 - attacked[i].Check.Opacity
							end
						end

						for i, v in Particles do
							local rootPart = attacked[i] and attacked[i].Entity.RootPart
							v.Position = rootPart and rootPart.Position or Vector3.new(9e9, 9e9, 9e9)
							v.Parent = rootPart and gameCamera or nil
						end

						local faceRoot = attacked[1] and attacked[1].Entity.RootPart
						if Face.Enabled and faceRoot and root then
							local vec = faceRoot.Position * Vector3.new(1, 0, 1)
							root.CFrame = CFrame.lookAt(root.Position, Vector3.new(vec.X, root.Position.Y + 0.001, vec.Z))
						end
					end)
					if not ok then
						Attacking = false
						store.KillauraTarget = nil
					end

					-- Keep the attack loop at the selected cadence even while targets are
					-- present.  The old target-count delay could override Update rate and
					-- leave sword swings waiting long enough to be dropped.
					task.wait(1 / math.clamp(UpdateRate.Value, 1, 120))
				until not Killaura.Enabled
			else
				-- Stop the running attack/animation tasks before restoring normal input.
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				if animationHooksInstalled and swordEffectFunction then
					debug.setupvalue(swordEffectFunction, 6, swordEffectController)
				end
				if animationHooksInstalled and scytheAnimationFunction then
					debug.setupvalue(scytheAnimationFunction, 3, scytheAnimationController)
				end
				swordEffectFunction, swordEffectController = nil, nil
				scytheAnimationFunction, scytheAnimationController = nil, nil
				animationHooksInstalled = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	AttackRate = Killaura:CreateSlider({
		Name = 'Attack attempts per 10s',
		Min = 35,
		Max = 35,
		Default = 35,
		Suffix = ' hits'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)  

																																				
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local swordEffectFunction, swordEffectController
	local scytheAnimationFunction, scytheAnimationController
	local animationHooksInstalled = false
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta or not meta.sword then return false end

		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'KillauraOLD',
		Function = function(callback)
			if callback then
				local nextServerAttack = 0
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					-- Save the live controller upvalues.  Restoring to bedwars.Knit is not
					-- reliable: the game can use a different controller after an update.
					swordEffectFunction = oldSwing or bedwars.SwordController.playSwordEffect
					scytheAnimationFunction = bedwars.ScytheController.playLocalAnimation
					local _, currentSwordEffectController = debug.getupvalue(swordEffectFunction, 6)
					local _, currentScytheAnimationController = debug.getupvalue(scytheAnimationFunction, 3)
					swordEffectController = currentSwordEffectController
					scytheAnimationController = currentScytheAnimationController
					debug.setupvalue(swordEffectFunction, 6, fake)
					debug.setupvalue(scytheAnimationFunction, 3, fake)
					animationHooksInstalled = true

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								if not Killaura.Enabled then break end
								local delta = (v.RootPart.Position - selfpos)
								local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										-- This affects only the local visual effect.  Keep it at the
										-- normal 34-per-10-second cadence so it cannot burst/double.
										local swingDelay = math.max(
											meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0,
											10 / 34
										)
										AnimDelay = tick() + swingDelay
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end

								local actualRoot = v.Character and v.Character.PrimaryPart
								local now = tick()
								local attackCooldown = math.max(tonumber(meta.sword.attackSpeed) or 0, 10 / 34)
								if actualRoot and now >= nextServerAttack then
									nextServerAttack = now + attackCooldown
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait(1 / math.clamp(UpdateRate.Value, 1, 120))
				until not Killaura.Enabled
			else
				-- Stop the running attack/animation tasks before restoring normal input.
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				if animationHooksInstalled and swordEffectFunction then
					pcall(debug.setupvalue, swordEffectFunction, 6, swordEffectController)
				end
				if animationHooksInstalled and scytheAnimationFunction then
					pcall(debug.setupvalue, scytheAnimationFunction, 3, scytheAnimationController)
				end
				swordEffectFunction, swordEffectController = nil, nil
				scytheAnimationFunction, scytheAnimationController = nil, nil
				animationHooksInstalled = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)
																																													
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local swordEffectFunction, swordEffectController
	local scytheAnimationFunction, scytheAnimationController
	local animationHooksInstalled = false
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta or not meta.sword then return false end

		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'KillauraDEBUG',
		Function = function(callback)
			if callback then
				local nextServerAttack = 0
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					-- Save the live controller upvalues.  Restoring to bedwars.Knit is not
					-- reliable: the game can use a different controller after an update.
					swordEffectFunction = oldSwing or bedwars.SwordController.playSwordEffect
					scytheAnimationFunction = bedwars.ScytheController.playLocalAnimation
					local _, currentSwordEffectController = debug.getupvalue(swordEffectFunction, 6)
					local _, currentScytheAnimationController = debug.getupvalue(scytheAnimationFunction, 3)
					swordEffectController = currentSwordEffectController
					scytheAnimationController = currentScytheAnimationController
					debug.setupvalue(swordEffectFunction, 6, fake)
					debug.setupvalue(scytheAnimationFunction, 3, fake)
					animationHooksInstalled = true

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								if not Killaura.Enabled then break end
								local delta = (v.RootPart.Position - selfpos)
								local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										-- This affects only the local visual effect.  Keep it at the
										-- normal 34-per-10-second cadence so it cannot burst/double.
										local swingDelay = math.max(
											meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0,
											10 / 34
										)
										AnimDelay = tick() + swingDelay
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end

								local actualRoot = v.Character and v.Character.PrimaryPart
								local now = tick()
								local attackCooldown = math.max(
									tonumber(meta.sword.attackSpeed) or 0,
									1 / math.clamp(UpdateRate.Value, 1, 120)
								)
								if actualRoot and now >= nextServerAttack then
									nextServerAttack = now + attackCooldown
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait(1 / math.clamp(UpdateRate.Value, 1, 120))
				until not Killaura.Enabled
			else
				-- Stop the running attack/animation tasks before restoring normal input.
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				if animationHooksInstalled and swordEffectFunction then
					pcall(debug.setupvalue, swordEffectFunction, 6, swordEffectController)
				end
				if animationHooksInstalled and scytheAnimationFunction then
					pcall(debug.setupvalue, scytheAnimationFunction, 3, scytheAnimationController)
				end
				swordEffectFunction, swordEffectController = nil, nil
				scytheAnimationFunction, scytheAnimationController = nil, nil
				animationHooksInstalled = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)

run(function()
	local Value
	local CameraDir
	local start
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function launchProjectile(item, pos, proj, speed, dir)
		if not pos then return end
	
		pos = pos - dir * 0.1
		local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
		switchItem(item.tool, 0)
		task.wait(0.1)
		bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
		if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
			local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
			if shoot then
				bedwars.SoundManager:playSound(shoot)
			end
		end
	end
	
	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
	
			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
						switchItem(tool.tool)
					end
	
					bedwars.Client:Get(remotes.CannonAim):SendToServer({
						cannonBlockPos = blockpos,
						lookVector = dir
					})
	
					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end
	
					task.delay(broken, function()
						for _ = 1, 3 do
							local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								JumpSpeed = 5.25 * Value.Value
								JumpTick = tick() + 2.3
								Direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				JumpSpeed = 4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.Velocity = Vector3.zero
			end))
	
			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, pos, dir)
			launchProjectile(item, pos, 'fireball', 60, dir)
		end,
		grappling_hook = function(item, pos, dir)
			launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
		end,
		jade_hammer = function(item, _, dir)
			if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
				bedwars.AbilityController:useAbility(item.itemType..'_jump')
				JumpSpeed = 1.4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,
		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
			end
	
			if LongJump.Enabled then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				JumpSpeed = 4.5 * Value.Value
				JumpTick = tick() + 2.4
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end
	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1
	
						if knockbackBoost >= JumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
							if not pos then return end
							local vec = (entitylib.character.RootPart.Position - pos)
							JumpSpeed = knockbackBoost
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))
				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						JumpSpeed = 2.5 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))
	
				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
	
					if root and isnetworkowner(root) then
						if JumpTick > tick() then
							root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
							if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
							else
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
							end
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							JumpSpeed = 0
						end
					else
						start = nil
					end
				end))
	
				if store.hand and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end
	
				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)
	
run(function()
    local NoFall

    NoFall = vape.Categories.Blatant:CreateModule({
        Name = 'Render NoFall',
        Function = function(callback)
            if callback then
                NoFall:Clean(runService.Heartbeat:Connect(function(dt)
                    if entitylib.isAlive and bedwars.Knit.Controllers.MatchController:getMatchState() == 1 then
                        local root = entitylib.character.RootPart
                        local v = root.Velocity

                        if root.Velocity.Y < -35 and not vape.Modules.Fly.Enabled then
                            root.Velocity = Vector3.new(0,2.5,0)
                            entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                            runService.PreRender:Wait()
                            root.Velocity = v
                        end
                    end
                end))

                NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(char)
                    local animator = char.Humanoid:WaitForChild('Animator', 1)
                    if animator and NoFall.Enabled and not vape.Modules.Fly.Enabled then
                        task.wait(.5)
                        NoFall:Toggle()
                        NoFall:Toggle()
                    end
                end))
            end
        end,
        Tooltip = 'Take no fall damage.'
    })
end)

run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if tab.moveSpeedMultiplier then
						tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
					end
					return old(self, tab)
				end
	
				for i in modifier.modifiers do
					if (i.moveSpeedMultiplier or 1) < 1 then
						modifier:removeModifier(i)
					end
				end
			else
				modifier.addModifier = old
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AttackRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local swordEffectFunction, swordEffectController
	local scytheAnimationFunction, scytheAnimationController
	local animationHooksInstalled = false
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta or not meta.sword then return false end

		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'KillauraOLD',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					-- Save the live controller upvalues.  Restoring to bedwars.Knit is not
					-- reliable: the game can use a different controller after an update.
					swordEffectFunction = oldSwing or bedwars.SwordController.playSwordEffect
					scytheAnimationFunction = bedwars.ScytheController.playLocalAnimation
					local _, currentSwordEffectController = debug.getupvalue(swordEffectFunction, 6)
					local _, currentScytheAnimationController = debug.getupvalue(scytheAnimationFunction, 3)
					swordEffectController = currentSwordEffectController
					scytheAnimationController = currentScytheAnimationController
					debug.setupvalue(swordEffectFunction, 6, fake)
					debug.setupvalue(scytheAnimationFunction, 3, fake)
					animationHooksInstalled = true

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				-- Preserve OLD's hit validation, but serialize its remote requests.  The
				-- previous loop fired once for every valid target during a scan, causing
				-- bursts that eventually tripped the server rate limit.
				local nextAttackRequest = 0
				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								if not Killaura.Enabled then break end
								local delta = (v.RootPart.Position - selfpos)
								local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										-- This affects only the local visual effect.  Keep it at the
										-- normal 34-per-10-second cadence so it cannot burst/double.
										local swingDelay = math.max(
											meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0,
											10 / 34
										)
										AnimDelay = tick() + swingDelay
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end

								local actualRoot = v.Character and v.Character.PrimaryPart
								local now = tick()
								if actualRoot and now >= nextAttackRequest then
									local requestInterval = math.max(
										meta.sword and meta.sword.attackSpeed or 0,
										10 / AttackRate.Value
									)
									nextAttackRequest = now + requestInterval
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					-- Target scans must not slow down with multiple players; the shared
					-- request timer above is the only attack-rate limiter.
					task.wait(1 / math.clamp(UpdateRate.Value, 1, 120))
				until not Killaura.Enabled
			else
				-- Stop the running attack/animation tasks before restoring normal input.
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				if animationHooksInstalled and swordEffectFunction then
					pcall(debug.setupvalue, swordEffectFunction, 6, swordEffectController)
				end
				if animationHooksInstalled and scytheAnimationFunction then
					pcall(debug.setupvalue, scytheAnimationFunction, 3, scytheAnimationController)
				end
				swordEffectFunction, swordEffectController = nil, nil
				scytheAnimationFunction, scytheAnimationController = nil, nil
				animationHooksInstalled = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	AttackRate = Killaura:CreateSlider({
		Name = 'Attack attempts per 10s',
		Min = 1,
		Max = 35,
		Default = 34,
		Suffix = ' hits',
		Tooltip = 'Shared request cap. 34 is the safer default; 35 is available for testing.'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)
run(function()
	local TargetPart
	local Targets
	local FOV
	local OtherProjectiles
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	local old
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					})
	
					if plr then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							return old(...)
						end
	
						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
							return old(...)
						end
	
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity
	
						if balloons and balloons > 0 then
							playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
						end
	
						if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end
	
						if plr.Player:GetAttribute('IsOwlTarget') then
							for _, owl in collectionService:GetTagged('Owl') do
								if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
									playerGravity = 0
								end
							end
						end
	
						local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
						local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
						if calc then
							targetinfo.Targets[plr] = tick() + 1
							return {
								initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
								positionFrom = offsetpos,
								deltaT = lifetime,
								gravitationalAcceleration = gravity,
								drawDurationSeconds = 5
							}
						end
					end
	
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
end)


	
run(function()
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = cloneRaycast()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback or nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
					if entitylib.isAlive then
						if not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) then
							bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or Value.Value)
							if Mode.Value == 'CFrame' then
								local state = entitylib.character.Humanoid:GetState()
								if state == Enum.HumanoidStateType.Climbing then return end
			
								local root, velo = entitylib.character.RootPart, getSpeed()
								local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
								local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
			
								if WallCheck.Enabled then
									rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
									rayCheck.CollisionGroup = root.CollisionGroup
									local ray = workspace:Raycast(root.Position, destination, rayCheck)
									if ray then
										destination = ((ray.Position + ray.Normal) - root.Position)
									end
								end
			
								root.CFrame += destination
								root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
								if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
							end
						end
					end
				end))
			else
				bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Method',
		List = {'Bedwars', 'CFrame'},
		Default = 'CFrame'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)
	
run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)
	
run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
					label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				end))
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
	local KitESP
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'wild_flower'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'}
	}
	
	local function Added(v, icon)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local function addKit(tag, icon)
		KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			Added(v.PrimaryPart, icon)
		end))
		KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end))
		for _, v in collectionService:GetTagged(tag) do
			Added(v.PrimaryPart, icon)
		end
	end
	
	KitESP = vape.Categories.Render:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
				local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
				if kit then
					addKit(kit[1], kit[2])
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = KitESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Rank
	local Enchant
	local Equipment
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = Instance.new('TextLabel')
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			if Equipment.Enabled then
				for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end
	
			task.spawn(function()
				if Rank.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'RankIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(size.X + 10, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image or ''
					Icon.Parent = nametag
				end
			end)
	
			task.spawn(function()
				if Enchant.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'EnchantIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-30, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.enchants[ent.Player]:async() or ''
					Icon.Parent = nametag
				end
			end)
	
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				if Equipment.Enabled and store.inventories[ent.Player] then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local inventory = store.inventories[ent.Player]
					nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
					nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
					nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
					nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
					nametag.Kit.Image = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit].renderImage or ''
				end
				
				if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then
					nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or ''
				end
	
				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string.format(Strings[ent], mag)
						local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string.format(Strings[ent], mag)
						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Enchant = NameTags:CreateToggle({
		Name = 'Show Enchant',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Rank = NameTags:CreateToggle({
		Name = 'Show Rank',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Rank
	local Enchant
	local Equipment
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	-- BedWars may leave a defeated character tagged as an entity for a short time.
	-- Do not keep rendering its last screen position while we wait for EntityRemoved.
	local function isNametagActive(ent)
		return ent
			and ent.Character and ent.Character.Parent
			and ent.RootPart and ent.RootPart.Parent
			and (ent.Health == nil or ent.Health > 0)
	end
	
	local Added = {
		Normal = function(ent)
			if not isNametagActive(ent) then return end
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = Instance.new('TextLabel')
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			if Equipment.Enabled then
				for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end
	
			task.spawn(function()
				if Rank.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'RankIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(size.X + 10, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image or ''
					Icon.Parent = nametag
				end
			end)
	
			task.spawn(function()
				if Enchant.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'EnchantIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-30, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.enchants[ent.Player]:async() or ''
					Icon.Parent = nametag
				end
			end)
	
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not isNametagActive(ent) then return end
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if not nametag and isNametagActive(ent) then
				Added.Normal(ent)
				nametag = Reference[ent]
			end
			if nametag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				if Equipment.Enabled and store.inventories[ent.Player] then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local inventory = store.inventories[ent.Player]
					nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
					nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
					nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
					nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
					nametag.Kit.Image = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit].renderImage or ''
				end
				
				if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then
					nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or ''
				end
	
				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if not nametag and isNametagActive(ent) then
				Added.Drawing(ent)
				nametag = Reference[ent]
			end
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			for ent, nametag in Reference do
				if not isNametagActive(ent) then
					Removed.Normal(ent)
					continue
				end
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string.format(Strings[ent], mag)
						local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, nametag in Reference do
				if not isNametagActive(ent) then
					Removed.Drawing(ent)
					continue
				end
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string.format(Strings[ent], mag)
						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTagsTestNew',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Enchant = NameTags:CreateToggle({
		Name = 'Show Enchant',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Rank = NameTags:CreateToggle({
		Name = 'Show Rank',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)


run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function nearStorageItem(item)
		for _, v in List.ListEnabled do
			if item:find(v) then return v end
		end
	end
	
	local function refreshAdornee(v)
		local chest = v.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value or nil
		if not chest then
			v.Enabled = false
			return
		end
	
		local chestitems = chest and chest:GetChildren() or {}
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		v.Enabled = false
		local alreadygot = {}
		for _, item in chestitems do
			if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
				alreadygot[item.Name] = true
				v.Enabled = true
				local blockimage = Instance.new('ImageLabel')
				blockimage.Size = UDim2.fromOffset(32, 32)
				blockimage.BackgroundTransparency = 1
				blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
				blockimage.Parent = v.Frame
			end
		end
		table.clear(chestitems)
	end
	
	local function Added(v)
		local chest = v:WaitForChild('ChestFolderValue', 3)
		if not (chest and StorageESP.Enabled) then return end
		chest = chest.Value
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		StorageESP:Clean(chest.ChildAdded:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		task.spawn(refreshAdornee, billboard)
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				for _, v in collectionService:GetTagged('chest') do
					task.spawn(Added, v)
				end
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			for _, v in Reference do
				task.spawn(refreshAdornee, v)
			end
		end
	})
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = StorageESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local AutoBalloon
	
	AutoBalloon = vape.Categories.Utility:CreateModule({
		Name = 'AutoBalloon',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
				if not AutoBalloon.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then 
						lowestpoint = point 
					end
				end
	
				repeat
					if entitylib.isAlive then
						if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
							local balloon = getItem('balloon')
							if balloon then
								for _ = 1, 3 do 
									bedwars.BalloonController:inflateBalloon() 
								end
							end
							task.wait(0.1)
						end
					end
					task.wait(0.1)
				until not AutoBalloon.Enabled
			end
		end,
		Tooltip = 'Inflates when you fall into the void'
	})
end)
	
run(function()
	local AutoKit
	local Legit
	local Toggles = {}
	
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if InfiniteFly.Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		blood_assassin = function()
				local hitPlayers = {} 
				
				AutoKit:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if not entitylib.isAlive then return end
					
					local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
					local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
				
					if attacker == lplr and victim and victim ~= lplr then
						hitPlayers[victim] = true
						
						local storeState = bedwars.Store:getState()
						local activeContract = storeState.Kit.activeContract
						local availableContracts = storeState.Kit.availableContracts or {}
						
						if not activeContract then
							for _, contract in availableContracts do
								if contract.target == victim then
									bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
										contractId = contract.id
									})
									break
								end
							end
						end
					end
				end))
				
				repeat
					if entitylib.isAlive then
						local storeState = bedwars.Store:getState()
						local activeContract = storeState.Kit.activeContract
						local availableContracts = storeState.Kit.availableContracts or {}
						
						if not activeContract and #availableContracts > 0 then
							local bestContract = nil
							local highestDifficulty = 0
							
							for _, contract in availableContracts do
								if hitPlayers[contract.target] then
									if contract.difficulty > highestDifficulty then
										bestContract = contract
										highestDifficulty = contract.difficulty
									end
								end
							end
							
							if bestContract then
								bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
									contractId = bestContract.id
								})
								task.wait(0.5)
							end
						end
					else
						table.clear(hitPlayers)
					end
					task.wait(1)
				until not AutoKit.Enabled
				
				table.clear(hitPlayers)
		end,
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			kitCollection('bee', function(v)
				bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		bigman = function()
			kitCollection('treeOrb', function(v)
				if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
					v:Destroy()
				end
			end, 12, false)
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
				})
	
				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
	
					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end
	
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false, nil, true)
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
					target = v
				})
			end, 18, true)
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
			end
	
			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
	
				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		jailor = function()
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, 20, false)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end
	
				if ent and getItem('guitar') then
					bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
						healTarget = ent.Character
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			kitCollection('hidden-metal', function(v)
				bedwars.Client:Get(remotes.PickupMetal):SendToServer({
					id = v:GetAttribute('Id')
				})
			end, 20, false)
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Client:Get(remotes.MinerDig):SendToServer({
					petrifyId = v:GetAttribute('PetrifyId') or v:GetAttribute('Id')
				})
			end, 6, true)
		end,
		pinata = function()
			notif('AutoKit','please note lucia now has a range check now.',6,"warning")
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Client:Get('DepositCoins'):CallServer(v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		star_collector = function()
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, 20, false)
		end,
		summoner = function()
			repeat
				local plr = entitylib.EntityPosition({
					Range = 31,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})
	
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
	
					bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
	
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
	
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
	
			repeat
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})
	
					if plr then
						bedwars.Client:Get(remotes.DragonBreath):SendToServer({
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		warlock = function()
			local lastTarget
			repeat
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = true
					})
	
					if plr and plr.Character ~= lastTarget then
						if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
							target = plr.Character
						}) then
							plr = nil
						end
					end
	
					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		wizard = function()
			repeat
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability) then
					local plr = entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
	
					if plr then
						bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
					end
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end
	}
	
	AutoKit = vape.Categories.Utility:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = bedwars.BedwarsKitMeta[v].name,
			Default = true
		})
	end
end)
	
run(function()
	local AutoPearl
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function firePearl(pos, spot, item)
		switchItem(item.tool)
		local meta = bedwars.ProjectileMeta.telepearl
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
	
		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
			projectileRemote:InvokeServer(item.tool, 'telepearl', 'telepearl', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
		end
	
		if store.hand then
			switchItem(store.hand.tool)
		end
	end
	
	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			if callback then
				local check
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local pearl = getItem('telepearl')
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = getNearGround(20)
	
								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoPearl.Enabled
			end
		end,
		Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
	})
end)
	run(function()
	local AutoFreiya
	local Range
	local Stacks
	
	AutoFreiya = vape.Categories.Minigames:CreateModule({
		Name = 'AutoFreiya',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'ice_queen' and bedwars.AbilityController:canUseAbility('ice_queen', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Targetable and (v.Character:GetAttribute('IceQueenStacks') or 0) >= Stacks.Value and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								bedwars.AbilityController:useAbility('ice_queen')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFreiya.Enabled
			end
		end,
		Tooltip = 'Automatically detonates ice stacks once enemies are frozen enough'
	})
	Range = AutoFreiya:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Stacks = AutoFreiya:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Ice stacks an enemy needs before detonating'
	})
end)
run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
						table.insert(listofmodes, i) 
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)
run(function()
	local shooting, old = false
	local AutoShootInterval
	local AutoShootSwitchSpeed
	local AutoShootRange
	local AutoShootFOV
	local AutoShootWaitDelay
	local lastAutoShootTime = 0
	local autoShootEnabled = false
	local KillauraTargetCheck
	local FirstPersonCheck
	_G.autoShootLock = _G.autoShootLock or false
	local cachedBows = {}
	local cachedSwordSlot = nil
	local cachedHasArrows = false
	local lastInventoryUpdate = 0
	local INVENTORY_CACHE_TIME = 0.5
	local lastTargetCheck = 0
	local lastTargetResult = false
	local TARGET_CHECK_INTERVAL = 0.15
	local math_acos = math.acos
	local math_rad = math.rad
	local tick = tick
	
	local function updateInventoryCache()
		local now = tick()
		if now - lastInventoryUpdate < INVENTORY_CACHE_TIME then
			return
		end
		lastInventoryUpdate = now
		
		local arrowItem = getItem('arrow')
		cachedHasArrows = arrowItem and arrowItem.amount > 0
		
		table.clear(cachedBows)
		cachedSwordSlot = nil
		
		local hotbar = store.inventory.hotbar
		for i = 1, #hotbar do
			local v = hotbar[i]
			if v.item and v.item.itemType then
				local itemMeta = bedwars.ItemMeta[v.item.itemType]
				if itemMeta then
					if itemMeta.projectileSource then
						local projectileSource = itemMeta.projectileSource
						if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
							table.insert(cachedBows, i - 1)
						end
					end
					if itemMeta.sword and not cachedSwordSlot then
						cachedSwordSlot = i - 1
					end
				end
			end
		end
	end
	
	local function hasArrows()
		updateInventoryCache()
		return cachedHasArrows
	end
	
	local function getBows()
		updateInventoryCache()
		return cachedBows
	end
	
	local function getSwordSlot()
		updateInventoryCache()
		return cachedSwordSlot
	end

	-- Do not use hotbarSwitch here: it waits forever if the game does not emit an
	-- inventory event after a slot dispatch.  Polling the store gives AutoShoot a
	-- bounded failure path instead of leaving its lock held forever.
	local function switchToSlot(slot)
		if slot == nil then return false end
		if store.inventory.hotbarSlot == slot then return true end
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})

		local timeout = tick() + 0.25
		repeat
			task.wait()
		until store.inventory.hotbarSlot == slot or tick() >= timeout
		return store.inventory.hotbarSlot == slot
	end

	local function clickBow()
		if type(mouse1click) == 'function' then
			return pcall(mouse1click)
		end
		if type(mouse1press) == 'function' and type(mouse1release) == 'function' then
			local pressed = pcall(mouse1press)
			if not pressed then return false end
			task.wait()
			return pcall(mouse1release)
		end
		return false
	end

	local function fireBows(switchDelay, returnToSword)
		_G.autoShootLock = true
		local originalSlot = store.inventory.hotbarSlot
		local ok = xpcall(function()
			for _, bowSlot in getBows() do
				if switchToSlot(bowSlot) then
					task.wait(switchDelay)
					clickBow()
					task.wait(0.05)
				end
			end

			local restoreSlot = returnToSword and getSwordSlot() or originalSlot
			switchToSlot(restoreSlot or originalSlot)
		end, debug.traceback)
		_G.autoShootLock = false
		return ok
	end
	
	local function hasValidTarget()
		if KillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		end
		
		local now = tick()
		if now - lastTargetCheck < TARGET_CHECK_INTERVAL then
			return lastTargetResult
		end
		lastTargetCheck = now
		
		if not entitylib.isAlive then 
			lastTargetResult = false
			return false 
		end
		
		local myPos = entitylib.character.RootPart.Position
		local myLook = entitylib.character.RootPart.CFrame.LookVector
		local rangeSquared = AutoShootRange.Value * AutoShootRange.Value
		local fovRad = math_rad(AutoShootFOV.Value)
		local myTeam = lplr:GetAttribute('Team')
		
		for _, entity in entitylib.List do
			if entity.Player == lplr then continue end
			if not entity.Character then continue end
			
			local rootPart = entity.RootPart
			if not rootPart then continue end
			
			if entity.Player then
				if myTeam == entity.Player:GetAttribute('Team') then
					continue
				end
			else
				if not entity.Targetable then
					continue
				end
			end
			
			local pos = rootPart.Position
			local dx = pos.X - myPos.X
			local dy = pos.Y - myPos.Y
			local dz = pos.Z - myPos.Z
			local distanceSquared = dx * dx + dy * dy + dz * dz
			
			if distanceSquared > rangeSquared then continue end
			
			local distance = math.sqrt(distanceSquared)
			if distance < 0.01 then 
				lastTargetResult = true
				return true 
			end
			
			local toTargetX = dx / distance
			local toTargetY = dy / distance
			local toTargetZ = dz / distance
			local dot = myLook.X * toTargetX + myLook.Y * toTargetY + myLook.Z * toTargetZ
			local angle = math_acos(math.max(-1, math.min(1, dot)))
			
			if angle <= fovRad then
				lastTargetResult = true
				return true
			end
		end
		
		lastTargetResult = false
		return false
	end
	
	local AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				autoShootEnabled = true
				
				lastInventoryUpdate = 0
				updateInventoryCache()
				
				old = bedwars.ProjectileController.createLocalProjectile
				bedwars.ProjectileController.createLocalProjectile = function(...)
					local source, data, proj = ...
					if source and proj and (proj == 'arrow' or bedwars.ProjectileMeta[proj] and bedwars.ProjectileMeta[proj].combat) and not _G.autoShootLock then
						task.spawn(function()
							if not hasArrows() then
								return
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								return
							end
							
							if KillauraTargetCheck.Enabled then
								if not store.KillauraTarget then
									return
								end
							else
								if not hasValidTarget() then
									return
								end
							end
							
							local bows = getBows()
							if #bows > 0 then
								task.wait(AutoShootWaitDelay.Value)
								fireBows(0.05, false)
							end
						end)
					end
					return old(...)
				end
				
				task.spawn(function()
					repeat
						task.wait(0.15) 
						if autoShootEnabled and not _G.autoShootLock then
							if not hasArrows() then
								continue
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							local hasTarget = false
							if KillauraTargetCheck.Enabled then
								hasTarget = store.KillauraTarget ~= nil
							else
								hasTarget = hasValidTarget()
							end
							
							if not hasTarget then
								continue
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoShootTime) >= AutoShootInterval.Value then
								local bows = getBows()
								
								if #bows > 0 then
									lastAutoShootTime = currentTime
									fireBows(AutoShootSwitchSpeed.Value, true)
								end
							end
						end
					until not autoShootEnabled
				end)
			else
				autoShootEnabled = false
				if old then
					bedwars.ProjectileController.createLocalProjectile = old
				end
				_G.autoShootLock = false
				
				table.clear(cachedBows)
				cachedSwordSlot = nil
				cachedHasArrows = false
				lastInventoryUpdate = 0
			end
		end,
		Tooltip = 'Automatically switches to bows and shoots them'
	})
	
	AutoShootInterval = AutoShoot:CreateSlider({
		Name = 'Shoot Interval',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to auto-shoot bows'
	})
	
	AutoShootSwitchSpeed = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and shooting (lower = faster)'
	})
	
	AutoShootWaitDelay = AutoShoot:CreateSlider({
		Name = 'Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)'
	})
	
	AutoShootRange = AutoShoot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to auto-shoot'
	})
	
	AutoShootFOV = AutoShoot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	KillauraTargetCheck = AutoShoot:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only auto-shoot when Killaura has a target (overrides Range/FOV)'
	})
	
	FirstPersonCheck = AutoShoot:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
	
	vape:Clean(vapeEvents.InventoryChanged.Event:Connect(function()
		lastInventoryUpdate = 0
	end))
end)
	
	
run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait() 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)
	
run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
									item = getItem(item)
									if item then
										item = bedwars.Client:Get(remotes.DropItem):CallServer({
											item = item.tool,
											amount = item.amount
										})
	
										if item then
											item:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
							end
						end
					end
	
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
end)
	
run(function()
	local MissileTP
	
	MissileTP = vape.Categories.Utility:CreateModule({
		Name = 'MissileTP',
		Function = function(callback)
			if callback then
				MissileTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('guided_missile') and plr then
					local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
					if projectile then
						local projectilemodel = projectile.model
						if not projectilemodel.PrimaryPart then
							projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
						end
	
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Name = 'AntiGravity'
						bodyforce.Parent = projectilemodel.PrimaryPart
	
						repeat
							projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
							task.wait(0.1)
						until not projectile.model or not projectile.model.Parent
					else
						notif('MissileTP', 'Missile on cooldown.', 3)
					end
				end
			end
		end,
		Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
	})
end)
	
run(function()
	local PickupRange
	local Range
	local Network
	local Lower
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in items do
							if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
							if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
							end
							
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
								task.spawn(function()
									bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.SoundManager:playSound(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	Network = PickupRange:CreateToggle({
		Name = 'Network TP',
		Default = true
	})
	Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)
	
run(function()
	local RavenTP
	
	RavenTP = vape.Categories.Utility:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('raven') and plr then
					bedwars.Client:Get(remotes.SpawnRaven):CallServerAsync():andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart
	
							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
	})
end)
	
run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local adjacent, lastpos, label = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	local function getScaffoldBlock()
	local inventory = InventoryUtil.GetInventory(CoreGui)
	if not inventory or not inventory.items then
		return nil
	end

	for _, item in pairs(inventory.items) do
		if item and item.item and item.itemType then
			local allowed = true

			if LimitItem then
				allowed = item.itemType == LimitItem
			end

			if allowed then
				return item
			end
		end
	end

	return nil
end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()
	
						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end
	
						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end
	
						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
									if blockpos then
										task.spawn(bedwars.placeBlock, blockpos, wool, false)
									end
								end
								lastpos = currentpos
							end
						end
					end
	
					task.wait(0.03)
				until not Scaffold.Enabled
			else
				Label = nil
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)
	
run(function()
	local ShopTierBypass
	local tiered, nexttier = {}, {}
	
	ShopTierBypass = vape.Categories.Utility:CreateModule({
		Name = 'ShopTierBypass',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.shopLoaded or not ShopTierBypass.Enabled
				if ShopTierBypass.Enabled then
					for _, v in bedwars.Shop.ShopItems do
						tiered[v] = v.tiered
						nexttier[v] = v.nextTier
						v.nextTier = nil
						v.tiered = nil
					end
				end
			else
				for i, v in tiered do
					i.tiered = v
				end
				for i, v in nexttier do
					i.nextTier = v
				end
				table.clear(nexttier)
				table.clear(tiered)
			end
		end,
		Tooltip = 'Lets you buy things like armor early.'
	})
end)
	
run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local AlertDuration
	local ClosetDetect

	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}

	local blacklistedusernames = {}
	local apiModNames = {}

	local teamNameMap = { [1] = 'Blue', [2] = 'Orange', [3] = 'Pink', [4] = 'Yellow' }
	local joined = {}
	local detectedPlayers = {}
	local processing = {}

		local listsLoaded = false
		task.spawn(function()
			listsLoaded = true
		end)

	getgenv()._aerov4_staffCounts = {spec=0, closet=0, mod=0, impossible=0}
	local function refreshStaffCounts()
		local c = {spec=0, closet=0, mod=0, impossible=0}
		for _, data in pairs(detectedPlayers) do
			local ct = data.checktype
			if ct == 'spectator' then c.spec += 1
			elseif ct == 'closet' then c.closet += 1
			elseif ct == 'impossible_join' then c.impossible += 1
			else c.mod += 1 end
		end
		getgenv()._aerov4_staffCounts = c
		vapeEvents.StaffCountUpdate:Fire()
	end

	local function staffFunction(plr, checktype)
		if detectedPlayers[plr.UserId] then return end
		if not vape.Loaded then repeat task.wait() until vape.Loaded end
		local duration = AlertDuration.Value
		local playerName = plr.Name
		local playerId = plr.UserId
		detectedPlayers[playerId] = {name=playerName, checktype=checktype, detectedTime=tick()}
		notif('StaffDetector', 'Staff Detected (' .. checktype .. '): ' .. playerName .. ' (' .. playerId .. ')', duration, 'alert')
		whitelist.customtags[playerName] = {{text='GAME STAFF', color=Color3.new(1,0,0)}}
		local isClanCheck = checktype:find('clan')
		if Party.Enabled and not isClanCheck then pcall(bedwars.PartyController.leaveParty) end
		local modeValue = Mode.Value
		if modeValue == 'Uninject' then
			task.spawn(function() vape:Uninject() end)
			game:GetService('StarterGui'):SetCore('SendNotification', {Title='StaffDetector',Text='Staff Detected ('..checktype..')\n'..playerName..' ('..playerId..')',Duration=duration})
		elseif modeValue == 'Requeue' then
			pcall(bedwars.QueueController.leaveQueue)
			bedwars.QueueController:joinQueue(store.queueType)
		elseif modeValue == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then vape:Load(true, Profile.Value) end
		elseif modeValue == 'AutoConfig' then
			local safe = {AutoClicker=true,Reach=true,Sprint=true,HitFix=true,StaffDetector=true}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (safe[i] or v.Category == 'Render') then
					if v.Enabled then v:Toggle() end
					v:SetBind('')
				end
			end
		end
		refreshStaffCounts()
	end

	local function closetFunction(plr)
		if detectedPlayers[plr.UserId] then return end
		if not vape.Loaded then repeat task.wait() until vape.Loaded end
		local teamNum = tonumber(plr:GetAttribute('Team'))
		local team = teamNum and teamNameMap[teamNum] or 'Unknown'
		detectedPlayers[plr.UserId] = {name=plr.Name, checktype='closet', detectedTime=tick()}
		notif('StaffDetector', 'KNOWN CLOSETCHEATER: ' .. plr.Name .. ' | Team: ' .. team, AlertDuration.Value, 'alert')
		whitelist.customtags[plr.Name] = {{text='CHEATER', color=Color3.fromRGB(255,140,0)}}
		refreshStaffCounts()
	end

	local function checkCloset(plr)
		if not ClosetDetect or not ClosetDetect.Enabled then return false end
		if plr == lplr then return false end
		if blacklistedusernames[plr.Name:lower()] then
			task.spawn(function()
				local waited = 0
				while not plr:GetAttribute('Team') and waited < 10 do
					task.wait(0.5) waited += 0.5
				end
				closetFunction(plr)
			end)
			return true
		end
		return false
	end

	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
		if processing[plr.UserId] then return end
		processing[plr.UserId] = true

		if not listsLoaded then
			local t = tick()
			repeat task.wait(0.1) until listsLoaded or (tick()-t > 3)
		end

		if checkCloset(plr) then processing[plr.UserId] = nil return end

		if table.find(blacklisteduserids, plr.UserId) or (Users and table.find(Users.ListEnabled, tostring(plr.UserId))) then
			staffFunction(plr, 'blacklisted_user')
			processing[plr.UserId] = nil
			return
		end

		if apiModNames[plr.Name:lower()] then
			staffFunction(plr, 'known_mod')
			processing[plr.UserId] = nil
			return
		end

		local function spectatorFunction(plr)
			if detectedPlayers[plr.UserId] then return end
			if not vape.Loaded then repeat task.wait() until vape.Loaded end
			detectedPlayers[plr.UserId] = {name=plr.Name, checktype='spectator', detectedTime=tick()}
			notif('StaffDetector', 'Spectator: '..plr.Name..' ('..tostring(plr.UserId)..') [Has friend in server]', AlertDuration.Value, 'warning')
			refreshStaffCounts()
		end

		local function checkJoin()
			if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') then
				local hasFriend = false
				for _, sp in ipairs(playersService:GetPlayers()) do
					if sp ~= plr then
						local ok, res = pcall(function() return plr:IsFriendsWith(sp.UserId) end)
						if ok and res then hasFriend = true break end
					end
				end
				if hasFriend then spectatorFunction(plr) else staffFunction(plr, 'impossible_join') end
				return true
			end
			return false
		end

		local spectatorConnection
		spectatorConnection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
			if checkJoin() then spectatorConnection:Disconnect() processing[plr.UserId] = nil end
		end)
		StaffDetector:Clean(spectatorConnection)

		if checkJoin() then processing[plr.UserId] = nil return end

		if Clans.Enabled then
			local function checkClanTag()
				local clanTag = plr:GetAttribute('ClanTag')
				if clanTag and table.find(blacklistedclans, clanTag) then
					staffFunction(plr, 'blacklisted_clan_' .. clanTag:lower())
				end
			end
			if plr:GetAttribute('ClanTag') then
				checkClanTag()
			else
				local clanConnection
				clanConnection = plr:GetAttributeChangedSignal('ClanTag'):Connect(function()
					clanConnection:Disconnect()
					checkClanTag()
				end)
				StaffDetector:Clean(clanConnection)
				task.delay(5, function() if clanConnection then clanConnection:Disconnect() end end)
			end
		end

		processing[plr.UserId] = nil
	end

	local function playerRemoving(plr)
		local userId = plr.UserId
		joined[userId] = nil
		processing[userId] = nil
		if detectedPlayers[userId] then
			local data = detectedPlayers[userId]
			notif('StaffDetector', data.name .. ' (' .. data.checktype .. ') has left the server', AlertDuration.Value, 'warning')
			if whitelist.customtags[data.name] then whitelist.customtags[data.name] = nil end
			detectedPlayers[userId] = nil
			refreshStaffCounts()
		end
	end

	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				StaffDetector:Clean(playersService.PlayerRemoving:Connect(playerRemoving))
				for _, v in playersService:GetPlayers() do task.spawn(playerAdded, v) end
			else
				table.clear(joined) table.clear(processing) table.clear(detectedPlayers)
				refreshStaffCounts()
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})

	Mode = StaffDetector:CreateDropdown({Name='Mode',List={'Uninject','Profile','Requeue','AutoConfig','Notify'},Function=function(val) if Profile.Object then Profile.Object.Visible = val=='Profile' end end})
	AlertDuration = StaffDetector:CreateSlider({Name='Alert Duration',Min=5,Max=120,Default=60,Suffix='s',Tooltip='How long the alert notification stays on screen'})
	Clans = StaffDetector:CreateToggle({Name='Blacklist clans',Default=true})
	Party = StaffDetector:CreateToggle({Name='Leave party'})
	ClosetDetect = StaffDetector:CreateToggle({Name='Known Cheaters',Default=true,Tooltip='Alerts when a known closet cheater joins your game'})
	Profile = StaffDetector:CreateTextBox({Name='Profile',Default='default',Darker=true,Visible=false})
	Users = StaffDetector:CreateTextList({Name='Users',Placeholder='player (userid)',Function=function() end})
	task.defer(function() if Profile and Profile.Object then Profile.Object.Visible = (Mode.Value=='Profile') end end)
end)

	
run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'Disables Snap Traps'
	})
end)
	
run(function()
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					v:Disconnect()
				end
	
				for _, v in getconnections(runService.Heartbeat) do
					if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then
						v:Disconnect()
					end
				end
	
				bedwars.Client:Get(remotes.AfkStatus):SendToServer({
					afk = false
				})
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
run(function()
	local AutoSuffocate
	local Range
	local LimitItem
	
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end
	
	AutoSuffocate = vape.Categories.World:CreateModule({
		Name = 'AutoSuffocate',
		Function = function(callback)
			if callback then
				repeat
					local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()
	
					if item then
						local plrs = entitylib.AllPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = true
						})
	
						for _, ent in plrs do
							local needPlaced = {}
	
							for _, side in Enum.NormalId:GetEnumItems() do
								side = Vector3.fromNormalId(side)
								if side.Y ~= 0 then continue end
	
								side = fixPosition(ent.RootPart.Position + side * 2)
								if not getPlacedBlock(side) then
									table.insert(needPlaced, side)
								end
							end
	
							if #needPlaced < 3 then
								table.insert(needPlaced, fixPosition(ent.Head.Position))
								table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))
	
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
										break
									end
								end
							end
						end
					end
	
					task.wait(0.09)
				until not AutoSuffocate.Enabled
			end
		end,
		Tooltip = 'Places blocks on nearby confined entities'
	})
	Range = AutoSuffocate:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	LimitItem = AutoSuffocate:CreateToggle({
		Name = 'Limit to Items',
		Default = true
	})
end)
	
run(function()
	local AutoTool
	local old, event
	
	local function switchHotbarItem(block)
		if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
			local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
			if tool then
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
				end
	
				if hotbarSwitch(slot) then
					if inputService:IsMouseButtonPressed(0) then 
						event:Fire() 
					end
					return true
				end
			end
		end
	end
	
	AutoTool = vape.Categories.World:CreateModule({
		Name = 'AutoTool',
		Function = function(callback)
			if callback then
				event = Instance.new('BindableEvent')
				AutoTool:Clean(event)
				AutoTool:Clean(event.Event:Connect(function()
					contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
				end))
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
					if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then return end
					return old(self, maid, raycastparams, ...)
				end
			else
				bedwars.BlockBreaker.hitBlock = old
				old = nil
			end
		end,
		Tooltip = 'Automatically selects the correct tool'
	})
end)
run(function()
    local BedProtector
    local PlaceRange
    local Blacklist
    local Mode
    local Smart
    local Switch
    local Layers
    local PlaceHz
    local AutoPatch
    local AutoPatchRange
    local ProtectedLayers
    local PlacementSpeed

    local function getBedNear()
        local best, bestDist = nil, math.huge
        for _, v in collectionService:GetTagged('bed') do
            if not v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then continue end
            local d = entitylib.isAlive and (entitylib.character.RootPart.Position - v.Position).Magnitude or math.huge
            if d < bestDist then
                best, bestDist = v, d
            end
        end
        return best
    end

    local function getBlocks()
        local blocks = {}
        for _, item in store.inventory.inventory.items do
            local block = bedwars.ItemMeta[item.itemType].block
            if
                block and not table.find(Blacklist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType)
            then
                table.insert(blocks, { item.itemType, block.health, item.tool })
            end
        end
        table.sort(blocks, function(a, b)
            return a[2] > b[2]
        end)
        return blocks
    end

    local function getPyramid(size, grid)
        local positions = {}
        for h = size, 0, -1 do
            for w = h, 0, -1 do
                table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
                table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
                table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
                table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
            end
        end
        return positions
    end

    local function isEnemy(player)
        if not player then return false end
        local myTeam = lplr:GetAttribute('Team')
        return player:GetAttribute('Team') ~= myTeam
    end

    local function isWithinProtectedLayers(worldPos, bed)
        if not bed then return false end
        local relPos = bed.CFrame:PointToObjectSpace(worldPos)
        local gx = math.floor(relPos.X / 3 + 0.5)
        local gy = math.floor(relPos.Y / 3 + 0.5)
        local gz = math.floor(relPos.Z / 3 + 0.5)
        local maxLayer = ProtectedLayers.Value
        for layer = 1, maxLayer do
            for _, pos in getPyramid(layer, 3) do
                local px = math.floor(pos.X / 3 + 0.5)
                local py = math.floor(pos.Y / 3 + 0.5)
                local pz = math.floor(pos.Z / 3 + 0.5)
                if px == gx and py == gy and pz == gz then
                    return true
                end
            end
        end
        return false
    end

    BedProtector = vape.Categories.World:CreateModule({
        Name = 'Draco X2',
        Function = function(callback)
            if callback then
                BedProtector:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(data)
                    if not BedProtector.Enabled then return end
                    if not AutoPatch.Enabled then return end
                    if not entitylib.isAlive then return end
                    if not isEnemy(data.player) then return end

                    local worldPos = data.blockRef.blockPosition * 3
                    local bed = getBedNear()
                    if not bed then return end
                    if (entitylib.character.RootPart.Position - worldPos).Magnitude > AutoPatchRange.Value then return end
                    if not isWithinProtectedLayers(worldPos, bed) then return end
                    if getPlacedBlock(worldPos) then return end

                    local blocks = getBlocks()
                    if #blocks == 0 then return end
                    local block = blocks[1]

                    task.spawn(function()
                        if PlacementSpeed.Value > 0 then
                            task.wait(PlacementSpeed.Value / 1000)
                        end

                        if getPlacedBlock(worldPos) then return end

                        local old = store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
                        local switched = false

                        if Switch.Enabled then
                            local hotbar = getHotbar(block[3])
                            if hotbar and hotbarSwitch(hotbar) then
                                switched = true
                                task.wait()
                            end
                        end

                        bedwars.placeBlock(worldPos, block[1], false)

                        if switched and old then
                            task.wait()
                            hotbarSwitch(old)
                        end
                    end)
                end))

                repeat
                    local bed = getBedNear()
                    if bed then
                        for i, block in getBlocks() do
                            if i > Layers.Value then
                                break
                            end
                            local switch, old = Switch.Enabled, store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
                            local hotbar = nil

                            if switch then
                                hotbar = getHotbar(block[3])
                            end

                            for _, pos in getPyramid(i, 3) do
                                if not BedProtector.Enabled then
                                    break
                                end
                                pos = (bed.CFrame * CFrame.new(pos)).Position
                                if getPlacedBlock(pos) then
                                    continue
                                end
                                if entitylib.isAlive and (entitylib.character.RootPart.Position - pos).Magnitude > PlaceRange.Value then
                                    continue
                                end
                                if hotbar and hotbarSwitch(hotbar) then
                                    task.wait()
                                end
                                task.spawn(bedwars.placeBlock, pos, block[1], false)
                                task.wait(1 / PlaceHz.Value)
                            end

                            if switch and old and hotbarSwitch(old) then
                                task.wait()
                            end
                        end
                    else
                        if Mode.Value == 'On Key' then
                            notif('Draco X2', 'Unable to locate bed', 5)
                            BedProtector:Toggle()
                        end
                    end
                    task.wait(0.5)
                    if Mode.Value == 'On Key' then
                        BedProtector:Toggle()
                        break
                    end
                until not BedProtector.Enabled
            end
        end,
        Tooltip = 'Automatically places and defends blocks around the bed.'
    })

    Mode = BedProtector:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On Key'},
        Default = 'Toggle',
        Function = function(val)
            if Smart then
                Smart.Object.Visible = val == 'Toggle'
            end
        end,
    })
    Blacklist = BedProtector:CreateTextList({
        Name = 'Blacklist',
        Default = {'siege_tnt', 'tnt'},
    })
    PlaceRange = BedProtector:CreateSlider({
        Name = 'Place Range',
        Min = 1,
        Max = 40,
        Default = 15,
    })
    Layers = BedProtector:CreateSlider({
        Name = 'Layers',
        Min = 1,
        Max = 8,
        Default = 3,
        Suffix = function(v) return v == 1 and 'layer' or 'layers' end,
        Tooltip = 'How many pyramid layers to build around the bed; set to 1 to only build the closest layer'
    })
    PlaceHz = BedProtector:CreateSlider({
        Name = 'Place Hz',
        Min = 1,
        Max = 20,
        Default = 10,
        Suffix = 'hz',
        Tooltip = 'How many blocks to place per second; higher = faster'
    })
    Switch = BedProtector:CreateToggle({Name = 'Auto Switch'})
    Smart = BedProtector:CreateToggle({Name = 'Smart', Default = true})
    AutoPatch = BedProtector:CreateToggle({
        Name = 'AutoPatch',
        Default = false,
        Tooltip = 'When enabled, automatically replaces blocks broken by enemies within the protected layers'
    })
    AutoPatchRange = BedProtector:CreateSlider({
        Name = 'AutoPatch Range',
        Min = 1,
        Max = 40,
        Default = 15,
        Suffix = 'studs',
        Tooltip = 'How far from your character AutoPatch will replace broken blocks'
    })
    ProtectedLayers = BedProtector:CreateSlider({
        Name = 'Protected Layers',
        Min = 1,
        Max = 8,
        Default = 2,
        Suffix = function(v) return v == 1 and 'layer' or 'layers' end,
        Tooltip = 'How many pyramid layers AutoPatch will monitor and rebuild when broken by enemies'
    })
    PlacementSpeed = BedProtector:CreateSlider({
        Name = 'Placement Speed',
        Min = 0,
        Max = 500,
        Default = 100,
        Suffix = 'ms',
        Tooltip = 'Delay in milliseconds before AutoPatch places a replacement block; 0 for instant'
    })
end)
run(function()
	local BlockIn
	local SpeedSlider
	local DelaySlider
	local AutoSwitch
	local HandCheck
	local StrongestOnly
	local CpsConstants = nil
	local originalCPS = 12
	local placing = false
	local buildThread = nil
	
	local facesOnly = {
		Vector3.new(3, 0, 0),   
		Vector3.new(-3, 0, 0), 
		Vector3.new(0, 3, 0),   
		Vector3.new(0, -3, 0),  
		Vector3.new(0, 0, 3),   
		Vector3.new(0, 0, -3) 
	}
	
	local function checkFaceAdjacent(pos)
		for _, v in facesOnly do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function hasFaceBelowOrSide(pos)
		if getPlacedBlock(pos - Vector3.new(0, 3, 0)) then
			return true
		end
		
		for _, v in facesOnly do
			if v.Y == 0 and getPlacedBlock(pos + v) then
				return true
			end
		end
		
		return false
	end
	
	local function canPlaceAtPosition(blockpos)
		if not checkFaceAdjacent(blockpos) then
			return false
		end
		
		local checkBelow = blockpos - Vector3.new(0, 3, 0)
		local hasSupport = false
		
		for i = 1, 10 do
			if getPlacedBlock(checkBelow) then
				hasSupport = true
				break
			end
			checkBelow = checkBelow - Vector3.new(0, 3, 0)
		end
		
		return hasSupport or hasFaceBelowOrSide(blockpos)
	end
	
	local function initCPS()
		pcall(function()
			CpsConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants
		end)
		
		if not CpsConstants then
			pcall(function()
				CpsConstants = bedwars.CpsConstants
			end)
		end
		
		if CpsConstants then
			originalCPS = CpsConstants.BLOCK_PLACE_CPS
		end
	end
	
	local function setCPS(value)
		if CpsConstants then
			CpsConstants.BLOCK_PLACE_CPS = value
		end
	end
	
	local function getBlocks()
		local blocks = {}
		
		for _, item in pairs(store.inventory.inventory.items) do
			if bedwars.ItemMeta[item.itemType] and bedwars.ItemMeta[item.itemType].block then
				local meta = bedwars.ItemMeta[item.itemType]
				table.insert(blocks, {
					itemType = item.itemType,
					health = meta.block.health or 0,
					tool = item.tool
				})
			end
		end
		
		table.sort(blocks, function(a, b)
			return a.health > b.health
		end)
		
		return blocks
	end
	
	local function getHotbarSlotForBlock(blockTool)
		for i, v in pairs(store.inventory.hotbar) do
			if v.item and v.item.tool == blockTool then
				return i - 1
			end
		end
		return nil
	end
	
	local function hasBlockAt(pos)
		local block, blockpos = getPlacedBlock(pos)
		return block ~= nil
	end
	
	local function getScaffoldBlock()
		if HandCheck.Enabled then
			if store.hand and store.hand.toolType == 'block' then
				return store.hand.tool.Name
			end
			return nil
		else
			local blocks = getBlocks()
			if #blocks == 0 then
				return nil
			end
			
			if StrongestOnly.Enabled then
				return blocks[1].itemType
			else
				local weakestInHotbar = nil
				local weakestHealth = math.huge
				
				for _, block in ipairs(blocks) do
					local slot = getHotbarSlotForBlock(block.tool)
					if slot then
						if block.health < weakestHealth then
							weakestHealth = block.health
							weakestInHotbar = block
						end
					end
				end
				
				if weakestInHotbar then
					return weakestInHotbar.itemType
				else
					return blocks[1].itemType
				end
			end
		end
	end
	
	local function findGaps(origin)
		local gaps = {}
		
		local offsets = {
			Vector3.new(3, 0, 0),
			Vector3.new(-3, 0, 0),
			Vector3.new(0, 3, 0),
			Vector3.new(0, -3, 0),
			Vector3.new(0, 0, 3),
			Vector3.new(0, 0, -3),
			Vector3.new(3, 3, 0),
			Vector3.new(-3, 3, 0),
			Vector3.new(0, 3, 3),
			Vector3.new(0, 3, -3),
			Vector3.new(0, 6, 0),
		}
		
		for _, offset in ipairs(offsets) do
			local pos = origin + offset
			
			if not hasBlockAt(pos) then
				table.insert(gaps, pos)
			end
		end
		
		return gaps
	end
	
	local function hasMovedSignificantly(startPos, currentPos)
		local distance = (startPos - currentPos).Magnitude
		return distance > 2
	end
	
	local function executeBlockIn()
		if placing then return end
		placing = true
		
		buildThread = task.spawn(function()
			while BlockIn.Enabled and placing do
				if not entitylib.isAlive then
					notif('BlockIn', 'Not alive', 2)
					placing = false
					BlockIn:Toggle()
					return
				end
				
				local blockToUse = getScaffoldBlock()
				
				if not blockToUse then
					task.wait(0.1)
					continue
				end
				
				setCPS(SpeedSlider.Value)
				
				local startOrigin = entitylib.character.RootPart.Position
				
				local gaps = findGaps(startOrigin)
				
				if #gaps == 0 then
					if AutoSwitch.Enabled and not HandCheck.Enabled then
						pcall(function()
							hotbarSwitch(store.inventory.hotbarSlot)
						end)
					end
					
					setCPS(originalCPS)
					placing = false
					
					task.wait(0.1)
					if BlockIn.Enabled then
						BlockIn:Toggle()
					end
					return
				end
				
				local originalSlot = store.inventory.hotbarSlot
				local delay = DelaySlider.Value / 1000
				
				local function restoreSlot()
					if AutoSwitch.Enabled and not HandCheck.Enabled and originalSlot then
						pcall(function()
							hotbarSwitch(originalSlot)
						end)
					end
				end
				
				if AutoSwitch.Enabled and not HandCheck.Enabled then
					local blocks = getBlocks()
					if #blocks > 0 then
						local targetBlock = nil
						
						if StrongestOnly.Enabled then
							targetBlock = blocks[1]
						else
							local weakestInHotbar = nil
							local weakestHealth = math.huge
							
							for _, block in ipairs(blocks) do
								local slot = getHotbarSlotForBlock(block.tool)
								if slot then
									if block.health < weakestHealth then
										weakestHealth = block.health
										weakestInHotbar = block
									end
								end
							end
							
							targetBlock = weakestInHotbar or blocks[1]
						end
						
						if targetBlock then
							local slot = getHotbarSlotForBlock(targetBlock.tool)
							if slot then
								hotbarSwitch(slot)
								task.wait(0.05)
							end
						end
					end
				end
				
				for i, pos in ipairs(gaps) do
					if not BlockIn.Enabled or not placing then 
						break 
					end
					
					local currentBlock = getScaffoldBlock()
					if not currentBlock then
						break
					end
					
					if not entitylib.isAlive then
						break
					end
					
					local currentPos = entitylib.character.RootPart.Position
					if hasMovedSignificantly(startOrigin, currentPos) then

					end
					
					if not hasBlockAt(pos) then
						if hasFaceBelowOrSide(pos) then
							if canPlaceAtPosition(pos) then
								pcall(bedwars.placeBlock, pos, currentBlock, false)
							end
						else
							local nearestBlock = blockProximity(pos)
							if nearestBlock and canPlaceAtPosition(nearestBlock) then
								pcall(bedwars.placeBlock, nearestBlock, currentBlock, false)
							end
						end
					end
					
					if i < #gaps then
						task.wait(delay)
					end
				end
				
				restoreSlot()
				task.wait(0.1)
			end
			
			restoreSlot()
			setCPS(originalCPS)
			placing = false
		end)
	end
	
	BlockIn = vape.Categories.Utility:CreateModule({
		Name = 'BlockIn',
		Function = function(callback)
			if callback then
				initCPS()
				executeBlockIn()
			else
				placing = false
				if buildThread then
					pcall(function()
						task.cancel(buildThread)
					end)
					buildThread = nil
				end
				setCPS(originalCPS)
			end
		end,
		Tooltip = 'Surrounds you with blocks (real-time gap detection)'
	})
	
	SpeedSlider = BlockIn:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 12,
		Default = 12,
		Suffix = ' CPS',
		Function = function(val)
			if BlockIn.Enabled then
				setCPS(val)
			end
		end,
		Tooltip = 'Block placement speed'
	})
	
	DelaySlider = BlockIn:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 200,
		Default = 50,
		Suffix = 'ms',
		Function = function(val)
		end,
		Tooltip = 'Delay between blocks'
	})
	
	AutoSwitch = BlockIn:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Function = function(val)
		end,
		Tooltip = 'Auto switch to blocks'
	})
	
	HandCheck = BlockIn:CreateToggle({
		Name = 'Hand Check',
		Default = false,
		Function = function(val)
		end,
		Tooltip = 'Only build when holding block'
	})
	
	StrongestOnly = BlockIn:CreateToggle({
		Name = 'Strongest Only',
		Default = false,
		Function = function(val)
		end,
		Tooltip = 'Use strongest block only (obsidian)'
	})
end)
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local Delays = {}
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + 0.2
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController and bedwars.AppController:isAppOpen('ChestApp') then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								for _, v in chests do
									if (localPosition - v.Position).Magnitude <= Range.Value then
										lootChest(v:FindFirstChild('ChestFolderValue'))
									end
								end
							end
						end
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			end
		end,
		Tooltip = 'Grabs items from near chests.'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local Schematica
	local File
	local Mode
	local Transparency
	local parts, guidata, poschecklist = {}, {}, {}
	local point1, point2
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				if Vector3.new(x, y, z) ~= Vector3.zero then
					table.insert(poschecklist, Vector3.new(x, y, z))
				end
			end
		end
	end
	
	local function checkAdjacent(pos)
		for _, v in poschecklist do
			if getPlacedBlock(pos + v) then return true end
		end
		return false
	end
	
	local function getPlacedBlocksInPoints(s, e)
		local list, blocks = {}, bedwars.BlockController:getStore()
		for x = (e.X > s.X and s.X or e.X), (e.X > s.X and e.X or s.X) do
			for y = (e.Y > s.Y and s.Y or e.Y), (e.Y > s.Y and e.Y or s.Y) do
				for z = (e.Z > s.Z and s.Z or e.Z), (e.Z > s.Z and e.Z or s.Z) do
					local vec = Vector3.new(x, y, z)
					local block = blocks:getBlockAt(vec)
					if block and block:GetAttribute('PlacedByUserId') == lplr.UserId then
						list[vec] = block
					end
				end
			end
		end
		return list
	end
	
	local function loadMaterials()
		for _, v in guidata do 
			v:Destroy() 
		end
		local suc, read = pcall(function() 
			return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
		end)
	
		if suc and read then
			local items = {}
			for _, v in read do 
				items[v[2]] = (items[v[2]] or 0) + 1 
			end
			
			for i, v in items do
				local holder = Instance.new('Frame')
				holder.Size = UDim2.new(1, 0, 0, 32)
				holder.BackgroundTransparency = 1
				holder.Parent = Schematica.Children
				local icon = Instance.new('ImageLabel')
				icon.Size = UDim2.fromOffset(24, 24)
				icon.Position = UDim2.fromOffset(4, 4)
				icon.BackgroundTransparency = 1
				icon.Image = bedwars.getIcon({itemType = i}, true)
				icon.Parent = holder
				local text = Instance.new('TextLabel')
				text.Size = UDim2.fromOffset(100, 32)
				text.Position = UDim2.fromOffset(32, 0)
				text.BackgroundTransparency = 1
				text.Text = (bedwars.ItemMeta[i] and bedwars.ItemMeta[i].displayName or i)..': '..v
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.TextColor3 = uipallet.Text
				text.TextSize = 14
				text.FontFace = uipallet.Font
				text.Parent = holder
				table.insert(guidata, holder)
			end
			table.clear(read)
			table.clear(items)
		end
	end
	
	local function save()
		if point1 and point2 then
			local tab = getPlacedBlocksInPoints(point1, point2)
			local savetab = {}
			point1 = point1 * 3
			for i, v in tab do
				i = bedwars.BlockController:getBlockPosition(CFrame.lookAlong(point1, entitylib.character.RootPart.CFrame.LookVector):PointToObjectSpace(i * 3)) * 3
				table.insert(savetab, {
					{
						x = i.X, 
						y = i.Y, 
						z = i.Z
					}, 
					v.Name
				})
			end
			point1, point2 = nil, nil
			writefile(File.Value, httpService:JSONEncode(savetab))
			notif('Schematica', 'Saved '..getTableSize(tab)..' blocks', 5)
			loadMaterials()
			table.clear(tab)
			table.clear(savetab)
		else
			local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
			if mouseinfo and mouseinfo.target then
				if point1 then
					point2 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 2, toggle again near position 1 to save it', 3)
				else
					point1 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 1', 3)
				end
			end
		end
	end
	
	local function load(read)
		local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
		if mouseinfo and mouseinfo.target then
			local position = CFrame.new(mouseinfo.placementPosition * 3) * CFrame.Angles(0, math.rad(math.round(math.deg(math.atan2(-entitylib.character.RootPart.CFrame.LookVector.X, -entitylib.character.RootPart.CFrame.LookVector.Z)) / 45) * 45), 0)
	
			for _, v in read do
				local blockpos = bedwars.BlockController:getBlockPosition((position * CFrame.new(v[1].x, v[1].y, v[1].z)).p) * 3
				if parts[blockpos] then continue end
				local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v[2]:find('wool') and getWool() or v[2])
				if handler then
					local part = handler:place(blockpos / 3, 0)
					part.Transparency = Transparency.Value
					part.CanCollide = false
					part.Anchored = true
					part.Parent = workspace
					parts[blockpos] = part
				end
			end
			table.clear(read)
	
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in parts do
						if (i - localPosition).Magnitude < 60 and checkAdjacent(i) then
							if not Schematica.Enabled then break end
							if not getItem(v.Name) then continue end
							bedwars.placeBlock(i, v.Name, false)
							task.delay(0.1, function()
								local block = getPlacedBlock(i)
								if block then
									v:Destroy()
									parts[i] = nil
								end
							end)
						end
					end
				end
				task.wait()
			until getTableSize(parts) <= 0
	
			if getTableSize(parts) <= 0 and Schematica.Enabled then
				notif('Schematica', 'Finished building', 5)
				Schematica:Toggle()
			end
		end
	end
	
	Schematica = vape.Categories.World:CreateModule({
		Name = 'Schematica',
		Function = function(callback)
			if callback then
				if not File.Value:find('.json') then
					notif('Schematica', 'Invalid file', 3)
					Schematica:Toggle()
					return
				end
	
				if Mode.Value == 'Save' then
					save()
					Schematica:Toggle()
				else
					local suc, read = pcall(function() 
						return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
					end)
	
					if suc and read then
						load(read)
					else
						notif('Schematica', 'Missing / corrupted file', 3)
						Schematica:Toggle()
					end
				end
			else
				for _, v in parts do 
					v:Destroy() 
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Save and load placements of buildings'
	})
	File = Schematica:CreateTextBox({
		Name = 'File',
		Function = function()
			loadMaterials()
			point1, point2 = nil, nil
		end
	})
	Mode = Schematica:CreateDropdown({
		Name = 'Mode',
		List = {'Load', 'Save'}
	})
	Transparency = Schematica:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.7,
		Decimal = 10,
		Function = function(val)
			for _, v in parts do 
				v.Transparency = val 
			end
		end
	})
end)
	
run(function()
	local ArmorSwitch
	local Mode
	local Targets
	local Range
	
	ArmorSwitch = vape.Categories.Inventory:CreateModule({
		Name = 'ArmorSwitch',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Toggle' then
					repeat
						local state = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						}) and true or false
	
						for i = 0, 2 do
							if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
								bedwars.Store:dispatch({
									type = 'InventorySetArmorItem',
									item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
									armorSlot = i
								})
								vapeEvents.InventoryChanged.Event:Wait()
							end
						end
						task.wait(0.1)
					until not ArmorSwitch.Enabled
				else
					ArmorSwitch:Toggle()
					for i = 0, 2 do
						bedwars.Store:dispatch({
							type = 'InventorySetArmorItem',
							item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
							armorSlot = i
						})
						vapeEvents.InventoryChanged.Event:Wait()
					end
				end
			end
		end,
		Tooltip = 'Puts on / takes off armor when toggled for baiting.'
	})
	Mode = ArmorSwitch:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'}
	})
	Targets = ArmorSwitch:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = ArmorSwitch:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local AutoBank
	local UIToggle
	local UI
	local Chests
	local Items = {}
	
	local function addItem(itemType, shop)
		local item = Instance.new('ImageLabel')
		item.Image = bedwars.getIcon({itemType = itemType}, true)
		item.Size = UDim2.fromOffset(32, 32)
		item.Name = itemType
		item.BackgroundTransparency = 1
		item.LayoutOrder = #UI:GetChildren()
		item.Parent = UI
		local itemtext = Instance.new('TextLabel')
		itemtext.Name = 'Amount'
		itemtext.Size = UDim2.fromScale(1, 1)
		itemtext.BackgroundTransparency = 1
		itemtext.Text = ''
		itemtext.TextColor3 = Color3.new(1, 1, 1)
		itemtext.TextSize = 16
		itemtext.TextStrokeTransparency = 0.3
		itemtext.Font = Enum.Font.Arial
		itemtext.Parent = item
		Items[itemType] = {Object = itemtext, Type = shop}
	end
	
	local function refreshBank(echest)
		for i, v in Items do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end
	
	local function nearChest()
		if entitylib.isAlive then
			local pos = entitylib.character.RootPart.Position
			for _, chest in Chests do
				if (chest.Position - pos).Magnitude < 20 then
					return true
				end
			end
		end
	end
	
	local function handleState()
		local chest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
		if not chest then return end
	
		local mapCF = workspace.MapCFrames:FindFirstChild((lplr:GetAttribute('Team') or 1)..'_spawn')
		if mapCF and (entitylib.character.RootPart.Position - mapCF.Value.Position).Magnitude < 80 then
			for _, v in chest:GetChildren() do
				local item = Items[v.Name]
				if item then
					task.spawn(function()
						bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						refreshBank(chest)
					end)
				end
			end
		else
			for _, v in store.inventory.inventory.items do
				local item = Items[v.itemType]
				if item then
					task.spawn(function()
						bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(chest, v.tool)
						refreshBank(chest)
					end)
				end
			end
		end
	end
	
	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('personal-chest', AutoBank)
				UI = Instance.new('Frame')
				UI.Size = UDim2.new(1, 0, 0, 32)
				UI.Position = UDim2.fromOffset(0, -240)
				UI.BackgroundTransparency = 1
				UI.Visible = UIToggle.Enabled
				UI.Parent = vape.gui
				AutoBank:Clean(UI)
				local Sort = Instance.new('UIListLayout')
				Sort.FillDirection = Enum.FillDirection.Horizontal
				Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
				Sort.SortOrder = Enum.SortOrder.LayoutOrder
				Sort.Parent = UI
				addItem('iron', true)
				addItem('gold', true)
				addItem('diamond', false)
				addItem('emerald', true)
				addItem('void_crystal', true)
	
				repeat
					local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
					hotbar = hotbar and hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
					if hotbar then
						UI.Position = UDim2.fromOffset(0, (hotbar.AbsolutePosition.Y + guiService:GetGuiInset().Y) - 40)
					end
	
					local newState = nearChest()
					if newState then
						handleState()
					end
	
					task.wait(0.1)
				until (not AutoBank.Enabled)
			else
				table.clear(Items)
			end
		end,
		Tooltip = 'Automatically puts resources in ender chest'
	})
	UIToggle = AutoBank:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if AutoBank.Enabled then
				UI.Visible = callback
			end
		end,
		Default = true
	})
end)
	
run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	
	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}
	
	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end
	
	local function buyItem(item, currencytable)
		if not id then return end
		notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
		bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
				bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
			end
		end)
		currencytable[item.currency] -= item.price
	end
	
	local function buyUpgrade(upgradeType, currencytable)
		if not Upgrades.Enabled then return end
		local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
		local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
		local currentTier = (currentUpgrades[upgradeType] or 0) + 1
		local bought = false
	
		for i = currentTier, #upgrade.tiers do
			local tier = upgrade.tiers[i]
			if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
	
			if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
				notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
				bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
				currencytable.diamond -= tier.cost
				bought = true
			else
				break
			end
		end
	
		return bought
	end
	
	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
	
		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if TierCheck.Enabled and v.nextTier then break end
		end
	
		if buyable then
			buyItem(buyable, currencytable)
		end
	
		return bought
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
	
				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					if (npctick - tick()) > 1 then npctick = tick() end
				end))
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController and (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp'))) then
							npc = nil
						end
					end
	
					if npc and lastupgrades ~= upgrades then
						if (npctick - tick()) > 1 then npctick = tick() end
						lastupgrades = upgrades
					end
	
					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								if callback(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						npctick = tick() + (waitcheck and 0.4 or math.huge)
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
	
				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end
	
				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
	TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end
	
						local v = bedwars.Shop.getShopItem(tab[2], lplr)
						if v then
							local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
							item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
							if item > 0 and canBuy(v, currencytable, item) then
								for _ = 1, item do
									buyItem(v, currencytable)
								end
								return true
							end
						end
					end
				end
			end
		end
	})
end)
	
run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					for _ = 1, 4 do
						if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
					end
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
					
					if apple then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = apple.tool
						})
					end
				end
			end
	
			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
	
					if shield then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = shield.tool
						})
					end
				end
			end
		end
	end
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						consumeCheck(attribute)
					end
				end))
				consumeCheck()
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%'
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
end)
	
run(function()
	local AutoHotbar
	local Mode
	local Clear
	local List
	local Active
	
	local function CreateWindow(self)
		local selectedslot = 1
		local window = Instance.new('Frame')
		window.Name = 'HotbarGUI'
		window.Size = UDim2.fromOffset(660, 465)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.BackgroundColor3 = uipallet.Main
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Visible = false
		window.Parent = vape.gui.ScaledGui
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.BackgroundTransparency = 1
		title.Text = 'AutoHotbar'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 40)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		addBlur(window)
		local modal = Instance.new('TextButton')
		modal.Text = ''
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Parent = window
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -35, 0, 9)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getcustomasset('newvape/assets/new/close.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = window
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
			vape.gui.ScaledGui.ClickGui.Visible = true
		end)
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		local bigslot = Instance.new('Frame')
		bigslot.Size = UDim2.fromOffset(110, 111)
		bigslot.Position = UDim2.fromOffset(11, 71)
		bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		bigslot.Parent = window
		local bigslotcorner = Instance.new('UICorner')
		bigslotcorner.CornerRadius = UDim.new(0, 4)
		bigslotcorner.Parent = bigslot
		local bigslotstroke = Instance.new('UIStroke')
		bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
		bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bigslotstroke.Parent = bigslot
		local slotnum = Instance.new('TextLabel')
		slotnum.Size = UDim2.fromOffset(80, 20)
		slotnum.Position = UDim2.fromOffset(25, 200)
		slotnum.BackgroundTransparency = 1
		slotnum.Text = 'SLOT 1'
		slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
		slotnum.TextSize = 12
		slotnum.FontFace = uipallet.Font
		slotnum.Parent = window
		for i = 1, 9 do
			local slotbkg = Instance.new('TextButton')
			slotbkg.Name = 'Slot'..i
			slotbkg.Size = UDim2.fromOffset(51, 52)
			slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = window
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = ''
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			local slotstroke = Instance.new('UIStroke')
			slotstroke.Color = color.Light(uipallet.Main, 0.04)
			slotstroke.Thickness = 2
			slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			slotstroke.Enabled = i == selectedslot
			slotstroke.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				window['Slot'..selectedslot].UIStroke.Enabled = false
				selectedslot = i
				slotstroke.Enabled = true
				slotnum.Text = 'SLOT '..selectedslot
			end)
			slotbkg.MouseButton2Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..i].ImageLabel.Image = ''
					obj.Hotbar[tostring(i)] = nil
					obj.Object['Slot'..i].Image = '	'
				end
			end)
		end
		local searchbkg = Instance.new('Frame')
		searchbkg.Size = UDim2.fromOffset(496, 31)
		searchbkg.Position = UDim2.fromOffset(142, 80)
		searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		searchbkg.Parent = window
		local search = Instance.new('TextBox')
		search.Size = UDim2.new(1, -10, 0, 31)
		search.Position = UDim2.fromOffset(10, 0)
		search.BackgroundTransparency = 1
		search.Text = ''
		search.PlaceholderText = ''
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.TextColor3 = uipallet.Text
		search.TextSize = 12
		search.FontFace = uipallet.Font
		search.ClearTextOnFocus = false
		search.Parent = searchbkg
		local searchcorner = Instance.new('UICorner')
		searchcorner.CornerRadius = UDim.new(0, 4)
		searchcorner.Parent = searchbkg
		local searchicon = Instance.new('ImageLabel')
		searchicon.Size = UDim2.fromOffset(14, 14)
		searchicon.Position = UDim2.new(1, -26, 0, 8)
		searchicon.BackgroundTransparency = 1
		searchicon.Image = getcustomasset('newvape/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		searchicon.Parent = searchbkg
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.fromOffset(500, 240)
		children.Position = UDim2.fromOffset(144, 122)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.FillDirectionMaxCells = 9
		windowlist.CellSize = UDim2.fromOffset(51, 52)
		windowlist.CellPadding = UDim2.fromOffset(4, 3)
		windowlist.Parent = children
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
		end)
		table.insert(vape.Windows, window)
	
		local function createitem(id, image)
			local slotbkg = Instance.new('TextButton')
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = children
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = image
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..selectedslot].ImageLabel.Image = image
					obj.Hotbar[tostring(selectedslot)] = id
					obj.Object['Slot'..selectedslot].Image = image
				end
			end)
		end
	
		local function indexSearch(text)
			for _, v in children:GetChildren() do
				if v:IsA('TextButton') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			if text == '' then
				for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
					createitem(v, bedwars.ItemMeta[v].image)
				end
				return
			end
	
			for i, v in bedwars.ItemMeta do
				if text:lower() == i:lower():sub(1, text:len()) then
					if not v.image then continue end
					createitem(i, v.image)
				end
			end
		end
	
		search:GetPropertyChangedSignal('Text'):Connect(function()
			indexSearch(search.Text)
		end)
		indexSearch('')
	
		return window
	end
	
	vape.Components.HotbarList = function(optionsettings, children, api)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local optionapi = {
			Type = 'HotbarList',
			Hotbars = {},
			Selected = 1
		}
		local hotbarlist = Instance.new('TextButton')
		hotbarlist.Name = 'HotbarList'
		hotbarlist.Size = UDim2.fromOffset(220, 40)
		hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
		hotbarlist.Text = ''
		hotbarlist.BorderSizePixel = 0
		hotbarlist.AutoButtonColor = false
		hotbarlist.Parent = children
		local textbkg = Instance.new('Frame')
		textbkg.Name = 'BKG'
		textbkg.Size = UDim2.new(1, -20, 0, 31)
		textbkg.Position = UDim2.fromOffset(10, 4)
		textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		textbkg.Parent = hotbarlist
		local textbkgcorner = Instance.new('UICorner')
		textbkgcorner.CornerRadius = UDim.new(0, 4)
		textbkgcorner.Parent = textbkg
		local textbutton = Instance.new('TextButton')
		textbutton.Name = 'HotbarList'
		textbutton.Size = UDim2.new(1, -2, 1, -2)
		textbutton.Position = UDim2.fromOffset(1, 1)
		textbutton.BackgroundColor3 = uipallet.Main
		textbutton.Text = ''
		textbutton.AutoButtonColor = false
		textbutton.Parent = textbkg
		textbutton.MouseEnter:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		textbutton.MouseLeave:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)
		local textbuttoncorner = Instance.new('UICorner')
		textbuttoncorner.CornerRadius = UDim.new(0, 4)
		textbuttoncorner.Parent = textbutton
		local textbuttonicon = Instance.new('ImageLabel')
		textbuttonicon.Size = UDim2.fromOffset(12, 12)
		textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
		textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
		textbuttonicon.BackgroundTransparency = 1
		textbuttonicon.Image = getcustomasset('newvape/assets/new/add.png')
		textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
		textbuttonicon.Parent = textbutton
		local childrenlist = Instance.new('Frame')
		childrenlist.Size = UDim2.new(1, 0, 1, -40)
		childrenlist.Position = UDim2.fromOffset(0, 40)
		childrenlist.BackgroundTransparency = 1
		childrenlist.Parent = hotbarlist
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = childrenlist
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
		end)
		textbutton.MouseButton1Click:Connect(function()
			optionapi:AddHotbar()
		end)
		optionapi.Window = CreateWindow(optionapi)
	
		function optionapi:Save(savetab)
			local hotbars = {}
			for _, v in self.Hotbars do
				table.insert(hotbars, v.Hotbar)
			end
			savetab.HotbarList = {
				Selected = self.Selected,
				Hotbars = hotbars
			}
		end
	
		function optionapi:Load(savetab)
			for _, v in self.Hotbars do
				v.Object:ClearAllChildren()
				v.Object:Destroy()
				table.clear(v.Hotbar)
			end
			table.clear(self.Hotbars)
			for _, v in savetab.Hotbars do
				self:AddHotbar(v)
			end
			self.Selected = savetab.Selected or 1
		end
	
		function optionapi:AddHotbar(data)
			local hotbardata = {Hotbar = data or {}}
			table.insert(self.Hotbars, hotbardata)
			local hotbar = Instance.new('TextButton')
			hotbar.Size = UDim2.fromOffset(200, 27)
			hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
			hotbar.Text = ''
			hotbar.AutoButtonColor = false
			hotbar.Parent = childrenlist
			hotbardata.Object = hotbar
			local hotbarcorner = Instance.new('UICorner')
			hotbarcorner.CornerRadius = UDim.new(0, 4)
			hotbarcorner.Parent = hotbar
			for i = 1, 9 do
				local slot = Instance.new('ImageLabel')
				slot.Name = 'Slot'..i
				slot.Size = UDim2.fromOffset(17, 18)
				slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
				slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				slot.BorderSizePixel = 0
				slot.Parent = hotbar
			end
			hotbar.MouseButton1Click:Connect(function()
				local ind = table.find(optionapi.Hotbars, hotbardata)
				if ind == optionapi.Selected then
					vape.gui.ScaledGui.ClickGui.Visible = false
					optionapi.Window.Visible = true
					for i = 1, 9 do
						optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
					end
				else
					if optionapi.Hotbars[optionapi.Selected] then
						optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
					end
					hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					optionapi.Selected = ind
				end
			end)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getcustomasset('newvape/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					ind = table.find(self.Hotbars, obj)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function getBlock()
		local clone = table.clone(store.inventory.inventory.items)
		table.sort(clone, function(a, b)
			return a.amount < b.amount
		end)
	
		for _, item in clone do
			local block = bedwars.ItemMeta[item.itemType].block
			if block and not block.seeThrough then
				return item
			end
		end
	end
	
	local function getCustomItem(v)
		if v == 'diamond_sword' then
			local sword = store.tools.sword
			v = sword and sword.itemType or 'wood_sword'
		elseif v == 'diamond_pickaxe' then
			local pickaxe = store.tools.stone
			v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
		elseif v == 'diamond_axe' then
			local axe = store.tools.wood
			v = axe and axe.itemType or 'wood_axe'
		elseif v == 'wood_bow' then
			local bow = getBow()
			v = bow and bow.itemType or 'wood_bow'
		elseif v == 'wool_white' then
			local block = getBlock()
			v = block and block.itemType or 'wool_white'
		end
	
		return v
	end
	
	local function findItemInTable(tab, item)
		for slot, v in tab do
			if item.itemType == getCustomItem(v) then
				return tonumber(slot)
			end
		end
	end
	
	local function findInHotbar(item)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == item.itemType then
				return i - 1, v.item
			end
		end
	end
	
	local function findInInventory(item)
		for _, v in store.inventory.inventory.items do
			if v.itemType == item.itemType then
				return v
			end
		end
	end
	
	local function dispatch(...)
		bedwars.Store:dispatch(...)
		vapeEvents.InventoryChanged.Event:Wait()
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})
	
		for _, v in store.inventory.inventory.items do
			local slot = findItemInTable(items, v)
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
				end
	
				local newslot = findInHotbar(v)
				if newslot then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					if olditem.item then
						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(olditem.item),
							slot = newslot
						})
					end
				end
	
				dispatch({
					type = 'InventoryAddToHotbar',
					item = findInInventory(v),
					slot = slot - 1
				})
			elseif Clear.Enabled then
				local newslot = findInHotbar(v)
				if newslot then
				   	dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'Automatically arranges hotbar to your liking.'
	})
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)
	
run(function()
	local Value
	local oldclickhold, oldshowprogress
	
	local FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			if callback then
				oldclickhold = bedwars.ClickHold.startClick
				oldshowprogress = bedwars.ClickHold.showProgress
				bedwars.ClickHold.startClick = function(self)
					self.startedClickTime = tick()
					local handle = self:showProgress()
					local clicktime = self.startedClickTime
					bedwars.RuntimeLib.Promise.defer(function()
						task.wait(self.durationSeconds * (Value.Value / 40))
						if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
							self:hideProgress()
							if self.onComplete then self.onComplete() end
							if self.onPartialComplete then self.onPartialComplete(1) end
							self.startedClickTime = -1
						end
					end)
				end
	
				bedwars.ClickHold.showProgress = function(self)
					local roact = debug.getupvalue(oldshowprogress, 1)
					local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
						[roact.Ref] = self.wrapperRef,
						Size = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.8
					}, { roact.createElement('Frame', {
						[roact.Ref] = self.progressRef,
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.5
					}) }) }), lplr:FindFirstChild('PlayerGui'))
	
					self.handle = countdown
					local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
						Size = UDim2.fromScale(0.11, 0.005)
					})
					local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1)
					})
	
					sizetween:Play()
					countdowntween:Play()
					table.insert(self.tweens, countdowntween)
					table.insert(self.tweens, sizetween)
					
					return countdown
				end
			else
				bedwars.ClickHold.startClick = oldclickhold
				bedwars.ClickHold.showProgress = oldshowprogress
				oldclickhold = nil
				oldshowprogress = nil
			end
		end,
		Tooltip = 'Use/Consume items quicker.'
	})
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100
	})
end)
	
run(function()
	local FastDrop
	
	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
						task.spawn(bedwars.ItemDropController.dropItemInHand)
						task.wait()
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			end
		end,
		Tooltip = 'Drops items fast when you hold Q'
	})
end)
	
run(function()
	local BedPlates
	local Background
	local Color
	local LayerCounter
	local LayerColor
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function getBlockLayerHealth(block)
		local meta = bedwars.ItemMeta[block]
		return meta and meta.block and meta.block.health or 0
	end
	
	local function getLayerColor()
		return LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.new(1, 1, 1)
	end
	
	local function scanSide(self, start, tab)
		for _, side in sides do
			local layers = {}
			for i = 1, 15 do
				local block = getPlacedBlock(start + (side * i))
				if not block or block == self or block.Name == 'bed' then
					break
				end
				if not block:GetAttribute('NoBreak') then
					layers[block.Name] = (layers[block.Name] or 0) + 1
				end
			end
	
			for block, amount in layers do
				tab[block] = math.max(tab[block] or 0, amount)
			end
		end
	end
	
	local function refreshAdornee(v)
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local layers = {}
		local alreadygot = {}
		scanSide(v.Adornee, start, layers)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), layers)
		for block, amount in layers do
			table.insert(alreadygot, {block, amount})
		end
		table.sort(alreadygot, function(a, b)
			local healthA, healthB = getBlockLayerHealth(a[1]), getBlockLayerHealth(b[1])
			return healthA == healthB and a[1] < b[1] or healthA > healthB
		end)
		v.Enabled = #alreadygot > 0
	
		for _, blockData in alreadygot do
			local block, amount = blockData[1], blockData[2]
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
			if amount > 1 and (not LayerCounter or LayerCounter.Enabled) then
				local amounttext = Instance.new('TextLabel')
				amounttext.Name = 'Amount'
				amounttext.Size = UDim2.fromScale(1, 1)
				amounttext.BackgroundTransparency = 1
				amounttext.Text = tostring(amount)
				amounttext.TextColor3 = getLayerColor()
				amounttext.TextSize = 16
				amounttext.TextStrokeTransparency = 0.3
				amounttext.Font = Enum.Font.Arial
				amounttext.Parent = blockimage
			end
		end
	end
	
	local function refreshAll()
		for _, v in Reference do
			refreshAdornee(v)
		end
	end
	
	local function updateLayerTextColor()
		local textColor = getLayerColor()
		for _, v in Reference do
			for _, obj in v.Frame:GetDescendants() do
				if obj:IsA('TextLabel') and obj.Name == 'Amount' then
					obj.TextColor3 = textColor
				end
			end
		end
	end
	
	local function Added(v)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	BedPlates = vape.Categories.Minigames:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('bed') do
					task.spawn(Added, v)
				end
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays blocks over the bed'
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then
				Color.Object.Visible = callback
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
	LayerCounter = BedPlates:CreateToggle({
		Name = 'Layer Counter',
		Function = function(callback)
			if LayerColor and LayerColor.Object then
				LayerColor.Object.Visible = callback
			end
			refreshAll()
		end,
		Default = true
	})
	LayerColor = BedPlates:CreateColorSlider({
		Name = 'Counter Text Color',
		Function = function()
			updateLayerTextColor()
		end,
		DefaultSat = 0,
		DefaultValue = 1
	})
end)
	
run(function()
	local Breaker
	local Range
	local BreakSpeed
	local UpdateRate
	local Bed
	local LuckyBlock
	local IronOre
	local Tesla
	local Hive
	local Pinata
	local Crops
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local InstantBreak
	local LimitItem
	local AutoTool
	local MouseDown
	local Snow
	local YetiBreaker
	local RagnarBreaker
	local ShowPath
	local BreakClosest
	local BlockHighlight
	local BreakerHighlightColor
	local BreakerAngle
	local blockHighlightInstance
	local frozenBlockPositions = {}
	local parts = {}
	local lastTier4Break = 0
	local tierTeamIds = { tier99 = {}, tier4 = {} }
	local lastTierCacheUpdate = 0
	local hit = 0
	local cachedTeammates = {}
	local cachedTeammatesTime = 0
	local breakabilityCache = {}
	local BREAK_CACHE_TTL = 0.5

	local function cachedIsBreakable(v)
		local now = tick()
		local cached = breakabilityCache[v]
		if cached and (now - cached.t) < BREAK_CACHE_TTL then
			return cached.v
		end
		local blockPos = bedwars.BlockController:getBlockPosition(v.Position)
		local ok, result = pcall(bedwars.BlockController.isBlockBreakable, bedwars.BlockController, {blockPosition = blockPos}, lplr)
		local val = ok and result
		breakabilityCache[v] = {v = val, t = now}
		return val
	end

	local function updateTierTeamCache()
		local now = tick()
		if now - lastTierCacheUpdate < 3 then return end 
		lastTierCacheUpdate = now
		
		table.clear(tierTeamIds.tier99)
		table.clear(tierTeamIds.tier4)

		for _, player in playersService:GetPlayers() do
			local tier = 0
			if false then
				local teamId = player.Character and (player.Character:GetAttribute('Team') or player.Character:GetAttribute('TeamId'))
				if teamId then
					tierTeamIds.tier99[tonumber(teamId)] = true
				end
			elseif tier == 4 then
				local teamId = player.Character and (player.Character:GetAttribute('Team') or player.Character:GetAttribute('TeamId'))
				if teamId then
					tierTeamIds.tier4[tonumber(teamId)] = true
				end
			end
		end
	end

	local function getPlacerTier(block)
		if not block then return 0 end
		
		updateTierTeamCache()
		
		local blockTeamId = block:GetAttribute('Team') or block:GetAttribute('TeamId')
		if blockTeamId then
			blockTeamId = tonumber(blockTeamId)
			if blockTeamId then
				if tierTeamIds.tier99[blockTeamId] then
					return 99
				elseif tierTeamIds.tier4[blockTeamId] then
					return 4
				end
			end
		end

		local userId = block:GetAttribute('PlacedByUserId')
		if userId then
			local success, player = pcall(playersService.GetPlayerByUserId, playersService, userId)
			if success and player then
				return 0
			end
		end
		
		return 0
	end

	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if block:GetAttribute('NoHealthbar') then return end
		if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
			self.healthbarMaid:DoCleaning()
			self.healthbarBlockRef = blockRef
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			local cleanCheck = true
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			self.healthbarPart = part
			bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)

			local mounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('newvape/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = self.healthbarProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)

			self.healthbarMaid:GiveTask(function()
				cleanCheck = false
				self.healthbarBlockRef = nil
				bedwars.Roact.unmount(mounted)
				if self.healthbarPart then
					self.healthbarPart:Destroy()
				end
				self.healthbarPart = nil
			end)

			bedwars.RuntimeLib.Promise.delay(5):andThen(function()
				if cleanCheck then
					self.healthbarMaid:DoCleaning()
				end
			end)
		end

		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
			Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end

	local function rebuildTeammateCache()
		local now = tick()
		if now - cachedTeammatesTime < 2 then return end
		cachedTeammatesTime = now
		table.clear(cachedTeammates)
		local localTeam = lplr.Team
		if not localTeam then return end
		for _, player in playersService:GetPlayers() do
			if player.Team == localTeam then
				cachedTeammates[player.UserId] = true
			end
		end
	end

	local function isSameTeam(userId)
		if not userId then return false end
		rebuildTeammateCache()
		return cachedTeammates[userId] == true
	end

	local function passesChecks(v)
		local placerTier = 0
		local myTier = 0

		if false then
			return false  
		end

		if placerTier == 4 and myTier == 0 then
			if tick() - lastTier4Break < (1.65 + math.random() * 0.7) then
				return false 
			end
			lastTier4Break = tick() 
		end

		if not SelfBreak.Enabled then
			if v.Name == 'bed' then
				local myTeam = lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId'))
				local bedTeam = v:GetAttribute('Team') or v:GetAttribute('TeamId')
				if not myTeam or not bedTeam or tonumber(bedTeam) == tonumber(myTeam) then 
					return false 
				end
			end

			local blockTeam = v:GetAttribute('Team') or v:GetAttribute('TeamId')
			local myTeam = lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId'))
			
			if blockTeam and myTeam and tonumber(blockTeam) == tonumber(myTeam) then
				return false
			end

			if v:GetAttribute('PlacedByUserId') == lplr.UserId then 
				return false 
			end
			
			if isSameTeam(v:GetAttribute('PlacedByUserId')) then 
				return false 
			end
		end

		if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then 
			return false 
		end
		
		if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then 
			return false 
		end
		
		return true
	end

	local function wrappedHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if BlockHighlight and BlockHighlight.Enabled and blockHighlightInstance then
			blockHighlightInstance.Size = block.Size + Vector3.new(0.01, 0.01, 0.01)
			blockHighlightInstance.Adornee = block
		end
		if CustomHealth.Enabled then
			customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		end
	end

	-- Updated doBreak: respect BreakSpeed when BreakClosest is enabled (unless InstantBreak is explicitly on)
	local function doBreak(v, isPathBlock)
		hit += 1
		if RagnarBreaker and RagnarBreaker.Enabled then
			if store.equippedKit == 'berserker' and bedwars.AbilityController and bedwars.AbilityController:canUseAbility("berserker_rage") then
				replicatedStorage:WaitForChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"):WaitForChild("useAbility"):FireServer("berserker_rage")
			end
		end

		if BreakClosest and BreakClosest.Enabled then
			bedwars.breakClosestMode = true
		end

		-- compute explicit instant flag; keep original logic but allow BreakClosest to disable it unless InstantBreak is on
		local instantFlag = ((InstantBreak and InstantBreak.Enabled) or (AutoTool and AutoTool.Enabled)) and (LimitItem and LimitItem.Enabled)

		if BreakClosest and BreakClosest.Enabled and not (InstantBreak and InstantBreak.Enabled) then
			instantFlag = false
		end

		local target, path, endpos = bedwars.breakBlock(v, Effect and Effect.Enabled, Animation and Animation.Enabled, wrappedHealthbar, instantFlag)
		bedwars.breakClosestMode = false
		if path and ShowPath and ShowPath.Enabled then
			local placerTier = 0
			if false then
				task.wait(0.65 + math.random() * 0.4)  
			end
			local currentnode = target
			for _, part in parts do
				part.Position = currentnode or Vector3.zero
				if currentnode then
					part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
				end
				currentnode = path[currentnode]
			end
		end
		task.wait(isPathBlock and 0 or ((InstantBreak and InstantBreak.Enabled) and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value))
		return true
	end

	local function doBreakDirect(block)
		if not block or not block.Parent then return end
		local blockPos = bedwars.BlockController:getBlockPosition(block.Position)
		pcall(function()
			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = blockPos},
				hitPosition = block.Position,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			})
		end)
		task.wait(BreakSpeed.Value)
	end

	local function findPathBlock(targetPos, playerPos)
		local dir = (targetPos - playerPos)
		local distance = dir.Magnitude
		if distance < 3 then return nil end
		dir = dir.Unit
		local checked = {}
		local step = 3
		for i = step, distance - step, step do
			local checkPos = roundPos(playerPos + dir * i)
			local key = checkPos.X .. ',' .. checkPos.Y .. ',' .. checkPos.Z
			if checked[key] then continue end
			checked[key] = true
			if (checkPos - targetPos).Magnitude < 2.5 then continue end
			if (checkPos - playerPos).Magnitude < 3 then continue end
			local block = getPlacedBlock(checkPos)
			if block then
				local ok, canBreak = pcall(bedwars.BlockController.isBlockBreakable, bedwars.BlockController, {blockPosition = checkPos / 3}, lplr)
				if ok and canBreak and passesChecks(block) then
					return block
				end
			end
		end
		return nil
	end

	local function isYetiBlock(block)
		if not block then return false end
		local pos = block.Position / 3
		local key = math.round(pos.X) .. ',' .. math.round(pos.Y) .. ',' .. math.round(pos.Z)
		return frozenBlockPositions[key] == true
	end

	local function hookFreezeController()
		local FreezeCtrl = (bedwars.KnitClient and bedwars.KnitClient.Controllers and bedwars.KnitClient.Controllers.FreezeBlocksController)
			or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.FreezeBlocksController)
		if not FreezeCtrl or not FreezeCtrl.freezeBlocks then return end
		local oldFreeze = FreezeCtrl.freezeBlocks
		FreezeCtrl.freezeBlocks = function(self, position, frozenBlocks, ...)
			table.clear(frozenBlockPositions)
			if type(frozenBlocks) == 'table' then
				for _, v in frozenBlocks do
					local pos
					if typeof(v) == 'Vector3' then
						pos = v
					elseif type(v) == 'table' then
						pos = v.position or v.blockPosition or v.pos
					elseif typeof(v) == 'Instance' and v:IsA('BasePart') then
						pos = v.Position / 3
					end
					if pos then
						local key = math.round(pos.X) .. ',' .. math.round(pos.Y) .. ',' .. math.round(pos.Z)
						frozenBlockPositions[key] = true
					end
				end
			end
			task.delay(8, function() table.clear(frozenBlockPositions) end)
			return oldFreeze(self, position, frozenBlocks, ...)
		end
		Breaker:Clean(function()
			pcall(function() FreezeCtrl.freezeBlocks = oldFreeze end)
		end)
	end

	local function findYetiPathBlock(bedPos, playerPos)
		local dir = (bedPos - playerPos)
		local distance = dir.Magnitude
		if distance < 3 then return nil end
		dir = dir.Unit
		local step = 3
		local bestYeti, bestDist = nil, math.huge
		for i = step, distance - step, step do
			local checkPos = roundPos(playerPos + dir * i)
			if (checkPos - bedPos).Magnitude < 4 then continue end
			local block = getPlacedBlock(checkPos)
			if block and isYetiBlock(block) then
				local nextStepPos = roundPos(checkPos + dir * step)
				local nextBlock = getPlacedBlock(nextStepPos)
				if not nextBlock then continue end
				local dist = (checkPos - bedPos).Magnitude
				if dist < bestDist and bedwars.BlockController:isBlockBreakable({blockPosition = checkPos / 3}, lplr) and passesChecks(block) then
					bestYeti = block
					bestDist = dist
				end
			end
		end
		return bestYeti
	end

	local function attemptBreak(tab, localPosition, skipBreakCheck)
		if not tab then return false end
		if MouseDown and MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end
		local best, bestDist = nil, math.huge
		for _, v in tab do
			local dist = (v.Position - localPosition).Magnitude
			if dist >= Range.Value or dist >= bestDist then continue end
			if not skipBreakCheck and v.Name ~= 'bed' then
				if not cachedIsBreakable(v) then continue end
			end
			if not passesChecks(v) then continue end
			best = v
			bestDist = dist
		end
		if not best then return false end
		return doBreak(best)
	end

	local function attemptBreakNamed(names, localPosition)
		if names == nil then
			names = {}
		end
		if MouseDown and MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return false end
		local best, bestDist = nil, math.huge
		for _, v in store.blocks do
			if v and v:IsA('BasePart') and table.find(names, v.Name) then
				local dist = (v.Position - localPosition).Magnitude
				if dist < Range.Value and dist < bestDist then
					if cachedIsBreakable(v) and passesChecks(v) then
						if true then
							best = v
							bestDist = dist
						end
					end
				end
			end
		end
		if best then return doBreak(best) end
		return false
	end

	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				if ShowPath and ShowPath.Enabled then
					for _ = 1, 8 do
						local part = Instance.new('Part')
						part.Anchored = true
						part.CanQuery = false
						part.CanCollide = false
						part.Transparency = 1
						part.Parent = gameCamera
						local highlight = Instance.new('BoxHandleAdornment')
						highlight.Size = Vector3.one
						highlight.AlwaysOnTop = true
						highlight.ZIndex = 1
						highlight.Transparency = 0.5
						highlight.Adornee = part
						highlight.Parent = part
						table.insert(parts, part)
					end
				end

				if BlockHighlight and BlockHighlight.Enabled then
					blockHighlightInstance = Instance.new('BoxHandleAdornment')
					blockHighlightInstance.AlwaysOnTop = true
					blockHighlightInstance.ZIndex = 10
					blockHighlightInstance.Transparency = 0.3
					blockHighlightInstance.Color3 = BreakerHighlightColor and Color3.fromHSV(BreakerHighlightColor.Hue, BreakerHighlightColor.Sat, BreakerHighlightColor.Value) or Color3.fromRGB(255, 255, 0)
					blockHighlightInstance.Parent = gameCamera
				end
				
				task.spawn(hookFreezeController)
				local beds = collection('bed', Breaker)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron_ore_mesh_block', Breaker)

				local trackedSpecial = {tesla_trap={}, beehive={}, pinata={}, carrot={}, melon={}, pumpkin={}, snow_pile={}} 
				local _trackedNames = {tesla_trap = true, beehive = true, pinata = true, carrot = true, melon = true, pumpkin = true, snow_pile = true}

			local function trackAdd(obj)
				if not _trackedNames[obj.Name] then return end
				local t = trackedSpecial[obj.Name]
				if not t then return end
				if obj:IsA('BasePart') then
					table.insert(t, obj)
				elseif obj:IsA('Model') then
					local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
					if part then table.insert(t, part) end
				end
			end

			local function trackRemove(obj)
				if not _trackedNames[obj.Name] then return end
				local t = trackedSpecial[obj.Name]
				if t then
					if obj:IsA('BasePart') then
						local i = table.find(t, obj)
						if i then table.remove(t, i) end
					elseif obj:IsA('Model') then
						local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
						if part then
							local i = table.find(t, part)
							if i then table.remove(t, i) end
						end
					end
				end
				breakabilityCache[obj] = nil
			end

			for _, obj in workspace:GetDescendants() do trackAdd(obj) end
			Breaker:Clean(workspace.DescendantAdded:Connect(trackAdd))
			Breaker:Clean(workspace.DescendantRemoving:Connect(trackRemove))

				local lockedPathBlock = nil
				repeat
					task.wait(1 / math.clamp(UpdateRate.Value, 1, 60))
					if not Breaker.Enabled then break end
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position

						if Bed.Enabled and YetiBreaker and YetiBreaker.Enabled then
							local foundYeti = false
							for _, bed in beds do
								if foundYeti then break end
								if (bed.Position - localPosition).Magnitude < Range.Value then
									local yetiBlock = findYetiPathBlock(bed.Position, localPosition)
									if yetiBlock then
										doBreak(yetiBlock)
										foundYeti = true
									end
								end
							end
							if foundYeti then continue end
						end

						local best, bestDist = nil, math.huge
						local _blockPosArg = {}
						local function eval(tab, skip)
							if not tab then return end
							for _, v in tab do
								if not v or not v.Parent then continue end
								local dist = (v.Position - localPosition).Magnitude
								if dist >= Range.Value or dist >= bestDist then continue end
								if not skip and v.Name ~= 'bed' then
									if not cachedIsBreakable(v) then continue end
								end
								if not passesChecks(v) then continue end
								if BreakerAngle and BreakerAngle.Value < 360 then
									local hrp = entitylib.character and entitylib.character.RootPart
									if hrp then
										local toBlock = (v.Position - hrp.Position).Unit
										local dot = hrp.CFrame.LookVector:Dot(toBlock)
										local angleToBlock = math.deg(math.acos(math.clamp(dot, -1, 1)))
										if angleToBlock > BreakerAngle.Value / 2 then continue end
									end
								end
								best = v
								bestDist = dist
							end
						end
						eval(Bed.Enabled and beds, true)
						if not best then
							eval(LuckyBlock.Enabled and luckyblock, true)
							eval(IronOre.Enabled and ironores, true)
							eval(Tesla and Tesla.Enabled and trackedSpecial.tesla_trap, true)
							eval(Snow and Snow.Enabled and trackedSpecial.snow_pile, true)
							eval(Hive and Hive.Enabled and trackedSpecial.beehive)
							eval(Pinata and Pinata.Enabled and trackedSpecial.pinata, true)
							if Crops and Crops.Enabled then
								eval(trackedSpecial.carrot, true)
								eval(trackedSpecial.melon, true)
								eval(trackedSpecial.pumpkin, true)
							end
						end
					
						if best then
							if not MouseDown or not MouseDown.Enabled or inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
								if BreakClosest and BreakClosest.Enabled then
									local underBlock = getPlacedBlock(roundPos(localPosition - Vector3.new(0, 3, 0)))
									if underBlock and underBlock ~= best and passesChecks(underBlock) then
										local bpos = bedwars.BlockController:getBlockPosition(underBlock.Position)
										local ok, canBreak = pcall(bedwars.BlockController.isBlockBreakable, bedwars.BlockController, {blockPosition = bpos}, lplr)
										if ok and canBreak then
											doBreak(underBlock, true)
											continue
										end
									end
									local pathBlock = findPathBlock(best.Position, localPosition)
									if pathBlock then
										doBreak(pathBlock, true)
									else
										doBreak(best, false)
									end
								else
									doBreak(best, false)
								end
								continue
							end
						end

						if BlockHighlight and BlockHighlight.Enabled and blockHighlightInstance then
							blockHighlightInstance.Adornee = nil
						end
						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Breaker.Enabled
			else
				table.clear(breakabilityCache)
				if blockHighlightInstance then
					blockHighlightInstance:Destroy()
					blockHighlightInstance = nil
				end
				for _, v in parts do
					v:ClearAllChildren()
					v:Destroy()
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Break blocks around you automatically'
	})

	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BreakSpeed = Breaker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Snow = Breaker:CreateToggle({
		Name = 'Break Snow',
		Default = false
	})
	Tesla = Breaker:CreateToggle({
		Name = 'Break Tesla',
		Default = true
	})
	Hive = Breaker:CreateToggle({
		Name = 'Break Hive',
		Default = true
	})
	Pinata = Breaker:CreateToggle({
		Name = 'Break Pinata',
		Default = false
	})
	Crops = Breaker:CreateToggle({
		Name = 'Break Crops',
		Default = false,
		Tooltip = 'Breaks pumpkin, carrot and watermelon crops '
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({Name = 'Animation'})
	SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
	InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Tooltip = 'Automatically switches to the best tool for breaking blocks'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
	MouseDown = Breaker:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'Only breaks blocks when holding left click'
	})
	YetiBreaker = Breaker:CreateToggle({
		Name = 'Yeti Breaker',
		Tooltip = 'Focuses on frozen blocks'
	})
	RagnarBreaker = Breaker:CreateToggle({
		Name = 'Ragnar',
		Tooltip = 'pops the ragnar ability whenever nuking'
	})
	BreakClosest = Breaker:CreateToggle({
		Name = 'Break Closest',
		Default = false,
		Tooltip = 'Prioritizes breaking blocks closest to your character instead of the optimal path'
	})
	ShowPath = Breaker:CreateToggle({
		Name = 'Show Path',
		Default = true,
		Tooltip = 'Show the path boxes when breaking blocks'
	})
	BlockHighlight = Breaker:CreateToggle({
		Name = 'Block Highlight',
		Default = false,
		Tooltip = 'Highlights the block currently being broken',
		Function = function(callback)
			if BreakerHighlightColor and BreakerHighlightColor.Object then
				BreakerHighlightColor.Object.Visible = callback
			end
			if callback then
				if Breaker.Enabled then
					blockHighlightInstance = Instance.new('BoxHandleAdornment')
					blockHighlightInstance.AlwaysOnTop = true
					blockHighlightInstance.ZIndex = 10
					blockHighlightInstance.Transparency = 0.3
					blockHighlightInstance.Color3 = BreakerHighlightColor and Color3.fromHSV(BreakerHighlightColor.Hue, BreakerHighlightColor.Sat, BreakerHighlightColor.Value) 
					blockHighlightInstance.Parent = gameCamera
				end
			else
				table.clear(breakabilityCache)
				if blockHighlightInstance then
					blockHighlightInstance:Destroy()
					blockHighlightInstance = nil
				end
			end
		end
	})
	BreakerHighlightColor = Breaker:CreateColorSlider({
		Name = 'Highlight Color',
		Darker = true,
		DefaultHue = 0.167,
		DefaultOpacity = 0.2,
		Visible = false,
		Tooltip = 'Color of the block highlight',
		Function = function(hue, sat, val)
			if blockHighlightInstance then
				blockHighlightInstance.Color3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})

	BreakerAngle = Breaker:CreateSlider({
		Name = 'Break Angle',
		Min = 0,
		Max = 360,
		Default = 360,
		Tooltip = 'only break blocks within this angle of your look direction 360 = all directions'
	})

	task.defer(function()
		if CustomHealth and CustomHealth.Object then
			CustomHealth.Object.Visible = Effect.Enabled
		end
	end)
end)

	
run(function()
	local BedBreakEffect
	local Mode
	local List
	local NameToId = {}
	
	BedBreakEffect = vape.Legit:CreateModule({
		Name = 'Bed Break Effect',
		Function = function(callback)
			if callback then
	            BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
	                firesignal(bedwars.Client:Get('BedBreakEffectTriggered').instance.OnClientEvent, {
	                    player = data.player,
	                    position = data.bedBlockPosition * 3,
	                    effectType = NameToId[List.Value],
	                    teamId = data.brokenBedTeam.id,
	                    centerBedPosition = data.bedBlockPosition * 3
	                })
	            end))
	        end
		end,
		Tooltip = 'Custom bed break effects'
	})
	local BreakEffectName = {}
	for i, v in bedwars.BedBreakEffectMeta do
		table.insert(BreakEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(BreakEffectName)
	List = BedBreakEffect:CreateDropdown({
		Name = 'Effect',
		List = BreakEffectName
	})
end)
	
run(function()
	vape.Legit:CreateModule({
		Name = 'Clean Kit',
		Function = function(callback)
			if callback then
				bedwars.WindWalkerController.spawnOrb = function() end
				local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
				if zephyreffect then 
					zephyreffect.Visible = false 
				end
			end
		end,
		Tooltip = 'Removes zephyr status indicator'
	})
end)
	
run(function()
	local old
	local Image
	
	local Crosshair = vape.Legit:CreateModule({
		Name = 'Crosshair',
		Function = function(callback)
			if callback then
				old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, 25)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, Image.Value)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, Image.Value)
			else
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, old)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, old)
				old = nil
			end
	
			if bedwars.ViewmodelController.crosshair then
				bedwars.ViewmodelController:hideCrosshair()
				bedwars.ViewmodelController:showCrosshair()
			end
		end,
		Tooltip = 'Custom first person crosshair depending on the image choosen.'
	})
	Image = Crosshair:CreateTextBox({
		Name = 'Image',
		Placeholder = 'image id (roblox)',
		Function = function(enter)
			if enter and Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end
	})
end)
	
run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke
	local suc, tab = pcall(function()
		return debug.getupvalue(bedwars.DamageIndicator, 2)
	end)
	tab = suc and tab or {}
	local oldvalues, oldfont = {}
	
	DamageIndicator = vape.Legit:CreateModule({
		Name = 'Damage Indicator',
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfont = debug.getconstant(bedwars.DamageIndicator, 86)
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[FontOption.Value])
				debug.setconstant(bedwars.DamageIndicator, 119, Stroke.Enabled and 'Thickness' or 'Enabled')
				tab.strokeThickness = Stroke.Enabled and 1 or false
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				debug.setconstant(bedwars.DamageIndicator, 86, oldfont)
				debug.setconstant(bedwars.DamageIndicator, 119, 'Thickness')
			end
		end,
		Tooltip = 'Customize the damage indicator'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[val])
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 119, callback and 'Thickness' or 'Enabled')
				tab.strokeThickness = callback and 1 or false
			end
		end
	})
end)
	
run(function()
	local FOV
	local Value
	local old, old2
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				old = bedwars.FovController.setFOV
				old2 = bedwars.FovController.getFOV
				bedwars.FovController.setFOV = function(self) 
					return old(self, Value.Value) 
				end
				bedwars.FovController.getFOV = function() 
					return Value.Value 
				end
			else
				bedwars.FovController.setFOV = old
				bedwars.FovController.getFOV = old2
			end
			
			bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
	
run(function()
	local FPSBoost
	local Kill
	local Visualizer
	local effects, util = {}, {}
	
	FPSBoost = vape.Legit:CreateModule({
		Name = 'FPS Boost',
		Function = function(callback)
			if callback then
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							effects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function() 
									return {
										onKill = function() end, 
										isPlayDefaultKillEffect = function() 
											return true 
										end
									} 
								end
							}
						end
					end
				end
	
				if Visualizer.Enabled then
					for i, v in bedwars.VisualizerUtils do
						util[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
	
				repeat task.wait() until store.matchState ~= 0
				if not bedwars.AppController then return end
				bedwars.NametagController.addGameNametag = function() end
				for _, v in bedwars.AppController:getOpenApps() do
					if tostring(v):find('Nametag') then
						bedwars.AppController:closeApp(tostring(v))
					end
				end
			else
				for i, v in effects do 
					bedwars.KillEffectController.killEffects[i] = v 
				end
				for i, v in util do 
					bedwars.VisualizerUtils[i] = v 
				end
				table.clear(effects)
				table.clear(util)
			end
		end,
		Tooltip = 'Improves the framerate by turning off certain effects'
	})
	Kill = FPSBoost:CreateToggle({
		Name = 'Kill Effects',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
	Visualizer = FPSBoost:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Legit:CreateModule({
		Name = 'Hit Color',
		Function = function(callback)
			if callback then 
				repeat
					for i, v in entitylib.List do 
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then 
							if not table.find(done, highlight) then 
								table.insert(done, highlight) 
							end
							highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
							highlight.FillTransparency = Color.Opacity
						end
					end
					task.wait(0.1)
				until not HitColor.Enabled
			else
				for i, v in done do 
					v.FillColor = Color3.new(1, 0, 0)
					v.FillTransparency = 0.4
				end
				table.clear(done)
			end
		end,
		Tooltip = 'Customize the hit highlight options'
	})
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)
	
run(function()
	vape.Legit:CreateModule({
		Name = 'HitFix',
		Function = function(callback)
			debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
			debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
		end,
		Tooltip = 'Changes the raycast function to the correct one'
	})
end)
	
run(function()
	local Interface
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local old, new = {}, {}
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val
	
		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	Interface = vape.Legit:CreateModule({
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
		end,
		Tooltip = 'Customize bedwars UI'
	})
	local fontitems = {'LuckiestGuy'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'LuckiestGuy' then
			table.insert(fontitems, v.Name)
		end
	end
	Interface:CreateDropdown({
		Name = 'Health Font',
		List = fontitems,
		Function = function(val)
			modifyconstant(HotbarHealthbar.render, 77, val)
		end
	})
	Interface:CreateColorSlider({
		Name = 'Health Color',
		Function = function(hue, sat, val)
			modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			if Interface.Enabled then
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
				if hotbar then
					hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			end
		end
	})
	Interface:CreateColorSlider({
		Name = 'Hotbar Color',
		DefaultOpacity = 0.8,
		Function = function(hue, sat, val, opacity)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		end
	})
end)
	
run(function()
	local KillEffect
	local Mode
	local List
	local NameToId = {}
	
	local killeffects = {
		Gravity = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			local nametag = char:FindFirstChild('Nametag', true)
			if highlight then
				highlight:Destroy()
			end
			if nametag then
				nametag:Destroy()
			end
	
			task.spawn(function()
				local partvelo = {}
				for _, v in char:GetDescendants() do
					if v:IsA('BasePart') then
						partvelo[v.Name] = v.Velocity
					end
				end
				char.Archivable = true
				local clone = char:Clone()
				clone.Humanoid.Health = 100
				clone.Parent = workspace
				game:GetService('Debris'):AddItem(clone, 30)
				char:Destroy()
				task.wait(0.01)
				clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				clone:BreakJoints()
				task.wait(0.01)
				for _, v in clone:GetDescendants() do
					if v:IsA('BasePart') then
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
						bodyforce.Parent = v
						v.CanCollide = true
						v.Velocity = partvelo[v.Name] or Vector3.zero
					end
				end
			end)
		end,
		Lightning = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			if highlight then
				highlight:Destroy()
			end
			local startpos = 1125
			local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
			local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)
	
			for i = startpos - 75, 0, -75 do
				local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
				if i == 0 then
					newpos2 = Vector3.zero
				end
				local part = Instance.new('Part')
				part.Size = Vector3.new(1.5, 1.5, 77)
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored = true
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
				part.Parent = workspace
				local part2 = part:Clone()
				part2.Size = Vector3.new(3, 3, 78)
				part2.Color = Color3.new(0.7, 0.7, 0.7)
				part2.Transparency = 0.7
				part2.Material = Enum.Material.SmoothPlastic
				part2.Parent = workspace
				game:GetService('Debris'):AddItem(part, 0.5)
				game:GetService('Debris'):AddItem(part2, 0.5)
				bedwars.QueryUtil:setQueryIgnored(part, true)
				bedwars.QueryUtil:setQueryIgnored(part2, true)
				if i == 0 then
					local soundpart = Instance.new('Part')
					soundpart.Transparency = 1
					soundpart.Anchored = true
					soundpart.Size = Vector3.zero
					soundpart.Position = startcf
					soundpart.Parent = workspace
					bedwars.QueryUtil:setQueryIgnored(soundpart, true)
					local sound = Instance.new('Sound')
					sound.SoundId = 'rbxassetid://6993372814'
					sound.Volume = 2
					sound.Pitch = 0.5 + (math.random(1, 3) / 10)
					sound.Parent = soundpart
					sound:Play()
					sound.Ended:Connect(function()
						soundpart:Destroy()
					end)
				end
				newpos = newpos2
			end
		end,
		Delete = function(_, _, char, _)
			char:Destroy()
		end
	}
	
	KillEffect = vape.Legit:CreateModule({
		Name = 'Kill Effect',
		Function = function(callback)
			if callback then
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = {
						new = function()
							return {
								onKill = v,
								isPlayDefaultKillEffect = function()
									return false
								end
							}
						end
					}
				end
				KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
					lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
				end))
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			else
				for i in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = nil
				end
				lplr:SetAttribute('KillEffectType', 'default')
			end
		end,
		Tooltip = 'Custom final kill effects'
	})
	local modes = {'Bedwars'}
	for i in killeffects do
		table.insert(modes, i)
	end
	Mode = KillEffect:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Function = function(val)
			List.Object.Visible = val == 'Bedwars'
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
			end
		end
	})
	local KillEffectName = {}
	for i, v in bedwars.KillEffectMeta do
		table.insert(KillEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(KillEffectName)
	List = KillEffect:CreateDropdown({
		Name = 'Bedwars',
		List = KillEffectName,
		Function = function(val)
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', NameToId[val])
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local ReachDisplay
	local label
	
	ReachDisplay = vape.Legit:CreateModule({
		Name = 'Reach Display',
		Function = function(callback)
			if callback then
				repeat
					label.Text = (store.attackReachUpdate > tick() and store.attackReach or '0.00')..' studs'
					task.wait(0.4)
				until not ReachDisplay.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41)
	})
	ReachDisplay:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	ReachDisplay:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0.00 studs'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = ReachDisplay.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = tick()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then 
			table.clear(alreadypicked) 
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat 
				task.wait() 
				chosensong = list[math.random(1, #list)] 
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = tick() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				repeat
					if not songobj.Playing then choosesong() end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
						songtween:Play()
					end
					task.wait()
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
				if songtween then
					songtween:Cancel()
				end
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then 
				songobj.Volume = val / 100 
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local SoundChanger
	local List
	local soundlist = {}
	local old
	
	SoundChanger = vape.Legit:CreateModule({
		Name = 'SoundChanger',
		Function = function(callback)
			if callback then
				old = bedwars.SoundManager.playSound
				bedwars.SoundManager.playSound = function(self, id, ...)
					if soundlist[id] then
						id = soundlist[id]
					end
	
					return old(self, id, ...)
				end
			else
				bedwars.SoundManager.playSound = old
				old = nil
			end
		end,
		Tooltip = 'Change ingame sounds to custom ones.'
	})
	List = SoundChanger:CreateTextList({
		Name = 'Sounds',
		Placeholder = '(DAMAGE_1/ben.mp3)',
		Function = function()
			table.clear(soundlist)
			for _, entry in List.ListEnabled do
				local split = entry:split('/')
				local id = bedwars.SoundList[split[1]]
				if id and #split > 1 then
					soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
				end
			end
		end
	})
end)
	
run(function()
	local UICleanup
	local OpenInv
	local KillFeed
	local OldTabList
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local old, new = {}, {}
	local oldkillfeed
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			local typing = type(old[func][ind])
			if typing == 'function' or typing == 'userdata' then return end
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) and val ~= nil then return end
	
		new[func][ind] = val
		if UICleanup.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	UICleanup = vape.Legit:CreateModule({
		Name = 'UI Cleanup',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				if OpenInv.Enabled then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				end
	
				if KillFeed.Enabled then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
				end
			else
				if oldinvrender then
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
	
				if KillFeed.Enabled then
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end
			end
		end,
		Tooltip = 'Cleans up the UI for kits & main'
	})
	UICleanup:CreateToggle({
		Name = 'Resize Health',
		Function = function(callback)
			modifyconstant(HotbarApp, 60, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 15).render, 30, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 23).tweenPosition, 16, callback and 0 or nil)
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'No Hotbar Numbers',
		Function = function(callback)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 90, callback and 0 or nil)
			modifyconstant(func, 71, callback and 0 or nil)
		end,
		Default = true
	})
	OpenInv = UICleanup:CreateToggle({
		Name = 'No Inventory Button',
		Function = function(callback)
			modifyconstant(HotbarApp, 78, callback and 0 or nil)
			if UICleanup.Enabled then
				if callback then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				else
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
			end
		end,
		Default = true
	})
	KillFeed = UICleanup:CreateToggle({
		Name = 'No Kill Feed',
		Function = function(callback)
			if UICleanup.Enabled then
				if callback then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				else
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
			end
		end,
		Default = true
	})
	OldTabList = UICleanup:CreateToggle({
		Name = 'Old Player List',
		Function = function(callback)
			if UICleanup.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
			end
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'Fix Queue Card',
		Function = function(callback)
			modifyconstant(bedwars.QueueCard.render, 15, callback and 0.1 or nil)
		end,
		Default = true
	})
end)
	
run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local NoBob
	local Rots = {}
	local old, oldc1
	
	Viewmodel = vape.Legit:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if callback then
				old = bedwars.ViewmodelController.playAnimation
				oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
				if NoBob.Enabled then
					bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
						if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
						return old(self, animtype, ...)
					end
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				if viewmodel then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
			else
				bedwars.ViewmodelController.playAnimation = old
				if viewmodel then
					viewmodel.RightHand.RightWrist.C1 = oldc1
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
				old = nil
			end
		end,
		Tooltip = 'Changes the viewmodel animations'
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
			end
		end
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
			end
		end
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -0.2,
		Max = 2,
		Default = -0.2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, Viewmodel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				if Viewmodel.Enabled then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
			end
		}))
	end
	NoBob = Viewmodel:CreateToggle({
		Name = 'No Bobbing',
		Default = true,
		Function = function()
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end
	})
end)
	
run(function()
	local WinEffect
	local List
	local NameToId = {}
	
	WinEffect = vape.Legit:CreateModule({
		Name = 'WinEffect',
		Function = function(callback)
			if callback then
				WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					for i, v in getconnections(bedwars.Client:Get('WinEffectTriggered').instance.OnClientEvent) do
						if v.Function then
							v.Function({
								winEffectType = NameToId[List.Value],
								winningPlayer = lplr
							})
						end
					end
				end))
			end
		end,
		Tooltip = 'Allows you to select any clientside win effect'
	})
	local WinEffectName = {}
	for i, v in bedwars.WinEffectMeta do
		table.insert(WinEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(WinEffectName)
	List = WinEffect:CreateDropdown({
		Name = 'Effects',
		List = WinEffectName
	})
end)

run(function()
	local AutoDavey
	local Switch
	local Break
	local Jump
	local LimitItem
	
	local old, oldAim
	
	local function canBreak()
		if not LimitItem.Enabled then return true end
		local itemmeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
		return itemmeta ~= nil and itemmeta.breakBlock ~= nil
	end
	
	local function breakCannon(block)
		local deadline = tick() + 0.6 + (store.ping.total or 0)
	
		repeat
			if not AutoDavey.Enabled or not entitylib.isAlive or not canBreak() then return end
			if (block.Position - entitylib.character.RootPart.Position).Magnitude > 30 then return end
			bedwars.breakBlock(block, true, true, nil, Switch.Enabled)
			task.wait(0.1)
		until not block.Parent or tick() > deadline
	end
	
	AutoDavey = vape.Categories.Minigames:CreateModule({
		Name = 'AutoDavey',
		Function = function(callback)
			if callback then
				oldAim = bedwars.CannonController.startAiming
				bedwars.CannonController.startAiming = function(self, block, ...)
					local call = oldAim(self, block, ...)
	
					if Break.Enabled and block and block.Parent and entitylib.isAlive and canBreak() and getBlockHits(block, block.Position) > 1 then
						task.spawn(breakCannon, block)
					end
	
					return call
				end
	
				old = bedwars.CannonHandController.launchSelf
				bedwars.CannonHandController.launchSelf = function(self, block, ...)
					if Break.Enabled and block and block.Parent and entitylib.isAlive and (block.Position - entitylib.character.RootPart.Position).Magnitude <= 30 and canBreak() then
						task.spawn(breakCannon, block)
					end
	
					local call = old(self, block, ...)
	
					if Jump.Enabled and entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					return call
				end
			else
				bedwars.CannonHandController.launchSelf = old
				bedwars.CannonController.startAiming = oldAim
			end
		end,
		Tooltip = 'Automatically breaks cannon/jump on launch'
	})
	Jump = AutoDavey:CreateToggle({Name = 'Jump on impact'})
	
	Break = AutoDavey:CreateToggle({Name = 'Break on impact'})
	
	Switch = AutoDavey:CreateToggle({Name = 'Legit switch'})
	
	LimitItem = AutoDavey:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
end) 

run(function()
    local HitFix
	local PingBased
	local Options
    HitFix = vape.Categories.Blatant:CreateModule({
        Name = 'HitFix',
        Function = function(callback)
            local function getPing()
                local stats = game:GetService("Stats")
                local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
                return tonumber(ping:match("%d+")) or 50
            end

            local function getDelay()
                local ping = getPing()

                if PingBased.Enabled then
                    if Options.Value == "Blatant" then
                        return math.clamp(0.08 + (ping / 1000), 0.08, 0.14)
                    else
                        return math.clamp(0.11 + (ping / 1200), 0.11, 0.15)
                    end
                end

                return Options.Value == "Blatant" and 0.1 or 0.13
            end

            if callback then
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        local func = bedwars.SwordController.swingSwordAtMouse

                        if Options.Value == "Blatant" then
                            debug.setconstant(func, 23, "raycast")
                            debug.setupvalue(func, 4, bedwars.QueryUtil)
                        end

                        for i, v in ipairs(debug.getconstants(func)) do
                            if typeof(v) == "number" and (v == 0.15 or v == 0.1) then
                                debug.setconstant(func, i, getDelay())
                            end
                        end
                    end
                end)
            else
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        local func = bedwars.SwordController.swingSwordAtMouse

                        debug.setconstant(func, 23, "Raycast")
                        debug.setupvalue(func, 4, workspace)

                        for i, v in ipairs(debug.getconstants(func)) do
                            if typeof(v) == "number" then
                                if v < 0.15 then
                                    debug.setconstant(func, i, 0.15)
                                end
                            end
                        end
                    end
                end)
            end
        end,
        Tooltip = 'Improves hit registration and decreases the chances of a ghost hit'
    })

    Options = HitFix:CreateDropdown({
        Name = "Mode",
        List = {"Blatant", "Legit"},
    })

    PingBased = HitFix:CreateToggle({
        Name = "Ping Based",
        Default = false,
    })
end)
run(function()
	local WhiteHits
	local hookedHighlights = {}
	WhiteHits =  vape.Categories.Blatant:CreateModule({
		Name = "WhiteHits",
		Function = function(callback)
			if callback then
				local function hookHighlight(v)
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight and not hookedHighlights[highlight] then
						highlight.FillTransparency = 1
						hookedHighlights[highlight] = highlight:GetPropertyChangedSignal("FillTransparency"):Connect(function()
							if WhiteHits.Enabled then
								highlight.FillTransparency = 1
							end
						end)
					end
				end
				for _, v in entitylib.List do
					hookHighlight(v)
				end
				WhiteHits:Clean(entitylib.Events.EntityAdded:Connect(hookHighlight))
				WhiteHits:Clean(entitylib.Events.EntityRemoved:Connect(function(v)
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight and hookedHighlights[highlight] then
						hookedHighlights[highlight]:Disconnect()
						hookedHighlights[highlight] = nil
					end
				end))
			else
				for _, conn in pairs(hookedHighlights) do
					if typeof(conn) == "RBXScriptConnection" then
						conn:Disconnect()
					end
				end
				table.clear(hookedHighlights)
			end
		end
	})
end)																																																				
run(function()
	local BCR
	local Value
	local old
	local inf = math.huge or 9e9
	BCR = vape.Categories.Blatant:CreateModule({
		Name = "BlockCPSRemover",
		Function = function(callback)
			if callback then
				old = bedwars.SharedConstants.CpsConstants['BLOCK_PLACE_CPS']
				bedwars.SharedConstants.CpsConstants['BLOCK_PLACE_CPS'] = Value.Value == 0 and inf or Value.Value
			else
				bedwars.SharedConstants.CpsConstants['BLOCK_PLACE_CPS'] = old
				old = nil
			end
		end,
	})
	Value = BCR:CreateSlider({
		Name = "CPS",
		Suffix = "s",
		Tooltip = "Changes the limit to the CPS cap(0 = remove)",
		Default = 0,
		Min = 0,
		Max = 100,
		Function = function()
			if BCR.Enabled then
				bedwars.SharedConstants.CpsConstants['BLOCK_PLACE_CPS'] = Value.Value == 0 and inf or Value.Value
			else
				if old == nil then old = 12 end
				bedwars.SharedConstants.CpsConstants['BLOCK_PLACE_CPS'] = old
				old = nil
			end
		end,
		
	})
end)
run(function()
	local Shaders
	local Lighting = lightingService
	local old = {
		Technology = nil,
		GlobalShadows = nil,
		SS = nil, -- HITLER,
		Bright = nil,
		EC = nil,
		EDS =  nil,
		CT = nil,
		ODA = nil,
		ESS = nil,
	}
	Shaders = vape.Legit:CreateModule({
		Name = "Shaders",
		Function = function(callback)
			if callback then
				pcall(function()
					local RS = replicatedStorage
					local folder = Instance.new("Folder")
					folder.Name = "LightingStuffThingys"
					folder.Parent = RS

					for _, v in ipairs(Lighting:GetChildren()) do
						v.Parent = folder
					end
				end)
				pcall(function()
					old.Technology = Lighting.Technology
					old.GlobalShadows = Lighting.GlobalShadows
					old.SS = Lighting.ShadowSoftness
					old.Bright = Lighting.Brightness
					old.EC = Lighting.ExposureCompensation
					old.EDS = Lighting.EnvironmentDiffuseScale
					old.ESS = Lighting.EnvironmentSpecularScale
					old.CT = Lighting.ClockTime
					old.ODA = Lighting.OutdoorAmbient
					Lighting.GlobalShadows = true
					Lighting.ShadowSoftness = 0.7
					Lighting.Brightness = 1.5
					Lighting.ExposureCompensation = -0.15
					Lighting.EnvironmentDiffuseScale = 0.6
					Lighting.EnvironmentSpecularScale = 0.4
					Lighting.ClockTime = 14
					Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 160)
					Lighting.Technology = Enum.Technology.Future
				end)

				local Bloom = Instance.new("BloomEffect")
				Bloom.Intensity = 0.45
				Bloom.Size = 32
				Bloom.Threshold = 0.9
				Bloom.Parent = Lighting

				local Color = Instance.new("ColorCorrectionEffect")
				Color.Brightness = 0.05
				Color.Contrast = -0.05
				Color.Saturation = 0.12
				Color.TintColor = Color3.fromRGB(255, 242, 230)
				Color.Parent = Lighting

				local DoF = Instance.new("DepthOfFieldEffect")
				DoF.FarIntensity = 0.15
				DoF.NearIntensity = 0
				DoF.FocusDistance = 60
				DoF.InFocusRadius = 50
				DoF.Parent = Lighting

				local Blur = Instance.new("BlurEffect")
				Blur.Size = 2
				Blur.Parent = Lighting

				local Atmosphere = Instance.new("Atmosphere")
				Atmosphere.Density = 0.35
				Atmosphere.Offset = 0.25
				Atmosphere.Glare = 0
				Atmosphere.Haze = 1.2
				Atmosphere.Color = Color3.fromRGB(245, 235, 225)
				Atmosphere.Parent = Lighting
			else
				pcall(function()
					for _, v in ipairs(lightingService:GetChildren()) do
						if v then
							v:Destroy()
						end
					end
					task.wait(0.025)
					local RS = replicatedStorage
					local folder = RS:FindFirstChild("LightingStuffThingys")
					if not folder then return end
					local children = folder:GetChildren()

					for _, v in ipairs(children) do
						v.Parent = Lighting
					end

					folder:Destroy()
				end)
				pcall(function()
					Lighting.Technology = old.Technology
					Lighting.GlobalShadows = old.GlobalShadows
					Lighting.ShadowSoftness = old.SS
					Lighting.Brightness = old.Bright
					Lighting.ExposureCompensation = old.EC
					Lighting.EnvironmentDiffuseScale = old.EDS
					Lighting.EnvironmentSpecularScale = old.ESS
					Lighting.ClockTime = old.CT
					Lighting.OutdoorAmbient = old.ODA
					task.wait(.025)
					old.Technology = nil
					old.GlobalShadows = nil
					old.SS = nil
					old.Bright = nil
					old.EC = nil
					old.EDS = nil
					old.ESS = nil
					old.CT = nil
					old.ODA = nil
				end)
			end
		end
	})
end)

run(function()
	local MouseTP
	local mode
	local pos
	local function getNearestPlayer()
		local character = lplr.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end

		local nearestPlayer = nil
		local shortestDistance = math.huge or (2^1024-1)
		local myPos = hrp.Position

		for _, player in ipairs(playersService:GetPlayers()) do
			if player ~= lplr then
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")

				if root and hum and hum.Health > 0 then
					local dist = (root.Position - myPos).Magnitude
					if dist < shortestDistance then
						nearestPlayer = player
					end
				end
			end
		end

		return nearestPlayer
	end
	local function Elektra(type)
		if type == "Mouse" then
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true
			local ray = cloneref(lplr:GetMouse()).UnitRay
			rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
			position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
			if not position then
				notif('MouseTP', 'No position found.', 5)
				MouseTP:Toggle(false)
				return
			end
			
			if bedwars.AbilityController:canUseAbility('ELECTRIC_DASH') then
				local info = TweenInfo.new(0.72,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)
				local tween = tweenService:Create(entitylib.character.RootPart,info,{CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)})
				tween:Play()
				task.wait(0.69)
				bedwars.AbilityController:useAbility('ELECTRIC_DASH')
				MouseTP:Toggle(false)
			end
		else
			local FoundedPLR = getNearestPlayer()
			if FoundedPLR then
				local position = FoundedPLR.Character.HumanoidRootPart.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle(false)
					return
				end
				
				if bedwars.AbilityController:canUseAbility('ELECTRIC_DASH') then
					local info = TweenInfo.new(0.72,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)
					local tween = tweenService:Create(entitylib.character.RootPart,info,{CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)})
					tween:Play()
					task.wait(0.69)
					bedwars.AbilityController:useAbility('ELECTRIC_DASH')
					MouseTP:Toggle(false)
				end
			end
		end
	end
	
	local function Davey(type)
		if type == "Mouse" then
			local Cannon = getItem("cannon")
			local ray = cloneref(lplr:GetMouse()).UnitRay
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true
			rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
			position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)

			if not position then
				notif('MouseTP', 'No position found.', 5,"warning")
				MouseTP:Toggle(false)
				return
			end

				
			if not Cannon then
				notif('MouseTP', 'No cannon found.', 5,"warning")
				MouseTP:Toggle(false)
				return
			end

			if not entitylib.isAlive then
				notif('MouseTP', 'Cannot locate where i am at?', 5,"warning")
				MouseTP:Toggle(false)
				return
			end
			local pos = entitylib.character.RootPart.Position
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
			local block, blockpos = getPlacedBlock(rounded)
			if block then
				if block.Name == "cannon" then
					if (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
						bedwars.Client:Get(remotes.CannonAim):SendToServer({
							cannonBlockPos = blockpos,
							lookVector = position
						})
						local broken = 0.1
						if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
							broken = 0.4
							bedwars.breakBlock(block, true, true)
						end
			
						task.delay(broken, function()
							for _ = 1, 3 do
								local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
								if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
									humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
								if call then
									bedwars.breakBlock(block, true, true)
									break
								end
								task.wait(0.1)
							end
						end)
						MouseTP:Toggle(false)
					end
				end
			end
		else
			local Cannon = getItem("cannon")
			local FoundedPLR = getNearestPlayer()
			if FoundedPLR then
				local position = FoundedPLR.Character.HumanoidRootPart.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				local old = nil
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle(false)
					return
				end
				if not Cannon then
					notif('MouseTP', 'No cannon found.', 5,"warning")
					MouseTP:Toggle(false)
					return
				end

				if not entitylib.isAlive then
					notif('MouseTP', 'Cannot locate where i am at?', 5,"warning")
					MouseTP:Toggle(false)
					return
				end
				local pos = entitylib.character.RootPart.Position
				pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
				local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
				bedwars.placeBlock(rounded, 'cannon', false)
				local block, blockpos = getPlacedBlock(rounded)
				if block then
					if block.Name == "cannon" then
						if (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
							bedwars.Client:Get(remotes.CannonAim):SendToServer({
								cannonBlockPos = blockpos,
								lookVector = position
							})
							local broken = 0.1
							if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
								broken = 0.4
								bedwars.breakBlock(block, true, true)
							end
				
							task.delay(broken, function()
								for _ = 1, 3 do
									local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
									if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
										humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
									end
									if call then
										bedwars.breakBlock(block, true, true)
										break
									end
									task.wait(0.1)
								end
							end)
							MouseTP:Toggle(false)
						end
					end
				end
			end
		end
	end

	local function Yuzi(type)
		if type == "Mouse" then
			local old = nil
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true
			local ray = cloneref(lplr:GetMouse()).UnitRay
			rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
			position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
			if not position then
				notif('MouseTP', 'No position found.', 5)
				MouseTP:Toggle(false)
				return
			end
			
			if bedwars.AbilityController:canUseAbility('dash') then
				old = bedwars.YuziController.dashForward
				bedwars.YuziController.dashForward = function(v1,v2)
					local arg = nil
					if v1 then
						arg = v1
					else
						arg = v2
					end
					if entitylib.isAlive then
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position,entitylib.character.RootPart.Position + arg * Vector3.new(1, 0, 1))
						entitylib.character.Humanoid.JumpHeight = 0.5
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						entitylib.character.RootPart:ApplyImpulse(CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
						bedwars.JumpHeightController:setJumpHeight(cloneref(game:GetService("StarterPlayer")).CharacterJumpHeight)
						bedwars.SoundManager:playSound(bedwars.SoundList.DAO_SLASH)
						local any_playAnimation_result1 = bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.DAO_DASH)
						if any_playAnimation_result1 ~= nil then
							any_playAnimation_result1:AdjustSpeed(2.5)
						end
					end
				end
				bedwars.AbilityController:useAbility('dash',nil,{
					direction = gameCamera.CFrame.LookVector,
					origin = entitylib.character.RootPart.Position,
					weapon = store.hand.tool.Name.itemType,
				})
				task.wait(0.15)
				bedwars.YuziController.dashForward = old
				old = nil
				MouseTP:Toggle(false)
			end
		else
			local FoundedPLR = getNearestPlayer()
			if FoundedPLR then
				local position = FoundedPLR.Character.HumanoidRootPart.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				local old = nil
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle(false)
					return
				end
				
				if bedwars.AbilityController:canUseAbility('dash') then
					old = bedwars.YuziController.dashForward
					bedwars.YuziController.dashForward = function(v1,v2)
						local arg = nil
						if v1 then
							arg = v1
						else
							arg = v2
						end
						if entitylib.isAlive then
							entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position,entitylib.character.RootPart.Position + arg * Vector3.new(1, 0, 1))
							entitylib.character.Humanoid.JumpHeight = 0.5
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							entitylib.character.RootPart:ApplyImpulse(CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
							bedwars.JumpHeightController:setJumpHeight(cloneref(game:GetService("StarterPlayer")).CharacterJumpHeight)
							bedwars.SoundManager:playSound(bedwars.SoundList.DAO_SLASH)
							local any_playAnimation_result1 = bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.DAO_DASH)
							if any_playAnimation_result1 ~= nil then
								any_playAnimation_result1:AdjustSpeed(2.5)
							end
						end
					end
					bedwars.AbilityController:useAbility('dash',nil,{
						direction = gameCamera.CFrame.LookVector,
						origin = entitylib.character.RootPart.Position,
						weapon = store.hand.tool.Name.itemType,
					})
					task.wait(0.15)
					bedwars.YuziController.dashForward = old
					old = nil
					MouseTP:Toggle(false)
				end
			end
		end
	end

	local function Zar(type)
		notif('MouseTP', 'Comming soon!', 8,'warning')
		MouseTP:Toggle(false)
		return
	end

	local function Mouse(type)
		if type == "Mouse" then
			local position
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true
			local ray = cloneref(lplr:GetMouse()).UnitRay
			rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
			position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
			entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
		
			if not position then
				notif('MouseTP', 'No position found.', 5)
				MouseTP:Toggle(false)
				return
			end
		else
			local FoundedPLR = getNearestPlayer()
			if FoundedPLR then
				local position = FoundedPLR.Character.HumanoidRootPart.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
				if not position then
					notif('MouseTP', 'No player found.', 5)
					MouseTP:Toggle(false)
					return
				end
			end
		end
		MouseTP:Toggle(false)
	end

	MouseTP = vape.Categories.Utility:CreateModule({
		Name = 'MouseTP',
		Function = function(callback)
			if not callback then return end
			if callback then
				if mode.Value == "Mouse" then
					Mouse(pos.Value)
				elseif mode.Value == "Kits" then
					if store.equippedKit == "elektra" then
						Elektra(pos.Value)
					elseif store.equippedKit == "davey" then
						Davey(pos.Value)
					elseif store.equippedKit == "dasher" then
						Yuzi(pos.Value)
					elseif store.equippedKit == "gun_blade" then
						Zar(pos.Value)
					else
						vape:CreateNotification("MouseTP", "Current kit is not supported for MouseTP", 4.5, "warning")
						MouseTP:Toggle(false)
						return
					end
				else
					Mouse()
				end
			end
		end,
	})
	mode = MouseTP:CreateDropdown({
		Name = "Mode",
		List = {'Mouse','Kits'}
	})
	pos =  MouseTP:CreateDropdown({
		Name = "Position",
		List = {'Cloeset Player', 'Mouse'}
	})
end)

run(function()
    local KitDisplay

    local function getKitMeta(player)
    	local kit = player:GetAttribute('PlayingAsKits') or player:GetAttribute('PlayingAsKit') or 'none'
    	return bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none
    end

    local function getPlayerFromDraft(render, name)
    	local id = render and render:match('id=(%d+)')
    	if id then
    		local player = playersService:GetPlayerByUserId(tonumber(id))
    		if player then
    			return player
    		end
    	end

    	for _, v in playersService:GetPlayers() do
    		if render and render:find('id=' .. v.UserId, 1, true) then
    			return v
    		end

    		if name and (v.Name == name or v.DisplayName == name or v:GetAttribute('DisguiseDisplayName') == name) then
    			return v
    		end

    		local displayName
    		pcall(function()
    			displayName = bedwars.StreamerModeController:getDisplayName(v)
    		end)
    		if name and displayName == name then
    			return v
    		end
    	end
    	return nil
    end

    local waitForChild = function(start, ...)
    	local parent = start
    	for _, v in {...} do
    		parent = parent and parent:WaitForChild(v, 5)
    		if not parent then
    			break
    		end
    	end
    	return parent
    end

    local function getPlayerName(card)
    	local textbar = card and card:FindFirstChild('TextBackgroundBar')
    	local label = textbar and textbar:FindFirstChild('PlayerName') or card and card:FindFirstChild('PlayerName', true)
    	return label and label.Text or ''
    end

    local function getDraftCard(container)
    	if not container then
    		return
    	end
    	return container.Name == 'MatchDraftPlayerCard' and container or container:FindFirstChild('MatchDraftPlayerCard', true)
    end

    local function callback5v5(v, plr)
    	if not v then
    		return
    	end
    	local render = v:FindFirstChild('PlayerRender', true)
    	local player = plr or getPlayerFromDraft(render and render.Image or '', getPlayerName(v))

    	if player then
    		local kitImage = getKitMeta(player)
    		local roact = v:FindFirstChild('KitImage')

    		if not roact then
    			roact = Instance.new('ImageLabel', v)
    			roact.BackgroundTransparency = 1
    			roact.AnchorPoint = Vector2.new(1, 0.5)
    			roact.Position = UDim2.fromScale(1.05, 0.5)
    			roact.Name = 'KitImage'
    			roact.Size = UDim2.fromScale(1.5, 1.5)
    			roact.ZIndex = 1
    			roact.ImageTransparency = 0.4
    			roact.SliceCenter = Rect.new(0, 0, 0, 0)
    			roact.SliceScale = 1
    			roact.ScaleType = Enum.ScaleType.Crop

    			KitDisplay:Clean(roact)

    			local ratio = Instance.new('UIAspectRatioConstraint', roact)
    			ratio.Name = '1'
    			ratio.AspectRatio = 1
    			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
    			ratio.DominantAxis = Enum.DominantAxis.Width
    		end

    		roact.Image = kitImage.renderImage
    		roact.Position = UDim2.fromScale(1.05, 0)
    		tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.fromScale(1.05, 0.4)}):Play()

    		local function update()
    			kitImage = getKitMeta(player)
    			roact.Image = kitImage.renderImage
    		end

    		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
    		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
    	end
    end

    local function callbacksquad(v)
    	if not v then
    		return
    	end
    	local render = v:FindFirstChild('PlayerRender', true)
    	local player = render and getPlayerFromDraft(render.Image, '') or nil

    	if player then
    		local kitImage = getKitMeta(player)
    		local Roact = v:FindFirstChild('Kitcvrender')

    		if not Roact then
    			local base = v:FindFirstChild('3') or v:WaitForChild('3', 5)
    			if not base then
    				return
    			end
    			Roact = base:Clone()
    			Roact.Parent = v
    			Roact.Name = 'Kitcvrender'
    			KitDisplay:Clean(Roact)
    		end

    		Roact.Image = kitImage.renderImage

    		KitDisplay:Clean(render:GetPropertyChangedSignal('Image'):Connect(function()
    			local newplayer = getPlayerFromDraft(render.Image, '')
    			if newplayer then
    				player = newplayer
    				kitImage = getKitMeta(player)
    				Roact.Image = kitImage.renderImage
    			end
    		end))

    		local function update()
    			kitImage = getKitMeta(player)
    			Roact.Image = kitImage.renderImage
    		end

    		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
    		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
    	end
    end

    local function setup5v5(DraftApp)
    	local Background = DraftApp:FindFirstChild('DraftAppBackground')
    	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
    	local hooked = false

    	for i = 1, 2 do
    		local dtc = BodyContainer and BodyContainer:FindFirstChild('Team' .. i .. 'Column')
    		if dtc then
    			hooked = true
    			KitDisplay:Clean(dtc.ChildAdded:Connect(function(child)
    				task.delay(0.2, function()
    					if KitDisplay.Enabled then
    						callback5v5(getDraftCard(child))
    					end
    				end)
    			end))

    			for _, v in dtc:GetChildren() do
    				if v:IsA('Frame') then
    					callback5v5(getDraftCard(v))
    				end
    			end
    		end
    	end

    	if not hooked then
    		for _, label in DraftApp:GetDescendants() do
    			if label:IsA('TextLabel') and label.Name == 'PlayerName' then
    				local container = label.Parent
    				for _ = 1, 3 do
    					container = container and container.Parent
    				end
    				if container then
    					callback5v5(getDraftCard(container))
    				end
    			end
    		end

    		KitDisplay:Clean(DraftApp.DescendantAdded:Connect(function(child)
    			if child:IsA('TextLabel') and child.Name == 'PlayerName' then
    				task.delay(0.2, function()
    					local container = child.Parent
    					for _ = 1, 3 do
    						container = container and container.Parent
    					end
    					if KitDisplay.Enabled and container then
    						callback5v5(getDraftCard(container))
    					end
    				end)
    			end
    		end))
    	end

    	return hooked
    end

    local function setupSquad(DraftApp)
    	local Background = DraftApp:FindFirstChild('DraftAppBackground')
    	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
    	local TeamsColumn = BodyContainer and BodyContainer:FindFirstChild('TeamsColumn')
    	if not TeamsColumn then
    		return
    	end

    	for _, v: Instance in TeamsColumn:GetChildren() do
    		if v:IsA('Frame') then
    			local plrframe = waitForChild(v, '1', '2', '4')
    			if plrframe then
    				for _, plr in plrframe:GetChildren() do
    					callbacksquad(plr)
    				end

    				KitDisplay:Clean(plrframe.ChildAdded:Connect(function(plr)
    					KitDisplay:Toggle()
    					KitDisplay:Toggle()
    				end))
    			end
    		end
    	end
    end

    KitDisplay = vape.Categories.Render:CreateModule({
    	Name = 'Kit Display',
    	Function = function(call)
    		if call then
    			local DraftApp = lplr.PlayerGui:WaitForChild('MatchDraftApp', 9e9)
    			setup5v5(DraftApp)
    			setupSquad(DraftApp)
    		end
    	end,
    	Tooltip = 'Allows you to see the other opponent kits'
    })
end)
run(function()
    local LegacyAnimation

    local function isFirstPerson()
        local char = lplr.Character
        if not char then return false end
        local head = char:FindFirstChild('Head')
        if not head then return false end
        return head.LocalTransparencyModifier == 1
    end

    LegacyAnimation = vape.Categories.Render:CreateModule({
        Name = 'LegacyAnimation',
        Function = function(callback)
            if callback then
                local frameCounter = 0
                workspace:SetAttribute('RbxLegacyAnimationBlending', not isFirstPerson())
                LegacyAnimation:Clean(runService.Heartbeat:Connect(function()
                    frameCounter = frameCounter + 1
                    if frameCounter % 6 == 0 then
                        workspace:SetAttribute('RbxLegacyAnimationBlending', not isFirstPerson())
                    end
                end))
            else
                workspace:SetAttribute('RbxLegacyAnimationBlending', false)
            end
        end,
        Tooltip = 'Enables legacy animation blending in 3rd person only'
    })
end)

run(function()
	local AutoHonor
	local Delay
	local honoredusers = {}
	local maxhonors = 2
	
	local function getTeammates()
		local teammates = {}
		local nonteammates = {}
		local myTeam = lplr.Team
		
		for i, plr in playersService:GetPlayers() do
			if plr ~= lplr then
				if plr.Team == myTeam then
					table.insert(teammates, plr)
				else
					table.insert(nonteammates, plr)
				end
			end
		end
		return teammates, nonteammates
	end
	
	local function honorPlayers()
		if #honoredusers >= maxhonors then return end
		if not bedwars.HonorController then return end
		
		local teammates, nonteammates = getTeammates()
		
		if #teammates > 0 and #honoredusers < maxhonors then
			local randomTeammate = teammates[math.random(1, #teammates)]
			if not honoredusers[randomTeammate.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomTeammate.UserId)
				honoredusers[randomTeammate.UserId] = true
			end
		end
		
		if #nonteammates > 0 and #honoredusers < maxhonors then
			local randomEnemy = nonteammates[math.random(1, #nonteammates)]
			if not honoredusers[randomEnemy.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomEnemy.UserId)
				honoredusers[randomEnemy.UserId] = true
			end
		end
	end
	
	AutoHonor = vape.Categories.Minigames:CreateModule({
		Name = "AutoHonor",
		Function = function(callback)
			if callback then
				AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						pcall(honorPlayers)
					end
				end))
				AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(...)
					pcall(honorPlayers)
				end))
			else
				table.clear(honoredusers)
			end
		end
	})
	Delay = AutoHonor:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.05
	})
end)

run(function()
	local KitSkins
	local Players = playersService
	local RunService = runService
	local LocalPlayer = Players.LocalPlayer
	local RS = replicatedStorage

	local CURRENT_ITEM_SKIN = "Victorious Lyla"
	local CURRENT_SKIN_TYPE = "Nightmare"

	local ok1, ItemType = pcall(function()
		return require(RS.TS.item["item-type"]).ItemType
	end)
	if not ok1 then ItemType = {} end

	local ok2, ItemSkinType = pcall(function()
		return require(RS.TS.games.bedwars["item-skin"]["item-skin-types"]).ItemSkinType
	end)
	if not ok2 then ItemSkinType = {} end

	local KitSkinCtrl
	pcall(function()
		local KC = require(RS.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
		KitSkinCtrl = bedwars.KitSkinController
	end)

	local BOW_ROT = CFrame.Angles(0, math.rad(-90), 0)
	local CROSSBOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-360), 0)
	local LUNAR_CROSSBOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, -190, math.rad(-180))
	local VICTORIOUS_ARCHER_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, -52, math.rad(90))
	local VICTORIOUS_ARCHER_CROSSBOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, -190, math.rad(-180))
	local VICTORIOUS_ARCHER_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
	local HEADHUNTER_ROT = CFrame.new(0.4, 0, 0) * CFrame.Angles(0, math.rad(360), 0)
	local AXE_ROT = CFrame.new(0, 0, -0.4) * CFrame.Angles(0, math.rad(90), 0)
	local PICKAXE_ROT = CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.rad(110), 0)
	local LASSO_ROT = CFrame.Angles(0, math.rad(90), 0)
	local STAFF_ROT = CFrame.Angles(0, math.rad(90), 0)
	local SWORD_ROT = CFrame.new(0, -1.7, 0) * CFrame.Angles(0, math.rad(-180), 0)
	local HEARTBEAM_SWORD_ROT = CFrame.new(0, -1.2, 0) * CFrame.Angles(0, math.rad(0), 0)
	local LIFE_BOW_ROT = CFrame.Angles(0, math.rad(-20), 0)
	local DAO_ROT = CFrame.new(0, -1.7, 0) * CFrame.Angles(0, math.rad(-180), 0)
	local VIC_ROT = CFrame.new(0, -1.9, 0) * CFrame.Angles(0, math.rad(360), 0)
	local HEXED_DAO_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, 160, math.rad(-180))
	local SNOW_DAO_ROT = CFrame.new(-0.2, -0.9, 0) * CFrame.Angles(0, math.rad(-180), 0)
	local HARPOON_ROT = CFrame.new(0, -1.4, -0.15) * CFrame.Angles(0, math.rad(180), 0)
	local TRIDENT_ROT = CFrame.new(0, 0.5, 0.05) * CFrame.Angles(0, math.rad(180), 0)
	local LYLA_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(30, -30, 183.56)
	local LYLA_CROSSBOW_ROT = CFrame.Angles(math.rad(0), math.rad(180), math.rad(0))
	local LYLA_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)

	local CANNON_HAND_SCALE = 0.34
	local CANNON_PLACED_OFFSET = CFrame.new(0, -1.0, 0)
	local CANNON_TOOL_NAME = "cannon"

	local CANNON_SKIN_NAMES = {
		["Victorious Cannon"] = {
			Gold = "cannon_gold_victorious",
			Platinum = "cannon_platinum_victorious",
			Diamond = "cannon_diamond_victorious",
			Emerald = "cannon_emerald_victorious",
			Nightmare = "cannon_nightmare_victorious",
		},
		["Ghost Cannon"] = { Default = "cannon_ghost" },
		["Deep Sea Cannon"] = { Default = "cannon_deepsea" },
	}

	local CANNON_SOUND_NAMES = {
		Gold = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Platinum = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Diamond = "CANNON_FIRE_VICTORIOUS_DIAMOND",
		Emerald = "CANNON_FIRE_VICTORIOUS_EMERALD",
		Nightmare = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
	}

	local SKIN_OFFSETS = {
		["nightmare_victorious_flower_bow"] = LYLA_BOW_ROT,
		["emerald_victorious_flower_bow"] = LYLA_BOW_ROT,
		["diamond_victorious_flower_bow"] = LYLA_BOW_ROT,
		["platinum_victorious_flower_bow"] = LYLA_BOW_ROT,
		["gold_victorious_flower_bow"] = LYLA_BOW_ROT,
		["nightmare_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["emerald_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["diamond_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["platinum_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["gold_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["nightmare_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["emerald_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["diamond_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["platinum_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["gold_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_nightmare"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_emerald"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_diamond"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_platinum"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_gold"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["flower_bow_frost_queen"] = BOW_ROT,
		["tactical_crossbow_lunar_dragon"] = LUNAR_CROSSBOW_ROT,
		["life_bow_mummy"] = LIFE_BOW_ROT,
		["flower_headhunter_frost_queen"] = HEADHUNTER_ROT,
		["wood_sword_darkvalentine"] = SWORD_ROT,
		["stone_sword_darkvalentine"] = SWORD_ROT,
		["iron_sword_darkvalentine"] = SWORD_ROT,
		["diamond_sword_darkvalentine"] = SWORD_ROT,
		["emerald_sword_darkvalentine"] = SWORD_ROT,
		["wood_sword_heartbeam"] = HEARTBEAM_SWORD_ROT,
		["stone_sword_heartbeam"] = HEARTBEAM_SWORD_ROT,
		["iron_sword_heartbeam"] = HEARTBEAM_SWORD_ROT,
		["diamond_sword_heartbeam"] = HEARTBEAM_SWORD_ROT,
		["emerald_sword_heartbeam"] = HEARTBEAM_SWORD_ROT,
		["wood_bow_victorious_nightmare"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_emerald"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_diamond"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_platinum"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_gold"] = VICTORIOUS_ARCHER_BOW_ROT,
		["tactical_crossbow_victorious_nightmare"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_emerald"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_diamond"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_platinum"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_gold"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["life_crossbow_mummy"] = CROSSBOW_ROT,
		["life_headhunter_mummy"] = HEADHUNTER_ROT,
		["victorious_gold_triton"] = TRIDENT_ROT,
		["victorious_platinum_triton"] = TRIDENT_ROT,
		["victorious_diamond_triton"] = TRIDENT_ROT,
		["victorious_emerald_triton"] = TRIDENT_ROT,
		["victorious_nightmare_triton"] = TRIDENT_ROT,
		["demon_triton"] = HARPOON_ROT,
		["lasso_mummy"] = LASSO_ROT,
		["lasso_wrangler_reindeer_lassy"] = LASSO_ROT,
		["lasso_lifeguard"] = LASSO_ROT,
		["wood_axe_darkvalentine"] = AXE_ROT,
		["stone_axe_darkvalentine"] = AXE_ROT,
		["iron_axe_darkvalentine"] = AXE_ROT,
		["diamond_axe_darkvalentine"] = AXE_ROT,
		["wood_axe_valentine"] = AXE_ROT,
		["stone_axe_valentine"] = AXE_ROT,
		["iron_axe_valentine"] = AXE_ROT,
		["diamond_axe_valentine"] = AXE_ROT,
		["wood_pickaxe_darkvalentine"] = PICKAXE_ROT,
		["stone_pickaxe_darkvalentine"] = PICKAXE_ROT,
		["iron_pickaxe_darkvalentine"] = PICKAXE_ROT,
		["diamond_pickaxe_darkvalentine"] = PICKAXE_ROT,
		["wood_pickaxe_valentine"] = PICKAXE_ROT,
		["stone_pickaxe_valentine"] = PICKAXE_ROT,
		["iron_pickaxe_valentine"] = PICKAXE_ROT,
		["diamond_pickaxe_valentine"] = PICKAXE_ROT,
		["gold_victorious_wizard_staff"] = STAFF_ROT,
		["gold_victorious_wizard_staff_2"] = STAFF_ROT,
		["gold_victorious_wizard_staff_3"] = STAFF_ROT,
		["platinum_victorious_wizard_staff"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_2"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_3"] = STAFF_ROT,
		["diamond_victorious_wizard_staff"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_2"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_3"] = STAFF_ROT,
		["emerald_victorious_wizard_staff"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_2"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_3"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_2"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_3"] = STAFF_ROT,
		["wood_dao_victorious"] = VIC_ROT,
		["stone_dao_victorious"] = VIC_ROT,
		["iron_dao_victorious"] = VIC_ROT,
		["diamond_dao_victorious"] = VIC_ROT,
		["emerald_dao_victorious"] = VIC_ROT,
		["wood_dao_cursed"] = HEXED_DAO_ROT,
		["stone_dao_cursed"] = HEXED_DAO_ROT,
		["iron_dao_cursed"] = HEXED_DAO_ROT,
		["diamond_dao_cursed"] = HEXED_DAO_ROT,
		["emerald_dao_cursed"] = HEXED_DAO_ROT,
		["wood_dao_tiger"] = DAO_ROT,
		["stone_dao_tiger"] = DAO_ROT,
		["iron_dao_tiger"] = DAO_ROT,
		["diamond_dao_tiger"] = DAO_ROT,
		["emerald_dao_tiger"] = DAO_ROT,
		["wood_dao_snow_rabbit"] = SNOW_DAO_ROT,
		["stone_dao_snow_rabbit"] = SNOW_DAO_ROT,
		["iron_dao_snow_rabbit"] = SNOW_DAO_ROT,
		["diamond_dao_snow_rabbit"] = SNOW_DAO_ROT,
		["emerald_dao_snow_rabbit"] = SNOW_DAO_ROT,
	}

	local KIT_SKIN_MAP = {
		["Victorious Lyla"] = { Gold = "gold_victorious_lyla", Platinum = "platinum_victorious_lyla", Diamond = "diamond_victorious_lyla", Emerald = "emerald_victorious_lyla", Nightmare = "nightmare_victorious_lyla" },
		["Frost Queen Lyla"] = { Default = "flower_bee_frost_queen" },
		["Victorious Archer"] = { Gold = "archer_victorious_gold", Platinum = "archer_victorious_platinum", Diamond = "archer_victorious_diamond", Emerald = "archer_victorious_emerald", Nightmare = "archer_victorious_nightmare" },
		["Lunar Dragon Archer"] = { Default = "archer_lunar_dragon" },
		["Victorious Yuzi"] = { Default = "yuzi_victorious" },
		["Hexed Yuzi"] = { Default = "dasher_cursed" },
		["Tiger Yuzi"] = { Default = "dasher_tiger" },
		["Snow Rabbit Yuzi"] = { Default = "dasher_snow_rabbit" },
		["Victorious Zeno"] = { Gold = "gold_victorious_wizard", Platinum = "platinum_victorious_wizard", Diamond = "diamond_victorious_wizard", Emerald = "emerald_victorious_wizard", Nightmare = "nightmare_victorious_wizard" },
		["Victorious Triton"] = { Gold = "victorious_gold_triton", Platinum = "victorious_platinum_triton", Diamond = "victorious_diamond_triton", Emerald = "victorious_emerald_triton", Nightmare = "victorious_nightmare_triton" },
		["Demon Triton"] = { Default = "demon_triton" },
		["Mummy Life Bow"] = { Default = "mummy_nazar" },
		["Mummy Lasso"] = { Default = "cowgirl_mummy" },
		["Victorious Cannon"] = { Gold = "gold_victorious_davey", Platinum = "platinum_victorious_davey", Diamond = "diamond_victorious_davey", Emerald = "emerald_victorious_davey", Nightmare = "nightmare_victorious_davey" },
		["Ghost Cannon"] = { Default = "davey_ghost" },
		["Deep Sea Cannon"] = { Default = "davey_deepsea" },
	}

	local STORE_SKIN_MAP = {
		["Balloon Swords"] = function() return { { ItemType.WOOD_SWORD, ItemSkinType.BALLOON_WOOD_SWORD }, { ItemType.STONE_SWORD, ItemSkinType.BALLOON_STONE_SWORD }, { ItemType.IRON_SWORD, ItemSkinType.BALLOON_IRON_SWORD }, { ItemType.DIAMOND_SWORD, ItemSkinType.BALLOON_DIAMOND_SWORD }, { ItemType.EMERALD_SWORD, ItemSkinType.BALLOON_EMERALD_SWORD } } end,
		["Banana Swords"] = function() return { { ItemType.WOOD_SWORD, ItemSkinType.BANANA_WOOD_SWORD }, { ItemType.STONE_SWORD, ItemSkinType.BANANA_STONE_SWORD }, { ItemType.IRON_SWORD, ItemSkinType.BANANA_IRON_SWORD }, { ItemType.DIAMOND_SWORD, ItemSkinType.BANANA_DIAMOND_SWORD }, { ItemType.EMERALD_SWORD, ItemSkinType.BANANA_EMERALD_SWORD } } end,
		["Valentine Pack"] = function() return { 
			{ ItemType.WOOD_SWORD, ItemSkinType.VALENTINE_WOOD_SWORD }, { ItemType.STONE_SWORD, ItemSkinType.VALENTINE_STONE_SWORD }, { ItemType.IRON_SWORD, ItemSkinType.VALENTINE_IRON_SWORD }, { ItemType.DIAMOND_SWORD, ItemSkinType.VALENTINE_DIAMOND_SWORD }, { ItemType.EMERALD_SWORD, ItemSkinType.VALENTINE_EMERALD_SWORD },
			{ ItemType.WOOD_PICKAXE, ItemSkinType.VALENTINE_WOOD_PICKAXE }, { ItemType.STONE_PICKAXE, ItemSkinType.VALENTINE_STONE_PICKAXE }, { ItemType.IRON_PICKAXE, ItemSkinType.VALENTINE_IRON_PICKAXE }, { ItemType.DIAMOND_PICKAXE, ItemSkinType.VALENTINE_DIAMOND_PICKAXE },
			{ ItemType.WOOD_AXE, ItemSkinType.VALENTINE_WOOD_AXE }, { ItemType.STONE_AXE, ItemSkinType.VALENTINE_STONE_AXE }, { ItemType.IRON_AXE, ItemSkinType.VALENTINE_IRON_AXE }, { ItemType.DIAMOND_AXE, ItemSkinType.VALENTINE_DIAMOND_AXE }
		} end,
		["Darkheart Pack"] = function() return { 
			{ ItemType.WOOD_SWORD, ItemSkinType.DARKVALENTINE_WOOD_SWORD }, { ItemType.STONE_SWORD, ItemSkinType.DARKVALENTINE_STONE_SWORD }, { ItemType.IRON_SWORD, ItemSkinType.DARKVALENTINE_IRON_SWORD }, { ItemType.DIAMOND_SWORD, ItemSkinType.DARKVALENTINE_DIAMOND_SWORD }, { ItemType.EMERALD_SWORD, ItemSkinType.DARKVALENTINE_EMERALD_SWORD },
			{ ItemType.WOOD_PICKAXE, ItemSkinType.DARKVALENTINE_WOOD_PICKAXE }, { ItemType.STONE_PICKAXE, ItemSkinType.DARKVALENTINE_STONE_PICKAXE }, { ItemType.IRON_PICKAXE, ItemSkinType.DARKVALENTINE_IRON_PICKAXE }, { ItemType.DIAMOND_PICKAXE, ItemSkinType.DARKVALENTINE_DIAMOND_PICKAXE },
			{ ItemType.WOOD_AXE, ItemSkinType.DARKVALENTINE_WOOD_AXE }, { ItemType.STONE_AXE, ItemSkinType.DARKVALENTINE_STONE_AXE }, { ItemType.IRON_AXE, ItemSkinType.DARKVALENTINE_IRON_AXE }, { ItemType.DIAMOND_AXE, ItemSkinType.DARKVALENTINE_DIAMOND_AXE }
		} end,
		["Heartbeam Swords"] = function() return { { ItemType.WOOD_SWORD, ItemSkinType.HEARTBEAM_WOOD_SWORD }, { ItemType.STONE_SWORD, ItemSkinType.HEARTBEAM_STONE_SWORD }, { ItemType.IRON_SWORD, ItemSkinType.HEARTBEAM_IRON_SWORD }, { ItemType.DIAMOND_SWORD, ItemSkinType.HEARTBEAM_DIAMOND_SWORD }, { ItemType.EMERALD_SWORD, ItemSkinType.HEARTBEAM_EMERALD_SWORD } } end,
		["Mummy Life Bow"] = function() return { { ItemType.LIFE_BOW, ItemSkinType.LIFE_BOW_MUMMY }, { ItemType.LIFE_CROSSBOW, ItemSkinType.LIFE_CROSSBOW_MUMMY }, { ItemType.LIFE_HEADHUNTER, ItemSkinType.LIFE_HEADHUNTER_MUMMY } } end,
		["Mummy Lasso"] = function() return { { ItemType.LASSO, ItemSkinType.LASSO_MUMMY } } end,
	}

	local function yuziDaoMap(suffix)
		return {
			wood_dao = "wood_dao_" .. suffix,
			stone_dao = "stone_dao_" .. suffix,
			iron_dao = "iron_dao_" .. suffix,
			diamond_dao = "diamond_dao_" .. suffix,
			emerald_dao = "emerald_dao_" .. suffix,
		}
	end

	local SKIN_DATA = {
		["Victorious Lyla"] = function(t)
			local lt = t:lower()
			return {
				flower_bow = lt .. "_victorious_flower_bow",
				flower_crossbow = lt .. "_victorious_flower_crossbow",
				flower_headhunter = lt .. "_victorious_flower_headhunter",
			}
		end,
		["Frost Queen Lyla"] = function()
			return {
				flower_bow = "flower_bow_frost_queen",
				flower_crossbow = "flower_crossbow_frost_queen",
				flower_headhunter = "flower_headhunter_frost_queen",
			}
		end,
		["Victorious Archer"] = function(t)
			local lt = t:lower()
			return {
				wood_bow = "wood_bow_victorious_" .. lt,
				tactical_crossbow = "tactical_crossbow_victorious_" .. lt,
				tactical_headhunter = "tactical_headhunter_victorious_" .. lt,
			}
		end,
		["Lunar Dragon Archer"] = function()
			return {
				wood_bow = "wood_bow_lunar_dragon",
				tactical_crossbow = "tactical_crossbow_lunar_dragon",
				tactical_headhunter = "tactical_headhunter_lunar_dragon",
			}
		end,
		["Victorious Triton"] = function(t)
			return { harpoon = "victorious_" .. t:lower() .. "_triton" }
		end,
		["Demon Triton"] = function() return { harpoon = "demon_triton" } end,
		["Victorious Yuzi"] = function() return yuziDaoMap("victorious") end,
		["Hexed Yuzi"] = function() return yuziDaoMap("cursed") end,
		["Tiger Yuzi"] = function() return yuziDaoMap("tiger") end,
		["Snow Rabbit Yuzi"] = function() return yuziDaoMap("snow_rabbit") end,
		["Victorious Zeno"] = function(t)
			local lt = t:lower()
			return {
				wizard_staff = lt .. "_victorious_wizard_staff",
				wizard_staff_2 = lt .. "_victorious_wizard_staff_2",
				wizard_staff_3 = lt .. "_victorious_wizard_staff_3",
			}
		end,
		["Balloon Swords"] = function() return { wood_sword = "balloon_wood_sword", stone_sword = "balloon_stone_sword", iron_sword = "balloon_iron_sword", diamond_sword = "balloon_diamond_sword", emerald_sword = "balloon_emerald_sword" } end,
		["Banana Swords"] = function() return { wood_sword = "banana_wood_sword", stone_sword = "banana_stone_sword", iron_sword = "banana_iron_sword", diamond_sword = "banana_diamond_sword", emerald_sword = "banana_emerald_sword" } end,
		["Valentine Pack"] = function() return { 
			wood_sword = "wood_sword_valentine", stone_sword = "stone_sword_valentine", iron_sword = "iron_sword_valentine", diamond_sword = "diamond_sword_valentine", emerald_sword = "emerald_sword_valentine",
			wood_pickaxe = "wood_pickaxe_valentine", stone_pickaxe = "stone_pickaxe_valentine", iron_pickaxe = "iron_pickaxe_valentine", diamond_pickaxe = "diamond_pickaxe_valentine",
			wood_axe = "wood_axe_valentine", stone_axe = "stone_axe_valentine", iron_axe = "iron_axe_valentine", diamond_axe = "diamond_axe_valentine"
		} end,
		["Darkheart Pack"] = function() return { 
			wood_sword = "wood_sword_darkvalentine", stone_sword = "stone_sword_darkvalentine", iron_sword = "iron_sword_darkvalentine", diamond_sword = "diamond_sword_darkvalentine", emerald_sword = "emerald_sword_darkvalentine",
			wood_pickaxe = "wood_pickaxe_darkvalentine", stone_pickaxe = "stone_pickaxe_darkvalentine", iron_pickaxe = "iron_pickaxe_darkvalentine", diamond_pickaxe = "diamond_pickaxe_darkvalentine",
			wood_axe = "wood_axe_darkvalentine", stone_axe = "stone_axe_darkvalentine", iron_axe = "iron_axe_darkvalentine", diamond_axe = "diamond_axe_darkvalentine"
		} end,
		["Heartbeam Swords"] = function() return { wood_sword = "wood_sword_heartbeam", stone_sword = "stone_sword_heartbeam", iron_sword = "iron_sword_heartbeam", diamond_sword = "diamond_sword_heartbeam", emerald_sword = "emerald_sword_heartbeam" } end,
		["Mummy Lasso"] = function() return { lasso = "lasso_mummy" } end,
		["Mummy Life Bow"] = function() return { life_bow = "life_bow_mummy", life_crossbow = "life_crossbow_mummy", life_headhunter = "life_headhunter_mummy" } end,
	}

	local TIERED_SKINS = {
		["Victorious Lyla"] = true,
		["Victorious Archer"] = true,
		["Victorious Zeno"] = true,
		["Victorious Triton"] = true,
		["Victorious Cannon"] = true,
	}

	local function normalizeName(s)
		return s:lower():gsub("[_%s%-]", "")
	end

	local function isCannonSkin()
		return CANNON_SKIN_NAMES[CURRENT_ITEM_SKIN] ~= nil
	end

	local function getCurrentCannonSkinName()
		local tbl = CANNON_SKIN_NAMES[CURRENT_ITEM_SKIN]
		if not tbl then return nil end
		return tbl[CURRENT_SKIN_TYPE] or tbl.Default
	end

	local function getCannonSkinSource(skinName)
		local assets = RS:FindFirstChild("Assets")
		if not assets then return nil end
		local blocks = assets:FindFirstChild("Blocks")
		if not blocks then return nil end
		return blocks:FindFirstChild(skinName)
	end

	local function keepOriginalInvisible(tool)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not tool or not tool.Parent then
				conn:Disconnect()
				return
			end
			for _, d in ipairs(tool:GetDescendants()) do
				if d:IsA("BasePart") and not d:IsDescendantOf(tool:FindFirstChild("LOCAL_ITEM_RESKIN") or game) then
					d.LocalTransparencyModifier = 1
					d.Transparency = 1
				elseif (d:IsA("Decal") or d:IsA("Texture")) and not d:IsDescendantOf(tool:FindFirstChild("LOCAL_ITEM_RESKIN") or game) then
					d.Transparency = 1
				end
			end
		end)
		table.insert(connections, conn)
	end

	local function getCurrentMappings()
		local fn = SKIN_DATA[CURRENT_ITEM_SKIN]
		if not fn then return {} end
		return fn(CURRENT_SKIN_TYPE) or {}
	end

	local function getKitSkinValue()
		local m = KIT_SKIN_MAP[CURRENT_ITEM_SKIN]
		if not m then return nil end
		return m[CURRENT_SKIN_TYPE] or m.Default
	end

	local function getStoreSkins()
		local fn = STORE_SKIN_MAP[CURRENT_ITEM_SKIN]
		if not fn then return {} end
		return fn() or {}
	end

	local tagged = setmetatable({}, { __mode = "k" })
	local connections = {}
	local oldGetKitSkin = nil
	local savedStoreSkins = {}

	local cannonTagged = setmetatable({}, { __mode = "k" })
	local cannonConnections = {}
	local cannonRenderConns = {}
	local oldFireCannon, oldLaunchSelf
	local soundsHooked = false

	local function firstBasePart(root)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	end

	local function makeInvisible(root)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				d.Transparency = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
	end

	local function restoreVisibility(root)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
				d.Transparency = 0
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 0
			end
		end
	end

	local function setNoCollide(model)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				d.Anchored = false
			end
		end
	end

	local function weldAllTo(anchor, container)
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("BasePart") and d ~= anchor then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = anchor
				wc.Part1 = d
				wc.Parent = anchor
			end
		end
	end

	local function attachReskin(tool, skinName)
		if not tool or tagged[tool] then return end
		tagged[tool] = true

		local origHandle = tool:FindFirstChild("Handle")
		if not (origHandle and origHandle:IsA("BasePart")) then
			origHandle = firstBasePart(tool)
		end
		if not origHandle then tagged[tool] = nil; return end

		local itemsFolder = RS:FindFirstChild("Items")
		if not itemsFolder then tagged[tool] = nil; return end
		local source = itemsFolder:FindFirstChild(skinName)
		if not source then tagged[tool] = nil; return end

		makeInvisible(tool)

		local clone = source:Clone()
		clone.Name = "LOCAL_ITEM_RESKIN"
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
				pcall(d.Destroy, d)
			end
		end

		setNoCollide(clone)
		clone.Parent = tool

		local cloneAnchor = clone:FindFirstChild("Handle")
		if not (cloneAnchor and cloneAnchor:IsA("BasePart")) then
			if clone:IsA("Model") then
				if not clone.PrimaryPart then
					local p = firstBasePart(clone)
					if p then pcall(function() clone.PrimaryPart = p end) end
				end
				cloneAnchor = clone.PrimaryPart
			end
			cloneAnchor = cloneAnchor or firstBasePart(clone)
		end

		if not cloneAnchor then
			clone:Destroy(); restoreVisibility(tool); tagged[tool] = nil; return
		end

		pcall(function() cloneAnchor.CFrame = origHandle.CFrame end)
		weldAllTo(cloneAnchor, clone)

		local w = Instance.new("Weld")
		w.Part0 = origHandle
		w.Part1 = cloneAnchor
		w.C0 = SKIN_OFFSETS[skinName] or CFrame.identity
		w.C1 = CFrame.identity
		w.Parent = cloneAnchor
	end

	local function weldAllToPrimary(model)
		local primary = model.PrimaryPart
		if not primary then return end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= primary then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = primary
				wc.Part1 = d
				wc.Parent = primary
			end
		end
	end

	local function attachCannonReskin(targetRoot, posOffset, heldScale)
		if not targetRoot or cannonTagged[targetRoot] then return end
		cannonTagged[targetRoot] = true

		local targetPart = targetRoot:FindFirstChild("Handle")
		if not (targetPart and targetPart:IsA("BasePart")) then
			targetPart = firstBasePart(targetRoot)
		end
		if not targetPart then cannonTagged[targetRoot] = nil; return end

		local skinName = getCurrentCannonSkinName()
		if not skinName then cannonTagged[targetRoot] = nil; return end
		local source = getCannonSkinSource(skinName)
		if not source then cannonTagged[targetRoot] = nil; return end

		makeInvisible(targetRoot)

		local clone = source:Clone()
		clone.Name = "LOCAL_CANNON_RESKIN"
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
				pcall(d.Destroy, d)
			end
		end

		if not clone:IsA("Model") then
			setNoCollide(clone)
			clone.Parent = targetRoot
			return
		end

		if not clone.PrimaryPart then
			local p = firstBasePart(clone)
			if p then pcall(function() clone.PrimaryPart = p end) end
		end
		if not clone.PrimaryPart then
			clone:Destroy(); cannonTagged[targetRoot] = nil; return
		end

		if heldScale and heldScale ~= 1 then
			pcall(function() clone:ScaleTo(heldScale) end)
		end

		setNoCollide(clone)
		clone.Parent = targetRoot

		local offset = posOffset or CFrame.identity
		pcall(function() clone:PivotTo(targetPart.CFrame * offset) end)

		weldAllToPrimary(clone)

		local wc = Instance.new("WeldConstraint")
		wc.Part0 = targetPart
		wc.Part1 = clone.PrimaryPart
		wc.Parent = clone.PrimaryPart
	end

	local function hookCannonThirdPerson(character)
		local function onChildAdded(child)
			if not (child:IsA("Tool") and child.Name == CANNON_TOOL_NAME) then return end
			task.wait()

			local handle = child:FindFirstChild("Handle") or firstBasePart(child)
			if not handle then return end

			local existing = child:FindFirstChild("LOCAL_CANNON_RESKIN")
			if existing then existing:Destroy(); cannonTagged[child] = nil end

			attachCannonReskin(child, CFrame.identity, CANNON_HAND_SCALE)

			local start = time()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not child.Parent then conn:Disconnect(); return end
				makeInvisible(child)
				if time() - start > 3 then conn:Disconnect() end
			end)
			table.insert(cannonRenderConns, conn)
		end

		for _, c in ipairs(character:GetChildren()) do onChildAdded(c) end
		local conn = character.ChildAdded:Connect(onChildAdded)
		table.insert(cannonConnections, conn)
	end

	local function hookCannonViewmodel()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local function hookVM(vm)
			for _, child in ipairs(vm:GetChildren()) do
				if child.Name == CANNON_TOOL_NAME then
					attachCannonReskin(child, CFrame.identity, CANNON_HAND_SCALE)
				end
			end
			local conn = vm.ChildAdded:Connect(function(child)
				if child.Name == CANNON_TOOL_NAME then
					task.wait()
					attachCannonReskin(child, CFrame.identity, CANNON_HAND_SCALE)
				end
			end)
			table.insert(cannonConnections, conn)
		end
		local vm = cam:FindFirstChild("Viewmodel")
		if vm then hookVM(vm) end
		local conn = cam.ChildAdded:Connect(function(child)
			if child.Name == "Viewmodel" then task.wait(); hookVM(child) end
		end)
		table.insert(cannonConnections, conn)
	end

	local function hookCannonContainer(container)
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do
			if child.Name == CANNON_TOOL_NAME then
				attachCannonReskin(child, CFrame.identity, CANNON_HAND_SCALE)
			end
		end
		local conn = container.ChildAdded:Connect(function(child)
			if child.Name == CANNON_TOOL_NAME then
				task.wait()
				attachCannonReskin(child, CFrame.identity, CANNON_HAND_SCALE)
			end
		end)
		table.insert(cannonConnections, conn)
	end

	local function hookCannonBlocksFolder(blocksFolder)
		for _, child in ipairs(blocksFolder:GetChildren()) do
			if child.Name == CANNON_TOOL_NAME then
				attachCannonReskin(child, CANNON_PLACED_OFFSET, 1)
			end
		end
		local conn = blocksFolder.ChildAdded:Connect(function(child)
			if child.Name == CANNON_TOOL_NAME then
				task.wait()
				attachCannonReskin(child, CANNON_PLACED_OFFSET, 1)
			end
		end)
		table.insert(cannonConnections, conn)
	end

	local function hookAllWorldCannons()
		local map = workspace:FindFirstChild("Map")
		if not map then return end
		local worlds = map:FindFirstChild("Worlds")
		if not worlds then return end
		for _, world in ipairs(worlds:GetChildren()) do
			local blocks = world:FindFirstChild("Blocks")
			if blocks then hookCannonBlocksFolder(blocks) end
		end
		local conn = worlds.ChildAdded:Connect(function(world)
			task.wait()
			local blocks = world:FindFirstChild("Blocks")
			if blocks then hookCannonBlocksFolder(blocks) end
		end)
		table.insert(cannonConnections, conn)
	end

	local function hookCannonSounds()
		if soundsHooked then return end
		if not (bedwars and bedwars.CannonHandController) then return end
		soundsHooked = true
		oldFireCannon = bedwars.CannonHandController.fireCannon
		oldLaunchSelf = bedwars.CannonHandController.launchSelf

		local function replaceSound()
			-- SoundPool is no longer always parented directly to Workspace.  Its
			-- absence must not prevent the original cannon action from running.
			local soundPool = workspace:FindFirstChild("SoundPool", true)
			if soundPool then
				for _, v in ipairs(soundPool:GetChildren()) do
					if v:IsA("Sound") and v.SoundId == "rbxassetid://7121064180" then v:Destroy() end
				end
			end
			local key = CANNON_SOUND_NAMES[CURRENT_SKIN_TYPE] or CANNON_SOUND_NAMES.Nightmare
			if bedwars.SoundManager and bedwars.SoundList and bedwars.SoundList[key] then
				bedwars.SoundManager:playSound(bedwars.SoundList[key])
			end
		end

		bedwars.CannonHandController.fireCannon = function(...)
			pcall(replaceSound)
			return oldFireCannon(...)
		end
		bedwars.CannonHandController.launchSelf = function(...)
			pcall(replaceSound)
			return oldLaunchSelf(...)
		end
	end

	local function unhookCannonSounds()
		if soundsHooked and bedwars and bedwars.CannonHandController then
			if oldFireCannon then bedwars.CannonHandController.fireCannon = oldFireCannon end
			if oldLaunchSelf then bedwars.CannonHandController.launchSelf = oldLaunchSelf end
		end
		oldFireCannon = nil; oldLaunchSelf = nil; soundsHooked = false
	end

	local function cleanupCannons()
		for _, c in pairs(cannonConnections) do pcall(function() c:Disconnect() end) end
		for _, c in pairs(cannonRenderConns) do pcall(function() c:Disconnect() end) end
		table.clear(cannonConnections)
		table.clear(cannonRenderConns)

		for root in pairs(cannonTagged) do
			if root and root.Parent then
				local r = root:FindFirstChild("LOCAL_CANNON_RESKIN")
				if r then r:Destroy() end
				restoreVisibility(root)
			end
		end
		table.clear(cannonTagged)

		local map = workspace:FindFirstChild("Map")
		if map then
			local worlds = map:FindFirstChild("Worlds")
			if worlds then
				for _, world in ipairs(worlds:GetChildren()) do
					local blocks = world:FindFirstChild("Blocks")
					if blocks then
						for _, child in ipairs(blocks:GetChildren()) do
							if child.Name == CANNON_TOOL_NAME then
								local r = child:FindFirstChild("LOCAL_CANNON_RESKIN")
								if r then r:Destroy() end
								restoreVisibility(child)
							end
						end
					end
				end
			end
		end

		unhookCannonSounds()
	end

	local function applyKitSkinHook()
		if not KitSkinCtrl then return end
		local val = getKitSkinValue()
		if not val then return end
		if not oldGetKitSkin then oldGetKitSkin = KitSkinCtrl.getKitSkin end
		KitSkinCtrl.getKitSkin = function(self, char)
			if char == LocalPlayer.Character then return val end
			return oldGetKitSkin(self, char)
		end
	end

	local function removeKitSkinHook()
		if KitSkinCtrl and oldGetKitSkin then
			KitSkinCtrl.getKitSkin = oldGetKitSkin
			oldGetKitSkin = nil
		end
	end

	local function applyStoreSkins()
		if not (bedwars and bedwars.Store) then return end
		local skins = getStoreSkins()
		savedStoreSkins = {}
		local state = bedwars.Store:getState()
		for _, pair in ipairs(skins) do
			if pair[1] and pair[2] then
				local prev = state.Locker and state.Locker.selectedItemSkins and state.Locker.selectedItemSkins[pair[1]]
				table.insert(savedStoreSkins, { pair[1], prev })
				pcall(function() bedwars.Store:dispatch({ type = "LockerSetItemSkin", itemType = pair[1], itemSkin = pair[2] }) end)
			end
		end
	end

	local function clearStoreSkins()
		if not (bedwars and bedwars.Store) then return end
		for _, saved in ipairs(savedStoreSkins) do
			pcall(function() bedwars.Store:dispatch({ type = "LockerSetItemSkin", itemType = saved[1], itemSkin = saved[2] }) end)
		end
		savedStoreSkins = {}
	end

	local function tryApply(child)
		if isCannonSkin() then return end
		local mappings = getCurrentMappings()

		local skinName = mappings[child.Name:lower()]

		if not skinName then
			local childNorm = normalizeName(child.Name)
			for k, v in pairs(mappings) do
				if normalizeName(k) == childNorm then skinName = v; break end
			end
		end

		if not skinName then return end
		task.wait()
		if child.Parent then attachReskin(child, skinName) end
	end

	local function hookViewmodel()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local function hookVM(vm)
			for _, child in ipairs(vm:GetChildren()) do tryApply(child) end
			table.insert(connections, vm.ChildAdded:Connect(tryApply))
		end
		local vm = cam:FindFirstChild("Viewmodel")
		if vm then hookVM(vm) end
		table.insert(connections, cam.ChildAdded:Connect(function(child)
			if child.Name == "Viewmodel" then task.wait(); hookVM(child) end
		end))
	end

	local function hookContainer(container)
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do tryApply(child) end
		table.insert(connections, container.ChildAdded:Connect(tryApply))
	end

	local function onCharacterAdded(character)
		task.wait(0.2)
		applyKitSkinHook()
		if isCannonSkin() then
			hookCannonContainer(LocalPlayer.Backpack)
			hookCannonContainer(character)
			hookCannonThirdPerson(character)
		else
			hookContainer(LocalPlayer.Backpack)
			hookContainer(character)
		end
	end

	local function cleanup()
		for _, c in pairs(connections) do pcall(function() c:Disconnect() end) end
		table.clear(connections)
		for root in pairs(tagged) do
			if root and root.Parent then
				local r = root:FindFirstChild("LOCAL_ITEM_RESKIN")
				if r then r:Destroy() end
				restoreVisibility(root)
			end
		end
		table.clear(tagged)
		removeKitSkinHook()
		clearStoreSkins()
		cleanupCannons()
	end

	local skinNames = {}
	for name in pairs(SKIN_DATA) do table.insert(skinNames, name) end
	for name in pairs(CANNON_SKIN_NAMES) do table.insert(skinNames, name) end
	table.sort(skinNames)

	local SkinTypeDropdown

	KitSkins = vape.Categories.Render:CreateModule({
		Name = "KitSkins",
		Function = function(enabled)
			if enabled then
				if isCannonSkin() then
					hookCannonViewmodel()
					hookAllWorldCannons()
					hookCannonSounds()
					applyKitSkinHook()
					if LocalPlayer.Character then
						hookCannonContainer(LocalPlayer.Backpack)
						hookCannonContainer(LocalPlayer.Character)
						hookCannonThirdPerson(LocalPlayer.Character)
					end
				else
					hookViewmodel()
					applyKitSkinHook()
					applyStoreSkins()
					if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
				end
				table.insert(connections, LocalPlayer.CharacterAdded:Connect(onCharacterAdded))
			else
				cleanup()
			end
		end,
		Tooltip = "Client-sided item skin changer",
	})

	KitSkins:CreateDropdown({
		Name = "Item Skin",
		List = skinNames,
		Default = CURRENT_ITEM_SKIN,
		Function = function(val)
			CURRENT_ITEM_SKIN = val
			if SkinTypeDropdown and SkinTypeDropdown.Object then
				SkinTypeDropdown.Object.Visible = TIERED_SKINS[val] == true
			end
			if KitSkins.Enabled then KitSkins:Toggle(); KitSkins:Toggle() end
		end,
	})

	SkinTypeDropdown = KitSkins:CreateDropdown({
		Name = "Skin Type",
		List = { "Gold", "Platinum", "Diamond", "Emerald", "Nightmare", "Default" },
		Default = CURRENT_SKIN_TYPE,
		Function = function(val)
			CURRENT_SKIN_TYPE = val
			if KitSkins.Enabled then KitSkins:Toggle(); KitSkins:Toggle() end
		end,
	})

	task.defer(function()
		if SkinTypeDropdown and SkinTypeDropdown.Object then
			SkinTypeDropdown.Object.Visible = TIERED_SKINS[CURRENT_ITEM_SKIN] == true
		end
		if SkinTypeDropdown and SkinTypeDropdown.Set then
			SkinTypeDropdown:Set(CURRENT_SKIN_TYPE)
		end
	end)
end)
	
run(function()
	local AutoAdetunde
	local AdetundeUtil, AdetundeUpgradeMeta
	pcall(function()
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta
	end)
	
	AutoAdetunde = vape.Categories.Kits:CreateModule({
		Name = 'AutoAdetunde',
		Function = function(callback)
			if callback then
				repeat
					local crystal = getItem('frost_crystal')
					if crystal then
						for i, v in (AdetundeUtil and AdetundeUtil.getUpgradesFromHammer(lplr) or {}) do
							local new = getItem('frost_crystal')
							if not new then
								break
							end
	
							crystal = new
	
							local nextUpgrade = AutoAdetunde.Options['Buy ' .. i].Enabled and AdetundeUpgradeMeta[i].tiers[v + 1] or nil
							if nextUpgrade then
								if crystal.amount >= nextUpgrade.price then
									bedwars.Client:Get('UpgradeFrostyHammer'):CallServer(i)
									task.wait(0.1)
								end
							end
						end
					end
					task.wait(0.5)
				until not AutoAdetunde.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades ur frosty hammer'
	})
	
	for i in (AdetundeUpgradeMeta or {}) do
		AutoAdetunde:CreateToggle({
			Name = 'Buy ' .. i,
			Default = true,
		})
	end
end)
run(function()
    local AutoBuildUp
    local LimitItem
    
    local function getScaffoldBlock()
        return getScaffoldBlockForModule(LimitItem)
    end

    local function canPlaceAtPosition(blockpos)
        if not checkFaceAdjacent(blockpos) then
            return false
        end
        
        local checkBelow = blockpos - Vector3.new(0, 3, 0)
        local hasSupport = false
        
        for i = 1, 10 do
            if getPlacedBlock(checkBelow) then
                hasSupport = true
                break
            end
            checkBelow = checkBelow - Vector3.new(0, 3, 0)
        end
        
        return hasSupport or hasFaceBelowOrSide(blockpos)
    end
    
    AutoBuildUp = vape.Categories.World:CreateModule({
        Name = 'AutoBuildUp',
        Function = function(callback)
            
            if callback then
                repeat
                    if entitylib.isAlive then
                        local wool = getScaffoldBlock()
                        
                        if wool then
                            local root = entitylib.character.RootPart
                            
                            if inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
                                local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
                                
                                local block, blockpos = getPlacedBlock(currentpos)
                                if not block then
                                    blockpos = blockpos * 3
                                    
                                    if hasFaceBelowOrSide(blockpos) then
                                        if canPlaceAtPosition(blockpos) then
                                            task.spawn(bedwars.placeBlock, blockpos, wool, false)
                                        end
                                    else
                                        local nearestBlock = blockProximity(currentpos)
                                        if nearestBlock and canPlaceAtPosition(nearestBlock) then
                                            task.spawn(bedwars.placeBlock, nearestBlock, wool, false)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    task.wait(0.03)
                until not AutoBuildUp.Enabled
            end
        end,
        Tooltip = 'Automatically places blocks under you ONLY when jumping (no corner connections)'
    })
    
    LimitItem = AutoBuildUp:CreateToggle({
        Name = 'Limit to items',
        Default = false,
        Tooltip = 'Only place blocks when holding a block item'
    })
end)
	
run(function()
	local StaffHUD
	local ShowSpec
	local ShowCloset
	local ShowMod
	local ShowImpossible

	local STAFF_GROUP_ID = 5774246
	local STAFF_MIN_RANK = 100

	local closetIds = {1502104539,3826146717,4531785383,1049767300,4926350670,653085195,184655415,2752307430,5087196317,5744061325,1536265275}

	local rowDefs = {
		{key='spec',       label='Spec',       color=Color3.fromRGB(100,180,255), order=1},
		{key='closet',     label='Closet',     color=Color3.fromRGB(255,140,0),   order=2},
		{key='mod',        label='Mod',        color=Color3.fromRGB(255,60,60),   order=3},
		{key='impossible', label='Impossible', color=Color3.fromRGB(200,50,255),  order=4},
	}

	local tracked  = {}
	local counts   = {spec=0, closet=0, mod=0, impossible=0}
	local watchers = {}

		local apiClosetNames = {}
		local apiModNames = {}
		local listsLoaded = false

		local function loadLists()
			task.spawn(function()
				listsLoaded = true
			end)
		end

	local gui = Instance.new('ScreenGui')
	gui.Name = 'StaffHUD'
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = vape.gui
	gui.Enabled = false

	local frame = Instance.new('Frame')
	frame.Name = 'Container'
	frame.Parent = gui
	frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(1,1)
	frame.Position = UDim2.new(1,-8,1,-8)
	frame.Size = UDim2.new(0,110,0,14)
	frame.AutomaticSize = Enum.AutomaticSize.Y

	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0,6)
	uicorner.Parent = frame

	local pad = Instance.new('UIPadding')
	pad.PaddingLeft=UDim.new(0,6) pad.PaddingRight=UDim.new(0,6)
	pad.PaddingTop=UDim.new(0,4)  pad.PaddingBottom=UDim.new(0,4)
	pad.Parent = frame

	local layout = Instance.new('UIListLayout')
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0,2)
	layout.Parent = frame

	local rowObjects = {}
	for _, r in rowDefs do
		local lbl = Instance.new('TextLabel')
		lbl.Name = r.key
		lbl.Parent = frame
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1,0,0,13)
		lbl.TextColor3 = r.color
		lbl.TextSize = 11
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextStrokeTransparency = 0.4
		lbl.TextStrokeColor3 = Color3.new(0,0,0)
		lbl.LayoutOrder = r.order
		lbl.Visible = false
		rowObjects[r.key] = lbl
	end

	local function updateDisplay()
		if not StaffHUD or not StaffHUD.Enabled then gui.Enabled = false return end
		local toggleMap = {spec=ShowSpec,closet=ShowCloset,mod=ShowMod,impossible=ShowImpossible}
		local anyVisible = false
		for _, r in rowDefs do
			local show = toggleMap[r.key] and toggleMap[r.key].Enabled
			rowObjects[r.key].Text = r.label .. ': ' .. (counts[r.key] or 0)
			rowObjects[r.key].Visible = show
			if show then anyVisible = true end
		end
		gui.Enabled = anyVisible
	end

	local function setTracked(userId, newCat)
		local old = tracked[userId]
		if old == newCat then return end
		if old then counts[old] = math.max(0,(counts[old] or 1)-1) end
		if newCat then
			tracked[userId] = newCat
			counts[newCat] = (counts[newCat] or 0) + 1
		else
			tracked[userId] = nil
		end
		updateDisplay()
	end

	local function removePlayer(userId)
		setTracked(userId, nil)
		if watchers[userId] then
			for _, c in ipairs(watchers[userId]) do pcall(function() c:Disconnect() end) end
			watchers[userId] = nil
		end
	end

	local function hasFriendInServer(plr)
		for _, other in ipairs(playersService:GetPlayers()) do
			if other ~= plr then
				local ok, res = pcall(function() return plr:IsFriendsWith(other.UserId) end)
				if ok and res then return true end
			end
		end
		return false
	end

	local function recheckSpec(plr)
		if not StaffHUD or not StaffHUD.Enabled then return end
		local cat = tracked[plr.UserId]
		if cat == 'closet' or cat == 'mod' then return end
		if plr:GetAttribute('Spectator') == true then
			task.spawn(function()
				local hasFriend = hasFriendInServer(plr)
				setTracked(plr.UserId, hasFriend and 'spec' or 'impossible')
			end)
		else
			if cat == 'spec' or cat == 'impossible' then
				setTracked(plr.UserId, nil)
			end
		end
	end

	local function watchPlayer(plr)
		if plr == lplr or watchers[plr.UserId] then return end
		local conns = {}
		table.insert(conns, plr:GetAttributeChangedSignal('Spectator'):Connect(function() recheckSpec(plr) end))
		table.insert(conns, plr:GetAttributeChangedSignal('Team'):Connect(function() recheckSpec(plr) end))
		watchers[plr.UserId] = conns
	end

	local function classifyPlayer(plr)
		if plr == lplr then return end
		local lowerName = plr.Name:lower()

		if table.find(closetIds, plr.UserId) or apiClosetNames[lowerName] then
			setTracked(plr.UserId, 'closet')
			watchPlayer(plr)
			return
		end

		if apiModNames[lowerName] then
			setTracked(plr.UserId, 'mod')
			watchPlayer(plr)
			return
		end

		watchPlayer(plr)
		recheckSpec(plr)
	end

	local function cleanAll()
		for _, conns in pairs(watchers) do
			for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		end
		table.clear(watchers)
		table.clear(tracked)
		counts = {spec=0, closet=0, mod=0, impossible=0}
	end

	StaffHUD = vape.Categories.Utility:CreateModule({
		Name = 'StaffHUD',
		Function = function(callback)
			if callback then
				cleanAll()
				loadLists()
				task.spawn(function()
					local t = tick()
					repeat task.wait(0.1) until listsLoaded or (tick() - t > 5)
					for _, plr in ipairs(playersService:GetPlayers()) do
						classifyPlayer(plr)
					end
				end)
				StaffHUD:Clean(playersService.PlayerAdded:Connect(function(plr)
					classifyPlayer(plr)
				end))
				StaffHUD:Clean(playersService.PlayerRemoving:Connect(function(plr)
					removePlayer(plr.UserId)
				end))
				updateDisplay()
			else
				cleanAll()
				table.clear(apiClosetNames)
				table.clear(apiModNames)
				listsLoaded = false
				gui.Enabled = false
			end
		end,
		Tooltip = 'Live corner counter: Spectators, Closet Cheaters, Mods and Impossible Joins'
	})

	ShowSpec       = StaffHUD:CreateToggle({Name='Spectators',      Default=true, Function=function() updateDisplay() end})
	ShowCloset     = StaffHUD:CreateToggle({Name='Closet Cheaters', Default=true, Function=function() updateDisplay() end})
	ShowMod        = StaffHUD:CreateToggle({Name='Mods',            Default=true, Function=function() updateDisplay() end})
	ShowImpossible = StaffHUD:CreateToggle({Name='Impossible Joins',Default=true, Function=function() updateDisplay() end})

	vape:Clean(function()
		cleanAll()
		pcall(function() gui:Destroy() end)
	end)
end)
	
run(function()
	local AutoBuilder
	local Animation
	local Blacklist
	local BedCheck
	local Limit
	
	local function getBedNear(pos)
		local bed, lastmag = nil, math.huge
		local localPosition = pos or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			local mag = (localPosition - v.Position).Magnitude
			if mag < lastmag and v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then
				bed = v
				lastmag = mag
			end
		end
		return bed, lastmag
	end
	
	AutoBuilder = vape.Categories.Kits:CreateModule({
		Name = 'AutoBuilder',
		Function = function(callback)
			if callback then
				repeat
					task.wait()
				until store.matchState ~= 0 and store.equippedKit == 'builder' or not AutoBuilder.Enabled
				if not AutoBuilder.Enabled then
					return
				end
	
				local bed = getBedNear(entitylib.character.RootPart.Position)
				local blocks = collection('block', AutoBuilder, function(tab, obj)
					task.delay(0, function()
						if obj and not obj:GetAttribute('NoBreak') and obj:GetAttribute('PlacedByUserId') ~= nil then
							table.insert(tab, obj)
						end
					end)
				end)
				repeat
					if entitylib.isAlive and (not Limit.Enabled and getItem('hammer') or Limit.Enabled and store.hand.tool and store.hand.tool.Name == 'hammer') then
						bed = getBedNear(entitylib.character.RootPart.Position)
	
						for _, v in blocks do
							if not BedCheck.Enabled or (bed.Position - v.Position).Magnitude <= 30 then
								local name = v.Name
								if name:find('wool_') then
									name = 'wool'
								end
								if not table.find(Blacklist.ListEnabled, name) and not v:FindFirstChild('BuilderFortify') then
									bedwars.Client:Get('FortifyBlock'):SendToServer(({getPlacedBlock(v.Position)})[2])
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.BUILDER_HAMMER_HIT), {
											fadeInTime = 0.02
										})
										bedwars.SoundManager:playSound(bedwars.SoundList.FORTIFY_BLOCK,lplr.Character.HumanoidRootPart.Position)
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBuilder.Enabled
			end
		end
	})
	
	BedCheck = AutoBuilder:CreateToggle({
		Name = 'Bed Check',
		Tooltip = 'Checks if the block is near your bed'
	})
	Animation = AutoBuilder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays builder visuals (sfx and anim)'
	})
	Limit = AutoBuilder:CreateToggle({
		Name = 'Limit to items',
		Default = true
	})
	Blacklist = AutoBuilder:CreateTextList({
		Name = 'Blacklists',
		Placeholder = 'block',
		Default = {'cannon', 'wool'}
	})
end)

run(function()
	local AutoCaitlyn
	local Mode
	local Range
	local MinHP
	local TargetPriorities
	local activeSession
	
	local function getEntity(value)
		return typeof(value) == 'Instance' and entitylib.getEntity(value) or nil
	end
	
	local function getContract(contracts, ent)
		for _, v in contracts do
			if v.target == ent.Player or v.target and v.target.Name == ent.Player.Name then
				return v
			end
		end
		return nil
	end
	
	local function getValidTargets(wallcheck)
		local targets = {}
		for _, ent in entitylib.AllPosition({
			Part = 'RootPart',
			Players = true,
			Range = Range.Value,
			Wallcheck = wallcheck
		}) do
			if not (ent.Player.Team and ent.Player.Team.Name == 'Spectators') then
				targets[ent.Player] = ent
				targets[ent.Character] = ent
			end
		end
		return targets
	end
	
	local function hasBed(session, plr)
		local suc, team = pcall(bedwars.TeamController and bedwars.TeamController.getPlayerTeam, bedwars.TeamController, plr)
		local teamId = suc and team and team.id or plr:GetAttribute('Team')
		if teamId == nil then
			return true
		end
	
		local cached = session.beds[teamId]
		if cached and cached[2] > tick() then
			return cached[1]
		end
	
		suc, team = pcall(bedwars.BedwarsController and bedwars.BedwarsController.getTeamBed, bedwars.BedwarsController, teamId)
		local result = not suc or team and team.Parent ~= nil
		session.beds[teamId] = {result, tick() + 1}
		return result
	end
	
	local function getScore(session, contract, targets)
		local ent = targets[contract.target]
		if not ent then
			return nil
		end
	
		local health = ent.Humanoid.Health
		local distance = (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
		local score = 30 + ((tonumber(contract.rewardValue) or 0) * 35)
		score += (1 - math.clamp(health / math.max(ent.Humanoid.MaxHealth, 1), 0, 1)) * 35
		score += math.max(1 - (distance / Range.Value), 0) * 20
	
		if health <= MinHP.Value then
			score += 20
		end
		if (session.threats[ent.Player] or 0) > tick() then
			score += 30
		end
		if ent.Character:GetAttribute('BleedSource') == lplr.UserId then
			score += 25
		end
		if not hasBed(session, ent.Player) then
			score += 20
		end
	
		local reward = contract.rewardExplanation
		if type(reward) == 'table' then
			score += (reward.assassin and 10 or 0) + (reward.kitClass and 8 or 0) + (reward.gear and 6 or 0)
		end
		return score, ent
	end
	
	local function getPriorityContract(session, contracts)
		local bounty = false
		for _, v in contracts do
			if v.rewardValue ~= nil or v.rewardUpgrade ~= nil then
				bounty = true
				break
			end
		end
		if not bounty then
			return nil, false
		end
	
		local targets = getValidTargets(true)
		local current, currentScore
		if session.priorityId ~= nil then
			for _, v in contracts do
				if v.id == session.priorityId then
					current, currentScore = v, getScore(session, v, targets)
					break
				end
			end
		end
	
		local best, bestScore
		for _, v in contracts do
			local score = getScore(session, v, targets)
			if score and (not bestScore or score > bestScore) then
				best, bestScore = v, score
			end
		end
	
		if current and currentScore and best ~= current and bestScore < currentScore + 15 then
			best = current
		end
	
		session.priorityId = best and best.id or nil
		return best, true
	end
	
	local function getNormalContract(session, contracts)
		local hit = session.lastHit
		if hit and hit[2] > tick() then
			local ent = getValidTargets(false)[hit[1].Player]
			if ent == hit[1] then
				if Mode.Value == 'On Low' and ent.Humanoid.Health >= MinHP.Value then
					return nil
				end
				return getContract(contracts, ent)
			end
		end
	
		session.lastHit = nil
		return nil
	end
	
	local function selectContract(session, contract)
		if contract and not (session.pendingId == contract.id and session.pendingUntil > tick()) then
			bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
				contractId = contract.id
			})
			session.pendingId = contract.id
			session.pendingUntil = tick() + 1
		end
	end
	
	local function updateCaitlyn(session)
		if not entitylib.isAlive or store.matchState ~= 1 or store.equippedKit ~= 'blood_assassin' then
			session.lastHit = nil
			session.pendingId = nil
			session.priorityId = nil
			return
		end
	
		local kit = bedwars.Store:getState().Kit
		if not kit or kit.activeContract then
			session.pendingId = nil
			session.priorityId = kit and kit.activeContract and kit.activeContract.id or nil
			return
		end
	
		if session.pendingId and session.pendingUntil > tick() then
			return
		end
		session.pendingId = nil
	
		local contracts = kit.availableContracts
		if not contracts or #contracts == 0 then
			return
		end
	
		local contract
		if TargetPriorities.Enabled then
			local available
			contract, available = getPriorityContract(session, contracts)
			if not available then
				contract = getNormalContract(session, contracts)
			end
		else
			session.priorityId = nil
			contract = getNormalContract(session, contracts)
		end
		selectContract(session, contract)
	end
	
	AutoCaitlyn = vape.Categories.Kits:CreateModule({
		Name = 'AutoCaitlyn',
		Function = function(callback)
			if callback then
				local session = {
					beds = {},
					nextUpdate = 0,
					pendingUntil = 0,
					threats = {}
				}
				activeSession = session
	
				AutoCaitlyn:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if activeSession ~= session then
						return
					end
	
					local source = getEntity(damageTable.fromEntity)
					if damageTable.entityInstance == lplr.Character and source and source.Player then
						session.threats[source.Player] = tick() + 3
					elseif damageTable.fromEntity == lplr.Character or damageTable.fromEntity == lplr then
						local victim = getEntity(damageTable.entityInstance)
						if victim then
							session.lastHit = {victim, tick() + 1}
						end
					end
				end))
	
				AutoCaitlyn:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function()
					table.clear(session.beds)
				end))
	
				AutoCaitlyn:Clean(entitylib.Events.LocalAdded:Connect(function()
					session.lastHit = nil
					session.pendingId = nil
				end))
	
				if entitylib.Events.LocalRemoved then
	
					AutoCaitlyn:Clean(entitylib.Events.LocalRemoved:Connect(function()
						session.lastHit = nil
						session.pendingId = nil
						session.priorityId = nil
					end))
	
				end
	
				repeat
					if tick() >= session.nextUpdate then
						session.nextUpdate = tick() + 0.2
						updateCaitlyn(session)
					end
					task.wait(0.05)
				until not AutoCaitlyn.Enabled or activeSession ~= session
	
				if activeSession == session then
					activeSession = nil
				end
			else
				activeSession = nil
			end
		end,
		Tooltip = 'Automatically assigns a player\'s contract when a specific action happens'
	})
	
	Mode = AutoCaitlyn:CreateDropdown({
		Name = 'Contract mode',
		List = {'On Hit', 'On Low'},
		Tooltip = 'On Hit - Contracts them whenever u start hitting them\nOn Low - When they\'re low',
		Function = function(val)
			if MinHP then
				MinHP.Object.Visible = val == 'On Low'
			end
		end,
		Default = 'On Low'
	})
	MinHP = AutoCaitlyn:CreateSlider({
		Name = 'Minimum Health',
		Tooltip = 'How low they have to be before contracting',
		Min = 1,
		Max = 100,
		Default = 30,
		Darker = true,
		Visible = false
	})
	Range = AutoCaitlyn:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	TargetPriorities = AutoCaitlyn:CreateToggle({
		Name = 'Target Priorities',
		Function = function()
			if activeSession then
				activeSession.priorityId = nil
			end
		end
	})
end)

run(function()
	local AutoElder
	local Streamer
	local Range
	local Animation
	local Delay
	
	local Legit = (bedwars.EldertreeController and bedwars.EldertreeController.createTreeOrbInteraction and getFunctionRange(bedwars.EldertreeController.createTreeOrbInteraction)) or 10
	
	AutoElder = vape.Categories.Kits:CreateModule({
		Name = 'AutoElder',
		Function = function(call)
			if call then
				AutoElder:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'treeOrb' then
						task.delay(0.1, prompt.InputHoldBegin, prompt)
					end
				end))
	
				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for i, v in collectionService:GetTagged('treeOrb') do
							if tick() > (Delay[v] or 0) and (localPosition - v.Spirit.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
	
								if (localPosition - v.Spirit.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
										bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
									end
									if bedwars.Client:Get('ConsumeTreeOrb'):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
										v:Destroy()
									end
									Delay[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoElder.Enabled
			end
		end,
		Tooltip = 'Automatically collects tree orbs'
	})
	
	Streamer = AutoElder:CreateToggle({
		Name = 'Streamer mode',
		Tooltip = 'Useful for when ur screensharing',
		Function = function(call)
			pcall(function()
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end)
		end
	})
	Animation = AutoElder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoElder:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoElder:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoElder:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end,
		Default = 0.2,
		Decimal = 100
	})
end)

run(function()
	local AutoEmber
	local Targets
	local Range
	local Delay
	local Limit
	
	AutoEmber = vape.Categories.Kits:CreateModule({
		Name = 'AutoEmber',
		Function = function(call)
			if call then
				local clock = os.clock()
				repeat
					if entitylib.isAlive then
						local tool = getItem('infernal_saber')
						if tool and (not Limit.Enabled or store.hand.tool and store.hand.tool == tool) and entitylib.EntityPosition({
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
						}) then
							if Delay.Value <= 0 or (os.clock() - clock) >= Delay.Value then
								bedwars.Client:Get('HellBladeRelease'):SendToServer({
									chargeTime = 1,
									weapon = tool,
									player = lplr,
								})
								clock = os.clock()
							end
						end
					end
					task.wait()
				until not AutoEmber.Enabled
			end
		end
	})
	
	Targets = AutoEmber:CreateTargets({
		Players = true,
		NPCs = false
	})
	Delay = AutoEmber:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	Range = AutoEmber:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Limit = AutoEmber:CreateToggle({Name = 'Limit to item'})
	
end)

run(function()
	local AutoGingerbread
	local Range
	local Delay
	local Break
	local Jump
	local Switch
	local OwnOnly
	local SuccessfulOnly
	
	local old
	local hook
	
	local function canUseBlock(block)
		if not entitylib.isAlive or typeof(block) ~= 'Instance' or not block:IsA('BasePart') then
			return false
		end
	
		if store.equippedKit ~= 'gingerbread_man' then
			return false
		end
	
		if OwnOnly.Enabled and block:GetAttribute('PlacedByUserId') ~= lplr.UserId then
			return false
		end
	
		return (block.Position - entitylib.character.RootPart.Position).Magnitude <= Range.Value
	end
	
	AutoGingerbread = vape.Categories.Kits:CreateModule({
		Name = 'AutoGingerbreadMan',
		Function = function(callback)
			if callback then
				if not bedwars.LaunchPadController then return end
				local original = bedwars.LaunchPadController.attemptLaunch
				old = original
				hook = function(...)
					local controller, block = ...
					local lastLaunch = controller and controller.lastLaunch or 0
	
					if AutoGingerbread.Enabled and (not SuccessfulOnly.Enabled or (controller and controller.lastLaunch and (controller.lastLaunch ~= lastLaunch or workspace:GetServerTimeNow() - controller.lastLaunch < 0.5))) then
						if Break.Enabled and canUseBlock(block) then
							task.delay(Delay.Value, function()
								if AutoGingerbread.Enabled and block.Parent then
									bedwars.breakBlock(block, false, nil, true, nil, Switch.Enabled)
								end
							end)
						end
	
						if Jump.Enabled and entitylib.isAlive then
							lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
	
					return original(...)
				end
				bedwars.LaunchPadController.attemptLaunch = hook
			elseif old then
				if bedwars.LaunchPadController and bedwars.LaunchPadController.attemptLaunch == hook then
					bedwars.LaunchPadController.attemptLaunch = old
				end
				old = nil
				hook = nil
			end
		end,
		Tooltip = 'Automatically handles Gingerbread Man launch pads.'
	})
	
	Break = AutoGingerbread:CreateToggle({
		Name = 'Break launch pad',
		Default = true,
		Function = function(call)
			pcall(function()
				Range.Object.Visible = call
				Delay.Object.Visible = call
				Switch.Object.Visible = call
				OwnOnly.Object.Visible = call
			end)
		end
	})
	Jump = AutoGingerbread:CreateToggle({Name = 'Jump after launch'})
	Switch = AutoGingerbread:CreateToggle({
		Name = 'Legit switch',
		Darker = true
	})
	OwnOnly = AutoGingerbread:CreateToggle({
		Name = 'Own pads only',
		Default = true,
		Darker = true
	})
	SuccessfulOnly = AutoGingerbread:CreateToggle({
		Name = 'Successful launch only',
		Default = true
	})
	Range = AutoGingerbread:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoGingerbread:CreateSlider({
		Name = 'Break delay',
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'sec' or 'secs'
		end
	})
	
end)

run(function()
	local AutoHannah
	local Range
	
	AutoHannah = vape.Categories.Kits:CreateModule({
		Name = 'AutoHannah',
		Function = function(callback)
			if callback then
				local objs = collection('HannahExecuteInteraction', AutoHannah)
				repeat
					if entitylib.isAlive and store.equippedKit == 'hannah' then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in objs do
							if not AutoHannah.Enabled then
								break
							end
	
							local part = not v:IsA('Model') and v or v.PrimaryPart
							if part and (part.Position - localPosition).Magnitude <= Range.Value then
								local billboard = bedwars.Client:Get('HannahPromptTrigger'):CallServer({
									user = lplr,
									victimEntity = v,
								}) and v:FindFirstChild('Hannah Execution Icon')
	
								if billboard then
									billboard:Destroy()
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoHannah.Enabled
			end
		end,
		Tooltip = 'Automatically executes low health players with Hannah.'
	})
	
	AutoHannah:CreateTargets({Players = true}) -- cosmetic settings lmao
	Range = AutoHannah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	AutoHannah:CreateDropdown({
		Name = 'Target mode', 
		List = methods,
		Default = 'Health'
	})
	AutoHannah:CreateToggle({
		Name = 'Only killaura target',
		Tooltip = 'Only executes targets that are being attacked by killaura'
	})
end)

run(function()
	local AutoHephaestus
	local lastRepair = 0
	
	AutoHephaestus = vape.Categories.Kits:CreateModule({
		Name = 'AutoHephaestus',
		Function = function(callback)
			if callback then
				AutoHephaestus:Clean(runService.Heartbeat:Connect(function()
					if tick() >= lastRepair and store.equippedKit == 'tinker' and (bedwars.TinkerKitController and bedwars.TinkerKitController.mounted) and bedwars.AbilityController:canUseAbility('tinker_self_repair') and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 1 then
						lastRepair = tick() + 0.5
						bedwars.AbilityController:useAbility('tinker_self_repair')
					end
				end))
			end
		end,
		Tooltip = 'Automatically repairs your Tinker machine whenever the self repair ability is available'
	})
	
end)

run(function()
	local AutoKaliyah
	local Range
	local Delay
	local NoSlow
	
	local Legit = (bedwars.DragonSlayerController.onKitLocalActivated and getFunctionRange(bedwars.DragonSlayerController.onKitLocalActivated)) or 14.4
	local modifier, oldAddModifier, newAddModifier
	local noSlowUntil = 0
	
	local function hookModifier()
		if newAddModifier then return end
		modifier = bedwars.SprintController:getMovementStatusModifier()
		oldAddModifier = modifier and modifier.addModifier
		if typeof(oldAddModifier) ~= 'function' then
			modifier, oldAddModifier = nil, nil
			return
		end
		newAddModifier = function(self, tab)
			if AutoKaliyah.Enabled and NoSlow.Enabled and tick() < noSlowUntil and type(tab) == 'table' and tab.moveSpeedMultiplier == 0 then
				tab.moveSpeedMultiplier = 1
			end
			return oldAddModifier(self, tab)
		end
		modifier.addModifier = newAddModifier
		AutoKaliyah:Clean(function()
			if modifier and modifier.addModifier == newAddModifier then
				modifier.addModifier = oldAddModifier
			end
			modifier, oldAddModifier, newAddModifier = nil, nil, nil
			noSlowUntil = 0
		end)
	end
	
	local function func(v)
		if NoSlow.Enabled then
			hookModifier()
			noSlowUntil = math.max(noSlowUntil, tick() + Delay.Value + 0.1)
		end
	
		task.wait(Delay.Value)
		bedwars.DragonSlayerController:deleteEmblem(v)
		bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
	
		bedwars.Client:Get('RequestDragonPunch'):SendToServer({
			target = v
		})
	end
	
	AutoKaliyah = vape.Categories.Kits:CreateModule({
		Name = 'AutoKaliyah',
		Function = function(call)
			if call then
				local objs = collection('KaliyahPunchInteraction', AutoKaliyah)
	
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in objs do
							if not AutoKaliyah.Enabled then
								break
							end
	
							local part = not v:IsA('Model') and v or v.PrimaryPart
							if part and (part.Position - localPosition).Magnitude <= Range.Value then
								func(v)
							end
						end
					end
					task.wait(0.1)
				until not AutoKaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "punch" ability from kaliyah'
	})
	
	NoSlow = AutoKaliyah:CreateToggle({
		Name = 'No Slow',
		Tooltip = 'Prevents you from being slowed down after using the "Punch" ability',
		Default = true
	})
	Range = AutoKaliyah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 18,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoKaliyah:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoKaliyah:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	
end)

run(function()
	local AutoLani
	local Delay
	local UseEnemy
	local Enemy
	local Player
	
	local Request = {Fire = function(self, ...) end}
	pcall(function()
		Request = bedwars.Client:Get('PaladinAbilityRequest')
	end)
	
	AutoLani = vape.Categories.Minigames:CreateModule({
		Name = 'AutoLani',
		Function = function(callback)
			if callback then
				local oldstart = 0
	
				repeat
					local start = (lplr:GetAttribute('PaladinStartTime') or 0)
					if oldstart and oldstart ~= start then
						local player = UseEnemy.Enabled and playersService:FindFirstChild(Enemy.Value) or not UseEnemy.Enabled and playersService:FindFirstChild(Player.Value) or nil
	
						if player then
							task.delay(Delay.Value, function()
								if AutoLani.Enabled and player.Parent == playersService then
									Request:SendToServer({target = player})
								end
							end)
						end
					end
					oldstart = start
					task.wait(0.1)
				until not AutoLani.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "scepter of light" ability'
	})
	
	local friends, enemies = {'None'}, {'None'}
	local teamConnections = {}
	
	local function rebuildPlayers()
		table.clear(friends)
		table.clear(enemies)
		table.insert(friends, 'None')
		table.insert(enemies, 'None')
		for _, plr in playersService:GetPlayers() do
			if plr:GetAttribute('Team') == lplr:GetAttribute('Team') then
				table.insert(friends, plr.Name)
			elseif plr.Team and plr.Team.Name ~= 'Spectators' then
				table.insert(enemies, plr.Name)
			end
		end
		Player:Change(friends)
		Enemy:Change(enemies)
	end
	
	local function addConnection(plr)
		if teamConnections[plr] then
			teamConnections[plr]:Disconnect()
		end
		teamConnections[plr] = plr:GetAttributeChangedSignal('Team'):Connect(rebuildPlayers)
		rebuildPlayers()
	end
	
	Player = AutoLani:CreateDropdown({
		Name = 'Selected Player',
		List = {},
		Tooltip = 'Player to use the ability on'
	})
	Enemy = AutoLani:CreateDropdown({
		Name = 'Selected Enemy',
		List = {},
		Tooltip = 'Target to use the ability on',
		Visible = false
	})
	UseEnemy = AutoLani:CreateToggle({
		Name = 'Use enemy',
		Function = function(call)
			Enemy.Object.Visible = call
			Player.Object.Visible = not call
		end,
		Tooltip = 'Uses the ability on other people instead of your teammates'
	})
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		if teamConnections[plr] then
			teamConnections[plr]:Disconnect()
			teamConnections[plr] = nil
		end
		rebuildPlayers()
	end))
	vape:Clean(function()
		for _, connection in teamConnections do
			connection:Disconnect()
		end
		table.clear(teamConnections)
	end)
	Delay = AutoLani:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 20,
		Default = 5,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end,
		Decimal = 10,
		Tooltip = 'Delay between triggers'
	})
	
end)

run(function()
	local AutoMarina
	local Range
	
	AutoMarina = vape.Categories.Kits:CreateModule({
		Name = 'AutoMarina',
		Function = function(call)
			if call then
				local jellies = collection('jellyfish', AutoMarina, function(tab, obj)
					task.delay(0, function()
						if obj:GetAttribute('PlacedByUserId') == lplr.UserId then
							table.insert(tab, obj)
						end
					end)
				end)
				repeat
					if entitylib.isAlive and bedwars.AbilityController:canUseAbility('electrify_jellyfish') then
						for _, v in jellies do
							if v.PrimaryPart then
								if entitylib.EntityPosition({
									Origin = v.PrimaryPart.Position,
									Range = Range.Value,
									Part = 'RootPart',
									Players = true
								}) then
									bedwars.AbilityController:useAbility('electrify_jellyfish')
									break
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoMarina.Enabled
			end
		end,
		Tooltip = 'Automatically uses "electrify" ability when enemies are near jellies.'
	})
	
	Range = AutoMarina:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 65,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
	})
end)

run(function()
	local AutoMartin
	local Targets
	local Range
	
	AutoMartin = vape.Categories.Kits:CreateModule({
	    Name = 'AutoMartin',
	    Function = function(callback)
	        if callback then
	            repeat
	                local ent = entitylib.EntityPosition({
	                    Range = Range.Value,
	                    Part = 'RootPart',
	                    Wallcheck = Targets.Walls.Enabled,
	                    Players = Targets.Players.Enabled,
	                    NPCs = Targets.NPCs.Enabled,
	                    Sort = sortmethods.Distance,
	                })
	                if ent and bedwars.AbilityController:canUseAbility('cactus_fire') then
	                    bedwars.AbilityController:useAbility('cactus_fire')
	                end
	                task.wait(0.1)
	            until not AutoMartin.Enabled
	        end
	    end,
	    Tooltip = 'Automatically uses "Wild growth" ability when within range.'
	})
	
	Targets = AutoMartin:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoMartin:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 0 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoMelody
	local Range
	local SelfHeal
	local TeammateHeal
	
	AutoMelody = vape.Categories.Kits:CreateModule({
		Name = 'AutoMelody',
		Function = function(callback)
			if callback then
				repeat
					local mag, hp, ent = Range.Value, math.huge, nil
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Player and (SelfHeal.Enabled or v.Player ~= lplr) and (TeammateHeal.Enabled and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') or not TeammateHeal.Enabled and SelfHeal.Enabled and v.Player == lplr) then
								local newmag = (localPosition - v.RootPart.Position).Magnitude
								if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
									mag, hp, ent = newmag, v.Health, v
								end
							end
						end
					end
	
					if ent and getItem('guitar') then
						bedwars.Client:Get('GuitarHeal'):SendToServer({
							healTarget = ent.Character
						})
					end
	
					task.wait(0.1)
				until not AutoMelody.Enabled
			end
		end,
		Tooltip = 'Automatically uses the guitar to heal ur teammates/urself'
	})
	
	SelfHeal = AutoMelody:CreateToggle({
		Name = 'Self Heal',
		Default = true
	})
	TeammateHeal = AutoMelody:CreateToggle({
		Name = 'Teammate Heal',
		Default = true
	})
	Range = AutoMelody:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 4
	})
end)

run(function()
	local AutoMetal
	local Limit
	local StreamerMode
	local Duration
	local Range
	local Animation
	
	local Legit = (bedwars.HiddenMetalController and bedwars.HiddenMetalController.onKitLocalActivated and getFunctionRange(bedwars.HiddenMetalController.onKitLocalActivated)) or 0
	local Delay = {}
	
	AutoMetal = vape.Categories.Kits:CreateModule({
		Name = 'AutoMetal',
		Function = function(call)
			if call then
				AutoMetal:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if StreamerMode.Enabled then
						if prompt.Name == 'hidden-metal-prompt' and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
							task.wait(0.1)
							prompt:InputHoldBegin()
						end
					end
				end))
	
				repeat
					if not StreamerMode.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for i, v in collectionService:GetTagged('hidden-metal') do
							if tick() > (Delay[v] or 0) and (localPosition - v.Part.Position).Magnitude <= Range.Value and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
								if Duration.Value > 0 then
									task.wait(Duration.Value)
								end
	
								if (localPosition - v.Part.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.SHOVEL_DIG)
										bedwars.SoundManager:playSound(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
									end
									bedwars.Client:Get('CollectCollectableEntity'):SendToServer({
										id = v:GetAttribute('Id')
									})
									Delay[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoMetal.Enabled
			end
		end,
		Tooltip = 'Automatically uses the metal kit'
	})
	
	Limit = AutoMetal:CreateToggle({Name = 'Limit to item'})
	StreamerMode = AutoMetal:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			pcall(function()
				Duration.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end)
		end,
		Tooltip = 'Actually does the metal prompt thing for you'
	})
	Animation = AutoMetal:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the metal collect animation'
	})
	Range = AutoMetal:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = Legit,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoMetal:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Duration = AutoMetal:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end,
		Default = 0.2,
		Decimal = 5
	})
end)

run(function()
	local AutoMiner
	local Delay
	local Animation
	local Range
	
	local Legit = (bedwars.MinerController and bedwars.MinerController.setupMinerPrompts and getFunctionRange(bedwars.MinerController.setupMinerPrompts)) or 0
	
	AutoMiner = vape.Categories.Kits:CreateModule({
	    Name = 'AutoMiner',
	    Function = function(callback)
	        if callback then
	            local souls = collection('petrified-player', AutoMiner)
	            local cooldown = 0
	            repeat
	                if entitylib.isAlive and (tick() - cooldown) >= Delay.Value then
	                    local localPosition = entitylib.character.RootPart.Position
	                    for _, v in souls do
	                    	local soulPos = v.PrimaryPart and v.PrimaryPart.Position or (v:IsA('BasePart') and v.Position or v:GetPivot().Position)
	                        if (localPosition - soulPos).Magnitude <= Range.Value then
	                            bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.MINER_MINE_STONE)
	                            task.delay(Delay.Value, function()
	                                if AutoMiner.Enabled and v.Parent then
	                                    bedwars.Client:Get('DestroyPetrifiedPlayer'):SendToServer({
	                                        petrifyId = v:GetAttribute('Id')
	                                    })
	                                end
	                            end)
	                            cooldown = tick()
	                            break
	                        end
	                    end
	                end
	                task.wait(0.1)
	            until not AutoMiner.Enabled
	        end
	    end
	})
	
	Range = AutoMiner:CreateSlider({
	    Name = 'Range',
	    Min = 1,
	    Max = 30,
	    Default = 12,
	    Suffix = function(val)
	        return val <= 1 and 'stud' or 'studs'
	    end
	})
	AutoMiner:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoMiner:CreateSlider({
	    Name = 'Delay',
	    Min = 0,
	    Max = 2,
	    Default = 0.1,
	    Suffix = 'seconds',
	    Decimal = 10
	})
	Animation = AutoMiner:CreateToggle({Name = 'Animation', Default = true})
	
end)

run(function()
	local AutoNoelle
	local Notify
	local FrostySlime
	local HealSlime
	local StickySlime
	local VoidSlime
	local Limit
	
	local function getSlimes()
		local slimes = {}
		local folder = workspace:FindFirstChild('SlimeModelFolder')
		if not folder then return {} end
		for _, v in folder:GetChildren() do
			local data = v:FindFirstChild('SlimeData')
			data = data and data.Value or nil
	
			if data and data.Tamer.Value == lplr.UserId then
				table.insert(slimes, {
					Data = data, 
					RootPart = v, 
					Name = v.Name:gsub(`_{lplr.Name}`, ''):gsub('Slime', ' Slime')
				})
			end
		end
		return slimes
	end
	
	local function getPlayer(name)
		for _, v in playersService:GetPlayers() do
			if (`{v.DisplayName} ({v.Name})`) == name then
				return v
			end
		end
		return
	end
	
	AutoNoelle = vape.Categories.Kits:CreateModule({
		Name = 'AutoNoelle',
		Function = function(call)
			if call then
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'slime_tamer_flute') then
						local slimes = getSlimes()
	
						for _, v in slimes do
							local dropdown = AutoNoelle.Options[`{v.Name} Target`]
							if dropdown then
								local player = getPlayer(dropdown.Value)
								if player and v.Data.Following.Value ~= player.UserId then
									bedwars.Client:Get('RequestMoveSlime'):CallServerAsync({
										slimeId = v.Data:GetAttribute('Id'),
										targetPlayerUserId = player.UserId,
									}):andThen(function(suc)
										if suc then
											v.Data.Following.Value = player.UserId
											if Notify.Enabled then
												notif('AutoNoelle', `Directed {v.Name} to {player.DisplayName} ({player.Name})`, 5, 'info')
											end
										end
									end)
								end
							end
						end
					end
					task.wait(0.5)
				until not AutoNoelle.Enabled
			end
		end,
		Tooltip = 'Automatically directs the slimes to the selected player\'s'
	})
	
	local friends = { 'None' }
	
	local function addConnection(plr)
		if plr:GetAttribute('Team') == lplr:GetAttribute('Team') then
			table.insert(friends, `{plr.DisplayName} ({plr.Name})`)
			FrostySlime:Change(friends)
			HealSlime:Change(friends)
			StickySlime:Change(friends)
			VoidSlime:Change(friends)
		end
	
		vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
			if plr:GetAttribute('Team') == lplr:GetAttribute('Team') then
				table.insert(friends, `{plr.DisplayName} ({plr.Name})`)
				FrostySlime:Change(friends)
				HealSlime:Change(friends)
				StickySlime:Change(friends)
				VoidSlime:Change(friends)
			end
		end))
	end
	
	Notify = AutoNoelle:CreateToggle({ Name = 'Notify on direct' })
	Limit = AutoNoelle:CreateToggle({ Name = 'Limit to item' })
	FrostySlime = AutoNoelle:CreateDropdown({
		Name = 'Frosty Slime Target',
		List = {},
		Tooltip = 'Player to direct frost slimes to',
	})
	HealSlime = AutoNoelle:CreateDropdown({
		Name = 'Heal Slime Target',
		List = {},
		Tooltip = 'Player to direct heal slimes to',
	})
	StickySlime = AutoNoelle:CreateDropdown({
		Name = 'Sticky Slime Target',
		List = {},
		Tooltip = 'Player to direct sticky slimes to',
	})
	VoidSlime = AutoNoelle:CreateDropdown({
		Name = 'Void Slime Target',
		List = {},
		Tooltip = 'Player to direct void slimes to',
	})
	
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)

run(function()
	local AutoNyx
	local Targets
	
	AutoNyx = vape.Categories.Kits:CreateModule({
		Name = 'AutoNyx',
		Function = function(call)
			if call then
				AutoNyx:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.damageType == 0 and damageTable.fromEntity and damageTable.fromEntity.Name == lplr.Name and entitylib.EntityPosition({
						Range = 14.4,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
					}) and bedwars.AbilityController:canUseAbility('midnight') then
						bedwars.AbilityController:useAbility('midnight')
					end
				end))
			end
		end,
		Tooltip = 'Automatically uses the "midnight" ability when meleeing a target'
	})
	
	Targets = AutoNyx:CreateTargets({
		Players = true,
		NPCs = false
	})
end)

run(function()
	local AutoPyro
	
	local list = {'Range', 'Heat', 'Power'}
	
	AutoPyro = vape.Categories.Kits:CreateModule({
		Name = 'AutoPyro',
		Function = function(callback)
			if callback then
				repeat
					local flamethrower = getItem('flamethrower')
					if flamethrower then
						for _, v in list do
							if not AutoPyro.Options['Buy ' .. v].Enabled then
								table.remove(list, table.find(list, v))
							end
						end
	
						for _, v in list do
							v = v:lower()
							local value = flamethrower.tool:GetAttribute(v) or -1
							if value < 3 then
								local nextUpgrade = bedwars.PyroUpgradeMeta and bedwars.PyroUpgradeMeta[v].tiers[value + 2]
								if nextUpgrade then
									local currency = getItem(nextUpgrade.currency)
									if currency and currency.amount >= nextUpgrade.price then
										bedwars.Client:Get('UpgradeFlamethrower'):CallServer(v)
										task.wait(0.1)
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoPyro.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades flamethrower'
	})
	
	for _, i in list do
		AutoPyro:CreateToggle({
			Name = 'Buy ' .. i,
			Default = true
		})
	end
end)

run(function()
	local AutoRamil
	local Range
	local Sorts
	local Targets
	local UseTornando
	local TonradoRange
	
	AutoRamil = vape.Categories.Kits:CreateModule({
		Name = 'AutoRamil',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'airbender' then
						local localPosition = entitylib.character.RootPart.Position
						local ent = entitylib.EntityPosition({
							Origin = localPosition,
							Range = (UseTornando.Enabled and TonradoRange.Value > Range.Value and TonradoRange.Value or Range.Value),
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sorts.Value],
						})
	
						if ent then
							if (localPosition - ent.RootPart.Position).Magnitude <= Range.Value and bedwars.AbilityController:canUseAbility('airbender_tornado') then
								bedwars.AbilityController:useAbility('airbender_tornado')
							end
	
							if UseTornando.Enabled and (localPosition - ent.RootPart.Position).Magnitude <= TonradoRange.Value and bedwars.AbilityController:canUseAbility('airbender_moving_tornado') then
								bedwars.AbilityController:useAbility('airbender_moving_tornado')
							end
						end
					end
					task.wait()
				until not AutoRamil.Enabled
			end
		end,
		Tooltip = 'Automatically use ramil abilities on certain conditions.'
	})
	
	Targets = AutoRamil:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sorts = AutoRamil:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Range = AutoRamil:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 25,
		Default = 25,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
	UseTornando = AutoRamil:CreateToggle({
		Name = 'Use Moving Tornado',
		Function = function(call)
			pcall(function()
				TonradoRange.Object.Visible = call
			end)
		end
	})
	TonradoRange = AutoRamil:CreateSlider({
		Name = 'Tornado Range',
		Min = 1,
		Max = 35,
		Default = 25,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
end)

run(function()
	local AutoSheep
	local Delay
	local Range
	
	local tameSheep = {SendToServer = function(self, ...) end}
	pcall(function()
		tameSheep = bedwars.Client:GetNamespace('SheepHerder'):Get('TameSheep')
	end)
	
	AutoSheep = vape.Categories.Minigames:CreateModule({
		Name = 'AutoSheepHerder',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local model = workspace:FindFirstChild('SheepModel') or workspace
	
						for _, v in model:GetChildren() do
							if v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
								tameSheep:SendToServer(v.SheepData.Value)
							end
						end
					end
					task.wait(0.1)
				until not AutoSheep.Enabled
			end
		end,
		Tooltip = 'Automatically tames sheep within range.'
	})
	
	Range = AutoSheep:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Default = 20
	})
	Delay = AutoSheep:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)

run(function()
	local AutoStar
	local Streamer
	local Range
	local Animation
	local Delay
	
	AutoStar = vape.Categories.Kits:CreateModule({
		Name = 'AutoStarCollector',
		Function = function(callback)
			if callback then
				AutoStar:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled then
						if prompt.Name == 'stars_ProximityPrompt' then
							task.wait(0.1)
							prompt:InputHoldBegin()
						end
					end
				end))
	
				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for i, v in collectionService:GetTagged('stars') do
							if tick() > (Delay[v] or 0) and v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
	
								if (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									end
									bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
									Delay[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoStar.Enabled
			end
		end,
		Tooltip = 'Automatically collects stars'
	})
	
	Streamer = AutoStar:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			pcall(function()
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end)
		end,
		Tooltip = 'Useful for when ur screensharing'
	})
	Animation = AutoStar:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoStar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	Delay = AutoStar:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end,
		Default = 0.2,
		Decimal = 100
	})
end)

run(function()
	local AutoTaliyah
	local Emerald
	local Diamond
	local Iron
	local Amount
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	AutoTaliyah = vape.Categories.Kits:CreateModule({
		Name = 'AutoTaliyah',
		Tooltip = 'Automatically buy chickens when it sells for emerald',
		Function = function(callback)
			if callback then
				local item = bedwars.Shop.getShopItem('chicken_shop_item', lplr)
				repeat
					local shopNpc, items, __, id = getShopNPC()
					if shopNpc and items then
						local chickenData = (bedwars.TaliyahUtil and bedwars.TaliyahUtil:getPrice()) or {}
						if (chickenData.currency == 'emerald' and Emerald.Enabled or chickenData.currency == 'iron' and Iron.Enabled or chickenData.currency == 'diamond' and Diamond.Enabled) and chickenData.price >= Amount.Value then
							bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
								shopItem = item,
								shopId = id
							}):andThen(function(suc)
								if suc then
									bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
									bedwars.Store:dispatch({
										type = 'BedwarsAddItemPurchased',
										itemType = item.itemType
									})
									bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
								end
							end)
						end
					end
					task.wait(0.1)
				until not AutoTaliyah.Enabled
			end
		end,
	})
	
	Iron = AutoTaliyah:CreateToggle({
		Name = 'Iron',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is iron'
	})
	Emerald = AutoTaliyah:CreateToggle({
		Name = 'Emerald',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is emerald'
	})
	Diamond = AutoTaliyah:CreateToggle({
		Name = 'Diamond',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is diamond'
	})
	Amount = AutoTaliyah:CreateSlider({
		Name = 'Amount',
		Default = 2,
		Min = 1,
		Max = 1000,
		Tooltip = 'Only sells if the currency is selling for the selected amount'
	})
end)

run(function()
	local AutoTriton
	local Legit
	local Back
	local BackDelay
	local Limit
	
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local projectileRemote = {InvokeServer = function(self, ...) end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get('ProjectileFire').instance
	end)
	
	local function firePearl(pos, spot, item)
		local hotbar, old = getHotbar(item.tool), store.hand
	
		switchItem(item.tool)
		if Legit.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end
	
		local meta = bedwars.ProjectileMeta.harpoon_projectile
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
		local landed = false
	
		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'harpoon_projectile', 'harpoon_projectile', pos, nil, dir, {drawDurationSeconds = 1})
			local res = projectileRemote:InvokeServer(
				item.tool,
				'harpoon_projectile',
				'harpoon_projectile',
				pos,
				pos,
				dir,
				httpService:GenerateGUID(true),
				{ 
	                drawDurationSeconds = 1, 
	                shotId = httpService:GenerateGUID(false) 
	            },
				workspace:GetServerTimeNow() - 0.045
			)
			task.spawn(function()
				local timeout = tick() + 10
				repeat
					task.wait()
				until not AutoTriton.Enabled or not projectile or not projectile.Parent or tick() >= timeout
				landed = true
			end)
			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)
			end
		else
			landed = true
		end
	
	    repeat
	        task.wait() 
	    until landed or not AutoTriton.Enabled
		if Back.Enabled and old and old.tool then
			task.wait(BackDelay:GetRandomValue())
			switchItem(old.tool)
			if Legit.Enabled and getHotbar(old.tool) then
				hotbarSwitch(getHotbar(old.tool))
			end
		end
	end
	
	local function findNearGround(origin)
		for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
			for i = 1, 24 do
				local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), rayCheck)
				if ray then
					return ray.Position
				end
			end
		end
		return nil
	end
	
	AutoTriton = vape.Categories.Kits:CreateModule({
		Name = 'AutoTriton',
		Function = function(callback)
			if callback then
				local check, lasty
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'harpoon') then
						local root = entitylib.character.RootPart
						local pearl = getItem('harpoon')
						rayCheck.FilterDescendantsInstances = {store.map}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lasty = root.CFrame
						end
	
						if pearl and root.Velocity.Y < -60 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoTriton.Enabled
			end
		end,
		Tooltip = 'Automatically throws triton trident onto nearby ground after\nfalling a certain distance.'
	})
	
	Legit = AutoTriton:CreateToggle({
		Name = 'Legit Switch',
		Tooltip = 'Visualizes the switching clientside',
		Default = true
	})
	Back = AutoTriton:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Function = function(callback)
			if BackDelay then
				BackDelay.Object.Visible = callback
			end
		end,
		Tooltip = 'Switches back to the last slot before pearl'
	})
	BackDelay = AutoTriton:CreateTwoSlider({
		Name = 'Switch Back Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Limit = AutoTriton:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only throws pearl when holding a pearl'
	})
	
end)

run(function()
	local AutoUma
	local Range
	local Limit
	local Animation
	local AutoSummon
	local HealSpirit
	local AttackSpirit
	local TargetItemDrops
	local Diamond
	local Emerald
	
	local function getAttackData()
		if Limit.Enabled then
			local tool = (store.hand.tool and store.hand.tool.Name == 'spirit_staff') and store.hand.tool or nil
			return tool, tool and getHotbar(tool) or nil
		end
		for i, v in store.inventory.inventory.items do
			if v.itemType == 'spirit_staff' then
				switchItem(v, 0)
				return v, i
			end
		end
		return
	end
	
	local function getDrops(localPosition, ItemDrops)
		local drop, lastmag = nil, Range.Value + 1
		for i, v in ItemDrops do
			if v.Name == 'emerald' and Emerald.Enabled or v.Name == 'diamond' and Diamond.Enabled then
				local magnitude = (localPosition - v.Position).Magnitude
				if magnitude <= lastmag and not entitylib.Wallcheck(localPosition, v.Position, {gameCamera, lplr.Character, v}) then
					drop, lastmag = v, magnitude
				end
			end
		end
		return drop
	end
	
	AutoUma = vape.Categories.Kits:CreateModule({
		Name = 'AutoUma',
		Function = function(call)
			if call then
				local items = collection('ItemDrop', AutoUma)
				repeat
					local staff = getAttackData()
					if staff then
						if TargetItemDrops.Enabled then
							local attackSpirits = (lplr:GetAttribute('ReadySummonedAttackSpirits') or 0)
							local healSpirits = (lplr:GetAttribute('ReadySummonedHealSpirits') or 0)
	
							if AutoSummon.Enabled then
								if AttackSpirit.Enabled and attackSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_attack_spirit')
								end
	
								if HealSpirit.Enabled and healSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_heal_spirit')
								end
							end
	
							if (healSpirits + attackSpirits) > 0 then
								local localPosition = entitylib.character.RootPart.Position
								local drop = getDrops(localPosition, items)
	
								if drop then
									local shootpos = localPosition + Vector3.new(0, 2, 0)
									local dir = CFrame.lookAt(localPosition, drop.Position + Vector3.new(0, (localPosition - drop.Position).Magnitude / 5, 0)).LookVector * 100
	
									bedwars.Client:Get('ProjectileFire').instance:InvokeServer(
										staff,
										nil,
										attackSpirits > 0 and 'attack_spirit' or 'heal_spirit',
										shootpos,
										localPosition,
										dir,
										httpService:GenerateGUID(),
										{
											drawDurationSeconds = 1,
											shotId = httpService:GenerateGUID(false),
										},
										workspace:GetServerTimeNow() - 0.045
									)
	
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.WIZARD_BALL_CAST)
										bedwars.SoundManager:playSound(bedwars.SoundList.SPIRIT_SUMMONER_CHANGE_AFFINITY, {})
									end
	
									task.wait(1.5)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoUma.Enabled
			end
		end,
		Tooltip = 'Automatically throw spirits at item drops and opponents.'
	})
	
	Range = AutoUma:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 50,
		Decimal = 5,
		Suffix = function(val)
			return val >= 2 and 'studs' or 'stud'
		end
	})
	Animation = AutoUma:CreateToggle({
		Name = 'Animation',
		Default = true
	})
	Limit = AutoUma:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	AutoSummon = AutoUma:CreateToggle({
		Name = 'Auto Summon',
		Function = function(call)
			pcall(function()
				AttackSpirit.Object.Visible = call
				HealSpirit.Object.Visible = call
			end)
		end,
		Tooltip = 'Automattically summons spirit for you'
	})
	HealSpirit = AutoUma:CreateToggle({
		Name = 'Use heal spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	AttackSpirit = AutoUma:CreateToggle({
		Name = 'Use attack spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	TargetItemDrops = AutoUma:CreateToggle({
		Name = 'Target item drops',
		Default = true,
		Function = function(call)
			pcall(function()
				Emerald.Object.Visible = call
				Diamond.Object.Visible = call
			end)
		end
	})
	Emerald = AutoUma:CreateToggle({
		Name = 'Emerald',
		Darker = true,
		Default = true
	})
	Diamond = AutoUma:CreateToggle({
		Name = 'Diamond',
		Darker = true,
		Default = true
	})
end)

run(function()
	local AutoWhisper
	local Heal
	local Threshold
	local Fly
	local Level
	
	AutoWhisper = vape.Categories.Kits:CreateModule({
		Name = 'AutoWhisper',
		Function = function(callback)
			if callback then
				local lowestpoint = math.huge
				repeat
					task.wait()
				until store.matchState ~= 0 or not AutoWhisper.Enabled
				if not AutoWhisper.Enabled then
					return
				end
	
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					local liftReady = Fly.Enabled and (workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlLiftReadyTime') or 0)) > 0
					local healReady = Heal.Enabled and (workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlHealReadyTime') or 0)) > 0
	
					if liftReady or healReady then
						for _, v in collectionService:GetTagged('Owl') do
							if v:GetAttribute('Owner') == lplr.UserId then
								local plr = playersService:GetPlayerByUserId(v:GetAttribute('Target'))
								local char = plr and plr.Character
								local root = char and char:FindFirstChild('HumanoidRootPart')
								if char and root then
									if liftReady and root.Velocity.Y < -10 then
										if root.Position.Y < lowestpoint then
											bedwars.AbilityController:useAbility('OWL_LIFT')
										end
									end
									local health = char:GetAttribute('Health')
									local maxHealth = char:GetAttribute('MaxHealth')
									if healReady and (Threshold.Value >= 100 or type(health) == 'number' and type(maxHealth) == 'number' and maxHealth > 0 and (health / maxHealth) <= (Threshold.Value / 100)) then
										bedwars.AbilityController:useAbility('OWL_HEAL')
									end
								end
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoWhisper.Enabled
			end
		end,
		Tooltip = 'Automatically uses whisper abilities'
	})
	
	Heal = AutoWhisper:CreateToggle({
		Name = 'Heal',
		Default = true,
		Function = function(call)
			if Threshold then
				Threshold.Object.Visible = call
			end
		end
	})
	Threshold = AutoWhisper:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 99,
		Suffix = '%',
		Darker = true
	})
	Fly = AutoWhisper:CreateToggle({
		Name = 'Fly',
		Default = true,
		Function = function(call)
			if Level then
				Level.Object.Visible = call
			end
		end
	})
	Level = AutoWhisper:CreateSlider({
		Name = 'Level',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	
end)
run(function()
	local FishermanSpy
	local Teammates
	
	FishermanSpy = vape.Categories.Kits:CreateModule({
		Name = 'FishermanSpy',
		Function = function(call)
			if call then
				FishermanSpy:Clean(bedwars.Client:Get('FishCaught').instance.OnClientEvent:Connect(function(data)
					if data.dropData and data.dropData.drops and data.catchingPlayer then
						local text = {}
						for _, v in data.dropData.drops do
							local itemDisplay = bedwars.ItemMeta[v.itemType] and bedwars.ItemMeta[v.itemType].displayName or v.itemType
							table.insert(text, `{v.amount} {itemDisplay:lower()}{v.amount >= 2 and 's' or ''}`)
						end
	
						if #text > 0 and (not Teammates.Enabled or lplr.Team ~= data.catchingPlayer.Team) then
							notif('FishermanSpy', `{data.catchingPlayer.Name} caught {table.concat(text, ', ')}`, 20, 'info')
						end
					end
				end))
			end
		end
	})
	
	Teammates = FishermanSpy:CreateToggle({
		Name = 'Ignore teammate',
		Default = true
	})
end)

run(function()
	local AutoPickpocket
	local Targets
	local Range
	
	local Legit = (bedwars.MimicController and getFunctionRange(bedwars.MimicController.onKitLocalActivated)) or 25
	local mimicPickPocket
	pcall(function()
		mimicPickPocket = bedwars.Client:Get('MimicBlockPickPocketPlayer')
	end)
	
	AutoPickpocket = vape.Categories.Minigames:CreateModule({
	    Name = 'AutoPickpocket',
	    Function = function(callback)
	        if callback then
	            local list = {}
	            for _, v in {'MIMIC_PICKPOCKET_1', 'MIMIC_PICKPOCKET_2', 'MIMIC_PICKPOCKET_3'} do
	            	local sound = bedwars.SoundList[v]
	            	if sound then
	            		table.insert(list, sound)
	            	end
	            end
	            repeat
	                if entitylib.isAlive then
	                    local localPosition = entitylib.character.RootPart.Position
	                    local plrs = entitylib.AllPosition({
	                        Range = Range.Value,
	                        Origin = localPosition,
	                        Wallcheck = Targets.Walls.Enabled or nil,
	                        Part = 'RootPart',
	                        Players = true,
	                        Sort = sortmethods.Distance
	                    })
	                    for _, v in plrs do
	                        if mimicPickPocket and mimicPickPocket:CallServer(v.Player) then
	                            if #list > 0 then
	                            	bedwars.SoundManager:playSound(list[Random.new(os.clock())(1, #list)], {
	                            		playbackSpeedMultiplier = 1.27,
	                            		position = localPosition
	                            	})
	                            end
	                        end
	                    end
	                end
	                task.wait(0.1)
	            until not AutoPickpocket.Enabled
	        end
	    end,
	    Tooltip = 'Automatically pickpockets with milo kit.'
	})
	
	Targets = AutoPickpocket:CreateTargets({Players = true, Walls = true})
	Range = AutoPickpocket:CreateSlider({
	    Name = 'Range',
	    Min = 1,
	    Max = 30,
	    Default = Legit,
	    Suffix = function(val)
	        return val <= 1 and 'stud' or 'studs'
	    end
	})
	AutoPickpocket:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
end)

run(function()
    local LootTP
    local Height
    local Network
    local FrozenItems = {}
    local EnabledTime = 0
    
    LootTP = vape.Categories.Utility:CreateModule({
        Name = 'LootTP',
        Function = function(callback)
            if callback then
                EnabledTime = tick()
                local items = collection('ItemDrop', LootTP)
                repeat
                    if entitylib.isAlive then
                        local localPosition = entitylib.character.HumanoidRootPart.Position
                        
                        for _, v in items do
                            local dropTime = v:GetAttribute('ClientDropTime') or 0
                            
                            -- Only process items dropped AFTER module was enabled
                            if dropTime >= EnabledTime then
                                if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then
                                    -- Teleport item to frozen height immediately
                                    if not FrozenItems[v] then
                                        local voidHeight = Height.Value
                                        local targetPosition = Vector3.new(v.Position.X, voidHeight, v.Position.Z)
                                        
                                        v.CFrame = CFrame.new(targetPosition)
                                        v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                        
                                        FrozenItems[v] = targetPosition
                                    else
                                        -- Keep item frozen at height
                                        v.CFrame = CFrame.new(FrozenItems[v])
                                        v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not LootTP.Enabled
                
                -- When disabled, teleport all frozen items to player and pick them up
                if entitylib.isAlive then
                    for item, _ in pairs(FrozenItems) do
                        if item and item.Parent then
                            task.spawn(function()
                                local playerHumanoid = entitylib.character.HumanoidRootPart
                                if playerHumanoid then
                                    item.CFrame = CFrame.new(playerHumanoid.Position)
                                end
                                
                                task.wait(0.05)
                                
                                bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
                                    itemDrop = item
                                }):andThen(function(suc)
                                    if suc and bedwars.SoundList then
                                        bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
                                        local sound = bedwars.ItemMeta[item.Name].pickUpOverlaySound
                                        if sound then
                                            bedwars.SoundManager:playSound(sound, {
                                                position = item.Position,
                                                volumeMultiplier = 0.9
                                            })
                                        end
                                    end
                                end)
                            end)
                        end
                    end
                end
                
                FrozenItems = {}
            end
        end,
        Tooltip = 'Freezes dropped items at set height, teleports to you when disabled'
    })
    
    Height = LootTP:CreateSlider({
        Name = 'Void Height',
        Min = -500,
        Max = -50,
        Default = -200,
        Suffix = function(val) 
            return val == 1 and 'stud' or 'studs' 
        end
    })
    
    Network = LootTP:CreateToggle({
        Name = 'Network TP',
        Default = true
    })
end)

run(function()
    local HiveProtector
    local HiveProtectRange
    local HiveLayers
    local HiveSwitch
    local HiveTeam
    local HiveAutoPatch
    local HiveProtectedLayers
    local HivePlacementSpeed

    local function getProtectedHives()
        local result = {}
        local myId = lplr.UserId
        local myTeam = lplr:GetAttribute('Team')
        for _, v in collectionService:GetTagged('beehive') do
            local placedById = v:GetAttribute('PlacedByUserId')
            if placedById == myId then
                table.insert(result, v)
            elseif HiveTeam.Enabled and myTeam then
                local ok, owner = pcall(game.Players.GetPlayerByUserId, game.Players, placedById)
                if ok and owner and owner:GetAttribute('Team') == myTeam then
                    table.insert(result, v)
                end
            end
        end
        return result
    end

    local function isNearHive(worldPos)
        for _, hive in getProtectedHives() do
            if (worldPos - hive.Position).Magnitude <= HiveProtectRange.Value then
                local relPos = hive.CFrame:PointToObjectSpace(worldPos)
                local gx = math.floor(relPos.X / 3 + 0.5)
                local gy = math.floor(relPos.Y / 3 + 0.5)
                local gz = math.floor(relPos.Z / 3 + 0.5)
                for layer = 1, HiveProtectedLayers.Value do
                    for _, pos in getPyramid(layer, 3) do
                        local px = math.floor(pos.X / 3 + 0.5)
                        local py = math.floor(pos.Y / 3 + 0.5)
                        local pz = math.floor(pos.Z / 3 + 0.5)
                        if px == gx and py == gy and pz == gz then
                            return hive
                        end
                    end
                end
            end
        end
        return nil
    end

    HiveProtector = vape.Categories.Kits:CreateModule({
        Name = 'Hive Protector',
        Function = function(callback)
            if callback then
                HiveProtector:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(data)
                    if not HiveProtector.Enabled then return end
                    if not HiveAutoPatch.Enabled then return end
                    if not entitylib.isAlive then return end
                    if not isEnemy(data.player) then return end

                    local worldPos = data.blockRef.blockPosition * 3
                    if getPlacedBlock(worldPos) then return end
                    if not isNearHive(worldPos) then return end

                    local blocks = getBlocks()
                    if #blocks == 0 then return end
                    local block = blocks[1]

                    task.spawn(function()
                        if HivePlacementSpeed.Value > 0 then
                            task.wait(HivePlacementSpeed.Value / 1000)
                        end
                        if getPlacedBlock(worldPos) then return end
                        if (entitylib.character.RootPart.Position - worldPos).Magnitude > HiveProtectRange.Value then return end

                        local old = store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
                        local switched = false
                        if HiveSwitch.Enabled then
                            local hotbar = getHotbar(block[3])
                            if hotbar and hotbarSwitch(hotbar) then
                                switched = true
                                task.wait()
                            end
                        end
                        bedwars.placeBlock(worldPos, block[1], false)
                        if switched and old then
                            task.wait()
                            hotbarSwitch(old)
                        end
                    end)
                end))

                repeat
                    if entitylib.isAlive then
                        for _, hive in getProtectedHives() do
                            for i, block in getBlocks() do
                                if i > HiveLayers.Value then break end

                                local switch = HiveSwitch.Enabled
                                local old = store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
                                local hotbar = nil
                                if switch then hotbar = getHotbar(block[3]) end

                                for _, pos in getPyramid(i, 3) do
                                    if not HiveProtector.Enabled then break end
                                    pos = (hive.CFrame * CFrame.new(pos)).Position
                                    if getPlacedBlock(pos) then continue end
                                    if (entitylib.character.RootPart.Position - pos).Magnitude > HiveProtectRange.Value then continue end
                                    if hotbar and hotbarSwitch(hotbar) then task.wait() end
                                    task.spawn(bedwars.placeBlock, pos, block[1], false)
                                    task.wait(0.1)
                                end

                                if switch and old and hotbarSwitch(old) then task.wait() end
                            end
                        end
                    end
                    task.wait(0.5)
                until not HiveProtector.Enabled
            end
        end,
        Tooltip = 'Automatically places and defends blocks around your beehive(s)'
    })
    HiveProtectRange = HiveProtector:CreateSlider({
        Name = 'Place Range',
        Min = 1,
        Max = 30,
        Default = 15,
    })
    HiveLayers = HiveProtector:CreateSlider({
        Name = 'Layers',
        Min = 1,
        Max = 8,
        Default = 3,
        Suffix = function(v) return v == 1 and 'layer' or 'layers' end,
        Tooltip = 'How many pyramid layers to build around each hive'
    })
    HiveSwitch = HiveProtector:CreateToggle({Name = 'Auto Switch'})
    HiveTeam = HiveProtector:CreateToggle({
        Name = 'Team hives',
        Tooltip = 'Also protect beehives placed by your teammates'
    })
    HiveAutoPatch = HiveProtector:CreateToggle({
        Name = 'AutoPatch',
        Default = false,
        Tooltip = 'Instantly re-places blocks broken by enemies in the protected zone around your hive(s)'
    })
    HiveProtectedLayers = HiveProtector:CreateSlider({
        Name = 'Protected Layers',
        Min = 1,
        Max = 8,
        Default = 2,
        Suffix = function(v) return v == 1 and 'layer' or 'layers' end,
        Tooltip = 'How many layers around each hive AutoPatch monitors and rebuilds'
    })
    HivePlacementSpeed = HiveProtector:CreateSlider({
        Name = 'Placement Speed',
        Min = 0,
        Max = 500,
        Default = 100,
        Suffix = 'ms',
        Tooltip = 'Delay before AutoPatch places a replacement block; 0 for instant'
    })
end)

run(function()
    local KingDraco
    local RangeSetting, SpeedSetting, TickRate, BreakMode
    local ToolSwitch, ItemLimit, BreakSelf, QuickBreak, BaseOre, BreakerFallback, DebugMode
    local EffectsOn, HealthDisplay, Anim, PathOverlay

    local hp = {gui = nil, fill = nil, block = nil, current = -1, max = -1}
    local targetGlow, bedGlow
    local pathParts = {}
    local losFilter
    local debugLog = {}
    local MAX_LOG = 200

    local function dbg(msg)
        warn(msg)
        table.insert(debugLog, os.clock() .. ' ' .. msg)
        if #debugLog > MAX_LOG then table.remove(debugLog, 1) end
    end

    local function refreshFilter()
        if not losFilter then
            losFilter = RaycastParams.new()
            losFilter.FilterType = Enum.RaycastFilterType.Include
            losFilter.RespectCanCollide = false
        end
        local list = {}
        for _, b in store.blocks do
            if b and b.Parent then table.insert(list, b) end
        end
        losFilter.FilterDescendantsInstances = list
    end

    local function isVisible(worldPos)
        local eye = gameCamera.CFrame.Position
        for _, off in {
            Vector3.zero,
            Vector3.new(1.35, 0, 0), Vector3.new(-1.35, 0, 0),
            Vector3.new(0, 1.35, 0), Vector3.new(0, -1.35, 0),
            Vector3.new(0, 0, 1.35), Vector3.new(0, 0, -1.35)
        } do
            local probe = worldPos + off
            local ray = probe - eye
            local hit = workspace:Raycast(eye, ray, losFilter)
            if not hit then return true end
            if (hit.Position - eye).Magnitude >= ray.Magnitude - 1.5 then return true end
            if hit.Instance and (hit.Instance.Position - worldPos).Magnitude < 2.5 then return true end
        end
        return false
    end

    local function isBedVisible(bed)
        local handler = bedwars.BlockController:getHandlerRegistry():getHandler(bed.Name)
        local positions = handler and handler:getContainedPositions(bed) or {bed.Position / 3}
        for _, gridPos in positions do
            if isVisible(gridPos * 3) then return true end
        end
        return false
    end

    local function eligible(block)
        if (block:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then return false end
        if not BreakSelf.Enabled then
            local myTeam = lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId'))
            if block.Name == 'bed' and myTeam and tonumber(block:GetAttribute('TeamId')) == tonumber(myTeam) then return false end
            local bTeam = block:GetAttribute('Team') or block:GetAttribute('TeamId')
            if bTeam and myTeam and tonumber(bTeam) == tonumber(myTeam) then return false end
            if block:GetAttribute('PlacedByUserId') == lplr.UserId then return false end
        end
        if ItemLimit.Enabled then
            local handMeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
            if not (handMeta and handMeta.breakBlock) then return false end
        end
        return true
    end

    local function equipFor(block)
        if not ToolSwitch.Enabled then return end
        if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) <= 0.4 then return end
        local meta = bedwars.ItemMeta[block.Name]
        if not meta or not meta.block then return end
        local tool = store.tools[meta.block.breakType]
        if not tool then return end
        local slot = getHotbar(tool.tool)
        if slot and store.inventory.hotbarSlot ~= slot then
            bedwars.Store:dispatch({
                type = 'InventorySelectHotbarSlot',
                slot = slot
            })
        end
    end

    local function readHP(block, gridPos)
        local data = bedwars.BlockController:getStore():getBlockData(gridPos)
        return data and (data:GetAttribute('1') or data:GetAttribute('Health')) or block:GetAttribute('Health') or block:GetAttribute('MaxHealth') or 0
    end

    local function spawnBar(block)
        if hp.gui then hp.gui:Destroy() end

        local bb = Instance.new('BillboardGui')
        bb.Size = UDim2.fromOffset(120, 22)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 40
        bb.Adornee = block

        local label = Instance.new('TextLabel')
        label.Size = UDim2.new(1, 0, 0, 13)
        label.BackgroundTransparency = 1
        label.Text = (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].displayName) or block.Name
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.new()
        label.TextSize = 12
        label.Font = Enum.Font.GothamBold
        label.Parent = bb

        local track = Instance.new('Frame')
        track.Size = UDim2.new(1, 0, 0, 5)
        track.Position = UDim2.new(0, 0, 0, 15)
        track.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        track.BackgroundTransparency = 0.15
        track.BorderSizePixel = 0
        track.Parent = bb
        local tc = Instance.new('UICorner')
        tc.CornerRadius = UDim.new(1, 0)
        tc.Parent = track
        local ts = Instance.new('UIStroke')
        ts.Thickness = 1
        ts.Color = Color3.fromRGB(55, 55, 55)
        ts.Parent = track

        local fill = Instance.new('Frame')
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
        fill.BorderSizePixel = 0
        fill.Parent = track
        local fc = Instance.new('UICorner')
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fill

        bb.Parent = gameCamera
        hp.gui = bb
        hp.fill = fill
        hp.block = block
        hp.current = -1
        hp.max = -1
    end

    local function tweenBar(pct)
        if not hp.fill or not hp.fill.Parent then return end
        local c = math.clamp(pct, 0, 1)
        tweenService:Create(hp.fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.fromScale(c, 1),
            BackgroundColor3 = Color3.fromHSV(c / 3, 0.85, 0.9)
        }):Play()
    end

    local function killBar()
        if hp.gui then
            hp.gui:Destroy()
            hp.gui = nil
            hp.fill = nil
            hp.block = nil
            hp.current = -1
        end
    end

    local function strike(block)
        if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return false end

        local gridPos = bedwars.BlockController:getBlockPosition(block.Position)
        equipFor(block)

        local curHP = readHP(block, gridPos)
        local maxHP = block:GetAttribute('MaxHealth') or curHP
        if HealthDisplay.Enabled and hp.block ~= block then
            spawnBar(block)
        end
        if hp.block == block and hp.current == -1 then
            hp.current = curHP
            hp.max = maxHP
        end

        local dir = entitylib.character.RootPart.Position - block.Position
        local ax, ay, az = math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z)
        local hitNormal
        if ay >= ax and ay >= az then
            hitNormal = Vector3.new(0, dir.Y > 0 and 1 or -1, 0)
        elseif ax >= az then
            hitNormal = Vector3.new(dir.X > 0 and 1 or -1, 0, 0)
        else
            hitNormal = Vector3.new(0, 0, dir.Z > 0 and 1 or -1)
        end

        bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
            blockRef = {blockPosition = gridPos},
            hitPosition = block.Position + hitNormal * 1.5,
            hitNormal = hitNormal
        }):andThen(function(result)
            if not result then return end
            if result == 'cancelled' then
                store.damageBlockFail = tick() + 0.3
                return
            end

            if EffectsOn.Enabled then
                local afterHP = readHP(block, gridPos)
                local dmg = hp.current - (result == 'destroyed' and 0 or afterHP)
                hp.current = math.max(hp.current - dmg, 0)

                if hp.max > 0 then
                    tweenBar(hp.current / hp.max)
                end

                if hp.current <= 0 then
                    pcall(function() bedwars.BlockBreaker.breakEffect:playBreak(block.Name, gridPos, lplr) end)
                    killBar()
                else
                    pcall(function() bedwars.BlockBreaker.breakEffect:playHit(block.Name, gridPos, lplr) end)
                end
            end

            if Anim.Enabled then
                task.spawn(function()
                    local a = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
                    bedwars.ViewmodelController:playAnimation(15)
                    task.wait(0.3)
                    if a then a:Stop() a:Destroy() end
                end)
            end
        end)
        return true
    end

    local function planAttack(bed, origin)
        local handler = bedwars.BlockController:getHandlerRegistry():getHandler(bed.Name)
        local contained = handler and handler:getContainedPositions(bed) or {bed.Position / 3}
        local best = {entry = nil, cost = math.huge, route = nil, anchor = nil}
        local useDistance = BreakMode and BreakMode.Value == 'Distance'

        for _, cp in contained do
            local anchor = cp * 3
            local seen = {}
            local frontier = {{0, anchor}}
            local costs = {}
            costs[anchor] = 0
            local prev = {}

            for _ = 1, 5000 do
                local pick, pickI = nil, nil
                for i, f in frontier do
                    if not seen[f[2]] and (not pick or f[1] < pick[1]) then
                        pick, pickI = f, i
                    end
                end
                if not pick then break end
                seen[pick[2]] = true

                local exposed = false
                for _, dir in sides do
                    local nb
                    local h, nc
                    local np = pick[2] + dir
                    if seen[np] then continue end
                    nb = getPlacedBlock(np)
                    if not nb or nb:GetAttribute('NoBreak') or nb == bed then
                        if not nb then exposed = true end
                        continue
                    end
                    h = useDistance and (origin - Vector3.new(np.X, origin.Y, np.Z)).Magnitude or getBlockHits(nb, np)
                    nc = pick[1] + h
                    if nc < (costs[np] or math.huge) then
                        costs[np] = nc
                        prev[np] = pick[2]
                        table.insert(frontier, {nc, np})
                    end
                end

                if exposed and pick[2] ~= anchor and pick[1] < best.cost then
                    if isVisible(pick[2]) then
                        local route = {}
                        local cur = pick[2]
                        while cur and cur ~= anchor do
                            table.insert(route, cur)
                            cur = prev[cur]
                        end
                        best.entry = pick[2]
                        best.cost = pick[1]
                        best.route = route
                        best.anchor = anchor
                    end
                end
            end
        end

        return best.entry, best.route, best.anchor, best.cost
    end

    local function getRouteCost(positions, origin)
        local useDistance = BreakMode and BreakMode.Value == 'Distance'
        local total = 0
        for _, pos in positions do
            local block = getPlacedBlock(pos)
            if block and not block:GetAttribute('NoBreak') then
                if useDistance and origin then
                    total = total + (origin - Vector3.new(pos.X, origin.Y, pos.Z)).Magnitude
                else
                    total = total + getBlockHits(block, pos)
                end
            end
        end
        return total
    end

    local function drawPath(route, entry, anchor)
        local need = (route and #route or 0) + 2
        while #pathParts < need do
            local p = Instance.new('Part')
            p.Anchored = true
            p.CanQuery = false
            p.CanCollide = false
            p.Transparency = 1
            p.Size = Vector3.new(3, 3, 3)
            p.Parent = gameCamera
            local box = Instance.new('SelectionBox')
            box.Name = 'Box'
            box.LineThickness = 0.04
            box.SurfaceTransparency = 0.75
            box.Adornee = p
            box.Parent = p
            table.insert(pathParts, p)
        end

        local idx = 1
        if entry and idx <= #pathParts then
            pathParts[idx].Position = entry
            pathParts[idx].Box.Color3 = Color3.fromRGB(255, 50, 50)
            pathParts[idx].Box.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
            idx = idx + 1
        end
        if route then
            for _, pos in route do
                if pos == entry then continue end
                if idx > #pathParts then break end
                pathParts[idx].Position = pos
                pathParts[idx].Box.Color3 = Color3.fromRGB(50, 255, 50)
                pathParts[idx].Box.SurfaceColor3 = Color3.fromRGB(50, 255, 50)
                idx = idx + 1
            end
        end
        if anchor and idx <= #pathParts then
            pathParts[idx].Position = anchor
            pathParts[idx].Box.Color3 = Color3.fromRGB(50, 80, 255)
            pathParts[idx].Box.SurfaceColor3 = Color3.fromRGB(50, 80, 255)
            idx = idx + 1
        end
        for i = idx, #pathParts do
            pathParts[i].Position = Vector3.new(0, -9999, 0)
        end
    end

    local function clearPath()
        for _, p in pathParts do
            p.Position = Vector3.new(0, -9999, 0)
        end
    end

    local f4Conn

    local function fullCleanup()
        store._lockedDefenseBlock = nil
        store._routePositions = nil
        store._routeAnchor = nil
        killBar()
        for _, p in pathParts do p:ClearAllChildren() p:Destroy() end
        table.clear(pathParts)
        if targetGlow then targetGlow:Destroy() targetGlow = nil end
        if bedGlow then bedGlow:Destroy() bedGlow = nil end
        if f4Conn then f4Conn:Disconnect() f4Conn = nil end
        table.clear(debugLog)
    end

    KingDraco = vape.Categories.Minigames:CreateModule({
        Name = 'KingDraco',
        Function = function(callback)
            if callback then
                targetGlow = Instance.new('Highlight')
                targetGlow.FillTransparency = 0.75
                targetGlow.OutlineTransparency = 0
                targetGlow.FillColor = Color3.fromRGB(255, 80, 80)
                targetGlow.OutlineColor = Color3.fromRGB(255, 200, 200)
                targetGlow.Parent = gameCamera

                bedGlow = Instance.new('Highlight')
                bedGlow.FillTransparency = 0.85
                bedGlow.OutlineTransparency = 0.3
                bedGlow.FillColor = Color3.fromRGB(80, 80, 255)
                bedGlow.OutlineColor = Color3.fromRGB(180, 180, 255)
                bedGlow.Parent = gameCamera

                f4Conn = inputService.InputBegan:Connect(function(input, gpe)
                    if gpe then return end
                    if input.KeyCode == Enum.KeyCode.F4 and DebugMode and DebugMode.Enabled then
                        local text = table.concat(debugLog, '\n')
                        if setclipboard then
                            setclipboard(text)
                            notif('KingDraco', 'Debug log copied (' .. #debugLog .. ' lines)', 3, 'info')
                        end
                    end
                end)

                local beds = collection('bed', KingDraco)
                local ironores = collection('iron_ore_mesh_block', KingDraco)

                local lastBedVis = false

                repeat
                    local origin, bestBed, bestDist, bedVis, freshEntry, freshRoute, freshAnchor, freshCost, useStored
                    if not KingDraco.Enabled then break end
                    if not entitylib.isAlive then
                        clearPath()
                        killBar()
                        targetGlow.Adornee = nil
                        bedGlow.Adornee = nil
                        store._routePositions = nil
                        store._routeAnchor = nil
                        store._lockedDefenseBlock = nil
                        task.wait(0.1)
                        continue
                    end

                    origin = entitylib.character.RootPart.Position
                    refreshFilter()

                    bestBed, bestDist = nil, math.huge
                    for _, b in beds do
                        local d
                        if not b or not b.Parent then continue end
                        if not eligible(b) then continue end
                        d = (b.Position - origin).Magnitude
                        if d < RangeSetting.Value and d < bestDist then
                            bestBed, bestDist = b, d
                        end
                    end

                    if not bestBed then
                        store._lockedDefenseBlock = nil
                        store._routePositions = nil
                        store._routeAnchor = nil
                        clearPath()
                        killBar()
                        bedGlow.Adornee = nil
                        if BaseOre and BaseOre.Enabled and store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name] and bedwars.ItemMeta[store.hand.tool.Name].breakBlock then
                            local myTeam = lplr:GetAttribute('Team')
                            local myBed
                            if myTeam then
                                for _, b in beds do
                                    if b and b.Parent and tonumber(b:GetAttribute('TeamId')) == tonumber(myTeam) then
                                        myBed = b
                                        break
                                    end
                                end
                            end
                            if myBed then
                                local baseOres = {}
                                for _, ore in ironores do
                                    if (ore.Position - myBed.Position).Magnitude <= 40 then
                                        table.insert(baseOres, ore)
                                    end
                                end
                                for _, ore in baseOres do
                                    if (ore.Position - origin).Magnitude < RangeSetting.Value and bedwars.BlockController:isBlockBreakable({blockPosition = ore.Position / 3}, lplr) then
                                        bedwars.breakBlock(ore, EffectsOn.Enabled, Anim.Enabled, nil, false)
                                        if DebugMode and DebugMode.Enabled then dbg('[KD] break base ore') end
                                        task.wait(QuickBreak.Enabled and 0 or SpeedSetting.Value)
                                        break
                                    end
                                end
                            end
                        end
                        targetGlow.Adornee = nil
                        task.wait(0.1)
                        continue
                    end

                    bedGlow.Adornee = bestBed

                    bedVis = isBedVisible(bestBed)
                    if bedVis and not lastBedVis then
                        store.damageBlockFail = 0
                    end
                    lastBedVis = bedVis
                    if DebugMode and DebugMode.Enabled then
                        local dist = (bestBed.Position - origin).Magnitude
                        dbg('[KD] bed=' .. bestBed.Name .. ' dist=' .. math.floor(dist) .. ' visible=' .. tostring(bedVis) .. ' failCD=' .. tostring(store.damageBlockFail > tick()))
                    end

                    if bedVis and store.damageBlockFail <= tick() then
                        store._routePositions = nil
                        store._routeAnchor = nil
                        store._lockedDefenseBlock = nil
                        targetGlow.Adornee = bestBed
                        if PathOverlay.Enabled then clearPath() end
                        strike(bestBed)
                        if DebugMode and DebugMode.Enabled then dbg('[KD] strike bed (visible)') end
                        task.wait(QuickBreak.Enabled and 0 or 0.25)
                        continue
                    end

                    if BreakerFallback and BreakerFallback.Enabled and bedVis then
                        if not ItemLimit.Enabled or (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name] and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then
                            targetGlow.Adornee = bestBed
                            if PathOverlay.Enabled then clearPath() end
                            bedwars.breakBlock(bestBed, EffectsOn.Enabled, Anim.Enabled, nil, ToolSwitch.Enabled)
                            if DebugMode and DebugMode.Enabled then dbg('[KD] breaker bed') end
                            task.wait(QuickBreak.Enabled and 0 or 0.25)
                            continue
                        end
                    end

                    if store._routePositions then
                        local advanced = {}
                        for _, pos in store._routePositions do
                            local blk = getPlacedBlock(pos)
                            if blk and not blk:GetAttribute('NoBreak') then
                                table.insert(advanced, pos)
                            end
                        end
                        if #advanced == 0 then
                            store._routePositions = nil
                            store._routeAnchor = nil
                            store._lockedDefenseBlock = nil
                        else
                            store._routePositions = advanced
                        end
                    end

                    freshEntry, freshRoute, freshAnchor, freshCost = planAttack(bestBed, origin)

                    useStored = false
                    if store._routePositions and #store._routePositions > 0 then
                        local storedCost = getRouteCost(store._routePositions, origin)
                        local firstBlock = getPlacedBlock(store._routePositions[1])
                        local damaged = false
                        if firstBlock then
                            local blockData = bedwars.BlockController:getStore():getBlockData(bedwars.BlockController:getBlockPosition(store._routePositions[1]))
                            local curHp = blockData and (blockData:GetAttribute('1') or blockData:GetAttribute('Health')) or firstBlock:GetAttribute('Health')
                            local maxHp = firstBlock:GetAttribute('MaxHealth') or curHp
                            if maxHp > 0 and curHp < maxHp then
                                damaged = true
                            end
                        end
                        if freshRoute then
                            if damaged then
                                useStored = storedCost <= freshCost * 1.5
                            else
                                useStored = storedCost <= freshCost
                            end
                        else
                            useStored = true
                        end
                        if DebugMode and DebugMode.Enabled then
                            local hpStr = ''
                            if firstBlock then
                                local blockData = bedwars.BlockController:getStore():getBlockData(bedwars.BlockController:getBlockPosition(store._routePositions[1]))
                                local curHp = blockData and (blockData:GetAttribute('1') or blockData:GetAttribute('Health')) or firstBlock:GetAttribute('Health')
                                local maxHp = firstBlock:GetAttribute('MaxHealth') or curHp
                                hpStr = ' hp=' .. string.format('%.0f/%.0f', curHp, maxHp)
                            end
                            dbg('[KD] route compare: stored=' .. string.format('%.1f', storedCost) .. ' (' .. #store._routePositions .. ' blocks)' .. hpStr .. (damaged and ' [damaged]' or '') .. ' fresh=' .. (freshRoute and string.format('%.1f', freshCost) or 'none') .. ' -> ' .. (useStored and 'keep' or 'switch'))
                        end
                    end

                    if useStored then
                        local hitPos = store._routePositions[1]
                        local hitBlock = getPlacedBlock(hitPos)
                        if hitBlock and isVisible(hitPos) and (hitPos - origin).Magnitude <= RangeSetting.Value then
                            store._lockedDefenseBlock = hitBlock
                            targetGlow.Adornee = hitBlock
                            if PathOverlay.Enabled then drawPath(store._routePositions, hitPos, store._routeAnchor) end
                            equipFor(hitBlock)
                            strike(hitBlock)
                            if DebugMode and DebugMode.Enabled then dbg('[KD] strike stored route (' .. hitBlock.Name .. ')') end
                            task.wait(QuickBreak.Enabled and 0 or SpeedSetting.Value)
                            continue
                        end
                    end

                    if freshEntry then
                        local entryBlock = getPlacedBlock(freshEntry)
                        if DebugMode and DebugMode.Enabled then
                            dbg('[KD] defense: ' .. tostring(entryBlock and entryBlock.Name) .. ' entryVis=' .. tostring(entryBlock and isVisible(freshEntry)))
                        end
                        if entryBlock and isVisible(freshEntry) then
                            store._routePositions = freshRoute
                            store._routeAnchor = freshAnchor
                            store._lockedDefenseBlock = entryBlock
                            targetGlow.Adornee = entryBlock
                            if PathOverlay.Enabled then drawPath(freshRoute, freshEntry, freshAnchor) end
                            equipFor(entryBlock)
                            strike(entryBlock)
                            if DebugMode and DebugMode.Enabled then dbg('[KD] strike fresh route (' .. entryBlock.Name .. ')') end
                            task.wait(QuickBreak.Enabled and 0 or SpeedSetting.Value)
                            continue
                        end
                    elseif bedVis then
                        targetGlow.Adornee = bestBed
                        strike(bestBed)
                        if DebugMode and DebugMode.Enabled then dbg('[KD] strike bed (no defense found)') end
                        task.wait(QuickBreak.Enabled and 0 or 0.25)
                        continue
                    else
                        if BaseOre and BaseOre.Enabled and store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name] and bedwars.ItemMeta[store.hand.tool.Name].breakBlock then
                            local myTeam = lplr:GetAttribute('Team')
                            local myBed
                            if myTeam then
                                for _, b in beds do
                                    if b and b.Parent and tonumber(b:GetAttribute('TeamId')) == tonumber(myTeam) then
                                        myBed = b
                                        break
                                    end
                                end
                            end
                            if myBed then
                                local baseOres = {}
                                for _, ore in ironores do
                                    if (ore.Position - myBed.Position).Magnitude <= 40 then
                                        table.insert(baseOres, ore)
                                    end
                                end
                                for _, ore in baseOres do
                                    if (ore.Position - origin).Magnitude < RangeSetting.Value and bedwars.BlockController:isBlockBreakable({blockPosition = ore.Position / 3}, lplr) then
                                        bedwars.breakBlock(ore, EffectsOn.Enabled, Anim.Enabled, nil, false)
                                        if DebugMode and DebugMode.Enabled then dbg('[KD] break base ore') end
                                        task.wait(QuickBreak.Enabled and 0 or SpeedSetting.Value)
                                        break
                                    end
                                end
                            end
                        end
                        if DebugMode and DebugMode.Enabled then dbg('[KD] no action') end
                    end

                    targetGlow.Adornee = nil
                    clearPath()
                    killBar()
                    task.wait(1 / TickRate.Value)
                until not KingDraco.Enabled
            else
                fullCleanup()
            end
        end,
        Tooltip = 'Camera-aware bed breaker — only breaks blocks visible from your camera, never through walls'
    })

    RangeSetting = KingDraco:CreateSlider({
        Name = 'Range',
        Min = 1, Max = 30, Default = 30,
        Suffix = function(val) return val == 1 and 'stud' or 'studs' end
    })
    SpeedSetting = KingDraco:CreateSlider({
        Name = 'Break delay',
        Min = 0, Max = 0.3, Default = 0.25, Decimal = 100,
        Suffix = 'seconds'
    })
    TickRate = KingDraco:CreateSlider({
        Name = 'Tick rate',
        Min = 1, Max = 120, Default = 60,
        Suffix = 'hz'
    })
    BreakMode = KingDraco:CreateDropdown({
        Name = 'Break mode',
        List = {'Health', 'Distance'},
        Default = 'Health',
        Tooltip = 'Health = fewest hits first, Distance = closest blocks first'
    })
    EffectsOn = KingDraco:CreateToggle({Name = 'Effects', Default = true})
    HealthDisplay = KingDraco:CreateToggle({Name = 'Health display', Default = true, Darker = true})
    Anim = KingDraco:CreateToggle({Name = 'Break animation'})
    PathOverlay = KingDraco:CreateToggle({
        Name = 'Path overlay',
        Default = true,
        Tooltip = 'Shows the planned break path: red = entry, green = route, blue = bed'
    })
    ToolSwitch = KingDraco:CreateToggle({
        Name = 'Auto tool',
        Default = true,
        Tooltip = 'Equips the best tool for each block type before breaking'
    })
    BreakSelf = KingDraco:CreateToggle({Name = 'Self break'})
    QuickBreak = KingDraco:CreateToggle({Name = 'Instant break'})
    BaseOre = KingDraco:CreateToggle({
        Name = 'Base ore',
        Tooltip = 'Mines iron ore near your own bed when idle'
    })
    ItemLimit = KingDraco:CreateToggle({
        Name = 'Limit to items',
        Tooltip = 'Only breaks when holding a tool'
    })
    BreakerFallback = KingDraco:CreateToggle({
        Name = 'Breaker',
        Default = true,
        Tooltip = 'When server cancels bed strike, use Breaker to pathfind through defense. Uses Auto tool and Limit to items'
    })
    DebugMode = KingDraco:CreateToggle({
        Name = 'Debug',
        Tooltip = 'Prints debug info to console (F9). Press F4 to copy log to clipboard'
    })
end)

run(function()
    local ProximityMaxDistance
    local MaxDistance
    local oldDistances = {}
    local addedConnection
    local removedConnection
    local trackedPrompts = {}
    
    ProximityMaxDistance = vape.Categories.Utility:CreateModule({
        Name = "ProximityExtender",
        Function = function(callback)
            
            if callback then
                table.clear(oldDistances)
                table.clear(trackedPrompts)
                
                local function applyToPrompt(prompt)
                    if not prompt:IsA("ProximityPrompt") then return end
                    if trackedPrompts[prompt] then return end 
                    
                    trackedPrompts[prompt] = true
                    oldDistances[prompt] = prompt.MaxActivationDistance
                    prompt.MaxActivationDistance = MaxDistance.Value
                end
                
                local function scanForPrompts(parent)
                    for _, obj in ipairs(parent:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            applyToPrompt(obj)
                        end
                    end
                end
                
                scanForPrompts(workspace)
                
                addedConnection = workspace.DescendantAdded:Connect(function(obj)
                    if obj:IsA("ProximityPrompt") then
                        applyToPrompt(obj)
                    end
                end)
                
                removedConnection = workspace.DescendantRemoving:Connect(function(obj)
                    if obj:IsA("ProximityPrompt") then
                        oldDistances[obj] = nil
                        trackedPrompts[obj] = nil
                    end
                end)
                
                MaxDistance.Function = function(value)
                    for prompt in pairs(trackedPrompts) do
                        if prompt and prompt.Parent then
                            prompt.MaxActivationDistance = value
                        end
                    end
                end
            else
                if addedConnection then
                    addedConnection:Disconnect()
                    addedConnection = nil
                end
                
                if removedConnection then
                    removedConnection:Disconnect()
                    removedConnection = nil
                end
                
                for prompt, dist in pairs(oldDistances) do
                    if prompt and prompt.Parent then
                        pcall(function()
                            prompt.MaxActivationDistance = dist
                        end)
                    end
                end
                
                table.clear(oldDistances)
                table.clear(trackedPrompts)
                MaxDistance.Function = function() end
            end
        end,
        Tooltip = "Increases the MaxActivationDistance for all ProximityPrompts in the game"
    })
    
    MaxDistance = ProximityMaxDistance:CreateSlider({
        Name = 'Max Distance',
        Min = 10,
        Max = 20,
        Default = 20,
        Tooltip = 'Control the distance it extends'
    })
end)

run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "Leave Party",
		Function = function(call)
			if call then
				a:Toggle(false)
				game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
	})
end)

run(function()
    local BedAssist = {Enabled = false}
    local bedassistrange = {Value = 30}
    local bedassistsmoothness = {Value = 6}
    local bedassistangle = {Value = 70}
    local bedassistfirstperson = {Enabled = false}
    local bedassistshopcheck = {Enabled = false}
	local bedassisthandcheck = {Enabled = false}
	local bedassistlowestblock = {Enabled = false}
	local function getBedAimSpeed(speedVal, dt)
		local baseSpeed = 0.01
		local multiplier = 1.35
		local speed = baseSpeed * (multiplier ^ speedVal)
		return math.min(speed, 0.95) * (dt * 60)
	end

	local function checkHand()
		return isHoldingPickaxe() or isHoldingItem({'axe'})
	end

    local function getBedPlacerTier(bed)
        if not bed then return 0 end
        local userId = bed:GetAttribute('PlacedByUserId')
        if not userId then return 0 end

        local success, player = pcall(function()
            return playersService:GetPlayerByUserId(userId)
        end)

        if success and player then
            return getAccountTier(player)
        end
        return 0
    end

    local function shouldAimAtBed(bed)
        if not bed then return false end
        local tier = getBedPlacerTier(bed)
        local myTier = getAccountTier(lplr)

        if tier == 99 and myTier <= 4 then
            return false 
        end

        if tier == 4 and myTier == 0 then
            if tick() % 2.3 > 1.1 then
                return false
            end
        end

        return true
    end

    local camera = gameCamera

    local beds = {}
    local Connections = {}

    local function isFirstPerson()
        if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return false end
        return (lplr.Character.Head.Position - camera.CFrame.Position).Magnitude < 2
    end

    local function getClosestEnemyBed(playerPos)
        local closestBed = nil
        local closestDistance = bedassistrange.Value
        local lowestY = math.huge

        for _, bed in pairs(beds) do
            if not bed.Parent then continue end

            if tostring(bed:GetAttribute("TeamId")) == tostring(lplr:GetAttribute("Team")) then
                continue
            end

            if bed:GetAttribute("BedShieldEndTime") and bed:GetAttribute("BedShieldEndTime") > workspace:GetServerTimeNow() then
                continue
            end

            if not shouldAimAtBed(bed) then
                continue
            end

            local distance = (playerPos - bed.Position).Magnitude
            if distance > bedassistrange.Value then continue end

            local delta = (bed.Position - playerPos)
            local localfacing = (lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") and lplr.Character.HumanoidRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)) or Vector3.new(1, 0, 0)
            local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))

            if angle <= math.rad(bedassistangle.Value) / 2 then
                if bedassistlowestblock.Enabled then
                    if bed.Position.Y < lowestY then
                        lowestY = bed.Position.Y
                        closestBed = bed
                    end
                else
                    if distance < closestDistance then
                        closestDistance = distance
                        closestBed = bed
                    end
                end
            end
        end

        return closestBed
    end


    BedAssist = vape.Categories.Utility:CreateModule({
        Name = "BedAssist",
        Function = function(callback)
            if callback then
                beds = collectionService:GetTagged("bed")
                local connection
                connection = runService.Heartbeat:Connect(function(dt)
                    if not BedAssist.Enabled then
                        connection:Disconnect()
                        camera.CameraType = Enum.CameraType.Custom
                        return
                    end
                    if not entitylib.isAlive then
                        return
                    end
					if bedassisthandcheck.Enabled and not checkHand() then 
						return
					end
                    if bedassistfirstperson.Enabled and not isFirstPerson() then
                        return
                    end
                    if bedassistshopcheck.Enabled then
                        local isShop = lplr:FindFirstChild("PlayerGui") and lplr.PlayerGui:FindFirstChild("ItemShop")
                        if isShop then return end
                    end

                    local playerPos = entitylib.LocalPosition or entitylib.character.HumanoidRootPart.Position
                    local closestBed = getClosestEnemyBed(playerPos)

                    if closestBed then
                        local bedPos = closestBed.Position
                        local currentCFrame = camera.CFrame
                        local targetCFrame = CFrame.lookAt(currentCFrame.Position, bedPos)
                        local lerpAmount = bedassistsmoothness.Value / 15
                        camera.CFrame = currentCFrame:Lerp(targetCFrame, math.min(getBedAimSpeed(bedassistsmoothness.Value, dt), 0.95))
                    end
                end)
                table.insert(Connections, connection)
            else
                for _, v in pairs(Connections) do
                    pcall(function()
                        v:Disconnect()
                    end)
                end
                Connections = {}
                table.clear(beds)
                camera.CameraType = Enum.CameraType.Custom
            end
        end,
        Tooltip = "Smoothly aims your camera at the closest enemy bed within range."
    })

    bedassistrange = BedAssist:CreateSlider({
        Name = "Assist Range",
        Min = 10,
        Max = 100,
        Function = function(val) end,
        Default = 30,
        Suffix = function(val) 
            return val == 1 and "stud" or "studs" 
        end
    })

    bedassistsmoothness = BedAssist:CreateSlider({
        Name = "Aim Speed",
        Min = 1,
        Max = 20,
        Function = function(val) end,
        Default = 6
    })

    bedassistangle = BedAssist:CreateSlider({
        Name = "Max Angle",
        Min = 10,
        Max = 360,
        Function = function(val) end,
        Default = 70
    })

    bedassistfirstperson = BedAssist:CreateToggle({
        Name = "First Person Only",
        Function = function() end,
        Default = false,
        Tooltip = "Only activates in first-person mode."
    })

    bedassistshopcheck = BedAssist:CreateToggle({
        Name = "Shop Check",
        Function = function() end,
        Default = false,
        Tooltip = "Disables aiming when in the shop menu."
    })

	bedassisthandcheck = BedAssist:CreateToggle({
		Name = "Hand Check",
		Function = function() end,
		Default = true,
		Tooltip = "Checks if you are holding a pickaxe"
	})

	bedassistlowestblock = BedAssist:CreateToggle({
		Name = "Target Lowest Block",
		Function = function() end,
		Default = false,
		Tooltip = "Targets the enemy bed at the lowest Y position instead of the closest"
	})

    table.insert(Connections, collectionService:GetInstanceAddedSignal("bed"):Connect(function(bed)
        table.insert(beds, bed)
    end))

    table.insert(Connections, collectionService:GetInstanceRemovedSignal("bed"):Connect(function(bed)
        local i = table.find(beds, bed)
        if i then
            table.remove(beds, i)
        end
    end))
end)

run(function()
	local DRBedAlarm
	local DetectionRange
	local RepeatNotifications
	local NotificationDelay
	local UseDisplayName
	local NotifyKits
	local TepearlCheck
	local TepearlRange
	local HighlightEnemies
	local HighlightColor
	local PlayAlarmSound
	local UseCustomSound
	local AlarmSoundId
	local AlarmVolume
	local customAlarmSound = nil
	local AlarmActive = false
	local PlayersNearBed = {}
	local LastNotificationTime = {}
	local CachedBed = nil
	local CachedBedPosition = nil
	local LastBedCheck = 0
	local PearlCache = {} 
	local LastPearlCheck = {}
	local ActiveHighlights = {}
	local LastAlarmSoundTick = 0
	
	local function getKitName(kitId)
		if bedwars.BedwarsKitMeta[kitId] then
			return bedwars.BedwarsKitMeta[kitId].name
		end
		return kitId:gsub("_", " "):gsub("^%l", string.upper)
	end
	
	local function getOwnBed()
		local currentTime = tick()
		
		if CachedBed and CachedBed.Parent and (currentTime - LastBedCheck) < 2 then
			return CachedBed, CachedBedPosition
		end
		
		if not entitylib.isAlive then 
			CachedBed = nil
			CachedBedPosition = nil
			return nil 
		end
		
		local playerTeam = lplr:GetAttribute('Team')
		if not playerTeam then 
			CachedBed = nil
			CachedBedPosition = nil
			return nil 
		end
		
		local tagged = collectionService:GetTagged('bed')
		for _, bed in ipairs(tagged) do
			if bed:GetAttribute('Team'..playerTeam..'NoBreak') then
				CachedBed = bed
				CachedBedPosition = bed.Position
				LastBedCheck = currentTime
				return bed, CachedBedPosition
			end
		end
		
		CachedBed = nil
		CachedBedPosition = nil
		return nil
	end
	
	local function getPlayerName(ent)
		if not ent.Player then return ent.Character.Name end
		return UseDisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name
	end
	
	local function getPlayerKit(ent)
		if not ent.Player then return nil end
		local kit = ent.Player:GetAttribute('PlayingAsKits')
		if kit and kit ~= 'none' then
			return getKitName(kit)
		end
		return nil
	end
	
	local function isHoldingPearl(ent, currentTime)
		if not ent.Player then return false end
		
		local lastCheck = LastPearlCheck[ent] or 0
		if (currentTime - lastCheck) < 0.5 and PearlCache[ent] ~= nil then
			return PearlCache[ent]
		end
		
		local inventory = store.inventories[ent.Player]
		if not inventory then 
			PearlCache[ent] = false
			LastPearlCheck[ent] = currentTime
			return false 
		end
		
		local handItem = inventory.hand
		
		if handItem and handItem.itemType then
			local itemType = handItem.itemType:lower()
			local hasPearl = itemType == 'telepearl' or itemType == 'teleport_pearl' or itemType:find('pearl', 1, true)
			PearlCache[ent] = hasPearl
			LastPearlCheck[ent] = currentTime
			return hasPearl
		end
		
		PearlCache[ent] = false
		LastPearlCheck[ent] = currentTime
		return false
	end
	
	local function createHighlight(ent)
		if not HighlightEnemies.Enabled then return end
		if ActiveHighlights[ent] then return end
		
		local character = ent.Character
		if not character then return end
		
		local highlight = Instance.new("Highlight")
		highlight.Name = "DRBedAlarmHighlight"
		highlight.Adornee = character
		local hue, sat, val = HighlightColor.Hue, HighlightColor.Sat, HighlightColor.Value
		local color = Color3.fromHSV(hue, sat, val)
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
		
		ActiveHighlights[ent] = highlight
	end
	
	local function removeHighlight(ent)
		if ActiveHighlights[ent] then
			ActiveHighlights[ent]:Destroy()
			ActiveHighlights[ent] = nil
		end
	end
	
	local function playAlarm(bedPosition, entPosition)
		if not PlayAlarmSound.Enabled then return end
		if os.time() < AlarmSoundTick then return end
		AlarmSoundTick = os.time() + 1.2

		if UseCustomSound and UseCustomSound.Enabled and AlarmSoundId and AlarmSoundId.Value and AlarmSoundId.Value ~= '' then
			pcall(function()
				if not customAlarmSound or not customAlarmSound.Parent then
					customAlarmSound = Instance.new('Sound')
					customAlarmSound.Parent = workspace
				end
				customAlarmSound.SoundId = 'rbxassetid://' .. AlarmSoundId.Value
				customAlarmSound.Volume = AlarmVolume.Value
				customAlarmSound:Play()
			end)
			return
		end

		local distance = entPosition and (bedPosition - entPosition).Magnitude or 0
		local soundId = distance >= 30 and bedwars.SoundList.BED_ALARM_TRIGGERED_FAR or bedwars.SoundList.BED_ALARM
		pcall(function()
			bedwars.SoundManager:playSound(soundId, {
				volumeMultiplier = AlarmVolume.Value
			})
		end)
	end
	
	local function stopAlarm()
	end
	
	local function createNotification(ent, hasPearl)
		local playerName = getPlayerName(ent)
		local message = playerName..' is near your bed!'
		
		if hasPearl then
			message = playerName..' is near your bed WITH A PEARL!'
		end
		
		if NotifyKits.Enabled then
			local kit = getPlayerKit(ent)
			if kit then
				if hasPearl then
					message = playerName..' is near your bed WITH A PEARL! (Kit: '..kit..')'
				else
					message = playerName..' is near your bed! (Kit: '..kit..')'
				end
			end
		end
		
		notif('Bed Alarm', message, 3)
	end
	
	local lastCheckTime = 0
	local function checkPlayers()
		if not DRBedAlarm.Enabled then return end
		if not entitylib.isAlive then return end
		
		local currentTime = tick()
		
		if (currentTime - lastCheckTime) < 0.1 then
			return
		end
		lastCheckTime = currentTime
		
		local bed, bedPosition = getOwnBed()
		if not bed or not bedPosition then return end
		
		local currentPlayersNear = {}
		local normalRange = DetectionRange.Value
		local pearlRangeEnabled = TepearlCheck.Enabled
		local pearlRange = pearlRangeEnabled and TepearlRange.Value or normalRange
		
		local normalRangeSq = normalRange * normalRange
		local pearlRangeSq = pearlRange * pearlRange
		
		local anyoneNear = false
		local lastNearEnt = nil
		
		for _, ent in ipairs(entitylib.List) do
			if not ent.Targetable then continue end
			if not ent.Player then continue end
			if getAccountTier(ent.Player) >= 4 and getAccountTier(ent.Player) < 99 and getAccountTier(lplr) == 0 then continue end


			local distanceVector = ent.RootPart.Position - bedPosition
			local distanceSq = distanceVector.X * distanceVector.X + distanceVector.Y * distanceVector.Y + distanceVector.Z * distanceVector.Z
			
			local hasPearl = false
			local inRange = false
			
			if pearlRangeEnabled and distanceSq <= pearlRangeSq then
				hasPearl = isHoldingPearl(ent, currentTime)
				if hasPearl then
					inRange = true
				end
			end
			
			if not inRange and distanceSq <= normalRangeSq then
				inRange = true
			end
			
			if inRange then
				currentPlayersNear[ent] = true
				anyoneNear = true
				lastNearEnt = ent
				
				createHighlight(ent)
				
				local shouldNotify = false
				
				if not PlayersNearBed[ent] then
					shouldNotify = true
				elseif RepeatNotifications.Enabled then
					local lastTime = LastNotificationTime[ent] or 0
					if currentTime - lastTime >= NotificationDelay.Value then
						shouldNotify = true
					end
				end
				
				if shouldNotify then
					createNotification(ent, hasPearl)
					LastNotificationTime[ent] = currentTime
					if PlayAlarmSound.Enabled and tick() - LastAlarmSoundTick >= NotificationDelay.Value then
						LastAlarmSoundTick = tick()
						local distance = (bedPosition - ent.RootPart.Position).Magnitude
						local soundId = distance >= 30 and bedwars.SoundList.BED_ALARM_TRIGGERED_FAR or bedwars.SoundList.BED_ALARM
						pcall(function()
							bedwars.SoundManager:playSound(soundId, {
								volumeMultiplier = AlarmVolume.Value
							})
						end)
					end
				end
			else
				removeHighlight(ent)
			end
		end
		
		for ent, _ in pairs(ActiveHighlights) do
			if not currentPlayersNear[ent] then
				removeHighlight(ent)
			end
		end
		
		PlayersNearBed = currentPlayersNear
	end
	
	DRBedAlarm = vape.Categories.Utility:CreateModule({
		Name = 'DRBedAlarm',
		Function = function(callback)
			if callback then
				local bed = getOwnBed()
				if not bed then
					notif('DRBedAlarm', 'Cannot locate your bed!', 3)
					DRBedAlarm:Toggle()
					return
				end
				
				AlarmActive = true
				PlayersNearBed = {}
				LastNotificationTime = {}
				PearlCache = {}
				LastPearlCheck = {}
				ActiveHighlights = {}
				lastCheckTime = 0
				
				DRBedAlarm:Clean(task.spawn(function()
					while DRBedAlarm.Enabled do
						checkPlayers()
						task.wait(0.1)
					end
				end))
			else
				AlarmActive = false
				
				stopAlarm()
				AlarmSoundTick = 0
				
				for ent, highlight in pairs(ActiveHighlights) do
					if highlight then
						highlight:Destroy()
					end
				end
				
				table.clear(PlayersNearBed)
				table.clear(LastNotificationTime)
				table.clear(PearlCache)
				table.clear(LastPearlCheck)
				table.clear(ActiveHighlights)
				CachedBed = nil
				CachedBedPosition = nil
			end
		end,
		Tooltip = 'Alerts you when enemies are near your bed'
	})
	
	DetectionRange = DRBedAlarm:CreateSlider({
		Name = 'Detection Range',
		Function = function() end,
		Default = 30,
		Min = 10,
		Max = 100,
		Tooltip = 'Distance in studs to detect players near bed'
	})
	
	TepearlCheck = DRBedAlarm:CreateToggle({
		Name = 'Telepearl Check',
		Function = function(callback)
			if TepearlRange and TepearlRange.Object then
				TepearlRange.Object.Visible = callback
			end
		end,
		Default = false,
		Tooltip = 'Extended detection range for players holding pearls'
	})
	
	TepearlRange = DRBedAlarm:CreateSlider({
		Name = 'Pearl Range',
		Function = function() end,
		Default = 250,
		Min = 100,
		Max = 500,
		Visible = false,
		Tooltip = 'Detection range for players with pearls'
	})
	
	RepeatNotifications = DRBedAlarm:CreateToggle({
		Name = 'Repeat Notifications',
		Function = function(callback)
			if NotificationDelay and NotificationDelay.Object then
				NotificationDelay.Object.Visible = callback
			end
		end,
		Default = false,
		Tooltip = 'Continue notifying while players remain near bed'
	})
	
	NotificationDelay = DRBedAlarm:CreateSlider({
		Name = 'Notification Delay',
		Function = function() end,
		Default = 5,
		Min = 1,
		Max = 10,
		Visible = false,
		Tooltip = 'Seconds between repeat notifications'
	})
	
	UseDisplayName = DRBedAlarm:CreateToggle({
		Name = 'Show Display Name',
		Function = function() end,
		Default = true,
		Tooltip = 'Show player display names instead of usernames'
	})
	
	NotifyKits = DRBedAlarm:CreateToggle({
		Name = 'Notify Kits',
		Function = function() end,
		Default = true,
		Tooltip = 'Include player kit in notification'
	})
	
	HighlightEnemies = DRBedAlarm:CreateToggle({
		Name = 'Highlight Enemies',
		Function = function(callback)
			if HighlightColor and HighlightColor.Object then
				HighlightColor.Object.Visible = callback
			end
			
			if not callback then
				for ent, highlight in pairs(ActiveHighlights) do
					if highlight then
						highlight:Destroy()
					end
				end
				table.clear(ActiveHighlights)
			end
		end,
		Default = false,
		Tooltip = 'Highlight enemies near your bed through walls'
	})
	
	HighlightColor = DRBedAlarm:CreateColorSlider({
		Name = 'Highlight Color',
		Function = function(hue, sat, val)
			local newColor = Color3.fromHSV(hue, sat, val)
			for ent, highlight in pairs(ActiveHighlights) do
				if highlight then
					highlight.FillColor = newColor
					highlight.OutlineColor = newColor
				end
			end
		end,
		Default = 1,
		Visible = false,
		Tooltip = 'Color of the enemy highlight'
	})
	
	PlayAlarmSound = DRBedAlarm:CreateToggle({
		Name = 'Play Alarm Sound',
		Function = function(callback)
			if AlarmVolume and AlarmVolume.Object then
				AlarmVolume.Object.Visible = callback
			end
			if UseCustomSound and UseCustomSound.Object then
				UseCustomSound.Object.Visible = callback
			end
			if not callback then
				stopAlarm()
				if customAlarmSound and customAlarmSound.Parent then
					customAlarmSound:Stop()
				end
			end
		end,
		Default = false,
		Tooltip = 'Play alarm sound when enemies are near bed'
	})
	
	AlarmVolume = DRBedAlarm:CreateSlider({
		Name = 'Alarm Volume',
		Function = function() end,
		Default = 1.5,
		Min = 0.1,
		Max = 3,
		Decimal = 5,
		Visible = false,
		Tooltip = 'Volume multiplier for the alarm sound'
	})

	UseCustomSound = DRBedAlarm:CreateToggle({
		Name = 'Use Custom Sound',
		Function = function(callback)
			if AlarmSoundId and AlarmSoundId.Object then
				AlarmSoundId.Object.Visible = callback
			end
			if not callback and customAlarmSound and customAlarmSound.Parent then
				customAlarmSound:Stop()
			end
		end,
		Default = false,
		Visible = false,
		Tooltip = 'Use a custom Roblox sound ID instead of the default alarm'
	})

	AlarmSoundId = DRBedAlarm:CreateTextBox({
		Name = 'Custom Sound ID',
		Default = '131961136',
		Visible = false,
		Tooltip = 'Enter a Roblox asset sound ID to play yo shit'
	})
end)

run(function()
	local InfKrystal
	local UPDATE_INTERVAL = 0.016
	local lastUpdateTime = 0
	local renderStepName = 'InfiniteKrystalMovement'

	InfKrystal = vape.Categories.Kits:CreateModule({
		Name = 'InfKrystal',
		Tooltip = 'Infinite Krystal movement',
		Function = function(callback)
			if callback then
				lastUpdateTime = 0

				runService:BindToRenderStep(
					renderStepName,
					Enum.RenderPriority.Character.Value + 2,
					function()
						local currentTime = tick()

						if currentTime - lastUpdateTime < UPDATE_INTERVAL then
							return
						end

						lastUpdateTime = currentTime

						pcall(function()
							bedwars.GlacialSkaterController:updateMomentum(100, "newValue")
						end)
					end
				)
			else
				runService:UnbindFromRenderStep(renderStepName)

				pcall(function()
					bedwars.GlacialSkaterController:updateMomentum(0, "newValue")
				end)
			end
		end
	})
end)

run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local CollectionService = collectionService
	
	local lootTypes = {
		iron = {
			keywords = {'iron'},
			color = Color3.fromRGB(200, 200, 200),
			icon = 'iron',
			displayName = 'IRON'
		},
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'DIAMOND'
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'EMERALD'
		}
	}
	
	local function getLootType(itemName)
		local nameLower = itemName:lower()
		for lootType, config in pairs(lootTypes) do
			for _, keyword in ipairs(config.keywords) do
				if nameLower:find(keyword, 1, true) then 
					return lootType, config
				end
			end
		end
		return nil
	end
	
	local function isLootEnabled(lootType)
		if lootType == 'iron' then
			return IronToggle.Enabled
		elseif lootType == 'diamond' then
			return DiamondToggle.Enabled
		elseif lootType == 'emerald' then
			return EmeraldToggle.Enabled
		end
		return false
	end
	
	local function getProperIcon(lootType)
		local icon = bedwars.getIcon({itemType = lootType}, true)
		
		if not icon or icon == "" then
			return nil
		end
		
		return icon
	end
	
	local function Added(lootHandle, lootType, config)
		if not isLootEnabled(lootType) then return end
		if Reference[lootHandle] then return end 
		
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = lootType
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(40, 40)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = lootHandle
		
		local blur = addBlur(billboard)
		blur.Visible = true 
		
		local iconImage = getProperIcon(config.icon)
		
		if iconImage then
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(40, 40)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundColor3 = Color3.new(0, 0, 0) 
			image.BackgroundTransparency = 0.3 
			image.BorderSizePixel = 0
			image.Image = iconImage
			image.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = image
		else
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.new(0, 0, 0) 
			frame.BackgroundTransparency = 0.3 
			frame.BorderSizePixel = 0
			frame.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = frame
			
			local textLabel = Instance.new('TextLabel')
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Position = UDim2.fromScale(0.5, 0.5)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = config.displayName
			textLabel.TextColor3 = config.color
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			textLabel.Parent = frame
		end
		
		Reference[lootHandle] = billboard
	end
	
	local function Removed(lootHandle)
		if Reference[lootHandle] then
			Reference[lootHandle]:Destroy()
			Reference[lootHandle] = nil
		end
	end
	
	local function findExistingLoot()
		local tagged = CollectionService:GetTagged('ItemDrop')
		for _, drop in ipairs(tagged) do
			local handle = drop:FindFirstChild('Handle')
			if handle then
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					if not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	local function refreshLootType(lootType)
		if not LootESP.Enabled then return end
		
		local enabled = isLootEnabled(lootType)
		
		if not enabled then
			for handle, billboard in pairs(Reference) do
				if billboard.Name == lootType then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		else
			local tagged = CollectionService:GetTagged('ItemDrop')
			for _, drop in ipairs(tagged) do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local dropLootType, config = getLootType(drop.Name)
					if dropLootType == lootType and not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			if callback then
				findExistingLoot()
				
				LootESP:Clean(CollectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
					if not LootESP.Enabled then return end
					
					task.defer(function()
						local handle = drop:FindFirstChild('Handle')
						if not handle then return end
						
						local lootType, config = getLootType(drop.Name)
						if lootType and isLootEnabled(lootType) then
							Added(handle, lootType, config)
						end
					end)
				end))
				
				LootESP:Clean(CollectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
					local handle = drop:FindFirstChild('Handle')
					if handle then
						Removed(handle)
					end
				end))
				
			else
				for handle, billboard in pairs(Reference) do
					billboard:Destroy()
				end
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for loot drops (iron, diamond, emerald)'
	})
	
	IronToggle = LootESP:CreateToggle({
		Name = 'Iron',
		Function = function(callback)
			refreshLootType('iron')
		end,
		Default = true
	})
	
	DiamondToggle = LootESP:CreateToggle({
		Name = 'Diamond',
		Function = function(callback)
			refreshLootType('diamond')
		end,
		Default = true
	})
	
	EmeraldToggle = LootESP:CreateToggle({
		Name = 'Emerald',
		Function = function(callback)
			refreshLootType('emerald')
		end,
		Default = true
	})
end)
run(function()
	local ViewMatchHistory
	ViewMatchHistory = vape.Categories.Utility:CreateModule({
		Name = "ViewMatchHistory",
		Function = function(callback)
			if callback then
				ViewMatchHistory:Toggle(false)
				local controller = bedwars.MatchHistoryController or bedwars.MatchHistroyController
				local app = bedwars.MatchHistoryApp or bedwars.MatchHistroyApp
				if not (controller and controller.requestMatchHistory and app and bedwars.AppController) then
					warn('[Vape] Match History is unavailable in this BedWars version.')
					return
				end
				controller:requestMatchHistory(lplr.Name):andThen(function(data)
					if data then
						bedwars.AppController:openApp({app = app, appId = 'MatchHistoryApp'}, data)
					end
				end):catch(function(err)
					warn('[Vape] Could not load match history: ' .. tostring(err))
				end)
			else
				return
			end
		end,
		Tooltip = 'View your recent match history'
	})								
end)
run(function()
    local Beekeeper
    local CollectionToggle
	local LimitToNet
	local maxBeehiveLevel = 10
    local maxedBeehives = {}
    local maxedNotificationSent = {}
    local CollectionDelay
    local DelaySlider
    local RangeSlider
    local ESPToggle
    local BeesESP
    local BeesNotify
    local BeesBackground
    local BeesColor
    local BeehiveESP
    local ShowOtherBeehives
    local BeehiveBackground
    local BeehiveColor
    local AutoDeposit
    local DepositDelay
    local DepositDelaySlider
    local DepositRange
    local ESPLimitToNet  
    local collectionRunning = false
    local depositRunning = false
    local BeesFolder = Instance.new('Folder')
    BeesFolder.Parent = vape.gui
    local BeehiveFolder = Instance.new('Folder')
    BeehiveFolder.Parent = vape.gui
    local BeesReference = {}
    local BeehiveReference = {}
    local lastNotification = 0
    local spawnQueue = {}
    local notificationCooldown = 1

    local function sendNotification(count)
        notif("Bee ESP", string.format("%d bees spawned", count), 3)
    end

    local function processSpawnQueue()
        if #spawnQueue > 0 then
            local currentTime = tick()
            if currentTime - lastNotification >= notificationCooldown then
                sendNotification(#spawnQueue)
                lastNotification = currentTime
                spawnQueue = {}
            else
                task.delay(notificationCooldown - (currentTime - lastNotification), function()
                    if #spawnQueue > 0 then
                        sendNotification(#spawnQueue)
                        spawnQueue = {}
                    end
                end)
            end
        end
    end

    local function getBeeIcon()
        return bedwars.getIcon({itemType = 'bee'}, true)
    end

    local function AddedBee(v)
        if BeesReference[v] then return end
        local model = v.Parent
        if model then
            if model.Name:find("TamedBee") or model:FindFirstChild("TamedBee") then
                return 
            end
            
            if model:GetAttribute("IsTamed") or model:GetAttribute("Tamed") then
                return 
            end
            
            for _, tag in pairs(collectionService:GetTags(model)) do
                if tag:lower():find("tamed") then
                    return 
                end
            end
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = BeesFolder
        billboard.Name = 'bee'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        
        local blur = addBlur(billboard)
        blur.Visible = BeesBackground.Enabled
        
        local image = Instance.new('ImageLabel')
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(BeesColor.Hue, BeesColor.Sat, BeesColor.Value)
        image.BackgroundTransparency = 1 - (BeesBackground.Enabled and BeesColor.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = getBeeIcon()
        image.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image
        
        BeesReference[v] = billboard
        
        if BeesNotify.Enabled then
            table.insert(spawnQueue, {item = 'bee', time = tick()})
            processSpawnQueue()
        end
    end

    local function RemovedBee(v)
        if BeesReference[v] then
            BeesReference[v]:Destroy()
            BeesReference[v] = nil
        end
    end

    local function isMyBeehive(beehive)
        if not beehive then return false end
        local placedBy = beehive:GetAttribute("PlacedByUserId")
        return placedBy and placedBy == lplr.UserId
    end
    
    local function getBeehiveOwnerName(beehive)
        if not beehive then return "Unknown" end
        local placedBy = beehive:GetAttribute("PlacedByUserId")
        if not placedBy then return "Unknown" end
        
        local player = game.Players:GetPlayerByUserId(placedBy)
        if player then
            return player.Name
        end
        
        return "Player"
    end

    local function AddedBeehive(beehive)
        local isOwn = isMyBeehive(beehive)
        
        if not isOwn and not (ShowOtherBeehives and ShowOtherBeehives.Enabled) then 
            return 
        end
        
        if BeehiveReference[beehive] then return end
        
        local level = beehive:GetAttribute("Level") or 0
        local isMaxed = level >= maxBeehiveLevel and isOwn
        
        if isMaxed and isOwn then
            maxedBeehives[beehive] = true
        end
        
        local ownerName = isOwn and nil or getBeehiveOwnerName(beehive)
        local hasOwnerName = ownerName ~= nil
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = BeehiveFolder
        billboard.Name = 'beehive-esp'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
        billboard.Size = isMaxed and UDim2.fromOffset(90, 40) or (hasOwnerName and UDim2.fromOffset(120, 40) or UDim2.fromOffset(80, 30))
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = beehive
        
        local blur = addBlur(billboard)
        blur.Visible = BeehiveBackground.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = isMaxed and Color3.fromRGB(255, 50, 50) or Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and (isMaxed and 0.5 or BeehiveColor.Opacity) or 0)
        frame.BorderSizePixel = 0
        frame.Parent = billboard
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 6)
        uicorner.Parent = frame
        
        if hasOwnerName then
            local nameLabel = Instance.new('TextLabel')
            nameLabel.Name = 'OwnerName'
            nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
            nameLabel.Position = UDim2.new(0, 0, 0, -20)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = ownerName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextStrokeTransparency = 0.5
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Parent = billboard
        end
        
        local homeImage = Instance.new('TextLabel')
        homeImage.Size = UDim2.fromOffset(20, 20)
        homeImage.Position = UDim2.new(0, 5, 0.5, 0)
        homeImage.AnchorPoint = Vector2.new(0, 0.5)
        homeImage.BackgroundTransparency = 1
        homeImage.Text = isOwn and "🏠" or "🏘️"
        homeImage.TextSize = 16
        homeImage.Parent = frame
        
        local beeImage = Instance.new('ImageLabel')
        beeImage.Size = UDim2.fromOffset(18, 18)
        beeImage.Position = UDim2.new(0.5, -5, 0.5, 0)
        beeImage.AnchorPoint = Vector2.new(0, 0.5)
        beeImage.BackgroundTransparency = 1
        beeImage.Image = getBeeIcon()
        beeImage.Parent = frame
        
        local levelLabel = Instance.new('TextLabel')
        levelLabel.Name = 'Level'
        levelLabel.Size = UDim2.new(0, 25, 1, 0)
        levelLabel.Position = UDim2.new(1, -30, 0, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = tostring(level)
        levelLabel.TextColor3 = isMaxed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 255, 255)
        levelLabel.TextSize = 16
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.TextStrokeTransparency = 0.5
        levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        levelLabel.Parent = frame
        
        if isMaxed and isOwn then
            local maxText = Instance.new('TextLabel')
            maxText.Name = 'MaxText'
            maxText.Size = UDim2.new(1, 0, 0.4, 0)
            maxText.Position = UDim2.new(0, 0, 0, hasOwnerName and -40 or -20)
            maxText.BackgroundTransparency = 1
            maxText.Text = "MAX"
            maxText.TextColor3 = Color3.fromRGB(255, 50, 50)
            maxText.TextSize = 12
            maxText.Font = Enum.Font.GothamBold
            maxText.TextStrokeTransparency = 0.5
            maxText.TextStrokeColor3 = Color3.new(0, 0, 0)
            maxText.Parent = billboard
        end
        
        BeehiveReference[beehive] = {
            billboard = billboard,
            levelLabel = levelLabel,
            beehive = beehive,
            isMaxed = isMaxed,
            isOwn = isOwn
        }
        
        local function updateLevel()
            local level = beehive:GetAttribute("Level") or 0
            local isMaxed = level >= maxBeehiveLevel and isOwn
            
            if isMaxed and isOwn then
                maxedBeehives[beehive] = true
                
                if not maxedNotificationSent[beehive] then
                    notif("Bee Keeper", "Beehive is full (MAX)", 3)
                    maxedNotificationSent[beehive] = true
                end
                
                if BeehiveReference[beehive] and BeehiveReference[beehive].billboard then
                    local maxText = BeehiveReference[beehive].billboard:FindFirstChild("MaxText")
                    if not maxText then
                        maxText = Instance.new('TextLabel')
                        maxText.Name = 'MaxText'
                        maxText.Size = UDim2.new(1, 0, 0.4, 0)
                        maxText.Position = UDim2.new(0, 0, 0, hasOwnerName and -40 or -20)
                        maxText.BackgroundTransparency = 1
                        maxText.Text = "MAX"
                        maxText.TextColor3 = Color3.fromRGB(255, 50, 50)
                        maxText.TextSize = 12
                        maxText.Font = Enum.Font.GothamBold
                        maxText.TextStrokeTransparency = 0.5
                        maxText.TextStrokeColor3 = Color3.new(0, 0, 0)
                        maxText.Parent = BeehiveReference[beehive].billboard
                    end
                    
                    local frame = BeehiveReference[beehive].billboard:FindFirstChild("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and 0.5 or 0)
                    end
                end
            else
                if isOwn then
                    maxedBeehives[beehive] = nil
                    maxedNotificationSent[beehive] = nil
                end
                
                if BeehiveReference[beehive] and BeehiveReference[beehive].billboard then
                    local maxText = BeehiveReference[beehive].billboard:FindFirstChild("MaxText")
                    if maxText then
                        maxText:Destroy()
                    end
                    
                    local frame = BeehiveReference[beehive].billboard:FindFirstChild("Frame")
                    if frame then
                        frame.BackgroundColor3 = Color3.fromHSV(BeehiveColor.Hue, BeehiveColor.Sat, BeehiveColor.Value)
                        frame.BackgroundTransparency = 1 - (BeehiveBackground.Enabled and BeehiveColor.Opacity or 0)
                    end
                end
            end
            
            if BeehiveReference[beehive] and BeehiveReference[beehive].levelLabel then
                BeehiveReference[beehive].levelLabel.Text = tostring(level)
            end
            
            if BeehiveReference[beehive] then
                BeehiveReference[beehive].isMaxed = isMaxed
            end
        end
        
        updateLevel()
        
        if isOwn then
            Beekeeper:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(updateLevel))
        else
            Beekeeper:Clean(beehive:GetAttributeChangedSignal("Level"):Connect(function()
                local level = beehive:GetAttribute("Level") or 0
                if BeehiveReference[beehive] and BeehiveReference[beehive].levelLabel then
                    BeehiveReference[beehive].levelLabel.Text = tostring(level)
                end
            end))
        end
    end


    local function RemovedBeehive(beehive)
        if BeehiveReference[beehive] then
            BeehiveReference[beehive].billboard:Destroy()
            BeehiveReference[beehive] = nil
        end
    end

    local function setupBeesESP()
        for _, v in collectionService:GetTagged('bee') do
            if v:IsA("Model") and v.PrimaryPart then
                if not v.Name:find("TamedBee") and not v:FindFirstChild("TamedBee") then
                    AddedBee(v.PrimaryPart)
                end
            end
        end

        Beekeeper:Clean(collectionService:GetInstanceAddedSignal('bee'):Connect(function(v)
            if v:IsA("Model") and v.PrimaryPart then
                task.wait(0.1)
                if not v.Name:find("TamedBee") and not v:FindFirstChild("TamedBee") then
                    AddedBee(v.PrimaryPart)
                end
            end
        end))

        Beekeeper:Clean(collectionService:GetInstanceRemovedSignal('bee'):Connect(function(v)
            if v.PrimaryPart then
                RemovedBee(v.PrimaryPart)
            end
        end))
        

    end

    local function setupBeehiveESP()
        for _, beehive in collectionService:GetTagged('beehive') do
            AddedBeehive(beehive)
        end

        Beekeeper:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(function(beehive)
            task.wait(0.1)
            AddedBeehive(beehive)
        end))

        Beekeeper:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(function(beehive)
            RemovedBeehive(beehive)
        end))
    end

    local function isHoldingBeeNet()
        if not store.hand or not store.hand.tool then return false end
        return store.hand.tool.Name == 'bee_net' or store.hand.tool.Name == 'bee-net'
    end

    local function startCollection()
        collectionRunning = true
        task.spawn(function()
            while collectionRunning and Beekeeper.Enabled and CollectionToggle.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                if LimitToNet.Enabled and not isHoldingBeeNet() then
                    task.wait(0.5)
                    continue
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = RangeSlider.Value
                local beesFound = false
                
                for _, v in collectionService:GetTagged('bee') do
                    if not collectionRunning or not Beekeeper.Enabled or not CollectionToggle.Enabled then 
                        break 
                    end
                    
                    if LimitToNet.Enabled and not isHoldingBeeNet() then
                        break
                    end
                    
                    if v:IsA("Model") and v.PrimaryPart then
                        local beePos = v.PrimaryPart.Position
                        local distance = (localPosition - beePos).Magnitude
                        
                        if distance <= range then
                            beesFound = true
                            
                            if CollectionDelay.Enabled and DelaySlider.Value > 0 then
                                task.wait(DelaySlider.Value)
                            end
                            
                            if LimitToNet.Enabled and not isHoldingBeeNet() then
                                break
                            end
                            
                            local beeId = v:GetAttribute('BeeId')
                            if beeId then
                                bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = beeId})
                                task.wait(0.1)
                            end
                        end
                    end
                end
                
                if not beesFound then
                    task.wait(0.2)
                else
                    task.wait(0.1)
                end
            end
            collectionRunning = false
        end)
    end

    local function startDeposit()
        depositRunning = true
        task.spawn(function()
            while depositRunning and Beekeeper.Enabled and AutoDeposit.Enabled do
                if not entitylib.isAlive then 
                    task.wait(0.1) 
                    continue 
                end
                
                local currentTool = store.hand and store.hand.tool
                if not currentTool or currentTool.Name ~= 'bee' then
                    task.wait(0.1)
                    continue
                end
                
                local localPosition = entitylib.character.RootPart.Position
                local range = DepositRange.Value
                local depositedThisCycle = false
                
                local availableBeehives = {}
                for _, beehive in collectionService:GetTagged('beehive') do
                    if isMyBeehive(beehive) and not maxedBeehives[beehive] then
                        local beehivePos = beehive.Position
                        local distance = (localPosition - beehivePos).Magnitude
                        
                        if distance <= range then
                            table.insert(availableBeehives, {
                                beehive = beehive,
                                distance = distance
                            })
                        end
                    end
                end
                
                table.sort(availableBeehives, function(a, b)
                    return a.distance < b.distance
                end)
                
                for _, beehiveData in ipairs(availableBeehives) do
                    if not depositRunning or not Beekeeper.Enabled or not AutoDeposit.Enabled then 
                        break 
                    end
                    local beehive = beehiveData.beehive
                    if maxedBeehives[beehive] then
                        continue
                    end
                    
                    local prompt = beehive:FindFirstChildOfClass("ProximityPrompt")
                    
                    if prompt and prompt.Enabled then
                        if DepositDelay.Enabled and DepositDelaySlider.Value > 0 then
                            local originalDuration = prompt.HoldDuration
                            prompt.HoldDuration = DepositDelaySlider.Value
                            
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                task.wait(DepositDelaySlider.Value)
                                prompt:InputHoldEnd()
                            end
                            
                            task.wait(DepositDelaySlider.Value + 0.1)
                            prompt.HoldDuration = originalDuration
                        else
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                                prompt:InputHoldEnd()
                            end
                            task.wait(0.1)
                        end
                        
                        depositedThisCycle = true
                        break 
                    end
                end
                
                if not depositedThisCycle and #availableBeehives > 0 then
                    local allMaxed = true
                    for _, beehiveData in ipairs(availableBeehives) do
                        if not maxedBeehives[beehiveData.beehive] then
                            allMaxed = false
                            break
                        end
                    end
                    
                    if allMaxed then
                        notif("Bee Keeper", "All nearby beehives are full", 3)
                    end
                end
                
                task.wait(depositedThisCycle and 0.3 or 0.2)
            end
            depositRunning = false
        end)
    end

    Beekeeper = vape.Categories.Kits:CreateModule({
        Name = 'AutoBeekeeper',
        Function = function(callback)
            if callback then
                if ESPToggle.Enabled then
                    if BeesESP.Enabled then
                        setupBeesESP()
                    end
                    if BeehiveESP.Enabled then
                        setupBeehiveESP()
                    end
                end
                
                if CollectionToggle.Enabled then
                    startCollection()
                end
                
                if AutoDeposit.Enabled then
                    startDeposit()
                end
                
                local _bkLastUpdate = 0
                Beekeeper:Clean(runService.Heartbeat:Connect(function()
                    if not ESPToggle.Enabled then return end
                    local _now = tick()
                    if _now - _bkLastUpdate < 0.2 then return end
                    _bkLastUpdate = _now
                    
                    for v, billboard in pairs(BeesReference) do
                        if not v or not v.Parent then
                            RemovedBee(v)
                            continue
                        end

                        local shouldShow = true

                        if ESPLimitToNet.Enabled and not isHoldingBeeNet() then
                            shouldShow = false
                        end

                        billboard.Enabled = shouldShow
                    end
                    
                    for beehive, ref in pairs(BeehiveReference) do
                        if not beehive or not beehive.Parent then
                            RemovedBeehive(beehive)
                            continue
                        end

                        local shouldShow = true

                        if ESPLimitToNet.Enabled and not isHoldingBeeNet() then
                            shouldShow = false
                        end

                        if ref.billboard then
                            ref.billboard.Enabled = shouldShow
                        end
                    end
                end))
            else
                collectionRunning = false
                depositRunning = false
                BeesFolder:ClearAllChildren()
                BeehiveFolder:ClearAllChildren()
                table.clear(BeesReference)
                table.clear(BeehiveReference)
                table.clear(spawnQueue)
                lastNotification = 0
            end
        end,
        Tooltip = 'Automatically collects bees and manages beehives'
    })
    
    CollectionToggle = Beekeeper:CreateToggle({
        Name = 'Auto Collect',
        Default = true,
        Tooltip = 'Automatically collect bees',
        Function = function(callback)
            if LimitToNet and LimitToNet.Object then LimitToNet.Object.Visible = callback end
            if CollectionDelay and CollectionDelay.Object then CollectionDelay.Object.Visible = callback end
            if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = (callback and CollectionDelay.Enabled) end
            if RangeSlider and RangeSlider.Object then RangeSlider.Object.Visible = callback end
            
            if callback and Beekeeper.Enabled then
                startCollection()
            else
                collectionRunning = false
            end
        end
    })
    
    LimitToNet = Beekeeper:CreateToggle({
        Name = 'Limit to Net',
        Default = false,
        Tooltip = 'Only collect bees when holding bee net'
    })
    
    CollectionDelay = Beekeeper:CreateToggle({
        Name = 'Collection Delay',
        Default = false,
        Tooltip = 'Add delay before collecting bees',
        Function = function(callback)
            if DelaySlider and DelaySlider.Object then
                DelaySlider.Object.Visible = callback
            end
        end
    })
    
    DelaySlider = Beekeeper:CreateSlider({
        Name = 'Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay in seconds before collecting'
    })
    
    RangeSlider = Beekeeper:CreateSlider({
        Name = 'Range',
        Min = 1, 
        Max = 30,
        Default = 18,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Control distance you want to collect bees'
    })
    
    ESPToggle = Beekeeper:CreateToggle({
        Name = 'ESP',
        Default = true,
        Tooltip = 'ESP for bees and beehives',
		Function = function(callback)
			if BeesESP and BeesESP.Object then BeesESP.Object.Visible = callback end
			if BeehiveESP and BeehiveESP.Object then BeehiveESP.Object.Visible = callback end
			if ESPLimitToNet and ESPLimitToNet.Object then ESPLimitToNet.Object.Visible = callback end

			if not callback then
				if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
				if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
				if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
				if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
				if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
				if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
			else
				if BeesESP and BeesESP.Enabled then
					if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = true end
					if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = true end
					if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
				end
				if BeehiveESP and BeehiveESP.Enabled then
					if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = true end
					if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = true end
					if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
				end
			end

			if Beekeeper.Enabled then
				if callback then
					if BeesESP.Enabled then setupBeesESP() end
					if BeehiveESP.Enabled then setupBeehiveESP() end
				else
					BeesFolder:ClearAllChildren()
					BeehiveFolder:ClearAllChildren()
					table.clear(BeesReference)
					table.clear(BeehiveReference)
				end
			end
		end
    })
    
    ESPLimitToNet = Beekeeper:CreateToggle({
        Name = 'Limit to Net',
        Default = false,
        Tooltip = 'Only show ESP when holding bee net'
    })
    
    BeesESP = Beekeeper:CreateToggle({
        Name = 'Bees',
        Default = false,
        Tooltip = 'Show bee locations',
        Function = function(callback)
            if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = callback end
            if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = callback end
            if BeesColor and BeesColor.Object then BeesColor.Object.Visible = callback end
            
            if Beekeeper.Enabled and ESPToggle.Enabled then
                if callback then setupBeesESP() else
                    BeesFolder:ClearAllChildren()
                    table.clear(BeesReference)
                end
            end
        end
    })
    
    BeesNotify = Beekeeper:CreateToggle({
        Name = 'Notify',
        Default = false,
        Tooltip = 'Get notifications when bees spawn'
    })
    
    BeesBackground = Beekeeper:CreateToggle({
        Name = 'Background',
        Default = true,
        Function = function(callback)
            if BeesColor and BeesColor.Object then BeesColor.Object.Visible = callback end
            for _, v in BeesReference do
                if v and v:FindFirstChild("ImageLabel") then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and BeesColor.Opacity or 0)
                    if v:FindFirstChild("Blur") then
                        v.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
	BeesColor = Beekeeper:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in BeesReference do
				if v and v:FindFirstChild("ImageLabel") then
					v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.ImageLabel.BackgroundTransparency = 1 - opacity
				end
			end
		end,
		Darker = true
	})
    
    BeehiveESP = Beekeeper:CreateToggle({
        Name = 'Beehives',
        Default = false,
        Tooltip = 'Show your beehive locations with bee count',
        Function = function(callback)
            if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = callback end
            if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = callback end
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            
            if Beekeeper.Enabled and ESPToggle.Enabled then
                if callback then setupBeehiveESP() else
                    BeehiveFolder:ClearAllChildren()
                    table.clear(BeehiveReference)
                end
            end
        end
    })
    
    ShowOtherBeehives = Beekeeper:CreateToggle({
        Name = 'Show Others',
        Default = false,
        Tooltip = 'Show other players\' beehives with their usernames',
        Function = function(callback)
            if Beekeeper.Enabled and ESPToggle.Enabled and BeehiveESP.Enabled then
                BeehiveFolder:ClearAllChildren()
                table.clear(BeehiveReference)
                setupBeehiveESP()
            end
        end
    })
    
    BeehiveBackground = Beekeeper:CreateToggle({
        Name = 'Beehive Background',
        Default = true,
        Function = function(callback)
            if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = callback end
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame then
                        if ref.isMaxed and ref.isOwn then
                            frame.BackgroundTransparency = 1 - (callback and 0.5 or 0)
                        else
                            frame.BackgroundTransparency = 1 - (callback and BeehiveColor.Opacity or 0)
                        end
                    end
                    if ref.billboard:FindFirstChild("Blur") then
                        ref.billboard.Blur.Visible = callback
                    end
                end
            end
        end
    })
    
    BeehiveColor = Beekeeper:CreateColorSlider({
        Name = 'Beehive Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, ref in BeehiveReference do
                if ref and ref.billboard then
                    local frame = ref.billboard:FindFirstChild("Frame")
                    if frame and not (ref.isMaxed and ref.isOwn) then
                        frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        frame.BackgroundTransparency = 1 - opacity
                    end
                end
            end
        end,
        Darker = true
    })
    
    AutoDeposit = Beekeeper:CreateToggle({
        Name = 'Auto Deposit',
        Default = false,
        Tooltip = 'Automatically deposit bees into your beehives',
		Function = function(callback)
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = callback end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = (callback and DepositDelay.Enabled) end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = callback end
			
			if not callback then
				if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			end

			if callback and Beekeeper.Enabled then
				startDeposit()
			else
				depositRunning = false
			end
		end
    })
    
    DepositDelay = Beekeeper:CreateToggle({
        Name = 'Deposit Delay',
        Default = false,
        Tooltip = 'Add delay before depositing bees',
        Function = function(callback)
            if DepositDelaySlider and DepositDelaySlider.Object then
                DepositDelaySlider.Object.Visible = callback
            end
        end
    })
    
    DepositDelaySlider = Beekeeper:CreateSlider({
        Name = 'Deposit Delay',
        Min = 0,
        Max = 2,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'Delay in seconds before depositing'
    })
    
    DepositRange = Beekeeper:CreateSlider({
        Name = 'Deposit Range',
        Min = 1,
        Max = 15,
        Default = 10,
        Decimal = 1,
        Suffix = ' studs',
        Tooltip = 'Range to deposit bees into beehives'
    })
	task.defer(function()
		if DelaySlider and DelaySlider.Object then DelaySlider.Object.Visible = CollectionDelay.Enabled end
		if not ESPToggle.Enabled or not BeesESP.Enabled then
			if BeesNotify and BeesNotify.Object then BeesNotify.Object.Visible = false end
			if BeesBackground and BeesBackground.Object then BeesBackground.Object.Visible = false end
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = false end
		else
			if BeesColor and BeesColor.Object then BeesColor.Object.Visible = BeesBackground.Enabled end
		end

		if not ESPToggle.Enabled or not BeehiveESP.Enabled then
			if ShowOtherBeehives and ShowOtherBeehives.Object then ShowOtherBeehives.Object.Visible = false end
			if BeehiveBackground and BeehiveBackground.Object then BeehiveBackground.Object.Visible = false end
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = false end
		else
			if BeehiveColor and BeehiveColor.Object then BeehiveColor.Object.Visible = BeehiveBackground.Enabled end
		end

		if AutoDeposit and not AutoDeposit.Enabled then
			if DepositDelay and DepositDelay.Object then DepositDelay.Object.Visible = false end
			if DepositDelaySlider and DepositDelaySlider.Object then DepositDelaySlider.Object.Visible = false end
			if DepositRange and DepositRange.Object then DepositRange.Object.Visible = false end
		end

		if DepositDelaySlider and DepositDelaySlider.Object then
			DepositDelaySlider.Object.Visible = (AutoDeposit.Enabled and DepositDelay.Enabled)
		end
	end)
end)

run(function()
    local GeneratorESP
    DiamondToggle = nil
    EmeraldToggle = nil
    TeamGenToggle = nil
    ShowOwnTeamGen = nil
    ShowEnemyTeamGen = nil
    local UIStyle
    local CompactDiamondToggle
    local CompactEmeraldToggle
    local CollectionService = collectionService
    local RunService = runService
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local CompactFolder = Instance.new('Folder')
    CompactFolder.Parent = vape.gui
    local teamColors = {
        [1] = {name = "Blue",   color = Color3.fromRGB(85, 150, 255)},
        [2] = {name = "Orange", color = Color3.fromRGB(255, 150, 50)},
        [3] = {name = "Pink",   color = Color3.fromRGB(255, 100, 200)},
        [4] = {name = "Yellow", color = Color3.fromRGB(255, 255, 50)}
    }

    local generatorTypes = {
        diamond = {
            keywords = {'diamond'},
            color = Color3.fromRGB(85, 200, 255),
            icon = 'diamond',
            displayName = 'Diamond',
            isTeamGen = false
        },
        emerald = {
            keywords = {'emerald'},
            color = Color3.fromRGB(0, 255, 100),
            icon = 'emerald',
            displayName = 'Emerald',
            isTeamGen = false
        }
    }

    local compactUI = Instance.new('ScreenGui')
    compactUI.Name = 'GeneratorCompactUI'
    compactUI.Parent = vape.gui
    compactUI.Enabled = false
    compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    compactUI.DisplayOrder = 10
    compactUI.ResetOnSpawn = false

    local mainFrame = Instance.new('Frame')
    mainFrame.Name = 'MainFrame'
    mainFrame.Parent = compactUI
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Position = UDim2.new(1, -8, 1, -8)
    mainFrame.Size = UDim2.new(0, 120, 0, 100)
    mainFrame.AnchorPoint = Vector2.new(1, 1)

    local uicorner = Instance.new('UICorner')
    uicorner.CornerRadius = UDim.new(0, 8)
    uicorner.Parent = mainFrame

    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Parent = mainFrame
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.Text = "GEN ESP"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextStrokeTransparency = 0.5
    title.TextStrokeColor3 = Color3.new(0, 0, 0)

    local diamondFrame = Instance.new('Frame')
    diamondFrame.Name = 'DiamondFrame'
    diamondFrame.Parent = mainFrame
    diamondFrame.BackgroundTransparency = 1
    diamondFrame.Size = UDim2.new(1, -20, 0, 25)
    diamondFrame.Position = UDim2.new(0, 10, 0, 35)

    local diamondIcon = Instance.new('ImageLabel')
    diamondIcon.Name = 'DiamondIcon'
    diamondIcon.Parent = diamondFrame
    diamondIcon.BackgroundTransparency = 1
    diamondIcon.Size = UDim2.new(0, 18, 0, 18)
    diamondIcon.Position = UDim2.new(0, 0, 0.5, -9)
    diamondIcon.Image = bedwars.getIcon({itemType = 'diamond'}, true)

    local diamondTimer = Instance.new('TextLabel')
    diamondTimer.Name = 'DiamondTimer'
    diamondTimer.Parent = diamondFrame
    diamondTimer.BackgroundTransparency = 1
    diamondTimer.Size = UDim2.new(1, -25, 1, 0)
    diamondTimer.Position = UDim2.new(0, 25, 0, 0)
    diamondTimer.Text = "00"
    diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
    diamondTimer.TextSize = 18
    diamondTimer.Font = Enum.Font.GothamBold
    diamondTimer.TextXAlignment = Enum.TextXAlignment.Left

    local emeraldFrame = Instance.new('Frame')
    emeraldFrame.Name = 'EmeraldFrame'
    emeraldFrame.Parent = mainFrame
    emeraldFrame.BackgroundTransparency = 1
    emeraldFrame.Size = UDim2.new(1, -20, 0, 25)
    emeraldFrame.Position = UDim2.new(0, 10, 0, 65)

    local emeraldIcon = Instance.new('ImageLabel')
    emeraldIcon.Name = 'EmeraldIcon'
    emeraldIcon.Parent = emeraldFrame
    emeraldIcon.BackgroundTransparency = 1
    emeraldIcon.Size = UDim2.new(0, 18, 0, 18)
    emeraldIcon.Position = UDim2.new(0, 0, 0.5, -9)
    emeraldIcon.Image = bedwars.getIcon({itemType = 'emerald'}, true)

    local emeraldTimer = Instance.new('TextLabel')
    emeraldTimer.Name = 'EmeraldTimer'
    emeraldTimer.Parent = emeraldFrame
    emeraldTimer.BackgroundTransparency = 1
    emeraldTimer.Size = UDim2.new(1, -25, 1, 0)
    emeraldTimer.Position = UDim2.new(0, 25, 0, 0)
    emeraldTimer.Text = "00"
    emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
    emeraldTimer.TextSize = 18
    emeraldTimer.Font = Enum.Font.GothamBold
    emeraldTimer.TextXAlignment = Enum.TextXAlignment.Left

    local diamondTimes = {}
    local emeraldTimes = {}

    local function getMyTeamId()
        local myTeam = lplr:GetAttribute('Team')
        if myTeam == nil then return nil end
        return tonumber(myTeam)
    end

    local function getGeneratorTeamId(generatorId)
        local teamNum = string.match(generatorId, "^(%d+)_generator")
        if teamNum then
            return tonumber(teamNum)
        end
        return nil
    end

    local function isTeamGenerator(generatorId)
        return string.match(generatorId, "^%d+_generator") ~= nil
    end

    local function getGeneratorType(generatorId)
        local idLower = string.lower(generatorId)

        if isTeamGenerator(generatorId) then
            return 'teamgen', {
                color = Color3.fromRGB(200, 200, 200),
                icon = 'iron',
                displayName = 'Team Gen',
                isTeamGen = true
            }
        end

        for genType, config in pairs(generatorTypes) do
            for _, keyword in ipairs(config.keywords) do
                if idLower:find(keyword) then
                    return genType, config
                end
            end
        end
        return nil, nil
    end

    local function isGeneratorEnabled(genType, teamId)
        if genType == 'diamond' then
            return DiamondToggle.Enabled
        elseif genType == 'emerald' then
            return EmeraldToggle.Enabled
        elseif genType == 'teamgen' then
            if not TeamGenToggle.Enabled then return false end
            local myTeamId = getMyTeamId()
            if not myTeamId or not teamId then return TeamGenToggle.Enabled end
            if teamId == myTeamId then
                return ShowOwnTeamGen.Enabled
            else
                return ShowEnemyTeamGen.Enabled
            end
        end
        return false
    end

    local function getProperIcon(iconType)
        local icon = bedwars.getIcon({itemType = iconType}, true)
        if not icon or icon == "" then return nil end
        return icon
    end

    local function getTierText(generatorAdornee)
        if not generatorAdornee then return nil end
        if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
        local reactTree = generatorAdornee:FindFirstChild('RoactTree')
        if not reactTree then return nil end
        local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
        if not teamApp then return nil end
        local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
        if globalGen then
            for _, child in pairs(globalGen:GetDescendants()) do
                if child:IsA('TextLabel') then
                    local text = child.Text
                    if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
                        return child
                    end
                end
            end
        end
        local teamGenMain = teamApp:FindFirstChild('TeamGenMain')
        if teamGenMain then
            for _, child in pairs(teamGenMain:GetDescendants()) do
                if child:IsA('TextLabel') then
                    local text = child.Text
                    if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
                        return child
                    end
                end
            end
        end
        return nil
    end

    local function extractTierLevel(tierText)
        if not tierText or tierText == "" then return "0" end
        if tierText == "0" then return "0" end
        local tierMatch = tierText:match("Tier%s+([IVX]+)")
        if tierMatch then return tierMatch end
        if tierText:match("^[IVX]+$") then return tierText end
        local numTier = tierText:match("Tier%s+(%d+)")
        if numTier then
            local num = tonumber(numTier)
            if num == 0 then return "0"
            elseif num == 1 then return "I"
            elseif num == 2 then return "II"
            elseif num == 3 then return "III"
            end
        end
        return "0"
    end

    local function getCountdownText(generatorAdornee)
        if not generatorAdornee then return nil end
        if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
        local reactTree = generatorAdornee:FindFirstChild('RoactTree')
        if not reactTree then return nil end
        local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
        if not teamApp then return nil end
        local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
        if not globalGen then return nil end
        local countdown = globalGen:FindFirstChild('Countdown')
        if not countdown then return nil end
        local textLabel = countdown:FindFirstChild('Text')
        if not textLabel then
            if countdown:IsA('TextLabel') then return countdown end
            return nil
        end
        return textLabel
    end

    local function extractSecondsFromText(text)
        if not text or text == "" then return 0 end
        local seconds = text:match("%[(%d+)%]")
        if seconds then return tonumber(seconds) or 0 end
        local justNumber = text:match("(%d+)")
        if justNumber then return tonumber(justNumber) or 0 end
        return 0
    end

    local function getResourceCount(position, resourceType)
        local count = 0
        for _, drop in pairs(CollectionService:GetTagged('ItemDrop')) do
            if drop:FindFirstChild('Handle') then
                local dropName = drop.Name:lower()
                if dropName:find(resourceType) then
                    local dist = (drop.Handle.Position - position).Magnitude
                    if dist <= 10 then
                        local amount = drop:GetAttribute('Amount') or 1
                        count = count + amount
                    end
                end
            end
        end
        return count
    end

    local CompactGenerators = {}

    local function rebuildCompactGenerators()
        table.clear(CompactGenerators)
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == 'GeneratorAdornee' then
                local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
                if ok and generatorId and type(generatorId) == 'string' and generatorId ~= '' then
                    local genType = getGeneratorType(generatorId)
                    if genType == 'diamond' or genType == 'emerald' then
                        table.insert(CompactGenerators, {obj = obj, genType = genType})
                    end
                end
            end
        end
    end

    local function updateCompactUI()
        if not GeneratorESP.Enabled or UIStyle.Value ~= 'Compact' then
            compactUI.Enabled = false
            return
        end
        compactUI.Enabled = true
        local bestDiamondTime = math.huge
        local bestEmeraldTime = math.huge
        for i = #CompactGenerators, 1, -1 do
            local entry = CompactGenerators[i]
            if not entry.obj or not entry.obj.Parent then
                table.remove(CompactGenerators, i)
                continue
            end
            local countdownText = getCountdownText(entry.obj)
            if countdownText and countdownText.Text then
                local timeLeft = extractSecondsFromText(countdownText.Text)
                if entry.genType == 'diamond' and timeLeft > 0 and timeLeft < bestDiamondTime then
                    bestDiamondTime = timeLeft
                elseif entry.genType == 'emerald' and timeLeft > 0 and timeLeft < bestEmeraldTime then
                    bestEmeraldTime = timeLeft
                end
            end
        end
        local showDiamond = CompactDiamondToggle and CompactDiamondToggle.Enabled
        local showEmerald = CompactEmeraldToggle and CompactEmeraldToggle.Enabled

        if not showDiamond and not showEmerald then
            compactUI.Enabled = false
            return
        end

        diamondFrame.Visible = showDiamond
        emeraldFrame.Visible = showEmerald

        if showDiamond then
            diamondFrame.Position = UDim2.new(0, 10, 0, 35)
        end
        if showEmerald then
            emeraldFrame.Position = UDim2.new(0, 10, 0, showDiamond and 65 or 35)
        end

        diamondTimes[1] = bestDiamondTime ~= math.huge and bestDiamondTime or 0
        emeraldTimes[1] = bestEmeraldTime ~= math.huge and bestEmeraldTime or 0
        if bestDiamondTime == math.huge then
            diamondTimer.Text = "00"
        else
            diamondTimer.Text = string.format("%02d", bestDiamondTime)
            if bestDiamondTime <= 5 then
                diamondTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
            elseif bestDiamondTime <= 10 then
                diamondTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
            else
                diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
            end
        end
        if bestEmeraldTime == math.huge then
            emeraldTimer.Text = "00"
        else
            emeraldTimer.Text = string.format("%02d", bestEmeraldTime)
            if bestEmeraldTime <= 5 then
                emeraldTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
            elseif bestEmeraldTime <= 10 then
                emeraldTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
            else
                emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
            end
        end
    end

    local function clearAllESP()
        Folder:ClearAllChildren()
        table.clear(Reference)
        compactUI.Enabled = false
    end

    local function createESP(generatorAdornee, genType, config, position, teamId)
        if not isGeneratorEnabled(genType, teamId) then return end
        if Reference[generatorAdornee] then return end

        if UIStyle.Value == 'Compact' then
            Reference[generatorAdornee] = {
                genType = genType,
                position = position,
                teamId = teamId,
                isTeamGen = config.isTeamGen
            }
            return
        end

        local displayColor = config.color
        local teamName = nil
        if config.isTeamGen and teamId and teamColors[teamId] then
            displayColor = teamColors[teamId].color
            teamName = teamColors[teamId].name
        end

        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'generator-esp-' .. genType
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = generatorAdornee

        if config.isTeamGen then
            billboard.Size = UDim2.fromOffset(180, 55)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
        else
            billboard.Size = UDim2.fromOffset(80, 30)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
        end

        local blur = addBlur(billboard)
        blur.Visible = true

        if config.isTeamGen and teamName then
            local dot = Instance.new('Frame')
            dot.Name = 'TeamDot'
            dot.Parent = billboard
            dot.Size = UDim2.fromOffset(8, 8)
            dot.Position = UDim2.new(0, 10, 0, 5)
            dot.BackgroundColor3 = displayColor
            dot.BorderSizePixel = 0
            local dotCorner = Instance.new('UICorner')
            dotCorner.CornerRadius = UDim.new(1, 0)
            dotCorner.Parent = dot

            local teamLabel = Instance.new('TextLabel')
            teamLabel.Name = 'TeamLabel'
            teamLabel.Parent = billboard
            teamLabel.BackgroundTransparency = 1
            teamLabel.Size = UDim2.new(1, 0, 0, 18)
            teamLabel.Position = UDim2.new(0, 0, 0, 0)
            teamLabel.Text = teamName
            teamLabel.TextColor3 = displayColor
            teamLabel.TextSize = 13
            teamLabel.Font = Enum.Font.GothamBold
            teamLabel.TextStrokeTransparency = 0.4
            teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            teamLabel.TextXAlignment = Enum.TextXAlignment.Center
        end

        local frame = Instance.new('Frame')
        frame.Size = config.isTeamGen and UDim2.new(1, 0, 0, 35) or UDim2.fromScale(1, 1)
        frame.Position = config.isTeamGen and UDim2.new(0, 0, 0, 20) or UDim2.new(0, 0, 0, 0)
        frame.BackgroundColor3 = Color3.new(0, 0, 0)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        if config.isTeamGen and teamId and teamColors[teamId] then
            local stripe = Instance.new('Frame')
            stripe.Name = 'TeamStripe'
            stripe.Parent = frame
            stripe.Size = UDim2.new(0, 3, 1, 0)
            stripe.Position = UDim2.new(0, 0, 0, 0)
            stripe.BackgroundColor3 = displayColor
            stripe.BorderSizePixel = 0
            local stripeCorner = Instance.new('UICorner')
            stripeCorner.CornerRadius = UDim.new(0, 3)
            stripeCorner.Parent = stripe
        end

        local uicorner2 = Instance.new('UICorner')
        uicorner2.CornerRadius = UDim.new(0, 6)
        uicorner2.Parent = frame

        if config.isTeamGen then
            local tierLabel = Instance.new('TextLabel')
            tierLabel.Name = 'Tier'
            tierLabel.Size = UDim2.new(0, 25, 1, 0)
            tierLabel.Position = UDim2.new(0, 8, 0, 0)
            tierLabel.BackgroundTransparency = 1
            tierLabel.Text = "0"
            tierLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            tierLabel.TextSize = 16
            tierLabel.Font = Enum.Font.GothamBold
            tierLabel.TextStrokeTransparency = 0.5
            tierLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            tierLabel.Parent = frame

            local resources = {
                {name = 'iron',    color = Color3.fromRGB(200, 200, 200), icon = 'iron',    xOffset = 35},
                {name = 'diamond', color = Color3.fromRGB(85, 200, 255),  icon = 'diamond', xOffset = 85},
                {name = 'emerald', color = Color3.fromRGB(0, 255, 100),   icon = 'emerald', xOffset = 135}
            }

            local resourceLabels = {}
            for _, resource in ipairs(resources) do
                local iconImage = getProperIcon(resource.icon)
                if iconImage then
                    local image = Instance.new('ImageLabel')
                    image.Size = UDim2.fromOffset(18, 18)
                    image.Position = UDim2.new(0, resource.xOffset, 0.5, 0)
                    image.AnchorPoint = Vector2.new(0, 0.5)
                    image.BackgroundTransparency = 1
                    image.Image = iconImage
                    image.Parent = frame
                end
                local countLabel = Instance.new('TextLabel')
                countLabel.Name = resource.name .. '_count'
                countLabel.Size = UDim2.new(0, 25, 1, 0)
                countLabel.Position = UDim2.new(0, resource.xOffset + 20, 0, 0)
                countLabel.BackgroundTransparency = 1
                countLabel.Text = "0"
                countLabel.TextColor3 = resource.color
                countLabel.TextSize = 16
                countLabel.Font = Enum.Font.GothamBold
                countLabel.TextStrokeTransparency = 0.5
                countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                countLabel.TextXAlignment = Enum.TextXAlignment.Left
                countLabel.Parent = frame
                resourceLabels[resource.name] = countLabel
            end

            Reference[generatorAdornee] = {
                billboard = billboard,
                tierLabel = tierLabel,
                ironLabel = resourceLabels.iron,
                diamondLabel = resourceLabels.diamond,
                emeraldLabel = resourceLabels.emerald,
                genType = genType,
                position = position,
                teamId = teamId,
                isTeamGen = true
            }
        else
            local iconImage = getProperIcon(config.icon)
            if iconImage then
                local image = Instance.new('ImageLabel')
                image.Size = UDim2.fromOffset(20, 20)
                image.Position = UDim2.new(0, 5, 0.5, 0)
                image.AnchorPoint = Vector2.new(0, 0.5)
                image.BackgroundTransparency = 1
                image.Image = iconImage
                image.Parent = frame
            end
            local timerLabel = Instance.new('TextLabel')
            timerLabel.Name = 'Timer'
            timerLabel.Size = UDim2.new(0, 30, 1, 0)
            timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
            timerLabel.AnchorPoint = Vector2.new(0.5, 0)
            timerLabel.BackgroundTransparency = 1
            timerLabel.Text = "00"
            timerLabel.TextColor3 = displayColor
            timerLabel.TextSize = 18
            timerLabel.Font = Enum.Font.GothamBold
            timerLabel.TextStrokeTransparency = 0.5
            timerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            timerLabel.Parent = frame
            local amountLabel = Instance.new('TextLabel')
            amountLabel.Name = 'Amount'
            amountLabel.Size = UDim2.new(0, 20, 1, 0)
            amountLabel.Position = UDim2.new(1, -20, 0, 0)
            amountLabel.BackgroundTransparency = 1
            amountLabel.Text = "0"
            amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            amountLabel.TextSize = 16
            amountLabel.Font = Enum.Font.GothamBold
            amountLabel.TextStrokeTransparency = 0.5
            amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            amountLabel.Parent = frame
            Reference[generatorAdornee] = {
                billboard = billboard,
                timerLabel = timerLabel,
                amountLabel = amountLabel,
                genType = genType,
                position = position,
                teamId = teamId,
                isTeamGen = false
            }
        end
    end

    local function updateESP(generatorAdornee)
        local ref = Reference[generatorAdornee]
        if not ref then return end
        if UIStyle.Value == 'Compact' then return end

        if ref.isTeamGen then
            if ref.tierLabel then
                local tierTextLabel = getTierText(generatorAdornee)
                if tierTextLabel and tierTextLabel.Text then
                    ref.tierLabel.Text = extractTierLevel(tierTextLabel.Text)
                else
                    ref.tierLabel.Text = "0"
                end
            end
            if ref.ironLabel then
                ref.ironLabel.Text = tostring(getResourceCount(ref.position, 'iron'))
            end
            if ref.diamondLabel then
                ref.diamondLabel.Text = tostring(getResourceCount(ref.position, 'diamond'))
            end
            if ref.emeraldLabel then
                ref.emeraldLabel.Text = tostring(getResourceCount(ref.position, 'emerald'))
            end
        else
            local countdownText = getCountdownText(generatorAdornee)
            if countdownText and countdownText.Text then
                local timeLeft = extractSecondsFromText(countdownText.Text)
                if ref.timerLabel then
                    ref.timerLabel.Text = string.format("%02d", timeLeft)
                    if timeLeft <= 5 then
                        ref.timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                    elseif timeLeft <= 10 then
                        ref.timerLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                    else
                        ref.timerLabel.TextColor3 = generatorTypes[ref.genType].color
                    end
                end
            else
                if ref.timerLabel then
                    ref.timerLabel.Text = "00"
                    ref.timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                end
            end
            if ref.amountLabel then
                ref.amountLabel.Text = tostring(getResourceCount(ref.position, ref.genType))
            end
        end
    end

    local function processGeneratorAdornee(obj)
        if obj.Name ~= 'GeneratorAdornee' then return end
        local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
        if not ok then return end
        if generatorId == nil then return end
        if type(generatorId) ~= 'string' then return end
        if generatorId == '' then return end

        local position = obj:GetPivot().Position
        local genType, config = getGeneratorType(generatorId)
        if not genType or not config then return end

        local teamId = getGeneratorTeamId(generatorId)
        if isGeneratorEnabled(genType, teamId) then
            createESP(obj, genType, config, position, teamId)
        end
    end

    local function findAllGenerators()
        for _, obj in pairs(workspace:GetDescendants()) do
            pcall(processGeneratorAdornee, obj)
        end
    end

    local function refreshESP()
        clearAllESP()
        if GeneratorESP.Enabled then
            findAllGenerators()
        end
    end

    local updateTimer = 0

    GeneratorESP = vape.Categories.Render:CreateModule({
        Name = 'GeneratorESP',
        Function = function(callback)
            if callback then
                findAllGenerators()
                rebuildCompactGenerators()

                GeneratorESP:Clean(workspace.DescendantAdded:Connect(function(obj)
                    if not GeneratorESP.Enabled then return end
                    task.wait(0.2)
                    pcall(processGeneratorAdornee, obj)
                    if obj.Name == 'GeneratorAdornee' then
                        rebuildCompactGenerators()
                    end
                end))

                GeneratorESP:Clean(runService.Heartbeat:Connect(function(dt)
                    if not GeneratorESP.Enabled then return end
                    updateTimer = updateTimer + dt
                    if updateTimer < 0.2 then return end
                    updateTimer = 0
                    for generatorAdornee, ref in pairs(Reference) do
                        if generatorAdornee and generatorAdornee.Parent then
                            updateESP(generatorAdornee)
                        else
                            if ref.billboard then ref.billboard:Destroy() end
                            Reference[generatorAdornee] = nil
                        end
                    end
                    updateCompactUI()
                end))

                GeneratorESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
                    if not GeneratorESP.Enabled then return end
                    if Reference[obj] then
                        if Reference[obj].billboard then Reference[obj].billboard:Destroy() end
                        Reference[obj] = nil
                    end
                end))
            else
                clearAllESP()
            end
        end,
        Tooltip = 'ESP for generators showing timer and item counts'
    })

    UIStyle = GeneratorESP:CreateDropdown({
        Name = 'UI Style',
        List = {'Original', 'Compact'},
        Default = 'Original',
        Function = function(val)
            local isOriginal = val == 'Original'
            if DiamondToggle then DiamondToggle.Object.Visible = isOriginal end
            if EmeraldToggle then EmeraldToggle.Object.Visible = isOriginal end
            if TeamGenToggle then TeamGenToggle.Object.Visible = isOriginal end
            if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
            if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
            if CompactDiamondToggle then CompactDiamondToggle.Object.Visible = not isOriginal end
            if CompactEmeraldToggle then CompactEmeraldToggle.Object.Visible = not isOriginal end
            refreshESP()
        end,
        Tooltip = 'Choose between original billboard ESP or compact side UI'
    })

    DiamondToggle = GeneratorESP:CreateToggle({
        Name = 'Diamond',
        Function = function() refreshESP() end,
        Default = false,
        Visible = true
    })

    EmeraldToggle = GeneratorESP:CreateToggle({
        Name = 'Emerald',
        Function = function() refreshESP() end,
        Default = false,
        Visible = true
    })

    CompactDiamondToggle = GeneratorESP:CreateToggle({
        Name = 'Compact Diamond',
        Default = false,
        Visible = false,
        Function = function()
            refreshESP()
        end
    })

    CompactEmeraldToggle = GeneratorESP:CreateToggle({
        Name = 'Compact Emerald',
        Default = false,
        Visible = false,
        Function = function()
            refreshESP()
        end
    })

    TeamGenToggle = GeneratorESP:CreateToggle({
        Name = 'Team Generators',
        Function = function(callback)
            if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = callback end
            if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = callback end
            refreshESP()
        end,
        Default = true
    })

    ShowOwnTeamGen = GeneratorESP:CreateToggle({
        Name = 'Show Own Team',
        Function = function() refreshESP() end,
        Default = false,
        Visible = true
    })

    ShowEnemyTeamGen = GeneratorESP:CreateToggle({
        Name = 'Show Enemy Teams',
        Function = function() refreshESP() end,
        Default = true,
        Visible = true
    })
end)

	
run(function()
    local HitregAdjuster
    local Hitreg
    local swordSpeed, swingSpeed, swingRestore

    HitregAdjuster = vape.Categories.Combat:CreateModule({
        Name = 'HitregAdjuster',
        Function = function(callback)
            if callback then
                local swordSwing = bedwars.SyncEvents and bedwars.SyncEvents.SwordSwing
                if not swordSwing then return end

                local connected = pcall(function()
                    swingSpeed = swordSwing:setPriority(150):connect(function(event)
                        swordSpeed = event.attackSpeed
                        event.attackSpeed = 10 / math.max(Hitreg.Value - 1, 1)
                    end)
                    swingRestore = swordSwing:setPriority(300):connect(function(event)
                        event.attackSpeed = swordSpeed
                    end)
                end)
                if not connected then
                    if swingSpeed then swingSpeed:Destroy() end
                    swingSpeed, swingRestore = nil, nil
                    return
                end

                HitregAdjuster:Clean(function()
                    if swingSpeed then swingSpeed:Destroy() end
                    if swingRestore then swingRestore:Destroy() end
                    swingSpeed, swingRestore = nil, nil
                end)
            end
        end,
        Tooltip = 'Swaps the games attack cooldown for a hit count of your own'
    })
    Hitreg = HitregAdjuster:CreateSlider({
        Name = 'Hitreg',
        Min = 1,
        Max = 36,
        Default = 35,
        Suffix = function(val)
            return val == 1 and 'hit / 10s' or 'hits / 10s'
        end,
        Tooltip = 'Spacing your manual and autoclicker hits fire at, 35 is the killaura spacing'
    })
end)

run(function()
    local AutoZeno
    local Targets
    local TargetMode
    local Limit
    local AutoShockWave
    local ShockwaveRange
    local UseStrike
    local UseStorm
    local Range
    local Delay

    local function getAttackData()
    	if Limit.Enabled then
    		local tool = (store.hand.tool and store.hand.tool.Name:find('wizard_staff')) and store.hand.tool or nil
    		return tool, tool and getHotbar(tool) or nil, tool and (tonumber(tool.Name:sub(#tool.Name, #tool.Name)) or 1) or nil
    	end

    	for i, v in store.inventory.inventory.items do
    		if v.itemType:find('wizard_staff') then
    			switchItem(v, 0)
    			return v, i, tonumber(v.itemType:sub(#v.itemType, #v.itemType)) or 1
    		end
    	end

    	return
    end

    AutoZeno = vape.Categories.Kits:CreateModule({
    	Name = 'Auto Zeno',
    	Function = function(call)
    		if call then
    			repeat
    				if entitylib.isAlive then
    					local staff, __, level = getAttackData()

    					if staff then
    						local localPosition = entitylib.character.RootPart.Position
    						local ent = entitylib.EntityPosition({
    							Origin = localPosition,
    							Range = (Range.Value < 6 and AutoShockWave.Enabled and 7) or Range.Value,
    							Part = 'RootPart',
    							Players = Targets.Players.Enabled,
    							NPCs = Targets.NPCs.Enabled,
    							Sort = sortmethods[TargetMode.Value],
    						})

    						if ent then
    							if AutoShockWave.Enabled and level > 2 then
    								if
    									bedwars.AbilityController:canUseAbility('SHOCKWAVE')
    									and (localPosition - ent.RootPart.Position).Magnitude <= ShockwaveRange.Value
    								then
    									bedwars.AbilityController:useAbility('SHOCKWAVE', newproxy(true), {
    										target = CFrame.lookAt(localPosition, ent.RootPart.Position).LookVector,
    									})
    									task.wait(Delay.Value)
    								end
    							end

    							if UseStrike.Enabled and bedwars.AbilityController:canUseAbility('LIGHTNING_STRIKE') then
    								bedwars.AbilityController:useAbility('LIGHTNING_STRIKE', newproxy(true), {
    									target = ent.RootPart.Position + ((ent.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing())),
    								})
    								task.wait(Delay.Value)
    							end

    							if UseStorm.Enabled and level > 1 then
    								if bedwars.AbilityController:canUseAbility('LIGHTNING_STORM') then
    									bedwars.AbilityController:useAbility('LIGHTNING_STORM', newproxy(true), {
    										target = ent.RootPart.Position + ((ent.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing())),
    									})
    									task.wait(Delay.Value)
    								end
    							end
    						end
    					end
    				end
    				task.wait(0.1)
    			until not AutoZeno.Enabled
    		end
    	end,
    	Tooltip = 'Automatically uses zeno\'s staff'
    })

    Targets = AutoZeno:CreateTargets({
    	Players = true,
    	NPCs = false,
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
    	if not table.find(methods, i) then
    		table.insert(methods, i)
    	end
    end
    TargetMode = AutoZeno:CreateDropdown({
    	Name = 'Target Mode',
    	List = methods,
    	Default = 'Distance'
    })
    Limit = AutoZeno:CreateToggle({
    	Name = 'Limit to item',
    	Default = true
    })
    UseStrike = AutoZeno:CreateToggle({
    	Name = 'Use Lightning Strike',
    	Default = true
    })
    UseStorm = AutoZeno:CreateToggle({Name = 'Use Lightning Storm'})
    AutoShockWave = AutoZeno:CreateToggle({
    	Name = 'Auto Shockwave',
    	Function = function(call)
    		pcall(function()
    			ShockwaveRange.Object.Visible = call
    		end)
    	end,
    	Tooltip = 'Automatically uses the shockwave ability when a target is near',
    })
    ShockwaveRange = AutoZeno:CreateSlider({
    	Name = 'Shockwave Range',
    	Visible = false,
    	Darker = true,
    	Min = 1,
    	Max = 12,
    	Suffix = function(val)
    		return val > 1 and 'studs' or 'stud'
    	end,
    	Decimal = 5,
    	Default = 12
    })
    Range = AutoZeno:CreateSlider({
    	Name = 'Range',
    	Min = 1,
    	Max = 60,
    	Default = 35,
    	Suffix = function(val)
    		return val > 1 and 'studs' or 'stud'
    	end,
    	Decimal = 5
    })
    Delay = AutoZeno:CreateSlider({
    	Name = 'Delay',
    	Min = 0,
    	Max = 10,
    	Default = 0.5,
    	Decimal = 5,
    	Suffix = function(val)
    		return val > 1 and 'secs' or 'sec'
    	end
    })
end)

local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local swordEffectFunction, swordEffectController
	local scytheAnimationFunction, scytheAnimationController
	local animationHooksInstalled = false
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta or not meta.sword then return false end

		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'KillauraFavorite',
		Function = function(callback)
			if callback then
				local nextServerAttack = 0
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					-- Save the live controller upvalues.  Restoring to bedwars.Knit is not
					-- reliable: the game can use a different controller after an update.
					swordEffectFunction = oldSwing or bedwars.SwordController.playSwordEffect
					scytheAnimationFunction = bedwars.ScytheController.playLocalAnimation
					local _, currentSwordEffectController = debug.getupvalue(swordEffectFunction, 6)
					local _, currentScytheAnimationController = debug.getupvalue(scytheAnimationFunction, 3)
					swordEffectController = currentSwordEffectController
					scytheAnimationController = currentScytheAnimationController
					debug.setupvalue(swordEffectFunction, 6, fake)
					debug.setupvalue(scytheAnimationFunction, 3, fake)
					animationHooksInstalled = true

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								if not Killaura.Enabled then break end
								local delta = (v.RootPart.Position - selfpos)
								local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										-- This affects only the local visual effect.  Keep it at the
										-- normal 34-per-10-second cadence so it cannot burst/double.
										local swingDelay = math.max(
											meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0,
											10 / 34
										)
										AnimDelay = tick() + swingDelay
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end

								local actualRoot = v.Character and v.Character.PrimaryPart
								local now = tick()
								local attackCooldown = math.max(tonumber(meta.sword.attackSpeed) or 0, 10 / 34)
								if actualRoot and now >= nextServerAttack then
									nextServerAttack = now + attackCooldown
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait(1 / math.clamp(UpdateRate.Value, 1, 120))
				until not Killaura.Enabled
			else
				-- Stop the running attack/animation tasks before restoring normal input.
				Attacking = false
				if AnimTween then
					AnimTween:Cancel()
				end
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				if animationHooksInstalled and swordEffectFunction then
					pcall(debug.setupvalue, swordEffectFunction, 6, swordEffectController)
				end
				if animationHooksInstalled and scytheAnimationFunction then
					pcall(debug.setupvalue, scytheAnimationFunction, 3, scytheAnimationController)
				end
				swordEffectFunction, swordEffectController = nil, nil
				scytheAnimationFunction, scytheAnimationController = nil, nil
				animationHooksInstalled = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)

run(function()
	local FOV
	local Value
	local old, old2
	
	FOV = vape.Categories.World:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				old = bedwars.FovController.setFOV
				old2 = bedwars.FovController.getFOV
				bedwars.FovController.setFOV = function(self) 
					return old(self, Value.Value) 
				end
				bedwars.FovController.getFOV = function() 
					return Value.Value 
				end
			else
				bedwars.FovController.setFOV = old
				bedwars.FovController.getFOV = old2
			end
			
			bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)

run(function()
    local LGKillaura, Targets, Sort, Range, UpdateRate, AngleSlider, MaxTargets
    local Mouse, Swing, GUI, BoxColor, ParticleTexture, ParticleColor1, ParticleColor2
    local ParticleSize, Face, Animation, AnimationMode, AnimationSpeed, AnimationTween
    local Limit, LegitAura, Sync
    local swordEffectFunction, swordEffectController
    local scytheAnimationFunction, scytheAnimationController
    local animationHooksInstalled = false
    local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
    local AttackRemote = {FireServer = function() end}
 
    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
    end)
 
    local function calculateRange(range)
        return math.clamp(range, 1, 20) * 1.5
    end
 
    local function performAttack(sword, meta, target, selfpos)
        local delta = (target.RootPart.Position - selfpos)
        local dir = CFrame.lookAt(selfpos, target.RootPart.Position).LookVector
        local pos = selfpos + dir * math.max(delta.Magnitude - 2, 0)
 
        local attackData = {
            weapon = sword.tool,
            chargedAttack = {
                chargeRatio = 1
            },
            entityInstance = target.Character,
            validate = {
                raycast = {
                    cameraPosition = {value = pos},
                    cursorDirection = {value = dir}
                },
                targetPosition = {value = target.RootPart.Position},
                selfPosition = {value = pos}
            }
        }
 
        bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
        store.attackReach = delta.Magnitude
        store.attackReachUpdate = tick() + 1
 
        for i = 1, 1 do
            AttackRemote:FireServer(attackData)
            task.wait(0.21)
        end
    end
 
    local function getAttackData()
        if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) then 
            return false 
        end
 
        if GUI.Enabled and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then 
            return false 
        end
 
        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then 
            return false 
        end
 
        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled and (store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid) then 
            return false 
        end
 
        if LegitAura.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.1 then 
            return false 
        end
 
        return sword, meta
    end
 
    local function playAttackAnimation(meta)
        if not Swing.Enabled and AnimDelay <= tick() and not LegitAura.Enabled then
            AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or (Sync.Enabled and 0.24 or 0.14))
            bedwars.SwordController:playSwordEffect(meta, 0)
 
            if meta.displayName:find(' Scythe') then
                bedwars.ScytheController:playLocalAnimation()
            end
        end
    end
 
    local function getTargets(range)
        return entitylib.AllPosition({
            Range = calculateRange(range),
            Wallcheck = Targets.Walls.Enabled or nil,
            Part = 'RootPart',
            Players = Targets.Players.Enabled,
            NPCs = Targets.NPCs.Enabled,
            Limit = MaxTargets.Value,
            Sort = sortmethods[Sort.Value]
        })
    end
 
    LGKillaura = vape.Categories.Utility:CreateModule({
        Name = 'GroveEsp',
        Function = function(callback)
            if callback then
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
                    end)
                end
 
                if Animation.Enabled then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    if not Attacking then
                                        bedwars.ViewmodelController:playAnimation(select(2, ...))
                                    end
                                end
                            }
                        }
                    }
                    swordEffectFunction = oldSwing or bedwars.SwordController.playSwordEffect
                    scytheAnimationFunction = bedwars.ScytheController.playLocalAnimation
                    local _, currentSwordEffectController = debug.getupvalue(swordEffectFunction, 6)
                    local _, currentScytheAnimationController = debug.getupvalue(scytheAnimationFunction, 3)
                    swordEffectController = currentSwordEffectController
                    scytheAnimationController = currentScytheAnimationController
                    debug.setupvalue(swordEffectFunction, 6, fake)
                    debug.setupvalue(scytheAnimationFunction, 3, fake)
                    animationHooksInstalled = true
 
                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
 
                                local first = not started
                                started = true
 
                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end
 
                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not LGKillaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end
 
                            if not started then
                                task.wait(0.01)
                            end
                        until (not LGKillaura.Enabled) or (not Animation.Enabled)
                    end)
                end
 
                repeat
                    local attacked, sword, meta = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil
 
                    if sword then
                        local plrs = getTargets(Range.Value)
                        if #plrs > 0 then
                            switchItem(sword.tool, 0)
                            local selfpos = entitylib.character.RootPart.Position
                            local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
 
                            for _, v in plrs do
                                local delta = (v.RootPart.Position - selfpos)
                                if delta.Magnitude <= calculateRange(Range.Value) then
                                    local flatDelta = delta * Vector3.new(1, 0, 1)
								if flatDelta.Magnitude <= 0 then continue end
								local angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
                                    if angle <= (math.rad(AngleSlider.Value) / 2) then
                                        table.insert(attacked, v)
                                        targetinfo.Targets[v] = tick() + 1
 
                                        if not Attacking then
                                            Attacking = true
                                            store.KillauraTarget = v
                                            playAttackAnimation(meta)
                                        end
 
                                        performAttack(sword, meta, v, selfpos)
                                    end
                                end
                            end
                        end
                    end
 
                    for i, v in Boxes do
                        v.Adornee = attacked[i] and attacked[i].RootPart or nil
                        if v.Adornee then
                            v.Color3 = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
                            v.Transparency = 1 - BoxColor.Opacity
                        end
                    end
 
                    for i, v in Particles do
                        v.Position = attacked[i] and attacked[i].RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                        v.Parent = attacked[i] and gameCamera or nil
                    end
 
                    if Face.Enabled and attacked[1] then
                        local vec = attacked[1].RootPart.Position * Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y, vec.Z))
                    end
 
                    task.wait(0.01)
                until not LGKillaura.Enabled
            else
                store.KillauraTarget = nil
                for _, v in Boxes do
                    v.Adornee = nil
                end
                for _, v in Particles do
                    v.Parent = nil
                end
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = true
                    end)
                end
                if AnimTween then
                    AnimTween:Cancel()
                    AnimTween = nil
                end
                if animationHooksInstalled and swordEffectFunction then
                    pcall(debug.setupvalue, swordEffectFunction, 6, swordEffectController)
                end
                if animationHooksInstalled and scytheAnimationFunction then
                    pcall(debug.setupvalue, scytheAnimationFunction, 3, scytheAnimationController)
                end
                swordEffectFunction, swordEffectController = nil, nil
                scytheAnimationFunction, scytheAnimationController = nil, nil
                animationHooksInstalled = false
                Attacking = false
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                        C0 = armC0
                    })
                    AnimTween:Play()
                end
            end
        end,
        Tooltip = 'Attack players around you\nwithout aiming at them.'
    })
 
    Targets = LGKillaura:CreateTargets({
        Players = true,
        NPCs = true,
        Walls = true
    })
 
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
 
    Range = LGKillaura:CreateSlider({
        Name = 'Attack range',
        Min = 1,
        Max = 20,
        Default = 18,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
 
    AngleSlider = LGKillaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
 
    UpdateRate = LGKillaura:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 120,
        Default = 60,
        Suffix = 'hz'
    })
 
    MaxTargets = LGKillaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 5,
        Default = 5
    })
 
    Sort = LGKillaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
 
    Mouse = LGKillaura:CreateToggle({Name = 'Require mouse down'})
    Swing = LGKillaura:CreateToggle({Name = 'No Swing'})
    GUI = LGKillaura:CreateToggle({Name = 'GUI check'})
 
    LGKillaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
 
    BoxColor = LGKillaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
 
    Face = LGKillaura:CreateToggle({Name = 'Face target'})
 
    Animation = LGKillaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if LGKillaura.Enabled then
                LGKillaura:Toggle()
                LGKillaura:Toggle()
            end
        end
    })
 
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
 
    AnimationMode = LGKillaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
 
    AnimationSpeed = LGKillaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
 
    AnimationTween = LGKillaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
 
    Limit = LGKillaura:CreateToggle({
        Name = 'Limit to items',
        Function = function(callback)
            if inputService.TouchEnabled and LGKillaura.Enabled then
                pcall(function()
                    lplr.PlayerGui.MobileUI['2'].Visible = callback
                end)
            end
        end,
        Tooltip = 'Only attacks when the sword is held'
    })
 
    LegitAura = LGKillaura:CreateToggle({
        Name = 'Swing only',
        Tooltip = 'Only attacks while swinging manually'
    })
 
    Sync = LGKillaura:CreateToggle({
        Name = 'Synced Animation',
        Tooltip = 'Plays animation with hit attempt'
    })
 
end)
