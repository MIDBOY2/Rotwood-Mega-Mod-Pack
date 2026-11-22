Fast Load 0.2.1 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Shorter loading screens with many mods.

Why loading got slower: every load (town <-> run) the game registers all its
prefabs again and finds each art file by trying every folder on its search
path, and every mod adds its folder at the front. So a file the mods don't
have costs one disk check per mod, for thousands of files. In your logs:
5.6 s a load with 8 mods, 8 s with 11, 10 s with 15.

What this does: lists each mod's folder once per load and answers from the
list. The same file is found in the same place (mods first, in the same
order); only the checks against mod folders that don't have the file are
skipped. A mod folder that can't be listed is checked on disk as before, and
any error falls back to the game's own search.

Log: one line per load in client_log.txt starting with [Fast Load], e.g.
"[Fast Load] 152000 mod-folder checks skipped, ..."

Quiet looks (0.2.0): fewer repeated art calls on characters.
Whenever a character's look is touched (equipping anything, a weapon swap, the
dodge afterimages, the HUD portrait, menu puppets), the game puts every armour
piece and body part back on, one engine call per symbol (Furry OC Generator
also clears every body part on each copy first). Some armour art writes
"Could not find anim build FROMNUM" to client_log.txt on each such call:
about a thousand lines a minute. Quiet looks skips the calls that would put
back exactly what a symbol already shows, and inside one look update a symbol
cleared and given the same art back gets neither call. The look is the same;
in tests with the game's own look code (and Furry OC's) after 600 random
changes it matched exactly at every step, with 87% fewer art calls and 93%
fewer of the calls that write those lines. What a symbol shows is trusted for
10 s at most; any build or override-build change forgets it.
Log: one line a minute, "[Fast Load] look art calls (last 60 s): ...", and
the first 12 art calls of each load named ("[Fast Load] art call 1: ...") so
a "Could not find anim build" line right after one shows which art it is.

Settings: scripts\fastload_settings.lua (enabled = the file search, log,
quiet_looks, quiet_looks_report).

Hidden-HUD fix (0.2.1): a game bug. With the Extra Lives talent, the lives
counter on the player HUD refreshes every frame and counts itself "hidden"
whenever the HUD is hidden, which the game does while any town menu is open
(the skill menu, the forge, the armoury), on the pause screen and on the
dungeon selection screen. So every frame it laid itself and the whole player
HUD out again: measured with Perf Probe at about 4 MB of garbage and 200-240 ms
of every second with the skill menu open (the frame rate jumping around, the
memory collector stuttering). Now it rests while the HUD is hidden and the
game's own refresh runs the moment the HUD is back.
Setting: hidden_hud_fix (true; false = the game's).
