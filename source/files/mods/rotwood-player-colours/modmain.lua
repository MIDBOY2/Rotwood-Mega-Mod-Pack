-- Player Colours (Rotwood build 760548)
-- Each character can have its own player colour (PLAYER COLOUR tab at the
-- mirror). Rides the game's own player colour system: nothing per frame.
-- Settings: scripts/playercolours_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Player Colours]"

local ok, user_settings = pcall(require, "playercolours_settings")
if not ok then
	print(TAG .. " playercolours_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "playercolours.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in playercolours_settings.lua)")
	return
end

local data_ok, data = pcall(require, "playercolours.data")
if not data_ok then
	print(TAG .. " off: data.lua: " .. tostring(data))
	return
end

local installed, info = Main.Install(data, settings)
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

local cmp_ok, cmp_err = pcall(require, "components.playercolour") -- loaded now so AddComponent finds it later
if not cmp_ok then
	print(TAG .. " off: components/playercolour.lua: " .. tostring(cmp_err))
	return
end

-- only the player prefab: other spawns pay nothing
AddPrefabPostInit("player_side", function(inst)
	local s_ok, err = pcall(Main.SetupPlayer, inst)
	if not s_ok then
		print(TAG .. " player setup skipped: " .. tostring(err))
	end
end)

local fx_info = "effects stay vanilla (fx = false)"
if settings.fx then
	local n = Main.HookFx(AddPrefabPostInit)
	local ok_m, m = pcall(Main.HookMachines, AddPrefabPostInit)
	fx_info = n .. " per-player effects follow it" .. ((ok_m and m > 0) and ", and the Spring Port's machines" or (", the Spring Port's machines stay the game's (" .. tostring(m) .. ")"))
end

if settings.farm_signs then
	local ok_s, n_s = pcall(Main.HookSigns, AddPrefabPostInit)
	fx_info = fx_info .. ((ok_s and n_s > 0) and "; the farm plot signs follow it" or ("; the farm plot signs stay the game's (" .. tostring(n_s) .. ")"))
end

local tab_info = "colour tab off in the settings"
if settings.colour_tab then
	local screen_ok, Screen = pcall(require, "playercolours.screen")
	local tab_ok, err = false, Screen
	if screen_ok then
		tab_ok, err = Screen.Install(settings)
	end
	tab_info = tab_ok and "colour tab on" or ("colour tab off: " .. tostring(err))
end

print(TAG .. " on (" .. tostring(info) .. "; " .. tab_info .. "; " .. fx_info .. ")")
