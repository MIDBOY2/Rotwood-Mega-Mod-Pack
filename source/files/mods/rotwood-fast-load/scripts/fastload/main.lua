-- Fast Load: the game's file search without the wasted disk checks.
--
-- The game (util.lua softresolvefilepath) finds every art file by trying each
-- entry of package.path in turn, and every mod puts its folder first: for a
-- file the mods don't have, that's one disk check per mod. Every load (town <->
-- run) registers all the game's prefabs again with an empty cache, thousands of
-- files: with 15 mods that took about 10 s a load (5.6 s with 8 mods).
--
-- This lists each mod's folder once per load (TheSim:ListFiles) and answers
-- from the list: the same file is found in the same place, in the same order,
-- only the checks against mod folders that don't have it are skipped. A mod
-- folder that can't be listed is checked on disk like before, and any error
-- falls back to the game's own function.

local Main = {}

Main.TAG = "[Fast Load]"
Main.DEFAULTS = { enabled = true, log = true, quiet_looks = true, quiet_looks_report = true, hidden_hud_fix = true }
Main.LIST_FILES = { FILES = 1, DIRS = 2 } -- util/listfilesenum.lua
Main.MAX_DEPTH = 10

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		local u = nil
		if type(user) == "table" then
			u = user[k] -- (false too: "x and false or nil" would lose it)
		end
		if u ~= nil and type(u) == type(v) then
			s[k] = u
		else
			s[k] = v
		end
	end
	Main.settings = s
	return s
end

function Main.Log(msg)
	print(Main.TAG .. " " .. msg)
end

Main.stats = { skipped = 0, found = 0, checked = 0, listed = 0, unlisted = 0, errors = 0 }
local files_of = {} -- mod root -> set of "dir/file" (lowercase), or false = check on disk

-- "MODS:name\scripts\?.lua" -> "MODS:name" (nil for the game's own entries)
function Main.ModRoot(entry, mods_root)
	local root = string.match(entry, "^(.-)[\\/]scripts[\\/]%?%.lua$")
	if root == nil or root == "" or type(mods_root) ~= "string" or mods_root == "" then
		return nil
	end
	if string.sub(root, 1, #mods_root) ~= mods_root or #root <= #mods_root then
		return nil
	end
	return root
end

-- Every file under a mod folder: { exact = {"dir/File"}, lower = {"dir/file"} }. nil when
-- the folder can't be listed (then it's checked on disk, like the game does).
function Main.ListMod(sim, root)
	-- set["dir/File.ext"] = true as on disk; set.lower["dir/file.ext"] = true
	local set, lower, count = {}, {}, 0
	local function walk(dir, rel, depth)
		local files = sim:ListFiles(dir, "*", Main.LIST_FILES.FILES)
		if type(files) ~= "table" then
			error("ListFiles " .. dir, 0)
		end
		for _, f in ipairs(files) do
			set[rel .. f] = true
			lower[string.lower(rel .. f)] = true
			count = count + 1
		end
		if depth < Main.MAX_DEPTH then
			local dirs = sim:ListFiles(dir, "*", Main.LIST_FILES.DIRS)
			for _, d in ipairs(type(dirs) == "table" and dirs or {}) do
				if d ~= "." and d ~= ".." then
					walk(dir .. "/" .. d, rel .. d .. "/", depth + 1)
				end
			end
		end
	end
	local ok = pcall(walk, (string.gsub(root, "\\", "/")), "", 0)
	-- every mod has a modinfo.lua: no modinfo in the list = the listing didn't work
	if not ok or not lower["modinfo.lua"] then
		return nil
	end
	return { exact = set, lower = lower }, count
end

local function FilesOf(sim, root)
	local set = files_of[root]
	if set == nil then
		local list = Main.ListMod(sim, root)
		set = list or false
		files_of[root] = set
		if list ~= nil then
			Main.stats.listed = Main.stats.listed + 1
		else
			Main.stats.unlisted = Main.stats.unlisted + 1
		end
	end
	return set
end

-- The game's softresolvefilepath (PC part), answering mod folders from their
-- lists. env: package_path, mods_root, exists (kleifileexists or nil), sim.
function Main.Resolve(env, filepath)
	filepath = string.gsub(filepath, "^/", "")
	local key = string.gsub(filepath, "\\", "/")
	-- "./" or "../" in the path: the lists can't tell, ask the disk like the game
	local plain = not (string.find(key, "^%.%.?/") or string.find(key, "/%.%.?/"))
	local exists = env.exists
	for entry in string.gmatch(env.package_path, "([^;]+)") do
		local root = Main.ModRoot(entry, env.mods_root)
		local set = plain and root ~= nil and FilesOf(env.sim, root) or false
		-- in the list: found. In the list in another letter case: ask the disk,
		-- like the game (whether case matters is the disk's call). Not in it: skip.
		local known = set and set.exact[key]
		if set and not known and not set.lower[string.lower(key)] then
			Main.stats.skipped = Main.stats.skipped + 1
		elseif known then
			Main.stats.found = Main.stats.found + 1
			local filename = string.gsub(entry, "scripts\\%?%.lua", filepath)
			return (string.gsub(filename, "\\", "/"))
		else
			local filename = string.gsub(entry, "scripts\\%?%.lua", filepath)
			filename = string.gsub(filename, "\\", "/")
			Main.stats.checked = Main.stats.checked + 1
			if not exists or exists(filename) then
				return filename
			end
		end
	end
	if not exists or exists(filepath) then
		return filepath
	end
	return nil
end

-- G: the game's globals. Returns ok, info.
function Main.Install(G)
	local orig = rawget(G, "softresolvefilepath")
	if type(orig) ~= "function" then
		return false, "softresolvefilepath not found"
	end
	local sim = rawget(G, "TheSim")
	if sim == nil or type(sim.ListFiles) ~= "function" then
		return false, "TheSim:ListFiles not found"
	end
	local platform = rawget(G, "Platform")
	if type(platform) == "table" and type(platform.IsConsole) == "function" and platform.IsConsole() then
		return false, "consoles resolve paths their own way"
	end
	local mods_root = rawget(G, "MODS_ROOT")
	if type(mods_root) ~= "string" or mods_root == "" then
		return false, "MODS_ROOT not found"
	end
	files_of = {}
	local logged = 0
	G.softresolvefilepath = function(filepath, force_path_search, ...)
		if type(filepath) ~= "string" then
			return orig(filepath, force_path_search, ...)
		end
		local env = { package_path = G.package.path, mods_root = mods_root, exists = rawget(G, "kleifileexists"), sim = sim }
		local ok, result = pcall(Main.Resolve, env, filepath)
		if ok then
			return result
		end
		Main.stats.errors = Main.stats.errors + 1
		if logged < 3 then
			logged = logged + 1
			Main.Log("fell back to the game's search for " .. filepath .. ": " .. tostring(result))
		end
		return orig(filepath, force_path_search, ...)
	end
	Main.installed_fn = G.softresolvefilepath
	return true, "mod folders answered from their file lists"
end

-- One line per load in client_log.txt (when the game registers the mods'
-- prefabs, right after its own): how many disk checks were skipped.
function Main.Report()
	local st = Main.stats
	local line = string.format("%d mod-folder checks skipped, %d files found in mods, %d checked on disk, %d mod folders listed%s%s",
		st.skipped, st.found, st.checked, st.listed,
		st.unlisted > 0 and string.format(", %d couldn't be listed (checked on disk)", st.unlisted) or "",
		st.errors > 0 and string.format(", %d fell back to the game's search", st.errors) or "")
	st.skipped, st.found, st.checked, st.errors = 0, 0, 0, 0
	return line
end

return Main
