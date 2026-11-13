-- GuideMenu.lua against a fake RestedXP: (1) its own list has guides, (2) its list is empty -> fallback.
local dir = arg[1]
_G.CLOSE = "Close"
_G.CreateFrame = function() return { Hide = function() end } end
_G.hooksecurefunc = function() end
_G.UIParent = { GetWidth = function() return 1920 end, GetEffectiveScale = function() return 1 end }
local shown
local function makeRXP(rxpList)
	local loaded
	local guides = {
		["G||A"] = { name = "A", group = "G", key = "a" },
		["G||B"] = { name = "B", group = "G", key = "b", lowLevel = true },
		["G||F"] = { name = "F", group = "G", key = "f", farm = true },
		["*Other||C"] = { name = "C", group = "*Other", key = "c" },
		["G||I"] = { name = "I", group = "G", internal = true },
	}
	local RXP = {
		locale = { Get = function(t) return t end },
		currentGuide = { name = "A", empty = false },
		RXPFrame = { GenerateMenuTable = function(_, menu) for _, i in ipairs(rxpList) do menu[#menu + 1] = i end
			menu[#menu + 1] = { text = "", isTitle = 1 }; menu[#menu + 1] = { text = "Import guide", func = function() end }; return menu end },
		guideList = { G = { names_ = { { group = "G", name = "A" }, { group = "G", name = "B" }, { group = "G", name = "F" }, { group = "G", name = "I" } } },
			["*Other"] = { names_ = { { group = "*Other", name = "C" } } }, RXPGuides = { names_ = {} } },
		GetGuideTable = function(g, n) return guides[g .. "||" .. n] end,
		IsGuideActive = function(g) return not g.lowLevel and not g.farm end,
		GetGuideName = function(g) return g.name end,
		LoadGuide = function(_, g) loaded = g end,
		ShowMenu = function(_, m) shown = m end,
		CloseMenu = function() end,
	}
	return RXP, function() return loaded end
end
local function run(rxpList)
	local RXP, loadedOf = makeRXP(rxpList)
	local ns = { rxp = RXP }
	assert(loadfile(dir .. "/Objectives/features/GuideMenu.lua"))("x", { objectives = ns })
	ns.showGuideMenu()
	return shown, loadedOf
end
local m = run({ { text = "Available Guides", isTitle = 1 }, { text = "G", hasArrow = true, menuList = { { text = "A" } } } })
local texts = {} for _, i in ipairs(m) do texts[#texts + 1] = i.text end
print("RXP list case:", table.concat(texts, " | "))
local m2, loadedOf = run({ { text = "Available Guides", isTitle = 1 } })
texts = {}
for _, i in ipairs(m2) do
	local sub = {}
	for _, s in ipairs(i.menuList or {}) do sub[#sub + 1] = s.text end
	texts[#texts + 1] = i.text .. (#sub > 0 and (" [" .. table.concat(sub, ", ") .. "]") or "")
end
print("fallback case:", table.concat(texts, " | "))
m2[3].menuList[1].func()
print("clicked first of second group ->", loadedOf() and loadedOf().name)
for _, i in ipairs(m2) do assert(i.text ~= "Import guide") end
print("no import entry: OK")
