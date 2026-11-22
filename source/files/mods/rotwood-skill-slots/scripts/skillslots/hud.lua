-- Skill Slots: HUD. The big skill icon shows B's skill; LT / RT / RS skills get
-- icons with their button on them. No "last used" highlight.
-- hud.layout = "cluster" (default): the four skills in a cluster next to the
-- portrait, like the controller (RS and RT on top, B and LT under them, the top
-- row half a step sideways), every icon with its button. The weight circle
-- becomes a small badge after the player's name (like the weapon badge in front
-- of it), and the power rows and the town's weapon tips move past the cluster.
-- The game packs the weight and skill icons and the power rows in a honeycomb
-- (each row half an icon sideways). The slot icons carry on the weight / skill
-- zigzag along the screen edge, away from the power rows, so they never sit on
-- top of powers. (hud.layout = "row" puts them in a row next to B, like before.)

local Core = require "skillslots.core"
local Power = require "defs.powers"
local Widget = require "widgets.widget"
local Text = require "widgets.text"
local Image = require "widgets.image"
local SkillIconWidget = require "widgets.ftf.skilliconwidget"
local PlayerPowersWidget = require "widgets/ftf/playerpowerswidget"

local Hud = {}

local orig_SetSkill, orig_RemoveSkill, orig_PositionPowers, orig_ctor

-- The big icon shows only B's skill (with the mod off: vanilla).
local function Shows(self, name)
	if not Core.IsActive(self.owner) then
		return true
	end
	return name == Core.GetBSkillName(self.owner)
end

local function IsRightSide(self)
	return self.layout_mode == "TOP_RIGHT" or self.layout_mode == "BOTTOM_RIGHT"
end

local function IsBottom(self)
	return self.layout_mode == "BOTTOM_LEFT" or self.layout_mode == "BOTTOM_RIGHT"
end

-- Old layout: a row next to B's icon.
local function PositionAsRow(self, row, hud)
	local right = IsRightSide(self)
	row:LayoutChildrenInRow(hud.spacing or 6, "center")
	row:LayoutBounds(right and "before" or "after", "center", self.skill_root)
	row:Offset((right and -1 or 1) * (hud.x or 0), hud.y or 0)
end

-- Honeycomb: the game puts the skill under the weight, half an icon sideways
-- (_PositionPowers), and the power rows hug both, each row half an icon off
-- the one before. The slot icons go along the screen edge, away from the
-- power rows: top HUDs down from the skill, bottom HUDs up from the weight
-- (whichever of the two sits on the outside). The first one goes straight on,
-- then they zigzag inward / outward like the rest of the honeycomb.
local function PositionAsZigzag(self, row, hud)
	local hsign = IsRightSide(self) and -1 or 1 -- inward: toward the power rows
	local half = (self.power_size or 130) / 2
	local tight = type(hud.overlap) == "number" and hud.overlap or 10 -- same squeeze as the game's skill icon
	local gap = 4 -- the straight step
	local prev, vreg
	if not IsBottom(self) or self.weight_root == nil then
		prev, vreg = self.skill_root, "below"
	else
		prev, vreg = self.weight_root, "above"
	end
	local vdir = vreg == "below" and 1 or -1
	row:SetPosition(0, 0)
	for i, cell in ipairs(row.children) do
		cell:SetPosition(0, 0)
		local dx, dy
		if i == 1 then
			dx, dy = hsign * (hud.x or 0), -vdir * gap + (hud.y or 0)
		else
			dx, dy = (i % 2 == 0 and 1 or -1) * hsign * half, vdir * tight
		end
		cell:LayoutBounds("center", vreg, prev):Offset(dx, dy)
		prev = cell
	end
end

-- Cluster: where each slot sits, from B's icon (the game's skill icon):
-- col = steps sideways (away from the screen edge), top = the row above.
local CLUSTER = { LT = { col = 1 }, RS = { col = 0, top = true }, RT = { col = 1, top = true } }

local function Num(v, default)
	return type(v) == "number" and v or default
end

local function ClusterOn(owner)
	local hud = Core.settings ~= nil and Core.settings.hud or nil
	return hud ~= nil and hud.layout == "cluster" and owner ~= nil and Core.IsActive(owner)
end
Hud.ClusterOn = ClusterOn

-- B's button on the game's skill icon (the slot icons have theirs)
local function BGlyph(self, on)
	local g = self.skillslots_bglyph
	if not on then
		if g ~= nil then
			g:Hide()
		end
		return
	end
	if g == nil then
		local size = self.skill_size or 116
		local glyph_size = math.floor(math.min(44, size * 0.4))
		g = self.skill_root:AddChild(Text(FONTFACE.DEFAULT, glyph_size))
		pcall(g.SetHiddenBoundingBox, g, true)
		pcall(g.SetOwningPlayer, g, self.owner)
		local controls = rawget(_G, "Controls")
		local control = controls ~= nil and controls.Digital ~= nil and rawget(controls.Digital, "SKILL") or nil
		g:SetText(control ~= nil and string.format("<p bind='%s' color=0>", control.key) or "B")
		self.skillslots_bglyph = g
		self.skillslots_bglyph_size = glyph_size
	end
	g:Show()
	g:SendToFront()
	g:LayoutBounds("center", "bottom", self.skill_bg or self.skill_root)
	g:Offset(0, -self.skillslots_bglyph_size * 0.3)
end

local function PositionAsCluster(self, row, hud)
	local c = type(hud.cluster) == "table" and hud.cluster or {}
	local hsign = IsRightSide(self) and -1 or 1
	-- skill_scale: the four skill icons (the game's B icon and the slots)
	-- drawn a bit bigger
	local k = math.max(0.5, math.min(2, Num(c.skill_scale, 1)))
	if self.skill_root ~= nil then
		self.skill_root:SetScale(k, k)
	end
	self.skillslots_skill_scale = k
	local size = (self.skillslots_cell_size or self.skill_size or 116) * k
	local step = size + Num(c.gap, 24)
	local shift = Num(c.shift, 0.4)
	if self.weight_root ~= nil then
		self.weight_root:Hide() -- it's the badge after the name now
		self.skillslots_hid_weight = true
	end
	if row ~= nil then
		pcall(row.SetHiddenBoundingBox, row, false) -- the HUD lines everything up past the cluster
		row:SetPosition(0, 0)
		for _, cell in ipairs(row.children) do
			cell:SetPosition(0, 0)
			cell:SetScale(k, k)
			local spot = CLUSTER[cell.skillslots_slot]
			if spot ~= nil then
				local dx = hsign * step * (spot.col + (spot.top and shift or 0)) + hsign * Num(hud.x, 0)
				if spot.top then
					cell:LayoutBounds("center", "above", self.skill_root):Offset(dx, Num(c.rise, 0) + Num(hud.y, 0))
				else
					cell:LayoutBounds("center", "center", self.skill_root):Offset(dx, Num(hud.y, 0))
				end
			end
		end
	end
	BGlyph(self, true)
	-- the power rows past the cluster (the game tucks them into its honeycomb),
	-- drawn power_scale times the game's size, power_gap past the skills
	if self.powers_root ~= nil and self.static_slots ~= nil then
		local bottom = IsBottom(self)
		-- (times the player's half size, powershide.lua)
		local ps = Num(c.power_scale, 1.3) * (tonumber(rawget(self, "skillslots_power_factor")) or 1)
		self.powers_root:SetScale(ps, ps)
		self.skillslots_power_scale = ps
		self.powers_root:LayoutBounds(hsign > 0 and "after" or "before", bottom and "bottom" or "top", self.static_slots)
			:Offset(hsign * Num(c.power_gap, Num(c.gap, 24)), bottom and 20 or -20)
	end
end

local function Uncluster(self)
	if self.skillslots_hid_weight and self.weight_root ~= nil then
		self.weight_root:Show()
		self.skillslots_hid_weight = nil
	end
	if self.skillslots_power_scale ~= nil and self.powers_root ~= nil then
		local k = tonumber(rawget(self, "skillslots_power_factor")) or 1
		self.powers_root:SetScale(k, k)
		self.skillslots_power_scale = nil
	end
	if self.skillslots_skill_scale ~= nil then
		if self.skill_root ~= nil then
			self.skill_root:SetScale(1, 1)
		end
		local row = self.skillslots_row
		for _, cell in ipairs(row ~= nil and row.children or {}) do
			cell:SetScale(1, 1)
		end
		self.skillslots_skill_scale = nil
	end
	BGlyph(self, false)
end

local function PositionRow(self)
	if ClusterOn(self.owner) then
		PositionAsCluster(self, self.skillslots_row, Core.settings.hud)
		return
	end
	Uncluster(self)
	local row = self.skillslots_row
	if row == nil or self.skill_root == nil or row.children == nil or #row.children == 0 then
		return
	end
	local hud = Core.settings.hud
	if hud.layout == "row" then
		PositionAsRow(self, row, hud)
	else
		PositionAsZigzag(self, row, hud)
	end
end

-- Skill Limits (when it's on): a skill out of uses goes grey with a red X,
-- like on the big skill icon. false = not there.
local limits_look = nil
local function LimitsLook()
	if limits_look == nil then
		local ok, m = pcall(require, "skilllimits.hud")
		limits_look = ok and type(m) == "table" and type(m.Refresh) == "function" and m or false
	end
	return limits_look or nil
end

-- The game's skill number (a cooldown's seconds, a skill's stacks: the power's
-- counter), top right like on the big skill icon. Updated on the game's own
-- "update_power" event, nothing per frame.
local function AddCounter(cell, icon, pow, owner, size)
	local ok, counter = pcall(Text, FONTFACE.DEFAULT, math.floor(size * 0.4))
	if not ok or counter == nil then
		return
	end
	cell:AddChild(counter)
	pcall(function()
		counter:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
		counter:SetShadowColor(UICOLORS.BLACK)
		counter:SetShadowOffset(1, -1)
		counter:SetOutlineColor(UICOLORS.BLACK)
		counter:EnableShadow()
		counter:EnableOutline()
	end)
	pcall(counter.SetHiddenBoundingBox, counter, true)
	local function show()
		local c = pow.persistdata ~= nil and pow.persistdata.counter or nil
		if (type(c) == "number" and c > 0) or (type(c) == "string" and c ~= "") then
			counter:SetText(tostring(c))
			counter:LayoutBounds("right", "top", icon)
			counter:Offset(-size * 0.06, -size * 0.06)
			counter:Show()
		else
			counter:Hide()
		end
		local look = LimitsLook()
		if look ~= nil then
			pcall(look.Refresh, icon, owner, pow.def ~= nil and pow.def.name or nil)
		end
	end
	show()
	if cell.inst ~= nil and owner ~= nil then
		cell.inst:ListenForEvent("update_power", function(_, def)
			if def ~= nil and pow.def ~= nil and def.name == pow.def.name then
				pcall(show)
			end
		end, owner)
	end
end

-- Rebuild the slot icons if the slots changed. Returns true if anything changed.
local function RefreshRow(self)
	local owner = self.owner
	local hud = Core.settings.hud
	local entries, names = {}, {}
	if Core.IsActive(owner) and Core.GetHudIcons(owner) then
		local pm = owner.components.powermanager
		for _, slot in ipairs(Core.SLOT_ORDER) do
			local name = Core.GetSlotSkill(owner, slot)
			local pow = name ~= nil and pm ~= nil and pm.powers[name] or nil
			if pow ~= nil then
				entries[#entries + 1] = { slot = slot, pow = pow }
				names[#names + 1] = slot .. "=" .. name
			elseif Core.IsPseudo(name) and Core.CanUse(owner, Core.GetDef(name)) then
				-- Block (the Greatsword's): its icon, no number
				entries[#entries + 1] = { slot = slot, item = Core.MakePseudoItem(Core.GetDef(name)) }
				names[#names + 1] = slot .. "=" .. name
			end
		end
	end
	local sig = table.concat(names, ",")
	if self.skillslots_sig == sig then
		return false
	end
	self.skillslots_sig = sig
	if self.skillslots_row ~= nil then
		self.skillslots_row:Remove()
		self.skillslots_row = nil
	end
	if #entries == 0 then
		return true
	end

	local row = (self.static_slots or self):AddChild(Widget("Skill Slots"))
	self.skillslots_row = row
	-- left out of the HUD's size: the game lines the power rows up against the
	-- weight / skill icons' box, and the slot icons mustn't push them around
	pcall(row.SetHiddenBoundingBox, row, true)
	pcall(row.SetOwningPlayer, row, owner) -- button glyphs follow this player's device
	-- "full" (or no number) = same size as the weapon skill icon
	local size = type(hud.size) == "number" and hud.size or self.skill_size or 116
	self.skillslots_cell_size = size
	local glyph_size = math.floor(math.min(44, size * 0.4))
	local as_row = hud.layout == "row"
	for _, e in ipairs(entries) do
		local cell = row:AddChild(Widget("Skill Slot " .. e.slot))
		cell.skillslots_slot = e.slot
		local icon = cell:AddChild(SkillIconWidget())
		icon:SetSkill(e.pow ~= nil and e.pow.persistdata or e.item)
		pcall(Core.FitIcon, icon, rawget(icon, "def"))
		icon:SetScaleToMatchWidth(size)
		local glyph = cell:AddChild(Text(FONTFACE.DEFAULT, glyph_size))
		glyph:SetText(string.format("<p bind='%s' color=0>", Core.controls[e.slot].key))
		if as_row then
			glyph:LayoutBounds("center", "below", icon)
			glyph:Offset(0, glyph_size * 0.35)
		else
			-- on the icon's lower edge, so the honeycomb stays tight
			pcall(glyph.SetHiddenBoundingBox, glyph, true)
			glyph:LayoutBounds("center", "bottom", icon)
			glyph:Offset(0, -glyph_size * 0.3)
		end
		if e.pow ~= nil then
			AddCounter(cell, icon, e.pow, owner, size)
		end
	end
	PositionRow(self)
	return true
end

-- B holds a weapon choice it can use right now (Block on B): its name, or nil.
local function BPseudo(self)
	local owner = self.owner
	if not Core.IsActive(owner) then
		return nil
	end
	local name = Core.GetSlotValue(owner, "B")
	if Core.IsPseudo(name) and Core.CanUse(owner, Core.GetDef(name)) then
		return name
	end
	return nil
end

-- Big icon: only skills that aren't slot-only (or Block, when it's on B).
-- Then the slot row.
local function Reconcile(self)
	local owner = self.owner
	local pm = owner ~= nil and owner.components ~= nil and owner.components.powermanager or nil
	if pm == nil or pm.powers == nil or self.skill_widget == nil then
		return
	end
	local changed = false
	local bpseudo = BPseudo(self)
	for name, w in pairs(self.skill_widget) do
		local keep
		if Core.IsPseudo(name) then
			keep = name == bpseudo
		else
			keep = pm.powers[name] ~= nil and Shows(self, name)
		end
		if not keep then
			w:Remove()
			self.skill_widget[name] = nil
			changed = true
		end
	end
	for name, pow in pairs(pm.powers) do
		if pow.def ~= nil and pow.def.power_type == Power.Types.SKILL
			and self.skill_widget[name] == nil and Shows(self, name) then
			orig_SetSkill(self, pow.persistdata, false)
		end
	end
	if bpseudo ~= nil and self.skill_widget[bpseudo] == nil then
		orig_SetSkill(self, Core.MakePseudoItem(Core.GetDef(bpseudo)), false)
		local w = self.skill_widget[bpseudo]
		if w ~= nil and w.SetToolTip ~= nil then
			pcall(w.SetToolTip, w, nil) -- the power tooltip is for real skills
		end
	end
	if RefreshRow(self) then
		changed = true
	end
	if changed then
		self:_LayoutPowers()
	end
end

local errors = 0

----------------------------------------------------------------------------
-- The player's HUD frame (cluster layout): the weight class as a badge after
-- the name, and the town's weapon tips past the cluster.

local function WeightDef(owner)
	local pm = owner ~= nil and owner.components ~= nil and owner.components.powermanager or nil
	if pm == nil or pm.GetPowersOfType == nil then
		return nil
	end
	local list = pm:GetPowersOfType(Power.Types.WEIGHT)
	local pow = type(list) == "table" and list[1] or nil
	if pow == nil then
		return nil
	end
	return pow.def or (pow.GetDef ~= nil and pow:GetDef()) or nil
end
Hud.WeightDef = WeightDef

-- right after the name's letters (the name sits in a fixed-width box)
local function PlaceBadge(uname)
	local b = uname.skillslots_badge
	local text = uname.name_text
	if b == nil or text == nil or not b:IsShown() then
		return
	end
	local x2 = nil
	if text.inst ~= nil and text.inst.TextWidget ~= nil and text.inst.TextWidget.GetRenderBounds ~= nil then
		local _, _, rx2 = text.inst.TextWidget:GetRenderBounds()
		x2 = rx2
	end
	if type(x2) ~= "number" then
		local _, _, bx2 = text:GetBoundingBox()
		x2 = bx2 or 0
	end
	local nx, ny = text:GetPosition()
	local size = b.skillslots_size or 40
	b:SetPosition(nx + x2 + 6 + size / 2, ny)
end
Hud.PlaceBadge = PlaceBadge

----------------------------------------------------------------------------
-- The name over the portrait (cluster layout): weapon badge + name + class
-- badge no wider than the portrait. A long name first gets a smaller font
-- (down to hud.name_min_font), then is cut with "..." (the game's own "..."
-- sat at the end of the 160-wide name box, where the class badge goes, and a
-- long name pushed the badge off the portrait: off the screen on right-side
-- HUDs).

local ELLIPSIS = "..."

local function Chars(s)
	if type(string.utf8len) == "function" then
		return string.utf8len(s)
	end
	if utf8 ~= nil and utf8.len ~= nil then
		return utf8.len(s) or #s
	end
	return #s
end

local function Prefix(s, n)
	if type(string.utf8sub) == "function" then
		return string.utf8sub(s, 1, n)
	end
	if utf8 ~= nil and utf8.offset ~= nil then
		local cut = utf8.offset(s, n + 1)
		return cut ~= nil and s:sub(1, cut - 1) or s
	end
	return s:sub(1, n)
end

local function FullName(uname)
	local owner = uname.owner
	if owner ~= nil and owner.GetCustomUserName ~= nil then
		local ok, name = pcall(owner.GetCustomUserName, owner)
		if ok and type(name) == "string" then
			return name
		end
	end
	return rawget(uname, "skillslots_full_name")
end

local function ShownText(text)
	if text.GetUnformattedText ~= nil then
		return text:GetUnformattedText()
	end
	return text:GetText()
end

local function TextWidth(text)
	local ok, w = pcall(text.GetRenderWidth, text)
	return ok and type(w) == "number" and w or 0
end

-- avail: the room for the letters, in the name text's own units
function Hud.FitName(uname, avail)
	local text = uname.name_text
	local full = FullName(uname)
	if text == nil or type(full) ~= "string" or type(avail) ~= "number" or avail <= 0 then
		return
	end
	local base = rawget(uname, "skillslots_base_font")
	if base == nil then
		base = rawget(text, "unscaled_size") or text:GetFontSize() or 40
		uname.skillslots_base_font = base
	end
	local min_font = math.min(base, Num(Core.settings.hud.name_min_font, 26))
	local key = full .. "\0" .. math.floor(avail + 0.5) .. "\0" .. base .. "\0" .. min_font
	if rawget(uname, "skillslots_fit_key") == key and ShownText(text) == rawget(uname, "skillslots_fit_text") then
		return -- already fitted (the HUD lays out often: keep it cheap)
	end
	local function Try(size, s)
		text:SetFontSize(size)
		if ShownText(text) == s and text.RefreshText ~= nil then
			text:RefreshText() -- same letters, new size: measure them again
		else
			text:SetText(s)
		end
		return TextWidth(text)
	end
	local size, shown = base, full
	local w = Try(size, full)
	if w > avail then
		size = math.max(min_font, math.floor(base * avail / w))
		w = Try(size, full)
		while w > avail and size > min_font do
			size = size - 1
			w = Try(size, full)
		end
		if w > avail then
			-- still too long at the smallest font: as many letters as fit, then "..."
			local lo, hi = 0, Chars(full) - 1
			while lo < hi do
				local mid = math.ceil((lo + hi) / 2)
				if Try(size, (Prefix(full, mid):gsub("%s+$", "")) .. ELLIPSIS) <= avail then
					lo = mid
				else
					hi = mid - 1
				end
			end
			shown = (Prefix(full, lo):gsub("%s+$", "")) .. ELLIPSIS
			Try(size, shown)
		end
	end
	if uname.ellipsis ~= nil then
		uname.ellipsis:Hide()
	end
	uname.skillslots_fit_key, uname.skillslots_fit_text, uname.skillslots_fit_size = key, shown, size
	uname.skillslots_full_name = full
end

-- back to the game's name (mod off for this player, or name_fit = false)
function Hud.UnfitName(uname)
	if rawget(uname, "skillslots_fit_key") == nil then
		return
	end
	local text = uname.name_text
	local full = FullName(uname)
	text:SetFontSize(rawget(uname, "skillslots_base_font") or 40)
	if type(full) == "string" then
		text:SetText(full)
	end
	if uname.ellipsis ~= nil and text.FitsRegionWidth ~= nil and not text:FitsRegionWidth() then
		uname.ellipsis:Show()
	end
	uname.skillslots_fit_key, uname.skillslots_fit_text, uname.skillslots_fit_size = nil, nil, nil
end

-- The weight class symbols (the mod's images): the game's weight icons are a
-- dark hexagon with a white symbol, which would be a black hexagon on the tag;
-- these are the symbols alone (arm / scales / feathers), drawn black.
Hud.WEIGHT_ICONS = {
	weight_heavy = "images/skillslots_icons/icon_skillslots_weight_heavy.tex",
	weight_normal = "images/skillslots_icons/icon_skillslots_weight_normal.tex",
	weight_light = "images/skillslots_icons/icon_skillslots_weight_light.tex",
}

local function UpdateBadge(status)
	local uname = status.username
	if uname == nil then
		return
	end
	local owner = status.owner
	local def = ClusterOn(owner) and Core.settings.hud.class_badge ~= false and WeightDef(owner) or nil
	local icon_tex = def ~= nil and Hud.WEIGHT_ICONS[def.name] or nil
	if type(icon_tex) ~= "string" then
		if uname.skillslots_badge ~= nil then
			uname.skillslots_badge:Hide()
		end
		return
	end
	local b = uname.skillslots_badge
	if b == nil then
		b = uname:AddChild(Widget("Skill Slots class badge"))
		pcall(b.SetHiddenBoundingBox, b, true) -- the name box keeps its size
		b.skillslots_bg = b:AddChild(Image("images/ui_ftf_hud/UI_HUD_playerTagBG.tex"))
		b.skillslots_icon = b:AddChild(Image(icon_tex))
		pcall(b.skillslots_icon.SetMultColor, b.skillslots_icon, UICOLORS.BLACK)
		uname.skillslots_badge = b
	end
	-- the same size as the weapon badge in front of the name
	local size = 40
	local wb = uname.weapon_widget ~= nil and uname.weapon_widget.bg or nil
	if wb ~= nil and wb.GetSize ~= nil then
		local w = wb:GetSize()
		if type(w) == "number" and w > 0 then
			size = w
		end
	end
	b.skillslots_size = size
	b.skillslots_bg:SetSize(size, size)
	if owner.uicolor ~= nil then
		pcall(b.skillslots_bg.SetMultColor, b.skillslots_bg, owner.uicolor)
	end
	b.skillslots_icon:SetTexture(icon_tex)
	b.skillslots_icon:SetSize(size * 0.8, size * 0.8)
	b:Show()
	PlaceBadge(uname)
end

local function IsRightStatus(status)
	local mode = status.layout_mode
	return mode == "TOP_RIGHT" or mode == "BOTTOM_RIGHT"
end

-- The health bar sits on the name's line, starting at the portrait's edge, but
-- the name box (weapon badge + a 160-wide name at the HUD's big font, + the
-- class badge after it in the cluster layout) is wider than the portrait: the
-- bar covered the end of the name and its badges (the game's own layout; long
-- names show it most). The bar now starts past the name's box, and the dark
-- frame behind grows by as much.
local function Box(root, w)
	local x1, y1, x2, y2 = w:GetBoundingBox()
	if x1 == nil or (x1 == 0 and x2 == 0) then
		return nil
	end
	local ax, ay = root:TransformFromWorld(w:TransformToWorld(x1, y1))
	local bx, by = root:TransformFromWorld(w:TransformToWorld(x2, y2))
	return math.min(ax, bx), math.min(ay, by), math.max(ax, bx), math.max(ay, by)
end

-- from's local x -> to's local x
local function LocalX(to, from, x)
	local wx, wy = from:TransformToWorld(x, 0)
	local lx = to:TransformFromWorld(wx, wy)
	return lx
end

-- Room for the name's letters over the portrait (in the name text's units).
-- The name starts at the portrait's left edge, and ends name_margin before its
-- right edge, where the health bar starts. Right-side HUDs mirror that: the
-- bar is on the left there, so the name starts name_margin in and may run to
-- the portrait's right edge (the game put the name's box, weapon badge + 160,
-- at the portrait's right edge, and a long name's class badge went past it,
-- off the screen).
local function NameRoom(status)
	local uname = status.username
	local text = uname ~= nil and uname.name_text or nil
	local portrait = status.portrait
	local w = text ~= nil and rawget(text, "w") or nil
	if text == nil or portrait == nil or type(w) ~= "number" or w <= 0 then
		return nil
	end
	local frame = rawget(portrait, "bg") or portrait
	local root = status.root or uname.parent
	local margin = Num(Core.settings.hud.name_margin, 10)
	local right_side = IsRightStatus(status)
	if root ~= nil and uname.weapon_widget ~= nil then
		local fx1 = Box(root, frame)
		local wx1 = Box(root, uname.weapon_widget)
		if fx1 ~= nil and wx1 ~= nil then
			local want = right_side and fx1 + margin or fx1
			if math.abs(wx1 - want) > 0.5 then
				uname:Offset(want - wx1, 0)
			end
		end
	end
	local x1, _, x2 = frame:GetBoundingBox()
	if x1 == nil or x1 == x2 then
		return nil
	end
	local fx2 = math.max(LocalX(text, frame, x1), LocalX(text, frame, x2))
	local badge = uname.skillslots_badge
	local room = (badge ~= nil and badge:IsShown()) and (6 + (badge.skillslots_size or 40)) or 0
	local right = math.min(w / 2, fx2 - room - (right_side and 0 or margin))
	return right + w / 2 -- the letters start at the box's left edge
end
Hud.NameRoom = NameRoom

-- what shows of the name: weapon badge, the letters (the name's box is 160
-- wide whatever the name), the game's "...", the class badge
local function NameBox(status)
	local root, uname = status.root, status.username
	local x1, y1, x2, y2
	local function Add(a, b, c, d)
		if a ~= nil then
			x1 = x1 ~= nil and math.min(x1, a) or a
			y1 = y1 ~= nil and math.min(y1, b) or b
			x2 = x2 ~= nil and math.max(x2, c) or c
			y2 = y2 ~= nil and math.max(y2, d) or d
		end
	end
	local wb = uname.weapon_widget
	if wb ~= nil and wb:IsShown() then
		Add(Box(root, wb))
	end
	local text = uname.name_text
	local tw = text ~= nil and text.inst ~= nil and text.inst.TextWidget or nil
	if tw ~= nil and tw.GetRenderBounds ~= nil then
		local rx1, ry1, rx2, ry2 = tw:GetRenderBounds()
		if type(rx1) == "number" and type(rx2) == "number" and rx2 > rx1 then
			local ax, ay = root:TransformFromWorld(text:TransformToWorld(rx1, ry1))
			local bx, by = root:TransformFromWorld(text:TransformToWorld(rx2, ry2))
			Add(math.min(ax, bx), math.min(ay, by), math.max(ax, bx), math.max(ay, by))
		end
	end
	if uname.ellipsis ~= nil and uname.ellipsis:IsShown() then
		Add(Box(root, uname.ellipsis))
	end
	local badge = uname.skillslots_badge
	if badge ~= nil and badge:IsShown() and badge.skillslots_bg ~= nil then
		Add(Box(root, badge.skillslots_bg))
	end
	if x1 == nil then
		return Box(root, uname)
	end
	return x1, y1, x2, y2
end

function Hud.ClearNameFromBar(status)
	local bar, root = status.health_bar, status.root
	if bar == nil or root == nil or status.username == nil or Core.settings.hud.bar_clears_name == false then
		return 0
	end
	local nx1, _, nx2 = NameBox(status)
	local bx1, _, bx2 = Box(root, bar)
	if nx1 == nil or bx1 == nil then
		return 0
	end
	local gap = Num(Core.settings.hud.bar_gap, 10)
	local shift = 0
	if IsRightStatus(status) then
		if bx2 > nx1 - gap then
			shift = (nx1 - gap) - bx2 -- the bar is left of the name
		end
	elseif bx1 < nx2 + gap then
		shift = (nx2 + gap) - bx1 -- the bar is right of the name
	end
	if shift ~= 0 then
		bar:Offset(shift, 0)
		if status.extra_lives ~= nil then
			status.extra_lives:Offset(shift, 0)
		end
	end
	status.skillslots_bar_shift = math.abs(shift)
	return shift
end

-- The extra lives (the wings + "x2" under the health bar's start) sat right
-- where the cluster's top row (RS / RT) is: hidden behind the skill circles.
-- Cluster layout: they go at the bar's end, on its line (before its start on
-- right-side HUDs, where the bar runs the other way).
function Hud.PlaceLives(status)
	local lives, bar = status.extra_lives, status.health_bar
	status.skillslots_lives_w = nil
	if lives == nil or bar == nil or not ClusterOn(status.owner) or Core.settings.hud.lives_after_bar == false then
		return false
	end
	local gap = Num(Core.settings.hud.lives_gap, 12)
	if IsRightStatus(status) then
		lives:LayoutBounds("before", "center", bar):Offset(-gap, 0)
	else
		lives:LayoutBounds("after", "center", bar):Offset(gap, 0)
	end
	if not lives:IsShown() then
		return false
	end
	local w = lives.GetScaledSize ~= nil and lives:GetScaledSize() or nil
	status.skillslots_lives_w = (type(w) == "number" and w > 0) and (w + gap) or nil
	return true
end

-- the dark frame behind: as wide as the shifted bar (and the lives after it)
-- need (the game sizes it from the bar's width and the power rows' width,
-- plus room for the portrait)
function Hud.WidenFrame(status, allow_weapontips)
	local d = (rawget(status, "skillslots_bar_shift") or 0) + (rawget(status, "skillslots_lives_w") or 0)
	local stretch, static = status.bg_stretch, status.bg_static
	if d <= 0 or stretch == nil or static == nil or status.health_bar == nil or status.player_powers == nil then
		return
	end
	local w, h = stretch:GetSize()
	local health_w = status.health_bar:GetScaledSize()
	local powers_w = status.player_powers:GetScaledSize()
	if status.want_weapontips and allow_weapontips and status.weapontips ~= nil then
		powers_w = powers_w + status.weapontips:GetSize() + 25
	end
	local game = math.max(health_w, powers_w)
	local need = math.max(health_w + d, powers_w)
	if need > game and type(w) == "number" and w > 0 then
		local scale = (game + 175) / w -- the game's BG_SCALE
		stretch:SetSize((need + 175) / scale, h)
			:LayoutBounds("after", "top", static)
	end
end

local function FitStatusName(status)
	local uname = status.username
	if uname == nil or uname.name_text == nil then
		return
	end
	local avail = nil
	if ClusterOn(status.owner) and Core.settings.hud.name_fit ~= false then
		avail = NameRoom(status)
	end
	if avail ~= nil and avail > 0 then
		uname.skillslots_fit_avail = avail
		Hud.FitName(uname, avail)
	else
		uname.skillslots_fit_avail = nil
		Hud.UnfitName(uname)
	end
	PlaceBadge(uname)
end

-- More than one player has a status on screen (the halves are shared).
function Hud.OtherPlayers()
	local all = rawget(_G, "AllPlayers")
	return type(all) == "table" and #all > 1
end

-- The town's weapon tips go right past the cluster, level with its top (its
-- bottom on the bottom HUDs). Not past the extra lives at the bar's end: the
-- game hides the health bar while the tips show (playerstatuswidget.lua: "gives
-- a lot more space for text"), and following the lives there put the tips in the
-- middle of the screen (0.14.0). The cluster's top is below the name's line, where
-- the lives stay. With more than one player the tips also stay in their own half:
-- tips that would reach past the middle are drawn smaller to fit.
function Hud.FitTips(status, right, anchor, gap, bottom)
	local tips = status.weapontips
	local h, v = right and "before" or "after", bottom and "bottom" or "top"
	tips:SetScale(1)
	tips:LayoutBounds(h, v, anchor)
		:Offset(right and -gap or gap, 0)
	if not Hud.OtherPlayers() or tips.GetVirtualBoundingBox == nil then
		return 1
	end
	local x1, _, x2 = tips:GetVirtualBoundingBox()
	if x1 == nil or x2 == nil or x2 <= x1 then
		return 1
	end
	local margin = Num(Core.settings.hud.tips_margin, 30)
	local w = x2 - x1
	local avail = right and (x2 - margin) or (-margin - x1)
	if avail >= w then
		return 1
	end
	local k = math.max(Num(Core.settings.hud.tips_min_scale, 0.5), avail / w)
	tips:SetScale(k)
	tips:LayoutBounds(h, v, anchor) -- still level with the cluster's top (bottom)
		:Offset(right and -gap or gap, 0)
	return k
end

local function AfterStatusLayout(status)
	UpdateBadge(status)
	local ok_fit, err = pcall(FitStatusName, status)
	if not ok_fit and errors < 5 then
		errors = errors + 1
		Core.Log("HUD name fit: " .. tostring(err))
	end
	local relayout = false
	local ok, shift = pcall(Hud.ClearNameFromBar, status)
	if ok and shift ~= 0 then
		relayout = true
	end
	local ok_lives, moved = pcall(Hud.PlaceLives, status)
	if ok_lives and moved then
		relayout = true
	end
	if status.weapontips ~= nil and status.player_powers ~= nil and ClusterOn(status.owner) then
		local right = IsRightStatus(status)
		local gap = Num(Core.settings.hud.tips_gap, 25)
		local bottom = status.layout_mode == "BOTTOM_LEFT" or status.layout_mode == "BOTTOM_RIGHT"
		-- right past the cluster (see Hud.FitTips)
		local ok_fit, fit_err = pcall(Hud.FitTips, status, right, status.player_powers, gap, bottom)
		if not ok_fit and errors < 5 then
			errors = errors + 1
			Core.Log("HUD weapon tips: " .. tostring(fit_err))
		end
		relayout = true
	end
	if relayout and status._LayoutBg ~= nil then
		status:_LayoutBg(status.weapontips ~= nil and status.weapontips:IsShown())
	end
end
Hud.AfterStatusLayout = AfterStatusLayout

-- The weapon tips in camp (widgets/ftf/weapontips.lua) come in where Skill
-- Slots puts the extra lives (the bar's end; the game hides the bar for the
-- tips and nothing for the lives, which stayed drawn over the tips' text).
-- While the tips are in, the lives are drawn see-through. Not hidden: the
-- game's counter shows itself again every frame and, when it finds itself
-- hidden, lays out the whole HUD again each frame (the old stutter Fast Load
-- fixes), so only its colour's alpha changes, which it never touches.
function Hud.TipsLives(tips, showing)
	local root = tips ~= nil and tips.parent or nil
	local status = root ~= nil and root.parent or nil
	local lives = status ~= nil and rawget(status, "extra_lives") or nil
	if lives == nil or lives.SetMultColorAlpha == nil then
		return false
	end
	if showing then
		-- only where this mod moved them (the cluster layout, lives_after_bar)
		if not ClusterOn(status.owner) or Core.settings.hud.lives_after_bar == false then
			return false
		end
		lives:SetMultColorAlpha(0)
		rawset(lives, "skillslots_tips_hid", true)
	elseif rawget(lives, "skillslots_tips_hid") then
		lives:SetMultColorAlpha(1)
		rawset(lives, "skillslots_tips_hid", nil)
	end
	return true
end

Hud.TIPS_FADE = 0.35 -- the game's tips fade out in 0.33 s: the lives come back after it

function Hud.HookTips(WeaponTips)
	if type(WeaponTips) ~= "table" or type(WeaponTips.AnimateIn) ~= "function" or type(WeaponTips.AnimateOut) ~= "function" then
		return false
	end
	if rawget(WeaponTips, "skillslots_lives_hook") then
		return true
	end
	local orig_in, orig_out = WeaponTips.AnimateIn, WeaponTips.AnimateOut
	WeaponTips.AnimateIn = function(self, ...)
		local results = table.pack(orig_in(self, ...))
		rawset(self, "skillslots_tips_seq", (rawget(self, "skillslots_tips_seq") or 0) + 1)
		local ok, err = pcall(Hud.TipsLives, self, true)
		if not ok and errors < 5 then
			errors = errors + 1
			Core.Log("HUD lives under the tips: " .. tostring(err))
		end
		return table.unpack(results, 1, results.n)
	end
	WeaponTips.AnimateOut = function(self, ...)
		local results = table.pack(orig_out(self, ...))
		local seq = (rawget(self, "skillslots_tips_seq") or 0) + 1
		rawset(self, "skillslots_tips_seq", seq)
		local function Back()
			-- not if the tips came back in meanwhile
			if rawget(self, "skillslots_tips_seq") == seq then
				pcall(Hud.TipsLives, self, false)
			end
		end
		local inst = self.inst
		if inst ~= nil and inst.DoTaskInTime ~= nil then
			local ok = pcall(inst.DoTaskInTime, inst, Hud.TIPS_FADE, Back)
			if not ok then
				Back()
			end
		else
			Back()
		end
		return table.unpack(results, 1, results.n)
	end
	rawset(WeaponTips, "skillslots_lives_hook", true)
	return true
end

local late_done = false
-- Hooked when the first player spawns (the game is fully loaded then).
function Hud.LateInstall()
	if late_done then
		return
	end
	late_done = true
	local hooked = {}
	local ok1, PSW = pcall(require, "widgets/ftf/playerstatuswidget")
	if ok1 and type(PSW) == "table" and type(PSW._Layout) == "function" then
		local orig = PSW._Layout
		PSW._Layout = function(self, ...)
			local results = table.pack(orig(self, ...))
			local ok, err = pcall(AfterStatusLayout, self)
			if not ok and errors < 5 then
				errors = errors + 1
				Core.Log("HUD name badge / weapon tips: " .. tostring(err))
			end
			return table.unpack(results, 1, results.n)
		end
		hooked[#hooked + 1] = "frame"
		if type(PSW._LayoutBg) == "function" then
			local orig_bg = PSW._LayoutBg
			PSW._LayoutBg = function(self, allow, ...)
				local results = table.pack(orig_bg(self, allow, ...))
				local ok, err = pcall(Hud.WidenFrame, self, allow)
				if not ok and errors < 5 then
					errors = errors + 1
					Core.Log("HUD frame width: " .. tostring(err))
				end
				return table.unpack(results, 1, results.n)
			end
		end
	end
	local ok2, PUW = pcall(require, "widgets/ftf/playerusernamewidget")
	if ok2 and type(PUW) == "table" and type(PUW._Layout) == "function" then
		local orig = PUW._Layout
		PUW._Layout = function(self, ...)
			local results = table.pack(orig(self, ...))
			-- the game's RefreshName puts the whole name back (a name change): fit it again
			local avail = rawget(self, "skillslots_fit_avail")
			if avail ~= nil then
				pcall(Hud.FitName, self, avail)
			end
			if self.skillslots_badge ~= nil then
				pcall(PlaceBadge, self)
			end
			return table.unpack(results, 1, results.n)
		end
		hooked[#hooked + 1] = "name"
	end
	local ok3, WT = pcall(require, "widgets/ftf/weapontips")
	if ok3 then
		local ok_hook, did = pcall(Hud.HookTips, WT)
		if not (ok_hook and did) then
			Core.Log("HUD lives under the tips: the game's way (weapon tips changed)")
		end
	end
	if #hooked < 2 then
		Core.Log("HUD frame hooks: " .. (#hooked > 0 and table.concat(hooked, ", ") or "none") .. " (cluster badge / tips may be missing)")
	end
	return hooked
end

local function SafeReconcile(self)
	local ok, err = pcall(Reconcile, self)
	if not ok and errors < 5 then
		errors = errors + 1
		Core.Log("HUD error: " .. tostring(err))
	end
end

function Hud.Install()
	orig_SetSkill = PlayerPowersWidget.SetSkill
	orig_RemoveSkill = PlayerPowersWidget.RemoveSkill
	orig_PositionPowers = PlayerPowersWidget._PositionPowers
	orig_ctor = PlayerPowersWidget._ctor
	assert(type(orig_SetSkill) == "function", "PlayerPowersWidget.SetSkill")
	assert(type(orig_RemoveSkill) == "function", "PlayerPowersWidget.RemoveSkill")
	assert(type(orig_PositionPowers) == "function", "PlayerPowersWidget._PositionPowers")
	assert(type(orig_ctor) == "function", "PlayerPowersWidget._ctor")

	-- (bulletproofing: an error working out an icon: logged, the game's way)
	local G = Core.G or require("skillslots.guard").Shared(Core.TAG or "[Skill Slots]")
	local function ShowsSkill(self, skill)
		if not Core.IsActive(self.owner) then
			return nil -- the game's way
		end
		local def = skill ~= nil and skill.GetDef ~= nil and skill:GetDef() or nil
		return def == nil or Shows(self, def.name)
	end
	PlayerPowersWidget.SetSkill = function(self, skill, fresh, ...)
		local ok, shows = G.Call("HUD skill icon", ShowsSkill, self, skill)
		if not ok or shows == nil then
			return orig_SetSkill(self, skill, fresh, ...)
		end
		local ret
		if shows then
			ret = orig_SetSkill(self, skill, fresh, ...)
		end
		SafeReconcile(self)
		return ret
	end

	-- vanilla removes an arbitrary skill icon here; remove the right one instead
	PlayerPowersWidget.RemoveSkill = function(self, ...)
		local ok, active = G.Call("HUD skill icon", Core.IsActive, self.owner)
		if not ok or not active then
			return orig_RemoveSkill(self, ...)
		end
		SafeReconcile(self)
	end

	PlayerPowersWidget._PositionPowers = function(self, ...)
		local ret = orig_PositionPowers(self, ...)
		if self.skillslots_row ~= nil or self.skillslots_hid_weight or ClusterOn(self.owner) then
			local ok, err = pcall(PositionRow, self)
			if not ok and errors < 5 then
				errors = errors + 1
				Core.Log("HUD layout error: " .. tostring(err))
			end
		end
		return ret
	end

	PlayerPowersWidget._ctor = function(self, owner, ...)
		orig_ctor(self, owner, ...)
		local ok, active = G.Call("HUD", Core.IsActive, owner)
		if ok and active then
			self.inst:ListenForEvent("skillslots_changed", function()
				SafeReconcile(self)
			end, owner)
			SafeReconcile(self)
		end
	end
end

return Hud
