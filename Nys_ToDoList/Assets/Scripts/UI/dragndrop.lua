-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local dragndrop = addonTable.dragndrop
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager

-- // Variables

dragndrop.dragging = false -- ez access

local normalAlpha = 1
local selectedDimAlpha = 0.5
local forbiddenDimAlpha = 0.3

local draggingWidget, oldPos, newPos
local targetDropFrame

local dragUpdate = CreateFrame("Frame", nil, UIParent)
local dropLine
local minDist = 10000

local clickX, clickY -- for a clean drag&grop
local dropFrameNb = 0

local dropFrames = {
  -- [1] = frame or CreateFrame(),
  -- [2] = frame or CreateFrame(),
  -- [3] = frame or CreateFrame(),
  -- ...
}

local categoryDropFrames = {}
local favsDropFrames = {}
local itemsDropFrames = {}

local catTopPos = { 0, 16 }
local catBottomPos = { 0, -11 }
local catItemPos = { 38, -11 }
local itemPos = { 26, -11 }
local itemCatPos = { -10, -11 } -- TODO redo clean

-- // WoW & Lua APIs

local GetCursorPosition = GetCursorPosition
local pairs, next = pairs, next
local tinsert, tremove, unpack, wipe = table.insert, table.remove, unpack, wipe
local CreateFrame, UIParent = CreateFrame, UIParent

--/***************/ MISC /*****************/--

local function testDist(dropFrame, cursorX, cursorY)
  -- we get the distance between the drop frame and the cursor, to determine which one is the closest to it
  local dropFrameX, dropFrameY = dropFrame:GetCenter()
  local targetDropFrameDist = math.sqrt((cursorX-dropFrameX)^2+(cursorY-dropFrameY)^2)
  if targetDropFrameDist < minDist then
    targetDropFrame = dropFrame
    minDist = targetDropFrameDist
  end
end

function dragndrop:UpdateDropFrames()
  -- this is done once, each time we start a drag&drop OR we are dragging&dropping and there is a frame refresh -- TODO NOW
  local tabID, tabData = database.ctab(), select(3, dataManager:Find(database.ctab()))
  local tdlFrame, contentWidgets = mainFrame:GetFrame(), mainFrame:GetContentWidgets()

  wipe(categoryDropFrames)
  wipe(favsDropFrames)
  wipe(itemsDropFrames)

  dropFrameNb = 0
  local newDropFrame, lastWidget

  -- category widgets loop
  for catOrder,catID in ipairs(tabData.orderedCatIDs) do
    local catWidget = contentWidgets[catID]
    lastWidget = catWidget

    newDropFrame = dragndrop:SetAndGetDropFrame(catWidget, unpack(catTopPos))
    dragndrop:SetDropFrameData(newDropFrame, tabID, nil, catOrder)
    tinsert(categoryDropFrames, newDropFrame)

    local catData = contentWidgets[catID].catData
    if not catData.closedInTabIDs[tabID] then
      newDropFrame = dragndrop:SetAndGetDropFrame(catWidget, unpack(catItemPos))
      dragndrop:SetDropFrameData(newDropFrame, tabID, catID, 1)

      tinsert(favsDropFrames, newDropFrame)
      if dataManager:GetNextFavPos(catID) == 1 then
        tinsert(itemsDropFrames, newDropFrame)
      end

      -- item widgets loop
      for itemOrder,itemID in ipairs(catData.orderedContentIDs) do -- TODO for now, only items
        local itemWidget = contentWidgets[itemID]
        lastWidget = itemWidget

        if not itemWidget.itemData.tabIDs[tabID] or not dataManager:IsHidden(itemID, tabID) then -- OPTIMIZE this func
          newDropFrame = dragndrop:SetAndGetDropFrame(itemWidget, unpack(itemPos))
          dragndrop:SetDropFrameData(newDropFrame, tabID, catID, itemOrder+1)

          if itemWidget.itemData.favorite then
            tinsert(favsDropFrames, newDropFrame)
            if dataManager:GetNextFavPos(catID) == itemOrder+1 then -- if it's the last fav in the cat, we can drop a normal item below it
              tinsert(itemsDropFrames, newDropFrame)
            end
          else
            tinsert(itemsDropFrames, newDropFrame)
          end
        end
      end
    end
  end

  if lastWidget then -- for the last cat drop point
    local offset, catID
    if lastWidget.enum == enums.category then
      offset = catBottomPos
      catID = lastWidget.catID
    elseif lastWidget.enum == enums.item then
      offset = itemCatPos
      catID = next(lastWidget.itemData.catIDs)
    end
    print("yup")
    newDropFrame = dragndrop:SetAndGetDropFrame(lastWidget, unpack(offset))
    dragndrop:SetDropFrameData(newDropFrame, tabID, nil, dataManager:GetPos(catID)+1)
    tinsert(categoryDropFrames, newDropFrame)
  end
end

function dragndrop:SetAndGetDropFrame(parent, ofsx, ofsy)
  -- here we get a drop point frame, or create one if it doesn't exist
  dropFrameNb = dropFrameNb + 1
  parent = parent or UIParent
  ofsx = ofsx or 0
  ofsy = ofsy or 0

  local dropFrame
  if dropFrames[dropFrameNb] then
    dropFrame = dropFrames[dropFrameNb]
  else
    dropFrame = CreateFrame("Frame", nil, parent)
    dropFrame:SetSize(1, 1)
    dropFrame.dropData = {}

    tinsert(dropFrames, dropFrame)
  end

  dropFrame:ClearAllPoints()
  dropFrame:SetPoint("CENTER", parent, "CENTER", ofsx, ofsy)
  return dropFrame
end

function dragndrop:SetDropFrameData(frame, tab, cat, pos)
  if not frame or not frame.dropData then return end
  frame.dropData.tab = tab
  frame.dropData.cat = cat
  frame.dropData.pos = pos
end

--/***************/ DRAGGING /*****************/--

function startCategoryDragging()
  print("START_DRAG_CAT")

  local contentWidgets = mainFrame:GetContentWidgets()

  -- first, since we are stealing the widget we are dragging from the frame,
  -- we create a new one to replace it
  contentWidgets[draggingWidget.catID] = nil
  mainFrame:UpdateWidget(draggingWidget.catID, enums.category)
  mainFrame:Refresh()

  -- now that we are dragging a duplicate widget, and the list looks like nothing changed,
  -- we start the real dragging work

  print("CALL leave") -- TODO NOW
  local btn = draggingWidget.interactiveLabel.Button
  btn:GetScript("OnLeave")(btn)

  -- when we are dragging a category, we dim every place we can't drag it to (for a visual feedback)
  contentWidgets[draggingWidget.catID]:SetAlpha(selectedDimAlpha)
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.item then
      widget:SetAlpha(forbiddenDimAlpha)
    end
  end

  -- we create the drop line
  dropLine = CreateFrame("Frame", nil, mainFrame:GetFrame().content, "NysTDL_DropLine")

  -- we only need to get the old pos one time
  oldPos = dataManager:GetPos(draggingWidget.catID)

  -- loop variables
  local tdlFrame = mainFrame:GetFrame()
  local lastCursorPosY

  -- and finally, the drop position managment
  dragUpdate:SetScript("OnUpdate", function()
    if not tdlFrame:IsMouseOver() then return end

    -- cursor current pos (Y)
    local widgetScale, cursorX, cursorY = draggingWidget:GetEffectiveScale(), GetCursorPosition() -- TODO redo scale later
    cursorX, cursorY = cursorX/widgetScale, cursorY/widgetScale

    if lastCursorPosY == cursorY then return end -- no need for an update
    lastCursorPosY = cursorY

    minDist = 10000 -- we reset the dist every time

    -- // let's go!

    for _,dropFrame in pairs(categoryDropFrames) do
      if dropFrame:IsVisible() and mainFrame:IsVisible(dropFrame, 8) then -- we only care about a drop point if we can see it (wocaadpiwcse #1)
        testDist(dropFrame, cursorX, cursorY)
      end
    end

    if not targetDropFrame then return end -- just in case we didn't find anything

    -- now that we have the closest widget, we update the positions, so that we are ready for the drop
    dropLine:ClearAllPoints()
    dropLine:SetPoint("LEFT", targetDropFrame, "CENTER")
    newPos = targetDropFrame.dropData.pos
    -- TODO test if same tab
    if newPos > oldPos then
      newPos = newPos - 1 -- we remove a pos since the oldPos remove will remove a pos to everyone that's after it
    end
  end)
end

function startItemDragging()
  print("START_DRAG_ITEM")

  local contentWidgets = mainFrame:GetContentWidgets()

  -- first, since we are stealing the widget we are dragging from the frame,
  -- we create a new one to replace it
  contentWidgets[draggingWidget.itemID] = nil
  mainFrame:UpdateWidget(draggingWidget.itemID, enums.item)
  mainFrame:Refresh()

  -- now that we are dragging a duplicate widget, and the list looks like nothing changed,
  -- we start the real dragging work

  -- when we are dragging an item, we dim every place we can't drag it to (for a visual feedback)
  contentWidgets[draggingWidget.itemID]:SetAlpha(selectedDimAlpha)
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.category then
      -- widget:SetAlpha(forbiddenDimAlpha)
    elseif widget.enum == enums.item then
      if draggingWidget.itemData.favorite then
        if not widget.itemData.favorite then
          widget:SetAlpha(forbiddenDimAlpha)
        end
      else
        if widget.itemData.favorite then
          widget:SetAlpha(forbiddenDimAlpha)
        end
      end
    end
  end

  -- we create the drop line
  dropLine = CreateFrame("Frame", nil, mainFrame:GetFrame().content, "NysTDL_DropLine")

  -- we only need to get the old pos one time
  oldPos = dataManager:GetPos(draggingWidget.itemID)

  -- loop variables
  local tdlFrame = mainFrame:GetFrame()
  local lastCursorPosY

  local dropFrames
  if draggingWidget.itemData.favorite then
    dropFrames = favsDropFrames
  else
    dropFrames = itemsDropFrames
  end

  -- and finally, the drop position managment
  dragUpdate:SetScript("OnUpdate", function()
    if not tdlFrame:IsMouseOver() then return end

    -- cursor current pos (Y)
    local widgetScale, cursorX, cursorY = draggingWidget:GetEffectiveScale(), GetCursorPosition() -- TODO redo scale later
    cursorX, cursorY = cursorX/widgetScale, cursorY/widgetScale

    if lastCursorPosY == cursorY then return end -- no need for an update
    lastCursorPosY = cursorY

    minDist = 10000 -- we reset the dist every time

    -- // let's go!

    for _,dropFrame in pairs(dropFrames) do
      if dropFrame:IsVisible() and mainFrame:IsVisible(dropFrame, 8) then -- we only care about a drop point if we can see it
        testDist(dropFrame, cursorX, cursorY)
      end
    end

    if not targetDropFrame then return end -- just in case we didn't find anything

    -- now that we have the closest widget, we update the positions, so that we are ready for the drop
    dropLine:ClearAllPoints()
    dropLine:SetPoint("LEFT", targetDropFrame, "CENTER")
    newPos = targetDropFrame.dropData.pos
    if next(draggingWidget.itemData.catIDs) == targetDropFrame.dropData.cat then -- if it's the same cat we're talking about
      if newPos > oldPos then
        newPos = newPos - 1 -- we remove a pos since the oldPos remove will remove a pos to everyone that's after it
      end
    end
  end)
end

--/***************/ DROPPING /*****************/--

function stopCategoryDragging()
  print("DRAGSTOP1-CAT")
  if not draggingWidget then return end

  dataManager:MoveCategory(draggingWidget.catID, oldPos, newPos, nil, nil, database.ctab(), database.ctab())
end

function stopItemDragging()
  print("DRAGSTOP1-ITEM")
  if not draggingWidget then return end

  local targetCat = targetDropFrame.dropData.cat
  dataManager:MoveItem(draggingWidget.itemID, oldPos, newPos, next(draggingWidget.itemData.catIDs), targetCat, database.ctab(), database.ctab())
end

function dragndrop:StopDragging()
  -- TODO replace by reset func, not a stop
  print("DRAGSTOP0")
  if not draggingWidget then return end -- TODO check usefulness of all these checks
  local dragFrame = draggingWidget.interactiveLabel.Button
  dragFrame:GetScript("OnDragStop")(dragFrame)
end

--/***************/ START&STOP /*****************/--

function dragndrop:RegisterForDrag(widget)
  -- drag properties
  widget:EnableMouse(true)
  widget:SetMovable(true)

  -- we detect the dragging on the label of the widget
  local dragFrame = widget.interactiveLabel.Button

  -- this is for snapping the widget on the cursor, where we started to drag it
  dragFrame:HookScript("OnMouseDown", function()
    local scale, x, y = widget:GetEffectiveScale(), GetCursorPosition()
    clickX, clickY = x/scale, y/scale
  end)

  -- drag scripts
  dragFrame:RegisterForDrag("LeftButton")

  dragFrame:SetScript("OnDragStart", function()
    print("DRAG 00")
    draggingWidget = widget
    dragndrop:UpdateDropFrames()
    dragndrop.dragging = true
  end)
  dragFrame:HookScript("OnDragStart", function()
    print("DRAG 1")
    -- we snap the one we are dragging to the current cursor position,
    -- where the widget was first clicked on before the drag, and we start moving it
    -- (it is a dummy widget, perfect duplicate just for a visual feedback, but it doesn't actually do anything)
    local widgetX, widgetY = draggingWidget:GetCenter()
    local ofsx, ofsy = clickX - widgetX, clickY - widgetY

    draggingWidget:SetParent(UIParent)
    draggingWidget:ClearAllPoints()

    local widgetScale, cursorX, cursorY = draggingWidget:GetEffectiveScale() , GetCursorPosition()
    draggingWidget:SetPoint("CENTER", nil, "BOTTOMLEFT", (cursorX/widgetScale)-ofsx, (cursorY/widgetScale)-ofsy)

    draggingWidget:StartMoving()
    draggingWidget:SetUserPlaced(false)
    draggingWidget:SetToplevel(true)
    draggingWidget:Raise()
  end)

  -- specific
  if widget.enum == enums.category then
    dragFrame:HookScript("OnDragStart", startCategoryDragging)
    dragFrame:SetScript("OnDragStop", stopCategoryDragging)
  elseif widget.enum == enums.item then
    dragFrame:HookScript("OnDragStart", startItemDragging)
    dragFrame:SetScript("OnDragStop", stopItemDragging)
  end

  dragFrame:HookScript("OnDragStop", function()
    print("DRAGSTOP2")
    if not dragndrop.dragging then return end
    dragndrop.dragging = false

    -- we reset the alpha states
    local contentWidgets = mainFrame:GetContentWidgets()
    for _,widget in pairs(contentWidgets) do
      widget:SetAlpha(normalAlpha)
    end

    -- // we reset everything

    -- we hide the dragging widget, as well as the drop line
    draggingWidget:ClearAllPoints() draggingWidget:Hide()
    dropLine:ClearAllPoints() dropLine:Hide()

    -- variables
    dragUpdate:SetScript("OnUpdate", nil)
    draggingWidget, oldPos, newPos = nil, nil, nil
    targetDropFrame = nil

    -- // refresh the mainFrame
    mainFrame:Refresh()
  end)
end
