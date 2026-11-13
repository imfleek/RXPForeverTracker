local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp

local PORTRAIT_LIMIT = 30
local USE_ATTRIBUTES = {"type", "item", "spell", "toy", "macrotext"}
local TARGET_LISTS = {"friendlyTargetButtons", "enemyTargetButtons"}
local ARM_SECONDS = 3

local view = {rows = {}, shown = 0}
ns.view = view
-- CONSTRAINT: the add-on's hovers use a tooltip of its own, never the shared GameTooltip (taint). The first hover
-- builds it: GameTooltipTemplate expands to about 50 widgets.
local ownTooltip

function ns.getTooltip()
	ownTooltip = ownTooltip or CreateFrame("GameTooltip", "AllObjectivesRXPTooltip", UIParent, "GameTooltipTemplate")
	return ownTooltip
end

function ns.tooltipOwnedBy(owner)
	return ownTooltip ~= nil and ownTooltip:GetOwner() == owner
end

function ns.hideTooltip()
	if ownTooltip then ownTooltip:Hide() end
end

function ns.releaseOwnTooltip(owner)
	if ownTooltip then ns.releaseTooltip(ownTooltip, owner) end
end

local buttons, wantedUnits = {}, {}
local portraits = ns.newPortraits(PORTRAIT_LIMIT)

function ns.addWantedUnits(set, uses, count)
	for index = 1, count or #uses do
		local use = uses[index]
		if use.type == "unit" then set[use.name] = true end
	end
end

function ns.setWantedUnits(entries)
	wipe(wantedUnits)
	if not entries then return end
	for _, entry in ipairs(entries) do
		for _, line in ipairs(entry.lines) do
			if line.uses then ns.addWantedUnits(wantedUnits, line.uses) end
		end
	end
end

-- CONSTRAINT: out of combat only, the button is protected.
local function attachPortrait(button, use)
	local name = use.type == "unit" and use.name or nil
	local portrait = name and portraits:get(name)
	portraits:attach(button, portrait, button)
	ns.setMark(button, use, portrait)
end

local function bindPortrait(token, redraw)
	local name = token and RXP.GetUnitName(token)
	if not (name and wantedUnits[name]) then return end
	local combat = InCombatLockdown()
	if combat and not portraits:get(name) then return end
	local portrait, new = portraits:acquire(name)
	if redraw or new then SetPortraitTexture(portrait, token) end
	portrait.seen = GetTime()
	if combat or portrait.button then return end
	for _, button in ipairs(buttons) do
		local use = button.use
		if use and button:IsShown() and use.type == "unit" and use.name == name then
			attachPortrait(button, use)
			return
		end
	end
end

function ns.bindLive()
	if next(wantedUnits) then ns.eachLiveUnit(bindPortrait) end
end

local function rxpTargetSlot(name)
	local frame = RXP.targeting.activeTargetFrame
	if not frame then return end
	for _, key in ipairs(TARGET_LISTS) do
		for index, button in ipairs(frame[key]) do
			local targetData = button.targetData
			if button:IsShown() and targetData and targetData.name == name then return targetData.kind, index end
		end
	end
end

-- CONSTRAINT: RestedXP marks only units its target frame lists, by list index (Targeting.lua GetMarkerIndex).
-- Any other unit, e.g. a quest giver already talked to, is targeted without a marker.
local function configureTarget(button, name, kind)
	local rxpKind, index = rxpTargetSlot(name)
	local marking = index and ns.rxpProfile()[rxpKind == "friendly" and "enableTargetMarking" or "enableEnemyMarking"]
	RXP.targeting:ConfigureTargetButton(button, name, rxpKind or kind, index or 1, marking)
end

local function armed(button)
	return button.armedAt ~= nil and GetTime() - button.armedAt <= ARM_SECONDS
end

local function addConfirmHint(tooltip, button, what)
	tooltip:AddLine((armed(button) and "Click again to " or "Click twice to ") .. what, 0.6, 0.6, 0.6)
end

local function buttonEnter(button)
	local use = button.use
	local tooltip = ns.getTooltip()
	tooltip:SetOwner(button, "ANCHOR_RIGHT")
	if use.type == "unit" then
		tooltip:AddLine(ns.paint(use.name, use.kind == "friendly" and "RXP_FRIENDLY_" or "RXP_ENEMY_"))
		if use.useItem then tooltip:AddLine("Use " .. (use.useItemName or use.useItem) .. " on " .. use.name) end
	elseif use.type == "destroy" then
		tooltip:SetItemByID(use.id)
		tooltip:AddLine(" ")
		tooltip:AddLine(ns.paint(string.format("Destroy: %d in your bags", C_Item.GetItemCount(use.id)), "RXP_WARN_"))
		addConfirmHint(tooltip, button, "throw every one away")
	elseif use.type == "abandon" then
		tooltip:AddLine(ns.paint("Abandon: " .. (C_QuestLog.GetTitleForQuestID(use.id) or use.id), "RXP_WARN_"))
		addConfirmHint(tooltip, button, "abandon this quest")
	elseif use.type == "spell" then
		tooltip:SetSpellByID(use.id)
	elseif use.type == "toy" then
		tooltip:SetToyByItemID(use.id)
	elseif use.type == "macro" then
		tooltip:AddLine(use.name)
	else
		tooltip:SetItemByID(use.id)
	end
	tooltip:AddLine("Ctrl+drag: move these buttons. Ctrl+right-drag: resize them.", 0.6, 0.6, 0.6, true)
	tooltip:Show()
end

local function updateCooldown(button)
	local use, start, duration = button.use, nil, nil
	if use.type == "spell" then
		local info = C_Spell.GetSpellCooldown(use.id)
		if info then start, duration = info.startTime, info.duration end
	-- CONSTRAINT: a combo circle keeps its item's cooldown: the swipe tracks the /use the click ends with.
	elseif use.useItem then
		start, duration = ns.itemCooldown(use.useItem)
	elseif use.type == "item" or use.type == "toy" then
		start, duration = ns.itemCooldown(use.id)
	end
	-- CONSTRAINT: a secret cooldown says nothing about the swipe on screen: it stays as it is.
	if ns.isSecret(start) or ns.isSecret(duration) then return end
	if not (start and duration) then start, duration = 0, 0 end
	-- CONSTRAINT: only a change is set: setting the same cooldown again restarts its swipe.
	if start == button.cooldownStart and duration == button.cooldownDuration then return end
	button.cooldownStart, button.cooldownDuration = start, duration
	if duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	else
		button.cooldown:Clear()
	end
end

local function resetCooldown(button)
	if (button.cooldownDuration or 0) > 0 then button.cooldown:Clear() end
	button.cooldownStart, button.cooldownDuration = nil, nil
end

function ns.updateCooldowns(list)
	for _, button in ipairs(list) do
		if button.use and button:IsShown() then updateCooldown(button) end
	end
end

local function updateButtonCooldowns()
	ns.updateCooldowns(buttons)
end

local function setArmed(button, on)
	ns.paintArmed(button, on)
	if ns.tooltipOwnedBy(button) and button.use then button:GetScript("OnEnter")(button) end
end

-- CONSTRAINT: an item the client asks to confirm (uncommon or better) stays on the cursor; the loop stops there.
local function destroyAll(id)
	if GetCursorInfo() then ClearCursor() end
	for bag = BACKPACK_CONTAINER, NUM_BAG_FRAMES do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			if C_Container.GetContainerItemID(bag, slot) == id then
				C_Container.PickupContainerItem(bag, slot)
				DeleteCursorItem()
				if GetCursorInfo() then return end
			end
		end
	end
end

-- CONSTRAINT: AbandonQuest takes no quest: it leaves the one SetAbandonQuest took from the selection, as in Blizzard's
-- own flow (QuestMapQuestOptions_AbandonQuest), which gives the selection back before its popup is answered. The quest
-- read back must be the one asked for, so a selection that did not take can never leave another quest. Blizzard's popup
-- is not shown: StaticPopup_Show would run under this add-on's taint.
local function abandonQuest(questID)
	if not ns.canAbandon(questID) then return end
	local selected = C_QuestLog.GetSelectedQuest()
	C_QuestLog.SetSelectedQuest(questID)
	C_QuestLog.SetAbandonQuest()
	local target = C_QuestLog.GetAbandonQuest()
	C_QuestLog.SetSelectedQuest(selected)
	if target == questID then C_QuestLog.AbandonQuest() end
end

-- CONSTRAINT: not a secure action: deleting from the bags and leaving a quest are plain API, so they run from a script
-- hook. A button keeps its use through combat, when the bags and the quest log may change under it: each act checks
-- again.
local ACTS = {destroy = destroyAll, abandon = abandonQuest}

local function confirmClick(button, mouseButton, down)
	local use = button.use
	local act = use and ACTS[use.type]
	if IsControlKeyDown() then return end -- Ctrl: moving the buttons (Ctrl-click does no action)
	if down or mouseButton ~= "LeftButton" or not act then return end
	if armed(button) then
		setArmed(button, false)
		act(use.id)
		ns.invalidate()
		return
	end
	button.armedAt = GetTime()
	setArmed(button, true)
	local stamp = button.armedAt
	C_Timer.After(ARM_SECONDS, function()
		if button.armedAt == stamp then setArmed(button, false) end
	end)
end

-- Ctrl+left-drag moves every step button together (one saved offset from their place beside the steps, so they
-- still follow the steps while the list scrolls); Ctrl+right-drag resizes them (drag up: larger, down: smaller).
-- Out of combat only: the game does not let an addon move or resize a secure button in combat.
local MIN_SIZE, MAX_SIZE, SIZE_PER_PIXEL = 0.5, 3, 1 / 120

local function circleOffset()
	local offset = ns.db.circleOffset
	if type(offset) ~= "table" then return 0, 0 end
	return tonumber(offset[1]) or 0, tonumber(offset[2]) or 0
end

local function circleSize()
	return math.min(math.max(tonumber(ns.db.circleScale) or 1, MIN_SIZE), MAX_SIZE)
end

local function cursor()
	local scale = UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	return x / scale, y / scale
end

local dragger = CreateFrame("Frame")
dragger:Hide()
dragger:SetScript("OnUpdate", function(self)
	if InCombatLockdown() or not IsMouseButtonDown(self.mouseButton) then
		self:Hide()
		return
	end
	local x, y = cursor()
	if self.mouseButton == "RightButton" then
		local size = self.startSize * (1 + (y - self.cursorY) * SIZE_PER_PIXEL)
		ns.db.circleScale = math.min(math.max(size, MIN_SIZE), MAX_SIZE)
	else
		ns.db.circleOffset = {self.startX + x - self.cursorX, self.startY + y - self.cursorY}
	end
	ns.sync()
end)

local function startDrag(_, mouseButton)
	if not IsControlKeyDown() then return end
	if InCombatLockdown() then
		ns.say("the step buttons cannot be moved or resized in combat.")
		return
	end
	dragger.mouseButton = mouseButton == "RightButton" and "RightButton" or "LeftButton"
	dragger.cursorX, dragger.cursorY = cursor()
	dragger.startX, dragger.startY = circleOffset()
	dragger.startSize = circleSize()
	ns.hideTooltip()
	dragger:Show()
end

-- /qt: back to their place beside the steps and their normal size
function ns.resetCircleOffset()
	ns.db.circleOffset, ns.db.circleScale = nil, nil
	ns.sync()
end

-- CONSTRAINT: created out of combat (onSync returns in combat). With Ctrl held the secure click does nothing: the
-- modified type ("ctrl-type*") is found before "type" and names no action.
local function newButton()
	local button = ns.newSecureButton()
	ns.buildButtonRing(button)
	ns.buildCircleArt(button, button, UIParent)
	button:SetAttribute("ctrl-type*", "noop")
	button:RegisterForDrag("LeftButton", "RightButton")
	button:SetScript("OnDragStart", startDrag)
	button:SetScript("OnEnter", buttonEnter)
	button:SetScript("OnLeave", ns.hideTooltip)
	button:HookScript("OnClick", confirmClick)
	return button
end

local function sizeButton(button, size)
	if button.size == size then return end
	button.size = size
	button:SetSize(size, size)
	ns.sizeCircle(button, size)
end

local function clearAttributes(button)
	for _, key in ipairs(USE_ATTRIBUTES) do button:SetAttribute(key, nil) end
end

-- CONSTRAINT: no portrait here: the arrow's buttons (Arrow.lua) use this alone and must not take a unit's portrait.
local function setAction(button, use)
	clearAttributes(button)
	if use.type == "unit" then
		configureTarget(button, use.name, use.kind)
		if use.useItem then
			-- CONSTRAINT: one click targets the unit then uses the step's item (Uses.lua combineUses): the /use
			-- line rides the same secure macro button, so the combat rules stay the target button's.
			local macro = button:GetAttribute("macrotext")
			button:SetAttribute("macrotext", (macro or "") .. "\n/use item:" .. use.useItem)
		end
	elseif use.type == "macro" then
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", use.text)
	elseif use.type == "spell" then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", C_Spell.GetSpellName(use.id) or use.id)
	elseif use.type == "toy" then
		button:SetAttribute("type", "toy")
		button:SetAttribute("toy", use.id)
	elseif use.type == "item" then
		button:SetAttribute("type", "item")
		button:SetAttribute("item", "item:" .. use.id)
	end
	local previous = button.use
	button.use = use
	if not previous or previous.type ~= use.type or previous.id ~= use.id or previous.name ~= use.name
		or previous.useItem ~= use.useItem then
		resetCooldown(button)
		setArmed(button, false)
	end
	button.icon:SetTexture(ns.drawsIcon(use) and (use.icon or ns.FALLBACK_ICON) or nil)
	button.cross:SetShown(ACTS[use.type] ~= nil)
end

local function clearAction(button)
	clearAttributes(button)
	local previous = button.use
	button.use = nil
	setArmed(button, false)
	resetCooldown(button)
	button.icon:SetTexture(nil)
	button.cross:Hide()
	if previous and ns.tooltipOwnedBy(button) then
		ns.hideTooltip()
		button:GetScript("OnEnter")(button)
	end
end

local function placeButtons(slots, count)
	local right, top = slots:GetRight(), slots:GetTop()
	if not right then return count end
	local scale = ns.relativeScale(slots)
	local factor = circleSize()
	local size, step = slots.size * factor, (slots.size + slots.gap) * factor
	local strata = view.module:GetFrameStrata()
	local offsetX, offsetY = circleOffset()
	-- the tracker's general opacity (/qt Advanced)
	local trackerApi = root.tracker and root.tracker.api
	local alpha = trackerApi and trackerApi.guideTrackerAlpha and trackerApi.guideTrackerAlpha() or 1
	for index, use in ipairs(slots.uses) do
		count = count + 1
		local button = buttons[count] or newButton()
		buttons[count] = button
		setAction(button, use)
		attachPortrait(button, use)
		local column, line = (index - 1) % slots.columns, math.floor((index - 1) / slots.columns)
		local x = (right - column * step - size / 2) * scale + offsetX
		local y = (top - line * step - size / 2) * scale + offsetY
		if x ~= button.x or y ~= button.y then
			button.x, button.y = x, y
			button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		end
		sizeButton(button, size * scale)
		button:SetFrameStrata(strata)
		button:SetFrameLevel(slots:GetFrameLevel() + 2)
		button.cooldown:SetFrameStrata(strata)
		button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
		button:SetAlpha(alpha)
		button.cooldown:SetAlpha(alpha)
		button:Show()
		button.cooldown:Show()
		updateCooldown(button)
	end
	return count
end

ns.onSync(function()
	if InCombatLockdown() then return end
	local count = 0
	for index = 1, view.shown do
		local row = view.rows[index]
		if row:IsVisible() then
			for _, line in ipairs(row.usedLines) do
				local slots = line.Slots
				if slots and slots:IsShown() then count = placeButtons(slots, count) end
			end
		end
	end
	for index = count + 1, #buttons do
		local button = buttons[index]
		ns.hideCircle(button, button.cooldown)
	end
	if count > 0 then ns.bindLive() end
end)

ns.setAction, ns.clearAction, ns.updateCooldown, ns.buttonEnter = setAction, clearAction, updateCooldown, buttonEnter
ns.confirmClick, ns.useAttributes = confirmClick, USE_ATTRIBUTES

ns.onUnitSighting(bindPortrait)
ns.listen({
	UI_SCALE_CHANGED = ns.relocate,
	DISPLAY_SIZE_CHANGED = ns.relocate,
	SPELL_UPDATE_COOLDOWN = updateButtonCooldowns,
	BAG_UPDATE_COOLDOWN = updateButtonCooldowns,
})
