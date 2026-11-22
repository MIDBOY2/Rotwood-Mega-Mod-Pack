-- Save States: saving, loading (one load, through the game's own run start),
-- the room's auto save, and the steps after a load.
--
-- A load:
--  1. everything is checked first (refused with the reason, nothing changed):
--     the save, the place and its map, the room, the players, each player's
--     2 weapon classes (Rebuild), and a dry run of each character's data
--  2. your state right now goes to the auto history (undo)
--  3. Replicate: the saved gear is put on (given if you don't own it)
--  4. the game starts a run with the saved place, seed, map, Frenzy level and
--     weather (the Blight: its saved legs first). The game tells everything
--     "new run", builds the map and writes the run file and each player's file
--  5. just before it loads the first room: the saved map goes into the run
--     file, each player's file gets the saved run parts (built from that file,
--     checked identical everywhere else), and the saved room loads instead
--  6. after the load: potion charges from your own potion, the saved HP again
--     (after the room's own "on entering" effects), a note, then the room's
--     auto save
local SS = require "savestates.main"
local D = require "savestates.data"
local C = require "savestates.capture"
local Gear = require "savestates.gear"
local Same = require "savestates.sameroom"

local L = {}

L.G = nil          -- GLOBAL
L.store = nil
L.RoomLoader = nil
L.biomes = nil
L.pending = nil    -- a load between its start and the reload
L.post = nil       -- after the reload: what's left to do
L.busy = false
L.autosave_task = nil

local function G()
	return L.G
end

local function Later(sec, fn)
	local g = G()
	local inst = g.TheGlobalInstance
	if inst ~= nil and inst.DoTaskInTime ~= nil then
		return inst:DoTaskInTime(sec, function()
			local ok, err = pcall(fn)
			if not ok then
				SS.Log("error: " .. tostring(err))
			end
		end)
	end
	pcall(fn)
	return nil
end
L.Later = Later

-- ---------------------------------------------------------------------------
-- save

-- cb(ok, why): after the file is written (the Saved Hunts page refreshes);
-- SS.on_saved(slot) too, for a page open while a key saves
function L.Save(slot, cb)
	local function Done(ok, why)
		if cb ~= nil then
			pcall(cb, ok, why)
		end
		if ok and SS.on_saved ~= nil then
			pcall(SS.on_saved, slot)
		end
	end
	if L.busy then
		SS.Note("Busy", "a load is in progress")
		Done(false, "a load is in progress")
		return
	end
	if not L.store.loaded then
		SS.Note("Not saved", "the save list is still loading")
		Done(false, "the save list is still loading")
		return
	end
	local st, why = C.Take("manual")
	if st == nil then
		SS.Note("Not saved", why)
		Done(false, why)
		return
	end
	local line = D.Summary(st)
	L.store:Add("manual", st, slot, line, function(ok, id)
		if ok then
			SS.Note("Saved slot " .. slot, line)
			Done(true)
		else
			SS.Note("Not saved", "the file couldn't be written (slot " .. slot .. ")")
			Done(false, "the file couldn't be written")
		end
	end)
end

function L.AutoSave(reason)
	local s = SS.settings
	if not s.auto_save or L.busy or L.pending ~= nil or L.post ~= nil or not L.store.loaded then
		return
	end
	local st = C.Take("auto")
	if st == nil then
		return
	end
	L.store:Add("auto", st, 0, D.Summary(st), function(ok)
		if not ok then
			SS.Log("the room's auto save couldn't be written")
		else
			SS.Debug("auto save: " .. D.Summary(st) .. (reason and (" (" .. reason .. ")") or ""))
		end
	end)
end

function L.ScheduleAutoSave(reason)
	if L.autosave_task ~= nil then
		pcall(function() L.autosave_task:Cancel() end)
		L.autosave_task = nil
	end
	L.autosave_task = Later(SS.settings.auto_save_delay, function()
		L.autosave_task = nil
		L.AutoSave(reason)
	end)
end

-- ---------------------------------------------------------------------------
-- checks

-- the map's index now (by its name: the list can change when mods change)
function L.ResolveAlt(run)
	local biome = L.biomes.locations[run.location_id]
	if biome == nil then
		return false, "the place " .. tostring(run.location_id) .. " isn't in the game"
	end
	if run.mapgen_name == nil then
		if run.alt_mapgen_id ~= nil then
			return false, "the save's map has no name"
		end
		return true, nil, biome
	end
	for i, name in ipairs(biome.alternate_mapgens or {}) do
		if name == run.mapgen_name then
			return true, i, biome
		end
	end
	return false, "the map " .. tostring(run.mapgen_name) .. " isn't there now (a mod off or changed?)"
end

local function PlayerLine(i, need, have)
	return string.format("Player %d needs %s (has %s)", i, D.ClassesText(need), D.ClassesText(have))
end

-- everything before anything changes. ok, why, plan
function L.Check(st, mode)
	local g = G()
	local ok, why = D.CheckState(st)
	if not ok then
		return false, why
	end
	if g.TheNet ~= nil and g.TheNet:IsInGame() and not g.TheNet:IsHost() then
		return false, "only the host can load"
	end
	if g.TheDungeon == nil or g.TheWorld == nil or not g.TheWorld.is_initialized or g.TheWorld.is_destroying then
		return false, "not in a room right now"
	end
	local okr, alt, biome = L.ResolveAlt(st.run)
	if not okr then
		return false, alt
	end
	if (tonumber(st.run.room_id) or 0) < 1 then
		return false, "the save's room isn't valid"
	end
	if st.run.trek ~= nil then
		local trek = g.TheDungeon:GetTrek()
		if trek == nil or type(st.run.trek.cfg) ~= "table" then
			return false, "the Blight data is missing"
		end
	end
	local players = C.LocalPlayers()
	if #players ~= #st.players then
		return false, string.format("the save has %d player%s, there %s %d now", #st.players, #st.players == 1 and "" or "s", #players == 1 and "is" or "are", #players)
	end
	local plan = { alt = alt, biome = biome, players = {} }
	local lines = {}
	for i, inst in ipairs(players) do
		local saved = st.players[i]
		local classes, held, other = C.Classes(inst)
		local pl = { inst = inst, slot = C.CharSlot(inst), saved = saved, classes = classes, held = held, other = other }
		if pl.slot == nil then
			return false, "player " .. i .. " has no character slot"
		end
		if mode == "rebuild" and not D.SameClasses(saved.classes, classes) then
			lines[#lines + 1] = PlayerLine(i, saved.classes, classes)
		end
		-- a dry run of the character's data with the saved run parts
		local okm, err = pcall(function()
			local B = inst:GetPersistData()
			local M = D.Merge(B, saved, { counters = SS.settings.restore_counters, held_matches = true })
			local okg, gwhy = D.Guard(B, M)
			if not okg then
				error(gwhy, 0)
			end
		end)
		if not okm then
			return false, "player " .. i .. ": " .. tostring(err)
		end
		plan.players[i] = pl
	end
	if #lines > 0 then
		return false, table.concat(lines, "; ")
	end
	return true, nil, plan
end

-- ---------------------------------------------------------------------------
-- load

local function Refuse(label, why)
	SS.Note("Can't load " .. tostring(label), why)
end

function L.LoadSlot(slot, mode)
	if L.busy then
		SS.Note("Busy", "a load is in progress")
		return
	end
	if not L.store.loaded then
		SS.Note("Can't load", "the save list is still loading")
		return
	end
	local id = L.store:SlotId(slot)
	local label = slot == 0 and "the latest auto save" or ("slot " .. slot)
	if id == nil then
		SS.Note("Can't load " .. label, "it's empty")
		return
	end
	L.LoadId(id, mode, label)
end

-- The save with its players in another order: order[i] = which saved player
-- today's player i gets (nil, or not a reordering of all of them: the save
-- as it is). Only the list is new; the saved players are the same tables.
function L.Reorder(st, order)
	if type(st) ~= "table" or type(st.players) ~= "table" or type(order) ~= "table" or #order ~= #st.players then
		return st
	end
	local seen = {}
	for _, i in ipairs(order) do
		if type(i) ~= "number" or st.players[i] == nil or seen[i] then
			return st
		end
		seen[i] = true
	end
	local copy = {}
	for k, v in pairs(st) do
		copy[k] = v
	end
	copy.players = {}
	for n, i in ipairs(order) do
		copy.players[n] = st.players[i]
	end
	return copy
end

-- 2 players whose characters are the other way round from the save (each
-- one's character slot is the other saved player's)
function L.LooksSwapped(st)
	if type(st) ~= "table" or type(st.players) ~= "table" or #st.players ~= 2 then
		return false
	end
	local ok, players = pcall(C.LocalPlayers)
	if not ok or type(players) ~= "table" or #players ~= 2 then
		return false
	end
	local a, b = C.CharSlot(players[1]), C.CharSlot(players[2])
	local sa, sb = st.players[1].slot, st.players[2].slot
	return a ~= nil and b ~= nil and sa ~= nil and sb ~= nil and a ~= b and a == sb and b == sa
end

-- opts.order: the saved players' order for today's players (L.Reorder)
function L.LoadId(id, mode, label, opts)
	if L.busy then
		SS.Note("Busy", "a load is in progress")
		return
	end
	L.busy = true
	L.store:Get(id, function(st)
		if st == nil then
			L.busy = false
			Refuse(label, "the file couldn't be read")
			return
		end
		if type(opts) == "table" and opts.order ~= nil then
			st = L.Reorder(st, opts.order)
		end
		local ok, err = pcall(L.Start, st, mode, label, id)
		if not ok then
			L.busy = false
			L.pending = nil
			Refuse(label, "an error before anything changed: " .. tostring(err))
		end
	end)
end

local function ModeName(mode)
	return mode == "replicate" and "Replicate" or "Rebuild"
end

-- Two Weapons: the saved weapon in hand first (its swap)
local function MatchHeld(pl)
	local tw = pl.inst.components.twoweapons
	if pl.saved.held == nil or pl.held == pl.saved.held or tw == nil then
		return pl.held == pl.saved.held
	end
	if pl.other ~= pl.saved.held then
		return false
	end
	local ok = pcall(function()
		if tw._Swap ~= nil then
			tw:_Swap()
		else
			tw:Swap()
		end
	end)
	if not ok then
		return false
	end
	local _, held = C.Classes(pl.inst)
	return held == pl.saved.held
end

-- The fade to black before a load: the game's own, as its run start does it
-- (components/startrunportal.lua: TheFrontEnd:Fade(FADE_OUT, 0.5, ...)).
-- fn after it (or right away without a frontend / with fade_load = false; a
-- fade that never calls back: the load goes on a second later anyway).
L.FADE_TIME = 0.5
L.faded = false
function L.FadeOut(fn)
	local g = G()
	local fe, OUT = g.TheFrontEnd, rawget(g, "FADE_OUT")
	L.faded = false
	if SS.settings.fade_load == false or fe == nil or fe.Fade == nil or OUT == nil then
		return fn()
	end
	local done = false
	local function Go()
		if not done then
			done = true
			fn()
		end
	end
	-- (marked before: the fade may call back at once)
	L.faded = true
	local ok = pcall(fe.Fade, fe, OUT, L.FADE_TIME, function()
		local okg, err = pcall(Go)
		if not okg then
			SS.Log("error: " .. tostring(err))
		end
	end)
	if not ok then
		if not done then
			L.faded = false
		end
		return Go()
	end
	Later(L.FADE_TIME + 1, Go)
end

-- a load stopped after the fade: the screen comes back
function L.FadeIn()
	if not L.faded then
		return
	end
	L.faded = false
	local g = G()
	local fe, IN = g.TheFrontEnd, rawget(g, "FADE_IN")
	if fe ~= nil and fe.Fade ~= nil and IN ~= nil then
		pcall(fe.Fade, fe, IN, L.FADE_TIME)
	end
end

function L.Start(st, mode, label, id)
	local g = G()
	local ok, why, plan = L.Check(st, mode)
	if not ok then
		L.busy = false
		Refuse(label, why)
		return
	end
	local function Go()
		local ok2, err = pcall(L._Go, st, mode, label, id, plan)
		if not ok2 then
			L.pending = nil
			L.busy = false
			L.FadeIn()
			SS.Note("Load stopped", tostring(err) .. " (your state before it is in the auto history)")
		end
	end
	-- the fade to black, then the load (the gear, the run start)
	local function Faded()
		L.FadeOut(Go)
	end
	-- 2. undo: your state as it was when you asked (before the fade)
	if SS.settings.undo_before_load and C.CanSave() then
		local now = C.Take("undo")
		if now ~= nil then
			L.store:Add("undo", now, nil, "before loading " .. tostring(label) .. ": " .. D.Summary(now), function()
				Faded()
			end)
			return
		end
	end
	Faded()
end

function L._Go(st, mode, label, id, plan)
	local g = G()
	local warnings = {}
	-- 3. gear
	for i, pl in ipairs(plan.players) do
		if mode == "replicate" then
			local keep = SS.settings.restore_loadout_after_run or SS.settings.replicate_lend
			local before = keep and Gear.Record(pl.inst) or nil
			local report = Gear.Apply(pl.inst, pl.saved.gear)
			for _, f in ipairs(report.failed) do
				warnings[#warnings + 1] = "player " .. i .. ": " .. f
			end
			if before ~= nil then
				local old = L.store:GetLoadout(pl.slot)
				local rec = old ~= nil and old or before -- an earlier Replicate's record: the first gear stays the one to put back
				rec.lend = SS.settings.replicate_lend or rec.lend
				rec.given = rec.given or {}
				for _, gv in ipairs(report.given) do
					rec.given[#rec.given + 1] = gv
				end
				L.store:SetLoadout(pl.slot, rec)
			end
			local classes, held, other = C.Classes(pl.inst)
			pl.classes, pl.held, pl.other = classes, held, other
			if not D.SameClasses(pl.saved.classes, classes) then
				-- put back what was worn and stop
				if before ~= nil then
					pcall(Gear.Restore, pl.inst, before)
					L.store:ClearLoadout(pl.slot)
				end
				error(PlayerLine(i, pl.saved.classes, classes) .. " (couldn't put the saved weapons on)", 0)
			end
		end
		pl.held_matches = MatchHeld(pl)
		-- the powers your gear gives now (the run start clears them; the merge
		-- puts the saved ones back when they're the same: see D.Merge)
		local pm = pl.inst.components.powermanager
		pl.gear_powers = {
			from = type(pm.powers_from_equipment) == "table" and D.deepcopy(pm.powers_from_equipment) or nil,
			overridden = type(pm.overridden_equipment_powers) == "table" and D.deepcopy(pm.overridden_equipment_powers) or nil,
		}
	end
	-- the run's parameters
	local run = st.run
	local trek = g.TheDungeon:GetTrek()
	local params
	if run.trek ~= nil then
		pcall(g.TheNet.CancelRunRequest, g.TheNet, 0)
		if trek:IsActive() then
			trek:Reset()
		end
		trek:OnLoad(D.deepcopy(run.trek))
		if not trek:IsActive() then
			error("the Blight data didn't load", 0)
		end
		if g.TheNet:IsHost() and g.TrekCommand ~= nil then
			g.TheNet:HostSetTrekData(g.TrekCommand.id.Begin, trek.data)
		end
		params = D.deepcopy(trek:GetCurrentLegParams())
		if type(params) ~= "table" then
			error("the Blight leg has no run", 0)
		end
	else
		if trek ~= nil and trek:IsActive() then
			pcall(g.TheNet.CancelRunRequest, g.TheNet, 0)
			trek:Reset()
		end
		params = {}
	end
	params.location_id = run.location_id
	params.region_id = run.region_id or plan.biome.region_id
	params.seed = run.seed
	params.alt_mapgen_id = plan.alt
	params.ascension = tonumber(run.ascension) or 0
	params.is_weather_enabled = run.is_weather_enabled
	-- what the reload needs
	local post = { time = os.time(), id = id, label = label, mode = mode, room_id = run.room_id,
		summary = D.Summary(st), players = {}, warnings = warnings, same_room = type(run.encounter) == "table" }
	for i, pl in ipairs(plan.players) do
		post.players[i] = {
			slot = pl.slot,
			potion = D.deepcopy(pl.saved.potion),
			hp = pl.saved.hp,
			exact = SS.settings.exact_hp,
		}
	end
	L.pending = { stage = "started", st = st, mode = mode, label = label, plan = plan, post = post, time = os.time() }
	-- 4. the game's own run start (the same calls as its debug run start)
	pcall(function() g.TheAudio:StopAllSounds() end)
	local RL = L.RoomLoader
	local wm = g.TheDungeon:GetDungeonMap()
	local quest = wm:BuildQuestParams(params.location_id)
	quest = RL.EvaluateSpawnRequests(params.location_id, quest)
	RL.StartRun(params, quest)
	-- no first room in 30 seconds: the load is off
	Later(30, function()
		if L.pending ~= nil and L.pending.stage == "started" then
			L.pending = nil
			L.busy = false
			L.FadeIn()
			SS.Note("Load stopped", "the run didn't start (your state before it is in the auto history)")
		end
	end)
end

-- 5. the game is about to load the run's first room
function L.OnLoadRoom(orig, worldprefab, scenegenprefab, roomid, is_debug_room, prev_room_cardinal)
	local job = L.pending
	if job == nil or job.stage ~= "started" or is_debug_room then
		return orig(worldprefab, scenegenprefab, roomid, is_debug_room, prev_room_cardinal)
	end
	job.stage = "writing"
	local g = G()
	local st = job.st
	local ok, err = pcall(function()
		local ss = g.TheSaveSystem
		-- every merge built and checked before anything is written
		local merged = {}
		for i, pl in ipairs(job.plan.players) do
			local save = ss:GetSaveForCharacterSlot(pl.slot)
			local B = save ~= nil and save:GetValue("player") or nil
			if type(B) ~= "table" then
				error("player " .. i .. ": no character file", 0)
			end
			local M, info = D.Merge(B, st.players[i], { counters = SS.settings.restore_counters, held_matches = pl.held_matches, gear_powers = pl.gear_powers })
			local okg, why = D.Guard(B, M)
			if not okg then
				error("player " .. i .. ": " .. tostring(why), 0)
			end
			for _, sk in ipairs(info.skipped) do
				job.post.warnings[#job.post.warnings + 1] = "player " .. i .. ": " .. sk
			end
			merged[i] = { save = save, M = M }
		end
		local W = D.deepcopy(st.worldmap)
		W.mgrun_data.alt_mapgen_id = job.plan.alt
		-- the room's own enemies again (0.5.0), read once by the room's draw
		local okn, rec = pcall(Same.ForLoad, st.run)
		W[Same.KEY] = okn and rec or nil
		-- write: the run file, each player's file, and what's left for after the reload
		local cb = g.MultiCallback()
		ss.dungeon:SetValue("worldmap", W)
		ss.dungeon:Save(cb:AddInstance())
		for _, m in ipairs(merged) do
			m.save:SetValue("player", m.M)
			m.save:Save(nil, cb:AddInstance())
		end
		L.store.io.Write("pending", job.post, cb:AddInstance())
		job.stage = "loading"
		cb:WhenAllComplete(function(success)
			if not success then
				SS.Log("a file before the reload wasn't written; loading anyway")
			end
			orig(st.run.world_prefab, st.run.scenegen_prefab or scenegenprefab, st.run.room_id, nil, nil)
		end)
	end)
	if not ok then
		-- nothing written: the game's own first room of the new run
		L.pending = nil
		L.busy = false
		SS.Note("Load stopped", tostring(err) .. " (a fresh run instead; your state before it is in the auto history)")
		return orig(worldprefab, scenegenprefab, roomid, is_debug_room, prev_room_cardinal)
	end
end

function L.Install(RoomLoader)
	assert(type(RoomLoader) == "table" and type(RoomLoader.LoadDungeonLevel) == "function" and type(RoomLoader.StartRun) == "function"
		and type(RoomLoader.EvaluateSpawnRequests) == "function", "the game's room loader changed")
	L.RoomLoader = RoomLoader
	local orig = RoomLoader.LoadDungeonLevel
	RoomLoader.LoadDungeonLevel = function(...)
		return L.OnLoadRoom(orig, ...)
	end
	return true, "loads go through the game's run start"
end

-- ---------------------------------------------------------------------------
-- 6. after the reload

-- The order after the reload (seen in client_log.txt): the players are spawned
-- at the room's entrance (their enter_room) BEFORE this file is read, and are
-- only in the game's player list a moment AFTER it. So neither enter_room nor
-- the read could start the last step, and it ran at the next door instead,
-- with the save's potion charges and HP (0.1.0-0.1.2). Now a short wait:
-- every half second until the players are in, then the last step once.
L.POST_POLL = 0.5   -- seconds between looks
L.POST_TRIES = 60   -- 30 seconds at most
L.POST_SETTLE = 0.5 -- after the players are in: the room's own start first (as 0.1.2)
L.post_wait = 0     -- the running wait (a newer one replaces it)

local function PostReady(post)
	local g = G()
	if g.TheDungeon == nil or g.TheWorld == nil or g.TheWorld.is_destroying then
		return false
	end
	if g.TheDungeon:IsInTown() then
		return true -- ApplyPost drops it
	end
	local n = #C.LocalPlayers()
	return n > 0 and n >= #(post.players or {})
end

function L.WaitForPost()
	if L.post == nil then
		return
	end
	L.post_wait = L.post_wait + 1
	local me = L.post_wait
	local tries = 0
	local function Step()
		if me ~= L.post_wait or L.post == nil then
			return
		end
		if PostReady(L.post) then
			Later(L.POST_SETTLE, function()
				if me == L.post_wait then
					L.ApplyPost()
				end
			end)
			return
		end
		tries = tries + 1
		if tries > L.POST_TRIES then
			SS.Log("the players weren't there after " .. (L.POST_POLL * L.POST_TRIES) .. " s: the load's last step with who's there")
			L.ApplyPost()
			return
		end
		Later(L.POST_POLL, Step)
	end
	Step()
end

-- at the game's start: a load that just happened (the pending file)
function L.ReadPending(cb)
	L.store.io.Read("pending", function(t)
		if type(t) == "table" and type(t.time) == "number" and os.time() - t.time < 600 and type(t.players) == "table" then
			L.post = t
		end
		if t ~= nil then
			L.store.io.Erase("pending", function() end)
		end
		if L.post ~= nil then
			L.WaitForPost()
		end
		if cb then
			cb()
		end
	end)
end

local function FindPost(post, slot)
	for _, p in ipairs(post.players) do
		if p.slot == slot then
			return p
		end
	end
	return nil
end

function L.ApplyPost()
	local post = L.post
	if post == nil then
		return
	end
	L.post = nil
	L.post_wait = L.post_wait + 1 -- any wait still running stops
	local g = G()
	if g.TheDungeon == nil or g.TheDungeon:IsInTown() then
		SS.Log("the load's last step skipped: in camp")
		return
	end
	local notes = {}
	local wm = g.TheDungeon:GetDungeonMap()
	local room = wm ~= nil and wm:GetCurrentRoomId() or nil
	-- the room's enemies (0.5.0): said only when they aren't the saved ones
	pcall(function()
		Same.Clear(wm)
		if not Same.on then
			return
		end
		if post.same_room and Same.result ~= "same" and Same.result ~= nil then
			notes[#notes + 1] = "the room's enemies drawn again (" .. tostring(Same.result) .. ")"
		elseif post.same_room == false and Same.last ~= nil then
			notes[#notes + 1] = "the room's enemies drawn again (a save from before 0.5.0)"
		end
	end)
	if room ~= post.room_id then
		-- another room's potion charges and HP are that room's: never the save's
		SS.Note("Loaded " .. tostring(post.label) .. " (" .. ModeName(post.mode) .. ")", tostring(post.summary)
			.. " | potion charges and HP not set: not the saved room (" .. tostring(room) .. ")")
		L.ScheduleAutoSave("after the load")
		return
	end
	for _, inst in ipairs(C.LocalPlayers()) do
		local p = FindPost(post, C.CharSlot(inst))
		if p ~= nil then
			-- potion charges from your own potion
			pcall(function()
				local pd, ut = inst.components.potiondrinker, inst.components.usetracker
				local def = pd:GetEquippedPotionDef("POTIONS")
				if def ~= nil and type(p.potion) == "table" then
					local max = pd:GetMaxUses()
					local target = D.PotionTarget(p.potion.remaining, p.potion.max, max)
					local used = math.max(0, max - target)
					ut:ResetUses(def.name)
					if used > 0 then
						ut:Use(def.name, used)
					end
				end
			end)
			-- the saved HP, after the room's own effects
			if p.exact then
				pcall(function()
					local h = inst.components.health
					local v = p.hp ~= nil and math.min(p.hp, h:GetMax()) or h:GetMax()
					h:SetCurrent(v, true)
				end)
			end
		end
	end
	for _, w in ipairs(post.warnings or {}) do
		notes[#notes + 1] = w
	end
	SS.Note("Loaded " .. tostring(post.label) .. " (" .. ModeName(post.mode) .. ")", tostring(post.summary) .. (#notes > 0 and (" | " .. table.concat(notes, "; ")) or ""))
	L.ScheduleAutoSave("after the load")
end

-- ---------------------------------------------------------------------------
-- a player entered a room (the game's enter_room)
function L.OnEnterRoom(inst)
	local g = G()
	if not inst:IsLocal() or g.TheDungeon == nil then
		return
	end
	if g.TheDungeon:IsInTown() then
		Later(1.0, function() L.RestoreLoadout(inst) end)
		return
	end
	if L.post ~= nil then
		L.WaitForPost()
		return
	end
	L.ScheduleAutoSave("room")
end

-- in town after a Replicate run: your own gear back on
function L.RestoreLoadout(inst)
	if not inst:IsValid() or not L.store.loaded then
		return
	end
	local slot = C.CharSlot(inst)
	local rec = slot ~= nil and L.store:GetLoadout(slot) or nil
	if rec == nil then
		return
	end
	local problems = Gear.Restore(inst, rec)
	L.store:ClearLoadout(slot)
	SS.Note("Your gear is back on", #problems > 0 and ("missing: " .. table.concat(problems, ", ")) or nil)
end

return L
