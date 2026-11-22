Two Weapons 1.0.14 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Left stick click (keyboard M): swap to your other weapon, behind the
dodge-cancel puff.

Your two weapons: the one in hand and the other one. Equip a weapon any way
the game allows (armory, shop mannequin, town rack, debug menu) and it
replaces the one in hand; your other weapon stays. With only one weapon so
far, the first new one you equip becomes your second. Saved per character.
Each player has their own pair.

Mannequin loadouts remember your other weapon. The game's loadout already
saves the weapon in hand (with your armor, potion, tonic, talents and gems);
saving a loadout (mannequin Claim & Save, the loadout screen) now also saves
your other weapon, and equipping it gives you that exact pair. Like the gear,
a change counts only once you save the loadout again. A loadout saved before
this, or with no second weapon, keeps the other weapon you have; so does one
whose saved weapon you've salvaged. The Hunter's Path screen's own
talents-only save keeps the loadout's other weapon. mannequin_loadouts =
false in the settings turns this off.

Works wherever a dodge would: standing, running, and when an attack can be
dodge-cancelled.

Swap attacks: the swap can come out attacking with the new weapon.
  LS with A (or mid-dodge) -> Mixed set
  LS with Y                -> Heavy set
  LS with X                -> Aerial set
  LS with B                -> Skill set
  LS standing still        -> plain swap
"With" = held, or pressed together in either order (within a third of a
second): LS then A / X / Y / B works too.
Skill Slots' slot buttons (LT / RT / RS) held during a swap don't count as B.
With Skill Slots' Block on the Greatsword's B, B (held or pressed) still counts
as B; b_moves = "skill" then does the Snapback counter (Block isn't a skill).
A swap attack can cut into any dodge, attack or skill: chain weapons
mid-combo. Each move is the game's own (its hits, damage and cancels).

Each weapon, by button (hold = keep the button held to charge; tapped, it's
the quick version):
  Hammer
    A  Forward jump slam: out of the dodge, its way (hammer_a = "fade_swing":
       the old fade-away swing)
    X  Golf swing: turns and swings through; hold X to charge it like
       holding Y would (3 strengths, the full one a focus hit)
    Y  Spinning flip slam
    B  Order in the Court: quick wind-up, then the focus slam
  Spear
    A  Rolling drill
    X  Rapid multi-thrust
    Y  Jump thrust (no wind-up)
    B  Crosscheck: the Spear's push-away skill. spear_b = "vault" in the
       settings: the Vault Strike instead (leaps up and dives down onto the
       closest enemy ahead of you, else a few steps ahead; dodge before
       take-off to cancel it)
  Bow
    A  Leap shot: out of the dodge, a forward leap shooting from the top
       (Weapon Moves; without it the game's forward jump shot); hold A to
       charge (bow_a = "backflip": the old backflip shot)
    X  Kneeling slide shot: slides forward into a kneel and shoots; hold X
       to charge the shot
    Y  Jump shot (no wind-up, charges while Y is held)
    B  Melee bash
  Greatsword
    A  Out of the dodge into the heavy swing (the game's forward roll attack;
       greatsword_a = "quick_heavy": the old quick swing)
    X  Skill slash, end half (no meter spent)
    Y  Horizontal sweep (keep Y held: it spins on)
    B  Snapback counter: the counter swing from a block, knocks back; a
       focus hit when you have meter. greatsword_b = "overhead": the
       overhead heavy slam instead
  Striker
    A  Shoulder tackle
    X  Focus throw (the shoulder tackle with no ball in hand)
    Y  Ball slam
    B  Flip kick: hops back, kicking the way you were going
  Cannon
    A  Roll + shot: rolls the dodge's way (Skill Slots' Cannon roll,
       invincible like the other weapons' rolls), then the normal shot ahead.
       cannon_a = "roll_blast": the roll, then Blast out of it (launches you
       back; the game's Blast follow-ups work after it). "mortar": the mortar
       lob (plants, fires your ammo); "shockwave": the shockwave slam (plants,
       blasts around you). Without Skill Slots: the mortar lob.
    X  Quick shot
    Y  Air shot
    B  Cannon whack

b_moves = "skill" in the settings makes LS with B fire the new weapon's B skill
instead (with Skill Slots: B's pick in that weapon's loadout, ready right
away; holding B keeps charging skills that charge).

Each player turns swap attacks on / off in Skill Slots' menu (View button /
keyboard Tab), saved per character. swap_attacks = false in the settings makes
off the starting value.

Both weapons' gems: the game only counts the gems of the weapon in your hand,
so max health, healing, protection and luck went up and down with every swap.
Now Sustain gems (Max Health, Healing, Alchemist's, Regen, Concentrated,
Pick-Me-Up, the protections) and Support gems (Luck, speed, loot, Teffra,
rerolls, weight...) count from both weapons, whichever you hold; the same gem
on both adds up. Damage gems stay with their weapon, and so does the
Teffressence Container (it imbues the weapon it sits in). A swap doesn't take the
kept gems away and give them back, so Regen doesn't start over and counters
keep going. Setting: both_weapons_gems. (Gem XP still goes to the weapon in
hand's gems, the game's way.)

Weapon memory: each weapon keeps what it had going while you hold the other
one, and gets it back when you swap back:
  - Greatsword meter, Cannon ammo used
  - skill stocks and cooldowns (a cooldown that ended while the weapon was
    away is ready when it comes back), weapon / gem power counters
  - Skill Slots' per-weapon skills
It lasts for the run (kept between rooms) and starts fresh with a new run.
Turn it off with remember = false in the settings.

Charged skills follow you: a skill you charged up that waits for its trigger
keeps its charge when you swap, glow and all, and the other weapon sets it off:
  - Unstable Equilibrium: the other weapon's next Heavy Attack that hits
    explodes (sheathing still cancels it)
  - Eggsplosion: the next hit makes the egg explosion
  - Voice of the Myriad: your attacks poison while it lasts
Spent on the other weapon, it's gone (its weapon comes back without it). Swap
back before using it and it's still charged on its own weapon.
Charges that only work with their own weapon (the Bow's Toxic Dip and Cold
Plunge arrows, the Greatsword's Mighty Chop and Critical Draw) stay with it and are ready again,
glowing, when you swap back. carry_charges = false keeps every charge with its
own weapon.
Also fixed: a skill's weapon glow could get stuck forever after a swap (the
game lost track of it); glows now always turn off when they should.

RB (keyboard F) with nothing to interact with sheathes your weapon during runs
too, like in town; attacking draws it again. rb_sheathe = false turns it off.
While it's sheathed you run 30% faster, like with the Greatsword gear piece
that gives RB sheathe (Shellwalker's Eggsabre). Not in town, where the game
already gives +50%, and not while wearing that gear piece (its own bonus
counts instead). sheathed_run_bonus in the settings sets the percent (0 = off).

debug = true in the settings writes what each swap press does to
client_log.txt (lines start with "[Two Weapons] debug:").

Settings: scripts\twoweapons_settings.lua (save, restart the game).
Log lines start with [Two Weapons] in client_log.txt.
0.6.1: the Cannon keeps its ammo through a swap (swapping away and back was a
free reload: the Cannon refills itself when the loadout changes, right after
the memory put the ammo back). The log says "Cannon ammo kept through the swap".
0.6.2: swap timing in the log (swap_timing).
0.6.3: smooth swap: the HUD's redraws wait a tick and happen once, and the
game's "max health changed" announcements are skipped when it didn't change
(measured: 14 of a swap's 21 ms; smooth_swap = false: the game's way).
0.6.4: smoother still: the leftover HUD work is spread one piece a frame
(power icons, panel, layout, portrait) instead of all in the next frame; the
power icons lay out once per swap, not after every power out / in; the panel's
refresh skips re-adding every power icon; the health announcement is skipped
when nothing changed. The swap timing line names the functions behind the
time, the weapons (BOW -> CANNON), the tasks run afterwards and the next
frames' lengths.
0.6.5: fixed: the swap timing (0.6.2-0.6.4) left the old weapon's power
listeners behind on the first 40 swaps of a session (they could keep firing;
restart the game once to clear them). Smoother: the HUD's reactions and the
game's metrics wait 2 frames (the power icons are then matched to your
powers); a swap redoes only the weapon's part of your look (you, the portrait,
the off-screen marker), not all your armour; the weight power stays when the
weight class doesn't change. The timing line adds the listener count, whose
look was redone and when.
0.6.6: smoother still: Skill Slots' skill update the frame after a swap
(6-7 ms in one frame with the Cannon) now joins the swap's smooth window: the
skills change at once, their HUD follows spread out with the swap's (icons 3
frames after the swap, their layout 4, gear level 5, panel layout 6, portrait
7). The swap timing line names the listeners added / gone after each swap and
who asked for any full look rebuild.
0.6.7: the dodge's afterimages (two copies of you on every dodge, reused)
redo only their weapon after a weapon change (the game cleared and redid all
their armour, writing 5 "Could not find anim build" lines each time). The swap
timing names the art builds behind your look once a session (to find where
those log lines come from).
0.7.0: A swaps (swap during a dodge, or A right before / after LS) come out of
the dodge going its way, like the Spear's rolling drill: Hammer: the jump slam
forward (a bit further than the game's rolling one); Bow: Weapon Moves' leap
shot forward (hold A to charge; without Weapon Moves the game's forward jump
shot); Greatsword: the game's forward roll into its heavy swing (the
dodge-to-attack animation, slowing from dodge speed); Cannon: the roll the
dodge's way, then the normal shot ahead. The old moves stay as choices:
hammer_a = "fade_swing", bow_a = "backflip", greatsword_a = "quick_heavy",
cannon_a = "roll_blast".

0.7.1: bulletproofing: Two Weapons' part of a press, a loadout and a new run is
guarded: an error is logged ("[Two Weapons] error in ...") and skipped, instead
of the game's error screen ending the run. guard = false: the game's way.
Crash fixed: the Striker's Recall, then a swap (B + LS) to the Bow or Cannon
stopped the game ("RecallOneShotput ... table expected, got nil"): Recall pulls
its balls back on timers 5 and 11 frames later, and they ran against the new
weapon. Now every timer a weapon or skill left running is made safe at the
swap (it runs; if it needs the old weapon, it's logged and skipped), and the
recall finds no balls and does nothing.
Bug fixed: the Striker's balls bouncing between two targets for ever after a
swap. The game tells the Striker "your loadout is changing" (it puts its balls
away then) only on the first change after a clean loadout, so from the second
swap on the thrown balls were left behind, untracked, hitting the same targets
endlessly (and the Striker came back with full ammo). Now every swap tells it,
as a normal weapon change does: swapping away from the Striker puts its balls
away.

0.7.2: LS + A (swap during a dodge): every move goes the dodge's way.
Greatsword: the Gut Bash (its lunge). Cannon: the roll, then the Blast fired
back the way you came, so its kick launches you on along the dodge (it used
to launch you back against it). Hammer: the fade-away swing, hopping on the
dodge's way and swinging behind you (it used to hop back against it). The
others are still choices: greatsword_a = "dodge_heavy" / "quick_heavy",
cannon_a = "roll_blast_back" / "roll_shot" / "mortar" / "shockwave",
hammer_a = "fade_swing_back" / "jump_slam".

0.7.3: the Striker's focus glow on your hand (after a focus catch) went away
with its next throw, but a swap before that (LS + X) left it glowing on the
new weapon for good. A swap now removes it with the Striker
(twoweapons/swapsafety.lua).

0.7.4: swap attacks in a row. Swapping mid-attack into a swap attack stays
instant, and so does swapping mid-way through that one (hammer heavy -> spear
heavy -> hammer heavy). A swap during the second one in a row waits until
that attack has finished, and at least 0.5 s after it started; the press is
kept and swaps right then. Out of attacks, swaps are instant and endless again.
Settings: swap_chain_limit (2; 0 = no limit), swap_chain_wait (0.5 s),
swap_chain_hold (true; false = a press during the wait is ignored).
0.7.5: the wait after two swap attacks in a row lasted until you were out of
attacks altogether, so keeping a combo going (X / Y) held the swap for the
whole combo. Now that swap attack is over as soon as the game starts your next
move from a press (the combo's next hit, a dodge, a skill): the kept press
swaps right then (still at least 0.5 s after that swap attack started).
0.7.6: LS + A with the Cannon and the Hammer faced backwards (dodge right,
they faced left): 0.7.2 turned you around so their backward push would carry
you the dodge's way. Now you keep facing the dodge's way and the push itself
goes the other way: the Cannon's Blast fires ahead and its kick launches you
on along the dodge; the Hammer's fade-away swing swings ahead and its hop
carries you on along the dodge. 0.7.2's are still there: cannon_a =
"roll_blast_turned", hammer_a = "fade_swing_turned".
0.7.7: a swap pressed during the wait after two swap attacks in a row is
ignored now (it used to be kept and swap by itself when the wait was over).
swap_chain_hold = true brings that back.
0.7.8: the same swap move again and again does less damage. Swaps stay
instant. Each swap move counts by itself (per weapon and move): the first 2
times in a row are full damage, from the 3rd on that move's own hits do 66%
(spear multi-thrust -> Cannon / bow -> multi-thrust -> ... -> the 3rd
multi-thrust: 66%). 2.5 s without a swap attack: full again. Arrows / shells
the reduced move fires keep it when they land; normal attacks, the combos you
carry on afterwards and powers' own hits are never reduced
(twoweapons/repeatdamage.lua). Settings: swap_repeat_full, swap_repeat_factor,
swap_repeat_window. swap_damage_log (on for now): every minute client_log.txt
gets each weapon's light attacks' and swap moves' damage per second, to set the
66% from real play.
0.7.9: only strong swap moves get the repeat reduction: the game's heavy
attacks and skills (the multi-thrust is a heavy). Light ones (Cannon quick
shot, the bow's light shots, the dodge moves) are never reduced.
swap_repeat_also / swap_repeat_skip add or leave out moves by state name.
0.7.10: never reduced either (swap_repeat_skip): the hammer's Y flip slam and
A jump slam, the spear's jump thrust, vault strike and crosscheck, the Cannon
whack and the bow's jump shot. Still reduced from the 3rd in a row: spear
multi-thrust; hammer golf swing and Order in the Court; Greatsword sweep,
dodge-into-heavy swings, snapback, overhead slam and skill slash; Cannon
Roll + Blast and mortar; bow melee bash; Striker focus throw and ball slam.
0.7.11: the bow's melee bash is never reduced either.
0.7.12: a repeated strong swap move does 59% from the 3rd time in a row (was
66%): about what the weapon's light attacks deal in the same time (spear: its
light combo 3.45 in 42 frames against the multi-thrust's ~3.15 in the ~23
frames to its last thrust, 60%).

0.8.0: both weapons' gems count (Sustain + Support), so max health and the
rest no longer change with a swap (both_weapons_gems).
0.8.1: the Teffressence Container always stays with its weapon, so it can't
imbue the weapon in hand from the other weapon without being used up.
0.8.2: the Greatsword's LS + B Snapback plays its swing to the end: the game
cuts its overhead swing at frame 17 and jumps to the recovery, so the sword
landing and the settle were missing (the game's own Snapback is unchanged).
The Hammer's LS + A fade-away swing hops further (about 2.1 units, was 1.15):
hammer_fade_distance in the settings (1 = the game's own hop).
0.9.0: a new character starts with two random basic weapons instead of the
game's basic Hammer (with the basic Spear in the bag): one in hand, the other
as your other weapon, from the 21 pairs in starting_pairs (in hand + other:
"spear + striker", "cannon + greatsword" ...; names: hammer, spear,
greatsword, striker, cannon, bow). The game's starting weapons not in your
pair leave the bag (the basic ones can still be made at the forge). Only a
brand new character (the game loads it with no saved data), never an
existing one; each local player gets their own roll. The log says which:
"[Two Weapons] new character: bow + striker (bow_basic in hand,
shotput_basic the other)". starting_pair = false: the game's weapons.
0.9.1: a new character's two weapons are unlocked at their weapon racks in camp
too (the Striker / Cannon / Bow / Greatsword racks stayed locked with their
Corestone price although you held the weapon). The rack is left as the game
leaves it after your last deposit: its progress filled and claimed, the weapon
type unlocked; the rack's reward (another basic weapon) isn't given, you hold
it. Only for that new character (each one has their own racks). The Greatsword
is only picked with the Draco DLC (its rack needs it). The log:
"[Two Weapons] new character: weapon racks unlocked in camp: cannon_basic,
shotput_basic". starting_pair_unlocks_racks = false: the racks stay locked.
0.9.2: a weapon power for each weapon. The weapon power room (a run's choice of
two Legendary powers that change one of a weapon's moves; a run has one at
most: the first room in about 1 in 3 of the shorter runs, or a door later on)
only offers powers for the weapon in your hand. Take one, and a moment later a
second choice flies out of the same crystal for your other weapon: the same
number of powers, rolled the game's way (its rarity roll and its rules: not
one you have, unlocked, ...); take one. The game's weapon powers already check
which weapon you hold and set themselves up again when it changes, so it
starts working when you swap to that weapon. Rules: both weapons the same
type (two Hammers): no second choice (the one Hammer power already works on
both; both_weapon_powers_same_type = true: a second Hammer choice anyway, not
the power you took nor the one you passed on). Swapping during the scene changes nothing: the first choice is for the
weapon in your hand when the crystal opens, the second for the other one, and
neither is rerolled or switched by a swap before, between or during the
picks; you end with one power for each weapon. The log names the
second choice: "[Two Weapons] weapon power room: your other weapon's choice
after the first (polearm): ...". both_weapon_powers = "first_room": only when
it's the run's first room; false: the game's one choice.
0.7.13: swap attacks turn with the stick like the game's own moves. Dodge one
way, push the stick back the other way, then LS + A: the A move turns to the
stick first (it used to always keep the dodge's way). X / Y / B already faced
the stick. Only "back" counts, by the game's own check (the one that picks
its turned attacks out of a dodge); the stick along the dodge, straight up /
down or let go keeps the dodge's way. swap_turn_with_stick = false: as before.

0.9.3: every run starts with the weapon power room. The game makes a shorter
run's first room (r1-r3 of each region) the weapon power room only 1 time in 3;
the other runs started with the normal pick of three powers, so Two Weapons had
nothing to add (it only adds the second choice in a weapon power room). Now the
first room is always the weapon power room there, in place of that normal
pick: a choice for the weapon in your hand, then one for your other weapon.
It's still the run's one weapon power room (the game counts it, and stops
offering more once you have two weapon powers). A long run's Fabled start stays
as it is. If nobody has a weapon power to take (none unlocked for the weapon in
hand), the normal pick comes out instead. The log: "[Two Weapons] the run's
start: the weapon power room (the game rolled the normal power pick)".
weapon_powers_at_start = false: the game's odds again (if it feels too strong).

0.9.4: the keyboard swap key is M (was R). With cheats / the console on, R is also
the game's "Repeat Last Console Command" hotkey, so every R press swapped and also
reran your last console command. With a c_give there (c_give("weapon",
"hammer_owlitzer")), the game puts that weapon back in every local player's hand
even when you already have it, so the swap looked like it switched and quickly
switched back (local co-op, the keyboard player, 2026-11-11). M is used by none of
the game's controls or debug keys (only Ctrl+M, and Ctrl isn't used in play; T
teleports you to the mouse, Shift+X opens a debug panel, and Shift is the
keyboard's skill button). If the keyboard key you set is one of the game's debug
keys, the log says so: "[Two Weapons] keyboard swap key R is also the game's debug
hotkey ...". Right hand: M sits under J / K, so a swap attack is K (or J) held, M.

0.9.5: more weapon power rooms, more Fabled rooms, longer hunts. Each weapon power
room still gives a choice for each of your two weapons (the second round for the
other weapon, as before).
  * The first: always. Side hunts: the first room (0.9.3). Boss runs and the
    Blight start with the game's Fabled room, so there one of room 2's doors is
    the weapon power room (its normal power door if it has one). Tefframech's own
    run keeps its room 3 (the game always gives that one).
  * A 2nd and a 3rd can come: 3 at most, so 3 weapon powers per weapon. The game
    stops all weapon power rooms once you hold 2 weapon powers (with a power for
    each weapon: after the first room) and allows one per map; here the count is
    per weapon, and a map allows 3. They come only where the game puts weapon
    power rooms, at its odds times second_weapon_power_room (2.5) and
    third_weapon_power_room (0.25): the 2nd in about 7 runs in 8 (3 in 4 Blights),
    the 3rd in about 1 run in 11.
  * They don't compete with Fabled (Lightning) or any other room: a weapon power
    door's odds come out of the normal power doors only; Fabled, potion,
    upgrade, Wanderer, gift, coin and material rooms keep the game's odds.
  * Longer hunts (extra_rooms = 2): side hunts 15 rooms (+2, in rooms 3-10),
    Blight legs +2 (rooms 3-11), boss runs 20 (+1, rooms 10-17: the pause map has
    no path for longer boss runs). The extra weapon power rooms then come on top
    of the rooms you'd get anyway: a run still has as many normal power rooms as
    before (the game's limits per map stay). The pause map uses the game's paths
    (for 15 and 12 rooms, the start of its 17- and 13-room paths).
  * More Fabled rooms: a map allows 3 (fabled_rooms_per_map; the game's 2 in boss
    runs, where the first room and the miniboss used both, so its later Fabled
    doors never came; 1 per Blight leg). Side hunts get Fabled doors again at the
    game's own old odds (fabled_in_side_hunts = 2, rooms 3-10; the game keeps
    them for boss runs now). Blight legs get some in rooms 3-9 (fabled_in_blight
    = 3). Each is the game's Fabled room: a hard room, the run's two families.
  * A weapon power room where you have none left for the weapon in hand: your
    other weapon's choice in its place. None for anyone: the game's normal pick.
  Simulated over thousands of runs of the game's own map code (6,000 per type):
  side hunt 1 / 87% / 9% (1st / 2nd / 3rd weapon power room), 0.84 Fabled rooms
  (game 0); boss run 1 / 89% / 9%, 2.84 Fabled (game 2.00); Blight 1 / 76% / 7%,
  3.85 Fabled (game 2.64); normal power rooms as before. The full table: the
  spreadsheet Weapon_power_rooms_2026-11-11.xlsx in Rotwood_Modding\mods\Two_Weapons.
  Each part has its own setting; false / 0 gives the game's. The log:
  "[Two Weapons] ...; more weapon power rooms: the 2nd at 2.5x, the 3rd at 0.25x
  the game's odds (7 maps)", "[Two Weapons] longer hunts: side hunts +2, boss runs
  +1, Blight legs +2 rooms (14 pause-map paths made)", "[Two Weapons] more Fabled
  rooms: up to 3 a map, side hunts at 2, Blight legs at 3".

0.9.6: the swap diagnostics are off by default (swap_timing, swap_damage_log). Each of a session's first 40 swaps counted every listener and entity and wrote a 2 KB line to the log, which added work to exactly the swaps you notice; turn them on again only to measure.

0.9.7: the 3rd weapon power room comes in about 1 run in 4 (was about 1 in 11).
  third_weapon_power_room is now 0.65 (was 0.25), and the Blight's maps have their
  own setting, third_weapon_power_room_blight (1.0): a Blight leg has fewer weapon
  power doors, so the same odds gave it less. Simulated over 6,000 runs of each
  type with the game's map code: 3rd weapon power room in side hunts 23.6% (hard
  24.2%), boss runs 21.4% (hard 25.2%), the Blight 23.6%; the 2nd stays at about
  87-89% (Blight 75%). Fabled and normal power rooms as before (side 0.80 / 3.91,
  boss 2.83 / 4.77, Blight 3.81 / 7.80). The 2nd and 3rd still take their odds
  only from normal power doors. The log: "[Two Weapons] ...; more weapon power
  rooms: the 2nd at 2.5x, the 3rd at 0.65x (1.0x in the Blight) the game's odds
  (7 maps)". The full table: Weapon_power_rooms_2026-11-11_v2.xlsx in
  Rotwood_Modding\mods\Two_Weapons.

0.9.8: Fabled doors in about 3 rooms in 10, the Blight's 2nd weapon power room
above the game's, a chance of a 4th in the Blight.
  * Fabled: a Fabled door in about 3 of every 10 rooms that can have one (was
    2-17%): side hunts 29%, boss runs 28%, the Blight 32%. The game's spacing
    stays (after a Fabled room the next 2 have none, so about 1 room in 3 is
    the most). Per run: side hunt 2.7 Fabled rooms (was 0.8, the game 0), boss
    run 5.0 (2.8, the game 2), Blight 6.5 (3.8, the game 2.6). Settings:
    fabled_in_side_hunts = 45, fabled_in_blight = 40, the new
    fabled_in_boss_runs = 60 (rooms 3-7 and 10-16), fabled_rooms_per_map = 6.
    They take a share of every other door: normal power rooms side 3.5 (was
    3.9), boss 4.1 (4.8), Blight 7.7 (7.8); fewer coin and material rooms
    (side coin 1.4 vs 2.0, material 0.7 vs 1.1). With the Fabled ones a run
    has more power picks than before (side 6.2 vs 4.7).
  * Why the Blight's 2nd was below the game's (75% vs 80%): the 2nd and 3rd
    took their odds out of the normal power doors only, and a Blight leg
    allows 3 normal power rooms, so once you had taken those, its later rooms
    had no weapon power doors at all. Now the rest comes on top, as the
    game's own weapon power doors do. Retuned: second_weapon_power_room 1.9,
    third 0.45; the Blight has its own: second_weapon_power_room_blight 1.2,
    third_weapon_power_room_blight 0.27.
  * A 4th weapon power room, only in the Blight (fourth_weapon_power_room_blight
    = 1.0, 0 = none): in about 1 Blight in 12. A weapon with 4 weapon powers
    gets its last one (no choice left); none left: your other weapon's choice.
    For a test run, third_weapon_power_room_blight = 5 and
    fourth_weapon_power_room_blight = 5 make them come in most Blights.
  Simulated (6,000 runs per type, the game's map code): 2nd weapon power room
  side 88.5%, boss 91%, Blight 88% (the game 80%); 3rd 21-25%; Blight 4th 8%.
  The log: "[Two Weapons] ...; more weapon power rooms: the 2nd at 1.9x, the 3rd
  at 0.45x the game's odds (the Blight: 1.2x, 0.27x, a 4th at 1x) (7 maps)",
  "[Two Weapons] more Fabled rooms: up to 6 a map, side hunts at 45, boss runs
  at 60, Blight legs at 40". The full tables:
  Weapon_power_rooms_2026-11-11_v3.xlsx in Rotwood_Modding\mods\Two_Weapons.

0.9.9: longer side hunts so the Fabled doors cost no other rooms; a Blight 4th in
1 in 8.
  * Side hunts get 3 more rooms after the weapon power rooms (the game's rooms
    9-10 stretch: monsters with normal power, coin, material, Fabled doors...,
    no weapon power doors): 18 rooms, drawn on the game's own 18-room pause-map
    paths. Normal power 3.9, coin 2.25, material 1.2 rooms a hunt (0.9.7: 3.9,
    2.0, 1.1; 0.9.8: 3.5, 1.4, 0.7), Fabled 3.6, weapon power odds unchanged
    (2nd 89%, 3rd 21%). Setting: extra_side_hunt_rooms = 3 (0: none, 4 at most,
    19 rooms). The log: "[Two Weapons] longer hunts: side hunts +5 (3 after the
    weapon power rooms), boss runs +1, Blight legs +2 rooms (12 pause-map paths
    made)".
  * fourth_weapon_power_room_blight = 2.2: a 4th in about 1 Blight in 8 (12%).

1.0.0: the rooms moved to their own mod, Hunt Rooms (rotwood-hunt-rooms).
Two Weapons keeps what's about carrying two weapons: in every weapon power room
a choice for each of your two weapons (both_weapon_powers), as before.
  * Gone from here (now Hunt Rooms', with its own settings): the weapon power
    room at every start (now its start gives its own pick and then the weapon
    power choice), room 2's weapon power room, the 2nd / 3rd / 4th weapon
    power rooms, more Fabled rooms, longer hunts (extrarooms.lua, fabled.lua
    and their settings: weapon_powers_at_start, weapon_power_room_2,
    second_ / third_ / fourth_weapon_power_room*, fabled_*, extra_rooms,
    extra_side_hunt_rooms). Without Hunt Rooms the rooms are the game's.
  * The game's rule for more weapon power rooms (none once a player holds 2
    weapon powers) now counts rooms, not powers: a room here gives each
    weapon one, so after one room you hold 2 and the game would have stopped
    the Blight's second weapon power room. With Hunt Rooms, its own answer
    (the game's own rooms only) is used.
  * A weapon power choice another mod adds (Hunt Rooms' start) with nothing
    left to offer: nothing in its place (a normal power room still gets the
    game's normal pick then).

1.0.1: no power icon flickering in the middle of the screen after a swap.
The smooth swap spreads the HUD's work over a few frames: the new weapon's power
icon is made one frame before the icon layout puts it in its row, and for that
frame the game drew it where a widget with no place goes, the middle of the
screen (the Windbreaker's "+0%" icon, user video). The new icon is now hidden
until the layout has placed it, then shown (an icon something else hid stays
hidden). Costs a look at the power icons in that one frame.

1.0.2: weapon powers no longer lost, and no empty weapon power choices.
  * The game keeps 4 weapon powers and a new one past that takes the place of
    your oldest; made for one weapon. With a power for each weapon (and Hunt
    Rooms' extra weapon power rooms) the 5th and 6th replaced your first ones
    (log: "Removing hammer_echo_slam to make room for new power (WEAPONPOWER
    limit = 4)"). Now it's twice the game's: 8, 4 for each weapon
    (weapon_power_limit = "double", a number, or false for the game's).
  * A weapon has only so many weapon powers (Cannon, Hammer, Bow, Spear: 4), so
    late in a long run a choice had 1 left, then none (P2 got one pedestal,
    then nothing, while P1 had two). A choice short of powers is now filled up
    to your usual number from the game's normal power pick (its filters, no
    Fabled modifiers, nothing already shown); a player with nothing left for
    either weapon gets a whole normal choice. weapon_power_fill = false: the
    choice as it is.

1.0.3: power pedestals never land on top of each other (user screenshot: the
start room with two players, 7 pedestals, three overlapping in the middle).
The game puts each player's choice in a circle beside the crystal and pulls a
circle of 3 or more powers in toward the crystal by its radius; with 3-4
powers each (Choosey gems, a filled choice) the two circles meet in the
middle. Now the pedestals' slides out of the crystal (the game's own) wait a
moment while all the circles of that drop are placed: if any two would land
closer than 3.5, every circle moves out from the crystal a step at a time
(tighter circles if the room runs out), keeping the game's shape and staying
on walkable ground. The other weapon's choice later lands clear of the other
player's pedestals the same way. Runs once when the pedestals appear.
power_spacing = false: the game's spots.

1.0.4: no flicker in the power rows on a swap (user video: the weapon's own
power, the first icon, went a frame before the new one came, then the top row
stood an icon to the left for 2 frames). The old weapon's icon now stays until
the new one is placed, in the same frame, and the new one is shown before the
rows are lined up (the game lines them up by the icons shown), so the rows
never move.
Your other weapon's choice flies out with the crystal's split sound (the
first choice's pedestals fly out as the crystal shatters, with its two shatter
sounds; the second came later, the crystal gone, silent). The game's same two
sounds play where the crystal was, once. split_sound = false: no sound. (Local
play: heard on this machine; an online player hears it only on the host.)
1.0.5: the power rows no longer shake on a swap (user video: 1.0.4 swapped the
icon cleanly, but the rows stood a pixel up for 2 frames, then came back). The
game lines the rows up by what's drawn in them, and the new icon's box isn't
quite its final one in its first frame; the panel's own layout two frames
later put them back. The swap's icon layout now keeps the rows where they were
when it would only move them a few units (a real change, like another row of
powers, still moves them).
1.0.8: a weapon with no weapon power left gets other powers, half of them
Fabled (user, 02:48 and 03:19: "the second weapon gets the normal choice, the
cannon gets 2 random powers with a high chance of being Fabled", "maybe 50%").
  * A short choice (a Cannon with an ammo power has only Return to Sender
    left) is filled with other powers: each one Fabled half the time (the
    game's Fabled roll: the run's Fabled families, shuffled) and otherwise
    the game's normal power pick; nothing already in the room's choices.
  * A weapon with nothing left: its turn is a choice of those other powers
    (your usual number) and your other weapon keeps its own weapon power
    choice. In hand: the other weapon's choice first, then its turn; as your
    second weapon: its turn is the second choice (1.0.7 skipped it there).
  * weapon_power_fill_fabled = 50 (the percent Fabled; 0 = never, 100 =
    always while there are some); weapon_power_fill = "weapon" for 1.0.7's
    fill (your other weapon's weapon powers), "normal", false.
  * Hunt Rooms' start choice isn't filled (as before).

1.0.7: weapon power choices stay weapon powers (user, 02:01: "player 2 didn't
get a 3rd power for the cannon, and even the second power was a choice
between a mundane power and a weapon power, again"). Not 1.0.2's bug back:
the game's Cannon gets 2 weapon powers at most. Its three ammo powers
(Single Shot, Rapid Light, Infinite Ammo) exclude each other (the game's
AMMO_MODIFIER tags), so after one of them only Bounce Catch Reload is left;
1.0.2 filled the short choice with a normal power, and with nothing left the
Cannon's place went to the Hammer with one pick only.
  * A short choice is now filled first with your other weapon's weapon powers
    (the game's filters, nothing already in the room's choices); normal powers
    only once both weapons are out. P2's 2nd room: Bounce Catch Reload or a
    Hammer power.
  * None left for the weapon in hand: your other weapon's choice in its place
    and then a second one of it (not the first's powers), so you still pick
    twice in the room. P2's 3rd room: two Hammer choices.
  * The second choice is looked at again when it comes out: a power your
    first pick took or ruled out (one ammo power rules out the others) is
    left out and the choice filled again (log: "... left out of your other
    weapon's choice").
  * weapon_power_fill = true (this), "normal" (normal powers only, as 1.0.2 to
    1.0.6), false (the choice as it is).
With Hunt Rooms 0.1.5 the run's weapon power rooms are counted by rooms, so
a weapon getting two powers in a room doesn't end the run's weapon power
rooms early.

1.0.6: the second choice's split sound was silent (user, 22:08). 1.0.4 / 1.0.5
played it from a sound-only entity made where the crystal was; now the same
two shatter sounds play from the player whose choice it is, as that player's
sound (the game's PlayCodeSound with the player as instigator, how the game
plays its own code sounds; heard by everyone, online too). Each time, the log
says: "weapon power room: the second choice's split sound (2 of 2, from the
player)".

1.0.9: the market counts every hunter the same (user 2026-11-13: "it picks
player 1's weapons and ignores player 2's"; 19:15: "a fix, not a rework:
take player 2 equally into account, and don't show what both players have;
if both have everything from that area, keep the first roll"). The game
rolls the market's list its own way (this hunt's gear, the weapon types the
hunters hold first), then cuts what's owned in three tiers: nobody owns it,
some own it, all own it, taking the first tier that fills every stand. A
piece one hunter already owns fell behind pieces nobody here wants, so
player 2's weapon was pushed off the stands by a random type. Now the first
two tiers are one, in the game's own rolled order: a piece counts as owned
only when every hunter here owns it, and those come last, shown only when
there's nothing else for that stand (then in the game's roll). Nothing else
changes. market_weapons = false: the game's tiers.

1.0.10: the swap button works in the gem screen (user 2026-11-13: "allow LS
weapon swap in menu"). At the gem table (Modify Weapon Gems, its weapon tab)
the left stick click / M swaps your weapons right there, the game's own swap,
and the panel shows the other weapon's gem slots the way the game fills it
when the tab opens. Only on the weapon tab, not with a popup up, only with a
second weapon. gem_screen_swap = false: the game's. Taking a gem that's set
on your other weapon is the game's own already: pick it in the list (greyed,
its details say which weapon it's set on) and Equip asks "Gem already set on
your <weapon>. Do you want to unset it from there first?", then moves it.

1.0.11: the Greatsword's Berserk carries over to your other weapon (user
2026-11-13: "it stops in swaps"; "carries over, you stay red, also must work
with the other weapon powers"). The game ends Berserk the moment the weapon
in your hand isn't a Greatsword (it checks every frame). Now, while your
other weapon is a Greatsword, it stays on with the weapon in hand: its timer
runs, your attacks with either weapon add time (the game's own light / heavy
attack counting), and the +25% speed, the 30% damage taken, the attacks that
can't be interrupted and the Multistrike stance's extra protection stay. The
Greatsword's own moves (Multistrike hits, its Meter) stay with it. You stay
red: after a swap the game's Berserk blade glow goes on the weapon in hand,
the red aura is put back if it was lost, and the Berserk switches are set on
the Greatsword's fresh stategraph when you swap back. The Greatsword's
Berserk weapon powers (Berserk on entering a fight room, on drinking a
potion, Headhunter's kills) work with it as your other weapon too. It ends
as the game's does: its timer, or when neither weapon is a Greatsword.
berserk_carry = false: a swap ends it, as the game.

1.0.14: the second weapon's Teffressence Container also works on Frenzy
Levels' Super Frenzy side hunt bosses, when that mod makes the gem work there
(its super_side_hunts.imbue_gem, Frenzy Levels 0.11.3: Super Frenzy 5).
1.0.13: the Teffressence Container gem on your second weapon works too (user
2026-11-14 03:33: "this stone only works for the weapon you kill the boss
with; if the second weapon has it, it won't unlock"). The game's gem works on
a boss kill at Super Frenzy, and only for the weapon in your hand: it sets the
weapon to item level 11, takes the gem out and lets it be upgraded past level
10 (imbued). Now on the same kill your second weapon gets the same: the
game's own test (not imbued yet, not a boss weapon, the gem in one of its
slots; not in a Blight Incursion leg) and the game's own imbue on that weapon
(craftingutil.ChargeNormalWeapon, through a stand-in whose equipped weapon is
your second one), then the game's "Imbued!" note with its name. With the gem
on both weapons, both are imbued on one kill. Its own part (twoweapons/
imbue.lua); second_weapon_imbue in the settings (false = the hand only).
1.0.12: the market's weapon stands, the weapons in your hands first (user
2026-11-13 20:54: "still giving out other classes when the current held
weapons of the area aren't owned yet"; 21:01: "when both players have the
weapon in hand the market rolled nothing"). The game mixes its roll (a type
nobody holds could come first), and 1.0.9 counted "one of you owns it" the
same as "nobody owns it", which put the weapons you both already hold back
on the stands. Now:
  * each hunter's weapon in hand first: this hunt's weapon of that type, when
    that hunter doesn't own it yet (their own inventory), one for each hunter
    (player 1 the first stand, player 2 the second; both holding the same
    type: that weapon, and the other stand the game's roll).
  * then the game's own order: pieces nobody has, then pieces one of you
    has, then pieces you all have (only when nothing else is left for a
    stand; if you both have everything from the area, the game's first roll).
Armour stands are the game's (its own tiers). market_weapons = false: the
game's market.
