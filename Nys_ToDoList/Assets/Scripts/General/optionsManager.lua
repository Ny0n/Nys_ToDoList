-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local mainFrame = addonTable.mainFrame
local databroker = addonTable.databroker
local dataManager = addonTable.dataManager
local optionsManager = addonTable.optionsManager

-- Variables
local L = core.L
local LDB = core.LDB
local LDBIcon = core.LDBIcon

--/*******************/ OPTIONS TABLES /*************************/--

function getLeaf(info, x)
  local tbl = optionsManager.optionsTable
  for i=1,x do
    tbl = tbl.args[info[i]]
  end
  return tbl
end

local tabManagementTable = {
  addInput = {
    order = 1.1,
    type = "execute",
    name = "hey",
    func = function(...)
      print(...)
      for k,v in pairs(...) do
        print(k,v)
      end
    end,
  },
  removeButton = {
    order = 1.1,
    type = "execute",
    name = "Remove tab",
    func = function(info)
      local tabID = getLeaf(info, 4).arg
      dataManager:DeleteTab(tabID)
      local tbl1 = optionsManager.optionsTable.args.main.args.tabs.args["groupProfileTabManagement"]
      local tbl2 = optionsManager.optionsTable.args.main.args.tabs.args["groupGlobalTabManagement"]
      optionsManager:UpdateTabsInOptions(tbl1)
      optionsManager:UpdateTabsInOptions(tbl2)
      LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
    end,
  },
}

local tabAddTable = {
  addInput = {
    order = 1.1,
    type = "input",
    name = "Tab name",
    get = function(info)
      local tbl1 = optionsManager.optionsTable.args.main.args.tabs.args["groupProfileTabManagement"]
      local tbl2 = optionsManager.optionsTable.args.main.args.tabs.args["groupGlobalTabManagement"]
      optionsManager:UpdateTabsInOptions(tbl1)
      optionsManager:UpdateTabsInOptions(tbl2)
      return ""
    end,
    set = function(info, tabName)
      dataManager:CreateTab(tabName, getLeaf(info, 3).arg)
    end,
  },

  -- / layout widgets / --

  -- -- spacers
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

function optionsManager:UpdateTabsInOptions(options)
  -- local options = getLeaf(info, 3)
  local arg, args = options.arg, options.args

  for k,v in pairs(args) do
    print("try to nil")
    if v.type == "group" then
      args[k] = nil
    end
  end

  for tabID,tabData in dataManager:ForEach(enums.tab, arg) do
    args[tabID] = {
      order = 1.1,
      type = "group",
      name = tabData.name,
      arg = tabID,
      args = tabManagementTable,
    }
  end

  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end

local function createAddonOptionsTable()
  optionsManager.optionsTable = {
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
              }, -- groupGlobalTabManagement

              -- / layout widgets / --

              -- spacers
              spacer099 = {
                order = 0.99,
                type = "description",
                width = "full",
                name = "\n",
              }, -- spacer099

              -- headers
              header1 = {
                order = 0,
                type = "header",
                name = L["General"],
              }, -- header1
              header2 = {
                order = 1,
                type = "header",
                name = "Tab Management",
              }, -- header2
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

--/*******************/ GETTERS/SETTERS /*************************/--

-- for each of the getters, we also call the setters to set the value to the current one,
-- just to update them (in case we switched profiles or something happened and only the getters are called,
-- the actual states of the buttons are not updated), this allows us to not call a special function to
-- reupdate everything right when we switch profiles: this is now done automatically.

function optionsManager:CallAllGETTERS()
  -- this simply calls every getters of every options in the options table
  -- (and so updates them, since I also call the setters like explained before)

  local info = {}

  local function recursiveGet(argName, argTable, getter)
    getter = argTable.get or getter
    table.wipe(info)
    table.insert(info, argName)

    if (argTable.type == "group") then
      for subArgName, subArgTable in pairs(argTable.args) do
        recursiveGet(subArgName, subArgTable, getter)
      end
    else
      if (argTable.type ~= "description" and argTable.type ~= "header" and argName ~= "profiles") then
        if (type(getter) == "string") then
          if getter == "GetCurrentProfile" then return end -- TODO hmmmm?
          optionsManager[getter](optionsManager, info)
        elseif(type(getter) == "function") then
          getter(info)
        end
      end
    end
  end

  recursiveGet("options", optionsManager.optionsTable)
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

-- // global getters and setters // --

function optionsManager:Getter(info)
  self:Setter(info, NysTDL.db.profile[info[#info]])
  return NysTDL.db.profile[info[#info]]
end

function optionsManager:Setter(info, ...)
  NysTDL.db.profile[info[#info]] = ...
  print("Setter")
end

-- // specific getters and setters // --

-- // 'General' tab // --

--favoritesColor
function optionsManager:favoritesColorGET(info)
  self:favoritesColorSET(info, unpack(NysTDL.db.profile.favoritesColor))
  return unpack(NysTDL.db.profile.favoritesColor)
end

function optionsManager:favoritesColorSET(info, ...)
  NysTDL.db.profile.favoritesColor = { ... }
  -- mainFrame:UpdateVisuals() -- TODO unauthorised
end

-- tdlButtonShow
function optionsManager:tdlButtonShowGET(info)
  self:tdlButtonShowSET(info, NysTDL.db.profile.tdlButton.show)
  return NysTDL.db.profile.tdlButton.show
end

function optionsManager:tdlButtonShowSET(info, newValue)
  NysTDL.db.profile.tdlButton.show = newValue
  widgets:RefreshTDLButton()
end

-- tdlButtonRed
function optionsManager:tdlButtonRedGET(info)
  self:tdlButtonRedSET(info, NysTDL.db.profile.tdlButton.red)
  return NysTDL.db.profile.tdlButton.red
end

function optionsManager:tdlButtonRedSET(info, newValue)
  NysTDL.db.profile.tdlButton.red = newValue
  widgets:UpdateTDLButtonColor()
end

-- minimapButtonHide
function optionsManager:minimapButtonHideGET(info)
  self:minimapButtonHideSET(info, NysTDL.db.profile.minimap.hide)
  return NysTDL.db.profile.minimap.hide
end

function optionsManager:minimapButtonHideSET(info, newValue)
  NysTDL.db.profile.minimap.hide = newValue
  databroker:RefreshMinimapButton()
end

-- minimapButtonTooltip
function optionsManager:minimapButtonTooltipGET(info)
  self:minimapButtonTooltipSET(info, NysTDL.db.profile.minimap.tooltip)
  return NysTDL.db.profile.minimap.tooltip
end

function optionsManager:minimapButtonTooltipSET(info, newValue)
  NysTDL.db.profile.minimap.tooltip = newValue
  databroker:RefreshMinimapButton() -- XXX
end

-- keyBind
function optionsManager:keyBindGET(info)
  -- here we don't need to call the SET since the key binding is independant of profiles
  return GetBindingKey("NysTDL")
end

function optionsManager:keyBindSET(info, newKey)
  -- we only want one key to be ever bound to this
  local key1, key2 = GetBindingKey("NysTDL") -- so first we get both keys associated to thsi addon (in case there are)
  -- then we delete their binding from this addon (we clear every binding from this addon)
  if key1 then SetBinding(key1) end
  if key2 then SetBinding(key2) end

  -- and finally we set the new binding key
  if (newKey ~= '') then -- considering we pressed one (not ESC)
    SetBinding(newKey, "NysTDL")
  end

  -- and save the changes

  --@retail@
  SaveBindings(GetCurrentBindingSet())
  --@end-retail@

  --[===[@non-retail@
  AttemptToSaveBindings(GetCurrentBindingSet())
  --@end-non-retail@]===]
end

-- // 'Tabs' tab // --

function optionsManager:GetterTabs(info)
  self:SetterTabs(info, NysTDL.db.profile[info[#info]])
  return NysTDL.db.profile[info[#info]]
end

function optionsManager:SetterTabs(info, ...)
  NysTDL.db.profile[info[#info]] = ...
  print("SetterTabs")
end

--/*******************/ INITIALIZATION /*************************/--

function optionsManager:Initialize()
  -- first things first, we create the addon's options table
  createAddonOptionsTable()

  -- this is for adapting the width of the widgets to the length of their respective names (that can change with the locale)
  local wDef = { toggle = 160, select = 265, range = 200, keybinding = 200, color = 180 }
  self:InitializeOptionsWidthRecursive(optionsManager.optionsTable.args.main.args, wDef)

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
