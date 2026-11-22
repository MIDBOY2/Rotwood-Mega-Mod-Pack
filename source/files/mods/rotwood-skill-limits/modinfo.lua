local version = "0.5.2"

return {
	name = "Skill Limits",
	description = [[Strong skills with no limit of their own get charges: 5 uses, and 5 seconds after the last use they all come back.
With no charges left the skill doesn't fire (the game's "no charge" sound) and its icon goes grey with a red X and counts down, like the game's own cooldown skills.
Bow arrow skills use ammo (3, +1 per 500 damage dealt) and go straight into a heavy shot; a Focus release fires the special arrow. Out of arrows, the button does the arrow dip, which makes one.
Skills that already have a limit are left alone. Which skills and the numbers: scripts/skilllimits_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
