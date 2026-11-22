-- Camp Brother: Gishins, Doc Hoggins' brother, made by the game's own NPC maker
-- (prefabs/npc_autogen.lua MakeAutogenNpc / MakeAutogenMouth), the same as every NPC
-- in camp:
--   a body on the game's NPC animations (npc_template), a head on Doc's own head
--     animations following the body's head_follow symbol, a mouth on every NPC's mouth
--     animations following the head's mouth_swap symbol; his builds are Doc's,
--     recoloured (anim/campbrother.zip, anim/campbrother_head.zip: sandy tan, red
--     coat, charcoal pants, black hat with a red wing)
--   the game's NPC brain (brains/brain_core_npc.lua): he turns to face the nearest
--     player (within 10, or the one he's talking to) and stands still
--   the game's NPC stategraph (stategraphs/sg_npc.lua): idle and blink, the emotes in
--     his lines, the talking mouth while a line is spoken
--   the game's interact and conversation (Chit Chat on RB): what he says is
--     scripts/campbrother/chat.lua with the lines in scripts/campbrother_strings.lua
--   Doc's voice (components/talkaudio.lua: Doc's speech sounds)
-- Spawned by the host like the camp's NPCs, not saved (put back each time the camp
-- loads). The only additions to the game's NPC: his own head build, Doc's voice, and
-- his chat given to you when you walk up to him (campbrother/chat.lua).

local Chat = require "campbrother.chat"

local NAME = "campbrother_npc"
local BODY_BUILD = "campbrother"
local HEAD_BUILD = "campbrother_head"
local HEAD_BANK = "npc_potionmaker_dungeon_head" -- Doc's head animations
local VOICE = "npc_potionmaker_dungeon" -- Doc's speech sounds

local params = {
	build = BODY_BUILD,
	bank = "npc_template", -- every NPC's body animations
	head = HEAD_BANK, -- the game uses the head's build name as its animations' name; his build goes on below
	role = "campbrother", -- his own role (his chat finds him by name; no game quest looks for this role)
	default_feeling = "happy", -- like Doc: the happy mouth
}

if type(rawget(_G, "MakeAutogenNpc")) ~= "function" or type(rawget(_G, "MakeAutogenMouth")) ~= "function" then
	print("[Camp Brother] no brother: the game's NPC maker changed (prefabs/npc_autogen.lua)")
	return
end

local npc = MakeAutogenNpc(NAME, params)
local mouth = MakeAutogenMouth(NAME, { head = HEAD_BUILD }) -- mouth symbols come from his head build

-- his builds as assets (the game's maker adds what it can find under anim/); the game's
-- NpcEditor file reference for him doesn't exist, so it goes
local function has_asset(assets, file)
	for _, a in ipairs(assets) do
		if a.file == file then
			return true
		end
	end
	return false
end
for i = #npc.assets, 1, -1 do
	local a = npc.assets[i]
	if a.type == "PKGREF" and a.file == "scripts/prefabs/autogen/npc/" .. NAME .. ".lua" then
		table.remove(npc.assets, i)
	end
end
for _, file in ipairs({ "anim/" .. BODY_BUILD .. ".zip", "anim/" .. HEAD_BUILD .. ".zip", "anim/" .. HEAD_BANK .. ".zip", "anim/npc_template.zip" }) do
	if not has_asset(npc.assets, file) then
		npc.assets[#npc.assets + 1] = Asset("ANIM", file)
	end
end
if not has_asset(mouth.assets, "anim/" .. HEAD_BUILD .. ".zip") then
	mouth.assets[#mouth.assets + 1] = Asset("ANIM", "anim/" .. HEAD_BUILD .. ".zip")
end

-- his name for the speech bubble (the game reads STRINGS.NAMES[prefab]); modmain
-- puts it where the game keeps it, this only fills it in if something lost it
local function EnsureName()
	local S = rawget(_G, "STRINGS")
	local cur = S ~= nil and type(S.NAMES) == "table" and S.NAMES[NAME] or nil
	if S ~= nil and type(S.NAMES) == "table" and (type(cur) ~= "string" or cur == "" or cur:find("MISSING:", 1, true) == 1) then
		local ok, lines = pcall(require, "campbrother_strings")
		S.NAMES[NAME] = ok and type(lines) == "table" and type(lines.NAME) == "string" and lines.NAME or "Gishins"
	end
end

local base_fn = npc.fn
npc.fn = function(prefabname, ...)
	EnsureName()
	local inst = base_fn(prefabname, ...)
	if inst.head ~= nil and inst.head.AnimState ~= nil then
		inst.head.AnimState:SetBuild(HEAD_BUILD)
	end
	local talkaudio = inst.components.talkaudio
	if talkaudio ~= nil then
		talkaudio.npc_prefab = VOICE
	end
	Chat.HookConversation(inst)
	return inst
end

return npc, mouth
