-- Armor Dyes settings. Restart the game after changing this file.
return {
	-- false = the whole mod is off (dyes you picked stay in the save and come
	-- back when it's on again)
	enabled = true,

	-- the ARMOUR DYE tab in the character screen (the mirror in town)
	dye_tab = true,

	-- a WEAPON sub-tab in ARMOUR DYE: dye the weapon you're carrying. (0.5.6) Every
	-- dye is worked out from that weapon's own colours like armour's (its colours
	-- turned, not painted over): the colour families, the neutrals, the 21 colour
	-- dyes, the 4 soft player colours and your own dyes. Every weapon keeps its
	-- own dye. false = no weapon tab, weapons in their normal colours.
	weapon_dyes = true,

	-- (0.5.9) The spear's twirl trail (drawn in the spear's own colours) takes the
	-- spear's dye too. false = the trail in its normal colours (0.5.8 and before).
	dye_weapon_trails = true,

	-- (0.5.6) Tint palettes: a whole colour scheme per piece instead of one colour
	-- (each material its own palette colour: main, second, accent, metal...), the
	-- boss looks' palettes and colour palettes. Live colour shifts, no extra art.
	palettes = true,

	-- a PALETTES sub-tab in ARMOUR DYE: one click puts a palette on the helmet,
	-- body, legs and weapon together
	palette_tab = true,

	-- the palettes in each piece's own list too (HELMET / BODY / LEGS / WEAPON),
	-- to mix palettes per piece. Longer lists. false = PALETTES tab only.
	palettes_in_lists = false,

	-- Dyes of your own, added after the built-in ones. These are a plain
	-- colour shift, the same on every armour set (not colour-matched):
	--   hue        = degrees to turn the colours (0-360)
	--   saturation = colour strength x (1 = unchanged, 0 = grey)
	--   brightness = x (1 = unchanged, 0.6 = darker, 1.2 = lighter)
	custom_dyes = {
		-- { name = "Electric", hue = 200, saturation = 1.0, brightness = 1.0 },
		-- { name = "Ghost", hue = 0, saturation = 0.1, brightness = 1.2 },
	},

	-- A brand-new character (made on the new-character screen) starts with its
	-- basic armour in its player's soft colour: player 1 Soft Blue, player 2
	-- Soft Yellow, player 3 Soft Teal, player 4 Soft Purple. Only once, only
	-- basic armour it hasn't dyed; change it at the mirror any time.
	-- false = new characters start in the original colours.
	new_character_colour = true,

	-- Loadouts remember the dye on each piece they wear (a Morphic piece: the
	-- dye on the boss look it shows), and equipping a loadout puts them back.
	--   "auto" = a dye you pick while wearing a loadout goes into it straight
	--            away (and its loadout statue changes with it)
	--   "save" = like gems: a changed dye marks the loadout as changed; save the
	--            loadout to keep it, switching loadouts puts its own dyes back
	--   false  = dyes aren't part of loadouts (as before)
	-- Loadouts saved before this don't change your dyes until they have some.
	loadout_dyes = "auto",

	-- The loadout statue in town shows the loadout as you'd wear it: the boss
	-- look of Morphic armour (its gem), mirage looks, and the dyes.
	-- false = the game's statue (plain pieces, no dyes).
	statue_look = true,

	-- (0.5.0) The imbued boss looks: the seven bosses' armour and weapons in their
	-- imbued (elite) colours. Each boss look gets "Imbued" first in its ARMOUR DYE
	-- list (helmet, body, legs, and its weapons in WEAPON), and the mirage station
	-- gets imbued patterns. The art loads in town (for the previews) and in a hunt
	-- only for the imbued pieces your hunters wear. false = none of it.
	imbued = true,

	-- The extra imbued looks after "Imbued": Treek Plum, Eggzy First and Salmon,
	-- Grimhollow Lava and Lava with the magenta glow. false = only "Imbued" (less
	-- art loaded in town).
	imbued_alt_looks = true,

	-- (0.5.9) Reference looks: older versions kept to compare with. Right now
	-- Grimhollow's lava bow with its first, red / pink string ("Imbued: Lava, red
	-- bow string" and "Imbued: Lava, magenta glow, red bow string"; the lava bow's
	-- string is now orange). false = left out (no art loaded for them).
	imbued_reference_looks = false,

	-- Imbued patterns at the mirage station (for any item of that slot; weapons of
	-- that weapon type), at the usual price. false = the dyes only.
	imbued_mirage = true,

	-- A piece in an imbued look shows the imbued icon (inventory, mirage station,
	-- loadouts). false = the normal icons.
	imbued_icons = true,

	-- The imbued patterns of a boss piece come with owning it (its weapon, its armour
	-- look, or a Morphic piece showing it). false = all imbued patterns from the start.
	imbued_needs_boss_piece = true,

	-- extra lines in client_log.txt
	debug = false,
}
