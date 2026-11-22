Armor Dyes 0.6.0 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Dye your armour. Helmet, body and legs each get their own colour. 39 dyes:
- 14 subtle dyes, worked out from the game's own armour colours (good for
  muting or nudging a set): Brick, Umber, Leather, Straw, Sage, Moss,
  Verdigris, Frost, Plum, Mauve, and the neutrals Soot, Iron, Stone, Bone
- 21 colour dyes, named after the player colour wheel: Green, Jade, Teal,
  Aqua, Cyan, Azure, Blue, Indigo, Purple, Grape, Orchid, Pink, Rose, Ruby,
  Red, Scarlet, Coral, Orange, Amber, Yellow, Lime. A colour dye only turns
  the colour: every part keeps its own lightness and strength, so nothing gets
  brighter or more saturated than the armour's own art, and the whole set
  turns together (a two-colour set stays two colours)
- 4 soft player colours: Soft Blue, Soft Yellow, Soft Teal, Soft Purple
  (a gentle tint toward players 1-4's colours)

WEAPONS (0.3.0)
- ARMOUR DYE has a 4th sub-tab, WEAPON: the weapon you're carrying. Its
  pictures show your character holding it in each dye.
- (0.5.6) Every weapon's dyes are worked out from its own art, like armour's:
  a dye turns the weapon's main colour to the dye's colour and the rest along
  with it, each colour keeping its lightness and strength - a gem stays a gem,
  metal stays metal, no flat neon wash. All 39 dyes: the 10 colour families
  (Brick, Moss...), the 4 neutrals, the 21 colour dyes, the 4 soft player
  colours, plus your own custom_dyes. The imbued boss weapons too.
- A weapon a game update adds (no numbers for it yet) gets the old tints (the
  dye colour multiplied in) until the data is remade.
- (0.5.9) The smears drawn in a weapon's own art (the spear's twirl trail) take
  the weapon's dye. The white swing smears every weapon leaves and the shot put
  ball's shadow are never touched. Off: dye_weapon_trails = false.
- Every weapon keeps its own dye (dye your hammer red, your spear blue).
- Off: weapon_dyes = false.
- Local players only: like the game's own dyes, online players' screens
  don't get your weapon's dye (the game only sends armour dyes).

TINT PALETTES (0.5.7)
- ARMOUR DYE has a PALETTES sub-tab: a whole colour scheme instead of one
  colour. Each material of a piece takes its own palette colour (main, second,
  third, fourth, accent, dark, light, metal), so a piece can be two or three
  colours. One click puts the palette on the helmet, body, legs and weapon.
- 24 palettes (0.5.8, your picks): the bosses' game colours - Mother Treek,
  Owlitzer, Thatcher, Bandicoot, Sedament, Eggzy, Grimhollow - then their
  imbued looks - Mother Treek, Owlitzer, Thatcher, Bandicoot, Sedament,
  Grimhollow, Grimhollow Lava - then Obsidian, Royal, Frost, Toxic and Rose
  Quartz, each soft and Bright (the first, stronger colours a touch toned
  down). The other palettes stay defined in the kit, off the list.
- No extra art: every picture of a piece gets one live colour shift (the same
  call as every dye here), so inside one picture its colours turn together. No
  colour is pushed brighter than it was or past the game's own range.
- Hover a palette: the big character shows it; pick it to keep it; save as any
  dye. Each piece keeps it like any dye (loadouts too).
- palettes = false: none. palette_tab = false: no PALETTES tab.
  palettes_in_lists = true: the palettes in each piece's own list too (to mix
  them per piece).

LOADOUTS AND THE LOADOUT STATUE (0.4.0)
- Loadouts remember the dye on each piece they wear: dye your armour, and
  switching to another loadout puts that loadout's dyes on, switching back
  puts yours back. A Morphic piece wears the dye of the boss look it shows
  (Morphic + Mother Treek's gem = Treek's armour and Treek's dyes).
- loadout_dyes = "auto" (default): a dye you pick while wearing a loadout goes
  into it right away. "save": like gems, a changed dye marks the loadout as
  changed; save it to keep the dye. false: dyes aren't part of loadouts.
- Loadouts saved before 0.4.0 don't touch your dyes until they get one (pick a
  dye while wearing it, or save it).
- The loadout statue in town shows the loadout as you'd wear it: Morphic
  armour in its gem's boss look, mirage looks, and the dyes. Saved with the
  statue, so it shows even when its owner isn't playing. A statue of an online
  player keeps the look it had. Off: statue_look = false (the game's statue).
- Weapon dyes count too when weapon_dyes is on.


IMBUED BOSS LOOKS (0.5.0)
- The seven bosses' armour and weapons repainted in their imbued (elite)
  colours: Mother Treek, Owlitzer, Bandicoot, Thatcher, Sedament, Eggzy,
  Grimhollow. New art made from the game's own boss art (anim/: the game's
  build files with repainted sheets, the same parts), with their own inventory
  icons (images/).
- As a dye: "Imbued" is the first dye after Original colours for every boss
  look - each boss armour piece (a Morphic piece showing the boss, or the boss
  mirage) and each boss weapon (WEAPON sub-tab). The piece is drawn from the
  imbued art instead of being tinted, its thrown parts (shot put ball, arrows,
  cannon shots) too, and its inventory icon shows the imbued look.
- More looks after "Imbued" for some bosses: Treek Plum, Eggzy First and
  Salmon, Grimhollow Lava and Lava with the magenta glow (imbued_alt_looks).
- Thatcher (0.5.5): "Imbued: Black Fur" first (armour + 6 weapons): the elite
  boss's black fur on the belly and the collar's strands, the legs like the
  elite boss's leg (white leg, black fur tuft above the foot, reddish foot),
  the weapons' brown fur black. "Imbued" = the white-belly look, unchanged.
  "Imbued: Black Fur, plain legs" (imbued_alt_looks): the same with the legs
  only recoloured (no fur tuft).
- As mirage patterns: at the mirage station, each boss piece you own (its
  weapon, its armour look, or a Morphic piece showing it) brings its imbued
  patterns, for any item of that slot (weapons: that weapon type), at the
  usual price. They sit with that boss's patterns and show "new" until seen.
- The imbued looks take the neutral dyes (and on weapons every dye, matched to
  the imbued art) like any other look.
- Saving: a dye is saved like any dye. An imbued mirage is saved as the boss's
  own mirage plus a note the game ignores, and comes back on load. Without the
  mod the piece simply shows the normal boss look.
- Memory (0.5.1): the game packs every loaded sheet into one texture pool with
  a hard cap of 190 slots, and a hunt's start room already fills ~177 of it. So
  the imbued art loads with the game's own per-area asset lists: in town all of
  it (17 slots: the mirror's and the mirage station's previews; town uses ~151),
  in a hunt only the imbued pieces your hunters wear (worked out as you leave for
  the hunt / the next room: usually one or two slots, none if nobody wears one).
  A piece whose art isn't loaded where you are (a loadout switched to in a hunt)
  shows the normal boss look until the next room, never an empty slot. The main
  menu shows the normal boss looks. imbued_alt_looks = false makes the town's
  share smaller; imbued = false loads none of it.

BAKED HEADBANDS (0.6.0)
- The Basic Headband and the Wollusk Helmet II repainted (real new art, not a
  tint) in 32 looks each, in ARMOUR DYE > HELMET right after Original colours,
  before the tint dyes:
  - Enigmox: Enigmox, Imbued Enigmox, Enigmox: Blue Eyes, Imbued Enigmox:
    Green Eyes, Enigmox: Pale Fur, Imbued Enigmox: Cream Fur
  - the other bosses, normal and imbued: Mother Treek, Owlitzer, Swarm, Rook,
    Shell Drake, Grimhollow
  - the game's colour families, "(baked)": Brick, Umber, Leather, Straw, Sage,
    Moss, Verdigris, Frost, Plum, Mauve, Soot, Iron, Stone, Bone
- The band takes the colour and keeps its own shading; the Wollusk band stays
  a little darker (a dark band), its studs keep their sage green with a touch
  of the look's metal colour. The black outline stays.
- Dyes only (never mirage patterns), the helmet only (never on the body or
  legs of those sets). The piece keeps the headband's own inventory icon.
- Small: only the helmet's art, packed into a 512 x 256 sheet per look. Like
  the imbued art, all of it loads in town (the mirror's previews), in a hunt
  only what's worn.

NEW CHARACTERS
- A brand-new character (made on the new-character screen) starts with its
  basic armour in its player's soft colour: player 1 Soft Blue, player 2 Soft
  Yellow, player 3 Soft Teal, player 4 Soft Purple. Only once; pick anything
  else at the mirror whenever. Off: new_character_colour = false.

HOW TO USE
- In town, use the mirror (character customization). There's a new tab,
  ARMOUR DYE, with HELMET / BODY / LEGS / WEAPON. Each picture is your character
  wearing that dye; hover / move onto one to preview it on the big puppet,
  click / A to pick it. The first picture = the original colours.
- Continue saves it with your character (like the other customization).
- Every player has their own dyes (up to 4 local players), and every armour
  set keeps its own dye: put on another helmet and it has its own colour;
  put the old one back and its dye comes back.
- Only armour you're wearing shows in the tab: to dye another set, wear it.
  Hidden armour (the armour toggle in the screen) keeps its dye.

HOW IT WORKS
- The game already has a dye system that was never switched on (the tab, the
  dye pictures, saving one dye per armour piece). Klei planned repainted
  armour files for it, none shipped. This mod fills it with colour shifts
  instead (AnimState:SetSymbolColorShift, the call the character creator uses
  for skin and hair), so no new art is needed.
- The numbers for each dye are worked out per armour set and per piece from
  the game's armour art (scripts/armordyes/data.lua), so Moss is the game's
  moss green on every set, at the set's own strength and shading.
- Limits of a colour shift: pure white, grey and black parts stay as they are
  (they have no colour to turn), so mostly-white sets like Bonejaw take dyes
  softly. The whole piece changes together (no trim-only dyes).
- An armour set added by a game update gets only the 4 neutral dyes until
  data.lua is made again (the update kit has the tool).

SETTINGS (scripts/armordyes_settings.lua)
- enabled, dye_tab, weapon_dyes, custom_dyes (your own colours: hue / saturation /
  brightness, the same shift on every set), new_character_colour, loadout_dyes,
  statue_look, debug.
- Imbued looks: imbued, imbued_alt_looks, imbued_mirage, imbued_icons,
  imbued_needs_boss_piece.

REMOVING THE MOD
- Armour goes back to its normal colours, nothing breaks. The game doesn't
  know the mod's dyes, so it drops them the next time it saves the character.
- Imbued mirages show the boss's normal look (that's what's in the save).

client_log.txt shows: [Armor Dyes] on (N dyes on M armour pieces; W weapon dyes (...); P palettes on Q pieces; dye tab on; new
characters start in their player's soft colour), and for a new character: [Armor Dyes] new character:
basic armour in ...

CHANGES
0.6.0 (2026-11-16 20:00, the user: "Trying to imbue Enigmox colors to bake and his normal ones, as well as other
  colors" / "I dont want them too vivid, more in line with the games color" / Wollusk: "Mostly the band" / "Good as
  start you can make these" / "Add the enigmox blue eyes, green eyes, and white/cream fur colors"): baked headbands
  (see BAKED HEADBANDS): 64 new helmet-only builds (anim/armor_basic_baked_*.zip, anim/armor_woworm_2_baked_*.zip).
  imbued.lua: a look can name its armour slots (slots = { "HEAD" }).
0.5.12 (2026-11-16 17:39, the user: "the inside of the canon remained purple" / "Lets use the horns color for the
  inside of the canon" / "New canon looks good"): the imbued Enigmox cannon's barrel inside and its cannonballs were
  left in the normal look's lavender; now in the cannon horns' cream khaki (#bcb09d), shading and spots kept, and the
  lavender rims on its leaves sage. Icons: the cannon's inside in the horn colour, the spear's leaf rims sage. The
  Striker (shot put) keeps its purple mouth as it was ("the striker emulates his inside of the mouth").
  The fixed cannon replaces the old one everywhere (its imbued look and its mirage pattern); the old one is gone.
  New (17:41, "add it as a secondary in the armor dye weapon tab only. But for the main imbued and mirage pattern
  keep the purple mouth"): "Imbued: Brown Mouth", the imbued Striker with its mouth in the horn colour, in ARMOUR DYE
  > WEAPON on the Striker, right after "Imbued". A dye only: never a mirage pattern. The main imbued Striker and its
  mirage pattern keep the purple mouth.
0.5.11 (2026-11-16 17:04, the user: "Yammo tint + hunter and bone jaw baked (with our workflow) In Armor dye -
  Weapon tab. Not in palletes"): imbued Enigmox's colours (dusty red, pale pink, sage) on weapons in his style, in
  ARMOUR DYE > WEAPON as "Imbued Enigmox", right after Original colours:
  - the 6 Yammo weapons: the imbued Enigmox palette as a live tint (the same colour shifts as the PALETTES tab's
    "Bandicoot Imbued", no new art; needs palettes = true);
  - the 6 Hunter and 6 Bonejaw weapons: baked art (anim/weapon_back_*_hunter_enigmox / _bonejaw_enigmox: every
    paint of the weapon given an imbued Enigmox colour, the shading and lines kept) with their own icons.
  A dye only: no mirage patterns, nothing new in the PALETTES tab. The art loads like the imbued looks' (town: all,
  hunts: what's worn).
0.5.10 (2026-11-16 14:10, the user on 0.5.9): "I only meant bow string which was too red / pink, the other stuff
  looked good" - the lava weapons are back as they were except the bow's string, now orange (#ed544d -> #ee7042;
  bow icon too); the reference looks are the red-string bow only ("Imbued: Lava, red bow string", "..., magenta glow,
  red bow string"). "I meant only the smears which are part of the weapon art ... The white swing stays untouched
  for all weapons" - the white swing smear tint is gone (no tint_swing_smears); the spear's twirl trail keeps the
  spear's dye, the slash trail ("wipe") is left alone again.
0.5.9 (2026-11-16): Grimhollow's lava weapons a bit more orange (user 04:01: "grimhollow red is too red, in
  his weapons, it needs to be a bit more orange than red, we can keep this version for reference"): the lava
  rims #f85078 -> #fa6a3c and the bow / cannon twine #ed544d -> #ee7042 (the yellow-orange core kept), in
  "Imbued: Lava" and "Imbued: Lava, magenta glow", icons too. The old red weapons are kept as reference looks
  "Imbued: Lava, red" and "Imbued: Lava, magenta glow, red" (weapons only), off unless
  imbued_reference_looks = true in the settings (nothing loaded for them otherwise).
  Weapon smears (user 04:01: "weapon dye does not apply to the smear sprites"): the spear's twirl trail
  (fx_spear_twirl01, drawn in each spear's own colours) now takes the spear's dye like the rest of it
  (dye_weapon_trails), and the white swing smears (the player's smear_weapon_generic01, white art) get a
  multiply tint: the weapon's main colour (tintdata) turned by the dye, at full brightness and 60% of its
  saturation (tint_swing_smears); back to white with no dye, on an imbued look, or with the weapon put away.
  Imbued mirage patterns had only 4 dyes (user 04:02: "while using the mirage pattern - the armor dye options
  become very very thin"): a mirage pattern draws the imbued piece, and there were no dye numbers for the
  imbued art, so it got the 4 neutrals. New scripts/armordyes/imbued_dyes.lua (kit tools/dyedata/
  imbued_dyedata.py, the same maths as data.lua on the 14 imbued armour builds): every dye now, worked out
  from the imbued colours.
  Gem screen (user 04:01: "gem stone icons still don't change"): the big item picture on the gem screen shows
  the imbued icon too (an imbued look as a dye or a mirage pattern), like the inventory and item pictures
  already did (the game draws the item's own unlock icon there whatever look it wears).
0.5.8 (2026-11-16): the palette list as picked (user: "I want the new and old obsidian, royal, Frost, Toxic,
  Rose, Sedament, Owlitzer, Thatcher, Grimhollow ... Bandicoot", "this one was good" (Grimhollow lava),
  "this was nice" (Mother Treek imbued), and "learn the bosses normal color palettes too"). New: the 7
  bosses' game-colour palettes (kit/tools/palettes/learn_normal_palettes.py: each imbued palette colour
  traced back through elite_ramps.json to the game paint it came from; Thatcher's / Eggzy's dark and
  Eggzy's eye set from the right part). Bright versions = the first colour palettes at 0.8x chroma.
  Dropped from the list (still in tint_palettes.json): Treek plum, Thatcher black fur, Eggzy imbued,
  Crimson & Gold, Ocean, Forest, Ember, Midnight, Sunset, Desert, Jade & Bronze, Ivory. A piece saved with
  a dropped palette shows its original colours (the game skips unknown dyes).
0.5.7 (2026-11-16): tint palettes (user: "use the armor dye versions that you did for the elite version ...
  cool universal color palettes ... not 1 uniform painted over color"; on the tint vs repaint comparison:
  "that looks kind of cool", "we should do even some for colors"; then "most of these colors are over the
  top" -> the colour palettes toned down to the boss looks' range, Obsidian kept close to the first one).
  New palettes.lua (the arithmetic), palettedefs.lua (24 palettes, kit/tools/palettes/make_palettedefs.py),
  tintdata.lua (per build and picture: the material's palette role and colour and the picture's 3
  strongest colours; kit/tools/palettes/tintdata.py from the game's 75 armour + 146 weapon builds and
  the mod's 14 + 60 imbued ones). A palette dye per piece (armordye_pal_<key>); ApplySlot gives each
  picture its own shift (worked out the first time a piece shows it, then kept: nothing at load).
  PALETTES sub-tab: one picture per palette, click = on every piece (the weapon when its dye is saved by
  the screen), hover previews and puts each piece's own dye back. client_log: "24 palettes on N pieces".
0.5.6 (2026-11-16): weapon dyes matched to each weapon (user: "they color everything in neon color ...
  do something similar to the armor dye ... not 1 uniform painted over color"). New weapondata.lua (made by
  kit/tools/dyedata/weapondata.py from all 146 game weapon builds and the mod's 60 imbued ones): per weapon,
  the colour shift for every dye (dyedata.py's families / neutrals, colourdyes.py's colour and soft dyes)
  from the main colours of its dyed pictures. Weapons get the 10 families now too (39 dyes + yours).
  No tint (SetSymbolMultColor) any more on those; saved weapon dyes keep their names, so a red hammer is
  still red, just the hammer's own red. Weapons without numbers keep the old tints. client_log says
  "N weapon dyes (M weapons matched, K on the old tints)".
0.5.5 (2026-11-15): Thatcher's black-fur looks. "Imbued: Black Fur" (first in his list: armour with the
  black belly and collar strands, the legs like the elite boss's leg - white cuffs, the shin wraps drawn
  as the boss's black fur tuft hanging over a reddish band, reddish boots - and the 6 black-fur weapons)
  and "Imbued: Black Fur, plain legs" (an extra look: the same legs only recoloured). The white-belly
  "Imbued" look and its key are unchanged (saved looks keep showing it). New icons for both (head as
  before). User: "B is desired but I'm worried animation wont look correct, so do both A and B",
  "the one with the white belly is good so no need to touch it", "Both weapon sets are good".
0.5.4 (2026-11-15): character cards (main menu character select, save slots) show every dye and look.
  A card with loadouts draws each loadout by the items' own names (the game's card code), so a mirage
  pattern - and the dye on that look - didn't show. Each piece is drawn in its look again (mirage,
  Morphic gem or imbued). The main menu loads no area, so the imbued art a card shows is loaded when
  the card is drawn (only those builds) and unloaded with the main menu when a game starts (handed to
  the next sim so nothing stays loaded into hunts). The drawn pieces' save (read by the cards) now keeps
  an imbued look as the boss look + a note, like items. User: "character select doesn't show the new
  frenzy armor dye or mirage pattern", "that and any other dye please".
0.5.3 (2026-11-15): imbued mirage pattern names showed "MISSING:STRINGS.ITEMS....":
  the names were also put in the game's STRINGS table, and the game's language
  pass rewrites every line there. Now they stay out of it, and the shown name is
  the boss piece's name (in the game's language) + the look, e.g.
  "Eye of the Storm (Imbued)". User: "mirage patterns names are missing".
  Imbued dyes inside a hunt: a hunt whose start didn't carry the worn looks (begun
  by an older version still running in town, or straight from the main menu)
  showed the normal boss look for the whole hunt. Now what's worn is added to the
  hunt's load list before every room change (never taken away), so it shows from
  the next room on; client_log.txt says once per look when its art isn't loaded.
  User: "the color dye resets when loading into a level".
0.5.2 (2026-11-15): the body and legs imbued patterns at the mirage station showed
  the helmet (icon and preview piece): the three pieces share a name, like the
  game's armour, and the station's stand-in was kept per name. Now per slot.
  User: "the mirage pattern icons for chest shows the head helmet icons".
0.5.1 (2026-11-15): the imbued art no longer loads with the mod. 0.5.0 kept all of
  it loaded everywhere: 17 of the game's 190 texture slots, on top of the ~177 a
  hunt's start room already uses (over the cap), and a slower start. Now it loads
  per area with the game's asset lists (town: all; hunts: what's worn), with the
  normal boss look as the fallback. User: "rotwood almost crashed on startup".
0.5.0 (2026-11-15): imbued boss looks for all seven bosses (armour + 6 weapons
  each, Treek / Eggzy / Grimhollow extra looks), as the first dye of each boss
  look (with the imbued icon) and as mirage patterns. User: "install the imbued
  bosses skins ... as armor dye first slot that changes icon as well and mirage
  pattern". Thatcher is v1 (to be revised).
0.4.0 (2026-11-14): Loadouts remember their dyes (loadout_dyes), the loadout statue
  shows dyes, Morphic boss looks and mirage looks (statue_look). User: "make
  loadouts remember the armor dye. and display that too"; "make the loadout
  statue display them" (Morphic armour showed plain).
0.3.1 (2026-11-12): "Original colours" on a dyed weapon looked washed out. The game keeps
      a part's colour shift and its tint together: 0.3.0 cleared the shift and then put
      the tint back to white, and the old shift (nearly grey, a bit brighter) came back with
      it. Now the tint goes back first, the shift is set to none, then cleared. Armour
      (never tinted) is untouched by this.
0.3.0 (2026-11-12): a WEAPON sub-tab in ARMOUR DYE (see WEAPONS). The HUD
      portrait and other copies of your character show the weapon's dye too.
      Slash trails stay undyed. If anything about weapons fails, the armour
      dyes work as before (and saving never drops a weapon dye it didn't see).
0.2.3 (2026-11-10): ARMOUR DYE crashed after PRESETS ("Modified Game Error",
      SelectableBodyPart). The game builds dye lists only for the 5th top tab, and
      FURY's PRESETS before it makes ARMOUR DYE the 6th, so the game built body-part
      lists there; and as Armor Dyes handles its tab's click itself, FURY never
      heard PRESETS was left and focused one of its removed slots (the game stops
      on that). The dye sub-tabs now build their dye lists themselves, and the
      character screen's extra tabs (ARMOUR DYE, PRESETS, Player Colours) each
      register how they leave their tab: opening one leaves the others first.
0.2.2 (2026-11-10): the ARMOUR DYE tab is back: FURY 1.5.0's presets tab put two more
      wrappers around the character screen, and the tab looked for the game's tab
      list only 4 deep (it's 6 down now: Player Colours, FURY's three, its presets
      tab); it looks 24 deep. A new character really spawns in its soft colour now
      (the 0.2.1 mark from the new-character screen was lost when the game starts
      the camp in a fresh Lua; now: the game loads a character with no saved data
      = just made). The new-character screen's template shows it from the moment
      a player takes the slot, and keeps it when you pick another template or
      preset. Player 1 Soft Blue, 2 Soft Yellow, 3 Soft Teal, 4 Soft Purple (the
      game's own player colours).
0.2.1 (2026-11-10): the new-character screen shows it: the template you're
      picking wears its basic armour in your player's soft colour (before, the
      colour only came on the character's first spawn).
0.2.0 (2026-11-09): 21 colour dyes (the player colour wheel) and 4 soft player
      colours added after the 14 subtle ones; new characters start with their
      basic armour in their player's soft colour (new_character_colour).
0.1.0: 14 dyes, the ARMOUR DYE tab.
