-- Fast Load: quiet looks. Fewer repeated art calls on characters.
--
-- Every time a character's look is touched, the game redoes all of it.
--   * Equipping anything (a weapon, a potion, a tonic): every armour symbol is
--     cleared, then every armour piece is put back (inventory.lua).
--   * Copying a look (the dodge afterimages, the HUD portrait, menu puppets):
--     all of it is copied again. Furry OC Generator also clears every body
--     part first and puts each one back.
-- Each "put back" is an engine call (AnimState:OverrideSymbol). For some
-- armour art, each such call writes "Could not find anim build FROMNUM" to
-- client_log.txt. That is about a thousand lines a minute, and each line is a
-- file write.
--
-- This changes only the engine calls, not what anything does. On character
-- looks (entities with a character creator, an inventory or a dye
-- component):
--   * A call that puts back exactly what the symbol already shows is skipped.
--   * Inside one look update (an Equip, a look copy, a dye change...), a
--     symbol cleared and then given back the same art gets neither call. Any
--     clear still due at the end of the update is sent then.
-- The look ends up the same as before; only the redundant calls are gone.
-- What a symbol shows is only trusted for expire_seconds after the call that
-- set it, and only when every change to it went through these calls:
--   * a build or bank change, or any other override call, forgets that
--     character's symbols (the next call is sent as usual);
--   * nothing outside character looks is touched.

local Quiet = {}

Quiet.TAG = "[Fast Load]"
Quiet.settings = { expire_seconds = 10, report = true, sample = 12, report_seconds = 60 }

-- the game's look updates; a call into any of these is one update
Quiet.ENTRY = {
	{ "components.inventory", { "Equip", "HideSlot", "ShowSlot", "ShowAllHiddenSlots", "OnLoad", "OnNetDeserialize", "RebuildCharacterArmour" } },
	{ "components.charactercreator", { "LoadFromTable", "CloneComponent", "OnLoad", "SetBodyPart", "SetBodyParts", "SetSpecies", "Randomize", "_OnPlayerDataChanged", "_RefreshPlayerData", "SetColorGroup" } },
	{ "components.equipmentdyer", { "SetEquipmentDye", "OnLoad", "OnNetDeserialize" } },
	{ "components.ghosttrail", { "OnUpdate" } },
}
-- engine calls that change symbols in ways not tracked here: forget the character's symbols
-- (these names, and any other method whose name has one of the FORGET_LIKE words)
Quiet.FORGET = { AddOverrideBuild = true, ClearOverrideBuild = true, ClearAllOverrideSymbols = true, ClearOverrideBuilds = true }
Quiet.FORGET_LIKE = { "OverrideBuild", "ClearAllOverride", "Skin" }

local looks = setmetatable({}, { __mode = "k" })   -- AnimState -> true (a character look)
local known = setmetatable({}, { __mode = "k" })   -- AnimState -> { [symbol] = { b = build or false, s = source, t = time } }
local pending = setmetatable({}, { __mode = "k" }) -- AnimState -> { [symbol] = true } (clears held to the end of the update)
local pending_list = {}                            -- AnimStates with held clears (this update only)
local depth = 0
local entry_name = nil
local wrapped = setmetatable({}, { __mode = "k" }) -- our wrapper functions
local orig = {}
local methods = nil

Quiet.stats = { sent = 0, repeats = 0, merged = 0, clears = 0, clears_skipped = 0, forgot = 0, by = {}, samples = 0 }
local last_report, sample_world = nil, false

local function Now()
	local gt = rawget(_G, "GetTime")
	if type(gt) == "function" then
		local ok, t = pcall(gt)
		if ok and type(t) == "number" then
			return t
		end
	end
	return os.clock()
end
Quiet.Now = Now

local function Fresh(r, now)
	return r ~= nil and now - r.t <= Quiet.settings.expire_seconds
end

local function Count(what)
	local s = Quiet.stats
	s[what] = s[what] + 1
	if what == "repeats" or what == "merged" then
		local k = entry_name or "other"
		s.by[k] = (s.by[k] or 0) + 1
	end
end

local function Report(now)
	if not Quiet.settings.report then
		return
	end
	if last_report == nil then
		last_report = now
		return
	end
	if now - last_report < Quiet.settings.report_seconds then
		return
	end
	local s = Quiet.stats
	if s.sent + s.repeats + s.merged + s.clears + s.clears_skipped > 0 then
		local by = {}
		for k, v in pairs(s.by) do
			by[#by + 1] = { k, v }
		end
		table.sort(by, function(a, b) return a[2] > b[2] end)
		local parts = {}
		for i = 1, math.min(4, #by) do
			parts[#parts + 1] = by[i][1] .. " " .. by[i][2]
		end
		print(string.format("%s look art calls (last %d s): %d sent, %d repeats skipped, %d clear+put-back merged, %d clears sent, %d skipped%s",
			Quiet.TAG, math.floor(now - last_report + 0.5), s.sent, s.repeats, s.merged, s.clears, s.clears_skipped,
			#parts > 0 and ("; skipped in: " .. table.concat(parts, ", ")) or ""))
	end
	s.sent, s.repeats, s.merged, s.clears, s.clears_skipped, s.forgot, s.by = 0, 0, 0, 0, 0, 0, {}
	last_report = now
end

-- the first few art calls sent each load, named (a "Could not find anim
-- build" line right after one names the art behind it)
local function Sample(sym, build, src)
	local s = Quiet.stats
	local world = rawget(_G, "TheWorld") or false
	if world ~= sample_world then
		sample_world = world
		s.samples = 0
	end
	if not Quiet.settings.report or s.samples >= Quiet.settings.sample then
		return
	end
	s.samples = s.samples + 1
	print(string.format("%s art call %d: %s <- %s/%s (%s)", Quiet.TAG, s.samples, tostring(sym), tostring(build), tostring(src), entry_name or "other"))
end

local function Record(anim, sym, b, s, now)
	local m = known[anim]
	if m == nil then
		m = {}
		known[anim] = m
	end
	local r = m[sym]
	if r == nil then
		m[sym] = { b = b, s = s, t = now }
	else
		r.b, r.s, r.t = b, s, now
	end
end

local function Forget(anim)
	if known[anim] ~= nil then
		known[anim] = nil
		Quiet.stats.forgot = Quiet.stats.forgot + 1
	end
end

-- send the clears still held at the end of an update
local function Flush()
	if #pending_list == 0 then
		return
	end
	local list = pending_list
	pending_list = {}
	local now = Now()
	for i = 1, #list do
		local anim = list[i]
		local p = pending[anim]
		pending[anim] = nil
		if p ~= nil then
			for sym in pairs(p) do
				orig.ClearOverrideSymbol(anim, sym)
				Quiet.stats.clears = Quiet.stats.clears + 1
				Record(anim, sym, false, nil, now)
			end
		end
	end
end
Quiet.Flush = Flush

local function OverrideSymbol(anim, sym, build, src, ...)
	if not looks[anim] or type(sym) ~= "string" or type(build) ~= "string" or type(src) ~= "string" or select("#", ...) > 0 then
		if looks[anim] and type(sym) == "string" then
			local m = known[anim]
			if m ~= nil then
				m[sym] = nil
			end
			local p = pending[anim]
			if p ~= nil then
				p[sym] = nil
			end
		end
		return orig.OverrideSymbol(anim, sym, build, src, ...)
	end
	local now = Now()
	local p = pending[anim]
	local held = p ~= nil and p[sym]
	if held then
		p[sym] = nil
	end
	local m = known[anim]
	local r = m ~= nil and m[sym] or nil
	if r ~= nil and r.b == build and r.s == src and Fresh(r, now) then
		Count(held and "merged" or "repeats")
		Report(now)
		return
	end
	Sample(sym, build, src)
	orig.OverrideSymbol(anim, sym, build, src)
	Quiet.stats.sent = Quiet.stats.sent + 1
	Record(anim, sym, build, src, now)
	Report(now)
end

local function ClearOverrideSymbol(anim, sym, ...)
	if not looks[anim] or type(sym) ~= "string" or select("#", ...) > 0 then
		if looks[anim] and type(sym) == "string" then
			local m = known[anim]
			if m ~= nil then
				m[sym] = nil
			end
		end
		return orig.ClearOverrideSymbol(anim, sym, ...)
	end
	local now = Now()
	local m = known[anim]
	local r = m ~= nil and m[sym] or nil
	if r ~= nil and r.b == false and Fresh(r, now) then
		Quiet.stats.clears_skipped = Quiet.stats.clears_skipped + 1
		return
	end
	if depth > 0 then
		local p = pending[anim]
		if p == nil then
			p = {}
			pending[anim] = p
			pending_list[#pending_list + 1] = anim
		end
		p[sym] = true
		return
	end
	orig.ClearOverrideSymbol(anim, sym)
	Quiet.stats.clears = Quiet.stats.clears + 1
	Record(anim, sym, false, nil, now)
end

-- a build / bank change: kept only when it's the same build (the afterimages
-- set the player's build on every reuse; the game counts on the symbols staying)
local function SameOr(getter, setter)
	return function(anim, value, ...)
		if looks[anim] and orig[getter] ~= nil then
			local ok, cur = pcall(orig[getter], anim)
			if not ok or cur ~= value then
				Forget(anim)
			end
		elseif looks[anim] then
			Forget(anim)
		end
		return orig[setter](anim, value, ...)
	end
end

local function Forgetting(name)
	return function(anim, ...)
		if looks[anim] then
			Forget(anim)
			local p = pending[anim]
			if p ~= nil then
				-- send held clears first: they came before this call
				for sym in pairs(p) do
					orig.ClearOverrideSymbol(anim, sym)
				end
				pending[anim] = nil
			end
		end
		return orig[name](anim, ...)
	end
end

-- the table the AnimState methods live in (the userdata's metatable, or its __index)
function Quiet.MethodTable(anim)
	if anim == nil then
		return nil
	end
	local ok, mt = pcall(getmetatable, anim)
	if not ok or type(mt) ~= "table" then
		return nil
	end
	if type(rawget(mt, "OverrideSymbol")) == "function" and type(rawget(mt, "ClearOverrideSymbol")) == "function" then
		return mt
	end
	local idx = rawget(mt, "__index")
	if type(idx) == "table" and type(rawget(idx, "OverrideSymbol")) == "function" and type(rawget(idx, "ClearOverrideSymbol")) == "function" then
		return idx
	end
	return nil
end

function Quiet.HookAnimState(anim)
	if methods ~= nil then
		return true
	end
	local t = Quiet.MethodTable(anim)
	if t == nil then
		return false
	end
	orig.OverrideSymbol = rawget(t, "OverrideSymbol")
	orig.ClearOverrideSymbol = rawget(t, "ClearOverrideSymbol")
	orig.GetBuild = rawget(t, "GetBuild")
	orig.GetBank = rawget(t, "GetBank")
	orig.SetBuild = rawget(t, "SetBuild")
	orig.SetBank = rawget(t, "SetBank")
	rawset(t, "OverrideSymbol", OverrideSymbol)
	rawset(t, "ClearOverrideSymbol", ClearOverrideSymbol)
	if type(orig.SetBuild) == "function" then
		rawset(t, "SetBuild", SameOr("GetBuild", "SetBuild"))
	end
	if type(orig.SetBank) == "function" then
		rawset(t, "SetBank", SameOr("GetBank", "SetBank"))
	end
	local names = {}
	for name, fn in pairs(t) do
		if type(name) == "string" and type(fn) == "function" and orig[name] == nil then
			local forget = Quiet.FORGET[name] == true
			for _, w in ipairs(Quiet.FORGET_LIKE) do
				if name:find(w, 1, true) then
					forget = true
				end
			end
			if forget and not name:find("^Get") and not name:find("^Has") and not name:find("^Is") then
				names[#names + 1] = name
			end
		end
	end
	for _, name in ipairs(names) do
		orig[name] = rawget(t, name)
		rawset(t, name, Forgetting(name))
	end
	methods = t
	return true
end

function Quiet.IsHooked()
	return methods ~= nil
end

local told_off = false
local function Mark(self)
	local inst = type(self) == "table" and rawget(self, "inst") or nil
	local anim = type(inst) == "table" and inst.AnimState or nil
	if anim ~= nil then
		if methods == nil and not Quiet.HookAnimState(anim) then
			if not told_off then
				told_off = true
				print(Quiet.TAG .. " quiet looks off: can't reach the art calls (AnimState)")
			end
			return
		end
		looks[anim] = true
	end
end

-- one look update: clears held to the end, then sent
local function Batched(fn, name)
	local w = function(self, ...)
		Mark(self)
		local outer = entry_name
		if depth == 0 then
			entry_name = name
		end
		depth = depth + 1
		local res = table.pack(pcall(fn, self, ...))
		depth = depth - 1
		if depth == 0 then
			local ok, err = pcall(Flush)
			entry_name = outer
			if not ok then
				print(Quiet.TAG .. " quiet looks: " .. tostring(err))
			end
		end
		if not res[1] then
			error(res[2], 0)
		end
		return table.unpack(res, 2, res.n)
	end
	wrapped[w] = name
	return w
end

-- wraps the game's look updates; again later to stay outside other mods' wrappers
function Quiet.InstallClasses(req)
	req = req or require
	local n = 0
	for _, e in ipairs(Quiet.ENTRY) do
		local ok, cls = pcall(req, e[1])
		if ok and type(cls) == "table" then
			for _, name in ipairs(e[2]) do
				local fn = rawget(cls, name)
				if type(fn) == "function" and not wrapped[fn] then
					local short = e[1]:match("[^.]+$") .. ":" .. name
					rawset(cls, name, Batched(fn, short))
					n = n + 1
				end
			end
		end
	end
	return n
end

function Quiet.LoadSettings(user)
	local d = { expire_seconds = 10, report = true, sample = 12, report_seconds = 60 }
	if type(user) == "table" then
		for k, v in pairs(d) do
			if user[k] ~= nil and type(user[k]) == type(v) then
				d[k] = user[k]
			end
		end
	end
	if d.expire_seconds < 0 then
		d.expire_seconds = 0
	end
	Quiet.settings = d
	return d
end

-- for tests
function Quiet._Reset()
	depth, entry_name, pending_list = 0, nil, {}
	Quiet.stats = { sent = 0, repeats = 0, merged = 0, clears = 0, clears_skipped = 0, forgot = 0, by = {}, samples = 0 }
	last_report, sample_world = nil, false
end
function Quiet._Depth() return depth end

return Quiet
