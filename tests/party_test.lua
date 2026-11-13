local dir = arg[1]
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" end }
_G.IsInGroup = function() return true end
_G.IsInRaid = function() return false end
_G.GetNumSubgroupMembers = function() return 4 end
local names = { party1 = "Buoy", party2 = "Critt", party3 = "Toast", party4 = "Shichimiya" }
_G.UnitExists = function(u) return names[u] ~= nil end
_G.UnitName = function(u) return names[u] or "Me" end
_G.C_QuestLog = { IsUnitOnQuest = function(u) return u == "party1" or u == "party2" or u == "party4" end,
	GetLogIndexForQuestID = function() return 1 end }
_G.QuestieLoader = { ImportModule = function(_, n)
	if n == "QuestieComms" then
		return { remoteQuestLogs = { [42] = {
			["Buoy-Forever"] = { { fulfilled = 7, required = 12, finished = false } },
			Critt = { { fulfilled = 12, required = 12, finished = true } },
		} } }
	end
end }
local api = {}
local ns = { api = api, onLogin = {}, db = { tooltips = true } }
assert(loadfile(dir .. "/Tracker/Party.lua"))("x", { tracker = ns })
local tip = { AddLine = function(_, t) print(t) end, AddDoubleLine = function(_, a, b, _, _, _, r, g, bb) print(("%-12s %s  (%.1f %.1f %.1f)"):format(a, b, r, g, bb)) end }
api.addPartyProgress(tip, 42)
