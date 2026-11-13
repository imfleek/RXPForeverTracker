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
	if k == "GetNumPoints" then return function() return 1 end end
	if k == "GetPoint" then return function(self) return "TOPLEFT", rawget(self, "_parent"), "TOPLEFT", 0, 0 end end
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

local db = { theme = "forever", upcomingCollapsed = false }
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
function module:AnchorBlock() end
function module:LayoutBlock() return true end
local entries = {
	{ number = "73", active = true, lines = { { text = "Talk to Jarrodenus" }, { text = "Fly to Teldrassil" } } },
	{ number = "74", active = false, lines = { { text = "Talk to Erelas Ambersky" } } },
	{ number = "75", active = false, lines = { { text = "Talk to Daryn Lightwind" } } },
}
ns.attachRows(module, function() return entries end)

local function upcomingFrame()
	local i = 1
	while true do
		local name, value = debug.getupvalue(module.LayoutContents, i)
		if not name then break end
		if name == "upcoming" then return value end
		i = i + 1
	end
end

local pass = true
local function check(label, cond) print((cond and "ok   " or "FAIL ") .. label); pass = pass and cond end

-- Forever Style, upcoming shown
module:LayoutContents()
local rows = view.rows
check("3 rows drawn", view.shown == 3)
check("heading Step 73", rows[1].header == "Step 73")
check("heading Step 74", rows[2].header == "Step 74")
check("first line no dash, second line dash", rows[1].objectives[1].dash == 2 and rows[1].objectives[2].dash == 1)
local anyBox = false
for _, v in ipairs(skipCalls) do if v then anyBox = true end end
check("no skip boxes in Forever Style", not anyBox and not skipCalls.back)
check("Forever Style hides the RXP back box", backHidden >= 1)
local up = upcomingFrame()
check("Upcoming Steps header built and shown", up and up._shown and up.Text._text == "Upcoming Steps")
check("info icon on upcoming row, none on current", rows[2].Info and rows[2].Info._shown and not (rows[1].Info and rows[1].Info._shown))
check("header sits below the current step (its height grows), not inside Step 74", rows[1].height == 20 + 33 and rows[2].dividerGap == nil)
check("bottom spacing normal", module.bottomSpacing == -4)
-- info click jumps to the step
-- i: quest in the log -> quest log; else the step's location -> map pin; Shift -> go to the step
local opened, pinned, shift = nil, nil, false
_G.IsShiftKeyDown = function() return shift end
_G.QuestMapFrame_OpenToQuestDetails = function(id) opened = id end
_G.C_QuestLog = { GetLogIndexForQuestID = function(id) return id == 5000 and 3 or nil end }
ns.inQuestLog = function(id) return id == 5000 end
_G.C_Map = { CanSetUserWaypointOnMap = function() return true end, SetUserWaypoint = function(p) pinned = p end,
	GetMapInfo = function() return { name = "Teldrassil" } end }
_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
RXP.currentGuide.steps[74] = { elements = { { tag = "goto", zone = 1438, x = 55.4, y = 50.2 }, { tag = "turnin", questId = 5000 } } }
RXP.currentGuide.steps[75] = { elements = { { tag = "accept", questId = 6000 }, { tag = "goto", zone = 1438, x = 31.2, y = 42.8 } } }
rows[2].Info._OnClick(rows[2].Info)
check("i on a step with a logged quest opens the quest log", opened == 5000 and not pinned)
rows[3].Info._OnClick(rows[3].Info)
check("i on a step without one sets a waypoint", pinned and pinned.m == 1438 and math.abs(pinned.x - 0.312) < 1e-9)
shift = true
opened = nil
rows[2].Info._OnClick(rows[2].Info)
shift = false
check("Shift-click no longer jumps to the step; it acts as a click", setCalls[1] == nil and opened == 5000)

-- folded
db.upcomingCollapsed = true
module:LayoutContents()
check("folded: only the current step drawn", view.shown == 1)
check("folded: header still shown", up._shown)
check("folded: current step grows by the header", view.rows[1].height == 53 and module.bottomSpacing == -4)
check("folded: expand art used", up.MinimizeButton._GetNormalTexture ~= nil)
up.MinimizeButton._OnClick()
check("collapse button unfolds and relayouts", db.upcomingCollapsed == false and relayouts == 1)

-- RXP Style
db.theme = "rxp"
skipCalls = {}
module:LayoutContents()
check("RXP: rows drawn", view.shown == 3)
check("RXP: no Step heading", rows ~= nil and view.rows[1].header == "")
check("RXP: upcoming header hidden", up._shown == false)
local boxes = false
for _, v in ipairs(skipCalls) do if v then boxes = true end end
check("RXP: skip boxes and back box on current step", boxes and skipCalls.back)

-- step buttons
progress = 73; setCalls = {}
ns.stepForward()
check("> goes to the next step", setCalls[1] == 74)
check("< available", ns.canStepBack())
progress = 100
check("> disabled at the last step with no next guide", not ns.canStepForward())
-- with a next guide, > at the last step starts it
local loadedNext = false
-- RestedXP's functions.next can LOAD a guide even with skip = false: looking must never call it (3.5.38)
local peekCalls = 0
RXP.functions = { next = function(skip) if skip == false then peekCalls = peekCalls + 1 end; loadedNext = true end }
RXP.currentGuide.next = "47-48 Inactive;RestedXP Horde\\47-48 Tanaris"
RXP.GetGuideTable = function(group, name)
	if name == "47-48 Tanaris" and group == "RestedXP Horde" then return { group = group, name = name } end
	if name == "47-48 Inactive" then return { group = group, name = name, inactive = true } end
end
RXP.IsGuideActive = function(g) return not g.inactive end
check("> usable at the last step when there is a next guide", ns.canStepForward())
check("its tooltip names the next guide", ns.stepForwardTip():find("47%-48 Tanaris") ~= nil)
ns.stepForward()
check("> at the last step starts the next guide", loadedNext)
check("looking for the next guide never called RestedXP's functions.next", peekCalls == 0)
loadedNext = false
for _ = 1, 5 do ns.canStepForward(); ns.stepForwardTip() end
check("redraws (asking for the next guide) load nothing", not loadedNext)
progress = 50
loadedNext = false
ns.stepForward()
check("> before the last step still goes one step", setCalls[#setCalls] == 51 and not loadedNext)
RXP.functions = nil
RXP.currentGuide.next, RXP.GetGuideTable, RXP.IsGuideActive = nil, nil, nil
-- < at the first step: back to the guide whose next is this one (and offered to this character)
local loadedPrev
RXP.currentGuide.name, RXP.currentGuide.group = "46-47 Feralas", "RestedXP Horde"
RXP.guides = { ["RestedXP Horde||45-46 Ashenvale"] = { name = "45-46 Ashenvale", group = "RestedXP Horde", next = "46-47 Feralas" },
	["RestedXP Horde||Other"] = { name = "Other", group = "RestedXP Horde", next = "Somewhere Else" } }
RXP.IsGuideActive = function() return true end
local savedPrev
RXP.SaveGuideProgress = function(guide, step) savedPrev = { guide.name, step } end
RXP.LoadGuide = function(_, guide) loadedPrev = guide.name; savedPrev.loadedAfter = true end
_G.UnitLevel = function() return 40 end
for i = 1, 100 do RXP.currentGuide.steps[i].sticky = true end -- no step to go back to
progress = 1
check("< usable at the first step when there is a previous guide", ns.canStepBack())
check("its tooltip names it", ns.stepBackTip():find("45%-46 Ashenvale") ~= nil)
ns.stepBack()
check("< at the first step loads the previous guide", loadedPrev == "45-46 Ashenvale")
check("at its first step (saved place set to 1 before loading)", savedPrev and savedPrev[1] == "45-46 Ashenvale" and savedPrev[2] == 1 and savedPrev.loadedAfter)
RXP.SaveGuideProgress = nil
-- RestedXP wipes stepSkip on a load: the previous guide's finished sticky steps came back as current steps
do
	local keep, keepProgress = RXP.currentGuide, progress
	_G.RXPCData = { stepSkip = {} }
	RXP.LoadGuide = function(_, guide)
		loadedPrev = guide.name
		RXP.currentGuide = { name = guide.name, group = guide.group, steps = { { sticky = true }, { sticky = true }, {}, { sticky = true }, { sticky = true } } }
		progress = 4
	end
	for i = 1, 100 do keep.steps[i].sticky = true end
	progress = 1
	local calls = #setCalls
	ns.stepBack()
	local skip = RXPCData.stepSkip
	-- 3.5.49: the previous guide starts at its first step, even when its own saved place (4 here) wins on load
	-- (its steps 1 and 2 are sticky, so its real first step is 3: 3.5.64)
	check("a guide loaded at another saved place is set to its first real step", setCalls[calls + 1] == 3 and progress == 3)
	check("the sticky steps before it are marked done", skip[1] and skip[2] and not skip[3])
	RXP.currentGuide, progress, _G.RXPCData = keep, keepProgress, nil
end
-- 3.5.58: a previous guide RestedXP will not open (its empty guide comes back): back to the guide you were on
do
	local keep = RXP.currentGuide
	local reloaded
	RXP.GetGuideTable = function(g, n) return { group = g, name = n, reloaded = true } end
	RXP.LoadGuide = function(_, guide)
		if guide.reloaded then reloaded = guide.name; RXP.currentGuide = keep else RXP.currentGuide = { empty = true } end
	end
	progress = 1
	for i = 1, 100 do keep.steps[i].sticky = true end
	ns.stepBack()
	check("RestedXP opened nothing: the guide you were on is loaded again", reloaded == keep.name and RXP.currentGuide == keep)
	RXP.GetGuideTable = nil
end
for i = 1, 100 do RXP.currentGuide.steps[i].sticky = nil end
RXP.guides = nil
progress = 100
local before = #setCalls
ns.goToStep(500)
check("out of range ignored", #setCalls == before)

-- a header that cannot be built: one error, then the divider line, no repeats
local errors = 0
_G.geterrorhandler = function() return function() errors = errors + 1 end end
local i = 1
while true do
	local name = debug.getupvalue(module.LayoutContents, i)
	if not name then break end
	if name == "upcoming" then debug.setupvalue(module.LayoutContents, i, nil) end
	i = i + 1
end
module.Header.Text = nil -- makes the build throw
db.theme, db.upcomingCollapsed = "forever", false
for _ = 1, 5 do module:LayoutContents() end
check("failed build reported once over 5 layouts", errors == 1)
check("rows still drawn with the divider", view.shown == 3)
print(pass and "PASS" or "FAILED")
