-- Blight Fix: keep the Blight Incursion stage valid for the leg it's used on.
-- The game (components/trekmanager.lua, TrekManager:Advance) moves to the next
-- leg but only sets current_stage when it's empty, so the stage picked at a
-- two-stage leg (the second portal = stage 2) is carried into the next leg.
-- A Rest Room leg has one stage, so the game selects "leg 4-2 (Rest Room)",
-- sends that to its network/save code (TheNet:HostSetTrekData), and only
-- changes it to 4-1 later at the portal. Both crashes came loading that Rest Room.
-- Fix: right before the game selects a leg (TrekManager:SelectLegData, used by
-- Advance and SetCurrentStage), a stage past the leg's stage count becomes 1.

local BlightFix = {}
BlightFix.TAG = "[Blight Fix]"

-- The stage to use instead, or nil when the current one is fine.
function BlightFix.FixedStage(trek)
	local data = trek.data
	if data == nil or data.cfg == nil then
		return nil
	end
	local stage = data.current_stage
	if type(stage) ~= "number" then
		return nil
	end
	local count = trek:GetCurrentLegStageCount()
	if type(count) == "number" and count >= 1 and (stage < 1 or stage > count) then
		return 1, stage, count
	end
	return nil
end

function BlightFix.Install(TrekManager)
	if type(TrekManager) ~= "table"
		or type(TrekManager.SelectLegData) ~= "function"
		or type(TrekManager.GetCurrentLegStageCount) ~= "function"
	then
		return false, "the game's trek code changed (TrekManager.SelectLegData / GetCurrentLegStageCount not found)"
	end
	if TrekManager.blightfix_installed then
		return true, "already on"
	end
	TrekManager.blightfix_installed = true
	local SelectLegData = TrekManager.SelectLegData
	TrekManager.SelectLegData = function(self, ...)
		local ok, fixed, was, count = pcall(BlightFix.FixedStage, self)
		if not ok then
			print(BlightFix.TAG .. " check error: " .. tostring(fixed))
		elseif fixed ~= nil then
			self.data.current_stage = fixed
			print(string.format("%s leg %s has %d stage(s) but stage %d was carried over from the last leg: using stage %d",
				BlightFix.TAG, tostring(self.data.current_leg), count, was, fixed))
		end
		return SelectLegData(self, ...)
	end
	return true, "Blight Incursion stage kept valid between legs"
end

return BlightFix
