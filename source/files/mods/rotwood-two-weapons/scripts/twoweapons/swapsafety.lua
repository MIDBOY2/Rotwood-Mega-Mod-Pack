-- Two Weapons: timers the old weapon left running.
--
-- A weapon's moves and skills schedule work a few frames ahead (the
-- Striker's Recall pulls its balls back 5 and 11 frames after the press,
-- "even if you dodge out"; the Cannon's air shots pick up their slide after
-- the hit stop; ...). The game never changes your weapon in the middle of a
-- move, so it never checks: after a swap those timers run against the new
-- weapon's stategraph, which doesn't have what they look for, and the game
-- stops with its error screen (Striker + Bow / Cannon: "RecallOneShotput ...
-- table expected, got nil").
--
-- So when the player's stategraph is replaced (a swap, or the game's own
-- weapon change), every timer still pending that a weapon or skill
-- stategraph started is wrapped: it still runs (a recall with nothing to
-- recall just does nothing), and if it fails because its weapon is gone the
-- error is logged ("[Two Weapons] error in a timer the old weapon left
-- running") and skipped, the game carries on.
--
-- And the Striker's recall itself checks for its balls first (the game's
-- other ball code already does), so that one is quiet.

local SwapSafety = {}

-- the game's weapon / skill stategraph files (the timers' functions live there)
SwapSafety.SOURCES = { "stategraphs/sg_player_", "stategraphs/playerskills/" }

local is_weapon_fn = setmetatable({}, { __mode = "k" }) -- fn -> true / false
local wrappers = setmetatable({}, { __mode = "k" }) -- our wrappers (never wrapped twice)

local function FromWeaponStategraph(fn)
	local known = is_weapon_fn[fn]
	if known ~= nil then
		return known
	end
	local info = debug ~= nil and debug.getinfo ~= nil and debug.getinfo(fn, "S") or nil
	local src = info ~= nil and tostring(info.source) or ""
	local yes = false
	for _, s in ipairs(SwapSafety.SOURCES) do
		if src:find(s, 1, true) then
			yes = true
			break
		end
	end
	is_weapon_fn[fn] = yes
	return yes
end
SwapSafety.FromWeaponStategraph = FromWeaponStategraph

local function Guard()
	local main = package.loaded["twoweapons.main"]
	if type(main) == "table" and main.G ~= nil then
		return main.G
	end
	return require("twoweapons.guard").Shared("[Two Weapons]")
end

-- Wrap the entity's pending weapon / skill timers. Returns how many.
function SwapSafety.WrapTimers(inst)
	local tasks = type(inst) == "table" and rawget(inst, "tasks") or nil
	if type(tasks) ~= "table" then
		return 0
	end
	local G = Guard()
	local n = 0
	for task in pairs(tasks) do
		local fn = type(task) == "table" and not task.retired and task.fn or nil
		if type(fn) == "function" and not wrappers[fn] and FromWeaponStategraph(fn) then
			local orig = fn
			local w = function(...)
				G.Call("a timer the old weapon left running", orig, ...)
			end
			wrappers[w] = true
			task.fn = w
			n = n + 1
		end
	end
	return n
end

local function IsPlayer(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.twoweapons ~= nil
end

-- Effects a weapon keeps on you between its own moves, by their name in the
-- stategraph's memory. The Striker's focus glow on your hand ("focustrail",
-- sg_player_shotput.lua and its Slam skill) is switched off by the Striker's
-- next throw or catch; after a swap nothing knows it's there, so it glowed on
-- for ever. They're removed when the stategraph is replaced. (Removed, not
-- stopped: the Slam's own "stopped" handler would look for it in the new
-- weapon's memory and fail.)
SwapSafety.LINGERING_FX = { "focustrail" }

function SwapSafety.ClearLingeringFx(inst)
	local mem = inst ~= nil and inst.sg ~= nil and inst.sg.mem or nil
	if type(mem) ~= "table" then
		return 0
	end
	local n = 0
	for _, key in ipairs(SwapSafety.LINGERING_FX) do
		local fx = mem[key]
		if fx ~= nil then
			mem[key] = nil
			if type(fx) == "table" and fx.IsValid ~= nil and fx:IsValid() then
				fx:Remove()
				n = n + 1
			end
		end
	end
	return n
end

local function HookStateGraph(ES)
	local orig = ES.SetStateGraph
	ES.SetStateGraph = function(self, ...)
		if self.sg ~= nil and IsPlayer(self) then
			local ok, n = pcall(SwapSafety.WrapTimers, self)
			if ok and n > 0 then
				SwapSafety.wrapped = (SwapSafety.wrapped or 0) + n
			end
			local okf, nf = pcall(SwapSafety.ClearLingeringFx, self)
			if okf and nf > 0 then
				SwapSafety.cleared = (SwapSafety.cleared or 0) + nf
			end
		end
		return orig(self, ...)
	end
end

-- The Striker's recall: no ball list (another weapon's stategraph): nothing to recall.
local function HookRecall()
	local ok, SGPlayerCommon = pcall(require, "stategraphs.sg_player_common")
	local fns = ok and type(SGPlayerCommon) == "table" and SGPlayerCommon.Fns or nil
	local orig = fns ~= nil and fns.RecallOneShotput or nil
	if type(orig) ~= "function" then
		return false
	end
	fns.RecallOneShotput = function(inst, ...)
		local mem = inst ~= nil and inst.sg ~= nil and inst.sg.mem or nil
		if mem == nil or type(mem.active_projectiles) ~= "table" then
			return
		end
		return orig(inst, ...)
	end
	return true
end

-- Returns true, or false + what's missing.
function SwapSafety.Install()
	local ES = rawget(_G, "EntityScript")
	if type(ES) ~= "table" or type(ES.SetStateGraph) ~= "function" then
		return false, "EntityScript:SetStateGraph"
	end
	HookStateGraph(ES)
	SwapSafety.recall = HookRecall()
	SwapSafety.enabled = true
	return true
end

return SwapSafety
