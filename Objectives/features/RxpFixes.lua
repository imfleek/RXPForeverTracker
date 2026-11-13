local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP = ns.rxp

-- Work-around for a RestedXP error (RXPGuides.lua evaluateQuestChoices, seen in v4.11.36): on a quest reward window
-- with two or more choices, RestedXP reads each choice's item link and looks the item up; a reward the game has not
-- loaded yet has no link, and the lookup of nothing raises "bad argument #1 ... Usage: local itemName, itemLink ...".
-- Until every choice has its link, RestedXP's quest helper waits (it runs again on its next pass, a moment later) and
-- the items are asked for. Only its own method is wrapped (no Blizzard function is touched); when RestedXP renames or
-- drops QuestAutomation, nothing happens.
local function rewardWindowEvent(event)
	if event then return event end
	-- the same order RestedXP uses to tell which quest window is open
	if _G.GossipFrame and _G.GossipFrame:IsShown() then return "GOSSIP_SHOW" end
	if _G.QuestFrameGreetingPanel and _G.QuestFrameGreetingPanel:IsShown() then return "QUEST_GREETING" end
	if _G.QuestFrameProgressPanel and _G.QuestFrameProgressPanel:IsShown() then return "QUEST_PROGRESS" end
	if _G.QuestFrameDetailPanel and _G.QuestFrameDetailPanel:IsShown() then return "QUEST_DETAIL" end
	if (_G.QuestFrameRewardPanel and _G.QuestFrameRewardPanel:IsShown())
		or (_G.QuestFrameCompleteButton and _G.QuestFrameCompleteButton:IsShown()) then return "QUEST_COMPLETE" end
end

local function rewardLinksMissing()
	local count = type(GetNumQuestChoices) == "function" and GetNumQuestChoices() or 0
	if type(count) ~= "number" or count <= 1 or type(GetQuestItemLink) ~= "function" then return false end
	local missing = false
	for i = 1, count do
		if not GetQuestItemLink("choice", i) then
			missing = true
			local id = type(GetQuestItemInfo) == "function" and select(6, GetQuestItemInfo("choice", i))
			if type(id) == "number" and C_Item and C_Item.RequestLoadItemDataByID then
				pcall(C_Item.RequestLoadItemDataByID, id)
			end
		end
	end
	return missing
end
ns.rewardLinksMissing = rewardLinksMissing

-- RestedXP runs it two ways: from its update ticker (addon.QuestAutomation(), looked up each time) and as the OnEvent
-- script of its own quest event frame (the function itself, given at load): both get the wrapper.
local original = RXP.QuestAutomation
if type(original) == "function" then
	local function guarded(self, event, ...)
		if rewardWindowEvent(event) == "QUEST_COMPLETE" and rewardLinksMissing() then return end
		return original(self, event, ...)
	end
	RXP.QuestAutomation = guarded
	if type(EnumerateFrames) == "function" then
		local frame = EnumerateFrames()
		while frame do
			if frame.GetScript and not (frame.IsForbidden and frame:IsForbidden()) then
				local ok, script = pcall(frame.GetScript, frame, "OnEvent")
				if ok and script == original then frame:SetScript("OnEvent", guarded) end
			end
			frame = EnumerateFrames(frame)
		end
	end
end
