-- GameTooltip stub: frame width = max(widest line, minimum width) + 20 padding (SetMinimumWidth is content width)
local lines, minW, shown = {}, 0, false
local tip = { NumLines = function() return #lines end }
function tip:AddLine(t) lines[#lines + 1] = t end
function tip:AddDoubleLine(a, b) lines[#lines + 1] = a .. "    " .. b end
function tip:ClearLines() lines = {} end
function tip:SetOwner() lines = {}; shown = false end
function tip:SetMinimumWidth(w) minW = w end
function tip:Show() shown = true end
function tip:IsShown() return shown end
function tip:GetOwner() return "owner" end
function tip:GetWidth()
	local w = 0
	for _, l in ipairs(lines) do w = math.max(w, #l * 6) end
	return math.max(w, minW) + 20
end
function tip:HookScript() end
_G.GameTooltip = tip
local ctrl = false
_G.IsControlKeyDown = function() return ctrl end
local src = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
local block = src:match("(local lastTip.-\napi.showQuestTooltip = questTooltip)")
assert(block)
local chainForced = false
local api = {
	chainTooltip = function() return true end,
	setChainCtrl = function(v) chainForced = v end,
	addQuestieLines = function(t)
		if chainForced or ctrl then
			t:AddLine("Chain: 1. A very long quest name in the middle of the chain")
			t:AddLine("Chain total (quests 2-5): 12000 xp 3g")
		else t:AddLine("Hold Ctrl to see the whole chain") end
	end,
}
local env = setmetatable({ db = { tooltips = true, partyProgress = false }, api = api, isSecret = function() return false end,
	addRewards = function() end,
	C_QuestLog = { GetLogIndexForQuestID = function() return 1 end, GetInfo = function() return { title = "Short", level = 10 } end } },
	{ __index = _G })
local fn = load(block .. "\nreturn questTooltip", "x", "t", env)()
fn("owner", 5, "Short")
local widths = { tip:GetWidth() }
for i = 1, 6 do
	ctrl = not ctrl
	fn("owner", 5, "Short", nil, true)
	widths[#widths + 1] = tip:GetWidth()
end
print("widths (open, then Ctrl down/up x3): " .. table.concat(widths, ", "))
for i = 2, #widths do assert(widths[i] == widths[1], "width changed") end
print("OK: same width every time")
