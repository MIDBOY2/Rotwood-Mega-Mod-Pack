-- Skill Slots: the slot buttons (LT / RT / RS-click, keyboard keys).
-- A slot press becomes the game's own "skill" press, tagged with the slot.
-- Weapon choices become dodge presses instead: Block (the Greatsword's) a
-- block press (block.lua, also on B), the Cannon's Dodge a roll press and its
-- Reload a plant press (cannon.lua).

local Core = require "skillslots.core"
local PlayerController = require "components.playercontroller"

local Input = {}

function Input.AddControls()
	local digital = Controls.Digital
	for _, slot in ipairs(Core.SLOT_ORDER) do
		local name = Core.CONTROL_PREFIX .. slot
		local control = rawget(digital, name)
		if control == nil then
			-- Controls.Digital is strict, so add with rawset. key/shortkey are what
			-- the game adds to its own controls (used for button glyphs).
			control = { key = "Controls.Digital." .. name, shortkey = name }
			rawset(digital, name, control)
		end
		Core.controls[slot] = control
	end

	-- input state entries for the new controls (or presses are dropped)
	TheInput:ResetControlState()

	local keyboard = Core.settings.keyboard or {}
	for _, slot in ipairs(Core.SLOT_ORDER) do
		local control = Core.controls[slot]
		if TheInput.gamepad_lookup == nil or TheInput.gamepad_lookup[control] == nil then
			TheInput:_AddGamepadButtonBind({ button = slot, control = control })
		end
		local key = keyboard[slot]
		if type(key) == "string" and key ~= ""
			and (TheInput.key_lookup == nil or TheInput.key_lookup[control] == nil) then
			TheInput:AddKeyBind({ key = key, control = control, ANYMOD = true })
		end
	end
end

local function GetSkillEntry(pc)
	for _, data in ipairs(pc.controlqueue) do
		if data.control == "skill" then
			return data
		end
	end
	return nil
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

local function OnSlotButton(pc, slot, down)
	local entry = GetSkillEntry(pc)
	local Block = Core.block_installed and require("skillslots.block") or nil
	local Cannon = Core.cannon_installed and require("skillslots.cannon") or nil
	if not down then
		if entry ~= nil and entry.skillslots_slot == slot and not entry.released then
			pc:OnControlUpEvent("skill")
		end
		if Block ~= nil then
			Block.OnButton(pc, slot, false)
		end
		if Cannon ~= nil then
			Cannon.OnButton(pc, slot, false)
		end
		return
	end
	if not CanPress(pc) then
		return
	end
	local inst = pc.inst
	local name = Core.GetSlotSkill(inst, slot)
	if name == nil then
		return
	end
	if name == Core.BLOCK then
		if Block ~= nil then
			Block.OnButton(pc, slot, true)
		end
		return
	end
	if name == Core.CANNON_DODGE or name == Core.CANNON_RELOAD then
		if Cannon ~= nil then
			Cannon.OnButton(pc, slot, true, name)
		end
		return
	end
	if Core.IsPseudo(name) then
		return
	end
	if not Core.HasPower(inst, name) then
		Core.Sync(inst)
		if not Core.HasPower(inst, name) then
			return
		end
	end
	local data = { skillslots_slot = slot }
	if pc:ShouldAimAtMouse() then
		data.dir = pc:GetMouseActionDirection()
	else
		data.dir = pc:GetAnalogDir()
	end
	pc:OnControlDownEvent("skill", data)
end

-- B with the Cannon's Reload or Dodge on it (from PlayerController:OnSkillButton):
-- B sends the plant / roll press instead of a skill press. Returns true when handled.
local function CannonOnB(pc, down)
	local Cannon = require "skillslots.cannon"
	local inst = pc.inst
	if not down then
		local entry = Cannon.DodgeEntry(pc)
		if entry ~= nil and entry.skillslots_slot == "B" and (entry.skillslots_plant or entry.skillslots_roll) then
			if not entry.released then
				pc:OnControlUpEvent("dodge")
			end
			return true
		end
		return false
	end
	local name = Core.GetSlotValue(inst, "B")
	if (name ~= Core.CANNON_RELOAD and name ~= Core.CANNON_DODGE) or not Cannon.Active(inst) then
		return false
	end
	if inst.emote_ring ~= nil and inst.emote_ring.IsRingShowing ~= nil and inst.emote_ring:IsRingShowing() then
		return false -- the emote ring is open: B is its shortcut, the game's way
	end
	if CanPress(pc) then
		Cannon.OnButton(pc, "B", true, name)
	end
	return true -- B fires no skill while it holds Reload / Dodge
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Core.Log("button error: " .. tostring(err))
	end
end

function Input.HookPlayerController()
	local orig_OnControl = PlayerController.OnControl
	PlayerController.OnControl = function(self, controls, down, ...)
		local results = table.pack(orig_OnControl(self, controls, down, ...))
		if Core.IsActive(self.inst) then
			for _, slot in ipairs(Core.SLOT_ORDER) do
				local control = Core.controls[slot]
				if control ~= nil and controls:Has(control) then
					local ok, err = pcall(OnSlotButton, self, slot, down)
					if not ok then
						Report(err)
					end
				end
			end
		end
		return table.unpack(results, 1, results.n)
	end

	-- A new skill press replaces the queued one. If the old one is still held
	-- (another skill button), release it first, like letting go of it.
	-- A slot press reaches the stategraph's own press handlers as the skill on
	-- that slot: the game reads the pressed skill from sg.mem.skillstate (B's
	-- skill) right there. The Cannon's roll / airborne / quick-rise states fire
	-- Big Blast's follow-ups (Air Blast, the timed big shot, quick rise) when
	-- the press is Big Blast: from a slot that was B's skill instead (Big Blast
	-- on LT never followed up; another skill on LT with Big Blast on B did).
	local orig_down = PlayerController.OnControlDownEvent
	PlayerController.OnControlDownEvent = function(self, control, data, ...)
		if control == "skill" and Core.IsActive(self.inst) then
			local entry = GetSkillEntry(self)
			if entry ~= nil and not entry.released then
				self:OnControlUpEvent("skill")
			end
			local inst = self.inst
			local slot = type(data) == "table" and data.skillslots_slot or nil
			local name = slot ~= nil and Core.GetSlotSkill(inst, slot) or nil
			local mem = inst.sg ~= nil and inst.sg.mem or nil
			if name ~= nil and mem ~= nil and not Core.IsPseudo(name) then
				mem.skillstate = "skill_" .. name
				local results = table.pack(pcall(orig_down, self, control, data, ...))
				Core.Settle(inst) -- B's skill again
				if not results[1] then
					error(results[2], 0)
				end
				return table.unpack(results, 2, results.n)
			end
		end
		return orig_down(self, control, data, ...)
	end

	-- Letting go of B only releases B's own press, not a held slot button.
	-- Block on B: B blocks instead (block.lua). The Cannon's Reload / Dodge on
	-- B: B plants / rolls instead.
	local orig_skill = PlayerController.OnSkillButton
	PlayerController.OnSkillButton = function(self, down, ...)
		if Core.IsActive(self.inst) and Core.block_installed then
			local ok, handled = pcall(require("skillslots.block").OnBButton, self, down)
			if not ok then
				Report(handled)
			elseif handled then
				return
			end
		end
		if Core.IsActive(self.inst) and Core.cannon_installed then
			local ok, handled = pcall(CannonOnB, self, down)
			if not ok then
				Report(handled)
			elseif handled then
				return
			end
		end
		if not down and Core.IsActive(self.inst) then
			local entry = GetSkillEntry(self)
			if entry ~= nil and entry.skillslots_slot ~= nil then
				return
			end
		end
		return orig_skill(self, down, ...)
	end
end

return Input
