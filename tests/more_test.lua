-- MoreQuests.lua with a fake 31-quest log (3 zone headers), watch limit 20, first 20 watched.
local dir = arg[1]
local F = {}
F.__index = function(t, k)
	if k == "GetStringHeight" then return function() return 12 end end
	if k == "GetWidth" then return function() return 260 end end
	if k == "GetEffectiveScale" or k == "GetScale" then return function() return 1 end end
	if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12, "" end end
	if k == "GetLeft" then return function() return 100 end end
	if k == "GetFrameLevel" then return function() return 1 end end
	if k == "GetBottom" then return function(s) return rawget(s, "_bottom") or 300 end end
	if k == "IsShown" then return function(s) return rawget(s, "_shown") ~= false end end
	if k == "Show" then return function(s) rawset(s, "_shown", true) end end
	if k == "Hide" then return function(s) rawset(s, "_shown", false) end end
	if k == "SetText" then return function(s, v) SETTEXT_CALLS = (SETTEXT_CALLS or 0) + 1; rawset(s, "_text", v) end end
	if k == "GetText" then return function(s) return rawget(s, "_text") end end
	if k == "SetScript" then return function(s, n, f) rawset(s, "_" .. n, f) end end
	if k == "GetParent" then return function(s) return rawget(s, "_parent") end end
	if k == "SetParent" then return function(s, p) rawset(s, "_parent", p) end end
	if k == "SetHeight" then return function(s, h) rawset(s, "_h", h) end end
	if k == "SetPoint" then return function(s, ...) rawset(s, "_point", { ... }) end end
	if k == "GetTop" then return function(s) return rawget(s, "_top") or 800 end end
	if k:match("^Create") then return function() return setmetatable({}, F) end end
	return function() end
end
_G.CreateFrame = function() return setmetatable({}, F) end
_G.geterrorhandler = function() return function(e) print("ERROR", e) end end
_G.UIParent = setmetatable({}, F)
_G.RXPForeverTrackerViewport = setmetatable({}, F)
local questModule = setmetatable({ GetContentsHeight = function() return 900 end }, F)
_G.QuestObjectiveTracker = questModule
_G.ObjectiveTrackerFrame = setmetatable({ modules = { questModule }, IsCollapsed = function() return false end }, F)
_G.Constants = { QuestWatchConsts = { MAX_QUEST_WATCHES = 20 } }
local log, watched = {}, {}
local zones = { "Tanaris", "Badlands", "Desolace" }
local qid = 100
for z, zone in ipairs(zones) do
	log[#log + 1] = { isHeader = true, title = zone }
	for i = 1, (z == 1 and 11 or 10) do
		qid = qid + 1
		log[#log + 1] = { questID = qid, title = "Quest " .. qid, level = 40 + z }
	end
end
local n = 0
for _, e in ipairs(log) do if e.questID and n < 20 then watched[e.questID] = true; n = n + 1 end end
_G.C_QuestLog = { GetNumQuestLogEntries = function() return #log end, GetInfo = function(i) return log[i] end,
	GetQuestWatchType = function(id) return watched[id] and 0 or nil end, GetNumQuestWatches = function() return n end,
	IsComplete = function(id) return id == 125 end,
	GetQuestObjectives = function(id) return { { text = "Thing slain: 2/8", finished = false } } end, AddQuestWatch = function() end }
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
local api = {}
api.moduleContentBottom = function() return 150 end
api.rewardSuffix = function(id) return "  |cffb087ff390xp|r" end
api.lastTrackedZone = "Badlands"
api.zoneHeaderHeight = function() return 14 end
local ns = { api = api, onLogin = {}, db = { enabled = true, trackMode = "all", zoneSort = true, moreQuests = true, questScale = 1 } }
assert(loadfile(dir .. "/Tracker/MoreQuests.lua"))("RXPForeverTracker", { tracker = ns, BRAND = "RXP ForeverTracker" })
ns.onLogin[1]()
for _, f in ipairs(timers) do f() end
local frame = _G.RXPForeverTrackerMoreQuests
-- read back the lines from the created FontStrings through the module's upvalues
local rows
for i = 1, 40 do local name, v = debug.getupvalue(api.layoutMoreQuests, i); if not name then break end end
local up = 1
local fn = api.rebuildMoreQuests
local lines = {}
local i = 1
while true do
	local name, v = debug.getupvalue(fn, i)
	if not name then break end
	if name == "schedule" and type(v) == "function" then
		local k = 1
		while true do
			local n3, v3 = debug.getupvalue(v, k)
			if not n3 then break end
			if n3 == "build" then name, v = n3, v3 break end
			k = k + 1
		end
	end
	if name == "build" then
		local j = 1
		while true do
			local n2, v2 = debug.getupvalue(v, j)
			if not n2 then break end
			if n2 == "rows" then rows = v2 end
			j = j + 1
		end
	end
	i = i + 1
end
local titles, shown = 0, 0
for _, r in ipairs(rows or {}) do
	if rawget(r, "_shown") ~= false and rawget(r, "_text") then
		shown = shown + 1
		local t = rawget(r, "_text")
		if t:match("^%[") then titles = titles + 1 end
		if shown <= 8 then print("  " .. t) end
	end
end
print(("quests in log 31, watched 20 -> listed in More quests: %d"):format(titles))
print("bottom reported to scroll range:", api.moreQuestsBottom())
for i = 1, 60 do local n, v = debug.getupvalue(api.layoutMoreQuests, i); if not n then break end; if n == "frame" then frame = v end end
local p = rawget(frame, "_point")
print(("More quests anchored: %s to section %s, y %s (expected -(800 - 150 + 8) = -658)"):format(p[1], p[3], p[5]))

-- a quest log update that changes nothing shown: no row is redrawn
local buildFn
do
	local i = 1
	while true do
		local n, v = debug.getupvalue(api.rebuildMoreQuests, i)
		if not n then break end
		if n == "schedule" then
			local k = 1
			while true do local n3, v3 = debug.getupvalue(v, k); if not n3 then break end; if n3 == "build" then buildFn = v3 end; k = k + 1 end
		end
		i = i + 1
	end
end
SETTEXT_CALLS = 0
buildFn()
print("unchanged update redraws rows:", SETTEXT_CALLS, "SetText calls")
api.rebuildMoreQuests(); for _, f in ipairs(timers) do f() end
SETTEXT_CALLS = 0
buildFn()
print("unchanged again:", SETTEXT_CALLS)

-- 3.5.32: folding the "Quests" section hides these quests too; unfolding shows them again
local hidden = false
rawset(frame, "Hide", function() hidden = true end)
rawset(frame, "Show", function() hidden = false end)
questModule.IsCollapsed = function() return true end
api.layoutMoreQuests()
print("Quests section folded -> More quests hidden:", hidden)
questModule.IsCollapsed = function() return false end
api.layoutMoreQuests()
print("unfolded -> shown again:", not hidden)
