-- Profiles (/qt > Settings Window > Profiles): named copies of every setting of the quest tracker
-- (RXPForeverTrackerDB) and the RXP Tracker (RXPForeverTrackerGuideDB). The settings in use always belong to the active
-- profile (saved into it on logout and before another profile loads); "Default" is made from them on first use.
-- Loading a profile writes its values into the settings and reloads the interface, which applies each of them.
-- Export: "RXPFT1:" + base64 of a small text serialisation (no Lua code is ever run on an imported string).
local _, root = ...; local ns = root.tracker
if not ns or root.disabledAll then return end
local api = ns.api

local PREFIX = "RXPFT1:"
local DEFAULT_NAME = "Default"
local MAX_NAME = 40

-- not settings: per-session or bookkeeping values, never copied into or out of a profile
local EXCLUDE_TRACKER = { profiles = true, activeProfile = true, ahValue = true, conflictKept = true,
	savedAutoWatch = true, zoneHidden = true, configPage = true, configTab = true, extra = true, guideScrolls = true,
	showRep = true }
local EXCLUDE_GUIDE = { onboarded = true, questFocus = true, questFocusSaved = true, hidden = true }

local function trackerDB() return ns.db end
local function guideDB()
	local guide = root.objectives
	return (guide and guide.db) or (type(_G.RXPForeverTrackerGuideDB) == "table" and _G.RXPForeverTrackerGuideDB) or nil
end

local function copy(value, depth)
	if type(value) ~= "table" then return value end
	depth = (depth or 0) + 1
	if depth > 20 then return nil end
	local out = {}
	for k, v in pairs(value) do
		if type(k) == "string" or type(k) == "number" then out[k] = copy(v, depth) end
	end
	return out
end

local function settingsOf(source, exclude)
	local out = {}
	for key, value in pairs(source or {}) do
		if type(key) == "string" and not exclude[key] then
			local t = type(value)
			if t == "number" or t == "string" or t == "boolean" or t == "table" then out[key] = copy(value) end
		end
	end
	return out
end

local function snapshot()
	return { tracker = settingsOf(trackerDB(), EXCLUDE_TRACKER), guide = settingsOf(guideDB(), EXCLUDE_GUIDE) }
end

-- replace the settings in use with a profile's (bookkeeping keys stay as they are)
local function applySettings(target, values, exclude)
	if not (target and values) then return end
	for key in pairs(target) do
		if type(key) == "string" and not exclude[key] then target[key] = nil end
	end
	for key, value in pairs(values) do
		if type(key) == "string" and not exclude[key] then target[key] = copy(value) end
	end
end

local function store()
	local db = trackerDB()
	if not db then return nil end
	if type(db.profiles) ~= "table" then db.profiles = {} end
	return db.profiles
end

local function cleanName(name)
	name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if name == "" then return nil, "Type a name for the profile." end
	if #name > MAX_NAME then return nil, ("Names are at most %d letters."):format(MAX_NAME) end
	if name:find("|", 1, true) then return nil, "Names cannot contain |." end
	return name
end

-- first use: "Default" from the settings in use
local function ensure()
	local profiles = store()
	if not profiles then return end
	local db = trackerDB()
	if next(profiles) == nil then profiles[DEFAULT_NAME] = snapshot() end
	if type(db.activeProfile) ~= "string" or not profiles[db.activeProfile] then
		db.activeProfile = profiles[DEFAULT_NAME] and DEFAULT_NAME or next(profiles)
	end
end

function api.profileNames()
	ensure()
	local names = {}
	for name in pairs(store() or {}) do names[#names + 1] = name end
	table.sort(names, function(a, b)
		if a == DEFAULT_NAME then return b ~= DEFAULT_NAME end
		if b == DEFAULT_NAME then return false end
		return a:lower() < b:lower()
	end)
	return names
end

function api.activeProfile()
	ensure()
	local db = trackerDB()
	return db and db.activeProfile or DEFAULT_NAME
end

-- keep the active profile up to date with the settings in use
local function saveActive()
	local profiles = store()
	local db = trackerDB()
	if profiles and db and type(db.activeProfile) == "string" then profiles[db.activeProfile] = snapshot() end
end

-- the settings in use under a name (a new profile, or over an existing one)
function api.saveProfile(name)
	local clean, err = cleanName(name)
	if not clean then return false, err end
	ensure()
	local existed = store()[clean] ~= nil
	store()[clean] = snapshot()
	return true, existed and ("Saved over \"" .. clean .. "\".") or ("Saved \"" .. clean .. "\".")
end

-- write a profile into the settings and make it active; the caller reloads the interface
function api.loadProfile(name)
	ensure()
	local profiles = store()
	local profile = name and profiles[name]
	if not profile then return false, "There is no profile called \"" .. tostring(name) .. "\"." end
	saveActive()
	local db = trackerDB()
	local keepProfiles, keepPos = db.profiles, db.pos
	applySettings(db, profile.tracker, EXCLUDE_TRACKER)
	applySettings(guideDB(), profile.guide, EXCLUDE_GUIDE)
	db.profiles = keepProfiles
	if type(db.pos) ~= "table" then db.pos = keepPos end
	db.activeProfile = name
	return true
end

function api.deleteProfile(name)
	ensure()
	local profiles = store()
	if not (name and profiles[name]) then return false, "There is no profile called \"" .. tostring(name) .. "\"." end
	if name == api.activeProfile() then return false, "The active profile cannot be deleted: load another one first." end
	profiles[name] = nil
	return true, "Deleted \"" .. name .. "\"."
end

---------------------------------------------------------------------------------------------------------------------
-- Export / import: a text serialisation (numbers, strings, booleans, tables) in base64, so the string survives copying
-- through chat and edit boxes. Decoding reads it back without running anything.
---------------------------------------------------------------------------------------------------------------------
local function serialise(value, out, depth)
	local t = type(value)
	if t == "number" then
		out[#out + 1] = "n" .. string.format("%.17g", value) .. ";"
	elseif t == "string" then
		out[#out + 1] = "s" .. #value .. ":" .. value
	elseif t == "boolean" then
		out[#out + 1] = value and "T" or "F"
	elseif t == "table" and depth < 20 then
		out[#out + 1] = "{"
		local keys = {}
		for k in pairs(value) do
			if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			serialise(k, out, depth + 1)
			serialise(value[k], out, depth + 1)
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "F"
	end
end

local function deserialise(text)
	local pos = 1
	local function read(depth)
		if depth > 20 then error("too deep") end
		local tag = text:sub(pos, pos)
		pos = pos + 1
		if tag == "n" then
			local finish = text:find(";", pos, true)
			if not finish then error("bad number") end
			local n = tonumber(text:sub(pos, finish - 1))
			if not n then error("bad number") end
			pos = finish + 1
			return n
		elseif tag == "s" then
			local colon = text:find(":", pos, true)
			local len = colon and tonumber(text:sub(pos, colon - 1))
			if not len or len < 0 then error("bad string") end
			local s = text:sub(colon + 1, colon + len)
			if #s ~= len then error("bad string") end
			pos = colon + len + 1
			return s
		elseif tag == "T" then return true
		elseif tag == "F" then return false
		elseif tag == "{" then
			local t = {}
			while true do
				if pos > #text then error("unfinished table") end
				if text:sub(pos, pos) == "}" then pos = pos + 1 return t end
				local k = read(depth + 1)
				if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
				t[k] = read(depth + 1)
			end
		end
		error("unexpected data")
	end
	local ok, value = pcall(read, 0)
	if not ok then return nil end
	if pos <= #text then return nil end
	return value
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, 64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

local function encode64(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
		local c3, c4 = math.floor(n / 64) % 64, n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function decode64(text)
	text = text:gsub("[^%w%+/=]", "")
	if #text % 4 ~= 0 then return nil end
	local out = {}
	for i = 1, #text, 4 do
		local chunk = text:sub(i, i + 3)
		local n, pad = 0, 0
		for j = 1, 4 do
			local ch = chunk:sub(j, j)
			local v = B64_INDEX[ch]
			if ch == "=" then v, pad = 0, pad + 1 elseif v == nil then return nil end
			n = n * 64 + v
		end
		local a, b, c = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
		out[#out + 1] = string.char(a) .. (pad < 2 and string.char(b) or "") .. (pad < 1 and string.char(c) or "")
	end
	return table.concat(out)
end

function api.exportProfile(name)
	ensure()
	if name == api.activeProfile() then saveActive() end
	local profile = name and store()[name]
	if not profile then return nil, "There is no profile called \"" .. tostring(name) .. "\"." end
	local out = {}
	serialise({ name = name, tracker = profile.tracker, guide = profile.guide }, out, 0)
	return PREFIX .. encode64(table.concat(out))
end

-- only plain settings come in: string keys, values of the same kind as the setting in use (where there is one)
local function filtered(values, current, exclude)
	local out = {}
	if type(values) ~= "table" then return out end
	for key, value in pairs(values) do
		if type(key) == "string" and not exclude[key] then
			local t = type(value)
			local have = current and current[key]
			if (t == "number" or t == "string" or t == "boolean" or t == "table") and (have == nil or type(have) == t) then
				out[key] = value
			end
		end
	end
	return out
end

-- returns ok, message, the profile's own name (from the string)
function api.importProfile(text, name)
	text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if text:sub(1, #PREFIX) ~= PREFIX then return false, "That is not an RXP ForeverTracker profile string." end
	local raw = decode64(text:sub(#PREFIX + 1))
	local data = raw and deserialise(raw)
	if type(data) ~= "table" or type(data.tracker) ~= "table" then
		return false, "The profile string is damaged or incomplete; copy it again."
	end
	local clean = cleanName((name and name:find("%S")) and name or data.name)
	if not clean then return false, "Type a name for the imported profile." end
	ensure()
	local existed = store()[clean] ~= nil
	store()[clean] = {
		tracker = filtered(data.tracker, trackerDB(), EXCLUDE_TRACKER),
		guide = filtered(data.guide, guideDB(), EXCLUDE_GUIDE),
	}
	return true, (existed and "Replaced \"%s\" with the imported profile." or "Imported \"%s\".") :format(clean), clean
end

-- first use makes "Default"; logging out keeps the active profile up to date
table.insert(ns.onLogin, ensure)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function() if trackerDB() then pcall(saveActive) end end)

api.profileCodec = { serialise = function(v) local out = {} serialise(v, out, 0) return table.concat(out) end,
	deserialise = deserialise, encode64 = encode64, decode64 = decode64 }
