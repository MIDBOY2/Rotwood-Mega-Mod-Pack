-- Boss Weapon Passives (Rotwood build 760548)
-- The boss weapons' passives: every boss weapon's power_on_equip is the game's
-- placeholder "equipment_bossweapon_wip" (does nothing). This gives each boss
-- its own passive, shared by its six weapons. Numbers: scripts/bosspassives_settings.lua

local pcall = GLOBAL.pcall

local Main = require "bosspassives.main"

local ok, user_settings = pcall(require, "bosspassives_settings")
if not ok then
	Main.Log("bosspassives_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	-- the powers still exist (empty), so characters saved with them load
	pcall(Main.Install, settings, false)
	Main.Log("off (enabled = false in bosspassives_settings.lua)")
	return
end

local installed, info = pcall(Main.Install, settings)
if not installed then
	Main.Log("off: " .. tostring(info))
	return
end

Main.Log("on (" .. tostring(info) .. ")")
