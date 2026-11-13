-- 3.5.66: /rt why opens a window in the settings window's look, in plain words
local A = arg[1]
local MT = {}
local function obj(t) return setmetatable(t or {}, MT) end
MT.__index = function(t, k)
	if k == "GetStringHeight" then return function() return 12 end end
	if k == "GetWidth" then return function() return 540 end end
	if k == "GetHeight" then return function() return 380 end end
	if k == "GetVerticalScroll" then return function() return 0 end end
	if k == "GetFrameLevel" then return function() return 5 end end
	if k == "IsShown" then return function(self) return rawget(self, "_shown") == true end end
	if k == "Show" then return function(self) rawset(self, "_shown", true); local f = rawget(self, "_OnShow"); if f then f(self) end end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "SetTextColor" then return function(self, r, g, b) rawset(self, "_color", { r, g, b }) end end
	if k == "SetScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k == "HookScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k:match("^Create") then return function(self) local o = obj({ _parent = self }); rawset(o, "_shown", true) return o end end
	return function() end
end
_G.CreateFrame = function() return obj({ _shown = true }) end
_G.UIParent = obj()
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.UnitLevel = function() return 45 end
local made = {}
local C = setmetatable({}, { __index = function() return { 0.5, 0.5, 0.5 } end })
local themeKit = { C = C, create = function() return obj({ _shown = true }), true end, solid = function() return obj() end,
	gradient = function() end, border = function() end,
	makeButton = function(_, label, _, onClick) local b = obj({ _shown = true, label = label, _OnClick = onClick }); made[label] = b; return b end }
local moves = {
	{ time = "17:40:01", kind = "load", guide = "41-41 Swamp of Sorrows", detail = "41-41 Swamp of Sorrows", byUs = true },
	{ time = "17:40:02", kind = "step", guide = "41-41 Swamp of Sorrows", step = 1, now = 9, byUs = false,
		flags = { "RestedXP already counted it as done" }, objectives = { "level check (done)" } },
}
local ns = { rxp = {},
	whySummary = function() return { guide = "41-41 Swamp of Sorrows", step = 9, total = 120, level = 45, skipOver = true,
		autoSkip = false, skipped = { { "you are past its level", 3 } } } end,
	whyMoves = function() return moves end,
	describeMove = function(m)
		if m.kind == "load" then return "Opened the guide " .. m.detail, "by you, with the tracker's buttons" end
		return "Passed step 1 on the way to step 9", "Why: RestedXP already counted it as done"
	end,
	whyText = function() return "TEXT FOR A BUG REPORT" end, clearMoves = function() moves = {} end }
assert(loadfile(A .. "/Objectives/features/WhyWindow.lua"))("x", { objectives = ns, tracker = { api = { themeKit = themeKit } } })
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local ok, err = pcall(ns.showWhyWindow)
check("the window opens: " .. tostring(err), ok)
local up = function(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i); if not n then return end; if n == want then return v end; i = i + 1 end end
local render = up(ns.whyChanged, "render")
local lines = up(render, "lines")
local all = {}
for _, fs in ipairs(lines or {}) do if rawget(fs, "_shown") ~= false and rawget(fs, "_text") then all[#all + 1] = fs._text end end
local text = table.concat(all, "\n")
print("     " .. text:gsub("\n", " | "))
check("where you are", text:find("41-41 Swamp of Sorrows", 1, true) and text:find("step 9 of 120", 1, true))
check("both skip settings in words", text:find("Skip overleveled steps:", 1, true) and text:find("Step skips:", 1, true))
check("what was skipped, counted", text:find("3 steps: you are past its level", 1, true))
check("moves newest first, in sentences", text:find("Passed step 1", 1, true) < text:find("Opened the guide", 1, true))
check("settings explained either way (on: skipped, off: kept)", text:find("are skipped by themselves", 1, true) and text:find("are kept", 1, true))
local copy = made["Copy for a bug report"]
copy._OnClick(copy)
local box = up(render, "content") and up(up(ns.showWhyWindow, "build"), "copyBox") or nil
box = box or up(ns.whyChanged, "copyBox")
check("Copy shows the plain text to copy", box and box._text == "TEXT FOR A BUG REPORT")
print(pass and "PASS" or "FAILED")
