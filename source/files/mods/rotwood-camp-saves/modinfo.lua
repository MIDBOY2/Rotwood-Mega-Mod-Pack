local version = "0.1.1"

return {
	name = "Camp Saves",
	description = [[No more stutter every 10 seconds while you decorate the camp.
The game saves everything (your character, the camp, its room) 10 seconds after any decoration is picked up or placed, a hitch of about 80-110 ms each time. Here those saves wait while you're in build mode and happen once, a moment after you leave it (or when the pause menu opens, or after 3 minutes at most). The save itself is the game's own.
Settings: scripts/campsaves_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = false,
}
