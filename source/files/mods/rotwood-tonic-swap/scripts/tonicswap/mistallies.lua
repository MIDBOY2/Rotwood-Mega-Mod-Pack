-- Tonic Swap: Misting Mixture and your allies.
--
-- Misting heals you every second (misting_heals times). Each heal also heals
-- allies near you by their share (the game: powerutil.DoPotionHeal ->
-- PotionDrinker:StartAOEHeal, a 6-frame window that heals friendlies within
-- the potion radius, TUNING.POTION_AOE_RADIUS_DEFAULT 6 plus talents; 40% of
-- your heal plus talents). An ally who isn't next to you at that moment gets
-- nothing, and nothing shows it.
--
-- misting_allies:
--   "link" (default): an ally a heal reaches is linked for the rest of that
--          drink and gets their share every second wherever they go (drinking
--          again while it heals keeps the links, like the heals left).
--   "game": only who's next to you at each heal.
-- What each heal shows, from the second on (drinking shows the game's ring):
-- misting_pulse, on the ground at you:
--   "none" (default): nothing.
--   "wave" ("heal_area" is the same): the green heal area (the one
--          the Hazard Idol's ground ring is made from, fx_ground_heal_area)
--          grows out from you to your reach, stays a moment and fades. It's
--          a child of you, like the Idol's area of the Idol, and is stopped
--          for everyone (MakeEventStopEffect), so no copy is left behind
--          online. (0.6.2 played only its fade-out, 6 frames = 0.2 s, which
--          barely showed.)
--   "ring": the game's drink ring (SGPlayerCommon.Fns.ShowAOEHealPreview).
-- misting_glow = true: everyone it heals glows green like drinking does
--   (SGCommon.Fns.DoPotionColorSequence, what Gourdo's heal aura does to
--   whoever it heals) with a small green heal burst (fx_heal_burst_sml, the
--   drink's burst at a smaller size, without its sound).
-- misting_beams = true: a green heal beam from you to each ally it heals (the
--   Gourdo seed's heal beam, what the Head Hunter power shows when it heals
--   allies: SGCommon.Fns.DoGourdoHealBeamFx). The game scales the whole beam
--   with its length (util.lua FakeBeamFXWithPositions: x and z both by the
--   distance's scale), made for Gourdo's few units: it's one small picture
--   (the anim's wavy ribbon, about 320 x 60 pixels), so a linked ally across
--   the room got it blown up 3 to 5 times, blurry. misting_beam_style:
--   "chain" (default): near allies get the game's beam as it is; farther,
--     the line is cut into pieces of about misting_beam_piece units and each
--     gets the game's own small beam for that length (FakeBeamFXWithPositions
--     with its small-beam table: the picture at the size it was drawn for),
--     one after another from you to the ally (misting_beam_ripple seconds
--     apart), at most misting_beam_max_pieces.
--   "thin" (0.7.x): one game beam at its length, its width thinner and its
--     colour fainter the farther the ally is (stretched).
--   "game": the game's beam at any distance.
--   Fainter farther away (misting_beam_fade_*, on your screen) and none past
--   misting_beam_max_distance in "chain" and "thin".
-- misting_marks = true: the small green ring around the feet
--   (heal_aoe_ring_affected, what the drink ring puts on allies) of everyone
--   under the potion: you, the linked allies and the allies in reach.
local MistAllies = {}

MistAllies.ALLIES = { link = true, game = true }
MistAllies.PULSES = { wave = true, ring = true, none = true }
MistAllies.FRIENDLY_ID = "misting_potion_friendly" -- the game's id for Misting's ally heals (pow.def.name .. "_friendly")
MistAllies.WAVE_FX = "fx_ground_heal_area" -- in the player's skill effects (fx group player_skills), loaded with every player
MistAllies.WAVE_SCALE_PER_RADIUS = 5.5 / 10 -- the Hazard Idol: scale 5.5 for its radius 10
MistAllies.WAVE_CHILD_ID = 7311 -- (16-bit) one wave per player at a time
MistAllies.WAVE_START = 0.25 -- its size when it starts, of the full size
MistAllies.WAVE_GROW = 0.35 -- seconds to grow to your reach
MistAllies.WAVE_HOLD = 0.6 -- seconds from the start to the fade (its fade-out: 0.2 s)
MistAllies.WAVE_FADE = 0.2
MistAllies.BURST_FX = "fx_heal_burst_sml" -- fx group healing, loaded with every player
MistAllies.BEAM_FX = "fx_gourdo_seed_heal_beam" -- _sml / _lrg, loaded with every player (the Head Hunter power's)
MistAllies.MARK_FX = "heal_aoe_ring_affected"
MistAllies.STYLES = { chain = true, thin = true, game = true }
-- the game's small heal beam: units -> scale (sg_common.lua _gourdo_healbeamfx_small, a local there)
MistAllies.SMALL_BEAM = { { 0, 0.5 }, { 1.8, 0.9 }, { 3.2, 1.15 }, { 5.7, 1.3 }, { 9.2, 1.6 }, { 13.2, 1.8 }, { 15, 1.9 } }
MistAllies.SMALL_UNTIL = 14 -- (the game takes its large beam from 15 units)

local settings = { link = true, pulse = "none", glow = true, beams = true, marks = true,
	beam_style = "chain", beam_thin = true, beam_piece = 6, beam_max_pieces = 8, beam_ripple = 0.04,
	beam_full_until = 6, beam_min_width = 0.3, beam_fade_from = 8, beam_fade_to = 30, beam_min_alpha = 0.3, beam_max = 50 }
MistAllies.settings = settings

local function Distance2(a, b)
	if a.Transform == nil or b.Transform == nil then
		return math.huge
	end
	local ax, az = a.Transform:GetWorldXZ()
	local bx, bz = b.Transform:GetWorldXZ()
	return (ax - bx) * (ax - bx) + (az - bz) * (az - bz)
end

local function Healable(ent, healer)
	if ent == nil or ent == healer or not ent:IsValid() or ent.components == nil then
		return false
	end
	local health = ent.components.health
	if health == nil or ent.components.combat == nil then
		return false
	end
	if health.IsDead ~= nil and health:IsDead() then
		return false
	end
	return true
end

-- the allies linked to this drinker's Misting (weak: a removed ally drops out)
local function Links(self)
	local links = rawget(self, "tonicswap_mist_links")
	if links == nil then
		links = setmetatable({}, { __mode = "k" })
		self.tonicswap_mist_links = links
	end
	return links
end

-- a new Misting drink starts with no links; drinking again while it heals
-- (tonicswap/potions.lua sets tonicswap_mist_carry) keeps them
-- (true: this drink's first heal)
local function Begin(self, pow)
	if rawget(self, "tonicswap_mist_pow") == pow then
		return false
	end
	self.tonicswap_mist_pow = pow
	if not rawget(self, "tonicswap_mist_carry") then
		self.tonicswap_mist_links = nil
	end
	self.tonicswap_mist_carry = nil
	return true
end

-- linked allies out of the heal's reach get their share now
local function HealLinked(self)
	local inst = self.inst
	local amount, id, radius = rawget(self, "aoe_heal_amount"), rawget(self, "aoe_heal_id"), rawget(self, "aoe_heal_radius")
	local Attack = rawget(_G, "Attack")
	if amount == nil or radius == nil or Attack == nil then
		return 0
	end
	local healed = rawget(self, "targets_healed_by_aoe") or {}
	local n = 0
	for ent in pairs(Links(self)) do
		if Healable(ent, inst) and Distance2(ent, inst) > radius * radius and not table.contains(healed, ent) then
			local heal = Attack(inst, ent)
			heal:SetHeal(math.min(amount, ent.components.health:GetMissing()))
			heal:SetID(id)
			ent.components.combat:ApplyHeal(heal)
			healed[#healed + 1] = ent -- (the game's window won't heal them again)
			n = n + 1
		end
	end
	return n
end

-- everyone under the potion this heal: you, linked allies, allies in reach
function MistAllies.UnderPotion(self)
	local inst = self.inst
	local list, seen = { inst }, { [inst] = true }
	if settings.link then
		for ent in pairs(Links(self)) do
			if not seen[ent] and Healable(ent, inst) then
				seen[ent] = true
				list[#list + 1] = ent
			end
		end
	end
	local radius = rawget(self, "aoe_heal_radius")
	local find = rawget(_G, "FindTargetTagGroupEntitiesInRange")
	local combat = inst.components ~= nil and inst.components.combat or nil
	if radius ~= nil and find ~= nil and combat ~= nil and combat.GetFriendlyTargetTags ~= nil and inst.Transform ~= nil then
		local x, z = inst.Transform:GetWorldXZ()
		for _, ent in ipairs(find(x, z, radius, combat:GetFriendlyTargetTags(), { "prop" }) or {}) do
			if not seen[ent] and Healable(ent, inst) then
				seen[ent] = true
				list[#list + 1] = ent
			end
		end
	end
	return list
end

-- the green heal area grows out from you to your reach, stays a moment and
-- fades; then it's stopped for everyone
function MistAllies.Wave(self)
	local inst = self.inst
	local radius = rawget(self, "aoe_heal_radius") or 6
	local EffectEvents = require "effectevents"
	local orientation = rawget(_G, "ANIM_ORIENTATION")
	local full = radius * MistAllies.WAVE_SCALE_PER_RADIUS
	local id = MistAllies.WAVE_CHILD_ID
	local fx = EffectEvents.MakeEventSpawnEffect(inst, {
		fxname = MistAllies.WAVE_FX,
		ischild = true,
		childid = id,
		scalex = full, scalez = full,
		orientation = orientation ~= nil and orientation.OnGroundFixed or nil,
	})
	if fx == nil or fx.AnimState == nil then
		return fx
	end
	-- here: from its start (fades in) and growing; elsewhere it shows full size
	fx.AnimState:SetFrame(0)
	fx.AnimState:SetScale(full * MistAllies.WAVE_START, full * MistAllies.WAVE_START)
	local now = rawget(_G, "GetTime")
	local start = now ~= nil and now() or 0
	local faded = false
	fx.tonicswap_wave_task = fx:DoPeriodicTask(0, function()
		if not fx:IsValid() then
			return
		end
		local t = (now ~= nil and now() or start) - start
		local k = math.min(1, t / MistAllies.WAVE_GROW)
		k = 1 - (1 - k) * (1 - k) -- (eases out)
		local s = full * (MistAllies.WAVE_START + (1 - MistAllies.WAVE_START) * k)
		fx.AnimState:SetScale(s, s)
		if not faded and t >= MistAllies.WAVE_HOLD then
			faded = true
			fx.AnimState:PlayAnimation("pst", false)
		end
	end)
	-- stopped for everyone (the area itself loops)
	inst:DoTaskInTime(MistAllies.WAVE_HOLD + MistAllies.WAVE_FADE, function()
		local current = inst:IsValid() and rawget(inst, MistAllies.WAVE_FX .. id) or nil
		if inst:IsValid() and (current == nil or current == fx) then -- (not a newer wave)
			EffectEvents.MakeEventStopEffect(inst, MistAllies.WAVE_FX, id)
		end
		if fx:IsValid() then
			fx:Remove()
		end
	end)
	return fx
end

-- green glow and a small heal burst on someone it heals
function MistAllies.Glow(ent)
	local SGCommon = require "stategraphs.sg_common"
	if ent.components.coloradder ~= nil and ent.components.bloomer ~= nil then
		SGCommon.Fns.DoPotionColorSequence(ent)
	end
	local EffectEvents = require "effectevents"
	return EffectEvents.MakeEventSpawnEffect(ent, { fxname = MistAllies.BURST_FX })
end

-- a beam this long: its width (of the game's) and how visible it is (0-1)
function MistAllies.BeamLook(dist)
	if settings.beam_style == "game" then
		return 1, 1
	end
	local width = 1
	if settings.beam_style == "thin" and dist > settings.beam_full_until and dist > 0 then
		width = math.max(settings.beam_min_width, settings.beam_full_until / dist)
	end
	local alpha = 1
	local a, b = settings.beam_fade_from, settings.beam_fade_to
	if dist >= b then
		alpha = settings.beam_min_alpha
	elseif dist > a then
		alpha = 1 - (1 - settings.beam_min_alpha) * (dist - a) / (b - a)
	end
	return width, alpha
end

-- runs the game's beam code; the fx it spawns is caught on its way out
local function Caught(fn, ...)
	local EffectEvents = require "effectevents"
	local spawn = EffectEvents.MakeEventSpawnEffect
	local caught = nil
	EffectEvents.MakeEventSpawnEffect = function(...)
		local fx = spawn(...)
		caught = caught or fx
		return fx
	end
	local ok, err = pcall(fn, ...)
	EffectEvents.MakeEventSpawnEffect = spawn
	if not ok then
		error(err, 0)
	end
	return caught
end

local function Fade(fx, alpha)
	local anim = fx ~= nil and fx.AnimState or nil
	if alpha < 1 and anim ~= nil and anim.SetMultColour ~= nil then
		anim:SetMultColour(1, 1, 1, alpha)
	end
end

-- how many pieces for a beam this long (1: the game's own beam)
function MistAllies.Pieces(dist)
	local piece = settings.beam_piece
	if piece <= 0 then
		return 1
	end
	local n = math.floor(dist / piece + 0.5)
	n = math.min(n, settings.beam_max_pieces)
	-- (each piece is the game's small beam: below 15 units)
	n = math.max(n, math.ceil(dist / MistAllies.SMALL_UNTIL))
	return math.max(1, n)
end

-- "chain": the game's small beam for each piece, from you to the ally
function MistAllies.Chain(inst, ally, n, alpha)
	local Vec = rawget(_G, "Vector3")
	local fake = rawget(_G, "FakeBeamFXWithPositions")
	assert(Vec ~= nil and fake ~= nil, "Vector3 / FakeBeamFXWithPositions")
	local a, b = inst:GetPosition(), ally:GetPosition()
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	local name, tbl = MistAllies.BEAM_FX, MistAllies.SMALL_BEAM
	local made = {}
	local function One(i)
		if not inst:IsValid() then
			return
		end
		local t0, t1 = (i - 1) / n, i / n
		local p0 = Vec(a.x + dx * t0, a.y + dy * t0, a.z + dz * t0)
		local p1 = Vec(a.x + dx * t1, a.y + dy * t1, a.z + dz * t1)
		local fx = Caught(fake, p0, p1, name, tbl, tbl, inst)
		Fade(fx, alpha)
		made[#made + 1] = fx
	end
	local ripple = settings.beam_ripple
	for i = 1, n do
		if i == 1 or ripple <= 0 or inst.DoTaskInTime == nil then
			One(i)
		else
			inst:DoTaskInTime(ripple * (i - 1), function()
				local ok, err = pcall(One, i)
				if not ok then
					print("[Tonic Swap] Misting beam piece: " .. tostring(err))
				end
			end)
		end
	end
	return made
end

-- the heal beam from you to an ally: the game's (its anim, length and the
-- network event); "chain" cuts a long one into the game's small beams
function MistAllies.Beam(inst, ally)
	local SGCommon = require "stategraphs.sg_common"
	local dist = math.sqrt(Distance2(inst, ally))
	if settings.beam_style ~= "game" and settings.beam_max > 0 and dist > settings.beam_max then
		return nil
	end
	local width, alpha = MistAllies.BeamLook(dist)
	if settings.beam_style == "chain" then
		local n = MistAllies.Pieces(dist)
		-- (without the game's beam code by position: its one beam)
		if n > 1 and rawget(_G, "Vector3") ~= nil and rawget(_G, "FakeBeamFXWithPositions") ~= nil then
			return MistAllies.Chain(inst, ally, n, alpha)
		end
	end
	if width >= 1 and alpha >= 1 then
		SGCommon.Fns.DoGourdoHealBeamFx(inst, inst, ally, MistAllies.BEAM_FX)
		return nil
	end
	local caught = Caught(SGCommon.Fns.DoGourdoHealBeamFx, inst, inst, ally, MistAllies.BEAM_FX)
	local anim = caught ~= nil and caught.AnimState or nil
	if anim ~= nil then
		if width < 1 and anim.GetScale ~= nil then
			local sx, sy = anim:GetScale()
			if type(sx) == "number" and type(sy) == "number" then
				anim:SetScale(sx, sy * width)
			end
		end
		if alpha < 1 and anim.SetMultColour ~= nil then
			anim:SetMultColour(1, 1, 1, alpha)
		end
	end
	return caught
end

-- one Misting heal (its ally window has just started)
function MistAllies.Tick(self, pow)
	local first = Begin(self, pow)
	if settings.link then
		HealLinked(self)
	end
	-- (the drink itself shows the game's ring and marks: from the second heal on)
	if first then
		return
	end
	local inst = self.inst
	if settings.pulse == "ring" then
		local SGPlayerCommon = require "stategraphs.sg_player_common"
		SGPlayerCommon.Fns.ShowAOEHealPreview(inst)
	elseif settings.pulse == "wave" then
		MistAllies.Wave(self)
	end
	local marks = settings.marks and settings.pulse ~= "ring" -- (the ring marks allies in reach itself)
	if not (marks or settings.glow or settings.beams) then
		return
	end
	local powerutil = marks and require "util.powerutil" or nil
	for _, ent in ipairs(MistAllies.UnderPotion(self)) do
		if marks then
			powerutil.SpawnParticlesOnEntity(ent, MistAllies.MARK_FX, nil, 0)
		end
		if settings.glow then
			MistAllies.Glow(ent)
		end
		if settings.beams and ent ~= inst then
			MistAllies.Beam(inst, ent)
		end
	end
end

-- the game's window healed someone: linked for the rest of the drink
function MistAllies.Collect(self)
	if not settings.link or rawget(self, "aoe_heal_id") ~= MistAllies.FRIENDLY_ID then
		return
	end
	local links = Links(self)
	for _, ent in ipairs(rawget(self, "targets_healed_by_aoe") or {}) do
		if Healable(ent, self.inst) then
			links[ent] = true
		end
	end
end

-- s: Tonic Swap's potion settings. G: its guard. Returns ok, info.
function MistAllies.Install(s, G, misting_power)
	local allies = s.misting_allies
	if allies == "both" or allies == "wave" then
		allies = "link" -- (0.6.1's names)
	end
	local pulse = s.misting_pulse
	if pulse == "heal_area" then
		pulse = "wave" -- (0.6.2's name)
	end
	settings.link = allies ~= "game"
	settings.pulse = MistAllies.PULSES[pulse] and pulse or "none"
	settings.glow = s.misting_glow ~= false
	settings.beams = s.misting_beams ~= false
	settings.marks = s.misting_marks ~= false
	local style = s.misting_beam_style
	if style == nil then
		style = s.misting_beam_thin == false and "game" or "chain" -- (0.7.x had only misting_beam_thin)
	end
	if not MistAllies.STYLES[style] then
		print("[Tonic Swap] bad setting misting_beam_style = " .. tostring(style) .. " (chain, thin or game): using chain")
		style = "chain"
	end
	settings.beam_style = style
	settings.beam_thin = style ~= "game"
	settings.beam_piece = tonumber(s.misting_beam_piece) or 6
	settings.beam_max_pieces = math.max(1, math.floor(tonumber(s.misting_beam_max_pieces) or 8))
	settings.beam_ripple = math.max(0, tonumber(s.misting_beam_ripple) or 0.04)
	settings.beam_full_until = tonumber(s.misting_beam_full_until) or 6
	settings.beam_min_width = tonumber(s.misting_beam_min_width) or 0.3
	settings.beam_fade_from = tonumber(s.misting_beam_fade_from) or 8
	settings.beam_fade_to = math.max(settings.beam_fade_from, tonumber(s.misting_beam_fade_to) or 30)
	settings.beam_min_alpha = tonumber(s.misting_beam_min_alpha) or 0.3
	settings.beam_max = tonumber(s.misting_beam_max_distance) or 50
	if not settings.link and settings.pulse == "none" and not settings.marks and not settings.glow and not settings.beams then
		return false, "the game's"
	end
	local PotionDrinker = require "components.potiondrinker"
	assert(type(PotionDrinker.StartAOEHeal) == "function", "PotionDrinker:StartAOEHeal")
	assert(type(PotionDrinker.TriggerAOEHeal) == "function", "PotionDrinker:TriggerAOEHeal")
	MistAllies.FRIENDLY_ID = misting_power .. "_friendly"

	if not rawget(PotionDrinker, "tonicswap_mist_hooked") then
		PotionDrinker.tonicswap_mist_hooked = true
		local orig_start = PotionDrinker.StartAOEHeal
		PotionDrinker.StartAOEHeal = function(self, pow, ...)
			local results = table.pack(orig_start(self, pow, ...))
			local def = pow ~= nil and pow.def or nil
			if def ~= nil and def.name == misting_power then
				G.Call("Misting allies", MistAllies.Tick, self, pow)
			end
			return table.unpack(results, 1, results.n)
		end
		local orig_trigger = PotionDrinker.TriggerAOEHeal
		PotionDrinker.TriggerAOEHeal = function(self, ...)
			local results = table.pack(orig_trigger(self, ...))
			G.Call("Misting links", MistAllies.Collect, self)
			return table.unpack(results, 1, results.n)
		end
	end
	local parts = {}
	parts[#parts + 1] = settings.link and "linked allies" or "allies in reach"
	parts[#parts + 1] = settings.pulse == "wave" and "growing green wave" or settings.pulse == "ring" and "healing ring" or "no pulse"
	if settings.glow then
		parts[#parts + 1] = "green glow"
	end
	if settings.beams then
		parts[#parts + 1] = settings.beam_style == "chain" and "heal beams (far: a chain of the game's small beams)"
			or settings.beam_style == "thin" and "heal beams (thinner far away)" or "heal beams"
	end
	if settings.marks and settings.pulse ~= "ring" then
		parts[#parts + 1] = "green rings on everyone healed"
	end
	return true, table.concat(parts, " + ")
end

return MistAllies
