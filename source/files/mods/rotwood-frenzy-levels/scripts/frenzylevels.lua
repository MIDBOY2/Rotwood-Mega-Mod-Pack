-- Frenzy Levels (Rotwood build 760548)
--
-- The game has five normal Frenzy levels (defs/modifiers/modulators/
-- ascension_levels.lua: each adds enemy health, faster attacks, more elites,
-- more ingots / corestones). The map used to have a picker for them
-- (widgets/ftf/dungeonselection/frenzyselectionwidget.lua, unused now, and
-- AscensionManager:GetMaxAllowedLevelForPlayer returns 0); now a frenzied main
-- hunt is always Frenzy 5 (MapSidebar:SetFrenzyMode / GetFrenzyLevel), and
-- only the anomalies (sublocations) get 1 to 4, from your hearts.
--
-- This brings the choice back for main hunts: in the side panel's Frenzy mode
-- the bumpers (LB / RB, keyboard Q / E: the game's MENU_TAB_PREV / NEXT,
-- which only worked for the Super Frenzy picker) change the level. The run
-- uses it like any frenzy (the game reads the stored level when the run
-- starts: RoomLoader.RequestRun / AscensionManager:_GetDesiredLevel).
-- Side hunts (the smaller hunts around a main one) get the same picker: No
-- frenzy to 5 (the game: frenzy only with weather, 1-4 by hearts).
-- The choice is kept per hunt in the game's own save table
-- (ascensionmanager.persistdata.last_selected, key "frenzylevels_<hunt>").
local FL = {}
FL.TAG = "[Frenzy Levels]"
FL.KEY = "frenzylevels_"
FL.settings = { enabled = true, min_level = 1, default_level = 5, show_in_title = true, side_hunts = true,
	frenzy_look = true, super_frenzy_look = true,
	cosmetic_chance = { frenzy = { 10, 20, 30, 40, 100 }, super_frenzy = { 100, 100, 100, 100, 100 } },
	corestone_bonus = { boss = { 1, 1, 2, 2, 3 }, rooms = { 1, 1, 1, 2, 2 }, hunts = "frenzied_side" },
	drakin_rewards = { pieces = 4, during_quest = true, weapons = true },
	blight_mirages = true,
	super_side_hunts = { enabled = true, loot = { 1.5, 1.75, 2, 2.25, 2.5 }, teffra = false, all_hard = true, unlock_all = true, boss_like_main = true, imbue_gem = 5 },
	super_main_loot = { loot = { 1.5, 1.75, 2, 2.25, 2.5 }, teffra = false },
	weather_bonus = { 0, 0, 0, 0, 1 },
	nimble_bonus = { min_level = 5, upgrade = 1, reroll = 1, extra_life = 1 },
	side_boss_bonus = { ingots = { 1, 1, 2, 2, 3 }, materials = { 2, 3, 4, 5, 6 } },
	super_main_shards = { 1, 1, 2, 2, 3 },
	super_skip = { unlock = "any_hunt", both_weapons = true } }

local NORMAL_MAX = 5
local SUPER_COUNT = 5 -- the game's Super Frenzy levels (SUPER_FRENZY_LEVELS)
local errors = 0

local function Log(msg)
	print(FL.TAG .. " " .. msg)
end

local function Err(where, err)
	if errors < 5 then
		errors = errors + 1
		Log("error in " .. where .. ": " .. tostring(err))
	end
end

function FL.Configure(settings)
	settings = type(settings) == "table" and settings or {}
	local s = {}
	for k, v in pairs(FL.settings) do
		s[k] = v
	end
	for k, v in pairs(settings) do
		s[k] = v
	end
	NORMAL_MAX = rawget(_G, "NORMAL_FRENZY_LEVELS") or 5
	SUPER_COUNT = rawget(_G, "SUPER_FRENZY_LEVELS") or 5
	local function Level(v, default)
		v = type(v) == "number" and math.floor(v) or default
		return math.max(0, math.min(NORMAL_MAX, v))
	end
	s.min_level = Level(s.min_level, 1)
	s.default_level = math.max(s.min_level, Level(s.default_level, NORMAL_MAX))
	s.cosmetic_chance = FL.CosmeticSettings(s.cosmetic_chance)
	s.corestone_bonus = FL.CorestoneSettings(s.corestone_bonus)
	s.drakin_rewards = FL.DrakinSettings(s.drakin_rewards)
	s.super_side_hunts = FL.SuperSideSettings(s.super_side_hunts)
	s.super_main_loot = FL.SuperMainSettings(s.super_main_loot)
	s.super_main_hard = FL.SuperMainHardSettings(s.super_main_hard)
	s.super_skip = FL.SuperSkipSettings(s.super_skip)
	s.hard_power_rooms = s.hard_power_rooms ~= false
	if s.gold_preview_key == nil then
		s.gold_preview_key = "Ctrl+Shift+Y"
	end
	local t = tonumber(s.hard_power_room_teffra)
	s.hard_power_room_teffra = t ~= nil and math.max(0, math.min(1000, math.floor(t))) or 35
	-- 0.9.0: more for the harder choices (frenzylevels/rewards.lua)
	local ok_r, FR = pcall(require, "frenzylevels.rewards")
	local ok_c, err = false, FR
	if ok_r and type(FR) == "table" then
		FR.Init(FL)
		ok_c, err = pcall(FR.Configure, s)
	end
	if not ok_c then
		Log("the rewards for the harder choices are off (" .. tostring(err) .. ")")
		s.weather_bonus, s.nimble_bonus, s.side_boss_bonus, s.super_main_shards = false, false, false, false
	end
	FL.settings = s
	return s
end

-- super_side_hunts: { enabled, loot = the loot multiplier for Super Frenzy
-- 1 to 5 (5 numbers, or one for all), teffra = Teffra (konjur) multiplied
-- too, all_hard = every fight room hard, unlock_all = every level open (else
-- each opens when the one below is cleared on that side hunt), boss_like_main
-- = the boss's Corestones and ingots as a Super Frenzy main hunt boss's (0.8.3)
-- }, true (the defaults) or false (off).
FL.SUPER_LOOT = { 1.5, 1.75, 2, 2.25, 2.5 }
function FL.SuperSideSettings(c)
	if c == false or type(c) == "table" and c.enabled == false then
		return false
	end
	c = type(c) == "table" and c or {}
	local loot = {}
	local one = tonumber(c.loot)
	for i = 1, SUPER_COUNT do
		local v = one or (type(c.loot) == "table" and tonumber(c.loot[i])) or FL.SUPER_LOOT[i] or FL.SUPER_LOOT[#FL.SUPER_LOOT]
		loot[i] = math.max(1, math.min(10, v))
	end
	-- (0.11.3) the Teffressence Container on the side boss from this SF level (false: never)
	local imbue = false
	if c.imbue_gem ~= false then
		imbue = math.max(1, math.min(SUPER_COUNT, math.floor(tonumber(c.imbue_gem) or 5)))
	end
	return {
		enabled = true,
		loot = loot,
		teffra = c.teffra == true,
		all_hard = c.all_hard ~= false,
		unlock_all = c.unlock_all ~= false,
		boss_like_main = c.boss_like_main ~= false,
		weather = c.weather ~= false, -- (0.10.0) weather side hunts too
		imbue_gem = imbue,
	}
end

-- super_main_hard (0.10.0): { gear_from = 10, gear_max = 15 } or false. A
-- Super Frenzy main hunt gets a step of extra hard rooms for each Party Gear
-- Level above gear_from (up to gear_max) and each Super Frenzy level above 1;
-- all the steps: every fight room hard (superside.lua).
function FL.SuperMainHardSettings(c)
	if c == false or type(c) == "table" and c.enabled == false then
		return false
	end
	c = type(c) == "table" and c or {}
	local top = rawget(_G, "ITEM_LEVEL") ~= nil and tonumber(ITEM_LEVEL.MAX_ITEM_LEVEL) or 15
	local from = tonumber(c.gear_from) or 10
	from = math.max(0, math.min(top - 1, math.floor(from)))
	local max = tonumber(c.gear_max) or top
	max = math.max(from + 1, math.min(top, math.floor(max)))
	return { gear_from = from, gear_max = max }
end

function FL.SuperMainHardOn()
	return type(FL.settings.super_main_hard) == "table"
end

-- Super Frenzy on the weather side hunts (the game's anomalies) too (0.10.0)
function FL.WeatherSuperOn()
	return FL.SuperSideOn() and FL.settings.super_side_hunts.weather ~= false
end

-- super_main_loot: { loot = the loot multiplier for main hunts at Super Frenzy
-- 1 to 5 (5 numbers, or one for all), teffra = Teffra multiplied too }, or
-- false (the game's: the same loot at every Super Frenzy level).
function FL.SuperMainSettings(c)
	if c == false or type(c) == "table" and c.enabled == false then
		return false
	end
	c = type(c) == "table" and c or {}
	local loot = {}
	local one = tonumber(c.loot)
	for i = 1, SUPER_COUNT do
		local v = one or (type(c.loot) == "table" and tonumber(c.loot[i])) or FL.SUPER_LOOT[i] or FL.SUPER_LOOT[#FL.SUPER_LOOT]
		loot[i] = math.max(1, math.min(10, v))
	end
	return { loot = loot, teffra = c.teffra == true }
end

-- super_skip (0.11.0): the Super Frenzy level skip on main hunts
-- (frenzylevels/superskip.lua): { unlock = "any_hunt" | "this_hunt",
-- both_weapons } or false
function FL.SuperSkipSettings(c)
	local ok, SK = pcall(require, "frenzylevels.superskip")
	if not ok or type(SK) ~= "table" then
		Log("the Super Frenzy level skip is off (" .. tostring(SK) .. ")")
		return false
	end
	return SK.Settings(c)
end

function FL.SuperMainOn()
	return type(FL.settings.super_main_loot) == "table"
end

-- the side hunt choices past Frenzy 5: Super Frenzy 1 to 5 (6 to 10: the
-- game's ascension levels; side hunts you frenzy yourself,
-- frenzylevels/superside.lua)
function FL.SuperLevel()
	return NORMAL_MAX + 1
end

function FL.SuperTop()
	return NORMAL_MAX + SUPER_COUNT
end

-- Super Frenzy levels cleared on a side hunt (0 to 5), saved with the picks
FL.SF_KEY = "frenzylevels_sfcleared_"
function FL.SuperCleared(am, location_id)
	local v = am ~= nil and am.persistdata.last_selected[FL.SF_KEY .. location_id] or nil
	return type(v) == "number" and math.max(0, math.min(SUPER_COUNT, math.floor(v))) or 0
end

function FL.SetSuperCleared(am, location_id, sf)
	local before = FL.SuperCleared(am, location_id)
	if sf > before then
		am.persistdata.last_selected[FL.SF_KEY .. location_id] = math.min(SUPER_COUNT, sf)
		return true
	end
	return false
end

-- the highest choice open on a side hunt you frenzy yourself (Super
-- Frenzy 1 is always open; with unlock_all every level)
function FL.SideTop(am, location_id)
	if not FL.SuperSideOn() then
		return NORMAL_MAX
	end
	if FL.settings.super_side_hunts.unlock_all then
		return FL.SuperTop()
	end
	return math.min(FL.SuperTop(), FL.SuperLevel() + FL.SuperCleared(am, location_id))
end

-- a choice's Super Frenzy level (1 to 5), or nil
function FL.SuperOf(choice)
	if type(choice) == "number" and choice > NORMAL_MAX then
		return math.min(SUPER_COUNT, choice - NORMAL_MAX)
	end
	return nil
end

function FL.SuperSideOn()
	return FL.settings.side_hunts ~= false and type(FL.settings.super_side_hunts) == "table"
end

-- cosmetic_chance: { frenzy = 5 percents, super_frenzy = 5 percents }, or
-- false (the game's). A missing or bad number is the default's.
function FL.CosmeticSettings(c)
	if c == false then
		return false
	end
	local default = { frenzy = { 10, 20, 30, 40, 100 }, super_frenzy = { 100, 100, 100, 100, 100 } }
	c = type(c) == "table" and c or {}
	local out = {}
	for key, list in pairs(default) do
		local user = type(c[key]) == "table" and c[key] or {}
		out[key] = {}
		for i, v in ipairs(list) do
			local n = tonumber(user[i])
			out[key][i] = n ~= nil and math.max(0, math.min(100, n)) or v
		end
	end
	return out
end

----------------------------------------------------------------------------
-- Corestones. The game's count (CraftingDropManager:GetSoulDropCount
-- "konjur_soul_lesser", the host's): a boss kill gives
-- ResolveLootModifiers().BossKillCorestones (no frenzy 2, Frenzy 1-2 1,
-- 3-4 2, 5 3, Super Frenzy 4) unless it gives the boss's heart; a corestone
-- room and a Teffra Zucco give Corestones[room difficulty] (1, 1, 2). The
-- game's anomalies also have their reward meter (gems, ingots, heart
-- shards); the side hunts you frenzy yourself get more corestones instead.
-- corestone_bonus: { boss = 5 numbers, rooms = 5 numbers (Frenzy 1 to 5),
-- hunts = "frenzied_side" | "all_side" | "all" }, or false (the game's).
FL.HUNTS = { frenzied_side = "side hunts you frenzied", all_side = "frenzied side hunts and anomalies", all = "every frenzied hunt" }

function FL.CorestoneSettings(c)
	if c == false then
		return false
	end
	local default = { boss = { 1, 1, 2, 2, 3 }, rooms = { 1, 1, 1, 2, 2 } }
	c = type(c) == "table" and c or {}
	local out = { hunts = FL.HUNTS[c.hunts] ~= nil and c.hunts or "frenzied_side" }
	for key, list in pairs(default) do
		local user = type(c[key]) == "table" and c[key] or {}
		out[key] = {}
		for i, v in ipairs(list) do
			local n = tonumber(user[i])
			out[key][i] = n ~= nil and math.max(0, math.min(99, math.floor(n))) or v
		end
	end
	return out
end

-- the bonus for this drop: number, and what it's for (nil: none)
function FL.CorestoneBonus()
	local c = FL.settings.corestone_bonus
	local dungeon = rawget(_G, "TheDungeon")
	local world = rawget(_G, "TheWorld")
	local am = FL.AM ~= nil and FL.AM() or nil
	if c == false or type(c) ~= "table" or dungeon == nil or world == nil or am == nil then
		return 0
	end
	local trek = dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek:IsActive() then
		return 0 -- (Blight Incursion: its own table)
	end
	local level = am:GetCurrentLevel()
	if type(level) ~= "number" or level < 1 then
		return 0
	end
	local loc = dungeon:GetCurrentLocationID()
	local biomes = require "defs.biomes"
	local side = type(loc) == "string" and biomes.IsSublocation(loc) == true
	local weather = side and dungeon:GetDungeonMap().data.is_weather_enabled
	if c.hunts == "frenzied_side" and not (side and not weather)
		or c.hunts == "all_side" and not side then
		return 0
	end
	local frenzy = math.min(level, NORMAL_MAX) -- (Super Frenzy: Frenzy 5's)
	local mapgen = require "defs.mapgen"
	local boss = world:GetCurrentRoomType() == mapgen.roomtypes.RoomType.s.boss
	local list = boss and c.boss or c.rooms
	return list[frenzy] or 0, string.format("Frenzy %d %s, %s", frenzy, side and (weather and "anomaly" or "side hunt") or "hunt", boss and "boss" or "room")
end

-- CraftingDropManager (components.craftingdropmanager). Returns ok, info.
function FL.InstallCorestones(CraftingDropManager)
	local c = FL.settings.corestone_bonus
	if c == false then
		return false, "the game's corestones"
	end
	if type(CraftingDropManager) ~= "table" or type(CraftingDropManager.GetSoulDropCount) ~= "function" then
		return false, "the game's corestones (CraftingDropManager:GetSoulDropCount not found)"
	end
	if not rawget(CraftingDropManager, "frenzylevels_corestones") then
		CraftingDropManager.frenzylevels_corestones = true
		local orig = CraftingDropManager.GetSoulDropCount
		CraftingDropManager.GetSoulDropCount = function(self, soul_type, ...)
			local count = orig(self, soul_type, ...)
			if soul_type == "konjur_soul_lesser" and type(count) == "number" then
				local ok, bonus, what = pcall(FL.CorestoneBonus)
				if not ok then
					Err("corestones", bonus)
				elseif bonus > 0 then
					Log(string.format("corestones: %d + %d (%s)", count, bonus, what))
					count = count + bonus
				end
			end
			return count
		end
	end
	local function List(l)
		local parts = {}
		for i, v in ipairs(l) do
			parts[i] = tostring(v)
		end
		return table.concat(parts, "/")
	end
	return true, string.format("corestones +%s boss, +%s rooms (%s)", List(c.boss), List(c.rooms), FL.HUNTS[c.hunts])
end

----------------------------------------------------------------------------
-- Drakinspawn (the Drakin Armoury Pack). The game (util/monsterutil.lua
-- AddDragonMinibossLoot, when a Drakinspawn spawns): a heart shard, and only
-- once you've finished Brother Tendy's quest a 25% chance of a cube that
-- gives one Drakin cosmetic (LootDropManager:GetCosmeticDropDLC, from
-- dlcutil.Draco_GetCosmetics: the Skyhunter and Marrowdeep armour, 6 pieces;
-- the quest itself gives the Immaculate Edge set). The Drakin weapon looks
-- (<weapon>_hunter: Drakinlance and the rest) drop only in Blight Incursions.
-- drakin_rewards: { pieces = cosmetics per Drakinspawn, during_quest = the
-- quest's fights drop them too, weapons = the weapon looks are in the pool
-- too }, or false (the game's). Every Drakinspawn drops the cube while you
-- have pieces left to get.
FL.DRAKIN_WEAPON_TYPES = { "hammer", "polearm", "cleaver", "cannon", "shotput", "bow" }

function FL.DrakinSettings(d)
	if d == false then
		return false
	end
	d = type(d) == "table" and d or {}
	local pieces = tonumber(d.pieces)
	return {
		pieces = pieces ~= nil and math.max(1, math.min(12, math.floor(pieces))) or 4,
		during_quest = d.during_quest ~= false,
		weapons = d.weapons ~= false,
	}
end

-- the Drakin weapon looks the game has
function FL.DrakinWeapons(Equipment)
	local out = {}
	local items = type(Equipment) == "table" and type(Equipment.Items) == "table" and Equipment.Items.WEAPON or nil
	if type(items) ~= "table" then
		return out
	end
	for _, kind in ipairs(FL.DRAKIN_WEAPON_TYPES) do
		local def = items[kind .. "_hunter"]
		if def ~= nil then
			out[#out + 1] = def
		end
	end
	return out
end

-- monsterutil, dlcutil, LootDropManager (components.lootdropmanager), Equipment. Returns ok, info.
function FL.InstallDrakin(monsterutil, dlcutil, LootDropManager, Equipment)
	local d = FL.settings.drakin_rewards
	if d == false then
		return false, "the game's Drakinspawn drops"
	end
	if type(monsterutil) ~= "table" or type(monsterutil.AddDragonMinibossLoot) ~= "function"
		or type(dlcutil) ~= "table" or type(dlcutil.Draco_GetCosmetics) ~= "function"
		or type(LootDropManager) ~= "table" or type(LootDropManager.GetCosmeticDropDLC) ~= "function" then
		return false, "the game's Drakinspawn drops (the game's Drakinspawn loot not found)"
	end
	if rawget(monsterutil, "frenzylevels_drakin") then
		return true, FL.drakin_info
	end
	monsterutil.frenzylevels_drakin = true
	local weapons = d.weapons and FL.DrakinWeapons(Equipment) or {}

	-- the pool: the game's armour, and the weapon looks
	local orig_pool = dlcutil.Draco_GetCosmetics
	dlcutil.Draco_GetCosmetics = function(...)
		local list = orig_pool(...)
		if #weapons > 0 and type(list) == "table" then
			local out = {}
			for i, def in ipairs(list) do
				out[i] = def
			end
			for _, def in ipairs(weapons) do
				out[#out + 1] = def
			end
			return out
		end
		return list
	end

	-- every Drakinspawn: the heart shard, and the cube while pieces are left
	local orig_loot = monsterutil.AddDragonMinibossLoot
	monsterutil.AddDragonMinibossLoot = function(inst, ...)
		local ok, err = pcall(function()
			local players = TheNet:GetPlayersOnRoomChange()
			for _, player in ipairs(players) do
				if player:IsLocal() then
					inst.components.lootdropper:AddLootToDrop(player, { konjur_heart_shard = 1 })
					local hunting = player:IsFlagUnlocked("pf_draco_dlc_completed_hunt")
						or d.during_quest and player:IsFlagUnlocked("pf_draco_dlc_started_hunt")
					if hunting and player.components.lootdropmanager:IsEligibleForCosmeticDropDLC() then
						inst.components.lootdropper:AddLootToDrop(player, { cosmetic_armour_draco_unlock = 1 })
					end
				end
			end
		end)
		if not ok then
			Err("Drakinspawn loot", err)
			return orig_loot(inst, ...)
		end
	end

	-- each cube gives this many pieces
	local orig_drop = LootDropManager.GetCosmeticDropDLC
	LootDropManager.GetCosmeticDropDLC = function(self, ...)
		local first = orig_drop(self, ...)
		if first ~= nil then
			for _ = 2, d.pieces do
				local ok, more = pcall(orig_drop, self, ...)
				if not ok then
					Err("Drakin pieces", more)
					break
				elseif more == nil then
					break
				end
			end
		end
		return first
	end

	FL.drakin_info = string.format("Drakinspawn: %d Drakin piece%s each%s%s", d.pieces, d.pieces == 1 and "" or "s",
		d.during_quest and ", Tendy's fights too" or "", #weapons > 0 and (", " .. #weapons .. " weapon looks too") or "")
	return true, FL.drakin_info
end

----------------------------------------------------------------------------
-- Blight Incursions. The game skips the boss kill's cosmetic roll there
-- (LootDropManager:OnLootDropperDeath: "Treks hand out mirage patterns
-- through their own reward flow"): its mirages (the Blight's armour sets, the
-- Drakin weapon looks, mirages of gear you own from the hunts you passed) come
-- only from Nimble's Cache, a few percent a roll at most. blight_mirages =
-- true: every Blight boss drops one (the game's cube, its Blight pool) while
-- you have some left to get.
function FL.InstallBlightMirages(LootDropManager)
	if FL.settings.blight_mirages == false then
		return false, "the game's Blight mirages"
	end
	if type(LootDropManager) ~= "table" or type(LootDropManager.OnLootDropperDeath) ~= "function"
		or type(LootDropManager.IsEligibleForCosmeticDrop) ~= "function" then
		return false, "the game's Blight mirages (LootDropManager not found)"
	end
	if not rawget(LootDropManager, "frenzylevels_blight") then
		LootDropManager.frenzylevels_blight = true
		local orig = LootDropManager.OnLootDropperDeath
		LootDropManager.OnLootDropperDeath = function(self, ent, ...)
			local added = orig(self, ent, ...)
			local ok, cube = pcall(function()
				local dungeon = rawget(_G, "TheDungeon")
				local trek = dungeon ~= nil and dungeon:GetTrek() or nil
				if ent ~= nil and ent:HasTag("boss") and trek ~= nil and trek:IsActive()
					and ent.components.lootdropper ~= nil and self:IsEligibleForCosmeticDrop() then
					ent.components.lootdropper:AddLootToDrop(self.inst, { cosmetic_armour_unlock = 1 })
					return true
				end
				return false
			end)
			if not ok then
				Err("Blight mirage", cube)
			elseif cube then
				Log("Blight boss: a mirage")
				added = true
			end
			return added
		end
	end
	return true, "a mirage from every Blight boss"
end

----------------------------------------------------------------------------
-- Cosmetic armour: each boss kill rolls for a piece (LootDropManager:
-- RollCosmeticDrop), with the chance for the run's level from
-- TUNING.COSMETICS.DROP_CHANCE_BY_ASCENSION (0 = no frenzy, 1-5 = Frenzy,
-- 6-10 = Super Frenzy 1-5; the game: 1%, 2 3 4 5 7.5%, 10 12 14 16 20%). A
-- miss adds that chance to the next roll until one drops (the game's bad luck
-- protection). The higher levels (11-15, not in the game yet) are kept at
-- least Super Frenzy 5's.
function FL.InstallCosmetics(tuning)
	local c = FL.settings.cosmetic_chance
	if c == false then
		return false, "the game's"
	end
	local t = type(tuning) == "table" and type(tuning.COSMETICS) == "table" and tuning.COSMETICS.DROP_CHANCE_BY_ASCENSION or nil
	if type(t) ~= "table" or type(t[NORMAL_MAX]) ~= "number" then
		return false, "the game's chances not found (TUNING.COSMETICS.DROP_CHANCE_BY_ASCENSION)"
	end
	for i = 1, NORMAL_MAX do
		t[i] = (c.frenzy[i] or c.frenzy[#c.frenzy]) / 100
	end
	local top = 0
	for i = 1, 5 do
		top = (c.super_frenzy[i] or c.super_frenzy[#c.super_frenzy]) / 100
		t[NORMAL_MAX + i] = top
	end
	for i = NORMAL_MAX + 6, NORMAL_MAX + 10 do
		if type(t[i]) == "number" and t[i] < top then
			t[i] = top
		end
	end
	local function List(l)
		local parts = {}
		for i, v in ipairs(l) do
			parts[i] = tostring(v)
		end
		return table.concat(parts, "/")
	end
	return true, string.format("cosmetic armour %s%%, Super Frenzy %s%%", List(c.frenzy), List(c.super_frenzy))
end

----------------------------------------------------------------------------
-- The Frenzy look: the game tints every frenzied hunt with its frenzy
-- lighting (prefabs/dungeon.lua ApplyLighting: lighting preset "fl_<hunt>",
-- "sfl_<hunt>" in Super Frenzy), a dark purple dusk. Side hunts used to be
-- frenzied only with weather, so most of them kept their normal colours.
-- frenzy_look = false keeps the hunt's normal colours in Frenzy 1-5 (only the
-- look: the difficulty and rewards stay), super_frenzy_look the same for
-- Super Frenzy. While the game works out the lighting, the preset it would
-- use is left out, so it does what it does for a hunt with no frenzy.
function FL.WrapLighting(inst, presets)
	local orig = inst ~= nil and inst.ApplyLighting or nil
	if type(orig) ~= "function" or type(presets) ~= "table" or rawget(inst, "frenzylevels_look") then
		return false
	end
	inst.frenzylevels_look = true
	inst.ApplyLighting = function(self, ...)
		local saved, hidden = {}, {}
		local ok_l, loc = pcall(self.GetCurrentLocationID, self)
		if ok_l and type(loc) == "string" then
			if FL.settings.frenzy_look == false or FL.NormalLookRun(self, loc) then
				hidden[#hidden + 1] = "fl_" .. loc
			end
			if FL.settings.super_frenzy_look == false then
				hidden[#hidden + 1] = "sfl_" .. loc
			end
		end
		for _, key in ipairs(hidden) do
			saved[key] = rawget(presets, key)
			presets[key] = nil
		end
		local results = table.pack(pcall(orig, self, ...))
		for _, key in ipairs(hidden) do
			presets[key] = saved[key]
		end
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
	return true
end

-- this run is a side hunt you frenzied yourself (no weather) set to the
-- normal look
function FL.NormalLookRun(dungeon, loc)
	if FL.settings.side_hunts == false then
		return false
	end
	local ok_b, biomes = pcall(require, "defs.biomes")
	if not ok_b or type(biomes) ~= "table" or biomes.IsSublocation == nil or not biomes.IsSublocation(loc) then
		return false
	end
	local ok_w, weather = pcall(function() return dungeon:GetDungeonMap().data.is_weather_enabled end)
	if not ok_w or weather then
		return false -- an anomaly (the game's frenzy): the game's look
	end
	local am = FL.AM ~= nil and FL.AM() or nil
	return am ~= nil and not FL.GetLook(am, loc)
end

function FL.LookInfo()
	local f, s = FL.settings.frenzy_look ~= false, FL.settings.super_frenzy_look ~= false
	if f and s then
		return "the game's frenzy colours" .. (FL.settings.side_hunts ~= false and " (X switches a frenzied side hunt's look)" or "")
	elseif not f and not s then
		return "normal colours in Frenzy and Super Frenzy"
	elseif not f then
		return "normal colours in Frenzy 1-5"
	end
	return "normal colours in Super Frenzy"
end

function FL.Clamp(level)
	level = type(level) == "number" and math.floor(level) or FL.settings.default_level
	return math.max(FL.settings.min_level, math.min(NORMAL_MAX, level))
end

function FL.GetChoice(am, location_id)
	local saved = am.persistdata.last_selected[FL.KEY .. location_id]
	return FL.Clamp(type(saved) == "number" and saved or FL.settings.default_level)
end

function FL.SetChoice(am, location_id, level)
	level = FL.Clamp(level)
	am.persistdata.last_selected[FL.KEY .. location_id] = level
	return level
end

-- Side hunts (the smaller hunts around a main one: biomes.IsSublocation). The
-- game gives them frenzy only while they have weather, at a level it works
-- out (1-4, by zone 2 hearts: DungeonSelectionUtil.GetDefaultAscension), else
-- none. Here: No frenzy (0) to 5, picked per side hunt; one never picked has
-- the game's level.
-- game_level: the game's level for it now (1-4 while it has weather, an
-- anomaly: then it never goes to Standard).
function FL.GetSideChoice(am, location_id, game_level)
	local saved = am.persistdata.last_selected[FL.KEY .. location_id]
	local level = type(saved) == "number" and saved or (type(game_level) == "number" and game_level or 0)
	local anomaly = type(game_level) == "number" and game_level >= 1
	local lowest = anomaly and 1 or 0
	local top = (anomaly and not FL.WeatherSuperOn()) and NORMAL_MAX or FL.SideTop(am, location_id)
	return math.max(lowest, math.min(top, math.floor(level)))
end

-- the level the game stores for a side hunt choice (Super Frenzy: Frenzy 5,
-- the run's own; superside.lua does the rest)
function FL.GameLevel(choice)
	return math.min(NORMAL_MAX, choice)
end

-- A side hunt you frenzied yourself (no weather): its look, the game's
-- Frenzy colours (true, the default) or the hunt's normal ones (false), saved
-- per hunt with the picks. X (keyboard Shift) on the map switches it.
FL.LOOK_KEY = "frenzylevels_look_"
FL.STR = { FRENZY_LOOK = "Frenzy look", NORMAL_LOOK = "Normal look" }
function FL.GetLook(am, location_id)
	return am.persistdata.last_selected[FL.LOOK_KEY .. location_id] ~= 0
end

function FL.SetLook(am, location_id, frenzy_look)
	am.persistdata.last_selected[FL.LOOK_KEY .. location_id] = frenzy_look and 1 or 0
	return frenzy_look
end

function FL.SetSideChoice(am, location_id, level)
	level = math.max(0, math.min(FL.SideTop(am, location_id), math.floor(level)))
	am.persistdata.last_selected[FL.KEY .. location_id] = level
	return level
end

-- frenzy unlocked for this side hunt (or its main hunt)
function FL.SideUnlocked(player, location_id, biomes)
	if FL.settings.side_hunts == false or player == nil or player.components == nil then
		return false
	end
	local ut = player.components.unlocktracker
	if ut == nil or ut.AreAscensionsUnlocked == nil then
		return false
	end
	if ut:AreAscensionsUnlocked(location_id) then
		return true
	end
	local parent = biomes ~= nil and biomes.GetParentLocation ~= nil and biomes.GetParentLocation(location_id) or nil
	return parent ~= nil and ut:AreAscensionsUnlocked(parent) == true
end

local function AM()
	local dungeon = rawget(_G, "TheDungeon")
	local prog = dungeon ~= nil and dungeon.progression or nil
	return prog ~= nil and prog.components ~= nil and prog.components.ascensionmanager or nil
end
FL.AM = AM

----------------------------------------------------------------------------
-- The game stores Frenzy 5 for a main hunt in two places (the side panel's
-- SetFrenzyMode and the map marker's Reset): while those run, a 5 stored for
-- that hunt becomes the hunt's chosen level.

FL.substitute = nil -- the location id being set up

function FL.InstallAscension(AscensionManager)
	local orig = AscensionManager.StoreSelectedAscension
	if type(orig) ~= "function" then
		return false, "AscensionManager:StoreSelectedAscension missing"
	end
	AscensionManager.StoreSelectedAscension = function(self, location_id, value, ...)
		if FL.substitute ~= nil and FL.substitute == location_id and FL.substitute_side and type(value) == "number" and value <= NORMAL_MAX then
			-- a side hunt: its pick (the game's level stored here if never picked)
			local ok, chosen = pcall(FL.GetSideChoice, self, location_id, value)
			if ok then
				value = FL.GameLevel(chosen)
			else
				Err("store", chosen)
			end
		elseif FL.substitute ~= nil and FL.substitute == location_id and not FL.substitute_side and value == NORMAL_MAX then
			local ok, chosen = pcall(FL.GetChoice, self, location_id)
			if ok then
				value = chosen
			else
				Err("store", chosen)
			end
		end
		return orig(self, location_id, value, ...)
	end
	return true
end

local function WithSubstitute(location_id, side, fn, ...)
	local before, before_side = FL.substitute, FL.substitute_side
	FL.substitute, FL.substitute_side = location_id, side
	local results = table.pack(pcall(fn, ...))
	FL.substitute, FL.substitute_side = before, before_side
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

----------------------------------------------------------------------------
-- The map's side panel

-- the side panel's mode ids (its FrenzyMode enum is local to the file)
local function FindMode(MapSidebar, mode, default)
	local dbg = rawget(_G, "debug")
	for _, fn in ipairs({ MapSidebar.SetFrenzyMode, MapSidebar.GetFrenzyLevel, MapSidebar._RefreshFrenzyWidgets }) do
		if type(fn) == "function" and dbg ~= nil and dbg.getupvalue ~= nil then
			for i = 1, 60 do
				local name, value = dbg.getupvalue(fn, i)
				if name == nil then
					break
				end
				if name == "FrenzyMode" and type(value) == "table" and type(value.id) == "table" then
					local id = rawget(value.id, mode)
					if id ~= nil then
						return id
					end
				end
			end
		end
	end
	return default -- Enum { "None", "Normal", "Super" }
end

function FL.InstallSidebar(MapSidebar, biomes, strings)
	if type(MapSidebar) ~= "table" or type(MapSidebar.SetFrenzyMode) ~= "function"
		or type(MapSidebar.GetFrenzyLevel) ~= "function" or type(MapSidebar.IncreaseAscensionLevel) ~= "function"
		or type(MapSidebar.DecreaseAscensionLevel) ~= "function" then
		return false, "the map's side panel changed (SetFrenzyMode / GetFrenzyLevel / Increase / DecreaseAscensionLevel)"
	end
	local NORMAL = FindMode(MapSidebar, "Normal", 2)
	local NONE = FindMode(MapSidebar, "None", 1)
	local SUPER = FindMode(MapSidebar, "Super", 3)
	FL.normal_mode, FL.none_mode = NORMAL, NONE

	local function IsHunt(location_id)
		return location_id ~= nil and not biomes.IsSublocation(location_id)
	end

	-- Frenzy mode, a main hunt (side hunts: AppliesSide)
	local function Applies(self)
		local loc = rawget(self, "locationData")
		return loc ~= nil and rawget(self, "frenzy_mode") == NORMAL and IsHunt(loc.id) and AM() ~= nil
	end
	FL.Applies = Applies

	-- a side hunt with frenzy unlocked (not in Super Frenzy): No frenzy to 5
	local function AppliesSide(self)
		local loc = rawget(self, "locationData")
		if loc == nil or loc.id == nil or not biomes.IsSublocation(loc.id) or AM() == nil or rawget(self, "frenzy_mode") == SUPER then
			return false
		end
		local ok, player = pcall(self.GetOwningPlayer, self)
		return ok and FL.SideUnlocked(player, loc.id, biomes)
	end
	FL.AppliesSide = AppliesSide

	local function SideChoice(self)
		return FL.GetSideChoice(AM(), self.locationData.id, rawget(self, "default_ascension"))
	end
	FL.SideChoiceOf = SideChoice

	-- the game's anomaly (frenzied by its weather): the game's level is 1+
	local function IsAnomaly(self)
		return type(rawget(self, "default_ascension")) == "number" and self.default_ascension >= 1
	end
	FL.IsAnomaly = IsAnomaly

	-- a side hunt you frenzied yourself: X switches its look
	function FL.CanToggleLook(self)
		return AppliesSide(self) and not IsAnomaly(self) and SideChoice(self) >= 1
	end

	function FL.ToggleLook(self)
		if not FL.CanToggleLook(self) then
			return false
		end
		local am, loc = AM(), self.locationData.id
		FL.SetLook(am, loc, not FL.GetLook(am, loc))
		local fe = rawget(_G, "TheFrontEnd")
		local sound = rawget(self, "controldown_sound")
		if fe ~= nil and sound ~= nil then
			pcall(function() fe:GetSound():PlaySound(sound) end)
		end
		FL.ShowTitle(self)
		return true
	end

	local function LevelText(level)
		local w = strings ~= nil and strings.UI ~= nil and strings.UI.DUNGEONSELECTIONSCREEN ~= nil
			and strings.UI.DUNGEONSELECTIONSCREEN.FRENZY_WIDGET or nil
		if level > NORMAL_MAX then
			local d = strings ~= nil and strings.UI ~= nil and strings.UI.DUNGEONSELECTIONSCREEN or nil
			local name = d ~= nil and type(d.HOTKEY_SUPERFRENZY) == "string" and d.HOTKEY_SUPERFRENZY or "Super Frenzy"
			return name .. " " .. tostring(FL.SuperOf(level))
		end
		if level == 0 then
			return w ~= nil and w.BASE_DIFFICULTY_TITLE or "Standard"
		end
		local fmt = w ~= nil and w.FRENZY_LEVEL_TITLE or "Frenzy {level}"
		return (fmt:gsub("{level}", tostring(level)))
	end
	FL.LevelText = LevelText

	local function Glyph(name)
		local controls = rawget(_G, "Controls")
		local c = controls ~= nil and controls.Digital ~= nil and rawget(controls.Digital, name) or nil
		if c == nil or c.key == nil then
			return ""
		end
		return string.format("<p bind='%s' color=0>", c.key)
	end

	-- the level under the hunt's name, between the bumper buttons
	function FL.ShowTitle(self)
		local dl = rawget(self, "dungeon_level")
		local loc = rawget(self, "locationData")
		if dl == nil or loc == nil or dl.SetBiomeTitle == nil or biomes.GetLocationPrettyNames == nil then
			return
		end
		local title, subtitle = biomes.GetLocationPrettyNames(loc.id)
		local show = FL.settings.show_in_title ~= false
		local mine = false
		if show and Applies(self) then
			mine = true
			local level = FL.GetChoice(AM(), loc.id)
			subtitle = Glyph("MENU_TAB_PREV") .. " " .. LevelText(level) .. " " .. Glyph("MENU_TAB_NEXT")
		elseif show and AppliesSide(self) then
			-- the side hunt's name stays, its level after it
			mine = true
			subtitle = tostring(subtitle or "") .. "   " .. Glyph("MENU_TAB_PREV") .. " " .. LevelText(SideChoice(self)) .. " " .. Glyph("MENU_TAB_NEXT")
			if FL.CanToggleLook(self) then
				subtitle = subtitle .. "   " .. Glyph("MENU_SECONDARY") .. " "
					.. (FL.GetLook(AM(), loc.id) and FL.STR.FRENZY_LOOK or FL.STR.NORMAL_LOOK)
			end
		end
		if mine or rawget(self, "frenzylevels_title") then
			dl:SetBiomeTitle(title, subtitle)
		end
		self.frenzylevels_title = mine
	end

	local orig_get = MapSidebar.GetFrenzyLevel
	MapSidebar.GetFrenzyLevel = function(self, ...)
		local ok, applies = pcall(Applies, self)
		if ok and applies then
			return FL.GetChoice(AM(), self.locationData.id)
		end
		local ok_s, side = pcall(AppliesSide, self)
		if ok_s and side then
			return SideChoice(self)
		end
		return orig_get(self, ...)
	end

	local orig_set = MapSidebar.SetFrenzyMode
	MapSidebar.SetFrenzyMode = function(self, mode, ...)
		local loc = rawget(self, "locationData")
		local results
		local side_ok = false
		if mode == NORMAL and loc ~= nil and loc.id ~= nil and biomes.IsSublocation(loc.id) and AM() ~= nil then
			local okp, player = pcall(self.GetOwningPlayer, self)
			side_ok = okp and FL.SideUnlocked(player, loc.id, biomes)
		end
		if mode == NORMAL and loc ~= nil and IsHunt(loc.id) and AM() ~= nil then
			results = table.pack(WithSubstitute(loc.id, false, orig_set, self, mode, ...))
		elseif side_ok then
			results = table.pack(WithSubstitute(loc.id, true, orig_set, self, mode, ...))
		else
			results = table.pack(orig_set(self, mode, ...))
		end
		local ok, err = pcall(FL.ShowTitle, self)
		if not ok then
			Err("title", err)
		end
		return table.unpack(results, 1, results.n)
	end

	if type(MapSidebar.SetLocationData) == "function" then
		local orig_loc = MapSidebar.SetLocationData
		MapSidebar.SetLocationData = function(self, ...)
			self.frenzylevels_title = nil -- the game sets the title again
			local results = table.pack(orig_loc(self, ...))
			local ok_m, err_m = pcall(FL.SideMode, self)
			if not ok_m then
				Err("side hunt", err_m)
			end
			local ok, err = pcall(FL.ShowTitle, self)
			if not ok then
				Err("title", err)
			end
			return table.unpack(results, 1, results.n)
		end
	end

	-- a side hunt: Frenzy mode for a level, the game's no-frenzy mode for 0
	-- (the game opens one without weather in no-frenzy mode)
	function FL.SideMode(self)
		if not AppliesSide(self) then
			return false
		end
		local want = SideChoice(self) >= 1 and NORMAL or NONE
		if rawget(self, "frenzy_mode") ~= want then
			self:SetFrenzyMode(want)
			return true
		end
		return false
	end

	function FL.DeltaSide(self, delta)
		local am = AM()
		local loc = self.locationData.id
		local old = SideChoice(self)
		local top = (IsAnomaly(self) and not FL.WeatherSuperOn()) and NORMAL_MAX or FL.SideTop(am, loc)
		local new = math.max(IsAnomaly(self) and 1 or 0, math.min(top, old + delta))
		if new == old then
			return false
		end
		FL.SetSideChoice(am, loc, new)
		local fe = rawget(_G, "TheFrontEnd")
		local sound = rawget(self, "controldown_sound")
		if fe ~= nil and sound ~= nil then
			pcall(function() fe:GetSound():PlaySound(sound) end)
		end
		if not FL.SideMode(self) then
			-- same mode: store it, refresh the tier badge, marker, materials
			am:StoreSelectedAscension(loc, FL.GameLevel(new))
			self:UpdateDifficultyAssessment()
			if self.RefreshContents ~= nil then
				self:RefreshContents()
			end
		end
		FL.ApplySideLook(self)
		FL.ShowTitle(self)
		return true
	end

	-- a side hunt at the Super Frenzy step: the game's Super Frenzy panel
	-- (its dark purple background and title); back to the Frenzy one below it
	local SUPER_BG, NORMAL_BG = "images/ui_ftf_dungeon_selection/panel_bg_superfrenzy.tex", "images/ui_ftf_dungeon_selection/panel_bg.tex"
	function FL.ApplySideLook(self)
		local super = AppliesSide(self) and SideChoice(self) > NORMAL_MAX
		local colors = rawget(_G, "UICOLORS")
		local bg, dl = rawget(self, "bg"), rawget(self, "dungeon_level")
		if super then
			if bg ~= nil and bg.SetTexture ~= nil then bg:SetTexture(SUPER_BG) end
			if dl ~= nil and dl.SetLocationTitleColor ~= nil and colors ~= nil then dl:SetLocationTitleColor(colors.SUPERFRENZY_TEXT_ACTIVE) end
			self.frenzylevels_super_look = true
		elseif rawget(self, "frenzylevels_super_look") then
			self.frenzylevels_super_look = nil
			if rawget(self, "frenzy_mode") == NORMAL then
				if bg ~= nil and bg.SetTexture ~= nil then bg:SetTexture(NORMAL_BG) end
				if dl ~= nil and dl.SetLocationTitleColor ~= nil and colors ~= nil then dl:SetLocationTitleColor(colors.PURPLE) end
			end
		end
		return super
	end

	if type(MapSidebar._RefreshFrenzyWidgets) == "function" then
		local orig_refresh = MapSidebar._RefreshFrenzyWidgets
		MapSidebar._RefreshFrenzyWidgets = function(self, ...)
			local results = table.pack(orig_refresh(self, ...))
			local ok, err = pcall(FL.ApplySideLook, self)
			if not ok then
				Err("Super Frenzy look", err)
			end
			return table.unpack(results, 1, results.n)
		end
	end

	function FL.Delta(self, delta)
		local am = AM()
		local loc = self.locationData.id
		local old = FL.GetChoice(am, loc)
		local new = FL.Clamp(old + delta)
		if new == old then
			return false
		end
		FL.SetChoice(am, loc, new)
		am:StoreSelectedAscension(loc, new)
		local fe = rawget(_G, "TheFrontEnd")
		local sound = rawget(self, "controldown_sound")
		if fe ~= nil and sound ~= nil then
			pcall(function() fe:GetSound():PlaySound(sound) end)
		end
		self:UpdateDifficultyAssessment() -- the tier badge and the map marker
		if self.RefreshContents ~= nil then
			self:RefreshContents() -- materials, layout
		end
		FL.ShowTitle(self)
		return true
	end

	local orig_inc, orig_dec = MapSidebar.IncreaseAscensionLevel, MapSidebar.DecreaseAscensionLevel
	local function Press(self, delta, orig, what, ...)
		local ok, applies = pcall(Applies, self)
		if ok and applies then
			local ok2, err = pcall(FL.Delta, self, delta)
			if not ok2 then
				Err(what, err)
			end
			return self
		end
		local ok_s, side = pcall(AppliesSide, self)
		if ok_s and side then
			local ok2, err = pcall(FL.DeltaSide, self, delta)
			if not ok2 then
				Err(what, err)
			end
			return self
		end
		return orig(self, ...)
	end
	MapSidebar.IncreaseAscensionLevel = function(self, ...)
		return Press(self, 1, orig_inc, "level up", ...)
	end
	MapSidebar.DecreaseAscensionLevel = function(self, ...)
		return Press(self, -1, orig_dec, "level down", ...)
	end
	return true, "normal mode id " .. tostring(NORMAL)
end

-- X (MENU_SECONDARY, keyboard Shift) on the map: a frenzied side hunt's look
function FL.InstallScreen(Screen, Controls)
	if type(Screen) ~= "table" or type(Screen.CONTROL_MAP) ~= "table" or Controls == nil or Controls.Digital == nil
		or Controls.Digital.MENU_SECONDARY == nil then
		return false, "the map screen's button map not found"
	end
	if rawget(Screen, "frenzylevels_look_key") then
		return true
	end
	Screen.frenzylevels_look_key = true
	table.insert(Screen.CONTROL_MAP, {
		control = Controls.Digital.MENU_SECONDARY,
		test = function(self)
			local sb = rawget(self, "sidebar")
			local ok, can = pcall(function() return sb ~= nil and sb:IsShown() and FL.CanToggleLook ~= nil and FL.CanToggleLook(sb) end)
			return ok and can == true
		end,
		fn = function(self)
			local ok, err = pcall(FL.ToggleLook, self.sidebar)
			if not ok then
				Err("look toggle", err)
			end
			return true
		end,
	})
	return true
end

-- the map markers: their Reset stores the hunt's default (Frenzy 5; a side
-- hunt's: the game's level)
function FL.InstallMarker(MapLocationMarker, biomes)
	if type(MapLocationMarker) ~= "table" or type(MapLocationMarker.Reset) ~= "function" then
		return false, "MapLocationMarker:Reset missing"
	end
	local orig = MapLocationMarker.Reset
	MapLocationMarker.Reset = function(self, ...)
		local ok, id = pcall(self.GetId, self)
		if ok and id ~= nil and AM() ~= nil then
			if not biomes.IsSublocation(id) then
				return WithSubstitute(id, false, orig, self, ...)
			end
			local okp, player = pcall(self.GetOwningPlayer, self)
			if okp and FL.SideUnlocked(player, id, biomes) then
				return WithSubstitute(id, true, orig, self, ...)
			end
		end
		return orig(self, ...)
	end
	if type(MapLocationMarker._UpdateBadgeVisuals) == "function" and not rawget(MapLocationMarker, "frenzylevels_super_badge") then
		MapLocationMarker.frenzylevels_super_badge = true
		local orig_badge = MapLocationMarker._UpdateBadgeVisuals
		MapLocationMarker._UpdateBadgeVisuals = function(self, ...)
			local results = table.pack(orig_badge(self, ...))
			local ok, err = pcall(FL.SuperBadge, self, biomes)
			if not ok then
				Err("Super Frenzy marker", err)
			end
			return table.unpack(results, 1, results.n)
		end
	end
	return true
end

-- the Super Frenzy side hunt shield (images/frenzylevels_markers: the game's
-- Super Frenzy main hunt shield without its crown, kit/tools/mapicons); used
-- only once the game finds the file (it stops on a missing one)
FL.SF_SIDE_BG = "images/frenzylevels_markers/frenzylevels_sf_side_bg.tex"
-- (0.10.2) the gold one: the game's completed main hunt shield without its crown
FL.SF_SIDE_GOLD_BG = "images/frenzylevels_markers/frenzylevels_sf_side_gold_bg.tex"
FL.SF_SIDE_ATLAS = "images/frenzylevels_markers.xml"
function FL.SideArtFound()
	if FL.side_art_found == nil then
		local resolve = rawget(_G, "softresolvefilepath")
		local ok, path = false, nil
		if type(resolve) == "function" then
			ok, path = pcall(resolve, FL.SF_SIDE_ATLAS)
		end
		FL.side_art_found = ok and path ~= nil and path ~= false
		if not FL.side_art_found then
			Log("Super Frenzy side hunt marker art not found (" .. FL.SF_SIDE_ATLAS .. "): the Frenzy shield")
		end
	end
	return FL.side_art_found
end

-- a side hunt's map marker at a Super Frenzy step: the game's Super Frenzy
-- look (the main hunts' Super Frenzy shield without the crown, its tier badge,
-- the pink text and boss icon) and the tier of that Super Frenzy level. The
-- game's own badge code sets the shield every time, so below Super Frenzy it's
-- the game's Frenzy one again.
function FL.SuperBadge(self, biomes)
	FL.markers[self] = true -- (the gold preview redraws the ones on the map)
	local shown = FL.preview_gold and FL.GoldPreview(self) or FL.SuperBadgeShow(self, biomes)
	if shown then
		self.frenzylevels_sf_look = true
	elseif rawget(self, "frenzylevels_sf_look") then
		-- (0.10.0 fix) back below Super Frenzy: the game's frenzied side hunt
		-- code puts back its shield and tier badge but never sets the boss
		-- icon's colour (the pink stayed): the game's black, as its other badges.
		-- (The game colours every other marker's icon itself.)
		self.frenzylevels_sf_look = nil
		local icon, colors = rawget(self, "boss_icon"), rawget(_G, "UICOLORS")
		if rawget(self, "is_sub_location") and rawget(self, "is_frenzied")
			and icon ~= nil and icon.SetMultColor ~= nil and colors ~= nil and colors.BLACK ~= nil then
			icon:SetMultColor(colors.BLACK)
		end
	end
	return shown
end

----------------------------------------------------------------------------
-- (0.10.3) the gold preview: a key (gold_preview_key, Ctrl+Shift+Y) shows
-- every hunt's marker in its gold look, to see them: visual only, nothing
-- saved, off again with the key or when the game restarts.
FL.preview_gold = false
FL.markers = setmetatable({}, { __mode = "k" })
FL.GAME_SIDE_GOLD = "images/mapicons_ftf/dungeon_bg_completed.tex" -- (the game's own, unused: if the mod's art is missing)

function FL.GoldPreview(self)
	local colors = rawget(_G, "UICOLORS")
	local side = rawget(self, "is_sub_location") == true
	if self.SetSaturation ~= nil then
		self:SetSaturation(1)
	end
	local badge = rawget(self, "badge")
	if badge ~= nil and badge.SetTexture ~= nil then
		badge:SetTexture(side and (FL.SideArtFound() and FL.SF_SIDE_GOLD_BG or FL.GAME_SIDE_GOLD) or "images/mapicons_ftf/dungeon_boss_bg_completed.tex")
	end
	local tier = rawget(self, "dungeon_tier")
	if tier ~= nil and tier.SetBadgeTexture ~= nil then
		local t = tier:SetBadgeTexture("images/ui_ftf_shop/dungeon_level_badge_completed.tex")
		if colors ~= nil and t ~= nil and t.SetTextColor ~= nil then
			t:SetTextColor(colors.SUPERFRENZY_TEXT_COMPLETED)
			if t.SetTextShadowColor ~= nil then
				t:SetTextShadowColor(colors.SUPERFRENZY_TEXT_COMPLETED_SHADOW)
			end
		end
	end
	local icon = rawget(self, "boss_icon")
	if icon ~= nil and icon.SetMultColor ~= nil and colors ~= nil then
		icon:SetMultColor(colors.SUPERFRENZY_TEXT_COMPLETED)
	end
	return true
end

-- the key: on / off, the markers on the map redrawn (the game's own badge
-- code, then this), a note on screen
function FL.ToggleGoldPreview()
	FL.preview_gold = not FL.preview_gold
	local n = 0
	for marker in pairs(FL.markers) do
		-- (a widget taken off the screen: removed, or its entity gone)
		local ok_v, valid = pcall(function()
			if rawget(marker, "removed") then
				return false
			end
			local inst = rawget(marker, "inst")
			return inst == nil or inst.IsValid == nil or inst:IsValid()
		end)
		if ok_v and valid and marker._UpdateBadgeVisuals ~= nil then
			local ok = pcall(marker._UpdateBadgeVisuals, marker)
			if ok then
				n = n + 1
			end
		else
			FL.markers[marker] = nil
		end
	end
	local msg = FL.preview_gold and "gold preview on: every hunt's marker gold (visual only, nothing saved)" or "gold preview off: the markers as they are"
	Log(string.format("%s (%d markers redrawn)", msg, n))
	pcall(function()
		local fe = rawget(_G, "TheFrontEnd")
		fe:ShowTextNotification("images/ui_ftf_shop/dungeon_level_badge_completed.tex", "Frenzy Levels", msg, 4)
	end)
	return FL.preview_gold, n
end

-- "Ctrl+Shift+Y" -> { key = "Y", ctrl = true, shift = true, alt = false, text = ... } or nil
function FL.ParseKey(text)
	if type(text) ~= "string" then
		return nil
	end
	local b = { ctrl = false, shift = false, alt = false, text = text }
	for part in text:gmatch("[^+]+") do
		local p = part:match("^%s*(.-)%s*$")
		local low = p:lower()
		if low == "ctrl" or low == "control" then
			b.ctrl = true
		elseif low == "shift" then
			b.shift = true
		elseif low == "alt" then
			b.alt = true
		elseif p ~= "" then
			if b.key ~= nil then
				return nil
			end
			b.key = p:upper()
		end
	end
	return b.key ~= nil and b or nil
end

-- the key, once a session (TheInput lives as long as the game); exact
-- modifiers (Ctrl+Shift+Y isn't Ctrl+Shift+Alt+Y), not while typing
function FL.BindGoldKey(input, Keys)
	local k = FL.ParseKey(FL.settings.gold_preview_key)
	if k == nil then
		return "no gold preview key"
	end
	if type(input) ~= "table" or type(input.AddKeyDownHandler) ~= "function" or type(input.IsKeyDown) ~= "function" or type(Keys) ~= "table" then
		return "no gold preview key (the game's input changed)"
	end
	local function Code(name)
		local ok, code = pcall(function() return Keys[name] end)
		return ok and code or nil
	end
	local code = Code(k.key)
	if code == nil then
		return "no gold preview key (the game has no key " .. k.key .. ")"
	end
	local mods = { ctrl = Code("CTRL"), shift = Code("SHIFT"), alt = Code("ALT") }
	if rawget(input, "_frenzylevels_gold_key") == code then
		return k.text .. ": the gold preview"
	end
	rawset(input, "_frenzylevels_gold_key", code)
	input:AddKeyDownHandler(code, function()
		local ok, err = pcall(function()
			local fe = rawget(_G, "TheFrontEnd")
			if type(fe) == "table" and fe.forceProcessText == true then
				return -- (typing)
			end
			local function Down(c) return c ~= nil and input:IsKeyDown(c) == true end
			if Down(mods.ctrl) == k.ctrl and Down(mods.shift) == k.shift and Down(mods.alt) == k.alt then
				FL.ToggleGoldPreview()
			end
		end)
		if not ok then
			Err("gold preview key", err)
		end
	end)
	return k.text .. ": the gold preview"
end

function FL.SuperBadgeShow(self, biomes)
	if not FL.SuperSideOn() or not rawget(self, "is_sub_location") or not rawget(self, "is_frenzied") then
		return false
	end
	local am = AM()
	local id = self:GetId()
	if am == nil or id == nil then
		return false
	end
	local choice = FL.GetSideChoice(am, id, 0)
	if FL.SuperOf(choice) == nil then
		return false
	end
	if am:GetSelectedAscension(id) ~= NORMAL_MAX then
		return false -- (an anomaly today: the game's level)
	end
	local colors = rawget(_G, "UICOLORS")
	-- (0.10.2) Super Frenzy 5 cleared on this side hunt: the gold look, as the
	-- game's main hunts once every Super Frenzy level is cleared (its
	-- completed shield without the crown, its completed tier badge and colours)
	local gold = FL.SuperCleared(am, id) >= SUPER_COUNT
	local text, shadow = "SUPERFRENZY_TEXT_ACTIVE", "SUPERFRENZY_TEXT_ACTIVE_SHADOW"
	if gold then
		text, shadow = "SUPERFRENZY_TEXT_COMPLETED", "SUPERFRENZY_TEXT_COMPLETED_SHADOW"
	end
	local tier = rawget(self, "dungeon_tier")
	local ok_u, DSU = pcall(require, "widgets.ftf.dungeonselection.dungeonselectionutil")
	if tier ~= nil and ok_u and type(DSU) == "table" and DSU.GetDifficultyLevelInternal ~= nil then
		tier:SetLevel(DSU.GetDifficultyLevelInternal({ ascension_level = choice, location = id }))
	end
	if tier ~= nil and tier.SetBadgeTexture ~= nil then
		local t = tier:SetBadgeTexture(gold and "images/ui_ftf_shop/dungeon_level_badge_completed.tex" or "images/ui_ftf_shop/dungeon_level_badge_super_frenzy.tex")
		if colors ~= nil and t ~= nil and t.SetTextColor ~= nil then
			t:SetTextColor(colors[text])
			if t.SetTextShadowColor ~= nil then
				t:SetTextShadowColor(colors[shadow])
			end
		end
	end
	local icon = rawget(self, "boss_icon")
	if icon ~= nil and icon.SetMultColor ~= nil and colors ~= nil then
		icon:SetMultColor(colors[text])
	end
	local badge = rawget(self, "badge")
	if badge ~= nil and badge.SetTexture ~= nil and FL.SideArtFound() then
		badge:SetTexture(gold and FL.SF_SIDE_GOLD_BG or FL.SF_SIDE_BG)
	end
	self.frenzylevels_gold = gold or nil
	return true
end

return FL
