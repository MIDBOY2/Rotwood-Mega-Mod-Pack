-- Hunt Rooms: the Heart Shard room in Super Frenzy side hunts (0.3.0).
--
-- In a Super Frenzy side hunt (Frenzy Levels), each of Hunt Rooms' extra
-- rooms' door choices has a chance (shard_room: 40 / 45 / 50 / 55 / 60% by
-- Super Frenzy level) that one of its doors is a Heart Shard room (the
-- game's own shard room, the Blight's: a fight, then the shard drop). It's
-- offered until you walk into one, then never again that hunt (the run's
-- record, saved with the players). Only in a door choice of 2 doors or more,
-- and it takes a normal power door's place first (else a weapon power, then
-- a Fabled one: a weapon power door it replaces isn't counted as shown).
-- Its reward, for each player: shard_room_shards Heart Shards (1 / 2 / 3 / 4
-- / 5 by level), a fixed number: Frenzy Levels' loot multiplier leaves the
-- shard room's Heart Shards alone (it asks HuntRoomsAPI.ShardRoom()).
local HR = require "huntrooms.main"
local PowerRooms = require "huntrooms.powerrooms"
local Tracker = require "huntrooms.tracker"

local Shard = {}

Shard.KIND = "shard_room" -- the run's record: a shard room walked into
Shard.REWARD = "shard"    -- the game's reward name (defs/mapgen.lua)
Shard.LootEvents = nil
Shard.RunKind = nil       -- Doors.RunKind (set by doors.lua)
Shard.installed = false   -- the reward's hook is in (no shard door without it)

local function MapRun()
	local dungeon = rawget(_G, "TheDungeon")
	local ok, wm = pcall(function() return dungeon:GetDungeonMap() end)
	return ok and wm ~= nil and wm.mgrun or nil
end

-- The run's Super Frenzy side hunt level, or nil.
function Shard.Level(mgrun)
	if Shard.RunKind == nil then
		return nil
	end
	local kind, level = Shard.RunKind(mgrun)
	if kind == "side_super" and type(level) == "number" and level >= 1 then
		return math.min(5, math.floor(level))
	end
	return nil
end

function Shard.Taken()
	return Tracker.Count(Shard.KIND) > 0
end

local ORDER = { plain = 1, weaponpower = 2, fabled = 3 }

-- An extra room's doors (after Hunt Rooms gave them): maybe one is a shard
-- room. Returns the door made one, or nil.
function Shard.MaybeOffer(doors, rand, mgrun)
	local s = HR.settings
	if not Shard.installed then
		return nil
	end
	local level = Shard.Level(mgrun)
	if level == nil or #doors < 2 or Shard.Taken() then
		return nil
	end
	local chance = tonumber(s.shard_room[level]) or 0
	if chance <= 0 or rand() * 100 >= chance then
		return nil
	end
	local best, rank = nil, 99
	for _, room in ipairs(doors) do
		local k = ORDER[room.reward]
		if room.roomtype == "monster" and k ~= nil and k < rank then
			best, rank = room, k
		end
	end
	if best == nil then
		return nil
	end
	best.huntrooms_was = best.reward
	best.reward = Shard.REWARD
	best.huntrooms_shard = true
	return best
end

-- Is the room the game is in Hunt Rooms' shard room (a Super Frenzy side hunt)?
function Shard.InShardRoom()
	local mgrun = MapRun()
	if mgrun == nil or type(mgrun.data) ~= "table" or Shard.Level(mgrun) == nil then
		return false
	end
	local cur = mgrun.data.current
	if type(cur) ~= "table" or cur.reward ~= Shard.REWARD then
		return false
	end
	return cur.huntrooms_shard == true or cur.huntrooms_power ~= nil or PowerRooms.Is(mgrun.mapgendef, cur.index) ~= nil
end

-- The shard room's Heart Shards for each player, or nil (not ours: the game's).
function Shard.RewardCount()
	if not Shard.InShardRoom() then
		return nil
	end
	local level = Shard.Level(MapRun())
	return level ~= nil and (tonumber(HR.settings.shard_room_shards[level]) or 0) or nil
end

local function LocalPlayers()
	local net = rawget(_G, "TheNet")
	local ok, list = pcall(function() return net:GetPlayersOnRoomChange() end)
	local out = {}
	for _, p in ipairs(ok and type(list) == "table" and list or {}) do
		local okl, is = pcall(function() return p:IsLocal() end)
		if okl and is then
			out[#out + 1] = p
		end
	end
	return out
end

function Shard.Install(deps)
	local s = HR.settings
	local any = false
	for i = 1, 5 do
		any = any or (s.shard_room[i] > 0 and s.shard_room_shards[i] > 0)
	end
	if not any then
		return false, "off"
	end
	local KRM, LE = deps.KonjurRewardManager, deps.LootEvents
	if type(KRM) ~= "table" or type(KRM.SpawnRoomRewardHeartShard) ~= "function" then
		return false, "a game update changed KonjurRewardManager (the game's shard room drop)"
	end
	if type(LE) ~= "table" or type(LE.SpawnHeartShardForAll) ~= "function" then
		return false, "a game update changed LootEvents (the Heart Shard drop)"
	end
	Shard.LootEvents = LE
	if not rawget(KRM, "huntrooms_shard_room") then
		local orig = KRM.SpawnRoomRewardHeartShard
		KRM.SpawnRoomRewardHeartShard = function(self, inst, ...)
			if HR.On("the Heart Shard room") then
				local ok, n = HR.Call("the Heart Shard room", Shard.RewardCount)
				if ok and type(n) == "number" then
					if n > 0 then
						local players = LocalPlayers()
						local okd, err = pcall(LE.SpawnHeartShardForAll, inst, players, n)
						if okd then
							HR.Debug(string.format("the Heart Shard room: %d Heart Shards each", n))
							return
						end
						HR.Log("the Heart Shard room: the game's drop instead (" .. tostring(err) .. ")")
					else
						return
					end
				end
			end
			return orig(self, inst, ...)
		end
		rawset(KRM, "huntrooms_shard_room", true)
	end
	Shard.installed = true
	local function List(t)
		local out = {}
		for i = 1, 5 do
			out[i] = tostring(t[i])
		end
		return table.concat(out, "/")
	end
	return true, string.format("Super Frenzy side hunts: %s%% each extra room, %s Heart Shards each", List(s.shard_room), List(s.shard_room_shards))
end

return Shard
