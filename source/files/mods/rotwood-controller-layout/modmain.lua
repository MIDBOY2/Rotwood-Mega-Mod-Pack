-- Controller Layout (Rotwood build 760548)
-- Emotes on the right stick; build and customize town on the D-pad.
-- Settings: scripts/controllerlayout_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Controller Layout]"

local ok, user_settings = pcall(require, "controllerlayout_settings")
if not ok then
	print(TAG .. " controllerlayout_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "controllerlayout.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in controllerlayout_settings.lua)")
	return
end

local installed, info = Main.Install()
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

-- the game's "[Debug Menu]" button at the top of the screen in camp and the build
-- number ("REV. 760548"): hidden or shown, each with a key that shows / hides it
-- (controllerlayout/debugbutton.lua)
local function KeyText(key)
	return (type(key) == "string" and key ~= "") and (", " .. key .. " shows / hides it") or ""
end
local db_on = settings.debug_button == "hidden" or settings.debug_button == "shown"
local rev_on = settings.rev_number == "hidden" or settings.rev_number == "shown"
if db_on or rev_on then
	local ok_db, installed, note = pcall(function()
		local constants = GLOBAL.rawget(GLOBAL, "InputConstants")
		local keys = type(constants) == "table" and constants.Keys or nil
		return require("controllerlayout.debugbutton").Install(settings, AddClassPostConstruct, GLOBAL.TheInput, keys)
	end)
	if ok_db and installed then
		if db_on then
			info = info .. "; debug menu button " .. settings.debug_button .. " in camp" .. KeyText(settings.debug_button_key)
		end
		if rev_on then
			info = info .. "; build number " .. settings.rev_number .. KeyText(settings.rev_number_key)
		end
		if note ~= nil then
			print(TAG .. " " .. note)
		end
	else
		print(TAG .. " debug menu button / build number left as the game has them: " .. tostring(ok_db and note or installed))
	end
end

-- what shows over the players' heads (controllerlayout/overhead.lua): Ctrl+H cycles it
local ok_oh, Overhead = pcall(require, "controllerlayout.overhead")
if ok_oh and type(Overhead) == "table" and pcall(Overhead.Setup, GLOBAL, settings) then
	pcall(Overhead.Load)
	if type(AddPlayerPostInit) == "function" then
		AddPlayerPostInit(function(inst)
			pcall(Overhead.SetupPlayer, inst)
		end)
	end
	local function InstallOverhead()
		local ok_i, done, oh_info = pcall(Overhead.Install, GLOBAL)
		if ok_i and done then
			print(TAG .. " overhead: " .. tostring(oh_info))
		else
			print(TAG .. " overhead: the game's (" .. tostring(ok_i and oh_info or done) .. ")")
		end
	end
	if type(AddGamePostInit) == "function" then
		AddGamePostInit(InstallOverhead)
	else
		print(TAG .. " overhead: the game's (the mod loader has no AddGamePostInit)")
	end
else
	print(TAG .. " overhead: the game's (" .. tostring(Overhead) .. ")")
end

print(TAG .. " on (" .. tostring(info) .. ")")
