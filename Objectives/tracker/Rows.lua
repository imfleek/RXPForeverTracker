local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local view = ns.view

local NUMBER_MARGIN = 1
-- CONSTRAINT: ratios of one font line's height, measured live at Blizzard's 12 pt line; the template's dash sits
-- MARKER_LIFT above the first line's middle (ObjectiveTrackerLineTemplate, Dash anchor).
local MARKER_LIFT, NUMBER_DROP, FIRST_RISE = 0.03, 0.11, 1 / 3
-- CONSTRAINT: a hyphen's ink sits DASH_BEARING left of its advance's middle; the marker column is placed COLUMN_SHIFT
-- left of the slot's middle, on the axis through that ink.
local COLUMN_SHIFT = 0.08
local DASH_BEARING = 0.046
local LINE_SPACING = ObjectiveTrackerModuleMixin.lineSpacing
local LOOKAHEAD_SCALE = 5 / 6
local SLOT_SIZE, SLOT_GAP, SLOT_MARGIN, SLOT_COLUMNS = 1.5, 2 / 12, 0.35, 2
local BOTTOM_TRIM = -4
local DIVIDER_ATLAS, DIVIDER_PAD, DIVIDER_INSET_RATIO, DIVIDER_SHIFT = "UI-World-Quest-golden-line", 0.3, 1 / 4, 0.14
local DONE_COLOR = OBJECTIVE_TRACKER_COLOR.Complete
-- CONSTRAINT: a copy: NormalHighlight.reverse would swap the colour on hover (ObjectiveTrackerBlockMixin).
local ACTIVE_COLOR = {
	r = OBJECTIVE_TRACKER_COLOR.NormalHighlight.r,
	g = OBJECTIVE_TRACKER_COLOR.NormalHighlight.g,
	b = OBJECTIVE_TRACKER_COLOR.NormalHighlight.b,
}

-- CONSTRAINT: PixelUtil.ConvertPixelsToUIForRegion is GetNearestPixelSize(value, region:GetEffectiveScale())
-- (Blizzard_SharedXML PixelUtil); its parameter is named desiredPixels but takes UI units.
local snap = PixelUtil.ConvertPixelsToUIForRegion

local forever = ns.forever
local NORMAL_COLOR = OBJECTIVE_TRACKER_COLOR.Normal
local INFO_ICON = "Interface\\FriendsFrame\\InformationIcon"
local UPCOMING_LABEL = "Upcoming Steps"
local UPCOMING_PAD = 4

-- Forever Style keeps upcoming steps at full size, like the game's own quests.
local function lookaheadSize(size, active)
	return (active or forever()) and size or size * LOOKAHEAD_SCALE
end

local module, entriesOf, measure, separator, rowPool, linePool, upcoming
-- true until the back-one-step box has been placed in this layout pass
local wantBack

local nameForms, insideLink -- below
local decorate, linkEnter, linkLeave, linkClick -- below, with the step-line helpers they use

-- "Click here to copy the link" steps (RestedXP's .link element, which carries a url): clicking the line opens a box
-- with the address selected, to copy with Ctrl+C.
local COPY_LINK = {
	text = "Press Ctrl+C to copy the link, then paste it into your browser.",
	hasEditBox = 1,
	editBoxWidth = 320,
	button1 = OKAY,
	OnShow = function(self, url)
		local box = self.editBox or self.EditBox or (self.GetName and _G[(self:GetName() or "") .. "EditBox"])
		if box then
			box:SetText(url or "")
			box:HighlightText()
			box:SetFocus()
		end
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}
if StaticPopupDialogs then StaticPopupDialogs.RXPFOREVERTRACKER_COPY_LINK = COPY_LINK end
local function urlOf(line)
	local element = line.rxpElement
	local url = type(element) == "table" and element.url
	return type(url) == "string" and url ~= "" and url or nil
end
-- A ".clicknext" step ("CLICK HERE FOR THE 1-9 SKYBORNE GUIDE"): the guide it starts, as "Group\Name" or "Name"
local function nextOf(line)
	local element = line.rxpElement
	local spec = type(element) == "table" and element.next
	if type(spec) ~= "string" or spec == "" then return nil end
	local group, name = spec:match("^(.-)\\(.+)$")
	return group, name or spec
end

-- RestedXP's "Missing pre-requisites" note on an accept / turn-in step (a string tooltip with its error icon); any
-- other string tooltip RestedXP gives an element shows too. Numbers there are its debug ids: not shown.
local function noteOf(line)
	local element = line.rxpElement
	local tip = type(element) == "table" and element.tooltip
	return type(tip) == "string" and tip ~= "" and tip or nil
end
local function isMissingPrereqs(line)
	local element = line.rxpElement
	local icons = ns.rxp and ns.rxp.icons
	return type(element) == "table" and noteOf(line) ~= nil and type(icons) == "table" and icons.error ~= nil
		and element.icon == icons.error
end

-- "Step skipped: XP requirements are not met" and the like: RestedXP's note on the step itself
local function stepNoteOf(line)
	local element = line.rxpElement
	local step = type(element) == "table" and element.step
	local tip = type(step) == "table" and step.tooltipText
	if type(tip) ~= "string" or tip == "" then return nil end
	-- RestedXP's wording for a step skipped because you are past its level; said the way it actually is here
	local XP_SKIP = "Step skipped: XP requirements are not met"
	if tip == XP_SKIP or (ns.L and tip == ns.L(XP_SKIP)) then return "Steps skipped: XP requirements are exceeded" end
	return tip
end

local function startGuide(group, name)
	local RXP = ns.rxp
	local guide = RXP and RXP.GetGuideTable and (group and RXP.GetGuideTable(group, name))
	if not guide and RXP and type(RXP.guides) == "table" then
		for _, g in pairs(RXP.guides) do
			if type(g) == "table" and g.name == name and (not group or g.group == group) then guide = g break end
		end
	end
	if not (guide and RXP.LoadGuide) then
		ns.say("that guide (" .. tostring(name) .. ") was not found.")
		return
	end
	local ok, err = pcall(RXP.LoadGuide, RXP, guide)
	if ok then
		if ns.guideChanged then ns.guideChanged() end
		if ns.resetEmptyRetries then ns.resetEmptyRetries() end
		if ns.invalidate then ns.invalidate() end
		ns.say("Starting " .. tostring(guide.displayname or guide.name or name) .. ".")
	else
		ns.say("Could not start that guide: " .. tostring(err))
	end
end

local function copyLink(url)
	if not StaticPopup_Show then return end
	local dialog = StaticPopup_Show("RXPFOREVERTRACKER_COPY_LINK", nil, nil, url)
	-- older StaticPopup code passes data to OnShow only through the dialog's data field
	if dialog then
		dialog.data = url
		local box = dialog.editBox or dialog.EditBox or (dialog.GetName and _G[(dialog:GetName() or "") .. "EditBox"])
		if box then box:SetText(url); box:HighlightText(); box:SetFocus() end
	end
end

-- left-click on a step line: copy its link, start the guide it names, or open the Prerequisite Journal for a step
-- with missing prerequisites; other buttons (and other lines) go on to the step as before
local function copyLinkClick(line, button)
	if button ~= "LeftButton" then return end
	local url = urlOf(line)
	if url then copyLink(url) return end
	local group, name = nextOf(line)
	if name then startGuide(group, name) return end
	if isMissingPrereqs(line) then
		local trackerApi = root.tracker and root.tracker.api
		local journal = _G.RXPForeverTrackerPrereqs
		if trackerApi and trackerApi.togglePrereqs and not (journal and journal:IsShown()) then trackerApi.togglePrereqs() end
	end
end

-- hover: what the line does on a click, and RestedXP's notes on it
local function copyLinkEnter(line)
	if GameTooltip:IsShown() and GameTooltip:GetOwner() ~= line then return end
	local url = urlOf(line)
	local group, name = nextOf(line)
	local note, stepNote = noteOf(line), stepNoteOf(line)
	if not (url or name or note or stepNote) then return end
	GameTooltip:SetOwner(line, "ANCHOR_CURSOR_RIGHT", 12, 0)
	local titled = false
	local function line1(text, r, g, b)
		if titled then GameTooltip:AddLine(text, r, g, b, true) else GameTooltip:SetText(text, r, g, b, 1, true); titled = true end
	end
	if url then
		line1("Click to copy the link", 1, 0.82, 0)
		GameTooltip:AddLine(url, 1, 1, 1, true)
	elseif name then
		line1("Click to start " .. name, 1, 0.82, 0)
		if group then GameTooltip:AddLine(group, 0.7, 0.7, 0.7, true) end
	end
	if note then
		line1(note, 1, 1, 1)
		if isMissingPrereqs(line) then GameTooltip:AddLine("Click to open the Prerequisite Journal.", 0.5, 0.85, 1, true) end
	end
	if stepNote then line1(stepNote, 0.75, 0.75, 0.75) end
	GameTooltip:Show()
end

-- Links in a step's text. RestedXP writes items as plain text ("|T133288:0|t[Gnarlpine Necklace]"), so the names
-- of the items the step itself handles (.collect, .use, .buy, .equip, ... - their ids are on its elements) become
-- item links, and an accept / turn-in step's quest name a quest link. The line template has links enabled, so these
-- answer the mouse with no other change to the line (it still passes clicks to the step). A line that copies a link,
-- starts a guide or carries one of RestedXP's notes, and has no link of its own, is wrapped whole in one of ours
-- ("rxpft:" links), so hovering and clicking it works the same way.
local ITEM_FIELDS = { "id", "itemId", "itemID", "item" }
local ITEM_TAGS = { collect = true, destroy = true, questitemcount = true, retrieveitem = true, buy = true, equip = true,
	collectmount = true, collecttoy = true, use = true, itemcount = true, bankdeposit = true, bankwithdraw = true }
local requested, itemWatch = {}, nil
-- Decorated text per element: the links depend only on the element, its step and its text, so a line is worked out
-- once and again only when its text changes or an item's name arrives (linkGeneration). Weak keys: a step's elements
-- go when RestedXP drops the guide.
local linkGeneration = 0
local linkCache = setmetatable({}, { __mode = "k" })
-- Item names arrive from the server: any arrival can make a name-only bracket linkable, so decorated lines are worked
-- out again afterwards (linkGeneration); a requested one also lays the tracker out again, once per burst.
local function watchItems()
	if itemWatch or not CreateFrame then return end
	itemWatch = CreateFrame("Frame")
	pcall(itemWatch.RegisterEvent, itemWatch, "GET_ITEM_INFO_RECEIVED")
	itemWatch:SetScript("OnEvent", function(self, _, got)
		linkGeneration = linkGeneration + 1
		if requested[got] == true then
			requested[got] = "loaded"
			if not self.pending then
				self.pending = true
				C_Timer.After(0.3, function() self.pending = nil; if ns.relayout then ns.relayout() end end)
			end
		end
	end)
end
local function itemName(id)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not name and GetItemInfo then name = GetItemInfo(id) end
	if not name and not requested[id] then
		requested[id] = true
		if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
		watchItems()
	end
	return name
end
-- CONSTRAINT: an item's name is only known once the game has loaded it, but its icon is known at once
-- (GetItemInfoInstant); RestedXP writes the icon in front of the name ("|T133972:0|t[Snickerfang Jowl]"), so the icon
-- picks the item when the name is not loaded yet. An icon two of the step's items share picks neither.
local function itemIcon(id)
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if ok and icon then return icon end
	end
	local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if get then
		local ok, _, _, _, _, icon = pcall(get, id)
		if ok then return icon end
	end
end
local function spellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and name then return name end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, id)
		if ok then return name end
	end
end
local function spellIcon(id)
	local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
	if get then
		local ok, icon = pcall(get, id)
		if ok then return icon end
	end
end
-- the spells a step casts, uses or trains (.cast, .usespell, .train): spell links with the game's spell tooltip
local SPELL_TAGS = { cast = true, usespell = true, train = true }

local function addLink(found, kind, id, name, icon)
	id = tonumber(id)
	if not id or id <= 0 then return end
	local link = kind .. ":" .. id
	if type(name) == "string" and name ~= "" then
		found.names[name:lower()] = link
		found.order[#found.order + 1] = { name = name, link = link }
	end
	if icon then
		local key = tostring(icon)
		local had = found.icons[key]
		found.icons[key] = (had == nil or had == link) and link or false
	end
end
local function stepLinks(element)
	local step = type(element) == "table" and element.step
	local found = { names = {}, icons = {}, order = {} }
	for _, e in ipairs(type(step) == "table" and type(step.elements) == "table" and step.elements or { element }) do
		if type(e) == "table" and SPELL_TAGS[e.tag] then
			local ids = {}
			if e.id then ids[#ids + 1] = e.id end
			if type(e.ids) == "table" then for _, v in ipairs(e.ids) do ids[#ids + 1] = v end end
			if e.tag == "usespell" and type(e.activeItems) == "table" then
				for k in pairs(e.activeItems) do ids[#ids + 1] = k end
			end
			for _, id in ipairs(ids) do
				id = tonumber(id)
				if id and id > 0 then addLink(found, "spell", id, spellName(id), spellIcon(id)) end
			end
		elseif type(e) == "table" and (ITEM_TAGS[e.tag] or e.itemId or e.itemID) then
			local ids = {}
			for _, field in ipairs(ITEM_FIELDS) do ids[#ids + 1] = e[field] end
			-- (not ipairs over { e.ids, e.items, e.activeItems }: a missing first list ended that loop at once, so the
			-- ids of .use and .bankwithdraw steps were never read)
			for _, field in ipairs({ "ids", "items", "activeItems" }) do
				local list = e[field]
				if type(list) == "table" then
					for k, v in pairs(list) do ids[#ids + 1] = type(v) == "number" and v or k end
				end
			end
			for _, id in ipairs(ids) do
				id = tonumber(id)
				if id and id > 0 then addLink(found, "item", id, itemName(id), itemIcon(id)) end
			end
		end
	end
	return found
end
local function plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cRXP_[%u_]-_", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
-- a name as written, then singular forms of a plural ("Potions" -> "Potion", "Berries" -> "Berry", "Boxes" -> "Box")
function nameForms(name)
	local forms = { name }
	local function add(form) if form ~= name and form ~= "" then forms[#forms + 1] = form end end
	-- a book's loose pages ("Green Hills of Stranglethorn - Pages"): its first page stands for them
	local book = name:match("^(.-)%s*%-?%s*[Pp]ages$")
	if book and book ~= "" then add(book .. " - Page 1") end
	if name:find("ies$") then add((name:gsub("ies$", "y"))) end
	if name:find("es$") then add((name:gsub("es$", ""))) end
	if name:find("s$") then add((name:gsub("s$", ""))) end
	return forms
end
-- the texture a "|T...|t" tag shows: a file id or a path
local function iconKey(tag)
	local tex = tag and tag:match("^|T([^:|]+)")
	if not tex then return nil end
	return tonumber(tex) and tostring(tonumber(tex)) or tex:lower():gsub("\\", "/")
end

-- A cast step: RestedXP puts the spell's own icon in front of the line, and the step names the spell with the same
-- icon again; the line starts with one general spell icon instead.
local CAST_ICON = "|TInterface/ICONS/INV_Misc_Book_09:0|t"
local function castIcon(text, element)
	if type(element) ~= "table" or element.tag ~= "cast" then return text end
	local lead = text:match("^(|T[^|]-|t)")
	if lead then return CAST_ICON .. text:sub(#lead + 1) end
	return CAST_ICON .. text
end

-- Items guides tell you to buy by name only (".vendor >> Buy [Greater Healing Potions]": no item id in the step). The
-- game finds an item by name only once it has loaded it, so these common ones are known by id; each is used only when
-- the icon in front of the name is that item's icon, or the game's name for the id matches.
local KNOWN_ITEMS = {
	["minor healing potion"] = 118, ["lesser healing potion"] = 858, ["healing potion"] = 929,
	["greater healing potion"] = 1710, ["superior healing potion"] = 3928, ["major healing potion"] = 13446,
	["minor mana potion"] = 2455, ["lesser mana potion"] = 3385, ["mana potion"] = 3827,
	["greater mana potion"] = 6149, ["superior mana potion"] = 13443, ["major mana potion"] = 13444,
	["ice cold milk"] = 1179, ["freshly baked bread"] = 4541, ["dalaran sharp"] = 414, ["mild spices"] = 2678,
	["flash powder"] = 5140, ["bronze tube"] = 4371, ["liferoot"] = 3357, ["small brown pouch"] = 4496,
	["green hills of stranglethorn - page 1"] = 2725, ["shredder operating manual - page 1"] = 16645,
	["rough arrow"] = 2512, ["sharp arrow"] = 2515, ["razor arrow"] = 3030, ["jagged arrow"] = 11285,
}
local function knownItem(forms, icon)
	for _, name in ipairs(forms) do
		local id = KNOWN_ITEMS[name:lower()]
		if id then
			local want = icon and iconKey(icon)
			local have = itemIcon(id)
			if want and have then
				if tostring(have) == want then return id end
			else
				local real = itemName(id)
				if not real or real:lower() == name:lower() then return id end
			end
		end
	end
end
-- is position at inside a link already ("|H...|h text |h")?
function insideLink(text, at)
	local open, from = nil, 1
	while true do
		local h = text:find("|H", from, true)
		if not h or h >= at then break end
		open, from = h, h + 2
	end
	if not open then return false end
	local first = text:find("|h", open + 2, true)
	local second = first and text:find("|h", first + 2, true)
	return not (second and second < at)
end

local function linkText(text, element)
	local out = castIcon(text, element)
	if not out:find("|H", 1, true) then
		local found = stepLinks(element)
		local icons = {}
		for k, v in pairs(found.icons) do
			icons[k] = v
			if type(k) == "string" and not tonumber(k) then icons[k:lower():gsub("\\", "/")] = v end
		end
		-- a name the step handles: by its name, then by the icon in front of it, then the game's item lookup
		local function linkFor(inner, icon)
			local key = plain(inner)
			local link = found.names[key:lower()]
			if not link and icon then
				local byIcon = icons[iconKey(icon)]
				if byIcon then link = byIcon end
			end
			-- guides name some items in the plural ("[Superior Healing Potions]"): the singular is tried too
			if not link and key ~= "" and C_Item and C_Item.GetItemInfoInstant then
				for _, name in ipairs(nameForms(key)) do
					local ok, id = pcall(C_Item.GetItemInfoInstant, name)
					if ok and type(id) == "number" then link = "item:" .. id break end
				end
			end
			if not link and key ~= "" then
				local id = knownItem(nameForms(key), icon)
				if id then link = "item:" .. id end
			end
			return link
		end
		-- the icon in front of the name joins the link, so hovering either shows the tooltip
		-- (brackets already linked are held as \1 \2 until both passes are done, so none is linked twice)
		out = out:gsub("(|T[^|]-|t)%[(.-)%]", function(icon, inner)
			local link = linkFor(inner, icon)
			if link then return ("|H%s|h%s\1%s\2|h"):format(link, icon, inner) end
			return icon .. "\1" .. inner .. "\2" -- decided here (its icon said no): the bare-name pass leaves it alone
		end)
		out = out:gsub("%[(.-)%]", function(inner)
			local link = linkFor(inner)
			if link then return ("|H%s|h\1%s\2|h"):format(link, inner) end
		end)
		out = out:gsub("\1", "["):gsub("\2", "]")
		-- a spell the step names without brackets ("Cast Teleport: Moonglade"): its first mention
		for _, entry in ipairs(found.order) do
			if entry.link:find("^spell:") and not out:find("|H" .. entry.link .. "|h", 1, true) then
				local at, to = out:find(entry.name, 1, true)
				if at and not out:sub(1, at - 1):find("|H[^|]*|h[^|]*$") then
					out = out:sub(1, at - 1) .. ("|H%s|h%s|h"):format(entry.link, entry.name) .. out:sub(to + 1)
				end
			end
		end
		-- the quest an accept / turn-in step names; an upcoming step's line holds the text of all its objectives, so it
		-- links the quest of each of its accept / turn-in objectives
		local quests = type(element) == "table" and element.upcoming and type(element.step) == "table"
			and type(element.step.elements) == "table" and element.step.elements or { element }
		for _, e in ipairs(quests) do
			local qid = type(e) == "table" and tonumber(e.questId)
			local title = type(e) == "table" and type(e.title) == "string" and e.title ~= "" and e.title
			if qid and title and (e.tag == "accept" or e.tag == "turnin") then
				local at, to = out:find(title, 1, true)
				while at and insideLink(out, at) do at, to = out:find(title, to + 1, true) end
				if at then out = out:sub(1, at - 1) .. ("|Hquest:%d|h%s|h"):format(qid, title) .. out:sub(to + 1) end
			end
		end
	end
	return out
end

decorate = function(text, element, line)
	if type(text) ~= "string" or text == "" then return text end
	watchItems()
	local out
	local cached = type(element) == "table" and linkCache[element]
	if cached and cached.text == text and cached.generation == linkGeneration then
		out = cached.out
	else
		out = linkText(text, element)
		if type(element) == "table" then
			cached = cached or {}
			cached.text, cached.generation, cached.out = text, linkGeneration, out
			linkCache[element] = cached
		end
	end
	if line and not out:find("|H", 1, true) and (urlOf(line) or nextOf(line) or noteOf(line) or stepNoteOf(line)) then
		out = "|Hrxpft:line|h" .. out .. "|h"
	end
	return out
end

-- RestedXP's notes on a line, under a link's own tooltip
local function addNotes(line)
	local note, stepNote = noteOf(line), stepNoteOf(line)
	if note then
		GameTooltip:AddLine(note, 1, 1, 1, true)
		if isMissingPrereqs(line) then GameTooltip:AddLine("Click to open the Prerequisite Journal.", 0.5, 0.85, 1, true) end
	end
	if stepNote then GameTooltip:AddLine(stepNote, 0.75, 0.75, 0.75, true) end
end

-- hover over a link: its tooltip (an item's, a quest's), or for our own line links what a click does
linkEnter = function(line, link, text, ...)
	if type(link) == "string" and link:find("^rxpft:") then
		copyLinkEnter(line)
		return
	end
	-- not handed to RestedXP's own row: its window is usually hidden, and a tooltip owned by a hidden frame does
	-- not show
	GameTooltip:SetOwner(line, "ANCHOR_CURSOR_RIGHT", 12, 0)
	if not pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
		GameTooltip:SetText(text or link)
	end
	addNotes(line)
	GameTooltip:Show()
end
linkLeave = function(line)
	if GameTooltip:GetOwner() == line then GameTooltip:Hide() end
end
-- click on a link: ours copy / start / open the journal (left button); the game's own as in chat (SetItemRef)
linkClick = function(line, link, text, button)
	-- Shift+right-click belongs to the step (an upcoming step becomes the current one), even on a link
	if button == "RightButton" and IsShiftKeyDown() then return end
	line.rxpLinkClickedAt = GetTime()
	if type(link) == "string" and link:find("^rxpft:") then
		copyLinkClick(line, button)
		return
	end
	if button == "LeftButton" and (urlOf(line) or nextOf(line) or isMissingPrereqs(line)) and not IsModifiedClick() then
		copyLinkClick(line, button)
		return
	end
	-- a quest name Shift+clicked: the game's own quest link in chat (GetQuestLink), as the quest log does
	local questID = type(link) == "string" and tonumber(link:match("^quest:(%d+)"))
	if questID and IsShiftKeyDown() then
		local chatLink = GetQuestLink and GetQuestLink(questID)
		if not chatLink then
			local title = (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID))
				or (type(text) == "string" and text:match("|h%[?([^|%]]+)%]?|h")) or ("Quest " .. questID)
			chatLink = ("|cffffff00|Hquest:%d:-1|h[%s]|h|r"):format(questID, title)
		end
		local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
		local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
		if not (insert and insert(chatLink)) and open then open(chatLink) end
		return
	end
	if SetItemRef then SetItemRef(link, text, button) end
end

local function pointedAt(owner)
	local any, visible
	for line in linePool:EnumerateActive() do
		if line.rxpRow == owner then
			any = true
			if line:IsVisible() then visible = true end
		end
	end
	return any, visible
end

-- CONSTRAINT: no width of its own: a FontString with one is cut with "..." once its text is wider; laneWidth only
-- keeps the room clear.
local function setNumber(row, entry)
	local number, first = row.Number, row.usedLines[1]
	local boxTop = entry.title and 0 or row.rise
	if forever() then
		number:SetText("")
		return
	end
	local color = OBJECTIVE_TRACKER_COLOR[entry.active and "Header" or "Complete"]
	number:SetFont(first.Text:GetFont())
	number:SetTextColor(color.r, color.g, color.b)
	number:SetWidth(0)
	number:SetText(entry.number)
	number:SetPoint("RIGHT", row, "TOPRIGHT", -NUMBER_MARGIN, (boxTop - row.height) / 2 - first.fontHeight * NUMBER_DROP)
end

-- CONSTRAINT: Action.lua placeButtons reads slots.size, slots.gap, slots.columns and slots.uses. A line's uses list is
-- refilled in place (Uses.lua setLine), so it may be empty.
local function placeSlots(row, line, uses, shift)
	local slots = line.Slots
	if not (uses and uses[1]) then
		if slots then slots:Hide() end
		return
	end
	if not slots then
		slots = CreateFrame("Frame", nil, line)
		line.Slots = slots
	end
	local fontHeight = line.fontHeight
	local columns = math.min(#uses, SLOT_COLUMNS)
	local size = 2 * snap(fontHeight * SLOT_SIZE / 2, line)
	local gap = snap(fontHeight * SLOT_GAP, line)
	local slotRows = math.ceil(#uses / columns)
	local lift = (size - fontHeight) / 2
	local slotsHeight = slotRows * (size + gap) - gap
	slots.size, slots.gap, slots.columns, slots.uses = size, gap, columns, uses
	slots:SetSize(columns * (size + gap) - gap, slotsHeight)
	slots:SetPoint("TOPRIGHT", line, "TOPLEFT", -snap(fontHeight * SLOT_MARGIN + (shift or 0), line), lift)
	slots:Show()
	local need, height = slotsHeight - lift, line:GetHeight()
	if need > height then
		line:SetHeight(need)
		row.height = row.height + need - height
	end
end

-- Shift+right-click on an upcoming step (its heading, or its text outside a link): that step becomes the current one
-- (ns.goToStep: RestedXP's SetStep). A click on a link stays the link's own.
local function jumpTo(row)
	local step = row and row.rxpUpcomingStep
	if type(step) == "number" and ns.goToStep then ns.goToStep(step) end
end
local function rowHeaderClick(row, mouseButton)
	if mouseButton == "RightButton" and IsShiftKeyDown() then jumpTo(row) end
end
local function lineUp(line, mouseButton)
	if mouseButton ~= "RightButton" or not IsShiftKeyDown() then return end
	local clickedAt = GetTime()
	-- a link's own click comes first or right after: wait a frame, and leave link clicks alone
	C_Timer.After(0, function()
		if line.rxpLinkClickedAt and math.abs(line.rxpLinkClickedAt - clickedAt) < 0.1 then return end
		jumpTo(line.rxpRow)
	end)
end

local function addLine(row, key, objective, entry)
	local active = entry.active
	local line, isNew = linePool:Acquire()
	if isNew then
		-- CONSTRAINT: a template other than module.lineTemplate makes Block:GetLine free the line into Blizzard's
		-- shared pool (ObjectiveTrackerBlockMixin:GetLine and FreeLine).
		line.template = module.lineTemplate
		line:SetScript("OnHyperlinkEnter", linkEnter)
		line:SetScript("OnHyperlinkLeave", linkLeave)
		line:SetScript("OnHyperlinkClick", linkClick)
		line:HookScript("OnMouseUp", lineUp)
	end
	line:SetParent(row)
	line.rxpRow = objective.frame
	line.rxpElement = objective.element
	local font, size, flags = row.HeaderText:GetFont()
	size = lookaheadSize(size, active)
	line.Text:SetFont(font, size, flags)
	local dash = line.Dash
	local dashFont, _, dashFlags = dash:GetFont()
	dash:SetFont(dashFont, size, dashFlags)
	local fontHeight = dash:GetStringHeight()
	line.fontHeight = fontHeight
	-- Forever Style: the game's own dash on every line (no skip boxes), as on its quests.
	local fv = forever()
	local boxes = active and not fv
	-- CONSTRAINT: everything that places the dash is final before AddObjective measures the text (Block.lua
	-- SetStringText). QUEST_DASH ends in a space: it pulls a centred hyphen left of the box's column.
	dash:SetWidth(boxes and fontHeight or 0)
	dash:SetJustifyH(boxes and "CENTER" or "LEFT")
	local dashText = boxes and "-" or QUEST_DASH
	dash:SetText(dashText)
	local left = boxes and fontHeight * (DASH_BEARING - COLUMN_SHIFT) or -module.blockOffsetX
	dash:SetPoint("TOPLEFT", snap(left, dash), snap(fontHeight * MARKER_LIFT, dash))
	line:Show()
	-- CONSTRAINT: a line already in usedLines is reused by GetLine; one from ObjectiveTrackerManager's shared pool
	-- would create that pool's collection tainted (Manager.lua AcquireFrame).
	row.usedLines[key] = line
	local spacing = LINE_SPACING
	if key == 1 then
		if row.dividerGap then
			spacing = row.dividerGap + module.fromBlockOffsetY
		elseif not (entry.title or forever()) then
			spacing = -fontHeight * FIRST_RISE
		end
		row.rise = -spacing
	end
	module.lineSpacing = spacing
	local dashStyle, color
	if fv then
		-- the first line is the step itself (its icon leads), the rest are its parts: "- Turn in ..."
		dashStyle = key > 1 and OBJECTIVE_DASH_STYLE_SHOW or OBJECTIVE_DASH_STYLE_HIDE
		color = objective.done and DONE_COLOR or active and ACTIVE_COLOR or NORMAL_COLOR
	else
		dashStyle = key == 1 and (objective.note or not active) and OBJECTIVE_DASH_STYLE_SHOW or OBJECTIVE_DASH_STYLE_HIDE
		color = (objective.done or not active) and DONE_COLOR or ACTIVE_COLOR
	end
	row:AddObjective(key, decorate(objective.text, objective.element, line), nil, true, dashStyle, color)
	-- the first skip box gets the back-one-step box on its left; this line's circles move left to make room
	local back = wantBack and boxes and not objective.note
	if back then wantBack = false end
	placeSlots(row, line, active and objective.uses, back and ns.backButtonRoom(fontHeight) or 0)
	-- CONSTRAINT: AddObjective resets the dash text when the dash style changes.
	dash:SetText(dashText)
	ns.setSkipBox(line, objective, boxes, fontHeight * (0.5 - COLUMN_SHIFT), fontHeight * (MARKER_LIFT - 0.5))
	if back then ns.placeBackButton(line) end
end

-- Tracker settings > Current step(s) / Upcoming steps: scale, x (+ right) and y (+ up) of each group of rows
local function groupLook(active)
	local db = ns.db
	if active then
		return math.min(math.max(tonumber(db.currentScale) or 1, 0.5), 2), tonumber(db.currentX) or 0, tonumber(db.currentY) or 0
	end
	return math.min(math.max(tonumber(db.upcomingScale) or 1, 0.5), 2), tonumber(db.upcomingX) or 0, tonumber(db.upcomingY) or 0
end

-- Before the row is anchored and its text measured: its scale, and (when scaled or moved) a fixed width - the
-- contents' width less the left inset, in the row's own units - with the x move in its left offset. Blizzard's
-- AnchorBlock places a block LEFT at block.offsetX and, unless block.fixedWidth, RIGHT at the module's edge.
local function prepareRow(row, scale, x)
	if math.abs((row:GetScale() or 1) - scale) > 1e-4 then row:SetScale(scale) end
	if scale ~= 1 or x ~= 0 then
		local contentsW = module.ContentsFrame:GetWidth() or 0
		row.offsetX = (module.blockOffsetX + x) / scale
		row.fixedWidth = true
		row:SetWidth(math.max((contentsW - module.blockOffsetX) / scale, 20))
	else
		row.offsetX, row.fixedWidth = nil, nil
	end
end

-- After LayoutBlock: the row's top offset back to the unscaled gap (plus the group's y move on its first row), and
-- the module's contents height corrected for the scaled height and the move, so what follows lines up.
local function settleRow(row, scale, yUp, first)
	local shift = first and yUp or 0
	if scale == 1 and shift == 0 then return end
	for index = 1, row:GetNumPoints() do
		local point, relative, relativePoint, x, y = row:GetPoint(index)
		if point == "TOP" then
			row:SetPoint("TOP", relative, relativePoint, x, ((y or 0) + shift) / scale)
			break
		end
	end
	module.contentsHeight = (module.contentsHeight or 0) + (row.height or 0) * (scale - 1) - shift
end

-- x offset that puts a frame anchored to a line's left edge at the contents' left edge (whatever the row's x/scale)
local function contentsDX(line, fallback)
	local contents = module.ContentsFrame
	local cl, ll = contents:GetLeft(), line and line:GetLeft()
	if not (cl and ll) then return fallback end
	local ce = contents:GetEffectiveScale()
	return (cl * ce - ll * line:GetEffectiveScale()) / ce
end

local function beginRow(scale, x)
	local row, isNew = rowPool:Acquire()
	if isNew then
		row.parentModule = module
		row:Init()
		row.OnHeaderClick = rowHeaderClick -- the heading's button (ObjectiveTrackerBlockHeaderMixin) calls this
		row.Number = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
		row.Number:SetJustifyH("RIGHT")
		row.Number:SetWordWrap(false)
		row.Number:SetMaxLines(1)
	end
	row:Reset()
	row.isHighlighted = false
	wipe(row.usedLines)
	prepareRow(row, scale or 1, x or 0)
	module:AnchorBlock(row)
	return row
end

-- Forever Style: "Step 74" heading; an upcoming step gets an i that goes to that step.
local function stepHeading(entry)
	local label = tonumber(entry.number) and ("Step " .. entry.number) or entry.number or ""
	if entry.title and entry.title ~= "" and entry.title ~= label then label = label .. " - " .. entry.title end
	return label
end

-- The i on an upcoming step: a quest of the step that is in the quest log opens there; otherwise the step's first
-- location (RestedXP's goto/waypoint elements: zone = map ID, x/y in 0-100) becomes the game's map pin and is tracked.
local QUEST_TAGS = {complete = 1, turnin = 2, accept = 3}

local function stepOf(index)
	local guide = ns.rxp.currentGuide
	local steps = guide and not guide.empty and guide.steps
	return type(steps) == "table" and steps[index] or nil
end

local function stepQuest(step)
	local best, bestRank
	for _, element in ipairs(step.elements or {}) do
		local rank = QUEST_TAGS[element.tag]
		local id = tonumber(element.questId)
		if rank and id and ns.inQuestLog(id) and (not bestRank or rank < bestRank) then best, bestRank = id, rank end
	end
	return best
end

local function stepPlace(step)
	for _, element in ipairs(step.elements or {}) do
		local map, x, y = tonumber(element.zone), tonumber(element.x), tonumber(element.y)
		if not (x and y) and element.zx and element.zy then x, y = element.zx * 100, element.zy * 100 end
		if map and x and y then return map, x / 100, y / 100 end
	end
end

local function openQuest(questID)
	if QuestMapFrame_OpenToQuestDetails then return pcall(QuestMapFrame_OpenToQuestDetails, questID) end
	local index = C_QuestLog.GetLogIndexForQuestID(questID)
	if not index then return false end
	if QuestLog_SetSelection and QuestLogFrame then
		ShowUIPanel(QuestLogFrame)
		return pcall(QuestLog_SetSelection, index)
	end
	return false
end

local function placeName(map)
	local info = C_Map.GetMapInfo(map)
	return info and info.name or ("map " .. map)
end

local function setWaypoint(map, x, y)
	if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) and UiMapPoint then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		ns.say(("waypoint set: %s %.1f, %.1f"):format(placeName(map), x * 100, y * 100))
		return true
	end
	ns.say(("go to %s %.1f, %.1f (the game cannot pin that map)"):format(placeName(map), x * 100, y * 100))
	return true
end

local function infoAction(index)
	local step = stepOf(index)
	if not step then return nil end
	local quest = stepQuest(step)
	if quest then return "quest", quest end
	local map, x, y = stepPlace(step)
	if map then return "place", map, x, y end
end

local function infoClick(button)
	local kind, a, b, c = infoAction(button.step)
	if kind == "quest" then
		if not openQuest(a) then ns.say("could not open the quest log for that quest.") end
	elseif kind == "place" then
		setWaypoint(a, b, c)
	else
		ns.say("step " .. button.step .. " has no quest in your log and no location.")
	end
end

local function infoTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText("Step " .. tostring(button.step), 1, 0.82, 0)
	local kind, a, b, c = infoAction(button.step)
	local title = kind == "quest" and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(a)
	if kind == "quest" then
		GameTooltip:AddLine("Click: open " .. (title or "this quest") .. " in the quest log.", 1, 1, 1, true)
	elseif kind == "place" then
		GameTooltip:AddLine(("Click: waypoint to %s %.1f, %.1f."):format(placeName(a), b * 100, c * 100), 1, 1, 1, true)
	else
		GameTooltip:AddLine("No quest in your log and no location for this step.", 0.7, 0.7, 0.7, true)
	end
	GameTooltip:AddLine("Shift+right-click the step: make it your current step.", 0.6, 0.8, 1, true)
	GameTooltip:Show()
end

local function placeInfo(row, entry)
	local info = row.Info
	local wanted = forever() and not entry.active and tonumber(entry.number)
	if not wanted then
		if info then info:Hide() end
		return
	end
	if not info then
		info = CreateFrame("Button", nil, row)
		info:SetNormalTexture(INFO_ICON)
		info:SetHighlightTexture(INFO_ICON, "ADD")
		info:SetScript("OnClick", infoClick)
		info:SetScript("OnEnter", infoTooltip)
		info:SetScript("OnLeave", function(self) ns.releaseTooltip(GameTooltip, self) end)
		row.Info = info
	end
	local text = row.HeaderText
	local size = math.floor(select(2, text:GetFont()) + 0.5)
	info.step = wanted
	info:SetSize(size, size)
	info:ClearAllPoints()
	info:SetPoint("LEFT", text, "LEFT", text:GetStringWidth() + 4, 0)
	info:SetFrameLevel(row:GetFrameLevel() + 2)
	info:Show()
end

-- Forever Style, a current step: a check right of "Step N" marks the whole step done, as ticking every one of its
-- objectives' boxes would (RestedXP's ActiveStepElementPostClick: OnComplete, then the objective skipped; RestedXP's
-- next step check finishes the step and moves on).
-- The check is drawn in the Forever settings window's palette (Tracker/Config.lua C): two rotated strokes, each a
-- soft shadow, a muted gold rim and a dark middle; hovered, the rim brightens a little, the middle fills a muted gold
-- and a very faint glow shows. Stroke sizes and places follow the skip box's tick (SkipBox.lua sizeGlyphs, 11 px units).
local DONE_RIM = { 0.788, 0.635, 0.29, 1 }      -- C.on
local DONE_RIM_HOVER = { 0.86, 0.74, 0.47, 1 } -- between C.on and C.ring: a gentle brightening
local DONE_FILL_HOVER = { 0.71, 0.58, 0.39, 1 } -- C.thumb: a muted gold
local DONE_EMPTY = { 0.102, 0.071, 0.035, 0.92 } -- C.onKnob
local DONE_SHADOW = { 0, 0, 0, 0.55 }
local DONE_SCALE = 1.3 -- of the heading's font size
local DONE_STROKES = {
	{ rotation = -math.pi / 4, w = 3.5, h = 1.25, x = -1.5, y = -0.8 },
	{ rotation = math.pi / 4, w = 6, h = 1.25, x = 1, y = -0.1 },
}
local DONE_EDGE, DONE_GLOW = 0.75, 1.6 -- rim and glow widths, in the same 11 px units
local function newStroke(button, layer, sub, rotation, color, blend)
	local t = button:CreateTexture(nil, layer, nil, sub)
	t:SetColorTexture(1, 1, 1, 1)
	if blend then t:SetBlendMode(blend) end
	if t.SetRotation then t:SetRotation(rotation) end
	t:SetVertexColor(color[1], color[2], color[3], color[4])
	return t
end
local function paintDone(button)
	local hovered = button.hovered
	local rim, fill = hovered and DONE_RIM_HOVER or DONE_RIM, hovered and DONE_FILL_HOVER or DONE_EMPTY
	for i = 1, #DONE_STROKES do
		button.outer[i]:SetVertexColor(rim[1], rim[2], rim[3], rim[4])
		button.inner[i]:SetVertexColor(fill[1], fill[2], fill[3], fill[4])
		button.glow[i]:SetShown(hovered and true or false)
	end
end
local function sizeDone(button, size)
	if button.drawnSize == size then return end
	button.drawnSize = size
	local unit = size / 11
	for i, def in ipairs(DONE_STROKES) do
		local function place(t, grow, dx, dy)
			t:SetSize((def.w + 2 * grow) * unit, (def.h + 2 * grow) * unit)
			t:ClearAllPoints()
			t:SetPoint("CENTER", button, "CENTER", (def.x + (dx or 0)) * unit, (def.y + (dy or 0)) * unit)
		end
		place(button.glow[i], DONE_GLOW)
		place(button.shadow[i], DONE_EDGE, 0.45, -0.45)
		place(button.outer[i], DONE_EDGE)
		place(button.inner[i], 0)
	end
end
local function newDoneButton(row)
	local button = CreateFrame("Button", nil, row)
	button.glow, button.shadow, button.outer, button.inner = {}, {}, {}, {}
	for i, def in ipairs(DONE_STROKES) do
		button.glow[i] = newStroke(button, "BACKGROUND", 0, def.rotation, { 0.79, 0.64, 0.29, 0.15 }, "ADD")
		button.shadow[i] = newStroke(button, "ARTWORK", -1, def.rotation, DONE_SHADOW)
		button.outer[i] = newStroke(button, "ARTWORK", 0, def.rotation, DONE_RIM)
		button.inner[i] = newStroke(button, "ARTWORK", 1, def.rotation, DONE_EMPTY)
	end
	paintDone(button)
	return button
end
-- marks the whole step done, as ticking every one of its objectives' boxes would (RestedXP's ActiveStepElementPostClick:
-- OnComplete, then the objective skipped; RestedXP's next step check finishes the step and moves on)
function ns.markStepDone(number)
	local RXP, step = ns.rxp, stepOf(number)
	if type(step) ~= "table" then return false end
	local any = false
	for _, element in ipairs(type(step.elements) == "table" and step.elements or {}) do
		if type(element) == "table" and not (element.completed or element.skip or element.textOnly) then
			if element.OnComplete then pcall(element.OnComplete, element) end
			element.skip = true
			any = true
		end
	end
	if not any then step.completed = true end -- nothing left to tick (text only): the step itself
	RXP.updateSteps = true
	if type(RXP.UpdateMap) == "function" then pcall(RXP.UpdateMap) end
	-- then move on at once, as RestedXP would once it saw the step finished (waiting for its own pass could be undone
	-- before it came: RestedXP re-checks objectives and redraws in between). A sticky step is recorded as finished
	-- (RXPCData.stepSkip, as RestedXP does for one) and the step you are on is set again; the step you are on goes
	-- to the next one.
	local okProgress, progress = pcall(RXP.GetGuideProgress)
	if okProgress and type(progress) == "number" and not ns.isSecret(progress) then
		if step.sticky and number ~= progress then
			local data = _G.RXPCData
			if type(data) == "table" then
				data.stepSkip = type(data.stepSkip) == "table" and data.stepSkip or {}
				data.stepSkip[number] = true
			end
			pcall(RXP.SetStep, progress)
		elseif number == progress then
			pcall(RXP.SetStep, progress + 1)
		end
	end
	if ns.invalidate then ns.invalidate() end
	return true
end
local function doneClick(button)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	ns.markStepDone(button.step)
end
local function doneTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText("Mark step " .. tostring(button.step) .. " done", 1, 0.82, 0)
	GameTooltip:Show()
end
local function placeDone(row, entry)
	local done = rawget(row, "Done")
	local wanted = forever() and entry.active and tonumber(entry.number)
	if not wanted then
		if done then done:Hide() end
		return
	end
	if not done then
		done = newDoneButton(row)
		done:RegisterForClicks("LeftButtonUp")
		done:SetScript("OnClick", doneClick)
		done:SetScript("OnEnter", function(self) self.hovered = true; paintDone(self); doneTooltip(self) end)
		done:SetScript("OnLeave", function(self)
			self.hovered = nil
			paintDone(self)
			ns.releaseTooltip(GameTooltip, self)
		end)
		row.Done = done
	end
	local text = row.HeaderText
	local size = math.floor(select(2, text:GetFont()) * DONE_SCALE + 0.5)
	done.step = wanted
	done:SetSize(size, size)
	sizeDone(done, size)
	done:ClearAllPoints()
	done:SetPoint("LEFT", text, "LEFT", text:GetStringWidth() + 4, 0)
	done:SetFrameLevel(row:GetFrameLevel() + 2)
	done:Show()
end

local function layoutRow(row, entry, lane, dividerGap)
	row.dividerGap = dividerGap
	-- CONSTRAINT: before any line: AdjustRightEdgeOffset asserts no region exists yet (Block.lua).
	row:AdjustRightEdgeOffset(forever() and 0 or -(NUMBER_MARGIN + lane))
	row:SetHeader(forever() and stepHeading(entry) or entry.title or "")
	-- an upcoming step: Shift+right-click its heading or text to make it the current step (jumpTo)
	row.rxpUpcomingStep = not entry.active and tonumber(entry.number) or nil
	placeInfo(row, entry)
	placeDone(row, entry)
	for key, objective in ipairs(entry.lines) do addLine(row, key, objective, entry) end
	setNumber(row, entry)
end

local function headerSize(row)
	return select(2, row.HeaderText:GetFont())
end

-- CONSTRAINT: a texture cannot change parent: it hangs on the contents frame and is anchored to the row below it.
local function placeSeparator(above, row)
	local inset = module.blockOffsetX * DIVIDER_INSET_RATIO
	separator:SetWidth(module:GetWidth() - 2 * inset)
	-- from the contents' left edge, so moving or scaling the steps (or Extra width) does not move the line
	separator:SetPoint("TOPLEFT", above, "BOTTOMLEFT", inset + contentsDX(above, -module.blockOffsetX),
		-headerSize(row) * (DIVIDER_PAD + DIVIDER_SHIFT))
	separator:Show()
end

-- Forever Style "Upcoming Steps": a copy of the guide's own section header (every texture of the module template's
-- header, its text font, its collapse button art), so it matches the game's look on any client; its collapse button
-- folds the upcoming steps away.
local function copyTexture(from, to)
	local atlas = from.GetAtlas and from:GetAtlas()
	if atlas then
		to:SetAtlas(atlas)
	else
		to:SetTexture(from:GetTexture())
		to:SetTexCoord(from:GetTexCoord())
	end
	to:SetVertexColor(from:GetVertexColor())
	to:SetBlendMode(from:GetBlendMode())
	to:SetAlpha(from:GetAlpha())
end

-- CONSTRAINT: every anchor goes to the copy's own frame, never to a region of the guide's header: an anchor left on
-- the guide's header (its text is anchored to the journal book) drew the copy over the guide name.
local function copyPoints(from, to, newParent)
	to:ClearAllPoints()
	for index = 1, from:GetNumPoints() do
		local point, _, relativePoint, x, y = from:GetPoint(index)
		to:SetPoint(point, newParent, relativePoint, x, y)
	end
end

local function setUpcomingCollapsed(collapsed)
	ns.db.upcomingCollapsed = collapsed and true or false
	ns.relayout()
end

local function buildUpcoming()
	local source = module.Header
	local frame = CreateFrame("Frame", nil, module.ContentsFrame)
	frame:Hide()
	frame:SetHeight(source:GetHeight())
	for _, region in ipairs({source:GetRegions()}) do
		if region:GetObjectType() == "Texture" and region:IsShown() then
			-- CONSTRAINT: GetDrawLayer returns layer and sublevel; CreateTexture's third argument is a template name.
			local layer, sublevel = region:GetDrawLayer()
			local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
			copyTexture(region, texture)
			texture:SetSize(region:GetSize())
			copyPoints(region, texture, frame)
		end
	end
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(source.Text:GetFontObject() or "ObjectiveTrackerHeaderFont")
	text:SetTextColor(source.Text:GetTextColor())
	local textPoint = ns.headerTextPoint
	if textPoint then
		text:SetPoint(textPoint[1], frame, textPoint[2], textPoint[3], textPoint[4])
	else
		copyPoints(source.Text, text, frame)
	end
	text:SetText(UPCOMING_LABEL)
	frame.Text = text
	local sourceButton = source.MinimizeButton
	local button = CreateFrame("Button", nil, frame)
	button:SetSize(sourceButton:GetSize())
	copyPoints(sourceButton, button, frame)
	for _, kind in ipairs({"Normal", "Pushed", "Highlight"}) do
		local from = sourceButton["Get" .. kind .. "Texture"](sourceButton)
		if from then
			button["Set" .. kind .. "Texture"](button, from:GetTexture() or "")
			copyTexture(from, button["Get" .. kind .. "Texture"](button))
		end
	end
	-- copied while the RXP Tracker itself may show "expand": always keep the collapse art as the base
	local atlas = button:GetNormalTexture() and button:GetNormalTexture():GetAtlas()
	button.collapseAtlas = atlas and atlas:gsub("[Ee]xpand", "collapse") or atlas
	button:SetScript("OnClick", function() setUpcomingCollapsed(not ns.db.upcomingCollapsed) end)
	frame.MinimizeButton = button
	upcoming = frame
	return frame
end

-- the collapsed state shows the game's expand art when the client has it (atlas name with "expand" for "collapse")
local function showCollapsed(button, collapsed)
	local atlas = button.collapseAtlas
	if not atlas then return end
	local want = collapsed and atlas:gsub("[Cc]ollapse", "expand") or atlas
	if want ~= atlas and not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(want)) then want = atlas end
	for _, texture in ipairs({button:GetNormalTexture(), button:GetPushedTexture()}) do
		if texture then texture:SetAtlas(want) end
	end
end

-- The header is built once. If that fails, the error is reported once and the plain divider line is used instead,
-- so a failure cannot repeat on every layout pass.
local upcomingFailed
local function upcomingReady()
	if upcoming then return true end
	if upcomingFailed then return false end
	local ok, err = pcall(buildUpcoming)
	if not ok then
		upcomingFailed = true
		upcoming = nil
		geterrorhandler()("RXP ForeverTracker: Upcoming Steps header could not be built, using the divider line: "
			.. tostring(err))
	end
	return ok
end

local function upcomingHeight()
	return upcoming:GetHeight() + 2 * UPCOMING_PAD
end

-- below a line (the last current step), or at the top of a spacer row (point "TOPLEFT") when the current steps are
-- folded away
local function placeUpcoming(above, point)
	local frame = upcoming
	frame.Text:SetFontObject(module.Header.Text:GetFontObject() or "ObjectiveTrackerHeaderFont")
	frame.Text:SetFont(module.Header.Text:GetFont())
	frame:ClearAllPoints()
	frame:SetWidth(module:GetWidth())
	-- at the contents' left edge, whatever the current steps' x or scale
	frame:SetPoint("TOPLEFT", above, point or "BOTTOMLEFT", contentsDX(above, -module.blockOffsetX), -UPCOMING_PAD)
	showCollapsed(frame.MinimizeButton, ns.db.upcomingCollapsed)
	frame:Show()
end

-- CONSTRAINT: measured in the tracker's line font the active step's number came out wider than the lane and was cut
-- to "1...".
local function laneWidth(entries, row)
	local font, size, flags = row.HeaderText:GetFont()
	local width = 0
	for _, entry in ipairs(entries) do
		measure:SetFont(font, lookaheadSize(size, entry.active), flags)
		measure:SetText(entry.number)
		width = math.max(width, measure:GetStringWidth())
	end
	return width
end

-- CONSTRAINT: LayoutBlock runs even when collapsed (one row), or hasTriedBlocks stays false and the container drops
-- the module (ObjectiveTrackerModuleMixin:Update and InternalAddBlock).
---------------------------------------------------------------------------------------------------------------------
-- Upcoming steps scroll: upcomingShown of them at a time (default 2); the mouse wheel over them moves the window, and
-- at either end it scrolls the whole tracker as usual. A thin scrollbar beside them (on/off, only on mouse over,
-- colour: Tracker settings in /qt). The window goes back to the top when the steps move on.
---------------------------------------------------------------------------------------------------------------------
local upOffset, upKey, upTotal, upShown = 0, nil, 0, 2
local upRows = {} -- the upcoming rows drawn now
local lastActive = 0 -- when the upcoming steps were last hovered or scrolled (the scrollbar's fade)
local upBar

local function upcomingWindow(entries)
	local out, ahead = {}, {}
	for _, entry in ipairs(entries) do
		if entry.active then out[#out + 1] = entry else ahead[#ahead + 1] = entry end
	end
	upShown = math.max(1, tonumber(ns.db.upcomingShown) or 2)
	if ns.ALL_STEPS and upShown >= ns.ALL_STEPS then upShown = math.huge end -- "All": no scrolling
	upTotal = #ahead
	local key = ahead[1] and ahead[1].number
	if key ~= upKey then upKey, upOffset = key, 0 end
	upOffset = math.min(math.max(upOffset, 0), math.max(upTotal - upShown, 0))
	for i = upOffset + 1, math.min(upTotal, upOffset + upShown) do out[#out + 1] = ahead[i] end
	return out
end

local function upcomingWheel(_, delta)
	local new = math.min(math.max(upOffset - delta, 0), math.max(upTotal - upShown, 0))
	if new == upOffset then
		-- at the top or bottom of the upcoming steps: handed to the tracker, which scrolls the quests only when the
		-- cursor is nearer them than this guide (so in practice it stays put)
		local trackerApi = root.tracker and root.tracker.api
		if trackerApi and trackerApi.trackerWheel then trackerApi.trackerWheel(delta) end
		return
	end
	upOffset = new
	lastActive = GetTime() -- scrolling shows the bar (Only on mouseover)
	ns.relayout()
end

local function wheelOn(frame, on)
	if not (frame and frame.EnableMouseWheel) then return end
	frame:EnableMouseWheel(on)
	frame:SetScript("OnMouseWheel", on and upcomingWheel or nil)
end

local function hovering()
	for _, row in ipairs(upRows) do
		if row:IsMouseOver() then return true end
	end
	return upcoming and upcoming:IsShown() and upcoming:IsMouseOver() or false
end

local function buildUpBar()
	upBar = CreateFrame("Frame", nil, module.ContentsFrame)
	upBar:SetWidth(3)
	upBar.track = upBar:CreateTexture(nil, "BACKGROUND")
	upBar.track:SetAllPoints()
	upBar.track:SetColorTexture(0, 0, 0, 0.35)
	upBar.thumb = upBar:CreateTexture(nil, "ARTWORK")
	upBar.thumb:SetWidth(3)
	upBar.elapsed = 0
	return upBar
end

-- "only on mouse over": like the quest list's scrollbar, shown while the mouse is over the upcoming steps or the bar
-- (or the wheel just moved them), and fading out over 0.4 s once 2 s have passed since; a script runs only while the
-- bar is shown in this mode
local FADE_DELAY, FADE_TIME = 2, 0.4
local function hoverCheck(self, elapsed)
	local now = GetTime()
	if hovering() or self:IsMouseOver() then lastActive = now end
	local target = (now - lastActive < FADE_DELAY) and 1 or 0
	local alpha = self:GetAlpha()
	local step = elapsed / FADE_TIME
	if alpha < target then alpha = math.min(target, alpha + step) elseif alpha > target then alpha = math.max(target, alpha - step) end
	if alpha ~= self:GetAlpha() then self:SetAlpha(alpha) end
end

local function placeUpBar()
	local first, last = upRows[1], upRows[#upRows]
	local want = ns.db.upcomingScrollbar and first and upTotal > upShown
	if not want then
		if upBar then upBar:Hide() end
		return
	end
	local bar = upBar or buildUpBar()
	bar:ClearAllPoints()
	local width = math.min(math.max(tonumber(ns.db.upcomingScrollbarWidth) or 3, 1), 12)
	-- in the quest list scrollbar's column (centred on it), so it never runs over the steps' text and lines up with
	-- it; at the steps' right edge in the RXP Tracker's own window or before the quest list has its scrollbar
	local trackerApi = root.tracker and root.tracker.api
	local qLeft, qRight
	if not (ns.detached and ns.detached()) and trackerApi and trackerApi.questBarColumn then
		qLeft, qRight = trackerApi.questBarColumn()
	end
	local firstRight, lastRight = first:GetRight(), last:GetRight()
	if qLeft and firstRight and lastRight then
		local ce = bar:GetParent():GetEffectiveScale()
		local leftPx = (qLeft + qRight) / 2 - width * ce / 2
		bar:SetPoint("TOPLEFT", first, "TOPRIGHT", (leftPx - firstRight * first:GetEffectiveScale()) / ce, 0)
		bar:SetPoint("BOTTOMLEFT", last, "BOTTOMRIGHT", (leftPx - lastRight * last:GetEffectiveScale()) / ce, 0)
	else
		bar:SetPoint("TOPRIGHT", first, "TOPRIGHT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 0, 0)
	end
	bar:SetWidth(width)
	bar.thumb:SetWidth(width)
	local c = ns.db.upcomingScrollbarColor or { 0.2, 0.85, 0.55, 0.85 }
	bar.thumb:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	local height = (first.height or 0) * (first:GetScale() or 1)
	for i = 2, #upRows do height = height + (upRows[i].height or 0) * (upRows[i]:GetScale() or 1) end
	height = math.max(height, 8)
	local thumbH = math.max(8, height * upShown / upTotal)
	local pos = (height - thumbH) * upOffset / math.max(upTotal - upShown, 1)
	bar.thumb:SetHeight(thumbH)
	bar.thumb:ClearAllPoints()
	bar.thumb:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -pos)
	local mouseover = ns.db.upcomingScrollbarMouseover and true or false
	if not mouseover then bar:SetAlpha(1) end -- in mouseover mode the fade (hoverCheck) sets it
	if bar.watching ~= mouseover then
		bar.watching = mouseover
		bar:SetScript("OnUpdate", mouseover and hoverCheck or nil)
	end
	bar:Show()
end

local function layoutContents(self)
	local entries = upcomingWindow(entriesOf())
	wipe(upRows)
	local owner = GameTooltip:GetOwner()
	local hovered = owner and pointedAt(owner)
	rowPool:ReleaseAll()
	linePool:ReleaseAll()
	wipe(view.rows)
	separator:Hide()
	if upcoming then upcoming:Hide() end
	local fv = forever()
	wantBack = not fv
	-- Forever Style uses the Upcoming Steps header; the divider line if it could not be built
	local useHeader = fv and upcomingReady()
	local folded = useHeader and ns.db.upcomingCollapsed
	local shown, lane = 0, nil
	-- the RXP Tracker's own collapse button folds the current step(s) only: the Upcoming Steps stay (with their own
	-- collapse button). An empty spacer row keeps the module laid out and holds the Upcoming Steps header.
	if ns.db.currentCollapsed then
		local kept = {}
		for _, entry in ipairs(entries) do if not entry.active then kept[#kept + 1] = entry end end
		entries = kept
		local spacer = beginRow(1, 0)
		spacer:SetHeader("")
		if spacer.Number then spacer.Number:SetText("") end
		if spacer.Info then spacer.Info:Hide() end
		-- a pooled row may have been a current step: its "mark done" check goes with the folded steps
		local done = rawget(spacer, "Done")
		if done then done:Hide() end
		spacer.height = useHeader and upcomingHeight() or 1
		if self:LayoutBlock(spacer) then
			if useHeader then placeUpcoming(spacer, "TOPLEFT") end
		else
			rowPool:Release(spacer)
		end
	end
	local last = self:IsCollapsed() and math.min(#entries, 1) or #entries
	for index = 1, last do
		local entry = entries[index]
		-- Forever Style, upcoming steps folded: only their header shows, under the last current step
		if folded and not entry.active then break end
		local previous = index > 1 and entries[index - 1].active and not entry.active and view.rows[index - 1]
		-- the header goes at the bottom of the last current step (its height grows by the header), so the first
		-- upcoming step's "Step N" heading starts below it
		local headerBelow = useHeader and entry.active and index < last and not entries[index + 1].active
		local scale, moveX, moveY = groupLook(entry.active)
		local firstOfGroup = index == 1 or (entries[index - 1].active and not entry.active)
		if index == 1 and ns.db.currentCollapsed then firstOfGroup = true end
		local row = beginRow(scale, moveX)
		lane = lane or laneWidth(entries, row)
		local gap = previous and not useHeader and separator:GetHeight() + 2 * (headerSize(row) * DIVIDER_PAD)
		layoutRow(row, entry, lane, gap or nil)
		-- the Upcoming Steps header below is not scaled with the row: its room in row units
		if headerBelow then row.height = row.height + upcomingHeight() / scale end
		if not self:LayoutBlock(row) then
			rowPool:Release(row)
			break
		end
		settleRow(row, scale, moveY, firstOfGroup)
		if headerBelow then placeUpcoming(row.usedLines[#entry.lines]) end
		if previous and not useHeader then placeSeparator(previous.usedLines[#entries[index - 1].lines], row) end
		shown = index
		view.rows[index] = row
		-- the wheel over an upcoming step scrolls the upcoming steps; current steps leave it to the tracker
		wheelOn(row, not entry.active)
		if not entry.active then upRows[#upRows + 1] = row end
	end
	view.shown = shown
	if upcoming then wheelOn(upcoming, upTotal > 0) end
	placeUpBar()
	-- the back-one-step box is RXP Style only: Forever Style hides one left from before the switch (its < > header
	-- buttons step instead)
	if wantBack or fv then ns.hideBackButton() end
	wantBack = false
	if hovered and not select(2, pointedAt(owner)) then ns.releaseTooltip(GameTooltip, owner) end
	self.bottomSpacing = shown > 0 and BOTTOM_TRIM or 0
end

-- CONSTRAINT: private pools: ObjectiveTrackerManager's shared pools would taint (Manager.lua AcquireFrame).
function ns.attachRows(trackerModule, currentEntries)
	module, entriesOf = trackerModule, currentEntries
	view.module = module
	-- The header's collapse button folds the current step(s), not the whole module (Blizzard's collapse would hide
	-- the Upcoming Steps too: a collapsed module adds no blocks). ToggleCollapsed is what the button calls
	-- (ObjectiveTrackerModuleHeaderMixin:OnToggle); the module itself is ours.
	if module.IsCollapsed and module:IsCollapsed() and module.SetCollapsed then module:SetCollapsed(false) end
	module.ToggleCollapsed = function(self)
		ns.db.currentCollapsed = not ns.db.currentCollapsed
		if self.Header and self.Header.SetCollapsed then self.Header:SetCollapsed(ns.db.currentCollapsed) end
		ns.relayout()
	end
	if module.Header and module.Header.SetCollapsed then module.Header:SetCollapsed(ns.db.currentCollapsed and true or false) end
	rowPool = CreateFramePool("Frame", module.ContentsFrame, "ObjectiveTrackerBlockTemplate")
	linePool = CreateFramePool("Frame", module.ContentsFrame, module.lineTemplate)
	module.LayoutContents = layoutContents
	measure = module:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
	measure:Hide()
	separator = module.ContentsFrame:CreateTexture(nil, "ARTWORK")
	separator:SetAtlas(DIVIDER_ATLAS, true)
	module:HookScript("OnHide", function()
		local owner = GameTooltip:GetOwner()
		if owner and pointedAt(owner) then ns.releaseTooltip(GameTooltip, owner) end
	end)
end
