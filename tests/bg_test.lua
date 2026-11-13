-- the background rectangle for a few paddings (UIParent units): left edge from the headers, bottom from the list end
local src = io.open(arg[1] .. "/Tracker/Core.lua"):read("a")
local body = src:match("(local background\nlocal function updateBackground%(%).-\nend\n)")
assert(body)
local rect
local function frameStub()
	local f = {}
	setmetatable(f, { __index = function(_, k)
		if k == "SetPoint" then return function(_, _, _, _, x, y) rect = rect or {}; rect.left, rect.top = x, y end end
		if k == "SetSize" then return function(_, w, h) rect.w, rect.h = w, h end end
		if k == "CreateTexture" then return function() return frameStub() end end
		return function() end
	end })
	return f
end
local db = { enabled = true, background = true, backgroundColor = { 0, 0, 0, 0.4 } }
local env = setmetatable({ withAlpha = function(f) return f end,
	db = db, ns = { api = { zoneLabelsLeft = function() return 124 end } },
	viewport = { GetBottom = function() return 200 end, GetFrameLevel = function() return 5 end },
	ghost = { GetTop = function() return 800 end, GetLeft = function() return 100 end, GetRight = function() return 400 end },
	tracker = { IsShown = function() return true end, GetFrameStrata = function() return "LOW" end, bottomModulePadding = 0 },
	contentBottom = function() return 500 end, scale = function() return 1 end,
	CreateFrame = function() return frameStub() end,
}, { __index = _G })
local update = load(body .. "\nreturn updateBackground", "x", "t", env)()
for _, pad in ipairs({ 0, 6, 20 }) do
	db.backgroundPad = pad
	rect = nil
	update()
	print(("pad %2d: left %d, right %d, top %d, bottom %d"):format(pad, rect.left, rect.left + rect.w, rect.top, rect.top - rect.h))
	assert(rect.left == 122 - pad and rect.top - rect.h == 500 - pad and rect.top == 800 + pad and rect.left + rect.w == 400 + pad)
end
print("OK: the space grows on all four sides")
