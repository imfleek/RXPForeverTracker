-- 3.5.55: RestedXP's quest helper waits until every reward choice has its item link
local A = arg[1]
local calls, shown, links = 0, true, { nil, "|Hitem:2|h" }
local requested = {}
_G.QuestFrameRewardPanel = { IsShown = function() return shown end }
_G.GetNumQuestChoices = function() return 2 end
_G.GetQuestItemLink = function(_, i) return links[i] end
_G.GetQuestItemInfo = function(_, i) return "x", 1, 1, 1, true, 100 + i end
_G.C_Item = { RequestLoadItemDataByID = function(id) requested[#requested + 1] = id end }
local original = function(self, event) calls = calls + 1 end
local frame = { GetScript = function(_, k) return k == "OnEvent" and original or nil end,
	SetScript = function(self, k, f) self.set = f end }
_G.EnumerateFrames = function(f) if f == nil then return frame end end
local RXP = { QuestAutomation = original }
local ns = { rxp = RXP }
assert(loadfile(A .. "/Objectives/features/RxpFixes.lua"))("x", { objectives = ns })
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
RXP.QuestAutomation()
check("reward window with a choice not loaded: RestedXP waits", calls == 0 and requested[1] == 101)
frame.set(frame, "QUEST_COMPLETE")
check("its quest event frame waits too", calls == 0 and frame.set ~= nil)
links[1] = "|Hitem:1|h"
RXP.QuestAutomation()
check("once every choice has its link, it runs", calls == 1)
links[1] = nil
frame.set(frame, "QUEST_DETAIL")
check("other quest windows are not held up", calls == 2)
print(pass and "PASS" or "FAILED")
