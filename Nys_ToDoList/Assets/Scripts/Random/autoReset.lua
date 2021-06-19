-- Namespaces
local addonName, addonTable = ...

local autoReset = addonTable.autoReset

--/*******************/ AUTO-RESET FUNCTIONS /*************************/--

-- // Automatic reset calculations

local function getHoursUntilReset(dateValue)
  local n = 0
  local value = dateValue.hour

  while value ~= NysTDL.db.profile.dailyHour do
    n = n + 1
    value = value + 1
    if value == 24 then
      value = 0
    end
  end

  if n == 0 then
    n = 24
  end

  return n - 1 -- because it's a countdown (it's like min and sec are also displayed)
end

local function getDaysUntilReset(dateValue)
  local n = 0
  local value = dateValue.wday

  if dateValue.hour >= NysTDL.db.profile.dailyHour then
    value = value + 1
    if value == 8 then
      value = 1
    end
  end

  while value ~= NysTDL.db.profile.weeklyDay do
    n = n + 1
    value = value + 1
    if value == 8 then
      value = 1
    end
  end

  return n -- same, but a bit more complicated since it depends on the daily reset hour
end

local T_getTimeUntilReset = {}
function autoReset.getTimeUntilReset()
  local dateValue = date("*t")

  wipe(T_getTimeUntilReset)
  T_getTimeUntilReset.days = getDaysUntilReset(dateValue)
  T_getTimeUntilReset.hour = getHoursUntilReset(dateValue)
  T_getTimeUntilReset.min = math.abs(dateValue.min - 59)
  T_getTimeUntilReset.sec = math.abs(dateValue.sec - 59)

  return T_getTimeUntilReset
end

local T_getSecondsToReset = {}
function autoReset.getSecondsToReset()
  local timeUntil = autoReset.getTimeUntilReset()

  wipe(T_getSecondsToReset)
  T_getSecondsToReset.weekly =
       timeUntil.days * 24 * 60 * 60
     + timeUntil.hour * 60 * 60
     + timeUntil.min * 60
     + timeUntil.sec
     + time()
  T_getSecondsToReset.daily =
       timeUntil.hour * 60 * 60
     + timeUntil.min * 60
     + timeUntil.sec
     + time()

  return T_getSecondsToReset
end
