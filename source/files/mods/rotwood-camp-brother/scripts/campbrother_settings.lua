-- Camp Brother settings (an experiment). World units: x grows east (right), z grows
-- north (up the screen); a map tile is 4 x 4. Edit, save, restart the game.
return {
	enabled = true,

	-- His station: between Lottie (the refinery) and Toot (the dojo), at the crossroads.
	-- Which setup (change this one word to compare them):
	--   "wagon_table" = Doc's big potion wagon (drawn at 0.75) on the stone, him on the
	--                   road in front of it, his red table on the road to his right
	--                   (like Hamish's forge and gem table, mirrored)
	--   "table"       = only his red table (drawn at 1.3) on the stone, him on the road
	--                   beside it
	--   "wagon_front" = the big wagon (0.75) with his table right in front of it, both
	--                   on the stone, him on the road
	--   "layout2"     = "wagon_front" with the potion table up by the refinery road (your
	--                   screenshot's arrangement)
	--   "layout3"     = Hamish's station, mirrored: the wagon where his forge is (on a
	--                   3 x 2 stone floor like the forge's), the red table where the
	--                   forge's tool table is, him where Hamish stands, the potion table
	--                   where the gem table is, and the road between them, all from
	--                   the game's own numbers, left and right swapped
	-- "table", "wagon_front" and "layout2" also have a potion table
	look = "layout2",

	-- where everything stands in each setup (scale = how big it's drawn; face = "right"
	-- or "left")
	looks = {
		wagon_table = {
			wagon = { x = -50, z = -16.8, scale = 0.75 },
			table = { x = -43.8, z = -23.2, scale = 1 },
			brother = { x = -48, z = -24.2, face = "right" },
		},
		table = {
			table = { x = -51, z = -18.5, scale = 1.3 },
			brother = { x = -46, z = -19.5, face = "right" },
			potion_table = { x = -43.6, z = -23.4 },
		},
		wagon_front = {
			wagon = { x = -50.3, z = -16.3, scale = 0.75 },
			table = { x = -51.2, z = -19.6, scale = 1 },
			brother = { x = -47.2, z = -22.7, face = "right" },
			potion_table = { x = -43.8, z = -23.4 },
		},
		layout2 = {
			wagon = { x = -50.3, z = -16.3, scale = 0.75 },
			table = { x = -51.2, z = -19.6, scale = 1 },
			brother = { x = -47.2, z = -22.7, face = "right" },
			potion_table = { x = -47, z = -13 },
		},
		-- (its own floor and road tiles: these replace stone_floor's floor and road_tiles
		-- below while it's the setup)
		layout3 = {
			wagon = { x = -48, z = -18, scale = 0.9 },
			table = { x = -51.8, z = -18.4, scale = 1 },
			brother = { x = -40.9, z = -13.9, face = "left" },
			potion_table = { x = -36, z = -8.5 },
			floor_tiles = { { x = -52, z = -16 }, { x = -48, z = -16 }, { x = -44, z = -16 },
				{ x = -52, z = -20 }, { x = -48, z = -20 }, { x = -44, z = -20 } },
			road_tiles = { { x = -52, z = -8 }, { x = -48, z = -8 }, { x = -44, z = -8 }, { x = -40, z = -8 }, { x = -36, z = -8 },
				{ x = -52, z = -12 }, { x = -48, z = -12 }, { x = -44, z = -12 }, { x = -40, z = -12 }, { x = -36, z = -12 } },
		},
	},

	-- Gishins talks: Chit Chat (RB) with his lines (scripts/campbrother_strings.lua).
	-- false = he only stands there (the game gives him its "Have a good day!")
	talk = true,

	-- the potion table: true = on, false = off
	road_potion_table = true,
	-- which one: Tonic Swap's working Potion Table when that mod is on (swap tonics
	-- there); false = Doc's little potion table, decoration only
	working_potion_table = true,

	-- the stone floor: the camp's cobblestone, 8 x 8 (2 x 2 map tiles), like the floor
	-- under every NPC home. Its middle (snaps to the map's tile corners, so it moves 4
	-- at a time): x -54..-46, z -22..-14
	stone_floor = true,
	floor = { x = -50, z = -18 },

	-- the road: the camp's dirt road on these map tiles (any point inside one): the line
	-- along the floor's front joining the road down to Toot, the road down past the
	-- refinery two tiles wide, and the grass between the station and the refinery road.
	-- Only grass becomes road.
	road = true,
	road_tiles = { { x = -52, z = -24 }, { x = -48, z = -24 }, { x = -44, z = -24 },
		{ x = -44, z = -12 }, { x = -44, z = -16 }, { x = -44, z = -20 }, { x = -48, z = -12 } },

	-- the chest and the starting camp (bedroll), down in the bottom-left corner (the
	-- little rubble pile there moves aside for the camp)
	move_chest = true,
	chest = { x = -56, z = -28 },
	move_camp = true,
	camp = { x = -59, z = -26.5 },
	move_rubble = true,
}
