-- 3.5.19: a just-loaded guide whose snapshot has no rows yet must not leave the RXP Tracker empty until the next step
local A = arg[1]
local timers = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.C_Timer = { After = function(d, f) timers[#timers + 1] = f end }
_G.GetTime = function() return 0 end
local rows = {}
local builds = 0
local RXP = { currentGuide = { name = "41-400_41-41 Swamp of Sorrows", steps = { {}, {}, {} } },
	GetGuideProgress = function() return 1 end,
	v2 = { BuildGuideStepsSnapshot = function() builds = builds + 1; return { rows = rows, title = "t", subtitle = "s" } end } }
local invalidated = 0
local ns = { rxp = RXP, db = { enabled = true }, L = function(t) return t end, drawn = function() return nil end,
	invalidate = function() invalidated = invalidated + 1 end, truncate = function() end }
local root = { objectives = ns }
local chunk = assert(loadfile(A .. "/Objectives/rxp/Snapshot.lua"))
chunk("x", root)
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
check("no rows yet: nothing drawn", ns.snapshot() == nil)
check("a re-read is scheduled", #timers == 1)
rows[1] = { step = 1 }
-- buildEntries etc. may need more; only check that the next pass reads the list again
timers[1]()
check("the retry asks for a redraw", invalidated == 1)
local before = builds
pcall(ns.snapshot)
check("the next pass builds the list again (not the cached empty one)", builds == before + 1)
-- a guide with no steps (the empty guide) does not retry forever
rows = {}
RXP.currentGuide = { empty = true, steps = {} }
timers = {}
ns.guideChanged(); ns.snapshot()
check("the empty guide is not retried", #timers == 0)
-- the retries stop after a while
RXP.currentGuide = { name = "x", steps = { {} } }
timers = {}
for _ = 1, 40 do ns.snapshot() end
check("at most 20 retries (5 s) per load: " .. #timers, #timers <= 20)
print(pass and "PASS" or "FAILED")
