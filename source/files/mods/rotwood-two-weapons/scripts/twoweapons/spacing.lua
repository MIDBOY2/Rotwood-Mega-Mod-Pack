-- Two Weapons: power pedestals never land on top of each other.
--
-- The game (components/powerdropmanager.lua SpawnCircleOfPowers) puts each
-- player's choice in a circle around a spot of its layout (2 players: left and
-- right of the crystal). A circle of 3 or more powers is wider (radius 2.55,
-- 3.5) and the game then pushes its centre in toward the crystal by that
-- radius. With two players and 3-4 powers each (Choosey gems, a choice filled
-- up), the two circles meet in the middle: in the run's start room (centres
-- 5 from the crystal) two 4-power circles end up 3 apart with radius 3.5, so
-- the pedestals overlap. A second choice spawned later can land on another
-- player's pedestals the same way.
--
-- Here, while the game makes a circle, the slides of its pedestals out of the
-- crystal (SGCommon.Fns.MoveToPointVel / MoveToPoint, the game's own) are held
-- a moment. When the game spawns every player's choice at once
-- (SpawnPowerItems), all its circles are placed together. If no pedestal
-- would land closer than `spacing` to another (this choice's, or one already
-- out), nothing changes. Otherwise every circle moves out from the crystal
-- a step at a time (the circles drawn a little tighter if that runs out of
-- room), keeping the game's shape and staying on walkable ground. Then the
-- game's own slides run, to those spots. It runs once when the pedestals
-- appear, not per frame.

local Spacing = {}
Spacing.TAG = "[Two Weapons]"
Spacing.spacing = 3.5     -- closest two pedestals' centres (the game's 2-power choice: 4.5 apart)
Spacing.STEP = 0.5        -- how far a circle moves out per try
Spacing.MAX_SHIFT = 6     -- the farthest out
Spacing.SCALES = { 1, 0.85, 0.7 } -- then the tightest that keeps `spacing` inside a circle
Spacing.batch = nil       -- the circles of one SpawnPowerItems
Spacing.moved = 0         -- times it moved pedestals (for the log and tests)

local function Log(msg)
	print(Spacing.TAG .. " " .. tostring(msg))
end

local function Dist(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- every pedestal already out (not the ones being placed): its spot
function Spacing.Others(mgr, placing)
	local others = {}
	local lists = type(mgr) == "table" and mgr.spawned_poweritems or nil
	if type(lists) ~= "table" then
		return others
	end
	for _, list in pairs(lists) do
		if type(list) == "table" then
			for _, item in ipairs(list) do
				if type(item) == "table" and not placing[item] and (item.IsValid == nil or item:IsValid()) then
					local spot = rawget(item, "twoweapons_spot")
					if spot == nil and item.GetPosition ~= nil then
						spot = item:GetPosition()
					end
					if spot ~= nil then
						others[#others + 1] = spot
					end
				end
			end
		end
	end
	return others
end

local function Walkable(G, x, z)
	local world = rawget(G, "TheWorld")
	local map = type(world) == "table" and world.Map or nil
	if map == nil or map.IsWalkableAtXZ == nil then
		return true
	end
	local ok, yes = pcall(map.IsWalkableAtXZ, map, x, z)
	return not ok or yes == true
end

-- The pedestals of one batch placed: circles = { { start = pos, moves = { { inst, target } } } }
function Spacing.Place(mgr, batch, G)
	G = G or _G
	local placing = {}
	local circles = {}
	for _, c in ipairs(batch.circles) do
		if #c.moves > 0 then
			local cx, cz = 0, 0
			for _, m in ipairs(c.moves) do
				placing[m.inst] = true
				cx, cz = cx + m.target.x, cz + m.target.z
			end
			cx, cz = cx / #c.moves, cz / #c.moves
			local dx, dz, dirx, dirz = 0, 0, nil, nil
			local start = c.start or batch.start
			if start ~= nil then
				dx, dz = cx - start.x, cz - start.z
			end
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 0.01 then
				dirx, dirz = dx / len, dz / len
			end
			-- the tightest circle that keeps the spacing between its own pedestals
			local radius = 0
			for _, m in ipairs(c.moves) do
				radius = math.max(radius, Dist(m.target.x, m.target.z, cx, cz))
			end
			local n = #c.moves
			local min_scale = 1
			if n >= 2 and radius > 0 then
				local r_min = Spacing.spacing / (2 * math.sin(math.pi / n))
				min_scale = math.min(1, r_min / radius)
			end
			circles[#circles + 1] = { c = c, cx = cx, cz = cz, dirx = dirx, dirz = dirz, min_scale = min_scale }
		end
	end
	if #circles == 0 then
		return false
	end
	local others = Spacing.Others(mgr, placing)

	-- the spots for a try (s: the circles' size, k: how far out)
	local function Spots(s, k)
		local spots = {}
		for ci, cc in ipairs(circles) do
			local ox, oz = cc.cx, cc.cz
			if cc.dirx ~= nil then
				ox, oz = ox + cc.dirx * k, oz + cc.dirz * k
			end
			for _, m in ipairs(cc.c.moves) do
				spots[#spots + 1] = { ci = ci, m = m, x = ox + (m.target.x - cc.cx) * s, z = oz + (m.target.z - cc.cz) * s }
			end
		end
		return spots
	end
	-- the closest any two pedestals come (and whether every spot is walkable)
	local function Closest(spots)
		local best = math.huge
		for i = 1, #spots do
			local a = spots[i]
			for j = i + 1, #spots do
				best = math.min(best, Dist(a.x, a.z, spots[j].x, spots[j].z))
			end
			for _, o in ipairs(others) do
				best = math.min(best, Dist(a.x, a.z, o.x, o.z))
			end
		end
		return best
	end
	local function AllWalkable(spots)
		for _, sp in ipairs(spots) do
			if not Walkable(G, sp.x, sp.z) then
				return false
			end
		end
		return true
	end

	local chosen, chosen_s, chosen_k
	local game = Spots(1, 0)
	if Closest(game) >= Spacing.spacing then
		chosen, chosen_s, chosen_k = game, 1, 0
	else
		local scales = {}
		for _, s in ipairs(Spacing.SCALES) do
			scales[#scales + 1] = s
		end
		local tightest = 1
		for _, cc in ipairs(circles) do
			tightest = math.min(tightest, cc.min_scale)
		end
		scales[#scales + 1] = tightest
		local fallback, fallback_d, fallback_s, fallback_k = nil, -1, nil, nil
		for _, s in ipairs(scales) do
			if s >= tightest - 1e-6 then
				local k = 0
				while k <= Spacing.MAX_SHIFT + 1e-6 do
					local spots = Spots(s, k)
					if AllWalkable(spots) then
						local d = Closest(spots)
						if d >= Spacing.spacing then
							chosen, chosen_s, chosen_k = spots, s, k
							break
						elseif d > fallback_d then
							fallback, fallback_d, fallback_s, fallback_k = spots, d, s, k
						end
					end
					k = k + Spacing.STEP
				end
			end
			if chosen ~= nil then
				break
			end
		end
		if chosen == nil and fallback ~= nil and fallback_d > Closest(game) then
			chosen, chosen_s, chosen_k = fallback, fallback_s, fallback_k
		end
		if chosen == nil then
			chosen, chosen_s, chosen_k = game, 1, 0
		end
	end

	local Vector3 = rawget(G, "Vector3")
	local changed = chosen_s ~= 1 or chosen_k ~= 0
	for _, sp in ipairs(chosen) do
		local m = sp.m
		if changed then
			if Vector3 ~= nil then
				m.final = Vector3(sp.x, m.target.y or 0, sp.z)
			else
				m.final = { x = sp.x, y = m.target.y or 0, z = sp.z }
			end
		end
		pcall(rawset, m.inst, "twoweapons_spot", m.final or m.target)
	end
	if changed then
		Spacing.moved = Spacing.moved + 1
		Log(string.format("power pedestals moved apart: %d out %.1f, circles at %d%% (they'd have been %.1f apart)",
			#chosen, chosen_k, math.floor(chosen_s * 100 + 0.5), Closest(game)))
	end
	return changed
end

-- the held slides, run (the game's own functions, to the placed spots)
function Spacing.Run(batch)
	for _, c in ipairs(batch.circles) do
		for _, m in ipairs(c.moves) do
			m.fn(m.inst, m.final or m.target, table.unpack(m.args, 1, m.args.n))
		end
	end
end

function Spacing.Flush(mgr, batch, G)
	local ok, err = pcall(Spacing.Place, mgr, batch, G)
	if not ok then
		Log("power pedestals: " .. tostring(err) .. " (the game's spots)")
		for _, c in ipairs(batch.circles) do
			for _, m in ipairs(c.moves) do
				m.final = nil
			end
		end
	end
	Spacing.Run(batch)
end

function Spacing.Install(PDM, SGCommon, G)
	G = G or _G
	if type(PDM) ~= "table" or type(PDM.SpawnCircleOfPowers) ~= "function" or type(PDM.SpawnPowerItems) ~= "function" then
		return false, "a game update changed PowerDropManager:SpawnCircleOfPowers / SpawnPowerItems"
	end
	local Fns = type(SGCommon) == "table" and SGCommon.Fns or nil
	if type(Fns) ~= "table" or type(Fns.MoveToPointVel) ~= "function" or type(Fns.MoveToPoint) ~= "function" then
		return false, "a game update changed SGCommon.Fns.MoveToPointVel / MoveToPoint"
	end
	if rawget(PDM, "twoweapons_spacing") then
		return true, "already on"
	end
	rawset(PDM, "twoweapons_spacing", true)

	local orig_circle = PDM.SpawnCircleOfPowers
	PDM.SpawnCircleOfPowers = function(self, powers, player_id, player_index, player_count, start_pos, ...)
		local circle = { start = start_pos, moves = {} }
		local mvv, mv = Fns.MoveToPointVel, Fns.MoveToPoint
		local function Hold(fn)
			return function(inst, target, ...)
				if type(target) ~= "table" or target.x == nil or target.z == nil then
					return fn(inst, target, ...)
				end
				circle.moves[#circle.moves + 1] = { inst = inst, target = target, fn = fn, args = table.pack(...) }
			end
		end
		Fns.MoveToPointVel, Fns.MoveToPoint = Hold(mvv), Hold(mv)
		local r = table.pack(pcall(orig_circle, self, powers, player_id, player_index, player_count, start_pos, ...))
		Fns.MoveToPointVel, Fns.MoveToPoint = mvv, mv
		if Spacing.batch ~= nil and r[1] then
			table.insert(Spacing.batch.circles, circle)
		else
			Spacing.Flush(self, { circles = { circle }, start = start_pos }, G)
		end
		if not r[1] then
			error(r[2], 0)
		end
		return table.unpack(r, 2, r.n)
	end

	local orig_items = PDM.SpawnPowerItems
	PDM.SpawnPowerItems = function(self, position, ...)
		if Spacing.batch ~= nil then
			return orig_items(self, position, ...)
		end
		local batch = { circles = {}, start = position }
		Spacing.batch = batch
		local r = table.pack(pcall(orig_items, self, position, ...))
		Spacing.batch = nil
		Spacing.Flush(self, batch, G)
		if not r[1] then
			error(r[2], 0)
		end
		return table.unpack(r, 2, r.n)
	end
	return true, string.format("power pedestals kept %.1f apart", Spacing.spacing)
end

return Spacing
