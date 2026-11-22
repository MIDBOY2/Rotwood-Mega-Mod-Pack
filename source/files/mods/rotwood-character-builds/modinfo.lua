local version = "0.2.0"

return {
	name = "Character Builds",
	description = [[Save a whole character as a build in one click (look, gear, inventory, loadouts, talents, everything)
and load all or part of it (look, look keeping your face, colours, gear) onto any character, right away.
One file outside every save. BUILDS tab at the mirror, or Ctrl + B in town. Settings: scripts/characterbuilds_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
