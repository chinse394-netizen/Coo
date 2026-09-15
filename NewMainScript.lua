-- NewMainScript.lua (patched to load antilag)
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/chinse394-netizen/Coo/'..readfile('Coo/profiles/commit.txt')..'/'..select(1, path:gsub('Coo/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'Coo', 'Coo/games', 'Coo/profiles', 'Coo/assets', 'Coo/libraries', 'Coo/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/chinse394-netizen/Coo')
	end)
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'
	if commit == 'main' or (isfile('Coo/profiles/commit.txt') and readfile('Coo/profiles/commit.txt') or '') ~= commit then
		wipeFolder('Coo')
		wipeFolder('Coo/games')
		wipeFolder('Coo/guis')
		wipeFolder('Coo/libraries')
	end
	writefile('Coo/profiles/commit.txt', commit)
end

-- Attempt to download and load the antilag module (non-fatal)
do
	local ok, err = pcall(function()
		-- Ensure the file is present (downloadFile writes it)
		downloadFile('Coo/libraries/antilag.lua')
		if isfile('Coo/libraries/antilag.lua') then
			-- Load the module safely
			local suc, mod = pcall(function()
				return loadstring(readfile('Coo/libraries/antilag.lua'), 'antilag')()
			end)
			if suc and type(mod) == 'table' then
				-- Expose the module globally for other scripts if desired
				shared.R12SAStandaloneAntilag = mod
				shared.AntiLag = mod
				-- If module has a status printer, run it periodically for monitoring
				if type(mod.PrintStatus) == 'function' then
					spawn(function()
						while true do
							task.wait(15)
							pcall(mod.PrintStatus)
						end
					end)
				end
			else
				warn('[NewMainScript] antilag loaded but did not return a module table or errored:', mod)
			end
		end
	end)
	if not ok then
		warn('[NewMainScript] Failed to download/load antilag:', err)
	end
end

return loadstring(downloadFile('Coo/main.lua'), 'main')()
