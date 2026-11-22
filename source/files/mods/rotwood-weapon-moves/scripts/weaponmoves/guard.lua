-- Bulletproofing (the same file in each of these mods, under its own name).
--
-- The game stops on any script error: it pauses and shows its error screen,
-- and the run is lost. This mod's own code inside the game's code (its
-- hooks, stategraph states, power triggers) runs through these instead: an
-- error is logged (the first few, with the lines it went through) and that
-- one piece is skipped, so the game carries on as if the mod weren't there
-- for that moment.
--
--   local G = require("weaponmoves.guard").Shared("[Mod Name]")
--   local ok, a, b = G.Call("where", fn, ...)  -- ok false: fn errored (logged);
--                                                 up to 5 results
--   local safe = G.Fn("where", fn)             -- the same, as a function
--   State(G.State(args))                       -- a whole state's functions;
--                                                 an error mid-state: to idle
-- No table is made a call (these run on every press / frame / hit).

local Guard = {}

Guard.LIMIT = 8

local function Trace(err)
	if debug ~= nil and debug.traceback ~= nil then
		return debug.traceback(tostring(err), 2)
	end
	return tostring(err)
end
Guard.Trace = Trace

-- the message and the first few Lua lines it went through (not the C ones)
function Guard.Short(trace)
	local lines = {}
	for line in tostring(trace):gmatch("[^\n]+") do
		line = line:gsub("^%s+", "")
		if #lines == 0 or (line ~= "stack traceback:" and not line:find("^%[C%]")) then
			lines[#lines + 1] = line
		end
		if #lines >= 4 then
			break
		end
	end
	return table.concat(lines, " | ")
end

function Guard.New(tag, limit)
	local g = { tag = tag, errors = 0, limit = limit or Guard.LIMIT, on = true }

	function g.Error(where, trace)
		g.errors = g.errors + 1
		if g.errors <= g.limit then
			print(string.format("%s error in %s (skipped; the game carries on): %s", g.tag, tostring(where), Guard.Short(trace)))
			if g.errors == g.limit then
				print(g.tag .. " (more errors after this aren't logged)")
			end
		end
	end

	-- ok, then up to five results (more are dropped: no table a call)
	function g.Call(where, fn, ...)
		if not g.on then
			return true, fn(...)
		end
		local ok, a, b, c, d, e = xpcall(fn, Trace, ...)
		if not ok then
			g.Error(where, a)
			return false
		end
		return true, a, b, c, d, e
	end

	function g.Fn(where, fn)
		return function(...)
			if not g.on then
				return fn(...)
			end
			local ok, a, b, c, d, e = xpcall(fn, Trace, ...)
			if not ok then
				g.Error(where, a)
				return nil
			end
			return a, b, c, d, e
		end
	end

	-- A state's functions (the State() args, with its FrameEvents and
	-- EventHandlers already made). An error on the way in, on an update, in
	-- the timeline or a handler: logged, then to the fallback state (idle),
	-- whose way in cleans up; one on the way out: logged.
	function g.State(args, fallback)
		local name = tostring(args.name)
		fallback = fallback or "idle"
		local function Out(inst)
			local sg = inst ~= nil and inst.sg or nil
			local cur = sg ~= nil and sg.currentstate or nil
			if cur ~= nil and cur.name == name and sg.GoToState ~= nil and name ~= fallback then
				pcall(sg.GoToState, sg, fallback)
			end
		end
		local function Wrap(where, fn, leave)
			return function(inst, ...)
				if not g.on then
					return fn(inst, ...)
				end
				local ok, a, b, c, d, e = xpcall(fn, Trace, inst, ...)
				if not ok then
					g.Error(name .. " " .. where, a)
					if leave then
						Out(inst)
					end
					return nil
				end
				return a, b, c, d, e
			end
		end
		for _, key in ipairs({ "onenter", "onupdate", "ontimeout" }) do
			if type(args[key]) == "function" then
				args[key] = Wrap(key, args[key], true)
			end
		end
		if type(args.onexit) == "function" then
			args.onexit = Wrap("onexit", args.onexit, false)
		end
		for i, ev in ipairs(type(args.timeline) == "table" and args.timeline or {}) do
			if type(ev) == "table" and type(ev.fn) == "function" then
				ev.fn = Wrap("frame " .. tostring(ev.frame or i), ev.fn, true)
			end
		end
		for _, ev in ipairs(type(args.events) == "table" and args.events or {}) do
			if type(ev) == "table" and type(ev.fn) == "function" then
				ev.fn = Wrap(tostring(ev.name), ev.fn, true)
			end
		end
		return args
	end

	return g
end

-- one guard per mod, shared by its files (the setting switches them all)
local shared = {}
function Guard.Shared(tag)
	shared[tag] = shared[tag] or Guard.New(tag)
	return shared[tag]
end

return Guard
