Save States 0.5.1 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.
==================================

Save the run you're in with a key, and rebuild it later with another key:
that room of that run, HP, Teffra, potion charges, every power with its rarity,
stacks and counters. Your character's progression is never touched.

Keys (all in scripts/savestates_settings.lua)
---------------------------------------------
  Ctrl+1 .. Ctrl+0            save to slot 1 .. 10
  Ctrl+Shift+1 .. 0           load that slot: Rebuild
  Ctrl+Alt+1 .. 0             load that slot: Replicate
  Ctrl+L / Ctrl+Alt+L         load the latest auto save (slot 0): Rebuild / Replicate
  Ctrl+Shift+Alt+1            the history tabs (Manual history, Auto history) in
                              an open Codex, on / off; with none open, Saved
                              Hunts with them (the game's debug UI menu instead
                              when the game has that UI)
The modifiers match exactly (Ctrl+Shift+1 is not Ctrl+1). With the game's debug
keys on, Ctrl+1 .. Ctrl+4 would also set the debug menu's text size: the mod
keeps those presses to itself (keep_debug_text_size).
The keys do nothing while you type (the console, the menu's note).

Saved Hunts (the Codex at the camp's entrance)
-----------------------------------------------
The Codex has a Saved Hunts tab (the game's save icon), first in its row, so the
Codex opens on it:
  left       every slot, named after its region with the region's ornament
             ("1: Great Rotwood Forest"), then the latest auto save
  top        the hunt's shield (the map's badge for that hunt: main or side
             hunt, Frenzy, Super Frenzy, with the hunt's icon) on the badge's
             grey wings, the region's ornament on both sides, the hunt's name
             and its Frenzy level
  players    each player: the two weapon classes around "P1" (the one in hand
             on the left), the character's name, HP, extra lives, Teffra,
             rerolls, potions left, the run's powers the HUD shows (the game's
             icons, with their counters and tooltips)
  bottom     the room's icon (the dungeon map's own: a fight shows its reward,
             a boss room its boss), the room (number, kind, reward), the Blight
             part, when it was saved, its note
  order      each player sees his own summary first: on P2's Codex, P2 then P1
             (the same pairing the load uses)
  LOAD       closes the Codex and loads it (Rebuild). If your weapons differ
             but the saved ones can be put on, it says so and loads Replicate.
  LS / RS    (gamepad) loads the save shown with Replicate (LS) or Rebuild
             (RS), whatever LOAD would do; it says why if that mode can't.
  Swap P1 / P2  (2 players, Y on a gamepad) the save's player 1 goes to
             today's player 2 and back, for when the characters came in the
             other order. It says when they look swapped, and who gets whom.
  history    two hidden tabs, Manual history and Auto history (every save kept,
             newest first; LOAD as usual): Ctrl+Shift+Alt+1 or both triggers
             (LT + RT) show / hide them in that Codex. No Codex opens with them.

The pause menu: SAVE HUNT (in a run) / LOAD HUNT (in town), next to Manage
Multiplayer. The Codex opens on Saved Hunts (the game stays paused):
  in a run   slots 1-10, the empty ones too: SAVE TO SLOT n / OVERWRITE SLOT n
             puts this room there (it says when you can't: a Blight rest room);
             below them the latest and the 20 newest auto saves, which LOAD
  in town    the slots, the latest and the 20 newest auto saves, LOAD
The keys work the same while it's open (a key save shows in the list).
             A save that can't load says why and the button can't be pressed.
A slot's page is drawn once and kept while the Codex is open (6 at most), so
moving through the list is instant; a slot the cursor only passes over isn't
drawn (it waits 0.15 s), a click draws it at once.
Mouse: click a slot, then LOAD. Gamepad: A on a slot goes to LOAD, A loads, B
goes back to the list. codex = false turns the tab off, codex_tab_first = false
puts it last. If a game update changes the Codex, the tab stays out (logged).

The full-screen Saved Hunts (experimental, 0.4.0)
-------------------------------------------------
With pause_menu_screen = "full" (the default) the pause menu's SAVE HUNT /
LOAD HUNT opens one full screen for everyone instead (not one per player, even
in co-op), in the pause menu's own look and with no header:
  top left   each saved player on one line: the weapons around P1, the
             character, HP, extra lives, Teffra, rerolls, potions (the HUD's
             icon), the run's powers (the game's icons and tooltips)
  middle     the saved hunt's map: the pause menu's own map (the rooms walked,
             the room you were in, the boss, the weather, the tally, the title
             with the Frenzy level), drawn from the save's map data. A save the
             map can't be drawn for shows the hunt's shield, name and Frenzy.
  bottom     the room's icon and line, when it was saved, the note
  right      the saves in the pause menu's Hunter's Path frame: slots 1-10 (in
             a run the empty ones too), the latest and the 20 newest auto saves
  buttons    CLOSE, SAVE TO SLOT n / OVERWRITE SLOT n / LOAD and the line about
             it, CODEX VIEW (closes this, opens the Codex's Saved Hunts)
An empty slot (in a run) shows this room as it would be saved. The controls are
the Codex view's: A picks (and goes to the button), LS / RS load Replicate /
Rebuild, Y swaps P1 / P2, B goes back to the list (then closes), the pause key
closes; LT+RT (keyboard: hold Z, press C) or Ctrl+Shift+Alt+1 show the hidden
history lists (Saves / Manual history / Auto history: LB / RB, Q / E, or click).
The game's map reads the dungeon you're in. For a save it's drawn with a
stand-in: for that moment TheDungeon answers with a copy of the save's map
(read by the game's own WorldMap / MapGenRun code) and everything else from the
real dungeon, which is back right after, an error too. Nothing is written.
The map is the same size for every save; only more than two players' lines'
worth (lots of powers, 3-4 players) makes it smaller. LOAD closes this screen
and the pause menu, then loads the save you clicked.
pause_menu_screen = "codex": the Codex view, as before. If the full screen
can't open (a game update), the Codex view opens and the log says why.

Slots and history
-----------------
  Slots 1-10      yours. Slot 0 is the auto save: you can't save to it.
  Auto save       every room you enter (a second after it starts) goes to slot 0
                  and the auto history (the last 100 rooms).
  Manual history  every manual save (the last 1000). Overwriting a slot keeps the
                  old save here.
  Undo            your state just before each load goes to the auto history.
  The menu        load anything from either list, copy an entry to a slot (an
                  auto entry becomes a manual one), pin one (never deleted), add a
                  note, delete. It's a panel of the game's debug UI, which the
                  normal game doesn't allow: then the console commands below do
                  the same jobs.

Console commands (the game's console; nothing runs until one is typed)
----------------
  ss_list()               the newest 15 saves of both histories, with their numbers
  ss_list(40, "auto")     40 of the auto history ("manual", "auto" or "all")
  ss_slots()              what's in slots 1-10 and slot 0
  ss_load(123)            load save #123 (Rebuild); ss_load(123, "replicate")
  ss_undo()               back to before the last load (its "before loading" save)
  ss_slot(123, 4)         put save #123 in slot 4 (Ctrl+Shift+4 then loads it)
  ss_pin(123), ss_unpin(123)   a pinned save is never pruned
  ss_note(123, "text")    a note on a save
  ss_delete(123)          delete a save (not a pinned one: unpin it first)
  ss_help()               this list
Files: the game's saves folder, savestates\ (one small file per state).

What a load brings back
-----------------------
Rebuild (your own gear; each player needs the saved 2 weapon classes, in any
order, or the load is refused with the classes it needs):
  the run       place, map (Hunt Rooms' longer maps too), seed, room, the rooms
                before it and the doors ahead, fights, shop stock, weather,
                the Frenzy level, anomaly or not
  the Blight    its legs, stage and the earlier legs' results
  you           HP (the same number, up to your max), Teffra, every power the
                run gave (relics, weapon powers, Fabled, curses) with rarity,
                stacks and counters, rerolls left, the run's counters on your
                talents and gear (extra lives left, starting Teffra taken, skill
                charges), potion charges (full stays full, empty stays empty,
                in between the same share: Bubbling Brew 1 of 2 -> 1 of 1),
                tonic uses
  the mods      Hunt Rooms' room counts, Two Weapons' memory (the weapon in hand
                is the saved one: its swap)
Replicate: all that, and the saved gear: weapons (level, gems, mirage), armour,
  potion, tonic. Gear you own is used as it is (yours is never changed); gear you
  don't own is given with its saved state. When the run ends (back in town) your
  own gear goes back on. replicate_lend = true (experimental): what was given is
  taken back then too.
Not brought back: the room's enemies and floor items (the room starts again with
  its fight; a reward you already took drops again), powers your own gear gives.

Never touched
-------------
Materials, gifts, corestones, heart shards, inventory, weapons, weapon levels,
armour and its levels, gems, unlocks, mirage, loadouts, talents, masteries.
Each load builds your character's data from your OWN current file with only the
run parts swapped in, and checks every other part is identical before writing
it; anything else and the load is refused.

How a load works (one loading screen, from town or any run)
-----------------------------------------------------------
 1. everything is checked first; a refused load changes nothing
 2. your state now goes to the auto history (undo)
 3. Replicate: the saved gear is put on
 4. the game's own run start, with the saved place, seed, map, Frenzy level and
    weather (the Blight: its saved legs first): the game tells everything "new
    run", builds the map and writes the run file and each player's file
 5. just before it loads the first room: the saved map goes into the run file,
    each player's file gets the saved run parts (with the same gear's powers as
    in the save: those too, as saved), and the saved room loads instead of
    room 1
 6. after the load, once the players are in the saved room: your potion's
    charges, the saved HP again (after the room's own "on entering" effects),
    a note, then the room's auto save. Only in the saved room: anywhere else
    your charges and HP stay as they are (the note says so)
If a step fails: before step 4 nothing changed (refused); at step 5 nothing of
the mod is written and the game's own first room of the new run loads; your
state before the load is always in the auto history.

Blight rest rooms can't be saved (the game keeps no run map there); the next
leg's first room saves itself.

Local co-op: every local player is saved, matched by player number. A different
number of players than the save: refused. Only the host can load.

Changes
-------
0.1.0  first version
0.1.1  console commands for the menu's jobs (ss_list, ss_slots, ss_load, ss_undo,
       ss_slot, ss_pin, ss_unpin, ss_note, ss_delete, ss_help): the menu needs
       the game's debug UI, which the normal game doesn't allow
0.1.2  loading works from any moment: 0.1.1 wrote the "before loading" label
       with your HP as a whole number, and mid-fight HP can be a fraction
       (412.5), so the load stopped ("bad argument #2 to 'format'") before
       anything changed. The same label is on every save, so manual and auto
       saves at such a moment failed too; now the numbers are rounded.
0.1.3  potion charges and HP are set in the loaded room. After the reload the
       game spawns the players before Save States reads its file and lists
       them a moment after, so the last step never started there; it ran at
       the next door instead, with the save's charges and HP (potions drained
       walking into a mystery room). Now it waits for the players (30 s at
       most), and never sets charges or HP in another room.
       No free potion charge at each load: the run start clears your gear's
       powers and the game added them again at the reload, so their "when you
       get it" part ran again (a Perfect Pairing gem gave a charge back with
       the refill animation and sound; gear counters started over). With the
       same gear's powers as in the save they now come back as saved.
0.1.4  Saved Hunts: a tab in the camp's Codex to see every slot and load it with
       a big LOAD button (see Saved Hunts above). Built from the Codex's own
       pieces (its tab group, list buttons, slot panel, the exploration badge's
       wings, the game's power icons and primary button). New saves remember
       their hunt for the list (older ones: read from their line).
0.1.5  Saved Hunts: every slot showed "This page had an error" and left the
       hunt's shield in the middle of the screen. The header measured the
       badge with a picture made for that and removed again; the game can't
       remove a picture that was never placed on a page (an error), and a
       picture with no place is drawn in the middle of the screen. It now uses
       the badge's known size (200 x 200). The test engine now refuses that
       remove like the game, and checks no picture is left off the page.
0.1.6  Saved Hunts: hunts with lucky_revive or shield (powers the HUD hides)
       left a white square with a hexagon in the middle of the screen, one
       more each time the slot was shown: the game's power icon refuses a
       power with no icon half way through. Those powers are left out like
       the HUD does, and a game widget that fails half way is removed again.
       Smoother: each slot's page was drawn again every time the cursor passed
       over it (dozens of power icons); now each is drawn once and kept, and
       only once the cursor stays on it. Layout: the players' rows sit in the
       middle under the top band (they were off to the left, P1 under the
       band), the line over LOAD no longer covers the room line, long region
       names shrink to fit the list, the HP icon is tinted, dividers between
       players, the shield is the map's badge art with the hunt's icon in
       black. Kills and damage taken out.
0.1.7  Saved Hunts: the right ornament in the top band sat on the hunt's
       shield. It's mirrored, and the game lines a mirrored picture up by its
       edges taken back to front, so it landed one width short. It's now
       mirrored inside a holder that isn't, and the holder is lined up.
       Hovering powers no longer jumps: the game's power tooltip picks its
       side before its keyword box shows, so it opened on the right, then
       jumped left over the list, and came back each time the cursor crossed
       the gaps between icons. Each tooltip now opens on one side (towards
       the middle of the screen) and the icons sit 2 apart instead of 6 (their
       hit box is smaller than their art, so the gaps were holes).
       A smaller LOAD button and less room kept for it. The potion shows the
       HUD's potion picture (empty when none are left), not the inventory one.
0.1.8  Saved Hunts: a long hunt name ran over the end of the top band: the
       room for it was worked out with a guess of the ornament's width (they
       are wider than tall). It now measures the wings and the ornament and
       keeps clear of the band's slanted ends; the ornaments are a bit
       smaller. The LOAD button is smaller again, and its text is the game's
       button text as is (it was resized, so it looked thinner than the game's
       buttons): made like the Codex's own Replay button.
0.1.9  Saved Hunts: the stats row is straight. Each icon picture has its own
       empty border (the HUD's potions most of all), so lining up the
       pictures left the art crooked. Now every icon's visible art (measured
       from the game's own pictures) is the same height and stands on the
       numbers' bottom line, with the same gap between every stat. The hunt's
       name in the top band is bigger again (0.1.8 kept too much room free).
0.1.10 Saved Hunts: stats row tweaks. Icons whose lowest pixels are thin
       tips or a corner looked like they floated: the lives' wings, the dice
       and the heart sit a little lower so their body rests on the line
       (Teffra as it was). The potion is a quarter bigger and a little lower.
       The numbers stay on one line whatever the icons do.
0.1.11 Saved Hunts: the hunt's shield in the top band is a quarter bigger
       (the wings and ornaments as they were), closer to the Codex's own badge.
0.2.0  Saved Hunts: each player sees himself first (on P2's Codex the saved
       P2 comes first, then P1), by the same pairing the load uses (player
       number order; by player number when the count differs). The room line
       has its icon from the dungeon map (the game's own choice and art,
       tinted like the hunt's map). The HUD's potion picture is
       drawn twice as big (its art has a wide empty margin).
0.3.0  Saved Hunts: LS / RS load with Replicate / Rebuild (LOAD as before),
       Swap P1 / P2 for 2 players (Y), the pause menu's SAVE HUNT (a run: save
       and overwrite slots 1-10) / LOAD HUNT (town) opening the Codex on Saved
       Hunts with the 20 newest auto saves under the slots, and the two hidden
       history tabs (Manual / Auto history) on Ctrl+Shift+Alt+1 or both
       triggers: the old debug UI menu's archive, since the game has no debug
       UI here.

0.3.1: the pause menu's SAVE HUNT / LOAD HUNT button fades and slides in with
the menu's other buttons (it was there at once while they came in): the game's
own button animation, started with theirs. If that ever fails, the button just
shows where it belongs.
0.3.2: Swap P1 / P2 has no button any more: Y on a gamepad does it (the hint at the
bottom says "Swap P1 / P2", "Swapped P1 / P2" once it's on, and the line above
LOAD says who gets whom).
0.4.0: the full-screen Saved Hunts (experimental; pause_menu_screen = "full", the
default; "codex" for the Codex view): one screen for everyone with the players
on top, the saved hunt's map (the pause menu's own, drawn from the save), the
room, the saves on the right in the Hunter's Path frame, SAVE / OVERWRITE /
LOAD, CODEX VIEW, the same controls and hidden history lists. An empty slot shows
this room as it would be saved. The Codex view: a slot's page now comes when the
cursor stays on it over the pause menu too (the 0.15 s wait was the game's
clock, which stands still while paused: it's the UI's clock now).
0.4.1: LOAD (full screen and Codex view) loads right away from the pause menu:
the pause menu closes too, so the game runs (0.4.0 / 0.3.x: the load waited
until you closed the pause menu yourself, and pressing LOAD again meanwhile
queued another load, the first one winning). Now the latest press is the one
that loads, once. LOAD always loads the save you clicked: moving the mouse over
other saves on the way to the button showed theirs and LOAD took the one shown.
The full screen's map is the same size for every save (it was measured with its
rooms drawn, so a hunt further on, or its boss icon, made it smaller); room is
kept for two players' lines and three lines under the map, so only more players,
lots of powers or a long note make it smaller.
The Codex view: hiding the history tabs while one of them was open, then LB /
RB, gave the game's error screen (the tab row still pointed at the removed
tab): the tab row goes back to Saved Hunts first now.
0.4.2: a load fades the screen to black first, the game's own fade, as long as
the start of a run takes (half a second), then the hunt loads. If the load
stops after that, the screen fades back in. fade_load = false in
savestates_settings.lua: no fade.
The full screen's map: the same size and spot for every save, on every load
and save (0.4.1 still measured the drawn map, which changed with what it showed:
now it's sized by its paper border, the same picture on every map).
0.5.1: fix: with no saved hunts, the Codex's Saved Hunts tab (the one it opens
on) left nothing focused, so the gamepad could do nothing (user 18:40: "codex
softlocks you"). An empty list now puts the focus on the Codex itself (the
game's own fallback), so the tabs and back work. Same while the list loads.
0.5.0: a load gives the saved room its own enemies (user, 00:20: "when you
load a room, it loads a different version of that room, but loading it again
loads the exact same room version the first load loaded"). Not meant: the
game draws a room's enemies from the run's encounter deck when the room
starts, and a save is always taken after that draw, so the saved deck had
this room's card used already. A load drew the next card (other enemies,
another special encounter or Frenzy extra), and every load of that save the
same next one (the same deck, the same room seed). Now the room's draw is
noted by name (encounter, special encounter, extra) and saved with the run;
the reloaded room gets that card again without a new draw. The deck stays as
saved, so the rooms after it draw what they drew in the run, and a load
doesn't move the special encounter counters in your character file. Anything
that doesn't match (another room or seed, a name the game no longer has, an
error): the game's own draw, and the load's note says why. Saves from before
0.5.0 have no note: their room is drawn again (the note says so).
same_room = false in savestates_settings.lua: every load draws again.
0.4.4: the full screen's player lines in columns (user, 22:08: "I want this
always aligned"). Every line, every save the same: the two weapons and P1 in
their places (an empty place when there's no second weapon), the name in its
own width (a long name drawn smaller to fit, the game's ShrinkToFitWidth; a
short one with room after it), then HP, extra lives, Teffra, rerolls and
potions, each in its own column and always shown: 0 when the player hasn't
got them, the HUD's plain potion when there's no potion. A column is as wide
as its widest number (or wider for a bigger number). Only the drawing: the
saves and runs are untouched. align_players = false: the lines as before;
if the columns can't be drawn, the line as before (logged).
0.4.3: the full screen's map is locked in place and bigger. Its place comes
from the screen alone: left of the saves (24 short of their frame), under two
players' lines, over three lines for the room (0.4.2 went by what each page
held, the room line's box above all, so a save with a taller room icon put
the map about 20 pixels higher). It now reaches across to the saves' frame:
0.4.2 kept room for the paper's roll past the border, but the roll sits inside
it, so that strip was left empty. The room line starts right under the map at
the same height on every save. Only a save with more players' lines than two
(3-4 players, lots of powers) moves its map down to make room.
