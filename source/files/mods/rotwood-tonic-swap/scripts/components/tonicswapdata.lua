-- Tonic Swap: what a player picked in the potions menu, saved with the character.
--   main: the main tonic's name, or "none". nil = never opened the menu (then
--         every tonic counts as out: no tonic).
--   off:  tonics taken out of the cycle (name -> true). Tonics not listed are
--         in it, so tonics added by a game update join the cycle by themselves.
--   standin: { out, on }: the tonic sitting out while a power does its job
--         (Iron Brew: Bulbug Boba) and the one put on for it, so it comes back
--         when the power goes (tonicswap/main.lua: ApplySittingOut).

local TonicSwapData = Class(function(self, inst)
	self.inst = inst
	self.main = nil
	self.off = {}
	self.standin = nil
end)

function TonicSwapData:GetStandIn()
	if self.standin == nil then
		return nil
	end
	return self.standin.out, self.standin.on
end

function TonicSwapData:SetStandIn(out, on)
	self.standin = type(out) == "string" and { out = out, on = type(on) == "string" and on or "none" } or nil
end

function TonicSwapData:IsPicked()
	return self.main ~= nil
end

function TonicSwapData:GetMain()
	return self.main or "none"
end

function TonicSwapData:SetMain(name)
	self.main = type(name) == "string" and name or "none"
end

function TonicSwapData:IsOff(name)
	return self.off[name] == true
end

function TonicSwapData:SetOff(name, off)
	self.off[name] = off and true or nil
end

-- Bubbling Brew's sip taken from a charge (tonicswap/potions.lua: SaveSips /
-- RestoreSips), so the next room doesn't give it back
local function PotionsMod()
	local P = package.loaded["tonicswap.potions"]
	return type(P) == "table" and P.SaveSips ~= nil and P or nil
end

function TonicSwapData:OnSave()
	local P = PotionsMod()
	local ok, sips = false, nil
	if P ~= nil then
		ok, sips = pcall(P.SaveSips, self.inst)
	end
	sips = ok and sips or nil
	if self.main == nil and next(self.off) == nil and sips == nil and self.standin == nil then
		return nil
	end
	local off = {}
	for name in pairs(self.off) do
		off[#off + 1] = name
	end
	table.sort(off)
	return { main = self.main, off = off, sips = sips, standin = self.standin }
end

function TonicSwapData:OnLoad(data)
	if type(data) ~= "table" then
		return
	end
	if type(data.main) == "string" then
		self.main = data.main
	end
	if type(data.off) == "table" then
		for _, name in ipairs(data.off) do
			if type(name) == "string" then
				self.off[name] = true
			end
		end
	end
	if type(data.standin) == "table" and type(data.standin.out) == "string" then
		self:SetStandIn(data.standin.out, data.standin.on)
	end
	if type(data.sips) == "table" then
		-- once the player's potions are set up (the inventory may load after us)
		local saved = data.sips
		local function restore(inst)
			local P = PotionsMod()
			if P ~= nil then
				pcall(P.RestoreSips, inst, saved)
			end
		end
		if self.inst.DoTaskInTime ~= nil then
			self.inst:DoTaskInTime(0, restore)
		else
			restore(self.inst)
		end
	end
end

function TonicSwapData:GetDebugString()
	local off = {}
	for name in pairs(self.off) do
		off[#off + 1] = name
	end
	table.sort(off)
	return "main=" .. self:GetMain() .. " off=" .. table.concat(off, ",")
		.. (self.standin ~= nil and (" standin=" .. self.standin.out .. ">" .. self.standin.on) or "")
end

return TonicSwapData
