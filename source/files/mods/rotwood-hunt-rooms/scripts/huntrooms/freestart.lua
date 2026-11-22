-- Hunt Rooms: the start's weapon power choice. The run's start room (the
-- first map's entrance; the Blight: its first part) gives its own pick, the
-- game's shared one (a normal power, or the Fabled of main hunts and the
-- Blight). Once everyone has taken theirs, the game's weapon power choice
-- flies out of the same crystal, rolled and spawned the game's way
-- (components/powerdropmanager.lua PreparePowers_WeaponPower and
-- SpawnPowerItems: each player's own, for the weapon in hand), with the
-- game's ignore_power_drop_pickup_limit tag (as the special event rooms'
-- extra powers have) so the room's one pick, already taken, doesn't block it.
-- With Two Weapons, its own hooks on those functions add your other weapon's
-- choice after the first. A start room that already is the weapon power room
-- (the game's roll) stays as it is.
-- Nothing is offered when nobody has a weapon power left to get, when the
-- run's weapon power rooms are already used up, or after an error (the start
-- is then the game's).
local HR = require "huntrooms.main"
local Tracker = require "huntrooms.tracker"

local FreeStart = {}

FreeStart.DELAY = 1.0 -- seconds after the start's pick: its leftovers fade first
FreeStart.TAGS = { "ignore_power_drop_pickup_limit", "cannot_reroll" }

-- The crystal's split sound for the weapon power choice: the crystal already
-- shattered for the start's own pick (its sound_powercrystal: the shatter and
-- its tail), so this choice flew out silent. The same two sounds, once, from a
-- player (the game's PlayCodeSound with the player as instigator: the game's
-- code-sound way, heard by everyone; Two Weapons plays its second choice's the
-- same way). split_sound = false: none. The number played.
FreeStart.SPLIT_SOUNDS = { "powerCrystal_shatter_crystal", "powerCrystal_shatter_tail" }
function FreeStart.SplitSound(players)
	if HR.settings ~= nil and HR.settings.split_sound == false then
		return 0
	end
	local from
	for _, p in ipairs(players or {}) do
		if p ~= nil and p.SoundEmitter ~= nil and (p.IsValid == nil or p:IsValid()) then
			from = p
			break
		end
	end
	if from == nil then
		return 0
	end
	local fmodtable = require "defs.sound.fmodtable"
	local soundutil = require "util.soundutil"
	local n = 0
	for _, name in ipairs(FreeStart.SPLIT_SOUNDS) do
		local ev = type(fmodtable.Event) == "table" and fmodtable.Event[name] or nil
		if ev ~= nil then
			local ok, err = pcall(soundutil.PlayCodeSound, from, ev, { instigator = from, max_count = 1 })
			if ok then
				n = n + 1
			else
				HR.Log("the start's split sound: " .. tostring(err))
			end
		end
	end
	return n
end

-- The run's start room, with a pick that isn't the weapon power one: its reward.
function FreeStart.StartRoom()
	local dungeon = rawget(_G, "TheDungeon")
	local map = dungeon ~= nil and dungeon.GetDungeonMap ~= nil and dungeon:GetDungeonMap() or nil
	if map == nil or not map:IsCurrentRoomDungeonEntrance() or not Tracker.FirstMap() then
		return nil
	end
	local reward = map:GetRewardForCurrentRoom()
	if reward == nil or reward == "none" or reward == "weaponpower" then
		return nil
	end
	return reward
end

local function Players()
	local ok, list = pcall(function() return TheNet:GetPlayersOnRoomChange() end)
	return ok and type(list) == "table" and list or {}
end

-- Before the game spawns a crystal's powers: the start's own (shared) pick.
function FreeStart.OnSpawn(mgr, position)
	if mgr.huntrooms_start ~= nil or not mgr.shared_drop or position == nil then
		return
	end
	if HR.settings.weapon_power_rooms <= Tracker.WeaponPowerRooms() then
		return
	end
	local reward = FreeStart.StartRoom()
	if reward ~= nil then
		mgr.huntrooms_start = { pos = position, state = "waiting", reward = reward }
	end
end

-- Each update, before the game's: once nobody can take more from the start's
-- pick (the game's own test, PowerManager:CanPickUpPowerDrop), the weapon
-- power choice is due.
function FreeStart.Check(mgr)
	local st = mgr.huntrooms_start
	if st == nil or st.state ~= "waiting" or not mgr.shared_drop then
		return
	end
	local players = Players()
	if #players == 0 then
		return
	end
	for _, player in ipairs(players) do
		local pm = player.components ~= nil and player.components.powermanager or nil
		if pm ~= nil and pm:CanPickUpPowerDrop() then
			return
		end
	end
	st.state = "due"
	mgr.inst:DoTaskInTime(FreeStart.DELAY, function()
		HR.Call("the start's weapon power", FreeStart.Spawn, mgr)
	end)
end

function FreeStart.Spawn(mgr)
	local st = mgr.huntrooms_start
	if st == nil or st.state ~= "due" then
		return false
	end
	st.state = "done"
	if FreeStart.StartRoom() == nil then
		return false
	end
	-- the start's pick is over (its leftovers are going): each player's own from here
	mgr.shared_drop = false
	mgr.spawned_poweritems = {}
	mgr.num_powers_to_start = {}
	mgr.choices_allowed = {}
	mgr.powers_data = {}
	mgr.huntrooms_extra_choice = true -- Two Weapons: no normal power pick in its place
	local ok, err = pcall(mgr.PreparePowers_WeaponPower, mgr)
	mgr.huntrooms_extra_choice = nil
	if not ok then
		mgr.shared_drop = false
		mgr.powers_data = {}
		mgr.twoweapons_second = nil
		error(err, 0)
	end
	if mgr.shared_drop then
		-- something put a shared pick in its place: none
		mgr.shared_drop = false
		mgr.powers_data = {}
		mgr.twoweapons_second = nil
		HR.Log("the start: no weapon power to offer")
		return false
	end
	local any = false
	for pid, list in pairs(mgr.powers_data or {}) do
		if type(list) == "table" and #list > 0 then
			any = true
		else
			mgr.powers_data[pid] = {}
			mgr.choices_allowed[pid] = 0 -- nothing to choose: nothing to wait for
		end
	end
	if not any then
		mgr.powers_data = {}
		mgr.twoweapons_second = nil
		HR.Log("the start: nobody has a weapon power left to get")
		return false
	end
	-- a player the game prepared nothing for: an empty choice, already made
	local ok_ids, ids = pcall(function() return TheNet:GetPlayerIDsOnRoomChange() end)
	for _, pid in ipairs(ok_ids and type(ids) == "table" and ids or {}) do
		if mgr.powers_data[pid] == nil then
			mgr.powers_data[pid] = {}
			mgr.choices_allowed[pid] = 0
		end
	end
	mgr:SpawnPowerItems(st.pos)
	local n = 0
	for _, items in pairs(mgr.spawned_poweritems or {}) do
		for _, item in ipairs(items) do
			if item ~= nil and item.AddTag ~= nil then
				for _, tag in ipairs(FreeStart.TAGS) do
					item:AddTag(tag)
				end
				n = n + 1
			end
		end
	end
	local sounds = 0
	if n > 0 then
		local oks, played = pcall(FreeStart.SplitSound, Players())
		if oks then
			sounds = played or 0
		else
			HR.Log("the start's split sound: " .. tostring(played))
		end
	end
	if n > 0 then
		local okr, errr = pcall(Tracker.Record, "start#wp", Tracker.START)
		if not okr then
			HR.Log("the start's weapon power choice not counted: " .. tostring(errr))
		end
	end
	HR.Log(string.format("the start (%s pick taken): a weapon power choice (%d powers)%s", tostring(st.reward), n,
		sounds > 0 and ", with the split sound" or ""))
	return true
end

-- PDM: components/powerdropmanager.lua
function FreeStart.Install(PDM)
	if type(PDM) ~= "table" then
		return false, "a game update changed PowerDropManager"
	end
	for _, fn in ipairs({ "PreparePowers_WeaponPower", "SpawnPowerItems", "OnUpdate" }) do
		if type(PDM[fn]) ~= "function" then
			return false, "a game update changed PowerDropManager:" .. fn
		end
	end
	local orig_spawn = PDM.SpawnPowerItems
	PDM.SpawnPowerItems = function(self, position, ...)
		if HR.On("the start's weapon power") then
			HR.Call("the start's weapon power", FreeStart.OnSpawn, self, position)
		end
		return orig_spawn(self, position, ...)
	end
	local orig_update = PDM.OnUpdate
	PDM.OnUpdate = function(self, ...)
		if self.huntrooms_start ~= nil and HR.On("the start's weapon power") then
			HR.Call("the start's weapon power", FreeStart.Check, self)
		end
		return orig_update(self, ...)
	end
	HR.start_on = true -- the caps count the start's choice before it's taken (doors.lua)
	return true, "every run's start: its own pick, then a weapon power choice"
end

return FreeStart
