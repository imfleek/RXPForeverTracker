local dir = arg[1]
local quests = {
	[98] = { nextQuestInChain = 99 }, [99] = { nextQuestInChain = 7848 }, [7848] = { name = "Attunement to the Core" },
	[50] = { nextQuestInChain = 51 }, [51] = {},
	[500] = { childQuests = { 9837 } }, [9837] = { name = "The Master's Key" },
}
_G.LibQuestieDB = { Quest = {
	Get = function(id, f) return quests[id] and quests[id][f] end,
	BuildNameIndexAsync = function() coroutine.yield() end,
	IdsByName = function(n) for id, q in pairs(quests) do if q.name == n then return { id } end end end,
} }
_G.Questie = { API = { isReady = true } }
_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" end }
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
local tickers = {}
_G.C_Timer = { NewTicker = function(_, fn) local t = { fn = fn, Cancel = function(s) s.done = true end }; tickers[#tickers + 1] = t; return t end }
_G.C_QuestLog = {}
local api = {}
local ns = { api = api, onLogin = {}, db = { questie = true, condense = true } }
assert(loadfile(dir .. "/Tracker/Questie.lua"))("x", { tracker = ns })
-- the star itself lives in Extras.lua (same code)
api.attunementStar = function(id)
	if not (ns.db.condense and ns.db.attunementStar ~= false and api.isAttunement(id)) then return "" end
	return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t "
end
print("98 (chain to Attunement to the Core):", api.isAttunement(98))
print("50 (unrelated chain):", api.isAttunement(50))
print("500 before the name index:", api.isAttunement(500))
for _, tk in ipairs(tickers) do local n = 0; while not tk.done and n < 10 do tk.fn(); n = n + 1 end end
print("500 after (follow-up The Master's Key):", api.isAttunement(500))
ns.db.condense = false
print("star with Elite+ icons off:", tostring(api.attunementStar(98)))
ns.db.condense = true
local src = io.open(dir .. "/Tracker/Extras.lua"):read("a")
local body = src:match("(local REWARD_PATTERNS = {.-\nlocal function baseTitle%(text%).-\nend)")
local baseTitle = load(body .. "\nreturn baseTitle")()
local star = api.attunementStar(98)
local decorated = ("      [60] The Molten Core  |cffb087ff5400xp|r"):gsub("^(%s*)", function(i) return i .. star end, 1)
print("decorated:", (decorated:gsub("|T[^|]*|t", "[star]"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
print("cleaned twice-decorated:", baseTitle(decorated:gsub("^(%s*)", function(i) return i .. star end, 1)))
