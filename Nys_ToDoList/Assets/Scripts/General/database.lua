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

  local noTabs = not dataManager:IsID(database.ctab())

  -- default tabs creation
  if noTabs then
    database:CreateDefaultTabs()
  end

  -- /==============< MIGRATION STUFF >==============/ --
  -- this is for doing specific things ONLY when the addon gets updated and its version changes

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

  -- /===============================================/ --

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

-- these two functions are called only once, each time there is an addon update
function database:GlobalNewVersion() -- global
  -- // updates the global saved variables once after an update
  print("GLOBAL NEW VERSION")

  if utils:IsVersionOlderThan(NysTDL.db.global.latestVersion, "6.0") then -- if we come from before 6.0
    if NysTDL.db.global.tuto_progression > 5 then -- if we already completed the tutorial
      -- we go to the new part of the edit mode button
      NysTDL.db.global.tuto_progression = 5
    end
  end
end

function database:ProfileNewVersion() -- profile
  -- // updates each profile saved variables once after an update
  print("PROFILE NEW VERSION")

  -- by default after each update, we empty the undo table
  wipe(NysTDL.db.profile.undoTable)

  -- var version migration
  database:CheckVarsMigration()
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

function database:CheckVarsMigration()
  -- // VAR VERSIONS MIGRATION
  -- this func will only call the right migrations, depending on the current and last version of the addon

  local db = NysTDL.db
  local global = db.global
  local profile = db.profile

  local ToDoListSV_transfert

  -- / migration from 1.0+ to 2.0+
  if utils:IsVersionOlderThan(profile.latestVersion, "2.0") then
    -- (potential) saved variables in 1.0+ : ToDoListSV_checkedButtons, ToDoListSV_itemsList, ToDoListSV_autoReset, ToDoListSV_lastLoadedTab
    -- saved variables in 2.0+ : ToDoListSV
    if ToDoListSV_checkedButtons or ToDoListSV_itemsList or ToDoListSV_autoReset or ToDoListSV_lastLoadedTab then
  		ToDoListSV_transfert = {
        -- we only care about those two to be transfered to 6.0+
        itemsList = ToDoListSV_itemsList or { ["Daily"] = {}, ["Weekly"] = {} },
  		  checkedButtons = ToDoListSV_checkedButtons or {},
  		}

      -- // bye bye
      ToDoListSV_checkedButtons = nil
      ToDoListSV_itemsList = nil
      ToDoListSV_autoReset = nil
      ToDoListSV_lastLoadedTab = nil
  	end
  end

  -- / migration from 2.0+ to 4.0+
  if utils:IsVersionOlderThan(profile.latestVersion, "4.0") then
    -- saved variables in 2.0+ : ToDoListSV
    -- saved variables in 4.0+ : NysToDoListDB (AceDB)
    if ToDoListSV or ToDoListSV_transfert then
      ToDoListSV_transfert = ToDoListSV_transfert or ToDoListSV
      -- again, only those two are useful
      profile.itemsList = utils:Deepcopy(ToDoListSV_transfert.itemsList) or { ["Daily"] = {}, ["Weekly"] = {} }
      profile.checkedButtons = utils:Deepcopy(ToDoListSV_transfert.checkedButtons) or {}

      -- // bye bye
      ToDoListSV = nil
      ToDoListSV_transfert = nil
    end
  end

  -- / migration from 4.0+ to 5.0+
  if utils:IsVersionOlderThan(profile.latestVersion, "5.0") then
    -- this test may not be bulletproof, but it's the closest safeguard i could think of
    -- 5.5+ format
    local nextFormat = false
    local catName, itemNames = next(profile.itemsList)
    if catName then
      local _, itemData = next(profile.itemsList[catName])
      if type(itemData) == "table" then
        nextFormat = true
      end
    end

    if profile.itemsList and (profile.itemsList["Daily"] and profile.itemsList["Weekly"]) and not nextFormat then
      -- we only extract the daily and weekly tables to be on their own
      profile.itemsDaily = utils:Deepcopy(profile.itemsList["Daily"]) or {}
      profile.itemsWeekly = utils:Deepcopy(profile.itemsList["Weekly"]) or {}

      -- // bye bye
      profile.itemsList["Daily"] = nil
      profile.itemsList["Weekly"] = nil
    end
  end

  -- / migration from 5.0+ to 5.5+
  if utils:IsVersionOlderThan(profile.latestVersion, "5.5") then
    -- every var here will be transfered INSIDE the items data
    if profile.itemsDaily or profile.itemsWeekly or profile.itemsFavorite or profile.itemsDesc or profile.checkedButtons then
      -- we need to change the saved variables to the new format
      local oldItemsList = utils:Deepcopy(profile.itemsList)
      profile.itemsList = {}

      for catName, itemNames in pairs(oldItemsList) do -- for every cat we had
        profile.itemsList[catName] = {}
        for _, itemName in pairs(itemNames) do -- and for every item we had
          -- first we get the previous data elements from the item
          -- / tabName
          -- no need for the locale here, i actually DID force-use the english names in my previous code,
          -- the shown names being the only ones different
          local tabName = enums.mainTabs.all
          if (utils:HasValue(profile.itemsDaily, itemName)) then
            tabName = enums.mainTabs.daily
          elseif (utils:HasValue(profile.itemsWeekly, itemName)) then
            tabName = enums.mainTabs.weekly
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

      -- // bye bye
      profile.itemsDaily = nil
      profile.itemsWeekly = nil
      profile.itemsFavorite = nil
      profile.itemsDesc = nil
      profile.checkedButtons = nil
    end
  end

  -- / migration from 5.5+ to 6.0+
  -- !! IMPORTANT !! profile.latestVersion was introduced in 5.6, so every migration from further on won't need double checks
  if utils:IsVersionOlderThan(profile.latestVersion, "6.0") then
    -- first we get the itemsList and delete it, so that we can start filling it correctly
    local itemsList = profile.itemsList
    profile.itemsList = nil -- reset
    profile.itemsList = {}

    -- we get the necessary tab IDs
    local allTabID, allTabData, dailyTabID, dailyTabData, weeklyTabID, weeklyTabData
    for tabID,tabData in dataManager:ForEach(enums.tab, false) do
      if tabData.name == enums.mainTabs.all then
        allTabID, allTabData = tabID, tabData
      elseif tabData.name == enums.mainTabs.daily then
        dailyTabID, dailyTabData = tabID, tabData
      elseif tabData.name == enums.mainTabs.weekly then
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
        local cID, tID
        if tabName == enums.mainTabs.all then
          allCatID = dataManager:CreateCategory(catName, allTabID)
          cID, tID = allCatID, allTabID
        elseif tabName == enums.mainTabs.daily then
          dailyCatID = dataManager:CreateCategory(catName, dailyTabID)
          cID, tID = dailyCatID, dailyTabID
        elseif tabName == enums.mainTabs.weekly then
          weeklyCatID = dataManager:CreateCategory(catName, weeklyTabID)
          cID, tID = weeklyCatID, weeklyTabID
        end

        -- was it closed?
        if profile.closedCategories and cID and tID then
          if utils:HasValue(profile.closedCategories[catName], tabName) then
            dataManager:ToggleClosed(cID, tID, false)
          end
        end
      end

      for itemName,itemData in pairs(items) do -- for every item, again
        -- tab & cat
        local itemTabID, itemCatID
        if itemData.tabName == enums.mainTabs.all then
          itemTabID = allTabID
          itemCatID = allCatID
        elseif itemData.tabName == enums.mainTabs.daily then
          itemTabID = dailyTabID
          itemCatID = dailyCatID
        elseif itemData.tabName == enums.mainTabs.weekly then
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

  -- / future migrations... (I hope not :D)
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
