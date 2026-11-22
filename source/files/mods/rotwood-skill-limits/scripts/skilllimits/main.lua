-- Skill Limits: strong skills that have no limit of their own get charges.
--
-- Each limited skill has a few charges (5). Every use takes one and restarts a
-- short rest timer (5 s); when the timer runs out, all charges come back. With
-- none left, pressing the skill does nothing but play the game's "no charge"
-- sound; the skill icon goes grey with a red X and counts down the seconds,
-- like the game's own skills with a cooldown (hud.lua). Pressing the skill
-- during a heavy attack (the boss skills' "charge the attack" way in) counts
-- the same.
--
-- Built only from the game's systems, with no per-frame work:
--   - the press: a wrapper on the game's skill button handler (DoControlFn.skill)
--     that only runs when a skill button is pressed; it sees which skill state
--     the game (or Skill Slots) is about to enter and lets it through or not
--   - the rest timer: the player's timer component ("timerdone" event)
--   - the icon number: the power's counter + "update_power", what the game's
--     cooldown skills use; the sounds: Skill_NoStock / Skill_NewStock
--   - the heavy-attack way in: the skill's own "controlevent" trigger
--
-- The bow's arrow skills (Toxic Dip, Cold Plunge, exploding arrow) use ammo
-- earned back by dealing damage, and can go straight into the heavy shot:
-- see arrows.lua.

local SGPlayerCommon = require "stategraphs.sg_player_common"
local PowerManager = require "components.powermanager"
local Power = require "defs.powers"
local Arrows = require "skilllimits.arrows"
local Hud = require "skilllimits.hud"

local Main = {}

Main.TAG = "[Skill Limits]"
Main.TIMER_PREFIX = "skilllimits_"
Main.settings = nil
Main.limited = {} -- skill id -> { charges = n, refill_seconds = s }
Main.installed = false

Main.DEFAULTS = {
	enabled = true,
	charges = 5,
	refill_seconds = 5,
	skills = {},
	show_charges_left = false,
	instant_bow_skills = true,
	bow_arrow_ammo = 2,
	bow_arrow_damage_per_arrow = 1500,
	bow_arrow_shared = true,
	bow_arrow_free_dip_cooldown = 15,
	blocked_sound = true,
	refill_sound = true,
	debug = false,
}

-- Skills with a limit of their own (stocks, cooldown, a max count): never
-- touched, even if listed in the settings.
Main.OWN_LIMIT = {
	hammer_reflectinglights = true, bow_fan = true, bow_hypershot = true,
	boss_sedament = true, boss_grimhollow = true, miniboss_gourdo = true,
	miniboss_crystroll = true, bananapeel = true,
}
-- Skills whose game data looks limited but isn't, in play: Thatcher's is one
-- use that comes back after 0.1 s; Eggzy's checks a cooldown nothing starts.
Main.NO_REAL_LIMIT = { boss_thatcher = true, boss_eggzy = true }
-- tuning names that mean "this skill already limits itself" (catches skills a
-- game update gives a limit to)
local OWN_LIMIT_TUNING = { "max_stocks", "cd", "max_count", "max_bananas" }

-- Skills that can count a use only when they hit (settings: count = "hit"):
-- the game's attack name of the hit that counts.
Main.HIT_NAMES = { polearm_javelin = "JAVELIN" }

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

function Main.Debug(msg)
	if Main.settings ~= nil and Main.settings.debug then
		Main.Log("debug: " .. tostring(msg))
	end
end

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if Main.DEFAULTS[k] ~= nil and type(v) == type(Main.DEFAULTS[k]) then
				s[k] = v
			end
		end
	end
	if s.charges < 1 then s.charges = 1 end
	if s.refill_seconds < 0.5 then s.refill_seconds = 0.5 end
	if s.bow_arrow_ammo < 0 then s.bow_arrow_ammo = 0 end
	if s.bow_arrow_damage_per_arrow < 1 then s.bow_arrow_damage_per_arrow = 1 end
	if s.bow_arrow_free_dip_cooldown < 0 then s.bow_arrow_free_dip_cooldown = -1 end -- no free dip
	Main.settings = s
	return s
end

local function HasOwnLimit(id)
	if Main.OWN_LIMIT[id] then
		return true
	end
	if Main.NO_REAL_LIMIT[id] then
		return false
	end
	local def = Power.Items and Power.Items.SKILL and Power.Items.SKILL[id]
	local tuning = def ~= nil and def.tuning or nil
	if type(tuning) == "table" then
		for _, rarity in pairs(tuning) do
			if type(rarity) == "table" then
				for _, k in ipairs(OWN_LIMIT_TUNING) do
					if rarity[k] ~= nil then
						return true
					end
				end
			end
		end
	end
	return false
end

-- settings.skills: id = true (default numbers), { charges, refill_seconds }, or false
function Main.BuildList(settings)
	local list, skipped = {}, {}
	local known = Power.Items ~= nil and Power.Items.SKILL or nil
	Arrows.Configure(Main, settings, known)
	for id, v in pairs(settings.skills) do
		if v and type(id) == "string" then
			if known ~= nil and known[id] == nil then
				Main.Log("no skill called " .. id .. " in the game (a typo, or renamed by an update): skipped")
			elseif Arrows.active[id] and Arrows.ammo_on then
				-- arrow skills use ammo (bow_arrow_ammo) instead of uses
			elseif HasOwnLimit(id) then
				table.insert(skipped, id)
			else
				local t = type(v) == "table" and v or {}
				local on_hit = t.count == "hit"
				if on_hit and Main.HIT_NAMES[id] == nil then
					Main.Log(id .. ": count = \"hit\" only works for " .. table.concat((function()
						local names = {}
						for k in pairs(Main.HIT_NAMES) do names[#names + 1] = k end
						table.sort(names)
						return names
					end)(), ", ") .. "; counting every use")
					on_hit = false
				end
				list[id] = {
					charges = math.max(1, math.floor(tonumber(t.charges) or settings.charges)),
					refill_seconds = math.max(0.5, tonumber(t.refill_seconds) or settings.refill_seconds),
					on_hit = on_hit or nil,
				}
			end
		end
	end
	table.sort(skipped)
	Main.limited = list
	return list, skipped
end

----------------------------------------------------------------------------
-- Per player

local function State(inst)
	local st = inst.skilllimits
	if st == nil then
		st = { left = {}, empty = {}, shown = {}, ticks = {} }
		inst.skilllimits = st
	end
	return st
end

local function PowerOf(inst, id)
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	return pm ~= nil and pm.powers ~= nil and pm.powers[id] or nil
end

local function SetCounter(inst, id, value)
	local pow = PowerOf(inst, id)
	local st = State(inst)
	if pow == nil or pow.persistdata == nil then
		st.shown[id] = nil
		return
	end
	if pow.persistdata.counter ~= value then
		pow.persistdata.counter = value
		inst:PushEvent("update_power", pow.def)
	end
	st.shown[id] = value ~= nil or nil
end

local function TimeLeft(inst, id)
	local timer = inst.components.timer
	return timer ~= nil and timer:GetTimeRemaining(Main.TIMER_PREFIX .. id) or nil
end

local function StopTicking(st, id)
	if st.ticks[id] ~= nil then
		st.ticks[id]:Cancel()
		st.ticks[id] = nil
	end
end

-- While a skill is out of charges: the icon shows the seconds left (once a second).
local function StartCountdown(inst, id)
	local st = State(inst)
	StopTicking(st, id)
	local function show()
		local left = TimeLeft(inst, id)
		SetCounter(inst, id, left ~= nil and math.max(1, math.ceil(left - 0.001)) or nil)
	end
	show()
	st.ticks[id] = inst:DoPeriodicTask(1, show)
end

-- the skill's icons refresh (number, grey + X)
local function Changed(inst, id)
	local pow = PowerOf(inst, id)
	if pow ~= nil and pow.def ~= nil then
		inst:PushEvent("update_power", pow.def)
	end
end

-- the game's little effect over the player's head (e.g. "acquire_item_empty",
-- the X it shows when a stock skill has nothing left)
local function Fx(inst, name)
	local ok, powerutil = pcall(require, "util.powerutil")
	if ok and powerutil ~= nil and powerutil.SpawnFxOnEntity ~= nil then
		pcall(powerutil.SpawnFxOnEntity, name, inst, { ischild = true, offy = 0 })
	end
end

local function PlaySound(inst, event)
	local ok_s, soundutil = pcall(require, "util.soundutil")
	local ok_f, fmodtable = pcall(require, "defs.sound.fmodtable")
	if ok_s and ok_f and fmodtable.Event ~= nil and fmodtable.Event[event] ~= nil then
		pcall(soundutil.PlayLocalCodeSound, inst, fmodtable.Event[event])
	end
end

-- shared with arrows.lua
Main.State = State
Main.PowerOf = PowerOf
Main.SetCounter = SetCounter
Main.PlaySound = PlaySound

function Main.Refill(inst, id)
	local st = State(inst)
	local was_empty = st.empty[id]
	st.left[id] = nil
	st.empty[id] = nil
	StopTicking(st, id)
	if st.shown[id] then
		SetCounter(inst, id, nil)
	end
	if was_empty then
		Changed(inst, id) -- (the grey + X go)
	end
	if was_empty and Main.settings.refill_sound then
		PlaySound(inst, "Skill_NewStock")
	end
	Main.Debug(tostring(inst) .. " " .. id .. " refilled")
end

-- One use of skill `id` counted: a charge goes, the rest timer restarts.
local function Consume(inst, id, lim)
	local st = State(inst)
	local left = math.max(0, (st.left[id] or lim.charges) - 1) -- (a throw still flying when it ran out)
	st.left[id] = left
	local timer = inst.components.timer
	if timer ~= nil then
		timer:StartTimer(Main.TIMER_PREFIX .. id, lim.refill_seconds, true) -- restarts it
	end
	if left <= 0 then
		st.empty[id] = true
		StartCountdown(inst, id)
		Changed(inst, id) -- (grey + X)
	elseif Main.settings.show_charges_left then
		SetCounter(inst, id, left)
	end
	Main.Debug(tostring(inst) .. " " .. id .. " used, " .. left .. " left")
end

-- A press is about to start skill `id`: true = go ahead (a charge is used,
-- or for a count = "hit" skill: it's watched for its hit).
function Main.TryUse(inst, id)
	local lim = Main.limited[id]
	if lim == nil then
		return true
	end
	local st = State(inst)
	local left = st.left[id] or lim.charges
	if left <= 0 then
		Fx(inst, "acquire_item_empty") -- the X over your head, like the game's stock skills
		if Main.settings.blocked_sound then
			PlaySound(inst, "Skill_NoStock")
		end
		Main.Debug(tostring(inst) .. " " .. id .. " blocked (" .. tostring(TimeLeft(inst, id)) .. " s)")
		return false
	end
	if lim.on_hit then
		st.armed = st.armed or {}
		st.armed[id] = (st.armed[id] or 0) + 1 -- free unless it hits
		return true
	end
	Consume(inst, id, lim)
	return true
end

-- A hit dealt by the player ("do_damage"): the hit of a count = "hit" skill
-- that was just used takes its charge (once per use).
local function OnDoDamage(inst, attack)
	local st = inst.skilllimits
	if st == nil or st.armed == nil or next(st.armed) == nil or attack == nil or attack.GetNameID == nil then
		return
	end
	local name = attack:GetNameID()
	for id, n in pairs(st.armed) do
		if Main.HIT_NAMES[id] == name then
			st.armed[id] = n > 1 and n - 1 or nil
			local lim = Main.limited[id]
			if lim ~= nil then
				Consume(inst, id, lim)
			end
		end
	end
end

local function OnTimerDone(inst, data)
	local name = data ~= nil and data.name or nil
	if type(name) == "string" and name:sub(1, #Main.TIMER_PREFIX) == Main.TIMER_PREFIX then
		Main.Refill(inst, name:sub(#Main.TIMER_PREFIX + 1))
	end
end

function Main.SetupPlayer(inst)
	if not Main.installed then
		return
	end
	inst:ListenForEvent("timerdone", OnTimerDone)
	for _, lim in pairs(Main.limited) do
		if lim.on_hit then
			inst:ListenForEvent("do_damage", OnDoDamage)
			break
		end
	end
	Arrows.SetupPlayer(inst)
end

----------------------------------------------------------------------------
-- The press

-- "skill_boss_owlitzer" -> "boss_owlitzer" when that skill is limited
local function LimitedSkillOf(statename)
	if type(statename) ~= "string" or statename:sub(1, 6) ~= "skill_" then
		return nil
	end
	local id = statename:sub(7)
	return Main.limited[id] ~= nil and id or nil
end
Main.LimitedSkillOf = LimitedSkillOf

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
			return value
		end
	end
	return nil
end

-- Runs the game's skill handler; while it runs, the player's stategraph checks
-- the state it's sent to. Nothing is added anywhere else.
local press_errors = 0
local function Report(err)
	if press_errors < 5 then
		press_errors = press_errors + 1
		Main.Log("skill press error (skipped; the game carries on): " .. tostring(err))
	end
end

local function SkillPress(orig, inst, data)
	local sg = inst ~= nil and inst.sg or nil
	if sg == nil or (next(Main.limited) == nil and not Arrows.Any()) then
		return orig(inst, data)
	end
	local prev = rawget(sg, "GoToState")
	local base = prev or getmetatable(sg).GoToState
	local blocked, used = false, nil
	local sheathed = sg.mem ~= nil and sg.mem.sheathed or nil
	-- what this state change means for the limits ("block", "quick",
	-- "quick_turn" or nil: go on); run in pcall, an error is logged and the
	-- game's state change goes ahead
	local function Decide(name, params)
		if used == nil then
			local kind, aid, turning = Arrows.Check(inst, sg, name, params)
			if kind == "block" then
				return "block"
			elseif kind == "quick" then
				used = aid
				Arrows.StartQuickShot(inst, aid)
				return turning and "quick_turn" or "quick"
			elseif aid ~= nil and Arrows.ammo_on then
				used = aid -- the game's dip (the arrow pays its ammo when fired)
			end
		end
		local id = LimitedSkillOf(name)
		if id == nil and name == "turn_pre" and type(params) == "table" then
			id = LimitedSkillOf(params[1]) -- turning around first, then the skill
		end
		if id ~= nil and id ~= used and PowerOf(inst, id) ~= nil then
			if not Main.TryUse(inst, id) then
				return "block"
			end
			used = id -- one charge per press, however the game gets there
		end
		return nil
	end
	rawset(sg, "GoToState", function(self, name, params, ...)
		if self == sg and not blocked then
			local ok, act = pcall(Decide, name, params)
			if not ok then
				Report(act)
			elseif act == "block" then
				blocked = true
				return
			elseif act == "quick_turn" then
				return base(self, "turn_pre", { "heavy_attack_pre" }, ...)
			elseif act == "quick" then
				return base(self, "heavy_attack_pre", nil, ...)
			end
		end
		return base(self, name, params, ...)
	end)
	local results = table.pack(pcall(orig, inst, data))
	rawset(sg, "GoToState", prev)
	if blocked and sg.mem ~= nil and sg.mem.sheathed ~= sheathed and SGPlayerCommon.Fns.SetWeaponSheathed ~= nil then
		pcall(SGPlayerCommon.Fns.SetWeaponSheathed, inst, sheathed) -- the handler unsheathes; nothing happened
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end
Main.SkillPress = SkillPress

----------------------------------------------------------------------------
-- The other way into a boss skill: pressing it during a heavy attack charges
-- that attack with it (Mother Tree's roots, Thatcher's poison, Eggzy's eggs).
-- It's the same skill, so it takes a use too, and with none left it does
-- nothing (no charge, no sound of charging, the press is used up).

-- the game's test for "this press charges the heavy attack"
-- (powerutil.BossPower_Queue_OnControlEvent)
local function WouldQueue(pow, inst, data)
	local sg = inst.sg
	return type(data) == "table" and data.control == "skill" and sg ~= nil
		and sg:HasStateTag("attack") and sg:HasStateTag("heavy_attack") and not sg:HasStateTag("attack_recovery")
		and pow.mem ~= nil and not pow.mem.attack_charged and not pow.mem.charged_this_state
end

-- With Skill Slots: which skill the press is for (true, name). Without: false.
local slots_core = nil
local function PressedSkill(inst, data)
	if slots_core == nil then
		local ok, core = pcall(require, "skillslots.core")
		slots_core = ok and type(core) == "table" and type(core.IsActive) == "function"
			and type(core.GetSlotSkill) == "function" and core or false
	end
	if not slots_core or not slots_core.IsActive(inst) then
		return false
	end
	return true, slots_core.GetSlotSkill(inst, data.skillslots_slot or "B")
end

local queue_wrapped = setmetatable({}, { __mode = "k" }) -- defs done
local function WrapQueue(id, def)
	local triggers = type(def) == "table" and def.event_triggers or nil
	local fn = triggers ~= nil and triggers.controlevent or nil
	if type(fn) ~= "function" or queue_wrapped[def] then
		return false
	end
	triggers.controlevent = function(pow, inst, data, ...)
		if Main.limited[id] ~= nil and WouldQueue(pow, inst, data) then
			local slots, name = PressedSkill(inst, data)
			if slots and name ~= id then
				return -- another skill's button: not this one's charge
			end
			if not Main.TryUse(inst, id) then
				local pc = inst.components.playercontroller
				if pc ~= nil and pc.FlushControlQueueAt ~= nil then
					pc:FlushControlQueueAt(data)
				end
				return
			end
		end
		return fn(pow, inst, data, ...)
	end
	queue_wrapped[def] = true
	return true
end
Main.WrapQueue = WrapQueue

----------------------------------------------------------------------------
-- Saves: the countdown number isn't saved (a power keeps its counter in the
-- save; without the mod the number would stay on the icon).

local function HookSave()
	local orig = PowerManager.OnSave
	PowerManager.OnSave = function(self, ...)
		local st = self.inst ~= nil and self.inst.skilllimits or nil
		local kept = nil
		if st ~= nil and next(st.shown) ~= nil and self.powers ~= nil then
			kept = {}
			for id in pairs(st.shown) do
				local pow = self.powers[id]
				if pow ~= nil and pow.persistdata ~= nil then
					kept[id] = pow.persistdata.counter
					pow.persistdata.counter = nil
				end
			end
		end
		local results = table.pack(pcall(orig, self, ...))
		if kept ~= nil then
			for id, v in pairs(kept) do
				local pow = self.powers[id]
				if pow ~= nil and pow.persistdata ~= nil then
					pow.persistdata.counter = v
				end
			end
		end
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
end

----------------------------------------------------------------------------

local function CheckGame()
	if type(SGPlayerCommon) ~= "table" or type(SGPlayerCommon.Fns) ~= "table" or type(SGPlayerCommon.Fns.DoAction) ~= "function" then
		return "SGPlayerCommon.Fns.DoAction"
	end
	local DoControlFn = FindUpvalue(SGPlayerCommon.Fns.DoAction, "DoControlFn")
	if type(DoControlFn) ~= "table" or type(DoControlFn.skill) ~= "function" then
		return "the skill button handler (DoControlFn.skill)"
	end
	if type(PowerManager) ~= "table" or type(PowerManager.OnSave) ~= "function" then
		return "PowerManager:OnSave"
	end
	return nil, DoControlFn
end

function Main.Install(settings)
	local missing, DoControlFn = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	local list, skipped = Main.BuildList(settings)
	for _, id in ipairs(skipped) do
		Main.Log(id .. " has a limit of its own: left as it is")
	end
	local orig = DoControlFn.skill
	DoControlFn.skill = function(inst, data)
		return SkillPress(orig, inst, data)
	end
	HookSave()
	local skills = Power.Items ~= nil and Power.Items.SKILL or nil
	for id in pairs(list) do
		WrapQueue(id, skills ~= nil and skills[id] or nil)
	end
	local hud_ok, hud = pcall(Hud.Install)
	if not hud_ok or not hud then
		Main.Log("the grey + X look on the big skill icon is off (" .. (hud_ok and "a game update changed SkillWidget" or tostring(hud)) .. ")")
	end
	Main.installed = true
	local n = 0
	for _ in pairs(list) do
		n = n + 1
	end
	local info = string.format("%d skills limited: %d uses, then %s s after the last use refills them",
		n, settings.charges, tostring(settings.refill_seconds))
	if Arrows.Any() then
		if Arrows.ammo_on then
			info = info .. string.format("; bow arrow skills: %d arrows, +1 per %s damage", Arrows.max, tostring(Arrows.per))
			info = info .. (Arrows.shared and ", one shared quiver" or ", a quiver each")
			if Arrows.free_dip == nil then
				info = info .. ", no free dip"
			elseif Arrows.free_dip > 0 then
				info = info .. string.format(", empty: a free dip every %s s", tostring(Arrows.free_dip))
			else
				info = info .. ", empty: free dips"
			end
		end
		if Arrows.instant_on then
			info = info .. "; instant bow skills on"
		end
	end
	return true, info
end

return Main
