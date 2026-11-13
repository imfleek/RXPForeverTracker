-- 3.5.36: Waypoint arrow > Arrow scale sets RestedXP's own Arrow Scale and the arrow's size
local A = arg[1]
_G.Clamp = function(v, a, b) return math.min(math.max(v, a), b) end
_G.C_Timer = { After = function() end }
local size
local profile = { arrowScale = 1 }
local RXP = { settings = { profile = profile }, arrowFrame = { SetSize = function(_, w, h) size = { w, h } end } }
local refreshed = 0
local ns = { rxp = RXP, db = {}, refresh = function() refreshed = refreshed + 1 end, MAX_FOLLOWING = 20,
	rxpProfile = function() return profile end, questFocusOn = function() return false end }
assert(loadfile(A .. "/Objectives/Settings.lua"))("x", { objectives = ns })
local g = ns.settings
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
check("reads RestedXP's arrow scale", g.getArrowScale() == 1)
g.setArrowScale(1.5)
check("150 %: RestedXP's setting and the arrow (48 px) follow", profile.arrowScale == 1.5 and size[1] == 48 and size[2] == 48 and refreshed == 1)
g.setArrowScale(5)
check("kept within 20-200 %", profile.arrowScale == 2)
RXP.settings.profile = nil
local before = profile.arrowScale
g.setArrowScale(0.5)
check("no RestedXP profile: nothing written", profile.arrowScale == before)
print(pass and "PASS" or "FAILED")
