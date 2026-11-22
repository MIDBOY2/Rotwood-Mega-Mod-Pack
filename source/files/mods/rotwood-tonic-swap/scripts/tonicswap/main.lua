-- Tonic Swap: cycle the equipped tonic with the D-pad.
--
-- Tonics are hidden equipment (slot TONICS) that the game still drinks together
-- with your potion. This mod keeps every working tonic in your inventory and
-- swaps the equipped one. "Working" = has a power that exists, so tonics added
-- by an update join the cycle by themselves.
--
-- Each player's cycle (the potions menu, at a tonic station): the tonics they
-- put in, starting at their main tonic. Only the main one = cycling off; all
-- out = no tonic. Never opened the menu = all out.

local Equipment = require "defs.equipment"
local Power = require "defs.powers"
local Potions = require "defs.potions" -- the game's ordered potion/tonic list
local itemforge = require "defs.itemforge"
local lume = require "util.lume"
local PlayerController = require "components.playercontroller"
local InventoryHoard = require "components.inventoryhoard"
local TSPotions = require "tonicswap.potions"
local EquipInSlot = require "tonicswap.equip"

local Main = {}

Main.TAG = "[Tonic Swap]"
Main.SLOT = "TONICS"
Main.enabled = false
Main.controls = {} -- "prev"/"next" -> control

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

-- bulletproofing (tonicswap/guard.lua): this mod's part of the game's code
-- runs through Main.G; an error is logged and the game carries on
Main.G = require("tonicswap.guard").Shared(Main.TAG)

----------------------------------------------------------------------------
-- Game names this mod relies on. If an update renames one, the mod stays off
-- and says which one in client_log.txt.

local REQUIRED = {
	{ "PlayerController", PlayerController, {
		"OnControl", "IsEnabled", "IsPlacing", "IsRemovingProp", "IsFarming", "_SkipProcessingActionButtons",
	} },
	{ "InventoryHoard", InventoryHoard, {
		"GetEquippedItem", "GetInventoryItem", "GetSlotItems", "TryGiveEquipment", "AddStackable", "EquipSingleItem",
	} },
	{ "TheInput", TheInput, { "_AddGamepadButtonBind", "_RemoveGamepadButtonBind", "AddKeyBind", "ResetControlState" } },
	{ "itemforge", itemforge, { "_CreateItem" } },
}

local function CheckGame()
	for _, entry in ipairs(REQUIRED) do
		local label, obj, fns = entry[1], entry[2], entry[3]
		if type(obj) ~= "table" then
			return label
		end
		for _, fn in ipairs(fns) do
			if type(obj[fn]) ~= "function" then
				return label .. ":" .. fn
			end
		end
	end
	if Equipment.Slots == nil or Equipment.Slots[Main.SLOT] == nil or Equipment.Items[Main.SLOT] == nil then
		return "Equipment.Slots.TONICS"
	end
	return nil
end

----------------------------------------------------------------------------
-- Settings

local DEFAULTS = {
	enabled = true,
	gamepad = { prev = "DPAD_LEFT", next = "DPAD_RIGHT" },
	keyboard = { prev = "COMMA", next = "PERIOD" },
	free_dpad = true,
	popup = true,
	skip = {},
	stations = { "lamp_volcano_1" },
	unlock_stations = true,
	potion_table = true, -- the Potion Table in the build menu (tonicswap/table.lua)
	potion_table_cost_like = "bench_basic", -- it costs what this structure costs
	main_at_run_start = false,
	-- tonics that sit out of your cycle while you have a power doing their job
	-- (power name -> tonic names); false = off
	out_with_power = { iron_brew = { "full_shield" } },
	tonic_fx = true, -- the tonics in the game's current art (tonicswap/tonicfx.lua)
	tonic_explode_scale = 0.5, -- Popping Candy's explosion size (with tonic_fx)
	tonic_explode_ground = false, -- and its ground blast
	tonic_freeze_style = "browse", -- Ice Cold Slushie: "nova" / "ripple" / "chill" / "instant" / "browse" (the next each use)
	tonic_explode_enemy_blasts = false, -- and the game's bomb hit burst on each enemy
	tonic_size_allies = true, -- Shrink / Juggernaut reach allies in your potion's reach (tonicswap/sizeallies.lua)
	tonic_size_allies_minions = false,
	drink_lift = 110, -- while drinking, the bar and potion icon over your head go up this much (0 = off)
	tonic_rage_damage = 200, -- Spicy Pumpkin Seeds: damage for its 5 seconds, % of normal (the game: 1000) (tonicswap/tonictune.lua)
	tonic_eggs_damage = 100, -- Battoad Eggs: each projectile's damage (the game: 50)
	tonic_clean_text = true, -- "[TEMP]" off the tonics' names and descriptions
	gem_refill_fix = true, -- the Alchemist's Gem doesn't refill your potion (tonicswap/gemrefill.lua)
	status_potion_look = true, -- the status panel: blue item-slot background, bigger bottle
	status_potion_scale = 1.35, -- its bottle size, times the game's
	status_potion_full = false, -- the status panel: the potion's full picture even with no drinks left
	hud_potion_backing = true, -- the HUD's dark frame reaches past the tonic icon
	menu_text_size = 1, -- the menu's details text (potion / tonic name, description, buttons), times the mod's size
	guard = true, -- bulletproofing: an error in this mod's part is logged and skipped
	-- the menu's grid (and the cycle) order; tonics not listed follow in the game's order
	-- (rows by colour: blue Shield / Freeze / Run speed, red Popping Candy and
	-- the two projectiles, yellow Shrink / Grow / Damage)
	order = { "full_shield", "freeze", "zucco_dash", "explotion", "projectile_repeat", "mudslinger",
		"shrink", "juggernaut", "yammo_rage" },
	tonic_colours = true, -- Freeze and Run speed drawn blue, Grow yellow, like their rows (false = the game's icons)
}

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			s[k] = v
		end
	end
	Main.settings = s
	Main.G.on = s.guard ~= false
	return s
end

----------------------------------------------------------------------------
-- Tonic list

local function IsWorking(def)
	local usage = def ~= nil and def.usage_data or nil
	if usage == nil or usage.power == nil then
		return false
	end
	local ok, pdef = pcall(Power.FindPowerByName, usage.power) -- errors for a missing name
	return ok and pdef ~= nil
end

-- Working tonic defs: the settings' order first, then the rest in the game's
-- own order (new ones by name at the end).
function Main.GetTonics()
	local items = Equipment.Items[Main.SLOT]
	local skip = {}
	for _, name in ipairs(Main.settings.skip or {}) do
		skip[name] = true
	end
	local list, seen = {}, {}
	local function Add(def)
		if def ~= nil and not seen[def.name] then
			seen[def.name] = true
			if IsWorking(def) and not skip[def.name] then
				list[#list + 1] = def
			end
		end
	end
	local order = type(Main.settings.order) == "table" and Main.settings.order or {}
	for _, name in ipairs(order) do
		if type(name) == "string" then
			Add(rawget(items, name))
		end
	end
	for _, entry in ipairs(Potions) do
		Add(entry.slot == Main.SLOT and rawget(items, entry.name) or nil)
	end
	local extra = {}
	for name, def in pairs(items) do
		if not seen[name] then
			extra[#extra + 1] = def
		end
	end
	table.sort(extra, function(a, b) return a.name < b.name end)
	for _, def in ipairs(extra) do
		Add(def)
	end
	return list
end

-- The class of items (from a probe tonic), or nil.
local function FindItemInstance()
	local any = next(Equipment.Items[Main.SLOT])
	if any == nil then
		return nil
	end
	local probe = itemforge._CreateItem(Main.SLOT, Equipment.Items[Main.SLOT][any])
	local mt = getmetatable(probe)
	return mt ~= nil and mt.__index or nil
end

-- Tonics are tagged "hide", and outside developer mode the game drops hidden
-- items from your inventory on load. Count working tonics as keepable.
local function KeepTonicsOnLoad(ItemInstance)
	if type(ItemInstance) ~= "table" or type(ItemInstance.IsShippableItem) ~= "function" then
		Main.Log("couldn't find IsShippableItem; tonics need developer mode to stay in your inventory")
		return
	end
	local orig = ItemInstance.IsShippableItem
	local function Keep(self)
		if self.slot == Main.SLOT and Main.enabled then
			return IsWorking(Equipment.Items[Main.SLOT][self.id])
		end
		return false
	end
	ItemInstance.IsShippableItem = function(self, ...)
		local ok, keep = Main.G.Call("keep tonics on load", Keep, self)
		if ok and keep then
			return true
		end
		return orig(self, ...)
	end
end

----------------------------------------------------------------------------
-- Owning and equipping

local function HasDictEntries(t)
	for k in pairs(t) do
		if type(k) ~= "number" then
			return true
		end
	end
	return false
end

local KEEP_STACK = 9

-- Make sure the player owns this tonic; returns the inventory item.
function Main.EnsureOwned(hoard, def)
	local item = hoard:GetInventoryItem(def)
	if item ~= nil then
		-- tonics stored as stacks lose one at the end of each run; top up
		if item.count ~= nil and item.count < KEEP_STACK then
			hoard:AddStackable(def, KEEP_STACK - item.count)
		end
		return item
	end
	-- keep the slot's storage style (list or stacks), never mix the two
	if HasDictEntries(hoard:GetSlotItems(Main.SLOT)) then
		hoard:AddStackable(def, KEEP_STACK)
	else
		hoard:TryGiveEquipment(def)
	end
	return hoard:GetInventoryItem(def)
end

function Main.EnsureAll(inst)
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard == nil or (inst.IsLocal ~= nil and not inst:IsLocal()) then
		return
	end
	for _, def in ipairs(Main.GetTonics()) do
		Main.EnsureOwned(hoard, def)
	end
end

-- Equip a tonic item (nil = no tonic) without a full loadout refresh (equip.lua).
function Main.EquipTonic(inst, item)
	local slot = Main.SLOT
	EquipInSlot(inst, slot, item)

	-- the potion drinker keeps its own copy of the equipped tonic
	local drinker = inst.components.potiondrinker
	if drinker ~= nil and drinker.equipped_potions ~= nil then
		if item == nil then
			drinker.equipped_potions[slot] = nil
		elseif drinker._SetEquippedPotion ~= nil then
			drinker:_SetEquippedPotion(slot, item)
		else
			drinker.equipped_potions[slot] = item
		end
	end
	inst:PushEvent("refreshpotiondata")
end

----------------------------------------------------------------------------
-- Each player's choices (tonic menu), saved with the character

function Main.GetData(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.tonicswapdata or nil
end

-- A tonic is in the cycle unless it was taken out. Never opened the menu: all
-- out (no tonic). No saved choices at all (another machine's player): all in.
function Main.IsIncluded(inst, def)
	local data = Main.GetData(inst)
	if data == nil then
		return true
	end
	return data:IsPicked() and not data:IsOff(def.name)
end

-- Sitting out: a tonic whose job a power you have already does (Iron Brew
-- gives 4 Shield Segments every drink, like Bulbug Boba) is out of your cycle
-- while you have that power: the D-pad skips it, and if you have it on you
-- go to the next one in your cycle. When the power goes (a new run, town)
-- it's back in, and if you still have on the tonic that stood in for it, you
-- get it back. Your menu choices don't change.
local function PowerManager(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.powermanager or nil
end

-- the power (its id) that has this tonic sitting out now, or nil
function Main.SittingOutFor(inst, def)
	local rules = Main.settings.out_with_power
	local pm = PowerManager(inst)
	if type(rules) ~= "table" or def == nil or pm == nil or pm.GetPowerByName == nil then
		return nil
	end
	local powers = {}
	for power in pairs(rules) do
		powers[#powers + 1] = power
	end
	table.sort(powers)
	for _, power in ipairs(powers) do
		local tonics = rules[power]
		if type(tonics) == "table" and lume.find(tonics, def.name) ~= nil and pm:GetPowerByName(power) ~= nil then
			return power
		end
	end
	return nil
end

-- the power's name as the game shows it
function Main.PowerTitle(power)
	local ok, def = pcall(Power.FindPowerByName, power)
	local pretty = ok and def ~= nil and def.pretty or nil
	return pretty ~= nil and pretty.name or power
end

-- The main tonic: the one picked with X, if it's still in the cycle;
-- otherwise the first tonic that's in (grid order). nil = no tonic.
-- ignore_out: as if no tonic were sitting out (your own choices)
function Main.GetMainDef(inst, ignore_out)
	local data = Main.GetData(inst)
	if data == nil or not data:IsPicked() then
		return nil
	end
	local tonics = Main.GetTonics()
	local name = data:GetMain()
	local function Usable(def)
		return not data:IsOff(def.name) and (ignore_out or Main.SittingOutFor(inst, def) == nil)
	end
	for i, def in ipairs(tonics) do
		if def.name == name and not data:IsOff(def.name) then
			if Usable(def) then
				return def
			end
			-- sitting out: the next one in your cycle stands in as the main one
			for k = 1, #tonics - 1 do
				local other = tonics[(i + k - 1) % #tonics + 1]
				if Usable(other) then
					return other
				end
			end
			return nil
		end
	end
	for _, def in ipairs(tonics) do
		if Usable(def) then
			return def
		end
	end
	return nil
end

-- "none" or a tonic name
function Main.GetMainName(inst)
	local def = Main.GetMainDef(inst)
	return def ~= nil and def.name or "none"
end

-- The player's cycle: the main tonic first (false = no tonic), then the
-- tonics that are in, in grid order going on from the main one.
-- Tonics sitting out (Main.SittingOutFor) aren't in it; ignore_out: as if
-- none were.
function Main.GetCycle(inst, ignore_out)
	local main = Main.GetMainDef(inst, ignore_out)
	local options = { main or false }
	local tonics = Main.GetTonics()
	local start = 0
	for i, def in ipairs(tonics) do
		if def == main then
			start = i
		end
	end
	for k = 1, #tonics do
		local def = tonics[(start + k - 1) % #tonics + 1]
		if def ~= main and Main.IsIncluded(inst, def) and (ignore_out or Main.SittingOutFor(inst, def) == nil) then
			options[#options + 1] = def
		end
	end
	return options
end

-- only the main tonic (or nothing): the D-pad does nothing
function Main.IsCyclingOff(inst)
	return #Main.GetCycle(inst) <= 1
end

-- any tonic other than the main one in the cycle
function Main.HasOthers(inst)
	return #Main.GetCycle(inst) > 1
end

local function CurrentDef(inst)
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	local item = hoard ~= nil and hoard:GetEquippedItem(Main.SLOT) or nil
	return item ~= nil and item:GetDef() or nil
end
Main.CurrentDef = CurrentDef

local function IndexOf(options, def)
	for i, opt in ipairs(options) do
		if (opt == false and def == nil) or opt == def then
			return i
		end
	end
	return nil
end

-- Equip a cycle entry (false = no tonic).
function Main.EquipOption(inst, opt, popup)
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard == nil then
		return false
	end
	local item = opt and Main.EnsureOwned(hoard, opt) or nil
	if opt and item == nil then
		return false
	end
	Main.EquipTonic(inst, item)
	if popup and Main.settings.popup and inst.PeekFollowStatus ~= nil then
		inst:PeekFollowStatus({ show_potion = true }, true)
	end
	inst:PushEvent("tonicswap_changed", { def = opt or nil })
	return true
end

-- After the cycle changed: a tonic that's no longer in it goes back to the main one.
function Main.FixCurrent(inst)
	local options = Main.GetCycle(inst)
	if IndexOf(options, CurrentDef(inst)) ~= nil then
		return false
	end
	return Main.EquipOption(inst, options[1], false)
end

-- A power came or went: the tonic you have on sitting out -> the next one in
-- your cycle (remembered, saved with your choices); the power gone and the
-- stand-in still on -> the tonic back.
function Main.ApplySittingOut(inst)
	if inst == nil or (inst.IsLocal ~= nil and not inst:IsLocal()) or (inst.IsValid ~= nil and not inst:IsValid()) then
		return false
	end
	local data = Main.GetData(inst)
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	if data == nil or hoard == nil then
		return false
	end
	local current = CurrentDef(inst)
	local power = Main.SittingOutFor(inst, current)
	if power ~= nil then
		-- the next one after it in your cycle that isn't sitting out
		local full = Main.GetCycle(inst, true)
		local at = IndexOf(full, current)
		local pick = nil
		if at ~= nil then
			for k = 1, #full - 1 do
				local opt = full[(at + k - 1) % #full + 1]
				if opt == false or Main.SittingOutFor(inst, opt) == nil then
					pick = opt
					break
				end
			end
		end
		if pick == nil then
			pick = Main.GetCycle(inst)[1]
		end
		if pick == current then
			return false
		end
		data:SetStandIn(current.name, pick and pick.name or "none")
		Main.Log(string.format("%s: %s sits out of your cycle, %s on", Main.PowerTitle(power), current.name, pick and pick.name or "no tonic"))
		return Main.EquipOption(inst, pick, true)
	end
	local out, standin = data:GetStandIn()
	if out == nil then
		return false
	end
	local out_def = rawget(Equipment.Items[Main.SLOT], out)
	if out_def ~= nil and Main.SittingOutFor(inst, out_def) ~= nil then
		return false -- still out
	end
	data:SetStandIn(nil)
	local current_name = current ~= nil and current.name or "none"
	if out_def ~= nil and current_name == standin and Main.IsIncluded(inst, out_def) then
		Main.Log(out .. " is back in your cycle and on again")
		return Main.EquipOption(inst, out_def, false)
	end
	return false
end

-- Before the first change: a player who never opened the menu starts from
-- "all out".
local function Begin(inst)
	local data = Main.GetData(inst)
	if data ~= nil and not data:IsPicked() then
		for _, def in ipairs(Main.GetTonics()) do
			data:SetOff(def.name, true)
		end
		data:SetMain("none")
	end
	return data
end

-- After a change: remember the main tonic as it is now, fix what's equipped
-- (equip_main: put the main tonic on now), tell the menu.
local function Finish(inst, data, equip_main)
	local main = Main.GetMainDef(inst)
	data:SetMain(main ~= nil and main.name or "none")
	if equip_main then
		Main.EquipOption(inst, main or false, false)
	else
		Main.FixCurrent(inst)
	end
	inst:PushEvent("tonicswap_config")
	return true
end

-- X: name becomes the main tonic (put in if it was out) and is equipped now.
function Main.SetMain(inst, name)
	local data = Begin(inst)
	if data == nil then
		return false
	end
	if type(name) == "string" and name ~= "none" then
		data:SetOff(name, false)
	end
	data:SetMain(name)
	return Finish(inst, data, true)
end

-- the next tonic that's in after `name` (grid order, wrapping), or nil
local function NextIn(inst, name)
	local tonics = Main.GetTonics()
	local at = 0
	for i, def in ipairs(tonics) do
		if def.name == name then
			at = i
		end
	end
	for k = 1, #tonics do
		local def = tonics[(at + k - 1) % #tonics + 1]
		if def.name ~= name and Main.IsIncluded(inst, def) then
			return def
		end
	end
	return nil
end

-- A: in or out of the cycle. The main tonic taken out passes "main" on to the
-- next one that's in (none left: no tonic); the first one put in is the main.
function Main.SetIncluded(inst, name, included)
	local data = Begin(inst)
	if data == nil then
		return false
	end
	local was_main = Main.GetMainName(inst) == name
	data:SetOff(name, not included)
	if not included and was_main then
		local next_def = NextIn(inst, name)
		data:SetMain(next_def ~= nil and next_def.name or "none")
	end
	return Finish(inst, data, false)
end

-- included = true: every tonic in; false: only the main tonic (cycling off)
function Main.SetAllIncluded(inst, included)
	local data = Begin(inst)
	if data == nil then
		return false
	end
	local main = Main.GetMainDef(inst)
	for _, def in ipairs(Main.GetTonics()) do
		data:SetOff(def.name, not included and def ~= main)
	end
	return Finish(inst, data, false)
end

-- Y: cycling off (only the main tonic), or, when it's off, every tonic in
function Main.ToggleCycling(inst)
	return Main.SetAllIncluded(inst, not Main.HasOthers(inst))
end

-- dir = 1 (next) or -1 (prev)
function Main.Cycle(inst, dir)
	local hoard = inst.components.inventoryhoard
	if hoard == nil then
		return false
	end
	local options = Main.GetCycle(inst)
	local index = IndexOf(options, CurrentDef(inst))
	local n = #options
	if n <= 1 then
		-- cycling off: the main tonic (or nothing) stays
		if index == nil then
			return Main.EquipOption(inst, options[1], true)
		end
		return false
	end
	local pick
	if index == nil then
		-- a tonic that isn't in the cycle: start at an end (next = the main one)
		pick = dir > 0 and 1 or n
	else
		pick = (index - 1 + dir) % n + 1
	end
	return Main.EquipOption(inst, options[pick], true)
end

----------------------------------------------------------------------------
-- Input

local function AddControls()
	local digital = Controls.Digital
	for _, which in ipairs({ "prev", "next" }) do
		local name = "TONICSWAP_" .. which:upper()
		local control = rawget(digital, name)
		if control == nil then
			control = { key = "Controls.Digital." .. name, shortkey = name }
			rawset(digital, name, control)
		end
		Main.controls[which] = control
	end
	TheInput:ResetControlState()

	local s = Main.settings
	if s.free_dpad then
		-- D-pad left/right walk only when the stick is idle; free them for tonics
		local moves = { DPAD_LEFT = "MOVE_LEFT", DPAD_RIGHT = "MOVE_RIGHT" }
		for _, button in pairs(s.gamepad or {}) do
			local move = moves[button]
			if move ~= nil and rawget(digital, move) ~= nil then
				TheInput:_RemoveGamepadButtonBind(digital[move])
			end
		end
	end
	for which, control in pairs(Main.controls) do
		local button = s.gamepad and s.gamepad[which]
		if type(button) == "string" and button ~= ""
			and (TheInput.gamepad_lookup == nil or TheInput.gamepad_lookup[control] == nil) then
			TheInput:_AddGamepadButtonBind({ button = button, control = control })
		end
		local key = s.keyboard and s.keyboard[which]
		if type(key) == "string" and key ~= ""
			and (TheInput.key_lookup == nil or TheInput.key_lookup[control] == nil) then
			TheInput:AddKeyBind({ key = key, control = control, ANYMOD = true })
		end
	end
end

-- Same checks the game makes before attack/skill buttons.
local function CanPress(pc)
	if not pc:IsEnabled() then
		return false
	end
	if pc.input ~= nil and pc.input.IsEditingBlockingGameplay ~= nil and pc.input:IsEditingBlockingGameplay() then
		return false
	end
	if pc.input_stealers ~= nil and #pc.input_stealers > 0 then
		return false
	end
	if pc:IsPlacing() or pc:IsRemovingProp() then
		return false
	end
	if pc:_SkipProcessingActionButtons() or pc:IsFarming() then
		return false
	end
	if pc.inst.IsSpectating ~= nil and pc.inst:IsSpectating() then
		return false
	end
	return true
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Main.Log("swap error: " .. tostring(err))
	end
end

local function HookPlayerController()
	local orig_OnControl = PlayerController.OnControl
	local function AfterPress(self, controls)
		if self.inst.tonicswap == nil then
			return
		end
		local dir = (Main.controls.next ~= nil and controls:Has(Main.controls.next)) and 1
			or (Main.controls.prev ~= nil and controls:Has(Main.controls.prev)) and -1
			or nil
		if dir ~= nil and CanPress(self) then
			local ok, err = pcall(Main.Cycle, self.inst, dir)
			if not ok then
				Report(err)
			end
		end
	end
	PlayerController.OnControl = function(self, controls, down, ...)
		local results = table.pack(orig_OnControl(self, controls, down, ...))
		if down then
			Main.G.Call("tonic cycle press", AfterPress, self, controls)
		end
		return table.unpack(results, 1, results.n)
	end
end

-- Vanilla bug: the potion HUD never hides the tonic icon once the tonic is gone.
local function FixPotionWidget()
	local ok, PotionWidget = pcall(require, "widgets/ftf/potionwidget")
	if not ok or type(PotionWidget) ~= "table" or type(PotionWidget.RefreshIcons) ~= "function" then
		Main.Log("potion HUD fix skipped")
		return
	end
	local orig = PotionWidget.RefreshIcons
	local function TonicIcon(self)
		if self.tonic_icon ~= nil then
			if self.equipped_tonic_def ~= nil then
				self.tonic_icon:Show()
			else
				self.tonic_icon:Hide()
			end
		end
	end
	PotionWidget.RefreshIcons = function(self, ...)
		local ret = orig(self, ...)
		Main.G.Call("HUD tonic icon", TonicIcon, self)
		return ret
	end
end

----------------------------------------------------------------------------

-- The tonic grid's rows by colour: three tonics drawn in their row's colour
-- (images/tonicswap_tonics: the game's icons recoloured to the palette of the
-- row's own icons: Bulbug Boba's blue; Shrink's and the Damage tonic's
-- yellow). Set on the tonic's item, so everywhere the game draws its icon
-- (the menu, the HUD, the inventory) shows it. tonic_colours = false, or the
-- atlas not in the mod's folder: the game's icons.
Main.TONIC_ATLAS = "images/tonicswap_tonics"
Main.TONIC_ICONS = { freeze = "icon_tonic_freeze_blue", zucco_dash = "icon_tonic_zucco_dash_blue",
	juggernaut = "icon_tonic_juggernaut_yellow" }
function Main.TonicColours()
	local items = Equipment.Items[Main.SLOT]
	local on = Main.settings.tonic_colours ~= false
	if on then
		local resolve = rawget(_G, "softresolvefilepath")
		if type(resolve) == "function" and (resolve(Main.TONIC_ATLAS .. ".xml") == nil or resolve(Main.TONIC_ATLAS .. ".tex") == nil) then
			Main.Log("tonic colours off: " .. Main.TONIC_ATLAS .. " isn't in the mod's folder (the game's icons)")
			on = false
		end
	end
	local n = 0
	for name, el in pairs(Main.TONIC_ICONS) do
		local def = rawget(items, name)
		if def ~= nil then
			if def.tonicswap_game_icon == nil then
				def.tonicswap_game_icon = def.icon or false
			end
			if on then
				def.icon = Main.TONIC_ATLAS .. "/" .. el .. ".tex"
				n = n + 1
			else
				def.icon = def.tonicswap_game_icon or nil
			end
		end
	end
	return n
end

function Main.Install()
	local missing = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	require "components.tonicswapdata" -- loaded now so AddComponent finds it later
	local ItemInstance = FindItemInstance()
	KeepTonicsOnLoad(ItemInstance)
	AddControls()
	HookPlayerController()
	FixPotionWidget()
	Main.G.Call("tonic colours", Main.TonicColours)
	Main.enabled = true
	-- the potions (their own part of the tonic menu); off alone if it fails
	local ok, potions_ok, info = pcall(TSPotions.Install, Main.settings, ItemInstance)
	if not ok then
		Main.potions_info = "potions off: " .. tostring(potions_ok)
	elseif not potions_ok then
		Main.potions_info = "potions off (" .. tostring(info) .. ")"
	else
		Main.potions_info = tostring(info)
	end
	-- the Alchemist's Gem doesn't refill your potion (tonicswap/gemrefill.lua)
	if Main.settings.gem_refill_fix ~= false then
		local gok, gem_ok, gem_info = pcall(function()
			return require("tonicswap.gemrefill").Install(require "defs.powers", Main.G)
		end)
		local line = not gok and ("gem refill fix off: " .. tostring(gem_ok))
			or not gem_ok and ("gem refill fix off (" .. tostring(gem_info) .. ")")
			or tostring(gem_info)
		Main.potions_info = tostring(Main.potions_info) .. "; " .. line
	end
	return true, #Main.GetTonics()
end

function Main.SetupPlayer(inst)
	if inst.tonicswap ~= nil then
		return
	end
	inst.tonicswap = {}
	if inst.components ~= nil and inst.components.tonicswapdata == nil then
		inst:AddComponent("tonicswapdata")
	end
	local function EnsureSoon()
		if inst:IsValid() then
			inst:DoTaskInTime(0, Main.EnsureAll)
		end
	end
	inst:ListenForEvent("enter_town", EnsureSoon)
	-- tonics sitting out while a power does their job
	local function SittingOutSoon()
		if inst:IsValid() and type(Main.settings.out_with_power) == "table" then
			inst:DoTaskInTime(0, function()
				local ok, err = pcall(Main.ApplySittingOut, inst)
				if not ok then
					Report(err)
				end
			end)
		end
	end
	inst:ListenForEvent("add_power", SittingOutSoon)
	inst:ListenForEvent("remove_power", SittingOutSoon)
	inst:ListenForEvent("enter_town", SittingOutSoon)
	TSPotions.SetupPlayer(inst)
	inst:ListenForEvent("start_new_run", function()
		if not inst:IsValid() then
			return
		end
		inst:DoTaskInTime(0, function()
			Main.EnsureAll(inst)
			-- each run starts on the main tonic (setting)
			if Main.settings.main_at_run_start and (inst.IsLocal == nil or inst:IsLocal()) then
				local ok, err = pcall(Main.EquipOption, inst, Main.GetMainDef(inst) or false, false)
				if not ok then
					Report(err)
				end
			end
			SittingOutSoon()
		end)
	end)
	EnsureSoon()
	SittingOutSoon() -- a run loaded with the power already
end

return Main
