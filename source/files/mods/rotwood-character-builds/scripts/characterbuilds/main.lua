-- Character Builds: saving a whole character as a build, and loading one onto a character.
--
-- A build is the character's whole file as the game saves it (savedata/playersave.lua): "player"
-- (every component: look colours, gear, inventory, gems, loadouts, talents, masteries, titles, the
-- mods' data such as Skill Slots, Two Weapons, Armor Dyes, Player Colours) and "playerdata" (the look,
-- unlocks, ascension...). Because the gear and the loadouts that point at it travel together, every
-- loadout still works on the character it's loaded onto.
--
-- Saving: the game saves the character first (SaveCharacterForPlayerID), then its file is copied into
-- the builds file (store.lua).
--
-- Loading (0.2.0: right where you stand, no loading screen):
--  1. everything is saved (SaveAll), and this character as it is now goes into the automatic backups
--     in the builds file (if that can't be written, nothing is loaded)
--  2. the build (or the part of it picked: look, look keeping your face, colours, gear) is merged with
--     the character's file, keeping the character's own PlayerUID
--  3. it goes onto the character the way the game itself puts a character onto a player who picks one
--     in town (widgets/ftf/characterselectioningame.lua OnUserReady): SaveSystem:LoadCharacterAsPlayerID
--     (the look, unlocks...), "character_slot_changed", SetPersistData, PostLoadWorld (gear, loadouts,
--     talents...). Then the character is saved.
--  If that fails, the character as it was goes back on the same way; if even that fails, its file is
--  put back and the town loads again (the game's own way back to town), so it's never left half done.
-- This save's quests, farm and run (questcentral, cropfarmer, dungeontracker) stay the character's own:
-- they belong to this save's town, not to the build.
local Store = require "characterbuilds.store"

local Main = {}

Main.TAG = "[Character Builds]"
Main.DEFAULTS = {
	enabled = true,
	builds_file = "",
	slots = 12,
	auto_backups = 8,
	mirror_tab = true,
	show_gear = true,
	loadout_card = true,
	key_open = "Ctrl+B",
	console_commands = true,
}
Main.settings = Main.DEFAULTS
Main.MAX_SLOTS = 400
Main.G = nil
Main.Store = Store

local function Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end
Main.Log = Log

function Main.Note(title, text)
	Log(tostring(title) .. (text ~= nil and text ~= "" and (": " .. tostring(text)) or ""))
	local fe = Main.G ~= nil and rawget(Main.G, "TheFrontEnd") or nil
	if fe ~= nil and fe.ShowTextNotification ~= nil then
		pcall(fe.ShowTextNotification, fe, nil, tostring(title), text ~= nil and tostring(text) or "", 6)
	end
end

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if Main.DEFAULTS[k] ~= nil and type(v) == type(Main.DEFAULTS[k]) then
				s[k] = v
			end
		end
	end
	s.slots = math.max(4, math.min(Main.MAX_SLOTS, math.floor(s.slots)))
	s.auto_backups = math.max(1, math.min(50, math.floor(s.auto_backups)))
	Main.settings = s
	return s
end

function Main.deepcopy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local r = {}
	seen[t] = r
	for k, v in pairs(t) do
		r[Main.deepcopy(k, seen)] = Main.deepcopy(v, seen)
	end
	return r
end

-- ---------------------------------------------------------------------------
-- what a build says about itself

function Main.SpeciesName(s)
	if type(s) ~= "string" or s == "" then
		return "?"
	end
	return (s:gsub("^%l", string.upper))
end

function Main.Look(b)
	local data = type(b) == "table" and b.data or nil
	local pd = type(data) == "table" and data.playerdata or nil
	local cc = type(pd) == "table" and pd.CharacterCreator or nil
	if type(cc) ~= "table" then
		return nil
	end
	local player = type(data.player) == "table" and data.player or {}
	local gbj = type(player.gbj_colorgroupoverride) == "table" and player.gbj_colorgroupoverride or nil
	return {
		species = cc.species,
		bodyparts = type(cc.bodyparts) == "table" and cc.bodyparts or {},
		colorgroups = type(cc.colorgroups) == "table" and cc.colorgroups or {},
		custom_colors = gbj ~= nil and type(gbj.overrides) == "table" and gbj.overrides or nil,
	}
end

-- one line: "Ogre · 17 Nov 2026 21:40 · MY-PC character 4"
function Main.Describe(b)
	if type(b) ~= "table" then
		return "Empty"
	end
	local look = Main.Look(b)
	local parts = { Main.SpeciesName(look ~= nil and look.species or nil) }
	if type(b.saved_text) == "string" then
		parts[#parts + 1] = b.saved_text
	end
	local from = {}
	if type(b.pc) == "string" and b.pc ~= "" then
		from[#from + 1] = b.pc
	end
	if type(b.character_slot) == "number" then
		from[#from + 1] = "character " .. b.character_slot
	end
	if #from > 0 then
		parts[#parts + 1] = table.concat(from, " ")
	end
	return table.concat(parts, " · ")
end

function Main.Label(b, slot)
	if type(b) == "table" and b.auto then
		return "Backup" .. (type(b.before) == "string" and (" (before " .. b.before .. ")") or "")
	end
	return "Build " .. tostring(slot)
end

-- the slots to show: at least settings.slots, and 4 more after the last build
function Main.SlotCount(t)
	local last = 0
	for k in pairs(type(t) == "table" and t.builds or {}) do
		if type(k) == "number" and k > last then
			last = k
		end
	end
	local n = math.max(Main.settings.slots, last + 4)
	n = math.ceil(n / 4) * 4
	return math.min(Main.MAX_SLOTS, n)
end

-- ---------------------------------------------------------------------------
-- the game's pieces

local function G()
	return Main.G
end

function Main.CharacterSlotOf(player)
	local g = G()
	if player == nil or player.Network == nil or g.TheSaveSystem == nil then
		return nil
	end
	local pid = player.Network:GetPlayerID()
	local slot = g.TheSaveSystem:GetCharacterForPlayerID(pid)
	return slot, pid
end

local function SaveOf(slot)
	local g = G()
	local save = slot ~= nil and g.TheSaveSystem:GetSaveForCharacterSlot(slot) or nil
	local pd = save ~= nil and rawget(save, "persistdata") or nil
	return save, pd
end

local function Stamp(b, player, slot)
	local g = G()
	b.saved = os.time()
	b.saved_text = os.date("%d %b %Y %H:%M")
	b.game = rawget(g, "APP_VERSION")
	b.pc = type(os.getenv) == "function" and os.getenv("COMPUTERNAME") or nil
	b.character_slot = slot
	if player ~= nil and player.GetCustomUserName ~= nil then
		local ok, who = pcall(player.GetCustomUserName, player)
		b.who = ok and who or nil
	end
	return b
end

local function CopyOfFile(pd)
	local data = Main.deepcopy(pd)
	data._savedata_metadata = nil
	return data
end

function Main.IsComplete(b)
	local d = type(b) == "table" and b.data or nil
	return type(d) == "table" and type(d.player) == "table" and type(d.playerdata) == "table"
		and type(d.playerdata.CharacterCreator) == "table"
end

-- ---------------------------------------------------------------------------
-- save

-- cb(ok, why)
function Main.SaveBuild(player, slot, cb)
	cb = cb or function() end
	local g = G()
	local cslot, pid = Main.CharacterSlotOf(player)
	if cslot == nil then
		return cb(false, "this player has no character file")
	end
	if type(slot) ~= "number" or slot < 1 or slot > Main.MAX_SLOTS or slot ~= math.floor(slot) then
		return cb(false, "no build slot " .. tostring(slot))
	end
	g.TheSaveSystem:SaveCharacterForPlayerID(pid, function()
		local ok, err = pcall(function()
			local _, pd = SaveOf(cslot)
			if type(pd) ~= "table" or type(pd.player) ~= "table" or type(pd.playerdata) ~= "table" then
				return cb(false, "the character's file is empty")
			end
			local b = Stamp({ data = CopyOfFile(pd) }, player, cslot)
			Store.Read(function(t, note)
				if t == nil then
					return cb(false, note)
				end
				t.builds[slot] = b
				Store.Write(t, function(okw, why)
					if okw then
						Log("saved character " .. cslot .. " as build " .. slot .. " (" .. Main.Describe(b) .. ") in " .. Store.where)
					end
					cb(okw, why)
				end)
			end)
		end)
		if not ok then
			cb(false, tostring(err))
		end
	end)
end

-- cb(ok, why)
function Main.DeleteBuild(slot, is_auto, cb)
	cb = cb or function() end
	Store.Read(function(t, note)
		if t == nil then
			return cb(false, note)
		end
		if is_auto then
			if t.auto[slot] == nil then
				return cb(false, "no backup " .. tostring(slot))
			end
			table.remove(t.auto, slot)
		else
			if t.builds[slot] == nil then
				return cb(false, "build " .. tostring(slot) .. " is empty")
			end
			t.builds[slot] = nil
		end
		Store.Write(t, cb)
	end)
end

-- ---------------------------------------------------------------------------
-- load

-- What can be loaded. gear: everything that isn't the look (gear, inventory, loadouts, gems, talents,
-- masteries, titles, unlocks, the mods' data); look: species, body parts, colours, paintbrush colours,
-- player colour.
Main.MODES = {
	all = { id = "all", name = "Everything", short = "everything", gear = true, look = true },
	all_face = { id = "all_face", name = "Everything, keep my face", short = "everything, face kept", gear = true, look = true, keep_face = true },
	look = { id = "look", name = "Look", short = "look", look = true },
	face = { id = "face", name = "Look, keep my face", short = "look, face kept", look = true, keep_face = true },
	colours = { id = "colours", name = "Colours only", short = "colours", colours = true },
	gear = { id = "gear", name = "Gear only", short = "gear", gear = true },
}
Main.MODE_ORDER = { "all", "all_face", "look", "face", "colours", "gear" }
Main.MAIN_MODES = { "all", "all_face" }               -- the load menu
Main.MORE_MODES = { "look", "face", "colours", "gear" } -- behind "More options"
Main.FACE_PARTS = { "EYES", "NOSE", "MOUTH" }
Main.OPTIONAL_PARTS = { "OTHER", "HAIR_FACE" } -- tails, beards: not every look has them
Main.LOOK_COMPONENTS = { gbj_colorgroupoverride = true, playercolour = true }
Main.KEEP_COMPONENTS = { questcentral = true, cropfarmer = true, dungeontracker = true, huntrooms = true }
-- The personal mods' data that only adds what it loads (fine on a new player, the game's own case): on
-- a character that already has its own, it's emptied to the mod's fresh state first, so the build's
-- skill loadouts (Skill Slots), tonic cycle (Tonic Swap) and second weapon (Two Weapons) come in
-- exactly, nothing of the old character's left mixed in. A build without that data = the fresh state.
Main.FRESH = {
	skillslotsdata = function(c) c.slots = {}; c.options = {}; c.loadouts = {} end,
	tonicswapdata = function(c) c.main = nil; c.off = {}; c.standin = nil end,
	twoweapons = function(c)
		c.cur = nil; c.prev = nil; c.loadouts = {}; c.memory = { powers = {}, sg = {} }; c.swap_attacks = nil; c.carried = nil
	end,
}

function Main.InTown()
	local g = G()
	local d = rawget(g, "TheDungeon")
	return d ~= nil and d.IsInTown ~= nil and d:IsInTown() == true
end

-- What stops a load (nil = it can go ahead).
function Main.CanLoad(player, b, mode)
	local g = G()
	local M = Main.MODES[mode or "all"]
	if M == nil then
		return "no way to load called " .. tostring(mode)
	end
	if not Main.IsComplete(b) then
		return "the build is incomplete"
	end
	if M.gear and not Main.InTown() then
		return "gear loads in town (a look loads anywhere)"
	end
	local net = rawget(g, "TheNet")
	if net ~= nil and net.IsHost ~= nil and net.IsInGame ~= nil and net:IsInGame() and not net:IsHost() then
		return "only the host can load builds"
	end
	if player == nil or (player.IsValid ~= nil and not player:IsValid()) then
		return "no player"
	end
	local cslot = Main.CharacterSlotOf(player)
	if cslot == nil then
		return "this player has no character file"
	end
	local save, pd = SaveOf(cslot)
	if save == nil or type(pd) ~= "table" then
		return "this character's file isn't loaded"
	end
	if Main.loading then
		return "a build is loading"
	end
	return nil
end

-- The character's file as it will be: cur (a copy of the character's file) with the picked part of
-- build data b.
function Main.Merge(cur, b, mode)
	local M = Main.MODES[mode]
	local m = Main.deepcopy(cur)
	m.player = type(m.player) == "table" and m.player or {}
	m.playerdata = type(m.playerdata) == "table" and m.playerdata or {}
	local bp, bpd = b.player or {}, b.playerdata or {}
	local cur_cc = type(m.playerdata.CharacterCreator) == "table" and m.playerdata.CharacterCreator or {}
	if M.gear then
		-- what the build doesn't have isn't carried over from the character (it's the build's fresh state)
		for k in pairs(m.player) do
			if bp[k] == nil and not Main.LOOK_COMPONENTS[k] and not Main.KEEP_COMPONENTS[k] then
				m.player[k] = nil
			end
		end
		for k, v in pairs(bp) do
			if not Main.LOOK_COMPONENTS[k] and not Main.KEEP_COMPONENTS[k] then
				m.player[k] = Main.deepcopy(v)
			end
		end
		for k, v in pairs(bpd) do
			if k ~= "CharacterCreator" and k ~= "PlayerUID" then
				m.playerdata[k] = Main.deepcopy(v)
			end
		end
	end
	if M.look then
		local cc = Main.deepcopy(bpd.CharacterCreator)
		cc.bodyparts = type(cc.bodyparts) == "table" and cc.bodyparts or {}
		if M.keep_face then
			local mine = type(cur_cc.bodyparts) == "table" and cur_cc.bodyparts or {}
			for _, part in ipairs(Main.FACE_PARTS) do
				cc.bodyparts[part] = mine[part]
			end
		end
		m.playerdata.CharacterCreator = cc
		m.player.gbj_colorgroupoverride = Main.deepcopy(bp.gbj_colorgroupoverride)
		m.player.playercolour = Main.deepcopy(bp.playercolour)
	elseif M.colours then
		local cc = Main.deepcopy(cur_cc)
		cc.colorgroups = type(cc.colorgroups) == "table" and cc.colorgroups or {}
		local theirs = type(bpd.CharacterCreator) == "table" and bpd.CharacterCreator.colorgroups or {}
		for k, v in pairs(type(theirs) == "table" and theirs or {}) do
			cc.colorgroups[k] = v
		end
		m.playerdata.CharacterCreator = cc
		m.player.gbj_colorgroupoverride = Main.deepcopy(bp.gbj_colorgroupoverride)
	end
	return m
end

local function Later(fn)
	local inst = rawget(G(), "TheGlobalInstance")
	if inst ~= nil and inst.DoTaskInTime ~= nil then
		inst:DoTaskInTime(0, fn)
	else
		fn()
	end
end
Main.Later = Later

-- The look's extras on the character: tails / beards the new look doesn't have, the paintbrush
-- colours (FURY's way when it's there, so every colour group shows again), the player colour.
function Main.ApplyLookExtras(player, m, M)
	local comps = player.components or {}
	local creator = comps.charactercreator
	local cc = m.playerdata.CharacterCreator or {}
	local want = type(cc.bodyparts) == "table" and cc.bodyparts or {}
	if creator ~= nil and type(creator.bodyparts) == "table" and creator.SetBodyPart ~= nil then
		for _, part in ipairs(Main.OPTIONAL_PARTS) do
			if want[part] == nil and creator.bodyparts[part] ~= nil then
				creator:SetBodyPart(part, nil)
			end
		end
	end
	local gbj = comps.gbj_colorgroupoverride
	if gbj ~= nil then
		local data = m.player.gbj_colorgroupoverride
		local overrides = type(data) == "table" and type(data.overrides) == "table" and data.overrides or {}
		local okf, FogPresets = pcall(require, "tools.fog_presets")
		if creator ~= nil and okf and type(FogPresets) == "table" and type(FogPresets.SetCustomColors) == "function" then
			FogPresets.SetCustomColors(creator, gbj, overrides)
		elseif gbj.OnLoad ~= nil then
			gbj.overrides = {}
			gbj:OnLoad({ overrides = Main.deepcopy(overrides) })
		end
	end
	if M.look and comps.playercolour ~= nil and comps.playercolour.OnLoad ~= nil then
		comps.playercolour:OnLoad(m.player.playercolour) -- (none = the game's own)
	end
end

-- dyes are only added by the game's loading: the ones on now go first
local function ClearDyes(player)
	local dyer = player.components.equipmentdyer
	local applied = dyer ~= nil and rawget(dyer, "applied_dyes") or nil
	if type(applied) ~= "table" or dyer.SetEquipmentDye == nil then
		return
	end
	local list = {}
	for slot, sets in pairs(applied) do
		for set in pairs(type(sets) == "table" and sets or {}) do
			list[#list + 1] = { slot, set }
		end
	end
	for _, e in ipairs(list) do
		dyer:SetEquipmentDye(e[1], e[2], nil)
	end
end

-- m onto the live character (see the top of this file). Errors are raised.
function Main.ApplyInPlace(player, cslot, pid, m, M)
	local g = G()
	local save, pd = SaveOf(cslot)
	if save == nil or type(pd) ~= "table" then
		error("character " .. tostring(cslot) .. " has no file", 0)
	end
	local uid = type(pd.playerdata) == "table" and pd.playerdata.PlayerUID or nil
	if uid ~= nil then
		m.playerdata.PlayerUID = uid
	end
	for k in pairs(pd) do
		pd[k] = nil
	end
	for k, v in pairs(Main.deepcopy(m)) do
		pd[k] = v
	end
	save.dirty = true
	-- the look, unlocks and the rest of playerdata: the game's own character load
	g.TheSaveSystem:LoadCharacterAsPlayerID(cslot, pid)
	if M.gear then
		local comps = {}
		for k, v in pairs(pd.player or {}) do
			if not Main.LOOK_COMPONENTS[k] and not Main.KEEP_COMPONENTS[k] then
				comps[k] = v
			end
		end
		ClearDyes(player)
		for name, fresh in pairs(Main.FRESH) do
			local cmp = player.components[name]
			if cmp ~= nil then
				local okf, ferr = pcall(fresh, cmp)
				if not okf then
					Log(name .. " couldn't be emptied first (" .. tostring(ferr) .. "): the build's goes on top")
				end
			end
		end
		player:PushEvent("character_slot_changed")
		player:SetPersistData(comps)
		player:PostLoadWorld(comps)
	end
	if M.look or M.colours then
		Main.ApplyLookExtras(player, m, M)
	end
	return save
end

function Main.ReloadTown()
	local g = G()
	local ok, RoomLoader = pcall(require, "roomloader")
	if not ok or type(RoomLoader) ~= "table" or type(RoomLoader.LoadTownLevel) ~= "function" then
		return false, "a game update changed RoomLoader.LoadTownLevel"
	end
	if type(RoomLoader.ResetNextLoad) == "function" then
		RoomLoader.ResetNextLoad() -- a full reload, as from a run (not the in-place one that crashed in 0.1.0)
	end
	local town = rawget(g, "TOWN_LEVEL")
	Later(function() RoomLoader.LoadTownLevel(town) end)
	return true
end

-- The load went wrong: the character as it was goes back on; if even that fails, its file is put back
-- and the town loads again. cb(why)
function Main.Restore(player, cslot, pid, before, err, cb)
	local all = Main.MODES.all
	local ok2, err2 = pcall(function()
		local m = Main.deepcopy(before)
		local save = Main.ApplyInPlace(player, cslot, pid, m, all)
		Later(function()
			pcall(Main.ApplyLookExtras, player, m, all)
			save:Save(player, function() end)
		end)
	end)
	if ok2 then
		Log("the build didn't go on (" .. tostring(err) .. "); the character is back as it was")
		return cb("it didn't go on (" .. tostring(err) .. "); your character is back as it was")
	end
	Log("the build didn't go on (" .. tostring(err) .. ") and putting the character back failed too (" .. tostring(err2) .. "): its file is put back and the town loads again")
	local save, pd = SaveOf(cslot)
	if save ~= nil and type(pd) == "table" then
		for k in pairs(pd) do
			pd[k] = nil
		end
		for k, v in pairs(Main.deepcopy(before)) do
			pd[k] = v
		end
		save.dirty = true
		save:Save(nil, function()
			Main.ReloadTown()
		end)
	end
	cb("it didn't go on (" .. tostring(err) .. "); your character's file is back as it was and the town loads again")
end

-- cb(ok, why) when it's on (or not). b: a build (from the file); label: how it's called in notes;
-- mode: one of Main.MODES (default "all"); before_apply: called just before it goes on (the mirror
-- closes then).
function Main.LoadBuild(player, b, label, mode, cb, before_apply)
	cb = cb or function() end
	mode = mode or "all"
	local g = G()
	local why = Main.CanLoad(player, b, mode)
	if why ~= nil then
		return cb(false, why)
	end
	local M = Main.MODES[mode]
	local cslot, pid = Main.CharacterSlotOf(player)
	Main.loading = true
	local function Fail(text)
		Main.loading = nil
		cb(false, text)
	end
	g.TheSaveSystem:SaveAll(function()
		local ok, err = pcall(function()
			local _, pd = SaveOf(cslot)
			if type(pd) ~= "table" or type(pd.player) ~= "table" then
				return Fail("this character's file is empty")
			end
			local before = CopyOfFile(pd)
			local what = label .. (mode ~= "all" and (", " .. M.short) or "")
			local backup = Stamp({ auto = true, before = what, data = Main.deepcopy(before) }, player, cslot)
			Store.Read(function(t, note)
				if t == nil then
					return Fail(note .. "; nothing loaded")
				end
				table.insert(t.auto, 1, backup)
				while #t.auto > Main.settings.auto_backups do
					table.remove(t.auto)
				end
				Store.Write(t, function(okw, werr)
					if not okw then
						return Fail("the automatic backup couldn't be written (" .. tostring(werr) .. "); nothing loaded")
					end
					local okm, m = pcall(Main.Merge, before, b.data, mode)
					if not okm then
						return Fail("the build couldn't be read (" .. tostring(m) .. "); nothing loaded")
					end
					if before_apply ~= nil then
						pcall(before_apply)
					end
					Later(function()
						local oka, save = pcall(Main.ApplyInPlace, player, cslot, pid, m, M)
						if not oka then
							return Main.Restore(player, cslot, pid, before, save, function(text)
								Fail(text)
							end)
						end
						Later(function()
							if M.look or M.colours then
								pcall(Main.ApplyLookExtras, player, m, M)
							end
							save:Save(player, function(success)
								if success == false then
									Log("character " .. cslot .. " has the build on, but its file didn't save yet (the next save writes it)")
								end
							end)
							Main.loading = nil
							Log("character " .. cslot .. " is now " .. what .. " (its state before is backup 1)")
							Main.Note("Build loaded", what)
							cb(true)
						end)
					end)
				end)
			end)
		end)
		if not ok then
			Fail(tostring(err))
		end
	end)
end

-- ---------------------------------------------------------------------------

function Main.Install(G_, settings)
	Main.G = G_
	Main.settings = settings or Main.settings
	Store.Configure(Main.settings)
	local g = G_
	if g.TheSim == nil or g.TheSim.GetPersistentString == nil then
		return false, "the game's saved strings (TheSim) aren't there"
	end
	local okm, err = pcall(Store.Migrate, function(n, note)
		if note ~= nil then
			Log(note)
		end
	end)
	if not okm then
		Log("copying 0.1.0's builds over didn't work: " .. tostring(err))
	end
	return true, "builds file: " .. Store.where
end

return Main
