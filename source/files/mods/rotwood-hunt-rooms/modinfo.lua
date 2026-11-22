local version = "0.3.3"

return {
	name = "Hunt Rooms",
	description = [[More legendary weapon power and Fabled rooms, the game's rooms otherwise:
every run's start also gives a weapon power choice; frenzied side hunts get an extra room (Super Frenzy side hunts one per level), the Blight's middle parts two; frenzied and Super Frenzy main hunts turn some normal power, corestone, gift and material doors into Fabled or weapon power doors. the Blight's miniboss is offered in each middle part, never beside a Fabled or weapon power door; minibosses give a 4-Fabled pick plus Corestones, ingots, materials and Teffra by level; the run's Fabled families are never Shield + Summon and favour Electric; Super Frenzy side hunts can have a Heart Shard room. Teffra, markets, potions and upgrades stay the game's.
Settings: scripts/huntrooms_settings.lua. Console: hr_help() lists the test commands.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
