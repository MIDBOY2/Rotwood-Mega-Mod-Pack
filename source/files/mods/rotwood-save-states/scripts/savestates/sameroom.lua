-- Save States: the same room on a load (0.5.0).
--
-- A room's enemies are the next card of the run's encounter deck: the game
-- draws it when the room starts (EncounterDeck:Draw, from components/
-- spawncoordinator.lua), with the room's own seed. A save is always taken
-- after that draw, so the saved map (WorldMap:GetMapData, its
-- encounter_deck_data) has the deck with this room's card already used: a
-- load drew the NEXT card (another set of enemies, or another special
-- encounter / Frenzy extra), and every load of that save the same next one
-- (the same deck, the same room seed). 0.4.x did that.
--
-- Now: the room's draw is noted (names only: which encounter, which special
-- encounter, which extra), saved with the run (run.encounter), handed to the
-- reloaded room in the map data the load writes, and that room gets the same
-- card again without drawing. The deck stays as saved: after this room's
-- draw, as in the run, so the rooms after it draw what they drew in the run.
-- The character file's special encounter counters aren't moved by a load.
--
-- Anything that doesn't match (another room or seed, another place, a name
-- the game doesn't have any more, a save from before 0.5.0, an error): the
-- game's own draw, as before. Nothing runs between room starts.
local Same = {}

Same.KEY = "savestates_encounter" -- in the map data a load writes (read once, then gone)
Same.on = false                   -- set by Install
Same.G = nil                      -- GLOBAL
Same.encounters = nil             -- encounter/encounters.lua
Same.extras = nil                 -- encounter/dynamicencounterelements.lua
Same.last = nil                   -- this room's draw (the game reloads the scripts each room)
Same.result = nil                 -- the loaded room: "same", or why the game drew
Same.Log = function() end

local function Dig(t, ...)
	for i = 1, select("#", ...) do
		if type(t) ~= "table" then
			return nil
		end
		t = t[(select(i, ...))]
	end
	return t
end

local function Copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

local function Here()
	local wm = Same.G.TheDungeon:GetDungeonMap()
	return wm, wm:GetCurrentRoomId(), wm:GetCurrentRoomSeed()
end

-- where the drawn names are in the game's lists
local function FindNormal(location, name, fn)
	local byroom = Same.encounters.GetRoomTypeEncounters(location)
	if type(byroom) ~= "table" then
		return nil
	end
	for rt, diffs in pairs(byroom) do
		if type(diffs) == "table" then
			for diff, set in pairs(diffs) do
				local e = Dig(set, name)
				if type(e) == "table" and e.exec_fn == fn then
					return rt, diff
				end
			end
		end
	end
	return nil
end

local function FindSpecial(name, fn)
	for rarity, set in pairs(Same.encounters.special_encounters) do
		local e = Dig(set, name)
		if type(e) == "table" and e.exec_fn == fn then
			return rarity
		end
	end
	return nil
end

local function FindExtra(dyn)
	for rarity, set in pairs(Same.extras) do
		if type(set) == "table" then
			for name, e in pairs(set) do
				if e == dyn then
					return rarity, name
				end
			end
		end
	end
	return nil
end

-- after the game's draw: what came out, by name
function Same.Note(deck, name, fn, dyn)
	Same.last = nil
	local _, room, seed = Here()
	if type(room) ~= "number" or type(seed) ~= "number" or type(deck.location) ~= "string" then
		return nil, "no room"
	end
	local rec = { v = 1, room_id = room, roomseed = seed, location = deck.location, kind = "none" }
	if name ~= nil then
		local W = Same.G.TheWorld
		if W ~= nil and W.is_special_encounter then
			local rarity = FindSpecial(name, fn)
			if rarity == nil then
				return nil, "the special encounter " .. tostring(name) .. " isn't in the game's list"
			end
			rec.kind, rec.encounter, rec.rarity = "special", name, rarity
		else
			local rt, diff = FindNormal(deck.location, name, fn)
			if rt == nil then
				return nil, "the encounter " .. tostring(name) .. " isn't in the game's list"
			end
			rec.kind, rec.encounter, rec.room_type, rec.difficulty = "normal", name, rt, diff
		end
	end
	if dyn ~= nil then
		local rarity, ename = FindExtra(dyn)
		if rarity == nil then
			return nil, "the extra isn't in the game's list"
		end
		rec.extra, rec.extra_rarity = ename, rarity
	end
	Same.last = rec
	return rec
end

-- a noted draw back as the game's (name, exec_fn, dynamic element); errors on a missing piece
function Same.Resolve(deck, rec)
	local name, fn, dyn
	if rec.kind == "special" then
		local e = Dig(Same.encounters.special_encounters, rec.rarity, rec.encounter)
		if type(e) ~= "table" or type(e.exec_fn) ~= "function" then
			error("the special encounter " .. tostring(rec.encounter) .. " isn't in the game now", 0)
		end
		name, fn = rec.encounter, e.exec_fn
	elseif rec.kind == "normal" then
		local e = Dig(Same.encounters.GetRoomTypeEncounters(deck.location), rec.room_type, rec.difficulty, rec.encounter)
		if type(e) ~= "table" or type(e.exec_fn) ~= "function" then
			error("the encounter " .. tostring(rec.encounter) .. " isn't in the game now", 0)
		end
		name, fn = rec.encounter, e.exec_fn
	elseif rec.kind ~= "none" then
		error("the save's room note is unreadable", 0)
	end
	if rec.extra ~= nil then
		dyn = Dig(Same.extras, rec.extra_rarity, rec.extra)
		if type(dyn) ~= "table" then
			error("the extra " .. tostring(rec.extra) .. " isn't in the game now", 0)
		end
	end
	return name, fn, dyn
end

-- before the game's draw: the save's card for this room, once
-- (true, name, fn, dyn) | (false, why or nil when there's no note)
function Same.Replay(deck)
	local wm = Same.G.TheDungeon:GetDungeonMap()
	local data = wm.data
	local rec = type(data) == "table" and data[Same.KEY] or nil
	if rec == nil then
		return false
	end
	data[Same.KEY] = nil -- once: never into a later room or a later save
	local room, seed = wm:GetCurrentRoomId(), wm:GetCurrentRoomSeed()
	local why
	if type(rec) ~= "table" or rec.v ~= 1 then
		why = "the save's room note is unreadable"
	elseif rec.room_id ~= room or rec.roomseed ~= seed then
		why = "the note is for another room (" .. tostring(rec.room_id) .. ", here " .. tostring(room) .. ")"
	elseif rec.location ~= deck.location then
		why = "the note is for another place"
	end
	if why ~= nil then
		Same.result = why
		return false, why
	end
	local name, fn, dyn = Same.Resolve(deck, rec)
	local W = Same.G.TheWorld
	if rec.kind == "special" then
		W.is_special_encounter = true
		W.special_encounter_name = name
	else
		W.is_special_encounter = nil
		W.special_encounter_name = nil
	end
	Same.result = "same"
	Same.Log(string.format("the saved room: %s%s, as when it was saved (no new draw)",
		name ~= nil and ((rec.kind == "special" and "special encounter " or "encounter ") .. tostring(name)) or "no encounter",
		rec.extra ~= nil and (", extra " .. tostring(rec.extra)) or ""))
	return true, name, fn, dyn
end

-- C.Take: this room's note (nil when there's none for it)
function Same.ForSave(wm)
	local rec = Same.last
	if not Same.on or rec == nil then
		return nil
	end
	local ok, room, seed = pcall(function() return wm:GetCurrentRoomId(), wm:GetCurrentRoomSeed() end)
	if not ok or rec.room_id ~= room or rec.roomseed ~= seed then
		return nil
	end
	return Copy(rec)
end

-- the loader: what goes into the map data it writes
function Same.ForLoad(run)
	local rec = type(run) == "table" and run.encounter or nil
	if not Same.on or type(rec) ~= "table" or rec.v ~= 1 then
		return nil
	end
	return Copy(rec)
end

-- after a load: a note no draw used (a room without one) goes
function Same.Clear(wm)
	if wm ~= nil and type(wm.data) == "table" then
		wm.data[Same.KEY] = nil
	end
end

function Same.Install(G, EncounterDeck, encounters, extras)
	if type(EncounterDeck) ~= "table" or type(EncounterDeck.Draw) ~= "function" then
		error("the game's encounter deck changed", 0)
	end
	if type(encounters) ~= "table" or type(encounters.GetRoomTypeEncounters) ~= "function" or type(encounters.special_encounters) ~= "table" then
		error("the game's encounter list changed", 0)
	end
	if type(extras) ~= "table" then
		error("the game's Frenzy extras list changed", 0)
	end
	Same.G, Same.encounters, Same.extras = G, encounters, extras
	if EncounterDeck.savestates_same_room then
		Same.on = true
		return true, "already in"
	end
	local orig = EncounterDeck.Draw
	EncounterDeck.Draw = function(self, spawn_coordinator, room_type, difficulty_index, ...)
		if Same.on then
			local ok, done, name, fn, dyn = pcall(Same.Replay, self)
			if ok and done then
				pcall(Same.Note, self, name, fn, dyn) -- (a save from the loaded room keeps it)
				return name, fn, dyn
			end
			local why = done -- Replay's error
			if ok then
				why = name -- (false, why), why nil when there was no note
			end
			if why ~= nil then
				Same.result = tostring(why)
				Same.Log("the saved room: " .. tostring(why) .. " (the game's own draw)")
			end
		end
		local name, fn, dyn = orig(self, spawn_coordinator, room_type, difficulty_index, ...)
		if Same.on then
			local okn, rec, why = pcall(Same.Note, self, name, fn, dyn)
			if not okn then
				Same.Log("the room's draw not noted: " .. tostring(rec))
			elseif rec == nil and why ~= nil then
				Same.Log("the room's draw not noted (" .. tostring(why) .. "): a load of a save from here draws again")
			end
		end
		return name, fn, dyn
	end
	EncounterDeck.savestates_same_room = true
	Same.on = true
	return true, "a load gives the saved room its own enemies again"
end

return Same
