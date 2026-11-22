-- Progression, permanent mode: a main boss beaten on Super Frenzy gives its gear.
-- Hook: the player's "boss_kill" event. The game sends it to each local player
-- who's there when a boss dies (health.lua), skipping boss parts like
-- Sedament's crow or the final boss's arms (they have "no_boss_kill"). It's
-- the same event the Proto-Weapon uses to take in the boss's essence.

local Common = require "progression.common"

local Permanent = {}

function Permanent.Info(s)
	local parts = {}
	if s.weapons then
		parts[#parts + 1] = "weapons"
	end
	if s.morphic_set then
		parts[#parts + 1] = "Morphic set"
	end
	if s.gems_per_kill >= Common.GEM_CAP then
		parts[#parts + 1] = "all " .. Common.GEM_CAP .. " gems"
	elseif s.gems_per_kill > 0 then
		parts[#parts + 1] = s.gems_per_kill .. (s.gems_per_kill == 1 and " gem" or " gems") .. " per kill"
	end
	parts[#parts + 1] = s.super_frenzy_only and "Super Frenzy only" or "any level"
	if s.super_frenzy_heart_multiplier > 1 then
		parts[#parts + 1] = "Super Frenzy hearts x" .. s.super_frenzy_heart_multiplier
			.. ((s.super_frenzy_heart_cap or 0) > 0 and (" (the extra up to " .. s.super_frenzy_heart_cap .. " of a boss's, held + in its weapons)") or "")
	end
	if s.super_frenzy_both_weapons then
		parts[#parts + 1] = "Super Frenzy clears for both weapons"
	end
	return table.concat(parts, ", ")
end

-- The weapon types this player holds: the one in hand, then the Two Weapons
-- swap weapon (if that mod is on and a second weapon is set).
function Permanent.HeldWeaponTypes(player)
	local types, seen = {}, {}
	local function add(wtype)
		if type(wtype) == "string" and wtype ~= "" then
			wtype = wtype:upper()
			if not seen[wtype] then
				seen[wtype] = true
				types[#types + 1] = wtype
			end
		end
	end
	local inv = player.components.inventory
	if inv ~= nil and inv.GetEquippedWeaponType ~= nil then
		add(inv:GetEquippedWeaponType())
	end
	local two = player.components.twoweapons
	if two ~= nil and two.GetOther ~= nil then
		local ok, other = pcall(two.GetOther, two)
		local def = ok and other ~= nil and other.GetDef ~= nil and other:GetDef() or nil
		if def ~= nil then
			add(def.weapon_type)
		end
	end
	return types
end

-- The run counts: Super Frenzy (or any level if super_frenzy_only = false),
-- and not a Blight Incursion leg (the game doesn't charge Proto-Weapons there either).
function Permanent.RunCounts(s)
	if TheDungeon == nil then
		return false
	end
	local ok_t, trek_on = pcall(function()
		local trek = TheDungeon.GetTrek ~= nil and TheDungeon:GetTrek() or nil
		return trek ~= nil and trek:IsActive()
	end)
	if ok_t and trek_on then
		return false
	end
	if not s.super_frenzy_only then
		return true
	end
	local asc = TheDungeon.progression ~= nil and TheDungeon.progression.components.ascensionmanager or nil
	if asc == nil then
		return false
	end
	if asc.IsSuperFrenzy ~= nil then
		return asc:IsSuperFrenzy()
	end
	return (asc:GetCurrentLevel() or 0) > (rawget(_G, "NORMAL_FRENZY_LEVELS") or 5)
end

function Permanent.Reward(player, base, s)
	local Equipment = require "defs.equipment"
	local items = Equipment.Items
	local got, icon = {}, nil
	local main_boss = Common.MAIN_BOSSES[base]

	if s.weapons and main_boss then
		for _, wtype in ipairs(Permanent.HeldWeaponTypes(player)) do
			local def = items.WEAPON ~= nil and items.WEAPON[wtype:lower() .. "_" .. base] or nil
			if Common.GiveEquipment(player, def, false) then
				got[#got + 1] = Common.PrettyName(def)
				icon = icon or def.icon
			end
		end
	end

	if s.morphic_set and (main_boss or base == Common.MORPHIC_SET) then
		for _, def in ipairs(Common.GiveMorphicSet(player)) do
			got[#got + 1] = Common.PrettyName(def)
			icon = icon or def.icon
		end
	end

	if s.gems_per_kill > 0 and main_boss then
		local n, gem_def, have = Common.GiveGems(player, base, s.gems_per_kill)
		if n > 0 then
			got[#got + 1] = Common.PrettyName(gem_def) .. " (" .. have .. "/" .. Common.GEM_CAP .. ")"
			icon = icon or gem_def.icon
		end
	end

	if #got > 0 then
		Common.Debug(tostring(player) .. " got " .. table.concat(got, ", ") .. " from " .. base)
		Common.Notify(icon, Common.BossName(base), got)
	end
	return got
end

function Permanent.OnBossKill(player, boss, s)
	if player == nil or boss == nil or (player.IsLocal ~= nil and not player:IsLocal()) then
		return nil
	end
	if not Permanent.RunCounts(s) then
		return nil
	end
	local base = Common.BossBaseName(boss.prefab)
	if base == nil or not (Common.MAIN_BOSSES[base] or base == Common.MORPHIC_SET) then
		return nil
	end
	return Permanent.Reward(player, base, s)
end

-- Super Frenzy clears for both weapons. The game records a cleared Super
-- Frenzy level for the weapon type in your hand only (RunManager:Victory ->
-- AscensionManager:CompleteCurrentAscension -> GetEffectiveCompletionLevel),
-- one level up from that weapon's own record. With Two Weapons your swap
-- weapon fought the boss too (and gets the boss's weapon and heart above), so
-- its weapon type gets the clear as well, the same way: one level up from its
-- own record, if this run's level is higher.
function Permanent.CreditSwapWeapons(am)
	local dungeon = rawget(_G, "TheDungeon")
	if dungeon == nil or am == nil then
		return 0
	end
	local trek = dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek:IsActive() then
		return 0 -- (the game doesn't count Blight Incursion legs either)
	end
	local current = tonumber(am.current) or 0
	if current <= (rawget(_G, "NORMAL_FRENZY_LEVELS") or 5) then
		return 0
	end
	local location_id = dungeon:GetDungeonMap():GetBiomeLocation().id
	local net = rawget(_G, "TheNet")
	local players = net ~= nil and net.GetPlayersOnRoomChange ~= nil and net:GetPlayersOnRoomChange() or {}
	local valid = rawget(_G, "WEAPON_TYPES") or {}
	-- (0.4.1) players whose second weapon Frenzy Levels' Super Frenzy level
	-- skip already recorded this win (with its hearts): left alone
	local done = rawget(am, "frenzylevels_swaps_done")
	local n = 0
	for _, player in ipairs(players) do
		local ut = player.components ~= nil and player.components.unlocktracker or nil
		local inv = player.components ~= nil and player.components.inventory or nil
		if ut ~= nil and inv ~= nil and not (type(done) == "table" and done[player]) then
			local held = inv:GetEquippedWeaponType()
			for _, wtype in ipairs(Permanent.HeldWeaponTypes(player)) do
				if wtype ~= held and valid[wtype] ~= nil then
					local level = ut:GetCompletedAscensionLevel(location_id, wtype)
					if current > level then
						am:SetHighestCompletedAscension(player, location_id, wtype, level + 1)
						n = n + 1
						Common.Log(string.format("Super Frenzy clear for the swap weapon too: %s %s, level %d (held: %s)",
							location_id, wtype, level + 1, tostring(held)))
					end
				end
			end
		end
	end
	return n
end

-- nil (off), or the line for the log when it can't hook
function Permanent.InstallBothClears(s)
	if not s.super_frenzy_both_weapons then
		return nil
	end
	local ok, AM = pcall(require, "components.ascensionmanager")
	if not ok or type(AM) ~= "table" or type(AM.CompleteCurrentAscension) ~= "function"
		or type(AM.SetHighestCompletedAscension) ~= "function" then
		return "Super Frenzy clears: the hand weapon only (a game update changed AscensionManager)"
	end
	if not rawget(AM, "progression_both_clears") then
		local orig = AM.CompleteCurrentAscension
		AM.CompleteCurrentAscension = function(self, ...)
			local results = table.pack(orig(self, ...))
			local okc, err = pcall(Permanent.CreditSwapWeapons, self)
			if not okc then
				Common.Log("Super Frenzy clear for the swap weapon: error " .. tostring(err))
			end
			return table.unpack(results, 1, results.n)
		end
		AM.progression_both_clears = true
	end
	return nil
end

function Permanent.Install(s)
	local problem = Permanent.InstallBothClears(s)
	return Permanent.Info(s) .. (problem ~= nil and ("; " .. problem) or "")
end

-- Super Frenzy hearts (Imbued Heartstones, konjur_heart_elite_<boss>): picking
-- one up gives `super_frenzy_heart_multiplier` of them.
-- (0.4.2, user 2026-11-14: "allows the multiples, but caps the amount to 30")
-- super_frenzy_heart_cap: the extra stops once you hold that many of that
-- boss's hearts (30: what all of its weapons use, 6 weapons x 1 to make + 4
-- upgrades, 11 to 15; the game gives one per Super Frenzy clear, 6 weapons x 5
-- levels = 30). The hearts the game gives (one per clear) are never cut; only
-- the multiplier's extra. Held count unreadable: the extra as before.
-- (0.4.3, user 03:50: "the 30 cap should count the hearts used on weapon
-- upgrades as well") The hearts already in that boss's weapons: 1 for each of
-- its weapons you have (made with a heart, or given) and 1 for each level
-- upgraded past the weapon's start (11; each upgrade costs 1 heart). So
-- held + used <= 30 means you never hold more than its weapons still need
-- (the 6 weapons: 1 to make + 4 upgrades each; one you have counts its make).
-- Boss weapons: the game's WEAPON items named <type>_<boss> with the
-- boss_equipment tag (the names Progression gives them by). nil if unreadable.
function Permanent.HeartsUsed(player, boss)
	local hoard = player.components ~= nil and player.components.inventoryhoard or nil
	if hoard == nil or type(hoard.GetSlotItems) ~= "function" or type(boss) ~= "string" then
		return nil
	end
	local items = hoard:GetSlotItems("WEAPON")
	if type(items) ~= "table" then
		return nil
	end
	local ok_f, itemforge = pcall(require, "defs.itemforge")
	local suffix = "_" .. boss
	local used = 0
	for _, item in pairs(items) do
		local def = type(item) == "table" and item.GetDef ~= nil and item:GetDef() or nil
		local name = def ~= nil and def.name or nil
		local tags = def ~= nil and def.tags or nil
		if type(name) == "string" and name:sub(-#suffix) == suffix and type(tags) == "table" and tags.boss_equipment then
			local base = 11
			if ok_f and type(itemforge) == "table" and type(itemforge.GetBaseILvlFromDef) == "function" then
				local okb, b = pcall(itemforge.GetBaseILvlFromDef, def)
				if okb and type(b) == "number" then
					base = b
				end
			end
			local lvl = item.GetItemLevel ~= nil and item:GetItemLevel() or base
			used = used + 1 + math.max(0, (tonumber(lvl) or base) - base)
		end
	end
	return used
end

function Permanent.HeartExtra(def, count, s, player)
	if s.super_frenzy_heart_multiplier > 1 and type(def.name) == "string" and def.name:find("^konjur_heart_elite_") then
		local extra = count * (s.super_frenzy_heart_multiplier - 1)
		local cap = s.super_frenzy_heart_cap or 0
		if cap > 0 and player ~= nil and player.components ~= nil then
			local hoard = player.components.inventoryhoard
			local ok, held = false, nil
			if hoard ~= nil and type(hoard.GetStackableCount) == "function" then
				ok, held = pcall(hoard.GetStackableCount, hoard, def)
			end
			if ok and type(held) == "number" then
				-- (held: the pickup itself is in already, the game's inventory takes it first)
				local ok_u, used = pcall(Permanent.HeartsUsed, player, def.name:match("^konjur_heart_elite_(.+)$"))
				if not ok_u or type(used) ~= "number" then
					used = 0 -- (unreadable: the held count alone)
				end
				extra = math.max(0, math.min(extra, cap - held - used))
			end
		end
		return extra
	end
	return 0
end

function Permanent.SetupPlayer(inst, s)
	if s.super_frenzy_heart_multiplier > 1 then
		Common.WatchPickups(inst, "heart multiplier", function(player, def, count)
			return Permanent.HeartExtra(def, count, s, player)
		end)
	end
	inst:ListenForEvent("boss_kill", function(player, boss)
		local ok, err = pcall(Permanent.OnBossKill, player, boss, s)
		if not ok then
			Common.Log("boss reward error: " .. tostring(err))
		end
	end)
end

return Permanent
