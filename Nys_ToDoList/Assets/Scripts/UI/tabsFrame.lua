-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local dragndrop = addonTable.dragndrop
local mainFrame = addonTable.mainFrame
local tabsFrame = addonTable.tabsFrame
local dataManager = addonTable.dataManager

-- // Variables
local L = core.L
local private = {}

local currentID = 0
local currentState = false -- false == profile tabs, true == global tabs

local scrollFrame, content
local tabWidgets = {}
local dropdownBtn
local dropdownFrame

-- // WoW & Lua APIs

local PanelTemplates_GetTabWidth = PanelTemplates_GetTabWidth
local PanelTemplates_SetNumTabs = PanelTemplates_SetNumTabs
local PanelTemplates_SetTab = PanelTemplates_SetTab
local CreateFrame = CreateFrame

--[[
Basically, the way this works is at follows:

There is a parent -scrollFrame- (with a HORIZONTAL scrolling),
showing the -content- frame which itself holds each of the -tabWidgets- one after another.

On the right of the -scrollFrame-, there is a -dropdownBtn- that when clicked on,
toggles the -dropdownFrame- that shows each of the tabs that are not currently shown in the -scrollFrame-.
]]

--/*******************/ ANIMATION /*************************/--

local animFrame = CreateFrame("Frame", nil, UIParent) -- OnUpdate frame
local ANIM_SPEED = 10

function private:Event_AnimFrame_OnUpdate(elapsed)
	local totalDistanceNeeded = FCFDockScrollFrame_GetScrollDistanceNeeded(self, self.selectedDynIndex)
	if (abs(totalDistanceNeeded) < 1.0) then
    private:StopAnim(args)
    return
	end

	local currentPosition = self:GetHorizontalScroll()

	local distanceNoCap = totalDistanceNeeded * ANIM_SPEED * elapsed
	local distanceToMove = (totalDistanceNeeded > 0) and min(totalDistanceNeeded, distanceNoCap) or max(totalDistanceNeeded, distanceNoCap)

	self:SetHorizontalScroll(max(currentPosition + distanceToMove, 0))
end

function private:StartAnim(args)
  animFrame:SetScript("OnUpdate", private.Event_AnimFrame_OnUpdate)
end

function private:StopAnim(args)
  animFrame:SetScript("OnUpdate", nil)
  FCFDockScrollFrame_JumpToTab(self, FCFDockScrollFrame_GetLeftmostTab(self))
end

--/*******************/ MISC /*************************/--

function private:ChatFrame_TruncateToMaxLength(text, maxLength)
	local length = strlenutf8(text)
	if (length > maxLength) then
		return text:sub(1, maxLength - 2).."..."
	end

	return text
end

function private:RefreshPoints()
  -- updates the pos of each tab widget, depending on their order
  local tabsList = select(3, dataManager:GetData(currentState))

  local lastWidget
  for pos,tabID in ipairs(tabsList.orderedTabIDs) do
    if tabWidgets[tabID] then
      if not lastWidget then
        tabWidgets[tabID]:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
      else
        tabWidgets[tabID]:SetPoint("TOPLEFT", lastWidget, "TOPRIGHT", -12, 0)
      end
      lastWidget = tabWidgets[tabID]
    end
  end
end

--/*******************/ WIDGETS /*************************/--
-- this is a bit more specific to this file, so i'm putting the widgets here instead of the widgets file

function private:TabWidget(tabID, parentFrame)
  local tabData = select(3, dataManager:Find(tabID))

  currentID = currentID + 1
  local parentName = parentFrame:GetName()
  local tabWidget = CreateFrame("Button", parentName.."Tab"..currentID, parentFrame, "CharacterFrameTabButtonTemplate")

  -- // data

  tabWidget.tabID = tabID
  tabWidget.tabData = tabData

  -- // UI & actions

  tabWidget:SetID(currentID)
  tabWidget:SetText(tabData.name)
  -- tabWidget:SetWidth(widgets:GetWidth(tabData.name)) -- TODO redo
  tabWidget:SetScript("OnClick", function(self)
    mainFrame:ChangeTab(self.tabID)
    tabsFrame:Refresh()
  end)

  return tabWidget
end

--/*******************/ GENERAL /*************************/--

function tabsFrame:SetScale(scale)
  for tabID,tabWidget in pairs(tabWidgets) do
    PanelTemplates_TabResize(tabWidget, 0, math.max(widgets:GetWidth(tabWidget.tabData.name)+10, 80))
  end
  local width = scale*enums.tdlFrameDefaultWidth
  print(width)
  PanelTemplates_ResizeTabsToFit(content, width*1.5)
end

function tabsFrame:UpdateTab(tabID)
  -- updates (create/update) the given tab's associated button

  if tabWidgets[tabID] then
    tabWidgets[tabID]:ClearAllPoints()
    tabWidgets[tabID]:Hide()
  end

  tabWidgets[tabID] = private:TabWidget(tabID, content)
  private:RefreshPoints() -- and refresh the pos
end

function tabsFrame:DeleteTab(tabID)
  if tabWidgets[tabID] then
    tabWidgets[tabID]:ClearAllPoints()
    tabWidgets[tabID]:Hide()
    tabWidgets[tabID] = nil
  end

  --TDLATER maybe refresh here? (and same in other funcs)
end

function tabsFrame:Refresh()
  -- // we update the visuals of the buttons

  -- we update the nb of tabs so that wow's API works
  PanelTemplates_SetNumTabs(content, currentID) -- (yea we're lying a bit, but it doesn't matter :D)

  -- we select the currently selected tab's button
  local currentTabID = database.ctab()
  for tabID,tabWidget in pairs(tabWidgets) do
    if currentTabID == tabID then
      print("------------------")
      print(tabWidget:GetParent():GetName())
      print(tabWidget:GetName())
      print(tabWidget:GetID())
      print(type(tabWidget:GetID()))
      print(tabWidget.tabData.name)
      PanelTemplates_SetTab(tabWidget:GetParent(), tabWidget:GetID())
      break
    end
  end

  -- and refresh the pos
  private:RefreshPoints()
end

--/*******************/ INITIALIZATION /*************************/--

function tabsFrame:CreateFrame(tdlFrame)
  -- // scrollFrame
  scrollFrame = CreateFrame("ScrollFrame", nil, tdlFrame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", tdlFrame, "BOTTOMLEFT", 0, 2)
  scrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", 0, -40)
  scrollFrame:SetClipsChildren(true)
  -- scrollFrame:SetScript("OnMouseWheel", mainFrame.Event_ScrollFrame_OnMouseWheel)
  scrollFrame.ScrollBar:Hide()
  scrollFrame.ScrollBar:ClearAllPoints()

  -- // content
  content = CreateFrame("Frame", "NysTDL_tabsFrame_content", scrollFrame)
  content:SetSize(1, 1) -- just to show everything inside of it
  scrollFrame:SetScrollChild(content)

  -- // init
  tabsFrame:Init()
end

function tabsFrame:Init()
  -- // tab widgets
  wipe(tabWidgets)
  for tabID,tabData in dataManager:ForEach(enums.tab, false) do -- TDLATER global too
    tabsFrame:UpdateTab(tabID)
  end

  -- refresh
  tabsFrame:Refresh()
end
