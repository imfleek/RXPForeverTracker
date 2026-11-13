local src = io.open(arg[1] .. "/Tracker/Extras.lua"):read("a")
local body = src:match("(local REWARD_PATTERNS = {.-\nlocal function baseTitle%(text%).-\nend)")
local baseTitle = load(body .. "\nreturn baseTitle")()
local xp = "  |cffb087ff390xp|r"
local gold = "  |cffffd7001g|r |cffc7c7cf20s|r"
local cases = {
	{ "[45] Stoley's Debt", "plain" },
	{ "[45] Stoley's Debt" .. string.rep(xp, 22), "22x xp (double space)" },
	{ "[45] Stoley's Debt" .. string.rep(" |cffb087ff390xp|r", 5), "single space" },
	{ "[45] Stoley's Debt|cffb087ff390xp|r|cffb087ff390xp|r", "no space" },
	{ "|cffffffff[45] Stoley's Debt" .. xp .. "|r" .. xp, "wrapped in a colour" },
	{ "[45] Stoley's Debt 390xp 390xp 390xp", "colour codes removed" },
	{ "[45] Stoley's Debt" .. xp .. gold .. xp .. gold, "xp + gold repeated" },
	{ "[45] Stoley's Debt  |cffb087ff390|r|TInterface\\AddOns\\RXPForeverTracker\\Textures\\XPOrb:0:0:1:0|t|r  |cffffd7001|r|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:0|t", "orb + coins" },
	{ "        [60] Ragefire Chasm  |cffffd7002g|r", "marker indent + gold" },
	{ "[30] The 100 Rats", "title with a number" },
}
for _, c in ipairs(cases) do print(("%-24s -> %q"):format(c[2], baseTitle(c[1]))) end
