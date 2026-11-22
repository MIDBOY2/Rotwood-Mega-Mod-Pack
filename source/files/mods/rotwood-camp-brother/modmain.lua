-- Camp Brother (an experiment, Rotwood build 760548)
-- Gishins, Doc Hoggins' brother (sandy tan, red coat, black hat with a red wing), at
-- his station in the camp between Lottie and Toot: Doc's big potion wagon or his red
-- table on a stone floor like the other NPC homes, the road along its front, him on
-- the road. He's a game NPC: he turns to face you and has a Chit Chat (RB).
-- Settings: scripts/campbrother_settings.lua; his lines: scripts/campbrother_strings.lua.
-- Turn it off: enabled = false there, or take the mod out of modsettings.lua.

local pcall = GLOBAL.pcall
local TAG = "[Camp Brother]"

local ok, user_settings = pcall(require, "campbrother_settings")
if not ok then
	print(TAG .. " campbrother_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "campbrother.main"
local settings = Main.LoadSettings(user_settings)
if not settings.enabled then
	print(TAG .. " off (enabled = false in campbrother_settings.lua)")
	return
end

PrefabFiles = { "campbrother_trailer", "campbrother_wagon", "campbrother_potion_table", "campbrother_npc" }

local oks, strings = pcall(require, "campbrother_strings")
if not oks then
	print(TAG .. " campbrother_strings.lua has an error, Gishins won't talk: " .. tostring(strings))
	strings = nil
end

local installed, done, problems = pcall(Main.Install, settings, GLOBAL.require, strings)
if not installed then
	print(TAG .. " off: " .. tostring(done))
	return
end
for _, p in ipairs(problems) do
	print(TAG .. " " .. p)
end
print(TAG .. " on (" .. (#done > 0 and table.concat(done, ", ") or "nothing") .. ")")
