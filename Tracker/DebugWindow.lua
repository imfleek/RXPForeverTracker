-- /qt debug: the tracker's layout details in a window in the same look as the /qt settings window, the Prerequisite
-- Journal and "Why did guide skip?" (the theme kit from Config.lua), as plain text ready to copy into a bug report.
--
-- "Copy all and close": WoW does not let addons write to the clipboard (CopyToClipboard is restricted to Blizzard's
-- own code), so the button selects all of the text and waits for Ctrl+C; the window closes once it is copied.
-- Escape or the X closes it without copying.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api

local WIDTH, HEIGHT, PAD = 640, 460, 14
local frame, scroll, box, copyButton, hint, waitingForCopy

local HINT_IDLE = "Drag the title bar to move. Escape closes."
local HINT_COPY = "|cffffd100All text is selected: press Ctrl+C to copy it. The window then closes.|r"

local function stopWaiting()
	waitingForCopy = false
	if hint then hint:SetText(HINT_IDLE) end
end

local function selectAll()
	box:SetFocus()
	box:HighlightText()
	scroll:SetVerticalScroll(0)
end

local function copyAll()
	waitingForCopy = true
	selectAll()
	hint:SetText(HINT_COPY)
end

local function build()
	local k = api.themeKit
	local C = k.C
	local f = k.create("Frame", "RXPForeverTrackerDebugFrame", UIParent)
	frame = f
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if UISpecialFrames then tinsert(UISpecialFrames, "RXPForeverTrackerDebugFrame") end

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
	title:SetText("Quest tracker debug")
	local close = k.create("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(28, 28)
	close:SetPoint("TOPRIGHT", -3, -4)
	close:SetFrameLevel(bar:GetFrameLevel() + 5)
	close:HookScript("OnClick", function() f:Hide() end)

	-- the text, in a dark panel like the settings window's
	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT", PAD, -40)
	panel:SetPoint("BOTTOMRIGHT", -PAD, 46)
	k.solid(panel, "BACKGROUND", C.panel, 1):SetAllPoints()
	k.border(panel, C.panelEdge, 1, "BORDER")

	scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 10, -8)
	scroll:SetPoint("BOTTOMRIGHT", -10, 8)
	box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetWidth(WIDTH - 2 * PAD - 24)
	box:SetTextColor(C.value[1], C.value[2], C.value[3])
	scroll:SetScrollChild(box)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max((box:GetHeight() or 0) - (self:GetHeight() or 0), 0)
		self:SetVerticalScroll(math.min(math.max((self:GetVerticalScroll() or 0) - delta * 40, 0), max))
	end)
	-- read only: typing puts the report back as it was
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self.qtsText then self:SetText(self.qtsText); self:HighlightText() end
	end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	-- Ctrl+C while waiting: let the copy happen, then close
	box:SetScript("OnKeyDown", function(_, key)
		if waitingForCopy and key == "C" and IsControlKeyDown and IsControlKeyDown() then
			C_Timer.After(0, function()
				f:Hide()
				DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RXP ForeverTracker|r debug details copied.")
			end)
		end
	end)
	box:SetScript("OnEditFocusLost", function() if waitingForCopy then stopWaiting() end end)

	-- footer, in the settings window's style
	copyButton = k.makeButton(f, "Copy all and close", 150, copyAll)
	copyButton:SetPoint("BOTTOMRIGHT", -PAD, 12)
	hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOMLEFT", PAD, 18)
	hint:SetPoint("RIGHT", copyButton, "LEFT", -10, 0)
	hint:SetJustifyH("LEFT")
	hint:SetTextColor(C.subLabel[1], C.subLabel[2], C.subLabel[3])

	f:SetScript("OnHide", function() stopWaiting(); box:ClearFocus() end)
	f:Hide() -- new frames start shown; the first Show lays it out
end

function api.showDebugWindow(lines)
	if not api.themeKit then
		for _, text in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RXP ForeverTracker|r " .. text) end
		return
	end
	if not frame then build() end
	-- plain text for a bug report: no colour codes
	local text = table.concat(lines, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	box.qtsText = text
	box:SetText(text)
	box:SetCursorPosition(0)
	stopWaiting()
	frame:Show()
	scroll:SetVerticalScroll(0)
end
