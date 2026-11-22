-- Two Weapons: charged skills and their glow across swaps.
--
--  * Glow: a skill's weapon glow is kept in the weapon stategraph, and a swap
--    to another weapon type starts a new stategraph, so the game lost track of
--    it: the skill could never turn it off (stuck forever). The glows now move
--    to the new stategraph.
--  * Charged skills follow you: a skill charged up and waiting for its trigger
--    (Unstable Equilibrium: the next Heavy Attack that hits explodes) keeps the
--    charge after a swap, and the other weapon sets it off. Once spent, it's
--    gone (the weapon it belongs to comes back without it); swapping back
--    before that brings it home, still charged.
--  * Swapping back to a weapon whose skill is still charged (one that can't
--    go to another weapon, like the Bow's primed arrows) brings its glow back
--    and readies it again.

local PowerManager = require "components.powermanager"

local Carry = {}

Carry.enabled = false -- glow and swap-back fixes
Carry.follow = false -- charged skills go to the other weapon (setting carry_charges)

local function Glow(pfx, symbol, offz)
	return function(pow, inst)
		local powerutil = require "util.powerutil"
		powerutil.AttachParticleSystemToSymbol(pow, inst, pfx, symbol, { offz = offz })
	end
end

-- skills whose charge goes to the other weapon:
--   charged(pow): waiting for its trigger
--   events: its own game events that keep running with the other weapon (the
--     ones that set it off or end it; never the skill button or room ones)
--   only[event](data): that event only counts when this says so
--   glow(pow, inst): puts its glow back (after a room change)
--   timer: a timed one; gone if this timer is (it ends on its own)
--   update: its per-frame part keeps running (the Thatcher weapon pulse)
Carry.SPECS = {
	-- Unstable Equilibrium: the next Heavy Attack that hits explodes
	-- (sheathing cancels it, like on the Hammer)
	hammer_explodingheavy = {
		charged = function(pow) return pow.persistdata.active == true end,
		events = { "do_damage", "sheathe_weapon" },
		-- (its clean-up runs on any sheathe event, drawing included; only a real
		-- sheathe ends it)
		only = { sheathe_weapon = function(enabled) return enabled == true end },
		glow = Glow("unstable_equilibrium_trail", "swap_fx", -0.1),
	},
	-- Eggsplosion (Eggzy): the next hit makes the egg explosion
	boss_eggzy = {
		charged = function(pow) return pow.mem.active == true end,
		events = { "do_damage" },
		glow = Glow("eggzy_weapon_trail", "swap_fx"),
	},
	-- Voice of the Myriad (Thatcher): poison on your attacks while it's active (a few seconds)
	boss_thatcher = {
		charged = function(pow) return pow.mem.active == true end,
		events = { "do_damage", "timerdone", "boss_thatcher_deactivate" },
		glow = function(pow, inst)
			local id = inst.GetHunterId ~= nil and inst:GetHunterId() or nil
			if id ~= nil then
				Glow("player_power_thatcher_weapon_trail_p" .. id, "swap_fx")(pow, inst)
			end
		end,
		timer = "boss_thatcher_active",
		update = true,
		extra_glow = { "boss_thatcher_weapon_specific_particles" },
	},
}

-- skills that stay with their weapon: what brings them back when you swap back
-- still charged ("enter_room": the game's own, for coming into a new room)
Carry.REFRESH = {
	hammer_explodingheavy = "enter_room",
	bow_primearrow_acid = "enter_room",
	bow_primearrow_cold = "enter_room",
	bow_primearrow_explode = "enter_room",
	cleaver_swagger_slash = "enter_room",
	-- Critical Draw: its glow while the bonus waits for the next attack
	cleaver_sheathe_weapon = function(pow, inst)
		if pow.mem.buff_ready and not pow.mem.pfx then
			local powerutil = require "util.powerutil"
			local symbol = inst.sg ~= nil and inst.sg.mem.sheathed and "weapon_back01" or "swap_fx2"
			pow.mem.pfx = powerutil.AttachParticleSystemToSymbol(pow, inst, "eggsaber_critical_draw_trail", symbol) or true
		end
	end,
}

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		print("[Two Weapons] charged skill error: " .. tostring(err))
	end
end

local function GetCmp(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.twoweapons or nil
end

local function Memory()
	local M = package.loaded["twoweapons.memory"]
	return type(M) == "table" and M.enabled and M or nil
end

local function GlowNames(pow, spec)
	local names = { pow.def.name .. "_particles" }
	for _, n in ipairs(spec ~= nil and spec.extra_glow or {}) do
		names[#names + 1] = n
	end
	return names
end

local function Particles(inst)
	local mem = inst.sg ~= nil and inst.sg.mem or nil
	return mem ~= nil and mem.autogen_particles or nil
end

local function IsCharged(pow, spec)
	local ok, res = pcall(spec.charged, pow)
	return ok and res == true
end

local function StopGlow(inst, pow, spec)
	local ParticleSystemHelper = require "util.particlesystemhelper"
	for _, n in ipairs(GlowNames(pow, spec)) do
		pcall(ParticleSystemHelper.MakeEventStopParticles, inst, { name = n })
	end
end

----------------------------------------------------------------------------
-- Carried charges (one per skill, per player): cmp.carried[name] = ghost

function Carry.Drop(cmp, name, why)
	local ghost = cmp.carried ~= nil and cmp.carried[name] or nil
	if ghost == nil then
		return
	end
	cmp.carried[name] = nil
	local inst = cmp.inst
	for ev, fn in pairs(ghost.listeners) do
		inst:RemoveEventCallback(ev, fn)
	end
	if ghost.task ~= nil then
		ghost.task:Cancel()
		ghost.task = nil
	end
	local pow, spec = ghost.pow, ghost.spec
	if why == "spent" and spec.update and pow.def.on_update_fn ~= nil then
		-- one last update so its look switches off (the Thatcher pulse)
		pcall(pow.def.on_update_fn, pow, inst, 0)
	end
	-- the weapon it belongs to remembers where it's at
	local M = Memory()
	if M ~= nil and cmp.memory ~= nil and cmp.memory.powers[name] ~= nil then
		local ok, err = pcall(M.SnapshotPower, cmp, pow)
		if not ok then
			Report(err)
		end
	end
	if why == "reset" or why == "lost" then
		StopGlow(inst, pow, spec)
	end
end

function Carry.DropAll(cmp, why)
	for name in pairs(cmp.carried or {}) do
		Carry.Drop(cmp, name, why)
	end
end

function Carry.Keep(cmp, pow, spec)
	local inst = cmp.inst
	local name = pow.def.name
	cmp.carried = cmp.carried or {}
	Carry.Drop(cmp, name, "replaced")
	local ghost = { pow = pow, spec = spec, listeners = {} }
	cmp.carried[name] = ghost
	local triggers = pow.def.event_triggers or {}
	for _, ev in ipairs(spec.events) do
		local fn = triggers[ev]
		local only = spec.only ~= nil and spec.only[ev] or nil
		if fn ~= nil then
			local function listener(inst, ...)
				if cmp.carried == nil or cmp.carried[name] ~= ghost then
					return
				end
				if only ~= nil and not only(...) then
					return
				end
				local ok, err = pcall(fn, pow, inst, ...)
				if not ok then
					Report(err)
				end
				if cmp.carried ~= nil and cmp.carried[name] == ghost and not IsCharged(pow, spec) then
					Carry.Drop(cmp, name, "spent")
				end
			end
			ghost.listeners[ev] = listener
			inst:ListenForEvent(ev, listener)
		end
	end
	if spec.update and pow.def.on_update_fn ~= nil and inst.DoPeriodicTicksTask ~= nil then
		local dt = rawget(_G, "TICKS") or 1 / 60
		ghost.task = inst:DoPeriodicTicksTask(1, function(inst)
			if cmp.carried == nil or cmp.carried[name] ~= ghost then
				return
			end
			local ok, err = pcall(pow.def.on_update_fn, pow, inst, dt)
			if not ok then
				Report(err)
				if ghost.task ~= nil then
					ghost.task:Cancel()
					ghost.task = nil
				end
			end
		end)
	end
	if cmp.settings ~= nil and cmp.settings.debug then
		print("[Two Weapons] debug: " .. name .. " stays charged on the other weapon")
	end
	return ghost
end

-- for the save between rooms
local function Plain(v)
	local t = type(v)
	return t == "number" or t == "boolean" or t == "string"
end
local PERSIST_SKIP = { id = true, slot = true, stacks = true, acquire_order = true, permanent = true, skillslots = true,
	temporary = true, defer_on_add_until_loading = true, ilvl = true, level = true }

function Carry.Save(cmp)
	local out
	for name, ghost in pairs(cmp.carried or {}) do
		local persist, mem = {}, {}
		for k, v in pairs(ghost.pow.persistdata or {}) do
			if type(k) == "string" and Plain(v) and not PERSIST_SKIP[k] then
				persist[k] = v
			end
		end
		for k, v in pairs(ghost.pow.mem or {}) do
			if type(k) == "string" and (type(v) == "number" or type(v) == "boolean") then
				mem[k] = v
			end
		end
		out = out or {}
		out[name] = { persist = persist, mem = mem }
	end
	return out
end

-- after a room change: the charges come back with their glow
function Carry.Load(cmp, saved)
	local inst = cmp.inst
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	if not Carry.follow or pm == nil or type(saved) ~= "table" then
		return
	end
	local Power = require "defs.powers.power"
	for name, data in pairs(saved) do
		local spec = Carry.SPECS[name]
		local timer = inst.components.timer
		if spec ~= nil and type(data) == "table" and pm.powers[name] == nil
			and (spec.timer == nil or (timer ~= nil and timer:HasTimer(spec.timer))) then
			local ok, err = pcall(function()
				local def = Power.FindPowerByName(name)
				local power = pm:CreatePower(def, type(data.persist) == "table" and data.persist.rarity or nil)
				for k, v in pairs(data.persist or {}) do
					if k ~= "rarity" then
						power[k] = v
					end
				end
				local pow = Power.PowerInstance(power)
				pow:SetOwner(inst)
				for k, v in pairs(data.mem or {}) do
					pow.mem[k] = v
				end
				if IsCharged(pow, spec) then
					Carry.Keep(cmp, pow, spec)
					if spec.glow ~= nil then
						spec.glow(pow, inst)
					end
				end
			end)
			if not ok then
				Report(err)
			end
		end
	end
end

----------------------------------------------------------------------------
-- Hooks

local function HookPowers()
	local orig_remove = PowerManager.RemovePower
	PowerManager.RemovePower = function(self, power_def, force, ...)
		local inst = self.inst
		local cmp = Carry.follow and GetCmp(inst) or nil
		local pow = cmp ~= nil and power_def ~= nil and self.powers[power_def.name] or nil
		local spec = pow ~= nil and Carry.SPECS[power_def.name] or nil
		if spec == nil or not cmp:IsRemembering() or not IsCharged(pow, spec)
			or ((power_def.permanent or (pow.mem ~= nil and pow.mem.permanent)) and not force) then
			return orig_remove(self, power_def, force, ...)
		end
		-- it leaves with the weapon, charged: keep its glow out of the clean-up
		-- and its charge as it is (Thatcher's clean-up switches it off)
		local kept = {}
		local parts = Particles(inst)
		for _, n in ipairs(GlowNames(pow, spec)) do
			if parts ~= nil and parts[n] ~= nil then
				kept[n] = parts[n]
				parts[n] = nil
			end
		end
		local mem = {}
		for k, v in pairs(pow.mem or {}) do
			mem[k] = v
		end
		local results = table.pack(orig_remove(self, power_def, force, ...))
		local ok, err = pcall(function()
			if inst.sg ~= nil and inst.sg.mem ~= nil and next(kept) ~= nil then
				inst.sg.mem.autogen_particles = inst.sg.mem.autogen_particles or {}
				for n, p in pairs(kept) do
					if p.IsValid ~= nil and p:IsValid() then
						inst.sg.mem.autogen_particles[n] = p
					end
				end
			end
			if self.powers[power_def.name] == nil then
				for k, v in pairs(mem) do
					pow.mem[k] = v
				end
				Carry.Keep(cmp, pow, spec)
			end
		end)
		if not ok then
			Report(err)
		end
		return table.unpack(results, 1, results.n)
	end

	local orig_add = PowerManager._AddPowerInternal
	PowerManager._AddPowerInternal = function(self, power, ...)
		local inst = self.inst
		local cmp = Carry.enabled and GetCmp(inst) or nil
		local name = power ~= nil and power.id or nil
		local back = false
		if cmp ~= nil and name ~= nil and self.powers[name] == nil then
			local M = Memory()
			if cmp.carried ~= nil and cmp.carried[name] ~= nil then
				-- back on its own weapon: it takes over, glow and all (without weapon
				-- memory it comes back fresh, so the glow goes)
				Carry.Drop(cmp, name, M ~= nil and "back" or "lost")
			end
			back = M ~= nil and cmp.memory ~= nil and cmp.memory.powers[name] ~= nil
		end
		local results = table.pack(orig_add(self, power, ...))
		local refresh = back and Carry.REFRESH[name] or nil
		local pow = refresh ~= nil and self.powers[name] or nil
		if pow ~= nil then
			local ok, err = pcall(function()
				local skillstate = inst.sg ~= nil and inst.sg.mem.skillstate or nil
				if type(refresh) == "function" then
					refresh(pow, inst)
				else
					local fn = pow.def.event_triggers ~= nil and pow.def.event_triggers[refresh] or nil
					if fn ~= nil then
						fn(pow, inst, {})
					end
				end
				-- the game's room-entry part also picks the skill for B; B stays as it was
				if inst.sg ~= nil then
					inst.sg.mem.skillstate = skillstate
				end
			end)
			if not ok then
				Report(err)
			end
		end
		return table.unpack(results, 1, results.n)
	end

	local orig_reset = PowerManager.ResetData
	PowerManager.ResetData = function(self, ...)
		local cmp = GetCmp(self.inst)
		if cmp ~= nil and cmp.carried ~= nil then
			pcall(Carry.DropAll, cmp, "reset")
		end
		return orig_reset(self, ...)
	end
end

-- the glows move to the new stategraph (a swap to another weapon type), and a
-- drawn weapon stays drawn: a fresh stategraph doesn't know, and its first
-- attack would announce "drawn" again, which some skills take as the end of
-- their charge (Unstable Equilibrium)
local function HookStateGraph(ES)
	local orig = ES.SetStateGraph
	ES.SetStateGraph = function(self, ...)
		local cmp = Carry.enabled and GetCmp(self) or nil
		local mem = cmp ~= nil and self.sg ~= nil and self.sg.mem or nil
		local old = mem ~= nil and mem.autogen_particles or nil
		local exit = mem ~= nil and mem.autogen_stopparticles or nil
		local was_drawn = mem ~= nil and mem.sheathed == false
		local results = table.pack(orig(self, ...))
		if mem ~= nil then
			local ok, err = pcall(function()
				local new = self.sg ~= nil and self.sg.mem or nil
				if new == nil or new == mem then
					return
				end
				if was_drawn and new.sheathed == nil then
					new.sheathed = false
				end
				for n, p in pairs(old or {}) do
					-- the lasting ones (not the ones an attack ends with it)
					if type(n) == "string" and type(p) == "table" and p.IsValid ~= nil and p:IsValid()
						and not (exit ~= nil and exit[p]) then
						new.autogen_particles = new.autogen_particles or {}
						if new.autogen_particles[n] == nil then
							new.autogen_particles[n] = p
						end
					end
				end
			end)
			if not ok then
				Report(err)
			end
		end
		return table.unpack(results, 1, results.n)
	end
end

-- Returns true, or false + what's missing.
function Carry.Install(follow)
	local need = { "RemovePower", "_AddPowerInternal", "ResetData" }
	for _, fn in ipairs(need) do
		if type(PowerManager[fn]) ~= "function" then
			return false, "PowerManager:" .. fn
		end
	end
	local ES = rawget(_G, "EntityScript")
	if type(ES) ~= "table" or type(ES.SetStateGraph) ~= "function" then
		return false, "EntityScript:SetStateGraph"
	end
	HookPowers()
	HookStateGraph(ES)
	Carry.enabled = true
	Carry.follow = follow ~= false
	return true
end

return Carry
