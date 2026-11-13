-- Load RXPForeverTracker's TOC in order with a permissive stub API, then build the settings window on both tabs.
local dir, mode = arg[1], arg[2] -- mode: "plain", "oldguide", "oldtracker"
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
if mode ~= "noauct" then _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 12345 end, GetAuctionPriceByItemID = function() return 999 end } } } end
if mode == "oldtracker" then _G.AllTrackerRXPDB = { scale = 1.2 }; _G.AllTrackerRXPObjectivesDB = { followingSteps = 5 } end
if mode == "oldguide" then _G.AllObjectivesRXPDB = { followingSteps = 6 } end
_G.ObjectiveTrackerFrame = setmetatable({ modules = {} }, frameMT)
local nilNames = { issecretvalue = true, ScrollBar = true, __events = true }
setmetatable(_G, { __index = function(_, k) if nilNames[k] or k:match("DB$") or k == "Auctionator" then return nil end return any() end })

-- a RestedXP that answers everything, except the parts named in REMOVE ("RXP.x" or "RXP.v2.y" or "RXP.RXPFrame.z")
local REMOVE = {}
for name in (os.getenv("REMOVE") or ""):gmatch("[^,]+") do REMOVE[name] = true end
local fromRxp = setmetatable({}, { __mode = "k" })
local function rxpTable(path)
	local t = {}
	fromRxp[t] = true
	return setmetatable(t, { __index = function(t, k)
		local full = path .. "." .. tostring(k)
		if REMOVE[full] then return nil end
		local key = tostring(k)
		local isTable = (key:match("^%l") and key ~= "next") or key == "RXPFrame" or key == "CurrentStepFrame" or key == "BarContainer"
		local v = isTable and rxpTable(full) or function() return any() end
		rawset(t, k, v); return v end,
		__call = function() return any() end })
end
local RXP = rxpTable("RXP")
local loadErrors = {}
_G.hooksecurefunc = function(a, b, c)
	local tbl, name = a, b
	if type(a) == "string" or not fromRxp[a] then return end
	if type(tbl) ~= "table" or type(tbl[name]) ~= "function" then
		error("hooksecurefunc: " .. tostring(name) .. " is not a function", 2)
	end
end
_G.LibStub = setmetatable({}, { __call = function(_, lib)
	if lib == "AceAddon-3.0" then return { GetAddon = function(_, n) return n == "RXPGuides" and RXP or nil end } end
	if lib == "AceEvent-3.0" then return { RegisterEvent = function(_, event, fn) _G.__events = _G.__events or {}; rawset(_G.__events, event, fn) end, RegisterMessage = function() end } end
	return nil
end })
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
print("objectives active", tostring(root.objectives and root.objectives.rxp ~= nil), "missing optional:", table.concat(root.objectives and root.objectives.missingRxp or {}, " "))

if mode == "breaker" then
	local ns = root.objectives
	local db = ns.db
	db.enabled = true
	local errors = 0
	_G.geterrorhandler = function() return function() errors = errors + 1 end end
	_G.debugstack = function() return "" end
	local before = #chat
	ns.guard(function() error("boom 1") end)
	ns.guard(function() return true end)
	ns.guard(function() error("boom 2") end)
	ns.guard(function() error("boom 3") end)
	print("after 2 in a row: enabled", tostring(db.enabled))
	ns.guard(function() error("RXP.v2:BuildGuideStepsSnapshot is nil") end)
	print("after 3 in a row: enabled", tostring(db.enabled), "suspended", tostring(ns.suspended()), "errors reported", errors)
	print("message", tostring(chat[#chat]):sub(1, 160))
	ns.guard(function() error("again") end)
	print("one message only", #chat - before == 1)
	__events.PLAYER_LOGOUT()
	print("saved setting restored on logout", tostring(db.enabled))
end
