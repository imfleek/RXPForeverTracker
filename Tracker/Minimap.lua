-- Minimap button: left click opens the settings, right click locks/unlocks the tracker, drag to move it around the
-- minimap. No library needed.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api

local atan2 = math.atan2 or math.atan
local button

local function position()
	local angle = math.rad(ns.db.minimap.angle or 225)
	local radius = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function onDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local s = Minimap:GetEffectiveScale()
	cx, cy = cx / s, cy / s
	ns.db.minimap.angle = math.deg(atan2(cy - my, cx - mx)) % 360
	position()
end

local function create()
	button = CreateFrame("Button", "RXPForeverTrackerMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 6, -5)
	icon:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Textures\\Cow") -- addon-owned 64x64 TGA
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			api.setLocked(not ns.db.locked)
			ns.say(ns.db.locked and "tracker locked" or "tracker unlocked: drag the green bar")
		elseif api.toggleConfig then
			api.toggleConfig()
		end
	end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("RXP ForeverTracker")
		GameTooltip:AddLine("Left click: settings", 1, 1, 1)
		GameTooltip:AddLine("Right click: lock / unlock the tracker", 1, 1, 1)
		GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	position()
	button:SetShown(not ns.db.minimap.hide)
end

function api.setMinimapShown(shown)
	ns.db.minimap.hide = not shown
	if button then button:SetShown(shown) end
end

ns.onLogin[#ns.onLogin + 1] = create
