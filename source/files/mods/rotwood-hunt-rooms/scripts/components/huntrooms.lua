-- Hunt Rooms: the rooms a run has had, kept with the player (huntrooms/tracker.lua).
local HuntRooms = Class(function(self, inst)
	self.inst = inst
	self.entered = {}
end)

function HuntRooms:Reset()
	self.entered = {}
end

function HuntRooms:Record(key, kind)
	if type(key) == "string" and type(kind) == "string" then
		self.entered[key] = kind
	end
end

function HuntRooms:Count(kind, leave_out)
	local n = 0
	for key, k in pairs(self.entered) do
		if k == kind and key ~= leave_out then
			n = n + 1
		end
	end
	return n
end

function HuntRooms:OnSave()
	if next(self.entered) == nil then
		return nil
	end
	local out = {}
	for key, kind in pairs(self.entered) do
		out[key] = kind
	end
	return { entered = out }
end

function HuntRooms:OnLoad(data)
	if type(data) == "table" and type(data.entered) == "table" then
		for key, kind in pairs(data.entered) do
			if type(key) == "string" and type(kind) == "string" then
				self.entered[key] = kind
			end
		end
	end
end

return HuntRooms
