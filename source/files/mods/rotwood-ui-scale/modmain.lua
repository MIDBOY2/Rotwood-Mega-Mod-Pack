-- UI Scale (Rotwood build 760548)
-- Your character info and the power popup smaller or bigger, each with its own size (and, if you
-- want it, the whole interface). Everything else stays the game's own. A mod of its own: switch it off
-- (enabled = false in its settings, or take it out of modsettings.lua) and the game's own sizes are
-- back. Settings: scripts/uiscale_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[UI Scale]"

local ok, user_settings = pcall(require, "uiscale_settings")
if not ok then
	print(TAG .. " uiscale_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "uiscale.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in uiscale_settings.lua)")
	return
end

-- the sizes picked in the game last time, else the ones in the settings file
local remembered = {}
if settings.remember then
	local ok_r, got = pcall(Main.ReadRemembered, GLOBAL)
	remembered = ok_r and type(got) == "table" and got or {}
end

local parts = {}
for _, z in ipairs(Main.SIZES) do
	local id = z.id
	local start = remembered[id] or settings[id]
	local how = remembered[id] ~= nil and " (picked in the game)" or ""
	local on = true
	if id ~= "whole_interface" then
		local ok_i, done, why = pcall(Main.InstallClass, GLOBAL, id)
		if not ok_i or not done then
			parts[#parts + 1] = z.note .. " off: " .. tostring(ok_i and why or done)
			on = false
		end
	end
	if on then
		local ok_a, applied, why = pcall(Main.Apply, GLOBAL, id, start)
		if not ok_a or not applied then
			parts[#parts + 1] = z.note .. " off: " .. tostring(ok_a and why or applied)
			Main.installed[id] = nil
		else
			parts[#parts + 1] = z.note .. " " .. Main.Pct(Main.current[id]) .. how
			if id == "power_popup" and settings.popup_prompt ~= "none" then
				local ok_p, done, pwhy, labels = pcall(Main.InstallPrompt, GLOBAL)
				if ok_p and done then
					parts[#parts + 1] = settings.popup_prompt == "all" and ("the prompts too" .. (labels and "" or " (not the revive prompt: a game update changed the HUD's prompts)")) or "the pickup prompt too"
				else
					parts[#parts + 1] = "the prompts keep the game's size: " .. tostring(ok_p and pwhy or done)
				end
			end
		end
	end
end

if settings.options_rows then
	local ok_o, done, why = pcall(Main.InstallOptionsRows, GLOBAL)
	parts[#parts + 1] = (ok_o and done) and "Options > Graphics" or ("Options rows off: " .. tostring(ok_o and why or done))
end
do
	pcall(require, "input.inputconstants") -- (it sets the global)
	local ok_k, done, names = pcall(Main.InstallKeys, GLOBAL)
	if ok_k and done then
		parts[#parts + 1] = "keys " .. tostring(names)
	elseif ok_k and names ~= nil and names ~= "" then
		parts[#parts + 1] = "keys off: " .. tostring(names)
	elseif not ok_k then
		parts[#parts + 1] = "keys off: " .. tostring(done)
	end
end
if settings.console_command then
	pcall(Main.InstallCommand, GLOBAL)
	parts[#parts + 1] = "c_uiscale() in the console"
end
print(TAG .. " on: " .. table.concat(parts, "; "))
