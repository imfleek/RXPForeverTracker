-- Prerequisite Journal (the book icon before the guide name, or Ctrl+right-click the RXP Tracker): the quests ahead in the current RestedXP guide that
-- cannot be accepted yet because a prerequisite quest is not done, and step by step how to do those prerequisites.
-- Data from Questie (Questie.lua api.prereqPlan); the look is the /qt window's (Config.lua api.themeKit).
local _, root = ...; local ns = root.tracker
if not ns or root.disabledAll then return end
local api = ns.api

local WIDTH, HEIGHT, MIN_W, MIN_H, MAX_W, MAX_H = 620, 600, 460, 360, 1200, 1100
local MAX_QUESTS = 250 -- accept steps checked per refresh
local PAD, INDENT = 14, 18

-- a step's icon instead of a dash: ! accept, ? turn in, sword kill, bag buy, hand collect, cog use
local ICON_SIZE = 16
local STEP_ICONS = {
	accept = "Interface\\GossipFrame\\AvailableQuestIcon",
	turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
	kill = "Interface\\CURSOR\\Attack",
	buy = "Interface\\Icons\\INV_Misc_Bag_08",
	collect = "Interface\\CURSOR\\Pickup",
	use = "Interface\\CURSOR\\Interact",
	reputation = "Interface\\Icons\\INV_Misc_Note_02",
}

local frame, scroll, content, subtitle, scrollbar, prevGuideButton, nextGuideButton, guideMenuButton, guideMenu
local pool, used = {}, 0

local function rxp()
	local ace = LibStub and LibStub("AceAddon-3.0", true)
	return ace and ace:GetAddon("RXPGuides", true)
end

local function kit() return api.themeKit end

-- the /qt window's text size and font (Settings Window > Text and font) apply here too
local function textScale()
	local k = (ns.db and tonumber(ns.db.configTextSize)) or 1
	return math.min(math.max(k, 0.8), 1.25) -- as the /qt slider (80-125 %)
end
local function chosenFont() return api.fontPath and api.fontPath() or nil end
-- a font string at its font object's size times the text size, in the chosen font
-- CONSTRAINT: the base size comes from the game's font object itself, never from the font string: after a SetFont,
-- the font string reports that size, so scaling it again on every redraw made the text grow without end.
local function styleText(fs, fontObject, extra)
	fs:SetFontObject(fontObject)
	local object = type(fontObject) == "string" and _G[fontObject] or fontObject
	local font, size, flags
	if object and object.GetFont then font, size, flags = object:GetFont() end
	if not size then font, size, flags = fs:GetFont() end
	if size then pcall(fs.SetFont, fs, chosenFont() or font, size * textScale() * (extra or 1), flags) end
end
local staticTexts = {} -- title, subtitle and hint: { fs, fontObject }
local applyStaticFonts -- below build, which uses it

local function done(id)
	return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
end
local function inLog(id) return C_QuestLog.GetLogIndexForQuestID(id) ~= nil end

local function guideName(guide)
	local addon = rxp()
	local ok, name = pcall(addon.GetGuideName, guide)
	return ok and name or guide.name or "this guide"
end

---------------------------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------------------------
-- The guide's accept and turn-in steps per quest: quest -> sorted step indices
local function guideIndex(steps)
	local at = {}
	for index, step in ipairs(steps) do
		for _, element in ipairs(type(step.elements) == "table" and step.elements or {}) do
			local id = tonumber(element.questId)
			if id and (element.tag == "accept" or element.tag == "turnin") then
				at[id] = at[id] or {}
				local list = at[id]
				if list[#list] ~= index then list[#list + 1] = index end
			end
		end
	end
	return at
end

-- the guide step in [from, to) that accepts or turns in this quest, if any
local function coveredAt(at, id, from, to)
	for _, index in ipairs(at[id] or {}) do
		if index >= from and index < to then return index end
	end
end

-- { { quest, name, step, plan = { ... }, covered = { [quest] = step } } }, or nil and a reason
---------------------------------------------------------------------------------------------------------------------
-- Which guide the journal shows: the current one, or another reached with < and > (only browsed here: RestedXP keeps
-- its own guide). > follows the guide's own "next" (RestedXP's #next: "Group\\Name" or "Name", several split by ";",
-- the first used); < goes back the way > came, else to a guide whose next is this one. Guides are read with
-- RestedXP's FetchGuide, which parses one without loading it.
---------------------------------------------------------------------------------------------------------------------
local stepGuide -- below
local viewGuide -- nil: the current guide
local history = {} -- guides left with >, for <

local function shownGuide()
	local addon = rxp()
	local guide = viewGuide or (addon and addon.currentGuide)
	if guide and guide.empty then return nil end
	return guide
end

local function fetch(group, name)
	local addon = rxp()
	if not (addon and addon.FetchGuide and name) then return nil end
	local ok, guide = pcall(addon.FetchGuide, addon, group, name)
	return ok and type(guide) == "table" and not guide.empty and guide or nil
end

-- "Group\\Name" or "Name" (in the guide's own group), the first of several
local function nextTarget(guide)
	local spec = type(guide.next) == "string" and guide.next:match("^%s*([^;]+)")
	if not spec then return nil end
	spec = spec:gsub("%s+$", "")
	local group, name = spec:match("^(.-)\\(.+)$")
	return group or guide.group, name or spec
end

local function sameGuide(a, b)
	return a and b and (a == b or (a.name == b.name and a.group == b.group))
end

-- The guides the journal browses: RestedXP Forever's "Dungeon Guide" and "Open World Guide" groups (your faction's),
-- each in level order and holding only the guides RestedXP would offer this character. < > step through the shown
-- guide's list and the Guides dropdown shows both, so neither depends on a guide's next-guide line resolving.
-- Matched by words in RestedXP's group names (not whole names), so a renamed group still lands in the right list:
-- Dungeon Guide = a Forever group with "Dungeon Guide"; Open World = a Forever guide group with neither "Dungeon" nor
-- "Quests" (RestedXP Forever Guide (A), or an "Open World" / "Speedrun" name). Class groups have no "Forever".
local SECTIONS = {
	{ label = "Dungeon Guide", match = function(name) return name:find("Forever", 1, true) and name:find("Dungeon Guide", 1, true) end },
	{ label = "Open World Guide", match = function(name)
		return name:find("Forever", 1, true) and name:find("Guide", 1, true) and not name:find("Dungeon", 1, true)
			and not name:find("Quests", 1, true)
	end },
}
local routes -- { { label, list = { { group, name } }, at = { ["group\\name"] = index } } }, rebuilt on a fresh render
local function routeKey(group, name) return tostring(group):gsub("^%*", "") .. "\\" .. tostring(name) end

local function levelsOf(name)
	local low, high = tostring(name):match("^%s*(%d+)%s*%-%s*(%d+)")
	return tonumber(low) or 999, tonumber(high) or 999
end

local function buildRoutes()
	local addon = rxp()
	local lists = addon and addon.guideList
	local out = {}
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	local side = faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
	for _, section in ipairs(SECTIONS) do
		local route = { label = section.label, list = {}, at = {} }
		for key, group in pairs(type(lists) == "table" and lists or {}) do
			local plain = type(key) == "string" and key:gsub("^%*", "") or ""
			local mark = plain:match("%((%a)%)%s*$")
			if section.match(plain) and not (side and mark and mark ~= side)
				and type(group) == "table" and type(group.names_) == "table" then
				for _, entry in ipairs(group.names_) do
					local name, g = type(entry) == "table" and entry.name, type(entry) == "table" and entry.group or plain
					local id = name and routeKey(g, name)
					if id and not route.at[id] then
						local raw = addon.GetGuideTable and addon.GetGuideTable(g, name)
						local ok, active = true, true
						if raw and addon.IsGuideActive then ok, active = pcall(addon.IsGuideActive, raw) end
						if not (raw and raw.chapter) and (not ok or active) then
							route.at[id] = true
							route.list[#route.list + 1] = { group = g, name = name, label = raw and raw.displayname or nil }
						end
					end
				end
			end
		end
		table.sort(route.list, function(a, b)
			local al, ah = levelsOf(a.name)
			local bl, bh = levelsOf(b.name)
			if al ~= bl then return al < bl end
			if ah ~= bh then return ah < bh end
			return a.name < b.name
		end)
		for i, entry in ipairs(route.list) do route.at[routeKey(entry.group, entry.name)] = i end
		out[#out + 1] = route
	end
	-- neither list found (RestedXP named its groups some other way): the current guide's own group, as before
	local empty = true
	for _, route in ipairs(out) do if #route.list > 0 then empty = false end end
	local current = addon and addon.currentGuide
	if empty and type(current) == "table" and type(lists) == "table" and current.group then
		local own = lists[current.groupdisplayname or current.group] or lists["*" .. tostring(current.group)]
		local route = { label = tostring(current.groupdisplayname or current.group):gsub("^%*", ""), list = {}, at = {} }
		for _, entry in ipairs(type(own) == "table" and type(own.names_) == "table" and own.names_ or {}) do
			if type(entry) == "table" and entry.name then
				local g = entry.group or current.group
				local raw = addon.GetGuideTable and addon.GetGuideTable(g, entry.name)
				route.list[#route.list + 1] = { group = g, name = entry.name, label = type(raw) == "table" and raw.displayname or nil }
			end
		end
		for i, entry in ipairs(route.list) do route.at[routeKey(entry.group, entry.name)] = i end
		if #route.list > 0 then out = { route } end
	end
	return out
end

local function getRoutes(fresh)
	if fresh or not routes then routes = buildRoutes() end
	return routes
end

-- the shown guide's place: its route and index there (nil when it is in neither group)
local function routeOf(guide)
	if not guide then return nil end
	local id = routeKey(guide.group, guide.name)
	for _, route in ipairs(getRoutes()) do
		local i = route.at[id]
		if i then return route, i end
	end
	-- a guide RestedXP lists under another group name: match on the name alone
	for _, route in ipairs(getRoutes()) do
		for i, entry in ipairs(route.list) do
			if entry.name == guide.name then return route, i end
		end
	end
end

local function routeStep(guide, delta)
	local route, i = routeOf(guide)
	local entry = route and route.list[i + delta]
	return entry and fetch(entry.group, entry.name) or nil, route ~= nil
end

local function nextGuide(guide)
	local target, routed = routeStep(guide, 1)
	if routed then return target end
	local group, name = nextTarget(guide)
	return name and fetch(group, name) or nil
end

local function previousGuide(guide)
	local target, routed = routeStep(guide, -1)
	if routed then return target end
	local last = history[#history]
	if last then return last end
	local addon = rxp()
	for key, other in pairs(addon and addon.guides or {}) do
		if type(key) == "string" and type(other) == "table" and type(other.next) == "string" and not sameGuide(other, guide) then
			local group, name = nextTarget(other)
			if name == guide.name and (group == guide.group or not group) then return fetch(other.group, other.name) end
		end
	end
end

local render -- below
-- < (delta -1) or > (+1): show the guide before / after the shown one; back at the current guide, the view resets
function stepGuide(delta)
	local shown = shownGuide()
	if not shown then return end
	local target
	if delta > 0 then
		target = nextGuide(shown)
		if not target then return end
		history[#history + 1] = shown
	else
		target = previousGuide(shown)
		if not target then return end
		if history[#history] == target then history[#history] = nil end
	end
	local addon = rxp()
	if sameGuide(target, addon and addon.currentGuide) then
		viewGuide = nil
		wipe(history)
	else
		viewGuide = target
	end
	if scroll then scroll:SetVerticalScroll(0) end
	render()
end

-- Does this guide come after your current RestedXP guide (later, at a higher level)? By RestedXP's guide menu order
-- when both are in one group, else along the next-guide chain from the current guide (raw guide data, not parsed).
local LATER_ALPHA = 0.6
local function isLater(guide)
	local addon = rxp()
	local current = addon and addon.currentGuide
	if not (guide and current) or sameGuide(guide, current) then return false end
	local route, here = routeOf(current)
	local other, there = routeOf(guide)
	if route and route == other then return there > here end
	local g, seen = current, 0
	while g and seen < 80 do
		seen = seen + 1
		local group, name = nextTarget(g)
		if not name then return false end
		if name == guide.name then return true end
		g = addon.GetGuideTable and addon.GetGuideTable(group, name) or nil
	end
	return false
end

-- the dropdown's choice: show that guide (back at the current one, the view resets)
local function chooseGuide(group, name)
	local addon = rxp()
	local current = addon and addon.currentGuide
	if current and current.name == name and (current.group == group or not group) then
		viewGuide = nil
	else
		local target = fetch(group, name)
		if not target then return false end
		viewGuide = target
	end
	wipe(history)
	if scroll then scroll:SetVerticalScroll(0) end
	render()
	return true
end

-- A later guide: which zone guide on the way to it (from your place in the current guide, through each guide between)
-- hands in a prerequisite it is missing. Hand-ins per guide are read once (weak keys: a guide RestedXP drops goes).
local turninsOf = setmetatable({}, { __mode = "k" })
local function turnins(steps)
	local known = turninsOf[steps]
	if known then return known end
	known = {}
	for index, step in ipairs(steps) do
		for _, element in ipairs(type(step.elements) == "table" and step.elements or {}) do
			local id = tonumber(element.questId)
			if id and element.tag == "turnin" and not known[id] then known[id] = index end
			for _, other in ipairs(element.tag == "turnin" and type(element.ids) == "table" and element.ids or {}) do
				other = tonumber(other)
				if other and not known[other] then known[other] = index end
			end
		end
	end
	turninsOf[steps] = known
	return known
end
-- { { name, turnins, from } } for the guides from the current one (at your step) up to the shown later guide
local function guidesBefore(shown)
	local addon = rxp()
	local current = addon and addon.currentGuide
	if not (shown and current) or sameGuide(shown, current) then return nil end
	local route, here = routeOf(current)
	local other, there = routeOf(shown)
	if not (route and route == other and there > here) then return nil end
	local okProgress, p = pcall(addon.GetGuideProgress)
	local out = {}
	for i = here, there - 1 do
		local entry = route.list[i]
		local g = i == here and current or fetch(entry.group, entry.name)
		if g and type(g.steps) == "table" then
			out[#out + 1] = { name = guideName(g), turnins = turnins(g.steps), from = i == here and (okProgress and tonumber(p) or 1) or 1 }
		end
	end
	return out
end
-- the guide before the shown one that hands in this quest (the first on the way), or nil
local function doneOnTheWay(before, id)
	for _, g in ipairs(before or {}) do
		local at = g.turnins[id]
		if at and at >= g.from then return g.name, at end
	end
end

local function collect()
	if not (api.prereqDataReady and api.prereqDataReady()) then
		return nil, "Questie is needed for this window: it knows each quest's prerequisites. Install or enable Questie and /reload."
	end
	local addon = rxp()
	local guide = shownGuide()
	if guide and not guide.steps then guide = fetch(guide.group, guide.name) end
	local steps = guide and guide.steps
	if type(steps) ~= "table" then return nil, "No RestedXP guide is loaded." end
	-- the current guide from your step; another guide from its start
	local progress = 1
	if not viewGuide or sameGuide(viewGuide, addon.currentGuide) then
		local okProgress, p = pcall(addon.GetGuideProgress)
		progress = okProgress and tonumber(p) or 1
	end
	local at = guideIndex(steps)
	local list, checked, seen = {}, 0, {}
	local before -- the guides on the way to a later guide (worked out once, when needed)
	for index = progress, #steps do
		for _, element in ipairs(type(steps[index].elements) == "table" and steps[index].elements or {}) do
			local id = tonumber(element.questId)
			if element.tag == "accept" and id and not seen[id] and checked < MAX_QUESTS then
				seen[id] = true
				checked = checked + 1
				if not done(id) and not inLog(id) then
					local plan, direct = api.prereqPlan(id)
					if plan and #plan > 0 then
						-- blocked when a direct prerequisite is not taken care of by the guide before this step
						local blocked, covered = false, {}
						for _, entry in ipairs(plan) do
							covered[entry.quest] = coveredAt(at, entry.quest, progress, index)
						end
						for pre in pairs(direct) do
							if not covered[pre] then blocked = true end
						end
						if blocked then
							-- a later guide: the guides before it that hand in its missing prerequisites
							before = before == nil and (guidesBefore(guide) or false) or before
							local doneBy, missing = {}, 0
							for _, pre in ipairs(plan) do
								if not covered[pre.quest] then
									local by, at = doneOnTheWay(before or nil, pre.quest)
									if by then doneBy[pre.quest] = { guide = by, step = at } else missing = missing + 1 end
								end
							end
							list[#list + 1] = { quest = id, name = api.prereqQuestName(id), step = index, plan = plan,
								covered = covered, doneBy = before and doneBy or nil, notOnTheWay = before and missing or nil }
						end
					end
				end
			end
		end
	end
	return list, nil, guideName(guide), progress
end

---------------------------------------------------------------------------------------------------------------------
-- Waypoints (a click on a step with a place)
---------------------------------------------------------------------------------------------------------------------
local function say(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RXP ForeverTracker|r " .. text)
end

local function mapName(map)
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name or ("map " .. map)
end

local function setWaypoint(map, x, y)
	if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) and UiMapPoint then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		say(("waypoint set: %s %.1f, %.1f"):format(mapName(map), x * 100, y * 100))
	else
		say(("go to %s %.1f, %.1f (the game cannot pin that map)"):format(mapName(map), x * 100, y * 100))
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Drawing: pooled line buttons in the scroll child
---------------------------------------------------------------------------------------------------------------------
local STYLE = {
	quest = { "GameFontNormalLarge", { 1, 0.82, 0 } },
	info = { "GameFontHighlightSmall", nil },
	prereq = { "GameFontNormal", { 0.941, 0.902, 0.824 } },
	step = { "GameFontHighlight", { 0.847, 0.812, 0.749 } },
	note = { "GameFontHighlight", { 0.69, 0.663, 0.612 } },
}

local function lineEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(mapName(self.map), 1, 0.82, 0)
	GameTooltip:AddLine(("Click: waypoint to %.1f, %.1f."):format(self.x * 100, self.y * 100), 1, 1, 1, true)
	GameTooltip:Show()
end

local function acquire()
	used = used + 1
	local line = pool[used]
	if not line then
		line = CreateFrame("Button", nil, content)
		line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		line.text:SetJustifyH("LEFT")
		line.text:SetJustifyV("TOP")
		line.icon = line:CreateTexture(nil, "ARTWORK")
		line.icon:SetSize(ICON_SIZE, ICON_SIZE)
		line.icon:SetPoint("TOPLEFT", 0, 1)
		line.highlight = line:CreateTexture(nil, "HIGHLIGHT")
		line.highlight:SetAllPoints()
		line.highlight:SetColorTexture(1, 0.9, 0.6, 0.08)
		line.pin = line:CreateTexture(nil, "OVERLAY")
		line.pin:SetTexture("Interface\\Minimap\\Tracking\\None")
		line.pin:SetSize(14, 14)
		line.pin:SetPoint("TOPRIGHT", 0, 0)
		line:SetScript("OnClick", function(self) if self.map then setWaypoint(self.map, self.x, self.y) end end)
		line:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
		pool[used] = line
	end
	return line
end

local y
local function addLine(style, text, indent, map, px, py, gap, icon)
	local line = acquire()
	local font, color = STYLE[style][1], STYLE[style][2]
	styleText(line.text, font)
	if color then line.text:SetTextColor(color[1], color[2], color[3]) else line.text:SetTextColor(0.6, 0.573, 0.522) end
	local iconSize = math.floor(ICON_SIZE * textScale() + 0.5)
	line.icon:SetShown(icon ~= nil)
	line.icon:SetSize(iconSize, iconSize)
	if icon then line.icon:SetTexture(icon) end
	local iconRoom = icon and iconSize + 4 or 0
	line.text:ClearAllPoints()
	line.text:SetPoint("TOPLEFT", iconRoom, 0)
	local width = content:GetWidth() - indent - iconRoom - (map and 18 or 0)
	line.text:SetWidth(math.max(width, 50))
	line.text:SetText(text)
	local height = math.max(math.ceil(line.text:GetStringHeight()), icon and iconSize or 0) + 2
	y = y - (gap or 2)
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", content, "TOPLEFT", indent, y)
	line.top = y
	line:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	line:SetHeight(height)
	line.map, line.x, line.y = map, px, py
	local clickable = map and px and py and true or false
	line:EnableMouse(clickable)
	line.highlight:SetShown(clickable)
	line.pin:SetShown(clickable)
	line:SetScript("OnEnter", clickable and lineEnter or nil)
	line:Show()
	y = y - height
	return line
end

-- Reward item icons after a line's text (on the same line when they fit, else on a row below): the game's item
-- tooltip on hover.
local iconPool, iconsUsed = {}, 0
local function itemEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) else GameTooltip:SetHyperlink("item:" .. self.item) end
	GameTooltip:Show()
end
local function itemIcon(item)
	local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)
	if not icon and GetItemIcon then icon = GetItemIcon(item) end
	return icon or 134400
end
local function addItemIcons(line, items, indent)
	if #items == 0 then return end
	local size = math.floor(18 * textScale() + 0.5)
	local gap = 3
	local needed = #items * (size + gap)
	local textW = math.ceil(line.text:GetStringWidth() or 0)
	local oneLine = (line.text:GetStringHeight() or 0) < size * 1.6
	local x, top
	if oneLine and indent + textW + 8 + needed <= content:GetWidth() then
		x, top = indent + textW + 8, line.top -- beside the text
		top = top - math.max((line:GetHeight() - size) / 2, 0)
	else
		y = y - 2
		x, top = indent, y
		y = y - size
	end
	for index, item in ipairs(items) do
		iconsUsed = iconsUsed + 1
		local b = iconPool[iconsUsed]
		if not b then
			b = CreateFrame("Button", nil, content)
			b.tex = b:CreateTexture(nil, "ARTWORK")
			b.tex:SetAllPoints()
			b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			b:SetScript("OnEnter", itemEnter)
			b:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
			iconPool[iconsUsed] = b
		end
		b.item = item
		b.tex:SetTexture(itemIcon(item))
		b:SetSize(size, size)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", content, "TOPLEFT", x + (index - 1) * (size + gap), top)
		b:Show()
	end
end

-- Vendor value of an item (the game's item data; nil until the client has loaded it, which is then requested)
local waitingItems = false
local function sellPrice(item)
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if not getInfo then return 0 end
	local name, _, _, _, _, _, _, _, _, _, price = getInfo(item)
	if not name then
		waitingItems = true
		if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
		return nil
	end
	return tonumber(price) or 0
end

-- The reward items of these quests (each once) and the vendor money they add: per quest the highest vendor value among
-- its reward items (the option worth most when sold)
local function rewardItemsOf(ids)
	local items, seen, extra = {}, {}, 0
	for _, id in ipairs(ids) do
		local list = api.questRewardItems and api.questRewardItems(id)
		local best = 0
		for _, item in ipairs(list or {}) do
			if not seen[item] then seen[item] = true; items[#items + 1] = item end
			local price = sellPrice(item)
			if price and price > best then best = price end
		end
		extra = extra + best
	end
	return items, extra
end

-- Whether < and > lead anywhere, and whether the Guides list has entries. A guide in the Dungeon / Open World lists
-- answers from its place there (no parsing); any other guide by RestedXP's next chain, worked out once per guide
-- until the next fresh render.
local neighbours = {}
local function guideKey(guide) return guide and (tostring(guide.group) .. "\\" .. tostring(guide.name)) or "" end
local function neighboursOf(guide)
	local menu = false
	for _, route in ipairs(getRoutes()) do if #route.list > 0 then menu = true end end
	local route, i = routeOf(guide)
	if route then return { prev = i > 1, nxt = i < #route.list, menu = menu } end
	local key = guideKey(guide)
	local known = neighbours[key]
	if not known then
		known = { prev = guide ~= nil and previousGuide(guide) ~= nil, nxt = guide ~= nil and nextGuide(guide) ~= nil }
		neighbours[key] = known
	end
	return { prev = known.prev, nxt = known.nxt, menu = menu }
end

-- The list (every accept step's prerequisite plan) for one guide at one step. Redraws for item data, fonts or a new
-- window size use it again; opening, Refresh, another guide or a quest accepted / turned in build it anew.
local cached -- { key, list, reason, guide, progress }
local function cachedCollect(fresh)
	local shown = shownGuide()
	local progress = 1
	local addon = rxp()
	if shown and (not viewGuide or sameGuide(viewGuide, addon and addon.currentGuide)) then
		local ok, p = pcall(addon.GetGuideProgress)
		progress = ok and tonumber(p) or 1
	end
	local key = guideKey(shown) .. "#" .. progress .. (api.prereqDataReady and api.prereqDataReady() and "" or "#noquestie")
	if fresh or not cached or cached.key ~= key then
		local list, reason, guide, p = collect()
		cached = { key = key, list = list, reason = reason, guide = guide, progress = p }
	end
	return cached.list, cached.reason, cached.guide, cached.progress
end

-- fresh: build the list again (otherwise the cached one for the same guide and step is drawn)
function render(fresh)
	if not frame then return end
	for index = 1, used do pool[index]:Hide() end
	used = 0
	for index = 1, iconsUsed do iconPool[index]:Hide() end
	iconsUsed = 0
	waitingItems = false
	y = 0
	content:SetWidth(math.max(scroll:GetWidth() - 4, 100))
	if fresh then getRoutes(true); wipe(neighbours) end
	local list, reason, guide, progress = cachedCollect(fresh)
	-- < > : the guide before / after this one in its Dungeon / Open World list
	if prevGuideButton then
		local known = neighboursOf(shownGuide())
		prevGuideButton:SetEnabled(known.prev)
		nextGuideButton:SetEnabled(known.nxt)
		guideMenuButton:SetEnabled(known.menu)
	end
	local later = viewGuide ~= nil and isLater(viewGuide)
	if not list then
		subtitle:SetText("")
		addLine("note", reason, 0)
	else
		local addon = rxp()
		local current = not viewGuide or sameGuide(viewGuide, addon and addon.currentGuide)
		later = not current and later
		subtitle:SetText(guide .. (current and "  |cff9a9285(current guide)|r"
			or later and "  |cff9a9285(later guide, higher level)|r" or "  |cff9a9285(previous guide)|r"))
		if #list == 0 then
			addLine("note", "Every quest still ahead in this guide has its prerequisites done, or the guide does them first.", 0)
		end
		for qIndex, entry in ipairs(list) do
			-- what skipping it costs: this quest and every prerequisite in its plan
			local ids = { entry.quest }
			for _, pre in ipairs(entry.plan) do ids[#ids + 1] = pre.quest end
			local items, vendorMoney = rewardItemsOf(ids)
			local rewards = ""
			if api.questRewardTotals and api.formatRewardTotals then
				local xp, money = api.questRewardTotals(ids)
				rewards = api.formatRewardTotals(xp, money + vendorMoney, true) -- a space before each coin icon
			end
			local heading = addLine("quest", entry.name .. (rewards ~= "" and ("   " .. rewards) or ""), 0, nil, nil, nil,
				qIndex > 1 and 16 or 0)
			addItemIcons(heading, items, 0)
			-- a later guide: the zone guide(s) on the way that hand in its prerequisites
			local wants = ("Guide step %d wants this quest."):format(entry.step)
			if entry.doneBy then
				local names, seenName = {}, {}
				for _, pre in ipairs(entry.plan) do
					local by = entry.doneBy[pre.quest]
					if by and not seenName[by.guide] then seenName[by.guide] = true; names[#names + 1] = by.guide end
				end
				if #names > 0 and entry.notOnTheWay == 0 then
					wants = wants .. " Its prerequisites are done in |cffffd100" .. table.concat(names, "|r, |cffffd100") .. "|r on the way."
				elseif #names > 0 then
					wants = wants .. " Some prerequisites are done in |cffffd100" .. table.concat(names, "|r, |cffffd100")
						.. "|r on the way; the rest no guide before it does. Do those first:"
				else
					wants = wants .. " No guide before it does its prerequisites. Do these first:"
				end
			else
				wants = wants .. " Do these first:"
			end
			addLine("info", wants, INDENT)
			if rewards ~= "" or #items > 0 then
				addLine("info", "Skipping it and these misses the experience, gold and items shown (gold includes the best-selling reward of each quest).", INDENT)
			end
			for pIndex, pre in ipairs(entry.plan) do
				local tags = {}
				if pre.inLog then tags[#tags + 1] = "in your quest log" end
				if entry.covered[pre.quest] then tags[#tags + 1] = "the guide does it at step " .. entry.covered[pre.quest] end
				local by = entry.doneBy and entry.doneBy[pre.quest]
				if by then tags[#tags + 1] = ("done in %s, step %d"):format(by.guide, by.step) end
				if pre.alternatives then
					tags[#tags + 1] = pre.alternatives == 1 and "or 1 other quest" or ("or one of " .. pre.alternatives .. " other quests")
				end
				local label = ("%d. %s"):format(pIndex, pre.name) .. (#tags > 0 and ("  |cff9a9285(" .. table.concat(tags, ", ") .. ")|r") or "")
				addLine("prereq", label, INDENT * 2, nil, nil, nil, 8)
				for _, step in ipairs(pre.steps) do
					addLine("step", step.text, INDENT * 3, step.map, step.x, step.y, nil, STEP_ICONS[step.kind])
				end
			end
		end
	end
	content:SetHeight(math.max(-y + 8, 1))
	if subtitle.fitWidth then subtitle.fitWidth() end
	-- a later guide (higher level) is slightly greyed out, still readable and clickable
	content:SetAlpha(later and LATER_ALPHA or 1)
	-- no scrollbar when everything fits (the template re-checks its range a frame later)
	if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
	if scrollbar then
		scrollbar:SetShown((scroll:GetVerticalScrollRange() or 0) > 0.5)
		C_Timer.After(0, function()
			if scrollbar and scroll then scrollbar:SetShown((scroll:GetVerticalScrollRange() or 0) > 0.5) end
		end)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Window (the /qt shell: dark body, bronze edge, title bar, panel, red buttons)
---------------------------------------------------------------------------------------------------------------------
local function build()
	local k = kit()
	local C = k.C
	local f = k.create("Frame", "RXPForeverTrackerPrereqs", UIParent)
	frame = f
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
	elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H) end
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "RXPForeverTrackerPrereqs")

	local body = k.solid(f, "BACKGROUND", C.window, 0.98, -7)
	body:SetAllPoints()
	k.border(f, C.edge, 2, "BORDER")
	local inner = CreateFrame("Frame", nil, f)
	inner:SetPoint("TOPLEFT", 2, -2)
	inner:SetPoint("BOTTOMRIGHT", -2, 2)
	k.border(inner, { 0, 0, 0 }, 1, "BORDER")

	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 2, -2)
	bar:SetPoint("TOPRIGHT", -2, -2)
	bar:SetHeight(32)
	local barBg = bar:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints()
	k.gradient(barBg, C.titleTop, C.titleBottom)
	local barLine = k.solid(bar, "BORDER", C.titleLine)
	barLine:SetPoint("BOTTOMLEFT")
	barLine:SetPoint("BOTTOMRIGHT")
	barLine:SetHeight(1)
	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", PAD, 0) -- left: the opacity slider sits on the right, beside the close button
	title:SetText("Prerequisite Journal")
	staticTexts[#staticTexts + 1] = { title, "GameFontNormal" }
	local close = k.create("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(28, 28)
	close:SetPoint("TOPRIGHT", -3, -4)
	close:SetFrameLevel(bar:GetFrameLevel() + 5)
	close:HookScript("OnClick", function() f:Hide() end)

	-- the journal's own opacity (10-100 %), just left of the close button; only this window
	do
		local MIN_ALPHA = 0.1
		local function journalAlpha()
			local v = tonumber(ns.db and ns.db.journalAlpha) or 1
			return math.min(math.max(v, MIN_ALPHA), 1)
		end
		local holder = CreateFrame("Frame", nil, bar)
		holder:SetPoint("RIGHT", close, "LEFT", -6, 0)
		holder:SetHeight(20)
		holder:SetFrameLevel(bar:GetFrameLevel() + 4)
		local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetTextColor(C.subLabel[1], C.subLabel[2], C.subLabel[3])
		label:SetText("Opacity")
		label:SetPoint("LEFT", holder, "LEFT", 0, 0)
		staticTexts[#staticTexts + 1] = { label, "GameFontHighlightSmall" }
		local slider = CreateFrame("Slider", nil, holder)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(MIN_ALPHA * 100, 100)
		slider:SetValueStep(5)
		if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
		slider:SetSize(90, 18)
		local trackBg = slider:CreateTexture(nil, "BACKGROUND")
		trackBg:SetPoint("LEFT"); trackBg:SetPoint("RIGHT"); trackBg:SetHeight(6)
		trackBg:SetColorTexture(C.trackEdge[1], C.trackEdge[2], C.trackEdge[3], 1)
		local track = slider:CreateTexture(nil, "BORDER")
		track:SetPoint("LEFT", 1, 0); track:SetPoint("RIGHT", -1, 0); track:SetHeight(4)
		track:SetColorTexture(C.track[1], C.track[2], C.track[3], 1)
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetSize(11, 11)
		thumb:SetColorTexture(C.thumb[1], C.thumb[2], C.thumb[3], 1)
		if thumb.SetRotation then pcall(thumb.SetRotation, thumb, math.rad(45)) end
		slider:SetThumbTexture(thumb)
		local value = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		value:SetTextColor(C.value[1], C.value[2], C.value[3])
		value:SetJustifyH("LEFT")
		staticTexts[#staticTexts + 1] = { value, "GameFontHighlightSmall" }
		local function arrange()
			local labelW = math.ceil(label:GetStringWidth() or 40)
			slider:ClearAllPoints()
			slider:SetPoint("LEFT", holder, "LEFT", labelW + 6, 0)
			value:ClearAllPoints()
			value:SetPoint("LEFT", slider, "RIGHT", 6, 0)
			value:SetWidth(math.ceil(36 * textScale()))
			holder:SetWidth(labelW + 6 + slider:GetWidth() + 6 + value:GetWidth())
		end
		local loading = false
		slider:SetScript("OnValueChanged", function(_, v)
			v = math.floor(v / 5 + 0.5) * 5
			value:SetText(v .. "%")
			f:SetAlpha(v / 100)
			if not loading and ns.db then ns.db.journalAlpha = v / 100 end
		end)
		slider:EnableMouseWheel(true)
		slider:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * 5) end)
		loading = true
		slider:SetValue(math.floor(journalAlpha() * 100 / 5 + 0.5) * 5)
		loading = false
		f:SetAlpha(journalAlpha())
		f.arrangeOpacity = arrange
		arrange()
	end

	subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	subtitle:SetTextColor(C.label[1], C.label[2], C.label[3])
	staticTexts[#staticTexts + 1] = { subtitle, "GameFontHighlight" }
	-- the guide's name on the left and < > Guides fixed at the right, centred on one line
	local HEADER_Y = -(32 + 21)
	subtitle:SetPoint("LEFT", f, "TOPLEFT", PAD + 2, HEADER_Y)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetWordWrap(false)
	-- < > at the right, before Guides: browse the previous / next guide's missing prerequisites
	local function guideArrow(page, delta, tip)
		local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-"
		local b = CreateFrame("Button", nil, f)
		b:SetSize(22, 22)
		b:SetNormalTexture(base .. "Up")
		b:SetPushedTexture(base .. "Down")
		b:SetDisabledTexture(base .. "Disabled")
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		b:SetScript("OnClick", function() stepGuide(delta) end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(tip, 1, 0.82, 0)
			GameTooltip:AddLine("Shows that guide's missing prerequisites here; your RestedXP guide stays as it is.", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
		return b
	end
	prevGuideButton = guideArrow("Prev", -1, "Previous guide")
	nextGuideButton = guideArrow("Next", 1, "Next guide")
	-- placed once Guides exists (below): [<][>] [Guides] against the window's right edge

	-- "Guides": a list of the group's guides (RestedXP's guide menu order) to pick the one shown
	local MENU_ROWS, ROW_H = 14, 20
	guideMenu = CreateFrame("Frame", nil, UIParent)
	guideMenu:SetFrameStrata("FULLSCREEN_DIALOG")
	guideMenu:SetClampedToScreen(true)
	guideMenu:EnableMouse(true)
	guideMenu:Hide()
	local menuBg = k.solid(guideMenu, "BACKGROUND", C.list, 0.97)
	menuBg:SetAllPoints()
	k.border(guideMenu, C.ctrlEdge)
	local menuScroll = CreateFrame("ScrollFrame", nil, guideMenu)
	menuScroll:SetPoint("TOPLEFT", 1, -2)
	menuScroll:SetPoint("BOTTOMRIGHT", -1, 2)
	local menuChild = CreateFrame("Frame", nil, menuScroll)
	menuChild:SetSize(1, 1)
	menuScroll:SetScrollChild(menuChild)
	-- a thin scrollbar on the right, shown when the list is longer than the box: drag its thumb, or use the wheel
	local BAR_W = 6
	local menuBar = CreateFrame("Frame", nil, guideMenu)
	menuBar:SetPoint("TOPRIGHT", -2, -3)
	menuBar:SetPoint("BOTTOMRIGHT", -2, 3)
	menuBar:SetWidth(BAR_W)
	menuBar:SetFrameLevel(menuScroll:GetFrameLevel() + 5)
	local barTrack = k.solid(menuBar, "BACKGROUND", C.track, 1)
	barTrack:SetAllPoints()
	local menuThumb = CreateFrame("Frame", nil, menuBar)
	menuThumb:SetWidth(BAR_W)
	menuThumb:EnableMouse(true)
	local thumbTex = k.solid(menuThumb, "ARTWORK", C.thumb, 1)
	thumbTex:SetAllPoints()
	local function contentHeight() return menuChild:GetHeight() or 0 end
	local function viewHeight() return menuScroll:GetHeight() or 0 end
	local function updateMenuBar()
		local childH, viewH = contentHeight(), viewHeight()
		local range = math.max(childH - viewH, 0)
		if range <= 0.5 or viewH <= 0 then menuBar:Hide() return end
		menuBar:Show()
		local trackH = menuBar:GetHeight() or viewH
		local thumbH = math.max(16, trackH * viewH / childH)
		menuThumb:SetHeight(thumbH)
		menuThumb:ClearAllPoints()
		menuThumb:SetPoint("TOP", menuBar, "TOP", 0, -((menuScroll:GetVerticalScroll() or 0) / range) * (trackH - thumbH))
	end
	local function scrollTo(value)
		local range = math.max(contentHeight() - viewHeight(), 0)
		menuScroll:SetVerticalScroll(math.min(math.max(value, 0), range))
		updateMenuBar()
	end
	menuThumb:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local scale = self:GetEffectiveScale()
		local startY, startScroll = select(2, GetCursorPosition()) / scale, menuScroll:GetVerticalScroll() or 0
		self:SetScript("OnUpdate", function()
			if not IsMouseButtonDown("LeftButton") then self:SetScript("OnUpdate", nil) return end
			local trackH, thumbH = menuBar:GetHeight() or 1, self:GetHeight() or 1
			local range = math.max(contentHeight() - viewHeight(), 0)
			local moved = startY - select(2, GetCursorPosition()) / scale
			scrollTo(startScroll + moved * range / math.max(trackH - thumbH, 1))
		end)
	end)
	menuThumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	menuThumb:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
	guideMenu:EnableMouseWheel(true)
	guideMenu:SetScript("OnMouseWheel", function(_, delta)
		scrollTo((menuScroll:GetVerticalScroll() or 0) - delta * ROW_H * 3)
	end)
	local menuRows = {}
	guideMenu.open = function()
		local shown = shownGuide()
		local addon = rxp()
		local current = addon and addon.currentGuide
		-- only the list your current guide is in (Open World Guide or Dungeon Guide), under its heading; the shown
		-- guide's list when your current guide is in neither, and both only when neither guide is in one
		local list = {}
		local currentRoute, currentAt = routeOf(current)
		local only = currentRoute or routeOf(shown)
		for _, route in ipairs(getRoutes()) do
			if #route.list > 0 and (not only or route == only) then
				list[#list + 1] = { header = route.label }
				local hidePrevious = ns.db and ns.db.journalHidePrevious
				for i, entry in ipairs(route.list) do
					-- how far past your current guide: 1-2 yellow, 3-4 orange, 5+ red
					local ahead = route == currentRoute and i - currentAt or 0
					-- the switch left of <: guides before your current one hidden
					if not (hidePrevious and route == currentRoute and ahead < 0) then
						list[#list + 1] = { group = entry.group, name = entry.name, label = entry.label, ahead = ahead }
					end
				end
			end
		end
		local shownId = shown and routeKey(shown.group, shown.name)
		local currentId = current and routeKey(current.group, current.name)
		local rowH = math.floor(ROW_H * textScale() + 0.5)
		local width = math.max(guideMenuButton:GetWidth() + 160, 260)
		local top, at = 0, nil
		for i, entry in ipairs(list) do
			local row = menuRows[i]
			if not row then
				row = CreateFrame("Button", nil, menuChild)
				row.sel = row:CreateTexture(nil, "BACKGROUND")
				row.sel:SetAllPoints()
				row.sel:SetColorTexture(1, 0.82, 0, 0.16)
				row.hl = row:CreateTexture(nil, "HIGHLIGHT")
				row.hl:SetAllPoints()
				row.hl:SetColorTexture(1, 0.9, 0.6, 0.1)
				row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				row.text:SetPoint("LEFT", 10, 0)
				row.text:SetPoint("RIGHT", -10, 0)
				row.text:SetJustifyH("LEFT")
				row.text:SetWordWrap(false)
				menuRows[i] = row
			end
			if entry.header then
				styleText(row.text, "GameFontNormal")
				row.text:SetText(entry.header)
				row.text:SetTextColor(1, 0.82, 0)
				row.text:SetPoint("LEFT", 6, 0)
				row.sel:Hide()
				row.hl:Hide()
				row:SetScript("OnClick", nil)
				row:EnableMouse(false)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", menuChild, "TOPLEFT", 0, -top)
				row:SetSize(width - 2, rowH)
				row:Show()
				top = top + rowH
			else
			row:EnableMouse(true)
			row.hl:Show()
			row.text:SetPoint("LEFT", 16, 0)
			styleText(row.text, "GameFontHighlight")
			local id = routeKey(entry.group, entry.name)
			local isShown = id == shownId
			local isCurrent = id == currentId
			local ahead = entry.ahead or 0
			-- the guide's display name, as RestedXP's own menu shows it (some guides have an internal name such as
			-- "41-400_41-41 Swamp of Sorrows" for "41-41 Swamp of Sorrows")
			row.text:SetText(tostring(entry.label or entry.name) .. (isCurrent and "  |cff9a9285(current)|r" or ""))
			local tc = ahead >= 5 and { 1, 0.3, 0.25 } or ahead >= 3 and { 1, 0.55, 0.15 } or ahead >= 1 and { 1, 0.88, 0.2 }
				or isShown and { 1, 1, 1 } or C.listText
			row.text:SetTextColor(tc[1], tc[2], tc[3])
			row.sel:SetShown(isShown and true or false)
			row:SetScript("OnClick", function()
				guideMenu:Hide()
				if not chooseGuide(entry.group, entry.name) then say("that guide could not be read.") end
			end)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", menuChild, "TOPLEFT", 0, -top)
			row:SetSize(width - 2, rowH)
			row:Show()
			if isShown then at = top end
			top = top + rowH
			end
		end
		for i = #list + 1, #menuRows do menuRows[i]:Hide() end
		if #list == 0 then return end
		local height = math.min(top, MENU_ROWS * rowH) + 4
		menuChild:SetSize(width, top)
		guideMenu:SetSize(width, height)
		guideMenu:ClearAllPoints()
		guideMenu:SetPoint("TOPRIGHT", guideMenuButton, "BOTTOMRIGHT", 0, -2)
		guideMenu:Show()
		if menuScroll.UpdateScrollChildRect then menuScroll:UpdateScrollChildRect() end
		-- open on the guide shown now
		local range = math.max(top - (height - 4), 0)
		menuScroll:SetVerticalScroll(at and math.min(math.max(at - (height - 4) / 2, 0), range) or 0)
		updateMenuBar()
		C_Timer.After(0, updateMenuBar) -- once the box has its new size
	end
	guideMenuButton = k.makeButton(f, "Guides", 90, function()
		if guideMenu:IsShown() then guideMenu:Hide() else guideMenu.open() end
	end)
	guideMenuButton:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, HEADER_Y)
	nextGuideButton:SetPoint("RIGHT", guideMenuButton, "LEFT", -6, 0)
	prevGuideButton:SetPoint("RIGHT", nextGuideButton, "LEFT", 0, 0)
	-- left of <: show or hide the guides before your current one in the Guides list
	local previousSwitch
	if k.makeSwitch then
		previousSwitch = k.makeSwitch(f, 16, function() return not (ns.db and ns.db.journalHidePrevious) end, function(on)
			if ns.db then ns.db.journalHidePrevious = not on end
			if guideMenu:IsShown() then guideMenu.open() end
		end)
		previousSwitch:SetPoint("RIGHT", prevGuideButton, "LEFT", -6, 0)
		previousSwitch:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText("Previous guides", 1, 0.82, 0)
			GameTooltip:AddLine("On: the Guides list shows the guides before your current one too. Off: only your current guide and those after it.", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		previousSwitch:HookScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
	end
	f:HookScript("OnHide", function() guideMenu:Hide() end)
	-- the name stops short of the buttons (cut with "..." when it is longer)
	subtitle.fitWidth = function()
		subtitle:SetWidth(0)
		local room = f:GetWidth() - 2 * PAD - 2 - 12 - prevGuideButton:GetWidth() - nextGuideButton:GetWidth() - 6
			- (guideMenuButton and guideMenuButton:GetWidth() or 0) - (previousSwitch and previousSwitch:GetWidth() + 6 or 0)
		subtitle:SetWidth(math.max(math.min(math.ceil(subtitle:GetStringWidth() or 0) + 2, room), 40))
	end

	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(32 + 36))
	panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 50)
	local panelBg = k.solid(panel, "BACKGROUND", C.panel)
	panelBg:SetAllPoints()
	k.border(panel, C.panelEdge)

	local native
	scroll, native = k.create("ScrollFrame", "RXPForeverTrackerPrereqsScroll", panel, "UIPanelScrollFrameTemplate")
	if native then
		scrollbar = scroll.ScrollBar or _G.RXPForeverTrackerPrereqsScrollScrollBar
		scroll.scrollBarHideable = true -- the template hides its bar itself when the range is zero
		if scrollbar and scrollbar.HookScript then
			scrollbar:HookScript("OnShow", function(self)
				if (scroll:GetVerticalScrollRange() or 0) <= 0.5 then self:Hide() end
			end)
		end
	end
	scroll:SetPoint("TOPLEFT", 12, -12)
	scroll:SetPoint("BOTTOMRIGHT", -30, 12)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - delta * 48, 0), range))
	end)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - 2 * PAD - 46, 1)
	scroll:SetScrollChild(content)

	local closeButton = k.makeButton(f, "Close", 96, function() f:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", -PAD, 14)
	local refresh = k.makeButton(f, "Refresh", 96, function() render(true) end)
	refresh:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", PAD + 2, 20)
	hint:SetPoint("RIGHT", refresh, "LEFT", -8, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Click a step with a pin for a waypoint. Data from Questie.")
	staticTexts[#staticTexts + 1] = { hint, "GameFontDisableSmall" }
	f.buttons = { closeButton, refresh, guideMenuButton }

	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -3, 3)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	-- follows the cursor while the button is held, top-left corner pinned (the game's StartSizing snaps about in
	-- Forever; see the settings window); the list is drawn again when the button is let go
	local sizing
	local function cursor()
		local scale = f:GetEffectiveScale()
		local x, y = GetCursorPosition()
		return x / scale, y / scale
	end
	local function stopSizing()
		if not sizing then return end
		sizing = nil
		grip:SetScript("OnUpdate", nil)
		grip:SetButtonState("NORMAL")
		render()
	end
	grip:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local left, top = f:GetLeft(), f:GetTop()
		if not (left and top) then return end
		local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * k, top * k)
		local cx, cy = cursor()
		sizing = { x = cx, y = cy, w = f:GetWidth(), h = f:GetHeight() }
		self:SetButtonState("PUSHED", true)
		self:SetScript("OnUpdate", function()
			if not IsMouseButtonDown("LeftButton") then stopSizing() return end
			local x, y = cursor()
			local w = math.min(math.max(sizing.w + (x - sizing.x), MIN_W), MAX_W)
			local h = math.min(math.max(sizing.h - (y - sizing.y), MIN_H), MAX_H)
			if math.abs(w - f:GetWidth()) >= 1 or math.abs(h - f:GetHeight()) >= 1 then
				f:SetSize(math.floor(w + 0.5), math.floor(h + 0.5))
			end
		end)
	end)
	grip:SetScript("OnMouseUp", stopSizing)
	grip:SetScript("OnHide", stopSizing)
	-- each opening starts at your current guide
	-- events only while open: item data arriving (vendor values, names) redraws it; a quest accepted or turned in builds
	-- the list again
	local EVENTS = { "GET_ITEM_INFO_RECEIVED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }
	f:SetScript("OnShow", function()
		viewGuide = nil
		wipe(history)
		for _, e in ipairs(EVENTS) do pcall(f.RegisterEvent, f, e) end
		applyStaticFonts()
		render(true)
	end)
	-- HookScript, not SetScript: SetScript would drop the earlier OnHide hook that closes the Guides dropdown (it
	-- stayed open after the journal closed)
	f:HookScript("OnHide", function() for _, e in ipairs(EVENTS) do pcall(f.UnregisterEvent, f, e) end end)
	f:SetScript("OnEvent", function(_, event)
		if event == "GET_ITEM_INFO_RECEIVED" then
			if waitingItems then api.refreshPrereqs() end
		else
			cached = nil
			api.refreshPrereqs()
		end
	end)
	f:Hide()
end

function applyStaticFonts()
	for _, entry in ipairs(staticTexts) do styleText(entry[1], entry[2]) end
	if frame and frame.arrangeOpacity then frame.arrangeOpacity() end
	for _, button in ipairs(frame and frame.buttons or {}) do
		local fs = button.GetFontString and button:GetFontString()
		if fs then styleText(fs, "GameFontNormal") end
		local textW = fs and fs:GetStringWidth() or 0
		button:SetSize(math.max(96, math.ceil(textW + 28)), math.floor(24 * textScale() + 0.5))
	end
end

-- Questie's reward list became ready, or item data arrived: draw again (at most every half second)
local redrawQueued = false
function api.refreshPrereqs()
	if not (frame and frame:IsShown()) or redrawQueued then return end
	redrawQueued = true
	C_Timer.After(0.5, function() redrawQueued = false; if frame and frame:IsShown() then render() end end)
end

-- /qt Text size or font changed (Config.lua applyFonts)
function api.refreshPrereqsFonts()
	if not frame then return end
	applyStaticFonts()
	if frame:IsShown() then render() end
end

-- Ctrl+right-click on the RXP Tracker (Core.lua): open, or close when open
function api.togglePrereqs()
	if not api.themeKit then return end
	if not frame then build() end
	if frame:IsShown() then frame:Hide() else frame:Show() end
end
