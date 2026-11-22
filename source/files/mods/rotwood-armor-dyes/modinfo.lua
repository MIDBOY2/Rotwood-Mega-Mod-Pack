local version = "0.6.0"

return {
	name = "Armor Dyes",
	description = [[Dye your armour: helmet, body and legs separately. 14 subtle dyes from the armour art, 21 colour dyes (the player colour wheel) and 4 soft player colours.
A brand-new character starts with its basic armour in its player's soft colour.
Turns on the game's unused ARMOUR DYE tab in the character screen (the mirror in town). Colours are tinted at runtime (no new art), matched to each armour set.
Saved per character and per armour piece; loadouts remember their dyes and the loadout statue shows them (and Morphic boss looks).
Imbued boss looks (0.5.0): the seven bosses' armour and weapons in their imbued colours, first in each boss look's dye list and as mirage patterns, with their own icons. Settings: scripts/armordyes_settings.lua. Local play, up to 4 players.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
