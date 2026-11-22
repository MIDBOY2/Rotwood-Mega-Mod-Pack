-- Skill Slots: Block (the Greatsword's) on a slot button.
-- The game's Greatsword blocks when the dodge button is pressed or held with
-- no direction (sg_player_cleaver_common.lua: ChooseDodgeAction picks block or
-- roll, TryPanicBlock blocks out of an attack while dodge is held, and the
-- block states last while "dodge" is held). With Block on a slot:
--   * the slot button sends the game's own "dodge" press with no direction,
--     marked as the block (skillslots_block), and lets go of it on release;
--   * the dodge button always rolls: a press with no direction gets your
--     facing direction, so it rolls forward like every other weapon;
--   * the Greatsword's checks for a held block only see the slot button, so
--     holding dodge never blocks; panic block from the slot button works with
--     the stick held too (the game wants a neutral stick there because a
--     direction meant a roll).
-- Block can go on LT / RT / RS or on B. On B, B only blocks (no skill press);
-- the Greatsword's skill goes on LT / RT / RS (core.lua keeps its
-- attack-into-skill combos working there).
-- Only while a Greatsword is in hand and Block is on one of its buttons;
-- otherwise everything is the game's own way.

local Core = require "skillslots.core"
local PlayerController = require "components.playercontroller"

local Block = {}

local function DodgeEntry(pc)
	for _, data in ipairs(pc.controlqueue or {}) do
		if data.control == "dodge" then
			return data
		end
	end
	return nil
end
Block.DodgeEntry = DodgeEntry

local function IsBlockPress(data)
	return data ~= nil and data.skillslots_block == true
end
Block.IsBlockPress = IsBlockPress

function Block.Active(inst)
	return inst ~= nil and Core.IsActive(inst) and Core.GetCurrentWeapon(inst) == Core.BLOCK_WEAPON
		and Core.HasBlockSlot(inst)
end

-- The slot button (input.lua: after the game's own checks for a button press).
function Block.OnButton(pc, slot, down)
	if not down then
		local entry = DodgeEntry(pc)
		if IsBlockPress(entry) and entry.skillslots_slot == slot and not entry.released then
			pc:OnControlUpEvent("dodge")
		end
		return
	end
	if not Block.Active(pc.inst) then
		return
	end
	pc:OnControlDownEvent("dodge", { skillslots_block = true, skillslots_slot = slot })
end

-- B (the game's skill button), from PlayerController:OnSkillButton. With
-- Block on B it blocks instead of firing a skill. Returns true when handled.
function Block.OnBButton(pc, down)
	local inst = pc.inst
	if not down then
		local entry = DodgeEntry(pc)
		if IsBlockPress(entry) and entry.skillslots_slot == "B" then
			if not entry.released then
				pc:OnControlUpEvent("dodge")
			end
			return true
		end
		return false
	end
	if not Block.Active(inst) or Core.GetSlotValue(inst, "B") ~= Core.BLOCK then
		return false
	end
	if inst.emote_ring ~= nil and inst.emote_ring.IsRingShowing ~= nil and inst.emote_ring:IsRingShowing() then
		return false -- the emote ring is open: B is its shortcut, the game's way
	end
	Block.OnButton(pc, "B", true)
	return true
end

function Block.Install()
	local SGPlayerCommon = require "stategraphs.sg_player_common"
	local SGPlayerCleaver = require "stategraphs.sg_player_cleaver_common"
	local Fns = SGPlayerCleaver ~= nil and SGPlayerCleaver.Fns or nil
	assert(type(Fns) == "table", "SGPlayerCleaver.Fns")
	for _, name in ipairs({ "ChooseDodgeAction", "TryPanicBlock", "TryDodge", "TryOneSidedDodge",
		"IsKaraCancelActionOpen", "CanExecuteKaraCancelAttack" }) do
		assert(type(Fns[name]) == "function", "SGPlayerCleaver.Fns." .. name)
	end
	for _, name in ipairs({ "OnDodgeButton", "OnControlDownEvent", "OnControlUpEvent", "IsControlHeld",
		"GetControlHeldTicks", "GetQueuedControl" }) do
		assert(type(PlayerController[name]) == "function", "PlayerController:" .. name)
	end
	local C = TUNING ~= nil and TUNING.GEAR ~= nil and TUNING.GEAR.WEAPONS ~= nil and TUNING.GEAR.WEAPONS.CLEAVER or nil
	assert(C ~= nil and type(C.PANIC_BLOCK_HELD_TICKS) == "number", "TUNING.GEAR.WEAPONS.CLEAVER.PANIC_BLOCK_HELD_TICKS")

	-- presses ----------------------------------------------------------------
	-- (bulletproofing: Block's part of each hook runs in Core.G.Call; if it
	-- errors, it's logged and the game's own code runs as if Block were off)
	local G = Core.G

	-- A new dodge press replaces the queued one: let go of a held one first
	-- (like releasing it). The dodge button's own press gets a direction.
	local function OnDodgePress(self, data)
		if not Block.Active(self.inst) then
			return
		end
		local entry = DodgeEntry(self)
		if entry ~= nil and not entry.released then
			self:OnControlUpEvent("dodge")
		end
		if not IsBlockPress(data) and data.dir == nil and self.inst.Transform ~= nil then
			data.dir = self.inst.Transform:GetFacingRotation()
		end
	end
	local orig_down = PlayerController.OnControlDownEvent
	PlayerController.OnControlDownEvent = function(self, control, data, ...)
		if control == "dodge" and type(data) == "table" then
			G.Call("Block: dodge press", OnDodgePress, self, data)
		end
		return orig_down(self, control, data, ...)
	end

	-- Letting go of the dodge button doesn't end a block held on the slot button.
	local function KeepsBlock(self)
		return Block.Active(self.inst) and IsBlockPress(DodgeEntry(self))
	end
	local orig_dodge = PlayerController.OnDodgeButton
	PlayerController.OnDodgeButton = function(self, down, ...)
		if not down then
			local ok, keep = G.Call("Block: dodge release", KeepsBlock, self)
			if ok and keep then
				return
			end
		end
		return orig_dodge(self, down, ...)
	end

	-- Only the Greatsword asks whether dodge is held (its block button): only
	-- the slot button's press counts. (nil: not Block's business)
	local function BlockHeld(self)
		if not Block.Active(self.inst) then
			return nil
		end
		local entry = DodgeEntry(self)
		return IsBlockPress(entry) and not entry.released
	end
	local orig_held = PlayerController.IsControlHeld
	PlayerController.IsControlHeld = function(self, control, ...)
		if control == "dodge" then
			local ok, held = G.Call("Block: held", BlockHeld, self)
			if ok and held ~= nil then
				return held
			end
		end
		return orig_held(self, control, ...)
	end
	local function BlockTicks(self)
		if not Block.Active(self.inst) then
			return nil
		end
		local entry = DodgeEntry(self)
		if IsBlockPress(entry) and not entry.released then
			return entry.ticks or 0
		end
		return 0
	end
	local orig_ticks = PlayerController.GetControlHeldTicks
	PlayerController.GetControlHeldTicks = function(self, control, ...)
		if control == "dodge" then
			local ok, ticks = G.Call("Block: held ticks", BlockTicks, self)
			if ok and ticks ~= nil then
				return ticks
			end
		end
		return orig_ticks(self, control, ...)
	end

	-- the Greatsword -----------------------------------------------------------

	-- block or roll: the slot button blocks, also out of an attack the moment
	-- it's pressed (the game wants dodge held a while there, else it rolls)
	local function BlocksNow(inst, data)
		if IsBlockPress(data) and not data.dodgespecial and Block.Active(inst) then
			if SGPlayerCommon.Fns.IsWeaponSheathed ~= nil and SGPlayerCommon.Fns.IsWeaponSheathed(inst) then
				SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
			end
			return true
		end
		return false
	end
	local orig_choose = Fns.ChooseDodgeAction
	Fns.ChooseDodgeAction = function(inst, data, ...)
		local ok, block = G.Call("Block: block or roll", BlocksNow, inst, data)
		if ok and block then
			inst.sg:GoToState("block_pre")
			return true
		end
		return orig_choose(inst, data, ...)
	end

	-- panic block: the slot button held (any stick direction). Decided in
	-- the guard, done outside it. (nil: not Block's business)
	local function PanicBlock(inst, held_ticks_override)
		if not Block.Active(inst) then
			return nil
		end
		local held_ticks = held_ticks_override or C.PANIC_BLOCK_HELD_TICKS
		if Fns.IsKaraCancelActionOpen(inst, C.DASH_BLOCK_KARA_CANCEL_EXTRA_TICKS) then
			held_ticks = 1
		end
		local pc = inst.components.playercontroller
		if pc:IsControlHeld("dodge") and pc:GetControlHeldTicks("dodge") >= held_ticks then
			if Fns.CanExecuteKaraCancelAttack(inst, C.DASH_BLOCK_KARA_CANCEL_EXTRA_TICKS) then
				return "dash_block"
			end
			return "block"
		end
		return "no"
	end
	local orig_panic = Fns.TryPanicBlock
	Fns.TryPanicBlock = function(inst, held_ticks_override, ...)
		local ok, what = G.Call("Block: panic block", PanicBlock, inst, held_ticks_override)
		if not ok or what == nil then
			return orig_panic(inst, held_ticks_override, ...)
		end
		if what == "dash_block" then
			inst.sg:GoToState("block_pre", { dash_block_velocity = Vector3(inst.Physics:GetVel()) })
			return true
		elseif what == "block" then
			inst.sg:GoToState("block_pre")
			return true
		end
		return false
	end

	-- the slot button's press never rolls
	local function SlotPress(inst)
		return Block.Active(inst) and IsBlockPress(inst.components.playercontroller:GetQueuedControl("dodge"))
	end
	for _, name in ipairs({ "TryDodge", "TryOneSidedDodge" }) do
		local orig = Fns[name]
		local where = "Block: " .. name
		Fns[name] = function(inst, ...)
			local ok, slot = G.Call(where, SlotPress, inst)
			if ok and slot then
				return false
			end
			return orig(inst, ...)
		end
	end
end

return Block
