local version = "0.11.3"

return {
	name = "Frenzy Levels",
	description = [[Pick a main hunt's Frenzy level (1 to 5) on the map. The game makes every frenzied main hunt Frenzy 5, and side hunts get frenzy only with weather (1 to 4). With the hunt in Frenzy mode on the map, LB / RB (Q / E) change the level; the title shows it and the dungeon tier follows. Bosses drop cosmetic armour more often (Frenzy 10-40%, Frenzy 5 and Super Frenzy every boss). Side hunts too (No frenzy to 5), and the side hunts you frenzy yourself give more corestones. Drakinspawn drop Drakin armour and weapon looks; every Blight boss drops a mirage. An experiment: RB past Frenzy 5 on a side hunt you frenzied yourself picks Super Frenzy 1 to 5 (the game's Super Frenzy levels, every fight room hard, loot x1.5 to x2.5, the boss's end drop like a Super Frenzy main boss's). Harder choices pay more: weather side hunts at Frenzy 5 get more from the weather meter, Nimble's two challenges in one run at Frenzy 5 or Super Frenzy give a power upgrade, a reroll and an extra life, side hunts you frenzy yourself give more ingots and materials, and repeat Super Frenzy main clears give Heart Shards. Super Frenzy level skip: once any main boss is beaten at Super Frenzy 1, LB / RB pick Super Frenzy 1 to 5 on every main hunt with any weapon, and a win clears every level up to it for both weapons you hold, one Imbued Heartstone per level per weapon.]],
	author = "midboy",
	version = version,
	mod_version = version,
	api_version = 1,

	mod_type = "gameplay",
	supports_mode = { rotwood = true },

	client_only_mod = false,
	all_clients_require_mod = true,
}
