Blight Fix 0.2.1 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

What it fixes
  In a Blight Incursion, a two-stage leg has two portals. Take the second one
  and the game remembers "stage 2". When that leg's boss dies, the game moves
  to the next leg (a Rest Room, which has only one stage) but keeps "stage 2":
  the log shows "Selecting leg 4-2 (Rest Room)", then a bit later
  "Updating current stage id to 1" / "Selecting leg 4-1 (Rest Room)".
  Both crashes happened right after that, loading that Rest Room. The first
  Rest Room (after leg 1, stage 1) loaded fine both times.

  With this mod the game gets stage 1 for a one-stage leg straight away. The
  log then shows "Selecting leg 4-1 (Rest Room)" with this line before it:
    [Blight Fix] leg 4 has 1 stage(s) but stage 2 was carried over from the last leg: using stage 1
  Two-stage legs still use the portal you pick.

The Blight's purple overlay
  The game puts a purple picture over the whole screen everywhere in the
  Blight except the Rest Rooms (the game's own, not a bug), pulsing between
  65% and 100%. Here it's faded to 10% of that by default, and Ctrl+B cycles:
    faded (10%)  ->  the game's own  ->  off  ->  faded ...
  A short note on screen says which. It changes right away, and the choice is
  kept for the next rooms and the next game start (a small file,
  blightfix_overlay.txt, in the game's save folder). Not while the console is
  open; exactly Ctrl+B (Ctrl+Shift+B does nothing). With the game's debug keys
  on, Ctrl+B no longer toggles their AABB drawing.
  How: the game's own overlay and its own pulsing stay; the overlay widget
  gets a colour alpha (0.10, 1, or hidden with the pulsing stopped for off),
  and the game's widget code multiplies it in. Nothing runs per frame that the
  game doesn't already run (off runs less).
  Settings (scripts/blightfix_settings.lua):
    overlay = "faded"      the start: "faded", "vanilla", "none", or false
                           (this part off: the game's own, no key). Changing
                           it starts over from the new value.
    overlay_faded = 0.10   how strong faded is (0 .. 1)
    overlay_key = "Ctrl+B" the key ("Ctrl+Shift+F8" style; false: no key)
    overlay_note = true    the note on screen
  Safety: its own part (an error leaves the game's overlay for that room,
  logged; the stage fix goes on); it checks the game's HUD at the game's
  start and stays off (the game's own) if the overlay code changed.

Turning it off
  scripts/blightfix_settings.lua: enabled = false (the whole mod: the game's
  own way; the log says "[Blight Fix] off (enabled = false in
  blightfix_settings.lua)"). overlay = false turns off only the overlay part.

Testing it fast (debug console, ` key)
  d_starttrek()                                  new Blight run, leg 1
  d_nextleg(1, 2)                                leg 3, second portal
  TheDungeon:PushEvent("dungeoncleared", {})     leg 3 counts as beaten
  then walk both players into the portal that appears: the Rest Room loads.

0.1.x: the stage fix.
0.2.0: the Blight's purple overlay: faded to 10% by default, Ctrl+B cycles
faded / the game's own / off, kept between rooms and game starts.
0.2.1: overlay_key = false (or another key) set while the game runs: the
earlier room's Ctrl+B no longer cycles the overlay or keeps Ctrl+B from the
game's debug keys (the key handler and the debug-key wrap kept from an earlier
room now ask the Blight Fix loaded now).
