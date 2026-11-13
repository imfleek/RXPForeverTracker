local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP, db = ns.rxp, ns.db

local NONE = {}
local TURN_IN_TAGS = {turnin = true, turninmultiple = true, dailyturnin = true}
local list, seen, rank, aheadRef, resolved, keep, watched = {}, {}, {}, {}, {}, {}, {}
local ranked

local function watchedQuests(into)
	for index = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
		if questID then into[#into + 1] = questID end
	end
	return into
end

-- CONSTRAINT: checkMirror (GetQuestId's third argument) returns the faction mirror the player holds.
local function note(id, ahead, turnIn)
	local questID = resolved[id]
	if questID == nil then
		questID = RXP.GetQuestId(id, nil, true)
		questID = questID and ns.inQuestLog(questID) and questID
		resolved[id] = questID
	end
	if not questID then return end
	if not rank[questID] then
		ranked = ranked + 1
		rank[questID] = ranked
	end
	if ahead then aheadRef[questID] = true end
	if turnIn and not seen[questID] then
		seen[questID] = true
		list[#list + 1] = questID
	end
end

local function byRank(a, b)
	return rank[a] < rank[b]
end

local function noteTurnIns(steps, progress)
	for s = 1, #steps do
		local step = steps[s]
		local ahead = progress == nil or (step.index or 0) >= progress
		if step.active or ahead then
			local elements = step.elements or NONE
			for e = 1, #elements do
				local element = elements[e]
				local tag = element.tag
				local turnIn = TURN_IN_TAGS[tag]
				if (turnIn or tag == "complete") and not (element.completed or element.skip) then
					local ids = element.ids
					if ids then
						for i = 1, #ids do note(ids[i], ahead, turnIn) end
					elseif element.questId then
						note(element.questId, ahead, turnIn)
					end
				end
			end
		end
	end
end

-- CONSTRAINT: a nil progress marks every step of the fetched guide ahead, so the next guide's turn-ins rank strictly
-- after the current guide's and superTrack may fall back to them.
local LOOKAHEAD_MAX = 8

local function lookaheadTurnIns(guide)
	local visited = {}
	for _ = 1, LOOKAHEAD_MAX do
		local group, name -- never RestedXP's functions.next: it can load a guide (SkipBox.lua peekNextGuide)
		if ns.peekNextGuide then group, name = ns.peekNextGuide(guide) end
		if not (group and name) then return end
		local nextGuide = RXP:FetchGuide(group, name)
		if not nextGuide or not nextGuide.steps or visited[nextGuide.key or nextGuide] then return end
		visited[guide.key or guide] = true
		guide = nextGuide
		noteTurnIns(guide.steps or NONE, nil)
		if #list > 0 then return end
	end
end

local function guideTurnIns()
	local guide = RXP.currentGuide
	if not guide or guide.empty then return nil end
	wipe(list)
	wipe(seen)
	wipe(rank)
	wipe(aheadRef)
	wipe(resolved)
	ranked = 0
	noteTurnIns(guide.steps or NONE, RXP.GetGuideProgress())
	local currentCount = #list
	-- CONSTRAINT: the bridge engages while one watch candidate is left, so handing in the last quest never empties
	-- the tracker; it adds the nearest ahead quest of the next guide only, not that guide's whole turn-in list.
	if currentCount <= 1 then
		lookaheadTurnIns(guide)
		for i = currentCount + 2, #list do list[i] = nil end
	end
	table.sort(list, byRank)
	for i = 1, #list do
		if aheadRef[list[i]] then return list, list[i] end
	end
	return list
end

function ns.questRank(questID)
	return rank[questID]
end

-- CONSTRAINT: removals run first, so adds stay under Constants.QuestWatchConsts.MAX_QUEST_WATCHES (25).
-- CONSTRAINT: CanRemoveQuestWatch() is false for New Player Experience characters.
local function applyWatches(wanted)
	wipe(keep)
	for i = 1, #wanted do keep[wanted[i]] = true end
	if QuestUtil.CanRemoveQuestWatch() then
		wipe(watched)
		watchedQuests(watched)
		for i = 1, #watched do
			if not keep[watched[i]] then C_QuestLog.RemoveQuestWatch(watched[i]) end
		end
	end
	for i = 1, #wanted do
		if not QuestUtils_IsQuestWatched(wanted[i]) then C_QuestLog.AddQuestWatch(wanted[i]) end
	end
end

-- CONSTRAINT: set only when the guide's active quest changes, so a POI click on another quest stays until then.
local superTracked
local function superTrack(questID)
	if questID == superTracked then return end
	if questID then
		C_SuperTrack.SetSuperTrackedQuestID(questID)
	elseif C_SuperTrack.GetSuperTrackedQuestID() == superTracked then
		C_SuperTrack.SetSuperTrackedQuestID(0)
	end
	superTracked = questID
end

function ns.questFocusOn()
	return db.questFocus[ns.playerGUID()] == true
end

local function savedInLog(key)
	wipe(list)
	local saved = db.questFocusSaved[key]
	for i = 1, #saved do
		local questID = saved[i]
		if ns.inQuestLog(questID) then list[#list + 1] = questID end
	end
	return list
end

-- CONSTRAINT: no watch change in combat: QUEST_WATCH_LIST_CHANGED marks the secure item-button tracker dirty.
local function sync()
	local key = ns.playerGUID()
	if not key or InCombatLockdown() then return end
	if db.questFocus[key] then
		local wanted, active = guideTurnIns()
		-- CONSTRAINT: an empty scan keeps the watches as they are; wiping them would strand the tracker until the
		-- guide offers new turn-ins, and stale ones leave the log on their own as the client untracks them.
		if wanted and #wanted > 0 then
			applyWatches(wanted)
			superTrack(active)
		end
	elseif db.questFocusSaved[key] then
		applyWatches(savedInLog(key))
		superTrack(nil)
		db.questFocusSaved[key] = nil
	end
end

local dirty = CreateFromMixins(DirtiableMixin)
-- CONSTRAINT: DirtiableMixin clears `dirty` after the method returns; an error would block every later pass.
dirty:SetDirtyMethod(function() xpcall(sync, geterrorhandler()) end)

local function markDirty()
	dirty:MarkDirty()
end

function ns.setQuestFocus(on)
	local key = ns.playerGUID()
	if not key then
		ns.say("Quest tracker: this character is not readable right now. Try again.")
		return
	end
	if on and not db.questFocusSaved[key] then db.questFocusSaved[key] = watchedQuests({}) end
	db.questFocus[key] = on or nil
	markDirty()
	ns.say((on and "Quest tracker: only quests this guide still turns in, ready ones small and last."
		or "Quest tracker: back to the quests you tracked before.")
		.. (InCombatLockdown() and " Applies when combat ends." or ""))
end

ns.onStepChange(markDirty)
ns.onRxpMessage("RXPGuidesV2_GuideStepsChanged", markDirty)
ns.listen({
	QUEST_LOG_UPDATE = markDirty,
	QUEST_WATCH_LIST_CHANGED = markDirty,
	PLAYER_REGEN_ENABLED = markDirty,
})
