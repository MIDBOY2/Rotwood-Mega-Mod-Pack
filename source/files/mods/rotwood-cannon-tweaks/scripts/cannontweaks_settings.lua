-- Cannon Tweaks settings. Restart the game after changing this file
-- (or try a number for one session in the console: c_cannon("single_shot.rounds", 4)).
-- Each power: enabled = false puts it back as the game has it. "game:" is the game's own number.
return {
	-- false = the mod is off (every cannon power as the game has it)
	enabled = true,

	-- Single Shot: shots fly faster, travel farther and hit harder, but the cannon holds only a few
	single_shot = {
		enabled = true,
		rounds = 3,              -- game: 1. Rounds in the cannon (1 to 30)
		damage_mult = 3,         -- game: 3. Weapon damage x3
		light_speed_mult = 3,    -- game: 3. Light shots fly 3x as fast
		heavy_speed_mult = 1.5,  -- game: 1.5. Heavy shots (blasts) 1.5x as fast
		range_mult = 2,          -- game: 2. Shots travel 2x as far
		blast_angle_mult = 0.5,  -- game: 0.5. The blast's spread (0.5 = half as wide)
	},

	-- Return to Sender: shots bounce back and can be caught to reload
	return_to_sender = {
		enabled = true,
		range_penalty = 20,      -- game: 60. -20% attack range (0 to 95; 0 = no penalty)
		reload_on_catch = 2,     -- game: 1. Rounds one catch reloads (1 to 30)
	},

	-- Bottomless Clip: rounds come back by themselves, but emptying the cannon overheats it
	bottomless_clip = {
		enabled = true,
		regen_per_sec = 3,       -- game: 1.66. Rounds back per second
		overheat_sec = 2.75,     -- game: 5. Seconds an overheat lasts (then the whole clip is back)
		overheat_sound_sec = 1,  -- game: 1. Seconds the overheat sound keeps going after the last shot
	},

	-- Spray 'n' Pray: more rounds, and holding light attack keeps firing
	spray_n_pray = {
		enabled = true,
		extra_rounds = 6,        -- game: 6. Extra rounds in the cannon
	},

	-- correct the power texts to the numbers ("2 Cannonballs", no "-0% Attack Range")
	fix_texts = true,

	-- the console command: c_cannon() every number now, c_cannon("bottomless_clip.regen_per_sec", 4)
	-- one number for this session, c_cannon("single_shot.rounds", "game") the game's number
	console_command = true,
}
