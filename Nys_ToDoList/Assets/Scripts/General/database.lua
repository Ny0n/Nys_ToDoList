-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local database = addonTable.database
local core = addonTable.core
local utils = addonTable.utils
local autoReset = addonTable.autoReset
local optionsManager = addonTable.optionsManager

-- Variables
local L = core.L

--/*******************/ TABLES /*************************/--

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
    nextID = 1, -- unique id used for everything in the list, will be incremented towards infinity
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

    currentTab = "TOSET", -- currently selected tab's ID

    -- // Misc
    lastListVisibility = false,
    lockList = false, -- TODO
    lockButton = false, -- TODO

    -- // Frame Options
    framePos = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 },
    frameSize = { width = 340, height = 400 },
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
    autoReset = nil,
    rememberUndo = true,
    highlightOnFocus = true,
    keepOpen = false,
    openByDefault = false,

    --'Tabs' tab
    instantRefresh = false,
    deleteAllTabItems = false,
    showOnlyAllTabItems = false,
    hideDailyTabItems = false,
    hideWeeklyTabItems = false,

    --'Chat Messages' tab
    showChatMessages = true,
    showWarnings = false,
    favoritesWarning = true,
    normalWarning = false,
    hourlyReminder = false,

    --'Auto Uncheck' tab
    weeklyDay = 4,
    dailyHour = 9,
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
            }, -- rememberUndo
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
            deleteAllTabItems = {
              order = 1.1,
              type = "toggle",
              name = L["Delete checked items"],
              desc = L["Automatically deletes checked items that are unique to the 'All' tab"],
            }, -- deleteAllTabItems
            showOnlyAllTabItems = {
              order = 1.2,
              type = "toggle",
              name = L["Only show tab items"],
              desc = L["Only show items unique to the 'All' tab"],
            }, -- showOnlyAllTabItems
            hideDailyTabItems = {
              order = 2.1,
              type = "toggle",
              name = L["Hide checked items"],
              desc = L["Automatically hides checked items in the tab until the next reset"],
            }, -- hideDailyTabItems
            hideWeeklyTabItems = {
              order = 3.1,
              type = "toggle",
              name = L["Hide checked items"],
              desc = L["Automatically hides checked items in the tab until the next reset"],
            }, -- hideWeeklyTabItems


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
        reset = {
          order = 3,
          type = "group",
          name = L["Auto Uncheck"],
          get = "GetterReset",
          set = "SetterReset",
          args = {
            weeklyDay = {
              order = 0.1,
              type = "select",
              style = "dropdown",
              name = L["Weekly reset day"],
              desc = L["Choose the day for the weekly reset"],
              values = {
                [2] = L["Monday"],
                [3] = L["Tuesday"],
                [4] = L["Wednesday"],
                [5] = L["Thursday"],
                [6] = L["Friday"],
                [7] = L["Saturday"],
                [1] = L["Sunday"],
              },
              sorting = {
                2, 3, 4, 5, 6, 7, 1,
              },
            }, -- weeklyDay
            dailyHour = {
              order = 0.2,
              type = "range",
              name = L["Daily reset hour"],
              desc = L["Choose the hour for the daily reset"],
              min = 0,
              max = 23,
              step = 1,
            }, -- dailyHour

            -- / layout widgets / --

            -- headers
            header1 = {
              order = 0,
              type = "header",
              name = L["General"],
            }, -- header1
          } -- args
        }, -- reset
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
function database:DBInit(profileChanged)
  -- checking for an addon update, globally
  if (NysTDL.db.global.latestVersion ~= core.toc.version) then
    self:GlobalNewVersion()
    NysTDL.db.global.latestVersion = core.toc.version
    NysTDL.db.global.addonUpdated = true
  end

  -- checking for an addon update, for the profile that was just loaded
  if (NysTDL.db.profile.latestVersion ~= core.toc.version) then
    self:ProfileNewVersion()
    NysTDL.db.profile.latestVersion = core.toc.version
  end

  -- // initialization of elements that need to be updated correctly when the profile changes

  -- default tabs creation
  if database.ctab() == "TOSET" then
    database:CreateDefaultTabs()
  end

  -- tabs resets
  resetManager:Initialize(profileChanged)

  -- remember undos
  if not NysTDL.db.profile.rememberUndo then
    wipe(NysTDL.db.profile.undoTable)
  end
end

function database:ProfileChanged(_, profile)
  print("PROFILE: ", profile)
  self:DBInit(true) -- in case the selected profile is empty TODO: test self

  -- we update the changes for the list
  mainFrame:ResetContent()
  mainFrame:Init(true)

  -- we update the changes to the options (since I now use tabs and the options are not instantly getting a refresh when changing profiles)
  optionsManager:CallAllGETTERS()
end

-- these two functions are called only once, each time there is an addon update
function database:GlobalNewVersion() -- global
  -- updates the global saved variables once after an update

  if (NysTDL.db.global.tuto_progression > 0) then -- if we already completed the tutorial
    -- since i added in the update a new tutorial frame that i want ppl to see, i just go back step in the tuto progression
    NysTDL.db.global.tuto_progression = NysTDL.db.global.tuto_progression - 1
  end
end

function database:ProfileNewVersion() -- profile
  -- if we're loading this profile for the first time after updating to 5.5+ from 5.4-
  if (NysTDL.db.profile.itemsDaily or NysTDL.db.profile.itemsWeekly or NysTDL.db.profile.itemsFavorite or NysTDL.db.profile.itemsDesc or NysTDL.db.profile.checkedButtons) then
    -- we need to change the saved variables to the new format
    local oldItemsList = utils:Deepcopy(NysTDL.db.profile.itemsList)
    NysTDL.db.profile.itemsList = {}

    for catName, itemNames in pairs(oldItemsList) do -- for every cat we had
      NysTDL.db.profile.itemsList[catName] = {}
      for _, itemName in pairs(itemNames) do -- and for every item we had
        -- first we get the previous data elements from the item
        -- / tabName
        local tabName = "All"
        if (utils:HasValue(NysTDL.db.profile.itemsDaily, itemName)) then
          tabName = "Daily"
        elseif (utils:HasValue(NysTDL.db.profile.itemsWeekly, itemName)) then
          tabName = "Weekly"
        end
        -- / checked
        local checked = utils:HasValue(NysTDL.db.profile.checkedButtons, itemName)
        -- / favorite
        local favorite = nil
        if (utils:HasValue(NysTDL.db.profile.itemsFavorite, itemName)) then
          favorite = true
        end
        -- / description
        local description = nil
        if (utils:HasKey(NysTDL.db.profile.itemsDesc, itemName)) then
          description = NysTDL.db.profile.itemsDesc[itemName]
        end

        -- then we replace it by the new var
        NysTDL.db.profile.itemsList[catName][itemName] = {
          ["tabName"] = tabName,
          ["checked"] = checked,
          ["favorite"] = favorite,
          ["description"] = description,
        }
      end
    end

    -- bye bye
    NysTDL.db.profile.itemsDaily = nil
    NysTDL.db.profile.itemsWeekly = nil
    NysTDL.db.profile.itemsFavorite = nil
    NysTDL.db.profile.itemsDesc = nil
    NysTDL.db.profile.checkedButtons = nil
  end
end

-- // specific functions

function database.ctab(newTabID) -- easy access to that specific database variable
  -- sets or gets the currently selected tab ID
  if type(newTabID) == enums.idtype then
    NysTDL.db.profile.currentTab = newTabID
  end
  return NysTDL.db.profile.currentTab
end

function database:CreateDefaultTabs()
	-- once per profile, we create the default addon tabs (All, Daily, Weekly)

	-- // Profile

	for g=1,2 do
		local isGlobal = g == 2

		-- Daily
		local dailyTabData = dataManager:CreateTab("Daily") -- isSameEachDay already true
		local dailyTabID = dataManager:AddTab(dailyTabData, isGlobal)
		for i=1,7 do resetManager:UpdateResetDay(dailyTabID, i, true) end -- every day
		resetManager:UpdateTimeData(dailyTabID, dailyTabData.reset.sameEachDay, 9, 0, 0)

		-- Weekly
		local weeklyTabData = dataManager:CreateTab("Weekly") -- isSameEachDay already true
		local weeklyTabID = dataManager:AddTab(weeklyTabData, isGlobal)
		resetManager:UpdateResetDay(weeklyTabID, 4, true) -- only wednesday
		resetManager:UpdateTimeData(weeklyTabID, weeklyTabData.reset.sameEachDay, 9, 0, 0)

		-- All
		local allTabID = dataManager:AddTab(dataManager:CreateTab("All"), isGlobal)
		dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
		dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)
	end

	-- then we set the default tab
  database.ctab(dailyTabID)
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
