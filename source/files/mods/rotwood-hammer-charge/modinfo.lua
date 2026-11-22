local version = "0.1.3"

return {
	name = "Hammer Charge",
	description = [[Every hammer gets the Sedament hammer's chargeable light attacks: hold X (keyboard: light attack) to charge;
a full charge is a focus hit that knocks down and deals the game's bonus damage. Heavy (Y) charging is unchanged (all hammers have it).
Settings: scripts/hammercharge_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
