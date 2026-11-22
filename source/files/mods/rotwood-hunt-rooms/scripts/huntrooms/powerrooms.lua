-- Power rooms: rooms put into a map (defs/mapgendata.lua MapGenData.defs) that
-- offer only powers, and that the game's own counters never see, so every
-- room the game makes stays exactly the game's.
--
-- A power room is one more 'k-k' stretch in the map's room_distribution
-- (roomtype monster, reward plain only, power_room = true); the game's
-- stretches after it move on by one, keeping their size, so each of the
-- game's rooms keeps its own odds and order (the meta room, the miniboss, the
-- market...). The game's MapGenData.Validate builds the map again (length,
-- boss position).
--
-- The game's counters (util/mapgenstate.lua: snoozes by doors seen and rooms
-- entered, per-map limits by doors seen and rooms entered) live in the run's
-- gen_state. Around the doors into a power room (the map's
-- OnGenerateNextRooms, when the next room is one) and entering one (its
-- OnSetCurrentRoom) the game's gen_state is kept aside and put back after,
-- so to the game's rules the power room never happened: a potion snoozed for
-- 4 rooms is still snoozed for 4 of the game's rooms, a map's 2 potions are
-- still 2, and so on. Nothing runs anywhere else.
--
-- Hunt Rooms (doors.lua) gives their doors their rewards: Fabled, weapon power
-- or normal power (the stretch's kind: "side" or "blight", in FLAG).
local PowerRooms = {}

PowerRooms.FLAG = "huntrooms_power"

local function Range(key)
	local a, b = tostring(key):match("^(%d+)-(%d+)$")
	return tonumber(a), tonumber(b)
end

-- A power room's stretch: one room, the game's door roll with only the normal
-- power reward (its difficulty spread: the stretch's own, given).
function PowerRooms.Stretch(difficulty, kind)
	local d = {}
	for k, v in pairs(difficulty or { easy = 20, medium = 75, hard = 5 }) do
		d[k] = v
	end
	return {
		roomtype = { monster = 1 },
		reward = { plain = 1 },
		difficulty_distribution = d,
		[PowerRooms.FLAG] = kind or true,
	}
end

-- Puts power rooms into a map's room_distribution, before each of the game's
-- rooms listed (the game's own numbers, e.g. { 13 }: a power room where the
-- game's room 13 was, that room and every later one one on). A game stretch
-- the room falls inside is split around it (both halves the same table).
-- Returns how many went in (0: the map isn't laid out as expected; nothing
-- changed then).
function PowerRooms.Insert(def, before, difficulty, kind)
	local rd = type(def) == "table" and def.room_distribution or nil
	if type(rd) ~= "table" or type(before) ~= "table" or #before == 0 then
		return 0
	end
	local spans = {}
	for key, dist in pairs(rd) do
		local a, b = Range(key)
		if a == nil or b == nil or b < a or type(dist) ~= "table" then
			return 0
		end
		spans[#spans + 1] = { a = a, b = b, dist = dist }
	end
	table.sort(spans, function(x, y) return x.a < y.a end)
	local points = {}
	for _, v in ipairs(before) do
		v = math.floor(tonumber(v) or 0)
		if v < 3 then
			return 0 -- never before the start or room 2 (the map's start makes those)
		end
		points[#points + 1] = v
	end
	table.sort(points)
	local last = spans[#spans].b
	for i, v in ipairs(points) do
		if v > last or (i > 1 and points[i - 1] == v) then
			return 0
		end
	end
	-- the game's numbers -> where they go: each one shifts by the power rooms before it
	local function Shift(n)
		local s = 0
		for _, v in ipairs(points) do
			if v <= n then
				s = s + 1
			end
		end
		return n + s
	end
	local out = {}
	for _, sp in ipairs(spans) do
		-- the game's rooms a..b, cut at each insertion point inside (a < v <= b)
		local from = sp.a
		for _, v in ipairs(points) do
			if v > sp.a and v <= sp.b then
				out[Shift(from) .. "-" .. Shift(v - 1)] = sp.dist
				from = v
			end
		end
		out[Shift(from) .. "-" .. Shift(sp.b)] = sp.dist
	end
	for i, v in ipairs(points) do
		local at = Shift(v) - 1 -- the room just before the game's room v, after it moved
		out[at .. "-" .. at] = PowerRooms.Stretch(difficulty, kind)
	end
	for key in pairs(rd) do
		rd[key] = nil
	end
	for key, dist in pairs(out) do
		rd[key] = dist
	end
	return #points
end

-- Is the map's room at this index a power room? Its kind ("side", "blight"), or nil.
function PowerRooms.Is(def, index)
	local rd = type(def) == "table" and def.roomdist or nil
	local room = type(rd) == "table" and type(index) == "number" and rd[index] or nil
	local kind = type(room) == "table" and room[PowerRooms.FLAG] or nil
	if kind == true then
		return "side"
	end
	return kind
end

local function Copy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = Copy(v)
	end
	return c
end

-- Runs fn with the game's gen_state kept aside and put back after (the power
-- room's doors and entering it never reach the game's counters).
function PowerRooms.Aside(mgrun, fn, ...)
	local data = type(mgrun) == "table" and mgrun.data or nil
	if type(data) ~= "table" or type(data.gen_state) ~= "table" then
		return fn(...)
	end
	local kept = data.gen_state
	data.gen_state = Copy(kept)
	local results = table.pack(pcall(fn, ...))
	data.gen_state = kept
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Pause-map paths (prefabs/autogen/mappath, DungeonHistoryMap:_ChoosePath) for
-- lengths the game has none for: the start of each of its shortest longer
-- paths (the same shapes, cut where the hunt ends). Returns how many were made.
function PowerRooms.Paths(paths, lengths, prefix)
	local made = 0
	for length in pairs(lengths) do
		local have, best = false, nil
		for _, p in pairs(paths) do
			local l = type(p) == "table" and tonumber(p.length) or nil
			if l == length then
				have = true
			elseif l ~= nil and l > length and type(p.path) == "table" and #p.path >= length and (best == nil or l < best) then
				best = l
			end
		end
		if not have and best ~= nil then
			local add = {}
			for name, p in pairs(paths) do
				if type(p) == "table" and tonumber(p.length) == best and type(p.path) == "table" and #p.path >= length then
					local steps = {}
					for i = 1, length do
						steps[i] = p.path[i]
					end
					local key = prefix .. tostring(name) .. "_" .. length
					add[key] = { __displayName = key, boss_position = p.boss_position, length = length, path = steps }
				end
			end
			for key, p in pairs(add) do
				paths[key] = p
				made = made + 1
			end
		end
	end
	return made
end

return PowerRooms
