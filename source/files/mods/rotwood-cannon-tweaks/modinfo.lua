local version = "0.1.0"

return {
	name = "Cannon Tweaks",
	description = [[The cannon's weapon powers with your own numbers: Single Shot holds 3 rounds, Return to Sender
costs -20% range and a catch reloads 2, Bottomless Clip refills 3 rounds a second and overheats 2.75 s.
Every number is a setting: scripts/cannontweaks_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = true,
	all_clients_require_mod = false,
}
