local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

-- CONSTRAINT: the module is in no list of Blizzard's; place() slots it after Scenario (uiOrder 1) on each update.
local SLOT = 1.5

local NO_ENTRIES = {}

local module, snapshot, grantedLast, foldedLast
-- CONSTRAINT: set only by the Update post-hook below, from IsShown, not IsVisible (Alt+Z hides UIParent): false until
-- the first Update, so RestedXP's windows do not flash at login.
local paused = false

function ns.paused()
	return paused
end

local function entries()
	return snapshot and snapshot.entries or NO_ENTRIES
end

-- CONSTRAINT: mirrors Container.lua Update: display-priority modules (Scenario, Bonus objectives) are laid out first.
local function grantedHeight()
	if ns.detached and ns.detached() then return UIParent:GetHeight() end
	local tracker = ObjectiveTrackerFrame
	local height = tracker:GetAvailableHeight()
	for _, other in ipairs(tracker.modules) do
		if other.hasDisplayPriority then
			if other:IsTruncated() then return 0 end
			height = height - other:GetContentsHeight()
		end
	end
	return height
end

local function trackerDb()
	return root.tracker and root.tracker.db
end

-- /qt Tracker settings: "Own window": the RXP Tracker leaves the quest tracker for a window of its own that you drag
-- by its bar; the quests close up, and make room again when it goes back.
local function detached()
	local tdb = trackerDb()
	return tdb and tdb.guideDetached and true or false
end
ns.detached = detached

local function trackerFolded()
	if detached() then return false end -- in its own window the quest tracker's collapse does not fold it
	local tracker = ObjectiveTrackerFrame
	return not tracker:ShouldShowHeader() or tracker:IsCollapsed()
end

-- CONSTRAINT: stands in for the container: Blizzard's module code also reads parentContainer:IsCollapsed(), and
-- module.MarkDirty is replaced below because the proxy has no MarkDirty.
local proxy = {IsCollapsed = trackerFolded}

local function anchorBelow(frame, previous)
	local tracker = ObjectiveTrackerFrame
	frame:ClearAllPoints()
	if previous then
		frame:SetPoint("TOP", previous, "BOTTOM", 0, -tracker.moduleSpacing)
	else
		frame:SetPoint("TOP", tracker, "TOP", 0, -tracker.topModulePadding)
	end
	frame:SetPoint("LEFT", tracker, "LEFT", frame.leftMargin, 0)
end

-- The "RestedXP Tracker scale" setting (tracker half, db.guideScale): a factor on top of the tracker's own scale.
-- The module is ours, so its width is set to the tracker's width divided by that factor: on screen it stays exactly as
-- wide as the tracker at any scale.
local function guideFactor()
	local trackerDb = root.tracker and root.tracker.db
	local value = trackerDb and tonumber(trackerDb.guideScale) or 1
	return math.min(math.max(value, 0.5), 1.5)
end

-- The window: an anchor you move by the bar along the top of the RXP Tracker. The position is saved (UIParent units,
-- top-left corner) in the tracker settings; the first time it opens to the left of the quest tracker.
local GRIP_H = 12
local window, grip
local function savePosition()
	local tdb = trackerDb()
	if tdb and window:GetLeft() then tdb.guideWindowPos = { window:GetLeft(), window:GetTop() } end
end

local function placeWindow()
	local tdb = trackerDb()
	local pos = tdb and type(tdb.guideWindowPos) == "table" and tdb.guideWindowPos
	window:ClearAllPoints()
	if pos and tonumber(pos[1]) and tonumber(pos[2]) then
		window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
	else
		local tracker = ObjectiveTrackerFrame
		local left, top = tracker:GetLeft(), tracker:GetTop()
		local width = module:GetWidth() * ns.relativeScale(module)
		if left and top then
			window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", math.max(left - width - 20, 0), top - GRIP_H)
		else
			window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	end
end

local function buildWindow()
	window = CreateFrame("Frame", "RXPForeverTrackerGuideWindow", UIParent)
	window:SetSize(1, 1)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	placeWindow()
	grip = CreateFrame("Button", nil, UIParent)
	grip:SetHeight(GRIP_H)
	grip:RegisterForDrag("LeftButton")
	local bg = grip:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.45)
	local dots = grip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dots:SetPoint("CENTER")
	dots:SetText("RXP Tracker")
	grip.dots = dots
	grip:SetAlpha(0.35)
	grip:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("RXP Tracker", 1, 0.82, 0)
		GameTooltip:AddLine("Drag to move. /qt > Tracker settings > Own window puts it back in the quest tracker.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function(self)
		self:SetAlpha(0.35)
		if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)
	-- The window follows the cursor through SetPoint while the button is held (as the quest tracker's drag bar does):
	-- the game's StartMoving does not move frames here in Forever.
	local dragOffset
	local function cursor()
		local s = UIParent:GetEffectiveScale()
		local x, y = GetCursorPosition()
		return x / s, y / s
	end
	local function stopDrag()
		if not dragOffset then return end
		dragOffset = nil
		grip:SetScript("OnUpdate", nil)
		savePosition()
		placeWindow()
		ns.relocate()
	end
	grip:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then return end
		if InCombatLockdown() and module:IsProtected() then return end
		local left, top = window:GetLeft(), window:GetTop()
		if not (left and top) then return end
		local cx, cy = cursor()
		dragOffset = { left - cx, top - cy }
		grip:SetScript("OnUpdate", function()
			if not IsMouseButtonDown("LeftButton") or (InCombatLockdown() and module:IsProtected()) then stopDrag() return end
			local x, y = cursor()
			window:ClearAllPoints()
			window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + dragOffset[1], y + dragOffset[2])
		end)
	end)
	grip:SetScript("OnMouseUp", stopDrag)
	grip:SetScript("OnDragStop", stopDrag)
	grip:SetScript("OnHide", stopDrag)
end

-- the bar sits just above the module, as wide as it, at the module's strata
local function placeGrip(show)
	if not grip then return end
	if not show then grip:Hide() return end
	grip:ClearAllPoints()
	grip:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 0, 0)
	grip:SetWidth(math.max(module:GetWidth() * ns.relativeScale(module), 40))
	grip:SetFrameStrata(module:GetFrameStrata())
	grip:SetFrameLevel(module:GetFrameLevel() + 5)
	grip:SetShown(module:IsShown())
end

-- CONSTRAINT: only anchors change on Blizzard's frames (no field, show, hide or size): none of their scripts runs.
local function place()
	local tracker = ObjectiveTrackerFrame
	local factor = guideFactor()
	local scale = ns.relativeScale(tracker) * factor
	if math.abs(module:GetScale() - scale) > 1e-4 then module:SetScale(scale) end
	-- the width without Extra width: Extra width widens only the quest tracker's frame, not the RXP Tracker (its
	-- divider lines stay put)
	local trackerApi = root.tracker and root.tracker.api
	local natural = trackerApi and trackerApi.naturalWidth and trackerApi.naturalWidth()
	local width = (natural or tracker:GetWidth()) / factor
	if width > 0 and math.abs(module:GetWidth() - width) > 0.5 and not ns.protectedInCombat(module) then
		module:SetWidth(width)
		ns.relayout() -- the rows are laid out from the module's width
	end
	module:SetFrameStrata(tracker:GetFrameStrata())
	module:SetFrameLevel(tracker:GetFrameLevel() + 1)
	local previous, follower
	for _, other in ipairs(tracker.modules) do
		if other:GetContentsHeight() > 0 then
			if not other.uiOrder or other.uiOrder > SLOT then
				follower = other
				break
			end
			previous = other
		end
	end
	local own = detached()
	if own then
		if not window then buildWindow() end
		if module:GetParent() ~= UIParent then module:SetParent(UIParent) end
		module:ClearAllPoints()
		module:SetPoint("TOPLEFT", window, "TOPLEFT", module.leftMargin or 0, 0)
	elseif module:IsShown() then
		anchorBelow(module, previous)
		previous = module
	end
	placeGrip(own)
	if follower then
		if not ns.protectedInCombat(follower) then anchorBelow(follower, previous) end
	elseif previous then
		tracker.NineSlice:SetPoint("BOTTOM", previous, "BOTTOM", 0, -tracker.bottomModulePadding)
	end
end

-- CONSTRAINT: a protected frame anchored to the module (another add-on's frame after ours) makes it wait in combat.
local function locked()
	return ns.protectedInCombat(module)
end

local function layoutModule()
	if not ObjectiveTrackerManager.containers[ObjectiveTrackerFrame] then return false end
	if locked() then return true end
	grantedLast, foldedLast = grantedHeight(), trackerFolded()
	module:Update(grantedLast, false)
	place()
	ns.bindLive()
	ns.sync()
	return true
end

local function createModule()
	module = CreateFrame("Frame", nil, UIParent, "ObjectiveTrackerModuleTemplate")
	module.parentContainer = proxy
	module.MarkDirty = ns.relayout
	ns.attachRows(module, entries)
	ns.buildHeaders(module)
	-- CONSTRAINT: slot movers: our placement, ManagedFrameSystem and Edit Mode (they move the tracker), and
	-- RestedXP (reorders its target buttons).
	hooksecurefunc(module, "SetPoint", ns.relocate)
	hooksecurefunc(ObjectiveTrackerFrame, "SetPoint", ns.relocate)
	ns.hookRxp(ns.rxp.targeting, "UpdateTargetFrame", ns.invalidate, "RXP.targeting.UpdateTargetFrame")
	module:HookScript("OnShow", ns.relocate)
	module:HookScript("OnHide", ns.relocate)
end

-- CONSTRAINT: paused, the module hides out of combat only: the circles on its rows are secure buttons that ns.sync
-- cannot hide in combat, so rows and circles leave together once it ends (ns.relayout).
local function draw()
	ns.updateIndicator(paused)
	if paused then
		ns.setWantedUnits(nil)
		if module and not InCombatLockdown() then
			module:Hide()
			ns.sync()
		end
		return true
	end
	ns.setWantedUnits(snapshot and snapshot.entries)
	if not module then createModule() end
	ns.updateHeaders(snapshot)
	return layoutModule()
end

-- CONSTRAINT: secure post-hook, so no taint reaches Blizzard's Update. Silent while ShouldShowHeader is false
-- (ObjectiveTrackerFrameMixin:Update returns before this call).
hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", function(tracker, dirtyUpdate)
	if tracker ~= ObjectiveTrackerFrame then return end
	local hidden = not tracker:IsShown()
	if hidden ~= paused then
		paused = hidden
		ns.guard(draw)
		ns.pauseChanged()
		return
	end
	if paused or not module or locked() then return end
	if not dirtyUpdate or grantedHeight() ~= grantedLast or trackerFolded() ~= foldedLast then
		ns.guard(layoutModule)
	else
		ns.guard(place)
	end
end)

-- /qt Tracker settings: Own window on or off (out of combat: the module may hold secure step buttons)
function ns.setDetached(on)
	local tdb = trackerDb()
	if not tdb then return false end
	on = on and true or false
	if (tdb.guideDetached and true or false) == on then return true end
	if InCombatLockdown() then
		ns.say("the RXP Tracker can move to or from its own window after combat.")
		return false
	end
	tdb.guideDetached = on
	if module then
		if on then
			if window then placeWindow() end
		else
			if grip then grip:Hide() end
		end
	end
	ns.relayout()
	return true
end

function ns.resetWindowPosition()
	local tdb = trackerDb()
	if tdb then tdb.guideWindowPos = nil end
	if window and module then placeWindow(); ns.relocate() end
end

function ns.drawn()
	return snapshot
end

function ns.render(snap)
	snapshot = snap
	return draw()
end
