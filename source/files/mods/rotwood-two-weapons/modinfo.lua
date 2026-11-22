local version = "1.0.14"

return {
	name = "Two Weapons",
	description = [[Two weapons: swap between the one in hand and your other one with left stick click (keyboard M), behind the dodge-cancel puff. Swap mid-dodge or with X / Y / B held for a swap attack with the new weapon. Each weapon remembers its meter, ammo, cooldowns and power counters between swaps.
Settings: scripts/twoweapons_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
