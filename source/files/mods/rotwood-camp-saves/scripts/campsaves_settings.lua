-- Camp Saves settings. Save the file and restart the game. A bad value falls
-- back to its default (the log says which).
return {
	-- false: the game's way (a full save 10 s after every decoration change)
	enabled = true,

	-- seconds after you leave build mode before the save (a quick re-entry,
	-- such as picking the next decoration, doesn't save in between)
	wait_after_build_mode = 2,

	-- seconds at most a change waits while you stay in build mode; then it
	-- saves anyway (the game itself waits 3 minutes on Switch, for the same
	-- hitch)
	max_wait = 180,

	-- the pause menu opening saves waiting changes (quitting to the main menu
	-- from there doesn't save in the game)
	save_on_pause = true,

	-- true: log every change held and every save
	debug = false,
}
