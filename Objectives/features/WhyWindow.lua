local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

-- /qt why: "Why did guide skip?" in the same look as the /qt settings window and the Prerequisite Journal (the theme
-- kit from Tracker/Config.lua). On top, where you are and RestedXP's two skip settings in plain words; below, the
-- latest moves, newest first, each a sentence with who made it and why. A button turns the list into text to copy for
-- a bug report. The data comes from SkipBox.lua (ns.whySummary, ns.whyMoves, ns.describeMove, ns.whyText).

local WIDTH, HEIGHT, PAD, ROW_GAP = 580, 480, 14, 8
local frame, content, scroll, copyBox, lines, used, summaryLines, refreshButton, copyButton, clearButton, backButton
local WHO_US = { 0.45, 0.75, 1 }   -- moves you made with the tracker's buttons
local WHO_RXP = { 1, 0.82, 0.25 }  -- moves RestedXP made

local function kit()
	local api = root.tracker and root.tracker.api
	return api and api.themeKit
end

local function line(parent)
	used = used + 1
	local fs = lines[used]
	if not fs then
		fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetJustifyH("LEFT")
		fs:SetJustifyV("TOP")
		if fs.SetWordWrap then fs:SetWordWrap(true) end
		lines[used] = fs
	end
	fs:Show()
	return fs
end

local function put(fs, text, template, color, x, y, width)
	fs:SetFontObject(template)
	fs:SetText(text)
	fs:SetTextColor(color[1], color[2], color[3])
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	fs:SetWidth(width)
	return y + (fs:GetStringHeight() or 12)
end

local function onOff(on) return on and "|cff66dd77On|r" or "|cffff7766Off|r" end

local function render()
	if not frame then return end
	local C = kit().C
	used = 0
	local width = (scroll:GetWidth() or (WIDTH - 2 * PAD)) - 4
	content:SetWidth(width)
	local y = 4
	local s = ns.whySummary()
	-- where you are
	if s.guide then
		y = put(line(content), ("|cffffd100%s|r  -  step %d of %d"):format(s.guide, s.step, s.total), "GameFontNormalLarge",
			C.headText, 0, y, width) + 4
	else
		y = put(line(content), "No RestedXP guide is loaded.", "GameFontNormalLarge", C.headText, 0, y, width) + 4
	end
	y = put(line(content), ("Your level: %d"):format(s.level), "GameFontHighlight", C.value, 0, y, width) + ROW_GAP
	-- RestedXP's settings that skip steps on their own
	y = put(line(content), "RestedXP's own settings that skip steps by themselves", "GameFontNormal", C.pageTitle, 0, y, width) + 4
	y = put(line(content), ("Skip overleveled steps: %s  -  steps for a level you are past %s."):format(onOff(s.skipOver),
		s.skipOver and "are skipped by themselves" or "are kept"), "GameFontHighlight", C.label, 10, y, width - 10) + 2
	y = put(line(content), ("Step skips: %s  -  steps for quests you cannot get yet, already did, or are not offered %s."):format(
		onOff(s.autoSkip), s.autoSkip and "are skipped by themselves" or "are kept"), "GameFontHighlight", C.label, 10, y, width - 10) + 2
	y = put(line(content), "Change these in RestedXP's settings (\"Skip overleveled steps\", \"Disable step skips\").",
		"GameFontHighlightSmall", C.subLabel, 10, y, width - 10) + ROW_GAP
	-- what RestedXP skipped in this guide
	if #s.skipped > 0 then
		y = put(line(content), "Skipped in this guide so far", "GameFontNormal", C.pageTitle, 0, y, width) + 4
		for _, r in ipairs(s.skipped) do
			y = put(line(content), ("%d step%s: %s"):format(r[2], r[2] == 1 and "" or "s", r[1]), "GameFontHighlight",
				C.label, 10, y, width - 10) + 2
		end
		y = y + ROW_GAP - 2
	end
	-- the latest moves, newest first
	y = put(line(content), "What moved your guide (newest first)", "GameFontNormal", C.pageTitle, 0, y, width) + 2
	y = put(line(content), "|cff73bfffBlue|r: you, with the tracker's buttons.  |cffffd140Gold|r: RestedXP on its own (or its own window).",
		"GameFontHighlightSmall", C.subLabel, 0, y, width) + 6
	local moves = ns.whyMoves()
	if #moves == 0 then
		y = put(line(content), "Nothing yet this session. Moves are listed here as they happen.", "GameFontHighlight", C.label,
			10, y, width - 10) + 2
	end
	for i = #moves, 1, -1 do
		local m = moves[i]
		local head, detail = ns.describeMove(m)
		local who = m.byUs and WHO_US or WHO_RXP
		local t = line(content)
		put(t, m.time, "GameFontHighlightSmall", C.subLabel, 0, y + 1, 60)
		y = put(line(content), head, "GameFontHighlight", who, 62, y, width - 62) + 1
		if detail then
			y = put(line(content), detail, "GameFontHighlightSmall", C.label, 62, y, width - 62) + 1
		end
		y = y + 5
	end
	for i = used + 1, #lines do lines[i]:Hide() end
	content:SetHeight(y + 6)
	if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
end

local function showList()
	copyBox:Hide(); copyBox:ClearFocus()
	scroll:Show()
	backButton:Hide(); copyButton:Show(); clearButton:Show(); refreshButton:Show()
	render()
end

local function showCopy()
	scroll:Hide()
	copyBox:SetText(ns.whyText())
	copyBox:Show()
	copyBox:SetFocus()
	copyBox:HighlightText()
	backButton:Show(); copyButton:Hide(); clearButton:Hide(); refreshButton:Hide()
end

local function build()
	local k = kit()
	local C = k.C
	local f = k.create("Frame", "RXPForeverTrackerWhyFrame", UIParent)
	frame = f
	lines, used = {}, 0
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if UISpecialFrames then tinsert(UISpecialFrames, "RXPForeverTrackerWhyFrame") end

	k.solid(f, "BACKGROUND", C.window, 0.98, -7):SetAllPoints()
	k.border(f, C.edge, 2, "BORDER")
	local inner = CreateFrame("Frame", nil, f)
	inner:SetPoint("TOPLEFT", 2, -2)
	inner:SetPoint("BOTTOMRIGHT", -2, 2)
	k.border(inner, { 0, 0, 0 }, 1, "BORDER")

	-- title bar
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 2, -2)
	bar:SetPoint("TOPRIGHT", -2, -2)
	bar:SetHeight(32)
	local barBg = bar:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints()
	k.gradient(barBg, C.titleTop, C.titleBottom)
	local barLine = k.solid(bar, "BORDER", C.titleLine)
	barLine:SetPoint("BOTTOMLEFT")
	barLine:SetPoint("BOTTOMRIGHT")
	barLine:SetHeight(1)
	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", PAD, 0)
	title:SetText("Why did guide skip?")
	local close = k.create("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(28, 28)
	close:SetPoint("TOPRIGHT", -3, -4)
	close:SetFrameLevel(bar:GetFrameLevel() + 5)
	close:HookScript("OnClick", function() f:Hide() end)

	-- the page: a dark panel like the settings window's
	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT", PAD, -40)
	panel:SetPoint("BOTTOMRIGHT", -PAD, 46)
	k.solid(panel, "BACKGROUND", C.panel, 1):SetAllPoints()
	k.border(panel, C.panelEdge, 1, "BORDER")

	scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - 2 * PAD - 24, 1)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max((content:GetHeight() or 0) - (self:GetHeight() or 0), 0)
		self:SetVerticalScroll(math.min(math.max((self:GetVerticalScroll() or 0) - delta * 40, 0), max))
	end)

	-- the same as text, selected, to copy (Ctrl+C) into a bug report
	copyBox = CreateFrame("EditBox", nil, panel)
	copyBox:SetPoint("TOPLEFT", 10, -8)
	copyBox:SetPoint("BOTTOMRIGHT", -10, 8)
	copyBox:SetMultiLine(true)
	copyBox:SetAutoFocus(false)
	copyBox:SetFontObject(ChatFontNormal)
	copyBox:SetTextColor(C.value[1], C.value[2], C.value[3])
	copyBox:SetScript("OnEscapePressed", function() showList() end)
	copyBox:Hide()

	-- footer buttons, in the settings window's style
	copyButton = k.makeButton(f, "Copy for a bug report", 170, showCopy)
	copyButton:SetPoint("BOTTOMLEFT", PAD, 12)
	clearButton = k.makeButton(f, "Clear the list", 120, function() ns.clearMoves() end)
	clearButton:SetPoint("LEFT", copyButton, "RIGHT", 8, 0)
	refreshButton = k.makeButton(f, "Refresh", 90, render)
	refreshButton:SetPoint("BOTTOMRIGHT", -PAD, 12)
	backButton = k.makeButton(f, "Back to the list", 140, showList)
	backButton:SetPoint("BOTTOMLEFT", PAD, 12)
	backButton:Hide()
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("RIGHT", refreshButton, "LEFT", -10, 0)
	hint:SetTextColor(C.subLabel[1], C.subLabel[2], C.subLabel[3])
	hint:SetText("/qt why")

	f:SetScript("OnShow", function() showList() end)
	f:Hide() -- new frames start shown; the first Show below lays it out
end

-- a new move while the window is open: list it
function ns.whyChanged()
	if frame and frame:IsShown() and scroll:IsShown() then render() end
end

function ns.showWhyWindow()
	if not kit() then error("the settings window's look is not available") end
	if not frame then build() end
	if frame:IsShown() then render() else frame:Show() end
end
