-- Camp Brother: his table (the small trailer). Doc Hoggins' travelling trailer from the dungeon's potion
-- rooms (traveling_potion_trailer), recoloured (anim/campbrother_trailer.zip: red
-- canvas, charcoal frame), made by the game's prop maker (prefabs/prop_autogen.lua's
-- MakeAutogenProp, the one every town prop comes from) with the trailer's own prop
-- data, played by the trailer's own animation (bank traveling_potion_trailer).

local NAME = "campbrother_trailer"
local BANK = "traveling_potion_trailer"

-- the game's trailer as its prop editor wrote it, if a game update takes it away
local FALLBACK = {
	gridsize = { { h = 3, w = 5 } },
	looping = true,
	parallax = {
		{ anim = "1", dist = -1.5, shadow = true },
		{ anim = "2", dist = -1.3999999761581, shadow = true },
		{ anim = "3", dist = -0.40000000596046, shadow = true },
		{ anim = "4", dist = -0.20000000298023, shadow = true },
		{ anim = "5", shadow = true },
		{ anim = "6", dist = 0.20000000298023, shadow = true },
		{ anim = "7", dist = 0.30000001192093, shadow = true },
	},
	parallax_use_baseanim_for_idle = true,
	physicssize = 2.5,
	physicstype = "dec",
	randomstartframe = true,
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
	print("[Camp Brother] no trailer: the game's prop maker (MakeAutogenProp) is gone")
	return
end

local Main = require "campbrother.main"
local look = Main.Look(Main.settings)
local scale = look.table ~= nil and look.table.scale or 1

local ok, data = pcall(require, "prefabs.prop_autogen_data")
local p = copy(ok and type(data) == "table" and data[BANK] or FALLBACK)
p.__displayName = NAME
p.bank = BANK
p.bankfile = BANK
p.build = NAME
p.group = "town_buildings"
p.networked = 0 -- every machine spawns its own with the town's props, like the dungeon's
p.script = nil -- (the trailer's script_args are a leftover with no script)
p.script_args = nil
p.clickable = nil
p.physicssize = (p.physicssize or 2.5) * scale -- its bump follows its size
return MakeAutogenProp(NAME, p)
