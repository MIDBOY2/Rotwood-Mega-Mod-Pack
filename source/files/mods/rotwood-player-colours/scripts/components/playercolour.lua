-- Player Colours: a character's colour override, saved with the character
-- (like the game's own equipmentdyer / charactercreator data). nil = vanilla:
-- the game's colour for the player number.
local Main = require "playercolours.main"

local PlayerColour = Class(function(self, inst)
	self.inst = inst
	self.key = nil
end)

function PlayerColour:GetKey()
	return self.key
end

-- key nil = vanilla. Applies right away.
function PlayerColour:SetKey(key)
	if key ~= nil and Main.by_key[key] == nil then
		key = nil
	end
	self.key = key
	Main.Apply(self.inst)
end

function PlayerColour:OnSave()
	if self.key ~= nil then
		return { key = self.key }
	end
	return nil
end

function PlayerColour:OnLoad(data)
	local key = type(data) == "table" and data.key or nil
	if key ~= nil and Main.by_key[key] == nil then
		Main.Log("saved colour '" .. tostring(key) .. "' isn't in the list any more: vanilla")
		key = nil
	end
	self.key = key
	-- the player number may not be known yet; "on_player_set" applies it then
	Main.Apply(self.inst)
end

return PlayerColour
