-- Tonic Swap: the Alchemist's Gem no longer refills your potion (0.7.13).
--
-- The Alchemist's Gem is the gem version of the Perfect Pairing power (the
-- game makes it from the power's def: defs/powers/playerpowers.lua,
-- Power.ProcessPowerGemVersion). Its text is only "Increased Potion
-- effectiveness", but it runs the power's whole setup, refill included:
-- RefillPotion(pow:GetVar("charges")). The gem's numbers have no charges, so
-- that's RefillPotion(nil), which the game reads as "refill everything"
-- (PotionDrinker:RefillPotion -> InitializePotions). And a gem power is added
-- again whenever your gear's powers change (PowerManager:OnLoadoutChanged: a
-- weapon or armour bought and put on at the market, your gems levelling up at
-- the end of a hunt, Two Weapons' both-weapons gems when your gems or weapons
-- change), so every time: a full potion (user 2026-11-13: "buying at the
-- market refills all potions / finishing a hunt refills all potions / some
-- powers fill all potions in repeat ... the power with the cheese").
-- Here: when the gem version is added and its numbers have no charges, it's
-- set up as already done (its own did_init), so the game's setup does the rest
-- (the bonus healing) without the refill. The Perfect Pairing power itself
-- (with charges: 1 / 2 / 3) still refills when you take it, as the game.
-- settings: gem_refill_fix = true (false: the game's).
local GemRefill = {}

-- gem versions of powers whose setup refills by their "charges" number
GemRefill.POWERS = { "gem_perfect_pairing" }
GemRefill.enabled = false

local function NoCharges(pow)
	if type(pow) ~= "table" or type(pow.GetVar) ~= "function" then
		return false
	end
	local ok, charges = pcall(pow.GetVar, pow, "charges")
	return ok and charges == nil
end
GemRefill.NoCharges = NoCharges

-- Power: defs.powers; G: the mod's guard.
function GemRefill.Install(Power, G)
	local items = type(Power) == "table" and type(Power.Items) == "table" and Power.Items.EQUIPMENT or nil
	if type(items) ~= "table" then
		return false, "a game update changed the gem powers (Power.Items.EQUIPMENT)"
	end
	local done, missing = {}, {}
	for _, name in ipairs(GemRefill.POWERS) do
		local def = items[name]
		if type(def) ~= "table" or type(def.on_add_fn) ~= "function" then
			missing[#missing + 1] = name
		elseif not rawget(def, "tonicswap_gemrefill") then
			rawset(def, "tonicswap_gemrefill", true)
			local orig = def.on_add_fn
			def.on_add_fn = function(pow, inst, ...)
				if GemRefill.enabled then
					G.Call("the Alchemist's Gem's refill", function()
						local pd = type(pow) == "table" and pow.persistdata or nil
						if pd ~= nil and not pd.did_init and NoCharges(pow) then
							pd.did_init = true -- (the game's own "refilled already")
						end
					end)
				end
				return orig(pow, inst, ...)
			end
			done[#done + 1] = name
		else
			done[#done + 1] = name
		end
	end
	GemRefill.enabled = #done > 0
	if #done == 0 then
		return false, "not found: " .. table.concat(missing, ", ")
	end
	return true, "gems that don't refill your potion: " .. table.concat(done, ", ")
		.. (#missing > 0 and (" (not found: " .. table.concat(missing, ", ") .. ")") or "")
end

return GemRefill
