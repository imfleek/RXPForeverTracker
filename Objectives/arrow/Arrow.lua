local _, root = ...; local ns = root.objectives

local arrow = ns.arrow
if not arrow then return end

local RXP, db = ns.rxp, ns.db
local af = RXP.arrowFrame
local cover, moonButtons, moons, drag = arrow.cover, arrow.moonButtons, arrow.moons, arrow.drag

local TICK, DIM = 0.1, 0.4
local CLOSE_DELAY, FADE_MOONS = 0.4, 0.15
local MOVE_EPSILON = 0.5
local ARROW_LEVEL, MOON_LEVEL = 2, 2
local MIN_COLLAPSED_MOONS = 2
local NONE = {}

local state = {shown = false, count = 0, dimmed = false, collapsed = false, open = false, placedOpen = false}
local wanted = {}
local pending, badge
local sinceTick = 0
local syncStep, syncShown, syncSince

local function hasAny(list)
	return list ~= nil and next(list) ~= nil
end

local function standaloneStep()
	if af:IsShown() or UnitIsGhost("player") then return nil end
	-- CONSTRAINT: the first active step can be a sticky one with no action of its own (a plain farming or
	-- target sticky): scanning the steps in order keeps that sticky from hiding the arrow from the action
	-- step behind it, and still prefers activeSteps[1] whenever it qualifies.
	for _, step in ipairs(RXP.RXPFrame.activeSteps) do
		if hasAny(step.activeItems) or hasAny(step.activeSpells) or hasAny(step.activeMacros)
			or ns.stepHasAction(step) then
			return step
		end
	end
end

local function arrowView()
	if not arrow.enabled() or ns.rxpProfile().disableArrow then return nil, false end
	if arrow.points() then
		return af.element and af.element.step, true
	end
	local step = standaloneStep()
	return step, step ~= nil or ns.activeTimer() ~= nil
end

local function drawIfUnit(button, name, token, redraw)
	local use = button.use
	if button:IsShown() and use and use.type == "unit" and use.name == name then
		arrow.drawPortrait(button, token, redraw)
	end
end

local function unitSeen(token, redraw)
	local name = token and RXP.GetUnitName(token)
	if not (name and wanted[name]) then return end
	for _, button in ipairs(moonButtons) do drawIfUnit(button, name, token, redraw) end
	drawIfUnit(cover, name, token, redraw)
end

local function updateCooldowns()
	if cover.use and cover:IsShown() then ns.updateCooldown(cover) end
	ns.updateCooldowns(moonButtons)
end

local function badgeEnter()
	if not state.collapsed or InCombatLockdown() then return end
	state.open, state.hoverT = true, GetTime()
	local x, y, size = arrow.geometry()
	if x and not state.placedOpen then arrow.place(x, y, size) end
end

-- CONSTRAINT: protected buttons change out of combat only; they stand on UIParent, never on RestedXP's arrow, which
-- RestedXP shows, hides, moves and resizes in combat.
local function place(x, y, size)
	local strata, level = af:GetFrameStrata(), af:GetFrameLevel() + ARROW_LEVEL
	local pin = size * arrow.PIN_SCALE
	arrow.placeCover(x, y, pin, strata, level)
	local collapsed = db.arrowCollapse and state.count >= MIN_COLLAPSED_MOONS
	if collapsed then badge = badge or arrow.buildBadge(badgeEnter) end
	local closed = collapsed and not state.open
	local disc = arrow.layout(state.count, x, y, pin)
	if closed then moons.visible = 1 end
	if state.count > 0 then
		if closed then
			badge:ClearAllPoints()
			badge:SetPoint("CENTER", UIParent, "BOTTOMLEFT", moons[1].x, moons[1].y)
			arrow.sizeBadge(badge, disc, state.count)
			badge:SetFrameStrata(strata)
			badge:SetFrameLevel(level + MOON_LEVEL)
			badge:Show()
		end
		local opening = collapsed and not closed and not state.placedOpen
		for index = 1, state.count do
			local button, spot = moonButtons[index], moons[index]
			-- CONSTRAINT: anchoring again with the same spot lays out the wobbling art once more.
			if button.spotX ~= spot.x or button.spotY ~= spot.y then
				button.spotX, button.spotY = spot.x, spot.y
				button:ClearAllPoints()
				button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", spot.x, spot.y)
			end
			arrow.sizeMoon(button, disc)
			if closed then
				arrow.hideButton(button)
			else
				arrow.showButton(button, strata, level + MOON_LEVEL)
				if opening then button.art:SetAlpha(0) end
			end
		end
		if opening then
			state.fadeT = GetTime()
			ns.eachLiveUnit(unitSeen, true)
		end
	end
	if badge and not closed then badge:Hide() end
	state.collapsed, state.placedOpen = collapsed, state.open
	state.placedX, state.placedY, state.placedSize = x, y, size
	state.dimmed = false
	if badge then badge:SetAlpha(1) end
	arrow.syncTimer()
end

local function hideAll()
	if badge then badge:Hide() end
	arrow.hideButton(cover)
	for _, button in ipairs(moonButtons) do arrow.hideButton(button) end
	moons.visible = 0
	state.collapsed, state.open = false, false
end

local function syncArrow()
	if InCombatLockdown() or drag.coverMoving then
		pending = true
		return
	end
	pending = nil
	local step, shown = arrowView()
	state.step, state.shown = step, shown
	local uses = step and ns.activeUses(step) or NONE
	wipe(wanted)
	local x, y, size = arrow.geometry()
	if not (shown and x) then
		state.count = 0
		hideAll()
		return
	end
	arrow.setCover(uses[1])
	local last = math.min(#uses, db.arrowSatellites and 1 + arrow.maxMoons or 1)
	local count = math.max(last - 1, 0)
	for index = 1, count do
		local button = moonButtons[index] or arrow.newMoon(index)
		moonButtons[index] = button
		ns.setAction(button, uses[index + 1])
		arrow.setArt(button, uses[index + 1])
	end
	ns.addWantedUnits(wanted, uses, last)
	state.count = count
	place(x, y, size)
	for index = count + 1, #moonButtons do arrow.hideButton(moonButtons[index]) end
	if hasAny(wanted) then ns.eachLiveUnit(unitSeen) end
end

local function setMoonAlpha(alpha)
	for _, button in ipairs(moonButtons) do
		if button:IsShown() then button.art:SetAlpha(alpha) end
	end
end

local function dim()
	if state.dimmed then return end
	state.dimmed = true
	cover.art:SetAlpha(DIM)
	if badge then badge:SetAlpha(DIM) end
	setMoonAlpha(DIM)
end

local function fadeMoons()
	local alpha = Saturate((GetTime() - state.fadeT) / FADE_MOONS)
	if not state.dimmed then setMoonAlpha(alpha) end
	if alpha >= 1 then state.fadeT = nil end
end

-- CONSTRAINT: moon hit rects are inset and the badge square reaches ring*sqrt(2) from moon 1, so IsMouseOver alone
-- misses gaps and corners; the center-distance net (ring*1.5, moons.hover) covers the whole cluster and stops a
-- parked cursor from cycling it open and closed.
local function overMoons()
	-- CONSTRAINT: GetCursorPosition answers effective-scale screen pixels; the spots are UIParent SetPoint units.
	local scale = UIParent:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	local reach = moons.hover * moons.hover
	for index = 1, moons.visible do
		local spot = moons[index]
		local dx, dy = cx - spot.x, cy - spot.y
		if dx * dx + dy * dy <= reach then return true end
	end
	return false
end

local function pollOpen()
	if not state.collapsed then
		state.open = false
		return false
	end
	if InCombatLockdown() then return false end
	local now = GetTime()
	local over = badge and badge:IsMouseOver() or false
	for _, button in ipairs(moonButtons) do over = over or (button:IsShown() and button:IsMouseOver()) end
	if not over then over = overMoons() end
	if over then
		state.hoverT, state.open = now, true
	elseif state.open and now - state.hoverT > CLOSE_DELAY then
		state.open = false
	end
	return state.open ~= state.placedOpen
end

-- CONSTRAINT: RestedXP's arrow OnUpdate is never hooked: SetupArrow re-sets it on every theme reload and a hidden
-- frame runs none. In combat sync and placement wait; buttons the arrow left are dimmed, never invisible and clickable.
local function tick(_, elapsed)
	arrow.pinTick()
	arrow.shroud(state.dimmed)
	if drag.coverMoving then return end
	if state.fadeT then fadeMoons() end
	sinceTick = sinceTick + elapsed
	local step, shown = arrowView()
	-- CONSTRAINT: RestedXP flips shown/step frame-to-frame near a route end (binary alpha on its arrow); a change must
	-- hold for one tick before it syncs or every flip churns hide/show.
	if step ~= state.step or shown ~= state.shown then
		if syncSince == nil or syncStep ~= step or syncShown ~= shown then
			syncStep, syncShown, syncSince = step, shown, GetTime()
		end
	elseif syncSince then
		syncStep, syncShown, syncSince = nil, nil, nil
	end
	local needSync = syncSince and GetTime() - syncSince >= TICK
	if sinceTick < TICK and not drag.active and not needSync then return end
	sinceTick = 0
	arrow.syncLock()
	local x, y, size = arrow.geometry()
	local needPlace = pollOpen() or state.dimmed
	if cover:IsShown() and x and state.placedX then
		local moved = math.abs(x - state.placedX) + math.abs(y - state.placedY)
		if moved > MOVE_EPSILON or size ~= state.placedSize then needPlace = true end
		if InCombatLockdown() and (moved > size / 2 or not shown) then dim() end
	end
	if InCombatLockdown() then
		if needSync then pending = true end
	elseif needSync or pending then
		syncArrow()
	elseif needPlace and x and state.shown then
		place(x, y, size)
	end
	arrow.shroud(state.dimmed)
end

arrow.place = place
ns.onView(syncArrow)
CreateFrame("Frame"):SetScript("OnUpdate", tick)

ns.onUnitSighting(unitSeen)
ns.listen({
	SPELL_UPDATE_COOLDOWN = updateCooldowns,
	BAG_UPDATE_COOLDOWN = updateCooldowns,
	PLAYER_REGEN_ENABLED = function() if pending then syncArrow() end end,
})
