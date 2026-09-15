--[[
	ANTILAG MODULE FOR VAPE V4
	Reduces FPS and ping spikes through optimizations
	- Frame-rate aware task waits
	- HTTP request debouncing
	- Loop optimization
	- Memory efficiency improvements
	- Render performance optimization
]]

local antilag = {}
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

-- Configuration
local CONFIG = {
	OPTIMAL_FRAMETIME = 1/60, -- 60 FPS target
	HTTP_REQUEST_DEBOUNCE = 0.5, -- seconds
	LOOP_THROTTLE_INTERVAL = 0.016, -- ~60 FPS
	MEMORY_CHECK_INTERVAL = 15, -- seconds
	MAX_PENDING_REQUESTS = 2, -- REDUCED from 3 to 2
	RENDER_THROTTLE = 0.016, -- throttle excessive renders
	MAX_FRAME_TIME = 0.05, -- cap frame time at 50ms
	GC_COLLECTION_INTERVAL = 180, -- INCREASED from 120 to 180 seconds
	INCREMENTAL_GC = true, -- use incremental garbage collection
}

-- Internal state
local state = shared.R12SAStandaloneAntilagState or {
	pendingHttpRequests = 0,
	deltaTime = 0,
	lastFrameTime = tick(),
	gcCollectInterval = 0,
	renderFrameCount = 0,
	running = false,
	maintenanceRunning = false
}
shared.R12SAStandaloneAntilagState = state

-- Cache for repeated file operations
local fileCache = {}
local fileCacheCount = 0
local fileCacheMaxSize = 100 -- INCREASED from 50 to 100

local function setCacheEntry(key, data)
	if fileCache[key] == nil then
		fileCacheCount = fileCacheCount + 1
	end
	fileCache[key] = {data = data, timestamp = tick()}
end

local function removeCacheEntry(key)
	if fileCache[key] ~= nil then
		fileCache[key] = nil
		fileCacheCount = math.max(fileCacheCount - 1, 0)
	end
end

--[[ ===== PERFORMANCE MONITORING ===== ]]

function antilag.GetFrameTime()
	return state.deltaTime
end

function antilag.GetFPS()
	return 1 / math.max(state.deltaTime, 0.001)
end

-- Monitor frame times to detect lag - IMPROVED version
if not state.running then
	state.running = true
	task.spawn(function()
		while state.running do
			local currentTime = tick()
			state.deltaTime = math.min(currentTime - state.lastFrameTime, CONFIG.MAX_FRAME_TIME)
			state.lastFrameTime = currentTime
			RunService.RenderStepped:Wait()
			state.renderFrameCount = state.renderFrameCount + 1
		end
	end)
end

--[[ ===== HTTP REQUEST OPTIMIZATION ===== ]]

function antilag.HttpGet(url, noCache)
	while state.pendingHttpRequests >= CONFIG.MAX_PENDING_REQUESTS do
		task.wait(0.1)
	end

	local cache = fileCache[url]
	if cache and not noCache and (tick() - cache.timestamp) < CONFIG.HTTP_REQUEST_DEBOUNCE then
		return cache.data
	end

	state.pendingHttpRequests = state.pendingHttpRequests + 1
	local success, result = pcall(function()
		return game:HttpGet(url)
	end)
	state.pendingHttpRequests = math.max(state.pendingHttpRequests - 1, 0)
	if not success then
		error(result)
	end
	
	if result then
		setCacheEntry(url, result)
	end

	return result
end

--[[ ===== FILE OPTIMIZATION ===== ]]

function antilag.ReadFileOptimized(path)
	local cache = fileCache[path]
	if cache then
		return cache.data
	end

	local success, result = pcall(function()
		return readfile(path)
	end)

	if success and result then
		if fileCache[path] then
			fileCache[path].data = result
			fileCache[path].timestamp = tick()
		else
			if fileCacheCount >= fileCacheMaxSize then
				-- Remove oldest cache entry
				local oldestKey = next(fileCache)
				removeCacheEntry(oldestKey)
			end
			setCacheEntry(path, result)
		end
		return result
	end
	
	return nil
end

function antilag.WriteFileOptimized(path, content)
	local success, err = pcall(function()
		writefile(path, content)
	end)
	
	if success then
		-- Update cache
		setCacheEntry(path, content)
	else
		warn('[ANTILAG] Write file failed: ' .. tostring(err))
	end
	
	return success
end

--[[ ===== LOOP OPTIMIZATION ===== ]]

function antilag.ThrottledWait(customInterval)
	local interval = customInterval or CONFIG.LOOP_THROTTLE_INTERVAL
	
	-- Adaptive wait based on current frame time
	local adjustedInterval = math.max(interval, state.deltaTime)
	if adjustedInterval > 0 then
		task.wait(adjustedInterval)
	else
		RunService.RenderStepped:Wait()
	end
end

function antilag.OptimizedLoop(condition, callback, maxWaitTime)
	maxWaitTime = maxWaitTime or 30
	local startTime = tick()
	
	while condition() do
		if (tick() - startTime) > maxWaitTime then
			warn('[ANTILAG] Loop timeout after ' .. maxWaitTime .. ' seconds')
			break
		end
		
		callback()
		antilag.ThrottledWait()
	end
end

--[[ ===== MEMORY OPTIMIZATION ===== ]]

function antilag.OptimizeMemory()
	-- Limit file cache size
	if fileCacheCount > fileCacheMaxSize * 1.5 then
		fileCache = {}
		fileCacheCount = 0
		-- Tiny incremental step only after dropping cached data. Full collection caused repeated frame spikes.
		if CONFIG.INCREMENTAL_GC then
			collectgarbage('step', 16)
		end
	end
end

-- Periodic cache maintenance. GC only gets a tiny step after cache pressure is relieved.
if not state.maintenanceRunning then
	state.maintenanceRunning = true
	task.spawn(function()
		while state.running do
			task.wait(CONFIG.MEMORY_CHECK_INTERVAL)
			state.gcCollectInterval = state.gcCollectInterval + CONFIG.MEMORY_CHECK_INTERVAL
			
			if state.gcCollectInterval >= CONFIG.GC_COLLECTION_INTERVAL then
				antilag.OptimizeMemory()
				state.gcCollectInterval = 0
			end
		end
		state.maintenanceRunning = false
	end)
end

--[[ ===== EVENT OPTIMIZATION ===== ]]

function antilag.DebounceFunction(func, delay)
	local lastCallTime = 0
	
	return function(...)
		local currentTime = tick()
		if currentTime - lastCallTime >= delay then
			lastCallTime = currentTime
			return func(...)
		end
	end
end

function antilag.ThrottleFunction(func, interval)
	local lastCallTime = 0
	local pending = false
	
	return function(...)
		local currentTime = tick()
		if currentTime - lastCallTime >= interval then
			lastCallTime = currentTime
			pending = false
			return func(...)
		elseif not pending then
			pending = true
			task.delay(interval - (currentTime - lastCallTime), function()
				if pending then
					lastCallTime = tick()
					pending = false
					func(...)
				end
			end)
		end
	end
end

--[[ ===== RENDER OPTIMIZATION ===== ]]

function antilag.ThrottleRender(func, interval)
	local lastRenderTime = 0
	interval = interval or CONFIG.RENDER_THROTTLE
	
	return function(...)
		local currentTime = tick()
		if currentTime - lastRenderTime >= interval then
			lastRenderTime = currentTime
			return func(...)
		end
	end
end

--[[ ===== OPTIMIZATION REPORT ===== ]]

function antilag.GetStatus()
	return {
		fps = antilag.GetFPS(),
		frameTime = state.deltaTime,
		pendingRequests = state.pendingHttpRequests,
		cachedFiles = fileCacheCount,
		renderFrames = state.renderFrameCount,
	}
end

function antilag.PrintStatus()
	local status = antilag.GetStatus()
	print('[ANTILAG] FPS: ' .. math.floor(status.fps) .. ' | Frame Time: ' .. math.floor(status.frameTime * 1000) .. 'ms | Pending Requests: ' .. status.pendingRequests .. ' | Cached Files: ' .. sta[...]
end

--[[ ===== CLEANUP ===== ]]

function antilag.Cleanup()
	fileCache = {}
	fileCacheCount = 0
	state.renderFrameCount = 0
	state.running = false
	state.maintenanceRunning = false
end

return antilag
