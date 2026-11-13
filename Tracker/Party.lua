-- Party quest progress in the quest tooltip.
--
-- The game does not give other players' objective counts to addons. Every party member who also runs this addon
-- sends their quest progress over the hidden addon channel (prefix "QTScroll"); the tooltip shows those counts.
-- Party members without this addon: their progress as Questie shares it (Questie's party sync, QuestieComms
-- remoteQuestLogs: objectives with fulfilled/required), when both of you run Questie. Only when neither shares counts
-- does the line fall back to whether they are on the quest at all (C_QuestLog.IsUnitOnQuest).
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api
local db

local PREFIX = "QTScroll"
local progress = {} -- [sender name] = { [questID] = { "3/8", "1/1", ... } }

local function isSecret(v) return issecretvalue and issecretvalue(v) or false end

local function shortName(name)
	if type(name) ~= "string" then return nil end
	return (name:match("^([^%-]+)")) or name
end

-- "questID:f/r,f/r;questID:f/r" in messages of at most 250 bytes
local function encodeAll()
	local parts = {}
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID then
			local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, info.questID)
			local list = {}
			if ok and type(objectives) == "table" then
				for _, o in ipairs(objectives) do
					local f, r = tonumber(o.numFulfilled), tonumber(o.numRequired)
					if f and r and not isSecret(f) and not isSecret(r) then
						list[#list + 1] = f .. "/" .. r
					else
						list[#list + 1] = o.finished and "1/1" or "0/1"
					end
				end
			end
			parts[#parts + 1] = info.questID .. ":" .. table.concat(list, ",")
		end
	end
	local messages, current = {}, ""
	for _, part in ipairs(parts) do
		if #current + #part + 1 > 240 then messages[#messages + 1] = current; current = "" end
		current = (current == "" and part) or (current .. ";" .. part)
	end
	messages[#messages + 1] = "E" .. current -- "E" marks the last message: the sender's list is complete
	return messages
end

-- Sent only when the progress changed since the last send (quest log updates come every few seconds without any
-- change), or when the party changed (newcomers need the full list).
local lastSent
local function send(force)
	if not db or not db.tooltips or db.partyProgress == false or not IsInGroup() or IsInRaid() then lastSent = nil return end
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
	local channel = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME)) and "INSTANCE_CHAT" or "PARTY"
	local messages = encodeAll()
	local all = table.concat(messages, "\n")
	if not force and all == lastSent then return end
	lastSent = all
	for _, message in ipairs(messages) do
		pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel)
	end
end

local pending, pendingForce
local function scheduleSend(delay, force)
	if force then pendingForce = true end
	if pending then return end
	pending = true
	C_Timer.After(delay or 3, function()
		local f = pendingForce
		pending, pendingForce = nil, nil
		send(f)
	end)
end

local incoming = {}
local function receive(sender, message)
	local name = shortName(sender)
	if not name or name == UnitName("player") then return end
	local last = message:sub(1, 1) == "E"
	if last then message = message:sub(2) end
	local into = incoming[name] or {}
	incoming[name] = into
	for part in message:gmatch("[^;]+") do
		local id, list = part:match("^(%d+):(.*)$")
		if id then
			local counts = {}
			for count in list:gmatch("[^,]+") do counts[#counts + 1] = count end
			into[tonumber(id)] = counts
		end
	end
	if last then
		progress[name] = into
		incoming[name] = nil
	end
end

-- Questie's party sync: QuestieComms.remoteQuestLogs[questID][playerName] = { { fulfilled, required, finished }, ... }
local function questieCounts(name, questID)
	local loader = _G.QuestieLoader
	if not (C_AddOns.IsAddOnLoaded("Questie") and type(loader) == "table" and type(loader.ImportModule) == "function") then
		return nil
	end
	local ok, comms = pcall(loader.ImportModule, loader, "QuestieComms")
	local logs = ok and type(comms) == "table" and comms.remoteQuestLogs
	local players = type(logs) == "table" and logs[questID]
	if type(players) ~= "table" then return nil end
	local objectives = players[name]
	if objectives == nil then
		for player, list in pairs(players) do -- "Name-Realm" keys
			if type(player) == "string" and shortName(player) == name then objectives = list break end
		end
	end
	if type(objectives) ~= "table" then return nil end
	local counts = {}
	for i = 1, #objectives do
		local o = objectives[i]
		local f, r = type(o) == "table" and tonumber(o.fulfilled), type(o) == "table" and tonumber(o.required)
		if f and r then counts[#counts + 1] = f .. "/" .. r
		elseif type(o) == "table" then counts[#counts + 1] = o.finished and "1/1" or "0/1" end
	end
	return counts
end

-- "3/8  1/1" from counts, and whether every objective is done
local function describe(counts)
	if #counts == 0 then return "nothing to collect", true end
	local done = true
	for _, count in ipairs(counts) do
		local f, r = count:match("(%d+)/(%d+)")
		if f and tonumber(f) < tonumber(r) then done = false end
	end
	if done then return "done (" .. table.concat(counts, "  ") .. ")", true end
	return table.concat(counts, "  "), false
end

local function onQuest(unit, questID)
	if C_QuestLog.IsUnitOnQuest then
		local ok, value = pcall(C_QuestLog.IsUnitOnQuest, unit, questID)
		if ok and type(value) == "boolean" then return value end
	end
	if _G.IsUnitOnQuest then
		local index = C_QuestLog.GetLogIndexForQuestID(questID)
		local ok, value = pcall(_G.IsUnitOnQuest, index, unit)
		if ok and value ~= nil then return value and value ~= 0 end
	end
end

function api.addPartyProgress(tip, questID)
	if not IsInGroup() or IsInRaid() then return end
	local lines = {}
	for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 4) do
		local unit = "party" .. i
		if UnitExists(unit) then
			local name = UnitName(unit)
			if type(name) == "string" and not isSecret(name) then
				-- their progress: from this addon, else from Questie's party sync
				local data = progress[name] and progress[name][questID]
				if not data then data = questieCounts(name, questID) end
				if data then
					local text, done = describe(data)
					lines[#lines + 1] = { name, text, done }
				elseif progress[name] then
					lines[#lines + 1] = { name, "not on quest", nil, true }
				else
					local on = onQuest(unit, questID)
					if on == false then
						lines[#lines + 1] = { name, "not on quest", nil, true }
					elseif on then
						-- on the quest, but neither this addon nor Questie shares their counts
						lines[#lines + 1] = { name, "on quest (no progress shared)", nil, true }
					end
				end
			end
		end
	end
	if #lines == 0 then return end
	tip:AddLine(" ")
	tip:AddLine(PARTY or "Party", 1, 0.82, 0)
	for _, line in ipairs(lines) do
		local r, g, b = 1, 1, 1
		if line[3] then r, g, b = 0.5, 0.9, 0.5 elseif line[4] then r, g, b = 0.6, 0.6, 0.6 end
		tip:AddDoubleLine(line[1], line[2], 0.8, 0.8, 0.8, r, g, b)
	end
end

ns.onLogin[#ns.onLogin + 1] = function()
	db = ns.db
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
	local frame = CreateFrame("Frame")
	for _, e in ipairs({ "CHAT_MSG_ADDON", "QUEST_LOG_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
		pcall(frame.RegisterEvent, frame, e)
	end
	frame:SetScript("OnEvent", function(_, event, prefix, message, _, sender)
		if event == "CHAT_MSG_ADDON" then
			if prefix == PREFIX and type(message) == "string" and not isSecret(message) then pcall(receive, sender, message) end
		elseif event == "GROUP_ROSTER_UPDATE" then
			for name in pairs(progress) do
				if not UnitInParty(name) then progress[name] = nil end
			end
			scheduleSend(2, true)
		elseif event == "PLAYER_ENTERING_WORLD" then
			scheduleSend(3, true)
		else
			scheduleSend(3)
		end
	end)
end
