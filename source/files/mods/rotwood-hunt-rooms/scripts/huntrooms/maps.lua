-- Hunt Rooms: longer maps (extra rooms) for frenzied side hunts, Super Frenzy
-- side hunts and the Blight's two long middle parts.
--
-- Side hunts: the game's frenzied side hunt map (defs/mapgendata.lua
-- short_mapgen_hard, picked for any side hunt at Frenzy 1+ by
-- RoomLoader.GetAltMapGenID from the location's alternate_mapgens) gets
-- copies with 1 to 8 extra rooms, added at the end of each side hunt's
-- alternate_mapgens (so the game's own entries keep their numbers, and runs
-- saved before keep theirs). The game still picks its own map; when that's the
-- frenzied side hunt map and the run wants extra rooms, the copy with that many
-- is picked instead (the run saves that pick, alt_mapgen_id, like the game's).
-- The copies exist for every count whatever the settings, so a saved run finds
-- its map after a settings change.
--
-- The Blight: its middle parts' map (exp_mapgen, only used there) gets its
-- extra rooms in place.
--
-- An extra room is a 'k-k' stretch (powerrooms.lua): the game's rooms after it
-- move on by one with their own odds, and the game's counters never see it
-- (doors.lua). The pause screen's map gets paths for the new lengths (the
-- start of the game's next longer ones).
local HR = require "huntrooms.main"
local PowerRooms = require "huntrooms.powerrooms"

local Maps = {}

-- the game's room numbers an extra room goes before, in order of use
Maps.SIDE_SLOTS = { 6, 9, 4, 7, 10, 5, 8, 3 }
Maps.BLIGHT_SLOTS = { 6, 4, 8, 5, 7, 9, 3 }
Maps.SIDE_DIFFICULTY = { easy = 20, medium = 75, hard = 5 } -- the game's rooms 3-8
Maps.SUFFIX = "_hr" -- variant names: <the game's name>_hr<count>

Maps.side_base = {}  -- the game's frenzied side hunt map tables
Maps.variants = {}   -- [base def][count] = the copy
Maps.alt = {}        -- [location id][count] = its index in alternate_mapgens
Maps.blight = 0      -- extra rooms in the Blight's middle parts
Maps.blight_defs = {} -- the middle part map tables given them
Maps.pending = nil   -- the run being asked for (RoomLoader.RequestRun / StartRun params)

local function Copy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local c = {}
	seen[t] = c
	for k, v in pairs(t) do
		c[Copy(k, seen)] = Copy(v, seen)
	end
	return setmetatable(c, getmetatable(t))
end

function Maps.Positions(slots, n)
	local out = {}
	for i = 1, math.min(n, #slots) do
		out[i] = slots[i]
	end
	table.sort(out)
	return out
end

-- A copy of a map with n extra rooms (nil if the map isn't laid out as expected).
function Maps.MakeVariant(base, n, slots, difficulty, kind)
	local v = Copy(base)
	v.roomdist = nil
	v.huntrooms_wrapped = nil
	if PowerRooms.Insert(v, Maps.Positions(slots, n), difficulty, kind) ~= n then
		return nil
	end
	v.huntrooms_extra = n
	v.huntrooms_base = base
	return v
end

local function Revalidate(MapGenData)
	-- Validate keeps the smallest miniboss / meta-reward room index it has seen,
	-- so the old ones go first (it sets them again, -1 where there's none)
	for _, def in pairs(MapGenData.defs) do
		if type(def) == "table" then
			def.first_miniboss_index = nil
			def.first_metaunlock_index = nil
		end
	end
	MapGenData.Validate()
end

-- Builds the maps. deps: { MapGenData, biomes, paths (prefabs.mappath_autogen_data or nil) }.
function Maps.Install(deps)
	local s = HR.settings
	local MapGenData, biomes = deps.MapGenData, deps.biomes
	if type(MapGenData) ~= "table" or type(MapGenData.defs) ~= "table" or type(MapGenData.AddDef) ~= "function"
		or type(MapGenData.GetDef) ~= "function" or type(MapGenData.Validate) ~= "function" then
		return false, "a game update changed MapGenData"
	end
	if type(biomes) ~= "table" or type(biomes.locations) ~= "table" then
		return false, "a game update changed defs/biomes"
	end
	-- the game's frenzied side hunt maps and the Blight's middle parts (every
	-- table of each: the game has one, registered under each location's name)
	local exps = {}
	for _, def in pairs(MapGenData.defs) do
		if type(def) == "table" and type(def.room_distribution) == "table" then
			if def.debug_name == "short_mapgen" and (tonumber(def.required_ascension) or 0) >= 1 and not def.huntrooms_base then
				Maps.side_base[def] = true
			elseif def.debug_name == "exp_mapgen" and def.huntrooms_extra == nil then
				exps[def] = true
			end
		end
	end
	local made, lengths = 0, {}
	local side_ok = next(Maps.side_base) ~= nil
	if side_ok then
		for base in pairs(Maps.side_base) do
			Maps.variants[base] = {}
			for n = 1, HR.MAX_EXTRA do
				local v = Maps.MakeVariant(base, n, Maps.SIDE_SLOTS, Maps.SIDE_DIFFICULTY, "side")
				if v == nil then
					side_ok = false
					break
				end
				Maps.variants[base][n] = v
			end
		end
	end
	if side_ok then
		for location_id, loc in pairs(biomes.locations) do
			local list = type(loc) == "table" and loc.alternate_mapgens or nil
			if type(list) == "table" then
				local count = #list
				for i = 1, count do
					local def = MapGenData.GetDef(list[i])
					if Maps.side_base[def] then
						Maps.alt[location_id] = Maps.alt[location_id] or {}
						for n = 1, HR.MAX_EXTRA do
							local name = tostring(list[i]) .. Maps.SUFFIX .. n
							if MapGenData.GetDef(name) == nil then
								MapGenData.AddDef(name, Maps.variants[def][n])
							end
							local at = nil
							for j, existing in ipairs(list) do
								if existing == name then
									at = j
								end
							end
							if at == nil then
								list[#list + 1] = name
								at = #list
							end
							Maps.alt[location_id][n] = at
							made = made + 1
						end
						break
					end
				end
			end
		end
	end
	local blight_info = "the Blight: the game's length"
	if next(exps) ~= nil and s.blight_rooms > 0 then
		local done, bad = 0, 0
		for exp in pairs(exps) do
			local stretch = nil
			for key, dist in pairs(exp.room_distribution) do
				if key == "3-9" then
					stretch = dist
				end
			end
			local difficulty = stretch ~= nil and stretch.difficulty_distribution or Maps.SIDE_DIFFICULTY
			local n = PowerRooms.Insert(exp, Maps.Positions(Maps.BLIGHT_SLOTS, s.blight_rooms), difficulty, "blight")
			if n == s.blight_rooms then
				exp.huntrooms_extra = n
				Maps.blight_defs[exp] = true
				done = done + 1
			else
				bad = bad + 1
			end
		end
		if done > 0 then
			Maps.blight = s.blight_rooms
			blight_info = string.format("the Blight: +%d rooms in each middle part", s.blight_rooms)
		end
		if bad > 0 then
			blight_info = blight_info .. string.format(" (%d of its middle maps not laid out as expected: the game's length)", bad)
		end
	elseif next(exps) == nil and s.blight_rooms > 0 then
		blight_info = "the Blight: the game's length (its middle map wasn't found)"
	end
	Revalidate(MapGenData)
	for base, list in pairs(Maps.variants) do
		for _, v in pairs(list) do
			if type(v.hunt_length_for_ui) == "number" then
				lengths[v.hunt_length_for_ui] = true
			end
		end
	end
	for exp in pairs(Maps.blight_defs) do
		if type(exp.hunt_length_for_ui) == "number" then
			lengths[exp.hunt_length_for_ui] = true
		end
	end
	local paths_made = 0
	if type(deps.paths) == "table" then
		local ok, n = pcall(PowerRooms.Paths, deps.paths, lengths, "huntrooms_")
		paths_made = ok and n or 0
	end
	local side_info = side_ok and made > 0 and "side hunts: longer when frenzied" or "side hunts: the game's length (the frenzied side hunt map wasn't found as expected)"
	Maps.side_on = side_ok and made > 0
	return Maps.side_on or Maps.blight > 0, string.format("%s; %s; %d pause-map paths made", side_info, blight_info, paths_made)
end

local function AM()
	local dungeon = rawget(_G, "TheDungeon")
	local progression = dungeon ~= nil and dungeon.progression or nil
	return progression ~= nil and progression.components ~= nil and progression.components.ascensionmanager or nil
end
Maps.AM = AM

-- How many extra rooms a side hunt wants: its Super Frenzy level's (Frenzy
-- Levels), else frenzy_side_rooms at Frenzy 1+, else 0.
function Maps.SideCount(location_id)
	local s = HR.settings
	local p = Maps.pending
	if type(p) ~= "table" or p.location_id ~= location_id then
		p = nil
	end
	local level = p ~= nil and tonumber(p.ascension) or nil
	if level == nil then
		local am = AM()
		level = am ~= nil and am.GetSelectedAscension ~= nil and am:GetSelectedAscension(location_id) or 0
	end
	level = tonumber(level) or 0
	local SS = package.loaded["frenzylevels.superside"]
	if type(SS) == "table" and type(SS.SuperSideLevel) == "function" then
		local ok, sf = pcall(SS.SuperSideLevel, location_id, level, p ~= nil and p.is_weather_enabled == true or false)
		if ok and type(sf) == "number" and s.super_side_rooms[sf] ~= nil then
			return s.super_side_rooms[sf], "Super Frenzy " .. sf
		end
	end
	if level >= 1 then
		return s.frenzy_side_rooms, "Frenzy " .. level
	end
	return 0, "no frenzy"
end

-- The game's pick (an index in the location's alternate_mapgens, or nil) ->
-- the longer copy when it's the frenzied side hunt map and the run wants one.
function Maps.PickAlt(location_id, idx)
	local MapGenData = require "defs.mapgendata"
	local biomes = require "defs.biomes"
	local loc = biomes.locations[location_id]
	local list = type(loc) == "table" and loc.alternate_mapgens or nil
	if type(idx) ~= "number" or type(list) ~= "table" or list[idx] == nil then
		return idx
	end
	if not Maps.side_base[MapGenData.GetDef(list[idx])] or Maps.alt[location_id] == nil then
		return idx
	end
	local n, why = Maps.SideCount(location_id)
	if n <= 0 then
		return idx
	end
	local at = Maps.alt[location_id][n]
	if at == nil or list[at] == nil or MapGenData.GetDef(list[at]) == nil then
		return idx
	end
	HR.Log(string.format("%s (%s): %d extra room%s", tostring(location_id), why, n, n == 1 and "" or "s"))
	return at
end

-- The game's RoomLoader: the pick, and the run asked for while it's made.
function Maps.Hook(RoomLoader)
	if type(RoomLoader) ~= "table" or type(RoomLoader.GetAltMapGenID) ~= "function" then
		return false, "a game update changed RoomLoader.GetAltMapGenID"
	end
	local orig = RoomLoader.GetAltMapGenID
	RoomLoader.GetAltMapGenID = function(region_id, location_id, ...)
		local idx = orig(region_id, location_id, ...)
		if HR.On("longer side hunts") then
			local ok, v = HR.Call("longer side hunts", Maps.PickAlt, location_id, idx)
			if ok and (v == nil or type(v) == "number") then
				return v
			end
		end
		return idx
	end
	for _, name in ipairs({ "RequestRun", "StartRun" }) do
		local fn = RoomLoader[name]
		if type(fn) == "function" then
			RoomLoader[name] = function(a, params, ...)
				local before = Maps.pending
				-- RequestRun(playerID, params) / StartRun(params, quest_params)
				Maps.pending = type(params) == "table" and params.location_id ~= nil and params or (type(a) == "table" and a.location_id ~= nil and a or nil)
				local r = table.pack(pcall(fn, a, params, ...))
				Maps.pending = before
				if not r[1] then
					error(r[2], 0)
				end
				return table.unpack(r, 2, r.n)
			end
		end
	end
	return true
end

-- The game's room roll (MapGenHelp.CreateRoomGenState) for a room the map has
-- no odds for (a run saved with other settings, or before an install): the
-- map's last odds (a one-door room toward the boss) instead of the game's assert.
function Maps.HookClamp(MapGenHelp)
	if type(MapGenHelp) ~= "table" or type(MapGenHelp.CreateRoomGenState) ~= "function" then
		return false
	end
	local orig = MapGenHelp.CreateRoomGenState
	local told = false
	MapGenHelp.CreateRoomGenState = function(location_id, mapgen_def, mapgen_state, rng, index, ...)
		local rd = type(mapgen_def) == "table" and mapgen_def.roomdist or nil
		if type(rd) == "table" and type(index) == "number" and rd[index] == nil and #rd > 0 and index > #rd then
			if not told then
				told = true
				HR.Log(string.format("room %d: past the map's %d rooms (a run saved with other settings?): the map's last odds", index, #rd))
			end
			index = #rd
		end
		return orig(location_id, mapgen_def, mapgen_state, rng, index, ...)
	end
	return true
end

return Maps
