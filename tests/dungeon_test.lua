local dir, reverseMode = arg[1], arg[2] == "rev"
local maps = {
	[947] = { name = "Azeroth", parentMapID = 0 },
	[12] = { name = "Kalimdor", parentMapID = 947 }, [13] = { name = "Eastern Kingdoms", parentMapID = 947 },
	[71] = { name = "Tanaris", parentMapID = 12, mapType = 3, c = { 12, 100, 100 } },
	[66] = { name = "Desolace", parentMapID = 12, mapType = 3, c = { 12, 300, 300 } },
	[15] = { name = "Badlands", parentMapID = 13, mapType = 3, c = { 13, 50, 50 } },
	[52] = { name = "Westfall", parentMapID = 13, mapType = 3, c = { 13, 80, 80 } },
}
local px, py = 0.6, 0.6
_G.Enum = { UIMapType = { Zone = 3 } }
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.CreateVector2D = function(x, y) return { x = x, y = y } end
-- 1 map unit = 1000 yards across a zone
_G.C_Map = {
	GetBestMapForUnit = function() return 71 end,
	GetMapInfo = function(id) local m = maps[id]; return m and { name = m.name, parentMapID = m.parentMapID, mapType = m.mapType } end,
	GetMapChildrenInfo = function(root) local out = {}; for id, m in pairs(maps) do if id ~= root then out[#out + 1] = { mapID = id, name = m.name, mapType = m.mapType } end end; return out end,
	GetWorldPosFromMapPos = function(id, v) local m = maps[id]; if not (m and m.c) then return nil end; return m.c[1], { x = m.c[2] * 10 + v.x * 1000, y = m.c[3] * 10 + v.y * 1000 } end,
	GetPlayerMapPosition = function() return { x = px, y = py } end,
}
_G.GetRealZoneText = function() return "Tanaris" end
local now = 0
_G.GetTime = function() return now end
_G.InCombatLockdown = function() return false end
_G.geterrorhandler = function() return function(e) error(e) end end
_G.xpcall = function(f, h) local ok, e = pcall(f); if not ok then h(e) end end
local timers, tickers = {}, {}
_G.C_Timer = { After = function(d, f) timers[#timers + 1] = f end, NewTicker = function(d, f) tickers[#tickers + 1] = f end }
local function flush() while #timers > 0 do local t = table.remove(timers, 1); t() end end
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(self, _, f) self.f = f end } end
local hooks = {}
_G.hooksecurefunc = function(t, name, f) if type(t) == "table" and name == "SortQuestWatches" then hooks.sort = f end end
local watches = {}
local quests = {
	[1] = { zone = "Tanaris", pts = { { 440, 90, 90 } } },   -- far corner of Tanaris
	[2] = { zone = "Tanaris", pts = { { 440, 61, 61 } } },   -- right next to the player
	[3] = { zone = "Desolace", pts = { { 405, 10, 10 } } },
	[4] = { zone = "Badlands", pts = { { 3, 50, 50 } } },    -- other continent
	[5] = { zone = "Tanaris", pts = { { 440, 20, 20 } } },
	[6] = { zone = "The Deadmines", pts = { { 999, 50, 50 } } },   -- dungeon quest (no outdoor map)
	[7] = { zone = "Westfall", pts = { { 1581, 40, 40 } } },       -- filed under Westfall, objectives in the Deadmines
	[8] = { zone = "Westfall", pts = { { 40, 30, 30 } } },         -- an ordinary Westfall quest
}
local areaToMap = { [440] = 71, [405] = 66, [3] = 15, [40] = 52 }
_G.C_QuestLog = {
	GetNumQuestWatches = function() return #watches end,
	GetQuestIDForQuestWatchIndex = function(i) return watches[i] end,
	GetQuestWatchType = function() return 0 end,
	RemoveQuestWatch = function(id) for i, v in ipairs(watches) do if v == id then table.remove(watches, i) break end end end,
	AddQuestWatch = function(id) if reverseMode then table.insert(watches, 1, id) else watches[#watches + 1] = id end end,
	IsComplete = function() return false end,
	SortQuestWatches = function() table.sort(watches) end,
}
local api = {}
local ns = { api = api, onLogin = {}, db = { zoneSort = true, enabled = true, zoneOrder = "closest" } }
api.questiePoints = function(id) return quests[id] and quests[id].pts end
api.questieUiMap = function(a) return areaToMap[a] end
api.questieZone = function(id) return quests[id] and quests[id].zone end
api.questieZoneName = function(area) return ({ [1581] = "The Deadmines", [40] = "Westfall", [440] = "Tanaris" })[area] end
assert(loadfile(dir .. "/Tracker/ZoneSort.lua"))("x", { tracker = ns })

local inside = false
_G.IsInInstance = function() return inside, inside and "party" or "none" end
_G.GetInstanceInfo = function() return inside and "Deadmines" or "Tanaris" end
ns.onLogin[1]()
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local function order()
	local list = {}
	for i, id in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8 }) do list[i] = { id = id, zone = quests[id].zone, index = i } end
	local out = api.orderQuests(list)
	local ids = {}
	for i, q in ipairs(out) do ids[i] = q.id end
	return ids
end
local outside = order()
print("outside:  " .. table.concat(outside, ","))
check("outside: Tanaris (where you are) first", outside[1] == 2)
check("outside: the Westfall dungeon quest has no special place", outside[1] ~= 7)
-- enter the Deadmines: no map position inside, the quest log header "The Deadmines"
inside = true
_G.GetRealZoneText = function() return "The Deadmines" end
_G.C_Map.GetBestMapForUnit = function() return nil end
now = now + 5
local ids = order()
print("in the Deadmines: " .. table.concat(ids, ","))
check("in a dungeon: its quests first", ids[1] == 6)
check("then the zone with a quest done in the dungeon (Westfall), that quest first", ids[2] == 7 and ids[3] == 8)
check("the rest keep their order after it", ids[4] == outside[1])
-- alphabetical order is left alone
ns.db.zoneOrder = "alpha"
local alpha = order()
print("alphabetical: " .. table.concat(alpha, ","))
check("alphabetical: Badlands first, not the dungeon", alpha[1] == 4)
print(pass and "PASS" or "FAILED")
