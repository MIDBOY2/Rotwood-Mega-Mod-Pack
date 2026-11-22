-- Save States (Rotwood build 760548)
-- Save the run you're in to a slot with a key, and rebuild it later with
-- another: that room of that run, HP, Teffra, potion charges, powers (rarity,
-- stacks, counters). Your character's progression is never touched.
-- Settings: scripts/savestates_settings.lua

local pcall, require = GLOBAL.pcall, GLOBAL.require

local SS = require "savestates.main"

local ok_s, user_settings = pcall(require, "savestates_settings")
if not ok_s then
	print(SS.TAG .. " savestates_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end
local settings = SS.LoadSettings(user_settings)
for _, w in ipairs(SS.warnings) do
	SS.Log(w)
end
if not settings.enabled then
	SS.Log("off (enabled = false in savestates_settings.lua)")
	return
end
if GLOBAL.rawget(GLOBAL, "SaveStatesAPI") ~= nil then
	SS.Log("already loaded")
	return
end

local function Req(name)
	local ok, m = pcall(require, name)
	return ok and m or nil
end

local lines = {}
local function Part(name, fn, ...)
	local ok, r1, r2 = pcall(fn, ...)
	if ok and r1 then
		lines[#lines + 1] = name .. ": " .. tostring(r2)
		return true
	end
	local why = ok and tostring(r2) or tostring(r1)
	SS.off[name] = why
	lines[#lines + 1] = name .. " off (" .. why .. ")"
	return false
end

local D = require "savestates.data"
local Store = require "savestates.store"
local C = require "savestates.capture"
local Gear = require "savestates.gear"
local L = require "savestates.loader"
local K = require "savestates.keys"
local Menu = require "savestates.menu"

-- the game's tables
local Equipment = Req("defs.equipment")
local Consumable = Req("defs.consumable")
local biomes = Req("defs.biomes")
local itemforge = Req("defs.itemforge")
local SaveData = Req("savedata.savedata")
local RoomLoader = Req("roomloader")

C.G, C.Equipment, C.Consumable, C.biomes = GLOBAL, Equipment, Consumable, biomes
Gear.G, Gear.itemforge, Gear.Equipment = GLOBAL, itemforge, Equipment
L.G, L.biomes = GLOBAL, biomes

-- the files: the game's own save files (savestates/ in the saves folder)
local function Path(name)
	return "savestates/" .. name
end
local io = {
	Write = function(name, t, cb)
		local ok, err = pcall(function()
			local sd = SaveData(Path(name))
			sd.persistdata = t
			sd.dirty = true
			sd:Save(function(success) cb(success ~= false) end)
		end)
		if not ok then
			SS.Log("couldn't write " .. name .. ": " .. tostring(err))
			cb(false)
		end
	end,
	Read = function(name, cb)
		local ok, err = pcall(function()
			local sd = SaveData(Path(name))
			sd:_Load(function(load_error)
				if load_error == nil then
					cb(sd.persistdata)
				else
					cb(nil)
				end
			end)
		end)
		if not ok then
			SS.Log("couldn't read " .. name .. ": " .. tostring(err))
			cb(nil)
		end
	end,
	Erase = function(name, cb)
		local ok = pcall(function()
			GLOBAL.TheSim:ErasePersistentString(Path(name), function(success) cb(success ~= false) end)
		end)
		if not ok then
			pcall(function() SaveData(Path(name)):Erase(cb) end)
		end
	end,
}

local needs = Equipment ~= nil and Consumable ~= nil and biomes ~= nil and itemforge ~= nil and SaveData ~= nil and RoomLoader ~= nil
if not needs then
	SS.Log("off: a game file it needs is missing or changed")
	return
end

L.store = Store.New(io, settings)

local loads_ok = Part("loading", L.Install, RoomLoader)

-- a load gives the saved room its own enemies again (0.5.0)
if settings.same_room then
	local Same = require "savestates.sameroom"
	Same.Log = SS.Log
	Part("same room", Same.Install, GLOBAL, Req("encounter.encounter_deck"), Req("encounter.encounters"), Req("encounter.dynamicencounterelements"))
else
	lines[#lines + 1] = "same room off (same_room = false)"
end

-- console commands (the menu's jobs without the debug UI): only defined, nothing runs until one is typed
Part("console", require("savestates.console").Register, GLOBAL, L)

-- a player entered a room: the auto save, the steps after a load, your gear back in town
AddPlayerPostInit(function(inst)
	inst:ListenForEvent("enter_room", function(player)
		local ok, err = pcall(L.OnEnterRoom, player or inst)
		if not ok then
			SS.Log("room: " .. tostring(err))
		end
	end)
end)

AddGamePostInit(function()
	SS.NoteFn = function(title, text)
		GLOBAL.TheFrontEnd:ShowTextNotification(nil, tostring(title), text ~= nil and tostring(text) or "", 5)
	end
	L.store:Load(function(ok, problems)
		if not ok then
			SS.Log("the save list had a broken file (" .. table.concat(problems, ", ") .. "): starting it fresh")
		end
		L.ReadPending()
	end)
	local actions = {
		save = function(slot) L.Save(slot) end,
		load = function(slot, mode)
			if not loads_ok then
				SS.Note("Can't load", "the loading part is off: " .. tostring(SS.off.loading))
				return
			end
			L.LoadSlot(slot, mode)
		end,
		latest = function(mode)
			if not loads_ok then
				SS.Note("Can't load", "the loading part is off: " .. tostring(SS.off.loading))
				return
			end
			L.LoadSlot(0, mode)
		end,
		menu = function()
			-- the debug UI's menu when the game has it; else the archive screen (every save kept)
			if GLOBAL.rawget(GLOBAL, "CAN_USE_DBUI") and Menu.node ~= nil then
				Menu.Toggle(GLOBAL)
			elseif settings.codex then
				SS.Call("the history tabs", function() require("savestates.codex").ToggleHistory() end)
			else
				Menu.Toggle(GLOBAL) -- (says it needs the debug UI: ss_help() in the console)
			end
		end,
		typing = function()
			local fe = GLOBAL.TheFrontEnd
			return (fe ~= nil and fe.forceProcessText == true) or Menu.Typing()
		end,
	}
	Req("input.inputconstants") -- (it sets the global)
	local InputConstants = GLOBAL.rawget(GLOBAL, "InputConstants")
	Part("keys", K.Install, GLOBAL.TheInput, InputConstants ~= nil and InputConstants.Keys or nil, actions)
	-- the Saved Hunts tab in the camp's Codex
	if settings.codex and loads_ok then
		local codex_ok = Part("Saved Hunts", function()
			local Codex = require "savestates.codex"
			Codex.settings.first = settings.codex_tab_first
			Codex.settings.screen = settings.pause_menu_screen
			return Codex.Install(GLOBAL, require("screens.town.codexscreenmulti"),
				{ L = L, biomes = biomes, itemforge = itemforge, Equipment = Equipment })
		end)
		-- the full-screen Saved Hunts (experimental): without it, the Codex's view
		if codex_ok and settings.pause_menu_screen == "full" then
			Part("full screen", function()
				return require("savestates.fullscreen").Install(GLOBAL)
			end)
		end
		-- the pause menu's SAVE HUNT / LOAD HUNT, and a page open while a key saves
		SS.on_saved = function(slot)
			pcall(function() require("savestates.codex").OnSaved(slot) end)
		end
		if settings.pause_menu ~= false then
			Part("pause menu", function()
				return require("savestates.codex").HookPause(require("screens.pausescreen"))
			end)
		end
	elseif not settings.codex then
		lines[#lines + 1] = "Saved Hunts off (codex = false)"
	end
	if GLOBAL.rawget(GLOBAL, "CAN_USE_DBUI") then
		Part("menu", function()
			local DebugNodes = require "dbui.debug_nodes"
			Menu.L = L
			Menu.Make(DebugNodes)
			return true, "in the debug UI"
		end)
	else
		lines[#lines + 1] = "the debug UI menu off (no debug UI): Ctrl+Shift+Alt+1 shows the Codex's history tabs"
	end
	-- after the game's debug keys are set up
	local function Last()
		Part("debug keys", K.WrapDebugKeys, GLOBAL)
		SS.Log("on: " .. table.concat(lines, "; "))
	end
	local gi = GLOBAL.rawget(GLOBAL, "TheGlobalInstance")
	if gi ~= nil and gi.DoTaskInTime ~= nil then
		gi:DoTaskInTime(0, Last)
	else
		Last()
	end
end)

GLOBAL.rawset(GLOBAL, "SaveStatesAPI", {
	version = 1,
	Save = function(slot) L.Save(slot) end,
	Load = function(slot, mode) L.LoadSlot(slot, mode or "rebuild") end,
})
