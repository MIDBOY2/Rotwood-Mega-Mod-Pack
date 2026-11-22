-- Two Weapons: the market's stands count every hunter the same (1.0.9, 1.0.12).
--
-- The hunt's market (Alphonse's armour and weapon stands, bought with
-- Corestones; components/shopmanager.lua GenerateMetaWares) rolls its list
-- the game's way: this hunt's gear, the weapon types the hunters hold first
-- (with random mixing). Then _FilterItemsByAllOwnedWithFallback cuts what's
-- owned, in three tiers (_FilterItemsByAllOwnership): nobody owns it, some
-- own it, all own it, taking the first tiers that fill every stand; each stand
-- takes the first piece of its kind left (_SpawnMannequinFromWares).
-- So a piece one hunter already owns fell behind pieces nobody here wants:
-- player 2's weapon was pushed off the stands when player 1 had bought it
-- (user 2026-11-13: "it picks player 1's weapons and ignores player 2's"),
-- and the mixing could put a type nobody holds first (user 20:54: "still
-- giving out other classes when the current held weapons of the area aren't
-- owned yet").
--
-- The fix (user 19:15: "a fix, not a rework: take player 2 equally into
-- account, and don't show what both players have; if both have everything
-- from that area, keep the first roll"):
--  * each hunter's weapon in hand first: this hunt's weapon of that type, when
--    that hunter doesn't own it yet (their own inventory), one for each hunter
--    in the game's player order (player 1 the first stand, player 2 the second).
--  * then the game's own tiers, in the game's roll: pieces nobody owns, then
--    pieces one of you owns, then pieces you all own (only when nothing else is
--    left for a stand).
-- 1.0.9 counted "one of you owns it" the same as "nobody owns it"; that put
-- back on the stands the weapons you both already hold (user 21:01: "when both
-- players have the weapon in hand the market rolled nothing"). 1.0.12 keeps
-- the game's tiers instead, with the hands first.
-- Nothing else changes: the game's roll, its stands, its frenzy and DLC rules.
-- settings: market_weapons = true (false: the game's).
local Market = {}

Market.SLOT = "WEAPON"

local function Cmp(p, name)
	return type(p) == "table" and type(p.components) == "table" and p.components[name] or nil
end

local function HeldType(player)
	local inv = Cmp(player, "inventory")
	if inv == nil or inv.GetEquippedWeaponDef == nil then
		return nil
	end
	local ok, def = pcall(inv.GetEquippedWeaponDef, inv)
	return ok and type(def) == "table" and def.weapon_type or nil
end

local function Owns(player, def)
	local hoard = Cmp(player, "inventoryhoard")
	if hoard == nil or hoard.HasInventoryItem == nil then
		return false
	end
	local ok, has = pcall(hoard.HasInventoryItem, hoard, def)
	return ok and has == true
end

-- The weapons for the hunters' hands (one each, the game's order of hunters):
-- the first in list of the type in that hunter's hand that they don't own.
function Market.ForHands(list, players)
	local picks, used = {}, {}
	for _, player in ipairs(players or {}) do
		local t = HeldType(player)
		if t ~= nil then
			for _, def in ipairs(list) do
				if type(def) == "table" and def.slot == Market.SLOT and def.weapon_type == t and not used[def] and not Owns(player, def) then
					picks[#picks + 1] = def
					used[def] = true
					break
				end
			end
		end
	end
	return picks, used
end

-- lists: the game's { unowned, owned by some, owned by all } for items.
-- Returns the same three tiers with the hunters' weapons in hand (ForHands)
-- moved to the front of the first, the rest in the game's order (or nil when
-- the lists aren't what the game makes: then the game's).
function Market.Merge(items, lists, players)
	if type(items) ~= "table" or type(lists) ~= "table" then
		return nil
	end
	local unowned, some, all = lists[1], lists[2], lists[3]
	if type(unowned) ~= "table" or type(some) ~= "table" or type(all) ~= "table" then
		return nil
	end
	if #unowned + #some + #all ~= #items then
		return nil -- (not the game's three tiers of these items)
	end
	local by_all = {}
	for _, def in ipairs(all) do
		by_all[def] = true
	end
	-- the hunters' hands (never owned by all: the holder doesn't own it)
	local wanted = {}
	for _, def in ipairs(items) do
		if not by_all[def] then
			wanted[#wanted + 1] = def
		end
	end
	local hands, used = Market.ForHands(wanted, players)
	local first, second = {}, {}
	for _, def in ipairs(hands) do
		first[#first + 1] = def
	end
	for _, def in ipairs(unowned) do
		if not used[def] then
			first[#first + 1] = def
		end
	end
	for _, def in ipairs(some) do
		if not used[def] then
			second[#second + 1] = def
		end
	end
	return { first, second, all }
end

-- ShopManager: components/shopmanager.lua; G: the mod's guard; players_fn:
-- the hunters here (the game's TheNet:GetPlayersOnRoomChange).
function Market.Install(ShopManager, G, players_fn)
	if type(ShopManager) ~= "table" or type(ShopManager._FilterItemsByAllOwnership) ~= "function"
		or type(ShopManager._FilterItemsByAllOwnedWithFallback) ~= "function" then
		return false, "a game update changed ShopManager:_FilterItemsByAllOwnership"
	end
	local info = "the market: each hunter's weapon in hand first (this hunt's, when they don't own it)"
	if rawget(ShopManager, "twoweapons_market") then
		return true, info
	end
	rawset(ShopManager, "twoweapons_market", true)
	local orig = ShopManager._FilterItemsByAllOwnership
	ShopManager._FilterItemsByAllOwnership = function(self, items, ...)
		local lists = orig(self, items, ...)
		local ok, merged = G.Call("the market's stands", function()
			-- (no hunters list: the game's tiers)
			local okp, players = false, nil
			if type(players_fn) == "function" then
				okp, players = pcall(players_fn)
			end
			return Market.Merge(items, lists, okp and type(players) == "table" and players or {})
		end)
		if ok and type(merged) == "table" then
			return merged
		end
		return lists
	end
	return true, info
end

return Market
