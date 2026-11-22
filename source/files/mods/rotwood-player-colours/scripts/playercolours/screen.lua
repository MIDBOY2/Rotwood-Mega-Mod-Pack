-- Player Colours: the PLAYER COLOUR tab of the character screen (the mirror in
-- town), after ARMOUR DYE. On top, a live preview made of the HUD's own pieces
-- (the real portrait widget with your character, your name, weapon badge,
-- health bar, a menu selection bracket), tinted the way the HUD tints them;
-- it follows the colour you point at. Below, the game's own colour buttons
-- (SelectableItemColor, as in the HEAD / BODY colour rows), Vanilla first.
-- The pick is saved with the character on Save Changes, like the rest of the
-- screen, and the HUD recolours right then; Revert All undoes it.

local Main = require "playercolours.main"

local Screen = {}

Screen.TAB = "TAB_PLAYERCOLOUR"
Screen.LABEL = "<p img='images/icons_ftf/add_player.tex' color=0 scale=0.9> PLAYER COLOUR"
local PER_ROW = 12 -- 0.2.7: Vanilla + 23 colours = two rows of 12 (Orchid moved up to the first row)
local SPACING = { h = 30, v = 60 } -- 0.2.7: 30 (was 40) so 12 fit the list's width (1750) with "Vermilion" under its button
local BUTTON_SCALE = 1.4
Screen.PER_ROW, Screen.SPACING = PER_ROW, SPACING
local NAME_SIZE = 56
local BAR = "images/ui_ftf_segmented_healthbar/bar_fill.tex"

-- A local of a game function, looked up through wrappers other mods put
-- around it (a few levels deep).
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

local function SetTab(top_tabs, shown)
	for i = #top_tabs, 1, -1 do
		if top_tabs[i] == Screen.TAB then
			table.remove(top_tabs, i)
		end
	end
	if shown then
		table.insert(top_tabs, Screen.TAB) -- last: after ARMOUR DYE
	end
end
Screen.SetTab = SetTab

-- Vanilla (nil) first, then the list.
function Screen.Entries(owner)
	local idx = Main.HunterId(owner) or 1
	local v = Main.vanilla[idx] or Main.vanilla[1]
	local entries = { { key = nil, name = "Vanilla", rgb = v and v.normal or { 1, 1, 1, 1 },
		tip = "Vanilla: the game's colour for your player number (P" .. idx .. ")" } }
	for _, c in ipairs(Main.list) do
		table.insert(entries, { key = c.key, name = c.name, rgb = c.rgb, tip = c.name })
	end
	return entries
end

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

local function NameOf(key)
	local c = key ~= nil and Main.by_key[key] or nil
	return c ~= nil and c.name or "Vanilla"
end

-- The colour a key shows as (nil = the game's colour for this player number).
function Screen.ColourOf(screen, key)
	local c = key ~= nil and Main.by_key[key] or nil
	if c ~= nil then
		return c.rgb
	end
	local idx = Main.HunterId(screen.owner) or 1
	local v = Main.vanilla[idx] or Main.vanilla[1]
	return v ~= nil and v.normal or { 1, 1, 1, 1 }
end

local function Try(fn)
	local ok, res = pcall(fn)
	if ok then
		return res
	end
	return nil
end

-- The preview on top: the HUD's own pieces, tinted like the HUD tints them.
function Screen.BuildPreview(screen, parent, W)
	local root = parent:AddChild(W.Widget("Player colour preview"))
	local p = {}
	root.playercolours_preview = p
	local okP, PlayerPortrait = pcall(require, "widgets.ftf.playerportrait")
	if okP and type(PlayerPortrait) == "table" then
		p.portrait = Try(function()
			local w = root:AddChild(PlayerPortrait()):SetScale(0.7)
			w.puppet:CloneCharacterWithEquipment(screen.owner, true)
			return w
		end)
	end
	p.info = root:AddChild(W.Widget("info"))
	local okW, PlayerWeaponWidget = pcall(require, "widgets.ftf.playerweaponwidget")
	if okW and type(PlayerWeaponWidget) == "table" then
		p.weapon = Try(function()
			local w = p.info:AddChild(PlayerWeaponWidget(screen.owner))
			-- sized to the name like the HUD does (PlayerUsernameWidget:SetFontSize), so the
			-- coloured tag shows behind the black weapon icon
			w:SetSize(NAME_SIZE)
			return w
		end)
	end
	local name = Try(function() return screen.owner:GetCustomUserName() end) or "Hunter"
	p.name = p.info:AddChild(W.Text(FONTFACE.DEFAULT, NAME_SIZE, name, UICOLORS.LIGHT_TEXT_TITLE))
	Try(function() -- the HUD's name style: black outline and shadow
		p.name:EnableShadow():SetShadowColor(UICOLORS.BLACK):SetShadowOffset(1, -1):EnableOutline():SetOutlineColor(UICOLORS.BLACK)
	end)
	p.bar_bg = p.info:AddChild(W.Panel(BAR)):SetNineSliceCoords(10, 2, 81, 28):SetSize(460, 36):SetMultColor(0.2, 0.2, 0.2)
	p.bar = p.info:AddChild(W.Panel(BAR)):SetNineSliceCoords(10, 2, 81, 28):SetSize(330, 36)
	p.bar_border = p.info:AddChild(W.Panel("images/ui_ftf_segmented_healthbar/9_slice_border.tex"))
		:SetMultColor(0, 0, 0, 1):SetNineSliceCoords(35, 4, 110, 34):SetSize(480, 52)
		:SendToBack() -- behind the bar, like the HUD's health bar (SegmentedHealthBar)
	p.brackets = root:AddChild(W.Panel("images/ui_ftf/selection_brackets_fill.tex"))
		:SetNineSliceCoords(78, 94, 80, 96):SetNineSliceBorderScale(0.8):SetSize(280, 160)
	p.brackets_top = root:AddChild(W.Panel("images/ui_ftf/selection_brackets_overlay.tex"))
		:SetNineSliceCoords(78, 94, 80, 96):SetNineSliceBorderScale(0.8):SetSize(280, 160)
	p.label = root:AddChild(W.Text(FONTFACE.DEFAULT, 48, "", UICOLORS.LIGHT_TEXT_TITLE))

	-- layout: portrait | badge + name over the health bar | a menu bracket with the colour's name
	if p.weapon ~= nil then
		p.name:LayoutBounds("after", "center", p.weapon):Offset(16, 0)
		p.bar_bg:LayoutBounds("left", "below", p.weapon):Offset(0, -20)
	else
		p.bar_bg:LayoutBounds("left", "below", p.name):Offset(0, -20)
	end
	p.bar:LayoutBounds("left", "center", p.bar_bg)
	p.bar_border:LayoutBounds("center", "center", p.bar_bg)
	if p.portrait ~= nil then
		p.info:LayoutBounds("after", "center", p.portrait):Offset(40, 0)
	end
	p.brackets:LayoutBounds("after", "center", p.info):Offset(70, 0)
	p.brackets_top:LayoutBounds("center", "center", p.brackets)
	p.label:LayoutBounds("center", "center", p.brackets)
	return root
end

function Screen.ShowInPreview(screen, key)
	local p = screen.playercolours_preview
	if p == nil then
		return
	end
	local colour = Screen.ColourOf(screen, key)
	if p.portrait ~= nil and p.portrait.bg ~= nil then
		p.portrait.bg:SetMultColor(colour)
	end
	if p.weapon ~= nil and p.weapon.bg ~= nil then
		p.weapon.bg:SetMultColor(colour)
	end
	p.name:SetGlyphColor(colour)
	p.bar:SetMultColor(colour)
	p.brackets:SetMultColor(colour)
	local c = key ~= nil and Main.by_key[key] or nil
	p.label:SetText(c ~= nil and c.name or "Vanilla")
end

function Screen.Describe(screen)
	local d = screen.customize_character_description
	if d == nil or not screen.playercolours_tab then
		return
	end
	d:SetText(NameOf(screen.playercolours_pick) .. ": your HUD, health bar, name, selection brackets and the ring under your feet")
		:Show()
		:LayoutBounds("center", "below", screen.list_bg)
		:Offset(0, -50)
end

function Screen.Buttons(screen)
	local grid = screen.playercolours_grid
	return grid ~= nil and grid.children or {}
end

function Screen.Select(screen, key)
	screen.playercolours_pick = key
	for _, btn in ipairs(Screen.Buttons(screen)) do
		if btn.playercolours_entry ~= nil then
			btn:SetSelected(btn.playercolours_entry.key == key)
		end
	end
	Screen.ShowInPreview(screen, key)
	Screen.Describe(screen)
	screen:CheckForChanges()
end

function Screen.BuildList(screen, SelectableItemColor, W)
	local Text = W.Text
	screen.scroll_contents:RemoveAllChildren()
	local preview = Screen.BuildPreview(screen, screen.scroll_contents, W)
	screen.playercolours_preview = preview.playercolours_preview
	local grid = screen.scroll_contents:AddChild(W.Widget("Player colour buttons"))
	screen.playercolours_grid = grid
	for _, e in ipairs(Screen.Entries(screen.owner)) do
		local btn = grid:AddChild(SelectableItemColor())
			:SetImageColor(e.rgb)
			:SetItemColorId(e.key or "vanilla")
			:SetLocked(false)
			:SetUnseen(false)
			:SetSelected(e.key == screen.playercolours_pick)
			-- the button's own normal / hover / pressed sizes (Clickable:SetScales): the game
			-- puts a button back to these on every hover and focus change
			:SetScales(BUTTON_SCALE, BUTTON_SCALE, BUTTON_SCALE)
			:SetScale(BUTTON_SCALE)
		btn.playercolours_entry = e
		if Text ~= nil then
			btn.playercolours_label = btn:AddChild(Text(FONTFACE.DEFAULT, 22, e.name, UICOLORS.LIGHT_TEXT_DARK))
				:LayoutBounds("center", "below", btn.image)
				:Offset(0, -26) -- under the game's selection underline
		end
		btn:SetToolTipFn(function() return e.tip end)
			:ShowToolTipOnFocus(true)
		btn:SetOnClick(function() Screen.Select(screen, e.key) end)
		-- pointing at a colour shows it in the preview; leaving goes back to the pick
		btn:SetOnGainFocus(function()
			btn:OnFocusChange(true)
			Screen.ShowInPreview(screen, e.key)
		end)
			:SetOnLoseFocus(function()
				btn:OnFocusChange(false)
				Screen.ShowInPreview(screen, screen.playercolours_pick)
			end)
	end
	grid:LayoutChildrenInGrid(Screen.PER_ROW, Screen.SPACING)
	grid:LayoutBounds("center", "below", preview):Offset(0, -60)
	Screen.ShowInPreview(screen, screen.playercolours_pick)
	screen.scroll_contents:LayoutBounds("center", "top", 0, -40)
	if screen.scroll ~= nil then
		screen.scroll:RefreshView()
	end
end

-- LT / RT (the sub-tab buttons) on a tab without sub-tabs (PRESETS, PLAYER
-- COLOUR): the game's TabGroup:NextTab looked for the open sub-tab, found none
-- and stopped the game ("attempt to perform arithmetic on a nil value (local
-- 'idx')"). Now: no sub-tabs = nothing happens; sub-tabs but none open = the
-- first (RT) / last (LT) opens. Every other press is the game's own. FURY and
-- Player Colours both put this in (once, whichever loads first), so either one
-- alone covers both tabs.
function Screen.GuardSubTabButtons()
	local ok, TabGroup = pcall(require, "widgets.tabgroup")
	if not ok or type(TabGroup) ~= "table" or type(TabGroup.NextTab) ~= "function" or type(TabGroup.GetCurrentIdx) ~= "function" then
		return false, "a game update changed widgets/tabgroup.lua"
	end
	if rawget(TabGroup, "personal_mods_safe_next_tab") then
		return true
	end
	local orig = TabGroup.NextTab
	TabGroup.NextTab = function(self, delta, ...)
		local tabs = type(self) == "table" and rawget(self, "tabs") or nil
		if type(tabs) == "table" and self:GetCurrentIdx() == nil then
			if #tabs == 0 then
				return
			end
			local tab = tabs[(tonumber(delta) or 1) < 0 and #tabs or 1]
			if tab ~= nil and type(tab.Click) == "function" then
				tab:Click()
			end
			return
		end
		return orig(self, delta, ...)
	end
	rawset(TabGroup, "personal_mods_safe_next_tab", true)
	return true
end

function Screen.Install(settings)
	local ok, CharacterScreen = pcall(require, "screens.character.characterscreen")
	if not ok or type(CharacterScreen) ~= "table" then
		return false, "screens.character.characterscreen: " .. tostring(CharacterScreen)
	end
	local ok2, SelectableItemColor = pcall(require, "widgets.ftf.selectableitemcolor")
	if not ok2 or type(SelectableItemColor) ~= "table" then
		return false, "widgets.ftf.selectableitemcolor"
	end
	local W = {}
	for k, mod in pairs({ Text = "widgets.text", Widget = "widgets.widget", Panel = "widgets.panel" }) do
		local okm, m = pcall(require, mod)
		if not okm or m == nil then
			return false, mod
		end
		W[k] = m
	end
	for _, fn in ipairs({ "OnChangeTab", "IsCharacterEqual", "CheckForChanges", "ApplyChanges", "OnContinueClicked",
		"OnRevertClicked", "FocusFirstElement" }) do
		if type(CharacterScreen[fn]) ~= "function" then
			return false, "a game update changed CharacterScreen:" .. fn
		end
	end
	local top_tabs = FindUpvalue(CharacterScreen._ctor, "TOP_TABS", 4)
	if type(top_tabs) ~= "table" then
		return false, "a game update changed the character screen's tab list"
	end
	if STRINGS == nil or STRINGS.CHARACTER_CREATOR == nil then
		return false, "STRINGS.CHARACTER_CREATOR"
	end
	STRINGS.CHARACTER_CREATOR[Screen.TAB] = Screen.LABEL
	local okg, gdone, gwhy = pcall(Screen.GuardSubTabButtons)
	if not okg or not gdone then
		Main.Log("LT / RT guard skipped (LT / RT on PLAYER COLOUR may stop the game): " .. tostring(okg and gwhy or gdone))
	end

	-- The tab only for characters that already exist (picked at the mirror).
	local ctor = CharacterScreen._ctor
	CharacterScreen._ctor = function(self, owner, on_close_cb, new_character_data, ...)
		local has = new_character_data == nil and owner ~= nil and owner.components ~= nil and owner.components.playercolour ~= nil
		SetTab(top_tabs, has)
		if has then
			-- the tab's name again now: the game's language pass replaces the strings
			-- table after the mods load (it showed MISSING:STRINGS...)
			if STRINGS ~= nil and STRINGS.CHARACTER_CREATOR ~= nil then
				STRINGS.CHARACTER_CREATOR[Screen.TAB] = Screen.LABEL
			end
			self.playercolours_orig = owner.components.playercolour:GetKey()
			self.playercolours_pick = self.playercolours_orig
			self.playercolours_on = true
		end
		return ctor(self, owner, on_close_cb, new_character_data, ...)
	end

	local function Leave(screen)
		screen.playercolours_tab = nil
		screen.playercolours_preview = nil
		screen.playercolours_grid = nil
	end
	Screen.Leave = Leave
	RegisterTabLeave(CharacterScreen, Screen.TAB, Leave)

	local orig_OnChangeTab = CharacterScreen.OnChangeTab
	function CharacterScreen:OnChangeTab(tab_button, ...)
		if tab_button == nil or tab_button.top_tab_id ~= Screen.TAB then
			Leave(self)
			return orig_OnChangeTab(self, tab_button, ...)
		end
		LeaveOtherTabs(CharacterScreen, self, Screen.TAB)
		self.playercolours_tab = true
		self.subnav:RemoveAllTabs()
		self.subnav_bg:SetShown(false)
		self.subnav:SetShown(false)
		if self.color_elements_list ~= nil then
			self.color_elements_list:RemoveAllChildren()
		end
		self.can_randomize_species = false
		Screen.BuildList(self, SelectableItemColor, W)
		Screen.Describe(self)
		self:FocusFirstElement()
	end

	local orig_Focus = CharacterScreen.FocusFirstElement
	function CharacterScreen:FocusFirstElement(...)
		if self.playercolours_tab then
			local cur = CurrentTopTab(self)
			if cur ~= nil and cur ~= Screen.TAB then
				-- another tab is open and its mod didn't pass the click on: left
				Leave(self)
			else
				for _, btn in ipairs(Screen.Buttons(self)) do
					if not rawget(btn, "removed") and btn.playercolours_entry ~= nil and btn.playercolours_entry.key == self.playercolours_pick then
						btn:SetFocus()
						return
					end
				end
			end
		end
		return orig_Focus(self, ...)
	end

	local orig_Equal = CharacterScreen.IsCharacterEqual
	function CharacterScreen:IsCharacterEqual(...)
		local same = orig_Equal(self, ...)
		if self.playercolours_on and self.playercolours_pick ~= self.playercolours_orig then
			return false
		end
		return same
	end

	-- Save Changes / apply: the owner gets the pick before the game saves the character.
	local function Commit(self)
		if self.playercolours_on and self.playercolours_pick ~= self.playercolours_orig then
			local c = self.owner and self.owner.components and self.owner.components.playercolour
			if c ~= nil then
				c:SetKey(self.playercolours_pick)
				Main.Log("character colour: " .. NameOf(self.playercolours_pick))
			end
			self.playercolours_orig = self.playercolours_pick
		end
	end
	local orig_Apply = CharacterScreen.ApplyChanges
	function CharacterScreen:ApplyChanges(...)
		Commit(self)
		return orig_Apply(self, ...)
	end
	local orig_Continue = CharacterScreen.OnContinueClicked
	function CharacterScreen:OnContinueClicked(...)
		Commit(self)
		return orig_Continue(self, ...)
	end

	local orig_Revert = CharacterScreen.OnRevertClicked
	function CharacterScreen:OnRevertClicked(...)
		local r = orig_Revert(self, ...)
		if self.playercolours_on and self.playercolours_pick ~= self.playercolours_orig then
			self.playercolours_pick = self.playercolours_orig
			if self.playercolours_tab then
				Screen.Select(self, self.playercolours_pick)
			else
				self:CheckForChanges()
			end
		end
		return r
	end

	return true
end

return Screen
