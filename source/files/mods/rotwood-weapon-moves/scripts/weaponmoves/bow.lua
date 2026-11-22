-- Weapon Moves, Bow: the leap shot.
--
-- The bow's animation files have a finished rolling shot the game never plays:
-- bow_roll_light_atk_pre (4 frames) / _hold (10) / _pst (14). Its first frames
-- are the roll's tucked mid-roll pose (the first frame cuts the roll sound),
-- then it springs up while drawing, shoots level from the top of the jump and
-- lands on frame 7 of the last part (a landing sound there). Its muzzle flash
-- for every bow (basic / ice / electric) is wired like the kneel shot's. The
-- kneel shot replaced it.
--
-- X in the middle of a roll (roll_pre / roll_loop, and the light-weight dash)
-- now goes to it. X at the roll's landing stays the kneel shot; X with the
-- stick back stays the back-flip shot. Heavy weight's hop takes its attacks at
-- the landing (the game's way), so it keeps the kneel shot.
--
-- Built from the game's own bow pieces (its arrow, shot sounds, charge levels
-- and cancel windows, copied from the back-flip shot), so powers that change
-- bow shots (Volley Shot, Skillshot, primed arrows, Hypershot...) apply to it
-- like to any light attack. Charge levels: let go before frame 5 quick, 5
-- medium, 10 Focus (goes through enemies), 15 full charge, 20 fires by itself.
-- In the air (from the pre's frame 2 to the landing) ground attacks pass under.
local Main = require "weaponmoves.main"
local SGCommon = require "stategraphs.sg_common"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local Bow = {}

Bow.PRE = "weaponmoves_bow_leap_pre"
Bow.HOLD = "weaponmoves_bow_leap_hold"
Bow.SHOOT = "weaponmoves_bow_leap_shoot"
Bow.ANIM_PRE = "bow_roll_light_atk_pre"
Bow.ANIM_HOLD = "bow_roll_light_atk_hold"
Bow.ANIM_SHOOT = "bow_roll_light_atk_pst"

-- the roll states that are mid-roll (the leap starts from the roll's tucked pose)
Bow.MID_ROLL = { roll_pre = true, roll_loop = true, roll_light = true }
-- the game's rolling-shot entries and the momentum each passes on (sg_player_bow.lua)
Bow.REDIRECT = { rolling_light_attack_very_far = 1.5, rolling_light_attack_far = 1.25, rolling_light_attack_med = 0.8 }
Bow.REDIRECT_ORDER = { "rolling_light_attack_very_far", "rolling_light_attack_far", "rolling_light_attack_med" }
-- charge levels by frame held, as for every bow shot (HOLD_FRAMES_* in sg_player_bow.lua)
Bow.HOLD_FRAMES = { WEAK = 0, MEDIUM = 5, FOCUS = 10, STRONG = 15, RELEASE = 20 }

-- The game puts each bow shot's arrow at the bow (standing 1.6, kneeling 1.4,
-- back-flip 2.0, jump shot 3.35). The leap's arrow leaves from the bow too:
-- 2.65 up (the bow's muzzle is 334 px up at the end of the draw, 355 px on
-- the release frame; the standing shot's is 195 px for 1.6; 2.9 looked a bit
-- high in game, 2.0 too low), and flies straight and level from there, like
-- every other level shot.
-- An arrow higher than 1.5 only hits enemies about as tall as it is (the
-- arrow's own rule), so the leap's arrows are checked for hits as if at 1.5
-- (HIT_Y): they hit everything a standing shot hits.
-- (0.1.3: 2.9; 0.1.2 flew at 2.0, under the bow; 0.1.0 - 0.1.1 left at 2.65 and dropped
-- to 1.45 over 3 ticks. Bow.DIP = true brings the drop back; HIT_Y = nil
-- uses the arrow's real height for hits.)
Bow.ARROW_Y = 2.65
Bow.HIT_Y = 1.5
Bow.DIP = false
Bow.DIP_TICKS = 3
Bow.DIP_TO = 1.45
Bow.LEVEL_GRAVITY = 0.01 -- a level arrow's own drop each tick (player_bow_projectile.lua)
Bow.DIP_WINDOW_TICKS = 20 -- extra arrows from powers come up to 8 animation frames after the shot

-- forward speed by frame, times the roll's momentum (0 = stop)
Bow.SPEED_PRE = { { 0, 5.5 }, { 2, 5 } }
Bow.SPEED_HOLD = { { 0, 4.5 }, { 3, 4 }, { 6, 3 }, { 8, 2 }, { 10, 1 }, { 12, 0.5 }, { 14, 0 } }
Bow.SPEED_SHOOT = { { 0, 2 }, { 3, 1.5 }, { 5, 1 }, { 7, 0 } }
Bow.AIR_FRAME = 2 -- the pre's frame where the feet leave the ground
Bow.LAND_FRAME = 7 -- the shot's frame where the feet touch down
Bow.NOTE_LIMIT = 20

Bow.notes = 0
function Bow.Note(msg)
	if Bow.notes < Bow.NOTE_LIMIT then
		Bow.notes = Bow.notes + 1
		Main.Log(msg)
	end
end

-- the back-flip shot's states: the leap copies their charge and cancel frames
-- and takes the game's bow helpers from them
Bow.BACKFLIP = { pre = "fading_light_attack_pre", hold = "fading_light_attack_hold", shoot = "fading_light_attack_shoot" }

-- the game's bow helpers (local functions of sg_player_bow.lua)
function Bow.FindHelpers(states)
	local pre, hold, shoot = states[Bow.BACKFLIP.pre], states[Bow.BACKFLIP.hold], states[Bow.BACKFLIP.shoot]
	if pre == nil or hold == nil or shoot == nil then
		return nil, "no back-flip shot states"
	end
	local h = {
		CreateArrow = Main.FindUpvalue(shoot.onenter, "CreateArrow"),
		PlayShotSound = Main.FindUpvalue(shoot.onenter, "PlayShotSound"),
		DoLightHoldOnUpdate = Main.FindUpvalue(hold.onupdate, "DoLightHoldOnUpdate"),
		StopHoldSound = Main.FindUpvalue(hold.onexit, "StopHoldSound"),
		StopHoldSoundUnlessHeadingToState = Main.FindUpvalue(pre.onexit, "StopHoldSoundUnlessHeadingToState"),
		SGPlayerCommon = Main.FindUpvalue(hold.onexit, "SGPlayerCommon"),
	}
	for _, ev in ipairs(hold.timeline or {}) do
		h.AllowLightShoot = h.AllowLightShoot or Main.FindUpvalue(ev.fn, "AllowLightShoot")
	end
	for _, name in ipairs({ "CreateArrow", "PlayShotSound", "DoLightHoldOnUpdate", "AllowLightShoot", "StopHoldSound", "StopHoldSoundUnlessHeadingToState" }) do
		if type(h[name]) ~= "function" then
			return nil, name .. " not found"
		end
	end
	if type(h.SGPlayerCommon) ~= "table" or type(h.SGPlayerCommon.Fns) ~= "table" then
		return nil, "SGPlayerCommon not found"
	end
	for _, name in ipairs(Bow.REDIRECT_ORDER) do
		if states[name] == nil or type(states[name].onenter) ~= "function" then
			return nil, "no " .. name .. " state"
		end
	end
	for _, name in ipairs({ "State", "FrameEvent", "EventHandler" }) do
		if rawget(_G, name) == nil then
			return nil, name .. " not found"
		end
	end
	return h
end

local function Speed(inst)
	return inst.sg.mem.weaponmoves_leap_speed or 1
end

local function Move(inst, v)
	if v == 0 then
		inst.Physics:Stop()
	else
		SGCommon.Fns.SetMotorVelScaled(inst, v * Speed(inst))
	end
end

-- (Bow.DIP = true) the leap's arrows: from the bow, down to normal arrow height
function Bow.Dip(arrow)
	if arrow == nil or (arrow.IsValid ~= nil and not arrow:IsValid()) or arrow.weaponmoves_dipped
		or arrow.gravity ~= Bow.LEVEL_GRAVITY then
		return false -- not a level arrow (a jump shot's falls on its own)
	end
	local y = arrow:GetPosition().y
	if y < Bow.DIP_TO + 0.5 then
		return false
	end
	arrow.weaponmoves_dipped = true
	local step = (y - Bow.DIP_TO) / Bow.DIP_TICKS
	arrow.gravity = step
	arrow:DoTaskInTicks(Bow.DIP_TICKS, function()
		if (arrow.IsValid == nil or arrow:IsValid()) and arrow.gravity == step then
			arrow.gravity = Bow.LEVEL_GRAVITY
		end
	end)
	return true
end

-- the leap's arrows: hits checked as if at HIT_Y (the arrow itself stays at
-- the bow's height; only the game's hit check sees the lower height). The
-- game puts the hit spark at the height it read for the check, so the spark
-- is put back at the arrow's real height.
function Bow.HitLow(arrow)
	if Bow.HIT_Y == nil or type(arrow) ~= "table" or rawget(arrow, "weaponmoves_hitlow") then
		return false
	end
	local push = arrow.PushEvent
	if type(push) ~= "function" then
		return false
	end
	rawset(arrow, "weaponmoves_hitlow", true)
	local combat = type(arrow.components) == "table" and arrow.components.combat or nil
	local spawn = type(combat) == "table" and combat.SpawnHitFxForPlayerAttack or nil
	if type(spawn) == "function" and rawget(combat, "SpawnHitFxForPlayerAttack") == nil then
		rawset(combat, "SpawnHitFxForPlayerAttack", function(c, attack, base_fx, victim, source, x_offset, y_offset, ...)
			local real_y = rawget(arrow, "weaponmoves_real_y")
			if source == arrow and real_y ~= nil and type(y_offset) == "number" then
				y_offset = real_y -- the spark where the arrow is
			end
			return spawn(c, attack, base_fx, victim, source, x_offset, y_offset, ...)
		end)
	end
	rawset(arrow, "PushEvent", function(self, event, ...)
		if event ~= "hitboxtriggered" or Bow.HIT_Y == nil then
			return push(self, event, ...)
		end
		local own = rawget(self, "GetPosition")
		local getpos = self.GetPosition
		local here = getpos(self)
		if type(here) ~= "table" or type(here.y) ~= "number" or here.y <= Bow.HIT_Y then
			return push(self, event, ...) -- already at normal height
		end
		rawset(self, "weaponmoves_real_y", here.y)
		rawset(self, "GetPosition", function(s, ...)
			local p = getpos(s, ...)
			if type(p) == "table" and type(p.y) == "number" and p.y > Bow.HIT_Y then
				p.y = Bow.HIT_Y
			end
			return p
		end)
		local results = table.pack(pcall(push, self, event, ...))
		rawset(self, "GetPosition", own)
		rawset(self, "weaponmoves_real_y", nil)
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end)
	return true
end

function Bow.OnLaunched(inst, arrows)
	local mem = inst.sg ~= nil and inst.sg.mem or nil
	local until_tick = mem ~= nil and mem.weaponmoves_leap_dip_until or nil
	if until_tick == nil or GetTick() > until_tick or type(arrows) ~= "table" then
		return
	end
	for _, arrow in ipairs(arrows) do
		if Bow.DIP then
			Bow.Dip(arrow)
		else
			Bow.HitLow(arrow)
		end
	end
end

function Bow.WatchArrows(inst)
	inst.sg.mem.weaponmoves_leap_dip_until = GetTick() + Bow.DIP_WINDOW_TICKS
	if not rawget(inst, "weaponmoves_watching_arrows") then
		rawset(inst, "weaponmoves_watching_arrows", true)
		inst:ListenForEvent("projectile_launched", Bow.OnLaunched)
	end
end

local function Sorted(timeline)
	for i, ev in ipairs(timeline) do
		ev.weaponmoves_order = i
	end
	table.sort(timeline, function(a, b)
		if a.frame ~= b.frame then
			return a.frame < b.frame
		end
		return a.weaponmoves_order < b.weaponmoves_order
	end)
	return timeline
end

local function AddSpeeds(FE, timeline, list)
	for _, step in ipairs(list) do
		local v = step[2]
		timeline[#timeline + 1] = FE(step[1], function(inst) Move(inst, v) end)
	end
end

function Bow.MakeStates(h)
	local GameState, FE, EH = rawget(_G, "State"), rawget(_G, "FrameEvent"), rawget(_G, "EventHandler")
	-- an error inside one of these states: logged, and you're back to idle
	local function State(args)
		return GameState(Main.G.State(args, "idle"))
	end
	local Fns = h.SGPlayerCommon.Fns
	local HF = Bow.HOLD_FRAMES

	local pre_timeline = {
		FE(Bow.AIR_FRAME, function(inst)
			inst.sg:AddStateTag("airborne")
			inst:PushEvent("sfx-jump")
		end),
	}
	AddSpeeds(FE, pre_timeline, Bow.SPEED_PRE)
	local pre = State({
		name = Bow.PRE,
		tags = { "attack", "busy", "light_attack" },
		onenter = function(inst, speedmult)
			inst:PushEvent("attack_state_start")
			inst.sg.mem.weaponmoves_leap_speed = type(speedmult) == "number" and speedmult or 1
			inst.AnimState:PlayAnimation(Bow.ANIM_PRE)
			Move(inst, Bow.SPEED_PRE[1][2])
			inst.sg.mem.bow_hold_sound_LP = soundutil.PlayCodeSound(inst, fmodtable.Event.Bow_Hold_Light_LP, {
				name = "bow_draw_LP",
				is_autostop = true,
			})
			Fns.SetAirborneHighAttackHurtboxSize(inst)
		end,
		timeline = Sorted(pre_timeline),
		events = {
			EH("animover", function(inst)
				local tags = rawget(_G, "POWER_TAGS")
				local no_charge = tags ~= nil and tags.BOW_CANNOT_CHARGE_LIGHT_SHOTS or nil
				if no_charge ~= nil and inst:HasTag(no_charge) then
					inst.sg:GoToState(Bow.SHOOT, "WEAK")
				else
					inst.sg:GoToState(Bow.HOLD)
				end
			end),
		},
		onexit = function(inst, currentstate, nextstate)
			inst.Physics:Stop()
			h.StopHoldSoundUnlessHeadingToState(inst, nextstate, Bow.HOLD)
			Fns.UnSetAirborneHighAttackHurtboxSize(inst)
		end,
	})

	local hold_timeline = {
		FE(2, function(inst) h.AllowLightShoot(inst, Bow.SHOOT) end),
		FE(HF.FOCUS - 1, function(inst)
			-- the draw sound's Focus cue (a frame early, for reaction time)
			if inst.sg.mem.bow_hold_sound_LP then
				soundutil.SetInstanceParameter(inst, inst.sg.mem.bow_hold_sound_LP, "bow_LP_timing", 2)
			end
		end),
		FE(HF.WEAK, function(inst) inst.sg.statemem.shot_strength = "WEAK" end),
		FE(HF.MEDIUM, function(inst) inst.sg.statemem.shot_strength = "MEDIUM" end),
		FE(HF.FOCUS, function(inst) inst.sg.statemem.shot_strength = "FOCUS" end),
		FE(HF.STRONG, function(inst) inst.sg.statemem.shot_strength = "STRONG" end),
		FE(HF.RELEASE, function(inst) inst.sg.statemem.must_release = true end),
	}
	AddSpeeds(FE, hold_timeline, Bow.SPEED_HOLD)
	local hold = State({
		name = Bow.HOLD,
		tags = { "attack", "busy", "airborne", "light_attack" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation(Bow.ANIM_HOLD) -- 10 frames, then stays at the top of the jump while charging
			Move(inst, Bow.SPEED_HOLD[1][2])
			if not inst.sg.mem.bow_hold_sound_LP then
				inst.sg.mem.bow_hold_sound_LP = soundutil.PlayCodeSound(inst, fmodtable.Event.Bow_Hold_Light_LP, {
					name = "bow_draw_LP",
					is_autostop = true,
					stopatexitstate = true,
				})
			end
			-- like the back-flip shot: the next standing shot starts its animations from the first set
			inst.sg.mem.lightfocus_anim_idx = 1
			inst.sg.mem.lightfocus_lastshot = false
			Fns.SetAirborneHighAttackHurtboxSize(inst)
		end,
		onupdate = function(inst)
			-- let go (or held too long): shoot
			h.DoLightHoldOnUpdate(inst, Bow.SHOOT)
		end,
		timeline = Sorted(hold_timeline),
		onexit = function(inst)
			inst.Physics:Stop()
			h.StopHoldSound(inst)
			Fns.UnSetAirborneHighAttackHurtboxSize(inst)
		end,
	})

	local function Combos(inst)
		inst.sg.statemem.lightcombostate = "light_attack_pre"
		inst.sg.statemem.heavycombostate = inst.sg.mem.shot_strength == "FOCUS" and "heavy_attack_hold" or "default_heavy_attack"
		-- light first; if no light was pressed, heavy
		if not Fns.TryQueuedAction(inst, "lightattack") then
			Fns.TryQueuedAction(inst, "heavyattack")
		end
	end
	local shoot_timeline = {
		FE(1, function(inst)
			-- Hypershot: rapid fire carries on
			if inst.sg.mem.hypershot_active then
				inst.sg.statemem.lightcombostate = "light_attack_pre"
				Fns.TryQueuedAction(inst, "lightattack")
			end
		end),
		-- the follow-up window: sooner after a Focus shot (as for every bow shot)
		FE(6, function(inst) if inst.sg.mem.shot_strength == "FOCUS" then Combos(inst) end end),
		FE(8, function(inst) if inst.sg.mem.shot_strength ~= "FOCUS" then Combos(inst) end end),
		FE(3, Fns.SetCanDodge),
		FE(6, Fns.SetCanSkill),
		FE(9, Fns.SetCanMove), -- after the follow-up window
		FE(Bow.LAND_FRAME, function(inst) inst.sg:RemoveStateTag("airborne") end),
	}
	AddSpeeds(FE, shoot_timeline, Bow.SPEED_SHOOT)
	local shoot = State({
		name = Bow.SHOOT,
		tags = { "attack", "busy", "airborne", "light_attack" },
		onenter = function(inst, shot_strength)
			shot_strength = type(shot_strength) == "string" and shot_strength or "WEAK"
			inst.AnimState:PlayAnimation(Bow.ANIM_SHOOT)
			inst.sg.mem.attack_type = "light_attack"
			inst.sg.mem.shot_strength = shot_strength
			inst.sg.mem.attack_id = "LIGHT_ATTACK_" .. shot_strength
			inst.sg.statemem.projectile_y_offset = Bow.ARROW_Y
			if Bow.DIP or Bow.HIT_Y ~= nil then
				Bow.WatchArrows(inst) -- its arrows (and powers' extra ones)
			end
			h.CreateArrow(inst)
			h.PlayShotSound(inst, "LIGHT", shot_strength)
			Move(inst, Bow.SPEED_SHOOT[1][2])
			Bow.Note(("Bow leap shot (%s, momentum x%g)"):format(shot_strength, Speed(inst)))
		end,
		timeline = Sorted(shoot_timeline),
		events = {
			EH("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
		onexit = function(inst)
			inst.Physics:Stop()
		end,
	})
	return pre, hold, shoot
end

-- coming straight from the middle of a roll?
local function MidRoll(inst)
	local last = inst.sg ~= nil and inst.sg.laststate or nil
	return last ~= nil and Bow.MID_ROLL[last.name] == true
end

-- the sg_player_bow post-init (registered from modmain)
function Bow.Install(sg)
	local states = type(sg) == "table" and type(sg.states) == "table" and sg.states or nil
	if states == nil then
		error("no states", 0)
	end
	if states[Bow.PRE] ~= nil then
		return "Bow: leap shot already in"
	end
	local h, why = Bow.FindHelpers(states)
	if h == nil then
		error(why, 0)
	end
	states[Bow.PRE], states[Bow.HOLD], states[Bow.SHOOT] = Bow.MakeStates(h)
	-- X mid-roll: the game sends it to these (the momentum each passes on);
	-- coming straight from a mid-roll state, the leap instead
	for _, name in ipairs(Bow.REDIRECT_ORDER) do
		local speed = Bow.REDIRECT[name]
		local st = states[name]
		local orig = st.onenter
		st.onenter = function(inst, ...)
			local ok, leap = Main.G.Call("bow mid-roll check", MidRoll, inst)
			if ok and leap then
				inst.sg:GoToState(Bow.PRE, speed)
				return
			end
			return orig(inst, ...)
		end
	end
	return "Bow: leap shot on (X in the middle of a roll; X at the landing stays the kneel shot)"
		.. (Main.G.on and "; guarded" or "")
end

return Bow
