-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local autoReset = addonTable.autoReset
local itemsFrame = addonTable.itemsFrame
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L
local LDD = core.LDD

local tdlFrame, tdlButton
local AllTab, DailyTab, WeeklyTab, CurrentTab

-- reset variables
local clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true}
local movingItem, movingCategory = false, false
local dontReloadPls = false

local checkBtn = {}
local removeBtn = {}
local favoriteBtn = {}
local descBtn = {}
local descFrames = {}
local label = {}
local editBox = {}
local categoryLabelFavsRemaining = {}
local addACategoryClosed = true
local tabActionsClosed = true
local optionsClosed = true
local autoResetedThisSession = false

-- these are for code comfort (sort of)

-- other
local shownInTab = {}
local hyperlinkEditBoxes = {}
local addACategoryItems = {}
local tabActionsItems = {}
local frameOptionsItems = {}
local currentDBItemsList
local categoryNameWidthMax = 220
local itemNameWidthMax = 240
local centerXOffset = 165
local lineOffset = 120
local descFrameLevelDiff = 20
local cursorX, cursorY, cursorDist = 0, 0, 10 -- for my special drag

local updateRate = 0.05
local refreshRate = 1

--------------------------------------
-- General functions
--------------------------------------

function itemsFrame:GetFrame()
  return tdlFrame
end

function itemsFrame:Toggle()
  -- changes the visibility of the ToDoList frame

  -- We also update the frame if we are about to show it
  if (not tdlFrame:IsShown()) then itemsFrame:Update() end

  tdlFrame:SetShown(not tdlFrame:IsShown())
end

function itemsFrame:ReloadTab(tabGlobalWidgetName)
  NysTDL.db.profile.lastLoadedTab = tabGlobalWidgetName or NysTDL.db.profile.lastLoadedTab

  if (dontReloadPls) then
    dontReloadPls = false
    return
  end

  -- // ************************************************************* // --

  if ((not undoing["clear"] and not undoing["single"]) and NysTDL.db.profile.deleteAllTabItems) then -- OPTION: delete checked 'All' tab items
    for catName, items in pairs(NysTDL.db.profile.itemsList) do -- for every item
      for itemName, data in pairs(items) do
        if (data.tabName == "All") then
          if (data.checked) then
            dontReloadPls = true
            itemsFrame:RemoveItem(removeBtn[catName][itemName])
          end
        end
      end
    end
  end

  itemsFrame:SetActiveTab(_G[NysTDL.db.profile.lastLoadedTab])
end

function NysTDL:EditBoxInsertLink(text)
  -- when we shift-click on things, we hook the link from the chat function,
  -- and add it to the one of my edit boxes who has the focus (if there is one)
  -- basically, it's what allow hyperlinks in my addon edit boxes
  for _, v in pairs(hyperlinkEditBoxes) do
		if v and v:IsVisible() and v:HasFocus() then
			v:Insert(text)
			return true
		end
	end
end

local function ItemIsInTab(itemTabName, tabName)
  return ((tabName == "All" and not NysTDL.db.profile.showOnlyAllTabItems) or itemTabName == tabName)
end

local function ItemIsHiddenInResetTab(catName, itemName)
  local checked = NysTDL.db.profile.itemsList[catName][itemName].checked
  local itemTabName = NysTDL.db.profile.itemsList[catName][itemName].tabName

  if (checked) then
    -- if it's a checked daily item and we have to hide these, same for weekly
    if ((NysTDL.db.profile.hideDailyTabItems and itemTabName == "Daily")
    or (NysTDL.db.profile.hideWeeklyTabItems and itemTabName == "Weekly")) then
      return true
    end
  end

  return false
end

function itemsFrame:GetCategoriesOrdered()
  -- returns a table containing the name of every category there is, ordered
  local categories = {}

  for category in pairs(NysTDL.db.profile.itemsList) do table.insert(categories, category) end
  table.sort(categories)

  return categories
end

-- actions
local function ScrollFrame_OnMouseWheel(self, delta)
  -- defines how fast we can scroll throught the tabs (here: 30)
  local newValue = self:GetVerticalScroll() - (delta * 30)

  if (newValue < 0) then
    newValue = 0
  elseif (newValue > self:GetVerticalScrollRange()) then
    newValue = self:GetVerticalScrollRange()
  end

  self:SetVerticalScroll(newValue)
end

local function FrameAlphaSlider_OnValueChanged(_, value)
  -- itemsList frame part
  NysTDL.db.profile.frameAlpha = value
  tdlFrame.frameAlphaSliderValue:SetText(value)
  tdlFrame:SetBackdropColor(0, 0, 0, value/100)
  tdlFrame:SetBackdropBorderColor(1, 1, 1, value/100)
  for i = 1, 3 do
    _G["ToDoListUIFrameTab"..i.."Left"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i.."LeftDisabled"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i.."Middle"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i.."MiddleDisabled"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i.."Right"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i.."RightDisabled"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i.."HighlightTexture"]:SetAlpha((value)/100)
  end

  -- description frames part
  if (NysTDL.db.profile.affectDesc) then
    NysTDL.db.profile.descFrameAlpha = value
  end

  value = NysTDL.db.profile.descFrameAlpha

  for _, v in pairs(descFrames) do
    v:SetBackdropColor(0, 0, 0, value/100)
    v:SetBackdropBorderColor(1, 1, 1, value/100)
    for k, x in pairs(v.descriptionEditBox) do
      if (type(k) == "string") then
        if (string.sub(k, k:len()-2, k:len()) == "Tex") then
          x:SetAlpha(value/100)
        end
      end
    end
  end
end

local function FrameContentAlphaSlider_OnValueChanged(_, value)
  -- itemsList frame part
  NysTDL.db.profile.frameContentAlpha = value
  tdlFrame.frameContentAlphaSliderValue:SetText(value)
  tdlFrame.ScrollFrame.ScrollBar:SetAlpha((value)/100)
  tdlFrame.closeButton:SetAlpha((value)/100)
  tdlFrame.resizeButton:SetAlpha((value)/100)
  for i = 1, 3 do
    _G["ToDoListUIFrameTab"..i.."Text"]:SetAlpha((value)/100)
    _G["ToDoListUIFrameTab"..i].content:SetAlpha((value)/100)
  end

  -- description frames part
  if (NysTDL.db.profile.affectDesc) then
    NysTDL.db.profile.descFrameContentAlpha = value
  end

  value = NysTDL.db.profile.descFrameContentAlpha

  for _, v in pairs(descFrames) do
    v.closeButton:SetAlpha(value/100)
    v.clearButton:SetAlpha(value/100)
    -- the title is already being cared for in the update of the desc frame
    v.descriptionEditBox.EditBox:SetAlpha(value/100)
    v.descriptionEditBox.ScrollBar:SetAlpha(value/100)
    v.resizeButton:SetAlpha(value/100)
  end
end

local function SetFocusEditBox(editBox) -- DRY
  editBox:SetFocus()
  if (NysTDL.db.profile.highlightOnFocus) then
    editBox:HighlightText()
  else
    editBox:HighlightText(0, 0)
  end
end

-- frame functions
function itemsFrame:ResetBtns(tabName, auto)
  -- this function's goal is to reset (uncheck) every item in the given tab
  -- "auto" is to differenciate the user pressing the uncheck button and the auto reset
  local uncheckedSomething = false

  for catName, items in pairs(NysTDL.db.profile.itemsList) do -- for every check buttons
    for itemName, data in pairs(items) do
      if (ItemIsInTab(data.tabName, tabName)) then -- if it is in the selected tab
        if (checkBtn[catName][itemName]:GetChecked()) then
          uncheckedSomething = true
        end

        checkBtn[catName][itemName]:SetChecked(false) -- we uncheck it
        checkBtn[catName][itemName]:GetScript("OnClick")(checkBtn[catName][itemName]) -- and call its click handler so that it can do its things and update correctly
      end
    end
  end

  if (uncheckedSomething) then -- so that we print this message only if there was checked items before the uncheck
    if (tabName == "All") then
      chat:Print(L["Unchecked everything!"])
    else
      chat:Print(utils:SafeStringFormat(L["Unchecked %s tab!"], L[tabName]))
    end
    itemsFrame:ReloadTab()
  elseif (not auto) then -- we print this message only if it was the user's action that triggered this function (not the auto reset)
    chat:Print(L["Nothing to uncheck here!"])
  end
end

function itemsFrame:CheckBtns(tabName)
  -- this function's goal is to check every item in the selected tab
  local checkedSomething = false

  for catName, items in pairs(NysTDL.db.profile.itemsList) do -- for every item
    for itemName, data in pairs(items) do
      if (ItemIsInTab(data.tabName, tabName)) then -- if it is in the selected tab
        if (not checkBtn[catName][itemName]:GetChecked()) then
          checkedSomething = true
        end

        checkBtn[catName][itemName]:SetChecked(true) -- we check it, and the OnValueChanged will update the frame
        checkBtn[catName][itemName]:GetScript("OnClick")(checkBtn[catName][itemName]) -- and call its click handler so that it can do its things and update correctly
    end
    end
  end

  if (checkedSomething) then -- so that we print this message only if there was checked items before the uncheck
    if (tabName == "All") then
      chat:Print(L["Checked everything!"])
    else
      chat:Print(utils:SafeStringFormat(L["Checked %s tab!"], L[tabName]))
    end
    itemsFrame:ReloadTab()
  else
    chat:Print(L["Nothing to check here!"])
  end
end

function itemsFrame:updateFavsRemainingNumbersColor()
  -- this updates the favorite color for every favorites remaining number label
  tdlFrame.remainingFavsNumber:SetTextColor(unpack(NysTDL.db.profile.favoritesColor))
  for catName in pairs(label) do -- for every category labels
    categoryLabelFavsRemaining[catName]:SetTextColor(unpack(NysTDL.db.profile.favoritesColor))
  end
end

local T_updateRemainingNumbers_1 = {}
local T_updateRemainingNumbers_2 = {}
local T_updateRemainingNumbers_3 = {}
local T_updateRemainingNumbers_4 = {}
function itemsFrame:updateRemainingNumbers()
  -- we get how many things there is left to do in every tab,
  -- it's the big important function that gives us every number, checked and unchecked, favs or not

  -- // this function is a bit horrible, but i'm planning to redo it entirely in the future when i'll want to look into sub-categories,
  -- but it does the job for now

  local tab = tdlFrame.remainingNumber:GetParent()

  local numberCheckedAll, numberCheckedDaily, numberCheckedWeekly = 0, 0, 0
  local numberCheckedFavAll, numberCheckedFavDaily, numberCheckedFavWeekly = 0, 0, 0
  local numberUncheckedAll, numberUncheckedDaily, numberUncheckedWeekly = 0, 0, 0
  local numberUncheckedFavAll, numberUncheckedFavDaily, numberUncheckedFavWeekly = 0, 0, 0
  for _, items in pairs(NysTDL.db.profile.itemsList) do -- for every item
    for _, data in pairs(items) do
      -- All tab
      if (ItemIsInTab(data.tabName, "All")) then
        if (data.checked) then
          numberCheckedAll = numberCheckedAll + 1 -- then it's one more done
          if (data.favorite) then -- and we check for the favorite state too
            numberCheckedFavAll = numberCheckedFavAll + 1
          end
        else
          numberUncheckedAll = numberUncheckedAll + 1
          if (data.favorite) then
            numberUncheckedFavAll = numberUncheckedFavAll + 1
          end
        end
      end
      -- Daily tab
      if (ItemIsInTab(data.tabName, "Daily")) then
        if (data.checked) then
          numberCheckedDaily = numberCheckedDaily + 1
          if (data.favorite) then
            numberCheckedFavDaily = numberCheckedFavDaily + 1
          end
        else
          numberUncheckedDaily = numberUncheckedDaily + 1
          if (data.favorite) then
            numberUncheckedFavDaily = numberUncheckedFavDaily + 1
          end
        end
      end
      -- Weekly tab
      if (ItemIsInTab(data.tabName, "Weekly")) then
        if (data.checked) then
          numberCheckedWeekly = numberCheckedWeekly + 1
          if (data.favorite) then
            numberCheckedFavWeekly = numberCheckedFavWeekly + 1
          end
        else
          numberUncheckedWeekly = numberUncheckedWeekly + 1
          if (data.favorite) then
            numberUncheckedFavWeekly = numberUncheckedFavWeekly + 1
          end
        end
      end
    end
  end

  -- we update the numbers of remaining things to do for the current tab
  if (tab == AllTab) then
    tdlFrame.remainingNumber:SetText(((numberUncheckedAll > 0) and "|cffffffff" or "|cff00ff00")..numberUncheckedAll.."|r")
    tdlFrame.remainingFavsNumber:SetText(((numberUncheckedFavAll > 0) and "("..numberUncheckedFavAll..")" or ""))
  elseif (tab == DailyTab) then
    tdlFrame.remainingNumber:SetText(((numberUncheckedDaily > 0) and "|cffffffff" or "|cff00ff00")..numberUncheckedDaily.."|r")
    tdlFrame.remainingFavsNumber:SetText(((numberUncheckedFavDaily > 0) and "("..numberUncheckedFavDaily..")" or ""))
  elseif (tab == WeeklyTab) then
    tdlFrame.remainingNumber:SetText(((numberUncheckedWeekly > 0) and "|cffffffff" or "|cff00ff00")..numberUncheckedWeekly.."|r")
    tdlFrame.remainingFavsNumber:SetText(((numberUncheckedFavWeekly > 0) and "("..numberUncheckedFavWeekly..")" or ""))
  end

  -- same for the category label ones
  for catName in pairs(label) do -- for every category labels
    local nbFavCat = 0
    for _, data in pairs(NysTDL.db.profile.itemsList[catName]) do -- and for every items in them
      if (ItemIsInTab(data.tabName, tab:GetName())) then -- if the current loop item is in the tab we're on
        if (data.favorite) then -- and it's a favorite
          if (not data.checked) then -- and it's not checked
            nbFavCat = nbFavCat + 1 -- then it's one more remaining favorite hidden in the closed category
          end
        end
      end
    end
    categoryLabelFavsRemaining[catName]:SetText((nbFavCat > 0) and "("..nbFavCat..")" or "")
  end

  -- we also update the favs colors
  itemsFrame:updateFavsRemainingNumbersColor()

  -- TDL button red option
  itemsFrame.tdlButton:SetNormalFontObject("GameFontNormalLarge") -- by default, we reset the color of the TDL button to yellow
  if (NysTDL.db.profile.tdlButton.red) then -- we check here if we need to color it red here
    local red = false
    -- we first check if there are daily remaining items
    if (numberUncheckedDaily > 0) then
      if ((NysTDL.db.profile.autoReset["Daily"] - time()) < 86400) then -- pretty much all the time
        red = true
      end
    end

    -- then we check if there are weekly remaining items
    if (numberUncheckedWeekly > 0) then
      if ((NysTDL.db.profile.autoReset["Weekly"] - time()) < 86400) then -- if there is less than one day left before the weekly reset
        red = true
      end
    end

    if (red) then
      local font = itemsFrame.tdlButton:GetNormalFontObject()
      if (font) then
        font:SetTextColor(1, 0, 0, 1) -- red
        itemsFrame.tdlButton:SetNormalFontObject(font)
      end
    end
  end

  -- and finally we put our variables in tables so they are easier to access on the other end
  wipe(T_updateRemainingNumbers_1)
  wipe(T_updateRemainingNumbers_2)
  wipe(T_updateRemainingNumbers_3)
  wipe(T_updateRemainingNumbers_4)
  local checked = T_updateRemainingNumbers_1
  checked.All = numberCheckedAll
  checked.Daily = numberCheckedDaily
  checked.Weekly = numberCheckedWeekly
  local checkedFavs = T_updateRemainingNumbers_2
  checkedFavs.All = numberCheckedFavAll
  checkedFavs.Daily = numberCheckedFavDaily
  checkedFavs.Weekly = numberCheckedFavWeekly
  local unchecked = T_updateRemainingNumbers_3
  unchecked.All = numberUncheckedAll
  unchecked.Daily = numberUncheckedDaily
  unchecked.Weekly = numberUncheckedWeekly
  local uncheckedFavs = T_updateRemainingNumbers_4
  uncheckedFavs.All = numberUncheckedFavAll
  uncheckedFavs.Daily = numberUncheckedFavDaily
  uncheckedFavs.Weekly = numberUncheckedFavWeekly
  return checked, checkedFavs, unchecked, uncheckedFavs -- and we return them, so that we can access it eg. in the favorites warning function
end

function itemsFrame:updateCheckButtonsColor()
  for catName, items in pairs(NysTDL.db.profile.itemsList) do -- for every check buttons
    for itemName, data in pairs(items) do
      -- we color them in a color corresponding to their checked state
      if (checkBtn[catName][itemName]:GetChecked()) then
        checkBtn[catName][itemName].InteractiveLabel.Text:SetTextColor(0, 1, 0)
      else
        if (data.favorite) then
          checkBtn[catName][itemName].InteractiveLabel.Text:SetTextColor(unpack(NysTDL.db.profile.favoritesColor))
        else
          checkBtn[catName][itemName].InteractiveLabel.Text:SetTextColor(unpack(utils:ThemeDownTo01(database.themes.theme_yellow)))
        end
      end
    end
  end
end


--/***************/ EVENTS /******************/--

local function ItemsFrame_OnVisibilityUpdate()
  -- things to do when we hide/show the list
  addACategoryClosed = true
  tabActionsClosed = true
  optionsClosed = true
  itemsFrame:ReloadTab()
  NysTDL.db.profile.lastListVisibility = tdlFrame:IsShown()
end

local function ItemsFrame_Scale()
  local scale = tdlFrame:GetWidth()/340
  tdlFrame.ScrollFrame.ScrollBar:SetScale(scale)
  tdlFrame.closeButton:SetScale(scale)
  tdlFrame.resizeButton:SetScale(scale)
  for i = 1, 3 do
    _G["ToDoListUIFrameTab"..i].content:SetScale(scale)
    _G["ToDoListUIFrameTab"..i]:SetScale(scale)
  end
  tutorialsManager:SetFramesScale(scale)
end

local T_ItemsFrame_OnUpdate = {
  other = function(self, x) -- returns true if an other argument than the given one or 'nothing' is true
    for k,v in pairs(self) do
      if (type(v) == "boolean") then
        if ((k ~= "nothing") and (k ~= x) and v) then
          return true
        end
      end
    end
    return false
  end,
  something = function(self, x) -- sets to true only the given argument, while falsing every other
    for k,v in pairs(self) do
      if (type(v) == "boolean") then
        self[k] = false
      end
    end
    self[x] = true
  end,
  nothing = false,
  shift = false,
  ctrl = false,
  alt = false,
} -- this is to only update once the things concerned by the special key inputs instead of every frame
local function ItemsFrame_OnUpdate(self, elapsed)
  -- called every frame
  self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
  self.timeSinceLastRefresh = self.timeSinceLastRefresh + elapsed

  -- if (self:IsMouseOver()) then
  --   tdlFrame.ScrollFrame.ScrollBar:Show()
  -- else
  --   tdlFrame.ScrollFrame.ScrollBar:Hide()
  -- end

  -- dragging
  if (self.isMouseDown and not self.hasMoved) then
    local x, y = GetCursorPosition()
    if ((x > cursorX + cursorDist) or (x < cursorX - cursorDist) or (y > cursorY + cursorDist) or (y < cursorY - cursorDist)) then  -- we start dragging the frame
      self:StartMoving()
      self.hasMoved = true
    end
  end

  if (true) then -- for ez CPU testing
    -- testing and showing the right buttons depending on our inputs
    if IsAltKeyDown() and not T_ItemsFrame_OnUpdate:other("alt") then
      if (not T_ItemsFrame_OnUpdate.alt) then
        T_ItemsFrame_OnUpdate:something("alt")

        tutorialsManager:Validate("ALTkey") -- tutorial
        -- we switch the category and frame options buttons for the undo and frame action ones and vice versa
        tdlFrame.categoryButton:Hide()
        tdlFrame.undoButton:Show()
        tdlFrame.frameOptionsButton:Hide()
        tdlFrame.tabActionsButton:Show()
        -- resize button
        tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame.ScrollFrame, "BOTTOMRIGHT", - 7, 32)
        tdlFrame.resizeButton:Show()
      end
    elseif IsShiftKeyDown() and not T_ItemsFrame_OnUpdate:other("shift") then
      if (not T_ItemsFrame_OnUpdate.shift) then
        T_ItemsFrame_OnUpdate:something("shift")

        for catName, items in pairs(NysTDL.db.profile.itemsList) do
          for itemName in pairs(items) do
            -- we show every star icons
            removeBtn[catName][itemName]:Hide()
            descBtn[catName][itemName]:Hide()
            favoriteBtn[catName][itemName]:Show()
          end
        end
      end
    elseif IsControlKeyDown() and not T_ItemsFrame_OnUpdate:other("ctrl") then
      if (not T_ItemsFrame_OnUpdate.ctrl) then
        T_ItemsFrame_OnUpdate:something("ctrl")

        for catName, items in pairs(NysTDL.db.profile.itemsList) do
          for itemName in pairs(items) do
            -- we show every paper icons
            removeBtn[catName][itemName]:Hide()
            favoriteBtn[catName][itemName]:Hide()
            descBtn[catName][itemName]:Show()
          end
        end
      end
    elseif (not T_ItemsFrame_OnUpdate.nothing) then
      T_ItemsFrame_OnUpdate:something("nothing")

      -- item icons
      for catName, items in pairs(NysTDL.db.profile.itemsList) do
        for itemName in pairs(items) do
          itemsFrame:UpdateItemButtons(catName, itemName)
        end
      end

      -- buttons
      tdlFrame.undoButton:Hide()
      tdlFrame.categoryButton:Show()
      tdlFrame.tabActionsButton:Hide()
      tdlFrame.frameOptionsButton:Show()
      -- resize button
      tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame.ScrollFrame, "BOTTOMRIGHT", - 7, 17)
      tdlFrame.resizeButton:Hide()
    end
  end

  if (true) then -- same
    -- we also update their color, if one of the button menus is opened
    tdlFrame.categoryButton.Icon:SetDesaturated(nil) tdlFrame.categoryButton.Icon:SetVertexColor(0.85, 1, 1) -- here we change the vertex color because the original icon is a bit reddish
    tdlFrame.frameOptionsButton.Icon:SetDesaturated(nil)
    tdlFrame.tabActionsButton.Icon:SetDesaturated(nil)
    if (not addACategoryClosed) then
      tdlFrame.categoryButton.Icon:SetDesaturated(1) tdlFrame.categoryButton.Icon:SetVertexColor(1, 1, 1)
    elseif (not optionsClosed) then
      tdlFrame.frameOptionsButton.Icon:SetDesaturated(1)
    elseif (not tabActionsClosed) then
      tdlFrame.tabActionsButton.Icon:SetDesaturated(1)
    end
  end

  tutorialsManager:UpdateFramesVisibility()

  while (self.timeSinceLastUpdate > updateRate) do -- every 0.05 sec (instead of every frame which is every 1/144 (0.007) sec for a 144hz display... optimization :D)
    if (NysTDL.db.profile.rainbow) then
      itemsFrame:ApplyNewRainbowColor(NysTDL.db.profile.rainbowSpeed)
    end
    self.timeSinceLastUpdate = self.timeSinceLastUpdate - updateRate
  end

  while (self.timeSinceLastRefresh > refreshRate) do -- every one second
    itemsFrame:checkAutoReset()
    self.timeSinceLastRefresh = self.timeSinceLastRefresh - refreshRate
  end
end

--/***************/ ITEMS, CATEGORIES AND TABS MANAGMENT /******************/--

function itemsFrame:Update()
  -- updates everything about the frame without actually reloading the tab, this is a less intensive version
  itemsFrame:checkAutoReset()
  itemsFrame:updateRemainingNumbers()
  itemsFrame:updateCheckButtonsColor()
end

function itemsFrame:UpdateItemButtons(catName, itemName)
  if (not NysTDL.db.profile.itemsList[catName] or not NysTDL.db.profile.itemsList[catName][itemName]) then return end
  local data = NysTDL.db.profile.itemsList[catName][itemName]
  -- shows the right button at the left of every item
  if (data.description) then
    -- if current item has a description, the paper icon takes the lead
    favoriteBtn[catName][itemName]:Hide()
    removeBtn[catName][itemName]:Hide()
    descBtn[catName][itemName]:Show()
  elseif (data.favorite) then
    -- or else if current item is a favorite
    descBtn[catName][itemName]:Hide()
    removeBtn[catName][itemName]:Hide()
    favoriteBtn[catName][itemName]:Show()
  else
    -- default
    favoriteBtn[catName][itemName]:Hide()
    descBtn[catName][itemName]:Hide()
    removeBtn[catName][itemName]:Show()
  end
end

-- // Automatic reset

function itemsFrame:checkAutoReset()
  if time() > NysTDL.db.profile.autoReset["Weekly"] then
    NysTDL.db.profile.autoReset["Daily"] = autoReset:GetSecondsToReset().daily
    NysTDL.db.profile.autoReset["Weekly"] = autoReset:GetSecondsToReset().weekly
    itemsFrame:ResetBtns("Daily", true)
    itemsFrame:ResetBtns("Weekly", true)
    autoResetedThisSession = true
  elseif time() > NysTDL.db.profile.autoReset["Daily"] then
    NysTDL.db.profile.autoReset["Daily"] = autoReset:GetSecondsToReset().daily
    itemsFrame:ResetBtns("Daily", true)
    autoResetedThisSession = true
  end
end

function itemsFrame:autoResetedThisSessionGET()
  return autoResetedThisSession
end

-- // Some widgets

-- item widget
function itemsFrame:CreateMovableCheckBtnElems(catName, itemName)
  local data = NysTDL.db.profile.itemsList[catName][itemName]

  if (not utils:HasKey(checkBtn, catName)) then checkBtn[catName] = {} end
  checkBtn[catName][itemName] = CreateFrame("CheckButton", "NysTDL_CheckBtn_"..catName.."_"..itemName, tdlFrame, "UICheckButtonTemplate")
  checkBtn[catName][itemName].InteractiveLabel = widgets:NoPointsInteractiveLabel(checkBtn[catName][itemName]:GetName().."_InteractiveLabel", checkBtn[catName][itemName], itemName, "GameFontNormalLarge")
  checkBtn[catName][itemName].InteractiveLabel:SetPoint("LEFT", checkBtn[catName][itemName], "RIGHT")
  checkBtn[catName][itemName].InteractiveLabel.Text:SetPoint("LEFT", checkBtn[catName][itemName], "RIGHT", 20, 0)
  checkBtn[catName][itemName].catName = catName -- easy access to the catName this button is in
  checkBtn[catName][itemName].itemName = itemName -- easy access to the itemName of this button, this also allows the shown text to be different
  if (utils:HasHyperlink(itemName)) then -- this is for making more space for items that have hyperlinks in them
    if (checkBtn[catName][itemName].InteractiveLabel.Text:GetWidth() > itemNameWidthMax) then
      checkBtn[catName][itemName].InteractiveLabel.Text:SetFontObject("GameFontNormal")
    end

    -- and also to deactivate the InteractiveLabel's Button, so that we can actually click on the links
    -- unless we are holding Alt, and to detect this, we actually put on them an OnUpdate script
    checkBtn[catName][itemName].InteractiveLabel:SetScript("OnUpdate", function(self)
      if (IsAltKeyDown()) then
        self.Button:Show()
      else
        self.Button:Hide()
      end
    end)
  end
  checkBtn[catName][itemName]:SetChecked(data.checked)
  checkBtn[catName][itemName]:SetScript("OnClick", function(self)
    data.checked = self:GetChecked()
    if (NysTDL.db.profile.instantRefresh) then
      itemsFrame:ReloadTab()
    else
      itemsFrame:Update()
    end
  end)
  checkBtn[catName][itemName].InteractiveLabel:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
  checkBtn[catName][itemName].InteractiveLabel:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  end)
  checkBtn[catName][itemName].InteractiveLabel.Button:SetScript("OnDoubleClick", function(self)
    -- first, we hide the label
    local checkBtn = self:GetParent():GetParent()
    checkBtn.InteractiveLabel:Hide()

    -- then, we can create the new edit box to rename the item, where the label was
    local catName, itemName = checkBtn.catName, checkBtn.itemName
    local renameEditBox = widgets:NoPointsRenameEditBox(checkBtn, itemName, itemNameWidthMax, self:GetHeight())
    renameEditBox:SetPoint("LEFT", checkBtn, "RIGHT", 5, 0)
    -- renameEditBox:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
    -- renameEditBox:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    --   ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
    -- end)
    table.insert(hyperlinkEditBoxes, renameEditBox) -- so that we can add hyperlinks in it

    -- let's go!
    renameEditBox:SetScript("OnEnterPressed", function(self)
      local newItemName = self:GetText()
      -- first, we do some tests
      if (newItemName == "") then -- if the new item name is empty
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (newItemName == itemName) then -- if the new is the same as the old
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (utils:HasKey(NysTDL.db.profile.itemsList[catName], newItemName)) then -- if the new item name already exists somewhere in the category
        chat:PrintForced(L["This item name already exists in the category"]..". "..L["Please choose a different name to avoid overriding data"])
        return
      else
        local l = widgets:NoPointsLabel(tdlFrame, nil, newItemName)
        if (l:GetWidth() > itemNameWidthMax and utils:HasHyperlink(newItemName)) then l:SetFontObject("GameFontNormal") end -- if it has an hyperlink in it and it's too big, we allow it to be a little longer, considering hyperlinks take more place
        if (l:GetWidth() > itemNameWidthMax) then -- then we recheck to see if the item is not too long for good
          chat:PrintForced(L["This item name is too big!"])
          return
        end
      end

      -- and if everything is good, we can rename the item (a.k.a, delete the current one and creating a new one)
      -- while keeping the same cat, and same tab
      itemsFrame:MoveItem(catName, catName, itemName, newItemName, NysTDL.db.profile.itemsList[catName][itemName].tabName)
    end)

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      self:Hide()
      checkBtn.InteractiveLabel:Show()
      table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, self))) -- removing the ref of the hyperlink edit box
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)
  end)

  if (not utils:HasKey(removeBtn, catName)) then removeBtn[catName] = {} end
  removeBtn[catName][itemName] = widgets:RemoveButton(checkBtn[catName][itemName])
  removeBtn[catName][itemName]:SetScript("OnClick", function(self) itemsFrame:RemoveItem(self) end)

  if (not utils:HasKey(favoriteBtn, catName)) then favoriteBtn[catName] = {} end
  favoriteBtn[catName][itemName] = widgets:FavoriteButton(checkBtn[catName][itemName], catName, itemName)
  favoriteBtn[catName][itemName]:SetScript("OnClick", function(self) itemsFrame:FavoriteClick(self) end)
  favoriteBtn[catName][itemName]:Hide()

  if (not utils:HasKey(descBtn, catName)) then descBtn[catName] = {} end
  descBtn[catName][itemName] = widgets:DescButton(checkBtn[catName][itemName], catName, itemName)
  descBtn[catName][itemName]:SetScript("OnClick", function(self) itemsFrame:DescriptionClick(self) end)
  descBtn[catName][itemName]:Hide()
end

-- category widget
function itemsFrame:CreateMovableLabelElems(catName)
  -- category label
  label[catName] = widgets:NoPointsInteractiveLabel("NysTDL_CatLabel_"..catName, tdlFrame, catName, "GameFontHighlightLarge")
  label[catName].catName = catName -- easy access to the catName of the label, this also allows the shown text to be different
  label[catName].Button:SetScript("OnEnter", function(self)
    local r, g, b = unpack(utils:ThemeDownTo01(database.themes.theme))
    self:GetParent().Text:SetTextColor(r, g, b, 1) -- when we hover it, we color the label
  end)
  label[catName].Button:SetScript("OnLeave", function(self)
    self:GetParent().Text:SetTextColor(1, 1, 1, 1) -- back to the default color
  end)
  label[catName].Button:SetScript("OnClick", function(self, button)
    if (IsAltKeyDown()) then return end -- we don't do any of the OnClick code if we have the Alt key down, bc it means that we want to rename the category by double clicking
    local catName = self:GetParent().catName
    if (button == "LeftButton") then -- we open/close the category
      if (utils:HasKey(NysTDL.db.profile.closedCategories, catName) and NysTDL.db.profile.closedCategories[catName] ~= nil) then -- if this is a category that is closed in certain tabs
        local isPresent, pos = utils:HasValue(NysTDL.db.profile.closedCategories[catName], CurrentTab:GetName()) -- we get if it is closed in the current tab
        if (isPresent) then -- if it is
          table.remove(NysTDL.db.profile.closedCategories[catName], pos) -- then we remove it from the saved variable
          if (#NysTDL.db.profile.closedCategories[catName] == 0) then -- and btw check if it was the only tab remaining where it was closed
            NysTDL.db.profile.closedCategories[catName] = nil -- in which case we nil the table variable for that category
          end
        else  -- if it is opened in the current tab
          table.insert(NysTDL.db.profile.closedCategories[catName], CurrentTab:GetName()) -- then we close it by adding it to the saved variable
        end
      else -- if this category was closed nowhere
        NysTDL.db.profile.closedCategories[catName] = {CurrentTab:GetName()} -- then we create its table variable and initialize it with the current tab (we close the category in the current tab)
      end

      -- and finally, we reload the frame to display the changes
      itemsFrame:ReloadTab()
    elseif (button == "RightButton") then -- we try to toggle the edit box to add new items
      -- if the label we right clicked on is NOT a closed category
      if (not (select(1, utils:HasKey(NysTDL.db.profile.closedCategories, catName))) or not (select(1, utils:HasValue(NysTDL.db.profile.closedCategories[catName], CurrentTab:GetName())))) then
        -- we toggle its edit box
        editBox[catName]:SetShown(not editBox[catName]:IsShown())

        if (editBox[catName]:IsShown()) then
          -- tutorial
          tutorialsManager:Validate("addItem")

          -- we also give that edit box the focus if we are showing it
          SetFocusEditBox(editBox[catName])
        end
      end
    end
  end)
  label[catName].Button:SetScript("OnDoubleClick", function(self)
    if (not IsAltKeyDown()) then return end -- we don't do any of the OnDoubleClick code if we don't have the Alt key down

    -- first, we hide the label
    local label = self:GetParent()
    label.Text:Hide()
    label.Button:Hide()

    -- then, we can create the new edit box to rename the category, where the label was
    local catName = label.catName
    local renameEditBox = widgets:NoPointsRenameEditBox(label, catName, categoryNameWidthMax, self:GetHeight())
    renameEditBox:SetPoint("LEFT", label, "LEFT", 5, 0)

    -- we move the favs remaining label to the right of the edit box while it's shown
    if (utils:HasKey(categoryLabelFavsRemaining, catName)) then
      categoryLabelFavsRemaining[catName]:ClearAllPoints()
      categoryLabelFavsRemaining[catName]:SetPoint("LEFT", renameEditBox, "RIGHT", 6, 0)
    end

    -- let's go!
    renameEditBox:SetScript("OnEnterPressed", function(self)
      local newCatName = self:GetText()
      -- first, we do some tests
      if (newCatName == "") then -- if the new cat name is empty
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (newCatName == catName) then -- if the new is the same as the old
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (utils:HasKey(NysTDL.db.profile.itemsList, newCatName)) then -- if the new cat name already exists
        chat:PrintForced(L["This category name already exists"]..". "..L["Please choose a different name to avoid overriding data"])
        return
      else
        local l = widgets:NoPointsLabel(tdlFrame, nil, newCatName)
        if (l:GetWidth() > categoryNameWidthMax) then -- if the new cat name is too big
          chat:PrintForced(L["This categoty name is too big!"])
          return
        end
      end

      -- and if everything is good, we can rename the category
      itemsFrame:RenameCategory(catName, newCatName)
    end)

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      self:Hide()
      label.Text:Show()
      label.Button:Show()
      -- when hiding the edit box, we reset the pos of the favs remaining label
      if (utils:HasKey(categoryLabelFavsRemaining, catName)) then
        categoryLabelFavsRemaining[catName]:ClearAllPoints()
        categoryLabelFavsRemaining[catName]:SetPoint("LEFT", label, "RIGHT", 6, 0)
      end
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)
  end)

  -- associated favs remaining label
  categoryLabelFavsRemaining[catName] = widgets:NoPointsLabel(label[catName], label[catName]:GetName().."_FavsRemaining", "")

  -- associated edit box and add button
  editBox[catName] = widgets:NoPointsLabelEditBox(catName)
  editBox[catName]:SetScript("OnEnterPressed", function(self)
    itemsFrame:AddItem(self)
    self:Show() -- we keep it shown to add more items
    SetFocusEditBox(self)
  end)
  -- cancelling
  editBox[catName]:SetScript("OnEscapePressed", function(self)
    self:Hide()
  end)
  editBox[catName]:HookScript("OnEditFocusLost", function(self)
    self:GetScript("OnEscapePressed")(self)
  end)
  table.insert(hyperlinkEditBoxes, editBox[catName])
end

-- // Creation and loading of the list's items

-- boom
local function loadCategories(tab, categoryLabel, catName, itemNames, lastData)
  -- here we generate and load each categories and their items one by one

  if (next(itemNames) ~= nil) then -- if for the current category there is at least one item to show in the current tab
    local lastLabel, newLabelHeightDelta, adjustHeight

    -- category label
    if (lastData == nil) then
      lastLabel = tdlFrame.dummyLabel
      newLabelHeightDelta = 0 -- no delta, this is the start point

      -- tutorial
      tutorialsManager:SetTarget("addItem", categoryLabel)
    else
      lastLabel = lastData["categoryLabel"]
      if (utils:HasKey(NysTDL.db.profile.closedCategories, lastData["catName"]) and utils:HasValue(NysTDL.db.profile.closedCategories[lastData["catName"]], tab:GetName())) then -- if the last category loaded was a closed one in this tab
        newLabelHeightDelta = 1 -- we only have a delta of one
      else
        newLabelHeightDelta = #lastData["itemNames"] + 1 -- or else, we have a delta of the number of items loaded in the last category + the last category's label
      end
    end

    -- category label placement
    if (newLabelHeightDelta == 0) then adjustHeight = 0 else adjustHeight = 1 end -- just for a proper clean height
    categoryLabel:SetParent(tab)
    categoryLabel:SetPoint("TOPLEFT", lastLabel, "TOPLEFT", 0, (-newLabelHeightDelta * 22) - (adjustHeight * 5)) -- here
    categoryLabel:Show()

    -- category label favs remaining placement
    -- we determine if it is shown or not later
    categoryLabelFavsRemaining[catName]:SetParent(categoryLabel)
    categoryLabelFavsRemaining[catName]:SetPoint("LEFT", categoryLabel, "RIGHT", 6, 0)

    -- edit box
    editBox[catName]:SetParent(tab)
    -- edit box width (we adapt it based on the category label's width)
    local labelWidth = tonumber(string.format("%i", categoryLabel.Text:GetWidth()))
    local rightPointDistance = 297 -- in alignment with the item renaming edit boxes
    local editBoxAddItemWidth = 150
    if (labelWidth + editBoxAddItemWidth > rightPointDistance) then
      editBox[catName]:SetSize(editBoxAddItemWidth - 10 - ((labelWidth + editBoxAddItemWidth) - rightPointDistance), 30)
      editBox[catName]:SetPoint("RIGHT", categoryLabel, "LEFT", rightPointDistance, 0)
    else
      editBox[catName]:SetSize(editBoxAddItemWidth - 10, 30)
      editBox[catName]:SetPoint("RIGHT", categoryLabel, "LEFT", rightPointDistance, 0)
    end
    editBox[catName]:Hide() -- we hide every edit box by default when we reload the tab

    -- if the category is opened in this tab, we display all of its items
    if (not utils:HasKey(NysTDL.db.profile.closedCategories, catName) or not utils:HasValue(NysTDL.db.profile.closedCategories[catName], tab:GetName())) then
      -- checkboxes
      local buttonsLength = 0
      for _, itemName in pairs(itemNames) do -- for every item to load
          buttonsLength = buttonsLength + 1

          checkBtn[catName][itemName]:SetParent(tab)
          checkBtn[catName][itemName]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT", 30, - 22 * buttonsLength + 5)
          checkBtn[catName][itemName]:Show()
      end
      categoryLabelFavsRemaining[catName]:Hide() -- the only thing is that we hide it if the category is opened
    else
      -- if not, we still need to put them at their right place, anchors and parents (but we keep them hidden)
      -- especially for when we load the All tab, for the clearing
      for _, itemName in pairs(itemNames) do -- for every item to load but hidden
        checkBtn[catName][itemName]:SetParent(tab)
        checkBtn[catName][itemName]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT")
      end
      categoryLabelFavsRemaining[catName]:Show() -- bc we only see him when the cat is closed
    end
  else
    -- if the current label has no reason to be visible in this tab, we hide it (and for the checkboxes, they have already been hidden before the first call to this func).
    -- so first we hide them to be sure they are gone from our view, and then it's a bit more complicated:
    -- we reset their parent to be the current tab, so that we're sure that they are all on the same tab, and then
    -- ClearAllPoints is pretty magical here since a hidden label CAN be clicked on and still manages to fire OnEnter and everything else, so :Hide() is not enough,
    -- so with this API we clear their points so that they have nowhere to go and they don't fire events anymore.
    label[catName]:Hide()
    label[catName]:SetParent(tab)
    label[catName]:ClearAllPoints()
    categoryLabelFavsRemaining[catName]:Hide()
    categoryLabelFavsRemaining[catName]:SetParent(tab)
    categoryLabelFavsRemaining[catName]:ClearAllPoints()
    editBox[catName]:Hide()
    editBox[catName]:SetParent(tab)
    editBox[catName]:ClearAllPoints()

    -- then, since there isn't anything to show in the current category for the current tab,
    -- we check if it was a closed category, in which case, we remove it from the saved variable
    if (tab:GetName() ~= "All") then -- unless we're in the All tab, since we can decide to hide items, so i want to keep the closed state if we want to show the items back
      if (utils:HasKey(NysTDL.db.profile.closedCategories, catName) and NysTDL.db.profile.closedCategories[catName] ~= nil) then
        local isPresent, pos = utils:HasValue(NysTDL.db.profile.closedCategories[catName], tab:GetName()) -- we get if it is closed in the current tab
        if (isPresent) then -- if it is
          table.remove(NysTDL.db.profile.closedCategories[catName], pos) -- then we remove it from the saved variable
          if (#NysTDL.db.profile.closedCategories[catName] == 0) then -- and btw check if it was the only tab remaining where it was closed
            NysTDL.db.profile.closedCategories[catName] = nil -- in which case we nil the table variable for that category
          end
        end
      end
    end

    -- and btw, we check if there is no more item at all in that category
    -- and if it's empty, we delete all of the corresponding elements, this is the place where we properly delete a category.
    if (not next(NysTDL.db.profile.itemsList[catName])) then
      -- we destroy them
      table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, editBox[catName])))
      editBox[catName] = nil
      label[catName] = nil
      categoryLabelFavsRemaining[catName] = nil

      -- and we nil them in the saved variables
      NysTDL.db.profile.itemsList[catName] = nil
      NysTDL.db.profile.closedCategories[catName] = nil
    end

    return lastData -- if we are here, lastData shall not be changed or there will be consequences! (so we end the function prematurely)
  end

  lastData = {
    ["tab"] = tab,
    ["categoryLabel"] = categoryLabel,
    ["catName"] = catName,
    ["itemNames"] = itemNames,
  }
  return lastData
end

-- generating the list items to load for the tab
local function generateTab(tab)
  -- We sort all of the categories in alphabetical order
  local tempTable = itemsFrame:GetCategoriesOrdered()

  -- doing that only one time
  -- before we reload the entire tab and items, we hide every checkboxes
  for catName, items in pairs(NysTDL.db.profile.itemsList) do -- for every item
    for itemName in pairs(items) do
      checkBtn[catName][itemName]:Hide()
      checkBtn[catName][itemName]:SetParent(tab)
      checkBtn[catName][itemName]:ClearAllPoints()
    end
  end

  -- then we load everything
  local lastData = nil
  shownInTab[tab:GetName()] = 0
  for _, catName in pairs(tempTable) do -- for each categories, alphabetically
    -- we sort alphabetically all the items inside, with the favorites in first
    local itemNames = {}
    local fav = {}
    local others = {}

    -- first we get every favs and other items for the current cat and place them in their respective tables
    for itemName, data in pairs(NysTDL.db.profile.itemsList[catName]) do
      if (ItemIsInTab(data.tabName, tab:GetName())) then
        if (not ItemIsHiddenInResetTab(catName, itemName)) then
          if (data.favorite) then
            table.insert(fav, itemName)
          else
            table.insert(others, itemName)
          end
        end
      end
    end

    -- sorting
    table.sort(fav)
    table.sort(others)
    for _, itemName in pairs(fav) do
      table.insert(itemNames, itemName)
    end
    for _, itemName in pairs(others) do
      table.insert(itemNames, itemName)
    end

    shownInTab[tab:GetName()] = shownInTab[tab:GetName()] + #itemNames

    lastData = loadCategories(tab, label[catName], catName, itemNames, lastData) -- and finally, we load them on the tab in the defined order
  end
end

--/***************/ FRAME CREATION /******************/--

local function loadAddACategory(tab)



  tdlFrame.labelFirstItemName:SetPoint("TOPLEFT", tdlFrame.labelCategoryName, "TOPLEFT", 0, - 25)
  tdlFrame.nameEditBox:SetPoint("RIGHT", tdlFrame.labelFirstItemName, "LEFT", 280, 0)

  tdlFrame.addBtn:SetPoint("TOP", tdlFrame.labelFirstItemName, "TOPLEFT", 140, - 30)
end

local function loadTabActions(tab)
  tdlFrame.tabActionsButton:SetParent(tab)
  tdlFrame.tabActionsButton:SetPoint("RIGHT", tdlFrame.undoButton, "LEFT", 2, 0)

  --/************************************************/--

  tdlFrame.tabActionsTitle:SetParent(tab)
  tdlFrame.tabActionsTitle:SetPoint("TOP", tdlFrame.title, "TOP", 0, - 59)
  tdlFrame.tabActionsTitle:SetText(string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Tab actions"].." ("..L[tab:GetName()]..") \\"))

  --/************************************************/--

  local w = tdlFrame.btnCheck:GetWidth() + tdlFrame.btnUncheck:GetWidth() + 10 -- this is to better center the buttons
  tdlFrame.btnCheck:SetParent(tab)
  tdlFrame.btnCheck:SetPoint("TOPLEFT", tdlFrame.tabActionsTitle, "TOP", -(w/2), - 35)

  tdlFrame.btnUncheck:SetParent(tab)
  tdlFrame.btnUncheck:SetPoint("TOPLEFT", tdlFrame.btnCheck, "TOPRIGHT", 10, 0)

  --/************************************************/--

  tdlFrame.btnClear:SetParent(tab)
  tdlFrame.btnClear:SetPoint("TOP", tdlFrame.btnCheck, "TOPLEFT", (w/2), -45)
end

local function loadOptions(tab)
  tdlFrame.frameOptionsButton:SetParent(tab)
  tdlFrame.frameOptionsButton:SetPoint("RIGHT", tdlFrame.helpButton, "LEFT", 2, 0)

  --/************************************************/--

  tdlFrame.optionsTitle:SetParent(tab)
  tdlFrame.optionsTitle:SetPoint("TOP", tdlFrame.title, "TOP", 0, - 59)

  --/************************************************/--

  tdlFrame.resizeTitle:SetParent(tab)
  tdlFrame.resizeTitle:SetPoint("TOP", tdlFrame.optionsTitle, "TOP", 0, -32)
  local h = tdlFrame.resizeTitle:GetHeight() -- if the locale text is too long, we adapt the points of the next element to match the height of this string

  --/************************************************/--

  tdlFrame.frameAlphaSlider:SetParent(tab)
  tdlFrame.frameAlphaSlider:SetPoint("TOP", tdlFrame.resizeTitle, "TOP", 0, -28 - h) -- here

  tdlFrame.frameAlphaSliderValue:SetParent(tab)
  tdlFrame.frameAlphaSliderValue:SetPoint("TOP", tdlFrame.frameAlphaSlider, "BOTTOM", 0, 0)

  --/************************************************/--

  tdlFrame.frameContentAlphaSlider:SetParent(tab)
  tdlFrame.frameContentAlphaSlider:SetPoint("TOP", tdlFrame.frameAlphaSlider, "TOP", 0, -50)

  tdlFrame.frameContentAlphaSliderValue:SetParent(tab)
  tdlFrame.frameContentAlphaSliderValue:SetPoint("TOP", tdlFrame.frameContentAlphaSlider, "BOTTOM", 0, 0)

  --/************************************************/--

  tdlFrame.affectDesc:SetParent(tab)
  tdlFrame.affectDesc:SetPoint("TOP", tdlFrame.frameContentAlphaSlider, "TOP", 0, -40)

  --/************************************************/--

  tdlFrame.btnAddonOptions:SetParent(tab)
  tdlFrame.btnAddonOptions:SetPoint("TOP", tdlFrame.affectDesc, "TOP", 0, - 55)
end

-- loading the content (top to bottom)
local function loadTab(tab)
  tdlFrame.title:SetParent(tab)
  tdlFrame.title:SetPoint("TOP", tab, "TOPLEFT", centerXOffset, - 10)

  local l = tdlFrame.title:GetWidth()
  tdlFrame.titleLineLeft:SetParent(tab)
  tdlFrame.titleLineRight:SetParent(tab)
  tdlFrame.titleLineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -18)
  tdlFrame.titleLineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 -10, -18)
  tdlFrame.titleLineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 +10, -18)
  tdlFrame.titleLineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -18)

  tdlFrame.remaining:SetParent(tab)
  tdlFrame.remaining:SetPoint("TOPLEFT", tdlFrame.title, "TOP", - 140, - 30)
  tdlFrame.remainingNumber:SetParent(tab)
  tdlFrame.remainingNumber:SetPoint("LEFT", tdlFrame.remaining, "RIGHT", 6, 0)
  tdlFrame.remainingFavsNumber:SetParent(tab)
  tdlFrame.remainingFavsNumber:SetPoint("LEFT", tdlFrame.remainingNumber, "RIGHT", 3, 0)

  tdlFrame.helpButton:SetParent(tab)
  tdlFrame.helpButton:SetPoint("TOPRIGHT", tdlFrame.title, "TOP", 140, - 23)

  tdlFrame.undoButton:SetParent(tab)
  tdlFrame.undoButton:SetPoint("RIGHT", tdlFrame.helpButton, "LEFT", 2, 0)

  -- loading the "add a category" menu
  loadAddACategory(tab)

  -- loading the "tab actions" menu
  loadTabActions(tab)

  -- loading the "frame options" menu
  loadOptions(tab)

  -- loading the bottom line at the correct place (a bit special)
  tdlFrame.lineBottom:SetParent(tab)

  -- and the menu title lines (a bit complicated too)
  tdlFrame.menuTitleLineLeft:SetParent(tab)
  tdlFrame.menuTitleLineRight:SetParent(tab)
  if (addACategoryClosed and tabActionsClosed and optionsClosed) then
    tdlFrame.menuTitleLineLeft:Hide()
    tdlFrame.menuTitleLineRight:Hide()
  else
    if (not addACategoryClosed) then
      l = tdlFrame.categoryTitle:GetWidth()
    elseif (not tabActionsClosed) then
      l = tdlFrame.tabActionsTitle:GetWidth()
    elseif (not optionsClosed) then
      l = tdlFrame.optionsTitle:GetWidth()
    end
    if ((l/2 + 15) <= lineOffset) then
      tdlFrame.menuTitleLineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
      tdlFrame.menuTitleLineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 - 10, -78)
      tdlFrame.menuTitleLineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 + 10, -78)
      tdlFrame.menuTitleLineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78)
      tdlFrame.menuTitleLineLeft:Show()
      tdlFrame.menuTitleLineRight:Show()
    else
      tdlFrame.menuTitleLineLeft:Hide()
      tdlFrame.menuTitleLineRight:Hide()
    end
  end

  -- first we check which one of the buttons is pressed (if there is one) for pre-processing something
  if (addACategoryClosed) then -- if the creation of new categories is closed
    -- we hide every component of the "add a category"
    for _, v in pairs(addACategoryItems) do
      v:Hide()
    end
  end

  if (tabActionsClosed) then -- if the tab actions menu is closed
    -- then we hide every component of the "tab actions"
    for _, v in pairs(tabActionsItems) do
      v:Hide()
    end
  end

  if (optionsClosed) then -- if the options menu is closed
    -- then we hide every component of the "options"
    for _, v in pairs(frameOptionsItems) do
      v:Hide()
    end
  end

  -- then we decide where to place the bottom line
  if (addACategoryClosed) then -- if the creation of new categories is closed
    if (tabActionsClosed) then -- if the options menu is closed
      if (optionsClosed) then -- and if the tab actions menu is closed too
        -- we place the line just below the buttons
        tdlFrame.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
        tdlFrame.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78)
      else
        -- or else we show and adapt the height of every component of the "options"
        local height = 0
        for _, v in pairs(frameOptionsItems) do
          v:Show()
          height = height + (select(5, v:GetPoint()))
        end

        -- and show the line below them
        tdlFrame.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, height - 62)
        tdlFrame.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, height - 62)
      end
    else
      -- or else we show and adapt the height of every component of the "tab actions"
      local height = 0
      for _, v in pairs(tabActionsItems) do
        v:Show()
        height = height + (select(5, v:GetPoint()))
      end

      -- and show the line below them
      tdlFrame.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, height - 62)
      tdlFrame.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, height - 62)
    end
  else
    -- or else we show and adapt the height of every component of the "add a category"
    local height = 0
    for _, v in pairs(addACategoryItems) do
      v:Show()
      height = height + (select(5, v:GetPoint()))
    end

    -- and show the line below the elements of the "add a category"
    tdlFrame.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, height - 62)
    tdlFrame.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, height - 62)
  end

  tdlFrame.dummyLabel:SetParent(tab)
  tdlFrame.dummyLabel:SetPoint("TOPLEFT", tdlFrame.lineBottom, "TOPLEFT", - 35, - 20)

  -- generating all of the content (items, checkboxes, editboxes, category labels...)
  generateTab(tab)

  -- Nothing label
  -- first, we get how many items there are shown in the tab
  local checked, _, unchecked = itemsFrame:updateRemainingNumbers()

  -- then we show/hide the nothing label depending on the result and shownInTab
  tdlFrame.nothingLabel:SetParent(tab)
  tdlFrame.nothingLabel:SetPoint("TOP", tdlFrame.lineBottom, "TOP", 0, - 20) -- to correctly center this text on diffent screen sizes
  tdlFrame.nothingLabel:Hide()
  if (checked[tab:GetName()] + unchecked[tab:GetName()] == 0) then -- if there is nothing to show in the tab we're in
    tdlFrame.nothingLabel:SetText(L["There are no items!"])
    tdlFrame.nothingLabel:Show()
  else -- if there are items in the tab
    if (unchecked[tab:GetName()] == 0) then -- and if they are checked ones
      -- we check if they are hidden or not, and if they are, we show the nothing label with a different text
      if (shownInTab[tab:GetName()] == 0) then
        tdlFrame.nothingLabel:SetText(utils:SafeStringFormat(L["(%i hidden item(s))"], checked[tab:GetName()]))
        tdlFrame.nothingLabel:Show()
      end
    end
  end
end

-- // Content generation

local function generateAddACategory()
  tdlFrame.categoryButton = widgets:IconButton(tdlFrame, "NysTDL_CategoryButton", "Add a category")
  tdlFrame.categoryButton:SetPoint("RIGHT", tdlFrame.frameOptionsButton, "LEFT", 2, 0)
  tdlFrame.categoryButton:SetScript("OnClick", function()
    tabActionsClosed = true
    optionsClosed = true
    addACategoryClosed = not addACategoryClosed

    tutorialsManager:Validate("addNewCat") -- tutorial

    itemsFrame:ReloadTab() -- we reload the frame to display the changes
    if (not addACategoryClosed) then
      SetFocusEditBox(tdlFrame.categoryEditBox)
    end -- then we give the focus to the category edit box if we opened the menu
  end)

  --/************************************************/--

  tdlFrame.categoryTitle = widgets:NoPointsLabel(tdlFrame, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Add a category"].." \\"))
  tdlFrame.categoryTitle:SetPoint("TOP", tdlFrame.title, "TOP", 0, -59)
  table.insert(addACategoryItems, tdlFrame.categoryTitle)

  --/************************************************/--

  tdlFrame.labelCategoryName = widgets:NoPointsLabel(tdlFrame, nil, L["Category:"])
  tdlFrame.labelCategoryName:SetPoint("TOPLEFT", tdlFrame.categoryTitle, "TOP", -140, - 35)
  table.insert(addACategoryItems, tdlFrame.labelCategoryName)

  tdlFrame.categoryEditBox = CreateFrame("EditBox", nil, tdlFrame, "InputBoxTemplate") -- edit box to put the new category name
  tdlFrame.categoryEditBox:SetPoint("RIGHT", tdlFrame.labelCategoryName, "LEFT", 257, 0)
  tdlFrame.categoryEditBox:SetSize(257 - widgets:GetWidth(tdlFrame.labelCategoryName:GetText()) - 20, 30)
  tdlFrame.categoryEditBox:SetAutoFocus(false)
  tdlFrame.categoryEditBox:SetScript("OnKeyDown", function(_, key) if (key == "TAB") then SetFocusEditBox(tdlFrame.nameEditBox) end end) -- to switch easily between the two edit boxes
  tdlFrame.categoryEditBox:SetScript("OnEnterPressed", addCategory) -- if we press enter, it's like we clicked on the add button
  tdlFrame.categoryEditBox:HookScript("OnEditFocusGained", function(self)
    if (NysTDL.db.profile.highlightOnFocus) then
      self:HighlightText()
    else
      self:HighlightText(self:GetCursorPosition(), self:GetCursorPosition())
    end
  end)
  table.insert(addACategoryItems, tdlFrame.categoryEditBox)

  --/************************************************/--

  --  // LibUIDropDownMenu version // --

  --@retail@
  tdlFrame.categoriesDropdown = LDD:Create_UIDropDownMenu("NysTDL_Frame_CategoriesDropdown", nil)

  tdlFrame.categoriesDropdown.HideMenu = function()
  	if L_UIDROPDOWNMENU_OPEN_MENU == tdlFrame.categoriesDropdown then
  		LDD:CloseDropDownMenus()
  	end
  end

  tdlFrame.categoriesDropdown.SetValue = function(self, newValue)
    -- we update the category edit box
    if (tdlFrame.categoryEditBox:GetText() == newValue) then
      tdlFrame.categoryEditBox:SetText("")
      SetFocusEditBox(tdlFrame.categoryEditBox)
    elseif (newValue ~= nil) then
      tdlFrame.categoryEditBox:SetText(newValue)
      SetFocusEditBox(tdlFrame.nameEditBox)
    end
  end

  -- Create and bind the initialization function to the dropdown menu
  LDD:UIDropDownMenu_Initialize(tdlFrame.categoriesDropdown, function(self, level)
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
      local categories = itemsFrame:GetCategoriesOrdered()
      for _, v in pairs(categories) do
        info.arg1 = v
        info.text = v
        info.checked = tdlFrame.categoryEditBox:GetText() == v
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

  tdlFrame.categoriesDropdownButton = CreateFrame("Button", "NysTDL_Button_CategoriesDropdown", tdlFrame.categoryEditBox, "NysTDL_DropdownButton")
  tdlFrame.categoriesDropdownButton:SetPoint("LEFT", tdlFrame.categoryEditBox, "RIGHT", 0, -1)
  tdlFrame.categoriesDropdownButton:SetScript("OnClick", function(self)
    LDD:ToggleDropDownMenu(1, nil, tdlFrame.categoriesDropdown, self:GetName(), 0, 0)
  end)
  tdlFrame.categoriesDropdownButton:SetScript("OnHide", tdlFrame.categoriesDropdown.HideMenu)
  --@end-retail@

  --  // NOLIB version1 - Custom frame style (clean, with wipes): taints click on quests in combat // --
  --[===[@non-retail@
  tdlFrame.categoriesDropdown = CreateFrame("Frame", "NysTDL_Frame_CategoriesDropdown")
  tdlFrame.categoriesDropdown.displayMode = "MENU"
  tdlFrame.categoriesDropdown.info = {}
  tdlFrame.categoriesDropdown.initialize = function(self, level)
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
      local categories = itemsFrame:GetCategoriesOrdered()
      for _, v in pairs(categories) do
        info.text = v
        info.arg1 = v
        info.checked = tdlFrame.categoryEditBox:GetText() == v
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
  -- tdlFrame.categoriesDropdown = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
  -- UIDropDownMenu_Initialize(tdlFrame.categoriesDropdown, function(self)
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
  --   local categories = itemsFrame:GetCategoriesOrdered()
  --   for _, v in pairs(categories) do
  --     info.func = self.SetValue
  --     info.arg1 = v
  --     info.text = info.arg1
  --     info.checked = tdlFrame.categoryEditBox:GetText() == info.arg1
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
  tdlFrame.categoriesDropdown.HideMenu = function()
  	if UIDROPDOWNMENU_OPEN_MENU == tdlFrame.categoriesDropdown then
  		CloseDropDownMenus()
  	end
  end
  tdlFrame.categoriesDropdown.SetValue = function(self, newValue)
    -- we update the category edit box
    if (tdlFrame.categoryEditBox:GetText() == newValue) then
      tdlFrame.categoryEditBox:SetText("")
      SetFocusEditBox(tdlFrame.categoryEditBox)
    elseif (newValue ~= nil) then
      tdlFrame.categoryEditBox:SetText(newValue)
      SetFocusEditBox(tdlFrame.nameEditBox)
    end
  end
  tdlFrame.categoriesDropdownButton = CreateFrame("Button", "NysTDL_Button_CategoriesDropdown", tdlFrame.categoryEditBox, "NysTDL_DropdownButton")
  tdlFrame.categoriesDropdownButton:SetPoint("LEFT", tdlFrame.categoryEditBox, "RIGHT", 0, -1)
  tdlFrame.categoriesDropdownButton:SetScript("OnClick", function(self)
    ToggleDropDownMenu(1, nil, tdlFrame.categoriesDropdown, self:GetName(), 0, 0)
  end)
  tdlFrame.categoriesDropdownButton:SetScript("OnHide", tdlFrame.categoriesDropdown.HideMenu)
  --@end-non-retail@]===]

  --/************************************************/--

  tdlFrame.labelFirstItemName = tdlFrame:CreateFontString(nil) -- info label 3
  tdlFrame.labelFirstItemName:SetFontObject("GameFontHighlightLarge")
  tdlFrame.labelFirstItemName:SetText(L["First item:"])
  table.insert(addACategoryItems, tdlFrame.labelFirstItemName)

  tdlFrame.nameEditBox = CreateFrame("EditBox", nil, tdlFrame, "InputBoxTemplate") -- edit box tp put the name of the first item
  l = widgets:NoPointsLabel(tdlFrame, nil, tdlFrame.labelFirstItemName:GetText())
  tdlFrame.nameEditBox:SetSize(280 - l:GetWidth() - 20, 30)
  tdlFrame.nameEditBox:SetAutoFocus(false)
  tdlFrame.nameEditBox:SetScript("OnKeyDown", function(_, key) if (key == "TAB") then SetFocusEditBox(tdlFrame.categoryEditBox) end end)
  tdlFrame.nameEditBox:SetScript("OnEnterPressed", addCategory) -- if we press enter, it's like we clicked on the add button
  tdlFrame.nameEditBox:HookScript("OnEditFocusGained", function(self)
    if (NysTDL.db.profile.highlightOnFocus) then
      self:HighlightText()
    else
      self:HighlightText(self:GetCursorPosition(), self:GetCursorPosition())
    end
  end)
  table.insert(addACategoryItems, tdlFrame.nameEditBox)
  table.insert(hyperlinkEditBoxes, tdlFrame.nameEditBox)

  tdlFrame.addBtn = widgets:Button("addButton", tdlFrame, L["Add category"])
  tdlFrame.addBtn:SetScript("onClick", addCategory)
  table.insert(addACategoryItems, tdlFrame.addBtn)
end

local function generateTabActions()
  tdlFrame.tabActionsButton = CreateFrame("Button", "categoryButton", tdlFrame, "NysTDL_TabActionsButton")
  tdlFrame.tabActionsButton.tooltip = L["Tab actions"]
  tdlFrame.tabActionsButton:SetScript("OnClick", function()
    addACategoryClosed = true
    optionsClosed = true
    tabActionsClosed = not tabActionsClosed
    itemsFrame:ReloadTab() -- we reload the frame to display the changes
  end)
  tdlFrame.tabActionsButton:Hide()

  --/************************************************/--

  tdlFrame.tabActionsTitle = widgets:NoPointsLabel(tdlFrame, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Tab actions"].." \\"))
  table.insert(tabActionsItems, tdlFrame.tabActionsTitle)

  --/************************************************/--

  tdlFrame.btnCheck = widgets:Button("btnCheck_tdlFrame", tdlFrame, L["Check"], "Interface\\BUTTONS\\UI-CheckBox-Check")
  tdlFrame.btnCheck:SetScript("OnClick", function(self)
    local tabName = self:GetParent():GetName()
    itemsFrame:CheckBtns(tabName)
  end)
  table.insert(tabActionsItems, tdlFrame.btnCheck)

  tdlFrame.btnUncheck = widgets:Button("btnUncheck_tdlFrame", tdlFrame, L["Uncheck"], "Interface\\BUTTONS\\UI-CheckBox-Check-Disabled")
  tdlFrame.btnUncheck:SetScript("OnClick", function(self)
    local tabName = self:GetParent():GetName()
    itemsFrame:ResetBtns(tabName)
  end)
  table.insert(tabActionsItems, tdlFrame.btnUncheck)

  --/************************************************/--

  tdlFrame.btnClear = widgets:Button("clearButton", tdlFrame, L["Clear"], "Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check")
  tdlFrame.btnClear:SetScript("onClick", function(self)
    local tabName = self:GetParent():GetName()
    itemsFrame:ClearTab(tabName)
  end)
  table.insert(tabActionsItems, tdlFrame.btnClear)
end

local function generateOptions()
  tdlFrame.frameOptionsButton = CreateFrame("Button", "frameOptionsButton_tdlFrame", tdlFrame, "NysTDL_FrameOptionsButton")
  tdlFrame.frameOptionsButton.tooltip = L["Frame options"]
  tdlFrame.frameOptionsButton:SetScript("OnClick", function()
    addACategoryClosed = true
    tabActionsClosed = true
    optionsClosed = not optionsClosed

    tutorialsManager:Validate("accessOptions") -- tutorial

    itemsFrame:ReloadTab() -- we reload the frame to display the changes
  end)

  --/************************************************/--

  tdlFrame.optionsTitle = widgets:NoPointsLabel(tdlFrame, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), "/ "..L["Frame options"].." \\"))
  table.insert(frameOptionsItems, tdlFrame.optionsTitle)

  --/************************************************/--

  tdlFrame.resizeTitle = widgets:NoPointsLabel(tdlFrame, nil, string.format("|cffffffff%s|r", L["Hold ALT to see the resize button"]))
  tdlFrame.resizeTitle:SetFontObject("GameFontHighlight")
  tdlFrame.resizeTitle:SetWidth(230)
  table.insert(frameOptionsItems, tdlFrame.resizeTitle)

  --/************************************************/--

  tdlFrame.frameAlphaSlider = CreateFrame("Slider", "frameAlphaSlider", tdlFrame, "OptionsSliderTemplate")
  tdlFrame.frameAlphaSlider:SetWidth(200)
  -- tdlFrame.frameAlphaSlider:SetHeight(17)
  -- tdlFrame.frameAlphaSlider:SetOrientation('HORIZONTAL')

  tdlFrame.frameAlphaSlider:SetMinMaxValues(0, 100)
  tdlFrame.frameAlphaSlider:SetValue(NysTDL.db.profile.frameAlpha)
  tdlFrame.frameAlphaSlider:SetValueStep(1)
  tdlFrame.frameAlphaSlider:SetObeyStepOnDrag(true)

  tdlFrame.frameAlphaSlider.tooltipText = L["Change the background opacity"] --Creates a tooltip on mouseover.
  _G[tdlFrame.frameAlphaSlider:GetName() .. 'Low']:SetText((select(1,tdlFrame.frameAlphaSlider:GetMinMaxValues()))..'%') --Sets the left-side slider text (default is "Low").
  _G[tdlFrame.frameAlphaSlider:GetName() .. 'High']:SetText((select(2,tdlFrame.frameAlphaSlider:GetMinMaxValues()))..'%') --Sets the right-side slider text (default is "High").
  _G[tdlFrame.frameAlphaSlider:GetName() .. 'Text']:SetText(L["Frame opacity"]) --Sets the "title" text (top-centre of slider).
  tdlFrame.frameAlphaSlider:SetScript("OnValueChanged", FrameAlphaSlider_OnValueChanged)
  table.insert(frameOptionsItems, tdlFrame.frameAlphaSlider)

  tdlFrame.frameAlphaSliderValue = tdlFrame.frameAlphaSlider:CreateFontString("frameAlphaSliderValue") -- the font string to see the current value
  tdlFrame.frameAlphaSliderValue:SetFontObject("GameFontNormalSmall")
  tdlFrame.frameAlphaSliderValue:SetText(tdlFrame.frameAlphaSlider:GetValue())
  table.insert(frameOptionsItems, tdlFrame.frameAlphaSliderValue)

  --/************************************************/--

  tdlFrame.frameContentAlphaSlider = CreateFrame("Slider", "frameContentAlphaSlider", tdlFrame, "OptionsSliderTemplate")
  tdlFrame.frameContentAlphaSlider:SetWidth(200)
  -- tdlFrame.frameContentAlphaSlider:SetHeight(17)
  -- tdlFrame.frameContentAlphaSlider:SetOrientation('HORIZONTAL')

  tdlFrame.frameContentAlphaSlider:SetMinMaxValues(60, 100)
  tdlFrame.frameContentAlphaSlider:SetValue(NysTDL.db.profile.frameContentAlpha)
  tdlFrame.frameContentAlphaSlider:SetValueStep(1)
  tdlFrame.frameContentAlphaSlider:SetObeyStepOnDrag(true)

  tdlFrame.frameContentAlphaSlider.tooltipText = L["Change the opacity for texts, buttons and other elements"] --Creates a tooltip on mouseover.
  _G[tdlFrame.frameContentAlphaSlider:GetName() .. 'Low']:SetText((select(1,tdlFrame.frameContentAlphaSlider:GetMinMaxValues()))..'%') --Sets the left-side slider text (default is "Low").
  _G[tdlFrame.frameContentAlphaSlider:GetName() .. 'High']:SetText((select(2,tdlFrame.frameContentAlphaSlider:GetMinMaxValues()))..'%') --Sets the right-side slider text (default is "High").
  _G[tdlFrame.frameContentAlphaSlider:GetName() .. 'Text']:SetText(L["Frame content opacity"]) --Sets the "title" text (top-centre of slider).
  tdlFrame.frameContentAlphaSlider:SetScript("OnValueChanged", FrameContentAlphaSlider_OnValueChanged)
  table.insert(frameOptionsItems, tdlFrame.frameContentAlphaSlider)

  tdlFrame.frameContentAlphaSliderValue = tdlFrame.frameContentAlphaSlider:CreateFontString("frameContentAlphaSliderValue") -- the font string to see the current value
  tdlFrame.frameContentAlphaSliderValue:SetFontObject("GameFontNormalSmall")
  tdlFrame.frameContentAlphaSliderValue:SetText(tdlFrame.frameContentAlphaSlider:GetValue())
  table.insert(frameOptionsItems, tdlFrame.frameContentAlphaSliderValue)

  --/************************************************/--

  tdlFrame.affectDesc = CreateFrame("CheckButton", "NysTDL_affectDesc", tdlFrame, "ChatConfigCheckButtonTemplate")
  tdlFrame.affectDesc.tooltip = L["Share the opacity options of this frame onto the description frames (only when checked)"]
  tdlFrame.affectDesc.Text:SetText(L["Affect description frames"])
  tdlFrame.affectDesc.Text:SetFontObject("GameFontHighlight")
  tdlFrame.affectDesc.Text:ClearAllPoints()
  tdlFrame.affectDesc.Text:SetPoint("TOP", tdlFrame.affectDesc, "BOTTOM")
  tdlFrame.affectDesc:SetHitRectInsets(0, 0, 0, 0)
  tdlFrame.affectDesc:SetScript("OnClick", function(self)
    NysTDL.db.profile.affectDesc = self:GetChecked()
    FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha)
    FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha)
  end)
  tdlFrame.affectDesc:SetChecked(NysTDL.db.profile.affectDesc)
  table.insert(frameOptionsItems, tdlFrame.affectDesc)

  --/************************************************/--

  tdlFrame.btnAddonOptions = widgets:Button("addonOptionsButton", tdlFrame, L["Open addon options"], "Interface\\Buttons\\UI-OptionsButton")
  tdlFrame.btnAddonOptions:SetScript("OnClick", function() if (not optionsManager:ToggleOptions(true)) then tdlFrame:Hide() end end)
  table.insert(frameOptionsItems, tdlFrame.btnAddonOptions)
end

-- generating the content (top to bottom)
local function generateFrameContent()
  -- title
  tdlFrame.title = widgets:NoPointsLabel(tdlFrame, nil, string.gsub(core.toc.title, "Ny's ", ""))
  tdlFrame.title:SetFontObject("GameFontNormalLarge")

  -- remaining label
  tdlFrame.remaining = widgets:NoPointsLabel(tdlFrame, nil, L["Remaining:"])
  tdlFrame.remaining:SetFontObject("GameFontNormalLarge")
  tdlFrame.remainingNumber = widgets:NoPointsLabel(tdlFrame, nil, "...")
  tdlFrame.remainingNumber:SetFontObject("GameFontNormalLarge")
  tdlFrame.remainingFavsNumber = widgets:NoPointsLabel(tdlFrame, nil, "...")
  tdlFrame.remainingFavsNumber:SetFontObject("GameFontNormalLarge")

  -- help button
  tdlFrame.helpButton = widgets:HelpButton(tdlFrame)
  tdlFrame.helpButton:SetScript("OnClick", function()
    SlashCmdList["NysToDoList"](L["info"])
    tutorialsManager:Validate("getMoreInfo") -- tutorial
  end)

  -- undo button
  tdlFrame.undoButton = CreateFrame("Button", "undoButton_tdlFrame", tdlFrame, "NysTDL_UndoButton")
  tdlFrame.undoButton.tooltip = L["Undo last remove/clear"]
  tdlFrame.undoButton:SetScript("OnClick", itemsFrame.UndoRemove)
  tdlFrame.undoButton:Hide()

  -- add a category button
  generateAddACategory()

  -- tab actions button
  generateTabActions()

  -- options button
  generateOptions()

  tdlFrame.titleLineLeft = widgets:NoPointsLine(tdlFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(database.themes.theme_yellow, 0.8))))
  tdlFrame.titleLineRight = widgets:NoPointsLine(tdlFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(database.themes.theme_yellow, 0.8))))
  tdlFrame.menuTitleLineLeft = widgets:NoPointsLine(tdlFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(database.themes.theme, 0.7))))
  tdlFrame.menuTitleLineRight = widgets:NoPointsLine(tdlFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(database.themes.theme, 0.7))))
  tdlFrame.lineBottom = widgets:NoPointsLine(tdlFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(database.themes.theme, 0.7))))

  tdlFrame.nothingLabel = widgets:NothingLabel(tdlFrame)

  tdlFrame.dummyLabel = widgets:Dummy(tdlFrame, tdlFrame.lineBottom, 0, 0)
end

-- // Profile init & change

function itemsFrame:ResetContent()
  -- considering I don't want to reload the UI when we change the current profile,
  -- we have to reset all the frame ourserves, so that means:

  -- 1 - having to hide everything in it (since elements don't dissapear even
  -- when we nil them, that's how wow and lua works)
  for catName, items in pairs(currentDBItemsList) do
    for itemName in pairs(items) do
      checkBtn[catName][itemName]:Hide()
    end
  end

  for k, _ in pairs(currentDBItemsList) do
    label[k]:Hide()
    categoryLabelFavsRemaining[k]:Hide()
    editBox[k]:Hide()
    table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, editBox[k])))
  end

  for _, v in pairs(descFrames) do
    v:Hide()
    table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, v.descriptionEditBox.EditBox)))
  end

  -- 2 - reset every content variable to their default value
  clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true }
  movingItem, movingCategory = false, false

  wipe(checkBtn)
  wipe(removeBtn)
  wipe(favoriteBtn)
  wipe(descBtn)
  wipe(descFrames)
  wipe(label)
  wipe(editBox)
  wipe(categoryLabelFavsRemaining)
  addACategoryClosed = true
  tabActionsClosed = true
  optionsClosed = true
  autoResetedThisSession = false
end

function itemsFrame:Init(profileChanged)
  -- this one is for keeping track of the old itemsList when we reset,
  -- so that we can hide everything when we change profiles
  currentDBItemsList = NysTDL.db.profile.itemsList

  -- we resize and scale the frame to match the saved variable
  tdlFrame:SetSize(NysTDL.db.profile.frameSize.width, NysTDL.db.profile.frameSize.height)
  -- we reposition the frame to match the saved variable
  local points = NysTDL.db.profile.framePos
  tdlFrame:ClearAllPoints()
  tdlFrame:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen
  -- and update its elements opacity to match the saved variable
  FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha)
  FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha)

  -- Generating the core once --
  for catName, items in pairs(NysTDL.db.profile.itemsList) do
    itemsFrame:CreateMovableLabelElems(catName) -- Category labels
    for itemName in pairs(items) do
      itemsFrame:CreateMovableCheckBtnElems(catName, itemName) -- All items transformed as checkboxes
    end
  end

  -- IMPORTANT: this code is to activate hyperlink clicks in edit boxes such as the ones for adding new items in categories,
  -- I disabled this for practical reasons: it's easier to write new item names in them if we can click on the links without triggering the hyperlink (and it's not very useful anyways :D).
  -- -- and after generating every one of the fixed elements, we go throught every edit box marked as hyperlink, and add them the handlers here:
  -- for _, v in pairs(hyperlinkEditBoxes) do
  --   if (not v:GetHyperlinksEnabled()) then -- just to be sure they are new ones (eg: not redo this for the first item name edit box of the add a category menu)
  --     v:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
  --     v:SetScript("OnHyperlinkClick", function(self, linkData, link, button)
  --       ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  --     end)
  --   end
  -- end

  -- then we update everything
  itemsFrame:ReloadTab() -- We load the good tab

  -- and we reload the saved variables needing an update
  tdlFrame.frameAlphaSlider:SetValue(NysTDL.db.profile.frameAlpha)
  tdlFrame.frameContentAlphaSlider:SetValue(NysTDL.db.profile.frameContentAlpha)
  tdlFrame.affectDesc:SetChecked(NysTDL.db.profile.affectDesc)

  -- when we're here, the list already exists, we just switched profiles and we need to update the new visibility
  if (profileChanged) then
    ItemsFrame_OnVisibilityUpdate()
  end
end

-- // Creating the main frame

function itemsFrame:CreateTDLFrame()
  -- local btn = CreateFrame("Frame", nil, UIParent, "LargeUIDropDownMenuTemplate")
  -- btn:SetPoint("CENTER")
  -- UIDropDownMenu_SetWidth(btn, 200)
  -- do return end

  -- as of wow 9.0, we need to import the backdrop template into our frames if we want to use it in them, it is not set by default, so that's what we are doing here
  tdlFrame = CreateFrame("Frame", "ToDoListUIFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

  -- background
  tdlFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 1, edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 }})

  -- properties
  tdlFrame:SetResizable(true)
  tdlFrame:SetMinResize(240, 284)
  tdlFrame:SetMaxResize(600, 1000)
  tdlFrame:SetFrameLevel(200)
  tdlFrame:SetMovable(true)
  tdlFrame:SetClampedToScreen(true)
  tdlFrame:EnableMouse(true)
  -- tdlFrame:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
  -- tdlFrame:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
  --   ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  -- end)

  tdlFrame:HookScript("OnUpdate", ItemsFrame_OnUpdate)
  tdlFrame:HookScript("OnShow", ItemsFrame_OnVisibilityUpdate)
  tdlFrame:HookScript("OnHide", ItemsFrame_OnVisibilityUpdate)
  tdlFrame:HookScript("OnSizeChanged", function(self)
    NysTDL.db.profile.frameSize.width = self:GetWidth()
    NysTDL.db.profile.frameSize.height = self:GetHeight()
    ItemsFrame_Scale()
  end)

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

  -- // CONTENT OF THE FRAME // --

  -- frame variables
  tdlFrame.timeSinceLastUpdate = 0
  tdlFrame.timeSinceLastRefresh = 0

  -- generating the fixed content shared between the 3 tabs
  generateFrameContent()

  -- tutorial
  tutorialsManager:Init()

  -- scroll frame
  tdlFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, tdlFrame, "UIPanelScrollFrameTemplate")
  tdlFrame.ScrollFrame:SetPoint("TOPLEFT", tdlFrame, "TOPLEFT", 4, - 4)
  tdlFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", - 4, 4)
  tdlFrame.ScrollFrame:SetClipsChildren(true)
  tdlFrame.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel)

  -- scroll bar
  tdlFrame.ScrollFrame.ScrollBar:ClearAllPoints()
  tdlFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", tdlFrame.ScrollFrame, "TOPRIGHT", - 12, - 38) -- the bottomright is updated in the OnUpdate (to manage the resize button)

  -- XXX
  tab.content = CreateFrame("Frame", name, tdlFrame.ScrollFrame)
  tab.content:SetSize(308, 1) -- y is determined by number of elements inside of it
  tab.content:Hide()

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
    tdlFrame:SetSize(340, 400)
  end)

  -- // Generating the tabs XXX
  AllTab, DailyTab, WeeklyTab = SetTabs(tdlFrame, 3, L["All"], L["Daily"], L["Weekly"])

  -- Initializing the frame with the current data
  itemsFrame:Init(false)

  -- when we're here, the list was just created, so it is opened by default already,
  -- then we decide what we want to do with that
  if (NysTDL.db.profile.openByDefault) then
    ItemsFrame_OnVisibilityUpdate() -- XXX
  elseif (NysTDL.db.profile.keepOpen) then
    tdlFrame:SetShown(NysTDL.db.profile.lastListVisibility)
  else
    tdlFrame:Hide()
  end
end

-- // creating the button to toggle it (if set in options)

function itemsFrame:CreateTDLButton()
  -- Creating the big button to easily toggle the frame
  tdlButton = widgets:Button("tdlButton", UIParent, string.gsub(core.toc.title, "Ny's ", ""))
  tdlButton:SetFrameLevel(100)
  tdlButton:SetMovable(true)
  tdlButton:EnableMouse(true)
  tdlButton:SetClampedToScreen(true)
  tdlButton:RegisterForDrag("LeftButton")
  tdlButton:SetScript("OnDragStart", function()
    if (not NysTDL.db.profile.lockButton) then
      tdlButton:StartMoving()
    end
  end)
  tdlButton:SetScript("OnDragStop", function() -- we save its position
    tdlButton:StopMovingOrSizing()
    local points, _ = NysTDL.db.profile.tdlButton.points, nil
    points.point, _, points.relativePoint, points.xOffset, points.yOffset = tdlButton:GetPoint()
  end)
  tdlButton:SetScript("OnClick", self.Toggle) -- the function the button calls when pressed
  self:RefreshTDLButton()
end

function itemsFrame:RefreshTDLButton()
  local points = NysTDL.db.profile.tdlButton.points
  tdlButton:ClearAllPoints()
  tdlButton:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen
  tdlButton:SetShown(NysTDL.db.profile.tdlButton.show)
end

--/***************/ INITIALIZATION /******************/--

function itemsFrame:Initialize()
  self:CreateTDLFrame()
  self:CreateTDLButton()
end
