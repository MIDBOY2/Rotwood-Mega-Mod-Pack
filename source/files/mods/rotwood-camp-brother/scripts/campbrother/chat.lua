-- Camp Brother: Gishins' Chit Chat, made the game's way.
--
-- A recurring chat quest (questral), like Doc's potion shop chat
-- (quests/shop_potion/dgn_shop_potion.lua): one objective, one OnAttract convo on the
-- "giver" (him), low importance so the prompt says "Chit Chat" and he gets no quest
-- mark. It goes into the game's quest content (the ContentDB) once when the game
-- loads, and each player gets it for him the way every NPC gets its fallback chat
-- (components/conversation.lua _GetBestQuest -> GetOrSpawnQuest_ForCastMember): when
-- you walk up to him. It isn't saved (SetIsTemporary, like chat_fluff_fallback), so
-- nothing of it stays in your save if the mod goes.
--
-- The convo: a random "hey" line (the same words, a different emote), then the game's
-- questions (cx:Question: QUESTION_n / ANSWER_n, each once a talk) in a loop, and the
-- game's own leave option (STRINGS.TALK.OPT_LEAVE, "Sorry, I've gotta run!").

local Chat = {}

Chat.ID = "campbrother_chat"
Chat.OBJECTIVE = "chat"
Chat.TONIC_TABLE = "tonicswap_potion_table"

-- The quest's strings from campbrother_strings.lua: the TALK list becomes TALK_1..n,
-- everything else (QUESTION_n, ANSWER_n, ANSWER_n_TABLE) as written. Returns the
-- strings and how many TALK lines there are.
function Chat.Strings(user)
	local s, n = {}, 0
	if type(user) ~= "table" then
		return s, 0
	end
	for k, v in pairs(user) do
		if k ~= "TALK" and k ~= "NAME" and type(k) == "string" and type(v) == "string" then
			s[k] = v
		end
	end
	if type(user.TALK) == "table" then
		for _, t in ipairs(user.TALK) do
			if type(t) == "string" then
				n = n + 1
				s["TALK_" .. n] = t
			end
		end
	elseif type(user.TALK) == "string" then
		n = 1
		s.TALK_1 = user.TALK
	end
	return s, n
end

-- The game fills in {name.x} / {name_multiple.x} in every quest's lines when it sets
-- its language, and an unknown name there stops it with an error screen. So a name
-- that isn't the game's (a typo in campbrother_strings.lua) becomes plain text here.
-- Returns the names that weren't found.
local NAME_FORMS = {
	{ "{name%.([_a-z0-9]-)}", "NAMES" }, { "{name_multiple%.([_a-z0-9]-)}", "NAMES_PLURAL" },
	{ "{NAME%.([_a-z0-9]-)}", "NAMES" }, { "{NAME_MULTIPLE%.([_a-z0-9]-)}", "NAMES_PLURAL" },
}
function Chat.CheckNames(strings, S)
	S = S or rawget(_G, "STRINGS")
	local missing = {}
	if type(S) ~= "table" or type(S.NAMES) ~= "table" then
		return missing
	end
	for k, v in pairs(strings) do
		for _, form in ipairs(NAME_FORMS) do
			local names = S[form[2]]
			if type(names) == "table" then
				v = v:gsub(form[1], function(key)
					if names[key] == nil then
						missing[#missing + 1] = key
						return key
					end
				end)
			end
		end
		strings[k] = v
	end
	return missing
end

-- Tonic Swap's working Potion Table is in the game (its lines about the table only then)
function Chat.HasPotionTable()
	local exists = rawget(_G, "PrefabExists")
	return exists ~= nil and exists(Chat.TONIC_TABLE) == true
end

-- the questions, in order: "1", "2", ... while QUESTION_n and ANSWER_n are there
function Chat.Questions(strings)
	local ids = {}
	local i = 1
	while strings["QUESTION_" .. i] ~= nil and strings["ANSWER_" .. i] ~= nil do
		ids[#ids + 1] = tostring(i)
		i = i + 1
	end
	return ids
end

-- The conversation (cx: the game's ConvoPlayer).
function Chat.Convo(cx, strings, n, rand, has_table)
	rand = rand or math.random
	has_table = has_table or Chat.HasPotionTable
	if n > 0 then
		cx:Talk("TALK_" .. rand(n))
	end
	local questions = Chat.Questions(strings)
	local table_lines = has_table()
	cx:Loop(function()
		for _, id in ipairs(questions) do
			local opt = cx:Question(id)
			if table_lines and strings["ANSWER_" .. id .. "_TABLE"] ~= nil then
				opt:Talk("ANSWER_" .. id .. "_TABLE")
			end
		end
		cx:AddEnd()
	end)
end

-- The quest class (Quest = questral.quest, Convo = questral.convo).
function Chat.Build(Quest, Convo, strings, n, npc_prefab)
	local Q = Quest.Create(Quest.QUEST_TYPE.s.CHAT, Chat.ID)
	Q:AddCast("giver")
		:FilterForPrefab(npc_prefab)
		:SetDeferred() -- he's given to it when you walk up (like the fallback chat)
	-- like Quest.CreateRecurringChat: no state kept, so it's there every time
	Q.skip_state_persist = true
	-- and not saved at all (like chat_fluff_fallback)
	Q:SetIsTemporary(true)
	-- "Chit Chat" on the prompt, no quest mark
	Q:SetIsUnimportant()
	Q:AddObjective(Chat.OBJECTIVE)
		:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	Q:OnAttract(Chat.OBJECTIVE, "giver")
		:SetPriority(Convo.PRIORITY.LOW)
		:Strings(strings)
		:Fn(function(cx)
			Chat.Convo(cx, strings, n)
		end)
	return Q
end

-- From modmain: build the quest and add it to the game's quest content. Returns ok,
-- why.
function Chat.Install(user_strings, npc_prefab, req)
	req = req or require
	local strings, n = Chat.Strings(user_strings)
	if n == 0 then
		return false, "campbrother_strings.lua has no TALK line"
	end
	local missing = Chat.CheckNames(strings)
	if #missing > 0 then
		print("[Camp Brother] campbrother_strings.lua: not the game's names, shown as plain words: " .. table.concat(missing, ", "))
	end
	local content = rawget(_G, "TheGameContent")
	if content == nil or content.GetContentDB == nil then
		return false, "the game's quest content isn't there"
	end
	local db = content:GetContentDB()
	local Quest = req "questral.quest"
	local Convo = req "questral.convo"
	if db:TryGet(Quest, Chat.ID) ~= nil then
		return true, "already in"
	end
	db:AddContentItem(Chat.Build(Quest, Convo, strings, n, npc_prefab))
	Chat.installed = true
	return true
end

-- On him: before the game picks what he says to a player (its _GetBestQuest), the
-- player gets his chat, like the game gives every NPC its fallback chat.
-- his chat is in the game's quest content (Install ran, or the content has it)
function Chat.Ready()
	if not Chat.installed then
		local content = rawget(_G, "TheGameContent")
		local ok, Quest = pcall(require, "questral.quest")
		if ok and content ~= nil and content:GetContentDB():TryGet(Quest, Chat.ID) ~= nil then
			Chat.installed = true
		end
	end
	return Chat.installed == true
end

function Chat.EnsureFor(conversation, player)
	if player == nil or player.components == nil or player.components.questcentral == nil or not Chat.Ready() then
		return
	end
	local qm, actor = conversation:_GetQuestManagerForQuester(player)
	if qm ~= nil and actor ~= nil then
		qm:GetOrSpawnQuest_ForCastMember(Chat.ID, actor)
	end
end

local warned = false
function Chat.HookConversation(inst, tag)
	local conv = inst.components ~= nil and inst.components.conversation or nil
	if conv == nil or type(conv._GetBestQuest) ~= "function" then
		return false
	end
	local base = conv._GetBestQuest
	conv._GetBestQuest = function(self, player, ...)
		local ok, err = pcall(Chat.EnsureFor, self, player)
		if not ok and not warned then
			warned = true
			print((tag or "[Camp Brother]") .. " error giving his chat (he only says the game's lines): " .. tostring(err))
		end
		return base(self, player, ...)
	end
	return true
end

return Chat
