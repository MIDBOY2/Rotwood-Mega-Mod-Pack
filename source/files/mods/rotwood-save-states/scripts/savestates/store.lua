-- Save States: the slots and the two history lists, on disk.
--
-- Files (in the game's saves folder, savestates/):
--   s_<id>      one state each
--   index       slots 1-10, the manual history (ids, oldest first), pins,
--               a short line for each, and the gear to put back after a run
--   auto_index  slot 0 and the auto history (and their lines)
--   pending     a load in progress (read once after the reload, then erased)
--
-- An id lives in one list. "Copy to slot" makes an auto entry a manual one.
-- Pruning deletes the oldest entry that no slot points to and isn't pinned.
-- Writes go through io: { Write(name, table, cb(ok)), Read(name, cb(table|nil)), Erase(name, cb(ok)) }
local D = require "savestates.data"

local Store = {}
Store.__index = Store

local SLOTS = 10
Store.SLOTS = SLOTS

function Store.New(io, settings, now)
	local self = setmetatable({}, Store)
	self.io = io
	self.settings = settings or {}
	self.now = now or os.time
	self.slots = {}   -- 0..10 -> id
	self.manual = {}  -- ids, oldest first
	self.auto = {}
	self.pins = {}    -- id -> true
	self.meta = {}    -- id -> { id, kind, time, summary, note, slot }
	self.loadouts = {} -- character slot (string) -> what to put back after the run
	self.next_id = 1
	self.loaded = false
	self.cache = {}   -- id -> state (the last few)
	self.cache_order = {}
	return self
end

local function IsId(v)
	return type(v) == "number" and v >= 1 and v == math.floor(v)
end

local function Name(id)
	return string.format("s_%06d", id)
end
Store.Name = Name

local function CleanList(list, meta, into)
	local seen = {}
	for _, id in ipairs(type(list) == "table" and list or {}) do
		if IsId(id) and not seen[id] and type(meta[id]) == "table" then
			seen[id] = true
			into[#into + 1] = id
		end
	end
end

-- read both indexes; a missing or broken one starts empty (logged by the caller)
function Store:Load(cb)
	local pending = 2
	local problems = {}
	local function done()
		pending = pending - 1
		if pending > 0 then
			return
		end
		self.loaded = true
		if cb then
			cb(#problems == 0, problems)
		end
	end
	self.io.Read("index", function(t)
		if type(t) == "table" then
			local meta = type(t.meta) == "table" and t.meta or {}
			for id, m in pairs(meta) do
				if IsId(id) and type(m) == "table" then
					self.meta[id] = m
				end
			end
			CleanList(t.manual, self.meta, self.manual)
			for s = 1, SLOTS do
				local id = type(t.slots) == "table" and t.slots[s] or nil
				if IsId(id) and self.meta[id] then
					self.slots[s] = id
				end
			end
			for id, v in pairs(type(t.pins) == "table" and t.pins or {}) do
				if IsId(id) and v == true then
					self.pins[id] = true
				end
			end
			if type(t.loadouts) == "table" then
				for k, v in pairs(t.loadouts) do
					if type(v) == "table" then
						self.loadouts[tostring(k)] = v
					end
				end
			end
			if IsId(t.next_id) then
				self.next_id = math.max(self.next_id, t.next_id)
			end
		elseif t ~= nil then
			problems[#problems + 1] = "index"
		end
		self.io.Read("auto_index", function(a)
			if type(a) == "table" then
				for id, m in pairs(type(a.meta) == "table" and a.meta or {}) do
					if IsId(id) and type(m) == "table" then
						self.meta[id] = m
					end
				end
				CleanList(a.auto, self.meta, self.auto)
				if IsId(a.slot0) and self.meta[a.slot0] then
					self.slots[0] = a.slot0
				end
				if IsId(a.next_id) then
					self.next_id = math.max(self.next_id, a.next_id)
				end
			elseif a ~= nil then
				problems[#problems + 1] = "auto_index"
			end
			-- ids above every one known
			for id in pairs(self.meta) do
				if id >= self.next_id then
					self.next_id = id + 1
				end
			end
			done()
		end)
		done()
	end)
end

function Store:_MetaFor(list)
	local m = {}
	for _, id in ipairs(list) do
		m[id] = self.meta[id]
	end
	return m
end

function Store:WriteIndex(cb)
	local slots = {}
	for s = 1, SLOTS do
		slots[s] = self.slots[s]
	end
	local meta = self:_MetaFor(self.manual)
	-- an auto entry a slot points to keeps its line here too
	for s = 1, SLOTS do
		local id = self.slots[s]
		if id and meta[id] == nil then
			meta[id] = self.meta[id]
		end
	end
	local pins = {}
	for id in pairs(self.pins) do
		pins[id] = true
	end
	self.io.Write("index", { v = 1, next_id = self.next_id, slots = slots, manual = D.deepcopy(self.manual), pins = pins, meta = D.deepcopy(meta), loadouts = D.deepcopy(self.loadouts) }, cb or function() end)
end

function Store:WriteAutoIndex(cb)
	self.io.Write("auto_index", { v = 1, next_id = self.next_id, slot0 = self.slots[0], auto = D.deepcopy(self.auto), meta = D.deepcopy(self:_MetaFor(self.auto)) }, cb or function() end)
end

function Store:_Cache(id, state)
	if self.cache[id] == nil then
		self.cache_order[#self.cache_order + 1] = id
	end
	self.cache[id] = state
	while #self.cache_order > 4 do
		local old = table.remove(self.cache_order, 1)
		self.cache[old] = nil
	end
end

local function Remove(list, id)
	for i = #list, 1, -1 do
		if list[i] == id then
			table.remove(list, i)
			return true
		end
	end
	return false
end

function Store:_Referenced(id)
	if self.pins[id] then
		return true
	end
	for s = 0, SLOTS do
		if self.slots[s] == id then
			return true
		end
	end
	return false
end

-- the oldest unreferenced entries past the list's size: returns the ids dropped
function Store:_Prune(list, max)
	local dropped = {}
	local i = 1
	while #list > max and i <= #list do
		local id = list[i]
		if self:_Referenced(id) then
			i = i + 1
		else
			table.remove(list, i)
			dropped[#dropped + 1] = id
		end
	end
	for _, id in ipairs(dropped) do
		self.meta[id] = nil
		self.cache[id] = nil
		self.io.Erase(Name(id), function() end)
	end
	return dropped
end

-- kind: "manual" (slot 1-10), "auto" (slot 0) or "undo" (the auto list, no slot)
-- cb(ok, id)
function Store:Add(kind, state, slot, summary, cb)
	cb = cb or function() end
	local id = self.next_id
	self.next_id = id + 1
	state.id = id
	local run = type(state.run) == "table" and state.run or {}
	local m = { id = id, kind = kind, time = self.now(), summary = summary, slot = slot,
		location = type(run.location_id) == "string" and run.location_id or nil } -- (the Codex's Saved Hunts list)
	self.io.Write(Name(id), state, function(ok)
		if not ok then
			cb(false, id)
			return
		end
		self.meta[id] = m
		self:_Cache(id, state)
		if kind == "manual" then
			self.manual[#self.manual + 1] = id
			if slot ~= nil and slot >= 1 and slot <= SLOTS then
				self.slots[slot] = id
			end
			self:_Prune(self.manual, self.settings.manual_history or 1000)
			self:WriteIndex(function(ok2) cb(ok2, id) end)
		else
			self.auto[#self.auto + 1] = id
			if kind == "auto" then
				self.slots[0] = id
			end
			self:_Prune(self.auto, self.settings.auto_history or 100)
			self:WriteAutoIndex(function(ok2) cb(ok2, id) end)
		end
	end)
end

-- cb(state|nil)
function Store:Get(id, cb)
	if not IsId(id) or self.meta[id] == nil then
		cb(nil)
		return
	end
	if self.cache[id] ~= nil then
		cb(self.cache[id])
		return
	end
	self.io.Read(Name(id), function(t)
		if type(t) == "table" then
			self:_Cache(id, t)
		end
		cb(type(t) == "table" and t or nil)
	end)
end

function Store:SlotId(slot)
	return self.slots[slot]
end

function Store:InList(list, id)
	for _, v in ipairs(list) do
		if v == id then
			return true
		end
	end
	return false
end

-- point slot 1-10 at an entry (an auto one becomes a manual one)
function Store:CopyToSlot(id, slot, cb)
	cb = cb or function() end
	if not IsId(id) or self.meta[id] == nil or type(slot) ~= "number" or slot < 1 or slot > SLOTS then
		cb(false)
		return
	end
	if Remove(self.auto, id) then
		self.manual[#self.manual + 1] = id
		self.meta[id].kind = "manual"
		self:WriteAutoIndex()
	end
	self.slots[slot] = id
	self.meta[id].slot = slot
	self:WriteIndex(function(ok) cb(ok) end)
end

function Store:SetPin(id, on, cb)
	if not IsId(id) or self.meta[id] == nil then
		if cb then cb(false) end
		return
	end
	self.pins[id] = on and true or nil
	self:WriteIndex(cb)
end

function Store:SetNote(id, note, cb)
	if not IsId(id) or self.meta[id] == nil then
		if cb then cb(false) end
		return
	end
	self.meta[id].note = type(note) == "string" and note:sub(1, 120) or nil
	if self:InList(self.auto, id) then
		self:WriteAutoIndex(cb)
	else
		self:WriteIndex(cb)
	end
end

function Store:Delete(id, cb)
	cb = cb or function() end
	if not IsId(id) or self.meta[id] == nil then
		cb(false)
		return
	end
	local in_auto = Remove(self.auto, id)
	Remove(self.manual, id)
	for s = 0, SLOTS do
		if self.slots[s] == id then
			self.slots[s] = nil
		end
	end
	self.pins[id] = nil
	self.meta[id] = nil
	self.cache[id] = nil
	self.io.Erase(Name(id), function() end)
	if in_auto then
		self:WriteAutoIndex()
	end
	self:WriteIndex(function(ok) cb(ok) end)
end

-- newest first, for the menu
function Store:List(which)
	local list = which == "auto" and self.auto or self.manual
	local out = {}
	for i = #list, 1, -1 do
		out[#out + 1] = self.meta[list[i]]
	end
	return out
end

-- what to put back after a Replicate run, by character slot
function Store:SetLoadout(char_slot, rec, cb)
	self.loadouts[tostring(char_slot)] = rec
	self:WriteIndex(cb)
end

function Store:GetLoadout(char_slot)
	return self.loadouts[tostring(char_slot)]
end

function Store:ClearLoadout(char_slot, cb)
	self.loadouts[tostring(char_slot)] = nil
	self:WriteIndex(cb)
end

return Store
