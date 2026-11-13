-- 3.5.61: the restart button: to the first step, and a second click back to where you were
local A = arg[1]
_G.C_Timer = { After = function() end }
_G.UnitLevel = function() return 30 end
_G.hooksecurefunc = function() end
_G.PlaySound = function() end
_G.SOUNDKIT = {}
local progress, calls = 12, {}
local guide = { steps = {} }
for i = 1, 20 do guide.steps[i] = { index = i, elements = {} } end
local RXP = { currentGuide = guide, GetGuideProgress = function() return progress end,
	SetStep = function(n) calls[#calls + 1] = n; progress = n end }
local ns = { rxp = RXP, db = {}, isSecret = function() return false end, say = function() end,
	hookRxp = function() return true end, rxpProfile = function() return {} end }
assert(loadfile(A .. "/Objectives/tracker/SkipBox.lua"))("x", { objectives = ns })
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
check("usable away from the first step", ns.canRestart() and not ns.restartPending())
ns.restartToggle()
check("click: to the first step", calls[1] == 1 and progress == 1 and ns.restartPending())
check("its tooltip offers the way back", ns.restartTip():find("step 12", 1, true) ~= nil)
check("still usable at the first step (to come back)", ns.canRestart())
progress = 3 -- you moved on a little
ns.restartToggle()
check("second click: back to step 12", calls[2] == 12 and progress == 12 and not ns.restartPending())
progress = 1
check("at the first step with nothing to return to: dimmed", not ns.canRestart())
progress = 9
ns.restartToggle()
RXP.currentGuide = { steps = guide.steps }
check("another guide forgets the way back", not ns.restartPending())
-- 3.5.63: a guide that opens with ".maxlevel 43,SoSSkip" (optional, jumps to a label): start after it
do
	local g = { steps = {} }
	for i = 1, 20 do g.steps[i] = { index = i, elements = {} } end
	g.steps[1] = { index = 1, optional = true, elements = { { tag = "maxlevel", level = 43, ref = "SoSSkip", textOnly = true } } }
	RXP.currentGuide, progress, calls = g, 15, {}
	ns.restartToggle()
	check("the opening jump step is passed by: starts at step 2", calls[1] == 2)
	ns.restartToggle()
	check("and back to 15", calls[2] == 15)
	progress = 2
	check("at its real first step with nothing to return to: dimmed", not ns.canRestart())
end
print(pass and "PASS" or "FAILED")
