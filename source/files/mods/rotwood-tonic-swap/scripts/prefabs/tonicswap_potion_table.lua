-- Tonic Swap's Potion Table (scripts/tonicswap/table.lua): the prop and its
-- build-menu placer, made by the game's own prop maker (prefabs/prop_autogen.lua's
-- MakeAutogenProp and prefabs/placers.lua), the way it makes every town prop.
local ok, Table = pcall(require, "tonicswap.table")
local MakeAutogenProp = rawget(_G, "MakeAutogenProp")
if not ok or MakeAutogenProp == nil then
	print("[Tonic Swap] no Potion Table: " .. (ok and "the game's prop maker (MakeAutogenProp) is gone" or tostring(Table)))
	return
end
local params = Table.Params()
local ret = { MakeAutogenProp(Table.NAME, params) }
local placers_ok, Placers = pcall(require, "prefabs.placers")
if placers_ok and type(Placers) == "table" and Placers.MakePlacerPrefab ~= nil then
	for _, prefab in ipairs(Placers.MakePlacerPrefab(Table.NAME, params)) do
		ret[#ret + 1] = prefab
	end
else
	print("[Tonic Swap] Potion Table: the game's placer maker is gone, it can't be placed from the build menu")
end
return table.unpack(ret)
