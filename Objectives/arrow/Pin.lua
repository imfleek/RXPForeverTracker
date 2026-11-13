local ADDON, root = ...; local ns = root.objectives

local arrow = ns.arrow
if not arrow then return end

local RXP = ns.rxp
local af = RXP.arrowFrame
local moons = arrow.moons
local GOLD_TEXT, WINDOW_BACK = arrow.GOLD_TEXT, arrow.WINDOW_BACK

local TEXTURES = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\"
local BODY, GOLD = TEXTURES .. "arrow_body.tga", TEXTURES .. "arrow_gold.tga"
local BODY_PLAIN, GOLD_PLAIN = TEXTURES .. "arrow_body_plain.tga", TEXTURES .. "arrow_gold_plain.tga"
local TIMER_RING = TEXTURES .. "arrow_timer.tga"
local SOFT_DISC = "Interface\\AddOns\\RXPGuides\\Textures\\blur_mask"

local PIN_SCALE = 1.1
local PIN, WINDOW, SHADOW, HALO, MARK = 1.28, 0.64, 1.0, 1.35, 0.8
local SHADOW_DROP = 0.03
local SLATE, DARK_SLATE = {0.18, 0.21, 0.38}, {0.15, 0.15, 0.17}
local HALO_COLOR = {1, 0.88, 0.54}
local SHADOW_ALPHA, HALO_ALPHA, HIGHLIGHT_ALPHA, PIN_ALPHA = 0.45, 0.35, 0.35, 0.8
local LOGO, LOGO_FILL = "rxp_logo-64", 1.14
local COVER_INSET = (1 - 1 / PIN_SCALE) / 2
local PIN_ART_LEVEL, CLOCK_LEVEL, CLOCK_RING_LEVEL = 5, 7, 8

local TEXT_GAP, FLIP, BACK, DWELL, TEXT_CLEAR, TEXT_PAD = 0.4, 0.8, 0.5, 0.4, 2, 2
local FADE_OUT, FADE_IN = 0.12, 0.18
local FONT = 0.18

local CLOCK_TEXT, CLOCK_FIT = 0.5, 0.92
local MINUTE, HOUR = 60, 3600

local cover, coverTip
local tag = {}
local lastDark, lastLogoPath
local lastR, lastG, lastB

-- CONSTRAINT: the tooltip owner cannot tell hover: a pin with no use and no timer has no owner.
local function hovering()
	return cover.hovered and cover:IsMouseOver()
end

local function refreshTip()
	if hovering() then
		ns.hideTooltip()
		coverTip()
	end
end

arrow.PIN_SCALE = PIN_SCALE


local function syncPin()
	local art = cover.art
	local theme = RXP.activeTheme
	local dark = theme ~= nil and theme.name == "DarkMode"
	-- Waypoint arrow > Arrow colour: the pin's body (and RestedXP's own chevron) in that colour; none = the theme's
	local custom = type(ns.db.arrowColor) == "table" and ns.db.arrowColor or nil
	-- compared as numbers (no string built on every frame)
	local r, g, b = custom and custom[1], custom and custom[2], custom and custom[3]
	local mode = custom and "custom" or (dark and "dark" or "slate")
	if mode ~= lastDark or r ~= lastR or g ~= lastG or b ~= lastB then
		lastDark, lastR, lastG, lastB = mode, r, g, b
		if custom then
			art.body:SetVertexColor(custom[1], custom[2], custom[3])
			if af.texture then af.texture:SetVertexColor(custom[1], custom[2], custom[3]) end
		else
			art.body:SetVertexColor(unpack(dark and DARK_SLATE or SLATE))
			if af.texture then af.texture:SetVertexColor(1, 1, 1) end
		end
	end
	-- and its opacity (the pin and RestedXP's arrow frame, text included)
	local alpha = math.min(math.max(tonumber(ns.db.arrowAlpha) or 1, 0.1), 1)
	if cover:GetAlpha() ~= alpha then cover:SetAlpha(alpha) end
	if af.GetAlpha and af:GetAlpha() ~= alpha then af:SetAlpha(alpha) end
	local path = theme and theme.texturePath
	if path ~= lastLogoPath then
		lastLogoPath = path
		art.logo:SetTexture(ns.texture(LOGO))
	end
	local plain = not arrow.points()
	if plain ~= cover.plain then
		cover.plain = plain
		local texture = plain and BODY_PLAIN or BODY
		art.body:SetTexture(texture)
		art.gold:SetTexture(plain and GOLD_PLAIN or GOLD)
		art.highlight:SetTexture(texture)
		cover.armGlow:SetTexture(texture)
	end
	local rotation = plain and 0 or af.orientation
	if rotation ~= cover.rotation then
		cover.rotation = rotation
		for _, texture in ipairs(art.nose) do texture:SetRotation(rotation) end
	end
end

-- the settings window changed the arrow's colour or opacity
function ns.applyArrowLook()
	lastDark = nil
	if cover and cover.art then pcall(syncPin) end
end

local function alphaTo(region, alpha)
	if region:GetAlpha() ~= alpha then region:SetAlpha(alpha) end
end

-- CONSTRAINT: RestedXP's chevron and text are hidden by a region's alpha (allowed in combat), never by Hide: DrawArrow
-- keeps writing them.
function arrow.shroud(dimmed)
	local alpha = (cover:IsShown() and not dimmed) and 0 or 1
	alphaTo(af.texture, alpha)
	alphaTo(af.text, alpha)
end

local function tagStart(below, pin, fontSize)
	if moons.visible == 0 then return nil end
	local gap = pin * TEXT_GAP
	local low, high = gap, gap + fontSize + TEXT_PAD
	if below then low, high = -high, -gap end
	local start
	for index = 1, moons.visible do
		local moon = moons[index]
		local offsetX, offsetY = moon.x - moons.centerX, moon.y - moons.centerY
		if math.abs(offsetY - Clamp(offsetY, low, high)) < moons.ring then
			if moons.side < 0 then
				start = math.max(start or -math.huge, offsetX + moons.ring + TEXT_CLEAR)
			else
				start = math.min(start or math.huge, offsetX - moons.ring - TEXT_CLEAR)
			end
		end
	end
	return start
end

local function layoutTag(hasYards, below, pin, fontSize, start)
	tag.shapeYards, tag.shapeBelow, tag.shapePin, tag.shapeStart, tag.ready = hasYards, below, pin, start, true
	tag.yardsText = nil
	local yards = tag.yards
	local edge = start and (moons.side < 0 and "LEFT" or "RIGHT")
	yards:SetJustifyH(edge or "CENTER")
	yards:ClearAllPoints()
	yards:SetHeight(fontSize + TEXT_PAD)
	yards:SetShown(hasYards)
	local gap = pin * TEXT_GAP
	local anchor = (below and "TOP" or "BOTTOM") .. (edge or "")
	yards:SetPoint(anchor, cover.art, "CENTER", start or 0, below and -gap or gap)
end

local function tagSide(now)
	local up = math.cos(af.orientation)
	if tag.textBelow == nil then tag.textBelow, tag.sideSince = true, now end
	local want = tag.textBelow
	if tag.textBelow and up < -FLIP then want = false elseif not tag.textBelow and up > -BACK then want = true end
	if want ~= tag.textBelow and now - tag.sideSince >= DWELL then tag.textBelow, tag.sideSince = want, now end
	return tag.textBelow
end

-- CONSTRAINT: RestedXP's text has no hook and changes with its distance, so GetText is polled every frame; the yards
-- are its last line.
local function syncTag()
	local source = af.text
	local font, sourceSize = source:GetFont()
	local pin = cover.size
	local fontSize = arrow.fontSize(sourceSize or pin * FONT)
	if font and (font ~= tag.font or fontSize ~= tag.fontSize) then
		tag.font, tag.fontSize = font, fontSize
		arrow.setFont(tag.yards, font, fontSize - 1)
		tag.ready = nil
	end
	local yards
	if arrow.points() then
		local text = source:GetText() or ""
		if text ~= tag.sourceText then tag.sourceText, tag.sourceYards = text, text:match("[^\n]*$") end
		yards = tag.sourceYards
	end
	local now = GetTime()
	local below, hasYards = tagSide(now), yards ~= nil
	local start = hasYards and tagStart(below, pin, fontSize) or nil
	if start then start = math.floor(start * 2 + 0.5) / 2 end
	local changed = not tag.ready or tag.shapeYards ~= hasYards or tag.shapeBelow ~= below or tag.shapePin ~= pin
		or tag.shapeStart ~= start
	local alpha = tag.alpha or 1
	if changed then
		if not tag.ready then
			layoutTag(hasYards, below, pin, fontSize, start)
			alpha, tag.fade = 1, nil
		elseif tag.fade ~= "out" then
			tag.fade, tag.fadeSince = "out", now - (1 - alpha) * FADE_OUT
		end
	end
	if tag.fade == "out" then
		alpha = 1 - (now - tag.fadeSince) / FADE_OUT
		if alpha <= 0 then
			alpha, tag.fade, tag.fadeSince = 0, "in", now
			layoutTag(hasYards, below, pin, fontSize, start)
		end
	elseif tag.fade == "in" then
		alpha = (now - tag.fadeSince) / FADE_IN
		if alpha >= 1 then alpha, tag.fade = 1, nil end
	end
	if alpha ~= tag.alpha then
		tag.alpha = alpha
		tag.yards:SetAlpha(alpha)
	end
	if hasYards and tag.shapeYards and yards ~= tag.yardsText then
		tag.yardsText = yards
		tag.yards:SetText(yards)
		tag.yards:SetWidth(0)
		tag.yards:SetWidth(tag.yards:GetStringWidth() + TEXT_PAD)
	end
end

local function clockText(seconds)
	if seconds >= HOUR then
		return string.format("%d:%02d:%02d", math.floor(seconds / HOUR), math.floor(seconds / MINUTE) % MINUTE,
			seconds % MINUTE)
	elseif seconds >= MINUTE then
		return string.format("%d:%02d", math.floor(seconds / MINUTE), seconds % MINUTE)
	end
	return tostring(seconds)
end

local function fitClock(text)
	local clock = cover.art.clock
	local window = cover.size * WINDOW
	local font = GameFontNormal:GetFont()
	local size = arrow.setFont(clock.text, font, window * CLOCK_TEXT)
	clock.text:SetText(text)
	while size > arrow.FONT_MIN and clock.text:GetStringWidth() > window * CLOCK_FIT do
		size = arrow.setFont(clock.text, font, size - 1)
		clock.text:SetText(text)
	end
end

-- CONSTRAINT: SetCooldown runs only when the timer's start or end changes; the same one again restarts the swipe.
function arrow.syncTimer()
	local clock = cover.art.clock
	local label, start, expires = ns.activeTimer()
	if not expires then
		if clock:IsShown() then
			clock:Hide()
			clock.ring:Clear()
			clock.label, clock.start, clock.expires, clock.seconds, clock.time = nil, nil, nil, nil, nil
			refreshTip()
		end
		return
	end
	if not clock:IsShown() then clock:Show() end
	if label ~= clock.label then
		clock.label = label
		refreshTip()
	end
	if start ~= clock.start or expires ~= clock.expires then
		clock.start, clock.expires = start, expires
		clock.ring:SetCooldown(start, expires - start)
	end
	local color = RXP.activeTheme.mapPins
	if color[1] ~= clock.red or color[2] ~= clock.green or color[3] ~= clock.blue then
		clock.red, clock.green, clock.blue = color[1], color[2], color[3]
		clock.ring:SetSwipeColor(color[1], color[2], color[3], 1)
	end
	local seconds = math.ceil(expires - GetTime())
	if seconds ~= clock.seconds then
		clock.seconds = seconds
		local text = clockText(seconds)
		if clock.time and #text == #clock.time then clock.text:SetText(text) else fitClock(text) end
		clock.time = text
	end
end

function arrow.pinTick()
	if not cover:IsShown() then return end
	syncPin()
	syncTag()
	arrow.syncTimer()
end

local function buildClock(art)
	local clock = CreateFrame("Frame", nil, art)
	clock:EnableMouse(false)
	clock:SetPoint("CENTER")
	local back = clock:CreateTexture(nil, "BACKGROUND")
	back:SetTexture(arrow.DISC)
	back:SetVertexColor(unpack(WINDOW_BACK))
	back:SetAllPoints()
	clock.text = clock:CreateFontString(nil, "OVERLAY")
	clock.text:SetFontObject("GameFontNormal")
	clock.text:SetTextColor(unpack(GOLD_TEXT))
	clock.text:SetPoint("CENTER")
	clock.ring = CreateFrame("Cooldown", nil, clock, "CooldownFrameTemplate")
	-- CONSTRAINT: CooldownFrameTemplate anchors TOPLEFT and BOTTOMRIGHT to the parent, overriding SetSize.
	clock.ring:ClearAllPoints()
	clock.ring:SetPoint("CENTER")
	clock.ring:SetSwipeTexture(TIMER_RING)
	clock.ring:SetDrawEdge(false)
	clock.ring:SetDrawBling(false)
	clock.ring:SetHideCountdownNumbers(true)
	clock.ring:EnableMouse(false)
	clock.ring.noCooldownCount = true
	clock:Hide()
	return clock
end

function coverTip()
	local label = cover.art.clock.label
	local timed = label ~= nil and label ~= ""
	local tooltip = timed and ns.getTooltip()
	if cover.use then
		ns.buttonEnter(cover)
	elseif timed then
		tooltip:SetOwner(cover, "ANCHOR_RIGHT")
	end
	if timed then
		if cover.use then tooltip:AddLine(" ") end
		tooltip:AddLine(label)
		tooltip:Show()
	end
end

local function coverEnter()
	cover.hovered = true
	if cover.use then
		cover.art.highlight:Show()
		cover.art.halo:Show()
	end
	coverTip()
end

local function coverLeave()
	cover.hovered = false
	cover.art.highlight:Hide()
	cover.art.halo:Hide()
	ns.releaseOwnTooltip(cover)
end

local function buildTag(art)
	tag.yards = art:CreateFontString(nil, "OVERLAY")
	tag.yards:SetFontObject("GameFontNormal")
	tag.yards:SetWordWrap(false)
	tag.yards:SetJustifyV("MIDDLE")
	tag.yards:SetShadowOffset(1, -1)
	tag.yards:SetShadowColor(0, 0, 0, 0.6)
	tag.yards:SetTextColor(unpack(GOLD_TEXT))
end

local function centeredTexture(art, texture, layer, level)
	local region = art:CreateTexture(nil, layer, nil, level)
	region:SetTexture(texture)
	region:SetPoint("CENTER")
	return region
end

local function buildCover()
	cover = arrow.newButton(BODY)
	local art = cover.art
	art.shadow = art:CreateTexture(nil, "BACKGROUND")
	art.shadow:SetTexture(SOFT_DISC)
	art.shadow:SetVertexColor(0, 0, 0)
	art.shadow:SetAlpha(SHADOW_ALPHA)
	art.halo = centeredTexture(art, SOFT_DISC, "BACKGROUND", 1)
	art.halo:SetBlendMode("ADD")
	art.halo:SetVertexColor(unpack(HALO_COLOR))
	art.halo:SetAlpha(HALO_ALPHA)
	art.halo:Hide()
	art.body = centeredTexture(art, BODY, "BORDER")
	art.body:SetVertexColor(unpack(SLATE))
	art.body:SetAlpha(PIN_ALPHA)
	art.back = centeredTexture(art, arrow.DISC, "BORDER", 1)
	art.back:SetVertexColor(unpack(WINDOW_BACK))
	art.back:SetAlpha(PIN_ALPHA)
	art.gold = centeredTexture(art, GOLD, "OVERLAY")
	art.highlight = centeredTexture(art, BODY, "OVERLAY", 1)
	art.highlight:SetBlendMode("ADD")
	art.highlight:SetAlpha(HIGHLIGHT_ALPHA)
	art.highlight:Hide()
	art.nose = {art.body, art.gold, art.highlight, cover.armGlow}
	buildTag(art)
	art.logo = art:CreateTexture(nil, "ARTWORK")
	art.logo:SetMask(ns.roundMask)
	art.logo:SetPoint("CENTER")
	art.logo:Hide()
	art.clock = buildClock(art)
	cover:SetScript("OnEnter", coverEnter)
	cover:SetScript("OnLeave", coverLeave)
	cover:HookScript("OnClick", ns.confirmClick)
	syncPin()
end

local function sizeCover(size)
	if cover.size == size then return end
	cover.size = size
	cover:SetSize(size, size)
	local inset = size * COVER_INSET
	cover:SetHitRectInsets(inset, inset, inset, inset)
	local art = cover.art
	art:SetSize(size, size)
	art.shadow:SetPoint("CENTER", 0, -size * SHADOW_DROP)
	art.shadow:SetSize(size * SHADOW, size * SHADOW)
	art.halo:SetSize(size * HALO, size * HALO)
	for _, texture in ipairs(art.nose) do texture:SetSize(size * PIN, size * PIN) end
	local window = size * WINDOW
	art.back:SetSize(window, window)
	cover.icon:SetSize(window, window)
	cover.cross:SetSize(window * MARK, window * MARK)
	ns.sizeUnseenMark(cover, window)
	art.logo:SetSize(window * LOGO_FILL, window * LOGO_FILL)
	art.clock:SetSize(window, window)
	art.clock.ring:SetSize(size * PIN, size * PIN)
	art.clock.seconds, art.clock.time = nil, nil
end

-- CONSTRAINT: unsuffixed attributes answer every button and the right one is the lock's, so the cover keeps them as
-- "*<key>1", which answers the left button with or without a modifier.
local LEFT_BUTTON_KEYS = {}
for index, key in ipairs(ns.useAttributes) do LEFT_BUTTON_KEYS[index] = "*" .. key .. "1" end

function arrow.setCover(use)
	if use then ns.setAction(cover, use) else ns.clearAction(cover) end
	for index, key in ipairs(ns.useAttributes) do
		cover:SetAttribute(LEFT_BUTTON_KEYS[index], cover:GetAttribute(key))
		cover:SetAttribute(key, nil)
	end
	arrow.setArt(cover, use)
	local art = cover.art
	art.logo:SetShown(use == nil)
	if hovering() then
		art.highlight:SetShown(use ~= nil)
		art.halo:SetShown(use ~= nil)
		if not ns.tooltipOwnedBy(cover) then coverTip() end
	end
end

-- CONSTRAINT: the pin's art stands above the moons' (their buttons answer the clicks above its button): the nose is
-- never behind one.
function arrow.placeCover(x, y, size, strata, level)
	cover:ClearAllPoints()
	cover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	sizeCover(size)
	arrow.showButton(cover, strata, level, level + PIN_ART_LEVEL)
	local clock = cover.art.clock
	clock:SetFrameLevel(level + CLOCK_LEVEL)
	clock.ring:SetFrameLevel(level + CLOCK_RING_LEVEL)
end

buildCover()
arrow.cover = cover
