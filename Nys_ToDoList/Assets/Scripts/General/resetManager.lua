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

function resetManager:NewRawTimeData()
	return {
		hour = 0,
		min = 0,
		sec = 0,
	}
end

function resetManager:NewResetData()
	local resetData = {
		isInterval = false,
		interval = resetManager:NewRawTimeData(),
		resetTimes = {
			["Reset 1"] = resetManager:NewRawTimeData(), -- min 1 reset, can be renamed / removed / added
			-- ...
		},
	}

  -- reset = { -- key in tab
  --   sameEachDay = true,
  --   resetData = resetManager:NewResetData(), -- for the sameEachDay reset data
  --   days = {
  --     -- [2] = resetData,
  --     -- [3] = resetData,
  --     -- ...
  --   },
  -- },

  return resetData
end

-- reset time

function resetManager:AddResetTime(resetData, resetTimeName)
	if resetData.resetTimes[resetTimeName] then
		-- TODO message
		return false
	end

	resetData.resetTimes[resetTimeName] = resetManager:NewRawTimeData()

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

-- reset day

function resetManager:UpdateSameEachDay(tabID, state, resetData)
  -- state means checking / unchecking the sameEachDay checkbox for the tab tabID
  -- resetData is the selected reset data to share
  local tabData = select(4, dataManager:Find(tabID))
  tabData.reset.sameEachDay = state

  -- for each day the tab has:
  -- if we are checking, we set every day to have the same reset data as the currently selected one
  -- if we are unchecking, we reset each day with a new reset data of their own
  for day,resetData in pairs(tabData.reset.days) do -- XXX careful
    tabData.reset.days[day] = state and resetData or resetManager:NewResetData()
  end
end

function resetManager:UpdateResetDay(tabID, day, state)
  -- day is a number between 1-7
  -- state means adding / removing the day (chen checking the radio button)
  local tabData = select(4, dataManager:Find(tabID))
  if state == false then state = nil end

  local sed = tabData.reset.sameEachDay

 -- XXX XXX revoir reset data de la tab, when 0 days hide reset data ?
  -- tabData.reset.days[day] = state and (tabData.reset.sameEachDay and )
end

--/*******************/ AUTOMATIC RESET MANAGMENT /*************************/--

function xxx:CreateDefaultTabs()
	-- once per profile, we create the default addon tabs (All, Daily, Weekly)

	-- // Profile

	-- Daily
	local dailyTabID = dataManager:AddTab(dataManager:CreateTab("Daily"))


	-- All
	local allTabID = dataManager:AddTab(dataManager:CreateTab("All"))
	dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
	dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)
end
