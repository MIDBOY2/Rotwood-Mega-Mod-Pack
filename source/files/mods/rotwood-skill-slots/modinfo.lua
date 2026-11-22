local version = "0.16.4"

return {
	name = "Skill Slots",
	description = [[Skill buttons: B, LT, RT and RS-click each fire their own skill (B starts as the weapon's skill).
Each weapon type has its own loadout. Pick skills in town: D-pad down, or a skill station (weapon racks, pergola, Wintertide tree, Kuma's Scare-Rot). Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
