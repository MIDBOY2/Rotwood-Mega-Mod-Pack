-- Armor Dyes (0.5.6): tint palettes. A palette gives each material of a piece its own colour (main,
-- second, third, fourth, accent, dark, light, metal), learned from the elite boss looks or made around
-- colours (palettedefs.lua). No new art: each picture (symbol) of a piece gets one live colour shift
-- (AnimState:SetSymbolColorShift, the same call as every other dye here) that takes the colour of the
-- picture's main material (tintdata.lua, read once from the game's art by tintdata.py) onto the
-- palette's colour for that material's role. Pictures of one piece can take different palette
-- colours; inside one picture every colour turns together.
--
-- The arithmetic matches kit/tools/palettes/tint_palette_preview.py (the preview pictures):
--   hue turn = palette hue - material hue; saturation x = palette / material (at most 3, an accent 1.6);
--   brightness x = palette / material (a colour keeps 35% of the art's own lightness; greys, whites,
--   darks keep half);
--   then no blown-out colours: the picture's three strongest colours are checked where the shift takes
--   them (OKLab chroma). The material itself may reach the palette colour; every other colour stays as
--   strong as it was at most, and none goes past the game's own armour at the hue it lands on
--   (dyedata.py CAP_BINS). Worked out once per piece and palette, then kept.

local Palettes = {}

Palettes.PREFIX = "pal_" -- the dye key: armordye_pal_<palette>
Palettes.ORDER = 600 -- after the mod's other dyes in a piece's list
Palettes.ROLES = { "main", "second", "third", "fourth", "accent", "dark", "light", "metal" }
Palettes.list = {}
Palettes.by_key = {}
Palettes.tint = nil
Palettes.cache = {}
Palettes.CAP_K = 1.0
Palettes.KEEP_LIGHT = 0.35
Palettes.MAX_KS = 3.0
Palettes.ACCENT_KS = 1.6

-- the most saturated the game's own armour gets per 30 degrees of OKLCh hue (dyedata.py)
local CAP_BINS = { 0.194, 0.137, 0.135, 0.169, 0.179, 0.076, 0.101, 0.088, 0.070, 0.080, 0.123, 0.203 }

local function Clamp(x, a, b)
	if x < a then
		return a
	end
	if x > b then
		return b
	end
	return x
end

local function Cap(hdeg)
	local x = (hdeg % 360) / 30 - 0.5
	local fl = math.floor(x)
	local f = x - fl
	local i0 = fl % 12
	return (CAP_BINS[i0 + 1] * (1 - f) + CAP_BINS[(i0 + 1) % 12 + 1] * f) * Palettes.CAP_K
end

local function HexRGB(hex)
	if type(hex) ~= "string" or #hex ~= 6 then
		return nil
	end
	local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	if r == nil or g == nil or b == nil then
		return nil
	end
	return r / 255, g / 255, b / 255
end

local function RGBtoHSV(r, g, b)
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 1e-9 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	local s = mx > 1e-9 and d / mx or 0
	return h, s, mx
end

local function HSVtoRGB(h, s, v)
	h = (h % 1) * 6
	local i = math.floor(h) % 6
	local f = h - math.floor(h)
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	end
	return v, p, q
end

local function Lin(c)
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Cbrt(x)
	return x > 0 and x ^ (1 / 3) or 0
end

local Atan2 = math.atan2 or math.atan -- (math.atan takes y, x from Lua 5.3)

-- OKLab (Ottosson) chroma and hue in degrees
local function OKLCh(r, g, b)
	r, g, b = Lin(r), Lin(g), Lin(b)
	local l = Cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
	local m = Cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
	local s = Cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
	local A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	local B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	local hdeg = math.deg(Atan2(B, A)) % 360
	return math.sqrt(A * A + B * B), hdeg
end
Palettes.OKLCh = OKLCh

local function HueGap(a, b)
	return math.abs((a - b + 180) % 360 - 180)
end

-- one picture's entry from tintdata.lua: { role, kind, h, s, v, { hot h, s, v, ... } }, or nil
local function GoodEntry(e)
	if type(e) ~= "table" or type(e[1]) ~= "string" or type(e[2]) ~= "string" then
		return false
	end
	for i = 3, 5 do
		if type(e[i]) ~= "number" then
			return false
		end
	end
	return e[6] == nil or type(e[6]) == "table"
end

-- The colour shift { hue turn, saturation x, brightness x } for one picture and one palette, or nil.
function Palettes.Shift(e, pal)
	if not GoodEntry(e) or type(pal) ~= "table" then
		return nil
	end
	local role, kind, h, s, v = e[1], e[2], e[3], e[4], e[5]
	local hex = pal[role] or pal.main
	local R, G, B = HexRGB(hex)
	if R == nil then
		return nil
	end
	local H, S, V = RGBtoHSV(R, G, B)
	local dh = (H - h) % 1
	local ks = Clamp(S / math.max(s, 0.06), 0, Palettes.MAX_KS)
	if role == "accent" then
		ks = math.min(ks, Palettes.ACCENT_KS)
	end
	if kind == "m" or kind == "l" or kind == "d" or role == "dark" then
		V = 0.5 * V + 0.5 * v
	else
		V = Palettes.KEEP_LIGHT * v + (1 - Palettes.KEEP_LIGHT) * V
	end
	local kb = Clamp(V / math.max(v, 0.06), 0.25, 2.2)
	-- no blown-out colours (see the top)
	local ct = OKLCh(HSVtoRGB(H, S, V))
	local hot = type(e[6]) == "table" and e[6] or {}
	for i = 1, #hot - 2, 3 do
		local hh, hs, hv = tonumber(hot[i]), tonumber(hot[i + 1]), tonumber(hot[i + 2])
		if hh ~= nil and hs ~= nil and hv ~= nil then
			local c0, h0 = OKLCh(HSVtoRGB(hh, hs, hv))
			for _ = 1, 3 do
				local c, hc = OKLCh(HSVtoRGB((hh + dh) % 1, math.min(hs * ks, 1), math.min(hv * kb, 1)))
				local is_mat = math.abs(((hh - h) + 0.5) % 1 - 0.5) < 0.042 and math.abs(hs - s) < 0.15
				local lim = math.min(Cap(hc), c0)
				if is_mat then
					lim = math.max(ct, lim)
				end
				if HueGap(hc, h0) < 30 then
					lim = math.max(lim, c0)
				end
				if c <= lim + 1e-4 or c < 1e-4 then
					break
				end
				ks = ks * lim / c
			end
		end
	end
	return { dh, ks, kb }
end

-- Takes the palette list and the picture data; returns how many palettes are usable.
function Palettes.Init(defs, tint)
	Palettes.list, Palettes.by_key, Palettes.cache = {}, {}, {}
	Palettes.tint = type(tint) == "table" and tint or nil
	if type(defs) ~= "table" or Palettes.tint == nil then
		return 0
	end
	for _, p in ipairs(defs) do
		if type(p) == "table" and type(p.key) == "string" and p.key:match("^[%w_]+$") and type(p.name) == "string"
			and HexRGB(p.main) ~= nil and Palettes.by_key[p.key] == nil then
			Palettes.list[#Palettes.list + 1] = p
			Palettes.by_key[p.key] = p
		end
	end
	return #Palettes.list
end

-- a build's pictures: kind = "armour" / "weapons"
function Palettes.Pictures(kind, build)
	local t = Palettes.tint ~= nil and Palettes.tint[kind] or nil
	local p = type(t) == "table" and type(build) == "string" and t[build] or nil
	return type(p) == "table" and p or nil
end

-- { symbol = shift } for a build in a palette (worked out once, then kept), or nil
function Palettes.ForPiece(kind, build, key)
	local pal = Palettes.by_key[key]
	local pics = Palettes.Pictures(kind, build)
	if pal == nil or pics == nil then
		return nil
	end
	local ck = kind .. "/" .. build
	local per = Palettes.cache[ck]
	if per == nil then
		per = {}
		Palettes.cache[ck] = per
	end
	local m = per[key]
	if m == nil then
		m = {}
		for sym, e in pairs(pics) do
			m[sym] = Palettes.Shift(e, pal)
		end
		per[key] = m
	end
	return m
end

-- does the build have picture data for any of these symbols? (cheap: registering asks this)
function Palettes.HasPictures(kind, build, symbols)
	local pics = Palettes.Pictures(kind, build)
	if pics == nil or type(symbols) ~= "table" then
		return false
	end
	for _, sym in ipairs(symbols) do
		if GoodEntry(pics[sym]) then
			return true
		end
	end
	return false
end

-- the shift a piece falls back on for a picture with no data: its first main-material picture's
-- (in the slot's symbol order), else its first picture with data; nil if none of its pictures has data
function Palettes.PieceShift(kind, build, key, symbols)
	local m = Palettes.ForPiece(kind, build, key)
	local pics = Palettes.Pictures(kind, build)
	if m == nil or type(symbols) ~= "table" then
		return nil
	end
	local first = nil
	for _, sym in ipairs(symbols) do
		if m[sym] ~= nil then
			if pics[sym][1] == "main" then
				return m[sym]
			end
			first = first or m[sym]
		end
	end
	return first
end

return Palettes
