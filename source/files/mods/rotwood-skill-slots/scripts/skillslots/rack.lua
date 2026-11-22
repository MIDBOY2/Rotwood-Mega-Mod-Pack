-- Skill Slots: the blacksmith's weapon racks (by Hamish's forge) open the skill slot
-- menu too. Hold interact (RB) on a rack: "Customize Skills". A tap does what it
-- always did.
--
-- The racks are the game's corestone stores (components/metaprogressstore.lua):
-- while a rack still takes corestones, a tap (and holding to keep depositing) is
-- the game's deposit, left exactly as it is. Once the rack's weapon is unlocked, a
-- tap opens your weapons (the game's own callback) and holding was unused: that's
-- where the hold goes, the game's own tap-or-hold interaction (the
-- generic_interact states in stategraphs/sg_player_common.lua, the hold ring like
-- the mannequin's), for the player at the rack only.

local Rack = {}

Rack.LABEL = "Customize Skills"
Rack.STATE = "generic_interact_start" -- the game's tap-or-hold interaction
Rack.KEY = "MetaProgressStore_2_hold" -- sorts under the rack's own status line
Rack.ICON = { "images/ui_ftf_hud/equipweapon_icon.tex", "images/ui_ftf_hud/equipweapon_icon_radial.tex" }

Rack.prefabs = {}

-- The rack is done taking corestones for this player: nothing to claim, nothing
-- left to buy (its tap opens the weapons now).
function Rack.Unlocked(store, player)
	if store == nil or player == nil or store.GetProgressInstance == nil then
		return false
	end
	local ok, _, progress = pcall(store.GetProgressInstance, store, player)
	if not ok or progress == nil or progress:IsPendingLevel() then
		return false
	end
	local ok2, next_reward = pcall(store.GetNextReward, store, player)
	return ok2 and next_reward == nil
end

function Rack.Label()
	local S = rawget(_G, "STRINGS")
	local fmt = S and S.UI and S.UI.ACTIONS and S.UI.ACTIONS.INTERACT_FMT
	local icon = S and S.NAMES and S.NAMES.interact_hold
	if type(fmt) == "string" and fmt.subfmt ~= nil and icon ~= nil then
		return fmt:subfmt({ button_icon = icon, label = Rack.LABEL })
	end
	return Rack.LABEL
end

function Rack.IsRack(store)
	return store ~= nil and store.inst ~= nil and Rack.prefabs[store.inst.prefab] == true
end

-- After the game made the rack's interactable (MetaProgressStore:Activate).
function Rack.Setup(store, open_fn, can_open_fn)
	local interactable = store.inst.components.interactable
	if interactable == nil or interactable.skillslots_rack then
		return false
	end
	interactable.skillslots_rack = true

	interactable:SetLongInteractConditionFn(function(_, player)
		return Rack.Unlocked(store, player) and can_open_fn(player)
	end)

	-- the player at the rack (StartInteract locked it to them just before the game
	-- asks for the state): the tap-or-hold interaction once their rack is unlocked
	local base_state = interactable.GetInteractStateName
	interactable.GetInteractStateName = function(self, ...)
		if self.lock ~= nil and Rack.Unlocked(store, self.lock) and can_open_fn(self.lock) then
			return Rack.STATE
		end
		return base_state(self, ...)
	end

	local base_fn = interactable.oninteractfn
	interactable:SetOnInteractFn(function(inst, player, long_interact, ...)
		if long_interact then
			open_fn(player)
			return
		end
		if base_fn ~= nil then
			return base_fn(inst, player, long_interact, ...)
		end
	end)
	return true
end

-- After the game set the rack's status line (OnGainInteractFocus).
function Rack.ShowHold(store, player, can_open_fn)
	local interactor = player ~= nil and player.components ~= nil and player.components.interactor or nil
	if interactor == nil then
		return
	end
	if Rack.Unlocked(store, player) and can_open_fn(player) then
		interactor:SetStatusText(Rack.KEY, Rack.Label())
		if interactor.SetLongInteractTextures ~= nil then
			interactor:SetLongInteractTextures(Rack.ICON[1], Rack.ICON[2])
		end
	else
		interactor:SetStatusText(Rack.KEY, nil)
	end
end

function Rack.HideHold(player)
	local interactor = player ~= nil and player.components ~= nil and player.components.interactor or nil
	if interactor ~= nil then
		interactor:SetStatusText(Rack.KEY, nil)
	end
end

-- Hooks the game's store class. Returns ok, why.
function Rack.Install(MetaProgressStore, prefabs, open_fn, can_open_fn)
	if type(MetaProgressStore) ~= "table" then
		return false, "the game's corestone store changed"
	end
	for _, fn in ipairs({ "Activate", "OnGainInteractFocus", "OnLoseInteractFocus", "GetProgressInstance", "GetNextReward" }) do
		if type(MetaProgressStore[fn]) ~= "function" then
			return false, "a game update changed MetaProgressStore:" .. fn
		end
	end
	for _, p in ipairs(prefabs) do
		Rack.prefabs[p] = true
	end
	local errors = 0
	local function report(what, err)
		if errors < 3 then
			errors = errors + 1
			print("[Skill Slots] rack " .. what .. " skipped: " .. tostring(err))
		end
	end

	local orig_Activate = MetaProgressStore.Activate
	MetaProgressStore.Activate = function(self, ...)
		local r = table.pack(orig_Activate(self, ...))
		if Rack.IsRack(self) then
			local ok, err = pcall(Rack.Setup, self, open_fn, can_open_fn)
			if not ok then
				report("setup", err)
			end
		end
		return table.unpack(r, 1, r.n)
	end

	local orig_Gain = MetaProgressStore.OnGainInteractFocus
	MetaProgressStore.OnGainInteractFocus = function(self, player, ...)
		local r = table.pack(orig_Gain(self, player, ...))
		if Rack.IsRack(self) then
			local ok, err = pcall(Rack.ShowHold, self, player, can_open_fn)
			if not ok then
				report("prompt", err)
			end
		end
		return table.unpack(r, 1, r.n)
	end

	local orig_Lose = MetaProgressStore.OnLoseInteractFocus
	MetaProgressStore.OnLoseInteractFocus = function(self, player, ...)
		if Rack.IsRack(self) then
			pcall(Rack.HideHold, player)
		end
		return orig_Lose(self, player, ...)
	end
	return true
end

return Rack
