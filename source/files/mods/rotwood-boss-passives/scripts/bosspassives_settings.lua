-- Boss Weapon Passives settings. Edit, save, restart the game.
--
-- One passive per boss, on all six of its weapons (Hammer, Spear, Greatsword,
-- Bow, Cannon, Striker). on = false: that boss's weapons keep the game's
-- placeholder (no passive).

return {
	enabled = true,

	-- Bulletproofing: an error inside a passive is logged ("[Boss Passives]
	-- error in ...") and skipped, instead of the game's error screen ending
	-- the run. false: errors go to the game as before.
	guard = true,

	-- Mother Treek: hitting a knocked-down enemy heals you, up to a cap a room.
	-- (Your heal powers' bonuses don't add to it: it heals heal_per_hit.)
	megatreemon = { on = true, heal_per_hit = 5, max_per_room = 50 },

	-- Owlitzer: a perfect dodge (an attack passes through you while you dodge)
	-- lets loose a gust of wind on both sides of you, and your next attack
	-- within crit_seconds is a critical hit. The gust hits every enemy within
	-- gust_radius for gust_damage times your weapon's damage (1.0 = the same;
	-- 0 = no damage) and pushes them away (gust: "weak", "medium", "strong" or
	-- "" for no push). gust_look = "whirlwind" adds the Windmon's wind spin
	-- round you on top of the gust (whirlwind_scale = its size; "" = the gust's
	-- puffs only).
	owlitzer = { on = true, crit_seconds = 4, gust = "medium", gust_damage = 1.0, gust_radius = 4.5,
		gust_look = "whirlwind", whirlwind_scale = 1.5 },

	-- Bandicoot: a successful Parry or a perfect dodge: for seconds, every hit
	-- you land strikes again (damage = that much of the hit).
	bandicoot = { on = true, seconds = 3, damage = 1.0 },

	-- Thatcher: every every_hits hits in a hit streak, a swarm bursts out of
	-- you and coats enemies within radius in Acid.
	thatcher = { on = true, every_hits = 25, radius = 6 },

	-- Sedament: each kill adds damage for the rest of the room, up to max_stacks.
	sedament = { on = true, damage_per_kill = 0.05, max_stacks = 5 },

	-- Eggzy: a critical hit that kills makes the enemy explode, at most once
	-- every cooldown seconds.
	eggzy = { on = true, cooldown = 3 },

	-- Grimhollow (Bastion Bark): during your heavy attacks you take
	-- front_reduction less damage from the front (0.4 = 40% less); a heavy
	-- attack that lands: after_heavy_reduction less damage from every side for
	-- after_heavy_seconds. Both at once multiply (40% and 25% = 55% less).
	grimhollow = { on = true, front_reduction = 0.4, after_heavy_reduction = 0.25, after_heavy_seconds = 3 },
}
