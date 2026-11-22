-- Tonic Swap: the size tonics reach your allies.
--
-- Drinking with Shrink (the smallify power: smaller, faster, takes more
-- damage) or Juggernaut (the juggernaut power, 50 stacks: bigger, slower,
-- hits harder, takes less) as your tonic also gives that power to the allies
-- near you: within your potion's reach (PotionDrinker:
-- GetTotalPotionAOEHealRadius, the radius its heal reaches allies in: 6 plus
-- talents). Each ally gets it the game's own way of giving an ally a power
-- (TheNetEvent:ApplyPower, as the Head Hunter Juggernaut power buffs its
-- allies; online it reaches them too), for as long as it lasts on them (the
-- room, like yours), with the game's spore burst on them (fx_spores_shrink_all
-- / fx_spores_juggernaut_all, the size mushrooms' and the Head Hunter's).
-- Allies: the other players, and with tonic_size_allies_minions the players'
-- summoned and charmed fighters (the game's "playerminion" tag).
--
-- settings: tonic_size_allies = true (false: only you, the game's);
-- tonic_size_allies_minions = false.
local SizeAllies = {}

SizeAllies.POWERS = { smallify = "fx_spores_shrink_all", juggernaut = "fx_spores_juggernaut_all" }
SizeAllies.SLOT = "TONICS"
SizeAllies.minions = false

local function Log(msg)
	print("[Tonic Swap] " .. tostring(msg))
end

local function Dist2(a, b)
	local ax, az = a.Transform:GetWorldXZ()
	local bx, bz = b.Transform:GetWorldXZ()
	return (ax - bx) * (ax - bx) + (az - bz) * (az - bz)
end

-- The tonic just drunk: its power and stacks, if it's a size tonic.
function SizeAllies.SizePower(item)
	local def = type(item) == "table" and item.GetDef ~= nil and item:GetDef() or nil
	if def == nil or (item.slot or def.slot) ~= SizeAllies.SLOT then
		return nil
	end
	local usage = def.usage_data
	local power = usage ~= nil and usage.power or nil
	if power == nil or SizeAllies.POWERS[power] == nil then
		return nil
	end
	return power, usage.power_stacks
end

-- The allies in reach of the drinker.
function SizeAllies.Allies(inst, radius)
	local list, seen = {}, { [inst] = true }
	local r2 = radius * radius
	local function Consider(ent)
		if ent ~= nil and not seen[ent] and ent:IsValid() and ent.Transform ~= nil and not ent:IsInLimbo()
			and (ent.IsDead == nil or not ent:IsDead()) and ent.components ~= nil and ent.components.powermanager ~= nil
			and Dist2(inst, ent) <= r2 then
			seen[ent] = true
			list[#list + 1] = ent
		end
	end
	for _, player in ipairs(TheNet:GetPlayersOnRoomChange() or {}) do
		Consider(player)
	end
	if SizeAllies.minions then
		local ok, entityutil = pcall(require, "util.entityutil")
		if ok and entityutil.GetNetEntities ~= nil then
			for _, minion in ipairs(entityutil.GetNetEntities({ required_tags = { "playerminion" } }) or {}) do
				Consider(minion)
			end
		end
	end
	return list
end

function SizeAllies.OnDrink(inst, item)
	if not inst:IsLocal() then
		return 0
	end
	local power, stacks = SizeAllies.SizePower(item)
	if power == nil or TheNetEvent == nil or TheNetEvent.ApplyPower == nil then
		return 0
	end
	local drinker = inst.components.potiondrinker
	local radius = drinker ~= nil and drinker.GetTotalPotionAOEHealRadius ~= nil and drinker:GetTotalPotionAOEHealRadius() or TUNING.POTION_AOE_RADIUS_DEFAULT
	local allies = SizeAllies.Allies(inst, radius)
	local fx = SizeAllies.POWERS[power]
	local powerutil = require "util.powerutil"
	for _, ally in ipairs(allies) do
		TheNetEvent:ApplyPower(inst.GUID, ally.GUID, power, stacks)
		if fx ~= nil and (Prefabs == nil or Prefabs[fx] ~= nil) then
			pcall(powerutil.SpawnFxOnEntity, fx, ally)
		end
	end
	if #allies > 0 then
		Log(string.format("size tonic (%s): %d all%s in reach got it too", power, #allies, #allies == 1 and "y" or "ies"))
	end
	return #allies
end

function SizeAllies.SetupPlayer(inst, Call)
	if inst.tonicswap_sizeallies then
		return
	end
	inst.tonicswap_sizeallies = true
	inst:ListenForEvent("drink_potion", function(i, item)
		Call("size tonic for allies", SizeAllies.OnDrink, i, item)
	end)
end

function SizeAllies.Install(settings)
	if settings.tonic_size_allies == false then
		return false, "off"
	end
	SizeAllies.minions = settings.tonic_size_allies_minions == true
	local PD = require "components.potiondrinker"
	if type(PD) ~= "table" or type(PD.GetTotalPotionAOEHealRadius) ~= "function" or type(PD.DrinkPotionSlot) ~= "function" then
		return false, "a game update changed PotionDrinker"
	end
	return true, "size tonics (Shrink, Juggernaut) reach allies within your potion's reach" .. (SizeAllies.minions and ", summoned fighters too" or "")
end

return SizeAllies
