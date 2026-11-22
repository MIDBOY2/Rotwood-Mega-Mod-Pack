local version = "0.2.8"

return {
	name = "Player Colours",
	description = [[Pick each character's player colour: 23 colours at the game's own saturation and brightness, or Vanilla (the game's colour for your player number).
A PLAYER COLOUR tab in the character screen (the mirror in town), after ARMOUR DYE, with a live preview of your HUD in the colour you point at. Save Changes recolours everything at once. Saved with the character.
Uses the game's own player colour system: the HUD, health bar, portrait, name, selection brackets, silhouette, the ring under your feet, the aim arrow, the Spring Port's machines and the other per-player effects all follow it. No new art, nothing runs per frame.
Settings: scripts/playercolours_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
