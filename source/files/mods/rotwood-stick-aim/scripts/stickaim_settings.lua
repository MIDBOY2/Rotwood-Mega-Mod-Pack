-- Stick Aim settings. Save, then restart the game.
return {
	-- false: the mod does nothing at all (the same as switching it off)
	enabled = true,

	-- what a player's right stick does until they switch it: "aim" or "emotes"
	default_mode = "emotes",

	-- BACK + right stick click switches that player's right stick between AIM and EMOTES
	toggle = true,
	-- a note on screen says which ("Player 1: right stick aims")
	toggle_note = true,
	-- BACK opens your status panel as you press it: closed again after the switch
	close_status = true,
	-- keep each player's choice for the next game (stickaim_modes.txt in the save folder)
	remember = true,

	-- how far the stick has to be pushed to aim (0-1), and how far back to stop aiming
	aim_at = 0.35,
	release_at = 0.2,

	-- while aiming, the buttons trade places (preset below); false: they stay as they are
	swap_buttons = true,
	preset = 1,
	-- a preset per player slot, e.g. { [2] = 1 } (player 2 uses preset 1); others use "preset"
	player_presets = {},
	-- button = what it does while aiming (the button whose job it takes). Buttons: A B X Y LB RB LT RT
	presets = {
		-- 1: RB light attack, RT heavy attack, LB skill, LT dodge; A interact, B potion,
		--    X the LT skill slot, Y the RT skill slot
		{ RB = "X", RT = "Y", LB = "B", LT = "A", A = "RB", B = "LB", X = "LT", Y = "RT" },
	},
}
