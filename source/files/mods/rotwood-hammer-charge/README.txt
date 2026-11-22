Hammer Charge 0.1.3 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

The hammer you were thinking of is the Sedament (tundra) hammer: its weapon
power is "Light Attacks are Chargeable, and do more Damage". This mod puts that
power on every hammer.

  Hold light attack (X / J / left mouse) to charge it, the way heavy (Y)
  already charges on every hammer. Tap it for the normal quick swing.
  A full charge (the weapon flashes, second tier) is a focus hit that knocks
  down and deals bonus damage: +140% at hammer level 1, +150% at level 2,
  +160% at level 3 (the Sedament hammer's own is +300 / 325 / 350%, which made
  a charged light far stronger than a fully charged heavy). With +140% Light
  Attack 1 / 2 / 3 hit for 3.0 / 3.6 / 4.2 times your weapon damage, the
  fully charged heavy for 4.58. Works on all three light swings of the combo
  and the fade-away light attack. bonus in the settings.

  The hammer's own weapon power stays (e.g. the Treek hammer's golf swing).
  The Sedament hammer works as before (never given the power twice).
  With Two Weapons, swapping onto a hammer keeps it working right away.

Settings: scripts\hammercharge_settings.lua (enabled = false turns it off,
bonus = the full charge's extra damage per hammer level).
Log lines start with [Hammer Charge] in client_log.txt. If a game update
renames the power or the functions this mod hooks, it switches itself off
and says what changed.

0.1.3: the check on every state change is guarded: an error is logged, never
the game's error screen.
