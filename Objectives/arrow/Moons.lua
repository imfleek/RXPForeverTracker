local _, root = ...; local ns = root.objectives

local arrow = ns.arrow
if not arrow then return end

local moons = arrow.moons

local CIRCLE = {0.53, 0.51, 0.48, 0.46, 0.44, 0.41, 0.39, 0.37}
local MOON_INSET = 0.07
local SHRINK, DISC_MIN = 0.92, 0.14
local PIN_R, ARC_GAP, VISIBLE, PIN_GAP = 0.375, 0.06, 1.06, 2
local START, SWEEP = math.rad(-90), math.rad(140)
local WOBBLE = {{x = 0, y = 1, seconds = 2.2}, {x = 1, y = 0, seconds = 3.1}}
local WOBBLE_STAGGER = 0.4
local BADGE_ALPHA, BADGE_FONT = 0.9, 0.42

local curve = {}

arrow.moonButtons = {}
arrow.maxMoons = #CIRCLE

-- CONSTRAINT: wobble amplitude (sizeMoon) is min(disc*VISIBLE*ARC_GAP*0.45, PIN_GAP/2), matching
-- the tag clearance: at full excursion the art stays clear of the neighbor ring, the pin nose and
-- the yards tag. Unsnapped keeps it smooth.
local function unsnap(textures)
	for _, texture in ipairs(textures) do
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
	end
end

local function moonEnter(self)
	self.art.glow:Show()
	ns.buttonEnter(self)
end

local function moonLeave(self)
	self.art.glow:Hide()
	self.art.pushed:Hide()
	ns.hideTooltip()
end

local function moonDown(self)
	self.art.pushed:Show()
end

local function moonUp(self)
	self.art.pushed:Hide()
end

function arrow.newMoon(index)
	local button = arrow.newButton()
	local art = button.art
	ns.buildArtRing(button)
	button:HookScript("OnClick", ns.confirmClick)
	button:SetScript("OnEnter", moonEnter)
	button:SetScript("OnLeave", moonLeave)
	button:SetScript("OnMouseDown", moonDown)
	button:SetScript("OnMouseUp", moonUp)
	art.wobble = {}
	art.wobbleMove = {}
	for key, bounce in ipairs(WOBBLE) do
		local group = art:CreateAnimationGroup()
		local move = group:CreateAnimation("Translation")
		move:SetDuration(bounce.seconds + (index - 1) * WOBBLE_STAGGER)
		move:SetSmoothing("IN_OUT")
		group:SetLooping("BOUNCE")
		art.wobble[key] = group
		art.wobbleMove[key] = move
	end
	unsnap(button.rim)
	unsnap({button.armGlow, button.icon, button.mark, button.cross})
	return button
end

function arrow.sizeMoon(button, disc)
	if button.size == disc then return end
	button.size = disc
	button:SetSize(disc, disc)
	local inset = disc * MOON_INSET
	button:SetHitRectInsets(inset, inset, inset, inset)
	button.art:SetSize(disc, disc)
	local amp = math.min(disc * VISIBLE * ARC_GAP * 0.45, PIN_GAP / 2)
	for key, bounce in ipairs(WOBBLE) do
		button.art.wobbleMove[key]:SetOffset(bounce.x * amp, bounce.y * amp)
	end
	ns.sizeCircle(button, disc)
end

local function arcAt(disc, mirrored)
	local ring = disc * VISIBLE / 2
	local radius = curve.pin * PIN_R + PIN_GAP + ring
	local step = 2 * math.asin(ring * (1 + ARC_GAP) / radius)
	local fits = (curve.count - 1) * step <= SWEEP
	for index = 1, curve.count do
		local angle = START - (index - 1) * step
		if mirrored then angle = math.pi - angle end
		local spot = moons[index] or {}
		moons[index] = spot
		spot.x, spot.y = curve.x + radius * math.cos(angle), curve.y + radius * math.sin(angle)
		if spot.x < ring or spot.x > curve.width - ring or spot.y < ring or spot.y > curve.height - ring then
			fits = false
		end
	end
	return ring, fits
end

-- CONSTRAINT: with neither side fitting, `moons` must end holding the left curve.
local function fitSide(disc)
	local ring, fits = arcAt(disc, false)
	if fits then return ring, true, false end
	local mirroredRing, mirroredFits = arcAt(disc, true)
	if mirroredFits then return mirroredRing, true, true end
	return (arcAt(disc, false)), false, false
end

function arrow.layout(count, x, y, pin)
	moons.visible = count
	if count == 0 then return end
	curve.count, curve.x, curve.y, curve.pin = count, x, y, pin
	curve.width, curve.height = UIParent:GetWidth(), UIParent:GetHeight()
	-- CONSTRAINT: sticky fit: the last accepted (disc, side) is retried first and kept while it fits, so a pin that
	-- wobbles across a fit boundary cannot flip-flop the arc between shrink steps or sides.
	local fresh = pin * CIRCLE[count]
	local sticky = moons.fitCount == count and moons.fitDisc
	local disc, ring, fits, mirrored
	if sticky then
		ring, fits, mirrored = arcAt(sticky, moons.fitMirrored)
	end
	if not fits then
		disc, ring, fits, mirrored = fresh, fitSide(fresh)
	else
		disc = sticky
	end
	while not fits and disc > pin * DISC_MIN do
		disc = math.max(disc * SHRINK, pin * DISC_MIN)
		ring, fits, mirrored = fitSide(disc)
	end
	moons.fitCount, moons.fitDisc, moons.fitMirrored = count, disc, mirrored
	moons.side, moons.centerX, moons.centerY, moons.ring = mirrored and 1 or -1, x, y, ring
	moons.hover = ring * 1.5
	for index = 1, count do
		local spot = moons[index]
		spot.x = Clamp(spot.x, ring, curve.width - ring)
		spot.y = Clamp(spot.y, ring, curve.height - ring)
	end
	return disc
end

function arrow.buildBadge(onEnter)
	local badge = CreateFrame("Frame", nil, UIParent)
	badge:EnableMouse(true)
	badge.back = badge:CreateTexture(nil, "BACKGROUND")
	badge.back:SetTexture(arrow.DISC)
	badge.back:SetVertexColor(unpack(arrow.WINDOW_BACK))
	badge.back:SetAlpha(BADGE_ALPHA)
	badge.back:SetPoint("CENTER")
	badge.art = badge
	ns.buildArtRing(badge)
	badge.ring:SetDrawLayer("BORDER")
	badge.text = badge:CreateFontString(nil, "OVERLAY")
	badge.text:SetPoint("CENTER")
	badge.text:SetTextColor(unpack(arrow.GOLD_TEXT))
	badge:SetScript("OnEnter", onEnter)
	badge:Hide()
	return badge
end

function arrow.sizeBadge(badge, disc, count)
	local size = disc * VISIBLE
	if badge.size ~= size then
		badge.size = size
		badge:SetSize(size, size)
		badge.back:SetSize(size, size)
		ns.sizeRing(badge, size)
		arrow.setFont(badge.text, (GameFontNormal:GetFont()), size * BADGE_FONT)
	end
	if badge.count ~= count then
		badge.count = count
		badge.text:SetText("+" .. count)
	end
end
