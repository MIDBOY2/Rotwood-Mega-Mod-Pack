-- Tonic Swap: the game's three potions, picked in town (the tonic menu's Potion
-- column). The game only ever gives you Soothing Spirits; Bubbling Brew and
-- Misting Mixture are finished in its files but hidden. This makes them
-- yours, keeps them in your inventory, and fixes what the game left behind:
--   * Bubbling Brew: every charge is 2 sips (the game's own number, which it
--     no longer reads), 100 health each; your tonic comes with every sip (its
--     one benefit: two drinks' time for less health). Potent Brew's flat bonus
--     counts half per sip. Everything else that reacts to drinking (Iron
--     Brew's shield, the frost freeze, Cleaver berserk, the curses' counters,
--     Immorel's refills) counts once per potion, and a free drink (the shop's
--     potion drunk on the spot, the potion event when you're full) is a whole
--     potion. The HUD counts sips: 3 charges show 6.
--   * Misting Mixture: 30 health every second, 10 times (the game: 50 x 15,
--     with every flat bonus added to each heal). Flat bonuses count 1.2x for a
--     drink, spread over the 10 heals (Potent Brew: +3 a heal per rank). Drinking it again while it heals starts the 10 again and
--     keeps the healing that was left (the game wasted the drink).
--   * their bottles in the drink animation: the mod's own art files
--     (anim/potion_health_bubble.zip, anim/potion_health_mist.zip, made from
--     Soothing's bottle and the potions' icons), or Soothing's bottle in
--     their colours (potion_bottles = "recolour").
-- Everything else is the game's own: charges (Field Medicine, refills,
-- Double Pour, Perfect Pairing), % bonuses, healing allies around you, powers
-- that react to drinking. Equipping uses the game's potion slot, so the HUD
-- icon, the bottle and loadouts follow by themselves. The talent menu's
-- potion picture (Field Medicine) shows each player's own potion.

local Equipment = require "defs.equipment"
local Power = require "defs.powers"
local EquipInSlot = require "tonicswap.equip"
-- bulletproofing (tonicswap/guard.lua): this mod's part of the potion code
-- runs through G; an error is logged and the game does it its own way
local G = require("tonicswap.guard").Shared("[Tonic Swap]")

local Potions = {}

Potions.SLOT = "POTIONS"
Potions.ORDER = { "heal1", "quick_heal1", "duration_heal1" }
Potions.HIDDEN = { quick_heal1 = true, duration_heal1 = true }
Potions.BUBBLING, Potions.MISTING = "quick_heal1", "duration_heal1"
Potions.BUBBLING_POWER, Potions.MISTING_POWER = "bubbling_potion", "misting_potion"
Potions.SOOTHING, Potions.SOOTHING_POWER = "heal1", "soothing_potion"
Potions.BOTTLES = { quick_heal1 = "potion_health_bubble", duration_heal1 = "potion_health_mist" }
Potions.SOOTHING_BOTTLE = "potion_health_sooth"
-- Soothing's bottle in their colours (hue turn, saturation x, brightness x)
Potions.RECOLOUR = { quick_heal1 = { 0.15, 0.75, 1.2 }, duration_heal1 = { 0.71, 0.55, 1.25 } }
Potions.BOTTLE_SYMBOL = "flask_line01"
-- the bottle smash at the end of the drink (the same effect for every potion):
-- the mod's copies with the shards in their glass colours
Potions.SMASH_FX = "fx_player_flask_smash_glass"
Potions.SMASH_BUILDS = { quick_heal1 = "fx_player_flask_smash_bubble", duration_heal1 = "fx_player_flask_smash_mist" }
Potions.SMASH_SYMBOL = "break_frames"
-- the HUD's empty-potion icons in Soothing's style (the mod's images folder)
Potions.HUD_EMPTY = {
	quick_heal1 = "images/tonicswap_potions/icon_hud_empty_potion_health_bubble.tex",
	duration_heal1 = "images/tonicswap_potions/icon_hud_empty_potion_health_mist.tex",
}
-- the HUD's potion icons (potion_hud_icons; the item's ui_icons, which the
-- game's potion widget draws): "mix" = higher-contrast full and empty icons
-- (half the originals, half a Soothing-like version), "classic" = the game's
-- full icon + the empty above, "game" = the game's own both
Potions.HUD_ICONS = {
	mix = {
		quick_heal1 = { ready = "images/tonicswap_potions/icon_hud_ready_potion_health_bubble_mix.tex",
			consumed = "images/tonicswap_potions/icon_hud_empty_potion_health_bubble_mix.tex" },
		duration_heal1 = { ready = "images/tonicswap_potions/icon_hud_ready_potion_health_mist_mix.tex",
			consumed = "images/tonicswap_potions/icon_hud_empty_potion_health_mist_mix.tex" },
	},
	classic = {
		quick_heal1 = { consumed = Potions.HUD_EMPTY.quick_heal1 },
		duration_heal1 = { consumed = Potions.HUD_EMPTY.duration_heal1 },
	},
	game = {},
}
Potions.GAME_ICONS_KEY = "tonicswap_game_icons"

-- the game's own HUD icon for a potion (its ui_icons before the mod's), for
-- pictures inside texts
function Potions.GameIcon(def, state)
	local ui = def ~= nil and def.ui_icons or nil
	if type(ui) ~= "table" then
		return nil
	end
	local game = rawget(ui, Potions.GAME_ICONS_KEY)
	local tex = type(game) == "table" and game[state] or ui[state]
	return type(tex) == "string" and tex or nil
end

-- the game's potion picture in talent texts (Field Medicine's charges)
Potions.HUD_POTION = "images/hud_images/hud_potion.tex"
-- the talent line's picture: the HUD bottle cropped to fill the line (the
-- game's HUD icon has a wide empty border), in the mod's atlas. Drawn as an
-- Image next to the number: a picture inside a text can only come from the
-- game's own atlases (the mod's showed nothing, by any path).
Potions.TALENT_PICTURE = {
	quick_heal1 = "images/tonicswap_potions/icon_talent_potion_health_bubble.tex",
	duration_heal1 = "images/tonicswap_potions/icon_talent_potion_health_mist.tex",
}
Potions.TALENT_ASPECT = { quick_heal1 = 106 / 162, duration_heal1 = 112 / 160 } -- width / height
-- the same crop of the "mix" HUD icons (potion_hud_icons = "mix")
Potions.TALENT_PICTURE_MIX = {
	quick_heal1 = "images/tonicswap_potions/icon_talent_potion_health_bubble_mix.tex",
	duration_heal1 = "images/tonicswap_potions/icon_talent_potion_health_mist_mix.tex",
}
Potions.TALENT_ASPECT_MIX = { quick_heal1 = 110 / 166, duration_heal1 = 116 / 164 }

Potions.DEFAULTS = {
	potions = true,
	potion_bottles = "own", -- "own", "recolour" or "soothing"
	potion_hud_icons = "mix", -- with "own": "mix", "classic" or "game"
	bubbling_sips = 2,
	bubbling_flat_share = 0.5,
	misting_heal = 30,
	misting_heals = 10,
	misting_flat_share = 1.2, -- a drink gets 1.2x the flat bonuses (Potent Brew 10: 300 + 300 = 600), spread over its heals
	misting_restart = true,
	misting_allies = "link", -- "link" / "game" (tonicswap/mistallies.lua)
	misting_pulse = "none", -- each heal: "none" / "wave" (the green area grows out to your reach) / "ring"
	misting_glow = true, -- each heal: everyone healed glows green, with a small heal burst
	misting_beams = true, -- each heal: a heal beam from you to each ally healed
	misting_marks = true, -- each heal: the small green ring at the feet of everyone healed
	misting_beam_style = nil, -- "chain" (far allies: a chain of the game's small beams), "thin" or "game"; nil: misting_beam_thin decides (0.7.7)
	misting_beam_thin = true, -- (0.7.7) false: the game's beam at any distance
	misting_beam_piece = 6, -- "chain": units per piece (each the game's small beam)
	misting_beam_max_pieces = 8,
	misting_beam_ripple = 0.04, -- "chain": seconds between pieces, from you to the ally (0: all at once)
	misting_beam_full_until = 6, -- units: the game's width up to here (your reach is 6)
	misting_beam_min_width = 0.3, -- the narrowest, of the game's width
	misting_beam_fade_from = 8, -- units: fading from here...
	misting_beam_fade_to = 30, -- ...to misting_beam_min_alpha here
	misting_beam_min_alpha = 0.3,
	misting_beam_max_distance = 50, -- farther: no beam (the ally still glows); 0 = no limit
	talent_picture = "hud", -- "hud", "hud_small" or "inventory"
	bubbling_hud_sips = true, -- the HUD / character panel / over-head potion count sips (3 charges = 6)
	bubbling_per_potion = true, -- powers that react to drinking count once per potion; a free drink is a whole potion
	potion_heal_log = false, -- probe: each drink's heal and what it was worked out from, in the log
	potion_heals = "current", -- "current" or a trial set of base heals (Potions.HEAL_SETS)
}

-- Trial sets of base heals (potion_heals). Each potion's heal with no Potent
-- Brew -> with Potent Brew 10 (+250 flat, times the potion's share):
--   current:          Soothing 250 -> 500, Bubbling 100 / 200 a charge -> 225 / 450,
--                     Misting 300 -> 600 (the game's, and misting_heal / misting_flat_share)
--   experimental:     Soothing 300 -> 600, Bubbling 125 / 250 -> 250 / 500, Misting 350 -> 700
--   experimental_375: the same, Misting 375 -> 750 (37.5 a heal: the game rounds each
--                     heal down, so 37 a heal, 370 a drink with no Potent Brew)
Potions.HEAL_SETS = {
	experimental = { soothing_heal = 300, soothing_flat_share = 1.2, bubbling_heal = 125, misting_heal = 35, misting_flat_share = 1.4 },
	experimental_375 = { soothing_heal = 300, soothing_flat_share = 1.2, bubbling_heal = 125, misting_heal = 37.5, misting_flat_share = 1.5 },
}

-- Powers that react to drinking (Bubbling Brew, bubbling_per_potion): once per
-- potion, on its first sip; these on its last sip instead (their counter or
-- refill belongs to the whole potion: Forbidden Drink's x2 heal lasts through
-- its third potion's both sips, Immorel refills when a charge is used up).
Potions.LAST_SIP = { forbidden_drink = true, immorel_waist = true }
-- a power whose heal modifier counts drinks: the count goes up on the last sip
Potions.COUNTS_ON_HEAL = { diluted_medicine = true }

Potions.STR = {
	BUBBLING_DESC = "Immediately <#RED>Heal</> for <#RED>{heal} Health</> a sip. Each charge is <#RED>%d sips</>, and your tonic comes with every sip.",
	MISTING_DESC = "<#RED>Heal</> for <#RED>{heal} Health</> right away, then every second, <#RED>{num_heals}</> heals in all.",
	MISTING_RESTART = " Drinking it again starts the heals over and keeps the healing that was left.",
}

function Potions.LoadSettings(user)
	local s = {}
	for k, v in pairs(Potions.DEFAULTS) do
		local u = nil
		if type(user) == "table" then
			u = user[k]
		end
		if u ~= nil and type(u) == type(v) then
			s[k] = u -- (false too)
		else
			s[k] = v
		end
	end
	-- (no default: a settings file without it keeps 0.7.7's misting_beam_thin)
	if type(user) == "table" and type(user.misting_beam_style) == "string" then
		s.misting_beam_style = user.misting_beam_style
	end
	if s.potion_bottles ~= "own" and s.potion_bottles ~= "recolour" and s.potion_bottles ~= "soothing" then
		s.potion_bottles = "own"
	end
	if Potions.HUD_ICONS[s.potion_hud_icons] == nil then
		print("[Tonic Swap] bad setting potion_hud_icons = " .. tostring(s.potion_hud_icons) .. " (mix, classic or game): using mix")
		s.potion_hud_icons = "mix"
	end
	if s.talent_picture ~= "hud" and s.talent_picture ~= "hud_small" and s.talent_picture ~= "inventory" then
		s.talent_picture = "hud"
	end
	local set = Potions.HEAL_SETS[s.potion_heals]
	if set == nil then
		s.potion_heals = "current"
	else
		for k, v in pairs(set) do
			s[k] = v
		end
	end
	s.bubbling_sips = math.max(1, math.floor(s.bubbling_sips))
	s.misting_heals = math.max(1, math.floor(s.misting_heals))
	s.misting_flat_share = math.max(0, s.misting_flat_share)
	s.bubbling_flat_share = math.max(0, s.bubbling_flat_share)
	s.misting_beam_full_until = math.max(0, s.misting_beam_full_until)
	s.misting_beam_min_width = math.min(1, math.max(0.05, s.misting_beam_min_width))
	s.misting_beam_fade_from = math.max(0, s.misting_beam_fade_from)
	s.misting_beam_fade_to = math.max(s.misting_beam_fade_from, s.misting_beam_fade_to)
	s.misting_beam_min_alpha = math.min(1, math.max(0, s.misting_beam_min_alpha))
	s.misting_beam_max_distance = math.max(0, s.misting_beam_max_distance)
	s.misting_beam_piece = math.max(0, tonumber(s.misting_beam_piece) or 6)
	s.misting_beam_max_pieces = math.min(16, math.max(1, math.floor(tonumber(s.misting_beam_max_pieces) or 8)))
	s.misting_beam_ripple = math.min(0.5, math.max(0, tonumber(s.misting_beam_ripple) or 0.04))
	Potions.settings = s
	return s
end

local function Items()
	return Equipment.Items[Potions.SLOT] or {}
end

-- the potion defs in the game's order
function Potions.GetPotions()
	local list = {}
	for _, name in ipairs(Potions.ORDER) do
		local def = rawget(Items(), name)
		if def ~= nil then
			list[#list + 1] = def
		end
	end
	return list
end

function Potions.IsOurs(name)
	for _, n in ipairs(Potions.ORDER) do
		if n == name then
			return true
		end
	end
	return false
end

local function Drinker(inst)
	return inst ~= nil and inst.components ~= nil and inst.components.potiondrinker or nil
end

function Potions.GetEquippedDef(inst)
	local hoard = inst ~= nil and inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard == nil or hoard.GetEquippedItem == nil then
		return nil
	end
	local ok, item = pcall(hoard.GetEquippedItem, hoard, Potions.SLOT)
	local def = ok and item ~= nil and item.GetDef ~= nil and item:GetDef() or nil
	return def
end

function Potions.SipsFor(def)
	if def ~= nil and def.name == Potions.BUBBLING then
		return Potions.settings.bubbling_sips
	end
	return 1
end

local function InTown()
	return TheWorld ~= nil and TheWorld.HasTag ~= nil and TheWorld:HasTag("town")
end
Potions.InTown = InTown

-- Bubbling Brew: a sip taken from a charge is kept between rooms. The game
-- rebuilds the player each room and its charge count comes back (it's saved),
-- but the sip count is ours: without this the next room gave the half back.
-- Saved with Tonic Swap's own data (components/tonicswapdata.lua) together
-- with the charge count it belongs to; put back only in a run, on the same
-- potion with the same charges used (town and a new run refill everything).
function Potions.SaveSips(inst)
	local drinker = Drinker(inst)
	local n = drinker ~= nil and tonumber(rawget(drinker, "tonicswap_sips")) or nil
	if n == nil or n <= 0 then
		return nil
	end
	local def = drinker:GetEquippedPotionDef(Potions.SLOT)
	local tracker = inst.components.usetracker
	if def == nil or tracker == nil or Potions.SipsFor(def) <= 1 then
		return nil
	end
	return { n = n, potion = def.name, uses = tracker:GetNumUses(def.name) }
end

function Potions.RestoreSips(inst, saved)
	if type(saved) ~= "table" or type(saved.n) ~= "number" or InTown() then
		return false
	end
	local drinker = Drinker(inst)
	if drinker == nil or drinker.GetEquippedPotionDef == nil then
		return false
	end
	local def = drinker:GetEquippedPotionDef(Potions.SLOT)
	local tracker = inst.components.usetracker
	local sips = Potions.SipsFor(def)
	if def == nil or def.name ~= saved.potion or tracker == nil or sips <= 1
		or tracker:GetNumUses(def.name) ~= saved.uses or drinker:GetRemainingPotionUses() <= 0 then
		return false
	end
	drinker.tonicswap_sips = math.min(math.floor(saved.n), sips - 1)
	if inst.PushEvent ~= nil then
		inst:PushEvent("refreshpotiondata")
	end
	return true
end

----------------------------------------------------------------------------
-- Owning and picking

-- Give the player the hidden potions they don't have yet.
function Potions.EnsureOwned(inst)
	local hoard = inst ~= nil and inst.components ~= nil and inst.components.inventoryhoard or nil
	if hoard == nil or (inst.IsLocal ~= nil and not inst:IsLocal()) then
		return
	end
	for _, def in ipairs(Potions.GetPotions()) do
		if hoard:GetInventoryItem(def) == nil then
			hoard:TryGiveEquipment(def)
		end
	end
end

-- Pick a potion (town only): equipped in the game's potion slot.
function Potions.Pick(inst, def)
	if def == nil or not InTown() then
		return false
	end
	local hoard = inst.components.inventoryhoard
	Potions.EnsureOwned(inst)
	local item = hoard:GetInventoryItem(def)
	if item == nil then
		return false
	end
	EquipInSlot(inst, Potions.SLOT, item)
	local drinker = Drinker(inst)
	if drinker ~= nil then
		drinker.tonicswap_sips = 0
		if drinker.CheckPotions ~= nil then
			drinker:CheckPotions(true)
		end
		if drinker.InitializePotions ~= nil then
			drinker:InitializePotions()
		end
	end
	inst:PushEvent("refreshpotiondata")
	inst:PushEvent("tonicswap_changed")
	return true
end

----------------------------------------------------------------------------
-- The game's pieces

-- The hidden potions would be dropped from your inventory on load outside
-- developer mode (hidden items aren't "shippable"): keep them.
local function KeepOnLoad(ItemInstance)
	if type(ItemInstance) ~= "table" or type(ItemInstance.IsShippableItem) ~= "function" then
		return false
	end
	local orig = ItemInstance.IsShippableItem
	local function Keep(self)
		return self.slot == Potions.SLOT and Potions.HIDDEN[self.id] and Potions.enabled
	end
	ItemInstance.IsShippableItem = function(self, ...)
		local ok, keep = G.Call("keep potions on load", Keep, self)
		if ok and keep then
			return true
		end
		return orig(self, ...)
	end
	return true
end

local function TuneMisting(s)
	local pdef = Power.FindPowerByName(Potions.MISTING_POWER)
	local t = pdef ~= nil and pdef.tuning ~= nil and pdef.tuning[Power.Rarity.COMMON] or nil
	if t == nil or t.heal == nil or t.num_heals == nil then
		error("misting_potion tuning not found", 0)
	end
	t.heal = s.misting_heal
	t.num_heals = s.misting_heals
	local idef = rawget(Items(), Potions.MISTING)
	if idef ~= nil and idef.stats ~= nil then
		idef.stats.heal = s.misting_heal
	end
end

-- a trial set's base heals (potion_heals) for Soothing and Bubbling: the
-- power's number (what the heal and its description read) and the item's
-- stat (the inventory shows it)
local function TuneHeals(s)
	local function Set(power_name, item_name, heal)
		if type(heal) ~= "number" then
			return
		end
		local pdef = Power.FindPowerByName(power_name)
		local t = pdef ~= nil and pdef.tuning ~= nil and pdef.tuning[Power.Rarity.COMMON] or nil
		if t == nil or t.heal == nil then
			error(power_name .. " tuning not found", 0)
		end
		t.heal = heal
		local idef = rawget(Items(), item_name)
		if idef ~= nil and idef.stats ~= nil then
			idef.stats.heal = heal
		end
	end
	Set(Potions.SOOTHING_POWER, Potions.SOOTHING, s.soothing_heal)
	Set(Potions.BUBBLING_POWER, Potions.BUBBLING, s.bubbling_heal)
end

-- The potions' descriptions (tonic menu, power tooltips): the new behaviour,
-- with your own numbers (talents, powers, the share of flat bonuses).
local function Strings(s)
	local function SetDesc(power_name, desc)
		local pp = STRINGS ~= nil and STRINGS.ITEMS ~= nil and STRINGS.ITEMS.POWERS ~= nil
			and STRINGS.ITEMS.POWERS.POTION_POWER or nil
		if pp ~= nil and pp[power_name] ~= nil then
			pp[power_name].desc = desc
			-- the game puts every text back from its text database when it sets
			-- the language (after the mods load): the new one goes in there too
			local ok, Tune = pcall(require, "tonicswap.tonictune")
			if ok then
				Tune.WriteDB({ ["STRINGS.ITEMS.POWERS.POTION_POWER." .. power_name .. ".desc"] = desc })
			end
		end
		local pdef = Power.FindPowerByName(power_name)
		if pdef ~= nil and type(pdef.pretty) == "table" then
			pdef.pretty.desc = desc
		end
		return pdef
	end
	if s.bubbling_sips > 1 then
		SetDesc(Potions.BUBBLING_POWER, string.format(Potions.STR.BUBBLING_DESC, s.bubbling_sips))
	end
	local mdef = SetDesc(Potions.MISTING_POWER, Potions.STR.MISTING_DESC .. (s.misting_restart and Potions.STR.MISTING_RESTART or ""))
	-- the game shows Misting's base heal; show what a heal really gives you
	if mdef ~= nil and mdef.desc_fn == nil then
		local orig = mdef.desc_contextual_tuning_fn
		mdef.desc_contextual_tuning_fn = function(pow, owner, ...)
			local t = orig ~= nil and orig(pow, owner, ...) or {}
			local drinker = Drinker(owner)
			if drinker ~= nil then
				local ok, heal = pcall(drinker.GetPotionHealAmount, drinker, pow)
				if ok and type(heal) == "number" then
					t.heal = heal
				end
			end
			return t
		end
	end
end

-- a power's name: a running power (.def) or a power item (GetDef / id)
function Potions.PowerName(pow)
	if type(pow) ~= "table" then
		return nil
	end
	local def = rawget(pow, "def")
	if type(def) == "table" and type(def.name) == "string" then
		return def.name
	end
	if type(pow.GetDef) == "function" then
		local ok, d = pcall(pow.GetDef, pow)
		if ok and type(d) == "table" and type(d.name) == "string" then
			return d.name
		end
	end
	local id = rawget(pow, "id")
	return type(id) == "string" and id or nil
end

local function HookDrinker(s)
	local PotionDrinker = require "components.potiondrinker"
	for _, name in ipairs({ "DrinkPotion", "GetPotionHealAmount", "GetTotalPotionHealAdd", "ApplyPower", "InitializePotions",
		"GetEquippedPotionDef" }) do
		assert(type(PotionDrinker[name]) == "function", "PotionDrinker:" .. name)
	end

	-- Bubbling Brew: a charge is used up on its last sip. While a drink runs,
	-- self.tonicswap_drink says which sip it is (first / last of its potion)
	-- and how many sips' healing it gives (whole: a free drink is a whole potion).
	local orig_drink = PotionDrinker.DrinkPotion
	local function SipsNow(self)
		return Potions.SipsFor(self:GetEquippedPotionDef(Potions.SLOT))
	end
	PotionDrinker.DrinkPotion = function(self, free_drink, ...)
		local ok, sips = G.Call("potion drink", SipsNow, self)
		if not ok or type(sips) ~= "number" or sips <= 1 then
			return orig_drink(self, free_drink, ...)
		end
		local drink
		if free_drink then
			-- the shop's potion drunk on the spot, the potion event when you're full
			drink = { first = true, last = true, whole = s.bubbling_per_potion and sips or 1, free = true }
		else
			self.tonicswap_sips = (self.tonicswap_sips or 0) + 1
			local n = self.tonicswap_sips
			drink = { first = n == 1, last = n >= sips, whole = 1, sip = n }
			if n < sips then
				free_drink = true -- an earlier sip: the charge isn't used up yet
			else
				self.tonicswap_sips = 0
			end
		end
		local outer = self.tonicswap_drink
		self.tonicswap_drink = drink
		local results = table.pack(pcall(orig_drink, self, free_drink, ...))
		self.tonicswap_drink = outer
		-- a sip that didn't use up its charge: the game sends no update, the HUD counts sips
		if not drink.free and not drink.last and self.inst ~= nil and self.inst.PushEvent ~= nil then
			self.inst:PushEvent("refreshpotiondata")
		end
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end

	-- a fresh set of charges (town, a new run, a full refill): no sip pending
	local orig_init = PotionDrinker.InitializePotions
	PotionDrinker.InitializePotions = function(self, ...)
		self.tonicswap_sips = 0
		return orig_init(self, ...)
	end

	-- flat heal bonuses: half per Bubbling sip, spread over Misting's heals
	local orig_heal = PotionDrinker.GetPotionHealAmount
	-- (a running power has .def; the one a description makes is an item: the
	-- game's itemforge.CreatePower, only GetDef / id. 0.3.0-0.5.6 read .def
	-- alone, so the descriptions showed the whole flat bonus.)
	local function ShareOf(pow)
		local name = Potions.PowerName(pow)
		local share = name == Potions.BUBBLING_POWER and s.bubbling_flat_share
			or name == Potions.MISTING_POWER and (s.misting_flat_share / s.misting_heals)
			or name == Potions.SOOTHING_POWER and type(s.soothing_flat_share) == "number" and s.soothing_flat_share or nil
		return name, share
	end
	-- the heal log (potion_heal_log): what each drink's heal was worked out
	-- from, once per drink (descriptions and other callers aren't logged)
	Potions.heal_logs = 0
	local function LogHeal(self, pow, share, result)
		if not s.potion_heal_log or not rawget(self, "tonicswap_logdrink") or Potions.heal_logs >= 40 then
			return
		end
		Potions.heal_logs = Potions.heal_logs + 1
		local name = Potions.PowerName(pow) or "?"
		local base = pow ~= nil and pow.GetVar ~= nil and pow:GetVar("heal") or "?"
		local add = PotionDrinker.GetTotalPotionHealAdd(self)
		local mult = self.GetTotalPotionHealMult ~= nil and self:GetTotalPotionHealMult() or 1
		local resolve = rawget(_G, "ResolveHuntModifiers")
		local okh, hunt = false, nil
		if resolve ~= nil then
			okh, hunt = pcall(function() return resolve().PotionHealMultiplier end)
		end
		local drink = self.tonicswap_drink
		print(string.format("[Tonic Swap] potion heal: %s: %s + flat %s%s, x%s (bonuses) x%s (hunt)%s = %s",
			tostring(name), tostring(base), tostring(add), share ~= nil and string.format(" x %.3f share", share) or " (all of it)",
			tostring(mult), okh and tostring(hunt) or "?",
			drink ~= nil and string.format(" [sip %s%s%s]", tostring(drink.sip or "-"), drink.free and ", free" or "",
				(drink.whole or 1) > 1 and (", x" .. drink.whole .. " whole potion") or "") or "", tostring(result)))
	end
	PotionDrinker.GetPotionHealAmount = function(self, pow, ...)
		local ok, name, share = G.Call("potion heal", ShareOf, pow)
		if not ok or type(share) ~= "number" then
			local results = table.pack(orig_heal(self, pow, ...))
			G.Call("potion heal log", LogHeal, self, pow, nil, results[1])
			return table.unpack(results, 1, results.n)
		end
		local orig_add = PotionDrinker.GetTotalPotionHealAdd
		rawset(self, "GetTotalPotionHealAdd", function(me, ...)
			-- (to 6 decimals: 25 x 1.2 / 10 must be 3, not 2.9999999, before the game rounds down)
			return math.floor(orig_add(me, ...) * share * 1e6 + 0.5) / 1e6
		end)
		local results = table.pack(pcall(orig_heal, self, pow, ...))
		rawset(self, "GetTotalPotionHealAdd", nil)
		if not results[1] then
			error(results[2], 0)
		end
		-- a free Bubbling drink: a whole potion's healing (every sip's, added up)
		local drink = self.tonicswap_drink
		if name == Potions.BUBBLING_POWER and drink ~= nil and (drink.whole or 1) > 1 and type(results[2]) == "number" then
			results[2] = results[2] * drink.whole
		end
		G.Call("potion heal log", LogHeal, self, pow, share, results[2])
		return table.unpack(results, 2, results.n)
	end

	-- (the heal log: marks the drink, every potion)
	local drink_hook = PotionDrinker.DrinkPotion
	PotionDrinker.DrinkPotion = function(self, ...)
		if not s.potion_heal_log then
			return drink_hook(self, ...)
		end
		local outer = rawget(self, "tonicswap_logdrink")
		rawset(self, "tonicswap_logdrink", true)
		local results = table.pack(pcall(drink_hook, self, ...))
		rawset(self, "tonicswap_logdrink", outer)
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end

	-- Misting Mixture again while it heals: start over, keep what was left
	if s.misting_restart then
		local orig_apply = PotionDrinker.ApplyPower
		-- (the power manager and the heals left; nil: not Misting again)
		local function TakeOld(self, power_name)
			local pm = self.inst ~= nil and self.inst.components ~= nil and self.inst.components.powermanager or nil
			if power_name ~= Potions.MISTING_POWER or pm == nil or pm.GetPowerByName == nil then
				return nil
			end
			local old = pm:GetPowerByName(power_name)
			local left = 0
			if old ~= nil then
				left = old.persistdata ~= nil and tonumber(old.persistdata.heals_left) or 0
				pm:RemovePower(old.def, true)
			end
			self.tonicswap_mist_carry = left > 0 or nil -- linked allies stay linked (tonicswap/mistallies.lua)
			return pm, left
		end
		local function AddLeft(pm, power_name, left)
			local new = left > 0 and pm:GetPowerByName(power_name) or nil
			if new ~= nil and new.persistdata ~= nil then
				new.persistdata.heals_left = (tonumber(new.persistdata.heals_left) or 0) + left
			end
		end
		PotionDrinker.ApplyPower = function(self, power_name, ...)
			local ok, pm, left = G.Call("Misting restart", TakeOld, self, power_name)
			if not ok or pm == nil then
				return orig_apply(self, power_name, ...)
			end
			local results = table.pack(orig_apply(self, power_name, ...))
			G.Call("Misting restart", AddLeft, pm, power_name, left or 0)
			return table.unpack(results, 1, results.n)
		end
	end
end

----------------------------------------------------------------------------
-- Bubbling Brew: once per potion, and the HUD in sips

-- the drink running now for this player (Bubbling Brew only), or nil
function Potions.CurrentDrink(inst)
	local drinker = Drinker(inst)
	return drinker ~= nil and rawget(drinker, "tonicswap_drink") or nil
end

-- What the HUD shows: drinks left and the most there can be. Bubbling Brew
-- counts sips (3 charges = 6; a sip taken from the current charge = 5);
-- every other potion counts charges, as the game.
function Potions.UsesLeft(drinker)
	local left, max = drinker:GetRemainingPotionUses(), drinker:GetMaxUses()
	local sips = Potions.SipsFor(drinker:GetEquippedPotionDef(Potions.SLOT))
	if sips <= 1 then
		return left, max, 1
	end
	local taken = left > 0 and math.min(tonumber(rawget(drinker, "tonicswap_sips")) or 0, sips - 1) or 0
	return math.max(0, left * sips - taken), max * sips, sips
end

-- Powers that react to drinking (Iron Brew's shield, the frost freeze, Cleaver
-- berserk, the curses' counters, Immorel's refills):
--   * once a drink, with any potion: the game tells them about every drink
--     twice when you have a tonic (one "drink_potion" for the potion, one for
--     the tonic), so Iron Brew gave 8 shield and Forbidden Drink ran out after
--     2 drinks. The tonic's copy of the event is skipped for them.
--   * Bubbling Brew (bubbling_per_potion): once a potion, on its first sip
--     (Potions.LAST_SIP: the last). Outside a Bubbling drink they run as the game's.
-- The potion and tonic powers themselves are left alone: the tonic comes with
-- every sip. Returns the names wrapped.
local gated = setmetatable({}, { __mode = "k" })
local function TonicEvent(data)
	return type(data) == "table" and rawget(data, "slot") == "TONICS"
end
function Potions.PerPotion()
	local names = {}
	local slots = type(Power.Slots) == "table" and Power.Slots or {}
	local skip = { [slots.POTION_POWER or "POTION_POWER"] = true, [slots.TONIC or "TONIC"] = true }
	for slot, defs in pairs(Power.Items or {}) do
		if not skip[slot] and type(defs) == "table" then
			for name, def in pairs(defs) do
				local triggers = type(def) == "table" and def.event_triggers or nil
				local fn = type(triggers) == "table" and triggers.drink_potion or nil
				if type(fn) == "function" and not gated[fn] then
					local when = Potions.LAST_SIP[name] and "last" or "first"
					-- (the check in the guard: an error there and the power runs)
					local function Skip(inst, data)
						if TonicEvent(data) then
							return true -- the same drink, told again for the tonic
						end
						local drink = Potions.CurrentDrink(inst)
						return drink ~= nil and not drink[when] and Potions.settings.bubbling_per_potion
					end
					local where = name .. " on drink"
					local w = function(pow, inst, data, ...)
						local ok, skip = G.Call(where, Skip, inst, data)
						if ok and skip then
							return
						end
						return fn(pow, inst, data, ...)
					end
					gated[w] = true
					triggers.drink_potion = w
					names[#names + 1] = name
				end
				-- a heal modifier that counts drinks (Diluted Medicine): counted on the last sip
				local hm = type(def) == "table" and Potions.COUNTS_ON_HEAL[name] and def.heal_mod_fn or nil
				if type(hm) == "function" and not gated[hm] then
					local function Before(pow)
						local owner = pow ~= nil and pow.owner or nil
						local drink = owner ~= nil and Potions.CurrentDrink(owner) or nil
						local pd = pow ~= nil and pow.persistdata or nil
						return owner, drink, pd, pd ~= nil and pd.counter or nil
					end
					local function After(pow, owner, drink, pd, before)
						if drink ~= nil and not drink.last and Potions.settings.bubbling_per_potion and pd ~= nil and pd.counter ~= before then
							pd.counter = before
							if owner.PushEvent ~= nil then
								owner:PushEvent("update_power", pow.def)
							end
						end
					end
					local where = name .. " heal count"
					local w = function(pow, heal, output, ...)
						local ok, owner, drink, pd, before = G.Call(where, Before, pow)
						local results = table.pack(hm(pow, heal, output, ...))
						if ok then
							G.Call(where, After, pow, owner, drink, pd, before)
						end
						return table.unpack(results, 1, results.n)
					end
					gated[w] = true
					def.heal_mod_fn = w
					names[#names + 1] = name .. " (heal count)"
				end
			end
		end
	end
	table.sort(names)
	return names
end

-- The game's potion widget (the HUD, the character panel, the potion over
-- your head): Bubbling Brew's number counts sips. Only the number: the game
-- still keeps charges everywhere else.
function Potions.HudSips()
	local ok, PotionWidget = pcall(require, "widgets/ftf/potionwidget")
	if not ok or type(PotionWidget) ~= "table" or type(PotionWidget.RefreshUses) ~= "function" then
		return false
	end
	if rawget(PotionWidget, "tonicswap_sips_hooked") then
		return true
	end
	rawset(PotionWidget, "tonicswap_sips_hooked", true)
	local orig = PotionWidget.RefreshUses
	-- (the drinker and its sips left / most; nil: the game's count)
	local function Sips(self)
		local drinker = Drinker(self.owner)
		local sips = drinker ~= nil and drinker.GetEquippedPotionDef ~= nil and Potions.SipsFor(drinker:GetEquippedPotionDef(Potions.SLOT)) or 1
		if not Potions.enabled or not Potions.settings.bubbling_hud_sips or sips <= 1 then
			return nil
		end
		local left, max = Potions.UsesLeft(drinker)
		return drinker, left, max
	end
	PotionWidget.RefreshUses = function(self, ...)
		local okc, drinker, left, max = G.Call("HUD potion count", Sips, self)
		if not okc or drinker == nil then
			return orig(self, ...)
		end
		rawset(drinker, "GetRemainingPotionUses", function() return left end)
		rawset(drinker, "GetMaxUses", function() return max end)
		local results = table.pack(pcall(orig, self, ...))
		rawset(drinker, "GetRemainingPotionUses", nil)
		rawset(drinker, "GetMaxUses", nil)
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
	return true
end

-- The bottle in the drink animation
-- The smash's shards in the potion's colour: the stategraph spawns the effect
-- with SGCommon.Fns.SpawnAtDist at the end of the drink.
local function Smash(s)
	local SGCommon = require "stategraphs.sg_common"
	if not (type(SGCommon) == "table" and type(SGCommon.Fns) == "table" and type(SGCommon.Fns.SpawnAtDist) == "function") then
		error("SGCommon.Fns.SpawnAtDist", 0)
	end
	local orig = SGCommon.Fns.SpawnAtDist
	local function Shards(inst, prefab, ent)
		if prefab == Potions.SMASH_FX and ent ~= nil and ent.AnimState ~= nil then
			local ok, def = pcall(Potions.GetEquippedDef, inst)
			local name = ok and def ~= nil and def.name or nil
			if name ~= nil and s.potion_bottles == "own" and Potions.SMASH_BUILDS[name] ~= nil then
				ent.AnimState:SetBuild(Potions.SMASH_BUILDS[name])
			elseif name ~= nil and s.potion_bottles == "recolour" and Potions.RECOLOUR[name] ~= nil
				and ent.AnimState.SetSymbolColorShift ~= nil then
				local hsb = Potions.RECOLOUR[name]
				ent.AnimState:SetSymbolColorShift(Potions.SMASH_SYMBOL, hsb[1], hsb[2], hsb[3])
			end
		end
	end
	SGCommon.Fns.SpawnAtDist = function(inst, prefab, ...)
		local ent = orig(inst, prefab, ...)
		if prefab == Potions.SMASH_FX then
			G.Call("potion smash colour", Shards, inst, prefab, ent)
		end
		return ent
	end
end

-- the smash colours are a nicety: if they can't be hooked, the potions still work
local function TrySmash(s)
	local ok, err = pcall(Smash, s)
	Potions.smash_error = not ok and tostring(err) or nil
end

local function Bottles(s)
	if s.potion_bottles == "own" then
		-- the mod's art files, loaded by modmain (Assets): the bottles come by
		-- themselves (def.build); the HUD's icons and the smash need help
		local set = Potions.HUD_ICONS[s.potion_hud_icons] or Potions.HUD_ICONS.classic
		for name in pairs(Potions.BOTTLES) do
			local def = rawget(Items(), name)
			local ui = def ~= nil and def.ui_icons or nil
			if type(ui) == "table" then
				-- the game's own paths, kept on the item the first time (texts
				-- can only show the game's atlases: Potions.GameIcon)
				local game = rawget(ui, Potions.GAME_ICONS_KEY)
				if game == nil then
					game = { ready = ui.ready, consumed = ui.consumed }
					rawset(ui, Potions.GAME_ICONS_KEY, game)
				end
				local icons = set[name] or {}
				ui.ready = icons.ready or game.ready
				ui.consumed = icons.consumed or game.consumed
			end
		end
		TrySmash(s)
		return
	end
	for name in pairs(Potions.BOTTLES) do
		local def = rawget(Items(), name)
		if def ~= nil then
			def.build = Potions.SOOTHING_BOTTLE
		end
	end
	if s.potion_bottles ~= "recolour" then
		return
	end
	TrySmash(s)
	local Inventory = require "components.inventory"
	assert(type(Inventory.OverrideEquipSlotSymbols) == "function", "Inventory:OverrideEquipSlotSymbols")
	local orig = Inventory.OverrideEquipSlotSymbols
	local function Recolour(self, slot, def)
		if slot == Potions.SLOT and self.inst ~= nil and self.inst.AnimState ~= nil then
			local hsb = def ~= nil and Potions.RECOLOUR[def.name] or nil
			local anim = self.inst.AnimState
			if hsb ~= nil and anim.SetSymbolColorShift ~= nil then
				anim:SetSymbolColorShift(Potions.BOTTLE_SYMBOL, hsb[1], hsb[2], hsb[3])
			elseif anim.ClearSymbolColorShift ~= nil then
				anim:ClearSymbolColorShift(Potions.BOTTLE_SYMBOL)
			end
		end
	end
	Inventory.OverrideEquipSlotSymbols = function(self, slot, def, ...)
		local results = table.pack(orig(self, slot, def, ...))
		G.Call("potion bottle colour", Recolour, self, slot, def)
		return table.unpack(results, 1, results.n)
	end
end

-- The picture for this player's potion inside talent texts, or nil for
-- Soothing Spirits (the game's own picture is Soothing's): the game's HUD icon
-- for it (small: it has a wide empty border), or its inventory icon
-- (talent_picture = "inventory"). (Drawing the HUD icon bigger with scale= hid
-- it in 0.4.1; the mod's own atlas can't be used inside a text.)
function Potions.IconFor(inst)
	local def = Potions.GetEquippedDef(inst)
	if def == nil or def.name == Potions.ORDER[1] then
		return nil
	end
	local mode = Potions.settings ~= nil and Potions.settings.talent_picture or Potions.DEFAULTS.talent_picture
	local hud = Potions.GameIcon(def, "ready")
	local inv = type(def.icon) == "string" and def.icon ~= "" and def.icon or nil
	if mode == "inventory" then
		return inv or hud
	end
	return hud or inv
end

-- The big HUD bottle drawn next to the talent line's number (talent_picture =
-- "hud"): its texture and width / height, or nil.
function Potions.LinePicture(inst)
	local mode = Potions.settings ~= nil and Potions.settings.talent_picture or Potions.DEFAULTS.talent_picture
	local def = mode == "hud" and Potions.GetEquippedDef(inst) or nil
	if def == nil or Potions.TALENT_PICTURE[def.name] == nil then
		return nil
	end
	local s = Potions.settings or Potions.DEFAULTS
	if s.potion_bottles == "own" and s.potion_hud_icons == "mix" and Potions.TALENT_PICTURE_MIX[def.name] ~= nil then
		return Potions.TALENT_PICTURE_MIX[def.name], Potions.TALENT_ASPECT_MIX[def.name] or 0.66
	end
	return Potions.TALENT_PICTURE[def.name], Potions.TALENT_ASPECT[def.name] or 0.66
end

local function ReplacePlain(s, old, new)
	local out, at = {}, 1
	while true do
		local i, j = s:find(old, at, true)
		if i == nil then
			break
		end
		out[#out + 1] = s:sub(at, i - 1)
		out[#out + 1] = new
		at = j + 1
	end
	out[#out + 1] = s:sub(at)
	return table.concat(out)
end
Potions.ReplacePlain = ReplacePlain

-- A talent text with the game's potion picture swapped for this potion's picture
function Potions.TalentImage(text, icon)
	return ReplacePlain(text, Potions.HUD_POTION, icon)
end

-- A talent text with the game's potion picture taken out (the line's own
-- picture is drawn next to it)
function Potions.StripPicture(text)
	local path = Potions.HUD_POTION:gsub("%p", "%%%0")
	return (text:gsub("%s*<p img=['\"]" .. path .. "['\"][^>]*>", ""))
end

function Potions.HasPotionPicture(def)
	local units = type(def) == "table" and type(def.pretty) == "table" and def.pretty.variable_units or nil
	if type(units) ~= "table" then
		return false
	end
	for _, v in pairs(units) do
		if type(v) == "string" and v:find(Potions.HUD_POTION, 1, true) then
			return true
		end
	end
	return false
end

-- talent unit texts with the potion picture: { t = units, k = key, orig = text }
local units_cache
local function PotionUnits()
	if units_cache == nil then
		units_cache = {}
		local talents = {}
		if type(Power.GetAllPowersOfFamily) == "function" then
			local ok, list = pcall(Power.GetAllPowersOfFamily, "TALENT")
			talents = ok and type(list) == "table" and list or {}
		end
		for _, def in pairs(talents) do
			local units = type(def) == "table" and type(def.pretty) == "table" and def.pretty.variable_units or nil
			if type(units) == "table" then
				for k, v in pairs(units) do
					if type(v) == "string" and v:find(Potions.HUD_POTION, 1, true) then
						units_cache[#units_cache + 1] = { t = units, k = k, orig = v }
					end
				end
			end
		end
	end
	return units_cache
end

-- run fn with the talent texts showing this player's potion (the texts are
-- shared by every player, so they're put back right after). strip: no
-- picture in the texts at all (the talent line draws its own).
function Potions.WithPotionIcon(inst, fn, ...)
	return Potions.WithUnits(inst, false, fn, ...)
end
local function SetUnits(inst, strip)
	local icon = Potions.IconFor(inst)
	local units = icon ~= nil and PotionUnits() or {}
	-- (all worked out first, then set: an error leaves every text as it was)
	local texts = {}
	for i, u in ipairs(units) do
		texts[i] = strip and Potions.StripPicture(u.orig) or Potions.TalentImage(u.orig, icon)
	end
	for i, u in ipairs(units) do
		u.t[u.k] = texts[i]
	end
	return units
end
-- The potion heal talent (Eggzy's "potion_heal") shows the game's potion's
-- heal: Soothing Spirits' 250, +25 a point. With Bubbling Brew or Misting
-- Mixture the talent screens show that potion's own: a whole charge's
-- healing with the talent's share of it (Bubbling: 2 sips of 100, half the
-- bonus a sip = 200, +25 a point; Misting: 10 heals of 30 and 1.2x the bonus
-- = 300, +30 a point). Nil: the game's numbers.
Potions.HEAL_TALENT = "talent_potion_heal" -- (Power.AddTalentPower("potion_heal"): the game adds "talent_")
function Potions.HealTalentNumbers(inst)
	local def = Potions.GetEquippedDef(inst)
	local s = Potions.settings
	if def == nil or s == nil then
		return nil
	end
	if def.name == Potions.BUBBLING and s.bubbling_sips > 1 then
		local okd, pdef = pcall(Power.FindPowerByName, Potions.BUBBLING_POWER)
		pdef = okd and pdef or nil
		local t = pdef ~= nil and pdef.tuning ~= nil and pdef.tuning[Power.Rarity.COMMON] or nil
		local heal = t ~= nil and tonumber(t.heal) or 100
		return { base = s.bubbling_sips * heal, scale = s.bubbling_sips * s.bubbling_flat_share }
	elseif def.name == Potions.MISTING then
		return { base = s.misting_heals * s.misting_heal, scale = s.misting_flat_share }
	elseif def.name == Potions.SOOTHING and type(s.soothing_heal) == "number" then
		return { base = s.soothing_heal, scale = s.soothing_flat_share or 1 }
	end
	return nil
end
-- (the talent's bonus number, swapped on its own variable while a talent
-- screen draws; its real value, which the talent's effect reads, is untouched)
local heal_wrappers = setmetatable({}, { __mode = "k" })
local function SetHealTalent(inst)
	local nums = Potions.HealTalentNumbers(inst)
	if nums == nil then
		return nil
	end
	local okt, tdef = pcall(Power.FindPowerByName, Potions.HEAL_TALENT)
	tdef = okt and tdef or nil
	local t = tdef ~= nil and tdef.tuning ~= nil and tdef.tuning[Power.Rarity.COMMON] or nil
	local var = t ~= nil and t.bonus_heal or nil
	local pretty = type(var) == "table" and var.GetPrettyForStacks or nil
	if type(pretty) ~= "function" or heal_wrappers[pretty] then
		return nil -- (already swapped: a talent screen inside another)
	end
	local own = rawget(var, "GetPrettyForStacks")
	local w = function(self, stacks, base_amount, ...)
		return pretty(self, (tonumber(stacks) or 0) * nums.scale, nums.base, ...)
	end
	heal_wrappers[w] = true
	rawset(var, "GetPrettyForStacks", w)
	return { var = var, own = own }
end
local NO_UNITS = {}
function Potions.WithUnits(inst, strip, fn, ...)
	-- (an error setting the pictures: logged, and the texts are the game's)
	local okp, units = G.Call("potion picture in talent texts", SetUnits, inst, strip)
	if not okp or type(units) ~= "table" then
		units = NO_UNITS
	end
	local okh, heal = G.Call("potion heal talent numbers", SetHealTalent, inst)
	local results = table.pack(pcall(fn, ...))
	if okh and type(heal) == "table" then
		rawset(heal.var, "GetPrettyForStacks", heal.own)
	end
	for _, u in ipairs(units) do
		u.t[u.k] = u.orig
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- The bottle next to a talent line's number (an Image on the bonus text, just
-- right of the number's drawn end, as tall as the font). tex nil: hidden.
function Potions.PlaceLinePicture(widget, tex, aspect)
	local text = widget ~= nil and widget.bonus or nil
	local img = widget ~= nil and widget.tonicswap_pic or nil
	if tex == nil or text == nil then
		if img ~= nil then
			img:Hide()
		end
		return
	end
	if img == nil then
		local Image = require "widgets/image"
		img = text:AddChild(Image(tex))
		widget.tonicswap_pic = img
	elseif img.tonicswap_tex ~= tex then
		img:SetTexture(tex)
	end
	img.tonicswap_tex = tex
	-- "<number> <picture>" without the picture leaves a space at the end
	if text.GetText ~= nil and text.SetText ~= nil then
		local str = text:GetText()
		if type(str) == "string" and str:find("%s$") then
			text:SetText((str:gsub("%s+$", "")))
		end
	end
	local size = text.GetFontSize ~= nil and text:GetFontSize() or 40
	local h = size
	local w = h * (aspect or 0.66)
	img:SetSize(w, h)
	local right = 0
	local tw = text.inst ~= nil and text.inst.TextWidget or nil
	if tw ~= nil and tw.GetRenderBounds ~= nil then
		local _, _, x2 = tw:GetRenderBounds()
		right = type(x2) == "number" and x2 or 0
	end
	img:SetPosition(right + size * 0.15 + w / 2, 0)
	img:Show()
end

-- The talent menu (the hearts at the Wellspring): Field Medicine's charges
-- (each talent's bonus line, the loadout summary) and any description.
local function TalentIcons()
	local hooked = {}
	local ok, TalentWidget = pcall(require, "widgets/ftf/talentwidget")
	if ok and type(TalentWidget) == "table" and type(TalentWidget.RefreshBonus) == "function" then
		local orig = TalentWidget.RefreshBonus
		local function Picture(self)
			local player = self.GetOwningPlayer ~= nil and self:GetOwningPlayer() or nil
			local tex, aspect = Potions.LinePicture(player)
			if tex ~= nil and not Potions.HasPotionPicture(self.talent_def) then
				tex = nil
			end
			return player, tex, aspect
		end
		TalentWidget.RefreshBonus = function(self, ...)
			local okp, player, tex, aspect = G.Call("talent potion picture", Picture, self)
			if not okp then
				return orig(self, ...)
			end
			if tex == nil then
				pcall(Potions.PlaceLinePicture, self, nil)
				return Potions.WithPotionIcon(player, orig, self, ...)
			end
			local results = table.pack(Potions.WithUnits(player, true, orig, self, ...))
			local ok, err = pcall(Potions.PlaceLinePicture, self, tex, aspect)
			if not ok then
				print("[Tonic Swap] talent picture: " .. tostring(err))
			end
			return table.unpack(results, 1, results.n)
		end
		hooked[#hooked + 1] = "talents"
	end
	local ok2, Summary = pcall(require, "screens/dialogs/talentsummarydialog")
	if ok2 and type(Summary) == "table" and type(Summary.AddGroupTalents) == "function" then
		local orig = Summary.AddGroupTalents
		Summary.AddGroupTalents = function(self, ...)
			local player = self.GetOwningPlayer ~= nil and self:GetOwningPlayer() or nil
			return Potions.WithPotionIcon(player, orig, self, ...)
		end
		hooked[#hooked + 1] = "summary"
	end
	if type(Power.GetDescForPower) == "function" then
		local orig = Power.GetDescForPower
		local function Pictured(desc, owner)
			local icon = Potions.IconFor(owner)
			return icon ~= nil and Potions.TalentImage(desc, icon) or desc
		end
		Power.GetDescForPower = function(power, owner, ...)
			local desc = orig(power, owner, ...)
			if type(desc) == "string" and owner ~= nil and desc:find(Potions.HUD_POTION, 1, true) then
				local ok, pictured = G.Call("potion picture in a description", Pictured, desc, owner)
				if ok and type(pictured) == "string" then
					desc = pictured
				end
			end
			return desc
		end
		hooked[#hooked + 1] = "descriptions"
	end
	-- The HUD's potion icon: the game redraws it only when the number of drinks
	-- left changes (PotionWidget:RefreshUses stops early when the count is the
	-- same), so a potion picked in town kept the old icon until the run. When
	-- the potion changes, forget the count so the refresh redraws the icon.
	local ok3, PotionWidget = pcall(require, "widgets/ftf/potionwidget")
	if ok3 and type(PotionWidget) == "table" and type(PotionWidget.RefreshIcons) == "function" then
		local orig = PotionWidget.RefreshIcons
		PotionWidget.RefreshIcons = function(self, ...)
			local before = self.equipped_potion_def
			local results = table.pack(orig(self, ...))
			if self.equipped_potion_def ~= before then
				self.last_remaining_uses = nil
				self.texture_name = nil
			end
			return table.unpack(results, 1, results.n)
		end
		hooked[#hooked + 1] = "hud"
	end
	return hooked
end

-- the talent pictures are a nicety: if they can't be hooked, the potions still
-- work. Hooked when the first player spawns (the game is fully loaded then, so
-- loading its talent screens early can't catch them half set up).
local function TryTalentIcons()
	if Potions.talent_icons ~= nil then
		return
	end
	local ok, hooked = pcall(TalentIcons)
	Potions.talent_icons = ok and table.concat(hooked, ", ") or ("off: " .. tostring(hooked))
	if not ok or #hooked < 4 then
		print("[Tonic Swap] talent menu potion pictures / HUD refresh: " .. (ok and (#hooked > 0 and table.concat(hooked, ", ") or "off")
			or Potions.talent_icons))
	end
end

-- ItemInstance: the class of an item (Main gets it from a probe item).
-- Returns ok, info or error.
function Potions.Install(user, ItemInstance)
	local s = Potions.LoadSettings(user)
	if not s.potions then
		return false, "potions = false"
	end
	if #Potions.GetPotions() < 3 then
		return false, "a game update changed the potions"
	end
	TuneMisting(s)
	TuneHeals(s)
	HookDrinker(s)
	local okm, m_ok, m_info = pcall(function() return require("tonicswap.mistallies").Install(s, G, Potions.MISTING_POWER) end)
	Potions.mist_info = okm and (m_ok and m_info or ("the game's" .. (m_info ~= "the game's" and (" (" .. tostring(m_info) .. ")") or "")))
		or ("the game's (" .. tostring(m_ok) .. ")")
	Strings(s)
	Bottles(s)
	local kept = KeepOnLoad(ItemInstance)
	local okp, names = pcall(Potions.PerPotion)
	Potions.per_potion = okp and names or nil
	local per_potion = okp and string.format(", drink powers: %d (once a drink%s)", #names,
		(s.bubbling_per_potion and s.bubbling_sips > 1) and ", Bubbling: once a potion" or "")
		or (", drink powers off: " .. tostring(names))
	local hud = ""
	if s.bubbling_hud_sips and s.bubbling_sips > 1 then
		local okh, hooked = pcall(Potions.HudSips)
		hud = (okh and hooked) and ", HUD in sips" or ", HUD in sips off"
	end
	Potions.enabled = true
	local heals = s.potion_heals ~= "current" and string.format(", heals: %s (Soothing %g, Bubbling %g a sip, Misting %g x %d)",
		s.potion_heals, s.soothing_heal, s.bubbling_heal, s.misting_heal, s.misting_heals) or ""
	return true, string.format("%d potions, bottles: %s%s%s%s%s%s, Misting allies: %s", #Potions.GetPotions(),
		s.potion_bottles == "own" and ("own (HUD icons: " .. s.potion_hud_icons .. ")") or s.potion_bottles,
		kept and "" or ", hidden potions need developer mode to stay",
		Potions.smash_error ~= nil and (", smash colours off: " .. Potions.smash_error) or "", per_potion, hud, heals, Potions.mist_info)
end

function Potions.SetupPlayer(inst)
	if not Potions.enabled then
		return
	end
	TryTalentIcons()
	if Potions.per_potion ~= nil then
		local okp, names = pcall(Potions.PerPotion) -- powers added after the mods loaded
		if okp and #names > 0 then
			for _, n in ipairs(names) do
				Potions.per_potion[#Potions.per_potion + 1] = n
			end
		end
	end
	local function Soon()
		if inst:IsValid() then
			inst:DoTaskInTime(0, Potions.EnsureOwned)
		end
	end
	inst:ListenForEvent("enter_town", Soon)
	Soon()
	-- the heal log: what a potion heal really gave (after every power's change)
	if Potions.settings ~= nil and Potions.settings.potion_heal_log then
		inst:ListenForEvent("take_heal", function(_, heal)
			G.Call("potion heal log", function()
				if (Potions.heal_logs or 0) < 40 and type(heal) == "table" and heal.IsPotionHeal ~= nil and heal:IsPotionHeal()
					and heal.GetHealer ~= nil and heal:GetHealer() == inst then
					Potions.heal_logs = (Potions.heal_logs or 0) + 1
					print(string.format("[Tonic Swap] potion heal given: %s (%s)", tostring(heal.GetHeal ~= nil and heal:GetHeal() or "?"),
						tostring(heal.GetID ~= nil and heal:GetID() or "?")))
				end
			end)
		end)
	end
end

return Potions
