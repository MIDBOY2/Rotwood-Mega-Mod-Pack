Progression 0.4.3 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

One switch in scripts\progression_settings.lua, then restart the game:
  mode = "off"        the game as it is
  mode = "permanent"  everyday play (the default)
  mode = "liri"       in between permanent and nightly
  mode = "nightly"    game night

permanent
  Beating a main boss on Super Frenzy, each player who's there gets, straight
  into the inventory:
    - the boss's weapon for the 2 weapons you hold: the one in hand and the
      Two Weapons swap weapon (without Two Weapons just the one in hand),
    - the 3 Morphic armour pieces (Crown, Breastplate, Greaves), the first time,
    - 1 of the boss's Morphic gem, up to the game's cap of 3.
  So 3 Super Frenzy kills of a boss, with a different pair of weapons each
  time, give all 6 of its weapons and all 3 of its gems. Gear you already own
  is skipped (a kill with the same two weapons gives just the gem).
  The final boss on Super Frenzy gives the Morphic pieces if you don't have them.
  super_frenzy_heart_multiplier (1 to 20, default 1): picking up a Super
  Frenzy heart (Imbued Heartstone) gives that many.
  Boss weapons come at level 11, the same as crafted ones, so their upgrades
  work as normal: level 11 to 15, each level 1 Super Frenzy heart (Imbued
  Heartstone) + 10 of the hunt's ingots. Boss hearts drop as the game has
  them; the heart you'd have spent crafting the weapon goes to an upgrade.
  Blight Incursion legs don't count (the game doesn't charge Proto-Weapons
  there either). The Proto-Weapon still works like the game has it.
  Super Frenzy clears for both weapons: the game counts a cleared Super
  Frenzy level only for the weapon in your hand. With Two Weapons your swap
  weapon gets the clear too, so its next Super Frenzy level opens as well.
  Each weapon type goes one level up from its own record, like the game
  (if the swap weapon was behind, it catches up one level per clear). The log
  says "Super Frenzy clear for the swap weapon too: ...".
  super_frenzy_both_weapons = false: the hand weapon only.

liri
  Beating a main boss on Super Frenzy (any Super Frenzy level), each player
  who's there gets:
    - the boss's weapon for the 2 weapons you hold (like permanent),
    - the 3 Morphic armour pieces (the first time),
    - all 3 of the boss's Morphic gems at once.
  And, in every run:
    - Super Frenzy hearts (Imbued Heartstones) x2   (1 to 20)
    - corestones x3                                 (1 to 5)
    - Gift-Wrapped Souvenirs x2                     (1 to 5)
  plus one market armour piece gives the whole set.
  Super Frenzy clears count for both weapons you hold (like permanent).
  Each number / part is set under liri = { ... } in the settings.

nightly (game night)
  It changes your save (gear, unlocks), so back up the save folder first and
  put the backup back afterwards if you want your old progress:
    C:\Users\<you>\AppData\Roaming\Klei\Rotwood\steam-<your id>\saves\cloud\
  Map         LB / RB on the map picks the level of the hunt you're looking
              at: Normal, Frenzy 1-5, Super Frenzy 1-5 (main hunts). Only
              hunts you've unlocked. Blight Incursions stay as the game has
              them (they open after the final boss).
  Boss gear   Beating a boss at any level, each player gets:
                every boss / miniboss: its weapon for all 6 weapon types
                main bosses: the 3 Morphic pieces (once), their look (mirage),
                             all 3 of their Morphic gems
                the final boss: the 3 Morphic pieces
                minibosses: their armour set
              Anything you already own is skipped.
  Weapons     All 6 weapon types unlocked from the start, each with its
              basic weapon (given when your character loads).
  Double      Everything picked up counts double except Teffra (enemy drops,
              the reward drops after rooms and bosses, run pickups): materials,
              corestones, Gift-Wrapped Souvenirs, heart shards, Super Frenzy
              hearts, Glitz. Heartstones stay single (one unlocks the boss's
              talents, a second does nothing).
  Market      Buying one armour piece gives the whole set.
  Each part can be turned off under nightly = { ... } in the settings.

Log lines start with [Progression] in client_log.txt, e.g.
  [Progression] on: permanent (weapons, Morphic set, 1 gem per kill, Super Frenzy only)
If a game update renames something it hooks, that part switches itself off
and the log says what changed.

0.4.3: the heart cap counts the hearts already in that boss's weapons too
(user 03:50: "the 30 cap should calculate the hearts that were used on weapon
upgrades as well"): 1 for each of its weapons you have (made with a heart or
given) and 1 for each upgrade past level 11. Held + those <= 30 means you
never hold more of a boss's hearts than its weapons still need. Its weapons
unreadable: the held count alone (as 0.4.2).
0.4.2: the Super Frenzy heart multiplier gets a cap (user 2026-11-14 03:35:
an SF5 skip win gave 8 hearts, doubled to 16; "a setting that keeps boss
heartstones from x2, since they're per clearing ... and a second setting,
applied now, that allows the multiples but caps the amount to 30").
  super_frenzy_heart_multiplier = 1: single hearts, one per clear (the game's;
    corestones and gifts still multiplied in liri)
  super_frenzy_heart_cap = 30 (on now, liri x2): the multiplier's extra
    hearts stop once you hold 30 of that boss's Imbued Heartstones. 30 is all
    a boss's weapons use: each of its 6 weapons costs 1 to make (Progression
    gives the 2 you hold for free) and 4 to upgrade from level 11 to 15; the
    game gives one per Super Frenzy clear, 6 weapons x 5 levels = 30. The
    game's own hearts (one per clear) are never cut, only the extra.
    0 = no cap.
0.4.1: with Frenzy Levels' Super Frenzy level skip on (0.11.0, super_skip),
the second weapon's clears and hearts come from there; this leaves those
players alone (no second level up on top).
0.4.0: Super Frenzy clears count for both weapons you hold (permanent and
liri: super_frenzy_both_weapons).
0.3.1: the map panel's level hooks are guarded: an error is logged ("map panel
error") and the panel stays the game's, instead of the game's error screen.
