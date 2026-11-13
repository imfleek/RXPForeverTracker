local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP, db = ns.rxp, ns.db
local L = ns.L

-- CONSTRAINT: the tracker keeps the view it was given and lays it out again whenever Blizzard does, so a pass fills
-- the one of two views it does not hold, in place: a pass that finds nothing new allocates nothing, and one that throws
-- leaves the tracker's view as it was.
local views = {{entries = {}}, {entries = {}}}
local hidden, unitNames = {}, {}

-- CONSTRAINT: the classic window announces little about the steps ahead: a handler can complete, hide or rewrite one
-- with no message (BottomFrame.UpdateFrame runs the handlers of the steps up to 8 ahead, and those that keep updating
-- at any distance), and its "Go to step" menu calls the SetStep it held at load, which no hook sees. Its heartbeat
-- (CurrentStepFrame.UpdateText, which a classic SetStep ends with too) calls ns.expireGuide: the list goes when its
-- guide or progress moved, and in any case when it is this many seconds old.
local LIST_MAX_AGE = 10

local guideList, listBuilt, listGuide, listProgress
local EMPTY_RETRIES, EMPTY_RETRY_DELAY = 20, 0.25 -- an empty snapshot of a loaded guide: read again, up to 5 s
local emptyRetries = 0

function ns.guideChanged()
	guideList = nil
end

-- a guide load or step change starts the retries afresh
function ns.resetEmptyRetries() emptyRetries = 0 end

function ns.expireGuide()
	if guideList and (GetTime() - listBuilt >= LIST_MAX_AGE or RXP.currentGuide ~= listGuide
		or RXP.GetGuideProgress() ~= listProgress) then
		guideList = nil
	end
end

local function buildList()
	guideList, listBuilt = RXP.v2:BuildGuideStepsSnapshot(), GetTime()
	listGuide, listProgress = RXP.currentGuide, RXP.GetGuideProgress()
end

local function entryAt(view, index)
	local entry = view.entries[index]
	if not entry then
		entry = {lines = {}}
		view.entries[index] = entry
	end
	return entry
end

local function describe(entry, number, title, active, step)
	entry.number, entry.title, entry.active, entry.step = number, title, active, step
end

local function buildEntries(view, after)
	local count = 0
	wipe(hidden)
	wipe(unitNames)
	-- CONSTRAINT: the attach pass runs backwards over the active steps: RestedXP appends the current step last
	-- (GuideWindow.lua SetStep), so the current step claims its units before the sticky and earlier steps that
	-- name the same unit, and a step that uses an item on that unit keeps both circles on its own row. The
	-- slots are then reversed back into activeSteps order, so the drawn order never moves.
	for index = #RXP.RXPFrame.activeSteps, 1, -1 do
		local step = RXP.RXPFrame.activeSteps[index]
		local entry = RXP.v2:IsActiveStepShown(step) and entryAt(view, count + 1)
		if entry and ns.readLines(entry.lines, step) > 0 then
			count = count + 1
			ns.attachUses(step, entry.lines, unitNames)
			local stepIndex = step.index
			describe(entry, stepIndex and tostring(stepIndex) or step.title, stepIndex and step.title, true, step)
		else
			hidden[#hidden + 1] = step
		end
		if step.index and step.index > after then after = step.index end
	end
	-- CONSTRAINT: hidden steps still adopt in activeSteps order: adoptHidden hands their uses to the first
	-- drawn line in list order, and reversing that list would hand a duplicate use to a different step.
	for index = 1, math.floor(#hidden / 2) do
		hidden[index], hidden[#hidden - index + 1] = hidden[#hidden - index + 1], hidden[index]
	end
	for index = 1, math.floor(count / 2) do
		view.entries[index], view.entries[count - index + 1] = view.entries[count - index + 1], view.entries[index]
	end
	if count > 0 then ns.adoptHidden(hidden, view.entries[1].lines, unitNames) end
	return count, after
end

-- CONSTRAINT: with "hide completed steps" RestedXP leaves the completed steps out of the rows, so a row's place in the
-- list is not its step's index (listRow.index is).
-- A small stand-in element per upcoming step ({ step = the guide's step }), reused while that step lives
local stepRefs = setmetatable({}, { __mode = "k" })
local function stepRef(index)
	local guide = RXP.currentGuide
	local step = type(guide) == "table" and type(guide.steps) == "table" and guide.steps[index]
	if type(step) ~= "table" then return nil end
	local ref = stepRefs[step]
	if not ref then
		ref = { step = step, upcoming = true }
		stepRefs[step] = ref
	end
	return ref
end

local function buildFollowing(view, rows, after, count)
	local following = 0
	local limit = db.followingSteps >= (ns.ALL_STEPS or math.huge) and math.huge or db.followingSteps
	for _, listRow in ipairs(rows) do
		if following >= limit then break end
		if listRow.index > after and not listRow.hidden then
			following = following + 1
			local entry = entryAt(view, count + following)
			-- the step itself (by its index), so its line can link the step's items and quest like a current step's
			ns.setLine(entry.lines, 1, nil, stepRef(listRow.index), listRow.text, false, false)
			ns.truncate(entry.lines, 1)
			describe(entry, tostring(listRow.index), nil, false)
		end
	end
	return following
end

-- What the render reads that the entries do not hold.
local function setStyle(view)
	-- CONSTRAINT: the theme's values, not the table: RestedXP edits its Custom theme in place (SettingsPanel.lua
	-- customTheme).
	local font, color = ns.textStyle()
	view.font = font
	view.red, view.green, view.blue, view.alpha = color[1], color[2], color[3], color[4]
	-- CONSTRAINT: ns.textStyle() omits the legacy texturePath that RXP.GetV1Texture reads for the header's logo and badge.
	view.texturePath = type(RXP.activeTheme) == "table" and RXP.activeTheme.texturePath or nil
	view.fontSize = ns.guideFontSize()
end

-- What decides how a view looks, from the view down: the fields compared at each depth and the list that goes deeper.
local LEVELS = {
	{"title", "subtitle", "counter", "progress", "total", "font", "texturePath", "fontSize", "red", "green", "blue", "alpha", list = "entries"},
	{"number", "title", "active", "step", list = "lines"},
	{"text", "done", "note", "frame", list = "uses"},
	{"type", "kind", "name", "id", "icon", "text", "useItem", "useItemName", "useItemIcon"},
}
local NONE = {}

local function same(a, b, depth)
	local level = LEVELS[depth]
	for _, field in ipairs(level) do
		if a[field] ~= b[field] then return false end
	end
	if not level.list then return true end
	local children, others = a[level.list] or NONE, b[level.list] or NONE
	if #children ~= #others then return false end
	for index, child in ipairs(children) do
		if not same(child, others[index], depth + 1) then return false end
	end
	return true
end

-- Whether two snapshots (or none) draw the same view.
function ns.sameView(a, b)
	if not (a and b) then return a == b end
	return same(a, b, 1)
end

-- Nothing to show: the view the tracker does not hold lets go of the steps, frames and elements it held. The tracker's
-- own is drawn again by a Blizzard relayout until the empty view replaces it, and the pass after that releases it.
local function release()
	local drawn = ns.drawn()
	for _, view in ipairs(views) do
		if view ~= drawn then wipe(view.entries) end
	end
	return nil
end

function ns.snapshot()
	if not db.enabled then
		guideList = nil
		return release()
	end
	if not guideList then buildList() end
	local snap = guideList
	if #snap.rows == 0 then
		-- A guide RestedXP has only just loaded (the first time in a session: it parses it then) can have no rows in
		-- its snapshot yet. That empty list was kept until the next step change, so the RXP Tracker vanished after
		-- going back to a previous guide. It is not kept: the list is read again shortly, for a few seconds.
		guideList = nil
		local guide = RXP.currentGuide
		if type(guide) == "table" and not guide.empty and type(guide.steps) == "table" and #guide.steps > 0 then
			if emptyRetries < EMPTY_RETRIES then
				emptyRetries = emptyRetries + 1
				C_Timer.After(EMPTY_RETRY_DELAY, function() ns.guideChanged(); ns.invalidate() end)
			end
		end
		return release()
	end
	emptyRetries = 0

	local progress = RXP.GetGuideProgress()
	-- CONSTRAINT: not #snap.rows, which shrinks with "hide completed steps".
	local total = RXP.currentGuide and RXP.currentGuide.steps and #RXP.currentGuide.steps or #snap.rows
	local view = ns.drawn() == views[1] and views[2] or views[1]
	view.title = snap.title
	view.subtitle = snap.subtitle
	view.counter = string.format(L("Step %d") .. "/%d", progress, total)
	view.progress, view.total = progress, total
	setStyle(view)
	local count, after = buildEntries(view, progress - 1)
	view.following = buildFollowing(view, snap.rows, after, count)
	ns.truncate(view.entries, count + view.following)
	return view
end
