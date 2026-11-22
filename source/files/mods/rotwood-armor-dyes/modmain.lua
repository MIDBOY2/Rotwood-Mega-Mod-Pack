-- Armor Dyes (Rotwood build 760548)
-- Dye each armour piece (helmet / body / legs) in the game's ARMOUR DYE tab of
-- the character screen (the mirror in town). Runtime colour shifts, no new art.
-- 0.5.0: the imbued boss looks (new art: anim/, images/), as the first dye of each boss
-- look and as mirage patterns (scripts/armordyes/imbued.lua).
-- Settings: scripts/armordyes_settings.lua

local pcall = GLOBAL.pcall
local TAG = "[Armor Dyes]"

local ok, user_settings = pcall(require, "armordyes_settings")
if not ok then
	print(TAG .. " armordyes_settings.lua has an error, using the defaults: " .. tostring(user_settings))
	user_settings = nil
end

local Main = require "armordyes.main"
local settings = Main.LoadSettings(user_settings)

if not settings.enabled then
	print(TAG .. " off (enabled = false in armordyes_settings.lua)")
	return
end

-- (0.5.0) the imbued boss looks: their art loads with the mod (Assets), and their
-- pieces go in before the dyes are made (the save hooks first: no imbued name is
-- ever saved, so the game is fine without the mod)
local Imbued = nil
local imbued_info = "imbued looks off in the settings"
if settings.imbued ~= false then
	local ok_m, mod = pcall(require, "armordyes.imbued")
	if not ok_m then
		imbued_info = "imbued looks off: " .. tostring(mod)
	else
		local ok_p, assets, why = pcall(mod.Prepare, settings)
		if not ok_p then
			imbued_info = "imbued looks off: " .. tostring(assets)
		elseif assets == nil then
			imbued_info = tostring(why)
		else
			Assets = Assets or {}
			for _, a in ipairs(assets) do
				table.insert(Assets, a)
			end
			local ok_d, done, n = pcall(mod.RegisterDefs)
			if ok_d and done then
				Imbued = mod
			else
				imbued_info = "imbued looks off: " .. tostring(ok_d and n or done)
			end
		end
	end
end

local data_ok, data = pcall(require, "armordyes.data")
if not data_ok then
	print(TAG .. " off: data.lua: " .. tostring(data))
	return
end

-- (0.5.9) the imbued pieces' own dye numbers (imbued_dyes.lua, from their art): an imbued
-- mirage pattern draws the imbued piece, which only got the 4 neutral dyes without them
if Imbued ~= nil and type(data) == "table" and type(data.sets) == "table" then
	local ok_id, idata = pcall(require, "armordyes.imbued_dyes")
	if ok_id and type(idata) == "table" and type(idata.sets) == "table" then
		for build, slots in pairs(idata.sets) do
			if type(build) == "string" and type(slots) == "table" and data.sets[build] == nil then
				data.sets[build] = slots
			end
		end
	else
		print(TAG .. " imbued_dyes.lua: " .. tostring(idata) .. " (imbued pieces get the neutral dyes only)")
	end
end

-- (0.5.6) the weapons' own colour data; without it the weapons keep the old tints
local wdata_ok, wdata = pcall(require, "armordyes.weapondata")
if not wdata_ok or type(wdata) ~= "table" then
	print(TAG .. " weapondata.lua: " .. tostring(wdata) .. " (weapon dyes use the old tints)")
	wdata = nil
end

-- (0.5.6) tint palettes: the palette list and each piece's picture data
local palettes = "not loaded"
if settings.palettes ~= false then
	local ok_p, Palettes = pcall(require, "armordyes.palettes")
	local ok_d, defs = pcall(require, "armordyes.palettedefs")
	local ok_t, tint = pcall(require, "armordyes.tintdata")
	if not ok_p or type(Palettes) ~= "table" then
		palettes = "palettes.lua: " .. tostring(Palettes)
	elseif not ok_d or type(defs) ~= "table" then
		palettes = "palettedefs.lua: " .. tostring(defs)
	elseif not ok_t or type(tint) ~= "table" then
		palettes = "tintdata.lua: " .. tostring(tint)
	else
		local ok_i, n = pcall(Palettes.Init, defs, tint)
		if ok_i and type(n) == "number" and n > 0 then
			palettes = Palettes
		else
			palettes = "no usable palettes" .. (ok_i and "" or (": " .. tostring(n)))
		end
	end
end

local installed, info = Main.Install(data, settings, wdata, palettes)
if not installed then
	print(TAG .. " off: " .. tostring(info))
	return
end

if Imbued ~= nil then
	local ok_i, info_i = pcall(Imbued.Install, settings)
	imbued_info = ok_i and tostring(info_i) or ("imbued dyes / patterns off: " .. tostring(info_i))
end

local tab_info = "dye tab off in the settings"
if settings.dye_tab then
	local screen_ok, Screen = pcall(require, "armordyes.screen")
	local tab_ok, err = false, Screen
	if screen_ok then
		tab_ok, err = Screen.Install(settings)
	end
	tab_info = tab_ok and "dye tab on" or ("dye tab off: " .. tostring(err))
end

local newchar_info = "new characters: original colours"
if settings.new_character_colour then
	local ok_b, SlotButton = pcall(require, "widgets.ftf.charactersaveslotbutton")
	newchar_info = "new characters start in their player's soft colour"
	if ok_b and Main.HookTemplatePreview(SlotButton) then
		newchar_info = newchar_info .. ", shown on the new-character screen"
	end
	-- A brand-new character: the game loads the player with no saved player data
	-- (PostLoadWorld(nil): prefabs/player_side.lua for one made on the main menu,
	-- widgets/ftf/characterselectioningame.lua for one made in town). That's the
	-- moment its basic armour gets its player's soft colour; it's saved with the
	-- character from then on.
	AddPlayerPostInit(function(inst)
		local base = inst.PostLoadWorld
		if type(base) ~= "function" or inst.armordyes_newchar then
			return
		end
		inst.armordyes_newchar = true
		inst.PostLoadWorld = function(self, data, ...)
			local r = table.pack(base(self, data, ...))
			if data == nil then
				local ok, given = pcall(function()
					if self.IsLocal ~= nil and not self:IsLocal() then
						return nil
					end
					local number = self.GetHunterId ~= nil and self:GetHunterId() or nil
					return Main.ApplyNewCharacterColour(self, number)
				end)
				if not ok then
					print(TAG .. " new character colour skipped: " .. tostring(given))
				elseif given ~= nil then
					print(TAG .. " new character: basic armour in " .. tostring(given))
				end
			end
			return table.unpack(r, 1, r.n)
		end
	end)
end

-- (0.4.0) loadouts keep their dyes; the loadout statue shows dyes and Morphic looks
local loadouts_info = "loadout dyes off"
local ok_l, Loadouts = pcall(require, "armordyes.loadouts")
if ok_l then
	local ok_i, info_l = pcall(function()
		local function Req(name)
			local ok_r, m = pcall(require, name)
			return ok_r and m or nil
		end
		return Loadouts.Install(settings, {
			Main = Main,
			Cosmetic = require "defs.cosmetics.cosmetics",
			Equipment = require "defs.equipment",
			EquipmentGem = Req("defs.equipmentgems.equipmentgem"),
			PlayerLoadouts = Req("components.playerloadouts"),
			LoadoutMannequin = Req("components.loadoutmannequin"),
		})
	end)
	loadouts_info = ok_i and tostring(info_l) or ("loadout dyes off: " .. tostring(info_l))
	if ok_i and Loadouts.mode ~= nil then
		AddPlayerPostInit(function(inst)
			local ok_p, err = pcall(Loadouts.SetupPlayer, inst)
			if not ok_p then
				print(TAG .. " loadout dyes skipped for a player: " .. tostring(err))
			end
		end)
	end
else
	loadouts_info = "loadout dyes off: " .. tostring(Loadouts)
end

print(TAG .. " on (" .. tostring(info) .. "; " .. tab_info .. "; " .. newchar_info .. "; " .. loadouts_info .. "; " .. imbued_info .. ")")
