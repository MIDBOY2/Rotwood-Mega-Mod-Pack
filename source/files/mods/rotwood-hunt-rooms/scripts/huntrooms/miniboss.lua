-- Hunt Rooms: the Blight's miniboss (0.2.1).
--
-- In the Blight's long middle parts (defs/mapgendata.lua exp_mapgen) the
-- miniboss is a room type the game rolls among the others for rooms 3-9
-- (weight 15, held back for the first 3 rooms, shown once at most:
-- max_seen miniboss = 1); its reward is always a Fabled pick (a miniboss with
-- Fabled in the room's odds is forced to it, util/mapgenhelp.lua). It's the
-- only Fabled the game has there, and it's optional: on the game's map code
-- about 1 part in 5 never shows one, and when it shows it can sit next to a
-- Fabled or weapon power door you'd have to give up for it.
--
-- Here (blight_miniboss = true), in each middle part:
--  * always offered: the game keeps its own roll; a part that hasn't shown
--    its miniboss by its last 5 door choices that can roll one (WINDOW: the
--    game's rooms 5-9, after the game's own first chance in room 4; the
--    extra rooms not counted) gets it at the first of them with a door to
--    give it (two doors or more; in the last 3, ONE_DOOR, a one-door choice
--    too: then it's the way on, as a main hunt's room 9). Made by the game's
--    own room code (MapGenHelp.CreateRoomGenState with the miniboss as the
--    room type, so its layout, its Fabled reward and FixupRoom's hard
--    difficulty are the game's), counted as seen by the game's own counter
--    (stats_seen) so the game rolls no second one. It takes the place of a
--    normal power door, else another fight door (a Fabled or weapon power
--    one after the others), never Teffra; only the part's last choice, when
--    it has no such door, gives a Teffra door, then a potion, upgrade or
--    mystery door. Never a market (a last choice of a market only would
--    leave the part without one: none in the tests' 24000 parts).
--  * never a choice against a Fabled or weapon power door: a door choice
--    with the miniboss has its Fabled and weapon power doors made normal
--    power doors (the game's roll kept for its counters, as the caps do).
-- Main hunts (their miniboss is the only door into room 9) and side hunts
-- (no miniboss room) are left as they are. Its Fabled isn't one of Hunt
-- Rooms' extra Fabled rooms (extra_fabled).
local HR = require "huntrooms.main"
local PowerRooms = require "huntrooms.powerrooms"
local Tracker = require "huntrooms.tracker"

local Miniboss = {}

Miniboss.MGH = nil -- util/mapgenhelp.lua (CreateRoomGenState, FixupRoom)
Miniboss.NEVER = { coin = true } -- rewards never turned into the miniboss (Teffra)
Miniboss.WINDOW = 5 -- the last door choices that can roll it where a part without it gets it
Miniboss.ONE_DOOR = 3 -- of those, the last ones where a one-door choice gets it too (the only way on, as a main hunt's room 9)
Miniboss.LAST = { potion = true, powerupgrade = true } -- the last choice only, with no other fight door: Teffra, then these or a mystery door (never a market)

-- The room numbers that can roll a miniboss on this map, in order (the
-- game's rooms; not an extra room, not a forced one like a main hunt's room 9).
function Miniboss.Choices(def)
	local rd = type(def) == "table" and def.roomdist or nil
	local list = {}
	if type(rd) ~= "table" then
		return list
	end
	for i = 1, #rd do
		local room = rd[i]
		local w = type(room) == "table" and type(room.roomtype) == "table" and tonumber(room.roomtype.miniboss) or nil
		if w ~= nil and w > 0 and not room[PowerRooms.FLAG] and not room.force_all_roomtypes then
			list[#list + 1] = i
		end
	end
	return list
end

-- first, last of them; nil when none
function Miniboss.Range(def)
	local list = Miniboss.Choices(def)
	return list[1], list[#list]
end

-- How many of them are left from this room on, this one included (0: not one of them).
function Miniboss.Left(list, index)
	for k, i in ipairs(list) do
		if i == index then
			return #list - k + 1
		end
	end
	return 0
end

-- Has this map shown its miniboss (the game's own counter)?
function Miniboss.Shown(mgrun)
	local gs = mgrun.data.gen_state
	return type(gs) == "table" and type(gs.stats_seen) == "table" and (tonumber(gs.stats_seen.miniboss) or 0) > 0
end

local function Doors(mgrun)
	local cur, list = mgrun.data.current, {}
	for _, c in ipairs(type(cur) == "table" and cur.exits or {}) do
		local room = mgrun.data.next[c]
		if type(room) == "table" then
			list[#list + 1] = { c = c, room = room }
		end
	end
	return list
end

-- The door to turn into the miniboss: a normal power door, else another fight
-- door (not Teffra), a Fabled or weapon power one after; the part's last
-- choice only, when it has none of those: a Teffra door, then a potion,
-- upgrade or mystery door. Never a market. nil when there's none.
function Miniboss.Rank(room, last)
	local r = room
	if r.roomtype == "monster" and not r.is_mystery then
		if not Miniboss.NEVER[r.reward] then
			return (r.reward == "plain" and 1) or ((r.reward == "fabled" or r.reward == "weaponpower") and 3) or 2
		end
		return last and 4 or nil
	end
	if last and r.roomtype ~= "market" and r.roomtype ~= "miniboss" and (r.is_mystery or Miniboss.LAST[r.roomtype]) then
		return 5
	end
	return nil
end

function Miniboss.Pick(doors, last)
	local best, rank = nil, 99
	for _, d in ipairs(doors) do
		local k = Miniboss.Rank(d.room, last)
		if k ~= nil and k < rank then
			best, rank = d, k
		end
	end
	return best
end

-- The game's own miniboss room for this door (its room code, the miniboss as
-- the room type, Fabled in the reward odds so it gets the Fabled reward).
function Miniboss.Make(mgrun, index, old)
	local MGH = Miniboss.MGH
	local def = mgrun.mapgendef
	local rd = def.roomdist[index]
	local room_def = {}
	for k, v in pairs(rd) do
		room_def[k] = v
	end
	room_def.roomtype = { miniboss = 1 }
	local reward = {}
	for k, v in pairs(type(rd.reward) == "table" and rd.reward or {}) do
		reward[k] = v
	end
	if reward.fabled == nil then
		reward.fabled = 0 -- (a miniboss with Fabled in its odds gets the Fabled reward)
	end
	room_def.reward = reward
	room_def.ignore_snooze_seen, room_def.ignore_snooze_depth = true, true
	room_def.force_all_roomtypes, room_def.force_all_rewards = nil, nil
	local proxy = setmetatable({ roomdist = setmetatable({ [index] = room_def }, { __index = def.roomdist }) }, { __index = def })
	local cur = mgrun.data.current
	local krandom = require "util.krandom"
	local seed = math.floor((tonumber(cur.roomseed) or 0) + index * 104729) % 2147483647
	local rng = krandom.CreateGenerator(seed)
	local history = type(mgrun.GetTravelHistory) == "function" and mgrun:GetTravelHistory(cur.index) or nil
	local room = MGH.CreateRoomGenState(mgrun.data.location_id, proxy, mgrun.data.gen_state, rng, index, history, old.weather_intensity_delta)
	if type(room) ~= "table" or room.roomtype ~= "miniboss" then
		error("the game made no miniboss room", 0)
	end
	MGH.FixupRoom(room, cur, mgrun)
	room.huntrooms_miniboss = true
	return room
end

-- After a door choice in the Blight: the guarantee, then no Fabled or weapon
-- power door beside the miniboss. Returns what it did (for the log), or nil.
function Miniboss.AfterDoors(mgrun, next_index, SetOrig, Give)
	if not HR.settings.blight_miniboss or Tracker.Leg() == nil then
		return nil
	end
	if PowerRooms.Is(mgrun.mapgendef, next_index) ~= nil then
		return nil -- (the doors into an extra room: never a miniboss there)
	end
	local list = Miniboss.Choices(mgrun.mapgendef)
	if #list == 0 then
		return nil -- (the Blight's first and last parts: no miniboss)
	end
	local left = Miniboss.Left(list, next_index)
	local doors = Doors(mgrun)
	local mb = nil
	for _, d in ipairs(doors) do
		if d.room.roomtype == "miniboss" then
			mb = d
		end
	end
	local did = nil
	if mb == nil and Miniboss.MGH ~= nil and not Miniboss.Shown(mgrun) and left >= 1 and left <= Miniboss.WINDOW
		and (left <= Miniboss.ONE_DOOR or #doors >= 2) then
		local d = Miniboss.Pick(doors, left == 1)
		if d == nil then
			HR.Log(string.format("the Blight's miniboss: room %d's doors have none to give it (%s)", next_index,
				left == 1 and "a market only: this part has none" or "Teffra, markets, rooms left as they are: the next choice"))
		else
			local room = Miniboss.Make(mgrun, next_index, d.room)
			mgrun:SetNextRoom(d.c, room)
			local gs = mgrun.data.gen_state
			gs.stats_seen.miniboss = (tonumber(gs.stats_seen.miniboss) or 0) + 1 -- the game's own count: no second one
			did = string.format("room %d: the miniboss in place of a %s door (none shown in this part yet)", next_index, tostring(d.room.reward))
			mb = { c = d.c, room = room }
		end
	end
	if mb ~= nil then
		local made = {}
		for _, d in ipairs(doors) do
			local r = mgrun.data.next[d.c]
			if r ~= mb.room and r.roomtype == "monster" and (r.reward == "fabled" or r.reward == "weaponpower") then
				made[#made + 1] = r.reward
				SetOrig(r)
				Give(r, "plain")
			end
		end
		if #made > 0 then
			did = (did and (did .. "; ") or "") .. string.format("room %d: beside the miniboss, %s made a normal power door", next_index, table.concat(made, " and "))
		end
	end
	return did
end

function Miniboss.Install(MGH)
	if type(MGH) ~= "table" or type(MGH.CreateRoomGenState) ~= "function" or type(MGH.FixupRoom) ~= "function" then
		Miniboss.MGH = nil
		return false, "a game update changed MapGenHelp (the Blight's miniboss as the game rolls it; still never beside a Fabled or weapon power door)"
	end
	Miniboss.MGH = MGH
	return true
end

return Miniboss
