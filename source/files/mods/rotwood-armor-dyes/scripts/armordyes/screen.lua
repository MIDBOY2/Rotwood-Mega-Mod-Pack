-- Armor Dyes: the ARMOUR DYE tab of the character screen (the mirror in town).
--
-- The game has this tab half built and switched off: the tab name and icon,
-- the dye picture buttons (SelectableArmorDye: your character wearing each
-- dye), preview on hover, and saving the picked dyes to the character. This
-- turns it on and finishes the parts that were never done: the HELMET / BODY /
-- LEGS sub-tabs, the list order and the selected mark, dye names as tooltips,
-- and keeping dye changes made while the armour is hidden in another tab.
-- 0.3.0: a WEAPON sub-tab (the weapon you're carrying; its pictures show the
-- character with the weapon, the big character shows it as the tab opens),
-- saved like the armour's and counted as a change by Continue / close.

local Cosmetic = require "defs.cosmetics.cosmetics"
local Main = require "armordyes.main"

local Screen = {}

local DYE_TAB = "TAB_ARMORDYE"
local IMAGE_W = 320
local PER_ROW = 4

-- The game's framing of each piece in the dye pictures (characterscreen.lua
-- ARMOR_DYE_TRANSFORM); used if that table can't be found.
local FALLBACK_TRANSFORM = {
	HEAD = { x = -30, y = -380, scale = 1.2 },
	BODY = { x = 0, y = -220, scale = 1 },
	WAIST = { x = 0, y = -76, scale = 1.4 },
	-- (the game has none for weapons: the whole character, the weapon on its back)
	WEAPON = { x = 0, y = -150, scale = 0.8 },
}

-- (0.5.6) the PALETTES sub-tab: a palette on every piece at once
Screen.PALETTES = "PALETTES"

-- the dye tab's sub-tabs: the armour, then the weapon (when weapon dyes are on),
-- then PALETTES (when there are palettes)
function Screen.TabSlots()
	local t = {}
	for _, slot in ipairs(Main.SLOTS) do
		t[#t + 1] = slot
	end
	if Main.weapon_on then
		t[#t + 1] = Main.WEAPON
	end
	if Main.palettes_on and (Main.settings == nil or Main.settings.palette_tab ~= false) then
		t[#t + 1] = Screen.PALETTES
	end
	return t
end

-- the owner's weapon dyes on the screen's puppet (the game copies the armour's).
-- Only a screen whose puppet got them saves / compares the weapon's dye (if the
-- copy ever fails, saving leaves the character's weapon dye as it was).
function Screen.WeaponDyesToPuppet(screen)
	if not Main.weapon_on or screen.owner == nil or screen.puppet == nil then
		return false
	end
	local ok = Main.CopyWeaponDyes(screen.owner, screen.puppet.components) == true
	if ok then
		rawset(screen, "armordyes_weapon_ready", true)
	end
	return ok
end

local function WeaponReady(screen)
	return Main.weapon_on and rawget(screen, "armordyes_weapon_ready") == true
end

-- (0.5.6) the pieces a palette goes on in this screen (the ones with a dye list):
-- { { slot, set }, ... }, the weapon only when its dye is saved by this screen
function Screen.PaletteSlots(screen)
	local out = {}
	local inv = screen.owner ~= nil and screen.owner.components ~= nil and screen.owner.components.inventory or nil
	if inv == nil or type(inv.equips) ~= "table" then
		return out
	end
	local slots = { Main.SLOTS[1], Main.SLOTS[2], Main.SLOTS[3] }
	if WeaponReady(screen) then
		slots[#slots + 1] = Main.WEAPON
	end
	for _, slot in ipairs(slots) do
		local set = inv.equips[slot]
		local list = Cosmetic.EquipmentDyes[slot]
		if set ~= nil and list ~= nil and list[set] ~= nil then
			out[#out + 1] = { slot, set }
		end
	end
	return out
end

-- a palette's dye on each of those pieces that has it
function Screen.PaletteDyes(screen, key)
	local out = {}
	local P = Main.Palettes
	if P == nil then
		return out
	end
	local short = Main.PREFIX .. P.PREFIX .. tostring(key)
	for _, ps in ipairs(Screen.PaletteSlots(screen)) do
		local def = Cosmetic.EquipmentDyes[ps[1]][ps[2]][short]
		if def ~= nil then
			out[#out + 1] = def
		end
	end
	return out
end

-- is the palette on all of them (on the screen's character)?
function Screen.PaletteActive(screen, defs)
	local dyer = screen.puppet ~= nil and screen.puppet.components.equipmentdyer or nil
	if dyer == nil or #defs == 0 then
		return false
	end
	for _, def in ipairs(defs) do
		if dyer:GetActiveDye(def.armour_slot, def.armour_set) ~= def then
			return false
		end
	end
	return true
end

-- hovering a palette shows it on the big character; leaving puts back what was there
function Screen.PalettePreview(screen, key)
	local dyer = screen.puppet.components.equipmentdyer
	if rawget(screen, "armordyes_pal_prev") == nil then
		local prev = {}
		for _, ps in ipairs(Screen.PaletteSlots(screen)) do
			local d = dyer:GetActiveDye(ps[1], ps[2])
			prev[#prev + 1] = { ps[1], ps[2], d ~= nil and d.short_name or nil }
		end
		rawset(screen, "armordyes_pal_prev", prev)
	end
	for _, def in ipairs(Screen.PaletteDyes(screen, key)) do
		dyer:SetEquipmentDye(def.armour_slot, def.armour_set, def.short_name)
	end
end

function Screen.ClearPalettePreview(screen)
	local prev = rawget(screen, "armordyes_pal_prev")
	if prev == nil or screen.puppet == nil then
		return
	end
	rawset(screen, "armordyes_pal_prev", nil)
	local dyer = screen.puppet.components.equipmentdyer
	for _, p in ipairs(prev) do
		dyer:SetEquipmentDye(p[1], p[2], p[3])
	end
end

-- picking a palette: on every piece that has it (kept until saved, like any dye)
function Screen.PickPalette(screen, key)
	rawset(screen, "armordyes_pal_prev", nil)
	local dyer = screen.puppet.components.equipmentdyer
	for _, def in ipairs(Screen.PaletteDyes(screen, key)) do
		dyer:SetEquipmentDye(def.armour_slot, def.armour_set, def.short_name)
	end
	local id = "armordye_palette_" .. tostring(key)
	for _, element in ipairs(screen.scroll_contents.children or {}) do
		if element.GetDyeId ~= nil then
			element:SetSelected(element:GetDyeId() == id)
		end
	end
	screen:CheckForChanges()
end

-- is the weapon's dye the same on the owner and the puppet?
function Screen.WeaponDyeEqual(screen)
	if not WeaponReady(screen) or screen.owner == nil or screen.puppet == nil then
		return true
	end
	local set = screen.owner.components.inventory.equips[Main.WEAPON]
	local list = Cosmetic.EquipmentDyes[Main.WEAPON]
	if set == nil or list == nil or list[set] == nil then
		return true
	end
	local o = screen.owner.components.equipmentdyer:GetActiveDye(Main.WEAPON, set)
	local p = screen.puppet.components.equipmentdyer:GetActiveDye(Main.WEAPON, set)
	return o == p
end

-- A local of a game function, looked up through wrappers other mods put
-- around it (a few levels deep).
local WRAPPER_DEPTH = 24

local function FindUpvalue(fn, wanted, depth, seen)
	if type(fn) ~= "function" then
		return nil
	end
	seen = seen or {}
	if seen[fn] then
		return nil
	end
	seen[fn] = true
	local inner = {}
	for i = 1, 255 do
		local name, value = debug.getupvalue(fn, i)
		if name == nil then
			break
		end
		if name == wanted then
			return value
		end
		if type(value) == "function" then
			table.insert(inner, value)
		end
	end
	if (depth or 0) > 0 then
		for _, f in ipairs(inner) do
			local v = FindUpvalue(f, wanted, depth - 1, seen)
			if v ~= nil then
				return v
			end
		end
	end
	return nil
end
Screen.FindUpvalue = FindUpvalue

local function SetDyeTab(top_tabs, shown)
	for i = #top_tabs, 1, -1 do
		if top_tabs[i] == DYE_TAB then
			table.remove(top_tabs, i)
		end
	end
	if shown then
		-- 5th place, where the game had it (its sub-tab clicks are Armor Dyes' own,
		-- so other mods' tabs before it don't matter)
		table.insert(top_tabs, math.min(5, #top_tabs + 1), DYE_TAB)
	end
end
Screen.SetDyeTab = SetDyeTab

-- The character screen's extra tabs (Armor Dyes' ARMOUR DYE, FURY's PRESETS,
-- Player Colours) each handle their own tab's click without passing it on, so
-- the other tab mods never hear that their tab was left. Each one registers how
-- it leaves its tab in CharacterScreen.extra_tab_leave, and opening one of these
-- tabs leaves the others first, before anything is built (a preset preview on
-- the big character must be gone before the dye pictures copy its look).
local function RegisterTabLeave(CharacterScreen, id, fn)
	local t = rawget(CharacterScreen, "extra_tab_leave")
	if t == nil then
		t = {}
		rawset(CharacterScreen, "extra_tab_leave", t)
	end
	t[id] = fn
end
local function LeaveOtherTabs(CharacterScreen, screen, own)
	for id, fn in pairs(rawget(CharacterScreen, "extra_tab_leave") or {}) do
		if id ~= own then
			pcall(fn, screen)
		end
	end
end
-- the top tab really open (the game's TabGroup sets .current before the click runs)
local function CurrentTopTab(screen)
	local nav = type(screen.navbar) == "table" and screen.navbar or nil
	local cur = nav ~= nil and rawget(nav, "current") or nil
	local id = type(cur) == "table" and rawget(cur, "top_tab_id") or nil
	return type(id) == "string" and id or nil
end

local function SlotLabel(slot)
	local cats = STRINGS and STRINGS.ITEM_CATEGORIES
	local s = cats and cats[slot] or slot
	return string.upper(tostring(s))
end

local function TransformFor(transforms, slot)
	local t = transforms and transforms[slot]
	if t ~= nil and t.offset ~= nil and t.offset.unpack ~= nil then
		local x, y = t.offset:unpack()
		return x, y, t.scale or 1
	end
	local f = FALLBACK_TRANSFORM[slot]
	return f.x, f.y, f.scale
end

-- NONE first, then the mod's dyes in palette order, then any other dyes. (0.5.6)
-- The tint palettes only with palettes_in_lists (else they're in PALETTES).
function Screen.OrderedDyes(slot, set)
	local list = {}
	local dyes = Cosmetic.EquipmentDyes[slot] and Cosmetic.EquipmentDyes[slot][set]
	local with_palettes = Main.settings ~= nil and Main.settings.palettes_in_lists == true
	for _, def in pairs(dyes or {}) do
		if with_palettes or def.armordye_palette == nil or def.armordye_in_list then -- (0.5.11) list palettes
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		local ao, bo = a.armordye_order or 1000, b.armordye_order or 1000
		if ao ~= bo then
			return ao < bo
		end
		return tostring(a.name) < tostring(b.name)
	end)
	table.insert(list, 1, { name = "NONE", armour_slot = slot, armour_set = set })
	return list
end

-- Owner's dyes = the puppet's, for the armour the owner wears (the game's own
-- copy uses the puppet's armour, which is gone while armour is hidden).
function Screen.SyncDyesToOwner(screen)
	local owner, puppet = screen.owner, screen.puppet
	if owner == nil or puppet == nil then
		return
	end
	local odyer = owner.components.equipmentdyer
	local pdyer = puppet.components and puppet.components.equipmentdyer
	local inv = owner.components.inventory
	if odyer == nil or pdyer == nil or inv == nil then
		return
	end
	for _, slot in ipairs(Cosmetic.DyeSlots) do
		local set = inv.equips[slot]
		if set ~= nil then
			local d = pdyer:GetActiveDye(slot, set)
			odyer:SetEquipmentDye(slot, set, d ~= nil and d.short_name or nil)
		end
	end
	-- the weapon (the game's own saving does the armour only)
	local wset = WeaponReady(screen) and inv.equips[Main.WEAPON] or nil
	local wlist = wset ~= nil and Cosmetic.EquipmentDyes[Main.WEAPON] or nil
	if wlist ~= nil and wlist[wset] ~= nil then
		local d = pdyer:GetActiveDye(Main.WEAPON, wset)
		odyer:SetEquipmentDye(Main.WEAPON, wset, d ~= nil and d.short_name or nil)
	end
end

function Screen.Install(settings)
	local ok, CharacterScreen = pcall(require, "screens.character.characterscreen")
	if not ok or type(CharacterScreen) ~= "table" then
		return false, "screens.character.characterscreen: " .. tostring(CharacterScreen)
	end
	local ok2, SelectableArmorDye = pcall(require, "widgets.ftf.selectablearmordye")
	if not ok2 or type(SelectableArmorDye) ~= "table" then
		return false, "widgets.ftf.selectablearmordye"
	end
	for _, fn in ipairs({ "OnChangeTab", "OnChangeSubTab", "GenerateArmorDyeList", "ApplyChanges", "OnContinueClicked",
		"DyePreview", "ClearDyePreview", "CheckForChanges", "_ShowArmor", "FocusFirstElement" }) do
		if type(CharacterScreen[fn]) ~= "function" then
			return false, "a game update changed CharacterScreen:" .. fn
		end
	end
	-- the game's tab lists sit in its own constructor, under every mod's wrapper
	-- around it (Player Colours', FURY's three post-constructs and its presets tab
	-- are five already): look deep enough for many more
	local top_tabs = FindUpvalue(CharacterScreen._ctor, "TOP_TABS", WRAPPER_DEPTH)
	local sub_tabs = FindUpvalue(CharacterScreen._ctor, "SUB_TABS", WRAPPER_DEPTH)
	if type(top_tabs) ~= "table" or type(sub_tabs) ~= "table" then
		return false, "a game update changed the character screen's tab list"
	end
	local transforms = FindUpvalue(CharacterScreen.GenerateArmorDyeList, "ARMOR_DYE_TRANSFORM", 2)
	if STRINGS == nil or STRINGS.CHARACTER_CREATOR == nil or STRINGS.CHARACTER_CREATOR[DYE_TAB] == nil then
		return false, "STRINGS.CHARACTER_CREATOR." .. DYE_TAB
	end

	sub_tabs[DYE_TAB] = Screen.TabSlots()

	-- The tab only for characters that already exist (a new character has no
	-- armour yet).
	local ctor = CharacterScreen._ctor
	CharacterScreen._ctor = function(self, owner, on_close_cb, new_character_data, ...)
		SetDyeTab(top_tabs, new_character_data == nil)
		local r = table.pack(ctor(self, owner, on_close_cb, new_character_data, ...))
		-- the big character copies the armour's dyes only: the weapon's too
		if new_character_data == nil then
			local okw, err = pcall(Screen.WeaponDyesToPuppet, self)
			if not okw then
				Main.Log("weapon dye on the mirror's character skipped: " .. tostring(err))
			end
		end
		return table.unpack(r, 1, r.n)
	end
	-- Continue / close: a weapon dye picked is a change (the game compares the
	-- armour's only, so close would have dropped it); Revert puts it back too
	if Main.weapon_on and type(CharacterScreen.IsCharacterEqual) == "function" then
		local equal = CharacterScreen.IsCharacterEqual
		CharacterScreen.IsCharacterEqual = function(self, ...)
			local same = equal(self, ...)
			if not same then
				return same
			end
			local okw, wsame = pcall(Screen.WeaponDyeEqual, self)
			return not okw or wsame
		end
	end
	if Main.weapon_on and type(CharacterScreen.OnRevertClicked) == "function" then
		local revert = CharacterScreen.OnRevertClicked
		CharacterScreen.OnRevertClicked = function(self, ...)
			pcall(Screen.WeaponDyesToPuppet, self)
			return revert(self, ...)
		end
	end

	RegisterTabLeave(CharacterScreen, DYE_TAB, function(screen)
		Screen.ClearPalettePreview(screen)
		screen.armordyes_tab = nil
	end)
	local orig_OnChangeTab = CharacterScreen.OnChangeTab
	function CharacterScreen:OnChangeTab(tab_button, ...)
		if tab_button == nil or tab_button.top_tab_id ~= DYE_TAB then
			self.armordyes_tab = nil
			return orig_OnChangeTab(self, tab_button, ...)
		end
		LeaveOtherTabs(CharacterScreen, self, DYE_TAB)
		self.armordyes_tab = true
		self.scroll_contents:RemoveAllChildren()
		self.subnav:RemoveAllTabs()
		self.can_randomize_species = false

		for _, slot in ipairs(Screen.TabSlots()) do
			local tab = self.subnav:AddTextTab(SlotLabel(slot), self.label_font_size)
				:SetName("Tab - dye " .. slot)
			tab.body_tab_id = slot
			tab.armordye_slot = slot
		end
		self:_ShowArmor()

		self.subnav:AddCycleIcons(50, 40, UICOLORS.LIGHT_TEXT_DARK)
		-- The dye sub-tabs build their dye lists here. The game's OnChangeSubTab
		-- only does that for the 5th top tab, and FURY's PRESETS tab sits before
		-- ARMOUR DYE (making it the 6th): the game then built body-part lists, and
		-- crashed in FURY's focus (0.2.2).
		self.subnav:SetTabOnClick(function(tab_btn)
			Screen.ClearPalettePreview(self)
			if tab_btn.armordye_slot == Screen.PALETTES then
				self:GeneratePaletteList()
				self:FocusFirstElement()
			elseif tab_btn.armordye_slot ~= nil then
				self:GenerateArmorDyeList(tab_btn.armordye_slot)
				self:FocusFirstElement()
			else
				self:OnChangeSubTab(tab_btn)
			end
		end)
		local w = self.subnav:GetSize()
		self.subnav_bg:SetScale(1, 1)
			:SetSize(w + 280, self.subnav_height)
			:LayoutBounds("center", "above", self.list_bg)
			:Offset(0, -1)
			:SetScale(1, -1)
		self.subnav:LayoutBounds("center", "center", self.subnav_bg)
			:Offset(0, -2)
		self.subnav:OpenTabAtIndex(1)
		self.subnav_bg:SetShown(true)
		self.subnav:SetShown(true)
		if self.customize_character_description ~= nil then
			self.customize_character_description:Hide()
		end
		self:FocusFirstElement()
	end

	-- OnChangeSubTab stays the game's (other mods read its locals, e.g. FURY's
	-- colour picker looks up BODY_PART_COLOR_MAP through it); the dye tab's
	-- sub-tabs don't go through it (above).

	function CharacterScreen:GenerateArmorDyeList(armorslot)
		self.scroll_contents:RemoveAllChildren()
		if self.color_elements_list ~= nil then
			self.color_elements_list:RemoveAllChildren()
		end

		local set = self.owner.components.inventory.equips[armorslot]
		if set == nil then
			Main.Debug("no " .. armorslot .. " armour equipped: nothing to dye")
			self.scroll:RefreshView()
			return
		end

		local pdyer = self.puppet.components.equipmentdyer
		local active = pdyer:GetActiveDye(armorslot, set)
		local x, y, scale = TransformFor(transforms, armorslot)

		for _, def in ipairs(Screen.OrderedDyes(armorslot, set)) do
			local is_none = def.name == "NONE"
			local selected = (is_none and active == nil) or (not is_none and active == def)
			local el = self.scroll_contents:AddChild(SelectableArmorDye(IMAGE_W))
				:SetDyeId(def.name)
				:SetLocked(false)
				:SetSelected(selected)
				:SetUnseen(false)
			-- (the game's pictures leave the weapon out: the weapon tab's keep it)
			local cloned = false
			if armorslot == Main.WEAPON then
				cloned = pcall(function()
					el.puppet_bg:CloneCharacterWithEquipment(self.puppet, false)
					el.puppet:CloneCharacterWithEquipment(self.puppet, false)
				end)
			end
			if not cloned then
				el:CloneCharacterAppearance(self.puppet)
			end
			el:SetPuppetArmorDye(armorslot, set, def.short_name)
			local label = is_none and "Original colours" or (def.armordye_label or def.short_name or def.name)
			el:SetToolTipFn(function() return label end)
				:ShowToolTipOnFocus(true)
			el:SetOnClick(function()
				self:OnDyeElementSelected(def)
			end)
			el:SetOnGainFocus(function()
				el:OnFocusChange(true)
				if not el:IsSelected() then
					self:DyePreview(def, armorslot)
				end
			end)
			:SetOnLoseFocus(function()
				el:OnFocusChange(false)
				if not el:IsSelected() then
					self:ClearDyePreview()
				end
			end)
			el:SetPuppetOffset(x, y)
				:SetPuppetScale(scale)
		end

		self.scroll_contents:LayoutInDiagonal(PER_ROW, 60, 60)
			:LayoutBounds("center", "top", 0, -60)
		self.scroll:RefreshView()
	end

	-- (0.5.6) PALETTES: each palette as a picture of the whole character (weapon
	-- included) wearing it on every piece that has it
	function CharacterScreen:GeneratePaletteList()
		self.scroll_contents:RemoveAllChildren()
		if self.color_elements_list ~= nil then
			self.color_elements_list:RemoveAllChildren()
		end
		local P = Main.Palettes
		local x, y, scale = TransformFor(transforms, Main.WEAPON)
		for _, pal in ipairs(P ~= nil and P.list or {}) do
			local defs = Screen.PaletteDyes(self, pal.key)
			if #defs > 0 then
				local el = self.scroll_contents:AddChild(SelectableArmorDye(IMAGE_W))
					:SetDyeId("armordye_palette_" .. pal.key)
					:SetLocked(false)
					:SetSelected(Screen.PaletteActive(self, defs))
					:SetUnseen(false)
				local cloned = pcall(function()
					el.puppet_bg:CloneCharacterWithEquipment(self.puppet, false)
					el.puppet:CloneCharacterWithEquipment(self.puppet, false)
				end)
				if not cloned then
					el:CloneCharacterAppearance(self.puppet)
				end
				for _, def in ipairs(defs) do
					el:SetPuppetArmorDye(def.armour_slot, def.armour_set, def.short_name)
				end
				local label = "Palette: " .. pal.name
				el:SetToolTipFn(function() return label end)
					:ShowToolTipOnFocus(true)
				el:SetOnClick(function()
					Screen.PickPalette(self, pal.key)
				end)
				el:SetOnGainFocus(function()
					el:OnFocusChange(true)
					if not el:IsSelected() then
						Screen.PalettePreview(self, pal.key)
					end
				end)
				:SetOnLoseFocus(function()
					el:OnFocusChange(false)
					if not el:IsSelected() then
						Screen.ClearPalettePreview(self)
					end
				end)
				el:SetPuppetOffset(x, y)
					:SetPuppetScale(scale)
			end
		end
		self.scroll_contents:LayoutInDiagonal(PER_ROW, 60, 60)
			:LayoutBounds("center", "top", 0, -60)
		self.scroll:RefreshView()
	end

	-- Same as the game's, without marking the dye "seen" in the save.
	function CharacterScreen:OnDyeElementSelected(def)
		self.puppet.components.equipmentdyer:SetEquipmentDye(def.armour_slot, def.armour_set, def.short_name)
		self.current_dye_slot = def.armour_slot
		self.current_dye_set = def.armour_set
		self.current_dye_name = def.short_name
		for _, element in ipairs(self.scroll_contents.children) do
			if element.GetDyeId ~= nil then
				element:SetSelected(def.name == element:GetDyeId())
			end
		end
		self:CheckForChanges()
	end

	-- Leaving a dye unpicked after hovering it: back to what was there.
	local orig_ClearDyePreview = CharacterScreen.ClearDyePreview
	function CharacterScreen:ClearDyePreview(...)
		if self.current_dye_slot == nil or self.current_dye_set == nil then
			return
		end
		return orig_ClearDyePreview(self, ...)
	end

	local orig_ApplyChanges = CharacterScreen.ApplyChanges
	function CharacterScreen:ApplyChanges(...)
		pcall(Screen.SyncDyesToOwner, self)
		return orig_ApplyChanges(self, ...)
	end

	local orig_OnContinueClicked = CharacterScreen.OnContinueClicked
	function CharacterScreen:OnContinueClicked(...)
		pcall(Screen.SyncDyesToOwner, self)
		return orig_OnContinueClicked(self, ...)
	end

	return true
end

return Screen
