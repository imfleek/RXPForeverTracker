local ADDON_NAME, root = ...; local ns = root.objectives
-- A separately installed AllObjectives RXP is running: leave everything to it (see Bootstrap.lua).
if root.standaloneObjectives or root.disabledAll then return end
local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
local RXP = AceAddon and AceAddon:GetAddon("RXPGuides", true)

local ACCENT_COLOR, MUTED_COLOR = "|cff33ff99", "|cff888888"
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"

function ns.accent(text)
	return ACCENT_COLOR .. text .. "|r"
end

ns.brand = ns.accent("RXP ForeverTracker") .. " " .. MUTED_COLOR .. "v" .. VERSION .. "|r"
ns.MAX_FOLLOWING = 100 -- steps ahead; the tracker shows upcomingShown of them at a time and scrolls the rest
ns.ALL_STEPS = ns.MAX_FOLLOWING + 1 -- the slider position after 100: every step (ahead / at once)
ns.FALLBACK_ICON = 134400

local DEFAULTS = {
	enabled = true,
	hidden = true,
	arrowButton = true,
	arrowLocked = false,
	arrowSatellites = true,
	arrowCollapse = false,
	followingSteps = 3,
	theme = "forever", -- "forever" (Forever Style, the default) or "rxp" (RXP Style)
	upcomingCollapsed = false,
	currentCollapsed = false, -- the RXP Tracker's own collapse button folds the current step(s) only
	arrowColor = false, arrowAlpha = 1, -- Waypoint arrow: its colour (false = the theme's) and opacity
	-- upcoming steps: how many show at once (the rest scroll), and their scrollbar (as the quest tracker's)
	upcomingShown = 2,
	upcomingScrollbar = true,
	upcomingScrollbarMouseover = false,
	upcomingScrollbarColor = { 0.2, 0.85, 0.55, 0.85 },
	upcomingScrollbarWidth = 3,
	-- size and place of the current step(s) and of the upcoming steps (scale 1 = as drawn; x/y in px, + right / up)
	currentScale = 1, currentX = 0, currentY = 0,
	upcomingScale = 1, upcomingX = 0, upcomingY = 0,
	-- the "N/M" step counter in the RXP Tracker's header (Forever Style): shown, text size, colour (nil = the game's)
	stepCountShown = true, stepCountSize = 0, stepCountColor = false,
}

local db = type(_G.RXPForeverTrackerGuideDB) == "table" and _G.RXPForeverTrackerGuideDB or {}
_G.RXPForeverTrackerGuideDB = db
for key, value in pairs(DEFAULTS) do
	if db[key] == nil then db[key] = value end
end
if type(db.onboarded) ~= "table" then db.onboarded = {} end
if type(db.questFocus) ~= "table" then db.questFocus = {} end
if type(db.questFocusSaved) ~= "table" then db.questFocusSaved = {} end
db.followingSteps = Clamp(math.floor(tonumber(db.followingSteps) or DEFAULTS.followingSteps), 0, ns.ALL_STEPS)
if db.theme ~= "rxp" then db.theme = "forever" end -- new installs (and unknown values) get Forever Style
db.upcomingShown = Clamp(math.floor(tonumber(db.upcomingShown) or DEFAULTS.upcomingShown), 1, ns.ALL_STEPS)
if type(db.upcomingScrollbarColor) ~= "table" then
	local c = DEFAULTS.upcomingScrollbarColor
	db.upcomingScrollbarColor = { c[1], c[2], c[3], c[4] }
end
ns.db = db
ns.DEFAULTS = DEFAULTS

-- Forever Style: the guide drawn like the game's own quest tracker sections (Header.lua, Rows.lua).
function ns.forever()
	return db.theme == "forever"
end

function ns.say(text)
	DEFAULT_CHAT_FRAME:AddMessage(ns.brand .. " " .. text)
end

local STEP_CALLS = {"SetStep", "SetElementComplete", "SetElementIncomplete", "ActiveStepElementPostClick"}
local VIEW_CALLS = {"UpdateItemFrame", "StartTimer", "ShowTimers"}

local AceEvent = RXP and LibStub("AceEvent-3.0", true)

---------------------------------------------------------------------------------------------------------------------
-- RestedXP updates. Nothing here is RestedXP's public API, so every part of it this addon uses is looked up when it is
-- used and may be missing after a RestedXP update:
--   * required: what the step display cannot work without (rxpAvailable). Missing, the guide display stays off,
--     RestedXP's own windows are used, the quest tracker works as usual, and one chat line names what is missing.
--   * optional: hooks (ns.hookRxp) and helpers (ns.isSecret, ns.itemCooldown, ns.isPlayerSpell, ns.L) fall back to the
--     game's own functions or do nothing; what is missing is listed by /qt status.
--   * at run time: a render that fails three times in a row (a RestedXP change in its guide or step data) turns the
--     guide display off for the session and brings RestedXP's windows back, with one chat line instead of an error on
--     every update; the next /reload tries again (ns.guard below).
---------------------------------------------------------------------------------------------------------------------
local missing = {}
ns.missingRxp = missing

local function rxpAvailable()
	local need = {
		{ "AceEvent-3.0", AceEvent },
		{ "RXP.v2", type(RXP.v2) == "table" },
		{ "RXP.settings", type(RXP.settings) == "table" },
		{ "RXP.RXPFrame", type(RXP.RXPFrame) == "table" },
		{ "RXP.SetStep", type(RXP.SetStep) == "function" },
		{ "RXP.GetGuideProgress", type(RXP.GetGuideProgress) == "function" },
	}
	local gone = {}
	for _, item in ipairs(need) do if not item[2] then gone[#gone + 1] = item[1] end end
	if #gone > 0 then return false, table.concat(gone, ", ") end
	return true
end

-- hooksecurefunc on RestedXP's table, only when the function is there (a renamed one would stop the whole file)
function ns.hookRxp(owner, name, fn, label)
	if type(owner) == "table" and type(owner[name]) == "function" then
		hooksecurefunc(owner, name, fn)
		return true
	end
	label = label or name
	for _, known in ipairs(missing) do if known == label then return false end end
	missing[#missing + 1] = label
	return false
end

local function gameIsSecret(value)
	local f = _G.issecretvalue
	return type(f) == "function" and f(value) and true or false
end

-- a secret value (12.0-style restricted data) cannot be compared or used as a key
function ns.isSecret(value)
	local f = RXP and type(RXP.IsSecretValue) == "function" and RXP.IsSecretValue or gameIsSecret
	local ok, secret = pcall(f, value)
	return ok and secret and true or false
end

function ns.itemCooldown(item)
	if RXP and type(RXP.GetItemCooldown) == "function" then return RXP.GetItemCooldown(item) end
	if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(item) end
	if _G.GetItemCooldown then return _G.GetItemCooldown(item) end
end

function ns.isPlayerSpell(id)
	if RXP and type(RXP.IsPlayerSpell) == "function" then return RXP.IsPlayerSpell(id) end
	if _G.IsPlayerSpell then return _G.IsPlayerSpell(id) end
	return false
end

-- RestedXP's translations of its own texts; the text itself when that is not there
function ns.L(text, ...)
	local locale = RXP and RXP.locale
	local get = type(locale) == "table" and locale.Get
	if type(get) == "function" then
		local ok, value = pcall(get, text, ...)
		if ok and value ~= nil then return value end
	end
	return text
end

-- one of RestedXP's own textures by name; the question-mark icon when that lookup is gone
function ns.texture(name)
	if RXP and type(RXP.GetV1Texture) == "function" then
		local ok, texture = pcall(RXP.GetV1Texture, name)
		if ok and texture then return texture end
	end
	return ns.FALLBACK_ICON
end

function ns.playerClass()
	local player = RXP and RXP.player
	return type(player) == "table" and player.class or select(2, UnitClass("player"))
end

-- RestedXP's settings (its saved profile); an empty table when they are laid out differently
local NO_PROFILE = {}
function ns.rxpProfile()
	local settings = RXP and RXP.settings
	local profile = type(settings) == "table" and settings.profile
	return type(profile) == "table" and profile or NO_PROFILE
end

-- RestedXP's guide font size setting; 12 when its settings are laid out differently
function ns.guideFontSize()
	local settings = RXP and RXP.settings
	local profile = type(settings) == "table" and settings.profile
	local size = type(profile) == "table" and tonumber(profile.guideFontSize)
	return size and size > 0 and size or 12
end

function ns.rxpRelease()
	return tostring(RXP and RXP.release or "")
end

local available, gone = false, nil
if RXP then available, gone = rxpAvailable() end
if not available then
	local why = gone and ("this RestedXP version has no " .. gone .. ", so its steps cannot be shown here; RestedXP's own windows are used. The quest tracker works as usual.")
		or "RestedXP is not available."
	if gone then C_Timer.After(0, function() ns.say(why) end) end
	-- the guide commands typed after /qt (toggle, why, ...) answer with why there is no guide display
	local guideCommands = { toggle = true, steps = true, arrow = true, satellites = true, badge = true, welcome = true,
		status = true, restart = true, why = true, all = true }
	ns.runCommand = function(input)
		local command = ((input or ""):match("^%s*(%S*)") or ""):lower()
		if guideCommands[command] or command:match("^%-?%d") then ns.say(why) return true end
		return false
	end
	return
end
ns.rxp = RXP

-- CONSTRAINT: AceEvent (RestedXP's copy) runs each handler through securecallfunction: one that errors stops no other.
function ns.listen(handlers)
	local owner = {}
	for event, handler in pairs(handlers) do
		AceEvent.RegisterEvent(owner, event, function(_, ...) handler(...) end)
	end
end

function ns.onRxpMessage(message, listener)
	AceEvent.RegisterMessage({}, message, listener)
end

function ns.onStepChange(listener)
	for _, name in ipairs(STEP_CALLS) do ns.hookRxp(RXP, name, listener, "RXP." .. name) end
end

-- CONSTRAINT: UnitGUID may return a secret value (RXP.IsSecretValue); a secret cannot be a table key.
local playerGUID
function ns.playerGUID()
	if not playerGUID then
		local value = UnitGUID("player")
		if value and not ns.isSecret(value) then playerGUID = value end
	end
	return playerGUID
end

local syncPasses = {}
function ns.onSync(pass)
	syncPasses[#syncPasses + 1] = pass
end

function ns.sync()
	for _, pass in ipairs(syncPasses) do pass() end
end

function ns.truncate(list, count)
	while #list > count do table.remove(list) end
end

function ns.relativeScale(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

function ns.protectedInCombat(frame)
	return InCombatLockdown() and frame:IsProtected()
end

function ns.inQuestLog(questID)
	return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
end

function ns.releaseTooltip(tooltip, owner)
	if tooltip:GetOwner() == owner then tooltip:Hide() end
end

local viewPasses = {}
function ns.onView(pass)
	viewPasses[#viewPasses + 1] = pass
end

-- What is on screen: the snapshot drawn, nil for the empty view, false for nothing (not drawn yet, or the last render
-- failed).
local rendered = false
local forceRender, stale
local function refresh()
	if not stale then
		ns.sync()
		return
	end
	local snapshot = ns.snapshot()
	if db.enabled then ns.onboard() end
	ns.runSweep()
	if not forceRender and ns.sameView(rendered, snapshot) then
		ns.sync()
	else
		forceRender = nil
		-- CONSTRAINT: cleared before rendering so a render that throws is redone on the next pass.
		rendered = false
		rendered = ns.render(snapshot) and snapshot
	end
	stale = nil
	for _, pass in ipairs(viewPasses) do pass() end
end

-- Run-time guard (see "RestedXP updates" above). Each error still goes to the error handler (BugSack, Witchcraft);
-- after FAILURE_LIMIT failed passes in a row the display stands down for this session instead of failing on every
-- update. PLAYER_LOGOUT puts the saved "on" back, so the next session tries again.
local FAILURE_LIMIT = 3
local failures, suspended = 0, false
local function standDown(err)
	if suspended or not db.enabled then return end
	suspended = true
	db.enabled = false
	pcall(ns.updateWindows)
	pcall(ns.refresh, true)
	local first = tostring(err):match("^[^\n]*") or ""
	ns.say("RestedXP's guide data could not be read (" .. first:sub(1, 160) .. "). Probably a RestedXP update this version does not know yet. Its steps show in RestedXP's own window for now; the quest tracker works as usual. /reload tries again.")
end

function ns.suspended() return suspended end

-- /qt on after a stand-down: try again now
function ns.resumeAfterStandDown()
	suspended, failures = false, 0
end

local function handler(err)
	return tostring(err) .. (debugstack and ("\n" .. debugstack(2)) or "")
end

function ns.guard(fn, ...)
	local ok, err = xpcall(fn, handler, ...)
	if ok then
		failures = 0
		return true
	end
	failures = failures + 1
	geterrorhandler()(err)
	if failures >= FAILURE_LIMIT then standDown(err) end
	return false
end

local dirty = CreateFromMixins(DirtiableMixin)
-- CONSTRAINT: DirtiableMixin clears `dirty` after the method returns; an error would block every later pass.
dirty:SetDirtyMethod(function() ns.guard(refresh) end)

function ns.invalidate()
	stale = true
	dirty:MarkDirty()
end

function ns.relocate()
	dirty:MarkDirty()
end

function ns.relayout()
	forceRender = true
	ns.invalidate()
end

function ns.refresh(force)
	forceRender = force or forceRender
	stale = true
	ns.guard(refresh)
end

local function listChanged()
	ns.guideChanged()
	if ns.resetEmptyRetries then ns.resetEmptyRetries() end
	ns.invalidate()
end

ns.onRxpMessage("RXPGuidesV2_GuideStepsChanged", listChanged)
ns.onRxpMessage("RXPGuidesV2_GuideWindowRefresh", listChanged)

ns.hookRxp(RXP.v2, "UpdateActiveStepsFrame", ns.invalidate, "RXP.v2.UpdateActiveStepsFrame")
ns.hookRxp(RXP.RXPFrame.CurrentStepFrame, "UpdateText", function()
	local v2 = RXP.v2
	if not (type(v2.IsGuideWindowEnabled) == "function" and v2:IsGuideWindowEnabled()) then
		ns.expireGuide()
		ns.invalidate()
	end
end, "RXP.RXPFrame.CurrentStepFrame.UpdateText")
ns.hookRxp(RXP.settings, "SetHideCompletedSteps", listChanged, "RXP.settings.SetHideCompletedSteps")
-- CONSTRAINT: SetStep clears the completed flags of the steps it deactivates and the skip of the next one, also when
-- the progress stays where it is (a sticky step completing, a window resize ending).
ns.hookRxp(RXP, "SetStep", listChanged, "RXP.SetStep")
ns.onStepChange(ns.invalidate)
for _, name in ipairs(VIEW_CALLS) do ns.hookRxp(RXP, name, ns.invalidate, "RXP." .. name) end

-- CONSTRAINT: a nested UpdateActiveStepEventWatchers call empties the list the outer pass still reads; defer one frame.
local updateWatchers, updating = RXP.v2.UpdateActiveStepEventWatchers, false
if updateWatchers then
	function RXP.v2:UpdateActiveStepEventWatchers(steps)
		if updating then
			C_Timer.After(0, function() self:UpdateActiveStepEventWatchers(steps) end)
			return
		end
		updating = true
		local ok, err = pcall(updateWatchers, self, steps)
		updating = false
		if not ok then error(err, 0) end
	end
end

-- CONSTRAINT: RestedXP has no SPELLS_CHANGED or PLAYER_EQUIPMENT_CHANGED handler that rebuilds its item bar; the
-- circles also follow learned spells and worn items, so they ask it to rebuild (it returns at once in combat; our hook
-- on it marks the view stale).
local function rebuildItemBar()
	if type(RXP.UpdateItemFrame) == "function" then RXP.UpdateItemFrame() end
end

ns.listen({
	PLAYER_ENTERING_WORLD = listChanged,
	PLAYER_LEVEL_UP = listChanged,
	PLAYER_REGEN_ENABLED = ns.relayout,
	SPELLS_CHANGED = rebuildItemBar,
	PLAYER_EQUIPMENT_CHANGED = rebuildItemBar,
	PLAYER_LOGOUT = function() if suspended then db.enabled = true end end,
})

C_Timer.After(0, function()
	ns.say("loaded. RestedXP steps now render in your All Objectives tracker. " .. ns.accent("/qt") .. " or " .. ns.accent("/qtrxp") .. " for settings.")
end)
