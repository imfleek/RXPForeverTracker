-- Quest block extras: experience reward after the quest title, gold reward before it, and spacing between quests.
--
-- The reward text is added to the title text of Blizzard's quest block with a SetText post-hook (the original title is
-- remembered and put back when an option is switched off). Spacing changes the quest module's own block-offset field.
-- Both are written without Blizzard's Forever tracker source: if a field or reward function does not exist in the
-- client, that part silently does nothing (see /qt debug).
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api
local db
local applying = false
local schedule, itemButtonOf, prepareText, repRewards
local hooked = {}
local baseSpacing -- the module's own value, captured before we touch it
local baseOffsetX -- the module's own blockOffsetX (left inset of quest titles and objectives), likewise

local function isSecret(v) return issecretvalue and issecretvalue(v) or false end

-- Classic-style quest functions (GetNumQuestLogRewards, GetQuestLogRewardInfo, ...) read the quest selected in the
-- quest log. The tooltip selects the hovered quest for the duration of the read and puts the old selection back.
local function withSelected(questID, fn)
	local C = C_QuestLog
	if C and C.GetSelectedQuest and C.SetSelectedQuest then
		local old = C.GetSelectedQuest()
		C.SetSelectedQuest(questID)
		local ok, a, b, c2 = pcall(fn)
		if old then C.SetSelectedQuest(old) end
		if ok then return a, b, c2 end
		return
	end
	if GetQuestLogSelection and SelectQuestLogEntry then
		local index = C and C.GetLogIndexForQuestID(questID)
		if not index then return end
		local old = GetQuestLogSelection()
		SelectQuestLogEntry(index)
		local ok, a, b, c2 = pcall(fn)
		SelectQuestLogEntry(old or 0)
		if ok then return a, b, c2 end
	end
end

local ALT = { GetQuestLogRewardMoney = { "GetQuestLogRewardMoney", "GetRewardMoney" }, GetQuestLogRewardXP = { "GetQuestLogRewardXP", "GetRewardXP" } }
local function call(name, questID, allowSelect)
	for _, n in ipairs(ALT[name] or { name }) do
		local fn = (C_QuestLog and C_QuestLog[n]) or _G[n]
		if type(fn) == "function" then
			local ok, value = pcall(fn, questID)
			if ok and type(value) == "number" and not isSecret(value) and value > 0 then return value end
		end
	end
	if allowSelect then -- tooltip only: never from the tracker refresh (selection changes fire quest-log events)
		local fn = _G[name]
		if type(fn) == "function" then
			local value = withSelected(questID, fn)
			if type(value) == "number" and not isSecret(value) then return value end
		end
	end
end

-- Money text: coloured numbers with g / s / c, or with the game's coin icons ("Show coins instead"): "40(s) 43(c)",
-- each icon right against its number, one space after each icon but the last.
-- CONSTRAINT: the coin images have an empty border around the coin, which showed as a gap on both sides of every
-- icon (user screenshot, 2.6.3: "(vendor 40 (s) 43 (c) )"). The image is cropped to the coin: texture coordinates
-- 2..14 of 16 on both axes (a fraction of the image, so its pixel size does not matter), drawn at the text height.
local function coin(file) return "|TInterface\\MoneyFrame\\" .. file .. ":0:0:0:0:16:16:2:14:2:14|t" end
local COIN = { g = coin("UI-GoldIcon"), s = coin("UI-SilverIcon"), c = coin("UI-CopperIcon") }
-- coins: true/false to choose; nil follows "Show coins instead" (titles). Tooltips pass db.tooltipCoins.
-- spaced: a space between the number and its coin icon (the Prerequisite Journal)
local function gold(copper, coins, spaced)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if coins == nil then coins = db and db.goldCoins end
	local function unit(letter) return coins and ("|r" .. (spaced and " " or "") .. COIN[letter]) or (letter .. "|r") end
	local out = {}
	if g > 0 then out[#out + 1] = "|cffffd700" .. g .. unit("g") end
	if s > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. unit("s") end
	if c > 0 then out[#out + 1] = "|cffeda55f" .. c .. unit("c") end
	return table.concat(out, " ")
end
-- the tooltips' own coin setting
local function tipGold(copper)
	return gold(copper, db.tooltipCoins and true or false)
end
api.tipGold = function(copper) return tipGold(copper) end

-- "xp" text or the addon's own experience orb icon ("Show xp orb").
local XP_ORB = "|TInterface\\AddOns\\" .. ADDON .. "\\Textures\\XPOrb:0:0:1:0|t"
-- tooltips: the orb right after the number, no gap
local XP_ORB_TIGHT = "|TInterface\\AddOns\\" .. ADDON .. "\\Textures\\XPOrb:0:0:0:0|t"

local function iconSize() return math.floor(14 * ((db and db.iconScale) or 1) + 0.5) end

---------------------------------------------------------------------------------------------------------------------
-- Title icons (Elite+ markers, attunement star)
---------------------------------------------------------------------------------------------------------------------
-- CONSTRAINT (user: "icon scaling shouldn't impact the formatting"): an icon inside the text (|T or |A) makes the line
-- taller and pushes the title along as it grows. The icons are therefore their own textures, drawn over fixed slots
-- in front of the title: the title is indented by the slots' width at 100 % (SLOT px each), and each icon is centred
-- on its slot at the chosen size. "Icon size" then changes only the icons; the text, line height and the quests
-- below stay where they are (a large icon may overlap its neighbours instead).
local SLOT, SLOT_GAP = 14, 3
local STAR_ICON = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" }

local function attunementIcon(id)
	if db and db.condense and db.attunementStar ~= false and id and api.isAttunement and api.isAttunement(id) then
		return STAR_ICON
	end
end
api.attunementIcon = attunementIcon


local function applyIcon(tex, desc)
	if desc.atlas and tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, desc.atlas)
		if ok and info then tex:SetAtlas(desc.atlas); return end
	end
	tex:SetTexture(desc.file)
	local c = desc.coords
	if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) else tex:SetTexCoord(0, 1, 0, 1) end
end

-- A finished quest's check: RestedXP's skip-step tick (UI/V2/Core.lua createElementRow: two rotated strokes in an
-- 11 px box), green, drawn with textures so it stays sharp at any size. It sits on its own left of the title and its
-- icons (anchored to the title's left edge, outside it): it never moves the title. Quest titles > "Checks on
-- finished quests", with its scale and opacity.
local CHECK_TICK = { 0.27, 0.87, 0.47 }
local CHECK_STROKES = {
	{ rotation = -math.pi / 4, w = 3.5, h = 1.25, x = -1.5, y = -0.8 },
	{ rotation = math.pi / 4, w = 6, h = 1.25, x = 1, y = -0.1 },
}
local CHECK_GAP = 2
local ICON_GAP = 2 -- between the title and the icon next to it
-- the outline: the same strokes in black, a little larger, behind (as the zone header's outlined text)
local CHECK_OUTLINE = 0.55 -- in 11 px units
local function checkWidget(fs)
	local w = fs.qtsCheck
	if w then return w end
	w = CreateFrame("Frame", nil, fs:GetParent())
	w:SetFrameLevel((fs:GetParent():GetFrameLevel() or 1) + 2)
	w.strokes, w.outlines = {}, {}
	for i, def in ipairs(CHECK_STROKES) do
		local o = w:CreateTexture(nil, "BORDER")
		o:SetColorTexture(0, 0, 0, 1)
		if o.SetRotation then o:SetRotation(def.rotation) end
		w.outlines[i] = o
		local t = w:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(1, 1, 1, 1)
		if t.SetRotation then t:SetRotation(def.rotation) end
		w.strokes[i] = t
	end
	fs.qtsCheck = w
	return w
end
-- Quest titles > Checks on finished quests: its colour and opacity (false: green, at the old opacity setting)
local function checkColor()
	local c = type(db.completeCheckColor) == "table" and db.completeCheckColor or nil
	if c then return c[1], c[2], c[3], c[4] or 1 end
	return CHECK_TICK[1], CHECK_TICK[2], CHECK_TICK[3], math.min(math.max(tonumber(db.completeCheckAlpha) or 1, 0.1), 1)
end
api.checkColor = checkColor
api.CHECK_GREEN = CHECK_TICK
-- A finished quest's icons in front of its title are faded to 87 % (placeTitleIcons set them to Icon opacity)
local DONE_ICON_ALPHA = 0.87
-- show (complete) or hide the check: on top of the icon next to the title when there is one, else left of the title
local function placeCheck(fs, complete)
	if complete and (fs.qtsIconsWidth or 0) > 0 then
		local iconAlpha = math.min(math.max(tonumber(db and db.iconAlpha) or 1, 0.1), 1)
		for _, tex in ipairs(fs.qtsIcons or {}) do tex:SetAlpha(math.min(iconAlpha, DONE_ICON_ALPHA)) end
	end
	if not (complete and db and db.completeCheck ~= false) then
		if fs.qtsCheck then fs.qtsCheck:Hide() end
		return
	end
	local w = checkWidget(fs)
	local _, fontSize = fs:GetFont()
	local lineH = (type(fontSize) == "number" and fontSize > 0) and fontSize or SLOT
	local size = math.floor(iconSize() * (tonumber(db.completeCheckScale) or 1) + 0.5)
	w:SetSize(size, size)
	w:ClearAllPoints()
	if (fs.qtsIconsWidth or 0) > 0 then
		w:SetPoint("CENTER", fs, "TOPLEFT", fs.qtsNearIconX, -lineH / 2) -- on the icon next to the title
	else
		w:SetPoint("RIGHT", fs, "TOPLEFT", -CHECK_GAP, -lineH / 2)
	end
	local r, g, b, a = checkColor()
	w:SetAlpha(math.min(math.max(a, 0.1), 1))
	local outline = db.completeCheckOutline and true or false
	local unit = size / 11
	for i, def in ipairs(CHECK_STROKES) do
		local t, o = w.strokes[i], w.outlines[i]
		t:SetVertexColor(r, g, b, 1)
		t:SetSize(def.w * unit, def.h * unit)
		t:ClearAllPoints()
		t:SetPoint("CENTER", w, "CENTER", def.x * unit, def.y * unit)
		if outline then
			o:SetSize((def.w + 2 * CHECK_OUTLINE) * unit, (def.h + 2 * CHECK_OUTLINE) * unit)
			o:ClearAllPoints()
			o:SetPoint("CENTER", w, "CENTER", def.x * unit, def.y * unit)
			o:Show()
		else
			o:Hide()
		end
	end
	w:Show()
end
api.placeCheck = placeCheck

-- Puts the icons (descriptors {atlas=, file=, coords=}) left of fs's first line, outside the title, and returns ""
-- (the title needs no room for them). Textures belong to fs's parent and are reused.
local function placeTitleIcons(fs, icons)
	fs.qtsIcons = fs.qtsIcons or {}
	local pool = fs.qtsIcons
	local parent = fs:GetParent()
	local _, fontSize = fs:GetFont()
	local lineH = (type(fontSize) == "number" and fontSize > 0) and fontSize or SLOT
	local size = iconSize()
	-- Quest titles > Icon opacity
	local alpha = math.min(math.max(tonumber(db and db.iconAlpha) or 1, 0.1), 1)
	-- drawn on their own left of the title, the last one next to it (they never move the title); a finished quest's
	-- check sits on the one next to the title (placeCheck reads qtsIconsWidth and qtsNearIconX)
	local n = #icons
	for i, desc in ipairs(icons) do
		local tex = pool[i]
		if not tex then tex = parent:CreateTexture(nil, "OVERLAY"); pool[i] = tex end
		applyIcon(tex, desc)
		tex:SetSize(size, size)
		tex:SetAlpha(alpha)
		tex:ClearAllPoints()
		tex:SetPoint("CENTER", fs, "TOPLEFT", -(ICON_GAP + (n - i) * (size + SLOT_GAP) + size / 2), -lineH / 2)
		tex:Show()
	end
	for i = n + 1, #pool do pool[i]:Hide() end
	fs.qtsIconsWidth = n > 0 and (ICON_GAP + n * size + (n - 1) * SLOT_GAP) or 0
	fs.qtsNearIconX = -(ICON_GAP + size / 2) -- the centre of the icon next to the title (the check sits on it)
	return "" -- the title keeps its place (nothing to make room for)
end
api.placeTitleIcons = placeTitleIcons
local function hideTitleIcons(fs)
	for _, tex in ipairs(fs and fs.qtsIcons or {}) do tex:Hide() end
	if fs then fs.qtsIconsWidth = 0 end
	if fs and fs.qtsCheck then fs.qtsCheck:Hide() end
end
api.hideTitleIcons = hideTitleIcons

local ICONS = {
	dungeon = { atlas = "Dungeon", file = "Interface\\Minimap\\Dungeon" },
	raid = { atlas = "Raid", file = "Interface\\Minimap\\Raid" },
	pvp = { file = "Interface\\TargetingFrame\\UI-PVP-Horde", coords = { 0, 40 / 64, 0, 40 / 64 } },
	skull = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
}
local function getIcons() return ICONS end
local TAG_ID = { group = 1, pvp = 41, raid = 62, dungeon = 81 } -- Classic quest tag IDs, used when no Enum is present

-- Elite -> skull, group quests -> [+N]; the matching "[Elite]" / "[60+]" tag in the title is tidied.
local function classifier(questID)
	local tag = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID)
	if type(tag) ~= "table" then return nil end
	local name = type(tag.tagName) == "string" and not isSecret(tag.tagName) and tag.tagName or ""
	local lower = name:lower()
	local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
	local info = logIndex and C_QuestLog.GetInfo(logIndex)
	local size = info and tonumber(info.suggestedGroup) or 0
	local enum = Enum and Enum.QuestTag or {}
	local id = tag.tagID
	local function is(word, enumKey)
		return lower:find(word, 1, true) ~= nil or (id ~= nil and (id == enum[enumKey] or id == TAG_ID[word]))
	end
	if is("raid", "Raid") then return getIcons().raid, name end
	if is("dungeon", "Dungeon") then return getIcons().dungeon, name end
	if is("pvp", "PvP") then return getIcons().pvp, name end
	local isElite = lower:find("elite", 1, true) ~= nil
		or (Enum and Enum.QuestTag and Enum.QuestTag.Elite and tag.tagID == Enum.QuestTag.Elite)
	local isGroup = lower:find("group", 1, true) ~= nil or size > 1
		or (Enum and Enum.QuestTag and Enum.QuestTag.Group and tag.tagID == Enum.QuestTag.Group)
	if isElite then return getIcons().skull, name end
	if isGroup then return ("|cffff8040[+%s]|r"):format(size > 1 and size or "?"), name end
end

local function stripTag(text, tagName)
	-- "[Elite] Title", "[60 Elite] Title" or "[60+] Title" -> "Title" / "[60] Title"
	local inner, rest = text:match("^%[([^%]]*)%]%s*(.*)$")
	if not inner then return text end
	local level = inner:match("^(%d+)%+?")
	if level and (inner:find("+", 1, true) or (tagName ~= "" and inner:lower():find(tagName:lower(), 1, true))) then
		return "[" .. level .. "] " .. rest
	end
	if tagName ~= "" and inner:lower():find(tagName:lower(), 1, true) then return rest end
	return text
end

local function questIDOf(block)
	local id = block.id or block.questID
	return type(id) == "number" and id or nil
end

local measurer
local function measureInit(fs)
	if not measurer then
		measurer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		measurer:Hide()
	end
	local font, size, flags = fs:GetFont()
	if font and size then measurer:SetFont(font, size, flags) end
end
local function indentFor(fs, markerText)
	measureInit(fs)
	measurer:SetText(markerText)
	local w = measurer:GetStringWidth() or 12
	measurer:SetText(" ")
	local sp = measurer:GetStringWidth()
	if not sp or sp <= 0 then sp = 3 end
	return string.rep(" ", math.ceil((w + 4) / sp) + 1) -- +1: a space after the icon
end

local function markerLabel(block, fs)
	if not block.qtsMarker then
		block.qtsMarker = block:CreateFontString(nil, "OVERLAY")
		block.qtsMarker:SetJustifyH("LEFT")
	end
	local label = block.qtsMarker
	local font, size, flags = fs:GetFont()
	if font and size then label:SetFont(font, size, flags) end
	label:ClearAllPoints()
	label:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
	return label
end

-- CONSTRAINT: Blizzard sets a title again with the text it currently shows (hovering quests re-applies the
-- highlighted title), which already holds what render() added; taken as the new base, every hover appended the
-- rewards once more ("390xp 390xp 390xp ..."). A captured title is therefore cleaned of everything render() adds: the
-- reward suffix always starts with two spaces and a colour code, and the elite/group marker indents with spaces.
-- 2.2.7: the text Blizzard re-applies when a quest is hovered on the world map's quest list came back in a form the
-- first cleanup missed (user video), so every form of what render() appends is removed wherever it is, with any
-- spacing, coloured or not, until nothing changes.
local REWARD_PATTERNS = {
	"%s*|c%x%x%x%x%x%x%x%x%d+|r|T[^|]*XPOrb[^|]*|t|r", -- xp with the orb
	"%s*|c%x%x%x%x%x%x%x%x%d+xp|r",                    -- xp
	"%s*|c%x%x%x%x%x%x%x%x%d+|r|T[^|]*|t",             -- gold/silver/copper coins
	"%s*|c%x%x%x%x%x%x%x%x%d+[gsc]|r",                 -- gold/silver/copper letters
	"%s*|cff4cc2ff%+%d+ rep|r",                        -- reputation
	"%s*|T[^|]*XPOrb[^|]*|t",                          -- a bare orb left over
	"|T[^|]*UI%-RaidTargetingIcon_1[^|]*|t%s?",        -- the attunement star (Questie.lua)
	"%s*|T[^|]*UI%-RaidTargetingIcon_1[^|]*|t%s*",    -- the attunement star
}
local PLAIN_TAILS = { "%s+%d+xp$", "%s+%d+[gsc]$", "%s+%+%d+ rep$" } -- the same with colour codes removed
local function baseTitle(text)
	local before
	repeat
		before = text
		for _, pattern in ipairs(REWARD_PATTERNS) do text = text:gsub(pattern, "") end
		for _, pattern in ipairs(PLAIN_TAILS) do text = text:gsub(pattern, "") end
	until text == before
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	return text
end

-- What follows a quest title: experience and gold (and rep) as switched on, in their order. Also used by the
-- "More quests" section (MoreQuests.lua). Every part starts with two spaces and a colour code (see baseTitle).
-- Experience and gold as on quest titles (the title settings: xp orb or "xp" in the xp colour, coins or g/s/c), for
-- totals that are not one quest's (the Prerequisite Journal). Nothing for zero.
function api.formatRewardTotals(xp, money, spacedCoins)
	local parts = {}
	if xp and xp > 0 then
		local c = db and db.xpColor or { 0.69, 0.53, 1 }
		local function byte(v) return math.floor((tonumber(v) or 1) * 255 + 0.5) end
		parts[#parts + 1] = ("|c%02x%02x%02x%02x%d%s|r"):format(byte(c[4]), byte(c[1]), byte(c[2]), byte(c[3]),
			math.floor(xp + 0.5), db and db.xpOrb and ("|r" .. XP_ORB) or "xp")
	end
	if money and money > 0 then parts[#parts + 1] = gold(money, nil, spacedCoins) end
	return table.concat(parts, "  ")
end

function api.rewardSuffix(id)
	if not db or not id then return "" end
	local text = ""
	for _, kind in ipairs(api.rewardOrder()) do
		if kind == "xp" then
			local xp = call("GetQuestLogRewardXP", id)
			if xp and xp > 0 then
				local c = db.xpColor or { 0.69, 0.53, 1 }
				-- |cAARRGGBB: the colour's opacity in the alpha byte
				text = text .. ("  |c%02x%02x%02x%02x%d%s|r"):format((tonumber(c[4]) or 1) * 255, c[1] * 255, c[2] * 255, c[3] * 255, xp,
					db.xpOrb and ("|r" .. XP_ORB) or "xp")
			end
		elseif kind == "rep" then
			local reps = repRewards(id)
			if reps[1] then text = text .. ("  |cff4cc2ff+%d rep|r"):format(reps[1].amount) end
		elseif kind == "gold" then
			local money = call("GetQuestLogRewardMoney", id)
			if money and money > 0 then text = text .. "  " .. gold(money) end
		end
	end
	return text
end

local function questComplete(id)
	if C_QuestLog and C_QuestLog.IsComplete then
		local ok, done = pcall(C_QuestLog.IsComplete, id)
		if ok and done ~= nil and not isSecret(done) then return done and true or false end
	end
	local index = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
	local info = index and C_QuestLog.GetInfo and C_QuestLog.GetInfo(index)
	return type(info) == "table" and info.isComplete == 1 or info and info.isComplete == true or false
end

local function render(block)
	local fs = block.HeaderText
	if not fs or not block.qtsBase then return end
	block.qtsBase = baseTitle(block.qtsBase) -- never decorate an already decorated title
	local text = block.qtsBase
	local id = questIDOf(block)
	local markerShown = false
	local slots, indent = {}, ""
	if id then
		if db.condense then
			local marker, tagName = classifier(id)
			if type(marker) == "table" then
				slots[#slots + 1] = marker
				text = stripTag(text, tagName or "")
			elseif marker then -- "[+N]" group size: text, not an icon
				local label = markerLabel(block, fs)
				label:SetText(marker)
				label:Show()
				markerShown = true
				indent = indentFor(fs, marker)
				text = stripTag(text, tagName or "")
			end
		end
		-- raid attunement quests (Questie.lua): a star, further from the title than the Elite+ icon (the icon next to
		-- the title is the one a finished quest's check sits on)
		local star = attunementIcon(id)
		if star then table.insert(slots, 1, star) end
		text = text .. api.rewardSuffix(id)
	end
	text = indent .. placeTitleIcons(fs, slots) .. text
	-- a finished quest: the green check, on its own left of the title (it does not move the text)
	placeCheck(fs, id and questComplete(id))
	if block.qtsMarker and not markerShown then block.qtsMarker:Hide() end
	-- the same title again (most tracker updates): leave the text alone, so the game has nothing to measure again
	if block.qtsLast == text and fs:GetText() == text then return end
	applying = true
	pcall(fs.SetText, fs, text)
	applying = false
	block.qtsLast = text
end

-- Experience and gold follow the order in which they were switched on.
local REWARD_KEY = { xp = "showXP", gold = "showGold" }
function api.rewardOrder()
	local order, seen = {}, {}
	for _, kind in ipairs(type(db.rewardOrder) == "table" and db.rewardOrder or {}) do
		if not seen[kind] and REWARD_KEY[kind] and db[REWARD_KEY[kind]] then
			order[#order + 1] = kind; seen[kind] = true
		end
	end
	for _, kind in ipairs({ "xp", "gold" }) do
		if db[REWARD_KEY[kind]] and not seen[kind] then order[#order + 1] = kind end
	end
	return order
end

-- Reputation rewards: Classic-style functions that read the selected quest. Read once per quest and cached, so the
-- tracker refresh does not keep changing the quest-log selection.
local repCache = {}
local function factionName(id)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, data = pcall(C_Reputation.GetFactionDataByID, id)
		if ok and type(data) == "table" and type(data.name) == "string" then return data.name end
	end
	if GetFactionInfoByID then
		local ok, name = pcall(GetFactionInfoByID, id)
		if ok and type(name) == "string" then return name end
	end
	return "Faction " .. tostring(id)
end
function repRewards(questID)
	local cached = repCache[questID]
	if cached and (#cached > 0 or GetTime() - (cached.time or 0) < 10) then return cached end
	local list = {}
	local numFn, infoFn = _G.GetNumQuestLogRewardFactions, _G.GetQuestLogRewardFactionInfo
	if type(numFn) == "function" and type(infoFn) == "function" then
		withSelected(questID, function()
			local n = numFn()
			for i = 1, (type(n) == "number" and n or 0) do
				local factionID, amount = infoFn(i)
				if type(factionID) == "number" and type(amount) == "number" and not isSecret(amount) then
					-- Blizzard's own quest window divides large values by 100 in some versions
					if amount >= 1000 and amount % 100 == 0 then amount = amount / 100 end
					list[#list + 1] = { name = factionName(factionID), amount = math.floor(amount) }
				end
			end
		end)
	end
	list.time = GetTime()
	repCache[questID] = list
	return list
end
api.repRewards = repRewards
function api.forgetRep(questID) if questID then repCache[questID] = nil else wipe(repCache) end end

function api.setReward(kind, on)
	if REWARD_KEY[kind] then db[REWARD_KEY[kind]] = on and true or false end
	local order = {}
	for _, k in ipairs(api.rewardOrder()) do if k ~= kind then order[#order + 1] = k end end
	if on then order[#order + 1] = kind end
	db.rewardOrder = order
	schedule()
end

local function hookBlock(block)
	local fs = block.HeaderText
	if hooked[block] or not fs or not fs.SetText then return end
	hooked[block] = true
	if type(fs.GetText) == "function" then
		local ok, current = pcall(fs.GetText, fs)
		if ok and type(current) == "string" and not isSecret(current) then block.qtsBase = baseTitle(current) end
	end
	hooksecurefunc(fs, "SetText", function(_, text)
		if applying or type(text) ~= "string" or isSecret(text) then return end
		if text == block.qtsLast then return end -- our own text set again: nothing new
		block.qtsBase = baseTitle(text)
		if db.showGold or db.showXP or db.condense then render(block) end
		prepareText(block.HeaderText, block)
	end)
end

-- Tooltip: quest title, level, overview text, objectives and rewards.
local tipHooked = {}
-- Vendor value of an item (sell price x count), when the item's data is loaded; asks the game to load it otherwise,
-- so the next hover shows it.
local function vendorValue(itemID, link, count)
	local key = itemID or link
	if not key then return nil end
	local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
	if type(getInfo) ~= "function" then return nil end
	local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(getInfo, key)
	if ok and type(price) == "number" and not isSecret(price) then
		return price * math.max(1, tonumber(count) or 1)
	end
	if itemID and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
end

local function itemLine(name, texture, count, quality, value)
	local text = name
	if type(quality) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local q = ITEM_QUALITY_COLORS[quality]
		text = (q.hex or "|cffffffff") .. name .. "|r"
	end
	if texture then text = "|T" .. texture .. ":16:16|t " .. text end
	if type(count) == "number" and count > 1 then text = text .. " x" .. count end
	if value and value > 0 then text = text .. "  |cffaaaaaa(vendor|r " .. tipGold(value) .. "|cffaaaaaa)|r" end
	return text
end

-- the reward lines, and the best vendor value among them ({ value, name }: what selling it brings, its count included)
local function readItems(numName, infoName, id)
	local numFn, infoFn = _G[numName], _G[infoName]
	local list = {}
	local best = { value = 0 }
	if type(numFn) ~= "function" or type(infoFn) ~= "function" then return list, best end
	local linkType = infoName == "GetQuestLogChoiceInfo" and "choice" or "reward"
	local function collect(useID)
		local ok, n = pcall(numFn, useID and id or nil)
		if not ok or type(n) ~= "number" or isSecret(n) then return end
		for i = 1, n do
			local okI, name, texture, count, quality, _, itemID = pcall(infoFn, i, useID and id or nil)
			if okI and type(name) == "string" and not isSecret(name) then
				local link
				if not useID and _G.GetQuestLogItemLink then
					local okL, value = pcall(_G.GetQuestLogItemLink, linkType, i)
					if okL and type(value) == "string" then link = value end
				end
				local id = type(itemID) == "number" and not isSecret(itemID) and itemID or nil
				local value = vendorValue(id, link, count)
				list[#list + 1] = itemLine(name, texture, count, quality, value)
				if type(value) == "number" and value > best.value then best.value, best.name = value, name end
			end
		end
	end
	collect(true)
	if #list == 0 then withSelected(id, function() collect(false) end) end
	return list, best
end

-- The last tooltip line in the game's small tooltip font; lines changed so go back to the normal font when the tooltip
-- is cleared (the game reuses its line font strings for every tooltip).
local smallened = {}
local function smallLastLine(tip)
	local name = tip.GetName and tip:GetName()
	local n = tip.NumLines and tip:NumLines()
	local fs = name and n and _G[name .. "TextLeft" .. n]
	if not (fs and fs.SetFontObject and _G.GameTooltipTextSmall) then return end
	fs:SetFontObject(_G.GameTooltipTextSmall)
	if not smallened[tip] then
		smallened[tip] = {}
		if tip.HookScript then
			pcall(tip.HookScript, tip, "OnTooltipCleared", function(self)
				local list = smallened[self]
				for i = #list, 1, -1 do
					if _G.GameTooltipText then list[i]:SetFontObject(_G.GameTooltipText) end
					list[i] = nil
				end
			end)
		end
	end
	local list = smallened[tip]
	list[#list + 1] = fs
end

local function addRewards(id)
	local tip = GameTooltip
	local xp = call("GetQuestLogRewardXP", id, true)
	local money = call("GetQuestLogRewardMoney", id, true)
	local items, bestItem = readItems("GetNumQuestLogRewards", "GetQuestLogRewardInfo", id)
	local choices, bestChoice = readItems("GetNumQuestLogChoices", "GetQuestLogChoiceInfo", id)
	if not ((xp and xp > 0) or (money and money > 0) or #items > 0 or #choices > 0) then return end
	tip:AddLine(" ")
	tip:AddLine(REWARDS or "Rewards", 1, 0.82, 0)
	if xp and xp > 0 then tip:AddLine(xp .. (db.tooltipXpOrb and XP_ORB_TIGHT or " experience"), 0.69, 0.53, 1) end
	-- the gold with the vendor value of the most valuable item reward added (what the quest is worth in gold)
	-- (only when the quest gives gold itself: no Gold line just for an item's vendor value)
	local best = bestChoice.value > bestItem.value and bestChoice or bestItem
	local total = (money or 0) + best.value
	if money and money > 0 then
		tip:AddLine("Gold: " .. tipGold(total), 1, 1, 1)
		if best.value > 0 then
			tip:AddLine(("  |cffaaaaaaincludes|r %s |cffaaaaaafrom selling %s|r"):format(tipGold(best.value), tostring(best.name)),
				1, 1, 1)
			smallLastLine(tip)
		end
	end
	if #items > 0 then
		tip:AddLine("You will receive:", 0.8, 0.8, 0.8)
		for _, item in ipairs(items) do tip:AddLine("  " .. item, 1, 1, 1) end
	end
	if #choices > 0 then
		tip:AddLine("Choose one of:", 0.8, 0.8, 0.8)
		for _, item in ipairs(choices) do tip:AddLine("  " .. item, 1, 1, 1) end
	end
end

-- The quest tooltip for any quest in the log: Blizzard's quest blocks (showTip) and the "More quests" section.
-- extra(tip), when given, adds lines before the tooltip is shown. Returns false when tooltips are off.
local lastTip -- the last quest tooltip shown, so it can be drawn again (Ctrl shows the whole chain: Questie.lua)
-- Width lock (seamless Ctrl): the tooltip is as wide as the wider of its two forms (Ctrl held and not), measured when
-- it opens, and that width is set again on every Ctrl redraw. The width is set, not added to: SetMinimumWidth
-- applies to the content (the frame adds its padding), so the content minimum is corrected once by what the frame
-- actually measures, and repeated redraws give the same width every time.
local MIN_DEFAULT = 0
local widthLocked = false
local function lockWidth(tip, target)
	if not (tip.SetMinimumWidth and target and target > 0) then tip:Show() return end
	widthLocked = true
	local guess = math.max(target - 20, 1)
	pcall(tip.SetMinimumWidth, tip, guess)
	tip:Show()
	local got = tip:GetWidth()
	if type(got) == "number" and math.abs(got - target) > 0.5 then
		pcall(tip.SetMinimumWidth, tip, math.max(guess - (got - target), 1))
		tip:Show()
	end
end

local fill -- below: the tooltip's lines
local function questTooltip(owner, id, fallbackTitle, extra, redraw)
	if not db or not db.tooltips or not id then return false end
	local tip = GameTooltip
	if redraw and lastTip and lastTip[1] == owner and lastTip[2] == id then
		-- Ctrl pressed or released: the same tooltip, in place (not re-owned, which hides and re-places it), at the
		-- width measured when it opened; only the lines change
		tip:ClearLines()
		fill(tip, id, fallbackTitle, extra)
		lockWidth(tip, lastTip.width)
		return true
	end
	lastTip = { owner, id, fallbackTitle, extra }
	tip:SetOwner(owner, "ANCHOR_LEFT")
	if tip.SetMinimumWidth then pcall(tip.SetMinimumWidth, tip, MIN_DEFAULT) end
	if api.chainTooltip and api.chainTooltip(id) and api.setChainCtrl then
		-- measure both forms: with the whole chain, then as it is now
		api.setChainCtrl(true)
		fill(tip, id, fallbackTitle, extra)
		api.setChainCtrl(false)
		tip:Show()
		local wide = tip:GetWidth() or 0
		tip:ClearLines()
		fill(tip, id, fallbackTitle, extra)
		tip:Show()
		lastTip.width = math.max(wide, tip:GetWidth() or 0)
		lockWidth(tip, lastTip.width)
	else
		fill(tip, id, fallbackTitle, extra)
		tip:Show()
	end
	return true
end

fill = function(tip, id, fallbackTitle, extra)
	local index = C_QuestLog.GetLogIndexForQuestID(id)
	local info = index and C_QuestLog.GetInfo(index)
	local title = info and info.title
	if type(title) ~= "string" or isSecret(title) then title = fallbackTitle or "Quest" end
	tip:AddLine(title, 1, 1, 1, true)
	if info and tonumber(info.level) and info.level > 0 then tip:AddLine("Level " .. info.level, 0.7, 0.7, 0.7) end
	local textFn = _G.GetQuestLogQuestText
	if index and type(textFn) == "function" then
		local ok, description, objectives = pcall(textFn, index)
		local text = ok and ((type(objectives) == "string" and objectives ~= "" and objectives) or description)
		if type(text) == "string" and text ~= "" and not isSecret(text) then
			tip:AddLine(" ")
			tip:AddLine(text, 0.9, 0.9, 0.9, true)
		end
	end
	if C_QuestLog.GetQuestObjectives then
		local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, id)
		if ok and type(objectives) == "table" and #objectives > 0 then
			tip:AddLine(" ")
			for _, o in ipairs(objectives) do
				if type(o.text) == "string" and not isSecret(o.text) and o.text ~= "" then
					local r, g, b = 1, 1, 1
					if o.finished then r, g, b = 0.5, 0.9, 0.5 end
					tip:AddLine("- " .. o.text, r, g, b, true)
				end
			end
		end
	end
	if api.addQuestieLines then pcall(api.addQuestieLines, tip, id) end -- Questie.lua, only while Questie is used
	addRewards(id)
	if db.partyProgress ~= false and api.addPartyProgress then api.addPartyProgress(tip, id) end
	if extra then extra(tip) end
end
api.showQuestTooltip = questTooltip

-- the width lock belongs to our quest tooltip only: any other use of the game tooltip starts without it
GameTooltip:HookScript("OnHide", function(self)
	if widthLocked then
		widthLocked = false
		if self.SetMinimumWidth then pcall(self.SetMinimumWidth, self, MIN_DEFAULT) end
	end
end)

-- Draw the quest tooltip again when it is still shown for the same owner (a modifier key changed).
function api.refreshQuestTooltip()
	if not lastTip then return end
	local tip = GameTooltip
	if not tip:IsShown() or tip:GetOwner() ~= lastTip[1] then return end
	questTooltip(lastTip[1], lastTip[2], lastTip[3], lastTip[4], true)
end

local function showTip(block)
	questTooltip(block, questIDOf(block), block.qtsBase)
end

-- The quest name sits on its own mouse-enabled header button in some clients, which receives the hover instead of the
-- block: every mouse-enabled child of the block (except the quest item button) shows the same tooltip.
local function hookTooltipOn(frame, block)
	if tipHooked[frame] or not frame.HookScript then return end
	tipHooked[frame] = true
	frame:HookScript("OnEnter", function() pcall(showTip, block) end)
	frame:HookScript("OnLeave", function() if db.tooltips then GameTooltip:Hide() end end)
end

local function hookTooltip(block)
	hookTooltipOn(block, block)
	local item = itemButtonOf(block)
	for _, key in ipairs({ "HeaderButton", "headerButton", "HeaderText" }) do
		local f = block[key]
		if type(f) == "table" and f.HookScript and f.IsMouseEnabled and f:IsMouseEnabled() then hookTooltipOn(f, block) end
	end
	for _, child in ipairs({ block:GetChildren() }) do
		if child ~= item and child.IsMouseEnabled and child:IsMouseEnabled() then hookTooltipOn(child, block) end
	end
end

-- Quest item buttons: on the side away from the scrollbar (Core decides the side). Blizzard re-anchors them on every
-- layout, so this runs after each tracker update. Item buttons can be protected: only moved out of combat.
function itemButtonOf(block)
	local b = block.ItemButton or block.itemButton
	if not b then
		local edge = block.rightEdgeFrame
		if edge and (edge.icon or edge.Icon or edge.SetItem or edge.HotKey) then b = edge end
	end
	return b
end

-- Blizzard re-anchors item buttons on every tracker update; the SetPoint post-hook moves them back to the left in the
-- same frame (moving them 0.1 s later made them flicker). Item buttons can be protected: then only out of combat.
local placingItem = false
local function itemMovable(item)
	return not InCombatLockdown() or not (item.IsProtected and item:IsProtected())
end
local function putLeft(item, block)
	placingItem = true
	pcall(function()
		item:ClearAllPoints()
		item:SetPoint("TOPRIGHT", block, "TOPLEFT", -4, 0)
	end)
	placingItem = false
	item.qtsSide = "left"
end
local itemHooked = setmetatable({}, { __mode = "k" })
local function hookItem(item)
	if itemHooked[item] then return end
	itemHooked[item] = true
	hooksecurefunc(item, "SetPoint", function(self)
		if placingItem then return end
		self.qtsSide = nil
		local block = self.qtsBlock
		if block and api.itemSide and api.itemSide() == "left" and itemMovable(self) then putLeft(self, block) end
	end)
end

local function placeItem(block)
	local item = itemButtonOf(block)
	if not item then return false end
	item.qtsBlock = block
	hookItem(item)
	if not item:IsShown() or not itemMovable(item) then return false end
	local side = api.itemSide and api.itemSide() or "left"
	if side == "left" then
		if item.qtsSide ~= "left" or item:GetNumPoints() ~= 1 or select(2, item:GetPoint(1)) ~= block then
			putLeft(item, block)
		end
		return false
	elseif item.qtsSide == "left" then
		item.qtsSide = nil
		return true -- let Blizzard put it back on the right with the next layout
	end
	return false
end

-- Word wrap and width for the title and objective lines. With an extra width set, a text whose width Blizzard set
-- explicitly is widened to the block width so the experience / gold text after the title is not cut off.
local function textRegions(block)
	local list = {}
	if block.HeaderText then list[#list + 1] = block.HeaderText end
	for _, key in ipairs({ "usedLines", "lines" }) do
		if type(block[key]) == "table" then
			for _, line in pairs(block[key]) do
				if type(line) == "table" and line.Text then list[#list + 1] = line.Text end
			end
		end
	end
	return list
end

-- Fit one text to its quest: with word wrap on, the text gets the room from where it starts to the right edge of the
-- quest (less the item button if that is on the right) and wraps onto more lines inside it. With word wrap off,
-- Blizzard's own widths stand (long text is cut off). This runs from SetText post-hooks, i.e. before Blizzard measures
-- the text's height for the layout, so no extra re-layout is needed (a re-layout per update broke scrolling).
function prepareText(fs, block)
	if not fs or not block or not db then return end
	local wrap = db.wordWrap and true or false
	if fs.qtsOrigWrap == nil and fs.CanWordWrap then fs.qtsOrigWrap = fs:CanWordWrap() end
	if fs.SetWordWrap then
		local want = wrap or (fs.qtsOrigWrap and true or false)
		if not fs.CanWordWrap or fs:CanWordWrap() ~= want then pcall(fs.SetWordWrap, fs, want) end
		if wrap and fs.SetMaxLines then pcall(fs.SetMaxLines, fs, 0) end
	end
	if wrap and fs:GetNumPoints() <= 1 then
		local left, blockRight = fs:GetLeft(), block:GetRight()
		if left and blockRight then
			local right = (api.itemSide and api.itemSide() == "right") and 30 or 0
			local want = (blockRight - left) - 4 - right
			if want > 20 and math.abs(fs:GetWidth() - want) > 1 then pcall(fs.SetWidth, fs, want) end
		end
	end
end

local textHooked = setmetatable({}, { __mode = "k" })
local function fitText(block)
	for _, fs in ipairs(textRegions(block)) do
		fs.qtsBlock = block -- lines are pooled and move between quests
		if not textHooked[fs] and fs ~= block.HeaderText then
			textHooked[fs] = true
			hooksecurefunc(fs, "SetText", function(self)
				if not applying then prepareText(self, self.qtsBlock) end
			end)
		end
		prepareText(fs, block)
	end
end

local wrapDirty = false

local function eachBlock(fn)
	local module = _G.QuestObjectiveTracker
	if not module or type(module.usedBlocks) ~= "table" then return end
	for _, byId in pairs(module.usedBlocks) do
		if type(byId) == "table" then
			for _, block in pairs(byId) do if type(block) == "table" then fn(block) end end
		end
	end
end

local function relayout()
	local module = _G.QuestObjectiveTracker
	if module and module.MarkDirty then pcall(securecallfunction, module.MarkDirty, module) end
	if ObjectiveTrackerFrame then
		if ObjectiveTrackerFrame.MarkDirty then pcall(securecallfunction, ObjectiveTrackerFrame.MarkDirty, ObjectiveTrackerFrame) end
		-- force a real re-layout now instead of waiting for the next quest event (opening the quest log did this)
		if ObjectiveTrackerFrame.Update then pcall(securecallfunction, ObjectiveTrackerFrame.Update, ObjectiveTrackerFrame, true) end
	end
end

local function applySpacing()
	local module = _G.QuestObjectiveTracker
	if not module or InCombatLockdown() then return end
	if baseSpacing == nil then
		baseSpacing = type(module.fromBlockOffsetY) == "number" and module.fromBlockOffsetY or false
	end
	if baseSpacing == false then return end
	local want = baseSpacing - (db.spacing or 0) -- offsets are negative going down
	if module.fromBlockOffsetY ~= want then module.fromBlockOffsetY = want; return true end
end

-- "Quest titles horizontal position": the quest module places each block (title with its objectives) blockOffsetX from
-- its left edge; db.questTitleX is added to the module's own value. Zone headers subtract it again (ZoneSort.lua,
-- MoreQuests.lua), so their own slider alone moves them. More Quests measures the blocks, so it follows.
local function applyTitleX()
	local module = _G.QuestObjectiveTracker
	if not module or InCombatLockdown() then return end
	if baseOffsetX == nil then
		baseOffsetX = type(module.blockOffsetX) == "number" and module.blockOffsetX or false
	end
	if baseOffsetX == false then return end
	local want = baseOffsetX + (tonumber(db.questTitleX) or 0)
	if module.blockOffsetX ~= want then module.blockOffsetX = want; return true end
end

-- Quest list > "Quests" header colour (its text and collapse button) and the line under it (the header's background
-- art): each a colour with opacity; nil leaves Blizzard's own. Applied on every tracker update (Blizzard may set the
-- text colour again); only when something differs.
local function tint(texture, c)
	if not texture then return end
	if c then
		texture:SetVertexColor(c[1], c[2], c[3])
		texture:SetAlpha(c[4] or 1)
	elseif texture.qtsTinted then
		texture:SetVertexColor(1, 1, 1)
		texture:SetAlpha(1)
	end
	texture.qtsTinted = c and true or nil
end
function api.applyQuestsHeaderLook()
	local module = _G.QuestObjectiveTracker
	local header = module and module.Header
	if not (header and db) then return end
	-- the line first: a failure in the text colour below must not leave it unset
	-- the line under "Quests  N/40" is the header's own art: every texture of the header frame itself (Background
	-- and anything a client adds there; not the collapse button's, not the Shine / Glow flashes)
	local line = type(db.questsLineColor) == "table" and db.questsLineColor or nil
	local text = type(db.questsHeaderColor) == "table" and db.questsHeaderColor or nil
	-- no colour chosen and nothing tinted from before: nothing to do on this update (no region list built)
	if not (line or text or header.qtsAnyTint) then return end
	header.qtsAnyTint = (line or text) and true or nil
	for _, region in ipairs({ header:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" and region ~= header.Shine and region ~= header.Glow then
			tint(region, line)
		end
	end
	if header.Text then
		if text then
			header.Text:SetTextColor(text[1], text[2], text[3], text[4] or 1)
			header.qtsTextTinted = true
		elseif header.qtsTextTinted then
			header.qtsTextTinted = nil
			local fontObject = header.Text:GetFontObject()
			if fontObject and fontObject.GetTextColor then header.Text:SetTextColor(fontObject:GetTextColor()) end
		end
	end
	local button = header.MinimizeButton
	if button then
		tint(button.GetNormalTexture and button:GetNormalTexture(), text)
		tint(button.GetPushedTexture and button:GetPushedTexture(), text)
	end
end

local function apply()
	if not db then return end
	pcall(api.applyQuestsHeaderLook)
	local changed = false
	eachBlock(function(block)
		hookBlock(block)
		hookTooltip(block)
		if placeItem(block) then changed = true end
		fitText(block)
		local before = block.qtsBase and block.HeaderText and block.HeaderText:GetText()
		if block.qtsBase then
			if db.showGold or db.showXP or db.condense then render(block)
			else
				applying = true
				pcall(block.HeaderText.SetText, block.HeaderText, block.qtsBase)
				applying = false
				block.qtsLast = block.qtsBase
				if block.qtsMarker then block.qtsMarker:Hide() end
				hideTitleIcons(block.HeaderText)
			end
			if before ~= block.HeaderText:GetText() then changed = true end
		end
	end)
	if applySpacing() then changed = true end
	if applyTitleX() then changed = true end
	if wrapDirty then wrapDirty = false; changed = true end -- one re-layout after the option is switched
	return changed
end

local timer
function schedule()
	if timer then return end
	timer = true
	C_Timer.After(0.1, function()
		timer = nil
		xpcall(function() if apply() then relayout() end end, geterrorhandler())
	end)
end

function api.applyExtras() schedule() end
function api.applyWrap() wrapDirty = true; schedule() end
function api.placeItems() schedule() end

function api.extrasDebug(say)
	local module = _G.QuestObjectiveTracker
	say(("rewards: xp=%s gold=%s; spacing=%s (module.fromBlockOffsetY=%s, original=%s); XP function: %s, gold function: %s"):format(
		tostring(db.showXP), tostring(db.showGold), tostring(db.spacing), tostring(module and module.fromBlockOffsetY),
		tostring(baseSpacing),
		tostring((C_QuestLog and C_QuestLog.GetQuestLogRewardXP) or _G.GetQuestLogRewardXP ~= nil),
		tostring((C_QuestLog and C_QuestLog.GetQuestLogRewardMoney) or _G.GetQuestLogRewardMoney ~= nil)))
end

ns.onLogin[#ns.onLogin + 1] = function()
	db = ns.db
	-- 2.9.3: the two attunement-star options became one
	if db.attuneStar == false then db.attunementStar = false end
	db.attuneStar = nil
	db.ahValue = nil -- 3.0.1: auction house prices removed
	if ObjectiveTrackerContainerMixin then
		hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", schedule)
	end
	local frame = CreateFrame("Frame")
	for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do pcall(frame.RegisterEvent, frame, e) end
	frame:SetScript("OnEvent", function(_, event, questID)
		if event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then api.forgetRep(type(questID) == "number" and questID or nil) end
		schedule()
	end)
	schedule()
end
