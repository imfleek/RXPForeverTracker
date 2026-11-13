-- 3.5.74: a finished quest gets a green tick on its own, left of the title (never moving it), with its own switch,
-- scale and opacity; title icons have an opacity
local src = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
local block = src:match("(local function applyIcon%(tex, desc%).-\napi.placeTitleIcons = placeTitleIcons)")
assert(block, "icon code not found")
local made = {}
local function tex()
	local t = { shown = false }
	function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
	function t:SetRotation(r) self.rotation = r end
	function t:SetSize(w, h) self.w, self.h = w, h end
	function t:SetAllPoints() end
	function t:SetPoint(...) self.point = { ... } end
	function t:ClearAllPoints() end
	function t:Show() self.shown = true end
	function t:Hide() self.shown = false end
	function t:SetTexture(f) self.file = f end
	function t:SetTexCoord() end
	function t:SetAlpha(a) self.alpha = a end
	function t:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
	return t
end
local function frame()
	local f = tex()
	function f:CreateTexture() local t = tex(); made[#made + 1] = t; return t end
	function f:SetFrameLevel() end
	function f:GetFrameLevel() return 1 end
	return f
end
local parent = frame()
local fs = { GetParent = function() return parent end, GetFont = function() return "f", 12, "" end }
local api = {}
local db = { iconScale = 1, completeCheck = true, completeCheckScale = 1, completeCheckAlpha = 1, iconAlpha = 0.5 }
local env = setmetatable({ api = api, db = db, iconSize = function() return 14 end, SLOT = 14, SLOT_GAP = 3,
	CreateFrame = function() return frame() end }, { __index = _G })
local place = load(block .. "\nreturn placeTitleIcons", "x", "t", env)()
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local skull = { file = "skull" }
local indent = place(fs, { skull }, 0)
api.placeCheck(fs, true)
local w = fs.qtsCheck
check("a finished quest gets a check", w and w.shown)
check("only a green tick: two strokes, no box or edge", #w.strokes == 2 and w.strokes[1].vertex[2] > 0.8
	and not w.outlines[1].shown)
check("on top of the Elite+ icon next to the title (same centre)", w.point[1] == "CENTER" and w.point[3] == "TOPLEFT"
	and w.point[4] == fs.qtsIcons[1].point[4])
check("a finished quest's icon fades to 87 % (Icon opacity 50 % stays lower)", fs.qtsIcons[1].alpha == 0.5)
check("the title makes no room: icons and check sit outside it", indent == "")
check("the Elite+ icon sits right next to the title, outside it", fs.qtsIcons[1].point[4] == -(2 + 7))
place(fs, { skull })
api.placeCheck(fs, false)
check("title icons use Icon opacity (50 %) when not finished", fs.qtsIcons[1].alpha == 0.5)
place(fs, {})
api.placeCheck(fs, true)
check("no icon: the check sits on its own left of the title", w.point[1] == "RIGHT" and w.point[4] == -2)
place(fs, { skull })
db.completeCheckScale, db.completeCheckAlpha = 2, 0.4
api.placeCheck(fs, true)
check("Check scale and Check opacity apply", w.w == 28 and w.alpha == 0.4)
db.completeCheckColor = { 1, 0.5, 0, 0.6 }
db.completeCheckOutline = true
api.placeCheck(fs, true)
check("Check colour and opacity apply", w.strokes[1].vertex[1] == 1 and w.strokes[2].vertex[2] == 0.5 and w.alpha == 0.6)
check("Outline the check: dark, slightly larger strokes behind", w.outlines[1].shown and w.outlines[1].color[1] == 0
	and w.outlines[1].w > w.strokes[1].w)
db.completeCheckOutline = false
api.placeCheck(fs, true)
check("outline off: hidden", not w.outlines[1].shown)
db.completeCheck = false
api.placeCheck(fs, true)
check("switched off: no check", not w.shown)
db.completeCheck = true
api.placeCheck(fs, false)
check("not finished: no check", not w.shown)
-- 3.5.78: Elite+ and a star: the star is placed further out (render puts it first), the check on the Elite+ icon
local star = { file = "star" }
db.completeCheck, db.completeCheckScale = true, 1
place(fs, { star, skull })
api.placeCheck(fs, true)
check("star further out, Elite+ icon next to the title", fs.qtsIcons[2].file == "skull" and fs.qtsIcons[2].point[4] > fs.qtsIcons[1].point[4])
check("the check sits on the Elite+ icon", w.point[4] == fs.qtsIcons[2].point[4])
local src2 = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
check("render puts the attunement star before the Elite+ icon", src2:find("if star then table.insert(slots, 1, star) end", 1, true) ~= nil)
print(pass and "PASS" or "FAILED")
