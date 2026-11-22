-- Camp Saves: the camp's decoration saves wait until you're done decorating.
--
-- The game (components/decormanager.lua): every decoration picked up or placed
-- pushes "on_decor_dirty" on TheWorld; DecorManager's listener marks it dirty,
-- and its task every 10 s then calls TheSaveSystem:SaveAll() (every local
-- character, the camp, the other save files, the camp's room): one frame of
-- about 80-110 ms each time while you decorate.
--
-- Here: the game's listener is taken off (found and checked where the game put
-- it) and this one put on instead.
--  * a change while someone is in build mode (PlayerController:
--    IsPlacingOrRemoving) is held
--  * held changes are saved with the game's own TheSaveSystem:SaveAll():
--    wait_after_build_mode seconds after build mode ends (TheWorld's
--    "stopplacing" / "stop_prop_remover", the game's own events), when the pause
--    menu opens (quitting to the main menu from there saves nothing in the
--    game), or after max_wait seconds in build mode at most
--  * a change outside build mode (a refund at load, another player): the
--    game's way (its own flag, its 10 s check)
-- Not needed for the other ways out of camp: starting a run saves the camp's
-- room and everything else (WorldMap:StartRun), quitting saves all
-- (SaveAndShutdown).
-- Safety: any error turns the mod off for the session and hands everything
-- held back to the game's flag (saved at its next 10 s check); if the game's
-- listener isn't where it should be, nothing is changed (the game's way).
-- Cost: nothing runs outside build mode; a change, the end of build mode and
-- the pause menu each do a few table reads.
local CS = {}

CS.TAG = "[Camp Saves]"
CS.DEFAULTS = {
	enabled = true,
	wait_after_build_mode = 2,
	max_wait = 180,
	save_on_pause = true,
	debug = false,
}
CS.settings = nil
CS.warnings = {}

CS.mgr = nil        -- the game's DecorManager
CS.inst = nil       -- its entity (the town world)
CS.source = nil     -- where its listener was (TheWorld)
CS.game_fn = nil    -- the game's own listener (put back on when the mod goes off)
CS.pending = false  -- changes held
CS.changes = 0
CS.first = nil      -- time of the first held change
CS.task_wait = nil
CS.task_max = nil
CS.off = nil        -- why the mod went off this session
CS.saves = 0

function CS.Log(msg)
	print(CS.TAG .. " " .. tostring(msg))
end

function CS.Debug(msg)
	if CS.settings ~= nil and CS.settings.debug then
		CS.Log(msg)
	end
end

local function Now()
	local gt = rawget(_G, "GetTime")
	return type(gt) == "function" and gt() or os.clock()
end

----------------------------------------------------------------------------
-- settings

local function Warn(key, v, default)
	CS.warnings[#CS.warnings + 1] = string.format("setting %s = %s isn't valid, using %s", key, tostring(v), tostring(default))
end

function CS.LoadSettings(user)
	CS.warnings = {}
	local s = {}
	for k, v in pairs(CS.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if CS.DEFAULTS[k] ~= nil then
				s[k] = v
			else
				CS.warnings[#CS.warnings + 1] = "setting " .. tostring(k) .. " isn't one of Camp Saves' (ignored)"
			end
		end
	end
	for _, key in ipairs({ "enabled", "save_on_pause", "debug" }) do
		if type(s[key]) ~= "boolean" then
			Warn(key, s[key], CS.DEFAULTS[key])
			s[key] = CS.DEFAULTS[key]
		end
	end
	local function Num(key, lo, hi)
		local n = tonumber(s[key])
		if n == nil or n ~= n or n < lo or n > hi then
			Warn(key, s[key], CS.DEFAULTS[key])
			n = CS.DEFAULTS[key]
		end
		s[key] = n
	end
	Num("wait_after_build_mode", 0, 60)
	Num("max_wait", 10, 1800)
	CS.settings = s
	return s
end

----------------------------------------------------------------------------
-- the game's state

-- Is anyone placing or removing a decoration (the game's build mode)?
function CS.Editing()
	for _, p in ipairs(rawget(_G, "AllPlayers") or {}) do
		local pc = type(p) == "table" and p.components ~= nil and p.components.playercontroller or nil
		if pc ~= nil and pc.IsPlacingOrRemoving ~= nil and pc:IsPlacingOrRemoving() then
			return true
		end
	end
	return false
end

-- Where inst listens for event with fn (the game's EntityScript tables:
-- inst.eventlistening[event][source] = { { fn = fn }, ... }), among sources.
function CS.FindSource(inst, event, fn, sources)
	local t = inst ~= nil and inst.eventlistening or nil
	local by_source = type(t) == "table" and t[event] or nil
	if type(by_source) ~= "table" then
		return nil
	end
	for _, src in ipairs(sources) do
		local fns = src ~= nil and by_source[src] or nil
		if type(fns) == "table" then
			for _, c in ipairs(fns) do
				if type(c) == "table" and c.fn == fn then
					return src
				end
			end
		end
	end
	return nil
end

----------------------------------------------------------------------------
-- holding and saving

function CS.Cancel()
	if CS.task_wait ~= nil then
		CS.task_wait:Cancel()
		CS.task_wait = nil
	end
	if CS.task_max ~= nil then
		CS.task_max:Cancel()
		CS.task_max = nil
	end
end

-- Save what's held with the game's own save. Returns true if it saved.
function CS.Flush(why)
	if not CS.pending then
		return false
	end
	local n = CS.changes
	CS.pending, CS.changes, CS.first = false, 0, nil
	CS.Cancel()
	local mgr = CS.mgr
	if mgr ~= nil then
		mgr.decor_dirty = false
	end
	local ss = rawget(_G, "TheSaveSystem")
	if ss ~= nil and type(ss.SaveAll) == "function" then
		ss:SaveAll()
		CS.saves = CS.saves + 1
		CS.Log(string.format("saved %d decoration change%s (%s)", n, n == 1 and "" or "s", tostring(why)))
		return true
	end
	-- no save system: the game's own flag (its 10 s check)
	if mgr ~= nil then
		mgr.decor_dirty = true
	end
	return false
end

-- The mod off for the session: what's held goes to the game's flag, and the
-- game's own listener goes back on.
function CS.TurnOff(why)
	if CS.off ~= nil then
		return
	end
	CS.off = tostring(why)
	CS.Log("off for this session after an error (the game's way from here): " .. CS.off)
	pcall(CS.Cancel)
	local mgr, inst, source = CS.mgr, CS.inst, CS.source
	if CS.pending and mgr ~= nil then
		mgr.decor_dirty = true
	end
	CS.pending = false
	if inst ~= nil and source ~= nil then
		pcall(function()
			inst:RemoveEventCallback("on_decor_dirty", CS.onDirty, source)
			if CS.game_fn ~= nil and CS.FindSource(inst, "on_decor_dirty", CS.game_fn, { source }) == nil then
				inst:ListenForEvent("on_decor_dirty", CS.game_fn, source)
			end
		end)
	end
end

-- fn(...) protected; an error turns the mod off (the game's way).
function CS.Call(what, fn, ...)
	if CS.off ~= nil then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		CS.TurnOff(what .. ": " .. tostring(err))
		return false
	end
	return true, err
end

function CS.OnDirty()
	local mgr = CS.mgr
	if not CS.Editing() then
		-- outside build mode: the game's way
		mgr.decor_dirty = true
		return
	end
	CS.changes = CS.changes + 1
	if not CS.pending then
		CS.pending = true
		CS.first = Now()
		CS.Debug("holding the camp's save while you decorate")
	end
	if CS.task_wait ~= nil then
		CS.task_wait:Cancel()
		CS.task_wait = nil
	end
	if CS.task_max == nil then
		CS.task_max = CS.inst:DoTaskInTime(CS.settings.max_wait, function()
			CS.task_max = nil
			CS.Call("the longest wait", CS.Flush, string.format("%d s in build mode", CS.settings.max_wait))
		end)
	end
	CS.Debug(string.format("decoration change held (%d so far)", CS.changes))
end

-- Build mode may have ended (the game's "stopplacing" / "stop_prop_remover").
function CS.OnEditChanged()
	if not CS.pending then
		return
	end
	if CS.Editing() then
		return
	end
	if CS.task_wait ~= nil then
		CS.task_wait:Cancel()
	end
	local function Due()
		CS.task_wait = nil
		if CS.pending and not CS.Editing() then
			CS.Flush("left build mode")
		end
	end
	if CS.settings.wait_after_build_mode <= 0 then
		CS.task_wait = nil
		Due()
		return
	end
	CS.task_wait = CS.inst:DoTaskInTime(CS.settings.wait_after_build_mode, function()
		CS.Call("after build mode", Due)
	end)
end

function CS.OnPause()
	if CS.pending and CS.settings.save_on_pause then
		CS.Flush("pause menu")
	end
end

-- the listeners (kept as fields so they can be taken off)
CS.onDirty = function()
	local ok = CS.Call("a decoration change", CS.OnDirty)
	if not ok and CS.mgr ~= nil then
		CS.mgr.decor_dirty = true -- the game's way for this change too
	end
end
CS.onEditChanged = function()
	CS.Call("build mode ended", CS.OnEditChanged)
end

----------------------------------------------------------------------------
-- install

-- On the game's DecorManager (AddComponentPostInit): its listener swapped for
-- this one. Errors (and changes nothing) if the game's listener isn't where it
-- should be.
local function Need(ok, msg)
	if not ok then
		error(msg, 0)
	end
end

function CS.Attach(mgr, inst)
	Need(type(mgr) == "table" and type(mgr.on_decor_dirty) == "function", "a game update changed DecorManager (no on_decor_dirty)")
	Need(inst ~= nil and inst.ListenForEvent ~= nil and inst.RemoveEventCallback ~= nil and inst.DoTaskInTime ~= nil, "a game update changed the entity functions")
	local world = rawget(_G, "TheWorld")
	local source = CS.FindSource(inst, "on_decor_dirty", mgr.on_decor_dirty, { world, inst })
	Need(source ~= nil, "a game update changed how DecorManager listens (its listener wasn't found)")
	-- a new camp (each load makes a new world): start clean
	pcall(CS.Cancel)
	CS.mgr, CS.inst, CS.source, CS.game_fn = mgr, inst, source, mgr.on_decor_dirty
	CS.pending, CS.changes, CS.first, CS.off = false, 0, nil, nil
	local game_fn = mgr.on_decor_dirty
	-- ours on first, then the game's off: whatever fails, the game's listener
	-- stays (or is put back) and ours comes off
	local ok, err = pcall(function()
		inst:ListenForEvent("on_decor_dirty", CS.onDirty, source)
		inst:ListenForEvent("stopplacing", CS.onEditChanged, source)
		inst:ListenForEvent("stop_prop_remover", CS.onEditChanged, source)
		inst:RemoveEventCallback("on_decor_dirty", game_fn, source)
		if CS.FindSource(inst, "on_decor_dirty", game_fn, { source }) ~= nil then
			error("the game's listener couldn't be taken off")
		end
	end)
	if not ok then
		pcall(function()
			inst:RemoveEventCallback("on_decor_dirty", CS.onDirty, source)
			inst:RemoveEventCallback("stopplacing", CS.onEditChanged, source)
			inst:RemoveEventCallback("stop_prop_remover", CS.onEditChanged, source)
			if CS.FindSource(inst, "on_decor_dirty", game_fn, { source }) == nil then
				inst:ListenForEvent("on_decor_dirty", game_fn, source)
			end
		end)
		CS.mgr, CS.inst, CS.source = nil, nil, nil
		error(err, 0)
	end
	CS.Debug("on the camp's decorations")
	return true
end

return CS
