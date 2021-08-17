-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local events = addonTable.events
local widgets = addonTable.widgets
local optionsManager = addonTable.optionsManager

-- Variables
local L = core.L
local warnTimerTime = 3600 -- in seconds (1 hour)

--/*******************/ EVENT HANDLERS /*************************/--

function NysTDL:PLAYER_LOGIN()
  local disabled = optionsManager.optionsTable.args.main.args.chat.args.groupWarnings.args.hourlyReminder.disabled
  if (NysTDL.db.global.UI_reloading) then -- just to be sure that it wasn't a reload, but a genuine player log in
    NysTDL.db.global.UI_reloading = false

    if (NysTDL.db.global.warnTimerRemaining > 0) then -- this is for the special case where we logged in, but reloaded before the 20 sec timer activated, so we just try it again
      events.warnTimer = self:ScheduleTimer(function() -- after reloading, we restart the warn timer from where we left off before the reload
        if (NysTDL.db.profile.hourlyReminder and not disabled()) then -- without forgetting that it's the hourly reminder timer this time
          chat:Warn()
        end
        events.warnTimer = self:ScheduleRepeatingTimer(function()
          if (NysTDL.db.profile.hourlyReminder and not disabled()) then
            chat:Warn()
          end
        end, warnTimerTime)
      end, NysTDL.db.global.warnTimerRemaining)
      return
    end
  end

  NysTDL.db.global.warnTimerRemaining = 0
  self:ScheduleTimer(function() -- 20 secs after the player logs in, we check if we need to warn him about the remaining items
    if (core.loaded) then -- just to be sure
      chat:Warn()
      events.warnTimer = self:ScheduleRepeatingTimer(function()
        if (NysTDL.db.profile.hourlyReminder and not disabled()) then
          chat:Warn()
        end
      end, warnTimerTime)
    end
  end, 20)
end

--/*******************/ INITIALIZATION /*************************/--

function events:Initialize()
  -- events
  NysTDL:RegisterEvent("PLAYER_LOGIN")

  -- hooks
  hooksecurefunc("ReloadUI", function()
    NysTDL.db.global.UI_reloading = true
    NysTDL.db.global.warnTimerRemaining = NysTDL:TimeLeft(events.warnTimer) -- if we are reloading, we keep in mind how much time there was left to our repeating warn timer
  end) -- this is for knowing when the addon is loading, if it was a UI reload or the player logging in
  hooksecurefunc("ChatEdit_InsertLink", function(...) return widgets:EditBoxInsertLink(...) end) -- this is for adding hyperlinks in my addon edit boxes
end
