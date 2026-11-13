local _, root = ...; local ns = root.objectives
if not ns.rxp then return end

local RXP, db, accent = ns.rxp, ns.db, ns.accent
local MAX_FOLLOWING = ns.MAX_FOLLOWING
local COMMAND_PATTERN = "^%s*(%S*)%s*(%S*)"
local STEPS_PATTERN = "^%d+$"

local function line(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

local function onOff(flag)
	return flag and "on" or "off"
end

local function lockState()
	return (db.arrowLocked or ns.rxpProfile().lockFrames) and "locked" or "unlocked"
end

local function stepsLine(previous)
	local shown = db.followingSteps >= ns.ALL_STEPS and "all" or db.followingSteps
	return "Steps shown ahead: " .. shown .. " (0-" .. MAX_FOLLOWING .. " or all)"
		.. (previous and " (was " .. previous .. ")." or ".")
end

local function arrowLine()
	return "Arrow button " .. onOff(db.arrowButton) .. ", satellites " .. onOff(db.arrowSatellites)
		.. (db.arrowCollapse and " (collapsed in a badge)" or "") .. ", arrow " .. lockState() .. "."
end

local function flip(key)
	return function()
		db[key] = not db[key]
		ns.refresh()
		ns.say(arrowLine())
	end
end

local function helpLine(usage, description, current)
	line((usage and accent("/qt " .. usage) .. "  " or "") .. description .. (current and ", now " .. current or ""))
end

local function printHelp()
	line(ns.brand)
	helpLine("toggle", "turn the skin on or off (off brings RestedXP's own windows back)")
	helpLine("<0-" .. MAX_FOLLOWING .. "|all>", "steps shown ahead", db.followingSteps >= ns.ALL_STEPS and "all" or db.followingSteps)
	helpLine("steps", "show the steps-ahead setting (/qt steps <0-" .. MAX_FOLLOWING .. "|all> sets it)")
	helpLine("arrow", "RestedXP's arrow as the step's objective button, on or off", onOff(db.arrowButton))
	helpLine("satellites", "the small objective buttons around the arrow, on or off", onOff(db.arrowSatellites))
	helpLine(nil, "Ctrl+Right-click on the arrow locks it in place or unlocks it", lockState())
	helpLine("badge", "collapse two or more satellites into one +N badge that opens on hover", onOff(db.arrowCollapse))
	helpLine("status", "current state")
	helpLine("restart", "start the current guide again from its first step")
	helpLine("why", "the latest guide and step moves, who made them, and why RestedXP passed steps")
	helpLine("welcome", "show the guide chooser screen")
end

local function printStatus()
	local snapshot = ns.snapshot()
	ns.say(onOff(db.enabled) .. ", RestedXP " .. ns.rxpRelease())
	if ns.suspended and ns.suspended() then line("Stood down this session: RestedXP's guide data could not be read. /qt toggle tries again.") end
	if ns.missingRxp and #ns.missingRxp > 0 then
		line("Not in this RestedXP version (those parts are skipped): " .. table.concat(ns.missingRxp, ", "))
	end
	line(arrowLine())
	if not snapshot then
		if not db.enabled then
			line("Use /qt toggle to show it.")
		elseif not RXP.currentGuide or RXP.currentGuide.empty then
			line("No RestedXP guide loaded.")
		else
			line("No steps left to show.")
		end
		return
	end
	line(snapshot.title .. (snapshot.subtitle ~= "" and ", " .. snapshot.subtitle or "") .. ": " .. snapshot.counter)
	line((#snapshot.entries - snapshot.following) .. " active, " .. snapshot.following .. " ahead. " .. stepsLine())
end

ns.printStatus = printStatus

local function setSteps(text)
	local steps = text:lower() == "all" and ns.ALL_STEPS or tonumber(text:match(STEPS_PATTERN))
	if not steps or steps > ns.ALL_STEPS then
		line("Expects a number from 0 to " .. MAX_FOLLOWING .. ", or all. " .. stepsLine())
		return
	end
	local previous = db.followingSteps
	db.followingSteps = steps
	ns.refresh()
	line(stepsLine(previous))
end

local COMMANDS = {
	toggle = function()
		db.enabled = not db.enabled
		if db.enabled and ns.resumeAfterStandDown then ns.resumeAfterStandDown() end
		ns.updateWindows()
		ns.refresh(true)
		ns.say(db.enabled and "on." or "off: RestedXP's own windows are back.")
	end,
	steps = function(argument)
		if argument == "" then line(stepsLine()) else setSteps(argument) end
	end,
	arrow = flip("arrowButton"),
	satellites = flip("arrowSatellites"),
	badge = flip("arrowCollapse"),
	welcome = ns.showWelcome,
	status = printStatus,
	restart = function() if ns.settings and ns.settings.restartGuide then ns.settings.restartGuide() end end,
	why = function() if ns.printMoves then ns.printMoves() end end,
}

-- The RXP Tracker's commands, typed after /qt (Tracker/Core.lua passes on what it does not know). Returns whether the
-- command was one of these; "help" prints them.
ns.commandNames = {}
for name in pairs(COMMANDS) do ns.commandNames[name] = true end
function ns.runCommand(input)
	local command, argument = (input or ""):match(COMMAND_PATTERN)
	command = (command or ""):lower()
	local run = COMMANDS[command]
	if run then
		run(argument)
		return true
	elseif command:match("^%-?%d") or command == "all" then
		setSteps(command)
		return true
	elseif command == "help" then
		printHelp()
		return true
	end
	return false
end
ns.printHelp = printHelp
