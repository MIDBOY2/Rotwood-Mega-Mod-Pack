-- Controller Layout settings. Edit, save, restart the game.
--
-- Right stick = emote ring: push the stick to open it, move it onto an emote,
-- let go to play that emote. Letting go with nothing picked just closes it.
-- (The face-button shortcuts still work while it's open.) Keyboard E is unchanged.
--
-- The game's build button moves to the D-pad, which frees RS-click for Skill
-- Slots. Customize town stays wherever the game's options put it (you have it
-- on D-pad up). Applies to every controller (the game has one button layout for
-- all pads). For a button set here, the game's options menu keeps showing the
-- old one; the button here is the one that works.
--
-- Gamepad button names: "DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT",
-- "LT", "RT", "LB", "RB", "LS", "RS", "BACK", ...
-- "" = no controller button. "game" = leave it where the game's options put it.

return {
	enabled = true,

	-- emote ring on the right stick (push, move to pick, let go to play)
	right_stick_emotes = true,
	-- how far the stick has to be pushed to open the ring (0 to 1)
	open_at = 0.5,
	-- how far it has to be pushed to pick an emote
	pick_at = 0.6,
	-- The pick follows the stick every frame (spinning around is instant).
	-- Letting go, made forgiving (the stick springs back through other angles
	-- and the thumb often slides as it lets go):
	-- let go counts once the stick is back under this (0.5 = halfway; the
	-- game's middle is ~0.3)
	release_at = 0.5,
	-- moving around the ring is instant, but when you let go, an emote the
	-- stick only touched for less than this many seconds doesn't count: you
	-- get the one you rested on before it
	settle_time = 0.07,
	-- false: with the ring opened by the stick, a face button closes it and does
	-- its usual move (same thumb as the stick). true: face buttons pick emotes
	-- like the game's ring (Y = top, B = right, A = bottom, X = left)
	face_buttons_pick = false,

	-- the game's emote button (LT): "" = gone, emotes are on the right stick only
	emote_button = "",

	-- build: open the decoration menu (the game has it on RS-click)
	build_button = "DPAD_DOWN",

	-- customize town: pick up / move decorations (the game has it on RT).
	-- "game" = the game's options decide (you set D-pad up there)
	customize_button = "game",

	-- D-pad buttons that emote / build / customize town sit on (set here or in
	-- the game's options) stop walking; the stick still walks
	free_dpad = true,

	-- the game's "[Debug Menu]" button at the top of the screen in camp (the chest
	-- icon under the build number; the game has no key for it):
	-- "hidden" = starts hidden, "shown" = starts shown, "game" = left alone
	debug_button = "hidden",
	-- the key that shows / hides it in camp ("" = none; not F8: the game's feedback key)
	debug_button_key = "F9",
	-- the build number at the top ("REV. 760548", in camp and in runs):
	-- "hidden" = starts hidden, "shown" = starts shown, "game" = left alone
	rev_number = "hidden",
	-- the key that shows / hides it ("" = none)
	rev_number_key = "F10",

	-- What shows over the players' heads (all players):
	--   "game"       the game's: the health bar with the name, the potion, the
	--                name when you're behind something
	--   "hp_potion"  the health bar and the potion, no names
	--   "potion"     only the potion, and only when you press potion with none left
	-- The key cycles them (a note at the side says which); the choice is kept
	-- for the next rooms and game starts. Changing overhead here starts over.
	overhead = "game",
	overhead_key = "Ctrl+H", -- ("" = no key)
	overhead_note = true,
}
