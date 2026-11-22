Skill Limits 0.5.2 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Stops endless spamming of strong skills that have no limit of their own.

HOW IT WORKS
- A limited skill has 5 uses. Every use takes one and restarts a 5 second
  rest timer. When the timer runs out (5 s after your last use), all 5 uses
  come back. So you can fire it 5 times in a row, then it needs a 5 s break;
  use it now and then and you never notice the limit.
- Out of uses: pressing the skill does nothing (you keep doing what you were
  doing): the game's X pops up over your head and you hear its "no charge"
  sound. The skill icon goes grey (the game's "not available" look) with a
  red X over it, and shows the seconds until the uses are back; the game's
  "charge back" sound plays when they are, and the icon is back to normal.
- Boss skills can also be fired by pressing them during a heavy attack (the
  attack gets charged with the skill). That counts as a use too, and with
  none left it doesn't charge.
- Per player (up to 4), per skill. Swapping weapons or skills doesn't reset
  the uses; a new room starts with them full.
- Works on the B skill and on Skill Slots' slots alike (the slot icons show
  the countdown with Skill Slots 0.6.14 or newer, the grey + X with 0.6.15).
- Charge-up skills (Unstable Equilibrium): one use = one charge-up.

BOW ARROW SKILLS (Toxic Dip, Cold Plunge, exploding arrow)
- Ammo, like the game's Banana Peel / Gourdo's Community Garden: one quiver
  of 2 arrows shared by all your arrow skills (bow_arrow_shared; false = 2
  each). Every special arrow that leaves the bow takes one. Dealing damage
  earns them back: one per 1500 damage to enemies, breakable props or the
  training dummies in town (the game's bananas / garden use 1000), with the
  game's "new stock" effect and sound. The skill icons show the arrows left.
- Quiver empty: one free dip. The button does the game's arrow dip, only the
  dip; when the arrow is up you have 1 arrow, loaded, and the next press
  shoots it (any charge). Then the next free dip waits 15 s
  (bow_arrow_free_dip_cooldown): meanwhile the button does nothing (the X
  over your head, the "no charge" sound) and the arrow icons go grey with the
  seconds left. Earning an arrow with damage works any time.
- Instant (instant_bow_skills = true, the default): the button goes straight
  into the bow's heavy shot. Hold it like the heavy attack button and release
  when the bow is charged for a Focus shot: that shot carries the special
  arrow (1 arrow). Released too early or too late = a normal heavy shot, free.
- instant_bow_skills = false: the game's way (dip, then your next heavy shot
  carries it); the arrow is taken when it's fired.
- The arrows are kept through rooms and weapon swaps like the game's own
  stock skills. A new arrow skill picked up joins the quiver as it is.

LIMITED BY DEFAULT
- Boss skills: Mother of Methuselah, Keeper of the Moon, Voice of the
  Myriad, Eggsplosion (their own limits don't do anything in play: one use
  back after 0.1 s / a cooldown that never starts)
- Miniboss skills: Big Yammo Slammo, Floracrane's Divebeak, Grody Groak Gulp,
  Embison's Turn Around Punch, Bonejaw's Charge
- Charge-ups: Unstable Equilibrium
- Bow arrow skills: ammo (above)
- Weapon skills: Javelin Backstab: throws that miss are free; 2 throws that
  hit (and backstab), then it rests 5 s after the last hit
- Unlimited: Banana Peel, Throw Stone, Hazard Idol, the weapons' own skills
  and the other light skills.
- Never touched: skills that already have a limit (Hypershot, Fan of
  Gnarlics, Holder of Shinies: 6 s cooldown, Bastion Volley: 10 shots that
  come back, Gourdo's Community Garden, Crystroll's Ice Puke, Banana Peel).

SETTINGS (scripts/skilllimits_settings.lua)
- charges, refill_seconds: the numbers for every limited skill
- skills: which skills, and per-skill numbers if you want
  (e.g. miniboss_groak = { charges = 3, refill_seconds = 8 })
- show_charges_left, blocked_sound, refill_sound, debug

PERFORMANCE
- Nothing runs every frame. The check only runs when a skill button is
  pressed; the rest timer is the game's timer component; the icon number is
  updated once a second only while a skill is out of uses, and the grey + X
  only change when a skill runs out or comes back.

client_log.txt shows: [Skill Limits] on (11 skills limited: ...)

0.5.2: the bow's special arrows (toxic, frozen, exploding) rarer, same strength:
  2 arrows in the quiver (was 3), 1500 damage to earn one back (was 1000).
  The free dip when empty stays every 15 s.
0.5.1: the skill press check is guarded: an error is logged ("skill press error")
and the press goes the game's way, instead of the game's error screen.
