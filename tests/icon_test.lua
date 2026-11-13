local src = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
local block = src:match("(local function iconSize%(%).-\napi.hideTitleIcons = hideTitleIcons)")
assert(block, "block")
local db = { condense = true, iconScale = 1, attunementStar = true }
local api = { isAttunement = function() return true end }
local function fontString(parent)
	local fs = { parent = parent, font = { "Fonts\\FRIZQT__.TTF", 12, "" }, text = "" }
	function fs:GetFont() return self.font[1], self.font[2], self.font[3] end
	function fs:SetFont(a, b, c) self.font = { a, b, c } end
	function fs:SetText(t) self.text = t end
	function fs:GetStringWidth() return #self.text * 3 end
	function fs:GetParent() return self.parent end
	function fs:Hide() end
	return fs
end
local parent = {}
function parent:CreateTexture()
	local t = { shown = false }
	function t:SetTexture(f) self.file = f end
	function t:SetTexCoord() end
	function t:SetSize(w, h) self.w, self.h = w, h end
	function t:SetAlpha(a) self.alpha = a end
	function t:ClearAllPoints() end
	function t:SetPoint(p, rel, rp, x, y) self.pt = { p, rp, x, y } end
	function t:Show() self.shown = true end
	function t:Hide() self.shown = false end
	return t
end
local env = setmetatable({ db = db, api = api, UIParent = { CreateFontString = function() return fontString({}) end } }, { __index = _G })
local place = load(block .. "\nreturn placeTitleIcons, attunementIcon", "x", "t", env)
local placeTitleIcons, attunementIcon = place()
local fs = fontString(parent)
local skull = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" }
local results = {}
for _, scale in ipairs({ 0.5, 1, 2.5 }) do
	db.iconScale = scale
	local indent = placeTitleIcons(fs, { skull, attunementIcon(1) }, 0)
	local t1, t2 = fs.qtsIcons[1], fs.qtsIcons[2]
	results[#results + 1] = indent
	print(("scale %.1f: indent %d spaces, skull %dx%d at x=%.1f y=%.1f, star %dx%d at x=%.1f"):format(scale, #indent,
		t1.w, t1.h, t1.pt[3], t1.pt[4], t2.w, t2.h, t2.pt[3]))
end
assert(results[1] == results[2] and results[2] == results[3], "the text must not move with the icon size")
placeTitleIcons(fs, {}, 0)
assert(not fs.qtsIcons[1].shown and not fs.qtsIcons[2].shown)
print("OK: title text starts at the same place at every icon size; icons hidden when none")
