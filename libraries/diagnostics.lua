--[[
	Diagnostics: lightweight leak / load / sync monitor.

	* One Heartbeat connection while enabled, sampled once per second, no per-frame allocation.
	* Reports: FPS + worst frame, Lua memory, client memory, entity/player count, active connections and
	  enable-threads per module, entitylib internals, remote counters, data send rate and ping.
	* Trend check: warns when memory / connection / thread counts keep rising across the sample window.

	The server-confirmed root position is not readable from the client. What this does measure are the
	things that delay replication of it: long frames (the client sends physics once per frame), the
	outgoing data rate and ping. A "hitch while moving" line is the closest client-side proxy.

	Use:  vape.Libraries.diagnostics.report()   -> prints the latest sample + trend
	      vape.Libraries.diagnostics.count('Name') -> opt-in counter for remote request rate
]]
local vape = shared.vape
if not vape then return end
if vape.Libraries.diagnostics then return vape.Libraries.diagnostics end

local cloneref = cloneref or function(obj) return obj end
local runService = cloneref(game:GetService('RunService'))
local statsService = cloneref(game:GetService('Stats'))
local playersService = cloneref(game:GetService('Players'))
local entitylib = vape.Libraries.entity

local diag = {
	Samples = {},
	Counters = {},
	MaxSamples = 600, -- 10 minutes at 1 Hz
	Verbose = false,
	Running = false
}

local lastCounters = {}
local frames, sumDt, maxDt, hitches = 0, 0, 0, 0
local lastSample, lastPos = os.clock(), nil

function diag.count(name)
	diag.Counters[name] = (diag.Counters[name] or 0) + 1
end

local function countKeys(tbl)
	local n = 0
	for _ in tbl do n += 1 end
	return n
end

local function safe(func)
	local ok, res = pcall(func)
	return ok and res or nil
end

local function isAura(name)
	return name:sub(1, 8) == 'Killaura' or name == 'SilentAura' or name == 'Projectile Aimbot'
end

local function sample(now)
	local elapsed = math.max(now - lastSample, 1e-3)
	lastSample = now

	local moduleConns, moduleThreads, perModule, auras = 0, 0, {}, {}
	for name, mod in vape.Modules do
		if mod.Enabled then
			local conns = mod.Connections and #mod.Connections or 0
			local threads = mod.Threads and countKeys(mod.Threads) or 0
			moduleConns += conns
			moduleThreads += threads
			if conns > 0 or threads > 0 then
				perModule[name] = {conns, threads}
			end
			if isAura(name) then table.insert(auras, name) end
		end
	end

	local entConns = 0
	for _, ent in entitylib.List do
		entConns += #ent.Connections
	end

	local remotes = {}
	for name, total in diag.Counters do
		remotes[name] = (total - (lastCounters[name] or 0)) / elapsed
		lastCounters[name] = total
	end

	local pos = entitylib.isAlive and entitylib.character.RootPart.Position or nil
	local speed = (pos and lastPos) and (pos - lastPos).Magnitude / elapsed or 0
	lastPos = pos

	local s = {
		t = now,
		fps = frames / elapsed,
		worstFrameMs = maxDt * 1000,
		hitches = hitches,
		hitchWhileMoving = hitches > 0 and speed > 4,
		luaMB = collectgarbage('count') / 1024,
		clientMB = safe(function() return statsService:GetTotalMemoryUsageMb() end),
		entities = #entitylib.List,
		players = #playersService:GetPlayers(),
		moduleConns = moduleConns,
		moduleThreads = moduleThreads,
		entityConns = entConns,
		entitylibConns = #entitylib.Connections,
		entitylibThreads = countKeys(entitylib.EntityThreads),
		vapeConns = #vape.Connections,
		perModule = perModule,
		activeAuras = auras,
		remotesPerSec = remotes,
		sendKbps = safe(function() return statsService.DataSendKbps end),
		pingMs = safe(function() return statsService.Network.ServerStatsItem['Data Ping']:GetValue() end),
		speed = speed
	}

	frames, sumDt, maxDt, hitches = 0, 0, 0, 0
	table.insert(diag.Samples, s)
	if #diag.Samples > diag.MaxSamples then
		table.remove(diag.Samples, 1)
	end
	return s
end

local function avg(samples, from, to, key)
	local total, n = 0, 0
	for i = from, to do
		local v = samples[i] and samples[i][key]
		if type(v) == 'number' then total += v n += 1 end
	end
	return n > 0 and total / n or 0
end

-- Compares the first and last 30 samples. Flat or noisy is fine; a steady climb is a leak.
function diag.trend()
	local n = #diag.Samples
	if n < 90 then return {} end
	local warnings = {}
	for _, key in {'luaMB', 'moduleConns', 'moduleThreads', 'entityConns', 'entitylibConns', 'entitylibThreads', 'vapeConns', 'sendKbps'} do
		local first, last = avg(diag.Samples, 1, 30, key), avg(diag.Samples, n - 29, n, key)
		if last > first * 1.2 and last - first > (key == 'luaMB' and 5 or key == 'sendKbps' and 20 or 3) then
			table.insert(warnings, string.format('%s rising: %.1f -> %.1f', key, first, last))
		end
	end
	return warnings
end

local function format(s)
	local parts = {}
	for name, v in s.remotesPerSec do table.insert(parts, string.format('%s=%.1f/s', name, v)) end
	local mods = {}
	for name, v in s.perModule do table.insert(mods, string.format('%s(c%d,t%d)', name, v[1], v[2])) end
	table.sort(mods)
	return string.format(
		'[Diag] fps %.0f (worst %.0fms, %d hitches%s) | lua %.1fMB client %sMB | ents %d players %d | conns mod %d ent %d lib %d vape %d | threads mod %d lib %d | send %sKbps ping %sms | remotes %s | auras %s | %s',
		s.fps, s.worstFrameMs, s.hitches, s.hitchWhileMoving and ', WHILE MOVING' or '', s.luaMB,
		s.clientMB and string.format('%.0f', s.clientMB) or '?', s.entities, s.players,
		s.moduleConns, s.entityConns, s.entitylibConns, s.vapeConns, s.moduleThreads, s.entitylibThreads,
		s.sendKbps and string.format('%.0f', s.sendKbps) or '?', s.pingMs and string.format('%.0f', s.pingMs) or '?',
		#parts > 0 and table.concat(parts, ' ') or 'n/a', #s.activeAuras > 0 and table.concat(s.activeAuras, ',') or 'none',
		table.concat(mods, ' ')
	)
end

function diag.report()
	local s = diag.Samples[#diag.Samples]
	if not s then return 'no samples yet' end
	local text = format(s)
	local warnings = diag.trend()
	if #warnings > 0 then text ..= '\n[Diag] TREND: ' .. table.concat(warnings, '; ') end
	if #s.activeAuras > 1 then text ..= '\n[Diag] WARNING: multiple aura modules enabled at once: ' .. table.concat(s.activeAuras, ', ') end
	return text
end

vape.Libraries.diagnostics = diag

local Diagnostics
Diagnostics = vape.Categories.Utility:CreateModule({
	Name = 'Diagnostics',
	Function = function(callback)
		if callback then
			diag.Running = true
			frames, sumDt, maxDt, hitches = 0, 0, 0, 0
			lastSample, lastPos = os.clock(), nil
			local lastPrint = lastSample
			Diagnostics:Clean(runService.Heartbeat:Connect(function(dt)
				frames += 1
				sumDt += dt
				if dt > maxDt then maxDt = dt end
				if dt > 0.1 then hitches += 1 end
				local now = os.clock()
				if now - lastSample >= 1 then
					sample(now)
					if diag.Verbose and now - lastPrint >= 10 then
						lastPrint = now
						warn(diag.report())
					end
				end
			end))
		else
			diag.Running = false
			table.clear(diag.Samples)
			table.clear(lastCounters)
		end
	end,
	Tooltip = 'Prints FPS, memory, connection/thread counts, remote rate and send rate. Warns on steady growth.'
})
Diagnostics:CreateToggle({
	Name = 'Print to console',
	Tooltip = 'Prints a summary every 10 seconds (also available via vape.Libraries.diagnostics.report())',
	Function = function(callback)
		diag.Verbose = callback
	end
})

return diag
