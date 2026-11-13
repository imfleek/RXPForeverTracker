-- What the settings window's AllObjectives RXP tab reads and changes: the same state and calls as /qt (Slash.lua).
local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP, db = ns.rxp, ns.db
local api = {}
ns.settings = api

local OPTIONS = {"enabled", "theme", "followingSteps", "arrowButton", "arrowSatellites", "arrowCollapse", "arrowLocked",
	"upcomingShown", "upcomingScrollbar", "upcomingScrollbarMouseover", "upcomingScrollbarColor", "upcomingScrollbarWidth",
	"currentScale", "currentX", "currentY", "upcomingScale", "upcomingX", "upcomingY",
	"stepCountShown", "stepCountSize", "stepCountColor", "arrowColor", "arrowAlpha"}

-- 2.6.0: "Quest list: only this guide's turn-ins" was removed (settings window and /qt quests); a character that had
-- it on gets the normal quest list back.
C_Timer.After(3, function()
	if ns.questFocusOn and ns.questFocusOn() and ns.setQuestFocus then pcall(ns.setQuestFocus, false) end
end)

function api.get(key)
	if key == "quests" then return ns.questFocusOn() end
	return db[key]
end

-- /qt toggle
function api.setEnabled(on)
	on = on and true or false
	if db.enabled == on then return end
	if on and ns.resumeAfterStandDown then ns.resumeAfterStandDown() end
	db.enabled = on
	ns.updateWindows()
	ns.refresh(true)
end

-- Guide look: "forever" (Forever Style, the default) or "rxp" (RXP Style)
function api.setTheme(theme)
	theme = theme == "rxp" and "rxp" or "forever"
	if db.theme == theme then return end
	db.theme = theme
	ns.refresh(true)
end

-- /qt 0-8
function api.setSteps(steps)
	steps = Clamp(math.floor((tonumber(steps) or 0) + 0.5), 0, ns.ALL_STEPS)
	if db.followingSteps == steps then return end
	db.followingSteps = steps
	ns.refresh()
end

-- /qt quests
function api.setQuests(on)
	if ns.questFocusOn() ~= (on and true or false) then ns.setQuestFocus(on and true or false) end
end

local function syncArrowLock()
	if ns.arrow and ns.arrow.syncLock then ns.arrow.syncLock() end
end

-- /qt arrow, satellites, badge; arrowLocked is the Ctrl+Right-click lock (Drag.lua)
function api.setFlag(key, on)
	db[key] = on and true or false
	if key == "arrowLocked" then syncArrowLock() else ns.refresh() end
end

-- Upcoming steps: upcomingShown (1-20), upcomingScrollbar, upcomingScrollbarMouseover, upcomingScrollbarColor
function api.setUpcoming(key, value)
	if key == "upcomingShown" then value = Clamp(math.floor((tonumber(value) or 2) + 0.5), 1, ns.ALL_STEPS) end
	if key == "upcomingScrollbarWidth" then value = Clamp(math.floor((tonumber(value) or 3) + 0.5), 1, 12) end
	local range = api.RANGES[key]
	if range then value = Clamp(tonumber(value) or range[3], range[1], range[2]) end
	db[key] = value
	ns.relayout()
	if key:find("^stepCount") and ns.applyStepCount then ns.applyStepCount() end
	if key:find("^arrow") and ns.applyArrowLook then ns.applyArrowLook() end
end

-- min, max, default (the settings window's sliders use the same)
api.RANGES = {
	currentScale = { 0.5, 2, 1 }, currentX = { -60, 120, 0 }, currentY = { -40, 60, 0 },
	upcomingScale = { 0.5, 2, 1 }, upcomingX = { -60, 120, 0 }, upcomingY = { -40, 60, 0 },
	stepCountSize = { 0, 24, 0 }, -- 0: the size it has by default
	arrowAlpha = { 0.1, 1, 1 },
}

-- Waypoint arrow scale: RestedXP's own "Arrow Scale" setting (its profile's arrowScale, 20-200 %), set the way its
-- settings panel sets it (the arrow frame 32 px x scale); the pin and the moons follow the frame's size
function api.getArrowScale()
	return tonumber(ns.rxpProfile().arrowScale) or 1
end
function api.setArrowScale(value)
	value = Clamp(tonumber(value) or 1, 0.2, 2)
	local settings = RXP.settings
	local profile = type(settings) == "table" and settings.profile
	if type(profile) ~= "table" then return end -- RestedXP keeps its settings elsewhere now: leave them alone
	profile.arrowScale = value
	local af = RXP.arrowFrame
	if af and af.SetSize then af:SetSize(32 * value, 32 * value) end
	ns.refresh()
end

-- RestedXP keeps your place in every guide for this character (RXPCData.guideProgress) and returns to it whenever the
-- guide is loaded, so a guide that once ran to its end (by skips, or by being passed through) opens at its end every
-- time. Restart: this guide from its first step (its saved place set to step 1, then RestedXP loads it again, which also
-- clears its finished sticky steps). Reset all: RestedXP's own "Reset Guide Progress".
function api.restartGuide()
	local guide = RXP.currentGuide
	if type(guide) ~= "table" or guide.empty or type(RXP.SaveGuideProgress) ~= "function" then return false end
	pcall(RXP.SaveGuideProgress, guide, 1)
	if type(RXP.ReloadGuide) == "function" then pcall(RXP.ReloadGuide, RXP) end
	if ns.guideChanged then ns.guideChanged() end
	if ns.resetEmptyRetries then ns.resetEmptyRetries() end
	ns.refresh(true)
	ns.say("Restarted " .. tostring(guide.displayname or guide.name) .. " from its first step.")
	return true
end
function api.resetAllProgress()
	if type(RXP.ResetGuideProgress) ~= "function" then return false end
	pcall(RXP.ResetGuideProgress)
	if ns.guideChanged then ns.guideChanged() end
	ns.refresh(true)
	ns.say("Every guide's saved place for this character was cleared: each starts from its first step.")
	return true
end

-- RestedXP's own Lock Frames setting locks the arrow too; the checkbox cannot unlock it then.
function api.lockedByRestedXP()
	return ns.rxpProfile().lockFrames and true or false
end

-- the step buttons' Ctrl+drag position and Ctrl+right-drag size (Action.lua)
function api.resetCircles() if ns.resetCircleOffset then ns.resetCircleOffset() end end

api.maxSteps = ns.MAX_FOLLOWING
api.allSteps = ns.ALL_STEPS -- one past maxSteps: "All"
function api.showWelcome() ns.showWelcome() end   -- /qt welcome
function api.printStatus() ns.printStatus() end   -- /qt status

-- Live status for the window: on/off, guide, step counter, arrow state.
function api.status()
	local out = {}
	out.enabled = db.enabled and true or false
	local guide = RXP.currentGuide
	if guide and not guide.empty and RXP.GetGuideName then
		local ok, name = pcall(RXP.GetGuideName, guide)
		out.guide = ok and name or nil
	end
	local ok, snapshot = pcall(ns.snapshot)
	if ok and snapshot then
		out.counter = snapshot.counter
		out.active = #snapshot.entries - snapshot.following
		out.ahead = snapshot.following
	end
	out.arrow = (db.arrowButton and "button on" or "button off") .. ", satellites " .. (db.arrowSatellites and "on" or "off")
		.. (db.arrowCollapse and " (badge)" or "") .. ", "
		.. ((db.arrowLocked or api.lockedByRestedXP()) and "locked" or "unlocked")
	return out
end

-- "Reset guide settings": the /qt options back to their defaults (quest focus off).
-- keys: only these settings (the /qt page whose Defaults was clicked); nil: every guide setting
function api.reset(keys)
	for _, key in ipairs(OPTIONS) do
		if not keys or keys[key] then
			local value = ns.DEFAULTS[key]
			if type(value) == "table" then value = { unpack(value) } end -- never share the defaults' own table
			db[key] = value
		end
	end
	if (not keys or keys.questFocus or keys.quests) and ns.questFocusOn() then ns.setQuestFocus(false) end
	syncArrowLock()
	ns.updateWindows()
	ns.refresh(true)
end

-- Orphaned quests (RestedXP's "Cleanup Orphaned Quests"): quests in your log that no step of the current guide, and no
-- turn-in still ahead, uses; finished quests are kept. The list is RestedXP's own (GetOrphanedQuests); it is read
-- while RestedXP's window is hidden too, as RestedXP's own button does. Hardcore characters: RestedXP lists none.
function api.orphansAvailable() return type(RXP.GetOrphanedQuests) == "function" end
-- quest -> the quest log header it sits under (the zone, or a category such as a class or a profession)
local function logZones()
	local zones, header = {}, nil
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
			local info = C_QuestLog.GetInfo(i)
			if type(info) == "table" then
				if info.isHeader then header = info.title
				elseif type(info.questID) == "number" then zones[info.questID] = header end
			end
		end
	elseif GetNumQuestLogEntries and GetQuestLogTitle then
		for i = 1, GetNumQuestLogEntries() or 0 do
			local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
			if isHeader then header = title elseif type(questID) == "number" then zones[questID] = header end
		end
	end
	return zones
end

function api.orphans()
	if not api.orphansAvailable() then return {} end
	local wasHidden = RXP.isHidden
	RXP.isHidden = false
	local ok, list = pcall(RXP.GetOrphanedQuests)
	RXP.isHidden = wasHidden
	local out = {}
	if not (ok and type(list) == "table") then return out end
	-- RestedXP lists them bottom of the log first; shown here in quest-log order, each with its zone (log header)
	local zones = logZones()
	for i = #list, 1, -1 do
		local q = list[i]
		if type(q) == "table" and type(q.questID) == "number" then
			out[#out + 1] = { questID = q.questID, title = q.questLogTitleText or ("Quest " .. q.questID), level = q.level,
				zone = zones[q.questID] }
		end
	end
	return out
end

-- the quest log index of a quest now (indices move as quests are abandoned)
local function logIndexOf(questID)
	if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
		local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
		if ok and type(index) == "number" and index > 0 then return index end
	end
	local count = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
	for i = 1, count do
		local id = select(8, GetQuestLogTitle(i))
		if id == questID then return i end
	end
end

-- Abandon one quest the way RestedXP does: select it, mark it to abandon, abandon (no Blizzard confirmation popup)
local function abandonOne(questID)
	local index = logIndexOf(questID)
	if not index then return false end
	if C_QuestLog and C_QuestLog.SetSelectedQuest then
		C_QuestLog.SetSelectedQuest(questID)
	elseif SelectQuestLogEntry then
		SelectQuestLogEntry(index)
	end
	local setAbandon = (C_QuestLog and C_QuestLog.SetAbandonQuest) or _G.SetAbandonQuest
	local abandon = (C_QuestLog and C_QuestLog.AbandonQuest) or _G.AbandonQuest
	if not (setAbandon and abandon) then return false end
	setAbandon()
	abandon()
	return true
end

-- Abandon these quests (questIDs), one every 0.2 s; each is checked to still be an orphan of the current guide first,
-- so a quest the guide started using meanwhile is kept. onDone(count) when finished.
function api.abandonOrphans(ids, onDone)
	local still = {}
	for _, q in ipairs(api.orphans()) do still[q.questID] = q.title end
	local queue = {}
	for _, id in ipairs(ids) do if still[id] then queue[#queue + 1] = id end end
	local count, total = 0, #queue
	local function step()
		local id = table.remove(queue, 1)
		if not id then
			if onDone then onDone(count) end
			return
		end
		local ok, done = pcall(abandonOne, id)
		if ok and done then
			count = count + 1
			ns.say("abandoned " .. tostring(still[id]) .. ".")
		end
		C_Timer.After(0.2, step)
	end
	step()
	return total
end
