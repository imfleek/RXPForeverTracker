local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp
local db = ns.db

-- CONSTRAINT: never RXP.settings.ToggleActive, showEnabled or hideGuideWindow: they pause RestedXP's engine.
-- CONSTRAINT: arrowFrame stays: Arrow.lua builds on it.
local ARROW = "arrowFrame"
-- CONSTRAINT: hiding RXPFrame or the V2 element host pauses the engine (OnHide runs PLAYER_LEAVING_WORLD; rows confirm
-- via OnUpdate): fade and mute them, never hide.
local ELEMENT_HOST = "RXPActiveStepsFrame" .. tostring(type(RXP.player) == "table" and RXP.player.name or UnitName("player"))
local FADED = {[ELEMENT_HOST] = true, RXPFrame = true}

local hooked, muted = {}, {}
local pending, sweepRequested

local function skinHides()
	return db.enabled and db.hidden
end

-- CONSTRAINT: not while the tracker is hidden (ns.paused): no circles stand in for the item bar and the target frame
-- then, and a player with no quest still sees the guide.
local function windowsHidden()
	return skinHides() and not ns.paused()
end

local function windowOf(entry)
	return entry.frame or entry
end

-- CONSTRAINT: RestedXP v4.11.32 lists windows without the method (RXPV2GuideConfigurator, GuideConfigurator.lua:1068);
-- treat them as its always-on windows: enabled, not secure (UI/V2/Core.lua:1908).
local function featureEnabled(entry)
	if entry.IsFeatureEnabled then return entry.IsFeatureEnabled() end
	return true, false
end

-- CONSTRAINT: RestedXP's toggles call IsFeatureEnabled unguarded on every listed window
-- (SettingsPanel.lua:3700, RXPGuides.lua:1972), so a listed window without the method errors its
-- minimap toggle; attach the same always-on stub it uses elsewhere (UI/V2/Core.lua:1908), only
-- while it stays missing.
local ALWAYS_ON = function() return true, false end
local function fixMethodlessWindows()
	for _, entry in pairs(type(RXP.enabledFrames) == "table" and RXP.enabledFrames or {}) do
		if type(entry) == "table" and not entry.IsFeatureEnabled then entry.IsFeatureEnabled = ALWAYS_ON end
	end
end
fixMethodlessWindows()

-- CONSTRAINT: ui.v2.configurator exists from GuideConfigurator.lua:2 (file scope), upgraded at RXPGuides.lua:2804,
-- before our load; the harness loads a subset without that file, so guard and retry on PLAYER_ENTERING_WORLD, the
-- event RestedXP Opens the configurator from (RXPGuides.lua:1822).
local configuratorHooked = false
local function hookConfigurator()
	if configuratorHooked then return end
	local configurator = RXP.ui and RXP.ui.v2 and RXP.ui.v2.configurator
	if configurator and configurator.Open then
		hooksecurefunc(configurator, "Open", fixMethodlessWindows)
		configuratorHooked = true
	end
end
hookConfigurator()
if not configuratorHooked then ns.listen({PLAYER_ENTERING_WORLD = hookConfigurator}) end

-- CONSTRAINT: protected frames wait for combat end, as RestedXP's secure windows do (RXPGuides.lua addon:GROUP_LEFT).
local function deferInCombat(protected)
	if protected and InCombatLockdown() then
		pending = true
		return true
	end
	return false
end

-- CONSTRAINT: invisible frames must not catch the mouse, scroll frames included.
local function mute(...)
	for index = 1, select("#", ...) do
		local frame = select(index, ...)
		if not deferInCombat(frame:IsProtected()) then
			if frame:IsMouseEnabled() or frame:IsMouseWheelEnabled() then
				local state = muted[frame] or {}
				state[1], state[2], state[3] = frame:IsMouseClickEnabled(), frame:IsMouseMotionEnabled(),
					frame:IsMouseWheelEnabled()
				muted[frame] = state
				frame:EnableMouse(false)
				frame:EnableMouseWheel(false)
			end
			mute(frame:GetChildren())
		end
	end
end

local function unmute()
	for frame, state in pairs(muted) do
		if not deferInCombat(frame:IsProtected()) then
			local click, motion, wheel = unpack(state, 1, 3)
			frame:SetMouseClickEnabled(click)
			frame:SetMouseMotionEnabled(motion)
			frame:EnableMouseWheel(wheel)
			muted[frame] = nil
		end
	end
end

local function fadeWindows(hidden)
	for key in pairs(FADED) do
		local entry = RXP.enabledFrames[key]
		if entry then
			local window = windowOf(entry)
			window:SetAlpha(hidden and 0 or 1)
			if hidden then mute(window) end
		end
	end
	if not hidden then unmute() end
end

-- CONSTRAINT: timer bars (LibCandyBar) are UIParent children, so the RXPFrame fade skips them; never hide or
-- unlist: a bar's OnHide drops it from the list ns.activeTimer reads.
local function fadeTimers()
	local alpha = windowsHidden() and 0 or 1
	for _, bar in pairs(ns.timerBars()) do
		if bar:GetAlpha() ~= alpha then bar:SetAlpha(alpha) end
	end
end

local function hideWhileHiding(window)
	if not windowsHidden() then return end
	local _, secure = featureEnabled(hooked[window])
	if not deferInCombat(secure) then window:Hide() end
end

function ns.updateWindows()
	pending = nil
	local hidden = windowsHidden()
	fadeWindows(hidden)
	fadeTimers()
	for key, entry in pairs(RXP.enabledFrames) do
		if not FADED[key] and key ~= ARROW then
			local enabled, isSecure = featureEnabled(entry)
			if not deferInCombat(isSecure) then
				local window = windowOf(entry)
				if not hooked[window] then
					hooked[window] = entry
					window:HookScript("OnShow", hideWhileHiding)
				end
				window:SetShown(not hidden and enabled and ns.rxpProfile().showEnabled)
			end
		end
	end
	if not hidden then RXP.targeting:UpdateTargetFrame() end
end

function ns.runSweep()
	if sweepRequested then
		sweepRequested = nil
		ns.updateWindows()
	end
end

function ns.toggleHidden()
	db.hidden = not db.hidden
	ns.updateWindows()
end

-- CONSTRAINT: only while the skin hides them: RestedXP hides some windows itself, which updateWindows would show.
function ns.pauseChanged()
	if skinHides() then ns.updateWindows() end
end

function ns.windowsTooltip()
	return ns.L("|cff909090Left Click: |cffffcc00Toggle Guide|r")
		.. "\nRestedXP windows: " .. (windowsHidden() and "hidden" or "shown")
end

-- CONSTRAINT: RestedXP's own toggle showing its windows ends our hiding; other messages may bring new windows.
local function onMessage(message, change, value)
	if not skinHides() then return end
	if message == "RXPGuidesV2_GuideWindowRefresh" and change == "visibility" and value then
		db.hidden = false
		ns.updateWindows()
	elseif windowsHidden() then
		sweepRequested = true
		ns.invalidate()
	end
end
for _, key in ipairs({"UpdateActiveSteps", "GuideStepsChanged", "QuestDataLoaded", "GuideWindowRefresh"}) do
	ns.onRxpMessage("RXPGuidesV2_" .. key, onMessage)
end

-- CONSTRAINT: new rows come with the mouse enabled (after UpdateActiveStepsFrame and SetStep); the classic window
-- enables it on every drawn row again in each UpdateText, which RestedXP runs about every 2.4 s.
local function muteNewRows()
	if windowsHidden() then fadeWindows(true) end
end
ns.hookRxp(RXP.v2, "UpdateActiveStepsFrame", muteNewRows, "RXP.v2.UpdateActiveStepsFrame")
ns.hookRxp(RXP, "SetStep", muteNewRows, "RXP.SetStep")
ns.hookRxp(RXP.RXPFrame.CurrentStepFrame, "UpdateText", function()
	local v2 = RXP.v2
	if not (type(v2.IsGuideWindowEnabled) == "function" and v2:IsGuideWindowEnabled()) then muteNewRows() end
end, "RXP.RXPFrame.CurrentStepFrame.UpdateText")

ns.hookRxp(RXP, "StartTimer", fadeTimers, "RXP.StartTimer")
ns.hookRxp(RXP, "ShowTimers", fadeTimers, "RXP.ShowTimers")

-- CONSTRAINT: re-hide only while hiding: RestedXP hides windows itself (hide in raid, splits, party steps).
ns.listen({
	PLAYER_ENTERING_WORLD = function()
		if pending or windowsHidden() then ns.updateWindows() end
	end,
	PLAYER_REGEN_ENABLED = function()
		if pending then ns.updateWindows() end
	end,
})
