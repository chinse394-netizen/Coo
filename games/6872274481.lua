local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local lightingService = cloneref(game:GetService('Lighting'))
local runService = cloneref(game:GetService('RunService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end

	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function() return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9) end)
		if KnitInit then break end
		task.wait()
	until KnitInit
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local Client = require(replicatedStorage.TS.remotes).default.Client

	bedwars = setmetatable({
		Client = Client,
		CrateItemMeta = debug.getupvalue(Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController').onStart, 3),
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

run(function()
	local Recorder
	local hiddenModules = {}
	local guiVisible

	Recorder = vape.Categories.Utility:CreateModule({
		Name = 'Recorder',
		Function = function(callback)
			if callback then
				table.clear(hiddenModules)
				guiVisible = vape.gui and vape.gui.Enabled
				for _, module in ipairs(vape.Modules) do
					if module ~= Recorder and module.Enabled and module.Category == 'Render' then
						table.insert(hiddenModules, module)
						module:Toggle()
					end
				end
				if vape.gui then vape.gui.Enabled = false end
			else
				for _, module in ipairs(hiddenModules) do
					if module and not module.Enabled then module:Toggle() end
				end
				table.clear(hiddenModules)
				if vape.gui and guiVisible ~= nil then vape.gui.Enabled = guiVisible end
				guiVisible = nil
			end
		end,
		Tooltip = 'Hides cheat visuals while recording.'
	})
end)

for _, v in vape.Modules do
	if v.Category == 'Combat' or v.Category == 'Minigames' then
		vape:Remove(i)
	end
end

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end) end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)

-- This only changes the local client's rendering settings.  Nothing here is sent
-- to the server, and every changed property is restored when the module is off.
run(function()
	local FPSBooster
	local FXCleanup
	local LightingCleanup
	local ReducedShadows
	local UnlockFPSCap
	local originalEffects = {}
	local originalLighting = {}
	local originalGlobalShadows
	local measuredFPS = 0
	local frameCount = 0
	local sampleStarted = os.clock()

	local effectClasses = {
		ParticleEmitter = true,
		Trail = true,
		Beam = true,
		Fire = true,
		Smoke = true,
		Sparkles = true
	}

	local function rememberEffect(effect)
		if effectClasses[effect.ClassName] and originalEffects[effect] == nil then
			originalEffects[effect] = effect.Enabled
		end
	end

	local function setEffectsEnabled(enabled)
		for _, object in workspace:GetDescendants() do
			if effectClasses[object.ClassName] then
				rememberEffect(object)
				object.Enabled = enabled and originalEffects[object] or false
			end
		end
	end

	local function restoreEffects()
		for effect, enabled in originalEffects do
			if effect.Parent then
				effect.Enabled = enabled
			end
		end
		table.clear(originalEffects)
	end

	local function rememberLighting(object)
		if originalLighting[object] == nil then
			originalLighting[object] = object.Enabled
		end
	end

	local function setPostProcessingEnabled(enabled)
		for _, object in lightingService:GetChildren() do
			if object:IsA('PostEffect') then
				rememberLighting(object)
				object.Enabled = enabled and originalLighting[object] or false
			end
		end
	end

	local function restoreLighting()
		for object, enabled in originalLighting do
			if object.Parent then
				object.Enabled = enabled
			end
		end
		table.clear(originalLighting)
	end

	local function applyOptions()
		if not FPSBooster.Enabled then return end
		if FXCleanup.Enabled then setEffectsEnabled(false) else restoreEffects() end
		if LightingCleanup.Enabled then setPostProcessingEnabled(false) else restoreLighting() end
		if ReducedShadows.Enabled then
			if originalGlobalShadows == nil then
				originalGlobalShadows = lightingService.GlobalShadows
			end
			lightingService.GlobalShadows = false
		elseif originalGlobalShadows ~= nil then
			lightingService.GlobalShadows = originalGlobalShadows
			originalGlobalShadows = nil
		end
	end

	FPSBooster = vape.Categories.Utility:CreateModule({
		Name = 'FPS Booster',
		Function = function(enabled)
			if enabled then
				local effects, postEffects = 0, 0
				for _, object in workspace:GetDescendants() do
					if effectClasses[object.ClassName] then effects += 1 end
				end
				for _, object in lightingService:GetChildren() do
					if object:IsA('PostEffect') then postEffects += 1 end
				end
				notif('FPS Booster', ('Scene scan: %d visual effects, %d post-processing effects. Use the options below to disable only what you want.'):format(effects, postEffects), 6)
				FPSBooster:Clean(runService.RenderStepped:Connect(function()
					frameCount += 1
					local elapsed = os.clock() - sampleStarted
					if elapsed >= 1 then
						measuredFPS = math.floor(frameCount / elapsed)
						frameCount = 0
						sampleStarted = os.clock()
					end
				end))
				FPSBooster:Clean(workspace.DescendantAdded:Connect(function(object)
					if FXCleanup.Enabled and effectClasses[object.ClassName] then
						rememberEffect(object)
						object.Enabled = false
					end
				end))
				FPSBooster:Clean(lightingService.ChildAdded:Connect(function(object)
					if LightingCleanup.Enabled and object:IsA('PostEffect') then
						rememberLighting(object)
						object.Enabled = false
					end
				end))
				applyOptions()
			else
				restoreEffects()
				restoreLighting()
				if originalGlobalShadows ~= nil then
					lightingService.GlobalShadows = originalGlobalShadows
					originalGlobalShadows = nil
				end
			end
		end,
		ExtraText = function()
			return measuredFPS > 0 and (measuredFPS .. ' FPS') or 'scanning'
		end,
		Tooltip = 'Local, reversible render optimizations. This cannot create FPS beyond what your device and the game can render.'
	})

	FXCleanup = FPSBooster:CreateToggle({
		Name = 'Disable particles and trails',
		Function = applyOptions,
		Tooltip = 'Disables local particle, trail, beam, fire, smoke, and sparkle effects.'
	})
	LightingCleanup = FPSBooster:CreateToggle({
		Name = 'Disable post-processing',
		Function = applyOptions,
		Tooltip = 'Disables bloom, depth of field, sun rays, and color effects without changing the sky.'
	})
	ReducedShadows = FPSBooster:CreateToggle({
		Name = 'Reduce shadows',
		Function = applyOptions,
		Tooltip = 'Turns off dynamic shadows locally. This is usually less noticeable than texture or sky changes.'
	})
	UnlockFPSCap = FPSBooster:CreateToggle({
		Name = 'Set FPS cap to 300',
		Function = function(enabled)
			if enabled and setfpscap then
				setfpscap(300)
			elseif enabled then
				notif('FPS Booster', 'Your executor does not provide setfpscap.', 5)
			end
		end,
		Tooltip = 'Raises a supported executor FPS cap to 300; it does not guarantee that frame rate.'
	})
end)
	run(function()
	local OGNameTags
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local LP = Players.LocalPlayer
	local FLAME_IMAGE = "rbxassetid://7101948108"
	local BedwarsImageId = require(ReplicatedStorage.TS.image["image-id"]).BedwarsImageId
	local TITLE_STROKE_TRANSP = nil
	local WIN_TEXT_PULL_LEFT = 14
	local ORIGINAL_NAMETAG_SCALE = 1.17
	local TITLE_TEXT_SIZE = 14
	local FLAME_ASPECT_RATIO = 0.8

	local KnitClient
	do
		local ok, knitMod = pcall(function()
			return require(ReplicatedStorage.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
		end)
		if ok then KnitClient = knitMod end
	end

	local function divisionToRankKey(division)
		if division >= 0 and division <= 3 then return "BRONZE_RANK"
		elseif division >= 4 and division <= 7 then return "SILVER_RANK"
		elseif division >= 8 and division <= 11 then return "GOLD_RANK"
		elseif division >= 12 and division <= 15 then return "PLATINUM_RANK"
		elseif division >= 16 and division <= 19 then return "DIAMOND_RANK"
		elseif division >= 20 and division <= 23 then return "EMERALD_RANK"
		elseif division == 24 then return "NIGHTMARE_RANK"
		end
		return "RANDOM_KIT_RENDER"
	end

	local function requestNametagData(callback)
		if not KnitClient or not KnitClient.Controllers or not KnitClient.Controllers.NametagController then return end
		local ctrl = KnitClient.Controllers.NametagController
		local ok, promise = pcall(function()
			return ctrl:requestNametagData(LP)
		end)
		if not ok or not promise then return end
		if typeof(promise) == "table" and promise.andThen then
			promise:andThen(function(data) callback(data) end)
		end
	end

	local function findLocalOriginalNametag(char)
		local head = char:FindFirstChild("Head")
		if not head then return nil end

		local direct = head:FindFirstChild("Nametag")
		if direct and direct:IsA("BillboardGui") then
			return direct
		end

		for _, gui in ipairs(CollectionService:GetTagged("EntityNameTag")) do
			if gui:IsA("BillboardGui") and (gui.Adornee == head or gui:IsDescendantOf(char)) then
				return gui
			end
		end

		return nil
	end

	local function scaleOriginalNametagSlightly(originalGui)
		if not originalGui then return end

		local attrW = originalGui:GetAttribute("BaseSizeW")
		local attrH = originalGui:GetAttribute("BaseSizeH")

		if type(attrW) ~= "number" or type(attrH) ~= "number" then
			originalGui:SetAttribute("BaseSizeW", originalGui.Size.X.Scale)
			originalGui:SetAttribute("BaseSizeH", originalGui.Size.Y.Scale)
			attrW = originalGui.Size.X.Scale
			attrH = originalGui.Size.Y.Scale
		end

		local w = (attrW or originalGui.Size.X.Scale) * ORIGINAL_NAMETAG_SCALE
		local h = (attrH or originalGui.Size.Y.Scale) * ORIGINAL_NAMETAG_SCALE

		originalGui.Size = UDim2.fromScale(w, h)
	end

	local function hideMiddleNameAndLevel(originalGui)
		if not originalGui then return end

		local container = originalGui:FindFirstChild("DisplayNameContainer", true)
		if container and container:IsA("GuiObject") then container.Visible = false end

		local nameLabel = originalGui:FindFirstChild("DisplayName", true)
		if nameLabel and nameLabel:IsA("TextLabel") then nameLabel.Visible = false end

		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("TextLabel") then
				local t = tostring(d.Text or "")
				if t:match("^%(%d+%)") then d.Visible = false end
			end
		end
	end

	local function hideOldWinStreakOnly(originalGui)
		if not originalGui then return end

		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("TextLabel") then
				local name = string.lower(d.Name or "")
				local txt = tostring(d.Text or "")
				if name:find("winstreak") or name:find("streak") or txt:find("🔥") then
					d.Visible = false
				end
			elseif d:IsA("ImageLabel") then
				local name = string.lower(d.Name or "")
				local img = tostring(d.Image or "")
				if name:find("winstreak") or name:find("streak") or img == FLAME_IMAGE then
					d.Visible = false
				end
			end
		end
	end

	local RANK_ICON_IMAGES = {}
	do
		local keys = {
			"BRONZE_RANK","SILVER_RANK","GOLD_RANK","PLATINUM_RANK",
			"DIAMOND_RANK","EMERALD_RANK","NIGHTMARE_RANK",
		}
		for _, k in ipairs(keys) do
			local img = BedwarsImageId[k]
			if type(img) == "string" and img ~= "" then
				RANK_ICON_IMAGES[img] = true
			end
		end
	end

	local function hideOldRankIconOnly(originalGui)
		if not originalGui then return end

		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("ImageLabel") then
				local name = string.lower(d.Name or "")
				local img = tostring(d.Image or "")

				if RANK_ICON_IMAGES[img] then
					d.Visible = false
				elseif name:find("rank") or name:find("division") or name:find("elo") then
					d.Visible = false
				end
			end
		end
	end

	local function fixRoleTextScaling(originalGui)
		if not originalGui then return end

		for _, d in ipairs(originalGui:GetDescendants()) do
			if d:IsA("TextLabel") then
				local name = string.lower(d.Name or "")

				if name:find("title") or name:find("playertitle") or name:find("role") then
					d.TextScaled = true

					if TITLE_STROKE_TRANSP ~= nil then
						d.TextStrokeTransparency = TITLE_STROKE_TRANSP
					end
				end
			end
		end
	end

	local function hideOtherLocalBillboards(char)
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("BillboardGui") and not CollectionService:HasTag(inst, "EntityNameTag") then
				if inst.Name ~= "LocalRankStreakGui" then
					inst.Enabled = false
				end
			end
		end
	end

	local function createHeadLockedGui(head)
		local existing = head:FindFirstChild("LocalRankStreakGui")
		if existing and existing:IsA("BillboardGui") then
			return existing
		end

		local bb = Instance.new("BillboardGui")
		bb.Name = "LocalRankStreakGui"
		bb.Parent = head
		bb.Adornee = head
		bb.AlwaysOnTop = true
		bb.ResetOnSpawn = false
		bb.MaxDistance = 1000

		bb.Size = UDim2.fromScale(7.2, 0.9)
		bb.StudsOffset = Vector3.new(0.44, 1.45, 0)

		local main = Instance.new("Frame")
		main.BackgroundTransparency = 1
		main.Size = UDim2.fromScale(1, 1)
		main.Parent = bb

		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.525, 0.5)
		row.Size = UDim2.fromScale(1, 1)
		row.Parent = main

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)  
		layout.Parent = row

		local rank = Instance.new("ImageLabel")
		rank.Name = "RankIcon"
		rank.BackgroundTransparency = 1
		rank.Size = UDim2.fromScale(0.16, 0.95)
		rank.Parent = row
		local rAspect = Instance.new("UIAspectRatioConstraint")
		rAspect.AspectRatio = 1
		rAspect.Parent = rank

		local winGroup = Instance.new("Frame")
		winGroup.Name = "WinGroup"
		winGroup.BackgroundTransparency = 1
		winGroup.Size = UDim2.fromScale(0.28, 1.05)  
		winGroup.Parent = row

		local flame = Instance.new("ImageLabel")
		flame.Name = "WinFlame"
		flame.BackgroundTransparency = 1
		flame.Image = FLAME_IMAGE
		flame.AnchorPoint = Vector2.new(0, 0.5)
		flame.Position = UDim2.fromScale(0, 0.5)
		flame.Size = UDim2.fromScale(0.24, 1.05)
		flame.Parent = winGroup

		local fAspect = Instance.new("UIAspectRatioConstraint")
		fAspect.AspectRatio = FLAME_ASPECT_RATIO  
		fAspect.Parent = flame

		local num = Instance.new("TextLabel")
		num.Name = "WinStreak"
		num.BackgroundTransparency = 1
		num.Font = Enum.Font.Gotham
		num.TextColor3 = Color3.fromRGB(255, 255, 255)
		num.TextStrokeTransparency = 1
		num.TextXAlignment = Enum.TextXAlignment.Left
		num.TextYAlignment = Enum.TextYAlignment.Center

		num.TextScaled = true

		num.AnchorPoint = Vector2.new(0, 0.5)
		num.Position = UDim2.fromScale(0.28, 0.5) 
		num.Size = UDim2.new(0.72, 0, 0.94, 0)   
		num.Parent = winGroup

		local winLayout = Instance.new("UIListLayout")
		winLayout.FillDirection = Enum.FillDirection.Horizontal
		winLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		winLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		winLayout.Padding = UDim.new(0, 2)
		winLayout.Parent = winGroup

		return bb
	end

	local function forceWinTextStyle(gui) end

	local function updateGui(gui, data)
		if not gui then return end

		local streak = 0
		local division = -1
		if data then
			if data.winstreak ~= nil then streak = tonumber(data.winstreak) or 0 end
			if data.rankDivision ~= nil then division = tonumber(data.rankDivision) or -1 end
		end

		local rank = gui:FindFirstChild("RankIcon", true)
		if rank and rank:IsA("ImageLabel") then
			local key = divisionToRankKey(division)
			rank.Image = BedwarsImageId[key] or ""
		end

		local flame = gui:FindFirstChild("WinFlame", true)
		if flame and flame:IsA("ImageLabel") then
			flame.Image = FLAME_IMAGE
		end

		local num = gui:FindFirstChild("WinStreak", true)
		if num and num:IsA("TextLabel") then
			num.Text = tostring(streak)
		end

		forceWinTextStyle(gui)
	end

	local activeLoop = nil

	local function setup(char)
		local head = char:WaitForChild("Head", 5)
		if not head then return end

		local headGui = createHeadLockedGui(head)

		activeLoop = task.spawn(function()
			while char.Parent and OGNameTags.Enabled do
				task.wait(0.25)

				hideOtherLocalBillboards(char)

				local original = findLocalOriginalNametag(char)
				if original then
					hideMiddleNameAndLevel(original)
					hideOldWinStreakOnly(original)
					hideOldRankIconOnly(original)
				end

				requestNametagData(function(data)
					updateGui(headGui, data)
				end)

				forceWinTextStyle(headGui)
			end
		end)
	end

	local function cleanup()
		if activeLoop then
			task.cancel(activeLoop)
			activeLoop = nil
		end

		if LP.Character then
			local head = LP.Character:FindFirstChild("Head")
			if head then
				local customGui = head:FindFirstChild("LocalRankStreakGui")
				if customGui then
					customGui:Destroy()
				end
			end
		end

		if LP.Character then
			local original = findLocalOriginalNametag(LP.Character)
			if original then
				local attrW = original:GetAttribute("BaseSizeW")
				local attrH = original:GetAttribute("BaseSizeH")
				if attrW and attrH then
					original.Size = UDim2.fromScale(attrW, attrH)
				end

				for _, d in ipairs(original:GetDescendants()) do
					if d:IsA("GuiObject") then
						d.Visible = true
					end
				end
			end
		end
	end

	OGNameTags = vape.Categories.Render:CreateModule({
		Name = 'OGNameTags',
		Function = function(callback)
			if callback then
				if LP.Character then
					setup(LP.Character)
				end

				OGNameTags:Clean(LP.CharacterAdded:Connect(function(char)
					setup(char)
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'Custom nametag with rank icon and winstreak (lobby only)'
	})

	local TitleSizeSlider = OGNameTags:CreateSlider({
		Name = 'Title Scale',
		Min = 1.0,
		Max = 1.5,
		Default = 1.17,
		Decimal = 100,
		Function = function(val)
			ORIGINAL_NAMETAG_SCALE = val
			if LP.Character and OGNameTags.Enabled then
				local original = findLocalOriginalNametag(LP.Character)
				if original then
					scaleOriginalNametagSlightly(original)
					fixRoleTextScaling(original)
				end
			end
		end,
		Tooltip = 'Scale original nametag to make title/role bigger'
	})
end)
run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.Minigames:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)
	
