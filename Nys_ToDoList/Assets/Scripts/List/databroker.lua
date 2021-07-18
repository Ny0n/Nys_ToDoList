-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local utils = addonTable.utils
local enums = addonTable.enums
local database = addonTable.database
local mainFrame = addonTable.mainFrame
local databroker = addonTable.databroker
local optionsManager = addonTable.optionsManager

-- Variables
local L = core.L
local LDB = core.LDB
local LDBIcon = core.LDBIcon

--/***************/ TOOLTIPS /*****************/--

-- // SIMPLE

function databroker:DrawSimpleTooltip(tooltip)
  if not NysTDL.db.profile.minimap.tooltip then
    tooltip:Hide()
    return
  end

  if tooltip and tooltip.AddLine then
    -- we get the color theme
    local hex = utils:RGBToHex(database.themes.theme)

    -- then we create each line
    tooltip:ClearLines()
    tooltip:AddDoubleLine(core.toc.title, core.toc.version)
    tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", L["toggle the list"]))
    tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Shift-Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", L["toggle addon options"]))
    tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Ctrl-Click"])..' - '..string.format("|cff%s%s|r", "FFFFFF", NysTDL.db.profile.minimap.lock and L["unlock minimap button"] or L["lock minimap button"]))
    tooltip:Show()
  end
end

function databroker:SetSimpleMode()
  local o = self.object
  --table.wipe(o)

  local tooltipObject -- we get the tooltip frame on the first databroker:DrawSimpleTooltip call from OnTooltipShow
  o.type = "launcher"
  o.label = core.toc.title
  o.icon = "Interface\\AddOns\\"..addonName.."\\Assets\\Art\\minimap_icon"
  function o.OnClick()
    if IsControlKeyDown() then
      -- lock minimap button
      if (not NysTDL.db.profile.minimap.lock) then
        LDBIcon:Lock(addonName)
      else
        LDBIcon:Unlock(addonName)
      end
      databroker:DrawSimpleTooltip(tooltipObject) -- we redraw the tooltip to display the lock change
    elseif IsShiftKeyDown() then
      -- toggle addon options
      optionsManager:ToggleOptions()
    else
      -- toggle the list
      mainFrame:Toggle()
    end
  end
  function o.OnTooltipShow(tooltip)
    tooltipObject = tooltip
    databroker:DrawSimpleTooltip(tooltip)
  end
end

-- // ADVANCED

function databroker:DrawAdvancedTooltip(tooltip)
  if not NysTDL.db.profile.minimap.tooltip then -- TODO remove duplicates
    tooltip:Hide()
    return
  end

  if tooltip and tooltip.AddLine then
    -- we get the color theme
    local hex = utils:RGBToHex(database.themes.theme)

    -- then we create each line
    tooltip:ClearLines()
    tooltip:AddDoubleLine(core.toc.title, core.toc.version)
    tooltip:AddLine("ADVANCED TOOLTIP")
    tooltip:Show()
  end
end

function databroker:SetAdvancedMode()
  local o = self.object
  table.wipe(o)

  local tooltipObject -- we get the tooltip frame on the first databroker:DrawSimpleTooltip call from OnTooltipShow
  o.type = "launcher"
  o.label = core.toc.title.." ADVANCED"
  o.icon = "Interface\\AddOns\\"..addonName.."\\Assets\\Art\\minimap_icon"
  function o.OnClick()
    if IsControlKeyDown() then
      -- lock minimap button
      if (not NysTDL.db.profile.minimap.lock) then
        LDBIcon:Lock(addonName)
      else
        LDBIcon:Unlock(addonName)
      end
      databroker:DrawAdvancedTooltip(tooltipObject) -- we redraw the tooltip to display the lock change
    elseif IsShiftKeyDown() then
      -- toggle addon options
      optionsManager:ToggleOptions()
    else
      -- toggle the list
      mainFrame:Toggle()
    end
  end
  function o.OnTooltipShow(tooltip)
    tooltipObject = tooltip
    databroker:DrawAdvancedTooltip(tooltip)
  end
end


-- // FRAME

function databroker:CreateTooltipFrame()
  self.tooltipFrame = CreateFrame("Frame")
  self.tooltipFrame:Hide()
end

function databroker:SetFrameMode()
  local o = self.object
  table.wipe(o)

  o.type = "launcher"
  o.label = core.toc.title.." OLALA"
  o.icon = "Interface\\AddOns\\"..addonName.."\\Assets\\Art\\minimap_icon"
end

--/***************/ DATAOBJECT /*****************/--

function databroker:SetMode(mode)
  if mode == enums.databrokerModes.simple then
    self:SetSimpleMode()
  elseif mode == enums.databrokerModes.advanced then
    self:SetAdvancedMode()
  elseif mode == enums.databrokerModes.frame then
    self:SetFrameMode()
  end
  NysTDL.db.profile.databrokerMode = mode
end

function databroker:CreateDatabrokerObject()
  self.object = LDB:NewDataObject(addonName)
  self:SetMode(NysTDL.db.profile.databrokerMode)
end

-- minimap button

function databroker:CreateMinimapButton()
  -- Registering the data broker and creating the button
  LDBIcon:Register(addonName, self.object, NysTDL.db.profile.minimap)

  -- this is the secret to correctly update the button position, (since we can't update it in the init code)
  -- so that the first time that we click on it, it doesn't go somewhere else like so many do,
  -- we just delay its update :D (enough number of times to be sure, considering some ppl take longer times to load the UI)
  NysTDL.iconTimerCount = 0
  NysTDL.iconTimerCountMax = 7
  local delay = 1.2 -- in seconds

  -- so here, we are, each delay for max NysTDL.iconTimerCountMax seconds calling this function
  NysTDL.iconTimer = NysTDL:ScheduleRepeatingTimer(function()
    -- we really do this to call this function
    databroker:RefreshMinimapButton()

    -- and here we check and stop the timer when we're done
    NysTDL.iconTimerCount = NysTDL.iconTimerCount + 1
    if NysTDL.iconTimerCount == NysTDL.iconTimerCountMax then
      NysTDL:CancelTimer(NysTDL.iconTimer)
    end
  end, delay)
end

function databroker:RefreshMinimapButton()
  LDBIcon:Refresh(addonName, NysTDL.db.profile.minimap)
end
