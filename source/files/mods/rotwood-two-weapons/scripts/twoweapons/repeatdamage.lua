-- Two Weapons: the same swap attack again and again does less damage.
--
-- Swaps stay instant, but a strong swap move paired with a quick ranged one
-- (spear multi-thrust <-> bow / cannon) could be looped. Now each strong
-- swap move is counted (per weapon and move): the first swap_repeat_full
-- times (2) in a row do full damage; from the next one on, that move's own
-- hits do swap_repeat_factor of their damage (0.59: about what that weapon's
-- light attacks deal in the same time: spear light combo 3.45 in 42 frames
-- against the multi-thrust's ~3.15 in the ~23 frames to its last thrust is
-- 60%; the damage log below measures it in play). swap_repeat_window seconds (2.5) without any swap attack: back to full.
-- Strong = the game's heavy attacks and skills (the multi-thrust is a heavy);
-- light-type swap moves (quick shots, the bow's light shots, dodge moves) are
-- never reduced. swap_repeat_also / swap_repeat_skip: moves (by state name)
-- counted or left out regardless (left out by default: the hammer's jump
-- slams, the spear's jump thrust, vault strike and crosscheck, the Cannon
-- whack and the bow's jump shot and melee bash).
--
-- Only that swap move's hits: from the moment it starts until it's over
-- (the game starts your next move from a press, you're out of attacks, or you
-- swap again). Arrows / shells it fires are marked as they leave and keep the
-- reduction when they land later; other hits (normal attacks, combos you
-- carry on, powers' own hits) are never touched. The damage goes through the
-- game's own damage multiplier for that one attack (Attack:InitDamageAmount).
--
-- Damage log (swap_damage_log, for setting the number): damage per second of
-- each weapon's light attacks and of each swap move, written to client_log.txt
-- ("[Two Weapons] damage rates") every minute while you fight.

local Repeat = {}

Repeat.hooked = false
Repeat.reduced = 0 -- hits reduced (for the log)

local function Setting(settings, key, default, lo, hi)
	local v = settings ~= nil and tonumber(settings[key]) or nil
	if v == nil then
		return default
	end
	return math.max(lo, math.min(hi, v))
end

function Repeat.Options(settings)
	return {
		full = math.floor(Setting(settings, "swap_repeat_full", 2, 0, 20)),
		factor = Setting(settings, "swap_repeat_factor", 0.59, 0, 1),
		window = Setting(settings, "swap_repeat_window", 2.5, 0, 30),
	}
end

-- the factor for one attack (nil = untouched)
function Repeat.FactorFor(attack)
	local proj = attack.GetProjectile ~= nil and attack:GetProjectile() or nil
	if proj ~= nil then
		return type(proj) == "table" and rawget(proj, "twoweapons_factor") or nil
	end
	local who = attack.GetAttacker ~= nil and attack:GetAttacker() or nil
	local f = type(who) == "table" and rawget(who, "twoweapons_factor") or nil
	if f ~= nil and attack.IsDirectPlayerAttack ~= nil and attack:IsDirectPlayerAttack() then
		return f
	end
	return nil
end

function Repeat.Install(G)
	if Repeat.hooked then
		return true
	end
	local AttackCls = rawget(_G, "Attack")
	if type(AttackCls) ~= "table" then
		local ok, mod = pcall(require, "attack")
		AttackCls = ok and type(mod) == "table" and mod or nil
	end
	if AttackCls == nil or type(AttackCls.InitDamageAmount) ~= "function" then
		return false, "Attack:InitDamageAmount"
	end
	local orig = AttackCls.InitDamageAmount
	local function Factor(attack)
		return Repeat.FactorFor(attack)
	end
	AttackCls.InitDamageAmount = function(self, damage_mult, ...)
		local ok, f = true, nil
		if G ~= nil then
			ok, f = G.Call("repeated swap attack damage", Factor, self)
		else
			ok, f = pcall(Factor, self)
		end
		if ok and type(f) == "number" and f ~= 1 then
			damage_mult = (damage_mult or 1) * f
			Repeat.reduced = Repeat.reduced + 1
		end
		return orig(self, damage_mult, ...)
	end
	Repeat.hooked = true
	return true
end

Repeat.STRONG_TYPES = { heavy_attack = true, skill = true }

local function Listed(list, state)
	if type(list) ~= "table" or state == nil then
		return false
	end
	for _, s in ipairs(list) do
		if s == state then
			return true
		end
	end
	return false
end

-- a strong swap move (heavy attack or skill, or listed in swap_repeat_also)
function Repeat.IsStrong(settings, move)
	if type(move) ~= "table" then
		return false
	end
	local state = move.state
	if Listed(settings ~= nil and settings.swap_repeat_skip, state) then
		return false
	end
	if Listed(settings ~= nil and settings.swap_repeat_also, state) then
		return true
	end
	return Repeat.STRONG_TYPES[move.type or "light_attack"] == true
end

-- the move's key: the weapon in hand and the move's state
function Repeat.Key(cmp, move)
	local weapon = cmp.cur ~= nil and cmp.cur.id or "?"
	local state = type(move) == "table" and (move.state or move.name) or tostring(move)
	return tostring(weapon) .. ":" .. tostring(state)
end

-- a swap move started: count it, reduce it from the (full + 1)th time
function Repeat.OnSwapAttack(cmp, move)
	local opts = Repeat.Options(cmp.settings)
	local now = GetTime()
	if cmp.repeat_last == nil or now - cmp.repeat_last > opts.window then
		cmp.repeat_counts = {}
	end
	cmp.repeat_counts = cmp.repeat_counts or {}
	cmp.repeat_last = now
	local key = Repeat.Key(cmp, move)
	local strong = Repeat.IsStrong(cmp.settings, move)
	local n = (cmp.repeat_counts[key] or 0) + 1
	cmp.repeat_counts[key] = n
	local f = (strong and n > opts.full and opts.factor < 1) and opts.factor or nil
	rawset(cmp.inst, "twoweapons_factor", f)
	cmp.repeat_move = key
	if cmp.Debug ~= nil then
		cmp:Debug(string.format("swap move %s (%s), %d time%s in a row%s", key, strong and "strong" or "light: never reduced", n, n == 1 and "" or "s",
			f ~= nil and string.format(": %d%% damage", math.floor(f * 100 + 0.5)) or ""))
	end
	Repeat.Probe(cmp, "swap " .. key)
	return n, f
end

-- the swap move is over: its reduction ends
function Repeat.End(cmp)
	if cmp.repeat_move == nil then
		return
	end
	cmp.repeat_move = nil
	rawset(cmp.inst, "twoweapons_factor", nil)
	Repeat.Probe(cmp, nil)
end

-- arrows / shells fired during a reduced swap move keep its factor
function Repeat.OnLaunched(cmp, projectiles)
	local f = rawget(cmp.inst, "twoweapons_factor")
	local cat = cmp.probe_cat
	if type(projectiles) ~= "table" then
		return
	end
	for _, p in pairs(projectiles) do
		if type(p) == "table" then
			if f ~= nil then
				rawset(p, "twoweapons_factor", f)
			end
			if cat ~= nil then
				rawset(p, "twoweapons_probe", cat)
			end
		end
	end
end

----------------------------------------------------------------------------
-- The damage log: per weapon, light attacks' and each swap move's damage per
-- second of their own time (cmp.settings.swap_damage_log).

Repeat.rates = {} -- category -> { damage, seconds, hits }
Repeat.LOG_EVERY = 60
Repeat.LOG_LIMIT = 20
Repeat.logged = 0
Repeat.last_log = nil

local function Rate(cat)
	local r = Repeat.rates[cat]
	if r == nil then
		r = { damage = 0, seconds = 0, hits = 0 }
		Repeat.rates[cat] = r
	end
	return r
end

-- switch the player's current category (closing the time of the last one)
function Repeat.Probe(cmp, cat)
	if not cmp.settings.swap_damage_log then
		return
	end
	local now = GetTime()
	if cmp.probe_cat ~= nil and cmp.probe_since ~= nil then
		local r = Rate(cmp.probe_cat)
		r.seconds = r.seconds + math.max(0, now - cmp.probe_since)
	end
	cmp.probe_cat = cat
	cmp.probe_since = cat ~= nil and now or nil
end

-- a new state: light attacks (outside swap moves) count as "light <weapon>"
function Repeat.OnNewState(cmp)
	if not cmp.settings.swap_damage_log or cmp.repeat_move ~= nil then
		return
	end
	local sg = cmp.inst.sg
	local light = sg ~= nil and sg:HasStateTag("light_attack") and sg:HasStateTag("attack")
	local cat = light and ("light " .. tostring(cmp.cur ~= nil and cmp.cur.id or "?")) or nil
	if cat ~= cmp.probe_cat then
		Repeat.Probe(cmp, cat)
	end
end

function Repeat.OnDamage(cmp, attack)
	if not cmp.settings.swap_damage_log or type(attack) ~= "table" then
		return
	end
	if attack.IsDirectPlayerAttack == nil or not attack:IsDirectPlayerAttack() then
		return
	end
	local proj = attack.GetProjectile ~= nil and attack:GetProjectile() or nil
	local cat = proj ~= nil and type(proj) == "table" and rawget(proj, "twoweapons_probe") or (proj == nil and cmp.probe_cat or nil)
	if cat == nil then
		return
	end
	local r = Rate(cat)
	r.damage = r.damage + (attack.GetDamage ~= nil and attack:GetDamage() or 0)
	r.hits = r.hits + 1
end

-- the summary: each category's damage per second; for each swap move, the
-- share of it its weapon's light attacks deal in the same time
function Repeat.Summary()
	local lines, light = {}, {}
	for cat, r in pairs(Repeat.rates) do
		local weapon = cat:match("^light (.+)$")
		if weapon ~= nil and r.seconds > 0 then
			light[weapon] = r.damage / r.seconds
		end
	end
	local cats = {}
	for cat in pairs(Repeat.rates) do
		cats[#cats + 1] = cat
	end
	table.sort(cats)
	for _, cat in ipairs(cats) do
		local r = Repeat.rates[cat]
		if r.seconds > 0 and r.hits > 0 then
			local dps = r.damage / r.seconds
			local line = string.format("%s %.1f/s (%d hits, %.1f s)", cat, dps, r.hits, r.seconds)
			local weapon = cat:match("^swap ([^:]+):")
			if weapon ~= nil and light[weapon] ~= nil and dps > 0 then
				line = line .. string.format(", its light attacks: %d%% of it", math.floor(light[weapon] / dps * 100 + 0.5))
			end
			lines[#lines + 1] = line
		end
	end
	return lines
end

function Repeat.LogSummary()
	if Repeat.logged >= Repeat.LOG_LIMIT then
		return false
	end
	local now = GetTime()
	if Repeat.last_log ~= nil and now - Repeat.last_log < Repeat.LOG_EVERY * 0.9 then
		return false -- (another local player's timer just did)
	end
	Repeat.last_log = now
	local lines = Repeat.Summary()
	if #lines == 0 then
		return false
	end
	Repeat.logged = Repeat.logged + 1
	print("[Two Weapons] damage rates: " .. table.concat(lines, "; "))
	return true
end

-- the player's listeners (components/twoweapons.lua calls this once)
function Repeat.Setup(cmp)
	local inst = cmp.inst
	cmp._onlaunched = function(_, projectiles)
		Repeat.OnLaunched(cmp, projectiles)
	end
	inst:ListenForEvent("projectile_launched", cmp._onlaunched)
	if cmp.settings.swap_damage_log then
		cmp._ondodamage = function(_, attack)
			pcall(Repeat.OnDamage, cmp, attack)
		end
		inst:ListenForEvent("do_damage", cmp._ondodamage)
		if inst.DoPeriodicTask ~= nil then
			cmp.log_task = inst:DoPeriodicTask(Repeat.LOG_EVERY, function()
				pcall(Repeat.LogSummary)
			end)
		end
	end
end

function Repeat.Teardown(cmp)
	local inst = cmp.inst
	if cmp._onlaunched ~= nil then
		inst:RemoveEventCallback("projectile_launched", cmp._onlaunched)
	end
	if cmp._ondodamage ~= nil then
		inst:RemoveEventCallback("do_damage", cmp._ondodamage)
	end
	if cmp.log_task ~= nil then
		cmp.log_task:Cancel()
		cmp.log_task = nil
	end
	rawset(inst, "twoweapons_factor", nil)
end

return Repeat
