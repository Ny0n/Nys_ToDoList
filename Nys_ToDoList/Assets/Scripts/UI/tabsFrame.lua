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

-- UI pos control
local inBetweenTabOffset = -12
local overflowButtonRightOffsetX = -9
local overflowButtonSize = 29
local listButtonWidgetHeight = 12
local leftScrollFrameOffset = 7
local rightScrollFrameOffset = -6
local MIN_TAB_SIZE, MAX_TAB_SIZE = 70, 90

local _currentID = 0
local _currentState = false -- false == profile tabs, true == global tabs
local _nbWholeTabsShown = 0

local scrollFrame, content, overflowButtonFrame, overflowList
local tabWidgets, listButtonWidgets = {}, {}
local dropdownBtn
local dropdownFrame
local overflowButtonWidth = -overflowButtonRightOffsetX + overflowButtonSize - 3
local lastLeftTab

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

function private:GetLeftMostTab()
	-- to know where we are in the scrollFrame
	-- returns the tabID of the found tab
	local scrollFrameLeft = scrollFrame:GetLeft()
	print("scrollFrameLeft", scrollFrameLeft)
	print("scrollFrameScroll", scrollFrame:GetHorizontalScroll())
	local tabsList = select(3, dataManager:GetData(_currentState))
  for _,tabID in ipairs(tabsList.orderedTabIDs) do -- in order, we check which is the first to be ENTIRELY (whole tab) on the right of the scrollFrame's left
    if tabWidgets[tabID] then
			-- print("tabWidgets[tabID]:GetLeft()", string.format("%.f", tabWidgets[tabID]:GetLeft()), select(3, dataManager:Find(tabID)).name)
			if tabWidgets[tabID]:GetLeft()+15 > scrollFrameLeft then
				-- print("LEFT_MOST_TAB", select(3, dataManager:Find(tabID)).name)
				return tabID
			end
    end
	end
	return select(2, next(tabsList.orderedTabIDs)) -- by default, if there are no tabs (specific cases), we return litterally the first tab
end

function private:GetShownWholeTabs()
	-- returns a table containing, in order, the tabID of the found whole tabs
	-- i'm betting on the fact that tabs are sorted, so i only need to know so much
	if _nbWholeTabsShown <= 0 then return {} end

	local shownTabs = {}

	local leftTab = private:GetLeftMostTab()
	local loc, pos = dataManager:GetPosData(leftTab)

	table.insert(shownTabs, leftTab)
	for i=1,_nbWholeTabsShown-1 do
		table.insert(shownTabs, loc[pos+i])
	end

	print("===================")
	for k,v in pairs(shownTabs) do
		print(select(3, dataManager:Find(v)).name)
	end
	print("<===================>")

	return shownTabs
end

function private:ScrollToTab(tabID)
	-- TDLATER animation
end

function private:SnapToTab(tabID)
	print("----> SnapToTab", select(3, dataManager:Find(tabID)).name)
	-- snaps the horizontal scroll to the left of the given tab
	if not tabWidgets[tabID] then return false end

	scrollFrame:SetHorizontalScroll(0)
	local diff = (tabWidgets[tabID]:GetLeft()+leftScrollFrameOffset) - scrollFrame:GetLeft()
	scrollFrame:SetHorizontalScroll(math.max(diff, 0))
end

function private:IncludeTab(tabID)
	print("-----IncludeTab-----")
	-- snaps the horizontal scroll to INCLUDE the given tab button,
	-- the difference with SnapToTab is that this one will snap to the RIGHT of the given tab,
	-- if it is after the current selection, will do nothing if the tab is already in the current selection, and snap to the left if it is before
	if not tabWidgets[tabID] then return false end
	if utils:HasValue(private:GetShownWholeTabs(), tabID) then -- if it's already shown, we have nothing to do
		return true
	end

	local firstPos = dataManager:GetPosData(private:GetLeftMostTab(), nil, true)
	local targetPos = dataManager:GetPosData(tabID, nil, true)

	local diff
	if targetPos < firstPos then -- if the tab is before the first shown one
		diff = (tabWidgets[tabID]:GetLeft() + leftScrollFrameOffset) - scrollFrame:GetLeft() -- negative (go left)
	else -- if the tab is after the last one (bc it's not before the first one, and it's not currently shown)
		diff = (tabWidgets[tabID]:GetRight() + rightScrollFrameOffset) - scrollFrame:GetRight() -- positive (go right)
	end
	scrollFrame:SetHorizontalScroll(math.max(scrollFrame:GetHorizontalScroll() + diff, 0))
end

function private:CalculateTabSize()
	-- reused from wow's chat function (FCFDock_CalculateTabSize) for my purpose
	-- returns tabSize, hasOverflow

	local scrollSize = scrollFrame:GetParent():GetWidth() -- the default scroll size we're considering to use is the width of the tdlFrame (without considering the overflowButtonFrame)
	local tabsList = select(3, dataManager:GetData(_currentState))
	local numTabs = #tabsList.orderedTabIDs

	-- first, we see if we can fit all the tabs at the maximum size
	if numTabs*MAX_TAB_SIZE < scrollSize then
		return MAX_TAB_SIZE, false, numTabs
	end

	if scrollSize/MIN_TAB_SIZE < numTabs then
		-- not everything fits, so we'll need room for the overflow button
		scrollSize = scrollSize - overflowButtonWidth
	end
	if scrollSize == 0 then
		return 1, numTabs > 0, 0
	end

	-- figure out how many tabs we're going to be able to fit at the minimum size
	local numWholeTabs = min(floor(scrollSize/MIN_TAB_SIZE), numTabs)
	if numWholeTabs == 0 then
		return scrollSize, true, numWholeTabs
	end

	-- how big each tab should be
	local tabSize = scrollSize/numWholeTabs
	return tabSize, (numTabs > numWholeTabs), numWholeTabs
end

function private:RefreshSize()
	print("-----RefreshSize-----")
  -- updates the size of each tab widget depending on the list's width,
	-- also shows the overflow button if needed

	local tabSize, hasOverflow, numWholeTabs = private:CalculateTabSize()
	local leftTab = private:GetLeftMostTab()
	local tabToSnapTo = leftTab

	if numWholeTabs > _nbWholeTabsShown then
		local loc, pos = dataManager:GetPosData(leftTab)

		-- if there is enough tabs to the right, we don't change our left tab,
		-- if there are NOT enough tabs to the right, we go find more tabs left
		if not loc[pos+numWholeTabs-1] then -- if there is no more tabs to the right,
			tabToSnapTo = loc[math.max(#loc-numWholeTabs+1, 1)] -- we start from the right, and take enough tabs
		end
	end

	local tabsList = select(3, dataManager:GetData(_currentState))
	local bonus = ((numWholeTabs > 0) and (((numWholeTabs-1)*(-inBetweenTabOffset))/numWholeTabs) or 0) -- to counteract the tab offset
	for _,tabID in ipairs(tabsList.orderedTabIDs) do
    if tabWidgets[tabID] then
			PanelTemplates_TabResize(tabWidgets[tabID], 0, tabSize+bonus)
    end
  end

	private:SnapToTab(tabToSnapTo)
	_nbWholeTabsShown = numWholeTabs

	scrollFrame:ClearAllPoints()
	local tdlFrame = mainFrame:GetFrame()
	if hasOverflow then
		overflowButtonFrame:SetShown(true)
	  scrollFrame:SetPoint("TOPLEFT", tdlFrame, "BOTTOMLEFT", leftScrollFrameOffset, 2)
	  scrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", -overflowButtonWidth+rightScrollFrameOffset, -40)
	else
		overflowButtonFrame:SetShown(false)
	  scrollFrame:SetPoint("TOPLEFT", tdlFrame, "BOTTOMLEFT", leftScrollFrameOffset, 2)
	  scrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", 0, -40)
	end
end

function private:RefreshPoints()
  -- updates the pos of each tab widget, depending on their order
  local tabsList = select(3, dataManager:GetData(_currentState))

  local lastWidget
  for pos,tabID in ipairs(tabsList.orderedTabIDs) do
    if tabWidgets[tabID] then
      if not lastWidget then
        tabWidgets[tabID]:SetPoint("TOPLEFT", content, "TOPLEFT", -leftScrollFrameOffset, 1)
      else
        tabWidgets[tabID]:SetPoint("TOPLEFT", lastWidget, "TOPRIGHT", inBetweenTabOffset, 0)
      end
      lastWidget = tabWidgets[tabID]
    end
  end
end

function private:RefreshOverflowList()
  -- updates the pos of each ListButtonWidget, which ones are shown, and adapts the height of the overflowList
	for _,listButton in pairs(listButtonWidgets) do
		listButton:ClearAllPoints()
		listButton:Hide()
		listButton.ArrowLEFT:Hide()
		listButton.ArrowRIGHT:Hide()
	end

	local tabsList = select(3, dataManager:GetData(_currentState))
  local lastWidget, rightSide
	local shownTabs = private:GetShownWholeTabs()
  for _,tabID in ipairs(tabsList.orderedTabIDs) do
    if listButtonWidgets[tabID] then
			if utils:HasValue(shownTabs, tabID) then
				rightSide = true
			else -- !! if the tab is not already shown as a button under the list
				if not lastWidget then
					listButtonWidgets[tabID]:SetPoint("TOP", overflowList.title, "BOTTOM", 0, -5)
	      else
	        listButtonWidgets[tabID]:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
	      end
				listButtonWidgets[tabID]:Show()
				if rightSide then
					listButtonWidgets[tabID].ArrowRIGHT:Show()
				else
					listButtonWidgets[tabID].ArrowLEFT:Show()
				end
	      lastWidget = listButtonWidgets[tabID]
			end
    end
	end

	if not lastWidget then lastWidget = overflowList.title end
	local top, bottom = overflowList:GetTop(), lastWidget:GetBottom()-8
	overflowList:SetHeight(top-bottom)
end

--/*******************/ WIDGETS /*************************/--
-- this is a bit more specific to this file, so i'm putting the widgets here instead of the widgets file

function private:TabWidget(tabID, parentFrame)
  local tabData = select(3, dataManager:Find(tabID))

  _currentID = _currentID + 1
  local parentName = parentFrame:GetName()
  local tabWidget = CreateFrame("Button", parentName.."Tab".._currentID, parentFrame, "CharacterFrameTabButtonTemplate")

  -- // data

  tabWidget.tabID = tabID
  tabWidget.tabData = tabData

  -- // UI & actions

  tabWidget:SetID(_currentID)
  tabWidget:SetText(tabData.name)
  tabWidget:SetScript("OnClick", function(self)
    mainFrame:ChangeTab(self.tabID)
    tabsFrame:Refresh()
  end)

  return tabWidget
end

function private:ListButtonWidget(tabID, parentFrame)
	local tabData = select(3, dataManager:Find(tabID))

	local listButtonWidget = CreateFrame("Button", nil, parentFrame, "NysTDL_OverflowListButton")

	-- // data

	listButtonWidget.tabID = tabID
	listButtonWidget.tabData = tabData

	-- // UI & actions

	listButtonWidget:SetText(tabData.name)
	listButtonWidget:SetSize(parentFrame:GetWidth()-12, listButtonWidgetHeight)
	listButtonWidget:SetScript("OnClick", function(self)
		tabWidgets[self.tabID]:Click()
		private:IncludeTab(self.tabID) -- TDLATER redo for anim
		private:RefreshOverflowList()
	end)

	return listButtonWidget
end

--/*******************/ GENERAL /*************************/--

function tabsFrame:Get()
	private:GetLeftMostTab()
end
function tabsFrame:Set()
	private:GetShownWholeTabs()
end

function tabsFrame:GLOBAL_MOUSE_DOWN()
	-- to replicate the behavior of the GameTooltip
	if not overflowList:IsMouseOver() and not overflowButtonFrame:IsMouseOver() then
		overflowList:Hide()
	end
end

function tabsFrame:SetScale(scale)
	-- we don't actually need the scale, the width of the scrollFrame is enough
	-- and it's automatically updated with the width from the tdlFrame
  tabsFrame:Refresh()
end

function tabsFrame:UpdateTab(tabID)
  -- updates (create/update) the given tab's associated button

  if tabWidgets[tabID] then
    tabWidgets[tabID]:ClearAllPoints()
    tabWidgets[tabID]:Hide()
  end
  if listButtonWidgets[tabID] then
    listButtonWidgets[tabID]:ClearAllPoints()
    listButtonWidgets[tabID]:Hide()
  end

  tabWidgets[tabID] = private:TabWidget(tabID, content)
  listButtonWidgets[tabID] = private:ListButtonWidget(tabID, overflowList)
  private:RefreshPoints() -- and refresh the pos
end

function tabsFrame:DeleteTab(tabID)
  if tabWidgets[tabID] then
    tabWidgets[tabID]:ClearAllPoints()
    tabWidgets[tabID]:Hide()
    tabWidgets[tabID] = nil
  end

	if listButtonWidgets[tabID] then
		listButtonWidgets[tabID]:ClearAllPoints()
    listButtonWidgets[tabID]:Hide()
    listButtonWidgets[tabID] = nil
  end

  --TDLATER maybe refresh here? (and same in other funcs)
end

function tabsFrame:Refresh()
	print("=====REFRESH=====")
  -- // we update the visuals of the buttons

  -- we update the nb of tabs so that wow's API works
  PanelTemplates_SetNumTabs(content, _currentID) -- (yea we're lying a bit, but it doesn't matter :D)

  -- we select the currently selected tab's button
  local currentTabID = database.ctab()
  for tabID,tabWidget in pairs(tabWidgets) do
    if currentTabID == tabID then
      PanelTemplates_SetTab(tabWidget:GetParent(), tabWidget:GetID())
      break
    end
  end

  -- refresh the pos
  private:RefreshPoints()

  -- refresh the size
  private:RefreshSize()

	-- and we always focus ourserves on the currently selected tab
	private:IncludeTab(database.ctab())
end

--/*******************/ INITIALIZATION /*************************/--

function tabsFrame:CreateFrame(tdlFrame)
  -- // scrollFrame
  scrollFrame = CreateFrame("ScrollFrame", nil, tdlFrame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", tdlFrame, "BOTTOMLEFT", leftScrollFrameOffset, 2)
  scrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", 0, -40)
  scrollFrame:SetClipsChildren(true)
  scrollFrame.ScrollBar:Hide()
  scrollFrame.ScrollBar:ClearAllPoints()
	scrollFrame:SetScript("OnShow", function()
		private:SnapToTab(lastLeftTab or private:GetLeftMostTab())
		tabsFrame:Refresh()
	end)
	scrollFrame:SetScript("OnHide", function()
		lastLeftTab = private:GetLeftMostTab()
	end)

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

	overflowList = CreateFrame("Frame", nil, tdlFrame, "BackdropTemplate")
	overflowList:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 1, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
	overflowList:SetBackdropColor(0, 0, 0, 1)
  overflowList:SetBackdropBorderColor(1, 1, 1, 0.5) -- TODO REDO ALPHA FOR ALL
	overflowList:SetPoint("TOPRIGHT", overflowButtonFrame, "BOTTOMRIGHT", 0, -5)
	overflowList:SetSize(150, 1) -- the height is updated dynamically
	overflowList:Hide()

	overflowList.title = overflowList:CreateFontString(nil)
	overflowList.title:SetPoint("TOP", overflowList, "TOP", 0, -5)
	overflowList.title:SetFontObject("GameFontHighlight")
	overflowList.title:SetText("Other Tabs")

	overflowButtonFrame.btn:SetScript("OnClick", function()
		if not overflowList:IsShown() then -- if we're about to show the list, we refresh it
			private:RefreshOverflowList()
		end

		overflowList:SetShown(not overflowList:IsShown()) -- toggles the overflowList
	end)
end

function tabsFrame:Init()
  -- // widgets
	-- we delete and hide each widget
  for tabID in pairs(tabWidgets) do
    tabsFrame:DeleteTab(tabID)
  end
  wipe(tabWidgets)
  wipe(listButtonWidgets)

	-- before (re)creating them
  for tabID,tabData in dataManager:ForEach(enums.tab, false) do -- TDLATER global too
    tabsFrame:UpdateTab(tabID)
  end

  -- refresh
  tabsFrame:Refresh()
end
