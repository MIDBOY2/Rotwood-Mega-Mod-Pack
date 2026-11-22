-- Character Builds: the BUILDS tab of the character screen (the mirror in town), last of the tabs.
--
-- Numbered build slots (the game's own body-part tiles, as in FURY's PRESETS: each shows the whole
-- character in that build's look, wearing its gear and weapon with their dyes, its number and a line
-- about it), then the automatic backups (your character as it was before each load). A on a slot:
-- Save this character here / Load onto this character / Delete; a backup: Load / Delete. Saving uses
-- the character as last saved (Save Changes first for changes made in the mirror). Loading asks what
-- to load (everything, the look, the look keeping your face, the colours, the gear), closes the mirror
-- and puts it on right away (no loading screen). Ctrl + B (the key_open setting) opens this tab
-- anywhere in town.
--
-- The tab is put in the screen's tab list once (no wrapper around the screen's constructor: the other
-- tab mods look for that list through those wrappers). Its name comes back after the game's language
-- pass (GameContent:SetLanguage replaces the strings).
local Main = require "characterbuilds.main"

local Tab = {}

Tab.ID = "TAB_CHARACTER_BUILDS"
Tab.LABEL = "<p img='images/ui_ftf/star_white.tex' color=0 scale=0.9> BUILDS"
Tab.TILE = 300
Tab.PER_ROW = 4
Tab.PER_ROW_CARD = 2 -- with the loadout card on the right (3 overlapped it)
Tab.CARD_W, Tab.CARD_H = 660, 880
Tab.HINT_CARD = "A on a slot: save this character there,\nload all or part of it, or delete it."
Tab.FRAME = { x = 0, y = -122, scale = 0.58 }
Tab.HINT = "A build is the whole character: look, gear, inventory, loadouts, talents, everything.\nA on a slot: save this character there, load all or part of it onto this character, or delete it."
Tab.SEARCH_DEPTH = 24
Tab.W = nil

local function Log(msg)
	Main.Log("tab: " .. msg)
end

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
Tab.FindUpvalue = FindUpvalue

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
local function CurrentTopTab(screen)
	local nav = type(screen.navbar) == "table" and screen.navbar or nil
	local cur = nav ~= nil and rawget(nav, "current") or nil
	local id = type(cur) == "table" and rawget(cur, "top_tab_id") or nil
	return type(id) == "string" and id or nil
end

function Tab.SetLabel()
	if STRINGS ~= nil and STRINGS.CHARACTER_CREATOR ~= nil then
		STRINGS.CHARACTER_CREATOR[Tab.ID] = Tab.LABEL
	end
end

-- The build's look on a tile's puppet (FURY's way when it's there: its custom colours too).
function Tab.ShowLook(puppet, b)
	local look = Main.Look(b)
	if puppet == nil or look == nil then
		return false
	end
	local okf, FogPresets = pcall(require, "tools.fog_presets")
	if okf and type(FogPresets) == "table" and type(FogPresets.ApplyToPuppet) == "function" then
		local ok = pcall(FogPresets.ApplyToPuppet, puppet, look)
		if ok then
			return true
		end
	end
	local creator = puppet.components ~= nil and puppet.components.charactercreator or nil
	if creator == nil then
		return false
	end
	creator:SetSpecies(look.species)
	creator:LoadFromTable({ species = look.species, bodyparts = look.bodyparts, colorgroups = look.colorgroups })
	return true
end

-- The build's gear on a tile's puppet: what it was wearing (armour looks, weapon, hidden helmet...),
-- with its dyes, the way the game dresses its own puppets (PlayerPuppet:CloneCharacterWithEquipment).
function Tab.ShowGear(puppet, b)
	local d = type(b) == "table" and b.data or nil
	local p = type(d) == "table" and d.player or nil
	local inv = type(p) == "table" and p.inventory or nil
	local comps = puppet ~= nil and puppet.components or nil
	if type(inv) ~= "table" or type(inv.equips) ~= "table" or comps == nil or comps.inventory == nil then
		return false
	end
	comps.inventory:OnLoad(Main.deepcopy(inv))
	local dyer = comps.equipmentdyer
	local dyes = type(p.equipmentdyer) == "table" and p.equipmentdyer.dyes or nil
	if dyer ~= nil and dyer.SetEquipmentDye ~= nil and type(dyes) == "table" then
		for slot, sets in pairs(dyes) do
			local set = inv.equips[slot]
			local dye = type(sets) == "table" and set ~= nil and sets[set] or nil
			if dye ~= nil then
				pcall(dyer.SetEquipmentDye, dyer, slot, set, dye)
			end
		end
	end
	return true
end

----------------------------------------------------------------------------
-- The loadout card: the focused build's equipped gear (the loadout it was wearing), the way the game's
-- own loadout widgets show it (ItemWidget: icon, level badge, rarity; DisplayStat), made from the
-- build's saved items turned into the game's item objects (itemforge.ConvertToRuntimeItem, as the game
-- does when it loads a character). It sits on the right of the slots list; the slots go 2 to a row.

-- slot -> saved item table of what the build was wearing (the game's InventoryHoard:GetEquippedGear:
-- a changed, unsaved loadout first, else the selected one), and its gear store
function Tab.EquippedItems(b)
	local p = type(b) == "table" and type(b.data) == "table" and b.data.player or nil
	local hoard = type(p) == "table" and p.inventoryhoard or nil
	if type(hoard) ~= "table" then
		return {}, nil
	end
	local inv = type(hoard.inventory) == "table" and hoard.inventory or {}
	local gear = type(hoard.loadout_override) == "table" and hoard.loadout_override
		or (type(hoard.loadouts) == "table" and hoard.loadouts[hoard.selectedLoadoutIndex]) or {}
	local out = {}
	for slot, idx in pairs(gear) do
		local list = inv[slot]
		if type(idx) == "number" and idx > 0 and type(list) == "table" and type(list[idx]) == "table" then
			out[slot] = list[idx]
		end
	end
	return out, hoard
end

-- Two Weapons' other weapon (its saved item), the way that mod picks it (TwoWeapons:GetOther: the
-- remembered previous weapon, else the current one, whichever isn't the one equipped)
function Tab.SecondWeapon(b, equipped)
	local p = type(b) == "table" and type(b.data) == "table" and b.data.player or nil
	local tw = type(p) == "table" and p.twoweapons or nil
	local hoard = type(p) == "table" and p.inventoryhoard or nil
	local list = type(hoard) == "table" and type(hoard.inventory) == "table" and hoard.inventory.WEAPON or nil
	if type(tw) ~= "table" or type(list) ~= "table" then
		return nil
	end
	local function Resolve(ref)
		if type(ref) ~= "table" or ref.id == nil then
			return nil
		end
		local it = type(ref.idx) == "number" and list[ref.idx] or nil
		if type(it) == "table" and it.id == ref.id then
			return it
		end
		for _, x in ipairs(list) do
			if type(x) == "table" and x.id == ref.id then
				return x
			end
		end
		return nil
	end
	local prev, cur = Resolve(tw.prev), Resolve(tw.cur)
	if prev ~= nil and prev ~= equipped then
		return prev
	end
	if cur ~= nil and cur ~= equipped then
		return cur
	end
	return nil
end

-- the gems in an item's slots (saved gem tables, from the build's GEMS)
function Tab.GemsOf(item, hoard)
	local out = {}
	local list = type(hoard) == "table" and type(hoard.inventory) == "table" and hoard.inventory.GEMS or {}
	for _, gs in ipairs(type(item.gem_slots) == "table" and item.gem_slots or {}) do
		if type(gs) == "table" and gs.gem_id ~= nil then
			for _, g in ipairs(list) do
				if type(g) == "table" and g.gem_id == gs.gem_id then
					out[#out + 1] = g
					break
				end
			end
		end
	end
	return out
end

-- the game's gear level: the four gear slots' item levels, averaged (playerutil.GetGearLevel)
function Tab.GearLevel(items)
	local total = 0
	for _, slot in ipairs({ "WEAPON", "HEAD", "BODY", "WAIST" }) do
		local it = items[slot]
		total = total + (it ~= nil and (tonumber(it.ilvl) or 0) or 0)
	end
	return math.floor(total / 4 + 0.5)
end

local function Runtime(saved)
	local copy = Main.deepcopy(saved)
	Tab.W.itemforge.ConvertToRuntimeItem(copy)
	return copy
end

local function ItemIcon(parent, saved, size, empty_slot)
	local W = Tab.W
	local w = parent:AddChild(W.ItemWidget(nil, nil, size))
	if saved ~= nil then
		w:SetItemInstance(Runtime(saved), 1)
	elseif empty_slot ~= nil then
		w:SetEmptySlot(empty_slot)
	end
	if w.HideQuantity ~= nil then
		w:HideQuantity()
	end
	-- only to look at: the controller stays on the slots
	if w.SetNavFocusable ~= nil then
		pcall(w.SetNavFocusable, w, false)
	end
	if w.SetClickable ~= nil then
		pcall(w.SetClickable, w, false)
	end
	return w
end

function Tab.CardOn()
	local W = Tab.W
	return Main.settings.loadout_card ~= false and W ~= nil and W.ItemWidget ~= nil and W.Image ~= nil and W.itemforge ~= nil
end

-- the card for this screen (made once per visit to the tab), or nil when it can't be shown
function Tab.EnsureCard(screen)
	if not Tab.CardOn() then
		return nil
	end
	if screen.cb_card ~= nil and not rawget(screen.cb_card, "removed") then
		return screen.cb_card
	end
	local parent = screen.customize_character_contents
	local anchor = screen.list_bg
	if parent == nil or anchor == nil then
		return nil
	end
	local W = Tab.W
	local card = parent:AddChild(W.Widget("Builds loadout card"))
	card.bg = card:AddChild(W.Image("images/global/square.tex"))
		:SetSize(Tab.CARD_W, Tab.CARD_H)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK or { 0.78, 0.68, 0.62, 1 })
		:SetMultColorAlpha(0.55)
	card.content = card:AddChild(W.Widget("Builds loadout card content"))
	card:LayoutBounds("right", "center", anchor):Offset(-40, 0)
	screen.cb_card = card
	return card
end

function Tab.ShowCard(screen, b, title)
	local card = screen.cb_card
	if card == nil or rawget(card, "removed") then
		return false
	end
	local W = Tab.W
	local TEXT = UICOLORS.LIGHT_TEXT_DARK
	local c = card.content
	c:RemoveAllChildren()
	if b == nil then
		c:AddChild(W.Text(FONTFACE.DEFAULT, 40, tostring(title) .. "\nEmpty", TEXT))
		c:LayoutBounds("center", "center", card.bg)
		return true
	end
	local items, hoard = Tab.EquippedItems(b)
	local look = Main.Look(b)
	local head = c:AddChild(W.Widget("Card head"))
	if W.PlayerLevelBadge ~= nil then
		local okb, badge = pcall(function() return head:AddChild(W.PlayerLevelBadge(70)):SetLevel(Tab.GearLevel(items)) end)
		if not okb then
			head:AddChild(W.Text(FONTFACE.DEFAULT, 40, "Lv " .. Tab.GearLevel(items), TEXT))
		end
	else
		head:AddChild(W.Text(FONTFACE.DEFAULT, 40, "Lv " .. Tab.GearLevel(items), TEXT))
	end
	head:AddChild(W.Text(FONTFACE.DEFAULT, 40, tostring(title) .. " · " .. Main.SpeciesName(look ~= nil and look.species or nil), TEXT))
	head:LayoutChildrenInRow(20)

	-- the weapon(s): name and gems (the second one: Two Weapons)
	local function WeaponRow(weapon, size)
		local row = c:AddChild(W.Widget("Card weapon"))
		local icon = ItemIcon(row, weapon, size)
		local side = row:AddChild(W.Widget("Card weapon side"))
		local okn, name = pcall(function() return Runtime(weapon):GetLocalizedName() end)
		side:AddChild(W.Text(FONTFACE.DEFAULT, 30, okn and tostring(name) or tostring(weapon.id), TEXT))
		local gems = side:AddChild(W.Widget("Card weapon gems"))
		for _, g in ipairs(Tab.GemsOf(weapon, hoard)) do
			ItemIcon(gems, g, 70)
		end
		gems:LayoutChildrenInRow(10)
		side:LayoutChildrenInColumn(10, "left")
		side:LayoutBounds("after", "center", icon):Offset(20, 0)
		return row
	end
	local weapon = items.WEAPON
	if weapon ~= nil then
		WeaponRow(weapon, 135)
		local second = Tab.SecondWeapon(b, weapon)
		if second ~= nil then
			WeaponRow(second, 135)
		end
	end

	-- the armour, with their gems
	local armour = c:AddChild(W.Widget("Card armour"))
	for _, slot in ipairs({ "HEAD", "BODY", "WAIST" }) do
		local cell = armour:AddChild(W.Widget("Card " .. slot))
		local it = items[slot]
		ItemIcon(cell, it, 120, slot)
		if it ~= nil then
			local gems = cell:AddChild(W.Widget("Card gems"))
			for _, g in ipairs(Tab.GemsOf(it, hoard)) do
				ItemIcon(gems, g, 52)
			end
			gems:LayoutChildrenInRow(6)
		end
		cell:LayoutChildrenInColumn(6, "center")
	end
	armour:LayoutChildrenInRow(30, "top")

	-- potion, tonic, food
	local extra = c:AddChild(W.Widget("Card consumables"))
	for _, slot in ipairs({ "POTIONS", "TONICS", "FOOD" }) do
		if items[slot] ~= nil then
			ItemIcon(extra, items[slot], 85)
		end
	end
	extra:LayoutChildrenInRow(20)

	-- damage and armour, as the game's loadout widget sums them
	if W.DisplayStat ~= nil and type(EQUIPMENT_STATS) == "table" then
		local stats = c:AddChild(W.Widget("Card stats"))
		local function Total(stat)
			local v = 0
			for _, slot in ipairs({ "WEAPON", "HEAD", "BODY", "WAIST" }) do
				local it = items[slot]
				if it ~= nil then
					local okv, st = pcall(function() return Runtime(it):GetStats() end)
					if okv and type(st) == "table" and type(st[stat]) == "number" then
						v = v + st[stat]
					end
				end
			end
			return v
		end
		for _, e in ipairs({ { EQUIPMENT_STATS.s.DMG_MULT, "images/icons_ftf/stat_weapon.tex" }, { EQUIPMENT_STATS.s.ARMOUR, "images/ui_ftf/ic_stat_defend.tex" } }) do
			pcall(function()
				stats:AddChild(W.DisplayStat(nil, 50, 44, 44))
					:ShouldShowToolTip(false)
					:ShowName(false)
					:SetStat({ icon = e[2], stat = e[1], value = Total(e[1]), delta = 0 })
			end)
		end
		stats:LayoutChildrenInRow(40)
	end

	-- how many loadouts it carries
	local n = 0
	for _ in pairs(type(hoard) == "table" and type(hoard.loadouts) == "table" and hoard.loadouts or {}) do
		n = n + 1
	end
	c:AddChild(W.Text(FONTFACE.DEFAULT, 28, n .. " saved loadout" .. (n == 1 and "" or "s") .. " come with it", TEXT))

	c:LayoutChildrenInColumn(20, "center")
	c:LayoutBounds("center", "top", card.bg):Offset(0, -24)
	return true
end

----------------------------------------------------------------------------
-- The slots

local function AddTile(screen, grid, b, number_text, name_text, on_click, on_focus)
	local W = Tab.W
	local tile = grid:AddChild(W.SelectableBodyPart(Tab.TILE))
	tile:SetLocked(false)
	tile:SetUnseen(false)
	tile:SetSelected(false)
	if tile.puppet_bg ~= nil then
		tile.puppet_bg:Hide()
	end
	local shown = b ~= nil and pcall(Tab.ShowLook, tile:GetPuppet(), b)
	if shown and Main.settings.show_gear then
		local okg, err = pcall(Tab.ShowGear, tile:GetPuppet(), b)
		if not okg then
			Log("a tile shows the look without the gear: " .. tostring(err))
		end
	end
	if b ~= nil and shown then
		tile:SetPuppetOffset(Tab.FRAME.x, Tab.FRAME.y)
		tile:SetPuppetScale(Tab.FRAME.scale)
	else
		tile:GetPuppet():Hide()
		tile.cb_plus = tile:AddChild(W.Text(FONTFACE.DEFAULT, 120, b == nil and "+" or "?", UICOLORS.LIGHT_TEXT_DARK))
			:SetMultColorAlpha(0.35)
	end
	tile.cb_number = tile:AddChild(W.Text(FONTFACE.DEFAULT, 56, number_text, UICOLORS.LIGHT_TEXT_DARK))
		:LayoutBounds("left", "top", tile.image)
		:Offset(20, -10)
	tile.cb_name = tile:AddChild(W.Text(FONTFACE.DEFAULT, 26, name_text, UICOLORS.LIGHT_TEXT_DARK))
		:LayoutBounds("center", "below", tile.image)
		:Offset(0, -8)
	tile:SetToolTipFn(function() return name_text end)
		:ShowToolTipOnFocus(true)
	tile:SetOnClick(on_click)
	if on_focus ~= nil and tile.SetOnGainFocus ~= nil then
		tile:SetOnGainFocus(function()
			local ok, err = pcall(on_focus)
			if not ok then
				Log("the loadout card: " .. tostring(err))
			end
		end)
	end
	return tile
end

function Tab.Build(screen)
	local token = {}
	screen.cb_build_token = token
	local done = false
	Main.Store.Read(function(t, note)
		done = true
		if screen.cb_tab_on and screen.cb_build_token == token then
			Tab.Fill(screen, t, note)
		end
	end)
	if not done then
		-- (the game's save folder answers later)
		local W = Tab.W
		screen.scroll_contents:RemoveAllChildren()
		screen.cb_tiles = {}
		screen.scroll_contents:AddChild(W.Text(FONTFACE.DEFAULT, 32, "Reading the builds...", UICOLORS.LIGHT_TEXT_DARK))
		screen.scroll_contents:LayoutBounds("center", "top", 0, -40)
	end
end

local function PlaceContents(screen, card)
	if card then
		screen.scroll_contents:LayoutBounds("left", "top", -((screen.list_width or 1750) / 2) + 40, -40)
	else
		screen.scroll_contents:LayoutBounds("center", "top", 0, -40)
	end
end

function Tab.Fill(screen, t, note)
	local W = Tab.W
	screen.scroll_contents:RemoveAllChildren()
	screen.cb_tiles = {}
	local card = Tab.EnsureCard(screen)
	local per_row = card and Tab.PER_ROW_CARD or Tab.PER_ROW
	local HINT = card and Tab.HINT_CARD or Tab.HINT
	local hint = screen.scroll_contents:AddChild(W.Text(FONTFACE.DEFAULT, 32, HINT, UICOLORS.LIGHT_TEXT_DARK))
	screen.cb_file = t
	if t == nil then
		hint:SetText(HINT .. "\n\n" .. tostring(note))
		PlaceContents(screen, card)
		return
	end
	if note ~= nil and note ~= "new" then
		hint:SetText(HINT .. "\n" .. note)
	end
	local grid = screen.scroll_contents:AddChild(W.Widget("Builds grid"))
	for slot = 1, Main.SlotCount(t) do
		local b = t.builds[slot]
		local tile = AddTile(screen, grid, b, tostring(slot), b ~= nil and Main.Describe(b) or "Empty",
			function() Tab.OpenSlot(screen, slot) end,
			card and function() Tab.ShowCard(screen, b, "Build " .. slot) end or nil)
		tile.cb_slot = slot
		table.insert(screen.cb_tiles, tile)
	end
	grid:LayoutChildrenInGrid(per_row, { h = 50, v = 90 })
	grid:LayoutBounds(card and "left" or "center", "below", hint):Offset(0, -40)
	local last = grid
	if #t.auto > 0 then
		local head = screen.scroll_contents:AddChild(W.Text(FONTFACE.DEFAULT, 40,
			card and "Automatic backups\n(your character before each load, newest first)" or "Automatic backups (your character before each load, newest first)", UICOLORS.LIGHT_TEXT_DARK))
		head:LayoutBounds(card and "left" or "center", "below", grid):Offset(0, -70)
		local agrid = screen.scroll_contents:AddChild(W.Widget("Backups grid"))
		for i, b in ipairs(t.auto) do
			local tile = AddTile(screen, agrid, b, "B" .. i, Main.Describe(b), function() Tab.OpenBackup(screen, i) end,
				card and function() Tab.ShowCard(screen, b, "Backup B" .. i) end or nil)
			tile.cb_auto = i
			table.insert(screen.cb_tiles, tile)
		end
		agrid:LayoutChildrenInGrid(per_row, { h = 50, v = 90 })
		agrid:LayoutBounds(card and "left" or "center", "below", head):Offset(0, -40)
		last = agrid
	end
	PlaceContents(screen, card)
	if card then
		local first = nil
		for slot = 1, Main.SlotCount(t) do
			if t.builds[slot] ~= nil then
				first = slot
				break
			end
		end
		pcall(Tab.ShowCard, screen, first and t.builds[first] or nil, "Build " .. (first or 1))
	end
	if screen.scroll ~= nil then
		screen.scroll:RefreshView()
	end
end

function Tab.Refocus(screen, slot, auto)
	for _, tile in ipairs(screen.cb_tiles or {}) do
		if not rawget(tile, "removed") and ((auto and tile.cb_auto == slot) or (not auto and tile.cb_slot == (slot or 1))) then
			tile:SetFocus()
			return true
		end
	end
	local first = (screen.cb_tiles or {})[1]
	if first ~= nil and not rawget(first, "removed") then
		first:SetFocus()
		return true
	end
	return false
end

local function Rebuild(screen, slot, auto)
	if screen.cb_tab_on then
		local ok, err = pcall(Tab.Build, screen)
		if not ok then
			Log("the slots couldn't be built: " .. tostring(err))
		end
		Tab.Refocus(screen, slot, auto)
	end
end

----------------------------------------------------------------------------
-- Dialogs

local function Dialog(screen, title, text)
	return Tab.W.ConfirmDialog(screen:GetOwningPlayer(), nil, true, title, "", text)
end

local function Show(dialog, vertical)
	dialog:HideArrow()
	dialog:SetMinWidth(900)
	if vertical then
		dialog:SetVerticalButtons()
	end
	dialog:CenterText()
	dialog:CenterButtons()
	TheFrontEnd:PushScreen(dialog)
	if dialog.AnimateIn ~= nil then
		dialog:AnimateIn()
	end
	return dialog
end

local function UnsavedLine(screen)
	local ok, same = pcall(screen.IsCharacterEqual, screen)
	if ok and same == false then
		return "\n(Changes not saved in the mirror aren't in it: Save Changes first to include them.)"
	end
	return ""
end

function Tab.Save(screen, slot)
	Main.SaveBuild(screen.owner, slot, function(ok, why)
		if ok then
			Main.Note("Build saved", "Build " .. slot)
		else
			Main.Note("Build not saved", tostring(why))
		end
		Rebuild(screen, slot)
	end)
end

function Tab.Delete(screen, slot, auto)
	Main.DeleteBuild(slot, auto, function(ok, why)
		if not ok then
			Main.Note("Not deleted", tostring(why))
		end
		Rebuild(screen, slot, auto)
	end)
end

function Tab.Load(screen, b, label, mode)
	Main.LoadBuild(screen.owner, b, label, mode, function(ok, why)
		if not ok then
			Main.Note("Build not loaded", tostring(why))
			if screen.cb_tab_on then
				Rebuild(screen)
			end
		end
	end, function()
		-- the mirror closes; the build goes on right after
		pcall(function() TheFrontEnd:PopScreen(screen) end)
	end)
end

-- What to load: Everything, or Everything keeping your own face; the parts behind "More options".
Tab.MODE_TEXT = {
	all = "Everything: look, face, gear, inventory, loadouts, talents",
	all_face = "Everything, keep my face: all of it, with your own eyes, nose and mouth",
	look = "Look: species, body parts, colours, player colour (your gear stays)",
	face = "Look, keep my face: as Look, with your own eyes, nose and mouth",
	colours = "Colours only: the build's colours on your own species and parts",
	gear = "Gear only: gear, inventory, loadouts, talents (your look stays)",
}
Tab.MORE = "More options..."

local function LoadDialog(screen, b, label, slot, auto, modes, title, extra_lines, more)
	local lines = { "Load " .. label .. " onto this character?", Main.Describe(b), "" }
	for _, id in ipairs(modes) do
		lines[#lines + 1] = Tab.MODE_TEXT[id]
	end
	for _, l in ipairs(extra_lines or {}) do
		lines[#lines + 1] = l
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "It goes on right away. Your character as it is now goes to the automatic backups first."
	lines[#lines + 1] = "This save's quests and farm stay as they are."
	local game = rawget(_G, "APP_VERSION")
	if b.game ~= nil and game ~= nil and tostring(b.game) ~= tostring(game) then
		lines[#lines + 1] = "Made on game build " .. tostring(b.game) .. "; this is " .. tostring(game) .. "."
	end
	local dialog = Dialog(screen, title, table.concat(lines, "\n") .. UnsavedLine(screen))
	local function Pick(id)
		return function()
			dialog:Close()
			local stop = Main.CanLoad(screen.owner, b, id)
			if stop ~= nil then
				Main.Note("Build not loaded", stop)
				return Tab.Refocus(screen, slot, auto)
			end
			Tab.Load(screen, b, label, id)
		end
	end
	local buttons = {}
	for _, id in ipairs(modes) do
		buttons[#buttons + 1] = { Main.MODES[id].name, Pick(id) }
	end
	if more ~= nil then
		buttons[#buttons + 1] = { Tab.MORE, function() dialog:Close(); more() end }
	end
	for i, bt in ipairs(buttons) do
		if i == 1 then
			dialog:SetYesButton(bt[1], bt[2])
		elseif i == 2 then
			dialog:SetNoButton(bt[1], bt[2])
		else
			dialog:AddButton(bt[1], bt[2])
		end
	end
	dialog:SetCancelButton("Cancel", function() dialog:Close(); Tab.Refocus(screen, slot, auto) end)
	return Show(dialog, true)
end

function Tab.ConfirmLoad(screen, b, label, slot, auto)
	local why = Main.CanLoad(screen.owner, b, "look")
	if why ~= nil then
		local dialog = Dialog(screen, "Can't load " .. label, why)
		dialog:SetYesButton("OK", function() dialog:Close(); Tab.Refocus(screen, slot, auto) end)
		dialog:HideNoButton()
		return Show(dialog, false)
	end
	return LoadDialog(screen, b, label, slot, auto, Main.MAIN_MODES, "Load " .. label,
		{ "More options: only the look, only the colours, only the gear." },
		function() Tab.MoreLoadOptions(screen, b, label, slot, auto) end)
end

function Tab.MoreLoadOptions(screen, b, label, slot, auto)
	return LoadDialog(screen, b, label, slot, auto, Main.MORE_MODES, "Load part of " .. label)
end

function Tab.ConfirmReplace(screen, slot)
	local t = screen.cb_file
	local b = t ~= nil and t.builds[slot] or nil
	local dialog = Dialog(screen, "Replace build " .. slot .. "?", "Save this character in slot " .. slot
		.. (b ~= nil and (" instead of " .. Main.Describe(b)) or "") .. "?" .. UnsavedLine(screen))
	dialog:SetYesButton("Replace", function() dialog:Close(); Tab.Save(screen, slot) end)
	dialog:SetNoButton("Keep it", function() dialog:Close(); Tab.Refocus(screen, slot) end)
	return Show(dialog, false)
end

function Tab.ConfirmDelete(screen, slot, auto)
	local t = screen.cb_file
	local b = t ~= nil and (auto and t.auto[slot] or t.builds[slot]) or nil
	if b == nil then
		return nil
	end
	local name = auto and ("backup B" .. slot) or ("build " .. slot)
	local dialog = Dialog(screen, "Delete " .. name .. "?", "Delete " .. name .. " (" .. Main.Describe(b) .. ")? This can't be undone.")
	dialog:SetYesButton("Delete", function() dialog:Close(); Tab.Delete(screen, slot, auto) end)
	dialog:SetNoButton("Keep it", function() dialog:Close(); Tab.Refocus(screen, slot, auto) end)
	return Show(dialog, false)
end

function Tab.OpenSlot(screen, slot)
	local t = screen.cb_file
	local b = t ~= nil and t.builds[slot] or nil
	local dialog
	if b == nil then
		dialog = Dialog(screen, "Build " .. slot, "Empty. Save this character here?" .. UnsavedLine(screen))
		dialog:SetYesButton("Save this character here", function() dialog:Close(); Tab.Save(screen, slot) end)
		dialog:HideNoButton()
	else
		dialog = Dialog(screen, "Build " .. slot, Main.Describe(b))
		dialog:SetYesButton("Load onto this character", function() dialog:Close(); Tab.ConfirmLoad(screen, b, "build " .. slot, slot) end)
		dialog:SetNoButton("Save this character here", function() dialog:Close(); Tab.ConfirmReplace(screen, slot) end)
		dialog:AddButton("Delete", function() dialog:Close(); Tab.ConfirmDelete(screen, slot) end)
	end
	dialog:SetCancelButton("Close", function() dialog:Close(); Tab.Refocus(screen, slot) end)
	return Show(dialog, true)
end

function Tab.OpenBackup(screen, i)
	local t = screen.cb_file
	local b = t ~= nil and t.auto[i] or nil
	if b == nil then
		return nil
	end
	local dialog = Dialog(screen, "Backup B" .. i, Main.Label(b) .. "\n" .. Main.Describe(b))
	dialog:SetYesButton("Load onto this character", function() dialog:Close(); Tab.ConfirmLoad(screen, b, "backup B" .. i, i, true) end)
	dialog:SetNoButton("Delete", function() dialog:Close(); Tab.ConfirmDelete(screen, i, true) end)
	dialog:SetCancelButton("Close", function() dialog:Close(); Tab.Refocus(screen, i, true) end)
	return Show(dialog, true)
end

----------------------------------------------------------------------------

-- LT / RT (the sub-tab buttons) on a tab without sub-tabs: the game's TabGroup:NextTab stops the game
-- there. FURY and Player Colours put in the same guard (once, whichever loads first, flagged on the
-- class); this one too, so BUILDS is covered with those mods off.
function Tab.GuardSubTabButtons()
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

-- W: SelectableBodyPart, Text, Widget, ConfirmDialog (the game's widgets).
function Tab.Install(CharacterScreen, W, GameContent)
	if type(CharacterScreen) ~= "table" then
		return false, "screens.character.characterscreen"
	end
	for _, k in ipairs({ "SelectableBodyPart", "Text", "Widget", "ConfirmDialog" }) do
		if W == nil or W[k] == nil then
			return false, "the game's " .. k
		end
	end
	for _, fn in ipairs({ "OnChangeTab", "FocusFirstElement" }) do
		if type(CharacterScreen[fn]) ~= "function" then
			return false, "a game update changed CharacterScreen:" .. fn
		end
	end
	local top_tabs = FindUpvalue(CharacterScreen._ctor, "TOP_TABS", Tab.SEARCH_DEPTH)
	if type(top_tabs) ~= "table" then
		return false, "a game update changed the character screen's tab list"
	end
	if STRINGS == nil or STRINGS.CHARACTER_CREATOR == nil then
		return false, "STRINGS.CHARACTER_CREATOR"
	end
	Tab.W = W
	Tab.SetLabel()
	local okg, gdone, gwhy = pcall(Tab.GuardSubTabButtons)
	if not okg or not gdone then
		Log("LT / RT guard skipped: " .. tostring(okg and gwhy or gdone))
	end
	-- the name again after every language pass (it replaces the strings table)
	if type(GameContent) == "table" and type(GameContent.SetLanguage) == "function" and not rawget(GameContent, "cb_label_hook") then
		local orig = GameContent.SetLanguage
		GameContent.SetLanguage = function(self, ...)
			local r = table.pack(orig(self, ...))
			pcall(Tab.SetLabel)
			return table.unpack(r, 1, r.n)
		end
		rawset(GameContent, "cb_label_hook", true)
	end
	local present = false
	for _, id in ipairs(top_tabs) do
		if id == Tab.ID then
			present = true
		end
	end
	if not present then
		table.insert(top_tabs, Tab.ID)
	end

	local function Leave(screen)
		if screen.cb_card ~= nil then
			pcall(function() screen.cb_card:Remove() end)
			screen.cb_card = nil
		end
		screen.cb_tab_on = nil
		screen.cb_tiles = nil
		screen.cb_file = nil
	end
	Tab.Leave = Leave
	RegisterTabLeave(CharacterScreen, Tab.ID, Leave)

	local orig_OnChangeTab = CharacterScreen.OnChangeTab
	function CharacterScreen:OnChangeTab(tab_button, ...)
		if tab_button == nil or tab_button.top_tab_id ~= Tab.ID then
			Leave(self)
			return orig_OnChangeTab(self, tab_button, ...)
		end
		LeaveOtherTabs(CharacterScreen, self, Tab.ID)
		pcall(self.ClearColorPreview, self)
		pcall(self.ClearBodyPartPreview, self)
		self.cb_tab_on = true
		self.subnav:RemoveAllTabs()
		self.subnav_bg:SetShown(false)
		self.subnav:SetShown(false)
		if self.color_elements_list ~= nil then
			self.color_elements_list:RemoveAllChildren()
		end
		self.can_randomize_species = false
		local ok, err = pcall(Tab.Build, self)
		if not ok then
			Log("the slots couldn't be built: " .. tostring(err))
		end
		self:FocusFirstElement()
	end

	local orig_Focus = CharacterScreen.FocusFirstElement
	function CharacterScreen:FocusFirstElement(...)
		if self.cb_tab_on then
			local cur = CurrentTopTab(self)
			if cur ~= nil and cur ~= Tab.ID then
				Leave(self)
			elseif self.cb_tiles ~= nil and Tab.Refocus(self) then
				return
			end
		end
		return orig_Focus(self, ...)
	end
	return true
end

----------------------------------------------------------------------------
-- A key that opens the BUILDS tab (the mirror's screen) for the keyboard player, anywhere in town.

local KEY_ALIASES = { ["="] = "EQUALS", ["-"] = "MINUS" }

-- "Ctrl+B" -> { ctrl, shift, alt, key = "B" }; nil for "" or a bad one
function Tab.ParseKey(text)
	if type(text) ~= "string" or text == "" or text:sub(-2) == "++" then
		return nil
	end
	local b = { ctrl = false, shift = false, alt = false }
	local mods, key = text:match("^(.-)%+?([^+]+)$")
	for part in (mods or ""):gmatch("[^+%s]+") do
		local low = part:lower()
		if low == "ctrl" or low == "control" then
			b.ctrl = true
		elseif low == "shift" then
			b.shift = true
		elseif low == "alt" then
			b.alt = true
		else
			return nil
		end
	end
	key = key ~= nil and (KEY_ALIASES[key] or key:upper()) or nil
	if key == nil or key == "" then
		return nil
	end
	b.key = key
	return b
end

function Tab.KeyboardPlayer()
	local okp, playerutil = pcall(require, "util.playerutil")
	if not okp or type(playerutil) ~= "table" then
		return nil
	end
	local player = nil
	pcall(function()
		local kb = TheInput:GetKeyboard()
		local hunter = kb ~= nil and kb:GetOwnerId() or nil
		if hunter ~= nil and playerutil.GetByHunterId ~= nil then
			player = playerutil.GetByHunterId(hunter)
		end
	end)
	if player == nil and playerutil.CountLocalPlayers ~= nil and playerutil.CountLocalPlayers() == 1 then
		player = playerutil.GetFirstLocalPlayer()
	end
	return player
end

-- the BUILDS tab's place in the screen's tabs
function Tab.OpenBuildsTab(screen)
	local nav = screen.navbar
	local tabs = nav ~= nil and rawget(nav, "tabs") or nil
	for i, t in ipairs(type(tabs) == "table" and tabs or {}) do
		if t.top_tab_id == Tab.ID then
			nav:OpenTabAtIndex(i)
			return true
		end
	end
	return false
end

-- open (or close, when it's the screen on top) for the keyboard player
function Tab.Toggle(CharacterScreen)
	local fe = TheFrontEnd
	local top = fe ~= nil and fe:GetActiveScreen() or nil
	if top ~= nil and rawget(top, "cb_opened_by_key") then
		return top:OnCloseClicked()
	end
	local hud = TheDungeon ~= nil and TheDungeon.HUD or nil
	if top == nil or top ~= hud then
		return -- a menu is open
	end
	if not Main.InTown() then
		return Main.Note("Builds", "The builds open in town (or at the mirror)")
	end
	local player = Tab.KeyboardPlayer()
	if player == nil or not player:IsValid() or (player.IsSpectating ~= nil and player:IsSpectating()) then
		return
	end
	local pc = player.components.playercontroller
	local screen = CharacterScreen(player)
	rawset(screen, "cb_opened_by_key", true)
	rawset(screen, "cb_open_builds", true)
	if pc ~= nil and pc.PushScreenFromInteraction ~= nil then
		pc:PushScreenFromInteraction(screen)
	else
		fe:PushScreen(screen)
	end
end

function Tab.InstallKey(CharacterScreen, text)
	local b = Tab.ParseKey(text)
	if b == nil then
		return false, (text == "" and "no key" or ("\"" .. tostring(text) .. "\" isn't a key I know"))
	end
	local IC = rawget(_G, "InputConstants")
	local code = type(IC) == "table" and type(IC.Keys) == "table" and IC.Keys[b.key] or nil
	if code == nil or TheInput == nil or TheInput.AddKeyDownHandler == nil or TheInput.IsKeyDown == nil then
		return false, "the game's keys changed"
	end
	if type(CharacterScreen.OnBecomeActive) ~= "function" then
		return false, "a game update changed CharacterScreen:OnBecomeActive"
	end
	-- when the screen opened by the key comes up (the game opens its own first tab then): BUILDS
	if not rawget(CharacterScreen, "cb_key_hook") then
		local orig = CharacterScreen.OnBecomeActive
		CharacterScreen.OnBecomeActive = function(self, ...)
			local r = table.pack(orig(self, ...))
			if rawget(self, "cb_open_builds") then
				rawset(self, "cb_open_builds", nil)
				local ok, err = pcall(Tab.OpenBuildsTab, self)
				if not ok then
					Log("the BUILDS tab didn't open: " .. tostring(err))
				end
			end
			return table.unpack(r, 1, r.n)
		end
		rawset(CharacterScreen, "cb_key_hook", true)
	end
	local K = IC.Keys
	TheInput:AddKeyDownHandler(code, function()
		if TheFrontEnd ~= nil and TheFrontEnd.forceProcessText then
			return
		end
		local down = function(name) return K[name] ~= nil and TheInput:IsKeyDown(K[name]) == true end
		if down("CTRL") == b.ctrl and down("SHIFT") == b.shift and down("ALT") == b.alt then
			local ok, err = pcall(Tab.Toggle, CharacterScreen)
			if not ok then
				Log("the key: " .. tostring(err))
			end
		end
	end)
	return true
end

return Tab
