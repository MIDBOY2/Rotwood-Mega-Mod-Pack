Frenzy Levels 0.11.3 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Pick a main hunt's Frenzy level on the map, 1 to 5.

The game has five normal Frenzy levels, but a frenzied main hunt is always
Frenzy 5; only the side hunts with weather play 1 to 4, set by how many zone 2
hearts you've put in. The game's old level picker is still in
its files, switched off.

How to use
- Open the map, pick a main hunt, and have it in Frenzy mode (the purple one,
  not Super Frenzy).
- LB / RB (keyboard Q / E) lower / raise the level. Under the hunt's name it
  says "Frenzy 3" between the two buttons; the dungeon tier badge and the map
  marker follow (Frenzy 1 = tier 6 ... Frenzy 5 = tier 10).
- Each hunt remembers its own level (in your save). A hunt you never changed
  is Frenzy 5, the game's.
- Side hunts: the same, No frenzy to 5 (below), and on the side hunts you
  frenzy yourself RB goes on: Super Frenzy 1 to 5 (an experiment, below).
- Super Frenzy works as before (LB / RB still pick the Super Frenzy level).

What each level does (the game's own levels, each adds to the one before)
  1  tier 6 enemies, elites (25%) and cyborgs, bosses +27% health, ingots and
     corestones from bosses
  2  +20% enemy health and damage, bosses +54%
  3  +40%, enemies attack more often, more elites (45%), more ingots /
     corestones, bosses +81%
  4  +60%, reviving a hunter costs you health, bosses +108%
  5  +80%, the fastest attacks and wind-ups, the most elites (55%), much
     tougher minibosses, the most ingots / corestones, bosses +135%

Side hunts
  Each area has one main hunt (the big marker, with the area's boss, like
  Nocturne Grove and Owlitzer) and a few side hunts around it (Acrid Glade,
  Brambleside Footpath, Tangled Hollow, ending with a smaller boss). The game
  frenzies a side hunt only while it has weather, at a level it picks (1-4);
  without weather it's a normal hunt. Now LB / RB pick No frenzy or Frenzy 1
  to 5 on any side hunt (once frenzy is unlocked in that area): under the
  side hunt's name it says "Frenzy 3" between the buttons, the title turns
  purple, and the tier badge follows. Each side hunt remembers its own; one
  you never changed keeps the game's level. side_hunts = false: the game's.
  The game's anomalies (side hunts it frenzies with weather): LB / RB still
  pick Frenzy 1 to 5, but never Standard, and they keep the game's Frenzy
  look.
  A side hunt you frenzied yourself (no weather): X (keyboard Shift) on the
  map switches its look, "Frenzy look" (the game's dusk colours, the default)
  or "Normal look" (the hunt's own colours); the title shows which. Saved per
  hunt.

Super Frenzy side hunts (an experiment)
  On a side hunt you frenzied yourself (no weather; not the game's anomalies),
  RB past Frenzy 5 picks "Super Frenzy 1", then 2 to 5: the title says which,
  the panel turns the game's Super Frenzy dark purple, and the map marker
  gets the main hunts' Super Frenzy look: their dark shield with its horns
  (without the crown, like every side hunt marker; the mod's
  images/frenzylevels_markers, made from the game's own shield), the Super
  Frenzy tier badge and the pink boss icon. LB goes back down. Super
  Frenzy 1 is open on every such side hunt; each next
  level opens when you win the one below on that side hunt (unlock_all =
  true, the setting for now: all five open). The game has no Super Frenzy for
  side hunts, so the run is the game's Frenzy 5 run (its progress, its look,
  the HUD says Frenzy 5) with:
  - the game's Super Frenzy level (each adds to the one below):
      level   enemy health  damage*  side boss health  and
      Frenzy 5  x2.8        x2.8     x4.9              (55% elites)
      SF1     x3.0          x3.0     x7.5              every enemy that can be
                                                       elite is elite, harder traps
      SF2     x3.45         x3.45    x8.2              deadly traps
      SF3     x3.7          x3.7     x8.55             (the game's hard miniboss:
                                                       nothing on side hunts)
      SF4     x3.83         x3.95    x8.73             you start 250 health down
      SF5     x3.95         x4.2     x8.9              higher prices, no free
                                                       upgrade or cauldron heal,
                                                       one market choice fewer
      * before your armour
    The boss stays the side hunt's own one (the game has no elite side
    bosses, and no double miniboss fight here).
  - every fight room is a hard room (the horned door icon), weapon power and
    friend gift rooms too. Hard rooms already give more than normal ones:
    Teffra from the room's kills 12-16 (normal rooms 4-10), a Teffra room
    165-185 (70-75), 2 Corestones (1), more materials in a material room, more
    and tougher enemies. When two plain doors (or two coin doors) would look
    the same, one becomes the other kind (the game's own fix).
  - the boss's end drop like a Super Frenzy main hunt boss's (0.8.3,
    boss_like_main): 6 Corestones and 5 ingots before the multiplier below
    (Frenzy 5's are 5 and 3). No Teffra added (the hunt is over).
  - Hunt Rooms 0.3.0's Heart Shard room (in its extra rooms): its Heart
    Shards are Hunt Rooms' fixed number (the Super Frenzy level), not
    multiplied below.
  - loot x1.5 / 1.75 / 2 / 2.25 / 2.5 (SF1 to SF5) on top of all that:
    Corestones (the boss's too), monster and boss materials, ingots, seeds
    and Heart Shards. Not Teffra (the game's konjur; teffra = true to
    include it), boss hearts, gems, powers, cosmetics. Counts are rounded at
    random so the average is exact (1 Corestone at x1.5: 1 or 2, half the
    time each).
  Log: "[Frenzy Levels] Super Frenzy 3 side hunt (treemon_forest_r1): Super
  Frenzy 3 enemies, every fight room hard, loot x2 (not Teffra)" when the
  run starts, "corestones: 2 -> 3 (Super Frenzy 1 side hunt)", and on a win
  "Super Frenzy 3 cleared on treemon_forest_r1: Super Frenzy 4 opened".
  super_side_hunts in the settings (loot, teffra, all_hard, unlock_all;
  false: RB stops at Frenzy 5). Only the host's game knows the pick (a solo
  run is fine).

More for the harder choices (0.9.0)
  Nothing is taken away: every level keeps what the game gives it, and the
  harder choices get more on top.
  - Weather side hunts at Frenzy 5 (the game picks their level, 1 to 4; you
    can raise it): each tier of the weather meter you reach gives one more
    reward from that tier's own bag (gems, Heart Shards, ingots, materials,
    seeds; the top tier a gem seed too). A full meter: about 2.5 gems and 2.3
    Heart Shards instead of 1.6 and 1.8. weather_bonus.
  - Nimble's two challenges (the curses he offers at a main hunt's start)
    both done in one run, at Frenzy 5 or Super Frenzy: at the final market, on
    top of his Heart Shards, a power upgrade, a reroll and an extra life for
    the boss. That's the game's own bonus for doing both (switched off in the
    game). nimble_bonus (min_level = 6: Super Frenzy only).
  - Side hunts you frenzy yourself (no weather), Frenzy 1 to 5: the boss
    gives each hunter more of the area's ingots (+1 / 1 / 2 / 2 / 3) and
    materials (+2 / 3 / 4 / 5 / 6, the game's materials room roll), on top of
    the extra Corestones. Not the anomalies or Super Frenzy side hunts.
    side_boss_bonus.
  - Main hunts at Super Frenzy, a repeat clear (that level already cleared
    with that weapon there, so no Imbued Heartstone this time): the boss gives
    each such hunter 1 / 1 / 2 / 2 / 3 Heart Shards (Super Frenzy 1 to 5), a
    fixed number (the loot multiplier leaves them alone). Nimble's Heart
    Shards come on top (those are multiplied: 2 become 3 to 5).
    super_main_shards.
  Log: "[Frenzy Levels] Frenzy 5 weather: the meter's tier 2, +GEM_UNIDENTIFIED",
  "Nimble's challenges, both done: power upgrade, reroll, extra life",
  "Frenzy 3 side hunt boss: +2 ingots, +4 materials", "Super Frenzy 4 boss, a
  repeat clear: +2 Heart Shards". Each part checks the game's code first and
  stays the game's way if something changed; an error inside is logged and
  the game's own reward goes on.

Colours
  The game colours every frenzied hunt with a dark purple dusk (its Frenzy
  lighting; Super Frenzy has its own). Side hunts used to be frenzied only
  with weather, so with Frenzy on side hunts most runs look like dusk; that's
  the game's Frenzy look (frenzy_look = true, the default). frenzy_look =
  false: Frenzy 1-5 keeps the hunt's normal colours (only the look changes,
  the Frenzy's enemies and rewards stay). super_frenzy_look = false: the same
  for Super Frenzy. Standard (no frenzy) always has the hunt's own colours,
  and each side hunt has its own (Ironwood Trail is bluer than the Great
  Rotwood Forest). Weather (rain, night...) has its own lighting.

Rewards are the game's for that level (it's the same as a side hunt with weather at that
level). Super Frenzy is already unlocked for you, so your Frenzy clears are
all counted at 5 and a lower pick doesn't change your progress.

Cosmetic armour
  Each boss kill can drop a piece of cosmetic armour. The chance by level:
  level        game's            now
  no frenzy    1%                1% (unchanged)
  Frenzy 1-5   2 3 4 5 7.5%      10 20 30 40 100%
  Super 1-5    10 12 14 16 20%   100% (all five)
  At Frenzy 5 and in Super Frenzy every boss you kill drops a piece. Below
  that, a miss adds that chance to your next boss until a piece drops (the
  game's catch-up). Once you own every piece there's nothing left to drop.
  (The game also needs the mirage station unlocked.) cosmetic_chance in the
  settings.

Corestones
  The side hunts you frenzy yourself give more corestones (the game's
  anomalies have their reward meter instead):
  level        boss kill (game's + extra)   corestone room / Teffra Zucco
  Frenzy 1     1 + 1                        1-2 + 1
  Frenzy 2     1 + 1                        1-2 + 1
  Frenzy 3     2 + 2                        1-2 + 1
  Frenzy 4     2 + 2                        1-2 + 2
  Frenzy 5     3 + 3                        1-2 + 2
  Nothing extra when the boss gives its heart instead. corestone_bonus in the
  settings (hunts = "all_side": anomalies too, "all": main hunts too).
  Log: "[Frenzy Levels] corestones: 3 + 3 (Frenzy 5 side hunt, boss)".

Drakinspawn (Drakin Armoury Pack)
  The game: each Drakinspawn drops a heart shard, and only once you've
  finished Brother Tendy's quest a 25% chance of one Drakin armour piece
  (Skyhunter and Marrowdeep sets, 6 pieces). The Drakin weapon looks drop only
  in Blight Incursions. Now every Drakinspawn, Tendy's three fights included,
  drops 4 pieces (armour and weapon looks: 12 in all) while you have some left
  to get, so you have everything by the end of the quest. The quest's own
  Immaculate Edge set is unchanged. drakin_rewards in the settings.

Blight Incursions
  The game gives no cosmetic on a boss kill in a Blight; its mirages (the
  Blight's armour sets, the Drakin weapon looks, mirages of gear you own from
  the hunts you passed) come only from Nimble's Cache, rarely. Now every
  Blight boss drops one while you have some left to get. blight_mirages in the
  settings. Log: "[Frenzy Levels] Blight boss: a mirage".

Settings: scripts\frenzylevels_settings.lua
  enabled = false        the game's way
  min_level = 0          LB also reaches "Standard" (no frenzy)
  default_level          where a hunt starts (5)
  show_in_title = false  no text under the name
  cosmetic_chance        the cosmetic armour chances above (false = the game's)
  corestone_bonus        the extra corestones above (false = the game's)
  drakin_rewards         the Drakinspawn drops above (false = the game's)
  blight_mirages         a mirage from every Blight boss (false = the game's)
  side_hunts = false     side hunts the game's way
  super_side_hunts       the Super Frenzy 1-5 side hunts above (false = none)
  weather_bonus          weather meter extras by level (false = the game's)
  nimble_bonus           Nimble's both-challenges bonus (false = the game's)
  side_boss_bonus        the side hunt boss's ingots / materials (false = the game's)
  super_main_shards      repeat Super Frenzy main clears' Heart Shards (false = none)
  super_main_hard        Super Frenzy main hunts' extra hard rooms (false = the game's)
  hard_power_rooms       weapon power / gift rooms hard too (false = never, the game's)
  hard_power_room_teffra their extra Teffra (35)
  gold_preview_key       every marker gold on the map, visual only ("Ctrl+Shift+Y"; "" = none)
  super_skip             the Super Frenzy level skip on main hunts (false = the game's one level at a time)

Log: "[Frenzy Levels] on: main hunts Frenzy 1 to 5 ..." when the first player
spawns. If the game's map code changes it says "off: ..." and the map works
the game's way.

0.1.0: first version.
0.11.3: the Teffressence Container gem works on Super Frenzy side hunt bosses
(user 03:54: "side hunts SF5: the miniboss kill at the end of the hunt will
activate the imbued gem"). The game's gem imbues the weapon in hand on a boss
kill only at the game's Super Frenzy (main hunts); a Super Frenzy side hunt
runs as the game's Frenzy 5, so it never did. Now the side hunt's boss kill at
Super Frenzy 5 does it the game's way (its own test: not imbued yet, not a
boss weapon; its own imbue: level 11, the gem used up, upgrades past 10, its
"Imbued!" moment). super_side_hunts.imbue_gem = 5 (1 = every Super Frenzy
side level, false = never). Two Weapons 1.0.14: the second weapon's gem too.
0.11.2: fix: a hunt with more Corestones at the end than one drop holds (a
Super Frenzy side boss, up to 15; a Super Frenzy main boss's repeat clear)
ended after the first drop (user 03:41: "finishing a side hunt on SF5 gives
all these corestones, but it finishes the run after taking a single reward,
because it ends the run on the next RB"). The game ends the hunt when the
boss's drop is taken, and its "Complete Hunt" button is on RB, so the extra
Corestone drops beside it (0.9.2) were still on the floor. Now the hunt's end
waits until those are taken too (at most 30 seconds; then the game's end, the
extras still there to take). The log says when it waits and when it goes on.
0.11.1: fix: a Super Frenzy level picked with the skip went back to the next
level to clear when the map's cursor left the hunt and came back (user 03:24:
"I tried to load super frenzy 5 but it loaded super frenzy 2", Bandicoot: SF5
picked, the cursor on a side hunt and back, the run started at SF2). The game
resets a hunt's pick every time the cursor comes to it (its default: the next
level to clear). Now its default is your stored pick when that's a higher
Super Frenzy level the weapon in hand can pick; a win still moves it on to the
next level (the game's), and a weapon that can't skip gets the game's.
0.11.0: the Super Frenzy level skip on main hunts (user 02:11 / 02:21 /
02:27: "after beating super frenzy 1, LB / RB all the way to super frenzy 5
regardless of weapons ... register the win across all frenzy 2, 3, 4, 5 on
both weapons, one heart per clear"; "an option to choose SF1-5 even if you
only killed one main boss at SF1"). The game's panel goes one level above
what the weapon in your hand has cleared there, and a win clears one level
for that weapon, one Imbued Heartstone. super_skip:
  unlock = "any_hunt" (mode 2, the default): once any main boss is beaten at
    Super Frenzy 1 with any weapon (read from the game's records, so a save
    that already has one counts), the Super Frenzy panel of every main hunt
    goes to Super Frenzy 5 with any weapon (where the game has opened Super
    Frenzy: its end-game unlock).
  unlock = "this_hunt" (mode 1): a weapon goes to 5 on a hunt once it has
    cleared Super Frenzy 1 there.
  A win at Super Frenzy N clears every level up to N for each weapon you hold
  (the one in hand and Two Weapons' second one: both_weapons) that's open by
  that rule; one that isn't gets the game's one level. One Imbued Heartstone
  per level newly cleared per weapon: the boss's drop gives the first (the
  hand weapon's, as the game), the rest come with the win (the pickup list
  shows them; a note on screen says which levels). Examples: Mother Treek SF1
  with hammer and bow (2 clears), then Bandicoot SF5 with both: Hammer SF1-5 +
  Bow SF1-5, 10 hearts. Owlitzer with the bow at SF3 and the striker never
  cleared, an SF5 win: Bow SF4-5 + Striker SF1-5, 7 hearts. A level your hand
  weapon cleared but the second hasn't: the panel shows the heart (not
  Corestones), and every panel level shows how many a win gives ("x7").
  Progression's liri mode doubles every Imbued Heartstone (its
  super_frenzy_heart_multiplier = 2), these too: set it to 1 there for one
  per clear. A picked level stays when you swap weapons (and, 0.11.1, when the
  cursor leaves the hunt and comes back).
  Safety: the extra hearts are given before the clears are written (an error:
  nothing written by this, the game's one level instead); Blight Incursion
  legs never count (the game's); hooks guarded, errors in the log ("Super
  Frenzy clears: the game's (...)"). Progression 0.4.1 leaves the second
  weapon to this.
0.10.3: the gold preview key (user 00:21: "a debug key to turn them all gold,
for visual purposes only"). Ctrl+Shift+Y on the map turns every hunt's marker
gold: side hunts the gold side shield (0.10.2), main hunts the game's gold
shield, all with the game's gold tier badge, number and logo. Visual only:
nothing is saved or unlocked, no pick changes; press it again (or restart the
game) for the markers as they are. A note on screen and in the log says which
("gold preview on: ... (15 markers redrawn)"). Modifiers exact, not while
typing; gold_preview_key in the settings ("" = no key). Ctrl+Shift+Y: no key of
the game's (its debug keys use G a lot) or of the other mods.
0.10.2: a side hunt's marker turns gold once you've cleared Super Frenzy 5 on
it (user 23:56: "once you clear super frenzy 5 on side hunts it turns gold
too, based on the main hunts' finished gold shield"). The game's main hunts
turn gold when every Super Frenzy level is cleared with every weapon (its
"completed" shield, tier badge and colours), shown while a Super Frenzy level
is picked; lower it and the Frenzy or normal look is back. The same here: with
a Super Frenzy step picked on a side hunt whose Super Frenzy 5 you've won
(Frenzy Levels counts the levels won per side hunt, not per weapon), the gold
side shield (the game's completed main hunt shield without its crown, made the
way the purple Super Frenzy side shield is: kit/tools/mapicons, both now in
images/frenzylevels_markers), the game's completed tier badge, its gold-brown
number and boss logo; LB down to Frenzy: the Frenzy shield and the black logo.
The game has a gold side hunt shield of its own (dungeon_bg_completed) that
nothing in it uses; this one keeps the main hunt shield's horns and bottom
spikes, like the purple one.
0.10.1: fix: a side hunt's map marker going back from Super Frenzy to Frenzy
(LB) kept the Super Frenzy pink boss logo on the Frenzy shield (user 23:47).
The game's code for a frenzied side hunt's marker puts back its shield and tier
badge but never sets the logo's colour (in the game a side hunt never had
Super Frenzy); now the logo goes back to the game's black when the marker leaves
Super Frenzy. Weather side hunts too.
0.10.0: more hard rooms, and Super Frenzy on weather side hunts (user
2026-11-13: "add weather rooms into super frenzy levels as well with x1.5 -
x2.5 rewards, including gems, heart shards"; "for the main hunt super frenzy,
start raising the hard room appearances: party level + super frenzy level,
max + max = 100% hard rooms, Super Frenzy 1 with party level 1-10 exactly as
now"; hard weapon power rooms "with an off switch, and just make it give more
teffra").
  * Super Frenzy main hunts: more hard rooms (super_main_hard). The game's
    hard rooms (the horned door) are its harder fights with its bigger
    rewards: more Teffra, 2 Heart Shards, more materials and Corestones,
    better power odds. It shows few: about 1 in 6 fight doors with Hunt
    Rooms, mostly its Fabled doors. Now a step for each Party Gear Level above
    10 (the game's own number, on the map: everyone's weapon, helmet, body and
    legs, averaged; up to 15) and each Super Frenzy level above 1, up to 9
    steps. Each fight door that isn't hard becomes hard with a chance of
    steps / 9:
      Super Frenzy 1, gear 1-10   0 steps  the game's (about 17% hard)
      Super Frenzy 1, gear 13     3 steps  about 45%
      Super Frenzy 3, gear 12     4 steps  about 54%
      Super Frenzy 5, gear 13     7 steps  about 82%
      Super Frenzy 5, gear 15     9 steps  every fight room hard
    Read when the run starts (gear bought during the run doesn't change it).
    The roll is seeded from each room's own seed, so it's the same on every
    machine. Log: "Super Frenzy 3 main hunt (...): ..., party gear level 12:
    4 of 9 steps, 44% of the other fight doors hard".
  * Weapon power and friend gift rooms made hard (Super Frenzy side hunts,
    the main hunts' extra hard rooms; the game never has them hard):
    hard_power_rooms = true, and they give 35 more Teffra from the room's
    kills (hard_power_room_teffra; the game's Teffra for skipping a power),
    on top of a hard room's own Teffra. hard_power_rooms = false: they stay
    the game's (medium). Log: "a hard weapon power / gift room: +35 Teffra
    from its kills".
  * Weather side hunts (the game's anomalies) get Super Frenzy 1 to 5 too
    (super_side_hunts.weather): RB past Frenzy 5 on the map, the Super Frenzy
    panel, each level opening as the one below is cleared on that side hunt
    (one record per side hunt, with weather or without). The run is a Super
    Frenzy side hunt's (Super Frenzy enemies, every fight room hard, loot x1.5
    / 1.75 / 2 / 2.25 / 2.5, Hunt Rooms' extra rooms and Heart Shard room)
    with the weather, and each tier of the weather meter gives Frenzy 5's
    rewards (the game's 1 / 2 / 3, its top tier with a sure Heart Shard, + weather_bonus's one) x that loot
    multiplier, every one drawn from the tier's own bag: gems and Heart Shards
    too. A full meter at Super Frenzy 5: about 22 rewards instead of 9.
    Inside those rewards the loot multiplier stays out (their count is what's
    multiplied). weather = false: weather side hunts stop at Frenzy 5.
0.9.2: safety: the game's Corestone drop can carry at most 7 Corestones per
hunter (it sends the count in 3 bits; the game itself goes up to 6). The Super
Frenzy loot multiplier and the Super Frenzy side hunt boss (9 to 15) went past
that. Now such a drop keeps 7 and the rest comes as a second Corestone drop
right beside it (the game's Corestone room reward). Log: "a Corestone drop
past the game's limit: 1 more drop beside it".
0.9.1: safety: the boss's extra ingots and Heart Shards drop as loot only when
the game has that drop loaded (Hunt Rooms 0.3.0 crashed on a Corestone, which
has no loot drop); otherwise they're given the way the game's pickups do.
0.9.0: more for the harder choices (the user, 16:47: adding rewards and
options, not taking them away; "extra materials and corestones when the other
rewards are too compelling in comparison to compete"): weather side hunts at
Frenzy 5 get one more reward from each meter tier; Nimble's two challenges in
one run at Frenzy 5 / Super Frenzy give the game's own (switched off) bonus, a
power upgrade, a reroll and an extra life; side hunts you frenzy yourself: the
boss +1 to +3 ingots and +2 to +6 materials; repeat Super Frenzy main clears:
the boss 1 / 1 / 2 / 2 / 3 Heart Shards (fixed, not multiplied).
0.8.3: Super Frenzy side hunts end like Super Frenzy main hunts (user, 05:42:
"what does that mean?" / the plan): the side boss's end drop starts from the
game's Super Frenzy Corestones and ingots, 6 and 5, instead of Frenzy 5's 5
and 3 (only those two; the rest of the loot stays Frenzy 5's), then x1.5 to
x2.5: Super Frenzy 1 9 Corestones / 7.5 ingots, SF3 12 / 10, SF5 15 / 12.5
(Progression's x3 Corestones on top). boss_like_main = false in
super_side_hunts: Frenzy 5's. Also: Hunt Rooms 0.3.0's Heart Shard room
keeps its fixed Heart Shards (asks HuntRoomsAPI.ShardRoom; the game's shard
drop only).
0.8.2: main hunts at Super Frenzy get more loot with each level. The game
gives the same loot at every Super Frenzy level (its loot changes all come at
Super Frenzy 1); now it's x1.5 / 1.75 / 2 / 2.25 / 2.5 at Super Frenzy 1 to 5,
the same way as the Super Frenzy side hunts: corestones, monster and boss
materials, ingots, seeds and heart shards; not Teffra, not boss hearts.
Setting: super_main_loot = { loot = { ... }, teffra = false } (false = the
game's). The log: "[Frenzy Levels] Super Frenzy 3 main hunt (treemon_forest):
loot x2 (not Teffra)". Nothing else of the game's Super Frenzy changes.

0.8.1: Super Frenzy side hunt markers get the main hunts' Super Frenzy shield
(without the crown): images/frenzylevels_markers.
0.8.0: Super Frenzy 1 to 5 on those side hunts (the game's levels: traps,
start damage, prices too), each opening when the one below is won
(unlock_all = true for now), loot x1.5 to x2.5 by level, Teffra not
multiplied.
0.7.0: Super Frenzy on the side hunts you frenzy yourself (RB past Frenzy 5,
an experiment): Super Frenzy 1 enemies, every fight room hard, loot x1.5.
0.6.1: every Blight Incursion boss drops a mirage (the game: none).
0.6.0: Drakinspawn drop 4 Drakin pieces each (armour and weapon looks),
Tendy's quest fights too.
0.5.1: boss kills +1 1 2 2 3 (doubles the game's; was +1 to +5).
0.5.0: more corestones in the side hunts you frenzy yourself (anomalies have
their reward meter instead): boss +1 to +5 by Frenzy level, corestone rooms
and Teffra Zuccos +1 (+2 at Frenzy 4-5). corestone_bonus in the settings.
0.4.0: anomalies never go to Standard and keep the game's look; X on the map
switches the look of a side hunt you frenzied yourself.
0.3.3: the game's Frenzy look is back by default (frenzy_look = true); the
normal-colours option stays.
0.3.2: Frenzy 1-5 keeps the hunt's normal colours (the game's frenzy dusk made
every run look like night): frenzy_look.
0.3.1: cosmetic armour on every boss at Frenzy 5 and in Super Frenzy (100%).
0.3.0: side hunts get the level picker too (No frenzy to 5).
0.2.0: cosmetic armour drops more often (10-50% by Frenzy level, 55-75% in
Super Frenzy).
