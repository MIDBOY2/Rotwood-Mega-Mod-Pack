-- Weapon Moves settings. true = on, false = the game's own way.
-- Changes take effect the next time the game starts a run (mods reload then).
return {
	enabled = true,

	-- Bow: X in the middle of a roll springs up and shoots from the top of the
	-- jump (the game's unused animation bow_roll_light_atk). Same charge levels
	-- as every bow shot (quick / medium / Focus / full charge, fires when you let
	-- go). Ground attacks pass under you while you're in the air. X at the roll's
	-- landing stays the kneel shot; X with the stick back stays the back-flip shot.
	bow_leap_shot = true,

	-- Hammer: B during the spin (the Lariat: roll, X with the stick pulled back,
	-- then Y; hold Y for more spins) plays the spin ending the game animated
	-- but never uses (UNUSED_hammer_big_atk1_pst). B doesn't cut the spin you're
	-- in: the finale starts when that spin comes round. One more spin, a big
	-- rising swing that knocks down (1.15x damage; a Focus hit when the spin was
	-- at full length), the hammer carries you up into the air (ground attacks
	-- pass under you), then you land with the hammer on your back. Dodge right
	-- after landing. In the game B does nothing while the spin is going.
	hammer_spin_finale = true,

	-- Hammer: after the finale's landing (the hammer is on your back):
	--   "back" = it stays there (the game's sheathed stance, as in camp; your
	--            next attack draws it, the way it does in camp)
	--   "hand" = you draw it (the game's quick unsheathe; any input cuts it short)
	--   "auto" = "back" in camp, "hand" on a run
	hammer_finale_landing = "back",

	-- Hammer: the finale's rising swing knocks what it hits down and back. How
	-- far: the game's knockdown distance for each enemy times this. 3.5 is the
	-- game's own knockback number for the spin's last round (its knockdowns never
	-- used it, so they all go 1x). 1 = the game's distance, 0 = none. 0 to 10.
	hammer_finale_knockback = 3.5,

	-- Hammer: Focus spins throw the cyan Focus sparks of the game's charged swings.
	-- A Focus spin (it hit more than one enemy, or it's at full length) gets the
	-- cyan spark glint the game made for this spin but never plays
	-- (fx_hammer_big_atk1_loop_front): every loop of it and the finale's extra
	-- spin; a Focus rising swing's trail gets the same cyan sparks. false = off.
	hammer_focus_fx = true,

	-- Hammer: while the finale's hammer carries you up and you spin in the air, the
	-- Windmon's wind spin whirls round you (the whirlwind of the Greatsword's flourish,
	-- and of Owlitzer's perfect dodge in Boss Passives), riding on you as you go up and
	-- come down; it ends as you land. false = off.
	hammer_air_spin_fx = true,

	-- Hammer: a short log of what the hammer does with your presses, to find out why
	-- a move doesn't come out. With the hammer in hand, each X / Y / B / dodge press
	-- writes a line to client_log.txt ("[Weapon Moves] hammer: Y in roll_pst frame 3,
	-- stick 168 deg from where you face (back) -> reverse_heavy_attack_sliding"): the
	-- move you were in, where the stick pointed (the golf swing and the fade-away
	-- swing that starts the spin need it pointing back, more than 100 degrees away
	-- from where you face) and the move the game went to. The first 150 presses
	-- of a session. false = off.
	hammer_input_log = false,

	-- Bulletproofing: an error inside these moves is logged ("[Weapon Moves]
	-- error in ...") and you go back to standing, instead of the game's error
	-- screen ending the run. false: errors go to the game as before.
	guard = true,
}
