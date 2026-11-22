-- Equip one item in a slot (nil = nothing) without a full loadout refresh: a
-- full refresh mid-fight would recall thrown striker balls. Used for the tonic
-- (D-pad, menu) and the potion (menu). Falls back to the game's own
-- EquipSingleItem if the inventory looks different after an update.
local lume = require "util.lume"

local function Equip(inst, slot, item)
	local hoard = inst.components.inventoryhoard
	local light = hoard.data ~= nil and type(hoard._SetLoadoutDirty) == "function"
		and type(hoard.IsLoadoutDirty) == "function" and type(hoard.ValidateDirtyState) == "function"
		and inst.components.inventory ~= nil
	if light then
		if not hoard:IsLoadoutDirty() then
			hoard:_SetLoadoutDirty() -- copies the current gear, no events
		end
		hoard.data.loadout_override[slot] = item ~= nil and lume.find(hoard.data.inventory[slot], item) or -1
		hoard:ValidateDirtyState()
		inst.components.inventory:Equip(slot, item ~= nil and item:GetItemAppearanceID() or nil)
	else
		hoard:EquipSingleItem(slot, item)
	end
end

return Equip
