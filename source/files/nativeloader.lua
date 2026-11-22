-- Native Loader 0.1.0 - a mod loader for Rotwood.
--
-- What it is
--   One file, own code. It loads the mods in the mods folder (the folders with a
--   modinfo.lua + modmain.lua) without any patched game script: every hook it gives
--   a mod rides on something the unmodified game already does by itself.
--
-- How it starts (two ways, same file)
--   "early"  One line in the game's main.lua, at the spot where the game's own
--            (switched-off) mod loading sits. This is the real start: the mods load
--            before the game registers its prefabs, builds its stategraphs and loads
--            the room - the same moment as before.
--   "late"   The game's own custom commands (customcommands.lua, launch option
--            -enable_customcommands). That runs after the room and the players are
--            already loaded, too late to load mods safely, so it is only a watchdog:
--            it tells you when the early line is missing (after a game update).
--
-- What each mod function rides on (all of it already in the unmodified game)
--   AddPrefabPostInit / AddPlayerPostInit / AddPrefabPostInitAny
--        the game's "entity_spawned" event (mainfunctions.lua, SpawnPrefabFromSim):
--        one listener, one table lookup per spawn.
--   AddStateGraphPostInit
--        stategraph.lua asks ModManager:GetPostInitFns("StateGraphPostInit", name)
--        whenever it builds a stategraph.
--   AddGamePostInit
--        mainfunctions.lua (Check_Mods) calls ModManager:SetPostEnv() at the end of Start().
--   Assets / PrefabFiles
--        gamelogic.lua (RegisterAllPrefabs) calls ModManager:RegisterPrefabs() each load.
--   AddComponentPostInit
--        EntityScript:AddComponent, wrapped only when a mod asks for it.
--   AddClassPostConstruct / AddGlobalClassPostConstruct, modimport, require
--        plain Lua (the class constructor, the game's own file loader and search path).
--
-- Safety
--   Nothing here may stop the game: every step and every mod callback is protected, and
--   a mod that fails is reported while the others go on.
--   All or nothing after a game update: when the game no longer has one of the things
--   listed above, NO mod is loaded (the game runs unmodified) and a message at the main
--   menu says what is missing - never half the mods' functions.
--   Off switches: mods\nativeloader_settings.lua (enabled = false, disabled_mods = {...}).
--   Without this file, or without the line in main.lua, the game runs unmodified.

local MODE = ...

local VERSION = "0.1.0"
local TAG = "[Native Loader] "

local G = _G
local rawget, rawset, type, tostring, pairs, ipairs = rawget, rawset, type, tostring, pairs, ipairs
local pcall, xpcall, error, next, require, math = pcall, xpcall, error, next, require, math
local string, table, debug, package, print = string, table, debug, package, print
local traceback = debug.traceback

-- The game runs with strict globals: reading a global that was never set is an error.
-- Everything that may be missing is read through this.
local function g(name)
	return rawget(G, name)
end

local function log(msg)
	print(TAG .. tostring(msg))
end

local MODS_ROOT = type(g("MODS_ROOT")) == "string" and g("MODS_ROOT") or "MODS:"
local LOADER_FILE = MODS_ROOT .. "nativeloader.lua"
local SETTINGS_FILE = MODS_ROOT .. "nativeloader_settings.lua"

local DEFAULTS = {
	enabled = true,       -- false: load no mods at all (the game runs unmodified)
	disabled_mods = {},   -- folder names to leave out, e.g. { "rotwood-stick-aim" }
	fast_require = false, -- experimental: game scripts are found without first looking in every mod folder
	                      -- (a mod can then no longer replace a game script by having a file with the same path)
	notices = true,       -- the in-game message at the main menu when a mod failed / mods are off
	verbose = false,      -- more lines in client_log.txt
}

-- ---------------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------------

-- Run a loaded chunk with its own globals table (Lua 5.4 has no setfenv).
local function set_env(fn, env)
	local i = 1
	while true do
		local name = debug.getupvalue(fn, i)
		if name == "_ENV" then
			debug.upvaluejoin(fn, i, function() return env end, 1)
			return fn
		elseif not name then
			return fn
		end
		i = i + 1
	end
end

-- A data file (settings, modinfo.lua): run with an empty environment, like the game
-- does for modinfo.lua (RunInEnvironment_Safe). Returns the table, or nil + why.
local function read_data_file(path)
	local load_file = g("kleiloadlua")
	if type(load_file) ~= "function" then
		return nil, "kleiloadlua missing"
	end
	local fn = load_file(path)
	if fn == nil then
		return nil, "missing"
	end
	if type(fn) ~= "function" then
		return nil, tostring(fn)
	end
	set_env(fn, {})
	local ok, ret = pcall(fn)
	if not ok then
		return nil, tostring(ret)
	end
	if type(ret) ~= "table" then
		return nil, "it does not return a table"
	end
	return ret
end

local function read_settings()
	local s = {}
	for k, v in pairs(DEFAULTS) do
		s[k] = v
	end
	local user, why = read_data_file(SETTINGS_FILE)
	if user == nil then
		if why ~= "missing" then
			log("settings not read (" .. tostring(why) .. "): using the defaults")
		end
		return s, why ~= "missing" and why or nil
	end
	for k, v in pairs(DEFAULTS) do
		local u = user[k]
		if u ~= nil then
			if type(u) == type(v) then
				s[k] = u
			else
				log("settings: " .. k .. " should be a " .. type(v) .. ", using the default")
			end
		end
	end
	return s
end

-- A message box at the main menu, built the way the game builds its own
-- (mainfunctions.lua, the "invites disabled" dialog). Never throws.
local function show_notice(title, body)
	local ok, err = pcall(function()
		local fe = g("TheFrontEnd")
		if fe == nil then
			return
		end
		local ConfirmDialog = require("screens.dialogs.confirmdialog")
		local dialog = ConfirmDialog(nil, nil, true, title, nil, body)
		dialog
			:FollowTextScaling()
			:SetYesButton("OK", function() dialog:Close() end)
			:HideArrow()
			:HideNoButton()
			:SetMinWidth(1000)
			:CenterButtons()
		fe:PushScreen(dialog)
		dialog:AnimateIn()
	end)
	if not ok then
		log("message not shown (" .. tostring(err) .. ")")
	end
	return ok
end

local function at_main_menu()
	local f = g("IsInFrontEnd")
	if type(f) ~= "function" then
		return false
	end
	local ok, yes = pcall(f)
	return ok and yes == true
end

-- ---------------------------------------------------------------------------------
-- "late": the watchdog from customcommands.lua. Loads nothing.
-- ---------------------------------------------------------------------------------
if MODE ~= "early" then
	local L = g("NativeLoader")
	if type(L) == "table" and L.started then
		-- the early start ran. The room is loaded by now, so the game must have asked for the mods' parts.
		local problems = type(L.Problems) == "function" and L.Problems(false) or {}
		if #problems > 0 and L.settings.notices and at_main_menu() and not L.problems_shown then
			L.problems_shown = true
			show_notice(L.blocked and "Mods are off" or "Mods may not work", table.concat(problems, "\n\n") .. "\n\nDetails are in client_log.txt.")
		elseif L.settings.verbose then
			log("watchdog: the early start ran (" .. tostring(#L.loaded) .. " mods)")
		end
		return L
	end
	local settings = read_settings()
	if not settings.enabled then
		return nil
	end
	log("MODS ARE OFF: the loader's line in the game's main.lua is missing (a game update or a file check puts the game's own scripts back). Run the Native Loader install again.")
	if settings.notices and at_main_menu() then
		show_notice("Mods are off",
			"The game's scripts were replaced (a game update or a file check), so no mod is loaded.\n\nRun the Native Loader install again before you load a save that uses mods.")
	end
	return nil
end

-- ---------------------------------------------------------------------------------
-- "early": load the mods
-- ---------------------------------------------------------------------------------
if type(g("NativeLoader")) == "table" then
	log("already started in this session: second start ignored")
	return g("NativeLoader")
end

local settings, settings_error = read_settings()

local L = {
	version = VERSION,
	started = false,
	settings = settings,
	mods = {},     -- every folder looked at: { name, version, status, error }
	loaded = {},   -- the mods whose modmain.lua was run (in load order), each { name, info, env, status }
	errors = 0,    -- errors caught in mod callbacks so far
	notices = {},  -- messages waiting for the main menu
	off = {},      -- off.spawn: why the entity_spawned listener could not be attached
}

if not settings.enabled then
	log(VERSION .. ": off (enabled = false in " .. SETTINGS_FILE .. ")")
	return nil
end

local kleiloadlua = g("kleiloadlua")
local TheSim = g("TheSim")
local ModManager = g("ModManager")

-- the minimum the loader cannot do without
do
	local missing = {}
	if type(kleiloadlua) ~= "function" then missing[#missing + 1] = "kleiloadlua" end
	if TheSim == nil or type(TheSim.ListFiles) ~= "function" then missing[#missing + 1] = "TheSim:ListFiles" end
	if type(package) ~= "table" or type(package.path) ~= "string" then missing[#missing + 1] = "package.path" end
	if type(debug) ~= "table" or type(debug.getupvalue) ~= "function" or type(debug.upvaluejoin) ~= "function" then
		missing[#missing + 1] = "debug.upvaluejoin"
	end
	if #missing > 0 then
		log(VERSION .. ": not started, the game is missing: " .. table.concat(missing, ", ") .. " (no mods loaded)")
		return nil
	end
end

-- another loader already loaded mods through the game's ModManager (the old patch): stay out
if type(ModManager) == "table" and type(rawget(ModManager, "mods")) == "table" and #ModManager.mods > 0 then
	log(VERSION .. ": not started, another mod loader already loaded " .. #ModManager.mods .. " mods (remove one of the two)")
	return nil
end

rawset(G, "NativeLoader", L)

-- Everything the mods' functions ride on. One of them missing = the game changed: load nothing.
do
	local missing = {}
	local function need(ok, what)
		if not ok then
			missing[#missing + 1] = what
		end
	end
	need(g("Class") ~= nil, "Class")
	need(type(ModManager) == "table", "ModManager")
	if type(ModManager) == "table" then
		need(type(ModManager.RegisterPrefabs) == "function", "ModManager.RegisterPrefabs")
		need(type(ModManager.GetPostInitFns) == "function", "ModManager.GetPostInitFns")
		need(type(ModManager.SetPostEnv) == "function", "ModManager.SetPostEnv")
	end
	need(type(g("LoadPrefabFile")) == "function", "LoadPrefabFile")
	need(type(g("RegisterPrefabs")) == "function", "RegisterPrefabs")
	need(type(g("Prefab")) == "table", "Prefab")
	need(type(g("Asset")) == "table", "Asset")
	need(type(TheSim.LoadPrefabs) == "function", "TheSim:LoadPrefabs")
	local ES = g("EntityScript")
	need(type(ES) == "table" and type(rawget(ES, "AddComponent")) == "function", "EntityScript.AddComponent")
	if #missing > 0 then
		L.blocked = table.concat(missing, ", ")
		L.started = true
		log(VERSION .. ": NO MODS LOADED: this game version no longer has " .. L.blocked
			.. " (the loader needs an update for it). The game runs unmodified.")
		L.Problems = function()
			return { "No mod is loaded: this game version changed something the mod loader needs (" .. L.blocked .. ")." }
		end
		function L.Report()
			return "Native Loader " .. VERSION .. ": no mods loaded, the game no longer has " .. L.blocked
		end
		-- say it at the main menu too, through the game's own end-of-start call when that is still there
		if type(ModManager) == "table" and type(ModManager.SetPostEnv) == "function" then
			ModManager.SetPostEnv = function()
				if settings.notices and at_main_menu() and not L.problems_shown then
					L.problems_shown = true
					show_notice("Mods are off", L.Problems()[1] .. "\n\nThe game runs unmodified. Details are in client_log.txt.")
				end
			end
			rawset(G, "GAMEPLAY_MODS_ENABLED", true)
		end
		return L
	end
end

-- ---------------------------------------------------------------------------------
-- hooks: where the mods' functions are kept, and how they are called
-- ---------------------------------------------------------------------------------
local prefab_hooks = {}     -- prefab name -> { handler, ... }
local any_hooks = {}        -- every prefab / players only, in the order they were added
local component_hooks = {}  -- component name -> { handler, ... }
local sg_hooks = {}         -- stategraph name -> { function(sg), ... } (already protected)
local H = {
	attached = false,          -- the entity_spawned listener is on
	any_plain = 0,             -- how many any_hooks are not players-only
	component_wrapped = false, -- EntityScript.AddComponent is wrapped
	postenv_ran = false,
	register_calls = 0,        -- how often the game asked for the mods' prefabs (once per load)
	sg_asked = 0,              -- how often the game asked for stategraph functions
	orig = {},                 -- the game's functions that were replaced
	prefab = prefab_hooks, any = any_hooks, component = component_hooks, sg = sg_hooks,
}
L.hooks = H

local function report(h, err)
	L.errors = L.errors + 1
	h.errs = (h.errs or 0) + 1
	if h.errs <= 3 then
		log("error in " .. tostring(h.mod) .. " (" .. tostring(h.what) .. "): " .. tostring(err))
		if h.errs == 3 then
			log("further errors from this " .. tostring(h.what) .. " are counted, not logged")
		end
	end
end

local function guard0(h)
	local ok, err = xpcall(h.fn, traceback)
	if not ok then
		report(h, err)
	end
end

local function guard1(h, a)
	local ok, err = xpcall(h.fn, traceback, a)
	if not ok then
		report(h, err)
	end
end

local function guard2(h, a, b)
	local ok, err = xpcall(h.fn, traceback, a, b)
	if not ok then
		report(h, err)
	end
end

-- A spawned entity: the mods' prefab functions first, then the every-prefab / player
-- ones (the order the old loader used). Entities no mod asked about cost one lookup.
local function dispatch_spawn(inst)
	local hs = prefab_hooks[inst.prefab]
	if hs ~= nil then
		for i = 1, #hs do
			guard1(hs[i], inst)
		end
	end
	local n = #any_hooks
	if n ~= 0 then
		local is_player = nil
		if H.any_plain == 0 then
			if not inst:HasTag("player") then
				return
			end
			is_player = true
		end
		for i = 1, n do
			local h = any_hooks[i]
			if h.player then
				if is_player == nil then
					is_player = inst:HasTag("player") and true or false
				end
				if is_player then
					guard1(h, inst)
				end
			else
				guard1(h, inst)
			end
		end
	end
end

local spawn_fault = { mod = "the loader", what = "entity_spawned" }
local function on_entity_spawned(_, inst)
	if inst == nil then
		return
	end
	local ok, err = pcall(dispatch_spawn, inst)
	if not ok then
		report(spawn_fault, err)
	end
end

-- TheGlobalInstance is made after the mods load, so the listener goes on at the first
-- of the game's own calls that comes after it (prefab registration, see below).
local function attach_spawn_listener()
	if H.attached then
		return true
	end
	if next(prefab_hooks) == nil and #any_hooks == 0 then
		return false -- no mod asked: no listener at all
	end
	local gi = g("TheGlobalInstance")
	if gi == nil or type(gi.ListenForEvent) ~= "function" then
		return false
	end
	local ok, err = pcall(gi.ListenForEvent, gi, "entity_spawned", on_entity_spawned)
	if not ok then
		if not L.off.spawn then
			L.off.spawn = tostring(err)
			log("prefab / player functions OFF: could not listen for entity_spawned (" .. tostring(err) .. ")")
		end
		return false
	end
	H.attached = true
	return true
end

local function ensure_component_hook()
	if H.component_wrapped then
		return true
	end
	local ES = g("EntityScript")
	if type(ES) ~= "table" or type(rawget(ES, "AddComponent")) ~= "function" then
		return false
	end
	local orig = ES.AddComponent
	H.orig.AddComponent = orig
	ES.AddComponent = function(self, name, ...)
		local hs = component_hooks[name]
		if hs == nil then
			return orig(self, name, ...) -- a component no mod asked about: straight through
		end
		local cmp = orig(self, name, ...)
		for i = 1, #hs do
			guard2(hs[i], cmp, self)
		end
		return cmp
	end
	H.component_wrapped = true
	return true
end

-- ---------------------------------------------------------------------------------
-- the game's own calls into ModManager, answered here
-- ---------------------------------------------------------------------------------
local function mod_register_prefabs(env)
	local LoadPrefabFile, RegisterPrefabs, Prefab = g("LoadPrefabFile"), g("RegisterPrefabs"), g("Prefab")
	local Prefabs = g("Prefabs")
	env.LoadPrefabFile = LoadPrefabFile
	env.RegisterPrefabs = RegisterPrefabs
	env.Prefabs = {}
	local files = rawget(env, "PrefabFiles")
	if type(files) == "table" then
		for _, path in ipairs(files) do
			-- the game's own prefab file loader: it registers every Prefab the file returns
			local ok, ret = xpcall(LoadPrefabFile, traceback, "prefabs/" .. tostring(path))
			if ok and type(ret) == "table" then
				for _, prefab in ipairs(ret) do
					if type(prefab) == "table" and type(prefab.name) == "string" then
						env.Prefabs[prefab.name] = prefab
					end
				end
			elseif not ok then
				L.errors = L.errors + 1
				log("error in " .. env.modname .. " (prefab file " .. tostring(path) .. "): " .. tostring(ret))
			end
		end
	end
	local names = {}
	for name, prefab in pairs(env.Prefabs) do
		names[#names + 1] = name
		if type(Prefabs) == "table" then
			Prefabs[name] = prefab
		end
	end
	table.sort(names)
	local mod_prefab = "MOD_" .. env.modname
	RegisterPrefabs(Prefab(mod_prefab, nil, rawget(env, "Assets"), names, true))
	TheSim:LoadPrefabs({ mod_prefab })
end

-- Has the game asked for the mods' parts by now? after_start: the end of Start() has passed.
-- (If a game update takes one of its calls away, this is what notices.)
local function problems(after_start)
	local list = {}
	if #L.loaded == 0 then
		return list
	end
	if H.register_calls == 0 then
		list[#list + 1] = "The game did not ask for the mods' art and prefabs (ModManager:RegisterPrefabs was not called)."
	end
	if next(sg_hooks) ~= nil and H.sg_asked == 0 then
		list[#list + 1] = "The game did not ask for the mods' stategraph changes (ModManager:GetPostInitFns was not called)."
	end
	if (next(prefab_hooks) ~= nil or #any_hooks > 0) and not H.attached then
		list[#list + 1] = "The mods' prefab / player functions are not connected (entity_spawned"
			.. (L.off.spawn and (": " .. L.off.spawn) or "") .. ")."
	end
	if after_start and not H.postenv_ran then
		list[#list + 1] = "The game did not run the mods' end-of-start functions (ModManager:SetPostEnv was not called)."
	end
	return list
end
L.Problems = problems

local function install_modmanager_hooks()
	-- stategraph.lua: ModManager:GetPostInitFns("StateGraphPostInit", name) for each stategraph it builds;
	-- mainfunctions.lua: ("PrefabPostInit", name) for each prefab it registers (the game never uses that answer).
	H.orig.GetPostInitFns = ModManager.GetPostInitFns
	ModManager.GetPostInitFns = function(self, kind, id)
		if not H.attached then
			attach_spawn_listener()
		end
		if kind == "StateGraphPostInit" then
			H.sg_asked = H.sg_asked + 1
			local list = sg_hooks[id]
			if list ~= nil then
				return list
			end
		end
		return {}
	end

	-- stategraph.lua also asks for mod states / events; this loader has none to give
	if type(ModManager.GetPostInitData) == "function" then
		H.orig.GetPostInitData = ModManager.GetPostInitData
		ModManager.GetPostInitData = function()
			return {}
		end
	end

	-- gamelogic.lua, RegisterAllPrefabs: after the game's own prefabs, each load
	H.orig.RegisterPrefabs = ModManager.RegisterPrefabs
	ModManager.RegisterPrefabs = function(self)
		H.register_calls = H.register_calls + 1
		attach_spawn_listener()
		for i = 1, #L.loaded do
			local mod = L.loaded[i]
			local ok, err = xpcall(mod_register_prefabs, traceback, mod.env)
			if not ok then
				L.errors = L.errors + 1
				log("error in " .. mod.name .. " (registering its assets / prefabs): " .. tostring(err))
			end
		end
		-- a later load in the same session, and the end of Start() never came by
		if H.register_calls > 1 and not H.postenv_ran and not H.postenv_warned then
			H.postenv_warned = true
			log("WARNING: " .. problems(true)[#problems(true)])
		end
	end

	-- mainfunctions.lua, Check_Mods (end of Start()): only when GAMEPLAY_MODS_ENABLED is set
	H.orig.SetPostEnv = ModManager.SetPostEnv
	ModManager.SetPostEnv = function(self)
		attach_spawn_listener()
		if H.postenv_ran then
			return
		end
		H.postenv_ran = true
		local n = 0
		for i = 1, #L.loaded do
			local env = L.loaded[i].env
			env.TheFrontEnd = g("TheFrontEnd")
			env.TheSim = g("TheSim")
			env.Point = g("Point")
			env.TheGlobalInstance = g("TheGlobalInstance")
			local fns = env.postinitfns.GamePostInit
			for j = 1, #fns do
				n = n + 1
				guard0(fns[j])
			end
		end
		if settings.verbose then
			log("game post-init: " .. n .. " functions ran")
		end
		local wrong = problems(true)
		for _, p in ipairs(wrong) do
			log("WARNING: " .. p)
			L.notices[#L.notices + 1] = p
		end
		if settings.notices and #L.notices > 0 and at_main_menu() then
			local body = table.concat(L.notices, "\n\n")
			L.notices = {}
			L.problems_shown = #wrong > 0
			show_notice(#wrong > 0 and "Mods may not work" or "A mod did not load", body .. "\n\nDetails are in client_log.txt.")
		end
	end
end

-- ---------------------------------------------------------------------------------
-- a mod's environment (the same names the game's own mods.lua / modutil.lua give)
-- ---------------------------------------------------------------------------------
local function handler(env, what, fn)
	if type(fn) ~= "function" then
		error(what .. ": a function is expected, got " .. type(fn), 3)
	end
	return { fn = fn, mod = env.modname, what = what }
end

local function class_post_construct(classdef, fn)
	local constructor = classdef._ctor
	classdef._ctor = function(self, ...)
		constructor(self, ...)
		fn(self, ...)
	end
end

local function create_environment(modname, info)
	local env = {
		-- lua
		pairs = pairs,
		ipairs = ipairs,
		print = print,
		math = math,
		table = table,
		type = type,
		string = string,
		tostring = tostring,
		require = require,
		Class = g("Class"),

		-- runtime
		TUNING = g("TUNING"),

		-- utility
		GLOBAL = G,
		modname = modname,
		MODROOT = MODS_ROOT .. modname .. "/",
		modinfo = info,

		Prefab = g("Prefab"),
		Asset = g("Asset"),
		ReleaseID = type(g("ReleaseID")) == "table" and g("ReleaseID").IDs or nil,
		CurrentRelease = g("CurrentRelease"),
	}
	env.env = env

	env.modimport = function(modulename)
		if settings.verbose then
			log("modimport: " .. env.MODROOT .. tostring(modulename))
		end
		if string.sub(modulename, #modulename - 3, #modulename) ~= ".lua" then
			modulename = modulename .. ".lua"
		end
		local result = kleiloadlua(env.MODROOT .. modulename)
		if result == nil then
			error("Error in modimport: " .. modulename .. " not found!")
		elseif type(result) == "string" then
			error("Error in modimport: " .. modname .. " importing " .. modulename .. "!\n" .. result)
		else
			set_env(result, env)
			result()
		end
	end

	env.modassert = function(test, message)
		if not test then
			log("MOD ERROR: " .. modname .. ": " .. tostring(message))
		end
		return test
	end
	env.moderror = function(message)
		log("MOD ERROR: " .. modname .. ": " .. tostring(message))
	end

	env.GetModConfigData = function(optionname)
		local options = type(info) == "table" and info.configuration_options or nil
		if type(options) == "table" then
			for _, v in pairs(options) do
				if type(v) == "table" and v.name == optionname then
					return v.default
				end
			end
		end
		return nil
	end

	local post = {
		GamePostInit = {},
		PrefabPostInit = {},
		PrefabPostInitAny = {},
		ComponentPostInit = {},
		StateGraphPostInit = {},
	}
	env.postinitfns = post
	env.postinitdata = {}

	-- the end of the game's Start() (the room is loaded; the players may be too)
	env.AddGamePostInit = function(fn)
		post.GamePostInit[#post.GamePostInit + 1] = handler(env, "AddGamePostInit", fn)
	end

	env.AddClassPostConstruct = function(package_name, fn)
		local classdef = require(package_name)
		if type(classdef) ~= "table" then
			error("AddClassPostConstruct: '" .. tostring(package_name) .. "' doesn't seem to return a valid class.", 2)
		end
		class_post_construct(classdef, fn)
	end

	env.AddGlobalClassPostConstruct = function(package_name, classname, fn)
		require(package_name)
		local classdef = rawget(G, classname)
		if classdef == nil then
			classdef = require(package_name)
		end
		if type(classdef) ~= "table" then
			error("AddGlobalClassPostConstruct: '" .. tostring(classname) .. "' wasn't loaded to global from '" .. tostring(package_name) .. "'.", 2)
		end
		class_post_construct(classdef, fn)
	end

	env.AddStateGraphPostInit = function(stategraph, fn)
		local h = handler(env, "AddStateGraphPostInit " .. tostring(stategraph), fn)
		post.StateGraphPostInit[stategraph] = post.StateGraphPostInit[stategraph] or {}
		table.insert(post.StateGraphPostInit[stategraph], h)
		sg_hooks[stategraph] = sg_hooks[stategraph] or {}
		table.insert(sg_hooks[stategraph], function(sg)
			guard1(h, sg)
		end)
	end

	env.AddComponentPostInit = function(component, fn)
		local h = handler(env, "AddComponentPostInit " .. tostring(component), fn)
		if not ensure_component_hook() then
			error("AddComponentPostInit: the game's EntityScript.AddComponent is gone", 2)
		end
		post.ComponentPostInit[component] = post.ComponentPostInit[component] or {}
		table.insert(post.ComponentPostInit[component], h)
		component_hooks[component] = component_hooks[component] or {}
		table.insert(component_hooks[component], h)
	end

	env.AddPrefabPostInitAny = function(fn)
		local h = handler(env, "AddPrefabPostInitAny", fn)
		post.PrefabPostInitAny[#post.PrefabPostInitAny + 1] = h
		any_hooks[#any_hooks + 1] = h
		H.any_plain = H.any_plain + 1
		attach_spawn_listener()
	end

	env.AddPlayerPostInit = function(fn)
		local h = handler(env, "AddPlayerPostInit", fn)
		h.player = true
		post.PrefabPostInitAny[#post.PrefabPostInitAny + 1] = h
		any_hooks[#any_hooks + 1] = h
		attach_spawn_listener()
	end

	env.AddPrefabPostInit = function(prefab, fn)
		local h = handler(env, "AddPrefabPostInit " .. tostring(prefab), fn)
		post.PrefabPostInit[prefab] = post.PrefabPostInit[prefab] or {}
		table.insert(post.PrefabPostInit[prefab], h)
		prefab_hooks[prefab] = prefab_hooks[prefab] or {}
		table.insert(prefab_hooks[prefab], h)
		attach_spawn_listener()
	end

	env.RemapSoundEvent = function(name, new_name)
		g("TheAudio"):RemapSoundEvent(name, new_name)
	end

	return env
end

-- ---------------------------------------------------------------------------------
-- finding the mods
-- ---------------------------------------------------------------------------------
local function trim_lower(s)
	return (string.gsub(string.lower(tostring(s)), "^%s*(.-)%s*$", "%1"))
end

local function find_mods()
	local dirs_kind = 2 -- util/listfilesenum.lua: DIRS
	local ok_enum, enum = pcall(require, "util.listfilesenum")
	if ok_enum and type(enum) == "table" and type(enum.DIRS) == "number" then
		dirs_kind = enum.DIRS
	end
	local ok, dirs = pcall(TheSim.ListFiles, TheSim, MODS_ROOT, "*", dirs_kind)
	if not ok or type(dirs) ~= "table" then
		log("could not list " .. MODS_ROOT .. " (" .. tostring(dirs) .. "): no mods loaded")
		return {}
	end
	local names = {}
	for _, d in ipairs(dirs) do
		if type(d) == "string" and d ~= "" then
			names[#names + 1] = d
		end
	end
	table.sort(names)

	local disabled = {}
	for _, n in ipairs(settings.disabled_mods) do
		disabled[tostring(n)] = true
	end

	local api = type(g("MOD_API_VERSION")) == "number" and g("MOD_API_VERSION") or 1
	local found = {}
	for _, name in ipairs(names) do
		local rec = { name = name }
		L.mods[#L.mods + 1] = rec
		local info, why = read_data_file(MODS_ROOT .. name .. "/modinfo.lua")
		if info == nil then
			if why == "missing" then
				rec.status = "not a mod (no modinfo.lua)"
			else
				rec.status = "failed"
				rec.error = "modinfo.lua: " .. tostring(why)
			end
		else
			rec.version = info.version
			local kind = trim_lower(info.mod_type or "")
			if kind == "translation" then
				rec.status = "translation (the game loads it)"
			elseif disabled[name] then
				rec.status = "disabled (nativeloader_settings.lua)"
			elseif type(info.supports_mode) ~= "table" or not info.supports_mode.rotwood then
				rec.status = "skipped (modinfo.lua: supports_mode.rotwood is not set)"
			elseif type(info.api_version) == "number" and info.api_version > api then
				rec.status = "failed"
				rec.error = "modinfo.lua: api_version " .. tostring(info.api_version) .. " is newer than the game's " .. tostring(api)
			else
				rec.info = info
				found[#found + 1] = rec
			end
		end
	end

	-- the game's order: higher priority first, then by the mod's display name, descending
	table.sort(found, function(a, b)
		local ap = type(a.info.priority) == "number" and a.info.priority or 0
		local bp = type(b.info.priority) == "number" and b.info.priority or 0
		if ap == bp then
			local an, bn = tostring(a.info.name), tostring(b.info.name)
			if an == bn then
				return a.name > b.name
			end
			return an > bn
		end
		return ap > bp
	end)
	return found
end

-- ---------------------------------------------------------------------------------
-- game scripts found in one step (optional)
-- ---------------------------------------------------------------------------------
-- The mods' folders sit in front of the game's in package.path (that order also decides
-- which art file wins, so it stays). For scripts it means the game's own loader looks in
-- every mod folder before it finds a game file. This searcher runs just before the
-- game's: a file the game has is returned straight away, anything else is left to the
-- game's loader, unchanged.
local function install_fast_require()
	if not settings.fast_require then
		return false
	end
	local searchers = package.searchers
	if type(searchers) ~= "table" or type(searchers[2]) ~= "function" then
		return false
	end
	local reload = g("RequiredFilesForReload")
	table.insert(searchers, 2, function(modulename)
		local filename = "scripts/" .. string.gsub(string.gsub(modulename, "%.", "/"), "\\", "/") .. ".lua"
		local result = kleiloadlua(filename)
		if result then
			if type(reload) == "table" and type(TheSim.GetFileModificationTime) == "function" then
				reload[filename] = TheSim:GetFileModificationTime(filename)
			end
			return result
		end
		return "\n\tno file '" .. filename .. "' (Native Loader: game scripts first)"
	end)
	return true
end

-- ---------------------------------------------------------------------------------
-- go
-- ---------------------------------------------------------------------------------
local function start()
	if settings_error ~= nil then
		L.notices[#L.notices + 1] = "nativeloader_settings.lua could not be read; the defaults are used."
	end

	local found = find_mods()

	-- before any mod runs: a mod may wrap these itself (Fast Load wraps RegisterPrefabs)
	install_modmanager_hooks()

	for _, rec in ipairs(found) do
		local name = rec.name
		local env = create_environment(name, rec.info)
		rec.env = env
		L.loaded[#L.loaded + 1] = rec
		-- the game's own list of mods (its crash report and the mods themselves read it)
		if type(ModManager.modnames) == "table" then table.insert(ModManager.modnames, name) end
		if type(ModManager.mods) == "table" then table.insert(ModManager.mods, env) end
		if type(ModManager.enabledmods) == "table" then table.insert(ModManager.enabledmods, name) end
		ModManager.currentlyloadingmod = name

		-- the mod's scripts folder joins the game's search path (scripts, and art by the game's rule)
		package.path = MODS_ROOT .. name .. "\\scripts\\?.lua;" .. package.path

		local fn = kleiloadlua(MODS_ROOT .. name .. "/modmain.lua")
		if fn == nil then
			rec.status = "no modmain.lua"
		elseif type(fn) ~= "function" then
			rec.status = "failed"
			rec.error = tostring(fn)
		else
			set_env(fn, env)
			local ok, err = xpcall(fn, traceback)
			if ok then
				rec.status = "loaded"
			else
				rec.status = "failed"
				rec.error = tostring(err)
			end
		end
		ModManager.currentlyloadingmod = nil
	end

	if #L.loaded > 0 then
		-- the game's own switch for its mod calls (Check_Mods -> ModManager:SetPostEnv)
		rawset(G, "GAMEPLAY_MODS_ENABLED", true)
		L.fast_require = install_fast_require()
	end

	-- report
	local ok_list, failed = {}, 0
	for _, rec in ipairs(L.mods) do
		if rec.status == "loaded" then
			ok_list[#ok_list + 1] = rec.name .. " " .. tostring(rec.version or "?")
		elseif rec.status == "failed" then
			failed = failed + 1
			log("FAILED " .. rec.name .. ": " .. tostring(rec.error))
			L.notices[#L.notices + 1] = rec.name .. " did not load."
		elseif settings.verbose or string.sub(tostring(rec.status), 1, 8) == "disabled" then
			log(rec.name .. ": " .. tostring(rec.status))
		end
	end
	table.sort(ok_list)
	log(VERSION .. ": " .. #ok_list .. " mods loaded" .. (failed > 0 and (", " .. failed .. " FAILED") or "")
		.. (#ok_list > 0 and (": " .. table.concat(ok_list, ", ")) or ""))
	L.started = true
end

function L.Report()
	local lines = { "Native Loader " .. VERSION .. ": " .. #L.loaded .. " mods run, " .. L.errors .. " callback errors" }
	for _, rec in ipairs(L.mods) do
		lines[#lines + 1] = "  " .. rec.name .. " " .. tostring(rec.version or "") .. ": " .. tostring(rec.status)
			.. (rec.error and (" (" .. string.match(tostring(rec.error), "^[^\n]*") .. ")") or "")
	end
	for _, p in ipairs(problems(H.postenv_ran)) do
		lines[#lines + 1] = "  PROBLEM: " .. p
	end
	return table.concat(lines, "\n")
end

local ok, err = xpcall(start, traceback)
if not ok then
	log(VERSION .. ": stopped by an error of its own, the mods loaded so far stay: " .. tostring(err))
	L.started = true
	L.notices[#L.notices + 1] = "The mod loader hit an error while loading the mods."
end
return L
