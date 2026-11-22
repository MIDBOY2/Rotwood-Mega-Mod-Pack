-- Frenzy Levels: Corestone drops past the game's limit (0.9.2).
--
-- The game's Corestone drop (a boss's end drop, a Corestone room: the soul
-- drops, components/souldrop.lua) sends each hunter's count over the network
-- in 3 bits (DROP_MAXIMUM 5: up to 7 fits). The game itself goes up to 6 (a
-- Super Frenzy boss). Frenzy Levels' bigger drops (the Super Frenzy loot
-- multiplier, the Super Frenzy side hunt boss: 9 to 15) would go past that
-- (rewardutil.lua: "will cause a hard crash when trying to serialize").
-- Here, when a soul drop is set up on the host (konjursouls.ConfigureKonjurSoul)
-- with a hunter's count above 7: that drop keeps 7, and the rest comes as one
-- more of the game's Corestone drops (soul_drop_lesser, the Corestone room
-- reward) right beside it, for those hunters only (7 at most in each; more
-- drops if needed). Nothing changes for 7 or fewer (all of the game's own).
-- Without that drop loaded here (it always is where the room's loot spots
-- are), the rest is left out and logged rather than risking the crash.
-- 0.11.2 (user 2026-11-14 03:41: "finishing a side hunt on SF5 gives all
-- these corestones, but it finishes the run after taking a single reward,
-- because it ends the run on the next RB"): the game ends the hunt when the
-- boss's drop is taken (RoomClear: the drop's consumed callback ->
-- "dungeoncleared" -> RunManager:Victory -> the "Complete Hunt" button, on
-- RB: Controls.Digital.NON_MODAL_CLICK), so the extra drops beside it were
-- still on the floor when the button came up. Now a drop with extra drops
-- holds its callback (SoulDrop:OnFullyConsumed) until those are taken too,
-- then the game's end goes on as always. Safety: at most HOLD_SECONDS (then
-- the game's end anyway, the extras still there to take); an error: the
-- game's at once.
local SC = {}

SC.MAX = 7
SC.EXTRA = "soul_drop_lesser"
SC.SOUL_PREFABS = { "soul_drop_konjur_soul_lesser", "soul_drop_konjur_soul_lesser_x2", "soul_drop_konjur_soul_lesser_many" }
SC.spawning = 0     -- inside our own extra drop's spawn (its counts are set by us)
SC.HOLD_SECONDS = 30 -- the longest the hunt's end waits for the extra drops
SC.installed = false
SC.deps = {}

local function Log(msg)
	print("[Frenzy Levels] " .. msg)
end

local function IsHost()
	local net = rawget(_G, "TheNet")
	local ok, host = pcall(function() return net:IsHost() end)
	return ok and host == true
end

local function PrefabOK(name)
	local exists = rawget(_G, "PrefabExists")
	if type(exists) ~= "function" then
		return false
	end
	local ok, yes = pcall(exists, name)
	return ok and yes == true
end
SC.PrefabOK = PrefabOK

function SC.PrefabFor(n)
	return SC.SOUL_PREFABS[math.max(1, math.min(n, #SC.SOUL_PREFABS))]
end

-- After the game set up a soul drop: counts above MAX capped, the rest per
-- hunter (or nil).
function SC.Cap(inst)
	local sd = inst.components ~= nil and inst.components.souldrop or nil
	if sd == nil or type(sd.child_drops) ~= "table" then
		return nil
	end
	local extra, any = {}, false
	for player, d in pairs(sd.child_drops) do
		if type(d) == "table" and type(d.count) == "number" and d.count > SC.MAX then
			extra[player] = d.count - SC.MAX
			d.count = SC.MAX
			any = true
		end
	end
	return any and extra or nil
end

-- The rest, as the game's Corestone drops beside the first one.
function SC.SpawnExtra(origin, extra)
	if not PrefabOK(SC.EXTRA) then
		local total = 0
		for _, n in pairs(extra) do
			total = total + n
		end
		Log(string.format("a Corestone drop past the game's limit: %d Corestones left out (no %s here)", total, SC.EXTRA))
		return 0
	end
	local okp, pos = pcall(function() return origin:GetPosition() end)
	local spawn = rawget(_G, "SpawnPrefab")
	local made, step = 0, 0
	local list = {}
	local function Done()
		if #list > 0 then
			SC.Track(origin, list)
		end
		return made
	end
	while next(extra) ~= nil do
		step = step + 1
		local drops, left = {}, {}
		for player, n in pairs(extra) do
			local c = math.min(n, SC.MAX)
			drops[player] = { prefab = SC.PrefabFor(c), count = c }
			if n > c then
				left[player] = n - c
			end
		end
		SC.spawning = SC.spawning + 1
		local ok, drop = pcall(spawn, SC.EXTRA, rawget(_G, "TheWorld"))
		SC.spawning = SC.spawning - 1
		if not ok or drop == nil then
			Log("a Corestone drop past the game's limit: the extra drop failed (" .. tostring(drop) .. ")")
			return Done()
		end
		list[#list + 1] = drop
		if okp and pos ~= nil and drop.Transform ~= nil then
			drop.Transform:SetPosition(pos.x + 2.5 * step, pos.y or 0, pos.z)
		end
		local sd = drop.components ~= nil and drop.components.souldrop or nil
		if sd ~= nil then
			sd:SetChildDrops(drops)
			local T = rawget(_G, "TUNING")
			local delay = T ~= nil and T.POWERS ~= nil and T.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES or 0
			pcall(sd.PrepareToShowGem, sd, { appear_delay_ticks = delay })
		end
		made = made + 1
		extra = left
	end
	Log(string.format("a Corestone drop past the game's limit: %d more drop%s beside it", made, made == 1 and "" or "s"))
	return Done()
end

----------------------------------------------------------------------------
-- 0.11.2: the hunt's end waits for the extra drops

-- this drop's extra drops (host)
function SC.Track(origin, drops)
	rawset(origin, "frenzylevels_extras", drops)
	for _, d in ipairs(drops) do
		rawset(d, "frenzylevels_parent", origin)
	end
end

-- extra drops of this drop not taken yet
function SC.Pending(origin)
	local list = rawget(origin, "frenzylevels_extras")
	if type(list) ~= "table" then
		return 0
	end
	local n = 0
	for _, d in ipairs(list) do
		local valid = true
		if d.IsValid ~= nil then
			local okv, v = pcall(d.IsValid, d)
			valid = okv and v == true
		end
		if valid and not rawget(d, "frenzylevels_taken") then
			n = n + 1
		end
	end
	return n
end

-- the held callback, now (once)
function SC.Release(origin, why)
	local cb = rawget(origin, "frenzylevels_held_cb")
	if cb == nil then
		return false
	end
	rawset(origin, "frenzylevels_held_cb", nil)
	Log("the boss's drop: " .. why .. ", the hunt can end")
	cb()
	return true
end

-- SoulDrop:OnFullyConsumed, wrapped (orig: the game's)
function SC.OnFullyConsumed(self, orig, ...)
	local inst = self.inst
	local parent = rawget(inst, "frenzylevels_parent")
	if parent ~= nil then
		rawset(inst, "frenzylevels_taken", true)
	end
	local cb = self.consumed_cb
	if cb ~= nil and SC.Pending(inst) > 0 then
		-- the drop with extras taken first: its callback (the hunt's end) waits
		self.consumed_cb = nil
		rawset(inst, "frenzylevels_held_cb", cb)
		local n = SC.Pending(inst)
		Log(string.format("the boss's drop taken: the hunt ends once the %d Corestone drop%s beside it %s taken too (at most %d seconds)",
			n, n == 1 and "" or "s", n == 1 and "is" or "are", SC.HOLD_SECONDS))
		local results = table.pack(orig(self, ...))
		local world = rawget(_G, "TheWorld")
		local okt = world ~= nil and world.DoTaskInTime ~= nil and pcall(world.DoTaskInTime, world, SC.HOLD_SECONDS, function()
			SC.Release(inst, "time's up")
		end)
		if not okt then
			SC.Release(inst, "no timer")
		end
		return table.unpack(results, 1, results.n)
	end
	local results = table.pack(orig(self, ...))
	if parent ~= nil and rawget(parent, "frenzylevels_held_cb") ~= nil and SC.Pending(parent) == 0 then
		SC.Release(parent, "every Corestone drop taken")
	end
	return table.unpack(results, 1, results.n)
end

function SC.InstallHold(SoulDrop)
	if type(SoulDrop) ~= "table" or type(SoulDrop.OnFullyConsumed) ~= "function" then
		return false
	end
	if not rawget(SoulDrop, "frenzylevels_hold") then
		rawset(SoulDrop, "frenzylevels_hold", true)
		local orig = SoulDrop.OnFullyConsumed
		SoulDrop.OnFullyConsumed = function(self, ...)
			local called = false
			local function game(...)
				called = true
				return orig(...)
			end
			local ok, results = pcall(function(...)
				return table.pack(SC.OnFullyConsumed(self, game, ...))
			end, ...)
			if ok then
				return table.unpack(results, 1, results.n)
			end
			Log("error holding the hunt's end for the Corestone drops: " .. tostring(results))
			-- the game's, at once: its own step if it didn't run, and a held callback goes
			local inst = self.inst
			if inst ~= nil and rawget(inst, "frenzylevels_held_cb") ~= nil then
				pcall(SC.Release, inst, "an error")
			end
			if not called then
				return orig(self, ...)
			end
			return nil
		end
	end
	return true
end

function SC.Install(konjursouls, SoulDrop)
	if type(konjursouls) ~= "table" or type(konjursouls.ConfigureKonjurSoul) ~= "function" then
		return false, "Corestone drops: the game's (konjursouls not found)"
	end
	local held = SC.InstallHold(SoulDrop)
	if not rawget(konjursouls, "frenzylevels_soulcap") then
		rawset(konjursouls, "frenzylevels_soulcap", true)
		local orig = konjursouls.ConfigureKonjurSoul
		konjursouls.ConfigureKonjurSoul = function(inst, opts, ...)
			local r = table.pack(orig(inst, opts, ...))
			if SC.spawning == 0 and type(inst) == "table" and IsHost() then
				local ok, extra = pcall(SC.Cap, inst)
				if not ok then
					Log("error in the Corestone drop limit: " .. tostring(extra))
				elseif extra ~= nil and inst.DoTaskInTime ~= nil then
					-- (next tick: the drop has its position by then)
					inst:DoTaskInTime(0, function()
						local okx, err = pcall(SC.SpawnExtra, inst, extra)
						if not okx then
							Log("error in the Corestone drop limit: " .. tostring(err))
						end
					end)
				end
			end
			return table.unpack(r, 1, r.n)
		end
	end
	SC.installed = true
	return true, "Corestone drops past the game's limit (7 each): the rest in a second drop beside it"
		.. (held and ", the hunt's end waits for it" or " (the hunt's end doesn't wait for it: SoulDrop not found)")
end

return SC
