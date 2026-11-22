-- Skill Slots: settings, which skill each button fires, and the power/skill hooks.
--
-- How it works:
--  * Each slot skill is a real skill power on the player (so its rewards and
--    events work, e.g. parry's crit buff). The mod marks them permanent so the
--    game's "one skill at a time" rule only applies to the weapon's skill.
--  * The game reads the skill to fire from sg.mem.skillstate. At rest it always
--    holds B's skill (the weapon's, unless B was given another skill). A slot
--    button press sets it to the slot's skill only for that press.
--  * Slot values: a skill name, "weapon" (the weapon's own skill, or the one
--    picked up during a run: vanilla B) or empty. B starts as "weapon".
--  * Each weapon type has its own loadout (saved as "LT:HAMMER", "B:BOW", ...),
--    so switching weapons switches all four skills. A slot never set for a
--    weapon uses the shared value (picked before loadouts existed), then the
--    settings file.
--  * Weapon-class skills (and boss_thatcher, a bow skill) only work while that
--    weapon is in hand; on a slot they rest while another weapon is out.
--  * Slot presses go through the game's own "skill" input, so buffering, cancel
--    windows and hold-to-charge skills work the same as on B.
--  * Weapon choices (Core.PSEUDO) are slot choices that aren't skill powers:
--    "Block" for the Greatsword (its block moved off the dodge button,
--    block.lua; LT / RT / RS or B), "Dodge" and "Reload" for the Cannon (its
--    unused roll on a button, or its plant / reload moved off the dodge
--    button so the dodge button rolls, cannon.lua; LT / RT / RS).
--  * Skills whose power keeps something with you while you have it (the
--    Sedament crow) only keep it while a button uses the skill (PRESENCE).

local Power = require "defs.powers"
local PowerManager = require "components.powermanager"
local PlayerController = require "components.playercontroller"
local SGPlayerCommon = require "stategraphs.sg_player_common"

local Core = {}

Core.TAG = "[Skill Slots]"
Core.SLOT_ORDER = { "LT", "RT", "RS" } -- the extra buttons (also the gamepad button names)
Core.MENU_SLOTS = { "B", "LT", "RT", "RS" } -- every slot the menu can set
Core.WEAPON = "weapon" -- slot value: the weapon's own skill
Core.BLOCK = "skillslots_block" -- slot value: the Greatsword's block (block.lua)
Core.BLOCK_WEAPON = "CLEAVER"
Core.CANNON_DODGE = "skillslots_cannon_dodge" -- slot value: the Cannon's roll (cannon.lua)
Core.CANNON_RELOAD = "skillslots_cannon_reload" -- slot value: the Cannon's plant / reload (cannon.lua)
Core.CANNON_WEAPON = "CANNON"
Core.EMPTY = "none" -- saved value for a slot emptied on purpose
Core.CONTROL_PREFIX = "SKILLSLOTS_"
Core.enabled = false
Core.settings = nil
Core.controls = {} -- slot -> control

function Core.Log(msg)
	print(Core.TAG .. " " .. tostring(msg))
end

-- bulletproofing (skillslots/guard.lua): this mod's part of the game's code
-- runs through Core.G; an error is logged and the game carries on
Core.G = require("skillslots.guard").Shared(Core.TAG)

----------------------------------------------------------------------------
-- Game names this mod relies on, checked at load. If an update renames one,
-- the mod switches itself off and says which one in client_log.txt.

local REQUIRED = {
	{ "PlayerController", PlayerController, {
		"OnControl", "OnSkillButton", "OnControlDownEvent", "OnControlUpEvent",
		"FlushControlQueueAt", "GetAnalogDir", "ShouldAimAtMouse", "GetMouseActionDirection",
		"IsEnabled", "IsPlacing", "IsRemovingProp", "IsFarming", "_SkipProcessingActionButtons",
	} },
	{ "PowerManager", PowerManager, {
		"_AddPowerInternal", "AddPowerByName", "RemovePowerByName", "GetCurrentSkillPower",
	} },
	{ "TheInput", TheInput, { "_AddGamepadButtonBind", "AddKeyBind", "ResetControlState" } },
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
	if Power.Slots == nil or Power.Slots.SKILL == nil or Power.Items == nil
		or type(Power.Items[Power.Slots.SKILL]) ~= "table" then
		return "Power.Slots.SKILL"
	end
	if Power.Types == nil or Power.Types.SKILL == nil then
		return "Power.Types.SKILL"
	end
	if SGPlayerCommon.Fns == nil or type(SGPlayerCommon.Fns.DoAction) ~= "function" then
		return "SGPlayerCommon.Fns.DoAction"
	end
	return nil
end

----------------------------------------------------------------------------
-- Settings

local DEFAULTS = {
	slots = { B = "weapon", LT = "buffnextattack", RT = "throwstone", RS = "parry" },
	stations = { "rustic_weapon_rack", "rugged_weapon_rack", "pergola", "tree_winter_2024", "dummy_kuma" },
	-- the blacksmith's weapon racks: hold interact for the menu (once unlocked)
	racks = { "weapon_rack_hammer", "weapon_rack_polearm", "weapon_rack_cleaver", "weapon_rack_cannon",
		"weapon_rack_shotput", "weapon_rack_bow" },
	keyboard = { LT = "U", RT = "I", RS = "O" },
	menu_button = { gamepad = "", keyboard = "H" },
	hud = { show = true, layout = "cluster", size = "full", overlap = 10, spacing = 10, x = 0, y = 0,
		cluster = { gap = 24, shift = 0.4, rise = 0, skill_scale = 1.1, power_scale = 1.3, power_gap = 8 }, class_badge = true, tips_gap = 25, tips_margin = 30, tips_min_scale = 0.5,
		bar_clears_name = true, bar_gap = 10, name_fit = true, name_min_font = 26, name_margin = 10,
		lives_after_bar = true, lives_gap = 12 },
	-- hide / show the power rows (powershide.lua)
	hide_powers = { gamepad = "DPAD_DOWN", hide_all = "SEMICOLON", show_all = "QUOTE", boss_auto_hide = "all", fade_time = 0.35,
		small_gamepad = "DPAD_UP", small_all = "SLASH" }, -- (small_sizes: powershide.lua's default unless set)
	-- where each weapon choice starts (false = on no button: the game's way)
	greatsword_block = false,
	cannon_dodge = "RS",
	cannon_reload = false,
	-- the Cannon roll's weapon invincibility bonus, in frames (like each
	-- weapon's own: Bow / Striker 0, Hammer / Spear / Greatsword 1)
	cannon_roll_iframes = 0,
	-- roll into the Cannon's air attacks mid-roll (false: normal shot / Blast)
	cannon_roll_combos = true,
	cannon_roll_swing = true,
	-- the game's mannequin loadouts remember every weapon's skill buttons
	mannequin_loadouts = true,
	-- never in the menu, even with Show all (the game's broken ones)
	hidden_skills = { "hammer_reflectinglights" },
	-- skills whose picture runs over its round frame: drawn this much smaller
	-- (the game draws every skill picture 1.1 x the frame). None now: Throw
	-- Snowball's own icon was redrawn centred and smaller (0.14.7).
	icon_scale = {},
}

function Core.LoadSettings(user)
	user = type(user) == "table" and user or {}
	local s = {
		enabled = user.enabled ~= false,
		slots = type(user.slots) == "table" and user.slots or DEFAULTS.slots,
		players = type(user.players) == "table" and user.players or {},
		keyboard = type(user.keyboard) == "table" and user.keyboard or DEFAULTS.keyboard,
		stations = type(user.stations) == "table" and user.stations or DEFAULTS.stations,
		rack_menu = user.rack_menu ~= false,
		forge_rack = user.forge_rack ~= false,
		racks = type(user.racks) == "table" and user.racks or DEFAULTS.racks,
		all_skills = user.all_skills == true,
		class_icons = user.class_icons ~= false,
		list_names = user.list_names == true,
		icon_scale = type(user.icon_scale) == "table" and user.icon_scale or DEFAULTS.icon_scale,
		hidden_skills = type(user.hidden_skills) == "table" and user.hidden_skills or DEFAULTS.hidden_skills,
		hide_other_weapons = user.hide_other_weapons ~= false,
		finish_skill_swing = user.finish_skill_swing ~= false,
		debug_skills = user.debug_skills == true, -- log of every skill state change (debugging; off)
		guard = user.guard ~= false,
		unlock_stations = user.unlock_stations ~= false,
		menu_button = type(user.menu_button) == "table" and user.menu_button or DEFAULTS.menu_button,
		mannequin_loadouts = user.mannequin_loadouts ~= false,
		cannon_roll_combos = user.cannon_roll_combos ~= false,
		cannon_roll_swing = user.cannon_roll_swing ~= false,
		cannon_roll_iframes = type(user.cannon_roll_iframes) == "number"
			and math.max(0, math.min(5, math.floor(user.cannon_roll_iframes + 0.5))) or DEFAULTS.cannon_roll_iframes,
		hud = {},
		hide_powers = {},
	}
	for k, v in pairs(DEFAULTS.hide_powers) do
		s.hide_powers[k] = v
	end
	if type(user.hide_powers) == "table" then
		for k, v in pairs(user.hide_powers) do
			s.hide_powers[k] = v
		end
	elseif user.hide_powers == false then
		s.hide_powers = false
	end
	for k, v in pairs(DEFAULTS.hud) do
		s.hud[k] = v
	end
	if type(user.hud) == "table" then
		for k, v in pairs(user.hud) do
			s.hud[k] = v
		end
	end
	-- where each weapon choice starts: a button it's allowed on, or false
	for _, name in ipairs(Core.PSEUDO_ORDER) do
		local p = Core.PSEUDO[name]
		local v = user[p.setting]
		if v == nil then
			v = DEFAULTS[p.setting]
		end
		if type(v) ~= "string" or not p.slots[v] then
			v = false -- false, "none", "" or a button it can't go on
		end
		s[p.setting] = v
	end
	Core.settings = s
	Core.G.on = s.guard
	return s
end

----------------------------------------------------------------------------
-- Weapon choices: slot choices that aren't skill powers (Block, Dodge,
-- Reload). Each belongs to one weapon type, can go on some buttons only, and
-- starts on the button its setting names (false = none: the game's way).
-- Their "def" has what the menu, the HUD and the info popup read from a skill
-- def (name, icon, pretty).

-- round skill icons in the game's skill-icon style (the mod's images folder)
Core.BLOCK_ICON = "images/skillslots_icons/icon_skillslots_block.tex"
Core.CANNON_DODGE_ICON = "images/skillslots_icons/icon_skillslots_cannon_dodge.tex"
Core.CANNON_RELOAD_ICON = "images/skillslots_icons/icon_skillslots_cannon_reload.tex"
Core.PSEUDO = {
	[Core.BLOCK] = {
		weapon = Core.BLOCK_WEAPON, setting = "greatsword_block", installed = "block_installed",
		icon = Core.BLOCK_ICON, slots = { B = true, LT = true, RT = true, RS = true },
		name = "Block",
		-- the menu shows the first paragraph (the summary); Skill info all of it
		desc = "The Greatsword's block. <#RED>Press or hold</> to <#RED>Block</>; the dodge button always <#RED>rolls</>.\n\nThe Greatsword's block, on this button instead of the dodge button with no direction. Press or hold to block (panic block and dash block too). The dodge button always rolls: with no direction, forward. On B, B only blocks: put the Greatsword's skill on LT, RT or RS.",
	},
	[Core.CANNON_DODGE] = {
		weapon = Core.CANNON_WEAPON, setting = "cannon_dodge", installed = "cannon_installed",
		icon = Core.CANNON_DODGE_ICON, slots = { B = true, LT = true, RT = true, RS = true },
		name = "Dodge",
		desc = "The Cannon's roll. <#RED>Press</> to <#RED>roll</>; the dodge button <#RED>plants</> and <#RED>reloads</>.\n\nThe Cannon's roll on this button, like every other weapon's roll. The dodge button stays the Cannon's own: plant, and reload while planted. On B, B only rolls: put the Cannon's skill on LT, RT or RS.",
	},
	[Core.CANNON_RELOAD] = {
		weapon = Core.CANNON_WEAPON, setting = "cannon_reload", installed = "cannon_installed",
		icon = Core.CANNON_RELOAD_ICON, slots = { B = true, LT = true, RT = true, RS = true },
		name = "Reload",
		desc = "The Cannon's plant and reload. <#RED>Press</> to <#RED>plant</>, again to <#RED>reload</>; the dodge button always <#RED>rolls</>.\n\nThe Cannon's plant and reload on this button: press to plant, press again while planted to reload (what the dodge button does in the game). The dodge button rolls instead, like every other weapon. On B, B only plants and reloads: put the Cannon's skill on LT, RT or RS (while planted, a skill button fires Backfire, like B in the game).",
	},
}
Core.PSEUDO_ORDER = { Core.BLOCK, Core.CANNON_DODGE, Core.CANNON_RELOAD } -- menu order, and the default's tie-break

-- Skills of no weapon, by kind (class_icons): boss / miniboss skills, and the
-- rest (Fist Pound, Throw Stone, Parry...: any weapon). Their icons: the
-- game's boss icon (kill counts) and its any-weapon icon (Select Weapon).
Core.CLASS_ICONS = { boss = "images/icons_ftf/inventory_bosses.tex", miniboss = "images/icons_ftf/inventory_bosses.tex",
	universal = "images/icons_ftf/inventory_weapon.tex" }
function Core.SkillClass(name)
	if Core.settings == nil or Core.settings.class_icons == false or type(name) ~= "string" or name == Core.WEAPON then
		return nil
	end
	if name:find("^boss_") then
		return "boss"
	elseif name:find("^miniboss_") then
		return "miniboss"
	end
	return "universal"
end

-- Skills the menu never shows, even with Show all (broken in the game).
function Core.IsHiddenSkill(name)
	local list = Core.settings ~= nil and Core.settings.hidden_skills or nil
	for _, n in ipairs(type(list) == "table" and list or {}) do
		if n == name then
			return true
		end
	end
	return false
end

local pseudo_defs = {}
function Core.GetPseudoDef(name)
	local p = Core.PSEUDO[name]
	if p == nil then
		return nil
	end
	if pseudo_defs[name] == nil then
		local tag = POWER_TAGS ~= nil and rawget(POWER_TAGS, p.weapon) or nil
		pseudo_defs[name] = {
			name = name,
			slot = Power.Slots.SKILL,
			power_type = Power.Types.SKILL,
			icon = p.icon,
			pretty = { name = p.name, desc = p.desc },
			required_tags = tag ~= nil and { tag } or nil,
			tags = {},
			skillslots_pseudo = true,
			skillslots_weapon = p.weapon,
		}
	end
	return pseudo_defs[name]
end
function Core.GetBlockDef()
	return Core.GetPseudoDef(Core.BLOCK)
end

function Core.IsPseudo(name)
	return name ~= nil and Core.PSEUDO[name] ~= nil
end

-- Its module installed fine (an update that broke it switches only that one off).
function Core.PseudoInstalled(name)
	local p = Core.PSEUDO[name]
	return p ~= nil and Core[p.installed] == true
end

-- Can this weapon choice go on this button?
function Core.PseudoAllowed(name, slot)
	local p = Core.PSEUDO[name]
	return p ~= nil and p.slots[slot] == true
end

-- A skill def by name (weapon choices included), or nil.
function Core.GetDef(name)
	if Core.IsPseudo(name) then
		return Core.GetPseudoDef(name)
	end
	return type(name) == "string" and rawget(Power.Items[Power.Slots.SKILL], name) or nil
end

-- name -> def, Block included (for code that indexes the skill list)
Core.Defs = setmetatable({}, { __index = function(_, name) return Core.GetDef(name) end })

-- What the game's skill icon widget needs from a skill item.
function Core.MakePseudoItem(def)
	return {
		GetDef = function() return def end,
		GetRarity = function() return Power.Rarity ~= nil and Power.Rarity.COMMON or "COMMON" end,
		skillslots_pseudo = true,
	}
end

local warned = {}
local function ValidSkill(name)
	if type(name) ~= "string" or name == "" or name == Core.EMPTY then
		return nil
	end
	if Core.IsPseudo(name) then
		return name
	end
	if rawget(Power.Items[Power.Slots.SKILL], name) ~= nil then
		return name
	end
	if not warned[name] then
		warned[name] = true
		Core.Log(string.format('unknown skill "%s" in skillslots_settings.lua, that slot stays empty', name))
	end
	return nil
end

local function GetHunterId(inst)
	if inst.GetHunterId == nil then
		return nil
	end
	local ok, id = pcall(inst.GetHunterId, inst)
	return ok and id or nil
end

-- Where a slot is saved: in the loadout of the weapon type in hand.
local function SlotKey(inst, slot, weapon)
	weapon = weapon or Core.GetCurrentWeapon(inst)
	return weapon ~= nil and (slot .. ":" .. weapon) or slot
end

-- Before loadouts, one set of slots was shared by every weapon. Move the
-- values that belong to one weapon into its loadout: a weapon skill goes to
-- its own weapon, and B (the weapon you set it with) to the weapon in hand.
-- Shared skills on LT / RT / RS stay as the starting point for every weapon.
local function MoveShared(inst, data)
	for _, slot in ipairs(Core.MENU_SLOTS) do
		local old = data.slots[slot]
		if old ~= nil then
			local def = Core.GetDef(old)
			local weapon = def ~= nil and Core.GetSkillWeapon(def) or nil
			if weapon == nil and slot == "B" then
				weapon = Core.GetCurrentWeapon(inst)
			end
			if weapon ~= nil then
				local key = slot .. ":" .. weapon
				if data.slots[key] == nil and old ~= Core.WEAPON then
					data.slots[key] = old
				end
				data.slots[slot] = nil
			end
		end
	end
end

-- What's on a slot for this player: a skill name, Core.WEAPON, or nil (empty).
-- A choice made in the menu (saved with the character) wins; otherwise the
-- defaults from the settings file.
function Core.GetSlotValue(inst, slot)
	local data = inst ~= nil and inst.components ~= nil and inst.components.skillslotsdata or nil
	local value
	if data ~= nil then
		MoveShared(inst, data)
		value = data.slots[SlotKey(inst, slot)]
	end
	if value == nil then
		value = Core.GetPseudoDefault(inst, slot) -- a weapon choice that starts on this slot
	end
	if value == nil and data ~= nil then
		value = data.slots[slot] -- shared starting point
	end
	if value == nil then
		local s = Core.settings
		value = s.slots[slot]
		local id = GetHunterId(inst)
		local per = id ~= nil and s.players[id] or nil
		if type(per) == "table" and per[slot] ~= nil then
			value = per[slot]
		end
		if value == nil and slot == "B" then
			value = Core.WEAPON
		end
	end
	if value == Core.WEAPON then
		return Core.WEAPON
	end
	return ValidSkill(value)
end

-- The skill a slot fires right now ("weapon" resolved), or nil.
function Core.GetSlotSkill(inst, slot, exclude)
	local value = Core.GetSlotValue(inst, slot)
	if value == Core.WEAPON then
		return Core.GetNativeSkillName(inst, exclude)
	end
	if value == exclude then
		return nil
	end
	return value
end

-- The weapon choice that starts on this slot for the weapon in hand
-- (settings: greatsword_block, cannon_dodge, cannon_reload), or nil.
function Core.GetPseudoDefault(inst, slot)
	local s = Core.settings
	if s == nil then
		return nil
	end
	local weapon
	for _, name in ipairs(Core.PSEUDO_ORDER) do
		local p = Core.PSEUDO[name]
		if s[p.setting] == slot and Core.PseudoInstalled(name) then
			weapon = weapon or Core.GetCurrentWeapon(inst) or false
			if weapon == p.weapon then
				return name
			end
		end
	end
	return nil
end
function Core.IsBlockDefaultSlot(inst, slot)
	return Core.GetPseudoDefault(inst, slot) == Core.BLOCK
end

-- The button a weapon choice is on for the weapon in hand (B included), or nil.
function Core.FindPseudoSlot(inst, name)
	for _, slot in ipairs(Core.MENU_SLOTS) do
		if Core.GetSlotValue(inst, slot) == name then
			return slot
		end
	end
	return nil
end

-- Block is on one of the Greatsword's buttons (LT / RT / RS or B).
function Core.HasBlockSlot(inst)
	return Core.FindPseudoSlot(inst, Core.BLOCK) ~= nil
end

-- B holds a weapon choice (Block on B): B doesn't fire a skill.
function Core.BHoldsPseudo(inst)
	return Core.IsPseudo(Core.GetSlotValue(inst, "B"))
end

-- What to save for an empty slot: nil, or "none" where nil would bring a
-- default back (a weapon choice's starting slot).
local function EmptyValue(inst, slot)
	if Core.GetPseudoDefault(inst, slot) ~= nil then
		return Core.EMPTY
	end
	return nil
end

-- A button uses this skill (B's "weapon" counts as the weapon's skill).
function Core.SkillInUse(inst, name)
	for _, slot in ipairs(Core.MENU_SLOTS) do
		if Core.GetSlotSkill(inst, slot) == name then
			return true
		end
	end
	return false
end

-- skill name -> slot, for every slot holding a named skill (not "weapon")
function Core.GetWantedSet(inst)
	local set = {}
	for _, slot in ipairs(Core.MENU_SLOTS) do
		local value = Core.GetSlotValue(inst, slot)
		if value ~= nil and value ~= Core.WEAPON and set[value] == nil then
			set[value] = slot
		end
	end
	return set
end

-- Put a skill (or Core.WEAPON) on a slot for this player. nil = empty, except
-- on B where it means the weapon's skill again. A value can only be on one
-- slot, so if it's on another slot the two slots swap. Changes the loadout of
-- the weapon type in hand.
function Core.SetSlotSkill(inst, slot, value)
	local data = inst.components.skillslotsdata
	if data == nil then
		return false
	end
	if value == nil and slot == "B" then
		value = Core.WEAPON
	end
	if Core.IsPseudo(value) and not Core.PseudoAllowed(value, slot) then
		return false -- Dodge / Reload go on LT / RT / RS only
	end
	local old = Core.GetSlotValue(inst, slot)
	if value ~= nil then
		for _, other in ipairs(Core.MENU_SLOTS) do
			if other ~= slot and Core.GetSlotValue(inst, other) == value then
				local moved = old
				if Core.IsPseudo(moved) and not Core.PseudoAllowed(moved, other) then
					moved = nil -- can't go there: that slot goes back to empty / B's weapon skill
				end
				data:Set(SlotKey(inst, other), moved or (other == "B" and Core.WEAPON) or EmptyValue(inst, other))
			end
		end
	end
	data:Set(SlotKey(inst, slot), value or EmptyValue(inst, slot))
	Core.Sync(inst)
	return true
end

-- Weapon type a skill needs (from the game's own required_tags), or nil.
local tag_to_weapon
local function GetTagToWeapon()
	if tag_to_weapon == nil then
		tag_to_weapon = {}
		for key, value in pairs(WEAPON_TYPES or {}) do
			local tag = POWER_TAGS ~= nil and rawget(POWER_TAGS, key) or nil
			if key == value and tag ~= nil then
				tag_to_weapon[tag] = key
			end
		end
	end
	return tag_to_weapon
end

-- Boss and miniboss skills, and Parry (Bandicoot's): each of those bosses
-- has a weapon of every type with the skill, so they work with any weapon
-- (the game data marks Thatcher's as Bow-only, a slip: its B fires it on
-- every Thatcher weapon) and count as owned per weapon type.
function Core.IsBossSkill(name)
	return type(name) == "string" and (name:find("^boss_") ~= nil or name:find("^miniboss_") ~= nil or name == "parry")
end

function Core.GetSkillWeapon(def)
	if def ~= nil and def.skillslots_weapon ~= nil then
		return def.skillslots_weapon -- a weapon choice: its weapon
	end
	if def ~= nil and Core.IsBossSkill(def.name) then
		return nil
	end
	local map = GetTagToWeapon()
	for _, tag in ipairs(def ~= nil and def.required_tags or {}) do
		if map[tag] ~= nil then
			return map[tag]
		end
	end
	return nil
end

local WEAPON_NAMES = { HAMMER = "Hammer", POLEARM = "Spear", SHOTPUT = "Striker", BOW = "Bow", CANNON = "Cannon", CLEAVER = "Greatsword" }
function Core.GetWeaponName(key)
	local names = STRINGS ~= nil and rawget(STRINGS, "NAMES") or nil
	local name = type(names) == "table" and rawget(names, "weapon_" .. string.lower(key)) or nil
	return type(name) == "string" and name or WEAPON_NAMES[key] or key
end

-- Weapon type in hand ("HAMMER", "BOW", ...). The equipped weapon gives the
-- inventory a lowercase weapon type tag ("hammer", "bow", ...).
function Core.GetCurrentWeapon(inst)
	local inv = inst.components ~= nil and inst.components.inventory or nil
	if inv ~= nil and inv.HasTag ~= nil then
		for _, key in pairs(GetTagToWeapon()) do
			if inv:HasTag(string.lower(key)) then
				return key
			end
		end
	end
	-- fallback: the equipped weapon's own type
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard ~= nil and hoard.GetEquippedItem ~= nil then
		local ok, item = pcall(hoard.GetEquippedItem, hoard, "WEAPON")
		local def = ok and item ~= nil and item.GetDef ~= nil and item:GetDef() or nil
		local key = def ~= nil and def.weapon_type or nil
		if key ~= nil and WEAPON_TYPES ~= nil and rawget(WEAPON_TYPES, key) == key then
			return key
		end
	end
	return nil
end

-- Can this player fire the skill right now? (weapon skills: that weapon in hand)
function Core.CanUse(inst, def)
	if def ~= nil and def.skillslots_weapon ~= nil then
		return Core.GetCurrentWeapon(inst) == def.skillslots_weapon -- a weapon choice
	end
	local tags = def ~= nil and def.required_tags or nil
	if tags == nil or Core.IsBossSkill(def.name) then
		return true
	end
	local map = GetTagToWeapon()
	local inv = inst.components ~= nil and inst.components.inventory or nil
	for _, tag in ipairs(tags) do
		local has
		if map[tag] ~= nil then
			has = Core.GetCurrentWeapon(inst) == map[tag]
		else
			has = (inst.HasTag ~= nil and inst:HasTag(tag))
				or (inv ~= nil and inv.HasTag ~= nil and inv:HasTag(tag))
		end
		if not has then
			return false
		end
	end
	return true
end

-- weapon_type: only that type's weapons count (nil = any)
local function OwnsWeaponWithSkill(inst, name, weapon_type)
	local hoard = inst.components.inventoryhoard
	local items = hoard ~= nil and hoard:GetSlotItems("WEAPON") or nil
	for _, item in pairs(items or {}) do
		local ok, usage = pcall(item.GetUsageData, item)
		if ok and usage ~= nil and usage.skill_on_equip == name then
			if weapon_type == nil then
				return true
			end
			local okd, def = pcall(item.GetDef, item)
			if okd and def ~= nil and def.weapon_type == weapon_type then
				return true
			end
		end
	end
	return false
end

-- Does this player own the skill? A weapon they own that comes with it, or a
-- copy they have right now that this mod didn't add. In this build skills
-- only come from weapons (no skill drops in runs). The game's power unlock
-- record is NOT used: every new character gets the whole skill list unlocked
-- by default (defs/metaprogression/defaultunlocks.lua), so it says nothing
-- about owning a skill.
-- Boss / miniboss skills and Parry count per weapon type: owned for a weapon
-- type only with that boss's weapon of that type (weapon = the type, default
-- the one in hand). Only a menu filter: every skill works owned or not.
function Core.OwnsSkill(inst, name, weapon)
	if Core.settings.all_skills or Core.IsPseudo(name) then
		return true
	end
	if Core.IsBossSkill(name) then
		local current = Core.GetCurrentWeapon(inst)
		weapon = weapon or current
		if weapon ~= nil then
			if OwnsWeaponWithSkill(inst, name, weapon) then
				return true
			end
			if weapon ~= current then
				return false
			end
			-- the game gave it with the weapon in hand (its B): counts below
		elseif OwnsWeaponWithSkill(inst, name) then
			return true
		end
	elseif OwnsWeaponWithSkill(inst, name) then
		return true
	end
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	local pow = pm ~= nil and pm.powers ~= nil and pm.powers[name] or nil
	return pow ~= nil and not (pow.persistdata ~= nil and pow.persistdata.skillslots) or false
end

-- The menu list: { { name, def, unlocked, owned, weapon, usable, token } ... }
-- First "weapon" (the weapon's own skill), then basic skills, the weapon in
-- hand's skills, miniboss and boss skills, the ones you own first; at the
-- bottom everything that needs another weapon. Nothing is locked: "Hide
-- unavailable" hides other weapons' skills and the ones you don't own, and
-- "Show all" lets you put any skill on a slot (for trying them out).
function Core.GetChoices(inst)
	local current = Core.GetCurrentWeapon(inst)
	local native = Core.GetNativeSkillName(inst)
	local list = {}
	for name, def in pairs(Power.Items[Power.Slots.SKILL]) do
		if not Core.IsHiddenSkill(name) then
			local weapon = Core.GetSkillWeapon(def)
			list[#list + 1] = { name = name, def = def, unlocked = true, owned = Core.OwnsSkill(inst, name),
				weapon = weapon, usable = Core.CanUse(inst, def) }
		end
	end
	local order = {}
	for i, key in ipairs(WEAPON_ORDER or {}) do
		order[key] = i
	end
	local pseudo_rank = {}
	for i, name in ipairs(Core.PSEUDO_ORDER) do
		pseudo_rank[name] = i
		if Core.PseudoInstalled(name) then
			local def = Core.GetPseudoDef(name)
			list[#list + 1] = { name = name, def = def, unlocked = true, owned = true,
				weapon = Core.PSEUDO[name].weapon, usable = Core.CanUse(inst, def) }
		end
	end
	local function group(c)
		if c.name:find("^boss_") then return 4 end
		if c.name:find("^miniboss_") then return 3 end
		if c.weapon ~= nil then return 2 end
		return 1
	end
	local function weapon_rank(c)
		if c.weapon == nil then return 0 end
		if c.weapon == current then return -1 end
		return order[c.weapon] or 99
	end
	table.sort(list, function(a, b)
		if a.usable ~= b.usable then
			return a.usable
		end
		local ga, gb = group(a), group(b)
		if ga ~= gb then
			return ga < gb
		end
		local wa, wb = weapon_rank(a), weapon_rank(b)
		if wa ~= wb then
			return wa < wb
		end
		if a.owned ~= b.owned then
			return a.owned
		end
		local pa, pb = pseudo_rank[a.name], pseudo_rank[b.name]
		if (pa ~= nil) ~= (pb ~= nil) then
			return pa ~= nil -- weapon choices first among their weapon's
		elseif pa ~= nil then
			return pa < pb
		end
		return a.name < b.name
	end)
	local items = Power.Items[Power.Slots.SKILL]
	table.insert(list, 1, { name = Core.WEAPON, def = native ~= nil and items[native] or nil,
		unlocked = true, owned = true, usable = true, token = true })
	return list
end

-- Shown while "Hide unavailable" is on: usable with the weapon in hand, and owned.
function Core.IsAvailable(choice)
	return choice.token or (choice.usable and choice.owned) or false
end

-- Menu option: hide unavailable skills (other weapons' and the ones you don't
-- own). Every time the menu opens it starts hidden (the settings file can
-- make it start with Show all); the button changes it until the menu closes.
-- Not saved.
function Core.GetHideOther(inst)
	if inst ~= nil and inst.skillslots_hide ~= nil then
		return inst.skillslots_hide
	end
	return Core.settings.hide_other_weapons ~= false
end

function Core.SetHideOther(inst, hide)
	if inst ~= nil then
		inst.skillslots_hide = hide == true
	end
end

-- The menu opened: back to the starting choice.
function Core.ResetHideOther(inst)
	if inst ~= nil then
		inst.skillslots_hide = nil
	end
end

-- Menu option: show the LT / RT / RS skill icons on the HUD. Saved per
-- character; the settings file (hud.show) gives the starting value.
function Core.GetHudIcons(inst)
	local data = inst ~= nil and inst.components ~= nil and inst.components.skillslotsdata or nil
	local saved
	if data ~= nil and data.options ~= nil then
		saved = data.options.hud_icons
	end
	if saved ~= nil then
		return saved
	end
	return Core.settings.hud.show ~= false
end

function Core.SetHudIcons(inst, on)
	local data = inst.components ~= nil and inst.components.skillslotsdata or nil
	if data ~= nil and data.SetOption ~= nil then
		data:SetOption("hud_icons", on == true)
	end
	inst:PushEvent("skillslots_changed")
end

-- Menu option: the names over the skills in the list ("Hammer", "Any",
-- "Miniboss"...). Off each time the menu opens (the settings file's
-- list_names = true: on); "Names" (LB, keyboard Q) switches them while it's
-- open, not kept for next time.
Core.list_names_now = setmetatable({}, { __mode = "k" })

function Core.GetListNames(inst)
	local now = inst ~= nil and Core.list_names_now[inst] or nil
	if now ~= nil then
		return now
	end
	return Core.settings ~= nil and Core.settings.list_names == true
end

function Core.SetListNames(inst, on)
	if inst ~= nil then
		Core.list_names_now[inst] = on == true
	end
end

-- the menu opens: back to the start value
function Core.ResetListNames(inst)
	if inst ~= nil then
		Core.list_names_now[inst] = nil
	end
end

-- A skill picture that runs over its frame (icon_scale): smaller, on the game's
-- SkillIconWidget (its picture is 1.1 x the frame). Others: the game's size.
function Core.FitIcon(widget, def)
	local img = widget ~= nil and rawget(widget, "icon") or nil
	local base = widget ~= nil and rawget(widget, "base_width") or nil
	if img == nil or type(base) ~= "number" or img.SetSize == nil then
		return
	end
	local scales = Core.settings ~= nil and Core.settings.icon_scale or nil
	local k = def ~= nil and type(scales) == "table" and tonumber(scales[def.name]) or nil
	if k == nil or k <= 0 or k > 2 then
		k = 1
	end
	img:SetSize(base * 1.10 * k, base * 1.10 * k)
end

function Core.GetSkillName(def)
	local pretty = def ~= nil and (def.pretty_override or def.pretty) or nil
	return pretty ~= nil and pretty.name or (def ~= nil and def.name) or ""
end

----------------------------------------------------------------------------
-- Power helpers

local function GetPM(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.powermanager or nil
end

local function IsSkill(pow)
	return pow ~= nil and pow.def ~= nil and pow.def.slot == Power.Slots.SKILL
end

local function IsPermanent(pow)
	return pow.def.permanent or (pow.mem ~= nil and pow.mem.permanent) or false
end

local function IsEquipmentSkill(pm, name)
	for _, list in pairs(pm.skills_from_equipment or {}) do
		for _, skill in ipairs(list) do
			if skill.name == name then
				return true
			end
		end
	end
	return false
end

function Core.IsActive(inst)
	return Core.enabled and inst ~= nil and inst.skillslots ~= nil
end

function Core.HasPower(inst, name)
	local pm = GetPM(inst)
	return name ~= nil and pm ~= nil and pm.powers ~= nil and pm.powers[name] ~= nil
end

-- The weapon's own skill: the weapon's, or else the newest skill that isn't on
-- a slot (one picked up during a run, or given from the debug menu), like
-- vanilla B.
function Core.GetNativeSkillName(inst, exclude)
	local pm = GetPM(inst)
	if pm == nil or pm.powers == nil then
		return nil
	end
	for _, list in pairs(pm.skills_from_equipment or {}) do
		for _, skill in ipairs(list) do
			if skill.name ~= exclude and pm.powers[skill.name] ~= nil then
				return skill.name
			end
		end
	end
	local wanted = Core.GetWantedSet(inst)
	local best, best_order
	for name, pow in pairs(pm.powers) do
		if name ~= exclude and IsSkill(pow) and wanted[name] == nil then
			local order = pow.persistdata ~= nil and pow.persistdata.acquire_order or 0
			if best == nil or order > best_order then
				best, best_order = name, order
			end
		end
	end
	return best
end

-- The skill B fires.
function Core.GetBSkillName(inst, exclude)
	return Core.GetSlotSkill(inst, "B", exclude)
end

-- A skill that is on an extra button (LT / RT / RS) and isn't B's skill.
function Core.IsSlotOnlySkill(inst, name)
	if not Core.IsActive(inst) or name == nil then
		return false
	end
	if name == Core.GetBSkillName(inst) then
		return false
	end
	for _, slot in ipairs(Core.SLOT_ORDER) do
		if Core.GetSlotSkill(inst, slot) == name then
			return true
		end
	end
	return false
end

local function IsSlotOnlyState(inst, state)
	for _, slot in ipairs(Core.SLOT_ORDER) do
		local name = Core.GetSlotSkill(inst, slot)
		if name ~= nil and "skill_" .. name == state then
			return Core.IsSlotOnlySkill(inst, name)
		end
	end
	return false
end

-- Put B's skill back in sg.mem.skillstate.
-- What sg.mem.skillstate holds between presses (B's skill state).
function Core.SettledSkillState(inst, exclude)
	local name = Core.GetBSkillName(inst, exclude)
	if Core.IsPseudo(name) then
		name = Core.GetPseudoBSkill(inst, exclude)
	end
	return name ~= nil and ("skill_" .. name) or nil
end

function Core.Settle(inst, exclude)
	if not Core.IsActive(inst) or inst.sg == nil or inst.sg.mem == nil then
		return
	end
	inst.sg.mem.skillstate = Core.SettledSkillState(inst, exclude)
end

-- Block on B: B fires no skill. The game still reads sg.mem.skillstate for
-- the Greatsword's attack-into-skill combos, so it holds the weapon's own
-- skill when that is on LT / RT / RS (the combos follow it there), else nil.
function Core.GetPseudoBSkill(inst, exclude)
	local native = Core.GetNativeSkillName(inst, exclude)
	if native == nil then
		return nil
	end
	for _, slot in ipairs(Core.SLOT_ORDER) do
		if Core.GetSlotSkill(inst, slot) == native then
			return native
		end
	end
	return nil
end

local function SetMine(pow, mine)
	pow.mem.permanent = mine or nil
	pow.persistdata.permanent = mine or nil
	pow.persistdata.skillslots = mine or nil
end

-- Make the player's skill powers match the slots.
function Core.Sync(inst)
	if not Core.IsActive(inst) or not inst:IsValid() then
		return
	end
	if inst.IsLocal ~= nil and not inst:IsLocal() then
		return
	end
	local pm = GetPM(inst)
	if pm == nil or pm.powers == nil then
		return
	end
	-- named slot skills this player can use right now (weapon skills need
	-- their weapon in hand)
	local items = Power.Items[Power.Slots.SKILL]
	local wanted = {}
	for name, slot in pairs(Core.GetWantedSet(inst)) do
		if not Core.IsPseudo(name) and Core.CanUse(inst, items[name]) then
			wanted[name] = slot
		end
	end

	-- skills this mod added that no slot uses any more
	local stale = {}
	for name, pow in pairs(pm.powers) do
		if IsSkill(pow) and pow.persistdata ~= nil and pow.persistdata.skillslots and wanted[name] == nil then
			stale[#stale + 1] = name
		end
	end
	for _, name in ipairs(stale) do
		SetMine(pm.powers[name], false)
		if not IsEquipmentSkill(pm, name) then
			pm:RemovePowerByName(name, true)
		end
	end

	if pm.CanReceivePowers == nil or pm:CanReceivePowers() then
		for name in pairs(wanted) do
			if pm.powers[name] == nil then
				pm:AddPowerByName(name, nil, { permanent = true })
			end
			local pow = pm.powers[name]
			if pow ~= nil and not pow.persistdata.skillslots then
				SetMine(pow, true)
			end
		end
	end

	Core.Settle(inst)
	Core.UpdatePresence(inst)
	inst:PushEvent("skillslots_changed")
end

----------------------------------------------------------------------------
-- Skills that keep something with you while you have the power: the Sedament
-- skill summons its crow when added and sends it away when removed. The game
-- always gives you your weapon's own skill, so the crow came with the Sedament
-- weapon even with the skill on no button. Now the crow is there only while a
-- button uses the skill (B's "Weapon skill" counts), on any weapon.

local PRESENCE = {
	boss_sedament = {
		-- what the power does when added (the game's on_add_fn) is the summon;
		-- sending away is what its on_remove_fn does
		dismiss = function(pow, inst)
			if pow.mem.minion ~= nil then
				if pow.mem.minion.IsValid == nil or pow.mem.minion:IsValid() then
					pow.mem.minion:PushEvent("despawn")
				end
				pow.mem.minion = nil
			end
		end,
	},
}
Core.PRESENCE = PRESENCE

function Core.UpdatePresence(inst)
	local pm = GetPM(inst)
	if pm == nil or pm.powers == nil or not Core.IsActive(inst) then
		return
	end
	for name, entry in pairs(PRESENCE) do
		local pow = pm.powers[name]
		if pow ~= nil and pow.mem ~= nil and entry.summon ~= nil then
			local wanted = Core.SkillInUse(inst, name)
			if wanted and pow.mem.skillslots_away then
				pow.mem.skillslots_away = nil
				entry.summon(pow, inst)
			elseif not wanted and not pow.mem.skillslots_away then
				entry.dismiss(pow, inst)
				pow.mem.skillslots_away = true
			end
		end
	end
end

-- TEMP debug: log every move from one skill state to another (the skill
-- restart bug), with the last skill press and who started the new state.
local debug_left = 60
local function Tick()
	local sim = rawget(_G, "TheSim")
	return sim ~= nil and sim.GetTick ~= nil and sim:GetTick() or 0
end

function Core.DebugSkills(inst)
	local prev, prev_tick = nil, 0
	local function OnNewState(inst, data)
		local name = data ~= nil and data.statename or nil
		local now = Tick()
		if type(name) == "string" and type(prev) == "string" and prev:find("^skill_") and name:find("^skill_") and debug_left > 0 then
			debug_left = debug_left - 1
			local press = inst.skillslots_lastpress
			local press_txt = "no press"
			if press ~= nil then
				press_txt = string.format("last press %d ticks ago in %s (canskill=%s canattack=%s combo=%s held=%s)",
					now - press.tick, tostring(press.state), tostring(press.canskill), tostring(press.canattack),
					tostring(press.combo), tostring(press.held))
			end
			local ok, tb = pcall(debug.traceback, "", 2)
			Core.Log(string.format("debug: %s (%d ticks) -> %s; %s%s", prev, now - prev_tick, name, press_txt,
				ok and ("\n" .. tostring(tb)) or ""))
		end
		prev, prev_tick = name, now
	end
	inst:ListenForEvent("newstate", function(inst, data)
		local ok, err = pcall(OnNewState, inst, data)
		if not ok and debug_left > 0 then
			debug_left = 0
			Core.Log("debug error: " .. tostring(err))
		end
	end)
end

-- (a sync after a loadout change / room: an error is logged, the game carries on)
local function SafeSync(inst)
	Core.G.Call("skill sync", Core.Sync, inst)
end

function Core.SetupPlayer(inst)
	if inst.skillslots ~= nil then
		return
	end
	-- the HUD frame (name badge, weapon tips) is hooked once the game is fully loaded
	pcall(function() require("skillslots.hud").LateInstall() end)
	if Core.settings.debug_skills then
		pcall(Core.DebugSkills, inst)
	end
	inst.skillslots = {}
	if inst.components ~= nil and inst.components.skillslotsdata == nil then
		inst:AddComponent("skillslotsdata")
	end
	local function SyncSoon()
		if inst:IsValid() then
			inst:DoTaskInTime(0, SafeSync)
		end
	end
	inst:ListenForEvent("loadout_changed", SyncSoon)
	inst:ListenForEvent("setup_new_run_powers", SyncSoon)
	inst:ListenForEvent("character_slot_changed", SyncSoon)
	inst:ListenForEvent("enter_room", SyncSoon)
	SyncSoon()
end

----------------------------------------------------------------------------
-- The Bow's primed-arrow skills (Toxic Dip, Cold Plunge...) share one
-- animation and its "priming" / "primed" events, and every one of them on you
-- answers: the last one wins, so with two slotted both buttons gave the same
-- arrow. Now only the one you pressed answers, and priming one un-primes the
-- other. inst.skillslots_prime = the one pressed last.

local PRIME = "^bow_primearrow_"

function Core.NotePrime(inst, state)
	if type(state) == "string" and state:find("^skill_bow_primearrow_") then
		inst.skillslots_prime = state:sub(#"skill_" + 1)
	end
end

local function Unprime(inst, keep)
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	for name, pow in pairs(pm ~= nil and pm.powers or {}) do
		if name ~= keep and name:find(PRIME) and pow.persistdata ~= nil and pow.persistdata.primed then
			local used = pow.def.event_triggers ~= nil and pow.def.event_triggers.bow_primearrow_used or nil
			if used ~= nil then
				used(pow, inst)
			end
		end
	end
end

-- whether this primed-arrow skill answers its shared event
function Core.PrimeAnswers(pow, inst, event)
	local choice = inst.skillslots_prime
	if choice == nil then
		return true -- nothing pressed through the slots: the game's own way
	end
	if choice ~= pow.def.name then
		return false
	end
	if event == "bow_primearrow_ready" then
		Unprime(inst, choice)
	end
	return true
end

----------------------------------------------------------------------------
-- Boss skills that answer every skill (Mother Treek, Sedament, Eggzy...)
-- In the game a player has one skill, so some skill powers react to any
-- skill's events: "activate_skill" (pushed by a boss skill's state when it
-- goes off: Mother Treek summons its roots, Sedament buffs its crow) and a
-- skill press during a heavy attack ("controlevent": charges the heavy with
-- the boss skill and eats the press). With several skills on buttons, Owlitzer
-- on RT also set off Mother Treek's roots, and any skill button charged the
-- heavy. Now only the skill that's going off / was pressed answers.

-- The skill power whose state this is ("skill_boss_eggzy_success" -> boss_eggzy), or nil.
function Core.SkillOfState(inst, state)
	if type(state) ~= "string" or state:sub(1, 6) ~= "skill_" then
		return nil
	end
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	local best
	for name, pow in pairs(pm ~= nil and pm.powers or {}) do
		if IsSkill(pow) then
			local s = "skill_" .. name
			if (state == s or state:sub(1, #s + 1) == s .. "_") and (best == nil or #name > #best) then
				best = name
			end
		end
	end
	return best
end

-- whether this skill power answers "activate_skill": the skill whose state is running
function Core.SkillAnswers(pow, inst)
	if not Core.IsActive(inst) then
		return true
	end
	local sg = inst.sg
	local state = sg ~= nil and sg.currentstate ~= nil and sg.currentstate.name or nil
	local owner = Core.SkillOfState(inst, state)
	if owner == nil then
		return true -- not a skill's state: the game's way
	end
	return owner == pow.def.name
end

-- whether this skill power answers a skill press: the skill on the button pressed
function Core.PressAnswers(pow, inst, data)
	if not Core.IsActive(inst) or type(data) ~= "table" or data.control ~= "skill" then
		return true
	end
	local name
	if data.skillslots_slot ~= nil then
		name = Core.GetSlotSkill(inst, data.skillslots_slot)
	else
		name = Core.GetBSkillName(inst)
	end
	return name ~= nil and name == pow.def.name
end

----------------------------------------------------------------------------
-- Hooks

-- Every skill power sets sg.mem.skillstate to itself when added, on room
-- enter and on loadout change, and clears it when removed. With several skill
-- powers the last one would win, so after each of those put B's skill back.
local function WrapSkillDef(def)
		local G = Core.G -- (bulletproofing: an error in Skill Slots' part: the game's way)
		local on_add, on_remove = def.on_add_fn, def.on_remove_fn
		local presence = PRESENCE[def.name]
		if presence ~= nil and on_add ~= nil then
			presence.summon = on_add
		end
		def.on_add_fn = function(pow, inst, ...)
			local active = false
			if presence ~= nil and on_add ~= nil then
				local ok, yes = G.Call("skill added", Core.IsActive, inst)
				active = ok and yes
			end
			if active then
				-- not yet: the check below summons it if a button uses the skill
				-- (next frame, once the weapon swap / loadout has settled)
				pow.mem.skillslots_away = true
				if inst.DoTaskInTime ~= nil then
					inst:DoTaskInTime(0, function()
						if inst:IsValid() then
							G.Call("skill helper (summon / send away)", Core.UpdatePresence, inst)
						end
					end)
				end
			elseif on_add ~= nil then
				on_add(pow, inst, ...)
			end
			G.Call("skill added: settle", Core.Settle, inst)
		end
		def.on_remove_fn = function(pow, inst, ...)
			if on_remove ~= nil then
				on_remove(pow, inst, ...)
			end
			G.Call("skill removed: settle", Core.Settle, inst, pow.def.name)
		end
		local triggers = def.event_triggers
		if triggers ~= nil and type(def.name) == "string" and def.name:find(PRIME) then
			for _, event in ipairs({ "bow_primearrow_fxstart", "bow_primearrow_ready" }) do
				local fn = triggers[event]
				if fn ~= nil then
					local where = "primed arrow: " .. event
					triggers[event] = function(pow, inst, ...)
						local ok, answers = G.Call(where, Core.PrimeAnswers, pow, inst, event)
						if not ok or answers then
							return fn(pow, inst, ...)
						end
					end
				end
			end
			-- coming into a room primed: it puts itself back (and only it)
			local fn = triggers.enter_room
			if fn ~= nil then
				triggers.enter_room = function(pow, inst, ...)
					if pow.persistdata ~= nil and pow.persistdata.primed then
						inst.skillslots_prime = pow.def.name
					end
					return fn(pow, inst, ...)
				end
			end
		end
		if triggers ~= nil then
			local activate = triggers.activate_skill
			if activate ~= nil then
				triggers.activate_skill = function(pow, inst, ...)
					local ok, answers = G.Call("skill activate", Core.SkillAnswers, pow, inst)
					if not ok or answers then
						return activate(pow, inst, ...)
					end
				end
			end
			local control = triggers.controlevent
			if control ~= nil then
				triggers.controlevent = function(pow, inst, data, ...)
					local ok, answers = G.Call("skill control", Core.PressAnswers, pow, inst, data)
					if not ok or answers then
						return control(pow, inst, data, ...)
					end
				end
			end
		end
		if triggers ~= nil then
			for _, event in ipairs({ "enter_room", "loadout_changed" }) do
				local fn = triggers[event]
				if fn ~= nil then
					local where = event .. ": settle"
					triggers[event] = function(pow, inst, ...)
						fn(pow, inst, ...)
						G.Call(where, Core.Settle, inst)
					end
				end
			end
		end
end
Core.WrapSkillDef = WrapSkillDef

local function WrapSkillDefs()
	local wrapped = 0
	for _, def in pairs(Power.Items[Power.Slots.SKILL]) do
		WrapSkillDef(def)
		wrapped = wrapped + 1
	end
	return wrapped
end

local function HookPowerManager()
	-- The skill limit (1) counts only non-slot skills: slot skills are permanent
	-- and the limit is raised by their number for each add.
	local orig_add = PowerManager._AddPowerInternal
	PowerManager._AddPowerInternal = function(self, power, stacks, bypass_prereq_fn, data, ...)
		local skill = Power.Slots.SKILL
		local def = power ~= nil and power.GetDef ~= nil and power:GetDef() or nil
		local limit = Power.MaxCount[skill]
		if def == nil or def.slot ~= skill or limit == nil or not Core.IsActive(self.inst) then
			return orig_add(self, power, stacks, bypass_prereq_fn, data, ...)
		end
		local kept = (data ~= nil and data.permanent) and 1 or 0
		for _, pow in pairs(self.powers) do
			if IsSkill(pow) and IsPermanent(pow) then
				kept = kept + 1
			end
		end
		Power.MaxCount[skill] = limit + kept
		local results = table.pack(pcall(orig_add, self, power, stacks, bypass_prereq_fn, data, ...))
		Power.MaxCount[skill] = limit
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end

	-- Used by the end-of-run summary; show B's skill there.
	local orig_current = PowerManager.GetCurrentSkillPower
	local function BSkill(self)
		if Core.IsActive(self.inst) then
			local name = Core.GetBSkillName(self.inst)
			local pow = name ~= nil and self.powers[name] or nil
			if pow ~= nil then
				return pow.persistdata, name
			end
		end
		return nil
	end
	PowerManager.GetCurrentSkillPower = function(self, ...)
		local ok, data, name = Core.G.Call("run summary skill", BSkill, self)
		if ok and data ~= nil then
			return data, name
		end
		return orig_current(self, ...)
	end
end

local function FindUpvalue(fn, wanted)
	for i = 1, 255 do
		local name, value = debug.getupvalue(fn, i)
		if name == nil then
			return nil
		end
		if name == wanted then
			return value
		end
	end
	return nil
end
Core.FindUpvalue = FindUpvalue

-- Game fix: some skills (Order in the Court, Blarmadillo's swing, the bow's
-- fan shot...) let the skill button in again a few frames into their own
-- attack, so pressing the skill again restarts it from its first frames over
-- and over and the swing never plays out. A press for the skill that's
-- already swinging waits until its attack animation is done (its
-- follow-through, "_pst", or the next state); it stays buffered and fires
-- then. Other skills, attacks and dodges cancel as before, and so does a
-- skill's own follow-up (skillcombostate).
function Core.HoldsSkillRestart(sg, target, combo)
	if not Core.settings.finish_skill_swing or target == nil or combo == target then
		return false
	end
	local state = sg.currentstate
	local name = state ~= nil and state.name or nil
	if type(name) ~= "string" or not sg:HasStateTag("attack") or name:find("_pst$") then
		return false
	end
	return name == target or name:sub(1, #target + 1) == target .. "_"
end

-- The Cannon planted: its Backfire follow-up is open (the plant's hold sets the
-- skill follow-up to a backfire_ state). In the game the skill button fires
-- Backfire there; with B on Reload (or not), every skill button does, any time
-- in the hold. (The plant's first frames read skill presses themselves and
-- already Backfire for any skill button.)
function Core.CannonBackfireOpen(inst, combo)
	return type(combo) == "string" and combo:find("^backfire_") ~= nil
		and Core.GetCurrentWeapon(inst) == Core.CANNON_WEAPON
end

-- One skill press, from B (data.skillslots_slot == nil) or a slot button.
-- What to do (worked out in the guard): "orig" the game's way, "no" nothing
-- (the press stays buffered / was dropped), or "go" with the skill state.
local function SkillPlan(inst, data)
	if not Core.IsActive(inst) or data == nil then
		return "orig"
	end
	if inst.emote_ring ~= nil and inst.emote_ring.IsRingShowing ~= nil and inst.emote_ring:IsRingShowing() then
		return "orig" -- the emote ring is open: the game feeds the press to it
	end
	local sg = inst.sg
	local pc = inst.components.playercontroller
	local slot = data.skillslots_slot
	local statemem = sg.statemem
	local combo = statemem.skillcombostate
	local target, reroute

	if slot ~= nil and Core.CannonBackfireOpen(inst, combo) then
		return "orig" -- the game's way: the follow-up (Backfire)
	end
	if slot ~= nil then
		local name = Core.GetSlotSkill(inst, slot)
		target = name ~= nil and ("skill_" .. name) or nil
		local blocked = inst.emote_ring ~= nil and inst.emote_ring:IsRingShowing()
		if blocked or target == nil or not Core.HasPower(inst, name) or not sg:HasState(target) then
			pc:FlushControlQueueAt(data)
			return "no"
		end
		-- a skill's own follow-up window (skillcombostate) only applies to that skill
		reroute = combo ~= target
		-- Block on B: the Greatsword's attack-into-skill combos (a transition
		-- state that then plays sg.mem.skillstate) follow the weapon's own skill
		-- to its slot
		-- (B's settled skill: a slot press already reads as its own skill)
		if reroute and combo ~= nil and type(combo) == "string" and not combo:find("^skill_")
			and Core.SettledSkillState(inst) == target and Core.BHoldsPseudo(inst) then
			reroute = false
		end
	else
		local name = Core.GetBSkillName(inst)
		target = name ~= nil and ("skill_" .. name) or nil
		-- B set to a skill that can't fire now (empty, or another weapon's)
		if Core.GetSlotValue(inst, "B") ~= Core.WEAPON
			and (target == nil or not Core.HasPower(inst, name) or not sg:HasState(target)) then
			pc:FlushControlQueueAt(data)
			return "no"
		end
		-- after a slot skill, B fires B's skill, not the slot skill's follow-up
		reroute = combo ~= nil and combo ~= target and IsSlotOnlyState(inst, combo)
	end

	if reroute and sg:HasStateTag("busy") and not (statemem.canskill or statemem.canattackorability) then
		return "no" -- not cancelable yet; the press stays buffered
	end
	local held = Core.HoldsSkillRestart(sg, target, combo)
	if Core.settings.debug_skills then
		inst.skillslots_lastpress = { tick = Tick(),
			state = sg.currentstate ~= nil and sg.currentstate.name or nil, canskill = statemem.canskill,
			canattack = statemem.canattackorability, combo = combo, held = held }
	end
	if held then
		return "no" -- the same skill mid-swing: wait for it to play out (stays buffered)
	end
	return "go", target, reroute, combo
end

local function SkillControl(orig, inst, data)
	local ok, plan, target, reroute, combo = Core.G.Call("skill press", SkillPlan, inst, data)
	if not ok or plan == "orig" then
		return orig(inst, data)
	elseif plan ~= "go" then
		return false
	end
	local sg = inst.sg
	local statemem = sg.statemem
	sg.mem.skillstate = target
	Core.G.Call("skill press: primed arrow", Core.NotePrime, inst, (reroute or combo == nil) and target or combo)
	if reroute then
		statemem.skillcombostate = nil
	end
	local results = table.pack(pcall(orig, inst, data))
	if reroute and inst.sg.statemem == statemem and statemem.skillcombostate == nil then
		statemem.skillcombostate = combo
	end
	Core.G.Call("skill press: settle", Core.Settle, inst)
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

local function HookSkillControl()
	local DoControlFn = FindUpvalue(SGPlayerCommon.Fns.DoAction, "DoControlFn")
	if type(DoControlFn) ~= "table" or type(DoControlFn.skill) ~= "function" then
		return false
	end
	local orig = DoControlFn.skill
	DoControlFn.skill = function(inst, data)
		return SkillControl(orig, inst, data)
	end
	return true
end

function Core.Install()
	local missing = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	if not HookSkillControl() then
		return false, "a game update changed the skill button handler (DoControlFn.skill)"
	end
	local count = WrapSkillDefs()
	HookPowerManager()

	-- loaded now (while the mod's scripts folder is searchable) so the game can
	-- find them later: the saved-slots component and the station menu
	require "components.skillslotsdata"

	local Input = require "skillslots.input"
	Input.AddControls()
	Input.HookPlayerController()

	-- Block on a slot (the Greatsword's): off by itself if the game changed
	local block_ok, block_err = pcall(function()
		require("skillslots.block").Install()
	end)
	Core.block_installed = block_ok
	if not block_ok then
		Core.Log("Greatsword Block slot off: " .. tostring(block_err))
	end

	-- the Cannon's Dodge and Reload: off by themselves if the game changed
	local cannon_ok, cannon_err = pcall(function()
		require("skillslots.cannon").Install()
	end)
	Core.cannon_installed = cannon_ok
	if not cannon_ok then
		Core.Log("Cannon Dodge / Reload slots off: " .. tostring(cannon_err))
	end

	-- the game's mannequin loadouts remember the skill buttons
	if Core.settings.mannequin_loadouts ~= false then
		local man_ok, man_err = pcall(function()
			require("skillslots.mannequin").Install()
		end)
		Core.mannequin_installed = man_ok
		if not man_ok then
			Core.Log("mannequin loadouts off (they won't remember skill buttons): " .. tostring(man_err))
		end
	end

	-- the skill station menu (modmain hooks it onto the station decorations)
	local menu_ok, station = pcall(require, "skillslots.station")
	if menu_ok then
		Core.Station = station
	else
		Core.Log("skill station menu off: " .. tostring(station))
	end

	local hud_ok, hud_err = pcall(function()
		require("skillslots.hud").Install()
	end)
	if not hud_ok then
		Core.Log("HUD icons off: " .. tostring(hud_err))
	end

	-- hide / show the power rows (D-pad down each, keys for all, boss fights)
	if Core.settings.hide_powers ~= false then
		local ph_ok, ph_done, ph_info = pcall(function()
			local IC = require "input.inputconstants"
			return require("skillslots.powershide").Install(require("widgets/ftf/playerpowerswidget"),
				require("components.playercontroller"), type(IC) == "table" and IC.Keys or rawget(_G, "InputConstants") and InputConstants.Keys)
		end)
		if not ph_ok then
			Core.Log("hide / show powers off: " .. tostring(ph_done))
		else
			Core.powershide_info = tostring(ph_info)
			Core.Log("hide / show powers: " .. Core.powershide_info)
		end
	end

	Core.enabled = true
	return true, count
end

return Core
