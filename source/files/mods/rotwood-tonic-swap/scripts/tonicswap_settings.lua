-- Tonic Swap settings. Edit, save, restart the game.
--
-- D-pad right = next tonic, D-pad left = previous. The tonic is drunk together
-- with your potion (LB).
--
-- Potions menu: press interact (RB) on a tonic station in town (the Potion
-- Table, or the Ironwork Illuminator). Each player picks:
--   Potion (top): Soothing Spirits, Bubbling Brew or Misting Mixture (in town).
--   Tonics (one grid): A = in / out of the cycle, X = main tonic (equipped
--   right away, first in the cycle), Y = disable cycling (only the main tonic)
--   or put every tonic in. All nine out = no tonic.
-- Saved per character. Never opened the menu = no tonic.
--
-- Tonics: zucco_dash, mudslinger, full_shield, shrink, yammo_rage, explotion,
-- juggernaut, projectile_repeat, freeze (resolve1 does nothing, so it's left out.)

return {
	enabled = true,

	gamepad = { prev = "DPAD_LEFT", next = "DPAD_RIGHT" },
	keyboard = { prev = "COMMA", next = "PERIOD" },

	-- Stop the D-pad left/right from also walking.
	free_dpad = true,

	-- Show your potion and tonic above your head for a moment after a swap.
	popup = true,

	-- Tonics to leave out for everyone (not in the menu either), e.g. skip = { "shrink" },
	skip = {},

	-- The menu's grid order, left to right, row by row (the D-pad cycle goes
	-- the same way). Tonics not listed come after, in the game's order.
	-- Rows by colour: blue Bulbug Boba (shield), Freeze, Run speed; red the
	-- popping candy (explotion) and the two projectiles; yellow Shrink, Grow
	-- (juggernaut), Damage (yammo_rage).
	order = { "full_shield", "freeze", "zucco_dash",
		"explotion", "projectile_repeat", "mudslinger",
		"shrink", "juggernaut", "yammo_rage" },
	-- Freeze and Run speed (zucco_dash) drawn blue and Grow (juggernaut)
	-- yellow, like the rest of their row (the game's icons recoloured to the
	-- row's palette, images/tonicswap_tonics). false = the game's icons.
	tonic_colours = true,

	-- The Potion Table: Doc Hoggins' travelling table with all three potions on
	-- it (and his SALE! sign), a tonic station you build in town: Build menu,
	-- Furniture or Usable. Interact (RB) opens the potions menu. It costs what
	-- the structure in potion_table_cost_like costs ("bench_basic" = the Hewn
	-- Bench). false = no Potion Table (pick placed ones up first: they go away
	-- with it).
	potion_table = true,
	potion_table_cost_like = "bench_basic",

	-- More tonic stations: town decorations that open the tonic menu (interact
	-- / RB). The Potion Table is always one.
	--   lamp_volcano_1 = Ironwork Illuminator (Lights)
	stations = { "lamp_volcano_1" },

	-- true = the stations show in the build menu right away (the Ironwork
	-- Illuminator is normally a Grimhollow exploration reward). Building one
	-- still costs its materials.
	unlock_stations = true,

	-- true = every run starts on your main tonic (false = you keep the one you
	-- had on when the run starts).
	main_at_run_start = false,

	-- Tonics that sit out of your cycle while you have a power that does
	-- their job: power = { tonics }. Iron Brew gives 4 Shield Segments every
	-- drink, like Bulbug Boba (full_shield), so with it Boba sits out: the
	-- D-pad skips it and, if you have it on, you get the next tonic in your
	-- cycle. It's back when the power goes (town, a new run), on again if you
	-- still have that next one on. Your menu choices stay as they are.
	-- false = off.
	out_with_power = { iron_brew = { "full_shield" } },

	-- Potions: the tonic menu's Potion column, picked in town. Bubbling Brew and
	-- Misting Mixture are finished in the game's files but hidden; true = all
	-- three are yours from the start.
	potions = true,

	-- The Alchemist's Gem (Perfect Pairing's gem: more potion healing) refilled
	-- your whole potion every time the game set your gear's powers up again (a
	-- weapon or armour bought at the market, your gems levelling up at the end
	-- of a hunt, Two Weapons' both-weapons gems): the game's bug, it runs the
	-- power's refill with no number, which means "everything". Now it only
	-- heals more, as its text says. The Perfect Pairing power still refills
	-- when you take it. false = the game's.
	gem_refill_fix = true,

	-- Their bottles in the drink animation:
	--   "own"      = the mod's art (anim and images folders): a round flask and
	--                a crystal decanter drawn from Soothing's bottle and the
	--                icons, the bottle smash in their glass colours, and empty
	--                HUD icons like Soothing's
	--   "recolour" = Soothing's bottle and the game's smash in their colours,
	--                the game's HUD icons (if "own" shows a missing bottle)
	--   "soothing" = Soothing's bottle and the game's smash as they are
	potion_bottles = "own",
	-- The HUD's potion icons with "own" bottles:
	--   "mix"     = higher-contrast full and empty icons (the originals mixed
	--               half and half with a Soothing-like version: solid glass,
	--               a darker rim on the fluid, white shines, a thicker outline)
	--   "classic" = the game's full icon and the mod's dark empty icon (0.7.8)
	--   "game"    = the game's own full and empty icons
	potion_hud_icons = "mix",

	-- The tonics' effects in the game's current art (false = as the game made
	-- them): Ice Cold Slushie freezes with the ice prison (the old one only
	-- greyed enemies out; bosses get Cold instead), Battoad Eggs and Chocolate
	-- Foam shoot the Shrapnel projectile, Popping Candy uses the small
	-- explosion.
	tonic_fx = true,
	-- Ice Cold Slushie: how the freeze plays out (with tonic_fx).
	--   "nova"    the Legendary Frost power's frost nova: the full-screen frost
	--             burst, then enemies freeze one after another, nearest first,
	--             the further ones quicker (all frozen within 0.4 s)
	--   "ripple"  a big frost burst at you; each enemy freezes as the wave
	--             reaches it (further away = later), a small burst on each
	--   "chill"   the frost burst; enemies go cold first (blue-grey, slowed),
	--             then freeze a moment later
	--   "instant" everyone at once
	--   "browse"  a different one each time you use it, its name shown over
	--             you (and in client_log.txt) - try them, then pick one here
	-- A second use while the first still plays waits for it, then plays in
	-- full; uses close together keep the style ("browse" moves on after a
	-- pause of 2 seconds).
	tonic_freeze_style = "browse",
	-- Popping Candy's explosion (it goes off every second for 10 seconds):
	-- its size (1 = the small explosion's own size, 0.5 = half) and whether
	-- its ground blast goes off too (true / false).
	tonic_explode_scale = 0.5,
	tonic_explode_ground = false,
	-- The game also bursts a bomb hit on every enemy the explosion hits (one
	-- blast per enemy on top of the explosion): true brings those back.
	tonic_explode_enemy_blasts = false,

	-- Tonic numbers. Spicy Pumpkin Seeds: your damage for its 5 seconds, in %
	-- of normal (200 = double; the game: 1000 = ten times). Battoad Eggs: each
	-- projectile's damage (the game: 50). 0 = the game's number.
	tonic_rage_damage = 200,
	tonic_eggs_damage = 100,
	-- true = take "[TEMP]" off the tonics' names and descriptions.
	tonic_clean_text = true,

	-- The status panel (the player status button: your loadout over your head):
	-- status_potion_look = the potion slot gets the blue patterned background
	-- of an item slot and a bigger bottle (status_potion_scale times the
	-- game's); false = the game's plain dark square.
	-- status_potion_full = true shows the potion's full picture even with no
	-- drinks left (the game shows the empty bottle; the count still shows 0).
	status_potion_look = true,
	status_potion_scale = 1.35,
	status_potion_full = false,
	-- The HUD (your panel in the corner): the dark frame's left piece is made
	-- just wide enough to cover the tonic icon next to the potion (it stuck
	-- out past the frame's slanted corner). false = the game's frame.
	hud_potion_backing = true,

	-- While you drink a potion, the health bar and potion icon over your head
	-- move up this much so they don't cover the drinking animation (the game
	-- puts the bar 360 over your feet and the icon 440). A press with no
	-- charges left leaves them where they are. 0 = off.
	drink_lift = 110,
	-- Shrink and Juggernaut as your tonic: allies within your potion's reach
	-- (where its heal reaches them) shrink or grow with you, for the room,
	-- with the game's spore burst on them. false = only you (the game's).
	tonic_size_allies = true,
	-- and the players' summoned / charmed fighters too
	tonic_size_allies_minions = false,

	-- The potion picture in the talent menu (Field Medicine's charges):
	--   "hud"       = your potion's HUD bottle, as big as the game's picture,
	--                 next to the number (the loadout summary and descriptions
	--                 show the game's HUD icon for it, small)
	--   "hud_small" = the game's HUD icon for it everywhere (small)
	--   "inventory" = its inventory icon everywhere
	talent_picture = "hud",

	-- Bubbling Brew: 100 health a sip. Sips per charge (your tonic comes with
	-- every sip), and how much of flat heal bonuses (Potent Brew) each sip gets.
	bubbling_sips = 2,
	bubbling_flat_share = 0.5,
	-- Bubbling Brew on the HUD, the character panel and the potion over your
	-- head: the number counts sips (3 charges show 6, a sip takes one off).
	-- Only the number: the game still counts charges (max, refills, talents).
	-- false = the game's count (charges).
	bubbling_hud_sips = true,
	-- Bubbling Brew: powers that react to drinking (Iron Brew's shield, the
	-- frost freeze, Cleaver berserk, Forbidden Drink / Diluted Medicine's
	-- counters, Immorel's refills) count once a potion, so its only extra is
	-- the tonic with every sip; a free drink (the shop's potion drunk on the
	-- spot, the potion event when you're full) is a whole potion's healing.
	-- false = they count every sip, a free drink is one sip.
	bubbling_per_potion = true,
	-- The menu's details box (the potion / tonic under the cursor): its text
	-- size, times the mod's (1 = name 60, description 52, buttons 42; the
	-- first versions used 44 / 36 / 32). A long description still shrinks to
	-- fit the box.
	menu_text_size = 1,

	-- Probe: each drink writes how its heal was worked out to the game's log
	-- ("[Tonic Swap] potion heal: ..."): base, flat bonuses and the share of
	-- them, % bonuses, the hunt's multiplier, the result. false when done.
	potion_heal_log = false,

	-- Trial potion heals (not on yet). Each potion with no Potent Brew -> with
	-- Potent Brew 10:
	--   "current"          Soothing 250 -> 500, Bubbling 100 a sip (200 a
	--                      charge) -> 225 (450), Misting 300 -> 600
	--   "experimental"     Soothing 300 -> 600, Bubbling 125 (250) -> 250
	--                      (500), Misting 350 -> 700
	--   "experimental_375" the same, Misting 375 -> 750 (37.5 a heal; the game
	--                      rounds each heal down, so 370 with no Potent Brew)
	-- (An experimental set replaces misting_heal / misting_flat_share below.)
	potion_heals = "current",

	-- Misting Mixture: health per heal and how many heals (one when you drink,
	-- then one every second). A drink gets misting_flat_share times the flat
	-- heal bonuses (Potent Brew), spread over its heals: 1.2 = each Potent
	-- Brew rank adds 3 a heal, 30 a drink (rank 10: 60 a heal, 600 a drink).
	misting_heal = 30,
	misting_heals = 10,
	misting_flat_share = 1.2,
	-- true = drinking it again while it heals starts the heals over and keeps
	-- the healing that was left (the game wastes that drink).
	misting_restart = true,
	-- Misting and your allies (each heal also heals allies near you by
	-- their share):
	--   misting_allies = "link": an ally a heal reaches gets their share every
	--     second for the rest of that drink, wherever they go. "game": only
	--     who's next to you at each heal.
	-- What each heal shows (from the second; drinking shows the game's ring):
	--   misting_pulse, on the ground at you:
	--     "wave" = the green heal area grows out from you to your reach,
	--              stays a moment and fades
	--     "ring" = the game's drink ring every heal; "none" = nothing
	--   misting_glow = true: everyone it heals glows green, like drinking,
	--     with a small green heal burst
	--   misting_beams = true: a green heal beam from you to each ally it heals
	--     (Gourdo's seed beam, the one the Head Hunter power shows)
	--   misting_marks = true: the small green ring around the feet of
	--     everyone it heals (you, linked allies, allies in reach)
	-- Too much? Turn off any of them.
	misting_allies = "link",
	misting_pulse = "none",
	misting_glow = true,
	misting_beams = true,
	misting_marks = true,
	-- The beam to a far ally (a linked ally can be across the room). The
	-- game's beam is one small picture drawn bigger the longer the beam, so
	-- far away it was blown up and blurry. misting_beam_style:
	--   "chain" = near allies (up to about 9 units) get the game's beam as it
	--             is; farther, a chain of the game's small beams, each about
	--             misting_beam_piece units (the picture at the size it was
	--             made for), one after another from you to the ally,
	--             misting_beam_ripple seconds apart (0 = all at once), at most
	--             misting_beam_max_pieces
	--   "thin"  = one beam at the game's length, thinner (down to
	--             misting_beam_min_width of the game's width past
	--             misting_beam_full_until units) and fainter: looks stretched
	--   "game"  = the game's beam at any distance
	-- "chain" and "thin": fully visible up to misting_beam_fade_from units,
	-- fading to misting_beam_min_alpha at misting_beam_fade_to (on your
	-- screen), no beam past misting_beam_max_distance units (0 = always).
	misting_beam_style = "chain",
	misting_beam_piece = 6,
	misting_beam_max_pieces = 8,
	misting_beam_ripple = 0.04,
	misting_beam_full_until = 6,
	misting_beam_min_width = 0.3,
	misting_beam_fade_from = 8,
	misting_beam_fade_to = 30,
	misting_beam_min_alpha = 0.3,
	misting_beam_max_distance = 50,

	-- Bulletproofing: an error inside Tonic Swap's part of the game (a drink,
	-- the potion count, the tonic menu press, the bottle colours, the talent
	-- pictures) is logged ("[Tonic Swap] error in ...") and that part skipped,
	-- so the game does it its own way that moment instead of showing its error
	-- screen and ending the run. false: errors go to the game as before.
	guard = true,
}
