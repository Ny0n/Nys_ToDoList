-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local dragndrop = addonTable.dragndrop
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- // Variables

local L = core.L
local LDD = core.LDD

-- THE frame
local tdlFrame

-- profile-dependant variables (those are reset in mainFrame:Init())

local dontRefreshPls = 0
local contentWidgets = {}

--[[

-- // contentWidgets examples:

contentWidgets = {
  [catID] = { -- widgets:CategoryWidget(catID)
    -- data
    enum = enums.category,
    catID = catID,
    catData = catData,
    -- frames
    interactiveLabel,
    favsRemainingLabel,
    addEditBox,
  },
  ...
  [itemID] = { -- widgets:ItemWidget(itemID)
    -- data
    enum = enums.item,
    itemID = itemID,
    itemData = itemData,
    -- frames
    checkBtn,
    interactiveLabel,
    removeBtn,
    favoriteBtn,
    descBtn,
  },
  ...
}

]]

-- these are for code comfort

local ctab -- set at initialization, it's just an alias
local centerXOffset = 165
local lineOffset = 120
local cursorX, cursorY, cursorDist = 0, 0, 10 -- for my special drag

--/*******************/ GENERAL /*************************/--

-- // Local functions

local function menuClick(menuEnum)
  -- controls what should be done when we click on menu buttons
  local menuFrames = tdlFrame.content.menuFrames

  -- // we update the selected menu (toggle mode)
  if menuFrames.selected == menuEnum then
    menuFrames.selected = nil
  else menuFrames.selected = menuEnum end

  mainFrame:Refresh() -- we reload the frame to display the changes

  -- // we do specific things afterwards
  local selected = menuFrames.selected

  -- like updating the color to white-out the selected menu button, so first we reset them all
  tdlFrame.content.categoryButton.Icon:SetDesaturated(nil) tdlFrame.content.categoryButton.Icon:SetVertexColor(0.85, 1, 1) -- here we change the vertex color because the original icon is a bit reddish
  tdlFrame.content.frameOptionsButton.Icon:SetDesaturated(nil)
  tdlFrame.content.tabActionsButton.Icon:SetDesaturated(nil)

  -- and other things
  if selected == enums.menus.addcat then -- add a category menu
    tdlFrame.content.categoryButton.Icon:SetDesaturated(1) tdlFrame.content.categoryButton.Icon:SetVertexColor(1, 1, 1)
    widgets:SetFocusEditBox(menuFrames[enums.menus.addcat].categoryEditBox)
    tutorialsManager:Validate("addNewCat") -- tutorial
  elseif selected == enums.menus.frameopt then -- frame options menu
    tdlFrame.content.frameOptionsButton.Icon:SetDesaturated(1)
    tutorialsManager:Validate("accessOptions") -- tutorial
  elseif selected == enums.menus.tabact then -- tab actions menu
    tdlFrame.content.tabActionsButton.Icon:SetDesaturated(1)
  end
end

local function setDoubleLinePoints(lineLeft, lineRight, l, y)
  lineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, y)
  lineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 - 10, y)
  lineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 + 10, y)
  lineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, y)
end

-- // General functions

function mainFrame:GetFrame()
  return tdlFrame
end

function mainFrame:GetContentWidgets()
  return contentWidgets
end

function mainFrame:Toggle()
  -- toggles the visibility of the ToDoList frame
  tdlFrame:SetShown(not tdlFrame:IsShown())
end

function mainFrame:ChangeTab(newTabID)
  ctab(newTabID)
  mainFrame:Refresh()
  tdlFrame.content.menuFrames[enums.menus.addcat].categoryEditBox:SetText(newTabID) -- TODO remove
end

function mainFrame:IsVisible(frame, margin)
  -- returns true if the frame is visible in the tdlFrame
  -- (not :IsVisible(), i'm talking about wether it's currently visible in the scroll frame, or hidden because of SetClipsChildren)
  margin = margin or 0

  local frameX, frameY = frame:GetCenter()

  local tdlFrameMinY = tdlFrame:GetBottom()
  local tdlFrameMaxY    = tdlFrame:GetTop()
  local tdlFrameMinX   = tdlFrame:GetLeft()
  local tdlFrameMaxX  = tdlFrame:GetRight()

  if frameX - margin > tdlFrameMinX
  and frameX + margin < tdlFrameMaxX
  and frameY - margin > tdlFrameMinY
  and frameY + margin < tdlFrameMaxY then
    return true
  end
end

-- // frame color/visual update functions

function mainFrame:UpdateCheckedStates()
  for _,contentWidget in pairs(contentWidgets) do
    if contentWidget.enum == enums.item then -- for every item checkboxes
      contentWidget.checkBtn:SetChecked(contentWidget.itemData.checked)
    end
  end
end

function mainFrame:UpdateRemainingNumberLabels()
  local tabID = ctab()

  -- we update the numbers of remaining things to do in total for the current tab
  local numbers = dataManager:GetRemainingNumbers(nil, tabID)
  tdlFrame.content.remainingNumber:SetText((numbers.totalUnchecked > 0 and "|cffffffff" or "|cff00ff00")..numbers.totalUnchecked.."|r")
  tdlFrame.content.remainingFavsNumber:SetText(numbers.uncheckedFav > 0 and "("..numbers.uncheckedFav..")" or "")

  -- we update the remaining numbers of every category in the tab
  for catID,catData in dataManager:ForEach(enums.category, tabID) do
    local nbFav = dataManager:GetRemainingNumbers(nil, tabID, catID).uncheckedFav
    local text = nbFav > 0 and "("..nbFav..")" or ""
    contentWidgets[catID].favsRemainingLabel:SetText(text)

    local catData = contentWidgets[catID].catData
    if not catData.closedInTabIDs[tabID] or text == "" then -- if the category is opened or the label shows nothing
      contentWidgets[catID].favsRemainingLabel:Hide()
      contentWidgets[catID].originalTabLabel:ClearAllPoints()
      contentWidgets[catID].originalTabLabel:SetPoint("LEFT", contentWidgets[catID].interactiveLabel, "RIGHT", 6, 0)
    else -- if the category is closed and the label shows something
      contentWidgets[catID].favsRemainingLabel:Show()
      contentWidgets[catID].originalTabLabel:ClearAllPoints()
      contentWidgets[catID].originalTabLabel:SetPoint("LEFT", contentWidgets[catID].favsRemainingLabel, "RIGHT", 6, 0)
    end
  end
end

function mainFrame:updateFavsRemainingNumbersColor()
  -- this updates the favorite color for every favorites remaining number label
  tdlFrame.content.remainingFavsNumber:SetTextColor(unpack(NysTDL.db.profile.favoritesColor))
  for _, contentWidget in pairs(contentWidgets) do
    if contentWidget.enum == enums.category then -- for every category widgets
      contentWidget.favsRemainingLabel:SetTextColor(unpack(NysTDL.db.profile.favoritesColor))
    end
  end
end

function mainFrame:UpdateItemNamesColor()
  for _, contentWidget in pairs(contentWidgets) do
    if contentWidget.enum == enums.item then -- for every item widget
      -- we color in accordance to their checked state
      if contentWidget.itemData.checked then
        contentWidget.interactiveLabel.Text:SetTextColor(0, 1, 0) -- green
      else
        if contentWidget.itemData.favorite then
          contentWidget.interactiveLabel.Text:SetTextColor(unpack(NysTDL.db.profile.favoritesColor)) -- colored
        else
          contentWidget.interactiveLabel.Text:SetTextColor(unpack(utils:ThemeDownTo01(database.themes.theme_yellow))) -- yellow
        end
      end
    end
  end
end

function mainFrame:ApplyNewRainbowColor()
  -- // when called, takes the current favs color, goes to the next one i times, then updates the visual
  -- it is called by the OnUpdate event of the frame / of one of the description frames

  local i = NysTDL.db.profile.rainbowSpeed

  local r, g, b = unpack(NysTDL.db.profile.favoritesColor)
  local Cmax = math.max(r, g, b)
  local Cmin = math.min(r, g, b)
  local delta = Cmax - Cmin

  local Hue
  if delta == 0 then
    Hue = 0
  elseif Cmax == r then
    Hue = 60 * (((g-b)/delta)%6)
  elseif Cmax == g then
    Hue = 60 * (((b-r)/delta)+2)
  elseif Cmax == b then
    Hue = 60 * (((r-g)/delta)+4)
  end

  if Hue >= 359 then
    Hue = 0
  else
    Hue = Hue + i
    if Hue >= 359 then
      Hue = Hue - 359
    end
  end

  local X = 1-math.abs((Hue/60)%2-1)

  if Hue < 60 then
    r, g, b = 1, X, 0
  elseif Hue < 120 then
    r, g, b = X, 1, 0
  elseif Hue < 180 then
    r, g, b = 0, 1, X
  elseif Hue < 240 then
    r, g, b = 0, X, 1
  elseif Hue < 300 then
    r, g, b = X, 0, 1
  elseif Hue < 360 then
    r, g, b = 1, 0, X
  end

  -- we apply the new color where it needs to be
  NysTDL.db.profile.favoritesColor = { r, g, b }
  mainFrame:updateFavsRemainingNumbersColor()
  mainFrame:UpdateItemNamesColor()
end

-- TODO move this
-- this table is to only update once the things concerned by the special key inputs instead of every frame
local T_Event_TDLFrame_OnUpdate = {
  other = function(self, x) -- returns true if an other argument than the given one or 'nothing' is true
    for k,v in pairs(self) do
      if type(v) == "boolean" then
        if k ~= "nothing" and k ~= x and v then
          return true
        end
      end
    end
    return false
  end,
  something = function(self, x) -- sets to true only the given argument, while falsing every other
    for k,v in pairs(self) do
      if type(v) == "boolean" then
        self[k] = false
      end
    end
    self[x] = true
  end,
  nothing = false,
  shift = false,
  ctrl = false,
  alt = false,
}
function mainFrame:UpdateItemButtons(itemID)
  -- // shows the right button at the left of the given item
  local itemWidget = contentWidgets[itemID] -- we take the item widget
  if not itemWidget then return end -- just in case

  -- first we hide each button to show the good one afterwards
  itemWidget.descBtn:Hide()
  itemWidget.favoriteBtn:Hide()
  itemWidget.removeBtn:Hide()

  if T_Event_TDLFrame_OnUpdate.ctrl then -- if ctrl is pressed and is the priority
    itemWidget.descBtn:Show() -- we force the paper (description)
    return
  elseif T_Event_TDLFrame_OnUpdate.shift then -- if shift is pressed and is the priority
    itemWidget.favoriteBtn:Show() -- we force the star (favorite)
    return
  end

  local itemData = itemWidget.itemData
  if itemData.description then -- the paper (description) icon takes the lead
    itemWidget.descBtn:Show()
  elseif itemData.favorite then -- then the star (favorite) icon
    itemWidget.favoriteBtn:Show()
  else -- or the cross (remove) icon by default
    itemWidget.removeBtn:Show()
  end
end

--/*******************/ EVENTS /*************************/--

function mainFrame:Event_ScrollFrame_OnMouseWheel(delta)
  -- defines how fast we can scroll throught the frame (here: 30)
  local newValue = tdlFrame.ScrollFrame:GetVerticalScroll() - (delta * 30)

  if newValue < 0 then
    newValue = 0
  elseif newValue > tdlFrame.ScrollFrame:GetVerticalScrollRange() then
    newValue = tdlFrame.ScrollFrame:GetVerticalScrollRange()
  end

  tdlFrame.ScrollFrame:SetVerticalScroll(newValue)
end

function mainFrame:Event_FrameAlphaSlider_OnValueChanged(value)
  -- itemsList frame part
  NysTDL.db.profile.frameAlpha = value
  tdlFrame.content.menuFrames[enums.menus.frameopt].frameAlphaSliderValue:SetText(value)
  tdlFrame:SetBackdropColor(0, 0, 0, value/100)
  tdlFrame:SetBackdropBorderColor(1, 1, 1, value/100)

  -- description frames part
  widgets:SetDescFramesAlpha(value)
end

function mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(value)
  -- itemsList frame part
  NysTDL.db.profile.frameContentAlpha = value
  tdlFrame.content.menuFrames[enums.menus.frameopt].frameContentAlphaSliderValue:SetText(value)
  tdlFrame.content:SetAlpha(value/100) -- content
  tdlFrame.ScrollFrame.ScrollBar:SetAlpha(value/100)
  tdlFrame.closeButton:SetAlpha(value/100)
  tdlFrame.resizeButton:SetAlpha(value/100)

  -- description frames part
  widgets:SetDescFramesContentAlpha(value)
end

function mainFrame:Event_TDLFrame_OnVisibilityUpdate()
  -- things to do when we hide/show the list
  menuClick() -- to close any opened menu and refresh the list
  NysTDL.db.profile.lastListVisibility = tdlFrame:IsShown()
  if dragndrop.dragging then dragndrop:CancelDragging() end
end

function mainFrame:Event_TDLFrame_OnSizeChanged(width, height)
  -- saved variables
  NysTDL.db.profile.frameSize.width = width
  NysTDL.db.profile.frameSize.height = height

  -- scaling
  local scale = width/enums.tdlFrameDefaultWidth
  self.content:SetScale(scale) -- content
  self.ScrollFrame.ScrollBar:SetScale(scale)
  self.closeButton:SetScale(scale)
  self.resizeButton:SetScale(scale)
  tutorialsManager:SetFramesScale(scale)
end

function mainFrame:Event_TDLFrame_OnUpdate()
  -- if (tdlFrame:IsMouseOver()) then
  --   tdlFrame.ScrollFrame.ScrollBar:Show()
  -- else
  --   tdlFrame.ScrollFrame.ScrollBar:Hide()
  -- end

  -- dragging
  if tdlFrame.isMouseDown and not tdlFrame.hasMoved then
    local x, y = GetCursorPosition()
    if (x > cursorX + cursorDist) or (x < cursorX - cursorDist) or (y > cursorY + cursorDist) or (y < cursorY - cursorDist) then  -- we start dragging the frame
      tdlFrame:StartMoving()
      tdlFrame.hasMoved = true
    end
  end

  -- testing and showing the right buttons depending on our inputs
  if IsAltKeyDown() and not T_Event_TDLFrame_OnUpdate:other("alt") then
    if not T_Event_TDLFrame_OnUpdate.alt then
      T_Event_TDLFrame_OnUpdate:something("alt")

      tutorialsManager:Validate("ALTkey") -- tutorial
      -- we switch the category and frame options buttons for the undo and frame action ones and vice versa
      tdlFrame.content.categoryButton:Hide()
      tdlFrame.content.frameOptionsButton:Hide()
      tdlFrame.content.tabActionsButton:Show()
      tdlFrame.content.undoButton:Show()
      -- resize button
      tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame.ScrollFrame, "BOTTOMRIGHT", - 7, 32)
      tdlFrame.resizeButton:Show()
    end
  elseif IsShiftKeyDown() and not T_Event_TDLFrame_OnUpdate:other("shift") then
    if not T_Event_TDLFrame_OnUpdate.shift then
      T_Event_TDLFrame_OnUpdate:something("shift")

      -- we show the star (favorite) icon for every item
      for _, contentWidget in pairs(contentWidgets) do
        if contentWidget.enum == enums.item then
          contentWidget.descBtn:Hide()
          contentWidget.favoriteBtn:Show()
          contentWidget.removeBtn:Hide()
        end
      end
    end
  elseif IsControlKeyDown() and not T_Event_TDLFrame_OnUpdate:other("ctrl") then
    if not T_Event_TDLFrame_OnUpdate.ctrl then
      T_Event_TDLFrame_OnUpdate:something("ctrl")

      -- we show the paper (description) icon for every item
      for _, contentWidget in pairs(contentWidgets) do
        if contentWidget.enum == enums.item then
          contentWidget.descBtn:Show()
          contentWidget.favoriteBtn:Hide()
          contentWidget.removeBtn:Hide()
        end
      end
    end
  elseif not T_Event_TDLFrame_OnUpdate.nothing then
    T_Event_TDLFrame_OnUpdate:something("nothing")

    -- item icons
    for itemID in dataManager:ForEach(enums.item) do
      mainFrame:UpdateItemButtons(itemID)
    end

    -- buttons
    tdlFrame.content.categoryButton:Show()
    tdlFrame.content.frameOptionsButton:Show()
    tdlFrame.content.tabActionsButton:Hide()
    tdlFrame.content.undoButton:Hide()
    -- resize button
    tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame.ScrollFrame, "BOTTOMRIGHT", - 7, 17)
    tdlFrame.resizeButton:Hide()
  end
end

--/*******************/ LIST LOADING /*************************/--

function mainFrame:UpdateWidget(ID, enum)
  -- i take the enum here, and am not using Find just for optimization

  if contentWidgets[ID] then
    contentWidgets[ID]:ClearAllPoints()
    contentWidgets[ID]:Hide()
  end

  if enum == enums.item then
    contentWidgets[ID] = widgets:ItemWidget(ID, tdlFrame.content)
    mainFrame:UpdateItemButtons(ID)
  elseif enum == enums.category then
    contentWidgets[ID] = widgets:CategoryWidget(ID, tdlFrame.content)
  end
end

function mainFrame:DeleteWidget(ID)
  if contentWidgets[ID] then
    contentWidgets[ID]:ClearAllPoints()
    contentWidgets[ID]:Hide()
    if contentWidgets[ID].enum == enums.category then
      widgets:RemoveHyperlinkEditBox(contentWidgets[ID].addEditBox)
    end
    contentWidgets[ID] = nil
  end
end

local function loadWidgets()
  -- // creating every category and item widget for the list
  -- called at load time / when changing profiles to crunch every creation at the same time

  -- category widgets
  for catID in dataManager:ForEach(enums.category) do
    mainFrame:UpdateWidget(catID, enums.category)
  end

  -- item widgets
  for itemID in dataManager:ForEach(enums.item) do
    mainFrame:UpdateWidget(itemID, enums.item)
  end
end

-- // Content loading

local function loadContent()
  -- // reloading of elements that need updates

  -- // we show the good sub-menu (add a category, frame options, tab actions, ...)
  local menuFrames = tdlFrame.content.menuFrames
  -- so first we hide each of them
  for menuEnum, menuFrame in pairs(menuFrames) do
    if menuEnum ~= "selected" then menuFrame:Hide() end
  end

  -- and then we show the good one, if there is one to show
  if menuFrames.selected then
    local menu = menuFrames[menuFrames.selected]
    menu:Show()
    tdlFrame.content.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78 - menu:GetHeight())
    tdlFrame.content.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78 - menu:GetHeight())
  else
    tdlFrame.content.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
    tdlFrame.content.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78)
  end

  -- // nothing label ("There are no items!" / "(%i hidden item(s))")
  -- first, we get how many items there are in the tab
  local numbers = dataManager:GetRemainingNumbers(nil, ctab())

  -- we hide it by default
  tdlFrame.content.nothingLabel:Hide()

  -- then we show it depending on the result
  if numbers.total == 0 then -- if there are no items in the current tab
    tdlFrame.content.nothingLabel:SetText(L["There are no items!"])
    tdlFrame.content.nothingLabel:Show()
  else -- if there are items in the tab
    if numbers.totalChecked == numbers.total then -- and if they are all checked ones
      -- we check if they are hidden or not, and if they are, we show the nothing label with a different text
      local tabData = select(3, dataManager:Find(ctab()))
      if tabData.hideCheckedItems then -- TODO hide cat with items? / close it automatically with special label ?
        tdlFrame.content.nothingLabel:SetText(utils:SafeStringFormat(L["(%i hidden item(s))"], numbers.totalChecked))
        tdlFrame.content.nothingLabel:Show()
      end
    end
  end
end

local function loadList()
  -- // generating all of the content (items, checkboxes, editboxes, category labels...)
  -- it's the big big important generation loop (oof)

  -- first things first, we hide EVERY widget, so that we only show the good ones after
  for _,contentWidget in pairs(contentWidgets) do
    contentWidget:ClearAllPoints()
    contentWidget:Hide()
  end

  -- let's go!
  local tabID, tabData = ctab(), select(3, dataManager:Find(ctab()))
  local newX, xSpace, newY, ySpace = 0, 12, 0, 28
  local oldCatWidget = tdlFrame.content.dummyFrame -- starting point

  -- category widgets loop
  for catOrder,catID in ipairs(tabData.orderedCatIDs) do
    contentWidgets[catID]:SetPoint("TOPLEFT", tdlFrame.content.dummyFrame, "TOPLEFT", newX, newY)
    contentWidgets[catID]:Show()

    if oldCatWidget == tdlFrame.content.dummyFrame then -- if it's the first loaded cat widget
      tutorialsManager:SetPoint("addItem", "RIGHT", contentWidgets[catID], "LEFT", -23, 0) -- we put the corresponding tuto on it
    end

    oldCatWidget = contentWidgets[catID]
    newY = newY - ySpace

    local catData = contentWidgets[catID].catData

    local originalTabName = select(3, dataManager:Find(catData.originalTabID)).name
    if originalTabName == tabData.name then
      contentWidgets[catID].originalTabLabel:Hide()
    else -- if the tab is showing a cat that was not created here, we show the label specifying the cat's original tab
      contentWidgets[catID].originalTabLabel:SetText("("..originalTabName.." tab)") -- TODO locale
      contentWidgets[catID].originalTabLabel:Show()
    end

    if not catData.closedInTabIDs[tabID] then -- if the cat is opened, we display all of its items
      -- item widgets loop
      newX = newX + xSpace
      for itemOrder,itemID in ipairs(catData.orderedContentIDs) do -- TODO for now, only items
        if not contentWidgets[itemID].itemData.tabIDs[tabID] or not dataManager:IsHidden(itemID, tabID) then -- OPTIMIZE this func
          contentWidgets[itemID]:SetPoint("TOPLEFT", tdlFrame.content.dummyFrame, "TOPLEFT", newX, newY)
          contentWidgets[itemID]:Show()
          newY = newY - ySpace
        end
      end
      newX = newX - xSpace
    end
  end

  -- drag&drop
  if dragndrop.dragging then
    dragndrop:UpdateDropFrames()
  end
end

-- // frame refresh

function mainFrame:UpdateVisuals()
  -- updates everything visual about the frame without actually fully refreshing it,
  -- this func can be called on its own, it's a less-intensive version than calling Refresh
  mainFrame:UpdateCheckedStates()
  mainFrame:UpdateRemainingNumberLabels()
  mainFrame:updateFavsRemainingNumbersColor()
  mainFrame:UpdateItemNamesColor()
  widgets:UpdateTDLButtonColor()
end

function mainFrame:DontRefreshNextTime(nb)
  -- // this func's sole purpose is optimization:
  -- ex: i sometimes only need to refresh the list one time after 10 operations instead of 10 times
  if type(nb) ~= "number" then
    nb = 1
  end

  dontRefreshPls = dontRefreshPls + nb
end

function mainFrame:Refresh()
  -- // THE refresh function, reloads the entire list's content in accordance to the current database

  -- anti-refresh for optimization
  if dontRefreshPls > 0 then
    dontRefreshPls = dontRefreshPls - 1
    return
  end

  -- // ************************************************************* // --

  local tabID = ctab()
  local tabData = select(3, dataManager:Find(tabID))

  -- TAB OPTION: delete checked items
  if tabData.deleteCheckedItems then dataManager:DeleteCheckedItems(tabID) end

  -- // ************************************************************* // --

  loadContent() -- content reloading (menus, buttons, ...)
  loadList() -- list reloading (categories, items, ...)
  mainFrame:UpdateVisuals() -- coloring...
end

--/*******************/ FRAME CREATION /*************************/--

-- // Content generation

local function generateMenuAddACategory()
  local menuframe = tdlFrame.content.menuFrames[enums.menus.addcat]

  local function addCat() -- DRY
    if dataManager:CreateCategory(menuframe.categoryEditBox:GetText(), ctab()) then
      menuframe.categoryEditBox:SetText("") -- we clear the box if the adding was a success
      tutorialsManager:Validate("addCat") -- tutorial
    end
    widgets:SetFocusEditBox(menuframe.categoryEditBox)
  end

  --/************************************************/--

  -- title
  menuframe.menuTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Add a category"].." \\"))
  menuframe.menuTitle:SetPoint("CENTER", menuframe, "TOPLEFT", centerXOffset, 0)
  -- left/right lines
  menuframe.menuTitleLL = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
  menuframe.menuTitleLR = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
  setDoubleLinePoints(menuframe.menuTitleLL, menuframe.menuTitleLR, menuframe.menuTitle:GetWidth(), 0)

  --/************************************************/--

  menuframe.labelCategoryName = widgets:NoPointsLabel(menuframe, nil, L["Category:"])
  menuframe.labelCategoryName:SetPoint("TOPLEFT", menuframe.menuTitle, "TOP", -140, - 35)

  menuframe.categoryEditBox = CreateFrame("EditBox", nil, menuframe, "InputBoxTemplate") -- edit box to put the new category name
  menuframe.categoryEditBox:SetPoint("RIGHT", menuframe.labelCategoryName, "LEFT", 257, 0)
  menuframe.categoryEditBox:SetSize(257 - widgets:GetWidth(menuframe.labelCategoryName:GetText()) - 20, 30)
  menuframe.categoryEditBox:SetAutoFocus(false)
  -- menuframe.categoryEditBox:SetScript("OnKeyDown", function(_, key) if (key == "TAB") then widgets:SetFocusEditBox(menuframe.nameEditBox) end end) XXX -- to switch easily between the two edit boxes
  menuframe.categoryEditBox:SetScript("OnEnterPressed", addCat) -- if we press enter, it's like we clicked on the add button
  menuframe.categoryEditBox:HookScript("OnEditFocusGained", function(self) -- TODO what is this
    if NysTDL.db.profile.highlightOnFocus then
      self:HighlightText()
    else
      self:HighlightText(self:GetCursorPosition(), self:GetCursorPosition())
    end
  end)

  --/************************************************/--

  --  // LibUIDropDownMenu version // --

  --@retail@
  menuframe.categoriesDropdown = LDD:Create_UIDropDownMenu("NysTDL_Frame_CategoriesDropdown", nil)

  menuframe.categoriesDropdown.HideMenu = function()
  	if L_UIDROPDOWNMENU_OPEN_MENU == menuframe.categoriesDropdown then
  		LDD:CloseDropDownMenus()
  	end
  end

  menuframe.categoriesDropdown.SetValue = function(self, newValue)
    -- we update the category edit box
    if (menuframe.categoryEditBox:GetText() == newValue) then
      menuframe.categoryEditBox:SetText("")
      widgets:SetFocusEditBox(menuframe.categoryEditBox)
    elseif (newValue ~= nil) then
      menuframe.categoryEditBox:SetText(newValue)
      -- widgets:SetFocusEditBox(menuframe.nameEditBox) XXX
    end
  end

  -- Create and bind the initialization function to the dropdown menu
  LDD:UIDropDownMenu_Initialize(menuframe.categoriesDropdown, function(self, level)
    if not level then return end
    local info = LDD:UIDropDownMenu_CreateInfo()
    wipe(info)

    if level == 1 then
      -- the title
      info.isTitle = true
      info.notCheckable = true
      info.text = L["Use an existing category"]
      LDD:UIDropDownMenu_AddButton(info, level)

      -- the categories
      wipe(info)
      info.func = self.SetValue
      local categories = mainFrame:GetCategoriesOrdered()
      for _, v in pairs(categories) do
        info.arg1 = v
        info.text = v
        info.checked = menuframe.categoryEditBox:GetText() == v
        LDD:UIDropDownMenu_AddButton(info, level)
      end

      -- the close button
      wipe(info)
  		info.notCheckable = true
  		info.text = CLOSE
  		info.func = self.HideMenu
  		LDD:UIDropDownMenu_AddButton(info, level)
    end
  end, "MENU")

  menuframe.categoriesDropdownButton = CreateFrame("Button", "NysTDL_Button_CategoriesDropdown", menuframe.categoryEditBox, "NysTDL_DropdownButton")
  menuframe.categoriesDropdownButton:SetPoint("LEFT", menuframe.categoryEditBox, "RIGHT", 0, -1)
  menuframe.categoriesDropdownButton:SetScript("OnClick", function(self)
    LDD:ToggleDropDownMenu(1, nil, menuframe.categoriesDropdown, self:GetName(), 0, 0)
  end)
  menuframe.categoriesDropdownButton:SetScript("OnHide", menuframe.categoriesDropdown.HideMenu)
  --@end-retail@

  --  // NOLIB version1 - Custom frame style (clean, with wipes): taints click on quests in combat // --
  --[===[@non-retail@
  menuframe.categoriesDropdown = CreateFrame("Frame", "NysTDL_Frame_CategoriesDropdown")
  menuframe.categoriesDropdown.displayMode = "MENU"
  menuframe.categoriesDropdown.info = {}
  menuframe.categoriesDropdown.initialize = function(self, level)
    if not level then return end
    local info = self.info
    wipe(info)

    if level == 1 then
      -- the title
      info.isTitle = true
      info.notCheckable = true
      info.text = L["Use an existing category"]
      UIDropDownMenu_AddButton(info, level)

      -- the categories
      wipe(info)
      info.func = self.SetValue
      local categories = mainFrame:GetCategoriesOrdered()
      for _, v in pairs(categories) do
        info.text = v
        info.arg1 = v
        info.checked = menuframe.categoryEditBox:GetText() == v
        UIDropDownMenu_AddButton(info, level)
      end

      wipe(info)
  		info.notCheckable = true
  		info.text = CLOSE
  		info.func = self.HideMenu
  		UIDropDownMenu_AddButton(info, level)
    end
  end
  --@end-non-retail@]===]

  --  // NOLIB version2 - WoW template style (no level check): taints SetFocus and click on quests in combat // --
  -- menuframe.categoriesDropdown = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
  -- UIDropDownMenu_Initialize(menuframe.categoriesDropdown, function(self)
  --   local info = UIDropDownMenu_CreateInfo()
  --
  --   -- the title
  --   info.isTitle = true
  --   info.notCheckable = true
  --   info.text = L["Use an existing category"]
  --   UIDropDownMenu_AddButton(info)
  --
  --   -- the categories
  --   info.notCheckable = false
  --   info.isTitle = false
  --   info.disabled = false
  --   local categories = mainFrame:GetCategoriesOrdered()
  --   for _, v in pairs(categories) do
  --     info.func = self.SetValue
  --     info.arg1 = v
  --     info.text = info.arg1
  --     info.checked = menuframe.categoryEditBox:GetText() == info.arg1
  --     UIDropDownMenu_AddButton(info)
  --   end
  --
  --   -- the cancel button
  --   info.func = nil
  --   info.arg1 = nil
  --   info.checked = false
  --   info.notCheckable = true
  --   info.text = L["Cancel"]
  --   UIDropDownMenu_AddButton(info)
  -- end, "MENU")

  -- // NOLIB common code // --
  --[===[@non-retail@
  menuframe.categoriesDropdown.HideMenu = function()
  	if UIDROPDOWNMENU_OPEN_MENU == menuframe.categoriesDropdown then
  		CloseDropDownMenus()
  	end
  end
  menuframe.categoriesDropdown.SetValue = function(self, newValue)
    -- we update the category edit box
    if (menuframe.categoryEditBox:GetText() == newValue) then
      menuframe.categoryEditBox:SetText("")
      widgets:SetFocusEditBox(menuframe.categoryEditBox)
    elseif (newValue ~= nil) then
      menuframe.categoryEditBox:SetText(newValue)
      -- widgets:SetFocusEditBox(menuframe.nameEditBox) XXX
    end
  end
  menuframe.categoriesDropdownButton = CreateFrame("Button", "NysTDL_Button_CategoriesDropdown", menuframe.categoryEditBox, "NysTDL_DropdownButton")
  menuframe.categoriesDropdownButton:SetPoint("LEFT", menuframe.categoryEditBox, "RIGHT", 0, -1)
  menuframe.categoriesDropdownButton:SetScript("OnClick", function(self)
    ToggleDropDownMenu(1, nil, menuframe.categoriesDropdown, self:GetName(), 0, 0)
  end)
  menuframe.categoriesDropdownButton:SetScript("OnHide", menuframe.categoriesDropdown.HideMenu)
  --@end-non-retail@]===]

  --/************************************************/--

  menuframe.addBtn = widgets:Button("addButton", menuframe, L["Add category"])
  menuframe.addBtn:SetPoint("TOP", menuframe.menuTitle, "TOP", 0, -65)
  menuframe.addBtn:SetScript("OnClick", addCat)

  tutorialsManager:SetPoint("addCat", "TOP", menuframe.addBtn, "BOTTOM", 0, -22)
end

local function generateMenuFrameOptions()
  local menuframe = tdlFrame.content.menuFrames[enums.menus.frameopt]

  --/************************************************/--

  -- title
  menuframe.menuTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Frame options"].." \\"))
  menuframe.menuTitle:SetPoint("CENTER", menuframe, "TOPLEFT", centerXOffset, 0)
  -- left/right lines
  menuframe.menuTitleLL = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
  menuframe.menuTitleLR = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
  setDoubleLinePoints(menuframe.menuTitleLL, menuframe.menuTitleLR, menuframe.menuTitle:GetWidth(), 0)

  --/************************************************/--

  menuframe.resizeTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cffffffff%s|r", L["Hold ALT to see the resize button"]))
  menuframe.resizeTitle:SetPoint("TOP", menuframe.menuTitle, "TOP", 0, -32)
  menuframe.resizeTitle:SetFontObject("GameFontHighlight")
  menuframe.resizeTitle:SetWidth(230)

  --/************************************************/--

  menuframe.frameAlphaSlider = CreateFrame("Slider", "frameAlphaSlider", menuframe, "OptionsSliderTemplate")
  menuframe.frameAlphaSlider:SetPoint("TOP", menuframe.resizeTitle, "TOP", 0, -28 - menuframe.resizeTitle:GetHeight()) -- TODO redo?
  menuframe.frameAlphaSlider:SetWidth(200)
  -- menuframe.frameAlphaSlider:SetHeight(17)
  -- menuframe.frameAlphaSlider:SetOrientation('HORIZONTAL')

  menuframe.frameAlphaSlider:SetMinMaxValues(0, 100)
  menuframe.frameAlphaSlider:SetValue(NysTDL.db.profile.frameAlpha)
  menuframe.frameAlphaSlider:SetValueStep(1)
  menuframe.frameAlphaSlider:SetObeyStepOnDrag(true)

  menuframe.frameAlphaSlider.tooltipText = L["Change the background opacity"] --Creates a tooltip on mouseover.
  _G[menuframe.frameAlphaSlider:GetName() .. 'Low']:SetText((select(1,menuframe.frameAlphaSlider:GetMinMaxValues()))..'%') --Sets the left-side slider text (default is "Low").
  _G[menuframe.frameAlphaSlider:GetName() .. 'High']:SetText((select(2,menuframe.frameAlphaSlider:GetMinMaxValues()))..'%') --Sets the right-side slider text (default is "High").
  _G[menuframe.frameAlphaSlider:GetName() .. 'Text']:SetText(L["Frame opacity"]) --Sets the "title" text (top-centre of slider).
  menuframe.frameAlphaSlider:SetScript("OnValueChanged", mainFrame.Event_FrameAlphaSlider_OnValueChanged)

  menuframe.frameAlphaSliderValue = menuframe.frameAlphaSlider:CreateFontString("frameAlphaSliderValue") -- the font string to see the current value
  menuframe.frameAlphaSliderValue:SetPoint("TOP", menuframe.frameAlphaSlider, "BOTTOM", 0, 0)
  menuframe.frameAlphaSliderValue:SetFontObject("GameFontNormalSmall")
  menuframe.frameAlphaSliderValue:SetText(menuframe.frameAlphaSlider:GetValue())

  --/************************************************/--

  menuframe.frameContentAlphaSlider = CreateFrame("Slider", "frameContentAlphaSlider", menuframe, "OptionsSliderTemplate")
  menuframe.frameContentAlphaSlider:SetPoint("TOP", menuframe.frameAlphaSlider, "TOP", 0, -50)
  menuframe.frameContentAlphaSlider:SetWidth(200)
  -- menuframe.frameContentAlphaSlider:SetHeight(17)
  -- menuframe.frameContentAlphaSlider:SetOrientation('HORIZONTAL')

  menuframe.frameContentAlphaSlider:SetMinMaxValues(60, 100)
  menuframe.frameContentAlphaSlider:SetValue(NysTDL.db.profile.frameContentAlpha)
  menuframe.frameContentAlphaSlider:SetValueStep(1)
  menuframe.frameContentAlphaSlider:SetObeyStepOnDrag(true)

  menuframe.frameContentAlphaSlider.tooltipText = L["Change the opacity for texts, buttons and other elements"] --Creates a tooltip on mouseover.
  _G[menuframe.frameContentAlphaSlider:GetName() .. 'Low']:SetText((select(1,menuframe.frameContentAlphaSlider:GetMinMaxValues()))..'%') --Sets the left-side slider text (default is "Low").
  _G[menuframe.frameContentAlphaSlider:GetName() .. 'High']:SetText((select(2,menuframe.frameContentAlphaSlider:GetMinMaxValues()))..'%') --Sets the right-side slider text (default is "High").
  _G[menuframe.frameContentAlphaSlider:GetName() .. 'Text']:SetText(L["Frame content opacity"]) --Sets the "title" text (top-centre of slider).
  menuframe.frameContentAlphaSlider:SetScript("OnValueChanged", mainFrame.Event_FrameContentAlphaSlider_OnValueChanged)

  menuframe.frameContentAlphaSliderValue = menuframe.frameContentAlphaSlider:CreateFontString("frameContentAlphaSliderValue") -- the font string to see the current value
  menuframe.frameContentAlphaSliderValue:SetPoint("TOP", menuframe.frameContentAlphaSlider, "BOTTOM", 0, 0)
  menuframe.frameContentAlphaSliderValue:SetFontObject("GameFontNormalSmall")
  menuframe.frameContentAlphaSliderValue:SetText(menuframe.frameContentAlphaSlider:GetValue())

  --/************************************************/--

  menuframe.affectDesc = CreateFrame("CheckButton", "NysTDL_affectDesc", menuframe, "ChatConfigCheckButtonTemplate")
  menuframe.affectDesc.tooltip = L["Share the opacity options of this frame onto the description frames (only when checked)"]
  menuframe.affectDesc:SetPoint("TOP", menuframe.frameContentAlphaSlider, "TOP", 0, -40)
  menuframe.affectDesc.Text:SetText(L["Affect description frames"])
  menuframe.affectDesc.Text:SetFontObject("GameFontHighlight")
  menuframe.affectDesc.Text:ClearAllPoints()
  menuframe.affectDesc.Text:SetPoint("TOP", menuframe.affectDesc, "BOTTOM")
  menuframe.affectDesc:SetHitRectInsets(0, 0, 0, 0)
  menuframe.affectDesc:SetScript("OnClick", function(self)
    NysTDL.db.profile.affectDesc = self:GetChecked() -- TODO oula
    mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.db.profile.frameAlpha)
    mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.db.profile.frameContentAlpha)
  end)
  menuframe.affectDesc:SetChecked(NysTDL.db.profile.affectDesc)

  --/************************************************/--

  menuframe.btnAddonOptions = widgets:Button("addonOptionsButton", menuframe, L["Open addon options"], "Interface\\Buttons\\UI-OptionsButton")
  menuframe.btnAddonOptions:SetPoint("TOP", menuframe.affectDesc, "TOP", 0, -55)
  menuframe.btnAddonOptions:SetScript("OnClick", function() if not optionsManager:ToggleOptions(true) then tdlFrame:Hide() end end)
end

local function generateMenuTabActions()
  local menuframe = tdlFrame.content.menuFrames[enums.menus.tabact]

  --/************************************************/--

  -- title
  menuframe.menuTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Tab actions"].." \\"))
  menuframe.menuTitle:SetPoint("CENTER", menuframe, "TOPLEFT", centerXOffset, 0)
  -- left/right lines
  menuframe.menuTitleLL = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
  menuframe.menuTitleLR = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
  setDoubleLinePoints(menuframe.menuTitleLL, menuframe.menuTitleLR, menuframe.menuTitle:GetWidth(), 0)
  --menuframe.menuTitle:SetText(string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Tab actions"].." ("..L[dataManager:GetName(ctab())]..") \\")) -- TODO redo this

  --/************************************************/--

  menuframe.btnCheck = widgets:Button("btnCheck_menuframe", menuframe, L["Check"], "Interface\\BUTTONS\\UI-CheckBox-Check")
  menuframe.btnCheck:SetPoint("TOP", menuframe.menuTitle, "TOP", 0, -35)
  menuframe.btnCheck:SetScript("OnClick", function() dataManager:ToggleTabChecked(ctab(), true) end)

  menuframe.btnUncheck = widgets:Button("btnUncheck_menuframe", menuframe, L["Uncheck"], "Interface\\BUTTONS\\UI-CheckBox-Check-Disabled")
  menuframe.btnUncheck:SetPoint("TOP", menuframe.btnCheck, "TOP", 0, -40)
  menuframe.btnUncheck:SetScript("OnClick", function() dataManager:ToggleTabChecked(ctab(), false) end)

  menuframe.btnClear = widgets:Button("clearButton", menuframe, L["Clear"], "Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check")
  menuframe.btnClear:SetPoint("TOP", menuframe.btnUncheck, "TOP", 0, -40)
  menuframe.btnClear:SetScript("OnClick", function() dataManager:ClearTab(ctab()) end)
end

local function generateFrameContent()
  -- // generating the content (top to bottom)

  -- creating content, scroll child of ScrollFrame (everything will be inside of it)
  tdlFrame.content = CreateFrame("Frame", nil, tdlFrame.ScrollFrame)
  tdlFrame.content:SetSize(310, 2000) -- y is determined by number of elements inside of it
  -- tdlFrame.content:SetSize(310, 1) -- y is determined by number of elements inside of it
  tdlFrame.ScrollFrame:SetScrollChild(tdlFrame.content)
  local content = tdlFrame.content

  -- title
  content.title = widgets:NoPointsLabel(content, nil, string.gsub(core.toc.title, "Ny's ", ""))
  content.title:SetPoint("CENTER", content, "TOPLEFT", centerXOffset, -16)
  content.title:SetFontObject("GameFontNormalLarge")
  -- left/right lines
  content.titleLL = widgets:ThemeLine(content, database.themes.theme_yellow, 0.8)
  content.titleLR = widgets:ThemeLine(content, database.themes.theme_yellow, 0.8)
  setDoubleLinePoints(content.titleLL, content.titleLR, content.title:GetWidth(), -18)

  -- remaining numbers labels
  content.remaining = widgets:NoPointsLabel(content, nil, L["Remaining:"])
  content.remaining:SetPoint("TOPLEFT", content.title, "TOP", -140, -32)
  content.remaining:SetFontObject("GameFontNormalLarge")
  content.remainingNumber = widgets:NoPointsLabel(content, nil, "...")
  content.remainingNumber:SetPoint("LEFT", content.remaining, "RIGHT", 6, 0)
  content.remainingNumber:SetFontObject("GameFontNormalLarge")
  content.remainingFavsNumber = widgets:NoPointsLabel(content, nil, "...")
  content.remainingFavsNumber:SetPoint("LEFT", content.remainingNumber, "RIGHT", 3, 0)
  content.remainingFavsNumber:SetFontObject("GameFontNormalLarge")

  -- help button
  content.helpButton = widgets:HelpButton(content)
  content.helpButton:SetPoint("TOPRIGHT", content.title, "TOP", 140, -25)
  content.helpButton:SetScript("OnClick", function()
    SlashCmdList.NysTDL(L["info"])
    tutorialsManager:Validate("getMoreInfo") -- tutorial
  end)

  tutorialsManager:SetPoint("getMoreInfo", "LEFT", content.helpButton, "RIGHT", 18, 0)

  -- frame options menu button
  content.frameOptionsButton = widgets:IconButton(content, "NysTDL_FrameOptionsButton", L["Frame options"])
  content.frameOptionsButton:SetPoint("RIGHT", content.helpButton, "LEFT", 2, 0)
  content.frameOptionsButton:SetScript("OnClick", function()
    menuClick(enums.menus.frameopt)
  end)

  tutorialsManager:SetPoint("accessOptions", "BOTTOM", content.frameOptionsButton, "TOP", 0, 18)

  -- category menu button
  content.categoryButton = widgets:IconButton(content, "NysTDL_CategoryButton", L["Add a category"])
  content.categoryButton:SetPoint("RIGHT", content.frameOptionsButton, "LEFT", 2, 0)
  content.categoryButton:SetScript("OnClick", function()
    menuClick(enums.menus.addcat)
  end)

  tutorialsManager:SetPoint("addNewCat", "TOP", content.categoryButton, "BOTTOM", 0, -18)

  -- undo button
  content.undoButton = widgets:IconButton(content, "NysTDL_UndoButton", L["Undo last remove/clear"])
  content.undoButton:SetPoint("RIGHT", content.helpButton, "LEFT", 2, 0)
  content.undoButton:SetScript("OnClick", function() dataManager:Undo() end)
  content.undoButton:Hide()

  -- tab actions menu button
  content.tabActionsButton = widgets:IconButton(content, "NysTDL_TabActionsButton", L["Tab actions"])
  content.tabActionsButton:SetPoint("RIGHT", content.undoButton, "LEFT", 2, 0)
  content.tabActionsButton:SetScript("OnClick", function()
    menuClick(enums.menus.tabact)
  end)
  content.tabActionsButton:Hide()

  -- // menus
  local contentWidth, menuEnum = content:GetWidth()
  content.menuFrames = {
    -- these will be replaced in the code,
    -- but i'm putting them here just so i can remember how this table works
    selected = nil,
    -- selected = enums.menus.xxx,
    -- [enums.menus.xxx] = frame,
    -- [enums.menus.xxx] = frame,
    -- [enums.menus.xxx] = frame,
  }

  -- / add a category sub-menu

  menuEnum = enums.menus.addcat
  content.menuFrames[menuEnum] = CreateFrame("Frame", nil, tdlFrame.content)
  content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, -78)
  content.menuFrames[menuEnum]:SetSize(contentWidth, 110) -- CVAL (coded value, non automatic)
  -- content.menuFrames[menuEnum]:SetHeight(300)
  -- content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, -70)
  -- content.menuFrames[menuEnum]:SetPoint("BOTTOMRIGHT", tdlFrame.content.title, "TOPLEFT", 200, -140)

  generateMenuAddACategory()

  -- / frame options sub-menu

  menuEnum = enums.menus.frameopt
  content.menuFrames[menuEnum] = CreateFrame("Frame", nil, tdlFrame.content)
  content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, -78)
  content.menuFrames[menuEnum]:SetSize(contentWidth, 260) -- CVAL

  generateMenuFrameOptions()

  -- / tab actions sub-menu

  menuEnum = enums.menus.tabact
  content.menuFrames[menuEnum] = CreateFrame("Frame", nil, tdlFrame.content)
  content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, -78)
  content.menuFrames[menuEnum]:SetSize(contentWidth, 160) -- CVAL

  generateMenuTabActions()

  -- below the menus
  content.lineBottom = widgets:ThemeLine(content, database.themes.theme, 0.7)

  content.nothingLabel = widgets:NothingLabel(content)
  content.nothingLabel:SetPoint("TOP", content.lineBottom, "TOP", 0, -20)

  content.dummyFrame = widgets:Dummy(content, content.lineBottom, 0, 0)
  content.dummyFrame:SetPoint("TOPLEFT", content.lineBottom, "TOPLEFT", -30, -30) -- TODO redo?
end

-- // Creating the main frame

function mainFrame:CreateTDLFrame()
  -- TODO temp
  -- profile
  mainFrame.tabSelect = CreateFrame("FRAME", nil, UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(mainFrame.tabSelect, 90)
  UIDropDownMenu_SetText(mainFrame.tabSelect, select(3, dataManager:Find(database.ctab())).name)

  -- Implement the function to change the weekly reset day, then refresh
  local function setTab(self, tabID)
    mainFrame:ChangeTab(tabID)
    UIDropDownMenu_SetText(mainFrame.tabSelect, select(3, dataManager:Find(database.ctab())).name) -- Update the text
  end

  -- Create and bind the initialization function to the dropdown menu
  UIDropDownMenu_Initialize(mainFrame.tabSelect, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()

    local tabsList = select(3, dataManager:GetData())
    for _, tabID in ipairs(tabsList.orderedTabIDs) do
      info.func = setTab
      info.arg1 = tabID
      info.text = select(3, dataManager:Find(tabID)).name
      info.checked = database.ctab() == info.arg1
      UIDropDownMenu_AddButton(info)
    end
  end)
  mainFrame.tabSelect:SetPoint("CENTER", UIParent, "CENTER", 0, 450)

  -- global
  mainFrame.tabSelectGlobal = CreateFrame("FRAME", nil, UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(mainFrame.tabSelectGlobal, 90)
  UIDropDownMenu_SetText(mainFrame.tabSelectGlobal, select(3, dataManager:Find(database.ctab())).name)

  -- Implement the function to change the weekly reset day, then refresh
  local function setTab2(self, tabID)
    mainFrame:ChangeTab(tabID)
    UIDropDownMenu_SetText(mainFrame.tabSelectGlobal, select(3, dataManager:Find(database.ctab())).name) -- Update the text
  end

  -- Create and bind the initialization function to the dropdown menu
  UIDropDownMenu_Initialize(mainFrame.tabSelectGlobal, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()

    local tabsList = select(3, dataManager:GetData(true))
    for _, tabID in ipairs(tabsList.orderedTabIDs) do
      info.func = setTab2
      info.arg1 = tabID
      info.text = select(3, dataManager:Find(tabID)).name
      info.checked = database.ctab() == info.arg1
      UIDropDownMenu_AddButton(info)
    end
  end)
  mainFrame.tabSelectGlobal:SetPoint("CENTER", UIParent, "CENTER", 0, 400)
  -- local btn = CreateFrame("Frame", nil, UIParent, "LargeUIDropDownMenuTemplate")
  -- btn:SetPoint("CENTER")
  -- UIDropDownMenu_SetWidth(btn, 200)
  -- do return end

  ctab = database.ctab -- alias

  -- we create the list
  tdlFrame = CreateFrame("Frame", "NysTDL_ToDoListFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

  -- background
  tdlFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 1, edgeSize = 10,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })

  tutorialsManager:SetPoint("ALTkey", "BOTTOM", tdlFrame, "TOP", 0, 18)

  -- properties
  tdlFrame:EnableMouse(true)
  tdlFrame:SetMovable(true)
  tdlFrame:SetClampedToScreen(true)
  tdlFrame:SetResizable(true)
  tdlFrame:SetMinResize(240, 284)
  tdlFrame:SetMaxResize(600, 1000)
  tdlFrame:SetToplevel(true)
  -- widgets:SetHyperlinksEnabled(tdlFrame, true)

  tdlFrame:HookScript("OnUpdate", mainFrame.Event_TDLFrame_OnUpdate)
  tdlFrame:HookScript("OnShow", mainFrame.Event_TDLFrame_OnVisibilityUpdate)
  tdlFrame:HookScript("OnHide", mainFrame.Event_TDLFrame_OnVisibilityUpdate)
  tdlFrame:HookScript("OnSizeChanged", mainFrame.Event_TDLFrame_OnSizeChanged)

  -- to move the frame AND NOT HAVE THE PRB WITH THE RESIZE so it's custom moving
  tdlFrame.isMouseDown = false
  tdlFrame.hasMoved = false
  local function StopMoving(self)
    self.isMouseDown = false
    if (self.hasMoved == true) then
      self:StopMovingOrSizing()
      self.hasMoved = false
      local points, _ = NysTDL.db.profile.framePos, nil
      points.point, _, points.relativePoint, points.xOffset, points.yOffset = self:GetPoint()
    end
  end
  tdlFrame:HookScript("OnMouseDown", function(self, button)
    if (not NysTDL.db.profile.lockList) then
      if (button == "LeftButton") then
        self.isMouseDown = true
        cursorX, cursorY = GetCursorPosition()
      end
    end
  end)
  tdlFrame:HookScript("OnMouseUp", StopMoving)
  tdlFrame:HookScript("OnHide", StopMoving)

  -- // CREATING THE CONTENT OF THE FRAME // --

  -- // scroll frame (almost everything will be inside of it using a scroll child frame, see generateFrameContent())

  tdlFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, tdlFrame, "UIPanelScrollFrameTemplate")
  tdlFrame.ScrollFrame:SetPoint("TOPLEFT", tdlFrame, "TOPLEFT", 4, - 4)
  tdlFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", - 4, 4)
  tdlFrame.ScrollFrame:SetScript("OnMouseWheel", mainFrame.Event_ScrollFrame_OnMouseWheel)
  tdlFrame.ScrollFrame:SetClipsChildren(true)

  -- // outside the scroll frame

  -- scroll bar
  tdlFrame.ScrollFrame.ScrollBar:ClearAllPoints()
  tdlFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", tdlFrame.ScrollFrame, "TOPRIGHT", - 12, - 38) -- the bottomright is updated in the OnUpdate (to manage the resize button)

  -- close button
  tdlFrame.closeButton = CreateFrame("Button", "closeButton", tdlFrame, "NysTDL_CloseButton")
  tdlFrame.closeButton:SetPoint("TOPRIGHT", tdlFrame, "TOPRIGHT", -1, -1)
  tdlFrame.closeButton:SetScript("onClick", function(self) self:GetParent():Hide() end)

  -- resize button
  tdlFrame.resizeButton = CreateFrame("Button", nil, tdlFrame, "NysTDL_TooltipResizeButton")
  tdlFrame.resizeButton.tooltip = L["Left click - resize"].."\n"..L["Right click - reset"]
  tdlFrame.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
  tdlFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
    if (button == "LeftButton") then
      tdlFrame:StartSizing("BOTTOMRIGHT")
      self:GetHighlightTexture():Hide() -- more noticeable
      self.MiniTooltip:Hide()
    end
  end)
  tdlFrame.resizeButton:SetScript("OnMouseUp", function(self, button)
    if (button == "LeftButton") then
      tdlFrame:StopMovingOrSizing()
      self:GetHighlightTexture():Show()
      self.MiniTooltip:Show()
    end
  end)
  tdlFrame.resizeButton:SetScript("OnHide", function(self)  -- same as on mouse up, just security
    tdlFrame:StopMovingOrSizing()
    self:GetHighlightTexture():Show()
  end)
  tdlFrame.resizeButton:RegisterForClicks("RightButtonUp")
  tdlFrame.resizeButton:HookScript("OnClick", function() -- reset size
    tdlFrame:SetSize(enums.tdlFrameDefaultWidth, enums.tdlFrameDefaultHeight)
  end)

  -- // inside the scroll frame

  generateFrameContent()

  -- // LOADING THE FRAME // --

  -- Initializing the frame with the current saved data
  mainFrame:Init()
end

-- // Profile init & change

function mainFrame:Init()
  -- // this func reloads the entire frame with the current database

  -- / first we reset everything that is loadable

  -- we delete and hide each widget
  for ID in pairs(contentWidgets) do
    mainFrame:DeleteWidget(ID)
  end

  -- then reset every content variable to their default value
  dontRefreshPls = 0
  wipe(contentWidgets)

  -- / now for the frame, we start by setting everything to the saved variables

  -- we resize and scale the frame
  tdlFrame:SetSize(NysTDL.db.profile.frameSize.width, NysTDL.db.profile.frameSize.height)

  -- we reposition the frame
  local points = NysTDL.db.profile.framePos
  tdlFrame:ClearAllPoints()
  tdlFrame:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen

  -- and update its elements opacity
  mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.db.profile.frameAlpha)
  mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.db.profile.frameContentAlpha)
  -- as well as updating the elements needing an update
  local frameopt = tdlFrame.content.menuFrames[enums.menus.frameopt]
  frameopt.frameAlphaSlider:SetValue(NysTDL.db.profile.frameAlpha)
  frameopt.frameContentAlphaSlider:SetValue(NysTDL.db.profile.frameContentAlpha)
  frameopt.affectDesc:SetChecked(NysTDL.db.profile.affectDesc)

  -- we generate the widgets once
  loadWidgets()

  --widgets:SetEditBoxesHyperlinksEnabled(true) -- see func details for why i'm not using it

  -- // and finally, we update the list's visibility

  local oldShownState = tdlFrame:IsShown()

  if NysTDL.db.profile.openByDefault then
    tdlFrame:Show()
  elseif NysTDL.db.profile.keepOpen then
    tdlFrame:SetShown(NysTDL.db.profile.lastListVisibility)
  else
    tdlFrame:Hide()
  end

  if oldShownState == tdlFrame:IsShown() then -- if we didn't change the list's shown state, we manually call Event_TDLFrame_OnVisibilityUpdate to refresh everything
    mainFrame:Event_TDLFrame_OnVisibilityUpdate()
  end
end
