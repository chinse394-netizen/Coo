local aimlib = {}
local epsilon = 1e-9
local cloneref2 = cloneref or function(reference)
	return reference
end
local players = cloneref2(game:GetService('Players'))
local tween_service = cloneref2(game:GetService('TweenService'))
local stats = cloneref2(game:GetService('Stats'))

local reply_t

local function one_round_trip()
	local ok, ping = pcall(function()
		return stats.Network.ServerStatsItem['Data Ping']:GetValue()
	end)
	if ok and type(ping) == 'number' and ping > 0 then
		return ping / 1000
	end
	return 0
end

function aimlib.setlag(val)
	if val == nil then
		reply_t = nil
	elseif type(val) == 'number' and val == val and val >= 0 and val < math.huge then
		reply_t = val
	end
end

local lag_bias = 0

local function get_base_lag()
	if reply_t ~= nil then
		return reply_t
	end

	if store and store.ping and store.ping.total then
		return store.ping.total
	end

	local ok, ping = pcall(players.LocalPlayer.GetNetworkPing, players.LocalPlayer)
	if ok and type(ping) == 'number' and ping >= 0 then
		return ping
	end
	return one_round_trip() * 0.5
end

function aimlib.getlag()
	return math.max(get_base_lag() + lag_bias, 0)
end

function aimlib.getrawlag()
	return get_base_lag()
end

function aimlib.Raycast(from2, dir, cast)
	return workspace:Raycast(from2, dir, cast)
end

aimlib.IsTrajectoryClear = function(from2, vel, grav, fly_t, cast, foe, ignored)
	local ray_cast = RaycastParams.new()
	ray_cast.FilterType = cast.FilterType
	ray_cast.FilterDescendantsInstances = cast.FilterDescendantsInstances
	ray_cast.IgnoreWater = cast.IgnoreWater
	ray_cast.CollisionGroup = cast.CollisionGroup
	ray_cast.RespectCanCollide = cast.RespectCanCollide
	local last_pos = from2
	for step = 1, 10 do
		local t2 = fly_t * (step / 10)
		local pos = from2 + vel * t2 + Vector3.new(0, -grav * 0.5 * t2 * t2, 0)
		local dir = pos - last_pos
		local hit = aimlib.Raycast(last_pos, dir, ray_cast)
		local ignored_hits = 0
		while hit do
			ignored_hits += 1
			if ignored_hits > 64 then
				return false, hit
			end
			if foe and hit.Instance:IsDescendantOf(foe) then
				return true
			end
			if not ignored or not ignored(hit.Instance) then
				return false, hit
			end
			ray_cast:AddToFilter(hit.Instance)
			hit = aimlib.Raycast(last_pos, dir, ray_cast)
		end
		last_pos = pos
	end
	return true
end

local tracer = Instance.new('Part')
tracer.Anchored = true
tracer.CanCollide = false
tracer.CanQuery = false
tracer.CanTouch = false
tracer.CastShadow = false

local is_zero = function(val)
	return (val > -epsilon and val < epsilon)
end
local cube_core = function(val)
	return (val > 0) and math.pow(val, (1 / 3)) or -math.pow(math.abs(val), (1 / 3))
end
local calc_q2 = function(c_0, c_1, c_2)
	local s_0, s_1
	if is_zero(c_0) then
		return not is_zero(c_1) and -c_2 / c_1 or nil
	end

	local p, q, d

	p = c_1 / (2 * c_0)
	q = c_2 / c_0
	d = p * p - q

	if is_zero(d) then
		s_0 = -p
		return s_0
	elseif (d < 0) then
		return
	else
		local sqrt_d = math.sqrt(d)

		s_0 = sqrt_d - p
		s_1 = -sqrt_d - p
		return s_0, s_1
	end
end
local calc_q3 = function(c_0, c_1, c_2, c_3)
	local s_0, s_1, s_2
	if is_zero(c_0) then
		return calc_q2(c_1, c_2, c_3)
	end

	local n, shift
	local a, b, c
	local square_a, p, q
	local cube_p, d

	a = c_1 / c_0
	b = c_2 / c_0
	c = c_3 / c_0

	square_a = a * a
	p = (1 / 3) * (-(1 / 3) * square_a + b)
	q = 0.5 * ((2 / 27) * a * square_a - (1 / 3) * a * b + c)

	cube_p = p * p * p
	d = q * q + cube_p

	if is_zero(d) then
		if is_zero(q) then
			s_0 = 0
			n = 1
		else
			local u = cube_core(-q)
			s_0 = 2 * u
			s_1 = -u
			n = 2
		end
	elseif (d < 0) then
		local phi = (1 / 3) * math.acos(math.clamp(-q / math.sqrt(-cube_p), -1, 1))
		local t = 2 * math.sqrt(-p)

		s_0 = t * math.cos(phi)
		s_1 = -t * math.cos(phi + math.pi / 3)
		s_2 = -t * math.cos(phi - math.pi / 3)
		n = 3
	else
		local sqrt_d = math.sqrt(d)
		local u = cube_core(sqrt_d - q)
		local v = -cube_core(sqrt_d + q)

		s_0 = u + v
		n = 1
	end

	shift = (1 / 3) * a

	if (n > 0) then
		s_0 = s_0 - shift
	end
	if (n > 1) then
		s_1 = s_1 - shift
	end
	if (n > 2) then
		s_2 = s_2 - shift
	end

	return s_0, s_1, s_2
end
function aimlib.calcq4(c_0, c_1, c_2, c_3, c_4)
	local s_0, s_1, s_2, s_3
	if is_zero(c_0) then
		local core_0, core_1, core_2 = calc_q3(c_1, c_2, c_3, c_4)
		local q3 = {}
		if core_0 then
			table.insert(q3, core_0)
		end
		if core_1 then
			table.insert(q3, core_1)
		end
		if core_2 then
			table.insert(q3, core_2)
		end
		return q3
	end

	local coefficients = {}
	local z, u, v, shift
	local a, b, c, d
	local square_a, p, q, r
	local n

	a = c_1 / c_0
	b = c_2 / c_0
	c = c_3 / c_0
	d = c_4 / c_0

	square_a = a * a
	p = -0.375 * square_a + b
	q = 0.125 * square_a * a - 0.5 * a * b + c
	r = -(3 / 256) * square_a * square_a + 0.0625 * square_a * b - 0.25 * a * c + d

	if is_zero(r) then
		coefficients[3] = q
		coefficients[2] = p
		coefficients[1] = 0
		coefficients[0] = 1

		s_0, s_1, s_2 = calc_q3(coefficients[0], coefficients[1], coefficients[2], coefficients[3])
		n = (s_0 and 1 or 0) + (s_1 and 1 or 0) + (s_2 and 1 or 0)
	else
		coefficients[3] = 0.5 * r * p - 0.125 * q * q
		coefficients[2] = -r
		coefficients[1] = -0.5 * p
		coefficients[0] = 1

		s_0, s_1, s_2 = calc_q3(coefficients[0], coefficients[1], coefficients[2], coefficients[3])
		z = s_0

		u = z * z - r
		v = 2 * z - p

		if is_zero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return
		end
		if is_zero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return
		end

		coefficients[2] = z - u
		coefficients[1] = q < 0 and -v or v
		coefficients[0] = 1

		s_0, s_1 = calc_q2(coefficients[0], coefficients[1], coefficients[2])
		n = (s_0 and 1 or 0) + (s_1 and 1 or 0)

		coefficients[2] = z + u
		coefficients[1] = q < 0 and v or -v
		coefficients[0] = 1

		if (n == 0) then
			local core_0, core_1 = calc_q2(coefficients[0], coefficients[1], coefficients[2])
			n = n + (core_0 and 1 or 0) + (core_1 and 1 or 0)
			s_0, s_1 = core_0, core_1
		end
		if (n == 1) then
			local core_0, core_1 = calc_q2(coefficients[0], coefficients[1], coefficients[2])
			n = n + (core_0 and 1 or 0) + (core_1 and 1 or 0)
			s_1, s_2 = core_0, core_1
		end
		if (n == 2) then
			local core_0, core_1 = calc_q2(coefficients[0], coefficients[1], coefficients[2])
			n = n + (core_0 and 1 or 0) + (core_1 and 1 or 0)
			s_2, s_3 = core_0, core_1
		end
	end

	shift = 0.25 * a

	local roots = {}
	if (n > 3) then
		table.insert(roots, s_3 - shift)
	end
	if (n > 2) then
		table.insert(roots, s_2 - shift)
	end
	if (n > 1) then
		table.insert(roots, s_1 - shift)
	end
	if (n > 0) then
		table.insert(roots, s_0 - shift)
	end

	return roots
end

aimlib.Spawntracer = function(from, to, custom)
	local dist = (to - from).Magnitude
	if dist < 0.01 then
		return
	end

	local segment = tracer:Clone()
	segment.Color = custom.Color
	segment.Size = vector.create(custom.Thick, custom.Thick, dist)
	segment.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	segment.Material = custom.Material
	segment.Transparency = custom.Opacity or 0

	if custom.Fade then
		tween_service:Create(segment, TweenInfo.new(custom.Lifetime), {
			Transparency = 1
		}):Play()
	end
	return segment
end
aimlib.Spawnarctracer = function(from2, aim_dir, shot_spd, grav, fly_t, steps, custom)
	steps = steps or 20
	local step_t = fly_t / steps
	local grav_vector = Vector3.new(0, -grav, 0)
	local vel = aim_dir * shot_spd

	local prev_pos = from2
	local model = Instance.new('Model')
	if custom.Material == Enum.Material.Glass then
		Instance.new('Highlight', model).Enabled = false
	end
	for step = 1, steps do
		local t2 = step * step_t
		local next_pos = from2 + vel * t2 + 0.5 * grav_vector * t2 * t2
		local segment = aimlib.Spawntracer(prev_pos, next_pos, custom)
		if segment then
			segment.Parent = model
		end
		prev_pos = next_pos
	end

	model.Parent = workspace.Terrain
	task.delay(custom.Lifetime, model.Destroy, model)
end

local update_rhythm, update_inputs
local valid_number = function(val)
	return type(val) == 'number' and val == val and math.abs(val) < math.huge
end

local flat_mask = Vector3.new(1, 0, 1)
local foe_move = setmetatable({}, {__mode = 'k'})
local valid_vector = function(val)
	return typeof(val) == 'Vector3'
		and valid_number(val.X)
		and valid_number(val.Y)
		and valid_number(val.Z)
end

local function get_attribute(core, attribute)
	local body = core and core.Parent
	if body and body:IsA('Model') then
		return body:GetAttribute(attribute)
	end
end

local function reset_move(core, track, pos, vel, t2, spawn_t)
	local kb_mark = track.knockbackMark
	local kb_multiplier = track.knockbackMultiplier
	local hop_vel = track.jumpVelocity
	table.clear(track)
	track.jumpVelocity = hop_vel
	track.assembly = vel
	track.damageTime = get_attribute(core, 'LastDamageTakenTime')
	track.knockbackMark = kb_mark
	track.knockbackMultiplier = kb_multiplier
	track.position = pos
	track.samples = {{position = pos, time = t2}}
	track.spawnTime = spawn_t
	track.stableVelocity = vel
	track.time = t2
	track.velocity = vel
	foe_move[core] = track
	return track
end

function aimlib.markKnockback(foe, multiplier, push)
	if typeof(foe) ~= 'Instance' then
		return
	end

	local core = foe:IsA('BasePart') and foe or foe:IsA('Model') and foe.PrimaryPart
	if not core then
		return
	end

	local track = foe_move[core] or {}
	track.knockbackMark = workspace:GetServerTimeNow()
	track.knockbackMultiplier = multiplier
	if valid_vector(push) then
		local flat = push * flat_mask
		track.knockbackHint = flat.Magnitude > epsilon and flat or nil
		track.knockbackHintTime = track.knockbackMark
	end
	track.expectedImpulse = nil
	track.expectedLift = nil
	track.expectedTime = nil
	foe_move[core] = track
end

function aimlib.expectkb(foe, reach, push, multiplier)
	if typeof(foe) ~= 'Instance' then
		return
	end

	local core = foe:IsA('BasePart') and foe or foe:IsA('Model') and foe.PrimaryPart
	if not core or not valid_number(reach) or not valid_vector(push) then
		return
	end

	local flat = push * flat_mask
	if flat.Magnitude <= epsilon and math.abs(push.Y) <= epsilon then
		return
	end

	local track = foe_move[core] or {}
	track.expectedImpulse = flat
	track.expectedLift = push.Y
	track.expectedTime = reach
	track.expectedMultiplier = multiplier
	foe_move[core] = track
end

local pending_rounds = {}
local leftover_scatter, leftover_count = 0, 0
local era_hits, era_rounds, era_rate = 0, 0, nil
local step_dir, step_size = 1, 0.008

local function apply_era()
	if era_rounds < 12 then
		return
	end

	local rate = era_hits / era_rounds
	era_hits, era_rounds = 0, 0
	if era_rate and rate + 0.02 < era_rate then
		step_dir = -step_dir
		step_size = math.max(step_size * 0.7, 0.002)
	end
	era_rate = rate
	if rate >= 0.95 then
		return
	end
	lag_bias = math.clamp(lag_bias + step_dir * step_size, -0.12, 0.12)
end

local function measure_scatter(round)
	local core = round.root
	if typeof(core) ~= 'Instance' or not core.Parent then
		return
	end

	local track = foe_move[core]
	if not track or track.spawnTime ~= round.spawnTime then
		return
	end
	if track.knockbackUntil and track.knockbackUntil > round.fireTime then
		return
	end

	local leftover = (core.Position - round.impact) * flat_mask
	if not valid_vector(leftover) or leftover.Magnitude > 30 then
		return
	end

	local cross = (leftover - round.direction * leftover:Dot(round.direction)).Magnitude
	leftover_scatter = leftover_scatter + (cross - leftover_scatter) * 0.2
	leftover_count = math.min(leftover_count + 1, 400)
end

local function resolve_rounds()
	if #pending_rounds == 0 then
		return
	end
	local now2 = workspace:GetServerTimeNow()

	for i2 = #pending_rounds, 1, -1 do
		local round = pending_rounds[i2]
		if not round.measured and now2 >= round.dueTime then
			round.measured = true
			measure_scatter(round)
		end
		if now2 > round.dueTime + 0.35 then
			table.remove(pending_rounds, i2)
			era_rounds += 1
			apply_era()
		end
	end
end

function aimlib.trackShot(foe_core)
	if typeof(foe_core) ~= 'Instance' then
		return
	end

	local track = foe_move[foe_core]
	local answer = track and track.lastSolution
	if not answer or not valid_number(answer.travelTime) or not valid_vector(answer.impact) then
		return
	end

	local vel = (track.velocity or Vector3.zero) * flat_mask
	if vel.Magnitude < 8 then
		return
	end

	if #pending_rounds >= 24 then
		table.remove(pending_rounds, 1)
	end
	table.insert(pending_rounds, {
		direction = vel.Unit,
		dueTime = answer.time + answer.travelTime,
		fireTime = answer.time,
		impact = answer.impact,
		root = foe_core,
		spawnTime = track.spawnTime,
		speed = vel.Magnitude
	})
end

function aimlib.reportHit(foe_core)
	if typeof(foe_core) ~= 'Instance' then
		return
	end

	local now2 = workspace:GetServerTimeNow()
	for i2 = #pending_rounds, 1, -1 do
		local round = pending_rounds[i2]
		if round.root == foe_core and now2 >= round.dueTime - 0.35 and now2 <= round.dueTime + 0.35 then
			if not round.measured then
				round.measured = true
				measure_scatter(round)
			end
			table.remove(pending_rounds, i2)
			era_hits += 1
			era_rounds += 1
			apply_era()
			return
		end
	end
end

function aimlib.getleftoverscatter()
	return leftover_scatter, leftover_count
end

function aimlib.getlagbias()
	return lag_bias, era_rate
end

local world_filter
local learned_cast = RaycastParams.new()
learned_cast.FilterType = Enum.RaycastFilterType.Include
local exclude_cast = RaycastParams.new()
exclude_cast.FilterType = Enum.RaycastFilterType.Exclude
exclude_cast.IgnoreWater = true
exclude_cast.RespectCanCollide = true
local exclude_arr, exclude_t = {}, 0

local cast_ground = function(pos, cast)
	return aimlib.Raycast(pos, Vector3.new(0, workspace.FallenPartsDestroyHeight - pos.Y, 0), cast)
end

local function refresh_exclude_arr(core)
	local t2 = os.clock()
	if t2 - exclude_t > 1 then
		exclude_t = t2
		table.clear(exclude_arr)
		for _, plr in players:GetPlayers() do
			if plr.Character then
				table.insert(exclude_arr, plr.Character)
			end
		end
	end

	local body = core and core.Parent
	if body and not table.find(exclude_arr, body) then
		table.insert(exclude_arr, body)
	end
	return exclude_arr
end

local trace_one = function(pos, cast, core)
	local body = core and core.Parent
	if cast then
		local res = cast_ground(pos, cast)
		if res and not (body and res.Instance:IsDescendantOf(body)) then
			if cast.FilterType == Enum.RaycastFilterType.Include then
				world_filter = cast.FilterDescendantsInstances
			end
			return res.Position.Y
		end
	end

	if world_filter and #world_filter > 0 then
		learned_cast.FilterDescendantsInstances = world_filter
		local res = cast_ground(pos, learned_cast)
		if res then
			return res.Position.Y
		end
	end

	exclude_cast.FilterDescendantsInstances = refresh_exclude_arr(core)
	local res = cast_ground(pos, exclude_cast)
	return res and res.Position.Y or nil
end

local foot_offsets = {Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)}
local trace_ground = function(pos, cast, core)
	local found = trace_one(pos, cast, core)
	if found then
		return found
	end
	for _, off in foot_offsets do
		local edge = trace_one(pos + off, cast, core)
		if edge and (not found or edge > found) then
			found = edge
		end
	end
	return found
end

local get_foe_move = function(core, pos, vel, inair, plr_grav)
	if not core or not valid_vector(pos) or not valid_vector(vel) then
		return {
			acceleration = Vector3.zero,
			position = pos,
			velocity = vel
		}
	end

	local t2 = workspace:GetServerTimeNow()
	local spawn_t = get_attribute(core, 'SpawnTime')
	local track = foe_move[core] or {}
	if track.time and t2 - track.time < 1 / 240 then
		local kb = track.knockbackUntil and t2 < track.knockbackUntil
		return {
			acceleration = track.acceleration or Vector3.zero,
			decay = track.knockbackDecay,
			flying = track.flying,
			invalid = track.pendingPosition ~= nil,
			impulse = kb and track.knockbackImpulse,
			knockback = kb,
			knockbackBase = kb and track.knockbackBase,
			expectedImpulse = track.expectedImpulse,
			expectedLift = track.expectedLift,
			expectedTime = track.expectedTime,
			missRate = track.missRate,
			position = track.position,
			state = track,
			stale = track.updateTime and math.clamp(t2 - track.updateTime, 0, 0.2) or nil,
			strafeElapsed = track.strafeReversal and t2 - track.strafeReversal or nil,
			strafeHalf = track.strafeHalf,
			strafeSeen = track.strafeSeen,
			strafeSpeed = track.strafeSpeed,
			strafeDirection = track.strafeDirection,
			turnRate = track.turnRate,
			turnSeen = track.turnSeen,
			velocity = track.velocity
		}
	end
	if not track.time or t2 - track.time > 0.75 or track.spawnTime ~= spawn_t then
		track = reset_move(core, track, pos, vel, t2, spawn_t)
		return {
			acceleration = Vector3.zero,
			position = pos,
			state = track,
			velocity = vel
		}
	end

	local delta = t2 - track.time
	if delta <= epsilon then
		return {
			acceleration = Vector3.zero,
			flying = track.flying,
			position = track.position,
			state = track,
			velocity = track.velocity
		}
	end
	local displacement = pos - track.position
	local instant_vel = displacement / delta
	local assembly_agreement = vel.Magnitude > 5
		and instant_vel.Magnitude > 5
		and vel.Unit:Dot(instant_vel.Unit) > 0.75
		and math.abs(vel.Magnitude - instant_vel.Magnitude) < math.max(40, vel.Magnitude * 0.75)
	if track.pendingPosition then
		if (pos - track.position).Magnitude < 2 then
			track.pendingPosition = nil
			track.pendingTime = nil
		elseif (pos - track.pendingPosition).Magnitude < 2 then
			track = reset_move(core, track, pos, vel, t2, spawn_t)
			return {
				acceleration = Vector3.zero,
				changed = true,
				position = pos,
				state = track,
				velocity = vel
			}
		else
			track.pendingPosition = nil
			track.pendingTime = nil
		end
	end

	local displacement_limit = math.max(12, (math.max(track.velocity.Magnitude, vel.Magnitude) + 30) * delta * 1.5)
	if (displacement.Magnitude > displacement_limit or instant_vel.Magnitude > 260) and not assembly_agreement then
		track.pendingPosition = pos
		track.pendingTime = t2
		track.time = t2
		return {
			acceleration = Vector3.zero,
			flying = track.flying,
			invalid = true,
			position = track.position,
			state = track,
			velocity = track.velocity
		}
	end

	local count = track.samples
	table.insert(count, {position = pos, time = t2})
	local rise_log = track.riseLog
	if not rise_log then
		rise_log = {}
		track.riseLog = rise_log
	end
	table.insert(rise_log, {pos.Y, t2})
	while #rise_log > 2 and t2 - rise_log[1][2] > 0.5 do
		table.remove(rise_log, 1)
	end
	while #count > 6 or (#count > 2 and t2 - count[1].time > 0.14) do
		table.remove(count, 1)
	end

	local read_vel
	local oldest = count[1]
	if oldest and t2 - oldest.time > 0.02 then
		read_vel = (pos - oldest.position) / (t2 - oldest.time)
		if not valid_vector(read_vel) or read_vel.Magnitude > 260 then
			read_vel = nil
		end
	end

	local recent_vel
	local prev_one = count[#count - 1]
	if prev_one and t2 - prev_one.time > epsilon then
		recent_vel = (pos - prev_one.position) / (t2 - prev_one.time)
		if not valid_vector(recent_vel) or recent_vel.Magnitude > 260 then
			recent_vel = nil
		end
	end

	local damage_t = get_attribute(core, 'LastDamageTakenTime')
	local damage_changed = valid_number(damage_t) and damage_t > 0 and damage_t ~= track.damageTime
	local marked = t2 - (track.knockbackMark or -math.huge) < 0.25
	local vel_change = vel - track.assembly
	local read_agreement = read_vel
		and read_vel.Magnitude > 5
		and vel.Magnitude > 5
		and read_vel.Unit:Dot(vel.Unit) > 0.7
		and (read_vel - vel).Magnitude < math.max(35, vel.Magnitude * 0.6)
	local vel_invalid = (vel_change.Magnitude > math.max(70, track.velocity.Magnitude * 2 + 35) or vel.Magnitude > 260)
		and not marked
		and not damage_changed
		and not read_agreement
	if vel_invalid then
		local candidate = track.velocityCandidate
		if candidate and t2 - track.velocityCandidateTime < 0.12 and (candidate - vel).Magnitude < math.max(12, vel.Magnitude * 0.2) then
			track.velocityCandidate = nil
			track.velocityCandidateTime = nil
		else
			track.velocityCandidate = vel
			track.velocityCandidateTime = t2
			vel = track.assembly
		end
	else
		track.velocityCandidate = nil
		track.velocityCandidateTime = nil
	end

	local assembly_flat = vel * flat_mask
	local read_flat = read_vel and read_vel * flat_mask
	local flat_vel = assembly_flat
	local read_accepted
	if read_flat then
		local difference = (read_flat - assembly_flat).Magnitude
		if difference < math.max(6, assembly_flat.Magnitude * 0.35) then
			flat_vel = assembly_flat:Lerp(read_flat, 0.15)
			read_accepted = true
		elseif assembly_flat.Magnitude < 2 and read_flat.Magnitude > 2 then
			local candidate = track.measuredCandidate
			local consistent = candidate
				and t2 - track.measuredCandidateTime < 0.15
				and candidate.Magnitude > epsilon
				and read_flat.Magnitude > epsilon
				and candidate.Unit:Dot(read_flat.Unit) > 0.8
				and math.abs(candidate.Magnitude - read_flat.Magnitude) < math.max(12, read_flat.Magnitude * 0.35)
			if read_flat.Magnitude < 45 or consistent then
				flat_vel = read_flat
				read_accepted = true
				track.measuredCandidate = nil
				track.measuredCandidateTime = nil
			else
				track.measuredCandidate = read_flat
				track.measuredCandidateTime = t2
				flat_vel = track.velocity * flat_mask
			end
		else
			track.measuredCandidate = nil
			track.measuredCandidateTime = nil
		end
	end

	local vert_vel = vel.Y
	if read_accepted and read_vel then
		if math.abs(vert_vel - read_vel.Y) < 8 then
			vert_vel = vert_vel + (read_vel.Y - vert_vel) * 0.15
		elseif recent_vel and math.abs(vert_vel) < 1 and (track.flying or math.abs(recent_vel.Y) < 45) then
			vert_vel = recent_vel.Y
		end
	end
	if not inair and math.abs(vert_vel) < 2 then
		vert_vel = 0
	end

	local combined_vel = Vector3.new(flat_vel.X, vert_vel, flat_vel.Z)
	local prev_vel = track.velocity
	local difference = (combined_vel - prev_vel).Magnitude
	local prev_flat = prev_vel * flat_mask
	local dir_changed = flat_vel.Magnitude > 2
		and prev_flat.Magnitude > 2
		and flat_vel.Unit:Dot(prev_flat.Unit) < 0.65
	local shift2 = difference / math.max(prev_vel.Magnitude * 0.35, 7)
	local changed = shift2 >= 1 or dir_changed
	local now_vel
	if changed then
		now_vel = combined_vel
	else
		local alpha = math.clamp(delta * 20, 0.2, 1)
		now_vel = prev_vel:Lerp(combined_vel, alpha + (1 - alpha) * shift2 * shift2)
	end

	local hum = core.Parent and core.Parent:FindFirstChildWhichIsA('Humanoid')
	local hum_track = hum and hum:GetState()
	track.leaping = hum_track == Enum.HumanoidStateType.Jumping or hum_track == Enum.HumanoidStateType.Freefall
	local push_change = (now_vel - prev_vel) * flat_mask
	local kb_started = (marked or damage_changed)
		and (push_change.Magnitude > 1.5 or math.abs(now_vel.Y - prev_vel.Y) > 1.5)
	if not kb_started and hum and hum.PlatformStand then
		kb_started = push_change.Magnitude > 5 or math.abs(now_vel.Y - prev_vel.Y) > 5
	end

	if track.expectedTime then
		if kb_started or t2 > track.expectedTime + 0.35 then
			track.expectedImpulse, track.expectedTime, track.expectedMultiplier, track.expectedLift = nil, nil, nil, nil
		elseif t2 >= track.expectedTime then
			track.knockbackHint = track.expectedImpulse
			track.knockbackHintTime = t2
			track.knockbackMark = t2
			track.knockbackMultiplier = track.expectedMultiplier
			track.expectedImpulse, track.expectedTime, track.expectedMultiplier, track.expectedLift = nil, nil, nil, nil
		end
	end

	local hint = track.knockbackHint
	if hint and t2 - (track.knockbackHintTime or -math.huge) > 0.25 then
		hint, track.knockbackHint, track.knockbackHintTime = nil, nil, nil
	end
	if hint and not kb_started and not track.knockbackUntil then
		kb_started = true
	end
	if kb_started then
		track.knockbackBase = track.stableVelocity * flat_mask
		track.knockbackDecay = inair and 1.8 or 3.5
		track.knockbackSeed = hint
		track.knockbackStart = t2
		track.knockbackUntil = t2 + 0.6
	end

	local kb = track.knockbackUntil and t2 < track.knockbackUntil
	local kb_push
	if kb then
		kb_push = now_vel * flat_mask - track.knockbackBase
		local seed = track.knockbackSeed
		if seed and t2 - track.knockbackStart < 0.12 and seed.Magnitude > kb_push.Magnitude then
			kb_push = seed
		end
		local prev_push = track.knockbackImpulse
		if prev_push
			and prev_push.Magnitude > 4
			and kb_push.Magnitude > 4
			and prev_push.Unit:Dot(kb_push.Unit) < 0.35
		then
			track.knockbackUntil = nil
			kb = false
		end
		if prev_push
			and kb
			and prev_push.Magnitude > 3
			and kb_push.Magnitude > 3
			and prev_push.Unit:Dot(kb_push.Unit) > 0.8
			and kb_push.Magnitude < prev_push.Magnitude
		then
			local decay = -math.log(kb_push.Magnitude / prev_push.Magnitude) / delta
			if valid_number(decay) and decay > 0 then
				track.knockbackDecay = track.knockbackDecay + (math.clamp(decay, 0.75, 8) - track.knockbackDecay) * 0.35
			end
		end
		if kb_push.Magnitude < 3 and t2 - track.knockbackStart > 0.1 then
			track.knockbackSeed = nil
			track.knockbackUntil = nil
			kb = false
		else
			track.knockbackImpulse = kb_push
		end
	end

	if inair then
		local vert_change = (now_vel.Y - prev_vel.Y) / delta
		if valid_number(vert_change) then
			track.verticalAcceleration = track.verticalAcceleration
				and track.verticalAcceleration + (vert_change - track.verticalAcceleration) * 0.25
				or vert_change
		end
		track.airTime = (track.airTime or 0) + delta
		if track.airTime > 0.6 and track.verticalAcceleration and valid_number(plr_grav) and plr_grav > 0 then
			if track.verticalAcceleration > -plr_grav * 0.4 then
				local ground_y = trace_ground(pos, nil, core)
				track.flying = ground_y and pos.Y - ground_y > 12 or false
			else
				track.flying = false
			end
		end
	else
		track.airTime = nil
		track.verticalAcceleration = nil
		track.flying = nil
	end

	local takeoff_base = track.position.Y
	local missed_landing
	if inair and track.airborne and prev_vel.Y <= 0 and now_vel.Y > 8 and not kb then
		local ground_y = trace_ground(pos, nil, core)
		local tall = hum and hum.HipHeight + core.Size.Y * 0.5 or 3
		if ground_y and pos.Y - ground_y <= tall + 3 then
			missed_landing = true
			takeoff_base = ground_y + tall
		end
	end
	if inair and (not track.airborne or missed_landing) and now_vel.Y > 5 and not kb then
		local takeoff = now_vel.Y
		local reference = track.jumpVelocity or takeoff
		if takeoff < reference * 1.5 and takeoff > reference * 0.5 then
			track.jumpVelocity = track.jumpVelocity and (track.jumpVelocity + (takeoff - track.jumpVelocity) * 0.35) or takeoff
			if track.jumpStart then
				local period = t2 - track.jumpStart
				local rise = track.jumpBase and takeoff_base - track.jumpBase
				if period > 0.15 and period < 1.5 then
					if track.jumpPeriod then
						local drift = math.abs(period - track.jumpPeriod) / track.jumpPeriod
						track.jumpDrift = track.jumpDrift and (track.jumpDrift + (drift - track.jumpDrift) * 0.35) or drift
					end
					track.jumpPeriod = track.jumpPeriod and (track.jumpPeriod + (period - track.jumpPeriod) * 0.35) or period
					track.jumpSeen = math.min((track.jumpSeen or 0) + 1, 6)
				else
					track.jumpSeen, track.jumpPeriod = nil, nil
				end
				if period > 0.15 and period < 1.5 and rise and rise > 1 and rise < 8 then
					track.climbStep = track.climbStep and (track.climbStep + (rise - track.climbStep) * 0.35) or rise
					track.climbSeen = math.min((track.climbSeen or 0) + 1, 6)
				else
					track.climbStep, track.climbSeen = nil, nil
				end
			end
			track.jumpStart = t2
			track.jumpBase = takeoff_base
		elseif not track.jumpVelocity then
			track.jumpVelocity = takeoff
			track.jumpStart = t2
			track.jumpBase = takeoff_base
		end
	end
	track.airborne = inair
	if track.jumpPeriod and t2 - (track.jumpStart or 0) > track.jumpPeriod + math.max(0.1, track.jumpPeriod * (track.jumpDrift or 0) * 2) then
		track.jumpPeriod, track.jumpSeen, track.climbStep, track.climbSeen = nil, nil, nil, nil
	end

	local zig_flat = now_vel * flat_mask
	if zig_flat.Magnitude > 4 and not kb then
		track.strafeSlow = nil
		track.strafeSpeed = track.strafeSpeed and (track.strafeSpeed + (zig_flat.Magnitude - track.strafeSpeed) * 0.2) or zig_flat.Magnitude
		local unit = zig_flat.Unit
		local prev = track.strafeDirection
		if prev and math.abs(unit:Dot(prev)) < 0.65 then
			track.strafeHalf, track.strafeReversal, track.strafeSeen = nil, nil, nil
			track.strafeDirection = unit
		elseif prev and unit:Dot(prev) < -0.5 then
			local last_flip = track.strafeReversal
			if last_flip then
				local mid = t2 - last_flip
				if mid > 0.08 and mid < 1.2 then
					track.strafeHalf = track.strafeHalf and (track.strafeHalf + (mid - track.strafeHalf) * 0.35) or mid
					track.strafeSeen = math.min((track.strafeSeen or 0) + 1, 6)
				end
			end
			track.strafeDirection = unit
			track.strafeReversal = t2
		elseif not prev or unit:Dot(prev) > 0.5 then
			track.strafeDirection = unit
		end
	elseif zig_flat.Magnitude < 1 then
		track.strafeSlow = track.strafeSlow or t2
		if t2 - track.strafeSlow > 0.2 then
			track.strafeDirection, track.strafeHalf, track.strafeSeen, track.strafeSpeed = nil, nil, nil, nil
		end
	end
	if track.strafeReversal and t2 - track.strafeReversal > (track.strafeHalf and track.strafeHalf * 1.5 or 2.5) then
		track.strafeHalf, track.strafeReversal, track.strafeSeen, track.strafeSpeed = nil, nil, nil, nil
	end

	local prev_turn = track.turnUnit
	if zig_flat.Magnitude > 5 and not kb then
		local unit = zig_flat.Unit
		if prev_turn and delta > epsilon then
			local cross = prev_turn.X * unit.Z - prev_turn.Z * unit.X
			local angle = math.atan2(cross, math.clamp(prev_turn:Dot(unit), -1, 1))
			if math.abs(angle) < 1.4 then
				local rate = angle / delta
				local settled = track.turnRate
				if settled and settled * rate > 0 and math.abs(rate) > 0.25 then
					track.turnSeen = math.min((track.turnSeen or 0) + 1, 12)
				elseif math.abs(rate) < 0.25 then
					track.turnSeen = math.max((track.turnSeen or 0) - 1, 0)
				else
					track.turnSeen = 0
				end
				track.turnRate = settled and settled + (rate - settled) * 0.3 or rate
			else
				track.turnRate, track.turnSeen = nil, 0
			end
		end
		track.turnUnit = unit
	else
		track.turnRate, track.turnSeen, track.turnUnit = nil, 0, nil
	end
	if track.strafeReversal and t2 - track.strafeReversal < delta * 1.5 then
		track.turnRate, track.turnSeen = nil, 0
	end

	if zig_flat.Magnitude > 4 then
		if displacement.Magnitude > epsilon then
			track.updateTime = t2
		end
	else
		track.updateTime = nil
	end

	local pending = track.pending
	if pending then
		while pending[1] and pending[1].arrival <= t2 do
			local entry = table.remove(pending, 1)
			local seen = track.position:Lerp(pos, math.clamp((entry.arrival - track.time) / delta, 0, 1))
			local miss = ((seen - entry.position) * flat_mask).Magnitude / entry.horizon
			if entry.candidates then
				track.scores = track.scores or {}
				local scores = track.scores[entry.bucket] or {count = 0}
				for i2, v2 in entry.candidates do
					local difference = (seen - v2) * flat_mask
					local loss = math.min(difference:Dot(difference) / 9, 4)
					scores[i2] = scores[i2] and scores[i2] + (loss - scores[i2]) * 0.2 or loss
				end
				scores.count += 1
				track.scores[entry.bucket] = scores
			end
			if track.missRate then
				miss = math.min(miss, track.missRate * 1.5)
			end
			track.missRate = track.missRate and (track.missRate + (miss - track.missRate) * 0.3) or miss
		end
	end

	local accel = Vector3.zero
	if not kb and flat_vel.Magnitude > 1 then
		local change = (now_vel - prev_vel) * flat_mask / delta
		local parallel = change:Dot(flat_vel.Unit)
		local perpendicular = (change - flat_vel.Unit * parallel).Magnitude
		if parallel < -8 and perpendicular < math.abs(parallel) * 0.6 then
			accel = flat_vel.Unit * math.max(parallel, -400)
		end
	end

	if not kb then
		track.stableVelocity = now_vel
		track.knockbackImpulse = nil
	end
	track.assembly = vel
	track.acceleration = accel
	track.damageTime = damage_t
	track.position = pos
	track.time = t2
	track.velocity = now_vel
	update_rhythm(track, pos, t2, kb)
	update_inputs(track, hum, t2, now_vel * flat_mask, kb)
	return {
		acceleration = accel,
		changed = changed or kb_started,
		decay = track.knockbackDecay,
		flying = track.flying,
		impulse = kb and kb_push,
		knockback = kb,
		knockbackBase = kb and track.knockbackBase,
		expectedImpulse = track.expectedImpulse,
		expectedLift = track.expectedLift,
		expectedTime = track.expectedTime,
		missRate = track.missRate,
		position = pos,
		state = track,
		stale = track.updateTime and math.clamp(t2 - track.updateTime, 0, 0.2) or nil,
		strafeElapsed = track.strafeReversal and t2 - track.strafeReversal or nil,
		strafeHalf = track.strafeHalf,
		strafeSeen = track.strafeSeen,
		strafeSpeed = track.strafeSpeed,
		strafeDirection = track.strafeDirection,
		turnRate = track.turnRate,
		turnSeen = track.turnSeen,
		velocity = now_vel
	}
end

local rank_spd, rank_grav, rank_step = 240, 35, 0.1

function aimlib.Observe(core, pos, vel, inair, plr_grav, from2, plr_tall, plr_hop)
	if typeof(core) ~= 'Instance' then
		return
	end

	local move = get_foe_move(core, pos, vel, inair, plr_grav)
	local track = move.state
	if not track or not valid_vector(from2) then
		return
	end

	local now2 = workspace:GetServerTimeNow()
	if now2 - (track.gradeTime or -math.huge) < rank_step then
		return
	end

	aimlib.SolveTrajectory(from2, rank_spd, rank_grav, pos, vel, plr_grav, plr_tall, plr_hop, nil, inair, pos, core, nil, true)
end

local rhythm_step = 1 / 30
local rhythm_velocities = {}

update_rhythm = function(track, pos, t2, kb)
	if kb then
		track.pattern = nil
		return
	end

	local rhythm = track.pattern
	if not rhythm or t2 - rhythm.observed > 0.25 then
		track.pattern = {samples = {pos * flat_mask}, time = t2, observed = t2, position = pos}
		return
	end

	local count = rhythm.samples
	local since = t2 - rhythm.observed
	while t2 - rhythm.time >= rhythm_step do
		rhythm.time += rhythm_step
		local alpha = math.clamp((rhythm.time - rhythm.observed) / math.max(since, epsilon), 0, 1)
		table.insert(count, rhythm.position:Lerp(pos, alpha) * flat_mask)
		if #count > 128 then
			table.remove(count, 1)
		end
	end
	rhythm.observed, rhythm.position = t2, pos
	if t2 - (rhythm.checked or 0) < 0.1 then
		return
	end
	rhythm.checked = t2

	local n = #count
	for i2 = 3, n do
		rhythm_velocities[i2] = (count[i2] - count[i2 - 2]) / (rhythm_step * 2)
	end

	local best, best_error, best_variance
	for period = 9, math.min(66, math.floor((n - 3) / 2)) do
		local span = math.min(period, 30)
		local error, energy, average = 0, 0, Vector3.zero
		for i2 = n - span + 1, n do
			local now = rhythm_velocities[i2]
			local prev = rhythm_velocities[i2 - period]
			local difference = now - prev
			error += difference:Dot(difference)
			energy += now:Dot(now)
			average += now
		end
		average /= span
		local variance = energy / span - average:Dot(average)
		error /= span
		if variance > 16 and error < variance * 0.12 and (not best_error or error < best_error * 0.85) then
			best, best_error, best_variance = period, error, variance
		end
	end

	if best then
		local now = (count[n] - count[n - 3]) / (rhythm_step * 3)
		local prev = (count[n - best] - count[n - best - 3]) / (rhythm_step * 3)
		local difference = now - prev
		if difference:Dot(difference) < math.max(9, best_variance * 0.2) then
			rhythm.seen = rhythm.period and math.abs(rhythm.period - best) <= 2 and (rhythm.seen or 0) + 1 or 1
			rhythm.period = best
			rhythm.error = best_error / best_variance
			return
		end
	end
	rhythm.period, rhythm.seen = nil, nil
end

local function rhythm_displacement(rhythm, since)
	local count = rhythm.samples
	local n, period = #count, rhythm.period
	local phase = since / rhythm_step
	local cycles = math.floor(phase / period)
	phase -= cycles * period
	local i = math.floor(phase)
	local pos = count[n - period + i]:Lerp(count[n - period + i + 1], phase - i)
	local drift = count[n] - count[n - period]
	return pos - count[n - period] + drift * cycles
end

local key_wait = 0.18
local key_wait_seen = 0
local key_history = 1
local key_fresh = 0.25

update_inputs = function(track, hum, t2, vel, kb)
	local move2 = hum and hum.MoveDirection
	if not valid_vector(move2) then
		track.inputs = nil
		return
	end

	move2 = move2 * flat_mask
	local inputs = track.inputs
	if not inputs then
		inputs = {}
		track.inputs = inputs
	end

	local last = inputs[#inputs]
	if not last or (last.move - move2).Magnitude > 1e-3 then
		table.insert(inputs, {move = move2, time = t2})
	end
	while #inputs > 2 and inputs[2].time < t2 - key_history do
		table.remove(inputs, 1)
	end
	track.inputTime = t2

	local spd = vel.Magnitude
	if not kb and spd > 8 and spd < 60 and move2.Magnitude > 0.5 then
		track.cruise = track.cruise and track.cruise + (spd - track.cruise) * 0.1 or spd
	end

	local change = track.inputChange
	if change then
		if kb or t2 - change.time > 0.5 then
			track.inputChange = nil
		elseif spd > 4 and vel.Unit:Dot(change.direction) > 0.8 then
			local wait = t2 - change.time
			if wait > 0.03 and wait < 0.45 then
				key_wait += (wait - key_wait) * 0.1
				key_wait_seen += 1
			end
			track.inputChange = nil
		end
	end

	if last and last.move ~= move2 and last.move.Magnitude > 0.5 and move2.Magnitude > 0.5 and last.move.Unit:Dot(move2.Unit) < 0.3 then
		if spd < 4 or vel.Unit:Dot(move2.Unit) < 0.3 then
			track.inputChange = {direction = move2.Unit, time = t2}
		end
	end
end

local function get_key_route(track, now2)
	local inputs = track and track.inputs
	if not inputs or #inputs == 0 or now2 - (track.inputTime or -math.huge) > key_fresh then
		return nil
	end

	local spd = math.clamp(track.cruise or 20, 8, 60)
	local start = now2 - key_wait
	local first = 1
	for i2 = #inputs, 1, -1 do
		if inputs[i2].time <= start then
			first = i2
			break
		end
	end

	local route = {{0, inputs[first].move * spd}}
	for i2 = first + 1, #inputs do
		table.insert(route, {inputs[i2].time - start, inputs[i2].move * spd})
	end
	return route
end

local function key_displacement(route, since)
	local shift = Vector3.zero
	for i2, v2 in route do
		local from = v2[1]
		if since <= from then
			break
		end
		local following = route[i2 + 1]
		local to = following and math.min(following[1], since) or since
		shift += v2[2] * (to - from)
	end
	return shift
end

function aimlib.getkeywait()
	return key_wait, key_wait_seen
end

local calc_move_t = function(from2, spd, shot_accel, pos_at_t, lo)
	local function evaluate(t2)
		local shift = pos_at_t(t2) - from2 - shot_accel * (0.5 * t2 * t2)
		return shift:Dot(shift) - spd * spd * t2 * t2
	end

	local low = lo or 0
	local low_val = evaluate(low)
	if not valid_number(low_val) then
		return
	end
	local dist = (pos_at_t(low) - from2).Magnitude
	local start = low
	local hi = math.min(math.max(dist / spd * 4 + 1, low + 2), 12)
	for step = 1, 72 do
		local alpha = step / 72
		local high = start + (hi - start) * math.pow(alpha, 1.35)
		local high_val = evaluate(high)
		if not valid_number(high_val) then
			return
		end
		if math.abs(high_val) < math.max(1e-7, spd * spd * high * high * 1e-7) then
			return high
		end
		if (high_val > 0) ~= (low_val > 0) then
			for _ = 1, 60 do
				local middle = (low + high) * 0.5
				if (evaluate(middle) > 0) == (low_val > 0) then
					low = middle
				else
					high = middle
				end
			end
			return high
		end
		low = high
		low_val = high_val
	end
end

local calc_intercept_t = function(displacement, vel, accel, spd, lo)
	lo = lo or 0
	local mid_accel = accel * 0.5
	if mid_accel:Dot(mid_accel) < epsilon then
		local a = vel:Dot(vel) - spd * spd
		local b = 2 * vel:Dot(displacement)
		local c = displacement:Dot(displacement)
		if math.abs(a) < epsilon then
			local t2 = math.abs(b) > epsilon and -c / b or nil
			return t2 and t2 > math.max(epsilon, lo) and t2 or nil
		end

		local disc = b * b - 4 * a * c
		local tolerance = epsilon * (b * b + math.abs(4 * a * c) + 1)
		if disc < -tolerance then
			return
		end

		local core = math.sqrt(math.max(disc, 0))
		local q = -0.5 * (b + (b >= 0 and core or -core))
		local first = q / a
		local second = math.abs(q) > epsilon and c / q or nil
		first = first and first > math.max(epsilon, lo) and first or nil
		second = second and second > math.max(epsilon, lo) and second or nil
		if first and second then
			return math.min(first, second)
		end
		return first or second
	end

	local c_4 = mid_accel:Dot(mid_accel)
	local c_3 = 2 * mid_accel:Dot(vel)
	local c_2 = 2 * mid_accel:Dot(displacement) + vel:Dot(vel) - spd * spd
	local c_1 = 2 * vel:Dot(displacement)
	local c_0 = displacement:Dot(displacement)
	local core_0, core_1, core_2 = calc_q3(4 * c_4, 3 * c_3, 2 * c_2, c_1)
	local critical = {}
	if valid_number(core_0) and core_0 > lo then
		table.insert(critical, core_0)
	end
	if valid_number(core_1) and core_1 > lo then
		table.insert(critical, core_1)
	end
	if valid_number(core_2) and core_2 > lo then
		table.insert(critical, core_2)
	end
	table.sort(critical)

	local function evaluate(t2)
		return ((((c_4 * t2 + c_3) * t2 + c_2) * t2 + c_1) * t2 + c_0)
	end

	local function tolerance(t2)
		return math.max(1e-7, spd * spd * t2 * t2 * 1e-7)
	end

	local function bisect(low, high, low_val)
		for _ = 1, 60 do
			local middle = (low + high) * 0.5
			local val = evaluate(middle)
			if (val > 0) == (low_val > 0) then
				low = middle
				low_val = val
			else
				high = middle
			end
		end
		return high
	end

	local prev = lo
	local prev_val = evaluate(prev)
	for _, t2 in critical do
		local val = evaluate(t2)
		if prev_val * val < 0 then
			return bisect(prev, t2, prev_val)
		end
		if math.abs(val) <= tolerance(t2) then
			return t2
		end
		prev = t2
		prev_val = val
	end

	if prev_val < 0 then
		local high = math.max(prev * 2, prev + 1)
		local high_val = evaluate(high)
		while high_val < 0 do
			high *= 2
			high_val = evaluate(high)
		end
		return bisect(prev, high, prev_val)
	end
	return
end

local zig_displacement = function(since, left, mid)
	local phase = mid - left
	local future = (phase + since) % (mid * 2)
	return (future <= mid and future or mid * 2 - future) - phase
end

local calc_landing_t = function(start_y, ground_y, vert_vel, plr_grav)
	local tall = start_y - ground_y
	if tall <= epsilon and vert_vel <= 0 then
		return nil, true
	end

	local disc = vert_vel * vert_vel + 2 * plr_grav * tall
	if disc < 0 then
		return nil
	end

	local landing = (vert_vel + math.sqrt(disc)) / plr_grav
	return valid_number(landing) and landing > epsilon and landing or nil
end

local function calc_static_fire(from2, foe, spd, accel)
	local delta = foe - from2
	if spd <= epsilon then
		return
	end

	local pull = -accel.Y
	if math.abs(pull) <= epsilon then
		local dist = delta.Magnitude
		if dist <= epsilon then
			return
		end
		local t2 = dist / spd
		return delta / t2, t2
	end

	local a = 0.25 * pull * pull
	local b = (pull * delta.Y) - (spd * spd)
	local c = delta:Dot(delta)
	local disc = (b * b) - (4 * a * c)
	if disc < 0 then
		return
	end

	local core = math.sqrt(disc)
	local first, second = (-b - core) / (2 * a), (-b + core) / (2 * a)
	local squared = first > epsilon and first or (second > epsilon and second or nil)
	if not squared then
		return
	end

	local t2 = math.sqrt(squared)
	if not valid_number(t2) or t2 <= epsilon then
		return
	end

	local vel = (delta + Vector3.new(0, 0.5 * pull * t2 * t2, 0)) / t2
	if not valid_vector(vel) then
		return
	end

	return vel, t2
end

local cover_lift = 2
local aim_lift = 0.5
local TERMINAL_FALL = 150

aimlib.SolveTrajectory = function(from2, shot_spd, grav, foe_pos, foe_vel, plr_grav, plr_tall, plr_hop, cast, foe_inair, foe_core_pos, foe_core, lo_t, strict)
	resolve_rounds()
	foe_vel = foe_vel or Vector3.zero
	shot_spd = tonumber(shot_spd) or 0
	grav = tonumber(grav) or 0
	plr_grav = tonumber(plr_grav) or 0
	plr_tall = tonumber(plr_tall) or 0
	if typeof(foe_core_pos) == 'Instance' and foe_core_pos:IsA('BasePart') then
		foe_core = foe_core_pos
		foe_core_pos = foe_core.Position
	end
	if not valid_vector(from2)
		or not valid_vector(foe_pos)
		or not valid_vector(foe_vel)
		or not valid_number(shot_spd)
		or shot_spd <= epsilon
		or not valid_number(grav)
		or not valid_number(plr_grav)
		or not valid_number(plr_tall)
	then
		local track = foe_core and foe_move[foe_core]
		local last_answer = track and track.lastSolution
		local now_pos = typeof(foe_core) == 'Instance' and foe_core:IsA('BasePart') and foe_core.Position
		if last_answer
			and valid_vector(from2)
			and valid_vector(now_pos)
			and workspace:GetServerTimeNow() - last_answer.time < 0.08
			and math.abs(last_answer.projectileSpeed - shot_spd) < 0.01
			and math.abs(last_answer.gravity - grav) < 0.01
			and (last_answer.origin - from2).Magnitude < 4
			and (last_answer.targetPosition - now_pos).Magnitude < 6
		then
			return from2 + last_answer.velocity, last_answer.impact, last_answer.travelTime
		end
		if strict then
			return nil
		end
		return foe_pos, foe_pos
	end
	if not valid_vector(foe_core_pos) then
		foe_core_pos = foe_pos
	end
	local body_aim = false
	if (foe_pos - foe_core_pos).Magnitude < 0.1 then
		foe_pos += Vector3.new(0, aim_lift, 0)
		body_aim = true
	end
	local foe_shift = foe_pos - foe_core_pos
	if type(foe_inair) ~= 'boolean' then
		foe_inair = nil
	end
	if foe_inair == nil then
		foe_inair = math.abs(foe_vel.Y) > 0.01
	end

	local move = get_foe_move(foe_core, foe_core_pos, foe_vel, foe_inair, plr_grav)
	if move.invalid and strict then
		return nil
	end
	foe_core_pos = move.position
	foe_pos = foe_core_pos + foe_shift
	foe_vel = move.velocity
	local answer_foe_pos = foe_core_pos
	local seen_pos, seen_vel = foe_pos, foe_vel
	if leftover_count >= 8 then
		local ahead = foe_vel * flat_mask
		if ahead.Magnitude > 6 then
			foe_pos -= ahead.Unit * math.clamp(leftover_scatter * 0.5, 0, 2)
		end
	end
	local ahead_trust = 1
	local miss_rate = move.missRate
	if miss_rate and miss_rate > epsilon and not move.knockback then
		local spd = (foe_vel * flat_mask).Magnitude
		if spd > epsilon then
			ahead_trust = (spd * spd) / (spd * spd + miss_rate * miss_rate)
		end
	end
	local foe_accel = Vector3.zero
	if plr_grav > 0 and (foe_inair or foe_vel.Y < -1) and not move.flying then
		foe_accel = Vector3.new(0, -plr_grav, 0)
	end
	local flat_accel = move.acceleration
	local flat_vel = foe_vel * flat_mask
	local stop_t
	if flat_accel.Magnitude > epsilon and flat_vel.Magnitude > epsilon then
		local slowdown = flat_accel:Dot(flat_vel.Unit)
		stop_t = math.abs(slowdown) > epsilon and -flat_vel.Magnitude / slowdown or nil
		if not valid_number(stop_t) or stop_t <= epsilon or stop_t > 0.35 then
			flat_accel = Vector3.zero
			stop_t = nil
		end
	end

	local zig_mid, zig_left, zig_vel
	if move.strafeHalf and (move.strafeSeen or 0) >= 2 then
		if flat_vel.Magnitude > 4 then
			zig_mid, zig_vel = move.strafeHalf, flat_vel
		elseif move.strafeDirection and (move.strafeSpeed or 0) > 4 then
			zig_mid, zig_vel = move.strafeHalf, move.strafeDirection * move.strafeSpeed
		end
		if zig_mid then
			zig_left = math.clamp(zig_mid - (move.strafeElapsed or 0), 0, zig_mid)
		end
	end

	local turn_rate
	if not zig_mid
		and (move.turnSeen or 0) >= 4
		and valid_number(move.turnRate)
		and flat_vel.Magnitude > 5
		and flat_accel.Magnitude <= epsilon
	then
		turn_rate = math.clamp(move.turnRate, -5, 5)
		if math.abs(turn_rate) < 0.25 then
			turn_rate = nil
		end
	end

	local hop_vel, hop_period, climb_step
	if not plr_hop and move.state and (move.state.jumpSeen or 0) >= 2 and move.state.jumpPeriod and workspace:GetServerTimeNow() - (move.state.jumpStart or 0) < move.state.jumpPeriod * 1.5 then
		plr_hop = move.state.jumpVelocity
	end
	if not plr_hop and (foe_vel * flat_mask).Magnitude > 8 then
		plr_hop = 42.6
	end
	if not plr_hop and move.state and move.state.leaping then
		plr_hop = move.state.jumpVelocity or 42.6
	end
	if valid_number(plr_hop) and plr_hop > 0 and plr_grav > 0 and not move.flying then
		hop_vel = plr_hop
		local seen = move.state and move.state.jumpVelocity
		if valid_number(seen) and seen > 0 then
			hop_vel = math.clamp(seen, plr_hop * 0.6, plr_hop * 1.6)
		end
		local period = move.state and move.state.jumpPeriod
		if valid_number(period) and period > 0 then
			hop_period = period
		end
		local climb = move.state and move.state.climbStep
		if hop_period
			and valid_number(climb)
			and (move.state.climbSeen or 0) >= 1
			and climb < hop_vel * hop_vel / (2 * plr_grav)
			and workspace:GetServerTimeNow() - (move.state.jumpStart or -math.huge) < hop_period * 2
		then
			climb_step = climb
		end
	end

	local ground_y2, landing_t, ground_limit
	if plr_tall > 0 then
		local ground_y = trace_ground(foe_core_pos, cast, foe_core)
		local jump_state = move.state
		if not ground_y
			and foe_inair
			and plr_grav > 0
			and not move.knockback
			and not move.flying
			and jump_state
			and jump_state.jumpBase
			and jump_state.jumpStart
			and workspace:GetServerTimeNow() - jump_state.jumpStart < 2 * (jump_state.jumpVelocity or 42.6) / plr_grav + 0.3
			and foe_core_pos.Y > jump_state.jumpBase - 3
		then
			ground_y = jump_state.jumpBase - plr_tall
		end
		if not ground_y and plr_grav > 0 and not move.flying and foe_accel.Y == 0 then
			foe_accel = Vector3.new(0, -plr_grav, 0)
		end
		if ground_y then
			ground_limit = ground_y + plr_tall + foe_shift.Y
			if foe_inair and not move.knockback and not move.flying and math.abs(foe_vel.Y) < 1 and foe_core_pos.Y - (ground_y + plr_tall) < 0.6 then
				foe_inair = false
				foe_accel = Vector3.zero
			end
		end
		if ground_y and (foe_accel.Y < 0 or hop_vel) and not move.flying then
			local landing, grounded = calc_landing_t(foe_core_pos.Y, ground_y + plr_tall, foe_vel.Y, plr_grav)
			local flat = foe_vel * flat_mask
			local ground_route = not move.knockback and not move.flying and get_key_route(move.state, workspace:GetServerTimeNow())
			if landing and flat.Magnitude * landing > 2 then
				local settled
				for step = 1, 4 do
					local one_t = landing * (step / 4)
					local one_ground = trace_ground(foe_core_pos + (ground_route and key_displacement(ground_route, one_t) or flat * one_t), cast, foe_core)
					if one_ground then
						local tall = foe_core_pos.Y + foe_vel.Y * one_t - plr_grav * (0.5 * one_t * one_t)
						if tall <= one_ground + plr_tall then
							local solved = calc_landing_t(foe_core_pos.Y, one_ground + plr_tall, foe_vel.Y, plr_grav)
							if solved then
								ground_y = one_ground
								landing = solved
								settled = true
								break
							end
						end
					end
				end

				if not settled then
					local drifted = trace_ground(foe_core_pos + (ground_route and key_displacement(ground_route, landing) or flat * landing), cast, foe_core)
					if drifted and math.abs(drifted - ground_y) > epsilon then
						ground_y = drifted
						landing, grounded = calc_landing_t(foe_core_pos.Y, ground_y + plr_tall, foe_vel.Y, plr_grav)
					end
				end
			end

			if climb_step and foe_inair and move.state.jumpBase then
				local raised = move.state.jumpBase + climb_step - plr_tall
				local rising = math.max(foe_vel.Y, 0)
				if ground_y < raised - climb_step * 0.5 and foe_core_pos.Y + rising * rising / (2 * plr_grav) >= raised + plr_tall then
					ground_y = raised
					landing, grounded = calc_landing_t(foe_core_pos.Y, ground_y + plr_tall, foe_vel.Y, plr_grav)
				end
			end

			if grounded then
				foe_core_pos = Vector3.new(foe_core_pos.X, ground_y + plr_tall, foe_core_pos.Z)
				foe_pos = foe_core_pos + foe_shift
				foe_vel = Vector3.new(foe_vel.X, 0, foe_vel.Z)
				foe_accel = Vector3.zero
				if hop_vel then
					ground_y2 = ground_y + plr_tall + foe_shift.Y
					landing_t = 0
				end
			else
				ground_y2 = ground_y + plr_tall + foe_shift.Y
				landing_t = landing
			end
		end
	end

	if ground_y2 and (hop_vel or foe_inair) and not move.flying then
		if body_aim then
			ground_y2 += cover_lift - foe_shift.Y
		end
		hop_vel = nil
	end

	local lag = aimlib.getlag() + (move.stale or 0)
	local shot_accel = Vector3.new(0, -grav, 0)
	local pos_at_t
	local t2
	local rhythm = move.state and move.state.pattern
	local key_route = not move.knockback and not move.flying and get_key_route(move.state, workspace:GetServerTimeNow())
	if move.knockback and move.impulse and move.knockbackBase then
		local base_pos = foe_pos
		local base_vel = move.knockbackBase
		local push = move.impulse
		local decay = math.max(move.decay or 1.8, epsilon)
		pos_at_t = function(val)
			local sum = lag + val
			local flat_shift = base_vel * sum + push * ((1 - math.exp(-decay * sum)) / decay)
			local vert = landing_t and sum >= landing_t
				and ground_y2
				or base_pos.Y + foe_vel.Y * sum + foe_accel.Y * (0.5 * sum * sum)
			return Vector3.new(base_pos.X + flat_shift.X, vert, base_pos.Z + flat_shift.Z)
		end
		t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
	elseif move.expectedImpulse and move.expectedTime then
		local base_pos = foe_pos
		local base_vel = flat_vel
		local push = move.expectedImpulse
		local decay = math.max(move.decay or (foe_inair and 1.8 or 3.5), epsilon)
		local push_wait = math.max(move.expectedTime - workspace:GetServerTimeNow(), 0) + lag
		local lift = valid_number(move.expectedLift) and move.expectedLift > epsilon and move.expectedLift or nil
		pos_at_t = function(val)
			local sum = lag + val
			local flat_shift = base_vel * sum
			if sum > push_wait then
				local since2 = sum - push_wait
				flat_shift += push * ((1 - math.exp(-decay * since2)) / decay)
			end
			local vert = landing_t and sum >= landing_t
				and ground_y2
				or base_pos.Y + foe_vel.Y * sum + foe_accel.Y * (0.5 * sum * sum)
			if lift and sum > push_wait then
				local since2 = sum - push_wait
				vert += math.max(lift * since2 - plr_grav * (0.5 * since2 * since2), 0)
			end
			return Vector3.new(base_pos.X + flat_shift.X, vert, base_pos.Z + flat_shift.Z)
		end
		t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
	elseif key_route then
		pos_at_t = function(val)
			local sum = lag + val
			local shift = key_displacement(key_route, sum)
			local vert
			if landing_t and ground_y2 and sum >= landing_t then
				vert = ground_y2
			else
				vert = foe_pos.Y + foe_vel.Y * sum + foe_accel.Y * (0.5 * sum * sum)
				if ground_y2 then
					vert = math.max(vert, ground_y2 - 1)
				end
			end
			return Vector3.new(foe_pos.X + shift.X, vert, foe_pos.Z + shift.Z)
		end
		ahead_trust = 1
		t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
	elseif rhythm and rhythm.period and (rhythm.seen or 0) >= 2 then
		local phase = math.max(workspace:GetServerTimeNow() - rhythm.time, 0)
		local prev = rhythm_displacement(rhythm, phase)
		pos_at_t = function(val)
			local sum = lag + val
			local shift = rhythm_displacement(rhythm, phase + sum) - prev
			local vert
			if landing_t and ground_y2 and sum >= landing_t then
				vert = ground_y2
			else
				vert = foe_pos.Y + foe_vel.Y * sum + foe_accel.Y * (0.5 * sum * sum)
			end
			return Vector3.new(foe_pos.X + shift.X, vert, foe_pos.Z + shift.Z)
		end
		ahead_trust = 1
		t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
	elseif zig_mid then
		local base_pos = foe_pos
		local base_vert = foe_vel.Y
		local flat = zig_vel
		local mid, left = zig_mid, zig_left
		pos_at_t = function(val)
			local sum = lag + val
			local shift = flat * zig_displacement(sum, left, mid)
			local vert
			if landing_t and ground_y2 and sum >= landing_t then
				vert = ground_y2
			else
				vert = base_pos.Y + base_vert * sum + foe_accel.Y * (0.5 * sum * sum)
			end
			return Vector3.new(base_pos.X + shift.X, vert, base_pos.Z + shift.Z)
		end
		t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
	elseif turn_rate then
		local base_pos = foe_pos
		local base_vert = foe_vel.Y
		local spd_along = flat_vel.Magnitude
		local unit = flat_vel.Unit
		local normal = Vector3.new(-unit.Z, 0, unit.X)
		local radius = spd_along / turn_rate
		local sweep_limit = math.min(2.6 / math.abs(turn_rate), 0.1 * (move.turnSeen or 4))
		pos_at_t = function(val)
			local sum = lag + val
			local swept = math.min(sum, sweep_limit) * turn_rate
			local shift = unit * (radius * math.sin(swept)) + normal * (radius * (1 - math.cos(swept)))
			if sum > sweep_limit then
				local heading = unit * math.cos(swept) + normal * math.sin(swept)
				shift += heading * (spd_along * (sum - sweep_limit))
			end
			local vert
			if landing_t and ground_y2 and sum >= landing_t then
				vert = ground_y2
			else
				vert = base_pos.Y + base_vert * sum + foe_accel.Y * (0.5 * sum * sum)
			end
			return Vector3.new(base_pos.X + shift.X, vert, base_pos.Z + shift.Z)
		end
		t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
	else
		if lag > epsilon then
			local flat_t = stop_t and math.min(lag, stop_t) or lag
			local flat_shift = flat_vel * flat_t + flat_accel * (0.5 * flat_t * flat_t)
			foe_core_pos += flat_shift
			foe_pos += flat_shift
			if stop_t and lag >= stop_t then
				foe_vel = Vector3.new(0, foe_vel.Y, 0)
				flat_vel = Vector3.zero
				flat_accel = Vector3.zero
				stop_t = nil
			else
				flat_vel += flat_accel * lag
				foe_vel = Vector3.new(flat_vel.X, foe_vel.Y, flat_vel.Z)
				if stop_t then
					stop_t -= lag
				end
			end

			if landing_t and lag >= landing_t then
				foe_pos = Vector3.new(foe_pos.X, ground_y2, foe_pos.Z)
				foe_vel = Vector3.new(foe_vel.X, 0, foe_vel.Z)
				foe_accel = Vector3.zero
				landing_t = nil
			else
				local vert_shift = Vector3.new(0, foe_vel.Y * lag + foe_accel.Y * (0.5 * lag * lag), 0)
				foe_core_pos += vert_shift
				foe_pos += vert_shift
				foe_vel += Vector3.new(0, foe_accel.Y * lag, 0)
				if landing_t then
					landing_t -= lag
				end
			end
		end

		local displacement = foe_pos - from2
		if displacement:Dot(displacement) <= epsilon then
			return foe_pos, foe_pos, 0
		end

		local relative_accel = foe_accel - shot_accel
		if stop_t then
			pos_at_t = function(val)
				local flat_t = math.min(val, stop_t)
				local flat_shift = flat_vel * flat_t + flat_accel * (0.5 * flat_t * flat_t)
				local vert = landing_t and val >= landing_t
					and ground_y2
					or foe_pos.Y + foe_vel.Y * val + foe_accel.Y * (0.5 * val * val)
				return Vector3.new(foe_pos.X + flat_shift.X, vert, foe_pos.Z + flat_shift.Z)
			end
			t2 = calc_move_t(from2, shot_spd, shot_accel, pos_at_t, lo_t)
		else
			t2 = calc_intercept_t(displacement, foe_vel, relative_accel, shot_spd, lo_t)
		end
		if not pos_at_t and landing_t and (not t2 or t2 > landing_t) then
			local landed_pos = Vector3.new(foe_pos.X, ground_y2, foe_pos.Z)
			local landed_vel = Vector3.new(foe_vel.X, 0, foe_vel.Z)
			t2 = calc_intercept_t(landed_pos - from2, landed_vel, -shot_accel, shot_spd, math.max(landing_t, lo_t or 0))
		end
	end

	if t2 and valid_number(t2) and t2 > epsilon then
		local future_foe
		if pos_at_t then
			future_foe = pos_at_t(t2)
		elseif landing_t and t2 > landing_t then
			future_foe = Vector3.new(
				foe_pos.X + foe_vel.X * t2,
				ground_y2,
				foe_pos.Z + foe_vel.Z * t2
			)
		else
			future_foe = foe_pos + foe_vel * t2 + foe_accel * (0.5 * t2 * t2)
		end
		local fire_vel = (future_foe - from2 - shot_accel * (0.5 * t2 * t2)) / t2
		if ground_limit and valid_vector(future_foe) and future_foe.Y < ground_limit then
			future_foe = Vector3.new(future_foe.X, ground_limit, future_foe.Z)
			local ground_vel, ground_t = calc_static_fire(from2, future_foe, shot_spd, shot_accel)
			if ground_vel and ground_t then
				fire_vel, t2 = ground_vel, ground_t
			end
		end
		local rise_log = move.state and move.state.riseLog
		if rise_log and #rise_log >= 4 and ground_limit and not move.knockback and not move.flying and foe_vel.Y > 2
			and (seen_vel * flat_mask).Magnitude < 8 and foe_core_pos.Y + foe_shift.Y - ground_limit <= 1.5 and valid_vector(future_foe) then
			local first, last = rise_log[1], rise_log[#rise_log]
			local span = last[2] - first[2]
			local rate = span >= 0.3 and (last[1] - first[1]) / span or 0
			if rate > 4 then
				local tower_y = foe_core_pos.Y + foe_shift.Y + rate * (lag + t2)
				if future_foe.Y < tower_y then
					future_foe = Vector3.new(future_foe.X, tower_y, future_foe.Z)
					local tower_vel, tower_t = calc_static_fire(from2, future_foe, shot_spd, shot_accel)
					if tower_vel and tower_t then
						fire_vel, t2 = tower_vel, tower_t
					end
				end
			end
		end
		if climb_step and hop_period and hop_period > 0 and move.state and move.state.jumpBase and move.state.jumpStart and valid_vector(future_foe) then
			local since = math.max(workspace:GetServerTimeNow() - move.state.jumpStart + lag + t2, 0)
			local cycles = math.floor(since / hop_period)
			local phase = since - cycles * hop_period
			local climb_jump = move.state.jumpVelocity or 42.6
			local climb_y = move.state.jumpBase + foe_shift.Y + cycles * climb_step + math.max(climb_jump * phase - 0.5 * plr_grav * phase * phase, 0)
			if future_foe.Y < climb_y then
				future_foe = Vector3.new(future_foe.X, climb_y, future_foe.Z)
				local climb_vel, climb_t = calc_static_fire(from2, future_foe, shot_spd, shot_accel)
				if climb_vel and climb_t then
					fire_vel, t2 = climb_vel, climb_t
				end
			end
		end
		if zig_mid and zig_vel and not move.knockback and valid_vector(future_foe) then
			local weight = math.clamp((lag + t2) / zig_mid - 1, 0, 1)
			if weight > 0 then
				local center = seen_pos + zig_vel * (zig_left - zig_mid * 0.5)
				local blended = Vector3.new(future_foe.X, 0, future_foe.Z):Lerp(Vector3.new(center.X, 0, center.Z), weight)
				future_foe = Vector3.new(blended.X, future_foe.Y, blended.Z)
				local zig_fire, zig_t = calc_static_fire(from2, future_foe, shot_spd, shot_accel)
				if zig_fire and zig_t then
					fire_vel, t2 = zig_fire, zig_t
				end
			end
		end
		local hop_state = move.state
		if not climb_step and ground_limit and not move.knockback and not move.flying and plr_grav > 0 and hop_state and (hop_state.jumpSeen or 0) >= 2 and hop_state.jumpPeriod and hop_state.jumpStart and valid_vector(future_foe) then
			local period = hop_state.jumpPeriod
			local jv = hop_state.jumpVelocity or 42.6
			local since = workspace:GetServerTimeNow() - hop_state.jumpStart + lag + t2
			if period > 0 and since < period * 3 then
				local phase = since % period
				local air_t = 2 * jv / plr_grav
				local arc = phase < air_t and math.max(jv * phase - 0.5 * plr_grav * phase * phase, 0) or 0
				local hop_y = ground_limit + arc
				if future_foe.Y < hop_y - 0.3 then
					future_foe = Vector3.new(future_foe.X, hop_y, future_foe.Z)
					local hop_fire, hop_t = calc_static_fire(from2, future_foe, shot_spd, shot_accel)
					if hop_fire and hop_t then
						fire_vel, t2 = hop_fire, hop_t
					end
				end
			end
		end
		if foe_accel.Y < 0 and valid_vector(future_foe) and (not ground_limit or future_foe.Y > ground_limit + 0.05) then
			local fall_g = -foe_accel.Y
			local span = lag + t2
			local vy0 = foe_vel.Y
			if vy0 - fall_g * span < -TERMINAL_FALL then
				local t_cap = math.max((vy0 + TERMINAL_FALL) / fall_g, 0)
				local free = vy0 * span - 0.5 * fall_g * span * span
				local capped = vy0 * t_cap - 0.5 * fall_g * t_cap * t_cap - TERMINAL_FALL * (span - t_cap)
				local lift = capped - free
				if lift > 0.05 then
					future_foe = future_foe + Vector3.new(0, lift, 0)
					local cap_vel, cap_t = calc_static_fire(from2, future_foe, shot_spd, shot_accel)
					if cap_vel and cap_t then
						fire_vel, t2 = cap_vel, cap_t
					end
				end
			end
		end

		local trust = ahead_trust
		if trust < 1 and valid_vector(future_foe) then
			local present = pos_at_t and pos_at_t(0) or foe_pos
			if not valid_vector(present) then
				present = foe_pos
			end
			local damped = Vector3.new(
				present.X + (future_foe.X - present.X) * trust,
				future_foe.Y,
				present.Z + (future_foe.Z - present.Z) * trust
			)
			local damped_vel, damped_t = calc_static_fire(from2, damped, shot_spd, shot_accel)
			if damped_vel and damped_t then
				future_foe, fire_vel, t2 = damped, damped_vel, damped_t
			end
		end
		local forecast_t = t2
		local bucket = t2 + lag < 0.3 and 1 or t2 + lag < 0.7 and 2 or 3
		local candidates = {
			future_foe - foe_shift,
			seen_pos + seen_vel * (lag + t2) - foe_shift,
			seen_pos + seen_vel * lag - foe_shift
		}
		local scores = move.state and move.state.scores and move.state.scores[bucket]
		if scores and scores.count >= 5 and scores[1] > 1 and not key_route and not move.knockback and not move.expectedImpulse and not (rhythm and rhythm.period and (rhythm.seen or 0) >= 2) then
			local selected, loss = 1, scores[1] * 0.8
			for i2 = 2, 3 do
				if scores[i2] < loss then
					selected, loss = i2, scores[i2]
				end
			end
			if selected ~= 1 then
				local vel = selected == 2 and seen_vel * flat_mask or Vector3.zero
				local present = seen_pos + seen_vel * lag
				local function alternative(val)
					local vert
					if pos_at_t then
						vert = pos_at_t(val).Y
					elseif landing_t and val >= landing_t then
						vert = ground_y2
					else
						vert = foe_pos.Y + foe_vel.Y * val + foe_accel.Y * (0.5 * val * val)
					end
					local point = present + vel * val
					return Vector3.new(point.X, vert, point.Z)
				end
				local solved = calc_move_t(from2, shot_spd, shot_accel, alternative, lo_t)
				if solved then
					t2 = solved
					future_foe = alternative(t2)
					fire_vel = (future_foe - from2 - shot_accel * (0.5 * t2 * t2)) / t2
				end
			end
		end
		if valid_vector(future_foe)
			and valid_vector(fire_vel)
			and math.abs(fire_vel.Magnitude - shot_spd) < math.max(0.05, shot_spd * 0.002)
		then
			local track = move.state
			if track then
				local now2 = workspace:GetServerTimeNow()
				track.lastSolution = {
					gravity = grav,
					impact = future_foe,
					origin = from2,
					projectileSpeed = shot_spd,
					targetPosition = answer_foe_pos,
					time = now2,
					travelTime = t2,
					velocity = fire_vel
				}
				if now2 - (track.gradeTime or -math.huge) >= 0.1 then
					track.gradeTime = now2
					track.pending = track.pending or {}
					if #track.pending >= 16 then
						table.remove(track.pending, 1)
					end
					table.insert(track.pending, {
						arrival = now2 + forecast_t + lag,
						horizon = forecast_t + lag,
						position = candidates[1],
						candidates = candidates,
						bucket = bucket
					})
				end
			end
			return from2 + fire_vel, future_foe, t2
		end
	end

	local last_answer = move.state and move.state.lastSolution
	if last_answer
		and not move.changed
		and not move.knockback
		and workspace:GetServerTimeNow() - last_answer.time < 0.08
		and math.abs(last_answer.projectileSpeed - shot_spd) < 0.01
		and math.abs(last_answer.gravity - grav) < 0.01
		and (last_answer.origin - from2).Magnitude < 4
		and (last_answer.targetPosition - answer_foe_pos).Magnitude < 6
	then
		return from2 + last_answer.velocity, last_answer.impact, last_answer.travelTime
	end

	if strict then
		return nil
	end
	return foe_pos, foe_pos
end

aimlib.GetSpawnPosition = function(position_from, aim_point, rel_x, rel_y, rel_z)
	if typeof(position_from) ~= 'Vector3' or typeof(aim_point) ~= 'Vector3' then
		return position_from
	end
	if (aim_point - position_from).Magnitude <= 1e-6 then
		return position_from
	end
	return (CFrame.new(position_from, aim_point) * CFrame.new(rel_x or 0.8, rel_y or -0.6, rel_z or 0)).Position
end

aimlib.GetLatencyLead = function()
	return math.clamp(aimlib.getlag() * 0.5 + 0.04, 0.02, 0.35)
end

local inner_solve = aimlib.SolveTrajectory
aimlib.SolveTrajectory = function(from, spd, grav, foe_pos, foe_vel, plr_grav, tall, hop, cast, inair, core_pos, core, lo_t, strict, ...)
	spd = tonumber(spd) or 0
	if spd > 0 and typeof(from) == 'Vector3' and typeof(foe_pos) == 'Vector3' and typeof(foe_vel) == 'Vector3' and foe_vel.Y < -2 and inair ~= false then
		local below = aimlib.Raycast(foe_pos - Vector3.new(0, 4, 0), Vector3.new(0, -400, 0), cast)
		local core_inst = typeof(core) == 'Instance' and core or typeof(core_pos) == 'Instance' and core_pos or nil
		local track = core_inst and foe_move[core_inst]
		local base_y = typeof(core_pos) == 'Vector3' and core_pos.Y or core_inst and core_inst.Position.Y or foe_pos.Y
		local fall_g = math.max(tonumber(plr_grav) or workspace.Gravity, 1)
		local jumped = track and track.jumpStart and track.jumpBase
			and workspace:GetServerTimeNow() - track.jumpStart < 2 * (track.jumpVelocity or 42.6) / fall_g + 0.3
			and base_y > track.jumpBase - 3
		if not below and not jumped then
			local g = tonumber(plr_grav) or workspace.Gravity
			local drop = tonumber(grav) or 0
			local lead = math.clamp(aimlib.getlag() * 0.5 + 0.03, 0.02, 0.3)
			local t = (foe_pos - from).Magnitude / spd
			local aim, spot = foe_pos, foe_pos
			for _ = 1, 8 do
				local tt = t + lead
				local fall = foe_vel.Y * tt - 0.5 * g * tt * tt
				if g > 0 and foe_vel.Y - g * tt < -TERMINAL_FALL then
					local t_cap = math.max((foe_vel.Y + TERMINAL_FALL) / g, 0)
					fall = foe_vel.Y * t_cap - 0.5 * g * t_cap * t_cap - TERMINAL_FALL * (tt - t_cap)
				end
				spot = foe_pos + Vector3.new(foe_vel.X * tt, fall, foe_vel.Z * tt)
				local need = spot - from + Vector3.new(0, 0.5 * drop * t * t, 0)
				aim = from + need
				t = need.Magnitude / spd
			end
			return aim, spot, t
		end
	end
	return inner_solve(from, spd, grav, foe_pos, foe_vel, plr_grav, tall, hop, cast, inair, core_pos, core, lo_t, strict, ...)
end

return aimlib
