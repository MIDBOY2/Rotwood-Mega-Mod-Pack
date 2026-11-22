local version = "0.4.3"

return {
	name = "Progression",
	description = [[Boss gear progression with one switch (scripts/progression_settings.lua, mode =):
"off": the game as it is.
"permanent": a main boss beaten on Super Frenzy gives its weapon for the 2 weapons you hold, the 3 Morphic pieces (once) and 1 of its Morphic gems (up to 3).
"liri": a main boss beaten on Super Frenzy gives its weapon for the 2 weapons you hold, the 3 Morphic pieces and all 3 gems; Super Frenzy hearts x2 (the extra up to 30 of a boss's, held + in its weapons), corestones x3, gifts x2; one market armour piece gives the whole set.
"nightly": game night. Pick any level on the map; any boss kill gives its weapon for all 6 weapon types (main bosses also the Morphic pieces, their look and all 3 gems; minibosses their armour set); all weapon types from the start; double drops except Teffra; one market armour piece gives the whole set.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
