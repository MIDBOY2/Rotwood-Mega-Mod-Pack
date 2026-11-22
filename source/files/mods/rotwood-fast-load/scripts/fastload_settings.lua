-- Fast Load settings. Edit, save, restart the game.
return {
	-- false = the game's own file search (every mod folder checked on disk)
	enabled = true,

	-- a line in client_log.txt each load: how many disk checks were skipped
	log = true,

	-- Quiet looks: whenever a character's look is touched (equipping anything,
	-- the dodge afterimages, the HUD portrait, menu puppets...) the game puts
	-- every armour piece and body part back on, one engine call per symbol,
	-- and some armour art writes "Could not find anim build FROMNUM" to the log
	-- on each call. This skips the calls that would put back exactly what's
	-- already there (same look, far fewer calls and log lines).
	-- false = the game's own calls
	quiet_looks = true,

	-- quiet looks: a line a minute in client_log.txt with how many calls were
	-- skipped, and the first few art calls of each load named
	quiet_looks_report = true,

	-- Hidden-HUD fix (a game bug): with the Extra Lives talent, the lives
	-- counter laid out the whole player HUD again every frame while a menu
	-- hides the HUD (the skill menu, the forge, the pause screen...): about
	-- 4 MB of garbage and a fifth of every second, so the frame rate jumps
	-- and the game stutters in menus. On: it rests while it can't be seen.
	-- false = the game's
	hidden_hud_fix = true,
}
