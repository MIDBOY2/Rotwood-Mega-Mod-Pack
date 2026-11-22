Powers First 0.1.0 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

When a room's powers come out, the game spreads a circle of powers for each player, further apart the
more players there are (3 and 4 players most of all). They can land on an NPC, a meal, anything else you
can use, and then pressing the button uses that instead of picking the power.

With this mod, while any power is still waiting to be picked, NPCs, meals and everything else you can
use are switched off: their prompt doesn't show and the button goes to the power. The moment power
choosing is over (every player has picked; the game takes the other powers away), they're all back.

Never switched off: the powers themselves, the power crystal, players (so you can revive them), and
anything you're already using.

It covers every power waiting on the floor: after a room, from an NPC's event, one bought in the shop
(pick it up, then the shop is back).

Settings: scripts\powersfirst_settings.lua (restart the game after changing it)
  - only_own_powers = false: everyone waits until every player has picked. true: a player who has
    picked gets NPCs and the rest back while the others still pick.
  - include_crystal = false: true also switches them off while the power crystal waits to be hit.
  - allow = {}: prefab names never switched off, e.g. allow = { "healing_fountain" }.

How it works: the game asks Interactable:CanPlayerFocus whenever a player looks for something to use
(to keep its target and to choose a new one). While a power is out, it answers no for everything that
isn't a power (or on the list above), so the game's own choosing lands on the power. The powers are
noted as the game makes them (AddPrefabPostInit "power_pickup_single"). Nothing runs per frame and
nothing is checked while no power is out.

Switching it off: enabled = false in the settings, or add "rotwood-powers-first" to disabled_mods
in mods\nativeloader_settings.lua, or delete the rotwood-powers-first folder. Nothing else depends on it.
Log lines start with [Powers First] in client_log.txt. If a game update changes what it uses, it
switches off and the log says so.

0.1.0 (2026-11-18, the user: "when playing in 4 /3 players, ven sometimes in 2 . the powers are being
  spread really far, sometimes onto interactables. like Npcs , Meals ,ETC. While choosing powers, Npcs
  and meals and such should be unavailable, until the power choosing is over, lets try this as a
  seperate mod"): first version.
