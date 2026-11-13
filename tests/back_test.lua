-- Load SkipBox.lua with a fake RestedXP and exercise the back-one-step box.
local dir = arg[1]
local frameMT = {}
frameMT.__index = function(t, k)
	if k == "GetWidth" then return function() return 11 end end
	if k == "GetFrameLevel" then return function() return 5 end end
	if k:match("^Create") then return function() return setmetatable({}, frameMT) end end
	if k == "SetScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k == "IsMouseOver" then return function() return false end end
	return function() end
end
_G.CreateFrame = function() return setmetatable({}, frameMT) end
_G.PixelUtil = { ConvertPixelsToUIForRegion = function(v) return v end }
_G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
_G.PlaySound = function() end
_G.GameTooltip = setmetatable({}, frameMT)
local progress, calls = 5, {}
_G.UnitLevel = function() return 10 end
local steps = { { index = 1 }, { index = 2, level = 20 }, { index = 3, sticky = true }, { index = 4, sticky = true }, { index = 5 } }
local RXP = { currentGuide = { steps = steps }, GetGuideProgress = function() return progress end, IsSecretValue = function() return false end,
	SetStep = function(n) calls[#calls + 1] = n; progress = n end,
	v2 = { GetTheme = function() return { edge = 1, backgroundColors = {}, borderColors = {} } end },
	ui = { v2 = { ApplyFrameBackdrop = function() end, SetFrameBackdropShown = function() end } } }
local said = {}
local ns = { rxp = RXP, say = function(m) said[#said + 1] = m end, releaseTooltip = function() end }
-- 3.5.8 compat helpers (Objectives/Core.lua), as the game would have them
ns.isSecret = ns.isSecret or function() return false end
ns.itemCooldown = ns.itemCooldown or function(item) return RXP.GetItemCooldown and RXP.GetItemCooldown(item) end
ns.isPlayerSpell = ns.isPlayerSpell or function(id) return RXP.IsPlayerSpell and RXP.IsPlayerSpell(id) end
ns.L = ns.L or function(t) return t end
ns.texture = ns.texture or function(n) return RXP.GetV1Texture and RXP.GetV1Texture(n) or 134400 end
ns.playerClass = ns.playerClass or function() return RXP.player and RXP.player.class or "MAGE" end
ns.guideFontSize = ns.guideFontSize or function() return RXP.settings and RXP.settings.profile and RXP.settings.profile.guideFontSize or 12 end
ns.rxpProfile = ns.rxpProfile or function() return RXP.settings and RXP.settings.profile or {} end
ns.rxpRelease = ns.rxpRelease or function() return tostring(RXP.release or "") end
ns.hookRxp = ns.hookRxp or function(t, n, f) if type(t) == "table" and type(t[n]) == "function" and hooksecurefunc then hooksecurefunc(t, n, f) end end
ns.guard = ns.guard or function(fn, ...) return pcall(fn, ...) end
assert(loadfile(dir .. "/Objectives/tracker/SkipBox.lua"))("x", { objectives = ns })
local line = setmetatable({ fontHeight = 12, Box = setmetatable({}, frameMT) }, frameMT)
ns.placeBackButton(line)
-- find the button through a second placement: grab OnClick via a fresh line's child is not exposed; call through the
-- module's click handler by re-reading the upvalue is not possible, so drive it via the stored script on the button.
local button
for k, v in pairs(debug.getregistry()) do end
local i = 1
while true do
	local name, value = debug.getupvalue(ns.placeBackButton, i)
	if not name then break end
	if name == "backButton" then button = value end
	i = i + 1
end
assert(button, "button created")
button._OnClick(button)
print("SetStep called with", calls[1], "progress now", progress)
-- from 5: 4 and 3 are sticky, 2 is above level 10 -> 1
print("expect 1 (skipped sticky 4, 3 and level-20 step 2):", calls[1])
button._OnClick(button)
print("at first step, calls:", #calls)
print("room for 12pt line", ns.backButtonRoom(12))
ns.hideBackButton()
print("OK")
