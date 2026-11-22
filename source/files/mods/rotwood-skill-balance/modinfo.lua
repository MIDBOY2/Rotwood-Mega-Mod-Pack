local version = "0.2.16"

return {
	name = "Skill Balance",
	description = [[Buffs for weak skills, every number in scripts/skillbalance_settings.lua.
Battering Ram, Thwack, Crosscheck: 1.5x their weapon's light attack, knock enemies over.
Trickster's Gambit (parry): longer window, knocks back the enemy you parry, 3 s of crits.
Order in the Court: more damage and a wider slam. Pole Vault, Dribble, Hazard Idol, Impulsive Stomp, Grody Groak Gulp, Big Blast buffed.
Community Garden and Voice of the Myriad: their stocks come back from damage dealt.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
