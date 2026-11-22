local version = "0.2.22"

return {
	name = "Weapon Moves",
	description = [[Moves the game has animations for but never uses. Bow: the leap shot (X in the middle of a roll: spring up and shoot from the top of the jump; X at the landing stays the kneel shot). Hammer: the spin finale (B during the spin: roll, X with the stick pulled back, then Y; then B: when that spin comes round, one more spin, a rising knockdown swing, carried up, land; the hammer stays on your back in camp, you draw it on a run; Focus spins throw the game's cyan Focus sparks, a Focus rise the same sparks; a whirlwind round the spin in the air). Each move can be switched off in scripts/weaponmoves_settings.lua.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
