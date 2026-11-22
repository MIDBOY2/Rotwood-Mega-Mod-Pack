local version = "0.5.1"

return {
	name = "Save States",
	description = [[Save the run you're in with a key and rebuild it later: that room of that run, HP, Teffra, potion charges, every power with its rarity and upgrades.
Ctrl+1..0 save to slot 1..10, Ctrl+Shift+1..0 load (Rebuild: your own gear), Ctrl+Alt+1..0 load (Replicate: the saved gear too), Ctrl+L the latest room, Ctrl+Shift+Alt+1 the menu. The pause menu's SAVE HUNT / LOAD HUNT: the saves on one full screen with the hunt's map.
Your character's progression is never touched. Settings: scripts/savestates_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
