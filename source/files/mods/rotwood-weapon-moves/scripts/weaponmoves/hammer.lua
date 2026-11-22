-- Weapon Moves: the Hammer's spin finale.
--
-- The spin (the Lariat): roll, X with the stick pulled back the way you came
-- (the fade-away hop swing), then Y (hold Y for more spins). It only lets you
-- dodge while it spins; B does nothing until you're standing again. (Roll,
-- then Y pulled back is the sliding golf swing, not the spin.) Here B in the
-- spin (wind-up, loops, or its ending before frame 8; a B pressed just before
-- the spin too) plays the ending the game has animated but never uses
-- (UNUSED_hammer_big_atk1_pst, 54 frames). B doesn't cut the spin you're in:
-- the finale starts when that spin comes round (the end of the wind-up or of
-- the loop). The game's ending is the loop's frames 0-7; at its frame 8 it
-- leaves the spin (the hammer swings down behind you, on the ground by 12)
-- where the finale keeps it up and brings it round in front: the point of no
-- return. B in the ending before it: the finale takes over at frame 8, from its
-- own frame 8 (the hammer behind you in the same place). The finale:
--   frames 0-14   one more spin (in front, then behind), hits like the spin,
--                 with the loop's swipe trails and spin sound
--   frames 15-18  a big rising swing in front: knocks down and back
--                 (hammer_finale_knockback), 1.15x damage,
--                 the golf swing's whoosh (not its Focus whoosh: that one's metal
--                 clang doesn't fit here); its trail: the
--                 loop's front swipe for the low sweep, then (frame 17) the
--                 spin trails go and the animation's own smear draws the
--                 upswing (frames 17-22: its big arc stays where it was swung
--                 and the trail reaches the hammer as it goes over; solid, then
--                 dying out in the game's swipes' 4 states)
--   frames 17-40  the hammer carries you up (airborne: ground attacks pass
--                 under you), spinning in the air in a whirlwind (from 18)
--   frames 40-54  you land, the hammer goes on your back (dodge from frame 42,
--                 attack / move from 46); then (hammer_finale_landing): "back"
--                 = it stays there (the game's sheathed idle, as in camp),
--                 "hand" = you draw it (the game's hammer_unsheathe_fast,
--                 cancel any time), "auto" = back in camp, hand in a run
-- Its hits use the spin's own numbers for how far the spin got (the game's
-- tables), and the rising swing is a Focus hit when the spin was at full
-- length, as the game's own spin ending is.

local Main = require "weaponmoves.main"

local Hammer = {}

Hammer.FINALE = "weaponmoves_hammer_spin_finale"
Hammer.ANIM = "UNUSED_hammer_big_atk1_pst"
-- B works in these. The ending (pst): before its frame 8 (Hammer.PST_BRANCH).
-- From there until the game opens its recovery (attacks / skills: frame 18, 23
-- or 24 by how long the spin was) B is used up: no finale, and not the skill
-- the game would fire from it the moment the recovery opens (it keeps presses
-- 20 frames longer from the ending's frame 9). After that: the game's.
Hammer.FROM = { fading_heavy_spin_pre = true, fading_heavy_spin_loop = true, fading_heavy_spin_pst = "branch" }
Hammer.PST_OPEN = { [0] = 18, [1] = 23, [2] = 24 } -- by statemem.recovery_tier
-- the game's ending (hammer_big_atk1_sheathe_pst / 2 / 3) is the loop's frames 0-7
-- (the same poses); at 8 it leaves the spin: the point of no return. The finale's
-- own frames 6-8 have the hammer behind you there too, so it takes over at 8
-- from its frame 8 (no extra spin: the ending's 0-7 were that spin).
Hammer.PST_BRANCH = 8
-- B pressed just before the spin (still in the game's press queue, 6 frames)
-- counts: checked on the spin's frame 1
Hammer.FIRST, Hammer.QUEUE_FRAME = "fading_heavy_spin_pre", 1
Hammer.HOW = "roll, X with the stick pulled back (the fade-away swing), then Y"
Hammer.RISE_FRAME = 15 -- the rising swing's first hit
Hammer.AIR_FROM, Hammer.AIR_TO = 17, 40
Hammer.DODGE_FRAME = 42
Hammer.FREE_FRAME = 46
Hammer.NOTE_LIMIT = 40
-- B in the spin waits for the spin to come round (sg.mem flag, taken when the
-- game enters its next loop or its ending; the wind-up clears a stale one)
Hammer.QUEUED = "weaponmoves_finale_queued"
Hammer.LOOP, Hammer.PST = "fading_heavy_spin_loop", "fading_heavy_spin_pst"
Hammer.RISE_FROM = 14 -- the rising swing's attack (hits 15-17)
Hammer.RISE_TO = 18 -- its attack ends (EndMeleeAttack)
Hammer.RISE_DAMAGE = 1.15
-- the rising swing's knockback: the game's knockdown hits (sg_player_hammer
-- OnHitBoxTriggered: DoKnockdownAttack) never set the attack's pushback, so they
-- all knock 1x the target's knockdown_distance (sg_common knockdown_pre: distance
-- = knockdown_distance x pushback x weight); the rising swing's hits get this
-- pushback (hammer_finale_knockback; the game's number for the spin's last
-- round, ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[3], is 3.5)
-- the swipe trails: the loop's own (prefabs/autogen/animtag/fx_player_swipes.lua,
-- hammer_big_atk1_loop: front at 0, off at 2, back at 6), and the front one for
-- the rising swing's low sweep. When the upswing starts (frame 17) every trail
-- of the finale still playing goes (the low sweep would go on circling on the
-- ground under you), and the body's own smear draws the upswing.
Hammer.SWIPES = { [0] = "fx_hammer_big_atk1", [6] = "fx_hammer_big_atk1_back", [14] = "fx_hammer_big_atk1" }
Hammer.UNSWIPES = { 2, 12 }
-- the upswing's trail: the animation's own smear. The hammer animations draw
-- their smears with fx_swipe_tornado01_untex, whose placeholder art (flat white)
-- is in the hammer bank's own build (player_bank_hammer); the game never shows it
-- (player_side.lua leaves AddOverrideBuild("player_bank_hammer") off and uses
-- swipe fx instead), and no swipe fx was made for this unused upswing. The smears
-- are drawn in place (the anim puts the symbol untransformed), so the mod's build
-- weaponmoves_hammer_smear (anim/weaponmoves_hammer_smear.zip, made by the kit's
-- tools/weaponmoves/build_smear.py) draws, for frames 17-22, the trail swung so far:
-- the upswing's big arc where it was swung plus the follow-through's smears up to the
-- hammer, painted like the game's hammer swipes (gold edges, the grey-green middle with
-- its darker stripe, a bit narrower than the hammer) and dying out in the 4 states of
-- the game's swipes, still reaching the hammer: 17-18 solid; 19-20 a narrower solid
-- gold / grey edge, a thin solid streak inside, gold at 30% alpha where the rest was;
-- 21 a short thin gold strand by the hammer, the 30% gold much narrower; 22 one faint
-- curved gold strand. Its outline is smoothed (drawn at 3x, the edge blurred and
-- re-cut, its width evened out along the arc) so the curve has no rough edges or
-- steps, and the die-out lines run smooth. For frames 17-22 only,
-- that one symbol is taken from it, drawn like the swipe fx (darkened, glowing, unlit),
-- then given back. Weapons whose swipes aren't gold (fire, frost, electric, fancy) get
-- the same arc in greys (the build's weaponmoves_smear_tint symbol), tinted their colour.
Hammer.SMEAR = "fx_swipe_tornado01_untex"
Hammer.SMEAR_BUILD = "weaponmoves_hammer_smear"   -- painted like the gold swipes
Hammer.SMEAR_TINT = "weaponmoves_smear_tint"   -- the same arc in greys, for tinting
-- Focus (hammer_focus_fx): the game's cyan spark glint made for this spin
-- (fx_hammer_charge_glint bank, hammer_big_atk1_loop_front: cyan sparks along the front
-- sweep, then the back sweep, lingering; prefabs/autogen/fx defines
-- fx_hammer_big_atk1_loop_front but the game never plays it), attached the way the game attaches its Focus swipes (the golf swing's
-- fx_hammer_charge_swipe_full: SGPlayerCommon.Fns.AttachExtraSwipeFx, then
-- DetachExtraSwipeFx so it plays on where it is). A spin is Focus when it hit more than
-- one enemy (sg_player_hammer FOCUS_TARGETS_THRESHOLD = 1) or it's at full length.
Hammer.FOCUS_FX = "fx_hammer_big_atk1_loop_front"
Hammer.FOCUS_TARGETS = 1
-- the rise's Focus sparks: no glint was made for the rise, but the finale draws an unused
-- symbol in the character's own space (fx_twirl01_untex, identity matrix, anim frames
-- 13-30 as symbol frames 0-17; no build has its art). A Focus finale puts the mod's
-- weaponmoves_focus_rise on it (anim/weaponmoves_hammer_focus.zip, made by the kit's
-- tools/weaponmoves/build_focus_overlay.py) for frames 17-30: the golf swing's own Focus
-- sparks (fx_hammer_charge_swipe_full = fx_hammer_charge_glint's
-- fx_hammer_roll_reverse_atk_full, its 17 frames over these 14: all its particle_spark_untex
-- sprites there with the swing, then drifting and fading where they are, none coming later),
-- carried from along the golf swing's circle with their sizes and turns onto the whole path
-- the hammer swings, all the way up to it: the arc (sprite 11) from 17, the follow-through
-- (12) from 19 and (13) from 21, each stretch's sparks coming as the trail reaches it and
-- gone by the landing. The finale draws the symbol behind the body on 19-22 and 27-30 and
-- also in front on 23-26, so those frames leave the hammer clear (the sparks stay behind
-- it). Glowing cyan like the glint fx (bloom 75, glow colour 00C1FF), unlit. A Focus rise
-- keeps the gold trail; the sparks are this overlay's.
Hammer.TWIRL = "fx_twirl01_untex"
Hammer.FOCUS_RISE_BUILD = "weaponmoves_hammer_focus"
Hammer.FOCUS_RISE = "weaponmoves_focus_rise"
Hammer.FOCUS_RISE_FROM, Hammer.FOCUS_RISE_TO = 17, 31
Hammer.FOCUS_RISE_GLOW = { 0, 0.757, 1, 0.75 }
-- the spin in the air (hammer_air_spin_fx): the animators drew a spin smear for it
-- (fx_twirl01_untex, frames 13-30) but no build has its art. Instead, the Windmon's wind
-- spin (fx_windmon_wind_spin: the whirlwind the game puts round you for the Greatsword's
-- flourish, and Boss Passives for Owlitzer's perfect dodge), spawned the game's way
-- (EffectEvents.MakeEventSpawnEffect) riding on the body (followsymbol base_pelvis, which
-- rises from -110 to -650 and comes back down) from frame 18: its 23 drawn frames end at
-- the landing (40); stopped if the finale is cut short (stopatexitstate)
Hammer.AIR_SPIN_FX = "fx_windmon_wind_spin"
Hammer.AIR_SPIN_FRAME = 18
Hammer.AIR_SPIN_SYMBOL = "base_pelvis"
Hammer.AIR_SPIN_SCALE = 1.0
Hammer.SMEAR_FROM, Hammer.SMEAR_TO = 17, 23   -- the anim draws the upswing smear 17-22
Hammer.SMEAR_GLOW = 0.6   -- the tinted arc's glow
-- the painted art is drawn the way the game draws its gold swipe fx
-- (prefabs/autogen/fx/fx_hammer_big_atk1_basic.lua: multcolor 999999, bloom 100,
-- lightoverride 100): darkened to 0.6, full glow of its own colours, unlit
Hammer.SWIPE_MULT, Hammer.SWIPE_BLOOM = 0.6, 1.0
-- by the weapon's fx type (its swipe fx: basic gold, fire red, frost / electric blue,
-- fancy violet); gold = the painted art as it is
Hammer.SMEAR_COLOURS = {
	default = { 1.0, 0.87, 0.47 },
	fire = { 1.0, 0.45, 0.2 },
	frost = { 0.7, 0.9, 1.0 },
	electric = { 0.45, 0.8, 1.0 },
	fancy = { 0.85, 0.6, 1.0 },
}
Hammer.SHEATHE_FRAME = 43 -- the hammer reaches your back
Hammer.DRAW = "weaponmoves_hammer_finale_draw"
Hammer.DRAW_ANIM = "hammer_unsheathe_fast"
Hammer.LANDINGS = { auto = true, back = true, hand = true }

Hammer.notes = 0
function Hammer.Note(msg)
	if Hammer.notes < Hammer.NOTE_LIMIT then
		Hammer.notes = Hammer.notes + 1
		Main.Log(msg)
	end
end

-- the game's hammer helpers and numbers (local to sg_player_hammer.lua),
-- taken from the spin's own states
function Hammer.FindHelpers(states)
	local loop, pst = states.fading_heavy_spin_loop, states.fading_heavy_spin_pst
	if loop == nil or pst == nil or states.fading_heavy_spin_pre == nil then
		return nil, "no spin states"
	end
	local F = Main.FindUpvalue
	local h = {
		ATTACK_DAMAGE_MOD = F(loop.onenter, "ATTACK_DAMAGE_MOD"),
		ATTACK_HITSTUN = F(loop.onenter, "ATTACK_HITSTUN"),
		ATTACK_PUSHBACK = F(loop.onenter, "ATTACK_PUSHBACK"),
		HITSTOP = F(loop.onenter, "REVERSE_HEAVY_SPIN_HITSTOP"),
		HITSTOP_MULT = F(loop.onenter, "HEAVY_SPIN_HITSTOP_MULTIPLIER"),
		DEFAULT_LOOPS = F(loop.onenter, "DEFAULT_ALLOWABLE_HEAVY_SPIN_LOOPS"),
		RestoreLariatFocus = F(loop.onenter, "RestoreLariatFocus"),
		LariatMotorVel = F(loop.onenter, "LariatMotorVel"),
		LARIAT_STATES = F(loop.onexit, "LARIAT_STATES"),
		ClearLariatFocus = F(loop.onexit, "ClearLariatFocus"),
		soundutil = F(loop.onexit, "soundutil"),
		SGPlayerCommon = F(loop.onexit, "SGPlayerCommon"),
	}
	for _, ev in ipairs(loop.timeline or {}) do
		h.PlayLariatSwingSound = h.PlayLariatSwingSound or F(ev.fn, "PlayLariatSwingSound")
		h.combatutil = h.combatutil or F(ev.fn, "combatutil")
	end
	-- the spin sound's own parts (optional: the game's modules otherwise)
	if h.PlayLariatSwingSound ~= nil then
		h.LARIAT_SWING_EVENTS = F(h.PlayLariatSwingSound, "LARIAT_SWING_EVENTS")
		h.fmodtable = F(h.PlayLariatSwingSound, "fmodtable")
		h.WeaponSwingAudio = F(h.PlayLariatSwingSound, "WeaponSwingAudio")
	end
	local hit = loop.events ~= nil and loop.events.hitboxtriggered or nil
	h.OnHitBoxTriggered = type(hit) == "table" and hit[1] ~= nil and hit[1].fn or nil
	for _, key in ipairs({ "ATTACK_DAMAGE_MOD", "ATTACK_HITSTUN", "ATTACK_PUSHBACK", "HITSTOP", "HITSTOP_MULT", "DEFAULT_LOOPS",
		"RestoreLariatFocus", "LariatMotorVel", "LARIAT_STATES", "ClearLariatFocus", "soundutil", "SGPlayerCommon",
		"PlayLariatSwingSound", "combatutil", "OnHitBoxTriggered" }) do
		if h[key] == nil then
			return nil, "the spin's " .. key .. " not found"
		end
	end
	local spin = h.ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN
	if type(spin) ~= "table" or type(h.ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN_FOCUS) ~= "table" then
		return nil, "the spin's damage numbers not found"
	end
	return h
end

-- the spin's hit shapes, by frame (the loop's own: in front 0-5, behind 6-12)
local function Beam(...) return { "PushBeam", ... } end
local function Offset(...) return { "PushOffsetBeam", ... } end
Hammer.HITS = {
	[0] = { Beam(0, 4.5, 1), Offset(0, 3.5, 1.3, -2.3) },
	[1] = { Beam(0, 4.5, 1) },
	[2] = { Beam(0, 4.5, 1.75), Offset(0, 4, 1.5, 1.75) },
	[3] = { Offset(0, 2.5, 3.5, 4), Offset(0, 4, 1.75, 1.75) },
	[4] = { Offset(-1, 1, 3.5, 4) },
	[5] = { Offset(-2, 0.5, 3.5, 4), Offset(0, -3.5, 1.5, 1.75) },
	[6] = { Beam(0, -4.5, 1.5), Offset(0, -3.5, 1.5, 1.75) },
	[7] = { Beam(0, -4.5, 1) },
	[8] = { Beam(0, -4.5, 1), Offset(0, -3.5, -1.5, -1.75) },
	[9] = { Offset(-2, 0, 1.5, -2.5) },
	[10] = { Offset(-1, 1, 1.5, -2.5) },
	[11] = { Offset(-2, 0, 1.5, -2.5) },
	[12] = { Beam(0, -3.5, 1) },
	-- the rising swing: in front, low to high
	[15] = { Beam(0, 4.5, 1.75), Offset(0, 4, 1.5, 1.75) },
	[16] = { Beam(0, 4.5, 1.75), Offset(0, 3, 2, 2) },
	[17] = { Beam(0, 3.5, 1.5) },
}

local function Push(inst, shape)
	local hitbox = inst.components.hitbox
	local hp = rawget(_G, "HitPriority")
	local priority = hp ~= nil and hp.PLAYER_DEFAULT or nil
	hitbox[shape[1]](hitbox, shape[2], shape[3], shape[4], shape[5] ~= nil and shape[5] or priority,
		shape[5] ~= nil and priority or nil)
end

-- where the hammer ends up after the landing: "back" or "hand"
-- (hammer_finale_landing; "auto": the game's own rule for sheathing, i.e. in camp)
function Hammer.Landing(inst, Fns)
	local mode = Main.settings ~= nil and Main.settings.hammer_finale_landing or "auto"
	if mode == "back" or mode == "hand" then
		return mode
	end
	local should = Fns ~= nil and Fns.ShouldSheatheWeapon or nil
	return (should ~= nil and should(inst)) and "back" or "hand"
end

-- the game's sound modules (from the spin's own sound function, else required)
local function Sounds(h)
	local fmod = h.fmodtable or require("defs.sound.fmodtable")
	local swing = h.WeaponSwingAudio or require("defs.sound.weaponswingaudio")
	return fmod, swing
end

-- the upswing smear's colour: the weapon's fx type (the one its swipe fx use);
-- second result: true = the gold swipes (the painted art as it is)
function Hammer.SmearColour(inst)
	local fx_type
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard ~= nil and hoard.GetEquippedItem ~= nil then
		local ok, Equipment = pcall(require, "defs.equipment")
		local item = ok and Equipment ~= nil and Equipment.Slots ~= nil and hoard:GetEquippedItem(Equipment.Slots.WEAPON) or nil
		fx_type = item ~= nil and item.GetFXType ~= nil and item:GetFXType() or nil
	end
	local c = Hammer.SMEAR_COLOURS[fx_type or "default"]
	if c == nil or c == Hammer.SMEAR_COLOURS.default then
		return Hammer.SMEAR_COLOURS.default, true
	end
	return c, false
end

function Hammer.IsFocus(inst)
	local sm = inst.sg.statemem
	return sm.focushit == true or (sm.numtargets or 0) > Hammer.FOCUS_TARGETS
end

-- effects never stop a move: one that fails to spawn is skipped (noted once)
local fx_noted = {}
local function SafeFx(what, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not fx_noted[what] then
		fx_noted[what] = true
		Hammer.Note(("%s skipped: %s"):format(what, tostring(err)))
	end
	return ok
end

function Hammer.FocusOn(inst, Fns)
	if Main.settings.hammer_focus_fx ~= false and Fns.AttachExtraSwipeFx ~= nil and Hammer.IsFocus(inst) then
		if SafeFx("the Focus glint", Fns.AttachExtraSwipeFx, inst, Hammer.FOCUS_FX) then
			inst.sg.statemem.weaponmoves_focus_fx = true
			return true
		end
	end
	return false
end

function Hammer.AirSpin(inst)
	if Main.settings.hammer_air_spin_fx == false then
		return false
	end
	local ok, EffectEvents = pcall(require, "effectevents")
	if not ok or type(EffectEvents) ~= "table" or EffectEvents.MakeEventSpawnEffect == nil then
		return false
	end
	return SafeFx("the air spin's whirlwind", EffectEvents.MakeEventSpawnEffect, inst, {
		fxname = Hammer.AIR_SPIN_FX, ischild = true, followsymbol = Hammer.AIR_SPIN_SYMBOL,
		stopatexitstate = true, scalex = Hammer.AIR_SPIN_SCALE, scalez = Hammer.AIR_SPIN_SCALE,
	})
end

function Hammer.RiseFocusOn(inst)
	if Main.settings.hammer_focus_fx == false or not Hammer.IsFocus(inst) then
		return false
	end
	local as = inst.AnimState
	as:OverrideSymbol(Hammer.TWIRL, Hammer.FOCUS_RISE_BUILD, Hammer.FOCUS_RISE)
	local g = Hammer.FOCUS_RISE_GLOW
	as:SetSymbolBloom(Hammer.TWIRL, g[1], g[2], g[3], g[4])
	if as.SetSymbolLightOverride ~= nil then
		as:SetSymbolLightOverride(Hammer.TWIRL, 1)
	end
	inst.sg.statemem.weaponmoves_rise_focus = true
	return true
end

function Hammer.RiseFocusOff(inst)
	if inst.sg.statemem.weaponmoves_rise_focus then
		inst.sg.statemem.weaponmoves_rise_focus = nil
		local as = inst.AnimState
		as:ClearOverrideSymbol(Hammer.TWIRL)
		as:SetSymbolBloom(Hammer.TWIRL, 0, 0, 0, 0)
		if as.SetSymbolLightOverride ~= nil then
			as:SetSymbolLightOverride(Hammer.TWIRL, 0)
		end
	end
end

function Hammer.FocusOff(inst, Fns)
	if inst.sg.statemem.weaponmoves_focus_fx then
		inst.sg.statemem.weaponmoves_focus_fx = nil
		if Fns.DetachExtraSwipeFx ~= nil then
			SafeFx("the Focus glint's detach", Fns.DetachExtraSwipeFx, inst)
		end
	end
end

-- the rising swing's pushback (nil: the game's)
function Hammer.RisePushback()
	local v = Main.settings ~= nil and Main.settings.hammer_finale_knockback or nil
	if type(v) == "number" and v >= 0 then
		return v
	end
	return nil
end

-- the finale's hits: the game's (OnHitBoxTriggered); in the rising swing its
-- knockdown (and its interrupt knockback) with the rising swing's pushback,
-- set on the attack just before the game's DoKnockdownAttack / DoKnockbackAttack
function Hammer.RiseHit(h, inst, data)
	local push = inst.sg.statemem.weaponmoves_rise_push
	local combat = inst.components ~= nil and inst.components.combat or nil
	if push == nil or type(combat) ~= "table" then
		return h.OnHitBoxTriggered(inst, data)
	end
	local own_down, own_back = rawget(combat, "DoKnockdownAttack"), rawget(combat, "DoKnockbackAttack")
	local down, back = combat.DoKnockdownAttack, combat.DoKnockbackAttack
	if type(down) == "function" then
		combat.DoKnockdownAttack = function(self, attack, ...)
			if attack ~= nil and attack.SetPushback ~= nil then attack:SetPushback(push) end
			return down(self, attack, ...)
		end
	end
	if type(back) == "function" then
		combat.DoKnockbackAttack = function(self, attack, ...)
			if attack ~= nil and attack.SetPushback ~= nil then attack:SetPushback(push) end
			return back(self, attack, ...)
		end
	end
	local ok, err = pcall(h.OnHitBoxTriggered, inst, data)
	combat.DoKnockdownAttack, combat.DoKnockbackAttack = own_down, own_back
	if not ok then
		error(err, 0)
	end
end

-- the finale taking over the game's ending at its frame `from` (the point of no
-- return): its animation from that frame, its timeline as if it had played from
-- frame 0 (the stategraph's ticks in the state, its start tick and its next frame
-- event: stategraph.lua GoToState sets them just before onenter), and what its
-- skipped frames would have set up: the attack open, the spin's slower drift (the
-- ending played its spin sound and swing; no spin glint: the ending has its own)
function Hammer.EnterAt(inst, from, h)
	local FE = rawget(_G, "FrameEvent")
	local sg = inst.sg
	local at = FE(from, function() end).frame -- frame `from` in the timeline's units
	inst.AnimState:SetFrame(from)
	sg.ticksinstate = at
	if type(sg.statestarttick) == "number" then
		sg.statestarttick = sg.statestarttick - at
	end
	local idx = nil
	local timeline = sg.currentstate ~= nil and sg.currentstate.timeline or nil
	for i, ev in ipairs(timeline or {}) do
		if ev.frame >= at then
			idx = i
			break
		end
	end
	sg.timelineindex = idx
	h.combatutil.StartMeleeAttack(inst)
	h.LariatMotorVel(inst, -0.5 * (sg.statemem.speedmult or 1))
	sg.statemem.weaponmoves_from = from
end

function Hammer.MakeState(h)
	local GameState, FE, EH = rawget(_G, "State"), rawget(_G, "FrameEvent"), rawget(_G, "EventHandler")
	local function State(args)
		return GameState(Main.G.State(args, "idle"))
	end
	local Fns = h.SGPlayerCommon.Fns
	local fmod, swing = Sounds(h)
	local function SetNumbers(inst, loops)
		local idx = math.min(loops + 1, h.DEFAULT_LOOPS + 1)
		local sm = inst.sg.statemem
		sm.damage_mod = h.ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN[idx]
		sm.focus_damage_mod = h.ATTACK_DAMAGE_MOD.REVERSE_HEAVY_SPIN_FOCUS[idx]
		sm.hitstun = h.ATTACK_HITSTUN.REVERSE_HEAVY_SPIN[idx]
		sm.pushback = h.ATTACK_PUSHBACK.REVERSE_HEAVY_SPIN[idx]
		sm.hitstoplevel = h.HITSTOP[idx]
		return idx
	end
	-- the spin's swing sound, as the game picks it (PlayLariatSwingSound), but
	-- allowed alongside one still ringing (max_count 2: the game's 1 would let
	-- the last loop's sound take this one's place)
	local function SpinSound(inst, loops)
		local events = h.LARIAT_SWING_EVENTS or {}
		local event = events[loops] or fmod.Event.Hammer_Lariat_Extended
		local params = { max_count = 2 }
		if loops > 1 then
			local allowable = inst.lariat_allowable_heavy_spin_loops or h.DEFAULT_LOOPS
			params.fmodparams = { lariatSwingCount_scaled = (loops - 1) / allowable }
		end
		return swing.PlaySound(inst, event, params)
	end
	-- the swipe trails, the way the game's embellisher attaches them
	-- (eventfuncs.lua attachswipefx / detachswipefx)
	local function Swipe(inst, fxname)
		Fns.AttachSwipeFx(inst, fxname, false, true)
		Fns.AttachPowerSwipeFx(inst, fxname, false, true)
	end
	local function Unswipe(inst)
		Fns.DetachSwipeFx(inst)
		Fns.DetachPowerSwipeFx(inst)
		Fns.DetachSwipeFx(inst, true)
		Fns.DetachPowerSwipeFx(inst, true)
	end
	-- the finale's trails still playing, gone: the attached ones the game's way
	-- (detach + remove), the let-go ones from the state's own stop-on-exit list
	-- (eventfuncs / effectevents StopFxOnStateExit: sg.mem.autogen_stopfx)
	local function EndTrails(inst)
		Fns.DetachSwipeFx(inst, false, true)
		Fns.DetachPowerSwipeFx(inst, false, true)
		Fns.DetachSwipeFx(inst, true, true)
		Fns.DetachPowerSwipeFx(inst, true, true)
		local list = inst.sg.mem.autogen_stopfx
		if list ~= nil then
			local fxs = {}
			for fx in pairs(list) do
				fxs[#fxs + 1] = fx
			end
			for _, fx in ipairs(fxs) do
				if fx.IsValid ~= nil and fx:IsValid() and fx:HasTag("FX") then
					fx:Remove()
				end
			end
		end
	end
	-- its colour and glow (a = alpha, the game's fade: SetMultColor(1, 1, 1, a); the
	-- die-out states are in the art, so the finale draws it at 1)
	local function SmearLook(as, look, a)
		if look.gold then
			local m = Hammer.SWIPE_MULT
			as:SetSymbolMultColor(Hammer.SMEAR, m, m, m, a)
			-- alpha-only bloom (its own colours), as the game's bloomer gives the swipe fx
			as:SetSymbolBloom(Hammer.SMEAR, Hammer.SWIPE_BLOOM * a)
		else
			local c = look.c
			as:SetSymbolMultColor(Hammer.SMEAR, c[1], c[2], c[3], a)
			as:SetSymbolBloom(Hammer.SMEAR, c[1], c[2], c[3], Hammer.SMEAR_GLOW * a)
		end
	end
	local function SmearOn(inst)
		local c, gold = Hammer.SmearColour(inst)
		local as = inst.AnimState
		local look = { c = c, gold = gold }
		as:OverrideSymbol(Hammer.SMEAR, Hammer.SMEAR_BUILD, gold and Hammer.SMEAR or Hammer.SMEAR_TINT)
		SmearLook(as, look, 1)
		if as.SetSymbolLightOverride ~= nil then
			as:SetSymbolLightOverride(Hammer.SMEAR, 1) -- unlit, like the swipe fx (lightoverride 100)
		end
		inst.sg.statemem.weaponmoves_smear = look
	end
	local function SmearOff(inst)
		if inst.sg.statemem.weaponmoves_smear then
			inst.sg.statemem.weaponmoves_smear = nil
			local as = inst.AnimState
			as:ClearOverrideSymbol(Hammer.SMEAR)
			as:SetSymbolMultColor(Hammer.SMEAR, 1, 1, 1, 1)
			if as.SetSymbolLightOverride ~= nil then
				as:SetSymbolLightOverride(Hammer.SMEAR, 0)
			end
			as:SetSymbolBloom(Hammer.SMEAR, 0, 0, 0, 0)
		end
	end

	local timeline = {
		FE(0, function(inst)
			h.LariatMotorVel(inst, -1.5 * inst.sg.statemem.speedmult)
			h.combatutil.StartMeleeAttack(inst)
			SpinSound(inst, (inst.sg.mem.heavyspinloops or 0) + 1)
			Hammer.FocusOn(inst, Fns) -- a Focus spin: the cyan glint swipe for this spin
		end),
		FE(6, function(inst) h.LariatMotorVel(inst, -0.5 * inst.sg.statemem.speedmult) end),
		FE(11, function(inst) inst.Physics:Stop() end),
		FE(13, function(inst) h.combatutil.EndMeleeAttack(inst) end),
		-- the rising swing: a fresh attack (everyone can be hit by it once),
		-- knocks down, 1.15x the spin's damage
		FE(Hammer.RISE_FROM, function(inst)
			local sm = inst.sg.statemem
			sm.knockdownhit = true
			sm.weaponmoves_rise_push = Hammer.RisePushback()
			sm.damage_mod = (sm.damage_mod or 1) * Hammer.RISE_DAMAGE
			sm.focus_damage_mod = (sm.focus_damage_mod or 1) * Hammer.RISE_DAMAGE
			sm.power_fx_attached = nil -- its power swipe again (the game's per-state dedupe)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(30)
			h.combatutil.StartMeleeAttack(inst)
		end),
		FE(Hammer.RISE_FRAME, function(inst)
			-- the golf swing's whoosh (the other low-to-high hammer swing); not its
			-- Focus whoosh (Hammer_Atk_Charge_Focus_Whoosh: a metal clang at the top
			-- of the rise that doesn't belong here)
			swing.PlaySound(inst, fmod.Event.Hammer_Atk_Reverse)
			Hammer.FocusOff(inst, Fns) -- the spin's glint plays on where it is (its sparks linger)
			if inst.sg.statemem.full_spin then
				inst.AnimState:SetSymbolBloom("weapon_back01", 1, 1, 1, 0.3)
			end
		end),
		FE(Hammer.AIR_FROM, function(inst)
			inst.sg:AddStateTag("airborne")
			inst:PushEvent("sfx-jump")
		end),
		FE(18, function(inst) -- Hammer.AIR_SPIN_FRAME, Hammer.RISE_TO
			h.combatutil.EndMeleeAttack(inst)
			inst.sg.statemem.weaponmoves_rise_push = nil
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			inst.sg:RemoveStateTag("nointerrupt")
			Hammer.AirSpin(inst) -- the whirlwind round the spin in the air
		end),
		FE(Hammer.AIR_TO, function(inst)
			inst.sg:RemoveStateTag("airborne")
			inst:PushEvent("sfx-land")
		end),
		FE(Hammer.DODGE_FRAME, Fns.SetCanDodge),
		-- the hammer on your back: the game's sheathe sound; "back" makes it the
		-- game's sheathed state from here (moving off now keeps it there; the
		-- next attack draws it, as in camp)
		FE(Hammer.SHEATHE_FRAME, function(inst)
			inst:PushEvent("sfx-sheath_hammer")
			local landing = Hammer.Landing(inst, Fns)
			inst.sg.statemem.landing = landing
			if landing == "back" and Fns.SetWeaponSheathed ~= nil then
				Fns.SetWeaponSheathed(inst, true)
			end
		end),
		FE(Hammer.FREE_FRAME, function(inst)
			Fns.SetCanAttackOrAbility(inst)
			Fns.SetCanMove(inst)
		end),
	}
	for frame, shapes in pairs(Hammer.HITS) do
		timeline[#timeline + 1] = FE(frame, function(inst)
			for _, shape in ipairs(shapes) do
				Push(inst, shape)
			end
		end)
	end
	for frame, fxname in pairs(Hammer.SWIPES) do
		timeline[#timeline + 1] = FE(frame, function(inst) Swipe(inst, fxname) end)
	end
	for _, frame in ipairs(Hammer.UNSWIPES) do
		timeline[#timeline + 1] = FE(frame, Unswipe)
	end
	timeline[#timeline + 1] = FE(Hammer.SMEAR_FROM, function(inst)
		EndTrails(inst)
		SmearOn(inst)
	end)
	timeline[#timeline + 1] = FE(Hammer.SMEAR_TO, SmearOff)
	-- a Focus rise: the cyan overlay and its flecks (Hammer.RiseFocusOn)
	timeline[#timeline + 1] = FE(Hammer.FOCUS_RISE_FROM, function(inst)
		SafeFx("the rise's Focus overlay", Hammer.RiseFocusOn, inst)
	end)
	timeline[#timeline + 1] = FE(Hammer.FOCUS_RISE_TO, Hammer.RiseFocusOff)
	table.sort(timeline, function(a, b) return a.frame < b.frame end)

	return State({
		name = Hammer.FINALE,
		tags = { "attack", "busy", "nointerrupt", "heavy_attack" },
		onenter = function(inst, params)
			inst.sg.mem[Hammer.QUEUED] = nil
			inst.AnimState:PlayAnimation(Hammer.ANIM)
			inst.sg.mem.attack_type = "heavy_attack"
			local sm = inst.sg.statemem
			local speedmult = params
			if type(params) == "table" then
				speedmult = params.speedmult
				if params.numtargets ~= nil then
					inst.sg.mem.lariat_numtargets = params.numtargets
				end
				if params.focushit then
					inst.sg.mem.lariat_focushit = true
				end
			end
			sm.speedmult = type(speedmult) == "number" and speedmult or 1
			sm.attacking = true -- the spin's own exit leaves the hit delay running for us
			sm.numtargets = 0
			h.RestoreLariatFocus(inst)
			local loops = inst.sg.mem.heavyspinloops or 0
			SetNumbers(inst, loops)
			local allowable = inst.lariat_allowable_heavy_spin_loops or h.DEFAULT_LOOPS
			sm.full_spin = loops >= allowable
			if loops >= h.DEFAULT_LOOPS then
				sm.focushit = true -- the game's own spin ending: a Focus hit at full length
			end
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(6 + sm.hitstoplevel * h.HITSTOP_MULT)
			sm.attack_id = "LARIAT"
			local from = type(params) == "table" and tonumber(params.from_frame) or nil
			if from ~= nil and from > 0 then
				Main.G.Call("hammer finale from the ending's frame", Hammer.EnterAt, inst, from, h)
			end
			Hammer.Note(("Hammer spin finale (after %d spins%s%s)"):format(loops, sm.focushit and ", Focus" or "",
				sm.weaponmoves_from ~= nil and (", from the ending's frame " .. sm.weaponmoves_from) or ""))
		end,
		timeline = timeline,
		events = {
			EH("hitboxtriggered", function(inst, data) return Hammer.RiseHit(h, inst, data) end),
			EH("animover", function(inst)
				local landing = inst.sg.statemem.landing or Hammer.Landing(inst, Fns)
				if landing == "hand" then
					inst.sg:GoToState(Hammer.DRAW)
				else
					inst.sg:GoToState("idle")
				end
			end),
		},
		onexit = function(inst)
			inst.Physics:Stop()
			Unswipe(inst)
			Hammer.FocusOff(inst, Fns)
			SmearOff(inst)
			Hammer.RiseFocusOff(inst)
			inst.AnimState:SetSymbolBloom("weapon_back01", 0, 0, 0, 0)
			h.soundutil.KillSound(inst, inst.sg.mem.lariat_extended_LP)
			inst.sg.mem.lariat_extended_LP = nil
			h.ClearLariatFocus(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	})
end

-- "hand": the hammer comes off your back into your hands (the game's own
-- hammer_unsheathe_fast, 12 frames, its unsheathe sound from the anim's tag);
-- any move, attack, skill or dodge cuts it short, as the finale's last frames
function Hammer.MakeDrawState(h)
	local GameState, FE, EH = rawget(_G, "State"), rawget(_G, "FrameEvent"), rawget(_G, "EventHandler")
	local Fns = h.SGPlayerCommon.Fns
	return GameState(Main.G.State({
		name = Hammer.DRAW,
		tags = { "busy" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation(Hammer.DRAW_ANIM)
		end,
		timeline = {
			FE(0, Fns.SetCanAttackOrAbility),
			FE(0, Fns.SetCanMove),
			FE(0, Fns.SetCanDodge),
		},
		events = {
			EH("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}, "idle"))
end

-- Is the player in this state? By name: the game gives each kind of entity its
-- own deep copy of a stategraph (entityscript.lua LoadStateGraph:
-- deepcopy(sg) per prefab), so the state a player is in is a copy of the one
-- changed here, never the same table. (0.2.3 compared the tables: B in the spin
-- never matched, so the finale never came out in the game.)
local function InState(inst, name)
	local cur = inst.sg ~= nil and inst.sg.currentstate or nil
	return cur ~= nil and cur.name == name
end
Hammer.InState = InState

-- B (the skill button itself: not Skill Slots' other slot buttons)
local function IsB(data)
	return data ~= nil and data.control == "skill" and (data.skillslots_slot == nil or data.skillslots_slot == "B")
end
Hammer.IsB = IsB

-- the last frame B starts the finale in (nil: any)
local function LastFrame(inst, state_name)
	local allowed = Hammer.FROM[state_name]
	if allowed == "branch" then
		return Hammer.PST_BRANCH - 1
	end
	return type(allowed) == "number" and allowed or nil
end

local function Frame(inst)
	local ticks = inst.sg.GetTicksInState ~= nil and inst.sg:GetTicksInState() or 0
	return ticks / (rawget(_G, "ANIM_FRAMES") or 2)
end

-- what B does here: "wait" (the finale when this spin comes round, or at the
-- ending's frame 8), "now", "late" (the ending past frame 8, its recovery still
-- closed: used up, nothing) or nil (the recovery open: the game's)
local function Decide(inst, state_name)
	local allowed = Hammer.FROM[state_name]
	if allowed == true then
		return "wait"
	end
	if state_name == Hammer.PST then
		local f = Frame(inst)
		if f < Hammer.PST_BRANCH then
			return "wait"
		end
		local open = Hammer.PST_OPEN[inst.sg.statemem.recovery_tier or 0] or Hammer.PST_OPEN[0]
		return f < open and "late" or nil
	end
	local last = LastFrame(inst, state_name)
	return (last ~= nil and Frame(inst) < last + 1) and "now" or nil
end
Hammer.Decide = Decide

-- B in the game's press queue (pressed in the last 6 frames, not used yet)
local function QueuedB(inst)
	local pc = inst.components.playercontroller
	local data = pc ~= nil and pc.GetQueuedControl ~= nil and pc:GetQueuedControl("skill") or nil
	return IsB(data) and data or nil
end
Hammer.QueuedB = QueuedB

local function UsePress(inst)
	local pc = inst.components.playercontroller
	if pc ~= nil and pc.FlushControlQueue ~= nil then
		pc:FlushControlQueue() -- the B press is used up (no skill after)
	end
end

local function Finale(inst, speedmult, from_frame)
	UsePress(inst)
	inst.sg.mem[Hammer.QUEUED] = nil
	-- the ending's exit clears the spin's Focus count: carried over here
	local mem = inst.sg.mem
	inst.sg:GoToState(Hammer.FINALE, { speedmult = speedmult or inst.sg.statemem.speedmult,
		numtargets = mem.lariat_numtargets, focushit = mem.lariat_focushit, from_frame = from_frame })
end
Hammer.Finale = Finale

-- B now, the finale when the spin comes round
local function Wait(inst, state_name)
	UsePress(inst)
	if not inst.sg.mem[Hammer.QUEUED] then
		inst.sg.mem[Hammer.QUEUED] = true
		Hammer.Note(("B in %s frame %.0f: the finale when this spin comes round"):format(state_name, Frame(inst)))
	end
end
Hammer.Wait = Wait

-- a frame event added to a game state (after its own on the same frame, or
-- before them: first)
local function AddFrameEvent(st, ev, first)
	st.timeline = st.timeline or {}
	ev.idx = first and -1 or #st.timeline + 1
	st.timeline[#st.timeline + 1] = ev
	table.sort(st.timeline, function(a, b)
		local ta, tb = a.time or a.frame, b.time or b.frame
		if ta ~= tb then
			return ta < tb
		end
		return (a.idx or 0) < (b.idx or 0)
	end)
end

-- B in the hammer's other heavy attacks (the golf swing, the jump slam...):
-- nothing changes, a note in the log says the finale is from the spin
Hammer.HINTS = 3
Hammer.hints = 0
local function HintOther(inst, name)
	if Hammer.hints < Hammer.HINTS then
		Hammer.hints = Hammer.hints + 1
		Hammer.Note(("B in %s: no finale there, it's from the spin (%s)"):format(name, Hammer.HOW))
	end
end

-- the sg_player_hammer post-init (registered from modmain)
function Hammer.Install(sg)
	local states = type(sg) == "table" and type(sg.states) == "table" and sg.states or nil
	if states == nil then
		error("no states", 0)
	end
	if states[Hammer.FINALE] ~= nil then
		return "Hammer: spin finale already in"
	end
	local h, why = Hammer.FindHelpers(states)
	if h == nil then
		error(why, 0)
	end
	local EH = rawget(_G, "EventHandler")
	states[Hammer.FINALE] = Hammer.MakeState(h)
	states[Hammer.DRAW] = Hammer.MakeDrawState(h)
	-- the spin's exit keeps its sound and Focus count for the finale (it treats
	-- it as part of the spin, like its own loop)
	h.LARIAT_STATES[Hammer.FINALE] = true
	-- A state handler that doesn't use the press must keep the game's own
	-- order: with no handler of the state's own, the stategraph's handlers run
	-- (return true); with one, its answer stands (return nothing).
	local function Passes(st)
		local own = st.events ~= nil and st.events.controlevent or nil
		return own == nil or next(own) == nil
	end
	for name in pairs(Hammer.FROM) do
		local st = states[name]
		local pass = Passes(st) or nil
		st:AddEvents({ EH("controlevent", function(inst, data)
			if IsB(data) and InState(inst, name) then
				local ok, what = Main.G.Call("hammer finale check", Decide, inst, name)
				if ok and what == "now" then
					Finale(inst)
					return
				elseif ok and what == "wait" then
					Wait(inst, name)
					return
				elseif ok and what == "late" then
					UsePress(inst)
					Hammer.Note(("B in the spin's ending at frame %.0f: past the point of no return (frame %d), no finale; used up (no skill)"):format(
						Frame(inst), Hammer.PST_BRANCH))
					return
				end
				if ok then
					Hammer.Note(("B too late in the spin's ending (frame %.0f; up to %s): the game's (its skill)"):format(
						Frame(inst), tostring(LastFrame(inst, name))))
				end
			end
			return pass -- anything else: the game's own handling (the dodge)
		end) })
	end
	local FE = rawget(_G, "FrameEvent")
	-- the spin comes round: the game goes into its next loop or its ending
	-- (from the wind-up's or a loop's end, or Y let go on a loop's first frames):
	-- a waiting B takes it to the finale instead, before that state starts
	for _, name in ipairs({ Hammer.LOOP, Hammer.PST }) do
		local st = states[name]
		local enter = st.onenter
		st.onenter = function(inst, speedmult, ...)
			if inst.sg.mem[Hammer.QUEUED] then
				local ok = Main.G.Call("hammer finale at the spin's end", Finale, inst, speedmult)
				if ok and InState(inst, Hammer.FINALE) then
					return
				end
				inst.sg.mem[Hammer.QUEUED] = nil
			end
			local r = enter(inst, speedmult, ...)
			-- a Focus loop: the cyan glint swipe the game made for it
			if name == Hammer.LOOP and InState(inst, Hammer.LOOP) then
				Main.G.Call("hammer Focus glint", Hammer.FocusOn, inst, h.SGPlayerCommon.Fns)
			end
			return r
		end
	end
	local loop = states[Hammer.LOOP]
	local loop_exit = loop.onexit
	loop.onexit = function(inst, ...)
		Main.G.Call("hammer Focus glint off", Hammer.FocusOff, inst, h.SGPlayerCommon.Fns)
		return loop_exit(inst, ...)
	end
	-- B in the ending before its frame 8: the finale takes over there, from its
	-- own frame 8 (before the ending's own frame-8 events: its swing behind)
	AddFrameEvent(states[Hammer.PST], FE(Hammer.PST_BRANCH, function(inst)
		Main.G.Call("hammer finale at the ending's frame 8", function()
			if inst.sg.mem[Hammer.QUEUED] and InState(inst, Hammer.PST) then
				Finale(inst, nil, Hammer.PST_BRANCH)
			end
		end)
	end), true)
	-- the wind-up starts a new spin: no B waiting from an earlier one (a dodge
	-- out of the spin leaves it); B pressed just before the spin (still in the
	-- game's press queue) waits for the wind-up to come round
	local first = states[Hammer.FIRST]
	local first_enter = first.onenter
	first.onenter = function(inst, ...)
		inst.sg.mem[Hammer.QUEUED] = nil
		return first_enter(inst, ...)
	end
	AddFrameEvent(first, FE(Hammer.QUEUE_FRAME, function(inst)
		Main.G.Call("hammer finale queued B", function()
			if InState(inst, Hammer.FIRST) and QueuedB(inst) ~= nil then
				Wait(inst, Hammer.FIRST)
			end
		end)
	end))
	-- the log note for B in the hammer's other heavy attacks
	local hinted = 0
	for name, st in pairs(states) do
		if Hammer.FROM[name] == nil and name ~= Hammer.FINALE and name ~= Hammer.DRAW and type(st) == "table" and type(st.tags) == "table"
			and st.AddEvents ~= nil then
			local heavy = false
			for _, tag in ipairs(st.tags) do
				heavy = heavy or tag == "heavy_attack"
			end
			if heavy then
				local pass = Passes(st) or nil
				st:AddEvents({ EH("controlevent", function(inst, data)
					if Hammer.hints < Hammer.HINTS and IsB(data) and InState(inst, name) then
						Main.G.Call("hammer finale hint", HintOther, inst, name)
					end
					return pass
				end) })
				hinted = hinted + 1
			end
		end
	end
	return ("Hammer: spin finale on (B during the spin: %s; %d other heavy attacks say so in the log)"):format(Hammer.HOW, hinted)
		.. (Main.G.on and "; guarded" or "")
end

return Hammer
