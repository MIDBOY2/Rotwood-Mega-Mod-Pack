-- Hammer Charge: the Sedament hammer's weapon power (chargeable light attacks)
-- on every hammer.
--
-- The game gives a weapon's power when it's equipped (PowerManager:
-- OnLoadoutChanged, from the weapon's usage_data.power_on_equip). This mod adds
-- the same power, with the stacks for the hammer's level, to any other hammer,
-- right after the game sorts out the weapon's own power, and takes it away
-- when the weapon in hand isn't a hammer (or is the Sedament hammer, which has
-- it already).

local Power = require "defs.powers"
local PowerManager = require "components.powermanager"

local Main = {}

Main.TAG = "[Hammer Charge]"
Main.POWER = "equipment_hammer_charged_light_attacks"
Main.SLOT = "WEAPON"
Main.WEAPON_TYPE = "HAMMER"
Main.enabled = false

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

-- bonus: a full charge's extra damage in percent at weapon level 1 / 2 / 3.
-- The Sedament hammer's own is +300 / 325 / 350%, which made a full charged
-- light (a focus hit) stronger than a fully charged heavy; +140 / 150 / 160%
-- puts Light Attack 3's (1.75 focus) at 4.2 / 4.4 / 4.55, just under the
-- charged heavy's 4.58.
local DEFAULTS = { enabled = true, bonus = { 140, 150, 160 } }
Main.DEFAULTS = DEFAULTS

function Main.LoadSettings(user)
	local s = { enabled = DEFAULTS.enabled, bonus = {} }
	if type(user) == "table" and type(user.enabled) == "boolean" then
		s.enabled = user.enabled
	end
	local b = type(user) == "table" and type(user.bonus) == "table" and user.bonus or {}
	for i, d in ipairs(DEFAULTS.bonus) do
		local v = tonumber(b[i])
		s.bonus[i] = v ~= nil and math.max(0, math.min(1000, math.floor(v + 0.5))) or d
	end
	Main.settings = s
	return s
end

----------------------------------------------------------------------------
-- Game names this mod relies on

local function CheckGame()
	if type(PowerManager) ~= "table" then
		return "PowerManager"
	end
	for _, fn in ipairs({ "OnLoadoutChanged", "GetEquipmentPowers", "GetPowerByName", "AddPowerByName",
		"RemovePowerByName", "GetPowerStacks" }) do
		if type(PowerManager[fn]) ~= "function" then
			return "PowerManager:" .. fn
		end
	end
	local found, def = pcall(Power.FindPowerByName, Main.POWER) -- errors for a missing name
	if not found or def == nil then
		return "the power " .. Main.POWER
	end
	if type(def.stacks_per_usage_level) ~= "table" or #def.stacks_per_usage_level == 0 then
		return Main.POWER .. ".stacks_per_usage_level"
	end
	return nil
end

----------------------------------------------------------------------------

local function Def()
	return Power.FindPowerByName(Main.POWER)
end

local function WeaponDef(item)
	local def = item ~= nil and item.GetDef ~= nil and item:GetDef() or nil
	return type(def) == "table" and def or nil
end

-- the weapon's own power is this one (the Sedament hammer), as the game added it
local function WeaponGrants(pm)
	for _, data in ipairs(pm:GetEquipmentPowers(Main.SLOT) or {}) do
		if data.name == Main.POWER then
			return true
		end
	end
	return false
end

-- this mod's copy is on the player
local function HasOurs(pm)
	return pm:GetPowerByName(Main.POWER) ~= nil and not WeaponGrants(pm)
end

-- stacks the weapon in hand should get from this mod, or nil for none
function Main.WantedStacks(inst)
	local hoard = inst.components ~= nil and inst.components.inventoryhoard or nil
	local item = hoard ~= nil and hoard:GetEquippedItem(Main.SLOT) or nil
	local def = WeaponDef(item)
	if def == nil or def.weapon_type ~= Main.WEAPON_TYPE then
		return nil
	end
	local usage = item.GetUsageData ~= nil and item:GetUsageData() or def.usage_data
	if type(usage) == "table" and usage.power_on_equip == Main.POWER then
		return nil -- has it already
	end
	local levels = Main.settings ~= nil and Main.settings.bonus or Def().stacks_per_usage_level
	local level = item.GetUsageLevel ~= nil and item:GetUsageLevel() or 1
	level = math.max(1, math.min(tonumber(level) or 1, #levels))
	-- (the power's stacks are its bonus in percent: one stack = +1%)
	return levels[level]
end

-- The hammer stategraph checks this flag; a fresh stategraph (Two Weapons
-- swap) starts without it until the power's next room.
local function SetFlag(inst)
	if inst.sg ~= nil and inst.sg.mem ~= nil then
		inst.sg.mem.hammer_charged_lights = true
	end
end

local function RemoveOurs(pm)
	if HasOurs(pm) then
		pm:RemovePowerByName(Main.POWER, true)
	end
end

function Main.Refresh(inst)
	local pm = inst.components ~= nil and inst.components.powermanager or nil
	if pm == nil then
		return
	end
	local want = Main.WantedStacks(inst)
	if HasOurs(pm) then
		if want ~= nil and pm:GetPowerStacks(Def()) == want then
			SetFlag(inst)
			return
		end
		pm:RemovePowerByName(Main.POWER, true)
	end
	if want ~= nil and pm:GetPowerByName(Main.POWER) == nil then
		pm:AddPowerByName(Main.POWER, want)
		SetFlag(inst)
	end
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Main.Log("error: " .. tostring(err))
	end
end

local function HookLoadout()
	local orig = PowerManager.OnLoadoutChanged
	PowerManager.OnLoadoutChanged = function(self, ...)
		local inst = self.inst
		local mine = inst ~= nil and inst.hammercharge ~= nil
		if mine then
			-- Take this mod's copy off first when it has to change, so the game
			-- never stacks the Sedament hammer's own power on top of it.
			local ok, err = pcall(function()
				if HasOurs(self) and Main.WantedStacks(inst) ~= self:GetPowerStacks(Def()) then
					RemoveOurs(self)
				end
			end)
			if not ok then
				Report(err)
			end
		end
		local results = table.pack(orig(self, ...))
		if mine then
			local ok, err = pcall(Main.Refresh, inst)
			if not ok then
				Report(err)
			end
		end
		return table.unpack(results, 1, results.n)
	end
end

function Main.Install()
	local missing = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	HookLoadout()
	Main.enabled = true
	return true, "light attacks chargeable on every hammer"
end

function Main.SetupPlayer(inst)
	if inst.hammercharge ~= nil then
		return
	end
	inst.hammercharge = {}
	local function Soon()
		if inst:IsValid() then
			inst:DoTaskInTime(0, function()
				local ok, err = pcall(Main.Refresh, inst)
				if not ok then
					Report(err)
				end
			end)
		end
	end
	-- a new run clears every power; the game re-adds weapon powers on its own
	inst:ListenForEvent("setup_new_run_powers", Soon)
	inst:ListenForEvent("enter_room", Soon)
	-- keep the stategraph flag after a weapon swap (fresh stategraph)
	-- (every state change: an error is logged, never the game's error screen)
	local function KeepFlag()
		local pm = inst.components ~= nil and inst.components.powermanager or nil
		if pm ~= nil and inst.sg ~= nil and inst.sg.mem ~= nil and not inst.sg.mem.hammer_charged_lights
			and pm:GetPowerByName(Main.POWER) ~= nil then
			inst.sg.mem.hammer_charged_lights = true
		end
	end
	inst:ListenForEvent("newstate", function()
		local ok, err = pcall(KeepFlag)
		if not ok then
			Report(err)
		end
	end)
	Soon()
end

return Main
