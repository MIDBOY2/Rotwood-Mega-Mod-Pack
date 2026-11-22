-- Tonic Swap: the potions menu (interact with a tonic station in town). Built
-- like the game's Emote Booth: MultiPanelScreen + one SinglePanel per local
-- player, so each player sets their own.
--   Potion: Soothing Spirits, Bubbling Brew or Misting Mixture, three big
--     icons on top (the game's potion slot; picked in town). Yours sits in a
--     soft light and says Equipped.
--   Tonics: one 3 x 3 grid under them. A puts a tonic in your D-pad cycle
--     (colour) or takes it out (greyed). X makes it your main tonic (equipped
--     right away, first in the cycle). Y disables cycling (only the main
--     tonic stays) or, when it's off, puts every tonic in. All nine out = no
--     tonic.
--   On the right: what's under the cursor, the buttons, the cycle line.

local Main = require "tonicswap.main"
local TSPotions = require "tonicswap.potions"
local Clickable = require "widgets/clickable"
local Image = require "widgets.image"
local MultiPanelScreen = require "screens.town.multipanelscreen"
local Panel = require "widgets.panel"
local SinglePanel = require "widgets.ftf.town.singlepanel"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local Power = require "defs.powers"

local STR = {
	TITLE = "Potions",
	DESC = "Pick your potion and your tonics.",
	POTION = "Potion",
	TONICS = "Tonics",
	POTION_CHARGES = "%d charges a refill.",
	POTION_SIPS = "%d charges a refill, %d sips each.",
	POTION_YOURS = "Your potion.",
	POTION_TOWN = "Potions are picked in town.",
	NONE = "No tonic",
	MAIN_TAG = "Main",
	EQUIPPED = "Equipped",
	IS_MAIN = "Your main tonic: first in your cycle.",
	IN_CYCLE = "In your cycle.",
	OUT_OF_CYCLE = "Out of your cycle.",
	SITTING_OUT = "Sitting out while you have %s (it does the same job); back when it goes.",
	CYCLE_IS = "D-pad left / right: %d in your cycle, %s first. All nine out = no tonic.",
	CYCLE_OFF = "Cycling off: you keep %s. All nine out = no tonic.",
	CYCLE_NOTHING = "All tonics out: no tonic.",
	HINT_TAKE = "Take this potion",
	HINT_IN = "Tonic: put it in your cycle",
	HINT_OUT = "Tonic: take it out of your cycle",
	HINT_MAIN = "Make it your main tonic",
	HINT_DISABLE = "Disable cycling (only the main tonic)",
	HINT_ALL = "Put every tonic in",
}

-- Two layouts, picked by how many players have the menu open:
-- "wide" (1, 3 or 4 players), in the game's panel art (1819 x 929, scaled up
-- when you're alone); "portrait" (2 players): a narrower, taller panel each,
-- side by side, with bigger icons and the details under them.
--   Potion                    | details of the potion or tonic under the
--   [big] [big] [big]         | cursor
--   Tonics                    |
--   [3 x 3 grid]              | A / X / Y, the cycle line at the bottom
-- More than 9 tonics: wider rows (up to 6). If it doesn't fit, it scales down.
local GRID_COLUMNS = 3
local GRID_MAX_COLUMNS = 6
local GRID_ROWS = 3
local DETAILS_MIN_W = 380
local PANEL_W, PANEL_H = 1819, 929 -- the game's panel art, if it can't be measured
local TITLE_SIZE = math.floor(FONTSIZE.SCREEN_SUBTITLE * 0.6)
-- the details box text, times FONTSIZE.SCREEN_TEXT (0.5.8: was name 1.1,
-- description 0.9, buttons / cycle line 0.8: too small to read); the
-- setting menu_text_size scales them all. A long description still shrinks to
-- fit its box.
local DETAIL_SIZES = { name = 1.6, desc = 1.35, hints = 1.0, status = 1.0 }
local function DetailSize(kind)
	local scale = Main.settings ~= nil and Main.settings.menu_text_size or nil
	scale = (type(scale) == "number" and scale > 0) and scale or 1
	return math.floor(FONTSIZE.SCREEN_TEXT * DETAIL_SIZES[kind] * scale + 0.5)
end
local GLOW = "images/ui_ftf/gradient_circle.tex" -- the game's soft light (talent hearts)
local MODES = {
	wide = { name = "wide", potion = 170, potion_gap = 56, tag_h = 40, button = 124, spacing = 12, title_gap = 12,
		section_gap = 22, details_gap = 70, margin_x = 100, top = 205, bottom = 60, title = TITLE_SIZE }, -- top: under the player's nameplate (670 x 200, top left)
	portrait = { name = "portrait", portrait = true, panel_w = 1500, panel_h = 1650, potion = 220, potion_gap = 40, tag_h = 48,
		button = 160, spacing = 14, title_gap = 14, section_gap = 34, details_gap = 40, details_below = true, details_h = 440,
		margin_x = 110, top = 290, bottom = 100,
		title = math.floor(FONTSIZE.SCREEN_SUBTITLE * 0.85) },
}
local PORTRAIT_GAP = 360 -- between the two players' panels

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

local function WithGlyph(control_name, text)
	local control = rawget(Controls.Digital, control_name)
	if control == nil or control.key == nil then
		return text
	end
	return string.format("<p bind='%s' color=0> %s", control.key, text)
end

local function TonicName(def)
	if def == nil then
		return STR.NONE
	end
	local pretty = def.pretty
	return type(pretty) == "table" and type(pretty.name) == "string" and pretty.name ~= "" and pretty.name or def.name
end

local function TonicDesc(player, def)
	if def == nil then
		return ""
	end
	local pm = player.components ~= nil and player.components.powermanager or nil
	local usage = def.usage_data
	local pdef = usage ~= nil and usage.power ~= nil and Power.FindPowerByName(usage.power) or nil
	if pm == nil or pdef == nil or Power.GetDescForPower == nil then
		return ""
	end
	local ok, desc = pcall(function()
		return Power.GetDescForPower(pm:CreatePower(pdef), player)
	end)
	return ok and type(desc) == "string" and desc or ""
end

----------------------------------------------------------------------------
-- A potion: its big icon, no slot. Yours sits in a soft light, "Equipped"
-- under it (outside its box, so the cursor's brackets hug the icon).

local PotionButton = Class(Clickable, function(self, player, size, def)
	Clickable._ctor(self, "PotionButton")
	self:SetOwningPlayer(player)
	self.size = size
	self.def = def
	self.kind = "potion"
	self.glow = self:AddChild(Image(GLOW))
		:SetName("Glow")
		:SetSize(size * 1.55, size * 1.55)
		:SetMultColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetMultColorAlpha(0.9)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.icon = self:AddChild(Image(def.icon))
		:SetName("Icon")
		:SetSize(size, size)
	self.tag_text = self:AddChild(Text(FONTFACE.DEFAULT, math.floor(size * 0.17)))
		:SetName("Tag text")
		:SetGlyphColor(UICOLORS.RED)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:SetText(STR.EQUIPPED)
		:Hide()
end)

function PotionButton:SetEquipped(equipped)
	self.equipped = equipped == true
	self.glow:SetShown(self.equipped)
	self.tag_text:SetShown(self.equipped)
	if self.equipped then
		self.tag_text:LayoutBounds("center", "below", self.icon):Offset(0, -8)
	end
	return self
end

----------------------------------------------------------------------------
-- A tonic: a square tile with the tonic's icon

local TonicButton = Class(Clickable, function(self, player, size)
	Clickable._ctor(self, "TonicButton")
	self:SetOwningPlayer(player)
	self.size = size
	self.kind = "tonic"
	self.background = self:AddChild(Image("images/ui_ftf_shop/inventory_slot_rare.tex"))
		:SetName("Background")
		:SetSize(size, size)
	self.icon = self:AddChild(Image("images/ui_ftf_shop/inventory_slot_rare.tex"))
		:SetName("Icon")
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.selected_overlay = self:AddChild(Image("images/ui_ftf_character/ItemBgSelection.tex"))
		:SetName("Selected overlay")
		:SetSize(size + 10, size + 10)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.tag_text = self:AddChild(Text(FONTFACE.DEFAULT, math.floor(size * 0.2)))
		:SetName("Tag text")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:Hide()
	self.equipped_text = self:AddChild(Text(FONTFACE.DEFAULT, math.floor(size * 0.17)))
		:SetName("Equipped text")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:SetText(STR.EQUIPPED)
		:Hide()
end)

function TonicButton:SetTonic(def)
	self.def = def
	if def ~= nil and def.icon ~= nil then
		self.icon:SetTexture(def.icon)
		self.icon:SetSize(self.size * 0.82, self.size * 0.82)
		self.icon:Show()
	else
		self.icon:Hide()
	end
	return self
end

-- lit = in colour (in the cycle); unlit = greyed out
function TonicButton:SetLit(lit)
	self.lit = lit
	self.icon:SetSaturation(lit and 1 or 0)
	self.icon:SetMultColorAlpha(lit and 1 or 0.35)
	self.background:SetMultColorAlpha(lit and 1 or 0.5)
	return self
end

-- the main tonic: the green frame and "Main" on top
function TonicButton:SetMain(main)
	self.selected_overlay:SetShown(main == true)
	if main then
		self.tag_text:SetText(STR.MAIN_TAG):Show()
		self.tag_text:LayoutBounds("center", "top", self.background):Offset(0, -6)
	else
		self.tag_text:Hide()
	end
	return self
end

-- the tonic you have on right now: "Equipped" at the bottom
function TonicButton:SetEquipped(equipped)
	self.equipped_text:SetShown(equipped == true)
	if equipped then
		self.equipped_text:LayoutBounds("center", "bottom", self.background):Offset(0, 6)
	end
	return self
end

----------------------------------------------------------------------------
-- One player's panel

local TonicPanel = Class(SinglePanel, function(self, player)
	SinglePanel._ctor(self, player)
	self:SetName("TonicPanel")
	self.game_bg = self.bg
	self.game_bg_w, self.game_bg_h = Size(self.bg, PANEL_W, PANEL_H)
	self.mode = MODES.wide
	self.layout_mode = "wide"

	self.content = self:AddChild(Widget()):SetName("Content")

	-- left: the potions on top, the tonics under them
	self.left = self.content:AddChild(Widget()):SetName("Left")
	self.potion_title = self.left:AddChild(Text(FONTFACE.DEFAULT, TITLE_SIZE))
		:SetName("Potion title")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetText(STR.POTION)
	self.potion_row = self.left:AddChild(Widget()):SetName("Potion row")
	self.tonic_title = self.left:AddChild(Text(FONTFACE.DEFAULT, TITLE_SIZE))
		:SetName("Tonics title")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetText(STR.TONICS)
	self.tonic_grid = self.left:AddChild(Widget()):SetName("Tonic grid")

	-- right: what's under the cursor; the buttons and the cycle line at its bottom
	self.details_root = self.content:AddChild(Widget()):SetName("Details root")
	self.details_bg = self.details_root:AddChild(Panel("images/ui_ftf/flat_cornered_panel.tex"))
		:SetName("Details bg")
		:SetNineSliceCoords(44, 40, 208, 200)
		:SetSize(DETAILS_MIN_W, 400)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetMultColorAlpha(0.2)
	self.details = self.details_root:AddChild(Widget()):SetName("Details")
	self.tonic_name = self.details:AddChild(Text(FONTFACE.DEFAULT, DetailSize("name")))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(DETAILS_MIN_W - 60)
	self.tonic_desc = self.details:AddChild(Text(FONTFACE.DEFAULT, DetailSize("desc")))
		:SetGlyphColor(HexToRGB(0x665950ff))
		:LeftAlign()
		:SetAutoSize(DETAILS_MIN_W - 60)
	self.hints = self.details_root:AddChild(Text(FONTFACE.DEFAULT, DetailSize("hints")))
		:SetName("Hints")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(DETAILS_MIN_W - 60)
	self.status = self.details_root:AddChild(Text(FONTFACE.DEFAULT, DetailSize("status")))
		:SetName("Cycle status")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(DETAILS_MIN_W - 60)

	self:BuildGrids()

	self.inst:ListenForEvent("tonicswap_changed", function() self:Refresh() end, player)
end)

function TonicPanel:GridWidth(columns)
	local m = self.mode
	return columns * m.button + (columns - 1) * m.spacing
end

function TonicPanel:BuildGrids()
	local player = self:GetOwningPlayer()
	local m = self.mode
	self.potion_row:RemoveAllChildren()
	self.tonic_grid:RemoveAllChildren()
	self.potion_buttons, self.tonic_buttons = {}, {}

	-- the potions (none when they're off in the settings)
	local potions = TSPotions.enabled and TSPotions.GetPotions() or {}
	for _, def in ipairs(potions) do
		local b = self.potion_row:AddChild(PotionButton(player, m.potion, def))
		b:SetOnClickFn(function() self:OnPotionClicked(def) end)
		b:SetOnGainFocus(function() self:ShowDetails(def, "potion") end)
		self.potion_buttons[#self.potion_buttons + 1] = b
	end
	self.potion_row:LayoutChildrenInRow(m.potion_gap)
	self.potion_title:SetShown(#potions > 0)
	self.potion_row:SetShown(#potions > 0)

	-- 3 per row (3 x 3 for the game's 9 tonics); wider rows if there are more
	local tonics = Main.GetTonics()
	local columns = GRID_COLUMNS
	while columns < GRID_MAX_COLUMNS and math.ceil(#tonics / columns) > GRID_ROWS do
		columns = columns + 1
	end
	self.grid_columns = columns
	for _, def in ipairs(tonics) do
		local b = self.tonic_grid:AddChild(TonicButton(player, m.button)):SetTonic(def)
		b:SetOnClickFn(function() self:OnTonicClicked(def) end) -- A
		b:SetOnClickAltFn(function() self:OnMakeMain(def) end) -- X (right click)
		b:SetOnGainFocus(function() self:ShowDetails(def, "tonic") end)
		self.tonic_buttons[#self.tonic_buttons + 1] = b
	end
	self.tonic_grid:LayoutChildrenInGrid(columns, m.spacing)
end

-- the portrait layout's background: the game's panel art as a nine-slice, so
-- its borders keep their thickness at the new size (nil if that fails; then
-- the art is just stretched)
function TonicPanel:_PortraitBg()
	if self.portrait_bg == nil then
		local ok, bg = pcall(function()
			return self:AddChild(Panel("images/bg_singlepanel_odd/singlepanel_odd.tex"))
				:SetName("Portrait background")
				:SetNineSliceCoords(80, 150, 1739, 779)
				:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_LIGHT)
		end)
		if ok and bg ~= nil then
			bg:MoveToBack()
			bg:Hide()
			-- the game makes its popup darkening (the "Ready!" popup when one
			-- player closes) from the panel background's texture
			bg.GetTexturePath = function() return "images/bg_singlepanel_odd/singlepanel_odd.tex" end
			self.portrait_bg = bg
		else
			self.portrait_bg = false
		end
	end
	return self.portrait_bg or nil
end

-- the button the cursor is on in this panel, or nil
function TonicPanel:_Focused()
	local player = self:GetOwningPlayer()
	local hunter = player ~= nil and player.GetHunterId ~= nil and player:GetHunterId() or nil
	if hunter == nil or TheFrontEnd == nil or TheFrontEnd.GetFocusWidget == nil then
		return nil, hunter
	end
	local ok, focus = pcall(TheFrontEnd.GetFocusWidget, TheFrontEnd, hunter)
	return ok and focus or nil, hunter
end

-- mode: "wide" (1, 3 or 4 players) or "portrait" (2 players), see MODES
function TonicPanel:SetLayoutMode(mode)
	local m = MODES[mode]
	if m == nil or self.layout_mode == mode then
		return self
	end
	self.layout_mode = mode
	self.mode = m
	if m.portrait then
		local bg = self:_PortraitBg()
		if bg ~= nil then
			self.game_bg:Hide()
			bg:SetSize(m.panel_w, m.panel_h):Show()
			self.bg = bg
		else
			self.game_bg:SetSize(m.panel_w, m.panel_h)
		end
	else
		if self.portrait_bg then
			self.portrait_bg:Hide()
		end
		self.game_bg:SetSize(self.game_bg_w, self.game_bg_h):Show()
		self.bg = self.game_bg
	end
	self.potion_title:SetFontSize(m.title)
	self.tonic_title:SetFontSize(m.title)
	self:_FitPopupBg()

	-- new sizes: rebuild, keep the cursor where it was
	local focus, hunter = self:_Focused()
	local where, def
	for _, b in ipairs(self.potion_buttons or {}) do
		if b == focus then where, def = "potion", b.def end
	end
	for _, b in ipairs(self.tonic_buttons or {}) do
		if b == focus then where, def = "tonic", b.def end
	end
	self:BuildGrids()
	if self.opened then
		self:Refresh()
		local list = where == "potion" and self.potion_buttons or where == "tonic" and self.tonic_buttons or nil
		for _, b in ipairs(list or {}) do
			if b.def == def then
				b:SetFocus(hunter)
				break
			end
		end
	else
		self:Layout()
	end
	return self
end

-- opens on your potion (or, without potions, your main tonic / the first one)
function TonicPanel:FindDefaultFocus()
	local player = self:GetOwningPlayer()
	local potion = TSPotions.GetEquippedDef(player)
	for _, b in ipairs(self.potion_buttons or {}) do
		if b.def == potion then
			return b
		end
	end
	local main = Main.GetMainDef(player)
	for _, b in ipairs(self.tonic_buttons or {}) do
		if b.def == main then
			return b
		end
	end
	return self.potion_buttons[1] or self.tonic_buttons[1]
end

-- The game's popup darkening is the panel art at its own size; cover the
-- panel at the size this layout gives it.
function TonicPanel:_FitPopupBg()
	if self.popup_bg ~= nil and self.bg ~= nil then
		local w, h = Size(self.bg, 0, 0)
		if w > 0 and h > 0 then
			self.popup_bg:SetSize(w, h):LayoutBounds("center", "center", self.bg)
		end
	end
end

function TonicPanel:OnPopupsChanged(...)
	self:_FitPopupBg()
	return TonicPanel._base.OnPopupsChanged(self, ...)
end

function TonicPanel:OnOpenPanel()
	self.opened = true
	self:Refresh()
	local b = self:FindDefaultFocus()
	if b ~= nil then
		self:ShowDetails(b.def, b.kind)
		b:SetFocus(self:GetOwningPlayer():GetHunterId())
	end
	TonicPanel._base.OnOpenPanel(self)
end

function TonicPanel:Refresh()
	local player = self:GetOwningPlayer()
	local main = Main.GetMainDef(player)
	local current = Main.CurrentDef(player)
	local potion = TSPotions.GetEquippedDef(player)
	for _, b in ipairs(self.potion_buttons or {}) do
		b:SetEquipped(potion ~= nil and b.def == potion)
	end
	for _, b in ipairs(self.tonic_buttons or {}) do
		b:SetLit(Main.IsIncluded(player, b.def) and Main.SittingOutFor(player, b.def) == nil)
		b:SetMain(main ~= nil and b.def == main)
		b:SetEquipped(current ~= nil and b.def == current)
	end
	-- the cycle line
	local cycle = Main.GetCycle(player)
	if #cycle <= 1 then
		self.status:SetText(main ~= nil and string.format(STR.CYCLE_OFF, TonicName(main)) or STR.CYCLE_NOTHING)
	else
		self.status:SetText(string.format(STR.CYCLE_IS, #cycle, TonicName(cycle[1] or nil)))
	end
	if self.shown_where ~= nil then
		self:ShowDetails(self.shown_def, self.shown_where)
	end
	self:Layout()
end

-- where: "potion" or "tonic"
function TonicPanel:ShowDetails(def, where)
	local player = self:GetOwningPlayer()
	self.shown_def, self.shown_where = def, where
	self.tonic_name:SetText(TonicName(def))
	local desc = TonicDesc(player, def)
	local note
	if where == "potion" and def ~= nil then
		note = self:_PotionNote(def)
	elseif where == "tonic" and def ~= nil then
		local power = Main.IsIncluded(player, def) and Main.SittingOutFor(player, def) or nil
		note = power ~= nil and string.format(STR.SITTING_OUT, Main.PowerTitle(power))
			or def == Main.GetMainDef(player) and STR.IS_MAIN
			or Main.IsIncluded(player, def) and STR.IN_CYCLE or STR.OUT_OF_CYCLE
	end
	if note ~= nil then
		desc = desc .. (desc ~= "" and "\n" or "") .. note
	end
	self.tonic_desc:SetText(desc)
	self.hints:SetText(self:_Hints(def, where))
	self:LayoutDetails()
end

-- the buttons for what the cursor's on (the game draws the button glyphs)
function TonicPanel:_Hints(def, where)
	local player = self:GetOwningPlayer()
	local lines = {}
	if where == "potion" and def ~= nil then
		if TSPotions.InTown() and def ~= TSPotions.GetEquippedDef(player) then
			lines[#lines + 1] = WithGlyph("ACCEPT", STR.HINT_TAKE)
		end
	elseif where == "tonic" and def ~= nil then
		lines[#lines + 1] = WithGlyph("ACCEPT", Main.IsIncluded(player, def) and STR.HINT_OUT or STR.HINT_IN)
		if def ~= Main.GetMainDef(player) then
			lines[#lines + 1] = WithGlyph("MENU_ALT_ACCEPT", STR.HINT_MAIN)
		end
	end
	lines[#lines + 1] = WithGlyph("MENU_UNCOMMON", Main.HasOthers(player) and STR.HINT_DISABLE or STR.HINT_ALL)
	return table.concat(lines, "\n")
end

-- a potion's charges (with your talents) and whether it's yours
function TonicPanel:_PotionNote(def)
	local player = self:GetOwningPlayer()
	local lines = {}
	local drinker = player.components ~= nil and player.components.potiondrinker or nil
	local ok, charges = false, nil
	if drinker ~= nil and drinker.GetMaxUses ~= nil then
		ok, charges = pcall(drinker.GetMaxUses, drinker)
	end
	if ok and type(charges) == "number" then
		local sips = TSPotions.SipsFor(def)
		lines[#lines + 1] = sips > 1 and string.format(STR.POTION_SIPS, charges, sips)
			or string.format(STR.POTION_CHARGES, charges)
	end
	local yours = TSPotions.GetEquippedDef(player)
	if yours ~= nil and yours == def then
		lines[#lines + 1] = STR.POTION_YOURS
	elseif not TSPotions.InTown() then
		lines[#lines + 1] = STR.POTION_TOWN
	end
	return table.concat(lines, "\n")
end

function TonicPanel:OnPotionClicked(def)
	TSPotions.Pick(self:GetOwningPlayer(), def)
	self:Refresh()
end

-- A on a tonic: in / out of the cycle
function TonicPanel:OnTonicClicked(def)
	local player = self:GetOwningPlayer()
	Main.SetIncluded(player, def.name, not Main.IsIncluded(player, def))
	self:Refresh()
end

-- X on a tonic: your main tonic
function TonicPanel:OnMakeMain(def)
	Main.SetMain(self:GetOwningPlayer(), def.name)
	self:Refresh()
end

-- Y: cycling off (only the main tonic) / every tonic in
function TonicPanel:OnCyclingClicked()
	Main.ToggleCycling(self:GetOwningPlayer())
	self:Refresh()
end

TonicPanel.CONTROL_MAP = {
	{
		control = Controls.Digital.MENU_UNCOMMON, -- Y
		fn = function(self)
			self:OnCyclingClicked()
			return true
		end,
	},
}

-- The details box keeps its size with the buttons and the cycle line at its
-- bottom; a long description shrinks instead, so the menu doesn't jump around
-- when the cursor moves.
function TonicPanel:LayoutDetails()
	local bw, bh = Size(self.details_bg, DETAILS_MIN_W, 400)
	self.details:SetScale(1)
	self.hints:SetScale(1)
	self.status:SetScale(1)
	self.tonic_desc:LayoutBounds("left", "below", self.tonic_name):Offset(0, -4)
	local _, status_h = Size(self.status, 0, 0)
	local _, hints_h = Size(self.hints, 0, 0)
	local tw, th = Size(self.details, 0, 0)
	local gap = hints_h > 0 and 20 or 0
	local bottom_h = status_h + hints_h + gap
	-- the box's height less its padding (24 top, 24 bottom) and 30 between the
	-- description and the buttons
	local free_h = bh - 24 - 24 - 30
	-- too tall: the name + description shrink first (to 0.6), then the
	-- buttons and the cycle line shrink with them
	local fit, fit_b = 1, 1
	if th > 0 and th + bottom_h > free_h then
		fit = math.max(0.6, (free_h - bottom_h) / th)
		if th * fit + bottom_h > free_h then
			local k = math.max(0.1, free_h / (th * fit + bottom_h))
			fit, fit_b = fit * k, k
		end
	end
	if tw > 0 then
		fit = math.min(fit, (bw - 50) / tw)
	end
	self.hints:SetScale(fit_b)
	self.status:SetScale(fit_b)
	self.status:LayoutBounds("left", "bottom", self.details_bg):Offset(30, 24)
	self.hints:LayoutBounds("left", "above", self.status):Offset(0, gap * fit_b)
	self.details:SetScale(fit)
	self.details:LayoutBounds("left", "top", self.details_bg):Offset(30, -24)
	return self
end

function TonicPanel:Layout()
	TonicPanel._base.Layout(self)
	local m = self.mode
	local panel_w, panel_h = Size(self.bg, m.panel_w or PANEL_W, m.panel_h or PANEL_H)
	local inner_w = panel_w - 2 * m.margin_x
	local inner_h = panel_h - m.top - m.bottom
	self.content:SetScale(1)

	-- left: Potion, the potions in a row (room under them for "Equipped"),
	-- Tonics, the grid centred under the potions
	local has_potions = self.potion_row:IsShown()
	local top_title = has_potions and self.potion_title or self.tonic_title
	local _, title_h = Size(top_title, 0, 0)
	if has_potions then
		self.potion_row:LayoutBounds("left", "below", self.potion_title):Offset(0, -m.title_gap)
		self.tonic_title:LayoutBounds("left", "below", self.potion_row):Offset(0, -(m.tag_h + m.section_gap))
	end
	self.tonic_grid:LayoutBounds("left", "below", self.tonic_title):Offset(0, -m.title_gap)
	local row_w = has_potions and Size(self.potion_row, 0, 0) or 0
	local grid_w = self:GridWidth(self.grid_columns or GRID_COLUMNS)
	if row_w > grid_w then
		self.tonic_grid:Offset((row_w - grid_w) / 2, 0)
		self.tonic_title:LayoutBounds("left", nil, self.tonic_grid)
	end

	-- the details box. Wide: on the right, from the top of the potions (or the
	-- grid) down to the grid's bottom, the rest of the width. Portrait: under
	-- them, the panel's whole width. (When it all scales down to fit, the box
	-- grows so it still reaches the panel's side.)
	local left_w, left_h = Size(self.left, grid_w, 500)
	local details_w, details_h
	if m.details_below then
		details_h = m.details_h
		local fit_h = math.min(1, inner_h / math.max(1, left_h + m.details_gap + details_h))
		details_w = math.max(DETAILS_MIN_W, left_w, inner_w / fit_h)
	else
		local fit_h = math.min(1, inner_h / math.max(1, left_h))
		details_w = math.max(DETAILS_MIN_W, inner_w / fit_h - left_w - m.details_gap)
		details_h = math.max(300, left_h - title_h - m.title_gap)
	end
	self.tonic_name:SetAutoSize(details_w - 60)
	self.tonic_desc:SetAutoSize(details_w - 60)
	self.hints:SetAutoSize(details_w - 60)
	self.status:SetAutoSize(details_w - 60)
	self.details_bg:SetSize(details_w, details_h)
	if m.details_below then
		self.details_bg:LayoutBounds("center", "below", self.left):Offset(0, -m.details_gap)
	else
		self.details_bg:LayoutBounds("after", nil, self.left):Offset(m.details_gap, 0)
			:LayoutBounds(nil, "top", has_potions and self.potion_row or self.tonic_grid)
	end
	self:LayoutDetails()

	-- fit it in the panel
	local content_w, content_h = Size(self.content, inner_w, inner_h)
	local fit = math.min(1, inner_w / content_w, inner_h / content_h)
	self.content_scale = fit
	self.content:SetScale(fit)
	if self.bg ~= nil then
		if m.details_below then
			self.content:LayoutBounds("center", "top", self.bg):Offset(0, -m.top)
		else
			self.content:LayoutBounds("left", "top", self.bg):Offset(m.margin_x, -m.top)
		end
	end
	return self
end

----------------------------------------------------------------------------
-- The screen: one panel per local player

local TonicScreen = Class(MultiPanelScreen, function(self, initiating_player)
	MultiPanelScreen._ctor(self, initiating_player, "TonicSwapScreen")
	self:SetTitle(STR.TITLE, STR.DESC)
	self:_CreatePanelsForLocalPlayers(TonicPanel)
end)

-- 2 players: the portrait layout, the two panels side by side; otherwise the
-- wide layout where the game puts the panels
function TonicScreen:LayoutPanels()
	local panels = self.panels ~= nil and self.panels:GetChildren() or {}
	local portrait = #panels == 2
	for _, panel in ipairs(panels) do
		if panel.SetLayoutMode ~= nil then
			panel:SetLayoutMode(portrait and "portrait" or "wide")
		end
	end
	TonicScreen._base.LayoutPanels(self)
	if portrait then
		panels[2]:LayoutBounds("after", "top", panels[1]):Offset(PORTRAIT_GAP, 0)
		self.panels:LayoutBounds("center", "center", self):Offset(0, -90)
	end
	return self
end

function TonicScreen:OnOpen()
	TonicScreen._base.OnOpen(self)
	if self.EnableFocusBracketsForGamepadAndMouse ~= nil then
		self:EnableFocusBracketsForGamepadAndMouse()
	end
end

TonicScreen.Panel = TonicPanel
TonicScreen.TonicButton = TonicButton
TonicScreen.PotionButton = PotionButton
TonicScreen.STR = STR

return TonicScreen
