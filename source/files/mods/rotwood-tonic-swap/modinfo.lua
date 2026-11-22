local version = "0.7.13"

return {
	name = "Tonic Swap",
	description = [[D-pad left / right cycles your tonic (drunk together with your potion).
A tonic station (the Potion Table: Build menu, Furniture / Usable; or the Ironwork Illuminator) opens the potions menu: your potion (all three of the game's potions) on top, and one grid of tonics (A in / out of the cycle, X main tonic, Y cycling off), per player.
Settings: scripts/tonicswap_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
