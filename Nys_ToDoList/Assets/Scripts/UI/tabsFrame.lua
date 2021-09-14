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

local inBetweenTabOffset = -12
local overflowButtonRightOffsetX = -9
local overflowButtonSize = 29
local MIN_TAB_SIZE, MAX_TAB_SIZE = 70, 90

local currentID = 0
local currentState = false -- false == profile tabs, true == global tabs
local nbWholeTabsShown

local scrollFrame, content, overflowButtonFrame
local tabWidgets = {}
local dropdownBtn
local dropdownFrame
local overflowButtonWidth = -overflowButtonRightOffsetX + overflowButtonSize - 3

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

function private:CalculateTabSize()
	-- reused from wow's chat function (FCFDock_CalculateTabSize) for my purpose
	-- returns tabSize, hasOverflow

	local scrollSize = scrollFrame:GetParent():GetWidth() -- the default scroll size we're considering to use is the width of the tdlFrame (without considering the overflowButtonFrame)
	local numTabs = currentID -- currentID is constantly updated
	print("numTabs", numTabs)
	nbWholeTabsShown = 0

	-- first, we see if we can fit all the tabs at the maximum size
	if numTabs*MAX_TAB_SIZE < scrollSize then
		print("__RETURN", 1)
		nbWholeTabsShown = numTabs
		return MAX_TAB_SIZE, false
	end

	if scrollSize/MIN_TAB_SIZE < numTabs then
		-- not everything fits, so we'll need room for the overflow button
			print("__CHANGE")
		scrollSize = scrollSize - overflowButtonWidth
	end
	if scrollSize == 0 then
		print("__RETURN", "1_bis")
		return 1, numTabs > 0
	end

	-- figure out how many tabs we're going to be able to fit at the minimum size
	local numWholeTabs = min(floor(scrollSize/MIN_TAB_SIZE), numTabs)
	if numWholeTabs == 0 then
		print("__RETURN", 2)
		return scrollSize, true
	end

	nbWholeTabsShown = numWholeTabs
	print("numWholeTabs", numWholeTabs)
	-- how big each tab should be
	local tabSize = scrollSize/numWholeTabs
	print("__RETURN", 3)
	return tabSize, (numTabs > numWholeTabs)
end

function private:RefreshSize()
  -- updates the size of each tab widget depending on the list's width,
	-- also shows the overflow button if needed
  local tabsList = select(3, dataManager:GetData(currentState))

	local tabSize, hasOverflow = private:CalculateTabSize()
	print(tabSize, hasOverflow)
	local bonus = ((nbWholeTabsShown > 0) and (((nbWholeTabsShown-1)*(-inBetweenTabOffset))/nbWholeTabsShown) or 0) -- to counteract the tab offset
	print("bonus", bonus)
	for pos,tabID in ipairs(tabsList.orderedTabIDs) do
    if tabWidgets[tabID] then
			PanelTemplates_TabResize(tabWidgets[tabID], 0, tabSize+bonus)
    end
  end

	scrollFrame:ClearAllPoints()
	local tdlFrame = mainFrame:GetFrame()
	if hasOverflow then
		overflowButtonFrame:SetShown(true)
	  scrollFrame:SetPoint("TOPLEFT", tdlFrame, "BOTTOMLEFT", 0, 2)
	  scrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", -overflowButtonWidth-6, -40)
	else
		overflowButtonFrame:SetShown(false)
	  scrollFrame:SetPoint("TOPLEFT", tdlFrame, "BOTTOMLEFT", 0, 2)
	  scrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", 0, -40)
	end
end

function private:RefreshPoints()
  -- updates the pos of each tab widget, depending on their order
  local tabsList = select(3, dataManager:GetData(currentState))

  local lastWidget
  for pos,tabID in ipairs(tabsList.orderedTabIDs) do
    if tabWidgets[tabID] then
      if not lastWidget then
        tabWidgets[tabID]:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 1)
      else
        tabWidgets[tabID]:SetPoint("TOPLEFT", lastWidget, "TOPRIGHT", inBetweenTabOffset, 0)
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
	-- we don't actually need the scale, the width of the scrollFrame is enough
	-- and it's automatically updated with the width from the tdlFrame
  tabsFrame:Refresh()
	print("xxx--->>> SetScale")
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
	print("TABSFRAME REFRESH")
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

  -- refresh the pos
  private:RefreshPoints()

  -- refresh the size
  private:RefreshSize()
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

	-- // overflowButton / overflowButtonFrame
	 -- !! both overflowButtonFrame and overflowButtonFrame.backdrop are there only to beautify the button,
	 -- by creating a better backdrop and masking of the border
	overflowButtonFrame = CreateFrame("Frame", nil, tdlFrame, nil)
	overflowButtonFrame:SetPoint("TOPRIGHT", tdlFrame, "BOTTOMRIGHT", overflowButtonRightOffsetX, 2)
  overflowButtonFrame:SetSize(overflowButtonSize, overflowButtonSize)
  overflowButtonFrame:SetFrameStrata("LOW")
	overflowButtonFrame:SetClipsChildren(true)

	overflowButtonFrame.backdrop = CreateFrame("Frame", nil, overflowButtonFrame, "BackdropTemplate")
	overflowButtonFrame.backdrop:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 1, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
	overflowButtonFrame.backdrop:SetBackdropColor(0, 0, 0, 1)
  overflowButtonFrame.backdrop:SetBackdropBorderColor(1, 1, 1, 0.5)
	overflowButtonFrame.backdrop:SetPoint("TOPLEFT", overflowButtonFrame, "TOPLEFT", 0, 4)
  overflowButtonFrame.backdrop:SetSize(overflowButtonFrame:GetWidth(), overflowButtonFrame:GetHeight()+2)
	overflowButtonFrame.backdrop:SetClipsChildren(true)

	overflowButtonFrame.btn = CreateFrame("Button", nil, overflowButtonFrame.backdrop, "NysTDL_OverflowButton")
  overflowButtonFrame.btn:SetPoint("CENTER", overflowButtonFrame.backdrop, "CENTER", 0, 0)
	local btnIconScale = 0.65 -- value between 0 and 1
  overflowButtonFrame.btn:SetSize(overflowButtonFrame:GetWidth()*btnIconScale, (overflowButtonFrame:GetHeight()*btnIconScale)/2)
	local inset = -overflowButtonFrame:GetWidth()*(1-btnIconScale)
  overflowButtonFrame.btn:SetHitRectInsets(inset, inset, inset, inset)
	overflowButtonFrame.btn.Highlight:SetPoint("TOPLEFT", overflowButtonFrame.backdrop, "TOPLEFT", 2, -4)
	overflowButtonFrame.btn.Highlight:SetPoint("BOTTOMRIGHT", overflowButtonFrame.backdrop, "BOTTOMRIGHT", -2, 2)
	overflowButtonFrame.btn:SetScript("OnMouseDown", function(self)
		self:ClearAllPoints()
		self:SetPoint("CENTER", self:GetParent(), "CENTER", 1, -2)
	end)
	overflowButtonFrame.btn:SetScript("OnMouseUp", function(self)
		self:ClearAllPoints()
		self:SetPoint("CENTER", self:GetParent(), "CENTER", 0, 0)
	end)
	overflowButtonFrame.btn:SetScript("OnClick", function(self)
		print("--> OnClick overflowButtonFrame.btn")
	end)
end

function tabsFrame:Init()
  -- // tab widgets
	-- we delete and hide each widget
  for tabID in pairs(tabWidgets) do
    tabsFrame:DeleteTab(tabID)
  end
  wipe(tabWidgets)

	-- before (re)creating them
  for tabID,tabData in dataManager:ForEach(enums.tab, false) do -- TDLATER global too
    tabsFrame:UpdateTab(tabID)
  end

  -- refresh
  tabsFrame:Refresh()
end
