-- Another quest tracker addon: 8 seconds after entering the world, ask which one to disable.
--
-- RXP ForeverTracker only works with Blizzard's default quest tracker (it makes that tracker scroll and shows the
-- RestedXP guide in it); an addon that replaces or hides it leaves nothing for this one to attach to, and both
-- together hide or overlap each other. Choices: disable RXP ForeverTracker, disable the other addon (for Questie: turn
-- off only its tracker) (both reload the UI), or keep both (not asked again for that addon). Escape and the close button do nothing.
local ADDON, root = ...; local ns = root.tracker

local DELAY = 8
-- Addons that replace or hide the default quest tracker. Questie only when its own tracker is switched on.
local KNOWN = { "!KalielsTracker", "KalielsTracker", "BetterQuestList", "SorhaQuestLog", "QuestGuru_Tracker", "Questie" }

local function questieTrackerOn()
	local questie = _G.Questie
	local ok, on = pcall(function() return questie.db.profile.trackerEnabled end)
	return ok and on and true or false
end

local function titleOf(name)
	local title = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name, "Title") or name
	return (tostring(title or name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function findOther(db)
	for _, name in ipairs(KNOWN) do
		if C_AddOns.IsAddOnLoaded(name) and not (db.conflictKept and db.conflictKept[name]) then
			if name ~= "Questie" or questieTrackerOn() then return name end
		end
	end
end

-- Questie: only its tracker is turned off (the rest of Questie stays), as its own "Enable Tracker" option does:
-- QuestieTracker:Disable() (Modules/Tracker/QuestieTracker.lua, Questie 12.7.0) sets the profile option and reloads.
-- When that module cannot be reached (a later Questie), the same profile option is set here and the UI reloads.
local function disableQuestieTracker()
	local loader = _G.QuestieLoader
	local ok, tracker = pcall(function() return loader:ImportModule("QuestieTracker") end)
	if ok and type(tracker) == "table" and type(tracker.Disable) == "function" and pcall(tracker.Disable, tracker) then
		return -- it reloads the UI itself
	end
	pcall(function() _G.Questie.db.profile.trackerEnabled = false end)
	ReloadUI()
end

local function disable(name)
	if name == "Questie" then return disableQuestieTracker() end
	pcall(C_AddOns.DisableAddOn, name)
	ReloadUI()
end

local function ask()
	local db = ns.db
	if not db then return end
	if InCombatLockdown() then C_Timer.After(DELAY, ask) return end
	local other = findOther(db)
	if not other then return end
	local otherTitle = titleOf(other)
	local questie = other == "Questie"
	StaticPopupDialogs.RXPFOREVERTRACKER_OTHER_TRACKER = {
		text = questie and (root.BRAND .. " found Questie's own quest tracker switched on.\n\n" .. root.BRAND
			.. " only works with Blizzard's default quest tracker, which Questie's tracker replaces; with both on they "
			.. "can hide or overlap each other.\n\nTurn off Questie's tracker (the rest of Questie keeps working), or "
			.. "disable " .. root.BRAND .. "? The UI reloads.")
			or (root.BRAND .. " found another quest tracker addon: %s.\n\n" .. root.BRAND .. " only works with "
			.. "Blizzard's default quest tracker, which %s replaces or hides; with both enabled they can hide or "
			.. "overlap each other.\n\nDisable one of them? The UI reloads."),
		button1 = "Disable " .. root.BRAND,
		button2 = questie and "Turn off Questie's tracker" or ("Disable " .. otherTitle),
		button3 = "Keep both",
		OnAccept = function() disable(ADDON) end,
		OnCancel = function(_, _, reason)
			if reason == "clicked" then disable(other) end
		end,
		OnAlt = function()
			db.conflictKept = db.conflictKept or {}
			db.conflictKept[other] = true
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = false,
		noCancelOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("RXPFOREVERTRACKER_OTHER_TRACKER", otherTitle, otherTitle)
end

-- Runs even when the tracker half is off (no default tracker to attach to is exactly this case).
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, _, isLogin, isReload)
	if isLogin == false and isReload == false then return end -- a zone change, not a login or reload
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	C_Timer.After(DELAY, function()
		if root.disabledAll then return end -- the old AllTracker RXP is running: Bootstrap.lua already said so
		if not ns.db then
			_G.RXPForeverTrackerDB = type(_G.RXPForeverTrackerDB) == "table" and _G.RXPForeverTrackerDB or {}
			ns.db = _G.RXPForeverTrackerDB
		end
		ask()
	end)
end)
