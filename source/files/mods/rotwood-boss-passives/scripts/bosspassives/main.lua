-- Boss Weapon Passives: one passive per boss, on its six weapons.
--
-- The game: every boss weapon has power_on_equip = "equipment_bossweapon_wip"
-- (defs/equipment/weapon/*.lua; the power does nothing). This adds an equipment
-- power per boss ("equipment_bossweapon_<boss>") built from the game's own
-- pieces, and points that boss's weapons at it. The game's loadout code then
-- adds / removes it with the weapon, like any weapon's passive.

local Power = require "defs.powers"
local Equipment = require "defs.equipment"
local powerutil = require "util.powerutil"

local Main = {}

Main.TAG = "[Boss Passives]"
Main.WIP = "equipment_bossweapon_wip"
Main.BOSSES = { "megatreemon", "owlitzer", "bandicoot", "thatcher", "sedament", "eggzy", "grimhollow" }

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

----------------------------------------------------------------------------
-- Bulletproofing: every function a passive gives the game (its event
-- triggers, on add / on remove, the damage mods) runs through Guard. An
-- error in one is logged (the first few, with where it happened) and that
-- one call does nothing, instead of the game's error screen ending the run.

local guard_errors = 0
local function Trace(err)
	return debug ~= nil and debug.traceback ~= nil and debug.traceback(tostring(err), 2) or tostring(err)
end
-- the message and the first few Lua lines it went through (not the C ones)
local function Short(trace)
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
function Main.GuardError(where, trace)
	guard_errors = guard_errors + 1
	if guard_errors <= 8 then
		Main.Log("error in " .. where .. " (skipped; the game carries on): " .. Short(trace))
	end
end
-- (power functions give back at most a value or two: no table a call)
local function GuardFn(where, fn)
	return function(...)
		local ok, a, b, c = xpcall(fn, Trace, ...)
		if not ok then
			Main.GuardError(where, a)
			return nil
		end
		return a, b, c
	end
end
Main.GuardFn = GuardFn
-- data: a power's definition table (before Power.AddEquipmentPower)
function Main.Guard(name, data)
	local count = 0
	for key, value in pairs(data) do
		if type(value) == "function" then
			data[key] = GuardFn(name .. " " .. key, value)
			count = count + 1
		elseif type(value) == "table" and (key == "event_triggers" or key == "remote_event_triggers") then
			for event, fn in pairs(value) do
				if type(fn) == "function" then
					value[event] = GuardFn(name .. " " .. event, fn)
					count = count + 1
				end
			end
		end
	end
	return data, count
end

----------------------------------------------------------------------------
-- Settings

Main.DEFAULTS = {
	enabled = true,
	guard = true,
	megatreemon = { on = true, heal_per_hit = 5, max_per_room = 50 },
	owlitzer = { on = true, crit_seconds = 4, gust = "medium", gust_damage = 1.0, gust_radius = 4.5, gust_look = "whirlwind", whirlwind_scale = 1.5 },
	bandicoot = { on = true, seconds = 3, damage = 1.0 },
	thatcher = { on = true, every_hits = 25, radius = 6 },
	sedament = { on = true, damage_per_kill = 0.05, max_stacks = 5 },
	eggzy = { on = true, cooldown = 3 },
	grimhollow = { on = true, front_reduction = 0.4, after_heavy_reduction = 0.25, after_heavy_seconds = 3 },
}

local function Merge(defaults, user)
	local out = {}
	for k, v in pairs(defaults) do
		local u = nil
		if type(user) == "table" then
			u = user[k]
		end
		if type(v) == "table" then
			out[k] = Merge(v, u)
		elseif u ~= nil and type(u) == type(v) then
			out[k] = u
		else
			out[k] = v
		end
	end
	return out
end

function Main.LoadSettings(user)
	local s = Merge(Main.DEFAULTS, user)
	local function Num(t, k, lo, hi)
		t[k] = math.max(lo, math.min(hi, t[k]))
	end
	Num(s.megatreemon, "heal_per_hit", 0, 1000); Num(s.megatreemon, "max_per_room", 0, 100000)
	Num(s.owlitzer, "crit_seconds", 0, 60); Num(s.owlitzer, "gust_damage", 0, 20); Num(s.owlitzer, "gust_radius", 0, 30)
	Num(s.owlitzer, "whirlwind_scale", 0.25, 4)
	if s.owlitzer.gust_look ~= "whirlwind" then
		s.owlitzer.gust_look = ""
	end
	if s.owlitzer.gust ~= "weak" and s.owlitzer.gust ~= "medium" and s.owlitzer.gust ~= "strong" then
		s.owlitzer.gust = s.owlitzer.gust == "" and "" or "medium"
	end
	Num(s.bandicoot, "seconds", 0, 60); Num(s.bandicoot, "damage", 0, 10)
	s.thatcher.every_hits = math.max(1, math.floor(s.thatcher.every_hits)); Num(s.thatcher, "radius", 0, 50)
	Num(s.sedament, "damage_per_kill", 0, 10); s.sedament.max_stacks = math.max(0, math.floor(s.sedament.max_stacks))
	Num(s.eggzy, "cooldown", 0, 600)
	Num(s.grimhollow, "front_reduction", 0, 0.95); Num(s.grimhollow, "after_heavy_reduction", 0, 0.95)
	Num(s.grimhollow, "after_heavy_seconds", 0, 60)
	Main.settings = s
	return s
end

----------------------------------------------------------------------------
-- Strings (the weapon's passive in its tooltip)

local function Pct(x)
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end
local function Sec(x)
	if x == math.floor(x) then
		return string.format("%d second%s", x, x == 1 and "" or "s")
	end
	return string.format("%.1f seconds", x)
end

function Main.Strings(s)
	return {
		megatreemon = { name = "Rootbound Mending",
			desc = string.format("Hitting a <#RED>knocked-down</> enemy <#RED>Heals</> you for <#RED>%d Health</>, up to <#RED>%d</> each room.",
				s.megatreemon.heal_per_hit, s.megatreemon.max_per_room) },
		owlitzer = { name = "Tailwind Talons",
			desc = string.format("A <#RED>perfect dodge</> lets loose a gust of wind%s, and your next attack within <#RED>%s</> is a <#RED>Critical Hit</>.",
				s.owlitzer.gust_damage > 0 and s.owlitzer.gust_radius > 0
					and (" that deals <#RED>" .. Pct(s.owlitzer.gust_damage) .. " of your weapon's Damage</> to enemies around you") or "",
				Sec(s.owlitzer.crit_seconds)) },
		bandicoot = { name = "Double Dealing",
			desc = string.format("A successful <#RED>Parry</> or <#RED>perfect dodge</>: for <#RED>%s</>, every hit you land strikes again%s.",
				Sec(s.bandicoot.seconds), s.bandicoot.damage == 1 and "" or (" for " .. Pct(s.bandicoot.damage) .. " of its damage")) },
		thatcher = { name = "Swarm Burst",
			desc = string.format("Every <#RED>%d hits</> in a hit streak, a swarm bursts out and coats nearby enemies in <#RED>Acid</>.",
				s.thatcher.every_hits) },
		sedament = { name = "Gathering Frost",
			desc = string.format("Each kill gives <#RED>+%s Damage</> for the rest of the room, up to <#RED>%d</> times.",
				Pct(s.sedament.damage_per_kill), s.sedament.max_stacks) },
		eggzy = { name = "Volatile Shell",
			desc = string.format("A <#RED>Critical Hit</> that kills makes the enemy <#RED>explode</> (once every %s).", Sec(s.eggzy.cooldown)) },
		grimhollow = { name = "Bastion Bark",
			desc = string.format("During your <#RED>Heavy Attacks</>, take <#RED>%s less damage</> from the front. A <#RED>Heavy Attack</> that lands: take <#RED>%s less damage</> for <#RED>%s</>.",
				Pct(s.grimhollow.front_reduction), Pct(s.grimhollow.after_heavy_reduction), Sec(s.grimhollow.after_heavy_seconds)) },
	}
end

----------------------------------------------------------------------------
-- Shared pieces

local function Timer(inst)
	return inst.components ~= nil and inst.components.timer or nil
end

local function StartTimer(inst, name, seconds)
	local t = Timer(inst)
	if t == nil then
		return
	end
	if t:HasTimer(name) then
		t:StopTimer(name)
	end
	t:StartTimer(name, seconds)
end

local function OnCooldown(inst, name)
	local t = Timer(inst)
	return t ~= nil and t:HasTimer(name)
end

-- a hit of yours on someone else (not a power's extra hit)
local function OwnHit(inst, attack)
	if attack == nil or attack.GetTarget == nil then
		return nil
	end
	local target = attack:GetTarget()
	if target == nil or target == inst or (target.IsValid ~= nil and not target:IsValid()) then
		return nil
	end
	if attack.IsDirectPlayerAttack ~= nil and not attack:IsDirectPlayerAttack() then
		return nil
	end
	return target
end

-- the attacker behind a hitbox you dodged (projectiles: their owner)
local function DodgedAttacker(data)
	local hb = data ~= nil and data.inst or nil
	if hb == nil or (hb.IsValid ~= nil and not hb:IsValid()) then
		return nil
	end
	if hb.HasTag ~= nil and hb:HasTag("projectile") then
		return hb.owner
	end
	return hb
end

-- A perfect dodge (the game's: an attack's hitbox touched you while you were
-- invincible in a dodge), once per dodge. fn(pow, inst)
local function PerfectDodge(fn)
	return {
		dodge = function(pow, inst)
			pow.mem.dodged = false
		end,
		hitboxcollided_invincible = function(pow, inst, data)
			if pow.mem.dodged or inst.sg == nil or not inst.sg:HasStateTag("dodge") then
				return
			end
			if DodgedAttacker(data) == nil then
				return
			end
			pow.mem.dodged = true
			fn(pow, inst)
		end,
	}
end

local function Fx(fn, ...)
	local ok = pcall(fn, ...)
	return ok
end

----------------------------------------------------------------------------
-- The passives: power data (event triggers etc.) from the settings

local Passives = {}

-- Mother Treek: hits on knocked-down enemies heal. The heal skips your heal
-- powers' bonuses (a flat "+X to every heal" turned 1 into 25 a hit), so it
-- heals what the description says.
local treek_logged = 0
local function TreekHeal(pow, inst, amount)
	local heal = Attack(inst, inst)
	heal:SetHeal(amount)
	heal:SetSource(pow.def.name)
	heal:SetID(pow.def.name)
	if heal.SetSkipPowerHealModifiers ~= nil then
		heal:SetSkipPowerHealModifiers(true)
	end
	local healed = inst.components.combat:ApplyHeal(heal)
	if treek_logged < 10 then
		treek_logged = treek_logged + 1
		Main.Log(string.format("Mother Treek: heal %d (applied %s)", amount, tostring(healed)))
	end
end
function Passives.megatreemon(s)
	return {
		on_add_fn = function(pow) pow.mem.healed = 0 end,
		event_triggers = {
			enter_room = function(pow) pow.mem.healed = 0 end,
			do_damage = function(pow, inst, attack)
				local target = OwnHit(inst, attack)
				if target == nil or target.sg == nil or not target.sg:HasStateTag("knockdown") then
					return
				end
				local healed = pow.mem.healed or 0
				local amount = math.min(s.heal_per_hit, s.max_per_room - healed)
				if amount <= 0 then
					return
				end
				pow.mem.healed = healed + amount
				TreekHeal(pow, inst, amount)
				inst:PushEvent("used_power", pow.def)
			end,
		},
	}
end

-- Owlitzer: a perfect dodge: a gust, and the next attack crits
local GUST_PFX = "windmon_armor_helm_gust"
-- the whirlwind on top (gust_look = "whirlwind"): the Windmon's wind spin the
-- game puts round the player for the Greatsword's flourish and Berserk's end.
-- Attached to you (ischild, as the game does for Zucco's spin), so it goes
-- where you go; the Greatsword's stands still because you do.
local WHIRLWIND_FX = "fx_windmon_wind_spin"
local function Gust(inst, s)
	local EffectEvents = require "effectevents"
	if s.gust_look == "whirlwind" then
		Fx(EffectEvents.MakeEventSpawnEffect, inst, { fxname = WHIRLWIND_FX, offy = 1, ischild = true,
			scalex = s.whirlwind_scale, scalez = s.whirlwind_scale })
	end
	local strength = s.gust
	if strength == "" then
		return
	end
	local ParticleSystemHelper = require "util.particlesystemhelper"
	for _, side in ipairs({ "left", "right" }) do
		Fx(EffectEvents.MakeEventSpawnLocalEntity, inst, ("player_wind_gust_dummy_%s_%s"):format(strength, side), "idle")
		local pos = inst:GetPosition()
		pos.x = pos.x + (side == "left" and -1 or 1)
		Fx(ParticleSystemHelper.MakeOneShotAtPosition, pos, GUST_PFX, 2, inst, { use_entity_facing = true })
	end
end
-- The crit's state lives on the player, not in the power's memory: the
-- crit is taken off whichever copy of the power is there (a copy made again
-- since, e.g. after a loadout change, doesn't know about the old one's crit).
local OWL = "bosspassives_owlitzer"
local owl_logged = 0
local function OwlLog(msg)
	if owl_logged < 40 then
		owl_logged = owl_logged + 1
		Main.Log("Owlitzer: " .. msg)
	end
end
-- the hit that uses up the crit: one of your own attacks on someone else
-- (light, heavy, skill, and their projectiles); not a power's hit, not the
-- gust's own hits
local function SpendsCrit(inst, attack, name)
	if attack == nil or attack.GetTarget == nil then
		return false
	end
	local target = attack:GetTarget()
	if target == nil or target == inst then
		return false
	end
	if attack.GetAttacker ~= nil and attack:GetAttacker() ~= inst then
		return false
	end
	if attack.GetID ~= nil and attack:GetID() == name then
		return false
	end
	-- only your own light / heavy attack or skill uses it up (your shots too:
	-- they carry the attack's id); a power's hit that crits in the meantime is a
	-- free crit, the window stays open for your swing
	return attack.IsDirectPlayerAttack ~= nil and attack:IsDirectPlayerAttack() == true
end
-- the gust's hits: the weapon's damage times gust_damage on every enemy around
local function GustHits(pow, inst, s)
	if s.gust_damage <= 0 or s.gust_radius <= 0 or inst.components.combat == nil then
		return 0
	end
	local base = inst.components.combat.GetBaseDamage ~= nil and inst.components.combat:GetBaseDamage() or 0
	local amount = math.max(1, math.ceil(base * s.gust_damage))
	local x, z = inst.Transform:GetWorldXZ()
	local n = 0
	for _, ent in ipairs(FindEnemiesInRange(x, z, s.gust_radius) or {}) do
		if ent ~= inst and ent:IsValid() then
			local hit = Attack(inst, ent)
			hit:SetDamage(amount)
			hit:SetSource(pow.def.name)
			hit:SetID(pow.def.name)
			hit:SetPushback(1.5)
			hit:SetHitstunAnimFrames(6)
			if hit.SetForceCriticalHit ~= nil and Attack.ForceCrit ~= nil then
				hit:SetForceCriticalHit(Attack.ForceCrit.id.NEVER) -- the crit is for your next attack
			end
			n = n + 1
			inst:DoTaskInAnimFrames(2, GuardFn("owlitzer gust hit", function()
				if ent:IsValid() and inst:IsValid() then
					inst.components.combat:DoPowerAttack(hit)
				end
			end))
		end
	end
	return n
end
-- The purple glow on the hands (components/playerstatsfxer) shows your total
-- crit chance. When it goes down the game fades it over a quarter second; the
-- fade's last step overshoots (a particle rate below zero), which may be what
-- left the glow on after the crit ended. So when the crit ends: the glow set
-- straight to the crit chance left and the fade stopped. The network value
-- stays set so other players' screens get the drop too.
local function CritPct(inst)
	local combat = inst.components.combat
	local c = combat ~= nil and combat.GetTotalCritChance ~= nil and tonumber(combat:GetTotalCritChance()) or nil
	return c ~= nil and math.floor(c * 100 + 0.5) or nil
end
function Main.SnapCritGlow(inst)
	local fxer = inst.components ~= nil and inst.components.playerstatsfxer or nil
	local combat = inst.components ~= nil and inst.components.combat or nil
	if fxer == nil or combat == nil or combat.GetTotalCritChance == nil or fxer.UpdateTargetCritParameters == nil then
		return false
	end
	local now = combat:GetTotalCritChance()
	fxer:UpdateTargetCritParameters({ new = now, old = now })
	fxer.updating_critchance = false
	fxer.fading_critchance_time = nil
	local colour = fxer.critchance_color_target
	local emit = math.max(0, tonumber(fxer.critchance_emitmult_target) or 0)
	local scale = math.max(0, tonumber(fxer.critchance_scalemult_target) or 0)
	if colour ~= nil then
		fxer.critchance_color_current = colour
		if inst.AnimState ~= nil and (inst.IsLocalOrMinimal == nil or inst:IsLocalOrMinimal()) then
			inst.AnimState:SetSymbolBloom("base_hand", colour:unpack())
		end
	end
	fxer.critchance_scalemult_current = scale
	local emitter = fxer.crithands_emitter1
	if emitter ~= nil then
		emitter:SetEmitRateMult(emit)
		emitter:SetScaleMult(scale)
	end
	local particles = fxer.crithandsparticles ~= nil and fxer.crithandsparticles.components ~= nil
		and fxer.crithandsparticles.components.particlesystem or nil
	if emit <= 0 and particles ~= nil then
		particles:Stop()
	end
	-- as the game leaves it after a fade (so the next drop always fades)
	fxer.critchance_color_target = nil
	fxer.critchance_emitmult_current = nil
	return true
end

function Passives.owlitzer(s)
	local function EndCrit(pow, inst, why)
		local st = inst[OWL]
		local was = st ~= nil and st.on
		if st ~= nil then
			st.on = false
			if st.task ~= nil then
				st.task:Cancel()
				st.task = nil
			end
		end
		-- always (nothing happens when it isn't there)
		if inst.components.combat ~= nil then
			inst.components.combat:RemoveCritChanceModifier(pow.def.name)
		end
		if was then
			pcall(Main.SnapCritGlow, inst)
		end
		if was and why ~= nil then
			local left = CritPct(inst)
			OwlLog("crit " .. why .. (left ~= nil and string.format("; crit chance back to %d%%%s", left,
				left > 3 and " (from your gear/powers: the hands keep a faint glow for it)" or "") or ""))
		end
	end
	local triggers = PerfectDodge(function(pow, inst)
		Gust(inst, s)
		local hit = GustHits(pow, inst, s)
		if s.crit_seconds > 0 and inst.components.combat ~= nil then
			local st = inst[OWL] or {}
			inst[OWL] = st
			if st.task ~= nil then
				st.task:Cancel()
			end
			-- the way out first, so nothing below can leave the crit on for good
			st.on = true
			st.task = inst:DoTaskInTime(s.crit_seconds, GuardFn("owlitzer crit timer", function()
				st.task = nil
				EndCrit(pow, inst, "ran out (no hit in " .. s.crit_seconds .. " s)")
			end))
			inst.components.combat:SetCritChanceModifier(pow.def.name, 1)
		end
		OwlLog(string.format("perfect dodge: gust hit %d, next attack within %s s crits", hit, tostring(s.crit_seconds)))
		inst:PushEvent("used_power", pow.def)
	end)
	triggers.do_damage = function(pow, inst, attack)
		local st = inst[OWL]
		if st == nil or not st.on then
			return
		end
		local id = tostring(attack ~= nil and attack.GetID ~= nil and attack:GetID() or "?")
		if SpendsCrit(inst, attack, pow.def.name) then
			local crit = attack.GetCrit ~= nil and attack:GetCrit() and "a critical hit" or "not a critical hit"
			local dmg = attack.GetDamage ~= nil and tonumber(attack:GetDamage()) or nil
			EndCrit(pow, inst, string.format("spent by %s (%s%s)", id, crit, dmg ~= nil and string.format(", %d damage", math.floor(dmg + 0.5)) or ""))
		elseif id ~= pow.def.name then
			OwlLog("a hit that doesn't use the crit up: " .. id)
		end
	end
	return {
		prefabs = {
			"player_wind_gust_dummy_weak_left", "player_wind_gust_dummy_weak_right",
			"player_wind_gust_dummy_medium_left", "player_wind_gust_dummy_medium_right",
			"player_wind_gust_dummy_strong_left", "player_wind_gust_dummy_strong_right",
			WHIRLWIND_FX,
		},
		-- a crit left over from before (none should be): gone
		on_add_fn = function(pow, inst)
			if inst[OWL] == nil or not inst[OWL].on then
				EndCrit(pow, inst)
			end
		end,
		on_remove_fn = function(pow, inst) EndCrit(pow, inst, "ended (weapon off)") end,
		event_triggers = triggers,
	}
end

-- Bandicoot: Parry / perfect dodge: every hit strikes again for a while
function Passives.bandicoot(s)
	local function Open(pow, inst)
		if s.seconds <= 0 then
			return
		end
		pow.mem.active = true
		StartTimer(inst, pow.def.name, s.seconds)
		inst:PushEvent("used_power", pow.def)
	end
	local triggers = PerfectDodge(Open)
	triggers.parry = function(pow, inst) Open(pow, inst) end
	triggers.timerdone = function(pow, inst, data)
		if data ~= nil and data.name == pow.def.name then
			pow.mem.active = false
		end
	end
	-- the game's Multistrike (speed_to_multistrike): a copy of the hit, a moment later
	triggers.do_damage = function(pow, inst, attack)
		if not pow.mem.active or s.damage <= 0 then
			return
		end
		local victim = OwnHit(inst, attack)
		if victim == nil or (attack.CheckChain ~= nil and attack:CheckChain(pow.def.name) ~= nil) then
			return
		end
		local extra = Attack(inst, victim)
		extra:CloneChainDataFromAttack(attack)
		extra:SetSource(pow.def.name)
		extra:SetDamage(attack:GetDamage() * s.damage)
		extra:SetID(pow.def.name)
		extra:SetPushback(0)
		extra:SetHitstunAnimFrames(0)
		extra:SetSkipPowerDamageModifiers(true)
		extra:SetSkipPowerDefendModifiers(true)
		inst:DoTaskInAnimFrames(3, GuardFn("bandicoot extra hit", function()
			if victim:IsValid() then
				inst.components.combat:DoPowerAttack(extra)
			end
		end))
	end
	return {
		on_remove_fn = function(pow) pow.mem.active = false end,
		event_triggers = triggers,
	}
end

-- Thatcher: every N hits in a streak, acid on everyone near
local ACID = "player_acid"
local ACID_PFX = "acid_splatter_thatcher"
function Passives.thatcher(s)
	local function Burst(pow, inst)
		local x, z = inst.Transform:GetWorldXZ()
		local n = 0
		for _, ent in ipairs(FindEnemiesInRange(x, z, s.radius) or {}) do
			if ent ~= inst and ent:IsValid() then
				powerutil.AddPowerToTarget(pow, inst, ent, ACID)
				n = n + 1
			end
		end
		local ParticleSystemHelper = require "util.particlesystemhelper"
		Fx(ParticleSystemHelper.MakeOneShotAtPosition, inst:GetPosition(), ACID_PFX, 2, inst)
		inst:PushEvent("used_power", pow.def)
		return n
	end
	Main.ThatcherBurst = Burst -- (tests)
	return {
		prefabs = { ACID_PFX },
		event_triggers = {
			hitstreak = function(pow, inst, data)
				local h = data ~= nil and tonumber(data.hitstreak) or 0
				local last = pow.mem.last or 0
				if h < last then
					last = 0 -- a new streak
				end
				if h > 0 and math.floor(h / s.every_hits) > math.floor(last / s.every_hits) then
					Burst(pow, inst)
				end
				pow.mem.last = h
			end,
			hitstreak_killed = function(pow) pow.mem.last = 0 end,
		},
	}
end

-- Sedament: each kill: more damage for the room
function Passives.sedament(s)
	local function Apply(pow, inst)
		local n = pow.mem.stacks or 0
		if n > 0 then
			inst.components.combat:SetDamageDealtMult(pow.def.name, 1 + s.damage_per_kill * n)
		else
			inst.components.combat:RemoveDamageDealtMult(pow.def.name)
		end
	end
	return {
		on_add_fn = function(pow, inst) pow.mem.stacks = 0; Apply(pow, inst) end,
		on_remove_fn = function(pow, inst) pow.mem.stacks = 0; Apply(pow, inst) end,
		event_triggers = {
			kill = function(pow, inst, data)
				if data == nil or data.attack == nil or not powerutil.TargetIsEnemy(data.attack) then
					return
				end
				if (pow.mem.stacks or 0) >= s.max_stacks then
					return
				end
				pow.mem.stacks = (pow.mem.stacks or 0) + 1
				Apply(pow, inst)
				inst:PushEvent("used_power", pow.def)
			end,
			enter_room = function(pow, inst) pow.mem.stacks = 0; Apply(pow, inst) end,
		},
	}
end

-- Eggzy: critical kills explode (the game's No Contest bomb)
local BOMB = "trap_bomb_pinecone_friendly"
function Passives.eggzy(s)
	return {
		prefabs = { BOMB },
		event_triggers = {
			kill = function(pow, inst, data)
				local attack = data ~= nil and data.attack or nil
				if attack == nil or not powerutil.TargetIsEnemy(attack) or not attack:GetCrit() then
					return
				end
				if OnCooldown(inst, pow.def.name) then
					return
				end
				if s.cooldown > 0 then
					StartTimer(inst, pow.def.name, s.cooldown)
				end
				local target = attack:GetTarget()
				local EffectEvents = require "effectevents"
				if target ~= nil and target:IsValid() then
					EffectEvents.MakeEventSpawnLocalEntity(target, BOMB, "explode")
				else
					EffectEvents.MakeEventSpawnLocalEntity(inst, BOMB, "explode")
				end
				inst:PushEvent("used_power", pow.def)
			end,
		},
	}
end

-- Grimhollow: Bastion Bark. During your heavy attacks you take less damage
-- from the front (the Bastion Volley's own front check); a heavy attack that
-- lands: less damage from every side for a few seconds. Both at once multiply
-- (40% and 25%: 55% less).
local function FromFront(attacker, target)
	-- the Bastion Volley's test (defs/powers/skillpowers.lua, boss_grimhollow)
	local ok, front = pcall(function()
		local dirtotarget = attacker:GetAngleTo(target)
		local facing = target.Transform:GetFacing() == FACING_LEFT and 180 or 0
		local diff = DiffAngle(facing, dirtotarget)
		return diff > 70 or (diff > 50 and facing == attacker.Transform:GetFacingRotation())
	end)
	return ok and front == true
end
Main.FromFront = FromFront -- (tests)

function Passives.grimhollow(s)
	-- the Bastion Volley's "hit reduced" sound, if it's there
	local sound
	pcall(function()
		local soundutil = require "util.soundutil"
		local fmodtable = require "defs.sound.fmodtable"
		local ev = fmodtable.Event.GrimhollowWeapon_Hit_Reduced
		if ev ~= nil and soundutil.PlayCodeSound ~= nil then
			sound = function(inst) soundutil.PlayCodeSound(inst, ev, { max_count = 1 }) end
		end
	end)
	return {
		defend_mod_fn = function(pow, attack, damage_modifier)
			local target = attack.GetTarget ~= nil and attack:GetTarget() or nil
			if target == nil then
				return false
			end
			local used = false
			local attacker = attack.GetAttacker ~= nil and attack:GetAttacker() or nil
			if s.front_reduction > 0 and target.sg ~= nil and target.sg:HasStateTag("heavy_attack")
				and attacker ~= nil and attacker ~= target and attacker.IsValid ~= nil and attacker:IsValid()
				and FromFront(attacker, target) then
				damage_modifier:ApplyDamageDecreaseMult(pow.def.name .. "_front", s.front_reduction)
				if sound ~= nil then
					pcall(sound, target)
				end
				used = true
			end
			-- (its own key: the game keeps one decrease per key)
			if s.after_heavy_reduction > 0 and OnCooldown(target, pow.def.name .. "_guard") then
				damage_modifier:ApplyDamageDecreaseMult(pow.def.name .. "_guard", s.after_heavy_reduction)
				used = true
			end
			return used
		end,
		event_triggers = {
			do_damage = function(pow, inst, attack)
				if s.after_heavy_seconds <= 0 or s.after_heavy_reduction <= 0 or attack == nil
					or attack.IsHeavyAttack == nil or not attack:IsHeavyAttack() then
					return
				end
				if OwnHit(inst, attack) == nil then
					return
				end
				StartTimer(inst, pow.def.name .. "_guard", s.after_heavy_seconds)
			end,
		},
	}
end

Main.Passives = Passives

----------------------------------------------------------------------------

function Main.PowerName(boss)
	return "equipment_bossweapon_" .. boss
end

-- The boss of a boss weapon def ("hammer_megatreemon" -> "megatreemon")
function Main.BossOf(def)
	local name = def ~= nil and def.name or nil
	if type(name) ~= "string" then
		return nil
	end
	for _, boss in ipairs(Main.BOSSES) do
		if name:sub(-#boss - 1) == "_" .. boss then
			return boss
		end
	end
	return nil
end

-- Power.FindPowerByName raises an error for a name that doesn't exist (it
-- never returns nil), so look powers up safely.
function Main.HasPower(name)
	local ok, def = pcall(Power.FindPowerByName, name)
	return ok and def ~= nil
end

-- The game translates STRINGS again right after the mods load (and on every
-- language change): GameContent:SetLanguage -> LOC.TranslateStringTable looks
-- every string up in the content database by its path, and one that isn't
-- there becomes "MISSING:STRINGS.ITEMS...." (questral/contentdb.lua). So the
-- passives' strings go into that database too. entries: { [path] = string }
function Main.RegisterStrings(entries)
	local gc = rawget(_G, "TheGameContent")
	local db = gc ~= nil and gc.GetContentDB ~= nil and gc:GetContentDB() or nil
	if db == nil or type(db.strings) ~= "table" then
		return false
	end
	for id, str in pairs(entries) do
		db.strings[id] = str -- (not AddString: it asserts on a second load)
	end
	return true
end

-- The powers are always made (an empty one for a boss that's off, or with
-- the mod switched off): a character saved with one of them equipped still
-- loads. retarget = false: the weapons keep the game's placeholder.
function Main.Install(s, retarget)
	assert(type(Power.AddEquipmentPower) == "function", "Power.AddEquipmentPower")
	assert(type(powerutil.DoPowerHeal) == "function" and type(powerutil.AddPowerToTarget) == "function"
		and type(powerutil.TargetIsEnemy) == "function", "powerutil")
	assert(Main.HasPower(Main.WIP), Main.WIP)
	local weapons = Equipment.Items.WEAPON
	assert(type(weapons) == "table", "Equipment.Items.WEAPON")

	-- the powers (strings first: the game reads them when the power is made)
	local strings = Main.Strings(s)
	local eq = STRINGS.ITEMS.POWERS.EQUIPMENT
	local made, entries = {}, {}
	local guarded = 0
	for _, boss in ipairs(Main.BOSSES) do
		local on = retarget ~= false and s[boss].on
		local name = Main.PowerName(boss)
		if not Main.HasPower(name) then
			eq[name] = { name = strings[boss].name, desc = on and strings[boss].desc or "", variables = {} }
			local path = "STRINGS.ITEMS.POWERS.EQUIPMENT." .. name
			entries[path .. ".name"], entries[path .. ".desc"] = eq[name].name, eq[name].desc
			local data = on and Passives[boss](s[boss]) or {}
			if s.guard ~= false then
				local _, n = Main.Guard(boss, data)
				guarded = guarded + n
			end
			data.power_category = Power.Categories.SUPPORT
			data.tags = data.tags or {}
			data.stacks_per_usage_level = { 1, 1, 1 }
			data.tuning = { [Power.Rarity.COMMON] = {} }
			Power.AddEquipmentPower("bossweapon_" .. boss, data)
		end
		if on then
			made[boss] = name
		end
	end
	if next(entries) ~= nil and not Main.RegisterStrings(entries) then
		Main.Log("couldn't add the passives' names to the game's string list: they may show as MISSING")
	end
	if retarget == false then
		return "powers kept for saved characters, weapons unchanged"
	end

	-- point the boss weapons at them (each weapon def has its own usage_data)
	local count, per = 0, {}
	for _, def in pairs(weapons) do
		local usage = type(def) == "table" and def.usage_data or nil
		if usage ~= nil and usage.power_on_equip == Main.WIP then
			local boss = Main.BossOf(def)
			if boss ~= nil and made[boss] ~= nil then
				usage.power_on_equip = made[boss]
				count = count + 1
				per[boss] = (per[boss] or 0) + 1
			end
		end
	end
	local parts = {}
	for _, boss in ipairs(Main.BOSSES) do
		if per[boss] then
			parts[#parts + 1] = boss .. " " .. per[boss]
		end
	end
	return string.format("%d boss weapons: %s%s", count, table.concat(parts, ", "),
		s.guard ~= false and string.format("; %d passive functions guarded", guarded) or "; guard off")
end

return Main
