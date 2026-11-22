-- Tonic Swap: the tonics' effects in the game's current art.
--
-- A few tonics (defs/powers/tonicpowers.lua) still use the game's early
-- placeholder effects:
--   Ice Cold Slushie (tonic_freeze): the old "freeze" status, enemies just go
--     grey and stop. Now the current Frozen: the ice prison, frost sparkles and
--     the shatter, as Frost powers and freeze traps do it
--     (SGCommon.Fns.ApplyInstantFreeze). Enemies that can't be frozen (bosses)
--     get full Cold instead, like everywhere else in the game. How it plays
--     out (tonic_freeze_style; everyone froze in the same frame before):
--       "nova"    the Legendary Frost power's frost nova (frost_potion_freeze):
--                 the full-screen frost burst and its sound, then enemies
--                 freeze one after another, nearest first, at its pace
--       "ripple"  a big frost burst at you; each enemy freezes as the wave
--                 reaches it (further = later), a small frost burst on each
--       "chill"   the frost burst; every enemy goes cold first (blue-grey,
--                 slowed, sparkles), then freezes a moment later
--       "instant" everyone at once (0.5.2)
--       "browse"  the next style each time you use it, its name over you
--   Battoad Eggs / Chocolate Foam (tonic_projectile_repeat / tonic_projectile):
--     the plain magic ball (generic_projectile). Now the Shrapnel power's
--     projectile with its trail (shrapnel_projectile, same hits and damage).
--   Popping Candy (tonic_explode): the big bomb explosion drawn at half size.
--     Now the game's own small explosion, drawn at tonic_explode_scale (0.5:
--     it goes off every second for 10 seconds, so it stays modest), with its
--     ground blast only if tonic_explode_ground is on. The game also bursts a
--     bomb hit ("hits_bomb") on every enemy it hits, so one tick looked like
--     a blast per enemy: off unless tonic_explode_enemy_blasts is on (the
--     enemies still take the hit).
-- Settings: tonic_fx = false keeps the game's effects.

local Power = require "defs.powers"

local TonicFx = {}

TonicFx.PROJECTILE = { generic_projectile = "shrapnel_projectile" }
TonicFx.BOMB = "bomb_explosion"
TonicFx.BOMB_NOW = { "bomb_explosion_small", "bomb_explosion_ground_small" }
-- Popping Candy's look (Install sets these from the settings)
TonicFx.opts = { scale = 0.5, ground = false, enemy_blasts = false, freeze_style = "browse" }

-- Ice Cold Slushie's styles
TonicFx.FREEZE_STYLES = { "nova", "ripple", "chill", "instant" }
TonicFx.FREEZE_NAMES = { nova = "Frost nova", ripple = "Frost ripple", chill = "Chill, then freeze", instant = "All at once" }
TonicFx.FREEZE_FX = { "freeze_entire_screen", "frost_explode_lrg", "frost_explode_sml" }
-- animation frames: the first freeze, then the gap to the next (the frost
-- potion power's pace: by how many enemies), each gap after that speedup x
-- the one before (at least 1 frame), and everyone frozen by frame last at the
-- latest. (0.5.3: the same gap every time, speedup = 1, last = nil.)
TonicFx.NOVA = { first = 2, few = 5, medium = 3, many = 1, speedup = 0.6, last = 12 }
TonicFx.RIPPLE_SPEED = 20 -- the wave, in units a second
TonicFx.CHILL = { stacks = 60, seconds = 0.75, step = 0.04 } -- Cold %, then frozen after this, nearest first
TonicFx.browse_next = 1
-- 0.7.12 (user 2026-11-13: two potions drunk quickly, each with the tonic,
-- cut the first frost nova short and froze some enemies late): a use that
-- comes while your last freeze is still playing out waits for it, then plays
-- in full right after (its burst, sound and freezes); one within CHAIN
-- seconds after it keeps its style ("browse" moves on only after a pause).
TonicFx.CHAIN = 2.0
TonicFx.BURST = 0.6 -- seconds: the frost burst's main particles (freeze_entire_screen: 0.6 s)
TonicFx.ANIM_FPS = 30 -- the game's anim frames a second (DoTaskInAnimFrames)

local function Find(name)
	local ok, def = pcall(Power.FindPowerByName, name) -- errors for a missing name
	return ok and type(def) == "table" and def or nil
end

local function AddPrefabs(def, list)
	def.prefabs = def.prefabs or {}
	for _, p in ipairs(list) do
		local have = false
		for _, q in ipairs(def.prefabs) do
			if q == p then
				have = true
			end
		end
		if not have then
			table.insert(def.prefabs, p)
		end
	end
end

-- run fn with Fns[key] swapped for wrap(original); put back right after (also on an error)
local function With(Fns, key, wrap, fn, ...)
	local orig = Fns[key]
	Fns[key] = wrap(orig)
	local results = table.pack(pcall(fn, ...))
	Fns[key] = orig
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

local function ProjectileSpawn(orig)
	return function(inst, prefab, ...)
		return orig(inst, TonicFx.PROJECTILE[prefab] or prefab, ...)
	end
end

-- the game's per-enemy bomb hit burst, skipped
local function NoBombHitFx(orig)
	return function(prefab, ...)
		if prefab == "hits_bomb" then
			return nil
		end
		return orig(prefab, ...)
	end
end

-- run fn with the global key swapped for wrap(original); put back right after
local function WithGlobal(key, wrap, fn, ...)
	local orig = rawget(_G, key)
	if type(orig) ~= "function" then
		return fn(...)
	end
	rawset(_G, key, wrap(orig))
	local results = table.pack(pcall(fn, ...))
	rawset(_G, key, orig)
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

local bomb_spawned
local function BombSpawn(orig)
	return function(inst, prefab, ...)
		if prefab == TonicFx.BOMB then
			local fx = orig(inst, TonicFx.BOMB_NOW[1], ...)
			if TonicFx.opts.ground then
				local ground = orig(inst, TonicFx.BOMB_NOW[2], ...)
				if ground ~= nil and ground.AnimState ~= nil then
					pcall(ground.AnimState.SetScale, ground.AnimState, TonicFx.opts.scale, TonicFx.opts.scale)
				end
			end
			bomb_spawned = fx
			return fx
		end
		return orig(inst, prefab, ...)
	end
end

----------------------------------------------------------------------------
-- Ice Cold Slushie's freeze, played out

local function Alive(e)
	return e ~= nil and e:IsValid() and e.components ~= nil and e.components.powermanager ~= nil
		and (e.IsAlive == nil or e:IsAlive())
end

local function FreezeOne(inst, enemy, Fns)
	if Alive(enemy) then
		local ok, err = pcall(Fns.ApplyInstantFreeze, inst, enemy)
		if not ok then
			print("[Tonic Swap] freeze: " .. tostring(err))
		end
	end
end

local function Particles(pos, name, inst)
	local ok, powerutil = pcall(require, "util.powerutil")
	if ok and type(powerutil) == "table" and powerutil.SpawnParticlesAtPosition ~= nil then
		return pcall(powerutil.SpawnParticlesAtPosition, pos, name, 1, inst)
	end
	return false
end

local function NovaSound(inst)
	local ok, soundutil = pcall(require, "util.soundutil")
	local ok2, fmodtable = pcall(require, "defs.sound.fmodtable")
	local ev = ok2 and fmodtable.Event ~= nil and fmodtable.Event.Frost_Nova_Fullscreen or nil
	if ok and ev ~= nil then
		pcall(soundutil.PlayCodeSound, inst, ev, { max_count = 1 })
	end
end

-- the enemies, nearest first, with their distance
function TonicFx.Nearest(inst, enemies)
	local list = {}
	for e in pairs(enemies) do
		if Alive(e) then
			list[#list + 1] = { e = e, d = math.sqrt(inst:GetDistanceSqTo(e)) }
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	return list
end

-- which style this time ("browse": the next one, its name shown over you)
function TonicFx.PickStyle(inst)
	local style = TonicFx.opts.freeze_style
	if style ~= "browse" then
		return style
	end
	local i = TonicFx.browse_next
	style = TonicFx.FREEZE_STYLES[i] or TonicFx.FREEZE_STYLES[1]
	TonicFx.browse_next = i % #TonicFx.FREEZE_STYLES + 1
	local text = string.format("%s (%d/%d)", TonicFx.FREEZE_NAMES[style], i, #TonicFx.FREEZE_STYLES)
	print("[Tonic Swap] Ice Cold Slushie: " .. text .. " - tonic_freeze_style = \"" .. style .. "\"")
	local dungeon = rawget(_G, "TheDungeon")
	local hud = dungeon ~= nil and dungeon.HUD or nil
	if hud ~= nil and hud.MakePopText ~= nil then
		local colors = rawget(_G, "UICOLORS")
		pcall(hud.MakePopText, hud, { target = inst, button = text, color = colors ~= nil and colors.BLUE or nil, size = 60, fade_time = 2.5 })
	end
	return style
end

-- the nova's freeze frames for n enemies, nearest first: the far ones come quicker
function TonicFx.NovaFrames(n)
	local N = TonicFx.NOVA
	local gap = n <= 3 and N.few or (n <= 7 and N.medium or N.many)
	local speedup = tonumber(N.speedup) or 1
	local f = N.first
	local frames = {}
	for i = 1, n do
		if i > 1 then
			f = f + math.max(1, math.floor(gap + 0.5))
			gap = gap * speedup
		end
		frames[i] = N.last ~= nil and math.min(f, math.max(N.last, N.first)) or f
	end
	return frames
end

local function Now()
	local get = rawget(_G, "GetTime")
	if type(get) ~= "function" then
		return nil
	end
	local ok, t = pcall(get)
	return ok and type(t) == "number" and t or nil
end

-- This player's last freeze, while it plays out or within CHAIN seconds after
-- (run.busy: when it's over), or nil.
function TonicFx.Running(inst, now)
	local run = rawget(inst, "tonicswap_freeze")
	if type(run) ~= "table" or now == nil or type(run.busy) ~= "number" then
		return nil
	end
	if now > run.busy + TonicFx.CHAIN then
		return nil
	end
	return run
end

-- How long a style plays out for n enemies (seconds; the ripple: its burst
-- at least, the wave's reach is only known when it goes).
function TonicFx.Length(style, n)
	if style == "instant" then
		return 0
	elseif style == "chill" then
		return math.max(TonicFx.BURST, TonicFx.CHILL.seconds + math.max(0, n - 1) * TonicFx.CHILL.step)
	elseif style == "ripple" then
		return TonicFx.BURST
	end
	local frames = TonicFx.NovaFrames(n)
	return math.max(TonicFx.BURST, (frames[#frames] or 0) / TonicFx.ANIM_FPS)
end

-- One freeze, played out now in its style. Returns how many and how long.
function TonicFx.PlayOut(inst, style, enemies, Fns)
	local list = TonicFx.Nearest(inst, enemies)
	local pos = inst:GetPosition()
	local length = TonicFx.Length(style, #list)
	if style == "instant" then
		for _, t in ipairs(list) do
			FreezeOne(inst, t.e, Fns)
		end
	elseif style == "ripple" then
		Particles(pos, "frost_explode_lrg", inst)
		NovaSound(inst)
		for _, t in ipairs(list) do
			local s = t.d / TonicFx.RIPPLE_SPEED
			length = math.max(length, s)
			inst:DoTaskInTime(s, function()
				if Alive(t.e) then
					Particles(t.e:GetPosition(), "frost_explode_sml", inst)
					FreezeOne(inst, t.e, Fns)
				end
			end)
		end
	elseif style == "chill" then
		Particles(pos, "freeze_entire_screen", inst)
		NovaSound(inst)
		local C = TonicFx.CHILL
		for i, t in ipairs(list) do
			if type(Fns.ApplyCold) == "function" then
				pcall(Fns.ApplyCold, inst, t.e, C.stacks)
			end
			inst:DoTaskInTime(C.seconds + (i - 1) * C.step, function()
				FreezeOne(inst, t.e, Fns)
			end)
		end
	else -- "nova"
		Particles(pos, "freeze_entire_screen", inst)
		NovaSound(inst)
		local frames = TonicFx.NovaFrames(#list)
		for i, t in ipairs(list) do
			inst:DoTaskInAnimFrames(frames[i], function()
				FreezeOne(inst, t.e, Fns)
			end)
		end
	end
	return #list, length
end

-- Returns the style, how many enemies now, and the wait (seconds) when it
-- follows a freeze still playing out.
function TonicFx.Freeze(inst, enemies, Fns)
	local now = Now()
	local run = TonicFx.Running(inst, now)
	local style
	if run ~= nil and TonicFx.FREEZE_NAMES[run.style] ~= nil then
		style = run.style -- the same freeze again (another potion, another sip)
		run.uses = (run.uses or 1) + 1
	else
		style = TonicFx.PickStyle(inst)
		run = { style = style, uses = 1 }
		rawset(inst, "tonicswap_freeze", run)
	end
	if now ~= nil and run.busy ~= nil and now < run.busy then
		-- the last one is still playing: this one right after it, in full
		local wait = run.busy - now
		local start = run.busy
		local n = #TonicFx.Nearest(inst, enemies)
		run.busy = start + TonicFx.Length(style, n)
		inst:DoTaskInTime(wait, function()
			local ok, _, length = pcall(TonicFx.PlayOut, inst, style, enemies, Fns)
			if not ok then
				print("[Tonic Swap] freeze: " .. tostring(_))
			elseif type(length) == "number" then
				local t = Now() or start
				run.busy = math.max(run.busy, t + length)
			end
		end)
		return style, 0, wait
	end
	local n, length = TonicFx.PlayOut(inst, style, enemies, Fns)
	if now ~= nil then
		run.busy = now + length
	end
	return style, n
end

-- opts: the settings (tonic_explode_scale, tonic_explode_ground, tonic_freeze_style).
-- Returns the list of tonics changed (names), and the problems.
function TonicFx.Install(SGCommon, opts)
	local done, problems = {}, {}
	if type(opts) == "table" then
		local scale = tonumber(opts.tonic_explode_scale)
		TonicFx.opts.scale = scale ~= nil and math.max(0.1, math.min(2, scale)) or 0.5
		TonicFx.opts.ground = opts.tonic_explode_ground == true
		TonicFx.opts.enemy_blasts = opts.tonic_explode_enemy_blasts == true
		local style = opts.tonic_freeze_style
		if style ~= "browse" and TonicFx.FREEZE_NAMES[style] == nil then
			style = "browse"
		end
		TonicFx.opts.freeze_style = style
	end
	local Fns = type(SGCommon) == "table" and SGCommon.Fns or nil
	if type(Fns) ~= "table" then
		return done, { "SGCommon.Fns not found" }
	end

	-- Ice Cold Slushie: the current Frozen, played out in the chosen style
	local freeze = Find("tonic_freeze")
	if freeze ~= nil and type(Fns.ApplyInstantFreeze) == "function" and not freeze.tonicswap_fx then
		freeze.tonicswap_fx = true
		AddPrefabs(freeze, TonicFx.FREEZE_FX)
		local orig = freeze.on_add_fn
		freeze.on_add_fn = function(pow, inst, ...)
			local world = rawget(_G, "TheWorld")
			local roomclear = world ~= nil and world.components ~= nil and world.components.roomclear or nil
			if roomclear == nil or Fns.ApplyInstantFreeze == nil then
				return orig(pow, inst, ...)
			end
			local ok, err = pcall(TonicFx.Freeze, inst, roomclear:GetEnemies() or {}, Fns)
			if not ok then
				print("[Tonic Swap] freeze: " .. tostring(err))
			end
			inst:DoTaskInTime(0, function()
				inst.components.powermanager:RemovePower(pow.def, true)
			end)
		end
		done[#done + 1] = "Ice Cold Slushie (" .. tostring(TonicFx.opts.freeze_style) .. ")"
	elseif freeze == nil or type(Fns.ApplyInstantFreeze) ~= "function" then
		problems[#problems + 1] = "freeze: tonic_freeze / ApplyInstantFreeze not found"
	end

	-- the projectile tonics: the Shrapnel projectile
	for _, p in ipairs({ { "tonic_projectile_repeat", "on_update_fn", "Battoad Eggs" }, { "tonic_projectile", "on_add_fn", "Chocolate Foam" } }) do
		local def = Find(p[1])
		if def ~= nil and type(def[p[2]]) == "function" and type(Fns.SpawnAtAngleDist) == "function" and not def.tonicswap_fx then
			def.tonicswap_fx = true
			local orig = def[p[2]]
			def[p[2]] = function(pow, inst, ...)
				return With(Fns, "SpawnAtAngleDist", ProjectileSpawn, orig, pow, inst, ...)
			end
			AddPrefabs(def, { "shrapnel_projectile" })
			done[#done + 1] = p[3]
		elseif def == nil then
			problems[#problems + 1] = p[1] .. " not found"
		end
	end

	-- Popping Candy: the small explosion and its ground blast
	local explode = Find("tonic_explode")
	if explode ~= nil and type(explode.on_update_fn) == "function" and type(Fns.SpawnAtDist) == "function" and not explode.tonicswap_fx then
		explode.tonicswap_fx = true
		local orig = explode.on_update_fn
		explode.on_update_fn = function(pow, inst, ...)
			bomb_spawned = nil
			-- each enemy's hit comes a few frames later (inst:DoTaskInAnimFrames):
			-- those tasks run without the bomb hit burst
			local own = rawget(inst, "DoTaskInAnimFrames")
			local base = inst.DoTaskInAnimFrames
			if not TonicFx.opts.enemy_blasts and type(base) == "function" then
				inst.DoTaskInAnimFrames = function(self, frames, fn, ...)
					if type(fn) ~= "function" then
						return base(self, frames, fn, ...)
					end
					return base(self, frames, function(...)
						return WithGlobal("SpawnHitFx", NoBombHitFx, fn, ...)
					end, ...)
				end
			end
			local packed = table.pack(pcall(With, Fns, "SpawnAtDist", BombSpawn, orig, pow, inst, ...))
			rawset(inst, "DoTaskInAnimFrames", own)
			if not packed[1] then
				error(packed[2], 0)
			end
			local results = table.pack(table.unpack(packed, 2, packed.n))
			-- (the game drew its big explosion at half size; the small one at the setting's size)
			if bomb_spawned ~= nil and bomb_spawned.AnimState ~= nil then
				pcall(bomb_spawned.AnimState.SetScale, bomb_spawned.AnimState, TonicFx.opts.scale, TonicFx.opts.scale)
			end
			bomb_spawned = nil
			return table.unpack(results, 1, results.n)
		end
		AddPrefabs(explode, TonicFx.BOMB_NOW)
		done[#done + 1] = "Popping Candy"
	elseif explode == nil then
		problems[#problems + 1] = "tonic_explode not found"
	end
	return done, problems
end

return TonicFx
