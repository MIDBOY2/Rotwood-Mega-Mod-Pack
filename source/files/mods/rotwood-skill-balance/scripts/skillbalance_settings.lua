-- Skill Balance settings. Restart the game after changing this file.
-- Damage numbers are multipliers: x your weapon damage (a hammer light hit is 1).
-- Set a section to false to leave that skill the game's way.
return {
	enabled = true,

	-- The ranged weapons' melee skills: Battering Ram (Cannon), Thwack (Bow),
	-- Crosscheck (Spear). Their damage = light_attack_mult x that weapon's own
	-- light attack (Cannon shot 1.25, Bow quick shot 0.85, Spear 1st hit 0.9).
	-- The game: Battering Ram 0.5, Thwack 0.6, Crosscheck 0.45.
	-- knockdown = true: the hit knocks enemies over (Thwack and Crosscheck
	-- already do; Battering Ram only pushed). pushback = how far: x the enemy's
	-- own distance, at 1.0 small enemies fly 4, medium 3, large 2 (light
	-- enemies about 3x that, heavy ones and bosses barely move). The game: 1.5.
	melee_skills = {
		light_attack_mult = 1.5,
		knockdown = true,
		pushback = 1.75,
	},

	-- Trickster's Gambit (parry)
	parry = {
		window_seconds = 0.67,   -- how long the parry catches attacks (the game: 0.43)
		crit_seconds = 3,        -- 100% crit chance after a parry (the game: 2)
		counter_damage = 1.0,    -- the enemy you parry takes this x weapon damage (0 = no counter hit)
		counter_pushback = 1.75, -- and gets knocked over this far (same scale as above)
		counter_range = 6,       -- only an enemy this close (not a far-off shooter)
	},

	-- Order in the Court (Hammer): tap / half charge (held 8+ frames) / full
	-- charge (held 16+ frames, about 0.5 s). The game tunes it like the hammer's
	-- charged heavy: 1.66 / 2.5 / 2.91, Focus 2.5 / 2.91 / 4.58, radius 3 / 3.25 / 4.
	-- Now a touch over the fully charged heavy (2.91, Focus 4.58) at full charge.
	-- (0.2.0 had 2.0 / 3.0 / 4.0, Focus 3.0 / 3.75 / 6.0; 0.2.1 1.8 / 2.7 / 3.3,
	-- Focus 2.7 / 3.25 / 5.0.)
	order_in_the_court = {
		damage = { 1.7, 2.55, 3.0 },
		focus_damage = { 2.55, 3.0, 4.75 },
		radius = { 3.25, 3.5, 4.5 },
	},

	-- Pole Vault (Spear): the hit taking off / landing. The game: 0.33 / 1.0
	pole_vault = { takeoff = 0.5, landing = 2.0 },

	-- Dribble (Striker): the slam / a Focus slam. The game: 1.15 / 1.75
	dribble = { damage = 1.75, focus_damage = 2.5 },

	-- Hazard Idol (Hammer): health it costs to summon. The game: 25.
	-- (The Idol still heals whoever breaks it for 25; its description keeps saying 25.)
	hazard_idol = { health_cost = 10 },

	-- Impulsive Stomp (Greatsword). The game: 2.0 (plus its meter bonus)
	impulsive_stomp = { damage = 2.5 },

	-- Grody Groak Gulp: each of its many tiny hits. The game: 0.1
	grody_groak_gulp = { damage = 0.25 },

	-- Mini parry: a perfect guard at the start of one quick skill per weapon,
	-- treated like the Greatsword's perfect guard (until tested in game). A hit
	-- in its first window_frames (30 per second; the Greatsword's guard window
	-- is 5) does damage_taken of its damage (the Greatsword's: 0.02 = 2%), you
	-- don't flinch (the skill goes on and its own hit is the counter), and you
	-- get the perfect guard's spark, shudder and protections (hit streak kept,
	-- the enemy's on-hit effects skipped). Owlitzer's Morphic gem fires like on
	-- a perfect guard. Not Parry's crit buff, nothing of the Greatsword's own.
	-- Each skill can be turned off: false.
	mini_parry = {
		window_frames = 5,
		damage_taken = 0.02,
		crosscheck = true,          -- Spear
		thwack = true,              -- Bow
		battering_ram = true,       -- Cannon
		order_in_the_court = true,  -- Hammer
		dribble = true,             -- Striker
	},

	-- Big Blast (Cannon). shell = "game": the game's shots and damage (six
	-- shells in a fan, 4 / Focus 5 each, times your weapon damage); only the
	-- charge time and the tap are changed:
	--   charge_ticks = a charge every this many ticks (60 a second; the game: 25)
	--   tap = the charges a quick tap fires (let go before the first charge;
	--     the game fires nothing then). 0 = the game's way.
	-- The 0.2.4 big shell is still there: shell = "one" (all the charges in one
	-- shell through every enemy, damage / focus_damage a charge, end_blast = an
	-- explosion at the end, perfect_ticks = a Critical Hit released on the
	-- flash, max_size = its size); shell = "fan": six shells, spread = the
	-- fan's angle times this, damage / focus_damage each.
	-- (big_blast = false: the game's Big Blast, charge time and tap too.)
	--   tap_damage = a tap shell's damage, times a Big Blast shell's (0.5 = 2 x
	--     your weapon damage, like a Mortar shell; 1 = full)
	--   tap_refund = false: a tap shell gives no ammo back when it hits (the
	--     game's Cannon reloads one shot for every skill shell that hits, so a
	--     tap that hit was free); true: it does
	big_blast = { charge_ticks = 16, spread = 1, damage = 4, focus_damage = 5, shell = "game", max_size = 1, end_blast = false, perfect_ticks = 0, tap = 1,
		tap_damage = 0.5, tap_refund = false },

	-- Throw Rock: the stone's damage a hit (a fixed number, the game: 9;
	-- Critical Hits scale from it).
	throw_rock = { damage = 18 },

	-- Greatsword Snap Attacks (Snap Tap, Snap Back): their damage times this
	-- (the game: Snap Tap 2.1, Snap Back 6.0 / 6.5 times your weapon damage).
	snap_attacks = { damage_mult = 2 },

	-- Sharpened Reflexes (Greatsword skill: uses up your meter for a bonus hit,
	-- an explosion, and a longer Perfect Guard window).
	--   any_attack_after_block = true: after your next block (any block), your
	--     next attack that lands sets off the explosion (the game: only a Snap
	--     Attack, which needs a full meter or a Perfect Guard; the skill empties
	--     the meter). false: the game's.
	--   guard_window_seconds = how long the longer Perfect Guard window lasts
	--     after the skill at most: it ends sooner once the explosion has gone
	--     off (0 = the game's: until your next Snap Attack ends).
	sharpened_reflexes = { any_attack_after_block = true, guard_window_seconds = 30 },

	-- Cannon Backfire (the skill during the plant / reload: uses up your ammo).
	--   damage / focus_damage = { 1-2 ammo, 3-4 ammo, 5-6 ammo } (times your
	--     weapon damage; the game: 0.5 / 3 / 4, Focus 0.75 / 4 / 5)
	--   reach = how much further the blast in front of you reaches (the game's
	--     blast: a box from 2 to 4 ahead; 1.75 = from 1 to 7 ahead, 2 = 1 to 8)
	--   radius = how much wider the box is (the game's: 5 across, 2.5 to each
	--     side; 1.2 = 6 across, 1.4 = 7)
	-- (The slide afterwards hits as the game's.)
	backfire = { damage = { 0.86, 3, 4.57 }, focus_damage = { 1.29, 4, 5.71 }, reach = 1.75, radius = 1.2 },

	-- Gourdo's Community Garden (the miniboss skill). Hold the button: each
	-- pulse heals you and the allies near you by heal and uses one stock; let go
	-- to stop. Stocks come back one per damage_per_stock damage you deal, up to
	-- max_stocks. full_heal: using all max_stocks stocks in one hold heals this
	-- much in all (the last pulse heals the rest: 30 + 30 + 40 = 100; 0 = off).
	-- (The game: heal 20, a stock per 1000 damage, 3 stocks.)
	-- dummy = true: hitting the training dummies in town earns stocks too (the
	-- game counts only enemies and breakable props, so in town a used stock
	-- never came back). false: the game's.
	community_garden = { heal = 30, damage_per_stock = 4000, max_stocks = 3, full_heal = 100, dummy = true },

	-- Thatcher's Voice of the Myriad (the bow skill): for seconds your hits coat
	-- enemies in Toxic. The game has no limit: its stock comes back 0.1 s after
	-- it wears off, and pressing it while it's on starts it again. Here its stock
	-- comes back from damage, like the Garden's: damage_per_stock damage dealt
	-- after it wears off (nothing counts while it's on), up to max_stocks, and no
	-- recast while it's on. Its icon shows the recharge ("45%"; blank = ready).
	-- dummy = true: training dummy hits count too. false: the game's.
	voice_of_the_myriad = { damage_per_stock = 2000, max_stocks = 1, seconds = 6, dummy = true },

	-- Shellwalker's Eggsabre (the Greatsword from Sedament's tundra): with it
	-- sheathed you run faster, in percent, for the weapon's level 1 / 2 / 3
	-- (its tooltip shows it). The game: 25 / 30 / 35. Two Weapons gives every
	-- weapon 30% sheathed, so this one is the runner: 60 / 70 / 80.
	eggsabre_run = { run_bonus = { 60, 70, 80 } },

	-- Stall log (changes nothing): when the game freezes for longer than
	-- seconds, one line in client_log.txt starting "[Skill Balance] the game
	-- stopped for" with what you did just before (states, skill hits, mini
	-- parries), to find what caused it. (The game's clock counts whole seconds,
	-- so the time lost is worked out from the frames each second.) false = off.
	stall_log = { seconds = 0.5 },

	-- Bulletproofing: an error inside Skill Balance's part of the game (the
	-- parry hold, Big Blast's tap and crits) is logged ("[Skill Balance] error
	-- in ...") and that part skipped, instead of the game's error screen
	-- ending the run. false: errors go to the game as before.
	guard = true,
}
