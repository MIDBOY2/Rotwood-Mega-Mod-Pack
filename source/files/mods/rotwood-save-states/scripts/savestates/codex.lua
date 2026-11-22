-- Save States: the Saved Hunts tab in the camp's Codex (the book at the camp's
-- entrance: screens/town/codexscreenmulti.lua).
--
-- The tab is the Codex's own kind (its tab group, the game's save icon from the
-- loadout screen), and its page is built like the Codex's region page:
--   * left: one row per slot ("1: Great Rotwood Forest" + the region's
--     ornament), the Codex's own list buttons;
--   * top band (the Codex's slot panel, the one under the region badge): the
--     hunt's shield (the map's badge art with the hunt's icon) on the
--     exploration badge's grey wings, the region's ornament on both sides (the
--     right one mirrored), the hunt's name and its Frenzy level;
--   * a summary per player: the two weapon classes around "P1", HP, extra
--     lives, Teffra, rerolls, potions left, the run's powers the game shows
--     (its power icons, with their counters and tooltips);
--   * the room (with its icon from the dungeon map), when it was saved, the note;
--   * each player sees his own summary first (on P2's Codex, P2 then P1);
--   * a big LOAD button (the game's primary button). It closes the Codex and
--     loads the save (Rebuild; Replicate when your weapons differ and the
--     saved ones can be put on). A save that can't load says why instead.
--
-- Everything is found where the game keeps it (the Codex's local classes via
-- the functions that use them). If any piece isn't there (a game update), the
-- Codex stays the game's, logged. Any error in the page shows a line on it,
-- never the game's error screen.
local SS = require "savestates.main"
local D = require "savestates.data"

local Codex = {}

Codex.KEY = "savestates_saved_hunts" -- the page's key in the Codex's panel list
Codex.TAB_ICON = "images/icons_ftf/loadout_save.tex" -- the game's save icon (loadout screen)
Codex.WINGS = "images/ui_ftf_runsummary/DungeonLevelDecor.tex" -- the exploration badge's wings
Codex.WINGS_SIZE = 186 -- the wings' width (DungeonLevelDecor: 301 x 274)
Codex.WINGS_DROP = 15 -- the wings sit this much lower than the shield's middle
-- the hunt's shield: the map's badge art (256 x 256) and the boss icon on it
-- (widgets/ftf/dungeonselection/maplocationmarker.lua: icon 116 of 256, 14 down)
Codex.SHIELDS = {
	main = "images/mapicons_ftf/dungeon_boss_bg.tex",
	frenzy = "images/mapicons_ftf/dungeon_frenzy_boss_bg.tex",
	super = "images/mapicons_ftf/dungeon_super_frenzy_boss_bg.tex",
	sub = "images/mapicons_ftf/dungeon_bg.tex",
	sub_frenzy = "images/mapicons_ftf/dungeon_frenzy_bg.tex",
}
Codex.SHIELD_SIZE = 155 -- (0.1.10: 124; the Codex's own badge is about this big on its wings)
Codex.SHIELD_ICON = 116 / 256
Codex.SHIELD_ICON_Y = -14 / 256
Codex.BAND_HEIGHT = 180 -- the top band (the Codex's region page: 160)
Codex.BAND_MARGIN = 25 -- kept clear at each end of the band (its slanted corners)
Codex.ORNAMENT_SIZE = 62 -- the region's ornaments' height (they're wider than tall)
Codex.DIVIDER = "images/ui_ftf/title_divider_3.tex" -- the Codex's divider in a slot panel
Codex.ROOM_ICON = 80 -- the room's map icon (the dungeon map's own, widgets/ftf/maproom.lua), this tall
Codex.ICONS = {
	hp = "images/icons_ftf/stat_health.tex",
	konjur = "images/hud_images/hud_konjur_drops_currency.tex",
	rerolls = "images/hud_images/hud_reroll_currency.tex",
	potion = "images/hud_images/hud_potion.tex",
	lives_wings = "images/ui_ftf_segmented_healthbar/revive_wings.tex",
	lives_plus = "images/ui_ftf_segmented_healthbar/revive_plus.tex",
}
Codex.LOAD_AREA = 185 -- the page's bottom part kept for the LOAD button and the line over it
-- the LOAD button's least size to the game's standard button (BUTTON_W x
-- BUTTON_H, 580 x 140). Its text keeps the game's button size and font, made
-- like the Codex's own Replay button (RegionPanel:_AddReminisceButton:
-- SetTextAndResizeToFit(text, 60, nil, BUTTON_W * 0.9, BUTTON_H * 0.9))
Codex.LOAD_SIZE = 0.55
Codex.SETTLE = 0.15 -- seconds the focus stays on a slot before its page is drawn
Codex.PAGES_KEPT = 6 -- slot pages kept drawn (hidden) while the Codex is open
Codex.POWER_SIZE = 80
-- the gap between power icons: their hit box is 0.8 of their art, so a small
-- gap keeps the hexagons apart without holes the cursor falls through (each
-- hole took the focus off and the tooltip went and came back)
Codex.POWER_GAP = 2
Codex.BAND_WIDTH = 950 -- the slot panel's width (widgets/ftf/slotcontentspanel.lua default)
Codex.POWERS_PER_ROW = 10
-- The stats row: every icon's visible art is the same height and stands on
-- the digits' bottom line, the gaps between items alike.
-- What part of each icon's art is visible (left, bottom, right, top, as
-- fractions of the picture; then its width to its height), measured from the
-- game's atlases: the pictures have empty borders of their own (the HUD's
-- potions most of all), so lining up the pictures left the art crooked.
-- Then how far the art sits below the line (sink, of its height: art whose
-- lowest pixels are thin tips or a corner looks like it floats, so it goes a
-- little lower to rest its body on the line; Teffra's round bottom is the
-- measure) and its size to the others (scale).
Codex.ART = {
	["images/icons_ftf/stat_health.tex"] = { 0.039, 0.070, 0.961, 0.922, 1, 0.10 }, -- the heart's point
	["images/hud_images/hud_konjur_drops_currency.tex"] = { 0.094, 0.020, 0.906, 0.984, 1, 0 },
	["images/hud_images/hud_reroll_currency.tex"] = { 0.113, 0.094, 0.898, 0.855, 1, 0.08 }, -- the dice's corner
	["images/hud_images/hud_potion.tex"] = { 0.211, 0.030, 0.789, 0.970, 1, 0 },
	["images/ui_ftf_segmented_healthbar/revive_wings.tex"] = { 0.016, 0.047, 1.000, 0.938, 1, 0.12 }, -- the feather tips
}
-- the HUD's potions (icons_inventory: icon_hud_ready_* / icon_hud_empty_*): a
-- slim bottle, a quarter bigger than the others
Codex.HUD_POTION_ART = { 0.30, 0.197, 0.70, 0.803, 1, 0.06, 1.25 }
Codex.STAT_LINE = 1.8 -- each stat's height for the row (around its number): the numbers line up whatever the icons do
Codex.STAT_ICON = 1.0 -- an icon's visible height to the stats' font size
Codex.DIGIT_HALF = 0.365 -- half the digits' height to the font size (the game's font, blockhead; its text box is centred on them)
Codex.STAT_ICON_GAP = 10 -- between an icon and its number
Codex.STAT_GAP = 44 -- between one stat and the next

Codex.STR = {
	TITLE = "Saved Hunts",
	EMPTY = "No saved hunts yet.\nIn a hunt, Ctrl+1 to Ctrl+0 saves to slots 1 to 10.",
	STORE_LOADING = "The save list is still loading.",
	LOADING = "Reading the save...",
	UNREADABLE = "This save couldn't be read.",
	LOAD = "LOAD",
	REPLICATE = "Your weapons differ: it loads with the saved weapons (Replicate).",
	BUSY = "A load is in progress.",
	LOADING_OFF = "Loading is off: %s",
	CANT = "Can't load: %s",
	ERROR = "This page had an error (in the log). The save itself is fine.",
	AUTO = "Latest",
	ROOM = "Room %s",
	SAVED = "Saved %s",
	SLOT = "slot %d",
	LATEST = "the latest auto save",
	BLIGHT = "The Blight, part %s",
	WEATHER = "weather",
	STANDARD = "Standard",
	FRENZY = "Frenzy %d",
	SUPER = "Super Frenzy %d",
	SWAP_OFF = "Swap P1 / P2",
	SWAP_ON = "Swapped P1 / P2",
	SWAP_SUGGEST = "Your characters are the other way round from the save: Swap P1 / P2?",
	SWAPPED = "Swapped: player 1 gets %s, player 2 gets %s.",
	FORCED_CANT = "Can't load with %s: %s",
	HINT_REPLICATE = "Load: Replicate",
	HINT_REBUILD = "Load: Rebuild",
	HINT_SWAP = "Swap P1 / P2",
	MODE_REPLICATE = "Replicate",
	MODE_REBUILD = "Rebuild",
	EMPTY_SLOT = "Empty",
	EMPTY_PAGE = "Slot %d is empty.\nSAVE puts this room here.",
	SAVE_TO = "SAVE TO SLOT %d",
	OVERWRITE = "OVERWRITE SLOT %d",
	SAVED_NOTE = "Saved to slot %d.",
	NOT_SAVED = "Not saved: %s",
	CANT_SAVE = "Can't save here: %s",
	HISTORY = "History",
	BEFORE_LOAD = "Before load",
	BUTTON_SAVE = "SAVE HUNT",
	BUTTON_LOAD = "LOAD HUNT",
}
Codex.AUTO_SHOWN = 20     -- auto saves listed under the slots (the newest)
Codex.HISTORY_SHOWN = 150 -- each hidden history tab (Ctrl+Shift+Alt+1 / both triggers)
Codex.view = nil          -- set while a page is made: { mode = "save" / "load" / "manual" / "auto", history = true }
Codex.HISTORY_TABS = {
	{ mode = "manual", key_suffix = "_manual", title = "Manual history" },
	{ mode = "auto", key_suffix = "_auto", title = "Auto history" },
}
Codex.open_pages = setmetatable({}, { __mode = "k" })
Codex.LS_CONTROL = "SAVESTATES_LOAD_REPLICATE" -- a control of our own on the left stick click (the game has none in menus)

-- the room you were in
Codex.ROOM_NAMES = {
	monster = "Fight", miniboss = "Miniboss", boss = "Boss", hype = "Before the boss", market = "Market",
	potion = "Potion stop", powerupgrade = "Power upgrade", wanderer = "Mystery", quest = "Mystery",
	food = "Food", empty = "Rest", entrance = "Start", insert = "Mystery", ranger = "Mystery",
}
Codex.REWARD_NAMES = {
	plain = nil, coin = "Teffra", konjur = "Teffra", power = "Power", fabled = "Fabled power",
	weaponpower = "Weapon power", small_token = "Corestone", big_token = "Heart", corestone = "Corestone",
}

-- set by modmain
Codex.L = nil
Codex.G = nil
Codex.biomes = nil
Codex.itemforge = nil
Codex.Equipment = nil
Codex.settings = { first = true }

local errors = 0
local function Log(msg)
	if errors < 10 then
		errors = errors + 1
		SS.Log("Saved Hunts: " .. tostring(msg))
	end
end
Codex.Log = Log

local function G()
	return Codex.G or _G
end

local function Global(name)
	return rawget(G(), name)
end

-- ---------------------------------------------------------------------------
-- what a save shows (plain data: tested on its own)

local function Whole(n)
	n = tonumber(n) or 0
	return math.floor(n + 0.5)
end

local function Grouped(n)
	local s = tostring(Whole(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""):gsub("^%-,", "-"))
end
Codex.Grouped = Grouped

-- a hunt's location id from the store's line (saves from before 0.1.4 have no meta.location)
function Codex.LocationOf(meta)
	if type(meta) ~= "table" then
		return nil
	end
	if type(meta.location) == "string" then
		return meta.location
	end
	local line = type(meta.summary) == "string" and meta.summary or ""
	local in_blight = line:match("^Blight leg [^(]*%(([%w_]+)%)")
	return in_blight or line:match("^([%w_]+)")
end

function Codex.Location(location_id)
	local b = Codex.biomes
	return b ~= nil and b.locations ~= nil and location_id ~= nil and b.locations[location_id] or nil
end

-- "Great Rotwood Forest" (the region: named after its main hunt, like the Codex)
function Codex.RegionName(location_id)
	local loc = Codex.Location(location_id)
	if loc == nil then
		return tostring(location_id or "?")
	end
	local b = Codex.biomes
	local parent_id = b.GetParentLocation ~= nil and b.GetParentLocation(location_id) or location_id
	local parent = b.locations[parent_id] or loc
	local name = parent.pretty ~= nil and parent.pretty.name or nil
	return name or (loc.pretty ~= nil and loc.pretty.name) or tostring(location_id)
end

function Codex.Ornament(location_id)
	local loc = Codex.Location(location_id)
	local b = Codex.biomes
	local region = loc ~= nil and b.regions ~= nil and b.regions[loc.region_id] or nil
	return region ~= nil and region.title_ornament or nil
end

-- the left list: slots 1-10, then the latest auto save
function Codex.Slots(store, view)
	local list = {}
	if store == nil or not store.loaded then
		return list
	end
	local SLOTS = store.SLOTS or 10
	local function Add(slot, prefix, label)
		local id = store:SlotId(slot)
		local meta = id ~= nil and store.meta[id] or nil
		if meta == nil then
			return
		end
		local loc = Codex.LocationOf(meta)
		list[#list + 1] = {
			slot = slot, id = id, meta = meta, location = loc, label = label,
			pretty_name = prefix .. ": " .. Codex.RegionName(loc),
			ornament = Codex.Ornament(loc),
		}
	end
	local mode = type(view) == "table" and view.mode or nil
	if mode == "manual" or mode == "auto" then
		return Codex.HistoryList(store, mode)
	end
	for s = 1, SLOTS do
		local before = #list
		Add(s, tostring(s), string.format(Codex.STR.SLOT, s))
		if mode == "save" and #list == before then
			-- an empty slot to save into
			list[#list + 1] = { slot = s, empty = true, label = string.format(Codex.STR.SLOT, s),
				pretty_name = tostring(s) .. ": " .. Codex.STR.EMPTY_SLOT }
		end
	end
	Add(0, Codex.STR.AUTO, Codex.STR.LATEST)
	-- the auto saves (every room you enter; your state before each load), newest first
	local latest = store:SlotId(0)
	local shown = {}
	for _, item in ipairs(list) do
		if item.id ~= nil then
			shown[item.id] = true
		end
	end
	local function History(ids, cap, name_of)
		local n = 0
		for k = #(ids or {}), 1, -1 do
			if n >= cap then
				break
			end
			local id = ids[k]
			local meta = store.meta[id]
			if meta ~= nil and not shown[id] then
				shown[id] = true
				n = n + 1
				local loc = Codex.LocationOf(meta)
				local when = Codex.Date ~= nil and Codex.Date(meta.time) or nil
				local label = name_of(meta) .. (when ~= nil and (" " .. when) or "")
				list[#list + 1] = {
					id = id, meta = meta, location = loc, label = label, history = true,
					pretty_name = label .. ": " .. Codex.RegionName(loc),
					ornament = Codex.Ornament(loc),
				}
			end
		end
	end
	local function AutoName(meta)
		return meta.kind == "undo" and Codex.STR.BEFORE_LOAD or Codex.STR.AUTO
	end
	local _ = latest
	if mode == "save" or mode == "load" then
		History(store.auto, Codex.AUTO_SHOWN, AutoName)
	end
	return list
end

-- a hidden history tab's list: every save of that history, newest first
function Codex.HistoryList(store, mode)
	local list = {}
	local ids = mode == "manual" and store.manual or store.auto
	local n = 0
	for k = #(ids or {}), 1, -1 do
		if n >= Codex.HISTORY_SHOWN then
			break
		end
		local id = ids[k]
		local meta = store.meta[id]
		if meta ~= nil then
			n = n + 1
			local loc = Codex.LocationOf(meta)
			local when = Codex.Date ~= nil and Codex.Date(meta.time) or nil
			local name = mode == "manual" and Codex.STR.HISTORY or (meta.kind == "undo" and Codex.STR.BEFORE_LOAD or Codex.STR.AUTO)
			local label = name .. (when ~= nil and (" " .. when) or "")
			list[#list + 1] = {
				id = id, meta = meta, location = loc, label = label, history = true,
				pretty_name = label .. ": " .. Codex.RegionName(loc),
				ornament = Codex.Ornament(loc),
			}
		end
	end
	return list
end

-- the header: the hunt's shield, name, Frenzy level, the region's ornament
function Codex.HeaderInfo(st)
	local run = type(st) == "table" and type(st.run) == "table" and st.run or {}
	local loc = Codex.Location(run.location_id)
	local level = Whole(run.ascension)
	local normal = Global("NORMAL_FRENZY_LEVELS") or 5
	local text
	local super = level > normal
	if level <= 0 then
		text = Codex.STR.STANDARD
	elseif super then
		text = string.format(Codex.STR.SUPER, level - normal)
	else
		text = string.format(Codex.STR.FRENZY, level)
	end
	return {
		name = loc ~= nil and loc.pretty ~= nil and loc.pretty.name or tostring(run.location_id or "?"),
		icon = loc ~= nil and loc.icon or nil,
		ornament = Codex.Ornament(run.location_id),
		frenzy = text,
		level = level,
		super = super,
		sub = loc ~= nil and loc.alternate_metaprogress ~= nil, -- a side hunt (the map's own test)
	}
end

local function Records(p)
	local pm = type(p.powers) == "table" and p.powers or {}
	local pd = type(pm.power_data) == "table" and pm.power_data or {}
	return type(pd.powers) == "table" and pd.powers or {}, pm
end

-- the run's powers, in the order they were picked
function Codex.RunPowers(p)
	local powers = Records(p)
	local out = {}
	for slot, list in pairs(powers) do
		if type(list) == "table" and not D.NONRUN[slot] then
			for name, rec in pairs(list) do
				if type(rec) == "table" and type(rec.id) == "string" then
					out[#out + 1] = rec
				end
			end
		end
	end
	-- a skill picked up in the run (not your weapon's, not a mod's permanent one)
	local pm = type(p.powers) == "table" and p.powers or {}
	if type(pm.overridden_equipment_skills) == "table" and next(pm.overridden_equipment_skills) ~= nil and type(powers.SKILL) == "table" then
		for _, rec in pairs(powers.SKILL) do
			if type(rec) == "table" and type(rec.id) == "string" and not rec.permanent then
				out[#out + 1] = rec
			end
		end
	end
	table.sort(out, function(a, b)
		local x, y = tonumber(a.acquire_order) or 0, tonumber(b.acquire_order) or 0
		if x ~= y then
			return x < y
		end
		return a.id < b.id
	end)
	return out
end

function Codex.PlayerInfo(p, i)
	p = type(p) == "table" and p or {}
	local powers, pm = Records(p)
	local hp_max = Whole(p.hp_max)
	local hp = p.hp ~= nil and Whole(p.hp) or hp_max
	local talents = type(powers.TALENT) == "table" and powers.TALENT or {}
	local lives_rec = talents.talent_extra_lives
	local potion = type(p.potion) == "table" and p.potion or {}
	local classes = type(p.classes) == "table" and p.classes or {}
	local held = p.held or classes[1]
	local other
	for _, c in ipairs(classes) do
		if c ~= held then
			other = c
			break
		end
	end
	return {
		index = tonumber(p.index) or i,
		name = type(p.name) == "string" and p.name or nil,
		held = held, other = other,
		hp = hp, hp_max = hp_max,
		lives = type(lives_rec) == "table" and Whole(lives_rec.lives_left) or nil,
		konjur = Whole(p.konjur),
		rerolls = Whole(pm.power_drop_rerolls),
		potion_id = potion.id,
		potions = potion.remaining ~= nil and Whole(potion.remaining) or nil,
		powers = Codex.RunPowers(p),
	}
end

function Codex.WeaponTex(class)
	local t = Global("WEAPON_TYPE_TO_TEX")
	return type(t) == "table" and class ~= nil and t[class] or nil
end

-- the potion as the HUD draws it (widgets/ftf/potionwidget.lua: the def's
-- ui_icons, the empty one when none are left), else its inventory icon
function Codex.PotionTex(id, remaining)
	local E = Codex.Equipment
	local def = E ~= nil and E.Items ~= nil and E.Items.POTIONS ~= nil and id ~= nil and E.Items.POTIONS[id] or nil
	local ui = def ~= nil and type(def.ui_icons) == "table" and def.ui_icons or nil
	if ui ~= nil then
		local tex = (remaining ~= nil and remaining <= 0) and ui.consumed or ui.ready
		if tex ~= nil then
			return tex
		end
	end
	return def ~= nil and def.icon or Codex.ICONS.potion
end

local function Date(t)
	local os_lib = rawget(G(), "os") or rawget(_G, "os")
	if type(t) ~= "number" or os_lib == nil or os_lib.date == nil then
		return nil
	end
	return os_lib.date("%d %b %H:%M", t)
end
Codex.Date = Date

-- the lines under the players: the room, when it was saved, the note
function Codex.RoomLines(st, meta)
	local run = type(st) == "table" and type(st.run) == "table" and st.run or {}
	local parts = {}
	parts[#parts + 1] = string.format(Codex.STR.ROOM, tostring(run.room_index or run.room_id or "?"))
	local room = run.roomtype ~= nil and (Codex.ROOM_NAMES[run.roomtype] or run.roomtype) or nil
	if room ~= nil then
		parts[#parts + 1] = room
	end
	local reward = run.reward ~= nil and Codex.REWARD_NAMES[run.reward] or nil
	if reward ~= nil then
		parts[#parts + 1] = reward
	end
	if run.trek ~= nil then
		parts[#parts + 1] = string.format(Codex.STR.BLIGHT, tostring(run.trek_leg or "?"))
	end
	if run.is_weather_enabled then
		parts[#parts + 1] = Codex.STR.WEATHER
	end
	local lines = { table.concat(parts, "  -  ") }
	local when = Date(type(meta) == "table" and meta.time or (type(st) == "table" and st.time) or nil)
	if when ~= nil then
		lines[#lines + 1] = string.format(Codex.STR.SAVED, when)
	end
	if type(meta) == "table" and type(meta.note) == "string" and meta.note ~= "" then
		lines[#lines + 1] = "\"" .. meta.note .. "\""
	end
	return lines
end

-- can this save load now: ok, mode, note
function Codex.LoadChoice(st)
	local L = Codex.L
	if L == nil then
		return false, nil, "no loader"
	end
	if SS.off ~= nil and SS.off.loading ~= nil then
		return false, nil, string.format(Codex.STR.LOADING_OFF, tostring(SS.off.loading))
	end
	if L.busy then
		return false, nil, Codex.STR.BUSY
	end
	local okc, ok, why = pcall(L.Check, st, "rebuild")
	if not okc then
		return false, nil, string.format(Codex.STR.CANT, tostring(ok))
	end
	if ok then
		return true, "rebuild", nil
	end
	local okc2, ok2 = pcall(L.Check, st, "replicate")
	if okc2 and ok2 then
		return true, "replicate", Codex.STR.REPLICATE
	end
	return false, nil, string.format(Codex.STR.CANT, tostring(why))
end

-- can this save load with that mode (LS / RS on the page): ok, why
function Codex.LoadChoiceFor(st, mode)
	local L = Codex.L
	if L == nil then
		return false, "no loader"
	end
	if SS.off ~= nil and SS.off.loading ~= nil then
		return false, string.format(Codex.STR.LOADING_OFF, tostring(SS.off.loading))
	end
	if L.busy then
		return false, Codex.STR.BUSY
	end
	local okc, ok, why = pcall(L.Check, st, mode)
	if not okc then
		return false, tostring(ok)
	end
	return ok == true, why
end

-- the save as it would load: P1 and P2 swapped when the page says so
function Codex.Effective(st, swap)
	local L = Codex.L
	if swap and L ~= nil and L.Reorder ~= nil and type(st) == "table" and type(st.players) == "table" and #st.players == 2 then
		return L.Reorder(st, { 2, 1 })
	end
	return st
end

-- swapping P1 / P2 makes sense: 2 saved players, 2 players now
function Codex.CanSwap(st)
	if type(st) ~= "table" or type(st.players) ~= "table" or #st.players ~= 2 then
		return false
	end
	local ok, list = pcall(Codex.LocalPlayers)
	return ok and type(list) == "table" and #list == 2
end

local function SavedName(p, i)
	return type(p) == "table" and type(p.name) == "string" and p.name ~= "" and p.name or ("player " .. i)
end

-- today's local players by player number: the load pairs the saved players
-- with them in this order (loader.lua L.Check)
function Codex.LocalPlayers()
	local C = require "savestates.capture"
	return C.LocalPlayers()
end

-- which saved player is the one looking at the page: the one the load would
-- give him (the same pairing), else the one with his player number
function Codex.ViewerIndex(players, viewer)
	if viewer == nil or type(players) ~= "table" or #players < 2 then
		return nil
	end
	local okl, list = pcall(Codex.LocalPlayers)
	if okl and type(list) == "table" and #list == #players then
		for i, p in ipairs(list) do
			if p == viewer then
				return i
			end
		end
	end
	local okid, id = pcall(function()
		return viewer.Network:GetPlayerID()
	end)
	if okid and id ~= nil then
		for i, p in ipairs(players) do
			if type(p) == "table" and p.player_id == id then
				return i
			end
		end
	end
	return nil
end

-- the order of the players' summaries: each player sees himself first
function Codex.PlayerOrder(players, viewer)
	local first = Codex.ViewerIndex(players, viewer)
	local order = {}
	if first ~= nil then
		order[1] = first
	end
	for i = 1, type(players) == "table" and #players or 0 do
		if i ~= first then
			order[#order + 1] = i
		end
	end
	return order
end

-- the room's icon as the dungeon map draws it (the game's own choice: a
-- fight shows its reward, a boss room its boss; util/mapgenhelp.lua
-- GetArtNameForRoom with the saved run's room and boss)
function Codex.RoomArt(st)
	local run = type(st) == "table" and type(st.run) == "table" and st.run or {}
	local wm = type(st) == "table" and type(st.worldmap) == "table" and st.worldmap or {}
	local mg = type(wm.mgrun_data) == "table" and wm.mgrun_data or {}
	local room = type(mg.current) == "table" and mg.current or { roomtype = run.roomtype, reward = run.reward, index = run.room_index }
	if room.roomtype == nil then
		return nil
	end
	local okh, MapGenHelp = pcall(require, "util.mapgenhelp")
	if not okh or type(MapGenHelp) ~= "table" or MapGenHelp.GetArtNameForRoom == nil then
		return nil
	end
	local run_view = {
		GetBoss = function()
			return mg.boss_prefab
		end,
		GetLocationId = function()
			return mg.location_id or run.location_id
		end,
	}
	local ok, key = pcall(MapGenHelp.GetArtNameForRoom, room, run_view)
	return ok and type(key) == "string" and key ~= "" and key or nil
end

-- ---------------------------------------------------------------------------
-- the page (widgets)

local W = {} -- the game's widget classes (set at install)

local function Colour(name, fallback)
	local ui = Global("UICOLORS")
	local c = type(ui) == "table" and ui[name] or nil
	return c or fallback or { 1, 1, 1, 1 }
end

local function FrenzyColour(info)
	if info.super then
		return Colour("SUPERFRENZY_TEXT_ACTIVE")
	end
	if info.level > 0 then
		return Colour("FRENZY_ACTIVE_TEXT_SHADOW")
	end
	return Colour("LIGHT_TEXT_DARKER")
end

local function HexToRGBSafe(hex)
	local fn = Global("HexToRGB")
	if fn ~= nil then
		return fn(hex)
	end
	return { 1, 1, 1, 1 }
end

local function FontSize(name, fallback)
	local f = Global("FONTSIZE")
	return type(f) == "table" and f[name] or fallback
end

local function NewText(size, text, colour)
	local fonts = Global("FONTFACE")
	return W.Text(fonts ~= nil and fonts.DEFAULT or nil, size, text or "", colour)
end

-- the hunt's shield: the map's badge for that hunt (its art for a main hunt, a
-- side hunt, Frenzy, Super Frenzy) with the hunt's icon on it, like the map
-- draws it (widgets/ftf/dungeonselection/maplocationmarker.lua)
function Codex.ShieldLook(info)
	local S = Codex.SHIELDS
	if info.sub then
		return info.level > 0 and S.sub_frenzy or S.sub, "BLACK"
	end
	if info.super then
		return S.super, "SUPERFRENZY_TEXT_ACTIVE"
	end
	if info.level > 0 then
		return S.frenzy, "BLACK"
	end
	return S.main, "BLACK"
end

-- the top band: the shield on the exploration badge's grey wings, the region's
-- ornament on both sides (the right one mirrored), the name, the Frenzy level.
-- (Made here, placed by Codex.LayoutHeader once it's in the band.)
function Codex.Header(st)
	local info = Codex.HeaderInfo(st)
	local h = W.Widget("Saved hunt header")
	local size = Codex.SHIELD_SIZE
	local shield, icon_colour = Codex.ShieldLook(info)
	h.wings = h:AddChild(W.Image(Codex.WINGS))
		:SetName("wings")
		:SetMultColor(HexToRGBSafe(0xA3897B77))
		:SetWidth_PreserveAspect(Codex.WINGS_SIZE)
	h.badge = h:AddChild(W.Image(shield))
		:SetName("hunt shield")
		:SetSize(size, size)
	h.icon = h.badge:AddChild(W.Image(info.icon or Codex.TAB_ICON))
		:SetName("hunt icon")
		:SetSize(size * Codex.SHIELD_ICON, size * Codex.SHIELD_ICON)
		:SetMultColor(Colour(icon_colour, { 0, 0, 0, 1 }))
		:SetPos(0, size * Codex.SHIELD_ICON_Y)
	if info.ornament ~= nil then
		h.orn_l = h:AddChild(W.Image(info.ornament)):SetName("ornament left")
			:SetMultColor(Colour("LIGHT_BACKGROUNDS_DARK"))
			:SetHeight_PreserveAspect(Codex.ORNAMENT_SIZE)
		-- the right one mirrored inside a holder that isn't: the game's
		-- LayoutBounds reads a mirrored widget's own bounds back to front, so a
		-- mirrored ornament put "after" the wings landed one width short, on
		-- the shield (seen in 0.1.6)
		h.orn_r = h:AddChild(W.Widget("ornament right"))
		h.orn_r.art = h.orn_r:AddChild(W.Image(info.ornament)):SetName("ornament right art")
			:SetMultColor(Colour("LIGHT_BACKGROUNDS_DARK"))
			:SetHeight_PreserveAspect(Codex.ORNAMENT_SIZE)
			:SetScale(-1, 1)
	end
	-- each side's text gets what's really left of the band: half the band, less
	-- half the wings, the ornament and the gaps (Codex.LayoutHeader), less the
	-- slanted end (a long name shrinks; 0.1.7 guessed the ornament's width and
	-- a long name ran over the band's end)
	local wings_w = tonumber((h.wings:GetSize())) or Codex.WINGS_SIZE
	local orn_w = h.orn_l ~= nil and (tonumber((h.orn_l:GetSize())) or 0) + 10 or 0
	local side = math.max(120, Codex.BAND_WIDTH / 2 - wings_w / 2 - orn_w - 14 - Codex.BAND_MARGIN)
	h.side = side
	local colour = FrenzyColour(info)
	local text_size = FontSize("SCREEN_TEXT", 40) * 1.2
	h.title = h:AddChild(NewText(text_size, info.name, colour)):SetName("hunt name")
		:ShrinkToFitWidth(side)
	h.frenzy = h:AddChild(NewText(text_size, info.frenzy, colour)):SetName("frenzy")
		:ShrinkToFitWidth(side)
	h.wings:MoveToBack()
	return h
end

-- the shield in the middle of the band, the rest around it
function Codex.LayoutHeader(h, band)
	h.badge:LayoutBounds("center", "center", band)
	h.wings:LayoutBounds("center", "center", h.badge):Offset(0, -Codex.WINGS_DROP)
	local left, right = h.wings, h.wings
	if h.orn_l ~= nil then
		h.orn_l:LayoutBounds("before", "center", h.wings):Offset(-10, 0)
		h.orn_r:LayoutBounds("after", "center", h.wings):Offset(10, 0)
		left, right = h.orn_l, h.orn_r
	end
	h.title:LayoutBounds("before", "center", left):Offset(-14, 0)
	h.frenzy:LayoutBounds("after", "center", right):Offset(14, 0)
	return h
end

-- the visible part of an icon's art (Codex.ART; the HUD's potions by name)
function Codex.ArtOf(tex)
	local a = Codex.ART[tex]
	if a ~= nil then
		return a
	end
	if type(tex) == "string" and tex:find("/icon_hud_", 1, true) then
		return Codex.HUD_POTION_ART
	end
	return { 0, 0, 1, 1, 1 }
end

-- An icon whose visible art is `height` tall (times its scale), in a box
-- just around that art (the picture itself doesn't count for the layout), so
-- boxes line up by what's seen.
function Codex.IconBox(parent, tex, height, name)
	local a = Codex.ArtOf(tex)
	local l, b, r, t, aspect = a[1], a[2], a[3], a[4], a[5] or 1
	height = height * (a[7] or 1)
	local th = height / math.max(0.05, t - b)
	local tw = th * aspect
	local box = parent:AddChild(W.Widget(name or "icon"))
	box:AddChild(W.Padding(math.max(1, (r - l) * tw), height))
	box.art_w, box.art_h = tw, th
	box.vis_h, box.sink = height, a[6] or 0
	box.art_x, box.art_y = -((l + r) / 2 - 0.5) * tw, -((b + t) / 2 - 0.5) * th
	box.art = box:AddChild(W.Image(tex)):SetName("art")
		:SetSize(tw, th)
		:SetHiddenBoundingBox(true)
		:SetPos(box.art_x, box.art_y)
	return box
end

-- The number after its icon, the icon standing on the digits' bottom line
-- (lowered by its sink); the stat as tall as Codex.STAT_LINE around its number,
-- so the row lines the numbers up.
local function OnLine(s, box, text, size)
	text:LayoutBounds("after", "center", box):Offset(Codex.STAT_ICON_GAP, 0)
	box:LayoutBounds(nil, "center", text):Offset(0, box.vis_h / 2 - size * Codex.DIGIT_HALF - box.sink * box.vis_h)
	s.line = s:AddChild(W.Padding(1, size * Codex.STAT_LINE))
	s.line:LayoutBounds("center", "center", text)
end

local function StatSize()
	return FontSize("SCREEN_TEXT", 40) * 1.1
end

local function Stat(parent, tex, text, name, tint)
	local s = parent:AddChild(W.Widget(name))
	local size = StatSize()
	s.icon_box = Codex.IconBox(s, tex, size * Codex.STAT_ICON, "icon")
	s.icon = s.icon_box.art
	if tint ~= nil then
		s.icon:SetMultColor(tint)
	end
	s.text = s:AddChild(NewText(size, text, Colour("LIGHT_TEXT_DARKER")))
	OnLine(s, s.icon_box, s.text, size)
	return s
end

local function Lives(parent, n, index)
	local s = parent:AddChild(W.Widget("extra lives"))
	local size = StatSize()
	local players = Colour("PLAYERS", {})
	s.icon_root = Codex.IconBox(s, Codex.ICONS.lives_wings, size * Codex.STAT_ICON, "lives icon")
	s.wings = s.icon_root.art:SetMultColor(players[index] or Colour("LIGHT_TEXT_DARK"))
	-- the plus is drawn on the wings' picture, the same size and place
	s.plus = s.icon_root:AddChild(W.Image(Codex.ICONS.lives_plus)):SetName("plus")
		:SetSize(s.icon_root.art_w, s.icon_root.art_h)
		:SetHiddenBoundingBox(true)
		:SetPos(s.icon_root.art_x, s.icon_root.art_y)
		:SetMultColor(HexToRGBSafe(0x7ce797ff))
	s.text = s:AddChild(NewText(size, tostring(n), Colour("LIGHT_TEXT_DARKER")))
	OnLine(s, s.icon_root, s.text, size)
	return s
end

-- for the full-screen Saved Hunts (fullscreen.lua): the same pieces
Codex.W = W
Codex.Colour = Colour
Codex.FontSize = FontSize
Codex.NewText = NewText
Codex.HexToRGBSafe = HexToRGBSafe
Codex.Stat = Stat
Codex.Lives = Lives
Codex.StatSize = StatSize

-- A game widget made and placed. If making it fails half way, the half-made
-- widget is placed and removed again: the game draws a widget that's never
-- placed in the middle of the screen, and can only remove a placed one.
-- (Klei's Class: an instance is a table with the class as its metatable,
-- then _ctor.)
function Codex.SafeChild(parent, cls, ...)
	local ctor = type(cls) == "table" and rawget(cls, "_ctor") or nil
	if type(ctor) ~= "function" then
		local ok, w = pcall(cls, ...)
		if ok then
			return parent:AddChild(w)
		end
		return nil, w
	end
	local obj = setmetatable({}, cls)
	local ok, err = pcall(ctor, obj, ...)
	if ok then
		return parent:AddChild(obj)
	end
	if rawget(obj, "inst") ~= nil and not rawget(obj, "removed") then
		pcall(function()
			if obj.parent == nil then
				parent:AddChild(obj)
			end
			obj:Remove()
		end)
	end
	return nil, err
end

-- a saved power as the game's item, if the game shows it: the HUD leaves out
-- the ones with show_in_ui off (lucky_revive, shield...) and the power icon
-- refuses one without an icon
function Codex.ShowablePower(rec)
	local item = D.deepcopy(rec)
	Codex.itemforge.ConvertToRuntimeItem(item)
	local def = item:GetDef()
	if type(def) ~= "table" or not def.show_in_ui or def.icon == nil then
		return nil
	end
	return item
end

-- Where a power's tooltip goes: always on the same side of the icon (towards
-- the middle of the screen). The game's tooltip picks its side by its size,
-- but the power tooltip's keyword box only shows after that, so it was put on
-- the right, measured again with the box, and moved to the left.
function Codex.PowerTooltipLayout(focus, tooltip)
	local x1, _, x2 = focus:GetVirtualBoundingBox()
	local side = (x1 ~= nil and x2 ~= nil and (x1 + x2) / 2 > 0) and "before" or "after"
	if tooltip.OnLayout ~= nil then
		tooltip:OnLayout(side, "top")
	end
	tooltip:LayoutBounds(side, "top", focus)
end

-- one player's summary (the Codex's page: a column)
function Codex.PlayerRow(panel, p, i)
	local info = Codex.PlayerInfo(p, i)
	local row = W.Widget("Player " .. i)
	Codex.PlayerWho(row, info)
	Codex.PlayerStats(row, info)
	Codex.PlayerPowers(row, info, panel:GetOwningPlayer(), Codex.POWERS_PER_ROW)
	row:LayoutChildrenInColumn(10, "center")
	return row
end

-- the two weapon classes around "P1", the character's name
function Codex.PlayerWho(row, info)
	local muted = Colour("LIGHT_TEXT_DARK")
	local who = row:AddChild(W.Widget("who"))
	local big = FontSize("SCREEN_TEXT_LARGE", 50) * 1.2
	local held = Codex.WeaponTex(info.held)
	local other = Codex.WeaponTex(info.other)
	if held ~= nil then
		who:AddChild(W.Image(held)):SetName("held weapon"):SetSize(big, big):SetMultColor(muted)
	end
	who:AddChild(NewText(big, "P" .. info.index, muted)):SetName("player number")
	if other ~= nil then
		who:AddChild(W.Image(other)):SetName("other weapon"):SetSize(big, big):SetMultColor(muted)
	end
	if info.name ~= nil then
		who.character = who:AddChild(NewText(FontSize("SCREEN_TEXT", 40), info.name, muted)):SetName("character")
	end
	who:LayoutChildrenInRow(24, "center")
	return who
end

-- HP, extra lives, Teffra, rerolls, potions
function Codex.PlayerStats(row, info)
	local stats = row:AddChild(W.Widget("stats"))
	Stat(stats, Codex.ICONS.hp, string.format("%d/%d", info.hp, info.hp_max), "health", Colour("LIGHT_TEXT_DARKER"))
	if info.lives ~= nil then
		Lives(stats, info.lives, info.index)
	end
	Stat(stats, Codex.ICONS.konjur, tostring(info.konjur), "teffra")
	Stat(stats, Codex.ICONS.rerolls, tostring(info.rerolls), "rerolls")
	if info.potions ~= nil then
		Stat(stats, Codex.PotionTex(info.potion_id, info.potions), tostring(info.potions), "potions")
	end
	stats:LayoutChildrenInRow(Codex.STAT_GAP, "center") -- (every stat as tall around its number: the numbers line up)
	return stats
end

-- the run's powers the game shows (its icons: frame, counter, tooltip), so
-- many to a row; nil when it shows none
function Codex.PlayerPowers(row, info, owner, per_row)
	local shown = {}
	for _, rec in ipairs(info.powers) do
		local ok, item = pcall(Codex.ShowablePower, rec)
		if not ok then
			Log("power " .. tostring(rec.id) .. ": " .. tostring(item)) -- (a power that's gone from the game: skipped)
		elseif item ~= nil then
			shown[#shown + 1] = item
		end
	end
	if #shown == 0 then
		return nil
	end
	do
		local grid = row:AddChild(W.Widget("powers"))
		for _, item in ipairs(shown) do
			local w, err = Codex.SafeChild(grid, W.PowerWidget, Codex.POWER_SIZE, owner, item)
			if w ~= nil then
				w:SetNavFocusable(true)
				w:ShowToolTipOnFocus(true)
				w:SetToolTipLayoutFn(Codex.PowerTooltipLayout)
			else
				Log("power " .. tostring(item.id) .. ": " .. tostring(err))
			end
		end
		grid:LayoutChildrenInGrid(per_row or Codex.POWERS_PER_ROW, Codex.POWER_GAP)
		return grid
	end
end

-- the room line: its map icon (tinted like the hunt's map) and what it was
function Codex.RoomRow(st, meta)
	local row = W.Widget("room")
	local key = Codex.RoomArt(st)
	if key ~= nil and W.MapRoom ~= nil then
		local icon, err = Codex.SafeChild(row, W.MapRoom)
		if icon ~= nil then
			local ok, e = pcall(function()
				icon:SetName("room icon")
				icon:SetRoomIcons({ roomtype = key })
				local loc = Codex.Location(type(st.run) == "table" and st.run.location_id or nil)
				local tint = loc ~= nil and type(loc.map_colors) == "table" and loc.map_colors.room_tint or nil
				if tint ~= nil then
					icon:SetMultColor(tint)
				end
				-- (the icon has its size once its picture is set, like the map does)
				local _, h = icon:GetSize()
				h = tonumber(h)
				icon:SetScale(h ~= nil and h > 1 and math.min(2, Codex.ROOM_ICON / h) or 0.5)
				row.icon = icon
			end)
			if not ok then
				Log("room icon " .. tostring(key) .. ": " .. tostring(e))
				icon:Remove()
				row.icon = nil
			end
		else
			Log("room icon: " .. tostring(err))
		end
	end
	row.text = row:AddChild(NewText(FontSize("SCREEN_TEXT", 40) * 0.9, table.concat(Codex.RoomLines(st, meta), "\n"), Colour("LIGHT_TEXT_DARK")))
		:SetName("room text")
	row:LayoutChildrenInRow(18, "center")
	return row
end

-- ---------------------------------------------------------------------------
-- the page's class (a Codex details panel)
--
-- A slot's page is drawn once and kept (hidden while another shows) until the
-- Codex closes or the list changes, so moving through the list only shows and
-- hides pages. A slot the focus only passes over isn't drawn: its page is
-- drawn once the focus stays on it (Codex.SETTLE), or right away when picked.

local Page = {} -- the page's methods (guarded by the class's wrappers)

function Page.CancelPending(self)
	if self.pending ~= nil then
		local job = self.pending
		self.pending = nil
		Codex.CancelJob(job)
	end
end

-- fn once t seconds have gone on the UI's own clock: the game's widget
-- updater (it runs while the game is paused; a DoTaskInTime waits for the
-- game, so over the pause menu a slot's page never came). The job, to call off.
function Codex.After(widget, t, fn)
	local req = G().require or require
	local Updater = req "ui.updater"
	local updater = Updater.Series({ Updater.Wait(t), Updater.Do(fn) })
	widget:RunUpdater(updater)
	return { widget = widget, updater = updater }
end

function Codex.CancelJob(job)
	pcall(function()
		job.widget:StopUpdater(job.updater)
	end)
end

-- everything on the right goes (a new list, the store not ready)
function Page.ClearDetails(self)
	Page.CancelPending(self)
	self.detail_contents:RemoveAllChildren()
	self.pages = {}
	self.message = nil
	self.current_id = nil
	self.wanted = nil
end

function Page.HideAll(self)
	for _, page in pairs(self.pages or {}) do
		page.root:Hide()
	end
	if self.message ~= nil then
		self.message:Hide()
	end
end

-- the details placed under the tabs (like the Codex's own pages)
function Page.Place(self)
	self.detail_contents:LayoutBounds("center", "top", self.right_bg)
	self.detail_scroll:RefreshView()
end

function Page.Message(self, text)
	Page.HideAll(self)
	if self.message == nil then
		local m = self.detail_contents:AddChild(W.Widget("message"))
		m:AddChild(W.Padding(100, 60))
		m.line = m:AddChild(NewText(FontSize("SCREEN_TEXT", 40), "", Colour("LIGHT_TEXT_DARK")))
			:SetName("message text")
		self.message = m
	end
	self.message.line:SetText(text)
	self.message:LayoutChildrenInColumn(5, "center")
	self.message:Show()
	self.current_id = nil
	Page.Place(self)
	Page.SetLoad(self, nil)
end

-- the LOAD button, the swap button and the line over them
function Page.SetLoad(self, data, st)
	self.load = nil
	self.load_data, self.load_st = data, st
	if data == nil or st == nil then
		self.load_btn:Hide()
		self.can_swap = false
		self.load_note:SetText("")
		Page.Hints(self)
		return
	end
	local can_swap = Codex.CanSwap(st)
	if not can_swap then
		self.swap = false
	end
	local eff = Codex.Effective(st, self.swap)
	local order = self.swap and { 2, 1 } or nil
	local ok, mode, note = Codex.LoadChoice(eff)
	self.save_job = nil
	if self.load_btn.text ~= nil and self.load_btn.text ~= Codex.STR.LOAD then
		self.load_btn:SetTextAndResizeToFit(Codex.STR.LOAD, 60, nil, (Global("BUTTON_W") or 580) * Codex.LOAD_SIZE, (Global("BUTTON_H") or 140) * Codex.LOAD_SIZE)
	end
	self.load_btn:Show()
	if ok then
		self.load_btn:Enable()
		self.load = { id = data.id, mode = mode, label = data.label, order = order }
	else
		self.load_btn:Disable()
	end
	-- Swap P1 / P2: Y only (its hint at the bottom says which way it is)
	self.can_swap = can_swap
	local lines = {}
	if note ~= nil and note ~= "" then
		lines[#lines + 1] = note
	end
	if self.swap then
		lines[#lines + 1] = string.format(Codex.STR.SWAPPED, SavedName(st.players[2], 2), SavedName(st.players[1], 1))
	elseif can_swap and Codex.L.LooksSwapped ~= nil and Codex.L.LooksSwapped(st) then
		lines[#lines + 1] = Codex.STR.SWAP_SUGGEST
	end
	self.load_note:SetText(table.concat(lines, "\n"))
	self.load_note:SetGlyphColor(ok and Colour("LIGHT_TEXT_DARK") or Colour("RED", { 0.8, 0.2, 0.2, 1 }))
	Page.LayoutLoad(self)
	Page.Hints(self)
end

function Page.LayoutLoad(self)
	self.load_btn:LayoutBounds("center", "bottom", self.right_bg):Offset(0, 30)
	self.load_note:LayoutBounds("center", "above", self.load_btn):Offset(0, 10)
end

-- Swap P1 / P2 for this page's loads (2 players): the save's player 1 goes to
-- today's player 2 and back (when the characters came in the other order)
function Page.ToggleSwap(self)
	if self.load_st == nil or not Codex.CanSwap(self.load_st) then
		return false
	end
	self.swap = not self.swap
	Page.SetLoad(self, self.load_data, self.load_st)
	return true
end

-- LS / RS: load the save shown with that mode (Replicate / Rebuild)
function Page.LoadForced(self, mode)
	local data, st = self.load_data, self.load_st
	if data == nil or st == nil or self.save_job ~= nil then
		return false
	end
	local ok, why = Codex.LoadChoiceFor(Codex.Effective(st, self.swap), mode)
	if not ok then
		local name = mode == "replicate" and Codex.STR.MODE_REPLICATE or Codex.STR.MODE_REBUILD
		self.load_note:SetText(string.format(Codex.STR.FORCED_CANT, name, tostring(why)))
		self.load_note:SetGlyphColor(Colour("RED", { 0.8, 0.2, 0.2, 1 }))
		Page.LayoutLoad(self)
		return true
	end
	self.load = { id = data.id, mode = mode, label = data.label, order = self.swap and { 2, 1 } or nil }
	Page.Load(self)
	return true
end

-- the button hints at the bottom (gamepad): the Codex's own, then ours
function Page.Hints(self)
	if self.inst == nil or not self.inst:IsValid() then
		return
	end
	pcall(self._RefreshHotkeys, self, self.last_focus)
end

local function PageKey(data)
	return tostring(data.id) .. "@" .. tostring(type(data.meta) == "table" and data.meta.time or "")
end
Codex.PageKey = PageKey
Codex.SavedName = SavedName

local function Tick(self)
	self.tick = (self.tick or 0) + 1
	return self.tick
end

-- a slot's page (the Codex's slot panel with the band on top)
function Page.Fill(self, page, data, st)
	page:AddChild(W.Padding(100, 20))
	local root = page:AddChild(W.SlotContentsPanel({ no_scroll = true, no_focus_lock = true, slots_height = Codex.BAND_HEIGHT }))
		:SetName("Saved hunt")
		:Layout()
	local header = root.slots_container:AddChild(Codex.Header(st))
	local column = root:GetListRoot():AddChild(W.Widget("Saved hunt players"))
	local players = type(st.players) == "table" and st.players or {}
	-- each player sees himself first (P1 and P2 swap on P2's Codex)
	for n, i in ipairs(Codex.PlayerOrder(players, self:GetOwningPlayer())) do
		if n > 1 then
			column:AddChild(W.Image(Codex.DIVIDER)):SetName("divider"):SetMultColor(Colour("LIGHT_BACKGROUNDS_DARK"))
		end
		column:AddChild(Codex.PlayerRow(self, players[i], i))
	end
	if #players > 0 then
		column:AddChild(W.Image(Codex.DIVIDER)):SetName("divider"):SetMultColor(Colour("LIGHT_BACKGROUNDS_DARK"))
	end
	column:AddChild(Codex.RoomRow(st, data.meta))
	column:LayoutChildrenInColumn(20, "center")
	-- under the band, in the middle (the Codex's region page lays its rows the same way)
	column:LayoutBounds("center", "below", root.list_overlay):Offset(0, -20)
	root:ResizeListBg(50)
	Codex.LayoutHeader(header, root.slots_list_bg)
	root:SelectSlot(header.badge)
	page:LayoutChildrenInColumn(5, "center")
end

function Page.Draw(self, data, st)
	local page = self.detail_contents:AddChild(W.Widget("Saved hunt page"))
	page:Hide()
	local ok, err = pcall(Page.Fill, self, page, data, st)
	if not ok then
		page:Remove()
		error(err, 0)
	end
	local entry = { root = page, st = st, key = PageKey(data), used = Tick(self) }
	self.pages[data.id] = entry
	-- a few are kept: the one shown longest ago goes
	local n, oldest_id, oldest = 0, nil, nil
	for id, p in pairs(self.pages) do
		n = n + 1
		if id ~= data.id and (oldest == nil or p.used < oldest.used) then
			oldest_id, oldest = id, p
		end
	end
	if n > Codex.PAGES_KEPT and oldest ~= nil then
		self.pages[oldest_id] = nil
		oldest.root:Remove()
	end
	return entry
end

function Page.Cached(self, data)
	local entry = self.pages[data.id]
	if entry == nil then
		return nil
	end
	if entry.key == PageKey(data) and not entry.root.removed then
		return entry
	end
	self.pages[data.id] = nil
	if not entry.root.removed then
		entry.root:Remove()
	end
	return nil
end

function Page.ShowPage(self, entry, data)
	Page.HideAll(self)
	entry.root:Show()
	entry.used = Tick(self)
	self.current_id = data.id
	Page.Place(self)
	if not Page.SetSave(self, data, entry.st) then
		Page.SetLoad(self, data, entry.st)
	end
end

function Page.BuildSlot(self, data)
	local L = Codex.L
	self.wanted = data
	local done = false
	L.store:Get(data.id, function(st)
		done = true
		if self.wanted ~= data or not self.inst:IsValid() then
			return -- (another slot was picked meanwhile)
		end
		if type(st) ~= "table" or type(st.run) ~= "table" then
			Page.Message(self, Codex.STR.UNREADABLE)
			self.current_id = data.id
			return
		end
		local ok, entry = pcall(Page.Draw, self, data, st)
		if not ok then
			Log(tostring(entry))
			Page.Message(self, Codex.STR.ERROR)
			self.current_id = data.id
			return
		end
		Page.ShowPage(self, entry, data)
	end)
	if not done then
		Page.Message(self, Codex.STR.LOADING)
		self.current_id = data.id
	end
end

-- save view: an empty slot's page (the line, and SAVE)
function Page.ShowEmpty(self, data)
	Page.CancelPending(self)
	self.wanted = data
	Page.Message(self, string.format(Codex.STR.EMPTY_PAGE, data.slot))
	self.current_id = "empty" .. tostring(data.slot)
	Page.SetSave(self, data, nil)
end

-- save view: the main button saves this room into the slot (slots 1-10)
function Page.SetSave(self, data, st)
	self.save_job = nil
	local L = Codex.L
	local slot = data ~= nil and data.slot or nil
	if self.view == nil or self.view.mode ~= "save" or type(slot) ~= "number" or slot < 1 then
		return false
	end
	local C = require "savestates.capture"
	local okc, can, why = pcall(C.CanSave)
	local text = string.format(data.empty and Codex.STR.SAVE_TO or Codex.STR.OVERWRITE, slot)
	self.load_btn:SetTextAndResizeToFit(text, 60, nil, (Global("BUTTON_W") or 580) * Codex.LOAD_SIZE, (Global("BUTTON_H") or 140) * Codex.LOAD_SIZE)
	self.load_btn:Show()
	self.can_swap = false
	self.load = nil
	if okc and can and L ~= nil and not L.busy then
		self.load_btn:Enable()
		self.save_job = { slot = slot }
		self.load_note:SetText(self.saved_note or "")
		self.load_note:SetGlyphColor(Colour("LIGHT_TEXT_DARK"))
	else
		self.load_btn:Disable()
		self.load_note:SetText(string.format(Codex.STR.CANT_SAVE, tostring(okc and (why or Codex.STR.BUSY) or can)))
		self.load_note:SetGlyphColor(Colour("RED", { 0.8, 0.2, 0.2, 1 }))
	end
	self.saved_note = nil
	Page.LayoutLoad(self)
	Page.Hints(self)
	return true
end

-- the main button: SAVE (save view, a slot) or LOAD, for the slot picked
-- (the mouse passing over other slots on its way here showed theirs)
function Page.Primary(self)
	local last = self.last_clicked
	if last ~= nil and last.data ~= nil then
		local want = last.data.empty and ("empty" .. tostring(last.data.slot)) or last.data.id
		if self.current_id ~= want then
			Page.ShowSlot(self, last.data, true)
		end
	end
	if self.save_job ~= nil then
		return Page.SaveSlot(self)
	end
	return Page.Load(self)
end

-- SAVE: this room into the slot; the list and its page come back with it
function Page.SaveSlot(self)
	local job = self.save_job
	local L = Codex.L
	if job == nil or L == nil then
		return
	end
	self.save_job = nil
	self.load_btn:Disable()
	L.Save(job.slot, function(ok, why)
		if not self.inst:IsValid() then
			return
		end
		SS.Call("Saved Hunts saved", Page.AfterSave, self, job.slot, ok, why)
	end)
end

function Page.AfterSave(self, slot, ok, why)
	self.list_key = nil
	self:Refresh()
	for _, row in ipairs(self.list_contents:GetChildren() or {}) do
		local data = row.saved_hunt
		if data ~= nil and data.slot == slot and not data.history then
			-- (the new list may have shown its first slot already: this one again)
			self.current_id = nil
			self.saved_note = ok and string.format(Codex.STR.SAVED_NOTE, slot) or string.format(Codex.STR.NOT_SAVED, tostring(why))
			Page.Clicked(self, data, row)
			return
		end
	end
end

-- show a slot: its kept page right away; a new one once the focus stays (or now)
function Page.ShowSlot(self, data, now)
	if data == nil then
		return
	end
	if data.empty then
		return Page.ShowEmpty(self, data)
	end
	Page.CancelPending(self)
	self.wanted = data
	if self.current_id == data.id then
		return
	end
	local entry = Page.Cached(self, data)
	if entry ~= nil then
		Page.ShowPage(self, entry, data)
		return
	end
	if not now and Codex.SETTLE > 0 then
		local job
		local ok = pcall(function()
			job = Codex.After(self, Codex.SETTLE, function()
				if self.pending == job then
					self.pending = nil
				end
				if self.wanted == data then
					SS.Call("Saved Hunts", Page.BuildSlot, self, data)
				end
			end)
		end)
		if ok and job ~= nil then
			self.pending = job
			return
		end
	end
	Page.BuildSlot(self, data)
end

local function ListKey(slots)
	local parts = {}
	for _, s in ipairs(slots) do
		parts[#parts + 1] = PageKey(s) .. "=" .. tostring(s.pretty_name)
	end
	return table.concat(parts, ";")
end
Codex.ListKey = ListKey

function Page.Refresh(self)
	local L = Codex.L
	if L == nil or L.store == nil or not L.store.loaded then
		self.list_key = nil
		self.list_contents:RemoveAllChildren()
		Page.ClearDetails(self)
		Page.Message(self, Codex.STR.STORE_LOADING)
		return nil
	end
	local slots = Codex.Slots(L.store, self.view)
	local key = ListKey(slots)
	if key == self.list_key and self.list_contents:GetFirstChild() ~= nil then
		-- the same saves: the list and the pages drawn stay (like the Codex's region list)
		return self:FindDefaultFocus()
	end
	self.list_key = key
	self.slots = slots
	Page.ClearDetails(self)
	if #slots == 0 then
		self.list_contents:RemoveAllChildren()
		self.last_clicked = {}
		Page.Message(self, Codex.STR.EMPTY)
		return nil
	end
	local function SetupButton(btn, data)
		btn.saved_hunt = data
		if data.ornament ~= nil then
			btn.ornament = btn:AddChild(W.Image(data.ornament))
				:SetName("region ornament")
				:SetHeight_PreserveAspect(btn.height * 0.55)
				:SetMultColor(Colour("LIGHT_TEXT_DARKER"))
			btn.ornament:LayoutBounds("right", "center", btn.btn_bg):Offset(-26, 0)
			local ow = btn.ornament:GetSize()
			btn.label:SetRegionSize(btn.width - (ow or 40) - 70, btn.height)
			btn.label:RefreshText() -- (shrinks the name to the narrower room)
			btn.label:LayoutBounds("left", "center", btn.btn_bg):Offset(24, 0)
				:LeftAlign()
		end
		btn:SetOnClickFn(function()
			SS.Call("Saved Hunts", Page.Clicked, self, data, btn)
		end)
		btn:SetOnGainFocus(function()
			SS.Call("Saved Hunts", Page.ShowSlot, self, data)
		end)
	end
	return self:_SetupListViewFromData(slots, SetupButton)
end

function Page.Clicked(self, data, btn)
	self:_ChangeSelection(self.last_clicked and self.last_clicked.btn, btn)
	self.last_clicked = { btn = btn, data = data }
	Page.ShowSlot(self, data, true)
	if self:IsRelativeNavigation() and self.load_btn:IsShown() and self.load_btn:IsEnabled() then
		self.load_btn:SetFocus(self:GetOwningUser():GetId())
	end
end

-- A load from a menu: the menu closes, and the pause menu under it too, so
-- the game runs again. (A load waits for the game's clock: 0.3.x left the
-- pause menu open and the load only started once you closed it. The game's
-- own "return to town" unpauses the same way before it starts.)
function Codex.LeaveForLoad(screen)
	local fe = Global("TheFrontEnd")
	if fe == nil then
		return
	end
	if screen ~= nil then
		fe:PopScreen(screen)
	end
	if fe.GetActiveScreen == nil then
		return
	end
	local ok, err = pcall(function()
		local top = fe:GetActiveScreen()
		local P = Codex.PauseScreen
		if top ~= nil and ((P ~= nil and getmetatable(top) == P) or rawget(top, "_widgetname") == "PauseScreen") then
			if top.Unpause ~= nil then
				top:Unpause()
			else
				fe:PopScreen(top)
			end
		end
	end)
	if not ok then
		Log("the pause menu stays open (the load starts when it closes): " .. tostring(err))
	end
end

-- the load, next frame: only the latest one asked for (pressing again while
-- one waits replaces it; a second load never runs after the first)
Codex.queued_load = nil
function Codex.QueueLoad(job)
	local L = Codex.L
	if job == nil or L == nil then
		return
	end
	Codex.queued_load = job
	local function Go()
		local j = Codex.queued_load
		Codex.queued_load = nil
		if j ~= nil then
			L.LoadId(j.id, j.mode, j.label, { order = j.order })
		end
	end
	local gi = Global("TheGlobalInstance")
	if gi ~= nil and gi.DoTaskInTime ~= nil then
		gi:DoTaskInTime(0, function()
			SS.Call("Saved Hunts load", Go)
		end)
	else
		Go()
	end
end

-- LOAD: the Codex closes (and the pause menu), then the load starts (the game's run start)
function Page.Load(self)
	local job = self.load
	local L = Codex.L
	if job == nil or L == nil then
		return
	end
	self.load = nil
	Codex.LeaveForLoad(self:GetScreen())
	Codex.QueueLoad(job)
end

function Codex.MakePageClass(DetailsPanel)
	local PANEL_INNER_HEIGHT = Codex.Upvalue(DetailsPanel._CreateDetailScroll, "PANEL_INNER_HEIGHT") or 820
	local PageClass = Class(DetailsPanel, function(self, main_panel)
		DetailsPanel._ctor(self, "SavedHuntsPanel", main_panel)
		self.detail_scroll = self.content:AddChild(self:_CreateDetailScroll("Saved hunt scroll"))
			:SetSize(self.detail_width + 15, PANEL_INNER_HEIGHT - Codex.LOAD_AREA)
		self.detail_contents = self.detail_scroll:AddScrollChild(W.Widget("Saved hunt contents"))
		self.load_btn = self.content:AddChild(W.ActionButton())
			:SetName("LOAD")
			:SetPrimary()
		self.load_btn:SetTextAndResizeToFit(Codex.STR.LOAD, 60, nil, (Global("BUTTON_W") or 580) * Codex.LOAD_SIZE, (Global("BUTTON_H") or 140) * Codex.LOAD_SIZE)
		self.load_btn:SetOnClick(function()
			SS.Call("Saved Hunts LOAD", Page.Primary, self)
		end)
		self.load_btn:SetNavFocusable(true)
		self.load_btn:Hide()
		self.load_note = self.content:AddChild(NewText(FontSize("SCREEN_TEXT", 40) * 0.9, "", Colour("LIGHT_TEXT_DARK")))
			:SetName("load note")
			:ShrinkToFitWidth(self.detail_width - 80)
		-- Swap P1 / P2 (2 players): Y (MENU_UNCOMMON), no button
		self.can_swap = false
		self.swap = false
		self.last_clicked = {}
		self.pages = {}
	end)

	-- the Codex's own controls, then: RS loads with Rebuild, LS with
	-- Replicate (the save shown), Y swaps P1 / P2 (CONTROL_MAP: on release)
	local map = {}
	for _, entry in ipairs(DetailsPanel.CONTROL_MAP or {}) do
		map[#map + 1] = entry
	end
	local digital = Codex.Controls ~= nil and Codex.Controls.Digital or nil
	if digital ~= nil then
		local rs = rawget(digital, "RADIAL_ACTION")
		if rs ~= nil then
			map[#map + 1] = { control = rs, fn = function(self)
				local ok, used = pcall(Page.LoadForced, self, "rebuild")
				return ok and used
			end }
		end
		local ls = rawget(digital, Codex.LS_CONTROL)
		if ls ~= nil then
			map[#map + 1] = { control = ls, fn = function(self)
				local ok, used = pcall(Page.LoadForced, self, "replicate")
				return ok and used
			end }
		end
		local y = rawget(digital, "MENU_UNCOMMON")
		if y ~= nil then
			map[#map + 1] = { control = y, fn = function(self)
				if not self.can_swap then
					return false
				end
				local ok, used = pcall(Page.ToggleSwap, self)
				return ok and used
			end }
		end
	end
	if digital ~= nil then
		local lt, rt = rawget(digital, "MENU_SUB_TAB_PREV"), rawget(digital, "MENU_SUB_TAB_NEXT")
		if lt ~= nil and rt ~= nil then
			-- both triggers: one let go while the other is held
			map[#map + 1] = { control_list = { lt, rt }, fn = function(self, device)
				local input = Global("TheInput")
				if input == nil or input.IsControlDownOnAnyDevice == nil then
					return false
				end
				local other_held = input:IsControlDownOnAnyDevice(lt) or input:IsControlDownOnAnyDevice(rt)
				if not other_held then
					return false
				end
				local single = self.main_panel
				local ok = pcall(Codex.SetHistoryTabs, single, single.savestates_history == nil)
				return ok
			end }
		end
	end
	PageClass.CONTROL_MAP = map

	-- the hints: the Codex's own (back to the list) and the load buttons
	function PageClass:_RefreshHotkeys(focus_widget)
		self.last_focus = focus_widget
		local ok, err = pcall(function()
			if self.main_panel:GetTopPopup() then
				return -- (hidden under a popup)
			end
			local hotkeys = {}
			local d = Codex.Controls.Digital
			if self:IsUsingGamepad() and self:IsShown() then
				if not focus_widget or not self.list_contents:IsAncestorOf(focus_widget) then
					hotkeys[#hotkeys + 1] = { control = d.CANCEL, label = Global("STRINGS").UI.CODEXSCREEN.BACK_TO_LIST }
				end
				if self.load_data ~= nil and self.load_btn:IsShown() then
					if rawget(d, Codex.LS_CONTROL) ~= nil then
						hotkeys[#hotkeys + 1] = { control = rawget(d, Codex.LS_CONTROL), label = Codex.STR.HINT_REPLICATE }
					end
					hotkeys[#hotkeys + 1] = { control = d.RADIAL_ACTION, label = Codex.STR.HINT_REBUILD }
					if self.can_swap then
						hotkeys[#hotkeys + 1] = { control = d.MENU_UNCOMMON, label = self.swap and Codex.STR.SWAP_ON or Codex.STR.HINT_SWAP }
					end
				end
			end
			self.main_panel:SetHotkeys(hotkeys)
		end)
		if not ok then
			Log("hints: " .. tostring(err))
			pcall(PageClass._base._RefreshHotkeys, self, focus_widget)
		end
	end

	function PageClass:FindDefaultFocus()
		local last = self.last_clicked
		if last ~= nil and last.btn ~= nil and last.btn.inst ~= nil and last.btn.inst:IsValid() then
			return last.btn
		end
		local first = self.list_contents:GetFirstChild()
		if first ~= nil then
			return first
		end
		-- 0.5.1: an empty list (no saved hunts yet, or still loading): nothing
		-- of ours to focus, and the Codex opens on this tab, so the focus went
		-- nowhere and the gamepad could do nothing (softlock). The Codex
		-- panel itself instead: the game's own fallback
		-- (CodexScreenSingle:FindDefaultFocus), so the tabs and back work.
		return self.main_panel
	end

	function PageClass:OnFocusChanged(new_focus, _show_immediately)
		local ok, err = pcall(function()
			local last = self.last_clicked
			if last ~= nil and last.data ~= nil and self.current_id ~= last.data.id
				and (not new_focus or not self.list_contents:IsAncestorOf(new_focus)) then
				-- the list lost the focus: back to the slot picked
				Page.ShowSlot(self, last.data, true)
			end
			self:_RefreshHotkeys(new_focus)
		end)
		if not ok then
			Log(tostring(err))
		end
	end

	function PageClass:Refresh()
		local ok, res = pcall(Page.Refresh, self)
		if not ok then
			Log(tostring(res))
			pcall(Page.Message, self, Codex.STR.ERROR)
			return nil
		end
		return res
	end

	function PageClass:Layout()
		PageClass._base.Layout(self)
		self.detail_scroll:LayoutBounds("left", "top", self.right_bg)
		pcall(Page.LayoutLoad, self)
		return self
	end

	Codex.Page = Page
	return PageClass
end

-- ---------------------------------------------------------------------------
-- finding the Codex's pieces, adding the tab

function Codex.Upvalue(fn, name)
	local dbg = rawget(G(), "debug") or rawget(_G, "debug")
	if type(fn) ~= "function" or dbg == nil or dbg.getupvalue == nil then
		return nil
	end
	for i = 1, 255 do
		local n, v = dbg.getupvalue(fn, i)
		if n == nil then
			return nil
		end
		if n == name then
			return v
		end
	end
	return nil
end

local function Need(cond, what)
	if not cond then
		error("a game update changed " .. what, 0)
	end
end

-- the Codex's per-player panel and its details panel (local classes in
-- codexscreenmulti.lua, reached through the functions that use them)
function Codex.FindClasses(CodexScreenMulti)
	Need(type(CodexScreenMulti) == "table" and type(CodexScreenMulti.CreatePanelAsPopup) == "function", "the Codex screen")
	local Single = Codex.Upvalue(CodexScreenMulti.CreatePanelAsPopup, "CodexScreenSingle")
	Need(type(Single) == "table" and type(Single._ctor) == "function" and type(Single._GoToPanel) == "function"
		and type(Single.OnTabClicked) == "function", "the Codex's panel")
	local RegionPanel = Codex.Upvalue(Single._ctor, "RegionPanel")
	Need(type(RegionPanel) == "table", "the Codex's region page")
	local DetailsPanel = RegionPanel._base
	Need(type(DetailsPanel) == "table" and type(DetailsPanel._ctor) == "function"
		and type(DetailsPanel._SetupListViewFromData) == "function" and type(DetailsPanel._CreateDetailScroll) == "function"
		and type(DetailsPanel._ChangeSelection) == "function" and type(DetailsPanel._RefreshHotkeys) == "function"
		and type(DetailsPanel.ShowPanel) == "function" and type(DetailsPanel.Layout) == "function", "the Codex's page")
	return Single, DetailsPanel
end

-- the tab and its page on one Codex panel (after the game built it)
function Codex.AddTo(single, PageClass)
	Need(type(single.panels) == "table" and single.tab_group ~= nil and single.tab_group.AddTab ~= nil, "the Codex's tabs")
	local page = single:AddChild(PageClass(single))
	page:Hide()
	page.view = Codex.view
	Codex.open_pages[page] = true
	local tg = single.tab_group
	local okt, tab = pcall(function()
		return tg:AddTab(Codex.TAB_ICON, Codex.STR.TITLE, 70, 60):HideBg()
	end)
	if not okt or tab == nil then
		page:Remove()
		error(tostring(tab), 0)
	end
	tab.target_panel = Codex.KEY
	single.panels[Codex.KEY] = page
	if Codex.settings.first or page.view ~= nil then
		-- first in the row (and the one the Codex opens on)
		pcall(function()
			local tabs = tg.tabs
			if tabs[#tabs] == tab then
				table.remove(tabs, #tabs)
				table.insert(tabs, 1, tab)
				local kids = tg.tabs_container.children
				for i, k in ipairs(kids) do
					if k == tab then
						table.remove(kids, i)
						table.insert(kids, 1, tab)
						break
					end
				end
			end
		end)
	end
	pcall(function() tg:Layout() end)
	if single.nameplate ~= nil then
		single.nameplate:SendToFront()
	end
	if single.tabs_container ~= nil then
		single.tabs_container:SendToFront()
	end
	if single.hotkeys ~= nil then
		single.hotkeys:SendToFront()
	end
	if page.view ~= nil and page.view.history then
		pcall(Codex.SetHistoryTabs, single, true)
	end
	return page, tab
end

-- The two hidden tabs (debugging, a crash): Manual history and Auto history,
-- every save kept. Only Ctrl+Shift+Alt+1 or both triggers bring them, for
-- that Codex; they go again with it (no Codex ever opens with them).
function Codex.SetHistoryTabs(single, on)
	local tg = single.tab_group
	local PageClass = Codex.PageClass
	if tg == nil or PageClass == nil then
		return false
	end
	local shown = single.savestates_history ~= nil
	if on == shown then
		return shown
	end
	if on then
		local made = {}
		for _, h in ipairs(Codex.HISTORY_TABS) do
			Codex.view = { mode = h.mode }
			local okp, page = pcall(function() return single:AddChild(PageClass(single)) end)
			Codex.view = nil
			if okp and page ~= nil then
				page:Hide()
				page.view = { mode = h.mode }
				Codex.open_pages[page] = true
				local okt, tab = pcall(function()
					return tg:AddTab(Codex.TAB_ICON, h.title, 70, 60):HideBg()
				end)
				if okt and tab ~= nil then
					local key = Codex.KEY .. h.key_suffix
					tab.target_panel = key
					single.panels[key] = page
					made[#made + 1] = { page = page, tab = tab, key = key }
				else
					page:Remove()
				end
			end
		end
		single.savestates_history = made
	else
		local made = single.savestates_history
		single.savestates_history = nil
		local leaving = false
		for _, m in ipairs(made) do
			if m.page:IsShown() or tg.current == m.tab then
				leaving = true
			end
		end
		if leaving then
			-- the tab row's current tab back to Saved Hunts first: a removed tab
			-- left as the current one crashed LB / RB (TabGroup:NextTab found
			-- no index for it; 0.4.0)
			Codex.SelectMainTab(tg)
			if single._GoToPanel ~= nil then
				pcall(single._GoToPanel, single, Codex.KEY)
			end
		end
		for _, m in ipairs(made) do
			single.panels[m.key] = nil
			for i, t in ipairs(tg.tabs or {}) do
				if t == m.tab then
					table.remove(tg.tabs, i)
					break
				end
			end
			if tg.current == m.tab then
				tg.current = nil
			end
			pcall(function() m.tab:Remove() end)
			pcall(function() m.page:Remove() end)
		end
		-- whatever happened, the tab row's current tab is one it has
		local okc, idx = pcall(function() return tg:GetCurrentIdx() end)
		if not okc or idx == nil then
			Codex.SelectMainTab(tg)
		end
	end
	pcall(function() tg:Layout() end)
	return on
end

-- the tab row's current tab: Saved Hunts (else the first), without a click
function Codex.SelectMainTab(tg)
	local ok, err = pcall(function()
		local at = 1
		for i, t in ipairs(tg.tabs or {}) do
			if t.target_panel == Codex.KEY then
				at = i
				break
			end
		end
		if tg.tabs ~= nil and tg.tabs[at] ~= nil then
			tg:SelectTab(at)
		else
			tg.current = nil
		end
	end)
	if not ok then
		Log("the Codex's tab row: " .. tostring(err))
	end
end

-- the Codex screens open now (the Saved Hunts tab in them)
local function OpenSingles()
	local list = {}
	for page in pairs(Codex.open_pages) do
		local single = page.main_panel
		local main = page.view == nil or (page.view.mode ~= "manual" and page.view.mode ~= "auto")
		if main then
			if page.inst ~= nil and page.inst:IsValid() and single ~= nil and single.inst ~= nil and single.inst:IsValid() then
				list[#list + 1] = single
			end
		end
	end
	return list
end
Codex.OpenSingles = OpenSingles

-- The Saved Hunts screen from the pause menu / the archive key: the game's
-- Codex, opened on the Saved Hunts tab, which shows the view's list:
--   "load"    (town) the slots and the auto saves, LOAD
--   "save"    (a run) slots 1-10 with the empty ones: SAVE / OVERWRITE puts
--             this room there; the auto saves below load as usual
-- and, only with Ctrl+Shift+Alt+1 / both triggers, the two hidden history
-- tabs (Codex.SetHistoryTabs)
function Codex.OpenScreen(mode, player, opts)
	local fe = Global("TheFrontEnd")
	local CodexScreenMulti = Codex.CodexScreenMulti
	Need(CodexScreenMulti ~= nil and fe ~= nil, "the Codex screen")
	Codex.view = { mode = mode, history = type(opts) == "table" and opts.history == true or nil }
	local ok, screen = pcall(CodexScreenMulti, player)
	Codex.view = nil
	if not ok then
		error(screen, 0)
	end
	screen.savestates_view = mode
	-- the game stays paused while it's open (like the pause menu under it)
	if screen.SetWantsPause ~= nil then
		pcall(screen.SetWantsPause, screen)
	end
	fe:PushScreen(screen)
	return screen
end

-- The pause menu's button and the key: the full-screen Saved Hunts
-- (fullscreen.lua; pause_menu_screen = "full", the default), else the
-- Codex's view. If the full screen can't open, the Codex's view opens.
function Codex.OpenSaved(mode, player, opts)
	local full = Codex.Full
	if full ~= nil and Codex.settings.screen ~= "codex" then
		local ok, screen = pcall(full.Open, mode, player, opts)
		if ok and screen ~= nil then
			return screen
		end
		Log("the full-screen Saved Hunts didn't open, the Codex's view instead: " .. tostring(screen))
	end
	return Codex.OpenScreen(mode, player, opts)
end

-- Ctrl+Shift+Alt+1: the history tabs on / off in an open Codex; with none
-- open, the Saved Hunts screen (save view in a run, load view in town) with them
function Codex.ToggleHistory()
	local full = Codex.Full
	if full ~= nil then
		local done = full.ToggleHistory()
		if done ~= nil then
			return done
		end
	end
	local singles = OpenSingles()
	if #singles > 0 then
		-- any open Codex without them: shown in all; all with them: hidden
		local on = false
		for _, single in ipairs(singles) do
			if single.savestates_history == nil then
				on = true
			end
		end
		for _, single in ipairs(singles) do
			Codex.SetHistoryTabs(single, on)
		end
		return on and "shown" or "hidden"
	end
	local dungeon = Global("TheDungeon")
	local town = dungeon ~= nil and dungeon.IsInTown ~= nil and dungeon:IsInTown()
	Codex.OpenSaved(town and "load" or "save", nil, { history = true })
	return "opened"
end
Codex.ToggleArchive = Codex.ToggleHistory

-- a key saved while a Saved Hunts page is open: its list comes back with it
function Codex.OnSaved(slot)
	for page in pairs(Codex.open_pages) do
		if page.inst ~= nil and page.inst:IsValid() and page:IsShown() then
			SS.Call("Saved Hunts saved", Page.AfterSave, page, slot, true)
		end
	end
	if Codex.Full ~= nil then
		Codex.Full.OnSaved(slot)
	end
end

-- the pause menu: SAVE HUNT (a run) / LOAD HUNT (town), after Manage Multiplayer
function Codex.HookPause(PauseScreen)
	Need(type(PauseScreen) == "table" and type(PauseScreen._ctor) == "function", "the pause menu")
	if rawget(PauseScreen, "savestates_pause_hooked") then
		return true, "the pause menu's button (already in)"
	end
	local req = G().require or require
	local templates = req "widgets.ftf.templates"
	Need(type(templates) == "table" and templates.Button ~= nil, "the pause menu's buttons")
	Codex.PauseScreen = PauseScreen
	local ctor = PauseScreen._ctor
	PauseScreen._ctor = function(self, player, ...)
		ctor(self, player, ...)
		local ok, err = pcall(function()
			local town = self.inTown == true
			local mode = town and "load" or "save"
			local after = self.manageMPButton or self.closeButton
			self.savestates_btn = self.bottom_left:AddChild(templates.Button(town and Codex.STR.BUTTON_LOAD or Codex.STR.BUTTON_SAVE))
				:SetSecondary()
				:SetFlipped()
				:SetOnClick(function()
					SS.Call("Saved Hunts screen", Codex.OpenSaved, mode, player)
				end)
				:LayoutBounds("after", "center", after)
				:Offset(20, 0)
		end)
		if not ok then
			Log("the pause menu opens without the Saved Hunts button: " .. tostring(err))
		end
	end
	-- the button comes in with the others: PauseScreen:AnimateIn fades and
	-- slides in only its own buttons (0.4 s wait, fade 0.1 s, 40 px from the
	-- left in 0.2 s); the same, started with them so they move together
	if type(PauseScreen.AnimateIn) == "function" then
		local animate = PauseScreen.AnimateIn
		PauseScreen.AnimateIn = function(self, ...)
			local results = table.pack(animate(self, ...))
			local btn = rawget(self, "savestates_btn")
			if btn ~= nil then
				local ok, err = pcall(Codex.AnimateButtonIn, self, btn)
				if not ok then
					Log("the pause menu's Saved Hunts button shows without its animation: " .. tostring(err))
				end
			end
			return table.unpack(results, 1, results.n)
		end
	end
	rawset(PauseScreen, "savestates_pause_hooked", true)
	return true, "the pause menu's Save / Load button"
end

-- the pause menu's own button animation (PauseScreen:AnimateIn's
-- AnimateButtonFromLeft_Sequence) for our button; on any error it's shown
-- where it belongs
function Codex.AnimateButtonIn(screen, btn)
	local req = G().require or require
	local x, y = btn:GetPosition()
	local ok, err = pcall(function()
		local Updater, easing = req "ui.updater", req "util.easing"
		local seq = Updater.Series({
			Updater.Wait(0.4),
			Updater.Parallel({
				Updater.Ease(function(v) btn:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
				Updater.Ease(function(v) btn:SetPosition(v, y) end, x - 40, x, 0.2, easing.inOutQuad),
			}),
		})
		btn:SetMultColorAlpha(0)
		screen:RunUpdater(seq)
	end)
	if not ok then
		btn:SetMultColorAlpha(1)
		btn:SetPosition(x, y)
		error(err, 0)
	end
	return true
end

-- G: GLOBAL. Returns ok, info.
-- our control on the left stick click (gamepads), for LS on the page
function Codex.AddLsControl()
	local Controls, TheInput = rawget(G(), "Controls"), rawget(G(), "TheInput")
	if type(Controls) ~= "table" or type(Controls.Digital) ~= "table" or TheInput == nil or TheInput._AddGamepadButtonBind == nil then
		return false
	end
	local digital = Controls.Digital
	local control = rawget(digital, Codex.LS_CONTROL)
	if control == nil then
		control = { key = "Controls.Digital." .. Codex.LS_CONTROL, shortkey = Codex.LS_CONTROL }
		rawset(digital, Codex.LS_CONTROL, control)
	end
	if TheInput.gamepad_lookup == nil or TheInput.gamepad_lookup[control] == nil then
		TheInput:_AddGamepadButtonBind({ button = "LS", control = control })
	end
	return true
end

function Codex.Install(GLOBAL_, CodexScreenMulti, deps)
	Codex.G = GLOBAL_
	Codex.CodexScreenMulti = CodexScreenMulti
	deps = deps or {}
	Codex.L = deps.L or Codex.L
	Codex.biomes = deps.biomes or Codex.biomes
	Codex.itemforge = deps.itemforge or Codex.itemforge
	Codex.Equipment = deps.Equipment or Codex.Equipment
	Need(Codex.L ~= nil and Codex.biomes ~= nil and Codex.itemforge ~= nil, "Save States' pieces")
	local Single, DetailsPanel = Codex.FindClasses(CodexScreenMulti)
	-- the Codex's list button (its local class, for the full screen's list)
	Codex.ListButton = Codex.Upvalue(DetailsPanel._SetupListViewFromData, "CodexListButton")
	local req = G().require or require
	Codex.Controls = rawget(G(), "Controls")
	pcall(Codex.AddLsControl)
	W.Widget = req "widgets.widget"
	W.Image = req "widgets.image"
	W.Text = req "widgets.text"
	W.Padding = req "widgets.padding"
	W.ActionButton = req "widgets.actionbutton"
	W.SlotContentsPanel = req "widgets.ftf.slotcontentspanel"
	W.PowerWidget = req "widgets.ftf.powerwidget"
	for name, cls in pairs(W) do
		Need(type(cls) == "table", "widgets: " .. name)
	end
	-- the room's map icon: optional (without it the room line shows no icon)
	local okm, MapRoom = pcall(req, "widgets.ftf.maproom")
	W.MapRoom = okm and type(MapRoom) == "table" and MapRoom or nil
	local PageClass = Codex.MakePageClass(DetailsPanel)
	Codex.PageClass = PageClass
	if rawget(Single, "savestates_codex_hooked") then
		return true, "the Saved Hunts tab (already in)"
	end
	local ctor = Single._ctor
	Single._ctor = function(self, ...)
		ctor(self, ...)
		local ok, err = pcall(Codex.AddTo, self, PageClass)
		if not ok then
			Log("this Codex opens without the tab: " .. tostring(err))
		end
	end
	rawset(Single, "savestates_codex_hooked", true)
	return true, "the Saved Hunts tab in the camp's Codex"
end

return Codex
