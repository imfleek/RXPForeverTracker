local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp

-- RestedXP's colour codes for guide words; plain text when a colour (or the table) is not there
function ns.paint(text, token)
	local colors = RXP.guideTextColors
	local code = type(colors) == "table" and colors[token]
	if type(code) ~= "string" then return text end
	return WrapTextInColorCode(text, code)
end

-- The font chosen in the settings window (Tracker/Fonts.lua) replaces RestedXP's theme font; "Game default" keeps it.
local function chosenFont()
	local trackerApi = root.tracker and root.tracker.api
	return trackerApi and trackerApi.fontPath and trackerApi.fontPath() or nil
end

-- RestedXP's theme font and text colour (its newer window's theme, or the classic one); the game's quest font and
-- white when a theme or a field of it is not there
local DEFAULT_COLOR = { 1, 1, 1, 1 }
local function defaultFont()
	local font = ObjectiveTrackerLineFont and ObjectiveTrackerLineFont.GetFont and ObjectiveTrackerLineFont:GetFont()
	return font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
local function colorOrDefault(c)
	return type(c) == "table" and tonumber(c[1]) and c or DEFAULT_COLOR
end

function ns.textStyle()
	local v2 = RXP.v2
	local theme, color
	if type(v2.IsGuideWindowEnabled) == "function" and v2:IsGuideWindowEnabled() and type(v2.GetTheme) == "function" then
		theme = v2:GetTheme()
		color = type(theme) == "table" and type(theme.textColor) == "table" and theme.textColor.common
	else
		theme = RXP.activeTheme
		color = type(theme) == "table" and theme.textColor
	end
	local font = type(theme) == "table" and type(theme.font) == "string" and theme.font or defaultFont()
	return chosenFont() or font, colorOrDefault(color)
end

local NO_BARS = {}
function ns.timerBars()
	local host = RXP.RXPFrame.BarContainer
	return type(host) == "table" and type(host.bars) == "table" and host.bars or NO_BARS
end

function ns.activeTimer()
	local now = GetTime()
	local label, start, expires
	for name, bar in pairs(ns.timerBars()) do
		local ends = bar.running and bar.exp
		if ends and ends > now and (not expires or ends > expires) then label, start, expires = name, bar.start, ends end
	end
	return label, start, expires
end
