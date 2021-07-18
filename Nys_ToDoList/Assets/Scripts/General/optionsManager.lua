-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local databroker = addonTable.databroker
local mainFrame = addonTable.mainFrame
local optionsManager = addonTable.optionsManager

-- Variables
local L = core.L
local LDB = core.LDB
local LDBIcon = core.LDBIcon

--/*******************/ GENERAL FUNCTIONS /*************************/--

-- Bindings.xml access
function NysTDL:ToggleFrame()
  mainFrame:Toggle()
end

function optionsManager:ToggleOptions(fromFrame)
  if (InterfaceOptionsFrame:IsShown()) then -- if the interface options frame is currently opened
    if (InterfaceOptionsFrameAddOns.selection ~= nil) then -- then we check if we're currently in the AddOns tab and if we are currently selecting an addon
      if (InterfaceOptionsFrameAddOns.selection.name == core.toc.title) then -- and if we are, we check if we're looking at this addon
        if (fromFrame) then return true end
        InterfaceOptionsFrame:Hide() -- and only if we are and we click again on the button, we close the interface options frame.
        return
      end
    end
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
  else
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    if (InterfaceOptionsFrameAddOns.selection == nil) then -- for the first opening, we have to do it 2 time for it to correctly open our addon options page
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

  recursiveGet("options", database.options)
end

function optionsManager:InitializeOptionsWidthRecursive(table, wDef)
  for _,v in pairs(table) do
    if (v.type == "group") then
      self:InitializeOptionsWidthRecursive(v.args, wDef)
    elseif (v.type ~= "description" and v.type ~= "header") then -- for every widget (except the descriptions and the headers), we keep their min normal width, we change it only if their name is bigger than the default width
      local w = widgets:NoPointsLabel(UIParent, nil, v.name):GetWidth()
      -- print (v.name.."_"..w)
      w = tonumber(string.format("%.3f", w/wDef[v.type]))
      if (w > 1) then
        v.width = w
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
  mainFrame:UpdateVisuals()
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
  mainFrame:Refresh()
end

--/*******************/ INITIALIZATION /*************************/--

function optionsManager:Initialize()
  -- this is for adapting the width of the widgets to the length of their respective names (that can change with the locale)
  local wDef = { toggle = 160, select = 265, range = 200, keybinding = 200, color = 180 }
  self:InitializeOptionsWidthRecursive(database.options.args.main.args, wDef)

  -- we register our options table for AceConfig
  LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(database.options, addonName)
  LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, database.options)

  -- then we add the profiles management, using AceDBOptions
  database.options.args.child_profiles.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(NysTDL.db)
  -- we also modify it a bit to better fit our needs (by adding some confirm pop-ups)
  local args = utils:Deepcopy(database.options.args.child_profiles.args.profiles.args)
  args.reset.confirm = true
  args.reset.confirmText = L["WARNING"]..'\n\n'..L["Resetting this profile will also clear the list."]..'\n'..L["Are you sure?"]..'\n'
  args.copyfrom.confirm = true
  args.copyfrom.confirmText = L["This action will override your settings, including the list."]..'\n'..L["Are you sure?"]..'\n'
  database.options.args.child_profiles.args.profiles.args = args

  -- we add our frame to wow's interface options panel
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, core.toc.title, nil, "main")
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, L["Profiles"], core.toc.title, "child_profiles")
end
