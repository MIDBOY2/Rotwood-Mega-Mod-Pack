-- Hunt Rooms: Super Frenzy main hunts' corestone, gift and material rooms
-- give super_main_reward times their reward (they come about half as often,
-- doors.lua). Only those rooms of the game's own (not the boss's corestones,
-- not enemy drops, not Teffra):
--  * corestone room: CraftingDropManager:GetSoulDropCount("konjur_soul_lesser")
--    x the factor (rounded at random, the average exact)
--  * material room: KonjurRewardManager:SpawnRoomRewardMaterial once more for
--    each extra time (its materials, seed and ingots)
--  * gift room: the friend gift drop's count per player (prefab
--    soul_drop_friendgift, souldrop child drops)
local HR = require "huntrooms.main"
local Doors = require "huntrooms.doors"

local Rewards = {}

local function Map()
	local dungeon = rawget(_G, "TheDungeon")
	return dungeon ~= nil and dungeon.GetDungeonMap ~= nil and dungeon:GetDungeonMap() or nil
end

-- The factor for the current room if it's a game's room of this reward in a
-- Super Frenzy main hunt, else 1.
function Rewards.Factor(reward)
	local f = HR.settings.super_main_reward
	if f <= 1 then
		return 1
	end
	local map = Map()
	local mgrun = map ~= nil and map.mgrun or nil
	if type(mgrun) ~= "table" or type(mgrun.data) ~= "table" then
		return 1
	end
	local room = mgrun.data.current
	if type(room) ~= "table" or room.reward ~= reward or room.huntrooms_orig ~= nil or room.huntrooms_power ~= nil or room.roomtype ~= "monster" then
		return 1
	end
	if Doors.RunKind(mgrun) ~= "main_super" then
		return 1
	end
	return f
end

function Rewards.Scale(n, f, rand)
	if type(n) ~= "number" or n <= 0 or f == 1 then
		return n
	end
	local x = n * f
	local whole = math.floor(x + 1e-9)
	if x - whole > 1e-9 and (rand or math.random)() < x - whole then
		whole = whole + 1
	end
	return whole
end

-- deps: { CraftingDropManager, KonjurRewardManager }; the gift: Rewards.GiftPostInit (modmain)
function Rewards.Install(deps)
	if HR.settings.super_main_reward <= 1 then
		return false, "off"
	end
	local done = {}
	local CDM, KRM = deps.CraftingDropManager, deps.KonjurRewardManager
	if type(CDM) == "table" and type(CDM.GetSoulDropCount) == "function" then
		local orig = CDM.GetSoulDropCount
		CDM.GetSoulDropCount = function(self, soul_type, ...)
			local count = orig(self, soul_type, ...)
			if soul_type == "konjur_soul_lesser" and type(count) == "number" and HR.On("super frenzy room rewards") then
				local ok, f = HR.Call("super frenzy room rewards", Rewards.Factor, "small_token")
				if ok and f > 1 then
					local world = rawget(_G, "TheWorld")
					if not (world ~= nil and world.GetCurrentRoomType ~= nil and world:GetCurrentRoomType() == "boss") then
						local scaled = Rewards.Scale(count, f)
						HR.Debug(string.format("corestone room: %d -> %d", count, scaled))
						count = scaled
					end
				end
			end
			return count
		end
		done[#done + 1] = "corestones"
	end
	if type(KRM) == "table" and type(KRM.SpawnRoomRewardMaterial) == "function" then
		local orig = KRM.SpawnRoomRewardMaterial
		KRM.SpawnRoomRewardMaterial = function(self, drop, ...)
			local r = table.pack(orig(self, drop, ...))
			if HR.On("super frenzy room rewards") then
				local ok, f = HR.Call("super frenzy room rewards", Rewards.Factor, "material")
				if ok and f > 1 then
					local extra = Rewards.Scale(1, f) - 1
					for _ = 1, extra do
						local ok2, err = pcall(orig, self, drop, ...)
						if not ok2 then
							HR.Log("material room: the extra bag failed: " .. tostring(err))
							break
						end
					end
					HR.Debug(string.format("material room: %d bags", extra + 1))
				end
			end
			return table.unpack(r, 1, r.n)
		end
		done[#done + 1] = "materials"
	end
	if #done == 0 then
		return false, "the game's room rewards (CraftingDropManager / KonjurRewardManager not found)"
	end
	return true, table.concat(done, ", ")
end

-- The friend gift drop (AddPrefabPostInit "soul_drop_friendgift").
function Rewards.GiftPostInit(inst)
	if not HR.On("super frenzy room rewards") or HR.settings.super_main_reward <= 1 then
		return
	end
	local ok, f = HR.Call("super frenzy room rewards", Rewards.Factor, "friendgift")
	if not ok or f <= 1 then
		return
	end
	local function ScaleDrops(drops)
		if type(drops) == "table" then
			for _, d in pairs(drops) do
				if type(d) == "table" and type(d.count) == "number" then
					d.count = Rewards.Scale(d.count, f)
				end
			end
		end
		return drops
	end
	local c = inst.components
	if c ~= nil and c.souldrop ~= nil then
		ScaleDrops(c.souldrop.child_drops)
	end
	local rd = c ~= nil and c.rotatingdrop or nil
	if rd ~= nil and type(rd.build_drops_fn) == "function" and rd.SetBuildDropsFn ~= nil then
		local orig = rd.build_drops_fn
		rd:SetBuildDropsFn(function(...)
			local drops = orig(...)
			local ok2 = pcall(ScaleDrops, drops)
			return drops
		end)
	end
	HR.Debug("gift room: x" .. tostring(f))
end

return Rewards
