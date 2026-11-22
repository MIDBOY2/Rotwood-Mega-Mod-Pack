-- Two Weapons: a new character starts with two random basic weapons instead of the
-- game's (the basic Hammer, with the basic Spear in the bag): one in hand, the
-- other as your other weapon (the swap button), picked from starting_pairs.
--
-- "New character" is the game's own signal: it loads a player with no saved
-- player data (inst:PostLoadWorld(nil): prefabs/player_side.lua for a character
-- made on the main menu, widgets/ftf/characterselectioningame.lua for one made in
-- camp). An existing character always has its saved data, so it's never touched.
-- The weapons are the game's basic ones (itemforge, like its starting gear),
-- equipped the game's way (EquipSingleItem: the other one first, then the one in
-- hand, so Two Weapons remembers the pair); the game's starting weapons that
-- aren't in the pair leave the bag. The character's first save keeps them.
--
-- Their weapon racks in camp are unlocked too (starting_pair_unlocks_racks): each
-- character fills a rack (weapon_rack_*, components/metaprogressstore.lua, the
-- WEAPON_UNLOCKS progress of defs/metaprogression/weaponunlocks.lua) with
-- Corestones to unlock its weapon type. For the two starting weapons that rack
-- is left as the game leaves it after the last deposit: its progress filled and
-- claimed, the weapon type unlocked (UnlockTracker:UnlockWeaponType). The rack's
-- reward (another basic weapon, put in your hands) isn't given: you hold it
-- already. The Hammer and Spear racks are open for everyone already. A weapon
-- whose rack needs a DLC you don't have (the Greatsword: Draco) isn't picked.

local StartPair = {}

-- names in the settings -> the game's basic weapons
StartPair.WEAPONS = {
	hammer = "hammer_basic",
	spear = "polearm_basic",
	greatsword = "cleaver_basic",
	striker = "shotput_basic",
	cannon = "cannon_basic",
	bow = "bow_basic",
}

-- the default pool (the user's list, 2026-11-10): in hand + other
StartPair.DEFAULT_PAIRS = {
	"spear+striker", "spear+cannon", "spear+bow",
	"hammer+striker", "hammer+cannon", "hammer+bow",
	"greatsword+striker", "greatsword+cannon", "greatsword+bow",
	"striker+hammer", "striker+spear", "striker+greatsword", "striker+bow",
	"cannon+hammer", "cannon+spear", "cannon+striker", "cannon+greatsword",
	"bow+hammer", "bow+spear", "bow+greatsword", "bow+striker",
}

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "spear + striker" -> "polearm_basic", "shotput_basic" (nil, why when it isn't a pair)
function StartPair.Parse(text)
	if type(text) ~= "string" then
		return nil, nil, "not text"
	end
	local a, b = text:match("^(.-)%+(.-)$")
	if a == nil then
		return nil, nil, "no '+'"
	end
	a, b = trim(a):lower():gsub("%s", ""), trim(b):lower():gsub("%s", "")
	local wa, wb = StartPair.WEAPONS[a], StartPair.WEAPONS[b]
	if wa == nil or wb == nil then
		return nil, nil, "unknown weapon (" .. (wa == nil and a or b) .. ")"
	end
	if wa == wb then
		return nil, nil, "the same weapon twice"
	end
	return wa, wb
end

-- The usable pairs from the settings, and the entries that weren't.
function StartPair.Pool(list)
	local pool, bad = {}, {}
	for _, text in ipairs(type(list) == "table" and list or StartPair.DEFAULT_PAIRS) do
		local a, b, why = StartPair.Parse(text)
		if a ~= nil then
			pool[#pool + 1] = { hand = a, other = b, text = text }
		else
			bad[#bad + 1] = tostring(text) .. ": " .. tostring(why)
		end
	end
	return pool, bad
end

-- The weapon's rack progress (defs/metaprogression/weaponunlocks.lua), or nil.
function StartPair.RackDef(id, Equipment, MetaProgress)
	local def = Equipment.Items.WEAPON[id]
	local wtype = def ~= nil and def.weapon_type or nil
	local defs = MetaProgress ~= nil and MetaProgress.Items ~= nil and MetaProgress.Slots ~= nil
		and MetaProgress.Items[MetaProgress.Slots.WEAPON_UNLOCKS] or nil
	if type(wtype) ~= "string" or defs == nil then
		return nil, wtype
	end
	return defs[wtype:lower()], wtype
end

-- Can this character have the weapon? (its rack doesn't need a DLC you don't have)
function StartPair.Available(id, Equipment, MetaProgress, dlc_ready)
	local pdef = StartPair.RackDef(id, Equipment, MetaProgress)
	local tags = pdef ~= nil and pdef.tags or nil
	if tags ~= nil and tags.requires_dlc_draco then
		return dlc_ready ~= nil and dlc_ready() == true
	end
	return true
end

-- Unlock the weapon's rack for this character, the state the game leaves after
-- the last deposit (see the top). Returns true (unlocked now), false (it already
-- was), or nil, why (no rack for it).
function StartPair.UnlockRack(inst, id, Equipment, MetaProgress)
	local pdef, wtype = StartPair.RackDef(id, Equipment, MetaProgress)
	if pdef == nil then
		return nil, "no rack for " .. tostring(wtype or id)
	end
	local c = inst.components
	local mpm, ut = c ~= nil and c.metaprogressmanager or nil, c ~= nil and c.unlocktracker or nil
	if mpm == nil or ut == nil then
		return nil, "no metaprogressmanager / unlocktracker"
	end
	local progress = mpm:ManifestProgress(pdef)
	local was = progress:GetNextReward() == nil and ut:IsWeaponTypeUnlocked(wtype)
	for _ = 1, 10 do -- a rack has one level (one reward); never loop on a surprise
		if progress:GetNextReward() == nil then
			break
		end
		if not progress:IsPendingLevel() then
			progress:GrantExperienceIfPossible(progress:GetEXPUntilNextLevel())
		end
		progress:OnPendingLevelClaimed()
	end
	ut:UnlockWeaponType(wtype)
	return not was
end

-- The racks' price tags (the Corestone number over a locked rack) for the
-- players here now (the game refreshes them when a player comes or goes).
function StartPair.RefreshRacks(ents, slot)
	for _, ent in pairs(ents or {}) do
		local store = type(ent) == "table" and ent.components ~= nil and ent.components.metaprogressstore or nil
		if store ~= nil and store.meta_progress == slot and store._RefreshTeamWidgets ~= nil then
			pcall(store._RefreshTeamWidgets, store)
		end
	end
end

-- Give the player one pair (pick = a pool entry). Returns the pair given, or nil, why.
function StartPair.Give(inst, pick, Equipment, itemforge)
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard == nil then
		return nil, "no inventory"
	end
	local defs = Equipment.Items.WEAPON
	local hand_def, other_def = defs[pick.hand], defs[pick.other]
	if hand_def == nil or other_def == nil then
		return nil, "the game has no " .. (hand_def == nil and pick.hand or pick.other)
	end
	local function own(def)
		for _, it in ipairs(hoard:GetSlotItems("WEAPON") or {}) do
			if it.id == def.name then
				return it
			end
		end
		local item = itemforge.CreateEquipment("WEAPON", def)
		hoard:AddToInventory("WEAPON", item)
		return item
	end
	local other = own(other_def)
	local hand = own(hand_def)
	hoard:EquipSingleItem("WEAPON", other)
	hoard:EquipSingleItem("WEAPON", hand)
	-- the game's starting weapons that aren't in the pair leave the bag
	local extra = {}
	for _, it in ipairs(hoard:GetSlotItems("WEAPON") or {}) do
		if it ~= hand and it ~= other and it.GetDef ~= nil and it:GetDef().tags ~= nil and it:GetDef().tags.starting_equipment then
			extra[#extra + 1] = it
		end
	end
	for _, it in ipairs(extra) do
		hoard:RemoveFromInventory(it)
	end
	-- Two Weapons' memory: the one in hand and the other one (set straight: its
	-- "a new weapon replaces the one in hand" rule would keep the game's hammer)
	local tw = inst.components.twoweapons
	if tw ~= nil then
		tw.cur = { id = hand.id, idx = hoard:GetItemIndex(hand) }
		tw.prev = { id = other.id, idx = hoard:GetItemIndex(other) }
	end
	return pick
end

-- Hook a player (AddPlayerPostInit): its first load with no saved data gets a pair.
-- racks (or nil: racks left alone): { MetaProgress = fn, dlc_ready = fn, ents = fn }
-- (functions: the game's modules are read when a character is made).
function StartPair.Attach(inst, pool, Equipment, itemforge, rand, log, racks)
	if inst.twoweapons_startpair or type(inst.PostLoadWorld) ~= "function" or #pool == 0 then
		return false
	end
	inst.twoweapons_startpair = true
	rand = rand or math.random
	local base = inst.PostLoadWorld
	inst.PostLoadWorld = function(self, data, ...)
		local r = table.pack(base(self, data, ...))
		if data == nil and (self.IsLocal == nil or self:IsLocal()) then
			local MetaProgress, dlc_ready
			if racks ~= nil then
				local okm, m = pcall(racks.MetaProgress)
				MetaProgress = okm and m or nil
				dlc_ready = function()
					local okd, d = pcall(racks.dlc_ready)
					return okd and d == true
				end
			end
			-- not a weapon whose rack needs a DLC you don't have
			local choices = pool
			if MetaProgress ~= nil then
				choices = {}
				for _, p in ipairs(pool) do
					if StartPair.Available(p.hand, Equipment, MetaProgress, dlc_ready)
						and StartPair.Available(p.other, Equipment, MetaProgress, dlc_ready) then
						choices[#choices + 1] = p
					end
				end
				if #choices == 0 then
					choices = pool
				end
			end
			local pick = choices[rand(#choices)]
			local ok, given, why = pcall(StartPair.Give, self, pick, Equipment, itemforge)
			if log ~= nil then
				if not ok then
					log("new character's weapons skipped (the game's): " .. tostring(given))
				elseif given == nil then
					log("new character's weapons skipped (the game's): " .. tostring(why))
				else
					log("new character: " .. given.text .. " (" .. given.hand .. " in hand, " .. given.other .. " the other)")
				end
			end
			-- their racks in camp: unlocked for this character
			if ok and given ~= nil and MetaProgress ~= nil then
				local opened = {}
				for _, id in ipairs({ given.hand, given.other }) do
					local oku, unlocked, why2 = pcall(StartPair.UnlockRack, self, id, Equipment, MetaProgress)
					if oku and unlocked then
						opened[#opened + 1] = id
					elseif log ~= nil and (not oku or unlocked == nil) then
						log("new character: " .. id .. "'s rack left as it was (" .. tostring(oku and why2 or unlocked) .. ")")
					end
				end
				if #opened > 0 then
					local oke, ents = pcall(racks.ents)
					StartPair.RefreshRacks(oke and ents or nil, MetaProgress.Slots.WEAPON_UNLOCKS)
					if log ~= nil then
						log("new character: weapon racks unlocked in camp: " .. table.concat(opened, ", "))
					end
				end
			end
		end
		return table.unpack(r, 1, r.n)
	end
	return true
end

return StartPair
