-- 3.5.0: profiles (Tracker/Profiles.lua): Default on first use, save/load/delete, export/import round trip, junk refused.
local A = arg[1]
local events
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(self, _, f) events = f end } end
local tracker = { scale = 1, scrollbarColor = { 0.2, 0.85, 0.55 }, font = "default", pos = { "CENTER", 0, 0 },
	ahValue = 5, zoneHidden = { [1] = true } }
local guide = { theme = "rxp", followingSteps = 3, onboarded = { x = true } }
local ns = { api = {}, onLogin = {}, db = tracker }
local root = { tracker = ns, objectives = { db = guide } }
assert(loadfile(A .. "/Tracker/Profiles.lua"))("x", root)
local api = ns.api
for _, fn in ipairs(ns.onLogin) do fn() end
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
check("first use: Default, active", api.activeProfile() == "Default" and api.profileNames()[1] == "Default")
check("bookkeeping not in a profile", tracker.profiles.Default.tracker.ahValue == nil and tracker.profiles.Default.tracker.zoneHidden == nil
	and tracker.profiles.Default.guide.onboarded == nil)
tracker.scale, guide.theme = 1.3, "forever"
check("save as new", api.saveProfile("  Raid  ") and api.profileNames()[2] == "Raid")
check("empty name refused", not api.saveProfile("   "))
-- export / import
local text = api.exportProfile("Raid")
check("export string has the prefix and no | characters", text:sub(1, 7) == "RXPFT1:" and not text:find("|", 1, true))
local ok, msg, name = api.importProfile(text, "")
check("import under its own name replaces Raid: " .. tostring(msg), ok and name == "Raid")
ok, msg, name = api.importProfile(text, "Copy of Raid")
check("import under a new name", ok and name == "Copy of Raid" and tracker.profiles["Copy of Raid"].tracker.scale == 1.3
	and tracker.profiles["Copy of Raid"].guide.theme == "forever")
check("junk refused", not api.importProfile("hello", "") and not api.importProfile("RXPFT1:@@@@", ""))
-- a string that is Lua code is only data: nothing runs
_G.HACKED = nil
local codec = api.profileCodec
local evil = "RXPFT1:" .. codec.encode64('{s7:tracker{s5:scalen1;}s4:names3:Bad}')
ok = api.importProfile(evil, "")
check("well-formed data imports", ok and tracker.profiles.Bad.tracker.scale == 1)
ok = api.importProfile("RXPFT1:" .. codec.encode64("_G.HACKED = true return {}"), "")
check("Lua code in a string is refused and never run", not ok and _G.HACKED == nil)
-- wrong-typed values are dropped
local typed = "RXPFT1:" .. codec.encode64('{s7:tracker{s5:scales3:big}s4:names5:Typed}')
api.importProfile(typed, "")
check("a value of the wrong kind is dropped", tracker.profiles.Typed.tracker.scale == nil)
-- load Raid while Default is active: Default keeps what was in use (1.5), Raid's values come in
tracker.scale = 1.5
ok = api.loadProfile("Raid")
check("load Raid: its values in use, active", ok and tracker.scale == 1.3 and guide.theme == "forever" and api.activeProfile() == "Raid")
check("the profile left was saved first (Default = 1.5)", tracker.profiles.Default.tracker.scale == 1.5)
check("bookkeeping kept on load", tracker.ahValue == 5 and guide.onboarded.x == true and tracker.profiles ~= nil)
api.loadProfile("Default")
check("active profile cannot be deleted", api.activeProfile() == "Default" and not api.deleteProfile("Default"))
check("another can", api.deleteProfile("Copy of Raid") and tracker.profiles["Copy of Raid"] == nil)
-- logout saves the active profile
tracker.scale = 0.9
events()
check("logout keeps the active profile up to date", tracker.profiles.Default.tracker.scale == 0.9)
-- round trip of the codec
local value = { a = 1.25, b = "x|y:z{}", c = true, d = { 1, 2, { e = false } } }
local back = codec.deserialise(codec.decode64(codec.encode64(codec.serialise(value))))
check("codec round trip", back.a == 1.25 and back.b == "x|y:z{}" and back.c == true and back.d[3].e == false)
print(pass and "PASS" or "FAILED")
