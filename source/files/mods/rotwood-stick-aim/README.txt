Stick Aim 0.1.1 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

A controller player's right stick can aim, the way the mouse does with mouse aiming on.

Each player picks: right stick AIM or EMOTES
  BACK + right stick click (hold BACK, click the stick) switches it for that player.
  A note says which ("Player 1: right stick aims"); the status panel BACK opened
  closes again. Each player slot keeps its choice for the next game
  (stickaim_modes.txt in the save folder). Players start in EMOTES
  (default_mode in the settings).

EMOTES: nothing changes (the emote ring on the stick, with Controller Layout).

AIM, while you push the stick:
  - standing still you turn to face the stick; running away from where it
    points you run backwards, looking that way (the game's mouse-aiming moves)
  - light attack, heavy attack and skills go where the stick points (steerable
    skills, the cannon's aim, the cleaver too); dodge still goes where you walk
  - the aim pointer under you points where the stick points
  - the buttons trade places (preset 1):
        RB  light attack        A  interact
        RT  heavy attack        B  potion
        LB  skill               X  your LT skill slot
        LT  dodge               Y  your RT skill slot
    D-pad, sticks, BACK, START stay as they are.
  - the stick doesn't open emotes. In menus, while placing a decoration, or
    with the emote ring open some other way, the stick is theirs as usual.
Let go of the stick: everything is back to normal. A button you pressed while
aiming keeps its job until you let go of it (no stuck buttons).

How it works: the swap is done where the game reads a controller button,
before it looks up what the button does, so it follows every binding (the
game's, Options > Controls, Skill Slots, Controller Layout). The aim uses the
game's own mouse-aiming code with the stick's direction. Nothing runs every
frame of its own.

Settings: scripts\stickaim_settings.lua (save, restart the game):
  enabled, default_mode ("aim" / "emotes"), toggle, toggle_note, close_status,
  remember, aim_at / release_at (how far to push to aim / to stop), swap_buttons,
  preset, player_presets (a preset per player slot), presets (your own layouts).

Switching it off: enabled = false in the settings, or add "rotwood-stick-aim" to disabled_mods
in mods\nativeloader_settings.lua, or delete the
rotwood-stick-aim folder. Nothing else depends on it.
Log lines start with [Stick Aim] in client_log.txt. If a game update renames
something it hooks, it switches off (or that part does) and the log says what.

0.1.1 (2026-11-16 22:10, the user: "Will the new right stick aim mod hinder performance?"): no new function is made
  per call any more while aiming (the aim pointer and running backwards ask every frame): nothing left for the
  garbage collector. Same behaviour.
0.1.0 (2026-11-16, the user: "per player setting for right stick AIM/EMOTES",
  "Using the right stick will aim", "While touching the right stick all ABXY will
  change places with RB LB RT LT", "Letting go of the stick will return controls
  to normal"; layout: "RB light attack, RT heavy attack, LB skill (B), LT dodge,
  A interact, B potion, X LT skill slot, Y RT skill slot"; toggle "BACK + right
  stick click"): first version.
