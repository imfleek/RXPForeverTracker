-- Font choice (Settings window > Font): one font for the quest tracker, the RestedXP Tracker (guide) and the settings
-- window. "Game default" leaves every font as the game and RestedXP set it.
--
-- The quest tracker draws with Blizzard's shared font objects; their font file is replaced and their size and
-- outline kept, and the originals are restored for "Game default". The guide reads api.fontPath() through
-- ns.textStyle (Objectives/rxp/Readers.lua), the settings window through applyFonts (Config.lua), zone headers
-- through styleLabel (ZoneSort.lua).
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api

local BUILT_IN = {
	{ "default", "Game default" },
	{ "friz", "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ "arial", "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ "morpheus", "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	{ "skurri", "Skurri", path = "Fonts\\SKURRI.TTF" },
}

-- Blizzard's quest tracker font objects (only those this client has are touched)
local OBJECTS = { "ObjectiveTrackerHeaderFont", "ObjectiveTrackerLineFont", "ObjectiveFont", "ObjectiveTrackerFont12",
	"ObjectiveTrackerFont13", "ObjectiveTrackerFont14", "ObjectiveTrackerFont15", "ObjectiveTrackerFont16",
	"ObjectiveTrackerFont17", "ObjectiveTrackerFont18", "ObjectiveTrackerFont19", "ObjectiveTrackerFont20" }

-- The choices: the built-in ones, then LibSharedMedia's fonts when that library is loaded (by another addon).
function api.fontOptions()
	local list = {}
	for _, f in ipairs(BUILT_IN) do list[#list + 1] = { f[1], f[2], path = f.path } end
	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
	if lsm and lsm.HashTable then
		local ok, fonts = pcall(lsm.HashTable, lsm, "font")
		if ok and type(fonts) == "table" then
			local names = {}
			for name, path in pairs(fonts) do
				if type(name) == "string" and type(path) == "string" then names[#names + 1] = name end
			end
			table.sort(names)
			local known = {}
			for _, f in ipairs(BUILT_IN) do if f.path then known[f.path:lower()] = true end end
			for _, name in ipairs(names) do
				local path = fonts[name]
				if not known[path:lower()] then list[#list + 1] = { "lsm:" .. name, name, path = path } end
			end
		end
	end
	return list
end

-- The chosen font file, or nil for "Game default".
function api.fontPath()
	local key = ns.db and ns.db.font
	if not key or key == "default" then return nil end
	for _, option in ipairs(api.fontOptions()) do
		if option[1] == key then return option.path end
	end
	return nil
end

local originals = {}
local function applyTrackerFont()
	local path = api.fontPath()
	for _, name in ipairs(OBJECTS) do
		local object = _G[name]
		if object and object.GetFont and object.SetFont then
			local file, size, flags = object:GetFont()
			if file and size then
				if not originals[name] then originals[name] = file end
				local want = path or originals[name]
				if file ~= want then pcall(object.SetFont, object, want, size, flags or "") end
			end
		end
	end
end

-- CONSTRAINT: on Forever the quest titles and objective lines are not drawn with the font objects above (user report,
-- 2.6.1: only the Quests header, zone headers and the guide changed). A shared object they might use (GameFont...)
-- would restyle the whole game, so the chosen font is set on the tracker's own text instead: section headers, quest
-- titles, objective lines and dashes, after every tracker update (Blizzard may reset text it reuses). Each text's
-- original font is remembered for "Game default"; sizes and outlines are kept.
local original = setmetatable({}, { __mode = "k" }) -- the font the game gave each text
local ours = setmetatable({}, { __mode = "k" })     -- the font we last put on it (nil: none)
local function applyTo(fs, path)
	if not (fs and fs.GetFont and fs.SetFont) then return false end
	local file, size, flags = fs:GetFont()
	if not (file and size) then return false end
	-- anything but our own font was set by the game (first time, or Blizzard reset reused text): that is the original
	if ours[fs] == nil or file ~= ours[fs] then original[fs] = file end
	local want = path or original[fs]
	ours[fs] = path
	if file == want then return false end
	pcall(fs.SetFont, fs, want, size, flags or "")
	return true
end

function api.applyBlockFonts()
	local tracker = ObjectiveTrackerFrame
	if not tracker then return false end
	local path = api.fontPath()
	if not path and next(original) == nil then return false end -- never changed anything: nothing to restore
	local changed = false
	for _, module in ipairs(tracker.modules or {}) do
		if module.Header and applyTo(module.Header.Text, path) then changed = true end
		for _, byId in pairs(type(module.usedBlocks) == "table" and module.usedBlocks or {}) do
			for _, block in pairs(type(byId) == "table" and byId or {}) do
				if type(block) == "table" then
					if applyTo(block.HeaderText, path) then changed = true end
					for _, line in pairs(type(block.usedLines) == "table" and block.usedLines or {}) do
						if type(line) == "table" then
							if applyTo(line.Text, path) then changed = true end
							if applyTo(line.Dash, path) then changed = true end
						end
					end
				end
			end
		end
	end
	if tracker.Header and applyTo(tracker.Header.Text, path) then changed = true end
	return changed
end

-- after Blizzard lays the tracker out: new or reused text gets the font; heights are measured again when it changed
local reapplying, lastRelayout = false, 0
local afterUpdateSoon -- below
local function afterUpdate()
	if reapplying then return end
	if api.applyBlockFonts() and GetTime() - lastRelayout > 1 then -- at most once a second, should Blizzard reset text every update
		lastRelayout = GetTime()
		reapplying = true
		local tracker = ObjectiveTrackerFrame
		if tracker and tracker.MarkDirty then pcall(securecallfunction, tracker.MarkDirty, tracker) end
		reapplying = false
	end
end
api.afterTrackerUpdateFonts = afterUpdate
-- once on the next frame however often the tracker updates in this one (and nothing at all with the game's font)
local soon = false
local function afterUpdateFired() soon = false; afterUpdate() end
function afterUpdateSoon()
	if soon or not api.fontPath() then return end
	soon = true
	C_Timer.After(0, afterUpdateFired)
end

-- Apply the choice everywhere: tracker, guide, zone headers, More quests, settings window.
function api.applyFont()
	applyTrackerFont()
	afterUpdate()
	local relayout = root.objectives.relayout
	if relayout then pcall(relayout) end
	if root.objectives.invalidateText then pcall(root.objectives.invalidateText) end
	if api.applyZoneHeaders then api.applyZoneHeaders() end
	if api.rebuildMoreQuests then api.rebuildMoreQuests() end
	if api.applyConfigFonts then api.applyConfigFonts() end
	local tracker = ObjectiveTrackerFrame
	if tracker and tracker.MarkDirty then pcall(securecallfunction, tracker.MarkDirty, tracker) end
	if api.applyLayout then api.applyLayout() end
end

function api.setFont(key)
	ns.db.font = key or "default"
	api.applyFont()
end

ns.onLogin[#ns.onLogin + 1] = function()
	if api.fontPath() then applyTrackerFont() end
	local tracker = ObjectiveTrackerFrame
	if tracker and type(tracker.Update) == "function" then
		hooksecurefunc(tracker, "Update", afterUpdateSoon)
	elseif ObjectiveTrackerContainerMixin and ObjectiveTrackerContainerMixin.Update then
		hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", afterUpdateSoon)
	end
	C_Timer.After(1, afterUpdate)
	-- Blizzard re-applies its text size to the font objects when the tracker's text size changes
	if ObjectiveTrackerManager and ObjectiveTrackerManager.SetTextSize then
		hooksecurefunc(ObjectiveTrackerManager, "SetTextSize", function() if api.fontPath() then applyTrackerFont() end end)
	end
end
