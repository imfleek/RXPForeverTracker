-- Load RXPForeverTracker's TOC in order with a permissive stub API, then build the settings window on both tabs.
local dir, mode = arg[1], "plain" -- mode: "plain", "oldguide", "oldtracker"
local mt = {}
local function any() return setmetatable({}, mt) end
mt.__index = function(t, k) local v = any(); rawset(t, k, v); return v end
mt.__call = function() return any() end
for _, op in ipairs({"__add","__sub","__mul","__div","__unm","__mod","__pow","__idiv"}) do mt[op] = function() return 0 end end
mt.__lt = function() return false end; mt.__le = function() return true end
mt.__concat = function(a, b) return tostring(type(a)=="table" and "" or a) .. tostring(type(b)=="table" and "" or b) end
mt.__len = function() return 0 end
-- frames: real tables with methods returning numbers where layout code does arithmetic
local frameMT = {}
frameMT.__index = function(t, k)
	if k == "GetWidth" or k == "GetHeight" or k == "GetStringHeight" or k == "GetVerticalScroll" or k == "GetFrameLevel" or k == "GetStringWidth" or k == "GetValue" or k == "GetEffectiveScale" then return function() return 100 end end
	if k == "GetText" then return function(self) return rawget(self, "_text") or "" end end
	if k == "GetCursorPosition" then return function(self) return rawget(self, "_cursor") or #(rawget(self, "_text") or "") end end
	if k == "SetCursorPosition" then return function(self, v) rawset(self, "_cursor", v) end end
	if k == "HighlightText" then return function(self, a, b) rawset(self, "_hl", { a, b }) end end
	if k == "SetAlpha" then return function(self, a) rawset(self, "_alpha", a) end end
	if k == "SetFocus" then return function(self) rawset(self, "_focus", true) end end
	if k == "GetTop" or k == "GetBottom" then return function() return 400 end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "GetFont" then return function() return "font", 12, "" end end
	if k == "GetMinMaxValues" then return function() return 0, 100 end end
	if k == "IsShown" then return function(self) return rawget(self, "_shown") ~= false end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
	if k == "Show" then return function(self) rawset(self, "_shown", true) end end
	if k == "SetShown" then return function(self, v) rawset(self, "_shown", v and true or false) end end
	if k == "HookScript" or k == "SetScript" then return function(self, name, fn) rawset(self, "_s_" .. name, fn) end end
	if k:match("^Create") then return function() return setmetatable({}, frameMT) end end
	if k == "ScrollBar" or k == "Instructions" or k == "qtsHint" or k == "qtsOwn" then return nil end
	return function() return nil end
end
_G.CreateFrame = function() return setmetatable({}, frameMT) end
_G.UIParent = setmetatable({}, frameMT)
local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers+1] = f end, NewTicker = function() return any() end }
_G.C_AddOns = { IsAddOnLoaded = function(n) return (mode == "oldguide" and n == "AllObjectivesRXP") or (mode == "oldtracker" and (n == "AllTrackerRXP")) or (n == "Auctionator" and mode ~= "noauct") end,
	GetAddOnMetadata = function() return "2.1.0" end }
_G.SlashCmdList, _G.UISpecialFrames = {}, {}
_G.LibStub = nil
if mode ~= "noauct" then _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 12345 end, GetAuctionPriceByItemID = function() return 999 end } } } end
if mode == "oldtracker" then _G.AllTrackerRXPDB = { scale = 1.2 }; _G.AllTrackerRXPObjectivesDB = { followingSteps = 5 } end
if mode == "oldguide" then _G.AllObjectivesRXPDB = { followingSteps = 6 } end
_G.ObjectiveTrackerFrame = setmetatable({ modules = {} }, frameMT)
local nilNames = { LibStub = true, issecretvalue = true, ScrollBar = true }
setmetatable(_G, { __index = function(_, k) if nilNames[k] or k:match("DB$") or k == "Auctionator" then return nil end return any() end })
local root = {}
for line in io.lines(dir .. "/RXPForeverTracker.toc") do
	line = line:gsub("\r", "")
	if line:match("%.lua$") then
		local ok, err = pcall(assert(loadfile(dir .. "/" .. line)), "RXPForeverTracker", root)
		if not ok then print("LOAD ERROR", line, err) os.exit(1) end
	end
end
for _, f in ipairs(timers) do f() end
print("mode", mode, "disabledAll", tostring(root.disabledAll), "standalone", tostring(root.standaloneObjectives))
print("migrated tracker", rawget(_G, "RXPForeverTrackerDB") and rawget(_G, "RXPForeverTrackerDB").scale, "guide", rawget(_G, "RXPForeverTrackerGuideDB") and rawget(_G, "RXPForeverTrackerGuideDB").followingSteps)
for _, m in ipairs(chat) do print("CHAT", m) end

local t = root.tracker
t.db = { minimap = { hide = false }, configTextSize = 1, scale = 1, zoneHeaderColor = {1,1,1}, xpColor = {1,1,1}, height = 0, step = 40, font = "default" }
setmetatable(t.db, { __index = function(_, k) if k == "configSize" or k == "configTab" or k == "pos" or k == "rewardOrder" or k:match("Color$") or k == "zoneOrder" then return nil end return 1 end })
for _, fn in ipairs(t.onLogin) do pcall(fn) end
rawset(t.db, "configAlpha", 0.6)
assert(pcall(t.api.toggleConfig))
local function up(fn, want)
	local i = 1
	while true do
		local n, v = debug.getupvalue(fn, i)
		if not n then return nil end
		if n == want then return v end
		i = i + 1
	end
end
-- find the declared items list and the font choice
local declared
local function search(fn, depth, seen)
	if declared or depth > 4 or seen[fn] then return end
	seen[fn] = true
	local i = 1
	while true do
		local n, v = debug.getupvalue(fn, i)
		if not n then break end
		if n == "declared" then declared = v return end
		if type(v) == "function" then search(v, depth + 1, seen) end
		i = i + 1
	end
end
search(t.api.toggleConfig, 0, {})
local fontItem
for _, item in ipairs(declared or {}) do if item.kind == "choice" and item.fontPreview then fontItem = item end end

local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local applies = 0
local orig = t.api.refreshPrereqsFonts
t.api.refreshPrereqsFonts = function() applies = applies + 1 end
local sizeItem
for _, item in ipairs(declared or {}) do if item.label == "Text size" then sizeItem = item end end
local function frame()
	local list = timers
	timers = {}
	for _, fn in ipairs(list) do pcall(fn) end
	return #list
end
for _ = 1, 5 do frame() end
applies = 0
sizeItem.set(1.32)
local perFrame = {}
for i = 1, 12 do frame(); perFrame[i] = applies end
print("font applications after one change, frame by frame: " .. table.concat(perFrame, " "))
check("fonts settle (no per-frame loop)", perFrame[12] == perFrame[6])
print(pass and "PASS" or "FAILED")
