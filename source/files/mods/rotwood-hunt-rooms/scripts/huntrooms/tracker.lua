-- Hunt Rooms: what a run has had, for the caps and the game's own weapon power
-- rule. Kept on each player (components/huntrooms.lua, saved with the player,
-- so it lasts through the Blight's parts and a quit and continue), and in
-- memory as a fallback.
--  * weapon power rooms: the weapon power rooms entered and the start's
--    choice (0.1.5). Runs started before 0.1.5 (no "count_rooms" mark): the
--    most weapon powers a player has for one weapon type, as before (a room
--    gave each weapon one; with Two Weapons 1.0.7 a short choice can give one
--    weapon two, so powers no longer tell rooms)
--  * the mod's Fabled rooms and the game's own weapon power rooms: the rooms
--    entered, by the room's seed and number (a room counts once)
--  * the Blight: every weapon power room entered, by the part (leg) it's in
-- A run starts over at the entrance of its first map (the Blight: its first part).
local HR = require "huntrooms.main"

local Tracker = {}

Tracker.mem = {}        -- key -> kind (no player component)
Tracker.current = nil   -- the key of the room just entered
Tracker.MARK = "count_rooms" -- a run counting weapon power rooms by rooms (0.1.5)
Tracker.ROOM = "wp_room"     -- a weapon power room entered (the game's or the mod's)
Tracker.START = "wp_start"   -- the start's weapon power choice given
Tracker.DOOR = "wp_door"     -- a door choice that showed a weapon power door (0.2.0)

local function Players()
	local net = rawget(_G, "TheNet")
	local ok, list = pcall(function() return net:GetPlayersOnRoomChange() end)
	return ok and type(list) == "table" and list or {}
end

local function Comp(player)
	local c = type(player) == "table" and player.components or nil
	return c ~= nil and c.huntrooms or nil
end

function Tracker.Key(room)
	return tostring(room.roomseed) .. "/" .. tostring(room.index)
end

-- The Blight's part (leg) the run is in, or nil outside the Blight.
function Tracker.Leg()
	local dungeon = rawget(_G, "TheDungeon")
	local trek = dungeon ~= nil and dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek.IsActive ~= nil and trek:IsActive() and trek.GetCurrentLegIndex ~= nil then
		return tonumber(trek:GetCurrentLegIndex()) or 1
	end
	return nil
end

function Tracker.LegKind(leg)
	return "wp_leg" .. tostring(leg)
end

function Tracker.FirstMap()
	local dungeon = rawget(_G, "TheDungeon")
	local trek = dungeon ~= nil and dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek.IsActive ~= nil and trek:IsActive() then
		return (tonumber(trek:GetCurrentLegIndex()) or 1) <= 1
	end
	return true
end

function Tracker.Reset()
	Tracker.mem = {}
	for _, p in ipairs(Players()) do
		local c = Comp(p)
		if c ~= nil then
			c:Reset()
		end
	end
end

function Tracker.Record(key, kind)
	Tracker.mem[key] = kind
	for _, p in ipairs(Players()) do
		local c = Comp(p)
		if c ~= nil then
			c:Record(key, kind)
		end
	end
end

-- Rooms of a kind entered this run (but the one left out), the most any
-- player has (the memory when no player has the component).
function Tracker.Count(kind, leave_out)
	local best, any = 0, false
	for _, p in ipairs(Players()) do
		local c = Comp(p)
		if c ~= nil then
			any = true
			best = math.max(best, c:Count(kind, leave_out))
		end
	end
	if not any then
		for k, v in pairs(Tracker.mem) do
			if v == kind and k ~= leave_out then
				best = best + 1
			end
		end
	end
	return best
end

-- Was this key recorded (any player, or the memory)?
function Tracker.Recorded(key)
	if Tracker.mem[key] ~= nil then
		return true
	end
	for _, p in ipairs(Players()) do
		local c = Comp(p)
		if c ~= nil and type(c.entered) == "table" and c.entered[key] ~= nil then
			return true
		end
	end
	return false
end

-- Weapon power rooms the run has had, and whether they're counted by rooms
-- (true) or, for a run from before 0.1.5, by powers (false).
function Tracker.WeaponPowerRooms()
	if Tracker.Count(Tracker.MARK) > 0 then
		return Tracker.Count(Tracker.ROOM) + math.min(1, Tracker.Count(Tracker.START)), true
	end
	return Tracker.PowerCount(), false
end

-- The most weapon powers one weapon type has, for any player (before 0.1.5).
function Tracker.PowerCount()
	local Power = package.loaded["defs.powers"] or package.loaded["defs.powers.power"]
	if Power == nil then
		local ok, p = pcall(require, "defs.powers")
		Power = ok and p or nil
	end
	local wp_type = type(Power) == "table" and type(Power.Types) == "table" and Power.Types.WEAPON_POWER or "WEAPON_POWER"
	local best = 0
	for _, p in ipairs(Players()) do
		local pm = type(p) == "table" and p.components ~= nil and p.components.powermanager or nil
		if pm ~= nil and pm.GetPowersOfType ~= nil then
			local counts = {}
			for _, pow in ipairs(pm:GetPowersOfType(wp_type) or {}) do
				local t = type(pow) == "table" and pow.def ~= nil and pow.def.weapon_power_weapon_type or "?"
				counts[t] = (counts[t] or 0) + 1
				best = math.max(best, counts[t])
			end
		end
	end
	return best
end

return Tracker
