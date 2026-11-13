local dir = arg[1]
local F = {}
F.__index = function(t, k)
	if k == "SetFont" then return function(s, file, size, flags)
		if type(size) ~= "number" then error("bad argument #2 to 'SetFont'") end
		rawset(s, "_font", { file, size, flags }) end end
	if k == "SetText" then return function(s, v) rawset(s, "_text", v) end end
	if k == "SetTextColor" then return function(s, r, g, b) rawset(s, "_rgb", { r, g, b }) end end
	if k:match("^Create") then return function() return setmetatable({}, F) end end
	return function() end
end
_G.CreateFrame = function() return setmetatable({}, F) end
_G.GameFontNormal = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end }
local header = setmetatable({ MinimizeButton = setmetatable({}, F),
	Text = { GetFont = function() return "Interface\\AddOns\\BigWigs\\Media\\Fonts\\NotoSans-Medium.otf", 14, "OUTLINE" end } }, F)
_G.QuestObjectiveTracker = { Header = header }
_G.ObjectiveTrackerFrame = setmetatable({}, F)
local count = 31
_G.C_QuestLog = { GetNumQuestLogEntries = function() return 40, count end, GetMaxNumQuestsCanAccept = function() return 40 end }
_G.C_Timer = { After = function() end }
local api = {}
local ns = { api = api, onLogin = {}, db = { enabled = true } }
assert(loadfile(dir .. "/Tracker/MoreQuests.lua"))("x", { tracker = ns })
local fs
for i = 1, 60 do local n, v = debug.getupvalue(api.updateQuestCount, i); if not n then break end end
for _, c in ipairs({ 26, 27, 36, 37, 39, 40 }) do
	count = c
	api.updateQuestCount()
	local i = 1
	while true do local n, v = debug.getupvalue(api.updateQuestCount, i); if not n then break end; if n == "countText" then fs = v end; i = i + 1 end
	local rgb = rawget(fs, "_rgb")
	local name = rgb[1] >= 1 and rgb[2] <= 0.2 and "red" or rgb[1] >= 1 and rgb[2] < 0.6 and "orange" or rgb[1] >= 1 and "yellow" or "green"
	print(("%s  %s  font %s %d"):format(rawget(fs, "_text"), name, rawget(fs, "_font")[1]:match("[^\\]+$"), rawget(fs, "_font")[2]))
end
