-- Two Weapons: a weapon power for each of your two weapons.
--
-- The game's weapon power room (the run's one choice of two Legendary powers
-- that change a move of a weapon; components/powerdropmanager.lua
-- PreparePowers_WeaponPower) only offers powers for the weapon in your hand:
-- each weapon power needs that weapon's tag (Power.AddWeaponPower adds it to
-- required_tags, and the drop checks the tags of what you have equipped).
--
-- Here, once you've taken one, a second choice flies out of the same crystal
-- for your other weapon:
--  * the same number of powers as the first (your power drop options: 2)
--  * rolled the game's way: its rarity roll and pick (RollRarity,
--    GetRandomPowerOfRarity), the same filters as the game's
--    (CollectWeaponPowerDrops: can drop, not one you have, the weapon's tag,
--    run count, player count, unlocked), with your other weapon's tag in place
--    of the one in your hand
--  * spawned the game's way (SpawnCircleOfPowers: the same spots, assigned to
--    you), and you take one (the game's OnUpdate clears the other); the items
--    carry the game's ignore_power_drop_pickup_limit tag (as the special event
--    rooms' extra powers do), so the room's one-pick limit, already used by the
--    first choice, doesn't block it
-- Rules:
--  * both weapons the same type (two Hammers): no second choice. A weapon power
--    belongs to the weapon type, so the one you take already works on both;
--    a second would give that pair two powers on every swing where a mixed
--    pair gets one each. both_weapon_powers_same_type = true: a second choice
--    of that type anyway, rolled once you've taken the first (not the power
--    you took, nor the one you passed on).
--  * swapping during the scene: both choices are fixed when the crystal opens,
--    the first for the weapon in your hand then, the second for your other
--    weapon. A swap before, between or during the picks changes neither (no
--    reroll, no switch): you end with one power for each weapon. The second
--    comes only if you still carry a weapon of its type when it's due.
--  * no power left for the other weapon (all taken, or none unlocked): none.
--
-- The game's weapon powers already work with the weapon not in your hand: each
-- checks the equipped weapon's type, and its loadout_changed handler sets it up
-- again when the weapon changes (a swap is one), so a swap turns it on.
--
-- A weapon power room where you have none left for the weapon in hand: your
-- other weapon's choice in its place; where nobody has any: the game's normal
-- power pick (not for an extra choice another mod gives, mgr.huntrooms_extra_choice).
--
-- The game's rule for more weapon power rooms (util/mapgenstate.lua
-- CalculateWeaponPowerModifier: none once a player holds 2 weapon powers) is
-- read by rooms here, not powers (a room gives each weapon one): none once a
-- player has had 2 weapon power rooms, as the game would with one weapon. The
-- Hunt Rooms mod, when there, answers it instead (HuntRoomsAPI).
-- The rooms themselves (a weapon power choice at every start, more weapon
-- power and Fabled rooms) are Hunt Rooms'.
--
-- How many weapon powers you keep: the game keeps 4 (Power.MaxCount for the
-- weapon power slot; PowerManager:AddPower removes your oldest to fit a
-- new one), made for one weapon. A power for each weapon fills that twice as
-- fast (the 5th took the place of your first), so here it's twice the game's:
-- 4 for each weapon.
--
-- A choice short of powers: a weapon has only so many, and some exclude each
-- other. The Cannon has 4 but its three ammo powers (Single Shot, Rapid
-- Light, Infinite Ammo: tags and exclusive_tags AMMO_MODIFIER) never go
-- together, so a Cannon gets 2 at most: one ammo power and Bounce Catch
-- Reload. Hammer, Bow and Spear: 4 each. Late in a run a choice may have 1
-- left, or none (user 2026-11-13: P2's Cannon choice was one Cannon power and
-- a normal one, then nothing).
--  * 1.0.8 (user, 03:19): a short choice is filled with other powers, each a
--    Fabled one half the time (weapon_power_fill_fabled = 50; the game's
--    Fabled roll: the run's Fabled families shuffled,
--    GetNumFabledRelicsFromOrderedFamilies) and otherwise the game's normal
--    power pick (GetNumRelics, as PreparePowers_Relic does: its filters, no
--    Fabled modifiers); nothing already in this room's choices. A Cannon with
--    an ammo power: Return to Sender or one of those.
--  * a weapon with nothing left: its turn is a choice of those other powers
--    (your usual number), and your other weapon keeps its own weapon power
--    choice. In hand: the other weapon's choice comes first (the room's),
--    then that weapon's turn; as your second weapon: its turn is the second
--    choice. You still pick twice in the room.
--    (1.0.7 filled from your other weapon's weapon powers instead:
--    weapon_power_fill = "weapon".)
--  * a second choice rolled when the crystal opens is looked at again when it
--    comes out: a power your first pick took or ruled out (one Cannon ammo
--    power rules out the others) is left out and the choice filled again.
-- (Not for an extra choice another mod gives.)
--
-- settings: both_weapon_powers = true (any weapon power room), "first_room"
-- (only when it's the run's first room), false (the game's);
-- both_weapon_powers_same_type = false (two of a type: one choice) / true;
-- weapon_power_limit = "double" (twice the game's), a number, false (the
-- game's); weapon_power_fill = true (short choices and a spent weapon's turn
-- filled with other powers, weapon_power_fill_fabled % of them Fabled),
-- "weapon" (your other weapon's weapon powers first, as 1.0.7), "normal"
-- (normal powers only, as 1.0.2-1.0.6), false (the choice as it is).

local WeaponPowers = {}

WeaponPowers.DELAY = 1.0 -- seconds after the first pick: the leftover power fades first
WeaponPowers.TAGS = { "ignore_power_drop_pickup_limit", "cannot_reroll" }
WeaponPowers.mode = false
WeaponPowers.fill = true -- true: other powers (some Fabled); "weapon": the other weapon's first; "normal": normal powers only; false: none
WeaponPowers.fabled_chance = 50 -- percent of filled powers that are Fabled (fill = true)
WeaponPowers.Random = function(mgr)
	local rng = mgr ~= nil and mgr.rng or nil
	if rng ~= nil and type(rng.Float) == "function" then
		return rng:Float()
	end
	return math.random()
end
WeaponPowers.same_type = false
WeaponPowers.WEAPON_POWER = "weaponpower" -- defs/mapgen.lua Reward

local function Log(msg)
	print("[Two Weapons] " .. tostring(msg))
end
local function Call(what, fn, ...)
	local main = package.loaded["twoweapons.main"]
	local G = type(main) == "table" and main.G or nil
	if G ~= nil then
		return G.Call(what, fn, ...)
	end
	return pcall(fn, ...)
end

local function PlayerOf(pid)
	local guid = TheNet:FindGUIDForPlayerID(pid)
	local player = guid ~= nil and Ents[guid] or nil
	if player ~= nil and player:IsValid() then
		return player
	end
	return nil
end

-- The weapon types in hand and of the other weapon ("HAMMER", "POLEARM"...).
function WeaponPowers.Types(player)
	local c = player ~= nil and player.components or nil
	local cmp = c ~= nil and c.twoweapons or nil
	local inv = c ~= nil and c.inventory or nil
	if cmp == nil or inv == nil then
		return nil, nil
	end
	local other = cmp:GetOther()
	local def = other ~= nil and other.GetDef ~= nil and other:GetDef() or nil
	local wtype = def ~= nil and def.weapon_type or nil
	if type(wtype) ~= "string" or rawget(WEAPON_TYPES, wtype) == nil then
		wtype = nil
	end
	return inv:GetEquippedWeaponType(), wtype
end

-- The other weapon's type, when it isn't the held one's.
function WeaponPowers.OtherType(player)
	local held, wtype = WeaponPowers.Types(player)
	if wtype == nil then
		return nil
	end
	if wtype == held then
		return nil, "both weapons are " .. wtype:lower()
	end
	return wtype
end

-- The game's IsPlayerEligible (powerdropmanager.lua, local), with the other
-- weapon's tag in place of the held one's.
local function Eligible(def, player, tag, held_tag)
	local inv = player.components.inventory
	local function Has(t)
		if t == tag then
			return true
		end
		if t == held_tag then
			return false
		end
		return player:HasTag(t) or inv:HasTag(t)
	end
	for _, t in ipairs(def.required_tags or {}) do
		if not Has(t) then
			return false
		end
	end
	for _, t in ipairs(def.exclusive_tags or {}) do
		if Has(t) then
			return false
		end
	end
	return true
end

-- The game's CollectWeaponPowerDrops for a weapon type (skip: names left out).
function WeaponPowers.Collect(mgr, player, wtype, skip)
	local Power = require "defs.powers"
	local powers = {}
	for _, def in pairs(Power.Items[Power.Slots.WEAPONPOWER] or {}) do
		if def.weapon_power_weapon_type == wtype and not (skip ~= nil and skip[def.name]) then
			powers[#powers + 1] = def
		end
	end
	powers = mgr:FilterByDroppable(powers)
	powers = mgr:FilterByHas(powers, player)
	local tag = wtype:lower()
	local held = player.components.inventory:GetEquippedWeaponTag()
	local eligible = {}
	for _, def in ipairs(powers) do
		if Eligible(def, player, tag, held) then
			eligible[#eligible + 1] = def
		end
	end
	powers = mgr:FilterByRunCount(eligible, player)
	powers = mgr:FilterByPlayerCount(powers)
	powers = mgr:FilterByUnlocked(powers, player)
	return powers
end

-- The game's GetNumWeaponPowers for a weapon type.
function WeaponPowers.Roll(mgr, player, wtype, num, skip)
	local Power = require "defs.powers"
	local options = WeaponPowers.Collect(mgr, player, wtype, skip)
	num = math.min(#options, num)
	local picks = {}
	for _ = 1, num do
		local rarity, lucky = mgr:RollRarity(player, "player_power")
		local pick, result_rarity = mgr:GetRandomPowerOfRarity(options, rarity, true, true)
		if pick then
			picks[#picks + 1] = { name = pick.name, slot = pick.slot, rarity = result_rarity, lucky = lucky, power_type = Power.Types.WEAPON_POWER }
		end
	end
	return picks
end

local function Names(powers)
	local t = {}
	for _, p in ipairs(powers) do
		t[#t + 1] = p.name
	end
	return table.concat(t, ", ")
end

-- The weapon type of a choice (its first weapon power), or nil.
local function ChoiceType(list)
	local Power = require "defs.powers"
	for _, p in ipairs(list or {}) do
		local def = type(p) == "table" and p.name ~= nil and Power.FindPowerByName(p.name) or nil
		local t = type(def) == "table" and def.weapon_power_weapon_type or nil
		if t ~= nil then
			return t
		end
	end
	return nil
end
WeaponPowers.ChoiceType = ChoiceType

-- A choice of wtype short of powers: your other weapon's weapon powers (the
-- one of your two that isn't wtype), the ones in this choice and skip left out.
-- Returns how many were added.
function WeaponPowers.TopUpWeapon(mgr, player, list, n, what, wtype, skip)
	local missing = (tonumber(n) or 0) - #list
	if missing <= 0 or WeaponPowers.fill ~= "weapon" or mgr.huntrooms_extra_choice then
		return 0
	end
	local held, other = WeaponPowers.Types(player)
	wtype = wtype or ChoiceType(list) or held
	local alt = (wtype == held) and other or held
	if alt == nil or alt == wtype or rawget(WEAPON_TYPES, alt) == nil then
		return 0
	end
	local names = {}
	for k in pairs(skip or {}) do
		names[k] = true
	end
	for _, p in ipairs(list) do
		names[p.name] = true
	end
	local picks = WeaponPowers.Roll(mgr, player, alt, missing, names)
	local roller = TheDungeon.progression ~= nil and TheDungeon.progression.components.powerroller or nil
	for _, p in ipairs(picks) do
		list[#list + 1] = p
		if roller ~= nil then
			roller:AddSeenPower(player, p.name, p.slot)
		end
	end
	if #picks > 0 then
		Log(string.format("weapon power room: %s short of weapon powers, filled with your %s's: %s", what or "a choice", alt:lower(), Names(picks)))
	end
	return #picks
end

-- One Fabled power the game would offer you (its Fabled room's roll: the
-- run's Fabled families in a shuffled order, the first with one for you), or nil.
function WeaponPowers.Fabled(mgr, player, forbidden)
	local roller = TheDungeon.progression ~= nil and TheDungeon.progression.components.powerroller or nil
	if roller == nil or type(roller.GetSelectedFabledFamilies) ~= "function" or type(mgr.GetNumFabledRelicsFromOrderedFamilies) ~= "function" then
		return nil
	end
	local families = roller:GetSelectedFabledFamilies()
	if type(families) ~= "table" or #families == 0 then
		return nil
	end
	if mgr.rng ~= nil and type(mgr.rng.Shuffle) == "function" then
		mgr.rng:Shuffle(families)
	end
	local copy = {}
	for i, name in ipairs(forbidden or {}) do
		copy[i] = name
	end
	local picks = mgr:GetNumFabledRelicsFromOrderedFamilies(player, families, 1, copy)
	local p = type(picks) == "table" and picks[1] or nil
	if p == nil or p.name == nil then
		return nil
	end
	return p
end

-- A choice filled up to n (the powers already in it and skip left out):
--  fill = true: other powers, each a Fabled one fabled_chance % of the time
--    (else, or with no Fabled left for you, the game's normal power pick)
--  fill = "weapon": your other weapon's weapon powers first, then normal powers
--  fill = "normal": the game's normal power pick (PreparePowers_Relic's: one
--    at a time, no Fabled modifiers, its filters; GetNumRelics)
-- Returns how many were added.
function WeaponPowers.TopUp(mgr, player, list, n, what, wtype, skip)
	local missing = (tonumber(n) or 0) - #list
	if missing <= 0 or not WeaponPowers.fill or mgr.huntrooms_extra_choice then
		return 0
	end
	local from_weapon = 0
	if WeaponPowers.fill == "weapon" then
		local okw, got = pcall(WeaponPowers.TopUpWeapon, mgr, player, list, n, what, wtype, skip)
		if okw then
			from_weapon = got or 0
		else
			Log("weapon power room: filling with your other weapon's powers failed: " .. tostring(got))
		end
		missing = (tonumber(n) or 0) - #list
		if missing <= 0 then
			return from_weapon
		end
	end
	local forbidden = {}
	for _, p in ipairs(list) do
		forbidden[#forbidden + 1] = p.name
	end
	for name in pairs(skip or {}) do
		forbidden[#forbidden + 1] = name
	end
	local tags = rawget(_G, "POWER_TAGS")
	local no_mods = type(tags) == "table" and tags.FABLED_MOD or nil
	local roller = TheDungeon.progression ~= nil and TheDungeon.progression.components.powerroller or nil
	local added, fabled = {}, 0
	for _ = 1, missing do
		local p = nil
		if WeaponPowers.fill == true and WeaponPowers.Random(mgr) * 100 < WeaponPowers.fabled_chance then
			local okf, got = pcall(WeaponPowers.Fabled, mgr, player, forbidden)
			if okf then
				p = got
				if p ~= nil then
					fabled = fabled + 1
				end
			else
				Log("weapon power room: the Fabled pick failed: " .. tostring(got))
			end
		end
		if p == nil and type(mgr.GetNumRelics) == "function" then
			local okr, got = pcall(mgr.GetNumRelics, mgr, player, 1, nil, forbidden, no_mods)
			if not okr then
				Log("weapon power room: the normal power pick failed: " .. tostring(got))
				break
			end
			p = type(got) == "table" and got[1] or nil
		end
		if p == nil or p.name == nil then
			break
		end
		list[#list + 1] = p
		forbidden[#forbidden + 1] = p.name
		added[#added + 1] = p
		if roller ~= nil then
			roller:AddSeenPower(player, p.name, p.slot)
		end
	end
	if #added > 0 then
		if WeaponPowers.fill == true then
			Log(string.format("weapon power room: %s filled with other powers (%d Fabled of %d): %s", what or "a choice", fabled, #added, Names(added)))
		else
			Log(string.format("weapon power room: %s short of weapon powers, filled with the normal power pick: %s", what or "a choice", Names(added)))
		end
	end
	return from_weapon + #added
end

-- Every player's room choice filled up to their number (a player with no
-- weapon power left for either weapon: a whole normal choice).
function WeaponPowers.FillRoom(mgr)
	for pid, list in pairs(mgr.powers_data or {}) do
		local player = PlayerOf(pid)
		if player ~= nil then
			local n = player.components.powermanager:GetPowerDropOptions()
			if #list < n then
				WeaponPowers.TopUp(mgr, player, list, n, #list == 0 and "no weapon power left for either weapon:" or "the room's choice", ChoiceType(list))
			end
		end
	end
end

-- The weapon powers you keep: twice the game's (or the setting's number).
function WeaponPowers.SetLimit(setting)
	if setting == false then
		return nil
	end
	local Power = require "defs.powers"
	local slots = rawget(Power, "Slots")
	local slot = type(slots) == "table" and slots.WEAPONPOWER or nil
	local max = rawget(Power, "MaxCount")
	if slot == nil or type(max) ~= "table" or type(max[slot]) ~= "number" then
		return nil, "the game's weapon power limit not found (the game's kept)"
	end
	-- (the game's own number, kept once: a second install doesn't double it again)
	local game = rawget(Power, "twoweapons_game_limit") or max[slot]
	rawset(Power, "twoweapons_game_limit", game)
	local want = type(setting) == "number" and math.floor(setting) or game * 2
	max[slot] = math.max(game, want)
	return max[slot], game
end

-- A weapon power room with no weapon power for anyone (none left, or none
-- unlocked, for the weapon in hand): the game's normal power pick instead (the
-- run's first room: its shared one, PreparePowers_RelicShared; any other: each
-- player's own, PreparePowers_Relic).
function WeaponPowers.EmptyRoom(mgr)
	mgr.twoweapons_other_first = nil
	if WeaponPowers.mode ~= false then
		for pid, list in pairs(mgr.powers_data or {}) do
			if #list == 0 then
				WeaponPowers.OtherFirst(mgr, pid, list)
			end
		end
	end
	for _, list in pairs(mgr.powers_data or {}) do
		if #list > 0 then
			return false
		end
	end
	if mgr.huntrooms_extra_choice then
		return false -- an extra choice (Hunt Rooms' start): nothing in its place
	end
	mgr.powers_data = {}
	if TheDungeon:GetDungeonMap():IsCurrentRoomDungeonEntrance() then
		mgr:PreparePowers_RelicShared()
		mgr.shared_drop = true
		Log("the run's start: no weapon power to offer, the normal power pick instead")
	else
		mgr:PreparePowers_Relic()
		Log("weapon power room: no weapon power left to offer, the normal power pick instead")
	end
	return true
end

-- A player with no weapon power left for the weapon in hand (all taken, or none
-- unlocked): the other weapon's choice in its place, as the room's own (the
-- game spawns it), so the room still gives a weapon power; no second choice
-- after it (Prepare).
function WeaponPowers.OtherFirst(mgr, pid, list)
	local player = PlayerOf(pid)
	local wtype = player ~= nil and WeaponPowers.OtherType(player) or nil
	if wtype == nil then
		return false
	end
	local powers = WeaponPowers.Roll(mgr, player, wtype, player.components.powermanager:GetPowerDropOptions())
	if #powers == 0 then
		return false
	end
	local roller = TheDungeon.progression ~= nil and TheDungeon.progression.components.powerroller or nil
	for _, p in ipairs(powers) do
		list[#list + 1] = p
		if roller ~= nil then
			roller:AddSeenPower(player, p.name, p.slot)
		end
	end
	mgr.twoweapons_other_first = mgr.twoweapons_other_first or {}
	mgr.twoweapons_other_first[pid] = true
	Log(string.format("weapon power room: none left for the weapon in hand, your other weapon's choice in its place (%s): %s", wtype:lower(), Names(powers)))
	return true
end

-- A player's weapon powers, by weapon type.
function WeaponPowers.Counts(player)
	local Power = require "defs.powers"
	local counts = {}
	local pm = player.components ~= nil and player.components.powermanager or nil
	for _, pow in ipairs(pm ~= nil and pm:GetPowersOfType(Power.Types.WEAPON_POWER) or {}) do
		local t = pow.def ~= nil and pow.def.weapon_power_weapon_type or nil
		if t ~= nil then
			counts[t] = (counts[t] or 0) + 1
		end
	end
	return counts
end

-- The weapon power rooms the players have had: the most weapon powers one of a
-- player's weapons has (each room gives each weapon one).
function WeaponPowers.RoomsDone(players)
	local rooms = 0
	for _, player in ipairs(players or {}) do
		for _, n in pairs(WeaponPowers.Counts(player)) do
			rooms = math.max(rooms, n)
		end
	end
	return rooms
end

-- The game's rule (CalculateWeaponPowerModifier) by rooms: 0 once a player has
-- had 2 weapon power rooms, else 1. Hunt Rooms' answer first when it's there.
function WeaponPowers.Modifier()
	local api = rawget(_G, "HuntRoomsAPI")
	if type(api) == "table" and type(api.WeaponPowerModifier) == "function" then
		local ok, v = pcall(api.WeaponPowerModifier)
		if ok and type(v) == "number" then
			return v
		end
	end
	return WeaponPowers.RoomsDone(TheNet:GetPlayersOnRoomChange()) >= 2 and 0 or 1
end

-- After the game prepares the room's weapon powers: the other weapon's, per player.
function WeaponPowers.Prepare(mgr)
	mgr.twoweapons_second = nil
	if WeaponPowers.mode == "first_room" and not TheDungeon:GetDungeonMap():IsCurrentRoomDungeonEntrance() then
		return
	end
	local second = {}
	for _, pid in ipairs(TheNet:GetPlayerIDsOnRoomChange()) do
		local player = PlayerOf(pid)
		if player ~= nil and mgr.twoweapons_other_first ~= nil and mgr.twoweapons_other_first[pid] then
			-- the room's choice was already the other weapon's (none left for the one in hand)
			local held, other = WeaponPowers.Types(player)
			local num = player.components.powermanager:GetPowerDropOptions()
			if WeaponPowers.fill == true and held ~= nil and not mgr.huntrooms_extra_choice then
				-- 1.0.8: then the spent weapon's turn, other powers (some Fabled)
				second[pid] = { wtype = held, num = num, filler = true }
				Log("weapon power room: none left for the " .. held:lower() .. ", its turn after your " .. tostring(other):lower() .. "'s choice: other powers")
			elseif WeaponPowers.fill == "weapon" and other ~= nil then
				-- 1.0.7: a second choice of the other weapon
				second[pid] = { wtype = other, num = num, in_place = true }
				Log("weapon power room: none left for the weapon in hand, a second " .. other:lower() .. " choice after the first in its place")
			end
			player = nil
		end
		-- the room's first choice: its powers never in the second
		local first_names = {}
		for _, p in ipairs(mgr.powers_data ~= nil and mgr.powers_data[pid] or {}) do
			if type(p) == "table" and p.name ~= nil then
				first_names[p.name] = true
			end
		end
		if player ~= nil then
			local wtype, why = WeaponPowers.OtherType(player)
			local held, other = WeaponPowers.Types(player)
			if wtype == nil and WeaponPowers.same_type and other ~= nil and other == held then
				-- two of a type: rolled once the first is taken
				second[pid] = { wtype = other, num = player.components.powermanager:GetPowerDropOptions() }
				Log("weapon power room: a second " .. other:lower() .. " choice after the first (both weapons are " .. other:lower() .. ")")
			elseif wtype ~= nil then
				local num = player.components.powermanager:GetPowerDropOptions()
				local powers = WeaponPowers.Roll(mgr, player, wtype, num, first_names)
				if #powers > 0 then
					second[pid] = { powers = powers, wtype = wtype, num = num, first = first_names }
					Log(string.format("weapon power room: your other weapon's choice after the first (%s): %s", wtype:lower(), Names(powers)))
					WeaponPowers.TopUp(mgr, player, powers, num, "your other weapon's choice (" .. wtype:lower() .. ")", wtype, first_names)
				elseif WeaponPowers.fill == true and not mgr.huntrooms_extra_choice then
					-- 1.0.8: the spent weapon's turn, other powers (some Fabled), after the first
					second[pid] = { wtype = wtype, num = num, filler = true, first = first_names }
					Log("weapon power room: no " .. wtype:lower() .. " power left: its turn after the first, other powers")
				else
					Log("weapon power room: no " .. wtype:lower() .. " power left to offer for your other weapon")
				end
			elseif why ~= nil then
				Log("weapon power room: one choice (" .. why .. ")")
			end
		end
	end
	if next(second) ~= nil then
		mgr.twoweapons_second = second
	end
end

-- The crystal's split sound for the second choice. The first choice's
-- pedestals fly out as the crystal shatters, with its sounds (the game's
-- sound_powercrystal on the crystal's shatter: sfx-shatter_crystal and
-- sfx-shatter_tail). The second comes later, the crystal already gone, so it
-- had none: the same two sounds play as the pedestals fly out, once each.
-- 1.0.6: they play from the player whose choice it is, as that player's sound
-- (the game's PlayCodeSound with the player as instigator, how the game plays
-- its own code sounds, heard by everyone). 1.0.4 / 1.0.5 played them from a
-- sound-only entity made where the crystal was, and the user heard nothing.
-- Each play is logged. split_sound = false: no sound.
WeaponPowers.SPLIT_SOUNDS = { "powerCrystal_shatter_crystal", "powerCrystal_shatter_tail" }
WeaponPowers.split_sound = true

function WeaponPowers.SplitSound(pos, player)
	if not WeaponPowers.split_sound then
		return 0
	end
	local fmodtable = require "defs.sound.fmodtable"
	local soundutil = require "util.soundutil"
	local events = {}
	for _, name in ipairs(WeaponPowers.SPLIT_SOUNDS) do
		local ev = type(fmodtable.Event) == "table" and fmodtable.Event[name] or nil
		if ev ~= nil then
			events[#events + 1] = ev
		end
	end
	if #events == 0 then
		Log("the crystal's split sound isn't in the game any more: none")
		return 0
	end
	if player == nil or player.SoundEmitter == nil or (player.IsValid ~= nil and not player:IsValid()) then
		Log("weapon power room: the split sound skipped (no player to play it from)")
		return 0
	end
	local played = 0
	for _, ev in ipairs(events) do
		local ok, err = pcall(soundutil.PlayCodeSound, player, ev, { instigator = player, max_count = 1 })
		if ok then
			played = played + 1
		else
			Log("weapon power room: the split sound: " .. tostring(err))
		end
	end
	if played > 0 then
		Log(string.format("weapon power room: the second choice's split sound (%d of %d, from the player)", played, #events))
	end
	return played
end

-- The second choice, where the first came out.
function WeaponPowers.Spawn(mgr, pid, pending)
	local player = PlayerOf(pid)
	local pos = mgr.twoweapons_second_pos
	if player == nil or pos == nil then
		return
	end
	local held, other = WeaponPowers.Types(player)
	if held ~= pending.wtype and other ~= pending.wtype then
		Log("weapon power room: no " .. pending.wtype:lower() .. " on you any more, no second choice")
		return
	end
	if pending.filler then
		-- a spent weapon's turn: other powers (some Fabled), not the first choice's
		local skip = {}
		for k in pairs(pending.skip or {}) do skip[k] = true end
		for k in pairs(pending.first or {}) do skip[k] = true end
		pending.powers = {}
		WeaponPowers.TopUp(mgr, player, pending.powers, pending.num or 2, "the " .. pending.wtype:lower() .. "'s turn", pending.wtype, skip)
		if #pending.powers == 0 then
			Log("weapon power room: nothing to offer for the " .. pending.wtype:lower() .. "'s turn")
			return
		end
	elseif pending.powers == nil then
		pending.powers = WeaponPowers.Roll(mgr, player, pending.wtype, pending.num or 2, pending.skip)
		if #pending.powers == 0 then
			Log("weapon power room: no other " .. pending.wtype:lower() .. " power left to offer")
			return
		end
		Log(string.format("weapon power room: the second %s choice: %s", pending.wtype:lower(), Names(pending.powers)))
		WeaponPowers.TopUp(mgr, player, pending.powers, pending.num or 2, "the second " .. pending.wtype:lower() .. " choice", pending.wtype, pending.skip)
	else
		-- rolled when the crystal opened: what your first pick took or ruled out goes (1.0.7)
		local okc, kept, dropped = pcall(WeaponPowers.StillOffered, mgr, player, pending.powers)
		if okc and #dropped > 0 then
			pending.powers = kept
			Log(string.format("weapon power room: %s left out of your other weapon's choice (your first pick took it or rules it out)", Names(dropped)))
			local skip = {}
			for k in pairs(pending.skip or {}) do skip[k] = true end
			for k in pairs(pending.first or {}) do skip[k] = true end
			for _, p in ipairs(dropped) do skip[p.name] = true end
			WeaponPowers.TopUp(mgr, player, pending.powers, pending.num or 2, "your other weapon's choice (" .. pending.wtype:lower() .. ")", pending.wtype, skip)
			if #pending.powers == 0 then
				Log("weapon power room: nothing left for your other weapon's choice")
				return
			end
		elseif not okc then
			Log("weapon power room: the second choice's look again failed (" .. tostring(kept) .. "), as rolled")
		end
	end
	local ids = TheNet:GetPlayerIDsOnRoomChange()
	local index = 1
	for i, id in ipairs(ids) do
		if id == pid then
			index = i
		end
	end
	mgr.spawned_poweritems[pid] = {}
	mgr.choices_allowed[pid] = 1
	mgr:SpawnCircleOfPowers(pending.powers, pid, index, math.max(#ids, 1), pos, player)
	if #(mgr.spawned_poweritems[pid] or {}) > 0 then
		Call("weapon power room: the split sound", WeaponPowers.SplitSound, pos, player)
	end
	for _, item in ipairs(mgr.spawned_poweritems[pid] or {}) do
		for _, tag in ipairs(WeaponPowers.TAGS) do
			item:AddTag(tag)
		end
	end
	local roller = TheDungeon.progression ~= nil and TheDungeon.progression.components.powerroller or nil
	if roller ~= nil then
		for _, p in ipairs(pending.powers) do
			roller:AddSeenPower(player, p.name, p.slot)
		end
	end
	mgr.inst:StartUpdatingComponent(mgr)
end

-- The weapon powers of a choice the game's filters still offer you (not taken,
-- not ruled out by exclusive tags of one you have now); other powers kept.
-- Returns kept, dropped.
function WeaponPowers.StillOffered(mgr, player, powers)
	local Power = require "defs.powers"
	local by_type, kept, dropped = {}, {}, {}
	for _, p in ipairs(powers) do
		local def = type(p) == "table" and p.name ~= nil and Power.FindPowerByName(p.name) or nil
		local t = type(def) == "table" and def.weapon_power_weapon_type or nil
		if t ~= nil then
			if by_type[t] == nil then
				local set = {}
				for _, d in ipairs(WeaponPowers.Collect(mgr, player, t)) do
					set[d.name] = true
				end
				by_type[t] = set
			end
			if by_type[t][p.name] then
				kept[#kept + 1] = p
			else
				dropped[#dropped + 1] = p
			end
		else
			kept[#kept + 1] = p
		end
	end
	return kept, dropped
end

local function Done(mgr, second, pid)
	second[pid] = nil
	if mgr.twoweapons_second == second and next(second) == nil then
		mgr.twoweapons_second = nil
	end
end

-- Each update (before the game's): a player who just made their choice gets the
-- other weapon's, a moment later. Counted the way the game's OnUpdate counts.
function WeaponPowers.Check(mgr)
	local second = mgr.twoweapons_second
	if second == nil or mgr.shared_drop then
		return
	end
	local gone = {}
	for pid, pending in pairs(second) do
		if not pending.started then
			local items = mgr.spawned_poweritems[pid]
			local start = mgr.num_powers_to_start[pid]
			local allowed = mgr.choices_allowed[pid]
			if PlayerOf(pid) == nil then
				gone[#gone + 1] = pid
			elseif items ~= nil and start ~= nil and allowed ~= nil then
				local left = 0
				for _, item in ipairs(items) do
					if item ~= nil and item:IsValid() and not item.sg:HasStateTag("despawning") then
						left = left + 1
					end
				end
				if start - left >= allowed then
					pending.started = true
					-- the first choice's powers (a same-type second leaves them out)
					pending.skip = {}
					for _, item in ipairs(items) do
						local wv = item ~= nil and item.components ~= nil and item.components.warevisualizer or nil
						if wv ~= nil and wv.power ~= nil then
							pending.skip[wv.power] = true
						end
					end
					mgr.inst:DoTaskInTime(WeaponPowers.DELAY, function()
						Done(mgr, second, pid)
						Call("weapon power room: the other weapon's choice", WeaponPowers.Spawn, mgr, pid, pending)
					end)
				end
			end
		end
	end
	for _, pid in ipairs(gone) do
		Done(mgr, second, pid)
	end
end

function WeaponPowers.Install(settings)
	local mode = settings.both_weapon_powers
	if mode ~= "first_room" then
		mode = mode ~= false
	end
	WeaponPowers.mode = mode
	WeaponPowers.same_type = settings.both_weapon_powers_same_type == true
	local fill = settings.weapon_power_fill
	if fill == false then
		WeaponPowers.fill = false
	elseif fill == "normal" or fill == "weapon" then
		WeaponPowers.fill = fill
	else
		WeaponPowers.fill = true
	end
	local chance = tonumber(settings.weapon_power_fill_fabled)
	if chance == nil or chance ~= chance then
		chance = 50
	end
	WeaponPowers.fabled_chance = math.max(0, math.min(100, chance))
	WeaponPowers.split_sound = settings.split_sound ~= false
	if mode == false then
		return false, "off"
	end
	local PDM = require "components.powerdropmanager"
	for _, fn in ipairs({ "PreparePowers_WeaponPower", "PreparePowers_RelicShared", "PreparePowers_Relic", "SpawnPowerItems", "OnUpdate", "SpawnCircleOfPowers", "FilterByDroppable", "FilterByHas",
		"FilterByRunCount", "FilterByPlayerCount", "FilterByUnlocked", "RollRarity", "GetRandomPowerOfRarity" }) do
		if type(PDM[fn]) ~= "function" then
			return false, "a game update changed PowerDropManager:" .. fn
		end
	end

	-- the game's rule for more weapon power rooms, by rooms (or Hunt Rooms')
	local rule = false
	local ok_s, MapGenState = pcall(require, "util.mapgenstate")
	if ok_s and type(MapGenState) == "table" and type(MapGenState.CalculateWeaponPowerModifier) == "function" then
		local orig_modifier = MapGenState.CalculateWeaponPowerModifier
		MapGenState.CalculateWeaponPowerModifier = function(...)
			local ok, v = Call("weapon power rooms: the game's rule by rooms", WeaponPowers.Modifier)
			if ok and type(v) == "number" then
				return v
			end
			return orig_modifier(...)
		end
		rule = true
	end

	-- the weapon powers you keep (the game's limit, made for one weapon)
	local limit_setting = settings.weapon_power_limit
	if limit_setting == nil then
		limit_setting = "double"
	end
	local okl, limit, game_limit = pcall(WeaponPowers.SetLimit, limit_setting)
	if not okl then
		Log("the weapon power limit: " .. tostring(limit))
		limit, game_limit = nil, nil
	elseif limit == nil and game_limit ~= nil then
		Log(tostring(game_limit))
		game_limit = nil
	end

	local orig_prepare = PDM.PreparePowers_WeaponPower
	PDM.PreparePowers_WeaponPower = function(self, ...)
		local r = table.pack(orig_prepare(self, ...))
		local ok, empty = Call("weapon power room: no weapon power to offer", WeaponPowers.EmptyRoom, self)
		empty = ok and empty
		if not empty then
			Call("weapon power room: short choices filled", WeaponPowers.FillRoom, self)
			Call("weapon power room: the other weapon's powers", WeaponPowers.Prepare, self)
		end
		return table.unpack(r, 1, r.n)
	end
	local orig_spawn = PDM.SpawnPowerItems
	PDM.SpawnPowerItems = function(self, position, ...)
		if self.twoweapons_second ~= nil then
			self.twoweapons_second_pos = position
		end
		return orig_spawn(self, position, ...)
	end
	local orig_update = PDM.OnUpdate
	PDM.OnUpdate = function(self, ...)
		if self.twoweapons_second ~= nil then
			Call("weapon power room: the first choice", WeaponPowers.Check, self)
		end
		return orig_update(self, ...)
	end
	local info = "a weapon power for each weapon"
	if mode == "first_room" then
		info = info .. " (the first room only)"
	end
	if WeaponPowers.same_type then
		info = info .. ", two of a type: two choices"
	end
	if not rule then
		info = info .. " (the game's weapon power rule by powers: MapGenState.CalculateWeaponPowerModifier not found)"
	end
	if limit ~= nil and game_limit ~= nil and limit ~= game_limit then
		info = info .. string.format(", %d weapon powers kept (the game's %d)", limit, game_limit)
	end
	if not WeaponPowers.fill then
		info = info .. ", short choices not filled"
	elseif WeaponPowers.fill == "normal" then
		info = info .. ", short choices filled with normal powers"
	elseif WeaponPowers.fill == "weapon" then
		info = info .. ", short choices filled with your other weapon's powers"
	end
	return true, info
end

return WeaponPowers
