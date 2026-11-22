-- Skill Slots: the station menu. Built the same way as the game's Emote Booth
-- (MultiPanelScreen + one SinglePanel per local player): slots on the left,
-- the skills you can pick on the right.
--   pick a slot (B / LT / RT / RS-click) -> pick a skill -> it goes on that slot
--   X (keyboard Shift) / "Skill info": overview popup of the skill under the cursor
--   Y / "Clear slot" empties the selected slot (on B: back to the weapon skill)
--   "Hide unavailable" hides other weapons' skills and the ones you don't own;
--       "Show all" shows every skill, and any of them can go on a slot
--   LS (Two Weapons' swap button) switches your weapon, and with it the loadout
--   "HUD icons" shows / hides the LT / RT / RS icons on this player's HUD
--   View (keyboard Tab) turns Two Weapons' swap attacks on / off for this player
-- The buttons under the list can be reached with the D-pad / stick too.
-- A skill can only sit on one slot; putting it on another slot swaps them.
-- "Weapon skill" (first in the list) is the weapon's own skill, B by default.

local Core = require "skillslots.core"
local SkillInfoPopup = require "skillslots.infopopup"
local ActionButton = require "widgets.actionbutton"
local Clickable = require "widgets/clickable"
local Image = require "widgets.image"
local MultiPanelScreen = require "screens.town.multipanelscreen"
local Panel = require "widgets.panel"
local ScrollPanel = require "widgets.scrollpanel"
local SinglePanel = require "widgets.ftf.town.singlepanel"
local SkillIconWidget = require "widgets.ftf.skilliconwidget"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local Power = require "defs.powers"

local STR = {
	TITLE = "Skill Slots",
	DESC = "Pick a skill for each button. Each weapon type has its own loadout.",
	LOADOUT = "%s loadout",
	LOADOUT_ANY = "Loadout",
	SWAP_HINT = "<p bind='%s' color=0> Switch weapon",
	EMPTY = "Empty",
	WEAPON = "Weapon skill",
	WEAPON_TAG = "Weapon",
	CLASS_TAG = { boss = "Boss", miniboss = "Miniboss", universal = "Any" }, -- skills of no weapon (class_icons)
	WEAPON_DESC = "Your weapon's own skill. It changes with your weapon, and a skill you pick up during a run replaces it.",
	NOT_OWNED = "You don't own this skill yet (shown because Show all is on). It still works on a slot.",
	NOT_OWNED_TYPE = "You don't own this boss's %s yet (shown because Show all is on). It still works on a slot.",
	NEEDS = "Needs a %s in hand. On a slot it rests while you hold another weapon.",
	NEEDS_SHORT = "needs a %s",
	CLEAR = "Clear slot",
	INFO = "Skill info",
	CLEAR_B = "Use weapon skill",
	HIDE_OTHER = "Hide unavailable",
	SHOW_OTHER = "Show all",
	HUD_ON = "HUD icons: On",
	HUD_OFF = "HUD icons: Off",
	NAMES_ON = "Names: On",
	NAMES_OFF = "Names: Off",
	SWAP_ATTACKS_ON = "Swap attacks: On",
	SWAP_ATTACKS_OFF = "Swap attacks: Off",
}

-- Button text with its controller / keyboard button in front ("[X] Skill info")
-- a widget's size, or the fallback when it can't be measured
local function Size(w, dw, dh)
	if w ~= nil and w.GetSize ~= nil then
		local ok, sw, sh = pcall(w.GetSize, w)
		if ok and type(sw) == "number" and type(sh) == "number" and sw > 0 and sh > 0 then
			return sw, sh
		end
	end
	return dw or 0, dh or 0
end

local PANEL_W, PANEL_H = 1819, 929 -- the game's panel art, if it can't be measured
local BUTTONS_MARGIN = 80 -- the button row keeps this far in from the panel's sides

-- Two layouts, picked by how many players have the menu open:
--   1 or 2 players, "tall": the panel is taller than the game's (the screen has
--     the room); slots in a column with their names, the list on the right,
--     the details under the list.
--   3 or 4 players, "grid": the panels sit in two rows that already fill the
--     screen top to bottom, so they keep the game's height. The slots go in a
--     2 x 2 grid with the details under them, and the list takes the right
--     side top to bottom, with bigger icons.
local TALL_H = 1100
local SIZES = {
	-- before the screen has picked one (the game's panel, the old layout)
	normal = { slot = 124, icon = 150, gap = 20, columns = 5, list_w = 870, list_h = 520, list_top = 140 },
	tall = { name = "tall", slot = 150, icon = 195, gap = 12, columns = 4, list_w = 870, list_h = 660, list_top = 140 },
	grid = { name = "grid", grid = true, slot = 140, icon = 222, gap = 12, columns = 4, list_w = 960, list_h = 665, list_top = 130,
		title_size = math.floor(FONTSIZE.SCREEN_SUBTITLE * 0.8), name_size = math.floor(FONTSIZE.SCREEN_SUBTITLE * 0.75),
		desc_size = math.floor(FONTSIZE.SCREEN_TEXT * 0.8) },
}
local LIST_W = SIZES.normal.list_w
-- the skills are round: with a skill on it a button has no square background,
-- and the round skill fills the spot (an empty slot keeps the square)
local ICON_FILL = 0.82 -- on the square
local PLAIN_FILL = 0.86 -- without it (0.98 made neighbours touch)
local DETAILS_BUTTON_GAP = 14 -- the description's bottom stays this far above the buttons
local DETAILS_MIN_SCALE = 0.5 -- and never shrinks below this
local GRID_GLYPH_GAP = 12 -- grid layout: between a slot's button glyph and its button
local GRID_COLUMN_GAP = 48 -- grid layout: between the two slot columns
local SOLO_MAX_SCALE = 1.5 -- alone, the game scales the panel up; a tall one no more than this
-- the slot being changed: an outline that follows the round skill, hanger and all (the
-- game's own way of outlining a skill: SkillIconWidget's border_highlight, the
-- medallion's frame drawn a bit bigger behind it in a flat colour): a dark line, the
-- selection green, a dark edge (scale of the frame, colour). An empty slot (no skill:
-- the square) keeps the game's square selection.
local PICK_GREEN = { 141 / 255, 232 / 255, 116 / 255, 1 }
local PICK_DARK = { 0.09, 0.07, 0.06, 1 }
local PICK_RINGS = { { 1.18, PICK_DARK }, { 1.145, PICK_GREEN }, { 1.055, PICK_DARK } }   -- outside in
-- the weapon type: the game's weapon type icons (WEAPON_TYPE_TO_TEX: the "Select weapon
-- type" menu's), top right of the panel for the loadout shown, and after the name of a
-- skill only that weapon can use
local WEAPON_ICON_SIZE = { tall = 84, grid = 70 }
local WEAPON_ICON_OFFSET = { -42, -38 }   -- from the panel's top right corner (in its corner, 2026-11-11)
local function WeaponTex(weapon)
	local map = rawget(_G, "WEAPON_TYPE_TO_TEX")
	return weapon ~= nil and type(map) == "table" and map[weapon] or nil
end
-- A skill's class icon: its weapon's; with no weapon (class_icons), the game's
-- boss icon for boss / miniboss skills (the one by kill counts) and its "any
-- weapon" icon (the Select Weapon title's) for the rest.
local function ClassTex(weapon, def)
	local tex = WeaponTex(weapon)
	if tex ~= nil or def == nil then
		return tex
	end
	local kind = Core.SkillClass(def.name)
	return kind ~= nil and Core.CLASS_ICONS[kind] or nil
end
local function WeaponGlyph(weapon, def)
	local tex = ClassTex(weapon, def)
	return tex ~= nil and string.format(" <p img='%s' color=0 scale=0.9>", tex) or ""
end

-- A slot's name: one line per line of text (the class icon stays on the name's
-- line, at its end); a long name ("Gourdo's Community Garden") gets a smaller
-- font instead of wrapping. Below the smallest size it wraps as before.
local LABEL_MAX_W = 420
local LABEL_MIN_SCALE = 0.7
local function FitLabel(label)
	local base = FONTSIZE.SCREEN_TEXT
	local size = base
	label:SetFontSize(size)
	local w = Size(label, 0, 0)
	while w > LABEL_MAX_W and size - 2 >= base * LABEL_MIN_SCALE do
		size = size - 2
		label:SetFontSize(size)
		w = Size(label, 0, 0)
	end
	if w > LABEL_MAX_W then
		label:SetAutoSize(LABEL_MAX_W)
	end
	return size
end

local function WithGlyph(control_name, text)
	local control = rawget(Controls.Digital, control_name)
	if control == nil or control.key == nil then
		return text
	end
	return string.format("<p bind='%s' color=0> %s", control.key, text)
end

-- Two Weapons' swap attacks (that mod may not be on)
local function GetTwoWeapons(player)
	local tw = player ~= nil and player.components ~= nil and player.components.twoweapons or nil
	if tw ~= nil and tw.SWAP_ATTACKS_API ~= nil and tw.GetSwapAttacks ~= nil and tw.SetSwapAttacks ~= nil then
		return tw
	end
	return nil
end

local function MakeSkillItem(player, def)
	if def ~= nil and def.skillslots_pseudo then
		return Core.MakePseudoItem(def) -- Block: not a skill power
	end
	local pm = player.components.powermanager
	return pm ~= nil and def ~= nil and pm:CreatePower(def) or nil
end

-- The details under the list show a skill's main paragraph; the rest (its rules:
-- stocks, recharge...) is on the Skill info page. The game writes those as
-- paragraphs ("\n\n" in strings_powers.lua).
local function MainParagraph(desc)
	local i = type(desc) == "string" and desc:find("\n\n", 1, true) or nil
	return i ~= nil and desc:sub(1, i - 1) or desc
end

local function GetSkillDesc(player, def)
	if def ~= nil and def.skillslots_pseudo then
		return def.pretty ~= nil and def.pretty.desc or ""
	end
	local item = MakeSkillItem(player, def)
	if item == nil or Power.GetDescForPower == nil then
		return ""
	end
	local ok, desc = pcall(Power.GetDescForPower, item, player)
	return ok and type(desc) == "string" and desc or ""
end

-- Left column: title block + 4 slot rows must fit between the character banner
-- (top) and the panel's bottom edge.
local SLOT_SIZE = SIZES.normal.slot

local function Glyph(slot)
	local control = slot == "B" and Controls.Digital.SKILL or Core.controls[slot]
	return control ~= nil and string.format("<p bind='%s' color=0>", control.key) or slot
end

local function Items()
	return Core.Defs -- the skill defs, and Block
end

----------------------------------------------------------------------------
-- One square skill button (used for the slots and the list).

local SkillButton = Class(Clickable, function(self, player, size)
	Clickable._ctor(self, "SkillButton")
	self:SetOwningPlayer(player)
	self.player = player
	self.size = size

	self.background = self:AddChild(Image("images/ui_ftf_shop/inventory_slot_rare.tex"))
		:SetName("Background")
		:SetSize(size, size)
	self.icon = self:AddChild(SkillIconWidget())
		:SetName("Icon")
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.lock_badge = self:AddChild(Image("images/icons_ftf/lock_icon.tex"))
		:SetName("Lock badge")
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetMultColorAlpha(0.6)
		:SetScale(0.35)
		:Hide()
	self.selected_overlay = self:AddChild(Image("images/ui_ftf_character/ItemBgSelection.tex"))
		:SetName("Selected overlay")
		:SetSize(size + 10, size + 10)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.equipped_badge = self:AddChild(Image("images/ui_ftf_character/ItemBgEquipped.tex"))
		:SetName("Equipped badge")
		:SetSize(size + 10, size + 10)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.slot_text = self:AddChild(Text(FONTFACE.DEFAULT, math.floor(size * 0.28)))
		:SetName("Slot text")
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.tag_text = self:AddChild(Text(FONTFACE.DEFAULT, math.floor(size * 0.18)))
		:SetName("Tag text")
		:SetOutlineColor(UICOLORS.BLACK) -- readable on the round skill and on the panel
		:EnableOutline()
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
end)

-- the outline round the skill (made the first time it's needed, on the skill
-- icon's own frame holder so it scales and dims with it); nil if the icon can't
-- have one
function SkillButton:_Rings()
	if self.pick_rings ~= nil then
		return self.pick_rings
	end
	local icon = self.icon
	local holder = icon ~= nil and rawget(icon, "icon_container") or nil
	if holder == nil or icon.BuildTextureName == nil or rawget(icon, "skill") == nil then
		return nil
	end
	local tex = icon:BuildTextureName()
	self.pick_rings = {}
	for i = #PICK_RINGS, 1, -1 do       -- inside out: each new one goes behind the last
		local scale, colour = PICK_RINGS[i][1], PICK_RINGS[i][2]
		local ring = holder:AddChild(Image(tex))
			:SetName("Pick ring " .. i)
			:SetScale(scale, scale)
			:SetMultColor(0, 0, 0, 1)
			:SetAddColor(colour[1], colour[2], colour[3], 1)
			:SetHiddenBoundingBox(true)
			:IgnoreInput()
			:SendToBack()
			:Hide()
		table.insert(self.pick_rings, ring)
	end
	return self.pick_rings
end

-- how big the round skill is: fills the spot without the square background
function SkillButton:_IconWidth()
	return self.size * (self.plain and PLAIN_FILL or ICON_FILL)
end

-- no square background behind the skill (the button keeps its size for the
-- cursor and the mouse)
function SkillButton:SetPlain(plain)
	self.plain = plain == true
	self.background:SetMultColorAlpha(self.plain and 0 or 1)
	if self.def ~= nil then
		self.icon:SetScaleToMatchWidth(self:_IconWidth())
	end
	return self
end

-- the slot buttons change size with the panel (taller panel: bigger)
function SkillButton:SetButtonSize(size)
	if size == self.size then
		return self
	end
	self.size = size
	self.background:SetSize(size, size)
	self.selected_overlay:SetSize(size + 10, size + 10)
	self.equipped_badge:SetSize(size + 10, size + 10)
	self.slot_text:SetFontSize(math.floor(size * 0.28))
	self.tag_text:SetFontSize(math.floor(size * 0.18))
	if self.def ~= nil then
		self.icon:SetScaleToMatchWidth(self:_IconWidth())
	end
	if self.on_slot ~= nil then
		self:SetOnSlot(self.on_slot)
	end
	if self.tag ~= nil then
		self.tag_text:LayoutBounds("center", "top", self.background):Offset(0, -6)
	end
	return self
end

-- locked = can't be picked; dim = picked but can't fire now (other weapon)
function SkillButton:SetSkill(def, locked, dim)
	self.def = def
	self.locked = locked
	if def ~= nil then
		local item = MakeSkillItem(self.player, def)
		if item ~= nil then
			self.icon:SetSkill(item)
			Core.FitIcon(self.icon, def)
			self.icon:SetScaleToMatchWidth(self:_IconWidth())
			self.icon:Show()
			if self.pick_rings ~= nil and self.icon.BuildTextureName ~= nil then
				local tex = self.icon:BuildTextureName()   -- the frame by the skill's rarity
				for _, ring in ipairs(self.pick_rings) do
					ring:SetTexture(tex)
				end
			end
		end
		self.icon:SetMultColorAlpha(locked and 0.25 or dim and 0.5 or 1)
	else
		self.icon:Hide()
	end
	self.lock_badge:SetShown(locked == true)
	if self.picked then
		self:SetPicked(true)
	end
	return self
end

-- Small text on top of the button (which weapon a skill needs).
function SkillButton:SetTag(text)
	self.tag = text
	if text ~= nil then
		self.tag_text:SetText(text)
		self.tag_text:LayoutBounds("center", "top", self.background):Offset(0, -6)
	end
	self.tag_text:SetShown(text ~= nil and self.tag_on ~= false)
	return self
end

-- the "Names" option: the tag stays set, only shown or hidden
function SkillButton:SetTagShown(on)
	self.tag_on = on ~= false
	self.tag_text:SetShown(self.tag ~= nil and self.tag_on)
	return self
end

-- the slot being changed: the outline round its skill (an empty slot: the square)
function SkillButton:SetPicked(selected)
	self.picked = selected == true
	local rings = self.picked and self.def ~= nil and self:_Rings() or nil
	for _, ring in ipairs(self.pick_rings or {}) do
		ring:SetShown(rings ~= nil)
	end
	self.selected_overlay:SetShown(self.picked and rings == nil)
	return self
end

-- Which slot this skill is on (list buttons), or nil.
function SkillButton:SetOnSlot(slot)
	self.on_slot = slot
	self.equipped_badge:SetShown(slot ~= nil)
	if slot ~= nil then
		self.slot_text:SetText(Glyph(slot)):Show()
		self.slot_text:LayoutBounds("left", "bottom", self.background):Offset(6, 4)
	else
		self.slot_text:Hide()
	end
	return self
end

----------------------------------------------------------------------------
-- One player's panel

local SkillSlotsPanel = Class(SinglePanel, function(self, player)
	SinglePanel._ctor(self, player)
	Core.ResetListNames(player) -- the list's names start off each time (list_names)
	self:SetName("SkillSlotsPanel")
	self.selected_slot = Core.MENU_SLOTS[1]
	self.bg_w, self.bg_h = Size(self.bg, PANEL_W, PANEL_H) -- the game's panel art
	self.layout_mode = nil
	self.sizes = SIZES.normal

	-- Left: the slots, for the weapon type in hand
	self.slots_root = self:AddChild(Widget()):SetName("Slots")
	-- title + swap hint stacked, kept clear of the character banner at the top
	self.title_block = self.slots_root:AddChild(Widget()):SetName("Title block")
	self.loadout_title = self.title_block:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE))
		:SetName("Loadout title")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
	self.swap_hint = self.title_block:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 0.85))
		:SetName("Swap hint")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:LeftAlign()
	-- the loadout's weapon type, top right (made by SetWeaponIcon)
	self.weapon_icon = nil

	-- after a weapon swap the game switches the skills a tick later; then
	-- show the new weapon's loadout
	self.inst:ListenForEvent("skillslots_changed", function()
		if self.shown_weapon ~= Core.GetCurrentWeapon(player) then
			self:OnWeaponChanged()
		end
	end, player)
	self.slot_rows = {}
	for _, slot in ipairs(Core.MENU_SLOTS) do
		local row = self.slots_root:AddChild(Widget()):SetName("Slot row " .. slot)
		row.glyph = row:AddChild(Text(FONTFACE.DEFAULT, 58)):SetText(Glyph(slot))
		row.button = row:AddChild(SkillButton(player, SLOT_SIZE))
		row.label = row:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:LeftAlign()
		row.button.slot = slot
		row.button:SetOnClickFn(function() self:OnSlotClicked(slot) end)
		row.button:SetOnGainFocus(function()
			if self:_IsGamepad() then
				self:ShowDetails(Core.GetSlotValue(player, slot))
			end
		end)
		self.slot_rows[slot] = row
	end

	-- Right: the skills
	self.list_bg = self:AddChild(Panel("images/ui_ftf/flat_cornered_panel.tex"))
		:SetName("List bg")
		:SetNineSliceCoords(44, 40, 208, 200)
		:SetSize(LIST_W, SIZES.normal.list_h)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetMultColorAlpha(0.2)
	self.list_scroll = self:AddChild(ScrollPanel())
		:SetName("List scroll")
		:SetSize(LIST_W + 35, SIZES.normal.list_h)
		:SetBarInset(50)
		:SetVirtualMargin(40)
	self.list_contents = self.list_scroll:AddScrollChild(Widget()):SetName("List contents")

	-- Details under the list
	self.details = self:AddChild(Widget()):SetName("Details")
	self.skill_name = self.details:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(820)
	self.skill_desc = self.details:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(HexToRGB(0x665950ff))
		:LeftAlign()
		:SetAutoSize(820)
	-- a skill you don't own (Show all): the game's lock after its name
	self.owned_lock = self.details:AddChild(Image("images/icons_ftf/lock_icon.tex"))
		:SetName("Not owned")
		:SetSize(math.floor(FONTSIZE.SCREEN_SUBTITLE * 0.8), math.floor(FONTSIZE.SCREEN_SUBTITLE * 0.8))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
		:IgnoreInput()
		:Hide()
	self.buttons = self:AddChild(Widget()):SetName("Buttons")
	-- every button can be reached with the D-pad / stick (down from the list)
	self.info_button = self.buttons:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.75, BUTTON_H)
		:SetSecondary()
		:SetScale(0.65)
		:SetNormalScale(0.65)
		:SetFocusScale(0.7)
		:SetNavFocusable(true)
		:SetText(WithGlyph("MENU_SECONDARY", STR.INFO))
		:SetOnClick(function() self:OnInfoClicked() end)
	self.clear_button = self.buttons:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.95, BUTTON_H)
		:SetPrimary()
		:SetFlipped()
		:SetScale(0.65)
		:SetNormalScale(0.65)
		:SetFocusScale(0.7)
		:SetNavFocusable(true)
		:SetText(WithGlyph("MENU_UNCOMMON", STR.CLEAR))
		:SetOnClick(function() self:OnClearClicked() end)
	self.hide_button = self.buttons:AddChild(ActionButton())
		:SetSize(BUTTON_W * 1.1, BUTTON_H)
		:SetSecondary()
		:SetScale(0.65)
		:SetNormalScale(0.65)
		:SetFocusScale(0.7)
		:SetNavFocusable(true)
		:SetText(WithGlyph("MENU_TAB_NEXT", STR.HIDE_OTHER))
		:SetOnClick(function() self:OnHideClicked() end)
	self.hud_button = self.buttons:AddChild(ActionButton())
		:SetSize(BUTTON_W * 1.0, BUTTON_H)
		:SetSecondary()
		:SetScale(0.65)
		:SetNormalScale(0.65)
		:SetFocusScale(0.7)
		:SetNavFocusable(true)
		:SetText(STR.HUD_ON)
		:SetOnClick(function() self:OnHudClicked() end)
	self.names_button = self.buttons:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.9, BUTTON_H)
		:SetSecondary()
		:SetScale(0.65)
		:SetNormalScale(0.65)
		:SetFocusScale(0.7)
		:SetNavFocusable(true)
		:SetText(WithGlyph("MENU_TAB_PREV", STR.NAMES_ON))
		:SetOnClick(function() self:OnNamesClicked() end)
	self.swap_attacks_button = self.buttons:AddChild(ActionButton())
		:SetSize(BUTTON_W * 1.1, BUTTON_H)
		:SetSecondary()
		:SetScale(0.65)
		:SetNormalScale(0.65)
		:SetFocusScale(0.7)
		:SetNavFocusable(true)
		:SetText(WithGlyph("MENU_VIEW_RELATED", STR.SWAP_ATTACKS_ON))
		:SetOnClick(function() self:OnSwapAttacksClicked() end)
	self:RefreshSwapAttacks()

	self:HideDuringPopups{ self.info_button, self.clear_button, self.hide_button, self.hud_button, self.names_button, self.swap_attacks_button }
end)

function SkillSlotsPanel:_IsGamepad()
	local player = self:GetOwningPlayer()
	return player ~= nil and player.components.playercontroller:IsRelativeNavigation()
end

function SkillSlotsPanel:FindDefaultFocus()
	local row = self.slot_rows[self.selected_slot]
	return row ~= nil and row.button or self.list_contents:GetFirstChild()
end

function SkillSlotsPanel:OnOpenPanel()
	-- RB toggles Show all only on a fresh press: holding RB at a weapon rack opens the menu
	self.opened_at = GetTime ~= nil and GetTime() or os.clock()
	self.showall_pressed_at = nil
	Core.ResetHideOther(self:GetOwningPlayer()) -- every open starts hidden
	self:RefreshSwapAttacks()
	self:RefreshHudButton()
	self:RefreshNamesButton()
	self:RefreshList()
	self:RefreshSlots()
	self:ShowDetails(Core.GetSlotValue(self:GetOwningPlayer(), self.selected_slot))
	local row = self.slot_rows[self.selected_slot]
	if row ~= nil then
		row.button:SetFocus(self:GetOwningPlayer():GetHunterId())
	end
	SkillSlotsPanel._base.OnOpenPanel(self)
end

function SkillSlotsPanel:RefreshSlots()
	local player = self:GetOwningPlayer()
	local items = Items()
	local current = Core.GetCurrentWeapon(player)
	self.loadout_title:SetText(current ~= nil and string.format(STR.LOADOUT, Core.GetWeaponName(current)) or STR.LOADOUT_ANY)
	self:SetWeaponIcon(current)
	local on_slot = {} -- slot value -> slot, for the list badges
	for _, slot in ipairs(Core.MENU_SLOTS) do
		local row = self.slot_rows[slot]
		local value = Core.GetSlotValue(player, slot)
		local name = Core.GetSlotSkill(player, slot)
		local def = name ~= nil and items[name] or nil
		local usable = def == nil or Core.CanUse(player, def)
		row.button:SetSkill(def, false, not usable):SetPicked(slot == self.selected_slot)
		row.button:SetPlain(def ~= nil)
		local text
		if value == Core.WEAPON then
			text = (def ~= nil and (Core.GetSkillName(def) .. WeaponGlyph(Core.GetSkillWeapon(def) or current, def) .. "\n") or "") .. STR.WEAPON
		elseif def ~= nil then
			local weapon = Core.GetSkillWeapon(def)
			text = Core.GetSkillName(def) .. WeaponGlyph(weapon, def)
			if not usable and weapon ~= nil then
				text = text .. "\n" .. string.format(STR.NEEDS_SHORT, Core.GetWeaponName(weapon))
			end
		else
			text = STR.EMPTY
		end
		row.label:SetText(text)
		FitLabel(row.label)
		if value ~= nil then
			on_slot[value] = slot
		end
	end
	for _, w in ipairs(self.list_contents.children) do
		w:SetOnSlot(w.choice ~= nil and on_slot[w.choice.name] or nil)
	end
	self:RefreshButtons()
	self:Layout()
end

-- the loadout's weapon type icon, top right of the panel (none without a weapon type)
function SkillSlotsPanel:SetWeaponIcon(weapon)
	local tex = WeaponTex(weapon)
	if tex == self.weapon_icon_tex then
		return self
	end
	self.weapon_icon_tex = tex
	if self.weapon_icon ~= nil then
		self.weapon_icon:Remove()
		self.weapon_icon = nil
	end
	if tex ~= nil then
		self.weapon_icon = self:AddChild(Image(tex))
			:SetName("Weapon type")
			:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
			:IgnoreInput()
		self:LayoutWeaponIcon()
	end
	return self
end

function SkillSlotsPanel:LayoutWeaponIcon()
	local icon = self.weapon_icon
	if icon == nil then
		return self
	end
	local target = WEAPON_ICON_SIZE[self.sizes.grid and "grid" or "tall"]
	icon:SetScale(1)
	local w, h = Size(icon, target, target)
	local sc = target / math.max(w, h, 1)
	icon:SetScale(sc)
		:LayoutBounds("right", "top", self.bg)
		:Offset(WEAPON_ICON_OFFSET[1], WEAPON_ICON_OFFSET[2])
	return self
end

function SkillSlotsPanel:RefreshList()
	local player = self:GetOwningPlayer()
	self.list_contents:RemoveAllChildren()
	self.shown_weapon = Core.GetCurrentWeapon(player)
	local swap = rawget(Controls.Digital, "TWOWEAPONS_SWAP")
	local tw = player.components.twoweapons
	if swap ~= nil and tw ~= nil and tw:GetOther() ~= nil then
		self.swap_hint:SetText(string.format(STR.SWAP_HINT, swap.key)):Show()
	else
		self.swap_hint:Hide()
	end
	local hide = Core.GetHideOther(player)
	self.hide_button:SetText(WithGlyph("MENU_TAB_NEXT", hide and STR.SHOW_OTHER or STR.HIDE_OTHER))
	for _, choice in ipairs(Core.GetChoices(player)) do
		if not hide or Core.IsAvailable(choice) then
			self:_AddChoice(player, choice)
		end
	end
	self.list_contents:LayoutChildrenInGrid(self.sizes.columns, self.sizes.gap or 20)
		:LayoutBounds("center", "top", self.list_bg)
	self.list_scroll:RefreshView()
	self.list_built = true
end

-- The game's popup darkening (skill info, the "Ready!" popup) is the panel
-- art at its own size; cover the panel at the size this layout gives it.
function SkillSlotsPanel:_FitPopupBg()
	if self.popup_bg ~= nil and self.bg ~= nil then
		local w, h = Size(self.bg, 0, 0)
		if w > 0 and h > 0 then
			self.popup_bg:SetSize(w, h):LayoutBounds("center", "center", self.bg)
		end
	end
end

function SkillSlotsPanel:OnPopupsChanged(...)
	self:_FitPopupBg()
	return SkillSlotsPanel._base.OnPopupsChanged(self, ...)
end

-- mode: "tall" (1 or 2 players) or "grid" (3 or 4), see SIZES
function SkillSlotsPanel:SetLayoutMode(mode)
	local sizes = SIZES[mode]
	if sizes == nil or self.layout_mode == mode then
		return self
	end
	self.layout_mode = mode
	self.sizes = sizes
	if self.bg ~= nil then
		self.bg:SetSize(self.bg_w, mode == "tall" and TALL_H or self.bg_h)
	end
	self:_FitPopupBg()
	self.list_bg:SetSize(sizes.list_w, sizes.list_h)
	self.list_scroll:SetSize(sizes.list_w + 35, sizes.list_h)
	for _, row in pairs(self.slot_rows) do
		row.button:SetButtonSize(sizes.slot)
	end
	self.loadout_title:SetFontSize(sizes.title_size or FONTSIZE.SCREEN_SUBTITLE)
	self.skill_name:SetFontSize(sizes.name_size or FONTSIZE.SCREEN_SUBTITLE)
	local lock = math.floor((sizes.name_size or FONTSIZE.SCREEN_SUBTITLE) * 0.8)
	self.owned_lock:SetSize(lock, lock)
	self.skill_desc:SetFontSize(sizes.desc_size or FONTSIZE.SCREEN_TEXT)
	if self.list_built then
		-- rebuild the list with the new icon size; keep the cursor on the same skill
		local player = self:GetOwningPlayer()
		local hunter = player ~= nil and player.GetHunterId ~= nil and player:GetHunterId() or nil
		local ok, focus = false, nil
		if hunter ~= nil and TheFrontEnd ~= nil and TheFrontEnd.GetFocusWidget ~= nil then
			ok, focus = pcall(TheFrontEnd.GetFocusWidget, TheFrontEnd, hunter)
		end
		local focused_choice = ok and focus ~= nil and focus.parent == self.list_contents and focus.choice ~= nil
			and focus.choice.name or nil
		self:RefreshList()
		self:RefreshSlots()
		if focused_choice ~= nil then
			for _, w in ipairs(self.list_contents.children) do
				if w.choice ~= nil and w.choice.name == focused_choice then
					w:SetFocus(hunter)
					break
				end
			end
		end
	end
	self:Layout()
	return self
end

function SkillSlotsPanel:_AddChoice(player, choice)
	local w = self.list_contents:AddChild(SkillButton(player, self.sizes.icon))
	w:SetTagShown(Core.GetListNames(player))
	w:SetSkill(choice.def, false, not choice.usable)
	w:SetPlain(choice.def ~= nil)
	if choice.token then
		w:SetTag(STR.WEAPON_TAG)
	elseif choice.weapon ~= nil then
		w:SetTag(Core.GetWeaponName(choice.weapon))
	else
		local kind = Core.SkillClass(choice.name)
		if kind ~= nil then
			w:SetTag(STR.CLASS_TAG[kind])
		end
	end
	w.choice = choice
	w:SetOnClickFn(function() self:OnSkillClicked(w) end)
	w:SetOnGainFocus(function()
		if self:_IsGamepad() then
			self:ShowDetails(choice.name, w)
		end
	end)
end

-- name: a skill name, Core.WEAPON or nil
function SkillSlotsPanel:ShowDetails(name, widget)
	local player = self:GetOwningPlayer()
	self.details_name = name
	self.skill_name:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	if name == Core.WEAPON then
		local native = Core.GetNativeSkillName(player)
		local def = native ~= nil and Items()[native] or nil
		-- the weapon's own skill: its name (just "Weapon skill" when there's none)
		self.skill_name:SetText(def ~= nil and (Core.GetSkillName(def)
			.. WeaponGlyph(Core.GetSkillWeapon(def) or Core.GetCurrentWeapon(player), def)) or STR.WEAPON)
		self.skill_desc:SetText(STR.WEAPON_DESC)
		self.owned_lock:Hide()
	else
		local def = name ~= nil and Items()[name] or nil
		if def == nil then
			self.skill_name:SetText(STR.EMPTY)
			self.skill_desc:SetText("")
			self.owned_lock:Hide()
		else
			local weapon = Core.GetSkillWeapon(def)
			self.skill_name:SetText(Core.GetSkillName(def) .. WeaponGlyph(weapon, def))
			local desc = MainParagraph(GetSkillDesc(player, def))
			if weapon ~= nil and not Core.CanUse(player, def) then
				desc = desc .. (desc ~= "" and "\n" or "") .. string.format(STR.NEEDS, Core.GetWeaponName(weapon))
			end
			self.skill_desc:SetText(desc)
			-- not owned (shown with Show all, it still works on a slot): the lock
			self.owned_lock:SetShown(not Core.OwnsSkill(player, name))
		end
	end
	self:LayoutDetails()
end

function SkillSlotsPanel:RefreshButtons()
	local value = Core.GetSlotValue(self:GetOwningPlayer(), self.selected_slot)
	if self.selected_slot == "B" then
		self.clear_button:SetText(WithGlyph("MENU_UNCOMMON", STR.CLEAR_B))
		self.clear_button:SetEnabled(value ~= Core.WEAPON)
	else
		self.clear_button:SetText(WithGlyph("MENU_UNCOMMON", STR.CLEAR))
		self.clear_button:SetEnabled(value ~= nil)
	end
end

-- name: a skill name or Core.WEAPON
function SkillSlotsPanel:_FindListWidget(name)
	for _, w in ipairs(self.list_contents.children) do
		if w.choice ~= nil and w.choice.name == name then
			return w
		end
	end
	return nil
end

function SkillSlotsPanel:OnSlotClicked(slot)
	self.selected_slot = slot
	self:RefreshSlots()
	local name = Core.GetSlotValue(self:GetOwningPlayer(), slot)
	self:ShowDetails(name)
	-- on gamepad, picking a slot sends the cursor to the list
	if self:_IsGamepad() then
		local w = (name ~= nil and self:_FindListWidget(name)) or self.list_contents:GetFirstChild()
		if w ~= nil then
			w:SetFocus(self:GetOwningPlayer():GetHunterId())
		end
	end
end

function SkillSlotsPanel:OnSkillClicked(w)
	self:ShowDetails(w.choice.name, w)
	local player = self:GetOwningPlayer()
	Core.SetSlotSkill(player, self.selected_slot, w.choice.name)
	self:RefreshSlots()
	if self:_IsGamepad() then
		self.slot_rows[self.selected_slot].button:SetFocus(player:GetHunterId())
	end
end

-- Two Weapons' swap button in the menu: swap the real weapon.
function SkillSlotsPanel:OnSwapWeapon()
	local tw = self:GetOwningPlayer().components.twoweapons
	if tw ~= nil and tw:GetOther() ~= nil then
		tw:TrySwap()
	end
end

function SkillSlotsPanel:OnWeaponChanged()
	local player = self:GetOwningPlayer()
	self:RefreshList()
	self:RefreshSlots()
	self:ShowDetails(Core.GetSlotValue(player, self.selected_slot))
	self.slot_rows[self.selected_slot].button:SetFocus(player:GetHunterId())
end

-- Swap button (LS / keyboard R, from Two Weapons). Two Weapons may load after
-- this mod, so its control is looked up here, not in CONTROL_MAP.
function SkillSlotsPanel:HandleControlUp(controls, ...)
	local swap = rawget(Controls.Digital, "TWOWEAPONS_SWAP")
	if swap ~= nil and controls:Has(swap) then
		self:OnSwapWeapon()
		return true
	end
	local base = SkillSlotsPanel._base.HandleControlUp
	return base ~= nil and base(self, controls, ...) or false
end

function SkillSlotsPanel:OnHideClicked()
	local player = self:GetOwningPlayer()
	local hunter = player:GetHunterId()
	local on_button = self.hide_button.HasFocus ~= nil and self.hide_button:HasFocus(hunter)
	Core.SetHideOther(player, not Core.GetHideOther(player))
	self:RefreshList()
	self:RefreshSlots()
	self:ShowDetails(Core.GetSlotValue(player, self.selected_slot))
	-- the list was rebuilt: the cursor stays on the button (D-pad use) or goes
	-- back to the selected slot
	if on_button then
		self.hide_button:SetFocus(hunter)
	else
		self.slot_rows[self.selected_slot].button:SetFocus(hunter)
	end
end

-- The skill the cursor is on: a list entry, a slot (its skill), or else the
-- one the details show. A skill name, Core.WEAPON or nil.
function SkillSlotsPanel:_CursorSkill()
	local player = self:GetOwningPlayer()
	local ok, focus = pcall(TheFrontEnd.GetFocusWidget, TheFrontEnd, player:GetHunterId())
	local w = ok and focus or nil
	while w ~= nil and w ~= self do
		if w.choice ~= nil then
			return w.choice.name
		end
		if w.slot ~= nil and self.slot_rows[w.slot] ~= nil and self.slot_rows[w.slot].button == w then
			return Core.GetSlotValue(player, w.slot)
		end
		w = w.parent
	end
	return self.details_name
end

-- Popup with everything about a skill, the size of this player's panel.
function SkillSlotsPanel:ShowSkillInfo(name)
	local player = self:GetOwningPlayer()
	local screen = self.GetScreen ~= nil and self:GetScreen() or nil
	if screen == nil or screen.ShowPopup == nil or screen.ClosePopup == nil then
		return false
	end
	if self.HasPopup ~= nil and self:HasPopup(player) then
		return false
	end
	local items = Items()
	local def, note
	if name == Core.WEAPON then
		local native = Core.GetNativeSkillName(player)
		def = native ~= nil and items[native] or nil
		note = SkillInfoPopup.STR.WEAPON_TOKEN
	elseif name ~= nil then
		def = items[name]
	end
	if def == nil then
		self.info_button:OnFocusNudge("up")
		return false
	end
	local tags = {}
	local weapon = Core.GetSkillWeapon(def)
	tags[#tags + 1] = weapon ~= nil and string.format(SkillInfoPopup.STR.WEAPON_SKILL, Core.GetWeaponName(weapon))
		or SkillInfoPopup.STR.ANY_WEAPON
	tags[#tags + 1] = Core.OwnsSkill(player, def.name) and SkillInfoPopup.STR.OWNED or SkillInfoPopup.STR.NOT_OWNED
	for _, slot in ipairs(Core.MENU_SLOTS) do
		if Core.GetSlotSkill(player, slot) == def.name then
			tags[#tags + 1] = string.format(SkillInfoPopup.STR.ON_SLOT, Glyph(slot))
		end
	end
	local w, h = 1500, 900
	if self.bg ~= nil and self.bg.GetSize ~= nil then
		local ok, bw, bh = pcall(self.bg.GetSize, self.bg)
		if ok and type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0 then
			w, h = bw * 0.97, bh * 0.95
		end
	end
	local popup = SkillInfoPopup(player, def, {
		width = w, height = h,
		item = MakeSkillItem(player, def),
		tags = table.concat(tags, "   ·   "),
		note = note,
		text = def.skillslots_pseudo and GetSkillDesc(player, def) or nil,
		fallback_desc = GetSkillDesc(player, def),
	})
	local hunter = player:GetHunterId()
	local ok_focus, last_focus = pcall(TheFrontEnd.GetFocusWidget, TheFrontEnd, hunter)
	screen:ShowPopup(player, popup)
	popup:SetScale(1) -- the panel's own size
	if self.bg ~= nil then
		popup:LayoutBounds("center", "center", self.bg)
	end
	popup:SetOnCloseFn(function()
		screen:ClosePopup(player, popup)
		local back = ok_focus and last_focus or nil
		if back == nil or back.removed then
			back = self:FindDefaultFocus()
		end
		if back ~= nil then
			back:SetFocus(hunter)
		end
	end)
	popup:AnimateIn()
	self.info_popup = popup
	return true
end

function SkillSlotsPanel:OnInfoClicked()
	return self:ShowSkillInfo(self:_CursorSkill())
end

-- LT / RT / RS icons on the HUD, on / off for this player.
function SkillSlotsPanel:RefreshHudButton()
	self.hud_button:SetText(Core.GetHudIcons(self:GetOwningPlayer()) and STR.HUD_ON or STR.HUD_OFF)
end

function SkillSlotsPanel:RefreshNamesButton()
	self.names_button:SetText(WithGlyph("MENU_TAB_PREV", Core.GetListNames(self:GetOwningPlayer()) and STR.NAMES_ON or STR.NAMES_OFF))
end

-- the names over the list's skills, on / off for this player
function SkillSlotsPanel:OnNamesClicked()
	local player = self:GetOwningPlayer()
	Core.SetListNames(player, not Core.GetListNames(player))
	self:RefreshNamesButton()
	local on = Core.GetListNames(player)
	for _, w in ipairs(self.list_contents.children) do
		if w.SetTagShown ~= nil then
			w:SetTagShown(on)
		end
	end
	self:LayoutButtons()
end

function SkillSlotsPanel:OnHudClicked()
	local player = self:GetOwningPlayer()
	Core.SetHudIcons(player, not Core.GetHudIcons(player))
	self:RefreshHudButton()
	self:LayoutDetails()
end

-- Two Weapons' swap attacks, on / off for this player.
function SkillSlotsPanel:RefreshSwapAttacks()
	local tw = GetTwoWeapons(self:GetOwningPlayer())
	self.swap_attacks_button:SetShown(tw ~= nil)
	if tw ~= nil then
		self.swap_attacks_button:SetText(WithGlyph("MENU_VIEW_RELATED", tw:GetSwapAttacks() and STR.SWAP_ATTACKS_ON or STR.SWAP_ATTACKS_OFF))
	end
end

function SkillSlotsPanel:OnSwapAttacksClicked()
	local tw = GetTwoWeapons(self:GetOwningPlayer())
	if tw == nil then
		return
	end
	tw:SetSwapAttacks(not tw:GetSwapAttacks())
	self:RefreshSwapAttacks()
	self:LayoutDetails()
end

function SkillSlotsPanel:OnClearClicked()
	local player = self:GetOwningPlayer()
	Core.SetSlotSkill(player, self.selected_slot, nil)
	self:RefreshSlots()
	self:ShowDetails(Core.GetSlotValue(player, self.selected_slot))
end

SkillSlotsPanel.CONTROL_MAP = {
	{
		control = Controls.Digital.MENU_UNCOMMON, -- Y: clear the selected slot
		fn = function(self)
			if self.clear_button:IsEnabled() then
				self.clear_button:Click()
			end
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_SECONDARY, -- X (keyboard Shift): skill info popup
		fn = function(self)
			self:OnInfoClicked()
			return true
		end,
	},
}
-- LB / Q (the game's MENU_TAB_PREV, free in this menu; not RB: holding RB at a
-- weapon rack opens the menu, and a held button repeats): the list's names on /
-- off, once per press (a held LB doesn't flicker them)
local NAMES_REPEAT_GAP = 0.4
local names_control = rawget(Controls.Digital, "MENU_TAB_PREV")
if names_control ~= nil then
	table.insert(SkillSlotsPanel.CONTROL_MAP, {
		control = names_control,
		fn = function(self)
			local now = GetTime ~= nil and GetTime() or os.clock()
			if self.names_pressed_at == nil or now - self.names_pressed_at > NAMES_REPEAT_GAP then
				self.names_button:Click()
			end
			self.names_pressed_at = now
			return true
		end,
	})
end
-- RB / E (the game's MENU_TAB_NEXT): Show all / Hide unavailable, once per
-- press, and only a fresh press after the menu opens (holding RB at a weapon
-- rack opens the menu; a held button repeats)
local SHOWALL_REPEAT_GAP = 0.4
local showall_control = rawget(Controls.Digital, "MENU_TAB_NEXT")
if showall_control ~= nil then
	table.insert(SkillSlotsPanel.CONTROL_MAP, {
		control = showall_control,
		fn = function(self)
			local now = GetTime ~= nil and GetTime() or os.clock()
			local last = self.showall_pressed_at or self.opened_at
			if (last == nil or now - last > SHOWALL_REPEAT_GAP) and self.hide_button:IsShown() then
				self.hide_button:Click()
			end
			self.showall_pressed_at = now
			return true
		end,
	})
end
SkillSlotsPanel.FitLabel = FitLabel -- (for the tests)
-- View / Tab: Two Weapons' swap attacks on / off
local view_control = rawget(Controls.Digital, "MENU_VIEW_RELATED")
if view_control ~= nil then
	table.insert(SkillSlotsPanel.CONTROL_MAP, {
		control = view_control,
		fn = function(self)
			if self.swap_attacks_button:IsShown() then
				self.swap_attacks_button:Click()
			end
			return true
		end,
	})
end

function SkillSlotsPanel:LayoutButtons()
	-- the button row: centred under the panel and never wider than it (with
	-- Two Weapons it's 5 buttons; wider than the panel, it pushed 2 players'
	-- panels off the screen)
	self.buttons:SetScale(1)
	self.buttons:LayoutChildrenInRow(10)
	local panel_w = Size(self.bg, PANEL_W, 0)
	local row_w = Size(self.buttons, 0, 0)
	local fit = row_w > 0 and math.min(1, (panel_w - 2 * BUTTONS_MARGIN) / row_w) or 1
	self.buttons_scale = fit
	self.buttons:SetScale(fit)
		:LayoutBounds("center", nil, self.bg)
		:LayoutBounds(nil, "bottom", self.bg)
		:Offset(0, -50)
	return self
end

-- top and bottom of a widget, in this panel's space (nil if it can't be measured)
function SkillSlotsPanel:_VerticalExtent(w)
	local ok, top, bottom = pcall(function()
		local x1, y1, x2, y2 = w:GetBoundingBox()
		local _, a = self:TransformFromWidget(w, x1, y1)
		local _, b = self:TransformFromWidget(w, x2, y2)
		return math.max(a, b), math.min(a, b)
	end)
	if ok and type(top) == "number" and type(bottom) == "number" then
		return top, bottom
	end
	return nil
end

-- the skill name + description: under the list (tall), or under the slots
-- (grid). In both, a long description shrinks to fit above the buttons (it used
-- to run under them in the tall layout: "You don't own this skill yet ...").
function SkillSlotsPanel:LayoutDetails()
	self:LayoutButtons()
	self.details:SetScale(1)
	self.skill_name:SetPos(0, 0)
	self.owned_lock:LayoutBounds("after", "center", self.skill_name):Offset(14, 0)
	self.skill_desc:LayoutBounds("left", "below", self.skill_name):Offset(0, -6)
	local function place()
		if self.sizes.grid then
			self.details:LayoutBounds("left", "below", self.slots_root):Offset(0, -20)
		else
			self.details:LayoutBounds("left", "below", self.list_bg):Offset(40, -20)
		end
	end
	place()
	-- room down to the buttons: a long description shrinks to fit. Measured on
	-- the name and the text themselves as well as the box around them (0.14.7
	-- measured only the box, which missed the text's last lines: "hold another
	-- weapon." ran under the buttons), and again after each shrink.
	local function Extent()
		local top, bottom = self:_VerticalExtent(self.details)
		local name_top = self:_VerticalExtent(self.skill_name)
		local _, desc_bottom = self:_VerticalExtent(self.skill_desc)
		if name_top ~= nil then
			top = top ~= nil and math.max(top, name_top) or name_top
		end
		if desc_bottom ~= nil then
			bottom = bottom ~= nil and math.min(bottom, desc_bottom) or desc_bottom
		end
		return top, bottom
	end
	local scale = 1 -- (set at the top)
	for _ = 1, 3 do
		local details_top, details_bottom = Extent()
		local buttons_top = self:_VerticalExtent(self.buttons)
		if details_top == nil or details_bottom == nil or buttons_top == nil then
			break
		end
		local room = details_top - buttons_top - DETAILS_BUTTON_GAP
		local h = details_top - details_bottom
		if room <= 0 or h <= room + 0.5 or scale <= DETAILS_MIN_SCALE then
			break
		end
		scale = math.max(DETAILS_MIN_SCALE, scale * room / h)
		self.details:SetScale(scale)
		place()
	end
	return self
end

-- grid layout: the slots in a 2 x 2 grid (B LT / RT RS), no names beside them
function SkillSlotsPanel:LayoutSlotGrid()
	local size = self.sizes.slot
	local cell_w
	for _, slot in ipairs(Core.MENU_SLOTS) do
		local row = self.slot_rows[slot]
		row.label:Hide()
		row.button:SetPos(0, 0)
		row.glyph:LayoutBounds("before", "center", row.button):Offset(-GRID_GLYPH_GAP, 0)
	end
	-- the widest glyph sets where the buttons line up
	local glyph_w = 0
	for _, slot in ipairs(Core.MENU_SLOTS) do
		glyph_w = math.max(glyph_w, (Size(self.slot_rows[slot].glyph, 60, 60)))
	end
	cell_w = glyph_w + GRID_GLYPH_GAP + size
	self.title_block:LayoutChildrenInColumn(2, "left")
	self.title_block:LayoutBounds("left", "top", 0, 0)
	local _, title_h = Size(self.title_block, 0, 100)
	for k, slot in ipairs(Core.MENU_SLOTS) do
		local r, q = (k - 1) // 2, (k - 1) % 2
		local x = glyph_w + GRID_GLYPH_GAP + size / 2 + q * (cell_w + GRID_COLUMN_GAP)
		local y = -(title_h + 14 + size / 2 + r * (size + 16))
		self.slot_rows[slot]:SetPos(x, y)
	end
	return self
end

function SkillSlotsPanel:Layout()
	SkillSlotsPanel._base.Layout(self)
	local sizes = self.sizes

	if sizes.grid then
		self:LayoutSlotGrid()
		self.slots_root:LayoutBounds("left", "top", self.bg):Offset(110, -165)
	else
		for _, slot in ipairs(Core.MENU_SLOTS) do
			local row = self.slot_rows[slot]
			row.label:Show()
			row.glyph:SetPos(0, 0)
			row.button:LayoutBounds("after", "center", row.glyph):Offset(18, 0)
			row.label:LayoutBounds("after", "center", row.button):Offset(22, 0)
		end
		self.title_block:LayoutChildrenInColumn(2, "left")
		self.slots_root:LayoutChildrenInColumn(16, "left")
			:LayoutBounds("left", "top", self.bg)
			:Offset(110, -180)
	end

	-- the list: top right; the details text is as wide as the room it has
	self.list_bg:LayoutBounds("right", "top", self.bg):Offset(-100, -(sizes.list_top or 140))
	self.list_scroll:LayoutBounds("left", "top", self.list_bg)
	if sizes.grid then
		local panel_w = Size(self.bg, PANEL_W, 0)
		local text_w = math.max(300, panel_w - 110 - 100 - sizes.list_w - 35 - 45)
		self.skill_name:SetAutoSize(text_w)
		self.skill_desc:SetAutoSize(text_w)
	else
		self.skill_name:SetAutoSize(820)
		self.skill_desc:SetAutoSize(820)
	end
	self:LayoutDetails()
	self:LayoutWeaponIcon()
	return self
end

----------------------------------------------------------------------------
-- The screen: one panel per local player

local SkillSlotsScreen = Class(MultiPanelScreen, function(self, initiating_player)
	MultiPanelScreen._ctor(self, initiating_player, "SkillSlotsScreen")
	self:SetTitle(STR.TITLE, STR.DESC)
	self:_CreatePanelsForLocalPlayers(SkillSlotsPanel)
end)

-- 1 or 2 players: the tall layout; 3 or 4: the grid layout (see SIZES)
function SkillSlotsScreen:LayoutPanels()
	local panels = self.panels ~= nil and self.panels:GetChildren() or {}
	local tall = #panels <= 2
	for _, panel in ipairs(panels) do
		if panel.SetLayoutMode ~= nil then
			panel:SetLayoutMode(tall and "tall" or "grid")
		end
	end
	SkillSlotsScreen._base.LayoutPanels(self)
	-- alone, the game scales the panel up (more with the biggest text
	-- setting); a tall one only up to SOLO_MAX_SCALE so it stays on the screen
	if #panels == 1 and tall then
		local panel = panels[1]
		local sx = panel.GetScale ~= nil and panel:GetScale() or nil
		if type(sx) == "number" and sx > SOLO_MAX_SCALE then
			panel:SetScale(SOLO_MAX_SCALE)
			self.panels:LayoutBounds("center", "center", self):Offset(0, -90)
		end
	end
	return self
end

function SkillSlotsScreen:OnOpen()
	SkillSlotsScreen._base.OnOpen(self)
	self:EnableFocusBracketsForGamepadAndMouse()
end

SkillSlotsScreen.Panel = SkillSlotsPanel
SkillSlotsScreen.STR = STR
SkillSlotsScreen.MainParagraph = MainParagraph

return SkillSlotsScreen
