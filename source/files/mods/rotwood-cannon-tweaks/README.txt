Cannon Tweaks 0.1.0 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

The cannon's weapon powers with your own numbers. Out of the box:
  - Single Shot: 3 rounds in the cannon (the game: 1). Still x3 damage, faster and farther shots.
  - Return to Sender: -20% attack range (the game: -60%), and a caught shot reloads 2 (the game: 1).
  - Bottomless Clip: 3 rounds back a second (the game: 1.66), an overheat lasts 2.75 s (the game: 5).
  - Spray 'n' Pray: as the game (6 extra rounds), but its number is a setting too.
The power texts show the new numbers ("you only have 3 Cannonballs", "reload 2 Cannonballs").

Settings: scripts\cannontweaks_settings.lua (restart the game after changing it)
  - every number of the four powers, each with the game's own next to it:
    single_shot: rounds, damage_mult, light_speed_mult, heavy_speed_mult, range_mult, blast_angle_mult
    return_to_sender: range_penalty (percent, 0 = none), reload_on_catch
    bottomless_clip: regen_per_sec, overheat_sec, overheat_sound_sec
    spray_n_pray: extra_rounds
  - enabled = false inside one power puts that one back as the game has it (or single_shot = false).
  - fix_texts = true: the texts corrected to the numbers. console_command = true.
  - a number outside its limits is brought inside them, and the log says so.

Trying numbers without restarting (console, this session only; the settings file keeps yours):
  - c_cannon() every number now, with the game's
  - c_cannon("bottomless_clip.regen_per_sec", 4), c_cannon("single_shot.rounds", 5)
  - c_cannon("single_shot.rounds", "game") the game's number
  Rounds, damage, speed and range take effect from the next room; refill, overheat and the catch at once.

How it works: the game keeps each power's numbers in its definition and reads them every time it uses
them, so the mod writes yours in once, when the game starts (before any power is picked). The game's
own code does everything else. Return to Sender's catch reloads 1 in the game's code, so the mod wraps
that one function: the game's reload, sound and sparkle, then the extra rounds through the same reload
event the game uses. The texts: Power.GetDescForPower, corrected only for these powers. Nothing runs per
frame.
Your own character: other players need the mod for their cannon too.

Switching it off: enabled = false in the settings, or add "rotwood-cannon-tweaks" to disabled_mods
in mods\nativeloader_settings.lua, or delete the rotwood-cannon-tweaks folder. Nothing else depends on it.
Log lines start with [Cannon Tweaks] in client_log.txt (the start line lists what changed). If a game
update renames or removes something, that number or power is left as the game has it and the log says
so; the rest stays on.

0.1.0 (2026-11-18, the user: "about the cannon powers. They suck . Lets tweak them", picked: "Single
  Shot: 1 -> 3 rounds, Return to Sender: -60% -> -20%, Bottomless Clip: faster regen"; every number a
  setting): first version.
