-- Progression, nightly mode (game night): a condensed Rotwood.
-- Each feature is its own small hook on the game's own code path:
--   level picker  -> picker.lua (the map's location panel, MapSidebar)
--   boss gear     -> LootDropManager:OnLootDropperDeath (runs per local player
--                    when an enemy with loot dies; bosses / minibosses only)
--   weapon types  -> the player's "on_player_set" event (the character's save
--                    is loaded by then; fires again each room, every step
--                    skips what you already have)
--   double pickup -> the player's "get_loot" event (every pickup: enemy drops,
--                    the reward drops after rooms and bosses, run pickups)
--   market set    -> the player's "bought_equipment" event (market mannequins)

local Common = require "progression.common"

local Nightly = {}

----------------------------------------------------------------------------
-- Boss gear

-- `base`'s weapon of every weapon type (hammer_megatreemon, bow_megatreemon, ...)
function Nightly.BossWeapons(base)
	local Equipment = require "defs.equipment"
	local weapons = Equipment.Items ~= nil and Equipment.Items.WEAPON or nil
	local list = {}
	if weapons == nil then
		return list
	end
	for _, wtype in ipairs(Common.WeaponTypes()) do
		local def = weapons[wtype:lower() .. "_" .. base]
		if def ~= nil and not def.cosmetic_item then
			list[#list + 1] = def
		end
	end
	return list
end

-- A boss / miniboss died: this player gets its gear, at any level. Every step
-- skips what the player already has, so a second kill (or a boss with several
-- parts) adds nothing.
--   every boss / miniboss: its weapon of all 6 weapon types
--   main bosses: the 3 Morphic pieces, its look (mirage), 3 of its Morphic gems
--   the final boss: the 3 Morphic pieces (its own armour)
--   minibosses: their armour set
function Nightly.GrantBossGear(player, base)
	local Equipment = require "defs.equipment"
	local items = Equipment.Items
	local got, icon = {}, nil
	local function note(def, text)
		got[#got + 1] = text or Common.PrettyName(def)
		icon = icon or (def ~= nil and (def.unlock_icon or def.icon)) or nil
	end

	local weapons = 0
	for _, weapon in ipairs(Nightly.BossWeapons(base)) do
		if Common.GiveEquipment(player, weapon, false) then
			weapons = weapons + 1
			icon = icon or weapon.icon
		end
	end
	if weapons > 0 then
		got[#got + 1] = weapons .. (weapons == 1 and " weapon" or " weapons")
	end

	if Common.MAIN_BOSSES[base] or base == Common.MORPHIC_SET then
		for _, def in ipairs(Common.GiveMorphicSet(player)) do
			note(def)
		end
		if Common.MAIN_BOSSES[base] then
			-- its look
			local looks = 0
			for _, slot in ipairs(Common.ARMOUR_SLOTS) do
				local def = items[slot] ~= nil and items[slot][base] or nil
				if def ~= nil and def.cosmetic_item and Common.GiveEquipment(player, def, false) then
					looks = looks + 1
					icon = icon or def.icon
				end
			end
			if looks > 0 then
				got[#got + 1] = Common.BossName(base) .. " look"
			end
			-- its gems
			local n, gem_def = Common.GiveGems(player, base, nil)
			if n > 0 then
				note(gem_def, n .. "x " .. Common.PrettyName(gem_def))
			end
		end
	else
		-- a miniboss: its real armour set
		for _, slot in ipairs(Common.ARMOUR_SLOTS) do
			local def = items[slot] ~= nil and items[slot][base] or nil
			if def ~= nil and not def.cosmetic_item and Common.GiveEquipment(player, def, false) then
				note(def)
			end
		end
	end

	if #got > 0 then
		Common.Debug(tostring(player) .. " got " .. table.concat(got, ", ") .. " from " .. base)
		Common.Notify(icon, Common.BossName(base), got)
	end
	return got
end

local function HookBossGear()
	local LootDropManager = require "components.lootdropmanager"
	local orig = LootDropManager.OnLootDropperDeath
	assert(type(orig) == "function", "LootDropManager:OnLootDropperDeath")
	LootDropManager.OnLootDropperDeath = function(self, ent, ...)
		local results = table.pack(orig(self, ent, ...))
		if ent ~= nil and ent.HasTag ~= nil and (ent:HasTag("boss") or ent:HasTag("miniboss")) then
			local player = self.inst
			local ok, err = pcall(function()
				local base = Common.BossBaseName(ent.prefab)
				if base ~= nil then
					Nightly.GrantBossGear(player, base)
				end
			end)
			if not ok then
				Common.Log("boss gear error: " .. tostring(err))
			end
		end
		return table.unpack(results, 1, results.n)
	end
end

----------------------------------------------------------------------------
-- Double pickups

-- Everything picked up counts double except Teffra (konjur). Heartstones (the
-- first-kill boss hearts) stay single too: depositing one unlocks its boss's
-- talents and uses up every copy you hold, so a second does nothing.
-- Super Frenzy hearts (konjur_heart_elite_*) do double: they're spent on boss
-- weapons and their upgrades.
-- (Revives and reroll pickups bought in a run aren't drops, so this never sees them.)
local NOT_DOUBLED = {
	konjur = true,
}
function Nightly.ShouldDouble(def)
	if def == nil or def.slot ~= "MATERIALS" or type(def.name) ~= "string" then
		return false
	end
	if NOT_DOUBLED[def.name] then
		return false
	end
	if def.name:find("^konjur_heart_") and def.name ~= "konjur_heart_shard"
		and not def.name:find("^konjur_heart_elite_") then
		return false
	end
	return true
end

----------------------------------------------------------------------------
-- All 6 weapon types from the start, with their basic weapon

function Nightly.UnlockWeaponTypes(player)
	local unlocks = player.components.unlocktracker
	local Equipment = require "defs.equipment"
	local got = {}
	for _, wtype in ipairs(Common.WeaponTypes()) do
		if unlocks ~= nil and not unlocks:IsWeaponTypeUnlocked(wtype) then
			unlocks:UnlockWeaponType(wtype)
		end
		local def = Equipment.Items.WEAPON[wtype:lower() .. "_basic"]
		if Common.GiveEquipment(player, def, false) then
			got[#got + 1] = Common.PrettyName(def)
		end
	end
	if #got > 0 then
		Common.Debug(tostring(player) .. " weapons: " .. table.concat(got, ", "))
		Common.Notify(nil, "Game Night", got)
	end
	return got
end

----------------------------------------------------------------------------

function Nightly.SetupPlayer(inst, s)
	if s.double_pickups and s.double_amount > 1 then
		Common.WatchPickups(inst, "double pickups", function(_, def, count)
			return Nightly.ShouldDouble(def) and count * (s.double_amount - 1) or 0
		end)
	end
	if s.all_weapon_types then
		inst:ListenForEvent("on_player_set", function(player)
			if player.IsLocal ~= nil and not player:IsLocal() then
				return
			end
			local ok, err = pcall(Nightly.UnlockWeaponTypes, player)
			if not ok then
				Common.Log("weapon types error: " .. tostring(err))
			end
		end)
	end
	if s.market_full_set then
		Common.WatchMarketSets(inst)
	end
end

function Nightly.Install(s)
	local on, off = {}, {}
	local function try(flag, label, fn)
		if not s[flag] then
			return
		end
		local ok, err = pcall(fn)
		if ok then
			on[#on + 1] = label
		else
			off[#off + 1] = label
			Common.Log(label .. " off: a game update changed " .. tostring(err))
		end
	end
	try("pick_any_level", "pick any level", function() require("progression.picker").Install(Common) end)
	try("boss_gear", "boss gear", HookBossGear)
	if s.double_pickups then
		on[#on + 1] = "double pickups x" .. s.double_amount
	end
	if s.all_weapon_types then
		on[#on + 1] = "all weapon types"
	end
	if s.market_full_set then
		on[#on + 1] = "market full sets"
	end
	local info = #on > 0 and table.concat(on, ", ") or "nothing on"
	if #off > 0 then
		info = info .. "; off: " .. table.concat(off, ", ")
	end
	return info
end

return Nightly
