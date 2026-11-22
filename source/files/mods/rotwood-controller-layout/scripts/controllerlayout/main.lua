-- Controller Layout: the emote ring on the right stick (push, pick, let go),
-- build and customize town on the D-pad, LT emote button removed.

local PlayerController = require "components.playercontroller"

local function TryRequire(name)
	local ok, mod = pcall(require, name)
	return ok and type(mod) == "table" and mod or nil
end
local PlayerEmoteRing = TryRequire("widgets/ftf/playeremotering")
local CraftSelector = TryRequire("widgets/ftf/town/decor/craftselector")

local Main = {}

Main.TAG = "[Controller Layout]"
Main.enabled = false
Main.forced = {} -- control -> gamepad button name, or false for none

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

----------------------------------------------------------------------------
-- Settings

local DEFAULTS = {
	enabled = true,
	right_stick_emotes = true,
	open_at = 0.5,
	pick_at = 0.6,
	release_at = 0.5,
	settle_time = 0.07,
	face_buttons_pick = false,
	emote_button = "",
	build_button = "DPAD_DOWN",
	customize_button = "game",
	free_dpad = true,
	debug_button = "hidden",
	debug_button_key = "F9",
	rev_number = "hidden",
	rev_number_key = "F10",
	overhead = "game",
	overhead_key = "Ctrl+H",
	overhead_note = true,
}

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			s[k] = v
		end
	end
	Main.settings = s
	return s
end

----------------------------------------------------------------------------
-- Game names this mod relies on. If an update renames one, that part stays off
-- and client_log.txt says which.

local function Missing(label, obj, fns)
	if type(obj) ~= "table" then
		return label
	end
	for _, fn in ipairs(fns) do
		if type(obj[fn]) ~= "function" then
			return label .. ":" .. fn
		end
	end
	return nil
end

local function CheckBindings()
	return Missing("TheInput", TheInput, { "RebindGamepadButton", "_RemoveGamepadButtonBind" })
end

local function CheckEmotes()
	return Missing("PlayerController", PlayerController,
			{ "OnUpdate", "GetRadialMenuDir", "HasGamepad", "IsEnabled", "IsPlacingOrRemoving", "OnControlDownEvent" })
		or Missing("PlayerEmoteRing", PlayerEmoteRing,
			{ "OnEmoteKey", "UpdateFocus", "OnUpdate", "IsRingShowing", "CloseImmediately", "_Reveal", "SelectSlot",
				"GetSelectedSlotIndex", "GetSlot" })
end

----------------------------------------------------------------------------
-- Buttons: the game's emote / build / customize-town controls

local MOVED = {
	{ control = "SHOW_EMOTE_RING", setting = "emote_button" },
	{ control = "OPEN_CRAFTING", setting = "build_button" },
	{ control = "PICKUP_MODE", setting = "customize_button" },
}
local DPAD_MOVES = { DPAD_UP = "MOVE_UP", DPAD_DOWN = "MOVE_DOWN", DPAD_LEFT = "MOVE_LEFT", DPAD_RIGHT = "MOVE_RIGHT" }

local function IsDpad(button)
	return type(button) == "string" and DPAD_MOVES[button] ~= nil
end

-- the gamepad buttons a control is on right now (this mod's or the game's options')
local function ButtonsOf(control)
	local lookup = TheInput.gamepad_lookup
	local list = {}
	for _, binding in ipairs(type(lookup) == "table" and lookup[control] or {}) do
		list[#list + 1] = binding.button
	end
	return list
end

local function OnDpad(control)
	for _, button in ipairs(ButtonsOf(control)) do
		if IsDpad(button) then
			return true
		end
	end
	return false
end

local function InstallBindings()
	local digital = Controls.Digital
	local s = Main.settings
	local moved = {}
	for _, entry in ipairs(MOVED) do
		local control = rawget(digital, entry.control)
		local value = s[entry.setting]
		if control ~= nil and type(value) == "string" and value ~= "game" then
			Main.forced[control] = value ~= "" and value or false
			moved[#moved + 1] = entry.control .. "=" .. (value ~= "" and value or "none")
		end
	end

	if #moved > 0 then
		-- The game re-applies its saved buttons for these when its options
		-- change; keep this mod's buttons then too ("game" ones are left alone).
		local orig = TheInput.RebindGamepadButton
		rawset(TheInput, "RebindGamepadButton", function(self, binding, ...)
			local forced -- false = no button (and/or would turn it into nil)
			if type(binding) == "table" then
				forced = Main.forced[binding.control]
			end
			if forced ~= nil then
				binding = { control = binding.control, button = forced or nil, ANYMOD = binding.ANYMOD }
			end
			return orig(self, binding, ...)
		end)
		for control, button in pairs(Main.forced) do
			TheInput:RebindGamepadButton({ control = control, button = button or nil, ANYMOD = true })
		end
	end

	-- D-pad walking (used only with the stick idle) gives way wherever these
	-- controls now sit on the D-pad, set here or in the game's options
	local freed = {}
	if s.free_dpad then
		for _, entry in ipairs(MOVED) do
			local control = rawget(digital, entry.control)
			for _, button in ipairs(control ~= nil and ButtonsOf(control) or {}) do
				local move = IsDpad(button) and rawget(digital, DPAD_MOVES[button]) or nil
				if move ~= nil and not freed[button] then
					freed[button] = true
					TheInput:_RemoveGamepadButtonBind(move)
				end
			end
		end
	end

	-- In the build menu the D-pad moves the cursor; with build on the D-pad,
	-- letting go of D-pad down would also close the menu. B still closes it.
	local open_crafting = rawget(digital, "OPEN_CRAFTING")
	if open_crafting ~= nil and OnDpad(open_crafting) then
		local map = CraftSelector ~= nil and rawget(CraftSelector, "CONTROL_MAP") or nil
		local fixed = false
		for _, mapping in ipairs(type(map) == "table" and map or {}) do
			if type(mapping.control_list) == "table" then
				local list, had = {}, false
				for _, c in ipairs(mapping.control_list) do
					if c == open_crafting then
						had = true
					else
						list[#list + 1] = c
					end
				end
				if had then
					mapping.control_list = list
					fixed = true
				end
			end
		end
		if not fixed then
			Main.Log("build menu: couldn't stop D-pad down from closing it (a game update changed the build menu)")
		end
	end
	return #moved > 0 and table.concat(moved, ", ") or "buttons unchanged"
end

----------------------------------------------------------------------------
-- Emote ring on the right stick

local IDLE = "IDLE"

-- the ring is up (or about to come up)
local function RingUp(ring)
	local state = ring.bar_state
	return state == "WAITING_FOR_FADE_IN" or state == "FADE_IN" or state == IDLE
end

local function CanUseStick(pc)
	if not pc:HasGamepad() or not pc:IsEnabled() then
		return false
	end
	if pc.input ~= nil and pc.input.IsEditingBlockingGameplay ~= nil and pc.input:IsEditingBlockingGameplay() then
		return false
	end
	if pc.input_stealers ~= nil and #pc.input_stealers > 0 then
		return false
	end
	if pc:IsPlacingOrRemoving() then -- the stick turns the decoration
		return false
	end
	local inst = pc.inst
	if inst.IsSpectating ~= nil and inst:IsSpectating() then
		return false
	end
	return true
end

-- Picking with the stick: the pick follows the stick every frame (the ring's
-- own update, like the game's mouse picking), so spinning around the ring is
-- instant. Letting go is made forgiving: the thumb often slides sideways as
-- it lets go, and the stick springs back through other angles. So:
--   * letting go counts as soon as the stick is back under release_at
--     (halfway), not only once it's in the middle;
--   * an emote the stick only touched in the last moment before letting go
--     (less than settle_time) doesn't count: you get the one you rested on
--     before it (only if you did rest on it that long).
local HISTORY = 8 -- picks remembered per opening

local function ClosestSlot(ring, angle)
	angle = (angle + 360) % 360
	local closest, smallest = nil, 360
	for k, slot in ipairs(ring.slots_container.children) do
		if slot:IsActive() then
			local diff = DiffAngle(angle, slot:GetSlotRadAngle())
			if diff < smallest then
				smallest = diff
				closest = k
			end
		end
	end
	return closest
end

function Main.NewPick()
	return { history = {} }
end

-- one frame of picking; pick = this player's tracker, now = the ring's clock
function Main.UpdatePick(ring, pick, r, angle, now)
	if angle == nil or r == nil or r < (Main.settings.pick_at or 0.6) then
		return -- not pushed far enough (or let go): keep the pick
	end
	pick.last_firm = now
	local target = ClosestSlot(ring, angle)
	if target ~= nil and target ~= ring:GetSelectedSlotIndex() then
		ring:SelectSlot(target)
		local history = pick.history
		history[#history + 1] = { slot = target, t = now }
		if #history > HISTORY then
			table.remove(history, 1)
		end
	end
end

-- Letting go: the emote to play. The current pick, unless the stick only
-- touched it in the last moment and rested on an earlier one before that.
function Main.SettledSlot(pick, selected)
	local history = pick ~= nil and pick.history or nil
	if history == nil or #history < 2 or history[#history].slot ~= selected then
		return selected
	end
	local settle = Main.settings.settle_time or 0.07
	local last_firm = pick.last_firm or history[#history].t
	local function Held(i)
		local until_t = i == #history and last_firm or history[i + 1].t
		return until_t - history[i].t
	end
	if Held(#history) >= settle then
		return selected
	end
	for i = #history - 1, 1, -1 do
		if Held(i) >= settle then
			return history[i].slot
		end
	end
	return selected
end

-- the stick let go of a ring it opened: play the (settled) pick, or just close
function Main.Release(pc, ring, r)
	local selected = ring:GetSelectedSlotIndex()
	local settled = selected ~= nil and Main.SettledSlot(pc.controllerlayout_pick, selected) or nil
	if settled ~= nil and settled ~= selected then
		ring:SelectSlot(settled) -- a slide while letting go: back to the one you rested on
	end
	ring.controllerlayout_stick = nil
	-- the stick may still be on its way back: wait for the middle before the
	-- ring can open again
	pc.controllerlayout_stick = r ~= nil and "spent" or nil
	pc.controllerlayout_pick = nil
	ring:OnEmoteKey("up")
end

local function ReleaseAt()
	return Main.settings.release_at or 0.5
end

-- every frame while the ring is up, on a gamepad (from the ring's update)
local function RingStep(ring, pc)
	local r, angle = pc:GetRadialMenuDir()
	pc.controllerlayout_pick = pc.controllerlayout_pick or Main.NewPick()
	Main.UpdatePick(ring, pc.controllerlayout_pick, r, angle, ring.controllerlayout_clock or 0)
	if pc.controllerlayout_stick == "open" and ring.controllerlayout_stick and (r == nil or r < ReleaseAt()) then
		Main.Release(pc, ring, r)
	end
end

-- pc.controllerlayout_stick: nil = ready, "open" = this stick opened the ring,
-- "spent" = waiting for the stick to come back before opening again.
-- Runs with the player controller's update: opens the ring, and closes it when
-- something else takes over (letting go is handled in the ring's update, this
-- is only the fallback).
function Main.PollStick(pc)
	local inst = pc.inst
	local ring = inst ~= nil and inst.emote_ring or nil
	if ring == nil or ring.config_mode then
		return
	end
	local state = pc.controllerlayout_stick
	local r, angle
	if pc:HasGamepad() then
		r, angle = pc:GetRadialMenuDir()
	end
	if state == "open" then
		if not RingUp(ring) then
			-- closed some other way (a face button, a menu, a hit)
			ring.controllerlayout_stick = nil
			pc.controllerlayout_stick = r ~= nil and "spent" or nil
		elseif not CanUseStick(pc) then
			ring.controllerlayout_stick = nil
			ring:CloseImmediately()
			pc.controllerlayout_stick = r ~= nil and "spent" or nil
		elseif r == nil or r < ReleaseAt() then
			Main.Release(pc, ring, r)
		end
	elseif state == "spent" then
		if r == nil then
			pc.controllerlayout_stick = nil
		end
	elseif r ~= nil and r >= (Main.settings.open_at or 0.5) and not RingUp(ring) and CanUseStick(pc) then
		pc.controllerlayout_pick = Main.NewPick()
		ring:OnEmoteKey("down")
		ring:_Reveal() -- straight up, no tap-to-repeat wait
		ring.controllerlayout_stick = true
		pc.controllerlayout_stick = "open"
		if ring.bar_state == IDLE then
			Main.UpdatePick(ring, pc.controllerlayout_pick, r, angle, ring.controllerlayout_clock or 0)
		end
	end
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Main.Log("emote stick error: " .. tostring(err))
	end
end

local ATTACK_CONTROLS = { lightattack = true, heavyattack = true, dodge = true, skill = true, potion = true }

local function InstallEmotes()
	-- the ring's clock (for settle_time)
	local orig_RingUpdate = PlayerEmoteRing.OnUpdate
	PlayerEmoteRing.OnUpdate = function(self, dt, ...)
		self.controllerlayout_clock = (self.controllerlayout_clock or 0) + (type(dt) == "number" and dt or 0)
		return orig_RingUpdate(self, dt, ...)
	end

	-- On a gamepad: this mod's picking (RingStep) instead of the game's, which
	-- plays on its own when the stick is flicked. Mouse / keyboard keep the game's.
	local orig_UpdateFocus = PlayerEmoteRing.UpdateFocus
	PlayerEmoteRing.UpdateFocus = function(self, ...)
		if not self.config_mode and self.bar_state == IDLE then
			local player = self:GetOwningPlayer()
			local pc = player ~= nil and player.components ~= nil and player.components.playercontroller or nil
			if pc ~= nil and pc:HasGamepad() then
				if self.SetGamepadHotkeysShown ~= nil then
					self:SetGamepadHotkeysShown(true)
				end
				local ok, err = pcall(RingStep, self, pc)
				if ok then
					return
				end
				Report(err)
			end
		end
		return orig_UpdateFocus(self, ...)
	end

	if not Main.settings.face_buttons_pick then
		-- The same thumb works the stick and the face buttons, so with the ring
		-- opened by the stick, a face button isn't an emote pick: it closes the
		-- ring and does its usual move.
		local orig_IsRingShowing = PlayerEmoteRing.IsRingShowing
		PlayerEmoteRing.IsRingShowing = function(self, ...)
			if self.controllerlayout_stick then
				return false
			end
			return orig_IsRingShowing(self, ...)
		end
		local function CloseForMove(self)
			local ring = self.inst ~= nil and self.inst.emote_ring or nil
			if ring ~= nil and ring.controllerlayout_stick then
				ring.controllerlayout_stick = nil
				ring:CloseImmediately()
			end
		end
		local orig_down = PlayerController.OnControlDownEvent
		PlayerController.OnControlDownEvent = function(self, control, ...)
			if ATTACK_CONTROLS[control] and self.controllerlayout_stick == "open" then
				-- (an error closing the ring is logged; the move still goes)
				local ok, err = pcall(CloseForMove, self)
				if not ok then
					Report(err)
				end
				self.controllerlayout_stick = "spent"
			end
			return orig_down(self, control, ...)
		end
	end

	-- every frame: the game's update (it returns nothing), then the stick. No
	-- table for its results (a new one every frame was garbage for nothing).
	local orig_OnUpdate = PlayerController.OnUpdate
	PlayerController.OnUpdate = function(self, ...)
		orig_OnUpdate(self, ...)
		local ok, err = pcall(Main.PollStick, self)
		if not ok then
			Report(err)
		end
	end
	return true
end

----------------------------------------------------------------------------

function Main.Install()
	local parts = {}
	local missing = CheckBindings()
	if missing ~= nil then
		Main.Log("buttons unchanged: a game update changed " .. missing)
	else
		parts[#parts + 1] = InstallBindings()
	end
	if Main.settings.right_stick_emotes then
		missing = CheckEmotes()
		if missing ~= nil then
			Main.Log("right stick emotes off: a game update changed " .. missing)
		else
			InstallEmotes()
			parts[#parts + 1] = "emotes on the right stick"
		end
	end
	if #parts == 0 then
		return false, "nothing to do"
	end
	Main.enabled = true
	return true, table.concat(parts, "; ")
end

return Main
