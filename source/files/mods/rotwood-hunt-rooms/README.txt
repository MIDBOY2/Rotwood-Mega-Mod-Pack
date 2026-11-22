Hunt Rooms 0.3.3 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

More legendary weapon power rooms and more Fabled rooms, and the Blight's
miniboss in every middle part; every other room is the game's (Teffra,
markets, the meta room, potions, upgrades and mystery rooms at the game's own
odds).

What each hunt gets:
  Every hunt     The start room gives its own pick (a normal power, or the
                 Fabled of main hunts and the Blight), then a legendary weapon
                 power choice. With Two Weapons: one for each of your two
                 weapons. A start that already is the weapon power room (the
                 game's roll) stays as it is.
  Side hunt      The start only.
  Side hunt, Frenzy 1-5 (anomalies too)
                 +1 room: its doors offer a Fabled, a weapon power or a normal
                 power (one of each at most).
  Side hunt, Super Frenzy 1-5 (Frenzy Levels)
                 +1 room per Super Frenzy level, the same kind of room.
  Main hunt      The start only.
  Main hunt, Frenzy 1-5
                 A 25% chance a door choice gets one of its normal power,
                 corestone, gift or material doors turned into a Fabled or
                 weapon power door, the hit half on normal powers, half on the
                 others.
  Main hunt, Super Frenzy 1-5
                 Corestone, gift and material doors come about half as often
                 (the half become Fabled or weapon power doors) and give twice
                 their reward; a few normal power doors too.
  The Blight     +2 rooms in each of its two long middle parts, offering
                 Fabled or weapon power doors (a normal power once both are
                 used up). At most 2 weapon power rooms in one part, the
                 game's own counted (the start's choice in the first part):
                 past that, that part's weapon power doors are normal power
                 doors.
                 Its miniboss (a Fabled pick, the only Fabled the game has in
                 the middle parts) in each middle part, never beside a Fabled
                 or weapon power door: see 0.2.1.

Never two weapon power rooms in a row (the start's choice counts as the
start room's): a weapon power door right after one is a normal power door,
an extra room's door a Fabled or a normal power one (weapon_power_gap: the
rooms between, at least; 1).

Weapon power doors show up a set number of times, the start's choice not
counted: 2 in a side or main hunt, 3 over a whole Blight (the game's own: 1
and 2). Each one counts the moment it's offered, taken or not: skip it and
it's gone. The game's own weapon power doors count too; past the number they
are normal power doors. So at most 3 weapon power rooms in a hunt and 4 in a
Blight with the start's choice (2 and 3 without it). Unfrenzied side and main
hunts get no extra rooms, so there it's the start's choice and the game's own.

The most a run gives on top: 3 Fabled rooms on top of the game's own (its
start room, minibosses and own Fabled doors don't count); never more than 4
weapon power rooms in any run.

The miniboss (a main hunt's room 9, the Blight's middle parts), 0.3.0: its
Fabled pick shows 4 Fabled powers (2 from each of the run's families) and
the normal power. And each player gets, on top of what it gives already:

  level           Corestones  ingots  area materials  Teffra
  Normal               1         0          1           +10
  Frenzy 1-5        1,1,1,1,2  1,1,2,2,3  1,1,2,2,2   +14 +18 +22 +26 +30
  Super Frenzy 1-5     2         4          3         +34 +38 +42 +46 +50
  the Blight           2         3          2           +30

(Frenzy Levels' Super Frenzy loot multiplier and Progression's pickups apply
as to any drop; Teffra as the game's.)

The run's Fabled families, 0.3.0: never Shield + Summon, Electric in 75% of
runs (Electric + Shield / Summon / Frost 25% each, Frost + Shield / Summon
12.5% each). The game's pick otherwise (its random generator, saved with the
run, the same over a whole Blight); the normal powers linked to the Fabled
you hold follow on their own.

Super Frenzy side hunts (Frenzy Levels), 0.3.0: a Heart Shard room among
the extra rooms' doors, 40 / 45 / 50 / 55 / 60% each extra room by level,
offered until you walk into one (then not again that hunt). It gives each
player 1 / 2 / 3 / 4 / 5 Heart Shards (a fixed number). On the game's map
code it's offered in about 34 / 64 / 78 / 92 / 98% of those hunts.

All the numbers: scripts\huntrooms_settings.lua (save, restart the game).

How it stays the game's:
  * The game rolls every room first, its own way. A door changed here keeps the
    game's roll, and the game counts the room by that roll when you enter it,
    so the rooms after it come at the game's odds. The extra rooms are kept
    aside from the game's counters altogether.
  * Never touched: Teffra, market, miniboss, meta-reward, potion, upgrade,
    mystery and boss rooms, the start room and room 2. (The Blight's
    miniboss is the one exception, 0.2.1: one door of a middle part that
    hasn't shown it becomes it, the game's own miniboss room.)
  * The longer side hunts are copies of the game's frenzied side hunt map with
    the extra rooms between the game's own; the game's map stays as it is.
    The copies are added at the end of each side hunt's map list, so the
    game's entries (and runs saved before) keep their numbers.
  * The pause screen's map gets paths for the new lengths.

Safety:
  * Each part checks the game functions it needs at load and stays off (the
    game's way) if one is missing; the others go on. The log line at load says
    what's on and why anything is off.
  * Every hook calls the game's own function, and the mod's part inside a
    protected call: an error turns only that part off for the session
    (logged), and the game's result stands.
  * A room the map has no odds for (a run saved with other settings): the
    map's last odds instead of the game's assert.
  * A bad setting falls back to its default (logged).
  * Install or remove it between hunts, not in the middle of one.

Console commands for testing (the game's console; nothing runs until one is
typed, they're only defined):
  hr_help()               the list
  hr_doors()              this room and its doors: what each gives, what Hunt
                          Rooms changed ("was ..."), whether the next room is
                          an extra one, and the run's counts against the caps
  hr_start("treemon_forest_r1", 3)
                          a hunt at a level, as if picked on the map: 0 none,
                          1-5 Frenzy, 6-10 Super Frenzy 1-5 (side hunts: Frenzy
                          Levels' Super Frenzy side hunts); a third number is
                          the seed. The level is stored first: the game picks
                          the run's map from the stored level before it stores
                          the new one, so d_startrun alone with a new level gets
                          the old level's map (and no extra room). A Blight
                          left running ends first, as with d_startrun.
  hr_again()              this hunt again on a new map: the same place, Frenzy
                          level, map and weather (one console line per new run)
  hr_again(12345)         ... on that seed's map (the same seed, the same map)
  hr_sim()                this hunt's map played 1000 times on the game's own
                          map code with every mod's hooks: the odds in the log
                          (weapon power rooms, Fabled rooms, the caps, the extra
                          rooms and their doors, every reward and room kind)
  hr_sim(5000, "any", 7)  5000 runs taking any door, seed 7 ("takes", the
                          default: weapon power doors first, then Fabled, then a
                          normal power). The same seed gives the same numbers.
  The sim never touches your run: the network's room record (the map and the
  doors read it) gets a stand-in for the sim's length and is set again from
  your run after; Hunt Rooms' run record is a sandbox; the map log is muted;
  an error in the sim is shown and never turns a part off for the game. It
  needs a hunt (its first room is enough), the host, at most 10 seconds.
  In the Blight it plays the part you're in, on its own.

Log lines start with [Hunt Rooms] in client_log.txt; debug = true in the
settings logs every room it changes.

Works with Two Weapons (a choice for each weapon in every weapon power room)
and Frenzy Levels (its Super Frenzy side hunts get their rooms here).
The heart shard masteries count as before (the hunt, its events and its end
are the game's; a longer hunt still ends at its boss).

0.1.0: the first version: the room parts that were in Two Weapons 0.9.9, split
out and rebuilt so the game's own rooms keep the game's odds.

0.1.1: hardening after a longer stress test (saved and continued at every room,
whole Blights with Blight Fix, forced errors, 300 random settings):
  * the door changes and the run's record are separate parts from the game's
    counters: if one of them fails, the game's counters still see the game's
    rolls, and an extra room then offers a normal power (never Teffra)
  * every fight room hard (Frenzy Levels' Super Frenzy side hunts): an extra
    room's two normal power doors both stay hard (Frenzy Levels' own rule)
  * the Blight's middle part map: every table of it gets its rooms

0.1.2: console commands for testing: hr_help(), hr_doors(), hr_start(),
hr_again(), hr_sim() (above). Nothing else changed.

0.3.3: with Frenzy Levels 0.10.0's hard rooms (Super Frenzy main hunts by
party gear level, Super Frenzy side and weather side hunts): a door it made
hard stays hard when a door here becomes a Fabled or weapon power one (the
game's rule keeps weapon power doors medium; Frenzy Levels' hard_power_rooms
decides now), and two alike doors aren't told apart by making one of them
easier. Without Frenzy Levels: the game's rule as before. Weather side hunts at
Super Frenzy (Frenzy Levels 0.10.0) get the Super Frenzy side hunts' extra
rooms and Heart Shard room.
0.3.2: the miniboss's Corestones are a real Corestone drop again (user 17:44-17:45:
0.3.1 added them straight to the inventory with no animation, and player 2's
Corestone counter went wrong: it arrived mid-fight while the game hides that
counter). When the miniboss room is cleared, the game's Corestone room reward
(what a Corestone room leaves: each hunter takes their own, with the
take-Corestone animation) appears next to the Fabled pick, with the miniboss's
Corestones. miniboss_corestones is at most 5 (the game's limit for one drop).
0.3.1: fix: killing a miniboss crashed the game ("Failed to spawn prefab
'drop_konjur_soul_lesser'", 17:25): 0.3.0 put the miniboss's extra Corestones in
its loot, and the game has no Corestone loot drop. Now they're given the way
the game's Corestone pickups give them (straight to each hunter, the pickup
popup). The ingots drop as loot only when the game has that drop loaded;
otherwise they're given the same way.
0.3.0: the miniboss, the run's Fabled families and a Heart Shard room (user,
05:32-06:05: "can it never be shield and summon ... high chances of
electric"; "choosing between 3/4 fable powers after a mini boss feels more
rewarding"; "mini boss rewards will be a core stone per player ... + the
materials needed to upgrade their mini boss weapon", "10 Teffra per player
... going to 50 in super frenzy 5", "on top of what it already gives"; "a
heart shard room in the super frenzy side hunt ... 1-5", "could be offered
more than 1 time but if you walked in ... it wont be offered again").
  * the run's 2 Fabled families (fabled_never_pair, fabled_favour,
    fabled_favour_share): picked right after the game's own pick, with the
    game's random generator, from the families the game tags "fabled"; an
    unusual pick or an error leaves the game's.
  * the miniboss's Fabled pick (miniboss_fabled = 4): in a miniboss room
    the game's shared Fabled pick asks for 4 Fabled powers instead of 2
    (the game's own round over the families: 2 each), the normal power as
    before. Two Weapons' Fabled fill and every other caller: as asked.
  * the miniboss's rewards (miniboss_rewards and its tables): when it dies,
    each player gets Corestones and ingots in its own loot (the game's
    lootdropper), the game's materials room roll for a few materials, and
    the game's Teffra drop, by level; once per room; not a side hunt's boss
    (a miniboss used as the boss); no ingots or materials where the game has
    none (Tefframech).
  * the Heart Shard room (shard_room, shard_room_shards): the game's shard
    room (the Blight's) as an extra room's door in Super Frenzy side hunts,
    in place of its normal power door (else weapon power, then Fabled), in
    door choices of 2 doors or more; walked into: recorded with the run, no
    more that hunt. Its drop gives each player the Super Frenzy level's
    count (Frenzy Levels 0.8.3 leaves those Heart Shards unmultiplied:
    HuntRoomsAPI.ShardRoom).
  * hr_doors shows the run's Fabled families and the Heart Shard room.
0.2.1: the Blight's miniboss in every middle part, never beside a Fabled or
weapon power door (user, 03:59: "not compete means you never choose between
miniboss and fable / weapon power door. Always offer a mini boss to get
fable ... the only change should be to blight"). In the game the Blight's
middle-part miniboss is just one of the room kinds it rolls for rooms 3-9,
once at most: about 1 part in 7 never showed it (2% of Blights neither, 26%
one), and 5% of the time it came beside a Fabled or weapon power door. Now
(blight_miniboss = true): the game rolls first (its own miniboss, its own
room 4 chance); a middle part that hasn't shown it by its room 5 gets it at
the next door choice with a door to give it (a normal power door first, then
another fight door; never Teffra or a market; a one-door choice only in the
last three, then it's the way on as in a main hunt's room 9; the part's last
choice can give a Teffra, potion, upgrade or mystery door when there's no
other). It's the game's own room (MapGenHelp.CreateRoomGenState with the
miniboss as the room kind: its layout, its Fabled reward, hard), counted by
the game's own counter so it never comes twice. A door choice with the
miniboss has its Fabled and weapon power doors made normal power doors (not
counted as weapon power doors shown). Main hunts (room 9 is the miniboss
only) and side hunts (no miniboss) as before. On the game's map code, 24000
middle parts: every one offered it (the game's own in 54%, by room 5 in 85%),
never beside one, never twice. A Fabled-first player: 5.97 Fabled rooms a
Blight (6 in 97%), was 5.69; the game alone 2.70. A weapon-power-first one:
4.83 Fabled (was 4.47), weapon power rooms 3.97 (3.99).
0.2.0: weapon power doors show up a set number of times (user, 03:06: "there
is a difference between having 3 rooms appear per Blight and a limit of 4
powers where the game keeps offering it until you have 4"; 03:19: "4 at the
Blight with the start's choice on, 3 when off", anywhere across it). Before,
weapon power doors kept coming until you'd taken 4 weapon power rooms (skip
one, another came). Now weapon_power_doors = 2 per side or main hunt and
weapon_power_doors_blight = 3 per Blight, the start's choice not counted; a
door choice showing one uses one, taken or not, and past them the game's own
weapon power doors are normal power doors and the extra rooms offer Fabled
or normal powers. With the start's choice off, a start the game made a
weapon power room counts as one. On the game's map code: at most 3 weapon
power rooms in any hunt (frenzied side hunts 3 in 23% of runs, frenzied main
hunts 68%, Super Frenzy 72-98%) and 4 in a Blight; a player skipping weapon
power doors still sees at most 2 / 3. hr_doors shows "weapon power doors
shown x of y". (The base game: 1 a hunt, 2 a Blight.)
0.1.5: never two weapon power rooms in a row (user, 02:01: "weapon power
rooms still show too frequently (like 2 in a row) (after the first room) so
3"). The game's own weapon power room came, and right after it the extra
room's weapon power door (the extra room is kept out of the game's counters,
so the game's own wait between weapon power rooms didn't hold for it). Now a
weapon power door right after a weapon power room, the start's choice
included, is a normal power door (the game's roll kept for its counters); an
extra room's door Fabled or a normal power. weapon_power_gap = 1 (rooms
between at least; 2 for more room, 0 = no rule). On the game's map code,
many runs: two in a row went from 6% of frenzied side hunts, 13% of frenzied
main hunts and half the Blights to none; a frenzied side hunt has 3 weapon
power rooms in 23% of runs (was 29%), a frenzied main hunt 4 in 17% (was
28%), the Blight still 4. Also: the run's weapon power rooms are counted by
the rooms entered (and the start's choice), not by the powers held (with Two
Weapons 1.0.7 a weapon can get two in one room). Runs started before keep
the old count.
0.1.4: the start's weapon power choice flies out with the crystal's split
sound (user, 23:27: the normal power's crystal had already shattered, so the
weapon power choice after it came out silent; Two Weapons' second choice
already had its sound). The game's two shatter sounds, once, from a player
(the game's code-sound way); the log line ends "with the split sound".
split_sound = false: none.
0.1.3: the Blight: at most 2 weapon power rooms in one part (setting
blight_weapon_rooms_per_leg; the game's own weapon power rooms count, and the
start's choice in the first part). A part could get 3 before. The whole
Blight's cap (weapon_power_rooms, 4) stays.
