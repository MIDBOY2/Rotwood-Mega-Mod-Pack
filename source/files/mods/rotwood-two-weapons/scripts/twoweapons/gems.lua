-- Two Weapons: both weapons' gems.
--
-- The game only counts the gems of the weapon in your hand (a swap really
-- equips the other weapon), so with two weapons your max health, healing,
-- protection, luck and so on went up and down with every swap, and the gems on
-- the weapon you weren't holding did nothing.
--
-- Here the gems of the types in the settings (both_weapons_gems; Sustain and
-- Support to start) count from BOTH weapons, whichever one is in your hand:
--  * gem powers (Healing Gem, Alchemist's Gem, Regen, protections, ...): they
--    live under their own entry in the game's equipment powers
--    (powers_from_equipment[Gems.KEY]) instead of the weapon's, so a swap
--    doesn't take them away and give them back (no reset: Regen doesn't start
--    over, counters keep going). Both weapons' gems are listed in a fixed
--    order, so the list only changes when your gems or your two weapons do.
--  * gem stats (Max Health Gem, Luck Gem): the other weapon's are added where
--    the game adds up your equipment's stats (InventoryHoard:ComputeStats);
--    the weapon in hand already has its own in its stats.
-- The same gem on both weapons adds up, like two of it on one weapon.
-- Gems of other types (Damage, to start) stay with their weapon: they're
-- about how that weapon hits.

local Gems = {}

Gems.KEY = "TWOWEAPONS_GEMS"
Gems.SLOT = "WEAPON"
Gems.types = {}
Gems.enabled = false

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		print("[Two Weapons] both weapons' gems error: " .. tostring(err))
	end
end

-- settings: both_weapons_gems = { sustain = true, support = true, damage = false } (false = off)
function Gems.Configure(setting)
	Gems.types = {}
	if type(setting) ~= "table" then
		return false
	end
	local any = false
	for _, name in ipairs({ "sustain", "support", "damage" }) do
		if setting[name] == true then
			Gems.types[string.upper(name)] = true
			any = true
		end
	end
	return any
end

function Gems.Kept(def)
	return def ~= nil and type(def.gem_type) == "string" and Gems.types[def.gem_type] == true
end

-- Gems that act on the weapon they sit in, so they always stay with it: the
-- Teffressence Container (boss_soul) imbues the weapon in hand and takes
-- itself out of that weapon (craftingutil.ChargeNormalWeapon); counted from
-- the other weapon it would imbue the one in hand and never be used up.
Gems.WITH_WEAPON = { boss_soul = true }

function Gems.KeptGem(gem)
	if gem == nil then
		return false
	end
	local def = gem:GetDef()
	local id = rawget(gem, "id") or (def ~= nil and def.name) or nil
	if id ~= nil and Gems.WITH_WEAPON[id] then
		return false
	end
	return Gems.Kept(def)
end

local function Other(inst)
	local cmp = inst ~= nil and inst.components ~= nil and inst.components.twoweapons or nil
	if cmp == nil or cmp.GetOther == nil then
		return nil
	end
	local ok, other = pcall(cmp.GetOther, cmp)
	return ok and other or nil
end
Gems.Other = Other

local function Slots(item)
	if item == nil or item.GetGemSlots == nil then
		return {}
	end
	local ok, slots = pcall(item.GetGemSlots, item)
	return (ok and type(slots) == "table") and slots or {}
end

local function Matched(slot_type, gem_type)
	local ok, craftingutil = pcall(require, "util.craftingutil")
	if ok and craftingutil.IsGemTypeMatchedWithSlot ~= nil then
		return craftingutil.IsGemTypeMatchedWithSlot(slot_type, gem_type) == true
	end
	return slot_type ~= nil and (slot_type == gem_type or slot_type == "ANY")
end

-- the kept gems' powers on one weapon, as the game lists equipment powers
local function PowerEntries(item, out)
	for _, slot in ipairs(Slots(item)) do
		local gem = slot.GetGem ~= nil and slot:GetGem() or nil
		local def = gem ~= nil and gem:GetDef() or nil
		if Gems.KeptGem(gem) and def.usage_data ~= nil and def.usage_data.power_on_equip ~= nil then
			local bonus = Matched(slot:GetSlotType(), def.gem_type)
			if def.tags ~= nil and def.tags.hide_slot_bonus then
				bonus = false
			end
			out[#out + 1] = { name = def.usage_data.power_on_equip, level = gem:GetUpgradeLevel() or 1, slot_bonus_active = bonus }
		end
	end
end

-- both weapons' kept gem powers, in an order that doesn't depend on which
-- weapon is in hand
function Gems.KeptPowers(held, other)
	local list = {}
	PowerEntries(held, list)
	if other ~= nil and other ~= held then
		PowerEntries(other, list)
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.level ~= b.level then
			return a.level < b.level
		end
		return (a.slot_bonus_active and 1 or 0) < (b.slot_bonus_active and 1 or 0)
	end)
	return list
end

local function Same(a, b)
	a, b = a or {}, b or {}
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		local x, y = a[i], b[i]
		if x.name ~= y.name or x.level ~= y.level or (x.slot_bonus_active == true) ~= (y.slot_bonus_active == true) then
			return false
		end
	end
	return true
end

-- the weapon in hand's slots with the kept gems taken out (for the game's own
-- list of the weapon's powers)
local function HideKept(item)
	if item == nil or rawget(item, "twoweapons_hiding") then
		return function() end
	end
	local real = Slots(item)
	local shown = {}
	for i, slot in ipairs(real) do
		local gem = slot.GetGem ~= nil and slot:GetGem() or nil
		if gem ~= nil and Gems.KeptGem(gem) then
			shown[i] = setmetatable({ GetGem = function() return nil end }, { __index = slot })
		else
			shown[i] = slot
		end
	end
	local before = rawget(item, "GetGemSlots") -- (the game's is the class's: nil here)
	rawset(item, "twoweapons_hiding", true)
	rawset(item, "GetGemSlots", function() return shown end)
	return function()
		rawset(item, "GetGemSlots", before)
		rawset(item, "twoweapons_hiding", nil)
	end
end

function Gems.ApplyKept(pm, list)
	local current = pm:GetEquipmentPowers(Gems.KEY)
	if Same(list, current) then
		return false
	end
	if current ~= nil then
		pm:RemoveEquipmentPowers(Gems.KEY, current)
	end
	for _, data in ipairs(list) do
		pm:AddEquipmentPower(Gems.KEY, data)
	end
	return true
end

-- the setting turned off: the kept powers go back to the weapon (the game's
-- next list of the weapon's powers has them again)
function Gems.ClearKept(pm)
	local current = pm:GetEquipmentPowers(Gems.KEY)
	if current ~= nil then
		pm:RemoveEquipmentPowers(Gems.KEY, current)
	end
end

-- the other weapon's kept gems' stats (stat_mods + the matching slot's bonus,
-- as the game adds a gem's stats to its weapon)
function Gems.OtherStats(other)
	local add = {}
	for _, slot in ipairs(Slots(other)) do
		local mounts = slot.GemMounts ~= nil and { slot:GemMounts() } or nil
		local list = {}
		if mounts ~= nil and type(mounts[1]) == "function" then
			for _, mount in slot:GemMounts() do
				list[#list + 1] = { mount = mount, slot_type = slot.slot_type or (slot.GetSlotType ~= nil and slot:GetSlotType()) }
			end
		else
			list[1] = { mount = slot, slot_type = slot.GetSlotType ~= nil and slot:GetSlotType() or slot.slot_type }
		end
		for _, m in ipairs(list) do
			local gem = m.mount.GetGem ~= nil and m.mount:GetGem() or nil
			local def = gem ~= nil and gem:GetDef() or nil
			if Gems.KeptGem(gem) and type(def.stat_mods) == "table" then
				local lvl = gem.GetItemLevel ~= nil and gem:GetItemLevel() or gem.ilvl or 1
				if def.max_ilvl ~= nil and lvl > def.max_ilvl then
					lvl = def.max_ilvl
				end
				for stat, values in pairs(def.stat_mods) do
					local v = type(values) == "table" and values[lvl] or nil
					if type(v) == "number" then
						add[stat] = (add[stat] or 0) + v
					end
				end
				if (m.slot_type == def.gem_type or m.slot_type == "ANY") and type(def.stat_mods_slot_bonus) == "table" then
					for stat, v in pairs(def.stat_mods_slot_bonus) do
						if type(v) == "number" then
							add[stat] = (add[stat] or 0) + v
						end
					end
				end
			end
		end
	end
	return add
end

function Gems.Install(settings)
	local on = Gems.Configure(settings.both_weapons_gems)
	local PowerManager = require "components.powermanager"
	local InventoryHoard = require "components.inventoryhoard"
	for _, need in ipairs({ { PowerManager, "OnLoadoutChanged" }, { PowerManager, "GetEquipmentPowers" }, { PowerManager, "AddEquipmentPower" },
		{ PowerManager, "RemoveEquipmentPowers" }, { InventoryHoard, "ComputeStats" }, { InventoryHoard, "GetEquippedItem" } }) do
		if type(need[1][need[2]]) ~= "function" then
			return false, "a game update changed " .. need[2]
		end
	end
	local main = package.loaded["twoweapons.main"]
	local G = type(main) == "table" and main.G or nil
	local function Call(what, fn, ...)
		if G ~= nil then
			return G.Call(what, fn, ...)
		end
		return pcall(fn, ...)
	end

	local orig_powers = PowerManager.OnLoadoutChanged
	PowerManager.OnLoadoutChanged = function(self, ...)
		local inv = self.inst ~= nil and self.inst.components ~= nil and self.inst.components.inventoryhoard or nil
		local cmp = self.inst ~= nil and self.inst.components ~= nil and self.inst.components.twoweapons or nil
		if not Gems.enabled or inv == nil or cmp == nil then
			-- off (or turned off since the save): gem powers kept from before
			-- go back to the weapon (the game's list below has them again)
			if self.GetEquipmentPowers ~= nil and self:GetEquipmentPowers(Gems.KEY) ~= nil then
				Call("both weapons' gems: back to the weapon", Gems.ClearKept, self)
			end
			return orig_powers(self, ...)
		end
		local held = inv:GetEquippedItem(Gems.SLOT)
		local restore = function() end
		local okh, r = pcall(HideKept, held)
		if okh then
			restore = r
		else
			Report(r)
		end
		local results = table.pack(pcall(orig_powers, self, ...))
		restore()
		if not results[1] then
			error(results[2], 0)
		end
		Call("both weapons' gems: powers", function()
			Gems.ApplyKept(self, Gems.KeptPowers(held, Other(self.inst)))
		end)
		return table.unpack(results, 2, results.n)
	end

	local orig_stats = InventoryHoard.ComputeStats
	InventoryHoard.ComputeStats = function(self, ...)
		local stats = orig_stats(self, ...)
		if Gems.enabled and type(stats) == "table" and self.inst ~= nil then
			Call("both weapons' gems: stats", function()
				local other = Other(self.inst)
				if other ~= nil and other ~= self:GetEquippedItem(Gems.SLOT) then
					for stat, v in pairs(Gems.OtherStats(other)) do
						if rawget(stats, stat) ~= nil then
							stats[stat] = stats[stat] + v
						end
					end
				end
			end)
		end
		return stats
	end

	Gems.enabled = on
	if not on then
		return false, "off"
	end
	local names = {}
	for _, name in ipairs({ "SUSTAIN", "SUPPORT", "DAMAGE" }) do
		if Gems.types[name] then
			names[#names + 1] = name:sub(1, 1) .. name:sub(2):lower()
		end
	end
	return true, table.concat(names, " + ")
end

-- After the other weapon is known (loaded from the save, a mannequin loadout)
-- without a loadout change: stats and powers worked out again, the way the
-- game's InventoryHoard:OnLoadoutChanged sets them (without equipping again).
function Gems.Refresh(inst)
	if not Gems.enabled or inst == nil or inst.components == nil then
		return
	end
	local c = inst.components
	local inv = c.inventoryhoard
	if inv == nil then
		return
	end
	local stats = inv:ComputeStats()
	local name = "equipment_stats"
	local function Set(cmp, fn, ...)
		if cmp ~= nil and type(cmp[fn]) == "function" then
			local ok, err = pcall(cmp[fn], cmp, ...)
			if not ok then
				Report(err)
			end
		end
	end
	Set(c.health, "SetBaseMaxHealth", stats.HP, true)
	Set(c.combat, "SetBaseDamage", name, stats.DMG)
	Set(c.combat, "SetCritChanceModifier", name, stats.CRIT)
	Set(c.combat, "SetCritDamageMult", name, stats.CRIT_MULT)
	Set(c.combat, "SetFocusDamageMult", name, stats.FOCUS_MULT)
	Set(c.locomotor, "AddSpeedMult", name, stats.SPEED)
	Set(c.lucky, "AddLuckMod", name, stats.LUCK)
	Set(c.combat, "SetDungeonTierDamageReductionMult", name, stats.ARMOUR)
	if c.damagebonus ~= nil then
		c.damagebonus.cached_stats = stats
	end
	if c.powermanager ~= nil then
		c.powermanager:OnLoadoutChanged()
	end
end

return Gems
