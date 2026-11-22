-- Hammer Charge (Rotwood build 760548)
-- Every hammer gets the Sedament hammer's chargeable light attacks.
-- Settings: scripts/hammercharge_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Hammer Charge]"

local ok, user_settings = pcall(require, "hammercharge_settings")
if not ok then
	print(TAG .. " hammercharge_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "hammercharge.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in hammercharge_settings.lua)")
	return
end

local installed, info = Main.Install()
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

AddPlayerPostInit(function(inst)
	Main.SetupPlayer(inst)
end)

print(TAG .. " on (" .. tostring(info) .. ")")
