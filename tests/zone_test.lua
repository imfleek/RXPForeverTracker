local dir = arg[1]
local maps = {
	[947] = { name = "Azeroth", parentMapID = 0 },
	[12] = { name = "Kalimdor", parentMapID = 947 }, [13] = { name = "Eastern Kingdoms", parentMapID = 947 },
	[71] = { name = "Tanaris", parentMapID = 12, mapType = 3, c = { 12, 100, 100 } },
	[66] = { name = "Desolace", parentMapID = 12, mapType = 3, c = { 12, 300, 300 } },
	[15] = { name = "Badlands", parentMapID = 13, mapType = 3, c = { 13, 50, 50 } },
	[219] = { name = "Zul'Farrak", parentMapID = 71, mapType = 4 },
}
_G.Enum = { UIMapType = { Zone = 3 } }
_G.CreateVector2D = function(x, y) return { x = x, y = y } end
_G.C_Map = {
	GetBestMapForUnit = function() return 71 end,
	GetMapInfo = function(id) local m = maps[id]; return m and { name = m.name, parentMapID = m.parentMapID, mapType = m.mapType } end,
	GetMapChildrenInfo = function(root) local out = {}; for id, m in pairs(maps) do if id ~= root then out[#out + 1] = { mapID = id, name = m.name, mapType = m.mapType } end end; return out end,
	GetWorldPosFromMapPos = function(id, v) local m = maps[id]; if not (m and m.c) then return nil end; return m.c[1], { x = m.c[2] + (v.x - 0.5) * 20, y = m.c[3] + (v.y - 0.5) * 20 } end,
	GetPlayerMapPosition = function() return { x = 0.6, y = 0.6 } end,
}
_G.GetRealZoneText = function() return "Tanaris" end
_G.GetTime = function() return 0 end
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
_G.hooksecurefunc = function() end
_G.C_QuestLog = {}
local api = {}
local ns = { api = api, onLogin = {}, db = { zoneSort = true, enabled = true } }
assert(loadfile(dir .. "/Tracker/ZoneSort.lua"))("x", { tracker = ns })
ns.onLogin[1]()
local zones = { "Riverglades", "Badlands", "Desolace", "Zul'Farrak", "Tanaris" }
-- the same sort the tracker uses, via the module's sorted()
local sorted
for i = 1, 80 do local n, v = debug.getupvalue(api.sortNow, i); if not n then break end
	if n == "schedule" then for j = 1, 80 do local n2, v2 = debug.getupvalue(v, j); if not n2 then break end
		if n2 == "sortWatches" then for k = 1, 80 do local n3, v3 = debug.getupvalue(v2, k); if not n3 then break end
			if n3 == "sorted" then sorted = v3 end end end end end end
local list = {}
for i, z in ipairs(zones) do list[i] = { id = i, zone = z, index = i } end
local out = sorted(list)
local names = {}
for _, q in ipairs(out) do names[#names + 1] = q.zone end
print("tracked quest zones, closest first: " .. table.concat(names, ", "))
local mo = api.orderQuests({ { id = 1, zone = "Badlands", index = 1 }, { id = 2, zone = "Tanaris", index = 2 } }); print("More quests order:", mo[1].zone, mo[2].zone)
