-- Progression, nightly mode: pick any level on the map, like the alpha.
-- The map's location panel (MapSidebar) normally sets the level by itself
-- (side hunts by the weather, main hunts Frenzy 5, Super Frenzy with its own
-- picker once unlocked). Here LB / RB (the game's "previous / next tab", which
-- the panel already sends to Increase/DecreaseAscensionLevel) steps through:
--   Normal, Frenzy 1-5, and Super Frenzy 1-5 where the hunt has a Super Frenzy
--   boss (the game's own check, biomes.HasEliteBoss: main hunts).
-- The choice goes where the game keeps it (AscensionManager's selected level
-- per location), so the run starts at it like any other run. The panel's own
-- looks (purple title for Frenzy, the Super Frenzy background and elite boss)
-- follow the level.

local Picker = {}

local NORMAL_LEVELS = 5
local SUPER_LEVELS = 5

local function FindUpvalue(fn, wanted)
	if type(fn) ~= "function" then
		return nil
	end
	for i = 1, 255 do
		local name, value = debug.getupvalue(fn, i)
		if name == nil then
			return nil
		end
		if name == wanted then
			return value
		end
	end
	return nil
end

-- levels the player can pick for a location
function Picker.Levels(location_id)
	local levels = {}
	local normal = rawget(_G, "NORMAL_FRENZY_LEVELS") or NORMAL_LEVELS
	for i = 0, normal do
		levels[#levels + 1] = i
	end
	local ok, biomes = pcall(require, "defs.biomes")
	local has_elite = ok and biomes.HasEliteBoss ~= nil and location_id ~= nil and biomes.HasEliteBoss(location_id)
	if has_elite then
		local super = rawget(_G, "SUPER_FRENZY_LEVELS") or SUPER_LEVELS
		for i = 1, super do
			levels[#levels + 1] = normal + i
		end
	end
	return levels
end

-- the nearest allowed level at or below `level`
function Picker.Clamp(levels, level)
	local best = levels[1]
	for _, l in ipairs(levels) do
		if l <= (level or 0) then
			best = l
		end
	end
	return best
end

function Picker.Step(levels, level, delta)
	local idx = 1
	for i, l in ipairs(levels) do
		if l == level then
			idx = i
		end
	end
	idx = math.max(1, math.min(#levels, idx + delta))
	return levels[idx]
end

function Picker.LevelName(level)
	local normal = rawget(_G, "NORMAL_FRENZY_LEVELS") or NORMAL_LEVELS
	if level <= 0 then
		return "Normal"
	elseif level <= normal then
		return "Frenzy " .. level
	end
	return "Super Frenzy " .. (level - normal)
end

function Picker.Install(Main)
	local MapSidebar = require "widgets.ftf.dungeonselection.mapsidebar"
	local orig_set_location = MapSidebar.SetLocationData
	local orig_set_mode = MapSidebar.SetFrenzyMode
	local orig_get_level = MapSidebar.GetFrenzyLevel
	local orig_inc = MapSidebar.IncreaseAscensionLevel
	local orig_dec = MapSidebar.DecreaseAscensionLevel
	for name, fn in pairs({ SetLocationData = orig_set_location, SetFrenzyMode = orig_set_mode,
		GetFrenzyLevel = orig_get_level, IncreaseAscensionLevel = orig_inc, DecreaseAscensionLevel = orig_dec }) do
		assert(type(fn) == "function", "MapSidebar:" .. name)
	end
	-- the panel's Normal / Frenzy / Super modes (an Enum: None, Normal, Super)
	local FrenzyMode = FindUpvalue(orig_set_mode, "FrenzyMode") or FindUpvalue(orig_get_level, "FrenzyMode")
	local MODE = {
		None = FrenzyMode ~= nil and FrenzyMode.id.None or 1,
		Normal = FrenzyMode ~= nil and FrenzyMode.id.Normal or 2,
		Super = FrenzyMode ~= nil and FrenzyMode.id.Super or 3,
	}
	local normal = rawget(_G, "NORMAL_FRENZY_LEVELS") or NORMAL_LEVELS

	local function Ascension()
		return TheDungeon.progression.components.ascensionmanager
	end

	local function Label(self, level)
		local label = rawget(self, "progression_label")
		if label == nil then
			local Text = require "widgets.text"
			label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT or 48, "", UICOLORS.LIGHT_TEXT))
			pcall(label.SetHiddenBoundingBox, label, true)
			rawset(self, "progression_label", label)
		end
		local text = Picker.LevelName(level)
		pcall(function()
			label:SetText(string.format("<p bind='Controls.Digital.MENU_TAB_PREV' color=0>  %s  <p bind='Controls.Digital.MENU_TAB_NEXT' color=0>", text))
			label:LayoutBounds("center", "top", self.bg)
			label:Offset(0, -372)
			label:Show()
		end)
	end

	-- show `level` for the panel's location and store it for the run
	local function Apply(self, level)
		local location = self.locationData ~= nil and self.locationData.id or nil
		if location == nil then
			return
		end
		local levels = Picker.Levels(location)
		level = Picker.Clamp(levels, level)
		rawset(self, "progression_level", level)
		local mode = level <= 0 and MODE.None or (level <= normal and MODE.Normal or MODE.Super)
		Ascension():StoreSelectedAscension(location, level)
		local was = rawget(self, "progression_applying")
		rawset(self, "progression_applying", true)
		local ok, err = pcall(orig_set_mode, self, mode) -- the panel's looks for the mode
		rawset(self, "progression_applying", was)
		if not ok then
			Main.Log("map panel: " .. tostring(err))
		end
		-- the panel stores its own level for the mode (Frenzy 5, or the Super
		-- Frenzy picker's, which stops at your unlocks): ours wins
		Ascension():StoreSelectedAscension(location, level)
		if self.superfrenzy_widget ~= nil then
			self.superfrenzy_widget:Hide()
		end
		if self.heartshard_challenges_widget ~= nil then
			self.heartshard_challenges_widget:Show()
		end
		pcall(self.RefreshContents, self) -- boss shown, travel button, materials, layout
		pcall(self.UpdateMaterials, self)
		pcall(self.UpdateDifficultyAssessment, self)
		Label(self, level)
		pcall(self.DoLayout, self)
		Main.Debug(location .. ": " .. Picker.LevelName(level))
	end
	Picker.Apply = Apply
	-- (in the map panel's hooks: an error is logged, the panel stays the game's)
	local apply_errors = 0
	local function SafeApply(self, level)
		local ok, err = pcall(Apply, self, level)
		if not ok and apply_errors < 5 then
			apply_errors = apply_errors + 1
			Main.Log("map panel error (skipped; the game carries on): " .. tostring(err))
		end
	end

	MapSidebar.SetLocationData = function(self, data, ...)
		-- this location's level as last picked, read before the panel sets its own
		local location = data ~= nil and data.id or nil
		local level = location ~= nil and Ascension():GetSelectedAscension(location) or nil
		local was = rawget(self, "progression_applying")
		rawset(self, "progression_applying", true)
		local results = table.pack(pcall(orig_set_location, self, data, ...))
		rawset(self, "progression_applying", was)
		if not results[1] then
			error(results[2], 0)
		end
		if location ~= nil then
			SafeApply(self, level)
		end
		return table.unpack(results, 2, results.n)
	end

	-- something else switched the panel's mode (e.g. a map marker): keep our level
	MapSidebar.SetFrenzyMode = function(self, ...)
		local results = table.pack(orig_set_mode(self, ...))
		if not rawget(self, "progression_applying") and rawget(self, "progression_level") ~= nil then
			SafeApply(self, rawget(self, "progression_level"))
		end
		return table.unpack(results, 1, results.n)
	end

	MapSidebar.GetFrenzyLevel = function(self, ...)
		local level = rawget(self, "progression_level")
		if level ~= nil then
			return level
		end
		return orig_get_level(self, ...)
	end

	local function Delta(self, d)
		local location = self.locationData ~= nil and self.locationData.id or nil
		if location == nil then
			return self
		end
		local ok, err = pcall(function()
			local levels = Picker.Levels(location)
			local level = rawget(self, "progression_level") or Ascension():GetSelectedAscension(location)
			Apply(self, Picker.Step(levels, Picker.Clamp(levels, level), d))
		end)
		if not ok and apply_errors < 5 then
			apply_errors = apply_errors + 1
			Main.Log("map panel error (skipped; the game carries on): " .. tostring(err))
		end
		return self
	end
	MapSidebar.IncreaseAscensionLevel = function(self)
		return Delta(self, 1)
	end
	MapSidebar.DecreaseAscensionLevel = function(self)
		return Delta(self, -1)
	end
end

return Picker
