-- 3.5.9: with Questie's tracker on, the prompt turns off only Questie's tracker, not Questie
local dir, how = arg[1], arg[2] -- how: "module" (QuestieTracker:Disable reachable) or "profile" (fallback)
_G.Questie = { db = { profile = { trackerEnabled = true } } }
local disabled, reloaded, shown, timers, moduleDisabled = {}, 0, nil, {}, false
if how ~= "profile" then
	local tracker = {}
	function tracker:Disable() moduleDisabled = true; Questie.db.profile.trackerEnabled = false; ReloadUI() end
	_G.QuestieLoader = { ImportModule = function(_, name) return name == "QuestieTracker" and tracker or nil end }
end
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" end, DisableAddOn = function(n) disabled[#disabled + 1] = n end,
	GetAddOnMetadata = function(n) return n end }
_G.ReloadUI = function() reloaded = reloaded + 1 end
_G.InCombatLockdown = function() return false end
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(which, a) shown = { which = which, a = a } end
_G.C_Timer = { After = function(d, f) timers[#timers + 1] = { d, f } end }
local evt
_G.CreateFrame = function() local f = { RegisterEvent = function() end, UnregisterEvent = function() end }
	f.SetScript = function(_, _, fn) evt = fn end; return f end
_G.RXPForeverTrackerDB = { enabled = true }
local root = { BRAND = "RXP ForeverTracker", tracker = { db = _G.RXPForeverTrackerDB, api = {} } }
assert(loadfile(dir .. "/Tracker/Conflicts.lua"))("RXPForeverTracker", root)
evt({ UnregisterEvent = function() end }, "PLAYER_ENTERING_WORLD", true, false)
timers[1][2]()
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local d = shown and StaticPopupDialogs[shown.which]
check("prompt shown for Questie's tracker", d ~= nil)
check("button says it turns off Questie's tracker", d.button2 == "Turn off Questie's tracker")
check("text says the rest of Questie keeps working", d.text:find("rest of Questie keeps working", 1, true) ~= nil)
d.OnCancel(nil, nil, "clicked")
check("Questie itself is not disabled", #disabled == 0)
check("its tracker is off", Questie.db.profile.trackerEnabled == false)
if how ~= "profile" then check("through Questie's own QuestieTracker:Disable", moduleDisabled) end
check("the UI reloads once", reloaded == 1)
print(pass and "PASS" or "FAILED")
