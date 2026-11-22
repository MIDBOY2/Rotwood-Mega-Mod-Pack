local version = "0.1.0"

return {
	name = "Powers First",
	description = [[While powers are waiting to be picked, NPCs, meals and everything else you can use are switched off,
so a power that lands on them can always be picked. They come back the moment power choosing is over.
Settings: scripts/powersfirst_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = true,
	all_clients_require_mod = false,
}
