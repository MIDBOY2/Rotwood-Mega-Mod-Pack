-- Progression (Rotwood build 760548)
-- One switch in scripts/progression_settings.lua: mode = "off", "permanent", "liri" or "nightly".

local pcall = GLOBAL.pcall

local ok, user_settings = pcall(require, "progression_settings")
local Common = require "progression.common"
if not ok then
	Common.Log("progression_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local settings = Common.LoadSettings(user_settings)
if settings.bad_mode ~= nil then
	Common.Log('mode = "' .. settings.bad_mode .. '" isn\'t "off", "permanent", "liri" or "nightly": using "' .. settings.mode .. '"')
end

if settings.mode == "off" then
	Common.Log('off (mode = "off" in progression_settings.lua)')
	return
end

local Mode = require("progression." .. settings.mode)
local mode_settings = settings[settings.mode]
local info = Mode.Install(mode_settings)

AddPlayerPostInit(function(inst)
	Mode.SetupPlayer(inst, mode_settings)
end)

Common.Log("on: " .. settings.mode .. " (" .. tostring(info) .. ")")
