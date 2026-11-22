-- Save States: the settings, the log, notes and the protected calls every part uses.
--
-- Layers of safety:
--  1. install: each part checks the game functions it needs and stays off
--     when one is missing; the game is untouched by a part that is off
--  2. a load is checked in full before anything changes (refused with the
--     reason on screen); the character data is built from the character's
--     own current file with only the run parts swapped in, and checked to be
--     identical everywhere else before it's written
--  3. run time: every hook calls the game's own function, and the mod's part
--     inside a protected call; an error falls back to the game's way
--  4. settings: a bad value falls back to its default (logged)
local SS = {}

SS.TAG = "[Save States]"
SS.VERSION = 1 -- the state format

SS.DEFAULTS = {
	enabled = true,
	keys = {
		save = "Ctrl",
		rebuild = "Ctrl+Shift",
		replicate = "Ctrl+Alt",
		latest_rebuild = "Ctrl+L",
		latest_replicate = "Ctrl+Alt+L",
		menu = "Ctrl+Shift+Alt+1",
	},
	keep_debug_text_size = true,
	manual_history = 1000,
	auto_save = true,
	auto_history = 100,
	auto_save_delay = 1.0,
	undo_before_load = true,
	fade_load = true,
	align_players = true,
	same_room = true,
	replicate_lend = false,
	restore_loadout_after_run = true,
	restore_counters = true,
	exact_hp = true,
	notes = true,
	codex = true,
	codex_tab_first = true,
	pause_menu = true,
	pause_menu_screen = "full",
	debug = false,
}

SS.settings = nil
SS.off = {}      -- part -> why it's off for this session
SS.warnings = {} -- settings that fell back to their default

function SS.Log(msg)
	print(SS.TAG .. " " .. tostring(msg))
end

function SS.Debug(msg)
	if SS.settings ~= nil and SS.settings.debug then
		SS.Log(msg)
	end
end

-- fn(...) protected: ok, results... On an error the part goes off for the
-- session (logged once) and false comes back.
function SS.Call(part, fn, ...)
	if SS.off[part] ~= nil then
		return false, "off"
	end
	local r = table.pack(pcall(fn, ...))
	if not r[1] then
		SS.off[part] = tostring(r[2])
		SS.Log(part .. ": off for this session after an error: " .. tostring(r[2]))
		return false, r[2]
	end
	return table.unpack(r, 1, r.n)
end

-- fn(...) protected, without turning anything off: ok, results...
function SS.Try(fn, ...)
	return pcall(fn, ...)
end

-- a short note on screen (and always in the log)
SS.NoteFn = nil -- set by modmain: function(title, text)
function SS.Note(title, text)
	SS.Log(tostring(title) .. (text ~= nil and text ~= "" and (": " .. tostring(text)) or ""))
	if SS.settings ~= nil and SS.settings.notes and SS.NoteFn ~= nil then
		pcall(SS.NoteFn, title, text)
	end
end

-- ---------------------------------------------------------------------------
-- keys: "Ctrl+Shift" (modifiers for the slot keys) or "Ctrl+Alt+L" (with a key)
local MODS = { ctrl = "ctrl", control = "ctrl", shift = "shift", alt = "alt" }
function SS.ParseKey(text, want_key)
	if type(text) ~= "string" then
		return nil
	end
	local b = { ctrl = false, shift = false, alt = false, key = nil }
	for part in text:gmatch("[^+%s]+") do
		local low = part:lower()
		if MODS[low] then
			b[MODS[low]] = true
		elseif b.key == nil and #part == 1 and part:match("[%w]") then
			b.key = part:upper()
		else
			return nil
		end
	end
	if want_key and b.key == nil then
		return nil
	end
	if not want_key and b.key ~= nil then
		return nil
	end
	if not (b.ctrl or b.shift or b.alt) then
		return nil -- a bare key would fire while playing
	end
	return b
end

local function Warn(key, v, default)
	SS.warnings[#SS.warnings + 1] = string.format("setting %s = %s isn't valid, using %s", key, tostring(v), tostring(default))
end

local function Num(s, key, lo, hi, whole)
	local v, default = s[key], SS.DEFAULTS[key]
	local n = tonumber(v)
	if n == nil or n ~= n or n < lo or n > hi or (whole and n ~= math.floor(n)) then
		if v ~= nil then
			Warn(key, v, default)
		end
		return default
	end
	return n
end

local function Bool(s, key)
	local v = s[key]
	if type(v) == "boolean" then
		return v
	end
	if v ~= nil then
		Warn(key, v, SS.DEFAULTS[key])
	end
	return SS.DEFAULTS[key]
end

-- one of a few words
local function Choice(s, key, list)
	local v = s[key]
	for _, c in ipairs(list) do
		if v == c then
			return v
		end
	end
	if v ~= nil then
		Warn(key, v, SS.DEFAULTS[key])
	end
	return SS.DEFAULTS[key]
end

local KEY_KINDS = {
	save = false, rebuild = false, replicate = false, -- modifiers only (+ the number row)
	latest_rebuild = true, latest_replicate = true, menu = true, -- with a key
}

function SS.LoadSettings(user)
	SS.warnings = {}
	local s = type(user) == "table" and user or {}
	local out = {}
	for _, k in ipairs({ "enabled", "keep_debug_text_size", "auto_save", "undo_before_load", "fade_load", "align_players", "same_room", "replicate_lend",
		"restore_loadout_after_run", "restore_counters", "exact_hp", "notes", "codex", "codex_tab_first", "pause_menu", "debug" }) do
		out[k] = Bool(s, k)
	end
	out.manual_history = Num(s, "manual_history", 0, 5000, true)
	out.auto_history = Num(s, "auto_history", 0, 1000, true)
	out.auto_save_delay = Num(s, "auto_save_delay", 0.1, 10, false)
	out.pause_menu_screen = Choice(s, "pause_menu_screen", { "full", "codex" })
	-- keys: each on its own; "" or false turns one off
	out.keys = {}
	local uk = type(s.keys) == "table" and s.keys or {}
	for kind, with_key in pairs(KEY_KINDS) do
		local v = uk[kind]
		if v == nil then
			v = SS.DEFAULTS.keys[kind]
		end
		if v == false or v == "" then
			out.keys[kind] = nil
		else
			local b = SS.ParseKey(v, with_key)
			if b == nil then
				Warn("keys." .. kind, v, SS.DEFAULTS.keys[kind])
				b = SS.ParseKey(SS.DEFAULTS.keys[kind], with_key)
			end
			out.keys[kind] = b
		end
	end
	-- two kinds of slot keys on the same modifiers: the later ones off
	local seen = {}
	for _, kind in ipairs({ "save", "rebuild", "replicate" }) do
		local b = out.keys[kind]
		if b ~= nil then
			local id = tostring(b.ctrl) .. tostring(b.shift) .. tostring(b.alt)
			if seen[id] then
				Warn("keys." .. kind, "the same modifiers as keys." .. seen[id], "off")
				out.keys[kind] = nil
			else
				seen[id] = kind
			end
		end
	end
	SS.settings = out
	return out
end

-- a short text for a binding: "Ctrl+Shift" or "Ctrl+Alt+L"
function SS.KeyText(b, slot_key)
	if b == nil then
		return "off"
	end
	local parts = {}
	if b.ctrl then parts[#parts + 1] = "Ctrl" end
	if b.shift then parts[#parts + 1] = "Shift" end
	if b.alt then parts[#parts + 1] = "Alt" end
	parts[#parts + 1] = b.key or slot_key or "1..0"
	return table.concat(parts, "+")
end

return SS
