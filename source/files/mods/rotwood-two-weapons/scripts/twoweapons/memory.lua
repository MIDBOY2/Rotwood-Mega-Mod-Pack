-- Two Weapons: weapon memory. A swap doesn't reset (or refill) what each weapon
-- had going; it comes back when you swap back:
--  * gauges the weapon's stategraph keeps: Greatsword meter, Cannon ammo used
--    (a different weapon type gets a fresh stategraph, which zeroes them)
--  * powers that leave with the weapon and come back with it (the weapon's
--    skill, its equipment / gem powers, Skill Slots' per-weapon skills): their
--    saved data (skill stocks, counters) and their running numbers
--  * cooldown / buff timers that ran out while the weapon was away are played
--    out when it comes back (a skill whose cooldown ended is ready again)
-- The memory lasts for the run (saved between rooms) and is cleared when the
-- game resets your powers (new run, back to town).

local PowerManager = require "components.powermanager"

local Memory = {}

Memory.enabled = false

-- stategraph values kept per weapon type (stategraph "sg_player_<type>")
Memory.SG_KEYS = {
	cleaver = { "meter" },
	cannon = { "shots_fired" },
}

-- after putting the values back: let the game's own displays catch up
local SG_REFRESH = {
	cleaver = function(inst)
		local max = inst.sg:GetMem("meter_max")
		if type(max) == "number" then
			inst:PushEvent("cleaver_meter_changed", { new = inst.sg.mem.meter, old = 0, max = max })
		end
	end,
	cannon = function(inst)
		local SGPlayerCommon = require "stategraphs.sg_player_common"
		local fns = SGPlayerCommon.Fns or {}
		if fns.Cannon_UpdateAmmoSymbols ~= nil then
			fns.Cannon_UpdateAmmoSymbols(inst)
		end
		-- the dodge's invincibility follows the ammo left (less with none)
		if fns.Cannon_UpdateIframeModifier ~= nil and inst.components ~= nil and inst.components.playerroller ~= nil then
			pcall(fns.Cannon_UpdateIframeModifier, inst)
		end
	end,
}

-- The Cannon zeroes its ammo used on "loadout_changed" (sg_player_cannon's
-- ConfigureEquipmentStats: shots_fired = 0), and the game sends that event
-- right after a swap's new stategraph started (InventoryHoard:OnLoadoutChanged
-- equips, then pushes it). So what RestoreSG put back was a full reload again:
-- swapping away and back was a free reload. The values put back are applied
-- again right after that handler, once, during the swap.
Memory.RESET_ON_LOADOUT = { cannon = true }
Memory.PENDING_SECONDS = 1

local function Now()
	local fn = rawget(_G, "GetTime")
	return fn ~= nil and fn() or 0
end

local kept_logged = 0

-- power data fields that describe the power, not its progress
local PERSIST_SKIP = {
	id = true, slot = true, rarity = true, stacks = true, acquire_order = true, permanent = true,
	skillslots = true, temporary = true, defer_on_add_until_loading = true, ilvl = true, level = true,
}
-- running numbers that point at things in the world (projectiles in flight,
-- pending spawns, tasks, effects): never carried over
local MEM_SKIP = { "pending", "flight", "task", "fx", "target", "_id", "permanent" }

local function IsPlain(v)
	local t = type(v)
	return t == "number" or t == "boolean" or t == "string"
end

local function CopyPersist(src)
	local out = {}
	for k, v in pairs(src or {}) do
		if type(k) == "string" and IsPlain(v) and not PERSIST_SKIP[k] then
			out[k] = v
		end
	end
	return out
end

local function MemKeyOk(k)
	local lower = string.lower(k)
	for _, part in ipairs(MEM_SKIP) do
		if lower:find(part, 1, true) then
			return false
		end
	end
	return true
end

local function CopyMem(src)
	local out = {}
	for k, v in pairs(src or {}) do
		local t = type(v)
		if type(k) == "string" and (t == "number" or t == "boolean") and MemKeyOk(k) then
			out[k] = v
		end
	end
	return out
end

-- timers on the player that belong to this power ("<name>_cooldown", ...)
local function RunningTimers(inst, name)
	local timer = inst.components ~= nil and inst.components.timer or nil
	local list = {}
	if timer ~= nil and type(timer.timers) == "table" then
		for tname in pairs(timer.timers) do
			if type(tname) == "string" and tname:find(name, 1, true) then
				list[#list + 1] = tname
			end
		end
	end
	table.sort(list)
	return list
end

local function GetCmp(inst)
	local cmp = inst ~= nil and inst.components ~= nil and inst.components.twoweapons or nil
	if cmp ~= nil and cmp.memory ~= nil then
		return cmp
	end
	return nil
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		print("[Two Weapons] weapon memory error: " .. tostring(err))
	end
end

----------------------------------------------------------------------------
-- Powers

function Memory.SnapshotPower(cmp, pow)
	cmp.memory.powers[pow.def.name] = {
		persist = CopyPersist(pow.persistdata),
		mem = CopyMem(pow.mem),
		timers = RunningTimers(cmp.inst, pow.def.name),
	}
end

-- Before the power is added again: its saved data goes back first, so its own
-- setup sees it (e.g. a skill that already used a stock doesn't refill).
function Memory.PreRestore(cmp, power)
	local snap = cmp.memory.powers[power.id]
	if snap == nil then
		return nil
	end
	for k, v in pairs(snap.persist) do
		power[k] = v
	end
	return snap
end

function Memory.PostRestore(cmp, pm, name, snap)
	cmp.memory.powers[name] = nil
	local pow = pm.powers[name]
	if pow == nil then
		return
	end
	local inst = cmp.inst
	for k, v in pairs(snap.persist) do
		pow.persistdata[k] = v
	end
	pow.mem = pow.mem or {}
	for k, v in pairs(snap.mem) do
		pow.mem[k] = v
	end
	-- timers that ran out while the weapon was away
	local timer = inst.components ~= nil and inst.components.timer or nil
	local triggers = pow.def.event_triggers
	local done = triggers ~= nil and triggers.timerdone or nil
	if done ~= nil then
		for _, tname in ipairs(snap.timers or {}) do
			if timer == nil or not timer:HasTimer(tname) then
				local ok, err = pcall(done, pow, inst, { name = tname })
				if not ok then
					Report(err)
				end
			end
		end
	end
	inst:PushEvent("update_power", pow.def)
	if pow.persistdata.stocks_left ~= nil then
		inst:PushEvent("update_stock_counter", pow.def)
	end
end

local function HookPowers()
	local orig_remove = PowerManager.RemovePower
	PowerManager.RemovePower = function(self, power_def, force, ...)
		local cmp = Memory.enabled and GetCmp(self.inst) or nil
		if cmp ~= nil and power_def ~= nil and cmp:IsRemembering() then
			local pow = self.powers[power_def.name]
			if pow ~= nil and (force or not (power_def.permanent or (pow.mem ~= nil and pow.mem.permanent))) then
				local ok, err = pcall(Memory.SnapshotPower, cmp, pow)
				if not ok then
					Report(err)
				end
			end
		end
		return orig_remove(self, power_def, force, ...)
	end

	local orig_add = PowerManager._AddPowerInternal
	PowerManager._AddPowerInternal = function(self, power, ...)
		local cmp = Memory.enabled and GetCmp(self.inst) or nil
		local snap
		if cmp ~= nil and power ~= nil and power.id ~= nil and self.powers[power.id] == nil
			and cmp.memory.powers[power.id] ~= nil then
			local ok, res = pcall(Memory.PreRestore, cmp, power)
			snap = ok and res or nil
		end
		local results = table.pack(orig_add(self, power, ...))
		if snap ~= nil then
			local ok, err = pcall(Memory.PostRestore, cmp, self, power.id, snap)
			if not ok then
				Report(err)
			end
		end
		return table.unpack(results, 1, results.n)
	end

	-- new run / back to town: start fresh
	local orig_reset = PowerManager.ResetData
	local function Fresh(self)
		local cmp = GetCmp(self.inst)
		if cmp ~= nil then
			cmp:ClearMemory()
		end
	end
	PowerManager.ResetData = function(self, ...)
		local results = table.pack(orig_reset(self, ...))
		local G = package.loaded["twoweapons.main"] ~= nil and package.loaded["twoweapons.main"].G or nil
		if G ~= nil then
			G.Call("new run: forget the other weapon's powers", Fresh, self)
		else
			Fresh(self)
		end
		return table.unpack(results, 1, results.n)
	end
end

----------------------------------------------------------------------------
-- Stategraph gauges

local function WeaponOfSG(inst)
	local name = inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.name or nil
	return type(name) == "string" and name:match("^sg_player_(.+)$") or nil
end

function Memory.SaveSG(cmp)
	local inst = cmp.inst
	local weapon = WeaponOfSG(inst)
	local keys = weapon ~= nil and Memory.SG_KEYS[weapon] or nil
	if keys == nil then
		return
	end
	local saved = {}
	for _, k in ipairs(keys) do
		local v = inst.sg.mem[k]
		if IsPlain(v) then
			saved[k] = v
		end
	end
	cmp.memory.sg[weapon] = saved
end

function Memory.RestoreSG(cmp)
	local inst = cmp.inst
	local weapon = WeaponOfSG(inst)
	local saved = weapon ~= nil and cmp.memory.sg[weapon] or nil
	if saved == nil then
		return
	end
	cmp.memory.sg[weapon] = nil
	for k, v in pairs(saved) do
		inst.sg.mem[k] = v
	end
	local refresh = SG_REFRESH[weapon]
	if refresh ~= nil then
		refresh(inst)
	end
	if Memory.RESET_ON_LOADOUT[weapon] then
		cmp.memory_pending = { weapon = weapon, values = saved, t = Now() }
	end
end

-- after the stategraph's own "loadout_changed" handler: the values again
function Memory.ReapplyAfterLoadout(inst)
	local cmp = GetCmp(inst)
	local pending = cmp ~= nil and cmp.memory_pending or nil
	if pending == nil then
		return
	end
	cmp.memory_pending = nil
	if WeaponOfSG(inst) ~= pending.weapon or Now() - pending.t > Memory.PENDING_SECONDS then
		return
	end
	for k, v in pairs(pending.values) do
		inst.sg.mem[k] = v
	end
	local refresh = SG_REFRESH[pending.weapon]
	if refresh ~= nil then
		refresh(inst)
	end
	if kept_logged < 10 and pending.weapon == "cannon" then
		kept_logged = kept_logged + 1
		local SGPlayerCommon = require "stategraphs.sg_player_common"
		local fns = SGPlayerCommon.Fns or {}
		local left = fns.Cannon_GetRemainingAmmo ~= nil and select(2, pcall(fns.Cannon_GetRemainingAmmo, inst)) or nil
		local max = fns.Cannon_GetMaxAmmo ~= nil and select(2, pcall(fns.Cannon_GetMaxAmmo, inst)) or nil
		print(string.format("[Two Weapons] Cannon ammo kept through the swap: %s of %s", tostring(left), tostring(max)))
	end
end

-- AddStateGraphPostInit for the stategraphs in RESET_ON_LOADOUT: wraps their
-- "loadout_changed" handlers. Returns how many were wrapped.
function Memory.PostInitSG(sg)
	local list = type(sg) == "table" and type(sg.events) == "table" and sg.events.loadout_changed or nil
	if type(list) ~= "table" then
		return 0
	end
	if list.fn ~= nil then -- a single handler, not a list
		list = { list }
	end
	local wrapped = 0
	for _, h in pairs(list) do
		if type(h) == "table" and type(h.fn) == "function" then
			if not h.twoweapons_memory then
				h.twoweapons_memory = true
				local orig = h.fn
				h.fn = function(inst, ...)
					local results = table.pack(orig(inst, ...))
					local ok, err = pcall(Memory.ReapplyAfterLoadout, inst)
					if not ok then
						Report(err)
					end
					return table.unpack(results, 1, results.n)
				end
			end
			wrapped = wrapped + 1
		end
	end
	return wrapped
end

local function HookStateGraph(ES)
	local orig = ES.SetStateGraph
	ES.SetStateGraph = function(self, ...)
		local cmp = Memory.enabled and GetCmp(self) or nil
		if cmp == nil then
			return orig(self, ...)
		end
		local ok, err = pcall(Memory.SaveSG, cmp)
		if not ok then
			Report(err)
		end
		local results = table.pack(orig(self, ...))
		ok, err = pcall(Memory.RestoreSG, cmp)
		if not ok then
			Report(err)
		end
		return table.unpack(results, 1, results.n)
	end
end

----------------------------------------------------------------------------

-- Returns true, or false + what's missing.
function Memory.Install()
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
	Memory.enabled = true
	return true
end

return Memory
