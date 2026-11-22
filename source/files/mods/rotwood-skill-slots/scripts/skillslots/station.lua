-- Skill Slots: turns chosen town decorations into a skill station. Pressing
-- interact (RB) on one opens the skill slot menu, the same way the game's own
-- stations (Mirage Station, Emote Booth...) open theirs.
-- Also: a menu button that opens it anywhere in town, and unlocking the station
-- decorations in the build menu.

local Core = require "skillslots.core"
local Constructable = require "defs.constructable"
local PlayerController = require "components.playercontroller"
local screenopener = require "prefabs.customscript.screenopener"
require "skillslots.screen" -- loaded now so the game can open it later

local Station = {}

Station.SCREEN = "skillslots.screen"
Station.LABEL = "Customize Skills" -- same wording style as the Emote Booth ("Customize Emotes")
Station.CONTROL = "SKILLSLOTS_MENU"

-- AddPrefabPostInit callback for each station decoration.
function Station.MakeStation(inst)
	if not Core.enabled or inst.components == nil or inst.components.interactable ~= nil then
		return -- already interactive (e.g. a game station), leave it alone
	end
	-- The game's language pass runs after mods load and replaces strings it
	-- doesn't know with "MISSING:...", so set the prompt again now.
	Station.SetLabel(inst.prefab)
	local ok, err = pcall(screenopener.default.CustomInit, inst, {
		screen_require = Station.SCREEN,
	})
	if not ok then
		Core.Log("couldn't make " .. tostring(inst.prefab) .. " a skill station: " .. tostring(err))
	end
end

-- Interact prompt text ("RB Customize Skills") for a station prefab.
function Station.SetLabel(prefab)
	local labels = STRINGS.UI and STRINGS.UI.SCREENOPENER_PROP
	if type(labels) == "table" and prefab ~= nil and labels[prefab] ~= Station.LABEL then
		labels[prefab] = Station.LABEL
	end
end

function Station.SetLabels(prefabs)
	for _, prefab in ipairs(prefabs) do
		Station.SetLabel(prefab)
	end
end

-- Open the menu without a station (menu button, developer console).
function Station.OpenFor(player)
	if player == nil then
		return
	end
	local Screen = require(Station.SCREEN)
	TheFrontEnd:PushScreen(Screen(player))
end

-- Open it from an interaction (the blacksmith's weapon racks), the way the game's
-- screen-opening props do (prefabs/customscript/screenopener.lua).
function Station.OpenFromInteraction(player)
	if player == nil then
		return
	end
	local Screen = require(Station.SCREEN)
	local screen = Screen(player)
	local pc = player.components ~= nil and player.components.playercontroller or nil
	if pc ~= nil and pc.PushScreenFromInteraction ~= nil then
		pc:PushScreenFromInteraction(screen)
	else
		TheFrontEnd:PushScreen(screen)
	end
	if player.sg ~= nil and player.sg.GoToState ~= nil then
		player.sg:GoToState("idle_accept")
	end
end

-- The menu can open for this player (in town).
function Station.CanOpenAt(player)
	return Core.enabled and player ~= nil and TheWorld ~= nil and TheWorld:HasTag("town")
		and not (player.IsSpectating ~= nil and player:IsSpectating())
end

----------------------------------------------------------------------------
-- Build menu: the game only lists decorations whose recipe is unlocked (biome
-- exploration rewards, Kuma's friendship, the winter event). This unlocks the
-- station ones the same way earning them does. Building still costs materials.

-- Returns how many were unlocked, or nil if the player isn't ready yet.
function Station.UnlockRecipes(inst, prefabs)
	local unlocks = inst.components ~= nil and inst.components.unlocktracker or nil
	if unlocks == nil then
		return nil
	end
	if inst.Network ~= nil and inst.Network:GetPlayerID() == nil then
		return nil
	end
	local count = 0
	for _, prefab in ipairs(prefabs) do
		if Constructable.FindItem(prefab) ~= nil and not unlocks:IsRecipeUnlocked(prefab) then
			unlocks:UnlockRecipe(prefab)
			count = count + 1
		end
	end
	return count
end

function Station.SetupPlayer(inst)
	local settings = Core.settings
	if not settings.unlock_stations or (inst.IsLocal ~= nil and not inst:IsLocal()) then
		return
	end
	local function TryUnlock()
		if inst.skillslots_stations_done then
			return
		end
		local ok, count = pcall(Station.UnlockRecipes, inst, settings.stations)
		if not ok then
			inst.skillslots_stations_done = true
			Core.Log("couldn't unlock the station decorations: " .. tostring(count))
		elseif count ~= nil then
			inst.skillslots_stations_done = true
			if count > 0 then
				Core.Log("unlocked " .. count .. " station decoration(s) in the build menu")
			end
		end
	end
	inst:DoTaskInTime(0, TryUnlock)
	inst:ListenForEvent("enter_room", TryUnlock)
end

----------------------------------------------------------------------------
-- Menu button: opens the skill slot menu anywhere in town.

local DPAD_MOVES = { DPAD_UP = "MOVE_UP", DPAD_DOWN = "MOVE_DOWN", DPAD_LEFT = "MOVE_LEFT", DPAD_RIGHT = "MOVE_RIGHT" }

local function InTown()
	return TheWorld ~= nil and TheWorld:HasTag("town")
end

-- Same checks the game makes before gameplay buttons, plus "in town".
local function CanOpen(pc)
	if not Core.enabled or not InTown() or not pc:IsEnabled() then
		return false
	end
	if pc.input ~= nil and pc.input.IsEditingBlockingGameplay ~= nil and pc.input:IsEditingBlockingGameplay() then
		return false
	end
	if pc.input_stealers ~= nil and #pc.input_stealers > 0 then
		return false
	end
	if pc:IsPlacing() or pc:IsRemovingProp() or pc:_SkipProcessingActionButtons() or pc:IsFarming() then
		return false
	end
	if pc.inst.IsSpectating ~= nil and pc.inst:IsSpectating() then
		return false
	end
	return true
end

-- Gameplay buttons the menu button must not share (the game's own, also when
-- rebound in the options, and the other mods'). If the button is also one of
-- these, the menu stays shut and the log says which.
local SHARED_WITH = {
	"OPEN_CRAFTING", "PICKUP_MODE", "SHOW_EMOTE_RING", "SHOW_PLAYER_STATUS", "SHOW_PLAYERS_LIST",
	"ACTION", "SKILL", "DODGE", "ATTACK_LIGHT", "ATTACK_HEAVY", "USE_POTION", "PAUSE", "RADIAL_ACTION",
	"SKILLSLOTS_LT", "SKILLSLOTS_RT", "SKILLSLOTS_RS", "TONICSWAP_PREV", "TONICSWAP_NEXT", "TWOWEAPONS_SWAP",
}
local warned_shared = {}
local function SharedControl(controls)
	local digital = Controls.Digital
	for _, name in ipairs(SHARED_WITH) do
		local control = rawget(digital, name)
		if control ~= nil and controls:Has(control) then
			return name
		end
	end
	return nil
end

-- Opens on release (like the console key), so the menu never gets half a press.
local function OnMenuButton(pc, down, controls)
	local shared = SharedControl(controls)
	if shared ~= nil then
		pc.skillslots_menu_down = nil
		if down and not warned_shared[shared] then
			warned_shared[shared] = true
			Core.Log("menu button is also " .. shared .. " in the game's controls, so it doesn't open the menu. "
				.. "Pick another menu_button in skillslots_settings.lua")
		end
		return
	end
	if down then
		pc.skillslots_menu_down = CanOpen(pc)
	elseif pc.skillslots_menu_down then
		pc.skillslots_menu_down = nil
		if CanOpen(pc) then
			Station.OpenFor(pc.inst)
		end
	end
end

local errors = 0
local function Report(err)
	if errors < 5 then
		errors = errors + 1
		Core.Log("menu button error: " .. tostring(err))
	end
end

function Station.AddMenuButton(button)
	if type(button) ~= "table" then
		return false
	end
	local pad = type(button.gamepad) == "string" and button.gamepad ~= "" and button.gamepad or nil
	local key = type(button.keyboard) == "string" and button.keyboard ~= "" and button.keyboard or nil
	if pad == nil and key == nil then
		return false
	end

	local digital = Controls.Digital
	local control = rawget(digital, Station.CONTROL)
	if control == nil then
		control = { key = "Controls.Digital." .. Station.CONTROL, shortkey = Station.CONTROL }
		rawset(digital, Station.CONTROL, control)
	end
	Station.control = control
	TheInput:ResetControlState()

	if pad ~= nil then
		-- D-pad walking (only used with the stick idle) gives way to the menu
		local move = DPAD_MOVES[pad]
		if move ~= nil and rawget(digital, move) ~= nil then
			TheInput:_RemoveGamepadButtonBind(digital[move])
		end
		if TheInput.gamepad_lookup == nil or TheInput.gamepad_lookup[control] == nil then
			TheInput:_AddGamepadButtonBind({ button = pad, control = control })
		end
	end
	if key ~= nil and (TheInput.key_lookup == nil or TheInput.key_lookup[control] == nil) then
		-- (the key alone: Ctrl+H is Controller Layout's overhead key, and other
		-- mods' Ctrl / Alt keys never open the menu)
		TheInput:AddKeyBind({ key = key, control = control })
	end

	local orig_OnControl = PlayerController.OnControl
	PlayerController.OnControl = function(self, controls, down, ...)
		local results = table.pack(orig_OnControl(self, controls, down, ...))
		if controls:Has(control) then
			local ok, err = pcall(OnMenuButton, self, down, controls)
			if not ok then
				Report(err)
			end
		end
		return table.unpack(results, 1, results.n)
	end
	return true
end

return Station
