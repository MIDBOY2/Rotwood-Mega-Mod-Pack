-- Two Weapons: a smooth swap. Measured in the game (swap_timing): a swap took
-- about 21 ms in one frame (a frame is 16.7 ms at 60 a second). Now about
-- 1.3 ms in the swap's frame, the rest spread about 1 ms a frame:
--  * During the swap (the weapon still changes at once, same frame):
--    - the HUD's own reactions (power icons, weapon icon, weapon tips, the
--      off-screen marker, ...) and the game's metrics wait; everything that
--      plays (powers, stategraph, weight, stats) runs as usual;
--    - only the weapon's part of your look is redone (the game cleared and
--      redid all your armour too);
--    - your weight power stays when your weight class doesn't change;
--    - "max health / health changed" are skipped when nothing changed; the
--      panel's refresh and layout wait.
--  * The frame after: Skill Slots puts your slot skills right (a weapon's
--    skills come and go with it). It joins the swap's window: the skills
--    change at once, the HUD follows with the swap's (it was 6-7 ms in that
--    frame with the Cannon, mostly the HUD redoing icons and layout per skill).
--  * Then, one piece per frame: the HUD's reactions (2 frames after the
--    swap), the skill / power icons matched to your powers (3), their layout
--    (4), the panel's gear level (5), the panel's layout (6), the portrait
--    (7: only its weapon).
-- smooth_swap = false in the settings: the game's way.
local SmoothSwap = {}

local SLOT = "WEAPON"

SmoothSwap.STAGES = { hud = 2, icons = 3, powers = 4, panel = 5, layout = 6, portrait = 7 } -- ticks after the swap
SmoothSwap.last = {} -- stage name -> ms (for the swap timing line)
SmoothSwap.dirty = setmetatable({}, { __mode = "k" }) -- power icon widget -> reset rows
SmoothSwap.portraits = setmetatable({}, { __mode = "k" }) -- panel widget -> true
SmoothSwap.hooked = setmetatable({}, { __mode = "k" }) -- class -> true
SmoothSwap.pending = setmetatable({}, { __mode = "k" }) -- player -> the swap's pieces still to come
SmoothSwap.labels = setmetatable({}, { __mode = "k" }) -- function -> name (for the swap timing line)
SmoothSwap.hud_installed = nil
SmoothSwap.loose = setmetatable({}, { __mode = "k" }) -- power icon -> its icons widget (hidden until placed)
SmoothSwap.doomed = setmetatable({}, { __mode = "k" }) -- power icon of a power gone -> its icons widget (shown until the layout)
SmoothSwap.probe = nil -- the swap timing, while it measures a swap
SmoothSwap.trace = nil -- the swap timing: told of every look rebuilt
SmoothSwap.errors = 0
SmoothSwap.stats = { light_clone = 0, full_clone = 0, light_refresh = 0, weight_kept = 0 }

local function Clock()
	local os_lib = rawget(_G, "os")
	return os_lib ~= nil and os_lib.clock ~= nil and os_lib.clock() or nil
end

local function Log(msg)
	if SmoothSwap.errors < 10 then
		SmoothSwap.errors = SmoothSwap.errors + 1
		print("[Two Weapons] smooth swap: " .. tostring(msg))
	end
end

local function Timed(name, fn)
	local t = Clock()
	local ok, err = pcall(fn)
	if t ~= nil then
		SmoothSwap.last[name] = (Clock() - t) * 1000
	end
	if not ok then
		Log(name .. ": " .. tostring(err))
	end
end

local function Valid(e)
	return type(e) == "table" and (e.IsValid == nil or e:IsValid())
end

----------------------------------------------------------------------------
-- The player's events during the swap. The game's EntityScript:PushEvent,
-- with one difference: listeners that belong to HUD widgets (or the game's
-- metrics) are queued instead of called. The listeners themselves are never
-- touched (the game removes a listener by matching its function).

local source_of = setmetatable({}, { __mode = "k" })
local function SourceOf(fn)
	local s = source_of[fn]
	if s == nil then
		local info = debug.getinfo(fn, "S")
		s = info ~= nil and tostring(info.source or "") or ""
		source_of[fn] = s
	end
	return s
end

function SmoothSwap.IsHUD(inst, src, fn)
	if src == inst or type(src) ~= "table" then
		return false
	end
	return rawget(src, "widget") ~= nil or SourceOf(fn):find("/metrics.lua", 1, true) ~= nil
end

function SmoothSwap.Dispatch(inst, ev, data, queue)
	local probe = SmoothSwap.probe
	local all = rawget(inst, "eventlisteners")
	local listeners = all ~= nil and all[ev] or nil
	if listeners ~= nil then
		-- a list first: listeners may change while they're called
		local tocall, srcs, n = {}, {}, 0
		for src, fns in pairs(listeners) do
			for i = 1, #fns do
				n = n + 1
				tocall[n] = fns[i]
				srcs[n] = src
			end
		end
		for i = 1, n do
			local c = tocall[i]
			local fn = c.fn
			if fn ~= nil then -- not removed meanwhile
				if queue ~= nil and SmoothSwap.IsHUD(inst, srcs[i], fn) then
					queue[#queue + 1] = { c = c, src = srcs[i], ev = ev, data = data }
				elseif probe ~= nil then
					probe.Call(fn, inst, data)
				else
					fn(inst, data)
				end
			end
		end
	end
	if inst.sg ~= nil then
		inst.sg:PushEvent(ev, data)
	end
	if inst.brain ~= nil then
		inst.brain:PushEvent(ev, data)
	end
end

-- the game's PushEvent, unchanged by mods (else the queueing stays off)
function SmoothSwap.GamePushEvent()
	local ES = rawget(_G, "EntityScript")
	local push = type(ES) == "table" and rawget(ES, "PushEvent") or nil
	if type(push) ~= "function" then
		return nil
	end
	local info = debug.getinfo(push, "S")
	if info == nil or not tostring(info.source or ""):find("entityscript.lua", 1, true) then
		return nil
	end
	return push
end

----------------------------------------------------------------------------
-- The power icons, matched to the powers you have (instead of replaying each
-- power out / in of the swap): what the panel's full refresh did (it re-added
-- every power's icon), plus taking off the ones of powers gone.

function SmoothSwap.IsPowersWidget(w)
	return type(w) == "table" and type(rawget(w, "power_widgets")) == "table" and type(rawget(w, "skill_widget")) == "table"
		and type(rawget(w, "weight_widget")) == "table" and type(rawget(w, "power_idxs")) == "table"
		and type(rawget(w, "power_rows_idx")) == "table"
		and w.AddPower ~= nil and w.SetSkill ~= nil and w.SetWeight ~= nil and w.RemoveSkill ~= nil and w._LayoutPowers ~= nil
end

local function GameFn(fn, file)
	if type(fn) ~= "function" then
		return false
	end
	local info = debug.getinfo(fn, "S")
	return info ~= nil and tostring(info.source or ""):find(file, 1, true) ~= nil
end

function SmoothSwap.SyncPowerIcons(w, inst)
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	if pm == nil or type(pm.powers) ~= "table" or pm.GetAllPowersInDisplayOrder == nil then
		return false
	end
	local Power = require "defs.powers"
	local T = Power.Types
	local removed = false
	-- in a swap the icons' layout waits a frame: an icon of a power gone stays
	-- where it is until then, and goes in the same frame its row is laid out
	-- again (1.0.3: it went a frame before, a gap in the row for that frame)
	local defer = rawget(inst, "twoweapons_hold_hud") ~= nil
	for name, pw in pairs(w.power_widgets) do
		if pm.powers[name] == nil then
			if defer then
				SmoothSwap.doomed[pw] = w
			else
				pw:Remove()
			end
			w.power_widgets[name] = nil
			for i = #w.power_idxs, 1, -1 do
				if w.power_idxs[i] == name then
					table.remove(w.power_idxs, i)
				end
			end
			removed = true
		end
	end
	for name, ww in pairs(w.weight_widget) do
		if pm.powers[name] == nil then
			ww:Remove()
			w.weight_widget[name] = nil
		end
	end
	local stale = nil
	for name in pairs(w.skill_widget) do
		if pm.powers[name] == nil then
			stale = stale or {}
			stale[#stale + 1] = name
		end
	end
	if stale ~= nil then
		if GameFn(w.RemoveSkill, "playerpowerswidget.lua") then
			-- the game's own (one skill icon): take off the stale ones
			for _, name in ipairs(stale) do
				local sw = w.skill_widget[name]
				sw:Remove()
				w.skill_widget[name] = nil
			end
		else
			w:RemoveSkill() -- a mod's (Skill Slots: puts the skill icons right)
		end
	end
	for _, pow in ipairs(pm:GetAllPowersInDisplayOrder()) do
		local def = pow.def
		if def ~= nil then
			if def.power_type == T.SKILL then
				if w.skill_widget[def.name] == nil then
					w:SetSkill(pow.persistdata, true)
				end
			elseif def.power_type == T.WEIGHT then
				if w.weight_widget[def.name] == nil then
					w:SetWeight(pow.persistdata, true)
				end
			elseif w.power_widgets[def.name] == nil then
				w:AddPower(pow.persistdata, true)
			end
		end
	end
	if removed then
		w:_LayoutPowers(#w.power_rows_idx > 2)
	end
	return true
end

-- The queued HUD reactions, in two frames: first everything but the power
-- icons' widget (part = "others"), then the power icons (part = "icons"):
-- matched to your powers instead of replaying each power out / in, then that
-- widget's other queued reactions (Skill Slots' icon row), in order.
local function IsIconsEntry(e)
	local w = rawget(e.src, "widget")
	return w ~= nil and SmoothSwap.IsPowersWidget(w), w
end

local function Call(inst, e)
	local fn = e.c.fn
	if fn ~= nil and Valid(e.src) then -- still listening
		local ok, err = pcall(fn, inst, e.data)
		if not ok then
			Log(tostring(e.ev) .. ": " .. tostring(err))
		end
	end
end

function SmoothSwap.ReplayCalls(inst, queue, part)
	if part ~= "icons" then
		for _, e in ipairs(queue) do
			if not IsIconsEntry(e) then
				Call(inst, e)
			end
		end
	end
	if part == "others" then
		return
	end
	local sync, synced = {}, {}
	for _, e in ipairs(queue) do
		local icons, w = IsIconsEntry(e)
		if icons and (e.ev == "add_power" or e.ev == "remove_power") and not synced[w] then
			synced[w] = true
			sync[#sync + 1] = w
		end
	end
	for _, w in ipairs(sync) do
		if Valid(rawget(w, "inst")) then
			local ok, err = pcall(SmoothSwap.SyncPowerIcons, w, inst)
			if not ok then
				Log("power icons: " .. tostring(err))
			end
		end
	end
	for _, e in ipairs(queue) do
		local icons, w = IsIconsEntry(e)
		if icons and not (synced[w] and (e.ev == "add_power" or e.ev == "remove_power")) then
			Call(inst, e)
		end
	end
end

-- Run fn with the HUD held: icon layouts wait (flushed by the icon stage),
-- layout requests are dropped (the layout stage does one), character copies
-- in UI puppets only redo the weapon.
function SmoothSwap.Held(inst, fn, ...)
	local had = rawget(inst, "PushEvent")
	local push = inst.PushEvent
	local hold = rawget(inst, "twoweapons_hold_hud") or { panel = false, layout = false, powers = false }
	rawset(inst, "twoweapons_hold_hud", hold)
	rawset(inst, "twoweapons_light_clone", true)
	inst.PushEvent = function(self, ev, ...)
		if self == inst and ev == "refresh_hud" then
			hold.layout = true
			return
		end
		return push(self, ev, ...)
	end
	local results = table.pack(pcall(fn, ...))
	inst.PushEvent = had
	rawset(inst, "twoweapons_hold_hud", nil)
	rawset(inst, "twoweapons_light_clone", nil)
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

----------------------------------------------------------------------------
-- The panel's refresh (PlayerStatusWidget:OnCharacterChanged) without the
-- power icons (matched already), the portrait (its own frame) and the layout
-- (its own frame). false = the panel isn't the shape this expects: the game's
-- own refresh runs.
function SmoothSwap.LightRefresh(w)
	local owner = rawget(w, "owner")
	if owner == nil or w.player_level == nil or w.username == nil or w.player_title == nil or w.health_bar == nil
		or w.weapon_meter == nil or w.portrait == nil or w.portrait.Refresh == nil then
		return false
	end
	-- a weapon swap changes only the gear level (the weapon's level counts);
	-- the name, title, colours and spectating don't change with a weapon
	local playerutil = require "util.playerutil"
	w.player_level:SetLevel(playerutil.GetGearLevel(owner))
	SmoothSwap.portraits[w] = true
	SmoothSwap.stats.light_refresh = SmoothSwap.stats.light_refresh + 1
	return true
end

----------------------------------------------------------------------------
-- A character copy in a UI puppet (the portrait, the off-screen marker) after
-- a swap: only the weapon changed, so only the weapon is redone. false = the
-- puppet isn't a copy of this character apart from the weapon (the game's
-- full copy runs).

local function SameSet(a, b)
	a, b = a or {}, b or {}
	for k, v in pairs(a) do
		if b[k] ~= v then
			return false
		end
	end
	for k, v in pairs(b) do
		if a[k] ~= v then
			return false
		end
	end
	return true
end

function SmoothSwap.LightClone(puppet, character)
	local comps = puppet.components
	local pinv = comps ~= nil and comps.inventory or nil
	local cinv = character.components ~= nil and character.components.inventory or nil
	if pinv == nil or cinv == nil or type(pinv.equips) ~= "table" or type(cinv.equips) ~= "table"
		or pinv.equips[SLOT] == nil or pinv.Equip == nil then
		return false
	end
	for slot, name in pairs(cinv.equips) do
		if slot ~= SLOT and pinv.equips[slot] ~= name then
			return false
		end
	end
	for slot, name in pairs(pinv.equips) do
		if slot ~= SLOT and cinv.equips[slot] ~= name then
			return false
		end
	end
	if not SameSet(pinv.hidden_slots, cinv.hidden_slots) then
		return false
	end
	-- the dyes (the game's copy sets them too)
	local cd = character.components.equipmentdyer
	local pd = comps.equipmentdyer
	if cd ~= nil or pd ~= nil then
		if cd == nil or pd == nil or type(pd.applied_dyes) ~= "table" then
			return false
		end
		local Cosmetic = require "defs.cosmetics.cosmetics"
		for _, slot in ipairs(Cosmetic.DyeSlots or {}) do
			local set = cinv.equips[slot]
			local active = set ~= nil and cd:GetActiveDye(slot, set) or nil
			local want = active ~= nil and active.short_name or nil
			local have = set ~= nil and pd.applied_dyes[slot] ~= nil and pd.applied_dyes[slot][set] or nil
			if want ~= have then
				return false
			end
		end
	end
	local weapon = cinv.equips[SLOT]
	if pinv.equips[SLOT] ~= weapon then
		rawset(pinv, "twoweapons_light_equip", true)
		local ok, err = pcall(pinv.Equip, pinv, SLOT, weapon)
		rawset(pinv, "twoweapons_light_equip", nil)
		if not ok then
			error(err, 0)
		end
	end
	SmoothSwap.stats.light_clone = SmoothSwap.stats.light_clone + 1
	return true
end

function SmoothSwap.HookPuppetClass(cls)
	if type(cls) ~= "table" or SmoothSwap.hooked[cls] or type(cls.CloneCharacterWithEquipment) ~= "function" then
		return
	end
	SmoothSwap.hooked[cls] = true
	local clone = cls.CloneCharacterWithEquipment
	cls.CloneCharacterWithEquipment = function(self, character, skip_weapon, ...)
		if not skip_weapon and type(character) == "table" and rawget(character, "twoweapons_light_clone") then
			local ok, done = pcall(SmoothSwap.LightClone, self, character)
			if ok and done then
				return self
			end
			if not ok then
				Log("portrait copy: " .. tostring(done))
			end
		end
		SmoothSwap.stats.full_clone = SmoothSwap.stats.full_clone + 1
		return clone(self, character, skip_weapon, ...)
	end
end

----------------------------------------------------------------------------
-- Class hooks, each class once. They only act on entities marked by a swap.

-- The dodge's afterimages (the game's ghost trail: two copies of you on every
-- dodge, reused from dodge to dodge). Each copy takes your look again; the
-- game redoes only what changed (your armour stays on a reused copy), but a
-- weapon change made it clear and redo every slot (5 "Could not find anim
-- build" log lines each time). Their weapon change redoes only the weapon.
function SmoothSwap.IsCopy(inst)
	return type(inst) == "table" and rawget(inst, "prefabname") == "spiked_ghost"
end

-- Equipping the weapon in a swap redoes only the weapon's symbols (the game:
-- clear every slot's symbols, then redo every slot). Armour isn't touched, so
-- it stays as it was (dye tints included).
function SmoothSwap.HookInventoryClass(cls)
	if type(cls) ~= "table" or SmoothSwap.hooked[cls] then
		return SmoothSwap.hooked[cls] == true
	end
	if type(cls.Equip) ~= "function" or type(cls.ClearAllEquipSlots) ~= "function" or type(cls.RebuildCharacterArmour) ~= "function"
		or type(cls.ClearEquipSlotSymbols) ~= "function" or type(cls.OverrideEquipSlotSymbols) ~= "function"
		or type(cls._GetEquippedDef) ~= "function" then
		return false
	end
	SmoothSwap.hooked[cls] = true
	local EMPTY = {}
	local equip, clear_all, rebuild = cls.Equip, cls.ClearAllEquipSlots, cls.RebuildCharacterArmour
	cls.Equip = function(self, slot, name, ...)
		if slot == SLOT and (rawget(self, "twoweapons_light_equip") or SmoothSwap.IsCopy(self.inst))
			and not rawget(self, "twoweapons_weapon_only") then
			rawset(self, "twoweapons_weapon_only", true)
			local results = table.pack(pcall(equip, self, slot, name, ...))
			rawset(self, "twoweapons_weapon_only", nil)
			if not results[1] then
				error(results[2], 0)
			end
			return table.unpack(results, 2, results.n)
		end
		return equip(self, slot, name, ...)
	end
	cls.ClearAllEquipSlots = function(self, ...)
		if rawget(self, "twoweapons_weapon_only") then
			return self:ClearEquipSlotSymbols(SLOT, EMPTY)
		end
		return clear_all(self, ...)
	end
	cls.RebuildCharacterArmour = function(self, ...)
		if SmoothSwap.trace ~= nil then
			pcall(SmoothSwap.trace, self, rawget(self, "twoweapons_weapon_only") == true)
		end
		if rawget(self, "twoweapons_weapon_only") then
			local def = self:_GetEquippedDef(SLOT)
			if def ~= nil then
				self:OverrideEquipSlotSymbols(SLOT, def)
			end
			return
		end
		return rebuild(self, ...)
	end
	return true
end

-- The weight power is taken off and put back on at every weight change, even
-- within the same class; in a swap it stays when it's already the right one.
function SmoothSwap.WeightPowerCurrent(w)
	local pm = w.inst ~= nil and w.inst.components ~= nil and w.inst.components.powermanager or nil
	if pm == nil or type(w.weightpowers) ~= "table" or w.GetStatus == nil or pm.HasPower == nil then
		return false
	end
	local want = w.weightpowers[w:GetStatus()]
	if want == nil or not pm:HasPower(want) then
		return false
	end
	for _, def in pairs(w.weightpowers) do
		if def ~= want and pm:HasPower(def) then
			return false
		end
	end
	return true
end

function SmoothSwap.HookWeightClass(cls)
	if type(cls) ~= "table" or SmoothSwap.hooked[cls] or type(cls.UpdateWeightPower) ~= "function" then
		return
	end
	SmoothSwap.hooked[cls] = true
	local update = cls.UpdateWeightPower
	cls.UpdateWeightPower = function(self, ...)
		if self.inst ~= nil and rawget(self.inst, "twoweapons_hold_hud") ~= nil then
			local ok, same = pcall(SmoothSwap.WeightPowerCurrent, self)
			if ok and same then
				SmoothSwap.stats.weight_kept = SmoothSwap.stats.weight_kept + 1
				return
			end
		end
		return update(self, ...)
	end
end

-- A new power icon (the weapon's power after a swap) is made with no place in
-- the HUD (playerpowerswidget.lua: PowerWidget(...), then the layout puts it in
-- a row). While that layout waits (one frame, to the icon layout stage) the
-- game drew it at the middle of the screen, where a widget with no parent goes
-- (1.0.0: the Windbreaker's icon flickered there on each swap). So it's hidden
-- until a layout has placed it.
function SmoothSwap.HideLoose(w)
	for _, pw in pairs(w.power_widgets) do
		if type(pw) == "table" and rawget(pw, "parent") == nil and pw.IsShown ~= nil and pw:IsShown() then
			pw:Hide()
			SmoothSwap.loose[pw] = w
		end
	end
end

-- Right before a layout of the icons: the icons of powers gone go, the new
-- ones are shown, so the layout measures the rows as they'll be drawn (1.0.3
-- showed them after it: the game lines the rows up by what's shown, so the top
-- row stood an icon to the left until the panel's layout, 2 frames later).
-- The layout places every icon in a row right after, in the same frame.
function SmoothSwap.Settle(w)
	if next(SmoothSwap.doomed) ~= nil then
		for pw, owner in pairs(SmoothSwap.doomed) do
			if owner == w then
				SmoothSwap.doomed[pw] = nil
				if Valid(rawget(pw, "inst")) or rawget(pw, "inst") == nil then
					pw:Remove()
				end
			end
		end
	end
	if next(SmoothSwap.loose) ~= nil then
		for pw, owner in pairs(SmoothSwap.loose) do
			if owner == w then
				pw:Show()
			end
		end
	end
end

-- Right after it: the placed ones stay shown, one the layout didn't place
-- (never at the middle of the screen) is hidden again until one does.
function SmoothSwap.ShowPlaced(w)
	if next(SmoothSwap.loose) == nil then
		return
	end
	for pw, owner in pairs(SmoothSwap.loose) do
		if owner == w then
			if rawget(pw, "parent") ~= nil then
				SmoothSwap.loose[pw] = nil
				pw:Show()
			else
				pw:Hide()
			end
		end
	end
end

-- A layout of the icons, with the icons settled before it and the unplaced
-- hidden after it (an error in it: the same, then the error as it was)
function SmoothSwap.SettledLayout(layout, w, ...)
	local ok, err = pcall(SmoothSwap.Settle, w)
	if not ok then
		Log("power icons: " .. tostring(err))
	end
	local results = table.pack(pcall(layout, w, ...))
	ok, err = pcall(SmoothSwap.ShowPlaced, w)
	if not ok then
		Log("power icons: " .. tostring(err))
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- the HUD classes (once): the power icons' layout can wait, the panel can
-- refresh lightly, UI puppets can copy only the weapon
function SmoothSwap.InstallHUD()
	if SmoothSwap.hud_installed ~= nil then
		return SmoothSwap.hud_installed
	end
	SmoothSwap.hud_installed = false
	local package_lib = rawget(_G, "package")
	local loaded = package_lib ~= nil and package_lib.loaded or {}
	for _, key in ipairs({ "widgets/playerpuppet", "widgets.playerpuppet" }) do
		SmoothSwap.HookPuppetClass(loaded[key])
	end
	SmoothSwap.game_push = SmoothSwap.GamePushEvent()
	local ok1, PPW = pcall(require, "widgets/ftf/playerpowerswidget")
	local ok2, PSW = pcall(require, "widgets/ftf/playerstatuswidget")
	if not ok1 or not ok2 or type(PPW) ~= "table" or type(PSW) ~= "table" or type(PPW.Layout) ~= "function"
		or type(PSW.OnCharacterChanged) ~= "function" then
		return false
	end
	local layout = PPW.Layout
	SmoothSwap.PowersLayout = layout
	PPW.Layout = function(self, reset_rows, ...)
		local owner = rawget(self, "owner")
		local hold = owner ~= nil and rawget(owner, "twoweapons_hold_hud") or nil
		if hold ~= nil then
			SmoothSwap.dirty[self] = SmoothSwap.dirty[self] == true or reset_rows == true
			hold.powers = true
			local ok, err = pcall(SmoothSwap.HideLoose, self)
			if not ok then
				Log("new power icon: " .. tostring(err))
			end
			return self
		end
		return SmoothSwap.SettledLayout(layout, self, reset_rows, ...)
	end
	local refresh = PSW.OnCharacterChanged
	PSW.OnCharacterChanged = function(self, ...)
		local owner = rawget(self, "owner")
		if owner ~= nil and rawget(owner, "twoweapons_light_refresh") then
			local ok, done = pcall(SmoothSwap.LightRefresh, self)
			if ok and done then
				return
			end
		end
		return refresh(self, ...)
	end
	SmoothSwap.hud_installed = true
	return true
end


----------------------------------------------------------------------------
-- Run fn inside a smooth window: the HUD's reactions wait like a swap's.
function SmoothSwap.Within(inst, fn, ...)
	if rawget(inst, "twoweapons_hold_hud") ~= nil then
		return fn(...) -- already inside one
	end
	local finish = SmoothSwap.Begin(inst)
	local results = table.pack(pcall(fn, ...))
	finish()
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Skill Slots puts your slot skills right the frame after a swap (a weapon's
-- skills come and go with it). Measured: 6-7 ms in that one frame with the
-- Cannon, most of it the HUD redoing the skill icons and the panel's layout
-- for each skill. Right after a swap it now runs inside the swap's smooth
-- window: the skills change at once, the HUD follows with the swap's.
function SmoothSwap.HookSkillSlots()
	local package_lib = rawget(_G, "package")
	local Core = package_lib ~= nil and package_lib.loaded ~= nil and package_lib.loaded["skillslots.core"] or nil
	if type(Core) ~= "table" or SmoothSwap.hooked[Core] or type(Core.Sync) ~= "function" then
		return
	end
	SmoothSwap.hooked[Core] = true
	local sync = Core.Sync
	local wrapper = function(inst, ...)
		local pending = type(inst) == "table" and SmoothSwap.pending[inst] or nil
		if pending ~= nil and not pending.hud_done then
			return SmoothSwap.Within(inst, sync, inst, ...)
		end
		return sync(inst, ...)
	end
	SmoothSwap.labels[wrapper] = "Skill Slots resync"
	Core.Sync = wrapper
end
----------------------------------------------------------------------------

-- The rows kept still through a swap's icon layout. The game lines the rows
-- up by what's drawn in them (LayoutBounds: the icons' boxes, the counter
-- texts' too), and a new icon's box isn't quite its final one in the frame it
-- comes (user video, 1.0.4: the rows a pixel up for the 2 frames until the
-- panel's layout put them back). A swap changes one icon, not the rows: a move
-- this small is put back; a real change (another row) is kept.
SmoothSwap.STEADY = 4 -- UI units

local function Spot(w)
	if type(w) ~= "table" or w.GetPosition == nil or w.SetPosition == nil then
		return nil
	end
	local x, y = w:GetPosition()
	if type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	return { w = w, x = x, y = y }
end

function SmoothSwap.Spots(w)
	local list = {}
	list[#list + 1] = Spot(rawget(w, "powers_root"))
	for _, row in ipairs(rawget(w, "power_rows_idx") or {}) do
		list[#list + 1] = Spot(row)
	end
	return list
end

function SmoothSwap.KeepSteady(w, before)
	local rows = rawget(w, "power_rows_idx")
	if type(before) ~= "table" or type(rows) ~= "table" or #before ~= #SmoothSwap.Spots(w) then
		return 0 -- the rows changed: the new layout stands
	end
	local kept = 0
	for _, b in ipairs(before) do
		local x, y = b.w:GetPosition()
		if type(x) == "number" and type(y) == "number" and (x ~= b.x or y ~= b.y)
			and math.abs(x - b.x) <= SmoothSwap.STEADY and math.abs(y - b.y) <= SmoothSwap.STEADY then
			b.w:SetPosition(b.x, b.y)
			kept = kept + 1
		end
	end
	return kept
end

-- The icons' layouts that waited (the icon layout stage): one per icons
-- widget of this player, each settled (the old icons go, the new ones show)
function SmoothSwap.LayIcons(inst)
	local todo = {}
	for w, reset in pairs(SmoothSwap.dirty) do
		if rawget(w, "owner") == inst then
			todo[w] = reset
		end
	end
	for _, w in pairs(SmoothSwap.doomed) do
		if rawget(w, "owner") == inst and todo[w] == nil then
			todo[w] = false
		end
	end
	for w, reset in pairs(todo) do
		SmoothSwap.dirty[w] = nil
		if SmoothSwap.PowersLayout ~= nil then
			local okb, before = pcall(SmoothSwap.Spots, w)
			SmoothSwap.SettledLayout(SmoothSwap.PowersLayout, w, reset)
			if okb then
				local okk, err = pcall(SmoothSwap.KeepSteady, w, before)
				if not okk then
					Log("rows kept still: " .. tostring(err))
				end
			end
		else
			SmoothSwap.Settle(w)
			SmoothSwap.ShowPlaced(w)
		end
	end
end

-- Call before the equip; returns the function to call after it (always).
function SmoothSwap.Begin(inst)
	SmoothSwap.InstallHUD()
	SmoothSwap.HookSkillSlots()
	local comps = inst.components or {}
	local inv = comps.inventory
	local light_equip = inv ~= nil and SmoothSwap.HookInventoryClass(getmetatable(inv))
	if comps.weight ~= nil then
		SmoothSwap.HookWeightClass(getmetatable(comps.weight))
	end
	local health = comps.health
	local max0 = health ~= nil and health.GetMax ~= nil and health:GetMax() or nil
	local base0 = health ~= nil and health.GetBaseMaxHealth ~= nil and health:GetBaseMaxHealth() or nil
	local had = rawget(inst, "PushEvent")
	local push = inst.PushEvent
	-- queue the HUD's reactions only with the game's own PushEvent in place
	local dispatch = SmoothSwap.game_push ~= nil and had == nil and push == SmoothSwap.game_push
	-- a swap's pieces still to come (their HUD frame not yet done): this joins
	-- them (Skill Slots' resync the frame after a swap) instead of scheduling
	-- its own
	local pending = SmoothSwap.pending[inst]
	local joined = pending ~= nil and not pending.hud_done
	local queue = joined and pending.queue or {}
	local hold = joined and pending.hold or { panel = false, layout = false, powers = false }
	local depth = 0
	rawset(inst, "twoweapons_hold_hud", hold)
	if light_equip then
		rawset(inv, "twoweapons_light_equip", true)
	end
	inst.PushEvent = function(self, ev, data, ...)
		if self == inst then
			if ev == "inventorychanged" then
				hold.panel = true
				return
			elseif ev == "refresh_hud" then
				hold.layout = true
				return
			elseif ev == "maxhealthchanged" and max0 ~= nil and data == max0 then
				return
			elseif ev == "basemaxhealthchanged" and base0 ~= nil and data == base0 then
				return
			elseif ev == "healthchanged" and type(data) == "table" and data.old == data.new
				and (max0 == nil or data.max == nil or data.max == max0) then
				return
			end
		end
		local probe = SmoothSwap.probe
		local t = probe ~= nil and Clock() or nil
		depth = depth + 1
		if dispatch and self == inst then
			SmoothSwap.Dispatch(inst, ev, data, queue)
		else
			push(self, ev, data, ...)
		end
		depth = depth - 1
		if t ~= nil then
			probe.Event(ev, (Clock() - t) * 1000, depth)
		end
	end
	return function()
		inst.PushEvent = had
		rawset(inst, "twoweapons_hold_hud", nil)
		if light_equip then
			rawset(inv, "twoweapons_light_equip", nil)
		end
		if joined then
			return -- the pieces already scheduled take this too
		end
		if not (hold.panel or hold.layout or hold.powers or #queue > 0) then
			return
		end
		if inst.DoTaskInTicks == nil then
			if #queue > 0 then
				SmoothSwap.Held(inst, SmoothSwap.ReplayCalls, inst, queue, "all")
			end
			SmoothSwap.LayIcons(inst)
			return
		end
		SmoothSwap.last = {}
		local state = { queue = queue, hold = hold, hud_done = false }
		SmoothSwap.pending[inst] = state
		local function Later(ticks, name, fn)
			inst:DoTaskInTicks(ticks, function()
				if Valid(inst) then
					Timed(name, fn)
				end
			end)
		end
		Later(SmoothSwap.STAGES.hud, "hud", function()
			state.hud_done = true
			if #queue > 0 then
				SmoothSwap.Held(inst, SmoothSwap.ReplayCalls, inst, queue, "others")
			end
		end)
		Later(SmoothSwap.STAGES.icons, "skill / power icons", function()
			if #queue > 0 then
				SmoothSwap.Held(inst, SmoothSwap.ReplayCalls, inst, queue, "icons")
			end
		end)
		Later(SmoothSwap.STAGES.powers, "power icons", function()
			SmoothSwap.LayIcons(inst)
		end)
		Later(SmoothSwap.STAGES.panel, "panel", function()
			if not hold.panel then
				return
			end
			rawset(inst, "twoweapons_light_refresh", true)
			local ok, err = pcall(inst.PushEvent, inst, "inventorychanged")
			rawset(inst, "twoweapons_light_refresh", nil)
			if not ok then
				error(err, 0)
			end
		end)
		Later(SmoothSwap.STAGES.layout, "layout", function()
			inst:PushEvent("refresh_hud")
		end)
		Later(SmoothSwap.STAGES.portrait, "portrait", function()
			for w in pairs(SmoothSwap.portraits) do
				if rawget(w, "owner") == inst then
					SmoothSwap.portraits[w] = nil
					local puppet = w.portrait ~= nil and rawget(w.portrait, "puppet") or nil
					if puppet ~= nil then
						SmoothSwap.HookPuppetClass(getmetatable(puppet))
					end
					rawset(inst, "twoweapons_light_clone", true)
					local ok, err = pcall(w.portrait.Refresh, w.portrait, inst)
					rawset(inst, "twoweapons_light_clone", nil)
					if not ok then
						error(err, 0)
					end
				end
			end
			if SmoothSwap.pending[inst] == state then
				SmoothSwap.pending[inst] = nil
			end
		end)
	end
end

return SmoothSwap
