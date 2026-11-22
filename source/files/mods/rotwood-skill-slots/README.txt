Skill Slots 0.16.4 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Buttons
  B          weapon's own skill by default (changes with the weapon, like vanilla)
  LT         Fist Pound (buffnextattack: crit chance until your next crit)
  RT         Throw Stone
  RS-click   parry (free for a skill: Controller Layout moves build to
             D-pad down). With the Cannon in hand: Dodge (see below)
  Keyboard:  U / I / O for LT / RT / RS
  These are the defaults until you pick in the menu; picks already saved
  with a character stay.

Skill slot menu
  Build a skill station and press interact (RB, "Customize Skills") on it, or
  press H on the keyboard in town (H alone: Ctrl+H is Controller Layout's
  overhead key). Each player can open it. (The controller
  has no menu button by default now: D-pad down is build, D-pad up customize
  town. menu_button in the settings can take one.)
  The blacksmith's weapon racks (by Hamish's forge, one per weapon): hold
  interact (RB) on a rack whose weapon you've unlocked: "Customize Skills". A tap
  still opens your weapons. A rack still taking corestones is the game's deposit
  only (tap and hold both deposit there). rack_menu = false turns it off.
  The weapon rack inside Hamish's forge (the hut): stand by it and press interact
  (RB): "Customize Skills" (the forge building highlights). forge_rack = false
  turns it off.
  Stations:
  Rugged Weapon Rack, Rustic Weapon Rack, Pergola, Wintertide Tree, Kuma's Scare-Rot.
  The mod unlocks them in the build menu: racks, Pergola and Kuma's Scare-Rot
  are on the Town tab, Wintertide Tree on the Flora tab. Building one still
  costs its materials (racks and Kuma: 2 elite-monster drops,
  Pergola and Wintertide Tree: 3 boss drops).
  The menu works like the Emote Booth: pick a slot (B, LT, RT, RS), then pick
  a skill. "Weapon skill" (first in the list) is the weapon's own skill; put
  it on another button and B is free for something else.
  Each weapon type has its own loadout of all four buttons, so switching
  weapons (Two Weapons swap included) switches the skills. The menu shows and
  sets the loadout of the weapon in hand. With Two Weapons, LS (keyboard R)
  in the menu switches your weapon, and the menu shows that loadout.
  Weapon skills (Hammer, Spear, ...) only fire with that weapon in hand. On a
  slot they rest while you hold another weapon (handy with Two Weapons).
  Skills that need another weapon sit at the bottom of the list.
  X (keyboard Shift) / "Skill info": a popup the size of your panel with the
  skill under the cursor: big icon, which weapon it needs, whether you own it,
  which button it's on, the full description with its numbers and keyword
  explanations (plain text like the game's equipment screen, no highlight
  bar). A, B or X closes it.
  The menu always opens with "Hide unavailable" on: it hides other weapons'
  skills and the skills you don't own (owned = comes with a weapon in your
  inventory, or you have it right now; the few skills no weapon gives, like
  Banana Peel and Throw Stone, only show with Show all). Boss and miniboss
  skills, and Parry (Bandicoot's), count per weapon type: every one of those
  bosses has a weapon of each type, and a weapon's loadout lists the skill
  only if you own that boss's weapon of that type (Owlitzer's Spear owned:
  Owlitzer's skill in the Spear loadout, not the Hammer's).
  "Show all" (RB, keyboard E) lists every skill until the menu closes, and any
  of them can go on a slot, owned or not; the details say when you don't own one. Owning is
  only this filter: every skill works on a slot either way.
  Boss and miniboss skills work with any weapon (the game marks Thatcher's as
  Bow-only, a slip in its data: B fires it on every Thatcher weapon).
  "HUD icons": shows / hides the LT / RT / RS icons on this player's HUD
  "Names" (LB, keyboard Q): shows / hides the names over the list's skills
    ("Hammer", "Any", "Miniboss"...), off each time the menu opens
    (list_names = true in the settings file: on)
  (B's skill icon always stays).
  View button (keyboard Tab): Two Weapons' swap attacks on / off for this
  player (only shown with Two Weapons).
  All the buttons under the list (Skill info, Clear slot / Use weapon skill,
  Hide unavailable / Show all, HUD icons, Swap attacks) can be reached with the D-pad or
  stick: go down from the list.
  Size: with 1 or 2 players the panel is taller than the game's, with bigger
  icons (4 to a row in the list). With 3 or 4 players the panels sit in two
  rows that already fill the screen, so they keep the game's height and use
  another layout: the slots in a 2 x 2 grid with the skill details under them,
  the list on the right top to bottom with big icons, 4 to a row (the skill
  names show in the details when you move onto a slot).
  The skills are round, so they have no square background: the round skill
  fills its spot (an empty slot keeps the square).
  Y clears the selected slot (on B: back to the weapon skill). A skill can only
  sit on one slot (picking it for another slot swaps the two). Your picks are
  saved with your character.

Mannequin loadouts
  The game's loadouts (the mannequin: Claim & Save, Quick Equip; the loadout
  screen) save your gear, potion, tonic, Hunter's Path talents and gems. They
  also save your skill buttons now: every weapon type's B, LT, RT and RS
  (and Block / Dodge / Reload). Equipping the loadout puts them back.
  Like the gear, skill changes count only once you save the loadout again:
  switch to another loadout first and they're replaced by that one's.
  The Hunter's Path screen saves the loadout by itself when only talents
  changed; that save keeps the loadout's skills as they were.
  Loadouts saved before this keep whatever buttons you have.
  mannequin_loadouts = false in the settings turns this off.

HUD
  The four skills sit in a cluster next to the portrait, like the
  controller: RS and RT on top, B and LT under them, every icon with its
  button (B's is the game's big skill icon). The weight class becomes a small
  badge after your name, like the weapon badge in front of it: an arm (heavy),
  scales (balanced) or feathers (light), from the mod's images folder. The power rows
  (drawn 1.3x the game's size, 8 past the skills: hud.cluster.power_scale,
  power_gap; the skill icons 1.1x: skill_scale) and the town's weapon
  tips move past the cluster (left of it on right-side HUDs). hud.layout = "zigzag" in the settings brings back the game's
  honeycomb with the slot icons along the screen edge, "row" a row next to
  the skill icon.
  Slot icons show the game's skill number (cooldown seconds, stacks), and
  with Skill Limits on, a skill out of uses goes grey with a red X there too.

Settings: scripts\skillslots_settings.lua (defaults, station list, keys, HUD).
Log lines start with [Skill Slots] in client_log.txt. If a game update renames
something the mod hooks, it switches itself off and says what changed.

Weapon choices: a weapon's own move on a button
  A few weapon moves are choices in the skill list (that weapon only, first
  among its skills). On no button = the game's way. Settings say where each
  starts (greatsword_block, cannon_dodge, cannon_reload); picks in the menu win.

Greatsword: Block (LT, RT, RS or B; starts on no button)
  The Greatsword blocks with the dodge button and no direction. With Block on
  one of its buttons:
    - that button blocks: press or hold, panic block out of an attack (also
      with the stick held), dash block after a roll;
    - the dodge button always rolls: with no direction, forward, like every
      other weapon. Holding it never blocks. (During heavy attacks it still
      does the Greatsword's Bash, which counts as a dodge.)
  Block on B: B only blocks, and fires no skill. Put the Greatsword's skill on
  LT, RT or RS ("Weapon skill" in the list): the Greatsword's attack-into-skill
  combos follow it to that button. The big skill icon shows Block.
  Clear it (or move it off every button) and the Greatsword is back to the
  game's way. The HUD shows Block's icon on its button.

Block, Dodge and Reload have their own round skill icons (images folder),
drawn in the style of the game's skill icons.

Cannon: Dodge and Reload (B, LT, RT or RS)
  The game's Cannon has no roll: its dodge button plants the cannon (press it
  again while planted to reload) and its dodge is the heavy attack (Blast).
  Its animation files still have a finished roll the game never plays.
    - Dodge on a button: that button rolls, like every other weapon (the
      normal-weight roll animation; distance and speed from the game). Its
      invincibility is a normal roll's (12 frames at normal weight, 7 light,
      10 heavy) plus cannon_roll_iframes: 0 = exactly like Bow / Striker,
      1 = like Hammer / Spear / Greatsword. Blast keeps the Cannon's own bonus.
      The dodge button stays the Cannon's: plant, reload. Starts on RS
      (cannon_dodge).
    - Reload on a button: that button plants and reloads, everywhere the
      dodge button did (after a Blast, out of a knockdown...). The dodge button
      rolls instead. Starts on no button (cannon_reload).
    - On B: B only plants / reloads (or rolls, with Dodge on B) and fires no
      skill. Put the Cannon's skill ("Weapon skill") on LT, RT or RS. While
      planted, any skill button fires Backfire, as B does in the game, the
      whole time you stay planted (hold it to aim, let go to fire).
      Example: Reload on B, skills on LT / RT / RS: A rolls, B plants and
      reloads, LT / RT / RS fire Backfire while planted.
  Both on buttons: the dodge button and Dodge's button both roll.
  Roll into an attack, like the other weapons: light or heavy during the roll
  (or a press buffered in it) goes straight into one of the Cannon's own
  attacks, at the same moments the Hammer's roll-attacks come out:
                mid-roll, ahead      mid-roll, stick back      landing, ahead   landing, back
    light (X)   Air Shot             turn, Air Shot behind     normal shot      turn, Battering Ram swing
    heavy (Y)   Quick Rise (punch)   turn, Air Blast           Blast            turn, Blast
  Mid-roll = press during the roll; landing = press as you come out of it.
  Stick back = hold the stick away from the way you rolled. The swing is the
  Battering Ram skill's move (cannon_roll_swing = false: a normal shot
  behind instead). The first 30 roll attacks write a line to the log
  ("[Skill Slots] Cannon roll ...") to check them in game.
  The Air Shot keeps the roll's momentum (forward, or backward after turning);
  the Air Blast launches you on in the roll's direction, and a turned Blast as
  you land is a long dash forward. Then the game's own chains: after an air
  attack X = Air Shot, Y = Air Blast. Every shot spends ammo; with none, the
  game's empty versions. cannon_roll_combos = false: normal shot / Blast all
  through the roll (the Cannon has no rolling attack animations, so these are
  its own attacks, no blend).
  The roll goes wherever the game takes a dodge press (standing, a dodge
  cancel window, out of a plant before its next shot, getting up from a
  knockdown) and never plants or reloads. Heavy (Blast) and B (the Cannon's
  skill, and Backfire while planted) are unchanged.

Sedament crow: the crow is only there while one of your buttons uses the
Sedament skill ("Weapon skill" on B counts), with any weapon. Before, the
Sedament weapon always brought it, even with its skill on no button.

Boss skills on several buttons: some boss skills react to any skill in the
game (one skill per player there). Mother Treek's roots came out with any boss
skill (Owlitzer's wings on RT fired both), Sedament's crow got its buff from
any boss skill, and any skill button pressed during a heavy attack charged it
with the weapon's boss skill. Now each one only reacts to its own button.

Game fix: some skills (Order in the Court and others) let the skill button in
again a few frames into their own swing, so pressing it again restarted the
skill from its first frames over and over. Now a press for the skill that's
swinging waits until the swing has played out, then the skill starts again.
Other skills, attacks and dodges still cancel it. finish_skill_swing = false
in the settings goes back to the game's way.

Two of the Bow's primed-arrow skills slotted together (Toxic Dip, Cold
Plunge): the game had them all answer any priming, so both buttons gave the
same arrow. Now each button primes its own arrow, and priming one un-primes
the other (one primed arrow at a time, like the game).

Big Blast (the Cannon's skill) on LT / RT / RS: the game makes the shot big
only while the skill it has on record is still Big Blast as you let go, but
a slot press put B's skill back right after the press, so letting go fired
the plain Blast (the heavy attack). Now letting go of the slot button fires
the real Big Blast (and Skill Balance's big shell); B's skill goes back
right after. The log says "Big Blast on LT / RT / RS fires the real Big Blast".
0.14.4: the skill menu's look. The slot being changed gets an outline that follows
the round skill, hanger and all (a dark line, the selection green, a dark edge: the
game's own way of outlining a skill, its frame drawn bigger behind it) instead of the
square; an empty slot keeps the square. No green square on the skill under the cursor
in the list (the cursor's corners and the check mark say enough). The loadout's
weapon type icon (the game's, from its "Select weapon type" menu) sits top right of
the panel and changes with a swap, and a skill only one weapon can use has that
weapon's icon after its name (the slot names and the details under the list).
0.14.3: the weapon rack inside Hamish's forge opens the skill menu: press RB standing
by it. The rack is part of the forge building's art (the "rack" symbol of its back
layer), so the forge itself becomes a station (the same interaction as the other
stations), reaching far enough to stand by the hut, and only while you stand within a
few steps of where the rack is drawn (found on the building as it stands, so a moved
or flipped forge works too). Hamish's own interaction (his gems) is on the other side.
0.14.2: the skill menu's details: a skill you don't own (Show all) gets the game's
lock icon after its name instead of the "You don't own this ... yet" sentence, and
the details show the description's main paragraph only. The rest (a skill's rules:
stocks, recharge; the game's second paragraph) is on the Skill info page (X).
0.14.1: the town's weapon tips sat in the middle of the screen again: they lined up
past the extra lives (the wings at the health bar's end), but the game hides the
health bar while the tips show, so they followed the far end of a hidden bar. They
now go right past the skill cluster, level with its top (its bottom on the bottom
HUDs), below the name's line where the lives stay.
0.14.0: the blacksmith's weapon racks open the skill menu: hold RB on an unlocked
rack (the game's own tap-or-hold interaction and hold ring, for that player only; a
tap still opens your weapons, a rack taking corestones is untouched). With 2+
players the town's weapon tips stay in their player's half of the screen (player
1's ran into player 2's): tips that would reach past the middle are drawn smaller
to fit (hud.tips_margin, hud.tips_min_scale). The skill menu's description shrinks
to fit above the buttons in the 1-2 player layout too (it ran under them).
0.13.11: the power icons 1.3x (1.2x was too small, 1.35x too big).
0.13.10: HUD (cluster layout): the skill icons a bit bigger (1.1x), the power
  icons smaller (1.2x the game's, was 1.35x) and closer to the skills (8, was 24).
0.13.9: HUD (cluster layout): the name stays on the portrait with both badges: a
  long name gets a smaller font (down to 26), then is cut with "..." (the
  class badge was pushed far right, off the screen on player 2's side).
  Right-side HUDs: the name starts at the portrait's left edge like player 1.
  The extra lives (wings) moved to the health bar's end (the cluster's top row
  hid them). Settings: name_fit, name_min_font, name_margin, lives_after_bar,
  lives_gap.
0.13.8: bulletproofing: Skill Slots' part of a button press, a skill, the Cannon
roll, Block, the HUD and loadouts is worked out in a guard: an error is logged
("[Skill Slots] error in ...") and the game does it its own way that moment,
instead of its error screen ending the run. guard = false: the game's way.
0.13.7: a slot press reaches the stategraph as the skill on that slot (the
game reads B's skill there): Big Blast on LT / RT / RS now gets its Cannon
follow-ups (Air Blast out of the roll, the timed big shot on landing, quick
rise from a knockdown), and another skill on a slot no longer fires Big
Blast's follow-ups when Big Blast is on B. Found by checking every skill in
the game for the Big Blast kind of bug (the game reading "the" skill).
The HUD's health bar starts past your name's box (the weapon badge, a long
name and the class badge used to sit under the bar's end: the game starts the
bar at the portrait's edge, and the name box is wider); the dark frame grows
to match (hud.bar_clears_name = false: the game's way).
0.13.6: Big Blast from LT / RT / RS fires the real Big Blast.
0.13.5: the log notes each X / Y press during the Cannon roll (stick ahead / back,
where it went); a false "Cannon stategraph changed" line is gone.

0.14.5: menu polish (the user's notes, 2026-11-11).
  * Skills of no weapon get a class: boss and miniboss skills the game's boss
    icon (the one by kill counts) after their name and a "Boss" / "Miniboss" tag
    on their tile; the rest (Fist Pound, Throw Stone, Parry, Buff Next Attack...)
    the game's any-weapon icon (the Select Weapon title's) and an "Any" tag.
    class_icons = false: no icon or tag for them.
  * The loadout's weapon-type icon sits in the panel's top right corner (it was
    an icon's width further in).
  * "[TEMP] hammer_reflectinglights" (the game's, unfinished: does nothing) is
    never listed, even with Show all. hidden_skills = { ... } in the settings.
  * The weapon's own skill shows its name ("Keeper of the Moon"), without
    "Weapon skill:" in front ("Weapon skill" only when there's none).
  * Block, Dodge and Reload show a short summary in the menu, like the game's
    skills: "The Greatsword's block. Press or hold to Block; the dodge button
    always rolls." (the rest in Skill info, X).

0.14.9: Throw Snowball works on the move (the user: it didn't while moving or
with any stick movement). The game's scoop lets the stick cancel it from its
6th frame, before the throw (frame 16), so moving at all meant no snowball.
Throw Stone, the same animation, has no such frame: the stick waits for the
throw. That frame is taken out of the snowball's scoop now (the game's own
timeline, one entry); after the throw the stick moves you as before.
snowball_finish_throw = false: the game's.
Explosive Dive's prime (the user: the special arrow animation didn't show, so
the pink burst above the head looked unrelated). The dip fx (Hypershot's) is
drawn for the prime animation and hung above the head without it; it's gone.
explosive_dive_prime picks the prime:
  "arrow"   (default) the pink sparks come onto the arrow when the prime
            starts and a short pink burst on the arrow when it's primed; both
            follow the arrow's symbol, so they sit on it whatever the animation
  "vanilla" the game's prime animation and nothing else (the arrow's sparks
            still show it's primed)
  "quick"   the prime animation at twice the speed, then straight into the
            bow's Heavy Attack shot with the exploding arrow
            (explosive_dive_shot: "WEAK", "MEDIUM", "FOCUS" or "STRONG")
Menu: the names over the list's skills ("Names", LB / keyboard Q) are off
each time the menu opens; LB switches them while it's open, and that's not kept
for next time (it was saved per character). list_names = true: on each time.

0.14.8: from the test session (the user's notes, 2026-11-12).
  * Camp: the extra lives icon no longer sits over the weapon tips. Where this
    mod puts the lives (the bar's end, cluster layout) the tips come in on top
    of them; while the tips are in, the lives are drawn see-through and come
    back after the tips fade out. Only their colour's alpha changes: the game's
    lives counter lays out the whole HUD again every frame when it finds itself
    hidden (the old stutter), so it's never hidden.
  * Menu: a long skill description no longer runs under the buttons. The fit
    now measures the name and the description's own lines (0.14.7 measured the
    box around them, which missed the last lines) and measures again after each
    shrink, down to half size.
  * Menu: RB (keyboard E) is Show all / Hide unavailable, its glyph on the
    button. Only a fresh press after the menu opens counts (holding RB at a
    weapon rack opens the menu), once per press.

0.14.7: the menu, from a screenshot.
  * A slot's long name ("Gourdo's Community Garden") stays on one line with its
    class icon at the end: the font gets smaller instead of the icon wrapping to
    a second line (down to 70%; past that it wraps as before).
  * "Names" button (LB, keyboard Q): the names over the list's skills on / off,
    saved per character; list_names = false starts them hidden. A held LB
    doesn't flicker them. (Not RB: holding RB at a weapon rack opens the menu.)
  * Throw Snowball's icon (the mod's own) redrawn centred and 0.9 the size: its
    sparkles ran over the round frame. Same atlas, the other 7 icons untouched.
  * icon_scale (settings): any skill picture that runs over its frame can be
    drawn smaller in the menu, the HUD icons and Skill info (none by default).

0.14.6: two of the game's unfinished skills, finished (skillslots/finishskills.lua).
  * Explosive Dive (the Bow's "[TEMP] bow_primearrow_explode"): your next Heavy
    Attack explodes where it lands (the game's friendly pinecone bomb, which the
    game's arrow already sets off). New: its name and description, its own icon,
    Hypershot's pink dip fx and prime sound, Hypershot's pink sparks on the arrow
    while primed, a pink crit trail on the flying arrow (the focus arrow's sparks
    in crit pink: scripts/prefabs/skillslots_particles.lua). The sparks go away
    once you shoot, and a new room puts back its own sparks (the game's stub put
    Cold Plunge's frost on). explosive_dive = false: the game's stub;
    explosive_dive_trail = false: no trail.
  * Throw Snowball (the game's holiday skill, which ran out after 3 throws and
    then only shrugged "RELOAD!"): endless, each throw scoops a fresh snowball
    off the ground (the throw's own scoop animation). It throws the game's frost
    snowball (from the snow world): knocks enemies back and makes them Cold,
    150 Cold a hit, 600 Freezes (4 hits). Enemies only, no damage (like the
    game's snowball). The snowball is in your hand instead of the stone while
    you throw (the throw shares Throw Stone's animation; the stone is its
    "Symbol 2"; the snowball is the snowball projectile's ball, ice_core_untex
    in fx_projectile_snow_ball, a little bigger than the stone). Its own icon
    and description.
    Settings: snowball (false = the game's), snowball_cold, snowball_damage,
    snowball_speed, snowball_in_hand, snowball_hand_symbol ("" = the ball),
    snowball_finish_throw (the stick can't cancel the scoop, like Throw Stone).
  * The skill icon atlas has the two new icons (8 icons, the first 6 unchanged).
Keyboard H opens the menu only on its own (it opened with any modifier held):
Ctrl+H is Controller Layout's overhead key, which in town opened this menu too.

0.14.10: Cold Plunge and Toxic Dip (the game's frost and acid bow prime): the
spark that hung over your head is on the arrow now. Their dip effect is drawn
for the prime animation, and its spark (the game's prime burst, 4.7 above the
player) floated on its own when that animation didn't show, like Explosive
Dive's did. bow_prime_dip = "arrow" (default): the game's prime as it is (its
frost / acid sparks on the arrow, its primed arrow), only the dip effect left
out, and the game's own prime burst on the arrow when it's primed (Toxic Dip:
each player's colour). "game" brings the dip effect back.

0.14.11: Cold Plunge and Toxic Dip keep their dip's sound and look. 0.14.10 left
the whole dip effect out, and with it its sound (Bow_Prime_Ice / Bow_Prime_Acid)
and its frost / acid trail. bow_prime_dip, three ways:
  "arrow" (default) the dip's own sound, and its own trail and burst (read from
             the game's data: the same particles, frames and times) put on the
             arrow, where the game puts the frost sparks; only the dip's own
             drawing (the part that floated) left out
  "plain"   the dip's sound and the game's sparks on the arrow, no burst
  "game"    the game's dip effect as it is (the spark over the head)

0.15.0: hide / show the power rows (your powers' icons at the top of the
screen), always with a smooth fade (the game's own fade, on the UI's clock):
  D-pad down: that player's own rows, hidden / shown (each player with their
    controller). In runs: in town the game hides the rows anyway and D-pad
    down is the build menu (Controller Layout). D-pad down no longer walks.
  ; (semicolon) on the keyboard: every player's rows hidden; ' (quote): shown.
  Boss fights: when a boss wakes up (its health bar comes up) every player's
    rows fade out, and fade back in when it's beaten or the room is cleared.
    Showing yours yourself during the fight keeps them shown for it; rows you
    hid before stay hidden after.
  Each player's choice stays with their character from room to room.
  Settings (skillslots_settings.lua, hide_powers): gamepad ("" = none),
  hide_all / show_all (the game's key names, modifiers allowed, "" = none),
  boss_auto_hide ("boss", "all" = minibosses too, false), fade_time (seconds,
  0 = at once); hide_powers = false: off.
0.15.1: the keyboard keys for hiding / showing every player's power rows are
now ; and ' (0.15.0 had - and =: with the game's debug keys on, = also hid the
ground and - changed the map overlay). ; and ' aren't used by the game, its
debug keys or the other mods.
0.16.4: the power icons' size (D-pad up: 66% / 50%) is kept in the next
room (user, 00:47: "Power Hide/Show size are being reset when entering the
next room"). The size was saved with the character as a number, but loading
the character kept only on / off choices, so every new room started at full
size (since 0.16.2; hidden / shown was always kept). Numbers load now too.
0.16.3: the power rows also fade out in miniboss fights (user, 23:28:
"minibosses as well"): boss_auto_hide = "all" by default ("boss" = bosses
only, false = never).
0.16.2: smaller power icons stack in more rows (user, 22:53, with a mockup:
"when powers are half sized, I'd like them to stack in 2 rows", then "66%
size that allows for 3 rows is also an interesting idea to explore"). D-pad
up now steps through full size, 66% (3 rows) and 50% (4 rows), then full
again; / does it for every player. The rows fit the height of the game's 2
(rows = 2 / size) and the game's own row filling spreads the icons evenly
over them (12 powers: 3 rows of 4 at 66%, 4 rows of 3 at 50%), so they make
a block next to the skills instead of two long rows. Back to full size: the
game's own 2 rows. small_sizes (default { 0.66, 0.5 }) picks the sizes.
0.16.1: the bow's prime spark is back (user, 22:36: "the bows special arrow
spark is now gone ... either position it correctly when going straight into
the heavy attack animation, or at least play it when doing the reload ...
animation plays"). The game draws the spark (Explosive Dive's pink one,
Cold Plunge's frost, Toxic Dip's acid) for the "arrow raised" animation and
leaves it where it started, so going straight into the Heavy Attack left it
hanging; it had been left out. New default "anim" (explosive_dive_prime and
bow_prime_dip): the spark plays with the prime animation, lined up as drawn;
leave that animation early (Heavy Attack, dodge, run) and the spark goes,
what's left of its sparkle moves onto the arrow (its symbol) for the rest
of its time. The old ways are still there ("arrow", "plain" / "vanilla",
"game" / "quick").
0.16.0: half-size power icons. D-pad up: that player's power icons half size,
so a lot of them stack neater down the side; again: full size (in runs; in
town D-pad up is customize town, and D-pad up no longer walks). Keyboard /
(slash): every player's toggled. A smooth cross-fade (out, the new size laid
out by the game's own layout so the rows stay against the skill icons, back
in), kept with each character from room to room. Settings (hide_powers):
small_gamepad, small_all, small_scale (0.5 = half).
