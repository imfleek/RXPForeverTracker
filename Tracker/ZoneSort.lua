-- Sort all quests by zone, with zone headers in Blizzard's quest tracker.
--
-- SORT: Blizzard lists tracked quests in the order they were watched. When the option is on, the watch list is
-- rebuilt (RemoveQuestWatch + AddQuestWatch, keeping each quest's watch type) whenever the order is wrong: zones by
-- their closest quest, quests inside a zone closest first, so the closest quest/objective is at the very top. Re-checked
-- every 4 s while you move and after the game's own SortQuestWatches; out of combat only, never while the order is
-- already right, at most 4 re-orders per 10 s (so it cannot loop).
--
-- HEADERS (experimental): a zone name is drawn above the first quest block of each zone. The room for it is added to
-- the bottom of the block above (SetHeight post-hook, the technique AllObjectives RXP uses) and the header text is a
-- child of that block, so it scrolls and clips with the list. Nothing of Blizzard's is replaced.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api
local db

local HEADER_H = 18
local function isSecret(v) return issecretvalue and issecretvalue(v) or false end

local function headerTitle(questID)
	-- with Questie data on: the zone where the quest is done (Questie.lua), not the quest log's header
	local questieZone = api.questieZone and api.questieZone(questID)
	if questieZone then return questieZone end
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

local function watched()
	local list = {}
	for i = 1, C_QuestLog.GetNumQuestWatches() do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		if id then list[#list + 1] = { id = id, zone = headerTitle(id) or "", index = i } end
	end
	return list
end

---------------------------------------------------------------------------------------------------------------------
-- Zone distance: the closest zone to the player first
---------------------------------------------------------------------------------------------------------------------
-- Quest-log headers are zone (or dungeon) names. Names are matched to map IDs once from the game's own map tree
-- (C_Map.GetMapChildrenInfo of the top map, all descendants); a zone's position is the world position of its map's
-- centre (C_Map.GetWorldPosFromMapPos), a map without world coordinates (a dungeon) uses its parent zone's. The
-- player's position is C_Map.GetPlayerMapPosition on their best map (its centre when the position is not available,
-- in an instance for example). Order: the player's own zone, then the same continent by distance, then other
-- continents and unknown names; ties alphabetical.
local zoneMaps, centers = nil, {}
local function buildZoneMaps()
	zoneMaps = {}
	local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local root, guard = map, 0
	while root and guard < 10 do
		local info = C_Map.GetMapInfo(root)
		if not info or not info.parentMapID or info.parentMapID == 0 then break end
		root, guard = info.parentMapID, guard + 1
	end
	if not root then zoneMaps = nil return end
	local ok, children = pcall(C_Map.GetMapChildrenInfo, root, nil, true)
	for _, info in ipairs(ok and type(children) == "table" and children or {}) do
		local name = type(info.name) == "string" and not isSecret(info.name) and info.name:lower()
		-- prefer zones over other map types sharing the name
		if name and (not zoneMaps[name] or (Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Zone)) then
			zoneMaps[name] = info.mapID
		end
	end
end

local function worldPos(mapID, x, y, depth)
	if not mapID or (depth or 0) > 4 then return nil end
	local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
	if ok and continent and pos then
		local px, py = pos.x, pos.y
		if pos.GetXY then px, py = pos:GetXY() end
		if type(px) == "number" and type(py) == "number" and not isSecret(px) then return continent, px, py end
	end
	local info = C_Map.GetMapInfo(mapID)
	if info and info.parentMapID and info.parentMapID ~= 0 then return worldPos(info.parentMapID, 0.5, 0.5, (depth or 0) + 1) end
end

local function center(mapID)
	if centers[mapID] == nil then
		local continent, x, y = worldPos(mapID, 0.5, 0.5)
		centers[mapID] = continent and { continent, x, y } or false
	end
	return centers[mapID] or nil
end

-- Inside a dungeon, raid or scenario: its name (lower case), else nil. The game gives no map position there, so the
-- distances of quests outside cannot be compared with it; the dungeon's own quests come first instead.
local function instanceName()
	if not IsInInstance then return nil end
	local inside, kind = IsInInstance()
	if not inside or not (kind == "party" or kind == "raid" or kind == "scenario") then return nil end
	local name = GetInstanceInfo and GetInstanceInfo()
	if type(name) ~= "string" or name == "" or isSecret(name) then name = GetRealZoneText and GetRealZoneText() end
	return type(name) == "string" and name ~= "" and name:lower() or nil
end

-- "The Deadmines" and "Deadmines" are the same place
local function bareName(name) return (name:lower():gsub("^the%s+", "")) end

-- the quest log's zone header names the dungeon you are in
local isDungeonQuest -- below playerPlace's helpers
local function isInstanceZone(place, zoneName)
	if not (place and place.instance and zoneName and zoneName ~= "") then return false end
	local zone = bareName(zoneName)
	if zone == bareName(place.instance) then return true end
	return place.zone ~= nil and zone == bareName(place.zone)
end

local lastOutdoor -- the last place with a position: inside a dungeon the other zones are ordered from there
-- Questie: are this quest's objectives (its open ones; the turn-in once complete) inside the dungeon you are in?
-- Matched by the game map of Questie's area, or else by the area's name.
-- per area of Questie, whether it is the dungeon you are in: worked out once per dungeon visit, not on every sort
local areaInside, areaFor = {}, nil
function isDungeonQuest(id, place)
	local points = api.questiePoints and api.questiePoints(id)
	if not points then return false end
	local visit = tostring(place.instance) .. "#" .. tostring(place.map)
	if areaFor ~= visit then wipe(areaInside); areaFor = visit end
	local instance = bareName(place.instance)
	for _, p in ipairs(points) do
		local area = p[1]
		local inside = areaInside[area]
		if inside == nil then
			inside = (place.map ~= nil and api.questieUiMap ~= nil and api.questieUiMap(area) == place.map) or false
			if not inside then
				local name = api.questieZoneName and api.questieZoneName(area)
				inside = type(name) == "string" and bareName(name) == instance
			end
			areaInside[area] = inside
		end
		if inside then return true end
	end
	return false
end

local function playerPlace()
	local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	-- no map (inside many dungeons): no position, but the zone and the dungeon's name still order the list
	if not map then
		local zone = GetRealZoneText and GetRealZoneText() or nil
		if isSecret(zone) then zone = nil end
		local place = { name = zone and zone:lower() or nil, zone = zone, instance = instanceName() }
		if lastOutdoor then place.continent, place.x, place.y = lastOutdoor.continent, lastOutdoor.x, lastOutdoor.y end
		return place
	end
	local here = C_Map.GetMapInfo(map)
	local name = here and type(here.name) == "string" and not isSecret(here.name) and here.name:lower() or nil
	local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
	local x, y
	if ok and pos then
		x, y = pos.x, pos.y
		if pos.GetXY then x, y = pos:GetXY() end
	end
	if type(x) ~= "number" or isSecret(x) then x, y = 0.5, 0.5 end
	local continent, wx, wy = worldPos(map, x, y)
	local place = { name = name, zone = GetRealZoneText and GetRealZoneText() or nil, continent = continent, x = wx, y = wy,
		instance = instanceName(), map = map }
	if continent and not place.instance then
		lastOutdoor = place
	elseif not continent and lastOutdoor then
		place.continent, place.x, place.y = lastOutdoor.continent, lastOutdoor.x, lastOutdoor.y
	end
	return place
end

local FAR, UNKNOWN = 1e12, 2e12
local function distanceFrom(place, zoneName)
	if db and db.zoneOrder == "alpha" then return 0 end -- "Alphabetical": every zone equal, names decide
	if not zoneName or zoneName == "" then return UNKNOWN end
	local lower = zoneName:lower()
	if place and (lower == place.name or (place.zone and lower == place.zone:lower())) then return -1 end
	if not zoneMaps then buildZoneMaps() end
	local mapID = zoneMaps and zoneMaps[lower]
	local c = mapID and center(mapID)
	if not (c and place and place.continent) then return UNKNOWN end
	if c[1] ~= place.continent then return FAR end
	local dx, dy = c[2] - place.x, c[3] - place.y
	return dx * dx + dy * dy
end

-- the player's place, read at most once a second
local placeCache, placeAt
local function currentPlace()
	if not placeCache or GetTime() - (placeAt or 0) > 1 then placeCache, placeAt = playerPlace(), GetTime() end
	return placeCache
end

---------------------------------------------------------------------------------------------------------------------
-- Quest distance: the closest quest / objective to the player first
---------------------------------------------------------------------------------------------------------------------
-- Per quest, the squared world distance from the player to the nearest place it is done:
--   1. Questie on: the nearest spawn of its objectives (the turn-in once complete), Questie.lua api.questiePoints,
--      areas mapped to game maps with Questie's ZoneDB, positions with C_Map.GetWorldPosFromMapPos
--   2. the game's own C_QuestLog.GetDistanceSqToQuest (quest POI data)
--   3. C_QuestLog.GetNextWaypoint
--   4. the centre of the quest's zone (as before)
-- Another continent counts as far away (FAR + its zone distance), unknown after everything known.
local worldCache = {} -- questID -> { complete = bool, points = { {continent, x, y}, ... } }
local function questWorldPoints(id)
	local points = api.questiePoints and api.questiePoints(id)
	if not points then return nil end
	local entry = worldCache[id]
	if entry and entry.source == points then return entry.points end
	local out, mapOf = {}, {}
	for _, p in ipairs(points) do
		local area = p[1]
		if mapOf[area] == nil then mapOf[area] = api.questieUiMap and api.questieUiMap(area) or false end
		local map = mapOf[area]
		if map then
			local continent, x, y = worldPos(map, p[2] / 100, p[3] / 100)
			if continent then out[#out + 1] = { continent, x, y } end
		end
	end
	worldCache[id] = { source = points, points = out }
	return out
end

local function clientDistance(id)
	if C_QuestLog.GetDistanceSqToQuest then
		local ok, d, onContinent = pcall(C_QuestLog.GetDistanceSqToQuest, id)
		if ok and type(d) == "number" and not isSecret(d) and d >= 0 then
			if onContinent == false then return FAR + d end
			return d
		end
	end
end

local function waypointDistance(id, place)
	if not (C_QuestLog.GetNextWaypoint and place and place.continent) then return nil end
	local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, id)
	if not (ok and type(map) == "number" and type(x) == "number" and type(y) == "number") or isSecret(x) then return nil end
	local continent, wx, wy = worldPos(map, x, y)
	if not continent then return nil end
	if continent ~= place.continent then return FAR end
	local dx, dy = wx - place.x, wy - place.y
	return dx * dx + dy * dy
end

local lastSource = {}
local function questDistance(id, zone, place)
	-- in a dungeon its quests are the closest (ahead of every distance)
	if isInstanceZone(place, zone) then lastSource[id] = "instance" return -1 end
	-- a quest done in this dungeon but filed under another zone (Questie): its zone right after the dungeon's
	if place and place.instance and isDungeonQuest(id, place) then lastSource[id] = "instance (Questie)" return -0.5 end
	local points = questWorldPoints(id)
	if points and #points > 0 and place and place.continent then
		local best
		for _, p in ipairs(points) do
			if p[1] == place.continent then
				local dx, dy = p[2] - place.x, p[3] - place.y
				local d = dx * dx + dy * dy
				if not best or d < best then best = d end
			end
		end
		lastSource[id] = "questie"
		return best or (FAR + 1)
	end
	local d = clientDistance(id)
	if d then lastSource[id] = "game" return d end
	d = waypointDistance(id, place)
	if d then lastSource[id] = "waypoint" return d end
	lastSource[id] = "zone"
	local z = distanceFrom(place, zone)
	if z == -1 then return 0 end
	return z
end


-- Distances closer together than this (squared yards) count as equal, so the list does not swap two quests back and
-- forth while you walk between them; the current order then decides.
local BUCKET = 30
local function bucket(d)
	if d < 0 then return d end -- the dungeon you are in
	if d >= FAR then return d end
	return math.floor(math.sqrt(d) / BUCKET)
end

-- Sorts entries { id, zone, index } (index: the current position). "closest": zones by their closest quest, quests
-- inside a zone by distance; "alpha": zones A to Z, quests inside a zone by distance.
local function orderQuests(list, place)
	local out = {}
	for i, q in ipairs(list) do out[i] = q end
	place = place or playerPlace()
	local qd, zd = {}, {}
	for _, q in ipairs(out) do
		local d = bucket(questDistance(q.id, q.zone, place))
		qd[q.id] = d
		local key = q.zone or ""
		if zd[key] == nil or d < zd[key] then zd[key] = d end
	end
	local alpha = db and db.zoneOrder == "alpha"
	table.sort(out, function(a, b)
		local za, zb = a.zone or "", b.zone or ""
		if za ~= zb then
			if za == "" or zb == "" then return zb == "" end -- quests without a zone last
			if not alpha and zd[za] ~= zd[zb] then return zd[za] < zd[zb] end
			return za:lower() < zb:lower()
		end
		if qd[a.id] ~= qd[b.id] then return qd[a.id] < qd[b.id] end
		return a.index < b.index
	end)
	return out
end
api.orderQuests = function(list) return orderQuests(list) end

local function sorted(list) return orderQuests(list) end

local busy = false
local reversedAdd = false -- this client puts a newly watched quest first instead of last
local recent = {}         -- times of our recent reorders
local function sameOrder(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i].id ~= b[i].id then return false end end
	return true
end
local function rewatch(list, want, reverse)
	for _, q in ipairs(list) do C_QuestLog.RemoveQuestWatch(q.id) end
	local first, last, step = 1, #want, 1
	if reverse then first, last, step = #want, 1, -1 end
	for i = first, last, step do
		local q = want[i]
		if q.type ~= nil then C_QuestLog.AddQuestWatch(q.id, q.type) else C_QuestLog.AddQuestWatch(q.id) end
	end
end
local function sortWatches(force)
	if not db or not db.zoneSort or not db.enabled or InCombatLockdown() or busy then return end
	local now = GetTime()
	local keep = {}
	for _, t in ipairs(recent) do if now - t < 10 then keep[#keep + 1] = t end end
	recent = keep
	if #recent >= 4 then return end -- something keeps re-ordering the list: do not fight it more than this
	local list = watched()
	local want = sorted(list)
	if sameOrder(list, want) then return end
	recent[#recent + 1] = now
	busy = true
	for _, q in ipairs(want) do q.type = C_QuestLog.GetQuestWatchType(q.id) end
	local ok, err = pcall(function()
		rewatch(list, want, reversedAdd)
		local got = watched()
		if not sameOrder(got, want) then
			-- the client added in the other direction: learn it and redo once
			local reversed = #got == #want
			for i = 1, #got do if got[i].id ~= want[#want - i + 1].id then reversed = false break end end
			if reversed then
				reversedAdd = not reversedAdd
				rewatch(got, want, reversedAdd)
			end
		end
	end)
	busy = false
	if not ok then geterrorhandler()(err) end
end

---------------------------------------------------------------------------------------------------------------------
-- Headers
---------------------------------------------------------------------------------------------------------------------
local hooked = {}
local labels = setmetatable({}, { __mode = "k" }) -- block -> FontString
local extra = setmetatable({}, { __mode = "k" })  -- block -> extra height currently wanted
local applying = false

local function hookBlock(block)
	if hooked[block] then return end
	hooked[block] = true
	hooksecurefunc(block, "SetHeight", function(self, h)
		if applying or not extra[self] or extra[self] <= 0 or type(h) ~= "number" then return end
		applying = true
		pcall(self.SetHeight, self, h + extra[self])
		applying = false
	end)
end

local function headerHeight() return math.ceil(HEADER_H * (db.zoneHeaderScale or 1)) end

local function styleLabel(label)
	local color = db.zoneHeaderColor or { 0.2, 0.85, 0.55 }
	label:SetTextColor(color[1], color[2], color[3], tonumber(color[4]) or 1)
	local font, size, flags = GameFontNormalSmall:GetFont()
	font = api.fontPath and api.fontPath() or font
	if font and size then label:SetFont(font, size * (db.zoneHeaderScale or 1), db.zoneHeaderOutline and "OUTLINE" or flags) end
end

-- The left edge of the zone headers shown (UIParent units), for the background (Core.lua)
function api.zoneLabelsLeft()
	local left
	local ui = UIParent:GetEffectiveScale()
	for _, label in pairs(labels) do
		if label:IsVisible() then
			local l = label:GetLeft()
			if l then
				l = l * label:GetEffectiveScale() / ui
				if not left or l < left then left = l end
			end
		end
	end
	return left
end

-- for MoreQuests.lua: the same zone header look and room
api.styleZoneLabel = function(label) styleLabel(label) end
api.zoneHeaderHeight = function() return headerHeight() end

local function getLabel(block)
	local label = labels[block]
	if not label then
		label = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetJustifyH("LEFT")
		labels[block] = label
	end
	styleLabel(label)
	return label
end

local function questBlocks()
	local blocks = {}
	local module = _G.QuestObjectiveTracker
	if not module or type(module.usedBlocks) ~= "table" then return blocks end
	for _, byId in pairs(module.usedBlocks) do
		if type(byId) == "table" then
			for id, block in pairs(byId) do
				if type(block) == "table" and block.IsShown and block:IsShown() then blocks[tonumber(id) or id] = block end
			end
		end
	end
	return blocks
end

-- The first zone has no quest above it to make room in, so the gap between the "Quests" header and the first quest
-- is widened instead (the module's own fromHeaderOffsetY field; offsets are negative going down).
local baseHeaderOffset -- the module's original value, false if the field does not exist
local firstHeaderShown = false
local function applyFirstGap()
	local module = _G.QuestObjectiveTracker
	if not module then return false end
	if baseHeaderOffset == nil then
		baseHeaderOffset = type(module.fromHeaderOffsetY) == "number" and module.fromHeaderOffsetY or false
	end
	if baseHeaderOffset == false then return false end
	local want = baseHeaderOffset
	if firstHeaderShown then want = baseHeaderOffset - headerHeight() - (db.zoneHeaderPadY or 6) end
	if module.fromHeaderOffsetY ~= want then module.fromHeaderOffsetY = want; return true end
	return false
end

local function decorate()
	if not db or InCombatLockdown() then return false end
	firstHeaderShown = false
	local blocks = questBlocks()
	local want, changed = {}, false -- block -> {extra, zone} ; extra is set on the block above a new zone
	if db.zoneSort and db.enabled then
		local prevBlock, prevZone
		local shown = {}
		for id, block in pairs(blocks) do
			local top = block:GetTop()
			if top and type(id) == "number" then shown[#shown + 1] = { id = id, top = top, zone = headerTitle(id) or "" } end
		end
		table.sort(shown, function(a, b) return a.top > b.top end) -- the order Blizzard actually displays
		for _, q in ipairs(shown) do
			local block = blocks[q.id]
			if block then
				hookBlock(block)
				if q.zone ~= prevZone and q.zone ~= "" then
					want[block] = want[block] or {}
					want[block].header = q.zone
					if not prevBlock then firstHeaderShown = true end
					if prevBlock then want[prevBlock] = want[prevBlock] or {}; want[prevBlock].extra = headerHeight() end
				end
				prevBlock, prevZone = block, q.zone
			end
		end
		api.lastTrackedZone = prevZone -- the zone of the last tracked quest shown (MoreQuests continues from it)
	else
		api.lastTrackedZone = nil
	end
	for block in pairs(hooked) do
		local w = want[block] or {}
		local e = w.extra or 0
		if (extra[block] or 0) ~= e then extra[block] = e; changed = true end
		local label = labels[block]
		if w.header then
			label = getLabel(block)
			label:ClearAllPoints()
			-- the block itself sits questTitleX further right (Quest titles horizontal position): taken back off here
			label:SetPoint("BOTTOMLEFT", block, "TOPLEFT", (db.zoneHeaderX or 4) - (tonumber(db.questTitleX) or 0),
				2 + (tonumber(db.zoneHeaderY) or 0))
			label:SetText(w.header)
			label:Show()
		elseif label then
			label:Hide()
		end
	end
	if applyFirstGap() then changed = true end
	if api.applyBackground then api.applyBackground() end -- the background starts at the headers
	return changed
end

local function relayout()
	local module = _G.QuestObjectiveTracker
	if module and module.MarkDirty then pcall(securecallfunction, module.MarkDirty, module) end
	if ObjectiveTrackerFrame and ObjectiveTrackerFrame.MarkDirty then
		pcall(securecallfunction, ObjectiveTrackerFrame.MarkDirty, ObjectiveTrackerFrame)
	end
end

local timer
local sortRequested = false
local function schedule(delay, doSort)
	if doSort then sortRequested = true end
	if timer then return end
	timer = true
	C_Timer.After(delay or 0.3, function()
		timer = nil
		xpcall(function()
			if sortRequested then sortRequested = false; sortWatches(true) end
			if decorate() then relayout() end
		end, geterrorhandler())
	end)
end

function api.setZoneSort(enabled)
	db.zoneSort = enabled and true or false
	if db.zoneSort and db.trackMode and api.setTrackMode then api.setTrackMode(nil) end
	schedule(0, true)
	if api.refreshConfig then api.refreshConfig() end
end

function api.applyZoneHeaders()
	schedule(0, false)
	if api.rebuildMoreQuests then api.rebuildMoreQuests() end -- its zone headers take the same look
end

function api.sortNow() schedule(0, true) end

-- "Sort zones": "closest" (closest zone to you first, the default) or "alpha" (A to Z)
function api.setZoneOrder(order)
	db.zoneOrder = order == "alpha" and "alpha" or "closest"
	schedule(0, true)
	if api.rebuildMoreQuests then api.rebuildMoreQuests() end
end

function api.zoneDebug(say)
	local zones = {}
	for _, q in ipairs(watched()) do zones[#zones + 1] = (q.zone ~= "" and q.zone or "?") end
	say(("sort by zone=%s, tracked quest zones in order: %s"):format(tostring(db.zoneSort), table.concat(zones, ", ")))
	local place = playerPlace()
	say(("you are in %s (continent %s); zone maps known: %s"):format(tostring(place and (place.zone or place.name)),
		tostring(place and place.continent), tostring(zoneMaps and next(zoneMaps) ~= nil)))
	local place2 = currentPlace()
	for i, q in ipairs(orderQuests(watched(), place2)) do
		if i > 12 then break end
		local d = questDistance(q.id, q.zone, place2)
		local yards = d >= FAR and "far" or ("%d yd"):format(math.floor(math.sqrt(d)))
		say(("  %d. %s [%s] %s (%s)"):format(i, tostring(C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q.id) or q.id),
			q.zone ~= "" and q.zone or "?", yards, tostring(lastSource[q.id])))
	end
	say(("watch insert reversed: %s"):format(tostring(reversedAdd)))
	local module = _G.QuestObjectiveTracker
	say(("first zone gap: fromHeaderOffsetY=%s (original %s)"):format(tostring(module and module.fromHeaderOffsetY), tostring(baseHeaderOffset)))
end

ns.onLogin[#ns.onLogin + 1] = function()
	db = ns.db
	local frame = CreateFrame("Frame")
	-- ZONE_CHANGED_NEW_AREA: the closest zones change when you travel
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_REGEN_ENABLED",
		"ZONE_CHANGED_NEW_AREA" }) do
		pcall(frame.RegisterEvent, frame, e)
	end
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" or event == "ZONE_CHANGED_NEW_AREA" then wipe(worldCache) end
		-- entering or leaving a dungeon (a loading screen) or a new zone: read the player's place again
		if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then placeCache = nil end
		schedule(1, true)
	end)
	-- the game's own proximity sort (C_QuestLog.SortQuestWatches, run by Blizzard's tracker) would undo ours: put
	-- ours back right after it
	if C_QuestLog.SortQuestWatches then
		hooksecurefunc(C_QuestLog, "SortQuestWatches", function() if not busy then schedule(0.2, true) end end)
	end
	-- you move: re-check every few seconds (only re-orders when a different quest has become closer)
	-- Only after you moved 20 yards or more since the last check (or every 30 s at the latest), so standing still
	-- costs nothing; quest events re-sort on their own (above).
	local lastPlace, idle = nil, 0
	if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(4, function()
		if not (db and db.zoneSort and db.enabled) or InCombatLockdown() then return end
		local here = playerPlace()
		idle = idle + 1
		if lastPlace and here and here.continent == lastPlace.continent and here.x and lastPlace.x and idle < 8 then
			local dx, dy = here.x - lastPlace.x, here.y - lastPlace.y
			if dx * dx + dy * dy < 400 then return end
		end
		lastPlace, idle = here, 0
		schedule(0, true)
	end) end
	if ObjectiveTrackerContainerMixin then
		hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", function() schedule(0.1, false) end)
	end
end
