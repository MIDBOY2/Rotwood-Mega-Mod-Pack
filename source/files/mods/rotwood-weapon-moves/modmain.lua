-- Weapon Moves (Rotwood build 760548)
-- Moves the game has finished animations for but never uses.
-- Settings: scripts/weaponmoves_settings.lua

local pcall = GLOBAL.pcall

local Main = require "weaponmoves.main"

local ok, user_settings = pcall(require, "weaponmoves_settings")
if not ok then
	Main.Log("weaponmoves_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings, notes = Main.LoadSettings(user_settings)
for _, note in ipairs(notes) do
	Main.Log(note)
end

if not settings.enabled then
	Main.Log("off (enabled = false in weaponmoves_settings.lua)")
	return
end

local parts = {}

-- Bow: the leap shot (weaponmoves/bow.lua), set when the game builds the bow's stategraph
if settings.bow_leap_shot then
	if AddStateGraphPostInit == nil then
		Main.Log("Bow leap shot skipped (no AddStateGraphPostInit)")
	else
		AddStateGraphPostInit("sg_player_bow", function(sg)
			local installed, info = pcall(function()
				return require("weaponmoves.bow").Install(sg)
			end)
			if installed then
				Main.Log(info)
			else
				Main.Log("Bow leap shot skipped (" .. tostring(info) .. "): the game's own roll shots")
			end
		end)
		parts[#parts + 1] = "Bow leap shot"
	end
end

-- Hammer: the spin finale (weaponmoves/hammer.lua); its upswing trail art
-- (the hammer bank's smear painted like the gold swipes)
Assets = {}
if settings.hammer_spin_finale then
	table.insert(Assets, Asset("ANIM", "anim/weaponmoves_hammer_smear.zip"))
	table.insert(Assets, Asset("ANIM", "anim/weaponmoves_hammer_focus.zip")) -- the rise's Focus overlay
end
if settings.hammer_spin_finale then
	if AddStateGraphPostInit == nil then
		Main.Log("Hammer spin finale skipped (no AddStateGraphPostInit)")
	else
		AddStateGraphPostInit("sg_player_hammer", function(sg)
			local installed, info = pcall(function()
				return require("weaponmoves.hammer").Install(sg)
			end)
			if installed then
				Main.Log(info)
			else
				Main.Log("Hammer spin finale skipped (" .. tostring(info) .. "): B in the spin does nothing, as in the game")
			end
		end)
		parts[#parts + 1] = "Hammer spin finale"
	end
end

-- Hammer: a short log of what the hammer does with your presses (weaponmoves/presslog.lua)
if settings.hammer_input_log and AddPlayerPostInit ~= nil then
	AddPlayerPostInit(function(inst)
		local ok, err = pcall(function()
			require("weaponmoves.presslog").Attach(inst)
		end)
		if not ok then
			Main.Log("hammer press log skipped: " .. tostring(err))
		end
	end)
	parts[#parts + 1] = "hammer press log"
end

Main.Log("on (" .. (#parts > 0 and table.concat(parts, ", ") or "nothing switched on") .. ")")
