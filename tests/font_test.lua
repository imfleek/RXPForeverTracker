local dir = arg[1]
local function fontObject(file, size, flags)
	local o = { f = file, s = size, fl = flags }
	o.GetFont = function(self) return self.f, self.s, self.fl end
	o.SetFont = function(self, f, s, fl) self.f, self.s, self.fl = f, s, fl end
	return o
end
_G.ObjectiveTrackerHeaderFont = fontObject("Fonts\\FRIZQT__.TTF", 14, "")
_G.ObjectiveTrackerLineFont = fontObject("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
_G.LibStub = function() return { HashTable = function() return { Expressway = "Interface\\AddOns\\SharedMedia\\exp.ttf", ["Friz copy"] = "Fonts\\FRIZQT__.TTF" } end } end
_G.hooksecurefunc = function() end
_G.securecallfunction = function(f, ...) return f(...) end
local api = {}
local ns = { api = api, onLogin = {}, db = { font = "default" } }
assert(loadfile(dir .. "/Tracker/Fonts.lua"))("x", { tracker = ns, objectives = {} })
local names = {}
for _, o in ipairs(api.fontOptions()) do names[#names + 1] = o[2] end
print("choices: " .. table.concat(names, ", "))
api.setFont("arial")
print("Arial Narrow ->", ObjectiveTrackerHeaderFont:GetFont(), ObjectiveTrackerLineFont:GetFont())
api.setFont("lsm:Expressway")
print("Expressway   ->", (ObjectiveTrackerHeaderFont:GetFont()))
api.setFont("default")
print("Game default ->", ObjectiveTrackerHeaderFont:GetFont(), ObjectiveTrackerLineFont:GetFont())
