Camp Brother (experiment) 0.3.1 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Gishins, Doc Hoggins' brother, in the camp: sandy tan, red coat, charcoal pants, black hat with a
red wing. His station is at the crossroads between Lottie (the refinery) and Toot (the
dojo): a 2 x 2 cobblestone floor like the other NPC homes, the camp's road along its
front, and him on the road. Setups (look = ... in the settings, one word):
- "wagon_table": Doc's big potion wagon from the dungeon, drawn at 0.75, on
  the stone; his red table (Doc's small travelling trailer, recoloured) on the road to
  his right, like Hamish's forge and gem table, mirrored.
- "table": only his red table, drawn at 1.3, on the stone; him on the road beside it.
- "wagon_front": the big wagon (0.75) with his table right in front of it, both on the
  stone; him on the road.
- "layout2" (on in your settings): "wagon_front" with the potion table up by the
  refinery road at (-47, -13), where the grass beside the station is now road.
- "layout3": Hamish's station, mirrored (left and right swapped), around a plot at
  (-48, -18): the wagon (0.9) where his forge is, on a 3 x 2 stone floor like the
  forge's; his red table where the forge's tool table is; him at (-40.9, -13.9), where
  Hamish stands (the forge + (-7.1, 4.1) in the game's data), facing left; the potion
  table at (-36, -8.5), where the gem table is; the road between them, from the town
  map's road there. All from the game's own numbers; its floor and road tiles are its
  own (floor_tiles / road_tiles in its entry), the other setups' road isn't laid.
"table" and "wagon_front" also put a potion table on the road to his right (Hamish's gem
table, mirrored), "layout2" up by the refinery road: Tonic Swap's working Potion Table when that mod is on (part of his
station: not saved as built decor), else Doc's little potion table as decoration.
road_potion_table = false turns it off; working_potion_table = false always uses the
decoration.
Gishins is a game NPC, made by the game's own NPC maker like everyone in camp:
- he turns to face you when you come near (within 10), like the other NPCs, and faces
  whoever he's talking to;
- interact (RB): "Chit Chat". He greets you with a random hey animation (wave, "over
  here", point or clap) and asks "Are you in the market for Potions?", then:
    "What can you tell me about different kinds of Potions?" - Soothing Spirits (one big
      bottle, a big heal in one long swig), Bubbling Brew (two quick sips a fill, a
      smaller heal each), Misting Mixture (a little at first, then mending every second
      for a while);
    "What are Potion Tonics?" - the game calls them Teffra Pearls: they go in your
      potion and their effect comes with the drink; Bulbug Boba's shield, Coffee Jelly's
      speed, Spicy Pumpkin Seeds' Yammo rage, Small Beans;
    "Sorry, I've gotta run!" (the game's own leave option).
  Each question once a talk (the game's way); every talk has them again. With Tonic Swap
  on he also mentions the Potion Table. Emotes on his lines, the talking mouth while he
  speaks, Doc's voice.
- his lines are in scripts/campbrother_strings.lua, written the game's way (see the
  top of that file): edit, save, restart. A name in {name.x} that isn't the game's shows
  as a plain word (and the log says so) instead of the game's error screen.
- talk = false in the settings: he only stands there (the game gives him its "Have a
  good day!").
The chest and the starting camp move to the camp's bottom-left corner (a small rubble
pile there moves aside).

Settings: scripts/campbrother_settings.lua (positions in world units, each part on/off).
Off: enabled = false there, or add "rotwood-camp-brother" to disabled_mods in
mods\nativeloader_settings.lua. Nothing is saved: with the mod off, the camp is as it was.

How (all the game's own systems, set up once at load; nothing runs per frame):
- floor: the camp's cobblestone tiles (the tile under the cook's home plot), 2 x 2 map
  tiles = an NPC home's 8 x 8 plot, written into the town map layout before the town
  is built.
- road: the same map, the town road's own tile (copied from the road's end it joins),
  only on grass tiles (road_tiles in the settings).
- chest / starting camp: their spots in the town's prop placements (moved only from
  where the game puts them).
- wagon / table: the game's prop maker with their own prop data (traveling_potion_shop /
  traveling_potion_trailer), spawned with the town's placed props; drawn smaller /
  bigger the way the game flips a prop (each layer's animation scaled, their offsets
  with it), their bump scaled too.
- brother: the game's NPC maker (prefabs/npc_autogen.lua MakeAutogenNpc): body + head +
  mouth on the game's NPC animations and Doc's head animations (his head build on
  top), the game's NPC brain (brain_core_npc: face the nearest player, stand still),
  stategraph (sg_npc: idle, blink, emotes, talking mouth), interact and conversation,
  Doc's speech sounds. Spawned by the host like the camp's NPCs; not saved.
- his chat: a recurring chat quest (questral, like Doc's potion shop chat), added to
  the game's quest content once at load, given to each player for him when they walk
  up (the way the game gives every NPC its fallback chat); low importance (Chit Chat,
  no quest mark); not saved (nothing of it in your save if the mod goes). The game
  marks you as having met him (a "met" flag in your save, like every NPC).
- art: anim/campbrother*.zip, Doc's builds recoloured by the kit's
  tools/campbrother/build_art.py (the game's banks play them).

Log: "[Camp Brother] on (stone floor, road to him, chest moved, starting camp moved,
rubble moved, the brother's station (wagon_front), Gishins talks (Chit Chat))".

0.1.0 (2026-11-10): first try.
0.1.1 (2026-11-10): the brother up and to the right, at the trailer's right end
(-50.5, -11.5; was -52, -16.5); the road connects to him (map tile (-48, -12)) and the
road down past him is two tiles wide (x = -44, z -12 / -16 / -20); the chest
(-49.5, -27) and the starting camp (-53.5, -26.5) moved way down (were -21 / -23.5).
0.1.2 (2026-11-10): 0.1.1 moved only the brother; now the whole thing moves instead,
the brother back where he stood by the trailer: floor (-54, -10) (up one map tile; its
right edge meets the road's end under the refinery), trailer (-53.5, -8), brother
(-51, -12.5) (up 4, right 1). The road tiles and the chest / camp as in 0.1.1.
0.2.0 (2026-11-10): his station between Lottie and Toot (floor (-50, -18), the road line
along its front joining the road to Toot); Doc's big potion wagon (0.75) with his table on
the road to his right, or (look = "table") his table alone at 1.3; the chest (-56, -28) and
starting camp (-59, -26.5) in the bottom-left corner.
0.2.1 (2026-11-10): a third setup, look = "wagon_front": the big wagon with his table
right in front of it on the stone, him on the road (the mock-up's layout), on by default.
0.2.2 (2026-11-10): a potion table on the road to his right in the "table" and
"wagon_front" setups (Tonic Swap's working one when that mod is on, else Doc's little
table as decoration), with an off switch (road_potion_table).
0.2.3 (2026-11-10): "layout2" (the user's arrangement): wagon_front with the potion table
at (-47, -13); the grass tile there (-48, -12) is road now (in every setup). A Potion Table
you built on that tile goes back to your inventory (the game's own check: nothing can be
built on the road), the mod's stands there instead.
0.3.0 (2026-11-10): he's Gishins, a game NPC: made by the game's NPC maker, he turns to
face you, and has a Chit Chat (RB): a random hey animation, "Are you in the market for
Potions?", what the potion kinds are, what tonics (Teffra Pearls) are, and the game's
"Sorry, I've gotta run!"; Doc's voice. His lines in scripts/campbrother_strings.lua;
talk = false turns the chat off. Spawned by the host (networked like the camp's NPCs).
Also "layout3": Hamish's station mirrored (look = "layout3"). A list in the settings
(road_tiles, a setup's floor_tiles) now replaces the default list whole.
0.3.1 (2026-11-10): his name showed "MISSING:STRINGS.NAMES.campbrother_npc". The game
copies its text into its content DB at start-up (before mods), then setting the language
rewrites every line from that copy, so a name only added to STRINGS was lost. His name now
goes into the content DB too (the game's own AddString), and he checks it when he spawns.
