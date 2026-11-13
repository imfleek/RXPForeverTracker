local dir = arg[1]
local areas = { [440] = "Tanaris", [33] = "Stranglethorn Vale", [1176] = "Zul'Farrak" }
local data = {
	Quest = {
		[100] = { name = "Gahz'rilla", startedBy = { { 1 } }, finishedBy = { { 2 } }, zoneOrSort = 1176,
			objectives = { { { 3, "Sandfury slain" } }, nil, { { 5, "Ritual Scroll" } } }, preQuestSingle = { 99 }, nextQuestInChain = 101 },
		[99] = { name = "Divino-matic Rod", preQuestSingle = { 98 }, nextQuestInChain = 100 },
		[98] = { name = "Scrying Goggles", nextQuestInChain = 99 },
		[101] = { name = "The Final Piece", questLevel = 47 },
	},
	Npc = {
		[1] = { name = "Marin Noggenfogger", spawns = { [440] = { { 51.6, 26.9 } } } },
		[2] = { name = "Krazek", spawns = { [33] = { { 27.0, 77.1 } } } },
		[3] = { name = "Sandfury Troll", spawns = { [1176] = { { 1, 1 }, { 2, 2 } }, [440] = { { 3, 3 } } } },
		[4] = { name = "Ritualist", spawns = { [33] = { { 5, 5 } } } },
	},
	Item = { [5] = { name = "Ritual Scroll", npcDrops = { 4 } }, [9] = { name = "Carrot on a Stick", questRewards = { 101 } }, [10] = { name = "Junk" } },
	Object = {},
}
_G.LibQuestieDB = {}
if arg[2] == "module" then
	-- no QuestieDB addon: Questie's own QuestieDB module through QuestieLoader
	local qdb = { ItemPointers = {} }
	local names = { Quest = "QueryQuestSingle", Npc = "QueryNPCSingle", Object = "QueryObjectSingle", Item = "QueryItemSingle" }
	for kind, rows in pairs(data) do qdb[names[kind]] = function(id, field) local r = rows[id]; return r and r[field] end end
	for id in pairs(data.Item) do qdb.ItemPointers[id] = true end
	_G.QUESTIE_MODULES = { QuestieDB = qdb }
end
if arg[2] == "module" then _G.LibQuestieDB = nil end
for kind, rows in pairs(_G.LibQuestieDB and data or {}) do
	_G.LibQuestieDB[kind] = { Get = function(id, field) local r = rows[id]; return r and r[field] end }
end
for kind, rows in pairs(_G.LibQuestieDB and data or {}) do
	_G.LibQuestieDB[kind].GetAllIds = function() local ids = {}; for id in pairs(rows) do ids[#ids + 1] = id end; table.sort(ids); return ids end
end
local ctrl, tickers = false, {}
_G.IsControlKeyDown = function() return ctrl end
_G.C_Timer = { NewTicker = function(_, fn) local t = { fn = fn, Cancel = function(self) self.done = true end }; tickers[#tickers + 1] = t; return t end }
_G.GetItemInfo = function(id) return nil end
_G.GetQuestLogRewardMoney = function(id) return ({ [100] = 4500, [101] = 12000 })[id] or 0 end
_G.QuestieLoader = { ImportModule = function(_, name)
	if _G.QUESTIE_MODULES and _G.QUESTIE_MODULES[name] then return _G.QUESTIE_MODULES[name] end
	if name == "QuestieDB" then return {} end
	return { db = {}, GetQuestLogRewardXP = function(_, id) return ({ [100] = 3300, [101] = 4100 })[id] or 0 end } end }
_G.Questie = { API = { isReady = true, RegisterOnReady = function() end } }
local complete = false
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" end }
_G.C_Map = { GetAreaInfo = function(id) return areas[id] end }
_G.C_QuestLog = { IsComplete = function() return complete end, GetTitleForQuestID = function(id) return data.Quest[id] and data.Quest[id].name end }
local api = {}
api.tipGold = function(c) return ("%dg %ds"):format(math.floor(c / 10000), math.floor(c / 100) % 100) end
local ns = { api = api, onLogin = {}, db = { questie = true, questieChain = true, questieChainReward = true } }
assert(loadfile(dir .. "/Tracker/Questie.lua"))("x", { tracker = ns })
local tip = { AddLine = function(_, text) print("  " .. (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end }
print("tooltip (no Ctrl):")
api.addQuestieLines(tip, 100)
for _, tk in ipairs(tickers) do while not tk.done do tk.fn() end end
ctrl = true
print("tooltip (Ctrl held, reward items loaded):")
api.addQuestieLines(tip, 100)
print("zone while in progress:", api.questieZone(100))
local function pts(list) local o = {} for _, p in ipairs(list or {}) do o[#o + 1] = ("%d:%g,%g"):format(p[1], p[2], p[3]) end return table.concat(o, " ") end
print("points while in progress:", pts(api.questiePoints(100)))
complete = true
print("points once complete:", pts(api.questiePoints(100)))
print("zone once complete:", api.questieZone(100))
Questie.API.isReady = false
print("Questie not ready ->", tostring(api.questieZone(100)), "| option:", api.questieOn())
Questie.API.isReady = true; ns.db.questie = false
print("option off ->", tostring(api.questieZone(100)))
