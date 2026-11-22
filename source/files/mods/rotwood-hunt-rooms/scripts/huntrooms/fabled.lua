-- Hunt Rooms: the run's Fabled families and the miniboss's Fabled pick (0.3.0).
--
-- The run's 2 Fabled families: the game picks them once, at the start of
-- every run (components/powerroller.lua InitializeFabledFamilies: 2 of the 4,
-- Electric, Shield, Summon, Frost, at random), and every Fabled pick of the
-- run offers powers from those 2 only (the start room, Fabled rooms,
-- minibosses, the loot machine, Two Weapons' and Hunt Rooms' Fabled fill all
-- read the same list, GetSelectedFabledFamilies). The game's linked normal
-- powers (a family's tag, given by holding one of its Fabled powers) follow
-- on their own.
-- Here, right after the game's own pick and with its own random generator:
--  * never the pair fabled_never_pair (Shield + Summon)
--  * the family fabled_favour (Electric) in fabled_favour_share percent of
--    runs (75: Electric + Shield / Summon / Frost 25% each, Frost + Shield /
--    Summon 12.5% each)
-- The pair is saved with the run (the game's own OnSave), so a load keeps it,
-- and the Blight keeps it over all its parts (the game doesn't pick again
-- between parts). The families are the game's own list (the power families
-- tagged "fabled"); a name the game doesn't have (an update) leaves that rule
-- out; anything wrong: the game's own pick stands.
--
-- The miniboss's Fabled pick: in a miniboss room the game's shared Fabled
-- pick (PreparePowers_FabledShared: 1 power from each of the 2 families, plus
-- a normal power) asks for miniboss_fabled (4) Fabled powers instead of 2: 2
-- from each family (the game's own GetNumFabledRelicsFromOrderedFamilies goes
-- round the families), plus the normal power as before. 2 = the game's.
local HR = require "huntrooms.main"

local Fabled = {}

Fabled.families = nil -- the game's Fabled families (sorted)
Fabled.rule = nil     -- { never = { a, b } or nil, favour = name or nil, share = n }
Fabled.in_pick = 0    -- inside the game's shared Fabled pick in a miniboss room
Fabled.last = nil     -- the last pair picked (for the log / hr_doors)

-- The game's Fabled families: the power families tagged "fabled".
function Fabled.GameFamilies(Power)
	local out = {}
	if type(Power) ~= "table" or type(Power.Slots) ~= "table" or type(Power.SlotDescriptor) ~= "table" then
		return out
	end
	for slot in pairs(Power.Slots) do
		local d = Power.SlotDescriptor[slot]
		if type(d) == "table" and type(d.tags) == "table" and d.tags.fabled then
			out[#out + 1] = slot
		end
	end
	table.sort(out)
	return out
end

local function Has(list, x)
	for _, v in ipairs(list) do
		if v == x then
			return true
		end
	end
	return false
end

-- The rule from the settings, checked against the game's families.
function Fabled.Rule(s, families)
	local rule = { share = tonumber(s.fabled_favour_share) or 75 }
	local notes = {}
	local np = s.fabled_never_pair
	if type(np) == "table" then
		if Has(families, np[1]) and Has(families, np[2]) then
			rule.never = { np[1], np[2] }
		else
			notes[#notes + 1] = "never " .. tostring(np[1]) .. " + " .. tostring(np[2]) .. ": not the game's families, left out"
		end
	end
	if type(s.fabled_favour) == "string" then
		if Has(families, s.fabled_favour) then
			rule.favour = s.fabled_favour
		else
			notes[#notes + 1] = tostring(s.fabled_favour) .. " isn't one of the game's families, not favoured"
		end
	end
	return rule, notes
end

local function Never(rule, a, b)
	local n = rule.never
	return n ~= nil and ((a == n[1] and b == n[2]) or (a == n[2] and b == n[1]))
end

-- Every allowed pair with its weight (percent of runs).
function Fabled.Pairs(families, rule)
	local with, without = {}, {}
	for i = 1, #families do
		for j = i + 1, #families do
			local a, b = families[i], families[j]
			if not Never(rule, a, b) then
				local pair = { a, b }
				if rule.favour ~= nil and (a == rule.favour or b == rule.favour) then
					with[#with + 1] = pair
				else
					without[#without + 1] = pair
				end
			end
		end
	end
	local out = {}
	local share = math.max(0, math.min(100, rule.share or 0))
	if rule.favour == nil or #with == 0 or #without == 0 then
		local all = {}
		for _, p in ipairs(with) do all[#all + 1] = p end
		for _, p in ipairs(without) do all[#all + 1] = p end
		for _, p in ipairs(all) do
			out[#out + 1] = { pair = p, w = 100 / #all }
		end
		return out
	end
	for _, p in ipairs(with) do
		out[#out + 1] = { pair = p, w = share / #with }
	end
	for _, p in ipairs(without) do
		out[#out + 1] = { pair = p, w = (100 - share) / #without }
	end
	return out
end

-- One pair, by the weights; rand() in [0,1).
function Fabled.Pick(pairs, rand)
	local total = 0
	for _, e in ipairs(pairs) do
		total = total + e.w
	end
	if total <= 0 then
		return nil
	end
	local x = rand() * total
	for _, e in ipairs(pairs) do
		x = x - e.w
		if x < 0 then
			return e.pair
		end
	end
	return pairs[#pairs].pair
end

-- After the game's own pick: the run's pair by the rule (the game's random
-- generator). Leaves the game's pick when anything doesn't look right.
function Fabled.Apply(roller)
	local fams, rule = Fabled.families, Fabled.rule
	if fams == nil or rule == nil or #fams < 2 then
		return false
	end
	local cur = roller.fabled_families
	if type(cur) ~= "table" or #cur ~= 2 or not Has(fams, cur[1]) or not Has(fams, cur[2]) then
		return false -- (not the game's usual pick: left as it is)
	end
	local rng = roller.rng
	local rand = (type(rng) == "table" and type(rng.Float) == "function") and function() return rng:Float() end or math.random
	local pair = Fabled.Pick(Fabled.Pairs(fams, rule), rand)
	if pair == nil then
		return false
	end
	roller.fabled_families = { pair[1], pair[2] }
	Fabled.last = pair[1] .. " + " .. pair[2]
	HR.Debug("the run's Fabled families: " .. Fabled.last .. " (the game's pick: " .. tostring(cur[1]) .. " + " .. tostring(cur[2]) .. ")")
	return true
end

function Fabled.InstallFamilies(PowerRoller, Power)
	local s = HR.settings
	if s.fabled_never_pair == false and s.fabled_favour == false then
		return false, "off"
	end
	if type(PowerRoller) ~= "table" or type(PowerRoller.InitializeFabledFamilies) ~= "function" then
		return false, "a game update changed PowerRoller (the game's Fabled families)"
	end
	local fams = Fabled.GameFamilies(Power)
	if #fams < 3 then
		return false, "a game update changed the Fabled families (" .. #fams .. " found)"
	end
	local rule, notes = Fabled.Rule(s, fams)
	if rule.never == nil and rule.favour == nil then
		return false, table.concat(notes, "; ")
	end
	Fabled.families, Fabled.rule = fams, rule
	if not rawget(PowerRoller, "huntrooms_fabled") then
		local orig = PowerRoller.InitializeFabledFamilies
		PowerRoller.InitializeFabledFamilies = function(self, ...)
			local r = table.pack(orig(self, ...))
			if HR.On("the run's Fabled families") then
				HR.Call("the run's Fabled families", Fabled.Apply, self)
			end
			return table.unpack(r, 1, r.n)
		end
		rawset(PowerRoller, "huntrooms_fabled", true)
	end
	local parts = {}
	if rule.never ~= nil then
		parts[#parts + 1] = "never " .. rule.never[1] .. " + " .. rule.never[2]
	end
	if rule.favour ~= nil then
		parts[#parts + 1] = string.format("%s in %s%% of runs", rule.favour, tostring(rule.share))
	end
	for _, n in ipairs(notes) do
		parts[#parts + 1] = n
	end
	return true, table.concat(parts, ", ")
end

-- Is the room the game is in a miniboss room?
function Fabled.InMinibossRoom()
	local w = rawget(_G, "TheWorld")
	local ok, rt = pcall(function() return w:GetCurrentRoomType() end)
	return ok and rt == "miniboss"
end

function Fabled.InstallPick(PDM)
	local n = HR.settings.miniboss_fabled
	if n <= 2 then
		return false, "off"
	end
	if type(PDM) ~= "table" or type(PDM.PreparePowers_FabledShared) ~= "function" or type(PDM.GetNumFabledRelicsFromOrderedFamilies) ~= "function" then
		return false, "a game update changed PowerDropManager (the game's Fabled pick)"
	end
	if not rawget(PDM, "huntrooms_miniboss_pick") then
		local orig_prep = PDM.PreparePowers_FabledShared
		PDM.PreparePowers_FabledShared = function(self, ...)
			local mb = false
			if HR.On("the miniboss's Fabled pick") then
				local ok, yes = HR.Call("the miniboss's Fabled pick", Fabled.InMinibossRoom)
				mb = ok and yes == true
			end
			if not mb then
				return orig_prep(self, ...)
			end
			Fabled.in_pick = Fabled.in_pick + 1
			local r = table.pack(pcall(orig_prep, self, ...))
			Fabled.in_pick = Fabled.in_pick - 1
			if not r[1] then
				error(r[2], 0)
			end
			return table.unpack(r, 2, r.n)
		end
		local orig_num = PDM.GetNumFabledRelicsFromOrderedFamilies
		PDM.GetNumFabledRelicsFromOrderedFamilies = function(self, player, families, num, ...)
			if Fabled.in_pick > 0 and num == 2 and HR.On("the miniboss's Fabled pick") then
				num = HR.settings.miniboss_fabled
			end
			return orig_num(self, player, families, num, ...)
		end
		rawset(PDM, "huntrooms_miniboss_pick", true)
	end
	return true, string.format("%d Fabled powers (2 from each family) and the normal power", n)
end

return Fabled
