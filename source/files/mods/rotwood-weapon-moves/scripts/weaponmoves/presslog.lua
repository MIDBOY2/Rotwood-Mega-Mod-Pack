-- Weapon Moves: a short log of what the hammer does with your presses, to find out
-- why a move doesn't come out (hammer_input_log in the settings). With the hammer
-- in hand, each X / Y / B / dodge press writes one line to client_log.txt: the
-- move you're in and its frame, where the stick points compared to where you face
-- (the game's reverse moves - the golf swing, the fade-away swing that starts the
-- spin - need it pointing back, more than 100 degrees away), then the move the
-- game went to. The first 150 presses of a session only (a dodge from running or
-- standing isn't counted: the press after it shows the roll); nothing else runs.

local PressLog = {}

PressLog.MAX = 150
PressLog.count = 0
PressLog.REVERSE = 100 -- the game's angle for a reverse press (sg_player_common.lua)

local NAMES = { lightattack = "X", heavyattack = "Y", skill = "B", dodge = "dodge" }

-- a dodge from these isn't logged (moving about, not a move)
local function Moving(inst)
	local st = inst.sg ~= nil and inst.sg.currentstate or nil
	local name = st ~= nil and st.name or ""
	return name:find("^run") ~= nil or name:find("^idle") ~= nil or name:find("^turn") ~= nil or name:find("^walk") ~= nil
end
PressLog.Moving = Moving

local function diff_angle(a, b)
	local d = math.abs((a - b) % 360)
	return d > 180 and 360 - d or d
end

local function Log(msg)
	print("[Weapon Moves] " .. msg)
end

local function IsHammer(inst)
	local sg = inst.sg
	return sg ~= nil and sg.sg ~= nil and sg.sg.name == "sg_player_hammer"
end

function PressLog.Describe(inst, data)
	local name = NAMES[data.control]
	local st = inst.sg.currentstate
	local frames = inst.sg.GetTicksInState ~= nil and math.floor(inst.sg:GetTicksInState() / (ANIM_FRAMES or 2)) or nil
	local where = (st and st.name or "?") .. (frames ~= nil and (" frame " .. frames) or "")
	local stick
	if data.dir == nil then
		stick = "stick centred"
	else
		local facing = inst.Transform ~= nil and inst.Transform.GetFacingRotation ~= nil and inst.Transform:GetFacingRotation() or nil
		if facing == nil then
			stick = "stick " .. math.floor(data.dir + 0.5) .. " deg"
		else
			local d = diff_angle(data.dir, facing)
			stick = ("stick %d deg from where you face (%s)"):format(math.floor(d + 0.5), d > PressLog.REVERSE and "back" or "ahead")
		end
	end
	return ("hammer: %s in %s, %s"):format(name, where, stick)
end

function PressLog.Attach(inst)
	if inst.weaponmoves_presslog then
		return
	end
	inst.weaponmoves_presslog = true
	local pending = nil
	inst:ListenForEvent("controlevent", function(inst, data)
		if PressLog.count >= PressLog.MAX or data == nil or NAMES[data.control] == nil or not IsHammer(inst) then
			return
		end
		if data.control == "dodge" and Moving(inst) then
			return
		end
		local ok, line = pcall(PressLog.Describe, inst, data)
		if not ok then
			return
		end
		PressLog.count = PressLog.count + 1
		if pending ~= nil then
			Log(pending .. " -> stayed")
		end
		pending = line
		if PressLog.count == PressLog.MAX then
			Log(pending .. " (the last one logged this session: hammer_input_log)")
			pending = nil
		end
	end)
	inst:ListenForEvent("newstate", function(inst, data)
		if pending == nil then
			return
		end
		local name = data ~= nil and data.statename or "?"
		Log(pending .. " -> " .. tostring(name))
		pending = nil
	end)
end

return PressLog
