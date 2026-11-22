-- Skill Limits: the skill icon of a skill that's out of uses. It goes grey
-- (the game's own "not available" look, the one locked slots use) with a red
-- X over it, and the seconds left stay top right (the power's counter). It's
-- back to normal the moment the uses come back.
--
-- The game refreshes its big skill icon (SkillWidget) on the power's
-- "update_power" event; this adds the look to that refresh. Skill Slots' slot
-- icons call Hud.Refresh the same way. Nothing per frame.

local Hud = {}

Hud.installed = false

local SQUARE = "images/global/square.tex" -- the game's plain fill texture

local function Hex(hex, r, g, b)
	if type(HexToRGB) == "function" then
		local ok, c = pcall(HexToRGB, hex)
		if ok and c ~= nil then
			return c
		end
	end
	return { r, g, b, 1 }
end

-- a skill out of uses (the player's Skill Limits state)
function Hud.IsResting(owner, name)
	local st = type(owner) == "table" and owner.skilllimits or nil
	return name ~= nil and st ~= nil and st.empty ~= nil and st.empty[name] == true
end

-- the red X, centred on the icon, out of the icon's size and layout
local function MakeX(icon)
	local Widget = require "widgets.widget"
	local Image = require "widgets.image"
	local size = icon.base_width or 100
	local x = icon:AddChild(Widget("Skill Limits X"))
	pcall(x.SetHiddenBoundingBox, x, true)
	pcall(x.IgnoreInput, x)
	local len, thick, edge = size * 0.74, size * 0.13, size * 0.035
	local black = UICOLORS ~= nil and UICOLORS.BLACK or { 0, 0, 0, 1 }
	local red = Hex(0xEE5C5CFF, 0.93, 0.36, 0.36) -- UICOLORS.PENALTY
	for _, layer in ipairs({ { black, edge }, { red, 0 } }) do
		for _, rot in ipairs({ 45, -45 }) do
			local bar = x:AddChild(Image(SQUARE))
			bar:SetSize(len + 2 * layer[2], thick + 2 * layer[2])
			bar:SetMultColor(layer[1])
			bar:SetRotation(rot)
		end
	end
	rawset(icon, "skilllimits_x", x)
	return x
end

-- icon: the game's SkillIconWidget
function Hud.Apply(icon, resting)
	if type(icon) ~= "table" or icon.icon_container == nil then
		return
	end
	local dimmed = rawget(icon, "skilllimits_dimmed") == true
	if resting and not dimmed then
		local x = rawget(icon, "skilllimits_x") or MakeX(icon)
		icon.icon_container:SetMultColor(Hex(0x524643FF, 0.32, 0.27, 0.26))
		icon.icon_container:SetSaturation(0.1)
		x:Show()
		rawset(icon, "skilllimits_dimmed", true)
	elseif not resting and dimmed then
		icon.icon_container:SetMultColor(1, 1, 1, 1)
		icon.icon_container:SetSaturation(1)
		local x = rawget(icon, "skilllimits_x")
		if x ~= nil then
			x:Hide()
		end
		rawset(icon, "skilllimits_dimmed", false)
	end
end

-- for any skill icon: owner = the player, name = the skill
function Hud.Refresh(icon, owner, name)
	Hud.Apply(icon, Hud.IsResting(owner, name))
end

local function RefreshSkillWidget(self)
	local def = self.skill_def
	Hud.Refresh(self.skill_widget, self.owner, def ~= nil and def.name or nil)
end

local function After(cls, method)
	local orig = cls[method]
	cls[method] = function(self, ...)
		local results = table.pack(orig(self, ...))
		pcall(RefreshSkillWidget, self)
		return table.unpack(results, 1, results.n)
	end
end

-- The game's big skill icon: after its refreshes (update_power) and when it's
-- built (a HUD made mid-rest).
function Hud.Install()
	local ok, SkillWidget = pcall(require, "widgets.ftf.skillwidget")
	if not ok or type(SkillWidget) ~= "table" or type(SkillWidget.UpdateStacks) ~= "function"
		or type(SkillWidget.SetSkill) ~= "function" then
		return false
	end
	After(SkillWidget, "UpdateStacks")
	After(SkillWidget, "SetSkill")
	Hud.installed = true
	return true
end

return Hud
