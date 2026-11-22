-- Save States: Replicate's gear, with the game's own inventory functions.
--
--  * an item you own (the game allows one of each) is equipped as it is:
--    your level, gems and mirage are never changed
--  * an item you don't own is given with its saved level, gems and mirage
--    (made from its saved record the way the game loads items from disk)
--  * what you wore is recorded first; when the run ends it's put back
--  * lend (experimental setting): what was given is taken back then too
local Gear = {}

Gear.G = nil
Gear.itemforge = nil
Gear.Equipment = nil
Gear.GEMS = "GEMS"

local function deepcopy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local o = {}
	seen[t] = o
	for k, v in pairs(t) do
		o[k] = deepcopy(v, seen)
	end
	return o
end

local function Own(hoard, slot, id)
	local items = hoard:GetSlotItems(slot)
	for _, it in ipairs(items or {}) do
		if it.id == id then
			return it
		end
	end
	return nil
end
Gear.Own = Own

local function Strip(slots)
	-- the saved gem ids belong to the saving character's gems: emptied here
	for _, gs in ipairs(type(slots) == "table" and slots or {}) do
		if type(gs) == "table" then
			gs.gem_id = nil
			if type(gs.linked_slots) == "table" then
				for _, m in ipairs(gs.linked_slots) do
					if type(m) == "table" then
						m.gem_id = nil
					end
				end
			end
		end
	end
end

-- a copy of a saved item, added to your inventory; its saved gems added
-- (new gem ids) and mounted. Returns the item, and what was given.
function Gear.Give(hoard, slot, rec, gems)
	local itemforge = Gear.itemforge
	local def = Gear.Equipment.Items[slot] ~= nil and Gear.Equipment.Items[slot][rec.id] or nil
	if def == nil then
		return nil, "unknown " .. tostring(rec.id)
	end
	local item = deepcopy(rec)
	Strip(item.gem_slots)
	itemforge.ConvertToRuntimeItem(item)
	hoard:AddToInventory(slot, item)
	local given = { slot = slot, id = rec.id, gems = {} }
	-- the saved gems, slot by slot (a slot that holds several gems: skipped)
	for idx, gs in ipairs(type(rec.gem_slots) == "table" and rec.gem_slots or {}) do
		local grec = type(gs) == "table" and gs.gem_id ~= nil and gems ~= nil and gems[gs.gem_id] or nil
		if grec ~= nil and gs.linked_slots == nil then
			local ok = pcall(function()
				local gem = deepcopy(grec)
				gem.gem_id = nil
				gem.equipped_in = nil
				itemforge.ConvertToRuntimeItem(gem)
				hoard:AddToInventory(Gear.GEMS, gem)
				local mount = item:GetGemSlots()[idx]
				if mount ~= nil then
					mount:SetGem(gem)
				end
				given.gems[#given.gems + 1] = gem.gem_id
			end)
			if not ok then
				given.gem_failed = true
			end
		end
	end
	pcall(function() item:RefreshItemStats() end)
	pcall(function() hoard:RefreshItemStats() end)
	return item, given
end

local function Equipped(hoard, slot)
	local ok, it = pcall(hoard.GetEquippedItem, hoard, slot)
	return ok and it or nil
end

-- what you wear now (to put back after the run)
function Gear.Record(inst)
	local hoard = inst.components.inventoryhoard
	local rec = { equips = {}, other = nil }
	for _, slot in pairs(Gear.Equipment.Slots) do
		local it = Equipped(hoard, slot)
		if it ~= nil then
			rec.equips[slot] = it.id
		end
	end
	local tw = inst.components.twoweapons
	if tw ~= nil and tw.GetOther ~= nil then
		local ok, other = pcall(tw.GetOther, tw)
		rec.other = ok and other ~= nil and other.id or nil
	end
	pcall(function()
		rec.loadout_id = hoard:GetCurrentLoadoutID()
		rec.dirty = hoard:IsLoadoutDirty()
	end)
	return rec
end

local function SetOther(inst, item)
	local tw = inst.components.twoweapons
	if tw == nil or item == nil then
		return false
	end
	local hoard = inst.components.inventoryhoard
	local held = Equipped(hoard, "WEAPON")
	if held == item then
		return false
	end
	tw.prev = { id = item.id, idx = hoard:GetItemIndex(item) }
	pcall(tw.Track, tw)
	pcall(tw.RefreshGems, tw)
	return true
end

-- put on a saved state's gear. report: { given = {...}, used = {...}, failed = {...} }
function Gear.Apply(inst, saved)
	local hoard = inst.components.inventoryhoard
	local report = { given = {}, used = {}, failed = {} }
	if type(saved) ~= "table" or type(saved.equips) ~= "table" then
		return report
	end
	local items = type(saved.items) == "table" and saved.items or {}
	local function Get(slot, id, rec)
		local it = Own(hoard, slot, id)
		if it ~= nil then
			report.used[#report.used + 1] = id
			return it
		end
		if type(rec) ~= "table" or rec.id ~= id then
			report.failed[#report.failed + 1] = tostring(id) .. " (no saved record)"
			return nil
		end
		local ok, item, given = pcall(Gear.Give, hoard, slot, rec, saved.gems)
		if ok and item ~= nil then
			report.given[#report.given + 1] = given
			return item
		end
		report.failed[#report.failed + 1] = tostring(id) .. " (" .. tostring(ok and given or item) .. ")"
		return nil
	end
	for slot, id in pairs(saved.equips) do
		if type(slot) == "string" and type(id) == "string" and Gear.Equipment.Items[slot] ~= nil then
			local item = Get(slot, id, items[slot])
			if item ~= nil and Equipped(hoard, slot) ~= item then
				local ok, err = pcall(hoard.EquipSingleItem, hoard, slot, item)
				if not ok then
					report.failed[#report.failed + 1] = id .. " (couldn't equip: " .. tostring(err) .. ")"
				end
			end
		end
	end
	-- the other weapon (Two Weapons)
	if type(saved.other) == "table" and type(saved.other.id) == "string" and inst.components.twoweapons ~= nil then
		local item = Get("WEAPON", saved.other.id, saved.other)
		if item ~= nil then
			SetOther(inst, item)
		end
	end
	return report
end

-- put back what was recorded (in town after the run). lend: take back what was given.
function Gear.Restore(inst, rec)
	local hoard = inst.components.inventoryhoard
	local problems = {}
	if type(rec) ~= "table" then
		return problems
	end
	local switched = false
	if rec.dirty == false and rec.loadout_id ~= nil then
		switched = pcall(hoard.SwitchToLoadout, hoard, rec.loadout_id)
	end
	for slot, id in pairs(type(rec.equips) == "table" and rec.equips or {}) do
		local cur = Equipped(hoard, slot)
		if cur == nil or cur.id ~= id then
			local it = Own(hoard, slot, id)
			if it ~= nil then
				local ok = pcall(hoard.EquipSingleItem, hoard, slot, it)
				if not ok then
					problems[#problems + 1] = id
				end
			elseif not switched then
				problems[#problems + 1] = id .. " (not in the inventory)"
			end
		end
	end
	if rec.other ~= nil then
		local it = Own(hoard, "WEAPON", rec.other)
		if it ~= nil then
			SetOther(inst, it)
		end
	end
	if rec.lend and type(rec.given) == "table" then
		for _, g in ipairs(rec.given) do
			local it = Own(hoard, g.slot, g.id)
			if it ~= nil and Equipped(hoard, g.slot) ~= it then
				local ok = pcall(hoard.RemoveFromInventory, hoard, it)
				if not ok then
					problems[#problems + 1] = g.id .. " (couldn't take back)"
				end
				for _, gid in ipairs(type(g.gems) == "table" and g.gems or {}) do
					pcall(function()
						local gem = hoard:GetGemById(gid)
						if gem ~= nil and (gem.equipped_in == nil or gem.equipped_in == g.id) then
							hoard:RemoveFromInventory(gem)
						end
					end)
				end
			end
		end
	end
	return problems
end

return Gear
