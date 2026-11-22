-- Hunt Rooms: console commands for testing (the game's console). Nothing runs
-- until one is typed: they're only defined.
--   hr_help()                this list
--   hr_doors()               this room and its doors: what each gives, what Hunt Rooms changed, the run's counts
--   hr_start("treemon_forest_r1", 3)   a hunt at a level: 0 none, 1-5 Frenzy, 6-10 Super Frenzy 1-5
--                            (side hunts: Frenzy Levels' Super Frenzy side hunts), as if picked on the map
--   hr_start("treemon_forest", 8, 12345)   ... on that seed's map
--   hr_again()               this hunt again on a new map: the same place, Frenzy level, map and weather
--   hr_again(12345)          ... on that seed's map (a seed always makes the same map)
--   hr_sim()                 this hunt's map played 1000 times on the game's own map code: the odds, in the log
--   hr_sim(5000, "any", 7)   5000 runs taking any door, seed 7 (the same seed: the same numbers)
--
-- The sim (hr_sim): the game's own map generation (components/mapgenrun.lua,
-- defs/mapgendata.lua, util/mapgenhelp.lua and mapgenstate.lua) with every
-- mod's hooks as installed (Hunt Rooms, Two Weapons' rule, Frenzy Levels'
-- hard rooms), on throwaway maps of the hunt you're in. Kept apart from your run:
--  * the network's room record (TheNet's travel history, which the map and the
--    doors read): while the sim runs, TheNet is a stand-in that drops the
--    sim's writes; after, the record is set again from your run's own map
--  * Hunt Rooms' run record (the caps): a sandbox, the sim's own counts
--  * the map log and print are muted while it runs (thousands of lines)
--  * an error inside a sim run is counted and shown; it never turns a part off
--    for the game, and everything is put back even after one
--  * at most MAX_SECONDS (the game waits while it runs)
-- The sim player takes weapon power doors first ("takes"; then Fabled, then a
-- normal power, else any), or any door ("any"). Your run's players are read
-- as they are, as the game does (health and potions: its potion room odds;
-- gifts: its gift room odds).
local HR = require "huntrooms.main"
local Tracker = require "huntrooms.tracker"
local PowerRooms = require "huntrooms.powerrooms"
local Doors = require "huntrooms.doors"

local C = {}

C.DEFAULT_RUNS = 1000
C.MAX_RUNS = 20000
C.MAX_SECONDS = 10
C.busy = false

C.NAMES = { plain = "normal power", weaponpower = "weapon power", fabled = "Fabled", coin = "Teffra", small_token = "corestone",
	big_token = "big token", friendgift = "gift", material = "material", shard = "Heart Shard", skill = "skill", none = "nothing",
	restroom = "rest room" }
local DIFF = { [1] = "easy", [2] = "medium", [3] = "hard" }

local function Say(lines)
	for _, l in ipairs(lines) do
		print(HR.TAG .. " " .. l)
	end
	return lines
end

local function Global(name)
	return rawget(_G, name)
end

local function Name(reward)
	return C.NAMES[reward] or tostring(reward)
end

function C.RoomText(room)
	if type(room) ~= "table" then
		return "?"
	end
	local t = tostring(room.roomtype)
	if room.roomtype == "monster" and DIFF[room.difficulty] ~= nil then
		t = t .. " " .. DIFF[room.difficulty]
	end
	t = t .. ", " .. Name(room.reward)
	if room.is_mystery then
		t = t .. " (mystery)"
	end
	local o = room.huntrooms_orig
	if room.huntrooms_power ~= nil then
		t = t .. (room.huntrooms_shard and " [Hunt Rooms' extra room: a Heart Shard room]" or " [Hunt Rooms' extra room]")
	elseif room.huntrooms_miniboss then
		t = t .. " [Hunt Rooms: the Blight's miniboss, this part had none yet]"
	elseif type(o) == "table" and (o.reward ~= room.reward or o.roomtype ~= room.roomtype) then
		t = t .. " [Hunt Rooms: was " .. tostring(o.roomtype) .. ", " .. Name(o.reward) .. "]"
	end
	return t
end

function C.MapName(location_id, alt)
	local ok, biomes = pcall(require, "defs.biomes")
	local loc = ok and type(biomes) == "table" and type(biomes.locations) == "table" and biomes.locations[location_id] or nil
	local list = type(loc) == "table" and loc.alternate_mapgens or nil
	if alt ~= nil and type(list) == "table" and list[alt] ~= nil then
		return tostring(list[alt])
	end
	return tostring(location_id)
end

-- The hunt map you're in (the game's MapGenRun), or nil and why.
function C.RealRun()
	local dungeon = Global("TheDungeon")
	if dungeon == nil or dungeon.GetDungeonMap == nil then
		return nil, "not in a run"
	end
	local world = Global("TheWorld")
	if world ~= nil and world.HasTag ~= nil and world:HasTag("town") then
		return nil, "you're in town: start the hunt first (its first room is enough)"
	end
	if dungeon.IsUsingMapGenRun ~= nil and not dungeon:IsUsingMapGenRun() then
		return nil, "this room isn't from a hunt's map (a debug room?)"
	end
	local map = dungeon:GetDungeonMap()
	local mg = map ~= nil and map.mgrun or nil
	if type(mg) ~= "table" or type(mg.data) ~= "table" or type(mg.data.current) ~= "table" or mg.mapgendef == nil then
		return nil, "no hunt map is active"
	end
	return mg
end

function C.Kind(mg)
	local ok, kind, level = pcall(Doors.RunKind, mg)
	if not ok then
		return "?", 0
	end
	return tostring(kind), tonumber(level) or 0
end

local KIND_TEXT = { main = "main hunt", main_frenzy = "main hunt, Frenzy %d", main_super = "main hunt, Super Frenzy %d", side = "side hunt",
	side_frenzy = "side hunt, Frenzy %d", side_super = "side hunt, Super Frenzy %d", blight = "the Blight" }
function C.KindText(kind, level)
	local f = KIND_TEXT[kind]
	if f == nil then
		return tostring(kind) .. " " .. tostring(level)
	end
	return f:find("%d", 1, true) and string.format(f, tonumber(level) or 0) or f
end

local function Last(mg)
	if mg.IsProgressComplete ~= nil then
		local ok, done = pcall(mg.IsProgressComplete, mg)
		if ok then
			return done == true
		end
	end
	return (tonumber(mg.data.current.index) or 0) >= (tonumber(mg.data.max_rooms) or 0)
end

local function Cardinals(next_rooms)
	local list = {}
	for c in pairs(type(next_rooms) == "table" and next_rooms or {}) do
		list[#list + 1] = c
	end
	table.sort(list)
	return list
end

----------------------------------------------------------------------------
-- hr_help

function C.Help()
	return Say({
		"console commands (type them in the game's console):",
		"  hr_doors()              this room and its doors: what each gives, what Hunt Rooms changed, the run's counts",
		"  hr_start(\"treemon_forest_r1\", 3)   a hunt at a level (0 none, 1-5 Frenzy, 6-10 Super Frenzy 1-5), as if picked on the map; a 3rd number: the seed",
		"  hr_again()              this hunt again on a new map (the same place, Frenzy level, map and weather)",
		"  hr_again(12345)         ... on that seed's map (the same seed: the same map)",
		"  hr_sim()                this hunt's map played " .. C.DEFAULT_RUNS .. " times on the game's map code (your run doesn't change): the odds",
		"  hr_sim(5000, \"any\")     5000 runs taking any door (default \"takes\": weapon power doors first, then Fabled, then a normal power)",
		"  hr_sim(1000, \"takes\", 7)  with a seed: the same numbers every time",
		"  the game's own: d_clearroom() ends the fight, d_unlockroom() opens the doors, d_restartrun() this run again (the same map)",
	})
end

----------------------------------------------------------------------------
-- hr_doors

function C.Doors()
	local mg, why = C.RealRun()
	if mg == nil then
		return Say({ "hr_doors: " .. why })
	end
	local d = mg.data
	local cur = d.current
	local kind, level = C.Kind(mg)
	local lines = {
		string.format("room %s of %s: %s; %s, %s (map %s)", tostring(cur.index), tostring(d.max_rooms), C.RoomText(cur), C.KindText(kind, level),
			tostring(d.location_id), C.MapName(d.location_id, d.alt_mapgen_id)),
	}
	local cards = Cardinals(d.next)
	if Last(mg) then
		lines[#lines + 1] = "  the last room: no doors"
	elseif #cards == 0 then
		lines[#lines + 1] = "  no doors yet"
	else
		for _, c in ipairs(cards) do
			lines[#lines + 1] = "  " .. c .. ": " .. C.RoomText(d.next[c])
		end
		local ok, extra = pcall(PowerRooms.Is, mg.mapgendef, (tonumber(cur.index) or 0) + 1)
		if ok and extra ~= nil then
			lines[#lines + 1] = "  the next room is one of Hunt Rooms' extra rooms (" .. tostring(extra) .. ")"
		end
	end
	local s = HR.settings
	local okw, wp = pcall(Tracker.WeaponPowerRooms)
	local okf, fab = pcall(Tracker.Count, "mod_fabled")
	local okg, gwp = pcall(Tracker.Count, "game_wp")
	local okd, doors = pcall(Tracker.Count, Tracker.DOOR)
	local okl, leg = pcall(Tracker.Leg)
	local allowance = (okl and leg ~= nil) and s.weapon_power_doors_blight or s.weapon_power_doors
	lines[#lines + 1] = string.format("  this run: weapon power rooms %s of %d, weapon power doors shown %s of %d, Hunt Rooms' Fabled %s of %d, the game's own weapon power rooms %s",
		okw and tostring(wp) or "?", s.weapon_power_rooms, okd and tostring(doors) or "?", allowance, okf and tostring(fab) or "?", s.extra_fabled, okg and tostring(gwp) or "?")
	-- 0.3.0: the run's Fabled families, the Heart Shard room
	local okp, fams = pcall(function() return Global("TheDungeon").progression.components.powerroller:GetSelectedFabledFamilies() end)
	if okp and type(fams) == "table" and #fams > 0 then
		lines[#lines + 1] = "  this run's Fabled families: " .. table.concat(fams, " + ")
	end
	local Shard = package.loaded["huntrooms.shardroom"]
	if type(Shard) == "table" and Shard.installed then
		local okl, level = pcall(Shard.Level, mg)
		if okl and level ~= nil then
			local okt, taken = pcall(Shard.Taken)
			lines[#lines + 1] = string.format("  the Heart Shard room (Super Frenzy %d: %d%% each extra room, %d each): %s", level, s.shard_room[level] or 0, s.shard_room_shards[level] or 0,
				(okt and taken) and "taken this hunt" or "not taken yet")
		end
	end
	local off = {}
	for part in pairs(HR.off) do
		off[#off + 1] = part
	end
	if #off > 0 then
		table.sort(off)
		lines[#lines + 1] = "  off this session after an error: " .. table.concat(off, ", ")
	end
	return Say(lines)
end

----------------------------------------------------------------------------
-- hr_again

function C.Again(seed)
	local mg, why = C.RealRun()
	if mg == nil then
		return Say({ "hr_again: " .. why })
	end
	local net = Global("TheNet")
	local okh, host = pcall(function() return net:IsHost() end)
	if not okh or not host then
		return Say({ "hr_again: the host's game only" })
	end
	local dungeon = Global("TheDungeon")
	local okt, trek = pcall(function() return dungeon:GetTrek() end)
	if okt and trek ~= nil and trek.IsActive ~= nil and trek:IsActive() then
		return Say({ "hr_again: in the Blight, d_starttrek() starts a new one (then d_nextleg(1) jumps to its second part)" })
	end
	local ok, mode, _seq, params = pcall(function() return net:GetRunData() end)
	if not ok or type(params) ~= "table" or params.location_id == nil then
		return Say({ "hr_again: the game has no run data for this run" })
	end
	local default = Global("STARTRUNMODE_DEFAULT")
	if default ~= nil and mode ~= default then
		return Say({ "hr_again: this is a debug room (d_startboss and the like), not a hunt" })
	end
	local start = Global("d_startrunwithparams")
	if type(start) ~= "function" then
		return Say({ "hr_again: the game's d_startrunwithparams isn't there" })
	end
	local copy = Global("deepcopy")
	local p
	if type(copy) == "function" then
		p = copy(params)
	else
		p = {}
		for k, v in pairs(params) do
			p[k] = v
		end
	end
	local n = tonumber(seed)
	if n == nil then
		local okk, krandom = pcall(require, "util.krandom")
		local okg, s = false, nil
		if okk and type(krandom) == "table" and krandom.GenerateSeed ~= nil then
			okg, s = pcall(krandom.GenerateSeed)
		end
		n = okg and tonumber(s) or (os.time() + math.random(1, 1000000))
	end
	p.seed = math.floor(n)
	Say({ string.format("hr_again: %s, %s (map %s), seed %d%s", C.KindText(C.Kind(mg)), tostring(p.location_id), C.MapName(p.location_id, p.alt_mapgen_id),
		p.seed, p.is_weather_enabled and ", anomaly weather" or "") })
	start(p)
	return p
end

----------------------------------------------------------------------------
-- hr_start

-- A hunt at a level, as if picked on the map: the level is stored first (the
-- game picks the run's map from the stored level before it stores the run's
-- own, so d_startrun alone with a new level gets the map of the old one), on
-- a side hunt also Frenzy Levels' pick (its Super Frenzy side hunts: 6-10),
-- then the run starts the way the game's d_startrun does it (a Blight left
-- running ends first, then d_startrunwithparams), without d_startrun's
-- skip_new_game_flow flag in the cheats save (it changes how a debug launch
-- picks the character). level: 0 none, 1-5 Frenzy, 6-10 Super Frenzy 1-5.
function C.Start(location_id, level, seed)
	local net = Global("TheNet")
	local okh, host = pcall(function() return net:IsHost() end)
	if net ~= nil and okh and not host then
		return Say({ "hr_start: the host's game only" })
	end
	local okb, biomes = pcall(require, "defs.biomes")
	local loc = okb and type(biomes) == "table" and type(biomes.locations) == "table" and type(location_id) == "string" and biomes.locations[location_id] or nil
	if loc == nil then
		return Say({ "hr_start: no hunt called " .. tostring(location_id) .. " (for example \"treemon_forest\", \"treemon_forest_r1\")" })
	end
	local start = Global("d_startrunwithparams")
	if type(start) ~= "function" then
		return Say({ "hr_start: the game's d_startrunwithparams isn't there" })
	end
	local dungeon = Global("TheDungeon")
	local am = nil
	pcall(function() am = dungeon.progression.components.ascensionmanager end)
	if am == nil or am.StoreSelectedAscension == nil then
		return Say({ "hr_start: the game's Frenzy levels aren't there (start the game first)" })
	end
	local normal = tonumber(Global("NORMAL_FRENZY_LEVELS")) or 5
	local top = tonumber(Global("TOTAL_FRENZY_LEVELS")) or 10
	local want = math.max(0, math.min(top, math.floor(tonumber(level) or 0)))
	local game_level, note = want, nil
	local side = type(biomes.IsSublocation) == "function" and biomes.IsSublocation(location_id) == true
	if side then
		local FL = package.loaded["frenzylevels"]
		local has_fl = type(FL) == "table" and type(FL.SetSideChoice) == "function"
		if want > normal then
			if not (has_fl and type(FL.SuperSideOn) == "function" and FL.SuperSideOn()) then
				return Say({ "hr_start: side hunts have Super Frenzy only with Frenzy Levels' super_side_hunts on" })
			end
			local got = FL.SetSideChoice(am, location_id, want)
			if got < want then
				note = string.format("Super Frenzy %d isn't open on this hunt yet: level %d", want - normal, got)
			end
			want = got
			game_level = math.min(normal, got)
		elseif has_fl then
			FL.SetSideChoice(am, location_id, want)
		end
	end
	am:StoreSelectedAscension(location_id, game_level)
	local n = tonumber(seed)
	if n == nil then
		local okk, krandom = pcall(require, "util.krandom")
		local okg, s2 = false, nil
		if okk and type(krandom) == "table" and krandom.GenerateSeed ~= nil then
			okg, s2 = pcall(krandom.GenerateSeed)
		end
		n = okg and tonumber(s2) or (os.time() + math.random(1, 1000000))
	end
	n = math.floor(n)
	local what = want == 0 and "no frenzy" or (want <= normal and ("Frenzy " .. want) or ("Super Frenzy " .. (want - normal)))
	local lines = { string.format("hr_start: %s, %s, seed %d (hr_start(\"%s\", %d, %d) makes this map again)", location_id, what, n, location_id, want, n) }
	if note ~= nil then
		lines[#lines + 1] = "  " .. note
	end
	Say(lines)
	-- d_startrun's own steps: a Blight left running ends first
	local okt, trek = pcall(function() return dungeon:GetTrek() end)
	if okt and trek ~= nil and trek.IsActive ~= nil and trek:IsActive() and type(Global("d_endtrek")) == "function" then
		Global("d_endtrek")()
	end
	local p = { location_id = location_id, region_id = loc.region_id, seed = n, ascension = game_level }
	start(p)
	return { location_id = location_id, level = want, game_level = game_level, seed = n, params = p }
end

----------------------------------------------------------------------------
-- hr_sim

local QUIET = setmetatable({}, { __index = function() return function() end end })

-- TheNet for the sim's length: the room record's writes dropped, the rest the real one's.
function C.NetStandIn(net)
	local cache = { HostSetRoomTravelHistory = function() end }
	local stand_in = {}
	return setmetatable(stand_in, { __index = function(_, k)
		local f = cache[k]
		if f ~= nil then
			return f
		end
		local v = net[k]
		if type(v) == "function" then
			f = function(self, ...)
				if self == stand_in then
					self = net
				end
				return v(self, ...)
			end
			cache[k] = f
			return f
		end
		return v
	end })
end

local PREF = { weaponpower = 1, fabled = 2, plain = 3 }

function C.Pick(doors, policy, rng)
	if policy == "any" then
		return doors[rng:Integer(#doors)]
	end
	local best, bestp, ties = nil, 99, 0
	for _, door in ipairs(doors) do
		local p = PREF[door.room.reward] or 9
		if p < bestp then
			best, bestp, ties = door, p, 1
		elseif p == bestp then
			ties = ties + 1
			if rng:Integer(ties) == 1 then
				best = door
			end
		end
	end
	return best
end

local function Add(t, k, n)
	t[k] = (t[k] or 0) + (n or 1)
end

-- One sim run: the map from its entrance to its last room. Returns its counts.
function C.OneRun(MapGenRun, base, seed, rng, policy, S)
	local s = HR.settings
	local mg = MapGenRun(nil)
	mg:Init({ location_id = base.location_id, alt_mapgen_id = base.alt_mapgen_id, wants_quest_room = base.wants_quest_room, rng_seed = seed })
	local def = mg.mapgendef
	local run = { wp = 0, start = 0, fabled = 0, mod_fabled = 0, plain = 0, rooms = 0, extra = 0, extra_coin = 0,
		entered = {}, types = {}, extra_by = {}, doors = {}, xdoors = {}, ndoors = 0, nxdoors = 0 }
	local function Enter(room)
		run.rooms = run.rooms + 1
		local reward = tostring(room.reward)
		Add(run.entered, reward)
		if room.roomtype ~= "monster" then
			Add(run.types, tostring(room.roomtype))
		end
		local extra = PowerRooms.Is(def, room.index) or room.huntrooms_power
		if extra ~= nil then
			run.extra = run.extra + 1
			Add(run.extra_by, reward)
			if reward == "coin" then
				run.extra_coin = run.extra_coin + 1
			end
		end
		if reward == "weaponpower" then
			-- taken after the room's doors are made (as in the game): a power for each weapon
			run.wp = run.wp + 1
			S.wp = S.wp + 1
		elseif reward == "fabled" then
			run.fabled = run.fabled + 1
			local o = room.huntrooms_orig
			if extra ~= nil or (type(o) == "table" and o.reward ~= "fabled") then
				run.mod_fabled = run.mod_fabled + 1
			end
		elseif reward == "plain" and (tonumber(room.index) or 0) > 1 then
			run.plain = run.plain + 1
		end
		-- the start's weapon power choice (freestart.lua): the first map's
		-- entrance, a pick that isn't the weapon power one, the cap not reached
		if room.index == 1 and S.first and HR.start_on and HR.On("the start's weapon power") and reward ~= "none" and reward ~= "weaponpower"
			and S.wp < s.weapon_power_rooms then
			run.wp = run.wp + 1
			run.start = 1
			S.wp = S.wp + 1
		end
	end
	Enter(mg.data.current)
	for _ = 1, 64 do
		if Last(mg) then
			break
		end
		local doors = {}
		for _, c in ipairs(Cardinals(mg.data.next)) do
			doors[#doors + 1] = { c = c, room = mg.data.next[c] }
		end
		if #doors == 0 then
			break
		end
		local into_extra = PowerRooms.Is(def, (tonumber(mg.data.current.index) or 0) + 1) ~= nil
		for _, door in ipairs(doors) do
			local reward = tostring(door.room.reward)
			Add(run.doors, reward)
			run.ndoors = run.ndoors + 1
			if into_extra then
				Add(run.xdoors, reward)
				run.nxdoors = run.nxdoors + 1
			end
		end
		mg:AdvanceCurrentRoom(C.Pick(doors, policy, rng).c)
		Enter(mg.data.current)
	end
	return run
end

local function Merge(R, run)
	R.n = R.n + 1
	Add(R.wp_dist, run.wp)
	Add(R.fab_dist, run.fabled)
	for _, k in ipairs({ "wp", "start", "fabled", "mod_fabled", "plain", "rooms", "extra", "extra_coin", "ndoors", "nxdoors" }) do
		R[k] = R[k] + run[k]
	end
	if run.wp > HR.settings.weapon_power_rooms then
		R.over_wp = R.over_wp + 1
	end
	if run.mod_fabled > HR.settings.extra_fabled then
		R.over_fab = R.over_fab + 1
	end
	for _, k in ipairs({ "entered", "types", "extra_by", "doors", "xdoors" }) do
		for key, v in pairs(run[k]) do
			Add(R[k], key, v)
		end
	end
end

local function NewResults()
	return { n = 0, wp = 0, start = 0, fabled = 0, mod_fabled = 0, plain = 0, rooms = 0, extra = 0, extra_coin = 0, ndoors = 0, nxdoors = 0,
		over_wp = 0, over_fab = 0, wp_dist = {}, fab_dist = {}, entered = {}, types = {}, extra_by = {}, doors = {}, xdoors = {} }
end

local function Dist(t, n)
	local o = {}
	for k = 0, 20 do
		if t[k] then
			o[#o + 1] = string.format("%d: %.0f%%", k, 100 * t[k] / n)
		end
	end
	return table.concat(o, ", ")
end

-- "a 40%, b 30%" by share, most first
local function Shares(t, total, per_run)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		if t[a] ~= t[b] then
			return t[a] > t[b]
		end
		return tostring(a) < tostring(b)
	end)
	local o = {}
	for _, k in ipairs(keys) do
		if per_run then
			o[#o + 1] = string.format("%s %.2f", Name(k), t[k] / total)
		else
			o[#o + 1] = string.format("%s %.0f%%", Name(k), 100 * t[k] / total)
		end
	end
	return #o > 0 and table.concat(o, ", ") or "none"
end

function C.Report(R, head, extra_lines)
	local s = HR.settings
	local n = R.n
	local lines = { head }
	if n == 0 then
		lines[#lines + 1] = "  no run finished"
	else
		lines[#lines + 1] = string.format("  rooms: %.1f a run (Hunt Rooms' extra rooms: %.1f)", R.rooms / n, R.extra / n)
		lines[#lines + 1] = string.format("  weapon power rooms (with the start's choice): %.2f a run; %s; the cap %d: %s", R.wp / n, Dist(R.wp_dist, n),
			s.weapon_power_rooms, R.over_wp == 0 and "never over" or (R.over_wp .. " runs over"))
		lines[#lines + 1] = string.format("  the start's weapon power choice: %.0f%% of runs", 100 * R.start / n)
		lines[#lines + 1] = string.format("  Fabled rooms: %.2f a run (Hunt Rooms' %.2f, the game's %.2f); %s; Hunt Rooms' cap %d: %s", R.fabled / n, R.mod_fabled / n,
			(R.fabled - R.mod_fabled) / n, Dist(R.fab_dist, n), s.extra_fabled, R.over_fab == 0 and "never over" or (R.over_fab .. " runs over"))
		lines[#lines + 1] = string.format("  normal power rooms (after the first room): %.2f a run", R.plain / n)
		if R.extra > 0 then
			lines[#lines + 1] = string.format("  extra rooms: %s; Teffra in one: %s", Shares(R.extra_by, R.extra), R.extra_coin == 0 and "never" or (R.extra_coin .. " times"))
			lines[#lines + 1] = "  doors into the extra rooms: " .. Shares(R.xdoors, math.max(1, R.nxdoors))
		end
		lines[#lines + 1] = "  rooms entered by reward, a run: " .. Shares(R.entered, n, true)
		lines[#lines + 1] = "  rooms that aren't fights, a run: " .. Shares(R.types, n, true)
		lines[#lines + 1] = "  every door offered: " .. Shares(R.doors, math.max(1, R.ndoors))
	end
	for _, l in ipairs(extra_lines or {}) do
		lines[#lines + 1] = l
	end
	return lines
end

function C.Sim(runs, policy, seed)
	if C.busy then
		return Say({ "hr_sim: already running" })
	end
	local n = math.floor(tonumber(runs) or C.DEFAULT_RUNS)
	n = math.max(1, math.min(C.MAX_RUNS, n))
	policy = policy == "any" and "any" or "takes"
	local real, why = C.RealRun()
	if real == nil then
		return Say({ "hr_sim: " .. why })
	end
	local net = Global("TheNet")
	local okh, host = pcall(function() return net:IsHost() end)
	if not okh or not host then
		return Say({ "hr_sim: the host's game only" })
	end
	local okm, MapGenRun = pcall(require, "components.mapgenrun")
	local okk, krandom = pcall(require, "util.krandom")
	if not okm or MapGenRun == nil or not okk or type(krandom) ~= "table" then
		return Say({ "hr_sim: the game's map code isn't there (a game update?)" })
	end
	local base = { location_id = real.data.location_id, alt_mapgen_id = real.data.alt_mapgen_id, wants_quest_room = real.data.wants_quest_room }
	local kind, level = C.Kind(real)
	local seed0 = tonumber(seed) and math.floor(tonumber(seed)) or nil
	if seed0 == nil then
		local okg, s = pcall(krandom.GenerateSeed)
		seed0 = okg and tonumber(s) or os.time()
	end
	local okr, rng = pcall(krandom.CreateGenerator, seed0)
	if not okr or rng == nil then
		return Say({ "hr_sim: the game's random numbers aren't there" })
	end
	local okf, first = pcall(Tracker.FirstMap)
	local S = { wp = 0, mem = {}, first = not okf or first ~= false }
	local R = NewResults()

	-- the sandbox
	local kept = { Reset = Tracker.Reset, Record = Tracker.Record, Count = Tracker.Count, WeaponPowerRooms = Tracker.WeaponPowerRooms, Recorded = Tracker.Recorded,
		FirstMap = Tracker.FirstMap, current = Tracker.current, mem = Tracker.mem }
	local off_before = {}
	for k, v in pairs(HR.off) do
		off_before[k] = v
	end
	local log = Global("TheLog")
	local ch = type(log) == "table" and type(log.ch) == "table" and log.ch or nil
	local log_ch = ch ~= nil and rawget(ch, "MapGen") or nil
	local real_print = rawget(_G, "print")
	local stand_in = C.NetStandIn(net)
	local function Install()
		Tracker.Reset = function() S.mem = {} end
		Tracker.Record = function(key, kind_) S.mem[key] = kind_ end
		Tracker.Count = function(kind_, leave_out)
			local c = 0
			for k, v in pairs(S.mem) do
				if v == kind_ and k ~= leave_out then
					c = c + 1
				end
			end
			return c
		end
		Tracker.WeaponPowerRooms = function() return S.wp end -- (counted after each room's doors, as the powers come)
		Tracker.Recorded = function(key) return S.mem[key] ~= nil end
		Tracker.FirstMap = function() return S.first end
		rawset(_G, "TheNet", stand_in)
		if ch ~= nil then
			rawset(ch, "MapGen", QUIET)
		end
		rawset(_G, "print", function() end)
	end
	local sim_off = {}
	local function Restore()
		rawset(_G, "print", real_print)
		if ch ~= nil then
			rawset(ch, "MapGen", log_ch)
		end
		rawset(_G, "TheNet", net)
		for k, v in pairs(kept) do
			Tracker[k] = v
		end
		-- an error in the sim never turns a part off for the game
		for part, err in pairs(HR.off) do
			if off_before[part] == nil then
				sim_off[#sim_off + 1] = part .. ": " .. tostring(err)
				HR.off[part] = nil
			end
		end
		table.sort(sim_off)
	end

	C.busy = true
	local t0 = os.clock()
	local errors, first_error, stopped = 0, nil, false
	local ok_all, err_all = pcall(function()
		Install()
		for _ = 1, n do
			if os.clock() - t0 > C.MAX_SECONDS then
				stopped = true
				break
			end
			S.wp, S.mem = 0, {}
			Tracker.current = nil
			local ok, run = pcall(C.OneRun, MapGenRun, base, rng:GenerateSeed(), rng, policy, S)
			if ok then
				Merge(R, run)
			else
				errors = errors + 1
				first_error = first_error or tostring(run)
			end
		end
	end)
	local ok_restore, err_restore = pcall(Restore)
	if not ok_restore then
		-- the parts one by one (never left half done)
		rawset(_G, "print", real_print)
		rawset(_G, "TheNet", net)
		if ch ~= nil then
			rawset(ch, "MapGen", log_ch)
		end
		for k, v in pairs(kept) do
			Tracker[k] = v
		end
	end
	-- the network's room record: your run's own (what the game sets at every room)
	pcall(function()
		if net:IsHost() then
			net:HostSetRoomTravelHistory(real.data.travel_history)
		end
	end)
	C.busy = false

	local took = os.clock() - t0
	local head = string.format("hr_sim: %s, %s (map %s): %d run%s, %s; seed %s", C.KindText(kind, level), tostring(base.location_id),
		C.MapName(base.location_id, base.alt_mapgen_id), R.n, R.n == 1 and "" or "s",
		policy == "any" and "any door" or "weapon power doors first (then Fabled, then a normal power)", tostring(seed0))
	local tail = {}
	if kind == "blight" then
		tail[#tail + 1] = "  (this part of the Blight on its own, from nothing taken)"
	end
	if not HR.On("rooms") then
		tail[#tail + 1] = "  (Hunt Rooms' rooms part is off this session: the game's doors)"
	end
	if stopped then
		tail[#tail + 1] = string.format("  stopped after %d s (asked for %d runs)", C.MAX_SECONDS, n)
	end
	if errors > 0 then
		tail[#tail + 1] = string.format("  errors in %d sim run%s (left out), the first: %s", errors, errors == 1 and "" or "s", tostring(first_error))
	end
	if not ok_all then
		tail[#tail + 1] = "  the sim stopped on an error: " .. tostring(err_all)
	end
	if #sim_off > 0 then
		tail[#tail + 1] = "  errors in Hunt Rooms' parts in the sim (still on for your game): " .. table.concat(sim_off, "; ")
	end
	if not ok_restore then
		tail[#tail + 1] = "  putting things back: " .. tostring(err_restore) .. " (each one put back on its own)"
	end
	tail[#tail + 1] = string.format("  took %.1f s; your run is as it was", took)
	return Say(C.Report(R, head, tail)), R
end

----------------------------------------------------------------------------
-- the console names

C.COMMANDS = { "hr_help", "hr_doors", "hr_start", "hr_again", "hr_sim" }

function C.Register(G)
	local fns = {
		hr_help = function() C.Help() end,
		hr_doors = function() C.Doors() end,
		hr_start = function(location_id, level, seed) C.Start(location_id, level, seed) end,
		hr_again = function(seed) C.Again(seed) end,
		hr_sim = function(runs, policy, seed) C.Sim(runs, policy, seed) end,
	}
	local made, taken = {}, {}
	for _, name in ipairs(C.COMMANDS) do
		if rawget(G, name) == nil then
			local fn = fns[name]
			rawset(G, name, function(...)
				local ok, err = pcall(fn, ...)
				if not ok then
					C.busy = false
					print(HR.TAG .. " " .. name .. ": an error: " .. tostring(err))
				end
			end)
			made[#made + 1] = name .. "()"
		else
			taken[#taken + 1] = name
		end
	end
	local info = table.concat(made, " ")
	if #taken > 0 then
		info = info .. " (already taken, left as they are: " .. table.concat(taken, ", ") .. ")"
	end
	return #made > 0, info
end

return C
