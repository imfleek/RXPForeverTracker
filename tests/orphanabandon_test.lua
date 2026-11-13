-- 3.5.84: orphaned quests come from RestedXP's list; abandoning re-checks each quest and goes one at a time
local A = arg[1]
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
local function run() while #timers > 0 do table.remove(timers, 1)() end end
local log = { 11, 12, 13 }
local selected, abandoned = nil, {}
_G.C_QuestLog = { GetLogIndexForQuestID = function(id) for i, q in ipairs(log) do if q == id then return i end end end,
	GetNumQuestLogEntries = function() return #log + 1 end,
	GetInfo = function(i) if i == 1 then return { isHeader = true, title = "Westfall" } end return { questID = log[i - 1] } end }
_G.SelectQuestLogEntry = function(i) selected = log[i] end
_G.SetAbandonQuest = function() end
_G.AbandonQuest = function() abandoned[#abandoned + 1] = selected; for i, q in ipairs(log) do if q == selected then table.remove(log, i) end end end
local hiddenSeen
local RXP = { isHidden = true, currentGuide = { key = "g" } }
RXP.GetOrphanedQuests = function()
	hiddenSeen = RXP.isHidden
	local out = {}
	for _, q in ipairs(log) do if q ~= 13 then table.insert(out, 1, { questID = q, questLogTitleText = "Q" .. q, level = 10 }) end end
	return out
end
local said = {}
local ns = { rxp = RXP, db = {}, say = function(t) said[#said + 1] = t end, refresh = function() end }
assert(loadfile(A .. "/Objectives/Settings.lua"))("x", { objectives = ns })
local g = ns.settings
local list = g.orphans()
check("RestedXP's list, read with its window treated as shown", hiddenSeen == false and RXP.isHidden == true)
check("each with its quest log zone", list[1].zone == "Westfall" and list[2].zone == "Westfall")
check("in quest-log order", #list == 2 and list[1].questID == 11 and list[2].questID == 12 and list[1].title == "Q11")
local finished
local n = g.abandonOrphans({ 12, 13 }, function(c) finished = c end)
run()
check("only orphans abandoned (13 is part of the guide)", n == 1 and #abandoned == 1 and abandoned[1] == 12 and finished == 1)
abandoned = {}
g.abandonOrphans({ 11 }, function(c) finished = c end)
run()
check("single quest by hover", #abandoned == 1 and abandoned[1] == 11 and said[#said]:find("Q11", 1, true) ~= nil)
RXP.GetOrphanedQuests = nil
check("no RestedXP function: not offered", not g.orphansAvailable() and #g.orphans() == 0)
print(pass and "ALL OK" or "SOME FAILED")
