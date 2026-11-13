local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp

local NONE = {}
local HEARTH_ITEMS, HEARTH_SPELLS = {6948, 184871}, {556}
-- CONSTRAINT: RestedXP splits units by the element field a name sits in, never by tag (Targeting.lua AddUnits).
local UNIT_FIELDS = {{"targets", "friendly"}, {"mobs", "mob"}, {"unitscan", "unitscan"}}
local USE_TYPES = {"unit", "destroy", "abandon", "spell", "item", "toy", "macro"}
local WEAK = {__mode = "v"}

-- One set per kind of use, of ids or names, so that no key is a "kind:id" string built per pass.
local function newSets(metatable)
	local sets = {}
	for _, kind in ipairs(USE_TYPES) do sets[kind] = setmetatable({}, metatable) end
	return sets
end

local function emptySets(sets)
	for _, set in pairs(sets) do wipe(set) end
	return sets
end

local function once(sets, kind, key)
	local set = sets[kind]
	if set[key] then return false end
	set[key] = true
	return true
end

-- CONSTRAINT: a view pass runs on every signal RestedXP sends and must not allocate when it finds what the last one
-- found: these working sets and lists are kept between runs and emptied when a run starts. Nothing in them is read
-- after the run, and no run starts inside another.
local interned = newSets(WEAK)
local claims, emitted, placed = newSets(), newSets(), newSets()
local macroKeys, starredUses = {}, {}
local standIn, arrowLines, arrowUnits, actions, units = {}, {}, {}, {}, {}

-- CONSTRAINT: one table per distinct use, weak so that a use nothing holds any more is collected: a pass that finds
-- the same uses again allocates none. A use is never edited, only replaced: a button compares its old use with the
-- new one by field (Action.lua setAction).
local function intern(kind, id, icon, name, unitKind, text)
	local set, key = interned[kind], id or name
	local use = set[key]
	if not (use and use.icon == icon and use.name == name and use.kind == unitKind and use.text == text) then
		use = {type = kind, id = id, icon = icon, name = name, kind = unitKind, text = text,
			iconTag = icon and "|T" .. tostring(icon) .. ":"}
		set[key] = use
	end
	return use
end

local function keyOf(use)
	return use.id or use.name
end

-- CONSTRAINT: a step that both names a unit and offers an item drives one circle, not two (the historic a01d0f5
-- rule): the step's first unit and first item merge into a button whose one click targets the unit then uses the
-- item. Combined uses intern in their own two-level table (name then item id, no key strings per pass); a use is
-- never edited, only replaced, and the table rebuilds when any field differs.
local comboInterned = setmetatable({}, WEAK)

local function internCombo(unit, item)
	local name = item.name or C_Item.GetItemNameByID(item.id)
	local byUnit = comboInterned[unit.name]
	if not byUnit then
		byUnit = {}
		comboInterned[unit.name] = byUnit
	end
	local use = byUnit[item.id]
	if not (use and use.kind == unit.kind and use.useItemName == name and use.useItemIcon == item.icon) then
		use = {type = "unit", name = unit.name, kind = unit.kind, icon = unit.icon, iconTag = unit.iconTag,
			useItem = item.id, useItemName = name, useItemIcon = item.icon}
		byUnit[item.id] = use
	end
	return use
end

local function elementsOf(step)
	return step.elements or NONE
end

-- The line at `index`, emptied and given its fields; lines and their uses lists are refilled in place.
local function setLine(lines, index, frame, element, text, note, done)
	local line = lines[index]
	if line then
		if line.uses then wipe(line.uses) end
	else
		line = {}
		lines[index] = line
	end
	line.frame, line.element, line.text, line.note, line.done = frame, element, text, note, done
	return line
end
ns.setLine = setLine

-- CONSTRAINT: an active element's text is in the frame RestedXP binds to it (GuideWindow.lua BindActiveStepElement);
-- V2 rows and classic frames keep it in .text and the icon in .icon. The classic window pools those frames by position
-- and hides an element it draws no text for with alpha 0, leaving the text of an earlier step in place.
function ns.readLines(lines, step)
	local count = 0
	for _, element in ipairs(elementsOf(step)) do
		local frame = element.frame
		local body = frame and frame:GetAlpha() > 0 and frame.text and frame.text:GetText()
		if body and body ~= "" and body ~= " " then
			local icon = frame.icon and frame.icon:IsShown() and frame.icon:GetText() or ""
			local textOnly = element.textOnly
			count = count + 1
			setLine(lines, count, frame, element, icon .. body, textOnly or false,
				not textOnly and (element.completed or element.skip) or false)
		end
	end
	ns.truncate(lines, count)
	return count
end

local function addUse(line, use)
	local uses = line.uses
	if not uses then
		uses = {}
		line.uses = uses
	end
	uses[#uses + 1] = use
end

-- CONSTRAINT: starred names go after the element's unstarred ones (Targeting.lua FilterList); a unit gets one circle,
-- on the first line naming it.
local function addUnits(line, element, unitNames)
	wipe(starredUses)
	for _, field in ipairs(UNIT_FIELDS) do
		local names = element[field[1]]
		for _, unit in ipairs(type(names) == "table" and names or NONE) do
			local name = type(unit) == "string" and unit ~= "" and RXP.GetCreatureName(unit)
			local starred
			if name and name:sub(1, 1) == "*" then
				starred = true
				name = name:sub(2)
			end
			if name and not unitNames[name] then
				unitNames[name] = true
				local use = intern("unit", nil, nil, name, field[2])
				if starred then starredUses[#starredUses + 1] = use else addUse(line, use) end
			end
		end
	end
	for _, use in ipairs(starredUses) do addUse(line, use) end
end

-- CONSTRAINT: -1 is no id; a non-number first argument names another unit. RestedXP's item bar skips .cast.
local function castSpell(element)
	if element.tag ~= "cast" or element.unit ~= "player" or element.completed or element.skip then return nil end
	for _, id in ipairs(element.ids or NONE) do
		if id > 0 and ns.isPlayerSpell(id) then return id end
	end
end

-- CONSTRAINT: Blizzard offers Abandon for a quest the log holds and CanAbandonQuest allows (QuestMapFrame.lua); its
-- details button also wants the quest not disabled for the session, which is not checked here.
function ns.canAbandon(questId)
	return ns.inQuestLog(questId) and C_QuestLog.CanAbandonQuest(questId)
end

-- CONSTRAINT: RestedXP completes an .abandon element once none of its quests is in the log (functions.lua abandon); a
-- completed or skipped one asks for nothing.
local function abandonIds(element)
	return element.tag == "abandon" and not (element.completed or element.skip) and element.ids or NONE
end

function ns.stepHasAction(step)
	for _, element in ipairs(elementsOf(step)) do
		if castSpell(element) then return true end
		for _, questId in ipairs(abandonIds(element)) do
			if ns.canAbandon(questId) then return true end
		end
	end
	return false
end

local function claim(line, kind, id)
	local claimed = claims[kind]
	claimed[id] = claimed[id] or line
end

local function claimQuestItems(line, map, questId, mirror)
	local items = map and questId and map[mirror and RXP.GetQuestId(questId, nil, true) or questId]
	if type(items) == "table" then
		for _, item in pairs(items) do claim(line, "item", item) end
	elseif items then
		claim(line, "item", items)
	end
end

local function questClaim(field, mirror)
	return function(line, element)
		local map, ids = RXP[field], element.ids
		if ids then
			for _, questId in ipairs(ids) do claimQuestItems(line, map, questId, mirror) end
		else
			claimQuestItems(line, map, element.questId, mirror)
		end
	end
end

local function activeItemsClaim(kind)
	return function(line, element)
		for id in pairs(element.activeItems or NONE) do claim(line, kind, id) end
	end
end

local acceptClaim = questClaim("questAcceptItems")
local turnInClaim = questClaim("questTurnInItems", true)

-- CONSTRAINT: .hs gives the hearth items and spell (functions.lua hs); quest tags give their quests' items, turnin and
-- complete under the mirrored id (GetQuestId with checkMirror); a .collect with objective flag 0 and a quest gives
-- the item that starts it.
local CLAIMS = {
	use = activeItemsClaim("item"),
	usespell = activeItemsClaim("spell"),
	cast = function(line, element)
		local id = castSpell(element)
		if id then claim(line, "spell", id) end
	end,
	macro = function(line, element)
		if element.id then claim(line, "macro", element.id) end
	end,
	hs = function(line)
		for _, id in ipairs(HEARTH_ITEMS) do claim(line, "item", id) end
		for _, id in ipairs(HEARTH_SPELLS) do claim(line, "spell", id) end
	end,
	complete = questClaim("questCompleteItems", true),
	accept = acceptClaim,
	acceptmultiple = acceptClaim,
	daily = acceptClaim,
	turnin = turnInClaim,
	turninmultiple = turnInClaim,
	dailyturnin = turnInClaim,
	collect = function(line, element)
		if element.objFlags == 0 and element.questId and element.id then claim(line, "item", element.id) end
	end,
}

-- CONSTRAINT: RestedXP empties a .target, .mob or .unitscan element's units once its parent is completed or skipped,
-- but only when that element's own event fires (functions.lua UpdateTargets); until then the field lists the NPC.
local function unitsDropped(element)
	local parent = element.parent
	return type(parent) == "table" and (parent.completed or parent.skip)
end

local function lineOf(lines, element)
	for _, line in ipairs(lines) do
		if line.element == element then return line end
	end
	return lines[1]
end

-- CONSTRAINT: .destroy only marks junk for RestedXP's inventory manager (functions.lua destroy), which may delete or
-- sell it itself; the button throws the item away while any is left, as RestedXP completes the element at 0.
local function claimUses(step, lines, unitNames)
	local profile = ns.rxpProfile()
	emptySets(claims)
	for _, element in ipairs(elementsOf(step)) do
		local line = lineOf(lines, element)
		if profile.enableTargetFrame and not unitsDropped(element) then addUnits(line, element, unitNames) end
		if element.tag == "destroy" and element.id and C_Item.GetItemCount(element.id) > 0 then
			addUse(line, intern("destroy", element.id, C_Item.GetItemIconByID(element.id)))
		end
		for _, questId in ipairs(abandonIds(element)) do
			if ns.canAbandon(questId) then addUse(line, intern("abandon", questId)) end
		end
		local claimFor = CLAIMS[element.tag]
		if claimFor then claimFor(line, element) end
	end
end

-- CONSTRAINT: a line that shows the use's icon or names it owns it; a quest item can come from a .complete element.
local function ownerOf(lines, kind, id, iconTag, name)
	for _, line in ipairs(lines) do
		local text = line.text or ""
		if (iconTag and text:find(iconTag, 1, true)) or (name and name ~= "" and text:find(name, 1, true)) then
			return line
		end
	end
	return claims[kind][id] or lines[1]
end

local function emitSpell(lines, id)
	local use = intern("spell", id, C_Spell.GetSpellTexture(id))
	addUse(ownerOf(lines, "spell", id, use.iconTag, C_Spell.GetSpellName(id)), use)
end

local function emitItem(lines, id, toy)
	local use = intern(toy and "toy" or "item", id, C_Item.GetItemIconByID(id))
	addUse(ownerOf(lines, "item", id, use.iconTag, C_Item.GetItemNameByID(id)), use)
end

local function emitMacro(lines, key, icon, name, text)
	addUse(ownerOf(lines, "macro", key),
		intern("macro", key, (icon and icon ~= 0) and icon or ns.FALLBACK_ICON, name, nil, text))
end

local function sortedMacroKeys(macros)
	wipe(macroKeys)
	for key in pairs(macros) do macroKeys[#macroKeys + 1] = key end
	table.sort(macroKeys)
	return macroKeys
end

-- CONSTRAINT: RestedXP's V2 window wipes and aggregates the steps' active tables into its bar feed before the rows
-- bind and the tag callbacks fill them (GuideWindow.lua SetStep), so a fresh step's items are missing from the feed
-- when the bar is built; the bar keeps the filters (bags, toys, "p", known spells), and this only hands the ids over.
local function feedItemBar(step)
	local changed
	for id, arg in pairs(step.activeItems or NONE) do
		if RXP.activeItems[id] == nil then RXP.activeItems[id] = arg; changed = true end
	end
	for id, arg in pairs(step.activeSpells or NONE) do
		if RXP.activeSpells[id] == nil then RXP.activeSpells[id] = arg; changed = true end
	end
	for id, arg in pairs(step.activeMacros or NONE) do
		if RXP.activeMacros[id] == nil then RXP.activeMacros[id] = arg; changed = true end
	end
	return changed
end

-- CONSTRAINT: what the step can use is RestedXP's item bar (ActiveItemFrame.lua UpdateItemFrame: known spells, macros,
-- items worn or carried, items marked "p", toys), in its order; the step decides only which of them are its own.
-- An open .cast, which the bar never offers, is the step's objective itself and goes first.
local function emitUses(step, lines)
	emptySets(emitted)
	if feedItemBar(step) then RXP.UpdateItemFrame() end
	local items, spells, macros = step.activeItems or NONE, step.activeSpells or NONE, step.activeMacros or NONE
	for _, element in ipairs(elementsOf(step)) do
		local id = castSpell(element)
		if id and once(emitted, "spell", id) then emitSpell(lines, id) end
	end
	for _, button in ipairs(RXP.activeItemFrame.buttonList) do
		if button:IsShown() then
			local id = button.itemId
			if button.macro then
				for _, key in ipairs(sortedMacroKeys(macros)) do
					local icon, name = tostring(key):match("(%d+):(.*)")
					if name == button.name and once(emitted, "macro", key) then
						emitMacro(lines, key, tonumber(icon), name, macros[key])
					end
				end
			elseif button.spell then
				if spells[id] ~= nil and once(emitted, "spell", id) then emitSpell(lines, id) end
			elseif (items[id] or button.toy and items[id] ~= nil) and once(emitted, "item", id) then
				emitItem(lines, id, button.toy)
			end
		end
	end
end

-- CONSTRAINT: one click targets the unit then uses the item, first of each in the step's lines (the historic
-- a01d0f5 rule); the combined use takes the unit use's slot and the item use leaves the lines, so further units
-- and items keep their own circles. It needs an emitted item: with the item window off no combo forms.
local function combineUses(lines)
	local unitLine, unitIndex, itemLine, itemIndex
	for _, line in ipairs(lines) do
		local uses = line.uses
		for index = 1, uses and #uses or 0 do
			local use = uses[index]
			if not unitLine and use.type == "unit" then
				unitLine, unitIndex = line, index
			elseif not itemIndex and (use.type == "item" or use.type == "toy") then
				itemLine, itemIndex = line, index
			end
		end
	end
	if not (unitLine and itemLine) then return end
	unitLine.uses[unitIndex] = internCombo(unitLine.uses[unitIndex], itemLine.uses[itemIndex])
	table.remove(itemLine.uses, itemIndex)
	if #itemLine.uses == 0 then itemLine.uses = nil end
end

-- Puts the step's uses on its lines; `unitNames` holds the units taken already, which get one circle each.
function ns.attachUses(step, lines, unitNames)
	claimUses(step, lines, unitNames)
	if not ns.rxpProfile().disableItemWindow then emitUses(step, lines) end
	combineUses(lines)
end

-- CONSTRAINT: a step the window does not draw (#hidewindow, #hidetip, no text) still feeds RestedXP's target frame and
-- item bar (GuideWindow.lua); its uses go after the first drawn line's, via a stand-in line no element owns.
function ns.adoptHidden(steps, lines, unitNames)
	if #steps == 0 then return end
	emptySets(placed)
	for _, line in ipairs(lines) do
		for _, use in ipairs(line.uses or NONE) do once(placed, use.type, keyOf(use)) end
	end
	for _, step in ipairs(steps) do
		local carrier = setLine(standIn, 1)
		ns.attachUses(step, standIn, unitNames)
		for _, use in ipairs(carrier.uses or NONE) do
			if once(placed, use.type, keyOf(use)) then addUse(lines[1], use) end
		end
	end
end

local function collectUses(step, position)
	local lines = arrowLines[position]
	if not lines then
		lines = {}
		arrowLines[position] = lines
	end
	if ns.readLines(lines, step) == 0 then
		lines = standIn
		setLine(lines, 1)
	end
	wipe(arrowUnits)
	ns.attachUses(step, lines, arrowUnits)
	for _, line in ipairs(lines) do
		for _, use in ipairs(line.uses or NONE) do
			if once(placed, use.type, keyOf(use)) then
				local list = use.type == "unit" and units or actions
				list[#list + 1] = use
			end
		end
	end
end

-- The list is the arrow's own: it holds until the next call.
function ns.activeUses(first)
	emptySets(placed)
	wipe(actions)
	wipe(units)
	local position = 1
	collectUses(first, position)
	for _, step in ipairs(RXP.RXPFrame.activeSteps) do
		if step ~= first then
			position = position + 1
			collectUses(step, position)
		end
	end
	ns.truncate(arrowLines, position)
	for _, use in ipairs(units) do actions[#actions + 1] = use end
	return actions
end
