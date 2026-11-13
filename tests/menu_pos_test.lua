local dir = arg[1]
_G.CLOSE = "Close"
local function geo(l, t, w, h) return { l = l, t = t, w = w, h = h, shown = true, points = {},
	GetLeft = function(s) return s.l end, GetRight = function(s) return s.l + s.w end, GetTop = function(s) return s.t end,
	GetWidth = function(s) return s.w end, GetEffectiveScale = function() return 0.73 end, IsVisible = function() return true end,
	IsShown = function(s) return s.shown end, GetParent = function(s) return s.parent end,
	ClearAllPoints = function(s) s.points = {} end, SetPoint = function(s, ...) s.points[#s.points + 1] = { ... } end } end
_G.UIParent = geo(0, 1052, 1920, 1052)
_G.UIParent.GetEffectiveScale = function() return 0.73 end
_G.CreateFrame = function() return { Hide = function() end } end
local hooks = {}
_G.hooksecurefunc = function(a, b, c) if type(a) == "string" then hooks[a] = b else hooks[b] = c end end
_G.ToggleDropDownMenu = function() end
_G.LibStub = nil
local shownArgs
local RXP = { locale = { Get = function(t) return t end }, currentGuide = { name = "A" },
	RXPFrame = { GenerateMenuTable = function(_, m) m[1] = { text = "G", hasArrow = true, menuList = { { text = "A" } } }; m[2] = { text = "", isTitle = 1 }; return m end },
	guideList = {}, GetGuideName = function(g) return g.name end, IsGuideActive = function() return true end,
	ShowMenu = function(_, menu, frame, anchor, x, y) shownArgs = { frame = frame, anchor = anchor, x = x, y = y } end, CloseMenu = function() end }
local function run(trackerLeft, anchorArg)
	local module = geo(trackerLeft, 800, 260, 300)
	local ns = { rxp = RXP, view = { module = module } }
	assert(loadfile(dir .. "/Objectives/features/GuideMenu.lua"))("x", { objectives = ns })
	shownArgs = nil
	ns.showGuideMenu(anchorArg == "cursor" and "cursor" or module)
	return shownArgs, ns, module
end
local a = run(1620)
print("tracker on right:", a.frame and a.frame.point, "->", a.frame and a.frame.relativePoint, "x", a.x)
local b = run(40)
print("tracker on left: ", b.frame and b.frame.point, "->", b.frame and b.frame.relativePoint, "x", b.x)
local c = run(1620, "cursor")
print("welcome screen:  ", c.frame == nil and "cursor (RestedXP default)" or "anchored")
-- submenu flip: menu open on the left of a right-side tracker
local d, ns = run(1620)
_G.UIDROPDOWNMENU_OPEN_MENU = d.frame
local parent = geo(1400, 800, 200, 300); local sub = geo(1600, 790, 220, 200)
local button = geo(1410, 780, 180, 16); button.parent = parent
_G.DropDownList1, _G.DropDownList2 = parent, sub
hooks.ToggleDropDownMenu(2, nil, nil, nil, nil, nil, nil, button)
local p = sub.points[1]
print("submenu anchored:", p and p[1], "to parent", p and p[3], "x", p and p[4], "y", p and p[5])
