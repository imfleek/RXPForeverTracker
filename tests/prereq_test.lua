-- Missing prerequisites (3.2.0): Questie.lua api.prereqPlan and Prereqs.lua collect, with a fake Questie and guide.
local dir = arg[1]
local areas = { [440] = "Tanaris", [33] = "Stranglethorn Vale" }
local Q = {
	[100] = { name = "Gahz'rilla", preQuestSingle = { 99 }, startedBy = { { 1 } }, finishedBy = { { 1 } } },
	[99] = { name = "Divino-matic Rod", preQuestSingle = { 98 }, startedBy = { { 1 } }, finishedBy = { { 2 } },
		objectives = { { { 3, "Sandfury slain" } }, nil, { { 7 }, { 8 } } } },
	[98] = { name = "Scrying Goggles", startedBy = { { 2 } }, finishedBy = { { 1 } }, requiredLevel = 45 },
	[200] = { name = "Group needed", preQuestGroup = { 201, 202 } },
	[201] = { name = "Done one" }, [202] = { name = "Guide does it", startedBy = { { 1 } } },
	[300] = { name = "Either works", preQuestSingle = { 301, 302 } }, [301] = { name = "A" }, [302] = { name = "B" },
	[400] = { name = "No prereqs" },
	-- Questie's reputation objective is one {faction, value} pair (quest 1368, user report 3.5.13)
	[500] = { name = "Rep wanted", preQuestSingle = { 1368 }, startedBy = { { 1 } } },
	[1368] = { name = "Rep quest", startedBy = { { 1 } }, finishedBy = { { 1 } },
		objectives = { { 5 }, nil, { 9 }, { 92, 3000 } } },
}
local data = { Quest = Q,
	Npc = { [1] = { name = "Marin Noggenfogger", spawns = { [440] = { { 51.6, 26.9 } } } },
		[2] = { name = "Krazek", spawns = { [33] = { { 27.0, 77.1 } } } },
		[3] = { name = "Sandfury Troll", spawns = { [440] = { { 3, 3 } } } } },
	Object = {}, Item = { [7] = { name = "Troll Tusk", npcDrops = { 3 } }, [8] = { name = "Mild Spices", vendors = { 2 } } } }
_G.LibQuestieDB = {}
for kind, rows in pairs(data) do _G.LibQuestieDB[kind] = { Get = function(id, f) local r = rows[id]; return r and r[f] end } end
local completed = { [201] = true, [302] = true }
local logged = {}
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" end }
_G.Questie = { API = { isReady = true } }
_G.QuestieLoader = { ImportModule = function(_, name) if name == "ZoneDB" then return { GetUiMapIdByAreaId = function(_, a) return a + 1000 end } end return {} end }
_G.C_Map = { GetAreaInfo = function(id) return areas[id] end }
_G.C_QuestLog = { IsQuestFlaggedCompleted = function(id) return completed[id] or false end,
	GetLogIndexForQuestID = function(id) return logged[id] end, IsComplete = function() return false end,
	GetTitleForQuestID = function(id) return Q[id] and Q[id].name end }
_G.UnitLevel = function() return 40 end
_G.C_Timer = { NewTicker = function() return { Cancel = function() end } end }
local api = {}
local ns = { api = api, onLogin = {}, db = { questie = true } }
local root = { tracker = ns }
assert(loadfile(dir .. "/Tracker/Questie.lua"))("x", root)

local pass = true
local function check(label, cond) print((cond and "ok   " or "FAIL ") .. label); pass = pass and cond end

_G.GetFactionInfoByID = function(id) return id == 92 and "Gelkis Clan Centaur" or nil end
local okRep, repPlan = pcall(api.prereqPlan, 500)
check("a reputation objective ({92, 3000}) plans without an error", okRep)
local repText = ""
if okRep and type(repPlan) == "table" then
	for _, p in ipairs(repPlan) do for _, st in ipairs(p.steps or {}) do repText = repText .. (st.text or st[2] or "") .. "|" end end
end
check("and shows it as Earn reputation with the faction: " .. repText, repText:find("Earn reputation with Gelkis Clan Centaur", 1, true) ~= nil)

local plan, direct = api.prereqPlan(100)
check("plan: earliest first (98 then 99)", plan and #plan == 2 and plan[1].quest == 98 and plan[2].quest == 99)
check("direct prerequisite is 99", direct[99] and not direct[98])
check("accept step with giver and place", plan[1].steps[1].text == "Accept Scrying Goggles from Krazek (Stranglethorn Vale 27.0, 77.1) (needs level 45)"
	and plan[1].steps[1].map == 1033 and math.abs(plan[1].steps[1].x - 0.27) < 1e-9)
local st = plan[2].steps
check("kill step", st[2].kind == "kill" and st[2].text == "Kill Sandfury slain (Tanaris)")
check("collect step (dropped)", st[3].kind == "collect" and st[3].text == "Collect Troll Tusk (Tanaris)")
check("buy step (sold, not dropped) with vendor waypoint", st[4].kind == "buy" and st[4].text == "Buy Mild Spices from Krazek (Stranglethorn Vale 27.0, 77.1)" and st[4].map == 1033)
check("turn-in step", st[5].kind == "turnin" and st[5].text:find("^Turn in Divino%-matic Rod to Krazek") ~= nil)
check("accept step kind", plan[1].steps[1].kind == "accept")
check("group: only the missing one", (function() local p = api.prereqPlan(200); return #p == 1 and p[1].quest == 202 end)())
check("single list with one done: nothing missing", #api.prereqPlan(300) == 0)
logged[99] = 4
local p2 = api.prereqPlan(100)
check("prerequisite in the log: no accept step", p2[2].inLog and p2[2].steps[1].kind == "kill")
logged[99] = nil

-- window data: guide at step 5; step 7 accepts 202 (covers 200's prerequisite), step 10 accepts 100, step 12 accepts 200
_G.LibStub = function() return { GetAddon = function() return _G.RXP end } end
local steps = {}
for i = 1, 20 do steps[i] = { elements = {} } end
steps[3].elements = { { tag = "accept", questId = 98 } } -- before progress: does not cover
steps[7].elements = { { tag = "accept", questId = 202 } }
steps[10].elements = { { tag = "accept", questId = 100 } }
steps[12].elements = { { tag = "accept", questId = 200 } }
steps[14].elements = { { tag = "accept", questId = 300 }, { tag = "accept", questId = 400 } }
_G.RXP = { currentGuide = { steps = steps, name = "46-47 Feralas" }, GetGuideProgress = function() return 5 end,
	GetGuideName = function(g) return g.name end }
api.themeKit = {}
assert(loadfile(dir .. "/Tracker/Prereqs.lua"))("x", root)
local function up(fn, want)
	local i = 1
	while true do
		local name, value = debug.getupvalue(fn, i)
		if not name then return nil end
		if name == want then return value end
		i = i + 1
	end
end
local collect = up(up(up(up(api.togglePrereqs, "build"), "render"), "cachedCollect"), "collect")
local list, reason, guide, progress = collect()
check("window lists only quest 100", list and #list == 1 and list[1].quest == 100 and list[1].step == 10)
check("guide name and progress", guide == "46-47 Feralas" and progress == 5)
check("step 3 (behind you) does not count as the guide doing it", list[1].covered[98] == nil)
completed[98], completed[99] = true, true
check("all done: empty list", #collect() == 0)
Questie.API.isReady = false
local none, why = nil, nil
-- ready() latches once seen; a fresh load without Questie ready gives the reason
local api2 = {}
assert(loadfile(dir .. "/Tracker/Questie.lua"))("x", { tracker = { api = api2, onLogin = {}, db = {} } })
api2.themeKit = {}
assert(loadfile(dir .. "/Tracker/Prereqs.lua"))("x", { tracker = { api = api2 } })
none, why = up(up(up(up(api2.togglePrereqs, "build"), "render"), "cachedCollect"), "collect")()
check("without Questie ready: a reason, no list", none == nil and why:find("Questie") ~= nil)
print(pass and "PASS" or "FAILED")
