local version = "0.2.9"

return {
	name = "Boss Weapon Passives",
	description = [[The boss weapons' passives the game never finished (each boss weapon's power is a placeholder that does nothing). One passive per boss, shared by its six weapons:
Mother Treek: hitting a knocked-down enemy heals you. Owlitzer: a perfect dodge lets loose a gust that hits enemies around you; your next attack crits.
Bandicoot: Parry or a perfect dodge makes every hit strike twice for a moment. Thatcher: every 25 hits in a streak, a swarm burst coats nearby enemies in Acid.
Sedament: each kill adds damage for the room. Eggzy: critical kills explode. Grimhollow: less damage during and after heavy attacks.
Every number in scripts/bosspassives_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
