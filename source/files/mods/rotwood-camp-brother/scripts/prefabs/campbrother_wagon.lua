-- Camp Brother: his big wagon. Doc Hoggins' big potion wagon from the dungeon's potion
-- rooms (traveling_potion_shop), made by the game's prop maker (prefabs/prop_autogen.lua's
-- MakeAutogenProp, the one every town prop comes from) with the wagon's own prop data,
-- played by its own animation and art. Only for the "wagon_table" setup.

local NAME = "campbrother_wagon"
local BANK = "traveling_potion_shop"

-- the game's wagon as its prop editor wrote it, if a game update takes it away
local FALLBACK = {
	gridsize = { { expand = { bottom = 2 }, h = 5, w = 6 } },
	parallax = {
		{ anim = "1", dist = -1.8999999761581, shadow = true },
		{ anim = "2", dist = -1.7999999523163, shadow = true },
		{ anim = "3", shadow = true },
		{ anim = "4", dist = 0.20000000298023, shadow = true },
		{ anim = "5", dist = 0.40000000596046, shadow = true },
		{ anim = "6", dist = 0.60000002384186, shadow = true },
		{ anim = "7", dist = 1.2000000476837, shadow = true },
	},
	parallax_use_baseanim_for_idle = true,
	physicssize = 2.8,
	physicstype = "dec",
	sound = true,
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

local MakeAutogenProp = rawget(_G, "MakeAutogenProp")
if MakeAutogenProp == nil then
	print("[Camp Brother] no wagon: the game's prop maker (MakeAutogenProp) is gone")
	return
end

local Main = require "campbrother.main"
local look = Main.Look(Main.settings)
local scale = look.wagon ~= nil and look.wagon.scale or 1

local ok, data = pcall(require, "prefabs.prop_autogen_data")
local p = copy(ok and type(data) == "table" and data[BANK] or FALLBACK)
p.__displayName = NAME
p.bank = BANK
p.bankfile = BANK
p.build = BANK
p.group = "town_buildings"
p.networked = 0 -- every machine spawns its own with the town's props
p.script = nil -- not a building you can upgrade / reskin: a set piece
p.script_args = nil
p.clickable = nil
p.placer = nil
p.children = nil
p.physicssize = (p.physicssize or 2.8) * scale -- its bump follows its size
return MakeAutogenProp(NAME, p)
