-- Progression settings. Restart the game after changing this file.
return {
	-- The switch:
	--   "off"        the game as it is
	--   "permanent"  everyday play: Super Frenzy boss kills give the boss's gear
	--   "liri"       in between: Super Frenzy boss kills give all the boss's
	--                gear at once, more Super Frenzy hearts, corestones and
	--                gifts, and one market armour piece gives the whole set
	--   "nightly"    game night: a condensed Rotwood (back up your save first,
	--                its unlocks and gear stay in the save)
	mode = "liri",

	-- mode = "permanent": each player who's there when a main boss dies on
	-- Super Frenzy gets:
	permanent = {
		-- the boss's weapon for the 2 weapons you hold: the one in hand and the
		-- Two Weapons swap weapon (without Two Weapons, just the one in hand)
		weapons = true,

		-- the 3 Morphic armour pieces (Crown, Breastplate, Greaves), the first time
		morphic_set = true,

		-- this many of the boss's Morphic gem per kill, up to the game's cap of 3
		gems_per_kill = 1,

		-- false: any level counts, not just Super Frenzy (for trying it out)
		super_frenzy_only = true,

		-- Super Frenzy hearts (Imbued Heartstones): picking one up gives this
		-- many. 1 = the game's own amount, up to 20. They upgrade boss weapons
		-- (level 11 to 15, 1 heart + 10 of the hunt's ingots per level).
		super_frenzy_heart_multiplier = 1,

		-- With the multiplier above 1: its extra hearts stop once you have this
		-- many of that boss's Imbued Heartstones, counting the ones held and the
		-- ones already in its weapons (1 for each of its weapons you have, 1 for
		-- each upgrade past level 11). 30 = all that boss's weapons need: 6
		-- weapons x (1 to make + 4 upgrades); the game gives one per Super
		-- Frenzy clear, 6 weapons x 5 levels = 30. The game's own hearts are
		-- never cut, only the extra. 0 = no cap.
		super_frenzy_heart_cap = 30,

		-- With Two Weapons: clearing a Super Frenzy level counts for both
		-- weapons you hold (the game counts only the one in hand). Each weapon
		-- type goes one level up from its own record, like the game does.
		super_frenzy_both_weapons = true,
	},

	-- mode = "liri": each player who's there when a main boss dies on Super
	-- Frenzy (any Super Frenzy level) gets the boss's weapon for the 2 weapons
	-- they hold, the 3 Morphic pieces and all 3 of the boss's Morphic gems.
	liri = {
		weapons = true,
		morphic_set = true,
		gems_per_kill = 3, -- 3 = all of them at once
		super_frenzy_only = true,

		-- Super Frenzy hearts (Imbued Heartstones): picking one up gives this many (1 to 20).
		-- 1 = single, as the game: one per clear (they're per clear and have no
		-- use past what the boss's weapons need)
		super_frenzy_heart_multiplier = 1,

		-- the multiplier's extra hearts stop once you have this many of that
		-- boss's Imbued Heartstones: held + already in its weapons (1 per weapon
		-- you have + 1 per upgrade past 11). 30 = all its weapons need; 0 = no cap
		super_frenzy_heart_cap = 30,

		-- clearing a Super Frenzy level counts for both weapons you hold
		super_frenzy_both_weapons = true,

		-- every corestone pickup gives this many times as much (1 to 5)
		corestone_multiplier = 3,

		-- every Gift-Wrapped Souvenir pickup gives this many times as much (1 to 5)
		gift_multiplier = 2,

		-- buying one armour piece at the market gives the whole set
		market_full_set = true,
	},

	-- mode = "nightly":
	nightly = {
		-- Map: LB / RB (the game's "previous / next tab" buttons) picks the
		-- level of the hunt you're looking at: Normal, Frenzy 1-5, and Super
		-- Frenzy 1-5 on main hunts (side hunts have no Super Frenzy boss).
		-- Only hunts you've unlocked; Blight Incursions are left as the game
		-- has them (they open after the final boss).
		pick_any_level = true,

		-- Beating a boss at any level puts its gear in your inventory (each player):
		--   every boss and miniboss: its weapon for all 6 weapon types
		--   main bosses: the 3 Morphic armour pieces, their look (mirage) and
		--                all 3 of their Morphic gems
		--   the final boss: the 3 Morphic armour pieces
		--   minibosses: their armour set
		boss_gear = true,

		-- All 6 weapon types unlocked from the start, each with its basic weapon.
		all_weapon_types = true,

		-- Everything you pick up counts double except Teffra: materials,
		-- corestones, Gift-Wrapped Souvenirs, heart shards, Super Frenzy hearts, Glitz.
		-- (Heartstones stay single: one unlocks the boss's talents, a second does nothing.)
		double_pickups = true,
		double_amount = 2,

		-- Buying one armour piece at the market gives the whole set.
		market_full_set = true,
	},

	debug = false,
}
