-- Hunt Rooms: the doors. After the game rolls a room's doors (each map's
-- OnGenerateNextRooms, the game's own code and counters first):
--  * an extra room's doors (maps.lua): Fabled, weapon power or normal power
--    (side hunts), Fabled or weapon power (the Blight), by the settings'
--    weights, one of each at most, within the caps
--  * frenzied main hunts (Frenzy 1-5): a chance a door choice gets one of its
--    normal power, corestone, gift or material doors turned into a Fabled or
--    weapon power door
--  * Super Frenzy main hunts: corestone, gift and material doors halved (the
--    half become Fabled or weapon power doors), a few normal power ones too
--  * any hunt: the game's own weapon power door once the run has all its
--    weapon power rooms becomes a normal power door
--  * any hunt: weapon power doors show up weapon_power_doors times at most
--    (2; the Blight: weapon_power_doors_blight, 3, over all its parts), the
--    start's choice not counted. A door choice showing one counts when it's
--    made, whether you take it or not (0.2.0); past it, the game's own
--    weapon power doors are normal power doors and the mod adds none
--  * any hunt: never a weapon power room right after another (0.1.5,
--    weapon_power_gap rooms between at least; the start's choice counts as
--    the start room's): a weapon power door that would break it is a normal
--    power door, an extra room's door Fabled or a normal power
--  * the Blight: at most blight_weapon_rooms_per_leg weapon power rooms in
--    each of its parts (the game's own and the mod's; the start's choice
--    counts in the first): past that, every weapon power door of that part is
--    a normal power one
-- Never: Teffra, market, miniboss, meta-reward, potion, upgrade, mystery or
-- boss rooms, and never room 2 or the start.
--
-- The game's counters see exactly what it rolled: a door changed here keeps
-- the game's roll (room.huntrooms_orig), put back while the game counts the
-- room as it's entered (the map's OnSetCurrentRoom), and an extra room is kept
-- aside from them altogether (its doors' roll and its entering run on a copy
-- of the counters, powerrooms.lua). So every room the game makes comes at the
-- game's odds, Teffra included.
--
-- The game's own weapon power rule (util/mapgenstate.lua
-- CalculateWeaponPowerModifier: none once a player holds 2 weapon powers) is
-- read as the game would with its own rooms only: none once the run has had 2
-- of the game's own weapon power rooms (the start's choice and the mod's rooms
-- don't count; with Two Weapons each room gives 2 powers).
local HR = require "huntrooms.main"
local PowerRooms = require "huntrooms.powerrooms"
local Tracker = require "huntrooms.tracker"
local Miniboss = require "huntrooms.miniboss"
local Shard = require "huntrooms.shardroom"

local Doors = {}

Doors.SNOOZE = 2 -- after a changed door shows a kind, the next 2 door choices don't get one
Doors.B = { small_token = true, material = true, friendgift = true }
Doors.HARD, Doors.MEDIUM = 3, 2

local krandom = nil
local function Rng(doors, index)
	if krandom == nil then
		local ok, k = pcall(require, "util.krandom")
		krandom = ok and k or false
	end
	local seed = (tonumber(doors[1] and doors[1].roomseed) or 0) + index * 7919
	seed = math.floor(seed) % 2147483647
	if krandom and krandom.CreateGenerator then
		local ok, g = pcall(krandom.CreateGenerator, seed)
		if ok and g ~= nil and g.Float ~= nil then
			return function() return g:Float() end
		end
	end
	return math.random
end

-- The run: "main", "main_frenzy", "main_super", "side", "side_frenzy",
-- "side_super", "blight" or "other"; and its level (Frenzy 1-5, Super Frenzy 1-5).
function Doors.RunKind(mgrun)
	local dungeon = rawget(_G, "TheDungeon")
	local trek = dungeon ~= nil and dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek.IsActive ~= nil and trek:IsActive() then
		return "blight", 0
	end
	local def = type(mgrun) == "table" and mgrun.mapgendef or nil
	local name = type(def) == "table" and def.debug_name or nil
	local am = dungeon ~= nil and dungeon.progression ~= nil and dungeon.progression.components ~= nil and dungeon.progression.components.ascensionmanager or nil
	local level = am ~= nil and am.GetCurrentLevel ~= nil and tonumber(am:GetCurrentLevel()) or 0
	level = level or 0
	if name == "base_mapgen" then
		if level > 5 then
			return "main_super", level - 5
		elseif level >= 1 then
			return "main_frenzy", level
		end
		return "main", 0
	elseif name == "short_mapgen" then
		local SS = package.loaded["frenzylevels.superside"]
		if type(SS) == "table" and SS.run and type(SS.level) == "number" then
			return "side_super", SS.level
		elseif level >= 1 then
			return "side_frenzy", level
		end
		return "side", 0
	end
	return "other", level
end
Shard.RunKind = Doors.RunKind

-- Every fight room hard (Frenzy Levels' Super Frenzy side hunts): a weapon
-- power door stays hard there too.
local function AllHard()
	local SS = package.loaded["frenzylevels.superside"]
	return type(SS) == "table" and SS.run == true and SS.all_hard == true
end

-- (0.3.3) a door Frenzy Levels made hard (its Super Frenzy rooms: every one in
-- a Super Frenzy side hunt, some or all in a Super Frenzy main hunt by your
-- gear level): kept hard when its door changes here
local function KeptHard(room)
	return AllHard() or (type(room) == "table" and room.frenzylevels_hard == true)
end

-- (0.3.3) weapon power doors may be hard (Frenzy Levels' hard_power_rooms;
-- without Frenzy Levels: never, the game's)
local function HardPower()
	local SS = package.loaded["frenzylevels.superside"]
	return type(SS) == "table" and SS.hard_power ~= false
end

local function SetOrig(room)
	if room.huntrooms_orig == nil then
		room.huntrooms_orig = { roomtype = room.roomtype, reward = room.reward, is_mystery = room.is_mystery, difficulty = room.difficulty }
	end
end

local function Give(room, reward)
	room.reward = reward
	if reward == "fabled" then
		room.difficulty = Doors.HARD -- the game's: a Fabled room is hard (MapGenHelp.FixupRoom)
	elseif reward == "weaponpower" and type(room.difficulty) == "number" and room.difficulty > Doors.MEDIUM
		and not (KeptHard(room) and HardPower()) then
		room.difficulty = Doors.MEDIUM -- the game's: never a hard weapon power room
	end
end

-- Does the run's start give its weapon power choice (this map's start room)?
local function StartChoice(cur)
	return type(cur) == "table" and cur.index == 1 and cur.reward ~= "weaponpower" and HR.start_on
		and HR.On("the start's weapon power") and Tracker.FirstMap()
end

-- The last weapon power room on this map up to the room you're in (its
-- number), or nil: the room you're in, the start's choice, or the one recorded.
function Doors.LastWeaponPowerRoom(mgrun)
	local data = type(mgrun) == "table" and mgrun.data or nil
	local cur = type(data) == "table" and data.current or nil
	if type(cur) ~= "table" or type(cur.index) ~= "number" then
		return nil
	end
	if cur.reward == "weaponpower" or StartChoice(cur) then
		return cur.index
	end
	local st = type(data.huntrooms) == "table" and data.huntrooms or nil
	local last = st ~= nil and tonumber(st.last_wp) or nil
	if last ~= nil and last <= cur.index then
		return last
	end
	return nil
end

-- The gap: can the room after the one you're in be a weapon power room?
function Doors.GapAllows(mgrun)
	local gap = tonumber(HR.settings.weapon_power_gap) or 0
	if gap <= 0 then
		return true
	end
	local last = Doors.LastWeaponPowerRoom(mgrun)
	if last == nil then
		return true
	end
	local next_index = mgrun.data.current.index + 1
	return next_index - last > gap
end

-- The door choice out of the room you're in (its key), for the allowance.
function Doors.ChoiceKey(mgrun)
	local cur = type(mgrun) == "table" and type(mgrun.data) == "table" and mgrun.data.current or nil
	if type(cur) ~= "table" then
		return nil
	end
	return Tracker.Key(cur) .. "#door"
end

-- Weapon power doors this hunt can still show: the allowance (the Blight's
-- over all its parts) less the door choices that showed one (this one left
-- out, so making it again, e.g. after a load, isn't refused by itself).
function Doors.DoorsLeft(mgrun)
	local s = HR.settings
	local allowance = Tracker.Leg() ~= nil and s.weapon_power_doors_blight or s.weapon_power_doors
	return (tonumber(allowance) or 0) - Tracker.Count(Tracker.DOOR, Doors.ChoiceKey(mgrun))
end

-- After a door choice is made: a weapon power door in it uses one of the allowance.
function Doors.CountShown(mgrun, doors)
	for _, room in ipairs(doors) do
		if room.roomtype == "monster" and room.reward == "weaponpower" then
			local key = Doors.ChoiceKey(mgrun)
			if key ~= nil then
				Tracker.Record(key, Tracker.DOOR)
			end
			return true
		end
	end
	return false
end

-- The caps: can this kind still come?
function Doors.Allowed(kind, mgrun)
	local s = HR.settings
	if kind == "weaponpower" then
		local rooms, by_rooms = Tracker.WeaponPowerRooms()
		local cur = type(mgrun) == "table" and mgrun.data ~= nil and mgrun.data.current or nil
		if type(cur) == "table" and cur.reward == "weaponpower" then
			-- the room being entered: counted when entered (0.1.5); before, its powers came after the doors
			if not by_rooms or not Tracker.Recorded(Tracker.Key(cur) .. "#wp") then
				rooms = rooms + 1
			end
		elseif StartChoice(cur) and not (by_rooms and Tracker.Count(Tracker.START) > 0) then
			rooms = rooms + 1 -- the run's start: its weapon power choice comes after room 2's doors
		end
		if rooms >= s.weapon_power_rooms then
			return false
		end
		if Doors.DoorsLeft(mgrun) <= 0 then
			return false
		end
		if not Doors.GapAllows(mgrun) then
			return false
		end
		return Doors.LegAllows(cur)
	elseif kind == "fabled" then
		return Tracker.Count("mod_fabled") < s.extra_fabled
	end
	return true
end

-- The Blight: has this part (leg) still room for a weapon power room? (the
-- rooms entered in it, the one being entered too; the start's choice in the
-- first part)
function Doors.LegAllows(cur)
	local leg = Tracker.Leg()
	if leg == nil then
		return true
	end
	local n = Tracker.Count(Tracker.LegKind(leg))
	if type(cur) == "table" and cur.index == 1 and HR.start_on and HR.On("the start's weapon power") and Tracker.FirstMap() then
		n = n + 1
	end
	return n < HR.settings.blight_weapon_rooms_per_leg
end

-- Fabled or weapon power, of the ones allowed (fabled_share when both), or nil.
local function Target(rand, ok_fabled, ok_wp)
	if ok_fabled and ok_wp then
		return rand() * 100 < HR.settings.fabled_share and "fabled" or "weaponpower"
	end
	return (ok_fabled and "fabled") or (ok_wp and "weaponpower") or nil
end

local function State(mgrun)
	local data = mgrun.data
	if type(data.huntrooms) ~= "table" then
		data.huntrooms = {}
	end
	local st = data.huntrooms
	if type(st.snooze) ~= "table" then
		st.snooze = { fabled = 0, weaponpower = 0 }
	end
	return st
end

-- An extra room's doors: the weights, one of each kind at most.
function Doors.PowerDoors(doors, kind, rand, mgrun)
	local s = HR.settings
	local weights = kind == "blight" and s.blight_room_doors or s.side_room_doors
	local w = {}
	for k, v in pairs(weights) do
		if v > 0 and Doors.Allowed(k, mgrun) then
			w[k] = v
		end
	end
	local used = {}
	for _, room in ipairs(doors) do
		local total, keys = 0, {}
		for k, v in pairs(w) do
			if not used[k] then
				total = total + v
				keys[#keys + 1] = k
			end
		end
		table.sort(keys)
		local pick = nil
		if total > 0 then
			local x = rand() * total
			for _, k in ipairs(keys) do
				x = x - w[k]
				if x <= 0 then
					pick = k
					break
				end
			end
			pick = pick or keys[#keys]
		end
		if pick == nil then
			-- nothing left to offer: a normal power (another difficulty if one already is)
			pick = "plain"
			if used.plain and not KeptHard(room) then
				-- two normal power doors: the game's way to tell alike doors apart, the other difficulty
				-- (every fight room hard in Frenzy Levels' Super Frenzy side hunts: both stay hard, its own rule)
				room.difficulty = (type(room.difficulty) == "number" and room.difficulty >= Doors.HARD) and Doors.MEDIUM or Doors.HARD
			end
		end
		used[pick] = true
		room.roomtype = "monster"
		room.is_mystery = nil
		room.huntrooms_power = kind
		Give(room, pick)
	end
	-- the Heart Shard room (0.3.0): Super Frenzy side hunts, until walked into
	if kind == "side" then
		local ok, shard = HR.Call("the Heart Shard room", Shard.MaybeOffer, doors, rand, mgrun)
		if ok and shard ~= nil then
			HR.Debug("extra room doors: a Heart Shard room (in place of a " .. tostring(shard.huntrooms_was) .. " door)")
		end
	end
	HR.Debug("extra room doors: " .. Doors.Describe(doors))
end

function Doors.Describe(doors)
	local t = {}
	for _, r in ipairs(doors) do
		t[#t + 1] = tostring(r.reward) .. (r.huntrooms_orig and ("(was " .. tostring(r.huntrooms_orig.reward) .. ")") or "")
	end
	return table.concat(t, ", ")
end

local function Kind(room)
	if room.is_mystery then
		return "mystery"
	end
	if room.roomtype == "monster" then
		return room.reward
	end
	return room.roomtype
end

-- The game's doors, after its roll.
function Doors.GameDoors(doors, index, rand, mgrun)
	local s = HR.settings
	local wp_ok = Doors.Allowed("weaponpower", mgrun)
	-- the game's own weapon power door past the cap: a normal power one
	if not wp_ok then
		for _, room in ipairs(doors) do
			if room.roomtype == "monster" and room.reward == "weaponpower" and room.huntrooms_orig == nil then
				SetOrig(room)
				Give(room, "plain")
				HR.Debug("room " .. index .. ": the game's weapon power door -> a normal power one (the run, or this part of the Blight, has its weapon power rooms, or the last one was too near)")
			end
		end
	end
	if index < 3 then
		return
	end
	local run = Doors.RunKind(mgrun)
	if run ~= "main_frenzy" and run ~= "main_super" then
		return
	end
	local st = State(mgrun)
	local shown = {}
	for _, room in ipairs(doors) do
		shown[Kind(room)] = true
	end
	local ok_f = not shown.fabled and st.snooze.fabled <= 0 and Doors.Allowed("fabled", mgrun)
	local ok_w = not shown.weaponpower and st.snooze.weaponpower <= 0 and wp_ok
	local function Group(test)
		local g = {}
		for _, room in ipairs(doors) do
			if room.roomtype == "monster" and not room.is_mystery and room.huntrooms_orig == nil and test(room.reward) then
				g[#g + 1] = room
			end
		end
		return g
	end
	local picked, from = nil, nil
	if run == "main_frenzy" then
		if (ok_f or ok_w) and rand() * 100 < s.frenzy_main_chance then
			local a = Group(function(r) return r == "plain" end)
			local b = Group(function(r) return Doors.B[r] end)
			local g
			if #a > 0 and #b > 0 then
				-- both there: the one that keeps the map's hit nearest the share on normal powers
				st.hit = type(st.hit) == "table" and st.hit or { a = 0, b = 0 }
				local share = s.frenzy_main_from_powers / 100
				local t = st.hit.a + st.hit.b + 1
				local da = math.abs((st.hit.a + 1) / t - share)
				local db = math.abs(st.hit.a / t - share)
				if math.abs(da - db) < 1e-9 then
					g = rand() < share and a or b
				else
					g = da < db and a or b
				end
			else
				g = #a > 0 and a or b
			end
			if #g > 0 then
				picked = g[math.floor(rand() * #g) + 1] or g[1]
				from = g == a and "a" or "b"
			end
		end
	else
		local cands = {}
		for _, room in ipairs(Group(function(r) return Doors.B[r] end)) do
			if rand() * 100 < s.super_main_halve then
				cands[#cands + 1] = room
			end
		end
		for _, room in ipairs(Group(function(r) return r == "plain" end)) do
			if rand() * 100 < s.super_main_from_powers then
				cands[#cands + 1] = room
			end
		end
		if #cands > 0 and (ok_f or ok_w) then
			picked = cands[math.floor(rand() * #cands) + 1] or cands[1]
		end
	end
	if picked ~= nil then
		local to = Target(rand, ok_f, ok_w)
		if to ~= nil then
			local was = picked.reward
			SetOrig(picked)
			Give(picked, to)
			st.snooze[to] = Doors.SNOOZE + 1 -- ticks down at this choice's end
			if from ~= nil then
				st.hit = type(st.hit) == "table" and st.hit or { a = 0, b = 0 }
				st.hit[from] = st.hit[from] + 1
			end
			HR.Debug(string.format("room %d (%s): a %s door -> %s", index, run, tostring(was), to))
		end
	end
end

-- After the game made the doors out of the current room.
function Doors.AfterDoors(mgrun, next_index)
	local data = mgrun.data
	local cur = data.current
	if type(cur) ~= "table" or type(cur.exits) ~= "table" or type(data.next) ~= "table" then
		return
	end
	local doors = {}
	for _, cardinal in ipairs(cur.exits) do
		local room = data.next[cardinal]
		if type(room) == "table" then
			doors[#doors + 1] = room
		end
	end
	if #doors == 0 then
		return
	end
	local rand = Rng(doors, next_index)
	local kind = PowerRooms.Is(mgrun.mapgendef, next_index)
	if kind ~= nil then
		local fights = {}
		for _, room in ipairs(doors) do
			if room.roomtype == "monster" or room.roomtype == "mystery" or room.is_mystery then
				fights[#fights + 1] = room
			end
		end
		Doors.PowerDoors(fights, kind, rand, mgrun)
	else
		Doors.GameDoors(doors, next_index, rand, mgrun)
		local st = State(mgrun)
		for k, v in pairs(st.snooze) do
			st.snooze[k] = math.max(0, v - 1)
		end
		-- the Blight's miniboss (0.2.1): always offered, never beside a Fabled or weapon power door
		local okm, did = HR.Call("the Blight's miniboss", Miniboss.AfterDoors, mgrun, next_index, SetOrig, Give)
		if okm and did ~= nil then
			HR.Debug("the Blight's miniboss: " .. did)
			doors = {}
			for _, cardinal in ipairs(cur.exits) do
				local room = data.next[cardinal]
				if type(room) == "table" then
					doors[#doors + 1] = room
				end
			end
		end
	end
	-- the allowance: this choice showed a weapon power door
	if Doors.CountShown(mgrun, doors) then
		HR.Debug(string.format("room %d's doors: a weapon power door (%d left this hunt)", next_index, math.max(0, Doors.DoorsLeft(mgrun) - 1)))
	end
end

-- An extra room's doors as normal power rooms (the fallback when the doors part is off).
function Doors.PlainDoors(mgrun)
	local data = mgrun.data
	local cur = data.current
	local kind = PowerRooms.Is(mgrun.mapgendef, (tonumber(cur.index) or 0) + 1) or "side"
	local used = false
	for _, cardinal in ipairs(cur.exits or {}) do
		local room = data.next[cardinal]
		if type(room) == "table" then
			room.roomtype, room.is_mystery, room.huntrooms_power = "monster", nil, kind
			room.reward = "plain"
			if used and not KeptHard(room) then
				room.difficulty = (type(room.difficulty) == "number" and room.difficulty >= Doors.HARD) and Doors.MEDIUM or Doors.HARD
			end
			used = true
		end
	end
	HR.Log("an extra room: normal power doors (the doors part is off)")
end

-- The game's counters for a room being entered, with the game's roll.
local function SetWithOrig(set, mgrun, room, ...)
	local o = room.huntrooms_orig
	local cur = { roomtype = room.roomtype, reward = room.reward, is_mystery = room.is_mystery, difficulty = room.difficulty }
	room.roomtype, room.reward, room.is_mystery, room.difficulty = o.roomtype, o.reward, o.is_mystery, o.difficulty
	local r = table.pack(pcall(set, mgrun, room, ...))
	room.roomtype, room.reward, room.is_mystery, room.difficulty = cur.roomtype, cur.reward, cur.is_mystery, cur.difficulty
	if not r[1] then
		error(r[2], 0)
	end
	return table.unpack(r, 2, r.n)
end

-- What the tracker counts for a room entered.
function Doors.OnEnter(mgrun, room)
	if room.index == 1 and Tracker.FirstMap() then
		Tracker.Reset()
		Tracker.Record("rooms", Tracker.MARK) -- this run counts weapon power rooms by rooms (0.1.5)
		if room.reward == "weaponpower" and not (HR.start_on and HR.On("the start's weapon power")) then
			-- the start's choice off: a start the game made a weapon power room is one of the allowance
			Tracker.Record(Tracker.Key(room) .. "#start", Tracker.DOOR)
		end
	end
	local key = Tracker.Key(room)
	Tracker.current = key
	if room.reward == "weaponpower" then
		Tracker.Record(key .. "#wp", Tracker.ROOM)
		State(mgrun).last_wp = room.index -- (the gap, this map)
	elseif StartChoice(room) then
		State(mgrun).last_wp = room.index -- the start's choice (the gap)
	end
	local power = PowerRooms.Is(mgrun.mapgendef, room.index)
	if room.reward == Shard.REWARD and (room.huntrooms_shard or power ~= nil or room.huntrooms_power ~= nil) then
		Tracker.Record(key .. "#shard", Shard.KIND) -- (0.3.0: walked into: no more this hunt)
	end
	local game_reward = room.huntrooms_orig ~= nil and room.huntrooms_orig.reward or room.reward
	if power ~= nil or room.huntrooms_power ~= nil then
		if room.reward == "fabled" then
			Tracker.Record(key, "mod_fabled")
		end
	elseif room.reward == "fabled" and game_reward ~= "fabled" then
		Tracker.Record(key, "mod_fabled")
	elseif game_reward == "weaponpower" then
		Tracker.Record(key, "game_wp")
	end
	-- the Blight: a weapon power room in this part (the game's or the mod's)
	local leg = Tracker.Leg()
	if leg ~= nil and room.reward == "weaponpower" then
		Tracker.Record(key .. "#leg", Tracker.LegKind(leg))
	end
end

-- Wraps a map's OnSetCurrentRoom and OnGenerateNextRooms (once per map table).
function Doors.Wrap(def)
	if type(def) ~= "table" or rawget(def, "huntrooms_wrapped") then
		return false
	end
	local gen, set = def.OnGenerateNextRooms, def.OnSetCurrentRoom
	if type(gen) ~= "function" or type(set) ~= "function" then
		return false
	end
	def.huntrooms_wrapped = true
	def.OnSetCurrentRoom = function(mgrun, room, ...)
		if not HR.On("rooms") or type(mgrun) ~= "table" or type(mgrun.data) ~= "table" or type(room) ~= "table" then
			return set(mgrun, room, ...)
		end
		HR.Call("the run's record", Doors.OnEnter, mgrun, room)
		-- the game's counters: kept apart from the parts above (they stay even if those go off)
		if PowerRooms.Is(mgrun.mapgendef or def, room.index) ~= nil then
			return PowerRooms.Aside(mgrun, set, mgrun, room, ...)
		elseif type(room.huntrooms_orig) == "table" then
			return SetWithOrig(set, mgrun, room, ...)
		end
		return set(mgrun, room, ...)
	end
	local entrance = def.OnGenerateEntranceRoom
	if type(entrance) == "function" then
		-- room 2's doors (the map's start makes them): only the cap on the game's own weapon power door
		def.OnGenerateEntranceRoom = function(mgrun, ...)
			local r = table.pack(entrance(mgrun, ...))
			if HR.On("rooms") and type(mgrun) == "table" and type(mgrun.data) == "table" and type(mgrun.data.current) == "table" then
				HR.Call("doors", Doors.AfterDoors, mgrun, 2)
			end
			return table.unpack(r, 1, r.n)
		end
	end
	def.OnGenerateNextRooms = function(mgrun, ...)
		if not HR.On("rooms") or type(mgrun) ~= "table" or type(mgrun.data) ~= "table" or type(mgrun.data.current) ~= "table" then
			return gen(mgrun, ...)
		end
		local next_index = (tonumber(mgrun.data.current.index) or 0) + 1
		local r
		if PowerRooms.Is(mgrun.mapgendef or def, next_index) ~= nil then
			r = table.pack(PowerRooms.Aside(mgrun, gen, mgrun, ...))
		else
			r = table.pack(gen(mgrun, ...))
		end
		local ok = HR.Call("doors", Doors.AfterDoors, mgrun, next_index)
		if not ok and PowerRooms.Is(mgrun.mapgendef or def, next_index) ~= nil then
			-- the doors part off (an error): an extra room still never offers
			-- Teffra or the game's other rooms, a normal power instead
			HR.Call("extra room fallback", Doors.PlainDoors, mgrun)
		end
		return table.unpack(r, 1, r.n)
	end
	return true
end

-- The game's own weapon power rule, with the game's own rooms only.
function Doors.WeaponPowerModifier()
	return Tracker.Count("game_wp", Tracker.current) >= 2 and 0 or 1
end

-- deps: { MapGenData, MapGenState }
function Doors.Install(deps)
	local MapGenData, MapGenState = deps.MapGenData, deps.MapGenState
	local mb_ok, mb_why = Miniboss.Install(deps.MapGenHelp)
	Doors.miniboss_info = mb_ok and "" or (" (" .. tostring(mb_why) .. ")")
	if type(MapGenData) ~= "table" or type(MapGenData.defs) ~= "table" then
		return false, "a game update changed MapGenData"
	end
	local n = 0
	for _, def in pairs(MapGenData.defs) do
		if Doors.Wrap(def) then
			n = n + 1
		end
	end
	if n == 0 then
		return false, "no map to change (a game update changed the maps)"
	end
	local modifier = false
	if type(MapGenState) == "table" and type(MapGenState.CalculateWeaponPowerModifier) == "function" then
		local orig = MapGenState.CalculateWeaponPowerModifier
		MapGenState.CalculateWeaponPowerModifier = function(...)
			if HR.On("rooms") then
				local ok, v = HR.Call("the game's weapon power rule", Doors.WeaponPowerModifier)
				if ok and type(v) == "number" then
					return v
				end
			end
			return orig(...)
		end
		modifier = true
	end
	return true, string.format("%d maps%s%s", n, modifier and "" or " (the game's weapon power rule as it is: MapGenState.CalculateWeaponPowerModifier not found)", Doors.miniboss_info or "")
end

return Doors
