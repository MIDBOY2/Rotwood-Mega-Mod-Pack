-- Skill Balance, 0.2.8: Throw Rock, the Greatsword's Snap Attacks and
-- Sharpened Reflexes, the Cannon's reload Backfire.
local More = {}

----------------------------------------------------------------------------
-- Throw Rock: the stone's hit has a fixed damage (the game: 9, Critical Hits
-- scale from it). Set on its way into Combat (its hit code is the
-- projectile's own local function).

More.rock = nil -- the damage while on
local rock_hooked = false
function More.ThrowRock(Main, s)
	local Combat = require "components.combat"
	if type(Combat) ~= "table" or type(Combat.DoBasicAttack) ~= "function" then
		error("Combat:DoBasicAttack not found", 0)
	end
	More.rock = math.max(1, s.damage)
	if not rock_hooked then
		rock_hooked = true
		local function Rock(attack)
			if More.rock ~= nil and attack:GetID() == "throwstone" and rawget(attack, "_override_damage") ~= nil then
				attack:SetOverrideDamage(More.rock)
			end
		end
		local orig = Combat.DoBasicAttack
		Combat.DoBasicAttack = function(self, attack, ...)
			if attack ~= nil and attack.GetID ~= nil then
				Main.G.Call("Throw Rock damage", Rock, attack)
			end
			return orig(self, attack, ...)
		end
	end
	return string.format("damage %s a hit (the game: 9)", tostring(More.rock))
end

----------------------------------------------------------------------------
-- The Greatsword's Snap Attacks (Snap Tap, Snap Back): their damage
-- (times your weapon damage) from the Greatsword's table.

More.SNAPS = { "SNAP_TAP", "SNAP_BACK_LEVEL1", "SNAP_BACK_LEVEL2" }
function More.SnapAttacks(Main, s)
	local SGPlayerCleaver = require "stategraphs.sg_player_cleaver_common"
	local mods = SGPlayerCleaver ~= nil and SGPlayerCleaver.Consts ~= nil and SGPlayerCleaver.Consts.ATTACK_DAMAGE_MOD or nil
	if type(mods) ~= "table" then
		error("the Greatsword's damage table not found", 0)
	end
	local was = rawget(mods, "skillbalance_snap_was") or {}
	rawset(mods, "skillbalance_snap_was", was)
	local parts = {}
	for _, key in ipairs(More.SNAPS) do
		if type(mods[key]) ~= "number" and was[key] == nil then
			error("Greatsword " .. key .. " not found", 0)
		end
		was[key] = was[key] or mods[key]
		mods[key] = was[key] * s.damage_mult
		parts[#parts + 1] = string.format("%s %g", key == "SNAP_TAP" and "Snap Tap" or ("Snap Back " .. key:sub(-1)), mods[key])
	end
	return string.format("x%g (%s)", s.damage_mult, table.concat(parts, ", "))
end

----------------------------------------------------------------------------
-- Sharpened Reflexes (the Greatsword's skill). The game: it uses up your
-- meter for a bonus on your next Snap Attack (a delayed explosion hit) and a
-- longer Perfect Guard window until that Snap Attack ends. But a Snap
-- Attack needs a full meter (or a Perfect Guard), and the skill empties it,
-- so the explosion rarely came. Now:
--   any_attack_after_block: after your next block (any block), your next
--     attack that lands (light, heavy, skill or Snap) sets off the explosion;
--   guard_window_seconds: the longer Perfect Guard window lasts this long
--     after the skill (0 = the game's: until the Snap Attack ends).
-- Once the explosion has gone off, the bonuses are over: the longer window
-- ends then too (and the bonus resets with the attack, as the game does).

local function IsSnap(attack)
	local id = attack.GetNameID ~= nil and attack:GetNameID() or nil
	return id == "snaptap" or id == "snapback"
end

function More.SharpenedReflexes(Main, s)
	local Power = require "defs.powers"
	local SGPlayerCleaver = require "stategraphs.sg_player_cleaver_common"
	local ok, def = pcall(Power.FindPowerByName, "cleaver_snapattack_boost")
	if not ok or type(def) ~= "table" or type(def.event_triggers) ~= "table" then
		error("the cleaver_snapattack_boost power not found", 0)
	end
	local trig = def.event_triggers
	def.skillbalance_orig = def.skillbalance_orig or { do_damage = trig.do_damage, attack_end = trig.attack_end,
		update = trig.update_snapattack_boost, on_remove = def.on_remove_fn }
	local orig = def.skillbalance_orig
	local explode = Main.FindUpvalue(orig.do_damage, "_cleaver_extra_hit")
	local SetWindow = SGPlayerCleaver ~= nil and SGPlayerCleaver.Fns ~= nil and SGPlayerCleaver.Fns.SetExtendedPerfectBlockWindow or nil
	if type(explode) ~= "function" or type(SetWindow) ~= "function" or type(orig.update) ~= "function" then
		error("Sharpened Reflexes' explosion / guard window not found", 0)
	end
	local G = Main.G

	local function Window(inst, on)
		if inst ~= nil and inst.sg ~= nil and inst.sg.mem ~= nil then
			SetWindow(inst, on)
		end
	end
	local function StopTimer(pow)
		if pow.mem.skillbalance_window ~= nil then
			pow.mem.skillbalance_window:Cancel()
			pow.mem.skillbalance_window = nil
		end
	end
	local function Reset(pow, inst)
		pow.mem.num_snap_attacks = 0
		pow.mem.damage_bonus = 0
		pow.mem.skillbalance_blocked = false
		pow.persistdata.counter = 0
		inst:PushEvent("update_power", pow.def)
		inst:PushEvent("used_power", pow.def)
	end

	trig.update_snapattack_boost = function(pow, inst, data)
		orig.update(pow, inst, data) -- the bonus, its counter, the window on
		pow.mem.skillbalance_blocked = false
		StopTimer(pow)
		if s.guard_window_seconds > 0 then
			pow.mem.skillbalance_window = inst:DoTaskInTime(s.guard_window_seconds, G.Fn("Sharpened Reflexes guard window", function()
				pow.mem.skillbalance_window = nil
				Window(inst, false)
			end))
		end
	end

	-- a block (any of the block states) readies the explosion; the longer
	-- window is put back on a fresh stategraph (a weapon swap)
	trig.newstate = function(pow, inst, data)
		local name = type(data) == "table" and data.statename or nil
		if s.any_attack_after_block and (pow.mem.damage_bonus or 0) > 0 and type(name) == "string" and name:find("^block") then
			pow.mem.skillbalance_blocked = true
		end
		if pow.mem.skillbalance_window ~= nil and inst.sg ~= nil and inst.sg.mem ~= nil and not inst.sg.mem.extended_just_defend_window then
			Window(inst, true)
		end
	end

	trig.do_damage = function(pow, inst, attack)
		if attack == nil or not pow.mem.damage_bonus or pow.mem.damage_bonus == 0 then
			return
		end
		local yes = IsSnap(attack)
		if not yes and s.any_attack_after_block and pow.mem.skillbalance_blocked then
			yes = attack.IsDirectPlayerAttack ~= nil and attack:IsDirectPlayerAttack()
				and (attack.GetSource == nil or attack:GetSource() ~= pow.def.name)
		end
		if not yes then
			return
		end
		pow.mem.num_snap_attacks = (pow.mem.num_snap_attacks or 0) + 1
		local target = attack:GetTarget()
		local data = { target = target, attack_id = attack:GetNameID() or "snaptap", damage = attack:GetDamage() * pow.mem.damage_bonus / 100 }
		inst:DoTaskInAnimFrames(6, G.Fn("Sharpened Reflexes explosion", function()
			if target ~= nil and target:IsValid() then
				explode(pow, inst, data)
			end
			-- the blast is done: the longer Perfect Guard window ends with it
			StopTimer(pow)
			Window(inst, false)
		end))
		inst:PushEvent("update_power", pow.def)
		inst:PushEvent("used_power", pow.def)
	end

	trig.attack_end = function(pow, inst, targets_hit)
		if not pow.mem.num_snap_attacks or pow.mem.num_snap_attacks == 0 then
			return
		end
		Reset(pow, inst)
		if s.guard_window_seconds <= 0 then
			Window(inst, false) -- the game's: the window ends with the attack
		end
	end

	def.on_remove_fn = function(pow, inst, ...)
		StopTimer(pow)
		if orig.on_remove ~= nil then
			return orig.on_remove(pow, inst, ...)
		end
		Window(inst, false)
	end

	return string.format("%s; the longer Perfect Guard window lasts %s",
		s.any_attack_after_block and "after your next block, your next attack sets off the explosion" or "the explosion on Snap Attacks (the game's)",
		s.guard_window_seconds > 0 and string.format("%g s or until the explosion", s.guard_window_seconds) or "until the Snap Attack ends (the game's)")
end

----------------------------------------------------------------------------
-- The Cannon's Backfire (skill during the plant / reload): the blast at the
-- muzzle reaches further and wider, and hits much harder. The strength goes
-- by the ammo it uses up (the game: 5-6 strong, 3-4 medium, 1-2 weak).

More.BACKFIRE_STATES = { "backfire_shoot_weak", "backfire_shoot_medium", "backfire_shoot_strong" }
More.BACKFIRE_KEYS = { weak = "BACKFIRE_WEAK", medium = "BACKFIRE_MEDIUM_EARLY", strong = "BACKFIRE_STRONG_EARLY" }

-- the blast: the beam in front of you on the shot's frame (both ends ahead);
-- the slide's hits behind / around you stay the game's
function More.ScaleBlast(s, startdist, enddist, thickness)
	if type(startdist) == "number" and type(enddist) == "number" and startdist > 0 and enddist > 0 then
		local far = math.max(startdist, enddist) * s.reach
		local near = math.min(startdist, enddist) * 0.5
		return far, near, (type(thickness) == "number" and thickness or 1) * s.radius
	end
	return startdist, enddist, thickness
end

function More.Backfire(Main, s, sg)
	local states = type(sg) == "table" and type(sg.states) == "table" and sg.states or nil
	if states == nil then
		error("no Cannon states", 0)
	end
	local attacks
	for _, name in ipairs(More.BACKFIRE_STATES) do
		local st = states[name]
		if st == nil then
			error(name .. " not found", 0)
		end
		local list = st.events ~= nil and st.events.hitboxtriggered or nil
		local h = list ~= nil and list[1] or nil
		attacks = attacks or (h ~= nil and Main.FindUpvalue(h.fn, "ATTACKS") or nil)
	end
	if type(attacks) ~= "table" then
		error("the Backfire's damage table not found", 0)
	end
	-- damage
	local parts = {}
	for tier, key in pairs(More.BACKFIRE_KEYS) do
		local a = attacks[key]
		if type(a) ~= "table" then
			error(key .. " not found", 0)
		end
		a.skillbalance_was = a.skillbalance_was or { a.DAMAGE, a.DAMAGE_FOCUS }
	end
	for i, tier in ipairs({ "weak", "medium", "strong" }) do
		local a = attacks[More.BACKFIRE_KEYS[tier]]
		a.DAMAGE = s.damage[i]
		a.DAMAGE_FOCUS = s.focus_damage[i]
		parts[#parts + 1] = string.format("%s %g / Focus %g (was %g / %g)", tier, a.DAMAGE, a.DAMAGE_FOCUS,
			a.skillbalance_was[1], a.skillbalance_was[2])
	end
	-- reach: the timeline's beams pass through the scaler while each runs
	local wrapped = 0
	for _, name in ipairs(More.BACKFIRE_STATES) do
		for _, ev in ipairs(states[name].timeline or {}) do
			if type(ev.fn) == "function" and not ev.skillbalance_reach then
				ev.skillbalance_reach = true
				local fn = ev.fn
				ev.fn = function(inst, ...)
					local hb = inst ~= nil and inst.components ~= nil and inst.components.hitbox or nil
					local cur = Main.settings ~= nil and Main.settings.backfire or nil
					if hb == nil or not cur or rawget(hb, "PushBeam") ~= nil then
						return fn(inst, ...)
					end
					local push = hb.PushBeam
					rawset(hb, "PushBeam", function(self, a, b, c, ...)
						local ok, x, y, z = pcall(More.ScaleBlast, cur, a, b, c)
						if ok then
							return push(self, x, y, z, ...)
						end
						return push(self, a, b, c, ...)
					end)
					local results = table.pack(pcall(fn, inst, ...))
					rawset(hb, "PushBeam", nil)
					if not results[1] then
						error(results[2], 0)
					end
					return table.unpack(results, 2, results.n)
				end
				wrapped = wrapped + 1
			end
		end
	end
	return string.format("Backfire: %s; the blast reaches x%g further, x%g wider", table.concat(parts, ", "), s.reach, s.radius)
end

return More
