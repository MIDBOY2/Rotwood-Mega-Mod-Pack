-- Powers First: while powers are waiting to be picked, everything else you can use is switched off.
--
-- When a room's powers come out (the power crystal bursts and the game's PowerDropManager spreads a
-- circle of "power_pickup_single" for each player, further apart the more players there are), they can
-- land on an NPC, a meal, anything else that has an interaction: the player then gets that instead of
-- the power. While any power is still there to pick, every other interaction can't be focused (the
-- game's Interactable:CanPlayerFocus, the one gate the player's controller uses both to keep its
-- target and to choose a new one), so the power under it is the one you get. The moment the last power
-- is picked (the others are switched off by the game and despawn), everything is back.
--
-- Never switched off: the powers themselves, the power crystal, players (reviving), an interaction
-- already going on, and the prefabs in the allow setting.
-- Cost: nothing while no power is out (one check that the list is empty); while powers are out, a
-- look at the few powers in the room when a player looks for something to use.
local Main = {}

Main.TAG = "[Powers First]"
Main.POWER_PREFAB = "power_pickup_single"
Main.DEFAULTS = {
	enabled = true,
	only_own_powers = false,
	include_crystal = false,
	allow = {},
}
Main.settings = Main.DEFAULTS
Main.allow = {}
Main.powers = setmetatable({}, { __mode = "k" })   -- power pickups alive now
Main.crystals = setmetatable({}, { __mode = "k" }) -- power crystals alive now
Main.REASON = "powers first: a power is waiting to be picked"

local function Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end
Main.Log = Log

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if Main.DEFAULTS[k] ~= nil and type(v) == type(Main.DEFAULTS[k]) then
				s[k] = v
			end
		end
	end
	Main.allow = {}
	for _, name in ipairs(s.allow) do
		if type(name) == "string" and name ~= "" then
			Main.allow[name] = true
		end
	end
	Main.settings = s
	return s
end

-- a power still there to pick: not removed, not switched off by the game, not on its way out
local function Live(inst)
	return inst ~= nil and inst:IsValid() and inst:HasTag("interactable")
		and not (inst.sg ~= nil and inst.sg:HasStateTag("despawning"))
end
Main.Live = Live

local function CanTake(inst, player)
	local sp = inst.components ~= nil and inst.components.singlepickup or nil
	local who = sp ~= nil and sp.GetAssignedPlayer ~= nil and sp:GetAssignedPlayer() or nil
	return who == nil or who == player
end

function Main.Track(list, inst)
	if inst == nil or list[inst] then
		return
	end
	list[inst] = true
	if inst.ListenForEvent ~= nil then
		inst:ListenForEvent("onremove", function() list[inst] = nil end)
	end
end

function Main.AddPower(inst)
	Main.Track(Main.powers, inst)
end

function Main.AddCrystal(inst)
	Main.Track(Main.crystals, inst)
end

-- is power choosing going on (for this player, with only_own_powers)?
function Main.Choosing(player)
	local own = Main.settings.only_own_powers and player ~= nil
	for inst in pairs(Main.powers) do
		if Live(inst) and (not own or CanTake(inst, player)) then
			return true
		end
	end
	if Main.settings.include_crystal then
		for inst in pairs(Main.crystals) do
			if inst:IsValid() then
				return true
			end
		end
	end
	return false
end

function Main.Exempt(inst)
	return Main.powers[inst] ~= nil or Main.crystals[inst] ~= nil
		or (inst.HasTag ~= nil and (inst:HasTag("player") or inst:HasTag("powerdrop")))
		or (inst.prefab ~= nil and (inst.prefab == Main.POWER_PREFAB or Main.allow[inst.prefab] ~= nil))
end

-- interactable: an Interactable component; player: the player looking for something to use
function Main.Blocks(interactable, player)
	local inst = interactable.inst
	if inst == nil or Main.Exempt(inst) then
		return false
	end
	if interactable.IsPlayerInteracting ~= nil and interactable:IsPlayerInteracting(player) then
		return false -- never cut an interaction short
	end
	return Main.Choosing(player)
end

function Main.InstallInteractable(Interactable)
	if type(Interactable) ~= "table" or type(Interactable.CanPlayerFocus) ~= "function" then
		return false, "a game update changed Interactable:CanPlayerFocus"
	end
	if rawget(Interactable, "powersfirst_hook") then
		return true
	end
	local orig = Interactable.CanPlayerFocus
	Interactable.CanPlayerFocus = function(self, player, ...)
		if next(Main.powers) ~= nil or (Main.settings.include_crystal and next(Main.crystals) ~= nil) then
			local ok, blocked = pcall(Main.Blocks, self, player)
			if not ok then
				if not Main.warned then
					Main.warned = true
					Log("a check went wrong (the game's own behaviour for it): " .. tostring(blocked))
				end
			elseif blocked then
				return false, Main.REASON
			end
		end
		return orig(self, player, ...)
	end
	rawset(Interactable, "powersfirst_hook", true)
	return true
end

return Main
