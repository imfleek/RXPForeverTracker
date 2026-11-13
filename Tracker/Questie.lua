-- Questie integration: only while Questie is installed, enabled and ready, and its option is on.
--
-- Reads Questie's database (the QuestieDB addon's global LibQuestieDB, Quest/Npc/Object/Item .Get(id, field): the
-- composed view with Questie's corrections; field names from QuestieDB/Types) for:
--   tooltips  quest giver and turn-in (name, zone, coordinates), where each objective is found, the quest's chain
--   sorting   the zone where the quest is done: its objectives, the turn-in NPC once complete, else Questie's zone
-- Every lookup is cached per quest and wrapped, so missing data or a changed field leaves the line out.
--
-- Future-proof (no quest, NPC, item or zone list of our own): everything is read live from whatever Questie's database
-- holds, so quests, zones and NPCs added in a Questie update (a new zone's quests, say) show up without a change here.
--   database  LibQuestieDB (the QuestieDB addon), else Questie's own QuestieDB module (Query*Single)
--   zones     the game's area names (C_Map.GetAreaInfo), else Questie's own zone names (TrackerUtils)
--   ready     Questie.API.isReady, else (an older or newer Questie without that API) as soon as its data answers
--   caches    cleared when Questie reports ready and on Questie data reloads; nothing is remembered from before then
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api

local MAX_ZONES, MAX_CHAIN = 3, 40

local function module(name)
	local loader = _G.QuestieLoader
	if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return nil end
	local ok, m = pcall(loader.ImportModule, loader, name)
	return ok and type(m) == "table" and m or nil
end

-- the database lookup for "Quest", "Npc", "Object" or "Item": LibQuestieDB, else Questie's QuestieDB module
local QUERY = { Quest = "QueryQuestSingle", Npc = "QueryNPCSingle", Object = "QueryObjectSingle", Item = "QueryItemSingle" }
local getters = {}
local function getter(kind)
	local fn = getters[kind]
	if fn then return fn end
	local lib = _G.LibQuestieDB
	if type(lib) == "table" and type(lib[kind]) == "table" and type(lib[kind].Get) == "function" then
		fn = lib[kind].Get
	else
		local qdb = module("QuestieDB")
		fn = qdb and type(qdb[QUERY[kind]]) == "function" and qdb[QUERY[kind]] or nil
	end
	getters[kind] = fn -- found once; while Questie is still loading nothing is remembered (see ready)
	return fn
end

local function questieAddOn() return C_AddOns.IsAddOnLoaded("Questie") end

local readySeen = false
local function ready()
	if readySeen then return true end
	if not questieAddOn() then return false end
	local questie = _G.Questie
	local apiTable = type(questie) == "table" and questie.API
	if type(apiTable) == "table" and apiTable.isReady ~= nil then
		if not apiTable.isReady then return false end
	elseif not getter("Quest") then
		return false
	end
	if not getter("Quest") then wipe(getters) return false end
	readySeen = true
	return true
end

-- Questie is installed and enabled (its options are listed only then)
function api.questieLoaded()
	return questieAddOn() and (type(_G.LibQuestieDB) == "table" or type(_G.QuestieLoader) == "table")
end

-- Questie data is used: installed, ready, and the option on
function api.questieOn()
	return ns.db and ns.db.questie ~= false and ready()
end

local function get(kind, id, field)
	if not id then return nil end
	local fn = getter(kind)
	if not fn then return nil end
	local ok, value = pcall(fn, id, field)
	return ok and value or nil
end

local zoneNames = {}
local function zoneName(areaID)
	if type(areaID) ~= "number" or areaID <= 0 then return nil end
	local cached = zoneNames[areaID]
	if cached ~= nil then return cached or nil end
	local name
	if C_Map and C_Map.GetAreaInfo then
		local ok, n = pcall(C_Map.GetAreaInfo, areaID)
		if ok and type(n) == "string" and n ~= "" then name = n end
	end
	if not name then -- an area the game does not name (yet): Questie's own name for it
		local utils = module("TrackerUtils")
		if utils and type(utils.GetZoneNameByID) == "function" then
			local ok, n = pcall(utils.GetZoneNameByID, utils, areaID)
			if ok and type(n) == "string" and n ~= "" then name = n end
		end
	end
	zoneNames[areaID] = name or false
	return name
end

-- The zone with the most spawns, its first coordinate
local function mainSpawn(spawns)
	if type(spawns) ~= "table" then return nil end
	local bestZone, bestList
	for zone, list in pairs(spawns) do
		if type(list) == "table" and (not bestList or #list > #bestList) then bestZone, bestList = zone, list end
	end
	local point = bestList and bestList[1]
	return bestZone, type(point) == "table" and point[1] or nil, type(point) == "table" and point[2] or nil
end

local function zonesOf(spawns, into, seen)
	for zone in pairs(type(spawns) == "table" and spawns or {}) do
		local name = zoneName(zone)
		if name and not seen[name] then seen[name] = true; into[#into + 1] = name end
	end
end

-- "Name (Zone 45.2, 60.1)" for an NPC or object
local function where(kind, id)
	local name = get(kind, id, "name")
	if not name then return nil end
	local zone, x, y = mainSpawn(get(kind, id, "spawns"))
	zone = zone or get(kind, id, "zoneID")
	local zname = zoneName(zone)
	if zname and x and y then return ("%s (%s %.1f, %.1f)"):format(name, zname, x, y) end
	if zname then return ("%s (%s)"):format(name, zname) end
	return name
end

local function firstOf(list) return type(list) == "table" and list[1] or nil end

local function starterText(id)
	local by = get("Quest", id, "startedBy")
	if type(by) ~= "table" then return nil end
	local npc, object, item = firstOf(by[1]), firstOf(by[2]), firstOf(by[3])
	if npc then return where("Npc", npc) end
	if object then return where("Object", object) end
	if item then
		local name = get("Item", item, "name")
		return name and ("item: " .. name) or nil
	end
end

local function finisherText(id)
	local by = get("Quest", id, "finishedBy")
	if type(by) ~= "table" then return nil end
	local npc, object = firstOf(by[1]), firstOf(by[2])
	if npc then return where("Npc", npc) end
	if object then return where("Object", object) end
end

-- Where each objective is found: creatures and objects by their spawn zones, items by what drops them.
-- The entries of one kind of a quest's Questie objectives (1 creatures, 2 objects, 3 items, 5 kill credit): only
-- table entries, so an unexpected shape (reputation is a single {faction, value} pair) is skipped, not an error.
local function objectiveEntries(objectives, i)
	local out = {}
	local kind = type(objectives) == "table" and objectives[i]
	for _, o in ipairs(type(kind) == "table" and kind or {}) do
		if type(o) == "table" then out[#out + 1] = o end
	end
	return out
end
local function firstId(objectives, i)
	local first = objectiveEntries(objectives, i)[1]
	return first and first[1]
end

local function objectiveLines(id)
	local objectives = get("Quest", id, "objectives")
	if type(objectives) ~= "table" then return {} end
	local lines = {}
	local function add(label, zones)
		if label and #zones > 0 then
			local shown = {}
			for i = 1, math.min(#zones, MAX_ZONES) do shown[i] = zones[i] end
			lines[#lines + 1] = label .. ": " .. table.concat(shown, ", ") .. (#zones > MAX_ZONES and ", ..." or "")
		end
	end
	for _, o in ipairs(objectiveEntries(objectives, 1)) do
		local zones, seen = {}, {}
		zonesOf(get("Npc", o[1], "spawns"), zones, seen)
		add(o[2] or get("Npc", o[1], "name"), zones)
	end
	for _, o in ipairs(objectiveEntries(objectives, 2)) do
		local zones, seen = {}, {}
		zonesOf(get("Object", o[1], "spawns"), zones, seen)
		add(o[2] or get("Object", o[1], "name"), zones)
	end
	for _, o in ipairs(objectiveEntries(objectives, 3)) do
		local zones, seen = {}, {}
		for _, npc in ipairs(get("Item", o[1], "npcDrops") or {}) do
			zonesOf(get("Npc", npc, "spawns"), zones, seen)
			if #zones > MAX_ZONES then break end
		end
		for _, object in ipairs(get("Item", o[1], "objectDrops") or {}) do
			zonesOf(get("Object", object, "spawns"), zones, seen)
			if #zones > MAX_ZONES then break end
		end
		add(o[2] or get("Item", o[1], "name"), zones)
	end
	return lines
end

local function previousOf(id)
	return firstOf(get("Quest", id, "preQuestSingle")) or firstOf(get("Quest", id, "preQuestGroup"))
end

local function questName(id)
	return (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)) or get("Quest", id, "name") or ("#" .. id)
end

-- The whole chain in order: back through the prerequisites, this quest, forward through nextQuestInChain
-- (cycle-safe, MAX_CHAIN each way). Returns the list and this quest's position, or nil when it is not in a chain.
local function chainList(id)
	local back, seen, cursor = {}, { [id] = true }, id
	while #back < MAX_CHAIN do
		local prev = previousOf(cursor)
		if not prev or seen[prev] then break end
		seen[prev] = true
		back[#back + 1], cursor = prev, prev
	end
	local list = {}
	for i = #back, 1, -1 do list[#list + 1] = back[i] end
	list[#list + 1] = id
	local position = #list
	cursor = id
	while #list - position < MAX_CHAIN do
		local nxt = get("Quest", cursor, "nextQuestInChain")
		if type(nxt) ~= "number" or nxt == 0 or seen[nxt] then break end
		seen[nxt] = true
		list[#list + 1], cursor = nxt, nxt
	end
	if #list == 1 then return nil end
	return list, position
end

-- Quest -> reward items, from Questie's item data (Item.questRewards is item -> quests): built once, a slice of items
-- per frame (a single pass over every item would risk the client's script time limit). nil while building.
local rewardIndex, building
local ITEMS_PER_FRAME = 1500
local function buildRewardIndex()
	if rewardIndex or building then return end
	-- every item Questie knows: LibQuestieDB's list, else the QuestieDB module's item pointers (keys)
	local ok, ids
	local lib = _G.LibQuestieDB
	if type(lib) == "table" and type(lib.Item) == "table" and type(lib.Item.GetAllIds) == "function" then
		ok, ids = pcall(lib.Item.GetAllIds)
	else
		local qdb = module("QuestieDB")
		if qdb and type(qdb.ItemPointers) == "table" then
			ids = {}
			for id in pairs(qdb.ItemPointers) do ids[#ids + 1] = id end
			ok = true
		end
	end
	if not ok or type(ids) ~= "table" then rewardIndex = {} return end
	building = true
	local index, i = {}, 1
	local ticker
	ticker = C_Timer.NewTicker(0, function()
		local stop = math.min(i + ITEMS_PER_FRAME - 1, #ids)
		for n = i, stop do
			local item = ids[n]
			local quests = get("Item", item, "questRewards")
			if type(quests) == "table" then
				for _, quest in ipairs(quests) do
					index[quest] = index[quest] or {}
					table.insert(index[quest], item)
				end
			end
		end
		i = stop + 1
		if i > #ids then
			ticker:Cancel()
			rewardIndex, building = index, false
			if api.refreshQuestTooltip then api.refreshQuestTooltip() end
			if api.refreshPrereqs then api.refreshPrereqs() end -- the journal's reward items
		end
	end)
end

local function rewardItems(quest)
	if not rewardIndex then buildRewardIndex() return nil end
	return rewardIndex[quest] or {}
end

local function itemText(item)
	local name, link = GetItemInfo and GetItemInfo(item)
	return link or name or get("Item", item, "name") or ("item " .. item)
end

-- Experience as Questie computes it (its QuestXP module: level-adjusted, 0 at max level), gold from the game's
-- quest data (0 when the game has not seen that quest yet).
local function questXP(quest)
	local questXPModule = module("QuestXP")
	if not (questXPModule and questXPModule.GetQuestLogRewardXP and questXPModule.db) then return 0 end
	local ok, xp = pcall(questXPModule.GetQuestLogRewardXP, questXPModule, quest)
	return ok and tonumber(xp) or 0
end
local function questMoney(quest)
	if not GetQuestLogRewardMoney then return 0 end
	local ok, money = pcall(GetQuestLogRewardMoney, quest)
	return ok and tonumber(money) or 0
end

local function isDone(quest)
	if C_QuestLog.IsQuestFlaggedCompleted then
		local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, quest)
		return ok and done
	end
end

-- Ctrl held, or the tooltip measuring its Ctrl width (Extras.lua api.setChainCtrl)
local forceCtrl = false
function api.setChainCtrl(on) forceCtrl = on and true or false end
local function ctrlDown() return forceCtrl or IsControlKeyDown() end
-- the tooltip may change with Ctrl (a chain to show)
function api.chainTooltip(id)
	if not (id and api.questieOn()) or ns.db.questieChain == false then return false end
	local list = chainList(id)
	return list ~= nil
end

-- Follow-up, chain (whole chain while Ctrl is held), the chain's final reward and totals.
local function addChainLines(tip, id)
	local db = ns.db
	if db.questieChain == false then return end
	local list, position = chainList(id)
	local nxt = get("Quest", id, "nextQuestInChain")
	if type(nxt) ~= "number" or nxt == 0 then nxt = nil end
	if not (list or nxt) then return end
	tip:AddLine(" ")
	if nxt then tip:AddLine("Follow-up: |cffffffff" .. questName(nxt) .. "|r", 0.6, 0.8, 1, true) end
	if list then
		tip:AddLine(("Chain: quest %d of %d"):format(position, #list), 0.6, 0.8, 1)
		if ctrlDown() then
			for i, quest in ipairs(list) do
				local level = get("Quest", quest, "questLevel")
				local label = ("%d. %s%s"):format(i, questName(quest), level and (" [" .. level .. "]") or "")
				if i == position then tip:AddLine("> " .. label, 1, 0.82, 0, true)
				elseif isDone(quest) then tip:AddLine("  " .. label, 0.5, 0.5, 0.5, true)
				else tip:AddLine("  " .. label, 1, 1, 1, true) end
			end
		else
			tip:AddLine(db.questieChainReward and "Hold Ctrl to see the whole chain, its final reward and total"
				or "Hold Ctrl to see the whole chain", 0.5, 0.5, 0.5)
			if db.questieChainReward then buildRewardIndex() end -- ready by the time Ctrl is pressed
		end
	end
	-- the final reward and the chain total only while Ctrl is held (with the whole chain)
	if db.questieChainReward and list and ctrlDown() then
		local final = list[#list]
		tip:AddLine("Chain ends with: |cffffffff" .. questName(final) .. "|r", 0.6, 0.8, 1, true)
		local items = rewardItems(final)
		if items == nil then
			tip:AddLine("  reward items: loading...", 0.5, 0.5, 0.5)
		else
			for _, item in ipairs(items) do tip:AddLine("  " .. itemText(item), 1, 1, 1, true) end
		end
		local finalMoney = questMoney(final)
		if finalMoney > 0 and api.tipGold then tip:AddLine("  " .. api.tipGold(finalMoney), 1, 1, 1) end
		local xp, money = 0, 0
		for i = position, #list do
			xp = xp + questXP(list[i])
			money = money + questMoney(list[i])
		end
		local parts = {}
		if xp > 0 then parts[#parts + 1] = ("|cffb087ff%d xp|r"):format(xp) end
		if money > 0 and api.tipGold then parts[#parts + 1] = api.tipGold(money) end
		if #parts > 0 then
			tip:AddLine(("Chain total (quests %d-%d): "):format(position, #list) .. table.concat(parts, "  "), 0.6, 0.8, 1, true)
		end
	end
end


-- Tooltip lines (Extras.lua questTooltip calls this after the objectives).
function api.addQuestieLines(tip, id)
	if not (id and api.questieOn()) then return end
	local giver, turnIn = starterText(id), finisherText(id)
	local objectives = objectiveLines(id)
	if giver or turnIn or #objectives > 0 then
		tip:AddLine(" ")
		tip:AddLine("Questie", 1, 0.82, 0)
		if giver then tip:AddLine("Quest giver: |cffffffff" .. giver .. "|r", 0.8, 0.8, 0.8, true) end
		if turnIn then tip:AddLine("Turn in: |cffffffff" .. turnIn .. "|r", 0.8, 0.8, 0.8, true) end
		if #objectives > 0 then
			tip:AddLine("Objectives found in:", 0.8, 0.8, 0.8)
			for _, line in ipairs(objectives) do tip:AddLine("  " .. line, 1, 1, 1, true) end
		end
	end
	addChainLines(tip, id)
end

-- Raid attunement quests: Questie has no attunement flag, so the attunement chains are found from their final
-- quests (IDs as tagged in Questie's Database/Corrections/questTagInfoCorrections.lua, except the Naxxramas ones):
-- every quest that leads to one (back through preQuestSingle/preQuestGroup) or continues into one (forward through
-- nextQuestInChain) belongs to that attunement; a quest named "...Attunement..." does too.
local ATTUNEMENT_FINALS = {
	[6502] = true, [6602] = true,                   -- Onyxia: Drakefire Amulet / Blood of the Black Dragon Champion
	[7848] = true,                                  -- Molten Core: Attunement to the Core
	[7761] = true,                                  -- Blackwing Lair: Blackhand's Command
	[9121] = true, [9122] = true, [9123] = true,    -- Naxxramas: The Dread Citadel (not in Questie's tag file)
	[9836] = true,                                  -- Karazhan: The Master's Touch
	[10901] = true, [13431] = true,                 -- Serpentshrine Cavern: The Cudgel of Kar'desh
	[10888] = true, [13430] = true,                 -- Tempest Keep: Trial of the Naaru: Magtheridon
	[10445] = true, [13432] = true,                 -- Mount Hyjal: The Vials of Eternity
	[11052] = true,                                 -- Tempest Keep (Questie's "SSC + TK attunements")
}
local attunementSet -- the finals and every quest leading to them (built once, when first needed)
local function buildAttunementSet()
	attunementSet = {}
	local queue = {}
	for id in pairs(ATTUNEMENT_FINALS) do attunementSet[id] = true; queue[#queue + 1] = id end
	local steps = 0
	while #queue > 0 and steps < 2000 do
		steps = steps + 1
		local id = table.remove(queue)
		for _, field in ipairs({ "preQuestSingle", "preQuestGroup" }) do
			for _, prev in ipairs(type(get("Quest", id, field)) == "table" and get("Quest", id, field) or {}) do
				if type(prev) == "number" and not attunementSet[prev] then
					attunementSet[prev] = true
					queue[#queue + 1] = prev
				end
			end
		end
	end
end

-- Raids whose final quest is best known by name (English names; compared while walking a chain, so no name index of
-- the whole database is built).
local ATTUNEMENT_NAMES = { ["The Master's Key"] = true, ["The Dread Citadel - Naxxramas"] = true, ["The Vials of Eternity"] = true }
local function attunementName(quest)
	local name = get("Quest", quest, "name")
	return type(name) == "string" and (ATTUNEMENT_NAMES[name] or name:find("Attunement", 1, true)) and true or false
end
-- A quest counts when it is in that set, or it or a quest its chain leads to (nextQuestInChain and childQuests, at
-- most MAX_VISIT quests) is in the set or has an attunement name.
local MAX_VISIT = 300
local attuneCache = {}
function api.isAttunement(id)
	if not (id and api.questieOn()) then return false end
	if attuneCache[id] ~= nil then return attuneCache[id] end
	if not attunementSet then buildAttunementSet() end
	local found = attunementSet[id] or attunementName(id)
	local seen, queue, head = { [id] = true }, { id }, 1
	while not found and head <= #queue and #queue <= MAX_VISIT do
		local quest = queue[head]
		head = head + 1
		local nxt = get("Quest", quest, "nextQuestInChain")
		if type(nxt) == "number" and nxt ~= 0 and not seen[nxt] then
			if attunementSet[nxt] or attunementName(nxt) then found = true end
			seen[nxt] = true
			queue[#queue + 1] = nxt
		end
		local children = get("Quest", quest, "childQuests")
		for _, child in ipairs(type(children) == "table" and children or {}) do
			if attunementSet[child] or attunementName(child) then found = true end
			if not seen[child] then seen[child] = true; queue[#queue + 1] = child end
		end
	end
	attuneCache[id] = found
	return found
end

-- The zone where a quest is done, for sorting and zone headers: once complete the turn-in's zone; otherwise its
-- objectives' (first creature, object, then item source); else Questie's quest zone.
local zoneCache, zoneCacheComplete = {}, {}
local function computeZone(id, complete)
	if complete then
		local by = get("Quest", id, "finishedBy")
		local npc = type(by) == "table" and firstOf(by[1])
		local object = type(by) == "table" and firstOf(by[2])
		local zone = npc and (mainSpawn(get("Npc", npc, "spawns")) or get("Npc", npc, "zoneID"))
			or object and (mainSpawn(get("Object", object, "spawns")) or get("Object", object, "zoneID"))
		local name = zoneName(zone)
		if name then return name end
	else
		local objectives = get("Quest", id, "objectives")
		if type(objectives) == "table" then
			local npc = firstId(objectives, 1)
			local object = firstId(objectives, 2)
			local item = firstId(objectives, 3)
			local zone
			if npc then zone = mainSpawn(get("Npc", npc, "spawns")) or get("Npc", npc, "zoneID") end
			if not zone and object then zone = mainSpawn(get("Object", object, "spawns")) or get("Object", object, "zoneID") end
			if not zone and item then
				local dropper = firstOf(get("Item", item, "npcDrops"))
				if dropper then zone = mainSpawn(get("Npc", dropper, "spawns")) or get("Npc", dropper, "zoneID") end
			end
			local name = zoneName(zone)
			if name then return name end
		end
	end
	return zoneName(get("Quest", id, "zoneOrSort"))
end

function api.questieZone(id)
	if not (id and api.questieOn()) then return nil end
	local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) and true or false
	if zoneCache[id] == nil or zoneCacheComplete[id] ~= complete then
		zoneCache[id] = computeZone(id, complete) or false
		zoneCacheComplete[id] = complete
	end
	return zoneCache[id] or nil
end

-- Where a quest is done, as map points for the closest-quest sort (ZoneSort.lua): {areaID, x, y} with Questie's 0-100
-- coordinates. Incomplete: every spawn of its objectives (creatures, objects, the creatures/objects that drop its
-- items); none of those, or complete: its turn-in NPC/object. Capped, cached per quest and completion state.
local MAX_POINTS = 80
local pointCache, pointComplete = {}, {}
local function addSpawns(out, spawns)
	if type(spawns) ~= "table" then return end
	for area, list in pairs(spawns) do
		if type(area) == "number" and type(list) == "table" then
			for _, point in ipairs(list) do
				if #out >= MAX_POINTS then return end
				if type(point) == "table" and type(point[1]) == "number" and type(point[2]) == "number"
					and point[1] >= 0 and point[2] >= 0 then
					out[#out + 1] = { area, point[1], point[2] }
				end
			end
		end
	end
end
local function addThing(out, kind, id)
	if id then addSpawns(out, get(kind, id, "spawns")) end
end
local function computePoints(id, complete)
	local out = {}
	if not complete then
		local objectives = get("Quest", id, "objectives")
		if type(objectives) == "table" then
			for _, entry in ipairs(type(objectives[1]) == "table" and objectives[1] or {}) do
				addThing(out, "Npc", type(entry) == "table" and entry[1] or nil)
			end
			for _, entry in ipairs(type(objectives[2]) == "table" and objectives[2] or {}) do
				addThing(out, "Object", type(entry) == "table" and entry[1] or nil)
			end
			for _, entry in ipairs(type(objectives[3]) == "table" and objectives[3] or {}) do
				local item = type(entry) == "table" and entry[1] or nil
				if item then
					for _, npc in ipairs(type(get("Item", item, "npcDrops")) == "table" and get("Item", item, "npcDrops") or {}) do
						addThing(out, "Npc", npc)
					end
					for _, object in ipairs(type(get("Item", item, "objectDrops")) == "table" and get("Item", item, "objectDrops") or {}) do
						addThing(out, "Object", object)
					end
				end
			end
			-- kill credit objectives: {{npcIds...}, rootNpc, text}
			for _, entry in ipairs(type(objectives[5]) == "table" and objectives[5] or {}) do
				local ids = type(entry) == "table" and entry[1]
				for _, npc in ipairs(type(ids) == "table" and ids or {}) do addThing(out, "Npc", npc) end
			end
		end
	end
	if #out == 0 then
		local by = get("Quest", id, "finishedBy")
		for _, npc in ipairs(type(by) == "table" and type(by[1]) == "table" and by[1] or {}) do addThing(out, "Npc", npc) end
		for _, object in ipairs(type(by) == "table" and type(by[2]) == "table" and by[2] or {}) do addThing(out, "Object", object) end
	end
	return out
end

function api.questiePoints(id)
	if not (id and api.questieOn()) then return nil end
	local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) and true or false
	if pointCache[id] == nil or pointComplete[id] ~= complete then
		local ok, points = pcall(computePoints, id, complete)
		pointCache[id] = ok and points or {}
		pointComplete[id] = complete
	end
	return pointCache[id]
end

-- the name of one of Questie's areas (the game's name for it, else Questie's)
function api.questieZoneName(areaID) return zoneName(areaID) end

-- Questie's map of its area IDs to the game's map IDs
function api.questieUiMap(areaID)
	local zoneDB = module("ZoneDB")
	if not (zoneDB and zoneDB.GetUiMapIdByAreaId) then return nil end
	local ok2, map = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, areaID)
	return ok2 and type(map) == "number" and map or nil
end

---------------------------------------------------------------------------------------------------------------------
-- Missing prerequisites (the Prerequisite Journal, Prereqs.lua). All from Questie's quest data: preQuestSingle (any
-- one of them must be done) and preQuestGroup (every one), startedBy/finishedBy for where to accept and turn in,
-- objectives for what to do; nothing of our own.
---------------------------------------------------------------------------------------------------------------------
local MAX_PREREQ_DEPTH, MAX_PREREQ_QUESTS = 12, 30

-- name, game map ID, x, y (0-1) for an NPC or object, from its main spawn
local function placeOf(kind, id)
	local name = get(kind, id, "name")
	if not name then return nil end
	local zone, x, y = mainSpawn(get(kind, id, "spawns"))
	zone = zone or get(kind, id, "zoneID")
	local map = zone and api.questieUiMap(zone)
	local label = name
	local zname = zoneName(zone)
	if zname and x and y then label = ("%s (%s %.1f, %.1f)"):format(name, zname, x, y)
	elseif zname then label = ("%s (%s)"):format(name, zname) end
	return label, map, x and x / 100, y and y / 100
end

local function inLog(id) return C_QuestLog.GetLogIndexForQuestID(id) ~= nil end

-- the prerequisites of a quest that are not done yet: one of preQuestSingle (one in the log first) and each of
-- preQuestGroup; also the other choices of preQuestSingle
local function missingOf(id)
	local out, alternatives = {}, nil
	local single = get("Quest", id, "preQuestSingle")
	if type(single) == "table" and #single > 0 then
		local anyDone, pick = false, nil
		for _, pre in ipairs(single) do
			if isDone(pre) then anyDone = true break end
			if not pick or (inLog(pre) and not inLog(pick)) then pick = pre end
		end
		if not anyDone and pick then
			out[#out + 1] = pick
			if #single > 1 then alternatives = #single - 1 end
		end
	end
	local group = get("Quest", id, "preQuestGroup")
	for _, pre in ipairs(type(group) == "table" and group or {}) do
		if not isDone(pre) then out[#out + 1] = pre end
	end
	return out, alternatives
end

-- zone names of a list of spawns tables, up to MAX_ZONES, "Tanaris, Feralas, ..."
local function zoneList(spawnLists)
	local zones, seen = {}, {}
	for _, spawns in ipairs(spawnLists) do
		zonesOf(spawns, zones, seen)
		if #zones > MAX_ZONES then break end
	end
	if #zones == 0 then return nil end
	local shown = {}
	for i = 1, math.min(#zones, MAX_ZONES) do shown[i] = zones[i] end
	return table.concat(shown, ", ") .. (#zones > MAX_ZONES and ", ..." or "")
end

local function withZones(text, zones) return zones and (text .. " (" .. zones .. ")") or text end

-- The objectives as things to do, from Questie's objectives (creatures, objects, items, reputation, kill credit):
-- Kill, Use, Collect (dropped or looted), Buy (sold and not dropped), Earn reputation. Each: kind, text, place.
local function objectiveSteps(id, add)
	local objectives = get("Quest", id, "objectives")
	if type(objectives) ~= "table" then return end
	-- each kind is a list of entries (tables); anything else in a list (a later Questie format) is skipped
	local function list(i) return objectiveEntries(objectives, i) end
	for _, o in ipairs(list(1)) do
		local name = o[2] or get("Npc", o[1], "name") or "?"
		add("kill", withZones("Kill " .. name, zoneList({ get("Npc", o[1], "spawns") })))
	end
	for _, o in ipairs(list(2)) do
		local name = o[2] or get("Object", o[1], "name") or "?"
		local _, map, x, y = placeOf("Object", o[1])
		add("use", withZones("Use " .. name, zoneList({ get("Object", o[1], "spawns") })), map, x, y)
	end
	for _, o in ipairs(list(3)) do
		local item = o[1]
		local name = o[2] or get("Item", item, "name") or ("item " .. tostring(item))
		local npcDrops, objectDrops = get("Item", item, "npcDrops"), get("Item", item, "objectDrops")
		local vendors = get("Item", item, "vendors")
		local dropped = (type(npcDrops) == "table" and #npcDrops > 0) or (type(objectDrops) == "table" and #objectDrops > 0)
		if not dropped and type(vendors) == "table" and vendors[1] then
			local label, map, x, y = placeOf("Npc", vendors[1])
			add("buy", "Buy " .. name .. (label and (" from " .. label) or ""), map, x, y)
		else
			local spawns = {}
			for _, npc in ipairs(type(npcDrops) == "table" and npcDrops or {}) do
				spawns[#spawns + 1] = get("Npc", npc, "spawns")
				if #spawns > 8 then break end
			end
			for _, object in ipairs(type(objectDrops) == "table" and objectDrops or {}) do
				spawns[#spawns + 1] = get("Object", object, "spawns")
				if #spawns > 16 then break end
			end
			add("collect", withZones("Collect " .. name, zoneList(spawns)))
		end
	end
	-- reputation is one {factionID, value} pair, not a list of them (quest 1368: objectives[4] = {92, 3000})
	local rep = objectives[4]
	local reps = type(rep) == "table" and (type(rep[1]) == "number" and { rep } or list(4)) or {}
	for _, o in ipairs(reps) do
		local faction = o[1]
		local factionName = faction and GetFactionInfoByID and select(1, GetFactionInfoByID(faction))
		add("reputation", "Earn reputation" .. (factionName and (" with " .. factionName) or ""))
	end
	for _, o in ipairs(list(5)) do
		local npcs = type(o[1]) == "table" and o[1] or {}
		local name = o[3] or (npcs[1] and get("Npc", npcs[1], "name")) or "?"
		local spawns = {}
		for _, npc in ipairs(npcs) do spawns[#spawns + 1] = get("Npc", npc, "spawns") end
		add("kill", withZones("Kill " .. name, zoneList(spawns)))
	end
end

-- What to do for one prerequisite: accept (unless in the log), the objectives, turn in.
-- Each step: kind (accept, kill, use, collect, buy, reputation, turnin), text, map, x, y.
local function stepsFor(id)
	local steps = {}
	local function add(kind, text, map, x, y)
		steps[#steps + 1] = { kind = kind, text = text, map = map, x = x, y = y }
	end
	local name = questName(id)
	local logged = inLog(id)
	if not logged then
		local level = tonumber(get("Quest", id, "requiredLevel"))
		local need = level and level > (UnitLevel("player") or 0) and (" (needs level " .. level .. ")") or ""
		local by = get("Quest", id, "startedBy")
		local npc, object, item = type(by) == "table" and firstOf(by[1]), type(by) == "table" and firstOf(by[2]),
			type(by) == "table" and firstOf(by[3])
		if npc then
			local label, map, x, y = placeOf("Npc", npc)
			add("accept", "Accept " .. name .. " from " .. (label or "?") .. need, map, x, y)
		elseif object then
			local label, map, x, y = placeOf("Object", object)
			add("accept", "Accept " .. name .. " at " .. (label or "?") .. need, map, x, y)
		elseif item then
			add("accept", "Accept " .. name .. " from the item " .. (get("Item", item, "name") or ("#" .. item)) .. need)
		else
			add("accept", "Accept " .. name .. need)
		end
	end
	local complete = logged and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
	if not complete then
		objectiveSteps(id, add)
	end
	local by = get("Quest", id, "finishedBy")
	if type(by) == "table" and firstOf(by[1]) then
		local label, map, x, y = placeOf("Npc", firstOf(by[1]))
		add("turnin", "Turn in " .. name .. " to " .. (label or "?"), map, x, y)
	elseif type(by) == "table" and firstOf(by[2]) then
		local label, map, x, y = placeOf("Object", firstOf(by[2]))
		add("turnin", "Turn in " .. name .. " at " .. (label or "?"), map, x, y)
	else
		add("turnin", "Turn in " .. name)
	end
	return steps, logged
end

-- Questie data is usable (installed and ready; the window needs it whatever the tooltip option says)
function api.prereqDataReady()
	return ready() and getter("Quest") ~= nil
end

-- The prerequisites of a quest still to do, earliest first (each one's own prerequisites before it):
-- { { quest, name, inLog, alternatives, steps = { { text, map, x, y } } } }, and the direct ones as a set.
function api.prereqPlan(id)
	if not api.prereqDataReady() then return nil end
	local plan, seen, direct = {}, {}, {}
	local function visit(quest, depth)
		if seen[quest] or depth > MAX_PREREQ_DEPTH or #plan >= MAX_PREREQ_QUESTS then return end
		seen[quest] = true
		local missing, alternatives = missingOf(quest)
		for _, pre in ipairs(missing) do
			if depth == 0 then direct[pre] = true end
			if not seen[pre] then
				visit(pre, depth + 1)
				local steps, logged = stepsFor(pre)
				plan[#plan + 1] = { quest = pre, name = questName(pre), inLog = logged, steps = steps,
					alternatives = depth == 0 and alternatives or nil }
			end
		end
	end
	visit(id, 0)
	return plan, direct
end

api.prereqQuestName = function(id) return questName(id) end

-- Experience (Questie's QuestXP, level-adjusted) and gold (the game's quest data) of a list of quests together
-- A quest's reward items from Questie's item data (Item.questRewards; Questie does not tell choices from fixed
-- rewards). nil while the index is still being built (the journal redraws when it is ready).
function api.questRewardItems(id)
	if not api.prereqDataReady() then return {} end
	return rewardItems(id)
end

function api.questRewardTotals(ids)
	local xp, money = 0, 0
	for _, id in ipairs(ids) do
		xp = xp + (questXP(id) or 0)
		money = money + (questMoney(id) or 0)
	end
	return xp, money
end

---------------------------------------------------------------------------------------------------------------------
-- Raid attunement quests (star on Elite+ quest titles)
---------------------------------------------------------------------------------------------------------------------
-- The star in front of attunement quest titles: Elite+ icons on, the star option on, Questie data used
-- (the star itself, at the Elite+ icon size, is api.attunementStar in Extras.lua)

-- Re-sort and redraw when the option changes or Questie becomes ready.
local clearCaches -- below: every per-quest answer, so nothing from before Questie was ready is kept
function api.applyQuestie()
	if clearCaches then clearCaches() end
	if api.applyExtras then api.applyExtras() end
	if api.sortNow then api.sortNow() end
	if api.rebuildMoreQuests then api.rebuildMoreQuests() end
end

clearCaches = function()
	wipe(getters); wipe(zoneNames); wipe(zoneCache); wipe(zoneCacheComplete); wipe(pointCache); wipe(pointComplete)
	wipe(attuneCache)
	attunementSet = nil
end

ns.onLogin[#ns.onLogin + 1] = function()
	-- Ctrl shows the whole chain: redraw an open quest tooltip when Ctrl is pressed or released
	local keys = CreateFrame("Frame")
	keys:RegisterEvent("MODIFIER_STATE_CHANGED")
	keys:SetScript("OnEvent", function(_, _, key)
		if (key == "LCTRL" or key == "RCTRL") and api.questieOn() and ns.db.questieChain ~= false
			and api.refreshQuestTooltip then
			api.refreshQuestTooltip()
		end
	end)
	local questie = _G.Questie
	if C_AddOns.IsAddOnLoaded("Questie") and type(questie) == "table" and type(questie.API) == "table"
		and type(questie.API.RegisterOnReady) == "function" then
		pcall(questie.API.RegisterOnReady, function() api.applyQuestie() end)
	end
end
