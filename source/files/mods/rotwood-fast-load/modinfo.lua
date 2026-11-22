local version = "0.2.1"

return {
	name = "Fast Load",
	description = [[Shorter loading screens. Every load, the game looks for each of its art files in every mod folder first: one disk check per mod per file (about 10 s a load with 15 mods). This lists each mod folder once and skips the folders that don't have the file. Same files found in the same places. Quiet looks: skips the engine calls that re-apply what a character already shows (cuts the "Could not find anim build FROMNUM" log spam).]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
