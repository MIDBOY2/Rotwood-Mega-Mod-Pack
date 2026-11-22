-- Blight Fix settings
return {
	-- true: keep the Blight Incursion stage valid between legs (the fix).
	-- false: the whole mod off, the game's own way (to compare: the log then
	--        shows "Selecting leg 4-2 (Rest Room)" after taking the second
	--        portal; the overlay is the game's too).
	enabled = true,

	-- The Blight's purple screen overlay (the game's own, on the whole Blight
	-- outside the Rest Rooms):
	--   "faded"    the game's overlay at overlay_faded of its strength
	--   "vanilla"  the game's own
	--   "none"     off
	--   false      this part off (the game's own, no key)
	overlay = "faded",

	-- how strong "faded" is: 0.10 = 10% of the game's (0 .. 1)
	overlay_faded = 0.10,

	-- the key that cycles faded -> vanilla -> none (false: no key). Exact
	-- modifiers: "Ctrl+B" isn't "Ctrl+Shift+B". Not while the console is open.
	-- The choice is kept for the next rooms and the next game start; changing
	-- overlay above starts over from the new value.
	overlay_key = "Ctrl+B",

	-- a short note on screen when the key changes it
	overlay_note = true,
}
