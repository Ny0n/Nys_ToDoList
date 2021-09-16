-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local mainFrame = addonTable.mainFrame
local tabsFrame = addonTable.tabsFrame
local databroker = addonTable.databroker
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager

-- Variables
local L = core.L
local LDB = core.LDB
local LDBIcon = core.LDBIcon

local private = {}

--/*******************/ OPTIONS TABLES /*************************/--

function getLeaf(info, x)
  local tbl = optionsManager.optionsTable
  for i=1,x do
    tbl = tbl.args[info[i]]
  end
  return tbl
end

local function getTabInfo(info)
  local tabID = getLeaf(info, 4).arg
  local tabData = select(3, dataManager:Find(tabID))
  local resetData
  if tabData.reset.isSameEachDay then
    resetData = tabData.reset.sameEachDay
  else
    resetData = tabData.reset.days[tabData.reset.configureDay]
  end
  return tabID, tabData, resetData
end

local tabManagementTable = {
  -- / settings / --

  settingsTab = {
    order = 1.1,
    type = "group",
    name = "Settings",
    args = {
      removeTabExecute = {
        order = 1.1,
        type = "execute",
        name = "Delete tab",
        confirm = true,
        confirmText = "Deleting this tab will delete everything that was created in it.\nAre you sure?",
        func = function(info)
          local tabID = getTabInfo(info)
          print(getLeaf(info, 4).arg)
          print(info.arg)
          print(info[#info-1].arg)
          dataManager:DeleteTab(tabID)
          private:RefreshTabManagement()
        end,
        disabled = function(info)
          local tabID = getTabInfo(info)
          return dataManager:IsProtected(tabID)
        end,
      },
      removeTabDescription = {
        order = 1.2,
        type = "description",
        name = "Cannot remove this tab, there must be at least one left",
        hidden = function(info)
          local tabID = getTabInfo(info)
          return not dataManager:IsProtected(tabID)
        end,
      },
      renameTabInput = {
        order = 1.3,
        type = "input",
        name = "Rename",
        get = function(info)
          local _, tabData = getTabInfo(info)
          return tabData.name
        end,
        set = function(info, newName)
          local tabID = getTabInfo(info)
          dataManager:Rename(tabID, newName)
        end,
      },
      instantRefreshToggle = {
        order = 1.4,
        type = "toggle",
        name = "Instant refresh",
        -- desc = "", -- TODO dire dépendant du profile (PR PROFILE ET GLOBAL, dans les deux cas c dépendant du profile (rien a changer du coup))
        get = function(info)
          return NysTDL.db.profile.instantRefresh
        end,
        set = function(info, state)
          NysTDL.db.profile.instantRefresh = state
          mainFrame:Refresh()
        end,
      },
      deleteCheckedItemsToggle = {
        order = 1.5,
        type = "toggle",
        name = "Delete checked items",
        get = function(info)
          local _, tabData = getTabInfo(info)
          return tabData.deleteCheckedItems
        end,
        set = function(info, state)
          local _, tabData = getTabInfo(info)
          tabData.deleteCheckedItems = state
          if state then
            tabData.hideCheckedItems = false
          end
          mainFrame:Refresh()
        end,
        disabled = function(info)
          local _, tabData = getTabInfo(info)
          return tabData.hideCheckedItems
        end,
      },
      hideCheckedItemsToggle = {
        order = 1.6,
        type = "toggle",
        name = "Hide checked items",
        get = function(info)
          local _, tabData = getTabInfo(info)
          return tabData.hideCheckedItems
        end,
        set = function(info, state)
          local _, tabData = getTabInfo(info)
          tabData.hideCheckedItems = state
          if state then
            tabData.deleteCheckedItems = false
          end
          mainFrame:Refresh()
        end,
        disabled = function(info)
          local _, tabData = getTabInfo(info)
          return tabData.deleteCheckedItems
        end,
      },
      shownTabsMultiSelect = {
        order = 1.7,
        type = "multiselect",
        name = "Shown tabs",
        values = function(info)
          local originalTabID, tabData = getTabInfo(info)
          local shownIDs = {}
          for tabID,tabData in dataManager:ForEach(enums.tab, getLeaf(info, 3).arg) do
            if tabID ~= originalTabID then
              shownIDs[tabID] = tabData.name
            end
          end
          return shownIDs
        end,
        get = function(info, key)
          local tabID, tabData = getTabInfo(info)
          return not not tabData.shownIDs[key]
        end,
        set = function(info, key, state)
          local tabID, tabData = getTabInfo(info)
      		dataManager:UpdateShownTabID(tabID, key, state)
        end,
      },

      -- / layout widgets / --

      -- spacers
      spacer121 = {
        order = 1.21,
        type = "description",
        width = "full",
        name = "",
      },
      spacer131 = {
        order = 1.31,
        type = "description",
        width = "full",
        name = "",
      },
      spacer141 = {
        order = 1.41,
        type = "description",
        width = "full",
        name = "",
      },
      spacer151 = {
        order = 1.51,
        type = "description",
        width = "full",
        name = "",
      },
      spacer161 = {
        order = 1.61,
        type = "description",
        width = "full",
        name = "",
      },
    },
  },

  -- / auto-reset / --

  autoResetTab = {
    order = 1.2,
    type = "group",
    name = "Auto-Reset",
    args = {
      resetDaysSelect = {
        order = 2.1,
        type = "multiselect",
        name = "Reset days",
        width = "full",
        values = function(info)
          return enums.days
        end,
        get = function(info, key)
          local _, tabData = getTabInfo(info)
          return not not tabData.reset.days[key]
        end,
        set = function(info, key, state)
          local tabID = getTabInfo(info)
      		resetManager:UpdateResetDay(tabID, key, state)
        end,
      },
      configureResetGroup = {
        order = 2.2,
        type = "group",
        name = "Configure reset times",
        inline = true,
        args = {
          configureDaySelect = {
            order = 1.1,
            type = "select",
            name = "Configure day",
            width = 0.9,
            values = function(info)
              local _, tabData = getTabInfo(info)
              local days = {}
              for day in pairs(tabData.reset.days) do
                days[day] = enums.days[day]
              end
              if not days[tabData.reset.configureDay] then
                tabData.reset.configureDay = next(days)
                print("SET CONFIGURE DAY", tabData.reset.configureDay)
              end
              return days
            end,
            get = function(info)
              local _, tabData = getTabInfo(info)
              return tabData.reset.configureDay
            end,
            set = function(info, value)
              local _, tabData = getTabInfo(info)
              tabData.reset.configureDay = value
            end,
            hidden = function(info)
              local _, tabData = getTabInfo(info)
              return tabData.reset.isSameEachDay
            end,
          },
          isSameEachDayToggle = {
            order = 1.2,
            type = "toggle",
            name = "Same each day",
            width = 0.9,
            get = function(info)
              local _, tabData = getTabInfo(info)
              return tabData.reset.isSameEachDay
            end,
            set = function(info, state)
              local tabID = getTabInfo(info)
              resetManager:UpdateIsSameEachDay(tabID, state)
            end,
          },
          addNewResetTimeExecute = {
            order = 1.3,
            type = "execute",
            name = "Add new reset",
            width = 0.9,
            func = function(info)
              local tabID, _, resetData = getTabInfo(info)
              resetManager:AddResetTime(tabID, resetData)
            end,
          },
          removeResetTimeExecute = {
            order = 1.4,
            type = "execute",
            name = "Remove reset",
            width = 0.9,
            func = function(info)
              local tabID, tabData, resetData = getTabInfo(info)
              resetManager:RemoveResetTime(tabID, resetData, tabData.reset.configureResetTime)
            end,
            hidden = function(info)
              local _, _, resetData = getTabInfo(info)
              return not resetManager:CanRemoveResetTime(resetData)
            end
          },
          configureResetTimeSelect = {
            order = 1.5,
            type = "select",
            name = "Configure reset",
            width = 0.9,
            values = function(info)
              local _, tabData, resetData = getTabInfo(info)
              local resets = {}
              for resetTimeName in pairs(resetData.resetTimes) do
                resets[resetTimeName] = resetTimeName
              end
              if not resets[tabData.reset.configureResetTime] then
                tabData.reset.configureResetTime = next(resets)
              end
              return resets
            end,
            get = function(info)
              local _, tabData = getTabInfo(info)
              return tabData.reset.configureResetTime
            end,
            set = function(info, value)
              local _, tabData = getTabInfo(info)
              tabData.reset.configureResetTime = value
            end,
          },
          renameResetTimeInput = {
            order = 1.6,
            type = "input",
            name = "Rename",
            width = 0.9,
            get = function(info)
              local _, tabData = getTabInfo(info)
              return tabData.reset.configureResetTime
            end,
            set = function(info, newName)
              local tabID, tabData, resetData = getTabInfo(info)
              resetManager:RenameResetTime(tabID, resetData, tabData.reset.configureResetTime, newName)
            end,
          },
          hourResetTimeRange = {
            order = 1.7,
            type = "range",
            name = "Hour",
            min = 0,
            max = 23,
            step = 1,
            get = function(info)
              local _, tabData, resetData = getTabInfo(info)
              return resetData.resetTimes[tabData.reset.configureResetTime].hour
            end,
            set = function(info, value)
              local tabID, tabData, resetData = getTabInfo(info)
              local timeData = resetData.resetTimes[tabData.reset.configureResetTime]
              resetManager:UpdateTimeData(tabID, timeData, value)
            end,
          },
          minResetTimeRange = {
            order = 1.8,
            type = "range",
            name = "Min",
            min = 0,
            max = 59,
            step = 1,
            get = function(info)
              local _, tabData, resetData = getTabInfo(info)
              return resetData.resetTimes[tabData.reset.configureResetTime].min
            end,
            set = function(info, value)
              local tabID, tabData, resetData = getTabInfo(info)
              local timeData = resetData.resetTimes[tabData.reset.configureResetTime]
              resetManager:UpdateTimeData(tabID, timeData, nil, value)
            end,
          },
          secResetTimeRange = {
            order = 1.9,
            type = "range",
            name = "Sec",
            min = 0,
            max = 59,
            step = 1,
            get = function(info)
              local _, tabData, resetData = getTabInfo(info)
              return resetData.resetTimes[tabData.reset.configureResetTime].sec
            end,
            set = function(info, value)
              local tabID, tabData, resetData = getTabInfo(info)
              local timeData = resetData.resetTimes[tabData.reset.configureResetTime]
              resetManager:UpdateTimeData(tabID, timeData, nil, nil, value)
            end,
          },

          -- / layout widgets / --

          spacer121 = {
            order = 1.21,
            type = "description",
            width = "full",
            name = "",
          },
          spacer141 = {
            order = 1.41,
            type = "description",
            width = "full",
            name = "",
          },
          spacer161 = {
            order = 1.61,
            type = "description",
            width = "full",
            name = "",
          },
          spacer171 = {
            order = 1.71,
            type = "description",
            width = "full",
            name = "",
          },
          spacer181 = {
            order = 1.81,
            type = "description",
            width = "full",
            name = "",
          },
        },
        hidden = function(info)
          local _, tabData = getTabInfo(info)
          return not next(tabData.reset.days) -- the configure group only appears if there is at least one day selected
        end,
      },
    },
  },

  -- -- headers
  -- header1 = {
  --   order = 1,
  --   type = "header",
  --   name = "Settings",
  -- },
  -- header2 = {
  --   order = 2,
  --   type = "header",
  --   name = "Auto-Reset",
  -- },
}

local tabAddTable = {
  addInput = {
    order = 1.1,
    type = "input",
    name = "Tab name",
    get = function(info)
      return ""
    end,
    set = function(info, tabName)
      dataManager:CreateTab(tabName, getLeaf(info, 3).arg)
    end,
  },

  -- / layout widgets / --

  -- spacers
  -- spacer099 = {
  --   order = 0.99,
  --   type = "description",
  --   width = "full",
  --   name = "\n",
  -- }, -- spacer099

  -- headers
  header1 = {
    order = 0,
    type = "header",
    name = "Add a new tab",
  }, -- header1
}

function private:UpdateTabsInOptions(options)
  -- local options = getLeaf(info, 3)
  local arg, args = options.arg, options.args

  for k,v in pairs(args) do
    if v.type == "group" then
      args[k] = nil
    end
  end

  for tabID,tabData in dataManager:ForEach(enums.tab, arg) do -- for each tab in the correct profile state
    args[tabID] = { -- we add them as selectable sub-groups under the good parent
      order = function()
        return dataManager:GetPosData(tabID, nil, true)
      end,
      type = "group",
      childGroups = "tab",
      name = tabData.name,
      arg = tabID,
      args = tabManagementTable,
    }
  end
end

function private:RefreshTabManagement()
  -- !! this func is important, as it refreshes the profile/global groups contents when adding/removing tabs
  local profile = optionsManager.optionsTable.args.main.args.tabs.args["groupProfileTabManagement"]
  local global = optionsManager.optionsTable.args.main.args.tabs.args["groupGlobalTabManagement"]
  private:UpdateTabsInOptions(profile)
  private:UpdateTabsInOptions(global)
end

local function createAddonOptionsTable()
  optionsManager.optionsTable = {
    handler = optionsManager,
    type = "group",
    name = core.toc.title.." ("..core.toc.version..")",
    get = function(info) return NysTDL.db.profile[info[#info]] end,
    set = function(info, ...)
      if NysTDL.db.profile[info[#info]] ~= nil then
        NysTDL.db.profile[info[#info]] = ...
      end
    end,
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
                get = function() return unpack(NysTDL.db.profile.favoritesColor) end,
                set = function(info, ...)
                  NysTDL.db.profile.favoritesColor = { ... }
                  mainFrame:UpdateVisuals()
                end,
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
                get = function() return NysTDL.db.profile.tdlButton.show end,
                set = function(info, value)
                  NysTDL.db.profile.tdlButton.show = value
                  widgets:RefreshTDLButton()
                end,
              }, -- tdlButtonShow
              tdlButtonRed = {
                order = 2.4,
                type = "toggle",
                name = L["Red"],
                desc = L["Changes the color of the TDL button if there are items left to do before tomorrow"],
                get = function() return NysTDL.db.profile.tdlButton.red end,
                set = function(info, value)
                  NysTDL.db.profile.tdlButton.red = value
                  widgets:UpdateTDLButtonColor()
                end,
                hidden = function() return not NysTDL.db.profile.tdlButton.show end
              }, -- tdlButtonShow
              minimapButtonHide = {
                order = 2.1,
                type = "toggle",
                name = L["Show minimap button"],
                desc = L["Toggles the display of the minimap button"],
                get = function() return not NysTDL.db.profile.minimap.hide end,
                set = function(_, value)
                  NysTDL.db.profile.minimap.hide = not value
                  databroker:RefreshMinimapButton()
                end,
              }, -- minimapButtonHide
              minimapButtonTooltip = {
                order = 2.2,
                -- disabled = function() return NysTDL.db.profile.minimap.hide end,
                type = "toggle",
                name = L["Show tooltip"],
                desc = L["Show the tooltip of the minimap/databroker button"],
                get = function() return NysTDL.db.profile.minimap.tooltip end,
                set = function(_, value)
                  NysTDL.db.profile.minimap.tooltip = value
                  databroker:RefreshMinimapButton()
                end,
              }, -- minimapButtonTooltip
              keyBind = {
                type = "keybinding",
                name = L["Show/Hide the list"],
                desc = L["Bind a key to toggle the list"]..'\n'..L["(independant from profile)"],
                order = 1.1,
                get = function() return GetBindingKey("NysTDL") end,
                set = function(info, newKey)
                  -- we only want one key to be ever bound to this
                  local key1, key2 = GetBindingKey("NysTDL") -- so first we get both keys associated to thsi addon (in case there are)
                  -- then we delete their binding from this addon (we clear every binding from this addon)
                  if key1 then SetBinding(key1) end
                  if key2 then SetBinding(key2) end

                  -- and finally we set the new binding key
                  if newKey ~= '' then -- considering we pressed one (not ESC)
                    SetBinding(newKey, "NysTDL")
                  end

                  -- and save the changes

                  --@retail@
                  SaveBindings(GetCurrentBindingSet())
                  --@end-retail@

                  --[===[@non-retail@
                  AttemptToSaveBindings(GetCurrentBindingSet())
                  --@end-non-retail@]===]
                end,
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
              optionsUpdater = {
                -- this is completely hidden from the UI and is only here to silently update
                -- the tab groups whenever there is a change.
                order = 0.1,
                type = "toggle",
                name = "options updater",
                -- whenever a setter is called when this tab of the options is opened OR we opened this tab,
                -- AceConfig will call each getter/disabled/hidden values of everything present on the page,
                -- so putting the update func here actually works really well
                hidden = function()
                  private:RefreshTabManagement()
                  widgets:UpdateTDLButtonColor() -- in case we changed reset times
                  tabsFrame:Refresh() -- in case we changed tab data
                  return true
                end,
              }, -- optionsUpdater
              groupProfileTabManagement = {
                order = 1.1,
                type = "group",
                name = "Profile tabs",
                arg = false,
                args = utils:Deepcopy(tabAddTable),
              }, -- groupProfileTabManagement
              groupGlobalTabManagement = {
                order = 1.2,
                type = "group",
                name = "Global tabs",
                arg = true,
                args = utils:Deepcopy(tabAddTable),
                hidden = true, -- TDLATER remove to implement global tabs
              }, -- groupGlobalTabManagement

              -- / layout widgets / --

              -- spacers
              -- spacer111 = {
              --   order = 1.11,
              --   type = "description",
              --   width = "full",
              --   name = "\n",
              -- }, -- spacer111

              -- headers
              header1 = {
                order = 1,
                type = "header",
                name = "Tab Management",
              }, -- header1
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
end

--/*******************/ GENERAL FUNCTIONS /*************************/--

-- Bindings.xml access
function NysTDL:ToggleFrame()
  mainFrame:Toggle()
end

function optionsManager:ToggleOptions(fromFrame)
  if InterfaceOptionsFrame:IsShown() then -- if the interface options frame is currently opened
    if InterfaceOptionsFrameAddOns.selection ~= nil then -- then we check if we're currently in the AddOns tab and if we are currently selecting an addon
      if InterfaceOptionsFrameAddOns.selection.name == core.toc.title then -- and if we are, we check if we're looking at this addon
        if fromFrame then return true end
        InterfaceOptionsFrame:Hide() -- and only if we are and we click again on the button, we close the interface options frame.
        return
      end
    end
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
  else
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    if InterfaceOptionsFrameAddOns.selection == nil then -- for the first opening, we have to do it 2 time for it to correctly open our addon options page
      InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    end
  end
end

function optionsManager:InitializeOptionsWidthRecursive(table, wDef)
  for _,v in pairs(table) do
    if (v.type == "group") then
      self:InitializeOptionsWidthRecursive(v.args, wDef)
    elseif (v.type ~= "description" and v.type ~= "header") then -- for every widget (except the descriptions and the headers), we keep their min normal width, we change it only if their name is bigger than the default width
      local w = widgets:NoPointsLabel(UIParent, nil, v.name):GetWidth()
      if wDef[v.type] then
        -- print (v.name.."_"..w)
        w = tonumber(string.format("%.3f", w/wDef[v.type]))
        if (w > 1) then
          v.width = w
        end
      end
    end
  end
end

--/*******************/ INITIALIZATION /*************************/--

function optionsManager:Initialize()
  -- first things first, we create the addon's options table
  createAddonOptionsTable()

  -- this is for adapting the width of the widgets to the length of their respective names (that can change with the locale)
  local wDef = { toggle = 160, select = 265, range = 200, keybinding = 200, color = 180 }
  optionsManager:InitializeOptionsWidthRecursive(optionsManager.optionsTable.args.main.args, wDef)

  -- we register our options table for AceConfig
  LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(optionsManager.optionsTable, addonName)
  LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, optionsManager.optionsTable)

  -- then we add the profiles management, using AceDBOptions
  optionsManager.optionsTable.args.child_profiles.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(NysTDL.db)
  -- we also modify it a bit to better fit our needs (by adding some confirm pop-ups)
  local args = utils:Deepcopy(optionsManager.optionsTable.args.child_profiles.args.profiles.args)
  args.reset.confirm = true
  args.reset.confirmText = L["WARNING"]..'\n\n'..L["Resetting this profile will also clear the list."]..'\n'..L["Are you sure?"]..'\n'
  args.copyfrom.confirm = true
  args.copyfrom.confirmText = L["This action will override your settings, including the list."]..'\n'..L["Are you sure?"]..'\n'
  optionsManager.optionsTable.args.child_profiles.args.profiles.args = args

  -- we add our frame to wow's interface options panel
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, core.toc.title, nil, "main")
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, L["Profiles"], core.toc.title, "child_profiles")
end
