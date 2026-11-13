-- "Change guide" menu: right-click on the guide in the tracker, and the header's Browse Guides button.
--
-- CONSTRAINT (RestedXP source, UI/V2/Core.lua and GuideWindow.lua): ShowSettingsMenu lists no guides at all, only the
-- step-list toggles and what follows the guide list (tips, options, "Import guide"); ShowGuideSelectionMenu keeps the
-- part of RXPFrame:GenerateMenuTable before its first blank title, which holds only groups with a guide that passes
-- IsGuideActive (level, phase, season...) and hides "unused" ("*") groups unless Show unused guides is on, so it can
-- come up with nothing but a divider. This menu takes that same guide part, and when it holds no guide it lists every
-- loadable guide from addon.guideList instead. It never offers the importer.
local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp
local L = ns.L

local function closeMenu()
	if RXP.CloseMenu then RXP:CloseMenu() end
end

-- What RestedXP's own menu entries do on click (GuideWindow.lua GenerateMenuTable OnClick).
local function loadGuide(guide)
	closeMenu()
	if not guide then return end
	local onClick = guide.OnClick
	if onClick and RXP.functions and RXP.functions[onClick] then
		RXP.functions[onClick](guide)
	else
		RXP:LoadGuide(guide)
	end
end

local function guideName(guide)
	local ok, name = pcall(RXP.GetGuideName, guide)
	return ok and name or guide.name or "?"
end

-- RestedXP's own guide list: the entries before the first blank title (as ShowGuideSelectionMenu does).
local function rxpGuideEntries()
	local ok, list = pcall(RXP.RXPFrame.GenerateMenuTable, RXP.RXPFrame, {})
	if not ok or type(list) ~= "table" then return {}, 0 end
	local entries, guides = {}, 0
	for _, item in ipairs(list) do
		if item.isTitle and item.text == "" then break end
		entries[#entries + 1] = item
		if item.menuList or item.func then guides = guides + 1 end
	end
	return entries, guides
end

-- CONSTRAINT: LoadGuide swaps a farming guide outside Gold Assistant mode (and a quest guide inside it) for the empty
-- guide when the guide is not active, so those are left out; internal, disabled and chapter guides never load.
local function loadable(guide)
	if not guide or guide.internal or guide.disabled or guide.chapter or guide.empty then return false end
	local gold = RXPCData and RXPCData.GA
	if guide.farm and not gold or not guide.farm and gold then
		return RXP.IsGuideActive(guide) and true or false
	end
	return true
end

-- Every loadable guide, grouped as RestedXP groups them (active ones first in each group).
local function allGuideEntries()
	local groups = {}
	for group, data in pairs(RXP.guideList or {}) do
		if group ~= "RXPGuides" and type(data) == "table" and type(data.names_) == "table" then
			local items = {}
			local seen = {}
			for _, identity in ipairs(data.names_) do
				local guide = RXP.GetGuideTable(identity.group, identity.name)
				if guide and not seen[guide] and loadable(guide) then
					seen[guide] = true
					local active = RXP.IsGuideActive(guide) and true or false
					items[#items + 1] = {
						text = guideName(guide) .. (active and "" or " |cff888888(not for your level)|r"),
						notCheckable = 1,
						func = function() loadGuide(guide) end,
						sortActive = active and 0 or 1,
						sortName = guideName(guide),
					}
				end
			end
			if #items > 0 then
				table.sort(items, function(a, b)
					if a.sortActive ~= b.sortActive then return a.sortActive < b.sortActive end
					return a.sortName < b.sortName
				end)
				local name = group:gsub("^[%*%+]", "")
				if RXP.GroupOverride then
					local ok, display = pcall(RXP.GroupOverride, group)
					if ok and type(display) == "string" then name = display:gsub("^[%*%+]", "") end
				end
				groups[#groups + 1] = { text = name, notCheckable = 1, hasArrow = true, menuList = items }
			end
		end
	end
	table.sort(groups, function(a, b) return a.text < b.text end)
	return groups
end

-- Where the menu opens: beside the tracker, never over the steps. RestedXP opens its menus at the cursor, and its
-- dropdown library opens every submenu to the right of its parent unless that runs off the screen
-- (LibUIDropDownMenu ToggleDropDownMenu, mirrored by Blizzard's UIDropDownMenu): with the tracker on the right of the
-- screen the guide lists landed on the steps. So the list is anchored outside the tracker through the dropdown frame's
-- own point/relativePoint/relativeTo fields (the anchor the library reads), on our own dropdown frame so RestedXP's
-- menus are untouched, and while it is open its submenus are moved to the same side.
local menuFrame, menuSide -- menuSide: "LEFT" (menu left of the tracker) or "RIGHT"
local SUBMENU_LISTS = { "DropDownList", "L_DropDownList" }

local function ourMenuOpen()
	return menuFrame and (_G.UIDROPDOWNMENU_OPEN_MENU == menuFrame or _G.L_UIDROPDOWNMENU_OPEN_MENU == menuFrame)
end

-- Submenus (level 2 and deeper) of our menu go left of their parent list when the menu sits left of the tracker.
local function placeSubmenu(level, button)
	if menuSide ~= "LEFT" or type(level) ~= "number" or level < 2 or not ourMenuOpen() then return end
	for _, prefix in ipairs(SUBMENU_LISTS) do
		local list, parent = _G[prefix .. level], _G[prefix .. (level - 1)]
		if list and parent and list:IsShown() and parent:IsShown() then
			local width = list:GetWidth() or 0
			local parentLeft, parentTop = parent:GetLeft(), parent:GetTop()
			local anchor = button and button.GetTop and button:GetParent() == parent and button or nil
			if parentLeft and parentTop and parentLeft - width > 0 then
				local dy = anchor and anchor:GetTop() and (anchor:GetTop() - parentTop) or 0
				list:ClearAllPoints()
				list:SetPoint("TOPRIGHT", parent, "TOPLEFT", 4, dy + 14)
			end
		end
	end
end

local hooked = false
local function hookSubmenus()
	if hooked then return end
	hooked = true
	if type(_G.ToggleDropDownMenu) == "function" then
		hooksecurefunc("ToggleDropDownMenu", function(level, _, _, _, _, _, _, button) placeSubmenu(level, button) end)
	end
	local lib = LibStub and LibStub("LibUIDropDownMenu-4.0", true)
	if lib and type(lib.ToggleDropDownMenu) == "function" then
		hooksecurefunc(lib, "ToggleDropDownMenu", function(_, level, _, _, _, _, _, _, button) placeSubmenu(level, button) end)
	end
end

local function getMenuFrame()
	if not menuFrame then
		local ok, frame = pcall(CreateFrame, "Frame", "RXPForeverTrackerGuideMenu", UIParent, "UIDropDownMenuTemplate")
		menuFrame = ok and frame or CreateFrame("Frame", "RXPForeverTrackerGuideMenu", UIParent)
		menuFrame:Hide()
		hookSubmenus()
	end
	return menuFrame
end

local function trackerFrame(anchor)
	if anchor and anchor.GetLeft and anchor:GetLeft() then return anchor end
	local module = ns.view and ns.view.module
	if module and module:IsVisible() and module:GetLeft() then return module end
	return ObjectiveTrackerFrame
end

function ns.showGuideMenu(anchor)
	local menu = {}
	local current = RXP.currentGuide
	menu[1] = {
		text = (current and not current.empty) and ("Current guide: " .. guideName(current)) or L("Select a guide:"),
		isTitle = 1,
		notCheckable = 1,
	}
	local entries, guides = rxpGuideEntries()
	if guides == 0 then entries = allGuideEntries() end
	for _, item in ipairs(entries) do menu[#menu + 1] = item end
	if #entries == 0 then
		menu[#menu + 1] = { text = "No RestedXP guides are loaded.", isTitle = 1, notCheckable = 1 }
	end
	menu[#menu + 1] = { text = "", notCheckable = 1, isTitle = 1 }
	menu[#menu + 1] = { text = _G.CLOSE, notCheckable = 1, func = closeMenu }

	local frame, target = getMenuFrame(), anchor ~= "cursor" and trackerFrame(anchor) or nil
	local left, right = target and target:GetLeft(), target and target:GetRight()
	if not (left and right) then
		menuSide = nil
		RXP:ShowMenu(menu) -- no tracker on screen: RestedXP's own placement (at the cursor)
		return
	end
	-- The side with more room: left of the tracker when it is on the right half of the screen.
	local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local onRight = (left + right) / 2 * scale > UIParent:GetWidth() / 2
	menuSide = onRight and "LEFT" or "RIGHT"
	frame.relativeTo = target
	frame.point = onRight and "TOPRIGHT" or "TOPLEFT"
	frame.relativePoint = onRight and "TOPLEFT" or "TOPRIGHT"
	frame.xOffset = onRight and -4 or 4
	frame.yOffset = 0
	RXP:ShowMenu(menu, frame, target, frame.xOffset, frame.yOffset)
end
