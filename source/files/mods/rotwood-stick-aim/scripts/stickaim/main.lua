-- Stick Aim (Rotwood build 760548): a controller player's right stick can aim, the way the mouse does.
--
-- Each player picks what their right stick does: AIM or EMOTES (BACK + right stick click switches it, a note
-- says which; kept per player slot in stickaim_modes.txt in the save folder).
-- AIM, while the stick is pushed:
--  * the game's own mouse aiming, with the stick's direction as the "mouse": standing still you turn to face
--    it, running away from it you run backwards looking at it, light / heavy attacks and skills go that way
--    (steerable skills, the cannon's aim, the cleaver too), the aim pointer under you points that way
--    (PlayerController:ShouldAimAtMouse / GetMouseActionDirection, PlayerHighlight:GetControlAngle,
--    SGPlayerCommon.Fns.ApplyBackPrefixOnUpdate). Dodge still goes where you walk (left stick).
--  * the buttons trade places (a preset; preset 1: RB light attack, RT heavy attack, LB skill, LT dodge,
--    A interact, B potion, X the LT skill slot, Y the RT skill slot). The swap is done where the game reads a
--    gamepad button (Input:OnGamePadButtonDown / Up), before it looks up what the button does, so every
--    binding follows (the game's, Options > Controls, Skill Slots', Controller Layout's). A button keeps
--    what it was pressed as until it's let go (no stuck buttons when the stick comes back first).
--  * the stick doesn't open emotes (PlayerController:GetRadialMenuDir answers "not pushed" during play, so
--    neither the game's ring nor Controller Layout's stick ring picks it up). Menus, the build placer and an
--    emote ring opened another way still get the stick.
-- Letting go of the stick: everything is the game's again. EMOTES: nothing changes at all.
-- Nothing runs every frame of its own: the checks run only when the game asks (a button, an aim question).

local Main = {}
Main.TAG = "[Stick Aim]"
Main.FILE = "stickaim_modes.txt"
Main.MODES = { aim = true, emotes = true }

Main.DEFAULTS = {
	enabled = true,
	default_mode = "emotes",
	toggle = true,
	toggle_note = true,
	close_status = true,
	aim_at = 0.35,
	release_at = 0.2,
	swap_buttons = true,
	preset = 1,
	player_presets = {},
	presets = {
		{ RB = "X", RT = "Y", LB = "B", LT = "A", A = "RB", B = "LB", X = "LT", Y = "RT" },
	},
	remember = true,
}

Main.settings = nil
Main.modes = {} -- hunter id (player slot 1-4) -> "aim" / "emotes"
Main.pads = {} -- gamepad id -> { aiming, pressed = { button id -> button id it was pressed as }, swallow = { button id } }
Main.maps = {} -- preset index -> { button id -> button id }
Main.on = false

local function G(name)
	return rawget(_G, name)
end

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

local errors = 0
local function Report(where, err)
	if errors < 8 then
		errors = errors + 1
		Main.Log(where .. ": " .. tostring(err))
	end
end

----------------------------------------------------------------------------
-- settings

local BUTTONS = { A = true, B = true, X = true, Y = true, LB = true, RB = true, LT = true, RT = true,
	BACK = true, START = true, LS = true, RS = true, DPAD_UP = true, DPAD_DOWN = true, DPAD_LEFT = true, DPAD_RIGHT = true }

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
	end
	if not Main.MODES[s.default_mode] then
		s.default_mode = Main.DEFAULTS.default_mode
	end
	if s.aim_at <= 0 or s.aim_at > 1 then
		s.aim_at = Main.DEFAULTS.aim_at
	end
	if s.release_at < 0 or s.release_at > s.aim_at then
		s.release_at = math.min(Main.DEFAULTS.release_at, s.aim_at)
	end
	-- a preset: only known buttons, each used once as a target
	local presets = {}
	for i, p in ipairs(type(s.presets) == "table" and s.presets or {}) do
		local clean, used = {}, {}
		if type(p) == "table" then
			for from, to in pairs(p) do
				if BUTTONS[from] and BUTTONS[to] and not used[to] then
					clean[from] = to
					used[to] = true
				end
			end
		end
		presets[i] = clean
	end
	if #presets == 0 then
		presets = { Main.DEFAULTS.presets[1] }
	end
	s.presets = presets
	if presets[s.preset] == nil then
		s.preset = 1
	end
	Main.settings = s
	return s
end

----------------------------------------------------------------------------
-- players, sticks, modes

function Main.PlayerOfPad(gamepad_id)
	for _, p in ipairs(G("AllPlayers") or {}) do
		local comps = type(p) == "table" and p.components or nil
		local pc = comps ~= nil and comps.playercontroller or nil
		if pc ~= nil and pc.gamepad_id == gamepad_id then
			return p, pc
		end
	end
	return nil, nil
end

function Main.SlotOf(player)
	if type(player) == "table" and type(player.GetHunterId) == "function" then
		local ok, id = pcall(player.GetHunterId, player)
		if ok and type(id) == "number" then
			return id
		end
	end
	return 1
end

function Main.ModeOf(player)
	return Main.modes[Main.SlotOf(player)] or Main.settings.default_mode
end

function Main.Pad(gamepad_id)
	local st = Main.pads[gamepad_id]
	if st == nil then
		st = { aiming = false, pressed = {}, swallow = {} }
		Main.pads[gamepad_id] = st
	end
	return st
end

-- the right stick as the engine last sent it (Input:OnGamepadAnalogInput): x right, y up
function Main.Stick(gamepad_id)
	local input = G("TheInput")
	local pads = type(input) == "table" and rawget(input, "gamepads") or nil
	local pad = type(pads) == "table" and pads[gamepad_id] or nil
	if type(pad) ~= "table" then
		return 0, 0, 0
	end
	local x, y = tonumber(pad.rs_x) or 0, tonumber(pad.rs_y) or 0
	return x, y, math.sqrt(x * x + y * y)
end

-- the game's direction for it (as GetAnalogDir / GetRadialMenuDir give: degrees, y down the screen)
function Main.Angle(pc)
	local x, y = Main.Stick(pc.gamepad_id)
	return math.deg(math.atan(-y, x))
end

local function RingShowing(inst)
	local ring = inst ~= nil and inst.emote_ring or nil
	if ring == nil or type(ring.IsRingShowing) ~= "function" then
		return false
	end
	local ok, up = pcall(ring.IsRingShowing, ring)
	return ok and up == true
end

-- in play with this gamepad: no menu or screen taking the buttons, not placing a decoration, not watching
function Main.InPlay(pc)
	if type(pc.HasGamepad) ~= "function" or not pc:HasGamepad() then
		return false
	end
	local ok, enabled = pcall(pc.IsEnabled, pc)
	if not ok or not enabled then
		return false
	end
	local input = pc.input
	if input ~= nil and type(input.IsEditingBlockingGameplay) == "function" and input:IsEditingBlockingGameplay() then
		return false
	end
	if type(pc.input_stealers) == "table" and #pc.input_stealers > 0 then
		return false
	end
	if type(pc.IsPlacingOrRemoving) == "function" and pc:IsPlacingOrRemoving() then
		return false
	end
	local inst = pc.inst
	if inst ~= nil and type(inst.IsSpectating) == "function" and inst:IsSpectating() then
		return false
	end
	return not RingShowing(inst)
end

-- Is this player aiming with the stick right now? (AIM mode, in play, the stick pushed past aim_at; it stays
-- aiming until the stick is back under release_at)
function Main.Aiming(pc)
	if not Main.on or type(pc) ~= "table" or pc.gamepad_id == nil or pc.gamepad_id < 0 then
		return false
	end
	if Main.ModeOf(pc.inst) ~= "aim" then
		return false
	end
	local st = Main.Pad(pc.gamepad_id)
	local _, _, r = Main.Stick(pc.gamepad_id)
	if st.aiming then
		if r < Main.settings.release_at then
			st.aiming = false
		end
	elseif r >= Main.settings.aim_at then
		st.aiming = true
	end
	return st.aiming and Main.InPlay(pc)
end

-- AIM mode in play: the stick is this mod's (not the emote ring's)
function Main.OwnsStick(pc)
	return Main.on and type(pc) == "table" and pc.gamepad_id ~= nil and pc.gamepad_id >= 0
		and Main.ModeOf(pc.inst) == "aim" and Main.InPlay(pc)
end

----------------------------------------------------------------------------
-- remembering the modes (one line: "1=aim,2=emotes")

function Main.Encode()
	local parts = {}
	for slot = 1, 8 do
		if Main.modes[slot] ~= nil then
			parts[#parts + 1] = slot .. "=" .. Main.modes[slot]
		end
	end
	return table.concat(parts, ",")
end

function Main.Decode(text)
	local modes = {}
	for slot, mode in tostring(text or ""):gmatch("(%d+)=(%a+)") do
		if Main.MODES[mode] then
			modes[tonumber(slot)] = mode
		end
	end
	return modes
end

function Main.Load()
	local sim = G("TheSim")
	if not Main.settings.remember or type(sim) ~= "table" or type(sim.GetPersistentString) ~= "function" then
		return false
	end
	return (pcall(sim.GetPersistentString, sim, Main.FILE, function(is_file, text)
		if is_file then
			for slot, mode in pairs(Main.Decode(text)) do
				if Main.modes[slot] == nil then
					Main.modes[slot] = mode
				end
			end
		end
	end))
end

function Main.Save()
	local sim = G("TheSim")
	if not Main.settings.remember or type(sim) ~= "table" or type(sim.SetPersistentString) ~= "function" then
		return false
	end
	return (pcall(sim.SetPersistentString, sim, Main.FILE, Main.Encode(), false, function() end))
end

local LABEL = { aim = "aims", emotes = "does emotes" }

function Main.Note(player, mode)
	local fe = G("TheFrontEnd")
	if Main.settings.toggle_note and type(fe) == "table" and type(fe.ShowTextNotification) == "function" then
		pcall(fe.ShowTextNotification, fe, nil, "Player " .. Main.SlotOf(player) .. ": right stick " .. LABEL[mode],
			"BACK + right stick click switches", 3)
	end
end

function Main.SetMode(player, mode)
	if not Main.MODES[mode] then
		return false
	end
	local slot = Main.SlotOf(player)
	Main.modes[slot] = mode
	Main.Save()
	Main.Log("player " .. slot .. ": right stick " .. mode)
	Main.Note(player, mode)
	return true
end

function Main.Toggle(player)
	local mode = Main.ModeOf(player) == "aim" and "emotes" or "aim"
	Main.SetMode(player, mode)
	-- BACK opened the player's status panel on its way down: closed again
	local fs = Main.settings.close_status and type(player) == "table" and player.follow_status or nil
	if fs ~= nil and type(fs.TryHideRadial) == "function" then
		pcall(fs.TryHideRadial, fs)
	end
	return mode
end

----------------------------------------------------------------------------
-- the button swap

function Main.BuildMaps(InputConstants)
	local ids = InputConstants ~= nil and InputConstants.GamepadButtons or nil
	if type(ids) ~= "table" then
		return false
	end
	Main.maps = {}
	for i, p in ipairs(Main.settings.presets) do
		local m = {}
		for from, to in pairs(p) do
			if ids[from] ~= nil and ids[to] ~= nil then
				m[ids[from]] = ids[to]
			end
		end
		Main.maps[i] = m
	end
	Main.rs_id = ids.RS
	Main.back_name = "BACK"
	return Main.maps[1] ~= nil
end

function Main.MapFor(player)
	local i = Main.settings.player_presets[Main.SlotOf(player)] or Main.settings.preset
	return Main.maps[i] or Main.maps[Main.settings.preset] or {}
end

-- what this press counts as (nil: as itself); also the BACK + right stick click toggle
function Main.OnButtonDown(input, gamepad_id, button)
	local st = Main.Pad(gamepad_id)
	if st.swallow[button] then
		return false -- (a repeat of the toggle's click)
	end
	local held = st.pressed[button]
	if held ~= nil then
		return held -- (a repeat of a held button: what it was pressed as)
	end
	local player, pc = Main.PlayerOfPad(gamepad_id)
	if pc == nil then
		return nil
	end
	if Main.settings.toggle and button == Main.rs_id then
		local pad = type(input.gamepads) == "table" and input.gamepads[gamepad_id] or nil
		if type(pad) == "table" and pad[Main.back_name] == true then
			st.swallow[button] = true
			Main.Toggle(player)
			return false
		end
	end
	if Main.settings.swap_buttons and Main.Aiming(pc) then
		local to = Main.MapFor(player)[button]
		if to ~= nil then
			st.pressed[button] = to
			return to
		end
	end
	return nil
end

function Main.OnButtonUp(gamepad_id, button)
	local st = Main.Pad(gamepad_id)
	if st.swallow[button] then
		st.swallow[button] = nil
		return false
	end
	local to = st.pressed[button]
	st.pressed[button] = nil
	return to
end

----------------------------------------------------------------------------
-- hooks

-- calls fn with GetAnalogDir answering the aim direction (the game builds a gamepad attack from it)
-- (0.1.1) shared stand-ins, the angle kept on the controller for the call: no new function or table per call
-- (the aim pointer and running backwards ask every frame while aiming)
local function AimAngle(self)
	return rawget(self, "stickaim_angle")
end
local function NoGamepad()
	return false
end

local function WithAim(pc, fn, ...)
	rawset(pc, "stickaim_angle", Main.Angle(pc))
	local prev = rawget(pc, "GetAnalogDir")
	rawset(pc, "GetAnalogDir", AimAngle)
	local ok, r = pcall(fn, ...)
	rawset(pc, "GetAnalogDir", prev)
	rawset(pc, "stickaim_angle", nil)
	if not ok then
		error(r, 0)
	end
	return r
end

local function Need(obj, label, names)
	if type(obj) ~= "table" then
		return label .. " missing"
	end
	for _, n in ipairs(names) do
		if type(obj[n]) ~= "function" then
			return label .. "." .. n .. " missing"
		end
	end
	return nil
end

function Main.Install(GLOBAL)
	local ok_i, Input = pcall(require, "input.input")
	local ok_pc, PlayerController = pcall(require, "components.playercontroller")
	local InputConstants = rawget(GLOBAL or _G, "InputConstants")
	if type(InputConstants) ~= "table" then
		pcall(require, "input.inputconstants") -- (it sets the global)
		InputConstants = rawget(GLOBAL or _G, "InputConstants")
	end
	local why = (not ok_i and "input.input: " .. tostring(Input)) or (not ok_pc and "playercontroller: " .. tostring(PlayerController))
		or Need(Input, "Input", { "OnGamePadButtonDown", "OnGamePadButtonUp" })
		or Need(PlayerController, "PlayerController", { "ShouldAimAtMouse", "GetMouseActionDirection", "GetRadialMenuDir",
			"OnLightAttackButton", "OnHeavyAttackButton", "OnSkillButton", "HasGamepad", "IsEnabled" })
	if why ~= nil then
		return false, why .. " (a game update changed it)"
	end
	if not Main.BuildMaps(InputConstants) then
		return false, "InputConstants.GamepadButtons missing"
	end

	-- the buttons: what a press counts as, before the game looks up its bindings
	local orig_down, orig_up = Input.OnGamePadButtonDown, Input.OnGamePadButtonUp
	Input.OnGamePadButtonDown = function(self, gamepad_id, button, ...)
		local ok, to = pcall(Main.OnButtonDown, self, gamepad_id, button)
		if not ok then
			Report("button", to)
			to = nil
		end
		if to == false then
			return true -- the toggle: the press goes no further
		end
		return orig_down(self, gamepad_id, to or button, ...)
	end
	Input.OnGamePadButtonUp = function(self, gamepad_id, button, ...)
		local ok, to = pcall(Main.OnButtonUp, gamepad_id, button)
		if not ok then
			Report("button", to)
			to = nil
		end
		if to == false then
			return true
		end
		return orig_up(self, gamepad_id, to or button, ...)
	end
	local notes = { "buttons" }

	-- aiming: the game's mouse aiming with the stick's direction
	local function Aiming(pc)
		local ok, yes = pcall(Main.Aiming, pc)
		if not ok then
			Report("aim", yes)
			return false
		end
		return yes
	end
	local orig_should = PlayerController.ShouldAimAtMouse
	PlayerController.ShouldAimAtMouse = function(self, ...)
		if Aiming(self) then
			return true
		end
		return orig_should(self, ...)
	end
	local orig_dir = PlayerController.GetMouseActionDirection
	PlayerController.GetMouseActionDirection = function(self, ...)
		if Aiming(self) then
			return Main.Angle(self)
		end
		return orig_dir(self, ...)
	end
	-- light / heavy attacks from a gamepad button take their direction from GetAnalogDir
	for _, name in ipairs({ "OnLightAttackButton", "OnHeavyAttackButton", "OnSkillButton" }) do
		local orig = PlayerController[name]
		PlayerController[name] = function(self, down, ismousebtn, ...)
			if down and not ismousebtn and Aiming(self) then
				return WithAim(self, orig, self, down, ismousebtn, ...)
			end
			return orig(self, down, ismousebtn, ...)
		end
	end
	-- the stick doesn't open emotes while it aims
	local orig_radial = PlayerController.GetRadialMenuDir
	PlayerController.GetRadialMenuDir = function(self, ...)
		local ok, mine = pcall(Main.OwnsStick, self)
		if ok and mine then
			return nil
		end
		return orig_radial(self, ...)
	end
	notes[#notes + 1] = "aim"

	-- the aim pointer under the player
	local ok_h, PlayerHighlight = pcall(require, "components.playerhighlight")
	if ok_h and type(PlayerHighlight) == "table" and type(PlayerHighlight.GetControlAngle) == "function" then
		local orig_angle = PlayerHighlight.GetControlAngle
		PlayerHighlight.GetControlAngle = function(self, ...)
			local player = self.player
			local pc = type(player) == "table" and player.components ~= nil and player.components.playercontroller or nil
			if pc ~= nil and Aiming(pc) then
				return WithAim(pc, orig_angle, self, ...)
			end
			return orig_angle(self, ...)
		end
		notes[#notes + 1] = "aim pointer"
	else
		Main.Log("the aim pointer keeps following the left stick (components.playerhighlight changed)")
	end

	-- running backwards while looking at the aim (the game does it only for the mouse)
	local ok_s, SGPlayerCommon = pcall(require, "stategraphs.sg_player_common")
	local fns = ok_s and type(SGPlayerCommon) == "table" and rawget(SGPlayerCommon, "Fns") or nil
	local orig_back = type(fns) == "table" and rawget(fns, "ApplyBackPrefixOnUpdate") or nil
	if type(orig_back) == "function" then
		rawset(fns, "ApplyBackPrefixOnUpdate", function(inst, animname, ...)
			local pc = type(inst) == "table" and inst.components ~= nil and inst.components.playercontroller or nil
			if pc ~= nil and Aiming(pc) then
				-- (as if no gamepad, for its gamepad check; the aim worked out first: the "no gamepad" would
				-- also stop this mod's own aim question in there)
				rawset(pc, "stickaim_angle", Main.Angle(pc))
				local prev_pad, prev_dir = rawget(pc, "HasGamepad"), rawget(pc, "GetMouseActionDirection")
				rawset(pc, "HasGamepad", NoGamepad)
				rawset(pc, "GetMouseActionDirection", AimAngle)
				local ok, r = pcall(orig_back, inst, animname, ...)
				rawset(pc, "HasGamepad", prev_pad)
				rawset(pc, "GetMouseActionDirection", prev_dir)
				rawset(pc, "stickaim_angle", nil)
				if ok then
					return r
				end
				Report("run backwards", r)
				return animname
			end
			return orig_back(inst, animname, ...)
		end)
		notes[#notes + 1] = "running backwards"
	else
		Main.Log("no running backwards while aiming (SGPlayerCommon.Fns.ApplyBackPrefixOnUpdate changed)")
	end

	Main.Load()
	Main.on = true
	local s = Main.settings
	return true, string.format("%s; players start in %s (BACK + right stick click switches%s); aim at %.2f, let go under %.2f; preset %d%s",
		table.concat(notes, ", "), s.default_mode, s.remember and ", kept per player" or "", s.aim_at, s.release_at, s.preset,
		s.swap_buttons and "" or " (buttons not swapped)")
end

return Main
