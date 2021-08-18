-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local utils = addonTable.utils
local enums = addonTable.enums
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager

-- Variables
local L = core.L

local private = {}

local autoResetedThisSession = false

--/*******************/ TABS RESET MANAGMENT /*************************/--

-- // reset data

function resetManager:autoResetedThisSessionGET()
  return autoResetedThisSession
end

-- managment

function private:NewRawTimeData()
	return {
		hour = 0,
		min = 0,
		sec = 0,
	}
end

function private:NewResetData()
	local resetData = {
		-- isInterval = false,
		-- interval = private:NewRawTimeData(), -- used for the interval reset data
		resetTimes = {
			["Reset 1"] = private:NewRawTimeData(), -- min 1 reset, can be renamed / removed / added
			-- ...
		},
	}

  -- reset = { -- key in tab
  --   configureDay = {1-7},
  --   configureResetTime = resetTimeName,
  --   isSameEachDay = true,
  --   sameEachDay = private:NewResetData(), -- isSameEachDay reset data
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

-- interval -- TODO future update

function resetManager:UpdateIsInterval(resetData, state)
	if state == nil then state = false end
	resetData.isInterval = state
end

-- reset times

function resetManager:AddResetTime(tabID, resetData)
  local nb = 0
  for _ in pairs(resetData.resetTimes) do
    nb = nb + 1
  end

  local resetTimeName
  repeat
    resetTimeName = "Reset"..' '..tostring(nb+1)
    nb = nb + 1
  until not resetData.resetTimes[resetTimeName]

	resetData.resetTimes[resetTimeName] = private:NewRawTimeData()

	private:StartNextTimers(tabID) -- update

	return resetData.resetTimes[resetTimeName]
end

function private:CanRemoveResetTime(resetData)
  local nb = 0
  for _ in pairs(resetData.resetTimes) do
    nb = nb + 1
  end
  return not (nb <= 1)
end

function resetManager:RemoveResetTime(tabID, resetData, resetTimeName)
	if not resetData.resetTimes[resetTimeName] then
		-- TODO message
    -- should never happen?
		return true
	end

  if not private:CanRemoveResetTime(resetData) then -- safety check
    -- TODO message?
    print("Cannot remove reset -- there must be at least one")
    return false
  end

	resetData.resetTimes[resetTimeName] = nil

	private:StartNextTimers(tabID) -- update

	return true
end

function resetManager:RenameResetTime(tabID, resetData, oldResetTimeName, newResetTimeName)
	if resetData.resetTimes[newResetTimeName] then
		-- TODO message name already exists
		return false
	end

	resetData.resetTimes[newResetTimeName] = resetData.resetTimes[oldResetTimeName]
	resetData.resetTimes[oldResetTimeName] = nil

	return true
end

function resetManager:UpdateTimeData(tabID, timeData, hour, min, sec)
  if not timeData.hour or not timeData.min or not timeData.sec then error("UpdateTimeData error: timeData is not valid") end

  if hour then timeData.hour = utils:Clamp(hour, 0, 23) end
	if min then timeData.min = utils:Clamp(min, 0, 59) end
	if sec then timeData.sec = utils:Clamp(sec, 0, 59) end

	private:StartNextTimers(tabID) -- update
end

-- // reset days

function resetManager:UpdateIsSameEachDay(tabID, state)
  -- state means checking / unchecking the isSameEachDay checkbox for the tab tabID
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
			tabData.reset.days[day] = tabData.reset.saves[day] or private:NewResetData()
	  end
	end

	private:StartNextTimers(tabID) -- update
end

function resetManager:UpdateResetDay(tabID, day, state)
  -- day is a number between 1-7
  -- state means adding / removing the day (chen checking the radio button)
  local tabData = select(3, dataManager:Find(tabID))

	if state then -- when adding a new day
	  tabData.reset.days[day] = tabData.reset.isSameEachDay and tabData.reset.sameEachDay or tabData.reset.saves[day] or private:NewResetData()
	else -- when removing a day
		tabData.reset.saves[day] = tabData.reset.days[day] -- we save it just in case
		tabData.reset.days[day] = nil -- and we delete it
	end

	private:StartNextTimers(tabID) -- update
end

--/*******************/ AUTOMATIC RESET MANAGMENT /*************************/--

-- this table is to keep track of every currently active timer IDs for every tab
local activeTimerIDs = {
	-- [tabID] = { 5, 22, 45 }, (timerIDs)
	-- [tabID] = { 1, 78, 12 }, (timerIDs)
	-- ...
}

local function getDiff(max, current, target)
  -- time is looping (each 60 sec or 60 min or 24 hours or 7 days we loop back)
  -- so this is to get the pure distance between two of those
  -- ex: getDiff between hour (current) 22 and hour (target) 7 is not 22-7, but 22h TO 7h, which is 9h

	if target > current then
		return target - current
	elseif target < current then
		return max - (current - target)
	else
		return 0
	end
end

local function removeOne(timeUntil, type, max)
  -- removes one hour/min/sec to the timeUntil data
	timeUntil[type] = timeUntil[type] - 1
  if timeUntil[type] == -1 then timeUntil[type] = max-1 end
end

local T_getSecondsUntil = {}
local function getSecondsUntil(currentDate, targetDay, resetTime)
	-- returns the number of seconds between the currentDate and the targetDate (wday, hour, min, sec)
	-- FORWARD TIME, meaning not the pure distance between the two dates, but the distance looping at weeks!
	-- (sunday -> monday = 1 day, monday -> sunday = 6 days)
	-- (without loops! :D)

	-- // the big scary if below is the "simplification" of this one:
	-- if resetTime.hour < currentDate.hour then
  -- 	removeOne(timeUntil, "days", 7)
	-- elseif resetTime.hour == currentDate.hour then
	-- 	if resetTime.min < currentDate.min then
	--   	removeOne(timeUntil, "days", 7)
	-- 	elseif resetTime.min == currentDate.min then
	-- 		if resetTime.sec < currentDate.sec then
	-- 	  	removeOne(timeUntil, "days", 7)
	-- 		end
	-- 	end
	-- end

	local timeUntil = T_getSecondsUntil
	wipe(timeUntil)

	timeUntil.days = getDiff(7, currentDate.wday, targetDay)
	if resetTime.hour < currentDate.hour
	or resetTime.hour == currentDate.hour
		and (resetTime.min < currentDate.min
		or resetTime.min == currentDate.min
			and (resetTime.sec < currentDate.sec))
	then
		removeOne(timeUntil, "days", 7)
	end

	timeUntil.hours = getDiff(24, currentDate.hour, resetTime.hour)
	if resetTime.min < currentDate.min
	or resetTime.min == currentDate.min
		and (resetTime.sec < currentDate.sec)
	then
		removeOne(timeUntil, "hours", 24)
	end

	timeUntil.mins = getDiff(60, currentDate.min, resetTime.min)
	if resetTime.sec < currentDate.sec
	then
		removeOne(timeUntil, "mins", 60)
	end

	timeUntil.secs = getDiff(60, currentDate.sec, resetTime.sec)

	local secondsUntil = timeUntil.days * 24 * 60 * 60
		+ timeUntil.hours * 60 * 60
		+ timeUntil.mins * 60
		+ timeUntil.secs

	return secondsUntil
end

function private:StartNextTimers(tabID)
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
	if next(reset.days) then -- if the tab has resets
		-- first we take the current day
		local targetDay = currentDate.wday

		-- if there are resets today, then we go through each of them and start timers for those who are still ahead of us
		if reset.days[targetDay] then
			local foundOne = false
			for name,resetTime in pairs(reset.days[currentDate.wday].resetTimes) do -- for each of them
				if currentDate.hour <= resetTime.hour and currentDate.min <= resetTime.min and currentDate.sec <= resetTime.sec then
					-- if the targeted reset time is still ahead of us
					-- then we start a timer for it
					local secondsUntil = getSecondsUntil(currentDate, targetDay, resetTime)
					private:StartTimer(tabID, currentTime, secondsUntil)
					foundOne = true
				end
			end
			if foundOne then return end
		end

		-- if it's not today, then we find the next reset day, in order
		repeat
			targetDay = targetDay + 1
			if targetDay == 8 then targetDay = 1 end
		until reset.days[targetDay]

		-- then we start every timer for the targeted day (can be one week later at maximum)
		for name,resetTime in pairs(reset.days[targetDay].resetTimes) do -- for each of them
			local secondsUntil = getSecondsUntil(currentDate, targetDay, resetTime)
			private:StartTimer(tabID, currentTime, secondsUntil)
		end
	end
end

function private:StartTimer(tabID, currentTime, secondsUntil)
	-- TODO min 1 sec ?
	local tabData = select(3, dataManager:Find(tabID))
	local nextResetTimes = tabData.reset.nextResetTimes
	if not nextResetTimes.n then nextResetTimes.n = 0 end -- timers pos init
	nextResetTimes.n = nextResetTimes.n + 1

	local timerID = NysTDL:ScheduleTimer("Timer_ResetTab", secondsUntil, tabID, nextResetTimes.n)
	activeTimerIDs[tabID][nextResetTimes.n] = timerID -- we keep track of the timerIDs

	-- and we keep track of the targeted time of the timer,
	-- this if to know if we need to reset tabs at log-in (or profile switch)
	local targetTime = currentTime + secondsUntil
	nextResetTimes[nextResetTimes.n] = targetTime
end

function NysTDL:Timer_ResetTab(tabID, timerPos)
  -- auto reset function, called by timers
  -- (there are some checks to make sure that the func was indeed called by timers, and not by the player in-game)
  if not tabID or not timerPos then return end

	-- first we remove the nextResetTime corresponding to the current reset
	local tabData = select(3, dataManager:Find(tabID)) -- this will error if the ID is not valid
  if not tabData.reset.nextResetTimes[timerPos] then return end
	tabData.reset.nextResetTimes[timerPos] = nil

  -- as well as removing the current timer from the active ones
	activeTimerIDs[tabID][timerPos] = nil

	-- then we uncheck the tab (this is the auto-uncheck func after all)
	dataManager:UncheckTab(tabID)

	-- and finally, we check if we need to restart timers for the tab
	if not next(tabData.reset.nextResetTimes) then -- if the last reset for the day was done
		private:StartNextTimers(tabID) -- we find the next valid day and restart new timers
	end
end

--/*******************/ INITIALIZATION /*************************/--

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
		for timerPos,targetTime in ipairs(tabData.reset.nextResetTimes) do
      print(timerPos, targetTime)
			if currentTime > targetTime then
				dataManager:UncheckTab(tabID)
        print("ResetManager: UncheckTab")
				autoResetedThisSession = true -- TODO redo??
				break
			end
		end
		wipe(tabData.reset.nextResetTimes)

    -- and by the way, we also relink our tables refs (see func details)
    private:RelinkIsSameEachDay(tabData)

		-- then we start the new timers
		private:StartNextTimers(tabID)
	end
end

function resetManager:InitTabData(tabData)
  -- creates the reset data associated with tabs
  tabData.reset = { -- content is user set
    configureDay = nil,
    configureResetTime = nil,
    isSameEachDay = true,
    sameEachDay = private:NewResetData(), -- isSameEachDay reset data
    days = { -- the actual reset times used for the auto reset on each given day
      -- [2] = resetData,
      -- [3] = resetData,
      -- ...
    },
    saves = { -- so that when we uncheck isSameEachDay, we recover each day's own reset data
      -- [2] = resetData,
      -- [3] = resetData,
      -- ...
    },
    nextResetTimes = { -- for when we log on or reload the addon, we first check if a reset date has passed
      n = 0,
      -- [1 (n++)] = 115884212 (time() + timeUntil)
      -- [2 (n++)] = 115847721 (time() + timeUntil)
      -- ...
    },
  }
end

function private:RelinkIsSameEachDay(tabData)
  -- this is necessary because for this feature i'm using refs with tables
  -- and since it's saved in the saved variables files at the end of the day,
  -- the refs dissapear, so i'm relinking them at addon reload here
  local reset = tabData.reset
  if not reset.isSameEachDay then return end

  for day in pairs(reset.days) do
    reset.days[day] = reset.sameEachDay
  end
end
