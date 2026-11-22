-- Save States: a state from the live game, through the game's own saves:
-- the run's map (WorldMap:GetMapData, what the game writes at every door),
-- each local player's run parts (the power manager's, health's, use tracker's
-- and the mods' own OnSave), and what each one wears (the items' BuildSaveData).
local D = require "savestates.data"
local Same = require "savestates.sameroom"

local C = {}

-- set by modmain: the game's tables
C.G = nil       -- GLOBAL
C.Equipment = nil
C.Consumable = nil
C.biomes = nil

local function G()
	return C.G
end

-- local players, by player number
function C.LocalPlayers()
	local g = G()
	local list = {}
	for _, p in ipairs(g.AllPlayers or {}) do
		if p ~= nil and p:IsValid() and p:IsLocal() and p.Network ~= nil and p.components ~= nil
			and p.components.powermanager ~= nil and p.components.inventoryhoard ~= nil then
			list[#list + 1] = p
		end
	end
	table.sort(list, function(a, b) return a.Network:GetPlayerID() < b.Network:GetPlayerID() end)
	return list
end

function C.CharSlot(inst)
	local g = G()
	local ok, slot = pcall(function() return g.TheSaveSystem:GetCharacterForPlayerID(inst.Network:GetPlayerID()) end)
	return ok and slot or nil
end

function C.WeaponClass(id)
	local eq = C.Equipment
	local def = id ~= nil and eq ~= nil and eq.Items.WEAPON[id] or nil
	return def ~= nil and def.weapon_type or nil
end

-- the weapon in hand and the other one (Two Weapons), as items
function C.Weapons(inst)
	local hoard = inst.components.inventoryhoard
	local held = hoard:GetEquippedItem("WEAPON")
	local other = nil
	local tw = inst.components.twoweapons
	if tw ~= nil and tw.GetOther ~= nil then
		local ok, it = pcall(tw.GetOther, tw)
		other = ok and it or nil
	end
	return held, other
end

-- the 2 weapon classes, the one in hand first
function C.Classes(inst)
	local held, other = C.Weapons(inst)
	local list = {}
	local h = held ~= nil and C.WeaponClass(held.id) or nil
	if h ~= nil then
		list[#list + 1] = h
	end
	local o = other ~= nil and C.WeaponClass(other.id) or nil
	if o ~= nil then
		list[#list + 1] = o
	end
	return list, h, o
end

local function GemsOf(item, into)
	local ok = pcall(function()
		for _, gslot in ipairs(item:GetGemSlots()) do
			for _, mount in gslot:GemMounts() do
				local gem = mount:GetGem()
				if gem ~= nil and gem.gem_id ~= nil then
					into[gem.gem_id] = gem:BuildSaveData()
				end
			end
		end
	end)
	return ok
end

local function Gear(inst)
	local hoard = inst.components.inventoryhoard
	local gear = { equips = {}, items = {}, gems = {} }
	for _, slot in pairs(C.Equipment.Slots) do
		local ok, item = pcall(hoard.GetEquippedItem, hoard, slot)
		if ok and item ~= nil and item.id ~= nil and item.BuildSaveData ~= nil then
			gear.equips[slot] = item.id
			gear.items[slot] = item:BuildSaveData()
			GemsOf(item, gear.gems)
		end
	end
	local _, other = C.Weapons(inst)
	if other ~= nil and other.BuildSaveData ~= nil then
		gear.other = other:BuildSaveData()
		GemsOf(other, gear.gems)
	end
	return gear
end

local function PowerCount(pm)
	local n = 0
	local powers = pm and pm.power_data and pm.power_data.powers or {}
	for slot, list in pairs(powers) do
		if not D.NONRUN[slot] and type(list) == "table" then
			for _ in pairs(list) do
				n = n + 1
			end
		end
	end
	return n
end

local function OnSave(cmp)
	if cmp == nil or cmp.OnSave == nil then
		return nil
	end
	local ok, data = pcall(cmp.OnSave, cmp)
	return ok and data or nil
end

function C.Player(inst, n, room_index)
	local c = inst.components
	local pm = c.powermanager:OnSave()
	local health = c.health
	local hp, hpmax = health:GetCurrent(), health:GetMax()
	local hoard = c.inventoryhoard
	local kdef = C.Consumable.Items.MATERIALS.konjur
	local konjur = hoard:GetStackableCount(kdef)
	local krec = nil
	pcall(function()
		local k = hoard.data.inventory.MATERIALS.konjur
		krec = k ~= nil and k:BuildSaveData() or nil
	end)
	local uses = OnSave(c.usetracker)
	local potion = { id = nil, max = 0, remaining = 0 }
	pcall(function()
		local pd = c.potiondrinker
		local def = pd:GetEquippedPotionDef("POTIONS")
		potion.id = def ~= nil and def.name or nil
		potion.max = pd:GetMaxUses()
		potion.remaining = pd:GetRemainingPotionUses()
	end)
	local tw = OnSave(c.twoweapons)
	local classes, held = C.Classes(inst)
	return {
		index = n,
		player_id = inst.Network:GetPlayerID(),
		slot = C.CharSlot(inst),
		name = (pcall(function() return inst:GetCustomUserName() end)) and inst:GetCustomUserName() or nil,
		room_index = room_index,
		powers = pm,
		power_count = PowerCount(pm),
		hp = (hp < hpmax) and hp or nil,
		hp_max = hpmax,
		konjur = konjur,
		konjur_record = krec,
		potion = potion,
		uses = uses ~= nil and uses.tracked_uses or {},
		huntrooms = OnSave(c.huntrooms),
		twoweapons = tw ~= nil and { memory = tw.memory, carried = tw.carried } or nil,
		dungeontracker = OnSave(c.dungeontracker),
		classes = classes,
		held = held,
		gear = Gear(inst),
	}
end

-- can a state be taken now? true, or false and why
function C.CanSave()
	local g = G()
	local dungeon, world = g.TheDungeon, g.TheWorld
	if dungeon == nil or world == nil or not world.is_initialized or world.is_destroying then
		return false, "not in a room right now"
	end
	if dungeon:IsInTown() then
		return false, "there's no run in town"
	end
	local okr, rest = pcall(function() return dungeon:IsInRestRoom() end)
	if okr and rest then
		return false, "a Blight rest room can't be saved (the next leg's first room saves itself)"
	end
	local wm = dungeon:GetDungeonMap()
	if wm == nil or wm.mgrun == nil or not wm.mgrun:IsActive() or wm:IsDebugMap() then
		return false, "not in a run"
	end
	if #C.LocalPlayers() == 0 then
		return false, "no players yet"
	end
	return true
end

function C.Take(kind)
	local g = G()
	local ok, why = C.CanSave()
	if not ok then
		return nil, why
	end
	local wm = g.TheDungeon:GetDungeonMap()
	local map = wm:GetMapData()
	local mg = map.mgrun_data
	local loc = mg.location_id
	local biome = C.biomes.locations[loc]
	if biome == nil then
		return nil, "unknown place " .. tostring(loc)
	end
	local alt = mg.alt_mapgen_id
	local cur = type(mg.current) == "table" and mg.current or {}
	local am = g.TheDungeon.progression.components.ascensionmanager
	local run = {
		location_id = loc,
		region_id = biome.region_id,
		alt_mapgen_id = alt,
		mapgen_name = alt ~= nil and biome.alternate_mapgens ~= nil and biome.alternate_mapgens[alt] or nil,
		seed = mg.mother_seed or map.mother_seed,
		ascension = am ~= nil and am:GetCurrentLevel() or 0,
		is_weather_enabled = map.is_weather_enabled,
		room_id = map.current,
		room_index = cur.index or map.current,
		world_prefab = cur.world or g.TheWorld.prefab,
		scenegen_prefab = g.TheSceneGen ~= nil and g.TheSceneGen.prefab or nil,
		roomtype = cur.roomtype,
		reward = cur.reward,
	}
	-- the room's own enemies for a load (0.5.0: savestates/sameroom.lua); a
	-- note left in the map by a load isn't saved again
	map[Same.KEY] = nil
	local okn, rec = pcall(Same.ForSave, wm)
	run.encounter = okn and rec or nil
	local trek = g.TheDungeon:GetTrek()
	if trek ~= nil and trek:IsActive() then
		run.trek = trek:OnSave()
		run.trek_leg = trek.data.current_leg
		run.trek_stage = trek.data.current_stage
	end
	local players = {}
	for i, inst in ipairs(C.LocalPlayers()) do
		players[i] = C.Player(inst, i, run.room_index)
	end
	local st = {
		v = 1,
		kind = kind,
		time = os.time(),
		build = g.APP_VERSION,
		run = run,
		worldmap = map,
		players = players,
	}
	local okc, err = D.CheckState(st)
	if not okc then
		return nil, err
	end
	return st
end

return C
