-- Save States: the full-screen Saved Hunts (experimental; pause_menu_screen =
-- "full" in savestates_settings.lua, the pause menu's SAVE HUNT / LOAD HUNT).
--
-- One screen for everyone (not one per player, even in co-op), the pause
-- menu's own look, no header:
--   * top left: each saved player on one line: the weapons around P1 and the
--     character, HP, extra lives, Teffra, rerolls, potions (the HUD's icon),
--     the run's powers (the game's icons, counters and tooltips);
--   * under them: the saved hunt's map, drawn by the pause menu's own map
--     (widgets/ftf/dungeonhistorymap.lua) from the save's map data;
--   * under the map: the room (its map icon), when it was saved, the note;
--   * right: the saves, in a frame like the pause menu's Hunter's Path:
--     slots 1-10 (in a run the empty ones too), then the auto saves;
--   * bottom: CLOSE, SAVE TO SLOT / OVERWRITE / LOAD and the line about it,
--     CODEX VIEW (the Codex's Saved Hunts), the gamepad's hints.
-- The controls are the Codex view's: A picks, LS loads with Replicate, RS
-- with Rebuild, Y swaps P1 / P2; LT+RT (keyboard: hold Z, press C) or
-- Ctrl+Shift+Alt+1 show the hidden history lists, LB / RB (Q / E) between them.
--
-- The map: the game's map reads the dungeon it's in (TheDungeon:GetDungeonMap()).
-- While a save's map is drawn, TheDungeon is a stand-in that answers with a
-- copy of the save's map data (run by the game's own WorldMap and MapGenRun
-- code) and everything else from the real one; the real one is back right
-- after, even on an error. Nothing is written anywhere. A map that can't be
-- drawn leaves the hunt's band (shield, name, Frenzy) in its place; if the
-- screen itself can't open, the Codex's view opens (codex.lua Codex.OpenSaved).
local SS = require "savestates.main"
local D = require "savestates.data"
local Codex = require "savestates.codex"

local Full = {}

Full.BG = "images/ui_ftf_pausescreen/background_gradient.tex" -- the pause menu's
Full.LIST_FRAME = "images/ui_ftf_shop/inventory_frame.tex"    -- the pause menu's Hunter's Path frame
Full.LIST_FRAME_SLICE = { 150, 150, 160, 160 }
Full.MARGIN = 60
Full.LIST_WIDTH = 820
Full.LIST_INSET = 75   -- the list inside the frame's border
Full.GAP = 60          -- between the hunt and the list
Full.BOTTOM = 220      -- the bottom row's room (the pause menu's buttons: 20 up, 140 tall)
Full.LIST_BOTTOM = 320 -- the list's frame ends higher: the gamepad's hints go under it
Full.NOTE_WIDTH = 1900 -- the line by the main button, at most
Full.PLAYER_GAP = 24   -- between the players' lines
Full.PLAYERS_KEPT = 2  -- the map always leaves room for this many players' lines (one row of powers)
Full.FOOT_KEPT = 110   -- and this much at the bottom (the room line: up to three lines of text)
Full.MAP_GAP = 24      -- between the map and the saves' frame
Full.MAP_MARGIN = 8    -- above and below the map
Full.FOOT_GAP = 6      -- between the map and the room line under it
Full.MAX_MAP_SCALE = 1.25
Full.LINE_GAP = 50     -- between the parts of a player's line
Full.MIN_POWERS = 6    -- powers to a row at least
-- align_players: the line's columns (the same on every line and every save)
Full.NAME_W = 360      -- the character's name: a longer one drawn smaller to fit
Full.WHO_GAP = 24      -- between the weapons, P1 and the name (the Codex's)
Full.COLUMN_TEXT = { hp = "8888/8888", lives = "88", teffra = "8888", rerolls = "88", potions = "88", number = "P8" }
Full.PAGES_KEPT = 4    -- saves drawn (hidden) while the screen is open
Full.SETTLE = Codex.SETTLE
Full.TAB_HEIGHT = 70
Full.STR = {
	CODEX = "CODEX VIEW",
	TABS = { "Saves", "Manual history", "Auto history" },
	HINT_LISTS = "Saves / history",
	NO_PREVIEW = "This room couldn't be shown (in the log).",
}
Full.LIST_VIEWS = { "main", "manual", "auto" }

Full.open = setmetatable({}, { __mode = "k" }) -- the screens open now
Full.ScreenClass = nil

local W = {} -- the game's classes (set at install)
Full.W = W

local function G()
	return Codex.G or _G
end

local function Global(name)
	return rawget(G(), name)
end

local function Log(msg)
	Codex.Log("full screen: " .. tostring(msg))
end

local function Need(cond, what)
	if not cond then
		error("a game update changed " .. what, 0)
	end
end

local function Colour(name, fallback)
	return Codex.Colour(name, fallback)
end

local function FontSize(name, fallback)
	return Codex.FontSize(name, fallback)
end

local function NewText(size, text, colour)
	return Codex.NewText(size, text, colour)
end


-- ---------------------------------------------------------------------------
-- the saved hunt's map (plain data and the game's own classes)

-- "Nocturne Grove—Frenzy 3": the map's title as the game makes it, for the save
function Full.MapTitle(st)
	local run = type(st) == "table" and type(st.run) == "table" and st.run or {}
	local loc = Codex.Location(run.location_id)
	local name = loc ~= nil and loc.pretty ~= nil and loc.pretty.name or tostring(run.location_id or "?")
	local AM = W.AscensionManager
	local label
	if AM ~= nil and type(AM.GetFrenzyLabel) == "function" then
		local ok, l = pcall(AM.GetFrenzyLabel, math.floor((tonumber(run.ascension) or 0) + 0.5), true, run.trek ~= nil)
		label = ok and type(l) == "string" and l ~= "" and l or nil
	end
	return label ~= nil and string.format("%s\u{2014}%s", name, label) or name
end

-- The save's world map, read-only: the game's WorldMap and MapGenRun on a copy
-- of the saved data (none of their constructors run: nothing is listened to,
-- nothing loaded). Its weather is the save's.
function Full.MapView(st)
	Need(W.WorldMap ~= nil and W.MapGenRun ~= nil, "the world map")
	local wm = type(st) == "table" and type(st.worldmap) == "table" and st.worldmap or nil
	local mg_data = wm ~= nil and type(wm.mgrun_data) == "table" and wm.mgrun_data or nil
	if mg_data == nil or type(mg_data.current) ~= "table" or type(mg_data.location_id) ~= "string" then
		error("the save has no map", 0)
	end
	local view = setmetatable({}, W.WorldMap)
	view.data = D.deepcopy(wm)
	view.data.mgrun_data = nil
	local mg = setmetatable({ debug = {} }, W.MapGenRun)
	mg:LoadData(mg_data, false) -- (a copy; false: nothing sent to the network)
	Need(type(mg.IsActive) == "function" and mg:IsActive(), "the map's run")
	view.mgrun = mg
	if W.WeatherManager ~= nil then
		local wd = type(wm.weathermanager_data) == "table" and D.deepcopy(wm.weathermanager_data) or {}
		view.weathermanager = setmetatable({ persist_data = wd }, W.WeatherManager)
	else
		view.weathermanager = { IsWeatherEnabled = function() return false end }
	end
	return view
end

-- TheDungeon for the drawing: the save's map, not in town; the rest the real one's
function Full.DungeonView(real, map_view)
	local view = setmetatable({}, { __index = real })
	view.GetDungeonMap = function()
		return map_view
	end
	view.IsInTown = function()
		return false
	end
	view.IsInRestRoom = function()
		return false
	end
	view.savestates_saved_map = true
	map_view.inst = view
	if type(map_view.weathermanager) == "table" then
		map_view.weathermanager.inst = view
	end
	return view
end

-- fn with TheDungeon the stand-in; the real one back after it, whatever happens
function Full.WithDungeon(view, fn, ...)
	local g = G()
	local real = rawget(g, "TheDungeon")
	rawset(g, "TheDungeon", view)
	local res = table.pack(pcall(fn, ...))
	rawset(g, "TheDungeon", real)
	if not res[1] then
		error(res[2], 0)
	end
	return table.unpack(res, 2, res.n)
end

-- the map's title for the save (the game wrote the run it's in), laid out the way it does
function Full.FixTitle(map, text)
	if map.title == nil or map.title_root == nil or text == nil then
		return false
	end
	if map.title.GetText ~= nil and map.title:GetText() == text then
		return false
	end
	map.title:SetText(text)
		:LayoutBounds("center", "center", map.title_root)
	local deco_w = 0
	if map.deco_left ~= nil then
		map.deco_left:LayoutBounds("before", "center", map.title):Offset(-20, 0)
		deco_w = map.deco_left:GetSize() or 0
	end
	if map.deco_right ~= nil then
		-- (laid out before mirroring, like the game: a mirrored widget's own
		-- bounds read back to front)
		map.deco_right:SetScale(1, 1)
			:LayoutBounds("after", "center", map.title):Offset(20, 0)
			:SetScale(-1, 1)
	end
	map.title_root:SetSize(map.title:GetSize() + deco_w * 3 + 130, 122)
	if map.bg ~= nil and map.bg.border ~= nil then
		map.title_root:LayoutBounds("center", "top", map.bg.border):Offset(0, -29)
	end
	return true
end

-- The pause menu's map of the saved hunt, on parent. Errors out (nothing left
-- on parent) when it can't be drawn.
function Full.DrawMap(parent, st)
	Need(W.DungeonHistoryMap ~= nil, "the dungeon map")
	local real = Global("TheDungeon")
	Need(real ~= nil, "the dungeon")
	local map_view = Full.MapView(st)
	local view = Full.DungeonView(real, map_view)
	local map = Full.WithDungeon(view, function()
		local m, err = Codex.SafeChild(parent, W.DungeonHistoryMap)
		if m == nil then
			error(err, 0)
		end
		local ok, e = pcall(function()
			m:SetName("saved hunt map")
			-- not the pause menu's: no debug buttons (they act on the dungeon you're in)
			if m.buttons ~= nil then
				m.buttons:Remove()
				m.buttons = nil
			end
			-- its size measured blank, before the rooms: every map the same size
			-- (a hunt drawn further, its boss icon, made the map smaller)
			local w, h = m:GetSize()
			m.savestates_size = { w, h }
			m:DrawFullMap()
		end)
		if not ok then
			pcall(function() m:Remove() end)
			error(e, 0)
		end
		return m
	end)
	-- the game's stand-in for missing map tiles is a debug line: a save from
	-- another place shows the plain paper instead
	pcall(function() map.bg.fill.label:Hide() end)
	local okt, errt = pcall(Full.FixTitle, map, Full.MapTitle(st))
	if not okt then
		Log("map title: " .. tostring(errt))
	end
	return map
end

-- the hunt's band (shield on its wings, the name, Frenzy): instead of a map
function Full.Band(parent, st)
	local holder = parent:AddChild(W.Widget("hunt band"))
	local band = holder:AddChild(W.Image("images/white.tex")):SetName("band")
		:SetSize(Codex.BAND_WIDTH, Codex.BAND_HEIGHT)
		:SetMultColorAlpha(0)
	local h = holder:AddChild(Codex.Header(st))
	Codex.LayoutHeader(h, band)
	return holder
end

-- w as big as box allows (up to max_scale), in its middle; size: its own
-- size to go by (else measured now)
function Full.Fit(w, box, max_scale, size)
	local ww, wh
	if type(size) == "table" and (tonumber(size[1]) or 0) > 0 and (tonumber(size[2]) or 0) > 0 then
		ww, wh = size[1], size[2]
	else
		ww, wh = w:GetSize()
	end
	local bw, bh = box.x2 - box.x1, box.top - box.bottom
	local s = max_scale or 1
	if ww ~= nil and ww > 0 then
		s = math.min(s, bw / ww)
	end
	if wh ~= nil and wh > 0 then
		s = math.min(s, bh / wh)
	end
	s = math.max(0.1, s)
	w:SetScale(s)
	w:LayoutBounds("center", "center", (box.x1 + box.x2) / 2, (box.top + box.bottom) / 2)
	return s
end

-- The map's place: the same for every save, from the screen alone (0.4.2
-- went by what the page held, the room line's box above all, so a save with a
-- taller room icon put the map higher). The space left of the saves, under
-- two players' lines, over the room line's room.
function Full.MapBox(self)
	local A = self.area
	local kept = Codex.POWER_SIZE * Full.PLAYERS_KEPT + Full.PLAYER_GAP * (Full.PLAYERS_KEPT - 1)
	local right = self.list_box ~= nil and self.list_box.x1 or (A.x2 + Full.GAP)
	return { x1 = A.x1, x2 = right - Full.MAP_GAP, top = A.top - kept - Full.MAP_MARGIN,
		bottom = A.bottom + Full.FOOT_KEPT + Full.MAP_MARGIN }
end

-- The map sized and placed by its paper border, the same picture for every
-- map: nothing drawn on it changes its size or place (0.4.1 measured the
-- map blank, but a place's map tiles that aren't loaded measure nothing, so
-- saves from other places came out bigger). The paper's roll sits inside the
-- border's box (measured on the user's screen, 0.4.2: the roll ended right at
-- the border's edge, so the room 0.4.2 kept for it was left empty).
Full.ROLL_ROOM = 0 -- of the border's width, past its box
function Full.FitMap(page, map, box)
	local border = type(map.bg) == "table" and map.bg.border or nil
	local bw, bh
	if border ~= nil then
		bw, bh = border:GetSize()
	end
	if not ((tonumber(bw) or 0) > 0 and (tonumber(bh) or 0) > 0) then
		return Full.Fit(map, box, 1, map.savestates_size)
	end
	local w = bw * (1 + Full.ROLL_ROOM)
	local s = math.max(0.1, math.min(Full.MAX_MAP_SCALE, (box.x2 - box.x1) / w, (box.top - box.bottom) / bh))
	map:SetScale(s)
	map:SetPosition(0, 0)
	local x1, y1, x2, y2 = border:GetBoundingBox()
	local ax, ay = page:TransformFromWidget(border, x1, y1)
	local bx, by = page:TransformFromWidget(border, x2, y2)
	local cx = (box.x1 + box.x2) / 2 - bw * s * Full.ROLL_ROOM / 2
	local cy = (box.top + box.bottom) / 2
	map:SetPosition(cx - (ax + bx) / 2, cy - (ay + by) / 2)
	-- where its border ends below (the room line goes under it)
	return s, cy - math.abs(by - ay) / 2
end

-- w moved so its text (or itself) starts at y (its top), centred on x: the
-- text, not the whole row, so a room icon's size never moves the line
function Full.PlaceTop(page, w, text, x, y)
	w:LayoutBounds("center", "top", x, y)
	local t = text or w
	local _, y1, _, y2 = t:GetBoundingBox()
	if type(y1) == "number" and type(y2) == "number" then
		local _, ty1 = page:TransformFromWidget(t, 0, y1)
		local _, ty2 = page:TransformFromWidget(t, 0, y2)
		w:Offset(0, y - math.max(ty1, ty2))
	end
end

-- ---------------------------------------------------------------------------
-- a saved hunt's page: the players, the map, the room

-- A cell of a fixed width (a Padding that wide), its content on its left.
local function Cell(parent, name, w)
	local cell = parent:AddChild(W.Widget(name))
	cell.pad = cell:AddChild((W.Padding or Codex.W.Padding)(math.max(1, w), 1))
	return cell
end
local function Into(cell, content)
	if content ~= nil then
		content:LayoutBounds("left", "center", cell.pad)
	end
	return content
end

-- how wide a stat is with this icon and this text (made, measured, removed)
local function StatWidth(parent, build)
	local probe = build(parent)
	local w = probe:GetSize()
	probe:Remove()
	return w or 1
end

-- The aligned line (align_players): the weapons and P1 in their places, the
-- name in Full.NAME_W (the game's ShrinkToFitWidth for a longer one), then HP,
-- extra lives, Teffra, rerolls, potions, each in its column's width and always
-- shown: 0 when the player hasn't got them, the HUD's plain potion when no
-- potion. A column is as wide as its widest number (Full.COLUMN_TEXT) or the
-- widest on this line, so the lines and the saves line up.
function Full.AlignedParts(line, info)
	local muted = Colour("LIGHT_TEXT_DARK")
	local who = line:AddChild(W.Widget("who"))
	local big = FontSize("SCREEN_TEXT_LARGE", 50) * 1.2
	local C = Full.COLUMN_TEXT
	for _, slot in ipairs({ { "held weapon", Codex.WeaponTex(info.held) }, { "player number" }, { "other weapon", Codex.WeaponTex(info.other) } }) do
		if slot[1] == "player number" then
			local probe = who:AddChild(NewText(big, C.number, muted))
			local nw = probe:GetSize()
			probe:Remove()
			local cell = Cell(who, "player number", nw or big)
			Into(cell, cell:AddChild(NewText(big, "P" .. info.index, muted)):SetName("player number"))
		else
			local cell = Cell(who, slot[1], big)
			if slot[2] ~= nil then
				Into(cell, cell:AddChild(W.Image(slot[2])):SetName(slot[1]):SetSize(big, big):SetMultColor(muted))
			end
		end
	end
	local name_cell = Cell(who, "character", Full.NAME_W)
	if info.name ~= nil then
		local t = name_cell:AddChild(NewText(FontSize("SCREEN_TEXT", 40), info.name, muted)):SetName("character")
		local tw = t:GetSize()
		if (tw or 0) > Full.NAME_W then
			t:ShrinkToFitWidth(Full.NAME_W) -- (the game's: a smaller font to fit)
		end
		who.character = Into(name_cell, t)
	end
	who:LayoutChildrenInRow(Full.WHO_GAP, "center")

	local stats = line:AddChild(W.Widget("stats"))
	local hp_text = string.format("%d/%d", info.hp, info.hp_max)
	local lives = info.lives or 0
	local potions = info.potions or 0
	local potion_tex = Codex.PotionTex(info.potion_id, info.potions ~= nil and potions or nil)
	local light = Colour("LIGHT_TEXT_DARKER")
	local cols = {
		{ "health", C.hp, hp_text, function(p, text) return Codex.Stat(p, Codex.ICONS.hp, text, "health", light) end },
		{ "extra lives", C.lives, tostring(lives), function(p, text) return Codex.Lives(p, text, info.index) end },
		{ "teffra", C.teffra, tostring(info.konjur), function(p, text) return Codex.Stat(p, Codex.ICONS.konjur, text, "teffra") end },
		{ "rerolls", C.rerolls, tostring(info.rerolls), function(p, text) return Codex.Stat(p, Codex.ICONS.rerolls, text, "rerolls") end },
		{ "potions", C.potions, tostring(potions), function(p, text) return Codex.Stat(p, potion_tex, text, "potions") end },
	}
	for _, col in ipairs(cols) do
		local build = col[4]
		local w = math.max(StatWidth(stats, function(p) return build(p, col[2]) end), StatWidth(stats, function(p) return build(p, col[3]) end))
		local cell = Cell(stats, col[1], w)
		Into(cell, build(cell, col[3]))
	end
	stats:LayoutChildrenInRow(Codex.STAT_GAP, "center")
	return who, stats
end

-- a player on one line: who, the stats, the powers (as many to a row as fit)
function Full.PlayerLine(parent, owner, p, i, width)
	local info = Codex.PlayerInfo(p, i)
	local line = parent:AddChild(W.Widget("Player " .. i))
	local who, stats
	if SS.settings == nil or SS.settings.align_players ~= false then
		local ok, a, b = pcall(Full.AlignedParts, line, info)
		if ok then
			who, stats = a, b
		else
			-- the line as before (the Codex's pieces), the half-made one gone
			Log("the players' columns: " .. tostring(a))
			line:Remove()
			line = parent:AddChild(W.Widget("Player " .. i))
		end
	end
	if who == nil then
		who = Codex.PlayerWho(line, info)
		stats = Codex.PlayerStats(line, info)
	end
	local ww, wh = who:GetSize()
	local sw, sh = stats:GetSize()
	local used = (ww or 0) + (sw or 0) + Full.LINE_GAP * 2
	local per_row = math.max(Full.MIN_POWERS, math.floor((width - used) / (Codex.POWER_SIZE + Codex.POWER_GAP)))
	local grid = Codex.PlayerPowers(line, info, owner, per_row)
	line:LayoutChildrenInRow(Full.LINE_GAP, "center")
	-- how tall this line is with one row of powers (the map's room is kept for two such lines)
	local row_h = Codex.POWER_SIZE
	if grid ~= nil then
		local _, gh = grid:GetSize()
		local n = #(grid:GetChildren() or {})
		local rows = math.max(1, math.ceil(n / per_row))
		row_h = math.max(1, (gh or 0) / rows)
	end
	line.one_row_h = math.max(wh or 0, sh or 0, row_h)
	return line
end

function Full.FillPage(self, page, st, meta, note)
	local A = self.area
	local width = A.x2 - A.x1
	-- the players (the save's order: one screen for everyone)
	-- The map's room is the same for every save: two players' lines with a row
	-- of powers each, and three lines at the bottom. Only more (more powers,
	-- more players) moves that save's map down.
	local players = type(st.players) == "table" and st.players or {}
	local block_h = 0
	if #players > 0 then
		local block = page:AddChild(W.Widget("players"))
		for i, p in ipairs(players) do
			Full.PlayerLine(block, self.owner, p, i, width)
		end
		block:LayoutChildrenInColumn(Full.PLAYER_GAP, "left")
		block:LayoutBounds("left", "top", A.x1, A.top)
		local _, bh = block:GetSize()
		block_h = bh or 0
		page.players = block
	end
	-- the map: its place and size the same for every save (more players or
	-- powers than the room kept for them: only that save's map moves down)
	local box = Full.MapBox(self)
	box.top = math.min(box.top, A.top - block_h - Full.MAP_MARGIN)
	local map_bottom = box.bottom
	local okm, map = pcall(Full.DrawMap, page, st)
	if okm then
		page.map = map
		local okf, s, mb = pcall(Full.FitMap, page, map, box)
		if not okf then
			Log("the map's size: " .. tostring(s))
			Full.Fit(map, box, 1, map.savestates_size)
		elseif type(mb) == "number" then
			map_bottom = mb
		end
	else
		Log("the map: " .. tostring(map))
		page.band = Full.Band(page, st)
		Full.Fit(page.band, box, 1.5)
	end
	-- the room (or the line for an empty slot) right under it, its text
	-- starting at the same height on every save
	local foot
	if note ~= nil then
		foot = page:AddChild(NewText(FontSize("SCREEN_TEXT", 40), note, Colour("LIGHT_TEXT_DARK"))):SetName("page note")
	else
		foot = page:AddChild(Codex.RoomRow(st, meta))
	end
	local text = rawget(foot, "text")
	if type(text) ~= "table" or text.GetBoundingBox == nil then
		text = nil -- (a line of text: itself)
	end
	local okp, errp = pcall(Full.PlaceTop, page, foot, text, (box.x1 + box.x2) / 2, map_bottom - Full.FOOT_GAP)
	if not okp then
		Log("the room line: " .. tostring(errp))
		foot:LayoutBounds("center", "bottom", (A.x1 + A.x2) / 2, A.bottom)
	end
	page.foot = foot
end

function Full.BuildPage(self, st, meta, note)
	local page = self.hunt:AddChild(W.Widget("Saved hunt page"))
	page:Hide()
	local ok, err = pcall(Full.FillPage, self, page, st, meta, note)
	if not ok then
		page:Remove()
		error(err, 0)
	end
	return page
end

-- ---------------------------------------------------------------------------
-- the screen's behaviour (guarded by the class's wrappers)

local S = {}
Full.S = S

local function FocusId(self)
	local user = self:GetOwningUser()
	return user ~= nil and user.GetId ~= nil and user:GetId() or nil
end

function S.CancelPending(self)
	if self.pending ~= nil then
		local job = self.pending
		self.pending = nil
		Codex.CancelJob(job)
	end
end

function S.HideAll(self)
	for _, e in pairs(self.pages) do
		e.root:Hide()
	end
	self.message:Hide()
end

function S.Message(self, text)
	S.HideAll(self)
	self.message:SetText(text)
		:LayoutBounds("center", "center", (self.area.x1 + self.area.x2) / 2, (self.area.top + self.area.bottom) / 2)
		:Show()
	self.current_key = nil
	S.SetLoad(self, nil)
end

local function Tick(self)
	self.tick = (self.tick or 0) + 1
	return self.tick
end

-- a page drawn: kept (a few), the one shown longest ago goes
function S.Keep(self, key, root, st)
	local entry = { root = root, st = st, used = Tick(self) }
	self.pages[key] = entry
	local n, oldest_key, oldest = 0, nil, nil
	for k, e in pairs(self.pages) do
		n = n + 1
		if k ~= key and (oldest == nil or e.used < oldest.used) then
			oldest_key, oldest = k, e
		end
	end
	if n > Full.PAGES_KEPT and oldest ~= nil then
		self.pages[oldest_key] = nil
		oldest.root:Remove()
	end
	return entry
end

function S.ShowPage(self, key, entry, data)
	S.HideAll(self)
	entry.root:Show()
	entry.used = Tick(self)
	self.current_key = key
	if not S.SetSave(self, data, entry.st) then
		S.SetLoad(self, data, entry.st)
	end
end

function S.Build(self, data)
	local L = Codex.L
	self.wanted = data
	local key = Codex.PageKey(data)
	local done = false
	L.store:Get(data.id, function(st)
		done = true
		if self.wanted ~= data or not self.inst:IsValid() then
			return -- (another save was picked meanwhile)
		end
		if type(st) ~= "table" or type(st.run) ~= "table" then
			S.Message(self, Codex.STR.UNREADABLE)
			self.current_key = key
			return
		end
		local ok, root = pcall(Full.BuildPage, self, st, data.meta)
		if not ok then
			Log(tostring(root))
			S.Message(self, Codex.STR.ERROR)
			self.current_key = key
			return
		end
		S.ShowPage(self, key, S.Keep(self, key, root, st), data)
	end)
	if not done then
		S.Message(self, Codex.STR.LOADING)
		self.current_key = key
	end
end

-- an empty slot (save view): this room as it would go there
function S.ShowEmpty(self, data)
	S.CancelPending(self)
	self.wanted = data
	local text = string.format(Codex.STR.EMPTY_PAGE, data.slot)
	local entry = self.pages.preview
	if entry == nil and not self.preview_failed then
		local ok, err = pcall(function()
			local C = require "savestates.capture"
			local st, why = C.Take("preview")
			if st == nil then
				error(why or "no state", 0)
			end
			entry = S.Keep(self, "preview", Full.BuildPage(self, st, nil, text), st)
		end)
		if not ok then
			self.preview_failed = true
			Log("this room's preview: " .. tostring(err))
			entry = nil
		end
	end
	if entry == nil then
		S.Message(self, text)
	else
		S.HideAll(self)
		entry.root:Show()
		entry.used = Tick(self)
		if entry.root.foot ~= nil and entry.root.foot.SetText ~= nil then
			entry.root.foot:SetText(text)
				:LayoutBounds("center", "bottom", (self.area.x1 + self.area.x2) / 2, self.area.bottom)
		end
	end
	self.current_key = "empty" .. tostring(data.slot)
	S.SetSave(self, data, nil)
end

-- a save shown: its kept page right away; a new one once the focus stays (or now)
function S.ShowEntry(self, data, now)
	if data == nil then
		return
	end
	if data.empty then
		return S.ShowEmpty(self, data)
	end
	S.CancelPending(self)
	self.wanted = data
	local key = Codex.PageKey(data)
	if self.current_key == key then
		return
	end
	local entry = self.pages[key]
	if entry ~= nil and not entry.root.removed then
		S.ShowPage(self, key, entry, data)
		return
	end
	if not now and Full.SETTLE > 0 then
		local job
		local ok = pcall(function()
			job = Codex.After(self, Full.SETTLE, function()
				if self.pending == job then
					self.pending = nil
				end
				if self.wanted == data then
					SS.Call("Saved Hunts", S.Build, self, data)
				end
			end)
		end)
		if ok and job ~= nil then
			self.pending = job
			return
		end
	end
	S.Build(self, data)
end

-- the main button and the line by it: LOAD (or why not)
function S.SetLoad(self, data, st)
	self.load = nil
	self.save_job = nil
	self.load_data, self.load_st = data, st
	if data == nil or st == nil then
		self.main_btn:Hide()
		self.can_swap = false
		self.note:SetText("")
		S.Hints(self)
		return
	end
	local can_swap = Codex.CanSwap(st)
	if not can_swap then
		self.swap = false
	end
	local ok, mode, note = Codex.LoadChoice(Codex.Effective(st, self.swap))
	S.MainText(self, Codex.STR.LOAD)
	self.main_btn:Show()
	if ok then
		self.main_btn:Enable()
		self.load = { id = data.id, mode = mode, label = data.label, order = self.swap and { 2, 1 } or nil }
	else
		self.main_btn:Disable()
	end
	self.can_swap = can_swap
	local lines = {}
	if note ~= nil and note ~= "" then
		lines[#lines + 1] = note
	end
	if self.swap then
		lines[#lines + 1] = string.format(Codex.STR.SWAPPED, Codex.SavedName(st.players[2], 2), Codex.SavedName(st.players[1], 1))
	elseif can_swap and Codex.L.LooksSwapped ~= nil and Codex.L.LooksSwapped(st) then
		lines[#lines + 1] = Codex.STR.SWAP_SUGGEST
	end
	S.Note(self, table.concat(lines, "\n"), ok)
	S.Hints(self)
end

-- save view, slots 1-10: the main button saves this room there
function S.SetSave(self, data, st)
	self.save_job = nil
	local slot = data ~= nil and data.slot or nil
	if self.mode ~= "save" or self.list_view ~= "main" or type(slot) ~= "number" or slot < 1 then
		return false
	end
	local L = Codex.L
	local C = require "savestates.capture"
	local okc, can, why = pcall(C.CanSave)
	S.MainText(self, string.format(data.empty and Codex.STR.SAVE_TO or Codex.STR.OVERWRITE, slot))
	self.main_btn:Show()
	self.can_swap = false
	self.load = nil
	self.load_data, self.load_st = data, st
	if okc and can and L ~= nil and not L.busy then
		self.main_btn:Enable()
		self.save_job = { slot = slot }
		S.Note(self, self.saved_note or "", true)
	else
		self.main_btn:Disable()
		S.Note(self, string.format(Codex.STR.CANT_SAVE, tostring(okc and (why or Codex.STR.BUSY) or can)), false)
	end
	self.saved_note = nil
	S.Hints(self)
	return true
end

-- (sized like the pause menu's buttons: widgets/ftf/templates.lua Button)
function S.MainText(self, text)
	if self.main_text ~= text then
		self.main_text = text
		self.main_btn:SetText(text)
		self.main_btn:ResizeToFit(nil, nil, Global("BUTTON_W") or 580, Global("BUTTON_H") or 140)
	end
	S.LayoutBottom(self)
end

function S.Note(self, text, ok)
	self.note:SetText(text or "")
	self.note:SetGlyphColor(ok and Colour("LIGHT_TEXT_DARK") or Colour("RED", { 0.8, 0.2, 0.2, 1 }))
	S.LayoutBottom(self)
end

function S.LayoutBottom(self)
	self.main_btn:LayoutBounds("after", "center", self.close_btn):Offset(20, 0)
	self.note:LayoutBounds("after", "center", self.main_btn:IsShown() and self.main_btn or self.close_btn):Offset(30, 0)
end

-- the main button: SAVE (save view, a slot) or LOAD, for the save picked
-- (the mouse passing over other saves on its way here showed theirs)
function S.Primary(self)
	local data = self.last_data
	if data ~= nil and self.current_key ~= (data.empty and ("empty" .. tostring(data.slot)) or Codex.PageKey(data)) then
		S.ShowEntry(self, data, true)
	end
	if self.save_job ~= nil then
		return S.SaveSlot(self)
	end
	return S.Load(self)
end

function S.SaveSlot(self)
	local job = self.save_job
	local L = Codex.L
	if job == nil or L == nil then
		return
	end
	self.save_job = nil
	self.main_btn:Disable()
	L.Save(job.slot, function(ok, why)
		if not self.inst:IsValid() then
			return
		end
		SS.Call("Saved Hunts saved", S.AfterSave, self, job.slot, ok, why)
	end)
end

-- a save made (here or with a key): the list again, that slot shown
function S.AfterSave(self, slot, ok, why)
	self.list_key = nil
	local function IsSlot(data)
		return data.slot == slot and not data.history
	end
	-- (the note first: the slot's page shows it)
	self.saved_note = ok and string.format(Codex.STR.SAVED_NOTE, slot) or string.format(Codex.STR.NOT_SAVED, tostring(why))
	self.current_key = nil
	local row = S.Refresh(self, true, IsSlot)
	if row == nil or row.saved_hunt == nil or not IsSlot(row.saved_hunt) then
		self.saved_note = nil
	end
	return row
end

-- LOAD: the screen closes (and the pause menu under it, so the game runs
-- again), then the load starts (the game's run start); codex.lua
function S.Load(self)
	local job = self.load
	local L = Codex.L
	if job == nil or L == nil then
		return
	end
	self.load = nil
	Codex.LeaveForLoad(self)
	Codex.QueueLoad(job)
end

-- LS / RS: load the save shown with that mode
function S.LoadForced(self, mode)
	local data, st = self.load_data, self.load_st
	if data == nil or st == nil or data.empty or self.save_job ~= nil then
		return false
	end
	local ok, why = Codex.LoadChoiceFor(Codex.Effective(st, self.swap), mode)
	if not ok then
		local name = mode == "replicate" and Codex.STR.MODE_REPLICATE or Codex.STR.MODE_REBUILD
		S.Note(self, string.format(Codex.STR.FORCED_CANT, name, tostring(why)), false)
		return true
	end
	self.load = { id = data.id, mode = mode, label = data.label, order = self.swap and { 2, 1 } or nil }
	S.Load(self)
	return true
end

-- Y: Swap P1 / P2 for this save's load (2 players)
function S.ToggleSwap(self)
	if not self.can_swap or self.load_st == nil or not Codex.CanSwap(self.load_st) then
		return false
	end
	self.swap = not self.swap
	S.SetLoad(self, self.load_data, self.load_st)
	return true
end

-- a row picked: it's shown now; picked by the player (click / A) with a
-- gamepad, the focus goes to the main button
function S.Pick(self, data, row, by_player)
	if self.last_row ~= nil and self.last_row ~= row and self.last_row.inst:IsValid() then
		self.last_row:Unselect()
	end
	row:Select()
	self.last_row, self.last_data = row, data
	S.ShowEntry(self, data, true)
	if by_player and self:IsRelativeNavigation() and self.main_btn:IsShown() and self.main_btn:IsEnabled() then
		self.main_btn:SetFocus(FocusId(self))
	end
end

-- the list of the view shown (the saves, or a hidden history)
function S.ListFor(self)
	local mode = self.list_view == "main" and self.mode or self.list_view
	return Codex.Slots(Codex.L.store, { mode = mode })
end

-- The list again (when the saves changed). The row picked: the first, or the
-- first that want(data) likes. focus: the focus goes to it (not while the
-- screen is made: the game gives it its first focus).
function S.Refresh(self, keep_focus, want)
	local L = Codex.L
	if L == nil or L.store == nil or not L.store.loaded then
		self.list_key = nil
		self.list_contents:RemoveAllChildren()
		S.Message(self, Codex.STR.STORE_LOADING)
		return nil
	end
	local slots = S.ListFor(self)
	local key = self.list_view .. "|" .. Codex.ListKey(slots)
	if key == self.list_key and self.list_contents:GetFirstChild() ~= nil then
		if want ~= nil then
			for _, row in ipairs(self.list_contents:GetChildren()) do
				if row.saved_hunt ~= nil and want(row.saved_hunt) then
					S.Pick(self, row.saved_hunt, row)
					return row
				end
			end
		end
		return self.last_row or self.list_contents:GetFirstChild()
	end
	self.list_key = key
	self.slots = slots
	S.CancelPending(self)
	self.list_contents:RemoveAllChildren()
	self.last_row, self.last_data = nil, nil
	if #slots == 0 then
		S.Message(self, Codex.STR.EMPTY)
		S.Hints(self)
		return nil
	end
	local first, wanted
	for i, data in ipairs(slots) do
		local row = self.list_contents:AddChild(W.ListButton(self.row_width, data.pretty_name))
		row:SetOdd(i % 2 == 0)
		S.SetupRow(self, row, data)
		first = first or row
		if wanted == nil and want ~= nil and want(data) then
			wanted = row
		end
	end
	first = wanted or first
	local last = self.list_contents:GetLastChild()
	if last ~= nil then
		last:SetFocusDir("down", last) -- (not on down into the buttons under the list)
	end
	self.list_contents:LayoutChildrenInColumn(10, "center")
	S.LayoutList(self)
	S.Pick(self, first.saved_hunt, first)
	if not keep_focus then
		first:SetFocus(FocusId(self))
	end
	return first
end

-- a row: the name and the region's ornament (like the Codex's list), shown on focus, picked on click
function S.SetupRow(self, row, data)
	row.saved_hunt = data
	if data.ornament ~= nil then
		row.ornament = row:AddChild(W.Image(data.ornament))
			:SetName("region ornament")
			:SetHeight_PreserveAspect(row.height * 0.55)
			:SetMultColor(Colour("LIGHT_TEXT_DARKER"))
		row.ornament:LayoutBounds("right", "center", row.btn_bg):Offset(-26, 0)
		local ow = row.ornament:GetSize()
		row.label:SetRegionSize(row.width - (ow or 40) - 70, row.height)
		row.label:RefreshText()
		row.label:LayoutBounds("left", "center", row.btn_bg):Offset(24, 0)
			:LeftAlign()
	end
	row:SetOnClickFn(function()
		SS.Call("Saved Hunts", S.Pick, self, data, row, true)
	end)
	row:SetOnGainFocus(function()
		SS.Call("Saved Hunts", S.ShowEntry, self, data)
	end)
end

-- the list's frame from the top: the title, the history lists' tabs (when
-- shown), then the list down to the frame's bottom
function S.LayoutList(self)
	local box = self.list_box
	local inset = Full.LIST_INSET
	local cx = (box.x1 + box.x2) / 2
	local y = box.top - inset
	self.list_title:LayoutBounds("center", "top", cx, y)
	local _, th = self.list_title:GetSize()
	y = y - (th or 0)
	if self.history then
		self.tabs:Show()
		self.tabs:LayoutBounds("center", "top", cx, y - 16)
		local _, tbh = self.tabs:GetSize()
		y = y - 16 - (tbh or 0)
	else
		self.tabs:Hide()
	end
	y = y - 20
	local bottom = box.bottom + inset
	self.list_scroll:SetSize(Full.LIST_WIDTH - inset * 2 + 35, math.max(200, y - bottom))
	self.list_scroll:LayoutBounds("center", "top", cx, y)
	self.list_contents:LayoutBounds("center", "top", self.list_scroll)
	self.list_scroll:RefreshView()
end

-- the hidden history lists: on / off (LT+RT, Z+C, Ctrl+Shift+Alt+1)
function S.SetHistory(self, on)
	on = on and true or false
	if on == (self.history == true) then
		return on
	end
	self.history = on
	if not on then
		self.list_view = "main"
	end
	S.MarkTabs(self)
	S.LayoutList(self)
	S.Refresh(self, not self.shown_once)
	return on
end

function S.MarkTabs(self)
	for i, tab in ipairs(self.tab_buttons or {}) do
		if Full.LIST_VIEWS[i] == self.list_view then
			tab:Select()
		else
			tab:Unselect()
		end
	end
end

-- one of the lists (the saves, manual history, auto history)
function S.SetListView(self, v)
	if v ~= "main" and not self.history then
		return false
	end
	if v == self.list_view then
		return true
	end
	self.list_view = v
	S.MarkTabs(self)
	S.Refresh(self, not self.shown_once)
	return true
end

-- LB / RB (Q / E): the next / previous list, while the history lists show
function S.StepList(self, step)
	if not self.history then
		return false
	end
	local n = #Full.LIST_VIEWS
	local at = 1
	for i, v in ipairs(Full.LIST_VIEWS) do
		if v == self.list_view then
			at = i
		end
	end
	return S.SetListView(self, Full.LIST_VIEWS[((at - 1 + step) % n) + 1])
end

-- the gamepad's hints at the bottom
function S.Hints(self)
	if self.hotkeys == nil then
		return
	end
	local ok, err = pcall(function()
		local hotkeys = {}
		local d = Codex.Controls ~= nil and Codex.Controls.Digital or nil
		if d ~= nil and self:IsUsingGamepad() then
			local focus = self:GetFocusForOwner()
			if focus ~= nil and not self.list_contents:IsAncestorOf(focus) then
				hotkeys[#hotkeys + 1] = { control = d.CANCEL, label = Global("STRINGS").UI.CODEXSCREEN.BACK_TO_LIST }
			end
			if self.load_data ~= nil and not self.load_data.empty and self.save_job == nil and self.main_btn:IsShown() then
				if rawget(d, Codex.LS_CONTROL) ~= nil then
					hotkeys[#hotkeys + 1] = { control = rawget(d, Codex.LS_CONTROL), label = Codex.STR.HINT_REPLICATE }
				end
				hotkeys[#hotkeys + 1] = { control = d.RADIAL_ACTION, label = Codex.STR.HINT_REBUILD }
				if self.can_swap then
					hotkeys[#hotkeys + 1] = { control = d.MENU_UNCOMMON, label = self.swap and Codex.STR.SWAP_ON or Codex.STR.HINT_SWAP }
				end
			end
			if self.history then
				hotkeys[#hotkeys + 1] = { control = d.MENU_TAB_NEXT, label = Full.STR.HINT_LISTS }
			end
		end
		self.hotkeys:SetHotkeys(hotkeys)
		self.hotkeys:LayoutBounds("right", "above", self.codex_btn):Offset(0, 20)
	end)
	if not ok then
		Log("hints: " .. tostring(err))
	end
end

function S.Close(self)
	local fe = Global("TheFrontEnd")
	if fe ~= nil then
		fe:PopScreen(self)
	end
end

-- CODEX VIEW: this screen closes, the Codex's Saved Hunts opens (the same view)
function S.OpenCodex(self)
	local mode, player, history = self.mode, self.player, self.history
	S.Close(self)
	Codex.OpenScreen(mode, player, { history = history or nil })
end

-- ---------------------------------------------------------------------------
-- the screen

local function FirstLocalPlayer()
	local ok, list = pcall(Codex.LocalPlayers)
	return ok and type(list) == "table" and list[1] or nil
end

function Full.Build(self, mode, player, opts)
	opts = type(opts) == "table" and opts or {}
	self.mode = mode == "save" and "save" or "load"
	self.list_view = "main"
	self.player = player
	self.owner = player or FirstLocalPlayer()
	self.pages = {}
	self.swap = false
	self.can_swap = false
	self:SetWantsPause()
	pcall(function()
		self:SetAudioCategory(W.Screen.AudioCategory.s.Fullscreen)
	end)
	local sw, sh = self:GetSize()
	local M = Full.MARGIN
	-- the pause menu's background (and black under it: nothing behind shows through)
	self.solid = self:AddChild(W.templates.SolidBackground(0x000000ff)):SetName("black")
	self.bg = self:AddChild(W.templates.BackgroundImage(Full.BG)):SetName("background")
	-- right: the saves in the Hunter's Path frame
	local list_top, list_bottom = sh / 2 - M, -sh / 2 + Full.LIST_BOTTOM
	self.list_box = { x1 = sw / 2 - M - Full.LIST_WIDTH, x2 = sw / 2 - M, top = list_top, bottom = list_bottom }
	self.list_frame = self:AddChild(W.Panel(Full.LIST_FRAME)):SetName("saves frame")
		:SetNineSliceCoords(table.unpack(Full.LIST_FRAME_SLICE))
		:SetSize(Full.LIST_WIDTH, list_top - list_bottom)
		:SetMultColor(Colour("LIGHT_TEXT"))
	self.list_frame:LayoutBounds("right", "top", sw / 2 - M, list_top)
	self.list_title = self:AddChild(NewText(FontSize("SCREEN_TEXT", 40) * 1.6, Codex.STR.TITLE, Colour("LIGHT_TEXT_TITLE"))):SetName("saves title")
	self.tabs = self:AddChild(W.Widget("history lists"))
	self.row_width = Full.LIST_WIDTH - Full.LIST_INSET * 2 - 40
	self.tab_buttons = {}
	local tab_w = math.floor((self.row_width - 20) / #Full.LIST_VIEWS)
	for i, v in ipairs(Full.LIST_VIEWS) do
		local tab = self.tabs:AddChild(W.ListButton(tab_w, Full.STR.TABS[i]))
		tab:SetName("list " .. v)
		tab:SetOnClickFn(function()
			SS.Call("Saved Hunts", S.SetListView, self, v)
		end)
		self.tab_buttons[i] = tab
	end
	self.tabs:LayoutChildrenInRow(10, "center")
	self.tabs:Hide()
	self.list_scroll = self:AddChild(W.ScrollPanel()):SetName("saves scroll")
		:SetSideMargin(10)
		:SetScrollBarMargin(0)
		:SetBarInset(50)
		:SetVirtualMargin(40)
	self.list_contents = self.list_scroll:AddScrollChild(W.Widget("saves"))
	-- left: the saved hunt (pages), or a line
	self.area = { x1 = -sw / 2 + M, x2 = self.list_box.x1 - Full.GAP, top = sh / 2 - M, bottom = -sh / 2 + Full.BOTTOM }
	self.hunt = self:AddChild(W.Widget("saved hunt"))
	self.message = self.hunt:AddChild(NewText(FontSize("SCREEN_TEXT", 40) * 1.2, "", Colour("LIGHT_TEXT_DARK"))):SetName("message")
	self.message:Hide()
	-- bottom left: CLOSE, the main button, its line (the pause menu's buttons and places)
	self.bottom_left = self:AddChild(W.Widget("bottom_left"))
		:FollowTextScaling()
		:LayoutBounds("left", "bottom", self)
	self.close_btn = self.bottom_left:AddChild(W.templates.BackButton())
		:SetOnClick(function()
			SS.Call("Saved Hunts close", S.Close, self)
		end)
		:LayoutBounds("left", "bottom", self.bg)
		:Offset(30, 20)
	self.main_btn = self.bottom_left:AddChild(W.templates.Button(Codex.STR.LOAD))
		:SetPrimary()
		:SetOnClick(function()
			SS.Call("Saved Hunts LOAD", S.Primary, self)
		end)
	self.main_btn:SetNavFocusable(true)
	self.note = self.bottom_left:AddChild(NewText(FontSize("SCREEN_TEXT", 40) * 0.9, "", Colour("LIGHT_TEXT_DARK"))):SetName("load note")
		:ShrinkToFitWidth(Full.NOTE_WIDTH)
	S.MainText(self, Codex.STR.LOAD)
	self.main_btn:Hide()
	-- bottom right: the Codex's view; the gamepad's hints before it
	self.bottom_right = self:AddChild(W.Widget("bottom_right"))
		:FollowTextScaling()
		:LayoutBounds("right", "bottom", self)
	self.codex_btn = self.bottom_right:AddChild(W.templates.Button(Full.STR.CODEX))
		:SetSecondary()
		:SetOnClick(function()
			SS.Call("Saved Hunts Codex view", S.OpenCodex, self)
		end)
		:LayoutBounds("right", "bottom", self.bg)
		:Offset(-30, 20)
	local okh, hk = pcall(function() return self.bottom_right:AddChild(W.PanelHotkeys("Saved Hunts hints")) end)
	self.hotkeys = okh and hk or nil
	if player ~= nil then
		self:SetOwningPlayer(player)
	end
	S.LayoutList(self)
	if opts.history then
		S.SetHistory(self, true) -- (its list made with it)
	else
		S.Refresh(self, true)
	end
	self.default_focus = self.close_btn
	S.Hints(self)
end

function Full.MakeScreenClass(Screen)
	local Cls = Class(Screen, function(self, mode, player, opts)
		Screen._ctor(self, "SavedHuntsScreen")
		Full.Build(self, mode, player, opts)
	end)

	local function Guard(name, fn)
		return function(self, ...)
			local ok, res = pcall(fn, self, ...)
			if not ok then
				Log(name .. ": " .. tostring(res))
				return false
			end
			return res
		end
	end

	local map = {}
	local d = Codex.Controls ~= nil and Codex.Controls.Digital or nil
	if d ~= nil then
		-- B: back to the list (gamepad, from elsewhere), else the screen closes
		map[#map + 1] = { control = d.CANCEL, fn = Guard("back", function(self)
			local focus = self:GetFocusForOwner()
			if self:IsRelativeNavigation() and focus ~= nil and not self.list_contents:IsAncestorOf(focus)
				and self.last_row ~= nil and self.last_row.inst:IsValid() then
				self.last_row:SetFocus(FocusId(self))
				return true
			end
			S.Close(self)
			return true
		end) }
		if rawget(d, "RADIAL_ACTION") ~= nil then
			map[#map + 1] = { control = d.RADIAL_ACTION, fn = Guard("RS", function(self) return S.LoadForced(self, "rebuild") end) }
		end
		if rawget(d, Codex.LS_CONTROL) ~= nil then
			map[#map + 1] = { control = rawget(d, Codex.LS_CONTROL), fn = Guard("LS", function(self) return S.LoadForced(self, "replicate") end) }
		end
		if rawget(d, "MENU_UNCOMMON") ~= nil then
			map[#map + 1] = { control = d.MENU_UNCOMMON, fn = Guard("Y", function(self) return S.ToggleSwap(self) end) }
		end
		local lt, rt = rawget(d, "MENU_SUB_TAB_PREV"), rawget(d, "MENU_SUB_TAB_NEXT")
		if lt ~= nil and rt ~= nil then
			-- both triggers: one let go while the other is held
			map[#map + 1] = { control_list = { lt, rt }, fn = Guard("history", function(self)
				local input = Global("TheInput")
				if input == nil or input.IsControlDownOnAnyDevice == nil then
					return false
				end
				if not (input:IsControlDownOnAnyDevice(lt) or input:IsControlDownOnAnyDevice(rt)) then
					return false
				end
				S.SetHistory(self, not self.history)
				return true
			end) }
		end
		local lb, rb = rawget(d, "MENU_TAB_PREV"), rawget(d, "MENU_TAB_NEXT")
		if lb ~= nil then
			map[#map + 1] = { control = lb, fn = Guard("LB", function(self) return S.StepList(self, -1) end) }
		end
		if rb ~= nil then
			map[#map + 1] = { control = rb, fn = Guard("RB", function(self) return S.StepList(self, 1) end) }
		end
	end
	Cls.CONTROL_MAP = map

	-- the pause key closes it too (like the pause menu)
	function Cls:OnControl(controls, down, ...)
		if Cls._base.OnControl(self, controls, down, ...) then
			return true
		end
		local digital = Codex.Controls ~= nil and Codex.Controls.Digital or nil
		if not down and digital ~= nil and digital.PAUSE ~= nil and controls:Has(digital.PAUSE) then
			S.Close(self)
			return true
		end
	end

	-- the first focus: the save picked (else the first row, else CLOSE)
	function Cls:FindDefaultFocus(hunter_id)
		if self.last_row ~= nil and self.last_row.inst:IsValid() and not self.last_row.removed then
			return self.last_row
		end
		return self.list_contents:GetFirstChild() or self.close_btn
	end

	-- the HUD hidden while it's open (opened from the pause menu it already is)
	function Cls:OnOpen()
		Cls._base.OnOpen(self)
		Full.open[self] = true
		pcall(function()
			self:EnableFocusBracketsForGamepad()
		end)
		pcall(function()
			local dungeon = Global("TheDungeon")
			if dungeon ~= nil and dungeon.HUD ~= nil and dungeon.HUD:IsShown() then
				self.hid_hud = true
				dungeon:SetHudVisibility(false)
			end
		end)
	end

	function Cls:OnClose()
		Full.open[self] = nil
		S.CancelPending(self)
		if self.hid_hud then
			self.hid_hud = nil
			pcall(function()
				local dungeon = Global("TheDungeon")
				if dungeon ~= nil then
					dungeon:SetHudVisibility(true)
				end
			end)
		end
		Cls._base.OnClose(self)
	end

	-- shown (again, after a screen on top): the saves may have changed, then
	-- the game gives the focus back (to the save picked)
	function Cls:OnBecomeActive()
		if self.shown_once then
			local ok, err = pcall(S.Refresh, self, true)
			if not ok then
				Log("refresh: " .. tostring(err))
			end
		end
		self.shown_once = true
		Cls._base.OnBecomeActive(self)
		pcall(S.Hints, self)
	end

	function Cls:OnFocusChanged(new_focus, hunter_id, show_immediately)
		Cls._base.OnFocusChanged(self, new_focus, hunter_id, show_immediately)
		local ok, err = pcall(function()
			local last = self.last_data
			if last ~= nil and new_focus ~= nil and not self.list_contents:IsAncestorOf(new_focus) then
				-- the list lost the focus: back to the save picked
				S.ShowEntry(self, last, true)
			end
			S.Hints(self)
		end)
		if not ok then
			Log("focus: " .. tostring(err))
		end
	end

	return Cls
end

-- ---------------------------------------------------------------------------
-- opening, the keys

-- The screen made and pushed. If making it fails half way, the half-made
-- screen is hidden and removed (a screen never pushed would still be drawn:
-- the frontend hides one it can't push for that reason), then the error goes
-- on (the Codex's view opens instead).
function Full.Open(mode, player, opts)
	local fe = Global("TheFrontEnd")
	local Cls = Full.ScreenClass
	Need(Cls ~= nil and fe ~= nil, "the full screen")
	local screen = setmetatable({}, Cls)
	local ok, err = pcall(Cls._ctor, screen, mode, player, opts)
	if not ok then
		if rawget(screen, "inst") ~= nil then
			pcall(function() screen:Hide() end)
			pcall(function()
				if fe.screenroot ~= nil and screen.parent == nil then
					fe.screenroot:AddChild(screen)
				end
				screen:Remove()
			end)
		end
		error(err, 0)
	end
	fe:PushScreen(screen)
	return screen
end

local function OpenScreens()
	local list = {}
	for screen in pairs(Full.open) do
		if screen.inst ~= nil and screen.inst:IsValid() then
			list[#list + 1] = screen
		end
	end
	return list
end
Full.OpenScreens = OpenScreens

-- Ctrl+Shift+Alt+1 with the screen open: its history lists on / off; nil: none open
function Full.ToggleHistory()
	local list = OpenScreens()
	if #list == 0 then
		return nil
	end
	local on = false
	for _, screen in ipairs(list) do
		if not screen.history then
			on = true
		end
	end
	for _, screen in ipairs(list) do
		SS.Call("Saved Hunts history", S.SetHistory, screen, on)
	end
	return on and "shown" or "hidden"
end

-- a key saved while the screen is open: the list comes back with it
function Full.OnSaved(slot)
	for _, screen in ipairs(OpenScreens()) do
		SS.Call("Saved Hunts saved", S.AfterSave, screen, slot, true)
	end
end

function Full.Install(GLOBAL_)
	Need(Codex.L ~= nil and Codex.PageClass ~= nil, "Saved Hunts (the Codex's tab)")
	local req = (GLOBAL_ ~= nil and GLOBAL_.require) or require
	W.Widget = Codex.W.Widget
	W.Image = Codex.W.Image
	W.Padding = Codex.W.Padding -- (the players' columns)
	W.Screen = req "widgets.screen"
	W.Panel = req "widgets.panel"
	W.ScrollPanel = req "widgets.scrollpanel"
	W.PanelHotkeys = req "widgets.panelhotkeys"
	W.templates = req "widgets.ftf.templates"
	W.ListButton = Codex.ListButton
	for _, name in ipairs({ "Widget", "Image", "Screen", "Panel", "ScrollPanel", "PanelHotkeys", "templates", "ListButton" }) do
		Need(type(W[name]) == "table", "widgets: " .. name)
	end
	Need(type(W.templates.Button) == "function" and type(W.templates.BackButton) == "function"
		and type(W.templates.BackgroundImage) == "function" and type(W.templates.SolidBackground) == "function", "the game's button templates")
	Need(type(W.Screen.AudioCategory) == "table", "the screen class")
	-- the map: optional (without it, the hunt's band)
	local function Opt(name)
		local ok, m = pcall(req, name)
		return ok and type(m) == "table" and m or nil
	end
	W.DungeonHistoryMap = Opt "widgets.ftf.dungeonhistorymap"
	W.MapGenRun = Opt "components.mapgenrun"
	W.WorldMap = Opt "components.worldmap"
	W.WeatherManager = Opt "components.weathermanager"
	W.AscensionManager = Opt "components.ascensionmanager"
	local map_ok = W.DungeonHistoryMap ~= nil and type(W.DungeonHistoryMap.DrawFullMap) == "function"
		and W.MapGenRun ~= nil and type(W.MapGenRun.LoadData) == "function"
		and W.WorldMap ~= nil and type(W.WorldMap.GetBiomeLocation) == "function"
	Full.ScreenClass = Full.MakeScreenClass(W.Screen)
	Codex.Full = Full
	return true, "the full-screen Saved Hunts (" .. (map_ok and "with the hunt's map" or "no map: the game's map changed") .. ")"
end

return Full
