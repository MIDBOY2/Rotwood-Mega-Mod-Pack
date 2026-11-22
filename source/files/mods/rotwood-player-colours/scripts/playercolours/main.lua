-- Player Colours: the runtime.
--
-- The game colours everything that marks a player (HUD frame, portrait, health
-- bar, name, selection brackets, silhouette, the ring under the feet, the aim
-- arrow) from one place: UICOLORS.PLAYERS[player number] (constants.lua), read
-- by SetPlayerColor in prefabs/player_side.lua, which then tells the HUD with
-- the "update_ui_color" event. The ring, aim arrow and the other per-player
-- effects are separate hand-tuned FX per player number (<name>_p1 .. _p4).
--
-- This mod uses the same system:
--  * a character's override goes into the game's own colour tables for that
--    player's number, then the game's own refresh runs (the
--    "update_skin_color" event, as the game's debug code does) - so the game
--    itself recolours everything, exactly as it does for vanilla colours;
--  * per-player FX get their override colours once when they appear
--    (AddPrefabPostInit on just those prefabs), through the same components
--    the game uses (colormultiplier / coloradder / bloomer, the particle
--    system's params, prefabutil.LoadBloomColorOverrideData for props).
-- Nothing runs per frame. All colours are precomputed in data.lua.

local Main = {}

Main.TAG = "[Player Colours]"
Main.DEFAULTS = {
	enabled = true,
	colour_tab = true, -- the PLAYER COLOUR tab in the character screen
	fx = true,         -- per-player effects (feet ring, aim arrow, ...) follow the colour
	red_ring = "steps", -- Red's ring under the feet: "steps" / "deep" / "bright" (Main.RED_RINGS)
	farm_signs = true, -- (0.2.8) the farm plot signs' leaf follows the plot owner's colour
	debug = false,
}

-- Red's ring under the feet (ground_indicator_p#). Its art is white with the shading in
-- alpha steps, added on the ground: a strong pure red tops out the red channel and the
-- steps (the inner circle) melt together. data.lua has "steps"; the others are the
-- earlier looks to try.
Main.RED_RINGS = {
	steps = { multcolor = "7A0000F2", glowcolor = "600000FF", bloom = 25 },  -- less red + a soft glow: the steps show (2026-11-10)
	deep = { multcolor = "900000F2", glowcolor = "E90000FF", bloom = 50 },   -- 0.2.2 ("R2")
	bright = { multcolor = "EC0000F2", glowcolor = "F7001FFF", bloom = 50 }, -- "Red A"
}

function Main.ApplyRedRing(data, which)
	local ring = Main.RED_RINGS[which or "steps"]
	local fam = type(data) == "table" and type(data.fx) == "table" and data.fx["ground_indicator_p#"] or nil
	local red = fam ~= nil and type(fam.by) == "table" and fam.by.red or nil
	if ring == nil or red == nil then
		return false
	end
	red.multcolor, red.glowcolor, red.bloom = ring.multcolor, ring.glowcolor, ring.bloom
	return true
end

Main.settings = Main.DEFAULTS
Main.data = nil
Main.list = {}       -- the colours, in picker order
Main.by_key = {}     -- key -> colour entry (with .rgb / .rgb_dark colour objects)
Main.vanilla = {}    -- player number -> the game's own colour objects (to put back)
Main.index_key = {}  -- player number -> override key now in the colour tables (nil = vanilla)
Main.index_owner = {} -- player number -> the player entity that set it
Main.fx_prefabs = 0
Main.particle_cache = {}
Main.prop_cache = {}
Main.machines = setmetatable({}, { __mode = "k" }) -- the Spring Port machines here: entity -> its player number
Main.signs = setmetatable({}, { __mode = "k" })    -- (0.2.8) the farm plot signs here: entity -> true

-- A per-player effect's prefab for a player number: "_p#" -> "_p2" (ground_indicator_p2),
-- "_#p" -> "_2p" (the Spring Port's corestone_converter_2p_idle).
function Main.NameFor(fam, idx)
	local name = fam:gsub("_p#", "_p" .. idx)
	name = name:gsub("_#p", "_" .. idx .. "p")
	return name
end

local function Log(msg)
	print(Main.TAG .. " " .. msg)
end
Main.Log = Log

local function Debug(msg)
	if Main.settings.debug then
		Log(msg)
	end
end
Main.Debug = Debug

function Main.LoadSettings(user)
	local s = {}
	for k, v in pairs(Main.DEFAULTS) do
		s[k] = v
	end
	if type(user) == "table" then
		for k, v in pairs(user) do
			if Main.DEFAULTS[k] ~= nil and type(v) == type(Main.DEFAULTS[k]) then
				s[k] = v
			end
		end
	end
	Main.settings = s
	return s
end

local function HexColour(hex)
	return HexToRGB(tonumber(hex .. "FF", 16))
end

-- What the mod needs from the game; nil = all there, else what's missing.
local function CheckGame()
	if type(UICOLORS) ~= "table" or type(UICOLORS.PLAYERS) ~= "table" or type(UICOLORS.PLAYERS_DARK_TEXT) ~= "table" then
		return "UICOLORS.PLAYERS"
	end
	for i = 1, 4 do
		if UICOLORS.PLAYERS[i] == nil or UICOLORS.PLAYERS_DARK_TEXT[i] == nil then
			return "UICOLORS.PLAYERS[" .. i .. "]"
		end
	end
	if type(HexToRGB) ~= "function" or type(HexToRGBFloats) ~= "function" or type(StrToHex) ~= "function" then
		return "the colour helpers (util/colorutil.lua)"
	end
	return nil
end

function Main.Install(data, settings)
	Main.settings = settings or Main.settings
	local missing = CheckGame()
	if missing ~= nil then
		return false, "a game update changed " .. missing
	end
	if type(data) ~= "table" or type(data.colours) ~= "table" then
		return false, "data.lua has no colour list"
	end
	Main.data = data
	Main.ApplyRedRing(data, Main.settings.red_ring)
	Main.list, Main.by_key = {}, {}
	for _, c in ipairs(data.colours) do
		local entry = { key = c.key, name = c.name, hex = c.hex, dark = c.dark,
			rgb = HexColour(c.hex), rgb_dark = HexColour(c.dark) }
		table.insert(Main.list, entry)
		Main.by_key[c.key] = entry
	end
	for i = 1, 4 do
		Main.vanilla[i] = {
			normal = UICOLORS.PLAYERS[i],
			dark = UICOLORS.PLAYERS_DARK_TEXT[i],
			named = rawget(UICOLORS, "PLAYER_" .. i),
			named_dark = rawget(UICOLORS, "PLAYER_" .. i .. "_DARK_TEXT"),
		}
	end
	return true, #Main.list .. " colours"
end

-- The game's colour tables for this player number: the override's colours, or
-- the game's own (key nil).
function Main.SetIndexColour(idx, key, owner)
	local v = Main.vanilla[idx]
	if v == nil then
		return false
	end
	local c = key ~= nil and Main.by_key[key] or nil
	local normal = c ~= nil and c.rgb or v.normal
	local dark = c ~= nil and c.rgb_dark or v.dark
	UICOLORS.PLAYERS[idx] = normal
	UICOLORS.PLAYERS_DARK_TEXT[idx] = dark
	if v.named ~= nil then
		UICOLORS["PLAYER_" .. idx] = normal
	end
	if v.named_dark ~= nil then
		UICOLORS["PLAYER_" .. idx .. "_DARK_TEXT"] = dark
	end
	local was = Main.index_key[idx]
	Main.index_key[idx] = c ~= nil and key or nil
	Main.index_owner[idx] = c ~= nil and owner or nil
	if was ~= Main.index_key[idx] then
		Main.RecolourMachines(idx)
		Main.RecolourSigns()
	end
	return true
end

-- ---------------------------------------------------------------------------
-- The Spring Port (0.2.6; the room with the Corestone machines and their
-- Treasure Bundles, the game's "metaunlock" room): one machine per player
-- number (corestone_converter_1p..4p), its player colour drawn into the art
-- of three layers (<n>pFloor: the ring on the floor, <n>pBloom1 / 2: its
-- glow), a set for each player number. For an override: those layers show
-- the set of the player whose art lands closest, with the engine's colour
-- shift (AnimState SetHue / SetSaturation / SetBrightness, fitted in
-- data.lua so that player's colour becomes yours). Only those layers: the
-- rest of the machine stays as it is (user 19:12: "only that colour, not the
-- machine as a whole"). Its smoke and sparkles (corestone_converter_<n>p_idle
-- / _pending / _present) are per-player effects like the others.

-- The machine's player-colour layers: { ent, part ("Floor", "Bloom1"...), n }.
function Main.MachineLayers(inst)
	local out = {}
	for _, child in ipairs(inst.highlightchildren or {}) do
		local base = type(child) == "table" and rawget(child, "baseanim") or nil
		if type(base) == "string" then
			local n, part = base:match("^([1-4])p(%a%w*)$")
			if n ~= nil and child.AnimState ~= nil then
				out[#out + 1] = { ent = child, part = part, n = tonumber(n) }
			end
		end
	end
	return out
end

local function HasAnim(anim_state, name)
	if anim_state.GetCurrentBankAnimNames == nil then
		return true -- (can't ask: the four sets share one build)
	end
	local ok, names = pcall(anim_state.GetCurrentBankAnimNames, anim_state)
	if not ok or type(names) ~= "table" or next(names) == nil then
		return true
	end
	for _, n in ipairs(names) do
		if n == name then
			return true
		end
	end
	return false
end

-- A layer onto another set of art, in the same anim at the same frame.
local function SwapLayer(ent, want)
	local AS = ent.AnimState
	local old = ent.baseanim
	local okn, cur = pcall(AS.GetCurrentAnimationName, AS)
	local anim = okn and type(cur) == "string" and cur:match("^(.-)_" .. old:gsub("%p", "%%%0") .. "$") or nil
	if anim ~= nil and anim ~= "" then
		local new = anim .. "_" .. want
		if not HasAnim(AS, new) then
			return false
		end
		local okf, frame = pcall(AS.GetCurrentAnimationFrame, AS)
		ent.baseanim = want
		AS:PlayAnimation(new, anim == "idle")
		if okf and type(frame) == "number" and AS.SetFrame ~= nil then
			pcall(AS.SetFrame, AS, frame)
		end
	else
		ent.baseanim = want -- (nothing playing yet: the next anim is the new set's)
	end
	return true
end

-- key: an override colour, or nil for the game's own.
function Main.RecolourMachine(inst, idx, key)
	if inst == nil or (inst.IsValid ~= nil and not inst:IsValid()) then
		return false
	end
	local spec = Main.data ~= nil and Main.data.machines ~= nil and Main.data.machines.corestone_converter or nil
	if spec == nil then
		return false
	end
	local v = key ~= nil and spec.by[key] or nil
	if key ~= nil and v == nil then
		return false
	end
	local base = v ~= nil and v.base or idx
	local h, s, b = v ~= nil and v.hue or 0, v ~= nil and v.saturation or 1, v ~= nil and v.brightness or 1
	local layers = Main.MachineLayers(inst)
	local done = 0
	for _, L in ipairs(layers) do
		local want = base .. "p" .. L.part
		local ok = L.ent.baseanim == want or SwapLayer(L.ent, want)
		if not ok then
			-- (that set's anim isn't there: this layer keeps the game's)
			want = idx .. "p" .. L.part
			if L.ent.baseanim ~= want then
				SwapLayer(L.ent, want)
			end
			h, s, b = 0, 1, 1
		end
		local AS = L.ent.AnimState
		AS:SetHue(h)
		AS:SetSaturation(s)
		AS:SetBrightness(b)
		done = done + 1
	end
	return done > 0
end

function Main.RecolourMachines(idx)
	if not Main.settings.fx then
		return
	end
	for inst, n in pairs(Main.machines) do
		if n == idx then
			local ok, err = pcall(Main.RecolourMachine, inst, n, Main.index_key[n])
			if not ok then
				Log("the Spring Port kept its colour: " .. tostring(err))
			end
		end
	end
end

function Main.HookMachines(AddPrefabPostInit)
	if Main.data == nil or Main.data.machines == nil or Main.data.machines.corestone_converter == nil then
		return 0
	end
	for idx = 1, 4 do
		AddPrefabPostInit("corestone_converter_" .. idx .. "p", function(inst)
			Main.machines[inst] = idx
			if Main.index_key[idx] ~= nil then
				local ok, err = pcall(Main.RecolourMachine, inst, idx, Main.index_key[idx])
				if not ok then
					Log("the Spring Port kept its colour: " .. tostring(err))
				end
			end
		end)
	end
	return 4
end

-- ---------------------------------------------------------------------------
-- The farm plot signs (0.2.8; the user, 2026-11-17: "the farm plot signs, their colors don't change to the
-- players colour"). Each plot's sign (plot_sign_0..3, script farm_sign_prop) shows a leaf in the colour of
-- its owner's player number while that player is here: one anim per player number, "<player id>_sign"
-- (0_sign = player 1 ...), and "idle_sign" (a brown leaf) when nobody owns it. Only the leaf (the build's
-- "symbol" symbol) is coloured; the wood stays. The leaves are drawn in the game's player colours (about
-- 3.5% darker), the same colours as the Spring Port's art, so its fits are used: the leaf of the player
-- number whose colour lands closest, with the engine's colour shift on just that symbol.
-- The game plays its own leaf when a player comes or goes; this runs a frame later (and when a colour
-- changes), so it always acts on the leaf the game chose.
local SIGN_SYMBOL = "symbol"

local function CurrentAnim(AS)
	local ok, name = pcall(AS.GetCurrentAnimationName, AS)
	return ok and type(name) == "string" and name or nil
end

function Main.RecolourSign(inst)
	if inst == nil or (inst.IsValid ~= nil and not inst:IsValid()) or inst.AnimState == nil then
		return false
	end
	local AS = inst.AnimState
	local pid = inst.player_id
	local anim = CurrentAnim(AS)
	local owner = type(pid) == "number" and GetPlayerEntityFromPlayerID ~= nil and GetPlayerEntityFromPlayerID(pid) or nil
	if anim == nil or not anim:match("^%d_sign$") or owner == nil then
		-- the brown leaf (nobody here), or not one of the game's sign anims: no shift
		if rawget(inst, "playercolours_sign") ~= nil then
			AS:ClearSymbolColorShift(SIGN_SYMBOL)
			inst.playercolours_sign = nil
		end
		return false
	end
	local own = tostring(pid) .. "_sign"
	local idx = Main.HunterId(owner) -- (defined further down)
	local key = idx ~= nil and Main.index_key[idx] or nil
	local spec = Main.data ~= nil and Main.data.machines ~= nil and Main.data.machines.corestone_converter or nil
	local v = key ~= nil and spec ~= nil and spec.by[key] or nil
	if v == nil then
		-- the game's own colour: its own leaf, no shift
		if anim ~= own then
			AS:PlayAnimation(own)
		end
		if rawget(inst, "playercolours_sign") ~= nil then
			AS:ClearSymbolColorShift(SIGN_SYMBOL)
			inst.playercolours_sign = nil
		end
		return true
	end
	local want = tostring(v.base - 1) .. "_sign"
	if anim ~= want then
		AS:PlayAnimation(want)
	end
	AS:SetSymbolColorShift(SIGN_SYMBOL, v.hue, v.saturation, v.brightness)
	inst.playercolours_sign = key
	return true
end

function Main.RecolourSigns()
	if not Main.settings.farm_signs then
		return
	end
	for inst in pairs(Main.signs) do
		local ok, err = pcall(Main.RecolourSign, inst)
		if not ok then
			Log("a farm plot sign kept its colour: " .. tostring(err))
		end
	end
end

local function RecolourSignLater(inst)
	if inst.DoTaskInTime ~= nil then
		inst:DoTaskInTime(0, function()
			local ok, err = pcall(Main.RecolourSign, inst)
			if not ok then
				Log("a farm plot sign kept its colour: " .. tostring(err))
			end
		end)
	end
end

function Main.HookSigns(AddPrefabPostInit)
	local spec = Main.data ~= nil and Main.data.machines ~= nil and Main.data.machines.corestone_converter or nil
	if spec == nil then
		return 0
	end
	for pid = 0, 3 do
		AddPrefabPostInit("plot_sign_" .. pid, function(inst)
			Main.signs[inst] = true
			RecolourSignLater(inst)
			-- after the game's own listeners (the sign's script adds them first)
			if TheDungeon ~= nil then
				inst:ListenForEvent("playerentered", function() RecolourSignLater(inst) end, TheDungeon)
			end
			if TheWorld ~= nil then
				inst:ListenForEvent("playerexited", function() RecolourSignLater(inst) end, TheWorld)
			end
		end)
	end
	return 4
end

-- ---------------------------------------------------------------------------
-- Per-player effects

local function PushFxColours(inst, kind, v)
	if kind == "prop" then
		local base = Main.prop_cache[inst.prefab]
		if base == nil then
			local ok, PropData = pcall(require, "prefabs.prop_autogen_data")
			base = ok and type(PropData) == "table" and PropData[inst.prefab] or false
			Main.prop_cache[inst.prefab] = base
		end
		local ok_u, prefabutil = pcall(require, "prefabs.prefabutil")
		if base and ok_u and prefabutil.LoadBloomColorOverrideData ~= nil then
			local params = {}
			for k, val in pairs(base) do
				params[k] = val
			end
			params.multcolor, params.addcolor, params.glowcolor = v.multcolor, v.addcolor, v.glowcolor
			params.bloom = v.bloom or base.bloom
			prefabutil.LoadBloomColorOverrideData(inst, params)
		end
		return
	end
	local c = inst.components
	if v.multcolor ~= nil and c.colormultiplier ~= nil then
		c.colormultiplier:PushColor("fx_autogen", HexToRGBFloats(StrToHex(v.multcolor)))
	end
	if v.addcolor ~= nil and c.coloradder ~= nil then
		c.coloradder:PushColor("fx_autogen", HexToRGBFloats(StrToHex(v.addcolor)))
	end
	if v.glowcolor ~= nil and v.bloom ~= nil and c.bloomer ~= nil then
		local r, g, b = HexToRGBFloats(StrToHex(v.glowcolor))
		c.bloomer:PushBloom("fx_autogen", r, g, b, v.bloom / 100)
	end
end

-- A copy of the base player's particle def with the turned colours (made once
-- per effect and colour).
function Main.ParticleParams(fam, key)
	local per = Main.particle_cache[fam]
	if per == nil then
		per = {}
		Main.particle_cache[fam] = per
	end
	if per[key] ~= nil then
		return per[key] or nil
	end
	local entry = Main.data.particles[fam] and Main.data.particles[fam].by[key]
	local ok, PData = pcall(require, "prefabs.particles_autogen_data")
	local src = entry ~= nil and ok and type(PData) == "table" and PData[Main.NameFor(fam, entry.base)] or nil
	if src == nil then
		per[key] = false
		return nil
	end
	local params = deepcopy(src)
	for i, em in ipairs(entry.emitters) do
		local pe = params.emitters and params.emitters[i]
		if pe ~= nil then
			if em.spawn ~= nil and pe.spawn ~= nil and pe.spawn.color ~= nil then
				pe.spawn.color = em.spawn
			end
			local cc = pe.curves and pe.curves.color
			if cc ~= nil and cc.data ~= nil then
				for j, val in ipairs(em.curve) do
					cc.data[j] = val
				end
			end
		end
	end
	per[key] = params
	return params
end

function Main.RecolourFx(inst, fam, key)
	if key == nil or inst == nil or inst.components == nil then
		return false
	end
	local fx = Main.data.fx[fam]
	if fx ~= nil then
		local v = fx.by[key]
		if v ~= nil then
			PushFxColours(inst, fx.kind, v)
			return true
		end
		return false
	end
	local ps = inst.components.particlesystem
	if ps ~= nil and Main.data.particles[fam] ~= nil then
		local params = Main.ParticleParams(fam, key)
		if params == nil then
			return false
		end
		if #ps.emitters ~= #(params.emitters or {}) then
			ps:Invalidate()
		end
		ps:SetParams(params, true)
		return true
	end
	return false
end

-- Put the game's own colours back on an effect (an override was removed while
-- it was on screen).
function Main.RevertFx(inst, fam, idx)
	local fx = Main.data.fx[fam]
	local name = Main.NameFor(fam, idx)
	if fx ~= nil then
		local ok, FxData = pcall(require, fx.kind == "prop" and "prefabs.prop_autogen_data" or "prefabs.fx_autogen_data")
		local d = ok and type(FxData) == "table" and FxData[name] or nil
		if d ~= nil then
			PushFxColours(inst, fx.kind, { multcolor = d.multcolor or "FFFFFFFF", addcolor = d.addcolor or "00000000",
				glowcolor = d.glowcolor, bloom = d.bloom })
		end
	elseif inst.components.particlesystem ~= nil and inst.components.particlesystem.LoadParams ~= nil then
		inst.components.particlesystem:LoadParams(name)
	end
end

-- Called once when a per-player effect appears.
function Main.OnFxSpawn(inst, fam, idx)
	local key = Main.index_key[idx]
	if key ~= nil then
		local ok, err = pcall(Main.RecolourFx, inst, fam, key)
		if not ok then
			Log("effect " .. tostring(inst.prefab) .. " kept its colour: " .. tostring(err))
		end
	end
end

-- Hook every per-player effect prefab (only those: other spawns pay nothing).
function Main.HookFx(AddPrefabPostInit)
	local n = 0
	local function hook(fam, players)
		for _, idx in ipairs(players) do
			local name = Main.NameFor(fam, idx)
			AddPrefabPostInit(name, function(inst)
				Main.OnFxSpawn(inst, fam, idx)
			end)
			n = n + 1
		end
	end
	for fam, f in pairs(Main.data.fx or {}) do
		hook(fam, f.players)
	end
	for fam, f in pairs(Main.data.particles or {}) do
		hook(fam, f.players)
	end
	Main.fx_prefabs = n
	return n
end

-- The ring under the feet and the aim arrow already on screen.
local function FamilyOf(prefab)
	if type(prefab) ~= "string" then
		return nil
	end
	local s, e, idx = prefab:find("_p([1-4])$")
	if s == nil then
		s, e, idx = prefab:find("_p([1-4])_")
		if s == nil then
			return nil
		end
		return prefab:sub(1, s - 1) .. "_p#" .. prefab:sub(e), tonumber(idx)
	end
	return prefab:sub(1, s - 1) .. "_p#", tonumber(idx)
end
Main.FamilyOf = FamilyOf

function Main.RecolourHighlight(player, key, idx)
	local ph = player.components and player.components.playerhighlight
	if ph == nil or not Main.settings.fx then
		return
	end
	for _, fx in ipairs({ ph.highlight, ph.aim }) do
		if fx ~= nil and fx.IsValid ~= nil and fx:IsValid() then
			local fam, fidx = FamilyOf(fx.prefab)
			if fam ~= nil then
				if key ~= nil then
					Main.RecolourFx(fx, fam, key)
				else
					Main.RevertFx(fx, fam, fidx or idx)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- The few things that read the colour only when they're built (everything
-- else listens to the game's "update_ui_color" or reads the colour again
-- itself). Run once when a colour changes.

local function BarShades(hb, colour)
	if hb ~= nil and type(hb.preview_color_gain) == "table" and type(hb.preview_color_loss) == "table" then
		hb.preview_color_gain = { colour[1] * 0.75, colour[2] * 0.75, colour[3] * 0.75, colour[4] }
		hb.preview_color_loss = { colour[1] * 0.5, colour[2] * 0.5, colour[3] * 0.5, colour[4] }
		if hb.preview ~= nil and hb.preview.SetMultColor ~= nil then
			hb.preview:SetMultColor(hb.preview_color_gain)
		end
	end
end

function Main.RefreshBuiltOnce(player, idx)
	local colour = player.uicolor
	if type(colour) ~= "table" then
		return
	end
	-- the "2P" over the head
	local fid = player.follow_id
	if fid ~= nil and fid.id_widget ~= nil and fid.id_widget.SetGlyphColor ~= nil then
		fid.id_widget:SetGlyphColor(colour)
	end
	-- the interaction prompt over the head ("RB Modify Weapon Gems"): made once, its
	-- text in player.playercolor (components/interactor.lua ManifestUi), and the
	-- hold-to-interact radial if one is up
	local inter = player.components.interactor
	local pc = type(player.playercolor) == "table" and player.playercolor or colour
	if inter ~= nil then
		if inter.status_text ~= nil and inter.status_text.SetGlyphColor ~= nil then
			inter.status_text:SetGlyphColor(pc)
		end
		local li = inter.long_interact
		local radial = li ~= nil and li.radial ~= nil and li.radial.widget or nil
		if radial ~= nil and radial.SetMultColor ~= nil then
			radial:SetMultColor(pc)
		end
	end
	-- health bars' gain / loss shades (the HUD's and the one over the head)
	local dungeon = rawget(_G, "TheDungeon")
	local hud = dungeon ~= nil and dungeon.HUD or nil
	local frames = hud ~= nil and hud.player_unit_frames or nil
	local frame = frames ~= nil and frames.GetUnitFrame ~= nil and frames:GetUnitFrame(player) or nil
	BarShades(frame ~= nil and frame.health_bar or nil, colour)
	BarShades(player.follow_health_bar ~= nil and player.follow_health_bar.hp_bar or nil, colour)
	-- selection brackets on screens already open
	local fe = rawget(_G, "TheFrontEnd")
	for _, s in ipairs(fe ~= nil and fe.screenstack or {}) do
		local fb = s.focus_brackets and s.focus_brackets[idx]
		if fb ~= nil and fb.bottom ~= nil and fb.bottom.SetMultColor ~= nil then
			fb.bottom:SetMultColor(UICOLORS.PLAYERS[idx])
		end
	end
	-- quest markers over NPCs marked for this player
	local world = rawget(_G, "TheWorld")
	local mm = world ~= nil and world.components ~= nil and world.components.npcmarkmanager or nil
	for _, marker in pairs(mm ~= nil and mm.marked_npcs or {}) do
		local nm = marker.components and marker.components.npcmarker
		if nm ~= nil and nm.fx ~= nil and nm._RefreshPlayers ~= nil then
			nm:_RefreshPlayers()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Players

local function HunterId(player)
	if player == nil or player.GetHunterId == nil then
		return nil
	end
	local ok, id = pcall(player.GetHunterId, player)
	if ok and type(id) == "number" and id >= 1 and id <= 4 then
		return id
	end
	return nil
end
Main.HunterId = HunterId

-- Put this character's colour in place and let the game recolour itself.
function Main.Apply(player, force)
	if player == nil or player.components == nil or player.components.playercolour == nil then
		return false
	end
	if player.IsLocal ~= nil and not player:IsLocal() then
		return false
	end
	local idx = HunterId(player)
	if idx == nil then
		return false
	end
	local key = player.components.playercolour:GetKey()
	local state = idx .. ":" .. tostring(key)
	if not force and player.playercolours_applied == state then
		return true
	end
	local prev_idx = player.playercolours_idx
	if prev_idx ~= nil and prev_idx ~= idx and Main.index_owner[prev_idx] == player then
		Main.SetIndexColour(prev_idx, nil)
	end
	if key == nil and Main.index_key[idx] == nil and player.playercolours_applied == nil then
		-- vanilla and nothing to undo: the game already did it all
		player.playercolours_applied = state
		player.playercolours_idx = idx
		return true
	end
	Main.SetIndexColour(idx, key, player)
	player.playercolours_applied = state
	player.playercolours_idx = idx
	player:PushEvent("update_skin_color") -- the game's own SetPlayerColor + "update_ui_color"
	Main.RecolourHighlight(player, key, idx)
	local ok, err = pcall(Main.RefreshBuiltOnce, player, idx)
	if not ok then
		Log("refresh after the change skipped a part: " .. tostring(err))
	end
	Debug("player " .. idx .. ": " .. tostring(key or "vanilla"))
	return true
end

-- A player left / the room is unloading: the game's colours back for its number.
function Main.Release(player)
	local idx = player ~= nil and player.playercolours_idx or nil
	if idx ~= nil and Main.index_owner[idx] == player then
		Main.SetIndexColour(idx, nil)
	end
end

function Main.SetupPlayer(inst)
	if inst.components == nil or inst.components.playercolour ~= nil then
		return
	end
	inst:AddComponent("playercolour")
	inst:ListenForEvent("on_player_set", function(p) Main.Apply(p) end)
	inst:ListenForEvent("onremove", function(p) Main.Release(p) end)
end

return Main
