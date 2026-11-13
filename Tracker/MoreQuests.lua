-- More quests: the quests in the log that the game will not track.
--
-- Blizzard's tracker draws only watched quests, and the game caps the watch list
-- (Constants.QuestWatchConsts.MAX_QUEST_WATCHES; 20 seen on Forever), so with "Track all quests" a full log (up to 40)
-- showed only the first 20. This section lists the rest below Blizzard's quests, in the tracker's fonts: title (with
-- level, in difficulty colour) and objectives. It is anchored below the lowest Blizzard section, so it scrolls with
-- the list, and Core's scroll range includes it (api.moreQuestsBottom). Plain frames only: nothing protected.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api
local tracker = ObjectiveTrackerFrame
local db

local GAP, INDENT, LINE_GAP, QUEST_GAP = 8, 12, 2, 7
local schedule -- defined at the end
local frame, rows = nil, {}
-- the Quest Tracker opacity (general x Quest Tracker, /qt Advanced): the section is on UIParent, outside the viewport
function api.applyMoreQuestsAlpha()
	if frame and api.questTrackerAlpha then frame:SetAlpha(api.questTrackerAlpha()) end
end
local used = 0

local function isSecret(v) return issecretvalue and issecretvalue(v) or false end
local function clean(v) return type(v) == "string" and not isSecret(v) and v or nil end

local function watchLimit()
	return (Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES) or nil
end

local function font(name, fallback)
	return _G[name] and name or fallback
end

local function wanted()
	return db and db.enabled and db.moreQuests ~= false and db.trackMode == "all"
end

-- One FontString per line, pooled; titles get a click button.
local function row(i)
	local r = rows[i]
	if not r then
		r = frame:CreateFontString(nil, "OVERLAY")
		r:SetJustifyH("LEFT")
		r:SetWordWrap(true)
		rows[i] = r
	end
	return r
end

local clickers = {}
local function clicker(i, fs, questID)
	local b = clickers[i]
	if not b then
		b = CreateFrame("Button", nil, frame)
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function(self)
			local id = self.questID
			if not id then return end
			if QuestMapFrame_OpenToQuestDetails then
				pcall(QuestMapFrame_OpenToQuestDetails, id)
			elseif ToggleQuestLog then
				pcall(ToggleQuestLog)
			end
		end)
		b:SetScript("OnEnter", function(self)
			local limit = watchLimit()
			local function notTracked(tip)
				tip:AddLine(" ")
				tip:AddLine(("Not tracked: the game tracks at most %s quests."):format(limit or "a limited number of"),
					0.8, 0.8, 0.8, true)
				tip:AddLine("Click: open in the quest log.", 0.6, 0.6, 0.6, true)
			end
			-- the same quest tooltip as the tracked quests (overview, objectives, rewards, party), when tooltips are on
			if api.showQuestTooltip and api.showQuestTooltip(self, self.questID, self.title, notTracked) then return end
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(self.title or "", 1, 1, 1, 1, true)
			notTracked(GameTooltip)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
		clickers[i] = b
	end
	b.questID = questID
	b.title = fs:GetText()
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", fs, "TOPLEFT")
	b:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT")
	b:Show()
	return b
end

local function difficultyColor(level)
	if GetQuestDifficultyColor and type(level) == "number" then
		local ok, c = pcall(GetQuestDifficultyColor, level)
		if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
	end
	return 1, 0.82, 0
end

-- The quests to list: in the log, not headers, not hidden or world/bonus tasks, not watched, not hidden by the zone
-- filter. Grouped under their quest-log headers, in quest-log order.
local function collect()
	local list, header = {}, nil
	local n = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
	for i = 1, n do
		local info = C_QuestLog.GetInfo(i)
		if info then
			if info.isHeader then
				header = clean(info.title)
			elseif info.questID and not isSecret(info.questID) and not info.isHidden and not info.isTask
				and not info.isBounty and C_QuestLog.GetQuestWatchType(info.questID) == nil
				and not (db.zoneHidden and db.zoneHidden[info.questID]) then
				local zone = api.questieZone and api.questieZone(info.questID) or header -- Questie: where it is done
				list[#list + 1] = { id = info.questID, title = clean(info.title) or "?", level = info.level, header = zone,
					order = #list + 1 }
			end
		end
	end
	-- sorting by zone: the same closest-zone-first order as the tracked quests (ZoneSort.lua)
	if db.zoneSort and api.orderQuests then
		local entries = {}
		for i, q in ipairs(list) do entries[i] = { id = q.id, zone = q.header or "", index = q.order, item = q } end
		local ok, ordered = pcall(api.orderQuests, entries)
		if ok and type(ordered) == "table" then
			for i, e in ipairs(ordered) do list[i] = e.item end
		end
	end
	return list
end

-- The Blizzard section whose last shown quest is lowest, and that quest's bottom (UIParent units, from Core).
local function lowestModule()
	local lowest, lowestBottom
	for _, module in ipairs(tracker.modules or {}) do
		if module:IsShown() and (module.GetContentsHeight == nil or module:GetContentsHeight() > 0) then
			local b = api.moduleContentBottom and api.moduleContentBottom(module)
			if b and (not lowestBottom or b < lowestBottom) then lowest, lowestBottom = module, b end
		end
	end
	return lowest, lowestBottom
end

local function questScale()
	return math.min(math.max(tonumber(db.questScale) or 1, 0.5), 1.5)
end

local function hide()
	if frame then frame:Hide() end
end

-- Position, scale and width, every tracker layout pass (Core.lua refresh).
function api.layoutMoreQuests()
	if not frame or used == 0 or not wanted() then hide() return end
	local viewport = _G.RXPForeverTrackerViewport
	local anchor, contentBottom = lowestModule()
	-- the whole tracker collapsed, or the "Quests" section folded with its collapse button: these quests go too
	local questModule = _G.QuestObjectiveTracker
	local questsFolded = questModule and questModule.IsCollapsed and questModule:IsCollapsed()
	if not viewport or not anchor or not tracker:IsShown() or (tracker.IsCollapsed and tracker:IsCollapsed())
		or questsFolded then
		hide()
		return
	end
	if frame:GetParent() ~= viewport then frame:SetParent(viewport) end
	local qs = questScale()
	local scale = tracker:GetEffectiveScale() / viewport:GetEffectiveScale() * qs
	if math.abs(frame:GetScale() - scale) > 1e-4 then frame:SetScale(scale) end
	frame:SetFrameStrata(tracker:GetFrameStrata())
	frame:SetFrameLevel(tracker:GetFrameLevel() + 1)
	local width = tracker:GetWidth() / qs
	if frame.builtWidth and math.abs(frame.builtWidth - width) > 1 then schedule() end -- text wraps at the old width
	-- anchored to the section's top (it moves with the section when the list scrolls), as far down as its last shown
	-- quest; offsets are in this frame's own scale
	local anchorTop = anchor:GetTop()
	if not anchorTop then hide() return end
	local uiScale = UIParent:GetEffectiveScale()
	local down = (anchorTop * anchor:GetEffectiveScale() / uiScale - contentBottom) * uiScale / frame:GetEffectiveScale()
	frame:ClearAllPoints()
	local gap = frame.look and frame.look.blockGap or GAP
	frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(math.max(down, 0) + gap))
	frame:SetWidth(width)
	frame:Show()
end

-- Bottom of the section in UIParent units, for the scroll range.
function api.moreQuestsBottom()
	if not frame or not frame:IsShown() then return nil end
	local b = frame:GetBottom()
	return b and b * frame:GetEffectiveScale() / UIParent:GetEffectiveScale() or nil
end

-- How Blizzard draws a quest, read from one it is showing (QuestObjectiveTracker.usedBlocks): fonts, colours, the
-- title's and the objective lines' horizontal offsets within the section, and the spacing. The section's own fields
-- (fromBlockOffsetY, lineSpacing) give the spacing; fallbacks keep the list usable before any quest was drawn.
local OTC = _G.OBJECTIVE_TRACKER_COLOR
local function colorOf(key, r, g, b)
	local c = OTC and OTC[key]
	if type(c) == "table" and c.r then return c.r, c.g, c.b end
	return r, g, b
end
local function fontOf(fs, fallbackObject)
	if fs and fs.GetFont then
		local file, size, flags = fs:GetFont()
		if file and size then return { file, size, flags } end
	end
	local object = _G[fallbackObject]
	if object and object.GetFont then
		local file, size, flags = object:GetFont()
		if file and size then return { file, size, flags } end
	end
	return { STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "" }
end

local function sample(module)
	local look = {
		headerX = 0, dashX = 0, textX = 12, blockGap = 10, lineGap = 2,
		header = fontOf(nil, "ObjectiveTrackerHeaderFont"), line = fontOf(nil, "ObjectiveTrackerLineFont"),
		headerColor = { colorOf("Header", 0.75, 0.61, 0) },
		normalColor = { colorOf("Normal", 0.8, 0.8, 0.8) },
		completeColor = { colorOf("Complete", 0.6, 0.6, 0.6) },
	}
	if type(module.fromBlockOffsetY) == "number" then look.blockGap = math.abs(module.fromBlockOffsetY) end
	if type(module.lineSpacing) == "number" then look.lineGap = module.lineSpacing end
	local left = module:GetLeft()
	if not left or type(module.usedBlocks) ~= "table" then return look end
	for _, byId in pairs(module.usedBlocks) do
		if type(byId) == "table" then
			for _, block in pairs(byId) do
				local header = type(block) == "table" and block.IsShown and block:IsShown() and block.HeaderText
				if header and header.GetLeft and header:GetLeft() then
					look.headerX = header:GetLeft() - left
					look.header = fontOf(header, "ObjectiveTrackerHeaderFont")
					for _, line in pairs(type(block.usedLines) == "table" and block.usedLines or {}) do
						local text = type(line) == "table" and line.Text
						if text and text.GetLeft and text:GetLeft() then
							look.textX = text:GetLeft() - left
							look.line = fontOf(text, "ObjectiveTrackerLineFont")
							local dash = line.Dash
							look.dashX = (dash and dash.IsShown and dash:IsShown() and dash:GetLeft()) and (dash:GetLeft() - left)
								or look.headerX
							break
						end
					end
					return look
				end
			end
		end
	end
	return look
end

local labels = {}
local function zoneLabel(i)
	local label = labels[i]
	if not label then
		label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetJustifyH("LEFT")
		labels[i] = label
	end
	if api.styleZoneLabel then api.styleZoneLabel(label) end
	return label
end

local dashes = {}
local function dashText(i)
	local d = dashes[i]
	if not d then
		d = frame:CreateFontString(nil, "OVERLAY")
		dashes[i] = d
	end
	return d
end

-- What the section would show, as one string: quest log updates come often (every few seconds, on any change of any
-- quest), and most change nothing shown here; then the rows are left as they are. A setting change always redraws.
local lastSignature
local forceBuild = false
local function colorKey(c) return c and ("%.3f,%.3f,%.3f"):format(c[1] or 0, c[2] or 0, c[3] or 0) or "" end

local function build()
	if not db then return end
	if not frame then
		frame = CreateFrame("Frame", "RXPForeverTrackerMoreQuests", UIParent)
		if api.applyMoreQuestsAlpha then api.applyMoreQuestsAlpha() end
		frame:SetSize(200, 10)
		frame:Hide()
	end
	local function clear()
		for _, r in ipairs(rows) do r:Hide(); if api.hideTitleIcons then api.hideTitleIcons(r) end end
		for _, b in ipairs(clickers) do b:Hide() end
		for _, l in ipairs(labels) do l:Hide() end
		for _, d in ipairs(dashes) do d:Hide() end
		used = 0
		lastSignature = nil
	end
	local list = wanted() and collect() or {}
	local module = _G.QuestObjectiveTracker
	if #list == 0 or not module then
		local had = used > 0
		clear()
		hide()
		if had and api.applyLayout then api.applyLayout() end
		return
	end

	-- seamless: no heading of its own; Blizzard's fonts, colours, offsets and spacing (sample)
	local look = sample(module)
	local qs = questScale()
	local width = math.max(tracker:GetWidth() / qs, 120)

	-- everything to draw, first as data
	local entries = {}
	local parts = { width, qs, tostring(db.zoneSort), db.zoneHeaderX or 4, tonumber(db.questTitleX) or 0, tonumber(db.zoneHeaderY) or 0,
		tostring(api.lastTrackedZone),
		look.header[1], look.header[2], look.line[1], look.line[2], look.headerX, look.dashX, look.textX, look.lineGap,
		look.blockGap, colorKey(look.headerColor), colorKey(look.normalColor), colorKey(look.completeColor) }
	for _, quest in ipairs(list) do
		local title = (type(quest.level) == "number" and quest.level > 0) and ("[%d] %s"):format(quest.level, quest.title)
			or quest.title
		if api.rewardSuffix then title = title .. api.rewardSuffix(quest.id) end
		local star = api.attunementIcon and api.attunementIcon(quest.id)
		local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(quest.id) and true or false
		local lines = {}
		if complete then
			lines[1] = { QUEST_WATCH_QUEST_READY or "Ready for turn-in", true }
		else
			local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, quest.id)
			for _, o in ipairs(ok and type(objectives) == "table" and objectives or {}) do
				local text = clean(o.text)
				if text and text ~= "" then lines[#lines + 1] = { text, o.finished and true or false } end
			end
		end
		entries[#entries + 1] = { quest = quest, title = title, star = star, complete = complete, lines = lines }
		parts[#parts + 1] = quest.id .. "|" .. tostring(quest.header) .. "|" .. title .. (star and "*" or "") .. (complete and "v" or "")
		for _, line in ipairs(lines) do parts[#parts + 1] = (line[2] and "+" or "-") .. line[1] end
	end
	local signature = table.concat(parts, "\n")
	if not forceBuild and signature == lastSignature then
		api.layoutMoreQuests()
		return
	end
	forceBuild = false
	clear()
	lastSignature = signature
	frame.look = look
	frame.builtWidth = tracker:GetWidth() / qs
	local y, click, zones, dashCount = 0, 0, 0, 0
	local function add(text, f, x, color, rightPad, icons)
		used = used + 1
		local fs = row(used)
		fs:SetFont(f[1], f[2], f[3])
		fs:SetWidth(math.max(width - x - (rightPad or 4), 40))
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
		-- icons left of the title, outside it (Extras.lua): they never move the text
		if icons and icons[1] and api.placeTitleIcons then
			text = api.placeTitleIcons(fs, icons) .. text
		elseif api.hideTitleIcons then
			api.hideTitleIcons(fs)
		end
		fs:SetText(text)
		fs:SetTextColor(color[1], color[2], color[3])
		fs:Show()
		y = y + (fs:GetStringHeight() or f[2]) + look.lineGap
		return fs
	end

	local lastZone = db.zoneSort and api.lastTrackedZone or nil
	for index, entry in ipairs(entries) do
		local quest = entry.quest
		if index > 1 then y = y + look.blockGap - look.lineGap end
		if db.zoneSort and quest.header and quest.header ~= lastZone then
			lastZone = quest.header
			-- the same room and place as ZoneSort's headers above Blizzard's quests
			y = y + (api.zoneHeaderHeight and api.zoneHeaderHeight() or 14)
			zones = zones + 1
			local label = zoneLabel(zones)
			label:ClearAllPoints()
			label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", look.headerX + (db.zoneHeaderX or 4) - 4 - (tonumber(db.questTitleX) or 0),
				-y + 2 + (tonumber(db.zoneHeaderY) or 0))
			label:SetText(quest.header)
			label:Show()
		end
		local fs = add(entry.title, look.header, look.headerX, look.headerColor, nil, entry.star and { entry.star } or nil)
		-- a finished quest: the green check on its own, left of the title (Extras.lua)
		if api.placeCheck then api.placeCheck(fs, entry.complete) end
		click = click + 1
		clicker(click, fs, quest.id)
		local lines = {}
		for i, line in ipairs(entry.lines) do
			lines[i] = { line[1], line[2] and look.completeColor or look.normalColor }
		end
		for _, line in ipairs(lines) do
			if look.textX > look.dashX then
				dashCount = dashCount + 1
				local d = dashText(dashCount)
				d:SetFont(look.line[1], look.line[2], look.line[3])
				d:SetText(QUEST_DASH or "- ")
				d:SetTextColor(line[2][1], line[2][2], line[2][3])
				d:ClearAllPoints()
				d:SetPoint("TOPLEFT", frame, "TOPLEFT", look.dashX, -y)
				d:Show()
			end
			add(line[1], look.line, look.textX, line[2])
		end
	end
	frame:SetHeight(math.max(y, 1))
	api.layoutMoreQuests()
	if api.applyLayout then api.applyLayout() end -- the scroll range changed
end

---------------------------------------------------------------------------------------------------------------------
-- Quest count on the "Quests" header: "31/40" left of its collapse button
---------------------------------------------------------------------------------------------------------------------
-- Quests in the log (the second return of GetNumQuestLogEntries counts quests, not headers) out of the log's
-- maximum. Green up to 26, yellow 27-36, orange 37-39, red when full: the same breakpoints scaled to the maximum when
-- it is not 40.
local countText
local function countColor(count, max)
	if count >= max then return 1, 0.2, 0.2 end
	if count >= math.floor(max * 37 / 40 + 0.5) then return 1, 0.55, 0.1 end
	if count >= math.floor(max * 27 / 40 + 0.5) then return 1, 0.9, 0.2 end
	return 0.3, 0.9, 0.3
end
function api.updateQuestCount()
	local module = _G.QuestObjectiveTracker
	local header = module and module.Header
	if not header then return end
	if not countText then
		countText = header:CreateFontString(nil, "OVERLAY")
		countText:SetJustifyH("RIGHT")
	end
	local anchor = header.MinimizeButton or header
	-- the header text's font (whatever addon set it); all three values, or the game's normal font
	local file, size, flags
	if header.Text and header.Text.GetFont then file, size, flags = header.Text:GetFont() end
	if not (file and size) then file, size, flags = GameFontNormal:GetFont() end
	if not (file and size) then return end
	-- Quest list > Quest count: its own text size (0 = the header's)
	local ownSize = tonumber(db and db.questCountSize) or 0
	if ownSize > 0 then size = ownSize end
	countText:SetFont(file, size, flags or "")
	countText:ClearAllPoints()
	countText:SetPoint("RIGHT", anchor, header.MinimizeButton and "LEFT" or "RIGHT", -6, 0)
	local ok, _, quests = pcall(C_QuestLog.GetNumQuestLogEntries)
	local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 40
	if not ok or type(quests) ~= "number" or isSecret(quests) or type(max) ~= "number" or max <= 0 then
		countText:SetText("")
		return
	end
	countText:SetText(("%d/%d"):format(quests, max))
	-- a custom colour replaces the green / yellow / orange / red of how full the log is
	-- its opacity always applies (the colour picker's opacity bar)
	local saved = db and type(db.questCountColor) == "table" and db.questCountColor or nil
	local alpha = saved and saved[4] or 1
	local c = db and db.questCountCustom and saved
	if c then
		countText:SetTextColor(c[1], c[2], c[3], alpha)
	else
		local r, g, b = countColor(quests, max)
		countText:SetTextColor(r, g, b, alpha)
	end
	countText:SetShown(db and db.enabled and db.questCount ~= false)
end

local pending
function schedule()
	if pending then return end
	pending = true
	C_Timer.After(0.2, function()
		pending = nil
		xpcall(api.updateQuestCount, geterrorhandler())
		xpcall(build, geterrorhandler())
	end)
end
-- settings and other modules: always redraw (colours, fonts, zone header looks are not in the signature)
api.rebuildMoreQuests = function() forceBuild = true; schedule() end

ns.onLogin[#ns.onLogin + 1] = function()
	db = ns.db
	local events = CreateFrame("Frame")
	for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED",
		"QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnEvent", schedule)
	schedule()
	-- folding or unfolding the "Quests" section hides or shows these quests at once (the next layout pass places them)
	local questModule = _G.QuestObjectiveTracker
	if hooksecurefunc and questModule and type(questModule.SetCollapsed) == "function" then
		hooksecurefunc(questModule, "SetCollapsed", function()
			C_Timer.After(0, function() pcall(api.layoutMoreQuests) end)
		end)
	end
end
