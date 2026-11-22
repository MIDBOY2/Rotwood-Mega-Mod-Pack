Camp Saves 0.1.1 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

No more stutter every 10 seconds while you decorate the camp.

What the game does: every decoration you pick up or place marks the camp as
changed, and every 10 seconds the game then saves everything at once (each
local character, the camp, the other save files, the camp's room). On this PC
that's one frame of about 80-110 ms (the character file alone ~50 ms), again
and again while you decorate. The game itself waits 3 minutes on Switch "since
they cause hitching".

What this does: while anyone is in build mode (placing or picking up
decorations), those saves wait. They happen once, with the game's own save:
  * 2 seconds after you leave build mode (picking the next decoration right
    away doesn't save in between)
  * when the pause menu opens (quitting to the main menu from there saves
    nothing in the game)
  * after 3 minutes at most, even if you stay in build mode
A change made outside build mode (the game refunding a decoration at load,
another player) saves the game's way.

Not needed for the other ways out of camp: starting a run saves the camp's
room and everything else, and quitting the game saves all.

If the game crashed while you were decorating, you'd lose up to those last
minutes of decoration moves. The camp and your inventory always save
together, so nothing is lost or doubled.

Settings: scripts\campsaves_settings.lua (save, restart the game):
  wait_after_build_mode = 2, max_wait = 180, save_on_pause = true, debug.

Safety:
  * The game's own listener is found where the game puts it and swapped for
    this one; if it isn't there (a game update), nothing changes: the game's
    way, logged.
  * Any error turns the mod off for the session: what's waiting goes back to
    the game's own flag (saved at its next 10 s check) and the game's listener
    goes back on.
  * Zero cost outside build mode: nothing runs; a change, the end of build
    mode and the pause menu each do a few table reads.

Log lines start with [Camp Saves] in client_log.txt: one at load, one per
save ("saved 12 decoration changes (left build mode)").

0.1.0: the first version (found with Perf Probe's frame log: the stutters were
the game's decoration autosave, not a mod; the mods' data is under 1% of the
character file).

0.1.1: the pause menu save works (0.1.0 called assert in modmain.lua, which the
game's mod environment doesn't have, so that one part stayed off; the rest
worked). The tests now load modmain.lua in an environment like the game's.
