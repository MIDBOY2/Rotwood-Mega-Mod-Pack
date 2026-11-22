-- Character Builds (Rotwood build 760548)
-- Save a whole character as a build and load it onto any character, in any save, on any of your PCs.
-- A mod of its own: switch it off (enabled = false in its settings, or take it out of modsettings.lua)
-- and nothing else changes. Settings: scripts/characterbuilds_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Character Builds]"

local ok, user_settings = pcall(require, "characterbuilds_settings")
if not ok then
	print(TAG .. " characterbuilds_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "characterbuilds.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in characterbuilds_settings.lua)")
	return
end

local ok_i, installed, info = pcall(Main.Install, GLOBAL, settings)
if not ok_i then
	print(TAG .. " off: " .. tostring(installed))
	return
elseif not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

local parts = { tostring(info) }

if settings.mirror_tab then
	local tab_ok, tab_done, tab_why = pcall(function()
		local Tab = require "characterbuilds.tab"
		local W = {
			SelectableBodyPart = require "widgets.ftf.selectablebodypart",
			Text = require "widgets.text",
			Widget = require "widgets.widget",
			ConfirmDialog = require "screens.dialogs.confirmdialog",
		}
		-- the loadout card's pieces (the card is skipped if any is missing)
		for k, path in pairs({ ItemWidget = "widgets.ftf.itemwidget", Image = "widgets.image", DisplayStat = "widgets.ftf.displaystat",
			PlayerLevelBadge = "widgets.ftf.playerlevelbadge", itemforge = "defs.itemforge" }) do
			local ok_w, m = pcall(require, path)
			if ok_w and m ~= nil then
				W[k] = m
			end
		end
		local CharacterScreen = require "screens.character.characterscreen"
		local done, why = Tab.Install(CharacterScreen, W, GLOBAL.TheGameContent)
		if done and settings.key_open ~= "" then
			pcall(require, "input.inputconstants") -- (it sets the global)
			local ok_k, kdone, kwhy = pcall(Tab.InstallKey, CharacterScreen, settings.key_open)
			why = (ok_k and kdone) and (settings.key_open .. " opens it in town") or ("the key is off: " .. tostring(ok_k and kwhy or kdone))
		end
		return done, why
	end)
	if tab_ok and tab_done == true then
		parts[#parts + 1] = "BUILDS tab at the mirror" .. (tab_why ~= nil and (" (" .. tostring(tab_why) .. ")") or "")
	else
		parts[#parts + 1] = "BUILDS tab off: " .. tostring(tab_ok and tab_why or tab_done)
	end
end

if settings.console_commands then
	local c_ok = pcall(function() return require("characterbuilds.console").Install(GLOBAL) end)
	parts[#parts + 1] = c_ok and "console: cb_list() / cb_save(n) / cb_load(n, p, what) / cb_undo()" or "console commands off"
end

print(TAG .. " on: " .. table.concat(parts, "; "))
