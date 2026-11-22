-- Tonic Swap (Rotwood build 760548)
-- D-pad left / right cycles your tonic. A tonic station (the Potion Table, or
-- the Ironwork Illuminator) opens the potions menu: your potion, and one grid of tonics (A in / out of
-- the cycle, X main tonic, Y cycling off), per player.
-- Settings: scripts/tonicswap_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Tonic Swap]"

local ok, user_settings = pcall(require, "tonicswap_settings")
if not ok then
	print(TAG .. " tonicswap_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "tonicswap.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in tonicswap_settings.lua)")
	return
end

-- The bottles of Bubbling Brew and Misting Mixture in the drink animation:
-- the game never shipped them, so the mod brings its own (anim folder), with
-- the bottle smash in their colours and their empty HUD icons (images).
Assets = {}
if settings.potions ~= false then
	-- their empty-potion HUD icons in Soothing's style, and the talent line's
	-- bottles
	table.insert(Assets, Asset("ATLAS", "images/tonicswap_potions.xml"))
	table.insert(Assets, Asset("IMAGE", "images/tonicswap_potions.tex"))
	if settings.potion_bottles == nil or settings.potion_bottles == "own" then
		table.insert(Assets, Asset("ANIM", "anim/potion_health_bubble.zip"))
		table.insert(Assets, Asset("ANIM", "anim/potion_health_mist.zip"))
		-- the bottle smash with their glass colours
		table.insert(Assets, Asset("ANIM", "anim/fx_player_flask_smash_bubble.zip"))
		table.insert(Assets, Asset("ANIM", "anim/fx_player_flask_smash_mist.zip"))
	end
end

-- the tonics drawn in their grid row's colour (Freeze, Run speed, Grow)
if settings.tonic_colours ~= false then
	table.insert(Assets, Asset("ATLAS", "images/tonicswap_tonics.xml"))
	table.insert(Assets, Asset("IMAGE", "images/tonicswap_tonics.tex"))
end

local installed, info = Main.Install()
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

-- the tonics' effects in the game's current art (before the game loads the
-- powers' prefabs, so the new effects come with them)
if settings.tonic_fx ~= false then
	local fx_ok, done, problems = pcall(function()
		local TonicFx = require "tonicswap.tonicfx"
		return TonicFx.Install(require "stategraphs.sg_common", settings)
	end)
	if not fx_ok then
		print(TAG .. " tonic effects left as the game's: " .. tostring(done))
	else
		print(TAG .. " tonic effects: " .. (#done > 0 and table.concat(done, ", ") or "none")
			.. (#problems > 0 and (" (" .. table.concat(problems, "; ") .. ")") or ""))
	end
end

-- tonic numbers and text (tonicswap/tonictune.lua)
local tune_ok, tune_done, tune_problems = pcall(function()
	return require("tonicswap.tonictune").Install(settings, Main.GetTonics())
end)
if not tune_ok then
	print(TAG .. " tonic numbers / text left as the game's: " .. tostring(tune_done))
elseif #tune_done + #tune_problems > 0 then
	print(TAG .. " tonics: " .. table.concat(tune_done, ", ")
		.. (#tune_problems > 0 and (" (" .. table.concat(tune_problems, "; ") .. ")") or ""))
end

-- the size tonics (Shrink, Juggernaut) reach allies in your potion's reach
local size_ok, SizeAllies = pcall(require, "tonicswap.sizeallies")
local size_on = false
if size_ok then
	local s_ok, on, size_info = pcall(SizeAllies.Install, settings)
	size_on = s_ok and on
	if not s_ok then
		print(TAG .. " size tonics for allies off: " .. tostring(on))
	elseif on then
		print(TAG .. " " .. tostring(size_info))
	elseif size_info ~= "off" then
		print(TAG .. " size tonics for allies off: " .. tostring(size_info))
	end
end
AddPlayerPostInit(function(inst)
	if size_on then
		SizeAllies.SetupPlayer(inst, function(what, fn, ...) return Main.G.Call(what, fn, ...) end)
	end
end)

-- while drinking: the health bar and potion icon over your head move up
local lift = GLOBAL.tonumber(settings.drink_lift) or 0
if lift > 0 then
	local lift_ok, n = pcall(function() return require("tonicswap.drinklift").Install(lift) end)
	if not lift_ok or n < 2 then
		print(TAG .. " drink lift: " .. (lift_ok and (n .. " of 2 widgets found") or tostring(n)))
	end
end

-- Tonic stations: interact (RB) with one in town to open the potions menu.
local Station
local station_ok, station_mod = pcall(require, "tonicswap.station")
if station_ok then
	Station = station_mod
else
	print(TAG .. " tonic menu off: " .. tostring(station_mod))
end

-- the status panel's potion slot and the HUD's frame behind the tonic: hooked
-- when the first player spawns (the game's UI is fully loaded then)
local ui_tried = false
AddPlayerPostInit(function(inst)
	if not ui_tried then
		ui_tried = true
		if settings.status_potion_look ~= false or settings.status_potion_full == true then
			local sp_ok, hooked = pcall(function() return require("tonicswap.tonictune").InstallStatusPotion(settings) end)
			if not sp_ok or not hooked then
				print(TAG .. " status panel potion left as the game's (" .. tostring(sp_ok and "widgets changed" or hooked) .. ")")
			end
		end
		if settings.hud_potion_backing ~= false then
			local hb_ok, hooked = pcall(function() return require("tonicswap.tonictune").InstallHudBacking() end)
			if not hb_ok or not hooked then
				print(TAG .. " HUD frame behind the tonic off (" .. tostring(hb_ok and "widget changed" or hooked) .. ")")
			end
		end
	end
	Main.SetupPlayer(inst)
	if Station ~= nil then
		Station.SetupPlayer(inst)
	end
end)

-- The Potion Table (tonicswap/table.lua): Doc Hoggins' travelling table with
-- the three potions, a tonic station you build in town. Its build menu entry
-- now (before the game loads the town's prefabs, so the town loads it like its
-- own structures); the prop itself comes from the game's prop maker when the
-- game registers the mods' prefabs (scripts/prefabs/tonicswap_potion_table.lua).
if Station ~= nil and settings.potion_table ~= false then
	local table_ok, done, info = pcall(function()
		local PotionTable = require "tonicswap.table"
		local installed, what = PotionTable.Install(settings.potion_table_cost_like)
		if installed then
			PrefabFiles = { "tonicswap_potion_table" }
			table.insert(Assets, Asset("ATLAS", "images/tonicswap_station.xml"))
			table.insert(Assets, Asset("IMAGE", "images/tonicswap_station.tex"))
			Station.own[PotionTable.NAME] = true
			-- a station first in the list (a new list: the settings' own stays as it is)
			local stations = { PotionTable.NAME }
			for _, prefab in ipairs(type(settings.stations) == "table" and settings.stations or {}) do
				if prefab ~= PotionTable.NAME then
					stations[#stations + 1] = prefab
				end
			end
			settings.stations = stations
		end
		return installed, what
	end)
	if not table_ok then
		print(TAG .. " no Potion Table: " .. tostring(done))
	elseif not done then
		print(TAG .. " no Potion Table: " .. tostring(info))
	else
		print(TAG .. " Potion Table in the build menu (Furniture / Usable; " .. tostring(info) .. ")")
	end
end

if Station ~= nil and type(settings.stations) == "table" then
	Station.SetLabels(settings.stations)
	for _, prefab in ipairs(settings.stations) do
		AddPrefabPostInit(prefab, function(inst)
			Station.MakeStation(inst)
		end)
	end
	-- developer console: tonicswap_menu()
	local declare = GLOBAL.rawget(GLOBAL, "global") -- strict mode's way to add a global
	if declare ~= nil then
		declare("tonicswap_menu")
	end
	GLOBAL.tonicswap_menu = function()
		Station.OpenFor(GLOBAL.ConsoleCommandPlayer())
	end
end

print(TAG .. " on (" .. tostring(info) .. " tonics; " .. tostring(Main.potions_info) .. ")")
