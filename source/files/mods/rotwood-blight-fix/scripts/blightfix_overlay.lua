-- Blight Fix: the Blight's purple overlay.
-- The game (screens/playerhud.lua) gives the HUD a full screen effect,
-- effects.trek_overlay (widgets/fullscreeneffect.lua, the trekoverlay1
-- picture), and loops it the whole Blight outside the Rest Rooms: its alpha
-- eases between 0.65 and 1 (PlayerHud:OnTrekStateChanged(true), called by
-- the HUD's constructor in every Blight room).
-- Here the game's loop runs as it is. The overlay widget gets its own colour
-- alpha (Widget:SetMultColorAlpha), and the game's widget code multiplies it
-- into the picture's alpha each time the loop sets it
-- (Widget:GetResolvedMultColor). So nothing runs per frame that the game
-- doesn't already run:
--   faded    the overlay at `faded` of its strength (0.10 = 10%)
--   vanilla  the game's own (alpha 1)
--   none     the game's loop stopped and the overlay hidden (nothing drawn,
--            no loop running)
-- A key (Ctrl+B) cycles faded -> vanilla -> none. The choice is kept in a
-- small file (TheSim:SetPersistentString, the game's way for small files):
-- the game reloads the mods for every room, and the next rooms and the next
-- game start keep the choice.

local O = {}
O.TAG = "[Blight Fix]"
O.MODES = { "faded", "vanilla", "none" }
O.FILE = "blightfix_overlay.txt"
O.DEFAULT_FADED = 0.10
O.DEFAULT_KEY = "Ctrl+B"

O.G = _G
O.mode = "faded"   -- now
O.start = "faded"  -- the settings' overlay (a kept choice counts while it's the same)
O.faded = O.DEFAULT_FADED
O.note = true
O.key = nil        -- { key = "B", ctrl, shift, alt, text, code, mods = { ctrl, shift, alt } }
O.input = nil
O.held = false
O.off = nil        -- why this part turned off for this room (an error)
O.loaded = false

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

-- the overlay widget's own colour alpha for a mode
function O.Alpha(mode)
	if mode == "faded" then
		return O.faded
	elseif mode == "none" then
		return 0
	end
	return 1
end

function O.Label(mode)
	if mode == "faded" then
		return string.format("faded (%d%%)", math.floor(O.faded * 100 + 0.5))
	elseif mode == "none" then
		return "off"
	end
	return "the game's own"
end

-- "Ctrl+B" -> { key = "B", ctrl = true, shift = false, alt = false, text = "Ctrl+B" }
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

-- the settings (a bad one: its default, logged)
function O.Setup(G, settings)
	O.G = G or _G
	settings = type(settings) == "table" and settings or {}
	local mode = settings.overlay
	if mode == nil then
		mode = "faded"
	end
	if not O.Valid(mode) then
		Log("bad setting overlay = " .. tostring(mode) .. " (faded, vanilla, none or false): using faded")
		mode = "faded"
	end
	O.start, O.mode = mode, mode
	local f = settings.overlay_faded
	if f == nil then
		f = O.DEFAULT_FADED
	end
	if type(f) ~= "number" or f ~= f or f < 0 or f > 1 then
		Log("bad setting overlay_faded = " .. tostring(f) .. " (0 .. 1): using " .. O.DEFAULT_FADED)
		f = O.DEFAULT_FADED
	end
	O.faded = f
	local k = settings.overlay_key
	if k == nil then
		k = O.DEFAULT_KEY
	end
	if k == false then
		O.key = nil
	else
		O.key = O.ParseKey(k)
		if O.key == nil then
			Log("bad setting overlay_key = " .. tostring(k) .. ' (like "Ctrl+B", or false): using ' .. O.DEFAULT_KEY)
			O.key = O.ParseKey(O.DEFAULT_KEY)
		end
	end
	O.note = settings.overlay_note ~= false
	return true
end

----------------------------------------------------------------------------
-- The kept choice (a small file in the game's save folder)

function O.Load()
	local sim = rawget(O.G, "TheSim")
	if sim == nil or type(sim.GetPersistentString) ~= "function" then
		O.loaded = true
		return false
	end
	local ok, err = pcall(sim.GetPersistentString, sim, O.FILE, function(is_file, text)
		local ok2, err2 = pcall(O.OnLoaded, is_file, text)
		if not ok2 then
			Log("the Blight overlay: reading the kept choice: " .. tostring(err2))
		end
	end)
	if not ok then
		O.loaded = true
		Log("the Blight overlay: couldn't read the kept choice: " .. tostring(err))
	end
	return ok
end

function O.OnLoaded(is_file, text)
	O.loaded = true
	if not is_file or type(text) ~= "string" then
		return
	end
	local mode, start = text:match("^%s*(%a+)%s*|%s*(%a+)")
	-- kept while the settings' overlay is the one it was kept with
	if O.Valid(mode) and start == O.start and mode ~= O.mode then
		O.mode = mode
		-- the game read it after the HUD was made: set it now
		local hud = O.Hud()
		if hud ~= nil and O.off == nil then
			local ok, err = pcall(O.Apply, hud, true)
			if not ok then
				O.TurnOff(err, hud)
			end
		end
	end
end

function O.Save()
	local sim = rawget(O.G, "TheSim")
	if sim == nil or type(sim.SetPersistentString) ~= "function" then
		return false
	end
	local ok, err = pcall(sim.SetPersistentString, sim, O.FILE, O.mode .. "|" .. O.start, false, function(success)
		if success == false then
			Log("the Blight overlay: couldn't keep the choice (the file)")
		end
	end)
	if not ok then
		Log("the Blight overlay: couldn't keep the choice: " .. tostring(err))
	end
	return ok
end

----------------------------------------------------------------------------
-- The overlay

function O.Hud()
	local d = rawget(O.G, "TheDungeon")
	local hud = type(d) == "table" and d.HUD or nil
	return type(hud) == "table" and hud or nil
end

function O.Effect(hud)
	local effects = type(hud) == "table" and hud.effects or nil
	local fx = type(effects) == "table" and effects.trek_overlay or nil
	if type(fx) == "table" and type(fx.SetLooping) == "function" and type(fx.Hide) == "function" then
		return fx
	end
	return nil
end

-- does the game want the overlay in this room? (its last OnTrekStateChanged)
function O.Wanted(hud)
	local w = rawget(hud, "blightfix_trek_wanted")
	if type(w) == "boolean" then
		return w
	end
	-- a HUD made before the hook: the game's own test (PlayerHud's constructor)
	local d = rawget(O.G, "TheDungeon")
	local ok, res = pcall(function()
		return d:GetTrek():IsActive() and not d:IsInRestRoom()
	end)
	return ok and res == true
end

-- the game's loop stopped right away (StopLooping would fade it out over 3
-- seconds in a series nobody can stop, which would hide a loop started again
-- in those 3 seconds)
function O.StopNow(fx)
	if fx.updater ~= nil and type(fx.StopUpdater) == "function" then
		fx:StopUpdater(fx.updater)
	end
	fx.updater = nil
	fx.resume_screen_flash_fn = nil
	if type(fx.SetAlpha) == "function" then
		fx:SetAlpha(0)
	end
	fx:Hide()
end

-- the mode on the HUD's overlay; start: may start the game's loop (when the
-- game wants the overlay and none runs)
function O.Apply(hud, start)
	local fx = O.Effect(hud)
	if fx == nil then
		return false
	end
	if type(fx.SetMultColorAlpha) == "function" then
		fx:SetMultColorAlpha(O.Alpha(O.mode))
	end
	if O.mode == "none" then
		O.StopNow(fx)
	elseif start and fx.updater == nil and O.Wanted(hud) then
		fx:SetLooping(true)
	end
	return true
end

-- an error: the game's own overlay for this room (logged)
function O.TurnOff(err, hud)
	O.off = tostring(err)
	Log("the Blight overlay is the game's own for this room (an error): " .. O.off)
	local fx = O.Effect(hud or O.Hud())
	if fx ~= nil and type(fx.SetMultColorAlpha) == "function" then
		pcall(fx.SetMultColorAlpha, fx, 1)
	end
end

-- the game calls it (the HUD's constructor) to start the loop in a Blight room
function O.OnTrek(hud, showing)
	if type(showing) == "boolean" then
		rawset(hud, "blightfix_trek_wanted", showing)
	end
	O.Apply(hud, false)
end

function O.Hook(PlayerHud)
	if type(PlayerHud) ~= "table" or type(PlayerHud.OnTrekStateChanged) ~= "function" then
		return false, "the game's HUD changed (PlayerHud.OnTrekStateChanged not found)"
	end
	-- the hook asks the Blight Fix loaded now (hooked once per HUD class)
	rawset(PlayerHud, "blightfix_overlay_current", O)
	if rawget(PlayerHud, "blightfix_overlay") ~= nil then
		return true, "already on"
	end
	local orig = PlayerHud.OnTrekStateChanged
	rawset(PlayerHud, "blightfix_overlay", orig)
	PlayerHud.OnTrekStateChanged = function(self, showing, ...)
		local cur = rawget(PlayerHud, "blightfix_overlay_current") or O
		if cur.off == nil then
			local ok, err = pcall(cur.OnTrek, self, showing)
			if not ok then
				cur.TurnOff(err, self)
			elseif showing == true and cur.mode == "none" then
				-- off: the game's loop doesn't start
				return orig(self, false, ...)
			end
		end
		return orig(self, showing, ...)
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

-- the key's modifiers, matched exactly (Ctrl+Shift+B isn't Ctrl+B)
function O.Matches()
	local k = O.key
	if k == nil or k.mods == nil or O.input == nil then
		return false
	end
	local m = O.Mods()
	return m.ctrl == k.ctrl and m.shift == k.shift and m.alt == k.alt
end

-- the console or a text box has the keyboard
function O.Typing()
	local fe = rawget(O.G, "TheFrontEnd")
	return type(fe) == "table" and fe.forceProcessText == true
end

function O.Note()
	local fe = rawget(O.G, "TheFrontEnd")
	if type(fe) == "table" and type(fe.ShowTextNotification) == "function" then
		local how = O.key ~= nil and (O.key.text .. ": faded, the game's own, off") or ""
		pcall(fe.ShowTextNotification, fe, nil, "Blight overlay: " .. O.Label(O.mode), how, 3)
	end
end

function O.Cycle()
	O.mode = O.Next(O.mode)
	O.Save()
	if O.off == nil then
		local hud = O.Hud()
		if hud ~= nil then
			local ok, err = pcall(O.Apply, hud, true)
			if not ok then
				O.TurnOff(err, hud)
			end
		end
	end
	Log("the Blight overlay: " .. O.Label(O.mode) .. (O.off ~= nil and " (from the next room)" or ""))
	if O.note then
		O.Note()
	end
end

function O.OnKeyDown()
	-- one change a press (a held key doesn't keep cycling)
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

-- one key handler per key and input object; a press reaches the Blight Fix
-- loaded now
function O.BindKey(G)
	local input = rawget(G, "TheInput")
	if type(input) == "table" and rawget(input, "_blightfix_overlay") ~= nil then
		rawset(input, "_blightfix_overlay", O) -- (an earlier load's handler asks this one now)
	end
	if O.key == nil then
		return "no key (overlay_key = false)"
	end
	local ic = rawget(G, "InputConstants")
	if ic == nil and type(rawget(G, "require")) == "function" then
		pcall(G.require, "input.inputconstants") -- (it sets the global)
		ic = rawget(G, "InputConstants")
	end
	local Keys = type(ic) == "table" and ic.Keys or nil
	if type(input) ~= "table" or type(input.AddKeyDownHandler) ~= "function" or type(input.AddKeyUpHandler) ~= "function"
		or type(input.IsKeyDown) ~= "function" or type(Keys) ~= "table" then
		return "no key (the game's input changed)"
	end
	-- (the game's key list errors on a name it doesn't have)
	local function Code(name)
		local ok, code = pcall(function() return Keys[name] end)
		return ok and code or nil
	end
	local code = Code(O.key.key)
	if code == nil then
		return "no key (the game has no key " .. O.key.key .. ")"
	end
	local mods = { ctrl = Code("CTRL"), shift = Code("SHIFT"), alt = Code("ALT") }
	if (O.key.ctrl and mods.ctrl == nil) or (O.key.shift and mods.shift == nil) or (O.key.alt and mods.alt == nil) then
		return "no key (the game's key list has no Ctrl / Shift / Alt)"
	end
	O.key.code, O.key.mods, O.input = code, mods, input
	rawset(input, "_blightfix_overlay", O)
	local bound = rawget(input, "_blightfix_overlay_codes")
	if bound == nil then
		bound = {}
		rawset(input, "_blightfix_overlay_codes", bound)
	end
	if not bound[code] then
		bound[code] = true
		local function Run(fn_name)
			local cur = rawget(input, "_blightfix_overlay")
			if cur ~= nil and cur.key ~= nil and cur.key.code == code then
				local ok, err = pcall(cur[fn_name])
				if not ok then
					cur.Log("the Blight overlay key: " .. tostring(err))
				end
			end
		end
		input:AddKeyDownHandler(code, function() Run("OnKeyDown") end)
		input:AddKeyUpHandler(code, function() Run("OnKeyUp") end)
	end
	return O.key.text .. " cycles it"
end

-- the game's debug keys (on when cheats are): Ctrl+B there toggles the
-- debug AABB drawing; our presses don't reach them
function O.WrapDebugKeys(G)
	if rawget(G, "_blightfix_debugkeys") ~= nil then
		rawset(G, "_blightfix_debugkeys", O) -- (the wrap asks this load)
	end
	if O.key == nil then
		return false, "no key"
	end
	local orig = rawget(G, "DoDebugKey")
	if type(orig) ~= "function" then
		return false, "the debug keys aren't on"
	end
	-- (wrapped once; the wrap asks the Blight Fix loaded now)
	local wrapped = rawget(G, "_blightfix_debugkeys") ~= nil
	rawset(G, "_blightfix_debugkeys", O)
	if wrapped then
		return true, "already"
	end
	rawset(G, "DoDebugKey", function(key, down, ...)
		local cur = rawget(G, "_blightfix_debugkeys") or O
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

-- after the game's start (GamePostInit): the HUD hook, a HUD already made,
-- the key
function O.Install(G)
	O.G = G or O.G
	local req = rawget(O.G, "require") or require
	local ok, PlayerHud = pcall(req, "screens.playerhud")
	if not ok then
		return false, "couldn't load the game's HUD: " .. tostring(PlayerHud)
	end
	local hooked, why = O.Hook(PlayerHud)
	if not hooked then
		return false, why
	end
	-- a HUD made before the hook (not the game's order today): set it now
	local hud = O.Hud()
	if hud ~= nil then
		local ok_a, err = pcall(O.Apply, hud, true)
		if not ok_a then
			O.TurnOff(err, hud)
		end
	end
	local keytext = O.BindKey(O.G)
	return true, O.Label(O.mode) .. "; " .. keytext
end

return O
