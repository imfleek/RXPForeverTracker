local src = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
local coinBlock = src:match("(local function coin%(file%).-\nlocal COIN = [^\n]+)")
local goldFn = src:match("(local function gold%(copper, coins, spaced%).-\nend)")
local db = { goldCoins = false }
local env = setmetatable({ db = db }, { __index = _G })
local gold = load(coinBlock .. "\n" .. goldFn .. "\nreturn gold", "x", "t", env)()
local text = "  |cffaaaaaa(vendor|r " .. gold(4043, true) .. "|cffaaaaaa)|r"
local readable = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*UI%-(%a+)Icon[^|]*|t", "[%1]")
print("tooltip vendor:", readable)
print("gold 1g 2s 3c:", (gold(10203, true):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*UI%-(%a+)Icon[^|]*|t", "[%1]")))
print("texture:", gold(1, true):match("|T([^|]*)|t"))
local body = src:match("(local REWARD_PATTERNS = {.-\nlocal function baseTitle%(text%).-\nend)")
local baseTitle = load(body .. "\nreturn baseTitle")()
print("title cleanup with coins:", baseTitle("[45] Stoley's Debt  " .. gold(10203, true)))
