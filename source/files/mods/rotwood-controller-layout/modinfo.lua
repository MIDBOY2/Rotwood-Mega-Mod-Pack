local version = "0.1.9"

return {
	name = "Controller Layout",
	description = [[Right stick: push to open the emote ring, move to pick, let go to play.
D-pad down = build (was RS-click). LT no longer opens emotes. Customize town stays in the game's options.
Settings: scripts/controllerlayout_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
