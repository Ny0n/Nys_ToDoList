-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local autoReset = addonTable.autoReset
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

--/*******************/ TABS RESET MANAGMENT /*************************/--

-- // reset data

-- managment

function resetManager:NewRawTimeData()
	return {
		hour = 0,
		min = 0,
		sec = 0,
		timeUntil = time(),
	}
end

function resetManager:UpdateTimeData(timeData, hour, min, sec)
	timeData.hour = utils:Clamp(hour, 0, 23)
	timeData.min = utils:Clamp(min, 0, 59)
	timeData.sec = utils:Clamp(sec, 0, 59)
	resetManager:UpdateAllTimers()
end

function resetManager:NewResetData()
	local resetData = {
		isInterval = false,
		interval = resetManager:NewRawTimeData(), -- used for the interval reset data
		resetTimes = {
			["Reset 1"] = resetManager:NewRawTimeData(), -- min 1 reset, can be renamed / removed / added
			-- ...
		},
	}

  -- reset = { -- key in tab
  --   isSameEachDay = true,
  --   sameEachDay = resetManager:NewResetData(), -- isSameEachDay reset data
  --   days = { -- the actual reset times used for the auto reset on each given day
	--	 -- [2] = resetData,
	--	 -- [3] = resetData,
	--	 -- ...
	--   },
	--   saves = { -- so that when we uncheck isSameEachDay, we recover each day's own reset data
	-- 	 -- [2] = resetData,
	-- 	 -- [3] = resetData,
	-- 	 -- ...
	--   },
  -- },

  return resetData
end

-- interval

function resetManager:UpdateIsInterval(resetData, state)
	if state == nil then state = false end
	resetData.isInterval = state
end

-- reset times

function resetManager:AddResetTime(resetData, resetTimeName)
	if resetData.resetTimes[resetTimeName] then
		-- TODO message
		return false
	end

	resetData.resetTimes[resetTimeName] = resetManager:NewRawTimeData()
	resetManager:UpdateAllTimers()

	return resetData.resetTimes[resetTimeName]
end

function resetManager:CanRemoveResetTime(resetData)
  return not #resetData.resetTimes <= 1
end

function resetManager:RemoveResetTime(resetData, resetTimeName)
	if not resetData.resetTimes[resetTimeName] then
		-- TODO message
    -- should never happen?
		return true
	end

  if not resetManager:CanRemoveResetTime(resetData) then return false end -- safety check

	resetData.resetTimes[resetTimeName] = nil
	resetManager:UpdateAllTimers()

	return true
end

function resetManager:RenameResetTime(resetData, oldResetTimeName, newResetTimeName)
	if resetData.resetTimes[newResetTimeName] then
		-- TODO message name already exists
		return false
	end

	resetData.resetTimes[newResetTimeName] = resetData.resetTimes[oldResetTimeName]
	resetData.resetTimes[oldResetTimeName] = nil

	return true
end

-- // reset days

function resetManager:UpdateIsSameEachDay(tabID, state)
  -- state means checking / unchecking the isSameEachDay checkbox for the tab tabID
  -- resetData is the selected reset data to share
  local tabData = select(3, dataManager:Find(tabID))
  tabData.reset.isSameEachDay = state

  -- for each day the tab has:
  -- if we are checking, we set every day to have the same tab reset data
  -- if we are unchecking, we reset each day to their own saved reset data (if they had any)
	if state then
		-- we save each day's reset data so that we can find them when we uncheck isSameEachDay
		for day in pairs(tabData.reset.days) do
	    tabData.reset.saves[day] = tabData.reset.days[day]
			tabData.reset.days[day] = tabData.reset.sameEachDay
	  end
	else
		-- when unchecking, we reapply the saved data, or create a new one if there isn't any
		for day in pairs(tabData.reset.days) do
			tabData.reset.days[day] = tabData.reset.saves[day] or resetManager:NewResetData()
	  end
	end
	resetManager:UpdateAllTimers()
end

function resetManager:UpdateResetDay(tabID, day, state)
  -- day is a number between 1-7
  -- state means adding / removing the day (chen checking the radio button)
  local tabData = select(3, dataManager:Find(tabID))

	if state then -- when adding a new day
	  tabData.reset.days[day] = tabData.reset.isSameEachDay and tabData.reset.sameEachDay or tabData.reset.saves[day] or resetManager:NewResetData()
	else -- when removing a day
		tabData.reset.saves[day] = tabData.reset.days[day] -- we save it just in case
		tabData.reset.days[day] = nil -- and we delete it
	end
	resetManager:UpdateAllTimers()
end

--/*******************/ AUTOMATIC RESET MANAGMENT /*************************/--

-- this table is to keep track of every currently active timer IDs for every tab
local activeTimerIDs = {
	-- [tabID] = { 5, 22, 45 }, (timerIDs)
	-- [tabID] = { 1, 78, 12 }, (timerIDs)
	-- ...
}
function resetManager:Initialize(profileChanged)
	-- called on addon load
	if profileChanged ~= nil then
		profileChanged = false -- only affects the new profile's tabs
		-- when we're here, it means that the profile just changed,
		-- so we cancel every timer we had started, without removing the saved var data in each tab
		for _,timerIDs in pairs(activeTimerIDs) do
			for timerPos,timerID in pairs(timerIDs) do
				NysTDL:CancelTimer(timerID)
			end
		end
		wipe(activeTimerIDs)
	end

	local currentTime = time()
	for tabID, tabData in dataManager:ForEach(enums.tab, profileChanged) do -- for every concerned tab
		-- first we check if we already passed a previously reset time,
		-- in which case we uncheck the tab
		for timerPos,targetTime in pairs(tabData.reset.nextResetTimes) do
			if currentTime > targetTime then
				dataManager:UncheckTab(tabID)
				break
			end
		end
		wipe(tabData.reset.nextResetTimes)

		-- then we start the new timers
		resetManager:StartNextTimers(tabID)
	end
end

function resetManager:StartNextTimers(tabID)
	-- // the big important function to manage each tab's resets

	-- variables
	local tabData = select(3, dataManager:Find(tabID))
	local reset = tabData.reset
	local nextResetTimes = reset.nextResetTimes
	local currentTime, currentDate = time(), date("*t")

	-- first we cancel every active timer for the tab (if there were any),
	-- as well as removing the content of the saved tab data (nextResetTimes), since we're gonna refill it anyways
	if type(activeTimerIDs[tabID]) ~= "table" then activeTimerIDs[tabID] = {} end -- local var init
	for timerPos,timerID in pairs(activeTimerIDs[tabID]) do
		NysTDL:CancelTimer(timerID)
	end
	wipe(activeTimerIDs[tabID])
	wipe(nextResetTimes)

	-- and finally, we do everything in order to find and start timers for the next resets
	if reset.days[currentDate.wday] then -- if the tab has resets today
		for name,resetTime in pairs(reset.days[currentDate.wday].resetTimes) do -- for each of them
			-- we check if they have passed or not
			if currentDate.hour <= resetTime.hour and currentDate.min <= resetTime.min and currentDate.sec <= resetTime.sec then

			else -- passed
				if resetTime.timeUntil then

				end
			end
		end
	end
end

function resetManager:StartTimer(tabID, targetTime)
	local tabData = select(3, dataManager:Find(tabID))
	local nextResetTimes = tabData.reset.nextResetTimes
	if not nextResetTimes.n then nextResetTimes.n = 0 end -- timers pos init
	nextResetTimes.n = nextResetTimes.n + 1

	local delay = targetTime - time()
	local timerID = NysTDL:ScheduleTimer("StartResetTimer", delay, tabID, nextResetTimes.n, resetManager.ResetTab)
	nextResetTimes[nextResetTimes.n] = targetTime -- this if to know if we need to reset tabs at log-in (or profile switch)
	activeTimerIDs[tabID][nextResetTimes.n] = timerID -- we keep track of the timerIDs
end

function resetManager.ResetTab(tabID, timerPos)
	-- auto reset function, called by timers

	-- first we uncheck the tab
	dataManager:UncheckTab(tabID)

	-- then we remove the nextResetTime corresponding to the current reset
	local tabData = select(3, dataManager:Find(tabID))
	tabData.reset.nextResetTimes[timerPos] = nil

	-- we remove the current timer from the active ones
	activeTimerIDs[tabID][timerPos] = nil

	-- and finally, we check if we need to restart timers for the tab
	if not next(tabData.reset.nextResetTimes) then -- so if the last reset for the day was done
		resetManager:StartNextTimers(tabID) -- we find the next valid day and restart new timers
	end
end


--
-- function resetManager:GetSecondsUntil(day, timeData)
-- 	local currentDate = date("*t")
-- 	local secondsUntil = resetManager:getDaysUntil(day, currentDate) * 60 * 60 * 24
-- 		+ resetManager:getHoursUntil(timeData.hour, currentDate) * 60 * 60
-- 		+ resetManager:getMinsUntil(timeData.min, currentDate) * 60
-- 		+ resetManager:getSecsUntil(timeData.sec, currentDate)
--   return secondsUntil
-- end
--
-- function NysTDL:StartResetTimer()
-- 	-- body...
-- end
--
-- function resetManager.ResetTab(tabID, timerPos)
-- 	dataManager:UncheckTab(tabID)
-- 	table.remove(activeTimerIDs, timerPos)
-- 	table.insert(activeTimerIDs, NysTDL:ScheduleTimer("StartResetTimer", 60*60*24*7, tabID, resetManager.ResetTab))
-- end
--
-- local activeTimerIDs = {}
-- function resetManager:UpdateAllTimers()
-- 	for k,v in pairs(activeTimerIDs) do
-- 		NysTDL:CancelTimer(v) -- first we cancel every timer
-- 		table.remove(activeTimerIDs, k)
-- 	end
--
-- 	for i=1,2 do
-- 		local tabsList = select(3, resetManager:GetData(i==2))
-- 		for tabID in pairs(tabsList) do -- for each tab
-- 			if tabID == "orderedTabIDs" then goto nextTab end
-- 			local reset = tabsList[tabID].reset
-- 			for day,resetData in pairs(reset.days) do -- for each checked days
-- 				for name,resetTime in pairs(resetData.resetTimes) do -- and for each reset time for those days
-- 					local timeUntil = resetManager:GetSecondsUntil(day, resetTime)
-- 					table.insert(activeTimerIDs, NysTDL:ScheduleTimer("StartResetTimer", timeUntil, tabID, #activeTimerIDs+1, resetManager.ResetTab))
-- 				end
-- 				if reset.isSameEachDay then break end -- only one day in this case
-- 			end
-- 			::nextTab::
-- 		end
-- 	end
-- end

function xxx:CreateDefaultTabs()
	-- once per profile, we create the default addon tabs (All, Daily, Weekly)

	-- // Profile

	for g=1,2 do
		local isGlobal = g == 2

		-- Daily
		local dailyTabData = dataManager:CreateTab("Daily") -- isSameEachDay already true
		local dailyTabID = dataManager:AddTab(dailyTabData, isGlobal)
		for i=1,7 do
			resetManager:UpdateResetDay(dailyTabID, i, true)
		end
		resetManager:UpdateTimeData(dailyTabData.reset.sameEachDay, 9, 0, 0)

		-- Weekly
		local weeklyTabData = dataManager:CreateTab("Weekly") -- isSameEachDay already true
		local weeklyTabID = dataManager:AddTab(weeklyTabData, isGlobal)
		resetManager:UpdateResetDay(weeklyTabID, 4, true) -- only wednesday
		resetManager:UpdateTimeData(weeklyTabData.reset.sameEachDay, 9, 0, 0)

		-- All
		local allTabID = dataManager:AddTab(dataManager:CreateTab("All"), isGlobal)
		dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
		dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)
	end
end
