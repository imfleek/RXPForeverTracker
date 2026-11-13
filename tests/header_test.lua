-- 3.2.1: Header.lua in both styles: journal book before the guide name, opens the Prerequisite Journal.
local dir = arg[1]
local MT = {}
local function obj(t) return setmetatable(t or {}, MT) end
MT.__index = function(t, k)
	if k == "GetPoint" then return function(self) return "LEFT", rawget(self, "_parent"), "LEFT", 6, 0 end end
	if k == "GetHeight" then return function(self) return rawget(self, "_h") or 16 end end
	if k == "GetWidth" then return function(self) return rawget(self, "_w") or 16 end end
	if k == "SetSize" then return function(self, w, h) rawset(self, "_w", w); rawset(self, "_h", h) end end
	if k == "SetNormalAtlas" then return function(self, a) rawset(self, "_atlas", a) end end
	if k == "GetStringWidth" then return function() return 60 end end
	if k == "GetHighlightTexture" then return function() return obj({ GetAtlas = function() return "a" end, GetBlendMode = function() return "ADD" end }) end end
	if k == "SetPoint" then return function(self, ...) local p = rawget(self, "_points") or {}; p[#p + 1] = { ... }; rawset(self, "_points", p) end end
	if k == "ClearAllPoints" then return function(self) rawset(self, "_points", {}) end end
	if k == "SetShown" then return function(self, v) rawset(self, "_shown", not not v) end end
	if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
	if k == "SetScript" then return function(self, n, f) rawset(self, "_" .. n, f) end end
	if k:match("^Create") then return function(self) return obj({ _parent = self }) end end
	if k:match("^Get%a+Texture$") then return function(self) return obj() end end
	return function() end
end
_G.CreateFrame = function(_, _, parent) return obj({ _parent = parent }) end
_G.Mixin = function(t) return t end
_G.InCombatLockdown = function() return false end
_G.C_Texture = { GetAtlasInfo = function(name) if name == "UI-HUD-MicroMenu-AdventureGuide-Up" then return { width = 32, height = 40 } end end }
_G.AutoScalingFontStringMixin = {}
_G.hooksecurefunc = function() end
_G.ObjectiveTrackerManager = {}
_G.ObjectiveTrackerFrame = obj({ Header = obj({ Text = obj(), MinimizeButton = obj() }) })
_G.GameTooltip_SetTitle, _G.GameTooltip_AddNormalLine = function() end, function() end
local db = { enabled = true, theme = "rxp" }
local RXP = { locale = { Get = function(s) return s end }, release = "x", settings = { profile = { guideFontSize = 12 } },
	GetV1Texture = function(n) return n end, player = { class = "MAGE" }, v2 = {} }
local opened = 0
local toggled = 0
local ns = { rxp = RXP, db = db, toggleHidden = function() toggled = toggled + 1 end, windowsTooltip = function() return "" end, forever = function() return db.theme == "forever" end, textStyle = function() return "f", { 1, 1, 1 } end,
	hideTooltip = function() end, getTooltip = function() return obj() end, canStepBack = function() return true end,
	canStepForward = function() return true end }
local root = { objectives = ns, tracker = { api = { togglePrereqs = function() opened = opened + 1 end } } }
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
ns.hookRxp = ns.hookRxp or function(t, n, f) if type(t) == "table" and type(t[n]) == "function" then hooksecurefunc(t, n, f) end end
ns.guard = ns.guard or function(fn, ...) return pcall(fn, ...) end
assert(loadfile(dir .. "/Objectives/tracker/Header.lua"))("x", root)
local header = obj({ Text = obj(), MinimizeButton = obj() })
header.Text._parent = header
local module = obj({ Header = header })
ns.buildHeaders(module)
local snap = { title = "Dungeon Guide", subtitle = "46-47 Feralas/Azshara", progress = 73, total = 200 }
local pass = true
local function check(l, c) print((c and "ok   " or "FAIL ") .. l); pass = pass and c end
local function up(fn, want) local i = 1 while true do local n, v = debug.getupvalue(fn, i); if not n then return end; if n == want then return v end; i = i + 1 end end
ns.updateHeaders(snap)
local placeJournal = up(up(ns.updateHeaders, "updateModuleHeader"), "showForeverHeader")
local journal = up(placeJournal, "journal") or up(up(placeJournal, "placeJournal"), "journal")
check("journal built", journal ~= nil)
check("journal uses Forever's journal (Adventure Guide) button art at its proportions", journal._atlas == "UI-HUD-MicroMenu-AdventureGuide-Up" and journal._w == 18 and journal._h == 22)
check("RXP: journal after the logo", journal._points[1][1] == "TOPLEFT" and journal._points[1][2] == 42)
check("RXP: name after the journal", (function() for _, p in ipairs(rawget(up(up(ns.updateHeaders, "updateModuleHeader"), "title"), "_points") or {}) do if p[1] == "TOPLEFT" and p[2] == 42 + 18 + 4 then return true end end end)() == true)
check("RXP: header text hidden", header.Text._shown == false)
db.theme = "forever"
ns.updateHeaders(snap)
check("Forever: guide name, not its group", header.Text._text == "46-47 Feralas/Azshara")
local hdr = up(up(ns.updateHeaders, "updateModuleHeader"), "showForeverHeader")
local browse, help = up(up(hdr, "placeJournal"), "browseButton"), up(up(hdr, "placeJournal"), "helpButton")
local count = up(hdr, "stepCount")
check("Forever: ! where the header text began", browse._points[1][1] == "LEFT" and browse._points[1][4] == 6)
check("Forever: ? after !", help._points[1][2] == browse)
check("Forever: book after ?", journal._points[1][2] == help)
check("Forever: step count 73/200", count._text == "73/200")
check("Forever: name ends before the count", header.Text._points[2][2] == count)
local list = up(hdr, "foreverButtons")
local nameToggle = list and list[#list] -- the name button is always last (3.5.61 put the restart button before it)
check("Forever: a restart button sits between < and >", list and #list == 7)
check("Forever: the name is clickable over its own text", nameToggle and nameToggle._points[1][2] == header.Text)
nameToggle._OnClick(nameToggle)
check("Forever: clicking the name toggles RestedXP's window", toggled == 1)
check("Forever: name follows the journal", header.Text._points[1][2] == journal)
ns.updateHeaders({ title = "Feralas", subtitle = "" })
check("no group: title shown", header.Text._text == "Feralas")
journal._OnClick(journal)
check("click opens the Prerequisite Journal", opened == 1)
print(pass and "PASS" or "FAILED")
