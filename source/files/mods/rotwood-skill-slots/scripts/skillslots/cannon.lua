-- Skill Slots: the Cannon's Dodge and Reload on a slot button.
-- The game's Cannon has no roll: its dodge button plants the cannon (and
-- reloads while planted), and its dodge is the heavy attack (Blast). The
-- Cannon's animation files still have a finished roll (cannon_roll_pre /
-- _loop / _pst) that the game's shared roll states play for whatever weapon is
-- in hand, so the roll only needs a way in:
--   * Dodge on LT / RT / RS: that button sends a dodge press marked as a roll.
--     The dodge button stays the Cannon's own (plant / reload).
--   * Reload on LT / RT / RS: that button sends the game's own dodge press
--     (plant / reload, every Cannon combo that plants); the dodge button's
--     presses are marked as rolls.
-- A roll press goes to the roll wherever the game takes a dodge press (idle,
-- a dodge cancel window, a state with a dodge follow-up) and never plants or
-- reloads: the Cannon states that read dodge presses themselves (Blast into
-- plant, plant into reload, aiming...) let it fall through to the game's
-- shared control handling. Getting up from a knockdown with it rolls too.
-- It always uses the normal-weight roll animation (the Cannon has no light /
-- heavy roll animations); distance, speed and invincibility come from the
-- game as for any roll. The game adds a weapon bonus to every dodge's
-- invincibility (Bow / Striker 0 frames, Hammer / Spear / Greatsword 1, the
-- Cannon 5 for its Blast while it has ammo); the roll uses
-- cannon_roll_iframes instead (default 0, like Bow / Striker), only for the
-- roll: Blast keeps the Cannon's own.
-- Roll into an attack (cannon_roll_combos): at the Hammer's roll-attack frames,
-- light / heavy cancel the roll into the Cannon's own airborne / standing
-- attacks (it has no rolling attack animations), by timing and stick:
--               mid-roll, ahead      mid-roll, back         landing, ahead   landing, back
--   light (X)   Air Shot ahead       turn, Air Shot behind  normal shot      turn, Battering Ram swing
--   heavy (Y)   Quick Rise (punch)   turn, Air Blast        Blast            turn, Blast (dash on)
-- (the swing is the Battering Ram skill's move: cannon_roll_swing = false
-- makes that one a normal shot behind)
-- The Air Shot keeps the roll's momentum (forward, or backward after turning);
-- the Air Blast launches you on in the roll's direction. The game's own
-- chains follow (after an air attack: X = Air Shot, Y = Air Blast...). No ammo:
-- the game's empty versions. cannon_roll_combos = false: the normal shot /
-- Blast all through the roll.
-- Only while a Cannon is in hand and Dodge or Reload is on one of its slots;
-- otherwise everything is the game's own way.

local Core = require "skillslots.core"
local PlayerController = require "components.playercontroller"

local Cannon = {}

Cannon.ROLL_STATE = "roll_pre" -- the game's normal roll (shared roll states)
-- the roll's air attacks: a step that passes the roll's momentum on to the
-- Cannon's own airborne state (they normally come out of a Blast)
Cannon.AIR_SHOT = "skillslots_roll_airshot"
Cannon.AIR_BLAST = "skillslots_roll_airblast"
Cannon.AIR_TARGETS = { [Cannon.AIR_SHOT] = "blast_TO_airshoot", [Cannon.AIR_BLAST] = "blast_TO_airblast" }
Cannon.NO_AMMO = "blast_TO_noammo"
Cannon.QUICK_RISE = "cannon_quickrise"
Cannon.SWING = "skill_cannon_butt" -- the Battering Ram skill's swing (cannon_skill_whip)
Cannon.IFRAME_SOURCE = "weapon_type" -- the game's name for the weapon's dodge invincibility bonus

-- Cannon states that read dodge presses in their own controlevent handler
-- (plant, reload, aim cancel). A roll press skips those. (shockwave_hold and
-- the two backfire_hold states only watch buttons being let go: a dodge press
-- does nothing there, so they aren't in the list.)
Cannon.OWN_DODGE_STATES = {
	"blast", "blast_TO_land", "blast_TO_airshoot", "blast_TO_airblast", "blast_TO_plant",
	"cannon_plant_pre", "mortar_hold",
	"cannon_quickrise",
}

local function DodgeEntry(pc)
	for _, data in ipairs(pc.controlqueue or {}) do
		if data.control == "dodge" then
			return data
		end
	end
	return nil
end
Cannon.DodgeEntry = DodgeEntry

-- The buttons Dodge and Reload are on for the Cannon in hand (nil, nil when
-- no Cannon or neither is on a button).
function Cannon.Slots(inst)
	if inst == nil or not Core.IsActive(inst) or Core.GetCurrentWeapon(inst) ~= Core.CANNON_WEAPON then
		return nil, nil
	end
	return Core.FindPseudoSlot(inst, Core.CANNON_DODGE), Core.FindPseudoSlot(inst, Core.CANNON_RELOAD)
end

function Cannon.Active(inst)
	local dodge, reload = Cannon.Slots(inst)
	return dodge ~= nil or reload ~= nil
end

-- Reload is on a slot: the dodge button rolls.
function Cannon.RollOnDodgeButton(inst)
	local _, reload = Cannon.Slots(inst)
	return reload ~= nil
end

function Cannon.IsRollPress(data)
	return type(data) == "table" and data.skillslots_roll == true
end

-- The slot button (input.lua: after the game's own checks for a button press).
-- name: Core.CANNON_DODGE or Core.CANNON_RELOAD
function Cannon.OnButton(pc, slot, down, name)
	if not down then
		local entry = DodgeEntry(pc)
		if entry ~= nil and entry.skillslots_slot == slot and not entry.released
			and (entry.skillslots_roll or entry.skillslots_plant) then
			pc:OnControlUpEvent("dodge")
		end
		return
	end
	if not Cannon.Active(pc.inst) then
		return
	end
	local data = { skillslots_slot = slot }
	if name == Core.CANNON_DODGE then
		data.skillslots_roll = true
	else
		data.skillslots_plant = true
	end
	if pc:ShouldAimAtMouse() and pc.GetMouseActionDirection ~= nil then
		data.dir = pc:GetMouseActionDirection()
	else
		data.dir = pc:GetAnalogDir()
	end
	pc:OnControlDownEvent("dodge", data)
end

function Cannon.Install()
	local SGPlayerCommon = require "stategraphs.sg_player_common"
	local DoControlFn = Core.FindUpvalue(SGPlayerCommon.Fns.DoAction, "DoControlFn")
	assert(type(DoControlFn) == "table" and type(DoControlFn.dodge) == "function", "DoControlFn.dodge")
	for _, name in ipairs({ "OnDodgeButton", "OnControlDownEvent", "OnControlUpEvent", "GetAnalogDir" }) do
		assert(type(PlayerController[name]) == "function", "PlayerController:" .. name)
	end

	-- presses ----------------------------------------------------------------

	-- A new dodge press replaces the queued one: let go of a held one first
	-- (like releasing it). With Reload on a slot, the dodge button's own
	-- presses are rolls.
	-- (bulletproofing: the Cannon's part of each hook runs in Core.G.Call;
	-- if it errors, it's logged and the game's own code runs)
	local G = Core.G
	local function OnDodgePress(self, data)
		if not Cannon.Active(self.inst) then
			return
		end
		local entry = DodgeEntry(self)
		if entry ~= nil and not entry.released then
			self:OnControlUpEvent("dodge")
		end
		if data.skillslots_slot == nil and Cannon.RollOnDodgeButton(self.inst) then
			data.skillslots_roll = true
		end
	end
	local orig_down = PlayerController.OnControlDownEvent
	PlayerController.OnControlDownEvent = function(self, control, data, ...)
		if control == "dodge" and type(data) == "table" then
			G.Call("Cannon: dodge press", OnDodgePress, self, data)
		end
		return orig_down(self, control, data, ...)
	end

	-- Letting go of the dodge button doesn't let go of a slot button's press.
	local function KeepsSlotPress(self)
		if not Cannon.Active(self.inst) then
			return false
		end
		local entry = DodgeEntry(self)
		return entry ~= nil and entry.skillslots_slot ~= nil
	end
	local orig_dodge = PlayerController.OnDodgeButton
	PlayerController.OnDodgeButton = function(self, down, ...)
		if not down then
			local ok, keep = G.Call("Cannon: dodge release", KeepsSlotPress, self)
			if ok and keep then
				return
			end
		end
		return orig_dodge(self, down, ...)
	end

	-- the stategraph --------------------------------------------------------

	-- A roll press takes the game's dodge path with the roll as the next
	-- state, instead of the Cannon's plant / reload follow-ups.
	local function RollsNow(inst, data)
		return Cannon.IsRollPress(data) and Cannon.Active(inst) and inst.sg ~= nil
			and not (inst.emote_ring ~= nil and inst.emote_ring.IsRingShowing ~= nil and inst.emote_ring:IsRingShowing())
	end
	local orig_dodge_fn = DoControlFn.dodge
	DoControlFn.dodge = function(inst, data, ...)
		local ok, roll = G.Call("Cannon: roll press", RollsNow, inst, data)
		if not ok or not roll then
			return orig_dodge_fn(inst, data, ...)
		end
		local sg = inst.sg
		local statemem = sg.statemem
		-- the game sends "dodge_cancel" for a dodge out of an attack, except
		-- for the Cannon (its dodge is the heavy attack); the roll is a dodge
		if sg:HasStateTag("busy") and (sg:HasStateTag("attack") or sg:HasStateTag("skill")) and sg.mem.heavydodge then
			inst:PushEvent("dodge_cancel", { state = sg.currentstate, state_tags = sg.currentstate ~= nil and sg.currentstate.tags or nil })
		end
		local saved = statemem.dodgecombostate
		statemem.dodgecombostate = Cannon.ROLL_STATE
		local results = table.pack(pcall(orig_dodge_fn, inst, data, ...))
		statemem.dodgecombostate = saved -- put it back (the state's own follow-up)
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end

	-- the Cannon's roll has no "_up" animations: roll the side way when going up
	local orig_up = SGPlayerCommon.Fns.ApplyUpPrefixSimple
	if type(orig_up) == "function" then
		SGPlayerCommon.Fns.ApplyUpPrefixSimple = function(inst, name, ...)
			if type(name) == "string" and string.lower(name):find("^cannon_roll") then
				return name
			end
			return orig_up(inst, name, ...)
		end
	end
end

-- A frame event added to a state's timeline, kept in the game's order (time,
-- then position).
function Cannon.AddFrame(FE, state, frame, fn)
	state.timeline = state.timeline or {}
	local ev = FE(frame, fn)
	ev.idx = #state.timeline + 1
	state.timeline[#state.timeline + 1] = ev
	table.sort(state.timeline, function(a, b)
		return a.time < b.time or (a.time == b.time and (a.idx or 0) < (b.idx or 0))
	end)
end

-- In the Cannon's roll: light / heavy go to its attacks (the table at the top;
-- phase "air" = mid-roll, "land" = the landing), aimed where the press points;
-- a press buffered during the roll goes off now.
function Cannon.OpenAttacks(inst, phase)
	if Core.GetCurrentWeapon(inst) ~= Core.CANNON_WEAPON then
		return
	end
	local sm = inst.sg.statemem
	local states = inst.sg.sg ~= nil and inst.sg.sg.states or nil
	local air = phase == "air" and Core.settings.cannon_roll_combos ~= false and states ~= nil
		and states[Cannon.AIR_SHOT] ~= nil and states[Cannon.AIR_BLAST] ~= nil and states[Cannon.QUICK_RISE] ~= nil
	if air then
		sm.lightcombostate = Cannon.AIR_SHOT
		sm.reverselightstate = Cannon.AIR_SHOT
		sm.heavycombostate = Cannon.QUICK_RISE
		sm.reverseheavystate = Cannon.AIR_BLAST
	else
		sm.lightcombostate = "default_light_attack"
		sm.heavycombostate = "default_heavy_attack"
		sm.reverselightstate = "default_light_attack"
		sm.reverseheavystate = "default_heavy_attack"
		if phase == "land" and Core.settings.cannon_roll_combos ~= false and Core.settings.cannon_roll_swing ~= false
			and states ~= nil and states[Cannon.SWING] ~= nil then
			sm.reverselightstate = Cannon.SWING
		end
	end
	Cannon.Note("roll attacks open (" .. (air and "mid-roll" or phase) .. ")")
	-- the roll's speed and direction, for the air attacks' momentum
	local speed = tonumber(sm.speed) or tonumber(sm.maxspeed) or 0
	inst.sg.mem.skillslots_roll = { speed = math.abs(speed), rot = inst.Transform:GetFacingRotation() }
	if inst.sg.RemoveStateTag ~= nil then
		inst.sg:RemoveStateTag("norotatecombo") -- the attack turns to the press's direction
	end
	local SGPlayerCommon = require "stategraphs.sg_player_common"
	if SGPlayerCommon.Fns.TryQueuedLightOrHeavy ~= nil then
		SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
	end
end

-- The log: each X / Y press during the roll, which way the stick pointed and
-- where it went (to see in game why a move didn't come out).
local function PressBefore(inst, data)
	local SGPlayerCommon = require "stategraphs.sg_player_common"
	local rev = SGPlayerCommon.Fns.IsReverseControl
	local back = rev ~= nil and rev(inst, data) or false
	local facing = inst.Transform ~= nil and inst.Transform:GetFacingRotation() or nil
	local before = inst.sg.currentstate ~= nil and inst.sg.currentstate.name or "?"
	return before, back, facing
end
local function PressAfter(inst, data, before, back, facing)
	local after = inst.sg.currentstate ~= nil and inst.sg.currentstate.name or "?"
	Cannon.Note(string.format("roll press: %s, stick %s (dir %s, facing %s), in %s -> %s%s",
		data.control == "heavyattack" and "Y" or "X", back and "back" or "ahead", tostring(data.dir and math.floor(data.dir + 0.5)),
		tostring(facing and math.floor(facing + 0.5)), before, after, after == before and " (not yet: buffered / window closed)" or ""))
end
function Cannon.WatchRollPresses(state)
	local list = state.events ~= nil and state.events.controlevent or nil
	for _, h in ipairs(type(list) == "table" and list or {}) do
		if type(h) == "table" and type(h.fn) == "function" and not h.skillslots_note then
			h.skillslots_note = true
			local orig = h.fn
			h.fn = function(inst, data, ...)
				-- (the Cannon's stategraph only: the game never rolls it without this mod)
				local watch = type(data) == "table" and (data.control == "lightattack" or data.control == "heavyattack")
					and Cannon.notes < 60
				local before, back, facing
				if watch then
					local ok
					ok, before, back, facing = Core.G.Call("Cannon roll: press log", PressBefore, inst, data)
					watch = ok
				end
				local results = table.pack(orig(inst, data, ...))
				if watch then
					Core.G.Call("Cannon roll: press log", PressAfter, inst, data, before, back, facing)
				end
				return table.unpack(results, 1, results.n)
			end
		end
	end
end

-- A few lines in the log the first times, to see in game which roll attacks
-- come up (Skill Slots' log lines start with [Skill Slots]).
Cannon.notes = 0
function Cannon.Note(msg)
	if Cannon.notes < 60 then
		Cannon.notes = Cannon.notes + 1
		Core.Log("Cannon " .. msg)
	end
end

local function AngleDiff(a, b)
	local d = math.abs((a - b) % 360)
	return d > 180 and 360 - d or d
end

-- The roll's momentum for an air attack out of it: forward if you still face
-- the roll's way, backward if the attack turned you round (Blast-style data:
-- the airborne states slow it down from there like after a Blast).
function Cannon.RollTransition(inst)
	local mem = inst.sg.mem.skillslots_roll
	local speed = mem ~= nil and mem.speed or 0
	local sign = 1
	if mem ~= nil and mem.rot ~= nil and AngleDiff(inst.Transform:GetFacingRotation(), mem.rot) > 90 then
		sign = -1
	end
	return { maxspeed = sign * speed, speed = sign * speed, framessliding = 4 }
end

-- Ammo to fire (the game's check: some ammo, not overheated)
function Cannon.CanFire(inst)
	local mem = inst.sg.mem
	if mem.cannon_infinite_ammo_power and (tonumber(mem.cannon_overheat_cooldown_remaining) or 0) > 0 then
		return false
	end
	local SGPlayerCommon = require "stategraphs.sg_player_common"
	local get = SGPlayerCommon.Fns.Cannon_GetRemainingAmmo
	return get == nil or (tonumber(get(inst)) or 0) > 0
end

-- The step states (added to the Cannon's stategraph): straight on into the
-- Cannon's airborne attack with the roll's momentum, or its empty version.
local function AirTarget(inst, name)
	local data = Cannon.RollTransition(inst)
	local target = Cannon.CanFire(inst) and Cannon.AIR_TARGETS[name] or Cannon.NO_AMMO
	Cannon.Note("roll: " .. name .. " -> " .. target)
	return target, data
end
function Cannon.MakeAirState(StateCtor, name)
	local where = "Cannon roll: " .. name
	return StateCtor({
		name = name,
		tags = { "busy", "attack" },
		onenter = function(inst)
			-- (an error working it out: logged, and you stand up)
			local ok, target, data = Core.G.Call(where, AirTarget, inst, name)
			if not ok or target == nil then
				target, data = "idle", nil
			end
			inst.sg:GoToState(target, data)
		end,
	})
end

-- Near the end of the roll's recovery: back to the game's rules (attacks wait
-- for the recovery to end).
function Cannon.CloseAttacks(inst)
	if Core.GetCurrentWeapon(inst) ~= Core.CANNON_WEAPON then
		return
	end
	local sm = inst.sg.statemem
	sm.lightcombostate = nil
	sm.heavycombostate = nil
	sm.reverselightstate = nil
	sm.reverseheavystate = nil
end

-- The Cannon's stategraph (AddStateGraphPostInit "sg_player_cannon"):
--   * its default dodge (plant) rolls for a roll press: the way in when
--     getting up from a knockdown;
--   * its states that read dodge presses themselves let a roll press fall
--     through to the shared control handling (returning true does that).
-- Big Blast on LT / RT / RS. Letting go of the skill button in the aim states
-- (sg_player_cannon_skill_aim.lua, DoBigBlast) goes to the Cannon's blast state
-- with big = true, and the blast state makes the shot big only while
-- sg.mem.skillstate still reads "skill_cannon_aim". A slot press puts B's skill
-- back right after the press, so letting go of the slot button fired the plain
-- Blast (the heavy attack). The aim states' release now reads Big Blast while
-- it fires; B's skill goes back right after. (The blast state itself is left
-- alone: Skill Balance finds Big Blast's shot inside it.) Works whatever the
-- Dodge / Reload settings are; Big Blast on B was already fine.
Cannon.BIG_BLAST_SKILL = "skill_cannon_aim"
Cannon.AIM_RELEASE_STATES = { "skill_cannon_aim_loop", "skill_cannon_aim_run_pre", "skill_cannon_aim_run_loop", "skill_cannon_aim_run_pst" }

function Cannon.BigBlastRelease(orig)
	return function(inst, ...)
		local mem = inst ~= nil and inst.sg ~= nil and inst.sg.mem or nil
		if mem == nil or mem.skillstate == Cannon.BIG_BLAST_SKILL then
			return orig(inst, ...)
		end
		local keep = mem.skillstate
		mem.skillstate = Cannon.BIG_BLAST_SKILL
		local results = table.pack(pcall(orig, inst, ...))
		if mem.skillstate == Cannon.BIG_BLAST_SKILL then
			mem.skillstate = keep
		end
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
end

-- a local variable a game function uses: its value and slot
local function FindUpvalue(fn, wanted)
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

-- at mod load: the aim states are skill states (playerskillstates)
function Cannon.KeepBigBlast()
	local found, PlayerSkillState = pcall(function()
		require "playerskillstates"
		return require "playerskillstate"
	end)
	if not found or type(PlayerSkillState) ~= "table" or type(PlayerSkillState.GetPlayerSkillStates) ~= "function" then
		Core.Log("Big Blast on LT / RT / RS: skill states not found (" .. tostring(PlayerSkillState) .. "), it may fire the plain Blast")
		return false
	end
	local by_name = {}
	for _, st in ipairs(PlayerSkillState:GetPlayerSkillStates()) do
		by_name[st.name] = st
	end
	local fn, idx, orig
	for _, name in ipairs(Cannon.AIM_RELEASE_STATES) do
		local st = by_name[name]
		local v, i = FindUpvalue(st ~= nil and st.onupdate or nil, "DoBigBlast")
		if type(v) == "function" then
			fn, idx, orig = st.onupdate, i, v
			break
		end
	end
	if fn == nil then
		Core.Log("Big Blast on LT / RT / RS: the aim states changed (no DoBigBlast), it may fire the plain Blast")
		return false
	end
	if orig == Cannon.big_blast_release then
		return true -- already in
	end
	Cannon.big_blast_release = Cannon.BigBlastRelease(orig)
	debug.setupvalue(fn, idx, Cannon.big_blast_release) -- shared by every aim state that lets go
	Core.Log("Big Blast on LT / RT / RS fires the real Big Blast")
	return true
end

function Cannon.PostInitSG(sg)
	local states = sg ~= nil and sg.states or nil
	if type(states) ~= "table" then
		Core.Log("Cannon stategraph: no states, Dodge / Reload rolls only from idle")
		return
	end
	-- the roll's invincibility: the setting's weapon bonus instead of the
	-- Cannon's Blast bonus, for this roll only (the roll counts its frames when
	-- it starts; the Cannon's own bonus goes back right after)
	local rp = states[Cannon.ROLL_STATE]
	if rp ~= nil and type(rp.onenter) == "function" then
		local orig_roll = rp.onenter
		-- (the roller, and the bonus there before; nil: not the Cannon's roll)
		local function SetIframes(inst)
			local pr = inst.components ~= nil and inst.components.playerroller or nil
			if pr == nil or pr.AddIframeModifier == nil or Core.GetCurrentWeapon(inst) ~= Core.CANNON_WEAPON then
				return nil
			end
			local prev = pr:GetIframeModifierBySource(Cannon.IFRAME_SOURCE)
			pr:AddIframeModifier(Cannon.IFRAME_SOURCE, Core.settings.cannon_roll_iframes or 0)
			return pr, prev
		end
		local function PutBack(pr, prev)
			if prev ~= nil then
				pr:AddIframeModifier(Cannon.IFRAME_SOURCE, prev)
			else
				pr:RemoveIframeModifier(Cannon.IFRAME_SOURCE)
			end
		end
		rp.onenter = function(inst, ...)
			local ok, pr, prev = Core.G.Call("Cannon roll: invincibility", SetIframes, inst)
			if not ok or pr == nil then
				return orig_roll(inst, ...)
			end
			local results = table.pack(pcall(orig_roll, inst, ...))
			Core.G.Call("Cannon roll: invincibility back", PutBack, pr, prev)
			if not results[1] then
				error(results[2], 0)
			end
			return table.unpack(results, 2, results.n)
		end
	else
		Core.Log("Cannon stategraph: no " .. Cannon.ROLL_STATE .. " state")
	end

	-- roll into an attack, like the other weapons: light / heavy cancel the
	-- roll straight into the Cannon's normal shot / Blast (it has no rolling
	-- attack animations), at the Hammer's roll-attack frames. The press's
	-- stick direction aims it.
	local FE = rawget(_G, "FrameEvent")
	local loop, pst = states.roll_loop, states.roll_pst
	if FE ~= nil and loop ~= nil and pst ~= nil then
		-- (guarded: an error there is logged, the roll carries on the game's way)
		local Air = Core.G.Fn("Cannon roll: attacks open (mid-roll)", function(inst) Cannon.OpenAttacks(inst, "air") end)
		local Land = Core.G.Fn("Cannon roll: attacks open (landing)", function(inst) Cannon.OpenAttacks(inst, "land") end)
		local Close = Core.G.Fn("Cannon roll: attacks close", function(inst) Cannon.CloseAttacks(inst) end)
		Cannon.AddFrame(FE, loop, 2, Air)
		Cannon.AddFrame(FE, loop, 8, Air)
		Cannon.AddFrame(FE, pst, 0, Land)
		Cannon.AddFrame(FE, pst, 7, Close)
		Cannon.WatchRollPresses(loop)
		Cannon.WatchRollPresses(pst)
	else
		Core.Log("Cannon stategraph: no roll_loop / roll_pst, no roll into an attack")
	end
	-- the roll's air attacks (Air Shot / Air Blast with the roll's momentum)
	local StateCtor = rawget(_G, "State")
	local have = StateCtor ~= nil and states[Cannon.QUICK_RISE] ~= nil and states[Cannon.NO_AMMO] ~= nil
	for _, target in pairs(Cannon.AIR_TARGETS) do
		have = have and states[target] ~= nil
	end
	if have then
		for name in pairs(Cannon.AIR_TARGETS) do
			states[name] = Cannon.MakeAirState(StateCtor, name)
		end
	else
		Core.Log("Cannon stategraph changed: the roll's air attacks are off (normal shot / Blast out of the roll)")
	end

	local dd = states.default_dodge
	if dd ~= nil and type(dd.onenter) == "function" then
		local orig_enter = dd.onenter
		local function IsRoll(inst, data)
			return Cannon.IsRollPress(data) and Cannon.Active(inst)
		end
		dd.onenter = function(inst, data, ...)
			local ok, roll = Core.G.Call("Cannon: dodge state", IsRoll, inst, data)
			if ok and roll then
				inst.sg:GoToState(Cannon.ROLL_STATE)
				return
			end
			return orig_enter(inst, data, ...)
		end
	else
		Core.Log("Cannon stategraph: no default_dodge state")
	end
	local missing = {}
	local function IsRollAt(inst, data)
		return Cannon.IsRollPress(data) and Cannon.Active(inst)
	end
	for _, name in ipairs(Cannon.OWN_DODGE_STATES) do
		local state = states[name]
		local handlers = state ~= nil and state.events ~= nil and state.events.controlevent or nil
		if type(handlers) == "table" and #handlers > 0 then
			for _, h in ipairs(handlers) do
				local orig_fn = h.fn
				local where = "Cannon: " .. name .. " press"
				h.fn = function(inst, data, ...)
					local ok, roll = Core.G.Call(where, IsRollAt, inst, data)
					if ok and roll then
						return true -- not a plant / reload press: the shared handling
					end
					return orig_fn(inst, data, ...)
				end
			end
		else
			missing[#missing + 1] = name
		end
	end
	if #missing > 0 then
		Core.Log("Cannon stategraph changed (" .. table.concat(missing, ", ") .. "): a roll press there may plant")
	else
		Core.Log("Cannon roll ready (Cannon stategraph hooked)")
	end
end

return Cannon
