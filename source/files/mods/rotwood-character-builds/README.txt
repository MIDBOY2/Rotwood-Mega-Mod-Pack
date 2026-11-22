Character Builds 0.2.0 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Save a whole character as a build in one click, and load all or part of it onto any character: in
another save, on another Steam account, on another PC. A build is the whole character: its look (every
customization, Furry OC Generator's colours, player colour), gear, inventory, materials, gems, every
loadout, talents, masteries, titles, unlocks, and the other mods' data on it (Skill Slots, Two Weapons,
Armor Dyes...). Because the gear and the loadouts that point at it travel together, every loadout
still works.

WHERE THE BUILDS ARE
One file for everything, next to the Steam account folders, outside every save:
  C:\Users\<you>\AppData\Roaming\Klei\Rotwood\character_builds.lua
(the previous version is kept next to it as character_builds.lua.bak). The game reaches it the way it
reaches its own files above the save folder. If the game won't keep it there, this Steam account's save
folder is used (saves\character_builds) and the log and the BUILDS tab say so. 0.1.0's builds (in the
save folder) are copied there on the first start; the save folder copy stays.
To use your builds on another PC, copy that file there, or point builds_file in the settings at a
folder both PCs share (OneDrive, a network folder). cb_where() in the console says which is in use.

THE BUILDS TAB (the mirror in town, the last tab; or Ctrl + B anywhere in town, again to close)
- Numbered slots, each showing the build's character wearing its gear and weapon, with their dyes,
  2 to a row. On the right, a loadout card for the slot you're on: its gear level, weapon and Two
  Weapons' second weapon (name, level, rarity, gems), armour (levels, gems), potion, tonic and food,
  damage and armour, and how many saved loadouts come with it. Made with the game's own item widgets.
  A on a slot:
  - empty: Save this character here
  - a build: Load onto this character / Save this character here (replace) / Delete
- Saving takes the character as last saved: press Save Changes first if you changed things in the
  mirror.
- Loading asks what to load:
  - Everything: look (face too), gear, inventory, loadouts, talents
  - Everything, keep my face: all of it, with your own eyes, nose and mouth (the build's colours on them)
  - More options...:
    - Look: species, body parts, colours, paintbrush colours, player colour (your gear stays)
    - Look, keep my face: as Look, with your own eyes, nose and mouth
    - Colours only: the build's colours and paintbrush colours on your own species and parts
    - Gear only: gear, inventory, loadouts, talents, unlocks (your look stays)
  The mirror closes and it goes on right away: no loading screen. Your character as it was goes to the
  automatic backups first (if that can't be written, nothing is loaded). The character keeps its own
  place and ID, and this save's quests and farm stay its own (they belong to this save's town).
- Automatic backups (below the slots, newest first, 8 kept): your character before each load. Load one
  to undo a load; delete the ones you don't need.
- Everything and Gear load in town; a look or colours load anywhere. Each player uses their own mirror
  for their own character (Ctrl + B opens it for whoever has the keyboard).

CONSOLE
  cb_list()             the builds and backups
  cb_save(n, p)         save player p's character as build n (p = 1 if left out)
  cb_load(n, p, what)   load build n onto player p's character; what = "all" (default), "all_face",
                        "look", "face", "colours" or "gear"
  cb_undo(p)            load player p's newest backup back
  cb_delete(n)          delete build n
  cb_where()            where the builds file is

HOW A LOAD WORKS
Everything is saved first and your character goes to the backups. The build (or the part picked) is
merged with the character's file and put onto the character the way the game itself puts a character
onto a player who picks one in town: the game's character load (look, unlocks), then its gear, loadouts,
talents and the rest, then the character is saved. Skill Slots' skill loadouts, Tonic Swap's tonic
cycle and Two Weapons' second weapon are emptied first and then take the build's, so nothing of the
old character is left mixed in. Tails and beards the new look doesn't have come off;
dyes the build doesn't have come off. If something goes wrong, your character as it was goes straight
back on; if even that fails, its file is put back and the town loads again (the game's full way back),
so it's never left half done. Nothing runs during play.

SETTINGS: scripts\characterbuilds_settings.lua (save, restart the game)
  enabled, builds_file ("" = the default above), slots (12), auto_backups (8, 1 to 50), mirror_tab,
  show_gear (gear on the tiles), loadout_card (the card; false = 4 slots to a row, no card),
  key_open ("Ctrl+B"; "" = no key), console_commands.

Switching it off: enabled = false in the settings, or add "rotwood-character-builds" to disabled_mods
in mods\nativeloader_settings.lua, or delete the rotwood-character-builds folder. Your builds file stays.
Log lines start with [Character Builds] in client_log.txt.

Not yet: making a brand-new character straight from a build (make any character, then load the build
onto it at the mirror).

0.2.0 (2026-11-17, the user: "loading a build , also the build doesnt show armor and weapon previews",
  "its really cool how the eyes nose and mouth keep their parts haha , that could be kind of an option ,
  Like to transfer colors from 1 character to anmother", "the entire room is reloaded. everything should
  be loaded , without a loading screen", "Lets try key binds for it / menu ui"):
  - loads right where you stand, no loading screen (0.1.0's town reload crashed: remove_decor_pointer)
  - Everything, and Everything keeping your face; Look / Look, keep my face / Colours only / Gear only
    behind More options (the user: "Everything , is what I wanted to the "keep my face" (which is
    everyhting but keep my face) and everything should be incuding the face. the other options
    should only show in a "sow more options prompt"")
  - the tiles show the gear and weapon with their dyes
  - the builds file next to the Steam account folders (the game hides %APPDATA% from mods, so 0.1.0
    used the save folder); 0.1.0's builds copied over
  - Ctrl + B opens the BUILDS tab in town
  - the second weapon on the card; skill loadouts, tonic cycle and second weapon load exactly (the
    user: "does it also save skill loadouts and tonics cycles ?", "show the second weapon as well")
  - the loadout card beside the slots (the user: "the Build Should Ideally include some of the
    loadouts info", picked "Loadout card beside tiles")
0.1.0 (2026-11-17, the user: "I great mod would let as save entire Character Customizations Preset +
  Gear Loadout in 1 click", "It needs to be a seperate universal file That isnt attacjed to 1 save",
  "A Full character saver would be great including all presets of cac and loadouts and gear, talents,
  everything"): first version.
