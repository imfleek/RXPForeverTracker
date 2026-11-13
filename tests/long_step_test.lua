-- 3.5.11: a very long current step pushes the quests down: wrapped text counts and the strip has no height cap
local A = arg[1]
local src = io.open(A .. "/Tracker/Core.lua"):read("*a")
local a = src:find("local DIVIDER_GAP", 1, true)
local b = src:find("-- The divider between the last step", 1, true)
local chunk = "local toScreen, ghost, db, tracker, scale, UIParent = ...\nlocal pinGuide, guide\n" .. src:sub(a, b - 1)
	.. "\nreturn { lowest = lowestShown, measure = function(p, g) pinGuide, guide = p, g; return measurePinned() end }"
local function region(bottom, text) return { GetObjectType = function() return "FontString" end, IsShown = function() return true end,
	GetText = function() return text end, GetBottom = function() return bottom end } end
local function frame(bottom, regions, children) return { IsShown = function() return true end, IsVisible = function() return true end,
	GetBottom = function() return bottom end, GetRegions = function() return unpack(regions or {}) end,
	GetChildren = function() return unpack(children or {}) end } end
local ghostH = 400
local ghost = { GetTop = function() return 600 end, GetHeight = function() return ghostH end }
local f = assert(loadstring(chunk))(function(_, v) return v end, ghost, {}, {}, function() return 1 end, {})
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local line = frame(470, { region(430, "Be careful as all Centipaar cast [Thrash] ...") })
local contents = frame(480, {}, { frame(465, {}, { line }) })
local guideF = frame(480); guideF.ContentsFrame = contents
check("wrapped text below its line counts (430; frames alone said 465)", f.lowest(contents, 3, 480) == 430)
check("empty text does not count", f.lowest(frame(470, { region(100, "") }), 0, 470) == 470)
check("quests start below the text: 600 - (430 - 12) = 182", f.measure(true, guideF) == 182)
ghostH = 150
check("a step taller than the window still pushes the quests below it (no cap: 182, was 50)", f.measure(true, guideF) == 182)
print(pass and "PASS" or "FAILED")
