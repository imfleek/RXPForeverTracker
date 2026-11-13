local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp
local L = ns.L
local db = ns.db

local LOGO_SIZE, LOGO_INSET, BADGE_SIZE, HEADER_LIFT, BUTTON_GAP = 30, 6, 17, 2, 2
local LOGO_ICON = "rxp_logo-64"
local INDICATOR_TEXT = "Blizzard hides the tracker while it has nothing to show: your steps return with it. "
	.. "RestedXP's own window is not hidden meanwhile.\nClick: browse guides. Right-click: settings."

local logo, badge, title, subtitle, stepText, settingsButton, guidesButton, counter, indicator, logoToggle
-- Forever Style header buttons, right to left before the collapse button: > < ? !
local foreverButtons, nextButton, prevButton, restartButton, browseButton, helpButton, stepCount, nameButton, nameClicksPassed
-- the Prerequisite Journal's book, before the guide name in both styles (Tracker/Prereqs.lua)
-- Art: Forever's own journal button, the Adventure Guide (encounter journal) micro button, an open book
-- (Blizzard_MicroMenu Mainline EJMicroButtonMixin: LoadMicroButtonTextures(self, "AdventureGuide"):
-- UI-HUD-MicroMenu-AdventureGuide-Up/Down/Disabled/Mouseover; in Forever's micro menu, Camelot
-- MicroMenuContainerOverrides; forever source 1.60.1.70888), at the atlas's proportions. (The Questlog button's art
-- is a "!" scroll, not a book.) A client without those atlases gets a book icon.
local JOURNAL_ATLAS = "UI-HUD-MicroMenu-AdventureGuide-"
local JOURNAL_ICON, JOURNAL_SIZE, JOURNAL_GAP = "Interface\\Icons\\INV_Misc_Book_09", 16, 4
local JOURNAL_HEIGHT = 22
local journal, journalForeverPoint

local function showTooltip(owner, text, heading)
	local tooltip = ns.getTooltip()
	tooltip:SetOwner(owner, "ANCHOR_TOP")
	local fallbackTitle = "RestedXP Guides " .. ns.rxpRelease()
	GameTooltip_SetTitle(tooltip, heading or fallbackTitle)
	GameTooltip_AddNormalLine(tooltip, text, true)
	tooltip:Show()
end

local function showWindowsTooltip(owner)
	showTooltip(owner, ns.windowsTooltip())
end

local function openSettings()
	RXP.v2:ShowSettingsMenu()
end

local function openGuides()
	ns.showGuideMenu()
end

local function scaledText(parent, minLineHeight, fontObject)
	local text = Mixin(parent:CreateFontString(nil, "OVERLAY", fontObject), AutoScalingFontStringMixin)
	text.minLineHeight = minLineHeight
	text:SetWordWrap(false)
	text:SetMaxLines(1)
	return text
end

local guideModule

local function openJournal()
	local api = root.tracker and root.tracker.api
	if api and api.togglePrereqs then api.togglePrereqs() end
end

local function buildJournal(header)
	local button = CreateFrame("Button", nil, header)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(JOURNAL_ATLAS .. "Up")
	if info and info.width and info.height and info.height > 0 then
		button:SetSize(math.floor(JOURNAL_HEIGHT * info.width / info.height + 0.5), JOURNAL_HEIGHT)
		button:SetNormalAtlas(JOURNAL_ATLAS .. "Up")
		button:SetPushedAtlas(JOURNAL_ATLAS .. "Down")
		button:SetDisabledAtlas(JOURNAL_ATLAS .. "Disabled")
		button:SetHighlightAtlas(JOURNAL_ATLAS .. "Mouseover")
	else
		button:SetSize(JOURNAL_SIZE, JOURNAL_SIZE)
		button:SetNormalTexture(JOURNAL_ICON)
		button:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	end
	button:SetScript("OnClick", openJournal)
	button:SetScript("OnEnter", function(self)
		showTooltip(self, "Quests ahead in this guide that you can't take yet, and what to do first. Requires Questie.",
			"Prerequisite Journal")
	end)
	button:SetScript("OnLeave", ns.hideTooltip)
	journal = button
	-- Forever Style: where the game's header text starts; the book takes that spot and the text follows it
	local point, relative, relativePoint, x, y = header.Text:GetPoint(1)
	journalForeverPoint = {point or "LEFT", relative or header, relativePoint or "LEFT", x or 0, y or 0}
	-- the template's own text position, for the Upcoming Steps header's copy (Rows.lua): the guide's header text is
	-- anchored to the book from now on
	ns.headerTextPoint = {point or "LEFT", relativePoint or "LEFT", x or 0, y or 0}
end

-- RXP Style: the book after the logo, the name after the book; Forever Style: the book where the header text began
local function placeJournal(header, forever)
	journal:ClearAllPoints()
	if forever then
		-- left to right: ! ? book, the guide name (cut with "..." when long), 4/73, < > and the collapse button
		local p = journalForeverPoint
		browseButton:ClearAllPoints()
		browseButton:SetPoint("LEFT", p[2], p[3], p[4], p[5])
		helpButton:ClearAllPoints()
		helpButton:SetPoint("LEFT", browseButton, "RIGHT", BUTTON_GAP, 0)
		journal:SetPoint("LEFT", helpButton, "RIGHT", JOURNAL_GAP, 0)
		header.Text:ClearAllPoints()
		header.Text:SetPoint("LEFT", journal, "RIGHT", JOURNAL_GAP, 0)
		header.Text:SetPoint("RIGHT", stepCount, "LEFT", -6, 0)
	else
		journal:SetPoint("TOPLEFT", LOGO_INSET * 2 + LOGO_SIZE, HEADER_LIFT + (journal:GetHeight() - JOURNAL_SIZE) / 2)
		title:SetPoint("TOPLEFT", LOGO_INSET * 2 + LOGO_SIZE + journal:GetWidth() + JOURNAL_GAP, HEADER_LIFT)
	end
end

local function buildModuleHeader(module)
	guideModule = module
	local header = module.Header
	header.Text:Hide()
	logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetPoint("BOTTOMLEFT", LOGO_INSET, HEADER_LIFT)
	logo:SetSize(LOGO_SIZE, LOGO_SIZE)
	badge = header:CreateTexture(nil, "OVERLAY")
	badge:SetPoint("BOTTOMRIGHT", logo, "BOTTOMRIGHT", 2, 1)
	badge:SetSize(BADGE_SIZE, BADGE_SIZE)
	-- "Step X of Y" on the guide name's line, at the right (before the collapse button); the name ends before it
	stepText = header:CreateFontString(nil, "OVERLAY")
	stepText:SetPoint("TOPRIGHT", header.MinimizeButton, "TOPLEFT", -4, HEADER_LIFT)
	stepText:SetJustifyH("RIGHT")
	stepText:SetWordWrap(false)
	title = scaledText(header, 8)
	title:SetPoint("TOPLEFT", LOGO_INSET * 2 + LOGO_SIZE, HEADER_LIFT)
	title:SetPoint("TOPRIGHT", stepText, "TOPLEFT", -6, 0)
	title:SetJustifyH("LEFT")
	title:SetTextColor(1, 0.82, 0)
	subtitle = scaledText(header, 9)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	subtitle:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
	subtitle:SetJustifyH("LEFT")

	buildJournal(header)
	local toggle = CreateFrame("Button", nil, header)
	logoToggle = toggle
	toggle:SetAllPoints(logo)
	local highlight = header.MinimizeButton:GetHighlightTexture()
	toggle:SetHighlightAtlas(highlight:GetAtlas(), highlight:GetBlendMode())
	toggle:SetScript("OnClick", function(self)
		ns.toggleHidden()
		showWindowsTooltip(self)
	end)
	toggle:SetScript("OnEnter", showWindowsTooltip)
	toggle:SetScript("OnLeave", ns.hideTooltip)
end

-- Forever Style ------------------------------------------------------------------------------------------------------
-- The game's own section header (the module template's Text, background and collapse button) with the guide name, and
-- four small buttons in the game's art: ! browse guides, ? help and settings, < back a step, > next step.
local FOREVER_HELP = "Left-click: RXP Tracker settings (/qt).\nRight-click: RestedXP's own settings.\n"
	.. "Right-click the steps: change guide.\n"
	.. "Click the i beside an upcoming step: its quest in the log, or a waypoint."

local function openTrackerSettings()
	local api = root.tracker and root.tracker.api
	if api and api.openConfigTab then api.openConfigTab("guide") end
end

local function foreverButton(header, size, normal, onClick, tip, heading)
	local button = CreateFrame("Button", nil, header)
	button:SetSize(size, size)
	button:SetNormalTexture(normal)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self) showTooltip(self, type(tip) == "function" and tip() or tip, heading) end)
	button:SetScript("OnLeave", ns.hideTooltip)
	return button
end

-- The restart button: the game's square button (UI-SquareButton, the frame the spellbook page arrows are drawn in; the
-- quest tracker's own find-group button uses it the same way) with a circular arrow in the < > arrows' gold.
local SQUARE = "Interface\\Buttons\\UI-SquareButton-"
local RESTART_ICON = "Interface\\Buttons\\UI-RefreshButton"
local ARROW_GOLD = { 1, 0.82, 0 }
local function restartIconLook(button)
	local icon = button.icon
	-- a way back waiting: the arrow turns the other way
	if button.pending then icon:SetTexCoord(1, 0, 0, 1) else icon:SetTexCoord(0, 1, 0, 1) end
	local on = button:IsEnabled()
	icon:SetVertexColor(on and ARROW_GOLD[1] or 0.5, on and ARROW_GOLD[2] or 0.5, on and ARROW_GOLD[3] or 0.5)
	icon:SetDesaturated(not on)
end
local function restartButtonFor(header, size, onClick, tip)
	local button = foreverButton(header, size, SQUARE .. "Up", onClick, tip, "RestedXP Guides")
	button:SetPushedTexture(SQUARE .. "Down")
	button:SetDisabledTexture(SQUARE .. "Disabled")
	local icon = button:CreateTexture(nil, "ARTWORK", nil, 5)
	icon:SetTexture(RESTART_ICON)
	icon:SetSize(math.floor(size * 0.5 + 0.5), math.floor(size * 0.5 + 0.5))
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon = icon
	-- pressed in, as the template's icon moves (QuestObjectiveFindGroupButton / SquareIconButtonTemplate)
	button:SetScript("OnMouseDown", function(self) if self:IsEnabled() then icon:SetPoint("CENTER", self, "CENTER", -1, -1) end end)
	button:SetScript("OnMouseUp", function(self) icon:SetPoint("CENTER", self, "CENTER", 0, 0) end)
	return button
end

local function pageButton(header, size, page, onClick, tip)
	local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-"
	local button = foreverButton(header, size, base .. "Up", onClick, tip, "RestedXP Guides")
	button:SetPushedTexture(base .. "Down")
	button:SetDisabledTexture(base .. "Disabled")
	return button
end

local function buildForeverButtons(header)
	local size = math.max(14, math.floor(header.MinimizeButton:GetHeight() + 0.5))
	nextButton = pageButton(header, size + 4, "Next", function() ns.stepForward() end, function() return ns.stepForwardTip() end)
	prevButton = pageButton(header, size + 4, "Prev", function() ns.stepBack() end, function() return ns.stepBackTip() end)
	local help = foreverButton(header, size, "Interface\\GossipFrame\\ActiveQuestIcon", function(_, mouseButton)
		if mouseButton == "RightButton" then openSettings() else openTrackerSettings() end
	end, FOREVER_HELP, "RXP Tracker")
	local browse = foreverButton(header, size, "Interface\\GossipFrame\\AvailableQuestIcon", function() openGuides() end,
		"Left-click: " .. L("Browse Guides"), "RestedXP Guides")
	-- between < and >: the guide's first step, and back again
	restartButton = restartButtonFor(header, size + 4, function() ns.restartToggle() end, function() return ns.restartTip() end)
	nextButton:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -BUTTON_GAP, 0)
	restartButton:SetPoint("RIGHT", nextButton, "LEFT", 2, 0)
	prevButton:SetPoint("RIGHT", restartButton, "LEFT", 2, 0)
	-- "4/73" (current step of the guide's steps) before the arrows, as RXP Style's "Step X of Y"
	stepCount = header:CreateFontString(nil, "OVERLAY")
	stepCount:SetFontObject(header.Text:GetFontObject() or "ObjectiveTrackerHeaderFont")
	stepCount:SetJustifyH("RIGHT")
	stepCount:SetWordWrap(false)
	stepCount:SetPoint("RIGHT", prevButton, "LEFT", -4, 0)
	-- ! and ? go to the left end, before the journal book (placed in placeJournal)
	browseButton, helpButton = browse, help
	-- clicking the guide name opens or closes RestedXP's own guide window, as the logo does in RXP Style
	local nameToggle = CreateFrame("Button", nil, header)
	nameToggle:SetPoint("TOPLEFT", header.Text, "TOPLEFT", -2, 3)
	nameToggle:SetPoint("BOTTOMRIGHT", header.Text, "BOTTOMRIGHT", 2, -3)
	local glow = nameToggle:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetColorTexture(1, 0.82, 0, 0.08)
	nameToggle:SetScript("OnClick", function(self)
		ns.toggleHidden()
		showWindowsTooltip(self)
	end)
	nameToggle:SetScript("OnEnter", showWindowsTooltip)
	nameToggle:SetScript("OnLeave", ns.hideTooltip)
	-- right-clicks (guide menu, Shift: /qt, Ctrl: Prerequisite Journal) still reach the guide underneath
	nameToggle:RegisterForClicks("LeftButtonUp")
	nameButton = nameToggle
	foreverButtons = {browse, help, prevButton, restartButton, nextButton, stepCount, nameToggle}
	header.Text:SetWordWrap(false)
end

local function showForeverHeader(module, snapshot, forever)
	local header = module.Header
	if forever and not foreverButtons then buildForeverButtons(header) end
	for _, region in ipairs({logo, badge, title, subtitle, stepText, logoToggle}) do region:SetShown(not forever) end
	if foreverButtons then
		for _, button in ipairs(foreverButtons) do button:SetShown(forever) end
	end
	header.Text:SetShown(forever)
	-- CONSTRAINT: SetPropagateMouseClicks is protected (Forever API: IsProtectedFunction): out of combat only; a header
	-- first built in combat gets it on the next update after combat.
	if nameButton and not nameClicksPassed and not InCombatLockdown() and nameButton.SetPropagateMouseClicks then
		nameClicksPassed = pcall(nameButton.SetPropagateMouseClicks, nameButton, true)
	end
	placeJournal(header, forever)
	if not forever then return end
	-- the guide's own name (e.g. "46-47 Feralas/Azshara"), not its group ("Dungeon Guide"): RestedXP puts the group in
	-- title and the guide's name in subtitle when the guide has a group (UI/V2/Core.lua BuildGuideStepsSnapshot)
	local sub = snapshot and snapshot.subtitle
	local name = (sub and sub ~= "") and sub or snapshot and snapshot.title or ""
	module.headerText = name
	-- unchanged text is not set again (each SetText makes the game measure it)
	if header.Text:GetText() ~= name then header.Text:SetText(name) end
	local progress, total = snapshot and snapshot.progress, snapshot and snapshot.total
	-- Tracker settings > Step counter: shown, size (0 = the header's), colour (false = the default light grey)
	local db = ns.db
	local font, size, flags = header.Text:GetFont()
	local wantSize = tonumber(db.stepCountSize) or 0
	if wantSize > 0 then size = wantSize end
	local c = type(db.stepCountColor) == "table" and db.stepCountColor or nil
	-- compared as numbers (no table or string built on every redraw)
	local cr, cg, cb, ca = c and c[1], c and c[2], c and c[3], c and (c[4] or 1)
	if font and (stepCount.font ~= font or stepCount.size ~= size or stepCount.flags ~= flags or stepCount.cr ~= cr
		or stepCount.cg ~= cg or stepCount.cb ~= cb or stepCount.ca ~= ca or stepCount.customColor ~= (c ~= nil)) then
		stepCount:SetFont(font, size, flags)
		stepCount.font, stepCount.size, stepCount.flags = font, size, flags
		stepCount.cr, stepCount.cg, stepCount.cb, stepCount.ca, stepCount.customColor = cr, cg, cb, ca, c ~= nil
		if c then stepCount:SetTextColor(c[1], c[2], c[3], c[4] or 1) else stepCount:SetTextColor(0.85, 0.85, 0.85) end
	end
	-- hidden: no text, so the guide name gets the room
	local count = (db.stepCountShown ~= false and progress and total and total > 0) and (progress .. "/" .. total) or ""
	if stepCount:GetText() ~= count then stepCount:SetText(count) end
	prevButton:SetEnabled(ns.canStepBack())
	nextButton:SetEnabled(ns.canStepForward())
	if restartButton then
		local pending = ns.restartPending and ns.restartPending() or false
		local can = ns.canRestart and ns.canRestart() or false
		if restartButton.pending ~= pending or restartButton.can ~= can then
			restartButton.pending, restartButton.can = pending, can
			restartButton:SetEnabled(can)
			restartIconLook(restartButton)
		end
	end
end

-- the settings window changed the counter: redraw now
function ns.applyStepCount()
	if stepCount then stepCount.font = nil end
	ns.refresh(true)
end

local function iconButton(parent, onClick, onEnter)
	local button = CreateFrame("Button", nil, parent, "ObjectiveTrackerContainerMinimizeButtonTemplate")
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", ns.hideTooltip)
	return button
end

local function headerButton(labelKey, onClick)
	return iconButton(ObjectiveTrackerFrame.Header, onClick, function(self) showTooltip(self, L(labelKey)) end)
end

local function buildContainerWidgets()
	settingsButton = headerButton("Open Settings", openSettings)
	guidesButton = headerButton("Browse Guides", openGuides)
	counter = scaledText(ObjectiveTrackerFrame.Header, 12, "ObjectiveTrackerHeaderFont")
	counter:SetJustifyH("CENTER")
end

-- CONSTRAINT: ScaleTextToFit caches baseLineHeight on its first call: a new font size needs scale 1 and a new cache.
local function resetScaling(text)
	text:SetTextScale(1)
	text.baseLineHeight = nil
end

local function setScaledFont(text, font, size)
	text:SetFont(font, size, "")
	resetScaling(text)
end

local function updateModuleHeader(snapshot)
	local font, color = ns.textStyle()
	local size = ns.guideFontSize()
	setScaledFont(title, font, size)
	setScaledFont(subtitle, font, size + 2)
	subtitle:SetTextColor(unpack(color))
	stepText:SetFont(font, size, "")
	stepText:SetTextColor(0.85, 0.85, 0.85)
	local progress, total = snapshot and snapshot.progress, snapshot and snapshot.total
	stepText:SetText((progress and total and total > 0) and ("Step %d of %d"):format(progress, total) or "")
	title:SetText(snapshot and snapshot.title or "")
	subtitle:SetText(snapshot and snapshot.subtitle or "")
	logo:SetTexture(ns.texture(LOGO_ICON))
	badge:SetTexture(ns.texture(ns.playerClass()))
	showForeverHeader(guideModule, snapshot, ns.forever())
end

local function setButtonIcon(button, icon, enabled)
	local texture = ns.texture(icon)
	button:SetNormalTexture(texture)
	button:SetPushedTexture(texture)
	button:SetShown(enabled)
end

local function updateContainerWidgets(snapshot)
	local header, enabled = ObjectiveTrackerFrame.Header, db.enabled
	settingsButton:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -BUTTON_GAP, 0)
	guidesButton:SetPoint("RIGHT", settingsButton, "LEFT", -BUTTON_GAP, 0)
	-- CONSTRAINT: the counter starts at the ink edge of the header text, not the edge of its box
	-- (Blizzard_ObjectiveTrackerContainer.xml); anchors only, no position read off Blizzard's frames.
	counter:SetPoint("LEFT", header.Text, "LEFT", header.Text:GetStringWidth() + BUTTON_GAP, 0)
	counter:SetPoint("RIGHT", guidesButton, "LEFT", -BUTTON_GAP, 0)
	-- Forever Style: these two live on the guide's own header as ? and !
	local shown = enabled and not ns.forever()
	setButtonIcon(settingsButton, "rxp_cog-32", shown)
	setButtonIcon(guidesButton, LOGO_ICON, shown)
	resetScaling(counter)
	counter:SetText("") -- the step counter now sits beside the guide name (updateModuleHeader)
end

function ns.buildHeaders(module)
	buildModuleHeader(module)
	buildContainerWidgets()
	-- CONSTRAINT: the counter's anchor holds the header text's width, which a new text size changes with no new snapshot.
	hooksecurefunc(ObjectiveTrackerManager, "SetTextSize", ns.relayout)
end

function ns.updateHeaders(snapshot)
	updateModuleHeader(snapshot)
	updateContainerWidgets(snapshot)
end

local function showIndicatorTooltip(owner)
	showTooltip(owner, INDICATOR_TEXT, "RXP ForeverTracker")
end

local function clickIndicator(_, mouseButton)
	if mouseButton == "RightButton" then openSettings() else openGuides() end
end

local function buildIndicator()
	local button = iconButton(UIParent, clickIndicator, showIndicatorTooltip)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetPoint("CENTER", ObjectiveTrackerFrame.Header.MinimizeButton)
	return button
end

function ns.updateIndicator(paused)
	local shown = paused and db.enabled
	if not (shown or indicator) then return end
	indicator = indicator or buildIndicator()
	setButtonIcon(indicator, LOGO_ICON, shown)
	if not shown then ns.releaseOwnTooltip(indicator) end
end
