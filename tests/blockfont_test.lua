local dir = arg[1]
local function fs(file, size, flags)
	local o = { f = file, s = size, fl = flags }
	o.GetFont = function(self) return self.f, self.s, self.fl end
	o.SetFont = function(self, f, s, fl) self.f, self.s, self.fl = f, s, fl end
	return o
end
local title, line, dash, header = fs("Fonts\\FRIZQT__.TTF", 13, ""), fs("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"), fs("Fonts\\FRIZQT__.TTF", 12, "OUTLINE"), fs("Fonts\\FRIZQT__.TTF", 14, "")
local block = { HeaderText = title, usedLines = { a = { Text = line, Dash = dash } } }
local dirty = 0
_G.ObjectiveTrackerFrame = { modules = { { Header = { Text = header }, usedBlocks = { x = { [123] = block } } } },
	MarkDirty = function() dirty = dirty + 1 end, Update = function() end }
_G.hooksecurefunc = function() end
_G.securecallfunction = function(f, ...) return f(...) end
_G.GetTime = function() return 100 end
_G.C_Timer = { After = function() end }
_G.LibStub = nil
local api = {}
local ns = { api = api, onLogin = {}, db = { font = "default" } }
assert(loadfile(dir .. "/Tracker/Fonts.lua"))("x", { tracker = ns, objectives = {} })
api.setFont("arial")
print("Arial: title", title:GetFont(), "| objective", line.f, line.s, line.fl, "| dash", dash.f, "| relayouts", dirty)
title.f = "Fonts\\FRIZQT__.TTF" -- Blizzard reuses the block and resets its title
api.afterTrackerUpdateFonts()
print("after Blizzard reset + update: title", title.f)
api.setFont("default")
print("Game default: title", title:GetFont(), "| objective", line.f, line.s, line.fl)
