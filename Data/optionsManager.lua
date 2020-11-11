-- Namespaces
local addonName, tdlTable = ...;

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;

-- Variables

local L = config.L;
local LDB = config.LDB;
local LDBIcon = config.LDBIcon;

-- we need to put all of this in a file that loads just before the init so they have acces to every function in every other file of the addon

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

function NysTDL:Warn()
  if (not itemsFrame:autoResetedThisSessionGET()) then -- we don't want to show this warning if it's the first log in of the day, only if it is the next ones
    if (NysTDL.db.profile.showWarnings) then
      local haveWarned = false
      local warn = "--------------| |cffff0000"..L["WARNING"].."|r |--------------"

      if (NysTDL.db.profile.favoritesWarning) then -- and the user allowed this functionnality
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
            local hex = config:RGBToHex({ NysTDL.db.profile.favoritesColor[1]*255, NysTDL.db.profile.favoritesColor[2]*255, NysTDL.db.profile.favoritesColor[3]*255} )
            str = string.format("|cff%s%s|r", hex, str)
            if (not haveWarned) then config:PrintForced(warn) haveWarned = true end
            config:PrintForced(L["You still have %s favorite item(s) to do before the next reset, don't forget them!"]:format(str))
          end
        end
      end

      if (NysTDL.db.profile.normalWarning) then
        local _, daily, weekly = itemsFrame:updateRemainingNumber()
        if ((daily + weekly) > 0) then -- and there is at least one daily or weekly item left to do (favorite or not)
          local total = 0

          -- we first check if there are daily ones
          if (daily > 0) then
            if ((NysTDL.db.profile.autoReset["Daily"] - time()) < 86400) then -- pretty much all the time
              total = total + daily
            end
          end

          -- then we check if there are weekly ones
          if (weekly > 0) then
            if ((NysTDL.db.profile.autoReset["Weekly"] - time()) < 86400) then -- if there is less than one day left before the weekly reset
              total = total + weekly
            end
          end

          if (total ~= 0) then
            if (not haveWarned) then config:PrintForced(warn) haveWarned = true end
            config:PrintForced(L["Total number of items left to do before tomorrow:"]..' '..tostring(total))
          end
        end
      end

      if (haveWarned) then
        local timeUntil = config:GetTimeUntilReset()
        local str2 = L["Time remaining: %i hours %i min"]:format(timeUntil.hour, timeUntil.min + 1)
        config:PrintForced(str2)
      end
    end
  end
end

function NysTDL:CreateTDLButton()
  -- Creating the big button to easily toggle the frame
  itemsFrame.tdlButton = config:CreateButton("tdlButton", UIParent, string.gsub(config.toc.title, "Ny's ", ""));
  itemsFrame.tdlButton:SetFrameLevel(100);
  itemsFrame.tdlButton:SetMovable(true);
  itemsFrame.tdlButton:EnableMouse(true);
  itemsFrame.tdlButton:SetClampedToScreen(true);
  itemsFrame.tdlButton:RegisterForDrag("LeftButton");
  itemsFrame.tdlButton:SetScript("OnDragStart", itemsFrame.tdlButton.StartMoving);
  itemsFrame.tdlButton:SetScript("OnDragStop", function() -- we save its position
    itemsFrame.tdlButton:StopMovingOrSizing()
    local points = self.db.profile.tdlButton.points
    points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset = itemsFrame.tdlButton:GetPoint()
  end);
  itemsFrame.tdlButton:SetScript("OnClick", itemsFrame.Toggle); -- the function the button calls when pressed
  NysTDL:RefreshTDLButton();
end

function NysTDL:RefreshTDLButton()
  local points = self.db.profile.tdlButton.points;
  itemsFrame.tdlButton:ClearAllPoints();
  itemsFrame.tdlButton:SetPoint(points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset);
  itemsFrame.tdlButton:SetShown(self.db.profile.tdlButton.show);
end

local function draw_tooltip(tooltip)
  if (not NysTDL.db.profile.minimap.tooltip) then
    tooltip:Hide();
    return;
  end

  if tooltip and tooltip.AddLine then
      -- we get the color theme
      local hex = config:RGBToHex(config.database.theme)

      -- then we create each line
      tooltip:ClearLines();
      tooltip:AddDoubleLine(config.toc.title, config.toc.version);
      tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", L["toggle the list"]))
      tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Shift-Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", L["toggle addon options"]))
      tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Ctrl-Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", NysTDL.db.profile.minimap.lock and L["unlock minimap button"] or L["lock minimap button"]))
      tooltip:Show()
  end
end

function NysTDL:CreateMinimapButton()
  -- creating the data object to store the button infos

  local tooltipObject; -- we get the tooltip on the first draw_tooltip call from OnTooltipShow

  local LDB_o_minimap = LDB:NewDataObject(addonName, {
    type = "launcher",
    label = config.toc.title,
    icon = "Interface\\AddOns\\"..addonName.."\\Data\\Textures\\minimap_icon",
    OnClick = function()
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
  -- oulala
end

function NysTDL:ProfileChanged()
  NysTDL:DBInit(); -- in case the selected profile is empty

  -- we update the changes for the list
  itemsFrame:ResetContent();
  itemsFrame:Init();

  -- we update the changes to the options (since I now use tabs and the options are not instantly getting a refresh when changing profiles)
  NysTDL:CallAllGETTERS();
end

--/*******************/ GETTERS/SETTERS /*************************/--

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

function NysTDL:InitializeOptionsWidthRecursive(table, wDef)
  for _,v in pairs(table) do
    if (v.type == "group") then
      NysTDL:InitializeOptionsWidthRecursive(v.args, wDef)
    elseif (v.type ~= "description" and v.type ~= "header") then -- for every widget (except the descriptions and the headers), we keep their min normal width, we change it only if their name is bigger than the default width
      local w = config:CreateNoPointsLabel(UIParent, nil, v.name):GetWidth();
      -- print (v.name.."_"..w)
      w = tonumber(string.format("%.3f", w/wDef[v.type]));
      if (w > 1) then
        v.width = w;
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

--showWarnings
function NysTDL:showWarningsGET(info)
  NysTDL:showWarningsSET(info, NysTDL.db.profile.showWarnings)
  return NysTDL.db.profile.showWarnings;
end

function NysTDL:showWarningsSET(info, newValue)
  NysTDL.db.profile.showWarnings = newValue;
end

--favoritesWarning
function NysTDL:favoritesWarningGET(info)
  NysTDL:favoritesWarningSET(info, NysTDL.db.profile.favoritesWarning)
  return NysTDL.db.profile.favoritesWarning;
end

function NysTDL:favoritesWarningSET(info, newValue)
  NysTDL.db.profile.favoritesWarning = newValue;
end

--normalWarning
function NysTDL:normalWarningGET(info)
  NysTDL:normalWarningSET(info, NysTDL.db.profile.normalWarning)
  return NysTDL.db.profile.normalWarning;
end

function NysTDL:normalWarningSET(info, newValue)
  NysTDL.db.profile.normalWarning = newValue;
end

--hourlyReminder
function NysTDL:hourlyReminderGET(info)
  NysTDL:hourlyReminderSET(info, NysTDL.db.profile.hourlyReminder)
  return NysTDL.db.profile.hourlyReminder;
end

function NysTDL:hourlyReminderSET(info, newValue)
  NysTDL.db.profile.hourlyReminder = newValue;
end

--favoritesColor
function NysTDL:favoritesColorGET(info)
  NysTDL:favoritesColorSET(info, unpack(NysTDL.db.profile.favoritesColor))
  return unpack(NysTDL.db.profile.favoritesColor);
end

function NysTDL:favoritesColorSET(info, ...)
  NysTDL.db.profile.favoritesColor = { select(1, ...), select(2, ...), select(3, ...), select(4, ...) };
  itemsFrame:updateCheckButtonsColor()
  itemsFrame:updateRemainingNumber()
end

--rainbow
function NysTDL:rainbowGET(info)
  NysTDL:rainbowSET(info, NysTDL.db.profile.rainbow);
  return NysTDL.db.profile.rainbow;
end

function NysTDL:rainbowSET(info, newValue)
  NysTDL.db.profile.rainbow = newValue;
end

--rainbowSpeed
function NysTDL:rainbowSpeedGET(info)
  NysTDL:rainbowSpeedSET(info, NysTDL.db.profile.rainbowSpeed);
  return NysTDL.db.profile.rainbowSpeed;
end

function NysTDL:rainbowSpeedSET(info, newValue)
  NysTDL.db.profile.rainbowSpeed = newValue;
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

-- tdlButtonRed
function NysTDL:tdlButtonRedGET(info)
  NysTDL:tdlButtonRedSET(info, NysTDL.db.profile.tdlButton.red)
  return NysTDL.db.profile.tdlButton.red;
end

function NysTDL:tdlButtonRedSET(info, newValue)
  if (NysTDL.db.profile.tdlButton.red and not newValue) then
    itemsFrame.tdlButton:SetNormalFontObject("GameFontNormalLarge");
  end
  NysTDL.db.profile.tdlButton.red = newValue;
  if (NysTDL.db.profile.tdlButton.red) then
    itemsFrame:updateRemainingNumber() -- we check if we need to color the button instantly in case the set was true
  end
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
