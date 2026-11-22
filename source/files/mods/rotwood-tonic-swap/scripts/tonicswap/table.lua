-- Tonic Swap: the Potion Table, a tonic station you build in town (Build
-- menu: Furniture and Usable). Doc Hoggins' travelling table from the dungeon
-- with Soothing Spirits, Misting Mixture and Bubbling Brew on it and his SALE!
-- sign kept: anim/tonicswap_potion_table.zip is the game's table art with the
-- decanter swapped for the three bottles, played by the game's own table
-- animation (bank traveling_potion_table).
--
-- Made the game's way, nothing of our own runs on it:
--   the prop: the game's prop maker (MakeAutogenProp, the one every town prop
--     comes from) and its build-menu placer, with the game's screen opener
--     script, so interact (RB) opens the potions menu the way the Teffra
--     Mirage Station opens its screen (scripts/prefabs/tonicswap_potion_table.lua)
--   the build menu entry: a Constructable structure like the game's own, with
--     an icon in the game's town-prop style (images/tonicswap_station)

local Table = {}

Table.NAME = "tonicswap_potion_table"
Table.BANK = "traveling_potion_table" -- the game's travelling table: its animation plays ours
Table.ICON = "images/tonicswap_station/town_prop_tonicswap_potion_table.tex"
Table.LABEL = "Choose Potions"
Table.TEXT = {
	name = "Potion Table",
	desc = "Doc Hoggins' travelling table, with all three potions on it. Choose your potion and tonics here.",
}
Table.COST_LIKE = "bench_basic" -- costs what this structure costs (the Hewn Bench)
-- 1.15x the game's table: its top at a hunter's chest (the art is built 1.15x:
-- kit/tools/stationart/build_table.py). 2x2 on the town grid like the game's table, a slightly
-- bigger body. Interact reaches it (the screen opener's radius is 3.5).
Table.GRID = { w = 2, h = 2 }
Table.PHYSICS = 1.5

-- The game's travelling table as its prop editor wrote it, if a game update
-- takes it away.
local FALLBACK = {
	gridsize = { { h = 2, w = 2 } },
	looping = true,
	parallax = {
		{ anim = "1", shadow = true },
		{ anim = "2", dist = 0.10000000149012, shadow = true },
		{ anim = "3", dist = 0.15000000596046, shadow = true },
		{ anim = "4", dist = 0.20000000298023, shadow = true },
	},
	parallax_use_baseanim_for_idle = true,
	physicssize = 1.3,
	physicstype = "smdec",
	randomstartframe = true,
}

local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local r = {}
	for k, v in pairs(t) do
		r[k] = copy(v)
	end
	return r
end

-- The prop's data, in the form the game's prop editor writes (like
-- prefabs/autogen/prop/vanity_screen.lua): the travelling table's own data,
-- networked and placeable like the town's other structures, with the game's
-- screen opener.
function Table.Params()
	local ok, data = pcall(require, "prefabs.prop_autogen_data")
	local base = ok and type(data) == "table" and data[Table.BANK] or nil
	local p = copy(base or FALLBACK)
	p.__displayName = Table.NAME
	p.bank = Table.BANK
	p.bankfile = Table.BANK -- so the placer loads the animation too
	p.build = Table.NAME
	p.group = "construct_structure"
	p.clickable = true
	p.placer = true
	p.networked = 1
	p.isminimal = true
	p.hostspawn = true
	p.sound = true
	p.gridsize = { { w = Table.GRID.w, h = Table.GRID.h } }
	p.physicssize = Table.PHYSICS
	p.script = "screenopener"
	p.script_args = {
		screen_require = "tonicswap.screen",
		interact_sounds = {
			interact_start = { sound_max_count = 1.0, soundevent = "inventory_equip_potions" },
		},
	}
	return p
end

-- The build-menu recipe for the item (defs/recipes.lua): made with the game's
-- own MakePlaceablePropRecipe when the recipes are loaded already. Returns
-- true when the item has a recipe or will get one from the game's loop.
function Table.EnsureRecipe(def)
	local Recipes = package.loaded["defs.recipes"]
	if type(Recipes) ~= "table" then
		return true -- not loaded yet: the game's loop over the structures makes it
	end
	local for_slot = type(Recipes.ForSlot) == "table" and Recipes.ForSlot[def.slot] or nil
	if type(for_slot) ~= "table" then
		return false, "the game's recipes changed (no " .. tostring(def.slot) .. " recipes)"
	end
	if for_slot[def.name] == nil then
		local make = rawget(_G, "MakePlaceablePropRecipe")
		if type(make) ~= "function" then
			return false, "the game's recipe maker (MakePlaceablePropRecipe) is gone"
		end
		local ok, err = pcall(make, def)
		if not ok then
			return false, "its recipe: " .. tostring(err)
		end
	end
	if for_slot[def.name] == nil then
		return false, "no recipe made"
	end
	return true
end

-- Its build menu entry and text. Call from modmain (before the game loads the
-- town's prefabs). Returns true, what it costs.
function Table.Install(cost_like)
	local Constructable = require "defs.constructable"
	local slot = Constructable.Slots.STRUCTURES
	local items = slot ~= nil and Constructable.Items[slot] or nil
	if items == nil then
		return false, "the build menu's structures changed"
	end
	STRINGS.ITEMS[slot] = STRINGS.ITEMS[slot] or {}
	STRINGS.ITEMS[slot][Table.NAME] = STRINGS.ITEMS[slot][Table.NAME] or copy(Table.TEXT)
	STRINGS.NAMES[Table.NAME] = Table.TEXT.name
	STRINGS.UI.SCREENOPENER_PROP[Table.NAME] = Table.LABEL
	if items[Table.NAME] ~= nil then
		local ok_recipe, why = Table.EnsureRecipe(items[Table.NAME])
		if not ok_recipe then
			items[Table.NAME] = nil
			return false, why
		end
		return true, "already there"
	end
	local like_name = cost_like or Table.COST_LIKE
	if items[like_name] == nil then
		like_name = Table.COST_LIKE
	end
	local like = items[like_name]
	local ingredients = {}
	for name, count in pairs(like and like.ingredients or {}) do
		ingredients[name] = count
	end
	local descriptor = Constructable.SlotDescriptor and Constructable.SlotDescriptor[slot]
	-- the fields the game's AddStructure gives an item (defs/constructable.lua)
	items[Table.NAME] = {
		name = Table.NAME,
		slot = slot,
		icon = Table.ICON,
		dungeon_icon = descriptor and descriptor.icon or nil,
		pretty = STRINGS.ITEMS[slot][Table.NAME],
		tags = {
			furniture = true, -- the Furniture tab
			usable = true, -- the Usable tab (like the Teffra Mirage Station)
			playercraftable = true,
			[Constructable.Categories and Constructable.Categories.BASIC or "basic"] = true,
			placeable = true,
		},
		rarity = ITEM_RARITY.s.COMMON,
		weight = 1,
		stackable = true,
		gridsize = { w = Table.GRID.w, h = Table.GRID.h },
		ingredients = ingredients,
	}
	-- Its build-menu recipe. The game makes one for every structure when it loads
	-- defs/recipes.lua (MakePlaceablePropRecipe). If that's loaded already, make
	-- ours the same way now (without one the build menu crashed when the table
	-- got focus); if not, the game's own loop makes it with the others.
	local ok_recipe, why = Table.EnsureRecipe(items[Table.NAME])
	if not ok_recipe then
		items[Table.NAME] = nil -- no recipe = not in the build menu (it would crash it)
		return false, why
	end
	local parts = {}
	for name, count in pairs(ingredients) do
		parts[#parts + 1] = count .. " " .. name
	end
	table.sort(parts)
	return true, "costs " .. (#parts > 0 and table.concat(parts, ", ") or "nothing") .. " (like " .. tostring(like and like_name or "nothing") .. ")"
end

return Table
