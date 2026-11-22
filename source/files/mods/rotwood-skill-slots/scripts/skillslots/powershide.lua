-- Skill Slots: hide / show the power rows of the HUD (the icons of your
-- powers at the top of the screen), always with a smooth fade (the game's own:
-- Widget:AlphaTo, on the UI's clock, so it runs while paused too).
--  * D-pad down (hide_powers.gamepad): that player's own rows, hidden / shown.
--    In runs only: in town the game hides the rows anyway (and D-pad down is
--    the build menu there with Controller Layout).
--  * keyboard (hide_powers.hide_all / show_all, ; and ' by default): every
--    player's rows. (Keys nothing else uses, the game's debug keys included:
--    0.15.0 had - and =, which the debug keys also use: = hid the ground.)
--  * boss_auto_hide: when a boss wakes up (the game's "bossactivated", as its
--    health bar comes up) every player's rows fade out; when it's beaten (its
--    "bossdeactivated" with no other boss still up) or the room is cleared,
--    they fade back in. Showing them yourself during the fight keeps them
--    shown for that fight. "boss" = boss fights, "all" = minibosses too,
--    false = never.
-- Each player's own choice (hidden / shown) is kept with their character
-- (skillslotsdata, option powers_hidden), so it stays from room to room.
-- Faded out, the rows are hidden at the end of the fade (the game's Hide, as
-- in town: no tooltips from invisible icons, the HUD's layout unchanged).
--
-- Smaller (0.16.0, sizes 0.16.2): D-pad up (hide_powers.small_gamepad) steps
-- that player's power icons through small_sizes (default 66%, then 50%) and
-- back to full size. Smaller icons take more rows in the same height: the
-- game's 2 rows become 3 at 66%, 4 at 50% (rows = 2 / size), filled evenly by
-- the game's own row filling (12 powers: 3 rows of 4, 4 rows of 3), so they
-- stack in a block next to the skills instead of two long rows (the user's
-- mockup, 22:53). Keyboard / (small_all): every player's, the next size. In runs only (in
-- town D-pad up is customize town). A cross-fade: out, the new size laid out
-- by the game's own layout (the rows' scale set before it lines them up, so
-- they stay against the skill icons), back in. Kept with the character too
-- (option powers_small).
local Core = require "skillslots.core"

local PH = {}

PH.FADE = 0.35
PH.OPTION = "powers_hidden"
PH.CONTROL = "SKILLSLOTS_POWERS"
PH.DEFAULTS = { gamepad = "DPAD_DOWN", hide_all = "SEMICOLON", show_all = "QUOTE", boss_auto_hide = "all", fade_time = 0.35,
	small_gamepad = "DPAD_UP", small_all = "SLASH", small_sizes = { 0.66, 0.5 } }
PH.BASE_ROWS = 2 -- the game's rows (it keeps 2, more only when they're full)
PH.MAX_ROWS = 6
PH.OPTION_SMALL = "powers_small"
PH.CONTROL_SMALL = "SKILLSLOTS_POWERS_SIZE"
PH.control_small = nil
PH.widgets = setmetatable({}, { __mode = "k" }) -- powers widget -> true
PH.control = nil
PH.errors = 0

local function Log(msg)
	if PH.errors < 10 then
		PH.errors = PH.errors + 1
		Core.Log("powers hide: " .. tostring(msg))
	end
end

function PH.Settings()
	local s = Core.settings ~= nil and Core.settings.hide_powers or nil
	return type(s) == "table" and s or PH.DEFAULTS
end

local function FadeTime()
	local t = tonumber(PH.Settings().fade_time)
	if t == nil then
		return PH.FADE
	end
	return math.max(0, math.min(3, t))
end

local function State(w)
	local s = rawget(w, "skillslots_hide")
	if s == nil then
		s = { manual = false, auto = false, override = false, small = 0 } -- small: 0 = full size, else the size's number
		rawset(w, "skillslots_hide", s)
	end
	return s
end

function PH.IsHidden(w)
	local s = State(w)
	return s.manual or (s.auto and not s.override)
end

local function Easing()
	local ok, easing = pcall(require, "util.easing")
	return ok and type(easing) == "table" and (easing.inOutQuad or easing.linear) or nil
end

-- The rows faded to the state's look (instant: at once, no fade).
function PH.Apply(w, instant)
	local root = rawget(w, "powers_root")
	if root == nil then
		return
	end
	local hidden = PH.IsHidden(w)
	if rawget(w, "skillslots_powers_hidden") == hidden and not instant then
		return
	end
	rawset(w, "skillslots_powers_hidden", hidden)
	local t = instant and 0 or FadeTime()
	local ease = Easing()
	local can_fade = t > 0 and root.AlphaTo ~= nil and ease ~= nil
	if hidden then
		if not can_fade or not root:IsShown() then
			root:SetMultColorAlpha(0)
			root:Hide()
			return
		end
		root:AlphaTo(0, t, ease, function()
			if rawget(w, "skillslots_powers_hidden") then
				root:Hide()
			end
		end)
	else
		if rawget(w, "skillslots_in_town") then
			root:SetMultColorAlpha(1) -- the game shows them when you leave town
			return
		end
		if not can_fade then
			root:SetMultColorAlpha(1)
			root:Show()
			return
		end
		if not root:IsShown() then
			root:SetMultColorAlpha(0)
		end
		root:AlphaTo(1, t, ease) -- (shows it first: the game's AlphaTo)
	end
end

local function Save(w)
	local owner = rawget(w, "owner")
	local data = owner ~= nil and owner.components ~= nil and owner.components.skillslotsdata or nil
	if data ~= nil and data.SetOption ~= nil then
		data:SetOption(PH.OPTION, State(w).manual)
		data:SetOption(PH.OPTION_SMALL, State(w).small)
	end
end

----------------------------------------------------------------------------
-- Half size

-- the smaller sizes, in order (small_sizes; an old small_scale alone: that one)
function PH.Sizes()
	local st = PH.Settings()
	local list = type(st.small_sizes) == "table" and st.small_sizes or nil
	if list == nil and tonumber(st.small_scale) ~= nil then
		list = { st.small_scale }
	end
	local out = {}
	for _, v in ipairs(list or PH.DEFAULTS.small_sizes) do
		local k = tonumber(v)
		if k ~= nil and k >= 0.2 and k < 1 and #out < 4 then
			out[#out + 1] = k
		end
	end
	if #out == 0 then
		out[1] = 0.5
	end
	return out
end
function PH.SmallScale() -- the smallest (0.16.0's one size)
	local sizes = PH.Sizes()
	return sizes[#sizes]
end

-- a saved / asked size as a number: 0 = full; true (0.16.0's "small") = the smallest
local function Level(v)
	local n = #PH.Sizes()
	if v == true then
		return n
	end
	v = math.floor(tonumber(v) or 0)
	return (v >= 1 and v <= n) and v or 0
end
PH.Level = Level

-- the rows' size for this player (1 or its smaller size): read by the layout
-- (hud.lua's cluster scale and the game's own)
function PH.Factor(w)
	local level = Level(State(w).small)
	return level > 0 and PH.Sizes()[level] or 1
end

-- how many rows at a size: the game's 2 rows' height (66%: 3, 50%: 4); nil = full size
function PH.RowsFor(k)
	if k == nil or k >= 1 then
		return nil
	end
	return math.max(PH.BASE_ROWS, math.min(PH.MAX_ROWS, math.floor(PH.BASE_ROWS / k + 0.05)))
end

-- the new size laid out by the game's layout (Layout + the HUD's refresh);
-- back to full size: the game's own trim back to its 2 rows
local function LayOut(w)
	local k = PH.Factor(w)
	local rows = PH.RowsFor(k)
	local was = rawget(w, "skillslots_power_rows")
	rawset(w, "skillslots_power_factor", k)
	rawset(w, "skillslots_power_rows", rows)
	if w._LayoutPowers ~= nil then
		w:_LayoutPowers(rows == nil and was ~= nil or (rows ~= nil and was ~= nil and rows < was))
	end
end

-- Before the game's Layout fills the rows: a smaller size has its rows ready
-- (the game's AddPowerRow; it fills the emptiest row first, so they fill
-- evenly), and the game's trim (reset_rows: back to its 2) trims to them
-- instead: rows past them have their icons put back on the powers' root (as
-- the game's Layout does with every row) before they go. The reset_rows the
-- game should use.
function PH.ReadyRows(w, reset_rows)
	local n = rawget(w, "skillslots_power_rows")
	local rows = rawget(w, "power_rows_idx")
	local root = rawget(w, "powers_root")
	if type(n) ~= "number" or type(rows) ~= "table" or root == nil or type(w.AddPowerRow) ~= "function" then
		return reset_rows
	end
	if reset_rows then
		for i = #rows, n + 1, -1 do
			local row = rows[i]
			local kids = {}
			for _, c in ipairs(type(row.children) == "table" and row.children or {}) do
				kids[#kids + 1] = c
			end
			for _, c in ipairs(kids) do
				c:Reparent(root)
			end
			row:Remove()
			table.remove(rows, i)
		end
	end
	for _ = #rows + 1, n do
		w:AddPowerRow()
	end
	return false
end

local function Updater()
	local ok, U = pcall(require, "widgets.updater")
	return ok and type(U) == "table" and U.Series ~= nil and U.Wait ~= nil and U.Do ~= nil and U or nil
end

function PH.SetSmall(w, small, instant)
	local s = State(w)
	s.small = Level(small)
	Save(w)
	local root = rawget(w, "powers_root")
	if root == nil then
		return
	end
	local t = instant and 0 or FadeTime()
	local U = Updater()
	local ease = Easing()
	-- hidden (by you, a boss fight or the town), or no fade: at once
	if t <= 0 or U == nil or ease == nil or root.RunUpdater == nil or root.AlphaTo == nil or not root:IsShown()
		or rawget(w, "skillslots_powers_hidden") then
		LayOut(w)
		return
	end
	local half = t / 2
	root:AlphaTo(0, half, ease)
	if rawget(w, "skillslots_size_job") ~= nil and root.StopUpdater ~= nil then
		pcall(root.StopUpdater, root, rawget(w, "skillslots_size_job"))
	end
	local job = U.Series({ U.Wait(half), U.Do(function()
		rawset(w, "skillslots_size_job", nil)
		local ok, err = pcall(LayOut, w)
		if not ok then
			Log(err)
		end
		-- (hidden meanwhile: it stays hidden)
		if rawget(w, "skillslots_powers_hidden") then
			root:SetMultColorAlpha(0)
			root:Hide()
		elseif not rawget(w, "skillslots_in_town") then
			root:AlphaTo(1, half, ease)
		end
	end) })
	rawset(w, "skillslots_size_job", job)
	root:RunUpdater(job)
end

-- the next size: full, then each smaller one, then full again
local function NextLevel(level)
	return (Level(level) + 1) % (#PH.Sizes() + 1)
end
function PH.ToggleSmall(w)
	PH.SetSmall(w, NextLevel(State(w).small))
end

-- every player's: one step on from the biggest of them, all the same size
-- (one size: all small unless they all are already)
function PH.AllSmall()
	local low = nil
	for w in pairs(PH.widgets) do
		local l = Level(State(w).small)
		low = (low == nil or l < low) and l or low
	end
	local level = NextLevel(low or 0)
	for w in pairs(PH.widgets) do
		if w.inst == nil or w.inst.IsValid == nil or w.inst:IsValid() then
			PH.SetSmall(w, level)
		end
	end
end

-- that player's choice: hidden (true) / shown (false)
function PH.Set(w, hidden)
	local s = State(w)
	s.manual = hidden == true
	if not hidden then
		s.override = s.auto -- shown during a boss fight: stays shown for it
	end
	Save(w)
	PH.Apply(w)
end

function PH.Toggle(w)
	PH.Set(w, not PH.IsHidden(w))
end

function PH.WidgetOf(player)
	for w in pairs(PH.widgets) do
		if rawget(w, "owner") == player and (w.inst == nil or w.inst.IsValid == nil or w.inst:IsValid()) then
			return w
		end
	end
	return nil
end

function PH.All(hidden)
	for w in pairs(PH.widgets) do
		if w.inst == nil or w.inst.IsValid == nil or w.inst:IsValid() then
			PH.Set(w, hidden)
		end
	end
end

----------------------------------------------------------------------------
-- Boss fights

local function IsBossFight(bosses)
	local mode = PH.Settings().boss_auto_hide
	if mode == false or mode == nil or mode == "none" then
		return false
	end
	if mode == "all" then
		return true
	end
	for _, ent in ipairs(type(bosses) == "table" and bosses or {}) do
		if type(ent) == "table" and ent.HasTag ~= nil and ent:HasTag("boss") then
			return true
		end
	end
	return false
end

local function AnyBossUp(bosses)
	for _, ent in ipairs(type(bosses) == "table" and bosses or {}) do
		local b = type(ent) == "table" and ent.components ~= nil and ent.components.boss or nil
		local alive = ent.IsAlive == nil or ent:IsAlive()
		if b ~= nil and b.has_activated and alive and (ent.IsValid == nil or ent:IsValid()) then
			return true
		end
	end
	return false
end

function PH.OnBossUp(w, bosses)
	if not IsBossFight(bosses) then
		return
	end
	local s = State(w)
	if not s.auto then
		s.auto, s.override = true, false
		PH.Apply(w)
	end
end

function PH.OnBossDown(w, bosses)
	local s = State(w)
	if s.auto and not AnyBossUp(bosses) then
		s.auto, s.override = false, false
		PH.Apply(w)
	end
end

function PH.OnRoomDone(w)
	local s = State(w)
	if s.auto then
		s.auto, s.override = false, false
		PH.Apply(w)
	end
end

----------------------------------------------------------------------------
-- A new powers widget (each player's HUD; made again with each room)

function PH.Attach(w)
	if rawget(w, "powers_root") == nil or PH.widgets[w] then
		return
	end
	PH.widgets[w] = true
	local owner = rawget(w, "owner")
	local data = owner ~= nil and owner.components ~= nil and owner.components.skillslotsdata or nil
	local s = State(w)
	s.manual = data ~= nil and type(data.options) == "table" and data.options[PH.OPTION] == true
	s.small = Level(data ~= nil and type(data.options) == "table" and data.options[PH.OPTION_SMALL] or 0)
	if s.small > 0 then
		local ok, err = pcall(LayOut, w)
		if not ok then
			Log(err)
		end
	end
	PH.Apply(w, true)
	local world = rawget(_G, "TheWorld")
	if world ~= nil and w.inst ~= nil and w.inst.ListenForEvent ~= nil then
		local function Guard(fn)
			return function(_, data_)
				local ok, err = pcall(fn, w, data_)
				if not ok then
					Log(err)
				end
			end
		end
		w.inst:ListenForEvent("bossactivated", Guard(PH.OnBossUp), world)
		w.inst:ListenForEvent("bossdeactivated", Guard(PH.OnBossDown), world)
		w.inst:ListenForEvent("room_complete", Guard(PH.OnRoomDone), world)
	end
end

local function InTown()
	local d = rawget(_G, "TheDungeon")
	if d == nil or d.IsInTown == nil then
		return false
	end
	local ok, town = pcall(d.IsInTown, d)
	return ok and town == true
end

----------------------------------------------------------------------------
-- Keys

local function ParseKey(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local b = { ctrl = false, shift = false, alt = false }
	for part in text:gmatch("[^+]+") do
		local p = part:gsub("^%s+", ""):gsub("%s+$", "")
		local u = p:upper()
		if u == "CTRL" then
			b.ctrl = true
		elseif u == "SHIFT" then
			b.shift = true
		elseif u == "ALT" then
			b.alt = true
		else
			b.key = u
		end
	end
	return b.key ~= nil and b or nil
end
PH.ParseKey = ParseKey

local function Typing()
	local fe = rawget(_G, "TheFrontEnd")
	return fe ~= nil and fe.forceProcessText == true
end

function PH.OnKey(b, hidden)
	if Typing() then
		return
	end
	local I, Keys = TheInput, PH.Keys
	if Keys ~= nil and I ~= nil and I.IsKeyDown ~= nil then
		local m = { ctrl = I:IsKeyDown(Keys.CTRL) == true, shift = I:IsKeyDown(Keys.SHIFT) == true, alt = I:IsKeyDown(Keys.ALT) == true }
		if m.ctrl ~= b.ctrl or m.shift ~= b.shift or m.alt ~= b.alt then
			return
		end
	end
	if hidden == "small" then
		if not InTown() then
			PH.AllSmall()
		end
		return
	end
	PH.All(hidden)
end

function PH.BindKeys(Keys)
	local s = PH.Settings()
	local bound = {}
	if TheInput == nil or TheInput.AddKeyDownHandler == nil or type(Keys) ~= "table" then
		return bound
	end
	PH.Keys = Keys
	for _, which in ipairs({ "hide_all", "show_all", "small_all" }) do
		local b = ParseKey(s[which])
		if b ~= nil then
			local ok, code = pcall(function() return Keys[b.key] end)
			if ok and code ~= nil then
				local hidden = which == "hide_all"
				if which == "small_all" then
					hidden = "small"
				end
				TheInput:AddKeyDownHandler(code, function()
					local okk, err = pcall(PH.OnKey, b, hidden)
					if not okk then
						Log(err)
					end
				end)
				bound[#bound + 1] = which .. " " .. tostring(s[which])
			else
				Log(which .. ": the game has no key " .. tostring(s[which]))
			end
		end
	end
	return bound
end

----------------------------------------------------------------------------
-- The D-pad button (a control of its own, each player's controller)

-- a control of ours on a gamepad button (D-pad walking freed from it)
function PH.AddButton(name, button)
	if type(button) ~= "string" or button == "" then
		return nil
	end
	local digital = Controls.Digital
	local control = rawget(digital, name)
	if control == nil then
		control = { key = "Controls.Digital." .. name, shortkey = name }
		rawset(digital, name, control)
	end
	TheInput:ResetControlState()
	-- a D-pad button walks only when the stick is idle: freed for this
	local moves = { DPAD_UP = "MOVE_UP", DPAD_DOWN = "MOVE_DOWN", DPAD_LEFT = "MOVE_LEFT", DPAD_RIGHT = "MOVE_RIGHT" }
	local move = moves[button]
	if move ~= nil and rawget(digital, move) ~= nil and TheInput._RemoveGamepadButtonBind ~= nil then
		pcall(TheInput._RemoveGamepadButtonBind, TheInput, digital[move])
	end
	if TheInput.gamepad_lookup == nil or TheInput.gamepad_lookup[control] == nil then
		TheInput:_AddGamepadButtonBind({ button = button, control = control })
	end
	return control
end

function PH.AddControl()
	local s = PH.Settings()
	local buttons = {}
	PH.control = PH.AddButton(PH.CONTROL, s.gamepad)
	if PH.control ~= nil then
		buttons[#buttons + 1] = s.gamepad .. " each player's"
	end
	PH.control_small = PH.AddButton(PH.CONTROL_SMALL, s.small_gamepad)
	if PH.control_small ~= nil then
		local sizes = {}
		for _, k in ipairs(PH.Sizes()) do
			sizes[#sizes + 1] = string.format("%d%% %d rows", math.floor(k * 100 + 0.5), PH.RowsFor(k))
		end
		buttons[#buttons + 1] = s.small_gamepad .. " smaller each (" .. table.concat(sizes, ", ") .. ")"
	end
	return #buttons > 0 and table.concat(buttons, ", ") or nil
end

function PH.OnControl(pc, controls, down)
	if not down then
		return
	end
	local hide = PH.control ~= nil and controls:Has(PH.control)
	local small = PH.control_small ~= nil and controls:Has(PH.control_small)
	if not (hide or small) or InTown() then
		return
	end
	local w = PH.WidgetOf(pc.inst)
	if w == nil then
		return
	end
	if hide then
		PH.Toggle(w)
	end
	if small then
		PH.ToggleSmall(w)
	end
end

----------------------------------------------------------------------------

function PH.Install(PlayerPowersWidget, PlayerController, Keys)
	assert(type(PlayerPowersWidget) == "table" and type(PlayerPowersWidget._ctor) == "function"
		and type(PlayerPowersWidget.ShowPowers) == "function" and type(PlayerPowersWidget.HidePowersForTown) == "function",
		"a game update changed PlayerPowersWidget")
	local ctor, show, hide = PlayerPowersWidget._ctor, PlayerPowersWidget.ShowPowers, PlayerPowersWidget.HidePowersForTown
	-- the rows' size set before the game lines them up (hud.lua's cluster
	-- scale multiplies it in too)
	local layout = PlayerPowersWidget.Layout
	if type(layout) == "function" then
		-- a smaller size's rows ready before the game fills them
		PlayerPowersWidget.Layout = function(self, reset_rows, ...)
			if rawget(self, "skillslots_power_rows") ~= nil then
				local ok, r = pcall(PH.ReadyRows, self, reset_rows)
				if ok then
					reset_rows = r
				else
					Log(r)
				end
			end
			return layout(self, reset_rows, ...)
		end
	end
	local position = PlayerPowersWidget._PositionPowers
	if type(position) == "function" then
		PlayerPowersWidget._PositionPowers = function(self, ...)
			local k = rawget(self, "skillslots_power_factor")
			local root = rawget(self, "powers_root")
			if type(k) == "number" and root ~= nil and root.SetScale ~= nil then
				pcall(root.SetScale, root, k, k)
			end
			return position(self, ...)
		end
	end
	PlayerPowersWidget._ctor = function(self, ...)
		ctor(self, ...)
		local ok, err = pcall(PH.Attach, self)
		if not ok then
			Log(err)
		end
	end
	-- the game hides the rows in town and shows them out of it; hidden by
	-- you, they stay hidden
	PlayerPowersWidget.HidePowersForTown = function(self, ...)
		rawset(self, "skillslots_in_town", true)
		return hide(self, ...)
	end
	PlayerPowersWidget.ShowPowers = function(self, ...)
		rawset(self, "skillslots_in_town", nil)
		local r = table.pack(show(self, ...))
		if rawget(self, "skillslots_powers_hidden") and rawget(self, "powers_root") ~= nil then
			self.powers_root:SetMultColorAlpha(0)
			self.powers_root:Hide()
		end
		return table.unpack(r, 1, r.n)
	end
	local info = {}
	local ok_b, button = pcall(PH.AddControl)
	if not ok_b then
		Log("D-pad button: " .. tostring(button))
		button = nil
	end
	if button ~= nil and type(PlayerController) == "table" and type(PlayerController.OnControl) == "function" then
		local on = PlayerController.OnControl
		PlayerController.OnControl = function(self, controls, down, ...)
			local r = table.pack(on(self, controls, down, ...))
			local ok, err = pcall(PH.OnControl, self, controls, down)
			if not ok then
				Log(err)
			end
			return table.unpack(r, 1, r.n)
		end
		info[#info + 1] = button
	end
	local ok_k, keys = pcall(PH.BindKeys, Keys)
	if ok_k then
		for _, k in ipairs(keys) do
			info[#info + 1] = k
		end
	else
		Log("keys: " .. tostring(keys))
	end
	local mode = PH.Settings().boss_auto_hide
	if mode ~= false and mode ~= nil and mode ~= "none" then
		info[#info + 1] = "auto in " .. (mode == "all" and "boss and miniboss" or "boss") .. " fights"
	end
	return true, table.concat(info, ", ")
end

return PH
