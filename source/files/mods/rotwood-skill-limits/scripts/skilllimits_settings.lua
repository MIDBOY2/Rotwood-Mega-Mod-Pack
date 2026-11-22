-- Skill Limits settings. Restart the game after changing this file.
return {
	enabled = true,

	-- A limited skill has this many uses. Every use restarts the rest timer;
	-- when it runs out (refill_seconds after the last use) all uses come back.
	charges = 5,
	refill_seconds = 5,

	-- The limited skills. true = the numbers above, or give one its own:
	--   miniboss_groak = { charges = 3, refill_seconds = 8 },
	-- count = "hit": only uses that hit something count (misses are free, the
	-- rest timer starts at the hit). Works for Javelin Backstab.
	-- false or leaving it out = unlimited. Skills that have a limit of their
	-- own (Hypershot, Fan of Gnarlics, Holder of Shinies (6 s cooldown),
	-- Bastion Volley (10 shots that come back), Gourdo's Community Garden,
	-- Crystroll's Ice Puke, Banana Peel) are never touched.
	skills = {
		-- boss skills
		boss_megatreemon = true,       -- Mother of Methuselah
		boss_owlitzer = true,          -- Keeper of the Moon
		boss_thatcher = true,          -- Voice of the Myriad (the game's limit: 0.1 s)
		boss_eggzy = true,             -- Eggsplosion (the game's cooldown never starts)
		-- miniboss skills
		miniboss_yammo = true,         -- Big Yammo Slammo
		miniboss_floracrane = true,    -- Floracrane's Divebeak
		miniboss_groak = true,         -- Grody Groak Gulp
		miniboss_embison = true,       -- Embison's Turn Around Punch
		miniboss_bonejaw = true,       -- Bonejaw's Charge
		-- charge-ups (one charge = one charge-up)
		hammer_explodingheavy = true,  -- Unstable Equilibrium
		-- (the bow's arrow skills use ammo instead: bow_arrow_ammo below)
		-- weapon skills
		polearm_javelin = { charges = 2, count = "hit" }, -- Javelin Backstab: misses are free, 2 hits

		-- Unlimited (add any of these above to limit them too):
		-- throwstone (Throw Stone), hammer_totem (Hazard Idol), throwsnowball,
		-- buffnextattack (Fist Pound), parry (Trickster's Gambit),
		-- hammer_thump (Order in the Court), polearm_shove (Crosscheck),
		-- polearm_vault, polearm_extend (As-You-Will),
		-- shotput_recall, shotput_summon, shotput_slam (Dribble), shotput_lob,
		-- shotput_seek, cannon_butt (Battering Ram), cannon_singlereload,
		-- cannon_aim (Big Blast), cannon_proximitymine, bow_melee (Thwack),
		-- cleaver_blade_burst (Sabre Rattle), cleaver_bash_prime (Impulsive
		-- Stomp), cleaver_snapattack_boost (Sharpened Reflexes),
		-- cleaver_swagger_slash (Mighty Chop), cleaver_sheathe_weapon (Critical
		-- Draw), cleaver_block_trap (Sword Plant), cleaver_berserkmode_activate
	},

	-- The bow's arrow skills (Toxic Dip, Cold Plunge, exploding arrow) use
	-- ammo, like the game's Banana Peel and Gourdo's Community Garden: each
	-- special arrow fired takes one, dealing damage (enemies, breakable props,
	-- the training dummies in town) earns them back. The skill icon shows the
	-- arrows left.
	-- (2 arrows / 1500: the special arrows stay full strength but rare)
	bow_arrow_ammo = 2,                 -- arrows in the quiver (0 = no ammo, unlimited)
	bow_arrow_damage_per_arrow = 1500,  -- damage dealt to earn one back (the game's bananas / garden use 1000)
	-- true  = one quiver for all your arrow skills (2 arrows in all, whichever skill fires them)
	-- false = each arrow skill has its own 2
	bow_arrow_shared = true,
	-- Out of arrows: one free dip (the button does the arrow dip, only the dip,
	-- and that makes one arrow), then this many seconds until the next free dip.
	-- Meanwhile the button does nothing (an X over your head) and the icons go
	-- grey with the seconds left. 0 = a free dip every time, -1 = no free dip.
	bow_arrow_free_dip_cooldown = 15,

	-- true  = the arrow skill's button goes straight into a heavy shot. Hold
	--         it and release when the bow is charged for a Focus shot: that
	--         shot carries the special arrow (1 ammo). Any other release = a
	--         normal heavy shot, free.
	-- false = the game's way: dip the arrow, your next heavy shot carries it
	--         (1 ammo when it's fired). Out of arrows: the free dip above.
	instant_bow_skills = true,

	-- the skill icon: false = a number only while out of uses (seconds until
	-- they're back, like the game's cooldown skills); true = also the uses left
	show_charges_left = false,

	-- the game's "no charge" sound when pressing a skill with no uses left,
	-- and its "charge back" sound when they come back
	blocked_sound = true,
	refill_sound = true,

	-- extra lines in client_log.txt
	debug = false,
}
