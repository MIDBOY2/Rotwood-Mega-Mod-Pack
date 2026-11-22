-- Player Colours settings. Restart the game after changing this file.
return {
	-- false = the whole mod is off (colours you picked stay in the save and
	-- come back when it's on again)
	enabled = true,

	-- the PLAYER COLOUR tab in the character screen (the mirror in town)
	colour_tab = true,

	-- the ring under your feet, the aim arrow and the other per-player effects
	-- (acid, poison, jam ball target, ...) follow the colour too.
	-- false = only the HUD / names / brackets change, effects stay vanilla
	fx = true,

	-- Red's ring under your feet: "steps" (its inner circle shows), "deep" (0.2.2's),
	-- "bright" (full red, the inner circle melts into it)
	red_ring = "steps",

	-- (0.2.8) the leaf on the farm plot signs follows the plot owner's colour.
	-- false = the signs keep the game's colours
	farm_signs = true,

	-- extra lines in client_log.txt
	debug = false,
}
