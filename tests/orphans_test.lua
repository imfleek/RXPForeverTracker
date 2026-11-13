-- Load RXPForeverTracker's TOC in order with a permissive stub API, then build the settings window on both tabs.
local dir, mode = arg[1], arg[2] -- mode: "plain", "oldguide", "oldtracker"
local mt = {}
local function any() return setmetatable({}, mt) end
mt.__index = function(t, k) local v = any(); rawset(t, k, v); return v end
mt.__call = function() return any() end
for _, op in ipairs({"__add","__sub","__mul","__div","__unm","__mod","__pow","__idiv"}) do mt[op] = function() return 0 end end
mt.__lt = function() return false end; mt.__le = function() return true end
mt.__concat = function(a, b) return tostring(type(a)=="table" and "" or a) .. tostring(type(b)=="table" and "" or b) end
mt.__len = function() return 0 end
-- frames: real tables with methods returning numbers where layout code does arithmetic
local frameMT = {}
frameMT.__index = function(t, k)
	if k == "GetWidth" or k == "GetHeight" or k == "GetStringHeight" or k == "GetVerticalScroll" or k == "GetFrameLevel" or k == "GetStringWidth" or k == "GetValue" or k == "GetEffectiveScale" then return function() return 100 end end
	if k == "GetText" then return function(self) return rawget(self, "_text") or "" end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "GetFont" then return function() return "font", 12, "" end end
	if k == "SetTextColor" then return function(self, r, g, b) rawset(self, "_color", { r, g, b }) end end
	if k == "GetMinMaxValues" then return function() return 0, 100 end end
	if k == "IsShown" then return function(self) return rawget(self, "_shown") ~= false end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
	if k == "Show" then return function(self) rawset(self, "_shown", true) end end
	if k == "SetShown" then return function(self, v) rawset(self, "_shown", v and true or false) end end
	if k == "HookScript" or k == "SetScript" then return function(self, name, fn) rawset(self, "_s_" .. name, fn) end end
	if k:match("^Create") then return function() return setmetatable({}, frameMT) end end
	if k == "ScrollBar" or k == "Instructions" or k == "qtsHint" or k == "qtsOwn" then return nil end
	return function() return nil end
end
_G.CreateFrame = function() return setmetatable({}, frameMT) end
_G.UIParent = setmetatable({}, frameMT)
local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers+1] = f end, NewTicker = function() return any() end }
_G.C_AddOns = { IsAddOnLoaded = function(n) return (mode == "oldguide" and n == "AllObjectivesRXP") or (mode == "oldtracker" and (n == "AllTrackerRXP")) or (n == "Auctionator" and mode ~= "noauct") end,
	GetAddOnMetadata = function() return "2.1.0" end }
_G.SlashCmdList, _G.UISpecialFrames = {}, {}
_G.LibStub = nil
if mode ~= "noauct" then _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 12345 end, GetAuctionPriceByItemID = function() return 999 end } } } end
if mode == "oldtracker" then _G.AllTrackerRXPDB = { scale = 1.2 }; _G.AllTrackerRXPObjectivesDB = { followingSteps = 5 } end
if mode == "oldguide" then _G.AllObjectivesRXPDB = { followingSteps = 6 } end
_G.ObjectiveTrackerFrame = setmetatable({ modules = {} }, frameMT)
local nilNames = { LibStub = true, issecretvalue = true, ScrollBar = true }
setmetatable(_G, { __index = function(_, k) if nilNames[k] or k:match("DB$") or k == "Auctionator" then return nil end return any() end })
local root = {}
for line in io.lines(dir .. "/RXPForeverTracker.toc") do
	line = line:gsub("\r", "")
	if line:match("%.lua$") then
		local ok, err = pcall(assert(loadfile(dir .. "/" .. line)), "RXPForeverTracker", root)
		if not ok then print("LOAD ERROR", line, err) os.exit(1) end
	end
end
for _, f in ipairs(timers) do f() end
print("mode", mode, "disabledAll", tostring(root.disabledAll), "standalone", tostring(root.standaloneObjectives))
print("migrated tracker", rawget(_G, "RXPForeverTrackerDB") and rawget(_G, "RXPForeverTrackerDB").scale, "guide", rawget(_G, "RXPForeverTrackerGuideDB") and rawget(_G, "RXPForeverTrackerGuideDB").followingSteps)
for _, m in ipairs(chat) do print("CHAT", m) end
local t = root.tracker
if not t.disabled and t.api.toggleConfig then
	t.db = { minimap = { hide = false }, configTextSize = 1, scale = 1, zoneHeaderColor = {1,1,1}, xpColor = {1,1,1}, height = 0, step = 40 }; setmetatable(t.db, { __index = function(_, k) if k == "configSize" or k == "configTab" or k == "pos" or k == "rewardOrder" or k:match("Color$") or k == "font" or k == "zoneOrder" then return nil end return 1 end })
	for _, fn in ipairs(t.onLogin) do local okL, e = pcall(fn); if not okL then print("login hook", e) end end
	if mode == "fakeguide" then
		local s = { enabled = true, followingSteps = 3, arrowButton = true, arrowSatellites = false, arrowCollapse = false, arrowLocked = false, quests = false }
		root.objectives.settings = { maxSteps = 8, get = function(k) return s[k] end, setEnabled = function(v) s.enabled = v end,
			setSteps = function(v) s.followingSteps = v end, setQuests = function(v) s.quests = v end, setFlag = function(k, v) s[k] = v end,
			lockedByRestedXP = function() return false end, showWelcome = function() print("welcome called") end, printStatus = function() print("status called") end,
			status = function() return { enabled = true, guide = "Test guide", counter = "Step 12/48", active = 2, ahead = 3, arrow = "button on" } end,
			reset = function() print("reset called") end,
			orphansAvailable = function() return true end,
			orphans = function() return ORPHANS end,
			abandonOrphans = function(ids, done) ABANDONED = ids; done(#ids) return #ids end }
		ORPHANS = { { questID = 12, title = "Other Quest", level = 25, zone = "Duskwood" }, { questID = 11, title = "Old Quest", level = 20, zone = "Westfall" } }
		root.objectives.rxp = { currentGuide = { key = "g", name = "Test guide" } }
		root.objectives.say = function(t) print("SAY", t) end
		rawset(_G, "UnitLevel", function() return 30 end)
		rawset(_G, "GetQuestDifficultyColor", nil)
		rawset(_G, "GetQuestGreenRange", function() return 8 end)
	end
	local ok, err = pcall(t.api.toggleConfig)
	print("build window", ok, err)
	ok, err = pcall(t.api.openConfigTab, "guide")
	print("guide tab", ok, err, "saved tab", t.db.configTab)
	ok, err = pcall(t.api.openConfigTab, "quests")
	print("quests tab", ok, err, "saved tab", t.db.configTab)
	if t.api.pageKeys then
		local okK, q, gk = pcall(t.api.pageKeys, "titles")
		local names = {}
		for k in pairs(okK and q or {}) do names[#names + 1] = k end
		table.sort(names)
		print("page keys (titles)", okK, table.concat(names, ","), "guide keys", okK and next(gk) ~= nil)
		print("db intact after", t.db.scale ~= nil and getmetatable(t.db) ~= nil)
	end
print("auctionator removed", t.api.auctionatorLoaded == nil)
	if t.api._ahValue then
		t.api._setDb({ ahValue = true })
		print("AH value link x2:", t.api._ahValue(123, "|Hitem:123|h", 2), "id only:", t.api._ahValue(123, nil, 1))
	end
end
print("slash", tostring(rawget(SlashCmdList, "ALLTRACKERRXP") ~= nil), tostring(rawget(_G, "SLASH_ALLTRACKERRXP1")))

if mode == "fakeguide" then
	local function up(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i); if not n then return end; if n == want then return v end; i = i + 1 end end
	local items = up(t.api.refreshConfig, "items")
	local orph
	for _, it in ipairs(items or {}) do if it.kind == "orphans" then orph = it end end
	local pass = true
	local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
	check("orphans on their own page in the RXP Tracker group", orph ~= nil and orph.page == "orphans")
	local pg = up(t.api.refreshConfig, "pageByKey") or up(up(t.api.refreshConfig, "query") or function() end, "pageByKey")
	local function findUp(fn, want, depth, seen)
		seen = seen or {}
		if type(fn) ~= "function" or seen[fn] or depth < 0 then return end
		seen[fn] = true
		local i = 1
		while true do
			local n, v = debug.getupvalue(fn, i)
			if not n then return end
			if n == want then return v end
			if type(v) == "function" then local r = findUp(v, want, depth - 1, seen); if r then return r end end
			i = i + 1
		end
	end
	local pagesList = findUp(t.api.openConfigTab, "pages", 3) or findUp(t.api.toggleConfig, "pages", 3)
	if pagesList then
		local order = {}
		for _, p in ipairs(pagesList) do order[#order + 1] = p.key end
		local list = table.concat(order, ",")
		check("listed right under Themes & guide (" .. list .. ")", list:find("guide,orphans", 1, true) ~= nil)
		for _, p in ipairs(pagesList) do if p.key == "orphans" then check("in the RXP Tracker group, with Defaults for its sort", p.group == "guide" and p.reset ~= nil) end end
	else
		print("     (pages list not reachable from refreshConfig)")
	end
	local kinds = {}
	for _, it in ipairs(items) do if it.page == "orphans" then kinds[#kinds + 1] = it.kind .. ":" .. tostring(it.label) end end
	local k = table.concat(kinds, " | ")
	check("Sort by choice and Reverse checkbox above the list (" .. k .. ")", k:find("choice:Sort by", 1, true) and k:find("check:Reverse the order", 1, true)
		and k:find("choice:Sort by", 1, true) < k:find("orphans:", 1, true))
	rawset(t.db, "orphanSort", "level"); rawset(t.db, "orphanReverse", false)
	orph.refresh()
	local holder = orph.frame
	local rows = up(orph.refresh, "rows")
	local summary = up(orph.refresh, "summary")
	local cleanup = up(orph.refresh, "cleanup")
	local c1 = rawget(rows[1].label, "_color")
	print("     colours:", c1 and table.concat(c1, ","), rawget(rows[2].label, "_color") and table.concat(rawget(rows[2].label, "_color"), ","))
	check("rows coloured by difficulty (level 20 grey, 25 green at level 30)", c1 and c1[1] == 0.5 and c1[2] == 0.5
		and rawget(rows[2].label, "_color")[2] == 0.75)
	check("zone shown left of each quest", rows[1].zone._text == "Westfall" and rows[2].zone._text == "Duskwood")
	-- 3.5.92: sort by name / zone, reversed
	local function order() local o = {} for i = 1, 2 do o[i] = rows[i].questID end return table.concat(o, ",") end
	local saved = t.db
	t.db.orphanSort = "zone"; orph.refresh()
	check("sort by zone (Duskwood before Westfall): " .. order(), order() == "12,11")
	t.db.orphanSort = "name"; orph.refresh()
	check("sort by name (Old before Other): " .. order(), order() == "11,12")
	t.db.orphanReverse = true; orph.refresh()
	check("reversed: " .. order(), order() == "12,11")
	t.db.orphanReverse = false; t.db.orphanSort = "level"; orph.refresh()
	check("sorted low level first", rows[1].questID == 11 and rows[2].questID == 12)
	check("two quests listed", #rows == 2 and rows[1].label._text:find("Old Quest", 1, true) and rows[1]._shown ~= false)
	check("summary counts them", summary._text:find("2 quests in your log are not part of Test guide", 1, true) ~= nil)
	check("cleanup button labelled with count", (cleanup._text or ""):find("Cleanup orphaned quests (2)", 1, true) ~= nil)
	-- hover shows the row's Abandon button
	check("abandon hidden before hover", rows[2].abandon._shown == false)
	rows[2]._s_OnEnter(rows[2])
	check("hover shows Abandon", rows[2].abandon._shown == true)
	rows[2].abandon._s_OnClick(rows[2].abandon)
	check("first click asks again", rawget(_G, "ABANDONED") == nil and (rows[2].abandon._text or ""):find("Sure", 1, true) ~= nil)
	rows[2].abandon._s_OnClick(rows[2].abandon)
	check("second click abandons only that quest", ABANDONED and #ABANDONED == 1 and ABANDONED[1] == 12)
	ABANDONED = nil
	ORPHANS = { { questID = 11, title = "Old Quest", level = 20 } }
	orph.refresh()
	check("list follows the quest log", rows[2]._shown == false and summary._text:find("1 quest in your log is", 1, true) ~= nil)
	cleanup._s_OnClick(cleanup)
	check("cleanup asks first", rawget(_G, "ABANDONED") == nil)
	cleanup._s_OnClick(cleanup)
	check("cleanup abandons every orphan", ABANDONED and #ABANDONED == 1 and ABANDONED[1] == 11)
	ORPHANS = {}
	orph.refresh()
	check("none left: says so, button hidden", summary._text:find("No orphaned quests", 1, true) ~= nil and cleanup._shown == false)
	t.api.openConfigTab("orphans")
	check("/qt orphan's page opens", t.db.configPage == "orphans")
	print(pass and "ALL OK" or "SOME FAILED")
end
