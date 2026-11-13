local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local SCALE, DIM_ALPHA, TOLERANCE, MAX_BLOCKS = 0.85, 0.8, 0.01, 200
local CHECK = " |A:ui-questtracker-tracker-check:12:12|a"
local READY_KEY = "QuestComplete"

-- CONSTRAINT: widget calls and field reads only: a Blizzard field written from here would taint the tracker.
-- CONSTRAINT: a block another add-on's protected frame hangs on is not resized or moved in combat; the next safe layout
-- does it (Blizzard's own quest item and POI buttons are plain).
local original, styled, shifted, readyBlocks = {}, {}, {}, {}
local heightDelta = 0

-- CONSTRAINT: Blizzard's Edit Mode sets its own font size over ours: a size that is no longer ours stays.
local function setScale(fontString, scale)
	local saved = original[fontString]
	if scale == 1 and saved == nil then return false end
	local font, size, flags = fontString:GetFont()
	if not size then return false end
	if saved and math.abs(size - saved * SCALE) > TOLERANCE then
		saved = nil
		original[fontString] = nil
	end
	if scale == 1 then
		if not saved then return false end
		fontString:SetFont(font, saved, flags)
		original[fontString] = nil
		return true
	end
	if saved then return false end
	fontString:SetFont(font, size * scale, flags)
	original[fontString] = size
	return true
end

-- CONSTRAINT: frames pooled across modules (ObjectiveTrackerManager:ReleaseFrame) keep their own font on release.
hooksecurefunc(ObjectiveTrackerManager, "ReleaseFrame", function(_, frame)
	shifted[frame] = nil
	if frame.HeaderText then setScale(frame.HeaderText, 1) end
	if frame.Text then setScale(frame.Text, 1) end
end)

local function indent(module, block)
	block:SetPoint("LEFT", 0, 0)
	if not block.fixedWidth then
		block:SetPoint("RIGHT", block:GetParent(), "RIGHT", -(block.offsetX or module.blockOffsetX), 0)
	end
end

local function restyleHeader(header, scale, ready, delta)
	local before = header:GetHeight()
	header:SetHeight(0)
	local changed = setScale(header, scale)
	local text = header:GetText()
	if ready and text and not text:find(CHECK, -#CHECK, true) then
		header:SetText(text .. CHECK)
		changed = true
	end
	if changed then delta = delta + header:GetHeight() - before end
	return delta
end

local function restyleLines(block, scale, hiddenLine, delta)
	for _, other in pairs(block.usedLines) do
		local fontString = other.Text
		if fontString and other ~= hiddenLine and setScale(fontString, scale) then
			local lineBefore = other:GetHeight()
			fontString:SetHeight(0)
			local height = fontString:GetHeight()
			other:SetHeight(height)
			if other:IsShown() then delta = delta + height - lineBefore end
		end
	end
	return delta
end

-- CONSTRAINT: runs after LayoutBlock; SetHeight pulls later blocks up and module.contentsHeight is left stale: the
-- module's own height follows (UpdateHeight hook below).
-- CONSTRAINT: an untouched block needs no restore: Blizzard's SetStringText resets header and line heights anyway.
local function mark(module, quest)
	local block = module:GetExistingBlock(quest:GetID())
	local header = block and block.HeaderText
	if not header then return end
	local ready = ns.questFocusOn() and quest:IsComplete() and not quest.isAutoComplete
	if ready then styled[block] = true elseif not styled[block] then return end
	header:SetAlpha(ready and DIM_ALPHA or 1)
	readyBlocks[block] = ready or nil
	shifted[block] = nil
	-- CONSTRAINT: OnLayout reshows the POI button every layout.
	local button = block.poiButton
	if ready and button and button:IsShown() and not ns.protectedInCombat(button) then button:Hide() end
	local line = block.usedLines[READY_KEY]
	local resize = block.used and not ns.protectedInCombat(block)
	local compact = ready and resize and line
	if line and not compact and not line:IsShown() then line:Show() end
	if not resize then return end
	if ready and button and not button:IsShown() then
		shifted[block] = true
		indent(module, block)
	end
	local scale = ready and SCALE or 1
	local delta = compact and -(line:GetHeight() + module.lineSpacing) or 0
	if compact then line:Hide() end
	delta = restyleHeader(header, scale, ready, delta)
	delta = restyleLines(block, scale, compact and line, delta)
	if delta ~= 0 then
		block:SetHeight(block:GetHeight() + delta)
		heightDelta = heightDelta + delta
	end
	if not ready then styled[block] = nil end
end

-- CONSTRAINT: mirrors AnchorBlock; nextBlock order is Blizzard's.
-- CONSTRAINT: the client re-sorts the watch list on zone changes; guide order is re-set on the anchors each layout.
local chain, sinkFirst, sinkLast = {}, {}, {}

local function anchorList(module, blocks, previous)
	for _, member in ipairs(blocks) do
		member:ClearAllPoints()
		if previous then
			member:SetPoint("TOP", previous, "BOTTOM", 0, module.fromBlockOffsetY)
		else
			member:SetPoint("TOP", module.ContentsFrame, "TOP", 0, module.fromHeaderOffsetY)
		end
		if shifted[member] then
			indent(module, member)
		else
			member:SetPoint("LEFT", member.offsetX or module.blockOffsetX, 0)
			if not member.fixedWidth then member:SetPoint("RIGHT") end
		end
		previous = member
	end
	return previous
end

-- CONSTRAINT: an auto-quest popup's block id is a string; Blizzard lists those first.
local function rankOf(block)
	if type(block.id) ~= "number" then return -math.huge end
	return ns.questRank(block.id) or math.huge
end

local function sortByRank(blocks)
	for i = 2, #blocks do
		local block = blocks[i]
		local key = rankOf(block)
		local j = i - 1
		while j >= 1 and rankOf(blocks[j]) > key do
			blocks[j + 1] = blocks[j]
			j = j - 1
		end
		blocks[j + 1] = block
	end
end

local function sink(module)
	if not ns.questFocusOn() then return end
	wipe(chain)
	wipe(sinkFirst)
	wipe(sinkLast)
	local blocked = false
	local block = module.firstBlock
	while block and #chain < MAX_BLOCKS do
		if ns.protectedInCombat(block) then blocked = true break end
		chain[#chain + 1] = block
		local list = readyBlocks[block] and sinkLast or sinkFirst
		list[#list + 1] = block
		block = block.nextBlock
	end
	if not blocked then
		sortByRank(sinkFirst)
		sortByRank(sinkLast)
		local ahead = #sinkFirst
		for i = 1, #chain do
			if chain[i] ~= (i <= ahead and sinkFirst[i] or sinkLast[i - ahead]) then
				anchorList(module, sinkLast, anchorList(module, sinkFirst, nil))
				break
			end
		end
	end
end

hooksecurefunc(QuestObjectiveTracker, "UpdateSingle", function(module, quest)
	xpcall(mark, geterrorhandler(), module, quest)
end)

hooksecurefunc(QuestObjectiveTracker, "BeginLayout", function()
	heightDelta = 0
end)

hooksecurefunc(QuestObjectiveTracker, "LayoutContents", function(module)
	xpcall(sink, geterrorhandler(), module)
	wipe(readyBlocks)
end)

hooksecurefunc(QuestObjectiveTracker, "UpdateHeight", function(module)
	if heightDelta ~= 0 and not ns.protectedInCombat(module) then module:SetHeight(module:GetHeight() + heightDelta) end
end)
