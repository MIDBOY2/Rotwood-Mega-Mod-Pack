-- Skill Slots: the weapon rack in Hamish's forge opens the skill slot menu.
-- The rack is part of the forge building's art, not a prop of its own: Hamish's forge
-- (prefabs/autogen/prop/forge_unlocked.lua: bank forge_2, drawn in parallax layers)
-- draws it as the "rack" symbol in its layer "1" (dist -2.0, the back of the hut,
-- right of the forge's middle). So the forge itself becomes the station (the same
-- screen-opener interaction as the other stations: Station.MakeStation), with a reach
-- big enough to stand by the hut (its collision is 4.8 round its middle), and it only
-- takes focus while you stand by the rack: within REACH of where that layer draws the
-- rack symbol (AnimState:GetSymbolPosition, so a flipped forge works too).

local ForgeRack = {}

ForgeRack.PREFAB = "forge_unlocked"   -- Hamish's forge
ForgeRack.LAYER_ANIM = "1"            -- the parallax layer that draws the rack
ForgeRack.SYMBOL = "rack"
ForgeRack.RADIUS = 6.5                -- the forge's interact reach (its collision 4.8 + room to stand)
ForgeRack.REACH = 3.2                 -- how close to the rack you stand for "Customize Skills"

-- where the rack is drawn (world x, z), or nil
function ForgeRack.RackXZ(inst)
	local layers = { inst }
	for _, child in ipairs(inst.highlightchildren or {}) do
		layers[#layers + 1] = child
	end
	for _, layer in ipairs(layers) do
		local as = layer.AnimState
		if as ~= nil and as.IsCurrentAnimation ~= nil and as:IsCurrentAnimation(ForgeRack.LAYER_ANIM) then
			local x, _, z = as:GetSymbolPosition(ForgeRack.SYMBOL, 0, 0, 0)
			return x, z
		end
	end
	return nil
end

-- the player stands by the rack
function ForgeRack.Near(inst, player, reach)
	if player == nil or player.Transform == nil then
		return false
	end
	local x, z = ForgeRack.RackXZ(inst)
	if x == nil then
		return false
	end
	local px, pz = player.Transform:GetWorldXZ()
	local dx, dz = px - x, pz - z
	reach = reach or ForgeRack.REACH
	return dx * dx + dz * dz <= reach * reach
end

-- AddPrefabPostInit for the forge. make_station = Station.MakeStation,
-- can_open = Station.CanOpenAt (in town, Skill Slots on).
function ForgeRack.Make(inst, make_station, can_open, reach)
	make_station(inst)
	local interactable = inst.components ~= nil and inst.components.interactable or nil
	if interactable == nil then
		return false, "the forge didn't become a station"
	end
	interactable:SetRadius(ForgeRack.RADIUS)
	interactable:SetInteractFocusConditionFn(function(_, player)
		return (can_open == nil or can_open(player)) and ForgeRack.Near(inst, player, reach)
	end)
	return true
end

return ForgeRack
