--/*******************/ IMPORTS /*************************/--

-- File init

local events = NysTDL.events
NysTDL.events = events

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local chat = NysTDL.chat
local widgets = NysTDL.widgets
local tabsFrame = NysTDL.tabsFrame
local optionsManager = NysTDL.optionsManager

-- Secondary aliases

local L = libs.L
local AceTimer = libs.AceTimer
local AceEvent = libs.AceEvent

--/*******************************************************/--

-- Variables

local warnTimerTime = 3600 -- in seconds (1 hour)
local warnTimer

--/*******************/ EVENT HANDLERS /*************************/--

function events:PLAYER_LOGIN()
	local disabled = optionsManager.optionsTable.args.main.args.chat.args.groupWarnings.args.hourlyReminder.disabled
	if NysTDL.acedb.global.UI_reloading then -- just to be sure that it wasn't a reload, but a genuine player log in
		NysTDL.acedb.global.UI_reloading = false

		if NysTDL.acedb.global.warnTimerRemaining > 0 then -- this is for the special case where we logged in, but reloaded before the 20 sec timer activated, so we just try it again
			warnTimer = AceTimer:ScheduleTimer(function() -- after reloading, we restart the warn timer from where we left off before the reload
				if NysTDL.acedb.profile.hourlyReminder and not disabled() then -- without forgetting that it's the hourly reminder timer this time
					chat:Warn()
				end
				warnTimer = AceTimer:ScheduleRepeatingTimer(function()
					if NysTDL.acedb.profile.hourlyReminder and not disabled() then
						chat:Warn()
					end
				end, warnTimerTime)
			end, NysTDL.acedb.global.warnTimerRemaining)
			return
		end
	end

	NysTDL.acedb.global.warnTimerRemaining = 0
	AceTimer:ScheduleTimer(function() -- 20 secs after the player logs in, we check if we need to warn him about the remaining items
		if core.loaded then -- just to be sure
			chat:Warn()
			warnTimer = AceTimer:ScheduleRepeatingTimer(function()
				if NysTDL.acedb.profile.hourlyReminder and not disabled() then
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
		NysTDL.acedb.global.UI_reloading = true
		NysTDL.acedb.global.warnTimerRemaining = AceTimer:TimeLeft(warnTimer) -- if we are reloading, we keep in mind how much time there was left to our repeating warn timer
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

	local LoadAddOn_Blizzard_EncounterJournal = false
	hooksecurefunc(C_AddOns, "LoadAddOn", function(name)
		if LoadAddOn_Blizzard_EncounterJournal then
			return
		end

		if name ~= "Blizzard_EncounterJournal" then
			return
		end

		if not EncounterJournal then
			return
		end

		hooksecurefunc("EncounterJournal_OnClick", function(self)
			if IsModifiedClick("CHATLINK") then -- basically IsShiftKeyDown()
				if self.link then
					widgets:EditBoxInsertLink(self.link)
				end
			end
		end)
		hooksecurefunc("EncounterJournalBossButton_OnClick", function(self)
			if IsModifiedClick("CHATLINK") then -- basically IsShiftKeyDown()
				if self.link then
					widgets:EditBoxInsertLink(self.link)
				end
			end
		end)

		LoadAddOn_Blizzard_EncounterJournal = true
	end)
end
