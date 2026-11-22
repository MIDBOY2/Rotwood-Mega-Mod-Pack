-- Blight Fix (Rotwood build 760548)
-- 1. Keeps the Blight Incursion stage valid when moving to the next leg.
-- 2. The Blight's purple overlay: faded (the default), the game's own or off,
--    Ctrl+B cycles it.
-- Settings: scripts/blightfix_settings.lua

local pcall = GLOBAL.pcall

local BlightFix = require "blightfix"

local ok_s, settings = pcall(require, "blightfix_settings")
if not ok_s or type(settings) ~= "table" then
	print(BlightFix.TAG .. " blightfix_settings.lua has an error, using the defaults: " .. tostring(settings))
	settings = {}
end
if settings.enabled == false then
	print(BlightFix.TAG .. " off (enabled = false in blightfix_settings.lua)")
	return
end

-- 1. the stage
local ok, TrekManager = pcall(require, "components.trekmanager")
if not ok then
	print(BlightFix.TAG .. " off: couldn't load the game's trek code: " .. tostring(TrekManager))
else
	local installed, info = BlightFix.Install(TrekManager)
	if not installed then
		print(BlightFix.TAG .. " off: " .. tostring(info))
	else
		print(BlightFix.TAG .. " on (" .. tostring(info) .. ")")
	end
end

-- 2. the overlay (its own part: an error here leaves the game's overlay)
if settings.overlay == false then
	print(BlightFix.TAG .. " the Blight overlay: the game's own (overlay = false)")
	return
end
local ok_o, Overlay = pcall(require, "blightfix_overlay")
if not ok_o or type(Overlay) ~= "table" then
	print(BlightFix.TAG .. " the Blight overlay: the game's own (couldn't load blightfix_overlay.lua: " .. tostring(Overlay) .. ")")
	return
end
local ok_set, err_set = pcall(Overlay.Setup, GLOBAL, settings)
if not ok_set then
	print(BlightFix.TAG .. " the Blight overlay: the game's own (settings: " .. tostring(err_set) .. ")")
	return
end
pcall(Overlay.Load)

local function InstallOverlay()
	local ok_i, done, info = pcall(Overlay.Install, GLOBAL)
	if not ok_i then
		print(BlightFix.TAG .. " the Blight overlay: the game's own (" .. tostring(done) .. ")")
		return
	elseif not done then
		print(BlightFix.TAG .. " the Blight overlay: the game's own (" .. tostring(info) .. ")")
		return
	end
	print(BlightFix.TAG .. " the Blight overlay: " .. tostring(info))
	-- after the game's debug keys are set up
	local function DebugKeys()
		pcall(Overlay.WrapDebugKeys, GLOBAL)
	end
	local gi = GLOBAL.rawget(GLOBAL, "TheGlobalInstance")
	if gi ~= nil and gi.DoTaskInTime ~= nil then
		gi:DoTaskInTime(0, DebugKeys)
	else
		DebugKeys()
	end
end
-- after the game's start (the HUD file then loads like the game loads it)
if type(AddGamePostInit) == "function" then
	AddGamePostInit(InstallOverlay)
else
	print(BlightFix.TAG .. " the Blight overlay: the game's own (the mod loader has no AddGamePostInit)")
end
