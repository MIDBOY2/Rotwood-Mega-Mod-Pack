-- Character Builds: the builds file. One text file outside every save and Steam account.
--
-- (0.2.0) The game doesn't let mods read %APPDATA% (os.getenv gives nothing), so the file is reached the
-- way the game itself reaches files above its save folder: its saved strings are kept in
-- ...\Klei\Rotwood\steam-<account>\saves\, and the game reads "../profile.json" and
-- "../customcommands.lua" from there. Two folders up is ...\Klei\Rotwood\, next to every Steam
-- account's folder:
--   C:\Users\<you>\AppData\Roaming\Klei\Rotwood\character_builds.lua
-- Every write is read back. If the game won't keep it there, the save folder is used instead (and the
-- log and the BUILDS tab say so). 0.1.0 kept its builds in the save folder ("character_builds"): they
-- are copied to the shared file the first time (the save folder copy stays as it was).
-- builds_file in the settings (a full path, e.g. a shared OneDrive folder) uses the game's Lua file
-- access by path instead: written as a new file, read back, then swapped in.
-- Either way the previous version is kept as .bak next to it.
local Store = {}

Store.VERSION = 1
Store.mode = "persistent"                     -- "persistent" (the game's saved strings) or "file" (a full path)
Store.path = nil                              -- "file": the full path
Store.UNIVERSAL = "../../character_builds.lua" -- next to the Steam account folders
Store.LOCAL = "character_builds"              -- this account's save folder (0.1.0, and the fallback)
Store.name = Store.UNIVERSAL                  -- "persistent": the name in use
Store.WHERE_UNIVERSAL = "Klei\\Rotwood\\character_builds.lua (next to the Steam account folders)"
Store.WHERE_LOCAL = "this Steam account's save folder (saves\\character_builds)"
Store.where = Store.WHERE_UNIVERSAL
Store.note = nil                              -- why the save folder is used, when it is

local function HaveIO()
	return type(io) == "table" and type(io.open) == "function" and type(os) == "table"
		and type(os.rename) == "function" and type(os.remove) == "function"
end

function Store.Configure(settings)
	local p = settings ~= nil and settings.builds_file or nil
	Store.note = nil
	if type(p) == "string" and p ~= "" and HaveIO() then
		Store.mode = "file"
		Store.path = p
		Store.where = p
	else
		Store.mode = "persistent"
		Store.path = nil
		Store.name = Store.UNIVERSAL
		Store.where = Store.WHERE_UNIVERSAL
		if type(p) == "string" and p ~= "" then
			Store.note = "builds_file needs the game's file access by path, which isn't there"
			Store.where = Store.where .. " (" .. Store.note .. ")"
		end
	end
	return Store.where
end

local function ReadFile(path)
	if type(path) ~= "string" then
		return nil
	end
	local f = io.open(path, "rb")
	if f == nil then
		return nil
	end
	local text = f:read("*a")
	f:close()
	return text
end
Store.ReadFile = ReadFile

function Store.Decode(text)
	if type(text) ~= "string" or text == "" then
		return nil, "empty"
	end
	local fn, err = load(text, "=character_builds", "t", {})
	if fn == nil then
		return nil, tostring(err)
	end
	local ok, t = pcall(fn)
	if not ok or type(t) ~= "table" then
		return nil, tostring(t)
	end
	return t
end

function Store.Encode(t)
	local DataDumper = require "util.datadumper"
	return DataDumper(t, nil, true)
end

-- a file's table with its lists in place
function Store.Normalise(t)
	if type(t) ~= "table" then
		t = {}
	end
	t.version = t.version or Store.VERSION
	if type(t.builds) ~= "table" then
		t.builds = {}
	end
	if type(t.auto) ~= "table" then
		t.auto = {}
	end
	-- only numbered slots in builds, only a list in auto
	for k in pairs(t.builds) do
		if type(k) ~= "number" or type(t.builds[k]) ~= "table" then
			t.builds[k] = nil
		end
	end
	local auto = {}
	for _, b in ipairs(t.auto) do
		if type(b) == "table" then
			auto[#auto + 1] = b
		end
	end
	t.auto = auto
	return t
end

-- the game's saved string: cb(text or nil)
local function Persist(name, cb)
	TheSim:GetPersistentString(name, function(ok, text)
		cb((ok ~= false and type(text) == "string" and text ~= "") and text or nil)
	end)
end
Store.Persist = Persist

-- One file's table from its text and its .bak's text. cb(t, note)
local function FromTexts(text, bak_text, where, cb)
	if text ~= nil then
		local t, err = Store.Decode(text)
		if t ~= nil then
			return cb(Store.Normalise(t))
		end
		local bt = Store.Decode(bak_text)
		if bt ~= nil then
			return cb(Store.Normalise(bt), "the builds file couldn't be read (" .. tostring(err) .. "): using its backup copy (.bak)")
		end
		return cb(nil, "the builds file can't be read (" .. tostring(err) .. "): " .. where .. ". Nothing is written over it; fix or move it")
	end
	local bt = Store.Decode(bak_text)
	if bt ~= nil then
		return cb(Store.Normalise(bt), "the builds file was missing: using its backup copy (.bak)")
	end
	return cb(Store.Normalise(nil), "new")
end

-- cb(t, note): t = the file's table (a fresh one when there's no file yet); t nil = can't read it
-- (then nothing may be written over it), note says why.
function Store.Read(cb)
	if Store.mode == "file" then
		return FromTexts(ReadFile(Store.path), ReadFile(Store.path .. ".bak"), Store.path, cb)
	end
	Persist(Store.name, function(text)
		Persist(Store.name .. ".bak", function(bak)
			FromTexts(text, bak, Store.where, cb)
		end)
	end)
end

-- the save folder from now on (this game session), said
local function UseLocal(why)
	Store.name = Store.LOCAL
	Store.note = why
	Store.where = Store.WHERE_LOCAL .. ": " .. why
	print("[Character Builds] builds file: " .. Store.where)
end

-- write text under a saved-string name, the old version kept as .bak first, and read it back.
-- cb(ok)
local function PersistWrite(name, text, cb)
	Persist(name, function(old)
		local function WriteNew()
			TheSim:SetPersistentString(name, text, false, function(ok)
				if ok == false then
					return cb(false)
				end
				Persist(name, function(back)
					cb(back ~= nil and Store.Decode(back) ~= nil)
				end)
			end)
		end
		if old ~= nil and Store.Decode(old) ~= nil then
			TheSim:SetPersistentString(name .. ".bak", old, false, function() WriteNew() end)
		else
			WriteNew()
		end
	end)
end

-- cb(ok, why)
function Store.Write(t, cb)
	local okenc, text = pcall(Store.Encode, t)
	if not okenc or type(text) ~= "string" then
		return cb(false, "the builds couldn't be written out: " .. tostring(text))
	end
	if Store.mode == "file" then
		local tmp = Store.path .. ".tmp"
		local f, err = io.open(tmp, "wb")
		if f == nil then
			return cb(false, "can't write " .. tmp .. " (" .. tostring(err) .. "): does the folder exist?")
		end
		f:write(text)
		f:close()
		if Store.Decode(ReadFile(tmp)) == nil then
			os.remove(tmp)
			return cb(false, "the new builds file didn't read back; the old one is untouched")
		end
		if ReadFile(Store.path) ~= nil then
			os.remove(Store.path .. ".bak")
			local okb, berr = os.rename(Store.path, Store.path .. ".bak")
			if not okb then
				os.remove(tmp)
				return cb(false, "can't keep the old file as .bak (" .. tostring(berr) .. "); nothing changed")
			end
		end
		local okr, rerr = os.rename(tmp, Store.path)
		if not okr then
			os.rename(Store.path .. ".bak", Store.path)
			return cb(false, "can't put the new file in place (" .. tostring(rerr) .. "); the old one is back")
		end
		return cb(true)
	end
	PersistWrite(Store.name, text, function(ok)
		if ok then
			return cb(true)
		end
		if Store.name == Store.UNIVERSAL then
			UseLocal("the game didn't keep the file next to the Steam account folders")
			return Persist(Store.LOCAL, function(old_local)
				-- builds already in the save folder are never written over by a table read from the
				-- shared place: switched, nothing written, the next try reads them
				local lt = Store.Decode(old_local)
				if lt ~= nil and (next(Store.Normalise(lt).builds) ~= nil or #lt.auto > 0) then
					return cb(false, "the shared place didn't keep it; switched to this account's save folder, which has builds of its own: nothing was overwritten, try again")
				end
				PersistWrite(Store.LOCAL, text, function(ok2)
					cb(ok2, ok2 and "saved in this account's save folder instead (the shared place didn't keep it)" or "not saved: the save folder didn't keep it either")
				end)
			end)
		end
		cb(false, "the save folder didn't keep it")
	end)
end

-- 0.1.0's builds (this account's save folder) into the shared file, once: only while the shared file
-- doesn't exist yet. The save folder copy stays. cb(count or nil, note)
function Store.Migrate(cb)
	cb = cb or function() end
	if Store.mode ~= "persistent" or Store.name ~= Store.UNIVERSAL then
		return cb(nil)
	end
	Persist(Store.UNIVERSAL, function(have)
		if have ~= nil then
			return cb(nil)
		end
		Persist(Store.LOCAL, function(text)
			local t = Store.Decode(text)
			if t == nil then
				return cb(nil)
			end
			t = Store.Normalise(t)
			local n = 0
			for _ in pairs(t.builds) do
				n = n + 1
			end
			Store.Write(t, function(ok, why)
				if ok and Store.name == Store.UNIVERSAL then
					cb(n, n .. " builds and " .. #t.auto .. " backups from this account's save folder copied to " .. Store.WHERE_UNIVERSAL)
				else
					cb(nil, why)
				end
			end)
		end)
	end)
end

return Store
