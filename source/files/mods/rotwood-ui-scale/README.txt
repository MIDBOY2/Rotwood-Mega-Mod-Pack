UI Scale 0.2.0 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Two parts of the interface get their own size; everything else stays exactly the game's:
  - Character info: your corner with the portrait, name, health, skills, potion and currencies (and
    the other players' corners). Each shrinks toward its own corner of the screen.
  - Power popup: the power details over a power you can pick up (also in the shop and at the
    wanderer), and the prompts: the line over you that says what the button does (Take / Reroll,
    Talk, the mirror, the stations, Revive), in camp and on hunts. A conversation's speech balloons
    keep the game's size.
  - (Whole interface: 0.1.0's way, everything including menus and the map. Left alone at 100%.)

Changing the sizes in the game (remembered, also after a room loads or a restart):
  - Options > Graphics: Character Info Size, Power Popup Size, Whole Interface Size (50% to 150%)
  - Character info: Ctrl + = bigger, Ctrl + - smaller, Ctrl + Shift + = the game's size
  - Power popup: Ctrl + Alt + = bigger, Ctrl + Alt + - smaller, Ctrl + Alt + Shift + = the game's size
  - 5% a press; the number pad's + and - work too (with the same modifiers). Not while typing in the console.
  - console: c_uiscale(0.8) character info, c_uiscale("popup", 0.8), c_uiscale("whole", 0.9),
    c_uiscale() the sizes now

Settings: scripts\uiscale_settings.lua (restart the game after changing it)
  - character_info = 0.85, power_popup = 0.85, whole_interface = 1: the sizes to start with, until you
    pick others in the game. 1 = the game's own size.
  - popup_prompt = "all": every prompt follows the power popup's size; "pickups": only Take / Reroll
    at a pickup; "none": the game's size.
  - remember = true: sizes picked in the game are kept (your save folder: saves\ui_scale).
  - options_rows, the key_... lines ("" = no key), step, console_command.

How it works: the game builds the character info (PlayerStatusWidget) and the power details
(WorldPowerDescription) again every room. The mod wraps those classes' constructors (like the game's
own AddClassPostConstruct) and, on each new widget, that one widget's size call, so its size goes on
top of the game's own. The prompts are the game's interaction prompt (Interactor:SetStatusText, one
widget for every interaction) and the HUD's label prompt (revive). Nothing runs per frame; no other
widget is touched.
Whole interface: the game lays out every screen on a 3840 x 2160 canvas and fits that to your window;
at anything but 100% the mod makes the canvas bigger (3840 / size).

Switching it off: enabled = false in the settings, or add "rotwood-ui-scale" to disabled_mods
in mods\nativeloader_settings.lua, or delete the rotwood-ui-scale folder. Nothing else depends on it.
Log lines start with [UI Scale] in client_log.txt. If a game update changes something it uses, that
part switches off (the rest stays on) and the log says so.

0.2.0 (2026-11-17, the user: "Lets try key binds for it / menu ui", "ui is affecting everything from,
  menu to world map , Nice - but it needs to be only the character info", "and it resets on load",
  "and this needs a different setting from the character ui , and everything else needs to stay
  exactly the same", "Cant you include that in the popups ?", "the prompts still dont scale down",
  "maybe only incamp ?"):
  - character info and power popup, each with its own size; the whole interface left alone
  - the prompts follow the power popup: every prompt, camp too (popup_prompt = "all"; "pickups" is the
    first 0.2.0's way, only Take / Reroll)
  - sizes picked in the game are remembered (0.1.0's c_uiscale went back to the file's size)
  - Options > Graphics rows, keys
0.1.0 (2026-11-17, the user: "How to scale the ui down ? To make it smaller ?"): the whole interface,
  from the settings file.
