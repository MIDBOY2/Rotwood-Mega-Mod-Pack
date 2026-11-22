-- Tonic Swap: tonic numbers and text.
--  * Spicy Pumpkin Seeds (tonic_rage): the game multiplies your damage by
--    damage / 100 for 5 seconds (1000 = ten times). tonic_rage_damage sets it
--    (200 = double), and the description says it plainly: "Deal 200% Damage
--    for 5 seconds." (the game's "+1000%" was really ten times).
--  * Battoad Eggs (tonic_projectile_repeat): each projectile's damage
--    (tonic_eggs_damage; the game: 50).
--  * The tonics' powers start their names and descriptions with "[TEMP] "
--    (unfinished text): tonic_clean_text takes it off.
-- The game puts every text back from its text database when it sets the
-- language (after the mods load), so new text goes into that database too.
local Power = require "defs.powers"

local Tune = {}

Tune.RAGE = "tonic_rage"
Tune.EGGS = "tonic_projectile_repeat"
Tune.RAGE_DESC = "Deal <#RED>{damage}%</> {name.concept_damage} for <#RED>{time}</> seconds."
Tune.TEMP = "^%[TEMP%]%s*"

local function Find(name)
	local ok, pdef = pcall(Power.FindPowerByName, name) -- errors for a missing name
	if not ok or pdef == nil then
		return nil, nil
	end
	local t = pdef.tuning ~= nil and pdef.tuning[Power.Rarity.COMMON] or nil
	return pdef, t
end

-- where a power's text lives: STRINGS.ITEMS.POWERS.<slot>.<name> (the
-- power's pretty table is that table)
function Tune.TextPath(pdef)
	local strings = rawget(_G, "STRINGS")
	local powers = strings ~= nil and strings.ITEMS ~= nil and strings.ITEMS.POWERS or nil
	if powers == nil or type(pdef.pretty) ~= "table" then
		return nil
	end
	for slot, tbl in pairs(powers) do
		if type(tbl) == "table" and rawget(tbl, pdef.name) == pdef.pretty then
			return "STRINGS.ITEMS.POWERS." .. tostring(slot) .. "." .. pdef.name
		end
	end
	return nil
end

local function SetText(pdef, field, str, entries)
	if type(pdef.pretty) ~= "table" then
		return false
	end
	pdef.pretty[field] = str
	local path = Tune.TextPath(pdef)
	if path ~= nil then
		entries[path .. "." .. field] = str
	end
	return true
end

function Tune.WriteDB(entries)
	local gc = rawget(_G, "TheGameContent")
	local db = gc ~= nil and gc.GetContentDB ~= nil and gc:GetContentDB() or nil
	if db == nil or type(db.strings) ~= "table" then
		return false
	end
	for id, str in pairs(entries) do
		db.strings[id] = str -- (not AddString: it asserts on a second load)
	end
	return true
end

-- s: the settings; tonics: the tonic item defs (their powers get clean text).
-- Returns what was done and what couldn't be.
function Tune.Install(s, tonics)
	local done, problems, entries = {}, {}, {}

	local rage_damage = tonumber(s.tonic_rage_damage)
	if rage_damage ~= nil and rage_damage > 0 then
		local pdef, t = Find(Tune.RAGE)
		if t ~= nil and type(t.damage) == "number" then
			t.damage = rage_damage
			SetText(pdef, "desc", Tune.RAGE_DESC, entries)
			done[#done + 1] = string.format("Spicy Pumpkin Seeds %g%% damage", rage_damage)
		else
			problems[#problems + 1] = Tune.RAGE .. " not found (its damage left as the game's)"
		end
	end

	local eggs_damage = tonumber(s.tonic_eggs_damage)
	if eggs_damage ~= nil and eggs_damage > 0 then
		local _, t = Find(Tune.EGGS)
		if t ~= nil and type(t.damage) == "number" then
			t.damage = eggs_damage
			done[#done + 1] = string.format("Battoad Eggs %g a projectile", eggs_damage)
		else
			problems[#problems + 1] = Tune.EGGS .. " not found (its damage left as the game's)"
		end
	end

	if s.tonic_clean_text ~= false then
		local cleaned, seen = 0, {}
		for _, def in ipairs(type(tonics) == "table" and tonics or {}) do
			local name = def.usage_data ~= nil and def.usage_data.power or nil
			local pdef = name ~= nil and not seen[name] and Find(name) or nil
			if pdef ~= nil and type(pdef.pretty) == "table" then
				seen[name] = true
				for _, field in ipairs({ "name", "desc" }) do
					local v = pdef.pretty[field]
					if type(v) == "string" and v:find(Tune.TEMP) then
						SetText(pdef, field, (v:gsub(Tune.TEMP, "")), entries)
						cleaned = cleaned + 1
					end
				end
			end
		end
		if cleaned > 0 then
			done[#done + 1] = "[TEMP] off " .. cleaned .. " tonic texts"
		end
	end

	if next(entries) ~= nil and not Tune.WriteDB(entries) then
		problems[#problems + 1] = "the game's text database not found (some text may show the game's)"
	end
	return done, problems
end

----------------------------------------------------------------------------
-- The status panel (the player status button: your loadout over your head).
--  * look: its potion slot gets the blue patterned background of an item slot
--    (the game: a plain dark square) and a bigger bottle (scale).
--  * full: the potion's full picture even with no drinks left (the game shows
--    the empty bottle; the count still shows 0). Off by default.
-- The game loads the status panel's widget as "widgets.ftf.playerloadoutwidget"
-- (0.4.9 hooked "widgets/ftf/playerloadoutwidget", a separate copy of the file
-- the game never uses: nothing showed).

Tune.SLOT_BG = "images/ui_ftf_shop/inventory_slot_rare.tex" -- the blue item-slot pattern
Tune.SLOT_MASK = "images/ui_ftf_shop/inventory_slot_bg.tex" -- the slot's shape (like the game's item slots)
Tune.status = { look = true, scale = 1.35, full = false }

function Tune.FullPicture(widget)
	local def = widget.equipped_potion_def
	local icon = def ~= nil and def.ui_icons ~= nil and def.ui_icons.ready or nil
	if icon ~= nil and widget.potion_icon ~= nil and widget.texture_name ~= icon then
		widget.texture_name = icon
		widget.potion_icon:SetTexture(icon)
	end
end

-- the bottle (and tonic) at the bigger size; the slot (background, its shape) at the slot's
function Tune.SizeLook(w)
	local size = type(w.size) == "number" and w.size or 132
	local big = size * Tune.status.scale
	if w.potion_icon ~= nil then
		w.potion_icon:SetSize(big, big)
	end
	if w.tonic_icon ~= nil then
		w.tonic_icon:SetSize(big * 0.33, big * 0.33)
	end
	if w.bg ~= nil then
		w.bg:SetSize(size, size)
	end
	local mask = rawget(w, "tonicswap_mask")
	if mask ~= nil then
		mask:SetSize(size, size)
	end
end

function Tune.PlaceMask(w)
	local mask = rawget(w, "tonicswap_mask")
	if mask ~= nil and w.potion_icon ~= nil then
		mask:LayoutBounds("center", "center", w.potion_icon)
	end
end

function Tune.ApplyLook(w)
	if rawget(w, "tonicswap_look") then
		return
	end
	rawset(w, "tonicswap_look", true)
	if w.bg == nil and w.ShowBackground ~= nil then
		w:ShowBackground()
	end
	if w.bg == nil then
		return
	end
	local Image = require "widgets.image"
	local mask = w:AddChild(Image(Tune.SLOT_MASK))
	mask:SetMask()
	rawset(w, "tonicswap_mask", mask)
	w.bg:SetTexture(Tune.SLOT_BG)
	w.bg:SetMultColor(UICOLORS.WHITE)
	w.bg:SetMasked()
	-- drawn first: the shape, then the pattern inside it, then the bottle
	w.bg:SendToBack()
	mask:SendToBack()
	Tune.SizeLook(w)
	w:Layout()
end

local function HookPotionWidget(PotionWidget)
	if rawget(PotionWidget, "tonicswap_status_hooked") then
		return true
	end
	rawset(PotionWidget, "tonicswap_status_hooked", true)
	local orig_uses = PotionWidget.RefreshUses
	PotionWidget.RefreshUses = function(self, ...)
		local results = table.pack(orig_uses(self, ...))
		if rawget(self, "tonicswap_full_picture") then
			pcall(Tune.FullPicture, self)
		end
		return table.unpack(results, 1, results.n)
	end
	local orig_size = PotionWidget.SetSize
	PotionWidget.SetSize = function(self, ...)
		local results = table.pack(orig_size(self, ...))
		if rawget(self, "tonicswap_look") then
			pcall(Tune.SizeLook, self)
			pcall(self.Layout, self)
		end
		return table.unpack(results, 1, results.n)
	end
	local orig_tonic = PotionWidget.MakeTonicIcon
	PotionWidget.MakeTonicIcon = function(self, ...)
		local results = table.pack(orig_tonic(self, ...))
		if rawget(self, "tonicswap_look") then
			pcall(Tune.SizeLook, self)
			pcall(self.Layout, self)
		end
		local status = rawget(self, "tonicswap_hud")
		if status ~= nil and status._LayoutBg ~= nil then
			pcall(status._LayoutBg, status, status.weapontips ~= nil and status.weapontips:IsShown())
		end
		return table.unpack(results, 1, results.n)
	end
	local orig_layout = PotionWidget.Layout
	PotionWidget.Layout = function(self, ...)
		local results = table.pack(orig_layout(self, ...))
		if rawget(self, "tonicswap_look") then
			pcall(Tune.PlaceMask, self)
		end
		return table.unpack(results, 1, results.n)
	end
	return true
end

local function HookLoadout(Loadout)
	if type(Loadout) ~= "table" or type(Loadout._ctor) ~= "function" or rawget(Loadout, "tonicswap_status_hooked") then
		return false
	end
	rawset(Loadout, "tonicswap_status_hooked", true)
	local orig_ctor = Loadout._ctor
	Loadout._ctor = function(self, ...)
		orig_ctor(self, ...)
		local w = rawget(self, "potion_widget")
		if w ~= nil then
			if Tune.status.look then
				local ok, err = pcall(Tune.ApplyLook, w)
				if not ok then
					print("[Tonic Swap] status panel potion look: " .. tostring(err))
				end
			end
			if Tune.status.full then
				rawset(w, "tonicswap_full_picture", true)
				pcall(Tune.FullPicture, w)
			end
		end
	end
	return true
end

-- s: the settings. Returns true when hooked.
function Tune.InstallStatusPotion(s)
	s = s or {}
	Tune.status.look = s.status_potion_look ~= false
	Tune.status.full = s.status_potion_full == true
	local scale = tonumber(s.status_potion_scale)
	Tune.status.scale = (scale ~= nil and scale > 0.5 and scale < 2) and scale or 1.35
	local ok1, PotionWidget = pcall(require, "widgets/ftf/potionwidget")
	if not ok1 or type(PotionWidget) ~= "table" or type(PotionWidget.RefreshUses) ~= "function"
		or type(PotionWidget.SetSize) ~= "function" or type(PotionWidget.Layout) ~= "function"
		or type(PotionWidget.MakeTonicIcon) ~= "function" then
		return false
	end
	HookPotionWidget(PotionWidget)
	-- the game's own name for it (playerfollowstatus.lua), and the other spelling if loaded
	local hooked = false
	local ok2, Loadout = pcall(require, "widgets.ftf.playerloadoutwidget")
	if ok2 and HookLoadout(Loadout) then
		hooked = true
	end
	local package_lib = rawget(_G, "package")
	local other = package_lib ~= nil and package_lib.loaded ~= nil and package_lib.loaded["widgets/ftf/playerloadoutwidget"] or nil
	if other ~= nil and other ~= Loadout and HookLoadout(other) then
		hooked = true
	end
	return hooked or (ok2 and type(Loadout) == "table" and rawget(Loadout, "tonicswap_status_hooked") == true)
end

----------------------------------------------------------------------------
-- The HUD (your panel in the corner): the potion sits at the bottom of the
-- dark frame, and its tonic icon (bottom right of the bottle) stuck out past
-- the frame's slanted corner. The frame's left piece (UI_HUD_BG_root2, plain
-- see-through black with that slanted corner) is made just wide enough for
-- the corner to clear the tonic, and the band to its right (UI_HUD_BG_stretch2)
-- is shortened by as much, so the frame ends where it always did. Nothing is
-- stacked: the frame is see-through, and 0.5.2's extra piece behind it showed
-- as a darker block (twice the black) with a lighter, long tail (the band's
-- art fades out towards its bottom). On right-side HUDs the frame is
-- mirrored, and so is this.

Tune.BACKING = { margin = 6, corner = 137 / 158 } -- corner: the piece's bottom edge, as a share of its width

local function BoxIn(space, w)
	local x1, y1, x2, y2 = w:GetBoundingBox()
	if x1 == nil then
		return nil
	end
	local xs, ys = {}, {}
	for _, c in ipairs({ { x1, y1 }, { x2, y2 }, { x1, y2 }, { x2, y1 } }) do
		local wx, wy = w:TransformToWorld(c[1], c[2])
		local lx, ly = space:TransformFromWorld(wx, wy)
		xs[#xs + 1], ys[#ys + 1] = lx, ly
	end
	return math.min(table.unpack(xs)), math.min(table.unpack(ys)), math.max(table.unpack(xs)), math.max(table.unpack(ys))
end
Tune.BoxIn = BoxIn

-- the left piece's own size and place (before any widening)
local function Original(status, static)
	local o = rawget(status, "tonicswap_static0")
	if o == nil then
		local w0, h0 = static:GetSize()
		local x0, y0 = static:GetPosition()
		if type(w0) ~= "number" or type(h0) ~= "number" then
			return nil
		end
		o = { w = w0, h = h0, x = x0 or 0, y = y0 or 0 }
		rawset(status, "tonicswap_static0", o)
	end
	return o
end

-- Runs right after the game's _LayoutBg (the band at the game's width).
-- Returns the extra width given to the left piece (0 = the game's frame).
function Tune.ExtendBacking(status)
	local w, bg, static, band = status.potion_widget, status.bg, status.bg_static, status.bg_stretch
	local old = rawget(status, "tonicswap_backing") -- (0.5.2's piece, if a HUD still has one)
	if old ~= nil and old.Hide ~= nil then
		old:Hide()
	end
	if bg == nil or static == nil then
		return 0
	end
	local o = Original(status, static)
	if o == nil then
		return 0
	end
	if w ~= nil then
		rawset(w, "tonicswap_hud", status)
	end
	local extra = 0
	local tonic = w ~= nil and w:IsShown() and w.tonic_icon or nil
	if tonic ~= nil and tonic:IsShown() then
		local _, _, tx2 = BoxIn(bg, tonic)
		local sx1 = BoxIn(bg, static) -- the piece's left edge (it stays put)
		sx1 = sx1 or (o.x - o.w / 2)
		if tx2 ~= nil then
			local need = (tx2 + Tune.BACKING.margin - sx1) / Tune.BACKING.corner
			extra = math.max(0, need - o.w)
		end
	end
	static:SetSize(o.w + extra, o.h)
	static:SetPosition(o.x + extra / 2, o.y) -- the left edge stays put
	if band ~= nil and band.GetSize ~= nil then
		local bw, bh = band:GetSize()
		if type(bw) == "number" and extra > 0 then
			band:SetSize(math.max(bw - extra, 130), bh)
		end
		band:LayoutBounds("after", "top", static)
	end
	return extra
end

function Tune.InstallHudBacking()
	local ok, PSW = pcall(require, "widgets/ftf/playerstatuswidget")
	if not ok or type(PSW) ~= "table" or type(PSW._LayoutBg) ~= "function" then
		return false
	end
	if rawget(PSW, "tonicswap_backing_hooked") then
		return true
	end
	rawset(PSW, "tonicswap_backing_hooked", true)
	local orig = PSW._LayoutBg
	local errors = 0
	PSW._LayoutBg = function(self, ...)
		local results = table.pack(orig(self, ...))
		local ok2, err = pcall(Tune.ExtendBacking, self)
		if not ok2 and errors < 3 then
			errors = errors + 1
			print("[Tonic Swap] HUD frame behind the tonic: " .. tostring(err))
		end
		return table.unpack(results, 1, results.n)
	end
	return true
end

return Tune
