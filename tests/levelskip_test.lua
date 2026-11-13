-- 3.5.38: "Skip overleveled steps" mirrors RestedXP's own setting; one chat line when a started guide is level-skipped
local A = arg[1]
_G.Clamp = function(v, a, b) return math.min(math.max(v, a), b) end
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
local hooks = {}
_G.hooksecurefunc = function(t, k, f) hooks[k] = f end
_G.UnitLevel = function() return 45 end
local detected = 0
local profile = { enableXpStepSkipping = true }
local settings = { profile = profile, DetectXPRate = function() detected = detected + 1 end }
local said = {}
local function xp(level) return { elements = { { tag = "xp", level = level } } } end
local guide = { key = "k", name = "41-43 Swamp", steps = { xp(42), xp(42), xp(43), xp(43), {}, {} } }
local progress = 6
local RXP = { settings = settings, currentGuide = guide, GetGuideProgress = function() return progress end,
	LoadGuide = function() end }
local ns = { rxp = RXP, db = {}, refresh = function() end, MAX_FOLLOWING = 20,
	rxpProfile = function() return profile end, questFocusOn = function() return false end,
	isSecret = function() return false end, say = function(t) said[#said + 1] = t end,
	hookRxp = function(o, k, f) hooksecurefunc(o, k, f) return true end }
assert(loadfile(A .. "/Objectives/Settings.lua"))("x", { objectives = ns })
-- SkipBox needs only its tail here: load it with stubbed frames untouched (functions are defined, not run)
assert(loadfile(A .. "/Objectives/tracker/SkipBox.lua"))("x", { objectives = ns })
local g = ns.settings
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
profile.enableXpStepSkipping = true
hooks.LoadGuide()
for _, f in ipairs(timers) do f() end
check("a started guide skipped for level: one chat line", #said == 1 and said[1]:find("passed 4 steps", 1, true) and said[1]:find("4 you are past its level", 1, true) ~= nil)
hooks.LoadGuide(); for _, f in ipairs(timers) do f() end
check("said once per guide", #said == 1)
profile.enableXpStepSkipping = false
local other = { key = "k2", name = "x", steps = guide.steps }
RXP.currentGuide = other; hooks.LoadGuide(); for _, f in ipairs(timers) do f() end
check("setting off: nothing said", #said == 1)
-- auto-skip reasons and above-level steps (3.5.40)
profile.enableXpStepSkipping = true
local function noted(text) return { elements = { { tooltipText = text } } } end
local prereq = { key = "k3", name = "ZF", steps = { noted("Step skipped: Missing pre-requisites"), noted("Step skipped: Missing pre-requisites"),
	{ level = 50, elements = {} }, noted("Step skipped: Quest already turned in"), {} } }
progress = 5
RXP.currentGuide = prereq; hooks.LoadGuide(nil, prereq); for _, f in ipairs(timers) do f() end
local last = said[#said]
check("reasons counted and the auto-skip setting named", #said == 2 and last:find("passed 4 steps", 1, true)
	and last:find("2 Missing pre-requisites", 1, true) and last:find("1 above your level", 1, true)
	and last:find("Disable step skips", 1, true) ~= nil)
profile.disableAutoSkip = true
local printed = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) printed[#printed + 1] = t end }
hooks.SetStep(3)
ns.printMoves()
local text = table.concat(printed, "\n")
print("     " .. text:gsub("\n", " | "))
check("/rt why (no window: chat) lists the moves in words and the settings", text:find("Passed step 3 on the way to step 5", 1, true)
	and text:find("Step skips: off", 1, true) ~= nil)
-- 3.5.42: restart this guide / reset all
local savedAt, reloaded, resetAll
RXP.SaveGuideProgress = function(guide, step) savedAt = { guide, step } end
RXP.ReloadGuide = function() reloaded = true end
RXP.ResetGuideProgress = function() resetAll = true end
RXP.currentGuide = prereq
check("restart saves step 1 for the guide and loads it again", g.restartGuide() and savedAt[1] == prereq and savedAt[2] == 1 and reloaded)
check("reset all uses RestedXP's own reset", g.resetAllProgress() and resetAll)
print(pass and "PASS" or "FAILED")
