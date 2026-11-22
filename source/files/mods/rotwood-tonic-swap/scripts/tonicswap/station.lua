-- Tonic Swap: tonic stations. Pressing interact (RB) on one of these town
-- decorations opens the potions menu, the same way the game's own stations
-- (Emote Booth...) open theirs. Default: the Potion Table (the mod's own,
-- tonicswap/table.lua) and the Ironwork Illuminator (lamp_volcano_1). Also
-- unlocks the station decorations in the build menu.

local Main = require "tonicswap.main"
local Constructable = require "defs.constructable"
local screenopener = require "prefabs.customscript.screenopener"
require "tonicswap.screen" -- loaded now so the game can open it later

local Station = {}

Station.SCREEN = "tonicswap.screen"
Station.LABEL = "Choose Potions"

-- AddPrefabPostInit callback for each station decoration.
-- The mod's own stations (the Potion Table): already a screen opener from the
-- game's prop maker, they only need their prompt text.
Station.own = {}

function Station.MakeStation(inst)
	if not Main.enabled or inst.components == nil then
		return
	end
	if inst.components.interactable ~= nil then
		if Station.own[inst.prefab] then
			Station.SetLabel(inst.prefab)
		end
		return -- already interactive (a game station), leave it alone
	end
	-- the game's language pass replaces strings it doesn't know, so set it again now
	Station.SetLabel(inst.prefab)
	local ok, err = pcall(screenopener.default.CustomInit, inst, { screen_require = Station.SCREEN })
	if not ok then
		Main.Log("couldn't make " .. tostring(inst.prefab) .. " a tonic station: " .. tostring(err))
	end
end

-- Interact prompt text ("RB Choose Potions") for a station prefab.
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

-- Open the menu without a station (developer console).
function Station.OpenFor(player)
	if player ~= nil then
		local Screen = require(Station.SCREEN)
		TheFrontEnd:PushScreen(Screen(player))
	end
end

-- The game lists a decoration in the build menu once its recipe is unlocked
-- (the Ironwork Illuminator: a Grimhollow exploration reward). Unlock the
-- station ones the same way. Building still costs the materials.
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

-- What to unlock in the build menu: the mod's own stations always (nothing
-- in the game unlocks them), the settings' stations with unlock_stations.
function Station.UnlockList(settings)
	local list, seen = {}, {}
	local function add(prefab)
		if not seen[prefab] then
			seen[prefab] = true
			list[#list + 1] = prefab
		end
	end
	for _, prefab in ipairs(settings.unlock_stations and type(settings.stations) == "table" and settings.stations or {}) do
		add(prefab)
	end
	local own = {}
	for prefab in pairs(Station.own) do
		own[#own + 1] = prefab
	end
	table.sort(own)
	for _, prefab in ipairs(own) do
		add(prefab)
	end
	return list
end

function Station.SetupPlayer(inst)
	local settings = Main.settings
	local list = Station.UnlockList(settings)
	if #list == 0 or (inst.IsLocal ~= nil and not inst:IsLocal()) then
		return
	end
	local function TryUnlock()
		if inst.tonicswap_stations_done then
			return
		end
		local ok, count = pcall(Station.UnlockRecipes, inst, list)
		if not ok then
			inst.tonicswap_stations_done = true
			Main.Log("couldn't unlock the station decorations: " .. tostring(count))
		elseif count ~= nil then
			inst.tonicswap_stations_done = true
			if count > 0 then
				Main.Log("unlocked " .. count .. " tonic station decoration(s) in the build menu")
			end
		end
	end
	inst:DoTaskInTime(0, TryUnlock)
	inst:ListenForEvent("enter_room", TryUnlock)
end

return Station
