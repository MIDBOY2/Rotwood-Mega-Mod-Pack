-- Save States: the keys (the number row + modifiers, matched exactly), and
-- the game's debug keys kept off our presses (Ctrl+1 .. Ctrl+4 set the debug
-- menu's text size when the debug keys are on).
local SS = require "savestates.main"

local K = {}

K.TheInput = nil
K.Keys = nil      -- InputConstants.Keys
K.actions = nil   -- { save(slot), load(slot, mode), latest(mode), menu(), typing() -> bool }
K.codes = {}      -- key code -> "1".."0" / "L" ...

local NUMBERS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }

local function Mods()
	local I, Keys = K.TheInput, K.Keys
	return {
		ctrl = I:IsKeyDown(Keys.CTRL) == true,
		shift = I:IsKeyDown(Keys.SHIFT) == true,
		alt = I:IsKeyDown(Keys.ALT) == true,
	}
end

local function Same(b, m)
	return b ~= nil and b.ctrl == m.ctrl and b.shift == m.shift and b.alt == m.alt
end

local function SlotOf(name)
	local n = tonumber(name)
	if n == nil then
		return nil
	end
	return n == 0 and 10 or n
end

-- what a press does: kind, slot (or nil)
function K.Match(name, m)
	local keys = SS.settings.keys
	for _, kind in ipairs({ "menu", "latest_rebuild", "latest_replicate" }) do
		local b = keys[kind]
		if b ~= nil and b.key == name and Same(b, m) then
			return kind
		end
	end
	local slot = SlotOf(name)
	if slot ~= nil then
		for _, kind in ipairs({ "save", "rebuild", "replicate" }) do
			if Same(keys[kind], m) then
				return kind, slot
			end
		end
	end
	return nil
end

function K.OnKey(name)
	if K.actions.typing ~= nil and K.actions.typing() then
		return
	end
	local kind, slot = K.Match(name, Mods())
	if kind == nil then
		return
	end
	if kind == "save" then
		K.actions.save(slot)
	elseif kind == "rebuild" then
		K.actions.load(slot, "rebuild")
	elseif kind == "replicate" then
		K.actions.load(slot, "replicate")
	elseif kind == "latest_rebuild" then
		K.actions.latest("rebuild")
	elseif kind == "latest_replicate" then
		K.actions.latest("replicate")
	elseif kind == "menu" then
		K.actions.menu()
	end
end

function K.Install(TheInput, Keys, actions)
	assert(TheInput ~= nil and TheInput.AddKeyDownHandler ~= nil and TheInput.IsKeyDown ~= nil, "the game's input changed")
	assert(type(Keys) == "table" and Keys.CTRL ~= nil and Keys.SHIFT ~= nil and Keys.ALT ~= nil, "the game's key list changed")
	K.TheInput, K.Keys, K.actions = TheInput, Keys, actions
	-- bound once per input object (a press calls K.OnKey, which reads the current actions)
	if rawget(TheInput, "_savestates_bound") then
		return true, "keys (already bound)"
	end
	-- (the game's key list errors on a name it doesn't have)
	local function Code(name)
		local ok, code = pcall(function() return Keys[name] end)
		return ok and code or nil
	end
	local names = {}
	for _, n in ipairs(NUMBERS) do
		names[n] = Code("NUM_" .. n)
	end
	for kind, b in pairs(SS.settings.keys) do
		if b.key ~= nil and names[b.key] == nil then
			names[b.key] = Code(b.key)
			if names[b.key] == nil then
				SS.Log("keys." .. kind .. ": the game has no key " .. b.key)
			end
		end
	end
	local count = 0
	for name, code in pairs(names) do
		if code ~= nil then
			K.codes[code] = name
			TheInput:AddKeyDownHandler(code, function()
				local ok, err = pcall(K.OnKey, name)
				if not ok then
					SS.Log("key " .. name .. ": " .. tostring(err))
				end
			end)
			count = count + 1
		end
	end
	pcall(rawset, TheInput, "_savestates_bound", true)
	return true, count .. " keys"
end

-- the game's debug keys: our presses don't reach them
function K.WrapDebugKeys(G)
	local orig = rawget(G, "DoDebugKey")
	if type(orig) ~= "function" then
		return false, "off (the debug keys aren't on)"
	end
	rawset(G, "DoDebugKey", function(key, down)
		local name = K.codes[key]
		if name ~= nil and SS.settings.keep_debug_text_size then
			local ok, kind = pcall(K.Match, name, Mods())
			if ok and kind ~= nil then
				return true
			end
		end
		return orig(key, down)
	end)
	return true, "our keys don't reach the debug keys"
end

return K
