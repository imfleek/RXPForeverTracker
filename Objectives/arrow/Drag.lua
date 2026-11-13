local _, root = ...; local ns = root.objectives

local arrow = ns.arrow
if not arrow then return end

local RXP, db = ns.rxp, ns.db
local af, cover = RXP.arrowFrame, arrow.cover

local drag = {active = false, coverMoving = false}
arrow.drag = drag

local mouseOff, mover

-- CONSTRAINT: RestedXP's OnMouseDown on the arrow (map.lua) moves it unless its own Lock Frames is on, and knows
-- nothing of our lock: with ours on its mouse is off (a plain frame, so in combat too) and on again when the lock goes.
function arrow.syncLock()
	if arrow.enabled() and db.arrowLocked then
		if af:IsMouseEnabled() then
			af:EnableMouse(false)
			mouseOff = true
		end
	elseif mouseOff then
		mouseOff = nil
		af:EnableMouse(true)
	end
end

local function followMover()
	if InCombatLockdown() then return end
	local x, y = mover:GetCenter()
	cover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- CONSTRAINT: RestedXP's arrow drags through the button covering it, replaying its OnMouseDown/OnMouseUp (map.lua);
-- a drag starts out of combat only.
local function dragStart()
	if db.arrowLocked or ns.rxpProfile().lockFrames or InCombatLockdown() then return end
	if af:IsShown() then
		if af:GetAlpha() == 0 then return end
		af:GetScript("OnMouseDown")(af, "LeftButton")
	else
		-- CONSTRAINT: StartMoving and StopMovingOrSizing are protected: a button left moving when combat starts could not
		-- be stopped and would follow the mouse. A plain frame moves instead; the button follows it out of combat only.
		if not mover then
			mover = CreateFrame("Frame", nil, UIParent)
			mover:SetSize(1, 1)
			mover:SetMovable(true)
		end
		local x, y = cover:GetCenter()
		mover:ClearAllPoints()
		mover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		mover:Show()
		mover:StartMoving()
		mover:SetScript("OnUpdate", followMover)
		drag.coverMoving = true
	end
	drag.active = true
end

local function endDrag()
	if not drag.active then return end
	drag.active = false
	if not drag.coverMoving then
		af:GetScript("OnMouseUp")(af, "LeftButton")
		return
	end
	drag.coverMoving = false
	mover:StopMovingOrSizing()
	mover:SetScript("OnUpdate", nil)
	local x, y = mover:GetCenter()
	mover:Hide()
	if x then
		local scale = ns.relativeScale(af)
		af:ClearAllPoints()
		af:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	end
	RXP.settings:SaveFramePositions()
end

local function dragStop()
	if not drag.active then return end
	endDrag()
	local x, y, size = arrow.geometry()
	if x and not InCombatLockdown() then arrow.place(x, y, size) end
end

-- CONSTRAINT: the right button has no action (setCover), so the secure click before this hook does nothing.
local function coverClick(_, button, down)
	if button ~= "RightButton" or down or not IsControlKeyDown() then return end
	if ns.rxpProfile().lockFrames then
		ns.say("The arrow is locked by RestedXP's Lock Frames setting.")
		return
	end
	db.arrowLocked = not db.arrowLocked
	arrow.syncLock()
	ns.say(db.arrowLocked and "Arrow locked in place. Ctrl+Right-click it to unlock."
		or "Arrow unlocked: drag it to move it.")
end

-- CONSTRAINT: the action fires on the release, never on a press that becomes a drag. RestedXP's item buttons set no
-- useOnKeyDown (ActiveItemFrame.lua UpdateItemFrame); only its teleport buttons do.
cover:SetAttribute("useOnKeyDown", false)
cover:RegisterForDrag("LeftButton")
cover:SetScript("OnDragStart", dragStart)
cover:SetScript("OnDragStop", dragStop)
-- CONSTRAINT: a hidden frame gets no OnDragStop: a drag still running when the button hides ends here.
cover:SetScript("OnHide", endDrag)
cover:HookScript("OnClick", coverClick)
