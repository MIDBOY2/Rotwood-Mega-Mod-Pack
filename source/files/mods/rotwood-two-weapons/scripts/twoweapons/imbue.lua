-- Two Weapons: the Teffressence Container gem on your second weapon (1.0.13,
-- user 2026-11-14: "this stone only works for the weapon you kill the boss
-- with; if the second weapon has it, it won't unlock").
--
-- The game (defs/powers/gempowers.lua, the gem's power "boss_soul"): on a
-- boss kill at Super Frenzy, if the weapon IN YOUR HAND has the gem and isn't
-- imbued already (and isn't a boss weapon: "superfrenzy" tag), it calls
-- craftingutil.ChargeNormalWeapon: item level 11 if lower, the gem taken out
-- of the weapon and the inventory, weapon.boss_imbued = true (upgrades past
-- level 10). Only the weapon in hand: the gem power only exists for the
-- equipped weapon's gems (and Two Weapons keeps this gem with its own weapon:
-- gems.lua WITH_WEAPON, so it never imbues the wrong one).
-- Here: on the same boss kill (the player's "boss_kill" event, the one the
-- gem uses), the same test for your SECOND weapon, then the game's own
-- ChargeNormalWeapon on it (a stand-in player whose equipped weapon is the
-- second one: everything else is the real player's), and the game's "Imbued!"
-- note with that weapon's name. The weapon in hand stays the game's (its gem
-- power does it). Blight Incursion legs never (the game's).
-- 1.0.14: Frenzy Levels' Super Frenzy side hunt bosses too, when that mod
-- makes the gem work there (super_side_hunts.imbue_gem).
-- settings: second_weapon_imbue = true (false: the game's, the hand only).
local Imbue = {}

Imbue.enabled = false
Imbue.GEM = "boss_soul"
Imbue.DELAY = 2 -- seconds: the game's note comes when the essence reaches the weapon

local errors = 0
local function Log(msg)
	print("[Two Weapons] " .. tostring(msg))
end
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Log("second weapon imbue error: " .. tostring(err))
	end
end

local function NORMAL()
	return rawget(_G, "NORMAL_FRENZY_LEVELS") or 5
end

-- the second weapon (Two Weapons' component)
local function Other(player)
	local cmp = player.components ~= nil and player.components.twoweapons or nil
	if cmp == nil or cmp.GetOther == nil then
		return nil
	end
	local ok, other = pcall(cmp.GetOther, cmp)
	return ok and other or nil
end

-- has this weapon a Teffressence Container gem in a slot?
function Imbue.HasGem(item)
	if item == nil or item.GetGemSlots == nil then
		return false
	end
	for _, slot in ipairs(item:GetGemSlots() or {}) do
		local gem = slot.GetGem ~= nil and slot:GetGem() or nil
		if gem ~= nil then
			local def = gem.GetDef ~= nil and gem:GetDef() or nil
			local id = rawget(gem, "id") or (def ~= nil and def.name) or nil
			if id == Imbue.GEM then
				return true
			end
		end
	end
	return false
end

-- (1.0.14) Frenzy Levels' Super Frenzy side hunts: their boss counts too when
-- that mod says so (its super_side_hunts.imbue_gem; it does the hand weapon)
function Imbue.SideRun()
	local loaded = rawget(_G, "package") ~= nil and package.loaded or nil
	local SS = loaded ~= nil and loaded["frenzylevels.superside"] or nil
	if type(SS) ~= "table" or type(SS.ImbueRun) ~= "function" then
		return false
	end
	local ok, yes = pcall(SS.ImbueRun)
	return ok and yes == true
end

-- the game's test (gem_boss_soul's boss_kill), for the second weapon: the
-- weapon to imbue, or nil
function Imbue.Wants(player)
	local dungeon = rawget(_G, "TheDungeon")
	if dungeon == nil then
		return nil
	end
	local trek = dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek:IsActive() then
		return nil
	end
	local am = dungeon.progression ~= nil and dungeon.progression.components.ascensionmanager or nil
	if am == nil or ((am:GetCurrentLevel() or 0) <= NORMAL() and not Imbue.SideRun()) then
		return nil
	end
	local other = Other(player)
	if other == nil or other.boss_imbued then
		return nil
	end
	local def = other.GetDef ~= nil and other:GetDef() or nil
	if def == nil or (type(def.tags) == "table" and def.tags.superfrenzy) then
		return nil -- (a boss weapon: never, the game's)
	end
	if not Imbue.HasGem(other) then
		return nil
	end
	return other
end

-- the game's ChargeNormalWeapon on this weapon: a stand-in player whose
-- equipped weapon is it (the real inventory, components and player for
-- everything else; its own "absorb_boss_essence" presentation is the hand
-- weapon's, so not sent)
function Imbue.Charge(player, boss, item, craftingutil, weapon_slot)
	local hoard = player.components.inventoryhoard
	local stand_hoard = setmetatable({}, { __index = function(_, k)
		if k == "GetEquippedItem" then
			return function(_, slot, ...)
				if slot == weapon_slot then
					return item
				end
				return hoard:GetEquippedItem(slot, ...)
			end
		end
		local v = hoard[k]
		if type(v) == "function" then
			return function(_, ...)
				return v(hoard, ...)
			end
		end
		return v
	end })
	local components = setmetatable({ inventoryhoard = stand_hoard }, { __index = player.components })
	local stand = setmetatable({ components = components, PushEvent = function() end }, { __index = player })
	craftingutil.ChargeNormalWeapon(stand, boss)
	return item.boss_imbued == true
end

function Imbue.OnBossKill(player, boss)
	if not Imbue.enabled or player == nil or player.components == nil then
		return false
	end
	if player.IsLocal ~= nil and not player:IsLocal() then
		return false
	end
	local item = Imbue.Wants(player)
	if item == nil then
		return false
	end
	if not Imbue.Charge(player, boss, item, Imbue.craftingutil, Imbue.slot) then
		return false
	end
	local def = item:GetDef()
	local name = def ~= nil and def.pretty ~= nil and def.pretty.name or tostring(def and def.name)
	Log("Teffressence Container: the second weapon imbued too (" .. tostring(def and def.name) .. ", item level " .. tostring(item.GetItemLevel ~= nil and item:GetItemLevel() or "?") .. ")")
	local function Note()
		pcall(function()
			local fe = rawget(_G, "TheFrontEnd")
			local s = STRINGS.UI.MECHANIC_TUTORIALS.NORMAL_ITEM_CHARGED_NOTIFICATION
			fe:ShowTextNotification(def.icon, s.TITLE, string.format(s.DESC, name), 10)
		end)
	end
	if player.DoTaskInTime ~= nil then
		player:DoTaskInTime(Imbue.DELAY, Note)
	else
		Note()
	end
	return true
end

-- every player (Main.SetupPlayer)
function Imbue.SetupPlayer(inst)
	if not Imbue.enabled or inst == nil or inst.ListenForEvent == nil then
		return false
	end
	inst:ListenForEvent("boss_kill", function(player, boss)
		local ok, err = pcall(Imbue.OnBossKill, player, boss)
		if not ok then
			Report(err)
		end
	end)
	return true
end

-- deps: craftingutil, Equipment (defaults: the game's). Returns ok, info.
function Imbue.Install(settings, craftingutil, Equipment)
	Imbue.enabled = false
	if type(settings) == "table" and settings.second_weapon_imbue == false then
		return false, "off"
	end
	if craftingutil == nil then
		local ok, cu = pcall(require, "util.craftingutil")
		craftingutil = ok and cu or nil
	end
	if Equipment == nil then
		local ok, eq = pcall(require, "defs.equipment")
		Equipment = ok and eq or nil
	end
	if type(craftingutil) ~= "table" or type(craftingutil.ChargeNormalWeapon) ~= "function" then
		return false, "a game update changed the Teffressence Container (craftingutil.ChargeNormalWeapon)"
	end
	Imbue.craftingutil = craftingutil
	Imbue.slot = type(Equipment) == "table" and type(Equipment.Slots) == "table" and Equipment.Slots.WEAPON or "WEAPON"
	Imbue.enabled = true
	return true, "the Teffressence Container imbues the second weapon too"
end

return Imbue
