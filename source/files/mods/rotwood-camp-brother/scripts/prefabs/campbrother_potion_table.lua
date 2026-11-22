-- Camp Brother: Doc Hoggins' little potion table from the dungeon's potion rooms
-- (traveling_potion_table), as decoration on the road by his station when Tonic Swap's
-- working Potion Table isn't there. The game's prop maker (MakeAutogenProp) with the
-- table's own prop data, its own animation and art.

local NAME = "campbrother_potion_table"
local BANK = "traveling_potion_table"

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

local MakeAutogenProp = rawget(_G, "MakeAutogenProp")
if MakeAutogenProp == nil then
	print("[Camp Brother] no potion table: the game's prop maker (MakeAutogenProp) is gone")
	return
end

local ok, data = pcall(require, "prefabs.prop_autogen_data")
local p = copy(ok and type(data) == "table" and data[BANK] or FALLBACK)
p.__displayName = NAME
p.bank = BANK
p.bankfile = BANK
p.build = BANK
p.group = "town_buildings"
p.networked = 0 -- every machine spawns its own with the town's props
p.script = nil
p.script_args = nil
p.clickable = nil
p.placer = nil
return MakeAutogenProp(NAME, p)
