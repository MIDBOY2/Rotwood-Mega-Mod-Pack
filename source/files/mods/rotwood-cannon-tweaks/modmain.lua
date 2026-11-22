-- Cannon Tweaks (Rotwood build 760548)
-- The cannon's weapon powers with your own numbers: Single Shot holds more rounds, Return to Sender
-- costs less range and a catch reloads more, Bottomless Clip refills faster and overheats shorter.
-- A mod of its own: switch it off (enabled = false in its settings, or take it out of modsettings.lua)
-- and every power is as the game has it.
-- Settings: scripts/cannontweaks_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Cannon Tweaks]"

local ok, user_settings = pcall(require, "cannontweaks_settings")
if not ok then
	print(TAG .. " cannontweaks_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "cannontweaks.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in cannontweaks_settings.lua)")
	return
end

local ok_p, Power = pcall(require, "defs.powers")
if not ok_p or type(Power) ~= "table" then
	print(TAG .. " off: the game's powers (defs.powers): " .. tostring(Power))
	return
end

local ok_a, done, summary, any = pcall(Main.Apply, Power)
if not ok_a or not done then
	print(TAG .. " off: " .. tostring(ok_a and summary or done))
	return
end

local extras = {}
if settings.fix_texts and any then
	local ok_t, did, why = pcall(Main.InstallTexts, Power, GLOBAL)
	if not ok_t or not did then
		print(TAG .. " the power texts stay the game's: " .. tostring(ok_t and why or did))
	end
end
if settings.console_command then
	local ok_c, why = pcall(Main.InstallCommand, GLOBAL)
	if ok_c then
		extras[#extras + 1] = "c_cannon() in the console"
	else
		print(TAG .. " no console command: " .. tostring(why))
	end
end

print(TAG .. " on: " .. summary .. (#extras > 0 and ("; " .. table.concat(extras, ", ")) or ""))
