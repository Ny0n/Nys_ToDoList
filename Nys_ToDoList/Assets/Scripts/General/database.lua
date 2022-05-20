-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local utils = addonTable.utils
local enums = addonTable.enums
local widgets = addonTable.widgets
local database = addonTable.database
local migration = addonTable.migration
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

--/*******************/ TABLES /*************************/--
-- generating them inside functions called at initialization,
-- so they all have access to other files' functions and data

-- addon themes (rgb)
database.themes = {
  theme = { 0, 204, 255 }, -- theme
  theme2 = { 0, 204, 102 }, -- theme2
  theme_yellow = { 255, 216, 0 }, -- theme_yellow
  white = { 255, 255, 255 },
  black = { 0, 0, 0 },
  red = { 255, 0, 0 },
  yellow = { 255, 180, 0 },
}

-- AceDB defaults table
database.defaults = {
  global = {
    -- // Version
    addonUpdated = true, -- used to call an update func in init, only once after each addon update
    latestVersion = "", -- used to update the global saved variables once after each addon update

    -- // GLOBAL DATA
    itemsList = {},
    categoriesList = {},
    tabsList = {
      orderedTabIDs = { -- to have an order in which we display the tabs buttons
        -- [tabID], -- [1]
        -- [tabID], -- [2]
        -- ... -- [...]
      },
    },

    -- // Global ID
    nextID = "", -- forever increasing, defaults to the current time (time()) in hexadecimal

    -- // Misc
    tuto_progression = 0,
    -- tutorials_progression = {}, TDLATER
    UI_reloading = false,
    warnTimerRemaining = 0,
  },
  profile = {
    -- // Version
    latestVersion = "", -- used to update the profile saved variables once after each addon update, independent for each profile

    -- // PROFILE DATA
    itemsList = {},
    categoriesList = {},
    tabsList = {
      orderedTabIDs = { -- to have an order in which we display the tabs buttons
        -- [tabID], -- [1]
        -- [tabID], -- [2]
        -- ... -- [...]
      },
    },
    undoTable = {},

    -- // MIGRATION DATA
    migrationData = { -- see private:Failed in migration.lua
      failed = nil,
      saved = nil,
      version = nil,
      errmsg = nil,
      warning = nil,
      tuto = nil,
    },

    -- // Misc
    currentTab = "TOSET", -- currently selected tab ID, set when the default tabs are created
    databrokerMode = enums.databrokerModes.simple,
    lastListVisibility = false,
    lockList = false, -- TDLATER
    lockButton = false, -- TDLATER

    -- // Frame Options
    framePos = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 },
    frameSize = { width = enums.tdlFrameDefaultWidth, height = enums.tdlFrameDefaultHeight },
    frameAlpha = 65,
    frameContentAlpha = 100,
    affectDesc = true,
    descFrameAlpha = 65,
    descFrameContentAlpha = 100,

    -- // Addon Options

    --'General' tab
    minimap = { hide = false, minimapPos = 241, lock = false, tooltip = true }, -- for LibDBIcon
    tdlButton = { show = false, red = false, points = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 } },
    favoritesColor = { 1, 0.5, 0.6 },
    rainbow = false,
    rainbowSpeed = 2,
    rememberUndo = true,
    highlightOnFocus = true,
    keepOpen = false,
    openByDefault = false,

    --'Tabs' tab
    instantRefresh = false, -- profile dependant

    --'Chat Messages' tab
    showChatMessages = true,
    showWarnings = false,
    favoritesWarning = true,
    normalWarning = false,
    hourlyReminder = false,
  }, -- profile
}

--/*******************/ DATABASE FUNCTIONS /*************************/--

-- // DB init & change

-- this func is called once in initialize, on the addon load
-- and also everytime we switch profiles
function database:DBInit()
  dataManager.authorized = false -- there's no calling mainFrame funcs while we're tampering with the database!

  local noTabs = not dataManager:IsID(database.ctab())

  -- default tabs creation
  if noTabs then
    database:CreateDefaultTabs()
  end

  migration:Migrate() -- trying to migrate the old vars

  if noTabs then
    -- !! after the (potential) var migration, we rename the tabs to match the locale,
    -- this is a security in case the locale was not correctly done

    -- we find the main tab IDs to rename them
    for tabID,tabData in dataManager:ForEach(enums.tab, false) do -- TDLATER global
      if tabData.name == enums.mainTabs.all then
        dataManager:Rename(tabID, L["All"])
      elseif tabData.name == enums.mainTabs.daily then
        dataManager:Rename(tabID, L["Daily"])
      elseif tabData.name == enums.mainTabs.weekly then
        dataManager:Rename(tabID, L["Weekly"])
      end
    end
  end

  -- // initialization of elements that need to be updated correctly when the profile changes

  -- remember undos
  if not NysTDL.db.profile.rememberUndo then
    wipe(NysTDL.db.profile.undoTable)
  end

  -- data quantities
  dataManager:UpdateQuantities()

  dataManager.authorized = true
end

function database:ProfileChanged(_, profile)
  -- // here we update (basically in the same order as the core init) everything
  -- that needs an update after a database change

  -- #1 - database (always init a database)
  database:DBInit()

  -- #2 - options
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)

  -- #last-1 - widgets (we update che changes to the UI elements)
  widgets:ProfileChanged()

  -- #last - tabs resets
  resetManager:Initialize(true)
end

-- // specific functions

function database.ctab(newTabID) -- easy access to that specific database variable
  -- sets or gets the currently selected tab ID
  if dataManager:IsID(newTabID) then
    NysTDL.db.profile.currentTab = newTabID
  end
  return NysTDL.db.profile.currentTab
end

function database:CreateDefaultTabs()
	-- once per profile, we create the default addon tabs (All, Daily, Weekly)

  local selectedtabID
	for g=1, 1 do -- TDLATER fix ==> 1, 2
		local isGlobal = g == 2

		-- All
		local allTabID = dataManager:CreateTab(enums.mainTabs.all, isGlobal)

		-- Daily
		local dailyTabID, dailyTabData = dataManager:CreateTab(enums.mainTabs.daily, isGlobal)
    if not isGlobal then selectedtabID = dailyTabID end -- default tab

		-- Weekly
		local weeklyTabID, weeklyTabData = dataManager:CreateTab(enums.mainTabs.weekly, isGlobal)

    -- All data
		dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
		dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)

    -- Daily data (isSameEachDay already true)
    for i=1,7 do resetManager:UpdateResetDay(dailyTabID, i, true) end -- every day
    resetManager:RenameResetTime(dailyTabID, dailyTabData.reset.sameEachDay, enums.defaultResetTimeName, L["Daily"])
		resetManager:UpdateTimeData(dailyTabID, dailyTabData.reset.sameEachDay.resetTimes[L["Daily"]], 9, 0, 0)

    -- Weekly data (isSameEachDay already true)
    resetManager:UpdateResetDay(weeklyTabID, 4, true) -- only wednesday
    resetManager:RenameResetTime(weeklyTabID, weeklyTabData.reset.sameEachDay, enums.defaultResetTimeName, L["Weekly"])
    resetManager:UpdateTimeData(weeklyTabID, weeklyTabData.reset.sameEachDay.resetTimes[L["Weekly"]], 9, 0, 0)
	end

	-- then we set the default tab
  database.ctab(selectedtabID)
end

--/*******************/ INITIALIZATION /*************************/--

function database:Initialize()
  -- Saved variable database
  NysTDL.db = LibStub("AceDB-3.0"):New("NysToDoListDB", self.defaults) -- THE important line
  self:DBInit() -- initialization for some elements of the db

  -- callbacks for database changes
  NysTDL.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
  NysTDL.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
  NysTDL.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
  NysTDL.db.RegisterCallback(self, "OnDatabaseReset", "ProfileChanged")
end
