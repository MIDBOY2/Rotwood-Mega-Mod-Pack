local version = "0.2.1"

return {
	name = "Blight Fix",
	description = [[Blight Incursion: after a two-stage leg where you took the second portal, the game carries "stage 2" into the next leg even when that leg (a Rest Room) has only one stage. Both crashes happened loading that Rest Room. This keeps the stage valid (stage 1 for a one-stage leg) before the game uses it.
The Blight's purple overlay: faded to 10% (the default), the game's own, or off; Ctrl+B cycles it.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
