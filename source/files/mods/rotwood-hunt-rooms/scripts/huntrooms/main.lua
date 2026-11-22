-- Hunt Rooms: the settings, the log and the protected calls every part uses.
--
-- Layers of safety (each part is on its own):
--  1. install: each part checks the game functions it needs and stays off
--     (the game's way) when one is missing or changed; the others go on
--  2. run time: every hook calls the game's own function first or after, and
--     the mod's part inside a protected call: an error turns that part off
--     for the session (logged once) and the game's result stands
--  3. data: a room the map has no odds for (a run saved with other
--     settings) takes the map's last odds instead of the game's assert
--  4. settings: a bad value falls back to its default (logged)
local HR = {}

HR.TAG = "[Hunt Rooms]"
HR.MAX_EXTRA = 8 -- extra rooms a map can have (the variants are made for 1 to 8)
HR.WEIGHT_KINDS = { fabled = true, weaponpower = true, plain = true }

HR.DEFAULTS = {
	enabled = true,
	start_weapon_power = true,
	split_sound = true,
	weapon_power_rooms = 4,
	weapon_power_doors = 2,
	weapon_power_doors_blight = 3,
	weapon_power_gap = 1,
	extra_fabled = 3,
	fabled_share = 50,
	frenzy_side_rooms = 1,
	super_side_rooms = { 1, 2, 3, 4, 5 },
	side_room_doors = { fabled = 40, weaponpower = 30, plain = 30 },
	blight_rooms = 2,
	blight_room_doors = { fabled = 50, weaponpower = 50 },
	blight_weapon_rooms_per_leg = 2,
	blight_miniboss = true,
	-- 0.3.0
	fabled_never_pair = { "SHIELD", "SUMMON" },
	fabled_favour = "ELECTRIC",
	fabled_favour_share = 75,
	miniboss_fabled = 4,
	miniboss_rewards = true,
	miniboss_corestones = { normal = 1, frenzy = { 1, 1, 1, 1, 2 }, super = { 2, 2, 2, 2, 2 }, blight = 2 },
	miniboss_ingots = { normal = 0, frenzy = { 1, 1, 2, 2, 3 }, super = { 4, 4, 4, 4, 4 }, blight = 3 },
	miniboss_materials = { normal = 1, frenzy = { 1, 1, 2, 2, 2 }, super = { 3, 3, 3, 3, 3 }, blight = 2 },
	miniboss_teffra = { normal = 10, frenzy = { 14, 18, 22, 26, 30 }, super = { 34, 38, 42, 46, 50 }, blight = 30 },
	shard_room = { 40, 45, 50, 55, 60 },
	shard_room_shards = { 1, 2, 3, 4, 5 },
	frenzy_main_chance = 25,
	frenzy_main_from_powers = 50,
	super_main_halve = 50,
	super_main_from_powers = 5,
	super_main_reward = 2,
	debug = false,
}

HR.settings = nil
HR.off = {}      -- part -> why it's off for this session (an error)
HR.info = {}     -- part -> what it does (the log line at load)
HR.warnings = {} -- settings that fell back to their default

function HR.Log(msg)
	print(HR.TAG .. " " .. tostring(msg))
end

function HR.Debug(msg)
	if HR.settings ~= nil and HR.settings.debug then
		HR.Log(msg)
	end
end

-- fn(...) protected: ok, results... On an error the part goes off for the
-- session (once, logged) and false comes back.
function HR.Call(part, fn, ...)
	if HR.off[part] ~= nil then
		return false, "off"
	end
	local r = table.pack(pcall(fn, ...))
	if not r[1] then
		HR.off[part] = tostring(r[2])
		HR.Log(part .. ": off for this session after an error (the game's way from here): " .. tostring(r[2]))
		return false, r[2]
	end
	return table.unpack(r, 1, r.n)
end

function HR.On(part)
	return HR.settings ~= nil and HR.settings.enabled ~= false and HR.off[part] == nil
end

local function Warn(key, v, default)
	HR.warnings[#HR.warnings + 1] = string.format("setting %s = %s isn't valid, using %s", key, tostring(v), tostring(default))
end

local function Num(s, key, lo, hi, whole)
	local v, default = s[key], HR.DEFAULTS[key]
	if v == false then
		v = 0
	end
	local n = tonumber(v)
	if n == nil or n ~= n or n < lo or n > hi then
		if v ~= nil then
			Warn(key, v, default)
		end
		n = default
	end
	if whole then
		n = math.floor(n + 0.5)
	end
	s[key] = n
end

local function Weights(s, key)
	local v, default = s[key], HR.DEFAULTS[key]
	local out, any = {}, false
	if type(v) == "table" then
		for k, w in pairs(v) do
			local n = tonumber(w)
			if not HR.WEIGHT_KINDS[k] or n == nil or n ~= n or n < 0 then
				out = nil
				break
			end
			out[k] = n
			any = any or n > 0
		end
	else
		out = nil
	end
	if out == nil or not any then
		if v ~= nil then
			Warn(key, v, "the default")
		end
		out = {}
		for k, w in pairs(default) do
			out[k] = w
		end
	end
	s[key] = out
end

-- Five numbers (Super Frenzy 1 to 5, or one number for all), each lo..hi;
-- false = zeros. A bad one: the default.
local function Five(s, key, lo, hi)
	local v, default = s[key], HR.DEFAULTS[key]
	local out = {}
	if v == false then
		s[key] = { 0, 0, 0, 0, 0 }
		return
	end
	if type(v) == "number" then
		v = { v }
	end
	local ok = type(v) == "table" and #v >= 1
	if ok then
		for i = 1, 5 do
			local n = tonumber(v[i] or v[#v])
			if n == nil or n ~= n or n < lo or n > hi then
				ok = false
				break
			end
			out[i] = n
		end
	end
	if not ok then
		Warn(key, v, "the default")
		out = {}
		for i = 1, 5 do
			out[i] = default[i]
		end
	end
	s[key] = out
end

-- A miniboss reward by level: { normal = n, frenzy = { 5 }, super = { 5 }, blight = n }
-- (a part left out or bad: its default; false = all 0). Whole numbers 0..hi.
local function Levels(s, key, hi)
	local v, default = s[key], HR.DEFAULTS[key]
	local out = { frenzy = {}, super = {} }
	local function One(x, d)
		local n = tonumber(x)
		if n == nil or n ~= n or n < 0 or n > hi then
			if x ~= nil then
				Warn(key, x, d)
			end
			return d
		end
		return math.floor(n + 0.5)
	end
	if v == false then
		s[key] = { normal = 0, frenzy = { 0, 0, 0, 0, 0 }, super = { 0, 0, 0, 0, 0 }, blight = 0 }
		return
	end
	if type(v) ~= "table" then
		if v ~= nil then
			Warn(key, v, "the default")
		end
		v = {}
	end
	out.normal = One(v.normal, default.normal)
	out.blight = One(v.blight, default.blight)
	for _, part in ipairs({ "frenzy", "super" }) do
		local list = v[part]
		if type(list) == "number" then
			list = { list }
		end
		for i = 1, 5 do
			local x = type(list) == "table" and (list[i] or list[#list]) or nil
			out[part][i] = One(x, default[part][i])
		end
	end
	s[key] = out
end

-- The settings: the user's over the defaults, each checked.
function HR.LoadSettings(user)
	HR.warnings = {}
	local s = {}
	for k, v in pairs(HR.DEFAULTS) do
		if type(v) == "table" then
			local c = {}
			for k2, v2 in pairs(v) do
				c[k2] = v2
			end
			s[k] = c
		else
			s[k] = v
		end
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if HR.DEFAULTS[k] ~= nil then
				s[k] = v
			else
				HR.warnings[#HR.warnings + 1] = "setting " .. tostring(k) .. " isn't one of Hunt Rooms' (ignored)"
			end
		end
	end
	s.enabled = s.enabled ~= false
	s.start_weapon_power = s.start_weapon_power ~= false
	s.split_sound = s.split_sound ~= false
	s.blight_miniboss = s.blight_miniboss ~= false
	s.miniboss_rewards = s.miniboss_rewards ~= false
	-- the Fabled families (0.3.0): a pair never given, one family favoured
	local np = s.fabled_never_pair
	if np == false then
		s.fabled_never_pair = false
	elseif type(np) ~= "table" or type(np[1]) ~= "string" or type(np[2]) ~= "string" or np[1] == np[2] then
		Warn("fabled_never_pair", np, "{ \"SHIELD\", \"SUMMON\" }")
		s.fabled_never_pair = { "SHIELD", "SUMMON" }
	else
		s.fabled_never_pair = { np[1]:upper(), np[2]:upper() }
	end
	if s.fabled_favour == false then
		s.fabled_favour = false
	elseif type(s.fabled_favour) ~= "string" or s.fabled_favour == "" then
		Warn("fabled_favour", s.fabled_favour, "ELECTRIC")
		s.fabled_favour = "ELECTRIC"
	else
		s.fabled_favour = s.fabled_favour:upper()
	end
	Num(s, "fabled_favour_share", 0, 100)
	Num(s, "miniboss_fabled", 2, 8, true)
	Levels(s, "miniboss_corestones", 5) -- (the game's Corestone drop sends at most 7; 5 its own limit)
	Levels(s, "miniboss_ingots", 50)
	Levels(s, "miniboss_materials", 20)
	Levels(s, "miniboss_teffra", 1000)
	Five(s, "shard_room", 0, 100)
	Five(s, "shard_room_shards", 0, 20)
	for i = 1, 5 do
		s.shard_room_shards[i] = math.floor(s.shard_room_shards[i] + 0.5)
	end
	s.debug = s.debug == true
	Num(s, "weapon_power_rooms", 0, 8, true)
	Num(s, "weapon_power_doors", 0, 20, true)
	Num(s, "weapon_power_doors_blight", 0, 20, true)
	Num(s, "weapon_power_gap", 0, 10, true)
	Num(s, "extra_fabled", 0, 20, true)
	Num(s, "fabled_share", 0, 100)
	Num(s, "frenzy_side_rooms", 0, HR.MAX_EXTRA, true)
	Num(s, "blight_rooms", 0, HR.MAX_EXTRA, true)
	Num(s, "blight_weapon_rooms_per_leg", 0, 8, true)
	Num(s, "frenzy_main_chance", 0, 100)
	Num(s, "frenzy_main_from_powers", 0, 100)
	Num(s, "super_main_halve", 0, 100)
	Num(s, "super_main_from_powers", 0, 100)
	Num(s, "super_main_reward", 0, 10)
	if s.super_main_reward < 1 then
		Warn("super_main_reward", s.super_main_reward, 1)
		s.super_main_reward = 1
	end
	Weights(s, "side_room_doors")
	Weights(s, "blight_room_doors")
	-- super_side_rooms: 5 levels, each 0 to MAX_EXTRA rooms
	local sr, ok = s.super_side_rooms, true
	local levels = {}
	if type(sr) == "table" then
		for i = 1, 5 do
			local n = tonumber(sr[i] or sr[#sr])
			if n == nil or n ~= n or n < 0 or n > HR.MAX_EXTRA then
				ok = false
				break
			end
			levels[i] = math.floor(n + 0.5)
		end
	elseif sr == false then
		levels = { 0, 0, 0, 0, 0 }
	else
		ok = false
	end
	if not ok then
		Warn("super_side_rooms", sr, "{ 1, 2, 3, 4, 5 }")
		levels = { 1, 2, 3, 4, 5 }
	end
	s.super_side_rooms = levels
	HR.settings = s
	return s
end

return HR
