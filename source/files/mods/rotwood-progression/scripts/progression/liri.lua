-- Progression, Liri mode: between permanent and nightly.
--   A main boss beaten on Super Frenzy (any Super Frenzy level), each player
--   who's there gets: the boss's weapon for the 2 weapons they hold, the 3
--   Morphic pieces and all 3 of its Morphic gems (permanent mode's reward
--   with every gem at once).
--   Super Frenzy hearts x2, corestones x3, Gift-Wrapped Souvenirs x2
--   (each one set in the settings), and one market armour piece = the whole set.

local Common = require "progression.common"
local Permanent = require "progression.permanent"

local Liri = {}

-- what each multiplier applies to (Consumable item names)
Liri.CORESTONE = "konjur_soul_lesser"
Liri.GIFT = "friend_gift"

function Liri.Info(s)
	local info = Permanent.Info(s)
	if s.corestone_multiplier > 1 then
		info = info .. ", corestones x" .. s.corestone_multiplier
	end
	if s.gift_multiplier > 1 then
		info = info .. ", gifts x" .. s.gift_multiplier
	end
	if s.market_full_set then
		info = info .. ", market full sets"
	end
	return info
end

-- extra corestones / gifts for a pickup of `count`
function Liri.DropExtra(def, count, s)
	if def.name == Liri.CORESTONE then
		return count * (s.corestone_multiplier - 1)
	elseif def.name == Liri.GIFT then
		return count * (s.gift_multiplier - 1)
	end
	return 0
end

function Liri.Install(s)
	local problem = Permanent.InstallBothClears(s)
	return Liri.Info(s) .. (problem ~= nil and ("; " .. problem) or "")
end

function Liri.SetupPlayer(inst, s)
	-- boss rewards and the Super Frenzy heart multiplier: permanent mode's, with these settings
	Permanent.SetupPlayer(inst, s)
	if s.corestone_multiplier > 1 or s.gift_multiplier > 1 then
		Common.WatchPickups(inst, "drop multipliers", function(_, def, count)
			return Liri.DropExtra(def, count, s)
		end)
	end
	if s.market_full_set then
		Common.WatchMarketSets(inst)
	end
end

return Liri
