-- Hunt Rooms (Rotwood build 760548)
-- More legendary weapon power and Fabled rooms; the game's rooms otherwise.
-- Settings: scripts/huntrooms_settings.lua

local pcall, require = GLOBAL.pcall, GLOBAL.require

local HR = require "huntrooms.main"

local ok_s, user_settings = pcall(require, "huntrooms_settings")
if not ok_s then
	print(HR.TAG .. " huntrooms_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings = HR.LoadSettings(user_settings)
for _, w in ipairs(HR.warnings) do
	HR.Log(w)
end
if not settings.enabled then
	HR.Log("off (enabled = false in huntrooms_settings.lua)")
	return
end
if GLOBAL.rawget(GLOBAL, "HuntRoomsAPI") ~= nil then
	HR.Log("already loaded")
	return
end

local function Req(name)
	local ok, m = pcall(require, name)
	return ok and m or nil
end

-- each part on its own: ok and what it does, or why it's off
local lines = {}
local function Part(name, fn, ...)
	local ok, r1, r2 = pcall(fn, ...)
	if ok and r1 then
		lines[#lines + 1] = name .. ": " .. tostring(r2)
		return true
	end
	local why = ok and tostring(r2) or tostring(r1)
	HR.off[name] = why
	if why ~= "off" then
		lines[#lines + 1] = name .. " off (" .. why .. ")"
	end
	return false
end

local Maps = require "huntrooms.maps"
local Doors = require "huntrooms.doors"
local MapGenData = Req("defs.mapgendata")
local MapGenHelp = Req("util.mapgenhelp")

-- a room the map has no odds for (a run saved with other settings): the map's last odds
pcall(Maps.HookClamp, MapGenHelp)

-- the longer maps first: their copies get the doors' hooks too
local maps_ok = Part("longer side hunts", Maps.Install, { MapGenData = MapGenData, biomes = Req("defs.biomes"), paths = Req("prefabs.mappath_autogen_data") })
local doors_ok = Part("rooms", Doors.Install, { MapGenData = MapGenData, MapGenState = Req("util.mapgenstate"), MapGenHelp = MapGenHelp })
if maps_ok and doors_ok and Maps.side_on then
	Part("longer side hunts (the pick)", function()
		local ok, why = Maps.Hook(Req("roomloader"))
		return ok, why or "the game's pick, then the longer copy"
	end)
elseif not doors_ok then
	HR.off["longer side hunts"] = "the rooms part is off"
end

if settings.start_weapon_power and settings.weapon_power_rooms > 0 and doors_ok then
	Part("the start's weapon power", require("huntrooms.freestart").Install, Req("components.powerdropmanager"))
end

local Rewards = require "huntrooms.rewards"
if settings.super_main_reward > 1 and doors_ok then
	if Part("super frenzy room rewards", Rewards.Install, { CraftingDropManager = Req("components.craftingdropmanager"), KonjurRewardManager = Req("components.konjurrewardmanager") }) then
		AddPrefabPostInit("soul_drop_friendgift", function(inst)
			local ok, err = pcall(Rewards.GiftPostInit, inst)
			if not ok then
				HR.Log("gift room reward: the game's (" .. tostring(err) .. ")")
			end
		end)
	end
end

-- 0.3.0: the run's Fabled families, the miniboss's pick and rewards, the Heart Shard room
local Fabled = require "huntrooms.fabled"
Part("the run's Fabled families", Fabled.InstallFamilies, Req("components.powerroller"), Req("defs.powers"))
Part("the miniboss's Fabled pick", Fabled.InstallPick, Req("components.powerdropmanager"))
Part("the miniboss's rewards", require("huntrooms.minibossloot").Install, { LootDropManager = Req("components.lootdropmanager"), LootEvents = Req("lootevents"), Consumable = Req("defs.consumable"), CraftingDropManager = Req("components.craftingdropmanager") })
local Shard = require "huntrooms.shardroom"
if doors_ok then
	Part("the Heart Shard room", Shard.Install, { KonjurRewardManager = Req("components.konjurrewardmanager"), LootEvents = Req("lootevents") })
else
	HR.off["the Heart Shard room"] = "the rooms part is off"
end

-- the run's rooms, kept with each player (lasts through the Blight and a quit)
AddPlayerPostInit(function(inst)
	if inst.components ~= nil and inst.components.huntrooms == nil then
		local ok, err = pcall(function() inst:AddComponent("huntrooms") end)
		if not ok then
			HR.Log("the player's room record: memory only (" .. tostring(err) .. ")")
		end
	end
end)

-- for Two Weapons (its weapon power rule asks this first)
GLOBAL.rawset(GLOBAL, "HuntRoomsAPI", {
	version = 2,
	-- (0.3.0) for Frenzy Levels: is this Hunt Rooms' Heart Shard room (its Heart Shards a fixed number)?
	ShardRoom = function()
		if not HR.On("the Heart Shard room") or not Shard.installed then
			return false
		end
		local ok, yes = HR.Call("the Heart Shard room", Shard.InShardRoom)
		return ok and yes == true
	end,
	WeaponPowerModifier = function()
		if not HR.On("rooms") then
			return nil
		end
		local ok, v = HR.Call("the game's weapon power rule", Doors.WeaponPowerModifier)
		return ok and v or nil
	end,
})

-- console commands for testing (hr_help() lists them): only defined, nothing runs until one is typed
Part("console commands", function()
	return require("huntrooms.console").Register(GLOBAL)
end)

HR.Log(string.format("on: weapon power rooms up to %d, Fabled +%d; %s", settings.weapon_power_rooms, settings.extra_fabled, table.concat(lines, "; ")))
