-- Save States: the data rules, with no game calls (tested on their own).
--
-- A player's saved run parts:
--   powers     the power manager's own save (every power with its rarity, stacks
--              and counters, the powers seen, rerolls left)
--   hp         current HP (nil = full)
--   konjur     Teffra, and the stack's own record
--   potion     { id, max, remaining } and every use count (tonics too)
--   huntrooms / twoweapons (memory, charged skills) / dungeontracker: the run's records
--   classes    the 2 weapon classes ("HAMMER", "BOW"), held = the one in hand
--   gear       what was worn: the item records (level, gems, mirage) for Replicate
--
-- Merge builds a character's data from its OWN current data (the file the game
-- wrote at the run's start) with only those parts swapped in. Guard then checks
-- every other part is identical, or the load is refused.
local D = {}

local function deepcopy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local o = {}
	seen[t] = o
	for k, v in pairs(t) do
		o[deepcopy(k, seen)] = deepcopy(v, seen)
	end
	return o
end
D.deepcopy = deepcopy

local function deepequal(a, b, seen)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		-- numbers saved and loaded: 5 and 5.0 are the same
		if type(a) == "number" and type(b) == "number" then
			return a == b
		end
		return false
	end
	-- (a table met again on the same pair: already being compared)
	seen = seen or {}
	seen[a] = seen[a] or {}
	if seen[a][b] then
		return true
	end
	seen[a][b] = true
	for k, v in pairs(a) do
		if not deepequal(v, b[k], seen) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end
D.deepequal = deepequal

-- Power slots that aren't the run's: the game puts them back from your own
-- talents, gear, hearts and settings at every run's start (or they only last a moment).
D.NONRUN = {
	EQUIPMENT = true, TALENT = true, HEART = true, STATUSEFFECT = true, EXPEDITION = true,
	POTION_POWER = true, CHEAT = true, CHALLENGE = true, MOVEMENT = true, GROAK = true,
	WEIGHT = true, -- (your armour's weight)
	TONIC = true,  -- (a tonic's effect, from drinking it)
	SKILL = true, -- skills: see below (a skill picked up in the run is the run's)
}
-- powers in these slots that both characters have: their run counters come back
D.COUNTER_SLOTS = { TALENT = true, EQUIPMENT = true, HEART = true, SKILL = true, POTION_POWER = true }
-- what a power IS (never copied as a counter)
D.IDENTITY = { id = true, slot = true, rarity = true, stacks = true, acquire_order = true, permanent = true, skillslots = true }
D.STARTING_TEFFRA = "talent_starting_teffra"

-- ---------------------------------------------------------------------------
-- weapon classes: the same 2 (any order). a, b = lists of class names.
function D.SameClasses(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
		return false
	end
	local count = {}
	for _, c in ipairs(a) do
		count[c] = (count[c] or 0) + 1
	end
	for _, c in ipairs(b) do
		if not count[c] or count[c] == 0 then
			return false
		end
		count[c] = count[c] - 1
	end
	return true
end

local CLASS_NAMES = {
	HAMMER = "Hammer", POLEARM = "Spear", BOW = "Bow", CANNON = "Cannon", SHOTPUT = "Striker", CLEAVER = "Cleaver",
}
function D.ClassName(c)
	if c == nil then
		return "none"
	end
	return CLASS_NAMES[c] or (tostring(c):sub(1, 1) .. tostring(c):sub(2):lower())
end
function D.ClassesText(list)
	if type(list) ~= "table" or #list == 0 then
		return "no weapon"
	end
	local o = {}
	for i, c in ipairs(list) do
		o[i] = D.ClassName(c)
	end
	return table.concat(o, " + ")
end

-- ---------------------------------------------------------------------------
-- potion charges: full stays full, empty stays empty, in between the same
-- share (rounded), never 0 unless it was empty.
function D.PotionTarget(saved_remaining, saved_max, new_max)
	saved_remaining = tonumber(saved_remaining) or 0
	saved_max = tonumber(saved_max) or 0
	new_max = tonumber(new_max) or 0
	if new_max <= 0 then
		return 0
	end
	if saved_max <= 0 then
		return new_max -- nothing known: the game's own (full)
	end
	if saved_remaining >= saved_max then
		return new_max
	end
	if saved_remaining <= 0 then
		return 0
	end
	if saved_max == new_max then
		return math.floor(saved_remaining)
	end
	local t = math.floor(saved_remaining / saved_max * new_max + 0.5)
	if t < 1 then
		t = 1
	end
	if t > new_max then
		t = new_max
	end
	return t
end

-- ---------------------------------------------------------------------------
-- the run parts of one player's merge
local function SavedPowers(p)
	return type(p) == "table" and type(p.powers) == "table" and type(p.powers.power_data) == "table"
		and type(p.powers.power_data.powers) == "table" and p.powers or nil
end

-- The powers the gear gives now ({ from = powers_from_equipment, overridden =
-- overridden_equipment_powers }, read before the run start) are the saved ones,
-- and each has its saved record: true.
function D.SameGearPowers(sp, now)
	if type(sp) ~= "table" or type(now) ~= "table" or type(now.from) ~= "table" or type(sp.powers_from_equipment) ~= "table" then
		return false
	end
	if not deepequal(sp.powers_from_equipment, now.from) then
		return false
	end
	local so = type(sp.overridden_equipment_powers) == "table" and sp.overridden_equipment_powers or {}
	local no = type(now.overridden) == "table" and now.overridden or {}
	if not deepequal(so, no) then
		return false
	end
	local recs = type(sp.power_data) == "table" and type(sp.power_data.powers) == "table" and sp.power_data.powers.EQUIPMENT or nil
	for _, list in pairs(sp.powers_from_equipment) do
		if type(list) ~= "table" then
			return false
		end
		for _, e in ipairs(list) do
			local rec = type(e) == "table" and type(e.name) == "string" and type(recs) == "table" and recs[e.name] or nil
			if type(rec) ~= "table" or rec.id ~= e.name then
				return false
			end
		end
	end
	return true
end

-- B: the character's own data (a table like the game's character file "player").
-- p: the saved player. opts: { counters = bool, held_matches = bool }
-- Returns the merged copy and a few counts for the note.
function D.Merge(B, p, opts)
	opts = opts or {}
	assert(type(B) == "table", "no character data")
	local sp = SavedPowers(p)
	assert(sp ~= nil, "the save has no powers part")
	local M = deepcopy(B)
	local info = { powers = 0, skipped = {} }

	-- powers
	M.powermanager = type(M.powermanager) == "table" and M.powermanager or {}
	local pm = M.powermanager
	pm.power_data = type(pm.power_data) == "table" and pm.power_data or {}
	local pd = pm.power_data
	pd.powers = type(pd.powers) == "table" and pd.powers or {}
	pd.seen_powers = type(pd.seen_powers) == "table" and pd.seen_powers or {}
	local spd = sp.power_data
	local order = tonumber(pd.acquire_index) or 0
	for slot, list in pairs(spd.powers) do
		if type(list) == "table" and not D.NONRUN[slot] then
			pd.powers[slot] = deepcopy(list)
			for _, rec in pairs(list) do
				info.powers = info.powers + 1
				local o = type(rec) == "table" and tonumber(rec.acquire_order) or nil
				if o ~= nil and o >= order then
					order = o + 1
				end
			end
		end
	end
	-- a skill picked up in the run (it replaced the weapon's skill)
	local run_skill = type(sp.overridden_equipment_skills) == "table" and next(sp.overridden_equipment_skills) ~= nil
	if run_skill and type(spd.powers.SKILL) == "table" then
		local mine = type(pd.powers.SKILL) == "table" and pd.powers.SKILL or {}
		local managed = false -- a skill another mod keeps (permanent): theirs stays
		for _, rec in pairs(mine) do
			if type(rec) == "table" and rec.permanent then
				managed = true
			end
		end
		if managed then
			info.skipped[#info.skipped + 1] = "the run's skill (your skill slots keep theirs)"
		else
			local skills = {}
			for name, rec in pairs(spd.powers.SKILL) do
				if type(rec) == "table" and not rec.permanent then
					skills[name] = deepcopy(rec)
					info.powers = info.powers + 1
				end
			end
			pd.powers.SKILL = skills
			pm.overridden_equipment_skills = deepcopy(sp.overridden_equipment_skills)
		end
	end
	for slot, seen in pairs(type(spd.seen_powers) == "table" and spd.seen_powers or {}) do
		if not D.NONRUN[slot] and type(seen) == "table" then
			pd.seen_powers[slot] = deepcopy(seen)
		end
	end
	local sai = tonumber(spd.acquire_index) or 0
	pd.acquire_index = math.max(order, sai, tonumber(pd.acquire_index) or 0)
	pm.power_drop_rerolls = tonumber(sp.power_drop_rerolls) or 0

	-- your gear's powers: the game's run start clears them (PowerManager:ResetData)
	-- and adds them again at the reload, so their "when you get it" part ran
	-- again at every load: Perfect Pairing's potion charge with its refill
	-- animation, and their counters started over (0.1.0-0.1.2). With the same
	-- gear's powers as in the save, they're put back as saved: the game then
	-- sees no change (like going through a door). Other gear: the game's own.
	if opts.counters and D.SameGearPowers(sp, opts.gear_powers) then
		pd.powers.EQUIPMENT = type(pd.powers.EQUIPMENT) == "table" and pd.powers.EQUIPMENT or {}
		for _, list in pairs(sp.powers_from_equipment) do
			for _, e in ipairs(list) do
				pd.powers.EQUIPMENT[e.name] = deepcopy(spd.powers.EQUIPMENT[e.name])
			end
		end
		pm.powers_from_equipment = deepcopy(sp.powers_from_equipment)
		pm.overridden_equipment_powers = deepcopy(type(sp.overridden_equipment_powers) == "table" and sp.overridden_equipment_powers or {})
		info.gear_powers = true
	end

	-- run counters on the powers both have (lives left, Teffra taken, charges)
	if opts.counters then
		for slot in pairs(D.COUNTER_SLOTS) do
			local mine, theirs = pd.powers[slot], spd.powers[slot]
			if type(mine) == "table" and type(theirs) == "table" then
				for name, rec in pairs(mine) do
					local s = theirs[name]
					if type(rec) == "table" and type(s) == "table" then
						for k, v in pairs(s) do
							if not D.IDENTITY[k] and (type(v) == "number" or type(v) == "boolean") then
								rec[k] = v
							end
						end
					end
				end
			end
		end
		-- starting Teffra: the save's run had it (or a later room): not again
		local talents = pd.powers.TALENT
		local st = type(talents) == "table" and talents[D.STARTING_TEFFRA] or nil
		local had = type(spd.powers.TALENT) == "table" and spd.powers.TALENT[D.STARTING_TEFFRA] or nil
		if type(st) == "table" and had == nil and (tonumber(p.room_index) or 2) > 1 then
			st.consumed = true
		end
	end

	-- HP (nil = full)
	M.health = type(M.health) == "table" and M.health or {}
	M.health.current = tonumber(p.hp)

	-- Teffra: only the konjur stack
	M.inventoryhoard = type(M.inventoryhoard) == "table" and M.inventoryhoard or {}
	local hoard = M.inventoryhoard
	hoard.inventory = type(hoard.inventory) == "table" and hoard.inventory or {}
	hoard.inventory.MATERIALS = type(hoard.inventory.MATERIALS) == "table" and hoard.inventory.MATERIALS or {}
	local mats = hoard.inventory.MATERIALS
	local k = math.max(0, math.floor(tonumber(p.konjur) or 0))
	if k <= 0 then
		mats.konjur = nil
	elseif type(mats.konjur) == "table" then
		mats.konjur.count = k
	else
		local rec = type(p.konjur_record) == "table" and deepcopy(p.konjur_record)
			or { id = "konjur", slot = "MATERIALS", is_consumable = true, ilvl = 1, base_ilvl = 1, stats = {} }
		rec.count = k
		local ai = tonumber(hoard.acquire_index) or 0
		rec.acquire_order = ai
		hoard.acquire_index = ai + 1
		mats.konjur = rec
	end

	-- use counts (potions and tonics): the saved ones; the main potion's is
	-- set after the load from your own potion's charges (PotionTarget)
	M.usetracker = type(M.usetracker) == "table" and M.usetracker or {}
	M.usetracker.tracked_uses = type(M.usetracker.tracked_uses) == "table" and M.usetracker.tracked_uses or {}
	for id, n in pairs(type(p.uses) == "table" and p.uses or {}) do
		if type(n) == "number" then
			M.usetracker.tracked_uses[id] = n
		end
	end

	-- the mods' run records
	-- (none saved = none: the record of the run you were in doesn't carry over)
	M.huntrooms = type(p.huntrooms) == "table" and deepcopy(p.huntrooms) or nil
	if type(p.dungeontracker) == "table" then
		M.dungeontracker = deepcopy(p.dungeontracker)
	end
	if type(M.twoweapons) == "table" then
		if opts.held_matches and type(p.twoweapons) == "table" then
			M.twoweapons.memory = deepcopy(p.twoweapons.memory)
			M.twoweapons.carried = deepcopy(p.twoweapons.carried)
		else
			M.twoweapons.memory = nil
			M.twoweapons.carried = nil
		end
	end
	return M, info
end

-- The parts Merge may change. Everything else must be identical.
D.ALLOWED = {
	{ "powermanager" },
	{ "health", "current" },
	{ "inventoryhoard", "inventory", "MATERIALS", "konjur" },
	{ "inventoryhoard", "acquire_index" },
	{ "usetracker" },
	{ "huntrooms" },
	{ "dungeontracker" },
	{ "twoweapons", "memory" },
	{ "twoweapons", "carried" },
}

local function Mask(t)
	local c = deepcopy(t)
	for _, path in ipairs(D.ALLOWED) do
		local node = c
		for i = 1, #path - 1 do
			node = type(node) == "table" and node[path[i]] or nil
		end
		if type(node) == "table" then
			node[path[#path]] = nil
		end
	end
	return c
end
D.Mask = Mask

-- true when M differs from B only in the run parts
function D.Guard(B, M)
	if type(B) ~= "table" or type(M) ~= "table" then
		return false, "no character data"
	end
	local a, b = Mask(B), Mask(M)
	if deepequal(a, b) then
		return true
	end
	-- name the first part that differs
	for k, v in pairs(a) do
		if not deepequal(v, b[k]) then
			return false, "would change " .. tostring(k)
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false, "would add " .. tostring(k)
		end
	end
	return false, "would change the character"
end

-- ---------------------------------------------------------------------------
-- a state's own checks (before anything is looked up in the game)
function D.CheckState(st)
	if type(st) ~= "table" then
		return false, "the save is empty"
	end
	if type(st.run) ~= "table" or type(st.run.location_id) ~= "string" then
		return false, "the save has no run"
	end
	if type(st.worldmap) ~= "table" or type(st.worldmap.mgrun_data) ~= "table" then
		return false, "the save has no map"
	end
	if type(st.players) ~= "table" or #st.players == 0 then
		return false, "the save has no players"
	end
	for i, p in ipairs(st.players) do
		if SavedPowers(p) == nil then
			return false, "player " .. i .. " has no powers part"
		end
		if type(p.classes) ~= "table" then
			return false, "player " .. i .. " has no weapons part"
		end
	end
	if type(st.run.room_id) ~= "number" or type(st.run.world_prefab) ~= "string" then
		return false, "the save has no room"
	end
	return true
end

-- a number as a whole one for a label (HP mid-fight can be 412.5: Lua 5.4's
-- %d refuses that, 0.1.0 failed every load from such a moment)
local function Whole(x)
	local n = tonumber(x)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return "?"
	end
	return tostring(math.floor(n + 0.5))
end
D.Whole = Whole

-- a short line about a state, for the menu and the notes
function D.Summary(st)
	if type(st) ~= "table" or type(st.run) ~= "table" then
		return "?"
	end
	local r = st.run
	local where = tostring(r.location_id)
	if r.trek then
		where = "Blight leg " .. tostring(r.trek_leg or "?") .. (r.trek_stage and r.trek_stage > 1 and ("-" .. r.trek_stage) or "") .. " (" .. where .. ")"
	end
	local lvl = tonumber(r.ascension) or 0
	local fr = lvl > 0 and (" Frenzy " .. Whole(lvl)) or ""
	local hp, teffra, n = "", "", "0"
	local p = type(st.players) == "table" and st.players[1] or nil
	if p then
		hp = p.hp ~= nil and (" HP " .. Whole(p.hp)) or " HP full"
		teffra = " Teffra " .. Whole(tonumber(p.konjur) or 0)
		n = Whole(tonumber(p.power_count) or 0)
	end
	local who = type(st.players) == "table" and #st.players > 1 and (" " .. #st.players .. " players") or ""
	return string.format("%s%s room %s%s%s %s powers%s", where, fr, tostring(r.room_id), hp, teffra, n, who)
end

return D
