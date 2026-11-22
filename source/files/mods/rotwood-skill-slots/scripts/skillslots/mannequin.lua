-- Skill Slots: the game's mannequin loadouts remember your skill buttons.
-- Saving a loadout (at the mannequin or the loadout screen: claim, save)
-- stores every weapon type's buttons (B, LT, RT, RS and the weapon choices)
-- with it; equipping that loadout puts them back. Like the loadout's gear,
-- skill changes made after saving are kept only if you save the loadout
-- again; switching to another loadout replaces them with that one's.
-- Loadouts saved before this (or with the mod off) don't change your buttons.
-- The Hunter's Path screen saves the loadout by itself when only talents
-- changed: that save keeps the loadout's skills as they were.

local Core = require "skillslots.core"

local Mannequin = {}

local function Data(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.skillslotsdata or nil
end

local function Copy(t)
	local c = {}
	for k, v in pairs(t or {}) do
		c[k] = v
	end
	return c
end

-- The save comes from the Hunter's Path screen closing (the game's own
-- talents-only save), not from the player saving the loadout.
function Mannequin.IsTalentAutoSave()
	for level = 3, 12 do
		local info = debug.getinfo(level, "S")
		if info == nil then
			return false
		end
		if type(info.source) == "string" and info.source:find("talentscreen", 1, true) then
			return true
		end
	end
	return false
end

function Mannequin.Install()
	local PlayerLoadouts = require "components.playerloadouts"
	for _, name in ipairs({ "SaveLoadout", "EquipLoadout", "DeleteLoadout" }) do
		assert(type(PlayerLoadouts[name]) == "function", "PlayerLoadouts:" .. name)
	end

	-- (bulletproofing: Skill Slots' part runs in Core.G.Call; an error is
	-- logged and the loadout saves / equips the game's way)
	local G = Core.G
	local function BeforeSave(self, loadout_id)
		local data = Data(self.inst)
		if data == nil or not Core.IsActive(self.inst) or data.loadouts == nil then
			return nil
		end
		local keep = loadout_id ~= nil and data.loadouts[tostring(loadout_id)] ~= nil and Mannequin.IsTalentAutoSave()
		return data, keep, Copy(data.slots) -- the buttons right now, every weapon type
	end
	local orig_save = PlayerLoadouts.SaveLoadout
	PlayerLoadouts.SaveLoadout = function(self, loadout_id, ...)
		local ok, data, keep, snap = G.Call("loadout save", BeforeSave, self, loadout_id)
		if not ok or data == nil then
			return orig_save(self, loadout_id, ...)
		end
		-- saving equips the loadout again: don't put the old buttons back meanwhile
		data.skillslots_saving = (data.skillslots_saving or 0) + 1
		local results = table.pack(pcall(orig_save, self, loadout_id, ...))
		data.skillslots_saving = data.skillslots_saving - 1
		if not results[1] then
			error(results[2], 0)
		end
		local id = results[2]
		if id ~= nil and not keep then
			data.loadouts[tostring(id)] = snap
		end
		return table.unpack(results, 2, results.n)
	end

	local function AfterEquip(self, loadout_id)
		local data = Data(self.inst)
		if data ~= nil and data.loadouts ~= nil and (data.skillslots_saving or 0) == 0 and Core.IsActive(self.inst)
			and loadout_id ~= nil and self:GetLoadout(loadout_id) ~= nil then
			local snap = data.loadouts[tostring(loadout_id)]
			if snap ~= nil then
				data.slots = Copy(snap)
				Core.Sync(self.inst)
				self.inst:PushEvent("skillslots_changed")
			end
		end
	end
	local orig_equip = PlayerLoadouts.EquipLoadout
	PlayerLoadouts.EquipLoadout = function(self, loadout_id, ...)
		local results = table.pack(orig_equip(self, loadout_id, ...))
		G.Call("loadout equip", AfterEquip, self, loadout_id)
		return table.unpack(results, 1, results.n)
	end

	local function AfterDelete(self, loadout_id)
		local data = Data(self.inst)
		if data ~= nil and data.loadouts ~= nil and loadout_id ~= nil then
			data.loadouts[tostring(loadout_id)] = nil
		end
	end
	local orig_delete = PlayerLoadouts.DeleteLoadout
	PlayerLoadouts.DeleteLoadout = function(self, loadout_id, ...)
		local results = table.pack(orig_delete(self, loadout_id, ...))
		G.Call("loadout delete", AfterDelete, self, loadout_id)
		return table.unpack(results, 1, results.n)
	end
end

return Mannequin
