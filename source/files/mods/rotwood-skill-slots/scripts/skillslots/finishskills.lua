-- Skill Slots: two of the game's unfinished skills, finished.
--
-- Explosive Dive (bow_primearrow_explode). The game's version is a stub: it
-- has no name ("[TEMP] bow_primearrow_explode"), no icon, no dip fx, and
-- coming into a room primed it puts Cold Plunge's frost trail on your quiver.
-- What it does already works (prefabs/player_bow_projectile.lua): the primed
-- Heavy Attack arrow explodes where it lands (trap_bomb_pinecone_friendly,
-- the friendly pinecone bomb). Finished from Cold Plunge and Toxic Dip:
--   * name and description in the style of the other two, its own icon;
--   * priming: Hypershot's pink dip fx (fx_bow_skill_prime_arrow_hypershot,
--     the crit pink) and Hypershot's prime sound, and Hypershot's pink sparks
--     on the arrow while it's primed (quiver_arrow_trail_hypershot, on the
--     arrow's symbol swap_fx2 like Cold Plunge's frost);
--   * the primed arrow flies with a pink crit trail (the focus arrow's sparks
--     in crit pink: prefabs/skillslots_particles.lua);
--   * the pink sparks go away once the arrow is shot (the stub left them on),
--     and coming into a room primed puts back its own sparks, not frost;
--   * the prime, four ways (explosive_dive_prime): the dip fx is drawn for
--     the prime animation, so when that animation doesn't show, the pink burst
--     hangs above the head on its own (the user's screenshots):
--       "anim"    (default, 0.16.1) Hypershot's pink dip fx while the prime
--                 animation plays (the arrow raised: lined up as drawn); leave
--                 the animation early (straight into the Heavy Attack, a dodge,
--                 a run) and the drawing goes, what's left of its sparks goes
--                 onto the arrow (the user: "position it correctly when going
--                 straight into the heavy attack ... or at least play it when
--                 the reload animation plays")
--       "arrow"   no dip fx: the pink sparks come onto the arrow when
--                 the prime starts, and a short pink burst on the arrow when
--                 it's primed (both follow the arrow's symbol, so they sit on
--                 it whatever the animation does)
--       "vanilla" the game's prime: its animation, no dip fx (the arrow's pink
--                 sparks still show it's primed)
--       "quick"   the prime animation at twice the speed, then straight into
--                 the Heavy Attack shot (the bow's own heavy_attack_shoot,
--                 explosive_dive_shot strength) with the primed arrow
--
-- Throw Snowball (throwsnowball, the game's holiday skill: 9 snowballs, 3 per
-- reload, but nothing in the game reloads it, so after 3 throws it only
-- shrugs "RELOAD!"). Finished:
--   * endless: every throw scoops a fresh snowball off the ground (the throw's
--     own scoop: skill_throw_stone_pre), so no ammo and no "RELOAD!";
--   * the snowball the game's frost powers throw (player_snowball_cold_
--     projectile, snowballs from the snow world): it knocks enemies back and
--     makes them Cold; enough Cold (600) Freezes them. It only hits enemies
--     (the holiday snowball also knocked your friends down);
--   * no damage by default, like the game's snowball (snowball_damage);
--   * the snowball in your hand, not the stone (the throw shares Throw
--     Stone's animation; the stone is its symbol "Symbol 2"): the hand shows
--     the snowball projectile's art (fx_projectile_snow_ball) while you throw;
--   * name, description and its own icon;
--   * the throw always comes: the game's scoop lets the stick cancel it from
--     its 6th frame (SetCanMove), so throwing on the move gave no snowball.
--     Throw Stone (the same animation) has no such frame: the stick waits
--     for the throw. The snowball's scoop is the same now.
--
-- Cold Plunge (bow_primearrow_cold) and Toxic Dip (bow_primearrow_acid): the
-- game's own skills, the same prime. Their dip fx (fx_bow_skill_prime_arrow_
-- frost / _acid_pN) is its own animation drawn to match the prime animation:
-- its sound (Bow_Prime_Ice / Bow_Prime_Acid), a frost / acid trail on its
-- arrow from its 1st frame and a burst at its 10th, placed 4.7 above (where
-- the arrow is raised in the prime animation). When that doesn't line up the
-- burst hangs over the head on its own. bow_prime_dip, four ways:
--   "anim"  (default, 0.16.1) the game's dip fx while the prime animation
--           plays; leaving it early takes the drawing away and puts what's
--           left of its trail and burst on the arrow (as "arrow" does)
--   "arrow" the dip fx's own parts, read from the game's data
--           (prefabs/autogen/fx and /stategraph): its sound on the player, its
--           trail and burst on the arrow (the symbol the game puts the frost
--           sparks on, swap_fx2) at the dip's own frames and for its own
--           time; only the dip's drawing left out. 0.14.10 left out its sound
--           and trail too (the user: "removed the sfx and vfx").
--   "plain" the dip's sound and the game's prime (its sparks on the arrow), no
--           trail or burst
--   "game"  the game's dip fx as it is
--
-- settings: explosive_dive, explosive_dive_trail, snowball, snowball_cold,
-- snowball_damage, snowball_speed, snowball_in_hand, snowball_hand_symbol,
-- snowball_finish_throw.
local Finish = {}

Finish.TAG = "[Skill Slots]"

Finish.DIVE = "bow_primearrow_explode"
Finish.DIVE_NAME = "Explosive Dive"
Finish.DIVE_DESC = "Your next <#RED>Heavy Attack</> <#RED>Explodes</> when hitting the ground."
Finish.DIVE_ICON = "images/skillslots_icons/icon_skillslots_explosive_dive.tex"
Finish.DIVE_FX = "fx_bow_skill_prime_arrow_hypershot"
Finish.DIVE_SPARKS = "quiver_arrow_trail_hypershot"
Finish.DIVE_SYMBOL = "swap_fx2"
Finish.DIVE_BOMB = "trap_bomb_pinecone_friendly"
Finish.DIVE_STATE = "skill_bow_primearrow_explode" -- the game's: reroutes to skill_bow_primearrow
Finish.PRIME_ANIM = "bow_skill_prime_arrow"
Finish.BURST_TIME = 0.4
Finish.QUICK_SPEED = 2
Finish.CRIT_TRAIL = "skillslots_bow_arrow_trail_crit"
Finish.CRIT_TRAIL_FROM = "bow_arrow_trail_focus"
-- crit pink (the game's crit hits and Hypershot): start, end (RRGGBBAA)
Finish.CRIT_COLOURS = { 0xFF60F6FF, 0xFF44DFFC }

-- Cold Plunge / Toxic Dip: the dip fx's sound and particles on the arrow ("arrow")
Finish.DIP_FX_PATTERN = "^fx_bow_skill_prime_arrow_"
Finish.DIP_MODES = { anim = true, arrow = true, plain = true, game = true }
Finish.DIVE_MODES = { anim = true, arrow = true, vanilla = true, quick = true }
Finish.PRIME_STATE = "skill_bow_primearrow" -- the prime animation's state (the skills reroute to it)
Finish.DIP_WATCH_TIME = 3 -- seconds: the prime is over by then
Finish.DIP_FALLBACK_END = 40 -- the dip's frame its burst is over by (from its 10th, 30 frames)
local function HunterId(inst)
	return inst.GetHunterId ~= nil and inst:GetHunterId() or nil
end
Finish.DIPS = {
	bow_primearrow_cold = { name = "Cold Plunge",
		fx = function() return "fx_bow_skill_prime_arrow_frost" end,
		burst = function() return "bow_skill_frost_prime_trail_burst" end },
	bow_primearrow_acid = { name = "Toxic Dip",
		fx = function(inst)
			local id = HunterId(inst)
			return id ~= nil and ("fx_bow_skill_prime_arrow_acid_p" .. id) or "fx_bow_skill_prime_arrow_acid"
		end,
		burst = function(inst)
			local id = HunterId(inst)
			return id ~= nil and ("bow_skill_prime_arrow_trail_burst_p" .. id) or "arrow_acid_coat_burst"
		end },
}
Finish.DIP_BURST_TIME = 1 -- seconds (the dip's own: 30 frames)
Finish.FPS = 30 -- the dip fx's frames (the game's animations: 30 a second)

Finish.SNOW = "throwsnowball"
Finish.SNOW_NAME = "Throw Snowball"
Finish.SNOW_ICON = "images/skillslots_icons/icon_skillslots_snowball.tex"
Finish.SNOWBALL = "player_snowball_cold_projectile"
Finish.SNOW_BUILD = "fx_projectile_snow_ball"
Finish.ROCK_SYMBOL = "Symbol 2" -- the stone in skill_throw_stone_* (player_bank_basic's build)
Finish.SNOW_STATES = { "skill_throwsnowball", "skill_throwsnowball_pre", "skill_throwsnowball_pst" }

Finish.settings = {
	explosive_dive = true, explosive_dive_trail = true, explosive_dive_prime = "anim", explosive_dive_shot = "STRONG",
	snowball = true, snowball_cold = 150, snowball_damage = 0, snowball_speed = 25,
	snowball_in_hand = true, snowball_hand_symbol = nil, snowball_finish_throw = true,
	bow_prime_dip = "anim",
}
-- loading into a room (the power manager re-adding powers): no fx then
local function Loading(inst)
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	return pm ~= nil and pm.IsLoading ~= nil and pm:IsLoading()
end
Finish.dive_done = false
Finish.snow_done = false
Finish.states_done = false
Finish.snow_symbol = nil -- nil: not looked up yet; false: none found

local function Log(msg)
	print(Finish.TAG .. " " .. tostring(msg))
end

local function Num(v, default, lo, hi)
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.max(lo, math.min(hi, v))
end

function Finish.LoadSettings(user)
	user = type(user) == "table" and user or {}
	local s = {
		explosive_dive = user.explosive_dive ~= false,
		explosive_dive_trail = user.explosive_dive_trail ~= false,
		explosive_dive_prime = Finish.DIVE_MODES[user.explosive_dive_prime] and user.explosive_dive_prime or "anim",
		explosive_dive_shot = (user.explosive_dive_shot == "WEAK" or user.explosive_dive_shot == "MEDIUM" or user.explosive_dive_shot == "FOCUS")
			and user.explosive_dive_shot or "STRONG",
		snowball = user.snowball ~= false,
		-- Cold per hit: 600 Freezes (the game's frost snowball: 300)
		snowball_cold = math.floor(Num(user.snowball_cold, 150, 0, 600) + 0.5),
		-- x your weapon's damage: 0 = none (the game's snowball), 1 = full (its frost snowball)
		snowball_damage = Num(user.snowball_damage, 0, 0, 2),
		snowball_speed = Num(user.snowball_speed, 25, 5, 40),
		snowball_in_hand = user.snowball_in_hand ~= false,
		snowball_hand_symbol = type(user.snowball_hand_symbol) == "string" and user.snowball_hand_symbol ~= ""
			and user.snowball_hand_symbol or nil,
		-- the stick can't cancel the scoop (Throw Stone's way)
		snowball_finish_throw = user.snowball_finish_throw ~= false,
		-- Cold Plunge / Toxic Dip: "anim" (the game's dip while the prime animation shows), "arrow", "plain" or "game"
		bow_prime_dip = Finish.DIP_MODES[user.bow_prime_dip] and user.bow_prime_dip or "anim",
	}
	Finish.settings = s
	return s
end

local function AddPrefab(def, name)
	def.prefabs = def.prefabs or {}
	for _, p in ipairs(def.prefabs) do
		if p == name then
			return
		end
	end
	table.insert(def.prefabs, name)
end

local function HasPrefab(name)
	local reg = rawget(_G, "Prefabs")
	return type(reg) ~= "table" or reg[name] ~= nil
end

----------------------------------------------------------------------------
-- The pink crit trail: a copy of the focus arrow's sparks in crit pink.

local function Copy(t)
	if type(t) ~= "table" then
		return t
	end
	local r = {}
	for k, v in pairs(t) do
		r[k] = Copy(v)
	end
	return r
end

local function Mix(a, b, t)
	local out = 0
	for shift = 24, 0, -8 do
		local ca = (a >> shift) & 0xFF
		local cb = (b >> shift) & 0xFF
		out = out | (math.floor(ca + (cb - ca) * t + 0.5) << shift)
	end
	return out
end

-- The particle def (or nil if the game lost the focus trail).
function Finish.CritTrailParams(PData)
	local src = type(PData) == "table" and PData[Finish.CRIT_TRAIL_FROM] or nil
	if type(src) ~= "table" or type(src.emitters) ~= "table" then
		return nil
	end
	local p = Copy(src)
	p.__displayName = Finish.CRIT_TRAIL
	local first, last = Finish.CRIT_COLOURS[1], Finish.CRIT_COLOURS[2]
	for _, em in ipairs(p.emitters) do
		local curve = em.curves ~= nil and em.curves.color or nil
		if curve ~= nil and type(curve.data) == "table" and #curve.data > 0 then
			local n = #curve.data
			for i = 1, n do
				curve.data[i] = n == 1 and first or Mix(first, last, (i - 1) / (n - 1))
			end
		end
	end
	return p
end

----------------------------------------------------------------------------
-- Explosive Dive

function Finish.FinishDive(Power, powerutil)
	local def = rawget(Power.Items[Power.Slots.SKILL], Finish.DIVE)
	if def == nil then
		return false, "the game has no " .. Finish.DIVE
	end
	local triggers = def.event_triggers
	if type(triggers) ~= "table" or type(triggers.bow_primearrow_ready) ~= "function"
		or type(triggers.bow_primearrow_used) ~= "function" then
		return false, "a game update changed " .. Finish.DIVE
	end
	def.pretty = { name = Finish.DIVE_NAME, desc = Finish.DIVE_DESC }
	def.icon = Finish.DIVE_ICON
	AddPrefab(def, Finish.DIVE_BOMB)
	AddPrefab(def, Finish.DIVE_SPARKS)
	if Finish.settings.explosive_dive_prime == "anim" then
		AddPrefab(def, Finish.DIVE_FX) -- Hypershot's pink dip fx, loaded with the skill
	end

	local trail = Finish.settings.explosive_dive_trail
	local orig_fxstart = triggers.bow_primearrow_fxstart
	local orig_ready = triggers.bow_primearrow_ready
	local orig_used = triggers.bow_primearrow_used

	triggers.bow_primearrow_fxstart = function(pow, inst, ...)
		if orig_fxstart ~= nil then
			orig_fxstart(pow, inst, ...) -- the game's is empty
		end
		-- (the dip fx only lines up with the prime animation: "anim" shows it
		-- while that animation does, see explosive_dive_prime)
		if Finish.settings.explosive_dive_prime == "anim" and not Loading(inst) then
			local okf, fx = pcall(powerutil.SpawnFxOnEntity, Finish.DIVE_FX, inst, { inheritrotation = true })
			if okf and fx ~= nil then
				pcall(Finish.WatchDip, powerutil, inst, fx, Finish.DIVE_FX, Finish.DiveBurst)
			end
		end
		powerutil.AttachParticleSystemToSymbol(pow, inst, Finish.DIVE_SPARKS, Finish.DIVE_SYMBOL)
		local ok, fmodtable = pcall(require, "defs.sound.fmodtable")
		local oks, soundutil = pcall(require, "util.soundutil")
		local ev = ok and fmodtable.Event ~= nil and fmodtable.Event.Bow_Prime_Hypershot or nil
		if ev ~= nil and oks then
			soundutil.PlayCodeSound(inst, ev, { max_count = 1 })
		end
	end

	triggers.bow_primearrow_ready = function(pow, inst, ...)
		local r = orig_ready(pow, inst, ...)
		if Finish.settings.explosive_dive_prime == "arrow" and powerutil.SpawnParticlesOnEntity ~= nil
			and not (inst.components ~= nil and inst.components.powermanager ~= nil and inst.components.powermanager.IsLoading ~= nil
				and inst.components.powermanager:IsLoading()) then
			-- primed: a short pink burst on the arrow (its symbol, wherever the animation has it)
			local burst = HasPrefab(Finish.CRIT_TRAIL) and Finish.CRIT_TRAIL or Finish.DIVE_SPARKS
			pcall(powerutil.SpawnParticlesOnEntity, inst, burst, Finish.DIVE_SYMBOL, Finish.BURST_TIME)
		end
		local primed = inst.sg ~= nil and inst.sg.mem ~= nil and inst.sg.mem.primedarrow or nil
		if trail and type(primed) == "table" and primed.type == "explode" and primed.particlefxname == nil
			and HasPrefab(Finish.CRIT_TRAIL) then
			primed.particlefxname = Finish.CRIT_TRAIL
		end
		return r
	end

	triggers.bow_primearrow_used = function(pow, inst, ...)
		local r = orig_used(pow, inst, ...)
		powerutil.StopAttachedParticleSystem(inst, pow)
		return r
	end

	-- coming into a room primed: its own sparks (the game's put frost on)
	triggers.enter_room = function(pow, inst, ...)
		if pow.persistdata ~= nil and pow.persistdata.primed then
			powerutil.AttachParticleSystemToSymbol(pow, inst, Finish.DIVE_SPARKS, Finish.DIVE_SYMBOL)
			inst:PushEvent("bow_primearrow_ready")
		end
	end

	Finish.dive_done = true
	return true
end

----------------------------------------------------------------------------
-- Cold Plunge / Toxic Dip: the spark on the arrow


-- The dip fx's parts, from the game's data (cached): its sound (the fx's
-- soundevent) and its particles ({ name, frame, frames }: the stategraph
-- data's spawnparticles events, in its own frames).
Finish.dip_parts = {}
function Finish.DipParts(fxname)
	local cached = Finish.dip_parts[fxname]
	if cached ~= nil then
		return cached
	end
	local out = { parts = {} }
	local okf, FxData = pcall(require, "prefabs.fx_autogen_data")
	local fx = okf and type(FxData) == "table" and FxData[fxname] or nil
	out.sound = type(fx) == "table" and type(fx.soundevent) == "string" and fx.soundevent or nil
	local oks, SgData = pcall(require, "prefabs.stategraph_autogen_data")
	local sg = oks and type(SgData) == "table" and SgData[fxname] or nil
	local mine = type(sg) == "table" and type(sg.stategraphs) == "table" and sg.stategraphs[fxname] or nil
	local idle = type(mine) == "table" and type(mine.events) == "table" and mine.events.idle or nil
	for _, ev in ipairs(type(idle) == "table" and idle or {}) do
		local prm = type(ev) == "table" and ev.param or nil
		if ev.eventtype == "spawnparticles" and type(prm) == "table" and type(prm.particlefxname) == "string" then
			out.parts[#out.parts + 1] = { name = prm.particlefxname, frame = tonumber(ev.frame) or 1,
				frames = tonumber(prm.duration) or Finish.FPS }
		end
	end
	Finish.dip_parts[fxname] = out
	return out
end

-- the dip's sound on the player (the fx played it on itself, at the player)
function Finish.PlayDipSound(inst, soundevent)
	if soundevent == nil then
		return false
	end
	local okt, ev = pcall(function()
		return require("defs.sound.fmodtable").Event[soundevent]
	end)
	local oks, soundutil = pcall(require, "util.soundutil")
	if okt and ev ~= nil and oks and soundutil.PlayCodeSound ~= nil then
		soundutil.PlayCodeSound(inst, ev, { max_count = 1 })
		return true
	end
	return false
end

-- "arrow" / "plain": the dip's sound; "arrow": its particles on the arrow, each at
-- its frame for its time. The number of particles set going.
function Finish.DipOnArrow(powerutil, inst, fxname, sparks)
	local dip = Finish.DipParts(fxname)
	Finish.PlayDipSound(inst, dip.sound)
	if not sparks or powerutil.SpawnParticlesOnEntity == nil or Loading(inst) then
		return 0
	end
	local n = 0
	for _, part in ipairs(dip.parts) do
		if HasPrefab(part.name) then
			n = n + 1
			local function Go()
				if inst:IsValid() then
					pcall(powerutil.SpawnParticlesOnEntity, inst, part.name, Finish.DIVE_SYMBOL, part.frames / Finish.FPS)
				end
			end
			local delay = (part.frame - 1) / Finish.FPS
			if delay <= 0 or inst.DoTaskInTime == nil then
				Go()
			else
				inst:DoTaskInTime(delay, Go)
			end
		end
	end
	return n
end

-- "anim": the burst for a dip whose game data has no parts (the burst the
-- "arrow" mode uses), or nil
function Finish.DipBurst(info, inst)
	local ok, burst = pcall(info.burst, inst)
	if ok and burst ~= nil and HasPrefab(burst) then
		return burst
	end
	local primed = inst.sg ~= nil and inst.sg.mem ~= nil and inst.sg.mem.primedarrow or nil
	burst = type(primed) == "table" and primed.particlefxname or nil
	return burst ~= nil and HasPrefab(burst) and burst or nil
end
function Finish.DiveBurst()
	return HasPrefab(Finish.CRIT_TRAIL) and Finish.CRIT_TRAIL or Finish.DIVE_SPARKS
end

-- What's left of the dip fx's sparks, from its frame `frame` on, on the arrow
-- (its symbol, wherever the animation has it): each part for the rest of its
-- time, or later at its own frame. None in the data: the fallback burst for
-- the rest of the dip's burst time. The number set going.
function Finish.RestOnArrow(powerutil, inst, fxname, frame, fallback)
	if powerutil.SpawnParticlesOnEntity == nil then
		return 0
	end
	local dip = Finish.DipParts(fxname)
	local n, usable = 0, 0
	local function Spawn(name, seconds)
		if inst:IsValid() and seconds > 0 then
			pcall(powerutil.SpawnParticlesOnEntity, inst, name, Finish.DIVE_SYMBOL, seconds)
		end
	end
	for _, part in ipairs(dip.parts) do
		local stop = part.frame + part.frames
		usable = usable + (HasPrefab(part.name) and 1 or 0)
		if frame < stop and HasPrefab(part.name) then
			n = n + 1
			if frame >= part.frame or inst.DoTaskInTime == nil then
				Spawn(part.name, (stop - math.max(frame, part.frame)) / Finish.FPS)
			else
				inst:DoTaskInTime((part.frame - frame) / Finish.FPS, function()
					Spawn(part.name, part.frames / Finish.FPS)
				end)
			end
		end
	end
	if usable == 0 then
		-- none in the data (or none loaded): the fallback burst until the dip's burst would end
		local left = (Finish.DIP_FALLBACK_END - frame) / Finish.FPS
		local burst = type(fallback) == "function" and fallback(inst) or nil
		if burst ~= nil and left > 0 then
			Spawn(burst, left)
			n = 1
		end
	end
	return n
end

-- "anim": the dip fx shows while the prime animation does (the game drew it for
-- that animation and leaves it where it was spawned). Leaving the prime state
-- for anything but its own end (it goes to idle when the animation is over):
-- the drawing is taken away (its sparks with it; its sound plays on) and what's
-- left of its sparks goes onto the arrow. Watched once, for a few seconds.
function Finish.WatchDip(powerutil, inst, fx, fxname, fallback)
	if fx == nil or inst.ListenForEvent == nil or inst.RemoveEventCallback == nil then
		return false
	end
	local t0 = GetTime()
	local done = false
	local fn
	local function Stop()
		if not done then
			done = true
			inst:RemoveEventCallback("newstate", fn)
		end
	end
	fn = function(_, data)
		if done or type(data) ~= "table" or data.laststatename ~= Finish.PRIME_STATE then
			return
		end
		Stop()
		if data.statename == "idle" or not (fx.IsValid ~= nil and fx:IsValid()) then
			return -- the prime animation played out: the dip fx with it, as drawn
		end
		local frame = (GetTime() - t0) * Finish.FPS + 1
		fx:Remove()
		Finish.RestOnArrow(powerutil, inst, fxname, frame, fallback)
	end
	inst:ListenForEvent("newstate", fn)
	if inst.DoTaskInTime ~= nil then
		inst:DoTaskInTime(Finish.DIP_WATCH_TIME, Stop)
	end
	return true
end

-- one skill: its fxstart without the dip fx's drawing (its sound and parts on
-- the arrow instead), its ready with the burst on the arrow when the game's data
-- had no parts
function Finish.FixDip(Power, powerutil, name)
	local info = Finish.DIPS[name]
	local def = rawget(Power.Items[Power.Slots.SKILL], name)
	if info == nil or def == nil then
		return false, "the game has no " .. name
	end
	local triggers = def.event_triggers
	if type(triggers) ~= "table" or type(triggers.bow_primearrow_fxstart) ~= "function"
		or type(triggers.bow_primearrow_ready) ~= "function" then
		return false, "a game update changed " .. name
	end
	local orig_fxstart = triggers.bow_primearrow_fxstart
	local orig_ready = triggers.bow_primearrow_ready
	triggers.bow_primearrow_fxstart = function(pow, inst, ...)
		local mode = Finish.settings.bow_prime_dip
		if mode == "anim" then
			-- the game's, its dip fx kept (lined up while the prime animation
			-- shows) and watched: leaving the animation early takes it away
			local spawn = powerutil.SpawnFxOnEntity
			local dip_fx, dip_name
			powerutil.SpawnFxOnEntity = function(fx, ...)
				local made = spawn(fx, ...)
				if type(fx) == "string" and fx:find(Finish.DIP_FX_PATTERN) then
					dip_fx, dip_name = made, fx
				end
				return made
			end
			local results = table.pack(pcall(orig_fxstart, pow, inst, ...))
			powerutil.SpawnFxOnEntity = spawn
			if not results[1] then
				error(results[2], 0)
			end
			if dip_fx ~= nil then
				local okw, err = pcall(Finish.WatchDip, powerutil, inst, dip_fx, dip_name, function(who)
					return Finish.DipBurst(info, who)
				end)
				if not okw then
					Log(info.name .. "'s dip: " .. tostring(err))
				end
			end
			return table.unpack(results, 2, results.n)
		end
		if mode ~= "arrow" and mode ~= "plain" then
			return orig_fxstart(pow, inst, ...)
		end
		-- the game's, without its dip fx's drawing (only that spawn is skipped)
		local spawn = powerutil.SpawnFxOnEntity
		local skipped
		powerutil.SpawnFxOnEntity = function(fx, ...)
			if type(fx) == "string" and fx:find(Finish.DIP_FX_PATTERN) then
				skipped = fx
				return nil
			end
			return spawn(fx, ...)
		end
		local results = table.pack(pcall(orig_fxstart, pow, inst, ...))
		powerutil.SpawnFxOnEntity = spawn
		if not results[1] then
			error(results[2], 0)
		end
		-- its sound, and its trail and burst on the arrow
		local okn, n = pcall(Finish.DipOnArrow, powerutil, inst, skipped or info.fx(inst), mode == "arrow")
		if not okn then
			Log(info.name .. "'s dip on the arrow: " .. tostring(n))
		end
		pow.skillslots_dip_parts = okn and n or 0
		return table.unpack(results, 2, results.n)
	end
	triggers.bow_primearrow_ready = function(pow, inst, ...)
		local results = table.pack(orig_ready(pow, inst, ...))
		-- (the dip's own burst is already on its way; this only when the game's data had none)
		if Finish.settings.bow_prime_dip == "arrow" and (pow.skillslots_dip_parts or 0) == 0
			and powerutil.SpawnParticlesOnEntity ~= nil and not Loading(inst) then
			-- primed: the game's prime burst on the arrow (its symbol, wherever the animation has it)
			local ok, burst = pcall(info.burst, inst)
			if not ok or burst == nil or not HasPrefab(burst) then
				local primed = inst.sg ~= nil and inst.sg.mem ~= nil and inst.sg.mem.primedarrow or nil
				burst = type(primed) == "table" and primed.particlefxname or nil
			end
			if burst ~= nil and HasPrefab(burst) then
				pcall(powerutil.SpawnParticlesOnEntity, inst, burst, Finish.DIVE_SYMBOL, Finish.DIP_BURST_TIME)
			end
		end
		return table.unpack(results, 1, results.n)
	end
	return true
end

----------------------------------------------------------------------------
-- Throw Snowball

function Finish.SnowDesc()
	local s = Finish.settings
	local parts = { "Scoop up and throw a snowball that <#RED>Knocks Back</> enemies" }
	if s.snowball_damage > 0 then
		parts[#parts + 1] = string.format(", deals <#RED>%d%%</> of your <#RED>Weapon Damage</>", math.floor(s.snowball_damage * 100 + 0.5))
	end
	if s.snowball_cold > 0 then
		local hits = math.ceil(600 / s.snowball_cold)
		parts[#parts + 1] = string.format(" and makes them <#RED>Cold</>: <#RED>%d hit%s</> <#RED>Freeze%s</> them", hits,
			hits == 1 and "" or "s", hits == 1 and "s" or "")
	end
	parts[#parts + 1] = ".\n\nYou never run out of snow."
	return table.concat(parts)
end

-- The snowball's hit: knockback and Cold, enemies only (the game's frost
-- snowball's, with this skill's damage and its own attack name, so your
-- light attack powers don't go off on every snowball).
function Finish.SnowHit(inst, data)
	local SGCommon = require "stategraphs.sg_common"
	local s = Finish.settings
	SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		attack_id = "throwsnowball",
		source = "throwsnowball",
		damage_mod = s.snowball_damage,
		disable_damage_number = s.snowball_damage <= 0 or nil,
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "hits_snow_ball",
		hit_fx_offset_x = 1,
		hit_fx_offset_y = 1.5,
		hit_target_pst_fn = function(attacker, v)
			if s.snowball_cold > 0 then
				SGCommon.Fns.ApplyCold(attacker, v, s.snowball_cold)
			end
		end,
	})
end

function Finish.Throw(pow, inst)
	local SGCommon = require "stategraphs.sg_common"
	local ok, fmodtable = pcall(require, "defs.sound.fmodtable")
	local oks, soundutil = pcall(require, "util.soundutil")
	if ok and oks and fmodtable.Event ~= nil and fmodtable.Event.Skill_ThrowStone_Toss ~= nil then
		local handle = soundutil.PlaySoundData(inst, { fmodevent = fmodtable.Event.Skill_ThrowStone_Toss, sound_max_count = 1 })
		if inst.sg ~= nil and inst.sg.statemem ~= nil then
			inst.sg.statemem.throw_sound_handle = handle
		end
	end
	local bullet = SGCommon.Fns.SpawnAtDist(inst, Finish.SNOWBALL, 3)
	if bullet == nil then
		return
	end
	bullet:Setup(inst)
	local phb = bullet.components ~= nil and bullet.components.projectilehitbox or nil
	if phb ~= nil then
		phb:SetTriggerFunction(Finish.SnowHit)
	end
	if bullet.Physics ~= nil then
		bullet.Physics:SetMotorVel(Finish.settings.snowball_speed)
	end
	inst:PushEvent("projectile_launched", { bullet })
	-- endless: no ammo (and none shown on the skill)
	if pow.persistdata ~= nil and pow.persistdata.counter ~= 0 then
		pow.persistdata.counter = 0
		inst:PushEvent("update_power", pow.def)
	end
end

function Finish.FinishSnowball(Power)
	local def = rawget(Power.Items[Power.Slots.SKILL], Finish.SNOW)
	if def == nil then
		return false, "the game has no " .. Finish.SNOW
	end
	local triggers = def.event_triggers
	if type(triggers) ~= "table" or type(triggers.do_skill_throwsnowball) ~= "function" then
		return false, "a game update changed " .. Finish.SNOW
	end
	def.pretty = { name = Finish.SNOW_NAME, desc = Finish.SnowDesc() }
	def.icon = Finish.SNOW_ICON
	AddPrefab(def, Finish.SNOWBALL)
	def.on_add_fn = function(pow, inst)
		pow.persistdata.counter = 0 -- endless: nothing to count or reload
	end
	triggers.do_skill_throwsnowball = Finish.Throw
	triggers.reload_snowballs = function(pow, inst)
	end
	Finish.snow_done = true
	return true
end

-- The snowball projectile art's symbol, for the hand (looked up once). The
-- setting, else the ball: "ice_core_untex" (fx_projectile_snow_ball's build
-- holds ice_core_untex, the ball, 159 x 164 like the stone's 131 x 102 around
-- the same centre; lines_ntex, its motion lines; shadow). Checked against the
-- build itself when the game can list it; if a game update renamed the ball,
-- another ball-like symbol, or the stone stays.
Finish.SNOW_SYMBOL = "ice_core_untex"
function Finish.SnowSymbol()
	if Finish.snow_symbol ~= nil then
		return Finish.snow_symbol or nil
	end
	Finish.snow_symbol = false
	local set = Finish.settings.snowball_hand_symbol
	if set ~= nil then
		Finish.snow_symbol = set
		return set
	end
	local ok, names = pcall(function()
		local e = CreateEntity()
		e.entity:AddTransform()
		e.entity:AddAnimState()
		e.AnimState:SetBank(Finish.SNOW_BUILD)
		e.AnimState:SetBuild(Finish.SNOW_BUILD)
		e.AnimState:PlayAnimation("idle", true)
		local list = e.AnimState:GetSymbolNames()
		e:Remove()
		return list
	end)
	local pick
	if ok and type(names) == "table" and #names > 0 then
		for _, n in ipairs(names) do
			if n == Finish.SNOW_SYMBOL then
				pick = n
				break
			end
		end
		if pick == nil then
			for _, n in ipairs(names) do
				local low = type(n) == "string" and n:lower() or ""
				if (low:find("core") or low:find("snow") or low:find("ball")) and not low:find("shadow") and not low:find("line") then
					pick = n
					break
				end
			end
		end
	else
		pick = Finish.SNOW_SYMBOL -- the game can't list it: the known ball
	end
	if pick ~= nil then
		Finish.snow_symbol = pick
		Log(string.format('snowball in hand: "%s" from %s', pick, Finish.SNOW_BUILD))
	else
		Log("snowball in hand: no snowball art found (" .. tostring(ok and "no symbols" or names) .. "), the stone stays")
	end
	return pick
end

local function SnowInHand(inst)
	local sym = Finish.SnowSymbol()
	if sym ~= nil and inst.AnimState ~= nil then
		local SGCommon = require "stategraphs.sg_common"
		SGCommon.Fns.OverrideSymbolOnAllLayers(inst, Finish.ROCK_SYMBOL, Finish.SNOW_BUILD, sym)
		inst.skillslots_snow_in_hand = true
	end
end

local function StoneBack(inst)
	if inst.skillslots_snow_in_hand and inst.AnimState ~= nil then
		local SGCommon = require "stategraphs.sg_common"
		SGCommon.Fns.ClearOverrideSymbolOnAllLayers(inst, Finish.ROCK_SYMBOL)
	end
	inst.skillslots_snow_in_hand = nil
end
Finish.SnowInHand = SnowInHand
Finish.StoneBack = StoneBack

-- A state's exit, wrapped (the stategraph may already have wrapped it for its
-- generated events: then the original sits in orig_onexit).
local function WrapExit(st, fn)
	local field = st.orig_onexit ~= nil and "orig_onexit" or "onexit"
	local orig = st[field]
	st[field] = function(inst, from, to, ...)
		if orig ~= nil then
			orig(inst, from, to, ...)
		end
		fn(inst, from, to)
	end
end

-- The scoop's frame that lets the stick cancel it (the game's
-- SGPlayerCommon.Fns.SetCanMove in its timeline) taken out: the throw always
-- comes, as with Throw Stone. Returns how many were taken out.
function Finish.NoEarlyMove(st)
	local ok, SGPlayerCommon = pcall(require, "stategraphs.sg_player_common")
	local fns = ok and type(SGPlayerCommon) == "table" and SGPlayerCommon.Fns or nil
	local fn = type(fns) == "table" and fns.SetCanMove or nil
	if type(fn) ~= "function" or type(st.timeline) ~= "table" then
		return 0
	end
	local removed = 0
	for i = #st.timeline, 1, -1 do
		local ev = st.timeline[i]
		if type(ev) == "table" and ev.fn == fn then
			table.remove(st.timeline, i)
			removed = removed + 1
		end
	end
	return removed
end

-- Explosive Dive, "quick": its state (the game's skill_bow_primearrow_explode,
-- which only reroutes to the shared prime state) plays the prime animation at
-- QUICK_SPEED itself, primes at its moment, then goes straight into the bow's
-- Heavy Attack shot with the primed arrow. Not on a bow (no shot state): the
-- prime only, then idle.
function Finish.QuickDive(st)
	local FE = rawget(_G, "FrameEvent")
	if type(FE) ~= "table" and type(FE) ~= "function" then
		return false
	end
	st.tags = type(st.tags) == "table" and st.tags or {}
	local busy = false
	for _, t in ipairs(st.tags) do
		if t == "busy" then busy = true end
	end
	if not busy then
		table.insert(st.tags, "busy")
	end
	local speed = Finish.QUICK_SPEED
	st.onenter = function(inst)
		inst.AnimState:PlayAnimation(Finish.PRIME_ANIM)
		if inst.AnimState.SetDeltaTimeMultiplier ~= nil then
			inst.AnimState:SetDeltaTimeMultiplier(speed)
		end
	end
	-- the game's prime: the fx start at frame 4, primed at 14; here at half
	st.timeline = {
		FE(2, function(inst)
			inst:PushEvent("bow_primearrow_fxstart")
		end),
		FE(7, function(inst)
			inst:PushEvent("bow_primearrow_ready")
			local states = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.states or nil
			if inst:HasTag("bow") and type(states) == "table" and states.heavy_attack_shoot ~= nil then
				inst.sg:GoToState("heavy_attack_shoot", { shotstrength = Finish.settings.explosive_dive_shot })
			else
				inst.sg:GoToState("idle")
			end
		end),
	}
	for i, ev in ipairs(st.timeline) do
		ev.idx = i
	end
	local exit = st.onexit
	st.onexit = function(inst, ...)
		if inst.AnimState.SetDeltaTimeMultiplier ~= nil then
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end
		if exit ~= nil then
			return exit(inst, ...)
		end
	end
	return true
end

-- The throw's states (shared by every player): never "RELOAD!", the
-- snowball in hand from the scoop to the throw, the throw always comes.
function Finish.PatchStates(states, Call)
	local found = 0
	Call = Call or function(_, fn, ...) return pcall(fn, ...) end
	local in_hand = Finish.settings.snowball_in_hand
	Finish.early_move_removed = nil
	for _, st in ipairs(states) do
		if st.name == Finish.DIVE_STATE and Finish.dive_done and Finish.settings.explosive_dive_prime == "quick" then
			local ok, yes = pcall(Finish.QuickDive, st)
			Finish.quick_done = ok and yes == true
		end
		if not Finish.snow_done then
			-- (the snowball's states only when it's finished)
		elseif st.name == "skill_throwsnowball" then
			st.onenter = function(inst)
				inst.sg:GoToState("skill_throwsnowball_pre")
			end
			found = found + 1
		elseif st.name == "skill_throwsnowball_pre" then
			if Finish.settings.snowball_finish_throw then
				local ok, n = pcall(Finish.NoEarlyMove, st)
				Finish.early_move_removed = ok and n or 0
			end
			local enter = st.onenter
			st.onenter = function(inst, ...)
				if enter ~= nil then
					enter(inst, ...)
				end
				if in_hand then
					Call("snowball in hand", SnowInHand, inst)
				end
			end
			WrapExit(st, function(inst, from, to)
				if not (type(to) == "table" and to.name == "skill_throwsnowball_pst") then
					Call("snowball in hand", StoneBack, inst)
				end
			end)
			found = found + 1
		elseif st.name == "skill_throwsnowball_pst" then
			WrapExit(st, function(inst)
				Call("snowball in hand", StoneBack, inst)
			end)
			found = found + 1
		end
	end
	return found
end

-- Once, with the first player (the stategraphs are loaded by then).
function Finish.SetupPlayer(inst, Call)
	local quick = Finish.dive_done and Finish.settings.explosive_dive_prime == "quick"
	if not (Finish.snow_done or quick) or Finish.states_done then
		return
	end
	Finish.states_done = true
	local ok, PlayerSkillState = pcall(require, "playerskillstate")
	if ok and package.loaded["playerskillstates"] == nil then
		pcall(require, "playerskillstates")
	end
	local states = ok and PlayerSkillState.GetPlayerSkillStates ~= nil and PlayerSkillState.GetPlayerSkillStates() or nil
	local found = type(states) == "table" and Finish.PatchStates(states, Call) or 0
	if quick then
		Log(Finish.quick_done and "Explosive Dive: a quick prime, then straight into the Heavy Attack shot"
			or "Explosive Dive: the quick prime couldn't be set up (a game update?): the game's prime")
	end
	if not Finish.snow_done then
		return
	end
	if found < 3 then
		Log("Throw Snowball: a game update changed its states (" .. found .. " of 3 found); the snowball may shrug \"RELOAD!\"")
	end
	if Finish.settings.snowball_finish_throw then
		if (Finish.early_move_removed or 0) > 0 then
			Log("Throw Snowball: the stick waits for the throw (Throw Stone's way)")
		else
			Log("Throw Snowball: the scoop's move frame wasn't found (a game update?): the stick can still cancel it")
		end
	end
end

function Finish.Install(user, Power, powerutil)
	local s = Finish.LoadSettings(user)
	local done = {}
	if s.explosive_dive then
		local ok, yes, why = pcall(Finish.FinishDive, Power, powerutil)
		if ok and yes then
			done[#done + 1] = "Explosive Dive"
		else
			Log("Explosive Dive stays the game's: " .. tostring(ok and why or yes))
		end
	end
	if s.snowball then
		local ok, yes, why = pcall(Finish.FinishSnowball, Power)
		if ok and yes then
			done[#done + 1] = "Throw Snowball"
		else
			Log("Throw Snowball stays the game's: " .. tostring(ok and why or yes))
		end
	end
	for _, name in ipairs({ "bow_primearrow_cold", "bow_primearrow_acid" }) do
		local ok, yes, why = pcall(Finish.FixDip, Power, powerutil, name)
		if ok and yes then
			if s.bow_prime_dip == "anim" then
				done[#done + 1] = Finish.DIPS[name].name .. "'s dip with the prime animation"
			elseif s.bow_prime_dip == "arrow" then
				done[#done + 1] = Finish.DIPS[name].name .. "'s dip on the arrow"
			elseif s.bow_prime_dip == "plain" then
				done[#done + 1] = Finish.DIPS[name].name .. "'s dip sound only"
			end
		else
			Log(Finish.DIPS[name].name .. " stays the game's: " .. tostring(ok and why or yes))
		end
	end
	return done
end

return Finish
