-- UI Scale (Rotwood build 760548): parts of the interface smaller or bigger, each with its own size.
--
-- Three sizes, each 1 = the game's own size:
--  character_info  the character info in the screen's corners: each player's portrait, name, health,
--                  skills, potion, currencies (the game's PlayerStatusWidget). Scaled from its own
--                  corner, on top of the game's own size for it (bigger when you play alone).
--  power_popup     the power details over a power you can pick up, in the shop, at the wanderer (the
--                  game's WorldPowerDescription), on top of the size the game gives it.
--  whole_interface everything (0.1.0's way): menus, map, text, HUD. 1 = untouched.
-- Each one only touches its own widgets; the rest of the game stays exactly as it is.
--
-- character_info / power_popup: the game builds those widgets again every room. The mod wraps the
-- widget's class constructor (like the game's AddClassPostConstruct) and, on each new widget, that
-- one widget's SetScale, so its size goes on top of whatever size the game sets. Nothing runs per frame.
--
-- whole_interface: the game lays out every screen on a canvas of RES_X x RES_Y (3840 x 2160 at 16:9:
-- TARGET_RES_X / TARGET_RES_Y in constants.lua) and FrontEnd:OnScreenResize scales the root widget so
-- that canvas fills the window. A bigger canvas = everything smaller, still pinned to the screen's
-- edges. Left alone at 1.
local Main = {}

Main.TAG = "[UI Scale]"
Main.MIN, Main.MAX = 0.5, 1.5
Main.DEFAULTS = {
	enabled = true,
	character_info = 0.85,
	power_popup = 0.85,
	popup_prompt = "all",
	whole_interface = 1,
	remember = true,
	options_rows = true,
	key_character_bigger = "Ctrl+=",
	key_character_smaller = "Ctrl+-",
	key_character_reset = "Ctrl+Shift+=",
	key_popup_bigger = "Ctrl+Alt+=",
	key_popup_smaller = "Ctrl+Alt+-",
	key_popup_reset = "Ctrl+Alt+Shift+=",
	key_whole_bigger = "",
	key_whole_smaller = "",
	key_whole_reset = "",
	step = 0.05,
	console_command = true,
}
-- the sizes, in the order they're shown
Main.SIZES = {
	{ id = "character_info", key = "character", name = "Character Info Size", note = "Character info",
		what = "How big your character info is: portrait, health, skills, potion, currencies" },
	{ id = "power_popup", key = "popup", name = "Power Popup Size", note = "Power popup",
		what = "How big the power details are over a power you can pick up, and the prompts (Take, Reroll, Talk, Use...)" },
	{ id = "whole_interface", key = "whole", name = "Whole Interface Size", note = "Whole interface",
		what = "How big the whole interface is: menus, map, text, HUD (100% = the game's own)" },
}
Main.BY_ID = {}
for _, z in ipairs(Main.SIZES) do
	Main.BY_ID[z.id] = z
end
Main.SAVE_NAME = "ui_scale"                -- the sizes picked in the game (this account's save folder)
Main.SETTING_PREFIX = "graphics.uiscale_" -- the Options rows' settings (registered by the mod)
Main.settings = Main.DEFAULTS
Main.current = { character_info = 1, power_popup = 1, whole_interface = 1 }

local function Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end
Main.Log = Log

function Main.Clamp(v)
	if type(v) ~= "number" or v ~= v then
		return nil
	end
	return math.max(Main.MIN, math.min(Main.MAX, v))
end

-- 2 decimals (0.85), so the Options rows find it among their values
function Main.Round(v)
	return math.floor(v * 100 + 0.5) / 100
end

local function Pct(v)
	return math.floor((v or 1) * 100 + 0.5) .. "%"
end
Main.Pct = Pct

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if Main.DEFAULTS[k] ~= nil and type(v) == type(Main.DEFAULTS[k]) then
				s[k] = v
			end
		end
		-- popup_prompt was true / false before "all" / "pickups" / "none"
		if user.popup_prompt == true then
			s.popup_prompt = "all"
		elseif user.popup_prompt == false then
			s.popup_prompt = "none"
		end
		-- 0.1.0's one size was the whole interface's; its file only had that one, so the character info
		-- takes it (the whole interface stays the game's own)
		if user.character_info == nil and type(user.scale) == "number" then
			s.character_info = user.scale
		end
	end
	for _, z in ipairs(Main.SIZES) do
		local c = Main.Clamp(s[z.id])
		if c == nil then
			c = Main.DEFAULTS[z.id]
		end
		if c ~= s[z.id] then
			Log(z.id .. " " .. tostring(s[z.id]) .. " is outside " .. Main.MIN .. " .. " .. Main.MAX .. ": using " .. c)
		end
		s[z.id] = Main.Round(c)
	end
	s.step = math.max(0.01, math.min(0.25, s.step))
	if s.popup_prompt ~= "all" and s.popup_prompt ~= "pickups" and s.popup_prompt ~= "none" then
		Log("popup_prompt \"" .. tostring(s.popup_prompt) .. "\" isn't \"all\", \"pickups\" or \"none\": using \"all\"")
		s.popup_prompt = "all"
	end
	Main.settings = s
	return s
end

-- ---------------------------------------------------------------------------
-- whole_interface: the canvas

-- The game's own canvas, kept the first time (a global, so applying again never stacks; a full Lua
-- reset clears it along with the game's constants).
local function Base(G)
	local b = rawget(G, "UISCALE_GAME_RES")
	if type(b) ~= "table" then
		local x, y = rawget(G, "TARGET_RES_X"), rawget(G, "TARGET_RES_Y")
		if type(x) ~= "number" or type(y) ~= "number" or x <= 0 or y <= 0 then
			return nil
		end
		b = { x, y }
		rawset(G, "UISCALE_GAME_RES", b)
	end
	return b
end

function Main.ApplyCanvas(G, s)
	local b = Base(G)
	if b == nil then
		return false, "a game update changed TARGET_RES_X / TARGET_RES_Y"
	end
	local x = math.floor(b[1] / s + 0.5)
	local y = math.floor(b[2] / s + 0.5)
	rawset(G, "TARGET_RES_X", x)
	rawset(G, "TARGET_RES_Y", y)
	-- RES_X / RES_Y: the front end recomputes them for the window's shape on every resize; set them
	-- now too for anything that reads them before the first one.
	rawset(G, "RES_X", x)
	rawset(G, "RES_Y", y)
	local fe, sim = rawget(G, "TheFrontEnd"), rawget(G, "TheSim")
	if fe ~= nil and sim ~= nil and fe.OnScreenResize ~= nil and sim.GetScreenSize ~= nil then
		local w, h = sim:GetScreenSize()
		if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
			fe:OnScreenResize(w, h)
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- character_info / power_popup: one widget's SetScale wrapped, so the mod's size goes on top of the
-- game's (the game's own size changes keep working).

Main.widgets = { character_info = setmetatable({}, { __mode = "k" }), power_popup = setmetatable({}, { __mode = "k" }) }
Main.installed = {}

-- factor (optional): fn(w) -> how much of the size applies now (the pickup prompt: the popup's size
-- while it shows a pickup's prompt, the game's otherwise)
function Main.HookWidget(w, id, factor)
	if type(w) ~= "table" or type(w.SetScale) ~= "function" or rawget(w, "uiscale_id") then
		return false
	end
	local orig = w.SetScale
	rawset(w, "uiscale_id", id)
	rawset(w, "uiscale_x", type(w.sx) == "number" and w.sx or 1)
	rawset(w, "uiscale_y", type(w.sy) == "number" and w.sy or rawget(w, "uiscale_x"))
	rawset(w, "SetScale", function(self, x, y, ...)
		if type(x) == "number" then
			local yy = type(y) == "number" and y or x
			rawset(self, "uiscale_x", x)
			rawset(self, "uiscale_y", yy)
			local s = Main.current[id] or 1
			if factor ~= nil then
				local okf, f = pcall(factor, self)
				s = (okf and type(f) == "number") and f or 1
			end
			return orig(self, x * s, yy * s, ...)
		end
		return orig(self, x, y, ...)
	end)
	Main.widgets[id][w] = true
	w:SetScale(rawget(w, "uiscale_x"), rawget(w, "uiscale_y"))
	return true
end

-- the size now onto every such widget on screen
function Main.Refresh(id)
	local n = 0
	for w in pairs(Main.widgets[id] or {}) do
		if rawget(w, "uiscale_id") == id then
			local ok = pcall(w.SetScale, w, rawget(w, "uiscale_x") or 1, rawget(w, "uiscale_y"))
			n = n + (ok and 1 or 0)
		end
	end
	return n
end

-- the class whose new objects get the size, and which widget of the object
Main.CLASSES = {
	character_info = { path = "widgets.ftf.playerstatuswidget", part = "root",
		missing = "a game update changed the character info (widgets/ftf/playerstatuswidget)" },
	power_popup = { path = "widgets.ftf.worldpowerdescription", part = nil,
		missing = "a game update changed the power details (widgets/ftf/worldpowerdescription)" },
}

function Main.InstallClass(G, id)
	local c = Main.CLASSES[id]
	local ok, cls = pcall(require, c.path)
	if not ok or type(cls) ~= "table" or type(cls._ctor) ~= "function" then
		return false, c.missing .. (not ok and (": " .. tostring(cls)) or "")
	end
	if rawget(cls, "uiscale_ctor") then
		Main.installed[id] = true
		return true
	end
	local orig = cls._ctor
	cls._ctor = function(self, ...)
		orig(self, ...)
		local okh, err = pcall(function()
			local w = self
			if c.part ~= nil then
				w = rawget(self, c.part)
			end
			Main.HookWidget(w, id)
		end)
		if not okh then
			Log("a " .. Main.BY_ID[id].note:lower() .. " widget kept the game's size: " .. tostring(err))
		end
	end
	rawset(cls, "uiscale_ctor", true)
	Main.installed[id] = true
	return true
end

-- The prompts: the line over the player that says what the button does (Take / Reroll at a pickup,
-- Talk at an NPC, the mirror, the stations...). It's the game's Interactor prompt
-- (components/interactor.lua), one widget for every interaction, fed by SetStatusText; the revive
-- prompt is the HUD's label prompt (PlayerHud:ShowLabelPrompt). They take the power popup's size:
--   popup_prompt = "all"     every prompt (0.2.0 after "the prompts still dont scale down")
--   popup_prompt = "pickups" only while it shows a pickup's lines (the game's SinglePickup key)
--   popup_prompt = "none"    the game's size
-- The conversation itself (the speech balloons) keeps the game's size.
Main.PROMPT_KEY = "SinglePickup"

local function PromptFactor(interactor)
	if Main.settings.popup_prompt == "all" then
		return Main.current.power_popup or 1
	end
	local texts = rawget(interactor, "status_texts")
	if type(texts) == "table" and texts[Main.PROMPT_KEY] ~= nil then
		return Main.current.power_popup or 1
	end
	return 1
end
Main.PromptFactor = PromptFactor

function Main.SyncPrompt(interactor)
	local root = type(interactor) == "table" and rawget(interactor, "ui_root") or nil
	if type(root) ~= "table" then
		return false
	end
	if not rawget(root, "uiscale_id") then
		return Main.HookWidget(root, "power_popup", function() return PromptFactor(interactor) end)
	end
	root:SetScale(rawget(root, "uiscale_x") or 1, rawget(root, "uiscale_y"))
	return true
end

-- returns done, why, and whether the HUD's label prompts are in too
function Main.InstallPrompt(G)
	local ok, Interactor = pcall(require, "components.interactor")
	if not ok or type(Interactor) ~= "table" or type(Interactor.SetStatusText) ~= "function" then
		return false, "a game update changed the interaction prompt (components/interactor)"
	end
	if not rawget(Interactor, "uiscale_prompt") then
		local orig = Interactor.SetStatusText
		Interactor.SetStatusText = function(self, ...)
			local r = table.pack(orig(self, ...))
			local okp, err = pcall(Main.SyncPrompt, self)
			if not okp then
				Log("a prompt kept the game's size: " .. tostring(err))
			end
			return table.unpack(r, 1, r.n)
		end
		rawset(Interactor, "uiscale_prompt", true)
	end
	-- the HUD's own prompts (revive): only with "all"
	local labels = false
	if Main.settings.popup_prompt == "all" then
		local okh, PlayerHud = pcall(require, "screens.playerhud")
		if okh and type(PlayerHud) == "table" then
			labels = true
			for _, name in ipairs({ "ShowLabelPrompt", "ShowPrompt" }) do
				local orig = PlayerHud[name]
				if type(orig) == "function" and not rawget(PlayerHud, "uiscale_" .. name) then
					PlayerHud[name] = function(self, ...)
						local prompt = orig(self, ...)
						pcall(Main.HookWidget, prompt, "power_popup")
						return prompt
					end
					rawset(PlayerHud, "uiscale_" .. name, true)
				elseif type(orig) ~= "function" then
					labels = false
				end
			end
		end
	end
	return true, nil, labels
end

-- ---------------------------------------------------------------------------

-- id: one of Main.SIZES; scale: 1 = the game's size. Returns true / false, why.
function Main.Apply(G, id, scale)
	local s = Main.Clamp(scale)
	if s == nil or Main.BY_ID[id] == nil then
		return false, "scale must be a number"
	end
	s = Main.Round(s)
	if id == "whole_interface" then
		-- 1 at the start: not touched at all
		if not (s == 1 and rawget(G, "UISCALE_GAME_RES") == nil) then
			local ok, why = Main.ApplyCanvas(G, s)
			if not ok then
				return false, why
			end
		end
		Main.current[id] = s
		return true
	end
	Main.current[id] = s
	Main.Refresh(id)
	return true
end

-- ---------------------------------------------------------------------------
-- The sizes picked in the game: remembered in this account's save folder as
-- "character_info=0.85;power_popup=0.80;whole_interface=1.00".

function Main.Decode(text)
	local t = {}
	if type(text) ~= "string" then
		return t
	end
	for k, v in text:gmatch("([%w_]+)=([%d%.]+)") do
		local n = Main.Clamp(tonumber(v))
		if Main.BY_ID[k] ~= nil and n ~= nil then
			t[k] = Main.Round(n)
		end
	end
	return t
end

function Main.Encode(t)
	local parts = {}
	for _, z in ipairs(Main.SIZES) do
		if type(t[z.id]) == "number" then
			parts[#parts + 1] = string.format("%s=%.2f", z.id, t[z.id])
		end
	end
	return table.concat(parts, ";")
end

function Main.ReadRemembered(G)
	local sim = rawget(G, "TheSim")
	if sim == nil or sim.GetPersistentString == nil then
		return {}
	end
	local got = {}
	sim:GetPersistentString(Main.SAVE_NAME, function(ok, text)
		got = ok and Main.Decode(text) or {}
	end)
	return got
end

function Main.Remember(G)
	local sim = rawget(G, "TheSim")
	if Main.settings.remember and sim ~= nil and sim.SetPersistentString ~= nil then
		sim:SetPersistentString(Main.SAVE_NAME, Main.Encode(Main.current), false, function() end)
	end
end

-- A size picked in the game (Options rows, keys, console): applied now and remembered.
-- source: "options" / "key" (a key press shows a note with the size) / "console".
function Main.SetScale(G, id, scale, source)
	local z = Main.BY_ID[id]
	local s = Main.Clamp(scale)
	if z == nil or s == nil then
		return false
	end
	s = Main.Round(s)
	if math.abs((Main.current[id] or 1) - s) < 0.001 then
		return true
	end
	local ok, why = Main.Apply(G, id, s)
	if not ok then
		Log(z.note .. " not changed: " .. tostring(why))
		return false
	end
	Main.Remember(G)
	-- the Options row shows it too (a key press while Options is closed)
	local gs = rawget(G, "TheGameSettings")
	if source ~= "options" and gs ~= nil and type(gs.settings) == "table" then
		local setting = gs.settings[Main.SETTING_PREFIX .. id]
		if setting ~= nil then
			setting.value = s
		end
	end
	if source == "key" then
		local fe = rawget(G, "TheFrontEnd")
		if fe ~= nil and fe.ShowTextNotification ~= nil then
			pcall(fe.ShowTextNotification, fe, nil, z.note, Pct(s), 2)
		end
	end
	Log(z.note .. " " .. Pct(s) .. " (" .. tostring(source) .. ")")
	return true
end

-- ---------------------------------------------------------------------------
-- Keys

local KEY_ALIASES = { ["="] = "EQUALS", ["-"] = "MINUS" }

-- "Ctrl+Shift+=" -> { ctrl, shift, alt, key = "EQUALS" }; nil for "" or a bad one
function Main.ParseKey(text)
	if type(text) ~= "string" or text == "" or text:sub(-2) == "++" then
		return nil
	end
	local b = { ctrl = false, shift = false, alt = false, key = nil }
	-- the last part is the key ("=" or "-" can't be split on)
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

function Main.InstallKeys(G)
	local I = rawget(G, "TheInput")
	local IC = rawget(G, "InputConstants")
	local Keys = type(IC) == "table" and IC.Keys or nil
	if I == nil or I.AddKeyDownHandler == nil or I.IsKeyDown == nil or type(Keys) ~= "table" then
		return false, "the game's keys changed"
	end
	local function Code(name)
		local ok, code = pcall(function() return Keys[name] end)
		return ok and code or nil
	end
	local function Mods()
		return { ctrl = I:IsKeyDown(Code("CTRL")) == true, shift = I:IsKeyDown(Code("SHIFT")) == true, alt = I:IsKeyDown(Code("ALT")) == true }
	end
	local function Typing()
		local fe = rawget(G, "TheFrontEnd")
		return fe ~= nil and fe.forceProcessText == true
	end
	local s = Main.settings
	local actions = {}
	for _, z in ipairs(Main.SIZES) do
		local id = z.id
		if id == "whole_interface" or Main.installed[id] then
			actions[#actions + 1] = { s["key_" .. z.key .. "_bigger"], function() Main.SetScale(G, id, (Main.current[id] or 1) + s.step, "key") end, "KP_PLUS" }
			actions[#actions + 1] = { s["key_" .. z.key .. "_smaller"], function() Main.SetScale(G, id, (Main.current[id] or 1) - s.step, "key") end, "KP_MINUS" }
			actions[#actions + 1] = { s["key_" .. z.key .. "_reset"], function() Main.SetScale(G, id, 1, "key") end }
		end
	end
	-- one handler per key code, so each press does exactly the one action whose modifiers match
	local by_code, names = {}, {}
	for _, a in ipairs(actions) do
		local b = Main.ParseKey(a[1])
		if a[1] ~= "" and b == nil then
			Log("key \"" .. tostring(a[1]) .. "\" isn't a key I know: skipped")
		end
		if b ~= nil then
			local keys = { b.key }
			if a[3] ~= nil then
				keys[#keys + 1] = a[3]
			end
			for _, kname in ipairs(keys) do
				local code = Code(kname)
				if code == nil then
					Log("the game has no key " .. kname)
				else
					by_code[code] = by_code[code] or {}
					table.insert(by_code[code], { b = b, fn = a[2] })
				end
			end
			names[#names + 1] = a[1]
		end
	end
	local bound = 0
	for code, list in pairs(by_code) do
		I:AddKeyDownHandler(code, function()
			if Typing() then
				return
			end
			local m = Mods()
			for _, e in ipairs(list) do
				if m.ctrl == e.b.ctrl and m.shift == e.b.shift and m.alt == e.b.alt then
					local ok, err = pcall(e.fn)
					if not ok then
						Log("key: " .. tostring(err))
					end
					return
				end
			end
		end)
		bound = bound + 1
	end
	return bound > 0, table.concat(names, " / ")
end

-- ---------------------------------------------------------------------------
-- Rows in Options > Graphics: a setting of their own in the game's settings (the game saves its file
-- before the mods load, so the sizes are remembered by the mod, above), and spinner rows like Text
-- Size's. Changing one applies at once.

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
			inner[#inner + 1] = value
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
Main.FindUpvalue = FindUpvalue

function Main.RowValues(id)
	local values = {}
	local have = false
	local now = Main.current[id]
	for p = 50, 150, 5 do
		local v = p / 100
		values[#values + 1] = { name = p .. "%" .. (p == 100 and " (the game's size)" or ""), data = v }
		if now ~= nil and math.abs(now - v) < 0.001 then
			have = true
		end
	end
	if now ~= nil and not have then
		table.insert(values, 1, { name = Pct(now), data = now })
	end
	return values
end

local function KeyText(k, what)
	return (type(k) == "string" and k ~= "") and (k:gsub("%+", " + ") .. " " .. what) or nil
end

function Main.RowText(id)
	local z = Main.BY_ID[id]
	local s = Main.settings
	local keys = {}
	for _, k in ipairs({ KeyText(s["key_" .. z.key .. "_bigger"], "bigger"), KeyText(s["key_" .. z.key .. "_smaller"], "smaller"), KeyText(s["key_" .. z.key .. "_reset"], "the game's size") }) do
		keys[#keys + 1] = k
	end
	return z.what .. " (the UI Scale mod)." .. (#keys > 0 and (" Keys: " .. table.concat(keys, ", ") .. ".") or "")
end

function Main.InstallOptionsRows(G)
	local gs = rawget(G, "TheGameSettings")
	if gs == nil or gs.RegisterSetting == nil or gs.Has == nil then
		return false, "a game update changed the game's settings"
	end
	local okr, OptionsScreen = pcall(require, "screens.optionsscreen")
	if not okr or type(OptionsScreen) ~= "table" or type(OptionsScreen._BuildGraphicsPage) ~= "function" then
		return false, "a game update changed OptionsScreen:_BuildGraphicsPage"
	end
	local Row = FindUpvalue(OptionsScreen._BuildGraphicsPage, "OptionsScreenSpinnerRow", 8)
	if type(Row) ~= "table" then
		return false, "a game update changed the options rows"
	end
	local shown = {}
	for _, z in ipairs(Main.SIZES) do
		local id = z.id
		if id == "whole_interface" or Main.installed[id] then
			shown[#shown + 1] = z
			local key = Main.SETTING_PREFIX .. id
			if not gs:Has(key) then
				local setting = gs:RegisterSetting(key)
				setting:SetDefault(1.0)
				setting:SetApplyFunction(function(v)
					if type(v) == "number" then
						Main.SetScale(G, id, v, "options")
					end
				end)
				setting.value = Main.current[id] or 1.0 -- (no apply now: it's already on)
			end
		end
	end
	if rawget(OptionsScreen, "uiscale_rows") then
		return true
	end
	rawset(OptionsScreen, "uiscale_rows", true)
	local orig = OptionsScreen._BuildGraphicsPage
	OptionsScreen._BuildGraphicsPage = function(self, ...)
		local r = table.pack(orig(self, ...))
		for _, z in ipairs(shown) do
			local ok, err = pcall(function()
				local setting = gs.settings ~= nil and gs.settings[Main.SETTING_PREFIX .. z.id] or nil
				if setting ~= nil then
					setting.value = Main.current[z.id] or 1.0
				end
				self.pages.graphics:AddChild(Row(self.rowWidth, self.rowRightColumnWidth))
					:SetText(z.name, Main.RowText(z.id))
					:SetValues(Main.RowValues(z.id))
					:HookupSetting(Main.SETTING_PREFIX .. z.id, self)
			end)
			if not ok then
				Log("the Options row " .. z.name .. " was skipped: " .. tostring(err))
			end
		end
		return table.unpack(r, 1, r.n)
	end
	return true
end

-- c_uiscale(0.8): the character info; c_uiscale("popup", 0.8) / c_uiscale("whole", 0.8);
-- c_uiscale(): the sizes now.
local ALIASES = { character = "character_info", hud = "character_info", info = "character_info",
	popup = "power_popup", power = "power_popup", whole = "whole_interface", all = "whole_interface" }

function Main.InstallCommand(G)
	rawset(G, "c_uiscale", function(a, b)
		local id, scale = "character_info", a
		if type(a) == "string" then
			id = ALIASES[a] or (Main.BY_ID[a] ~= nil and a) or nil
			scale = b
			if id == nil then
				Log("which size? \"character\", \"popup\" or \"whole\"")
				return false
			end
		end
		if scale == nil then
			local parts = {}
			for _, z in ipairs(Main.SIZES) do
				parts[#parts + 1] = z.note .. " " .. Pct(Main.current[z.id])
			end
			Log("now: " .. table.concat(parts, ", "))
			return Main.current[id]
		end
		local ok = type(scale) == "number" and Main.SetScale(G, id, scale, "console")
		if ok then
			Log(Main.BY_ID[id].note .. " now " .. Pct(Main.current[id]) .. (Main.settings.remember and " (remembered)" or ""))
		else
			Log("not changed: scale must be a number")
		end
		return ok == true
	end)
end

return Main
