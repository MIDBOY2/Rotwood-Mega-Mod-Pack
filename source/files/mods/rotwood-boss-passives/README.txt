Boss Weapon Passives 0.2.9 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

The game's boss weapons (Super Frenzy, all six weapon types) have a skill but
no passive: their power is a placeholder that does nothing. This gives each
boss a passive, shared by its six weapons. It shows in the weapon's tooltip and
comes and goes with the weapon like any weapon's passive.

  Mother Treek  Rootbound Mending: hitting a knocked-down enemy heals you 5
                health, up to 50 a room (heal powers' bonuses don't add to it).
  Owlitzer      Tailwind Talons: a perfect dodge (an attack passes through you
                while you dodge) lets loose a gust of wind on both sides of you
                that hits every enemy around you for your weapon's damage, and
                your next attack within 4 seconds is a critical hit (the first
                of your hits that lands uses it up; otherwise it runs out).
  Bandicoot     Double Dealing: a successful Parry (the Bandicoot weapons' skill)
                or a perfect dodge: for 3 seconds every hit you land strikes
                again (the game's Multistrike).
  Thatcher      Swarm Burst: every 25 hits in a hit streak, a swarm bursts out
                and coats enemies around you in Acid.
  Sedament      Gathering Frost: each kill +5% damage for the rest of the room,
                up to 5 kills.
  Eggzy         Volatile Shell: a critical hit that kills makes the enemy
                explode (the No Contest bomb), once every 3 seconds.
  Grimhollow    Bastion Bark: during your heavy attacks you take 40% less
                damage from the front (the Bastion Volley's front), and a heavy
                attack that lands gives you 25% less damage taken for 3
                seconds. Both at once: 55% less.

A first version to try in game: every number is in
scripts\bosspassives_settings.lua (save, restart the game), and each boss can be
switched off there (on = false: its weapons keep the placeholder).

Taking the mod out for good: set enabled = false first and load each character
once (they then save with the game's placeholder), then remove the folder. With
enabled = false the mod still knows its passives, so saves made with them load.

Log lines start with [Boss Passives] in client_log.txt (Owlitzer also logs each
perfect dodge and when the crit is used up or runs out, the first 40 times).

0.2.2: the passives' names and descriptions showed as MISSING:STRINGS... (the
game translates every string again after the mods load and didn't know them).
Owlitzer: the crit could stay on for good; its gust now does damage.
0.2.3: Owlitzer's gust gets the Windmon's whirlwind round you on top of its
puffs (gust_look = "" in the settings for the puffs only).
0.2.4: Owlitzer's crit lasts 4 seconds (2 ran out before a charged swing
landed); the log says which hit used it up and whether it was critical.
0.2.5: Mother Treek heals 5 a hit, up to 50 a room. It was 1, but a heal
power's flat bonus was added to every heal, which made it 25 a hit.
0.2.6: Owlitzer: the purple glow on your hands goes when the crit ends (it
could stay on). The log says the crit chance left when it ends; above 3%
(crit from your gear or powers) the game keeps a faint glow for that.
0.2.7: Owlitzer's whirlwind follows you (it stayed where the dodge happened).
0.2.8: Owlitzer: only your own light / heavy attack or skill uses up the crit (a
power's hit used it before your swing landed).

0.2.9: bulletproofing: an error inside a passive is logged ("[Boss Passives] error
in ...", with the lines it went through) and skipped, instead of the game's
error screen ending the run. guard = false in the settings: the game's way.
