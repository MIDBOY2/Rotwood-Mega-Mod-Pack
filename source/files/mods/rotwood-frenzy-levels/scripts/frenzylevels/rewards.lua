-- Frenzy Levels: more for the harder choices (0.9.0). Nothing is taken away:
-- every level keeps what the game gives it, the harder ones get more.
--
--  * Weather side hunts at Frenzy 5 (weather_bonus): the game picks a side
--    hunt's weather level 1 to 4; Frenzy Levels lets you raise it to 5. Then
--    each tier of the weather meter you reach gives one more reward, drawn
--    from that tier's own bag (the game's WeatherForecast:PickReward: gems,
--    Heart Shards, ingots, materials, seeds; the top tier a gem seed too),
--    delivered the game's way (the Teffrometer, its notification).
--    0.10.0: a weather side hunt at Super Frenzy 1 to 5 (superside.lua): each
--    tier reached gives Frenzy 5's rewards (the game's 1 / 2 / 3 + weather_bonus's
--    one) x the Super Frenzy loot multiplier (rounded at random, the average
--    exact: tier 2's 3 x 1.5 = 4.5, x 2.5 = 7.5), every one drawn from that
--    tier's bag, so gems and Heart Shards too. Inside those rewards the loot multiplier stays out
--    (the count is what's multiplied, not each reward's ingots or materials).
--  * Nimble's challenges at Frenzy 5 and Super Frenzy (nimble_bonus): both
--    challenges done in one run: at the final market, on top of his Heart
--    Shards, a power upgrade, a reroll and an extra life. That's the game's
--    own bonus for it (components/marketchallengereward.lua, switched off in
--    the game: "If we completed both challenges at the same time spawn a
--    bonus reward"), the game's pickups.
--  * Side hunts you frenzy yourself, Frenzy 1 to 5 (side_boss_bonus): the boss
--    gives each hunter more of the area's ingots (in the boss's own loot) and
--    a few of the area's materials (the game's materials room roll), on top of
--    the extra Corestones (corestone_bonus). Not the anomalies (they have the
--    weather meter) or Super Frenzy side hunts.
--  * Main hunts at Super Frenzy, a repeat clear (super_main_shards): the boss
--    gives each hunter who doesn't get the boss's Imbued Heartstone this time
--    (a level that weapon already cleared there: the game's own test,
--    AscensionManager:GetLevelCompletionResult) Heart Shards, in the boss's
--    own loot. A fixed number: the Super Frenzy main loot multiplier leaves a
--    boss's Heart Shards alone (superside.lua SS.FixedShards).
-- Each part checks the game's functions first and stays out (the game's way)
-- if one is missing; an error inside is logged and the game's own reward
-- goes on. Zero cost elsewhere: each hook is a check of the run's kind.
local FR = {}

local FL -- frenzylevels.lua (FR.Init)

FR.DEFAULTS = {
	weather_bonus = { 0, 0, 0, 0, 1 },
	nimble_bonus = { min_level = 5, upgrade = 1, reroll = 1, extra_life = 1 },
	side_boss_bonus = { ingots = { 1, 1, 2, 2, 3 }, materials = { 2, 3, 4, 5, 6 } },
	super_main_shards = { 1, 1, 2, 2, 3 },
}

FR.NIMBLE = {
	{ key = "upgrade", prefab = "relic_upgrade_single", fn = "SpawnPowerUpgrade", name = "power upgrade" },
	{ key = "reroll", prefab = "power_reroll_pickup_single", fn = "SpawnPowerReroll", name = "reroll" },
	{ key = "extra_life", prefab = "extra_life_pickup_single", fn = "SpawnExtraLife", name = "extra life" },
}

FR.SHARD = "konjur_heart_shard"
FR.given = {}   -- [room key .. player] = true (a boss room's bonus, once)
FR.room = nil   -- the room the memory is for
FR.deps = {}
FR.parts = {}   -- part name -> installed

local errors = {} -- [where] = count (the first 5 of each are logged)

local function Log(msg)
	print((FL ~= nil and FL.TAG or "[Frenzy Levels]") .. " " .. msg)
end

local function Err(where, err)
	local n = errors[where] or 0
	if n < 5 then
		errors[where] = n + 1
		Log("error in " .. where .. ": " .. tostring(err))
	end
end
FR.Err = Err

function FR.Init(fl)
	FL = fl
end

----------------------------------------------------------------------------
-- settings

-- 5 numbers (Frenzy 1 to 5, or Super Frenzy 1 to 5), or one for all; whole
-- numbers lo..hi. false = off.
local function Five(v, default, lo, hi)
	if v == false then
		return false
	end
	local one = tonumber(v)
	local out = {}
	for i = 1, 5 do
		local x = one or (type(v) == "table" and tonumber(v[i])) or default[i]
		out[i] = math.max(lo, math.min(hi, math.floor(x)))
	end
	return out
end
FR.Five = Five

local function Count(v, default, lo, hi)
	local x = tonumber(v) or default
	return math.max(lo, math.min(hi, math.floor(x)))
end

function FR.Configure(s)
	local D = FR.DEFAULTS
	s.weather_bonus = Five(s.weather_bonus, D.weather_bonus, 0, 5)
	local n = s.nimble_bonus
	if n == false or (type(n) == "table" and n.enabled == false) then
		s.nimble_bonus = false
	else
		n = type(n) == "table" and n or {}
		s.nimble_bonus = {
			min_level = Count(n.min_level, D.nimble_bonus.min_level, 1, 10),
			upgrade = Count(n.upgrade, 1, 0, 3),
			reroll = Count(n.reroll, 1, 0, 3),
			extra_life = Count(n.extra_life, 1, 0, 3),
		}
	end
	local b = s.side_boss_bonus
	if b == false or (type(b) == "table" and b.enabled == false) then
		s.side_boss_bonus = false
	else
		b = type(b) == "table" and b or {}
		s.side_boss_bonus = {
			ingots = Five(b.ingots, D.side_boss_bonus.ingots, 0, 20) or { 0, 0, 0, 0, 0 },
			materials = Five(b.materials, D.side_boss_bonus.materials, 0, 30) or { 0, 0, 0, 0, 0 },
		}
	end
	s.super_main_shards = Five(s.super_main_shards, D.super_main_shards, 0, 10)
	return s
end

local function Any(list)
	if type(list) ~= "table" then
		return false
	end
	for _, v in ipairs(list) do
		if v > 0 then
			return true
		end
	end
	return false
end
FR.Any = Any

local function List(l)
	local t = {}
	for i, v in ipairs(l) do
		t[i] = tostring(v)
	end
	return table.concat(t, "/")
end

----------------------------------------------------------------------------
-- the run

local function Dungeon()
	return rawget(_G, "TheDungeon")
end

local function InTrek()
	local d = Dungeon()
	local ok, active = pcall(function()
		local trek = d:GetTrek()
		return trek ~= nil and trek:IsActive()
	end)
	return ok and active == true
end

local function Level()
	local am = FL ~= nil and FL.AM() or nil
	local ok, level = pcall(function() return am:GetCurrentLevel() end)
	return ok and type(level) == "number" and level or 0
end

-- The run: "weather" (a side hunt with weather, Frenzy 1-5), "side" (a side
-- hunt you frenzied yourself, Frenzy 1-5), "super_side" (Frenzy Levels'
-- Super Frenzy side hunt), "main" (a main hunt, Frenzy 1-5), "super_main" (a
-- main hunt at Super Frenzy), or nil (no frenzy, the Blight, unknown); and
-- the level (1-5).
function FR.RunKind()
	if FL == nil or InTrek() then
		return nil
	end
	local level = Level()
	if level < 1 then
		return nil
	end
	local d = Dungeon()
	local ok, loc, weather = pcall(function()
		local map = d:GetDungeonMap()
		return d:GetCurrentLocationID(), map ~= nil and map.data ~= nil and map.data.is_weather_enabled == true
	end)
	local biomes = FR.deps.biomes
	if not ok or type(loc) ~= "string" or type(biomes) ~= "table" or type(biomes.IsSublocation) ~= "function" then
		return nil
	end
	local top = FL.SuperLevel() - 1
	if biomes.IsSublocation(loc) == true then
		if FL.SS ~= nil and FL.SS.run then
			return "super_side", FL.SS.level
		end
		if level > top then
			return nil
		end
		return weather and "weather" or "side", level
	end
	if level > top then
		return "super_main", math.min(level - top, 5)
	end
	return "main", level
end

----------------------------------------------------------------------------
-- weather side hunts at Frenzy 5

-- (0.10.0) a weather side hunt at Super Frenzy: this run's Super Frenzy part
local function WeatherSuper()
	local SS = FL ~= nil and FL.SS or nil
	return SS ~= nil and SS.run == true and SS.weather == true and SS or nil
end
FR.WeatherSuper = WeatherSuper

-- (0.10.0) a tier's extra rewards at Super Frenzy: Frenzy 5's count (the
-- game's n for that tier + weather_bonus's) x the loot multiplier, rounded at
-- random, less the game's n (which the game gives itself)
function FR.WeatherSuperExtra(n, rand)
	local SS = WeatherSuper()
	n = math.max(0, math.floor(tonumber(n) or 1))
	if SS == nil then
		return 0
	end
	local list = FL.settings.weather_bonus
	local base = n + (type(list) == "table" and (list[#list] or 0) or 0)
	local total = SS.Scale(base, rand)
	return math.max(0, (tonumber(total) or base) - n)
end

-- extra rewards for each meter tier reached now (0: none)
function FR.WeatherExtra()
	local list = FL ~= nil and FL.settings.weather_bonus or nil
	if type(list) ~= "table" then
		return 0
	end
	local kind, level = FR.RunKind()
	if kind ~= "weather" then
		return 0
	end
	return list[level] or 0
end

-- One tier's extra rewards, the game's way (WeatherManager:CheckRewardProgress:
-- each local hunter with the Teffrometer, its tick, its notification).
function FR.GiveWeatherExtra(wm, tier, count)
	local d = Dungeon()
	local forecast = d.progression.components.weatherforecast
	local deps = FR.deps
	local pu, WR, tef = deps.playerutil, deps.WeatherRewards, deps.Teffrometer
	local given = {}
	for _ = 1, count do
		local id = forecast:PickReward(tier)
		local def = id ~= nil and WR[id] or nil
		if type(def) == "table" and type(def.fn) == "function" then
			local shown = false
			pu.DoForAllLocalPlayers(function(player)
				if player:IsValid() and pu.PlayerHasKeyItem(player, tef) then
					local psh = deps.ParticleSystemHelper
					if psh ~= nil and type(psh.MakeOneShotAtPosition) == "function" then
						pcall(psh.MakeOneShotAtPosition, player:GetPosition(), "teffrometer_tick" .. tier, 3, player)
					end
					local ok, err = pcall(def.fn, player)
					if ok then
						shown = true
						player:PushEvent("weather_reward", { reward_id = id, current_xp = wm.persist_data ~= nil and wm.persist_data.xp or nil })
					else
						Err("the Frenzy 5 weather reward", err)
					end
				end
			end)
			if shown then
				given[#given + 1] = tostring(id)
				pcall(function()
					local S = rawget(_G, "STRINGS")
					local fe = rawget(_G, "TheFrontEnd")
					local body = string.format(S.WEATHER.REWARD_NOTIFICATION_BODY, def.name.name, tier)
					fe:ShowTextNotification(tef.icon, S.WEATHER.REWARD_NOTIFICATION_TITLE, body, 10)
				end)
			end
		end
	end
	if #given > 0 then
		local SS = WeatherSuper()
		Log(string.format("%s weather: the meter's tier %d, +%s", SS ~= nil and ("Super Frenzy " .. tostring(SS.level)) or "Frenzy 5", tier, table.concat(given, ", ")))
	end
	return #given
end

function FR.InstallWeather(WM, deps)
	local super = FL.WeatherSuperOn ~= nil and FL.WeatherSuperOn()
	if not Any(FL.settings.weather_bonus) and not super then
		return false, "off"
	end
	if type(WM) ~= "table" or type(WM.CheckRewardProgress) ~= "function" then
		return false, "a game update changed WeatherManager (the weather meter)"
	end
	local pu, WR = deps.playerutil, deps.WeatherRewards
	local C = deps.Consumable
	local tef = type(C) == "table" and C.Items ~= nil and C.Items.KEY_ITEMS ~= nil and C.Items.KEY_ITEMS.teffrometer or nil
	if type(pu) ~= "table" or type(pu.DoForAllLocalPlayers) ~= "function" or type(pu.PlayerHasKeyItem) ~= "function"
		or type(WR) ~= "table" or tef == nil then
		return false, "a game update changed the weather rewards"
	end
	deps.Teffrometer = tef
	if not rawget(WM, "frenzylevels_weather") then
		rawset(WM, "frenzylevels_weather", true)
		local orig = WM.CheckRewardProgress
		WM.CheckRewardProgress = function(self, rewards, ...)
			local extra, before = 0, nil
			local SS = WeatherSuper() -- (0.10.0) Super Frenzy: the count x the loot multiplier
			if type(rewards) == "table" then
				local ok, n = true, nil
				if SS ~= nil then
					n = 1 -- (worked out for each tier below)
				else
					ok, n = pcall(FR.WeatherExtra)
				end
				if not ok then
					Err("the Frenzy 5 weather reward", n)
				elseif n > 0 then
					extra, before = n, {}
					local claimed = type(self.persist_data) == "table" and self.persist_data.rewards_claimed or {}
					for i = 1, #rewards do
						before[i] = claimed[i] == true
					end
				end
			end
			if SS ~= nil then
				SS.hold = SS.hold + 1
			end
			local r = table.pack(pcall(orig, self, rewards, ...))
			if before ~= nil and r[1] then
				local claimed = type(self.persist_data) == "table" and self.persist_data.rewards_claimed or {}
				for i = 1, #rewards do
					if not before[i] and claimed[i] then
						local count = extra
						if SS ~= nil then
							local okx, x = pcall(FR.WeatherSuperExtra, type(rewards[i]) == "table" and type(rewards[i].rewards) == "table" and #rewards[i].rewards or 1)
							count = okx and x or 0
							if not okx then
								Err("the Super Frenzy weather reward", x)
							end
						end
						if count > 0 then
							local ok, err = pcall(FR.GiveWeatherExtra, self, i, count)
							if not ok then
								Err("the Frenzy 5 weather reward", err)
							end
						end
					end
				end
			end
			if SS ~= nil then
				SS.hold = math.max(0, SS.hold - 1)
			end
			if not r[1] then
				error(r[2], 0)
			end
			return table.unpack(r, 2, r.n)
		end
	end
	return true, (Any(FL.settings.weather_bonus) and ("weather side hunts: +" .. List(FL.settings.weather_bonus) .. " from each meter tier (Frenzy 1-5)") or "weather side hunts: the game's meter (Frenzy 1-5)")
		.. (super and "; at Super Frenzy: each tier's rewards x the loot multiplier (gems and Heart Shards too)" or "")
end

----------------------------------------------------------------------------
-- Nimble's challenges: both in one run at Frenzy 5 and Super Frenzy

-- the challenges this hunter claims now, when the bonus applies (else 0)
function FR.NimbleCount(reward, player)
	local c = FL ~= nil and FL.settings.nimble_bonus or nil
	if type(c) ~= "table" or InTrek() or Level() < c.min_level then
		return 0
	end
	local list = reward:GetClaimableResults(player)
	return type(list) == "table" and #list or 0
end

function FR.GiveNimbleBonus(player)
	local c = FL.settings.nimble_bonus
	local ru, su = FR.deps.rewardutil, FR.deps.spawnutil
	local exists = rawget(_G, "PrefabExists")
	local pickups, got = {}, {}
	for _, e in ipairs(FR.NIMBLE) do
		for _ = 1, c[e.key] or 0 do
			if type(exists) ~= "function" or exists(e.prefab) then
				local ok, p = pcall(ru[e.fn], player)
				if ok and p ~= nil then
					pickups[#pickups + 1] = p
					got[#got + 1] = e.name
				elseif not ok then
					Err("Nimble's bonus", p)
				end
			end
		end
	end
	if #pickups > 0 and type(su) == "table" and type(su.RepositionPickups) == "function" then
		pcall(su.RepositionPickups, pickups, { base_pos = player:GetPosition(), radius = 3, spacing = 1 })
	end
	Log("Nimble's challenges, both done: " .. (#got > 0 and table.concat(got, ", ") or "nothing (the pickups aren't loaded here)"))
	return #pickups
end

function FR.InstallNimble(MCR, deps)
	local c = FL.settings.nimble_bonus
	if type(c) ~= "table" or c.upgrade + c.reroll + c.extra_life <= 0 then
		return false, "off"
	end
	if type(MCR) ~= "table" or type(MCR.OnClaim) ~= "function" or type(MCR.GetClaimableResults) ~= "function" then
		return false, "a game update changed Nimble's reward chest"
	end
	local ru = deps.rewardutil
	if type(ru) ~= "table" or type(ru.SpawnPowerUpgrade) ~= "function" or type(ru.SpawnPowerReroll) ~= "function" or type(ru.SpawnExtraLife) ~= "function" then
		return false, "a game update changed the reward pickups"
	end
	if not rawget(MCR, "frenzylevels_nimble") then
		rawset(MCR, "frenzylevels_nimble", true)
		local orig = MCR.OnClaim
		MCR.OnClaim = function(self, player, ...)
			local ok, n = pcall(FR.NimbleCount, self, player)
			if not ok then
				Err("Nimble's bonus", n)
				n = 0
			end
			local r = table.pack(orig(self, player, ...))
			if n >= 2 then
				local okb, err = pcall(FR.GiveNimbleBonus, player)
				if not okb then
					Err("Nimble's bonus", err)
				end
			end
			return table.unpack(r, 1, r.n)
		end
	end
	local what = {}
	for _, e in ipairs(FR.NIMBLE) do
		if c[e.key] > 0 then
			what[#what + 1] = (c[e.key] > 1 and (c[e.key] .. " ") or "") .. e.name .. (c[e.key] > 1 and "s" or "")
		end
	end
	return true, string.format("Nimble's two challenges in one run from %s: %s", c.min_level > 5 and ("Super Frenzy " .. (c.min_level - 5)) or ("Frenzy " .. c.min_level),
		table.concat(what, ", "))
end

----------------------------------------------------------------------------
-- the boss: side hunts you frenzied yourself, Super Frenzy main hunts

local function RoomKey()
	local d = Dungeon()
	local ok, id, seed = pcall(function()
		local wm = d:GetDungeonMap()
		return wm:GetCurrentRoomId(), wm:GetCurrentRoomSeed()
	end)
	if not ok then
		return nil
	end
	return tostring(seed) .. "/" .. tostring(id)
end

local function InBossRoom()
	local w = rawget(_G, "TheWorld")
	local ok, rt = pcall(function() return w:GetCurrentRoomType() end)
	return ok and rt == "boss"
end

-- Can this item drop as loot here (the game spawns "drop_<id>")? (0.9.1:
-- Hunt Rooms 0.3.0 crashed on a Corestone, which has no loot drop.)
function FR.CanDrop(id)
	local exists = rawget(_G, "PrefabExists")
	if type(exists) ~= "function" or type(id) ~= "string" then
		return false
	end
	local ok, yes = pcall(exists, "drop_" .. id)
	return ok and yes == true
end

-- Give an item straight to the hunter, the way the game's pickups do
-- (player:PushEvent("get_loot")). Returns true when given.
function FR.GiveDirect(player, id, n)
	local C = FR.deps.Consumable
	if n <= 0 or type(C) ~= "table" or type(C.FindItem) ~= "function" or player == nil or player.PushEvent == nil then
		return false
	end
	local ok, def = pcall(C.FindItem, id)
	if not ok or def == nil then
		return false
	end
	player:PushEvent("get_loot", { item = def, count = n })
	return true
end

local function HasLocationLoot()
	local d = Dungeon()
	local ok, loc = pcall(function() return d:GetDungeonMap():GetBiomeLocation() end)
	return not (ok and type(loc) == "table" and loc.no_location_loot)
end

-- Does this hunter get the boss's heart (an Imbued Heartstone) this time?
-- (the game's own test; anything wrong: yes, so no Heart Shards)
function FR.GetsHeart(player)
	local am = FL.AM()
	local ok, result = pcall(function() return am:GetLevelCompletionResult(player) end)
	if not ok or type(result) ~= "table" then
		return true
	end
	return result.heart == true
end

-- After the game's own OnLootDropperDeath (one call per local hunter).
-- Returns true when it added loot.
function FR.OnBossDeath(manager, ent)
	if not InBossRoom() then
		return false
	end
	local s = FL.settings
	local kind, level = FR.RunKind()
	local ingots, materials, shards = 0, 0, 0
	if kind == "side" and type(s.side_boss_bonus) == "table" then
		ingots = s.side_boss_bonus.ingots[level] or 0
		materials = s.side_boss_bonus.materials[level] or 0
	elseif kind == "super_main" and type(s.super_main_shards) == "table" then
		shards = s.super_main_shards[level] or 0
	end
	if ingots + materials + shards <= 0 then
		return false
	end
	local player = manager.inst
	local key = RoomKey()
	if player == nil or key == nil then
		return false
	end
	if FR.room ~= key then
		FR.room, FR.given = key, {}
	end
	local pkey = tostring(player.GUID or player)
	if FR.given[pkey] then
		return false -- (once per boss room)
	end
	if shards > 0 and FR.GetsHeart(player) then
		shards = 0 -- (the first clear: the game's Imbued Heartstone)
	end
	FR.given[pkey] = true
	local LE = FR.deps.LootEvents
	local loot = {}
	local has_loot = HasLocationLoot()
	if ingots > 0 and has_loot then
		local ok, ingot = pcall(LE.GetIngotForCurrentLocation)
		if ok and type(ingot) == "string" and FR.CanDrop(ingot) then
			loot[ingot] = ingots
		elseif not (ok and type(ingot) == "string" and FR.GiveDirect(player, ingot, ingots)) then
			ingots = 0
		end
	else
		ingots = 0
	end
	if shards > 0 then
		if FR.CanDrop(FR.SHARD) then
			loot[FR.SHARD] = shards
		elseif not FR.GiveDirect(player, FR.SHARD, shards) then
			shards = 0
		end
	end
	local added = false
	local ld = ent.components ~= nil and ent.components.lootdropper or nil
	if next(loot) ~= nil and ld ~= nil then
		if type(ld.loot_to_drop) == "table" then
			-- added to what the game already has for this hunter (counts summed)
			local mine = ld.loot_to_drop[player]
			if type(mine) ~= "table" then
				mine = {}
				ld.loot_to_drop[player] = mine
			end
			for id, c in pairs(loot) do
				mine[id] = (mine[id] or 0) + c
			end
			added = true
		elseif type(ld.AddLootToDrop) == "function" then
			ld:AddLootToDrop(player, loot)
			added = true
		end
	end
	if materials > 0 and has_loot then
		LE.SpawnRandomLootForCurrentLocation(ent, { player }, materials)
	else
		materials = 0
	end
	if kind == "side" then
		Log(string.format("Frenzy %d side hunt boss: +%d ingots, +%d materials", level, ingots, materials))
	elseif shards > 0 then
		Log(string.format("Super Frenzy %d boss, a repeat clear: +%d Heart Shards", level, shards))
	end
	return added
end

function FR.InstallBoss(LDM, deps)
	local s = FL.settings
	local side = type(s.side_boss_bonus) == "table" and (Any(s.side_boss_bonus.ingots) or Any(s.side_boss_bonus.materials))
	local main = Any(s.super_main_shards)
	if not side and not main then
		return false, "off"
	end
	if type(LDM) ~= "table" or type(LDM.OnLootDropperDeath) ~= "function" then
		return false, "a game update changed LootDropManager (the boss's loot)"
	end
	local LE = deps.LootEvents
	if type(LE) ~= "table" or type(LE.GetIngotForCurrentLocation) ~= "function" or type(LE.SpawnRandomLootForCurrentLocation) ~= "function" then
		return false, "a game update changed LootEvents (the boss's loot)"
	end
	if not rawget(LDM, "frenzylevels_boss") then
		rawset(LDM, "frenzylevels_boss", true)
		local orig = LDM.OnLootDropperDeath
		LDM.OnLootDropperDeath = function(self, ent, ...)
			local r = table.pack(orig(self, ent, ...))
			if type(ent) == "table" and ent.HasTag ~= nil and ent:HasTag("boss") then
				local ok, added = pcall(FR.OnBossDeath, self, ent)
				if not ok then
					Err("the boss's extra loot", added)
				elseif added and not r[1] then
					r[1] = true -- (the game sends this hunter's loot to the others)
				end
			end
			return table.unpack(r, 1, r.n)
		end
	end
	local parts = {}
	if side then
		parts[#parts + 1] = string.format("side hunts you frenzy yourself: the boss +%s ingots, +%s materials", List(s.side_boss_bonus.ingots), List(s.side_boss_bonus.materials))
	end
	if main then
		parts[#parts + 1] = string.format("Super Frenzy main hunts, repeat clears: the boss +%s Heart Shards", List(s.super_main_shards))
	end
	return true, table.concat(parts, "; ")
end

----------------------------------------------------------------------------
-- install: each part by itself. deps: { WeatherManager, WeatherRewards,
-- playerutil, Consumable, ParticleSystemHelper, MarketChallengeReward,
-- rewardutil, spawnutil, LootDropManager, LootEvents, biomes }.
-- Returns ok (any part in), info.
function FR.Install(fl, deps)
	FL = fl
	deps = type(deps) == "table" and deps or {}
	FR.deps = deps
	if type(deps.biomes) ~= "table" or type(deps.biomes.IsSublocation) ~= "function" then
		return false, "the game's rewards (defs.biomes not found)"
	end
	local out, any = {}, false
	local function Part(name, fn, ...)
		local ok, p_ok, info = pcall(fn, ...)
		FR.parts[name] = ok and p_ok == true
		if FR.parts[name] then
			any = true
			out[#out + 1] = info
		elseif not ok then
			out[#out + 1] = name .. ": the game's (" .. tostring(p_ok) .. ")"
		elseif info ~= "off" then
			out[#out + 1] = name .. ": the game's (" .. tostring(info) .. ")"
		end
	end
	Part("weather", FR.InstallWeather, deps.WeatherManager, deps)
	Part("Nimble", FR.InstallNimble, deps.MarketChallengeReward, deps)
	Part("boss", FR.InstallBoss, deps.LootDropManager, deps)
	return any, #out > 0 and table.concat(out, "; ") or "the game's rewards"
end

return FR
