local dir, reverseMode = arg[1], arg[2] == "rev"
local maps = {
	[947] = { name = "Azeroth", parentMapID = 0 },
	[12] = { name = "Kalimdor", parentMapID = 947 }, [13] = { name = "Eastern Kingdoms", parentMapID = 947 },
	[71] = { name = "Tanaris", parentMapID = 12, mapType = 3, c = { 12, 100, 100 } },
	[66] = { name = "Desolace", parentMapID = 12, mapType = 3, c = { 12, 300, 300 } },
	[15] = { name = "Badlands", parentMapID = 13, mapType = 3, c = { 13, 50, 50 } },
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
}
local areaToMap = { [440] = 71, [405] = 66, [3] = 15 }
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
assert(loadfile(dir .. "/Tracker/ZoneSort.lua"))("x", { tracker = ns })
ns.onLogin[1]()
watches = { 1, 2, 3, 4, 5 }
local function show(label) print(label, table.concat(watches, ",")) end
api.sortNow(); flush(); show("sorted:")
assert(table.concat(watches, ",") == "2,1,5,3,4", "expected 2,1,5,3,4 got " .. table.concat(watches, ","))
-- the game sorts its own way; ours comes back
C_QuestLog.SortQuestWatches(); hooks.sort(); now = now + 11; flush(); show("after Blizzard sort:")
assert(table.concat(watches, ",") == "2,1,5,3,4")
-- walk to the south-west of Tanaris: quest 5 becomes the closest
px, py = 0.22, 0.22; now = now + 11; tickers[1](); flush(); show("after moving:")
assert(watches[1] == 5, "quest 5 first")
-- tiny moves do not re-order
local before = table.concat(watches, ",")
px, py = 0.221, 0.221; now = now + 11; tickers[1](); flush()
assert(table.concat(watches, ",") == before)
local all = {}
for i = 1, 3 do all[i] = { id = ({ 3, 5, 1 })[i], zone = quests[({ 3, 5, 1 })[i]].zone, index = i } end
local o = api.orderQuests(all); print("More quests order:", o[1].id, o[2].id, o[3].id)
ns.db.zoneOrder = "alpha"; local o2 = api.orderQuests(all); print("alpha:", o2[1].zone, o2[2].zone, o2[3].zone)
api.zoneDebug(print)
print("OK")
