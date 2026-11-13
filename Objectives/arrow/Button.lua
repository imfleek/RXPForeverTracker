local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp
local af = RXP.arrowFrame
if not af then return end

local db = ns.db
local RXP_TEXTURES = "Interface\\AddOns\\RXPGuides\\Textures\\"

local arrow = {
	FONT_MIN = 8,
	DISC = RXP_TEXTURES .. "white_circle",
	WINDOW_BACK = { 0.09, 0.08, 0.06 },
	GOLD_TEXT = { 0.93, 0.78, 0.4 },
	moons = { visible = 0, side = -1, centerX = 0, centerY = 0, ring = 0 },
}
ns.arrow = arrow

function arrow.enabled()
	return db.enabled and db.arrowButton
end

-- CONSTRAINT: shown and drawing (alpha 0 while the client has no position), and not "~" on the wrong continent. The
-- "Hide waypoint arrow" setting stops DrawArrow before the frame hides.
function arrow.points()
	return af:IsShown() and af:GetAlpha() > 0 and not af.wrongContinent
end

function arrow.geometry()
	local x, y = af:GetCenter()
	if not x then return end
	local scale = ns.relativeScale(af)
	return x * scale, y * scale, af:GetWidth() * scale
end

function arrow.fontSize(size)
	return math.max(arrow.FONT_MIN, Round(size))
end

function arrow.setFont(fontString, font, size)
	size = arrow.fontSize(size)
	fontString:SetFont(font, size, "OUTLINE")
	return size
end

-- CONSTRAINT: the secure button is a bare hit rect; its art is a plain frame so it can wobble and fade in combat.
function arrow.newButton(armTexture)
	local button = ns.newSecureButton()
	local art = CreateFrame("Frame", nil, UIParent)
	art:EnableMouse(false)
	art:SetPoint("CENTER", button, "CENTER")
	button.art = art
	ns.buildCircleArt(button, art, art, armTexture)
	button:Hide()
	art:Hide()
	return button
end

function arrow.showButton(button, strata, level, artLevel)
	local art = button.art
	button:SetFrameStrata(strata)
	button:SetFrameLevel(level)
	art:SetFrameStrata(strata)
	art:SetFrameLevel(artLevel or level + 1)
	art:SetAlpha(1)
	button:Show()
	art:Show()
	if art.wobble then
		for _, group in ipairs(art.wobble) do
			-- CONSTRAINT: camelot 16001 ships no AnimationGroup resume method; groups are never paused or stopped, so
			-- progress survives hide/show and Play only starts a never-played group. Wobble runs while hidden (accepted).
			if not group:IsPlaying() then group:Play() end
		end
	end
	if button.use then ns.updateCooldown(button) end
end

function arrow.hideButton(button)
	if not ns.hideCircle(button, button.art) then return end
end

-- CONSTRAINT: the arrow keeps its own portraits (the tracker's are parented to its circles); a portrait follows its
-- unit across buttons. The art is a plain frame, so portraits draw in combat.
local portraits = ns.newPortraits(16, true)

function arrow.drawPortrait(button, token, redraw)
	local portrait, new = portraits:acquire(button.use.name)
	if redraw or new then SetPortraitTexture(portrait, token) end
	portrait.seen = GetTime()
	portraits:attach(button, portrait, button.art)
	button.mark:Hide()
end

function arrow.setArt(button, use)
	local name = use and use.type == "unit" and use.name or nil
	local portrait = name and portraits:get(name) or nil
	portraits:attach(button, portrait, button.art)
	button.icon:SetShown(use ~= nil and ns.drawsIcon(use))
	ns.setMark(button, use, portrait)
end
