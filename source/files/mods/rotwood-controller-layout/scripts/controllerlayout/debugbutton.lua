-- Controller Layout: two bits of the game's screen you can hide, each with a key:
--   the "[Debug Menu]" button at the top in camp (screens/playerhud.lua:
--     debug_btns.toggle_btn, the chest icon; the game hides it in dungeons)
--   the build number at the top ("REV. 760548": playerhud's debug_watermark,
--     in camp and in runs)
-- debug_button / rev_number = "hidden" (start hidden) / "shown" / "game" (left
-- alone); debug_button_key (F9) and rev_number_key (F10) show / hide them. Not
-- F8: that's the game's FEEDBACK key (input/bindings.lua). The last choice holds
-- for the session (each new HUD gets it). Nothing runs except on those keys and
-- when a HUD is made.

local DebugButton = {}

DebugButton.shown = nil -- the debug button: nil = not decided yet (the setting's start)
DebugButton.hooked = false
DebugButton.on = false
DebugButton.rev_shown = nil -- the build number
DebugButton.rev_hooked = false
DebugButton.rev_on = false

local function InTown()
	return TheDungeon ~= nil and TheDungeon.IsInTown ~= nil and TheDungeon:IsInTown()
end

local function Button(hud)
	local btns = hud ~= nil and hud.debug_btns or nil
	return btns, btns ~= nil and btns.toggle_btn or nil
end

-- Show or hide the debug button on a camp HUD.
function DebugButton.Apply(hud, shown)
	local btns, toggle = Button(hud)
	if toggle == nil or not InTown() then
		return false
	end
	if shown then
		toggle:Show()
	else
		toggle:Hide()
		if btns.Hide ~= nil then
			btns:Hide() -- its open menu goes with it
		end
	end
	return true
end

-- Show or hide the build number on a HUD (camp or run).
function DebugButton.ApplyRev(hud, shown)
	local w = hud ~= nil and hud.debug_watermark or nil
	if w == nil then
		return false
	end
	if shown then
		w:Show()
	else
		w:Hide()
	end
	return true
end

function DebugButton.Toggle()
	local hud = TheDungeon ~= nil and TheDungeon.HUD or nil
	if hud == nil or not InTown() then
		return false
	end
	DebugButton.shown = not DebugButton.shown
	return DebugButton.Apply(hud, DebugButton.shown)
end

function DebugButton.ToggleRev()
	local hud = TheDungeon ~= nil and TheDungeon.HUD or nil
	if hud == nil then
		return false
	end
	DebugButton.rev_shown = not DebugButton.rev_shown
	return DebugButton.ApplyRev(hud, DebugButton.rev_shown)
end

-- a key that runs fn (once per session); returns a note when it can't
local function BindKey(input, keys, key, flag, fn)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local code = type(keys) == "table" and rawget(keys, key) or nil
	if code == nil then
		return "the key '" .. key .. "' isn't a key name (no key)"
	end
	if input ~= nil and input.AddKeyDownHandler ~= nil and not DebugButton[flag] then
		DebugButton[flag] = true
		input:AddKeyDownHandler(code, function()
			pcall(fn)
		end)
	end
	return nil
end

-- Returns installed, note. settings: debug_button / rev_number ("hidden" /
-- "shown" / "game"), debug_button_key, rev_number_key.
function DebugButton.Install(settings, add_post_construct, input, keys)
	local db = settings.debug_button == "hidden" or settings.debug_button == "shown"
	local rev = settings.rev_number == "hidden" or settings.rev_number == "shown"
	if not db and not rev then
		return false, "both left as the game has them"
	end
	if db then
		DebugButton.on = true
		DebugButton.shown = settings.debug_button ~= "hidden"
	end
	if rev then
		DebugButton.rev_on = true
		DebugButton.rev_shown = settings.rev_number ~= "hidden"
	end
	add_post_construct("screens/playerhud", function(hud)
		if DebugButton.on then
			DebugButton.Apply(hud, DebugButton.shown)
		end
		if DebugButton.rev_on then
			DebugButton.ApplyRev(hud, DebugButton.rev_shown)
		end
	end)
	local notes = {}
	if db then
		notes[#notes + 1] = BindKey(input, keys, settings.debug_button_key, "hooked", DebugButton.Toggle)
	end
	if rev then
		notes[#notes + 1] = BindKey(input, keys, settings.rev_number_key, "rev_hooked", DebugButton.ToggleRev)
	end
	return true, #notes > 0 and table.concat(notes, "; ") or nil
end

return DebugButton
