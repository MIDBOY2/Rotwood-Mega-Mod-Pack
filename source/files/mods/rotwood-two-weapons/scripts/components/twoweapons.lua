-- Two Weapons: the two weapons of one player (the one in hand and the other
-- one) and the swap between them. Equipping a new weapon changes the one in
-- hand. Saved with the character.
--
-- Weapons are stored as { id = item def name, idx = inventory position }. The
-- position tells apart two copies of the same weapon; if it moved (an item was
-- removed), the first weapon with that id is used.

local powerutil = require "util.powerutil"
local Attacks = require "twoweapons.attacks"
local Repeat = require "twoweapons.repeatdamage"

local SLOT = "WEAPON"
local PUFF_FX = "player_powers_dodge_cancel_whenever" -- the dodge-cancel relic's puff

local TwoWeapons -- declared first: the constructor below reads TwoWeapons.settings
TwoWeapons = Class(function(self, inst)
	self.inst = inst
	self.cur = nil
	self.prev = nil
	self.pending = 0
	self.pending_task = nil
	self.settings = TwoWeapons.settings or {}
	-- weapon memory (twoweapons/memory.lua): what each weapon had going
	self.memory = { powers = {}, sg = {} }
	self.remember_until = nil
	-- charged skills on the other weapon (twoweapons/carry.lua): name -> charge
	self.carried = nil
	-- swap attacks (twoweapons/attacks.lua): this player's on / off choice
	-- (nil = the settings file's), and the moment after a plain swap when a
	-- light / heavy press still turns it into a swap attack
	self.swap_attacks = nil
	self.followup_until = nil
	-- the game's mannequin loadouts (twoweapons/mannequin.lua): loadout id
	-- (string) -> the other weapon saved with that loadout
	self.loadouts = {}

	-- chained swap attacks (see "Swap attack chains" below)
	self.chain = 0
	self.chain_last = nil
	self.chain_free = false
	self.chain_hold_task = nil
	self.in_swap_attack = false

	self._onloadoutchanged = function()
		self:Track()
	end
	inst:ListenForEvent("loadout_changed", self._onloadoutchanged)
	self._onnewstate = function()
		if self.in_swap_attack then
			return
		end
		local free = (self.chain > 0 or self.repeat_move ~= nil) and self:IsFree()
		if free and self.chain > 0 then
			self.chain_free = true
		end
		if free and self.repeat_move ~= nil then
			Repeat.End(self)
		end
		if self.settings.swap_damage_log then
			Repeat.OnNewState(self)
		end
	end
	inst:ListenForEvent("newstate", self._onnewstate)
	-- the same swap move again and again: less damage (twoweapons/repeatdamage.lua)
	local main = package.loaded["twoweapons.main"]
	pcall(Repeat.Install, type(main) == "table" and main.G or nil)
	pcall(Repeat.Setup, self)
end)

TwoWeapons.settings = nil -- set by modmain

local function GetHoard(inst)
	return inst.components ~= nil and inst.components.inventoryhoard or nil
end

local function MakeRef(hoard, item)
	if item == nil then
		return nil
	end
	return { id = item.id, idx = hoard:GetItemIndex(item) }
end

-- The owned weapon a stored ref points to, or nil.
function TwoWeapons:Resolve(ref)
	local hoard = GetHoard(self.inst)
	local items = hoard ~= nil and hoard:GetSlotItems(SLOT) or nil
	if ref == nil or ref.id == nil or items == nil then
		return nil
	end
	local item = ref.idx ~= nil and items[ref.idx] or nil
	if item ~= nil and item.id == ref.id then
		return item
	end
	for _, it in ipairs(items) do
		if it.id == ref.id then
			return it
		end
	end
	return nil
end

function TwoWeapons:GetEquipped()
	local hoard = GetHoard(self.inst)
	return hoard ~= nil and hoard:GetEquippedItem(SLOT) or nil
end

-- The weapon the swap button would equip, or nil.
function TwoWeapons:GetOther()
	local equipped = self:GetEquipped()
	local prev, cur = self:Resolve(self.prev), self:Resolve(self.cur)
	if prev ~= nil and prev ~= equipped then
		return prev
	end
	if cur ~= nil and cur ~= equipped then
		return cur
	end
	return nil
end

-- After any loadout change:
--  * equipped the other weapon (a swap): the two trade places
--  * equipped a new weapon while the other slot is empty: the old one fills it
--  * equipped a new weapon with both slots full: it replaces the weapon you
--    were holding; your other weapon stays
function TwoWeapons:Track()
	local hoard = GetHoard(self.inst)
	local equipped = self:GetEquipped()
	if hoard == nil or equipped == nil then
		return
	end
	local cur = self:Resolve(self.cur)
	local prev = self:Resolve(self.prev)
	if equipped ~= cur then
		if equipped == prev or prev == nil then
			prev = cur
		end
	end
	self.cur = MakeRef(hoard, equipped)
	self.prev = (prev ~= nil and prev ~= equipped) and MakeRef(hoard, prev) or nil
end

-- Mannequin loadouts: saving a loadout keeps the other weapon with it;
-- equipping it (after the game equipped its weapon) makes that the other one.
function TwoWeapons:SaveForLoadout(id, other)
	local hoard = GetHoard(self.inst)
	self.loadouts[tostring(id)] = (hoard ~= nil and other ~= nil) and MakeRef(hoard, other) or nil
end

function TwoWeapons:LoadForLoadout(id)
	local ref = self.loadouts[tostring(id)]
	if ref == nil then
		return false -- saved without a second weapon (or before this): keep yours
	end
	local hoard = GetHoard(self.inst)
	local item, equipped = self:Resolve(ref), self:GetEquipped()
	if hoard == nil or item == nil or equipped == nil or item == equipped then
		return false -- gone (salvaged) or it's the one in hand now
	end
	self.cur = MakeRef(hoard, equipped)
	self.prev = MakeRef(hoard, item)
	self:RefreshGems()
	return true
end

-- both weapons' gems (twoweapons/gems.lua): the other weapon changed outside a
-- loadout change, so stats and gem powers are worked out again
function TwoWeapons:RefreshGems()
	local gems = package.loaded["twoweapons.gems"]
	if type(gems) == "table" and gems.enabled and gems.Refresh ~= nil then
		local ok, err = pcall(gems.Refresh, self.inst)
		if not ok then
			print("[Two Weapons] both weapons' gems error: " .. tostring(err))
		end
	end
end

function TwoWeapons:ForgetLoadout(id)
	self.loadouts[tostring(id)] = nil
end

-- Same moments a dodge is allowed.
function TwoWeapons:CanSwapNow()
	local inst = self.inst
	local sg = inst.sg
	if sg == nil or not inst:IsValid() then
		return false
	end
	if inst.IsSpectating ~= nil and inst:IsSpectating() then
		return false
	end
	if sg:HasStateTag("busy") and not (sg.statemem ~= nil and sg.statemem.candodge) then
		return false
	end
	return true
end

-- the swap (timed into the log while swap_timing is on: twoweapons/swaptiming.lua)
function TwoWeapons:Swap()
	if self.settings.swap_timing ~= false then
		local ok, SwapTiming = pcall(require, "twoweapons.swaptiming")
		if ok and SwapTiming.Active() then
			return SwapTiming.Run(self.inst, self._Swap, self)
		end
	end
	return self:_Swap()
end

function TwoWeapons:_Swap()
	local hoard = GetHoard(self.inst)
	local target = self:GetOther()
	if hoard == nil or target == nil then
		return false
	end
	local inst = self.inst
	local old_sg = inst.sg

	if self.settings.puff ~= false then
		powerutil.SpawnFxOnEntity(PUFF_FX, inst, { offz = self.settings.puff_offset or -1 })
	end

	-- powers that leave with the old weapon in the next moments are remembered
	-- (Skill Slots switches its skills a tick after the swap)
	self.remember_until = GetTime() + 2
	-- the HUD's redraws wait a tick and happen once (twoweapons/smoothswap.lua)
	local finish
	if self.settings.smooth_swap ~= false then
		local ok, SmoothSwap = pcall(require, "twoweapons.smoothswap")
		finish = ok and SmoothSwap.Begin(inst) or nil
	end
	-- The game tells the old weapon "your loadout is about to change" (the
	-- Striker puts its balls away then) only on the first change after a
	-- clean loadout: from the second swap on, the Striker's balls were left
	-- behind, untracked, bouncing between targets for ever, and its Recall
	-- timers found no balls. So tell it every swap, as the game would.
	if hoard.IsLoadoutDirty ~= nil and hoard:IsLoadoutDirty() then
		inst:PushEvent("loadout_change_imminent", { loadout_index = nil, is_stats_only = false })
	end
	local equipped, err = pcall(hoard.EquipSingleItem, hoard, SLOT, target)
	if finish ~= nil then
		finish()
	end
	if not equipped then
		error(err, 0)
	end

	-- A different weapon type gets a fresh stategraph (starts idle). Same type
	-- keeps the stategraph, so leave whatever attack was being cancelled.
	if inst.sg == old_sg and inst.sg ~= nil and inst.sg:HasStateTag("busy") then
		inst.sg:GoToState("idle")
	end
	inst:PushEvent("twoweapons_swapped", { item = target })
	return true
end

function TwoWeapons:IsRemembering()
	return self.remember_until ~= nil and GetTime() <= self.remember_until
end

function TwoWeapons:ClearMemory()
	self.memory = { powers = {}, sg = {} }
	self.remember_until = nil
end

function TwoWeapons:TrySwap()
	if not self:CanSwapNow() then
		return false
	end
	return self:Swap()
end

----------------------------------------------------------------------------
-- Swap attacks

TwoWeapons.SWAP_ATTACKS_API = 1 -- Skill Slots looks for this to show its toggle

function TwoWeapons:GetSwapAttacks()
	if self.swap_attacks ~= nil then
		return self.swap_attacks
	end
	return self.settings.swap_attacks ~= false
end

function TwoWeapons:SetSwapAttacks(on)
	self.swap_attacks = on == true
	self.followup_until = nil
	self.inst:PushEvent("twoweapons_swapattacks_changed", { on = self.swap_attacks })
end

local function IsHeld(pc, control)
	return pc ~= nil and pc.IsControlHeld ~= nil and pc:IsControlHeld(control) or false
end

-- B held (not a Skill Slots slot button, which also sends a skill press).
-- With Skill Slots' Block on B (Greatsword), B sends a dodge press marked as
-- the B button instead: that counts as B too.
local function IsBHeld(pc)
	for _, data in ipairs(pc ~= nil and pc.controlqueue or {}) do
		if data.control == "skill" and data.skillslots_slot == nil and not data.released then
			return true
		end
		if data.control == "dodge" and data.skillslots_slot == "B" and not data.released then
			return true
		end
	end
	return false
end

function TwoWeapons:Debug(msg)
	if self.settings.debug then
		print("[Two Weapons] debug: " .. msg)
	end
end

local function StateName(inst)
	local sg = inst.sg
	local name = sg ~= nil and sg.currentstate ~= nil and sg.currentstate.name or "?"
	local sgname = sg ~= nil and sg.sg ~= nil and sg.sg.name or "?"
	return string.format("%s/%s", tostring(sgname), tostring(name))
end
TwoWeapons.StateName = StateName

-- The game uses up a tapped X / Y / A as soon as it starts the attack or
-- dodge, so remember when each was last pressed (Main's control hook).
function TwoWeapons:NotePress(kind)
	self.recent = self.recent or {}
	self.recent[kind] = GetTime()
end

function TwoWeapons:_PressedLately(kind)
	local t = self.recent ~= nil and self.recent[kind] or nil
	return t ~= nil and GetTime() - t <= (self.settings.combo_frames or 10) / 30
end

-- Which set a swap press asks for right now: "heavy" (Y held or just
-- pressed), "aerial" (X held or just pressed), "skill" (B held or just
-- pressed), "mixed" (in a dodge, or A just pressed), or nil (a plain swap).
function TwoWeapons:GetSwapAttackKind()
	if not self:GetSwapAttacks() then
		return nil
	end
	local inst = self.inst
	local pc = inst.components ~= nil and inst.components.playercontroller or nil
	if IsHeld(pc, "heavyattack") or self:_PressedLately("heavy") then
		return "heavy"
	elseif IsHeld(pc, "lightattack") or self:_PressedLately("aerial") then
		return "aerial"
	elseif IsBHeld(pc) or self:_PressedLately("skill") then
		return "skill"
	elseif (inst.sg ~= nil and inst.sg:HasStateTag("dodge")) or self:_PressedLately("mixed") then
		return "mixed"
	end
	return nil
end

-- getting hit / knocked down / dying: never
local NO_CANCEL_TAGS = { "hit", "knockdown", "knockback", "dead", "death" }

-- A swap attack can also cut into a dodge or an attack (or skill) at any
-- point: chaining weapons mid-combo. Returns ok, and why not.
function TwoWeapons:CanSwapAttackNow()
	if self:CanSwapNow() then
		return true
	end
	local sg = self.inst.sg
	if sg == nil then
		return false, "no stategraph"
	end
	if self.inst.IsSpectating ~= nil and self.inst:IsSpectating() then
		return false, "spectating"
	end
	for _, tag in ipairs(NO_CANCEL_TAGS) do
		if sg:HasStateTag(tag) then
			return false, "state tag " .. tag
		end
	end
	if sg:HasStateTag("dodge") or sg:HasStateTag("attack") or sg:HasStateTag("skill") then
		return true
	end
	-- the in-between states of combos (roll into attack, attack recovery)
	local name = sg.currentstate ~= nil and sg.currentstate.name or ""
	name = string.lower(name)
	if name:find("attack", 1, true) or name:find("roll", 1, true) or name:find("dodge", 1, true) or name:find("skill", 1, true) then
		return true
	end
	return false, "busy, not an attack or dodge"
end

function TwoWeapons:_StartAttack(kind, why)
	local inst = self.inst
	local ok, res = pcall(Attacks.Start, inst, kind, self.settings)
	if not ok then
		print("[Two Weapons] swap attack error: " .. tostring(res))
		return nil
	end
	if self.settings.debug then
		self:Debug(string.format("%s: %s swap attack -> %s, now in %s", why, kind,
			res ~= nil and tostring(res.state) or "none for this weapon", StateName(inst)))
		inst:DoTaskInTime(0.1, function()
			self:Debug("0.1s later: " .. StateName(inst))
		end)
	end
	return res
end

----------------------------------------------------------------------------
-- Swap attack chains. Swapping mid-attack into the other weapon's attack
-- stays instant, and so does swapping mid-way through that swap attack (two
-- in a row: hammer heavy -> spear heavy -> hammer heavy). A swap during the
-- second one in a row waits: until that attack has finished, and at least
-- swap_chain_wait seconds (0.5) after it started. A press meanwhile is
-- ignored (swap_chain_hold = true keeps it and swaps then). The swap attack has finished when
-- you're out of attacks, or as soon as the game starts your next move from a
-- press (the next hit of a combo, a dodge, a skill: OnActionStarted). Then the
-- chain starts over: swaps are instant again.

-- out of attacks: not attacking, not in a skill, not busy (a dodge, a swap
-- attack's roll or a hit isn't free yet; the recovery you can walk out of is)
function TwoWeapons:IsFree()
	local sg = self.inst.sg
	if sg == nil then
		return true
	end
	return not (sg:HasStateTag("attack") or sg:HasStateTag("skill") or sg:HasStateTag("busy"))
end

function TwoWeapons:ChainLimit()
	return math.max(0, math.floor(tonumber(self.settings.swap_chain_limit) or 2))
end

function TwoWeapons:ChainWait()
	return math.max(0, tonumber(self.settings.swap_chain_wait) or 0.5)
end

-- out of attacks since the last swap attack (and past the wait): start over
function TwoWeapons:_RefreshChain()
	if self.chain > 0 and self.chain_free and (self.chain_last == nil or GetTime() - self.chain_last >= self:ChainWait()) then
		self.chain = 0
		self.chain_free = false
	end
end

-- a swap now would be one too many in a row
function TwoWeapons:ChainLocked()
	local limit = self:ChainLimit()
	if limit <= 0 then
		return false
	end
	self:_RefreshChain()
	if self.chain < limit then
		return false
	end
	if self.chain_free == false or self.chain_last == nil then
		return true -- the last swap attack is still playing
	end
	return GetTime() - self.chain_last < self:ChainWait()
end

-- The game started a move from a press (PlayerController:FlushControlQueueAt,
-- hooked in main.lua): the swap attack playing is over, you've moved on.
TwoWeapons.CHAIN_ENDS_ON = { lightattack = true, heavyattack = true, skill = true, dodge = true }
function TwoWeapons:OnActionStarted(control)
	if self.in_swap_attack or not TwoWeapons.CHAIN_ENDS_ON[control] then
		return
	end
	if self.chain > 0 then
		self.chain_free = true
	end
	if self.repeat_move ~= nil then
		Repeat.End(self) -- the swap move is over: its hits only
	end
end

-- a swap attack happened; was_free: started from out of attacks (a new chain)
function TwoWeapons:_NoteSwapAttack(was_free)
	self:_RefreshChain()
	if was_free or self.chain == 0 then
		self.chain = 1
	else
		self.chain = self.chain + 1
	end
	self.chain_last = GetTime()
	self.chain_free = false
	self:Debug(string.format("swap attack %d in a row", self.chain))
end

function TwoWeapons:_StopHold()
	if self.chain_hold_task ~= nil then
		self.chain_hold_task:Cancel()
		self.chain_hold_task = nil
	end
end

-- a press during the wait: kept, and the swap happens when the wait is over
-- (dropped if you get hit, knocked down or die meanwhile, or after 3 s)
TwoWeapons.CHAIN_HOLD_SECONDS = 3
function TwoWeapons:_Hold()
	if self.settings.swap_chain_hold ~= true or self.chain_hold_task ~= nil then
		return
	end
	local start = GetTime()
	self:Debug("swap press during the 2nd swap attack in a row: waits for it to finish")
	self.chain_hold_task = self.inst:DoPeriodicTicksTask(1, function()
		local sg = self.inst.sg
		for _, tag in ipairs({ "hit", "knockdown", "knockback", "dead", "death" }) do
			if sg ~= nil and sg:HasStateTag(tag) then
				self:_StopHold()
				return
			end
		end
		if GetTime() - start > TwoWeapons.CHAIN_HOLD_SECONDS then
			self:_StopHold()
			return
		end
		if not self:ChainLocked() then
			self:_StopHold()
			self:RequestSwap()
		end
	end)
end

-- Swap, then attack. Returns true if it swapped.
function TwoWeapons:SwapAttack(kind)
	local was_free = self:IsFree()
	self.in_swap_attack = true
	local ok, swapped = pcall(self.Swap, self)
	if not ok or not swapped then
		self.in_swap_attack = false
		if not ok then
			error(swapped, 0)
		end
		return false
	end
	self.followup_until = nil
	local ok2, res = pcall(self._StartAttack, self, kind, "swap")
	self.in_swap_attack = false
	self:_NoteSwapAttack(was_free)
	if not ok2 then
		error(res, 0)
	end
	if res ~= nil then
		Repeat.OnSwapAttack(self, res)
	else
		Repeat.End(self)
	end
	return true
end

-- A plain swap leaves a short moment where light / heavy still makes it a
-- swap attack (pressing LS a hair before the attack button).
function TwoWeapons:_OpenFollowup(was_free)
	if self:GetSwapAttacks() then
		self.followup_until = GetTime() + (self.settings.followup_frames or 6) / 30
		self.followup_free = was_free ~= false
	end
end

-- Light / heavy press (after the game handled it): inside that moment, the
-- weapon just swapped in does its swap attack instead.
function TwoWeapons:OnAttackPress(kind)
	if self.followup_until == nil or GetTime() > self.followup_until then
		self.followup_until = nil
		return false
	end
	self.followup_until = nil
	if not self:GetSwapAttacks() then
		return false
	end
	if self:ChainLocked() then
		return false
	end
	self.in_swap_attack = true
	local ok, res = pcall(self._StartAttack, self, kind, "press right after a swap")
	self.in_swap_attack = false
	if ok and res ~= nil then
		self:_NoteSwapAttack(self.followup_free ~= false)
		Repeat.OnSwapAttack(self, res)
		return true
	end
	return false
end

function TwoWeapons:_StopPending()
	self.pending = 0
	if self.pending_task ~= nil then
		self.pending_task:Cancel()
		self.pending_task = nil
	end
end

-- One try at the swap button: a swap attack when one is asked for and allowed,
-- else a plain swap where a dodge would be allowed.
function TwoWeapons:_TryRequested()
	if self:ChainLocked() then
		self:_Hold()
		return false
	end
	local kind = self:GetSwapAttackKind()
	local can_attack, why_not
	if kind ~= nil then
		can_attack, why_not = self:CanSwapAttackNow()
	end
	if self.settings.debug and (self.pending_task == nil or can_attack) then
		local sg = self.inst.sg
		self:Debug(string.format("swap press: set=%s (swap attacks %s), in %s, dodge=%s attack=%s busy=%s, can swap=%s, swap attack=%s%s",
			tostring(kind), self:GetSwapAttacks() and "on" or "OFF", StateName(self.inst),
			tostring(sg ~= nil and sg:HasStateTag("dodge")), tostring(sg ~= nil and sg:HasStateTag("attack")),
			tostring(sg ~= nil and sg:HasStateTag("busy")), tostring(self:CanSwapNow()), tostring(can_attack == true),
			why_not ~= nil and (" (" .. why_not .. ")") or ""))
	end
	if kind ~= nil and can_attack then
		return self:SwapAttack(kind)
	end
	local was_free = self:IsFree()
	if self:TrySwap() then
		self:_OpenFollowup(was_free)
		self:Debug("plain swap, now in " .. StateName(self.inst))
		return true
	end
	return false
end

-- Button press: swap now, or keep the press for a few frames until a dodge window.
function TwoWeapons:RequestSwap()
	if self:GetOther() == nil then
		return false
	end
	if self:ChainLocked() then
		self:_Hold()
		return false
	end
	if self:_TryRequested() then
		self:_StopPending()
		return true
	end
	self.pending = (self.settings.buffer_frames or 6) * (ANIM_FRAMES or 2)
	if self.pending > 0 and self.pending_task == nil then
		self.pending_task = self.inst:DoPeriodicTicksTask(1, function()
			self.pending = self.pending - 1
			if self:_TryRequested() or self.pending <= 0 then
				self:_StopPending()
			end
		end)
	end
	return false
end

function TwoWeapons:OnSave()
	-- refresh positions in case items moved
	local hoard = GetHoard(self.inst)
	if hoard ~= nil then
		local cur, prev = self:Resolve(self.cur), self:Resolve(self.prev)
		self.cur = MakeRef(hoard, cur) or self.cur
		self.prev = prev ~= nil and MakeRef(hoard, prev) or nil
	end
	local has_memory = next(self.memory.powers) ~= nil or next(self.memory.sg) ~= nil
	local carried
	if self.carried ~= nil and next(self.carried) ~= nil then
		local ok, res = pcall(function() return require("twoweapons.carry").Save(self) end)
		carried = ok and res or nil
	end
	local loadouts
	if next(self.loadouts) ~= nil then
		loadouts = {}
		for id, ref in pairs(self.loadouts) do
			loadouts[id] = { id = ref.id, idx = ref.idx }
		end
	end
	if self.cur == nil and self.prev == nil and not has_memory and self.swap_attacks == nil and carried == nil and loadouts == nil then
		return nil
	end
	return { cur = self.cur, prev = self.prev, memory = has_memory and self.memory or nil,
		swap_attacks = self.swap_attacks, carried = carried, loadouts = loadouts }
end

function TwoWeapons:OnLoad(data)
	if type(data) ~= "table" then
		return
	end
	self.cur = type(data.cur) == "table" and data.cur or nil
	self.prev = type(data.prev) == "table" and data.prev or nil
	if type(data.swap_attacks) == "boolean" then
		self.swap_attacks = data.swap_attacks
	end
	local mem = data.memory
	if type(mem) == "table" and type(mem.powers) == "table" and type(mem.sg) == "table" then
		self.memory = { powers = mem.powers, sg = mem.sg }
	end
	if type(data.loadouts) == "table" then
		for id, ref in pairs(data.loadouts) do
			if type(ref) == "table" and type(ref.id) == "string" then
				self.loadouts[tostring(id)] = { id = ref.id, idx = type(ref.idx) == "number" and ref.idx or nil }
			end
		end
	end
	local carried = type(data.carried) == "table" and data.carried or nil
	-- match against what is actually equipped once the inventory is loaded
	self.inst:DoTaskInTime(0, function()
		self:Track()
		if self:GetOther() ~= nil then
			self:RefreshGems()
		end
		if carried ~= nil then
			local ok, err = pcall(function() require("twoweapons.carry").Load(self, carried) end)
			if not ok then
				print("[Two Weapons] charged skill error: " .. tostring(err))
			end
		end
	end)
end

function TwoWeapons:OnRemoveFromEntity()
	self:_StopHold()
	pcall(Repeat.Teardown, self)
	if self._onnewstate ~= nil then
		self.inst:RemoveEventCallback("newstate", self._onnewstate)
	end
	self:_StopPending()
	if self.carried ~= nil then
		pcall(function() require("twoweapons.carry").DropAll(self, "removed") end)
	end
	self.inst:RemoveEventCallback("loadout_changed", self._onloadoutchanged)
end

function TwoWeapons:GetDebugString()
	local function str(ref)
		return ref ~= nil and string.format("%s#%s", tostring(ref.id), tostring(ref.idx)) or "-"
	end
	return string.format("cur=%s prev=%s", str(self.cur), str(self.prev))
end

return TwoWeapons
