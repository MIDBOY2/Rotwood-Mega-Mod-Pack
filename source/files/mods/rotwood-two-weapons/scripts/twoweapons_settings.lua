-- Two Weapons settings. Edit, save, restart the game.
--
-- Your two weapons: the one in hand and the other one. Equipping a weapon the
-- normal way (armory, shop mannequin, town rack, debug menu) changes the one in
-- hand; the other stays. With only one weapon so far, the first new one you
-- equip becomes your second. The swap button flips between the two. Saved per
-- character.
--
-- The swap works wherever a dodge would: standing, running, and the moments an
-- attack can be dodge-cancelled. A press slightly early is kept for a moment.

return {
	enabled = true,

	-- The game's mannequin loadouts remember your other weapon: saving a
	-- loadout keeps the pair, equipping it gives you that pair back (the
	-- loadout's weapon in hand, the saved one as your other). Like the
	-- loadout's gear, a change counts only once you save the loadout again.
	-- false = loadouts only change the weapon in hand (the game's way).
	mannequin_loadouts = true,

	-- gamepad button: "LS" = left stick click
	gamepad = "LS",
	-- keyboard key (keyboard player). M is used by none of the game's controls
	-- or debug keys (with cheats / the console on, R reruns your last console
	-- command, T teleports you to the mouse, Shift+X opens a debug panel; the
	-- log warns if the key you set is one of them).
	keyboard = "M",

	-- the dodge-cancel puff that hides the swap
	puff = true,
	-- puff position: -1 is the game's own (a bit forward, made for dodges), 0 = centered
	puff_offset = -1,

	-- how long an early press waits for a dodge window, in animation frames (30 per second)
	buffer_frames = 6,

	-- weapon memory: each weapon keeps what it had going while you hold the
	-- other one (Greatsword meter, Cannon ammo, skill stocks and cooldowns,
	-- weapon / gem power counters). Lasts for the run. false = vanilla resets.
	remember = true,

	-- Both weapons' gems: the game only counts the gems of the weapon in your
	-- hand, so max health, healing, protection, luck... went up and down with
	-- every swap. The gem types set true here count from BOTH weapons,
	-- whichever one you hold (the same gem on both adds up, like two on one
	-- weapon). Damage gems are about how their weapon hits, so they stay with
	-- it to start. false = the game's way (only the weapon in hand).
	both_weapons_gems = { sustain = true, support = true, damage = false },

	-- A weapon power for each weapon: the weapon power room (the choice of two
	-- Legendary powers that change one of a weapon's moves) only offers powers
	-- for the weapon in your hand. Take one, and a second choice flies out of
	-- the same crystal for your other weapon (rolled the game's way, the same
	-- number of powers); take one of those too. It works when you swap to that
	-- weapon. Both choices are set when the crystal breaks (the first for the
	-- weapon in your hand then, the second for the other one): swapping during
	-- the room changes neither.
	-- true = in every weapon power room, "first_room" = only when it's the
	-- run's first room, false = the game's way (one choice).
	both_weapon_powers = true,
	-- Two weapons of the same type (two Hammers): one choice, since a Hammer
	-- power works with either. true = a second Hammer choice too (not the
	-- power you took, nor the one you passed on).
	both_weapon_powers_same_type = false,
	-- How many weapon powers you keep. The game keeps 4 (made for one weapon)
	-- and a new one past that takes the place of your oldest. "double" = twice
	-- the game's (8: 4 for each weapon), a number, false = the game's.
	weapon_power_limit = "double",
	-- A weapon has only so many weapon powers (Cannon, Hammer, Bow, Spear: 4).
	-- When a choice has fewer left than your usual number (the Cannon gets 2
	-- weapon powers at most: its three ammo powers exclude each other), the
	-- rest is filled with other powers; a weapon with nothing left gets a
	-- whole choice of them as its turn, and your other weapon keeps its own
	-- weapon power choice. "weapon" = your other weapon's weapon powers first
	-- (as 1.0.7); "normal" = normal powers only (as 1.0.2); false = the choice
	-- as it is (possibly empty).
	weapon_power_fill = true,
	-- Of those other powers, the percent that are Fabled (the rest normal).
	weapon_power_fill_fabled = 50,
	-- Power pedestals never on top of each other: with two players and 3-4
	-- powers each (Choosey gems, a filled choice) the game's circles meet in
	-- the middle of the room; here they move out from the crystal until no two
	-- pedestals are closer than 3.5 (tighter circles if the room runs out),
	-- staying on walkable ground. false = the game's spots.
	power_spacing = true,
	-- Your other weapon's choice flies out with the crystal's split sound, the
	-- one the first choice has (the crystal is gone by then, so it was silent),
	-- played from you. false = no sound.
	split_sound = true,
	-- The market's weapon stands: each hunter's weapon in hand first, this
	-- hunt's weapon of that type when that hunter doesn't own it yet (player 1
	-- the first stand, player 2 the second); then the game's own order: pieces
	-- nobody has, then pieces one of you has, then pieces you all have (only
	-- when there's nothing else for that stand). false = the game's.
	market_weapons = true,
	-- The swap button (left stick click / M) works in the gem screen (Modify
	-- Weapon Gems, its weapon tab): your weapons swap and the panel shows the
	-- other one's gem slots. false = close the screen to swap, as the game.
	gem_screen_swap = true,
	-- The Greatsword's Berserk carries over when your other weapon is a
	-- Greatsword: its timer runs, your attacks with either weapon add time, its
	-- speed, armour and uninterruptible attacks stay, you stay red; its Berserk
	-- weapon powers work with it as your other weapon too. It ends with its
	-- timer, or when neither weapon is a Greatsword. false = a swap ends it.
	berserk_carry = true,
	-- The Teffressence Container gem (kill an Imbued Boss Rot at the end of a
	-- Super Frenzy hunt: the gem is used up and its weapon can be upgraded past
	-- level 10). The game does it only for the weapon in your hand; here your
	-- second weapon's gem works on the same kill too (the game's own imbue, on
	-- that weapon, with its "Imbued!" note). false = the hand weapon only.
	second_weapon_imbue = true,
	-- The rooms themselves (a weapon power choice at every run's start, more
	-- weapon power and Fabled rooms, longer hunts) are the Hunt Rooms mod's
	-- (its settings: huntrooms_settings.lua). Without it, the game's rooms.

	-- charged skills follow you: a skill charged up and waiting for its trigger
	-- keeps its charge after a swap, and the other weapon sets it off
	-- (Unstable Equilibrium: the other weapon's next Heavy Attack that hits;
	-- Eggsplosion: the next hit; Voice of the Myriad: poison while it lasts).
	-- Spent there, it's gone; swap back first and it's still charged.
	-- false = it stays with its weapon (comes back charged when you swap back).
	carry_charges = true,

	-- RB (keyboard F) with nothing to interact with sheathes your weapon during
	-- runs too, like in town. Attacking draws it again. Uses the game's own
	-- option for this (a Greatsword gear piece normally turns it on).
	rb_sheathe = true,
	-- with your weapon sheathed you run faster, in percent (the Greatsword
	-- gear piece that gives RB sheathe, Shellwalker's Eggsabre, gives 30).
	-- Not in town (the game already gives +50% there) and not while wearing
	-- that gear piece (its own bonus counts instead). 0 = off.
	sheathed_run_bonus = 30,

	-- swap attacks: the swap comes out attacking with the new weapon
	--   swap during a dodge (or with A)   -> Mixed set
	--   swap with Y (held or tapped)      -> Heavy set
	--   swap with X (held or tapped)      -> Aerial set
	--   swap with B (held or tapped)      -> Skill set
	--   swap standing still               -> plain swap
	-- Each player can turn them on / off in Skill Slots' menu (saved per
	-- character); this is the starting value.
	swap_attacks = true,
	-- B's swap attack: "custom" = each weapon's own move (Order in the Court,
	-- vault strike...), "skill" = whatever B fires with the new weapon (its skill)
	b_moves = "custom",
	-- other moves to pick for some buttons:
	-- Spear B: "vault" (vault strike) or "crosscheck" (the push-away skill)
	spear_b = "crosscheck",
	-- Greatsword B: "snapback" (snapback counter) or "overhead" (overhead heavy slam)
	greatsword_b = "snapback",
	-- Which way swap attacks face: X / Y / B face where the stick points. A
	-- (the dodge) comes out of the dodge going its way, unless the stick points
	-- back the other way: then it turns to the stick first, like the game's own
	-- moves (dodge one way, push the stick the other way, attack). false: A
	-- always keeps the dodge's way (before 0.7.13).
	swap_turn_with_stick = true,
	-- A (the dodge) comes out of the dodge going its way. The other moves are
	-- still here to pick:
	-- Hammer A: "fade_swing" (the fade-away swing facing the dodge's way, its
	-- hop carrying you on along it), "fade_swing_turned" (turned around: hops
	-- the dodge's way, swinging behind you, 0.7.2-0.7.5), "fade_swing_back" (it
	-- hops back against the dodge, as before 0.7.0) or "jump_slam" (the jump
	-- slam forward, 0.7.0-0.7.1)
	hammer_a = "fade_swing",
	-- how far the fade-away swing hops: 1 = the game's own hop (about 1.15 units), 2 = about
	-- 2.1 units (0.8.2), up to 4
	hammer_fade_distance = 2,
	-- Bow A: "leap_shot" (Weapon Moves' leap shot forward; without Weapon Moves
	-- the game's forward jump shot) or "backflip" (the old backflip shot)
	bow_a = "leap_shot",
	-- Greatsword A: "bash" (the Gut Bash, its lunge, the dodge's way),
	-- "dodge_heavy" (the game's forward roll into its heavy swing) or
	-- "quick_heavy" (the old 5-frame quick swing)
	greatsword_a = "bash",
	-- Cannon A: "roll_blast" (the Cannon roll the dodge's way, then the Blast
	-- ahead, still facing the dodge's way, its kick launching you on along
	-- it), "roll_blast_turned" (turned around: the Blast fired back the way you
	-- came, 0.7.2-0.7.5), "roll_blast_back" (the Blast ahead, launching you back
	-- against the dodge), "roll_shot" (the roll, then the normal shot ahead),
	-- "mortar" (mortar lob) or "shockwave" (shockwave slam). The roll ones need
	-- Skill Slots (its Cannon roll); without it they do the mortar lob.
	cannon_a = "roll_blast",
	-- Pressing them together works in any order, within these windows (animation frames, 30 per second):
	-- A / X / Y this soon after a plain swap still makes it a swap attack
	followup_frames = 10,
	-- X / Y / A pressed this soon before the swap counts as held
	combo_frames = 10,
	-- (a swap attack can cut into any dodge, attack or skill: chain weapons mid-combo)

	-- Swap attacks in a row. Swapping mid-attack into a swap attack is
	-- instant, and so is swapping mid-way through that one (2 in a row:
	-- hammer heavy -> spear heavy -> hammer heavy). A swap during the last one
	-- allowed in a row waits until that attack has finished (you're out of
	-- attacks, or the game starts your next move: the next hit of a combo, a
	-- dodge, a skill), and at least swap_chain_wait seconds after it started.
	-- Then swaps are instant again.
	--   swap_chain_limit = swap attacks in a row before the wait (0 = no limit)
	--   swap_chain_wait  = the least wait, in seconds
	--   swap_chain_hold  = false: a press during the wait is ignored (press
	--                      again after); true: it's kept and swaps as soon as
	--                      the wait is over
	swap_chain_limit = 2,
	swap_chain_wait = 0.5,
	swap_chain_hold = false,

	-- The same strong swap move again and again (spear multi-thrust <-> bow,
	-- ...). Each strong swap move counts by itself (per weapon and move): the
	-- first swap_repeat_full times in a row do full damage, from the next one
	-- on its own hits do swap_repeat_factor of their damage (arrows / shells it
	-- fires too). swap_repeat_window seconds without any swap attack: full
	-- again. Strong = the game's heavy attacks and skills (the multi-thrust is
	-- a heavy); light swap moves (Cannon quick shot, the bow's light shots,
	-- the dodge moves) are never reduced, and neither are normal attacks or
	-- the combos you carry on afterwards.
	--   swap_repeat_full   = times at full damage (2: the 3rd is reduced)
	--   swap_repeat_factor = the reduced damage (0.59 = 59%: about what that
	--                        weapon's light attacks deal in the same time; 1 = off)
	--   swap_repeat_window = seconds without a swap attack before it's full again
	--   swap_repeat_also   = more moves to count as strong, by state name, e.g.
	--                        { "rolling_drill_attack_pre", "cannon_plant_pre" }
	--   swap_repeat_skip   = strong moves left alone (never reduced). Here:
	--                        hammer Y spinning flip slam and its A jump slam,
	--                        spear jump thrust, vault strike and crosscheck,
	--                        Cannon whack, bow jump shot and melee bash
	--   swap_damage_log    = true: every minute, client_log.txt gets each
	--                        weapon's light attacks' and swap moves' damage per
	--                        second ("[Two Weapons] damage rates"), to set the
	--                        factor from; false: off
	swap_repeat_full = 2,
	swap_repeat_factor = 0.59,
	swap_repeat_window = 2.5,
	swap_repeat_also = {},
	swap_repeat_skip = { "heavy_attack_jump_pre", "heavy_attack_jump", -- hammer Y flip slam, A jump slam
		"heavy_attack", "polearm_jump_out", "skill_polearm_shove", -- spear jump thrust, vault strike, crosscheck
		"skill_cannon_butt", -- Cannon whack
		"heavy_attack_hold", "skill_bow_melee" }, -- bow jump shot, melee bash
	swap_damage_log = false,

	-- true = write what each swap press does to client_log.txt ("[Two Weapons] debug:")
	debug = false,

	-- Smooth swap: the HUD's redraws (your player panel) wait one tick and
	-- happen once, and the max health announcements are skipped when the number
	-- didn't change (the game sent them every swap: about 14 of a swap's 21 ms).
	-- The weapon still changes at once. false = the game's way.
	smooth_swap = true,

	-- Swap timing (changes nothing): for the first 40 swaps, one line each in
	-- client_log.txt with how long the swap took and where the time went.
	swap_timing = false,

	-- A new character starts with two random basic weapons instead of the game's
	-- Hammer (and the Spear in the bag): the first in hand, the second your other
	-- weapon, picked from this list ("in hand + other"; hammer, spear, greatsword,
	-- striker, cannon, bow). Only a character you just made; existing ones keep
	-- theirs. false = the game's starting weapons.
	starting_pair = true,
	starting_pairs = {
		"spear + striker", "spear + cannon", "spear + bow",
		"hammer + striker", "hammer + cannon", "hammer + bow",
		"greatsword + striker", "greatsword + cannon", "greatsword + bow",
		"striker + hammer", "striker + spear", "striker + greatsword", "striker + bow",
		"cannon + hammer", "cannon + spear", "cannon + striker", "cannon + greatsword",
		"bow + hammer", "bow + spear", "bow + greatsword", "bow + striker",
	},
	-- ...and those two weapons' racks in camp are unlocked for that character (as
	-- if you'd paid their Corestones). false = the racks stay as the game has them.
	starting_pair_unlocks_racks = true,

	-- Bulletproofing: an error inside Two Weapons' part of the game (a press,
	-- a loadout, a new run) is logged ("[Two Weapons] error in ...") and that
	-- part skipped, instead of the game's error screen ending the run.
	-- false: errors go to the game as before.
	guard = true,
}
