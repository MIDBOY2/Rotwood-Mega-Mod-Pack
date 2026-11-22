-- Skill Limits (Rotwood build 760548)
-- Strong skills with no limit of their own get charges: 5 uses, refilled 5 s
-- after the last use. Settings: scripts/skilllimits_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Skill Limits]"

local ok, user_settings = pcall(require, "skilllimits_settings")
if not ok then
	print(TAG .. " skilllimits_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "skilllimits.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in skilllimits_settings.lua)")
	return
end

local installed, info = Main.Install(settings)
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

AddPlayerPostInit(function(inst)
	Main.SetupPlayer(inst)
end)

print(TAG .. " on (" .. tostring(info) .. ")")
