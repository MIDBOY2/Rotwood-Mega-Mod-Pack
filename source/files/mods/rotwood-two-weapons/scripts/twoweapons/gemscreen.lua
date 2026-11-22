-- Two Weapons: the swap button works in the gem screen (1.0.10).
--
-- The gem table's weapon tab (screens/town/gemscreenmulti.lua: Modify Weapon
-- Gems; its EquipmentGemDetailsPanel) shows the weapon in your hand. With two
-- weapons you had to close it, swap and open it again to set the other one's
-- gems (user 2026-11-13: "allow LS weapon swap in menu"). Here the swap
-- button (left stick click / M) swaps your weapons right there, the game's
-- own swap, and the panel shows the other weapon's gem slots, the way the
-- game fills it when the tab opens (SetCurrentItem, FillGemList, its layout
-- and focus). Only on the weapon tab (not the morphic armour screen), not
-- while a popup is up, only with a second weapon. The panel's control map
-- (the game's way: handled when the button comes up, before the screen's).
--
-- Taking a gem from your other weapon is the game's own already: pick a gem
-- set on another weapon (greyed in the list, "Set on <weapon>" in its
-- details) and Equip asks "Gem already set on your <weapon>: do you want to
-- unset it from there first?" (EquipmentGemDetailsPanel:_ConfirmUnsettingGem).
local GemScreen = {}

GemScreen.SLOT = "WEAPON"
GemScreen.ICON = "images/icons_ftf/inventory_weapon.tex"

local function Cmp(p, name)
	return type(p) == "table" and type(p.components) == "table" and p.components[name] or nil
end

-- The swap from the panel: true when it swapped (and the panel shows the new weapon).
function GemScreen.Swap(panel)
	local player = panel.GetOwningPlayer ~= nil and panel:GetOwningPlayer() or nil
	local tw, hoard = Cmp(player, "twoweapons"), Cmp(player, "inventoryhoard")
	if tw == nil or hoard == nil or tw:GetOther() == nil then
		return false
	end
	local screen = panel.GetScreen ~= nil and panel:GetScreen() or nil
	if screen ~= nil and screen.GetTopPopup ~= nil and screen:GetTopPopup(player) ~= nil then
		return false
	end
	local held = hoard:GetEquippedItem(GemScreen.SLOT)
	if held == nil or panel.current_item ~= held then
		return false -- (not the weapon tab: the morphic armour screen, or nothing shown)
	end
	if not tw:Swap() then
		return false
	end
	local now = hoard:GetEquippedItem(GemScreen.SLOT)
	if now == nil or now == held then
		return false
	end
	panel:SetCurrentItem(now, GemScreen.ICON, player)
	panel:FillGemList()
	local parent = panel.GetParent ~= nil and panel:GetParent() or nil
	if parent ~= nil and parent.Layout ~= nil then
		parent:Layout()
	elseif panel.Layout ~= nil then
		panel:Layout()
	end
	local hunter_id = player:GetHunterId()
	local focus = panel:FindDefaultFocus()
	if focus ~= nil and focus.SetFocus ~= nil then
		focus:SetFocus(hunter_id)
	end
	if screen ~= nil and screen.RefreshFocusPosition ~= nil then
		screen:RefreshFocusPosition(hunter_id)
	end
	return true
end

-- Panel: widgets/ftf/equipmentgemdetailspanel.lua; control: Two Weapons' swap
-- control; G: the mod's guard.
function GemScreen.Install(Panel, control, G)
	if type(Panel) ~= "table" or type(Panel.SetCurrentItem) ~= "function" or type(Panel.FillGemList) ~= "function"
		or type(Panel.FindDefaultFocus) ~= "function" then
		return false, "a game update changed EquipmentGemDetailsPanel"
	end
	if control == nil then
		return false, "no swap control"
	end
	if rawget(Panel, "twoweapons_gemscreen") then
		return true, "the swap button in the gem screen"
	end
	rawset(Panel, "twoweapons_gemscreen", true)
	local map = {}
	for _, m in ipairs(Panel.CONTROL_MAP or {}) do
		map[#map + 1] = m -- (the game's own or its base class's, if a later version adds some)
	end
	table.insert(map, 1, {
		control = control,
		fn = function(self)
			local ok, swapped = G.Call("the swap in the gem screen", GemScreen.Swap, self)
			return ok and swapped == true
		end,
	})
	rawset(Panel, "CONTROL_MAP", map)
	return true, "the swap button in the gem screen"
end

return GemScreen
