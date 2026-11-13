-- 3.5.83: /qt debug opens a themed window; "Copy all and close" selects all and closes after Ctrl+C; /qt focus is gone
local A = arg[1]
local MT = {}
local function obj(t) return setmetatable(t or {}, MT) end
MT.__index = function(t, k)
	if k == "GetHeight" or k == "GetWidth" then return function() return 300 end end
	if k == "GetVerticalScroll" or k == "GetFrameLevel" then return function() return 0 end end
	if k == "IsShown" then return function(self) return rawget(self, "_shown") == true end end
	if k == "Show" then return function(self) rawset(self, "_shown", true) end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false); local f = rawget(self, "_OnHide"); if f then f(self) end end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "SetFocus" then return function(self) rawset(self, "_focus", true) end end
	if k == "HighlightText" then return function(self) rawset(self, "_hl", true) end end
	if k == "SetScript" or k == "HookScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k:match("^Create") then return function(self) return obj({ _shown = true }) end end
	return function() end
end
_G.CreateFrame = function() return obj({ _shown = true }) end
_G.UIParent = obj(); _G.UISpecialFrames = {}; _G.tinsert = table.insert
local timers = {}
_G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
local ctrl = false
_G.IsControlKeyDown = function() return ctrl end
local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local made = {}
local C = setmetatable({}, { __index = function() return { 0.5, 0.5, 0.5 } end })
local api = { themeKit = { C = C, create = function() return obj({ _shown = true }), true end, solid = function() return obj() end,
	gradient = function() end, border = function() end,
	makeButton = function(_, label, _, onClick) local b = obj({ _shown = true, label = label, _OnClick = onClick }); made[label] = b; return b end } }
assert(loadfile(A .. "/Tracker/DebugWindow.lua"))("x", { tracker = { api = api } })
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local up = function(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i); if not n then return end; if n == want then return v end; i = i + 1 end end
api.showDebugWindow({ "enabled=true step=40", "|cffff0000red|r line" })
local frame, box = up(api.showDebugWindow, "frame"), up(api.showDebugWindow, "box")
check("window shown with the lines as plain text", frame._shown and box._text == "enabled=true step=40\nred line")
check("button named Copy all and close", made["Copy all and close"] ~= nil)
check("nothing goes to chat", #chat == 0)
made["Copy all and close"]._OnClick()
check("button selects all", box._focus and box._hl)
box._OnKeyDown(box, "C"); for _, f in ipairs(timers) do f() end
check("C without Ctrl does not close", frame._shown)
ctrl = true; box._OnKeyDown(box, "C"); for _, f in ipairs(timers) do f() end
check("Ctrl+C closes it", frame._shown == false and chat[#chat]:find("copied", 1, true) ~= nil)
api.showDebugWindow({ "again" }); ctrl = true; timers = {}
box._OnKeyDown(box, "C"); for _, f in ipairs(timers) do f() end
check("Ctrl+C without the button leaves it open", frame._shown == true)
box._OnTextChanged(box, true); check("typing is undone", box._text == "again")
local core = io.open(A .. "/Tracker/Core.lua"):read("*a")
check("/qt focus removed", not core:find('"focus"', 1, true) and not core:find("GetMouseFoci", 1, true))
check("debug not in /qt help", not core:find('{ "debug"', 1, true))
check("debug goes to the window", core:find("ns.api.showDebugWindow(lines)", 1, true) ~= nil)
local toc = io.open(A .. "/RXPForeverTracker.toc"):read("*a")
check("in the toc after Config.lua", toc:find("Tracker/Config.lua\nTracker/DebugWindow.lua", 1, true) ~= nil)
print(pass and "ALL OK" or "SOME FAILED")
