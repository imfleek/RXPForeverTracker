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
check("font dropdown found", fontItem ~= nil)
local win = up(t.api.toggleConfig, "frame") or rawget(_G, "RXPForeverTrackerConfig")
check("window opens at the saved opacity (60 %)", win and win._alpha == 0.6)
local box = up(fontItem.place, "box")
pcall(fontItem.place, 0, 0, 600)
local ok, err = pcall(box._s_OnClick)
check("dropdown opens: " .. tostring(err), ok)
local popup = up(box._s_OnClick, "popup") or up(up(box._s_OnClick, "openList"), "popup")
check("type box shown and focused", popup and popup.typed and popup.typed._shown ~= false and popup.typed._focus)
local labels = {}
for _, o in ipairs(fontItem.options()) do labels[#labels + 1] = o[2] end
print("     options: " .. table.concat(labels, ", "))
local typed = popup.typed
typed:SetText("ar"); typed:SetCursorPosition(2)
typed._s_OnTextChanged(typed, true)
check("auto-fill: " .. typed:GetText(), typed:GetText() == "Arial Narrow" and typed._hl[1] == 2)
local visible = 0
for _, row in ipairs(popup.rows) do if row._shown then visible = visible + 1 end end
check("list filtered to matches (" .. visible .. ")", visible >= 1 and visible < #labels)
local picked
local set = fontItem.set
fontItem.set = function(v) picked = v end
typed._s_OnEnterPressed(typed)
check("Enter picks the suggestion: " .. tostring(picked), picked ~= nil and picked ~= "default")
fontItem.set = set
-- deleting does not re-fill
box._s_OnClick()
typed:SetText("ari"); typed:SetCursorPosition(3); typed._s_OnTextChanged(typed, true)
typed:SetText("ar"); typed:SetCursorPosition(2); typed._s_OnTextChanged(typed, true)
check("backspace keeps what was typed", typed:GetText() == "ar")
-- Text size: dragging shows the value, applies on release; arrows/wheel/typing apply at once
local sizeItem
for _, item in ipairs(declared or {}) do if item.label == "Text size" then sizeItem = item end end
local sl = sizeItem and sizeItem.sliderFrame
rawset(t.db, "configTextSize", 1)
local held = true
_G.IsMouseButtonDown = function() return held end
-- the game sends no mouse-down when the thumb is grabbed: only value changes while the button is held
sl._s_OnValueChanged(sl, 140)
sl._s_OnValueChanged(sl, 106)
sl._s_OnValueChanged(sl, 125)
check("while the button is held the text size is not applied", t.db.configTextSize == 1)
local watcher = up(sl._s_OnValueChanged, "watcher")
watcher._s_OnUpdate(watcher)
check("still held: still waiting", t.db.configTextSize == 1)
held = false
watcher._s_OnUpdate(watcher)
check("released: applied once (125 %)", math.abs(t.db.configTextSize - 1.25) < 1e-9)
sl._s_OnValueChanged(sl, 120)
check("wheel/arrows (button up): applied at once", math.abs(t.db.configTextSize - 1.2) < 1e-9)
-- the range is 80-125 %: an older saved 160 % counts as 125 %, and the window grows with the text
rawset(t.db, "configTextSize", 1.6)
check("a saved 160 % is used (and shown) as 125 %", sizeItem.get() == 125)
local win2 = up(t.api.toggleConfig, "frame")
local grown
win2.SetSize = function(self, w, h) grown = { w, h } end
win2.GetWidth = function() return 720 end
win2.GetHeight = function() return 480 end
win2.qtsFitText()
check("window grows to fit 125 % text (at least 900 x 600)", grown and grown[1] >= 900 and grown[2] >= 600)
-- Profiles page: Export fills the export box
local actions, exportBox
for _, item in ipairs(declared or {}) do
	if item.kind == "buttons" and item.label == "Profile actions" then actions = item end
	if item.kind == "input" and item.label:find("^Profile string") then exportBox = item end
end
check("Profiles page built (actions and export box)", actions ~= nil and exportBox ~= nil and exportBox.edit ~= nil)
for _, fn in ipairs(t.onLogin) do pcall(fn) end
local okE, errE = pcall(actions.list[4][2])
exportBox.refresh()
check("Export puts a profile string in the box: " .. tostring(errE), okE and (exportBox.edit:GetText() or ""):sub(1, 7) == "RXPFT1:")
-- general, RXP Tracker and Quest Tracker opacity
do local i = 1 while true do local n = debug.getupvalue(t.api.setTrackerAlpha, i); if not n then break end; if n == "db" then debug.setupvalue(t.api.setTrackerAlpha, i, t.db) end; i = i + 1 end end
for _, fn in ipairs({ t.api.trackerAlpha, t.api.guideTrackerAlpha, t.api.questTrackerAlpha }) do
	local i = 1 while true do local n = debug.getupvalue(fn, i); if not n then break end; if n == "db" then debug.setupvalue(fn, i, t.db) end; i = i + 1 end
end
rawset(t.db, "trackerAlpha", 1); rawset(t.db, "guideAlpha", 1); rawset(t.db, "questAlpha", 1)
local okA, errA = pcall(t.api.setTrackerAlpha, 0.5, "trackerAlpha")
check("general opacity applies: " .. tostring(errA), okA and t.db.trackerAlpha == 0.5)
pcall(t.api.setTrackerAlpha, 0.5, "guideAlpha")
pcall(t.api.setTrackerAlpha, 0.8, "questAlpha")
check("RXP Tracker opacity = general x its own", math.abs(t.api.guideTrackerAlpha() - 0.25) < 1e-9)
check("Quest Tracker opacity = general x its own", math.abs(t.api.questTrackerAlpha() - 0.4) < 1e-9)
pcall(t.api.setTrackerAlpha, 0.01, "trackerAlpha")
check("never below 10 %", t.api.trackerAlpha() == 0.1)
print(pass and "PASS" or "FAILED")
