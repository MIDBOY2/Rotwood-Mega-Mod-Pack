-- Two Weapons (Rotwood build 760548)
-- Left stick click (keyboard M) swaps between your last two weapons,
-- behind the dodge-cancel puff. Settings: scripts/twoweapons_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Two Weapons]"

local ok, user_settings = pcall(require, "twoweapons_settings")
if not ok then
	print(TAG .. " twoweapons_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "twoweapons.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in twoweapons_settings.lua)")
	return
end

local installed, why = Main.Install()
if not installed then
	print(TAG .. " off: " .. tostring(why))
	return
end

-- weapon memory: the Cannon's ammo survives its own reset on the swap
if Main.memory_installed then
	if AddStateGraphPostInit == nil then
		print(TAG .. " Cannon ammo memory off (no AddStateGraphPostInit): a swap refills it")
	else
		local Memory = require "twoweapons.memory"
		for weapon in pairs(Memory.RESET_ON_LOADOUT) do
			AddStateGraphPostInit("sg_player_" .. weapon, function(sg)
				local ok, n = pcall(Memory.PostInitSG, sg)
				if not ok or n == 0 then
					print(TAG .. " " .. weapon .. " memory: the stategraph's loadout handler not found"
						.. (ok and "" or (" (" .. tostring(n) .. ")")) .. ": a swap may refill it")
				end
			end)
		end
	end
end

AddPlayerPostInit(function(inst)
	Main.SetupPlayer(inst)
end)

-- a new character starts with two random basic weapons (twoweapons/startpair.lua)
local start_info = ""
if settings.starting_pair then
	local okp, StartPair = pcall(require, "twoweapons.startpair")
	if okp then
		local pool, bad = StartPair.Pool(settings.starting_pairs)
		for _, b in ipairs(bad) do
			print(TAG .. " starting_pairs: skipped " .. b)
		end
		local function log(msg)
			print(TAG .. " " .. msg)
		end
		-- their weapon racks in camp unlocked too (the game's modules, read when a character is made)
		local racks = nil
		if settings.starting_pair_unlocks_racks then
			racks = {
				MetaProgress = function() return GLOBAL.require("defs.metaprogression") end,
				dlc_ready = function() return GLOBAL.require("util.dlcutil").IsDracoReady() end,
				ents = function() return GLOBAL.rawget(GLOBAL, "Ents") end,
			}
		end
		AddPlayerPostInit(function(inst)
			local ok, err = pcall(function()
				StartPair.Attach(inst, pool, GLOBAL.require("defs.equipment"), GLOBAL.require("defs.itemforge"), nil, log, racks)
			end)
			if not ok then
				log("new character's weapons off: " .. tostring(err))
			end
		end)
		start_info = " (new characters: 2 random basic weapons, " .. #pool .. " pairs"
			.. (racks ~= nil and ", their racks unlocked)" or ")")
	else
		print(TAG .. " new character's weapons off: " .. tostring(StartPair))
	end
end

print(TAG .. " on" .. start_info)
