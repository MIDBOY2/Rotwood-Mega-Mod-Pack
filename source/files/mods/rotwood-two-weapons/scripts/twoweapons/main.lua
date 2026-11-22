-- Two Weapons: load-time checks, the swap button, and the per-player component.

local PlayerController = require "components.playercontroller"
local InventoryHoard = require "components.inventoryhoard"
local powerutil = require "util.powerutil"
local TwoWeaponsCmp = require "components.twoweapons" -- loaded now so AddComponent finds it later

local Main = {}

Main.TAG = "[Two Weapons]"
Main.CONTROL = "TWOWEAPONS_SWAP"
Main.enabled = false
Main.control = nil

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

-- bulletproofing (twoweapons/guard.lua): this mod's part of the game's code
-- runs through Main.G; an error is logged and the game carries on
Main.G = require("twoweapons.guard").Shared(Main.TAG)

-- Game names this mod relies on. If an update renames one, the mod stays off
-- and says which one in client_log.txt.
local REQUIRED = {
	{ "PlayerController", PlayerController, {
		"OnControl", "IsEnabled", "IsPlacing", "IsRemovingProp", "IsFarming", "_SkipProcessingActionButtons",
	} },
	{ "InventoryHoard", InventoryHoard, { "EquipSingleItem", "GetEquippedItem", "GetSlotItems", "GetItemIndex" } },
	{ "powerutil", powerutil, { "SpawnFxOnEntity" } },
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
	return nil
end

local DEFAULTS = { enabled = true, gamepad = "LS", keyboard = "M", puff = true, puff_offset = -1, buffer_frames = 6, remember = true,
	rb_sheathe = true, sheathed_run_bonus = 30, carry_charges = true, swap_attacks = true, b_moves = "custom", spear_b = "vault", greatsword_b = "snapback",
	cannon_a = "roll_blast", hammer_a = "fade_swing", hammer_fade_distance = 2, swap_turn_with_stick = true, bow_a = "leap_shot", greatsword_a = "bash", followup_frames = 10, combo_frames = 10, mannequin_loadouts = true, swap_chain_limit = 2, swap_chain_wait = 0.5, swap_chain_hold = false,
	swap_repeat_full = 2, swap_repeat_factor = 0.59, swap_repeat_window = 2.5, swap_repeat_also = {},
	both_weapons_gems = { sustain = true, support = true, damage = false }, both_weapon_powers = true, both_weapon_powers_same_type = false,
	weapon_power_limit = "double", weapon_power_fill = true, power_spacing = true, split_sound = true, market_weapons = true, gem_screen_swap = true, berserk_carry = true, second_weapon_imbue = true,
	swap_repeat_skip = { "heavy_attack_jump_pre", "heavy_attack_jump", "heavy_attack", "polearm_jump_out", "skill_polearm_shove", "skill_cannon_butt", "heavy_attack_hold", "skill_bow_melee" }, swap_damage_log = false, debug = false, swap_timing = false, smooth_swap = true, guard = true,
	starting_pair = true, starting_pairs = nil, starting_pair_unlocks_racks = true }

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
	TwoWeaponsCmp.settings = s
	Main.G.on = s.guard ~= false
	return s
end

-- The game's debug keys (debugkeys.lua, loaded when cheats are on): one on the
-- swap key goes off on the same press. R = "Repeat Last Console Command" (a
-- repeated c_give puts that weapon back in every local player's hand, so the
-- swap seemed to undo itself), T teleports you to the mouse, Shift+X opens a
-- debug panel (Shift is the keyboard's skill button, held for a B swap attack).
-- Counted: its named hotkeys (GLOBAL_KEY_BINDINGS) without Ctrl / Alt, and
-- the other key handlers (AddGameDebugKey: DoDebugKey's handlers beyond the
-- named ones on that key). Its name, or nil.
function Main.KeyClash(key)
	local ok, IC = pcall(require, "input.inputconstants")
	local code = ok and type(IC) == "table" and type(IC.Keys) == "table" and IC.Keys[key] or nil
	if code == nil then
		return nil
	end
	local named = 0
	local list = rawget(_G, "GLOBAL_KEY_BINDINGS")
	if type(list) == "table" then
		for _, v in pairs(list) do
			local b = type(v) == "table" and v.binding or nil
			if type(b) == "table" and b.key == code then
				named = named + 1
				if not b.CTRL and not b.ALT then
					local name = type(v.name) == "string" and v.name or "a debug hotkey"
					return b.SHIFT and (name .. " (Shift+" .. key .. ")") or name
				end
			end
		end
	end
	local dd = rawget(_G, "DoDebugKey")
	if type(dd) == "function" and debug ~= nil and debug.getupvalue ~= nil then
		for i = 1, 255 do
			local n, v = debug.getupvalue(dd, i)
			if n == nil then
				break
			end
			if n == "handlers" and type(v) == "table" then
				if type(v[code]) == "table" and #v[code] > named then
					return "a debug key on " .. key
				end
				break
			end
		end
	end
	return nil
end

local function AddControl()
	local digital = Controls.Digital
	local control = rawget(digital, Main.CONTROL)
	if control == nil then
		control = { key = "Controls.Digital." .. Main.CONTROL, shortkey = Main.CONTROL }
		rawset(digital, Main.CONTROL, control)
	end
	Main.control = control
	TheInput:ResetControlState()
	local s = Main.settings
	if type(s.gamepad) == "string" and s.gamepad ~= ""
		and (TheInput.gamepad_lookup == nil or TheInput.gamepad_lookup[control] == nil) then
		TheInput:_AddGamepadButtonBind({ button = s.gamepad, control = control })
	end
	if type(s.keyboard) == "string" and s.keyboard ~= ""
		and (TheInput.key_lookup == nil or TheInput.key_lookup[control] == nil) then
		TheInput:AddKeyBind({ key = s.keyboard, control = control, ANYMOD = true })
		local clash = Main.KeyClash(s.keyboard)
		if clash ~= nil then
			Main.Log(("keyboard swap key %s is also the game's debug hotkey \"%s\" (cheats are on): a press does both. Set keyboard in twoweapons_settings.lua to another key (M is free)"):format(s.keyboard, clash))
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
	return true
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Main.Log("swap error: " .. tostring(err))
	end
end

-- Y / X / B / A in this press, as a swap attack set (see attacks.lua).
local function AttackKind(controls)
	local digital = Controls.Digital
	local heavy, light, dodge = rawget(digital, "ATTACK_HEAVY"), rawget(digital, "ATTACK_LIGHT"), rawget(digital, "DODGE")
	local skill = rawget(digital, "SKILL")
	if heavy ~= nil and controls:Has(heavy) then
		return "heavy"
	elseif light ~= nil and controls:Has(light) then
		return "aerial"
	elseif skill ~= nil and controls:Has(skill) then
		return "skill"
	elseif dodge ~= nil and controls:Has(dodge) then
		return "mixed"
	end
	return nil
end

local function HookPlayerController()
	local orig_OnControl = PlayerController.OnControl
	-- (after the game's own handling; in the guard: an error is logged)
	local function AfterPress(self, controls)
		local cmp = self.inst.components.twoweapons
		if cmp == nil or not CanPress(self) then
			return
		end
		local kind = AttackKind(controls)
		if kind ~= nil and cmp.NotePress ~= nil then
			cmp:NotePress(kind)
		end
		if Main.control ~= nil and controls:Has(Main.control) then
			local ok, err = pcall(cmp.RequestSwap, cmp)
			if not ok then
				Report(err)
			end
		end
		if cmp.followup_until ~= nil and kind ~= nil then
			local ok, err = pcall(cmp.OnAttackPress, cmp, kind)
			if not ok then
				Report(err)
			end
		end
	end
	-- the game starting a move from a press (the next hit of a combo, a dodge,
	-- a skill): a swap attack in a row is over then (components/twoweapons.lua)
	local orig_flush = PlayerController.FlushControlQueueAt
	if type(orig_flush) == "function" then
		local function Started(self, data)
			local cmp = self.inst ~= nil and self.inst.components ~= nil and self.inst.components.twoweapons or nil
			if cmp ~= nil and cmp.OnActionStarted ~= nil and type(data) == "table" then
				cmp:OnActionStarted(data.control)
			end
		end
		PlayerController.FlushControlQueueAt = function(self, data, ...)
			Main.G.Call("swap chain: a move started", Started, self, data)
			return orig_flush(self, data, ...)
		end
	end
	PlayerController.OnControl = function(self, controls, down, ...)
		local results = table.pack(orig_OnControl(self, controls, down, ...))
		if down then
			Main.G.Call("swap press", AfterPress, self, controls)
		end
		return table.unpack(results, 1, results.n)
	end
end

-- RB sheathes the weapon mid-run too (with nothing to interact with), using
-- the game's own switch for this (a Greatsword gear piece turns it on; with
-- this option it stays on for every player).
local function HookSheathe()
	local orig = PlayerController.SetCanUseActionToSheatheWeapon
	if type(orig) ~= "function" then
		Main.Log("RB sheathe off: a game update changed PlayerController:SetCanUseActionToSheatheWeapon")
		return false
	end
	local function Mine(self)
		return Main.settings.rb_sheathe and self.inst ~= nil and self.inst.components ~= nil
			and self.inst.components.twoweapons ~= nil
	end
	PlayerController.SetCanUseActionToSheatheWeapon = function(self, enabled, ...)
		local ok, mine = Main.G.Call("RB sheathe", Mine, self)
		if ok and mine then
			enabled = true
		end
		return orig(self, enabled, ...)
	end
	Main.sheathe_hooked = true
	return true
end

-- Running faster with the weapon sheathed, like the Greatsword gear piece
-- that gives RB sheathe (Shellwalker's Eggsabre: +30%). Not in town (the
-- game's own +50% there) and not with that gear piece on (its own bonus).
local SHEATHED_RUN = "twoweapons_sheathed_run"
local function HasSheatheGear(inst)
	local pm = inst.components.powermanager
	if pm == nil or pm.GetPowerByName == nil then
		return false
	end
	local ok, pow = pcall(pm.GetPowerByName, pm, "cleaver_sheathe_weapon")
	return ok and pow ~= nil
end
function Main.UpdateSheathedRun(inst)
	local loco = inst.components ~= nil and inst.components.locomotor or nil
	if loco == nil or loco.AddSpeedMult == nil or loco.RemoveSpeedMult == nil then
		return
	end
	local pct = tonumber(Main.settings.sheathed_run_bonus) or 0
	local world = rawget(_G, "TheWorld")
	local on = pct > 0 and inst.sg ~= nil and inst.sg.mem ~= nil and inst.sg.mem.sheathed == true
		and not (world ~= nil and world.HasTag ~= nil and world:HasTag("town")) and not HasSheatheGear(inst)
	-- both do nothing when nothing changes; a new run clears speed bonuses,
	-- so this sets it again on the next state change
	if on then
		loco:AddSpeedMult(SHEATHED_RUN, pct / 100)
	else
		loco:RemoveSpeedMult(SHEATHED_RUN)
	end
end

function Main.Install()
	local missing = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	AddControl()
	HookPlayerController()
	if Main.settings.rb_sheathe then
		HookSheathe()
	end
	if Main.settings.remember ~= false then
		local Memory = require "twoweapons.memory"
		local ok, why = Memory.Install()
		Main.memory_installed = ok
		if not ok then
			Main.Log("weapon memory off: a game update changed " .. tostring(why))
		end
	end
	-- after the memory: it runs first on the same game functions
	local Carry = require "twoweapons.carry"
	local ok_carry, why_carry = Carry.Install(Main.settings.carry_charges ~= false)
	if not ok_carry then
		Main.Log("skill glow fix / charged skills off: a game update changed " .. tostring(why_carry))
	end
	-- timers the old weapon left running (the Striker's Recall after a swap...)
	local ok_safe, safe = pcall(function() return require("twoweapons.swapsafety").Install() end)
	if not ok_safe or not safe then
		Main.Log("swap safety off (a timer the old weapon left running may stop the game): " .. tostring(safe))
	end
	-- the game's mannequin loadouts remember your other weapon
	if Main.settings.mannequin_loadouts ~= false then
		local ok_man, why_man = pcall(function() require("twoweapons.mannequin").Install() end)
		Main.mannequin_installed = ok_man
		if not ok_man then
			Main.Log("mannequin loadouts off (they won't remember your other weapon): " .. tostring(why_man))
		end
	end
	-- both weapons' gems count (max health and the rest don't change with a swap)
	local ok_gems, gems_info = pcall(function() return table.pack(require("twoweapons.gems").Install(Main.settings)) end)
	if not ok_gems then
		Main.gems_info = "both weapons' gems off: " .. tostring(gems_info)
	elseif gems_info[1] then
		Main.gems_info = "both weapons' gems: " .. tostring(gems_info[2])
	else
		Main.gems_info = gems_info[2] == "off" and nil or ("both weapons' gems off: " .. tostring(gems_info[2]))
	end
	if Main.gems_info ~= nil then
		Main.Log(Main.gems_info)
	end
	-- the weapon power room: a choice for each weapon
	local ok_wp, wp_ok, wp_info = pcall(function() return require("twoweapons.weaponpowers").Install(Main.settings) end)
	if not ok_wp then
		Main.Log("a weapon power for each weapon off: " .. tostring(wp_ok))
	elseif wp_ok then
		Main.Log(wp_info)
	elseif wp_info ~= "off" then
		Main.Log("a weapon power for each weapon off: " .. tostring(wp_info))
	end
	-- Berserk carries over to your other weapon (its own part, 1.0.11)
	if Main.settings.berserk_carry ~= false then
		local ok_bk, bk_ok, bk_info = pcall(function()
			return require("twoweapons.berserk").Install(require("defs.powers"), Main.G,
				require("stategraphs.sg_player_cleaver_common"), require("util.powerutil"))
		end)
		if not ok_bk then
			Main.Log("Berserk on swaps: the game's (" .. tostring(bk_ok) .. ")")
		elseif bk_ok then
			Main.Log(bk_info)
		else
			Main.Log("Berserk on swaps: the game's (" .. tostring(bk_info) .. ")")
		end
	end
	-- the Teffressence Container gem on the second weapon imbues it too (1.0.13)
	local ok_im, im_ok, im_info = pcall(function()
		return require("twoweapons.imbue").Install(Main.settings)
	end)
	if not ok_im then
		Main.Log("Teffressence Container on the second weapon: the game's, the hand weapon only (" .. tostring(im_ok) .. ")")
	elseif im_ok then
		Main.Log(im_info)
	elseif im_info ~= "off" then
		Main.Log("Teffressence Container on the second weapon: the game's, the hand weapon only (" .. tostring(im_info) .. ")")
	end
	-- the swap button in the gem screen (its own part, 1.0.10)
	if Main.settings.gem_screen_swap ~= false then
		local ok_gs, gs_ok, gs_info = pcall(function()
			return require("twoweapons.gemscreen").Install(require("widgets.ftf.equipmentgemdetailspanel"), Main.control, Main.G)
		end)
		if not ok_gs then
			Main.Log("the swap in the gem screen off: " .. tostring(gs_ok))
		elseif gs_ok then
			Main.Log(gs_info)
		else
			Main.Log("the swap in the gem screen off: " .. tostring(gs_info))
		end
	end
	-- the market's stands count every hunter the same (its own part, 1.0.9)
	if Main.settings.market_weapons ~= false then
		local ok_mk, mk_ok, mk_info = pcall(function()
			return require("twoweapons.market").Install(require("components.shopmanager"), Main.G,
				function() return TheNet:GetPlayersOnRoomChange() end)
		end)
		if not ok_mk then
			Main.Log("the market: the game's (" .. tostring(mk_ok) .. ")")
		elseif mk_ok then
			Main.Log(mk_info)
		else
			Main.Log("the market: the game's (" .. tostring(mk_info) .. ")")
		end
	end
	-- power pedestals never on top of each other (its own part)
	if Main.settings.power_spacing ~= false then
		local ok_sp, sp_ok, sp_info = pcall(function()
			return require("twoweapons.spacing").Install(require("components.powerdropmanager"), require("stategraphs.sg_common"), _G)
		end)
		if not ok_sp then
			Main.Log("power pedestal spacing off: " .. tostring(sp_ok))
		elseif sp_ok then
			Main.Log(sp_info)
		else
			Main.Log("power pedestal spacing off: " .. tostring(sp_info))
		end
	end
	Main.enabled = true
	return true
end

function Main.SetupPlayer(inst)
	if Main.enabled and inst.components ~= nil and inst.components.twoweapons == nil then
		inst:AddComponent("twoweapons")
	end
	-- (1.0.13) the second weapon's Teffressence Container
	if Main.enabled then
		local ok_im, err_im = pcall(function()
			local Imbue = require("twoweapons.imbue")
			if Imbue.enabled then
				Imbue.SetupPlayer(inst)
			end
		end)
		if not ok_im then
			Report(err_im)
		end
	end
	local pc = inst.components ~= nil and inst.components.playercontroller or nil
	if Main.sheathe_hooked and pc ~= nil then
		pc:SetCanUseActionToSheatheWeapon(true)
		if (tonumber(Main.settings.sheathed_run_bonus) or 0) > 0 and inst.ListenForEvent ~= nil then
			local function update(inst)
				local ok, err = pcall(Main.UpdateSheathedRun, inst)
				if not ok then
					Report(err)
				end
			end
			-- sheathing, drawing, and any change of state (a swap's new
			-- stategraph starts drawn)
			inst:ListenForEvent("sheathe_weapon", update)
			inst:ListenForEvent("newstate", update)
			inst:ListenForEvent("twoweapons_swapped", update)
		end
	end
end

return Main
