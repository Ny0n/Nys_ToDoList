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
    lockList = false, -- TODO
    lockButton = false, -- TODO

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
    instantRefresh = false,

    --'Chat Messages' tab
    showChatMessages = true,
    showWarnings = false,
    favoritesWarning = true,
    normalWarning = false,
    hourlyReminder = false,
  }, -- profile
}

-- AceConfig options table
database.options = {
  handler = optionsManager,
  type = "group",
  name = core.toc.title.." ("..core.toc.version..")",
  get = "Getter",
  set = "Setter",
  args = {
    main = {
      order = 0,
      type = "group",
      name = L["Options"],
      childGroups = "tab",
      args = {
        general = {
          order = 0,
          type = "group",
          name = L["General"],
          args = {

            -- / options widgets / --

            keepOpen = {
              order = 1.2,
              type = "toggle",
              name = L["Stay opened"],
              desc = L["Keeps the list opened if it was during last session"],
              disabled = function() return NysTDL.db.profile.openByDefault end,
            }, -- keepOpen
            openByDefault = {
              order = 1.3,
              type = "toggle",
              name = L["Open by default"],
              hidden = function() return not NysTDL.db.profile.keepOpen end
            }, -- openByDefault
            rememberUndo = {
              order = 3.7,
              type = "toggle",
              name = L["Remember undos"],
              desc = L["Save undos between sessions"],
            }, -- rememberUndo
            highlightOnFocus = {
              order = 3.8,
              type = "toggle",
              name = L["Highlight edit boxes"],
              desc = L["When focusing on edit boxes, automatically highlights the text inside"],
            }, -- highlightOnFocus
            favoritesColor = {
              order = 3.4,
              type = "color",
              name = L["Favorites color"],
              desc = L["Change the color for the favorite items"],
              get = "favoritesColorGET",
              set = "favoritesColorSET",
              disabled = function() return NysTDL.db.profile.rainbow end,
            }, -- favoritesColor
            rainbow = {
              order = 3.5,
              type = "toggle",
              name = L["Rainbow"],
              desc = L["Too.. Many.. Colors..."],
            }, -- rainbow
            rainbowSpeed = {
              order = 3.6,
              type = "range",
              name = L["Rainbow speed"],
              desc = L["Because why not?"],
              min = 1,
              max = 6,
              step = 1,
              hidden = function() return not NysTDL.db.profile.rainbow end,
            }, -- rainbowSpeed
            tdlButtonShow = {
              order = 2.3,
              type = "toggle",
              name = L["Show TDL button"],
              desc = L["Toggles the display of the 'To-Do List' button"],
              get = "tdlButtonShowGET",
              set = "tdlButtonShowSET",
            }, -- tdlButtonShow
            tdlButtonRed = {
              order = 2.4,
              type = "toggle",
              name = L["Red"],
              desc = L["Changes the color of the TDL button if there are items left to do before tomorrow"],
              get = "tdlButtonRedGET",
              set = "tdlButtonRedSET",
              hidden = function() return not NysTDL.db.profile.tdlButton.show end
            }, -- tdlButtonShow
            minimapButtonHide = {
              order = 2.1,
              type = "toggle",
              name = L["Show minimap button"],
              desc = L["Toggles the display of the minimap button"],
              get = function(info) return not optionsManager:minimapButtonHideGET(info) end,
              set = function(info, newValue) optionsManager:minimapButtonHideSET(info, not newValue) end,
            }, -- minimapButtonHide
            minimapButtonTooltip = {
              order = 2.2,
              -- disabled = function() return NysTDL.db.profile.minimap.hide end,
              type = "toggle",
              name = L["Show tooltip"],
              desc = L["Show the tooltip of the minimap/databroker button"],
              get = "minimapButtonTooltipGET",
              set = "minimapButtonTooltipSET",
            }, -- minimapButtonTooltip
            keyBind = {
              type = "keybinding",
              name = L["Show/Hide the list"],
              desc = L["Bind a key to toggle the list"]..'\n'..L["(independant from profile)"],
              order = 1.1,
              get = "keyBindGET",
              set = "keyBindSET",
            }, -- keyBind

            -- / layout widgets / --

            -- spacers
            spacer111 = {
              order = 1.31,
              type = "description",
              width = "full",
              name = "",
            }, -- spacer111
            spacer199 = {
              order = 1.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer199
            spacer221 = {
              order = 2.21,
              type = "description",
              width = "full",
              name = "",
            }, -- spacer221
            spacer299 = {
              order = 2.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer299
            spacer331 = {
              order = 3.31,
              type = "description",
              width = "full",
              name = "",
            }, -- spacer331
            spacer361 = {
              order = 3.61,
              type = "description",
              width = "full",
              name = "",
            }, -- spacer361
            spacer399 = {
              order = 3.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer399

            -- headers
            header1 = {
              order = 1,
              type = "header",
              name = "List",
            }, -- header1
            header2 = {
              order = 2,
              type = "header",
              name = L["Buttons"],
            }, -- header2
            header3 = {
              order = 3,
              type = "header",
              name = L["Settings"],
            }, -- header3
          }, -- args
        }, -- general
        tabs = {
          order = 1,
          type = "group",
          name = L["Tabs"],
          get = "GetterTabs",
          set = "SetterTabs",
          args = {
            instantRefresh = {
              order = 0.1,
              type = "toggle",
              name = L["Instant refresh"],
              desc = L["Applies the following settings instantly when checking items, instead of waiting for any other action"],
            }, -- instantRefresh

            -- / layout widgets / --

            -- spacers
            spacer099 = {
              order = 0.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer099
            spacer111 = {
              order = 1.11,
              type = "description",
              width = "full",
              name = "",
            }, -- spacer111
            spacer199 = {
              order = 1.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer199
            spacer299 = {
              order = 2.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer299
            spacer399 = {
              order = 3.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer399

            -- headers
            header1 = {
              order = 0,
              type = "header",
              name = L["General"],
            }, -- header1
            header2 = {
              order = 1,
              type = "header",
              name = L["All"],
            }, -- header2
            header3 = {
              order = 2,
              type = "header",
              name = L["Daily"],
            }, -- header3
            header4 = {
              order = 3,
              type = "header",
              name = L["Weekly"],
            }, -- header4
          } -- args
        }, -- tabs
        chat = {
          order = 2,
          type = "group",
          name = L["Chat Messages"],
          args = {
            showChatMessages = {
              order = 0.1,
              type = "toggle",
              name = L["Show chat messages"],
              desc = L["Enable or disable non-essential chat messages"]..'\n'..L["(warnings ignore this option)"],
            }, -- showChatMessages
            showWarnings = {
              order = 1.1,
              type = "toggle",
              name = L["Show warnings"],
              desc = L["Enable or disable the chat warning/reminder system"]..'\n'..L["(chat message when logging in)"],
            }, -- showWarnings
            groupWarnings = {
              order = 1.2,
              type = "group",
              name = L["Warnings"]..":",
              inline = true,
              hidden = function() return not NysTDL.db.profile.showWarnings end,
              args = {
                favoritesWarning = {
                  order = 1.1,
                  type = "toggle",
                  name = L["Favorites warning"],
                  desc = L["Enable warnings for favorite items"],
                }, -- favoritesWarning
                normalWarning = {
                  order = 1.2,
                  type = "toggle",
                  name = L["Normal warning"],
                  desc = L["Enable warnings for non-favorite items"],
                }, -- normalWarning
                hourlyReminder = {
                  order = 1.3,
                  type = "toggle",
                  name = L["Hourly reminder"],
                  desc = L["Show warnings every 60 min following your log-in time"],
                  disabled = function()
                    return not (NysTDL.db.profile.favoritesWarning or NysTDL.db.profile.normalWarning)
                  end,
                }, -- hourlyReminder
              }
            }, -- groupWarnings

            -- / layout widgets / --

            -- spacers
            spacer011 = {
              order = 0.99,
              type = "description",
              width = "full",
              name = "\n",
            }, -- spacer011

            -- headers
            header1 = {
              order = 0,
              type = "header",
              name = L["General"],
            }, -- header1
            header2 = {
              order = 1,
              type = "header",
              name = L["Warnings"],
            }, -- header2
          } -- args
        }, -- chat
        -- new main tab
      }, -- args
    }, -- main
    child_profiles = {
      order = 1,
      type = "group",
      name = L["Profiles"],
      childGroups = "tab",
      args = {
        -- importexport = {
        --   order = 101, -- because the profiles tab will have 100, the default value, when created from AceDBOptions
        --   type = "group",
        --   name = "Import/Export",
        --   args = {
        --   } -- args
        -- } -- importexport
        -- new profiles tab
      }, -- args
    } -- child_profiles
  } -- args
}

--/*******************/ DATABASE FUNCTIONS /*************************/--

-- // DB init & change

-- this func is called once in initialize, on the addon load
-- and also everytime we switch profiles
function database:DBInit()
  dataManager.authorized = false -- there's no calling mainFrame funcs while we're tampering with the database!

  -- default tabs creation
  if database.ctab() == "TOSET" then
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

  dataManager.authorized = true
end

function database:ProfileChanged(_, profile)
  -- // here we update (basically in the same order as the core init) everything
  -- that needs an update after a database change
  print("PROFILE: ", profile)

  -- #1 - database (always init a database)
  database:DBInit()

  -- #2 - options
  optionsManager:CallAllGETTERS()

  -- #last-1 - widgets (we update che changes to the UI elements)
  widgets:ProfileChanged()

  -- #last - tabs resets
  resetManager:Initialize(true)
end

-- these two functions are called only once, each time there is an addon update
function database:GlobalNewVersion() -- global
  -- updates the global saved variables once after an update

  if NysTDL.db.global.tuto_progression > 0 then -- if we already completed the tutorial
    -- since i added in the update a new tutorial frame that i want ppl to see, i just go back step in the tuto progression
    tutorialsManager:Previous()
  end
end

function database:ProfileNewVersion() -- profile
  -- updates each profile saved variables once after an update

  -- // VAR VERSIONS MIGRATION
  local db = NysTDL.db
  local global = db.global
  local profile = db.profile

  -- / no migration from versions older than 5.0

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
    local allTabID, dailyTabID, weeklyTabID
    for tabID,tabData in dataManager:ForEach(enums.tab, false) do
      if tabData.name == "All" then
        allTabID = tabID
      elseif tabData.name == "Daily" then
        dailyTabID = tabID
      elseif tabData.name == "Weekly" then
        weeklyTabID = tabID
      end
    end

    local contentTabs = {}

    -- we recreate every cat, and every item
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
        elseif tabName == "Daily" then
          dailyCatID = dataManager:CreateCategory(catName, dailyTabID)
        elseif tabName == "Weekly" then
          weeklyCatID = dataManager:CreateCategory(catName, weeklyTabID)
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

    -- bye bye
    profile.closedCategories = nil
    profile.lastLoadedTab = nil
  end
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
	for g=1, 1 do -- TODO fix => 1, 2
		local isGlobal = g == 2

		-- Daily
		local dailyTabID, dailyTabData = dataManager:CreateTab("Daily", isGlobal) -- isSameEachDay already true
		for i=1,7 do resetManager:UpdateResetDay(dailyTabID, i, true) end -- every day
		resetManager:UpdateTimeData(dailyTabID, dailyTabData.reset.sameEachDay.resetTimes["Reset 1"], 9, 0, 0)

    if not isGlobal then
      selectedtabID = dailyTabID -- default tab
    end

		-- Weekly
		local weeklyTabID, weeklyTabData = dataManager:CreateTab("Weekly", isGlobal) -- isSameEachDay already true
		resetManager:UpdateResetDay(weeklyTabID, 4, true) -- only wednesday
		resetManager:UpdateTimeData(weeklyTabID, weeklyTabData.reset.sameEachDay.resetTimes["Reset 1"], 9, 0, 0)

		-- All
		local allTabID = dataManager:CreateTab("All", isGlobal)
		dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
		dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)
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
