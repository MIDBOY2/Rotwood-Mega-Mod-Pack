-- Hunt Rooms: the miniboss's rewards (0.3.0).
--
-- A miniboss room (a main hunt's room 9, the Blight's middle parts, the DLC
-- dragons) gives its Fabled pick and the miniboss's own loot roll (its
-- material draw, gem experience). Now each player also gets, when the
-- miniboss dies, by the hunt's level (settings miniboss_corestones,
-- miniboss_ingots, miniboss_materials, miniboss_teffra; normal / Frenzy 1-5 /
-- Super Frenzy 1-5 / the Blight):
--  * Corestones: the game's own Corestone room reward (0.3.2): when the
--    miniboss room is cleared, a Corestone drop (soul_drop_lesser, what a
--    Corestone room leaves: each hunter takes their own, the take-Corestone
--    animation) next to the Fabled pick, with the miniboss's Corestones for
--    each hunter (at most 5: the game sends the count in 3 bits). There is no
--    Corestone loot drop in the game (0.3.0 put them in the miniboss's loot:
--    "Failed to spawn prefab drop_konjur_soul_lesser"; 0.3.1 gave them
--    straight to the inventory mid-fight, which broke player 2's Corestone
--    counter: the game hides it during a fight). Only when that drop isn't
--    loaded here: given straight to each hunter (0.3.1's way).
--  * the area's ingots: in the miniboss's own loot (the game's lootdropper,
--    so they drop with it, for each player, and the other players' games get
--    them the game's way), only when the game has that drop loaded
--    (PrefabExists("drop_<id>")); otherwise given like the Corestones
--  * a few of the area's materials: the game's own material roll (what a
--    materials room drops: the area's normal materials, imbued ones on
--    Frenzy; never boss material or ingots)
--  * Teffra: the game's own Teffra drop, for that player
-- Once per room (two minibosses in one room give it once). Not in a side
-- hunt's boss room (its boss is a miniboss used as the boss: "boss" there).
-- Frenzy Levels' Super Frenzy loot multiplier and Progression's pickups apply
-- to these as to any drop (Teffra: as the game's). No ingots where the game
-- has none (Tefframech: no_location_loot).
local HR = require "huntrooms.main"

local Loot = {}

Loot.LootEvents = nil
Loot.Consumable = nil
Loot.CDM = nil      -- CraftingDropManager (the room's Corestone drop)
Loot.dropped = nil  -- the room the Corestone drop was made for
Loot.ROOM_DROP = "soul_drop_lesser" -- the game's Corestone room reward
Loot.SOUL_PREFABS = { "soul_drop_konjur_soul_lesser", "soul_drop_konjur_soul_lesser_x2", "soul_drop_konjur_soul_lesser_many" }
Loot.MAX_DROP = 5   -- (components/souldrop.lua DROP_MAXIMUM: the count goes over the network in 3 bits)
Loot.given = {}  -- [room key .. player] = true (once per room)
Loot.room = nil  -- the room the memory is for
Loot.CORESTONE = "konjur_soul_lesser"

local function Dungeon()
	return rawget(_G, "TheDungeon")
end

-- "normal", "frenzy", "super" or "blight", and the level (1-5)
function Loot.Level()
	local dungeon = Dungeon()
	local trek = dungeon ~= nil and dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek.IsActive ~= nil and trek:IsActive() then
		return "blight", 0
	end
	local am = dungeon ~= nil and dungeon.progression ~= nil and dungeon.progression.components ~= nil and dungeon.progression.components.ascensionmanager or nil
	local level = am ~= nil and am.GetCurrentLevel ~= nil and tonumber(am:GetCurrentLevel()) or 0
	level = level or 0
	if level > 5 then
		return "super", math.min(5, level - 5)
	elseif level >= 1 then
		return "frenzy", math.min(5, level)
	end
	return "normal", 0
end

-- The amount of one reward (a Levels table) for this hunt.
function Loot.Amount(t, kind, n)
	if type(t) ~= "table" then
		return 0
	end
	if kind == "frenzy" or kind == "super" then
		local list = t[kind]
		return type(list) == "table" and tonumber(list[n]) or 0
	end
	return tonumber(t[kind]) or 0
end

function Loot.Amounts()
	local s = HR.settings
	local kind, n = Loot.Level()
	return {
		corestones = Loot.Amount(s.miniboss_corestones, kind, n),
		ingots = Loot.Amount(s.miniboss_ingots, kind, n),
		materials = Loot.Amount(s.miniboss_materials, kind, n),
		teffra = Loot.Amount(s.miniboss_teffra, kind, n),
	}, kind, n
end

local function RoomKey()
	local dungeon = Dungeon()
	local ok, wm = pcall(function() return dungeon:GetDungeonMap() end)
	if not ok or wm == nil then
		return nil
	end
	local ok2, id, seed = pcall(function() return wm:GetCurrentRoomId(), wm:GetCurrentRoomSeed() end)
	if not ok2 then
		return nil
	end
	return tostring(seed) .. "/" .. tostring(id)
end

local function InMinibossRoom()
	local w = rawget(_G, "TheWorld")
	local ok, rt = pcall(function() return w:GetCurrentRoomType() end)
	return ok and rt == "miniboss"
end

-- Does the game drop the area's loot here (not Tefframech)?
local function HasLocationLoot()
	local dungeon = Dungeon()
	local ok, loc = pcall(function() return dungeon:GetDungeonMap():GetBiomeLocation() end)
	return not (ok and type(loc) == "table" and loc.no_location_loot)
end

local function Add(t, id, n)
	if n > 0 and id ~= nil then
		t[id] = (t[id] or 0) + n
	end
end

-- Is this prefab loaded here (the game's PrefabExists)? Without it: no.
function Loot.PrefabOK(name)
	local exists = rawget(_G, "PrefabExists")
	if type(exists) ~= "function" or type(name) ~= "string" then
		return false
	end
	local ok, yes = pcall(exists, name)
	return ok and yes == true
end

-- Can this item drop as loot here (the game spawns "drop_<id>")? Without the
-- game's PrefabExists: no (given directly instead).
function Loot.CanDrop(id)
	return type(id) == "string" and Loot.PrefabOK("drop_" .. id)
end

-- Does the room's Corestone drop give the Corestones here?
function Loot.RoomDropReady()
	return Loot.CDM ~= nil and Loot.PrefabOK(Loot.ROOM_DROP)
end

-- Give an item straight to the hunter, the way the game's pickups do
-- (konjursouls.lua / the Corestone pickup: player:PushEvent("get_loot")).
-- Returns true when given.
function Loot.GiveDirect(player, id, n)
	local C = Loot.Consumable
	if n <= 0 or type(C) ~= "table" or type(C.FindItem) ~= "function" or player == nil or player.PushEvent == nil then
		return false
	end
	local ok, def = pcall(C.FindItem, id)
	if not ok or def == nil then
		HR.Log("the miniboss's rewards: " .. tostring(id) .. " isn't one of the game's items, left out")
		return false
	end
	player:PushEvent("get_loot", { item = def, count = n })
	return true
end

-- After the game's own OnLootDropperDeath (one call per local player).
-- Returns true when it added loot (the game then sends it to the others).
function Loot.OnDeath(manager, ent)
	if type(ent) ~= "table" or ent.HasTag == nil or not ent:HasTag("miniboss") or ent:HasTag("boss") then
		return false
	end
	if not InMinibossRoom() then
		return false
	end
	local player = manager.inst
	if player == nil then
		return false
	end
	local key = RoomKey()
	if key == nil then
		return false
	end
	if Loot.room ~= key then
		Loot.room, Loot.given = key, {}
	end
	local pkey = tostring(player.GUID or player)
	if Loot.given[pkey] then
		return false -- (once per room)
	end
	Loot.given[pkey] = true
	local a, kind, n = Loot.Amounts()
	local LE = Loot.LootEvents
	local loot = {}
	local corestones = 0
	if a.corestones > 0 then
		if Loot.RoomDropReady() then
			corestones = math.min(a.corestones, Loot.MAX_DROP) -- (the room's Corestone drop, when the room is cleared)
		elseif Loot.GiveDirect(player, Loot.CORESTONE, a.corestones) then
			corestones = a.corestones
		end
	end
	local ingots = 0
	if a.ingots > 0 and HasLocationLoot() then
		local ok, ingot = pcall(LE.GetIngotForCurrentLocation)
		if ok and type(ingot) == "string" then
			if Loot.CanDrop(ingot) then
				Add(loot, ingot, a.ingots)
				ingots = a.ingots
			elseif Loot.GiveDirect(player, ingot, a.ingots) then
				ingots = a.ingots
			end
		end
	end
	local added = false
	local ld = ent.components ~= nil and ent.components.lootdropper or nil
	if next(loot) ~= nil and ld ~= nil then
		if type(ld.loot_to_drop) == "table" then
			-- added to what the game already has for this player (counts summed)
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
	if a.materials > 0 and HasLocationLoot() then
		LE.SpawnRandomLootForCurrentLocation(ent, { player }, a.materials)
	end
	if a.teffra > 0 then
		local pos = ent.GetPosition ~= nil and ent:GetPosition() or nil
		if pos ~= nil then
			LE.MakeEventSpawnCurrency(a.teffra, pos, player, false, true)
		end
	end
	HR.Debug(string.format("the miniboss's rewards (%s%s): %d Corestones, %d ingots, %d materials, %d Teffra", kind, n > 0 and (" " .. n) or "",
		corestones, ingots, a.materials, a.teffra))
	return added
end

-- The room cleared (CraftingDropManager:OnRoomComplete, the host): in a
-- miniboss room, the Corestone drop, a moment later (after the game's Fabled
-- pick has its spot). Returns true when one is coming.
function Loot.OnRoomComplete(cdm)
	local net = rawget(_G, "TheNet")
	local okh, host = pcall(function() return net:IsHost() end)
	if not (okh and host) or not InMinibossRoom() or not Loot.RoomDropReady() then
		return false
	end
	local a = Loot.Amounts()
	local n = math.min(a.corestones, Loot.MAX_DROP)
	if n <= 0 then
		return false
	end
	local key = RoomKey()
	if key == nil or Loot.dropped == key then
		return false
	end
	Loot.dropped = key
	local w = cdm.inst
	if w == nil or w.DoTaskInTime == nil then
		return Loot.SpawnCorestones(cdm, n) ~= nil
	end
	w:DoTaskInTime(0.5, function()
		local ok, err = pcall(Loot.SpawnCorestones, cdm, n)
		if not ok then
			HR.Log("the miniboss's Corestones: " .. tostring(err))
		end
	end)
	return true
end

-- The game's Corestone room drop (CraftingDropManager:SpawnCraftingDrop: a
-- room_loot spot, its appear delay), each hunter's count n.
function Loot.SpawnCorestones(cdm, n)
	local w = rawget(_G, "TheWorld")
	local pdm = w ~= nil and w.components ~= nil and w.components.powerdropmanager or nil
	local spots = pdm ~= nil and type(pdm.spawners) == "table" and pdm.spawners or {}
	-- the game's power drop took the first spot (its shuffle at room_complete): the last one
	local spawner = #spots >= 2 and spots[#spots] or nil
	if spawner == nil and spots[1] ~= nil then
		local okp, pos = pcall(function() return spots[1]:GetPosition() end)
		local V = rawget(_G, "Vector3")
		if okp and pos ~= nil and V ~= nil then
			local p2 = V(pos.x + 3, 0, pos.z)
			spawner = { GetPosition = function() return p2 end }
		end
	end
	local drop = cdm:SpawnCraftingDrop(spawner, Loot.ROOM_DROP)
	local prefab = Loot.SOUL_PREFABS[math.min(n, #Loot.SOUL_PREFABS)]
	local sd = drop ~= nil and drop.components ~= nil and drop.components.souldrop or nil
	if sd ~= nil and type(sd.SetChildDrops) == "function" and Loot.PrefabOK(prefab) then
		local net = rawget(_G, "TheNet")
		local drops = {}
		for _, p in ipairs(net:GetPlayersOnRoomChange() or {}) do
			drops[p] = { prefab = prefab, count = n }
		end
		sd:SetChildDrops(drops)
	end
	HR.Debug(string.format("the miniboss's Corestones: the room's Corestone drop, %d each", n))
	return drop
end

function Loot.Install(deps)
	if not HR.settings.miniboss_rewards then
		return false, "off"
	end
	local LDM, LE = deps.LootDropManager, deps.LootEvents
	if type(LDM) ~= "table" or type(LDM.OnLootDropperDeath) ~= "function" then
		return false, "a game update changed LootDropManager (the miniboss's loot)"
	end
	if type(LE) ~= "table" or type(LE.GetIngotForCurrentLocation) ~= "function" or type(LE.SpawnRandomLootForCurrentLocation) ~= "function"
		or type(LE.MakeEventSpawnCurrency) ~= "function" then
		return false, "a game update changed LootEvents (the miniboss's loot)"
	end
	local C = deps.Consumable
	if type(C) ~= "table" or type(C.FindItem) ~= "function" then
		return false, "a game update changed Consumable (the game's items)"
	end
	Loot.LootEvents = LE
	Loot.Consumable = C
	local CDM = deps.CraftingDropManager
	if type(CDM) == "table" and type(CDM.OnRoomComplete) == "function" and type(CDM.SpawnCraftingDrop) == "function" then
		Loot.CDM = CDM
		if not rawget(CDM, "huntrooms_miniboss_corestones") then
			rawset(CDM, "huntrooms_miniboss_corestones", true)
			local orig_rc = CDM.OnRoomComplete
			CDM.OnRoomComplete = function(self, ...)
				local r = table.pack(orig_rc(self, ...))
				if HR.On("the miniboss's rewards") then
					HR.Call("the miniboss's rewards", Loot.OnRoomComplete, self)
				end
				return table.unpack(r, 1, r.n)
			end
		end
	else
		Loot.CDM = nil -- (the Corestones straight to each hunter)
	end
	if not rawget(LDM, "huntrooms_miniboss_loot") then
		local orig = LDM.OnLootDropperDeath
		LDM.OnLootDropperDeath = function(self, ent, ...)
			local r = table.pack(orig(self, ent, ...))
			if HR.On("the miniboss's rewards") and type(ent) == "table" and ent.HasTag ~= nil and ent:HasTag("miniboss") then
				local ok, added = HR.Call("the miniboss's rewards", Loot.OnDeath, self, ent)
				if ok and added and not r[1] then
					r[1] = true -- (the game sends this player's loot to the others)
				end
			end
			return table.unpack(r, 1, r.n)
		end
		rawset(LDM, "huntrooms_miniboss_loot", true)
	end
	local s = HR.settings
	local function Line(t)
		return string.format("%d / %d-%d / %d-%d / Blight %d", t.normal, t.frenzy[1], t.frenzy[5], t.super[1], t.super[5], t.blight)
	end
	return true, string.format("Corestones %s (%s), ingots %s, materials %s, Teffra %s (normal / Frenzy / Super Frenzy)",
		Line(s.miniboss_corestones), Loot.CDM ~= nil and "the room's Corestone drop" or "given straight to each hunter",
		Line(s.miniboss_ingots), Line(s.miniboss_materials), Line(s.miniboss_teffra))
end

return Loot
