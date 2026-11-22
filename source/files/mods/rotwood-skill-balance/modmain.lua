-- Skill Balance (Rotwood build 760548)
-- Buffs for weak skills; every number in scripts/skillbalance_settings.lua.

local pcall = GLOBAL.pcall

local Main = require "skillbalance.main"

local ok, user_settings = pcall(require, "skillbalance_settings")
if not ok then
	Main.Log("skillbalance_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	Main.Log("off (enabled = false in skillbalance_settings.lua)")
	return
end

local installed, n, parts, problems = pcall(Main.Install, settings)
if not installed then
	Main.Log("off: " .. tostring(n))
	return
end
for _, p in ipairs(problems) do
	Main.Log(p)
end

-- changes inside a weapon's own stategraph: set when the game builds it
for _, post in ipairs(Main.SG_POST) do
	if AddStateGraphPostInit == nil then
		Main.Log(post.name .. " shots skipped (no AddStateGraphPostInit)")
	else
		AddStateGraphPostInit(post.sg, function(sg)
			local ok, info = pcall(post.fn, sg)
			Main.Log(ok and tostring(info) or (post.name .. " shots skipped (" .. tostring(info) .. ")"))
		end)
	end
end

AddPlayerPostInit(function(inst)
	Main.SetupPlayer(inst)
end)

Main.Log("on (" .. n .. " changes: " .. table.concat(parts, "; ") .. ")")
