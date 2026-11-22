-- Armor Dyes 0.4.0: loadouts remember their dyes, and the loadout statue shows
-- them (user 2026-11-14: "make loadouts remember the armor dye. and display
-- that too"; "make the loadout statue display them": the Morphic armour's boss
-- look, the statue showed plain Morphic armour).
--
-- Loadouts (the game's components/playerloadouts.lua) save the player's state
-- per loadout: talent points and which gem sits where. Here each loadout also
-- keeps the dye on each piece it wears ({ set shown, dye } per slot, in the
-- game's own loadout table, saved with the character), and equipping the
-- loadout puts those dyes back on (the game's dye component: equipmentdyer,
-- one dye per armour set). A dye goes on the set the piece SHOWS: a Morphic
-- piece with Mother Treek's gem shows Treek's armour and wears Treek's dyes
-- (the game draws the shown set: ItemInstance:GetItemAppearanceID).
-- Loadouts saved before this keep the dyes as they are when equipped.
--   loadout_dyes = "auto": a dye you pick while wearing a loadout goes into it
--                  straight away (and its statue changes with it)
--   loadout_dyes = "save": like gems: a changed dye marks the loadout changed,
--                  saving it keeps the dye, switching loadouts puts its own back
--   loadout_dyes = false: dyes are not part of loadouts (as before)
--
-- The statue (components/loadoutmannequin.lua) only keeps the item names of
-- the loadout's pieces, and draws those: a Morphic piece shows as plain Morphic
-- armour and no dye shows (it has no dye component). Here, when the statue
-- copies a loadout of a player on this machine, it also keeps the loadout's
-- look: the set each piece shows (Morphic gem's boss look, a mirage look) and
-- the dye on it, saved with the statue, and draws those. A statue of a player
-- on another machine keeps the look it had (the game's when it has none).
-- statue_look = false: the game's statue.
local Loadouts = {}

Loadouts.KEY = "armordyes" -- in the game's loadout table
Loadouts.LOOK_KEY = "armordyes_look" -- in the statue's save
Loadouts.ARMOUR = { "HEAD", "BODY", "WAIST" }
Loadouts.STATUE_SLOTS = { "BODY", "HEAD", "WAIST", "WEAPON" } -- (the game's LOADOUT_SLOTS)
Loadouts.READY_DELAY = 1 -- seconds after a player is made before its dye changes count (its save loading puts dyes on)
Loadouts.mode = nil -- "auto" | "save" | nil (off)
Loadouts.statue = false

local Main, Cosmetic, Equipment, EquipmentGem

local errors = 0
local function Log(msg)
	print("[Armor Dyes] " .. tostring(msg))
end
local function Report(where, err)
	if errors < 8 then
		errors = errors + 1
		Log(where .. " skipped: " .. tostring(err))
	end
end
Loadouts.Report = Report

local function Call(where, fn, ...)
	local r = table.pack(pcall(fn, ...))
	if not r[1] then
		Report(where, r[2])
		return false
	end
	return true, table.unpack(r, 2, r.n)
end

----------------------------------------------------------------------------
-- What's worn and what's on it

function Loadouts.Slots()
	if Main ~= nil and Main.weapon_on then
		return { "HEAD", "BODY", "WAIST", "WEAPON" }
	end
	return Loadouts.ARMOUR
end

local function Comps(inst)
	return inst ~= nil and inst.components or nil
end
local function Dyer(player)
	local c = Comps(player)
	return c ~= nil and c.equipmentdyer or nil
end
local function Hoard(player)
	local c = Comps(player)
	return c ~= nil and c.inventoryhoard or nil
end

-- a dye the game knows for this piece (a dye from settings since removed: no)
function Loadouts.Known(slot, set, dye)
	local list = Cosmetic ~= nil and Cosmetic.EquipmentDyes[slot] or nil
	return type(dye) == "string" and type(set) == "string" and list ~= nil and list[set] ~= nil and list[set][dye] ~= nil
end

function Loadouts.Applied(dyer, slot, set)
	local t = dyer ~= nil and type(dyer.applied_dyes) == "table" and dyer.applied_dyes[slot] or nil
	return type(t) == "table" and t[set] or nil
end

-- the set an item shows (the game: a mirage look, else the Morphic gem's boss
-- look, else its own)
function Loadouts.ShownSet(item)
	if item == nil then
		return nil
	end
	if type(item.GetItemAppearanceID) == "function" then
		local ok, id = pcall(item.GetItemAppearanceID, item)
		if ok and type(id) == "string" then
			return id
		end
	end
	local def = type(item.GetDef) == "function" and item:GetDef() or nil
	return def ~= nil and def.name or nil
end

-- { slot = { set = shown set, dye = dye name or false } } for what's worn now
function Loadouts.Current(player)
	local hoard, dyer = Hoard(player), Dyer(player)
	if hoard == nil or dyer == nil then
		return nil
	end
	local out = {}
	for _, slot in ipairs(Loadouts.Slots()) do
		local set = Loadouts.ShownSet(hoard:GetEquippedItem(slot))
		if set ~= nil then
			out[slot] = { set = set, dye = Loadouts.Applied(dyer, slot, set) or false }
		end
	end
	return out
end

local function ValidEntry(e)
	return type(e) == "table" and type(e.set) == "string" and (e.dye == false or type(e.dye) == "string")
end
Loadouts.ValidEntry = ValidEntry

----------------------------------------------------------------------------
-- Loadouts

-- the loadout's dyes back on (after the game equips it). Returns how many changed.
function Loadouts.ApplyLoadout(pl, loadout_id)
	local loadout = pl:GetLoadout(loadout_id)
	local saved = loadout ~= nil and loadout[Loadouts.KEY] or nil
	if type(saved) ~= "table" then
		return 0 -- a loadout from before: the dyes stay as they are
	end
	local player = pl.inst
	if player == nil or (player.IsLocal ~= nil and not player:IsLocal()) then
		return 0
	end
	local dyer = Dyer(player)
	if dyer == nil or dyer.SetEquipmentDye == nil then
		return 0
	end
	local changed = 0
	rawset(pl, "armordyes_applying", (rawget(pl, "armordyes_applying") or 0) + 1)
	local ok, err = pcall(function()
		for _, slot in ipairs(Loadouts.Slots()) do
			local e = saved[slot]
			if ValidEntry(e) then
				local now = Loadouts.Applied(dyer, slot, e.set)
				if e.dye == false then
					if now ~= nil and Cosmetic.EquipmentDyes[slot] ~= nil and Cosmetic.EquipmentDyes[slot][e.set] ~= nil then
						dyer:SetEquipmentDye(slot, e.set, nil)
						changed = changed + 1
					end
				elseif e.dye ~= now and Loadouts.Known(slot, e.set, e.dye) then
					if dyer:SetEquipmentDye(slot, e.set, e.dye) then
						changed = changed + 1
					end
				end
			end
		end
	end)
	rawset(pl, "armordyes_applying", rawget(pl, "armordyes_applying") - 1)
	if not ok then
		error(err, 0)
	end
	return changed
end

-- ("save") do the dyes worn differ from the loadout's?
function Loadouts.DyesDirty(pl)
	local loadout = pl:GetLoadout(pl:GetCurrentLoadoutID())
	local saved = loadout ~= nil and loadout[Loadouts.KEY] or nil
	if type(saved) ~= "table" then
		return false
	end
	local cur = Loadouts.Current(pl.inst)
	for slot, e in pairs(cur or {}) do
		local s = saved[slot]
		-- (a piece with no entry, or another set shown: the game's own gear / gem check)
		if ValidEntry(s) and s.set == e.set and s.dye ~= e.dye then
			return true
		end
	end
	return false
end

-- ("auto") a dye just picked goes into the loadout worn, when that loadout's
-- piece is the one worn and its gems are as saved (else saving it does it)
function Loadouts.AutoStore(player, slot)
	local pl = Comps(player) ~= nil and player.components.playerloadouts or nil
	if pl == nil or (rawget(pl, "armordyes_applying") or 0) > 0 or type(slot) ~= "string" then
		return false
	end
	if player.IsLocal ~= nil and not player:IsLocal() then
		return false
	end
	local id = pl:GetCurrentLoadoutID()
	local loadout = id ~= nil and pl:GetLoadout(id) or nil
	local hoard, dyer = Hoard(player), Dyer(player)
	if loadout == nil or hoard == nil or dyer == nil then
		return false
	end
	local item = hoard:GetEquippedItem(slot)
	local ok_l, litem = pcall(pl.GetLoadoutItem, pl, id, slot)
	if item == nil or not ok_l or litem ~= item then
		return false
	end
	if pl.AreGemsDirty ~= nil and pl:AreGemsDirty() then
		return false
	end
	local set = Loadouts.ShownSet(item)
	if set == nil then
		return false
	end
	local dye = Loadouts.Applied(dyer, slot, set) or false
	local saved = loadout[Loadouts.KEY]
	if type(saved) ~= "table" then
		saved = {}
		loadout[Loadouts.KEY] = saved
	end
	local old = saved[slot]
	if ValidEntry(old) and old.set == set and old.dye == dye then
		return false
	end
	saved[slot] = { set = set, dye = dye }
	-- (the game's "this loadout changed": its statue copies it again)
	player:PushEvent("player_loadouts_changed", { loadout_id = id })
	return true
end

-- every player: a dye change counts once the player's save is on
function Loadouts.SetupPlayer(inst)
	if Loadouts.mode == nil or inst == nil or inst.ListenForEvent == nil then
		return false
	end
	local function Ready()
		rawset(inst, "armordyes_loadouts_ready", true)
	end
	if inst.DoTaskInTime ~= nil then
		inst:DoTaskInTime(Loadouts.READY_DELAY, Ready)
	else
		Ready()
	end
	inst:ListenForEvent("onequipmentdyechanged", function(player, data)
		if not rawget(player, "armordyes_loadouts_ready") then
			return
		end
		if Loadouts.mode == "auto" then
			Call("loadout dye", Loadouts.AutoStore, player, type(data) == "table" and data.equipment_slot or nil)
		elseif Loadouts.mode == "save" then
			local pl = player.components ~= nil and player.components.playerloadouts or nil
			if pl ~= nil and (rawget(pl, "armordyes_applying") or 0) == 0 then
				Call("loadout dye", pl.EvaluateDirty, pl)
			end
		end
	end)
	return true
end

function Loadouts.InstallLoadouts(PlayerLoadouts)
	for _, name in ipairs({ "GetCurrentPlayerState", "EquipLoadout", "EvaluateDirty", "GetLoadout", "GetCurrentLoadoutID", "IsLoadoutDirty", "SetLoadoutDirty", "GetLoadoutItem" }) do
		if type(PlayerLoadouts[name]) ~= "function" then
			return false, "a game update changed loadouts (PlayerLoadouts:" .. name .. ")"
		end
	end
	if PlayerLoadouts.armordyes_hooked then
		return true
	end
	PlayerLoadouts.armordyes_hooked = true

	-- saving a loadout: its dyes with it
	local orig_state = PlayerLoadouts.GetCurrentPlayerState
	PlayerLoadouts.GetCurrentPlayerState = function(self, ...)
		local state = orig_state(self, ...)
		if Loadouts.mode ~= nil and type(state) == "table" then
			local ok, cur = Call("loadout save", Loadouts.Current, self.inst)
			if ok and cur ~= nil then
				state[Loadouts.KEY] = cur
			end
		end
		return state
	end

	-- equipping a loadout: its dyes back on
	local orig_equip = PlayerLoadouts.EquipLoadout
	PlayerLoadouts.EquipLoadout = function(self, loadout_id, ...)
		local r = table.pack(orig_equip(self, loadout_id, ...))
		if Loadouts.mode ~= nil then
			Call("loadout equip", Loadouts.ApplyLoadout, self, loadout_id)
		end
		return table.unpack(r, 1, r.n)
	end

	-- ("save") a changed dye marks the loadout changed, like a moved gem
	local orig_dirty = PlayerLoadouts.EvaluateDirty
	PlayerLoadouts.EvaluateDirty = function(self, ...)
		local r = table.pack(orig_dirty(self, ...))
		if Loadouts.mode == "save" and not self:IsLoadoutDirty() then
			local ok, dirty = Call("loadout check", Loadouts.DyesDirty, self)
			if ok and dirty then
				self:SetLoadoutDirty(true)
			end
		end
		return table.unpack(r, 1, r.n)
	end
	return true
end

----------------------------------------------------------------------------
-- The statue

-- the boss look a Morphic gem among these gems gives this slot (the game's
-- ItemInstance:GetMorphicGemAppearance, from the loadout's gems)
function Loadouts.MorphicFromGems(slot, gem_ids, hoard)
	if type(gem_ids) ~= "table" or hoard == nil or hoard.GetGemById == nil then
		return nil
	end
	local morphic = EquipmentGem ~= nil and EquipmentGem.Type ~= nil and EquipmentGem.Type.MORPHIC or "MORPHIC"
	for _, id in pairs(gem_ids) do
		local ok, gem = pcall(hoard.GetGemById, hoard, id)
		local def = ok and gem ~= nil and type(gem.GetDef) == "function" and gem:GetDef() or nil
		if def ~= nil and def.gem_type == morphic and type(def.armour_appearance) == "string"
			and Equipment.FindItemInSlot(slot, def.armour_appearance) ~= nil then
			return def.armour_appearance
		end
	end
	return nil
end

-- what a loadout looks like: { items = { slot = item name }, show = { slot = set
-- shown }, dyes = { slot = dye } }, nil when the loadout is gone
function Loadouts.LookOf(player, loadout_id)
	local pl = Comps(player) ~= nil and player.components.playerloadouts or nil
	local hoard = Hoard(player)
	if pl == nil or hoard == nil or loadout_id == nil then
		return nil
	end
	local loadout = pl:GetLoadout(loadout_id)
	local equipment = loadout ~= nil and pl:GetLoadoutEquipment(loadout_id) or nil
	if type(equipment) ~= "table" then
		return nil
	end
	local worn = pl:GetCurrentLoadoutID() == loadout_id and not pl:IsLoadoutDirty()
	local gem_data = type(loadout.gem_data) == "table" and loadout.gem_data or nil
	local has_gems = gem_data ~= nil and next(gem_data) ~= nil
	local saved = Loadouts.mode ~= nil and type(loadout[Loadouts.KEY]) == "table" and loadout[Loadouts.KEY] or {}
	local dyer = Dyer(player)
	local look = { items = {}, show = {}, dyes = {} }
	for _, slot in ipairs(Loadouts.STATUE_SLOTS) do
		local item = equipment[slot]
		local def = item ~= nil and type(item.GetDef) == "function" and item:GetDef() or nil
		if def ~= nil and type(def.name) == "string" then
			look.items[slot] = def.name
			local show
			if worn then
				show = Loadouts.ShownSet(item)
			else
				-- the loadout's look: a mirage on the item, else the Morphic gem it keeps there
				show = type(item.GetAppearanceOverrideID) == "function" and item:GetAppearanceOverrideID() or nil
				if show == nil then
					if has_gems then
						show = Loadouts.MorphicFromGems(slot, gem_data[slot], hoard)
					elseif type(item.GetMorphicGemAppearance) == "function" then
						show = item:GetMorphicGemAppearance()
					end
				end
			end
			if type(show) ~= "string" or Equipment.FindItemInSlot(slot, show) == nil then
				show = def.name
			end
			look.show[slot] = show
			-- the dye: the loadout's for that look, else the one on that set now
			local e = saved[slot]
			local dye
			if ValidEntry(e) and e.set == show then
				dye = e.dye or nil
			else
				dye = Loadouts.Applied(dyer, slot, show)
			end
			if dye ~= nil and Loadouts.Known(slot, show, dye) and (slot ~= "WEAPON" or Main.weapon_on) then
				look.dyes[slot] = dye
			end
		end
	end
	return look
end

function Loadouts.SameLook(a, b)
	if a == nil or b == nil then
		return a == b
	end
	for _, part in ipairs({ "items", "show", "dyes" }) do
		local x, y = a[part] or {}, b[part] or {}
		for _, slot in ipairs(Loadouts.STATUE_SLOTS) do
			if x[slot] ~= y[slot] then
				return false
			end
		end
	end
	return true
end

-- a look read back from the statue's save (only names the game knows)
function Loadouts.ValidLook(t)
	if type(t) ~= "table" then
		return nil
	end
	local look = { items = {}, show = {}, dyes = {} }
	for _, slot in ipairs(Loadouts.STATUE_SLOTS) do
		local name = type(t.items) == "table" and t.items[slot] or nil
		local show = type(t.show) == "table" and t.show[slot] or nil
		local dye = type(t.dyes) == "table" and t.dyes[slot] or nil
		if type(name) == "string" and Equipment.FindItemInSlot(slot, name) ~= nil then
			look.items[slot] = name
			look.show[slot] = (type(show) == "string" and Equipment.FindItemInSlot(slot, show) ~= nil) and show or name
			if Loadouts.Known(slot, look.show[slot], dye) then
				look.dyes[slot] = dye
			end
		end
	end
	return next(look.items) ~= nil and look or nil
end

local function CopyLook(look)
	local c = { items = {}, show = {}, dyes = {} }
	for part, t in pairs(c) do
		for k, v in pairs(look[part] or {}) do
			t[k] = v
		end
	end
	return c
end

-- the statue draws the look it keeps: the shown set of each piece it holds,
-- with its dye (the dye drawing is Armor Dyes' own: Main.ApplySlot, told the
-- statue's dyes through its inventory)
function Loadouts.ShowLook(cmp)
	local inst = cmp.inst
	local inv = Comps(inst) ~= nil and inst.components.inventory or nil
	if inv == nil then
		return false
	end
	local look = rawget(cmp, "armordyes_look")
	local copied = type(cmp.copied_loadout) == "table" and cmp.copied_loadout or {}
	local display, swaps = {}, {}
	for _, slot in ipairs(Loadouts.STATUE_SLOTS) do
		local name = copied[slot]
		if look ~= nil and name ~= nil and look.items[slot] == name then
			local show = look.show[slot] or name
			if Equipment.FindItemInSlot(slot, show) == nil then
				show = name
			end
			display[slot] = { set = show, dye = look.dyes[slot] }
			if show ~= name then
				swaps[slot] = show
			end
		end
	end
	rawset(inv, "armordyes_display", next(display) ~= nil and display or nil)
	for _, slot in ipairs(Loadouts.STATUE_SLOTS) do
		if swaps[slot] ~= nil then
			inv:Equip(slot, swaps[slot])
		end
	end
	if Main ~= nil and Main.ApplySlot ~= nil and inv._GetEquippedDef ~= nil then
		for _, slot in ipairs(Loadouts.STATUE_SLOTS) do
			local def = inv:_GetEquippedDef(slot)
			if def ~= nil then
				Main.ApplySlot(inv, slot, def)
			end
		end
	end
	return true
end

-- the look for a statue copying this player's loadout; false = can't tell here
-- (a player on another machine, or not the statue's owner): keep what it has
function Loadouts.StatueLookFor(cmp, player_id, loadout_id)
	if cmp.inst == nil or (cmp.inst.IsLocal ~= nil and not cmp.inst:IsLocal()) then
		return false
	end
	local find = rawget(_G, "GetPlayerEntityFromPlayerID")
	local player = type(find) == "function" and find(player_id) or nil
	if player == nil or (player.IsValid ~= nil and not player:IsValid()) or (player.IsLocal ~= nil and not player:IsLocal()) then
		return false
	end
	if cmp.HasOwner ~= nil and cmp:HasOwner() and not cmp:IsOwnedBy(player) then
		return false
	end
	return Loadouts.LookOf(player, loadout_id)
end

function Loadouts.InstallStatue(LoadoutMannequin)
	for _, name in ipairs({ "SetLoadout", "_UpdateVisuals", "OnSave", "OnLoad", "ClearCopiedLoadout", "HasCopiedLoadout" }) do
		if type(LoadoutMannequin[name]) ~= "function" then
			return false, "a game update changed the loadout statue (LoadoutMannequin:" .. name .. ")"
		end
	end
	if LoadoutMannequin.armordyes_hooked then
		return true
	end
	LoadoutMannequin.armordyes_hooked = true

	local orig_visuals = LoadoutMannequin._UpdateVisuals
	LoadoutMannequin._UpdateVisuals = function(self, ...)
		rawset(self, "armordyes_updates", (rawget(self, "armordyes_updates") or 0) + 1)
		local r = table.pack(orig_visuals(self, ...))
		if Loadouts.statue then
			Call("statue look", Loadouts.ShowLook, self)
		end
		return table.unpack(r, 1, r.n)
	end

	local orig_set = LoadoutMannequin.SetLoadout
	LoadoutMannequin.SetLoadout = function(self, player_id, loadout_id, ...)
		local changed = false
		if Loadouts.statue then
			local ok, look = Call("statue look", Loadouts.StatueLookFor, self, player_id, loadout_id)
			if ok and look ~= false then
				changed = not Loadouts.SameLook(look, rawget(self, "armordyes_look"))
				rawset(self, "armordyes_look", look)
			end
		end
		local before = rawget(self, "armordyes_updates") or 0
		local r = table.pack(orig_set(self, player_id, loadout_id, ...))
		-- only the look changed (a dye, a gem): the game didn't redraw, so redraw
		if changed and (rawget(self, "armordyes_updates") or 0) == before and self:HasCopiedLoadout() then
			Call("statue redraw", self._UpdateVisuals, self)
		end
		return table.unpack(r, 1, r.n)
	end

	local orig_clear = LoadoutMannequin.ClearCopiedLoadout
	LoadoutMannequin.ClearCopiedLoadout = function(self, ...)
		local r = table.pack(orig_clear(self, ...))
		if not self:HasCopiedLoadout() and rawget(self, "armordyes_look") ~= nil then
			rawset(self, "armordyes_look", nil)
			Call("statue look", Loadouts.ShowLook, self)
		end
		return table.unpack(r, 1, r.n)
	end

	local orig_save = LoadoutMannequin.OnSave
	LoadoutMannequin.OnSave = function(self, ...)
		local data = orig_save(self, ...)
		local look = rawget(self, "armordyes_look")
		if type(data) == "table" and look ~= nil and self:HasCopiedLoadout() then
			data[Loadouts.LOOK_KEY] = CopyLook(look)
		end
		return data
	end

	local orig_load = LoadoutMannequin.OnLoad
	LoadoutMannequin.OnLoad = function(self, data, ...)
		if type(data) == "table" then
			local ok, look = Call("statue look load", Loadouts.ValidLook, data[Loadouts.LOOK_KEY])
			rawset(self, "armordyes_look", ok and look or nil)
		end
		return orig_load(self, data, ...)
	end
	return true
end

----------------------------------------------------------------------------

-- deps = { Main, Cosmetic, Equipment, EquipmentGem, PlayerLoadouts, LoadoutMannequin }
function Loadouts.Install(settings, deps)
	Main, Cosmetic, Equipment, EquipmentGem = deps.Main, deps.Cosmetic, deps.Equipment, deps.EquipmentGem
	local mode = settings.loadout_dyes
	Loadouts.mode = (mode == "auto" or mode == "save") and mode or nil
	if mode ~= false and mode ~= "auto" and mode ~= "save" then
		Loadouts.mode = "auto"
		Log("loadout_dyes = " .. tostring(mode) .. " isn't \"auto\", \"save\" or false: \"auto\"")
	end
	local info = {}
	if Loadouts.mode ~= nil then
		local ok, why = false, "no loadouts in this game"
		if type(deps.PlayerLoadouts) == "table" then
			ok, why = Loadouts.InstallLoadouts(deps.PlayerLoadouts)
		end
		if ok then
			info[#info + 1] = "loadouts keep their dyes (" .. Loadouts.mode .. ")"
		else
			Loadouts.mode = nil
			info[#info + 1] = "loadout dyes off: " .. tostring(why)
		end
	else
		info[#info + 1] = "loadout dyes off in the settings"
	end
	Loadouts.statue = false
	if settings.statue_look ~= false then
		local ok, why = false, "no loadout statue in this game"
		if type(deps.LoadoutMannequin) == "table" then
			ok, why = Loadouts.InstallStatue(deps.LoadoutMannequin)
		end
		Loadouts.statue = ok == true
		info[#info + 1] = ok and "the loadout statue shows dyes and Morphic looks" or ("statue look off: " .. tostring(why))
	else
		info[#info + 1] = "the game's statue"
	end
	return table.concat(info, "; ")
end

return Loadouts
