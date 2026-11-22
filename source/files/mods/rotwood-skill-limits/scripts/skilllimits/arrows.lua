-- Skill Limits: the bow's arrow skills (Toxic Dip, Cold Plunge, exploding arrow).
--
-- Ammo, the way the game's Banana Peel and Gourdo's Community Garden work:
-- one quiver shared by every arrow skill you have (bow_arrow_shared; false =
-- each skill its own), a few arrows (3); every special arrow that leaves the
-- bow takes one; dealing damage to enemies (or the training dummies in town)
-- earns them back (one per 1000 damage, the game's bananas and garden rate).
-- The skill icon shows the arrows left; the game's "new stock" effect and sound
-- play when one comes back.
-- Out of arrows: one free dip (the game's arrow dip, only the dip: it makes one
-- arrow and loads it, the next press shoots it), then bow_arrow_free_dip_cooldown
-- seconds before the next free dip. Meanwhile the button does nothing (the X
-- over your head) and the icons go grey with the seconds left.
--
-- Instant mode: the skill button goes straight into the bow's own heavy shot,
-- held with the skill button. Released in the Focus window, the shot carries
-- the skill's arrow (the game's primed-arrow events); any other release is a
-- plain heavy shot and costs nothing. Instant off: the game's arrow dip; the
-- dipped arrow takes its ammo when it's fired.
--
-- A special arrow is counted where the game makes it: the "projectile_primed"
-- event of the arrow carrying it. All event-driven, nothing per frame.

local Arrows = {}

Arrows.SKILLS = { bow_primearrow_acid = "acid", bow_primearrow_cold = "cold", bow_primearrow_explode = "explode" }
Arrows.BY_TYPE = { acid = "bow_primearrow_acid", cold = "bow_primearrow_cold", explode = "bow_primearrow_explode" }
Arrows.active = {} -- id -> true (arrow skills that exist in the game)
Arrows.ammo_on = false
Arrows.instant_on = false
Arrows.max = 3
Arrows.per = 1000
Arrows.shared = true -- one quiver for all the arrow skills
Arrows.free_dip = 15 -- seconds between free dips when empty; 0 = no wait; nil = no free dip
Arrows.FREE_DIP_TIMER = "skilllimits_free_dip"

local Main -- the main module (shared helpers), set by Configure

function Arrows.Configure(main, settings, known)
	Main = main
	Arrows.max = math.max(0, math.floor(settings.bow_arrow_ammo))
	Arrows.per = math.max(1, settings.bow_arrow_damage_per_arrow)
	Arrows.ammo_on = Arrows.max > 0
	Arrows.instant_on = settings.instant_bow_skills
	Arrows.shared = settings.bow_arrow_shared ~= false
	local cd = settings.bow_arrow_free_dip_cooldown
	Arrows.free_dip = (type(cd) == "number" and cd >= 0) and cd or nil
	Arrows.active = {}
	for id in pairs(Arrows.SKILLS) do
		if known == nil or known[id] ~= nil then
			Arrows.active[id] = true
		end
	end
end

function Arrows.Any()
	return next(Arrows.active) ~= nil and (Arrows.ammo_on or Arrows.instant_on)
end

local function ArrowOf(statename)
	if type(statename) ~= "string" or statename:sub(1, 6) ~= "skill_" then
		return nil
	end
	local id = statename:sub(7)
	return Arrows.active[id] and id or nil
end

----------------------------------------------------------------------------
-- Ammo (kept in the power's own saved data, like the game's stock skills)

local function Ammo(pow)
	local pd = pow.persistdata
	if pd.skilllimits_ammo == nil or pd.skilllimits_ammo > Arrows.max then
		pd.skilllimits_ammo = Arrows.max
	end
	return pd.skilllimits_ammo
end
Arrows.Ammo = Ammo

-- The arrow skills this player has (their powers).
local function Owned(inst)
	local list = {}
	for id in pairs(Arrows.active) do
		local pow = Main.PowerOf(inst, id)
		if pow ~= nil and pow.persistdata ~= nil then
			list[#list + 1] = pow
		end
	end
	table.sort(list, function(a, b) return a.def.name < b.def.name end)
	return list
end

-- The powers whose arrows go together: with the shared quiver, every arrow
-- skill the player has; otherwise just that one.
local function Group(inst, id)
	if Arrows.shared then
		return Owned(inst)
	end
	local pow = Main.PowerOf(inst, id)
	return (pow ~= nil and pow.persistdata ~= nil) and { pow } or {}
end

-- The quivers: one (shared) or one per arrow skill.
local function Pools(inst)
	local owned = Owned(inst)
	if Arrows.shared then
		return #owned > 0 and { owned } or {}
	end
	local pools = {}
	for _, pow in ipairs(owned) do
		pools[#pools + 1] = { pow }
	end
	return pools
end

local function SetAmmo(pool, ammo, dmg)
	for _, pow in ipairs(pool) do
		pow.persistdata.skilllimits_ammo = ammo
		pow.persistdata.skilllimits_dmg = dmg
	end
end

-- Shared quiver: every arrow skill shows the same count (the lowest, e.g. a
-- skill picked up mid-run joins the quiver as it is).
local function Sync(inst)
	if not Arrows.shared or not Arrows.ammo_on then
		return
	end
	local owned = Owned(inst)
	local low, dmg
	for _, pow in ipairs(owned) do
		local a = Ammo(pow)
		if low == nil or a < low then
			low, dmg = a, pow.persistdata.skilllimits_dmg
		end
	end
	if low ~= nil then
		SetAmmo(owned, low, dmg)
	end
end
Arrows.Sync = Sync

-- the free dip's wait (seconds left), or nil when a free dip is ready
local function DipWait(inst)
	local timer = inst.components ~= nil and inst.components.timer or nil
	return timer ~= nil and timer:GetTimeRemaining(Arrows.FREE_DIP_TIMER) or nil
end

local function FreeDipReady(inst)
	return Arrows.free_dip ~= nil and (Arrows.free_dip == 0 or DipWait(inst) == nil)
end

-- An arrow skill that can't do anything right now: no arrows and no free dip.
local function Resting(inst, pow)
	return Arrows.ammo_on and Ammo(pow) <= 0 and not FreeDipReady(inst)
end

function Arrows.Show(inst, id)
	local pow = Main.PowerOf(inst, id)
	if pow ~= nil and pow.persistdata ~= nil and Arrows.ammo_on then
		local a = Ammo(pow)
		local st = Main.State(inst)
		local resting = Resting(inst, pow)
		local was = st.empty[id] == true
		if resting then
			-- the icon number: the seconds until the free dip (none if there's no free dip)
			local wait = DipWait(inst)
			st.empty[id] = true
			Main.SetCounter(inst, id, wait ~= nil and math.max(1, math.ceil(wait - 0.001)) or nil)
		else
			st.empty[id] = nil
			Main.SetCounter(inst, id, a > 0 and a or nil) -- the icon number (none at 0, like the game's)
		end
		if was ~= resting then
			inst:PushEvent("update_power", pow.def) -- (grey + X on / off)
		end
	end
end

local function ShowGroup(inst, id)
	for _, pow in ipairs(Group(inst, id)) do
		Arrows.Show(inst, pow.def.name)
	end
end

local function Fx(inst, name, params)
	local ok, powerutil = pcall(require, "util.powerutil")
	if ok and powerutil ~= nil and powerutil.SpawnFxOnEntity ~= nil then
		pcall(powerutil.SpawnFxOnEntity, name, inst, params)
	end
end

local function NoAmmo(inst)
	Fx(inst, "acquire_item_empty", { ischild = true, offy = 0 })
	if Main.settings.blocked_sound then
		Main.PlaySound(inst, "Skill_NoStock")
	end
end

local function Spend(inst, id)
	local pow = Main.PowerOf(inst, id)
	if pow == nil or pow.persistdata == nil then
		return
	end
	local left = math.max(0, Ammo(pow) - 1)
	local group = Group(inst, id)
	SetAmmo(group, left, pow.persistdata.skilllimits_dmg)
	ShowGroup(inst, id)
	Main.Debug(tostring(inst) .. " " .. id .. " arrow fired, " .. left .. " left")
end

-- A special arrow is being made: its arrow skill pays for it.
local function OnProjectilePrimed(inst, data)
	local params = type(data) == "table" and data.params or nil
	local pa = type(params) == "table" and params.primedarrow or nil
	if type(pa) == "table" and pa.attacktype == data.attack_type then
		local id = Arrows.BY_TYPE[pa.type]
		if id ~= nil and Arrows.active[id] then
			Spend(inst, id)
		end
	end
end

-- Damage dealt to enemies / breakable props earns arrows back.
local function OnDoDamage(inst, attack)
	if attack == nil or attack.GetDamage == nil or attack.GetTarget == nil then
		return
	end
	local target = attack:GetTarget()
	if target == nil or not target:IsValid()
		or not (target:HasTag("mob") or target:HasTag("prop_destructible") or target:HasTag("dummy")) then
		return
	end
	local damage = attack:GetDamage() or 0
	if damage <= 0 then
		return
	end
	for _, pool in ipairs(Pools(inst)) do
		local first = pool[1]
		local pd = first.persistdata
		local ammo = Ammo(first)
		if ammo < Arrows.max then
			local dmg = (pd.skilllimits_dmg or 0) + damage
			local gained = 0
			while dmg >= Arrows.per and ammo < Arrows.max do
				dmg = dmg - Arrows.per
				ammo = ammo + 1
				gained = gained + 1
			end
			if ammo >= Arrows.max then
				dmg = 0 -- full: no saving up (the game caps it too)
			end
			SetAmmo(pool, ammo, dmg)
			if gained > 0 then
				Fx(inst, "acquire_item_plus", { ischild = true, offy = -1, scalex = 1.5, scalez = 1.5 })
				if Main.settings.refill_sound then
					Main.PlaySound(inst, "Skill_NewStock")
				end
				for _, pow in ipairs(pool) do
					Arrows.Show(inst, pow.def.name)
				end
				Main.Debug(tostring(inst) .. " " .. first.def.name .. (#pool > 1 and " (shared)" or "") .. " +" .. gained .. " arrow, " .. ammo .. " now")
			end
		end
	end
end

local function ShowAll(inst)
	Sync(inst)
	for id in pairs(Arrows.active) do
		Arrows.Show(inst, id)
	end
end

local function OnAddPower(inst, pow)
	local def = type(pow) == "table" and pow.def or nil
	if def ~= nil and Arrows.active[def.name] then
		inst:DoTaskInTicks(1, function() ShowAll(inst) end)
	end
end

-- While the free dip is on its wait and the quiver is empty, the icons count
-- the seconds down (once a second).
local function StopDipTicking(st)
	if st.dip_tick ~= nil then
		st.dip_tick:Cancel()
		st.dip_tick = nil
	end
end

local function StartDipWait(inst)
	if Arrows.free_dip == nil or Arrows.free_dip <= 0 then
		return
	end
	local timer = inst.components.timer
	if timer == nil then
		return
	end
	timer:StartTimer(Arrows.FREE_DIP_TIMER, Arrows.free_dip, true)
	local st = Main.State(inst)
	StopDipTicking(st)
	st.dip_tick = inst:DoPeriodicTask(1, function() ShowAll(inst) end)
end

local function OnTimerDone(inst, data)
	if type(data) == "table" and data.name == Arrows.FREE_DIP_TIMER then
		local st = Main.State(inst)
		StopDipTicking(st)
		local empty = false
		for _, pow in ipairs(Owned(inst)) do
			if Ammo(pow) <= 0 then
				empty = true
			end
		end
		ShowAll(inst)
		if empty and Main.settings.refill_sound then
			Main.PlaySound(inst, "Skill_NewStock") -- the free dip is ready
		end
		Main.Debug(tostring(inst) .. " free dip ready")
	end
end

----------------------------------------------------------------------------
-- Instant mode: the quick shot

-- states of the quick shot before the arrow leaves
local QUICK_STATES = { turn_pre = true, turn_pst = true, heavy_attack_pre = true, heavy_attack_hold = true }

-- While the quick shot is held, the bow's "is heavy attack held?" check reads
-- the skill button (a Skill Slots slot press is a skill press too).
local function EndQuickShot(inst)
	local st = inst.skilllimits
	local q = st ~= nil and st.quick or nil
	if q == nil then
		return nil
	end
	st.quick = nil
	if q.pc ~= nil then
		rawset(q.pc, "IsControlHeld", q.prev)
	end
	return q
end

function Arrows.StartQuickShot(inst, id)
	local st = Main.State(inst)
	EndQuickShot(inst)
	local pc = inst.components.playercontroller
	-- an arrow already loaded by the game's dip: this shot carries it, whatever its strength
	local q = { id = id, pc = pc, preloaded = inst.sg ~= nil and inst.sg.mem.primedarrow ~= nil }
	if pc ~= nil then
		q.prev = rawget(pc, "IsControlHeld")
		local held = q.prev or getmetatable(pc).IsControlHeld
		rawset(pc, "IsControlHeld", function(self, control, ...)
			if control == "heavyattack" then
				return held(self, "skill", ...)
			end
			return held(self, control, ...)
		end)
	end
	st.quick = q
	if not q.preloaded then
		inst:PushEvent("bow_primearrow_fxstart") -- the arrow dip effect, from the skill itself
	end
end

-- Wrap the bow's heavy_attack_shoot once per stategraph: decide just before
-- the arrow is made, from the shot strength the game worked out.
local function PatchShoot(sgdef)
	local state = sgdef ~= nil and sgdef.states ~= nil and sgdef.states.heavy_attack_shoot or nil
	if state == nil or type(state.onenter) ~= "function" then
		return false
	end
	if rawget(state, "skilllimits_wrapped") then
		return true
	end
	local orig = state.onenter
	state.onenter = function(inst, data, ...)
		local q = EndQuickShot(inst)
		if q == nil or q.preloaded then
			return orig(inst, data, ...) -- the game's own shot (a loaded arrow goes out with it)
		end
		local focus = type(data) == "table" and data.shotstrength == "FOCUS"
		inst:PushEvent(focus and "bow_primearrow_ready" or "bow_primearrow_used")
		local results = table.pack(pcall(orig, inst, data, ...))
		if focus and inst.sg ~= nil and inst.sg.mem.primedarrow ~= nil then
			inst:PushEvent("bow_primearrow_used") -- no arrow came out: don't keep it for later
		end
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
	rawset(state, "skilllimits_wrapped", true)
	return true
end
Arrows.PatchShoot = PatchShoot

local function CanQuickShot(sg)
	return sg ~= nil and sg.sg ~= nil and sg:HasState("heavy_attack_pre") and sg:HasState("heavy_attack_hold")
		and PatchShoot(sg.sg)
end

-- states of an empty-quiver dip before its arrow is made (turning first, then
-- the game's dip state, which the arrow skills' own states reroute into)
local DIP_STATES = { turn_pre = true, turn_pst = true, skill_bow_primearrow = true }

-- The dip loaded its arrow ("bow_primearrow_ready", the dip's frame 14): a dip
-- made with no arrows left makes that one arrow.
local function OnPrimeReady(inst)
	local st = inst.skilllimits
	local id = st ~= nil and st.empty_dip or nil
	if id == nil then
		return
	end
	st.empty_dip = nil
	local pow = Main.PowerOf(inst, id)
	if pow ~= nil and pow.persistdata ~= nil and Ammo(pow) <= 0 then
		SetAmmo(Group(inst, id), 1, pow.persistdata.skilllimits_dmg)
		StartDipWait(inst)
		ShowGroup(inst, id)
		Main.Debug(tostring(inst) .. " " .. id .. " free dip: 1 arrow")
	end
end

local function OnNewState(inst, data)
	local st = inst.skilllimits
	if st ~= nil and st.empty_dip ~= nil and (data == nil or not DIP_STATES[data.statename]) then
		st.empty_dip = nil -- left the dip before the arrow was made
	end
	if st ~= nil and st.quick ~= nil and (data == nil or not QUICK_STATES[data.statename]) then
		local q = EndQuickShot(inst)
		if not q.preloaded then
			inst:PushEvent("bow_primearrow_used") -- cancelled (dodge, hit...): the dip effect goes
		end
	end
end

----------------------------------------------------------------------------

-- A press is sending the player to `name`. Returns nil (not an arrow skill:
-- carry on), nil, id (the game's dip), "block" (no arrows), or
-- "quick", id, turning (instant shot).
function Arrows.Check(inst, sg, name, params)
	local turning = name == "turn_pre" and type(params) == "table"
	local id = ArrowOf(name) or (turning and ArrowOf(params[1])) or nil
	if id == nil then
		return nil
	end
	local pow = Main.PowerOf(inst, id)
	if pow == nil or pow.persistdata == nil then
		return nil
	end
	if Arrows.ammo_on and Ammo(pow) <= 0 then
		if FreeDipReady(inst) then
			-- no arrows: the free dip (the game's dip, and the dip makes one)
			Main.State(inst).empty_dip = id
			return nil, id
		end
		NoAmmo(inst) -- the free dip is on its wait (or off)
		return "block", id
	end
	if Arrows.instant_on and CanQuickShot(sg) then
		return "quick", id, turning
	end
	return nil, id -- the game's dip (the arrow pays when it's fired)
end

function Arrows.SetupPlayer(inst)
	if not Arrows.Any() then
		return
	end
	if Arrows.ammo_on then
		inst:ListenForEvent("bow_primearrow_ready", OnPrimeReady)
		inst:ListenForEvent("projectile_primed", OnProjectilePrimed)
		inst:ListenForEvent("do_damage", OnDoDamage)
		inst:ListenForEvent("add_power", OnAddPower)
		inst:ListenForEvent("enter_room", ShowAll)
		inst:ListenForEvent("timerdone", OnTimerDone)
		inst:DoTaskInTime(0.5, function()
			ShowAll(inst)
			local st = Main.State(inst)
			if DipWait(inst) ~= nil and st.dip_tick == nil then -- (a wait carried into this room)
				st.dip_tick = inst:DoPeriodicTask(1, function() ShowAll(inst) end)
			end
		end)
	end
	inst:ListenForEvent("newstate", OnNewState)
end

return Arrows
