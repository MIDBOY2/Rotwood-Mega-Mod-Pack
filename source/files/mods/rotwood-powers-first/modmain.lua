-- Powers First (Rotwood build 760548)
-- While powers are waiting to be picked, NPCs, meals and everything else you can use are switched off,
-- so a power that lands on one can always be picked. A mod of its own: switch it off (enabled = false in
-- its settings, or take it out of modsettings.lua) and the game is as it was.
-- Settings: scripts/powersfirst_settings.lua

local pcall = GLOBAL.pcall
local next = GLOBAL.next
local TAG = "[Powers First]"

local ok, user_settings = pcall(require, "powersfirst_settings")
if not ok then
	print(TAG .. " powersfirst_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "powersfirst.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in powersfirst_settings.lua)")
	return
end

local ok_r, Interactable = pcall(require, "components.interactable")
if not ok_r then
	print(TAG .. " off: components.interactable: " .. tostring(Interactable))
	return
end
local ok_i, done, why = pcall(Main.InstallInteractable, Interactable)
if not ok_i or not done then
	print(TAG .. " off: " .. tostring(ok_i and why or done))
	return
end

-- the powers (and the crystals) as the game makes them
AddPrefabPostInit(Main.POWER_PREFAB, function(inst)
	Main.AddPower(inst)
end)
AddComponentPostInit("powerdrop", function(cmp, inst)
	Main.AddCrystal(inst)
end)

local parts = { "NPCs, meals and the rest switched off while powers wait to be picked" }
parts[#parts + 1] = settings.only_own_powers and "until that player has picked" or "until every player has picked"
if settings.include_crystal then
	parts[#parts + 1] = "and while the crystal waits"
end
if next(Main.allow) ~= nil then
	local names = {}
	for name in pairs(Main.allow) do
		names[#names + 1] = name
	end
	table.sort(names)
	parts[#parts + 1] = "never: " .. table.concat(names, ", ")
end
print(TAG .. " on: " .. table.concat(parts, "; "))
