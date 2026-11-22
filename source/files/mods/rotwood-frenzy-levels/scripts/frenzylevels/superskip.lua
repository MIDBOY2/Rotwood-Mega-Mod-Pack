-- Frenzy Levels: the Super Frenzy level skip, main hunts (0.11.0, user
-- 2026-11-14: "after beating super frenzy 1, allow LB / RB all the way to
-- super frenzy 5 regardless of weapons ... register the win across all
-- levels up to it on both weapons, one heart per clear").
--
-- The game (components/ascensionmanager.lua, widgets/ftf/dungeonselection/
-- superfrenzyselectionwidget.lua):
--  * the Super Frenzy panel on the map goes up to one level above what the
--    weapon in your hand has cleared on that hunt (SetLocation: max_level =
--    highest completed + 1)
--  * a win records one level up from that weapon's own record, even when the
--    run's level was higher (GetEffectiveCompletionLevel: "players should
--    only ever unlock 1 level at a time"; the game lets a player join a
--    higher host's run)
--  * the boss gives that weapon's Imbued Heartstone when the level is new for
--    it (soul_drops.lua, IsEligibleForSuperFrenzyHeart): one per run
-- Here (super_skip in the settings):
--  * unlock = "any_hunt" (mode 2): once you've beaten any main boss at Super
--    Frenzy 1 (any weapon: read from the game's own records, so a save that
--    already has one works at once), every main hunt's Super Frenzy panel goes
--    to Super Frenzy 5 with any weapon (still only where the game has opened
--    Super Frenzy: its end-game unlock)
--    unlock = "this_hunt" (mode 1): a weapon goes to 5 on a hunt once it has
--    cleared Super Frenzy 1 there; without that, the game's one level
--  * a win at Super Frenzy N records every level up to N for each weapon you
--    hold (the hand one and, both_weapons, Two Weapons' second one) that is
--    open by the rule above; a weapon that isn't gets the game's one level up
--  * one Imbued Heartstone per level newly cleared per weapon: the game's own
--    drop gives the first (the hand weapon's), the rest come to you when the
--    win is recorded (the game's pickup event, so the pickup list shows them
--    and other mods' pickup rules apply). e.g. hammer at 0 and bow at 0 on
--    Bandicoot, a Super Frenzy 5 win: 10 clears, 10 hearts; bow at 3, striker
--    at 0 on Owlitzer: bow 4-5 + striker 1-5 = 7
--  * the panel shows the hearts a win would give ("x7")
--  * (0.11.1) a picked Super Frenzy level stays when the cursor leaves the
--    hunt and comes back (the game resets it to the next level to clear)
-- Safety: the hearts are given before anything is recorded (an error there:
-- nothing recorded by this, the game's one level instead); the game's own
-- record step runs as always, then each weapon is raised to its level; every
-- hook in a pcall. Blight Incursion legs never count (the game's).
-- Zero cost outside the map's Super Frenzy panel and a Super Frenzy win.
local SK = {}

SK.on = false
SK.unlock = "any_hunt"
SK.both = true
SK.info = "Super Frenzy level skip off"
SK.errors = 0

local FL, deps = nil, {}

local function NORMAL()
	return rawget(_G, "NORMAL_FRENZY_LEVELS") or 5
end

local function TOTAL()
	return rawget(_G, "TOTAL_FRENZY_LEVELS") or 10
end

local function Log(msg)
	print((FL and FL.TAG or "[Frenzy Levels]") .. " " .. msg)
end

local function Err(where, err)
	if SK.errors < 5 then
		SK.errors = SK.errors + 1
		Log("Super Frenzy level skip, error in " .. where .. ": " .. tostring(err))
	end
end

-- settings: false (off) or { unlock = "any_hunt" | "this_hunt" (or 2 / 1),
-- both_weapons = true }
function SK.Settings(c)
	if c == false or type(c) == "table" and c.enabled == false then
		return false
	end
	c = type(c) == "table" and c or {}
	local u = c.unlock
	if u == 1 or u == "1" or u == "this_hunt" or u == "hunt" then
		u = "this_hunt"
	else
		u = "any_hunt"
	end
	return { unlock = u, both_weapons = c.both_weapons ~= false }
end

----------------------------------------------------------------------------
-- the rules

local function ValidWeapon(w)
	local wt = rawget(_G, "WEAPON_TYPES")
	return type(w) == "string" and w ~= "" and (wt == nil or wt[w] ~= nil)
end

-- the weapon types this player holds: the one in hand first, then Two
-- Weapons' second one (both_weapons)
function SK.Held(player)
	local list, seen = {}, {}
	local function add(w)
		if type(w) == "string" then
			w = w:upper()
			if ValidWeapon(w) and not seen[w] then
				seen[w] = true
				list[#list + 1] = w
			end
		end
	end
	local inv = player.components ~= nil and player.components.inventory or nil
	local hand = inv ~= nil and inv.GetEquippedWeaponType ~= nil and inv:GetEquippedWeaponType() or nil
	add(hand)
	if SK.both then
		local two = player.components.twoweapons
		if two ~= nil and type(two.GetOther) == "function" then
			local ok, w = pcall(function()
				local other = two:GetOther()
				local def = type(other) == "table" and type(other.GetDef) == "function" and other:GetDef() or nil
				return type(def) == "table" and def.weapon_type or nil
			end)
			if ok then
				add(w)
			end
		end
	end
	return list
end

local function Completed(player, location_id, w)
	return tonumber(player.components.unlocktracker:GetCompletedAscensionLevel(location_id, w)) or 0
end

-- a main hunt (not a side hunt; the game's Super Frenzy is main hunts only)
function SK.IsMainHunt(location_id)
	local b = deps.biomes
	if type(b) ~= "table" then
		return true
	end
	local ok, side = pcall(function() return b.IsSublocation ~= nil and b.IsSublocation(location_id) end)
	if ok and side then
		return false
	end
	local loc = type(b.locations) == "table" and b.locations[location_id] or nil
	if loc == nil then
		return false -- (not a hunt of this game version)
	end
	return b.location_type == nil or loc.type == nil or loc.type == b.location_type.DUNGEON
end

-- mode 2: any main boss beaten at Super Frenzy 1 or higher, any weapon (the
-- game's own records)
function SK.AnyHuntCleared(player)
	local ut = player.components ~= nil and player.components.unlocktracker or nil
	if ut == nil or type(ut.GetAllAscensionData) ~= "function" then
		return false
	end
	local data = ut:GetAllAscensionData()
	if type(data) ~= "table" then
		return false
	end
	for location_id, weapons in pairs(data) do
		if type(weapons) == "table" and SK.IsMainHunt(location_id) then
			for _, level in pairs(weapons) do
				if type(level) == "number" and level > NORMAL() then
					return true
				end
			end
		end
	end
	return false
end

-- can this weapon pick (and record) any Super Frenzy level on this hunt?
-- any: AnyHuntCleared(player), when already known
function SK.Open(player, location_id, w, any)
	if SK.unlock == "any_hunt" then
		if any == nil then
			any = SK.AnyHuntCleared(player)
		end
		return any
	end
	return Completed(player, location_id, w) > NORMAL()
end

-- A win at this level: what each weapon this player holds records, and the
-- hearts (one per Super Frenzy level newly cleared per weapon).
-- Returns plan { { weapon, from, to, hearts } }, total hearts.
function SK.Plan(player, location_id, level)
	local plan, total = {}, 0
	if type(level) ~= "number" or level <= NORMAL() then
		return plan, 0
	end
	local any = SK.unlock == "any_hunt" and SK.AnyHuntCleared(player) or nil
	for _, w in ipairs(SK.Held(player)) do
		local c = Completed(player, location_id, w)
		if level > c then
			local to = SK.Open(player, location_id, w, any) and level or (c + 1) -- (not open: the game's one level)
			local hearts = to > NORMAL() and (to - math.max(c, NORMAL())) or 0
			plan[#plan + 1] = { weapon = w, from = c, to = to, hearts = hearts }
			total = total + hearts
		end
	end
	return plan, total
end

-- the heart the game's own boss drop gave this player (the hand weapon's
-- first new level): the one picked up this run (SK.SetupPlayer: the weapon
-- in hand can change between the boss's death and the win, with Two
-- Weapons), else the game's own test, before the records change
function SK.GameHeart(am, player)
	if SK.watching then
		local n = tonumber(rawget(player, "frenzylevels_sf_hearts")) or 0
		return n > 0 and 1 or 0
	end
	local ok, res = pcall(am.GetLevelCompletionResult, am, player)
	if ok and type(res) == "table" and res.heart == true and type(res.level) == "number" and res.level > NORMAL() then
		return 1
	end
	return 0
end

-- the boss's Imbued Heartstone (konjur_heart_elite_<boss>)
function SK.HeartDef(location_id)
	local C, b = deps.Consumable, deps.biomes
	if type(C) ~= "table" or type(C.FindItem) ~= "function" then
		return nil
	end
	local boss
	pcall(function() boss = b.GetLocationBoss(location_id) end)
	if type(boss) ~= "string" then
		pcall(function() boss = rawget(_G, "TheWorld"):GetCurrentBoss() end)
	end
	if type(boss) ~= "string" then
		return nil
	end
	local ok, def = pcall(C.FindItem, "konjur_heart_elite_" .. boss)
	return ok and type(def) == "table" and def or nil
end

local function WeaponName(w)
	local E = deps.Equipment
	local ok, name = pcall(function() return E.GetPrettyNameForWeaponType(w) end)
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return w:sub(1, 1) .. w:sub(2):lower()
end

-- "Hammer SF1-5" / "Bow SF4"
function SK.Describe(p)
	local a = math.max(p.from, NORMAL()) + 1 - NORMAL()
	local b = p.to - NORMAL()
	return string.format("%s SF%d%s", WeaponName(p.weapon), a, b > a and ("-" .. b) or "")
end

----------------------------------------------------------------------------
-- the win (AscensionManager:CompleteCurrentAscension, before the game's own
-- record step)

-- Before the game's record step: one player's plan, and their hearts given
-- (a local player). done: players whose second weapon this handles
-- (Progression leaves those alone). Returns the entry for SK.Record.
function SK.Prepare(am, player, location_id, level, heart_def, done)
	if player == nil or player.components == nil or player.components.unlocktracker == nil then
		return nil
	end
	local plan, hearts = SK.Plan(player, location_id, level)
	local is_local = player.IsLocal == nil or player:IsLocal()
	local given, extra = 0, 0
	if is_local and hearts > 0 then
		given = SK.GameHeart(am, player)
		extra = math.max(0, hearts - given)
		if extra > 0 then
			if heart_def == nil then
				error("the boss's Imbued Heartstone wasn't found: the game's one level instead")
			end
			-- (the game's own pickup event: inventory, the pickup list, the run's loot)
			player:PushEvent("get_loot", { item = heart_def, count = extra, frenzylevels_skip = true })
		end
	end
	rawset(player, "frenzylevels_sf_hearts", nil)
	if SK.both then
		done[player] = true
	end
	return { player = player, plan = plan, hearts = hearts, given = given, extra = extra, is_local = is_local }
end

-- After the game's record step (its one level for the hand weapon): each
-- weapon up to its level, the log and the note on screen.
function SK.Record(am, e, location_id, level, heart_def)
	local player, jumped = e.player, false
	for _, p in ipairs(e.plan) do
		if p.to > Completed(player, location_id, p.weapon) then
			am:SetHighestCompletedAscension(player, location_id, p.weapon, p.to)
		end
		jumped = jumped or p.to > p.from + 1
	end
	if #e.plan == 0 or not (jumped or e.extra > 0) then
		return false -- (the game's own case)
	end
	local parts = {}
	for i, p in ipairs(e.plan) do
		parts[i] = SK.Describe(p)
	end
	Log(string.format("Super Frenzy %d won on %s: %s cleared%s", level - NORMAL(), tostring(location_id),
		table.concat(parts, ", "), e.is_local and string.format(", %d Imbued Heartstone%s (%d from the boss, %d more)",
			e.hearts, e.hearts == 1 and "" or "s", e.given, e.extra) or ""))
	if e.is_local then
		pcall(function()
			local fe = rawget(_G, "TheFrontEnd")
			fe:ShowTextNotification(heart_def ~= nil and heart_def.icon or "images/map_ftf/frenzy_level_heart_front.tex",
				"Super Frenzy " .. (level - NORMAL()),
				table.concat(parts, ", ") .. string.format(": %d Imbued Heartstone%s", e.hearts, e.hearts == 1 and "" or "s"), 8)
		end)
	end
	return true
end

-- The win, before the game's record step: nil (not this), or the run for
-- SK.Finish.
function SK.OnComplete(am)
	rawset(am, "frenzylevels_swaps_done", nil)
	if not SK.on then
		return nil
	end
	local dungeon = rawget(_G, "TheDungeon")
	if dungeon == nil then
		return nil
	end
	local trek = dungeon.GetTrek ~= nil and dungeon:GetTrek() or nil
	if trek ~= nil and trek:IsActive() then
		return nil -- (the game doesn't count Blight Incursion legs)
	end
	local level = tonumber(am.current) or 0
	if level <= NORMAL() then
		return nil
	end
	local location_id = dungeon:GetDungeonMap():GetBiomeLocation().id
	if not SK.IsMainHunt(location_id) then
		return nil
	end
	local net = rawget(_G, "TheNet")
	local players = net ~= nil and net:GetPlayersOnRoomChange() or {}
	local run = { location_id = location_id, level = level, heart_def = SK.HeartDef(location_id), entries = {} }
	local done = {}
	for _, player in ipairs(players) do
		local ok, e = pcall(SK.Prepare, am, player, location_id, level, run.heart_def, done)
		if ok then
			run.entries[#run.entries + 1] = e
		else
			done[player] = nil
			Log("Super Frenzy clears for " .. tostring(player) .. ": the game's (" .. tostring(e) .. ")")
		end
	end
	rawset(am, "frenzylevels_swaps_done", done)
	return run
end

-- after the game's record step
function SK.Finish(am, run)
	local n = 0
	for _, e in ipairs(run.entries) do
		local ok, err = pcall(SK.Record, am, e, run.location_id, run.level, run.heart_def)
		if not ok then
			Log("Super Frenzy clears for " .. tostring(e.player) .. ": error writing them (" .. tostring(err) .. ")")
		elseif err then
			n = n + 1
		end
	end
	return n
end

-- every player (AddPlayerPostInit): the boss's Imbued Heartstone picked up
-- this run (the game's drop), for SK.GameHeart
SK.watching = false
function SK.SetupPlayer(inst)
	if not SK.on or inst == nil or inst.ListenForEvent == nil then
		return false
	end
	SK.watching = true
	inst:ListenForEvent("get_loot", function(player, data)
		if type(data) == "table" and not data.frenzylevels_skip and type(data.item) == "table"
			and type(data.item.name) == "string" and data.item.name:find("^konjur_heart_elite_") then
			rawset(player, "frenzylevels_sf_hearts", (tonumber(rawget(player, "frenzylevels_sf_hearts")) or 0) + (tonumber(data.count) or 1))
		end
	end)
	inst:ListenForEvent("start_new_run", function(player)
		rawset(player, "frenzylevels_sf_hearts", nil)
	end)
	return true
end

----------------------------------------------------------------------------
-- the map's Super Frenzy panel

function SK.PickerOpen(player, location_id, hand)
	if type(hand) ~= "string" then
		return false
	end
	hand = hand:upper()
	return ValidWeapon(hand) and SK.IsMainHunt(location_id) and SK.Open(player, location_id, hand)
end

-- after the game's SetLocation: up to Super Frenzy 5, keeping the level
-- picked before (stored) or the game's (the next one to clear)
function SK.OpenPicker(self, data, stored)
	if type(data) ~= "table" or type(data.id) ~= "string" then
		return false
	end
	if self.IsUnlocked ~= nil and not self:IsUnlocked() then
		return false
	end
	local player = self:GetOwningPlayer()
	local inv = player ~= nil and player.components ~= nil and player.components.inventory or nil
	if inv == nil or not SK.PickerOpen(player, data.id, inv:GetEquippedWeaponType()) then
		return false
	end
	local top = math.min(TOTAL(), tonumber(data.max_mapmarker_ascension) or TOTAL())
	local before = tonumber(self.max_level) or 0
	if top < before then
		top = before
	end
	local pick = self.selected_level
	if type(stored) == "number" and stored > NORMAL() and stored <= top then
		pick = stored
	end
	if top == before and pick == self.selected_level then
		return false -- (the game's panel already)
	end
	self.max_level = top
	self:SetSelectedLevel(pick)
	return true
end

-- after the game's SetSelectedLevel: the hearts a win would give ("x7"); a
-- level the hand weapon has cleared but the second weapon hasn't shows the
-- heart too
function SK.ShowHearts(self, FrenzyReward, strings)
	local level = self.selected_level
	if type(level) ~= "number" or level <= NORMAL() or self.reward_name == nil or type(self.location_data) ~= "table" then
		return false
	end
	local player = self:GetOwningPlayer()
	if player == nil then
		return false
	end
	local _, hearts = SK.Plan(player, self.location_data.id, level)
	if hearts <= 0 then
		return false
	end
	local cleared = level <= (tonumber(self.highest_personal_ascension_level) or 0)
	if cleared then
		local heart_id = type(FrenzyReward) == "table" and type(FrenzyReward.id) == "table" and FrenzyReward.id.Heartstone or nil
		if heart_id == nil or self.SetRewardType == nil then
			return false -- (the game's Corestones shown)
		end
		self:SetRewardType(heart_id)
	end
	if hearts > 1 then
		local base = strings.UI.DUNGEONSELECTIONSCREEN.SUPER_FRENZY_WIDGET.HEARTSTONE_REWARD
		self.reward_name:SetText(string.format("%s x%d", tostring(base), hearts))
	end
	if self.Layout ~= nil then
		self:Layout()
	end
	return true
end

-- The map screen resets a hunt's pick to the game's default each time the
-- cursor comes to it (DungeonSelectionScreen:_ShowLocationInfo ->
-- MapLocationMarker:Reset -> DungeonSelectionUtil.GetDefaultAscension: the
-- next level to clear), so a Super Frenzy 5 picked, then the cursor on a side
-- hunt and back, was Super Frenzy 2 again (user 03:24). Here the default is
-- the hunt's own stored pick (the game's last_selected) when it's a higher
-- Super Frenzy level the weapon in hand can pick; otherwise the game's (so a
-- win still moves the default up to the next level).
function SK.KeepPick(player, location_id, game)
	if type(game) ~= "number" or game <= NORMAL() or type(location_id) ~= "string" or player == nil or player.components == nil then
		return game
	end
	local inv = player.components.inventory
	if inv == nil or not SK.PickerOpen(player, location_id, inv:GetEquippedWeaponType()) then
		return game
	end
	local am = FL.AM()
	local stored = am ~= nil and am:GetSelectedAscension(location_id) or nil
	local b = deps.biomes
	local loc = type(b) == "table" and type(b.locations) == "table" and b.locations[location_id] or nil
	local top = math.min(TOTAL(), loc ~= nil and tonumber(loc.max_mapmarker_ascension) or TOTAL())
	if type(stored) == "number" and stored > game and stored <= top then
		return stored
	end
	return game
end

-- the game's FrenzyReward enum (local to the widget's file)
local function FindUpvalue(fn, want)
	local dbg = rawget(_G, "debug")
	if type(fn) ~= "function" or dbg == nil or dbg.getupvalue == nil then
		return nil
	end
	for i = 1, 60 do
		local name, value = dbg.getupvalue(fn, i)
		if name == nil then
			break
		end
		if name == want then
			return value
		end
	end
	return nil
end

----------------------------------------------------------------------------
-- install

-- d: { AscensionManager, SuperFrenzySelectionWidget, DungeonSelectionUtil,
-- Consumable, biomes, Equipment, STRINGS }. Returns ok, info.
function SK.Install(fl, d)
	FL = fl
	deps = d or {}
	local s = FL.settings.super_skip
	if type(s) ~= "table" then
		SK.on = false
		SK.info = "Super Frenzy level skip off"
		return false, SK.info
	end
	SK.unlock = s.unlock
	SK.both = s.both_weapons
	local AM, W = deps.AscensionManager, deps.SuperFrenzySelectionWidget
	if type(AM) ~= "table" or type(AM.CompleteCurrentAscension) ~= "function" or type(AM.SetHighestCompletedAscension) ~= "function"
		or type(AM.GetLevelCompletionResult) ~= "function" then
		SK.on = false
		SK.info = "Super Frenzy level skip off (a game update changed AscensionManager)"
		return false, SK.info
	end
	if type(W) ~= "table" or type(W.SetLocation) ~= "function" or type(W.SetSelectedLevel) ~= "function" then
		SK.on = false
		SK.info = "Super Frenzy level skip off (a game update changed the map's Super Frenzy panel)"
		return false, SK.info
	end
	if not rawget(AM, "frenzylevels_skip") then
		rawset(AM, "frenzylevels_skip", true)
		local orig = AM.CompleteCurrentAscension
		AM.CompleteCurrentAscension = function(self, ...)
			local ok, run = pcall(SK.OnComplete, self)
			if not ok then
				pcall(rawset, self, "frenzylevels_swaps_done", nil)
				Log("Super Frenzy clears: the game's (" .. tostring(run) .. ")")
				run = nil
			end
			local results = table.pack(orig(self, ...))
			if run ~= nil then
				local ok_f, err = pcall(SK.Finish, self, run)
				if not ok_f then
					Log("Super Frenzy clears: error writing them (" .. tostring(err) .. ")")
				end
			end
			return table.unpack(results, 1, results.n)
		end
	end
	if not rawget(W, "frenzylevels_skip") then
		rawset(W, "frenzylevels_skip", true)
		local orig_loc, orig_sel = W.SetLocation, W.SetSelectedLevel
		local FrenzyReward = FindUpvalue(orig_sel, "FrenzyReward")
		local strings = deps.STRINGS or rawget(_G, "STRINGS")
		W.SetLocation = function(self, data, ...)
			local stored
			if SK.on then
				pcall(function()
					stored = FL.AM():GetSelectedAscension(data.id)
				end)
			end
			local results = table.pack(orig_loc(self, data, ...))
			if SK.on then
				local ok, err = pcall(SK.OpenPicker, self, data, stored)
				if not ok then
					Err("the Super Frenzy panel", err)
				end
			end
			return table.unpack(results, 1, results.n)
		end
		W.SetSelectedLevel = function(self, ...)
			local results = table.pack(orig_sel(self, ...))
			if SK.on then
				local ok, err = pcall(SK.ShowHearts, self, FrenzyReward, strings)
				if not ok then
					Err("the Super Frenzy panel's hearts", err)
				end
			end
			return table.unpack(results, 1, results.n)
		end
	end
	-- (0.11.1) the pick kept when the cursor comes back to the hunt
	local DSU = deps.DungeonSelectionUtil
	SK.keeps_pick = false
	if type(DSU) == "table" and type(DSU.GetDefaultAscension) == "function" then
		if not rawget(DSU, "frenzylevels_skip") then
			rawset(DSU, "frenzylevels_skip", true)
			local orig_default = DSU.GetDefaultAscension
			DSU.GetDefaultAscension = function(player, location_id, ...)
				local game = orig_default(player, location_id, ...)
				if not SK.on then
					return game
				end
				local ok, level = pcall(SK.KeepPick, player, location_id, game)
				if not ok then
					Err("keeping the picked level", level)
					return game
				end
				return level
			end
		end
		SK.keeps_pick = true
	end
	SK.on = true
	SK.info = string.format("Super Frenzy level skip: %s, a win clears every level up to it for %s, one Imbued Heartstone per level per weapon",
		SK.unlock == "any_hunt" and "Super Frenzy 1 to 5 on every main hunt with any weapon once any main boss is beaten at Super Frenzy 1"
			or "Super Frenzy 1 to 5 on a hunt for a weapon that cleared Super Frenzy 1 there",
		SK.both and "both weapons you hold" or "the weapon in your hand")
		.. (SK.keeps_pick and "" or " (the pick goes back to the next level when the cursor leaves the hunt: DungeonSelectionUtil not found)")
	return true, SK.info
end

return SK
