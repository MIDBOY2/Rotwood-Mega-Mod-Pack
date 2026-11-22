-- Armor Dyes 0.5.0 / 0.5.1: the imbued boss looks.
--
-- The bosses' armour and weapons repainted in their imbued (elite) colours: new art
-- made from the game's own boss art (anim/: the game's build files with the sheets
-- repainted, the same symbols), the inventory icons in images/, the list in
-- imbued_data.lua. Two ways to wear them, both in the game's own screens:
--
--  * A dye. "Imbued" comes first in the ARMOUR DYE tab (right after Original
--    colours) for every boss look: each boss armour piece (a Morphic piece showing
--    the boss, or the boss mirage) and each boss weapon. It draws the piece from the
--    imbued art instead of tinting it (the symbol swap the game itself does when it
--    puts armour on), and the piece's inventory icon shows the imbued look.
--  * A mirage pattern. At the mirage station each boss piece you own brings its
--    imbued patterns, for any item of that slot (weapons: of that weapon type), at
--    the usual price.
--
-- Some bosses have more than one imbued look (Treek: Plum; Eggzy: First, Salmon;
-- Grimhollow: Lava, Lava with the magenta glow): those come after "Imbued".
--
-- (0.5.11) Looks for other sets too: imbued Enigmox's colours baked into the Hunter and
-- Bonejaw weapons ("Imbued Enigmox"). Those are dye_only: a dye in the weapon's own list
-- (ARMOUR DYE > WEAPON), no mirage patterns.
--
-- (0.6.0) Baked headbands: the Basic Headband and the Wollusk Helmet II repainted in
-- Enigmox's colours (normal, imbued, his eyes and fur), the other bosses' and the game's
-- colour families. dye_only, and slots = { "HEAD" }: the art is the helmet's only, so the
-- look is a dye in the helmet's list and never on the body or legs of that set.
--
-- Saves only ever hold the game's own names. A dye is saved like any dye (the game
-- skips dyes it doesn't know). An imbued mirage is saved as the boss's own mirage
-- plus a note the game ignores (armordyes_look), and put back on load: without the
-- mod the piece shows the normal boss look, nothing goes missing.
--
-- (0.5.1) The art loads with the game's own per-area asset lists, not with the mod:
-- the game packs every loaded sheet into one texture pool with a hard cap (190), and
-- a hunt's start room already fills ~177 of it. In town all imbued art loads (the
-- mirror's and the mirage station's previews); in a hunt only the imbued pieces the
-- hunters wear (worked out when the game leaves for the next area, carried in its
-- own load settings). A piece whose art isn't loaded where it is shows the normal
-- boss look (never an empty slot), the next area loads it.

local Cosmetic = require "defs.cosmetics.cosmetics"
local Equipment = require "defs.equipment"
local Main = require "armordyes.main"

local Imbued = {}

Imbued.ARMOUR_SLOTS = { "HEAD", "BODY", "WAIST" }
Imbued.WEAPON = "WEAPON"
Imbued.SAVE_KEY = "armordyes_look"
Imbued.ORDER_STEP = 0.01 -- alt looks after "Imbued", all before the colour dyes (1, 2...)

Imbued.settings = nil
Imbued.looks = {} -- the looks in use (imbued_data.lua, the art found)
Imbued.missing = {} -- builds not found in anim/
Imbued.icons_ok = false
Imbued.info = {} -- slot -> imbued piece name -> info (slot, base, boss, key, label, def)
Imbued.boss_of = {} -- imbued piece name -> boss (armour pieces share a name across slots, like the game's)
Imbued.by_slot = {} -- slot -> { imbued defs, in list order }
Imbued.swap_sets = {} -- slot -> { [base set] = true } (sets with an imbued dye)
Imbued.defs = 0
Imbued.dyes = 0
Imbued.saves_hooked = false
Imbued.mirage_on = false
Imbued.art = {} -- build -> "anim/<build>.zip" (the art found)
Imbued.art_list = {} -- the builds, sorted
Imbued.art_on = false -- loaded per area (the game's asset lists) works
Imbued.ART_PREFIX = "armordyes_imbued_" -- one asset prefab per build
Imbued.SETTINGS_KEY = "armordyes_imbued" -- the builds the next area needs, in the game's load settings
Imbued.WORN_SLOTS = { "HEAD", "BODY", "WAIST", "WEAPON" }

local function Log(msg)
	Main.Log(msg)
end

-- a file of the mod (or the game) the engine can find
local function FileExists(path)
	local fn = rawget(_G, "softresolvefilepath")
	if type(fn) ~= "function" then
		return true -- (can't check here: trust the install)
	end
	local ok, found = pcall(fn, path)
	return ok and found ~= nil
end

local function Copy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local c = {}
	seen[t] = c
	for k, v in pairs(t) do
		c[Copy(k, seen)] = Copy(v, seen)
	end
	return setmetatable(c, getmetatable(t))
end

----------------------------------------------------------------------------
-- The art (modmain, before anything else)

-- Returns the assets to load with the mod (modmain's Assets: the icons only; the
-- builds load per area, below), or nil and why not.
function Imbued.Prepare(settings)
	Imbued.settings = settings
	if settings.imbued == false then
		return nil, "imbued looks off in the settings"
	end
	local ok, data = pcall(require, "armordyes.imbued_data")
	if not ok or type(data) ~= "table" or type(data.looks) ~= "table" then
		return nil, "imbued_data.lua: " .. tostring(data)
	end
	local Asset = rawget(_G, "Asset")
	if type(Asset) ~= "table" and type(Asset) ~= "function" then
		return nil, "the game's Asset is missing"
	end
	local assets = {}
	local found = {}
	local function Anim(build)
		if found[build] == nil then
			found[build] = FileExists("anim/" .. build .. ".zip")
			if found[build] then
				Imbued.art[build] = "anim/" .. build .. ".zip"
				Imbued.art_list[#Imbued.art_list + 1] = build
			else
				Imbued.missing[#Imbued.missing + 1] = build
			end
		end
		return found[build]
	end

	-- the icons: only when every atlas is there (a missing one would stop the game
	-- when a screen shows it)
	local icons = settings.imbued_icons ~= false and type(data.atlases) == "table" and #data.atlases > 0
	if icons then
		for _, name in ipairs(data.atlases) do
			if type(name) ~= "string" or not FileExists("images/" .. name .. ".xml") or not FileExists("images/" .. name .. ".tex") then
				icons = false
				Log("imbued icons off: images/" .. tostring(name) .. " is missing")
			end
		end
	end
	if icons then
		for _, name in ipairs(data.atlases) do
			assets[#assets + 1] = Asset("ATLAS", "images/" .. name .. ".xml")
			assets[#assets + 1] = Asset("IMAGE", "images/" .. name .. ".tex")
		end
	end
	Imbued.icons_ok = icons

	for _, look in ipairs(data.looks) do
		if type(look) == "table" and type(look.boss) == "string" and type(look.key) == "string"
			and (not look.alt or settings.imbued_alt_looks ~= false)
			and (not look.ref or settings.imbued_reference_looks == true) then -- (0.5.9) reference looks: off unless asked
			local use = {
				boss = look.boss,
				key = look.key,
				label = type(look.label) == "string" and look.label or "Imbued",
				alt = look.alt == true,
				dye_only = look.dye_only == true, -- (0.5.11) a dye only: no mirage patterns
				icons = type(look.icons) == "table" and look.icons or {},
				weapons = {},
			}
			if type(look.armour) == "string" and Anim(look.armour) then
				use.armour = look.armour
			end
			-- (0.6.0) the armour slots the art has (a headband: the helmet only); none named: all three
			if type(look.slots) == "table" then
				local slots = {}
				for _, s in ipairs(look.slots) do
					for _, known in ipairs(Imbued.ARMOUR_SLOTS) do
						if s == known then
							slots[#slots + 1] = s
						end
					end
				end
				use.slots = slots
			end
			for wtype, build in pairs(type(look.weapons) == "table" and look.weapons or {}) do
				if type(build) == "string" and Anim(build) then
					use.weapons[wtype] = build
				end
			end
			if use.armour ~= nil or next(use.weapons) ~= nil then
				Imbued.looks[#Imbued.looks + 1] = use
			end
		end
	end
	if #Imbued.missing > 0 then
		Log("imbued art missing (those looks left out): " .. table.concat(Imbued.missing, ", "))
	end
	if #Imbued.looks == 0 then
		return nil, "no imbued art found in anim/"
	end
	table.sort(Imbued.art_list)
	return assets
end

----------------------------------------------------------------------------
-- The art per area, through the game's own asset lists (gamelogic.lua LoadAssets,
-- assetloader.lua): each build is an asset prefab of its own, registered with the
-- game's prefabs and put in the area's list when the area needs it. The game loads
-- and unloads it with the area (and packs it then, like its own art).

function Imbued.ArtPrefab(build)
	return Imbued.ART_PREFIX .. build
end

-- Registers the builds' asset prefabs (each time the game registers its prefabs).
function Imbued.RegisterArt()
	local register, Prefab, Asset = rawget(_G, "RegisterPrefabs"), rawget(_G, "Prefab"), rawget(_G, "Asset")
	if register == nil or Prefab == nil or Asset == nil then
		return 0
	end
	local n = 0
	for _, build in ipairs(Imbued.art_list) do
		local ok, err = pcall(register, Prefab(Imbued.ArtPrefab(build), nil, { Asset("ANIM", Imbued.art[build]) }, nil, true))
		if ok then
			n = n + 1
		else
			Log("imbued art " .. build .. " not registered: " .. tostring(err))
		end
	end
	return n
end

-- The imbued build a look shows on this character (an imbued piece, or a look with
-- its Imbued dye), or nil.
function Imbued.LookBuild(owner, slot, id)
	local items = Equipment.Items[slot]
	local def = items ~= nil and type(id) == "string" and items[id] or nil
	if def == nil then
		return nil
	end
	if def.armordyes_imbued ~= nil then
		return def.build
	end
	local dye = Imbued.ActiveSwap(owner, slot, id)
	return dye ~= nil and dye.armordye_build or nil
end

-- The imbued builds the hunters wear now: every hunter's drawn pieces, the pieces of
-- each of their loadouts (one switched to during the hunt) and Two Weapons' other
-- weapon. Sorted (the same list wherever it's asked for).
function Imbued.WornBuilds()
	local out, seen = {}, {}
	local function Add(build)
		if type(build) == "string" and Imbued.art[build] ~= nil and not seen[build] then
			seen[build] = true
			out[#out + 1] = build
		end
	end
	local function AddItem(p, slot, item)
		if type(item) == "table" and type(item.GetItemAppearanceID) == "function" then
			local ok, id = pcall(item.GetItemAppearanceID, item)
			if ok then
				Add(Imbued.LookBuild(p, slot, id))
			end
		end
	end
	local players = rawget(_G, "AllPlayers")
	for _, p in ipairs(type(players) == "table" and players or {}) do
		local comps = type(p) == "table" and p.components or nil
		local inv = comps ~= nil and comps.inventory or nil
		local hoard = comps ~= nil and comps.inventoryhoard or nil
		for _, slot in ipairs(Imbued.WORN_SLOTS) do
			if inv ~= nil and type(inv.equips) == "table" then
				Add(Imbued.LookBuild(p, slot, inv.equips[slot]))
			end
			if hoard ~= nil and type(hoard.data) == "table" and type(hoard.data.loadouts) == "table"
				and type(hoard.GetLoadoutItem) == "function" then
				for index in pairs(hoard.data.loadouts) do
					local ok, item = pcall(hoard.GetLoadoutItem, hoard, index, slot)
					if ok then
						AddItem(p, slot, item)
					end
				end
			end
		end
		local tw = comps ~= nil and comps.twoweapons or nil
		if tw ~= nil and type(tw.GetOther) == "function" then
			local ok, item = pcall(tw.GetOther, tw)
			if ok then
				AddItem(p, Imbued.WEAPON, item)
			end
		end
	end
	table.sort(out)
	return out
end

-- The asset prefabs an area loads: in town all (previews), elsewhere the builds the
-- hunters wore when the game left the last area (settings[SETTINGS_KEY]).
function Imbued.PrefabsFor(settings)
	if not Imbued.art_on or type(settings) ~= "table" then
		return {}
	end
	local actions = rawget(_G, "RESET_ACTION")
	local builds
	if type(actions) == "table" and actions.LOAD_TOWN_ROOM ~= nil and settings.reset_action == actions.LOAD_TOWN_ROOM then
		builds = Imbued.art_list
	else
		builds = type(settings[Imbued.SETTINGS_KEY]) == "table" and settings[Imbued.SETTINGS_KEY] or {}
	end
	local out = {}
	for _, build in ipairs(builds) do
		if type(build) == "string" and Imbued.art[build] ~= nil then
			out[#out + 1] = Imbued.ArtPrefab(build)
		end
	end
	return out
end

-- Is this build's art loaded in this area? (the game's list of what it loaded)
local loaded_from, loaded = nil, {}
function Imbued.IsArtLoaded(build)
	if not Imbued.art_on or type(build) ~= "string" or Imbued.art[build] == nil then
		return false
	end
	local params = rawget(_G, "InstanceParams")
	local s = type(params) == "table" and params.settings or nil
	if type(s) == "table" and s.last_asset_set == "FRONTEND" then
		-- (0.5.4) the main menu: what its character cards loaded (Imbued.LoadForFrontEnd)
		return Imbued.fe_loaded[Imbued.ArtPrefab(build)] == true
	end
	local list = type(s) == "table" and s.last_asset_set == "BACKEND" and s.last_back_end_prefabs or nil
	if type(list) ~= "table" then
		return false
	end
	if loaded_from ~= list then
		loaded_from, loaded = list, {}
		for _, name in ipairs(list) do
			loaded[name] = true
		end
	end
	return loaded[Imbued.ArtPrefab(build)] == true
end

function Imbued.HookArtLoading()
	local mods = rawget(_G, "ModManager")
	local start = rawget(_G, "StartNextInstance")
	local ok_a, AssetLoader = pcall(require, "assetloader")
	if type(mods) ~= "table" or type(mods.RegisterPrefabs) ~= "function" then
		return false, "ModManager:RegisterPrefabs changed"
	end
	if type(start) ~= "function" then
		return false, "StartNextInstance changed"
	end
	if not ok_a or type(AssetLoader) ~= "table" or type(AssetLoader.BuildBackendPrefabsList) ~= "function" then
		return false, "AssetLoader.BuildBackendPrefabsList changed"
	end
	-- registered with the mods' prefabs (the game registers them again after it
	-- clears its prefab list)
	local register = mods.RegisterPrefabs
	rawset(mods, "RegisterPrefabs", function(self, ...)
		local r = table.pack(register(self, ...))
		local ok, n = pcall(Imbued.RegisterArt)
		if not ok then
			Log("imbued art not registered: " .. tostring(n))
		end
		return table.unpack(r, 1, r.n)
	end)
	-- leaving for the next area: what the hunters wear goes into the game's load
	-- settings (they're carried into the next area, like its own)
	rawset(_G, "StartNextInstance", function(settings, ...)
		if type(settings) == "table" then
			local ok, worn = pcall(Imbued.WornBuilds)
			settings[Imbued.SETTINGS_KEY] = ok and worn or {}
			if not ok then
				Log("imbued art for the next area skipped: " .. tostring(worn))
			end
		end
		return start(settings, ...)
	end)
	-- the area's asset list (also the game's prefetch for the next area: the same list)
	local build_list = AssetLoader.BuildBackendPrefabsList
	AssetLoader.BuildBackendPrefabsList = function(settings, ...)
		local list = build_list(settings, ...)
		if type(list) == "table" then
			local ok, extra = pcall(Imbued.PrefabsFor, settings)
			if ok then
				for _, name in ipairs(extra) do
					list[#list + 1] = name
				end
			end
		end
		return list
	end
	Imbued.art_on = true
	local ok_f, why_f = pcall(Imbued.HookFrontEndReset)
	if not ok_f or why_f ~= true then
		Imbued.fe_on = false
		Log("imbued looks on the main menu off (" .. tostring(why_f) .. ")")
	end
	local ok_r, why_r = pcall(Imbued.HookRoomTravel)
	Imbued.room_travel_on = ok_r and why_r == true
	if not Imbued.room_travel_on then
		Log("imbued art between rooms: only at hunt start (" .. tostring(why_r) .. ")")
	end
	return true
end

-- (0.5.3) Merges builds into a sorted list (no repeats).
local function Union(a, b)
	local out, seen = {}, {}
	local function AddAll(list)
		for _, build in ipairs(type(list) == "table" and list or {}) do
			if type(build) == "string" and not seen[build] then
				seen[build] = true
				out[#out + 1] = build
			end
		end
	end
	AddAll(a) -- (either can be nil: a hunt begun without the list)
	AddAll(b)
	table.sort(out)
	return out
end
Imbued.Union = Union

-- (0.5.3) Room to room inside a hunt the game doesn't restart: it loads the next room
-- with the hunt's own load settings. What the hunters wear now is added to them before
-- the room changes (never taken away: what's loaded stays loaded for the hunt), so a
-- hunt that started without an imbued look's art (one begun by an older version of
-- the mod, or straight from the main menu) shows it from the next room on.
-- The game's own calls: Updaters.OverrideSimResetSettings(params) right before a room
-- change (the settings a crash restart would use), UpdateSimResetSettings(params) when
-- a restart is already pending.
function Imbued.HookRoomTravel()
	local ok_u, Updaters = pcall(require, "updaters")
	if not ok_u or type(Updaters) ~= "table" then
		return "updaters not found"
	end
	if type(Updaters.OverrideSimResetSettings) ~= "function" or type(Updaters.UpdateSimResetSettings) ~= "function" then
		return "Updaters.OverrideSimResetSettings changed"
	end
	local function AddWorn(settings)
		if type(settings) ~= "table" then
			return
		end
		local ok, worn = pcall(Imbued.WornBuilds)
		if not ok or type(worn) ~= "table" then
			return
		end
		-- the next room's settings (a restart), and the hunt's own (the next room's load)
		settings[Imbued.SETTINGS_KEY] = Union(settings[Imbued.SETTINGS_KEY], worn)
		local params = rawget(_G, "InstanceParams")
		local cur = type(params) == "table" and params.settings or nil
		if type(cur) == "table" and cur ~= settings then
			cur[Imbued.SETTINGS_KEY] = Union(cur[Imbued.SETTINGS_KEY], worn)
		end
	end
	local override = Updaters.OverrideSimResetSettings
	Updaters.OverrideSimResetSettings = function(settings, ...)
		pcall(AddWorn, settings)
		return override(settings, ...)
	end
	local update = Updaters.UpdateSimResetSettings
	Updaters.UpdateSimResetSettings = function(settings, ...)
		pcall(AddWorn, settings)
		return update(settings, ...)
	end
	return true
end

-- (0.5.3) A worn imbued look whose art isn't loaded in this area: one line in
-- client_log.txt per look per area (the normal boss look is shown).
local missing_logged = {}
function Imbued.ArtLoadedForDraw(build)
	local ok = Imbued.IsArtLoaded(build)
	if not ok and Imbued.art_on and type(build) == "string" and Imbued.art[build] ~= nil and not missing_logged[build] then
		local params = rawget(_G, "InstanceParams")
		local s = type(params) == "table" and params.settings or nil
		if type(s) == "table" and s.last_asset_set == "BACKEND" then
			missing_logged[build] = true
			Log("imbued art not loaded in this area: " .. build .. " (normal look"
				.. (Imbued.room_travel_on and " until the next room)" or " until the next hunt)"))
		end
	end
	return ok
end

----------------------------------------------------------------------------
-- Saves: an imbued mirage is saved as the boss's own look + a note

-- The look saved: the boss's own (the game's name), the imbued one in the note.
-- the imbued piece by slot and name, or nil
function Imbued.Info(slot, name)
	local t = slot ~= nil and Imbued.info[slot] or nil
	return t ~= nil and type(name) == "string" and t[name] or nil
end

function Imbued.ToSave(item, data)
	local id = type(data) == "table" and data.appearance_override_id or nil
	local info = Imbued.Info(data ~= nil and data.slot or nil, id)
	if info == nil then
		return
	end
	data[Imbued.SAVE_KEY] = id
	local ok, default = pcall(item.GetDefaultItemAppearance, item)
	if ok and default == info.base then
		data.appearance_override_id = nil -- the piece shows the boss look by itself (its own, or Morphic)
	else
		data.appearance_override_id = info.base
	end
end

-- The imbued look back on, if the piece still shows that boss look (a look changed
-- while the mod was off stays as it was).
function Imbued.FromSave(item)
	local look = rawget(item, Imbued.SAVE_KEY)
	if look == nil then
		return
	end
	local info = Imbued.Info(rawget(item, "slot"), look)
	if info == nil then
		return -- (not on now: the note stays for when it is)
	end
	rawset(item, Imbued.SAVE_KEY, nil)
	local current = rawget(item, "appearance_override_id")
	local same = current == info.base
	if not same and current == nil then
		local ok, default = pcall(item.GetDefaultItemAppearance, item)
		same = ok and default == info.base
	end
	if same then
		rawset(item, "appearance_override_id", look)
	end
end

function Imbued.HookSaves()
	if Imbued.saves_hooked then
		return true
	end
	local itemforge = require "defs.itemforge"
	if type(itemforge._CreateItem) ~= "function" or type(itemforge.ConvertToRuntimeItem) ~= "function" then
		return false, "itemforge changed"
	end
	-- the game's item class: the metatable of any item it makes
	local probe = itemforge._CreateItem(Imbued.ARMOUR_SLOTS[1], { name = "basic" })
	local mt = getmetatable(probe)
	local ItemInstance = type(mt) == "table" and mt.__index or nil
	if type(ItemInstance) ~= "table" or type(ItemInstance.BuildSaveData) ~= "function" then
		return false, "ItemInstance changed"
	end
	local build_save = ItemInstance.BuildSaveData
	ItemInstance.BuildSaveData = function(self, ...)
		local data = build_save(self, ...)
		local ok, err = pcall(Imbued.ToSave, self, data)
		if not ok then
			Log("imbued look save skipped: " .. tostring(err))
		end
		return data
	end
	local convert = itemforge.ConvertToRuntimeItem
	itemforge.ConvertToRuntimeItem = function(item, ...)
		local r = table.pack(convert(item, ...))
		if type(item) == "table" and rawget(item, Imbued.SAVE_KEY) ~= nil then
			local ok, err = pcall(Imbued.FromSave, item)
			if not ok then
				Log("imbued look load skipped: " .. tostring(err))
			end
		end
		return table.unpack(r, 1, r.n)
	end
	Imbued.ItemInstance = ItemInstance
	Imbued.saves_hooked = true
	return true
end

----------------------------------------------------------------------------
-- The imbued pieces: copies of the boss pieces with the imbued art (hidden from
-- shops, crafting and the game's lists, like its other mirage patterns)

local function PrettyName(base, label)
	local name = base.pretty ~= nil and base.pretty.name or nil
	if type(base.GetPrettyName) == "function" then
		local ok, n = pcall(base.GetPrettyName, base)
		if ok and type(n) == "string" then
			name = n
		end
	end
	if type(name) ~= "string" then
		name = base.name
	end
	return name .. " (" .. label .. ")"
end

local function NewPiece(slot, base, name, build, icon, look)
	local def = Copy(base)
	def.name = name
	def.build = build
	if icon ~= nil then
		def.icon = icon
	end
	def.cosmetic_item = true
	local rarity = rawget(_G, "ITEM_RARITY")
	if type(rarity) == "table" and type(rarity.s) == "table" and rarity.s.COSMETIC ~= nil then
		def.rarity = rarity.s.COSMETIC
	end
	-- a look only: no crafting, upgrades, powers, gems or its own patterns
	def.crafting_data = {}
	def.usage_data = {}
	def.gem_slots = nil
	def.cosmetic_variants = nil
	def.menu_id = nil
	def.alt_item = nil
	def.unlock_icon = nil
	def.ilvl = nil
	def.tags = Copy(base.tags or {})
	def.tags.hide = true -- (shops, the game's item lists and its asset list skip it)
	-- (0.5.3) its own name table, never in the game's STRINGS: the game's language pass
	-- rewrites everything there, and a name it has no line for comes back "MISSING:..."
	def.pretty = {
		name = PrettyName(base, look.label),
		desc = base.pretty ~= nil and base.pretty.desc or "",
	}
	-- the name the game shows (ItemInstance:GetLocalizedName): the boss piece's name as
	-- the game has it now (its language) + the look
	local label = look.label
	def.GetPrettyName = function()
		local ok, n = pcall(PrettyName, base, label)
		return ok and n or def.pretty.name
	end
	def.armordyes_imbued = {
		slot = slot,
		base = base.name,
		boss = look.boss,
		key = look.key,
		label = look.label,
		dye_only = look.dye_only == true or nil,
	}
	return def
end

local function Add(slot, def)
	local items = Equipment.Items[slot]
	items[def.name] = def
	Imbued.info[slot] = Imbued.info[slot] or {}
	Imbued.info[slot][def.name] = def.armordyes_imbued
	Imbued.boss_of[def.name] = def.armordyes_imbued.boss
	def.armordyes_imbued.def = def
	Imbued.by_slot[slot] = Imbued.by_slot[slot] or {}
	table.insert(Imbued.by_slot[slot], def)
	Imbued.defs = Imbued.defs + 1
end

-- the boss weapon of this type (the game's name: "hammer_megatreemon")
local function BossWeapon(boss, wtype)
	local items = Equipment.Items[Imbued.WEAPON]
	local def = items ~= nil and items[wtype:lower() .. "_" .. boss] or nil
	if type(def) == "table" and def.weapon_type == wtype then
		return def
	end
	return nil
end

-- Registers the imbued pieces (and the save hooks first: no imbued name is ever
-- saved). Before Main.Install, so the neutral dyes cover the imbued pieces too.
function Imbued.RegisterDefs()
	local ok, why = Imbued.HookSaves()
	if not ok then
		return false, why
	end
	if not Imbued.HookInventorySave() then
		Log("drawn pieces saved as they are (components.inventory changed)")
	end
	local ok_a, why_a = Imbued.HookArtLoading()
	if not ok_a then
		-- the art never loads: every imbued look shows the normal boss look
		Imbued.art_on = false
		Imbued.art_why = why_a
		Log("imbued art not loaded: " .. tostring(why_a))
	end
	local icons = Imbued.icons_ok
	for _, look in ipairs(Imbued.looks) do
		if look.armour ~= nil then
			for _, slot in ipairs(look.slots or Imbued.ARMOUR_SLOTS) do
				local base = Equipment.Items[slot] ~= nil and Equipment.Items[slot][look.boss] or nil
				local name = look.boss .. "_" .. look.key
				if type(base) == "table" and Equipment.Items[slot][name] == nil then
					Add(slot, NewPiece(slot, base, name, look.armour, icons and look.icons[slot] or nil, look))
				end
			end
		end
		for wtype, build in pairs(look.weapons) do
			local base = BossWeapon(look.boss, wtype)
			local name = base ~= nil and (base.name .. "_" .. look.key) or nil
			if base ~= nil and Equipment.Items[Imbued.WEAPON][name] == nil then
				Add(Imbued.WEAPON, NewPiece(Imbued.WEAPON, base, name, build, icons and look.icons[wtype] or nil, look))
			end
		end
	end
	return Imbued.defs > 0, Imbued.defs > 0 and Imbued.defs or "no boss pieces matched"
end

----------------------------------------------------------------------------
-- The dyes: "Imbued" first in each boss look's list

local function SwapDye(set, slot, look, order, piece)
	return {
		name = Main.PREFIX .. set .. "_" .. look.key .. "_" .. slot,
		short_name = Main.PREFIX .. look.key, -- what equipmentdyer saves
		armour_set = set,
		armour_slot = slot,
		dye_number = order,
		uitags = {},
		filtertags = {},
		armordye_label = look.label,
		armordye_order = order,
		armordye_swap = piece.name,
		armordye_build = piece.build,
		armordye_icon = Imbued.icons_ok and piece.icon or nil,
	}
end

function Imbued.RegisterDyes()
	local orders = {}
	local weapons = false
	for _, slot in ipairs({ "HEAD", "BODY", "WAIST", Imbued.WEAPON }) do
		for _, piece in ipairs(Imbued.by_slot[slot] or {}) do
			local info = piece.armordyes_imbued
			local set = info.base
			local key = slot .. "/" .. set
			local order = orders[key] or 0
			orders[key] = order + Imbued.ORDER_STEP
			local all = Cosmetic.EquipmentDyes[slot] or {}
			Cosmetic.EquipmentDyes[slot] = all
			local list = all[set] or {}
			all[set] = list
			local def = SwapDye(set, slot, info, order, piece)
			list[def.short_name] = def
			Imbued.swap_sets[slot] = Imbued.swap_sets[slot] or {}
			Imbued.swap_sets[slot][set] = true
			Imbued.dyes = Imbued.dyes + 1
			weapons = weapons or slot == Imbued.WEAPON
		end
	end
	if weapons then
		-- the WEAPON sub-tab and the weapon's dye on puppets (also with weapon_dyes = false)
		Main.weapon_on = true
		Main.HookPuppet()
	end
	return Imbued.dyes
end

-- The imbued dye on this look of this character, or nil.
function Imbued.ActiveSwap(owner, slot, set)
	local sets = Imbued.swap_sets[slot]
	if sets == nil or not sets[set] then
		return nil
	end
	local dyer = owner ~= nil and owner.components ~= nil and owner.components.equipmentdyer or nil
	if dyer == nil then
		return nil
	end
	local dye = dyer:GetActiveDye(slot, set)
	return type(dye) == "table" and dye.armordye_swap ~= nil and dye or nil
end

----------------------------------------------------------------------------
-- The weapon's thrown things (shot put ball, arrows, cannon shots) use the drawn
-- weapon's build (Inventory:GetEquippedWeaponDef): an imbued dye gives them the
-- imbued art too. The game reads only build and weapon type from it here, and the
-- imbued piece has the boss weapon's.

function Imbued.HookWeaponDef()
	local Inventory = require "components.inventory"
	if type(Inventory.GetEquippedWeaponDef) ~= "function" then
		return false
	end
	local orig = Inventory.GetEquippedWeaponDef
	Inventory.GetEquippedWeaponDef = function(self, ...)
		local def = orig(self, ...)
		if type(def) ~= "table" then
			return def
		end
		local info = def.armordyes_imbued
		if info ~= nil then
			-- an imbued mirage whose art isn't loaded here: the boss weapon's own
			if not Imbued.IsArtLoaded(def.build) then
				return Equipment.Items[Imbued.WEAPON][info.base] or def
			end
			return def
		end
		if Imbued.swap_sets[Imbued.WEAPON] ~= nil and Imbued.swap_sets[Imbued.WEAPON][def.name] then
			local ok, dye = pcall(Imbued.ActiveSwap, self.inst, Imbued.WEAPON, def.name)
			local piece = ok and dye ~= nil and Equipment.Items[Imbued.WEAPON][dye.armordye_swap] or nil
			if piece ~= nil and Imbued.IsArtLoaded(piece.build) then
				return piece
			end
		end
		return def
	end
	return true
end

-- An imbued piece (a mirage) whose art isn't loaded where it is: drawn as the boss's
-- own piece (the game's art), never an empty slot.
function Imbued.HookDrawFallback()
	local Inventory = require "components.inventory"
	if type(Inventory.OverrideEquipSlotSymbols) ~= "function" then
		return false
	end
	local draw = Inventory.OverrideEquipSlotSymbols
	Inventory.OverrideEquipSlotSymbols = function(self, slot, def, ...)
		local info = type(def) == "table" and def.armordyes_imbued or nil
		if info ~= nil and not Imbued.IsArtLoaded(def.build) then
			local base = Equipment.Items[slot] ~= nil and Equipment.Items[slot][info.base] or nil
			if base ~= nil then
				def = base
			end
		end
		return draw(self, slot, def, ...)
	end
	return true
end

----------------------------------------------------------------------------
-- Icons: a piece showing an imbued look (its dye, or an imbued mirage) shows the
-- imbued icon in the inventory, the mirage station, the loadouts...

function Imbued.IconFor(item, player)
	if not Imbued.icons_ok or type(item) ~= "table" or type(item.GetItemAppearanceID) ~= "function" then
		return nil
	end
	local slot = rawget(item, "slot")
	if slot == nil or (Imbued.info[slot] == nil and Imbued.swap_sets[slot] == nil) then
		return nil -- (materials, potions...: nothing to look at)
	end
	local items = Equipment.Items[slot]
	if items == nil then
		return nil
	end
	local id = item:GetItemAppearanceID()
	local look = type(id) == "string" and items[id] or nil
	if look == nil then
		return nil
	end
	if look.armordyes_imbued ~= nil then
		-- an imbued mirage (an imbued pattern's own entry already has its icon)
		return look ~= item:GetDef() and look.icon or nil
	end
	local runtime = rawget(item, "runtime")
	local hoard = type(runtime) == "table" and runtime.inventoryhoard or nil
	local owner = hoard ~= nil and hoard.inst or player
	local dye = Imbued.ActiveSwap(owner, slot, id)
	return dye ~= nil and dye.armordye_icon or nil
end

local function Wrap(class, name, after)
	local orig = class[name]
	if type(orig) ~= "function" then
		return false
	end
	class[name] = function(self, ...)
		local r = table.pack(orig(self, ...))
		local ok, err = pcall(after, self, ...)
		if not ok then
			Log("imbued icon skipped: " .. tostring(err))
		end
		return table.unpack(r, 1, r.n)
	end
	return true
end

function Imbued.HookIcons()
	local done = {}
	local ok_s, InventorySlot = pcall(require, "widgets.ftf.inventoryslot")
	if ok_s and type(InventorySlot) == "table" and Wrap(InventorySlot, "SetItem", function(self, item, player)
		if item == nil or self.button == nil then
			return
		end
		local icon = Imbued.IconFor(item, player)
		if icon ~= nil then
			local size = (self.size or 0) + (self.item_size or 0)
			self.button:SetTexture(icon)
			if size > 0 then
				self.button:SetSize(size, size)
			end
		end
	end) then
		done[#done + 1] = "inventory slots"
	end
	local ok_w, ItemWidget = pcall(require, "widgets.ftf.itemwidget")
	if ok_w and type(ItemWidget) == "table" and Wrap(ItemWidget, "SetItemInstance", function(self, item)
		if item == nil or self.icon == nil then
			return
		end
		local icon = Imbued.IconFor(item, nil)
		if icon ~= nil then
			self.icon:SetTexture(icon)
			if self.size ~= nil then
				self.icon:SetSize(self.size, self.size)
			end
		end
	end) then
		done[#done + 1] = "item pictures"
	end
	-- (0.5.9, user 04:01: "gem stone icons still don't change") the gem screen's big item
	-- picture (the game draws the item's own unlock icon there, whatever look it wears)
	local ok_g, GemTitle = pcall(require, "widgets.ftf.gemitemtitlewidget")
	if ok_g and type(GemTitle) == "table" and Wrap(GemTitle, "SetItem", function(self, item)
		if item == nil or self.icon == nil then
			return
		end
		local icon = Imbued.IconFor(item, nil)
		if icon ~= nil then
			self.icon:SetTexture(icon)
			if self.icon_size ~= nil then
				self.icon:SetSize(self.icon_size, self.icon_size)
			end
		end
	end) then
		done[#done + 1] = "gem screen"
	end
	return #done > 0, table.concat(done, ", ")
end

----------------------------------------------------------------------------
-- Mirage: the imbued patterns at the mirage station

-- Is this imbued pattern this player's? (needs the boss piece: its weapon, its
-- armour look, or a Morphic piece showing it; imbued_needs_boss_piece = false: always)
function Imbued.Available(hoard, piece)
	local info = piece.armordyes_imbued
	if type(info) == "table" and info.dye_only then
		return false -- (0.5.11) a dye only (the weapon's own list), never a mirage pattern
	end
	if Imbued.settings == nil or Imbued.settings.imbued_needs_boss_piece == false then
		return true
	end
	if hoard == nil or type(hoard.data) ~= "table" or type(hoard.data.inventory) ~= "table" then
		return false
	end
	local base = Equipment.Items[info.slot][info.base]
	for _, item in ipairs(hoard.data.inventory[info.slot] or {}) do
		if type(item) == "table" and type(item.GetDef) == "function" then
			local ok, def = pcall(item.GetDef, item)
			if ok and def == base then
				return true
			end
			local ok2, shown = pcall(item.GetDefaultItemAppearance, item)
			if ok2 and shown == info.base then
				return true
			end
		end
	end
	return false
end

-- one stand-in item per imbued pattern and player (never saved, never in the inventory)
local stand_ins = setmetatable({}, { __mode = "k" })

function Imbued.StandIn(hoard, piece)
	local t = stand_ins[hoard]
	if t == nil then
		t = {}
		stand_ins[hoard] = t
	end
	-- by slot and name: the helmet, body and legs share a name (like the game's armour;
	-- 0.5.1 kept one per name, and the body and legs patterns showed the helmet)
	local key = tostring(piece.slot) .. "/" .. piece.name
	local item = t[key]
	if item == nil then
		local itemforge = require "defs.itemforge"
		item = itemforge.CreateEquipment(piece.slot, piece)
		t[key] = item
	end
	return item
end

function Imbued.StandInsFor(hoard, slot)
	local out = {}
	for _, piece in ipairs(Imbued.by_slot[slot] or {}) do
		if Imbued.Available(hoard, piece) then
			out[#out + 1] = Imbued.StandIn(hoard, piece)
		end
	end
	return out
end

function Imbued.HookMirage()
	local ok_c, Changer = pcall(require, "widgets.ftf.armoryequipmentchanger")
	local ok_h, InventoryHoard = pcall(require, "components.inventoryhoard")
	if not ok_c or type(Changer) ~= "table" or type(Changer.DisplayEquipment) ~= "function" then
		return false, "the mirage list changed"
	end
	if not ok_h or type(InventoryHoard) ~= "table" or type(InventoryHoard.GetInventoryItem) ~= "function"
		or type(InventoryHoard.GetSlotItems) ~= "function" then
		return false, "InventoryHoard changed"
	end

	-- an imbued pattern you have counts as owned (unlocked at the station)
	local get_item = InventoryHoard.GetInventoryItem
	InventoryHoard.GetInventoryItem = function(self, itemdef, ...)
		local item = get_item(self, itemdef, ...)
		if item == nil and type(itemdef) == "table" and itemdef.armordyes_imbued ~= nil and Imbued.mirage_on then
			local ok, have = pcall(Imbued.Available, self, itemdef)
			if ok and have then
				return Imbued.StandIn(self, itemdef)
			end
		end
		return item
	end

	-- the station's list (the only list that shows patterns: show_cosmetics) gets them
	-- with the owned patterns
	local display = Changer.DisplayEquipment
	Changer.DisplayEquipment = function(self, slot, ...)
		local hoard = self.show_cosmetics and Imbued.mirage_on and self.player ~= nil and self.player.components ~= nil
			and self.player.components.inventoryhoard or nil
		local extra = nil
		if hoard ~= nil then
			local ok, list = pcall(Imbued.StandInsFor, hoard, slot)
			if ok and #list > 0 then
				extra = list
			elseif not ok then
				Log("imbued patterns skipped: " .. tostring(list))
			end
		end
		if extra == nil then
			return display(self, slot, ...)
		end
		local own = rawget(hoard, "GetSlotItems")
		local get = own or InventoryHoard.GetSlotItems
		rawset(hoard, "GetSlotItems", function(h, s, ...)
			local items = get(h, s, ...)
			if s ~= slot or type(items) ~= "table" then
				return items
			end
			local t = {}
			for i = 1, #items do
				t[i] = items[i]
			end
			for _, item in ipairs(extra) do
				t[#t + 1] = item
			end
			return t
		end)
		local r = table.pack(pcall(display, self, slot, ...))
		rawset(hoard, "GetSlotItems", own)
		if not r[1] then
			error(r[2], 0)
		end
		return table.unpack(r, 2, r.n)
	end

	-- sorted with their boss's patterns, and the station's filters find their place
	local ok_b, biomes = pcall(require, "defs.biomes")
	if ok_b and type(biomes) == "table" and type(biomes.GetLocationForBoss) == "function" then
		local for_boss = biomes.GetLocationForBoss
		biomes.GetLocationForBoss = function(name, ...)
			local loc = for_boss(name, ...)
			if loc == nil and type(name) == "string" and Imbued.boss_of[name] ~= nil then
				return for_boss(Imbued.boss_of[name], ...)
			end
			return loc
		end
	end
	Imbued.mirage_on = true
	return true
end

----------------------------------------------------------------------------
-- (0.5.4) The main menu. The game loads no area there, so the imbued art a character card shows is loaded
-- when the card is drawn (only those builds) and put in the main menu's own list: the game unloads that list
-- when a game starts. The list is made again in each new sim (Lua restarts), so the builds are handed to the
-- next sim in the restart settings and added to its list before the game unloads it.

Imbued.fe_loaded = {} -- art prefab -> true: loaded for the main menu in this sim
Imbued.fe_on = true
Imbued.FE_KEY = "armordyes_imbued_fe"

local function InFrontEnd()
	local params = rawget(_G, "InstanceParams")
	local s = type(params) == "table" and params.settings or nil
	return type(s) == "table" and s.last_asset_set == "FRONTEND"
end
Imbued.InFrontEnd = InFrontEnd

function Imbued.FrontEndList()
	local out = {}
	for p in pairs(Imbued.fe_loaded) do
		out[#out + 1] = p
	end
	table.sort(out)
	return out
end

-- Loads the art of these builds for the main menu (not already loaded). Returns how many were loaded.
function Imbued.LoadForFrontEnd(builds)
	if not Imbued.art_on or not Imbued.fe_on or not InFrontEnd() or type(builds) ~= "table" then
		return 0
	end
	local sim = rawget(_G, "TheSim")
	local fe = rawget(_G, "FRONTEND_PREFABS")
	if sim == nil or type(sim.LoadPrefabs) ~= "function" or type(fe) ~= "table" then
		return 0
	end
	local missing = {}
	for _, b in ipairs(builds) do
		if type(b) == "string" and Imbued.art[b] ~= nil then
			local p = Imbued.ArtPrefab(b)
			if not Imbued.fe_loaded[p] then
				missing[#missing + 1] = p
			end
		end
	end
	if #missing == 0 then
		return 0
	end
	local ok, err = pcall(sim.LoadPrefabs, sim, missing)
	if not ok then
		Log("imbued art for the main menu not loaded: " .. tostring(err))
		return 0
	end
	for _, p in ipairs(missing) do
		Imbued.fe_loaded[p] = true
		fe[#fe + 1] = p -- (unloaded with the main menu's own art)
	end
	return #missing
end

-- A restart (the game's SimReset, every way it's reached): the main menu's builds go in its settings. In the
-- next sim (this file loads again), they're added to its main menu list before the game unloads that list,
-- or kept as loaded when it's the main menu again.
function Imbued.HookFrontEndReset()
	local reset = rawget(_G, "SimReset")
	if type(reset) ~= "function" then
		return "SimReset changed"
	end
	rawset(_G, "SimReset", function(settings, ...)
		if InFrontEnd() and next(Imbued.fe_loaded) ~= nil then
			settings = settings or {}
			if type(settings) == "table" then
				settings[Imbued.FE_KEY] = Imbued.FrontEndList()
			end
		end
		return reset(settings, ...)
	end)
	local params = rawget(_G, "InstanceParams")
	local s = type(params) == "table" and params.settings or nil
	local carried = type(s) == "table" and s.last_asset_set == "FRONTEND" and s[Imbued.FE_KEY] or nil
	local fe = rawget(_G, "FRONTEND_PREFABS")
	if type(carried) == "table" and type(fe) == "table" then
		for _, p in ipairs(carried) do
			if type(p) == "string" and p:sub(1, #Imbued.ART_PREFIX) == Imbued.ART_PREFIX and not Imbued.fe_loaded[p] then
				Imbued.fe_loaded[p] = true
				fe[#fe + 1] = p
			end
		end
	end
	return true
end

-- The look a saved item shows (its save data): its mirage (an imbued one from its note), its Morphic gem's,
-- or itself. As the game works it out (ItemInstance:GetItemAppearanceID), on a copy.
function Imbued.SavedLook(slot, item_data)
	if type(item_data) ~= "table" or type(item_data.id) ~= "string" then
		return nil
	end
	local items = Equipment.Items[slot]
	local copy = Copy(item_data)
	copy.slot = copy.slot or slot
	local itemforge = require "defs.itemforge"
	local ok = pcall(itemforge.ConvertToRuntimeItem, copy)
	if ok and type(copy.GetItemAppearanceID) == "function" then
		local ok2, id = pcall(copy.GetItemAppearanceID, copy)
		if ok2 and type(id) == "string" and items ~= nil and items[id] ~= nil then
			return id
		end
	end
	return item_data.id
end

-- The imbued build a look shows with these saved dyes (equipmentdyer save data), or nil.
function Imbued.SavedBuild(slot, look, dyes)
	local items = Equipment.Items[slot]
	local def = items ~= nil and type(look) == "string" and items[look] or nil
	if def == nil then
		return nil
	end
	if def.armordyes_imbued ~= nil then
		return def.build
	end
	local sd = type(dyes) == "table" and type(dyes[slot]) == "table" and dyes[slot][look] or nil
	local sets = Cosmetic.EquipmentDyes[slot]
	local dye = type(sd) == "string" and sets ~= nil and sets[look] ~= nil and sets[look][sd] or nil
	return type(dye) == "table" and dye.armordye_swap ~= nil and dye.armordye_build or nil
end

-- The imbued builds a saved character shows (its drawn pieces and its dyes).
function Imbued.SavedBuilds(entity_data)
	local out, seen = {}, {}
	if type(entity_data) ~= "table" then
		return out
	end
	local inv = type(entity_data.inventory) == "table" and entity_data.inventory or {}
	local equips = type(inv.equips) == "table" and inv.equips or {}
	local looks = type(inv[Imbued.EQUIP_KEY]) == "table" and inv[Imbued.EQUIP_KEY] or {}
	local dyer = type(entity_data.equipmentdyer) == "table" and entity_data.equipmentdyer or {}
	for _, slot in ipairs(Imbued.WORN_SLOTS) do
		local b = Imbued.SavedBuild(slot, looks[slot] or equips[slot], dyer.dyes)
		if b ~= nil and not seen[b] then
			seen[b] = true
			out[#out + 1] = b
		end
	end
	table.sort(out)
	return out
end

-- The character cards (save slots, the main menu and in-game character select). A card with loadouts draws
-- each loadout by the items' own names (CharacterSaveSlotButton:SetLoadout): a mirage pattern (and the dye on
-- that look) didn't show. Each piece is drawn in its look again, with the imbued art it needs on the main menu.
function Imbued.ShowLoadoutLooks(btn, idx)
	local data = btn.player_entity_data
	local hoard = type(data) == "table" and data.inventoryhoard or nil
	local choice = type(btn.loadout_choice_choices) == "table" and btn.loadout_choice_choices[idx] or nil
	if type(hoard) ~= "table" or type(hoard.inventory) ~= "table" or type(choice) ~= "table" then
		return 0
	end
	local dyes = type(data.equipmentdyer) == "table" and data.equipmentdyer.dyes or nil
	local looks, builds = {}, {}
	for slot, item_idx in pairs(type(choice.equipment) == "table" and choice.equipment or {}) do
		local items = hoard.inventory[slot]
		local item = type(item_idx) == "number" and item_idx > 0 and type(items) == "table" and items[item_idx] or nil
		local look = item ~= nil and Imbued.SavedLook(slot, item) or nil
		if look ~= nil then
			if look ~= item.id then
				looks[slot] = look
			end
			local b = Imbued.SavedBuild(slot, look, dyes)
			if b ~= nil then
				builds[#builds + 1] = b
			end
		end
	end
	local loaded = Imbued.LoadForFrontEnd(builds)
	for slot, look in pairs(looks) do
		btn:EquipArmour(slot, look)
	end
	if loaded > 0 then
		-- art that wasn't there when the pieces went on: drawn again with it
		for _, pup in ipairs({ btn.puppet, btn.puppet_shadow }) do
			local inv = pup ~= nil and pup.GetInventoryComponent ~= nil and pup:GetInventoryComponent() or nil
			if inv ~= nil and inv.RebuildCharacterArmour ~= nil then
				pcall(inv.RebuildCharacterArmour, inv)
			end
		end
	end
	return loaded
end

function Imbued.HookCards()
	local done = {}
	local ok_p, SelectablePuppet = pcall(require, "widgets.ftf.selectablepuppet")
	if ok_p and type(SelectablePuppet) == "table" and type(SelectablePuppet.SetPlayerData) == "function" then
		local set = SelectablePuppet.SetPlayerData
		SelectablePuppet.SetPlayerData = function(self, entity_data, ...)
			if InFrontEnd() then
				local ok, err = pcall(function() Imbued.LoadForFrontEnd(Imbued.SavedBuilds(entity_data)) end)
				if not ok then
					Log("imbued art for a character card skipped: " .. tostring(err))
				end
			end
			return set(self, entity_data, ...)
		end
		done[#done + 1] = "cards"
	end
	local ok_b, Btn = pcall(require, "widgets.ftf.charactersaveslotbutton")
	if ok_b and type(Btn) == "table" and type(Btn.SetLoadout) == "function" and type(Btn.EquipArmour) == "function" then
		local set_loadout = Btn.SetLoadout
		Btn.SetLoadout = function(self, idx, ...)
			local r = table.pack(set_loadout(self, idx, ...))
			local ok, err = pcall(Imbued.ShowLoadoutLooks, self, idx)
			if not ok then
				Log("loadout looks on a character card skipped: " .. tostring(err))
			end
			return table.unpack(r, 1, r.n)
		end
		done[#done + 1] = "loadout looks"
	end
	return #done > 0, table.concat(done, ", ")
end

-- The drawn pieces' names are saved too (Inventory:OnSave, the character cards read them): an imbued one is
-- saved as the boss's own look + a note (as items are), and put back on load when the game has it.
Imbued.EQUIP_KEY = "armordyes_looks"
function Imbued.HookInventorySave()
	local ok, Inventory = pcall(require, "components.inventory")
	if not ok or type(Inventory) ~= "table" or type(Inventory.OnSave) ~= "function" or type(Inventory.OnLoad) ~= "function" then
		return false
	end
	local save = Inventory.OnSave
	Inventory.OnSave = function(self, ...)
		local data = save(self, ...)
		pcall(function()
			if type(data) == "table" and type(data.equips) == "table" then
				for slot, name in pairs(data.equips) do
					local info = Imbued.Info(slot, name)
					if info ~= nil then
						data.equips[slot] = info.base
						data[Imbued.EQUIP_KEY] = data[Imbued.EQUIP_KEY] or {}
						data[Imbued.EQUIP_KEY][slot] = name
					end
				end
			end
		end)
		return data
	end
	local load = Inventory.OnLoad
	Inventory.OnLoad = function(self, data, ...)
		if type(data) == "table" and type(data[Imbued.EQUIP_KEY]) == "table" and type(data.equips) == "table" then
			local ok2, fixed = pcall(function()
				local d = {}
				for k, v in pairs(data) do d[k] = v end
				d.equips = {}
				for k, v in pairs(data.equips) do d.equips[k] = v end
				for slot, name in pairs(data[Imbued.EQUIP_KEY]) do
					local info = Imbued.Info(slot, name)
					if info ~= nil and d.equips[slot] == info.base then
						d.equips[slot] = name
					end
				end
				return d
			end)
			if ok2 then
				data = fixed
			end
		end
		return load(self, data, ...)
	end
	return true
end

----------------------------------------------------------------------------

-- After Main.Install: the dyes and the hooks. Returns a line for client_log.txt.
function Imbued.Install(settings)
	local n = Imbued.RegisterDyes()
	-- the imbued dye draws only where its art is loaded (main.lua ApplySlot)
	Main.SwapArtLoaded = Imbued.ArtLoadedForDraw
	local parts = { string.format("%d imbued looks (%d pieces, %d dyes)", #Imbued.looks, Imbued.defs, n) }
	parts[#parts + 1] = Imbued.art_on and string.format("art per area: %d builds (town: all; hunts: what's worn%s)", #Imbued.art_list,
			Imbued.room_travel_on and ", topped up each room" or "")
		or ("art off: " .. tostring(Imbued.art_why) .. " (normal boss looks)")
	if not Imbued.HookDrawFallback() then
		parts[#parts + 1] = "no draw fallback"
	end
	local ok_c, cards, what = pcall(Imbued.HookCards)
	parts[#parts + 1] = ok_c and cards and ("character cards: " .. what .. (Imbued.art_on and Imbued.fe_on and ", imbued art on the main menu" or ""))
		or "character cards: the game's"
	if not Imbued.HookWeaponDef() then
		parts[#parts + 1] = "thrown weapon parts in the normal art"
	end
	if settings.imbued_icons ~= false and Imbued.icons_ok then
		local ok, what = Imbued.HookIcons()
		parts[#parts + 1] = ok and ("icons: " .. what) or "icons off: the game's icon widgets changed"
	else
		parts[#parts + 1] = "icons off"
	end
	if settings.imbued_mirage ~= false then
		local ok, why = Imbued.HookMirage()
		parts[#parts + 1] = ok and "mirage patterns on" or ("mirage patterns off: " .. tostring(why))
	else
		parts[#parts + 1] = "mirage patterns off in the settings"
	end
	return table.concat(parts, "; ")
end

return Imbued
