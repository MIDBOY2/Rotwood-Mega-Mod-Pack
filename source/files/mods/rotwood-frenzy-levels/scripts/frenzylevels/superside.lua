-- Frenzy Levels: Super Frenzy 1 to 5 on the side hunts you frenzy yourself (an
-- experiment). On the map, RB past Frenzy 5 on a side hunt you frenzied
-- yourself (not an anomaly) picks "Super Frenzy 1", then 2 to 5
-- (frenzylevels.lua: the panel and marker in the game's Super Frenzy colours;
-- each level opens once the one below is cleared on that side hunt, or all of
-- them with unlock_all). The game has no Super Frenzy for side hunts, so the
-- run itself is the game's Frenzy 5 run (its maps, progress, rewards and look)
-- with these changes, all made here:
--  * the game's Super Frenzy level: the enemy, destructible, trap, ascension
--    and hunt modifiers (defs/modifiers/modifier_resolvers.lua) resolve as
--    that Super Frenzy level (ascension 6 to 10, dungeon tier 11), the way the
--    game's own Super Frenzy does: enemy health x3.0 / 3.45 / 3.7 / 3.83 /
--    3.95 (Frenzy 5 x2.8), damage x3.0 / 3.45 / 3.7 / 3.95 / 4.2 (x2.8, before
--    armour), every enemy that can be elite is elite (55%), the side hunt's
--    boss x7.5 / 8.2 / 8.55 / 8.73 / 8.9 health (x4.9), shorter stuns; traps
--    harder (SF1, more from SF2); SF4 start damaged (250); SF5 the higher
--    prices (no free upgrade or cauldron heal, one market choice fewer).
--    Loot and player modifiers stay Frenzy 5's, but the boss's Corestones and
--    ingots (0.8.3, boss_like_main): the game's Super Frenzy level's, 6 and 5
--    (a Super Frenzy main hunt boss's; Frenzy 5's are 5 and 3), then the loot
--    multiplier. The side hunt's boss stays its
--    normal one (the game has no elite versions of the side hunt bosses: BOSS
--    is left out of the allowed elites). SF3's hard miniboss rule changes
--    nothing here (the side hunt boss fights don't check it).
--  * every fight room is hard (difficulty 3: the horned map icon), weapon
--    power and friend gift rooms included (the game keeps those medium). Two
--    plain (or coin) doors that now look alike: one becomes the other kind,
--    the game's own second fix (SS.Distinct)
--  * loot x1.5 / 1.75 / 2 / 2.25 / 2.5 by level (super_side_hunts.loot):
--    Corestones, monster and boss materials, ingots, seeds and Heart Shards,
--    on top of everything Frenzy 5 and the hard rooms give. Not Teffra (the
--    game's konjur) unless teffra = true. Counts are rounded at random so the
--    average is exact (1 Corestone at x1.5: 1 or 2, half the time each).
-- Main hunts at Super Frenzy 1 to 5 (the game's own): loot x1.5 / 1.75 / 2 /
-- 2.25 / 2.5 by level the same way (super_main_loot; the game gives the same
-- loot at every Super Frenzy level), Teffra not unless super_main_loot.teffra.
-- 0.10.0 (user 2026-11-13):
--  * weather side hunts (the game's anomalies) get Super Frenzy 1 to 5 too
--    (super_side_hunts.weather): the same run as a Super Frenzy side hunt,
--    with the weather and its meter; each tier of the meter gives its rewards
--    x the loot multiplier (rewards.lua), gems and Heart Shards included
--  * Super Frenzy main hunts: more hard rooms by your party's gear level and
--    the Super Frenzy level (super_main_hard): a step for each Party Gear
--    Level above 10 (the game's own number, the map's "Party Gear Level", up
--    to 15) and each Super Frenzy level above 1: 0 steps = the game's rooms,
--    9 steps (gear 15, Super Frenzy 5) = every fight room hard. Each fight
--    door not already hard becomes hard with a chance of steps / 9 (a seeded
--    roll from the room's own seed: the same on every machine). Read when the
--    run starts.
--  * weapon power and friend gift rooms made hard (the game never has them
--    hard): hard_power_rooms (false = they stay the game's), and they give
--    extra Teffra (hard_power_room_teffra: added to the room's Teffra from
--    its kills, the game's way of paying it out)
-- Zero cost outside these runs: each hook is one boolean test (SS.run, SS.main).
local SS = {}

SS.run = false       -- this run is a Super Frenzy side hunt
SS.location = nil    -- its location id
SS.level = nil       -- its Super Frenzy level (1 to 5)
SS.lift = 0          -- inside an enemy / destructible / trap / ascension / hunt resolve
SS.loot = 1.5
SS.all_hard = true
SS.teffra = false    -- Teffra (konjur) x the loot multiplier too
SS.main = false      -- this run is a main hunt at Super Frenzy (loot only)
SS.main_level = nil  -- its Super Frenzy level (1 to 5)
SS.main_loot = 1
SS.main_teffra = false
SS.scalable = {}     -- item id -> scale it (cached)
SS.info = "off"
SS.weather = false   -- this Super Frenzy side hunt has weather (0.10.0)
SS.hard_power = true -- weapon power / friend gift rooms made hard too (hard_power_rooms)
SS.power_teffra = 0  -- extra Teffra in such a room (hard_power_room_teffra)
SS.main_hard_q = 0   -- a Super Frenzy main hunt: the chance a fight door becomes hard
SS.main_hard_steps = 0
SS.main_gear = nil   -- the party's gear level it was read from
SS.hold = 0          -- inside the weather meter's rewards: their count is scaled, not their items

local FL

local function SUPER_COUNT_OF()
	return rawget(_G, "SUPER_FRENZY_LEVELS") or 5
end

local function Log(msg)
	print((FL and FL.TAG or "[Frenzy Levels]") .. " " .. msg)
end

-- the level a Super Frenzy side hunt resolves at (the game's ascension 6 to 10)
function SS.EnemyLevel()
	return FL.SuperLevel() - 1 + (SS.level or 1)
end

-- This run (location, the game's level, weather): its Super Frenzy level
-- (1 to 5), or nil.
function SS.SuperSideLevel(location_id, level, weather, biomes)
	if FL == nil or not FL.SuperSideOn() or type(location_id) ~= "string" or level ~= FL.GameLevel(FL.SuperLevel())
		or (weather and not FL.WeatherSuperOn()) then
		return nil
	end
	if biomes == nil then
		local ok, b = pcall(require, "defs.biomes")
		biomes = ok and b or nil
	end
	if biomes == nil or biomes.IsSublocation == nil or not biomes.IsSublocation(location_id) then
		return nil
	end
	local am = FL.AM()
	if am == nil then
		return nil
	end
	return FL.SuperOf(FL.GetSideChoice(am, location_id, 0))
end

function SS.IsSuperSide(location_id, level, weather, biomes)
	return SS.SuperSideLevel(location_id, level, weather, biomes) ~= nil
end

function SS.SetRun(sf, location_id, weather)
	local on = type(sf) == "number"
	weather = on and weather == true
	if on ~= SS.run or (on and (location_id ~= SS.location or sf ~= SS.level or weather ~= SS.weather)) then
		if on then
			local c = FL.settings.super_side_hunts
			SS.loot = type(c) == "table" and c.loot[sf] or 1
			Log(string.format("Super Frenzy %d %s (%s): Super Frenzy %d enemies, %s, loot x%s%s%s", sf, weather and "weather side hunt" or "side hunt",
				tostring(location_id), sf, SS.all_hard and "every fight room hard" or "the game's hard rooms", tostring(SS.loot),
				SS.teffra and " (Teffra too)" or " (not Teffra)", weather and ", the weather meter's rewards x" .. tostring(SS.loot) .. " (gems and Heart Shards too)" or ""))
		else
			Log("Super Frenzy side hunt: over")
		end
	end
	SS.run = on
	SS.location = on and location_id or nil
	SS.level = on and sf or nil
	SS.weather = weather
	return on
end

-- The party's gear level: the game's own (util/playerutil.lua
-- GetPartyGearLevel: everyone's weapon, helmet, body and legs levels,
-- averaged), or nil.
function SS.PartyGear()
	local pu = SS.playerutil
	if pu == nil then
		local ok, m = pcall(require, "util.playerutil")
		pu = ok and m or nil
		SS.playerutil = pu
	end
	if type(pu) ~= "table" or type(pu.GetPartyGearLevel) ~= "function" then
		return nil
	end
	local ok, level = pcall(pu.GetPartyGearLevel)
	return ok and type(level) == "number" and level == level and level or nil
end

-- A Super Frenzy main hunt's steps of extra hard rooms (0 to max) and the
-- party gear level they're from: one for each gear level above gear_from (up
-- to gear_max) and each Super Frenzy level above 1.
function SS.HardSteps(sf, gear)
	local c = FL ~= nil and FL.settings.super_main_hard or nil
	if type(c) ~= "table" or type(sf) ~= "number" then
		return 0, 0
	end
	local top = (c.gear_max - c.gear_from) + (SUPER_COUNT_OF() - 1)
	local g = type(gear) == "number" and math.max(0, math.min(c.gear_max - c.gear_from, math.floor(gear) - c.gear_from)) or 0
	local l = math.max(0, math.min(SUPER_COUNT_OF() - 1, math.floor(sf) - 1))
	return g + l, top
end



-- A main hunt at Super Frenzy (the game's level 6 to 10, not in the Blight):
-- its loot multiplier by level (super_main_loot).
function SS.SetMain(level, location_id, trek, biomes)
	local sf = nil
	local c = FL ~= nil and FL.settings.super_main_loot or nil
	if type(c) == "table" and not trek and type(level) == "number" and level >= FL.SuperLevel() and type(location_id) == "string" then
		if biomes == nil then
			local ok, b = pcall(require, "defs.biomes")
			biomes = ok and b or nil
		end
		local side = biomes ~= nil and biomes.IsSublocation ~= nil and biomes.IsSublocation(location_id)
		if biomes ~= nil and not side then
			sf = math.min(level - FL.SuperLevel() + 1, #c.loot)
		end
	end
	local on = sf ~= nil
	if on ~= SS.main or (on and sf ~= SS.main_level) then
		if on then
			SS.main_loot = c.loot[sf] or 1
			SS.main_teffra = c.teffra == true
			-- (0.10.0) the hard rooms: read when the run starts, from the party's gear
			local gear = SS.PartyGear()
			local steps, top = SS.HardSteps(sf, gear)
			SS.main_hard_steps, SS.main_gear = steps, gear
			SS.main_hard_q = (top > 0) and math.min(1, steps / top) or 0
			local hard = type(FL.settings.super_main_hard) ~= "table" and ""
				or steps == 0 and string.format(", party gear level %s: the game's hard rooms", tostring(gear or "?"))
				or SS.main_hard_q >= 1 and string.format(", party gear level %s: every fight room hard (%d of %d steps)", tostring(gear), steps, top)
				or string.format(", party gear level %s: %d of %d steps, %.0f%% of the other fight doors hard", tostring(gear or "?"), steps, top, 100 * SS.main_hard_q)
			Log(string.format("Super Frenzy %d main hunt (%s): loot x%s%s%s", sf, tostring(location_id), tostring(SS.main_loot), SS.main_teffra and " (Teffra too)" or " (not Teffra)", hard))
		end
	end
	SS.main = on and not SS.run
	SS.main_level = SS.main and sf or nil
	if not SS.main then
		SS.main_hard_q, SS.main_hard_steps = 0, 0
	end
	return SS.main
end

-- the loot multiplier now: a Super Frenzy side hunt's, a main hunt's, or 1
function SS.Factor()
	if SS.run then
		return SS.loot
	elseif SS.main then
		return SS.main_loot
	end
	return 1
end

----------------------------------------------------------------------------
-- the Super Frenzy level

-- The game fills in a missing ascension level from the hunt's stored one
-- (Frenzy 5), and the run's start asks for the run's own level (5) by name;
-- inside a lifted resolve both are the run's Super Frenzy level instead.
function SS.WrapDungeonTier(orig)
	return function(modulations, ...)
		if SS.lift > 0 and SS.run and type(modulations) == "table" then
			local level, loc = modulations.ascension_level, modulations.location
			if (level == nil and (loc == nil or loc == SS.location))
				or (level == FL.GameLevel(FL.SuperLevel()) and loc ~= nil and loc == SS.location) then
				modulations.ascension_level = SS.EnemyLevel()
			end
		end
		return orig(modulations, ...)
	end
end

local function Copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

-- A lifted resolve (enemy, destructible, trap, ascension, hunt): resolved as
-- the run's Super Frenzy level. The caller's modulations are copied first (the
-- game writes the level into them, and the same table may go on to a loot
-- resolve).
function SS.WrapLifted(orig, post)
	return function(modulations, ...)
		if not SS.run then
			return orig(modulations, ...)
		end
		if type(modulations) == "table" then
			modulations = Copy(modulations)
		end
		SS.lift = SS.lift + 1
		local results = table.pack(pcall(orig, modulations, ...))
		SS.lift = SS.lift - 1
		if not results[1] then
			error(results[2], 0)
		end
		if post ~= nil and SS.run and type(results[2]) == "table" then
			post(results[2])
		end
		return table.unpack(results, 2, results.n)
	end
end

-- The loot modifiers of a Super Frenzy side hunt: Frenzy 5's (the run is the
-- game's Frenzy 5 run), but the boss's Corestones and ingots from the game's
-- own Super Frenzy level (a lifted resolve, the way the enemies get theirs):
-- a Super Frenzy main hunt boss's (0.8.3).
SS.BOSS_LOOT = { "BossKillCorestones", "BossKillIngots" }
function SS.WrapLoot(orig)
	return function(modulations, ...)
		local r = table.pack(orig(modulations, ...))
		if not SS.run or SS.lift > 0 or type(r[1]) ~= "table" then
			return table.unpack(r, 1, r.n)
		end
		local c = FL ~= nil and FL.settings ~= nil and FL.settings.super_side_hunts or nil
		if type(c) ~= "table" or c.boss_like_main == false then
			return table.unpack(r, 1, r.n)
		end
		local lifted_mods = type(modulations) == "table" and Copy(modulations) or nil
		SS.lift = SS.lift + 1
		local ok, lifted = pcall(orig, lifted_mods, ...)
		SS.lift = SS.lift - 1
		if ok and type(lifted) == "table" then
			for _, key in ipairs(SS.BOSS_LOOT) do
				local v = rawget(lifted, key)
				if type(v) == "number" and type(rawget(r[1], key)) == "number" then
					rawset(r[1], key, v)
				end
			end
		elseif not ok then
			Log("Super Frenzy side hunt boss loot: Frenzy 5's (" .. tostring(lifted) .. ")")
		end
		return table.unpack(r, 1, r.n)
	end
end

-- the allowed elites without BOSS (no elite side hunt bosses), and no
-- "elite boss" descriptor
function SS.NoEliteBoss(mods)
	local list = rawget(mods, "AllowableElites")
	if type(list) == "table" then
		local out, removed = {}, false
		for _, v in ipairs(list) do
			if v == "BOSS" then
				removed = true
			else
				out[#out + 1] = v
			end
		end
		if removed then
			mods.AllowableElites = out
		end
	end
	local desc = rawget(mods, "AscensionDescriptors")
	local sfm = rawget(_G, "SUPERFRENZY_MODIFIERS")
	local id = sfm ~= nil and sfm.id ~= nil and sfm.id.ELITE_BOSS or nil
	if type(desc) == "table" and id ~= nil and desc[id] ~= nil then
		local d = Copy(desc)
		d[id] = nil
		mods.AscensionDescriptors = d
	end
	return mods
end

----------------------------------------------------------------------------
-- every fight room hard

-- The game's FixupRoom (util/mapgenhelp.lua) keeps the doors out of a room
-- from looking alike, first by making one of two alike doors the other
-- difficulty. With every door hard, two doors with the same reward look alike
-- again: then its second fix, a plain room becomes a coin room (or a coin room
-- a plain one) when no other door has that. Other rewards stay as they are
-- (two alike doors, both with that reward).
function SS.Distinct(exit_room, current_room, mgrun)
	if type(current_room) ~= "table" or type(current_room.exits) ~= "table" or type(mgrun) ~= "table" or mgrun.GetNextRoom == nil then
		return false
	end
	local taken = {}
	for _, cardinal in ipairs(current_room.exits) do
		local other = mgrun:GetNextRoom(cardinal)
		if type(other) == "table" and other ~= exit_room and other.roomtype == exit_room.roomtype and other.difficulty == 3 and other.reward ~= nil then
			taken[other.reward] = true
		end
	end
	if not taken[exit_room.reward] then
		return false
	end
	local alt = (exit_room.reward == "plain" and "coin") or (exit_room.reward == "coin" and "plain") or nil
	if alt ~= nil and not taken[alt] then
		exit_room.reward = alt
		return true
	end
	return false
end

SS.POWER_REWARDS = { weaponpower = true, friendgift = true } -- (the game keeps these medium)

-- A seeded roll for a door (0 to 1): from the room's own seed (the game's
-- roomseed, made by the map's seeded rng), through a few steps of the
-- Park-Miller generator, so every machine (and a reloaded run) rolls the same.
function SS.Roll(room)
	local seed = math.floor(tonumber(type(room) == "table" and room.roomseed) or ((tonumber(type(room) == "table" and room.index) or 0) * 7919))
	local x = (seed + 104729) % 2147483647
	if x <= 0 then
		x = x + 2147483646
	end
	for _ = 1, 3 do
		x = (x * 48271) % 2147483647
	end
	return x / 2147483647
end

-- Does this run's rule want this fight door hard? (SS.run: every one with
-- all_hard; a Super Frenzy main hunt: its seeded roll against main_hard_q.)
-- Weapon power / friend gift doors only with hard_power_rooms.
function SS.Wants(exit_room)
	if type(exit_room) ~= "table" or exit_room.roomtype ~= "monster" or type(exit_room.difficulty) ~= "number" or exit_room.difficulty < 1 then
		return false
	end
	if SS.POWER_REWARDS[exit_room.reward] and not SS.hard_power then
		return false
	end
	if SS.run then
		return SS.all_hard == true
	end
	if SS.main and SS.main_hard_q > 0 then
		return SS.main_hard_q >= 1 or SS.Roll(exit_room) < SS.main_hard_q
	end
	return false
end

-- Should this fight door be made hard (wanted and not hard yet)?
function SS.MakeHard(exit_room)
	return SS.Wants(exit_room) and exit_room.difficulty < 3
end

-- After the game's fix-up: a wanted door hard, and marked (also one the game
-- already rolled hard), so Hunt Rooms keeps it hard when it changes the
-- door's reward (a Fabled or weapon power door)
function SS.WrapFixup(orig)
	return function(exit_room, current_room, mgrun, ...)
		local results = table.pack(orig(exit_room, current_room, mgrun, ...))
		if SS.run or SS.main then
			local ok, err = pcall(function()
				if SS.Wants(exit_room) then
					exit_room.frenzylevels_hard = true -- (Hunt Rooms keeps it hard)
					if exit_room.difficulty < 3 then
						exit_room.difficulty = 3
						SS.Distinct(exit_room, current_room, mgrun)
					end
				end
			end)
			if not ok then
				SS.fix_errors = (SS.fix_errors or 0) + 1
				if SS.fix_errors <= 3 then
					Log("hard rooms: the game's door kept (" .. tostring(err) .. ")")
				end
			end
		end
		return table.unpack(results, 1, results.n)
	end
end

----------------------------------------------------------------------------
-- a hard weapon power / friend gift room: extra Teffra

-- The room's Teffra from its kills (KonjurRewardManager:SetBasicKonjurBudget,
-- paid out by the kills and the rest at the last one): + power_teffra in a
-- hard weapon power or friend gift room (only this mod makes those).
function SS.WrapBudget(orig)
	return function(self, ...)
		local r = table.pack(orig(self, ...))
		if SS.power_teffra > 0 and type(self) == "table" and type(self.basic_konjur_budget) == "number" then
			local ok, add = pcall(function()
				local d = rawget(SS.G or _G, "TheDungeon")
				local map = d ~= nil and d:GetDungeonMap() or nil
				if map == nil or map:GetDifficultyForCurrentRoom() ~= 3 then
					return 0
				end
				return SS.POWER_REWARDS[map:GetRewardForCurrentRoom()] and SS.power_teffra or 0
			end)
			if ok and add > 0 then
				self.basic_konjur_budget = self.basic_konjur_budget + add
				if type(self.basic_konjur_budget_max) == "number" then
					self.basic_konjur_budget_max = self.basic_konjur_budget_max + add
				end
				Log(string.format("a hard weapon power / gift room: +%d Teffra from its kills", add))
			elseif not ok then
				Log("the hard power room's Teffra: the game's (" .. tostring(add) .. ")")
			end
		end
		return table.unpack(r, 1, r.n)
	end
end

----------------------------------------------------------------------------
-- loot

-- n x the loot multiplier, rounded at random (the average is exact)
function SS.Scale(n, rand)
	if type(n) ~= "number" or n <= 0 then
		return n
	end
	local x = n * SS.Factor()
	local whole = math.floor(x + 1e-9)
	local frac = x - whole
	if frac > 1e-9 and (rand or math.random)() < frac then
		whole = whole + 1
	end
	return whole
end

-- Hunt Rooms' Heart Shard room (Hunt Rooms 0.3.0): its Heart Shards are a
-- fixed number (the Super Frenzy level), so they aren't multiplied here. The
-- game's shard room drop (power_drop_shard) in the room Hunt Rooms says is
-- its shard room (HuntRoomsAPI.ShardRoom); anything else: multiplied.
-- 0.9.0: a Super Frenzy main hunt boss's Heart Shards (rewards.lua, a repeat
-- clear) are a fixed number too (the game's bosses drop none there).
function SS.FixedShards(instigator)
	if type(instigator) ~= "table" then
		return false
	end
	if SS.main and instigator.HasTag ~= nil then
		local okb, boss = pcall(instigator.HasTag, instigator, "boss")
		if okb and boss then
			return true
		end
	end
	if instigator.prefab ~= "power_drop_shard" then
		return false
	end
	local G = SS.G or _G
	local api = rawget(G, "HuntRoomsAPI")
	if type(api) ~= "table" or type(api.ShardRoom) ~= "function" then
		return false
	end
	local ok, yes = pcall(api.ShardRoom)
	return ok and yes == true
end

-- Corestones, Heart Shards, seeds, ingots, monster and boss materials (a
-- "drops_<area>" tag). Not: boss hearts, gems, friend gifts, rerolls and
-- extra lives, cosmetics, keys. Teffra (konjur) is scaled where it's spawned
-- (WrapCurrency, with teffra = true), not here.
function SS.Scalable(id, Consumable)
	local known = SS.scalable[id]
	if known ~= nil then
		return known
	end
	local yes = false
	if type(id) == "string" and id ~= "konjur" then
		if id == "konjur_soul_lesser" or id == "konjur_heart_shard" or id:find("^seed_") then
			yes = true
		elseif Consumable ~= nil and Consumable.Items ~= nil and Consumable.Items.MATERIALS ~= nil then
			local def = Consumable.Items.MATERIALS[id]
			local tags = def ~= nil and def.tags or nil
			if type(tags) == "table" and not tags.konjur_heart then
				for tag in pairs(tags) do
					if type(tag) == "string" and tag:find("^drops_") and tag ~= "drops_currency" then
						yes = true
						break
					end
				end
			end
		end
	end
	SS.scalable[id] = yes
	return yes
end

function SS.ScaleLoot(loot, Consumable, rand, instigator)
	local out = {}
	local fixed_shards = loot.konjur_heart_shard ~= nil and SS.FixedShards(instigator)
	for id, count in pairs(loot) do
		if type(count) == "number" and SS.Scalable(id, Consumable) and not (fixed_shards and id == "konjur_heart_shard") then
			out[id] = SS.Scale(count, rand)
		else
			out[id] = count
		end
	end
	return out
end

function SS.WrapSpawnLoot(orig, Consumable)
	return function(instigator, loot, ...)
		if (SS.run or SS.main) and SS.hold == 0 and type(loot) == "table" then
			loot = SS.ScaleLoot(loot, Consumable, nil, instigator)
		end
		return orig(instigator, loot, ...)
	end
end

function SS.WrapCurrency(orig)
	return function(amount, ...)
		if ((SS.run and SS.teffra) or (SS.main and SS.main_teffra)) and SS.hold == 0 and type(amount) == "number" then
			amount = SS.Scale(amount)
		end
		return orig(amount, ...)
	end
end

function SS.WrapSoulCount(orig)
	return function(self, soul_type, ...)
		local count = orig(self, soul_type, ...)
		if (SS.run or SS.main) and SS.hold == 0 and soul_type == "konjur_soul_lesser" and type(count) == "number" then
			local scaled = SS.Scale(count)
			Log(string.format("corestones: %d -> %d (Super Frenzy %d %s hunt)", count, scaled, SS.level or SS.main_level or 0, SS.run and "side" or "main"))
			count = scaled
		end
		return count
	end
end

----------------------------------------------------------------------------
-- unlocking: a won run opens the next level on that side hunt

function SS.OnVictory()
	if not SS.run or SS.level == nil or SS.location == nil then
		return false
	end
	local am = FL.AM()
	if am ~= nil and FL.SetSuperCleared(am, SS.location, SS.level) then
		Log(string.format("Super Frenzy %d cleared on %s%s", SS.level, SS.location,
			SS.level < FL.SuperTop() - FL.SuperLevel() + 1 and string.format(": Super Frenzy %d opened", SS.level + 1) or ""))
		return true
	end
	return false
end

----------------------------------------------------------------------------
-- 0.11.3: the Teffressence Container gem on a Super Frenzy side hunt's boss
-- (user 2026-11-14 03:54: "side hunts SF5: the miniboss kill at the end of
-- the hunt will activate the imbued gem"). The game's gem (its power
-- gem_boss_soul, "boss_kill") imbues the weapon in hand on a boss kill only
-- when the game's level is Super Frenzy; a Super Frenzy side hunt runs as the
-- game's Frenzy 5 (superside's run), so it never did. Here, after the game's
-- own handler, in a Super Frenzy side hunt at super_side_hunts.imbue_gem or
-- higher (5: SF5 only; 1: every SF side level; false: never): the game's own
-- test (not a Blight leg, the weapon not imbued yet and not a boss weapon)
-- and its own imbue (craftingutil.ChargeNormalWeapon: level 11, the gem used
-- up, upgrades past 10; its "Imbued!" moment). The side hunt's boss sends
-- "boss_kill" like a main boss (the game tags it "boss" in the boss room).
-- Two Weapons' second weapon asks SS.ImbueRun() too.

function SS.ImbueRun()
	if not SS.run or FL == nil then
		return false
	end
	local c = FL.settings.super_side_hunts
	local min = type(c) == "table" and c.imbue_gem or false
	return type(min) == "number" and (SS.level or 0) >= min
end

-- after the game's boss_kill handler (pow, the player, the boss)
function SS.SideImbue(pow, inst, boss, craftingutil, weapon_slot)
	if not SS.ImbueRun() then
		return false
	end
	local dungeon = rawget(_G, "TheDungeon")
	local am = dungeon ~= nil and dungeon.progression ~= nil and dungeon.progression.components.ascensionmanager or nil
	if am ~= nil and (am:GetCurrentLevel() or 0) > (rawget(_G, "NORMAL_FRENZY_LEVELS") or 5) then
		return false -- (the game's own Super Frenzy: its handler did it)
	end
	local trek = dungeon ~= nil and dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek:IsActive() then
		return false
	end
	local hoard = inst ~= nil and inst.components ~= nil and inst.components.inventoryhoard or nil
	local weapon = hoard ~= nil and hoard:GetEquippedItem(weapon_slot) or nil
	if weapon == nil then
		return false
	end
	local def = weapon:GetDef()
	if weapon.boss_imbued or (def ~= nil and type(def.tags) == "table" and def.tags.superfrenzy) then
		return false
	end
	craftingutil.ChargeNormalWeapon(inst, boss)
	Log(string.format("Teffressence Container: imbued on the Super Frenzy %d side hunt's boss (%s)", SS.level or 0, tostring(def and def.name)))
	return true
end

-- Power: defs.powers; returns ok, info
function SS.InstallImbue(Power, craftingutil, Equipment)
	local items = type(Power) == "table" and type(Power.Items) == "table" and Power.Items.EQUIPMENT or nil
	local def = type(items) == "table" and items.gem_boss_soul or nil
	local triggers = type(def) == "table" and def.event_triggers or nil
	if type(triggers) ~= "table" or type(triggers.boss_kill) ~= "function" then
		return false, "the Teffressence Container on side hunts: the game's (gem_boss_soul's boss_kill not found)"
	end
	if type(craftingutil) ~= "table" or type(craftingutil.ChargeNormalWeapon) ~= "function" then
		return false, "the Teffressence Container on side hunts: the game's (craftingutil.ChargeNormalWeapon not found)"
	end
	local slot = type(Equipment) == "table" and type(Equipment.Slots) == "table" and Equipment.Slots.WEAPON or "WEAPON"
	if not rawget(triggers, "frenzylevels_imbue") then
		rawset(triggers, "frenzylevels_imbue", true)
		local orig = triggers.boss_kill
		triggers.boss_kill = function(pow, inst, boss, ...)
			local results = table.pack(orig(pow, inst, boss, ...))
			local ok, err = pcall(SS.SideImbue, pow, inst, boss, craftingutil, slot)
			if not ok then
				Log("error in the Teffressence Container on a side hunt: " .. tostring(err))
			end
			return table.unpack(results, 1, results.n)
		end
	end
	return true, "the Teffressence Container works on Super Frenzy side hunt bosses"
end

----------------------------------------------------------------------------
-- install

-- deps: { G (the game's globals), MapGenHelp, LootEvents, Consumable,
-- CraftingDropManager, AscensionManager, WorldMap, biomes }. Returns ok, info.
function SS.Install(fl, deps)
	FL = fl
	local c = FL.settings.super_side_hunts
	if not FL.SuperSideOn() and not FL.SuperMainOn() and not FL.SuperMainHardOn() then
		SS.info = "Super Frenzy side hunts off"
		return false, SS.info
	end
	SS.all_hard = type(c) == "table" and c.all_hard or false
	SS.teffra = type(c) == "table" and c.teffra == true
	SS.hard_power = FL.settings.hard_power_rooms ~= false
	SS.power_teffra = SS.hard_power and (tonumber(FL.settings.hard_power_room_teffra) or 0) or 0
	SS.playerutil = deps.playerutil
	local G = deps.G
	local missing = {}
	for _, name in ipairs({ "ResolveDungeonTier", "ResolveEnemyModifiers", "ResolveAscensionModifiers", "ResolveDestructibleModifiers", "ResolveTrapModifiers", "ResolveHuntModifiers" }) do
		if type(rawget(G, name)) ~= "function" then
			missing[#missing + 1] = name
		end
	end
	local AM, MGH, LE = deps.AscensionManager, deps.MapGenHelp, deps.LootEvents
	if type(AM) ~= "table" or type(AM._ActivateAscension) ~= "function" then
		missing[#missing + 1] = "AscensionManager:_ActivateAscension"
	end
	if type(MGH) ~= "table" or type(MGH.FixupRoom) ~= "function" then
		missing[#missing + 1] = "MapGenHelp.FixupRoom"
	end
	if type(LE) ~= "table" or type(LE.SpawnLootFromMaterials) ~= "function" or type(LE.HandleEventSpawnCurrency) ~= "function" then
		missing[#missing + 1] = "LootEvents"
	end
	if #missing > 0 then
		SS.info = "Super Frenzy side hunts off (the game changed: " .. table.concat(missing, ", ") .. ")"
		return false, SS.info
	end
	if rawget(G, "frenzylevels_superside") then
		return true, SS.info
	end
	rawset(G, "frenzylevels_superside", true)

	-- the run: told in every room (a run continued after a quit too) and at
	-- its start, before the players' start of run (the start damage) and the
	-- first doors
	local orig_activate = AM._ActivateAscension
	AM._ActivateAscension = function(self, level, location_id, ...)
		local ok, err = pcall(function()
			local dungeon = rawget(G, "TheDungeon")
			local map = dungeon ~= nil and dungeon:GetDungeonMap() or nil
			local loc = location_id or (map ~= nil and map:GetBiomeLocation().id) or nil
			local weather = map ~= nil and map.data ~= nil and map.data.is_weather_enabled or false
			local trek = dungeon ~= nil and dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
			local in_trek = trek ~= nil and trek:IsActive()
			SS.SetRun(not in_trek and SS.SuperSideLevel(loc, level, weather, deps.biomes) or nil, loc, weather)
			SS.SetMain(level, loc, in_trek, deps.biomes)
		end)
		if not ok then
			Log("error in Super Frenzy side hunt check: " .. tostring(err))
			SS.SetRun(nil)
			SS.main = false
		end
		return orig_activate(self, level, location_id, ...)
	end
	local WM = deps.WorldMap
	local early = type(WM) == "table" and type(WM.StartRun) == "function"
	if early then
		local orig_start = WM.StartRun
		WM.StartRun = function(self, dungeon_run_params, ...)
			local ok, err = pcall(SS.OnStartRun, dungeon_run_params, deps.biomes)
			if not ok then
				Log("error in Super Frenzy side hunt start: " .. tostring(err))
				SS.SetRun(nil)
			end
			return orig_start(self, dungeon_run_params, ...)
		end
	end
	SS.early_start = early
	if type(AM.CompleteCurrentAscension) == "function" then
		local orig_complete = AM.CompleteCurrentAscension
		AM.CompleteCurrentAscension = function(self, ...)
			local ok, err = pcall(SS.OnVictory)
			if not ok then
				Log("error recording a Super Frenzy clear: " .. tostring(err))
			end
			return orig_complete(self, ...)
		end
	end

	G.ResolveDungeonTier = SS.WrapDungeonTier(G.ResolveDungeonTier)
	G.ResolveEnemyModifiers = SS.WrapLifted(G.ResolveEnemyModifiers)
	G.ResolveDestructibleModifiers = SS.WrapLifted(G.ResolveDestructibleModifiers)
	G.ResolveTrapModifiers = SS.WrapLifted(G.ResolveTrapModifiers)
	G.ResolveHuntModifiers = SS.WrapLifted(G.ResolveHuntModifiers)
	G.ResolveAscensionModifiers = SS.WrapLifted(G.ResolveAscensionModifiers, SS.NoEliteBoss)
	local boss_loot = type(rawget(G, "ResolveLootModifiers")) == "function"
	if boss_loot then
		G.ResolveLootModifiers = SS.WrapLoot(G.ResolveLootModifiers)
	end
	SS.G = G
	MGH.FixupRoom = SS.WrapFixup(MGH.FixupRoom)
	LE.SpawnLootFromMaterials = SS.WrapSpawnLoot(LE.SpawnLootFromMaterials, deps.Consumable)
	LE.HandleEventSpawnCurrency = SS.WrapCurrency(LE.HandleEventSpawnCurrency)
	local CDM = deps.CraftingDropManager
	local corestones = type(CDM) == "table" and type(CDM.GetSoulDropCount) == "function"
	if corestones then
		CDM.GetSoulDropCount = SS.WrapSoulCount(CDM.GetSoulDropCount)
	end
	-- (0.10.0) the hard weapon power / gift rooms' Teffra
	local KRM = deps.KonjurRewardManager
	local budget = SS.power_teffra > 0 and type(KRM) == "table" and type(KRM.SetBasicKonjurBudget) == "function"
	if budget then
		KRM.SetBasicKonjurBudget = SS.WrapBudget(KRM.SetBasicKonjurBudget)
	end
	-- (0.11.3) the Teffressence Container on Super Frenzy side hunt bosses
	local imbue_ok, imbue_info = false, nil
	if FL.SuperSideOn() and type(c) == "table" and type(c.imbue_gem) == "number" then
		local ok_i, a, b = pcall(SS.InstallImbue, deps.Power, deps.craftingutil, deps.Equipment)
		imbue_ok, imbue_info = ok_i and a, ok_i and b or ("the Teffressence Container on side hunts: the game's (" .. tostring(a) .. ")")
	end
	local function List(l)
		local t = {}
		for i, v in ipairs(l) do
			t[i] = tostring(v)
		end
		return table.concat(t, "/")
	end
	local parts = {}
	if FL.SuperSideOn() then
		parts[#parts + 1] = string.format("Super Frenzy side hunts 1-5 (RB past Frenzy 5; %s%s): the game's Super Frenzy levels, %s, loot x%s%s",
			c.unlock_all and "all open" or "each opens when the one below is cleared", FL.WeatherSuperOn() and "; weather side hunts too, their meter's rewards x the loot" or "",
			SS.all_hard and "every fight room hard" or "the game's hard rooms", List(c.loot), SS.teffra and " (Teffra too)" or " (not Teffra)")
	else
		parts[#parts + 1] = "Super Frenzy side hunts off"
	end
	local m = FL.settings.super_main_loot
	if type(m) == "table" then
		parts[#parts + 1] = string.format("Super Frenzy main hunts: loot x%s%s", List(m.loot), m.teffra and " (Teffra too)" or " (not Teffra)")
	end
	local h = FL.settings.super_main_hard
	if type(h) == "table" then
		parts[#parts + 1] = string.format("Super Frenzy main hunts: more hard rooms by party gear level (above %d, to %d) and level (every fight room hard at the top)", h.gear_from, h.gear_max)
	end
	parts[#parts + 1] = SS.hard_power and string.format("weapon power / gift rooms made hard: %s", budget and ("+" .. SS.power_teffra .. " Teffra") or (SS.power_teffra > 0 and "no extra Teffra (KonjurRewardManager not found)" or "no extra Teffra"))
		or "weapon power / gift rooms: never hard (the game's)"
	SS.info = table.concat(parts, "; ") .. (corestones and "" or " (not Corestones: CraftingDropManager not found)")
		.. ((FL.SuperSideOn() and c.boss_like_main) and (boss_loot and ", the side boss's Corestones / ingots as a Super Frenzy main boss's" or " (the side boss's loot as Frenzy 5's: ResolveLootModifiers not found)") or "")
		.. (early and "" or " (the start damage only from the first room: WorldMap:StartRun not found)")
		.. (imbue_info ~= nil and ("; " .. (imbue_ok and (imbue_info .. " (SF" .. c.imbue_gem .. (c.imbue_gem < 5 and "+" or "") .. ")") or imbue_info)) or "")
	return true, SS.info
end

-- the run's start (WorldMap:StartRun, before the players' and the dungeon's
-- "start_new_run" and before the first doors; TheDungeon's start_new_run
-- event too, when StartRun couldn't be hooked)
function SS.OnStartRun(params, biomes)
	if type(params) ~= "table" then
		return SS.SetRun(nil)
	end
	local level = params.ascension
	if level == nil and FL ~= nil and FL.AM() ~= nil and params.location_id ~= nil then
		level = FL.AM():GetSelectedAscension(params.location_id)
	end
	local trek = params.trek_params ~= nil or params.is_trek == true
	local side = SS.SetRun(not trek and SS.SuperSideLevel(params.location_id, level, params.is_weather_enabled == true, biomes) or nil, params.location_id, params.is_weather_enabled == true)
	SS.SetMain(level, params.location_id, trek, biomes)
	return side
end

return SS
