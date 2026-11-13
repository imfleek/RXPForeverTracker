-- 3.5.70: the quest tooltip's gold includes the vendor value of the most valuable item reward
local src = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
local block = src:match("(local function itemLine%(name, texture, count, quality, value%).-\nlocal function addRewards%(id%).-\nend)\n")
assert(block, "reward code not found")
local lines = {}
local fonts = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end, GetName = function() return "Tip" end,
	NumLines = function() return #lines end, HookScript = function(self, _, f) self.cleared = f end }
_G.GameTooltipTextSmall, _G.GameTooltipText = "small", "normal"
setmetatable(_G, { __index = function(_, k)
	local n = type(k) == "string" and tonumber(k:match("^TipTextLeft(%d+)$"))
	if n then return { SetFontObject = function(_, f) fonts[n] = f end } end
end })
local values = { [1] = 300, [2] = 4500, [3] = 1200 } -- copper per item id
local env = setmetatable({
	GameTooltip = tip, db = {}, REWARDS = "Rewards",
	vendorValue = function(id, _, count) return (values[id] or 0) * (count or 1) end,
	tipGold = function(c) return tostring(c) .. "c" end,
	withSelected = function(_, fn) fn() end,
	isSecret = function() return false end,
	call = function(name) if name == "GetQuestLogRewardMoney" then return 2000 end return 0 end,
}, { __index = _G })
-- the reward API is read from the game's globals
_G.GetNumQuestLogRewards = function() return 1 end
_G.GetQuestLogRewardInfo = function(i) return "Ring", nil, 1, 1, true, 1 end
_G.GetNumQuestLogChoices = function() return 2 end
_G.GetQuestLogChoiceInfo = function(i) return i == 1 and "Sword" or "Shield", nil, 1, 1, true, i == 1 and 2 or 3 end
local addRewards = load(block .. "\nreturn addRewards", "x", "t", env)()
addRewards(42)
local text = table.concat(lines, "\n")
print((text:gsub("\n", " | ")))
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
check("gold = quest money + the best item's vendor value (2000 + 4500)", text:find("Gold: 6500c", 1, true) ~= nil)
local inc
for i, l in ipairs(lines) do if l:find("from selling", 1, true) then inc = i end end
check("that line is in the small tooltip font", inc and fonts[inc] == "small")
tip.cleared(tip)
check("and the normal font comes back when the tooltip is cleared", inc and fonts[inc] == "normal")
check("and says where the extra comes from", text:find("4500c", 1, true) and text:find("from selling Sword", 1, true) ~= nil)
-- no item with a vendor value: just the quest's gold
values = {}
lines = {}
addRewards(42)
text = table.concat(lines, "\n")
check("no sellable item: the quest's own gold, no extra line", text:find("Gold: 2000c", 1, true) and not text:find("from selling", 1, true))
-- no gold from the quest: no Gold line made just for an item's vendor value
values = { [1] = 300, [2] = 4500, [3] = 1200 }
env.call = function() return 0 end
lines = {}
addRewards(42)
text = table.concat(lines, "\n")
check("a quest with no gold gets no Gold line, even with sellable items", not text:find("Gold:", 1, true) and not text:find("from selling", 1, true))
print(pass and "PASS" or "FAILED")
