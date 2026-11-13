-- 3.2.5: journal reward totals use the quest-title settings (xp orb / coins), and Questie totals add up.
local A = arg[1]
local src = io.open(A .. "/Tracker/Extras.lua"):read("a")
local coinBlock = src:match("(local function coin%(file%).-\nlocal COIN = [^\n]+)")
local goldFn = src:match("(local function gold%(copper, coins, spaced%).-\nend)")
local orb = src:match("(local XP_ORB = [^\n]+)")
local fmt = src:match("(function api%.formatRewardTotals%(xp, money, spacedCoins%).-\nend)")
local db = {}
local env = setmetatable({ db = db, api = {}, ADDON = "RXPForeverTracker" }, { __index = _G })
local api = load(coinBlock .. "\n" .. goldFn .. "\n" .. orb .. "\n" .. fmt .. "\nreturn api", "x", "t", env)()
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local plain = api.formatRewardTotals(7400, 16500):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
check("text form: " .. plain, plain == "7400xp  1g 65s")
db.xpOrb, db.goldCoins = true, true
local icons = api.formatRewardTotals(7400, 16500)
check("orb and coins when chosen for titles", icons:find("XPOrb") ~= nil and icons:find("|T") ~= nil and not icons:find("xp|r"))
local spaced = api.formatRewardTotals(0, 16500, true)
check("journal: a space before each coin icon (3.5.13)", select(2, spaced:gsub("|r |T", "")) == 2 and not spaced:find("%d|r|T"))
check("titles keep coins tight", not api.formatRewardTotals(0, 16500):find("|r |T", 1, true))
check("nothing for zero", api.formatRewardTotals(0, 0) == "")
-- Questie totals
_G.LibQuestieDB = { Quest = { Get = function() end } }
_G.C_AddOns = { IsAddOnLoaded = function() return true end }
_G.Questie = { API = { isReady = true } }
_G.QuestieLoader = { ImportModule = function(_, n) if n == "QuestXP" then return { db = {}, GetQuestLogRewardXP = function(_, id) return ({ [1] = 1000, [2] = 2500 })[id] or 0 end } end return {} end }
_G.GetQuestLogRewardMoney = function(id) return ({ [1] = 500, [2] = 12000 })[id] or 0 end
_G.C_Map, _G.C_QuestLog = {}, {}
local qapi = {}
assert(loadfile(A .. "/Tracker/Questie.lua"))("x", { tracker = { api = qapi, onLogin = {}, db = {} } })
local xp, money = qapi.questRewardTotals({ 1, 2, 3 })
check("totals over the quest and its prerequisites", xp == 3500 and money == 12500)
print(pass and "PASS" or "FAILED")
