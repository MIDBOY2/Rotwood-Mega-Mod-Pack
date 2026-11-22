-- Skill Slots: the skills a player picked in the skill menu, saved with the
-- character. slot -> skill name, "weapon", or "none" for a slot they emptied.
-- Slots not listed use the defaults from skillslots_settings.lua.
-- options: menu choices (hide_other_weapons = true/false) and the power
-- rows' size (powers_small: a number, 0 = full size).
-- loadouts: the game's mannequin loadouts (id -> a copy of slots saved with
-- that loadout, skillslots/mannequin.lua).

local SkillSlotsData = Class(function(self, inst)
	self.inst = inst
	self.slots = {}
	self.options = {}
	self.loadouts = {}
end)

function SkillSlotsData:Set(slot, name)
	self.slots[slot] = name or "none"
end

function SkillSlotsData:SetOption(key, value)
	self.options[key] = value
end

function SkillSlotsData:OnSave()
	if next(self.slots) == nil and next(self.options) == nil and next(self.loadouts) == nil then
		return nil
	end
	local slots, options, loadouts = {}, {}, {}
	for k, v in pairs(self.slots) do
		slots[k] = v
	end
	for k, v in pairs(self.options) do
		options[k] = v
	end
	for id, saved in pairs(self.loadouts) do
		local copy = {}
		for k, v in pairs(saved) do
			copy[k] = v
		end
		loadouts[id] = copy
	end
	return { slots = slots, options = options, loadouts = next(loadouts) ~= nil and loadouts or nil }
end

function SkillSlotsData:OnLoad(data)
	if type(data) ~= "table" then
		return
	end
	if type(data.slots) == "table" then
		for k, v in pairs(data.slots) do
			if type(k) == "string" and type(v) == "string" then
				self.slots[k] = v
			end
		end
	end
	if type(data.options) == "table" then
		for k, v in pairs(data.options) do
			-- on / off choices, and numbers (the power rows' size, 0.16.2+:
			-- 0.16.2 / 0.16.3 dropped those here, so the size went back to
			-- full in every new room); a number only when it's a real one
			if type(k) == "string" and (type(v) == "boolean"
				or (type(v) == "number" and v == v and v > -1e9 and v < 1e9)) then
				self.options[k] = v
			end
		end
	end
	if type(data.loadouts) == "table" then
		for id, saved in pairs(data.loadouts) do
			if type(saved) == "table" then
				local copy = {}
				for k, v in pairs(saved) do
					if type(k) == "string" and type(v) == "string" then
						copy[k] = v
					end
				end
				self.loadouts[tostring(id)] = copy
			end
		end
	end
end

function SkillSlotsData:GetDebugString()
	local parts = {}
	for k, v in pairs(self.slots) do
		parts[#parts + 1] = k .. "=" .. v
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

return SkillSlotsData
