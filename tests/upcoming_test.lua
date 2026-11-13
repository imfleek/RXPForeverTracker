-- Forever Style (3.1.0): Rows.lua layout in both themes and the step buttons in SkipBox.lua, with fake Blizzard frames.
local dir = arg[1]
local MT = {}
local function obj(t) return setmetatable(t or {}, MT) end
MT.__index = function(t, k)
	if k == "Info" or k == "Slots" or k == "Box" or k == "dividerGap" or k == "MinimizeButton" and false then return nil end
	if k == "GetFont" then return function() return "font", 12, "" end end
	if k == "GetStringHeight" then return function() return 12 end end
	if k == "GetStringWidth" then return function() return 40 end end
	if k == "GetHeight" then return function(self) return rawget(self, "_h") or 25 end end
	if k == "SetHeight" then return function(self, h) rawset(self, "_h", h) end end
	if k == "GetWidth" then return function() return 240 end end
	if k == "GetSize" then return function() return 16, 16 end end
	if k == "GetFrameLevel" then return function() return 5 end end
	if k == "GetNumPoints" then return function(self) local p = rawget(self, "_points"); return p and #p or 1 end end
	if k == "GetPoint" then return function(self, i)
		local p = rawget(self, "_points")
		if p and p[i or 1] then return table.unpack(p[i or 1]) end
		return "TOPLEFT", rawget(self, "_parent"), "TOPLEFT", 0, 0
	end end
	if k == "SetPoint" then return function(self, point, rel, relPoint, x, y)
		local p = rawget(self, "_points") or {}
		rawset(self, "_points", p)
		for _, q in ipairs(p) do if q[1] == point then q[2], q[3], q[4], q[5] = rel, relPoint, x, y return end end
		p[#p + 1] = { point, rel, relPoint, x, y }
	end end
	if k == "ClearAllPoints" then return function(self) rawset(self, "_points", nil) end end
	if k == "SetScale" then return function(self, v) rawset(self, "_scale", v) end end
	if k == "GetScale" then return function(self) return rawget(self, "_scale") or 1 end end
	if k == "SetWidth" then return function(self, v) rawset(self, "_w", v) end end
	if k == "GetRegions" then return function(self) return table.unpack(rawget(self, "_regions") or {}) end end
	if k == "GetObjectType" then return function() return "Texture" end end
	if k == "IsShown" then return function(self) return rawget(self, "_shown") ~= false end end
	if k == "Show" then return function(self) rawset(self, "_shown", true) end end
	if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
	if k == "SetShown" then return function(self, v) rawset(self, "_shown", not not v) end end
	if k == "GetAtlas" then return function() return "ui-questtracker-tracker-collapse" end end
	if k == "GetTexCoord" then return function() return 0, 1, 0, 1 end end
	if k == "GetVertexColor" or k == "GetTextColor" then return function() return 1, 1, 1, 1 end end
	if k == "GetBlendMode" then return function() return "BLEND" end end
	if k == "GetAlpha" then return function() return 1 end end
	if k == "GetDrawLayer" then return function() return "BACKGROUND", 0 end end
	if k == "CreateTexture" then
		return function(self, name, layer, template, sublevel)
			if template ~= nil then error('Frame:CreateTexture(): Couldn\'t find inherited node "' .. tostring(template) .. '"') end
			return obj({ _parent = self })
		end
	end
	if k == "IsMouseOver" or k == "IsCollapsed" or k == "GetAtlasInfo" then return function() return false end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "SetScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k:match("^Get%a+Texture$") then
		return function(self) local key = "_" .. k; local v = rawget(self, key) or obj(); rawset(self, key, v); return v end
	end
	if k:match("^Create") then return function(self) return obj({ _parent = self }) end end
	return function() end
end
_G.CreateFrame = function(_, _, parent) return obj({ _parent = parent }) end
_G.C_Texture = { GetAtlasInfo = function(name) return name:find("expand") and {} or nil end }
_G.PixelUtil = { ConvertPixelsToUIForRegion = function(v) return v end }
_G.OBJECTIVE_TRACKER_COLOR = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
_G.ObjectiveTrackerModuleMixin = { lineSpacing = 2 }
_G.QUEST_DASH = "- "
_G.OBJECTIVE_DASH_STYLE_SHOW, _G.OBJECTIVE_DASH_STYLE_HIDE = 1, 2
_G.GameTooltip = obj()
_G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
_G.PlaySound = function() end
_G.UnitLevel = function() return 10 end
_G.GetTime = function() return 100 end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.Mixin = function(t) return t end

local function pool()
	local p = { active = {} }
	function p:Acquire()
		local f = obj({ usedLines = {}, Text = obj(), Dash = obj(), HeaderText = obj() })
		f.headers, f.objectives, f.height = {}, {}, 20
		function f:SetHeader(text) self.header = text end
		function f:AddObjective(key, text, _, _, dash) self.objectives[key] = { text = text, dash = dash } end
		self.active[#self.active + 1] = f
		return f, true
	end
	function p:ReleaseAll() self.active = {} end
	function p:Release() end
	function p:EnumerateActive() return pairs({}) end
	return p
end
_G.CreateFramePool = function() return pool() end

local db = { theme = "forever", upcomingCollapsed = false, upcomingShown = 2, upcomingScrollbar = true, upcomingScrollbarColor = { 0.2, 0.85, 0.55, 0.85 } }
local skipCalls = {}
local progress, setCalls = 73, {}
local RXP = { currentGuide = { steps = {} }, GetGuideProgress = function() return progress end,
	IsSecretValue = function() return false end, SetStep = function(n) setCalls[#setCalls + 1] = n; progress = n end,
	v2 = { GetTheme = function() return { edge = 1, backgroundColors = {}, borderColors = {} } end },
	ui = { v2 = { ApplyFrameBackdrop = function() end, SetFrameBackdropShown = function() end } } }
for i = 1, 100 do RXP.currentGuide.steps[i] = { index = i } end
local view = { rows = {}, shown = 0 }
local relayouts = 0
local ns = { rxp = RXP, db = db, view = view, say = print, releaseTooltip = function() end,
	forever = function() return db.theme == "forever" end, relayout = function() relayouts = relayouts + 1 end }
local root = { objectives = ns }
-- 3.5.8 compat helpers (Objectives/Core.lua), as the game would have them
ns.isSecret = ns.isSecret or function() return false end
ns.itemCooldown = ns.itemCooldown or function(item) return RXP.GetItemCooldown and RXP.GetItemCooldown(item) end
ns.isPlayerSpell = ns.isPlayerSpell or function(id) return RXP.IsPlayerSpell and RXP.IsPlayerSpell(id) end
ns.L = ns.L or function(t) return t end
ns.texture = ns.texture or function(n) return RXP.GetV1Texture and RXP.GetV1Texture(n) or 134400 end
ns.playerClass = ns.playerClass or function() return RXP.player and RXP.player.class or "MAGE" end
ns.guideFontSize = ns.guideFontSize or function() return RXP.settings and RXP.settings.profile and RXP.settings.profile.guideFontSize or 12 end
ns.rxpProfile = ns.rxpProfile or function() return RXP.settings and RXP.settings.profile or {} end
ns.rxpRelease = ns.rxpRelease or function() return tostring(RXP.release or "") end
ns.hookRxp = ns.hookRxp or function(t, n, f) if type(t) == "table" and type(t[n]) == "function" and hooksecurefunc then hooksecurefunc(t, n, f) end end
ns.guard = ns.guard or function(fn, ...) return pcall(fn, ...) end
assert(loadfile(dir .. "/Objectives/tracker/SkipBox.lua"))("x", root)
local realSkip = ns.setSkipBox
ns.setSkipBox = function(line, objective, active) skipCalls[#skipCalls + 1] = active end
local backHidden = 0
ns.hideBackButton = function() backHidden = backHidden + 1 end
ns.placeBackButton = function() skipCalls.back = true end
ns.backButtonRoom = function() return 0 end
assert(loadfile(dir .. "/Objectives/tracker/Rows.lua"))("x", root)

local headerText = obj()
local module = obj({ ContentsFrame = obj(), blockOffsetX = 20, fromBlockOffsetY = -10, lineTemplate = "T",
	Header = obj({ Text = headerText, MinimizeButton = obj(), _regions = { obj({}) } }) })
-- as Blizzard's (Blizzard_ObjectiveTrackerModule.lua, forever 4cd0ab7): TOP to the last block at fromBlockOffsetY,
-- LEFT at block.offsetX or blockOffsetX; contentsHeight grows by height - offsetY
function module:AnchorBlock(block)
	if type(rawget(block, "height")) ~= "number" then rawset(block, "height", 25) end
	block:ClearAllPoints()
	local last = rawget(self, "lastBlock")
	local offsetY = last and self.fromBlockOffsetY or 0
	block:SetPoint("TOP", last or self.ContentsFrame, last and "BOTTOM" or "TOP", 0, offsetY)
	block:SetPoint("LEFT", rawget(block, "offsetX") or self.blockOffsetX, 0)
	return offsetY
end
function module:LayoutBlock(block)
	local offsetY = self:AnchorBlock(block)
	self.lastBlock = block
	local h = rawget(block, "height"); if type(h) ~= "number" then h = 25; rawset(block, "height", h) end
	self.contentsHeight = (rawget(self, "contentsHeight") or 0) + h - (offsetY or 0)
	rawset(self, "_raw", (rawget(self, "_raw") or 0) + h - (offsetY or 0)) -- what Blizzard alone would count
	return true
end
local entries = { { number = "73", active = true, lines = { { text = "Talk to Jarrodenus" } } } }
for n = 74, 80 do entries[#entries + 1] = { number = tostring(n), active = false, lines = { { text = "Step " .. n } } } end
ns.attachRows(module, function() return entries end)


local trackerWheels = {}
root.tracker = { api = { trackerWheel = function(d) trackerWheels[#trackerWheels + 1] = d end } }
ns.relayout = function() module:LayoutContents() end
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local function shownSteps()
	local out = {}
	for i = 1, view.shown do out[i] = view.rows[i].header end
	return table.concat(out, ", ")
end
module:LayoutContents()
print("     shown: " .. shownSteps())
check("current step plus 2 upcoming (of 7)", view.shown == 3 and view.rows[2].header == "Step 74" and view.rows[3].header == "Step 75")
-- 3.5.52: the current step has a "mark done" check; it ticks off its open objectives
do
	local cur = view.rows[1]
	check("the current step has a done check, upcoming steps do not", rawget(cur, "Done") and cur.Done.step == 73
		and not rawget(view.rows[2], "Done"))
	check("the check is two outlined strokes", #cur.Done.outer == 2 and #cur.Done.inner == 2)
	local function innerColor() return cur.Done.inner[1]._vertex or cur.Done.inner[1].vertex end
	local enterFn, leaveFn = rawget(cur.Done, "_OnEnter"), rawget(cur.Done, "_OnLeave")
	check("it reacts to the mouse", enterFn ~= nil and leaveFn ~= nil)
	local e1, e2 = { tag = "accept" }, { tag = "goto", textOnly = true }
	RXP.currentGuide = RXP.currentGuide or {}
	local keepSteps = RXP.currentGuide.steps
	RXP.currentGuide.steps = { [73] = { elements = { e1, e2 } } }
	RXP.updateSteps = false
	ns.markStepDone(73)
	check("marking it done skips its open objectives and asks RestedXP to check the step", e1.skip and not e2.skip and RXP.updateSteps)
	-- 3.5.68: the step you are on moves on to the next one at once
	local setTo
	local keepSet, keepProgress = RXP.SetStep, RXP.GetGuideProgress
	RXP.SetStep = function(n) setTo = n end
	RXP.GetGuideProgress = function() return 73 end
	e1.skip = nil
	ns.markStepDone(73)
	check("the step you are on goes to the next step at once", setTo == 74)
	RXP.SetStep, RXP.GetGuideProgress = keepSet, keepProgress
	RXP.currentGuide.steps = keepSteps
end
-- 3.5.51: Shift+right-click an upcoming step makes it the current step
do
	local went
	local keep = ns.goToStep
	ns.goToStep = function(n) went = n end
	_G.IsShiftKeyDown = function() return true end
	local up = view.rows[2]
check("an upcoming row knows its step", up.rxpUpcomingStep == 74 and rawget(view.rows[1], "rxpUpcomingStep") == nil)
	up:OnHeaderClick("LeftButton")
	check("Shift+left-click does not", went == nil)
	up:OnHeaderClick("RightButton")
	check("Shift+right-click on its heading goes to that step", went == 74)
	went = nil
	_G.IsShiftKeyDown = function() return false end
	up:OnHeaderClick("RightButton")
	check("a plain right-click does not", went == nil)
	_G.IsShiftKeyDown = function() return true end
	view.rows[1]:OnHeaderClick("RightButton")
	check("nor does the current step", went == nil)
	_G.IsShiftKeyDown = function() return false end
	ns.goToStep = keep
end
local wheel = view.rows[2]._OnMouseWheel
check("upcoming rows take the wheel, the current step does not", wheel ~= nil and rawget(view.rows[1], "_OnMouseWheel") == nil)
wheel(view.rows[2], -1)
print("     after wheel down: " .. shownSteps())
check("wheel down shows 75 and 76", view.rows[2].header == "Step 75" and view.rows[3].header == "Step 76")
for _ = 1, 10 do view.rows[2]._OnMouseWheel(view.rows[2], -1) end
check("stops at the last two (79, 80)", view.rows[2].header == "Step 79" and view.rows[3].header == "Step 80")
check("at the end the wheel scrolls the tracker", #trackerWheels > 0 and trackerWheels[1] == -1)
local function upv(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i); if not n then return end; if n == want then return v end; i = i + 1 end end
local up = upv(upv(module.LayoutContents, "placeUpBar"), "upBar")
check("scrollbar shown while there is more to scroll", up and up._shown)
check("no per-frame script without Only on mouseover", rawget(up, "_OnUpdate") == nil)
db.upcomingScrollbarMouseover = true
module:LayoutContents()
check("a hover check with Only on mouseover", rawget(up, "_OnUpdate") ~= nil)
db.upcomingScrollbarMouseover = false
module:LayoutContents()
check("and gone again when it is turned off", rawget(up, "_OnUpdate") == nil)
-- the steps move on: back to the top
entries[2], entries[3] = entries[3], entries[2]
entries[2].number = "90"
module:LayoutContents()
check("new steps ahead: the window starts at the top again", view.rows[2].header == "Step 90")
db.upcomingShown = 10
module:LayoutContents()
check("all fit: no scrollbar", up._shown == false and view.shown == 8)
-- 3.5.25: scale and position of the current step and of the upcoming steps
db.upcomingShown = 2
local function run()
	rawset(module, "lastBlock", nil); module.contentsHeight = 0; rawset(module, "_raw", 0)
	module:LayoutContents()
	return module.contentsHeight
end
local plain = run()
local plainRows = {}
for i = 1, view.shown do plainRows[i] = view.rows[i].height end
db.currentScale, db.currentX, db.currentY = 1.5, 10, 6
db.upcomingScale, db.upcomingX, db.upcomingY = 0.8, -5, -4
local moved = run()
local cur, up1, up2 = view.rows[1], view.rows[2], view.rows[3]
local function point(row, name) for _, q in ipairs(rawget(row, "_points") or {}) do if q[1] == name then return q end end end
check("current step scaled 150 %, upcoming 80 %", cur._scale == 1.5 and up1._scale == 0.8 and up2._scale == 0.8)
check("current step moved 10 px right (left offset (20 + 10) / 1.5)", math.abs(cur.offsetX - 20) < 1e-6 and cur.fixedWidth)
check("upcoming moved 5 px left ((20 - 5) / 0.8)", math.abs(up1.offsetX - 18.75) < 1e-6)
check("width kept on screen: (240 - 20) / scale", math.abs(cur._w - 220 / 1.5) < 1e-6 and math.abs(up1._w - 220 / 0.8) < 1e-6)
check("current step 6 px up (top offset (0 + 6) / 1.5)", math.abs(point(cur, "TOP")[5] - 4) < 1e-6)
check("first upcoming 4 px down ((-10 - 4) / 0.8), the next only its scaled gap", math.abs(point(up1, "TOP")[5] - (-17.5)) < 1e-6
	and math.abs(point(up2, "TOP")[5] - (-12.5)) < 1e-6)
local h1, h2, h3 = rawget(cur, "height"), rawget(up1, "height"), rawget(up2, "height")
local want = rawget(module, "_raw") + h1 * 0.5 - 6 + h2 * -0.2 + 4 + h3 * -0.2
print(("     contents height: unscaled %.2f, with the looks %.2f, expected %.2f"):format(rawget(module, "_raw"), moved, want))
check("the module's height follows the scaled rows and the moves", math.abs(moved - want) < 1e-6)
db.currentScale, db.currentX, db.currentY, db.upcomingScale, db.upcomingX, db.upcomingY = 1, 0, 0, 1, 0, 0
run()
check("back to 1 / 0: rows as before (no fixed width, no offset)", rawget(view.rows[1], "offsetX") == nil
	and not rawget(view.rows[1], "fixedWidth") and view.rows[1]:GetScale() == 1)
-- 3.5.29: a "click here to copy the link" step opens a copy box with its address; links get their tooltip
local shownPopup
_G.StaticPopup_Show = function(which, a, b, data) shownPopup = { which = which, data = data }; return nil end
_G.InCombatLockdown = function() return false end
entries[1].lines[1].element = { url = "https://example.com/guide" }
run()
local line = view.rows[1].usedLines[1]
check("the step's line knows its link", line.rxpElement and line.rxpElement.url == "https://example.com/guide")
local addLine = upv(upv(module.LayoutContents, "layoutRow"), "addLine")
_G.IsModifiedClick = function() return false end
_G.SetItemRef = function() end
local linkClickFn, enter = upv(addLine, "linkClick"), upv(addLine, "linkEnter")
-- our whole-line links ("rxpft:") carry the line's action
local function click(l, b) linkClickFn(l, "rxpft:line", "", b) end
click(line, "RightButton")
check("a right-click does not open the copy box (it goes on to the step)", shownPopup == nil)
click(line, "LeftButton")
check("a left-click opens the copy box with the link", shownPopup and shownPopup.which == "RXPFOREVERTRACKER_COPY_LINK"
	and shownPopup.data == "https://example.com/guide")
local tip = {}
_G.GameTooltip = setmetatable({ IsShown = function() return false end, GetOwner = function() return nil end,
	SetOwner = function(_, o) tip.owner = o end, SetHyperlink = function(_, l) tip.link = l end, Show = function() tip.shown = true end,
	SetText = function() end, Hide = function() end }, { __index = function() return function() end end })
enter(line, "item:6948", "[Hearthstone]")
check("an item link in a step shows its tooltip", tip.link == "item:6948" and tip.shown and tip.owner == line)
-- 3.5.30: .clicknext starts its guide; missing prerequisites and a level skip show RestedXP's notes
local function lineEnter(l) enter(l, "rxpft:line") end
local loaded
ns.rxp = { GetGuideTable = function(g, n) return { group = g, name = n } end,
	LoadGuide = function(_, guide) loaded = guide end, icons = { error = "ERR" } }
ns.say = function() end
local fake = {}
local function hover(element)
	fake = { lines = {} }
	_G.GameTooltip = setmetatable({ IsShown = function() return false end, GetOwner = function() return nil end,
		SetOwner = function() end, SetText = function(_, t) fake.lines[#fake.lines + 1] = t end,
		AddLine = function(_, t) fake.lines[#fake.lines + 1] = t end, Show = function() fake.shown = true end, Hide = function() end },
		{ __index = function() return function() end end })
	local l = { rxpElement = element }
	lineEnter(l)
	return table.concat(fake.lines, " | "), l
end
local text, l = hover({ next = "RestedXP Forever Guide (H)\\1-9 Zephras Isle" })
check("clicknext: the tooltip says what a click starts (" .. text .. ")", text:find("Click to start 1%-9 Zephras Isle") ~= nil)
click(l, "LeftButton")
check("and a click loads that guide", loaded and loaded.name == "1-9 Zephras Isle" and loaded.group == "RestedXP Forever Guide (H)")
local toggled = 0
root.tracker.api.togglePrereqs = function() toggled = toggled + 1 end
text, l = hover({ tooltip = "Missing pre-requisites:\nQuest A (12)", icon = "ERR" })
check("missing prerequisites listed on hover, with the journal hint", text:find("Quest A") and text:find("Prerequisite Journal"))
click(l, "LeftButton")
check("a click opens the Prerequisite Journal", toggled == 1)
text = hover({ step = { tooltipText = "Step skipped: XP requirements are not met" } })
check("a step skipped by level says so, in our wording (" .. text .. ")", text == "Steps skipped: XP requirements are exceeded")
text = hover({ tooltip = 1234 })
check("RestedXP's debug ids (numbers) are not shown", not fake.shown)
-- 3.5.33: the RXP Tracker's collapse button folds the current step only; the upcoming steps stay
db.upcomingShown = 2
local doneBefore = rawget(view.rows[1], "Done")
-- the game's pool hands a released row out again: the current step's row comes back first, as the spacer
do
	local rp = upv(module.LayoutContents, "rowPool") or upv(upv(module.LayoutContents, "beginRow"), "rowPool")
	local again, old = view.rows[1], rp and rp.Acquire
	if rp then rp.Acquire = function(self) if again then local r = again; again = nil; return r, false end return old(self) end end
end
module:ToggleCollapsed()
check("collapse button: current steps folded", db.currentCollapsed == true)
-- 3.5.80: the current step's "mark done" check goes with it
check("the mark-done check is hidden while the current steps are folded", doneBefore and rawget(doneBefore, "_shown") == false)
local names = {}
for i = 1, view.shown do names[#names + 1] = view.rows[i].header end
print("     folded shows: " .. table.concat(names, ", "))
check("the upcoming steps still show, the current step does not", view.shown == 2 and view.rows[1].header ~= nil
	and not tostring(view.rows[1].header):find("73"))
module:ToggleCollapsed()
check("unfolded: current step back first", db.currentCollapsed == false and view.rows[1].header ~= nil and view.shown == 3)
-- 3.5.34: RestedXP writes items as plain text; the step's own items become item links, quests quest links
local decorate = upv(addLine, "decorate")
_G.C_Item = { GetItemNameByID = function(id) return ({ [5310] = "Gnarlpine Necklace", [6948] = "Hearthstone" })[id] end,
	GetItemInfoInstant = function(name) return ({ Hearthstone = 6948, ["Superior Healing Potion"] = 3928 })[name] end }
local step = { elements = { { tag = "collect", id = 5310 }, { tag = "accept", questId = 920, title = "Tenaron's Summons" } } }
for _, e in ipairs(step.elements) do e.step = step end
local out = decorate("Loot him for the |T133288:0|t[|cffe6cc80Gnarlpine Necklace|r]. Beware [Thrash]", step.elements[1], {})
print("     " .. out)
check("the step's item and its icon become one item link (colour kept)", out:find("|Hitem:5310|h|T133288:0|t[|cffe6cc80Gnarlpine Necklace|r]|h", 1, true) ~= nil)
check("linked once only", select(2, out:gsub("|Hitem:", "")) == 1)
check("other bracketed names stay plain text", out:find("Beware [Thrash]", 1, true) ~= nil)
out = decorate("Use your [Hearthstone]", { step = { elements = {} } }, {})
check("an item the game knows by name links even when the step lists no id", out == "Use your |Hitem:6948|h[Hearthstone]|h")
local upcomingLine = decorate("|T1:0|t[|cffe6cc80Gnarlpine Necklace|r]", { step = step, upcoming = true }, {})
check("upcoming steps link their items too", upcomingLine:find("|Hitem:5310|h", 1, true) ~= nil)
out = decorate("Accept Tenaron's Summons", step.elements[2], {})
check("an accept step's quest name becomes a quest link", out == "Accept |Hquest:920|hTenaron's Summons|h")
out = decorate("Click here to copy the link", { url = "https://x" }, { rxpElement = { url = "https://x" } })
check("a copy-link line is wrapped whole in our link", out == "|Hrxpft:line|hClick here to copy the link|h")
out = decorate("Plain text", { tag = "goto" }, { rxpElement = { tag = "goto" } })
check("a plain line is left alone", out == "Plain text")
-- 3.5.39: items the game has not loaded link by the icon in front of them; spells link; cast lines lead with one icon
_G.C_Item.GetItemIconByID = function(id) return ({ [5310] = 133288, [6948] = 134414, [4306] = 132905, [8391] = 133972,
	[8392] = 134343, [9619] = 133841, [11107] = 133653, [12284] = 133001 })[id] end
_G.C_Spell = { GetSpellName = function(id) return ({ [18960] = "Teleport: Moonglade", [11342] = "Ice Armor" })[id] end,
	GetSpellTexture = function(id) return ({ [18960] = 135758, [11342] = 135843 })[id] end }
local bank = { elements = { { tag = "bankwithdraw", items = { 4306, 8391, 8392 } }, { text = "x" }, { text = "y" } } }
for _, e in ipairs(bank.elements) do e.step = bank end
local lines = { "+|T132905:0|t[Silk Cloth]", "+|T133972:0|t[Snickerfang Jowl]", "+|T134343:0|t[Blasted Boar Lung]" }
local all = true
for i, text in ipairs(lines) do
	local o = decorate(text, bank.elements[math.min(i, 3)], {})
	if not o:find("|Hitem:" .. bank.elements[1].items[i] .. "|h", 1, true) then all = false; print("     " .. o) end
end
check("every withdrawn item links, loaded or not (by its icon)", all)
local use = { elements = { { tag = "use", activeItems = { [9619] = "" }, text = "Kill" }, { text = ">>Use" } } }
for _, e in ipairs(use.elements) do e.step = use end
out = decorate(">>Use the |T133841:0|t[Hippogryph Muisek Vessel] on their corpses", use.elements[2], {})
check("a .use item not yet loaded links on another line of its step", out:find("|Hitem:9619|h|T133841:0|t[Hippogryph Muisek Vessel]|h", 1, true) ~= nil)
local cast = { tag = "cast", ids = { 18960 }, icon = "|T135758:0|t" }
cast.step = { elements = { cast } }
out = decorate("|T135758:0|tCast |T135758:0|t[Teleport: Moonglade]", cast, {})
print("     " .. out)
check("a cast line starts with the general spell icon, once", out:find("^|TInterface/ICONS/INV_Misc_Book_09:0|t") ~= nil
	and select(2, out:gsub("135758", "")) == 1)
check("the cast spell becomes a spell link", out:find("|Hspell:18960|h|T135758:0|t[Teleport: Moonglade]|h", 1, true) ~= nil)
out = decorate("|T135758:0|tCast Teleport: Moonglade", cast, {})
check("a spell named without brackets links too", out:find("|Hspell:18960|hTeleport: Moonglade|h", 1, true) ~= nil)
local train = { tag = "train", id = 11342 }
train.step = { elements = { train } }
out = decorate("Train [Ice Armor]", train, {})
check("a trained spell links", out == "Train |Hspell:11342|h[Ice Armor]|h")
out = decorate("Buy |T134833:0|t[Superior Healing Potions] from him", { tag = "vendor", step = { elements = {} } }, {})
_G.C_Item.GetItemIconByID = (function(old) return function(id) if id == 1710 then return 134833 end return old(id) end end)(_G.C_Item.GetItemIconByID)
local gh = decorate("Buy |T134833:0|t[Greater Healing Potions] from him", { tag = "vendor", step = { elements = {} } }, {})
check("a common vendor item the game has not loaded links by its known id and icon", gh:find("|Hitem:1710|h", 1, true) ~= nil)
local wrong = decorate("Buy |T999:0|t[Greater Healing Potions] from him", { tag = "vendor", step = { elements = {} } }, {})
check("not when the icon is another item's", wrong:find("|H", 1, true) == nil)
_G.C_Item.GetItemIconByID = (function(old) return function(id) if id == 2725 then return 134332 end return old(id) end end)(_G.C_Item.GetItemIconByID)
local pages = decorate("Hold onto any |T134332:0|t[Green Hills of Stranglethorn - Pages] you find", { step = { elements = {} } }, {})
check("a book's \"Pages\" shows its first page", pages:find("|Hitem:2725|h", 1, true) ~= nil)
local pages2 = decorate("|T134332:0|t[Green Hills of Stranglethorn Pages]", { step = { elements = {} } }, {})
check("also written without the dash", pages2:find("|Hitem:2725|h", 1, true) ~= nil)
check("an item named in the plural links to the item", out:find("|Hitem:3928|h|T134833:0|t[Superior Healing Potions]|h", 1, true) ~= nil)
-- 3.5.52: an upcoming step links the quests its accept / turn-in objectives name; Shift+click puts a quest in chat
do
	local stepQ = { elements = { { tag = "accept", questId = 920, title = "Tenaron's Summons" },
		{ tag = "turnin", questId = 921, title = "Crown of the Earth" } } }
	local ref = { step = stepQ, upcoming = true }
	local up = decorate("Accept Tenaron's Summons\nTurn in Crown of the Earth", ref, {})
	check("an upcoming step links each quest it accepts or turns in", up:find("|Hquest:920|hTenaron's Summons|h", 1, true) ~= nil
		and up:find("|Hquest:921|hCrown of the Earth|h", 1, true) ~= nil)
	local withItem = decorate("Loot |T133288:0|t[Gnarlpine Necklace] for Tenaron's Summons", { tag = "accept", questId = 920,
		title = "Tenaron's Summons", step = { elements = { { tag = "collect", id = 5310 } } } }, {})
	check("a quest is linked beside an item link too", withItem:find("|Hitem:5310|h", 1, true) ~= nil
		and withItem:find("|Hquest:920|h", 1, true) ~= nil)
	local inserted
	_G.GetQuestLink = function(id) return "|cffffff00|Hquest:" .. id .. ":20|h[Q]|h|r" end
	_G.ChatEdit_InsertLink = function(l) inserted = l return true end
	_G.IsShiftKeyDown = function() return true end
	linkClickFn({}, "quest:920", "|Hquest:920|hTenaron's Summons|h", "RightButton")
	check("Shift+right-click on a quest name leaves it to the step (no chat link)", inserted == nil)
	linkClickFn({}, "quest:920", "|Hquest:920|hTenaron's Summons|h", "LeftButton")
	check("Shift+left-click on a quest name puts the game's quest link in chat", inserted == "|cffffff00|Hquest:920:20|h[Q]|h|r")
	_G.IsShiftKeyDown = function() return false end
end
-- 3.5.48: a line is decorated once, and again only when its text changes or item data arrives
local calls = 0
local oldName = _G.C_Item.GetItemNameByID
_G.C_Item.GetItemNameByID = function(id) calls = calls + 1 return oldName(id) end
local cacheEl = { tag = "collect", id = 5310 }
cacheEl.step = { elements = { cacheEl } }
local first = decorate("Loot [Gnarlpine Necklace]", cacheEl, {})
local before = calls
local second = decorate("Loot [Gnarlpine Necklace]", cacheEl, {})
check("the same line again is not worked out again", second == first and calls == before)
local third = decorate("Loot 2 [Gnarlpine Necklace]", cacheEl, {})
check("a changed text is", calls > before and third:find("|Hitem:5310|h", 1, true) ~= nil)
_G.C_Item.GetItemNameByID = oldName
print(pass and "PASS" or "FAILED")
