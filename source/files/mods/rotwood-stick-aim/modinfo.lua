local version = "0.1.1"

return {
	name = "Stick Aim",
	description = [[Controller: the right stick can aim, like the mouse (per player; BACK + right stick click switches Aim / Emotes).
While aiming the buttons trade places: RB light attack, RT heavy, LB skill, LT dodge; A interact, B potion, X / Y the LT / RT skill slots.
Settings: scripts/stickaim_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
