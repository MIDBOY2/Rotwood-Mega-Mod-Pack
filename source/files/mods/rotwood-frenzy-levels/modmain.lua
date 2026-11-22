-- Frenzy Levels (Rotwood build 760548)
-- Pick a main hunt's Frenzy level (1-5) on the map with LB / RB (Q / E).
-- Settings: scripts/frenzylevels_settings.lua

local pcall, require, print = GLOBAL.pcall, GLOBAL.require, GLOBAL.print

local FL = require "frenzylevels"

-- the Super Frenzy side hunt map marker shield (images/frenzylevels_markers)
Assets = {
	Asset("ATLAS", "images/frenzylevels_markers.xml"),
	Asset("IMAGE", "images/frenzylevels_markers.tex"),
}

local ok_s, settings = pcall(require, "frenzylevels_settings")
if not ok_s or type(settings) ~= "table" then
	print(FL.TAG .. " frenzylevels_settings.lua has an error, using the defaults: " .. tostring(settings))
	settings = {}
end
settings = FL.Configure(settings)
if settings.enabled == false then
	print(FL.TAG .. " off (enabled = false in frenzylevels_settings.lua)")
	return
end

-- cosmetic armour chances (works by itself)
local tuning = GLOBAL.rawget(GLOBAL, "TUNING")
local ok_c, c_ok, c_info = pcall(FL.InstallCosmetics, tuning)
FL.cosmetic_info = ok_c and c_ok and c_info or ("cosmetic armour: the game's chances" ..
	((not ok_c or c_info ~= "the game's") and (" (" .. tostring(ok_c and c_info or c_ok) .. ")") or ""))

-- more corestones in the side hunts you frenzy yourself (works by itself)
local ok_cd, CraftingDropManager = pcall(require, "components.craftingdropmanager")
local ok_cs, cs_ok, cs_info = pcall(FL.InstallCorestones, ok_cd and CraftingDropManager or nil)
FL.corestone_info = ok_cs and cs_info or ("the game's corestones (" .. tostring(cs_ok) .. ")")
if ok_cs and not cs_ok and cs_info ~= "the game's corestones" then
	print(FL.TAG .. " " .. tostring(cs_info))
end

-- Super Frenzy 1 to 5 on the side hunts you frenzy yourself (an experiment):
-- the game's Super Frenzy levels, every fight room hard, loot x1.5 to x2.5;
-- main hunts at Super Frenzy: loot x1.5 to x2.5 too, more hard rooms by gear
-- level (0.10.0); weather side hunts at Super Frenzy too (frenzylevels/superside.lua)
local SS
local function InstallSuperSide()
	if SS ~= nil and SS.installed then
		return true
	end
	local ok_r, SuperSide = pcall(require, "frenzylevels.superside")
	if not ok_r or type(SuperSide) ~= "table" then
		FL.superside_info = "Super Frenzy side hunts off (" .. tostring(SuperSide) .. ")"
		return false
	end
	SS = SuperSide
	FL.SS = SS -- (rewards.lua: is this run a Super Frenzy side hunt)
	local ok, s_ok, s_info = pcall(function()
		local function Req(name)
			local ok_m, m = pcall(require, name)
			return ok_m and m or nil
		end
		return SS.Install(FL, {
			G = GLOBAL,
			MapGenHelp = Req("util.mapgenhelp"),
			LootEvents = Req("lootevents"),
			Consumable = Req("defs.consumable"),
			CraftingDropManager = Req("components.craftingdropmanager"),
			AscensionManager = Req("components.ascensionmanager"),
			WorldMap = Req("components.worldmap"),
			biomes = Req("defs.biomes"),
			playerutil = Req("util.playerutil"),
			KonjurRewardManager = Req("components.konjurrewardmanager"),
			Power = Req("defs.powers"),
			craftingutil = Req("util.craftingutil"),
			Equipment = Req("defs.equipment"),
		})
	end)
	SS.installed = ok and s_ok == true
	FL.superside_info = ok and tostring(s_info) or ("Super Frenzy side hunts off (" .. tostring(s_ok) .. ")")
	return SS.installed
end
if (settings.side_hunts ~= false and settings.super_side_hunts ~= false) or settings.super_main_loot ~= false or settings.super_main_hard ~= false then
	InstallSuperSide()
	AddPrefabPostInit("dungeon", function(inst)
		-- (only when WorldMap:StartRun couldn't be hooked: that one is earlier)
		if SS ~= nil and SS.installed and not SS.early_start and inst.ListenForEvent ~= nil then
			inst:ListenForEvent("start_new_run", function(_, params)
				local ok, err = pcall(SS.OnStartRun, params)
				if not ok then
					print(FL.TAG .. " Super Frenzy side hunt start: " .. tostring(err))
				end
			end)
		end
	end)
else
	FL.superside_info = "Super Frenzy side hunts off"
end

-- the Frenzy look (the hunt's normal colours in a frenzy)
FL.look_info = FL.LookInfo()
if settings.frenzy_look == false or settings.super_frenzy_look == false or settings.side_hunts ~= false then
	local ok_p, presets = pcall(require, "prefabs.lighting_autogen_data")
	if ok_p and type(presets) == "table" then
		AddPrefabPostInit("dungeon", function(inst)
			local ok_w, err = pcall(FL.WrapLighting, inst, presets)
			if not ok_w then
				print(FL.TAG .. " frenzy colours: the game's (" .. tostring(err) .. ")")
			end
		end)
	else
		FL.look_info = "the game's frenzy colours (lighting presets not found: " .. tostring(presets) .. ")"
	end
end

-- the save side now (the game loads the town's save before any player spawns)
local ok_am, AscensionManager = pcall(require, "components.ascensionmanager")
local am_ok, am_info = false, tostring(AscensionManager)
if ok_am and type(AscensionManager) == "table" then
	am_ok, am_info = FL.InstallAscension(AscensionManager)
end
if not am_ok then
	print(FL.TAG .. " off: " .. tostring(am_info))
	return
end

-- the map's widgets when the first player spawns (the game is fully loaded then)
local installed = false
local SK -- the Super Frenzy level skip (0.11.0)
AddPlayerPostInit(function(inst)
	if installed then
		if SK ~= nil and SK.on then
			pcall(SK.SetupPlayer, inst)
		end
		return
	end
	installed = true
	-- 0.11.0: the Super Frenzy level skip on main hunts (frenzylevels/superskip.lua)
	local ok_k, k_ok, k_info = pcall(function()
		local K = require "frenzylevels.superskip"
		local function Req(name)
			local ok_m, m = pcall(require, name)
			return ok_m and m or nil
		end
		SK = K
		return K.Install(FL, {
			AscensionManager = Req("components.ascensionmanager"),
			SuperFrenzySelectionWidget = Req("widgets.ftf.dungeonselection.superfrenzyselectionwidget"),
			DungeonSelectionUtil = Req("widgets.ftf.dungeonselection.dungeonselectionutil"),
			Consumable = Req("defs.consumable"),
			biomes = Req("defs.biomes"),
			Equipment = Req("defs.equipment"),
			STRINGS = GLOBAL.rawget(GLOBAL, "STRINGS"),
		})
	end)
	FL.skip_info = ok_k and tostring(k_info) or ("Super Frenzy level skip off (" .. tostring(k_ok) .. ")")
	if SK ~= nil and SK.on then
		pcall(SK.SetupPlayer, inst)
	end
	if ((settings.side_hunts ~= false and settings.super_side_hunts ~= false) or settings.super_main_loot ~= false) and not (SS ~= nil and SS.installed) then
		if not InstallSuperSide() then
			-- the run side couldn't hook in: no Super Frenzy step on the map either
			FL.settings.super_side_hunts = false
		end
	end
	-- Drakinspawn drops (the Drakin Armoury Pack; works by itself)
	local ok_d, d_ok, d_info = pcall(function()
		local ok_mu, monsterutil = pcall(require, "util.monsterutil")
		local ok_du, dlcutil = pcall(require, "util.dlcutil")
		local ok_ld, LootDropManager = pcall(require, "components.lootdropmanager")
		local ok_eq, Equipment = pcall(require, "defs.equipment")
		return FL.InstallDrakin(ok_mu and monsterutil or nil, ok_du and dlcutil or nil, ok_ld and LootDropManager or nil, ok_eq and Equipment or nil)
	end)
	FL.drakin_info = ok_d and d_info or ("the game's Drakinspawn drops (" .. tostring(d_ok) .. ")")
	local ok_b, b_ok, b_info = pcall(function()
		local ok_ld, LootDropManager = pcall(require, "components.lootdropmanager")
		return FL.InstallBlightMirages(ok_ld and LootDropManager or nil)
	end)
	FL.blight_info = ok_b and b_info or ("the game's Blight mirages (" .. tostring(b_ok) .. ")")
	-- 0.9.0: more for the harder choices (frenzylevels/rewards.lua; each part by itself)
	local ok_r, r_ok, r_info = pcall(function()
		local FR = require "frenzylevels.rewards"
		local function Req(name)
			local ok_m, m = pcall(require, name)
			return ok_m and m or nil
		end
		return FR.Install(FL, {
			WeatherManager = Req("components.weathermanager"),
			WeatherRewards = Req("defs.weatherrewards"),
			playerutil = Req("util.playerutil"),
			Consumable = Req("defs.consumable"),
			ParticleSystemHelper = Req("util.particlesystemhelper"),
			MarketChallengeReward = Req("components.marketchallengereward"),
			rewardutil = Req("util.rewardutil"),
			spawnutil = Req("util.spawnutil"),
			LootDropManager = Req("components.lootdropmanager"),
			LootEvents = Req("lootevents"),
			biomes = Req("defs.biomes"),
		})
	end)
	FL.rewards_info = ok_r and tostring(r_info) or ("the game's rewards (" .. tostring(r_ok) .. ")")
	-- 0.9.2: Corestone drops past the game's limit (frenzylevels/soulcap.lua)
	local ok_sc, sc_ok, sc_info = pcall(function()
		local SC = require "frenzylevels.soulcap"
		local ok_k, konjursouls = pcall(require, "prefabs.customscript.konjursouls")
		local ok_sd, SoulDrop = pcall(require, "components.souldrop")
		return SC.Install(ok_k and konjursouls or nil, ok_sd and SoulDrop or nil)
	end)
	FL.soulcap_info = ok_sc and tostring(sc_info) or ("Corestone drops: the game's (" .. tostring(sc_ok) .. ")")
	local ok_b, biomes = pcall(require, "defs.biomes")
	local ok1, MapSidebar = pcall(require, "widgets.ftf.dungeonselection.mapsidebar")
	local ok2, Marker = pcall(require, "widgets.ftf.dungeonselection.maplocationmarker")
	if not ok_b or not ok1 then
		print(FL.TAG .. " off: couldn't load the map's side panel: " .. tostring(ok_b and MapSidebar or biomes))
		return
	end
	local ok_side, side_info = FL.InstallSidebar(MapSidebar, biomes, GLOBAL.STRINGS)
	if not ok_side then
		print(FL.TAG .. " off: " .. tostring(side_info))
		return
	end
	local ok_m, m_info = false, tostring(Marker)
	if ok2 then
		ok_m, m_info = FL.InstallMarker(Marker, biomes)
	end
	if settings.side_hunts ~= false then
		local ok3, Screen = pcall(require, "screens.town.dungeonselectionscreen")
		local ok_k, k_info = false, tostring(Screen)
		if ok3 then
			ok_k, k_info = FL.InstallScreen(Screen, GLOBAL.rawget(GLOBAL, "Controls"))
		end
		if not ok_k then
			print(FL.TAG .. " the look switch (X) is off: " .. tostring(k_info))
		end
	end
	-- 0.10.3: the gold preview key (every marker gold on the map, visual only)
	local ok_g, g_info = pcall(function()
		local ic = GLOBAL.rawget(GLOBAL, "InputConstants")
		return FL.BindGoldKey(GLOBAL.rawget(GLOBAL, "TheInput"), type(ic) == "table" and ic.Keys or nil)
	end)
	FL.gold_key_info = ok_g and tostring(g_info) or ("no gold preview key (" .. tostring(g_info) .. ")")
	print(string.format("%s on: main hunts Frenzy %d to 5 (LB / RB, Q / E on the map), new hunts start at %d%s%s; %s; %s",
		FL.TAG, settings.min_level, settings.default_level, settings.min_level == 0 and " (0 = Standard)" or "",
		ok_m and "" or ("; map markers keep the game's level until picked: " .. tostring(m_info)),
		settings.side_hunts ~= false and (FL.SuperSideOn() and "side hunts No frenzy to 5, then Super Frenzy 1-5" or "side hunts No frenzy to 5") or "side hunts the game's",
		FL.cosmetic_info .. "; " .. FL.corestone_info .. "; " .. tostring(FL.drakin_info) .. "; " .. tostring(FL.blight_info) .. "; " .. FL.look_info .. "; " .. tostring(FL.superside_info)
			.. "; " .. tostring(FL.rewards_info) .. "; " .. tostring(FL.soulcap_info) .. "; " .. tostring(FL.gold_key_info) .. "; " .. tostring(FL.skip_info)))
end)
