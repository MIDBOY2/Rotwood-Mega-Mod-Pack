-- Skill Balance: the numbers of some skills, from scripts/skillbalance_settings.lua.
--
-- The skills keep the game's own code. Their numbers live in the game's skill
-- files (stategraphs/playerskills/*): a table of attack numbers the hit
-- function reads (changed in place), or numbers written into the hit itself
-- (changed on the attack just before the game's combat code uses it, see
-- WithAttacks). Each change is on its own: if a game update moves one, only
-- that one is skipped and the log says which.

local Main = {}

Main.TAG = "[Skill Balance]"

-- The weapons' own light attacks (game data: sg_player_cannon SINGLE,
-- sg_player_bow LIGHT_ATTACK_WEAK, sg_player_polearm LIGHT_ATTACK_1).
Main.LIGHT = { cannon = 1.25, bow = 0.85, polearm = 0.9 }

-- the ranged weapons' melee skills: skill state -> weapon
Main.MELEE = {
	{ state = "skill_cannon_butt", weapon = "cannon", name = "Battering Ram" },
	{ state = "skill_bow_melee", weapon = "bow", name = "Thwack" },
	{ state = "skill_polearm_shove", weapon = "polearm", name = "Crosscheck" },
}

Main.DEFAULTS = {
	enabled = true,
	melee_skills = { light_attack_mult = 1.5, knockdown = true, pushback = 1.75 },
	parry = { window_seconds = 0.67, crit_seconds = 3, counter_damage = 1.0, counter_pushback = 1.75, counter_range = 6 },
	order_in_the_court = { damage = { 1.7, 2.55, 3.0 }, focus_damage = { 2.55, 3.0, 4.75 }, radius = { 3.25, 3.5, 4.5 } },
	pole_vault = { takeoff = 0.5, landing = 2.0 },
	dribble = { damage = 1.75, focus_damage = 2.5 },
	hazard_idol = { health_cost = 10 },
	impulsive_stomp = { damage = 2.5 },
	grody_groak_gulp = { damage = 0.25 },
	mini_parry = { window_frames = 5, damage_taken = 0.02, crosscheck = true, thwack = true, battering_ram = true,
		order_in_the_court = true, dribble = true },
	big_blast = { charge_ticks = 16, spread = 1, damage = 4, focus_damage = 5, shell = "game", max_size = 1, end_blast = false, perfect_ticks = 0, tap = 1,
		tap_damage = 0.5, tap_refund = false },
	throw_rock = { damage = 18 },
	snap_attacks = { damage_mult = 2 },
	sharpened_reflexes = { any_attack_after_block = true, guard_window_seconds = 30 },
	backfire = { damage = { 0.86, 3, 4.57 }, focus_damage = { 1.29, 4, 5.71 }, reach = 1.75, radius = 1.2 },
	community_garden = { heal = 30, damage_per_stock = 4000, max_stocks = 3, full_heal = 100, dummy = true },
	voice_of_the_myriad = { damage_per_stock = 2000, max_stocks = 1, seconds = 6, dummy = true },
	eggsabre_run = { run_bonus = { 60, 70, 80 } },
	stall_log = { seconds = 0.5 },
}

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

-- bulletproofing (skillbalance/guard.lua): this mod's part of the game's code
-- runs through Main.G; an error is logged and the game carries on
Main.G = require("skillbalance.guard").Shared(Main.TAG)

-- A section: the user's table filled in from the defaults (same types only),
-- false = off, anything else = the defaults.
local function Section(default, user)
	if user == false then
		return false
	end
	local s = {}
	for k, v in pairs(default) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			local d = default[k]
			if d ~= nil and type(v) == type(d) then
				if type(d) == "table" then
					-- a list of numbers ({ tap, half, full }): numbers only, the rest from the default
					local list = {}
					for i = 1, #d do
						list[i] = type(v[i]) == "number" and v[i] or d[i]
					end
					s[k] = list
				else
					s[k] = v
				end
			end
		end
	end
	return s
end

function Main.LoadSettings(user)
	local s = { enabled = true }
	if type(user) == "table" and user.enabled == false then
		s.enabled = false
	end
	local u = type(user) == "table" and user or {}
	for k, v in pairs(Main.DEFAULTS) do
		if k ~= "enabled" then
			s[k] = Section(v, u[k]) -- (false = that skill left alone)
		end
	end
	s.guard = u.guard ~= false
	Main.G.on = s.guard
	Main.settings = s
	return s
end

----------------------------------------------------------------------------
-- Finding the game's pieces

function Main.FindUpvalue(fn, wanted)
	if type(fn) ~= "function" then
		return nil
	end
	for i = 1, 255 do
		local name, value = debug.getupvalue(fn, i)
		if name == nil then
			return nil
		end
		if name == wanted then
			return value, i
		end
	end
	return nil
end

local states_by_name
local function SkillStates()
	if states_by_name == nil then
		require "playerskillstates" -- makes every skill state (the game does it when it builds the player's stategraph)
		local PlayerSkillState = require "playerskillstate"
		states_by_name = {}
		for _, st in ipairs(PlayerSkillState:GetPlayerSkillStates()) do
			states_by_name[st.name] = st
		end
	end
	return states_by_name
end

function Main.State(name)
	local st = SkillStates()[name]
	if st == nil then
		error("skill state " .. name .. " not found", 0)
	end
	return st
end

-- the state's handler for an event (the game's EventHandler object)
function Main.Handler(state, event)
	local list = state.events ~= nil and state.events[event] or nil
	local h = list ~= nil and list[1] or nil
	if h == nil or type(h.fn) ~= "function" then
		error(state.name .. " has no " .. event .. " handler", 0)
	end
	return h
end

----------------------------------------------------------------------------
-- Changing a hit just before the game's combat code takes it

local KINDS = { "DoBasicAttack", "DoKnockbackAttack", "DoKnockdownAttack" }

-- Runs fn(...) with the player's attacks going through adjust(attack, kind)
-- first. adjust can change the attack and return another kind to use
-- ("DoKnockdownAttack"). Only the skill's own hits: attacks made while the
-- game handles one of them (powers reacting to the hit) go through as they are.
function Main.WithAttacks(inst, adjust, fn, ...)
	local combat = inst ~= nil and inst.components ~= nil and inst.components.combat or nil
	if combat == nil then
		return fn(...)
	end
	local raw, orig = {}, {}
	for _, k in ipairs(KINDS) do
		raw[k] = rawget(combat, k)
		orig[k] = combat[k]
	end
	local depth = 0
	for _, k in ipairs(KINDS) do
		rawset(combat, k, function(self, attack, ...)
			local use = k
			if depth == 0 and attack ~= nil then
				local ok, r = pcall(adjust, attack, k)
				if ok and type(r) == "string" and orig[r] ~= nil then
					use = r
				end
			end
			depth = depth + 1
			local results = table.pack(pcall(orig[use], self, attack, ...))
			depth = depth - 1
			if not results[1] then
				error(results[2], 0)
			end
			return table.unpack(results, 2, results.n)
		end)
	end
	local results = table.pack(pcall(fn, ...))
	for _, k in ipairs(KINDS) do
		rawset(combat, k, raw[k])
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- the state's hit handler, with adjust on its hits
function Main.WrapHits(state, adjust)
	local h = Main.Handler(state, "hitboxtriggered")
	if h.skillbalance_orig == nil then
		h.skillbalance_orig = h.fn
	end
	local orig = h.skillbalance_orig
	h.fn = function(inst, data, ...)
		return Main.WithAttacks(inst, adjust, orig, inst, data, ...)
	end
end

----------------------------------------------------------------------------
-- The changes

local Changes = {}

function Changes.melee_skills(s)
	local done = {}
	for _, m in ipairs(Main.MELEE) do
		local dmg = s.light_attack_mult * Main.LIGHT[m.weapon]
		local state = Main.State(m.state)
		Main.WrapHits(state, function(attack)
			local target = attack.GetTarget ~= nil and attack:GetTarget() or nil
			Main.Stall.Note(attack.GetAttacker ~= nil and attack:GetAttacker() or nil,
				m.name .. " hit " .. tostring(target ~= nil and target.prefab or "?"))
			attack:SetDamageMod(dmg)
			attack:SetPushback(s.pushback)
			if s.knockdown then
				return "DoKnockdownAttack"
			end
		end)
		done[#done + 1] = string.format("%s %.2f", m.name, dmg)
	end
	return table.concat(done, ", ") .. string.format(" (%s, pushback %s)", s.knockdown and "knockdown" or "their own hit", tostring(s.pushback))
end

local function ParryHandlers(state)
	local list = {}
	for _, ev in ipairs({ "attacked", "knockback", "knockdown" }) do
		local l = state.events[ev]
		if l ~= nil and l[1] ~= nil then
			list[#list + 1] = l[1]
		end
	end
	return list
end

-- Is the player in this state? By name: the game gives each kind of entity its
-- own deep copy of a stategraph (entityscript.lua LoadStateGraph: deepcopy(sg)
-- per prefab), so the state a player is in is a copy of the one changed here,
-- never the same table. (0.2.14 compared the tables: the mini parry never
-- started, and a landed parry was never marked.)
local function InState(inst, state)
	local cur = inst.sg ~= nil and inst.sg.currentstate or nil
	return cur ~= nil and state ~= nil and cur.name == state.name
end
Main.InState = InState

-- (the parry's own parts, run in the guard)
local function Parrying(inst)
	return inst.sg:HasStateTag("parrying")
end
local function MarkParried(inst, state)
	if InState(inst, state) then
		inst.sg.statemem.skillbalance_parried = true
	end
end
-- the window outlasts the animation: hold its last pose
local function HoldPose(inst)
	if inst.sg:HasStateTag("parrying") and not inst.sg.statemem.skillbalance_parried then
		inst.AnimState:Pause()
		inst.sg.statemem.skillbalance_held = true
		return true
	end
	return false
end
-- the hold ends: the animation goes on (true: it was held)
local function LetGo(inst)
	if inst.sg.statemem.skillbalance_held then
		inst.sg.statemem.skillbalance_held = nil
		inst.AnimState:Resume()
		return true
	end
	return false
end

function Changes.parry(s)
	local state = Main.State("skill_parry")
	-- the window: the game's PARRY_WINDOW_FRAMES (anim frames, 30 a second)
	local frames = math.max(1, math.floor(s.window_seconds * 30 + 0.5))
	local _, idx = Main.FindUpvalue(state.onenter, "PARRY_WINDOW_FRAMES")
	if idx == nil then
		error("parry window not found", 0)
	end
	debug.setupvalue(state.onenter, idx, frames)

	-- A window longer than the parry animation (16 frames): hold its last pose
	-- until the window closes instead of leaving early. Not after a parry
	-- landed (the game lets you act right away then).
	for _, h in ipairs(ParryHandlers(state)) do
		local orig = h.skillbalance_orig or h.fn
		h.skillbalance_orig = orig
		h.fn = function(inst, data, ...)
			local okw, was = Main.G.Call("parry", Parrying, inst)
			local r = orig(inst, data, ...)
			if okw and was then
				Main.G.Call("parry", MarkParried, inst, state)
			end
			return r
		end
	end
	local animover = Main.Handler(state, "animover")
	local orig_animover = animover.skillbalance_orig or animover.fn
	animover.skillbalance_orig = orig_animover
	animover.fn = function(inst, ...)
		local ok, held = Main.G.Call("parry hold", HoldPose, inst)
		if ok and held then
			return
		end
		return orig_animover(inst, ...)
	end
	local orig_timeout = state.skillbalance_ontimeout or state.ontimeout
	state.skillbalance_ontimeout = orig_timeout
	state.ontimeout = function(inst, ...)
		orig_timeout(inst, ...)
		local ok, was = Main.G.Call("parry hold", LetGo, inst)
		if ok and was then
			inst.sg:GoToState("skill_pst")
		end
	end
	local orig_exit = state.skillbalance_onexit or state.onexit
	state.skillbalance_onexit = orig_exit
	state.onexit = function(inst, ...)
		Main.G.Call("parry hold", LetGo, inst)
		return orig_exit(inst, ...)
	end

	-- 100% crit for crit_seconds (the power's own number)
	local Power = require "defs.powers.power"
	local def = Power.FindPowerByName("parry")
	local tuning = def ~= nil and def.tuning ~= nil and def.tuning.COMMON or nil
	if tuning == nil or tuning.seconds == nil then
		error("parry crit time not found", 0)
	end
	tuning.seconds = s.crit_seconds

	Main.parry = s -- the counter hit: Main.SetupPlayer
	return string.format("window %.2f s, crits %s s%s", frames / 30, tostring(s.crit_seconds),
		s.counter_damage > 0 and string.format(", counter %s knockdown", tostring(s.counter_damage)) or "")
end

-- The enemy you parried: knocked over (the "parry" event the game sends).
function Main.ParryCounter(inst, data)
	local s = Main.parry
	if s == nil or s.counter_damage <= 0 then
		return false
	end
	local attack = type(data) == "table" and data.attack or nil
	local target = attack ~= nil and attack.GetAttacker ~= nil and attack:GetAttacker() or nil
	if target == nil or target == inst or not target:IsValid() or target:HasTag("player")
		or target.components == nil or target.components.combat == nil or target.components.health == nil
		or target.components.health:IsDead() then
		return false
	end
	if inst:GetDistanceSqTo(target) > s.counter_range * s.counter_range then
		return false
	end
	local counter = Attack(inst, target)
	counter:SetDamageMod(s.counter_damage)
	counter:SetPushback(s.counter_pushback)
	counter:SetDir(inst:GetAngleTo(target))
	counter:SetHitstunAnimFrames(10)
	counter:SetID("skill")
	counter:SetNameID("PARRY_COUNTER")
	counter:SetHitFlags(Attack.HitFlags.GROUND_AIR)
	return inst.components.combat:DoKnockdownAttack(counter) or false
end

function Changes.order_in_the_court(s)
	local h = Main.Handler(Main.State("skill_hammer_thump_atk"), "hitboxtriggered")
	local hit_fn = h.skillbalance_orig or h.fn
	local attacks = Main.FindUpvalue(hit_fn, "ATTACKS")
	if type(attacks) ~= "table" or attacks.TIER0 == nil or attacks.TIER2 == nil then
		error("Order in the Court's numbers not found", 0)
	end
	for i, tier in ipairs({ "TIER0", "TIER1", "TIER2" }) do
		local a = attacks[tier]
		a.DAMAGE_NORMAL = s.damage[i]
		a.DAMAGE_FOCUS = s.focus_damage[i]
		a.RADIUS = s.radius[i]
	end
	return string.format("%s / %s / %s, radius %s / %s / %s", s.damage[1], s.damage[2], s.damage[3], s.radius[1], s.radius[2], s.radius[3])
end

function Changes.pole_vault(s)
	Main.WrapHits(Main.State("skill_polearm_vault"), function(attack) attack:SetDamageMod(s.takeoff) end)
	Main.WrapHits(Main.State("skill_polearm_vault_pst"), function(attack) attack:SetDamageMod(s.landing) end)
	return string.format("%s / %s", s.takeoff, s.landing)
end

function Changes.dribble(s)
	local h = Main.Handler(Main.State("skill_shotput_slam_normal"), "hitboxtriggered")
	local hit_fn = h.skillbalance_orig or h.fn
	local attacks = Main.FindUpvalue(hit_fn, "ATTACKS")
	if type(attacks) ~= "table" or attacks.NORMAL == nil or attacks.FOCUS == nil then
		error("Dribble's numbers not found", 0)
	end
	attacks.NORMAL.DAMAGE = s.damage
	attacks.FOCUS.DAMAGE = s.focus_damage
	return string.format("%s / Focus %s", s.damage, s.focus_damage)
end

function Changes.hazard_idol(s)
	local state = Main.State("skill_hammer_totem")
	local Power = require "defs.powers.power"
	local def = Power.FindPowerByName("hammer_totem")
	local tuning = def ~= nil and def.tuning ~= nil and def.tuning.COMMON or nil
	if tuning == nil or tuning.healthtocreate == nil then
		error("Hazard Idol's cost not found", 0)
	end
	-- the timeline step that takes the health (it reads the power's number then)
	local step
	for _, ev in ipairs(state.timeline or {}) do
		local fn = ev.skillbalance_orig or ev.fn
		if Main.FindUpvalue(fn, "Power") ~= nil then
			step = ev
		end
	end
	if step == nil then
		error("Hazard Idol's health step not found", 0)
	end
	local orig = step.skillbalance_orig or step.fn
	step.skillbalance_orig = orig
	step.fn = function(inst, ...)
		local keep = tuning.healthtocreate
		tuning.healthtocreate = s.health_cost
		local results = table.pack(pcall(orig, inst, ...))
		tuning.healthtocreate = keep -- (the heal for whoever breaks it stays the game's)
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
	return string.format("costs %s", tostring(s.health_cost))
end

function Changes.impulsive_stomp(s)
	local SGPlayerCleaver = require "stategraphs.sg_player_cleaver_common"
	local mods = SGPlayerCleaver.Consts ~= nil and SGPlayerCleaver.Consts.ATTACK_DAMAGE_MOD or nil
	if type(mods) ~= "table" or mods.SKILL_BASH_PRIME == nil then
		error("Impulsive Stomp's number not found", 0)
	end
	mods.SKILL_BASH_PRIME = s.damage
	return tostring(s.damage)
end

function Changes.grody_groak_gulp(s)
	Main.WrapHits(Main.State("skill_miniboss_groak_vacuum"), function(attack) attack:SetDamageMod(s.damage) end)
	return tostring(s.damage) .. " a hit"
end

-- Mini parry: a perfect guard at the start of one quick skill per weapon,
-- treated like the Greatsword's perfect guard. A hit in the first frames:
-- the guard's small damage, the game's perfect-guard protections (the
-- "block_perfect" state tag: hit streak kept, the enemy's on-hit effects
-- skipped), no flinch (the skill goes on, its own hit is the counter), the
-- perfect guard's spark and shudder, and Owlitzer's Morphic gem fires like on
-- a perfect guard. Not Parry's crit buff (a perfect guard doesn't give it) and
-- nothing that belongs to the Greatsword (its mastery, gear and powers).
Main.GUARDS = {
	{ key = "crosscheck", state = "skill_polearm_shove", name = "Crosscheck" },
	{ key = "thwack", state = "skill_bow_melee", name = "Thwack" },
	{ key = "battering_ram", state = "skill_cannon_butt", name = "Battering Ram" },
	{ key = "order_in_the_court", state = "skill_hammer_thump", name = "Order in the Court" },
	{ key = "dribble", state = "skill_shotput_slam", name = "Dribble" },
}
Main.GUARD_EVENTS = { "attacked", "knockback", "knockdown" }
Main.GUARD_SOURCE = "skillbalance_guard"
local Guard = {}
Main.Guard = Guard

function Guard.Active(inst)
	local sm = inst ~= nil and inst.sg ~= nil and inst.sg.statemem or nil
	return sm ~= nil and sm.skillbalance_guard == true
end

function Guard.Start(inst, s)
	local sg = inst.sg
	local sm = sg.statemem
	sm.skillbalance_guard = true
	sm.skillbalance_guard_tags = {}
	for _, tag in ipairs({ "block_perfect", "nointerrupt" }) do
		if not sg:HasStateTag(tag) then
			sg:AddStateTag(tag)
			table.insert(sm.skillbalance_guard_tags, tag)
		end
	end
	local combat = inst.components ~= nil and inst.components.combat or nil
	if combat ~= nil and combat.SetDamageReceivedMult ~= nil then
		combat:SetDamageReceivedMult(Main.GUARD_SOURCE, s.damage_taken)
	end
	local name = sg.currentstate ~= nil and sg.currentstate.name or nil
	local started = sg.statestarttick
	local function stop()
		if inst:IsValid() and inst.sg ~= nil and inst.sg.currentstate ~= nil and inst.sg.currentstate.name == name
			and inst.sg.statestarttick == started then
			Guard.Stop(inst)
		end
	end
	if inst.DoTaskInAnimFrames ~= nil then
		inst:DoTaskInAnimFrames(s.window_frames, stop)
	else
		inst:DoTaskInTime(s.window_frames / 30, stop)
	end
end

function Guard.Stop(inst)
	local combat = inst.components ~= nil and inst.components.combat or nil
	if combat ~= nil and combat.RemoveDamageReceivedMult ~= nil then
		combat:RemoveDamageReceivedMult(Main.GUARD_SOURCE)
	end
	local sg = inst.sg
	local sm = sg ~= nil and sg.statemem or nil
	if sm == nil or not sm.skillbalance_guard then
		return
	end
	sm.skillbalance_guard = nil
	for _, tag in ipairs(sm.skillbalance_guard_tags or {}) do
		sg:RemoveStateTag(tag)
	end
	sm.skillbalance_guard_tags = nil
end

-- A hit inside the window: what the game does on a perfect guard, minus the
-- Greatsword's own block reactions.
function Guard.OnHit(inst, data)
	local sm = inst.sg.statemem
	-- one hit can send "attacked" and "knockdown" (or "knockback"): react once
	local attack = type(data) == "table" and data.attack or nil
	local tick = rawget(_G, "GetTick") ~= nil and GetTick() or nil
	if (attack ~= nil and attack == sm.skillbalance_last_attack)
		or (attack == nil and tick ~= nil and tick == sm.skillbalance_last_tick) then
		return
	end
	sm.skillbalance_last_attack = attack or sm.skillbalance_last_attack
	sm.skillbalance_last_tick = tick
	sm.skillbalance_guarded = (sm.skillbalance_guarded or 0) + 1
	local c = inst.components
	if c.hitshudder ~= nil and c.hitshudder.DoShudder ~= nil and TUNING ~= nil then
		pcall(c.hitshudder.DoShudder, c.hitshudder, TUNING.HITSHUDDER_AMOUNT_LIGHT or 0.1, HitStopLevel ~= nil and HitStopLevel.HEAVY or 4)
	end
	local okfx, EffectEvents = pcall(require, "effectevents")
	if okfx and type(EffectEvents) == "table" and EffectEvents.MakeEventSpawnEffect ~= nil then
		pcall(EffectEvents.MakeEventSpawnEffect, inst, { fxname = "hits_player_block_2", inheritrotation = true,
			flipfacingandrotation = true, offx = 1 })
	end
	local pm = c.powermanager
	if pm ~= nil and pm.GetPowerByName ~= nil then
		local ok, pow = pcall(pm.GetPowerByName, pm, "morphic_owlitzer")
		local triggers = ok and pow ~= nil and pow.def ~= nil and pow.def.event_triggers or nil
		if triggers ~= nil and type(triggers.block_hit) == "function" then
			pcall(triggers.block_hit, pow, inst, data)
		end
	end
	inst:PushEvent("skillbalance_mini_parry", data)
	Main.Stall.Note(inst, "mini parry (hit by " .. tostring(attack ~= nil and attack.GetAttacker ~= nil and attack:GetAttacker() ~= nil
		and attack:GetAttacker().prefab or "?") .. ")")
end

function Changes.mini_parry(s)
	if rawget(_G, "EventHandler") == nil then
		error("EventHandler not found", 0)
	end
	local done, missing = {}, {}
	for _, g in ipairs(Main.GUARDS) do
		local found, st = false, nil
		if s[g.key] ~= false then
			found, st = pcall(Main.State, g.state)
			if not found then
				missing[#missing + 1] = g.name
			end
		end
		if found then
			if not st.skillbalance_guard then
				st.skillbalance_guard = true
				local orig_enter, orig_exit = st.onenter, st.onexit
				st.onenter = function(inst, ...)
					local results = table.pack((orig_enter or function() end)(inst, ...))
					if InState(inst, st) then
						local ok, err = pcall(Guard.Start, inst, s)
						if not ok then
							Main.Log("mini parry error: " .. tostring(err))
						end
					end
					return table.unpack(results, 1, results.n)
				end
				st.onexit = function(inst, ...)
					pcall(Guard.Stop, inst)
					if orig_exit ~= nil then
						return orig_exit(inst, ...)
					end
				end
				for _, ev in ipairs(Main.GUARD_EVENTS) do
					st.events[ev] = st.events[ev] or {}
					local had = #st.events[ev] > 0
					table.insert(st.events[ev], EventHandler(ev, function(inst, data)
						if Guard.Active(inst) then
							pcall(Guard.OnHit, inst, data)
							return nil -- handled: no flinch, the skill goes on
						end
						return not had -- outside the window: as before
					end))
				end
			end
			done[#done + 1] = g.name
		end
	end
	if #done == 0 then
		error(#missing > 0 and ("skill states not found: " .. table.concat(missing, ", ")) or "every skill off", 0)
	end
	return string.format("%s (%d frames, %s%% damage)%s", table.concat(done, ", "), s.window_frames, tostring(s.damage_taken * 100),
		#missing > 0 and ("; not found: " .. table.concat(missing, ", ")) or "")
end

-- Big Blast (the Cannon's charged skill, skill_cannon_aim): every charge
-- (CHARGED_THRESHOLD_TICKS, 25 ticks = 0.42 s; 6 charges took 2.5 s) adds one
-- big shot at DAMAGE 4 / Focus 5, fanned out up to 50 degrees each side
-- (BIG_BLAST_BULLET_DATA), so one enemy took 2 or 3 of the 6: less than the
-- same ammo fired as plain shots, after a long stand-still charge.
-- charge_ticks: ticks a charge takes; spread: the fan's angle times this;
-- damage / focus_damage: each big shot.
-- The charge is in the skill's state (set now); the shot is in the Cannon's
-- own stategraph, set when the game builds it (modmain: AddStateGraphPostInit).
Main.SG_POST = {}
Main.SG_POST_LATE = {} -- joined at the end of Install

local function Ticks(s)
	return math.max(1, math.floor(s.charge_ticks + 0.5))
end

local function Now()
	local fn = rawget(_G, "GetTick")
	return fn ~= nil and fn() or 0
end

-- One big shell (shell = "one"): the charges make one shell. Its size: the
-- game's Big Blast shell (max_size = 1, the default); max_size above 1 grows
-- it with the charges, up to max_size times the game's at 6. It does each charge's damage at once, goes through every enemy on its way
-- (pierce) and ends in the mortar's explosion (end_blast: one charge's damage
-- around it). Released right on a charge's flash (within perfect_ticks): a
-- Critical Hit. shell = "fan" keeps the six shells (0.2.3's Big Blast).
local BASE_SCALE = 1.5 -- the game's Big Blast shell (player_cannon_bigblast_projectile)
local shell_logged = 0

function Main.ShellSize(s, n)
	return 1 + (s.max_size - 1) * (math.max(1, math.min(6, n)) - 1) / 5
end

-- the end blast: the mortar's explosion where the shell stops, one charge's damage around it
local function EndBlast(owner, x, z, size, focus, crit, s)
	if owner == nil or not owner:IsValid() then
		return 0
	end
	local EffectEvents = require "effectevents"
	local scale = 0.8 * size
	pcall(EffectEvents.MakeEventSpawnEffect, owner, { fxname = focus and "cannon_mortar_explosion_focus" or "cannon_mortar_explosion",
		offset_is_absolute = true, offx = x, offy = 0, offz = z, scalex = scale, scalez = scale })
	local find = rawget(_G, "FindEnemiesInRange")
	local AttackCls = rawget(_G, "Attack")
	local combat = owner.components ~= nil and owner.components.combat or nil
	if find == nil or AttackCls == nil or combat == nil then
		return 0
	end
	local n = 0
	for _, ent in ipairs(find(x, z, 2 * size) or {}) do
		if ent:IsValid() and ent ~= owner then
			local attack = AttackCls(owner, ent)
			attack:SetDamageMod(focus and s.focus_damage or s.damage)
			attack:SetHitstunAnimFrames(10)
			attack:SetPushback(1.5)
			attack:SetFocus(focus)
			attack:SetID("skill")
			attack:SetNameID("BIGBLAST")
			if crit and attack.SetForceCriticalHit ~= nil and AttackCls.ForceCrit ~= nil then
				attack:SetForceCriticalHit(AttackCls.ForceCrit.id.ALWAYS)
			end
			if combat:DoKnockbackAttack(attack) then
				n = n + 1
			end
		end
	end
	return n
end

-- the shell, fired by the game's Big Blast (the "blast" state with the charges)
local function OneShell(U, s, inst, amount)
	local ATTACK = U.ATTACKS.BIGBLAST
	local n = math.max(1, math.min(amount or 1, #U.BIG_BLAST_BULLET_DATA))
	local focus = U.IsFocusLightForRemaining(inst, U.GetRemainingAmmo(inst)) and true or false
	local damagemod = (focus and ATTACK.DAMAGE_FOCUS or ATTACK.DAMAGE) * n
	local hitstun = focus and ATTACK.HITSTUN_FOCUS or ATTACK.HITSTUN
	local pushback = focus and ATTACK.PUSHBACK_FOCUS or ATTACK.PUSHBACK
	local speed = U.GetModifiedHeavyProjectileSpeed(inst, focus and ATTACK.SPEED_FOCUS or ATTACK.SPEED)
	local range = U.GetModifiedProjectileRange(inst, focus and ATTACK.RANGE_FOCUS or ATTACK.RANGE)
	local prefab = focus and "player_cannon_bigblast_focus_projectile" or "player_cannon_bigblast_projectile"
	local size = Main.ShellSize(s, n)
	local flash = inst.sg.mem.skillbalance_flash
	inst.sg.mem.skillbalance_flash = nil
	local crit = s.perfect_ticks > 0 and flash ~= nil and Now() - flash <= s.perfect_ticks

	local bullet = U.SGCommon.Fns.SpawnAtAngleDist(inst, prefab, 2, 0)
	if bullet ~= nil then
		bullet:GlobalSetup(inst)
		bullet:Setup(inst, damagemod, hitstun, pushback, speed, range, focus, inst.sg.mem.attack_type, inst.sg.mem.attack_id, 1, 1, true)
		local pos = bullet:GetPosition()
		local y_offset = inst.sg.statemem.projectile_y_offset ~= nil and inst.sg.statemem.projectile_y_offset or 1.8
		bullet.Transform:SetPosition(pos.x, pos.y + y_offset, pos.z)
		bullet.AnimState:SetScale(BASE_SCALE * size, BASE_SCALE * size)
		bullet.skillbalance_crit = crit or nil
		if size > 1 and bullet.components ~= nil and bullet.components.hitbox ~= nil then
			-- a hitbox as big as the shell (the game's is for the small one)
			local half, thick = 0.5 * (size - 1) + 0.1, 1.75 * size
			bullet:DoPeriodicTicksTask(0, function()
				if bullet:IsValid() and bullet.components.hitbox ~= nil then
					bullet.components.hitbox:PushBeam(-half, half, thick, rawget(_G, "HitPriority") ~= nil and HitPriority.PLAYER_PROJECTILE or nil)
				end
			end)
		end
		if s.end_blast then
			bullet:ListenForEvent("onremove", function(b)
				local p = b:GetPosition()
				pcall(EndBlast, inst, p.x, p.z, size, focus, crit, s)
			end)
		end
		inst:PushEvent("projectile_launched", { bullet })
	end

	local previous = U.GetRemainingAmmo(inst)
	U.UpdateAmmo(inst, n)
	if U.GetRemainingAmmo(inst) <= previous and U.SGPlayerCommon.Fns.Cannon_PlayAmmoSound ~= nil then
		U.SGPlayerCommon.Fns.Cannon_PlayAmmoSound(inst, U.GetRemainingAmmo(inst), inst.sg.mem.cannon_single_shot and 70 or 100)
	end
	if shell_logged < 10 then
		shell_logged = shell_logged + 1
		Main.Log(string.format("Big Blast: one shell, %d charge%s, %g x your damage%s, size x%.2f%s", n, n == 1 and "" or "s",
			damagemod, focus and " (Focus)" or "", size, crit and ", released on the flash: Critical Hit" or ""))
	end
	return bullet
end
Main.OneShell = OneShell

-- the hits of a shell released on the flash: Critical Hits (the projectile's
-- own hit code makes the Attack, so it's marked on the way into Combat)
local crit_hooked = false
local function HookShellCrits()
	if crit_hooked then
		return true
	end
	local ok, Combat = pcall(require, "components.combat")
	local AttackCls = rawget(_G, "Attack")
	if not ok or type(Combat) ~= "table" or AttackCls == nil or AttackCls.ForceCrit == nil then
		return false
	end
	-- (every hit in the game passes here: the check runs in the guard)
	local function ShellCrit(attack)
		local proj = attack.GetProjectile ~= nil and attack:GetProjectile() or nil
		if proj ~= nil and proj.skillbalance_crit and attack.SetForceCriticalHit ~= nil then
			attack:SetForceCriticalHit(AttackCls.ForceCrit.id.ALWAYS)
		end
	end
	for _, name in ipairs({ "DoKnockbackAttack", "DoBasicAttack" }) do
		local orig = Combat[name]
		if type(orig) == "function" then
			Combat[name] = function(self, attack, ...)
				if attack ~= nil then
					Main.G.Call("Big Blast crit", ShellCrit, attack)
				end
				return orig(self, attack, ...)
			end
		end
	end
	crit_hooked = true
	return true
end
Main.HookShellCrits = HookShellCrits

local SHELL_UPVALUES = { "ATTACKS", "BIG_BLAST_BULLET_DATA", "IsFocusLightForRemaining", "GetRemainingAmmo", "GetModifiedProjectileRange",
	"GetModifiedHeavyProjectileSpeed", "UpdateAmmo", "SGCommon", "SGPlayerCommon" }

function Main.BigBlastShots(sg, s)
	local blast = type(sg) == "table" and type(sg.states) == "table" and sg.states.blast or nil
	local big, bi = nil, nil
	if blast ~= nil then
		big, bi = Main.FindUpvalue(blast.onenter, "DoBigBlast")
	end
	if big ~= nil and Main.skillbalance_shell_orig ~= nil and big == Main.skillbalance_shell_fn then
		big = Main.skillbalance_shell_orig -- built again: the game's function is behind ours
	end
	local attacks = big ~= nil and Main.FindUpvalue(big, "ATTACKS") or nil
	local fan = big ~= nil and Main.FindUpvalue(big, "BIG_BLAST_BULLET_DATA") or nil
	if type(attacks) ~= "table" or type(attacks.BIGBLAST) ~= "table" or type(fan) ~= "table" then
		error("Big Blast's shot not found", 0)
	end
	local shot = attacks.BIGBLAST
	shot.skillbalance_was = shot.skillbalance_was or { shot.DAMAGE, shot.DAMAGE_FOCUS }
	shot.DAMAGE = s.damage
	shot.DAMAGE_FOCUS = s.focus_damage
	local widest = 0
	for _, shots in pairs(fan) do
		if type(shots) == "table" then
			for _, b in ipairs(shots) do
				if type(b) == "table" and type(b.angle) == "number" then
					b.skillbalance_angle = b.skillbalance_angle or b.angle
					b.angle = b.skillbalance_angle * s.spread
					widest = math.max(widest, math.abs(b.angle))
				end
			end
		end
	end
	local what = string.format("Big Blast shots: %s / Focus %s each (was %s / %s)", tostring(s.damage),
		tostring(s.focus_damage), tostring(shot.skillbalance_was[1]), tostring(shot.skillbalance_was[2]))
	if s.shell ~= "one" then
		return what .. string.format(", six shells, widest %g degrees", widest)
	end
	-- one big shell: the game's helpers the shell needs (the original's own locals)
	local U = {}
	for _, name in ipairs(SHELL_UPVALUES) do
		U[name] = Main.FindUpvalue(big, name)
		if U[name] == nil then
			error("Big Blast's " .. name .. " not found (six shells kept)", 0)
		end
	end
	local orig = big
	local fn = function(inst, amount, ...)
		if Main.settings ~= nil and Main.settings.big_blast and Main.settings.big_blast.shell == "one" then
			return OneShell(U, s, inst, amount)
		end
		return orig(inst, amount, ...)
	end
	Main.skillbalance_shell_orig, Main.skillbalance_shell_fn = orig, fn
	debug.setupvalue(blast.onenter, bi, fn)
	local crits = s.perfect_ticks > 0 and HookShellCrits()
	return what .. string.format(", one big shell (%s, through every enemy%s%s)",
		s.max_size == 1 and "the game's size" or string.format("x%g at 6 charges", s.max_size),
		s.end_blast and ", the mortar's blast at the end" or "", crits and string.format(", Critical Hit on the flash (%d ticks)", s.perfect_ticks) or "")
end

function Changes.big_blast(s)
	if s.shell ~= "one" and s.shell ~= "fan" and s.shell ~= "game" then
		s.shell = "game"
	end
	s.max_size = math.max(0.5, math.min(4, s.max_size))
	s.perfect_ticks = math.max(0, math.floor(s.perfect_ticks + 0.5))
	s.tap = math.max(0, math.min(6, math.floor(s.tap + 0.5)))
	local aim = Main.State("skill_cannon_aim")
	local charge_fn, ci = Main.FindUpvalue(aim.onupdate, "_UpdateChargedTicks")
	if charge_fn ~= nil and Main.skillbalance_charge_orig ~= nil and charge_fn == Main.skillbalance_charge_fn then
		charge_fn = Main.skillbalance_charge_orig
	end
	local ticks, ti = Main.FindUpvalue(charge_fn, "CHARGED_THRESHOLD_TICKS")
	if type(ticks) ~= "number" or ti == nil then
		error("Big Blast's charge time not found", 0)
	end
	-- (the four aim/run states share the one _UpdateChargedTicks function)
	debug.setupvalue(charge_fn, ti, Ticks(s))
	-- the moment each charge stocks (the cannon flashes): for the release on the flash
	if Main.skillbalance_charge_fn == nil then
		local orig = charge_fn
		local wrapped = function(inst, ...)
			local mem = inst.sg ~= nil and inst.sg.mem or nil
			local before = mem ~= nil and mem.charges_stocked or 0
			local results = table.pack(orig(inst, ...))
			if mem ~= nil and (mem.charges_stocked or 0) > before then
				mem.skillbalance_flash = Now()
			end
			return table.unpack(results, 1, results.n)
		end
		Main.skillbalance_charge_orig, Main.skillbalance_charge_fn = orig, wrapped
		debug.setupvalue(aim.onupdate, ci, wrapped)
	end
	-- a quick tap (let go before the first charge): the game fires nothing (an
	-- empty click); tap = the charges a tap fires instead (with ammo left)
	s.tap_damage = math.max(0, math.min(1, tonumber(s.tap_damage) or 1))
	local tapped = Main.TapRelease(s)
	if tapped and s.tap > 0 and s.tap_refund == false then
		Main.SG_POST_LATE[#Main.SG_POST_LATE + 1] = { -- (after the other Cannon hooks)
			sg = "sg_player_cannon",
			name = "Big Blast tap refund",
			fn = function(sg)
				return Main.TapNoRefund(sg)
			end,
		}
	end
	-- shell = "game": the game's shots and damage (only the charge time and the tap changed)
	if s.shell ~= "game" then
		Main.SG_POST[#Main.SG_POST + 1] = {
			sg = "sg_player_cannon",
			name = "Big Blast",
			fn = function(sg)
				return Main.BigBlastShots(sg, s)
			end,
		}
	end
	return string.format("a charge every %d ticks (was %d), %s%s", Ticks(s), ticks,
		s.shell == "game" and "the game's shots and damage" or string.format("%s %s / Focus %s a charge",
			s.shell == "one" and "one big shell," or ("six shells, fan x" .. tostring(s.spread) .. ","), tostring(s.damage), tostring(s.focus_damage)),
		s.tap > 0 and (tapped and string.format(", a tap fires %d%s", s.tap,
			(s.tap_damage ~= 1 or s.tap_refund == false) and string.format(" (%d%% damage%s)", math.floor(s.tap_damage * 100 + 0.5),
				s.tap_refund == false and ", no ammo back" or "") or "") or ", (tap: aim states changed, a tap fires nothing)") or "")
end

-- Big Blast's release (the aim states' DoBigBlast, sg_player_cannon_skill_aim.lua):
-- fewer charges than tap (a quick tap) -> tap charges, as many as the ammo allows
Main.AIM_RELEASE_STATES = { "skill_cannon_aim_loop", "skill_cannon_aim_run_pre", "skill_cannon_aim_run_loop", "skill_cannon_aim_run_pst" }
function Main.TapRelease(s)
	local fn, idx, release
	for _, name in ipairs(Main.AIM_RELEASE_STATES) do
		local ok, st = pcall(Main.State, name)
		local f = ok and st ~= nil and st.onupdate or nil
		local v, i = Main.FindUpvalue(f, "DoBigBlast")
		if type(v) == "function" then
			fn, idx, release = f, i, v
			break
		end
	end
	if fn == nil then
		return false
	end
	if release == Main.skillbalance_tap_fn then
		return true -- already in (the settings are read on each release)
	end
	local SGPlayerCommon = require "stategraphs.sg_player_common"
	local orig = release
	-- returns true when this release is a tap (it now fires the tap's charges)
	local function Stock(inst)
		local mem = inst ~= nil and inst.sg ~= nil and inst.sg.mem or nil
		local b = Main.settings ~= nil and Main.settings.big_blast or nil
		local tap = type(b) == "table" and b.tap or 0
		if mem ~= nil and tap > 0 and (mem.charges_stocked or 0) < tap then
			local ammo_fn = SGPlayerCommon.Fns ~= nil and SGPlayerCommon.Fns.Cannon_GetRemainingAmmo or nil
			local ammo = ammo_fn ~= nil and ammo_fn(inst) or 0
			if ammo > 0 then
				mem.charges_stocked = math.min(tap, ammo)
				return true
			end
		end
		return false
	end
	Main.skillbalance_tap_fn = function(inst, ...)
		local ok, tapped = Main.G.Call("Big Blast tap", Stock, inst)
		local watch = nil
		if ok and tapped and inst.ListenForEvent ~= nil then
			-- the tap's shells (the game fires them right inside this release)
			watch = Main.TapShells()
			inst:ListenForEvent("projectile_launched", watch)
			Main.G.Call("Big Blast tap: no ammo back", Main.WatchTapRefund, inst)
		end
		local results = table.pack(pcall(orig, inst, ...))
		if watch ~= nil then
			inst:RemoveEventCallback("projectile_launched", watch)
		end
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
	debug.setupvalue(fn, idx, Main.skillbalance_tap_fn) -- shared by every aim state that lets go
	return true
end

-- The tap's shell. The game's Cannon reloads one shot for every skill shell
-- that hits ("skill_hit": each Big Blast shell that connects gives one back,
-- up to a full clip; piercing shells give none), so a one-shell tap that hit
-- was free. Now a tap shell does tap_damage of a Big Blast shell's damage
-- (0.5: 2 x your weapon damage, like a Mortar shell) and gives no ammo back
-- (tap_refund = false).
function Main.TapShells()
	return function(_, bullets)
		local b = Main.settings ~= nil and Main.settings.big_blast or nil
		local factor = type(b) == "table" and tonumber(b.tap_damage) or 1
		for _, bullet in ipairs(type(bullets) == "table" and bullets or {}) do
			if type(bullet) == "table" and not rawget(bullet, "skillbalance_tap") then
				rawset(bullet, "skillbalance_tap", true)
				local setup = bullet.Setup
				if type(setup) == "function" and factor ~= 1 then
					-- (the game sets the shell up a frame later: its damage then)
					bullet.Setup = function(self, owner, damage_mod, ...)
						if type(damage_mod) == "number" then
							damage_mod = damage_mod * factor
						end
						return setup(self, owner, damage_mod, ...)
					end
				end
			end
		end
	end
end

-- a tap shell's hit: the "skill_hit" the shell sends right after it doesn't reload
function Main.WatchTapRefund(inst)
	if rawget(inst, "skillbalance_tap_watch") then
		return
	end
	rawset(inst, "skillbalance_tap_watch", true)
	inst:ListenForEvent("do_damage", function(_, attack)
		local b = Main.settings ~= nil and Main.settings.big_blast or nil
		if type(b) ~= "table" or b.tap_refund ~= false or type(attack) ~= "table" or attack.GetProjectile == nil then
			return
		end
		local proj = attack:GetProjectile()
		if type(proj) == "table" and rawget(proj, "skillbalance_tap") then
			rawset(inst, "skillbalance_norefund_tick", Now())
		end
	end)
end

-- the Cannon's own "skill_hit" (reload one): skipped once for a tap shell's hit
function Main.TapNoRefund(sg)
	local list = type(sg) == "table" and type(sg.events) == "table" and sg.events.skill_hit or nil
	if type(list) ~= "table" or #list == 0 then
		error("the Cannon's skill hit reload not found", 0)
	end
	local n = 0
	for _, h in ipairs(list) do
		if type(h) == "table" and type(h.fn) == "function" and not h.skillbalance_norefund then
			h.skillbalance_norefund = true
			local fn = h.fn
			h.fn = function(inst, ...)
				local tick = type(inst) == "table" and rawget(inst, "skillbalance_norefund_tick") or nil
				if tick ~= nil then
					rawset(inst, "skillbalance_norefund_tick", nil)
					if tick == Now() then
						return -- the tap's shell: no ammo back
					end
				end
				return fn(inst, ...)
			end
			n = n + 1
		end
	end
	return string.format("Big Blast tap: its shell gives no ammo back (%d)", n)
end

-- 0.2.8: Throw Rock, Snap Attacks, Sharpened Reflexes, the reload Backfire (skillbalance/more.lua)
local More = require "skillbalance.more"
Main.More = More
function Changes.throw_rock(s)
	return More.ThrowRock(Main, s)
end
function Changes.snap_attacks(s)
	s.damage_mult = math.max(0, math.min(10, s.damage_mult))
	return More.SnapAttacks(Main, s)
end
function Changes.sharpened_reflexes(s)
	s.guard_window_seconds = math.max(0, math.min(600, s.guard_window_seconds))
	return More.SharpenedReflexes(Main, s)
end
function Changes.backfire(s)
	s.reach = math.max(0.5, math.min(5, s.reach))
	s.radius = math.max(0.5, math.min(5, s.radius))
	Main.SG_POST[#Main.SG_POST + 1] = {
		sg = "sg_player_cannon",
		name = "Backfire",
		fn = function(sg)
			return More.Backfire(Main, s, sg)
		end,
	}
	return string.format("damage %g / %g / %g (Focus %g / %g / %g), blast reach x%g, width x%g (set when the Cannon is built)",
		s.damage[1], s.damage[2], s.damage[3], s.focus_damage[1], s.focus_damage[2], s.focus_damage[3], s.reach, s.radius)
end

-- Gourdo's Community Garden (the miniboss skill: hold it, each pulse heals you
-- and allies near you and uses a stock; stocks come back with damage dealt).
-- Its numbers are the power's tuning (read each time: the tooltip shows the
-- new ones). The game counts damage to enemies and breakable props only, so
-- in town (no enemies) a used stock never came back: dummy = true counts the
-- training dummies too, like the bow quiver in Skill Limits.
local garden_orig = setmetatable({}, { __mode = "k" }) -- the game's damage counter, by power def (not in its trigger list: the game listens to every key there)
local garden_heal_orig = setmetatable({}, { __mode = "k" }) -- the game's heal pulse, by power def
local garden_newstate_orig = setmetatable({}, { __mode = "k" }) -- (the game has none; kept if it adds one)
function Changes.community_garden(s)
	local Power = require "defs.powers.power"
	local def = Power.FindPowerByName("miniboss_gourdo")
	local tuning = def ~= nil and def.tuning ~= nil and def.tuning.COMMON or nil
	if tuning == nil or tuning.heal == nil or tuning.damage_til_new_stock == nil or tuning.max_stocks == nil then
		error("the Garden's numbers not found", 0)
	end
	tuning.heal = s.heal
	tuning.damage_til_new_stock = math.max(1, s.damage_per_stock)
	tuning.max_stocks = math.max(1, math.floor(s.max_stocks))
	local dummies = ""
	local triggers = def.event_triggers
	local orig = triggers ~= nil and (garden_orig[def] or triggers.do_damage) or nil
	if s.dummy and type(orig) == "function" then
		garden_orig[def] = orig
		triggers.do_damage = function(pow, inst, data, ...)
			local ok, target = pcall(function() return data:GetTarget() end)
			if ok and target ~= nil and target:IsValid() and target:HasTag("dummy") and not target:HasTag("mob") then
				-- a training dummy hit counts like an enemy hit
				local as_enemy = setmetatable({
					HasTag = function(_, tag) return tag == "mob" or target:HasTag(tag) end,
					IsValid = function() return target:IsValid() end,
					GetPosition = function() return target:GetPosition() end,
				}, { __index = target })
				local hit = setmetatable({ GetTarget = function() return as_enemy end }, { __index = data })
				return orig(pow, inst, hit, ...)
			end
			return orig(pow, inst, data, ...)
		end
		dummies = ", training dummies count"
	elseif type(orig) == "function" and garden_orig[def] ~= nil then
		triggers.do_damage = orig
	end
	-- a full hold: max_stocks pulses in one hold heal full_heal in all, the last pulse
	-- heals the rest (30 + 30 + 40 = 100). The skill's states (sg_player_skill_miniboss_gourdo):
	-- a press enters skill_miniboss_gourdo, each pulse is one do_gourdo_skill_heal (the loop's
	-- frame 0; the wind-up's frame 18 never comes, its animations are 15 frames), holding
	-- the button loops back to the wind-up without a new press. So a press (newstate
	-- skill_miniboss_gourdo) starts the count, each heal counts one.
	local full = ""
	local heal_orig = triggers ~= nil and (garden_heal_orig[def] or triggers.do_gourdo_skill_heal) or nil
	local n = tuning.max_stocks
	local last = (s.full_heal or 0) - tuning.heal * (n - 1)
	if (s.full_heal or 0) > 0 and n > 1 and last > tuning.heal and type(heal_orig) == "function" then
		garden_heal_orig[def] = heal_orig
		garden_newstate_orig[def] = garden_newstate_orig[def] or triggers.newstate or false
		local newstate_orig = garden_newstate_orig[def]
		triggers.do_gourdo_skill_heal = function(pow, inst, data, ...)
			local pulses = (pow.mem.skillbalance_garden_pulses or 0) + 1
			pow.mem.skillbalance_garden_pulses = pulses
			if pulses ~= n then
				return heal_orig(pow, inst, data, ...)
			end
			local base = tuning.heal
			tuning.heal = last -- the game reads the heal from the tuning (persistdata:GetVar)
			local ok, err = pcall(heal_orig, pow, inst, data, ...)
			tuning.heal = base
			if not ok then
				error(err, 0)
			end
		end
		triggers.newstate = function(pow, inst, data, ...)
			if type(data) == "table" and data.statename == "skill_miniboss_gourdo" then
				pow.mem.skillbalance_garden_pulses = 0 -- a new press: a new hold
			end
			if newstate_orig then
				return newstate_orig(pow, inst, data, ...)
			end
		end
		full = string.format(", %d stocks in one hold heal %s (the last one %s)", n, tostring(s.full_heal), tostring(last))
	elseif garden_heal_orig[def] ~= nil then
		triggers.do_gourdo_skill_heal = garden_heal_orig[def]
		triggers.newstate = garden_newstate_orig[def] or nil
	end
	return string.format("heals %s, a stock per %s damage%s, %d stocks%s", tostring(s.heal), tostring(tuning.damage_til_new_stock),
		dummies, tuning.max_stocks, full)
end

-- Thatcher's Voice of the Myriad (the bow skill: for seconds_active your hits coat
-- enemies in Toxic). The game: 1 stock, 6 seconds, the stock back 0.1 s after it
-- wears off (its timerdone "_cooldown"), and a press while it's on gives the stock
-- back and starts it again (allow_retrigger: powerutil.StockPower_UseNoStocks): no
-- limit at all. Here its stock comes back from damage instead, like the Garden's:
-- damage_per_stock damage dealt once it has worn off (nothing counts while it's on)
-- to enemies and breakable props (the game's TargetIsEnemyOrDestructibleProp; dummy
-- = true: the training dummies too), up to max_stocks; no recast while it's on. Its
-- icon shows how far the recharge is ("45%"; blank when it's ready; the seconds left
-- while it's on, as the game shows them).
local myriad_orig = setmetatable({}, { __mode = "k" })
local function MyriadProgress(pow, inst)
	local pd = pow.persistdata
	local old = pd.counter
	if (pd.stocks_left or 0) >= pd:GetVar("max_stocks") then
		pd.counter = nil
	else
		pd.counter = string.format("%d%%", math.floor(100 * math.min(1, (pd.damage_dealt or 0) / pd:GetVar("damage_til_new_stock"))))
	end
	if pd.counter ~= old then
		inst:PushEvent("update_power", pow.def)
	end
end
function Changes.voice_of_the_myriad(s)
	local Power = require "defs.powers.power"
	local powerutil = require "util.powerutil"
	local def = Power.FindPowerByName("boss_thatcher")
	local tuning = def ~= nil and def.tuning ~= nil and def.tuning.COMMON or nil
	local triggers = def ~= nil and def.event_triggers or nil
	if tuning == nil or tuning.max_stocks == nil or tuning.seconds_active == nil or triggers == nil then
		error("the Myriad's numbers not found", 0)
	end
	local orig = myriad_orig[def] or { timerdone = triggers.timerdone, do_damage = triggers.do_damage }
	if type(orig.timerdone) ~= "function" or type(orig.do_damage) ~= "function" then
		error("the Myriad's timer / damage handling not found", 0)
	end
	myriad_orig[def] = orig
	tuning.max_stocks = math.max(1, math.floor(s.max_stocks))
	tuning.seconds_active = math.max(1, s.seconds)
	tuning.allow_retrigger = false
	tuning.damage_til_new_stock = math.max(1, s.damage_per_stock)
	local cooldown = def.name .. "_cooldown"
	triggers.timerdone = function(pow, inst, data, ...)
		if type(data) == "table" and data.name == cooldown then
			-- the game refills the stock here; now damage does
			return MyriadProgress(pow, inst)
		end
		return orig.timerdone(pow, inst, data, ...)
	end
	local dummies = s.dummy
	triggers.do_damage = function(pow, inst, attack, ...)
		orig.do_damage(pow, inst, attack, ...)
		if pow.mem.active or inst.components.timer:HasTimer(cooldown) then
			return -- it's on (or just ending): nothing counts
		end
		local pd = pow.persistdata
		if (pd.stocks_left or 0) >= pd:GetVar("max_stocks") then
			return
		end
		if not (powerutil.TargetIsEnemyOrDestructibleProp(attack) or (dummies and powerutil.TargetIsTrainingDummy(attack))) then
			return
		end
		pd.damage_dealt = (pd.damage_dealt or 0) + (attack:GetDamage() or 0)
		if pd.damage_dealt >= pd:GetVar("damage_til_new_stock") then
			pd.damage_dealt = 0
			powerutil.StockPower_Refill(pow, inst)
		end
		MyriadProgress(pow, inst)
	end
	return string.format("%s s on, a stock per %s damage dealt after it wears off%s, %d stock%s, no recast while it's on",
		tostring(tuning.seconds_active), tostring(tuning.damage_til_new_stock), dummies and ", training dummies count" or "",
		tuning.max_stocks, tuning.max_stocks == 1 and "" or "s")
end

-- Shellwalker's Eggsabre (the Sedament tundra Greatsword): with it sheathed
-- you run faster, by its power's stacks (a percent each) for the weapon's
-- level (stacks_per_usage_level; the game: 25 / 30 / 35). Two Weapons gives
-- every weapon 30% sheathed, so this one gets far more. The tooltip and the
-- running both read the new numbers. (A run saved before this keeps the old
-- bonus until town.)
function Changes.eggsabre_run(s)
	local Power = require "defs.powers.power"
	local def = Power.FindPowerByName("equipment_cleaver_sheathe_weapon")
	local levels = def ~= nil and def.stacks_per_usage_level or nil
	if type(levels) ~= "table" or type(levels[1]) ~= "number" then
		error("the Eggsabre's run bonus not found", 0)
	end
	local parts = {}
	for i = 1, #levels do
		local v = s.run_bonus[i] or s.run_bonus[#s.run_bonus]
		levels[i] = math.max(0, math.floor(v + 0.5))
		parts[i] = tostring(levels[i])
	end
	return "sheathed run speed +" .. table.concat(parts, " / ") .. "% by weapon level"
end

Main.ORDER = { "melee_skills", "parry", "order_in_the_court", "pole_vault", "dribble", "hazard_idol", "impulsive_stomp", "grody_groak_gulp",
	"mini_parry", "big_blast", "throw_rock", "snap_attacks", "sharpened_reflexes", "backfire", "community_garden", "voice_of_the_myriad", "eggsabre_run" }
Main.NAMES = {
	melee_skills = "melee skills", parry = "parry", order_in_the_court = "Order in the Court",
	pole_vault = "Pole Vault", dribble = "Dribble", hazard_idol = "Hazard Idol",
	impulsive_stomp = "Impulsive Stomp", grody_groak_gulp = "Grody Groak Gulp", mini_parry = "mini parry", big_blast = "Big Blast",
	throw_rock = "Throw Rock", snap_attacks = "Snap Attacks", sharpened_reflexes = "Sharpened Reflexes", backfire = "reload Backfire",
	community_garden = "Gourdo's Community Garden", voice_of_the_myriad = "Voice of the Myriad", eggsabre_run = "Shellwalker's Eggsabre",
}

-- Returns: number changed, info line parts, problems
function Main.Install(s)
	local on, parts, problems = 0, {}, {}
	for _, key in ipairs(Main.ORDER) do
		local section = s[key]
		if section then
			local ok, info = pcall(Changes[key], section)
			if ok then
				on = on + 1
				parts[#parts + 1] = Main.NAMES[key] .. ": " .. tostring(info)
			else
				problems[#problems + 1] = Main.NAMES[key] .. " skipped (" .. tostring(info) .. ")"
			end
		end
	end
	for _, post in ipairs(Main.SG_POST_LATE) do
		Main.SG_POST[#Main.SG_POST + 1] = post
	end
	Main.SG_POST_LATE = {}
	return on, parts, problems
end

----------------------------------------------------------------------------
-- Stall log: when the game stops for longer than stall_log.seconds (a
-- freeze), one line in the log with what the player did in the 3 seconds
-- before it: states entered, the changed skills' hits, mini parries. Nothing
-- is changed, it only watches (a check each frame).
local Stall = { KEEP = 3, MAX_NOTES = 40, MAX_LINES = 20 }
Main.Stall = Stall

local function RealTime()
	local fn = rawget(_G, "GetTimeRealSeconds")
	return fn ~= nil and fn() or nil
end

-- the pause menu stops the game too: not a freeze (SetPause is the game's
-- global the pause screens go through; noted when it last changed)
function Stall.WatchPause()
	if Stall.pause_watched then
		return
	end
	local orig = rawget(_G, "SetPause")
	if type(orig) ~= "function" then
		return
	end
	Stall.pause_watched = true
	rawset(_G, "SetPause", function(...)
		Stall.last_pause = RealTime()
		return orig(...)
	end)
end

function Stall.Note(inst, what)
	local st = inst ~= nil and inst.skillbalance_stall or nil
	local now = st ~= nil and RealTime() or nil
	if now == nil then
		return
	end
	local list = st.notes
	list[#list + 1] = { t = now, what = what }
	if #list > Stall.MAX_NOTES then
		table.remove(list, 1)
	end
end

-- The game's real-time clock moves in whole seconds, so time lost to a freeze
-- is measured by frames: in a normal second the game runs about SECONDS frames
-- (ticks); a freeze shows as the clock moving on with too few frames.
local function TicksPerSecond()
	local t = rawget(_G, "SECONDS")
	return type(t) == "number" and t > 0 and t or 60
end

function Stall.Check(inst, s)
	local st = inst.skillbalance_stall
	local now = RealTime()
	if st == nil or now == nil then
		return
	end
	st.frames = (st.frames or 0) + 1
	local world = rawget(_G, "TheWorld")
	if world ~= st.world then
		-- a new room: start over
		st.last, st.frames, st.world, st.mem = now, 0, world, collectgarbage("count")
		return
	end
	if now == st.last then
		return
	end
	local jump = now - st.last
	local lost = jump - st.frames / TicksPerSecond()
	local mem = collectgarbage("count")
	local paused = rawget(_G, "IsPaused") ~= nil and IsPaused() or false
	local menu = paused or (Stall.last_pause ~= nil and Stall.last_pause >= st.last - 1)
	if lost >= s.seconds and st.logged < Stall.MAX_LINES and not menu then
		st.logged = st.logged + 1
		local start = st.last
		local recent = {}
		for _, n in ipairs(st.notes) do
			if n.t >= start - Stall.KEEP then
				recent[#recent + 1] = string.format("%+d s %s", math.floor(n.t - start + 0.5), n.what)
			end
		end
		local screen = "?"
		local fe = rawget(_G, "TheFrontEnd")
		if fe ~= nil and fe.GetActiveScreen ~= nil then
			local ok, scr = pcall(fe.GetActiveScreen, fe)
			screen = ok and scr ~= nil and tostring(scr.name or scr._widgetname or scr) or "?"
		end
		Main.Log(string.format("the game stopped for about %.1f s (%d frames in %d s; screen %s, Lua memory %d -> %d KB); just before (seconds from the stop): %s",
			lost, st.frames, jump, screen, math.floor(st.mem), math.floor(mem), #recent > 0 and table.concat(recent, ", ") or "nothing noted"))
	end
	st.last, st.frames, st.mem = now, 0, mem
end

function Stall.Start(inst, s)
	if RealTime() == nil or inst.DoPeriodicTask == nil or inst.ListenForEvent == nil then
		return false
	end
	Stall.WatchPause()
	inst.skillbalance_stall = { notes = {}, last = RealTime(), frames = 0, mem = collectgarbage("count"), logged = 0,
		world = rawget(_G, "TheWorld") }
	inst:ListenForEvent("newstate", function(_, data)
		pcall(Stall.Note, inst, "state " .. tostring(type(data) == "table" and data.statename or "?"))
	end)
	inst:DoPeriodicTask(0, function()
		local ok, err = pcall(Stall.Check, inst, s)
		if not ok and inst.skillbalance_stall ~= nil and not inst.skillbalance_stall.failed then
			inst.skillbalance_stall.failed = true
			Main.Log("stall log error: " .. tostring(err))
		end
	end)
	return true
end

function Main.SetupPlayer(inst)
	if Main.settings ~= nil and Main.settings.stall_log then
		pcall(Stall.Start, inst, Main.settings.stall_log)
	end
	if Main.parry ~= nil and Main.parry.counter_damage > 0 then
		inst:ListenForEvent("parry", function(player, data)
			local ok, err = pcall(Main.ParryCounter, player, data)
			if not ok then
				Main.Log("parry counter error: " .. tostring(err))
			end
		end)
	end
end

return Main
