-- Frenzy Levels settings. Restart the game after changing.
return {
	-- false = the game's way (frenzied main hunts are always Frenzy 5)
	enabled = true,

	-- The lowest level LB / Q goes to: 1 = Frenzy 1. 0 = also "Standard"
	-- (the hunt with no frenzy, like before you cleared the zone).
	min_level = 1,

	-- A hunt you haven't picked a level for yet starts at this level
	-- (5 = the game's Frenzy).
	default_level = 5,

	-- The level under the hunt's name in the map's side panel, with the
	-- LB / RB (Q / E) buttons. false = no text (the dungeon tier badge still
	-- changes).
	show_in_title = true,

	-- Side hunts (the smaller hunts around each main one, like Acrid Glade
	-- next to Nocturne Grove): LB / RB pick No frenzy or Frenzy 1 to 5 there
	-- too. The game frenzies them only while they have weather, at a level it
	-- picks (1-4); a side hunt you never changed keeps the game's level.
	-- The game's anomalies (side hunts it frenzies with weather) never go to
	-- Standard and keep the game's Frenzy look. A side hunt you frenzy
	-- yourself: X (keyboard Shift) on the map switches its look between the
	-- game's Frenzy colours and the hunt's normal ones (saved per hunt).
	-- false = the game's way.
	side_hunts = true,

	-- The game colours every frenzied hunt with a dark purple dusk (its
	-- Frenzy lighting). true = the game's dusk. false = the hunt's normal
	-- colours in Frenzy 1 to 5 (only the look: enemies, difficulty and
	-- rewards stay the Frenzy's). super_frenzy_look: the same for Super Frenzy.
	frenzy_look = true,
	super_frenzy_look = true,

	-- Cosmetic armour: the chance, in percent, that a boss kill drops a
	-- piece, by level. frenzy = Frenzy 1 to 5 (main and side hunts),
	-- super_frenzy = Super Frenzy 1 to 5. A miss adds that chance to your next
	-- boss until one drops (the game's own catch-up). No frenzy keeps the
	-- game's 1%. 100 = every boss drops one (while you have pieces left to
	-- get). The game's: Frenzy 2 3 4 5 7.5, Super Frenzy 10 12 14 16 20.
	-- false = the game's chances.
	cosmetic_chance = {
		frenzy = { 10, 20, 30, 40, 100 },
		super_frenzy = { 100, 100, 100, 100, 100 },
	},

	-- More corestones, by Frenzy 1 to 5. The game's anomalies have their
	-- reward meter (gems, ingots, heart shards); the side hunts you frenzy
	-- yourself get extra corestones instead.
	--   boss  = extra on the boss kill (the game gives 1 1 2 2 3 at Frenzy
	--           1-5, so this doubles it; nothing extra when the boss gives
	--           its heart instead)
	--   rooms = extra in a corestone room and from a Teffra Zucco (the game:
	--           1, or 2 in a hard room)
	--   hunts = "frenzied_side" (side hunts you frenzied, not anomalies),
	--           "all_side" (anomalies too) or "all" (main hunts too; Super
	--           Frenzy gets Frenzy 5's numbers)
	-- false = the game's.
	corestone_bonus = {
		boss = { 1, 1, 2, 2, 3 },
		rooms = { 1, 1, 1, 2, 2 },
		hunts = "frenzied_side",
	},

	-- Drakinspawn (the Drakin Armoury Pack's dragon minibosses). The game: a
	-- heart shard each, and once you've finished Brother Tendy's quest a 25%
	-- chance of one Drakin armour piece (Skyhunter, Marrowdeep: 6 pieces; the
	-- quest gives the Immaculate Edge set). The Drakin weapon looks
	-- (Drakinlance, Forgeheart, Ashfall Sledge, Wingpiercer, The Brimstone,
	-- The Clawboom Stick) drop only in Blight Incursions.
	-- Here every Drakinspawn drops pieces while you have some left to get:
	--   pieces       = how many each (4: all 12 by the end of the quest)
	--   during_quest = true: Tendy's own three fights drop them too
	--   weapons      = true: the weapon looks drop from them too
	-- false = the game's.
	drakin_rewards = {
		pieces = 4,
		during_quest = true,
		weapons = true,
	},

	-- Blight Incursions: the game gives no cosmetic on a boss kill there; its
	-- mirages (the Blight's armour sets, the Drakin weapon looks, mirages of
	-- gear you own from the hunts you passed) come only from Nimble's Cache,
	-- rarely (about 0.2% to 3% a Blight for one particular look).
	-- true = every Blight boss drops one while you have some left to get.
	-- false = the game's.
	blight_mirages = true,

	-- Super Frenzy 1 to 5 on the side hunts you frenzy yourself (an
	-- experiment). On the map, RB past Frenzy 5 on a side hunt you frenzied
	-- yourself (not an anomaly) picks "Super Frenzy 1", then 2 to 5: the panel
	-- and the marker turn the game's Super Frenzy dark purple and the tier
	-- badge shows that level's tier. The run is the game's Frenzy 5 run (maps,
	-- progress, rewards, look) with:
	--   enemies    = the game's Super Frenzy level (SF1 / 2 / 3 / 4 / 5):
	--                health x3.0 / 3.45 / 3.7 / 3.83 / 3.95 (Frenzy 5 x2.8),
	--                damage x3.0 / 3.45 / 3.7 / 3.95 / 4.2 (x2.8), every
	--                enemy that can be elite is elite (55%), the side hunt's
	--                boss x7.5 / 8.2 / 8.55 / 8.73 / 8.9 health (x4.9);
	--                harder traps (more from SF2), SF4 you start 250 health
	--                down, SF5 the higher prices. The boss stays its own one
	--                (no elite side bosses, no double miniboss fight)
	--   all_hard   = true: every fight room is a hard room (the horned map
	--                icon), weapon power and friend gift rooms too
	--   loot       = x1.5 / 1.75 / 2 / 2.25 / 2.5 by level (or one number for
	--                all): Corestones, materials, ingots, seeds and Heart
	--                Shards, on top of Frenzy 5's and the hard rooms'
	--                (rounded at random: the average is exact)
	--   teffra     = false: Teffra (konjur) stays the game's (true: x loot too)
	--   unlock_all = true: all five levels open (for testing); false: Super
	--                Frenzy 1 is open and each next level opens when you win
	--                the one below on that side hunt
	--   boss_like_main = true: the boss's end drop starts from a Super Frenzy
	--                main hunt boss's Corestones and ingots (6 and 5; Frenzy
	--                5: 5 and 3), then the loot multiplier; false: Frenzy 5's
	--   weather    = true (0.10.0): weather side hunts (the game's anomalies)
	--                get Super Frenzy 1 to 5 too, RB past Frenzy 5 the same
	--                way: the same run with the weather, and each tier of the
	--                weather meter gives Frenzy 5's rewards x the loot above
	--                (gems and Heart Shards too); false: weather side hunts
	--                stop at Frenzy 5
	--   imbue_gem  = 5 (0.11.3): the Teffressence Container gem works on the
	--                side hunt's boss from this Super Frenzy level (the game's
	--                gem: kill the boss with it in your weapon, the weapon can
	--                be upgraded past level 10; the game only does it on main
	--                hunts). 5 = Super Frenzy 5 only, 1 = every level, false =
	--                never (the game's). Two Weapons' second weapon too.
	-- false = no Super Frenzy steps (RB stops at Frenzy 5).
	super_side_hunts = {
		enabled = true,
		loot = { 1.5, 1.75, 2, 2.25, 2.5 },
		teffra = false,
		all_hard = true,
		unlock_all = true,
		boss_like_main = true,
		weather = true,
		imbue_gem = 5,
	},

	-- Main hunts at Super Frenzy 1 to 5 (the game's): the game gives the same
	-- loot at every Super Frenzy level; here it grows with the level, like the
	-- Super Frenzy side hunts (corestones, monster and boss materials, ingots,
	-- seeds, heart shards; not boss hearts). teffra = true: Teffra too.
	-- false = the game's.
	super_main_loot = {
		loot = { 1.5, 1.75, 2, 2.25, 2.5 },
		teffra = false,
	},

	-- Main hunts at Super Frenzy 1 to 5: more hard rooms (0.10.0). The game's
	-- hard rooms are its harder fights (more and tougher enemies) with its
	-- bigger rewards (more Teffra, 2 Heart Shards, more materials and
	-- Corestones, better power odds), and it shows few of them. Here a step
	-- for each Party Gear Level above gear_from (the game's own number, shown
	-- on the map; up to gear_max) and each Super Frenzy level above 1: up to
	-- 9 steps. Each fight door that isn't hard becomes hard with a chance of
	-- steps / 9 (0 steps: the game's, about 1 in 6 fight doors with Hunt
	-- Rooms; 4 steps: about half; 9 steps, gear 15 at Super Frenzy 5: every
	-- fight room hard). Read when the run starts. false = the game's.
	super_main_hard = {
		gear_from = 10,
		gear_max = 15,
	},

	-- Weapon power and friend gift rooms made hard by the rules above (Super
	-- Frenzy side hunts, the main hunts' extra hard rooms; the game never has
	-- them hard): true = they're hard too, and give hard_power_room_teffra
	-- more Teffra from the room's kills (35: the game's Teffra for skipping a
	-- power); false = they stay the game's (never hard).
	hard_power_rooms = true,
	hard_power_room_teffra = 35,

	-- The gold preview (0.10.3): this key turns every hunt's map marker gold
	-- (the gold side hunt shield, the main hunts' gold one), to see how they
	-- look. Visual only: nothing is saved; press it again (or restart the game)
	-- for the markers as they are. Modifiers are exact ("Ctrl+Shift+Y" isn't
	-- "Ctrl+Shift+Alt+Y"); not while typing. "" = no key.
	gold_preview_key = "Ctrl+Shift+Y",

	-- More for the harder choices (0.9.0). Nothing is taken away: every level
	-- keeps what the game gives it; these add to the harder ones.

	-- Weather side hunts (anomalies): the game picks their level (1-4); here
	-- you can raise it. Extra rewards from each tier of the weather meter you
	-- reach, by Frenzy 1 to 5, drawn from that tier's own bag (gems, Heart
	-- Shards, ingots, materials, seeds; the top tier a gem seed too).
	-- { 0, 0, 0, 0, 1 } = one more from each tier at Frenzy 5 (about 2.5
	-- gems and 2.3 Heart Shards a full meter, instead of 1.6 and 1.8).
	-- false = the game's meter at every level.
	weather_bonus = { 0, 0, 0, 0, 1 },

	-- Nimble's two challenges (the curses he offers at a main hunt's start)
	-- both done in one run: at the final market, on top of his Heart Shards,
	-- the game's own bonus for that (switched off in the game): a power
	-- upgrade, a reroll and an extra life, right before the boss.
	--   min_level = from this level: 5 = Frenzy 5 and every Super Frenzy,
	--               6 = Super Frenzy only, 1 = every Frenzy
	--   upgrade / reroll / extra_life = how many of each (0 to 3)
	-- false = the game's (his Heart Shards only).
	nimble_bonus = {
		min_level = 5,
		upgrade = 1,
		reroll = 1,
		extra_life = 1,
	},

	-- Side hunts you frenzy yourself (no weather), Frenzy 1 to 5: the boss
	-- gives each hunter more, on top of the extra corestones above:
	--   ingots    = the area's ingots (in the boss's own loot)
	--   materials = the area's materials (the game's materials room roll)
	-- Not the anomalies (they have the weather meter) or Super Frenzy side
	-- hunts. false = the game's.
	side_boss_bonus = {
		ingots = { 1, 1, 2, 2, 3 },
		materials = { 2, 3, 4, 5, 6 },
	},

	-- Main hunts at Super Frenzy 1 to 5, a repeat clear (a level that weapon
	-- already cleared there, so no Imbued Heartstone this time): the boss
	-- gives each such hunter this many Heart Shards, a fixed number (the
	-- Super Frenzy loot multiplier above leaves them alone). Nimble's Heart
	-- Shards come on top. false = the game's.
	super_main_shards = { 1, 1, 2, 2, 3 },

	-- The Super Frenzy level skip, main hunts (0.11.0). The game: the Super
	-- Frenzy panel goes one level above what the weapon in your hand has
	-- cleared on that hunt, and a win clears one level for that weapon only,
	-- one Imbued Heartstone. Here LB / RB on the panel go up to Super Frenzy 5,
	-- and a win at Super Frenzy N clears every level up to N for each weapon
	-- you hold, with one Imbued Heartstone per level newly cleared per weapon
	-- (the boss's drop gives the first, the rest come with the win). The
	-- panel shows how many a win gives.
	--   unlock = "any_hunt" (mode 2): once any main boss is beaten at Super
	--            Frenzy 1 (any weapon; a save that has one already counts),
	--            every main hunt goes to 5 with any weapon. e.g. Mother Treek
	--            SF1 with hammer and bow, then Bandicoot SF5 with both: 10
	--            clears, 10 hearts
	--            "this_hunt" (mode 1): a weapon goes to 5 on a hunt once it
	--            has cleared Super Frenzy 1 there; a weapon that hasn't gets
	--            the game's one level
	--   both_weapons = true: Two Weapons' second weapon too (its clears and
	--            hearts); false: the weapon in hand only (Progression's one
	--            level up for the second weapon, no heart)
	-- Progression's liri mode doubles every Imbued Heartstone (its
	-- super_frenzy_heart_multiplier), these too. false = the game's.
	super_skip = {
		unlock = "any_hunt",
		both_weapons = true,
	},
}
