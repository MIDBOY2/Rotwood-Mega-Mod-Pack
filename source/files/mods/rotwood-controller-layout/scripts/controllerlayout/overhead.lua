-- Controller Layout: what shows over the players' heads (one setting for all
-- players). The game shows, over each player (screens/playerhud.lua
-- _AttachPlayerToHud):
--   the health bar with the player's name under it (widgets/ftf/
--     playerfollowhealthbar.lua: on every hit and heal, ShowHealthBar),
--   the potion and its uses (playerfollowpotion.lua TryShowPotion: pressing
--     potion with none left, drinking at full health, a refill, a new room),
--   the name alone when you're behind something big (playerfollowid.lua
--     TryShowID).
-- Modes (Ctrl+H cycles them, a note at the side says which):
--   "game"       the game's own
--   "hp_potion"  the health bar and the potion, no names
--   "potion"     nothing over the heads but the potion, and only when you press
--                potion with none left
-- Only the game's own show calls are let through or not (when the game asks
-- for a bar / a name / the potion): nothing runs per frame. The choice is kept
-- for the next rooms and the next game start (a small file, the game's way).

local O = {}
O.TAG = "[Controller Layout]"
O.MODES = { "game", "hp_potion", "potion" }
O.LABELS = { game = "the game's", hp_potion = "health and potion", potion = "potion only (when empty)" }
O.FILE = "controllerlayout_overhead.txt"
O.DEFAULT_KEY = "Ctrl+H"

O.G = _G
O.mode = "game"
O.start = "game"
O.note = true
O.key = nil
O.input = nil
O.held = false
O.off = nil

local function Log(s)
	print(O.TAG .. " " .. s)
end
O.Log = Log

function O.Valid(mode)
	for _, m in ipairs(O.MODES) do
		if m == mode then
			return true
		end
	end
	return false
end

function O.Next(mode)
	for i, m in ipairs(O.MODES) do
		if m == mode then
			return O.MODES[i % #O.MODES + 1]
		end
	end
	return O.MODES[1]
end

-- "Ctrl+H" -> { key = "H", ctrl = true, shift = false, alt = false, text = "Ctrl+H" }
function O.ParseKey(text)
	if type(text) ~= "string" then
		return nil
	end
	local b = { ctrl = false, shift = false, alt = false, text = text }
	for part in text:gmatch("[^+]+") do
		local p = part:match("^%s*(.-)%s*$")
		local low = p:lower()
		if low == "ctrl" or low == "control" then
			b.ctrl = true
		elseif low == "shift" then
			b.shift = true
		elseif low == "alt" then
			b.alt = true
		elseif p ~= "" then
			if b.key ~= nil then
				return nil
			end
			b.key = p:upper()
		end
	end
	if b.key == nil then
		return nil
	end
	return b
end

function O.Setup(G, settings)
	O.G = G or _G
	settings = type(settings) == "table" and settings or {}
	local mode = settings.overhead
	if mode == nil then
		mode = "game"
	end
	if not O.Valid(mode) then
		Log("bad setting overhead = " .. tostring(mode) .. " (game, hp_potion or potion): using game")
		mode = "game"
	end
	O.start, O.mode = mode, mode
	local k = settings.overhead_key
	if k == nil then
		k = O.DEFAULT_KEY
	end
	if k == false or k == "" then
		O.key = nil
	else
		O.key = O.ParseKey(k)
		if O.key == nil then
			Log("bad setting overhead_key = " .. tostring(k) .. ' (like "Ctrl+H", or ""): using ' .. O.DEFAULT_KEY)
			O.key = O.ParseKey(O.DEFAULT_KEY)
		end
	end
	O.note = settings.overhead_note ~= false
	return true
end

----------------------------------------------------------------------------
-- The kept choice

function O.Load()
	local sim = rawget(O.G, "TheSim")
	if sim == nil or type(sim.GetPersistentString) ~= "function" then
		return false
	end
	local ok = pcall(sim.GetPersistentString, sim, O.FILE, function(is_file, text)
		if not is_file or type(text) ~= "string" then
			return
		end
		local mode, start = text:match("^%s*([%a_]+)%s*|%s*([%a_]+)")
		if O.Valid(mode) and start == O.start then
			O.mode = mode
			pcall(O.ApplyNow)
		end
	end)
	return ok
end

function O.Save()
	local sim = rawget(O.G, "TheSim")
	if sim == nil or type(sim.SetPersistentString) ~= "function" then
		return false
	end
	return (pcall(sim.SetPersistentString, sim, O.FILE, O.mode .. "|" .. O.start, false, function() end))
end

----------------------------------------------------------------------------
-- The game's show calls, let through or not

-- the player's potion uses left (nil: unknown)
function O.PotionsLeft(player)
	local pd = player ~= nil and player.components ~= nil and player.components.potiondrinker or nil
	if pd == nil or pd.GetRemainingPotionUses == nil then
		return nil
	end
	local ok, n = pcall(pd.GetRemainingPotionUses, pd)
	return ok and n or nil
end

-- may the potion show now? (potion mode: a press with none left)
function O.PotionAllowed(widget)
	if O.mode ~= "potion" then
		return true
	end
	local owner = widget.owner
	if type(owner) ~= "table" or rawget(owner, O.PRESSING_KEY) ~= true then
		return false
	end
	local left = O.PotionsLeft(owner)
	return left ~= nil and left <= 0
end

-- what's over a player's head now, for the mode (when it changes)
function O.ApplyTo(player)
	if O.mode == "game" then
		return
	end
	local id = player.follow_id
	if id ~= nil and id.Hide ~= nil then
		id:Hide()
	end
	local bar = player.follow_health_bar
	if bar ~= nil then
		if bar.username ~= nil and bar.username.Hide ~= nil then
			bar.username:Hide()
		end
		if O.mode == "potion" and bar.Hide ~= nil then
			bar:Hide()
		end
	end
	local pot = player.follow_potion
	if O.mode == "potion" and pot ~= nil and pot.Hide ~= nil then
		pot:Hide()
	end
end

function O.ApplyNow()
	local players = rawget(O.G, "AllPlayers")
	for _, p in ipairs(type(players) == "table" and players or {}) do
		pcall(O.ApplyTo, p)
	end
end

-- The hooks find the mod's part loaded now (kept on the class): the game
-- reloads mods for the next room, and a class hooked before keeps its hook.
O.CLASS_KEY = "controllerlayout_overhead"
O.PRESSING_KEY = "controllerlayout_pressing"

-- an error: the game's own for this room, said once
function O.Guard(what, fn, ...)
	if O.off ~= nil then
		return true
	end
	local ok, r = pcall(fn, ...)
	if not ok then
		O.off = tostring(r)
		Log("the overhead modes are the game's for this room (an error in " .. what .. "): " .. O.off)
		return true
	end
	return r
end

function O.BarAllowed()
	return O.mode ~= "potion"
end

function O.AfterBar(bar)
	if O.mode ~= "game" and bar.username ~= nil and bar.username.Hide ~= nil then
		bar.username:Hide()
	end
	return true
end

function O.IdAllowed()
	return O.mode == "game"
end

-- one class: its show call let through or not by the mod's part loaded now
local function HookClass(Class, method, what, allow_name, after_name)
	if type(Class) ~= "table" or type(Class[method]) ~= "function" then
		return false
	end
	local was = rawget(Class, O.CLASS_KEY)
	rawset(Class, O.CLASS_KEY, O)
	if was ~= nil then
		return true -- hooked by an earlier load: it finds this one now
	end
	local show = Class[method]
	Class[method] = function(self, ...)
		local cur = rawget(Class, O.CLASS_KEY)
		if cur ~= nil and not cur.Guard(what, cur[allow_name], self) then
			return
		end
		if after_name == nil or cur == nil then
			return show(self, ...)
		end
		local r = table.pack(show(self, ...))
		cur.Guard(what, cur[after_name], self)
		return table.unpack(r, 1, r.n)
	end
	return true
end

-- PlayerFollowHealthBar, PlayerFollowPotion, PlayerFollowID: the classes
function O.Hook(HealthBar, Potion, Id)
	local done = {}
	if HookClass(HealthBar, "ShowHealthBar", "the health bar", "BarAllowed", "AfterBar") then
		done[#done + 1] = "health bar"
	end
	if HookClass(Potion, "TryShowPotion", "the potion", "PotionAllowed") then
		done[#done + 1] = "potion"
	end
	if HookClass(Id, "TryShowID", "the name", "IdAllowed") then
		done[#done + 1] = "name"
	end
	return #done > 0, table.concat(done, ", ")
end

-- a player: its PeekFollowStatus (the game's: potion pressed, drinking at full
-- health...) marks it as pressing while it runs (kept on the player)
function O.SetupPlayer(inst)
	local peek = rawget(inst, "PeekFollowStatus")
	if type(peek) ~= "function" or rawget(inst, "controllerlayout_peek") then
		return false
	end
	rawset(inst, "controllerlayout_peek", true)
	local key = O.PRESSING_KEY
	inst.PeekFollowStatus = function(self, options, ...)
		local pressing = type(options) == "table" and options.show_potion == true
		if pressing then
			rawset(self, key, true)
		end
		local r = table.pack(pcall(peek, self, options, ...))
		if pressing then
			rawset(self, key, nil)
		end
		if not r[1] then
			error(r[2], 0)
		end
		return table.unpack(r, 2, r.n)
	end
	return true
end

----------------------------------------------------------------------------
-- The key

function O.Mods()
	local input, m = O.input, O.key.mods
	return {
		ctrl = m.ctrl ~= nil and input:IsKeyDown(m.ctrl) == true,
		shift = m.shift ~= nil and input:IsKeyDown(m.shift) == true,
		alt = m.alt ~= nil and input:IsKeyDown(m.alt) == true,
	}
end

function O.Matches()
	local k = O.key
	if k == nil or k.mods == nil or O.input == nil then
		return false
	end
	local m = O.Mods()
	return m.ctrl == k.ctrl and m.shift == k.shift and m.alt == k.alt
end

function O.Typing()
	local fe = rawget(O.G, "TheFrontEnd")
	return type(fe) == "table" and fe.forceProcessText == true
end

function O.Note()
	local fe = rawget(O.G, "TheFrontEnd")
	if type(fe) == "table" and type(fe.ShowTextNotification) == "function" then
		local how = O.key ~= nil and (O.key.text .. ": the game's, health and potion, potion only") or ""
		pcall(fe.ShowTextNotification, fe, nil, "Overhead: " .. O.LABELS[O.mode], how, 3)
	end
end

function O.Cycle()
	O.mode = O.Next(O.mode)
	O.Save()
	pcall(O.ApplyNow)
	Log("overhead: " .. O.LABELS[O.mode])
	if O.note then
		O.Note()
	end
end

function O.OnKeyDown()
	if O.held then
		return false
	end
	if O.Typing() or not O.Matches() then
		return false
	end
	O.held = true
	O.Cycle()
	return true
end

function O.OnKeyUp()
	O.held = false
end

function O.BindKey(G)
	local input = rawget(G, "TheInput")
	if type(input) == "table" and rawget(input, "_controllerlayout_overhead") ~= nil then
		rawset(input, "_controllerlayout_overhead", O) -- (an earlier load's handler asks this one now)
	end
	if O.key == nil then
		return "no key (overhead_key = \"\")"
	end
	local ic = rawget(G, "InputConstants")
	local Keys = type(ic) == "table" and ic.Keys or nil
	if type(input) ~= "table" or type(input.AddKeyDownHandler) ~= "function" or type(input.AddKeyUpHandler) ~= "function"
		or type(input.IsKeyDown) ~= "function" or type(Keys) ~= "table" then
		return "no key (the game's input changed)"
	end
	local function Code(name)
		local ok, code = pcall(function() return Keys[name] end)
		return ok and code or nil
	end
	local code = Code(O.key.key)
	if code == nil then
		return "no key (the game has no key " .. O.key.key .. ")"
	end
	O.key.code, O.key.mods, O.input = code, { ctrl = Code("CTRL"), shift = Code("SHIFT"), alt = Code("ALT") }, input
	rawset(input, "_controllerlayout_overhead", O)
	local bound = rawget(input, "_controllerlayout_overhead_codes")
	if bound == nil then
		bound = {}
		rawset(input, "_controllerlayout_overhead_codes", bound)
	end
	if not bound[code] then
		bound[code] = true
		local function Run(fn_name)
			local cur = rawget(input, "_controllerlayout_overhead")
			if cur ~= nil and cur.key ~= nil and cur.key.code == code then
				local ok, err = pcall(cur[fn_name])
				if not ok then
					cur.Log("the overhead key: " .. tostring(err))
				end
			end
		end
		input:AddKeyDownHandler(code, function() Run("OnKeyDown") end)
		input:AddKeyUpHandler(code, function() Run("OnKeyUp") end)
	end
	return O.key.text .. " cycles it"
end

-- the game's debug keys (on when cheats are): Ctrl+H there hides the props
-- (Ctrl+Shift+H too); an exact Ctrl+H press doesn't reach them
function O.WrapDebugKeys(G)
	if rawget(G, "_controllerlayout_overhead_debugkeys") ~= nil then
		rawset(G, "_controllerlayout_overhead_debugkeys", O) -- (the wrap asks this load)
	end
	if O.key == nil or O.key.code == nil then
		return false, "no key"
	end
	local orig = rawget(G, "DoDebugKey")
	if type(orig) ~= "function" then
		return false, "the debug keys aren't on"
	end
	-- (wrapped once; the wrap asks the part loaded now)
	local wrapped = rawget(G, "_controllerlayout_overhead_debugkeys") ~= nil
	rawset(G, "_controllerlayout_overhead_debugkeys", O)
	if wrapped then
		return true, "already"
	end
	rawset(G, "DoDebugKey", function(key, down, ...)
		local cur = rawget(G, "_controllerlayout_overhead_debugkeys") or O
		local k = cur.key
		if k ~= nil and key == k.code and cur.input ~= nil then
			local ok, match = pcall(cur.Matches)
			if ok and match then
				return true
			end
		end
		return orig(key, down, ...)
	end)
	return true, "the key doesn't reach the debug keys"
end

-- after the game's start: the widget classes hooked, the key
function O.Install(G)
	O.G = G or O.G
	local req = rawget(O.G, "require") or require
	local okh, HealthBar = pcall(req, "widgets/ftf/playerfollowhealthbar")
	local okp, Potion = pcall(req, "widgets/ftf/playerfollowpotion")
	local oki, Id = pcall(req, "widgets/ftf/playerfollowid")
	local hooked, what = O.Hook(okh and HealthBar or nil, okp and Potion or nil, oki and Id or nil)
	if not hooked then
		return false, "the game's overhead widgets changed"
	end
	pcall(O.ApplyNow)
	local keytext = O.BindKey(O.G)
	pcall(O.WrapDebugKeys, O.G)
	return true, O.LABELS[O.mode] .. " (" .. what .. "); " .. keytext
end

return O
