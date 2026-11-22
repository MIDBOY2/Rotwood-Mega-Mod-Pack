-- Save States settings. Every value here can be changed; a value that isn't
-- valid falls back to its default (the log says which).
return {
	enabled = true,

	-- Keys. A slot key is the modifiers + a number-row key (1 to 9 and 0 = slot 10).
	-- The modifiers have to match exactly: Ctrl+Shift+1 isn't Ctrl+1.
	keys = {
		save = "Ctrl",                 -- Ctrl+1 .. Ctrl+0: save to slot 1 .. 10
		rebuild = "Ctrl+Shift",        -- Ctrl+Shift+1 .. 0: load that slot, Rebuild
		replicate = "Ctrl+Alt",        -- Ctrl+Alt+1 .. 0: load that slot, Replicate
		latest_rebuild = "Ctrl+L",     -- the latest auto save (slot 0), Rebuild
		latest_replicate = "Ctrl+Alt+L", -- the latest auto save, Replicate
		menu = "Ctrl+Shift+Alt+1",     -- the hidden history tabs in the Codex (with none open: Saved Hunts with them)
	},
	-- With the game's debug keys on, Ctrl+1 .. Ctrl+4 also set the debug
	-- menu's text size. true: those presses only save (the text size stays).
	keep_debug_text_size = true,

	-- History: every manual save is kept here too, the oldest deleted first.
	manual_history = 1000,
	-- Every room you enter saves to slot 0 and to this list (the oldest first out).
	auto_save = true,
	auto_history = 100,
	auto_save_delay = 1.0, -- seconds after the room starts
	-- Your state just before every load goes to the auto history, so a load can be undone.
	undo_before_load = true,
	-- A load fades the screen to black first, like the start of a run (the game's own fade).
	fade_load = true,
	-- The full-screen Saved Hunts: each player's line in columns, the same on
	-- every save (a long name drawn smaller to fit, a short one with room after
	-- it; extra lives, rerolls and potions always shown, 0 when not unlocked, no
	-- potion = the HUD's plain potion). Only the drawing: no save changes.
	align_players = true,

	-- A load gives the saved room its own enemies again: the same encounter,
	-- special encounter and Frenzy extra as when it was saved (the game draws
	-- a room's enemies when it starts; a load without this draws the next
	-- ones instead). Saves from before 0.5.0 still draw again.
	-- false: the game draws the room's enemies again on every load.
	same_room = true,

	-- Replicate: the gear you don't own is given to you with its saved level,
	-- gems and mirage (the one exception to "never touch the character").
	-- true: lent for the run instead, and taken back when the run ends (experimental).
	replicate_lend = false,
	-- Replicate: your own gear goes back on when the run ends.
	restore_loadout_after_run = true,

	-- The run counters on powers your talents and gear give: extra lives left,
	-- starting Teffra already taken, skill charges.
	restore_counters = true,
	-- The saved HP is set again after the room's own "on entering" effects.
	exact_hp = true,

	notes = true, -- short notes on screen

	-- The Saved Hunts tab in the camp's Codex (the book at the camp's entrance):
	-- every slot with its hunt, Frenzy level, each player's HP, extra lives,
	-- Teffra, rerolls, potions, powers and the room, and a LOAD button.
	codex = true,
	codex_tab_first = true, -- the first tab (the Codex opens on it); false: the last
	-- The pause menu's SAVE HUNT (in a run: save into slots 1-10, overwrite
	-- them) / LOAD HUNT (in town): the Codex opens on Saved Hunts. false: no button.
	pause_menu = true,
	-- What that button (and Ctrl+Shift+Alt+1 with no menu open) opens:
	--   "full"  (experimental) one full screen for everyone, the pause menu's
	--           look: the players on top, the saved hunt's map, the saves on
	--           the right. Its CODEX VIEW button opens the Codex's view.
	--   "codex" the Codex, on its Saved Hunts tab (one per player).
	-- If the full screen can't open, the Codex's view opens (the log says why).
	pause_menu_screen = "full",
	debug = false,
}
