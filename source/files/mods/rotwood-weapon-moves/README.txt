Weapon Moves 0.2.22 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Moves the game has finished animations for but never uses. Each one can be
switched off in scripts/weaponmoves_settings.lua (true = on, false = the
game's own way). Changes take effect the next time a run starts.

HAMMER: THE SPIN FINALE (hammer_spin_finale)
The hammer's spin (the Lariat) has an ending the game animated but never
plays (UNUSED_hammer_big_atk1_pst). The spin itself is the game's:

  roll, then X with the stick pulled back the way you came
     the fade-away swing (a hop back with a swing)
  then Y (during or right after that swing; hold Y for more spins)
     the spin

(Roll, then Y with the stick pulled back is the sliding golf swing, and
roll + Y forward is the jump slam: neither is the spin.) In the game B does
nothing while the spin goes (only the dodge works). Now:

  B during the spin: its wind-up, its loops, or its ending's first 8 frames
  (the ending's spin, the same as a loop's; at frame 8 it swings the hammer
  down: the point of no return, B after that does nothing). A B pressed just
  before the spin starts counts too.
     the spin you're in finishes first (the wind-up or the loop to its end),
     then: one more spin (in front, then behind), a big rising swing in front
     that knocks down and back; the hammer carries you up into the air, you
     land with it on your back. From the ending, the rise takes over at its
     frame 8 (no extra spin: the ending's first frames were it).

- The spin hits use the spin's own numbers for how far it got; at full
  length the hits are Focus hits, like the game's own spin ending.
- The extra spin has the loop's swipe trails and spin sound; the rising swing
  a swipe trail for its low sweep and a glowing trail that follows the hammer
  up (the animation's own smear, painted like the gold hammer swipes, a bit
  narrower than the hammer; it stays where it was swung, still reaches the
  hammer as it goes over, and dies out in the 4 states of the game's swipes;
  other colours of swipes: tinted to match), the golf
  swing's whoosh, and hits 1.15x harder
  than the spin.
- The rising swing can hit everyone once, even those the spin just hit.
- While you're carried up (frames 17-40), ground attacks pass under you; you spin
  in the air in a whirlwind (the Windmon's wind spin, hammer_air_spin_fx).
  After the swing (frame 18) a hit can knock you out of it.
- Dodge opens right after you land (frame 42), attacks and moving at 46.
- After the landing (hammer_finale_landing): "back" = the hammer stays on your
  back (the game's sheathed stance, as in camp; your next attack draws it);
  "hand" = you draw it (the game's quick unsheathe, any input cuts it short);
  "auto" (the default) = back in camp, hand on a run.
- Skill Slots' other slot buttons don't trigger it, only B.
- B in the hammer's other heavy attacks (the golf swing, the jump slam...)
  does what it always did; the first 3 times, the log says the finale is
  from the spin ("[Weapon Moves] B in ...: no finale there").

BOW: THE LEAP SHOT (bow_leap_shot)
The bow's animation files have a rolling shot the game never plays
(bow_roll_light_atk): out of the roll you spring up, draw on the way up,
shoot level from the top of the jump and land. It's fully animated, with its
own sounds and muzzle flash; the kneel shot replaced it.

  X in the middle of a roll        the leap shot (new)
  X at the roll's landing          the kneel shot (the game's)
  X during the roll, stick back    the back-flip shot (the game's)

- Same charge levels as every bow shot, and it fires when you let go: let go
  early = quick shot, on the flash = Focus (goes through enemies), hold on =
  full charge, and it fires by itself if held too long. While charging you
  stay at the top of the jump.
- It carries the roll's momentum forward (farther out of a light-weight dash).
- From the moment you leave the ground until you land, ground attacks pass
  under you (like the back-flip shot).
- The arrow leaves from the bow (2.65 up, where the bow is as you let go)
  and flies straight and level. Its hits are checked as for a normal-height
  arrow, so it hits every enemy a standing shot hits (the game lets a high
  arrow hit only enemies about as tall as it is).
- Follow-ups and cancels are the back-flip shot's: after a Focus shot X / Y
  come out sooner; dodge, skill and walking open at the same frames.
- Powers that change bow shots work on it like on any light attack (Volley
  Shot, Skillshot, primed arrows, Hypershot's rapid fire...).
- Heavy weight: the hop takes its attacks at the landing (the game's way), so
  X there stays the kneel shot.
- The log shows "[Weapon Moves] Bow: leap shot on" at load and
  "Bow leap shot (FOCUS, momentum x0.8)" for the first 20 leap shots.
- If a game update changes the bow's roll shots, the log says "Bow leap shot
  skipped (...)" and the bow works the game's own way.

FILES
modmain.lua, scripts/weaponmoves/main.lua (settings, log), scripts/weaponmoves/
bow.lua (the leap shot), scripts/weaponmoves/hammer.lua (the spin finale),
scripts/weaponmoves/presslog.lua, scripts/weaponmoves/guard.lua,
scripts/weaponmoves_settings.lua, anim/weaponmoves_hammer_smear.zip (the
upswing trail art).

0.1.0: the Bow's leap shot.

0.1.1: bulletproofing: an error inside the leap shot is logged ("[Weapon Moves]
error in ...") and you go back to standing, instead of the game's error screen
ending the run. guard = false in the settings: the game's way.

0.1.2: the leap shot's arrow flies level from the start, at the back-flip
shot's height (2.0, the game's own height for a shot from the air; it still
hits nearly every enemy). It used to leave the bow at the top of the jump
(2.65) and drop to normal height over its first 3 ticks, which looked like a
glitch (Bow.DIP = true and Bow.ARROW_Y = 2.65 in bow.lua bring that back).

0.1.3: the leap shot's arrow leaves from the bow (2.9, measured from the
animation's release frame) instead of under it (2.0), straight and level, and
its hits are checked as if it flew at 1.5, so it still hits short enemies.
Bow.ARROW_Y / Bow.HIT_Y in bow.lua (HIT_Y = nil: the arrow's real height).

0.1.4: the leap shot's arrow a little lower: 2.65 (0.1.3's 2.9 was a bit high).
Still straight and level, still hits short enemies.

0.1.5: the leap shot's hit spark shows where the arrow hits (at the arrow's
height), not lower down where a standing shot's would be. (The game puts the
spark at the height it uses for the hit check, which the leap's arrow sets to
1.5 so it still hits short enemies.)

0.2.0: the Hammer spin finale (B during the back-roll spin), above.

0.2.1: the spin finale's input, made clear and easier: the spin is roll, X
with the stick pulled back, then Y (0.2.0's text said "back-roll, then hold
Y", which is the golf swing, not the spin). B now also works through the
ending's whole last swing (frames 0-9, was 0-5) and a B pressed just before
the spin starts counts (the game keeps a press 6 frames). B in the other heavy
attacks says in the log where the finale is.

0.2.2: B in the spin's ending works until the game lets you act again (frame
18, 23 or 24 of the ending, by how long the spin was). Before, a B after the
ending's swing (0.2.0: frame 5, 0.2.1: frame 9) was kept by the game and fired
your skill the moment the recovery opened: the skill instead of the finale.
The spin's Focus count carries into the finale from the ending too. Tested on
the game's own stategraph engine (stategraph.lua) tick by tick.
0.2.3: a press log for the hammer (hammer_input_log, on): with the hammer in hand each
X / Y / B / dodge press writes a line to client_log.txt, e.g. "[Weapon Moves] hammer: Y
in roll_pst frame 3, stick 175 deg from where you face (back) ->
reverse_heavy_attack_sliding": the move you were in, where the stick pointed compared
to where you face, and the move the game went to. The golf swing (roll, then Y with
the stick back) and the fade-away swing that starts the spin (roll, then X with the
stick back) need the stick more than 100 degrees from where you face; the log shows
what the game saw. The first 60 presses of a session. false turns it off.

0.2.4: the spin finale never came out in the game (B in the spin did nothing, then
the skill fired when the spin ended). The game gives each kind of entity its own
copy of a weapon's moves (entityscript.lua LoadStateGraph copies the stategraph per
prefab), and 0.2.3 checked "is the player in this exact spin move?" against the
original, never the copy the player is in. It now checks the move by name. Same fix
for the queued-B start and the log note for B in the other heavy attacks. The tests
now run the player on the game's own copy (they used the original, which is why
they passed). The press log keeps 150 presses and skips dodges from running or
standing.

0.2.5: B in the spin no longer cuts the spin you're in: the finale starts when
that spin comes round (the wind-up's or the loop's end, where the game would go
into its next loop or its ending; in the ending, its frame 12). The extra spin
has the loop's swipe trails (the game's fx_hammer_big_atk1 / _back, which the
game attaches by animation name, so the unused animation had none) and its spin
sound may play beside one still ringing; the rising swing gets a swipe trail for
its low sweep, the golf swing's whoosh (Hammer_Atk_Reverse) and 1.15x damage. The landing puts the hammer on your back (the
animation does), then hammer_finale_landing: "back" makes it the game's sheathed
state (its idle matches the animation's last frame), "hand" draws it with the
game's hammer_unsheathe_fast, "auto" = back in camp, hand on a run.

0.2.6: a check in the log for the spin finale's swipe trails (they didn't show in the
game): the first 2 finales and the first 2 spin loops write "[Weapon Moves] finale fx
check ..." lines: the trail entity, valid, attached, where, its animation frame.

0.2.7: the rising swing's upswing gets a trail. The game has no swipe effect for
it (its rising-swing swipe was never drawn); the animation itself has a smear
that follows the hammer up, drawn with the hammer bank's own art, which the
game never shows. For frames 17-21 of the finale that one smear is shown,
tinted like the weapon's swipes (gold, fire red, frost / electric blue, fancy
violet) and glowing, then hidden again. The 0.2.6 log check showed the other
trails work (the extra spin's and the low sweep's), so it's gone again.

0.2.8: when the upswing starts (frame 17) the finale's spin trails still playing go
(the rise's low sweep went on circling on the ground under you while you rose):
the attached one is detached and removed the game's way, the let-go ones come
off the state's own stop-on-exit list. The low sweep shows while the hammer is low.

0.2.9: the upswing trail is painted like the game's hammer swipes: the gold
edges, the grey-green middle with its darker stripe (the colours measured from
the swipes' own art). anim/weaponmoves_hammer_smear.zip is the hammer bank's
smear build with each of its 16 smears painted that way (same shapes, same
frames); it's shown unlit like the swipe effects, with a glow. Weapons whose
swipes aren't gold (fire, frost, electric, fancy) still get the plain smear
tinted their colour.

0.2.10: the upswing trail closer to the game's swipes: clean gold outer band,
the light grey-green middle, a wider dark grey band toward the inner side and a gold
inner rim (bands 36 / 30 / 16 / 18% across), and drawn the way the game draws its
gold swipe effects (darkened to 0.6, full glow of its own colours, unlit) instead of
a gold glow on top.

0.2.11: the upswing trail a bit narrower (about 55% of the smear's width, cut
from the inner side) so the hammer shows beside it, and it dies out like the
game's swipes: solid for 2 frames, then see-through (alpha 0.5, 0.5, 0.42, 0.26,
the game's hammer swipe frames measured; its glow fades with it) through frame 22,
the animation's last smear frame. The fresh trail stays solid, as the game's
fresh swipe frames are.

0.2.12: the upswing trail dies out in the 4 states of the game's swipes (as
measured on the game's hammer swipe frames): frames 17-18 solid; 19-20 the solid
gold / grey part narrower along the outer edge, gold at 30% alpha where the rest
was; 21 only a short thin solid gold strand with a much narrower 30% gold overlay;
22 just a faint gold strand (the same art at 0.3 alpha). States 1-3 are in the art,
one per smear sprite of the animation.

0.2.13: the upswing's big arc stays where it was swung and dies out there, as the
game's swipe effects do (0.2.12 played the states on the animation's later, smaller
smears that follow the hammer up, so the last states were small, thin and flat, and
the forked smear had rough double ends). Frames 17-18 solid; 19-20 the solid gold /
grey edge narrower (the tail end goes see-through first), a thin solid gold streak
inside, gold at 30% alpha where the rest was; 21 a short thin solid gold strand at the
arc's newest end, the 30% gold much narrower, a faint streak beside it; 22 one faint
curved gold strand. Nothing wraps round the arc's head. Swipes that aren't gold get
the same arc in greys, tinted (instead of the plain smear).

0.2.14: the dying trail stays connected to the hammer: frames 19-22 draw the trail
swung so far (the upswing's arc where it was, plus the animation's follow-through
smears up to where the hammer is now), painted as one curved trail in each die-out
state, so the solid strand of state 3 and the faint strand of state 4 run up to the
hammer.

0.2.15: Focus sparks (hammer_focus_fx). The game's Focus swings throw cyan spark
glints (its charged golf swing and overhead slam: the fx_hammer_charge_glint art, only
spark flecks the game glows cyan). The game made one for this spin,
fx_hammer_big_atk1_loop_front (sparks along the front sweep, then the back sweep,
lingering), but never plays it. Now a Focus spin (it hit more than one enemy, or it's
at full length) gets it on every loop and on the finale's extra spin, attached the way
the game attaches its Focus swipes (then left to play on where it is), and a Focus
rising swing's trail carries the same cyan sparks (thinning out as it dies). The spin's
full-length ending keeps the game's own cyan glint. hammer_focus_fx = false: off.

0.2.16: the Focus overlay: the game's Focus glints also draw a cyan swipe that adds light
(additive: their swipe sprites have alpha 0 and a cyan colour), not only sparks; a Focus
rising swing's trail now has it too: cyan streaks over the band's grey part and a soft
cyan halo past its inner edge, then cyan through the see-through gold as it dies (kept
off the solid gold, which it would burn to white). The spin's loops and the extra spin
already get it from the game's own glint. And the spin in the air (hammer_air_spin_fx):
the animators drew a spin smear for it that no build has art for; instead the Windmon's
wind spin (the whirlwind of the Greatsword's flourish, and of Owlitzer's perfect dodge in
Boss Passives) whirls round you from frame 18, riding on you as you rise and come down,
and ends as you land. A Focus glint or a whirlwind that fails to spawn is skipped (the
move goes on).

0.2.17: a Focus rise gets the Focus glint's look (the game made none for it): a
see-through light cyan swipe over the area the rising swing sweeps (beside the gold
trail, which stays gold), bright cyan streaks dashing along it, and spark flecks that fly
on along the swing, drift down and fade by the landing; the swipe narrows and fades with
the trail. Drawn on a symbol the finale places but never had art for (fx_twirl01_untex),
glowing cyan like the game's glint (the trail's own added cyan from 0.2.16 didn't show in
the game). hammer_focus_fx = false: off.

0.2.18: the Focus rise's look redone after seeing it in the game: the light cyan band and
its dashed streaks are gone, and the sparks are now the game's own: the spin glint's
spark sprites (the ones on a Focus spin loop), with their sizes, stretch and turns frame by
frame, laid along the rise's arc instead of the spin's sweep. Like the game's they stay
where the swing went, spread a little and shrink away by the landing (0.2.17's flew off
everywhere). hammer_focus_fx = false: off.

0.2.19: the rise's Focus sparks are now the golf swing's (its Focus glint): they come with
the swing and run along the whole trail all the way up to the hammer (the follow-through's
part as the trail gets there), then drift and fade where they are by the landing, behind
the hammer; none show up later near the ground in mid-air (the spin glint's back-sweep
sparks did). A Focus rise keeps the plain gold trail under them. The upswing trail is smoothed: its outline is
drawn at 3x and evened out, and its width runs smooth along the arc, so the curve and the
die-out lines have no rough or jagged edges.

0.2.20: the rising swing no longer plays the charged golf swing's Focus whoosh on a Focus
hit (Hammer_Atk_Charge_Focus_Whoosh: the metal clang at the top of the rise); its swing
whoosh stays.

0.2.21: the point of no return. The game's spin ending is the loop's frames 0-7; at
its frame 8 it leaves the spin (the hammer swings down behind you and is on the ground
by 12). B now only counts before that: the finale takes over right at frame 8, from
its own frame 8 (the hammer behind you in the same place, then up into the rise; no
extra spin, since the ending's first frames were that spin). Before, B counted until
the ending's recovery opened (up to frame 23) and the finale started from the ground
pose at frame 12. B from frame 8 until the recovery opens is used up: no finale, and
no skill firing later from it. Once the recovery is open, B is your skill as usual.
The rising swing now knocks back too: its knockdown sends what it hits
hammer_finale_knockback times the game's knockdown distance (3.5, the game's own
knockback number for the spin's last round; the game's knockdowns never used it, so
they all went 1x). 1 = the game's distance, 0 = none.

0.2.22: hammer_input_log (the hammer press log) is off by default now: a diagnostic, turn it on when a move doesn't come out.
