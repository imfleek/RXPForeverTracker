-- 3.5.81: the RXP Tracker's commands are typed after /qt; /rt is gone
local A = arg[1]
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
_G.SlashCmdList = {}
local printed = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) printed[#printed + 1] = t end }
local said, calls = {}, {}
local db = { enabled = true, followingSteps = 3, arrowButton = true, arrowSatellites = true }
local ns = { rxp = {}, db = db, MAX_FOLLOWING = 100, ALL_STEPS = 101, accent = function(t) return t end, brand = "RXP Tracker",
	refresh = function() calls.refresh = (calls.refresh or 0) + 1 end, updateWindows = function() end,
	say = function(t) said[#said + 1] = t end, rxpProfile = function() return {} end,
	printMoves = function() calls.why = true end, showWelcome = function() calls.welcome = true end,
	settings = { restartGuide = function() calls.restart = true end } }
assert(loadfile(A .. "/Objectives/Slash.lua"))("x", { objectives = ns })
check("no /rt registered", rawget(SlashCmdList, "ALLOBJECTIVESRXP") == nil and _G.SLASH_ALLOBJECTIVESRXP1 == nil)
check("why runs", ns.runCommand("why") and calls.why)
check("restart runs", ns.runCommand("Restart") and calls.restart)
check("number sets steps ahead", ns.runCommand("7") and db.followingSteps == 7)
check("all sets every step", ns.runCommand("all") and db.followingSteps == 101)
check("toggle flips", ns.runCommand("toggle") and db.enabled == false)
check("unknown is left to /qt", ns.runCommand("height 300") == false and ns.runCommand("zone") == false)
printed = {}
check("help prints /qt lines", ns.runCommand("help") and table.concat(printed, "\n"):find("/qt ", 1, true) ~= nil
	and not table.concat(printed, "\n"):find("/rt", 1, true))
-- Core.lua's no-RestedXP branch: guide commands say why, others go to /qt's help
local src = io.open(A .. "/Objectives/Core.lua"):read("*a")
check("Core.lua registers no /rt", not src:find('"/rt"', 1, true) and not src:find("ALLOBJECTIVESRXP", 1, true))
local qt = io.open(A .. "/Tracker/Core.lua"):read("*a")
check("/qt passes on unknown commands", qt:find("guide.runCommand(msg)", 1, true) ~= nil)
for _, c in ipairs({ '"config"', '"guide"', '"quests"', '"orphan"', '"height <px>"', '"scale <0.5-1.5>"', '"step <px>"', '"zone"', '"sort"',
	'"lock"', '"unlock"', '"reset"', '"on"', '"off"', '"help"' }) do
	check("/qt help lists " .. c, qt:find("{ " .. c .. ",", 1, true) ~= nil)
end
check("/qt help is not taken by the guide's help", qt:find('cmd ~= "help"', 1, true) ~= nil)
printed = {}
ns.runCommand("help")
check("guide help lists steps", table.concat(printed, "\n"):find("/qt steps", 1, true) ~= nil)
check("/qt orphan opens the Orphaned quests page", qt:find('cmd == "orphan" or cmd == "orphans"', 1, true) and qt:find('openConfigTab("orphans")', 1, true) ~= nil)
print(pass and "ALL OK" or "SOME FAILED")
