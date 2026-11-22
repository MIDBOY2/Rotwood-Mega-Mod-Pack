-- Character Builds settings. Restart the game after changing this file.
return {
	-- false = the mod is off (your builds file stays where it is)
	enabled = true,

	-- The builds file: one file for every save, Steam account and character.
	-- "" = the default: C:\Users\<you>\AppData\Roaming\Klei\Rotwood\character_builds.lua
	-- (next to the steam-... folders; if the game won't keep it there, your save folder is used and
	-- the log says so)
	-- Any full path works, for example a folder your PCs share, so a build saved on one PC
	-- shows up on the other (write \\ or / between folders; the folder has to exist):
	--   builds_file = "C:/Users/<you>/OneDrive/Rotwood/character_builds.lua",
	builds_file = "",

	-- build slots in the BUILDS tab (at least this many; 4 more appear after your last build)
	slots = 12,

	-- automatic backups kept: your character as it was, saved before every load (1 to 50)
	auto_backups = 8,

	-- the BUILDS tab at the mirror in town
	mirror_tab = true,

	-- the build tiles show the gear and weapon the build was wearing (with their dyes)
	show_gear = true,

	-- a card on the right of the slots with the focused build's loadout: weapon, gems, armour, potion,
	-- tonic, gear level, damage and armour (the slots go 2 to a row). false = 4 to a row, no card.
	loadout_card = true,

	-- a key that opens the BUILDS tab anywhere in town (press it again to close). "" = no key.
	key_open = "Ctrl+B",

	-- console commands: cb_list(), cb_save(n), cb_load(n, p, what), cb_undo(), cb_delete(n)
	-- (what: "all", "look", "face", "colours", "gear")
	console_commands = true,
}
