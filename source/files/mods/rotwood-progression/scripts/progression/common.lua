-- Progression: settings, logging and the gear helpers both modes use.

local Common = {}

Common.TAG = "[Progression]"
Common.settings = nil

Common.MODES = { off = true, permanent = true, liri = true, nightly = true }

Common.DEFAULTS = {
	mode = "permanent",
	permanent = {
		weapons = true,
		morphic_set = true,
		gems_per_kill = 1,
		super_frenzy_only = true,
		super_frenzy_heart_multiplier = 1,
		super_frenzy_heart_cap = 30,
		super_frenzy_both_weapons = true,
	},
	liri = {
		weapons = true,
		morphic_set = true,
		gems_per_kill = 3,
		super_frenzy_only = true,
		super_frenzy_heart_multiplier = 2,
		super_frenzy_heart_cap = 30,
		super_frenzy_both_weapons = true,
		corestone_multiplier = 3,
		gift_multiplier = 2,
		market_full_set = true,
	},
	nightly = {
		pick_any_level = true,
		boss_gear = true,
		all_weapon_types = true,
		double_pickups = true,
		double_amount = 2,
		market_full_set = true,
	},
	debug = false,
}

function Common.Log(msg)
	print(Common.TAG .. " " .. tostring(msg))
end

function Common.Debug(msg)
	if Common.settings ~= nil and Common.settings.debug then
		Common.Log("debug: " .. tostring(msg))
	end
end

-- "Nightly", "NIGHT", "game night" -> "nightly"; "Permanent" -> "permanent";
-- "Liri" -> "liri"; "OFF" -> "off"
function Common.NormalizeMode(mode)
	if type(mode) == "boolean" then
		return mode and "permanent" or "off"
	end
	if type(mode) ~= "string" then
		return nil
	end
	local m = mode:lower():gsub("[%s_%-]", "")
	if m == "off" or m == "none" or m == "disabled" then
		return "off"
	elseif m == "permanent" or m == "perm" or m == "on" then
		return "permanent"
	elseif m == "nightly" or m == "night" or m == "gamenight" then
		return "nightly"
	elseif m == "liri" then
		return "liri"
	end
	return nil
end

local function Merge(defaults, user)
	local s = {}
	for k, v in pairs(defaults) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if defaults[k] ~= nil and type(v) == type(defaults[k]) then
				s[k] = v
			end
		end
	end
	return s
end

function Common.LoadSettings(user)
	user = type(user) == "table" and user or {}
	local s = {
		permanent = Merge(Common.DEFAULTS.permanent, user.permanent),
		liri = Merge(Common.DEFAULTS.liri, user.liri),
		nightly = Merge(Common.DEFAULTS.nightly, user.nightly),
		debug = type(user.debug) == "boolean" and user.debug or Common.DEFAULTS.debug,
	}
	s.mode = Common.NormalizeMode(user.mode)
	if s.mode == nil then
		if user.mode ~= nil then
			s.bad_mode = tostring(user.mode)
		end
		s.mode = Common.DEFAULTS.mode
	end
	local function clamp(v, lo, hi)
		return math.max(lo, math.min(hi, math.floor(v)))
	end
	for _, m in ipairs({ s.permanent, s.liri }) do
		m.gems_per_kill = clamp(m.gems_per_kill, 0, 99)
		m.super_frenzy_heart_multiplier = clamp(m.super_frenzy_heart_multiplier, 1, 20)
		-- (0.4.2) the multiplier's extra stop at this many of a boss's hearts held (0: no cap)
		local cap = m.super_frenzy_heart_cap
		m.super_frenzy_heart_cap = cap == false and 0 or clamp(tonumber(cap) or 30, 0, 999)
	end
	s.liri.corestone_multiplier = clamp(s.liri.corestone_multiplier, 1, 5)
	s.liri.gift_multiplier = clamp(s.liri.gift_multiplier, 1, 5)
	s.nightly.double_amount = math.max(1, math.floor(s.nightly.double_amount))
	Common.settings = s
	return s
end

----------------------------------------------------------------------------
-- Gear

Common.ARMOUR_SLOTS = { "HEAD", "BODY", "WAIST" }

-- The 7 main bosses with a Morphic gem; the final boss's own armour is the Morphic set.
Common.MAIN_BOSSES = {
	megatreemon = true, owlitzer = true, bandicoot = true, thatcher = true,
	sedament = true, eggzy = true, grimhollow = true,
}
Common.MORPHIC_SET = "tefframech"
Common.GEM_CAP = 3 -- the game's MORPHIC_GEMS_PER_BOSS

-- the game's order (WEAPON_ORDER in constants.lua)
Common.WEAPON_TYPES = { "HAMMER", "POLEARM", "BOW", "SHOTPUT", "CANNON", "CLEAVER" }
function Common.WeaponTypes()
	local order = rawget(_G, "WEAPON_ORDER")
	if type(order) == "table" and #order > 0 then
		return order
	end
	return Common.WEAPON_TYPES
end

-- "megatreemon_elite" -> "megatreemon", "yammo_miniboss" -> "yammo",
-- anything of the final boss ("tefframech_phase2", ...) -> "tefframech"
function Common.BossBaseName(prefab)
	if type(prefab) ~= "string" then
		return nil
	end
	if prefab:find("^tefframech") then
		return "tefframech"
	end
	return (prefab:gsub("_elite$", ""):gsub("_miniboss$", ""):gsub("_elite$", ""))
end

function Common.BossName(base)
	return STRINGS ~= nil and STRINGS.NAMES ~= nil and STRINGS.NAMES[base] or base
end

function Common.PrettyName(def)
	return def ~= nil and def.pretty ~= nil and def.pretty.name or (def ~= nil and def.name) or "?"
end

function Common.Notify(icon, title, lines)
	if #lines == 0 or TheFrontEnd == nil or TheFrontEnd.ShowTextNotification == nil then
		return
	end
	pcall(TheFrontEnd.ShowTextNotification, TheFrontEnd, icon, title, table.concat(lines, ", "), 8)
end

-- Give one equipment piece if not owned, at the level the game crafts it at
-- (boss weapons 11, miniboss gear 10: the start of their upgrade path).
-- sync = the hunt's level instead, like a market buy (only for market sets:
-- it can put boss gear below its upgrade path or straight at the top).
function Common.GiveEquipment(player, def, sync)
	local hoard = player.components.inventoryhoard
	if def == nil or hoard == nil or hoard:HasInventoryItem(def) then
		return nil
	end
	local itemforge = require "defs.itemforge"
	local item = itemforge.CreateEquipment(def.slot, def)
	if item == nil then
		return nil
	end
	if sync then
		local ok_c, craftingutil = pcall(require, "util.craftingutil")
		if ok_c and craftingutil.SyncILvlToDungeonDifficulty ~= nil then
			pcall(craftingutil.SyncILvlToDungeonDifficulty, item)
		end
	end
	local unlocks = player.components.unlocktracker
	if unlocks ~= nil and unlocks.UnlockRecipe ~= nil then
		pcall(unlocks.UnlockRecipe, unlocks, def.name)
	end
	hoard:AddToInventory(def.slot, item)
	return item
end

-- The 3 Morphic pieces the player doesn't have yet. Returns the defs given.
function Common.GiveMorphicSet(player)
	local Equipment = require "defs.equipment"
	local given = {}
	for _, slot in ipairs(Common.ARMOUR_SLOTS) do
		local def = Equipment.Items[slot] ~= nil and Equipment.Items[slot][Common.MORPHIC_SET] or nil
		if Common.GiveEquipment(player, def, false) then
			given[#given + 1] = def
		end
	end
	return given
end

----------------------------------------------------------------------------
-- Pickups

-- Every pickup reaches the player as the game's "get_loot" event: enemy drops
-- (Loot), the glowing reward drops after a room or a boss (corestones,
-- Gift-Wrapped Souvenirs, Heartstones, Super Frenzy hearts: konjursouls.lua)
-- and run pickups. The inventory adds it in its own listener, which is
-- registered when the player is made, so it has run by the time ours does.
-- fn(player, def, count) returns how many extra to give.
function Common.WatchPickups(inst, label, fn)
	inst:ListenForEvent("get_loot", function(player, data)
		if data == nil or data.skip_inventory or type(data.item) ~= "table" or type(data.count) ~= "number" then
			return
		end
		if player.IsLocal ~= nil and not player:IsLocal() then
			return
		end
		local ok, err = pcall(function()
			local extra = fn(player, data.item, data.count)
			if extra ~= nil and extra > 0 then
				Common.GiveExtra(player, data.item, extra)
			end
		end)
		if not ok then
			Common.Log(label .. " error: " .. tostring(err))
		end
	end)
end

-- Extra copies of a pickup: into the inventory, and added to the pickup list
-- on screen (the game's display-only event, so it isn't counted twice).
function Common.GiveExtra(player, def, extra)
	local hoard = player.components.inventoryhoard
	if hoard == nil or def.slot == nil then
		return
	end
	hoard:AddStackable(def, extra)
	player:PushEvent("get_loot_display_only", { item = def, count = extra })
end

-- Up to `count` of the boss's Morphic gem (nil = up to the cap), never past the cap.
function Common.GiveGems(player, base, count)
	local ok, EquipmentGem = pcall(require, "defs.equipmentgems.equipmentgem")
	local gem_def = ok and EquipmentGem.FindGemByName ~= nil and EquipmentGem.FindGemByName("morphic_" .. base) or nil
	local hoard = player.components.inventoryhoard
	local gems = player.components.gemmanager
	if gem_def == nil or hoard == nil or gems == nil then
		return 0, gem_def
	end
	local have = hoard:GetGemCountById(gem_def.name) or 0
	count = count or Common.GEM_CAP
	local given = 0
	while given < count and have + given < Common.GEM_CAP do
		local gem = gems:MakeGem(gem_def)
		hoard:AddToInventory(gem.slot, gem)
		given = given + 1
	end
	return given, gem_def, have + given
end

----------------------------------------------------------------------------
-- Market: one piece = the whole set

function Common.OnBoughtEquipment(player, item)
	if item == nil or item.GetDef == nil then
		return
	end
	local def = item:GetDef()
	if def == nil or (def.slot ~= "HEAD" and def.slot ~= "BODY" and def.slot ~= "WAIST") then
		return
	end
	local Equipment = require "defs.equipment"
	local got = {}
	for _, slot in ipairs(Common.ARMOUR_SLOTS) do
		if slot ~= def.slot then
			local other = Equipment.Items[slot] ~= nil and Equipment.Items[slot][def.name] or nil
			if other ~= nil and Common.GiveEquipment(player, other, true) then
				got[#got + 1] = Common.PrettyName(other)
			end
		end
	end
	if #got > 0 then
		Common.Debug(tostring(player) .. " full set: " .. table.concat(got, ", "))
		Common.Notify(def.icon, Common.PrettyName(def), got)
	end
end

-- The market mannequins send the buyer "bought_equipment" (vendingmachine_wares.lua).
function Common.WatchMarketSets(inst)
	inst:ListenForEvent("bought_equipment", function(player, item)
		local ok, err = pcall(Common.OnBoughtEquipment, player, item)
		if not ok then
			Common.Log("market set error: " .. tostring(err))
		end
	end)
end

return Common
