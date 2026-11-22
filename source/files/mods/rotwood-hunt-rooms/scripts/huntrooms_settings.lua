-- Hunt Rooms settings. Change a number, save, restart the game.
-- A value that isn't a number (or is out of range) falls back to the default
-- and the log says so ("[Hunt Rooms] setting ...").
return {
	enabled = true,

	-- The start of every hunt, two modes:
	--   true   the start room gives its own pick (a normal power, or the
	--          Fabled of main hunts and the Blight), then a legendary weapon
	--          power choice. With Two Weapons: one for each of your weapons.
	--   false  the game's start: a weapon power choice only when the game
	--          rolls a weapon power start room (with Two Weapons: one for
	--          each weapon then too); a normal start gets nothing extra.
	-- Takes effect from the next run you start.
	start_weapon_power =true,
	-- The start's weapon power choice flies out with the crystal's split sound
	-- (the crystal already shattered for the start's own pick, so it was
	-- silent). false = no sound.
	split_sound = true,

	-- The most rooms a run gives (rooms you take):
	--   weapon_power_rooms: legendary weapon power rooms, counting the start
	--     (4 = every weapon power a hammer, spear, bow or cannon has)
	--   extra_fabled: Fabled rooms on top of the game's own (its start room,
	--     its minibosses and its own Fabled doors don't count)
	weapon_power_rooms = 4,
	extra_fabled = 3,

	-- How many times a weapon power door can show up in a hunt, the start's
	-- choice not counted. Each one counts the moment it's offered, taken or
	-- not: skip it and it's gone. Past it, weapon power doors are normal
	-- power doors (an extra room's: Fabled or a normal power). The game's own
	-- weapon power doors count too (start_weapon_power = false: a start the
	-- game made a weapon power room counts as one).
	--   weapon_power_doors: side and main hunts (the game's own: 1)
	--   weapon_power_doors_blight: the whole Blight (the game's own: 2)
	weapon_power_doors = 2,
	weapon_power_doors_blight = 3,

	-- Rooms that come between two weapon power rooms, at least (the start's
	-- choice counts as one). 1 = never two in a row; 2 = two other rooms
	-- between; 0 = no rule. A weapon power door that would break it is a
	-- normal power door (an extra room's: Fabled or a normal power).
	weapon_power_gap = 1,

	-- When a room offers one of the two, the chance (percent) it's Fabled
	-- rather than a weapon power (when both can still come).
	fabled_share = 50,

	-- Frenzied side hunts (Frenzy 1-5, anomalies too): extra rooms.
	frenzy_side_rooms = 1,
	-- Super Frenzy side hunts (Frenzy Levels): extra rooms by level 1 to 5.
	super_side_rooms = { 1, 2, 3, 4, 5 },
	-- What an extra side hunt room offers: door weights (one of each at most;
	-- the game's 1 to 3 doors). 0 = never.
	side_room_doors = { fabled = 40, weaponpower = 30, plain = 30 },

	-- The Blight: extra rooms in each of its two long middle parts, and what
	-- they offer (a normal power once both are used up).
	blight_rooms = 2,
	blight_room_doors = { fabled = 50, weaponpower = 50 },
	-- The most weapon power rooms in one part (leg) of the Blight: the game's
	-- own and the extra rooms' (the start's choice counts in the first part).
	-- Past it, that part's weapon power doors are normal power doors.
	-- (weapon_power_rooms above still caps the whole Blight.)
	blight_weapon_rooms_per_leg = 2,
	-- The Blight's miniboss (its Fabled pick, the only Fabled the game gives in
	-- the long middle parts): every middle part offers it (the game's own roll
	-- first; a part without it by its room 5 gets it at the next door choice
	-- with a door to give), and its door choice never has a Fabled or weapon
	-- power door beside it (those become normal power doors), so you never
	-- pick between them. false = the game's (about 1 part in 7 without one,
	-- sometimes beside one).
	blight_miniboss = true,

	-- Frenzied main hunts (Frenzy 1-5): the chance (percent) that a door
	-- choice with a normal power, corestone, gift or material door gets one
	-- of them turned into a Fabled or weapon power door, and the share
	-- (percent) of those taken from normal power doors (50: half the hit on
	-- normal powers, half on corestone, gift and material doors).
	frenzy_main_chance = 25,
	frenzy_main_from_powers = 50,

	-- Super Frenzy main hunts:
	--   halve: the share (percent) of corestone, gift and material doors that
	--     become Fabled or weapon power doors (while those can still come)
	--   from_powers: the same for normal power doors (a tiny bit)
	--   reward: corestone, gift and material rooms give this many times
	--     their reward (2 = twice as rare, twice the reward)
	super_main_halve = 50,
	super_main_from_powers = 5,
	super_main_reward = 2,

	-- The run's 2 Fabled families (the game picks 2 of Electric, Shield,
	-- Summon and Frost at every run's start; every Fabled pick of the run
	-- offers those two). Never this pair (false: any pair), and this family
	-- in fabled_favour_share percent of runs (false: no favourite). With
	-- 75: Electric + Shield / Summon / Frost 25% each, Frost + Shield /
	-- Summon 12.5% each. The normal powers linked to the Fabled you hold
	-- follow on their own.
	fabled_never_pair = { "SHIELD", "SUMMON" },
	fabled_favour = "ELECTRIC",
	fabled_favour_share = 75,

	-- The miniboss's Fabled pick (a main hunt's room 9, the Blight's middle
	-- parts): this many Fabled powers (2 from each family at 4), plus the
	-- normal power as always. 2 = the game's.
	miniboss_fabled = 4,

	-- The miniboss's rewards, for each player, on top of what it gives now
	-- (its Fabled pick, its own material draw and Teffra): Corestones, the
	-- area's ingots, a few of the area's materials (the game's materials
	-- room roll) and Teffra, by the hunt's level: normal, Frenzy 1-5, Super
	-- Frenzy 1-5, the Blight. Frenzy Levels' Super Frenzy loot multiplier and
	-- Progression's pickups apply as to any drop. false = the game's.
	miniboss_rewards = true,
	-- (Corestones: the game's Corestone room drop when the room is cleared, at most 5)
	miniboss_corestones = { normal = 1, frenzy = { 1, 1, 1, 1, 2 }, super = { 2, 2, 2, 2, 2 }, blight = 2 },
	miniboss_ingots     = { normal = 0, frenzy = { 1, 1, 2, 2, 3 }, super = { 4, 4, 4, 4, 4 }, blight = 3 },
	miniboss_materials  = { normal = 1, frenzy = { 1, 1, 2, 2, 2 }, super = { 3, 3, 3, 3, 3 }, blight = 2 },
	miniboss_teffra     = { normal = 10, frenzy = { 14, 18, 22, 26, 30 }, super = { 34, 38, 42, 46, 50 }, blight = 30 },

	-- The Heart Shard room (Super Frenzy side hunts, Frenzy Levels): the
	-- chance (percent) each extra room's doors have one, by Super Frenzy
	-- level 1-5, offered until you walk into one (then never again that
	-- hunt), and the Heart Shards it gives each player (a fixed number).
	-- 0 (or false) = none.
	shard_room = { 40, 45, 50, 55, 60 },
	shard_room_shards = { 1, 2, 3, 4, 5 },

	-- Log every room the mod changes ("[Hunt Rooms] ..." in client_log.txt).
	debug = false,
}
