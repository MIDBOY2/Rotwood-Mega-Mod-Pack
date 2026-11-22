-- Character Builds: console commands. n = a build slot; p = a player number (1 = the first player,
-- default), the same as AllPlayers[p].
--   cb_list()            the builds and the automatic backups
--   cb_save(n, p)        save player p's character as build n
--   cb_load(n, p, what)  load build n onto player p's character, right away. what: "all" (default),
--                        "all_face" (everything, keeping your eyes, nose, mouth), "look", "face" (the
--                        look keeping your eyes, nose, mouth), "colours", "gear"
--   cb_undo(p)           load player p's newest automatic backup back onto that character
--   cb_delete(n)         delete build n
--   cb_where()           where the builds file is
local Main = require "characterbuilds.main"

local Console = {}

local function Player(p)
	local list = rawget(_G, "AllPlayers") or {}
	return list[tonumber(p) or 1]
end

local function Say(msg)
	Main.Log(msg)
end

function Console.Install(G)
	rawset(G, "cb_where", function()
		Say("builds file: " .. tostring(Main.Store.where))
		return Main.Store.where
	end)
	rawset(G, "cb_list", function()
		Main.Store.Read(function(t, note)
			if t == nil then
				return Say(note)
			end
			local n = 0
			for slot = 1, Main.SlotCount(t) do
				local b = t.builds[slot]
				if b ~= nil then
					Say("build " .. slot .. ": " .. Main.Describe(b))
					n = n + 1
				end
			end
			for i, b in ipairs(t.auto) do
				Say("backup B" .. i .. ": " .. Main.Label(b) .. ", " .. Main.Describe(b))
			end
			Say(n .. " builds, " .. #t.auto .. " backups, in " .. tostring(Main.Store.where))
		end)
	end)
	rawset(G, "cb_save", function(n, p)
		local pl = Player(p)
		if pl == nil then
			return Say("no player " .. tostring(p or 1))
		end
		Main.SaveBuild(pl, tonumber(n), function(ok, why)
			Say(ok and ("saved as build " .. tostring(n)) or ("not saved: " .. tostring(why)))
		end)
	end)
	rawset(G, "cb_load", function(n, p, what)
		local pl = Player(p)
		if pl == nil then
			return Say("no player " .. tostring(p or 1))
		end
		what = what or "all"
		if Main.MODES[what] == nil then
			return Say("not loaded: what is \"all\", \"all_face\", \"look\", \"face\", \"colours\" or \"gear\"")
		end
		Main.Store.Read(function(t, note)
			local b = t ~= nil and t.builds[tonumber(n)] or nil
			if b == nil then
				return Say("not loaded: " .. (t == nil and tostring(note) or ("build " .. tostring(n) .. " is empty")))
			end
			Main.LoadBuild(pl, b, "build " .. tostring(n), what, function(ok, why)
				Say(ok and ("loaded build " .. tostring(n) .. " (" .. Main.MODES[what].short .. ")") or ("not loaded: " .. tostring(why)))
			end)
		end)
	end)
	rawset(G, "cb_undo", function(p)
		local pl = Player(p)
		if pl == nil then
			return Say("no player " .. tostring(p or 1))
		end
		local cslot = Main.CharacterSlotOf(pl)
		Main.Store.Read(function(t, note)
			if t == nil then
				return Say("not loaded: " .. tostring(note))
			end
			for i, b in ipairs(t.auto) do
				if b.character_slot == cslot then
					return Main.LoadBuild(pl, b, "backup B" .. i, "all", function(ok, why)
						Say(ok and ("loaded backup B" .. i) or ("not loaded: " .. tostring(why)))
					end)
				end
			end
			Say("no backup of character " .. tostring(cslot))
		end)
	end)
	rawset(G, "cb_delete", function(n)
		Main.DeleteBuild(tonumber(n), false, function(ok, why)
			Say(ok and ("deleted build " .. tostring(n)) or ("not deleted: " .. tostring(why)))
		end)
	end)
	return true
end

return Console
