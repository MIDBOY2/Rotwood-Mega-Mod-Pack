-- Cannon Tweaks: the cannon's weapon powers with your own numbers.
--
-- The game keeps each power's numbers in its definition (defs/powers/weaponpowers.lua, the tuning
-- table of the LEGENDARY rarity, the only one these powers have) and reads them every time it uses them
-- (pow:GetVar -> ItemInstance:GetTuning), so the mod writes your numbers into those tables once, when
-- the game starts, before any power is picked. The game's own code does everything else, exactly as
-- before. Nothing runs per frame.
--
-- One thing isn't a number in the game: Return to Sender's catch reloads 1 round, written in its code
-- (event "cannon_projectile_caught" -> PushEvent("cannon_reload", 1)). The mod wraps that one function:
-- the game's reload, sound and sparkle, then the extra rounds through the same "cannon_reload" event.
-- The texts: a power's description is filled with these numbers by the game already; the mod only
-- corrects "1 Cannonball" / "3 Cannonball" (Power.GetDescForPower), and drops "-0% Attack Range".
local Main = {}

Main.TAG = "[Cannon Tweaks]"

-- each power: its settings, the game's tuning name, the game's number (build 760548), the limits
Main.POWERS = {
	{
		id = "single_shot", def = "cannon_single_shot", title = "Single Shot",
		vars = {
			{ key = "rounds", tuning = "max_ammo", game = 1, default = 3, min = 1, max = 30, whole = true, next_room = true },
			{ key = "damage_mult", tuning = "weapon_damage_mult", game = 3, default = 3, min = 0.1, max = 20, next_room = true },
			{ key = "light_speed_mult", tuning = "light_speed_mult", game = 3, default = 3, min = 0.1, max = 10, next_room = true },
			{ key = "heavy_speed_mult", tuning = "heavy_speed_mult", game = 1.5, default = 1.5, min = 0.1, max = 10, next_room = true },
			{ key = "range_mult", tuning = "range_mult", game = 2, default = 2, min = 0.1, max = 10, next_room = true },
			{ key = "blast_angle_mult", tuning = "blast_angle_mult", game = 0.5, default = 0.5, min = 0.1, max = 5, next_room = true },
		},
	},
	{
		id = "return_to_sender", def = "cannon_bounce_catch_reload", title = "Return to Sender",
		vars = {
			{ key = "range_penalty", tuning = "attack_range_mult", game = 60, default = 20, min = 0, max = 95, whole = true, next_room = true },
			-- not a number the game has: the mod's own (the game's code reloads 1)
			{ key = "reload_on_catch", game = 1, default = 2, min = 1, max = 30, whole = true },
		},
	},
	{
		id = "bottomless_clip", def = "cannon_infinite_ammo", title = "Bottomless Clip",
		vars = {
			{ key = "regen_per_sec", tuning = "sustained_shots_per_sec", game = 1.66, default = 3, min = 0.1, max = 30 },
			-- above 0: at 0 the game would never end an overheat
			{ key = "overheat_sec", tuning = "overheat_cooldown_sec", game = 5, default = 2.75, min = 0.1, max = 30 },
			{ key = "overheat_sound_sec", tuning = "overheat_sound_linger_sec", game = 1, default = 1, min = 0, max = 10 },
		},
	},
	{
		id = "spray_n_pray", def = "cannon_rapid_light", title = "Spray 'n' Pray",
		vars = {
			{ key = "extra_rounds", tuning = "ammo_max_bonus", game = 6, default = 6, min = 0, max = 30, whole = true, next_room = true },
		},
	},
}
Main.BY_ID = {}
for _, p in ipairs(Main.POWERS) do
	Main.BY_ID[p.id] = p
	p.by_key = {}
	for _, v in ipairs(p.vars) do
		p.by_key[v.key] = v
	end
end

Main.DEFAULTS = { enabled = true, fix_texts = true, console_command = true }
for _, p in ipairs(Main.POWERS) do
	local d = { enabled = true }
	for _, v in ipairs(p.vars) do
		d[v.key] = v.default
	end
	Main.DEFAULTS[p.id] = d
end

Main.settings = nil
Main.defs = {}      -- power id -> the game's definition (only the ones the mod changed)
Main.original = {}  -- power id -> { tuning name -> the game's number }
Main.texts = {}     -- the game's power name -> function(desc, G) for the ones the mod changed
Main.warned = {}

local function Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end
Main.Log = Log

local function LogOnce(id, msg)
	if not Main.warned[id] then
		Main.warned[id] = true
		Log(msg)
	end
end

local function Num(n)
	if type(n) ~= "number" then
		return tostring(n)
	end
	if n == math.floor(n) and math.abs(n) < 1e9 then
		return string.format("%d", n)
	end
	return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end
Main.Num = Num

local function Clamp(v, n)
	if v.whole then
		n = math.floor(n + 0.5)
	end
	if n < v.min then
		n = v.min
	elseif n > v.max then
		n = v.max
	end
	return n
end
Main.Clamp = Clamp

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		if type(v) == "table" then
			local t = {}
			for k2, v2 in pairs(v) do
				t[k2] = v2
			end
			s[k] = t
		else
			s[k] = v
		end
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			local d = Main.DEFAULTS[k]
			local p = Main.BY_ID[k]
			if p ~= nil then
				if type(v) == "boolean" then
					s[k].enabled = v -- single_shot = false: the game's
				elseif type(v) == "table" then
					for k2, v2 in pairs(v) do
						local var = p.by_key[k2]
						if k2 == "enabled" then
							if type(v2) == "boolean" then
								s[k].enabled = v2
							else
								Log(k .. ".enabled has to be true or false, using true")
							end
						elseif var == nil then
							Log(k .. "." .. tostring(k2) .. " isn't a setting, left out")
						elseif type(v2) ~= "number" or v2 ~= v2 then
							Log(k .. "." .. k2 .. " has to be a number, using " .. Num(var.default))
						else
							local n = Clamp(var, v2)
							if n ~= v2 then
								if v2 >= var.min and v2 <= var.max then
									Log(k .. "." .. k2 .. " = " .. Num(v2) .. " has to be a whole number, using " .. Num(n))
								else
									Log(k .. "." .. k2 .. " = " .. Num(v2) .. " is outside " .. Num(var.min) .. " to " .. Num(var.max) .. ", using " .. Num(n))
								end
							end
							s[k][k2] = n
						end
					end
				else
					Log(k .. " has to be a table of numbers (or false), using the defaults")
				end
			elseif d ~= nil then
				if type(v) == type(d) then
					s[k] = v
				else
					Log(k .. " has to be " .. type(d) .. ", using " .. tostring(d))
				end
			else
				Log(tostring(k) .. " isn't a setting, left out")
			end
		end
	end
	Main.settings = s
	return s
end

-- the game's definition of a weapon power, by its full name ("cannon_single_shot")
function Main.FindDef(Power, name)
	local slot = type(Power.Slots) == "table" and rawget(Power.Slots, "WEAPONPOWER") or "WEAPONPOWER"
	local items = type(Power.Items) == "table" and rawget(Power.Items, slot) or nil
	local def = type(items) == "table" and rawget(items, name) or nil
	if def == nil and type(Power.FindPowerByName) == "function" then
		local ok, found = pcall(Power.FindPowerByName, name)
		def = ok and found or nil
	end
	if type(def) == "table" and type(def.tuning) == "table" then
		return def
	end
end

-- write one number into every rarity of a definition that has it as a plain number
-- returns how many, and the game's number
local function SetTuning(def, name, value)
	local count, was = 0, nil
	for _, tbl in pairs(def.tuning) do
		if type(tbl) == "table" and type(rawget(tbl, name)) == "number" then
			was = was or rawget(tbl, name)
			tbl[name] = value
			count = count + 1
		end
	end
	return count, was
end
Main.SetTuning = SetTuning

-- put the game's numbers back (a power that failed half way)
function Main.Restore(id)
	local def, orig = Main.defs[id], Main.original[id]
	if def ~= nil and orig ~= nil then
		for name, value in pairs(orig) do
			local ok, err = pcall(SetTuning, def, name, value)
			if not ok then
				Log("couldn't put back the game's " .. tostring(name) .. ": " .. tostring(err))
			end
		end
	end
	Main.defs[id] = nil
	Main.original[id] = nil
end

-- the extra rounds when Return to Sender's shot is caught
function Main.InstallCatch(def)
	local triggers = def.event_triggers
	-- the game's own (kept on the definition, so a second load wraps the game's again, not the mod's)
	local orig = rawget(def, "cannontweaks_game_catch")
		or (type(triggers) == "table" and rawget(triggers, "cannon_projectile_caught") or nil)
	if type(orig) ~= "function" or type(triggers) ~= "table" then
		return false, "its catch (event_triggers.cannon_projectile_caught) isn't in the game any more"
	end
	rawset(def, "cannontweaks_game_catch", orig)
	Main.catch_orig = orig
	Main.catch_fn = function(pow, inst, ...)
		-- the game's: 1 round, the reload sound and the sparkle
		orig(pow, inst, ...)
		local mine = Main.settings ~= nil and Main.settings.return_to_sender or nil
		local extra = mine ~= nil and mine.enabled and (mine.reload_on_catch or 1) - 1 or 0
		if extra > 0 and inst ~= nil and inst.IsValid ~= nil and inst:IsValid() then
			inst:PushEvent("cannon_reload", extra)
		end
	end
	triggers.cannon_projectile_caught = Main.catch_fn
	return true
end

-- ---------- the texts ----------
local function Esc(s)
	return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end
local function EscRepl(s)
	return (s:gsub("%%", "%%%%"))
end

-- the ammo's name, one and many ("Cannonball", "Cannonballs"), as the game shows it
function Main.AmmoNames(G)
	local S = type(G) == "table" and rawget(G, "STRINGS") or nil
	local names = type(S) == "table" and rawget(S, "NAMES") or nil
	local plural = type(S) == "table" and rawget(S, "NAMES_PLURAL") or nil
	local one = type(names) == "table" and rawget(names, "cannon_ammo") or nil
	local many = type(plural) == "table" and rawget(plural, "cannon_ammo") or nil
	if type(one) ~= "string" or one == "" then
		return nil
	end
	if type(many) ~= "string" or many == "" then
		many = one
	end
	return one, many
end

-- "3 Cannonball" -> "3 Cannonballs", "1 Cannonballs" -> "1 Cannonball"
function Main.FixCount(desc, n, one, many)
	if type(desc) ~= "string" or type(one) ~= "string" or type(many) ~= "string" or one == many then
		return desc
	end
	local num = Num(n)
	local d = " " .. desc
	if n == 1 then
		d = d:gsub("([^%d%.,])1 " .. Esc(many), "%1" .. "1 " .. EscRepl(one))
	elseif not d:find(num .. " " .. many, 1, true) then
		d = d:gsub("([^%d%.,])" .. Esc(num) .. " " .. Esc(one), "%1" .. EscRepl(num .. " " .. many))
	end
	return d:sub(2)
end

-- Return to Sender: "reload 1 Cannonball" -> "reload 2 Cannonballs"; "-0% Attack Range." dropped
function Main.FixCatch(desc, n, penalty, one, many)
	if type(desc) ~= "string" then
		return desc
	end
	if n ~= 1 and type(one) == "string" then
		local d = (" " .. desc .. " "):gsub("([^%d%.,])1 " .. Esc(one) .. "([^%w])", "%1" .. EscRepl(Num(n) .. " " .. many) .. "%2", 1)
		desc = d:sub(2, -2)
	end
	if penalty == 0 then
		desc = desc:gsub("%s*%-0%%[^\n]*$", "")
	end
	return desc
end

Main.TEXTS = {
	single_shot = function(desc, G)
		local one, many = Main.AmmoNames(G)
		return Main.FixCount(desc, Main.settings.single_shot.rounds, one, many)
	end,
	return_to_sender = function(desc, G)
		local one, many = Main.AmmoNames(G)
		local mine = Main.settings.return_to_sender
		return Main.FixCatch(desc, mine.reload_on_catch, mine.range_penalty, one, many)
	end,
	spray_n_pray = function(desc, G)
		local one, many = Main.AmmoNames(G)
		return Main.FixCount(desc, Main.settings.spray_n_pray.extra_rounds, one, many)
	end,
}

function Main.InstallTexts(Power, G)
	-- the game's own (kept on Power, so a second load wraps the game's again)
	local orig = rawget(Power, "cannontweaks_game_desc") or Power.GetDescForPower
	if type(orig) ~= "function" then
		return false, "Power.GetDescForPower isn't in the game any more"
	end
	rawset(Power, "cannontweaks_game_desc", orig)
	Main.desc_orig = orig
	Main.desc_fn = function(power, ...)
		local desc = orig(power, ...)
		if type(desc) ~= "string" or next(Main.texts) == nil then
			return desc
		end
		local ok, def = pcall(power.GetDef, power)
		local fix = ok and type(def) == "table" and Main.texts[def.name] or nil
		if fix == nil then
			return desc
		end
		local ok2, fixed = pcall(fix, desc, G)
		if ok2 and type(fixed) == "string" then
			return fixed
		end
		LogOnce("text", "a power's text couldn't be corrected, the game's stays: " .. tostring(fixed))
		return desc
	end
	Power.GetDescForPower = Main.desc_fn
	return true
end

-- ---------- putting the numbers in ----------
-- one power; returns the changes ("rounds 1 -> 3") or nil, why
function Main.ApplyPower(Power, p)
	local mine = Main.settings[p.id]
	local def = Main.FindDef(Power, p.def)
	if def == nil then
		return nil, "not in the game (" .. p.def .. "), left as it is"
	end
	Main.defs[p.id] = def
	-- the game's numbers, kept on the definition (a second load still knows them)
	local orig = rawget(def, "cannontweaks_game")
	if type(orig) ~= "table" then
		orig = {}
		rawset(def, "cannontweaks_game", orig)
	end
	Main.original[p.id] = orig
	local changes = {}
	for _, v in ipairs(p.vars) do
		local value = mine[v.key]
		if v.tuning ~= nil then
			local count, was = SetTuning(def, v.tuning, value)
			if count == 0 then
				Log(p.title .. ": the game no longer has the number " .. v.tuning .. ", " .. v.key .. " left as the game has it")
			else
				if orig[v.tuning] == nil then
					orig[v.tuning] = was
				end
				local game = orig[v.tuning]
				if game ~= v.game then
					Log(p.title .. ": the game's " .. v.key .. " is " .. Num(game) .. " now (was " .. Num(v.game) .. " when the mod was made)")
				end
				if value ~= game then
					changes[#changes + 1] = v.key .. " " .. Num(game) .. " -> " .. Num(value)
				end
			end
		elseif v.key == "reload_on_catch" then
			local ok, why = Main.InstallCatch(def)
			if not ok then
				Log(p.title .. ": " .. tostring(why) .. ", a catch reloads the game's 1")
			elseif value ~= v.game then
				changes[#changes + 1] = v.key .. " " .. Num(v.game) .. " -> " .. Num(value)
			end
		end
	end
	if Main.TEXTS[p.id] ~= nil then
		Main.texts[p.def] = Main.TEXTS[p.id]
	end
	return changes
end

-- every power; returns true, summary
function Main.Apply(Power)
	if type(Power) ~= "table" then
		return false, "the game's powers (defs.powers) aren't there"
	end
	local parts = {}
	local any = false
	for _, p in ipairs(Main.POWERS) do
		if not Main.settings[p.id].enabled then
			parts[#parts + 1] = p.title .. ": the game's"
		else
			local ok, changes, why = pcall(Main.ApplyPower, Power, p)
			if not ok then
				Main.Restore(p.id)
				Main.texts[p.def] = nil
				Log(p.title .. ": left as the game has it, something went wrong: " .. tostring(changes))
			elseif changes == nil then
				Log(p.title .. ": " .. tostring(why))
			else
				any = true
				parts[#parts + 1] = p.title .. ": " .. (#changes > 0 and table.concat(changes, ", ") or "as the game")
			end
		end
	end
	return true, table.concat(parts, "; "), any
end

-- ---------- console ----------
function Main.Describe()
	local parts = {}
	for _, p in ipairs(Main.POWERS) do
		local mine = Main.settings[p.id]
		if not mine.enabled then
			parts[#parts + 1] = p.id .. ": the game's"
		else
			local nums = {}
			for _, v in ipairs(p.vars) do
				local game = v.tuning ~= nil and Main.original[p.id] ~= nil and Main.original[p.id][v.tuning] or v.game
				nums[#nums + 1] = v.key .. " " .. Num(mine[v.key]) .. " (game " .. Num(game) .. ")"
			end
			parts[#parts + 1] = p.id .. ": " .. table.concat(nums, ", ")
		end
	end
	return table.concat(parts, "; ")
end

-- c_cannon(): every number now. c_cannon("single_shot.rounds", 4): one number, for this session
-- (the settings file keeps yours). c_cannon("single_shot.rounds", "game"): the game's number.
function Main.SetNumber(what, value)
	local id, key = tostring(what):match("^([%w_]+)%.([%w_]+)$")
	local p = id ~= nil and Main.BY_ID[id] or nil
	local v = p ~= nil and p.by_key[key] or nil
	if v == nil then
		return nil, 'which number? like c_cannon("single_shot.rounds", 4); c_cannon() lists them'
	end
	local mine = Main.settings[id]
	if not mine.enabled or Main.defs[id] == nil then
		return nil, p.title .. " is as the game has it (switched off in the settings, or not found)"
	end
	if value == "game" then
		value = v.tuning ~= nil and Main.original[id] ~= nil and Main.original[id][v.tuning] or v.game
	end
	if type(value) ~= "number" or value ~= value then
		return nil, "not changed: give a number"
	end
	local n = Clamp(v, value)
	mine[key] = n
	if v.tuning ~= nil then
		SetTuning(Main.defs[id], v.tuning, n)
	end
	return n, p.title .. ": " .. key .. " now " .. Num(n) .. (v.next_room and " (from the next room)" or "")
		.. ", this session only (the settings file keeps yours)"
end

function Main.InstallCommand(G)
	rawset(G, "c_cannon", function(what, value)
		if what == nil then
			Log(Main.Describe())
			return true
		end
		local n, msg = Main.SetNumber(what, value)
		Log(msg)
		return n
	end)
end

return Main
