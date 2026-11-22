-- Save States: console commands, the menu's jobs without the game's debug UI
-- (the game's console). Nothing runs until one is typed: they're only defined.
--   ss_help()               this list
--   ss_list()               the newest 15 saves of both histories, with their numbers
--   ss_list(40, "auto")     40 of the auto history ("manual", "auto" or "all")
--   ss_slots()              what's in slots 1-10 and in slot 0 (the latest auto save)
--   ss_load(123)            load save #123 (Rebuild); ss_load(123, "replicate")
--   ss_undo()               back to before the last load (its "before loading" save)
--   ss_slot(123, 4)         put save #123 in slot 4 (Ctrl+Shift+4 then loads it)
--   ss_pin(123) / ss_unpin(123)   a pinned save is never pruned
--   ss_note(123, "text")    a note on a save
--   ss_delete(123)          delete a save (not a pinned one: unpin it first)
local SS = require "savestates.main"

local C = {}

C.L = nil -- savestates.loader (its store)
C.DEFAULT_LIST = 15

local function Say(lines)
	for _, l in ipairs(lines) do
		print(SS.TAG .. " " .. l)
	end
	return lines
end

local function When(t)
	if type(t) ~= "number" then
		return "?"
	end
	return os.date("%m-%d %H:%M", t)
end

function C.Line(m)
	local store = C.L.store
	local where = m.kind == "manual" and "manual" or (m.kind == "undo" and "undo" or "auto")
	local slots = {}
	for s = 0, 10 do
		if store.slots[s] == m.id then
			slots[#slots + 1] = s == 0 and "slot 0" or ("slot " .. s)
		end
	end
	return string.format("#%d  %s  %-6s %s%s%s%s", m.id, When(m.time), where, tostring(m.summary or ""),
		#slots > 0 and ("  [" .. table.concat(slots, ", ") .. "]") or "", store.pins[m.id] and "  [pinned]" or "",
		m.note and ("  - " .. m.note) or "")
end

local function Ready(cmd)
	local L = C.L
	if L == nil or L.store == nil then
		Say({ cmd .. ": Save States isn't set up" })
		return nil
	end
	if not L.store.loaded then
		Say({ cmd .. ": the save list is still loading" })
		return nil
	end
	return L.store
end

local function Id(cmd, id, store)
	local n = tonumber(id)
	if n == nil or store.meta[math.floor(n)] == nil then
		Say({ cmd .. ": no save #" .. tostring(id) .. " (ss_list() shows the numbers)" })
		return nil
	end
	return math.floor(n)
end

function C.Help()
	return Say({
		"console commands (the menu's jobs):",
		"  ss_list()              the newest 15 saves, with their numbers; ss_list(40, \"auto\"): 40 of the auto history (\"manual\", \"auto\", \"all\")",
		"  ss_slots()             what's in slots 1-10 and slot 0",
		"  ss_load(123)           load save #123 (Rebuild); ss_load(123, \"replicate\")",
		"  ss_undo()              back to before the last load",
		"  ss_slot(123, 4)        put save #123 in slot 4",
		"  ss_pin(123), ss_unpin(123), ss_note(123, \"text\"), ss_delete(123)",
	})
end

function C.List(n, which)
	local store = Ready("ss_list")
	if store == nil then
		return nil
	end
	n = math.max(1, math.min(500, math.floor(tonumber(n) or C.DEFAULT_LIST)))
	which = (which == "manual" or which == "auto") and which or "all"
	local items = {}
	if which ~= "auto" then
		for _, m in ipairs(store:List("manual")) do items[#items + 1] = m end
	end
	if which ~= "manual" then
		for _, m in ipairs(store:List("auto")) do items[#items + 1] = m end
	end
	table.sort(items, function(a, b) return a.id > b.id end)
	local lines = { string.format("saves (%s, newest first, %d of %d):", which, math.min(n, #items), #items) }
	for i = 1, math.min(n, #items) do
		lines[#lines + 1] = "  " .. C.Line(items[i])
	end
	if #items == 0 then
		lines[#lines + 1] = "  none yet"
	end
	return Say(lines)
end

function C.Slots()
	local store = Ready("ss_slots")
	if store == nil then
		return nil
	end
	local lines = { "slots:" }
	for s = 1, 10 do
		local id = store.slots[s]
		lines[#lines + 1] = string.format("  %2d: %s", s, id and store.meta[id] and C.Line(store.meta[id]) or "empty")
	end
	local id0 = store.slots[0]
	lines[#lines + 1] = "   0: " .. (id0 and store.meta[id0] and C.Line(store.meta[id0]) or "empty") .. " (the latest auto save, Ctrl+L)"
	return Say(lines)
end

function C.Load(id, mode)
	local store = Ready("ss_load")
	if store == nil then
		return nil
	end
	local n = Id("ss_load", id, store)
	if n == nil then
		return nil
	end
	mode = mode == "replicate" and "replicate" or "rebuild"
	Say({ string.format("ss_load: #%d (%s)", n, mode == "replicate" and "Replicate" or "Rebuild") })
	C.L.LoadId(n, mode, "save #" .. n)
	return n
end

-- the newest "before loading" save
function C.Undo(mode)
	local store = Ready("ss_undo")
	if store == nil then
		return nil
	end
	local best = nil
	for _, m in ipairs(store:List("auto")) do
		if m.kind == "undo" and (best == nil or m.id > best.id) then
			best = m
		end
	end
	if best == nil then
		Say({ "ss_undo: no load to undo yet" })
		return nil
	end
	mode = mode == "replicate" and "replicate" or "rebuild"
	Say({ "ss_undo: " .. C.Line(best) })
	C.L.LoadId(best.id, mode, "before the last load")
	return best.id
end

function C.Slot(id, slot)
	local store = Ready("ss_slot")
	if store == nil then
		return nil
	end
	local n = Id("ss_slot", id, store)
	local s = tonumber(slot)
	if n == nil then
		return nil
	end
	if s == nil or s ~= math.floor(s) or s < 1 or s > 10 then
		Say({ "ss_slot: a slot is 1 to 10" })
		return nil
	end
	store:CopyToSlot(n, s, function(ok)
		Say({ ok and string.format("ss_slot: #%d is in slot %d (Ctrl+Shift+%d loads it)", n, s, s % 10) or "ss_slot: couldn't write the save list" })
	end)
	return n
end

function C.Pin(id, on)
	local store = Ready(on and "ss_pin" or "ss_unpin")
	if store == nil then
		return nil
	end
	local n = Id(on and "ss_pin" or "ss_unpin", id, store)
	if n == nil then
		return nil
	end
	store:SetPin(n, on, function(ok)
		Say({ ok ~= false and string.format("#%d %s", n, on and "pinned (never pruned)" or "unpinned") or "couldn't write the save list" })
	end)
	return n
end

function C.Note(id, text)
	local store = Ready("ss_note")
	if store == nil then
		return nil
	end
	local n = Id("ss_note", id, store)
	if n == nil then
		return nil
	end
	store:SetNote(n, text ~= nil and tostring(text) or nil, function(ok)
		Say({ ok ~= false and string.format("#%d: note %s", n, text ~= nil and ("\"" .. tostring(text) .. "\"") or "cleared") or "couldn't write the save list" })
	end)
	return n
end

function C.Delete(id)
	local store = Ready("ss_delete")
	if store == nil then
		return nil
	end
	local n = Id("ss_delete", id, store)
	if n == nil then
		return nil
	end
	if store.pins[n] then
		Say({ string.format("ss_delete: #%d is pinned (ss_unpin(%d) first)", n, n) })
		return nil
	end
	local line = C.Line(store.meta[n])
	store:Delete(n, function(ok)
		Say({ ok ~= false and ("deleted " .. line) or "ss_delete: couldn't write the save list" })
	end)
	return n
end

C.COMMANDS = { "ss_help", "ss_list", "ss_slots", "ss_load", "ss_undo", "ss_slot", "ss_pin", "ss_unpin", "ss_note", "ss_delete" }

function C.Register(G, L)
	C.L = L
	local fns = {
		ss_help = function() C.Help() end,
		ss_list = function(n, which) C.List(n, which) end,
		ss_slots = function() C.Slots() end,
		ss_load = function(id, mode) C.Load(id, mode) end,
		ss_undo = function(mode) C.Undo(mode) end,
		ss_slot = function(id, slot) C.Slot(id, slot) end,
		ss_pin = function(id) C.Pin(id, true) end,
		ss_unpin = function(id) C.Pin(id, false) end,
		ss_note = function(id, text) C.Note(id, text) end,
		ss_delete = function(id) C.Delete(id) end,
	}
	local made, taken = 0, {}
	for _, name in ipairs(C.COMMANDS) do
		if rawget(G, name) == nil then
			local fn = fns[name]
			rawset(G, name, function(...)
				local ok, err = pcall(fn, ...)
				if not ok then
					print(SS.TAG .. " " .. name .. ": an error: " .. tostring(err))
				end
			end)
			made = made + 1
		else
			taken[#taken + 1] = name
		end
	end
	local info = made .. " commands (ss_help() lists them)"
	if #taken > 0 then
		info = info .. "; already taken, left as they are: " .. table.concat(taken, ", ")
	end
	return made > 0, info
end

return C
