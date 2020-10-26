-- Namespaces
local addonName, tdlTable = ...;
tdlTable.init = {}; -- adds init table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;
local init = tdlTable.init;

-- Variables

local L = config.L;
local LDB = config.LDB;
local LDBIcon = config.LDBIcon;
local tdlButton;
local addonLoaded = false;

--/*******************/ GENERAL FUNCTIONS /*************************/--

function NysTDL:ToggleFrame()
  -- Bindings.xml access
  itemsFrame:Toggle();
end

function NysTDL:ToggleOptions(fromFrame)
  if (InterfaceOptionsFrame:IsShown()) then -- if the interface options frame is currently opened
    if (InterfaceOptionsFrameAddOns.selection ~= nil) then -- then we check if we're currently in the AddOns tab and if we are currently selecting an addon
      if (InterfaceOptionsFrameAddOns.selection.name == config.toc.title) then -- and if we are, we check if we're looking at this addon
        if (fromFrame) then return true; end
        InterfaceOptionsFrame:Hide(); -- and only if we are and we click again on the button, we close the interface options frame.
        return;
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

function NysTDL:CreateTDLButton()
  -- Creating the big button to easily toggle the frame
  tdlButton = config:CreateButton("tdlButton", UIParent, string.gsub(config.toc.title, "Ny's ", ""));
  tdlButton:SetFrameLevel(100);
  tdlButton:SetMovable(true);
  tdlButton:EnableMouse(true);
  tdlButton:SetClampedToScreen(true);
  tdlButton:RegisterForDrag("LeftButton");
  tdlButton:SetScript("OnDragStart", tdlButton.StartMoving);
  tdlButton:SetScript("OnDragStop", function() -- we save its position
    tdlButton:StopMovingOrSizing()
    local points = self.db.profile.tdlButton.points
    points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset = tdlButton:GetPoint()
  end);
  tdlButton:SetScript("OnClick", itemsFrame.Toggle); -- the function the button calls when pressed
  NysTDL:RefreshTDLButton();
end

function NysTDL:RefreshTDLButton()
  local points = self.db.profile.tdlButton.points;
  tdlButton:ClearAllPoints();
  tdlButton:SetPoint(points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset);
  tdlButton:SetShown(self.db.profile.tdlButton.show);
end

function NysTDL:CreateMinimapButton()
  -- creating the data object to store the button infos

  local tooltipObject; -- we get the tooltip on the first draw_tooltip call from OnTooltipShow
  local function draw_tooltip(tooltip)
    if (not self.db.profile.minimap.tooltip) then
      tooltip:Hide();
      return;
    end

    if tooltip and tooltip.AddLine then
        -- we get the color theme
        local hex = config:RGBToHex(config.database.theme)

        -- then we create each line
        tooltip:ClearLines();
        tooltip:AddDoubleLine(config.toc.title, 'V'..config.database.version);
        tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", L["toggle the list"]))
        tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Shift-Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", L["toggle addon options"]))
        tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Ctrl-Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", NysTDL.db.profile.minimap.lock and L["unlock minimap button"] or L["lock minimap button"]))
        tooltip:Show()
    end
  end

  local LDB_o_minimap = LDB:NewDataObject(addonName, {
    type = "launcher",
    label = config.toc.title,
    icon = "Interface\\AddOns\\"..addonName.."\\Data\\Images\\minimap_icon",
    OnClick = function(self, button)
      if (IsControlKeyDown()) then
        -- lock minimap button
        if (not NysTDL.db.profile.minimap.lock) then
          LDBIcon:Lock(addonName)
        else
          LDBIcon:Unlock(addonName)
        end
        draw_tooltip(tooltipObject) -- we redraw the tooltip to display the lock change
      elseif (IsShiftKeyDown()) then
        -- toggle addon options
        NysTDL:ToggleOptions()
      else
        -- toggle the list
        NysTDL:ToggleFrame()
      end
    end,
    OnTooltipShow = function(tooltip)
      tooltipObject = tooltip
      draw_tooltip(tooltip)
    end,
  })

  -- Registering the data broker and creating the button
  LDBIcon:Register(addonName, LDB_o_minimap, self.db.profile.minimap)

  -- and this is the secret to correctly update the button position, (since we can't update it in the init code)
  -- so that the first time that we click on it, it doesn't go somewhere else like so many do,
  -- we just delay its update :D (a number of times to be sure, considering some ppl take longer times to load the UI)
  self.iconTimerCount = 0;
  self.iconTimerCountMax = 7;
  local delay = 1.2; -- in seconds

  -- so here, we are, each delay for max self.iconTimerCountMax seconds calling this function
  self.iconTimer = self:ScheduleRepeatingTimer(function()
    -- we really do this to call this function
    LDBIcon:Refresh(addonName, self.db.profile.minimap)

    -- and here we check and stop the timer when we're done
    self.iconTimerCount = self.iconTimerCount + 1;
    if self.iconTimerCount == self.iconTimerCountMax then
      self:CancelTimer(self.iconTimer)
    end
  end, delay)
end

function NysTDL:DBInit()
  -- initialization of elements that need access to other files functions or need to be updated correctly when the profile changes
  if (self.db.profile.autoReset == nil) then self.db.profile.autoReset = { ["Daily"] = config:GetSecondsToReset().daily, ["Weekly"] = config:GetSecondsToReset().weekly } end
  if (not self.db.profile.rememberUndo) then self.db.profile.undoTable = {} end
  if (self.db.profile.itemsList == nil) then self.db.profile.itemsList = {} end
  if (self.db.profile.itemsDaily == nil) then
    if (self.db.profile.itemsList["Daily"] ~= nil) then
      self.db.profile.itemsDaily = config:Deepcopy(self.db.profile.itemsList["Daily"])
      self.db.profile.itemsList["Daily"] = nil
    else
      self.db.profile.itemsDaily = {}
    end
  end
  if (self.db.profile.itemsWeekly == nil) then
    if (self.db.profile.itemsList["Weekly"] ~= nil) then
    self.db.profile.itemsWeekly = config:Deepcopy(self.db.profile.itemsList["Weekly"])
    self.db.profile.itemsList["Weekly"] = nil
    else
      self.db.profile.itemsWeekly = {}
    end
  end
end

function NysTDL:ProfileChanged()
  NysTDL:DBInit(); -- in case the selected profile is empty

  -- we update the changes for the list
  itemsFrame:ResetContent();
  itemsFrame:Init();

  -- we update the changes to the options (since I now use tabs and the options are not instantly getting a refresh when changing profiles)
  NysTDL:CallAllGETTERS();
end

--/*******************/ EVENTS /*************************/--
-- we need to put them here so they have acces to every function in every file of the addon

function NysTDL:PLAYER_LOGIN()
  if (NysTDL.db.profile.UI_reloading) then -- just to be sure that it wasn't a reload, but a genuine player log in
    NysTDL.db.profile.UI_reloading = false
    return;
  end

  self:ScheduleTimer(function(self) -- 20 secs after the player logs in, we check if we need to warn him about favorite items
    if (addonLoaded) then -- just to be sure
      if (not itemsFrame:autoResetedThisSessionGET()) then -- we don't want to show this warning if it's the first log in of the day, only if it is the next ones
        if (NysTDL.db.profile.showFavoritesWarning) then -- and the user allowed this functionnality
          local _, _, _, _, daily, weekly = itemsFrame:updateRemainingNumber()
          if ((daily + weekly) > 0) then -- and there is at least one daily or weekly favorite left to do
            local str = ""

            -- we first check if there are daily ones
            if (daily > 0) then
              if ((NysTDL.db.profile.autoReset["Daily"] - time()) < 86400) then -- pretty much all the time
                str = str..daily.." ("..L["Daily"]..")"
              end
            end

            -- then we check if there are weekly ones
            if (weekly > 0) then
              if ((NysTDL.db.profile.autoReset["Weekly"] - time()) < 86400) then -- if there is less than one day left before the weekly reset
                if (str ~= "") then
                  str = str.." + "
                end
                str = str..weekly.." ("..L["Weekly"]..")"
              end
            end

            if (str ~= "") then
              local timeUntil = config:GetTimeUntilReset()
              local str2 = L["Time remaining: %i hours %i min"]:format(timeUntil.hour, timeUntil.min + 1)
              local hex = config:RGBToHex({ NysTDL.db.profile.favoritesColor[1]*255, NysTDL.db.profile.favoritesColor[2]*255, NysTDL.db.profile.favoritesColor[3]*255} )
              str = string.format("|cff%s%s|r", hex, str)
              config:PrintForced("--------------| "..L["WARNING"].." |--------------")
              config:PrintForced(L["You still have %s favorite item(s) to do before the next reset, don't forget them!"]:format(str).." ("..str2..")")
            end
          end
        end
      end
    end
  end, 20)
end

--/*******************/ CHAT COMMANDS /*************************/--
-- we need to put them here so they have acces to every function in every file of the addon

-- Commands:
init.commands = {
  [L["help"]] = function(...)
    local hex = config:RGBToHex(config.database.theme2)
    config:PrintForced(string.format("|cff%s%s|r", hex, L["/tdl"])..' - '..L["show/hide the list"])
    config:PrintForced(string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["info"])..' - '..L["shows more information"])
  end,

  [""] = function(...)
    itemsFrame:Toggle()
  end,

  [L["info"]] = function(...)
    local hex = config:RGBToHex(config.database.theme2)
    config:PrintForced(L["Here are a few commands to help you understand some systems in the list:"].." - "..string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["toggleways"]).." - "..string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["additems"]).." - "..string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["favorites"]).." - "..string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["descriptions"]).." - "..string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["hiddenbuttons"]))
  end,

  [L["toggleways"]] = function(...)
    config:PrintForced(L["To toggle the list, you have several ways:"]..'\n- '..L["minimap button (the default)"]..'\n- '..L["a normal TDL button"]..'\n- '..L["databroker plugin (eg. titan panel)"]..'\n- '..L["the '/tdl' command"]..'\n- '..L["key binding"]..'\n'..L["Go to the addon options in the Blizzard interface panel to customize this."])
  end,

  [L["additems"]] = function(...)
    config:PrintForced("- "..L["To add a new item to a category, just right click the category name!"]..'\n- '..L["You can also left click on the category names to expand or shrink their content."])
  end,

  [L["favorites"]] = function(...)
    config:PrintForced(L["You can favorite items!"].."\n"..L["To do so, hold the SHIFT key when the list is opened, then click on the star icons to favorite the items that you want!"].."\n"..L["Perks of favorite items:"].."\n- "..L["cannot be deleted"].."\n- "..L["customizable color"].."\n- "..L["sorted first in categories"].."\n- "..L["have their own more visible remaining numbers"].."\n- "..L["have an auto chat warning/reminder system!"])
  end,

  [L["descriptions"]] = function(...)
    config:PrintForced(L["You can add descriptions on items!"].."\n"..L["To do so, hold the CTRL key when the list is opened, then click on the page icons to open a description frame!"].."\n- "..L["they are auto-saved and have no length limitations"].."\n- "..L["if an item has a description, he cannot be deleted (empty the description if you want to do so)"])
  end,

  [L["hiddenbuttons"]] = function(...)
    config:PrintForced(L["There are some hidden buttons on the list."].."\n"..L["To show them, hold the ALT key when the list is opened!"])
  end,
}

-- Command catcher:
local function HandleSlashCommands(str)
  local path = init.commands; -- optimise!

  if (#str == 0) then
    -- User just entered "/tdl" with no additional args.
    path[""]();
    return;
  end

  local args = {string.split(' ', str)};

  local deep = 1;
  for id, arg in pairs(args) do
    arg = arg:lower(); -- current arg to low caps

    if (path[arg]) then
      if (type(path[arg]) == "function") then
        -- all remaining args passed to our function!
        path[arg](select(id + 1, unpack(args)))
        return;
      elseif (type(path[arg]) == "table") then
        deep = deep + 1;
        path = path[arg]; -- another sub-table found!

        if ((select(deep, unpack(args))) == nil) then
          -- User just entered "/tdl" with no additional args.
          path[""]();
          return;
        end
      end
    else
      -- does not exist!
      init.commands[L["help"]]();
      return;
    end
  end
end

--/*******************/ GETTERS/SETTERS /*************************/--
-- we need to put them here so they have acces to every function in every file of the addon

-- for each of the getters, we also call the setters to set the value to the current one,
-- just to update them (in case we switched profiles or something happened and only the getters are called,
-- the actual states of the buttons are not updated), this allows us to not call a special function to
-- reupdate everything right when we switch profiles: this is now done automatically.

function NysTDL:CallAllGETTERS()
  -- this simply calls every getters of every options in the options table
  -- (and so updates them, since i also call the setters like explained before)
  for _,v in pairs(config.database.options.args.general.args) do
    if (v.type ~= "description" and v.type ~= "header") then
      if (type(v.get) == "string") then
        NysTDL[v.get]();
      elseif(type(v.get) == "function") then
        v:get();
      end
    end
  end
end

-- weeklyDay
function NysTDL:weeklyDayGET(info)
  NysTDL:weeklyDaySET(info, NysTDL.db.profile.weeklyDay)
  return NysTDL.db.profile.weeklyDay;
end

function NysTDL:weeklyDaySET(info, newValue)
  NysTDL.db.profile.weeklyDay = newValue;
  NysTDL.db.profile.autoReset["Weekly"] = config:GetSecondsToReset().weekly;
end

-- dailyHour
function NysTDL:dailyHourGET(info)
  NysTDL:dailyHourSET(info, NysTDL.db.profile.dailyHour)
  return NysTDL.db.profile.dailyHour;
end

function NysTDL:dailyHourSET(info, newValue)
  NysTDL.db.profile.dailyHour = newValue;
  NysTDL.db.profile.autoReset["Daily"] = config:GetSecondsToReset().daily
  NysTDL.db.profile.autoReset["Weekly"] = config:GetSecondsToReset().weekly
end

--showChatMessages
function NysTDL:showChatMessagesGET(info)
  NysTDL:showChatMessagesSET(info, NysTDL.db.profile.showChatMessages)
  return NysTDL.db.profile.showChatMessages;
end

function NysTDL:showChatMessagesSET(info, newValue)
  NysTDL.db.profile.showChatMessages = newValue;
end

--showFavoritesWarning
function NysTDL:showFavoritesWarningGET(info)
  NysTDL:showFavoritesWarningSET(info, NysTDL.db.profile.showFavoritesWarning)
  return NysTDL.db.profile.showFavoritesWarning;
end

function NysTDL:showFavoritesWarningSET(info, newValue)
  NysTDL.db.profile.showFavoritesWarning = newValue;
end

--favoritesColor
function NysTDL:favoritesColorGET(info)
  NysTDL:favoritesColorSET(info, unpack(NysTDL.db.profile.favoritesColor))
  return unpack(NysTDL.db.profile.favoritesColor);
end

function NysTDL:favoritesColorSET(info, ...)
  NysTDL.db.profile.favoritesColor = { select(1, ...), select(2, ...), select(3, ...), select(4, ...) };
  itemsFrame:updateCheckButtons()
  itemsFrame:updateRemainingNumber()
end

-- tdlButtonShow
function NysTDL:tdlButtonShowGET(info)
  NysTDL:tdlButtonShowSET(info, NysTDL.db.profile.tdlButton.show)
  return NysTDL.db.profile.tdlButton.show;
end

function NysTDL:tdlButtonShowSET(info, newValue)
  NysTDL.db.profile.tdlButton.show = newValue;
  NysTDL:RefreshTDLButton();
end

-- minimapButtonHide
function NysTDL:minimapButtonHideGET(info)
  NysTDL:minimapButtonHideSET(info, NysTDL.db.profile.minimap.hide)
  return NysTDL.db.profile.minimap.hide;
end

function NysTDL:minimapButtonHideSET(info, newValue)
  NysTDL.db.profile.minimap.hide = newValue;
  LDBIcon:Refresh(addonName, NysTDL.db.profile.minimap)
end

-- minimapButtonTooltip
function NysTDL:minimapButtonTooltipGET(info)
  NysTDL:minimapButtonTooltipSET(info, NysTDL.db.profile.minimap.tooltip)
  return NysTDL.db.profile.minimap.tooltip;
end

function NysTDL:minimapButtonTooltipSET(info, newValue)
  NysTDL.db.profile.minimap.tooltip = newValue;
  LDBIcon:Refresh(addonName, NysTDL.db.profile.minimap)
end

-- rememberUndo
function NysTDL:rememberUndoGET(info)
  NysTDL:rememberUndoSET(info, NysTDL.db.profile.rememberUndo)
  return NysTDL.db.profile.rememberUndo;
end

function NysTDL:rememberUndoSET(info, newValue)
  NysTDL.db.profile.rememberUndo = newValue;
end

-- keyBind
function NysTDL:keyBindGET(info)
  -- here we don't need to call the SET since the key binding is independant of profiles
  return GetBindingKey("NysTDL");
end

function NysTDL:keyBindSET(info, newKey)
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
  if (config.toc.wowVersion == "retail") then
    SaveBindings(GetCurrentBindingSet())
  elseif (config.toc.wowVersion == "classic") then
    AttemptToSaveBindings(GetCurrentBindingSet())
  end
end

--/*******************/ INITIALIZATION /*************************/--

function NysTDL:OnInitialize()
    -- Called when the addon is loaded

    -- Register new Slash Command
    SLASH_NysToDoList1 = L["/tdl"];
    SlashCmdList.NysToDoList = HandleSlashCommands;

    -- Saved variable database
    self.db = LibStub("AceDB-3.0"):New("NysToDoListDB", config.database.defaults)
    self:DBInit(); -- initialization for some elements of the db that need specific functions

    -- since I changed the way to save variables (and am now using AceDB),
    -- we need (on the first load after the addon update) to take our important data
    -- contained in the old saved variable back, and we place it in the new DB
    if (ToDoListSV ~= nil) then
      self.db.profile.itemsDaily = config:Deepcopy(ToDoListSV.itemsList["Daily"])
      ToDoListSV.itemsList["Daily"] = nil
      self.db.profile.itemsWeekly = config:Deepcopy(ToDoListSV.itemsList["Weekly"])
      ToDoListSV.itemsList["Weekly"] = nil
      self.db.profile.itemsList = config:Deepcopy(ToDoListSV.itemsList)
      self.db.profile.checkedButtons = config:Deepcopy(ToDoListSV.checkedButtons)
      self.db.profile.autoReset = config:Deepcopy(ToDoListSV.autoReset)
      self.db.profile.lastLoadedTab = config:Deepcopy(ToDoListSV.lastLoadedTab)
      ToDoListSV = nil;
    end

    -- callbacks for database changes
    self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
    self.db.RegisterCallback(self, "OnDatabaseReset", "ProfileChanged")

    -- events registration
    self:RegisterEvent("PLAYER_LOGIN")
    hooksecurefunc("ReloadUI", function() NysTDL.db.profile.UI_reloading = true end) -- this is for knowing when the addon is loading, if it was a UI reload or the player logging in

    -- / Blizzard interface options / --

    -- this is for adapting the width of the widgets to the length of their respective names (that can change with the locale)
    local wDef = { toggle = 180, select = 275, range = 218, keybinding = 218, color = 190 }
    for _,v in pairs(config.database.options.args.general.args) do
      if (v.type == "toggle") then -- for them, we adapt their width to match the one of their name
        local w = config:CreateNoPointsLabel(UIParent, nil, v.name):GetWidth();
        w = tonumber(string.format("%.3f", w/wDef[v.type]));
        v.width = 1-((1-w)*0.82);
      -- elseif ((v.type == "description" and (v.name ~= "" and v.name ~= "\n" and v.name ~= nil)) and v.type ~= "header") then -- and for every other widget (except the spacers and the headers), we keep their min normal width, we change it only if their name is bigger than the default width
      elseif (v.type ~= "description" and v.type ~= "header") then -- and for every other widget (except the descriptions and the headers), we keep their min normal width, we change it only if their name is bigger than the default width
        local w = config:CreateNoPointsLabel(UIParent, nil, v.name):GetWidth();
        -- print(v.name.."_"..w)
        w = tonumber(string.format("%.3f", w/wDef[v.type]));
        if (w > 1) then
          v.width = w;
        end
      end
    end

    -- we register our options table for AceConfig
    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(config.database.options, addonName)
    -- We register all our options table to be shown in the main options frame in the interface panel (there are nos sub pages, here i'm using tabs)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, config.database.options) -- General tab, which is in the options table already
    config.database.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db) -- Profiles tab, taken from AceDBOptions

    -- we modify the profiles section a bit to better fit our needs
    -- config.database.options.args.profiles.inline = true
    local args = config:Deepcopy(config.database.options.args.profiles.args)
    args.reset.confirm = true
    args.reset.confirmText = L["WARNING"]..'\n\n'..L["Resetting this profile will also clear the list."]..'\n'..L["Are you sure?"]..'\n'
    args.copyfrom.confirm = true
    args.copyfrom.confirmText = L["This action will override your settings, including the list."]..'\n'..L["Are you sure?"]..'\n'
    config.database.options.args.profiles.args = args

    -- we add our frame to blizzard's interface options frame
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, config.toc.title, nil) -- using config.database.options
    -- self.optionsFrame.timeSinceLastUpdate = 0
    -- self.optionsFrame:HookScript("OnUpdate", NysTDL.optionsFrame_OnUpdate)

    -- / ********************** / --

    -- we create the 2 buttons
    NysTDL:CreateTDLButton();
    NysTDL:CreateMinimapButton();

    -- we create the frame
    itemsFrame:CreateItemsFrame();

    -- addon fully loaded!
    local hex = config:RGBToHex(config.database.theme2);
    config:Print(L["addon loaded!"]..' ('..string.format("|cff%s%s|r", hex, L["/tdl"]..' '..L["help"])..')');
    addonLoaded = true;
end