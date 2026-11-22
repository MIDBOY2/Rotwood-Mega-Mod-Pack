-- Skill Slots (Rotwood build 760548)
-- B (the weapon's skill by default), LT, RT, RS-click: each fires its own skill.
-- Settings: scripts/skillslots_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Skill Slots]"

local ok, user_settings = pcall(require, "skillslots_settings")
if not ok then
	print(TAG .. " skillslots_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Core = require "skillslots.core"
local settings = Core.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in skillslots_settings.lua)")
	return
end

-- the round skill icons for Block and the Cannon's Dodge / Reload, drawn in
-- the style of the game's skill icons (images folder)
Assets = {
	Asset("ATLAS", "images/skillslots_icons.xml"),
	Asset("IMAGE", "images/skillslots_icons.tex"),
}

-- two of the game's unfinished skills, finished (skillslots/finishskills.lua):
-- Explosive Dive and Throw Snowball. Before Core.Install, so the slot hooks
-- wrap the finished skills.
local Finish = require "skillslots.finishskills"
local fin_ok, fin_done = pcall(Finish.Install, user_settings, require("defs.powers"), require("util.powerutil"))
if not fin_ok then
	print(TAG .. " unfinished skills stay the game's: " .. tostring(fin_done))
elseif #fin_done > 0 then
	print(TAG .. " finished the game's unfinished skills: " .. table.concat(fin_done, ", "))
end
if Finish.dive_done and Finish.settings.explosive_dive_trail then
	PrefabFiles = { "skillslots_particles" } -- Explosive Dive's pink crit trail
end
if Finish.snow_done then
	AddPlayerPostInit(function(inst)
		Finish.SetupPlayer(inst, Core.G.Call) -- once: the snowball throw's states
	end)
end

local installed, info = Core.Install()
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

-- Big Blast fired from LT / RT / RS: the real Big Blast (cannon.lua)
local bb_ok, bb_err = pcall(require("skillslots.cannon").KeepBigBlast)
if not bb_ok then
	print(TAG .. " Big Blast hook failed: " .. tostring(bb_err))
end

-- the Cannon's Dodge / Reload: its stategraph's own dodge handling (cannon.lua)
if Core.cannon_installed and AddStateGraphPostInit ~= nil then
	AddStateGraphPostInit("sg_player_cannon", function(sg)
		local ok, err = pcall(require("skillslots.cannon").PostInitSG, sg)
		if not ok then
			print(TAG .. " Cannon stategraph hook failed: " .. tostring(err))
		end
	end)
end

AddPlayerPostInit(function(inst)
	Core.SetupPlayer(inst)
	if Core.Station ~= nil then
		Core.Station.SetupPlayer(inst) -- unlocks the station decorations
	end
end)

-- Skill stations: interact (RB) with one of these decorations in town to open
-- the skill slot menu. List in skillslots_settings.lua. The menu button
-- (D-pad down / H by default) opens it anywhere in town.
if Core.Station ~= nil then
	Core.Station.SetLabels(settings.stations)
	Core.Station.AddMenuButton(settings.menu_button)
	for _, prefab in ipairs(settings.stations) do
		AddPrefabPostInit(prefab, function(inst)
			Core.Station.MakeStation(inst)
		end)
	end
	-- the blacksmith's weapon racks: hold interact (RB) for the menu once the rack's
	-- weapon is unlocked (a tap still does what it did)
	if settings.rack_menu then
		local okr, Rack = pcall(require, "skillslots.rack")
		local okm, MetaProgressStore = pcall(require, "components.metaprogressstore")
		local rack_ok, rack_why = false, okr and MetaProgressStore or Rack
		if okr and okm then
			rack_ok, rack_why = Rack.Install(MetaProgressStore, settings.racks, Core.Station.OpenFromInteraction, Core.Station.CanOpenAt)
		end
		if rack_ok then
			print(TAG .. " weapon racks: hold RB for Customize Skills (" .. #settings.racks .. " racks)")
		else
			print(TAG .. " weapon racks: no skill menu there: " .. tostring(rack_why))
		end
	end
	-- the weapon rack inside Hamish's forge (part of the building's art): press
	-- interact (RB) by it for the menu (skillslots/forgerack.lua)
	if settings.forge_rack ~= false then
		local okf, ForgeRack = pcall(require, "skillslots.forgerack")
		if okf then
			Core.Station.SetLabel(ForgeRack.PREFAB)
			AddPrefabPostInit(ForgeRack.PREFAB, function(inst)
				local ok, made, why = pcall(ForgeRack.Make, inst, Core.Station.MakeStation, Core.Station.CanOpenAt)
				if not ok or not made then
					print(TAG .. " Hamish's forge rack: no skill menu there: " .. tostring(ok and why or made))
				end
			end)
			print(TAG .. " Hamish's forge rack: press RB by it for Customize Skills")
		else
			print(TAG .. " Hamish's forge rack: " .. tostring(ForgeRack))
		end
	end
	-- developer console: skillslots_menu()
	if GLOBAL.global ~= nil then
		GLOBAL.global("skillslots_menu")
	end
	GLOBAL.skillslots_menu = function()
		Core.Station.OpenFor(GLOBAL.ConsoleCommandPlayer())
	end
end

print(TAG .. " on (" .. tostring(info) .. " skills hooked)")
