-- Camp Brother (experiment): Doc Hoggins' brother's station in the camp, between
-- Lottie (the refinery) and Toot (the dojo): Doc's big potion wagon or his table on
-- a stone floor, the road along its front, him on the road.
--
-- All of it is the game's own systems, set up once when the game loads:
--   the stone floor: the town map's cobblestone tiles, the floor every NPC home in
--     camp stands on (2 x 2 map tiles = the 8 x 8 of a home plot). Written into the
--     town's map layout before the town is built (map/layouts/town/...).
--   the road to him: the same map, the town road's own tiles (the road it joins).
--   the chest and the starting camp: their spots in the town's prop placements
--     (map/propdata/town_..._propdata), which the town spawns them from each load.
--   the wagon and the table: spawned with the town's other placed props
--     (PropManager:SpawnStaticProps -> its SpawnProp, the way the town spawns every prop
--     it places), made by the game's prop maker (scripts/prefabs/campbrother_wagon.lua,
--     campbrother_trailer.lua); drawn smaller / bigger the way the game flips a prop.
--   the brother, Gishins: made by the game's own NPC maker, like every NPC in camp
--     (scripts/prefabs/campbrother_npc.lua): the game's NPC brain turns him to face
--     you, the game's NPC stategraph plays his idle, emotes and talking, the game's
--     interact and conversation give his Chit Chat (scripts/campbrother/chat.lua, the
--     lines in scripts/campbrother_strings.lua), in Doc's voice. Spawned by the host.
-- Nothing of the mod runs after that: no updates, no timers. (The game's NPC brain
-- runs for him like for every NPC.)

local Main = {}

Main.TAG = "[Camp Brother]"
Main.TRAILER = "campbrother_trailer" -- his table (Doc's small travelling trailer)
Main.WAGON = "campbrother_wagon" -- Doc's big potion wagon (traveling_potion_shop)
Main.POTION_TABLE = "campbrother_potion_table" -- Doc's little potion table, decoration only
Main.TONIC_TABLE = "tonicswap_potion_table" -- Tonic Swap's working Potion Table (the same table)
Main.NPC = "campbrother_npc"

Main.DEFAULTS = {
	enabled = true,
	town_layout = "town/town_plots_base_wide3", -- the town world's map (prefabs/autogen/world/town_plots_base_wide2_farm.lua)
	town_props = "town_plots_base_wide2_farm_propdata", -- its prop placements
	-- his station, between Lottie (the refinery) and Toot (the dojo), at the
	-- crossroads: a 2 x 2 stone floor with the road along its front
	stone_floor = true,
	floor = { x = -50, z = -18 }, -- the middle of the 8 x 8 floor (2 x 2 map tiles): x -54..-46, z -22..-14
	-- which setup: "wagon_table" = the big wagon (smaller) on the stone, him on the
	-- road in front of it, his table on the road to his right (Hamish's forge / gem
	-- table layout, mirrored); "table" = only his table, bigger, on the stone, him
	-- on the road beside it; "wagon_front" = the big wagon (smaller) with his table
	-- right in front of it, both on the stone, him on the road; "layout2" = the same
	-- with the potion table up by the refinery road. "table", "wagon_front" and
	-- "layout2" also have a potion table (on the road to his right: Hamish's gem
	-- table, mirrored)
	look = "wagon_front",
	-- Gishins talks: Chit Chat (RB) with his lines (scripts/campbrother_strings.lua).
	-- false: he only stands there (the game gives him its "Have a good day!")
	talk = true,
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
		-- "wagon_front" with the potion table up by the refinery road, where the
		-- road fills the grass beside the station (the user's own arrangement)
		layout2 = {
			wagon = { x = -50.3, z = -16.3, scale = 0.75 },
			table = { x = -51.2, z = -19.6, scale = 1 },
			brother = { x = -47.2, z = -22.7, face = "right" },
			potion_table = { x = -47, z = -13 },
		},
		-- Hamish's station, mirrored (left <-> right) around his own plot at (-48, -18):
		-- every spot is Hamish's from the game's data (map/propdata town: his plot (24,
		-- -26), the gem table (12, -16.5); prefabs/customscript/buildings.lua: Hamish
		-- stands at the forge + (-7.1, 4.1); the forge's tool table is part of its art,
		-- at about + (3.8, -0.4)), x mirrored: the wagon where the forge is, his red
		-- table where the tool table is, him where Hamish stands, the potion table where
		-- the gem table is. The ground too: the forge's 3 x 2 cobblestone and the road
		-- between it and the gem table (the town map's tiles there), mirrored.
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
	-- the potion table on the road (the setups that have one): on / off
	road_potion_table = true,
	-- which one: Tonic Swap's working Potion Table when that mod is on (swap tonics
	-- there, like Hamish's gem table), else Doc's little potion table as decoration.
	-- false: always the decoration.
	working_potion_table = true,
	-- the road: town road tiles (the camp's dirt road) on these map tiles (any point
	-- inside a tile): the line along his floor's front joining the road down to Toot,
	-- and the road down past the refinery two tiles wide
	road = true,
	road_join = { x = -48, z = -8 }, -- the road's end under the refinery (that tile's ground is used)
	road_tiles = { { x = -52, z = -24 }, { x = -48, z = -24 }, { x = -44, z = -24 },
		{ x = -44, z = -12 }, { x = -44, z = -16 }, { x = -44, z = -20 }, { x = -48, z = -12 } },
	move_chest = true,
	chest = { from = { x = -51, z = -13 }, x = -56, z = -28 },
	move_camp = true,
	camp = { from = { x = -53.5, z = -15.5 }, x = -59, z = -26.5 },
	-- the little rubble pile where the camp goes, moved out of its way
	move_rubble = true,
	rubble = { from = { x = -59, z = -26 }, x = -62.5, z = -22.5 },
}

-- the chosen setup (an unknown name: the first one)
function Main.Look(settings)
	local looks = type(settings) == "table" and settings.looks or Main.DEFAULTS.looks
	return looks[settings and settings.look] or looks.wagon_table, looks[settings and settings.look] and settings.look or "wagon_table"
end

local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local r = {}
	for k, v in pairs(t) do
		r[k] = copy(v)
	end
	return r
end

local function merge(defaults, user)
	local r = {}
	for k, v in pairs(defaults) do
		if type(v) == "table" and v[1] ~= nil and type(user) == "table" and type(user[k]) == "table" then
			-- a list (tiles): the settings' list replaces the default one whole
			r[k] = copy(user[k])
		elseif type(v) == "table" then
			r[k] = merge(v, type(user) == "table" and type(user[k]) == "table" and user[k] or {})
		elseif type(user) == "table" and user[k] ~= nil and type(user[k]) == type(v) then
			r[k] = user[k]
		else
			r[k] = v
		end
	end
	return r
end

function Main.LoadSettings(user)
	Main.settings = merge(Main.DEFAULTS, user)
	return Main.settings
end

-- Where a map tile's middle is in the world: 4 units a tile, the way the game puts
-- the layout in the world (util/maplayout.lua GetWorldPosFromLayoutObject: x = (u -
-- (width + 1) / 2) * 4, z = ((height - 1) / 2 - v) * 4, u / v in tiles from the
-- layout's left / top edge). Row 0 of the layout is the north edge. (Every home plot
-- in camp sits right in the middle of its 2 x 2 cobblestone tiles this way.)
local function tile_centre(layer, col, row)
	return (col - layer.width / 2) * 4, (layer.height / 2 - 1 - row) * 4
end

-- The map tiles under an 8 x 8 floor centred at (x, z) (a tile corner).
function Main.TileIndices(layer, x, z)
	local w, h = layer.width, layer.height
	local out = {}
	for row = 0, h - 1 do
		local _, tz = tile_centre(layer, 0, row)
		if math.abs(tz - z) < 4 then
			for col = 0, w - 1 do
				local tx = tile_centre(layer, col, 0)
				if math.abs(tx - x) < 4 then
					out[#out + 1] = row * w + col + 1
				end
			end
		end
	end
	return out
end

local function ground_layer(layout)
	for _, layer in ipairs(type(layout) == "table" and layout.layers or {}) do
		if layer.name == "BG_TILES" and type(layer.data) == "table" then
			return layer
		end
	end
end

-- the tile whose square holds (x, z)
local function tile_at(layer, x, z)
	local w, h = layer.width, layer.height
	local col = math.floor(x / 4 + 0.5) + w / 2
	local row = (h / 2 - 1) - math.floor(z / 4 + 0.5)
	return layer.data[row * w + col + 1]
end
Main.TileAt = tile_at

-- The floor the camp's NPC homes stand on: the tile under the cook's home plot.
function Main.HomeFloorTile(layer, props)
	local plot = type(props) == "table" and type(props.plot_cook) == "table" and props.plot_cook[1]
	if plot and plot.x and plot.z then
		local id = tile_at(layer, plot.x, plot.z)
		if id and id > 0 then
			return id
		end
	end
	return 3 -- COBBLETOWN in the town tile group (defs/groundtiles.lua)
end

function Main.StoneFloor(layout, props, x, z)
	local layer = ground_layer(layout)
	if layer == nil then
		return false, "the town map has no ground layer"
	end
	local stone = Main.HomeFloorTile(layer, props)
	-- on the map's tile corners (2 units off a tile's middle), so it's always 2 x 2
	-- whole tiles
	x, z = math.floor((x - 2) / 4 + 0.5) * 4 + 2, math.floor((z - 2) / 4 + 0.5) * 4 + 2
	local idx = Main.TileIndices(layer, x, z)
	if #idx ~= 4 then
		return false, "the floor isn't on the town map (" .. #idx .. " tiles)"
	end
	for _, i in ipairs(idx) do
		if (layer.data[i] or 0) == 0 then
			return false, "the floor would reach off the town's ground"
		end
	end
	for _, i in ipairs(idx) do
		layer.data[i] = stone
	end
	return true, stone
end

-- A floor on the given map tiles (any point inside each), the camp's cobblestone
-- (layout3: the forge's 3 x 2 floor, mirrored).
function Main.FloorTiles(layout, props, tiles)
	local layer = ground_layer(layout)
	if layer == nil then
		return false, "the town map has no ground layer"
	end
	local stone = Main.HomeFloorTile(layer, props)
	local w, h = layer.width, layer.height
	local idx = {}
	for _, t in ipairs(type(tiles) == "table" and tiles or {}) do
		local col = math.floor(t.x / 4 + 0.5) + w / 2
		local row = (h / 2 - 1) - math.floor(t.z / 4 + 0.5)
		if col < 0 or col >= w or row < 0 or row >= h or (layer.data[row * w + col + 1] or 0) == 0 then
			return false, "the floor would reach off the town's ground"
		end
		idx[#idx + 1] = row * w + col + 1
	end
	if #idx == 0 then
		return false, "no floor tiles"
	end
	for _, i in ipairs(idx) do
		layer.data[i] = stone
	end
	return true, stone
end

-- The road: the tiles given become the town road (the ground of the road tile it
-- joins). Only grass is turned to road (not the floors under homes, not off the map).
function Main.Road(layout, join, tiles)
	local layer = ground_layer(layout)
	if layer == nil then
		return false, "the town map has no ground layer"
	end
	local road = join ~= nil and tile_at(layer, join.x, join.z) or nil
	if road == nil or road == 0 then
		return false, "the road it joins isn't on the town map"
	end
	local grass = tile_at(layer, -60, 0) -- the camp's grass (the empty west edge)
	local w, h = layer.width, layer.height
	local changed, skipped = 0, 0
	for _, t in ipairs(type(tiles) == "table" and tiles or {}) do
		local col = math.floor(t.x / 4 + 0.5) + w / 2
		local row = (h / 2 - 1) - math.floor(t.z / 4 + 0.5)
		local i = row * w + col + 1
		if col >= 0 and col < w and row >= 0 and row < h and layer.data[i] == grass and grass ~= road then
			layer.data[i] = road
			changed = changed + 1
		elseif layer.data[i] ~= road then
			skipped = skipped + 1
		end
	end
	if changed == 0 and skipped > 0 then
		return false, "no road: its tiles aren't grass"
	end
	return true, changed, skipped
end

local function near(p, q)
	return p ~= nil and q ~= nil and math.abs((p.x or 0) - q.x) < 0.01 and math.abs((p.z or 0) - q.z) < 0.01
end

-- Move a prop the town places (only from where the game put it, so a game update
-- that moves it on its own wins).
function Main.MoveProp(props, prefab, spot)
	local list = type(props) == "table" and props[prefab]
	if type(list) ~= "table" or list[1] == nil then
		return false, prefab .. " isn't in the town's props"
	end
	for _, p in ipairs(list) do
		if near(p, spot.from) then
			p.x, p.z = spot.x, spot.z
			return true
		end
	end
	return false, prefab .. " isn't where it used to be (a game update moved it), left alone"
end

local spawned_in = setmetatable({}, { __mode = "k" })

-- A prop drawn smaller / bigger, the game's way (components/prop.lua flips a prop
-- like this): its animation scaled, and its parallax layers' animations too, their
-- offsets from it scaled with them.
function Main.ScaleProp(inst, k)
	if inst == nil or type(k) ~= "number" or k == 1 then
		return
	end
	if inst.AnimState ~= nil then
		inst.AnimState:SetScale(k, k)
	end
	for _, child in ipairs(inst.highlightchildren or {}) do
		if child.AnimState ~= nil then
			child.AnimState:SetScale(k, k)
		end
		local x, y, z = child.Transform:GetLocalPosition()
		child.Transform:SetPosition(x * k, y * k, z * k)
	end
end

-- Which potion table: Tonic Swap's working one (its prefab is there: the mod is on;
-- it spawns on the host, like the town's other working stations), else the decoration.
function Main.IsHost()
	local net = rawget(_G, "TheNet")
	return net == nil or net.IsHost == nil or net:IsHost()
end

function Main.PotionTableName(settings)
	local exists = rawget(_G, "PrefabExists")
	if settings.working_potion_table and Main.IsHost() and exists ~= nil and exists(Main.TONIC_TABLE) then
		return Main.TONIC_TABLE
	end
	return Main.POTION_TABLE
end

function Main.SpawnPotionTable(propmanager, settings, spot)
	local name = Main.PotionTableName(settings)
	local inst = propmanager:SpawnProp(name, { x = spot.x, z = spot.z }, nil, false)
	if inst ~= nil and name == Main.TONIC_TABLE then
		-- part of his station, not one you built: not saved with the town's decor (or
		-- every load would add another), not refunded / moved by the decor checks
		local okp, Placer = pcall(require, "components.placer")
		local decor_tag = okp and type(Placer) == "table" and Placer.DECOR_TAG or "ManagedDecor"
		inst.persists = false
		if inst.RemoveTag ~= nil then
			inst:RemoveTag(decor_tag)
		end
		-- (one you built on a road tile goes back to your inventory: the game's own
		-- decor check, nothing can be built on the camp's road)
	end
	return inst, name
end

function Main.SpawnInTown(propmanager, settings)
	if spawned_in[propmanager] then
		return
	end
	spawned_in[propmanager] = true
	local look = Main.Look(settings)
	local wagon, table_
	if look.wagon ~= nil then
		wagon = propmanager:SpawnProp(Main.WAGON, { x = look.wagon.x, z = look.wagon.z }, nil, false)
		Main.ScaleProp(wagon, look.wagon.scale)
	end
	if look.table ~= nil then
		table_ = propmanager:SpawnProp(Main.TRAILER, { x = look.table.x, z = look.table.z }, nil, false)
		Main.ScaleProp(table_, look.table.scale)
	end
	local potion
	if settings.road_potion_table and look.potion_table ~= nil then
		potion = Main.SpawnPotionTable(propmanager, settings, look.potion_table)
	end
	local b = look.brother
	-- the host spawns him, like the camp's NPCs (the game sends him to the others)
	local npc = Main.IsHost() and SpawnPrefab(Main.NPC) or nil
	if npc ~= nil then
		npc.Transform:SetWorldPosition(b.x, 0, b.z)
		npc.Transform:SetRotation(b.face == "left" and 180 or 0)
	end
	return table_, npc, wagon, potion
end

-- Hook the town's placed-prop spawn: after the game's own, his station and the
-- brother (once per town load, every machine, like the town's other local props).
function Main.HookSpawn(PropManager, settings)
	if type(PropManager) ~= "table" or type(PropManager.SpawnStaticProps) ~= "function" or type(PropManager.SpawnProp) ~= "function" then
		return false, "the town's prop spawner changed"
	end
	local original = PropManager.SpawnStaticProps
	PropManager.SpawnStaticProps = function(self, ...)
		local spawned = original(self, ...)
		local world = rawget(_G, "TheWorld")
		if world ~= nil and world:HasTag("town") then
			local ok, err = pcall(Main.SpawnInTown, self, settings)
			if not ok then
				print(Main.TAG .. " error spawning the brother (skipped; the game carries on): " .. tostring(err))
			end
		end
		return spawned
	end
	return true
end

-- His name, the game's way. The game copies STRINGS into its content DB when it
-- starts (content/contentloader.lua AddStringTable, before mods load), then
-- SetLanguage (after mods load) rewrites every STRINGS line from that copy
-- (languages/loc.lua TranslateStringTable): a name that's only in STRINGS comes
-- back as "MISSING:STRINGS.NAMES.campbrother_npc". So his name goes in both.
function Main.InstallName(name)
	local S = rawget(_G, "STRINGS")
	if S ~= nil and type(S.NAMES) == "table" then
		S.NAMES[Main.NPC] = name
	end
	local gc = rawget(_G, "TheGameContent")
	local db = gc ~= nil and gc.GetContentDB ~= nil and gc:GetContentDB() or nil
	if db == nil or db.GetAllStrings == nil or db.AddString == nil then
		return false
	end
	local id = "STRINGS.NAMES." .. Main.NPC
	local all = db:GetAllStrings()
	if type(all) == "table" and all[id] == nil then
		db:AddString(id, name)
	elseif type(all) == "table" then
		all[id] = name
	end
	return true
end

function Main.Name(strings)
	return type(strings) == "table" and type(strings.NAME) == "string" and strings.NAME or "Gishins"
end

-- His name, and his chat in the game's quest content (from modmain, once). Returns
-- ok, why.
function Main.InstallTalk(settings, strings, req)
	pcall(Main.InstallName, Main.Name(strings))
	if not settings.talk then
		return false, "off"
	end
	if type(strings) ~= "table" then
		return false, "campbrother_strings.lua has an error"
	end
	local Chat = req "campbrother.chat"
	return Chat.Install(strings, Main.NPC, req)
end

-- From modmain, before the town loads. Returns the parts that are on.
function Main.Install(settings, req, strings)
	req = req or require
	local done, problems = {}, {}
	local okp, props = pcall(req, "map.propdata." .. settings.town_props)
	if not okp or type(props) ~= "table" then
		props = nil
		problems[#problems + 1] = "the town's prop placements changed (" .. tostring(settings.town_props) .. ")"
	end
	if settings.stone_floor then
		local okl, layout = pcall(req, "map/layouts/" .. settings.town_layout)
		if okl and type(layout) == "table" then
			local look = Main.Look(settings)
			local ok, info
			if look.floor_tiles ~= nil then
				ok, info = Main.FloorTiles(layout, props, look.floor_tiles)
			else
				ok, info = Main.StoneFloor(layout, props, settings.floor.x, settings.floor.z)
			end
			if ok then
				done[#done + 1] = "stone floor"
			else
				problems[#problems + 1] = "no stone floor: " .. tostring(info)
			end
		else
			problems[#problems + 1] = "no stone floor: the town map changed (" .. tostring(settings.town_layout) .. ")"
		end
	end
	if settings.road then
		local okl, layout = pcall(req, "map/layouts/" .. settings.town_layout)
		if okl and type(layout) == "table" then
			local ok, changed, skipped = Main.Road(layout, settings.road_join, Main.Look(settings).road_tiles or settings.road_tiles)
			if ok then
				done[#done + 1] = "road to him"
				if skipped ~= nil and skipped > 0 then
					problems[#problems + 1] = skipped .. " road tile(s) left as they were (not grass)"
				end
			else
				problems[#problems + 1] = tostring(changed)
			end
		else
			problems[#problems + 1] = "no road: the town map changed (" .. tostring(settings.town_layout) .. ")"
		end
	end
	if props ~= nil then
		for _, m in ipairs({ { "move_chest", "inventory_chest", "chest", "chest" }, { "move_camp", "player_base_1", "camp", "starting camp" },
			{ "move_rubble", "town_grid_rubble", "rubble", "rubble moved" } }) do
			if settings[m[1]] then
				local ok, why = Main.MoveProp(props, m[2], settings[m[3]])
				if ok then
					done[#done + 1] = m[4]:find("moved", 1, true) and m[4] or (m[4] .. " moved")
				else
					problems[#problems + 1] = why
				end
			end
		end
	end
	local okm, PropManager = pcall(req, "components.propmanager")
	local hooked, why = false, tostring(PropManager)
	if okm then
		hooked, why = Main.HookSpawn(PropManager, settings)
	end
	if hooked then
		local _, name = Main.Look(settings)
		done[#done + 1] = "the brother's station (" .. name .. ")"
		local okt, talks, twhy = pcall(Main.InstallTalk, settings, strings, req)
		if okt and talks then
			done[#done + 1] = "Gishins talks (Chit Chat)"
		elseif not okt then
			problems[#problems + 1] = "Gishins doesn't talk: " .. tostring(talks)
		elseif twhy ~= "off" then
			problems[#problems + 1] = "Gishins doesn't talk: " .. tostring(twhy)
		end
	else
		problems[#problems + 1] = "no brother: " .. tostring(why)
	end
	return done, problems
end

return Main
