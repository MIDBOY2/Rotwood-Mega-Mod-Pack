-- Two Weapons: Berserk carries over to your other weapon (1.0.11).
--
-- The Greatsword's Berserk (the game's cleaver_berserk_status: 12 s plus your
-- Meter, longer with every attack; +25% speed, 30% damage taken, attacks that
-- can't be interrupted, Multistrike when you mash) ends the moment the weapon
-- in your hand isn't a Greatsword: its on_update_fn removes it every frame
-- (defs/powers/statuseffectpowers.lua). So a swap ended it.
-- Here (user 2026-11-13: "carries over, you stay red, also must work with the
-- other weapon powers"), while your OTHER weapon is a Greatsword:
--  * Berserk stays on with the weapon in your hand: its timer runs, your
--    attacks with either weapon add time (the game's light / heavy attack
--    events), the speed, the damage taken, the attacks that can't be
--    interrupted, the Multistrike stance's extra protection. The Greatsword's
--    own moves (Multistrike hits, its Meter) stay with the Greatsword.
--  * you stay red: after a swap the game's Berserk look is put back on the
--    weapon in hand (its blade glow, the red aura if it was lost), and the
--    Greatsword's Berserk switches (no Meter, no Perfect Guard...) are set on
--    its fresh stategraph when you swap back.
--  * the Greatsword's Berserk weapon powers (Berserk on entering a fight room,
--    on drinking a potion, Headhunter's kill) work with it as your other
--    weapon too: they only asked for the weapon in hand.
-- It ends as the game's does (its timer, or when neither weapon is a
-- Greatsword any more). settings: berserk_carry = true (false: the game's).
local Berserk = {}

Berserk.POWER = "cleaver_berserk_status"
Berserk.TYPE = "CLEAVER" -- WEAPON_TYPES.CLEAVER: the Greatsword
-- the Greatsword weapon powers that start / extend Berserk, and the events they do it on
Berserk.WEAPON_POWERS = {
	berserk_on_room_enter = { "start_gameplay" },
	berserk_on_drink_potion = { "drink_potion" },
	berserk_headhunter = { "kill" },
}
-- the game's Berserk blade glow (BerserkColorBladePassive / Active)
Berserk.BLADE_PASSIVE = { 0.2, 0, 0, 0.1 }
Berserk.BLADE_ACTIVE = { 0.75, 0, 0, 0.75 }
Berserk.AURA = "berzerk_loop_front"
Berserk.enabled = false

local function Cmp(inst, name)
	return type(inst) == "table" and type(inst.components) == "table" and inst.components[name] or nil
end

function Berserk.HeldType(inst)
	local inv = Cmp(inst, "inventory")
	return inv ~= nil and inv.GetEquippedWeaponType ~= nil and inv:GetEquippedWeaponType() or nil
end

-- Is your other weapon (Two Weapons) a Greatsword?
function Berserk.OtherIsGreatsword(inst)
	local tw = Cmp(inst, "twoweapons")
	if tw == nil or tw.GetOther == nil then
		return false
	end
	local ok, other = pcall(tw.GetOther, tw)
	local def = ok and type(other) == "table" and other.GetDef ~= nil and other:GetDef() or nil
	return type(def) == "table" and def.weapon_type == Berserk.TYPE
end

-- While fn runs, this player's weapon in hand reads as the Greatsword (only
-- their inventory's GetEquippedWeaponType, put back right after).
function Berserk.AsGreatsword(inst, fn, ...)
	local inv = Cmp(inst, "inventory")
	if inv == nil then
		return fn(...)
	end
	local had = rawget(inv, "GetEquippedWeaponType")
	rawset(inv, "GetEquippedWeaponType", function() return Berserk.TYPE end)
	local r = table.pack(pcall(fn, ...))
	rawset(inv, "GetEquippedWeaponType", had)
	if not r[1] then
		error(r[2], 0)
	end
	return table.unpack(r, 2, r.n)
end

-- Should the game's code see a Greatsword now (held: no; the other one is)?
local function Carry(inst)
	return Berserk.enabled and Berserk.HeldType(inst) ~= Berserk.TYPE and Berserk.OtherIsGreatsword(inst)
end
Berserk.Carry = Carry

-- After a swap (next tick: the new weapon and its stategraph are in): the
-- Berserk switches and its look on what you hold now.
function Berserk.Refresh(pow, inst, SGPlayerCleaver, powerutil)
	if inst == nil or (inst.IsValid ~= nil and not inst:IsValid()) or pow == nil or pow.mem == nil or not pow.mem.active then
		return false
	end
	local pm = Cmp(inst, "powermanager")
	if pm == nil or pm.GetPowerByName == nil or pm:GetPowerByName(Berserk.POWER) ~= pow then
		return false -- (it ended meanwhile)
	end
	if SGPlayerCleaver ~= nil and SGPlayerCleaver.Fns ~= nil and SGPlayerCleaver.Fns.SetBerserkMode ~= nil and inst.sg ~= nil then
		SGPlayerCleaver.Fns.SetBerserkMode(inst, true, pow.mem.stats)
	end
	if inst.AnimState ~= nil and inst.AnimState.SetSymbolBloom ~= nil then
		local stats = pow.mem.stats
		local c = (stats ~= nil and stats.light_attack_canmultihit) and Berserk.BLADE_ACTIVE or Berserk.BLADE_PASSIVE
		inst.AnimState:SetSymbolBloom("feature01", c[1], c[2], c[3], c[4])
	end
	local aura = pow.mem.fx_ol
	if (aura == nil or (aura.IsValid ~= nil and not aura:IsValid())) and powerutil ~= nil and powerutil.SpawnFxOnEntity ~= nil
		and powerutil.MakeChildID ~= nil then
		pow.mem.fx_ol_child_id = powerutil.MakeChildID()
		pow.mem.fx_ol = powerutil.SpawnFxOnEntity(Berserk.AURA, inst, { ischild = true, childid = pow.mem.fx_ol_child_id })
	end
	return true
end

-- Power: defs.powers; G: the mod's guard; SGPlayerCleaver: stategraphs.sg_player_cleaver_common;
-- powerutil: util.powerutil.
function Berserk.Install(Power, G, SGPlayerCleaver, powerutil)
	local items = type(Power) == "table" and type(Power.Items) == "table" and Power.Items.STATUSEFFECT or nil
	local def = type(items) == "table" and items[Berserk.POWER] or nil
	if type(def) ~= "table" or type(def.on_update_fn) ~= "function" or type(def.event_triggers) ~= "table"
		or type(def.event_triggers.loadout_changed) ~= "function" then
		return false, "a game update changed the Berserk status (" .. Berserk.POWER .. ")"
	end
	if rawget(def, "twoweapons_berserk") then
		Berserk.enabled = true
		return true, Berserk.info
	end
	rawset(def, "twoweapons_berserk", true)

	-- the game's every-frame check: with the Greatsword as your other weapon, it sees one
	local orig_update = def.on_update_fn
	-- (worked out once per loadout: your weapons only change with one)
	def.on_update_fn = function(pow, inst, ...)
		local mem = type(pow) == "table" and pow.mem or nil
		local carry = mem ~= nil and mem.twoweapons_carry or nil
		if carry == nil then
			local okc, c = pcall(Carry, inst)
			carry = okc and c == true
			if mem ~= nil then
				mem.twoweapons_carry = carry
			end
		end
		if carry then
			return Berserk.AsGreatsword(inst, orig_update, pow, inst, ...)
		end
		return orig_update(pow, inst, ...)
	end

	-- a swap: the game's own handler, then the switches and the look on the new weapon
	local orig_loadout = def.event_triggers.loadout_changed
	def.event_triggers.loadout_changed = function(pow, inst, ...)
		if type(pow) == "table" and pow.mem ~= nil then
			pow.mem.twoweapons_carry = nil -- (your weapons changed: worked out again)
		end
		local r = table.pack(orig_loadout(pow, inst, ...))
		if Berserk.enabled and inst ~= nil and inst.DoTaskInTime ~= nil then
			inst:DoTaskInTime(0, function()
				G.Call("Berserk after the swap", Berserk.Refresh, pow, inst, SGPlayerCleaver, powerutil)
			end)
		end
		return table.unpack(r, 1, r.n)
	end

	-- the Greatsword's Berserk weapon powers, with it as your other weapon
	local wrapped = 0
	for name, events in pairs(Berserk.WEAPON_POWERS) do
		local okf, wdef = pcall(Power.FindPowerByName, name)
		local triggers = okf and type(wdef) == "table" and wdef.event_triggers or nil
		if type(triggers) == "table" and not rawget(wdef, "twoweapons_berserk") then
			rawset(wdef, "twoweapons_berserk", true)
			for _, ev in ipairs(events) do
				local orig = triggers[ev]
				if type(orig) == "function" then
					triggers[ev] = function(pow, inst, ...)
						local okc, carry = pcall(Carry, inst)
						if okc and carry then
							return Berserk.AsGreatsword(inst, orig, pow, inst, ...)
						end
						return orig(pow, inst, ...)
					end
					wrapped = wrapped + 1
				end
			end
		end
	end
	Berserk.enabled = true
	Berserk.info = string.format("Berserk carries over to your other weapon (%d of the Greatsword's Berserk weapon powers with it)", wrapped)
	return true, Berserk.info
end

return Berserk
