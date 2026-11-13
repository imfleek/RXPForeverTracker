local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp

local TRANSPARENT = {0, 0, 0, 0}
local SKIP_IDLE_ALPHA, SKIP_HOVER_ALPHA = 0.8, 1
-- CONSTRAINT: RestedXP's V2 box is 11 px (UI/V2/Core.lua createElementRow); the tracker line font is 12 pt
-- (Blizzard_ObjectiveTrackerFonts.xml ObjectiveTrackerFont12). Size and glyphs scale from that ratio.
local RXP_BOX, TRACKER_TEXT_PT = 11, 12

-- CONSTRAINT: RestedXP's ApplyFrameBackdrop builds two frames and five textures the first time it paints a frame and
-- allocates on every call: only the side in view is painted (the hover frame's own on the first hover).
local function updateSkipBox(box)
	local theme = RXP.v2:GetTheme()
	local checked, hovered = not not box:GetChecked(), not not box.hovered
	local idle = not hovered and checked
	if hovered then
		RXP.ui.v2:ApplyFrameBackdrop(box.hover, theme.edge, TRANSPARENT, theme.borderColors.commonEdge)
	else
		RXP.ui.v2:ApplyFrameBackdrop(box, theme.edge, idle and theme.backgroundColors.activeStepCheckboxChecked
			or theme.backgroundColors.activeStepCheckbox, idle and theme.borderColors.activeStepCheckboxChecked
			or theme.borderColors.commonEdge)
	end
	RXP.ui.v2:SetFrameBackdropShown(box, not hovered)
	box.checkShort:SetShown(idle)
	box.checkLong:SetShown(idle)
	box.hover:SetShown(hovered)
	box:SetAlpha(hovered and SKIP_HOVER_ALPHA or SKIP_IDLE_ALPHA)
end

local function newTick(box, rotation)
	local tick = box:CreateTexture(nil, "OVERLAY")
	tick:SetColorTexture(1, 1, 1, 1)
	tick:SetRotation(rotation)
	return tick
end

local function onEnter(box)
	box.hovered = true
	updateSkipBox(box)
	RXP.ActiveStepElementOnEnter(box)
end

local function onLeave(box)
	box.hovered = nil
	updateSkipBox(box)
	RXP.ActiveStepElementOnLeave(box)
end

local function onPostClick(box)
	PlaySound(box:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	RXP.ActiveStepElementPostClick(box)
	local element = box:GetParent().element
	box:SetChecked(not not (element.completed or element.skip))
	updateSkipBox(box)
end

-- CONSTRAINT: RestedXP's click and enter handlers read the element from the parent line (GuideWindow.lua
-- ActiveStepElementPostClick, ActiveStepElementOnEnter): setSkipBox keeps it in line.element.
local function newSkipBox(line)
	local box = CreateFrame("CheckButton", nil, line)
	box:SetPushedTexture("")
	box.checkShort = newTick(box, -math.pi / 4)
	box.checkLong = newTick(box, math.pi / 4)
	box.hover = CreateFrame("Frame", nil, box)
	box.hover:SetAllPoints(box)
	box.hoverIcon = box.hover:CreateTexture(nil, "OVERLAY")
	box.hoverIcon:SetTexture("Interface/AddOns/RXPGuides/Textures/v2/rxp-skip-step-hover")
	box:SetScript("OnEnter", onEnter)
	box:SetScript("OnLeave", onLeave)
	box:SetScript("PostClick", onPostClick)
	return box
end

local function sizeGlyphs(box, size)
	local scale = size / RXP_BOX
	box.checkShort:SetSize(3.5 * scale, 1.25 * scale)
	box.checkShort:SetPoint("CENTER", box, "CENTER", -1.5 * scale, -0.8 * scale)
	box.checkLong:SetSize(6 * scale, 1.25 * scale)
	box.checkLong:SetPoint("CENTER", box, "CENTER", scale, -0.1 * scale)
	box.hoverIcon:SetPoint("TOPLEFT", box.hover, "TOPLEFT", 2 * scale, -2 * scale)
	box.hoverIcon:SetPoint("BOTTOMRIGHT", box.hover, "BOTTOMRIGHT", -2 * scale, 2 * scale)
end

-- Back one step: a box in the skip box's style, left of the first skip box of the current step. It moves the guide to
-- the step before RestedXP's current one (RXP.GetGuideProgress, RXP.SetStep: the calls the Snapshot and the hooks in
-- Core.lua already rely on); at the first step it is dimmed and does nothing.
local BACK_GAP = 0.25 -- of a line's font height, between the back box and the skip box
local BACK_DISABLED_ALPHA = 0.3

function ns.backButtonRoom(fontHeight)
	return fontHeight * (RXP_BOX / TRACKER_TEXT_PT + 2 * BACK_GAP)
end

local backButton

-- CONSTRAINT: RestedXP's SetStep(n) (GuideWindow.lua) moves on to n + 1 at once when step n is sticky (sticky steps
-- stay active beside the current one) or above the player's level, so the target is the nearest earlier step that is
-- neither. A step left behind had its completed flag cleared when the guide moved past it (SetStep clears it on every
-- step it deactivates), so it is shown again; RestedXP may then complete it straight away if it is already done.
-- A step you or RestedXP already skipped (an objective's box ticked, or RestedXP's "Step skipped: ..." note): going back
-- to it would only bounce straight back, so < passes it by. Completed objectives do not count: RestedXP keeps an
-- objective's done flag from the last time the guide passed it and checks it again when the step comes back, so
-- judging by it jumped over steps that were not done.
local function skippedStep(step)
	if type(step) ~= "table" then return true end
	if type(step.tooltipText) == "string" and step.tooltipText:find("Step skipped", 1, true) then return true end
	for _, e in ipairs(type(step.elements) == "table" and step.elements or {}) do
		if type(e) == "table" and (e.skip and not e.textOnly
			or type(e.tooltipText) == "string" and e.tooltipText:find("Step skipped", 1, true)) then
			return true
		end
	end
	return false
end

local firstStep -- below: a guide's real first step

-- A step that sends you elsewhere at once: one of its objectives carries a label to jump to (".maxlevel 43,SoSSkip",
-- ".xp <N,label", ...; RestedXP sets addon.nextStep to the label and goes there on its next pass). Going back onto one
-- rolled the guide over into its later steps.
local function jumpStep(step)
	for _, e in ipairs(type(step) == "table" and type(step.elements) == "table" and step.elements or {}) do
		if type(e) == "table" and e.ref then return true end
	end
	return false
end

-- previousStep(below, anyOnly): anyOnly answers only "is there an earlier step to go to?" (redraws ask that): it stops
-- at the first plain step without looking at skips
local function previousStep(below, anyOnly)
	local ok, progress = pcall(RXP.GetGuideProgress)
	if not ok or type(progress) ~= "number" or ns.isSecret(progress) then return nil end
	local guide = RXP.currentGuide
	local steps = guide and not guide.empty and guide.steps
	if type(steps) ~= "table" then return nil end
	local level = UnitLevel("player")
	if ns.isSecret(level) then level = nil end
	local fallback
	for index = math.min((below or progress) - 1, #steps), 1, -1 do
		local step = steps[index]
		if step and not step.sticky and not (level and tonumber(step.level) and level < step.level) and not jumpStep(step) then
			if anyOnly or not skippedStep(step) then return index end
			fallback = fallback or index
		end
	end
	return fallback
end

-- Back is one SetStep, as RestedXP's own "Go to step N". When RestedXP puts you straight back on the very step you left
-- (it finished the step again at once), < keeps going one more step back until it stays (or there is no earlier step).
-- Any other move by RestedXP, or another click of yours, stops it (a loop that also reacted to those fought RestedXP's
-- own step changes). BOUNCE_MAX only guards against an endless run.
local BOUNCE_CHECK, BOUNCE_MAX = 0.6, 40
local backClicks = 0
local function stepBackFrom(origin, target, tries, click)
	if not click then
		backClicks = backClicks + 1
		click = backClicks
	end
	tries = tries or 0
	local ok, err = pcall(RXP.SetStep, target)
	if not ok then ns.say("Could not go back a step: " .. tostring(err)) return end
	if tries >= BOUNCE_MAX or not C_Timer then return end
	local guide = RXP.currentGuide
	C_Timer.After(BOUNCE_CHECK, function()
		if click ~= backClicks or RXP.currentGuide ~= guide then return end
		local okNow, now = pcall(RXP.GetGuideProgress)
		if not okNow or type(now) ~= "number" or ns.isSecret(now) then return end
		-- rolled over past where you were (RestedXP jumped ahead from the step you went back to): back a guide instead,
		-- or, with none before this one, to the step you were on
		if now > origin then
			if ns.previousGuide and ns.previousGuide() then ns.backToPreviousGuide() else pcall(RXP.SetStep, origin) end
			return
		end
		if now ~= origin then return end
		local further = previousStep(target)
		if further and further < target then stepBackFrom(origin, further, tries + 1, click) end
	end)
end

local function updateBack(button)
	local theme = RXP.v2:GetTheme()
	RXP.ui.v2:ApplyFrameBackdrop(button, theme.edge, theme.backgroundColors.activeStepCheckbox,
		button.hovered and theme.borderColors.activeStepCheckboxChecked or theme.borderColors.commonEdge)
	local target = previousStep(nil, true)
	button:SetAlpha(not target and BACK_DISABLED_ALPHA or button.hovered and SKIP_HOVER_ALPHA or SKIP_IDLE_ALPHA)
end

local function backTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	local target = previousStep()
	GameTooltip:SetText("Back one step", 1, 1, 1)
	GameTooltip:AddLine(target and ("Go back to step " .. target .. ".") or "This is the guide's first step.", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

local function goBack(button)
	local target = previousStep()
	if not target then return end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	local okProgress, origin = pcall(RXP.GetGuideProgress)
	stepBackFrom(okProgress and type(origin) == "number" and origin or target + 1, target)
	updateBack(button)
	if button.hovered then backTooltip(button) end
end

-- Forever Style header arrows: one step back / forward, and a jump to an upcoming step (its info icon).
-- The guide before this one: a guide whose #next names the current guide ("Group\\Name" or a name in its own group,
-- any of a ";" list) and that RestedXP offers this character (IsGuideActive). Found once per current guide.
local prevCache = setmetatable({}, { __mode = "k" })
local function previousGuide()
	local current = RXP.currentGuide
	if not current or current.empty or not current.name then return nil end
	local known = prevCache[current]
	if known ~= nil then return known or nil end
	local found = false
	for _, guide in pairs(type(RXP.guides) == "table" and RXP.guides or {}) do
		-- (not one RestedXP's LoadGuide turns down: internal or disabled guides)
		if type(guide) == "table" and type(guide.next) == "string" and guide ~= current and guide.name ~= current.name
			and not guide.internal and not guide.disabled then
			for spec in guide.next:gmatch("[^;]+") do
				spec = spec:gsub("^%s+", ""):gsub("%s+$", "")
				local group, name = spec:match("^(.-)\\(.+)$")
				name, group = name or spec, group or guide.group
				if name == current.name and (group == current.group or group == current.groupdisplayname)
					and (not RXP.IsGuideActive or RXP.IsGuideActive(guide)) then
					found = guide
					break
				end
			end
		end
		if found then break end
	end
	prevCache[current] = found
	return found or nil
end
ns.previousGuide = previousGuide

-- < stays usable at the first step when there is a guide before this one: it goes back to that guide
function ns.canStepBack()
	return previousStep(nil, true) ~= nil or previousGuide() ~= nil
end

function ns.stepBackTip()
	local guide = previousGuide()
	local shift = guide and ("\nShift+click: back to the start of the previous guide, " .. tostring(guide.displayname or guide.name) .. ".") or ""
	if previousStep(nil, true) == nil then
		return guide and ("First step: back to the start of the previous guide, " .. tostring(guide.displayname or guide.name) .. ".") or "First step of this guide."
	end
	return "Back one step." .. shift
end

-- CONSTRAINT: RestedXP's LoadGuide wipes RXPCData.stepSkip (GuideWindow.lua LoadGuide), the record of the sticky steps
-- you already finished, and SetStep then makes every sticky step before your place active again. Going back to a
-- guide you have moved past, that showed its finished sticky steps as current ones (an unbounded list above the
-- upcoming steps). They are marked done again and the step is set once more, so only the step you are at shows.
function ns.settleEarlierSteps()
	local data = _G.RXPCData
	local guide = RXP.currentGuide
	local okProgress, progress = pcall(RXP.GetGuideProgress)
	if type(data) ~= "table" or type(guide) ~= "table" or type(guide.steps) ~= "table" or not okProgress
		or type(progress) ~= "number" or ns.isSecret(progress) then return end
	data.stepSkip = type(data.stepSkip) == "table" and data.stepSkip or {}
	local changed = false
	for index = 1, math.min(progress - 1, #guide.steps) do
		local step = guide.steps[index]
		if type(step) == "table" and step.sticky and not data.stepSkip[index] then
			data.stepSkip[index] = true
			changed = true
		end
	end
	if changed then pcall(RXP.SetStep, progress) end
end

-- Load a zone guide at its real first step (firstStep: past an opening step that jumps ahead). Its saved place is set
-- to step 1 first (LoadGuide returns to the saved place); after loading, any jump the opening step asked for
-- (addon.nextStep) is dropped and the first real step is set. said: the chat line's start ("Back to the start of the
-- previous guide").
local function loadGuideAtStart(guide, said)
	if type(guide) ~= "table" then return false end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if type(RXP.SaveGuideProgress) == "function" then pcall(RXP.SaveGuideProgress, guide, 1) end
	local left = RXP.currentGuide
	local ok, err = pcall(RXP.LoadGuide, RXP, guide)
	-- RestedXP can fail to open a guide, or open its empty guide instead (it declines inactive, internal or disabled
	-- guides), which left no guide at all: back to the guide you were on, with what went wrong
	local now = RXP.currentGuide
	if (not ok or type(now) ~= "table" or now.empty) and type(left) == "table" and not left.empty then
		local backName = tostring(left.displayname or left.name)
		local raw = RXP.GetGuideTable and RXP.GetGuideTable(left.group, left.name)
		pcall(RXP.LoadGuide, RXP, raw or left)
		ns.say(("RestedXP could not open %s%s; staying on %s."):format(tostring(guide.displayname or guide.name),
			not ok and (" (" .. tostring(err) .. ")") or "", backName))
		if ns.guideChanged then ns.guideChanged() end
		if ns.resetEmptyRetries then ns.resetEmptyRetries() end
		if ns.invalidate then ns.invalidate() end
		return false
	end
	if not ok then
		ns.say("Could not load that guide: " .. tostring(err))
		return false
	end
	local first = firstStep(now)
	local okAt, at = pcall(RXP.GetGuideProgress)
	if okAt and type(at) == "number" and not ns.isSecret(at) and at ~= first then
		RXP.nextStep = false -- the opening step's jump, asked for while it was loaded
		pcall(RXP.SetStep, first)
	end
	ns.settleEarlierSteps()
	-- read the new guide's steps afresh (see Snapshot.lua: a just-loaded guide may have none yet)
	if ns.guideChanged then ns.guideChanged() end
	if ns.resetEmptyRetries then ns.resetEmptyRetries() end
	if ns.invalidate then ns.invalidate() end
	ns.say(said .. ": " .. tostring(now.displayname or now.name or guide.displayname or guide.name) .. ".")
	return true
end

-- Back to the previous zone guide, at its real first step
function ns.backToPreviousGuide()
	local guide = previousGuide()
	if not guide then return false end
	return loadGuideAtStart(guide, "Back to the start of the previous guide")
end

-- On to the next zone guide (RestedXP's #next, read without loading: peekNextGuide), at its real first step
function ns.forwardToNextGuide()
	local group, name, t = ns.peekNextGuide(RXP.currentGuide)
	if not name then return false end
	local raw = RXP.GetGuideTable and RXP.GetGuideTable(group, name) or t
	return loadGuideAtStart(raw, "On to the start of the next guide")
end

function ns.stepBack()
	-- Shift+click: the previous zone guide, wherever you are in this one
	if IsShiftKeyDown and IsShiftKeyDown() and previousGuide() then
		ns.backToPreviousGuide()
		return
	end
	local target = previousStep()
	if not target then
		-- no step before this one that stays put: the previous zone guide
		ns.backToPreviousGuide()
		return
	end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	local okProgress, origin = pcall(RXP.GetGuideProgress)
	stepBackFrom(okProgress and type(origin) == "number" and origin or target + 1, target)
end

local function guideSteps()
	local ok, progress = pcall(RXP.GetGuideProgress)
	if not ok or type(progress) ~= "number" or ns.isSecret(progress) then return nil end
	local guide = RXP.currentGuide
	local steps = guide and not guide.empty and guide.steps
	if type(steps) ~= "table" then return nil end
	return progress, #steps
end

-- The guide after this one, worked out WITHOUT loading anything.
-- CONSTRAINT: RestedXP's functions.next(false) is not a safe look: when the next guide is for another season or mode,
-- or none of the names after #next is active and found as written, it calls functions.next(nil, ...) itself, which
-- LOADS a guide (functions.lua). The header asks "is there a next guide?" on every redraw, so that jumped guides on
-- its own. This follows the same rules (";" alternatives, "Group\Name", the level affix, condensed groups, the first
-- active one, else the last found; season / hardcore mismatches move on to that guide's own #next) and only reads.
local function guideTable(group, name)
	local get = RXP.GetGuideTable
	if type(get) ~= "function" then return nil end
	local ok, t = pcall(get, group, name)
	if ok and type(t) == "table" then return t, group end
	local condensed = type(RXP.condenseGroups) == "table" and RXP.condenseGroups
	local parent = condensed and condensed[group]
	if parent then
		for other, display in pairs(condensed) do
			if display == parent then
				ok, t = pcall(get, other, name)
				if ok and type(t) == "table" then return t, other end
			end
		end
	end
end

function ns.peekNextGuide(guide, depth)
	depth = depth or 0
	if depth > 6 or type(guide) ~= "table" or type(guide.next) ~= "string" or guide.next == "" then return nil end
	local found, foundGroup, last, lastGroup
	for spec in guide.next:gmatch("[^;]+") do
		spec = spec:gsub("^%s+", ""):gsub("%s+$", "")
		local group = guide.group or ""
		local name = spec:gsub("^%s*(.+)\\%s*", function(prefix) group = prefix return "" end)
		if type(RXP.affix) == "function" then
			local ok, renamed = pcall(string.gsub, name, "^(%d)-(%d%d?)", RXP.affix)
			if ok and renamed then name = renamed end
		end
		local t, g = guideTable(group, name)
		if t then
			last, lastGroup = t, g
			local okActive, active = true, true
			if RXP.IsGuideActive then okActive, active = pcall(RXP.IsGuideActive, t) end
			if okActive and active then found, foundGroup = t, g break end
		end
	end
	local t, g = found or last, found and foundGroup or lastGroup
	if not t then return nil end
	-- for another season or the other hardcore mode: RestedXP goes on to that guide's own next one
	local profile = ns.rxpProfile()
	local seasonOk = true
	if RXP.stepLogic and type(RXP.stepLogic.SeasonCheck) == "function" then
		local ok, result = pcall(RXP.stepLogic.SeasonCheck, t)
		seasonOk = not ok or result and true or false
	end
	local modeOk = not (t.hardcore and not profile.hardcore or t.softcore and profile.hardcore)
	if not (seasonOk and modeOk) then return ns.peekNextGuide(t, depth + 1) end
	return t.group or g, t.name, t
end

-- The name (and group) of the guide after this one, or nil; never loads anything. Asked on every header redraw: kept
-- per guide, its #next line and your level (which guides RestedXP offers can change with the level). RestedXP
-- registers its guides over the first moments after login, so "none found" is kept only a few seconds.
local NO_NEXT_KEEP = 5
local nextCache = setmetatable({}, { __mode = "k" })
function ns.nextGuideName()
	local guide = RXP.currentGuide
	if type(guide) ~= "table" then return nil end
	local level, spec, now = UnitLevel("player"), guide.next, GetTime and GetTime() or 0
	local known = nextCache[guide]
	if known and known.level == level and known.spec == spec and (known.name or now - known.at < NO_NEXT_KEEP) then
		return known.name, known.group
	end
	local group, name = ns.peekNextGuide(guide)
	if not (type(name) == "string" and name ~= "") then group, name = nil, nil end
	known = known or {}
	known.level, known.spec, known.at, known.name, known.group = level, spec, now, name, group
	nextCache[guide] = known
	return name, group
end

-- The restart button between < and >: to the guide's first step, and a second click back to the step you were on.
-- The step to return to is kept per guide (a new guide forgets it); RestedXP's SetStep(1) itself moves past sticky or
-- above-level opening steps.
local returnTo -- { guide = guide table, step = number }
local function restartState()
	local guide = RXP.currentGuide
	if returnTo and returnTo.guide ~= guide then returnTo = nil end
	return returnTo
end
function ns.canRestart()
	local guide = RXP.currentGuide
	if type(guide) ~= "table" or guide.empty then return false end
	if restartState() then return true end
	local ok, progress = pcall(RXP.GetGuideProgress)
	return ok and type(progress) == "number" and not ns.isSecret(progress) and progress > firstStep(guide)
end
function ns.restartPending()
	return restartState() ~= nil
end
function ns.restartTip()
	local back = restartState()
	if back then return ("Back to step %d, where you were."):format(back.step) end
	return "To the first step of this guide. Click again to come back."
end
-- The guide's real first step. Some guides open with a step that jumps away at once: ".maxlevel 43,SoSSkip" (an
-- optional step whose objective carries a label to jump to) sends anyone past that level to the label, halfway through
-- the guide, so SetStep(1) landed there. The first step taken is the first that is not sticky, not optional, not above
-- your level, not already skipped, and has no such jump.
function firstStep(guide)
	local steps = type(guide) == "table" and type(guide.steps) == "table" and guide.steps or {}
	local level = UnitLevel("player")
	if ns.isSecret(level) then level = nil end
	for index = 1, #steps do
		local step = steps[index]
		local plain = type(step) == "table" and not step.sticky and not step.optional
			and not (level and tonumber(step.level) and level < step.level) and not skippedStep(step)
		if plain then
			for _, e in ipairs(type(step.elements) == "table" and step.elements or {}) do
				if type(e) == "table" and e.ref then plain = false break end
			end
		end
		if plain then return index end
	end
	return 1
end

function ns.restartToggle()
	local guide = RXP.currentGuide
	if type(guide) ~= "table" or guide.empty then return end
	local back = restartState()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if back then
		returnTo = nil
		local ok, err = pcall(RXP.SetStep, back.step)
		if not ok then ns.say("Could not go back to step " .. back.step .. ": " .. tostring(err)) end
		return
	end
	local ok, progress = pcall(RXP.GetGuideProgress)
	if not ok or type(progress) ~= "number" or ns.isSecret(progress) or progress <= firstStep(guide) then return end
	returnTo = { guide = guide, step = progress }
	local okSet, err = pcall(RXP.SetStep, firstStep(guide))
	if not okSet then
		returnTo = nil
		ns.say("Could not go to the first step: " .. tostring(err))
	end
end

local function atLastStep()
	local progress, total = guideSteps()
	return progress ~= nil and progress >= total
end

-- > stays usable at the last step when there is a next guide: it starts that guide
function ns.canStepForward()
	local progress, total = guideSteps()
	if progress == nil then return false end
	return progress < total or ns.nextGuideName() ~= nil
end

function ns.stepForwardTip()
	local name = ns.nextGuideName()
	if atLastStep() then
		return name and ("Last step: start the next guide, " .. name .. ".") or "Last step of this guide."
	end
	return "Next step." .. (name and ("\nShift+click: on to the start of the next guide, " .. name .. ".") or "")
end

-- CONSTRAINT: SetStep(n) itself moves past sticky and above-level steps (GuideWindow.lua), as RestedXP's own skip does.
function ns.goToStep(index)
	local progress, total = guideSteps()
	index = tonumber(index)
	if not (progress and index) or index < 1 or index > total or index == progress then return end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	local ok, err = pcall(RXP.SetStep, index)
	if not ok then ns.say("Could not change step: " .. tostring(err)) end
end

function ns.stepForward()
	-- Shift+click: the next zone guide, wherever you are in this one
	if IsShiftKeyDown and IsShiftKeyDown() and ns.nextGuideName() then
		ns.forwardToNextGuide()
		return
	end
	local progress, total = guideSteps()
	if not progress then return end
	if progress < total then
		ns.goToStep(progress + 1)
		return
	end
	-- no steps left: RestedXP loads its next guide (functions.next with no arguments, as its own "next guide" does)
	local name = ns.nextGuideName()
	if not name then return end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	local ok, err = pcall(RXP.functions.next)
	if ok then ns.say("Starting the next guide: " .. name .. ".") else ns.say("Could not start the next guide: " .. tostring(err)) end
end

local function newBackButton()
	local button = CreateFrame("Button")
	button:RegisterForClicks("LeftButtonUp")
	button.upper = newTick(button, math.pi / 4)
	button.lower = newTick(button, -math.pi / 4)
	button:SetScript("OnEnter", function(self) self.hovered = true; updateBack(self); backTooltip(self) end)
	button:SetScript("OnLeave", function(self)
		self.hovered = nil
		updateBack(self)
		ns.releaseTooltip(GameTooltip, self)
	end)
	button:SetScript("OnClick", goBack)
	return button
end

-- Called for the first active line that has a skip box (Rows.lua addLine), after setSkipBox placed that box.
function ns.placeBackButton(line)
	local box = line.Box
	if not box then return end
	backButton = backButton or newBackButton()
	local button = backButton
	button:SetParent(line)
	local size = box:GetWidth()
	local scale = size / RXP_BOX
	button:SetSize(size, size)
	local length, thick = 4.2 * scale, 1.25 * scale
	button.upper:SetSize(length, thick)
	button.upper:SetPoint("CENTER", button, "CENTER", 0, 1.45 * scale)
	button.lower:SetSize(length, thick)
	button.lower:SetPoint("CENTER", button, "CENTER", 0, -1.45 * scale)
	button:ClearAllPoints()
	button:SetPoint("RIGHT", box, "LEFT", -PixelUtil.ConvertPixelsToUIForRegion(line.fontHeight * BACK_GAP, box), 0)
	button:SetFrameLevel(box:GetFrameLevel())
	button.hovered = button:IsMouseOver() or nil
	button:Show()
	updateBack(button)
end

function ns.hideBackButton()
	if backButton and backButton:IsShown() then
		ns.releaseTooltip(GameTooltip, backButton)
		backButton:Hide()
	end
end

function ns.setSkipBox(line, objective, active, centerX, centerY)
	local box = line.Box
	if not active or objective.note then
		if box then
			RXP.ActiveStepElementOnLeave(box)
			box:Hide()
		end
		return
	end
	if not box then
		box = newSkipBox(line)
		line.Box = box
	end
	line.element = objective.element
	box.hovered = box:IsMouseOver() or nil
	box:SetChecked(objective.done)
	local size = 2 * PixelUtil.ConvertPixelsToUIForRegion(line.fontHeight * RXP_BOX / TRACKER_TEXT_PT / 2, box)
	box:SetSize(size, size)
	sizeGlyphs(box, size)
	box:SetPoint("TOPLEFT", line, "TOPLEFT", PixelUtil.ConvertPixelsToUIForRegion(centerX - size / 2, box),
		PixelUtil.ConvertPixelsToUIForRegion(centerY + size / 2, box))
	box:SetFrameLevel(line:GetFrameLevel() + 1)
	box.hover:SetFrameLevel(box:GetFrameLevel() + 2)
	box:Show()
	updateSkipBox(box)
end

-- Why a guide jumped ahead. RestedXP passes steps by itself: the ones above your level (SetStep: level >= step.level),
-- ones you are past the level for ("Skip overleveled steps", functions.lua xp), and its auto-skips ("Disable step
-- skips" off: missing prerequisites, quests already done or not offered, ...), which leave a "Step skipped: ..." note
-- on the step. A few seconds after a guide starts, one chat line counts the steps passed by reason and names the
-- setting; /qt why lists the latest guide and step moves and whether this addon made any of them.
local NOTE_DELAY = 4
local SKIP_PREFIX = "Step skipped:"
local noted = {}

local function skipReason(step, level)
	if type(step) ~= "table" then return nil end
	if tonumber(step.level) and tonumber(step.level) > level then return "above your level" end
	local function fromText(text)
		if type(text) ~= "string" then return nil end
		local at = text:find(SKIP_PREFIX, 1, true) or (ns.L and text:find(ns.L(SKIP_PREFIX), 1, true))
		if at then return (text:sub(at):gsub("^[^:]*:%s*", ""):gsub("|r", "")) end
	end
	local reason = fromText(step.tooltipText)
	for _, element in ipairs(type(step.elements) == "table" and step.elements or {}) do
		if reason then break end
		if type(element) == "table" then
			reason = fromText(element.tooltipText)
			local below = not reason and element.tag == "xp" and not element.reverseLogic and tonumber(element.level)
			if below and level > below and ns.levelSkipOn() then reason = "you are past its level" end
		end
	end
	return reason
end

local function skipCounts(guide, progress)
	local level, counts, total = UnitLevel("player"), {}, 0
	for index = 1, math.min(progress - 1, #guide.steps) do
		local reason = skipReason(guide.steps[index], level)
		if reason then
			if not counts[reason] then counts[reason] = 0; counts[#counts + 1] = reason end
			counts[reason] = counts[reason] + 1
			total = total + 1
		end
	end
	return counts, total
end

local function hintFor(reason)
	if reason == "you are past its level" or reason:find("XP requirements", 1, true) then
		return "turn off \"Skip overleveled steps\" in RestedXP's settings"
	elseif reason == "above your level" then
		return "come back at that level"
	end
	return "tick \"Disable step skips\" in RestedXP's settings"
end

local function noteSkips(guide)
	if RXP.currentGuide ~= guide or type(guide) ~= "table" or type(guide.steps) ~= "table" then return end
	local okProgress, progress = pcall(RXP.GetGuideProgress)
	if not okProgress or type(progress) ~= "number" or ns.isSecret(progress) then return end
	local counts, total = skipCounts(guide, progress)
	local key = guide.key or guide.name
	if total < 3 or not key or noted[key] then return end
	noted[key] = true
	local parts, hints, seen = {}, {}, {}
	for _, reason in ipairs(counts) do
		parts[#parts + 1] = counts[reason] .. " " .. reason
		local hint = hintFor(reason)
		if not seen[hint] then seen[hint] = true; hints[#hints + 1] = hint end
	end
	ns.say(("RestedXP passed %d steps of %s by itself (%s). To follow them: %s, then restart the guide (/qt, Themes & "
		.. "guide). /qt why lists what moved the guide."):format(total, tostring(guide.displayname or guide.name),
		table.concat(parts, ", "), table.concat(hints, "; ")))
end

function ns.levelSkipOn()
	return ns.rxpProfile().enableXpStepSkipping ~= false
end

-- the latest guide and step moves: what, where, and whether this addon's code made it (its folder in the call stack)
local LOG_SIZE = 150
local moves = {} -- { time, kind = "load" | "step" | "finished" | "next", guide, step, now, byUs, flags, objectives }
local function progressNow()
	local ok, progress = pcall(RXP.GetGuideProgress)
	return ok and type(progress) == "number" and not ns.isSecret(progress) and progress or nil
end
local function guideLabel(guide)
	return type(guide) == "table" and tostring(guide.displayname or guide.name) or "?"
end
local function record(entry)
	entry.time = date and date("%H:%M:%S") or ""
	moves[#moves + 1] = entry
	if #moves > LOG_SIZE then table.remove(moves, 1) end
	if ns.whyChanged then ns.whyChanged() end
end
-- this addon's code made the call (its folder in the call stack): one of the tracker's buttons you clicked
local function byUs()
	local stack = type(debugstack) == "function" and debugstack(3, 14, 0) or ""
	return stack:find("RXPForeverTracker", 1, true) ~= nil
end

-- RestedXP's objective kinds in words
local OBJECTIVE_WORDS = {
	accept = "accept quest", turnin = "hand in quest", complete = "quest objective", collect = "collect item",
	["goto"] = "go to a place", xp = "level check", maxlevel = "level check", fly = "flight", fp = "flight path",
	hs = "hearthstone", home = "set hearthstone", use = "use item", cast = "cast spell", train = "train skill",
	vendor = "visit vendor", buy = "buy item", zoneskip = "zone check", subzoneskip = "zone check",
	isOnQuest = "quest log check", isQuestComplete = "quest complete check", isQuestTurnedIn = "quest done check",
}
local function objectiveWords(e)
	if type(e) ~= "table" or not e.tag then return nil end
	local id = e.questId or e.id or (type(e.ids) == "table" and e.ids[1])
	local text = (OBJECTIVE_WORDS[e.tag] or tostring(e.tag)) .. (id and (" " .. tostring(id)) or "")
	local note = type(e.tooltipText) == "string" and e.tooltipText:find(SKIP_PREFIX, 1, true)
		and e.tooltipText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^.-:%s*", "") or nil
	local state = note and ("skipped: " .. note) or e.skip and "skipped" or e.completed and "done" or not e.textOnly and "open" or nil
	return state and (text .. " (" .. state .. ")") or text
end
local function stepFacts(step)
	local flags, objectives = {}, {}
	if type(step) ~= "table" then return flags, objectives end
	local level = UnitLevel("player")
	if step.completed then flags[#flags + 1] = "RestedXP already counted it as done" end
	if tonumber(step.level) and tonumber(step.level) > level then
		flags[#flags + 1] = ("it needs level %d (you are %d)"):format(step.level, level)
	end
	if type(step.tooltipText) == "string" and step.tooltipText:find(SKIP_PREFIX, 1, true) then
		flags[#flags + 1] = step.tooltipText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	end
	if step.sticky then flags[#flags + 1] = "it stays open beside other steps (sticky)" end
	if step.requires then flags[#flags + 1] = "it waits for another step first" end
	for _, e in ipairs(type(step.elements) == "table" and step.elements or {}) do
		local words = objectiveWords(e)
		if words then objectives[#objectives + 1] = words end
	end
	return flags, objectives
end

-- every step RestedXP passes or lands on, with why: SetStep(n) moves on from a step marked done, one above your level,
-- a sticky one or one whose required step is open (GuideWindow.lua SetStep)
local function stepHook(n, n2)
	n = type(n) == "table" and n2 or n
	local guide = RXP.currentGuide
	local step = type(guide) == "table" and type(guide.steps) == "table" and guide.steps[n]
	local flags, objectives = stepFacts(step)
	record({ kind = "step", guide = guideLabel(guide), step = n, now = progressNow(), byUs = byUs(), flags = flags,
		objectives = objectives })
end

-- the moment RestedXP decides an active step is finished: which of its objectives made it so
local function completionHook()
	if not RXP.loadNextStep then return end
	local guide = RXP.currentGuide
	for _, step in ipairs(type(RXP.RXPFrame) == "table" and type(RXP.RXPFrame.activeSteps) == "table"
		and RXP.RXPFrame.activeSteps or {}) do
		if type(step) == "table" and step.completed then
			local flags, objectives = stepFacts(step)
			record({ kind = "finished", guide = guideLabel(guide), step = step.index, now = progressNow(), byUs = false,
				flags = flags, objectives = objectives })
		end
	end
end

-- One move in plain words: { headline, detail } (detail may be nil)
function ns.describeMove(m)
	local who = m.byUs and "you, with the tracker's buttons" or "RestedXP"
	if m.kind == "load" then
		return ("Opened the guide %s"):format(m.detail or m.guide), "by " .. who
	elseif m.kind == "next" then
		return ("Moved on to the next guide, %s"):format(m.guide), "by " .. who
	elseif m.kind == "finished" then
		local detail = #m.objectives > 0 and ("Its objectives: " .. table.concat(m.objectives, ", ")) or nil
		return ("Step %s was finished"):format(tostring(m.step)), detail
	end
	-- a step: landed on it, or passed it on the way
	if m.now == m.step then
		return ("Now on step %s of %s"):format(tostring(m.step), m.guide), "moved there by " .. who
	end
	local why = #m.flags > 0 and table.concat(m.flags, "; ") or nil
	local detail = why and ("Why: " .. why) or nil
	if #m.objectives > 0 then
		detail = (detail and (detail .. ". ") or "") .. "Its objectives: " .. table.concat(m.objectives, ", ")
	end
	return ("Passed step %s on the way to step %s"):format(tostring(m.step), tostring(m.now or "?")), detail
end

-- The window's summary: { guide, step, total, level, skipOver (on/off), autoSkip (on/off), skipped = { {reason, n} } }
function ns.whySummary()
	local profile = ns.rxpProfile()
	local out = {
		level = UnitLevel("player"), release = ns.rxpRelease and ns.rxpRelease() or "?",
		skipOver = profile.enableXpStepSkipping ~= false, autoSkip = not profile.disableAutoSkip, skipped = {},
	}
	local guide = RXP.currentGuide
	local progress = progressNow()
	if type(guide) == "table" and not guide.empty and type(guide.steps) == "table" and progress then
		out.guide, out.step, out.total = guideLabel(guide), progress, #guide.steps
		local counts = skipCounts(guide, progress)
		for _, reason in ipairs(counts) do out.skipped[#out.skipped + 1] = { reason, counts[reason] } end
	end
	return out
end
function ns.whyMoves() return moves end
function ns.clearMoves() wipe(moves); if ns.whyChanged then ns.whyChanged() end end

-- the same as plain text, to copy into a bug report
function ns.whyText()
	local s = ns.whySummary()
	local out = {}
	out[#out + 1] = ("RestedXP %s. Level %d. Skip overleveled steps: %s. Step skips: %s."):format(tostring(s.release),
		s.level, s.skipOver and "on" or "off", s.autoSkip and "on" or "off")
	if s.guide then
		out[#out + 1] = ("Current guide: %s, step %d of %d."):format(s.guide, s.step, s.total)
		if #s.skipped > 0 then
			local parts = {}
			for _, r in ipairs(s.skipped) do parts[#parts + 1] = r[2] .. " " .. r[1] end
			out[#out + 1] = "Steps RestedXP noted as skipped: " .. table.concat(parts, ", ") .. "."
		end
	end
	out[#out + 1] = ""
	if #moves == 0 then out[#out + 1] = "No guide or step moves yet this session." end
	for _, m in ipairs(moves) do
		local head, detail = ns.describeMove(m)
		out[#out + 1] = m.time .. "  " .. head .. (detail and (" - " .. detail) or "")
	end
	return table.concat(out, "\n")
end

-- /qt why: the window (WhyWindow.lua), or the text in chat when it cannot be built
function ns.printMoves()
	if ns.showWhyWindow and pcall(ns.showWhyWindow) then return end
	for line in ns.whyText():gmatch("[^\n]+") do DEFAULT_CHAT_FRAME:AddMessage(line) end
end

ns.hookRxp(RXP, "SetStep", stepHook, "RXP.SetStep")
ns.hookRxp(RXP, "UpdateStepCompletion", completionHook, "RXP.UpdateStepCompletion")
ns.hookRxp(RXP, "LoadGuide", function(_, guide)
	record({ kind = "load", guide = guideLabel(RXP.currentGuide),
		detail = guideLabel(type(guide) == "table" and guide or RXP.currentGuide), byUs = byUs() })
	local current = RXP.currentGuide
	if type(current) == "table" and not current.empty and C_Timer then
		C_Timer.After(NOTE_DELAY, function() noteSkips(current) end)
	end
end, "RXP.LoadGuide")
if type(RXP.functions) == "table" then
	ns.hookRxp(RXP.functions, "next", function()
		record({ kind = "next", guide = guideLabel(RXP.currentGuide), byUs = byUs() })
	end, "RXP.functions.next")
end
