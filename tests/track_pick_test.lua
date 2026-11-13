local src = io.open(arg[1] .. "/Tracker/Config.lua"):read("a")
local body = src:match("(local TRACK_OPTIONS = {.-\nlocal function trackSet%(db, v%).-\nend)")
assert(body, "track block")
local db = { trackMode = nil, zoneSort = false, zoneFilter = false }
local api = {}
function api.setMode(mode, byZone) db.trackMode = mode; db.zoneSort = (mode ~= nil and byZone) and true or false end
function api.modeIs(mode, byZone)
	if byZone then return db.zoneSort and (db.trackMode or "all") == mode end
	return not db.zoneSort and db.trackMode == mode
end
function api.setZoneFilter(v) db.zoneFilter = v end
local env = setmetatable({ api = api }, { __index = _G })
local TRACK_OPTIONS, trackGet, trackSet = load(body .. "\nreturn TRACK_OPTIONS, trackGet, trackSet", "x", "t", env)()
for _, o in ipairs(TRACK_OPTIONS) do
	trackSet(db, o[1])
	local got = trackGet(db)
	print(("%-12s -> trackMode=%-6s zoneSort=%-5s zoneFilter=%-5s reads back %s"):format(o[1], tostring(db.trackMode),
		tostring(db.zoneSort), tostring(db.zoneFilter), got))
	assert(got == o[1])
end
trackSet(db, "myzone"); trackSet(db, "manual")
assert(db.zoneFilter == false and trackGet(db) == "manual")
print("OK")
