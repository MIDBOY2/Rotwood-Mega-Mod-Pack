-- Skill Slots settings. Edit, save, restart the game.
--
-- B starts as your weapon's own skill (it changes with the weapon, like vanilla).
-- Each slot below is a button with its own skill (defaults until you pick in the menu):
--   B = the game's skill button, LT = left trigger, RT = right trigger, RS = right stick click
-- "weapon" = the weapon's own skill (changes with the weapon, like vanilla B).
-- Each weapon type (Hammer, Bow, ...) has its own loadout of all four buttons:
-- switching weapons switches the skills. The menu sets the loadout of the
-- weapon in hand; "slots" below is where every weapon's loadout starts.
-- To move parry to LT, swap the names: LT = "parry", RS = "buffnextattack".
-- Use "none" (or delete the line) to leave a slot empty.
--
-- Universal skills (work with any weapon):
--   parry, throwstone, bananapeel, buffnextattack, throwsnowball (holiday)
--   miniboss_yammo, miniboss_floracrane, miniboss_groak, miniboss_gourdo,
--   miniboss_crystroll, miniboss_embison, miniboss_bonejaw
--   boss_megatreemon, boss_owlitzer, boss_thatcher, boss_sedament, boss_eggzy,
--   boss_grimhollow
-- Weapon skills (hammer_totem, polearm_vault, ...) and boss_thatcher (a bow skill)
-- only work with that weapon in hand; on a slot they rest while you hold another.
-- Tested so far: parry, throwstone. Boss skills may react to other skills'
-- events until the event filter is added.
--
-- RS-click was the game's build button; with Controller Layout build is on
-- D-pad down and RS-click is free for a skill.

return {
	enabled = true,

	-- Skill stations: press interact (RB) on one of these decorations in town to
	-- open the skill slot menu. Your picks are saved with your character and
	-- replace the "slots" defaults below.
	--   rustic_weapon_rack = Rugged Weapon Rack, rugged_weapon_rack = Rustic Weapon Rack
	--   (the game swaps those two names), pergola = Pergola,
	--   tree_winter_2024 = Wintertide Tree, dummy_kuma = Kuma's Scare-Rot
	stations = { "rustic_weapon_rack", "rugged_weapon_rack", "pergola", "tree_winter_2024", "dummy_kuma" },

	-- The blacksmith's weapon racks (by Hamish's forge): hold interact (RB) on one for
	-- "Customize Skills", once that rack's weapon is unlocked (then a tap opens your
	-- weapons, as before; while a rack still takes corestones it's the game's deposit
	-- only). false = off.
	rack_menu = true,

	-- The weapon rack inside Hamish's forge (the hut): stand by it and press interact
	-- (RB) for "Customize Skills". false = off.
	forge_rack = true,

	-- true = the station decorations show in the build menu right away (the game
	-- normally unlocks them later: biome exploration, Kuma's friendship, the
	-- winter event). Building one still costs its materials.
	unlock_stations = true,

	-- Opens the same menu anywhere in town, no station needed.
	-- gamepad: "DPAD_UP", "DPAD_DOWN", ... or "" for none. keyboard: a key or "".
	-- (If the button is also bound to something else, the menu won't open on it
	-- and client_log.txt says which.) The controller has none by default: build
	-- is on D-pad down (Controller Layout), customize town on D-pad up (the
	-- game's options) and Tonic Swap has left / right. To get one back, free
	-- one of those first, then name it here (e.g. gamepad = "DPAD_UP").
	menu_button = { gamepad = "", keyboard = "H" },

	-- Any skill can go on a slot (Show all in the menu lists them all, for
	-- trying them out). true = also count every skill as owned, so Hide
	-- unavailable only hides other weapons' skills.
	all_skills = false,

	-- true = the menu always opens with "Hide unavailable" on: other weapons'
	-- skills and skills you don't own are hidden. "Show all" (X in the menu)
	-- shows everything until the menu closes. false = it always opens with
	-- Show all. Owned = comes with a weapon in your inventory, or you have it
	-- right now. Boss and miniboss skills and Parry count per weapon type: a
	-- weapon's loadout lists them only if you own that boss's weapon of that
	-- type. (Only a filter: any skill works on a slot, owned or not.)
	hide_other_weapons = true,

	-- Skills of no weapon get a class too, by their name and on their tile:
	-- boss and miniboss skills the game's boss icon ("Boss" / "Miniboss"), the
	-- rest (Fist Pound, Throw Stone, Parry...) its any-weapon icon ("Any").
	-- false = no icon or tag for them.
	class_icons = true,

	-- The names over the skills in the menu's list ("Hammer", "Any",
	-- "Miniboss"...). false = off each time the menu opens; true = on. "Names"
	-- (LB, keyboard Q) switches them while the menu is open (not kept).
	list_names = false,

	-- Skill pictures that run over their round frame, drawn smaller in the menu
	-- and on the HUD (1 = the game's size), e.g. { throwstone = 0.9 }.
	-- (Throw Snowball's own icon is drawn inside its frame now.)
	icon_scale = {},

	-- Skills the menu never shows, even with Show all (the game's unfinished
	-- ones that don't work).
	hidden_skills = { "hammer_reflectinglights" },

	-- Two of the game's unfinished skills, finished.
	-- Explosive Dive (the Bow's "[TEMP] bow_primearrow_explode"): your next
	-- Heavy Attack explodes where it lands (the game's friendly pinecone
	-- bomb). Name, description, icon, Hypershot's pink dip fx and sparks on
	-- the arrow while primed. false = the game's stub.
	explosive_dive = true,
	-- the primed arrow flies with a pink crit trail (false = no trail)
	explosive_dive_trail = true,
	-- Explosive Dive's prime (the game's dip fx only lines up with the prime
	-- animation, so it could hang above your head on its own):
	--   "anim"    the pink spark (Hypershot's dip fx) while the prime animation
	--             plays (the arrow raised: it sits on it, as drawn); go straight
	--             into the Heavy Attack (or dodge, run) and the spark goes, what's
	--             left of its sparkle moves onto the arrow
	--   "arrow"   pink sparks come onto the arrow, a short pink burst on it when
	--             it's primed (they follow the arrow, whatever the animation)
	--   "vanilla" the game's prime animation, no dip fx (the arrow's sparks
	--             still show it's primed)
	--   "quick"   the prime animation at twice the speed, then straight into
	--             the Heavy Attack shot with the exploding arrow
	explosive_dive_prime = "anim",
	-- "quick": the shot's strength, like a held Heavy Attack: "WEAK",
	-- "MEDIUM", "FOCUS" (the perfect-timing shot) or "STRONG" (full charge)
	explosive_dive_shot = "STRONG",
	-- Cold Plunge and Toxic Dip (the game's frost and acid prime): their dip
	-- fx is its own animation drawn to match the prime animation, so when that
	-- doesn't show, its spark hangs over your head. Four ways:
	--   "anim"  = the game's spark while the prime animation plays (lined up as
	--             drawn); go straight into the Heavy Attack (or dodge, run) and
	--             the spark goes, what's left of its sparkle moves onto the arrow
	--   "arrow" = the dip's own sound, and its own frost / acid trail and burst
	--             put on the arrow, at the dip's own moments (only the dip's
	--             drawing left out)
	--   "plain" = the dip's sound and the game's sparks on the arrow, no burst
	--   "game"  = the game's dip fx as it is (the spark over the head)
	bow_prime_dip = "anim",
	-- Throw Snowball (the game's holiday skill): endless snowballs, each one
	-- scooped off the ground, that knock enemies back and make them Cold;
	-- enough Cold Freezes them. Enemies only. false = the game's (3 throws,
	-- then it only shrugs "RELOAD!").
	snowball = true,
	-- Cold per hit: 600 Freezes (150 = 4 hits; the game's frost snowball: 300)
	snowball_cold = 150,
	-- damage, x your weapon's: 0 = none (the game's snowball), 1 = full (its frost snowball)
	snowball_damage = 0,
	-- how fast it flies (the game's snowball: 25, its frost snowball: 15)
	snowball_speed = 25,
	-- the snowball in your hand while you throw, not the stone (false = the stone)
	snowball_in_hand = true,
	-- the snowball art's symbol for the hand: "" = the ball, "ice_core_untex"
	-- (the game's snowball art, fx_projectile_snow_ball)
	snowball_hand_symbol = "",
	-- true: the stick can't cancel the scoop, the throw always comes (Throw
	-- Stone's way); false: the game's (moving cancels it from its 6th frame)
	snowball_finish_throw = true,

	-- Game fix: some skills (Order in the Court and others) restart from their
	-- first frames when you keep pressing the skill button, so the swing never
	-- plays out. true = pressing the skill again while it's swinging waits for
	-- the swing to finish, then the skill starts again. false = the game's way.
	finish_skill_swing = true,

	-- Weapon choices: moves of one weapon you can put on a button in the menu
	-- (each weapon's loadout), like a skill. Not on any button = the game's way.
	-- These lines say where each one starts; false = on no button. Your picks
	-- in the menu win over these.
	--
	-- Greatsword "Block": its block (the dodge button with no direction) on
	-- "LT", "RT", "RS" or "B". With Block on a button, the dodge button always
	-- rolls (forward with no direction). On B, B only blocks: put the
	-- Greatsword's skill on LT / RT / RS (its attack-into-skill combos follow it).
	greatsword_block = false,
	-- Cannon "Dodge": the Cannon's roll (it has one in its files the game never
	-- plays) on "LT", "RT" or "RS". The dodge button stays the Cannon's own
	-- (plant, reload while planted). Starts on RS for testing.
	cannon_dodge = "RS",
	-- Cannon "Reload": the Cannon's plant / reload (what its dodge button does)
	-- on "LT", "RT" or "RS"; the dodge button rolls instead.
	cannon_reload = false,
	-- The Cannon roll's invincibility: every roll is invincible for the game's
	-- roll frames (12 at normal weight, 7 light, 10 heavy) plus a weapon bonus:
	-- Bow and Striker 0, Hammer, Spear and Greatsword 1. This is the Cannon
	-- roll's bonus (0 = exactly like Bow / Striker, 1 = like the melee weapons).
	-- Only the roll: the Cannon's Blast keeps its own bonus.
	cannon_roll_iframes = 0,
	-- Roll into an attack: light (X) / heavy (Y) during the Cannon roll.
	--   true  = mid-roll: X = Air Shot (keeps the roll's momentum), Y = Quick
	--           Rise (stop and punch); stick back: turn, then Air Shot behind /
	--           Air Blast (launches you on in the roll's direction). As you
	--           land: X = normal shot, Y = Blast (stick back: turn, then the
	--           Battering Ram swing / a Blast that dashes you on). The game's
	--           own chains follow (X / Y after an air shot).
	--   false = the normal shot / Blast all through the roll.
	cannon_roll_combos = true,
	-- The landing's stick-back X: the Battering Ram skill's swing (false = a
	-- normal shot behind).
	cannon_roll_swing = true,

	-- The game's mannequin loadouts remember your skill buttons (every
	-- weapon's), saved when you save the loadout, put back when you equip it.
	-- false = loadouts don't touch your skill buttons.
	mannequin_loadouts = true,

	-- Where every weapon's buttons start (until you pick in the menu).
	-- buffnextattack = Fist Pound (crit chance), throwstone = Throw Stone.
	slots = {
		B = "weapon",
		LT = "buffnextattack",
		RT = "throwstone",
		RS = "parry",
	},

	-- Per-player changes, by player number (1-4). Only list what differs.
	-- Example: player 2 gets bananapeel on RT:
	--   [2] = { RT = "bananapeel" },
	players = {
	},

	-- Keyboard keys for the slots (keyboard player only).
	keyboard = {
		LT = "U",
		RT = "I",
		RS = "O",
	},

	-- Slot icons on the player HUD, with their button on each icon.
	-- show = false starts them hidden (each player can switch them in the menu: "HUD icons").
	-- layout = "cluster": the four skills next to the portrait like the
	--   controller: RS and RT on top, B and LT under them (the top row shifted
	--   sideways), every icon with its button. The weight class moves to a small
	--   badge after your name, and the power rows and the town's weapon tips
	--   move past the cluster (to the left on right-side HUDs).
	--   "zigzag": they carry on the game's honeycomb (weight icon, skill
	--   icon, then LT / RT / RS, each half an icon sideways) along the screen
	--   edge, clear of the power rows. "row": in a row next to the skill icon.
	-- size = "full" (same as the weapon skill icon) or a width like 90.
	-- cluster: gap = space between icons, shift = how far the top row sits
	--   sideways (0.5 = half a step), rise = extra space above B / LT.
	-- skill_scale = how big the four skill icons are drawn (the game's B icon
	--   and the slots; 1 = the game's skill icon size).
	-- power_scale = how big the powers past the cluster are drawn (1 = the
	--   game's size); power_gap = space between the skills and the powers.
	-- class_badge = false keeps the weight circle off (cluster only).
	-- tips_gap = space between the cluster and the town's weapon tips.
	-- tips_margin / tips_min_scale: with 2+ players, a player's tips stay in their
	--   half of the screen (tips_margin from the middle); tips that would reach
	--   further are drawn smaller to fit, down to tips_min_scale.
	-- overlap = how much each icon tucks into the one before (zigzag; the game uses 10).
	-- spacing = gap between icons (row layout).
	-- x / y = extra offset of the slot icons if they cover something.
	-- bar_clears_name = false: the health bar starts at the portrait's edge like
	-- the game's (it covers the end of a long name and its badges); bar_gap =
	-- space between the name's box and the bar.
	-- name_fit = false: the game's name (font 40, cut at 160 wide with "...").
	--   On (cluster): weapon badge + name + class badge stay on the portrait: a
	--   long name gets a smaller font, down to name_min_font, then is cut with
	--   "...". name_margin = space kept on the health bar's side.
	-- lives_after_bar = false: the extra lives (wings) under the health bar's
	--   start like the game's (the cluster's top row covers them). On
	--   (cluster): at the bar's end, lives_gap away.
	-- Hide / show the power rows of the HUD (your powers' icons at the top),
	-- always with a smooth fade:
	--   gamepad: each player's own rows, in runs ("DPAD_DOWN"; "" = none).
	--     In town the game hides them anyway (D-pad down is build there).
	--   hide_all / show_all: keyboard keys for every player's rows ("" = none;
	--     modifiers allowed, e.g. "Ctrl+SEMICOLON"). ; and ' by default: keys
	--     nothing else uses (with the game's debug keys on, - and = do debug
	--     things: = hides the ground). The game's key names: SEMICOLON,
	--     QUOTE, SLASH, F5, A..Z, ...
	--   boss_auto_hide: "boss" = every player's rows fade out when a boss
	--     wakes up and back when it's beaten (or the room's cleared); "all" =
	--     minibosses too; false = never. Showing them yourself during the
	--     fight keeps them shown for it.
	--   fade_time: seconds for each fade (0 = at once).
	--   small_gamepad: each player's power icons smaller, one step a press:
	--     full size, then each of small_sizes, then full again ("DPAD_UP";
	--     "" = none; in runs: in town D-pad up is customize town). small_all:
	--     a keyboard key doing it for every player ("SLASH" = /).
	--   small_sizes: the smaller sizes, in order (up to 4). Smaller icons get
	--     more rows in the height of the game's 2: 0.66 = 3 rows, 0.5 = 4
	--     rows (2 / size), filled evenly, so they stack in a block next to the
	--     skills. { 0.5 } = one size only (D-pad up toggles it).
	-- Each player's choice stays with their character from room to room.
	-- hide_powers = false: off.
	hide_powers = {
		gamepad = "DPAD_DOWN",
		hide_all = "SEMICOLON",
		show_all = "QUOTE",
		boss_auto_hide = "all",
		fade_time = 0.35,
		small_gamepad = "DPAD_UP",
		small_all = "SLASH",
		small_sizes = { 0.66, 0.5 },
	},

	hud = {
		show = true,
		layout = "cluster",
		size = "full",
		cluster = { gap = 24, shift = 0.4, rise = 0, skill_scale = 1.1, power_scale = 1.3, power_gap = 8 },
		class_badge = true,
		tips_gap = 25,
		tips_margin = 30,
		tips_min_scale = 0.5,
		overlap = 10,
		spacing = 10,
		x = 0,
		y = 0,
		bar_clears_name = true,
		bar_gap = 10,
		name_fit = true,
		name_min_font = 26,
		name_margin = 10,
		lives_after_bar = true,
		lives_gap = 12,
	},

	-- Bulletproofing: an error inside Skill Slots' part of the game (a button
	-- press, a skill, the Cannon roll, Block, the HUD, loadouts) is logged
	-- ("[Skill Slots] error in ...") and that part skipped, so the game does
	-- it its own way that moment instead of showing its error screen and
	-- ending the run. false: errors go to the game as before.
	guard = true,
}
