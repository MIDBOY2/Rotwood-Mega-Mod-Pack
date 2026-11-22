Controller Layout 0.1.9 - part of Rotwood Mega Mod Pack by midboy. Made for Rotwood build 763742.

Emotes on the right stick
  Push the stick: the emote ring opens. Move it onto an emote. Let go: that
  emote plays. Letting go with nothing picked just closes the ring.
  The pick follows the stick every frame, so spinning around is instant.
  Letting go is forgiving: it counts as soon as the stick is back under
  halfway, and an emote the stick only touched in the last moment before
  letting go (under ~4 frames) doesn't count - you get the one you rested on.
  release_at / settle_time in the settings.
  Pressing an attack / dodge / skill / potion while the ring is open closes it
  and does the move as usual (same thumb as the stick); face_buttons_pick = true
  in the settings brings back the game's face-button emote picks instead.
  No ring while a menu is open or while you're placing a decoration (the stick
  turns it then). Keyboard E works as before.

Buttons (every controller)
  D-pad down   build (open the decoration menu)   was RS-click
  LT           no longer opens emotes              (LT = Skill Slots' parry only)
  Customize town stays where the game's Options > Controls put it (you set
  D-pad up there); customize_button in the settings can set it here instead.
  A D-pad direction used by build / customize town / emotes no longer walks
  (the stick walks). In the build menu D-pad down moves the cursor; B closes it.
  RS-click is now free for a Skill Slots skill.
  For build and emote the game's Options > Controls page still shows the old
  buttons; the ones above are the ones that work. Pick other buttons in the
  settings ("game" = leave it to the game's options).

With the other mods
  Tonic Swap: D-pad left / right. Two Weapons: LS-click.
  Skill Slots: LT / RT / RS-click; its menu has no controller button now
  (skill station or keyboard H), see menu_button in its settings.

Settings: scripts\controllerlayout_settings.lua (save, restart the game).
Log lines start with [Controller Layout] in client_log.txt. If a game update
renames something the mod hooks, that part switches off and the log says what.

What's over the players' heads (Ctrl+H)
  One setting for all players (overhead), Ctrl+H cycles it, a short note at
  the side says which:
    the game's          the health bar with the name, the potion, the name
                        when you're behind something big
    health and potion   the health bar and the potion, no names
    potion only         nothing over the heads but the potion, and only when
                        you press potion with none left
  Only the game's own "show it" calls are let through or not: nothing runs per
  frame. The choice is kept for the next rooms and game starts
  (controllerlayout_overhead.txt in the save folder); changing overhead in the
  settings starts over from the new value. overhead_key = "" for no key.
  Exactly Ctrl+H (not while the console is open). With the game's debug keys
  on, Ctrl+H no longer hides the props (Ctrl+Shift+H still does).
  Tonic Swap's potion pop-up after a tonic swap counts as the game's potion
  pop-up: in "potion only" it shows only with no potion left.

0.1.8: the debug button's key is F9 (F8 is the game's own feedback key: it opened
"Send us your feedback"). The build number at the top ("REV. 760548") starts hidden
too; F10 shows / hides it, in camp and in runs. rev_number = "hidden" / "shown" /
"game", rev_number_key = "F10".
0.1.7: the game's "[Debug Menu]" button at the top of the screen in camp (the chest
icon under the build number) starts hidden; F8 shows / hides it (the game has no
key for it). debug_button = "hidden" / "shown" / "game" (left alone),
debug_button_key = "F8" ("" = no key). The last choice holds for the session.
0.1.6: the stick check that runs every frame no longer makes a throwaway table each frame (less garbage; nothing else changed).
Also 0.1.6: closing the emote ring for a move is guarded (an error is logged, the move still goes).

0.1.9: what's over the players' heads: Ctrl+H cycles the game's / health and
potion / potion only (when you press potion with none left), one setting for
all players, a note at the side, kept between rooms and game starts.
