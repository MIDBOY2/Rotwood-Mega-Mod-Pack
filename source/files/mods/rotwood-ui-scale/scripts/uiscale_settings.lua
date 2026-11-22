-- UI Scale settings. Restart the game after changing this file.
-- Each size: 1 = the game's own size, 0.85 = 85%, 0.75 = 75%, from 0.5 to 1.5 (above 1 is bigger).
-- A size picked in the game (Options > Graphics, the keys or the console) is used instead of these
-- while remember = true.
return {
	-- false = the mod is off (the game's own sizes)
	enabled = true,

	-- your character info in the corner: portrait, name, health, skills, potion, currencies
	-- (the other players' corners too). It shrinks toward its own corner.
	character_info = 0.85,

	-- the power details over a power you can pick up (and in the shop, at the wanderer)
	power_popup = 0.85,

	-- the prompts (the line over you that says what the button does) take the power popup's size:
	--   "all"     every prompt: Take / Reroll, Talk, the mirror, the stations, Revive (camp and hunts)
	--   "pickups" only at a pickup (Take / Reroll)
	--   "none"    the game's size
	-- (a conversation's speech balloons always keep the game's size)
	popup_prompt = "all",

	-- the whole interface: menus, map, text, HUD (0.1.0's way). 1 = left exactly as the game has it.
	whole_interface = 1,

	-- remember the sizes picked in the game
	remember = true,

	-- the size rows in Options > Graphics
	options_rows = true,

	-- keys (not while typing in the console). The modifiers have to match exactly; "" = no key.
	-- Bigger / smaller also work with the number pad's + and - (with the same modifiers).
	key_character_bigger = "Ctrl+=",        -- character info 5% bigger
	key_character_smaller = "Ctrl+-",       -- character info 5% smaller
	key_character_reset = "Ctrl+Shift+=",   -- character info at the game's own size
	key_popup_bigger = "Ctrl+Alt+=",        -- power popup 5% bigger
	key_popup_smaller = "Ctrl+Alt+-",       -- power popup 5% smaller
	key_popup_reset = "Ctrl+Alt+Shift+=",   -- power popup at the game's own size
	key_whole_bigger = "",                  -- whole interface (no keys unless you add them)
	key_whole_smaller = "",
	key_whole_reset = "",
	step = 0.05,                            -- how much one key press changes a size

	-- the console command: c_uiscale(0.8) the character info, c_uiscale("popup", 0.8),
	-- c_uiscale("whole", 0.9), c_uiscale() the sizes now
	console_command = true,
}
