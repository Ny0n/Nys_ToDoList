-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local utils = addonTable.utils
local enums = addonTable.enums
local widgets = addonTable.widgets
local database = addonTable.database
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

    -- // Misc
    tuto_progression = 0,
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

    currentTab = "TOSET", -- currently selected tab ID, set when the default tabs are created
    databrokerMode = enums.databrokerModes.simple,

    -- // Misc
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

  -- default tabs creation
  if not dataManager:IsID(database.ctab()) then
    database:CreateDefaultTabs()
  end

  -- checking for an addon update, globally
  if NysTDL.db.global.latestVersion ~= core.toc.version then
    self:GlobalNewVersion()
    NysTDL.db.global.latestVersion = core.toc.version
    NysTDL.db.global.addonUpdated = true
  end

  -- checking for an addon update, for the profile that was just loaded
  if NysTDL.db.profile.latestVersion ~= core.toc.version then
    self:ProfileNewVersion()
    NysTDL.db.profile.latestVersion = core.toc.version
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
  print("PROFILE: ", profile)

  -- #1 - database (always init a database)
  database:DBInit()

  -- #2 - options
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)

  -- #last-1 - widgets (we update che changes to the UI elements)
  widgets:ProfileChanged()

  -- #last - tabs resets
  resetManager:Initialize(true)
end

-- these two functions are called only once, each time there is an addon update
function database:GlobalNewVersion() -- global
  -- // updates the global saved variables once after an update

  if NysTDL.db.global.tuto_progression > 0 then -- if we already completed the tutorial
    -- since i added in the update a new tutorial frame that i want ppl to see, i just go back step in the tuto progression
    tutorialsManager:Previous()
    -- TODO redo
  end
end

function database:ProfileNewVersion() -- profile
  -- // updates each profile saved variables once after an update

  -- by default after each update, we empty the undo table
  wipe(NysTDL.db.profile.undoTable)

  -- var version migration
  database:MigrateVars()
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
		local allTabID = dataManager:CreateTab("All", isGlobal)

		-- Daily
		local dailyTabID, dailyTabData = dataManager:CreateTab("Daily", isGlobal)
    if not isGlobal then selectedtabID = dailyTabID end -- default tab

		-- Weekly
		local weeklyTabID, weeklyTabData = dataManager:CreateTab("Weekly", isGlobal)

    -- All data
		dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
		dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)

    -- Daily data (isSameEachDay already true)
    for i=1,7 do resetManager:UpdateResetDay(dailyTabID, i, true) end -- every day
    resetManager:RenameResetTime(dailyTabID, dailyTabData.reset.sameEachDay, enums.defaultResetTimeName, "Daily")
		resetManager:UpdateTimeData(dailyTabID, dailyTabData.reset.sameEachDay.resetTimes["Daily"], 9, 0, 0)

    -- Weekly data (isSameEachDay already true)
    resetManager:UpdateResetDay(weeklyTabID, 4, true) -- only wednesday
    resetManager:RenameResetTime(weeklyTabID, weeklyTabData.reset.sameEachDay, enums.defaultResetTimeName, "Weekly")
    resetManager:UpdateTimeData(weeklyTabID, weeklyTabData.reset.sameEachDay.resetTimes["Weekly"], 9, 0, 0)

	end

	-- then we set the default tab
  database.ctab(selectedtabID)
  print("SET DEFAULT TAB")
end

function database:MigrateVars()
  -- // VAR VERSIONS MIGRATION
  local db = NysTDL.db
  local global = db.global
  local profile = db.profile

  -- / no migration from versions < 5.0

  -- / migration from 5.0+ to 5.5+
  if (profile.itemsDaily or profile.itemsWeekly or profile.itemsFavorite or profile.itemsDesc or profile.checkedButtons) then
    -- we need to change the saved variables to the new format
    local oldItemsList = utils:Deepcopy(profile.itemsList)
    profile.itemsList = {}

    for catName, itemNames in pairs(oldItemsList) do -- for every cat we had
      profile.itemsList[catName] = {}
      for _, itemName in pairs(itemNames) do -- and for every item we had
        -- first we get the previous data elements from the item
        -- / tabName
        local tabName = "All"
        if (utils:HasValue(profile.itemsDaily, itemName)) then
          tabName = "Daily"
        elseif (utils:HasValue(profile.itemsWeekly, itemName)) then
          tabName = "Weekly"
        end
        -- / checked
        local checked = utils:HasValue(profile.checkedButtons, itemName)
        -- / favorite
        local favorite = nil
        if (utils:HasValue(profile.itemsFavorite, itemName)) then
          favorite = true
        end
        -- / description
        local description = nil
        if (utils:HasKey(profile.itemsDesc, itemName)) then
          description = profile.itemsDesc[itemName]
        end

        -- then we replace it by the new var
        profile.itemsList[catName][itemName] = {
          ["tabName"] = tabName,
          ["checked"] = checked,
          ["favorite"] = favorite,
          ["description"] = description,
        }
      end
    end

    -- bye bye
    profile.itemsDaily = nil
    profile.itemsWeekly = nil
    profile.itemsFavorite = nil
    profile.itemsDesc = nil
    profile.checkedButtons = nil
  end

  -- / migration from 5.5+ to 6.0+
  if profile.closedCategories then
    -- first we get the itemsList and delete it, so that we can start filling it correctly
    local itemsList = profile.itemsList
    profile.itemsList = nil -- reset
    profile.itemsList = {}

    -- we get the necessary tab IDs
    local allTabID, allTabData, dailyTabID, dailyTabData, weeklyTabID, weeklyTabData
    for tabID,tabData in dataManager:ForEach(enums.tab, false) do
      if tabData.name == "All" then -- LOCALE
        allTabID, allTabData = tabID, tabData
      elseif tabData.name == "Daily" then
        dailyTabID, dailyTabData = tabID, tabData
      elseif tabData.name == "Weekly" then
        weeklyTabID, weeklyTabData = tabID, tabData
      end
    end

    -- // we recreate every cat, and every item
    local contentTabs = {}
    for catName,items in pairs(itemsList) do
      -- first things first, we do a loop to get every tab the cat is in (by checking the items data)
      wipe(contentTabs)
      for _,itemData in pairs(items) do
        if not utils:HasValue(contentTabs, itemData.tabName) then
          table.insert(contentTabs, itemData.tabName)
        end
      end

      -- then we add the cat to each of those found tabs
      local allCatID, dailyCatID, weeklyCatID
      for _,tabName in pairs(contentTabs) do
        if tabName == "All" then
          allCatID = dataManager:CreateCategory(catName, allTabID)
          if utils:HasValue(profile.closedCategories[catName], "All") then
            dataManager:ToggleClosed(allCatID, allTabID, false)
          end
        elseif tabName == "Daily" then
          dailyCatID = dataManager:CreateCategory(catName, dailyTabID)
          if utils:HasValue(profile.closedCategories[catName], "Daily") then
            dataManager:ToggleClosed(dailyCatID, dailyTabID, false)
          end
        elseif tabName == "Weekly" then
          weeklyCatID = dataManager:CreateCategory(catName, weeklyTabID)
          if utils:HasValue(profile.closedCategories[catName], "Weekly") then
            dataManager:ToggleClosed(weeklyCatID, weeklyTabID, false)
          end
        end
      end

      for itemName,itemData in pairs(items) do -- for every item
        -- tab & cat
        local itemTabID, itemCatID
        if itemData.tabName == "All" then
          itemTabID = allTabID
          itemCatID = allCatID
        elseif itemData.tabName == "Daily" then
          itemTabID = dailyTabID
          itemCatID = dailyCatID
        elseif itemData.tabName == "Weekly" then
          itemTabID = weeklyTabID
          itemCatID = weeklyCatID
        end

        -- / creation
        local itemID = dataManager:CreateItem(itemName, itemTabID, itemCatID)

        -- checked
        if itemData.checked then
          dataManager:ToggleChecked(itemID)
        end

        -- favorite
        if itemData.favorite then
          dataManager:ToggleFavorite(itemID)
        end

        -- description
        if itemData.description then
          dataManager:UpdateDescription(itemID, itemData.description)
        end
      end
    end

    -- // we also update the tabs in accordance with the tabs SV

    if profile.deleteAllTabItems then
      allTabData.deleteCheckedItems = true
      allTabData.hideCheckedItems = false
    end

    if profile.showOnlyAllTabItems then
      dataManager:UpdateShownTabID(allTabID, dailyTabID, false)
  		dataManager:UpdateShownTabID(allTabID, weeklyTabID, false)
    end

    if profile.hideDailyTabItems then
      dailyTabData.hideCheckedItems = true
      dailyTabData.deleteCheckedItems = false
    end

    if profile.hideWeeklyTabItems then
      weeklyTabData.hideCheckedItems = true
      weeklyTabData.deleteCheckedItems = false
    end

    -- // bye bye
    profile.closedCategories = nil
    profile.lastLoadedTab = nil
    profile.weeklyDay = nil
    profile.dailyHour = nil
    profile.deleteAllTabItems = nil
    profile.showOnlyAllTabItems = nil
    profile.hideDailyTabItems = nil
    profile.hideWeeklyTabItems = nil
  end
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
