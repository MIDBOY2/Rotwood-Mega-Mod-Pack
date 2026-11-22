-- Stick Aim (Rotwood build 760548)
-- A controller player's right stick can aim, like the mouse; while it aims the buttons trade places.
-- A mod of its own: switch it off (enabled = false in its settings, or take it out of modsettings.lua)
-- and nothing else changes. Settings: scripts/stickaim_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Stick Aim]"

local ok, user_settings = pcall(require, "stickaim_settings")
if not ok then
	print(TAG .. " stickaim_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "stickaim.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in stickaim_settings.lua)")
	return
end

local ok_i, installed, info = pcall(Main.Install, GLOBAL)
if not ok_i then
	print(TAG .. " off: " .. tostring(installed))
elseif not installed then
	print(TAG .. " off: " .. tostring(info))
else
	print(TAG .. " on: " .. tostring(info))
end
