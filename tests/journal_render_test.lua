-- 3.2.6: build and draw the Prerequisite Journal with stub frames: text size and font from /qt, icons scaled.
local A = arg[1]
local MT = {}
local function obj(t) return setmetatable(t or {}, MT) end
local fontsSet = {}
MT.__index = function(t, k)
	if k == "ScrollBar" or k == "UpdateScrollChildRect" then return nil end
	if k == "GetFont" then return function(self) return rawget(self, "_font") or "Fonts\\FRIZQT__.TTF", rawget(self, "_size") or 12, "" end end
	if k == "SetFont" then return function(self, f, s) rawset(self, "_font", f); rawset(self, "_size", s); fontsSet[#fontsSet + 1] = { f, s } end end
	-- as in the game: a font string keeps a size set with SetFont even when its font object is set again
	if k == "SetFontObject" then return function(self) if not rawget(self, "_size") then rawset(self, "_size", 12); rawset(self, "_font", "Fonts\\FRIZQT__.TTF") end end end
	if k == "GetStringHeight" then return function(self) return rawget(self, "_size") or 12 end end
	if k == "GetStringWidth" then return function() return 50 end end
	if k == "GetWidth" then return function() return 500 end end
	if k == "GetFrameLevel" then return function() return 5 end end
	if k == "GetHeight" then return function() return 400 end end
	if k == "GetVerticalScrollRange" then return function() return 0 end end
	if k == "GetVerticalScroll" then return function() return 0 end end
	if k == "IsShown" then return function(self) return rawget(self, "_shown") == true end end
	if k == "Show" then return function(self) rawset(self, "_shown", true); local f = rawget(self, "_OnShow"); if f then f(self) end end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
	if k == "SetSize" then return function(self, w, h) rawset(self, "_w", w); rawset(self, "_h", h) end end
	if k == "SetTextColor" then return function(self, r, g, b) rawset(self, "_color", { r, g, b }) end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "SetEnabled" then return function(self, v) rawset(self, "_enabled", not not v) end end
	if k == "SetAlpha" then return function(self, a) rawset(self, "_alpha", a) end end
	if k == "SetMinMaxValues" then return function(self, a, b) rawset(self, "_min", a); rawset(self, "_max", b) end end
	if k == "SetScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k == "GetFontString" then return function(self) local fs = rawget(self, "_fs") or obj(); rawset(self, "_fs", fs); return fs end end
	if k:match("^Create") then return function(self) return obj({ _parent = self }) end end
	return function() end
end
_G.CreateFrame = function() return obj() end
for _, name in ipairs({ "GameFontNormalLarge", "GameFontHighlightSmall", "GameFontNormal", "GameFontHighlight", "GameFontDisableSmall" }) do
	_G[name] = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end }
end
_G.UIParent = obj()
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.GameTooltip = obj()
_G.C_Timer = { After = function(_, f) f() end }
_G.DEFAULT_CHAT_FRAME = obj()
_G.C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end }
_G.LibStub = function() return { GetAddon = function() return _G.RXP end } end
local steps = { { elements = { { tag = "accept", questId = 100 } } } }
-- Open World guides Ashenvale -> Feralas (current) -> Tanaris; Feralas's next line names a guide that is not there,
-- so < > must follow the list, not the chain. Plus one Dungeon Guide, and groups the journal leaves out.
local OW, DG = "RestedXP Forever Guide (H)", "RestedXP Forever Dungeon Guide (H)"
local guides = {
	[OW .. "\\45-46 Ashenvale"] = { group = OW, name = "45-46 Ashenvale", next = "46-47 Feralas", steps = { { elements = {} } } },
	[OW .. "\\46-47 Feralas"] = { group = OW, name = "46-47 Feralas", next = "47-48 Missing Guide", steps = steps },
	[OW .. "\\47-48 Tanaris"] = { group = OW, name = "47-48 Tanaris", steps = { { elements = { { tag = "turnin", questId = 99 } } } } },
	[OW .. "\\48-49 Hinterlands"] = { group = OW, name = "48-49 Hinterlands", steps = { { elements = { { tag = "accept", questId = 300 } } } } },
	[OW .. "\\49-50 Azshara"] = { group = OW, name = "49-50 Azshara", steps = { { elements = {} } } },
	[OW .. "\\50-51 Searing Gorge"] = { group = OW, name = "50-51 Searing Gorge", steps = { { elements = {} } } },
	[OW .. "\\51-52 Un'Goro"] = { group = OW, name = "51-52 Un'Goro", steps = { { elements = {} } } },
	[OW .. "\\5-8 Inactive"] = { group = OW, name = "5-8 Inactive", inactive = true, steps = { { elements = {} } } },
	[DG .. "\\1-6 Durotar"] = { group = DG, name = "1-6 Durotar", steps = { { elements = {} } } },
	["RestedXP Forever Guide (A)\\1-6 Elwynn"] = { group = "RestedXP Forever Guide (A)", name = "1-6 Elwynn", steps = { { elements = {} } } },
	["RestedXP Forever Dungeon Quests (H)\\RFC"] = { group = "RestedXP Forever Dungeon Quests (H)", name = "RFC", steps = { { elements = {} } } },
}
local addonGuides = {}
for k, g in pairs(guides) do addonGuides[k:gsub("\\", "||")] = g end
_G.UnitFactionGroup = function() return "Horde" end
local function names(group, ...) local t = {} for _, n in ipairs({ ... }) do t[#t + 1] = { name = n, group = group } end return { names_ = t } end
_G.RXP = { currentGuide = guides[OW .. "\\46-47 Feralas"], GetGuideProgress = function() return 1 end, GetGuideName = function(g) return g.name end,
	guides = addonGuides, FetchGuide = function(_, group, name) return guides[group .. "\\" .. name] end,
	GetGuideTable = function(group, name) return guides[group .. "\\" .. name] end,
	IsGuideActive = function(g) return not g.inactive end,
	guideList = { [OW] = names(OW, "47-48 Tanaris", "46-47 Feralas", "5-8 Inactive", "45-46 Ashenvale", "48-49 Hinterlands",
		"49-50 Azshara", "50-51 Searing Gorge", "51-52 Un'Goro"),
		[DG] = names(DG, "1-6 Durotar"),
		["RestedXP Forever Guide (A)"] = names("RestedXP Forever Guide (A)", "1-6 Elwynn"),
		["RestedXP Forever Dungeon Quests (H)"] = names("RestedXP Forever Dungeon Quests (H)", "RFC") } }
local db = { configTextSize = 1.25, journalAlpha = 0.5 }
local api = {}
api.prereqDataReady = function() return true end
api.prereqQuestName = function() return "Gahz'rilla" end
local planCalls = 0
api.prereqPlan = function()
	planCalls = planCalls + 1
	return { { quest = 99, name = "Divino-matic Rod", steps = { { kind = "kill", text = "Kill Sandfury" }, { kind = "turnin", text = "Turn in", map = 1, x = 0.5, y = 0.5 } } } }, { [99] = true }
end
api.questRewardTotals = function() return 3500, 12500 end
local formatted
api.formatRewardTotals = function(xp, money) formatted = money; return xp .. "xp " .. money end
api.questRewardItems = function(id) return { 10, 11 } end
local prices = { [10] = 500, [11] = 1200 }
local requested = {}
_G.C_Item = { GetItemInfo = function(item) if prices[item] then return "Item" .. item, nil, nil, nil, nil, nil, nil, nil, nil, nil, prices[item] end end,
	GetItemIconByID = function(item) return 1000 + item end, RequestLoadItemDataByID = function(item) requested[#requested + 1] = item end }
_G.GameTooltip.SetItemByID = function(self, item) rawset(self, "_item", item) end
_G.GameTooltip.GetOwner = function() return nil end
api.fontPath = function() return "Fonts\\ARIALN.TTF" end
api.themeKit = { C = setmetatable({}, { __index = function() return { 0, 0, 0 } end }), create = function() return obj(), true end,
	solid = function() return obj() end, gradient = function() end, border = function() end,
	makeButton = function() return obj() end }
assert(loadfile(A .. "/Tracker/Prereqs.lua"))("x", { tracker = { api = api, db = db } })
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local ok, err = pcall(api.togglePrereqs)
check("journal opens and draws: " .. tostring(err), ok)
local arial, scaled = false, false
for _, f in ipairs(fontsSet) do
	if f[1] == "Fonts\\ARIALN.TTF" then arial = true end
	if f[2] == 15 then scaled = true end
end
check("chosen /qt font used", arial)
local up = function(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i); if not n then return end; if n == want then return v end; i = i + 1 end end
local win = up(up(api.togglePrereqs, "build"), "frame") or up(api.togglePrereqs, "frame")
check("journal opens at its saved opacity (50 %)", win and win._alpha == 0.5)
check("text size 125 % applied (12 -> 15)", scaled)
fontsSet = {}
db.configTextSize = 1
ok = pcall(api.refreshPrereqsFonts)
local back = false
for _, f in ipairs(fontsSet) do if f[2] == 12 then back = true end end
check("changing the /qt text size redraws the journal", ok and back)
check("gold includes the best vendor value per quest (12500 + 2 x 1200)", formatted == 14900)
local icons = up(up(up(api.togglePrereqs, "build"), "render"), "iconPool") or up(up(up(api.togglePrereqs, "build"), "render"), "addItemIcons") and up(up(up(up(api.togglePrereqs, "build"), "render"), "addItemIcons"), "iconPool")
check("two reward item icons (each item once)", icons and icons[1] and icons[2] and not icons[3] and icons[1].item == 10)
icons[2]._OnEnter(icons[2])
check("hover shows the item's tooltip", GameTooltip._item == 11)
prices[11] = nil
pcall(api.refreshPrereqsFonts)
check("an item not loaded yet is requested", requested[1] == 11)
-- redraws must not grow the text (the 3.4.0 screenshot)
db.configTextSize = 1.25
local biggest = 0
for _ = 1, 4 do
	fontsSet = {}
	pcall(api.refreshPrereqsFonts)
	for _, f in ipairs(fontsSet) do if f[2] > biggest then biggest = f[2] end end
end
check("four redraws at 125 %: text stays 15 (was growing)", biggest == 15)
-- < > browse the guide chain
local build = up(api.togglePrereqs, "build")
local render = up(build, "render")
local sub = up(render, "subtitle")
local prevB, nextB = up(render, "prevGuideButton"), up(render, "nextGuideButton")
pcall(api.refreshPrereqsFonts)
check("current guide named, no step number", sub._text and sub._text:find("^46%-47 Feralas") and sub._text:find("current guide") and not sub._text:find("step"))
check("both arrows usable in the middle of the chain", prevB._enabled and nextB._enabled)
nextB._OnClick(nextB)
check("> shows the next guide (Tanaris) though Feralas's next line is broken, marked later", sub._text:find("^47%-48 Tanaris") and sub._text:find("later guide"))
check("> still usable mid-list (Tanaris, more after it)", nextB._enabled == true and prevB._enabled == true)
for _ = 1, 4 do nextB._OnClick(nextB) end
check("> disabled only at the end of the list (Un'Goro)", sub._text:find("^51%-52") and nextB._enabled == false and prevB._enabled == true)
for _ = 1, 4 do prevB._OnClick(prevB) end
prevB._OnClick(prevB)
check("< comes back to the current guide", sub._text:find("^46%-47 Feralas") and sub._text:find("%(current guide%)"))
prevB._OnClick(prevB)
check("< shows the guide whose next is this one (Ashenvale)", sub._text:find("^45%-46 Ashenvale"))
check("< disabled at the start of the list, > still usable", prevB._enabled == false and nextB._enabled == true)
nextB._OnClick(nextB); nextB._OnClick(nextB)
check("> > from Ashenvale reaches Tanaris (arrows never grey mid-list)", sub._text:find("^47%-48 Tanaris") and prevB._enabled)
prevB._OnClick(prevB)
check("RestedXP's own guide unchanged", RXP.currentGuide.name == "46-47 Feralas")
-- the Guides dropdown: RestedXP's group list, pick one
local menuButton = up(render, "guideMenuButton")
local menu = up(build, "guideMenu")
check("Guides button usable", menuButton and menuButton._enabled)
menu.open()
local rows = up(menu.open, "menuRows")
local texts = {}
for i, r in ipairs(rows or {}) do if r._shown then texts[#texts + 1] = r.text._text:gsub("  |c.*$", "") end end
print("  menu: " .. table.concat(texts, " | "))
check("dropdown: only your current guide's list (Open World), level order, your faction, active guides",
	table.concat(texts, "|") == "Open World Guide|45-46 Ashenvale|46-47 Feralas|47-48 Tanaris|48-49 Hinterlands|49-50 Azshara|50-51 Searing Gorge|51-52 Un'Goro")
check("current marked", rows[3].text._text:find("%(current%)"))
local function rgb(i) local c = rows[i].text._color; return c[1], c[2], c[3] end
local yellow, orange, red = { 1, 0.88, 0.2 }, { 1, 0.55, 0.15 }, { 1, 0.3, 0.25 }
local function is(i, c) local r, g, b = rgb(i); return r == c[1] and g == c[2] and b == c[3] end
check("the next 2 after your guide yellow", is(4, yellow) and is(5, yellow))
check("the next 2 orange", is(6, orange) and is(7, orange))
check("the rest red", is(8, red))
check("earlier and current guides in the normal colour", not is(2, yellow) and not is(2, red) and not is(3, yellow))
db.journalHidePrevious = true
menu.open()
local hidden = {}
for _, r in ipairs(rows or {}) do if r._shown then hidden[#hidden + 1] = r.text._text:gsub("  |c.*$", "") end end
check("previous guides hidden: list starts at your current guide (" .. tostring(hidden[2]) .. ")", hidden[2] == "46-47 Feralas")
db.journalHidePrevious = nil
menu.open()
rows[4]._OnClick(rows[4])
check("picking Tanaris shows it", sub._text:find("^47%-48 Tanaris"))
local content = up(render, "content")
check("a later guide is greyed (60 %) and says so", content._alpha == 0.6 and sub._text:find("later guide"))
menu.open()
rows[3]._OnClick(rows[3])
check("picking the current guide goes back to it", sub._text:find("^46%-47 Feralas") and sub._text:find("%(current guide%)"))
check("the current guide is not greyed", content._alpha == 1)
menu.open()
rows[2]._OnClick(rows[2])
check("an earlier guide is not greyed", content._alpha == 1 and sub._text:find("%(previous guide%)"))
check("RestedXP's own guide still unchanged", RXP.currentGuide.name == "46-47 Feralas")
-- redraws for fonts and item data reuse the plans; Refresh builds them again
local before = planCalls
pcall(api.refreshPrereqsFonts)
pcall(api.refreshPrereqsFonts)
check("font / item redraws reuse the plans (no new plan lookups)", planCalls == before)
-- 3.5.65: a later guide names the zone guide on the way that does its missing prerequisites
do
	menu.open()
	local hint
	for _, r in ipairs(rows or {}) do
		if r._shown and r.text._text and r.text._text:find("^48%-49 Hinterlands") then r._OnClick(r) end
	end
	local pool = up(up(render, "addLine"), "acquire") and up(up(up(render, "addLine"), "acquire"), "pool")
	for _, line in ipairs(pool or {}) do
		local t = line.text and rawget(line.text, "_text")
		if t and t:find("wants this quest", 1, true) and line._shown ~= false then hint = hint or t end
	end
	print("     " .. tostring(hint))
	check("later guide: the guide on the way that hands in the prerequisite is named", hint and hint:find("done in |cffffd10047%-48 Tanaris") ~= nil)
end
print(pass and "PASS" or "FAILED")
