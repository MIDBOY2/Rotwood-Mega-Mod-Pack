-- Two Weapons: swap attacks. A swap can come out attacking with the new weapon:
--   swap during a dodge          -> Mixed set (out of the dodge, its way)
--   swap while holding heavy (Y) -> Heavy set
--   swap while holding light (X) -> Aerial set
--   swap while holding skill (B) -> Skill set
--   plain swap, then light / heavy / skill a moment later -> those sets too
-- Each attack is the game's own move (its hits, damage, effects and cancel
-- windows), started in the new weapon's stategraph right after the swap.
-- On / off per player (Skill Slots' menu has the toggle).

local Attacks = {}

Attacks.SETS = { "mixed", "heavy", "aerial", "skill" }

local function TryRequire(name)
	local ok, mod = pcall(require, name)
	return ok and type(mod) == "table" and mod or nil
end
local function Fn(module, name)
	local fns = type(module) == "table" and rawget(module, "Fns") or nil
	local fn = type(fns) == "table" and rawget(fns, name) or nil
	return type(fn) == "function" and fn or nil
end
local SGCommon = TryRequire("stategraphs.sg_common")
local SGPlayerCommon = TryRequire("stategraphs.sg_player_common")
local FaceActionTarget = Fn(SGCommon, "FaceActionTarget")
local SetWeaponSheathed = Fn(SGPlayerCommon, "SetWeaponSheathed")

-- the game's turn-to-face helper (looked up when used)
local function Facing()
	return Fn(package.loaded["stategraphs.sg_common"], "FaceActionTarget") or FaceActionTarget
end
local function StickDir(inst)
	local pc = inst.components ~= nil and inst.components.playercontroller or nil
	if pc == nil or pc.GetAnalogDir == nil then
		return nil
	end
	local ok, dir = pcall(pc.GetAnalogDir, pc)
	return ok and type(dir) == "number" and dir or nil
end
-- the stick points back against where you face: the game's own check for
-- its turned attacks out of a dodge (SGPlayerCommon.Fns.IsReverseControl)
local function AngleBetween(a, b)
	local d = math.abs(a - b) % 360
	return d > 180 and 360 - d or d
end
function Attacks.IsStickBack(inst, dir)
	if dir == nil then
		return false
	end
	local reverse = Fn(package.loaded["stategraphs.sg_player_common"], "IsReverseControl")
	if reverse ~= nil then
		local ok, yes = pcall(reverse, inst, { dir = dir })
		if ok then
			return yes == true
		end
	end
	local t = inst.Transform
	local facing = t ~= nil and (t.GetFacingRotation ~= nil and t:GetFacingRotation() or (t.GetRotation ~= nil and t:GetRotation())) or nil
	return type(facing) == "number" and AngleBetween(dir, facing) > 100
end

-- Cannon air shot: needs the momentum of the blast it normally follows
local function CannonRecoil()
	local tuning = TUNING ~= nil and TUNING.GEAR ~= nil and TUNING.GEAR.WEAPONS ~= nil and TUNING.GEAR.WEAPONS.CANNON or nil
	local vel = tuning ~= nil and tuning.ROLL_VELOCITY or 11
	return { maxspeed = -vel, speed = 0, framessliding = 8 }
end

-- Greatsword skill slash, second half only: no meter spent, no geysers
local function CleaverSlash()
	return { meter = 0, spawn_positions = {}, spawn_indicators = {} }
end

-- type = the game's attack type for the move (sg.mem.attack_type): the game
-- sets it when it starts an attack from a button press, and the attack's
-- effects need it (a fresh weapon stategraph has none yet)
-- Order in the Court: the skill's wind-up from the hammer going up (frame 3),
-- the charge-hold part cut short (frame 7 -> 17), then the fully charged
-- focus slam
-- focus slam (on B: letting go of B doesn't cut it to the quick slam)
local THUMP = { state = "skill_hammer_thump", frame = 3, skip_after = 4, skip_to = 17, no_early_exit = true,
	release_button = true, type = "skill", name = "Order in the Court (focus slam)" }
local DRILL = { state = "rolling_drill_attack_pre", data = 1, type = "light_attack", name = "Rolling drill" }
local SLASH = { state = "skill_cleaver_blade_burst_pre", data = CleaverSlash, type = "skill", name = "Skill slash, end half" }
local AIRSHOT = { state = "blast_TO_airshoot", data = CannonRecoil, type = "light_attack", name = "Air shot" }
local TACKLE = { state = "rolling_tackle", data = 1, type = "light_attack", name = "Shoulder tackle" }

-- Spear vault strike: where it lands. The game's own (a power's follow-up)
-- lands just in front of the enemy you focus-hit; here: the closest enemy
-- ahead of you, else a few steps ahead.
local VAULT_RANGE = 9 -- how far it looks for an enemy to land on
local VAULT_CONE = 50 -- degrees either side of where you face
local VAULT_DIST = 6 -- nothing there: lands this far ahead
local VAULT_FRONT = 2 -- lands this far in front of the enemy (the game's)
local function AngleDiff(a, b)
	local d = math.abs(a - b) % 360
	return d > 180 and 360 - d or d
end
local function VaultTarget(inst)
	local x, z = inst.Transform:GetWorldXZ()
	local rot = inst.Transform:GetRotation()
	local px, pz
	local find = rawget(_G, "FindTargetsForEntityInRange")
	local ok, targets = false, nil
	if find ~= nil then
		ok, targets = pcall(find, inst, x, z, VAULT_RANGE)
	end
	local best, best_d
	for _, t in ipairs(ok and type(targets) == "table" and targets or {}) do
		if t ~= inst and t.IsValid ~= nil and t:IsValid() and t.Transform ~= nil then
			local tx, tz = t.Transform:GetWorldXZ()
			local d = math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2)
			if AngleDiff(rot, inst:GetAngleToXZ(tx, tz)) <= VAULT_CONE and (best_d == nil or d < best_d) then
				best, best_d = t, d
				px, pz = tx, tz
				if d > 0.1 then
					px, pz = tx + (x - tx) / d * VAULT_FRONT, tz + (z - tz) / d * VAULT_FRONT
				end
			end
		end
	end
	if best == nil then
		local r = math.rad(rot)
		px, pz = x + math.cos(r) * VAULT_DIST, z - math.sin(r) * VAULT_DIST
	end
	local pos = inst:GetPosition()
	pos.x, pos.z = px, pz
	local world = rawget(_G, "TheWorld")
	local map = world ~= nil and world.Map or nil
	if map ~= nil and map.FindClosestWalkablePoint ~= nil then
		local ok_walk, walk = pcall(map.FindClosestWalkablePoint, map, pos)
		if ok_walk and walk ~= nil then
			pos = walk
		end
	end
	inst.sg.mem.polearm_jump_combo_target_pos = pos
	inst.twoweapons_vault_pos = pos
	return pos
end
-- the jump was dodged out of before take-off: forget the spot (the game's
-- own follow-up would jump there otherwise)
local function VaultCleanup(inst)
	if inst.sg ~= nil and inst.sg.mem.polearm_jump_combo_target_pos == inst.twoweapons_vault_pos then
		inst.sg.mem.polearm_jump_combo_target_pos = nil
	end
	inst.twoweapons_vault_pos = nil
end

-- the vault strike (the game's follow-up from a power): leaps up and dives
-- down onto the closest enemy ahead (else a few steps ahead)
local VAULT = { state = "polearm_jump_out", prepare = VaultTarget, follow_states = { polearm_jump_out = true },
	on_end = VaultCleanup, type = "heavy_attack", name = "Vault strike" }
-- Crosscheck: the Spear's own skill, pushes an enemy away
local CROSSCHECK = { state = "skill_polearm_shove", type = "skill", name = "Crosscheck" }
-- the counter swing from a block, straight into the swing (the game's
-- sword-behind wind-up skipped: it made it look like two swings); knocks
-- back, a focus hit when there's meter (it spends some, like the game's)
local SNAPBACK = { state = "attack_snapback", data = function() return { level = 2 } end, type = "heavy_attack",
	full_swing = true, set_statemem = { twoweapons_full_swing = true }, -- the swing to its end (Attacks.InstallFullSwing)
	name = "Snapback counter" }
-- the overhead heavy slam, with the game's quick wind-up (the one it uses
-- out of a dodge)
local OVERHEAD = { state = "heavyattack2_cancel_pre",
	data = function() return { version = "up", heavyattack_combo = 1, damage_scale = 1 } end, type = "heavy_attack",
	name = "Overhead heavy slam" }
-- plants the cannon, then straight into the mortar shot / the shockwave (they
-- fire the ammo you have, like the game's own)
local MORTAR = { state = "cannon_plant_pre", set_statemem = { nextstate = "mortar_ammocheck" }, type = "heavy_attack",
	name = "Mortar lob" }
local SHOCKWAVE = { state = "cannon_plant_pre", set_statemem = { nextstate = "shockwave_ammocheck" }, type = "light_attack",
	name = "Shockwave slam" }
-- The Cannon's roll (Skill Slots' Cannon roll: the same invincibility as the
-- other weapons' rolls), then an attack out of it where the roll opens light /
-- heavy (the roll's 3rd frame): Blast (launches you back) or the normal shot.
-- Rolls the way the stick points. Without Skill Slots' Cannon roll: the
-- Mortar lob instead.
local function CannonRollReady(inst)
	local SS = package.loaded["skillslots.core"]
	if type(SS) ~= "table" or SS.cannon_installed ~= true then
		return false
	end
	local states = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.states or nil
	return states ~= nil and states.roll_pre ~= nil and states.roll_loop ~= nil and states.roll_pst ~= nil
end
-- Roll + Blast: the Blast fires back the way you came, so its kick launches
-- you on along the dodge (0.7.2; roll_blast_back: the Blast ahead, launching
-- you back against the dodge)
-- (reverse = the move's own push goes the other way: Attacks.MarkReverse below)
local ROLL_BLAST = { state = "roll_pre", needs = CannonRollReady, fallback = MORTAR, face_stick = true, unsheathe_first = true,
	after_roll = "default_heavy_attack", reverse_after_roll = "blast", type = "heavy_attack",
	name = "Roll + Blast (facing the dodge's way, launching you on along it)" }
local ROLL_BLAST_TURNED = { state = "roll_pre", needs = CannonRollReady, fallback = MORTAR, face_stick = true, unsheathe_first = true,
	after_roll = "default_heavy_attack", flip_after_roll = true, type = "heavy_attack",
	name = "Roll + Blast (turned around: fires back, launches you the dodge's way)" }
local ROLL_BLAST_BACK = { state = "roll_pre", needs = CannonRollReady, fallback = MORTAR, face_stick = true, unsheathe_first = true,
	after_roll = "default_heavy_attack", type = "heavy_attack", name = "Roll + Blast (launches you back)" }
local ROLL_SHOT = { state = "roll_pre", needs = CannonRollReady, fallback = MORTAR, face_stick = true, unsheathe_first = true,
	after_roll = "default_light_attack", type = "light_attack", name = "Roll + shot" }

-- The Mixed (dodge) set comes out of the dodge going the dodge's way, like the
-- Spear's rolling drill (the game's own roll attacks, with the roll's
-- momentum). Before 0.7.0 the Hammer and the Bow hopped back (fade-aways), the
-- Cannon rolled then blasted itself back, and the Greatsword's 5-frame quick
-- swing didn't read as coming out of a dodge. The old moves stay as choices
-- (hammer_a / bow_a / greatsword_a / cannon_a in the settings).

-- Hammer: the game's rolling heavy, the jump slam forward (its "far" one is
-- 2.3; this goes a bit further)
local JUMP_SLAM = { state = "heavy_attack_jump", data = 2.8, type = "heavy_attack", name = "Forward jump slam" }
-- how far the fade-away swing hops: the game's state takes a speed (1 = its own, 1.15 units;
-- it adds .5 at the swing, up to 2.5): hammer_fade_distance in the settings (0.8.2: 2, about
-- 2.1 units)
local function FadeDistance(inst, settings)
	local v = type(settings) == "table" and tonumber(settings.hammer_fade_distance) or nil
	if v == nil or v <= 0 then
		v = 2
	end
	return math.min(v, 4)
end
-- the fade-away swing: the game's state turns you around and hops you back,
-- so started facing the dodge it hops on the dodge's way, swinging behind
-- you (0.7.2; fade_swing_back: turned first, it hops back against the dodge)
local FADE_SWING = { state = "fading_light_attack", data = FadeDistance, preflip = true, reverse = true, type = "light_attack",
	name = "Fade-away swing (facing the dodge's way, hopping on along it)" }
local FADE_SWING_TURNED = { state = "fading_light_attack", data = FadeDistance, type = "light_attack",
	name = "Fade-away swing (turned around, hopping the dodge's way)" }
local FADE_SWING_BACK = { state = "fading_light_attack", data = FadeDistance, preflip = true, type = "light_attack", name = "Fade-away swing (hops back)" }
-- Bow: the leap shot (Weapon Moves: the rolling shot the game never plays,
-- from the roll's tucked pose, a forward leap shooting from the top); held A
-- charges it like held X. Without Weapon Moves: the game's rolling jump shot
-- forward (its "far" momentum).
local function HasLeap(inst)
	local states = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.states or nil
	return states ~= nil and states.weaponmoves_bow_leap_pre ~= nil
end
local BOW_JUMP_FWD = { state = "heavy_attack_hold", data = function() return { speedmult = 2.4 } end, type = "heavy_attack",
	name = "Forward jump shot" }
local LEAP_SHOT = { state = "weaponmoves_bow_leap_pre", data = 1.25, needs = HasLeap, fallback = BOW_JUMP_FWD, hold = "lightattack",
	hold_states = { weaponmoves_bow_leap_pre = true, weaponmoves_bow_leap_hold = true }, type = "light_attack",
	name = "Leap shot (hold A to charge)" }
local BACKFLIP = { state = "fading_light_attack_pre", data = -1, preflip = true, hold = "lightattack",
	hold_states = { fading_light_attack_pre = true, fading_light_attack_hold = true }, type = "light_attack",
	name = "Backflip shot (hold A to charge)" }
-- Greatsword: the game's forward roll into its heavy swing (the dodge-to-attack
-- animation, slowing down from dodge speed into the swing)
local DODGE_HEAVY = { state = "rolling_fwd_to_heavyattack1", type = "heavy_attack", name = "Out of the dodge into heavy swing" }
-- the Gut Bash: the Greatsword's lunge (its dodge attack), the dodge's way
-- (its wind-up animation wants a table, or it plays none)
local GUT_BASH = { state = "bash_pre", data = function() return {} end, type = "light_attack", name = "Gut Bash (the dodge's way)" }
local FAST_HEAVY = { state = "rolling_fwd_fast_to_heavyattack1", type = "heavy_attack", name = "Quick dodge into heavy swing" }

-- weapon type (stategraph "sg_player_<type>") -> set -> move
-- hold = the button the game's own charge checks; hold_states = the move's
-- charging part. The set's button (A / X / Y / B) held counts as that button,
-- so holding it charges (tapped: the quick version).
Attacks.MOVES = {
	hammer = {
		-- the fade-away swing, hopping on the dodge's way
		mixed = FADE_SWING,
		-- the jump slam, turned into the spinning flip when it comes down
		heavy = { state = "heavy_attack_jump_pre", redirect = { heavy_attack_air = "spinning_heavy_attack_air" },
			type = "heavy_attack", name = "Spinning flip slam" },
		-- the golf swing: turns, winds up, swings through; held X charges it
		-- like held Y does (3 strengths, the full one a focus hit)
		aerial = { state = "reverse_heavy_attack_pre", preflip = true, hold = "heavyattack",
			hold_states = { reverse_heavy_attack_pre = true }, type = "heavy_attack", name = "Golf swing (hold X to charge)" },
		skill = THUMP,
	},
	polearm = {
		mixed = DRILL,
		-- straight into the jump (the game's 6-frame wind-up skipped)
		heavy = { state = "heavy_attack", type = "heavy_attack", name = "Jump thrust (Y heavy)" },
		-- rapid multi-thrust (the beam version when a power gives it)
		aerial = { state = "multithrust_attack_pre", state_if_mem = { polearm_multithrust_beam = "multithrust_beam_attack" },
			type = "heavy_attack", name = "Rapid multi-thrust" },
		-- the vault strike (the game's follow-up from a power): leaps up and
		-- dives down onto the closest enemy ahead (else a few steps ahead)
		skill = VAULT,
	},
	bow = {
		-- the leap shot forward, out of the dodge; held A charges it
		mixed = LEAP_SHOT,
		-- the jump shot, straight into the jump (the wind-up skipped); keeps
		-- charging while Y is held, shoots when it's let go
		heavy = { state = "heavy_attack_hold", data = function() return { speedmult = 1 } end, type = "heavy_attack",
			name = "Jump shot (Y heavy)" },
		-- slides forward into a kneel and shoots; held X charges the shot
		aerial = { state = "rolling_light_attack_pre", data = 1.25, hold = "lightattack",
			hold_states = { rolling_light_attack_pre = true, rolling_light_attack_hold = true }, type = "light_attack",
			name = "Kneeling slide shot (hold X to charge)" },
		skill = { state = "skill_bow_melee", type = "skill", name = "Melee bash" },
	},
	cleaver = {
		-- the Gut Bash, lunging on the dodge's way
		mixed = GUT_BASH,
		-- its horizontal sweep, with the game's quick wind-up (the one it uses
		-- out of a dodge); a focus hit when there's meter, and Y kept held
		-- spins on like the game's own
		heavy = { state = "heavyattack3_cancel_pre", data = function() return { heavyattack_combo = 1, damage_scale = 1 } end,
			type = "heavy_attack", name = "Horizontal sweep" },
		aerial = SLASH,
		skill = SNAPBACK,
	},
	shotput = {
		aerial = { state = "throw", data = true, needs_ammo = true, fallback = TACKLE, type = "heavy_attack", name = "Focus throw" },
		heavy = { state = "skill_shotput_slam", type = "skill", name = "Ball slam" },
		mixed = TACKLE,
		-- the fade-away kick: hops back kicking the way you were going (the
		-- game's state turns you around for this, so turn first)
		skill = { state = "fading_kick", data = 1, preflip = true, type = "light_attack", name = "Flip kick" },
	},
	cannon = {
		-- rolls the dodge's way, then the Blast fired back the way you came:
		-- its kick launches you on along the dodge
		mixed = ROLL_BLAST,
		heavy = AIRSHOT,
		-- its normal shot (overheated / out of ammo: what the game does then)
		aerial = { state = "default_light_attack", type = "light_attack", name = "Quick shot" },
		skill = { state = "skill_cannon_butt", type = "skill", name = "Cannon whack" },
	},
}

-- other moves a set can use instead, picked in the settings:
--   weapon -> set -> { setting = settings key, moves = { value -> move } }
Attacks.ALTS = {
	polearm = { skill = { setting = "spear_b", moves = { vault = VAULT, crosscheck = CROSSCHECK } } },
	cleaver = { skill = { setting = "greatsword_b", moves = { snapback = SNAPBACK, overhead = OVERHEAD } },
		mixed = { setting = "greatsword_a", moves = { bash = GUT_BASH, dodge_heavy = DODGE_HEAVY, quick_heavy = FAST_HEAVY } } },
	cannon = { mixed = { setting = "cannon_a", moves = { roll_blast = ROLL_BLAST, roll_blast_turned = ROLL_BLAST_TURNED, roll_blast_back = ROLL_BLAST_BACK, roll_shot = ROLL_SHOT,
		mortar = MORTAR, shockwave = SHOCKWAVE } } },
	hammer = { mixed = { setting = "hammer_a", moves = { fade_swing = FADE_SWING, fade_swing_turned = FADE_SWING_TURNED, fade_swing_back = FADE_SWING_BACK, jump_slam = JUMP_SLAM } } },
	bow = { mixed = { setting = "bow_a", moves = { leap_shot = LEAP_SHOT, backflip = BACKFLIP } } },
}

local function WeaponOfSG(inst)
	local name = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.name or nil
	return type(name) == "string" and name:match("^sg_player_(.+)$") or nil
end
Attacks.WeaponOfSG = WeaponOfSG

local function HasState(inst, state)
	local states = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.states or nil
	return states ~= nil and states[state] ~= nil
end

-- B (the "skill" set): the skill on B for the weapon just swapped in, the
-- way B itself would fire it: Skill Slots' pick for that weapon's loadout
-- (its power added right away, Skill Slots would a tick later), else the
-- game's skill (the one a run gave you, or the weapon's own).
local function SkillState(inst)
	local SS = package.loaded["skillslots.core"]
	if type(SS) == "table" and SS.IsActive ~= nil and SS.GetBSkillName ~= nil then
		local ok, active = pcall(SS.IsActive, inst)
		if ok and active then
			local ok_name, name = pcall(SS.GetBSkillName, inst)
			if ok_name and type(name) == "string" and SS.IsPseudo ~= nil and SS.IsPseudo(name) then
				-- B holds a weapon choice (the Greatsword's Block), not a skill:
				-- the weapon's own B swap move instead
				return nil
			end
			if ok_name and type(name) == "string" then
				if SS.HasPower ~= nil and SS.Sync ~= nil and not SS.HasPower(inst, name) then
					pcall(SS.Sync, inst)
				end
				if SS.Settle ~= nil then
					pcall(SS.Settle, inst)
				end
				return "skill_" .. name
			end
		end
	end
	local mem = inst.sg ~= nil and inst.sg.mem or nil
	if mem ~= nil and type(mem.skillstate) == "string" and HasState(inst, mem.skillstate) then
		return mem.skillstate
	end
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	local item = hoard ~= nil and hoard.GetEquippedItem ~= nil and hoard:GetEquippedItem("WEAPON") or nil
	local ok, usage = pcall(function() return item:GetUsageData() end)
	if ok and type(usage) == "table" and type(usage.skill_on_equip) == "string" then
		return "skill_" .. usage.skill_on_equip
	end
	return nil
end
Attacks.SkillState = SkillState

local function ShotputHasBall(inst)
	local mem = inst.sg.mem
	if type(mem.ammo_max) ~= "number" then
		return true
	end
	local count = 0
	for _ in pairs(mem.active_projectiles or {}) do
		count = count + 1
	end
	return mem.ammo_max - count > 0
end

function Attacks.GetMove(weapon, kind)
	local set = weapon ~= nil and Attacks.MOVES[weapon] or nil
	return set ~= nil and set[kind] or nil
end

local warned = {}
local function Warn(key, msg)
	if not warned[key] then
		warned[key] = true
		print("[Two Weapons] " .. msg)
	end
end

-- Turn one state into another the first time the attack reaches it (the
-- hammer's jump slam -> spinning flip). Stops once the attack is over.
local function Redirect(inst, map)
	local done = false
	local fn
	local function stop()
		if not done then
			done = true
			inst:RemoveEventCallback("newstate", fn)
		end
	end
	fn = function(inst, data)
		local to = data ~= nil and map[data.statename] or nil
		if to ~= nil then
			stop()
			if HasState(inst, to) then
				inst.sg:GoToState(to)
			end
		elseif inst.sg ~= nil and not inst.sg:HasStateTag("attack") then
			stop()
		end
	end
	inst:ListenForEvent("newstate", fn)
	inst:DoTaskInTime(3, stop)
end

-- Call on_end once the attack moves on from these states (or after a few
-- seconds, whatever happens). Returns a function that ends it early.
local function Follow(inst, states, on_end)
	local done = false
	local fn
	local function stop()
		if not done then
			done = true
			inst:RemoveEventCallback("newstate", fn)
			on_end(inst)
		end
	end
	fn = function(inst, data)
		local name = data ~= nil and data.statename or nil
		if not states[name] then
			stop()
		end
	end
	inst:ListenForEvent("newstate", fn)
	inst:DoTaskInTime(5, stop)
	return stop
end

-- The Cannon roll swap attacks: once the roll reaches the frame where it opens
-- light / heavy (roll_loop's 3rd frame, or its recovery if the roll is
-- shorter), go to the attack. Anything else (a hit, a dodge) ends it.
local ROLL_STATES = { roll_pre = true, roll_loop = true }
Attacks.ROLL_ATTACK_FRAME = 2
----------------------------------------------------------------------------
-- A move's own push the other way. The Cannon's Blast kicks you away from
-- where it fires, and the Hammer's fade-away swing hops back. To face your
-- dodge and still travel with it, the push is turned around instead of you:
-- while the marked state plays, SGCommon.Fns.SetMotorVelScaled (the hop) and
-- Physics:MoveRelFacing (the Blast's first kick) go the other way, and the
-- Blast's slide speed is turned around once it's set. The mark is put on
-- before the state starts (the game can run its frame 0 inside GoToState) and
-- comes off as soon as you're in any other state.

local function Marked(inst)
	local m = inst ~= nil and type(inst) == "table" and rawget(inst, "twoweapons_reverse") or nil
	local sg = m ~= nil and inst.sg or nil
	return sg ~= nil and sg.currentstate ~= nil and sg.currentstate.name == m
end
Attacks.Marked = Marked

Attacks.reverse_owner = setmetatable({}, { __mode = "k" }) -- Physics -> its entity
function Attacks.InstallReverse()
	if not Attacks.motorvel_hooked then
		local common = TryRequire("stategraphs.sg_common") or SGCommon
		local fns = type(common) == "table" and rawget(common, "Fns") or nil
		if type(fns) == "table" and type(rawget(fns, "SetMotorVelScaled")) == "function" then
			local orig = fns.SetMotorVelScaled
			fns.SetMotorVelScaled = function(inst, value, ...)
				if type(value) == "number" and Marked(inst) then
					value = -value
				end
				return orig(inst, value, ...)
			end
			Attacks.motorvel_hooked = true
		end
	end
	return Attacks.motorvel_hooked == true
end

local function HookMoveRel(inst)
	local phys = inst.Physics
	if phys == nil then
		return false
	end
	Attacks.reverse_owner[phys] = inst
	if Attacks.moverel_hooked then
		return true
	end
	local mt = getmetatable(phys)
	local index = type(mt) == "table" and mt.__index or nil
	if type(index) == "table" and type(index.MoveRelFacing) == "function" then
		local orig = index.MoveRelFacing
		index.MoveRelFacing = function(self, dist, ...)
			local owner = Attacks.reverse_owner[self]
			if owner ~= nil and type(dist) == "number" and Marked(owner) then
				dist = -dist
			end
			return orig(self, dist, ...)
		end
		Attacks.moverel_hooked = true
	end
	return Attacks.moverel_hooked == true
end

function Attacks.MarkReverse(inst, state)
	Attacks.InstallReverse()
	pcall(HookMoveRel, inst)
	rawset(inst, "twoweapons_reverse", state)
	local fn
	fn = function(_, data)
		local name = data ~= nil and data.statename or nil
		if name ~= state then
			if rawget(inst, "twoweapons_reverse") == state then
				rawset(inst, "twoweapons_reverse", nil)
			end
			inst:RemoveEventCallback("newstate", fn)
		end
	end
	inst:ListenForEvent("newstate", fn)
end

-- The Snapback's swing to its end. The game plays only the first 17 frames of its overhead
-- swing (cleaver_atk3_vert, 33 frames) and jumps to the recovery (cleaver_atk3_pst), which
-- starts from the swing's last pose: the sword landing and the settle (frames 17-32) were
-- skipped and the recovery popped in. A swap Snapback (statemem.twoweapons_full_swing) lets
-- the swing finish; the state's own animover then goes to the recovery, the same way. The
-- game's own Snapback (and every other player) is unchanged.
Attacks.full_swing_patched = setmetatable({}, { __mode = "k" })
Attacks.FULL_SWING_FRAME = 17
function Attacks.InstallFullSwing(inst, state)
	local states = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.states or nil
	local st = states ~= nil and states[state] or nil
	if st == nil or type(st.timeline) ~= "table" then
		return false
	end
	if Attacks.full_swing_patched[st] ~= nil then
		return Attacks.full_swing_patched[st]
	end
	local per = rawget(_G, "ANIM_FRAMES") or 1
	local found = 0
	for _, ev in ipairs(st.timeline) do
		if type(ev) == "table" and ev.frame == Attacks.FULL_SWING_FRAME * per and type(ev.fn) == "function" then
			local orig = ev.fn
			ev.fn = function(i, ...)
				local mem = i ~= nil and i.sg ~= nil and i.sg.statemem or nil
				if mem ~= nil and mem.twoweapons_full_swing then
					return -- the swing plays on to its end
				end
				return orig(i, ...)
			end
			found = found + 1
		end
	end
	Attacks.full_swing_patched[st] = found > 0
	if found == 0 then
		Warn(state .. " full swing", "the Snapback's full swing skipped: a game update moved its frame-17 cut")
	end
	return found > 0
end

-- the marked state has started: its slide speed (the Blast's) the other way too
function Attacks.ReverseSpeed(inst)
	if not Marked(inst) then
		return false
	end
	local mem = inst.sg.statemem
	for _, key in ipairs({ "maxspeed", "speed" }) do
		if type(mem[key]) == "number" then
			mem[key] = -mem[key]
		end
	end
	return true
end

function Attacks.AfterRoll(inst, attack_state, attack_type, flip, reverse_state)
	local done = false
	local fn
	local function stop()
		if not done then
			done = true
			inst:RemoveEventCallback("newstate", fn)
		end
	end
	local function go()
		stop()
		if HasState(inst, attack_state) then
			inst.sg.mem.attack_type = attack_type or "light_attack"
			if flip and inst.FlipFacingAndRotation ~= nil then
				inst:FlipFacingAndRotation() -- fire back the way you came
			end
			if reverse_state ~= nil then
				Attacks.MarkReverse(inst, reverse_state) -- face the dodge, the kick launches you on along it
			end
			inst.sg:GoToState(attack_state)
			if reverse_state ~= nil then
				Attacks.ReverseSpeed(inst)
			end
		end
	end
	fn = function(inst, data)
		local name = data ~= nil and data.statename or nil
		if name == "roll_loop" then
			local started = inst.sg.statestarttick
			local function at_frame()
				if not done and inst:IsValid() and inst.sg ~= nil and inst.sg.currentstate ~= nil
					and inst.sg.currentstate.name == "roll_loop" and inst.sg.statestarttick == started then
					go()
				end
			end
			if inst.DoTaskInAnimFrames ~= nil then
				inst:DoTaskInAnimFrames(Attacks.ROLL_ATTACK_FRAME, at_frame)
			else
				inst:DoTaskInTime(Attacks.ROLL_ATTACK_FRAME / 30, at_frame)
			end
		elseif name == "roll_pst" then
			go() -- a short roll: straight from its recovery
		elseif not ROLL_STATES[name] then
			stop()
		end
	end
	inst:ListenForEvent("newstate", fn)
	inst:DoTaskInTime(3, stop)
end

-- the button of each set (A is the dodge button)
Attacks.SET_BUTTON = { mixed = "dodge", heavy = "heavyattack", aerial = "lightattack", skill = "skill" }

-- The set's button held: the move charges as if the button the game's charge
-- checks were held (Y for the golf swing, X for the bow's shots), until it's
-- let go or the move gets past its charge. When it's the same button, the
-- game's own charge just works.
local function HoldWith(inst, move, source)
	local pc = inst.components ~= nil and inst.components.playercontroller or nil
	if source == nil or source == move.hold or pc == nil or type(pc.IsControlHeld) ~= "function"
		or not pc:IsControlHeld(source) then
		return
	end
	local control = move.hold
	local base_held, base_ticks = pc.IsControlHeld, pc.GetControlHeldTicks
	local own_held, own_ticks = rawget(pc, "IsControlHeld"), rawget(pc, "GetControlHeldTicks")
	local active = true
	local function held(self, name, ...)
		if active and name == control and base_held(self, source) then
			return true
		end
		return base_held(self, name, ...)
	end
	local function ticks(self, name, ...)
		local n = base_ticks(self, name, ...)
		if active and name == control and base_held(self, source) then
			local b = base_ticks(self, source)
			if type(b) == "number" and (type(n) ~= "number" or b > n) then
				return b
			end
		end
		return n
	end
	rawset(pc, "IsControlHeld", held)
	if type(base_ticks) == "function" then
		rawset(pc, "GetControlHeldTicks", ticks)
	end
	local function on_up(inst, data)
		if active and data ~= nil and data.control == source and not base_held(pc, control) then
			-- the game's charge ends when its own button comes up
			inst.sg:PushEvent("controlupevent", { control = control })
		end
	end
	inst:ListenForEvent("controlupevent", on_up)
	Follow(inst, move.hold_states, function(inst)
		active = false
		inst:RemoveEventCallback("controlupevent", on_up)
		if rawget(pc, "IsControlHeld") == held then
			rawset(pc, "IsControlHeld", own_held)
		end
		if rawget(pc, "GetControlHeldTicks") == ticks then
			rawset(pc, "GetControlHeldTicks", own_ticks)
		end
	end)
end

-- Start the swap attack of this set with the weapon now in hand.
-- settings.b_moves = "skill": B fires the new weapon's B skill instead of its
-- own swap move; Attacks.ALTS: other moves picked in the settings.
-- Returns the move started, or nil.
function Attacks.Start(inst, kind, settings)
	if inst.sg == nil then
		return nil
	end
	local weapon = WeaponOfSG(inst)
	local move = Attacks.GetMove(weapon, kind)
	local alt = weapon ~= nil and Attacks.ALTS[weapon] ~= nil and Attacks.ALTS[weapon][kind] or nil
	if alt ~= nil and type(settings) == "table" and alt.moves[settings[alt.setting]] ~= nil then
		move = alt.moves[settings[alt.setting]]
	end
	if kind == "skill" and (move == nil or (type(settings) == "table" and settings.b_moves == "skill")) then
		-- B: the new weapon's B skill
		local skill = SkillState(inst)
		if skill ~= nil then
			local cur = inst.sg.currentstate ~= nil and inst.sg.currentstate.name or nil
			move = { state = skill, type = "skill", name = "B skill (" .. skill .. ")", already = cur == skill, b_skill = true }
		elseif move == nil then
			return nil
		end
		-- no skill to fire (B holds Block): the weapon's own B move stays
	end
	if move == nil then
		return nil
	end
	if move.needs_ammo and not ShotputHasBall(inst) then
		move = move.fallback
	end
	if move ~= nil and move.needs ~= nil then
		local ok, ready = pcall(move.needs, inst)
		if not (ok and ready) then
			move = move.fallback
		end
	end
	if move == nil then
		return nil
	end
	if move == nil then
		return nil
	end
	local state = move.state
	for key, alt in pairs(move.state_if_mem or {}) do
		if inst.sg.mem[key] and HasState(inst, alt) then
			state = alt
		end
	end
	if move.b_skill and inst.sg.mem.skillstate == nil then
		inst.sg.mem.skillstate = state
	end
	if move.b_skill then
		-- Skill Slots: which of the Bow's primed-arrow skills this is
		local SS = package.loaded["skillslots.core"]
		if type(SS) == "table" and SS.NotePrime ~= nil then
			pcall(SS.NotePrime, inst, state)
		end
	end
	if not HasState(inst, state) then
		Warn(state, "swap attack skipped: a game update removed the state " .. tostring(state))
		return nil
	end
	local data = move.data
	if type(data) == "function" then
		data = data(inst, settings)
	end
	if move.already then
		-- B was pressed right after the swap and the game already started this
		-- skill: leave it running
		inst:PushEvent("twoweapons_swapattack", { weapon = weapon, kind = kind, state = state })
		return move
	end
	if move.redirect ~= nil then
		Redirect(inst, move.redirect)
	end
	-- what the game does before it starts an attack from a button press
	inst.sg.mem.attack_type = move.type or "light_attack"
	local face = Facing()
	if (kind ~= "mixed" or move.face_stick) and face ~= nil then
		-- Heavy / Aerial / Skill (and the Cannon roll): face where the stick points
		local dir = StickDir(inst)
		if dir ~= nil then
			pcall(face, inst, { dir = dir }, true, true)
		end
	elseif kind == "mixed" and face ~= nil and (type(settings) ~= "table" or settings.swap_turn_with_stick ~= false) then
		-- Mixed (A) goes the dodge's way, unless the stick points back the
		-- other way: then it turns that way first, like the game's own turned
		-- attacks out of a dodge (dodge one way, stick the other, attack)
		local dir = StickDir(inst)
		if Attacks.IsStickBack(inst, dir) then
			pcall(face, inst, { dir = dir }, true, true)
		end
	end
	if move.prepare ~= nil then
		local ok, err = pcall(move.prepare, inst)
		if not ok then
			Warn("prepare " .. state, "swap attack setup failed (" .. state .. "): " .. tostring(err))
		end
	end
	if move.follow_states ~= nil and move.on_end ~= nil then
		Follow(inst, move.follow_states, move.on_end)
	end
	if move.preflip and inst.FlipFacingAndRotation ~= nil then
		inst:FlipFacingAndRotation()
	end
	if move.release_button then
		-- the move ignores its button: the game won't hear it come up
		local pc = inst.components ~= nil and inst.components.playercontroller or nil
		local button = Attacks.SET_BUTTON[kind]
		for _, d in ipairs(pc ~= nil and type(pc.controlqueue) == "table" and pc.controlqueue or {}) do
			if d.control == button and not d.released then
				d.released = true
			end
		end
	end
	if move.hold ~= nil and move.hold_states ~= nil then
		-- before the state starts: it checks the button as it begins
		HoldWith(inst, move, Attacks.SET_BUTTON[kind])
	end
	if move.unsheathe_first and SetWeaponSheathed ~= nil then
		-- the roll picks its (sheathed or not) animation as it starts
		pcall(SetWeaponSheathed, inst, false)
	end
	if move.after_roll ~= nil then
		Attacks.AfterRoll(inst, move.after_roll, move.type, move.flip_after_roll, move.reverse_after_roll)
	end
	if move.reverse then
		Attacks.MarkReverse(inst, state)
	end
	if move.full_swing then
		Attacks.InstallFullSwing(inst, state)
	end
	inst.sg:GoToState(state, data)
	if move.reverse then
		Attacks.ReverseSpeed(inst)
	end
	local in_state = inst.sg.currentstate ~= nil and inst.sg.currentstate.name == state
	if move.frame ~= nil and in_state and inst.AnimState ~= nil and inst.AnimState.SetFrame ~= nil then
		inst.AnimState:SetFrame(move.frame)
		if move.skip_to ~= nil then
			local started = inst.sg.statestarttick
			local function skip()
				if inst:IsValid() and inst.sg ~= nil and inst.sg.currentstate ~= nil and inst.sg.currentstate.name == state
					and inst.sg.statestarttick == started then
					inst.AnimState:SetFrame(move.skip_to)
				end
			end
			if inst.DoTaskInAnimFrames ~= nil then
				inst:DoTaskInAnimFrames(move.skip_after or 1, skip)
			else
				inst:DoTaskInTime((move.skip_after or 1) / 30, skip)
			end
		end
	end
	if move.set_statemem ~= nil and in_state then
		for k, v in pairs(move.set_statemem) do
			inst.sg.statemem[k] = v
		end
	end
	if move.no_early_exit and in_state then
		-- the skill button isn't held (or doesn't count), so the skill would cut
		-- to its quick (uncharged) slam; let it run into the charged one instead
		inst.sg.statemem.mustexit = false
	end
	if SetWeaponSheathed ~= nil then
		pcall(SetWeaponSheathed, inst, false)
	end
	-- the X / Y press that asked for it is used up (held buttons stay held, so
	-- the bow can still charge)
	local pc = inst.components ~= nil and inst.components.playercontroller or nil
	if pc ~= nil and pc.FlushControlQueue ~= nil then
		pc:FlushControlQueue()
	end
	inst:PushEvent("twoweapons_swapattack", { weapon = weapon, kind = kind, state = state })
	return move
end

return Attacks
