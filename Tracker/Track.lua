-- Tracking mode: "Track all quests" or "Manually track quests" (only one of these two and "Sort all quests by zone"
-- can be active; they are switched off by each other).
--   all     every quest in the log is added to the tracker (up to the game's limit), also new ones and after login.
--   manual  new quests are not tracked automatically: the game's autoQuestWatch setting is switched off (and restored
--           when the mode ends). If the client has no such setting, a freshly accepted quest is un-tracked instead.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api
local db
local CVAR = "autoQuestWatch"

local function getCVar()
	local ok, value = pcall(GetCVar, CVAR)
	if ok then return value end
end

local function maxWatches()
	return (Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES) or 25
end

local function trackAll()
	if InCombatLockdown() then return end
	local limit = maxWatches()
	if C_QuestLog.GetNumQuestWatches() >= limit then return end -- the list is full: nothing to add (most updates)
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and not (db.zoneHidden and db.zoneHidden[info.questID]) then
			if C_QuestLog.GetQuestWatchType(info.questID) == nil then
				if C_QuestLog.GetNumQuestWatches() >= limit then return end
				C_QuestLog.AddQuestWatch(info.questID)
			end
		end
	end
end

local timer
local function schedule(fn, delay)
	if timer then return end
	timer = true
	C_Timer.After(delay or 0.7, function() timer = nil; xpcall(fn, geterrorhandler()) end)
end

local lastAccepted
local function onEvent(event, questID)
	if db.trackMode == "all" then
		schedule(trackAll)
	elseif db.trackMode == "manual" and event == "QUEST_ACCEPTED" and getCVar() == nil and questID then
		lastAccepted = questID
		C_Timer.After(0.5, function()
			if db.trackMode == "manual" and lastAccepted == questID and not InCombatLockdown()
				and C_QuestLog.GetQuestWatchType(questID) ~= nil then
				C_QuestLog.RemoveQuestWatch(questID)
			end
		end)
	end
end

local function applyMode()
	local mode = db.trackMode
	local current = getCVar()
	if mode == "manual" then
		if current ~= nil then
			if db.savedAutoWatch == nil then db.savedAutoWatch = current end
			pcall(SetCVar, CVAR, "0")
		end
	elseif db.savedAutoWatch ~= nil then
		pcall(SetCVar, CVAR, db.savedAutoWatch)
		db.savedAutoWatch = nil
	end
	if mode == "all" then trackAll() end
end

-- mode: "all", "manual" or nil. Choosing one switches "sort by zone" off.
function api.setTrackMode(mode)
	db.trackMode = mode
	if mode and db.zoneSort then
		db.zoneSort = false
		if api.applyZoneHeaders then api.applyZoneHeaders() end
	end
	applyMode()
	if api.refreshConfig then api.refreshConfig() end
end

-- The four tracking choices are one exclusive group:
--   Track all quests                 trackMode "all",    zoneSort false
--   Track all quests by zone         trackMode "all",    zoneSort true  (zone headers)
--   Manually track quests            trackMode "manual", zoneSort false
--   Manually track quests by zone    trackMode "manual", zoneSort true  (zone headers)
function api.setMode(mode, byZone)
	db.trackMode = mode
	db.zoneSort = (mode ~= nil and byZone) and true or false
	applyMode()
	if api.applyZoneHeaders then api.applyZoneHeaders() end
	if db.zoneSort and api.sortNow then api.sortNow() end
	if api.refreshConfig then api.refreshConfig() end
end

function api.modeIs(mode, byZone)
	if byZone then
		-- older settings: sort by zone without a tracking mode counts as "track all quests by zone"
		return db.zoneSort and (db.trackMode or "all") == mode
	end
	return not db.zoneSort and db.trackMode == mode
end

ns.onLogin[#ns.onLogin + 1] = function()
	db = ns.db
	local frame = CreateFrame("Frame")
	for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }) do pcall(frame.RegisterEvent, frame, e) end
	frame:SetScript("OnEvent", function(_, event, questID) onEvent(event, questID) end)
	if db.trackMode == "all" or db.trackMode == "manual" then C_Timer.After(3, applyMode) else applyMode() end
end
