-- 3.5.59: < is one step back (as RestedXP's "Go to step"), passing only steps already skipped; back again while
-- RestedXP puts you straight back on the step you left, nothing else
local A = arg[1]
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
_G.UnitLevel = function() return 30 end
_G.hooksecurefunc = function() end
_G.PlaySound = function() end
_G.SOUNDKIT = {}
local progress = 5
local calls = {}
local steps = { { index = 1, elements = { { tag = "goto" } } }, { index = 2, elements = { { tag = "kill" } } },
	{ index = 3, elements = { { tag = "accept" } } }, { index = 4, elements = { { tag = "accept", completed = true } } },
	{ index = 5, elements = { { tag = "x" } } } }
local bounce = {}
local RXP = { currentGuide = { steps = steps }, GetGuideProgress = function() return progress end,
	SetStep = function(n) calls[#calls + 1] = n; progress = bounce[n] or n end }
local ns = { rxp = RXP, db = {}, isSecret = function() return false end, say = function() end,
	hookRxp = function() return true end, rxpProfile = function() return {} end }
assert(loadfile(A .. "/Objectives/tracker/SkipBox.lua"))("x", { objectives = ns })
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local function run() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
ns.stepBack()
check("a step whose objective shows done is not passed by (that flag can be stale): goes to 4", calls[1] == 4)
calls, progress = {}, 5
steps[4].elements[1] = { tag = "accept", skip = true }
ns.stepBack()
check("a step you skipped (box ticked) is passed by: goes to 3", calls[1] == 3)
run()
-- RestedXP puts you straight back on 5: back again until it stays
calls, progress = {}, 5
steps[4].elements[1] = { tag = "kill" }
bounce[4], bounce[3] = 5, 5
ns.stepBack()
check("first: step 4", calls[1] == 4)
run()
check("put straight back on 5: one more step back, to 3", calls[2] == 3)
run()
check("put back again: on to 2", calls[3] == 2 and progress == 2)
run()
check("it stayed on 2: no more", #calls == 3)
-- 3.5.64: RestedXP rolling over past where you were
calls, progress, bounce = {}, 5, { [4] = 6 }
ns.stepBack()
run()
check("RestedXP rolled past where you were (no guide before this one): back to the step you were on", #calls == 2 and calls[2] == 5)
-- RestedXP moving to some other earlier step is left alone
calls, progress, bounce = {}, 5, { [4] = 2 }
ns.stepBack()
run()
check("RestedXP moved somewhere else (not past you): no fight", #calls == 1)
-- a step that jumps ahead (".maxlevel 43,SoSSkip") is never a back target
calls, progress, bounce = {}, 5, {}
steps[4].elements[1] = { tag = "maxlevel", level = 43, ref = "SoSSkip" }
ns.stepBack()
check("a jump step is passed by: goes to 3", calls[1] == 3)
steps[4].elements[1] = { tag = "kill" }
run()
-- a second click before the check: the first click's check does nothing
calls, progress, bounce = {}, 5, {}
ns.stepBack(); ns.stepBack()
run()
check("two quick clicks: two steps back, no extra moves", #calls == 2 and calls[1] == 4 and calls[2] == 3)
-- from step 2 of a guide whose step 1 jumps ahead: back goes to the previous zone guide, never onto step 1
do
	local loaded
	RXP.guides = { prev = { name = "Prev", group = "G", next = "Here" } }
	RXP.currentGuide = { name = "Here", group = "G", steps = { { index = 1, optional = true, elements = { { tag = "maxlevel", ref = "Skip" } } },
		{ index = 2, elements = { { tag = "kill" } } }, { index = 3, elements = {} } } }
	RXP.LoadGuide = function(_, g) loaded = g.name; RXP.currentGuide = { name = g.name, steps = { { elements = {} } } }; progress = 1 end
	calls, progress = {}, 2
	ns.stepBack()
	check("only a jump step before: back a zone guide instead", loaded == "Prev" and calls[1] == nil)
end
-- 3.5.69: Shift+click < > changes zone guide, wherever you are in this one
do
	local loaded
	RXP.guides = { prev = { name = "Prev", group = "G", next = "Here" } }
	local here = { name = "Here", group = "G", next = "There", steps = {} }
	for i = 1, 10 do here.steps[i] = { index = i, elements = { { tag = "kill" } } } end
	RXP.currentGuide = here
	RXP.GetGuideTable = function(g, n) if n == "There" then return { name = "There", group = g } end end
	RXP.LoadGuide = function(_, g) loaded = g.name; RXP.currentGuide = { name = g.name, steps = { { elements = {} } } }; progress = 1 end
	_G.IsShiftKeyDown = function() return true end
	calls, progress = {}, 6
	ns.stepBack()
	check("Shift+click <: the previous zone guide, even mid-guide", loaded == "Prev" and calls[1] == nil)
	RXP.currentGuide, loaded, progress = here, nil, 6
	ns.stepForward()
	check("Shift+click >: the next zone guide, even mid-guide", loaded == "There")
	_G.IsShiftKeyDown = function() return false end
	RXP.currentGuide, progress = here, 6
	check("< tooltip mentions Shift+click", ns.stepBackTip():find("Shift+click", 1, true) ~= nil)
	check("> tooltip mentions Shift+click", ns.stepForwardTip():find("Shift+click", 1, true) ~= nil)
end
print(pass and "PASS" or "FAILED")
