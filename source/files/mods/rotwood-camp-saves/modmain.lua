-- Camp Saves (Rotwood build 760548)
-- The camp's decoration saves wait until you're done decorating.
-- Settings: scripts/campsaves_settings.lua

-- (the game's mod environment has no assert; it's taken from GLOBAL like pcall)
local pcall, require, assert = GLOBAL.pcall, GLOBAL.require, GLOBAL.assert

local CS = require "campsaves.main"

local ok_s, user_settings = pcall(require, "campsaves_settings")
if not ok_s then
	print(CS.TAG .. " campsaves_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings = CS.LoadSettings(user_settings)
for _, w in ipairs(CS.warnings) do
	CS.Log(w)
end
if not settings.enabled then
	CS.Log("off (enabled = false in campsaves_settings.lua)")
	return
end
if GLOBAL.rawget(GLOBAL, "CampSavesAPI") ~= nil then
	CS.Log("already loaded")
	return
end

-- the camp's DecorManager (made with each camp): its listener swapped
AddComponentPostInit("decormanager", function(mgr, inst)
	local ok, err = pcall(CS.Attach, mgr, inst)
	if not ok then
		CS.Log("this camp saves the game's way (" .. tostring(err) .. ")")
	end
end)

-- the pause menu: held changes saved as it opens (screens/pausescreen.lua, once the game is up)
if settings.save_on_pause then
	AddGamePostInit(function()
		local ok, err = pcall(function()
			local PauseScreen = require "screens.pausescreen"
			assert(type(PauseScreen) == "table" and type(PauseScreen._ctor) == "function", "a game update changed PauseScreen")
			local ctor = PauseScreen._ctor
			PauseScreen._ctor = function(self, ...)
				ctor(self, ...)
				CS.Call("pause menu", CS.OnPause)
			end
		end)
		if not ok then
			CS.Log("pause menu save off (" .. tostring(err) .. ")")
		end
	end)
end

GLOBAL.rawset(GLOBAL, "CampSavesAPI", {
	version = 1,
	Pending = function() return CS.pending end,
	Flush = function(why) return CS.Flush(why or "asked") end,
})

CS.Log(string.format("on: decoration changes save %s s after you leave build mode%s, %d s at most in it (the game's save: every 10 s after any change)",
	tostring(settings.wait_after_build_mode), settings.save_on_pause and " or when the pause menu opens" or "", settings.max_wait))
