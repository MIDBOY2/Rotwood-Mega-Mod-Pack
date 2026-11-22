Player Colours 0.2.8 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Pick each character's player colour. 23 colours at the game's own saturation and
brightness, or Vanilla (the game's colour for your player number: P1 blue, P2 yellow,
P3 teal, P4 purple). Every character starts on Vanilla.

WHERE
  The character screen (the mirror in town): the PLAYER COLOUR tab, after ARMOUR DYE.
  On top, a live preview built from the HUD's own pieces: the portrait with your
  character, your weapon badge and name, the health bar, a menu selection bracket. It
  shows the colour you point at (mouse or gamepad) and goes back to your pick when you
  move away. Pick a colour, Save Changes: everything recolours right then (HUD, the 2P
  over your head, the health bars, the ring under your feet, open menus' brackets,
  quest markers). Revert All undoes an unsaved pick. Saved with the character, like its
  look and dyes. Not on the new-character screen (pick it at the mirror after).

WHAT FOLLOWS IT
  Your HUD frame, portrait, health bar, weapon meter, name, selection brackets in menus,
  your silhouette behind walls, the ring under your feet, the aim arrow, and the other
  per-player effects (acid, poison, jam ball target, bow prime arrow trails, decor
  remover pointer, acid traps).

HOW (no performance cost)
  The game colours all of that from one table, UICOLORS.PLAYERS[player number], read by
  its own SetPlayerColor, which then tells the HUD to refresh. This mod puts your
  character's colour in that table for your player number and asks the game to refresh
  the same way it does itself. The feet ring / aim arrow / per-player effects are the
  game's hand-tuned effects per player number; each override colour gets the nearest
  player's set turned to its hue (worked out ahead of time, in data.lua), pushed once
  when the effect appears through the game's own colour components. Nothing runs per
  frame; no new art.

LIMITS
  Local play (couch co-op): each local character's colour. Online, other players' games
  don't know your pick (they show the game's colour for your number).

SETTINGS  scripts/playercolours_settings.lua
  enabled     false = off (picked colours stay saved)
  colour_tab  the PLAYER COLOUR tab
  fx          false = only the HUD / names / brackets change, effects stay vanilla
  debug       extra lines in client_log.txt

LOG  client_log.txt
  [Player Colours] on (23 colours; colour tab on; 93 per-player effects follow it)
  [Player Colours] character colour: Coral        (Save Changes at the mirror)

AFTER A GAME UPDATE
  If the game's per-player effects changed: python3 kit/tools/playercolours/pcdata.py
  <scripts dir> <mod>/scripts/playercolours/data.lua

CHANGES
  0.2.8  the farm plot signs (user 2026-11-17: "the farm plot signs, their colors don't change to
         the players colour"): the leaf on each plot's sign now shows its owner's colour. Only the
         leaf changes; the wood stays. The leaves are drawn in the game's player colours, so it
         uses the same colour fit as the Spring Port's machines (the closest player's leaf, then
         the engine's colour shift on just the leaf). It acts a frame after the game shows its own
         leaf (a player arriving or leaving) and whenever a colour changes; nothing per frame.
         Off: farm_signs = false in scripts\playercolours_settings.lua.
  0.2.7  two more reds (user 2026-11-17: "1 between red and ruby. and the other between red and
         scarlet, they should be closer to red in terms of hue and sat"; "Orchid will move 1 row up
         so we will have 12 colors per row"): Crimson (E9575A, between Ruby and Red) and Vermilion
         (EA6045, between Red and Scarlet), picked by eye from three options. Their hue and
         saturation sit nearer Red than the neighbour. Scarlet has Red's own hue (a lighter,
         softer red), so Vermilion leans a little to the orange side, or the two came out the
         same. Their effects are made like Red's, from P1's set turned to the colour; the ring
         under your feet is Red's "steps" ring turned to the colour, so its inner circle shows.
         The picker: two rows of 12 (Vanilla .. Orchid, then Pink .. Lime), a little less space
         between buttons so 12 fit. The other 21 colours are unchanged, line for line.
  0.2.6  the Spring Port follows your colour (user 2026-11-13: the room with the Corestone
         machines and their Treasure Bundles, before a miniboss; the game calls it "metaunlock").
         Each player's machine has its colour drawn into its art, a set per player number (the
         ring on the floor and its two glow layers), so it stayed vanilla. Now, only on those
         three layers: the set of the player whose art lands closest to your colour, with the
         engine's colour shift fitted so that player's colour becomes yours (in data.lua, made by
         the tool from the engine's own hue / saturation / brightness maths). The rest of the
         machine keeps its own colours. Its smoke and sparkles (idle, rewards waiting, rewards
         given) follow too, like the other per-player effects. Back to Vanilla: the game's again.
  0.2.5  LT / RT (the sub-tab buttons) on PLAYER COLOUR stopped the game ("Modified Game Error",
         tabgroup.lua: attempt to perform arithmetic on a nil value (local 'idx')): the tab has no
         sub-tabs and the game's sub-tab cycling looked for the open one. Now LT / RT do nothing
         where there are no sub-tabs (FURY's PRESETS too: both mods put the same guard in, once).
  0.2.4  the character screen's extra tabs (ARMOUR DYE, FURY's PRESETS, this one) each handle
         their own click, so the others never heard their tab was left: each registers how it
         leaves its tab, opening one leaves the others first, and the focus checks the tab that's
         really open and never picks a removed button (the game stops on that: the ARMOUR DYE
         crash, 2026-11-10)
  0.2.3  Red, second test: the UI read pink -> E23A2E, a true red (HUD frame, bar, names). The ring
         under your feet showed no inner circle: its art keeps the shading in alpha steps, and at
         full strength the red channel tops out on the ground so the steps melt together; now less
         red and a soft glow ("steps"); red_ring in the settings switches to "deep" (0.2.2) or
         "bright". The interaction prompt over your head ("RB Modify Weapon Gems") and the hold
         radial now change colour on Save Changes too (the game sets them once, when made).
  0.2.2  Red, after testing: the UI was too pink and the ring under your feet orange (its effects
         were turned from P2's yellow ones). Now a truer red (E86059) with its effects turned from P1's
         (clean red glow, every effect on red's own hue), and the rings toned down so they stay red
         and the inner circle still shows (kit/tools/playercolours/pcdata.py TUNING)
  0.2.1  fixes from the first test: the tab's name (showed MISSING:STRINGS...: the game's language
         pass replaces the strings after the mods load, so it's set again when the screen opens);
         colour buttons keep one size (the game put hovered ones back to their own size); names sit
         under the selection underline; the preview's weapon badge shows its coloured tag (sized like
         the HUD's) and the health bar's black border sits behind the bar, like the HUD's
  0.2.0  live preview on top of the tab; Save Changes refreshes everything at once (it rides the
         game's own Save Changes and fires the game's own colour refresh, then re-tints the few
         HUD bits that only read the colour when they're built)
  0.1.0  first version
