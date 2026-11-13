local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RING, RING_PUSHED = "UI-QuestPoi-QuestNumber", "UI-QuestPoi-QuestNumber-Pressed"
local RING_GLOW = "UI-QuestPoi-InnerGlow"
local RING_SCALE, INNER = 1.6, 0.88
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local UNSEEN, POI_RING = "UI-QuestIcon-TurnIn-Normal", 32
local CROSS_TEXTURE, CROSS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 0.8
local ARMED_COLOR = {1, 0.25, 0.25}
local UNSEEN_FALLBACK_SIZE = 20
local unseenInfo = C_Texture.GetAtlasInfo(UNSEEN)
local UNSEEN_WIDTH, UNSEEN_HEIGHT = unseenInfo and unseenInfo.width or UNSEEN_FALLBACK_SIZE,
	unseenInfo and unseenInfo.height or UNSEEN_FALLBACK_SIZE

ns.roundMask = ROUND_MASK

-- CONSTRAINT: secure buttons hang on UIParent, never on a tracker frame, so protection cannot spread into the tracker.
function ns.newSecureButton()
	local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyUp", "AnyDown")
	return button
end

function ns.eachLiveUnit(visit, redraw)
	visit("target", redraw)
	visit("mouseover", redraw)
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do visit(plate:GetUnit(), redraw) end
end

-- CONSTRAINT: SetPortraitTexture needs the unit in sight and blanks until the engine has rendered it: draw on these
-- events only, never poll.
function ns.onUnitSighting(seen)
	ns.listen({
		PLAYER_TARGET_CHANGED = function() seen("target") end,
		UPDATE_MOUSEOVER_UNIT = function() seen("mouseover") end,
		NAME_PLATE_UNIT_ADDED = seen,
		UNIT_PORTRAIT_UPDATE = function(unit) seen(unit, true) end,
		PORTRAITS_UPDATED = function() ns.eachLiveUnit(seen, true) end,
	})
end

-- CONSTRAINT: one round portrait per unit name; a texture has one parent, so each set of circles keeps its own cache.
-- Past the limit the least recently seen portrait no circle shows is reused.
local Portraits = {}
Portraits.__index = Portraits

local shelf = CreateFrame("Frame", nil, UIParent)
shelf:Hide()

function ns.newPortraits(limit, unsnapped)
	return setmetatable({limit = limit, unsnapped = unsnapped, byName = {}, shelf = shelf}, Portraits)
end

function Portraits:get(name)
	return self.byName[name]
end

function Portraits:acquire(name)
	local portrait = self.byName[name]
	if portrait then return portrait, false end
	local count, oldest = 0, nil
	for _, other in pairs(self.byName) do
		count = count + 1
		local shown = other.button and other.button:IsShown()
		if not shown and (not oldest or other.seen < oldest.seen) then oldest = other end
	end
	if count >= self.limit and oldest then
		self.byName[oldest.unitName] = nil
		self:detach(oldest)
		portrait = oldest
	else
		portrait = self.shelf:CreateTexture(nil, "ARTWORK", nil, 1)
		portrait:SetMask(ROUND_MASK)
		if self.unsnapped then
			portrait:SetSnapToPixelGrid(false)
			portrait:SetTexelSnappingBias(0)
		end
	end
	portrait.unitName = name
	self.byName[name] = portrait
	return portrait, true
end

function Portraits:detach(portrait)
	local button = portrait.button
	if not button then return end
	portrait:SetParent(self.shelf)
	portrait.button, button.portrait = nil, nil
end

function Portraits:attach(button, portrait, parent)
	local current = button.portrait
	if current == portrait then return end
	if current then self:detach(current) end
	if not portrait then return end
	self:detach(portrait)
	portrait:SetParent(parent)
	portrait:SetAllPoints(button.icon)
	portrait.button, button.portrait = button, portrait
end

-- CONSTRAINT: `cooldownParent` must not be the protected button; the swipe is a sibling or the art frame's child.
function ns.buildCircleArt(button, host, cooldownParent, armTexture)
	local icon = host:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	icon:SetMask(ROUND_MASK)
	button.icon = icon
	local mark = host:CreateTexture(nil, "ARTWORK", nil, 2)
	mark:SetPoint("CENTER")
	mark:SetAtlas(UNSEEN)
	button.mark = mark
	local cross = host:CreateTexture(nil, "OVERLAY", nil, 2)
	cross:SetPoint("CENTER")
	cross:SetTexture(CROSS_TEXTURE)
	cross:Hide()
	button.cross = cross
	local armGlow = host:CreateTexture(nil, "OVERLAY", nil, 1)
	armGlow:SetPoint("CENTER")
	if armTexture then armGlow:SetTexture(armTexture) else armGlow:SetAtlas(RING_GLOW) end
	armGlow:SetBlendMode("ADD")
	armGlow:SetVertexColor(unpack(ARMED_COLOR))
	armGlow:Hide()
	button.armGlow = armGlow
	local cooldown = CreateFrame("Cooldown", nil, cooldownParent, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	cooldown:SetSwipeTexture(ROUND_MASK)
	cooldown:SetUseCircularEdge(true)
	cooldown:EnableMouse(false)
	button.cooldown = cooldown
end

-- CONSTRAINT: ring on the button's own textures, so the engine draws press and hover in combat too.
function ns.buildButtonRing(button)
	button:SetNormalAtlas(RING)
	button:SetPushedAtlas(RING_PUSHED)
	button:SetHighlightAtlas(RING_GLOW, "ADD")
	local rim = {button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()}
	for _, texture in ipairs(rim) do
		texture:ClearAllPoints()
		texture:SetPoint("CENTER")
	end
	-- CONSTRAINT: the POI disc is opaque and normal and pushed art default to ARTWORK, where they hide the icon.
	rim[1]:SetDrawLayer("BACKGROUND")
	rim[2]:SetDrawLayer("BACKGROUND")
	button.rim = rim
end

-- CONSTRAINT: the bare secure button has no ring textures, so button.art holds ring, pushed and glow.
function ns.buildArtRing(button)
	local art = button.art
	art.ring = art:CreateTexture(nil, "BACKGROUND")
	art.ring:SetAtlas(RING)
	art.pushed = art:CreateTexture(nil, "BACKGROUND", nil, 1)
	art.pushed:SetAtlas(RING_PUSHED)
	art.pushed:Hide()
	art.glow = art:CreateTexture(nil, "OVERLAY")
	art.glow:SetAtlas(RING_GLOW)
	art.glow:SetBlendMode("ADD")
	art.glow:Hide()
	button.rim = {art.ring, art.pushed, art.glow}
	for _, texture in ipairs(button.rim) do texture:SetPoint("CENTER") end
end

function ns.sizeUnseenMark(button, disc)
	local scale = disc * RING_SCALE / POI_RING
	button.mark:SetSize(UNSEEN_WIDTH * scale, UNSEEN_HEIGHT * scale)
end

function ns.sizeRing(button, disc)
	local ringSize = disc * RING_SCALE
	for _, texture in ipairs(button.rim) do texture:SetSize(ringSize, ringSize) end
	return ringSize
end

function ns.sizeCircle(button, disc)
	local ringSize = ns.sizeRing(button, disc)
	button.armGlow:SetSize(ringSize, ringSize)
	local inner = disc * INNER
	button.icon:SetSize(inner, inner)
	button.cross:SetSize(inner * CROSS, inner * CROSS)
	ns.sizeUnseenMark(button, disc)
end

function ns.drawsIcon(use)
	return use.type ~= "unit" and use.type ~= "abandon"
end

function ns.setMark(button, use, portrait)
	button.mark:SetShown(use ~= nil and (use.type == "abandon" or (use.type == "unit" and portrait == nil)))
end

function ns.paintArmed(button, armed)
	if not armed then button.armedAt = nil end
	button.armGlow:SetShown(armed)
	if armed then
		button.cross:SetVertexColor(unpack(ARMED_COLOR))
	else
		button.cross:SetVertexColor(1, 1, 1)
	end
end

function ns.hideCircle(button, companion)
	if not button:IsShown() then return false end
	button.cooldownStart, button.cooldownDuration = nil, nil
	-- CONSTRAINT: a circle that hides comes back not armed, also with the same use: a step that returns within the
	-- arming time must not find the second click waiting.
	ns.paintArmed(button, false)
	ns.releaseOwnTooltip(button)
	button:Hide()
	companion:Hide()
	return true
end
