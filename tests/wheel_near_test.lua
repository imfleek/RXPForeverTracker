-- 3.5.6: the quest tracker leaves the wheel alone when the cursor is nearer the RXP Tracker than the quests
local A = arg[1]
local src = io.open(A .. "/Tracker/Core.lua"):read("*a")
local a = src:find("local function screenRect", 1, true)
local b = src:find("local function onWheel", 1, true)
local function rect(l, b2, w, h, shown) return { GetRect = function() return l, b2, w, h end, GetEffectiveScale = function() return 1 end,
	IsShown = function() return shown ~= false end } end
local cursor = { 0, 0 }
local chunk = "local guide, pinGuide, viewport, tracker, moduleVisible, isForeign, GetCursorPosition = ...\n"
	.. src:sub(a, b - 1) .. "\nreturn nearerGuide"
local guideF = rect(0, 500, 200, 100)               -- y 500..600 (pinned on top)
local quests = rect(0, 200, 200, 280)               -- y 200..480
local view = rect(0, 100, 200, 400)                 -- y 100..500
local more = rect(0, 0, 200, 50, false)
_G.RXPForeverTrackerMoreQuests = more
local nearer = assert(loadstring(chunk))(guideF, true, view, { modules = { quests } }, function() return true end,
	function() return false end, function() return cursor[1], cursor[2] end)
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
cursor = { 100, 550 }; check("over the RXP Tracker: quests don't scroll", nearer() == true)
cursor = { 100, 495 }; check("in the gap, nearer the RXP Tracker (5 px vs 15 px): no scroll", nearer() == true)
cursor = { 100, 485 }; check("in the gap, nearer the quests: they scroll", nearer() == false)
cursor = { 100, 300 }; check("over the quests: they scroll", nearer() == false)
quests.GetRect = function() return 0, 600, 200, 100 end -- scrolled out of view
cursor = { 100, 550 }; check("no quest in view: the quests scroll as before", nearer() == false)
print(pass and "PASS" or "FAILED")
