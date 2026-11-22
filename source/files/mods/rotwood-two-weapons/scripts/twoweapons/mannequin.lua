-- Two Weapons: the game's mannequin loadouts remember your other weapon.
-- A loadout already saves the weapon in hand (with your armor, potion, tonic,
-- talents and gems). Saving a loadout (at the mannequin or the loadout
-- screen: claim, save) also keeps your other weapon with it; equipping that
-- loadout puts the game's saved weapon in hand and makes the saved one your
-- other weapon. Like the loadout's gear, a change counts only once you save
-- the loadout again. Loadouts saved before this, or saved with no second
-- weapon, keep the other weapon you have. If the saved weapon is gone
-- (salvaged), you keep yours.
-- The Hunter's Path screen saves the loadout by itself when only talents
-- changed: that save keeps the loadout's other weapon as it was.

local Mannequin = {}

local function Cmp(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.twoweapons or nil
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

-- the mod's guard (twoweapons.main's), or a local one if that isn't loaded
local function Guard()
	local main = package.loaded["twoweapons.main"]
	if type(main) == "table" and main.G ~= nil then
		return main.G
	end
	return require("twoweapons.guard").Shared("[Two Weapons]")
end

function Mannequin.Install()
	local PlayerLoadouts = require "components.playerloadouts"
	for _, name in ipairs({ "SaveLoadout", "EquipLoadout", "DeleteLoadout" }) do
		assert(type(PlayerLoadouts[name]) == "function", "PlayerLoadouts:" .. name)
	end

	-- (bulletproofing: Two Weapons' part runs in the guard; an error is
	-- logged and the loadout saves / equips the game's way)
	local G = Guard()
	local function BeforeSave(self, loadout_id)
		local tw = Cmp(self.inst)
		if tw == nil or tw.loadouts == nil then
			return nil
		end
		local keep = loadout_id ~= nil and tw.loadouts[tostring(loadout_id)] ~= nil and Mannequin.IsTalentAutoSave()
		return tw, keep, tw:GetOther() -- your other weapon right now
	end
	local orig_save = PlayerLoadouts.SaveLoadout
	PlayerLoadouts.SaveLoadout = function(self, loadout_id, ...)
		local ok, tw, keep, other = G.Call("loadout save", BeforeSave, self, loadout_id)
		if not ok or tw == nil then
			return orig_save(self, loadout_id, ...)
		end
		-- saving equips the loadout again: don't put the old pair back meanwhile
		tw.saving_loadout = (tw.saving_loadout or 0) + 1
		local results = table.pack(pcall(orig_save, self, loadout_id, ...))
		tw.saving_loadout = tw.saving_loadout - 1
		if not results[1] then
			error(results[2], 0)
		end
		local id = results[2]
		if id ~= nil and not keep then
			tw:SaveForLoadout(id, other)
		end
		return table.unpack(results, 2, results.n)
	end

	local orig_equip = PlayerLoadouts.EquipLoadout
	local function AfterEquip(self, loadout_id)
		local tw = Cmp(self.inst)
		if tw ~= nil and tw.loadouts ~= nil and (tw.saving_loadout or 0) == 0
			and loadout_id ~= nil and self:GetLoadout(loadout_id) ~= nil then
			tw:LoadForLoadout(loadout_id)
		end
	end
	PlayerLoadouts.EquipLoadout = function(self, loadout_id, ...)
		local results = table.pack(orig_equip(self, loadout_id, ...))
		G.Call("loadout equip", AfterEquip, self, loadout_id)
		return table.unpack(results, 1, results.n)
	end

	local orig_delete = PlayerLoadouts.DeleteLoadout
	local function AfterDelete(self, loadout_id)
		local tw = Cmp(self.inst)
		if tw ~= nil and tw.loadouts ~= nil and loadout_id ~= nil then
			tw:ForgetLoadout(loadout_id)
		end
	end
	PlayerLoadouts.DeleteLoadout = function(self, loadout_id, ...)
		local results = table.pack(orig_delete(self, loadout_id, ...))
		G.Call("loadout delete", AfterDelete, self, loadout_id)
		return table.unpack(results, 1, results.n)
	end
end

return Mannequin
