-- Two Weapons: swap timing (changes nothing). For each swap (the first 40 of
-- a game session), one line in client_log.txt, half a second after the swap:
--   swap #n BOW -> CANNON: <ms in the swap's frame>, Lua memory, the number
--   of listeners on you (it should stay put from swap to swap), entities;
--   by listener: the game's / mods' functions that reacted (file:line, ms);
--   by event: the events the swap set off (nested ones marked ">");
--   later: tasks the swap scheduled (Skill Slots' resync, ...), ms each;
--   HUD stages: the smooth swap's spread-out HUD work, ms each;
--   looks redone: whose look (you / a UI puppet) was rebuilt, weapon only or
--   all of it, and how many frames after the swap;
--   frames: the next 6 frames' lengths (16.7 ms = a smooth 60 a second).
-- The listeners are timed by the smooth swap's own event handling (never by
-- swapping out the game's listener functions: the game removes a listener by
-- matching its function, so a swapped-out one couldn't be removed; 0.6.2 -
-- 0.6.4 left the old weapon's power listeners behind that way).
-- swap_timing = false in the settings: off.
local SwapTiming = {}

SwapTiming.LIMIT = 40
SwapTiming.AFTER_TICKS = 30
SwapTiming.FRAMES = 6
SwapTiming.count = 0
SwapTiming.current = nil -- the latest swap's window (looks redone go there)

local function Clock()
	local os_lib = rawget(_G, "os")
	return os_lib ~= nil and os_lib.clock ~= nil and os_lib.clock() or nil
end

function SwapTiming.Active()
	return SwapTiming.count < SwapTiming.LIMIT and Clock() ~= nil
end

local labels = setmetatable({}, { __mode = "k" })
local function Label(fn)
	local l = labels[fn]
	if l == nil then
		local package_lib = rawget(_G, "package")
		local ss = package_lib ~= nil and package_lib.loaded ~= nil and package_lib.loaded["twoweapons.smoothswap"] or nil
		l = type(ss) == "table" and type(ss.labels) == "table" and ss.labels[fn] or nil
	end
	if l == nil then
		local info = debug.getinfo(fn, "S")
		local src = info ~= nil and tostring(info.short_src or "?") or "?"
		src = src:match("([^/\\]+)$") or src
		l = src .. ":" .. tostring(info ~= nil and info.linedefined or "?")
	end
	labels[fn] = l
	return l
end

-- who called: "file:line < file:line < ..." from the given stack level
local function Callers(level, n)
	local bits = {}
	for i = level, level + n - 1 do
		local info = debug.getinfo(i, "Sl")
		if info == nil then
			break
		end
		local src = tostring(info.short_src or "?"):match("([^/\\]+)$") or "?"
		bits[#bits + 1] = src:gsub('"%]$', "") .. ":" .. tostring(info.currentline)
	end
	return table.concat(bits, " < ")
end

local function Add(t, key, v)
	t[key] = (t[key] or 0) + v
end

local function Top(t, n, min, fmt)
	local list = {}
	for k, v in pairs(t) do
		if v >= (min or 0.5) then
			list[#list + 1] = { k, v }
		end
	end
	table.sort(list, function(a, b)
		if a[2] ~= b[2] then
			return a[2] > b[2]
		end
		return tostring(a[1]) < tostring(b[1])
	end)
	local bits = {}
	for i = 1, math.min(n, #list) do
		bits[#bits + 1] = string.format(fmt or "%s %.1f", (tostring(list[i][1]):gsub("^%s+", "> ")), list[i][2])
	end
	return table.concat(bits, ", ")
end

-- the listeners on the player right now: container -> "event file:line"
function SwapTiming.Listeners(inst)
	local snap = {}
	local all = rawget(inst, "eventlisteners")
	for ev, by_source in pairs(type(all) == "table" and all or {}) do
		for _, fns in pairs(by_source) do
			for _, c in ipairs(fns) do
				snap[c] = tostring(ev) .. " " .. (type(c.fn) == "function" and Label(c.fn) or "?")
			end
		end
	end
	return snap
end

-- listeners added / gone between two snapshots: { ["+event file:line"] = n, ... }
function SwapTiming.ListenerDiff(before, after)
	local diff = {}
	for c, d in pairs(after) do
		if before[c] == nil then
			Add(diff, "+" .. d, 1)
		end
	end
	for c, d in pairs(before) do
		if after[c] == nil then
			Add(diff, "-" .. d, 1)
		end
	end
	return diff
end

local function WeaponType(inst)
	local inv = inst.components ~= nil and inst.components.inventory or nil
	local ok, t = pcall(function() return inv:GetEquippedWeaponType() end)
	return ok and tostring(t) or "?"
end

function SwapTiming.CountListeners(inst)
	local n = 0
	local all = rawget(inst, "eventlisteners")
	for _, by_source in pairs(type(all) == "table" and all or {}) do
		for _, fns in pairs(by_source) do
			n = n + #fns
		end
	end
	return n
end

local function CountEntities()
	local ents = rawget(_G, "Ents")
	if type(ents) ~= "table" then
		return -1
	end
	local n = 0
	for _ in pairs(ents) do
		n = n + 1
	end
	return n
end

-- whose look gets rebuilt after a swap (told by the smooth swap)
function SwapTiming.Trace(inv, weapon_only)
	local w = SwapTiming.current
	if w ~= nil and not w.done then
		local who = inv.inst == w.player and "you" or "other"
		Add(w.looks, string.format("%s %s @%d", who, weapon_only and "weapon" or "all", w.ticks), 1)
		if not weapon_only and w.full_by == nil then
			w.full_by = Callers(4, 6) -- who asked for the first full rebuild
		end
	end
end

-- the listener changes from a swap until the next swap (or 30 frames)
local function CloseListeners(w)
	if w ~= nil and w.listener_diff == nil and w.snap0 ~= nil then
		w.listener_diff = SwapTiming.ListenerDiff(w.snap0, SwapTiming.Listeners(w.player))
		w.snap0 = nil
	end
end

-- Once a session: the build behind each piece of your look, and whether its
-- art file is there. The log fills with "Could not find anim build FROMNUM"
-- (5 at a time: the helmet slot has 5 symbols) at every full look rebuild;
-- this names the piece it comes from.
SwapTiming.builds_logged = false
function SwapTiming.LogBuilds(inst)
	if SwapTiming.builds_logged then
		return
	end
	SwapTiming.builds_logged = true
	local inv = inst.components ~= nil and inst.components.inventory or nil
	if inv == nil or type(inv.equips) ~= "table" or inv._GetEquippedDef == nil then
		return
	end
	local resolve = rawget(_G, "softresolvefilepath")
	local bits = {}
	local slots = {}
	for slot in pairs(inv.equips) do
		slots[#slots + 1] = slot
	end
	table.sort(slots)
	for _, slot in ipairs(slots) do
		local ok, def = pcall(inv._GetEquippedDef, inv, slot)
		local build = ok and def ~= nil and def.build or nil
		if build ~= nil then
			local found = "?"
			if type(resolve) == "function" then
				local ok2, path = pcall(resolve, "anim/" .. tostring(build) .. ".zip")
				found = ok2 and path ~= nil and "found" or "NO FILE"
			end
			bits[#bits + 1] = string.format("%s %s (%s, %s)", slot, tostring(inv.equips[slot]), tostring(build), found)
		end
	end
	local dyer = inst.components.equipmentdyer
	local dyes = {}
	if dyer ~= nil and type(dyer.applied_dyes) == "table" then
		for slot, sets in pairs(dyer.applied_dyes) do
			for set, name in pairs(type(sets) == "table" and sets or {}) do
				dyes[#dyes + 1] = tostring(slot) .. " " .. tostring(set) .. "=" .. tostring(name)
			end
		end
	end
	table.sort(dyes)
	print("[Two Weapons] your look's builds: " .. table.concat(bits, "; ") .. (#dyes > 0 and ("; dyes: " .. table.concat(dyes, ", ")) or ""))
end

-- run fn(...) with the swap's pieces timed; returns fn's results
function SwapTiming.Run(inst, fn, ...)
	SwapTiming.count = SwapTiming.count + 1
	local n = SwapTiming.count
	pcall(SwapTiming.LogBuilds, inst)
	local events, listeners, later = {}, {}, {}
	local from = WeaponType(inst)
	local nlisteners0 = SwapTiming.CountListeners(inst)
	CloseListeners(SwapTiming.current)
	local window = { player = inst, ticks = 0, looks = {}, done = false, snap0 = SwapTiming.Listeners(inst) }
	SwapTiming.current = window

	-- the smooth swap times each listener and event as it handles them
	local ok_ss, SmoothSwap = pcall(require, "twoweapons.smoothswap")
	if ok_ss and type(SmoothSwap) == "table" then
		SmoothSwap.trace = SwapTiming.Trace
		SmoothSwap.probe = {
			Call = function(f, a, b)
				local s = Clock()
				f(a, b)
				Add(listeners, Label(f), (Clock() - s) * 1000)
			end,
			Event = function(ev, ms, depth)
				Add(events, (depth > 0 and "  " or "") .. tostring(ev), ms)
			end,
		}
	end
	-- tasks the swap schedules (they run later): timed when they run
	local had_tasks = {}
	for _, name in ipairs({ "DoTaskInTime", "DoTaskInTicks", "DoTaskInAnimFrames" }) do
		local orig = inst[name]
		if type(orig) == "function" then
			had_tasks[name] = rawget(inst, name) or false
			inst[name] = function(self, t, task_fn, ...)
				if type(task_fn) ~= "function" then
					return orig(self, t, task_fn, ...)
				end
				local label = Label(task_fn)
				return orig(self, t, function(...)
					local s = Clock()
					local results = table.pack(task_fn(...))
					Add(later, label, (Clock() - s) * 1000)
					return table.unpack(results, 1, results.n)
				end, ...)
			end
		end
	end

	-- the frames after the swap; started before it, so each tick is counted
	-- before the tasks the swap schedules run
	local line, last
	local task
	if inst.DoPeriodicTicksTask ~= nil then
		local ticks, frames = 0, {}
		task = inst:DoPeriodicTicksTask(1, function()
			ticks = ticks + 1
			window.ticks = ticks
			local now = Clock()
			if ticks <= SwapTiming.FRAMES then
				frames[#frames + 1] = string.format("%.0f", (now - (last or now)) * 1000)
			end
			last = now
			if ticks >= SwapTiming.AFTER_TICKS then
				task:Cancel()
				window.done = true
				CloseListeners(window)
				local stages = ok_ss and type(SmoothSwap.last) == "table" and Top(SmoothSwap.last, 6, 0) or ""
				local looks = Top(window.looks, 8, 1, "%s x%d")
				local changed = Top(window.listener_diff or {}, 8, 1, "%s x%d")
				print(string.format("[Two Weapons] %s; later: %s; HUD stages: %s; looks redone: %s%s; listeners changed (to the next swap): %s; frames: %s",
					line or "?", Top(later, 6, 0.3), stages ~= "" and stages or "-", looks ~= "" and looks or "-",
					window.full_by ~= nil and (" (first full one by " .. window.full_by .. ")") or "", changed ~= "" and changed or "none",
					table.concat(frames, " ")))
			end
		end)
	end

	local t0, m0 = Clock(), collectgarbage("count")
	local results = table.pack(pcall(fn, ...))
	local total = (Clock() - t0) * 1000
	local mem = collectgarbage("count") - m0
	last = Clock() -- the first frame length: from the swap's end

	for name, had in pairs(had_tasks) do
		inst[name] = had or nil
	end
	if ok_ss and type(SmoothSwap) == "table" then
		SmoothSwap.probe = nil
	end
	local to = WeaponType(inst)
	local nlisteners = SwapTiming.CountListeners(inst)
	line = string.format("swap #%d %s -> %s: %.1f ms, Lua memory %+d KB, listeners on you %d (%+d), entities %d; by listener: %s; by event: %s",
		n, from, to, total, math.floor(mem + 0.5), nlisteners, nlisteners - nlisteners0, CountEntities(),
		Top(listeners, 8, 0.5), Top(events, 6, 0.5))

	if task == nil then
		window.done = true
		print("[Two Weapons] " .. line)
	end

	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

return SwapTiming
