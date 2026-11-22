-- Fast Load (Rotwood build 760548)
-- Shorter loading screens: the game looks for each of its art files in every
-- mod folder first (one disk check per mod per file, every load). This lists
-- each mod folder once and skips the folders that don't have the file.
-- Quiet looks: skips the art calls that re-apply what a character already
-- shows (the "Could not find anim build FROMNUM" log spam).
-- Settings: scripts/fastload_settings.lua

local pcall = GLOBAL.pcall

local Main = require "fastload.main"

local ok, user_settings = pcall(require, "fastload_settings")
if not ok then
	Main.Log("fastload_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings = Main.LoadSettings(user_settings)

-- quiet looks: fewer repeated art calls on characters (scripts/fastload/quietlooks.lua)
if settings.quiet_looks then
	local q_ok, Quiet = pcall(require, "fastload.quietlooks")
	if q_ok then
		Quiet.LoadSettings({ report = settings.quiet_looks_report })
		local w_ok, n = pcall(Quiet.InstallClasses, require)
		if not w_ok then
			Main.Log("quiet looks off: " .. tostring(n))
		elseif n == 0 then
			Main.Log("quiet looks off: the game's look code wasn't found")
		else
			Main.Log("quiet looks on (" .. tostring(n) .. " look updates)")
		end
		-- again at the first player: after every mod has added its own wrappers,
		-- so a whole look update (other mods' parts included) counts as one
		local again = false
		if AddPlayerPostInit ~= nil then
			AddPlayerPostInit(function()
				if not again then
					again = true
					pcall(Quiet.InstallClasses, require)
				end
			end)
		end
	else
		Main.Log("quiet looks off: " .. tostring(Quiet))
	end
end

-- hidden-HUD fix: the extra lives counter re-laid out the whole player HUD
-- every frame while a menu hides the HUD (scripts/fastload/hudfix.lua)
if settings.hidden_hud_fix then
	local h_ok, HudFix = pcall(require, "fastload.hudfix")
	local i_ok, done, why = false, false, nil
	if h_ok then
		i_ok, done, why = pcall(HudFix.Install, require)
	end
	if h_ok and i_ok and done then
		Main.Log("hidden-HUD fix on (the extra lives counter rests while a menu hides the HUD)")
	else
		Main.Log("hidden-HUD fix off: " .. tostring(not h_ok and HudFix or not i_ok and done or why))
	end
end

if not settings.enabled then
	Main.Log("file search off (enabled = false in fastload_settings.lua)")
	return
end

local called, installed, info = pcall(Main.Install, GLOBAL)
if not called or not installed then
	Main.Log("off: " .. tostring(called and info or installed))
	return
end

-- a line in client_log.txt each load, when the game registers the mods' prefabs
local ModManager = GLOBAL.rawget(GLOBAL, "ModManager")
if settings.log and ModManager ~= nil and type(ModManager.RegisterPrefabs) == "function" then
	local orig = ModManager.RegisterPrefabs
	ModManager.RegisterPrefabs = function(self, ...)
		pcall(function() Main.Log(Main.Report()) end)
		return orig(self, ...)
	end
end

Main.Log("on")
