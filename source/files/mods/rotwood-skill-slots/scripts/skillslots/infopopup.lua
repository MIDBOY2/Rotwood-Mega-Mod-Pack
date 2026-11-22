-- Skill Slots: skill overview popup (X in the menu, keyboard Shift). Covers
-- the player's own panel, like the game's info popups: big icon, name, which
-- weapon it needs, whether you own it, the full description, and the keyword
-- explanations the game's weapon tooltips show. Shrinks to fit the window.

local Core = require "skillslots.core"
local ImageButton = require "widgets.imagebutton"
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"

local function TryRequire(name)
	local ok, mod = pcall(require, name)
	return ok and mod or nil
end
local SkillWidget = TryRequire("widgets/ftf/skillwidget")
local SkillIconWidget = TryRequire("widgets.ftf.skilliconwidget")
local PowerDescriptionWidget = TryRequire("widgets/ftf/powerdescriptionwidget")
local PowerTooltipModule = TryRequire("widgets.ftf.powertooltip")
local PowerKeyWordTooltip = type(PowerTooltipModule) == "table" and PowerTooltipModule.PowerKeyWordTooltip or nil

local STR = {
	ANY_WEAPON = "Any weapon",
	WEAPON_SKILL = "%s skill",
	OWNED = "Owned",
	NOT_OWNED = "Not owned yet (works on a slot anyway)",
	ON_SLOT = "On %s",
	WEAPON_TOKEN = "Your weapon's own skill. It changes with your weapon, and a skill you pick up during a run replaces it.",
	CLOSE_HINT = "<p bind='Controls.Digital.CANCEL' color=0> Close",
}

local ICON_SIZE = 220
local PAD = 70
local MIN_SCALE = 0.5

local SkillInfoPopup = Class(Widget, function(self, player, def, opts)
	Widget._ctor(self, "SkillInfoPopup")
	opts = opts or {}
	self:SetOwningPlayer(player)
	self.player = player
	self.def = def
	self.width = opts.width or 1400
	self.height = opts.height or 900

	self.background = self:AddChild(Panel("images/bg_popup_small_empty/popup_small_empty.tex"))
		:SetName("Background")
		:SetNineSliceCoords(90, 50, 1558, 850)
		:SetNineSliceBorderScale(0.75)
		:SetSize(self.width, self.height)

	self.content = self:AddChild(Widget()):SetName("Content")
	local text_w = self.width - PAD * 2

	-- header: icon + name + tag line
	self.header = self.content:AddChild(Widget()):SetName("Header")
	local item = opts.item
	if item ~= nil and SkillWidget ~= nil then
		local ok, w = pcall(SkillWidget, ICON_SIZE, player, item)
		if ok and w ~= nil then
			self.icon = self.header:AddChild(w)
			pcall(w.DisableToolTip, w, true)
		end
	end
	if self.icon == nil and item ~= nil and SkillIconWidget ~= nil then
		self.icon = self.header:AddChild(SkillIconWidget())
		pcall(self.icon.SetSkill, self.icon, item)
		pcall(Core.FitIcon, self.icon, rawget(self.icon, "def"))
		pcall(self.icon.SetScaleToMatchWidth, self.icon, ICON_SIZE)
	end
	self.names = self.header:AddChild(Widget()):SetName("Names")
	local name_w = text_w - ICON_SIZE - 40
	self.title = self.names:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_TITLE or 70))
		:SetGlyphColor(UICOLORS.DARK_TEXT_DARKER)
		:SetAutoSize(name_w)
		:LeftAlign()
		:SetText(opts.title or Core.GetSkillName(def))
	self.tags = self.names:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.DARK_TEXT)
		:SetAutoSize(name_w)
		:LeftAlign()
		:SetText(opts.tags or "")

	-- description (its numbers are in the text; the game's separate list of
	-- them has no names for skills, so it isn't shown)
	self.body = self.content:AddChild(Widget()):SetName("Body")
	local described = false
	if opts.text ~= nil then
		self.body:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.1))
			:SetGlyphColor(UICOLORS.DARK_TEXT_DARKER)
			:SetAutoSize(text_w)
			:LeftAlign()
			:SetText(opts.text)
		described = true
	end
	if item ~= nil and PowerDescriptionWidget ~= nil and not item.skillslots_pseudo then
		local ok, w = pcall(function()
			local desc = self.body:AddChild(PowerDescriptionWidget(text_w, FONTSIZE.SCREEN_TEXT * 1.1))
			desc:SetFontColor(UICOLORS.DARK_TEXT_DARKER)
			desc:SetPower(item, nil, false)
			if desc.SetVariableFontColor ~= nil then
				desc:SetVariableFontColor(UICOLORS.DARK_TEXT)
			end
			return desc
		end)
		if ok then
			described = true
		elseif w ~= nil then
			Core.Log("skill info: description widget failed: " .. tostring(w))
		end
	end
	if not described and opts.fallback_desc ~= nil then
		self.body:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.1))
			:SetGlyphColor(UICOLORS.DARK_TEXT_DARKER)
			:SetAutoSize(text_w)
			:LeftAlign()
			:SetText(opts.fallback_desc)
	end

	-- keyword explanations (what the game's weapon tooltips add for skills),
	-- in the plain style the game uses for them on its parchment screens (the
	-- equipment tooltip): no highlight bar, muted brown text, red keywords
	if item ~= nil and not item.skillslots_pseudo and PowerKeyWordTooltip ~= nil and def ~= nil and type(def.tooltips) == "table" then
		for _, keyword in ipairs(def.tooltips) do
			if keyword ~= "SKILL" then
				pcall(function()
					local tip = self.body:AddChild(PowerKeyWordTooltip())
					tip:LayoutWithContent({ keyword = keyword, power = item, width = text_w })
					if tip.bg ~= nil and tip.SetTheme_LightOnTransparent ~= nil then
						tip:SetTheme_LightOnTransparent()
					end
				end)
			end
		end
	end
	if opts.note ~= nil then
		self.body:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
			:SetGlyphColor(UICOLORS.DARK_TEXT)
			:SetAutoSize(text_w)
			:LeftAlign()
			:SetText(opts.note)
	end

	self.hint = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 0.9))
		:SetGlyphColor(UICOLORS.DARK_TEXT)
		:SetText(STR.CLOSE_HINT)

	self.close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetName("Close button")
		:SetSize(rawget(_G, "BUTTON_SQUARE_SIZE") or 100, rawget(_G, "BUTTON_SQUARE_SIZE") or 100)
		:SetOnClick(function() self:Close() end)

	self:Layout()
end)

SkillInfoPopup.STR = STR

function SkillInfoPopup:Layout()
	self.names:LayoutChildrenInColumn(10, "left")
	if self.icon ~= nil then
		self.names:LayoutBounds("after", "center", self.icon):Offset(40, 0)
	end
	self.body:LayoutChildrenInColumn(30, "left")
	self.body:LayoutBounds("left", "below", self.header):Offset(0, -40)
	-- everything stays inside the window, above the close hint: a long
	-- description shrinks instead of running off the bottom
	self.content:SetScale(1)
	local cw, ch = self.content:GetSize()
	local _, hint_h = self.hint:GetSize()
	local avail_w = self.width - PAD * 2
	local avail_h = self.height - PAD - (40 + (hint_h or 0) + 30)
	local scale = 1
	if type(ch) == "number" and ch > avail_h and ch > 0 then
		scale = avail_h / ch
	end
	if type(cw) == "number" and cw > avail_w and cw > 0 then
		scale = math.min(scale, avail_w / cw)
	end
	self.content_scale = math.max(scale, MIN_SCALE)
	self.content:SetScale(self.content_scale)
	self.content:LayoutBounds("left", "top", self.background):Offset(PAD, -PAD)
	self.hint:LayoutBounds("center", "bottom", self.background):Offset(0, 40)
	self.close_button:LayoutBounds("right", "top", self.background):Offset(20, 20)
	return self
end

function SkillInfoPopup:SetOnCloseFn(fn)
	self.on_close_fn = fn
	return self
end

function SkillInfoPopup:Close()
	if self.closed then
		return
	end
	self.closed = true
	if self.on_close_fn ~= nil then
		self.on_close_fn()
	end
end

function SkillInfoPopup:FindDefaultFocus()
	return self.close_button
end

function SkillInfoPopup:SetDefaultFocus(hunter_id)
	self.close_button:SetFocus(hunter_id)
	return true
end

function SkillInfoPopup:AnimateIn()
	local x, y = self:GetPosition()
	if type(x) ~= "number" or type(y) ~= "number" then
		return self
	end
	self:ScaleTo(0.9, 1, 0.12, easing.outQuad)
		:SetPosition(x, y - 40)
		:MoveTo(x, y, 0.2, easing.outQuad)
	return self
end

local close_controls = {}
for _, name in ipairs({ "ACCEPT", "CANCEL", "MENU_SECONDARY", "MENU_ACCEPT" }) do
	local c = rawget(Controls.Digital, name)
	if c ~= nil then
		close_controls[#close_controls + 1] = c
	end
end
SkillInfoPopup.CONTROL_MAP = {
	{
		control_list = close_controls,
		fn = function(self)
			self:Close()
			return true
		end,
	},
}

return SkillInfoPopup
