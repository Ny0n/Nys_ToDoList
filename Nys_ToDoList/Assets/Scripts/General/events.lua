-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local libs = addonTable.libs
local core = addonTable.core
local chat = addonTable.chat
local events = addonTable.events
local widgets = addonTable.widgets
local database = addonTable.database
local tabsFrame = addonTable.tabsFrame
local optionsManager = addonTable.optionsManager

-- Variables
local L = libs.L
local AceTimer = libs.AceTimer
local AceEvent = libs.AceEvent

local private = {}

local warnTimerTime = 3600 -- in seconds (1 hour)

--/*******************/ EVENT HANDLERS /*************************/--

function events:PLAYER_LOGIN()
	local disabled = optionsManager.optionsTable.args.main.args.chat.args.groupWarnings.args.hourlyReminder.disabled
	if database.acedb.global.UI_reloading then -- just to be sure that it wasn't a reload, but a genuine player log in
		database.acedb.global.UI_reloading = false

		if database.acedb.global.warnTimerRemaining > 0 then -- this is for the special case where we logged in, but reloaded before the 20 sec timer activated, so we just try it again
			private.warnTimer = AceTimer:ScheduleTimer(function() -- after reloading, we restart the warn timer from where we left off before the reload
				if database.acedb.profile.hourlyReminder and not disabled() then -- without forgetting that it's the hourly reminder timer this time
					chat:Warn()
				end
				private.warnTimer = AceTimer:ScheduleRepeatingTimer(function()
					if database.acedb.profile.hourlyReminder and not disabled() then
						chat:Warn()
					end
				end, warnTimerTime)
			end, database.acedb.global.warnTimerRemaining)
			return
		end
	end

	database.acedb.global.warnTimerRemaining = 0
	AceTimer:ScheduleTimer(function() -- 20 secs after the player logs in, we check if we need to warn him about the remaining items
		if core.loaded then -- just to be sure
			chat:Warn()
			private.warnTimer = AceTimer:ScheduleRepeatingTimer(function()
				if database.acedb.profile.hourlyReminder and not disabled() then
					chat:Warn()
				end
			end, warnTimerTime)
		end
	end, 20)
end

function events:PLAYER_ENTERING_WORLD()
	tabsFrame:Refresh() -- I'm calling WoW APIs in there, and they're only really working after the event PLAYER_ENTERING_WORLD has fired
end

function events:GLOBAL_MOUSE_DOWN()
	tabsFrame:GLOBAL_MOUSE_DOWN() -- so that it's acting like the GameTooltip
end

--/*******************/ INITIALIZATION /*************************/--

function events:Initialize()
	-- events
	AceEvent:RegisterEvent("PLAYER_LOGIN", events.PLAYER_LOGIN)
	AceEvent:RegisterEvent("PLAYER_ENTERING_WORLD", events.PLAYER_ENTERING_WORLD)
	AceEvent:RegisterEvent("GLOBAL_MOUSE_DOWN", events.GLOBAL_MOUSE_DOWN)

	-- hooks
	hooksecurefunc("ReloadUI", function()
		database.acedb.global.UI_reloading = true
		database.acedb.global.warnTimerRemaining = AceTimer:TimeLeft(private.warnTimer) -- if we are reloading, we keep in mind how much time there was left to our repeating warn timer
	end) -- this is for knowing when the addon is loading, if it was a UI reload or the player logging in

	local canInsertLink = true
	hooksecurefunc("ChatEdit_InsertLink", function(...) -- this is for adding hyperlinks in my addon edit boxes
		if canInsertLink then
			AceTimer:ScheduleTimer(function() -- this is a fix to a bug that calls this func 2 times instead of one
				canInsertLink = true
			end, 0.1)
			canInsertLink = false

			return widgets:EditBoxInsertLink(...)
		end
		return true
	end)
end
