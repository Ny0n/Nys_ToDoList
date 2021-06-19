-- Namespaces
local addonName, addonTable = ...

-- declaring the different addon tables
addonTable.config = {}
addonTable.utils = {}
addonTable.autoReset = {}
addonTable.widgets = {}
addonTable.itemsFrame = {}
addonTable.init = {}

local config = addonTable.config

--/*******************/ ADDON LIBS AND DATA HANDLER /*************************/--
-- libs
NysTDL = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceTimer-3.0", "AceEvent-3.0")
config.AceGUI = LibStub("AceGUI-3.0")
config.L = LibStub("AceLocale-3.0"):GetLocale(addonName)
config.LDB = LibStub("LibDataBroker-1.1")
config.LDBIcon = LibStub("LibDBIcon-1.0")
config.LDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
-- data (from toc file)
config.toc = {}
config.toc.title = GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
config.toc.version = GetAddOnMetadata(addonName, "Version")

-- Variables
local L = config.L

-- Bindings.xml globals
BINDING_HEADER_NysTDL = config.toc.title
BINDING_NAME_NysTDL = L["Show/Hide the To-Do List"]

--/*******************/ DATABASE /*************************/--

config.database = {
    -- addon themes (rgb)
    theme = { 0, 204, 255 }, -- theme
    theme2 = { 0, 204, 102 }, -- theme2
    theme_yellow = { 255, 216, 0 }, -- theme_yellow

    -- AceConfig options table
    options = {
        handler = NysTDL,
        type = "group",
        name = config.toc.title.." ("..config.toc.version..")",
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
                      get = "keepOpenGET",
                      set = "keepOpenSET",
                      disabled = function() return NysTDL.db.profile.openByDefault end,
                  }, -- rememberUndo
                  openByDefault = {
                      order = 1.3,
                      type = "toggle",
                      name = L["Open by default"],
                      get = "openByDefaultGET",
                      set = "openByDefaultSET",
                      hidden = function() return not NysTDL.db.profile.keepOpen end
                  }, -- openByDefault
                  rememberUndo = {
                      order = 3.7,
                      type = "toggle",
                      name = L["Remember undos"],
                      desc = L["Save undos between sessions"],
                      get = "rememberUndoGET",
                      set = "rememberUndoSET",
                  }, -- rememberUndo
                  highlightOnFocus = {
                      order = 3.8,
                      type = "toggle",
                      name = L["Highlight edit boxes"],
                      desc = L["When focusing on edit boxes, automatically highlights the text inside"],
                      get = "highlightOnFocusGET",
                      set = "highlightOnFocusSET",
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
                      get = "rainbowGET",
                      set = "rainbowSET",
                  }, -- rainbow
                  rainbowSpeed = {
                      order = 3.6,
                      type = "range",
                      name = L["Rainbow speed"],
                      desc = L["Because why not?"],
                      min = 1,
                      max = 6,
                      step = 1,
                      get = "rainbowSpeedGET",
                      set = "rainbowSpeedSET",
                      hidden = function() return not NysTDL.db.profile.rainbow end
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
                      get = function(info) return not NysTDL:minimapButtonHideGET(info) end,
                      set = function(info, newValue) NysTDL:minimapButtonHideSET(info, not newValue) end,
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
                args = {
                  instantRefresh = {
                      order = 0.1,
                      type = "toggle",
                      name = L["Instant refresh"],
                      desc = L["Applies the following settings instantly when checking items, instead of waiting for any other action"],
                      get = "instantRefreshGET",
                      set = "instantRefreshSET",
                  }, -- instantRefresh
                  deleteAllTabItems = {
                      order = 1.1,
                      type = "toggle",
                      name = L["Delete checked items"],
                      desc = L["Automatically deletes checked items that are unique to the 'All' tab"],
                      get = "deleteAllTabItemsGET",
                      set = "deleteAllTabItemsSET",
                  }, -- deleteAllTabItems
                  showOnlyAllTabItems = {
                      order = 1.2,
                      type = "toggle",
                      name = L["Only show tab items"],
                      desc = L["Only show items unique to the 'All' tab"],
                      get = "showOnlyAllTabItemsGET",
                      set = "showOnlyAllTabItemsSET",
                  }, -- showOnlyAllTabItems
                  hideDailyTabItems = {
                      order = 2.1,
                      type = "toggle",
                      name = L["Hide checked items"],
                      desc = L["Automatically hides checked items in the tab until the next reset"],
                      get = "hideDailyTabItemsGET",
                      set = "hideDailyTabItemsSET",
                  }, -- hideDailyTabItems
                  hideWeeklyTabItems = {
                      order = 3.1,
                      type = "toggle",
                      name = L["Hide checked items"],
                      desc = L["Automatically hides checked items in the tab until the next reset"],
                      get = "hideWeeklyTabItemsGET",
                      set = "hideWeeklyTabItemsSET",
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
                      get = "showChatMessagesGET",
                      set = "showChatMessagesSET",
                  }, -- showChatMessages
                  showWarnings = {
                      order = 1.1,
                      type = "toggle",
                      name = L["Show warnings"],
                      desc = L["Enable or disable the chat warning/reminder system"]..'\n'..L["(chat message when logging in)"],
                      get = "showWarningsGET",
                      set = "showWarningsSET",
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
                            get = "favoritesWarningGET",
                            set = "favoritesWarningSET",
                        }, -- favoritesWarning
                        normalWarning = {
                            order = 1.2,
                            type = "toggle",
                            name = L["Normal warning"],
                            desc = L["Enable warnings for non-favorite items"],
                            get = "normalWarningGET",
                            set = "normalWarningSET",
                        }, -- normalWarning
                        hourlyReminder = {
                            order = 1.3,
                            type = "toggle",
                            name = L["Hourly reminder"],
                            desc = L["Show warnings every 60 min following your log-in time"],
                            get = "hourlyReminderGET",
                            set = "hourlyReminderSET",
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
                      get = "weeklyDayGET",
                      set = "weeklyDaySET",
                  }, -- weeklyDay
                  dailyHour = {
                      order = 0.2,
                      type = "range",
                      name = L["Daily reset hour"],
                      desc = L["Choose the hour for the daily reset"],
                      min = 0,
                      max = 23,
                      step = 1,
                      get = "dailyHourGET",
                      set = "dailyHourSET",
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
        }, -- args
    }, -- options

    -- AceDB defaults table
    defaults = {
        global = {
            addonUpdated = true, -- used to call an update func in init, only once after each addon update
            latestVersion = "", -- used to update the global saved variables once after each addon update
            tuto_progression = 0,
            UI_reloading = false,
            warnTimerRemaining = 0,
        },
        profile = {
            latestVersion = "", -- used to update the profile saved variables once after each addon update, independent for each profile

            -- // Misc
            itemsList = {},
            closedCategories = {},
            undoTable = {},
            lastLoadedTab = "ToDoListUIFrameTab2",
            lastListVisibility = false,
            lockList = false,
            lockButton = false,

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
    }, -- defaults
}
