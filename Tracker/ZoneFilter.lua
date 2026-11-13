-- "Show quests in my zone": quests of other zones are un-tracked (and remembered in db.zoneHidden) and tracked again
-- when you enter their zone or switch the option off. The super-tracked quest is never hidden. Independent of the
-- zone sort option.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api
local db
local MAP_TYPE_ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local function isSecret(v) return issecretvalue and issecretvalue(v) or false end

local function currentZone()
	local names, onMap = {}, {}
	local function add(name)
		if type(name) == "string" and name ~= "" and not isSecret(name) then names[name:lower()] = true end
	end
	if GetZoneText then add(GetZoneText()) end
	if GetRealZoneText then add(GetRealZoneText()) end
	if C_Map and C_Map.GetBestMapForUnit then
		local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
		local depth = 0
		while ok and type(mapID) == "number" and mapID > 0 and depth < 8 do
			depth = depth + 1
			local okInfo, info = pcall(C_Map.GetMapInfo, mapID)
			if not okInfo or type(info) ~= "table" then break end
			if info.mapType and info.mapType < MAP_TYPE_ZONE then break end
			add(info.name)
			if C_QuestLog.GetQuestsOnMap then
				local okQ, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
				if okQ and type(quests) == "table" then
					for _, q in ipairs(quests) do if type(q) == "table" and q.questID then onMap[q.questID] = true end end
				end
			end
			mapID = info.parentMapID
		end
	end
	return names, onMap
end

local function headerTitle(questID)
	local index = C_QuestLog.GetLogIndexForQuestID(questID)
	if not index then return nil end
	local headerIndex
	if C_QuestLog.GetHeaderIndexForQuest then
		local ok, value = pcall(C_QuestLog.GetHeaderIndexForQuest, questID)
		if ok then headerIndex = value end
	end
	if not headerIndex then
		for i = index, 1, -1 do
			local info = C_QuestLog.GetInfo(i)
			if info and info.isHeader then headerIndex = i break end
		end
	end
	local info = headerIndex and C_QuestLog.GetInfo(headerIndex)
	local title = info and info.title
	if type(title) == "string" and not isSecret(title) then return title end
end

local function inZone(questID, names, onMap)
	if onMap[questID] then return true end
	local title = headerTitle(questID)
	if not title then return true end
	return names[title:lower()] == true
end

local function maxWatches()
	return (Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES) or 25
end

local running
local function run()
	if not db then return end
	if InCombatLockdown() then running = "combat" return end
	running = nil
	local hidden = db.zoneHidden
	for questID in pairs(hidden) do
		if not C_QuestLog.GetLogIndexForQuestID(questID) then hidden[questID] = nil end
	end
	local names, onMap = currentZone()
	local active = db.zoneFilter and db.enabled
	for questID in pairs(hidden) do
		if not active or inZone(questID, names, onMap) then
			if C_QuestLog.GetQuestWatchType(questID) ~= nil then
				hidden[questID] = nil
			elseif C_QuestLog.GetNumQuestWatches() < maxWatches() then
				C_QuestLog.AddQuestWatch(questID)
				hidden[questID] = nil
			end
		end
	end
	if active and next(names) then
		local sup = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
		local list = {}
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
			if id then list[#list + 1] = id end
		end
		for _, questID in ipairs(list) do
			if questID ~= sup and not inZone(questID, names, onMap) then
				C_QuestLog.RemoveQuestWatch(questID)
				hidden[questID] = true
			end
		end
	end
	if api.sortNow then api.sortNow() end
end

local timer
local function schedule(delay)
	if timer then return end
	timer = true
	C_Timer.After(delay or 1.5, function() timer = nil; xpcall(run, geterrorhandler()) end)
end

function api.setZoneFilter(enabled)
	db.zoneFilter = enabled and true or false
	run()
	if api.refreshConfig then api.refreshConfig() end
end

function api.restoreZone()
	local was = db.zoneFilter
	db.zoneFilter = false
	run()
	db.zoneFilter = was
end

ns.onLogin[#ns.onLogin + 1] = function()
	db = ns.db
	if type(db.zoneHidden) ~= "table" then db.zoneHidden = {} end
	local frame = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_REGEN_ENABLED" }) do
		pcall(frame.RegisterEvent, frame, e)
	end
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" and running ~= "combat" then return end
		if db.zoneFilter or next(db.zoneHidden) then schedule(event == "QUEST_REMOVED" and 0.5 or 1.5) end
	end)
end
