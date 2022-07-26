--/*******************/ IMPORTS /*************************/--

-- File init
local resetManager = NysTDL.resetManager
NysTDL.resetManager = resetManager -- for IntelliSense

-- Primary aliases
local libs = NysTDL.libs
local chat = NysTDL.chat
local utils = NysTDL.utils
local enums = NysTDL.enums
local dataManager = NysTDL.dataManager

-- Secondary aliases
local L = libs.L
local AceTimer = libs.AceTimer

--/*******************************************************/--

-- Variables

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
			[enums.defaultResetTimeName] = private:NewRawTimeData(), -- min 1 reset, can be renamed / removed / added
			-- ...
		},
	}

	-- reset = { -- key in tab
	-- 	configureDay = {1-7},
	-- 	configureResetTime = resetTimeName,
	-- 	isSameEachDay = true,
	-- 	sameEachDay = private:NewResetData(), -- isSameEachDay reset data
	-- 	days = { -- the actual reset times used for the auto reset on each given day
	-- 		-- [2] = resetData,
	-- 		-- [3] = resetData,
	-- 		-- ...
	-- 	},
	-- 	saves = { -- so that when we uncheck isSameEachDay, we recover each day's own reset data
	-- 		-- [2] = resetData,
	-- 		-- [3] = resetData,
	-- 		-- ...
	-- 	},
	-- },

  return resetData
end

function resetManager:GetNbResetTimes(resetData)
	local nb = 0
	for _ in pairs(resetData.resetTimes) do
		nb = nb + 1
	end
	return nb
end

-- interval -- TDLATER future update

function resetManager:UpdateIsInterval(resetData, state)
	if state == nil then state = false end
	resetData.isInterval = state
end

-- reset times

function resetManager:AddResetTime(tabID, resetData)
	-- first we find a good name for the new reset
	local nb = resetManager:GetNbResetTimes(resetData)
	local resetTimeName
	repeat
		resetTimeName = L["Reset"]..' '..tostring(nb+1)
		nb = nb + 1
	until not resetData.resetTimes[resetTimeName]

	resetData.resetTimes[resetTimeName] = private:NewRawTimeData()

	private:StartNextTimers(tabID) -- update

	-- we select the new reset time
	local tabData = select(3, dataManager:Find(tabID))
	tabData.reset.configureResetTime = resetTimeName

	return resetData.resetTimes[resetTimeName]
end

function resetManager:CanRemoveResetTime(resetData)
	return not (resetManager:GetNbResetTimes(resetData) <= 1)
end

function resetManager:RemoveResetTime(tabID, resetData, resetTimeName)
	if not resetData.resetTimes[resetTimeName] then
		-- should never happen
		return true
	end

	if not resetManager:CanRemoveResetTime(resetData) then -- safety check, should never happen bc there is a pre-check
		return false
	end

	resetData.resetTimes[resetTimeName] = nil

	private:StartNextTimers(tabID) -- update

	return true
end

function resetManager:RenameResetTime(tabID, resetData, oldResetTimeName, newResetTimeName)
	if resetData.resetTimes[newResetTimeName] then
		chat:Print(L["This name already exists"])
		return false
	end

	resetData.resetTimes[newResetTimeName] = resetData.resetTimes[oldResetTimeName]
	resetData.resetTimes[oldResetTimeName] = nil

	return true
end

function resetManager:UpdateTimeData(tabID, timeData, hour, min, sec)
	if not timeData.hour or not timeData.min or not timeData.sec then
		error("UpdateTimeData error: timeData is not valid") -- KEEP
	end

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
	-- [tabID] = { -- (timerIDs)
	-- 	[timerResetID] = 5,
	-- 	[timerResetID] = 22,
	-- 	[timerResetID] = 45
	-- },
	-- [tabID] = { -- (timerIDs)
	-- 	[timerResetID] = 1,
	-- 	[timerResetID] = 78,
	-- 	[timerResetID] = 12
	-- },
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

	local timeUntil = T_getSecondsUntil
	wipe(timeUntil)

	-- // the big scary code below is the "simplification" of this commented out one
	-- if resetTime.hour < currentDate.hour then
	-- 	removeOne(timeUntil, "days", 7)
	-- elseif resetTime.hour == currentDate.hour then
	-- 	if resetTime.min < currentDate.min then
	-- 		removeOne(timeUntil, "days", 7)
	-- 	elseif resetTime.min == currentDate.min then
	-- 		if resetTime.sec < currentDate.sec then
	-- 			removeOne(timeUntil, "days", 7)
	-- 		end
	-- 	end
	-- end

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
	for _,timerID in pairs(activeTimerIDs[tabID]) do
		AceTimer:CancelTimer(timerID)
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
				local secondsUntil = getSecondsUntil(currentDate, targetDay, resetTime)
				if secondsUntil <= 86400 and secondsUntil > 0 then
					-- if the targeted reset time is still ahead of us
					-- then we start a timer for it
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
			if secondsUntil == 0 then secondsUntil = 604800 end
			private:StartTimer(tabID, currentTime, secondsUntil)
		end
	end
end

function private:StartTimer(tabID, currentTime, secondsUntil)
	-- IMPORTANT this func will never be called with secondsUntil == 0, it's at least 1 sec
	-- (I'm doing specific verifications for this at the places I'm calling this func)
	-- this means that we can't start a timer that will instantly finish, it will either find an other one (the next one) or make it loop one week

	local timerResetID = dataManager:NewID()
	local timerID = AceTimer:ScheduleTimer("Timer_ResetTab", secondsUntil, tabID, timerResetID)
	activeTimerIDs[tabID][timerResetID] = timerID -- we keep track of the timerIDs

	-- and we keep track of the targeted time of the timer,
	-- this if to know if we need to reset tabs at log-in (or profile switch)
	local tabData = select(3, dataManager:Find(tabID))
	local targetTime = currentTime + secondsUntil
	tabData.reset.nextResetTimes[timerResetID] = targetTime
end

function AceTimer:Timer_ResetTab(tabID, timerResetID)
	-- auto reset function, called by timers
	-- (there are some checks to make sure that the func was indeed called by timers, and not by the player in-game)
	if not tabID or not timerResetID then return end

	-- first we remove the nextResetTime corresponding to the current reset
	local tabData = select(3, dataManager:Find(tabID)) -- this will error if the ID is not valid
	if not tabData.reset.nextResetTimes[timerResetID] then return end
	tabData.reset.nextResetTimes[timerResetID] = nil

	-- as well as removing the current timer from the active ones
	activeTimerIDs[tabID][timerResetID] = nil

	-- then we uncheck the tab (this is the auto-uncheck func after all)
	dataManager:ToggleTabChecked(tabID, false)

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
			for _,timerID in pairs(timerIDs) do
				AceTimer:CancelTimer(timerID)
			end
		end
		wipe(activeTimerIDs)
	end

	local currentTime = time()
	for tabID,tabData in dataManager:ForEach(enums.tab, profileChanged) do -- for every concerned tab
		-- first we check if we already passed a previous reset time,
		-- in which case we uncheck the tab
		for _,targetTime in pairs(tabData.reset.nextResetTimes) do
			if currentTime >= targetTime then
				dataManager:ToggleTabChecked(tabID, false)
				autoResetedThisSession = true
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
			-- [timerResetID] = 115884212 (time() + timeUntil)
			-- [timerResetID] = 115847721 (time() + timeUntil)
			-- ...
		},
	}
end

function private:RelinkIsSameEachDay(tabData)
	-- this is necessary because for this feature I'm using refs with tables
	-- and since it's saved in the saved variables files at the end of the day,
	-- the refs dissapear, so I'm relinking them at addon reload here
	local reset = tabData.reset
	if not reset.isSameEachDay then return end

	for day in pairs(reset.days) do
		reset.days[day] = reset.sameEachDay
	end
end

--@do-not-package@
-- luacheck: push ignore

-- debug func
function resetManager:PrintTimeDiff(timerResetID, ttime)
	do return end

	local ctime = time()
	local days, hours, mins, secs = 0, 0, 0, 0
	local diff = math.abs(ttime - ctime)
	while diff>=86400 do
		diff = diff - 86400
		days = days + 1
	end
	while diff>=3600 do
		diff = diff - 3600
		hours = hours + 1
	end
	while diff>=60 do
		diff = diff - 60
		mins = mins + 1
	end
	secs = diff
	-- print (string.sub(timerResetID, 1, 3), string.format("Difference: (%s) %d days, %d hours, %d mins, %d secs", ttime > ctime and '+' or '-', days, hours, mins, secs))
end

-- luacheck: pop
--@end-do-not-package@
