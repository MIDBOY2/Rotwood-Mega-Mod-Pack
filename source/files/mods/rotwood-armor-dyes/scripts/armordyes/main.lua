-- Armor Dyes: the dyes and how they're drawn.
--
-- The game already has a dye system that was never switched on: each player
-- has an equipmentdyer component that remembers one dye per armour piece
-- (slot + armour set) and saves it with the character, and puppets / ghosts /
-- outlines copy it. Klei planned repainted armour files for it; none shipped.
--
-- This mod fills that system with dyes that need no new art: a dye is a colour
-- shift (hue turn, saturation x, brightness x) that the game applies to the
-- armour symbols with AnimState:SetSymbolColorShift, the same call the
-- character creator uses for skin and hair colours. The numbers are worked out
-- per armour set and slot from the game's own armour art (data.lua, made by
-- dyedata.py), so "Moss" looks like the game's moss green on every set.

local Cosmetic = require "defs.cosmetics.cosmetics"
local Equipment = require "defs.equipment"
local Inventory = require "components.inventory"
local EquipmentDyer = require "components.equipmentdyer"

local Main = {}

Main.TAG = "[Armor Dyes]"
Main.PREFIX = "armordye_"
Main.SLOTS = { "HEAD", "BODY", "WAIST" }
Main.settings = nil
Main.count = 0

Main.DEFAULTS = {
	enabled = true,
	dye_tab = true,
	weapon_dyes = true,
	dye_weapon_trails = true, -- (0.5.9) the spear's twirl trail dyed with the spear
	-- (0.5.6) tint palettes: palettes.lua
	palettes = true,
	palette_tab = true,
	palettes_in_lists = false,
	custom_dyes = {},
	new_character_colour = true,
	loadout_dyes = "auto", -- "auto" / "save" / false (0.4.0: loadouts.lua)
	statue_look = true,
	-- (0.5.0) the imbued boss looks: imbued.lua
	imbued = true,
	imbued_alt_looks = true,
	imbued_reference_looks = false, -- (0.5.9) older looks kept to compare (Grimhollow's red lava bow string)
	imbued_mirage = true,
	imbued_icons = true,
	imbued_needs_boss_piece = true,
	debug = false,
}
-- settings that may also be false (off) besides their usual kind of value
Main.MAY_BE_FALSE = { loadout_dyes = true }

-- soft player colour dye key by player number (data.lua dyes with player = n)
Main.soft_by_player = {}
-- character slots of characters just made on the new-character screen
Main.BASIC_SET = "basic"

-- Sets the data has no numbers for (added by a game update, or no art): these
-- work on any colours because they only change saturation / brightness.
Main.FALLBACK = {
	soot = { 0, 0.35, 0.55 },
	iron = { 0, 0.15, 0.85 },
	stone = { 0, 0.12, 1.0 },
	bone = { 0, 0.18, 1.15 },
}

-- Weapon dyes (0.3.0): a WEAPON tab next to HELMET / BODY / LEGS.
-- (0.5.6) Worked out per weapon from the game's weapon art like armour
-- (weapondata.lua, made by weapondata.py): a dye turns the weapon's own colours
-- (the main colour onto the dye's, each colour keeping its lightness and its
-- strength for its hue), so a gem stays a gem and metal stays metal. Weapons
-- also get the colour families (Brick, Moss...) now.
-- A weapon the data doesn't know (added by a game update) still gets the old
-- tint: the weapon's colours mostly greyed (the colour shift's saturation down,
-- brightness up a little) and the symbols multiplied by the dye's colour
-- (AnimState:SetSymbolMultColor). That's what made 0.3.0-0.5.5's weapon
-- colours one flat neon colour.
Main.WEAPON = "WEAPON"
Main.weapon_on = false
Main.weapon_count = 0
Main.WEAPON_TINT = { 0, 0.15, 1.12 } -- the colour shift under a colour dye's tint
Main.WEAPON_SOFT_TINT = { 0, 0.5, 1.05 } -- a soft player colour: more of the weapon's own colour kept
Main.WEAPON_SOFT_MIX = 0.6 -- how far toward the player colour
-- weapon pieces a dye leaves alone: the slash / swing trail, the spear's twirl
-- trail and the shot put ball's shadow (attacks keep their normal look)
Main.WEAPON_KEEP = { wipe = true, fx_spear_twirl01 = true, shadow_untex = true }
-- (0.5.9, user 04:01: "weapon dye does not apply to the smear sprites") with
-- dye_weapon_trails on (the default): the smears drawn in the weapon's own art (the
-- spear's twirl trail) take the weapon's dye. The slash trail ("wipe", in the game's
-- weapon symbol list though in no weapon's art) and the ball's shadow stay as they are.
Main.WEAPON_KEEP_TRAILS = { wipe = true, shadow_untex = true }
function Main.WeaponKeep()
	local s = Main.settings
	if s ~= nil and s.dye_weapon_trails == false then
		return Main.WEAPON_KEEP
	end
	return Main.WEAPON_KEEP_TRAILS
end
-- (The white swing smears every weapon leaves, the player's own smear_weapon_generic01,
-- are never touched: user 14:10, "the white swing stays untouched for all weapons".)

-- (0.5.6) tint palettes (palettes.lua): a dye per palette on every piece the
-- picture data knows, each picture of the piece with its own colour shift
Main.Palettes = nil
Main.palettes_on = false
Main.palette_count = 0

function Main.Log(msg)
	print(Main.TAG .. " " .. tostring(msg))
end

function Main.Debug(msg)
	if Main.settings ~= nil and Main.settings.debug then
		Main.Log("debug: " .. tostring(msg))
	end
end

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if Main.DEFAULTS[k] ~= nil and (type(v) == type(Main.DEFAULTS[k]) or (v == false and Main.MAY_BE_FALSE[k])) then
				s[k] = v
			end
		end
	end
	Main.settings = s
	return s
end

function Main.IsModDye(def)
	return type(def) == "table" and type(def.name) == "string" and def.name:sub(1, #Main.PREFIX) == Main.PREFIX
end

----------------------------------------------------------------------------
-- Game names this mod relies on. If an update renames one, the mod stays off
-- and says which one in client_log.txt.

local function CheckGame()
	local checks = {
		{ "Inventory", Inventory, { "OverrideEquipSlotSymbols", "ClearEquipSlotSymbols", "ClearAllEquipSlots", "RebuildCharacterArmour", "IsSlotHidden" } },
		{ "EquipmentDyer", EquipmentDyer, { "GetActiveDye", "SetEquipmentDye", "OnSave", "OnLoad" } },
	}
	for _, c in ipairs(checks) do
		if type(c[2]) ~= "table" then
			return c[1]
		end
		for _, fn in ipairs(c[3]) do
			if type(c[2][fn]) ~= "function" then
				return c[1] .. ":" .. fn
			end
		end
	end
	if type(Cosmetic.EquipmentDyes) ~= "table" or type(Cosmetic.DyeSlots) ~= "table" then
		return "Cosmetic.EquipmentDyes"
	end
	for _, slot in ipairs(Main.SLOTS) do
		if type(Cosmetic.EquipmentDyes[slot]) ~= "table" or type(Equipment.Items[slot]) ~= "table" or type(Equipment.Symbols[slot]) ~= "table" then
			return "slot " .. slot
		end
	end
	return nil
end

----------------------------------------------------------------------------
-- The dye list

local function CustomDyes(settings)
	local out = {}
	for i, c in ipairs(type(settings.custom_dyes) == "table" and settings.custom_dyes or {}) do
		if type(c) == "table" and type(c.name) == "string" then
			local hue = tonumber(c.hue) or 0
			local key = "custom" .. i .. "_" .. c.name:lower():gsub("[^%w]", "")
			table.insert(out, {
				key = key,
				name = c.name,
				hsb = { (hue % 360) / 360, tonumber(c.saturation) or 1, tonumber(c.brightness) or 1 },
			})
		else
			Main.Log("custom dye " .. i .. " skipped: it needs at least a name")
		end
	end
	return out
end

local function NewDef(set_name, slot, key, label, order, hsb)
	return {
		name = Main.PREFIX .. set_name .. "_" .. key .. "_" .. slot, -- unique: list widgets find dyes by it
		short_name = Main.PREFIX .. key, -- what equipmentdyer saves
		armour_set = set_name,
		armour_slot = slot,
		dye_number = order,
		uitags = {},
		filtertags = {},
		armordye = { hsb[1], hsb[2], hsb[3] },
		armordye_label = label,
		armordye_order = order,
	}
end

-- Fills Cosmetic.EquipmentDyes[slot][armour set][dye] for every armour piece.
function Main.RegisterDyes(data, settings)
	local customs = CustomDyes(settings)
	local count, sets_with_data, sets_fallback = 0, 0, 0
	for _, slot in ipairs(Main.SLOTS) do
		for item_name, item_def in pairs(Equipment.Items[slot]) do
			if type(item_def) == "table" and not item_def.has_no_anim then
				local per = data.sets[item_def.build] and data.sets[item_def.build][slot]
				local list = Cosmetic.EquipmentDyes[slot][item_name] or {}
				local order = 0
				for _, dye in ipairs(data.dyes) do
					if type(dye.player) == "number" then
						Main.soft_by_player[dye.player] = dye.key
					end
					local hsb = per and per[dye.key] or (per == nil and Main.FALLBACK[dye.key]) or nil
					if hsb then
						order = order + 1
						local def = NewDef(item_name, slot, dye.key, dye.name, order, hsb)
						list[def.short_name] = def
						count = count + 1
					end
				end
				for _, c in ipairs(customs) do
					order = order + 1
					local def = NewDef(item_name, slot, c.key, c.name, order, c.hsb)
					list[def.short_name] = def
					count = count + 1
				end
				if next(list) ~= nil then
					Cosmetic.EquipmentDyes[slot][item_name] = list
				end
				if per then
					sets_with_data = sets_with_data + 1
				else
					sets_fallback = sets_fallback + 1
					Main.Debug("no colour data for " .. slot .. " " .. item_name .. " (" .. tostring(item_def.build) .. "): neutral dyes only")
				end
			end
		end
	end
	Main.count = count
	return count, sets_with_data, sets_fallback
end

-- the dye's colour as a tint: its swatch, brightest channel at 1 (so the tint
-- doesn't darken the weapon more than it must)
local function SwatchTint(hex, mix)
	if type(hex) ~= "string" or #hex ~= 6 then
		return nil
	end
	local c = {}
	for i = 1, 3 do
		c[i] = tonumber(hex:sub(i * 2 - 1, i * 2), 16)
		if c[i] == nil then
			return nil
		end
		c[i] = c[i] / 255
	end
	local top = math.max(c[1], c[2], c[3], 1e-3)
	for i = 1, 3 do
		c[i] = c[i] / top
		if mix ~= nil then
			c[i] = 1 + (c[i] - 1) * mix
		end
	end
	return c
end
Main.SwatchTint = SwatchTint

-- The old weapon tint for one dye (a weapon with no data), or nil.
local function TintDef(dye)
	if dye.group == "colour" then
		local tint = SwatchTint(dye.swatch)
		if tint ~= nil then
			return { key = dye.key, name = dye.name, hsb = Main.WEAPON_TINT, mult = tint }
		end
	elseif dye.group == "soft" then
		local tint = SwatchTint(dye.swatch, Main.WEAPON_SOFT_MIX)
		if tint ~= nil then
			return { key = dye.key, name = dye.name, hsb = Main.WEAPON_SOFT_TINT, mult = tint }
		end
	elseif Main.FALLBACK[dye.key] ~= nil then
		return { key = dye.key, name = dye.name, hsb = Main.FALLBACK[dye.key] }
	end
	return nil
end

-- a colour shift from the data: three numbers in the game's range, or nil
local function GoodShift(v)
	if type(v) ~= "table" then
		return nil
	end
	local h, s, b = tonumber(v[1]), tonumber(v[2]), tonumber(v[3])
	if h == nil or s == nil or b == nil or s < 0 or b < 0 then
		return nil
	end
	return { h % 1, s, b }
end
Main.GoodShift = GoodShift

-- Fills Cosmetic.EquipmentDyes.WEAPON[weapon][dye] for every weapon. With the
-- weapon's colour data (0.5.6): every dye a colour shift worked out for that
-- weapon. Without: the colour dyes and soft player colours as tints, the
-- neutrals as plain colour shifts (as 0.3.0-0.5.5). Your own dyes: colour shifts.
-- Returns count, (why none), weapons with data, weapons on the old tint.
function Main.RegisterWeaponDyes(data, settings, wdata)
	if type(Equipment.Items[Main.WEAPON]) ~= "table" or type(Equipment.Symbols[Main.WEAPON]) ~= "table" then
		return 0, "the game has no weapon slot list"
	end
	wdata = type(wdata) == "table" and wdata or {}
	local customs = CustomDyes(settings)
	local all = Cosmetic.EquipmentDyes[Main.WEAPON] or {}
	local count, matched, tinted = 0, 0, 0
	for item_name, item_def in pairs(Equipment.Items[Main.WEAPON]) do
		if type(item_def) == "table" and not item_def.has_no_anim then
			local per = type(item_def.build) == "string" and wdata[item_def.build] or nil
			per = type(per) == "table" and per or nil
			local list = all[item_name] or {}
			local order = 0
			for _, dye in ipairs(data.dyes) do
				local d = nil
				local hsb = per ~= nil and GoodShift(per[dye.key]) or nil
				if hsb ~= nil then
					d = { key = dye.key, name = dye.name, hsb = hsb }
				elseif per == nil then
					d = TintDef(dye)
				end
				if d ~= nil then
					order = order + 1
					local def = NewDef(item_name, Main.WEAPON, d.key, d.name, order, d.hsb)
					if d.mult ~= nil then
						def.armordye_mult = { d.mult[1], d.mult[2], d.mult[3] }
					end
					list[def.short_name] = def
					count = count + 1
				end
			end
			for _, c in ipairs(customs) do
				order = order + 1
				local def = NewDef(item_name, Main.WEAPON, c.key, c.name, order, c.hsb)
				list[def.short_name] = def
				count = count + 1
			end
			if per ~= nil then
				matched = matched + 1
			else
				tinted = tinted + 1
				Main.Debug("no colour data for weapon " .. item_name .. " (" .. tostring(item_def.build) .. "): the old tints")
			end
			all[item_name] = list
		end
	end
	Cosmetic.EquipmentDyes[Main.WEAPON] = all
	Main.weapon_on = count > 0
	Main.weapon_count = count
	return count, nil, matched, tinted
end

-- the slot's symbol names as tintdata.lua keys them (armour: the slot's list, weapons: the dyed ones)
local function PaletteSymbols(slot)
	local out = {}
	local keep = slot == Main.WEAPON and Main.WeaponKeep() or nil
	for _, sym in ipairs(Equipment.Symbols[slot] or {}) do
		if not (keep ~= nil and keep[sym]) then
			out[#out + 1] = sym
		end
	end
	return out
end

-- (0.5.6) Fills Cosmetic.EquipmentDyes[slot][piece]["armordye_pal_<key>"] for every
-- armour piece (and weapon, when weapon dyes are on) whose art palettes.lua has
-- pictures for. Returns the count and the pieces covered. Nothing is worked out
-- here: a palette's shifts are worked out the first time a piece shows it
-- (palettes.lua keeps them), so loading costs nothing.
Main.IDENTITY = { 0, 1, 1 }
function Main.RegisterPalettes(Palettes)
	Main.Palettes = nil
	Main.palettes_on = false
	Main.palette_count = 0
	if type(Palettes) ~= "table" or #(Palettes.list or {}) == 0 then
		return 0, 0
	end
	local slots = { { "HEAD", "armour" }, { "BODY", "armour" }, { "WAIST", "armour" } }
	if Main.weapon_on then
		slots[#slots + 1] = { Main.WEAPON, "weapons" }
	end
	local count, pieces = 0, 0
	for _, sk in ipairs(slots) do
		local slot, kind = sk[1], sk[2]
		local symbols = PaletteSymbols(slot)
		local all = Cosmetic.EquipmentDyes[slot] or {}
		for item_name, item_def in pairs(Equipment.Items[slot] or {}) do
			if type(item_def) == "table" and not item_def.has_no_anim and Palettes.HasPictures(kind, item_def.build, symbols) then
				local list = all[item_name] or {}
				for i, pal in ipairs(Palettes.list) do
					-- (the shift itself: drawn per picture, see PaletteMap)
					local def = NewDef(item_name, slot, Palettes.PREFIX .. pal.key, pal.name, Palettes.ORDER + i, Main.IDENTITY)
					def.armordye_palette = pal.key
					def.armordye_tint_kind = kind
					def.armordye_tint_build = item_def.build
					list[def.short_name] = def
					count = count + 1
				end
				all[item_name] = list
				pieces = pieces + 1
			end
		end
		Cosmetic.EquipmentDyes[slot] = all
	end
	local okl, nl = pcall(Main.RegisterListPalettes, Palettes)
	if okl then
		count = count + nl
	else
		Main.Log("list palettes skipped: " .. tostring(nl))
	end
	Main.Palettes = Palettes
	Main.palettes_on = count > 0
	Main.palette_count = count
	return count, pieces
end

-- (0.5.11) a palette as a dye in some weapons' own lists (WEAPON tab), under a name of its own: imbued Enigmox's
-- colours on the Yammo weapons (user 2026-11-16 17:04 "Yammo tint ... In Armor dye - Weapon tab. Not in palletes").
-- set = the weapon item's set ("hammer_yammo" -> yammo); the PALETTES tab is left as it was.
Main.LIST_PALETTES = {
	{ set = "yammo", palette = "bandicoot", key = "enigmox_tint", label = "Imbued Enigmox", order = 0.5 },
}

function Main.RegisterListPalettes(Palettes)
	local count = 0
	if not Main.weapon_on or type(Palettes) ~= "table" or type(Palettes.by_key) ~= "table" then
		return 0
	end
	local symbols = PaletteSymbols(Main.WEAPON)
	local all = Cosmetic.EquipmentDyes[Main.WEAPON] or {}
	for _, lp in ipairs(Main.LIST_PALETTES) do
		if Palettes.by_key[lp.palette] ~= nil then
			for item_name, item_def in pairs(Equipment.Items[Main.WEAPON] or {}) do
				if type(item_def) == "table" and type(item_name) == "string" and item_name:sub(-(#lp.set + 1)) == "_" .. lp.set
					and not item_def.has_no_anim and Palettes.HasPictures("weapons", item_def.build, symbols) then
					local list = all[item_name] or {}
					local def = NewDef(item_name, Main.WEAPON, lp.key, lp.label, lp.order, Main.IDENTITY)
					def.armordye_palette = lp.palette
					def.armordye_tint_kind = "weapons"
					def.armordye_tint_build = item_def.build
					def.armordye_in_list = true -- (screen.lua: in the weapon's list, not only with palettes_in_lists)
					list[def.short_name] = def
					all[item_name] = list
					count = count + 1
				end
			end
		end
	end
	Cosmetic.EquipmentDyes[Main.WEAPON] = all
	return count
end

function Main.IsPaletteDye(def)
	return type(def) == "table" and def.armordye_palette ~= nil
end

-- a palette dye's colour shift per picture { symbol = shift } and the shift for a
-- picture with no data (the piece's main picture's), or nil (then the dye's own
-- shift, no change)
function Main.PaletteMap(dye)
	local P = Main.Palettes
	if P == nil or type(dye) ~= "table" or dye.armordye_palette == nil then
		return nil
	end
	local ok, m = pcall(P.ForPiece, dye.armordye_tint_kind, dye.armordye_tint_build, dye.armordye_palette)
	if not ok or type(m) ~= "table" then
		return nil
	end
	if dye.armordye_fallback == nil then
		local okf, f = pcall(P.PieceShift, dye.armordye_tint_kind, dye.armordye_tint_build, dye.armordye_palette, PaletteSymbols(dye.armour_slot))
		dye.armordye_fallback = okf and type(f) == "table" and f or false
	end
	return m, dye.armordye_fallback or nil
end

----------------------------------------------------------------------------
-- Drawing: after the game puts an armour piece's art on, tint its symbols.

local function IsDyeSlot(slot)
	return slot == "HEAD" or slot == "BODY" or slot == "WAIST" or (slot == Main.WEAPON and Main.weapon_on)
end
Main.IsDyeSlot = IsDyeSlot

local function Tinted(inv)
	local t = rawget(inv, "armordyes_tinted")
	if t == nil then
		t = {}
		rawset(inv, "armordyes_tinted", t)
	end
	return t
end

local function AnimOf(inv)
	local inst = inv.inst
	return inst ~= nil and inst.AnimState or nil
end

-- The dye on this piece (the mod's), or nil.
function Main.GetDye(inv, slot, def)
	if def == nil or not IsDyeSlot(slot) then
		return nil
	end
	if inv.IsSlotHidden ~= nil and inv:IsSlotHidden(slot) then
		return nil
	end
	local comps = inv.inst ~= nil and inv.inst.components or nil
	local dyer = comps ~= nil and comps.equipmentdyer or nil
	if dyer == nil then
		-- (0.4.0) something drawn with no dye component of its own (the loadout
		-- statue): the dyes it was given (loadouts.lua ShowLook), per piece
		local display = rawget(inv, "armordyes_display")
		local e = type(display) == "table" and display[slot] or nil
		if type(e) ~= "table" or e.set ~= def.name or type(e.dye) ~= "string" then
			return nil
		end
		local sets = Cosmetic.EquipmentDyes[slot]
		local dye = sets ~= nil and sets[def.name] ~= nil and sets[def.name][e.dye] or nil
		return Main.IsDrawnDye(dye) and dye or nil
	end
	local list = Cosmetic.EquipmentDyes[slot]
	if list == nil or list[def.name] == nil then
		return nil -- (GetActiveDye would index a set the list hasn't got)
	end
	local dye = dyer:GetActiveDye(slot, def.name)
	return Main.IsDrawnDye(dye) and dye or nil
end

-- a dye this mod draws: a colour shift, or (0.5.0) an imbued look (the piece's art swapped)
function Main.IsDrawnDye(dye)
	return type(dye) == "table" and (dye.armordye ~= nil or dye.armordye_swap ~= nil)
end

-- The colour shift for this piece, or nil.
function Main.GetShift(inv, slot, def)
	local dye = Main.GetDye(inv, slot, def)
	return dye ~= nil and dye.armordye or nil
end

local function Multed(inv)
	local t = rawget(inv, "armordyes_multed")
	if t == nil then
		t = {}
		rawset(inv, "armordyes_multed", t)
	end
	return t
end

-- Symbols that ever had a weapon tint (kept for the inventory's life: a few names).
local function MultUsed(inv)
	local t = rawget(inv, "armordyes_mult_used")
	if t == nil then
		t = {}
		rawset(inv, "armordyes_mult_used", t)
	end
	return t
end

-- A symbol back to the game's own colours. The engine keeps a symbol's colour
-- shift and its tint together: 0.3.0 cleared the shift, then put the tint back
-- to white, and the old shift came back with it ("original" on a dyed weapon
-- looked washed out: the weapon dyes' shift is nearly grey, a bit brighter).
-- Now a tinted symbol gets its tint back to white first, then the shift set to
-- none (0, 1, 1: the game's own colours even if the engine keeps it), then
-- cleared. A symbol never tinted (all armour) only gets the clear, as always.
local function Restore(inv, anim, sym)
	local used = rawget(inv, "armordyes_mult_used")
	if used ~= nil and used[sym] then
		if anim.SetSymbolMultColor ~= nil then
			anim:SetSymbolMultColor(sym, 1, 1, 1, 1)
		end
		anim:SetSymbolColorShift(sym, 0, 1, 1)
	end
	anim:ClearSymbolColorShift(sym)
end
Main.Restore = Restore

-- (0.5.0) An imbued look: the piece drawn from the imbued art (the same symbol swap the
-- game does when it puts the piece on, from another build with the same symbols). The
-- game puts its own art back on every rebuild (a dye change, a slot change...), so there's
-- nothing to undo; colour shifts this mod left on the symbols are cleared first.
-- (imbued.lua sets this: the imbued art loads per area)
function Main.SwapArtLoaded(build)
	return true
end

function Main.ApplySwap(inv, anim, symbols, dye)
	local build = dye.armordye_build
	if type(build) ~= "string" then
		return
	end
	local tinted = rawget(inv, "armordyes_tinted")
	local multed = rawget(inv, "armordyes_multed")
	for _, sym in ipairs(symbols) do
		if (tinted ~= nil and tinted[sym]) or (multed ~= nil and multed[sym]) then
			Restore(inv, anim, sym)
		end
		if tinted ~= nil then
			tinted[sym] = nil
		end
		if multed ~= nil then
			multed[sym] = nil
		end
		anim:OverrideSymbol(sym, build, sym)
	end
end

function Main.ApplySlot(inv, slot, def)
	if not IsDyeSlot(slot) then
		return
	end
	local anim = AnimOf(inv)
	if anim == nil then
		return
	end
	local symbols = def ~= nil and def.symbol_overrides or Equipment.Symbols[slot]
	if type(symbols) ~= "table" then
		return
	end
	local dye = Main.GetDye(inv, slot, def)
	if dye ~= nil and dye.armordye_swap ~= nil then
		if Main.SwapArtLoaded(dye.armordye_build) then
			Main.ApplySwap(inv, anim, symbols, dye)
			return
		end
		dye = nil -- its art isn't loaded here: the game's own look (imbued.lua)
	end
	local hsb = dye ~= nil and dye.armordye or nil
	local mult = dye ~= nil and anim.SetSymbolMultColor ~= nil and dye.armordye_mult or nil
	-- (0.5.6) a palette: each picture its own shift (a picture with no data takes the dye's)
	local per_sym, fallback = nil, nil
	if hsb ~= nil then
		per_sym, fallback = Main.PaletteMap(dye)
	end
	local tinted = Tinted(inv)
	local multed = rawget(inv, "armordyes_multed")
	if mult ~= nil and multed == nil then
		multed = Multed(inv)
	end
	local keep = slot == Main.WEAPON and Main.WeaponKeep() or nil
	for _, sym in ipairs(symbols) do
		-- a kept piece (the ball's shadow...) is never dyed: as if no dye
		local kept = keep ~= nil and keep[sym]
		local sym_hsb = nil
		if not kept then
			sym_hsb = per_sym ~= nil and (per_sym[sym] or fallback) or hsb
		end
		local sym_mult = not kept and mult or nil
		local had_mult = multed ~= nil and multed[sym] == true
		if sym_hsb == nil and sym_mult == nil then
			-- no dye here: the game's own colours (only what this mod changed)
			if tinted[sym] or had_mult then
				Restore(inv, anim, sym)
			end
			tinted[sym] = nil
			if multed ~= nil then
				multed[sym] = nil
			end
		else
			if had_mult and sym_mult == nil then
				anim:SetSymbolMultColor(sym, 1, 1, 1, 1)
				multed[sym] = nil
			end
			if sym_hsb ~= nil then
				anim:SetSymbolColorShift(sym, sym_hsb[1], sym_hsb[2], sym_hsb[3])
				tinted[sym] = true
			elseif tinted[sym] then
				Restore(inv, anim, sym)
				tinted[sym] = nil
			end
			if sym_mult ~= nil then
				anim:SetSymbolMultColor(sym, sym_mult[1], sym_mult[2], sym_mult[3], 1)
				multed[sym] = true
				MultUsed(inv)[sym] = true
			end
		end
	end
end

function Main.ClearSymbols(inv, symbols)
	local anim = AnimOf(inv)
	local tinted = rawget(inv, "armordyes_tinted")
	local multed = rawget(inv, "armordyes_multed")
	if anim == nil then
		return
	end
	for _, sym in ipairs(symbols) do
		local had_shift = tinted ~= nil and tinted[sym]
		local had_mult = multed ~= nil and multed[sym]
		if had_shift or had_mult then
			Restore(inv, anim, sym)
		end
		if tinted ~= nil then
			tinted[sym] = nil
		end
		if multed ~= nil then
			multed[sym] = nil
		end
	end
end

function Main.ClearAll(inv)
	local anim = AnimOf(inv)
	if anim == nil then
		return
	end
	local done = {}
	for _, t in ipairs({ rawget(inv, "armordyes_multed") or {}, rawget(inv, "armordyes_tinted") or {} }) do
		for sym in pairs(t) do
			if not done[sym] then
				done[sym] = true
				Restore(inv, anim, sym)
			end
		end
	end
	rawset(inv, "armordyes_tinted", {})
	rawset(inv, "armordyes_multed", {})
end

-- A copy of a character (a UI puppet: the HUD portrait, the mirror's) gets its
-- weapon dyes too (the game copies the armour's only), and its weapon redrawn.
function Main.CopyWeaponDyes(from, to_comps)
	if not Main.weapon_on then
		return false
	end
	local fd = from ~= nil and from.components ~= nil and from.components.equipmentdyer or nil
	local td = to_comps ~= nil and to_comps.equipmentdyer or nil
	if fd == nil or td == nil or type(fd.applied_dyes) ~= "table" or type(td.applied_dyes) ~= "table" then
		return false
	end
	local known = Cosmetic.EquipmentDyes[Main.WEAPON] or {}
	local copy = {}
	for set, name in pairs(fd.applied_dyes[Main.WEAPON] or {}) do
		if known[set] ~= nil and known[set][name] ~= nil then
			copy[set] = name
		end
	end
	td.applied_dyes[Main.WEAPON] = next(copy) ~= nil and copy or nil
	local inv = to_comps.inventory
	if inv ~= nil and inv._GetEquippedDef ~= nil then
		local def = inv:_GetEquippedDef(Main.WEAPON)
		if def ~= nil then
			Main.ApplySlot(inv, Main.WEAPON, def)
		end
	end
	return true
end

function Main.HookPuppet()
	if Main.puppet_hooked then
		return true
	end
	local ok, PlayerPuppet = pcall(require, "widgets.playerpuppet")
	if not ok or type(PlayerPuppet) ~= "table" or type(PlayerPuppet.CloneCharacterWithEquipment) ~= "function" then
		return false
	end
	Main.puppet_hooked = true
	local clone = PlayerPuppet.CloneCharacterWithEquipment
	PlayerPuppet.CloneCharacterWithEquipment = function(self, character, skip_weapon, ...)
		local r = table.pack(clone(self, character, skip_weapon, ...))
		if not skip_weapon then
			local okc, err = pcall(Main.CopyWeaponDyes, character, self.components)
			if not okc then
				Main.Log("weapon dye copy skipped: " .. tostring(err))
			end
		end
		return table.unpack(r, 1, r.n)
	end
	return true
end

local function HookInventory()
	local orig_override = Inventory.OverrideEquipSlotSymbols
	Inventory.OverrideEquipSlotSymbols = function(self, slot, def, ...)
		local r = orig_override(self, slot, def, ...)
		local ok, err = pcall(Main.ApplySlot, self, slot, def)
		if not ok then
			Main.Log("tint failed: " .. tostring(err))
		end
		return r
	end

	local orig_clear = Inventory.ClearEquipSlotSymbols
	Inventory.ClearEquipSlotSymbols = function(self, slot, def, ...)
		local r = orig_clear(self, slot, def, ...)
		if IsDyeSlot(slot) then
			local symbols = def ~= nil and def.symbol_overrides or Equipment.Symbols[slot]
			if type(symbols) == "table" then
				pcall(Main.ClearSymbols, self, symbols)
			end
		end
		return r
	end

	local orig_clear_all = Inventory.ClearAllEquipSlots
	Inventory.ClearAllEquipSlots = function(self, ...)
		local r = orig_clear_all(self, ...)
		pcall(Main.ClearAll, self)
		return r
	end
end

----------------------------------------------------------------------------
-- The game's unused dye market would shuffle every dye into a list each time
-- a market is filled (and use up random numbers doing it). It never shows
-- dyes, so it gets the game's own dyes only, as before.

local function HookDyeMarket()
	local ok, ShopManager = pcall(require, "components.shopmanager")
	if not ok or type(ShopManager) ~= "table" or type(ShopManager.GenerateDyeWares) ~= "function" then
		return
	end
	local orig = ShopManager.GenerateDyeWares
	ShopManager.GenerateDyeWares = function(self, ...)
		local saved = {}
		for _, slot in ipairs(Main.SLOTS) do
			saved[slot] = Cosmetic.EquipmentDyes[slot]
			local only_game = {}
			for set, dyes in pairs(saved[slot] or {}) do
				local kept = {}
				for k, def in pairs(dyes) do
					if not Main.IsModDye(def) then
						kept[k] = def
					end
				end
				if next(kept) ~= nil then
					only_game[set] = kept
				end
			end
			Cosmetic.EquipmentDyes[slot] = only_game
		end
		local res = { pcall(orig, self, ...) }
		for slot, t in pairs(saved) do
			Cosmetic.EquipmentDyes[slot] = t
		end
		if not res[1] then
			error(res[2], 0)
		end
		return table.unpack(res, 2)
	end
end

----------------------------------------------------------------------------
-- A brand-new character starts with its basic armour in its player's soft
-- colour (player 1 Soft Blue, 2 Soft Yellow, 3 Soft Teal, 4 Soft Purple: the
-- game's own player colours), once. modmain calls ApplyNewCharacterColour when
-- the game loads a player that has no saved player data (a character just made).
-- (0.2.1 marked the slot in memory on the new-character screen; the game starts
-- a fresh Lua when it goes from the menu into the camp, so the mark was gone.)

-- The new-character screen shows it too: an empty slot being made into a character
-- (the template puppets) wears its basic armour in the soft colour of the player
-- making it, on the puppet's own dye component (widgets/playerpuppet.lua). The
-- player is the slot's user (GetPlayerIndex), or the screen's owner in town.
local function PlayerNumberOf(button)
	local ok, n = pcall(function() return button:GetPlayerIndex() end)
	if ok and type(n) == "number" then
		return n
	end
	local ok2, owner = pcall(function() return button:GetOwningPlayer() end)
	if ok2 and owner ~= nil and owner.GetHunterId ~= nil then
		local ok3, id = pcall(owner.GetHunterId, owner)
		if ok3 and type(id) == "number" then
			return id
		end
	end
	return nil
end

function Main.DyeTemplatePreview(button)
	local ok_e, empty = pcall(function() return button:IsEmpty() end)
	if not ok_e or not empty then
		return nil -- an existing character keeps its own dyes
	end
	local dye = Main.SoftDyeFor(PlayerNumberOf(button)) -- nil = no player yet: the game's colours
	for _, sp in ipairs({ button.puppet, button.puppet_shadow }) do
		local pp = type(sp) == "table" and sp.puppet or nil
		local dyer = pp ~= nil and pp.components ~= nil and pp.components.equipmentdyer or nil
		if dyer ~= nil and dyer.SetEquipmentDye ~= nil then
			for _, slotname in ipairs(Main.SLOTS) do
				local set_dyes = Cosmetic.EquipmentDyes[slotname] and Cosmetic.EquipmentDyes[slotname][Main.BASIC_SET]
				if set_dyes ~= nil and (dye == nil or set_dyes[dye] ~= nil) then
					dyer:SetEquipmentDye(slotname, Main.BASIC_SET, dye)
				end
			end
		end
	end
	return dye
end

function Main.HookTemplatePreview(SlotButton)
	if type(SlotButton) ~= "table" or SlotButton.armordyes_preview_hooked then
		return false
	end
	local names = { "_ShowArmour", "SetUserReadyState", "SetCharacterCreationState" }
	for _, name in ipairs(names) do
		if type(SlotButton[name]) ~= "function" then
			return false
		end
	end
	-- and as soon as a player takes the empty slot (SetUser), and when the look
	-- changes (a template, a preset, a colour: the puppet is rebuilt)
	for _, name in ipairs({ "SetUser", "SetBase", "SetColour", "SetBodyParts" }) do
		if type(SlotButton[name]) == "function" then
			names[#names + 1] = name
		end
	end
	SlotButton.armordyes_preview_hooked = true
	for _, name in ipairs(names) do
		local orig = SlotButton[name]
		SlotButton[name] = function(self, ...)
			local ret = { orig(self, ...) }
			local ok, err = pcall(Main.DyeTemplatePreview, self)
			if not ok then
				print("[Armor Dyes] new-character preview skipped: " .. tostring(err))
			end
			return table.unpack(ret)
		end
	end
	return true
end

-- The soft dye for this player number (wraps past 4), or nil.
function Main.SoftDyeFor(player_number)
	if type(player_number) ~= "number" then
		return nil
	end
	local n = ((math.floor(player_number) - 1) % 4) + 1
	local key = Main.soft_by_player[n]
	return key ~= nil and (Main.PREFIX .. key) or nil
end

-- Called for a local player whose character was just made. Returns the dye
-- given, or nil. A basic armour piece that already has a dye keeps it.
function Main.ApplyNewCharacterColour(player, player_number)
	local dyer = player.components ~= nil and player.components.equipmentdyer or nil
	local dye = Main.SoftDyeFor(player_number)
	if dyer == nil or dye == nil then
		return nil
	end
	local given = nil
	for _, slotname in ipairs(Main.SLOTS) do
		local set_dyes = Cosmetic.EquipmentDyes[slotname] and Cosmetic.EquipmentDyes[slotname][Main.BASIC_SET]
		local have = dyer.applied_dyes ~= nil and dyer.applied_dyes[slotname] ~= nil and dyer.applied_dyes[slotname][Main.BASIC_SET] or nil
		if set_dyes ~= nil and set_dyes[dye] ~= nil and have == nil then
			dyer:SetEquipmentDye(slotname, Main.BASIC_SET, dye)
			given = dye
		end
	end
	return given
end

----------------------------------------------------------------------------

function Main.Install(data, settings, wdata, palettes)
	local missing = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	if type(data) ~= "table" or type(data.dyes) ~= "table" or type(data.sets) ~= "table" then
		return false, "data.lua is missing or broken"
	end
	local count, with_data, fallback = Main.RegisterDyes(data, settings)
	local weapon_info = "weapon dyes off"
	if settings.weapon_dyes ~= false then
		local okw, n, why, matched, tinted = pcall(Main.RegisterWeaponDyes, data, settings, wdata)
		if not okw then
			Main.weapon_on = false
			weapon_info = "weapon dyes off: " .. tostring(n)
		elseif n > 0 then
			weapon_info = string.format("%d weapon dyes (%d weapons matched, %d on the old tints)", n, matched or 0, tinted or 0)
			if not Main.HookPuppet() then
				weapon_info = weapon_info .. " (the HUD's portrait shows weapons undyed: PlayerPuppet changed)"
			end
		else
			weapon_info = "weapon dyes off: " .. tostring(why or "no weapons")
		end
	end
	local palette_info = "palettes off in the settings"
	if settings.palettes ~= false then
		if type(palettes) ~= "table" then
			palette_info = "palettes off: " .. tostring(palettes)
		else
			local okp, np, pieces = pcall(Main.RegisterPalettes, palettes)
			if not okp then
				Main.palettes_on = false
				palette_info = "palettes off: " .. tostring(np)
			elseif np > 0 then
				palette_info = string.format("%d palettes on %d pieces", #palettes.list, pieces)
			else
				palette_info = "palettes off: no pieces with picture data"
			end
		end
	end
	HookInventory()
	HookDyeMarket()
	return true, string.format("%d dyes on %d armour pieces%s; %s; %s", count, with_data + fallback,
		fallback > 0 and string.format(", %d with neutral dyes only", fallback) or "", weapon_info, palette_info)
end

return Main
