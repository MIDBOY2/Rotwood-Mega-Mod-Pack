-- Weapon Moves: settings, the log, and finding the game's local functions.
local Main = {}

Main.TAG = "[Weapon Moves]"
Main.DEFAULTS = {
	enabled = true,
	bow_leap_shot = true,
	hammer_spin_finale = true,
	hammer_finale_landing = "auto",
	hammer_finale_knockback = 3.5,
	hammer_focus_fx = true,
	hammer_air_spin_fx = true,
	hammer_input_log = false,
	guard = true,
}
Main.ORDER = { "enabled", "bow_leap_shot", "hammer_spin_finale", "hammer_finale_landing", "hammer_finale_knockback", "hammer_focus_fx", "hammer_air_spin_fx", "hammer_input_log", "guard" }
-- settings that take a word instead of true / false
Main.CHOICES = {
	hammer_finale_landing = { auto = true, back = true, hand = true },
}
-- settings that take a number: { lowest, highest }
Main.NUMBERS = {
	hammer_finale_knockback = { 0, 10 },
}

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

-- bulletproofing (weaponmoves/guard.lua): the leap shot's states and hooks
Main.G = require("weaponmoves.guard").Shared(Main.TAG)

-- true / false switches (or one of a setting's words, Main.CHOICES, or a number
-- in its range, Main.NUMBERS); anything else keeps the default (and says so)
function Main.LoadSettings(user)
	local s, notes = {}, {}
	for _, key in ipairs(Main.ORDER) do
		local v = nil
		if type(user) == "table" then
			v = user[key] -- (false is a real answer: no "and / or" here)
		end
		local words = Main.CHOICES[key]
		local range = Main.NUMBERS[key]
		if v == nil then
			s[key] = Main.DEFAULTS[key]
		elseif range ~= nil then
			if type(v) == "number" and v >= range[1] and v <= range[2] then
				s[key] = v
			else
				s[key] = Main.DEFAULTS[key]
				notes[#notes + 1] = key .. " should be a number from " .. range[1] .. " to " .. range[2] .. " (using " .. tostring(Main.DEFAULTS[key]) .. ")"
			end
		elseif words ~= nil then
			if type(v) == "string" and words[v] then
				s[key] = v
			else
				s[key] = Main.DEFAULTS[key]
				local list = {}
				for w in pairs(words) do list[#list + 1] = '"' .. w .. '"' end
				table.sort(list)
				notes[#notes + 1] = key .. " should be " .. table.concat(list, ", ") .. " (using \"" .. tostring(Main.DEFAULTS[key]) .. "\")"
			end
		elseif type(v) == "boolean" then
			s[key] = v
		else
			s[key] = Main.DEFAULTS[key]
			notes[#notes + 1] = key .. " should be true or false (using " .. tostring(Main.DEFAULTS[key]) .. ")"
		end
	end
	Main.settings = s
	Main.G.on = s.guard
	return s, notes
end

-- a local variable a game function uses: its value and slot
function Main.FindUpvalue(fn, wanted)
	if type(fn) ~= "function" then
		return nil
	end
	for i = 1, 255 do
		local name, value = debug.getupvalue(fn, i)
		if name == nil then
			return nil
		end
		if name == wanted then
			return value, i
		end
	end
	return nil
end

return Main
