local version = "0.3.1"

return {
	name = "Camp Brother (experiment)",
	description = [[Gishins, Doc Hoggins' brother, at his station in the camp between Lottie and Toot: Doc's big potion wagon on a stone floor, his red table, a potion table. A game NPC: he turns to face you and has a Chit Chat (RB) about potions and tonics. The chest and the starting camp move to the bottom-left corner.
Settings: scripts/campbrother_settings.lua; his lines: scripts/campbrother_strings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
