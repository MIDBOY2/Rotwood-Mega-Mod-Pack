Tonic Swap 0.7.13 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

D-pad right / left (keyboard . and ,): next / previous tonic in your cycle. The
tonic is drunk together with your potion. Its icon sits on the potion icon in
your HUD, and your potion pops up above your head for a moment after a swap.
Each player cycles their own. D-pad left/right no longer walk.

Potions
  All three of the game's potions are yours from the start, picked at the top
  of the potions menu (in town). The game only gives you Soothing
  Spirits; the other two are finished in its files but hidden.
  Soothing Spirits: 250 health, as the game.
  Bubbling Brew: 100 health a sip, 2 sips a charge, and your tonic comes with
    every sip (so each charge gives you the tonic twice: its one benefit, for
    two drinks' time and less health). Potent Brew's flat bonus counts half
    per sip. Everything else that reacts to drinking counts once a potion
    (Iron Brew's shield, the frost freeze, Cleaver berserk, Forbidden Drink /
    Diluted Medicine's counters, Immorel's refills), and a free drink (the
    shop's potion drunk on the spot, the potion event when you're full) is a
    whole potion's healing. The HUD, the character panel and the potion over
    your head count sips: 3 charges show 6, each sip takes one off. The game
    still counts charges for everything else (talents, refills, "full").
  Misting Mixture: 30 health right away, then every second, 10 heals (300).
    Potent Brew counts 1.2x for it, spread over the 10 heals: each rank adds 3
    a heal (rank 10: 60 a heal, 600 a drink). Drinking it again while it
    heals starts the 10 again and keeps the heals that were left (the game
    wasted that drink).
    Allies: each heal also heals allies within your reach by their share
    (40%). An ally a heal reaches is linked for the rest of that drink and
    gets their share every second even after walking away. Every heal from
    the second on: everyone it heals (you, the linked allies, anyone in reach) glows
    green with a small heal burst and gets the small green ring around the
    feet; a green heal beam goes from you to each ally. misting_allies
    ("link" / "game"), misting_pulse ("none" / "wave": the green heal area
    grows out from you to your reach / "ring"),
    misting_glow, misting_beams, misting_marks (true / false).
    The beam to a far ally (misting_beam_style): "chain" (default) cuts the
    line into pieces of about 6 units, each the game's own small beam at the
    size it was drawn for, one after another from you to the ally; near allies
    get the game's beam as it is. "thin" (0.7.7): one beam, thinner and
    fainter far away. "game": the game's beam at any distance. Numbers:
    misting_beam_piece, misting_beam_max_pieces, misting_beam_ripple,
    misting_beam_fade_from, misting_beam_fade_to, misting_beam_min_alpha,
    misting_beam_max_distance (and for "thin": misting_beam_full_until,
    misting_beam_min_width).
  Everything else is the game's own: charges (Field Medicine, refills, Double
  Pour, Perfect Pairing), % bonuses, the hunt's potion multiplier, healing
  allies around you (40%), powers that react to drinking. The menu shows
  each potion's numbers with your talents and powers, and your charges.
  Their bottles in the drink animation are the mod's own art (anim folder:
  a round flask and a crystal decanter, made from Soothing's bottle and the
  potions' icons), and so is the bottle smash at the end of the drink (the
  game's shards in their glass colours). The HUD shows their own icons; the
  empty ones are the mod's (images folder), dark see-through glass like
  Soothing's. The talent menu (the hearts at the Wellspring) shows each
  player's own potion where the game shows its potion picture (Field
  Medicine's charges, the loadout summary): on the talent line the potion's
  HUD bottle, as big as the game's picture, next to the number; in the
  loadout summary and descriptions the game's HUD icon for it (a picture
  inside a text can only come from the game's own atlases). talent_picture
  in the settings: "hud_small" = the game's HUD icon everywhere, "inventory"
  = the inventory icon. The HUD icon changes as soon as you pick (in
  town too).

Tonic effects (tonic_fx in the settings)
  Some tonics still used the game's early placeholder effects. Now: Ice Cold
  Slushie freezes enemies in the current ice prison (Frozen; bosses get Cold),
  Battoad Eggs and Chocolate Foam shoot the Shrapnel projectile with its
  trail, Popping Candy uses the small explosion and its ground blast. Same
  damage and timing as before.

Potions menu
  Build a Potion Table (build menu: Furniture or Usable; the mod's own
  station) and press interact (RB, "Choose Potions") on it in town. It's Doc
  Hoggins' travelling table from the dungeon, a bit bigger (its top at your chest), with all three potions on it
  (Soothing Spirits, Misting Mixture, Bubbling Brew) and his SALE! sign. It
  costs what the Hewn Bench costs (potion_table_cost_like). The Ironwork
  Illuminator (Lights; the mod unlocks it too) works as before. Each local
  player gets their own panel, like the Emote Booth.
  The table is made the game's way: the game's own table animation plays the
  mod's art (anim/tonicswap_potion_table.zip: the game's table with the
  decanter swapped for the three bottles), the game's prop maker builds it
  and the game's screen opener opens the menu, like the Teffra Mirage
  Station. Nothing runs on it while it stands there.
  Turning the table off (potion_table = false) or the mod off: pick placed
  tables up first, they go away with it.
  Top: your three potions, big. A takes one (in town); yours sits in a soft
  light and says Equipped.
  Below: one 3 x 3 grid of tonics (the shield top left, the yellow ones in the
  bottom row; settings: order).
    A: put the tonic in your cycle (in colour) or take it out (greyed).
    X (right click): make it your main tonic, the green frame and "Main". It's
       equipped right away and first in your cycle; the D-pad goes on from it
       in grid order.
    Y: disable cycling (only the main tonic stays, the D-pad does nothing),
       or, when it's off, put every tonic in.
    All nine out = no tonic. Taking out the main tonic makes the next one
    that's in the main one; the first one you put back in is the main one.
  "Equipped" on a tonic: the one you have on right now.
  On the right: the potion or tonic under the cursor, its buttons, and how
  many tonics your cycle has and which comes first.
  2 players: each gets a narrower, taller panel side by side, with bigger
  icons and the details under the grid.
  Saved per character. Never opened the menu: every tonic out (no tonic). A
  save from before 0.4.0 that had No tonic as the main one with tonics in:
  the first tonic that's in is the main one now.
  Developer console: tonicswap_menu() opens it anywhere.

Iron Brew and Bulbug Boba: Iron Brew (the power) gives 4 Shield Segments every
drink, which is Bulbug Boba's job. While you have it, Boba sits out of your
cycle: the D-pad skips it, and if you have it on you get the next tonic in
your cycle (the log says "Iron Brew: full_shield sits out of your cycle ...").
In the menu it's greyed with "Sitting out while you have Iron Brew". When the
power goes (back in town, a new run) Boba is back in your cycle, and if you
still have that next tonic on you get Boba on again. Your choices in the menu
don't change. out_with_power in the settings (false = off).

Settings: scripts\tonicswap_settings.lua (save, restart the game): buttons,
the Potion Table (potion_table, potion_table_cost_like), station decorations, skip list, order (the grid / cycle order),
main_at_run_start (every run starts on your main tonic), and the potions: potions on / off, potion_bottles ("own", or
"recolour" = Soothing's bottle in their colours if the own art shows a
missing bottle), Bubbling's sips and flat share, Misting's heal, number of
heals and restart, talent_picture.
Log lines start with [Tonic Swap] in client_log.txt.
0.4.6: Popping Candy's explosion half the size, no ground blast (it was over the
top going off every second); tonic_explode_scale / tonic_explode_ground.
0.4.7: Popping Candy: one blast a tick (the game also burst a bomb hit on every
enemy in range, which looked like a blast each); tonic_explode_enemy_blasts.
0.4.8: while you drink a potion, the health bar and potion icon over your head
move up (drink_lift) so they don't cover the drinking animation.
0.5.0: the status panel (player status button) potion slot: the blue
patterned background of an item slot and a 1.35x bigger bottle (settings:
status_potion_look, status_potion_scale). 0.4.9's change never showed: the
game loads that panel's widget under another name; fixed. The empty bottle
shows again with no drinks left, like your mock (status_potion_full = true
for the full picture). The HUD's dark frame now reaches past the tonic icon
next to the potion (hud_potion_backing).
0.5.1: Bubbling Brew's number on the HUD counts sips (bubbling_hud_sips).
Powers that react to drinking: once a drink with any potion (the game told
them twice when you had a tonic: Iron Brew gave 8 shield, Forbidden Drink ran
out after 2 drinks), and once a potion with Bubbling Brew; a free Bubbling
drink is a whole potion (bubbling_per_potion).
0.4.9: Spicy Pumpkin Seeds: double damage for 5 seconds (was ten times;
tonic_rage_damage), Battoad Eggs: 100 a projectile (was 50; tonic_eggs_damage),
"[TEMP]" off the tonics' texts (tonic_clean_text); the status panel shows
your potion's full picture even with no drinks left (status_potion_full); the
potions' descriptions now survive the game setting its language.

0.5.2: bulletproofing: Tonic Swap's part of a drink, the potion count, the tonic
menu press, the bottle colours and the talent pictures is guarded: an error is
logged ("[Tonic Swap] error in ...") and the game does it its own way that
moment, instead of its error screen ending the run. guard = false: the game's way.

0.5.3: the HUD's frame by the potion: no extra piece any more. The frame is
see-through, so 0.5.2's piece behind it showed as a darker block (twice the
black) with a lighter, long tail. Now the frame's own left piece is just wide
enough for its slanted corner to clear the tonic icon, and the band to its
right is shortened by as much, so the frame ends where it always did.
Ice Cold Slushie: everyone froze in the same frame. tonic_freeze_style picks
how it plays out: "nova" (the Legendary Frost power's frost nova: the
full-screen frost burst and its sound, then enemies freeze one after another,
nearest first), "ripple" (a big frost burst at you, each enemy freezes as the
wave reaches it, a small burst on each), "chill" (enemies go cold first, then
freeze a moment later), "instant" (all at once, as before). "browse" (for now)
uses the next one each time and shows its name over you, so you can try them
and pick one.

0.5.4: Ice Cold Slushie's frost nova: the further enemies freeze quicker, so
it's closer to instant. The nearest freezes at frame 2 and the next at the
power's pace, then each gap is 0.6 of the one before (at least 1 frame), and
everyone is frozen by frame 12 (0.4 s). 3 enemies: frames 2, 7, 10 (were 2, 7,
12); 7 enemies: done by frame 11 (was 20). TonicFx.NOVA in tonicfx.lua
(speedup = 1, last = nil: the 0.5.3 pace).

0.5.5: Bubbling Brew keeps a half-drunk charge between rooms. After one sip
the next room used to give the half back (the game rebuilds the player each
room; its charge count is saved, the sip count wasn't). Now the sip is saved
with the character and put back in the next room, as long as it's the same
run, the same potion and the same charges (town and a new run refill
everything, as before).
The talent screens (the hearts at the Wellspring) show your potion's own heal
on Potent Brew (Eggzy's potion heal talent). The game always showed Soothing
Spirits' 250 + 25 a point. Now, per potion (a whole charge):
  Soothing Spirits   250, +25 a point (the game's)
  Bubbling Brew      200 (2 sips of 100), +25 a point (half a point's 25 each sip)
  Misting Mixture    300 (10 heals of 30), +30 a point (1.2x, spread over the heals)
These were already what the potions healed; only the talent screens' numbers
were Soothing's.

0.5.6: a heal log (potion_heal_log = true, a probe): each drink writes to the
game's log how its heal was worked out ("[Tonic Swap] potion heal: <potion>:
<base> + flat <bonus> x <share>, x<% bonuses> x<hunt> = <heal>") and what it
really healed ("potion heal given: <amount>"). To check Bubbling Brew's share of
Potent Brew in the game (the mod's tests give 162 a sip at 5 points; a run
showed 225). Set it to false when done.

0.7.4: fix: 0.7.3 crashed the game at start (its 1.5x art was 1536 wide; the engine only takes
power-of-two atlases). The Potion Table is now 1.15x the game's table, its top at a hunter's
chest; 2x2 on the town grid.
0.7.3: the Potion Table was 1.5x the game's table, the gem table's height (2x was too big);
3x3 on the town grid like the gem table.
0.7.2: the Potion Table was twice the game's table (it was too small in camp): the art is
built 2x and upscaled, the game's table animation still plays it; 4x4 on the town grid.
0.7.1: fix: the build menu crashed when the Potion Table got focus (the game had made
the structures' recipes before the mod added the table; now the table's recipe is made
with the game's own MakePlaceablePropRecipe).
0.7.0: the Potion Table, a tonic station you build in town (Furniture /
Usable): Doc Hoggins' travelling table with all three potions and his SALE!
sign, the game's table art with the decanter swapped (anim, and the build
menu icon in images/tonicswap_station). potion_table, potion_table_cost_like
in the settings; the Ironwork Illuminator stays a station.
0.6.3: Misting: more to see each heal. The green wave now grows out from you to
your reach and stays a moment (0.6.2 played only its 0.2 s fade, so it barely
showed); everyone healed glows green with a small heal burst (misting_glow);
a heal beam from you to each ally (misting_beams, Gourdo's seed beam, the one
the Head Hunter power shows). Online, the wave is stopped for everyone (0.6.2
could leave copies on the other players' screens). The wave is off by default
(misting_pulse = "none"); "wave" turns it on.
0.6.2: Misting: the big ring each heal is gone (misting_pulse = "ring" brings
it back); a green healing wave instead, and the small green feet ring on
everyone the heal reaches, linked allies included.
0.6.1: Misting Mixture and your allies (misting_allies = "both"): every heal
sends out the healing ring (your reach, a mark on each ally in it), and an
ally a heal reaches gets their share every second for the rest of that drink,
wherever they go. "wave" / "link" for one of the two, "game" for neither.
0.6.0: with Iron Brew, Bulbug Boba sits out of your cycle (out_with_power);
back in town it's back.
0.5.9: trial potion heals as an option, not on (potion_heals = "current"):
"experimental" = Soothing 300 (+30 a Potent Brew level: 600), Bubbling 125 a
sip (250 a charge; 500 at Potent Brew 10), Misting 350 (700);
"experimental_375" = the same with Misting 375 (750). The talent screen and
the potion descriptions show the set's numbers.
0.5.8: the tonic menu's details text is bigger: name 64, description 54,
buttons and cycle line 40 (were 44 / 36 / 32). A long text still shrinks to
fit its box; when the box is full the buttons and cycle line shrink with it
(they used to stay big and squeeze the description down to 0.3). Two players:
the details box is a little taller (440, was 360). Setting: menu_text_size.
0.5.7: the potion descriptions (the tonic menu, tooltips) show the real heal.
They showed Bubbling Brew and Misting Mixture with the whole Potent Brew bonus
(5 points: Bubbling "225 a sip", Misting "155 a heal"); the heals themselves
always used the share (162 a sip, 45 a heal). The description asks the game for
a power item, which has no .def (only GetDef / id), and the share check only
read .def. Both are read now.

0.7.5: the size tonics reach your allies. Drink with Shrink (smaller, faster,
takes more damage) or Juggernaut (bigger, slower, hits harder, takes less) as
your tonic, and the allies within your potion's reach (where its heal reaches
them: 6 plus talents) shrink or grow with you, for the room like you, with the
game's spore burst on them (the size mushrooms' and the Head Hunter's). They get
it the game's own way of giving an ally a power (as the Head Hunter Juggernaut
power buffs allies), so it works online too. The log: "[Tonic Swap] size tonic
(smallify): 1 ally in reach got it too". tonic_size_allies = false: only you
(the game's). tonic_size_allies_minions = true: summoned and charmed fighters too.

0.7.6: the potion heal log (potion_heal_log) is off by default (a probe for working out the heal numbers).

0.7.7: Misting's heal beam to a far ally no longer gets huge. The game's beam
(Gourdo's seed beam) scales its width with its length, fine for Gourdo's few
units; a linked ally across the room got a thick smear over half the screen
(user video). Now the beam is still the game's (its anim, length, direction,
spawned the game's way), with its own width (the anim's height) thinner past
6 units, down to 0.3 of the game's, and its colour fading from 8 units to 0.3
visible at 30. Past 50 units there's no beam; the ally still gets the heal and
the glow. misting_beam_thin = false: the game's beam at any distance.

0.7.8: Misting's heal beam to a far ally is no longer a stretched, blurry
picture. The game's beam is one small picture (a wavy ribbon about 320 x 60
pixels): it's drawn bigger the longer the beam (the large beam is the same
ribbon scaled 2 to 2.7 times, then up to 1.7 times more), so across the room
it was blown up 3 to 5 times, and 0.7.7's thinner width made it look
stretched. Now (misting_beam_style = "chain") a far ally gets a chain: the
line is cut into pieces of about 6 units (misting_beam_piece, at most 8
pieces), each drawn by the game's own beam code with its small-beam table,
the ribbon at the size it was made for, one after another from you to the
ally 0.04 s apart (misting_beam_ripple; 0 = all at once). Allies within about
9 units get the game's beam as it is. Still fainter far away on your screen,
and no beam past 50 units. "thin" is 0.7.7's beam, "game" the game's.
misting_beam_thin = false (0.7.7's setting) still means the game's beam.


0.7.9: the HUD's Bubbling Brew and Misting Mixture icons, full and empty,
have more contrast (potion_hud_icons = "mix"): the game's full icons and the
mod's empty ones mixed half and half with a Soothing-like version (solid glass,
richer fluid with a darker rim, white shines, a thicker outline), so they read
like Soothing's on the dark HUD. In the mod's atlas next to the old ones:
"classic" brings back 0.7.8's (the game's full icon, the dark empty one),
"game" the game's own both. Only with potion_bottles = "own"; the game's
potion widget draws them (the item's ui_icons), nothing runs per frame.

0.7.10: the talents' potion picture (the bottle next to Field Medicine's
number at the Wellspring) uses the "mix" icons too (the same crop of the mix
full icon, in the mod's atlas). Pictures inside texts (descriptions, the
talent summary) stay the game's bottle: a text can only show the game's own
atlases. The save menus' potion counter draws the HUD's icon, so it follows
potion_hud_icons by itself.
0.7.11: the tonic grid in rows by colour (user mock-up): blue Bulbug Boba
(shield), Freeze, Run speed; red the popping candy and the two projectiles;
yellow Shrink, Grow, Damage. The D-pad cycle goes the same way. Freeze and Run
speed are drawn blue and Grow yellow, like the rest of their row: the game's
icons recoloured to the palette of the row's own icons (each icon's three
levels, the candy's side, its top and the raised picture, matched to the same
levels of Bulbug Boba / Shrink and the Damage tonic; the outline, shading and
speckles stay the game's), in the mod's atlas images/tonicswap_tonics. They're
set on the tonics themselves, so the menu, the HUD and the inventory all show
them. tonic_colours = false: the game's icons. The order is the settings'
order list (tonicswap_settings.lua).
0.7.12: Ice Cold Slushie with two potions drunk quickly (user 2026-11-13:
"tapping quickly to drink 2 yellow potions interrupts the first freeze nova
animation"; Bubbling Brew's sips each bring the tonic too). A freeze that
comes while your last one is still playing out (its frost burst, 0.6 s, and
its freezes) now waits for it and then plays in full right after: its burst,
its sound, every enemy frozen again. One that comes within 2 seconds after
keeps the same style ("browse" moves on to the next only after a pause).
Before, the second one started at once with the next browse style, so its
burst cut over the nova and the ripple / chill froze enemies late.
0.7.13: the Alchemist's Gem no longer refills your potion (user 2026-11-13:
"buying at the market refills all potions / finishing a hunt refills all
potions / some powers fill all potions in repeat ... the power with the cheese
that refills"). The Alchemist's Gem is the gem version of Perfect Pairing; its
text is only "Increased Potion effectiveness", but it ran the power's refill
with the gem's numbers, which have no charges, and the game reads a refill with
no number as "refill everything". The game sets your gear's powers up again
whenever they change (a weapon or armour bought and put on at the market, your
gems levelling up at the end of a hunt, Two Weapons' both-weapons gems when
your gems or weapons change), so each time: a full potion. Now the gem is set
up as already refilled: it only heals more. The Perfect Pairing power itself
still refills 1 / 2 / 3 charges when you take it, as the game. The game's other
refills are untouched (the potion shop, Double Pour, Flash Freeze Flask, the
curses, Immorel's armour). gem_refill_fix = false: the
game's.
