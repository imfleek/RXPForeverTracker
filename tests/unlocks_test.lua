-- 1.0.4: with Ctrl, the quest tooltip lists what finishing the quest, and its chain, unlocks (Questie data)
local dir = arg[1]
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local data = { Quest = {
	-- chain 10 -> 11 -> 12
	[10] = { name = "Start", questLevel = 20, nextQuestInChain = 11 },
	[11] = { name = "Middle", questLevel = 21, preQuestSingle = { 10 }, nextQuestInChain = 12 },
	[12] = { name = "End", questLevel = 22, preQuestSingle = { 11 } },
	-- opened by 10 (side quest) and starting a chain 20 -> 21
	[20] = { name = "Side Chain", questLevel = 23, preQuestSingle = { 10 }, nextQuestInChain = 21 },
	[21] = { name = "Side Chain II", questLevel = 24, preQuestSingle = { 20 } },
	-- opened by 10 together with 30
	[22] = { name = "Needs Two", questLevel = 25, preQuestGroup = { 10, 30 } },
	[30] = { name = "Other Need", questLevel = 19 },
	-- opened by 10 but Horde only (race mask 2: Orc) and already done
	[23] = { name = "Horde Only", questLevel = 20, preQuestSingle = { 10 }, requiredRaces = 2 },
	[24] = { name = "Done Already", questLevel = 20, preQuestSingle = { 10 } },
	-- opened by the chain's end
	[40] = { name = "After the Chain", questLevel = 26, preQuestSingle = { 12 } },
	-- no unlocks, no chain
	[50] = { name = "Lonely" },
} }
_G.LibQuestieDB = { Quest = { Get = function(id, f) local r = data.Quest[id]; return r and r[f] end,
	GetAllIds = function() local ids = {} for id in pairs(data.Quest) do ids[#ids + 1] = id end table.sort(ids) return ids end } }
local ctrl, tickers = false, {}
_G.IsControlKeyDown = function() return ctrl end
_G.C_Timer = { NewTicker = function(_, fn) local t = { fn = fn, Cancel = function(self) self.done = true end }; tickers[#tickers + 1] = t; return t end }
_G.QuestieLoader = { ImportModule = function() return {} end }
_G.Questie = { API = { isReady = true, RegisterOnReady = function() end } }
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" end }
_G.C_QuestLog = { IsQuestFlaggedCompleted = function(id) return id == 24 end, GetTitleForQuestID = function(id) return data.Quest[id] and data.Quest[id].name end }
_G.UnitRace = function() return "Human", "Human", 1 end
_G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
_G.bit = { band = function(a, b) local r, bitv = 0, 1; a, b = math.floor(a), math.floor(b)
	while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + bitv end; a, b, bitv = math.floor(a / 2), math.floor(b / 2), bitv * 2 end; return r end }
local api = {}
local ns = { api = api, onLogin = {}, db = { questie = true, questieChain = true, questieChainReward = false, questieUnlocks = true } }
assert(loadfile(dir .. "/Tracker/Questie.lua"))("x", { tracker = ns })
local lines
local tip = { AddLine = function(_, text) lines[#lines + 1] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end }
local function render(id) lines = {}; api.addQuestieLines(tip, id); return table.concat(lines, "\n") end
local t = render(10)
for _, tk in ipairs(tickers) do while not tk.done do tk.fn() end end
ctrl = false
t = render(10)
check("without Ctrl: hint mentions unlocks", t:find("and what it unlocks", 1, true) ~= nil and not t:find("Finishing", 1, true))
ctrl = true
t = render(10)
print(t)
check("lists the side chain, marked as starting a chain of 2", t:find("Side Chain [23] starts a new chain of 2 quests", 1, true) ~= nil)
check("quests that do not lead on are not called chains", not t:find("Needs Two [25] starts", 1, true) and not t:find("After the Chain [26] starts", 1, true))
check("a quest that needs another one too says so", t:find("Needs Two [25]", 1, true) and t:find("also needs: Other Need", 1, true) ~= nil)
check("not the chain's own follow-up (shown in the chain)", not t:find("  Middle [21]", 1, true) or t:find("> 1. Start", 1, true))
check("not other-race or finished quests", not t:find("Horde Only", 1, true) and not t:find("Done Already", 1, true))
check("what finishing the chain unlocks", t:find("Finishing the chain unlocks:", 1, true) and t:find("After the Chain [26]", 1, true) ~= nil)
check("Ctrl changes this tooltip (width measured)", api.chainTooltip(10) == true)
t = render(50)
check("nothing for a quest with no chain and no unlocks", t == "" and api.chainTooltip(50) == false)
ctrl = false
t = render(30)
check("not in a chain but unlocks something: its own Ctrl hint", t:find("Hold Ctrl to see what this quest unlocks", 1, true) ~= nil)
ctrl = true
t = render(30)
check("with Ctrl: what it unlocks, and what else that needs", t:find("Needs Two [25]", 1, true) and t:find("also needs: Start", 1, true) ~= nil)
ns.db.questieUnlocks = false
ctrl = true
t = render(10)
check("setting off: no unlock lines", not t:find("unlocks:", 1, true))
print(pass and "ALL OK" or "SOME FAILED")
