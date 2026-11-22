Skill Balance 0.2.16 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Buffs for skills that were weaker than they should be. Every number is in
scripts/skillbalance_settings.lua (restart the game after changing it); set a
section to false to leave that skill the game's way. Damage numbers are
multipliers: x your weapon damage (a hammer light hit is 1).

The ranged weapons' melee skills - made to hit and make room
  Battering Ram (Cannon)  0.5  -> 1.9   (1.5x the cannon shot)
  Thwack (Bow)            0.6  -> 1.3   (1.5x the bow's quick shot)
  Crosscheck (Spear)      0.45 -> 1.35  (1.5x the spear's 1st hit)
  All three knock enemies over (Battering Ram used to only push) with
  pushback 1.75 (was 1.5): small enemies land about 7 away, medium 5,
  large 3.5; light ones farther, heavy ones and bosses barely move.

Trickster's Gambit (parry)
  Window 0.43 s -> 0.67 s (the pose holds a moment longer when nothing hits).
  The enemy you parry takes a 1.0 hit and is knocked over (only if it's
  close: not a far-off shooter). 100% crit for 3 s (was 2).

Order in the Court (Hammer) - a risky charge, now worth it
  Tap 1.66 -> 1.7, half charge 2.5 -> 2.55, full charge 2.91 -> 3.0
  Focus 2.5 / 2.91 / 4.58 -> 2.55 / 3.0 / 4.75
  Radius 3 / 3.25 / 4 -> 3.25 / 3.5 / 4.5
  At full charge a touch over the fully charged heavy (2.91, Focus 4.58).
  (0.2.0: 2.0 / 3.0 / 4.0, Focus 3.0 / 3.75 / 6.0, radius 3.5 / 4 / 5;
  0.2.1: 1.8 / 2.7 / 3.3, Focus 2.7 / 3.25 / 5.0. Both too strong.)

Others
  Pole Vault (Spear): take-off 0.33 -> 0.5, landing 1.0 -> 2.0
  Dribble (Striker): 1.15 -> 1.75, Focus 1.75 -> 2.5
  Hazard Idol (Hammer): costs 10 health (was 25); it still heals 25 to
    whoever breaks it (its description keeps saying 25)
  Impulsive Stomp (Greatsword): 2.0 -> 2.5 (plus its meter bonus)
  Grody Groak Gulp: each tiny hit 0.1 -> 0.25

client_log.txt has one line: "[Skill Balance] on (17 changes: ...)". If a
game update moves something, that one skill is skipped and named in the log.

Mini parry - a perfect guard at the start of each weapon's quick skill
  Crosscheck (Spear), Thwack (Bow), Battering Ram (Cannon), Order in the
  Court (Hammer) and Dribble (Striker): a hit in their first 5 frames is
  treated like the Greatsword's perfect guard. You take 2% of it, don't
  flinch (the skill goes on, and its own hit is your counter), and get the
  perfect guard's spark, shudder and protections (your hit streak stays, the
  enemy's on-hit effects like frost don't land). Owlitzer's Morphic gem fires
  like on a perfect guard. Not Parry's crit buff (a perfect guard doesn't give
  it either) and nothing that belongs to the Greatsword (its mastery, gear
  and powers). The real Parry stays far stronger (longer window, no damage,
  knockdown counter, crits). Window, damage and each skill: mini_parry in the
  settings.

Big Blast (Cannon) - quicker charge, the game's shots
  A charge every 16 ticks (was 25: 6 charges in 1.6 s instead of 2.5 s). The
  shots are the game's (shell = "game"): one shell a charge, up to 6, fanned
  out from where you aim (at 6 charges: 50, 30 and 10 degrees to each side),
  4 times your weapon damage each (Focus 5), stopped by the first enemy
  unless you have a pierce power. A quick tap fires one shell (tap = 1; the
  game fires nothing for a tap; tap = 0 goes back to that) at half damage
  (tap_damage = 0.5) and gives no ammo back when it hits (tap_refund = false;
  the charged shots still give 1 back a hit, as the game does). shell = "fan":
  the six shells with your own damage and fan width (spread). shell = "one":
  the old single big shell through every enemy (0.2.4 - 0.2.7, too strong).
  big_blast = false: the game's own Big Blast, charge and tap too.

Gourdo's Community Garden - a stock per 4000 damage
  Hold the button: each pulse uses a stock and heals 30 (you and allies in
  range; the game: 20). Three stocks in one hold heal 100 (30 + 30 + 40). A
  stock comes back per 4000 damage dealt to enemies, breakable props and the
  training dummies in town (the game: 1000, no dummies), up to 3.
  community_garden in the settings.

Voice of the Myriad (Thatcher's bow skill) - no more spamming it
  For 6 s your hits coat enemies in Toxic (the game's). The game gave the
  stock back 0.1 s after it wore off, and a press while it was on started it
  again, so it could be kept on forever. Now its one stock comes back from
  2000 damage dealt after it has worn off (nothing counts while it's on;
  enemies, breakable props, the training dummies), and a press while it's on
  does nothing. Its icon shows the recharge ("45%"; blank = ready).
  voice_of_the_myriad in the settings.

Shellwalker's Eggsabre (Greatsword) - the runner
  With it sheathed you run +60 / 70 / 80% faster by the weapon's level (the
  game: 25 / 30 / 35). Two Weapons gives every weapon 30% sheathed, so this
  is twice that or more. eggsabre_run in the settings.

Stall log - finds freezes (changes nothing)
  When the game stops for more than half a second (not the pause menu, not a
  room loading), client_log.txt gets one line starting
  "[Skill Balance] the game stopped for" with what you did in the 3 seconds
  before: the states you went through, the changed skills' hits and mini
  parries. stall_log in the settings (false = off).

0.2.1: Order in the Court toned down (it was too strong); the stall log added
  after a 2-second freeze with Crosscheck.
0.2.2: Order in the Court a little lower again; the stall log works from the
  frames each second (the game's clock only counts whole seconds, which made
  0.2.1 log a "stop" every second).
0.2.3: Big Blast (Cannon) buffed: quicker charge, tighter fan, a bit more damage.
0.2.4: Big Blast: one big shell (shell = "fan" for the six shells).
0.2.5: Big Blast's shell back to the game's size (max_size = 1).
0.2.6: a quick Big Blast tap fires one charge (tap = 1).

0.2.7: bulletproofing: the parry hold and Big Blast's tap and crits are guarded:
an error is logged ("[Skill Balance] error in ...") and skipped, instead of the
game's error screen ending the run. guard = false: the game's way.
0.2.8: Big Blast back to the game's shots and damage (the big shell through
every enemy, its end blast and the Critical Hit on the flash made it far too
strong; still there as shell = "one"). The faster charge and the one-charge
tap stay. Throw Rock does 18 a hit (the game: 9). Greatsword Snap Attacks do
twice the damage. Sharpened Reflexes: after your next block, your next attack
sets off its explosion (the game: only a Snap Attack, which needs the full
meter the skill just used up), and its longer Perfect Guard window lasts 30 s.
Cannon Backfire (skill during the plant / reload): the blast reaches from 1 to
8 ahead (the game: 2 to 4) and 8 across (5), and hits for 3 / 9 / 16 times
your weapon damage by the ammo it uses (the game: 0.5 / 3 / 4).
0.2.9: Cannon Backfire toned down: 0.86 / 3 / 4.57 times your weapon damage
for 1-2 / 3-4 / 5-6 ammo (Focus 1.29 / 4 / 5.71; the game: 0.5 / 3 / 4, Focus
0.75 / 4 / 5): 3.5 times weaker than 0.2.8, but never below the game's. Its
blast (a box straight ahead, no fan) a bit smaller: from 1 to 7 ahead (the
game: 2 to 4), 7 across (the game: 5; 0.2.8: 8).
Big Blast stays: the game's shots and damage, the quicker charge, a tap fires one.

0.2.10: the Backfire's blast a bit narrower: 6 across (0.2.9: 7; the game: 5),
still from 1 to 7 ahead.

0.2.11: Sharpened Reflexes' bonuses end once its explosion has gone off: the
longer Perfect Guard window ends with the blast (it used to stay for the full
30 s); the 30 s are only the most it lasts without an explosion.

0.2.14: Shellwalker's Eggsabre runs +60 / 70 / 80% sheathed (was 25 / 30 / 35).
0.2.13: Gourdo's Community Garden: heals 50 a pulse (was 20), a stock back per
3000 damage dealt (was 1000), 3 stocks; hitting the training dummies in town
earns stocks too (the game counts only enemies and breakable props, so a stock
used in town never came back). Settings: community_garden.
0.2.12: a Big Blast tap does half damage (tap_damage = 0.5) and gives no ammo
back (tap_refund = false). The game reloads 1 ammo each time a skill shell hits
(not over your max, not for shells that pierce); charged Big Blasts still do.
0.2.15: the mini parry (the 5-frame guard at the start of Crosscheck, Thwack,
Battering Ram, Order in the Court and Dribble) never switched on in the game, and a
landed parry was never noted (so its pose could be held after it). The game gives
each kind of entity its own copy of the moves (entityscript.lua LoadStateGraph), and
0.2.14 checked the player's state against the original, never the copy. It now
checks by name. Tests run on the game's copy too.
0.2.16: Gourdo's Community Garden heals 30 a pulse, a stock per 4000 damage, 3
stocks, and 3 stocks in one hold heal 100 (the last pulse 40). Voice of the
Myriad: its stock comes back from 2000 damage dealt after it wears off (the game
gave it back right away, and a press while it was on restarted it: no limit), 1
stock, no recast while it's on, the icon shows the recharge.
