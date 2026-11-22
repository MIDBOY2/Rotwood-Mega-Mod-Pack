local version = "0.2.0"

return {
	name = "UI Scale",
	description = [[Your character info and the power popup (with its Take / Reroll prompt) smaller or bigger, each with its own size.
Menus, the map and everything else stay the game's own (the whole interface is an option, off).
Options > Graphics, or Ctrl + = / Ctrl + - (character info), Ctrl + Alt + = / Ctrl + Alt + - (power popup).
Remembered. Settings: scripts/uiscale_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = true,
	all_clients_require_mod = false,
}
