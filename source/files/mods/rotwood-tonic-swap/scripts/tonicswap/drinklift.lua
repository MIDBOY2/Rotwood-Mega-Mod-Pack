-- Tonic Swap: while you drink a potion, the health bar and the potion icon
-- over your head (PlayerFollowHealthBar / PlayerFollowPotion) move up by
-- drink_lift, so they don't cover the drinking animation (the flask comes up
-- to your face and is thrown up at the end). "Drinking" is the game's potion
-- states: pulling the flask out, holding it, drinking, putting it back. A
-- potion press with no charges left only shows the bar and icon (the game
-- doesn't start a drink), so they stay where the game puts them. They glide
-- up and back down instead of jumping.

local DrinkLift = {}

DrinkLift.STATES = { potion_pre = true, potion_hold = true, potion = true, potion_fast = true, potion_pre_cancel = true }
DrinkLift.lift = 110 -- UI units (the health bar sits 360 over your feet, the potion icon 440)
DrinkLift.GLIDE = 0.08 -- seconds: the time constant of the glide (most of the way in 0.2 s)

local function Now()
	local fn = rawget(_G, "GetTime")
	return fn ~= nil and fn() or 0
end

function DrinkLift.IsDrinking(owner)
	local sg = owner ~= nil and owner.sg or nil
	local name = sg ~= nil and sg.GetCurrentState ~= nil and sg:GetCurrentState() or nil
	return name ~= nil and DrinkLift.STATES[name] == true
end

-- the widget's lift this frame, gliding toward where it should be
function DrinkLift.Step(widget)
	local target = DrinkLift.IsDrinking(widget.owner) and DrinkLift.lift or 0
	local now = Now()
	local cur = widget.tonicswap_lift or 0
	local last = widget.tonicswap_lift_t
	widget.tonicswap_lift_t = now
	local dt = last ~= nil and now - last or nil
	if dt == nil or dt > 0.5 or dt < 0 then
		cur = target -- first frame, or the widget was hidden a while: no glide
	else
		cur = cur + (target - cur) * (1 - math.exp(-dt / DrinkLift.GLIDE))
		if math.abs(target - cur) < 0.5 then
			cur = target
		end
	end
	widget.tonicswap_lift = cur
	return cur
end

local function Wrap(cls)
	if type(cls) ~= "table" or type(cls.UpdatePosition) ~= "function" or rawget(cls, "tonicswap_drinklift") then
		return false
	end
	cls.tonicswap_drinklift = true
	local orig = cls.UpdatePosition
	cls.UpdatePosition = function(self, ...)
		local results = table.pack(orig(self, ...))
		local ok, lift = pcall(DrinkLift.Step, self)
		if ok and lift ~= 0 and self.GetPosition ~= nil then
			local x, y = self:GetPosition()
			if x ~= nil and y ~= nil then
				self:SetPosition(x, y + lift)
			end
		end
		return table.unpack(results, 1, results.n)
	end
	return true
end

-- Returns how many of the two widgets were hooked.
function DrinkLift.Install(lift)
	DrinkLift.lift = tonumber(lift) or DrinkLift.lift
	local n = 0
	for _, path in ipairs({ "widgets/ftf/playerfollowhealthbar", "widgets/ftf/playerfollowpotion" }) do
		local ok, cls = pcall(require, path)
		if ok and Wrap(cls) then
			n = n + 1
		end
	end
	return n
end

return DrinkLift
