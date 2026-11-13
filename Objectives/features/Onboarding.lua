local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp
local L = ns.L
local db = ns.db

local SHOW_DELAY = 4
local frame, body, shownGuide, enteredAt

local function setOnboarded(state)
	local key = ns.playerGUID()
	if key then db.onboarded[key] = state end
end

local function isOnboarded()
	local key = ns.playerGUID()
	return key == nil or db.onboarded[key]
end

local function guideName()
	local guide = RXP.currentGuide
	if guide and not guide.empty then return RXP.GetGuideName(guide) end
end

local function highlight(text)
	return ns.paint(text, "RXP_FRIENDLY_")
end

local function bodyText(name)
	return table.concat({
		"1. " .. (name and "Active guide: " .. highlight(name) .. ". Pick another below if you prefer."
			or highlight("Choose a guide") .. " below. RestedXP does the quest work for you."),
		"2. Your steps appear in the " .. highlight("All Objectives") .. " tracker on the right.",
		"3. The round " .. highlight("RestedXP icon") .. " at the top of that section shows or hides RestedXP's own windows.",
	}, "\n")
end

-- CONSTRAINT: OnHide also fires when UIParent hides (Alt-Z), so the dismissal is recorded here, not in OnHide.
local function dismiss()
	setOnboarded(true)
	frame:Hide()
end

local function addButton(text, point, x, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(170, 24)
	button:SetPoint(point, x, 14)
	button:SetText(L(text))
	button:SetScript("OnClick", onClick)
end

local function build()
	frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplate")
	frame:SetSize(380, 190)
	frame:SetPoint("TOP", 0, -60)
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:Hide()
	frame.TitleText:SetText(L("Welcome to RestedXP"))
	frame.CloseButton:SetScript("OnClick", dismiss)

	body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	body:SetPoint("TOPLEFT", 16, -36)
	body:SetPoint("TOPRIGHT", -16, -36)
	body:SetJustifyH("LEFT")
	body:SetSpacing(6)

	addButton("Browse Guides", "BOTTOMLEFT", 16, function() ns.showGuideMenu("cursor") end)
	addButton("Import guide", "BOTTOMRIGHT", -16, function() RXP.guideImporter:Open() end)
end

local function show()
	if not frame then build() end
	shownGuide = guideName()
	body:SetText(bodyText(shownGuide))
	frame:Show()
end

function ns.showWelcome()
	setOnboarded(nil)
	show()
end

function ns.onboard()
	if frame and frame:IsShown() then
		if guideName() ~= shownGuide then dismiss() end
	elseif enteredAt and GetTime() - enteredAt >= SHOW_DELAY and not InCombatLockdown() and not isOnboarded() then
		show()
	end
end

ns.listen({
	PLAYER_ENTERING_WORLD = function()
		enteredAt = GetTime()
		C_Timer.After(SHOW_DELAY, ns.invalidate)
	end,
})
