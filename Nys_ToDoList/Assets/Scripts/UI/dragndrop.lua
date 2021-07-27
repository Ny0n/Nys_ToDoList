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

local normalAlpha = 1
local selectedDimAlpha = 0.5
local forbiddenDimAlpha = 0.3

local draggingWidget, oldPos -- dragging widget
local dropTargetWidget, newPos -- drop target widget

local dragUpdate = CreateFrame("Frame", nil, UIParent)
local dropLine

local clickX, clickY -- for a clean drag&grop

-- // WoW APIs

local GetCursorPosition = GetCursorPosition
local pairs, next = pairs, next
local CreateFrame, UIParent = CreateFrame, UIParent

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

  print("CALL leave")
  local btn = draggingWidget.interactiveLabel.Button
  btn:GetScript("OnLeave")(btn)

  -- when we are dragging a category, we dim every place we can't drag it to (for a visual feedback)
  contentWidgets[draggingWidget.catID]:SetAlpha(selectedDimAlpha)
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.item then
      widget:SetAlpha(forbiddenDimAlpha)
    end
  end

  -- and finally, the drop position managment
  dragUpdate:SetScript("OnUpdate", function()
    do return end
    for _,widget in pairs(contentWidgets) do
      if widget.enum == enums.category then
        if widget.interactiveLabel.Button:IsMouseOver() and widget ~= draggingWidget then
          dropTargetWidget = widget
          local oldPos = dataManager:GetPos(draggingWidget.catID)
          local newPos = dataManager:GetPos(dropTargetWidget.catID)
          dataManager:MoveCategory(draggingWidget.catID, oldPos, newPos, nil, nil, database.ctab(), database.ctab())
          dragndrop:StopDragging()
        end
      end
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
  local minDist = {
    dist = nil,
    widget = nil,
    under = nil,
  }

  local widgetScale, cursorX, cursorY
  local function testDist(widget)
    -- we get the distance between the widget's drop point and the cursor, to determine which is the closest to it
    local widgetX, widgetY = widget.itemDropPoint:GetCenter()
    local dropTargetWidgetDist = math.sqrt((cursorX-widgetX)^2+(cursorY-widgetY)^2)
    if dropTargetWidgetDist < minDist.dist then
      minDist.dist = dropTargetWidgetDist
      minDist.widget = widget
    end
  end

  local function isDropPointVisible(dropPoint)
    -- returns true if the dropPoint is visible in the tdlFrame
    -- (not :IsVisible(), i'm talking about wether it's currently visible in the scroll frame, or hidden because of SetClipsChildren)

    local dropPointX, dropPointY = dropPoint:GetCenter()
    local tdlFrameMinY = tdlFrame:GetBottom()
    local tdlFrameMaxY    = tdlFrame:GetTop()
    local tdlFrameMinX   = tdlFrame:GetLeft()
    local tdlFrameMaxX  = tdlFrame:GetRight()

    local margin = 8

    if dropPointX - margin > tdlFrameMinX
    and dropPointX + margin < tdlFrameMaxX
    and dropPointY - margin > tdlFrameMinY
    and dropPointY + margin < tdlFrameMaxY then
      return true
    end
  end

  -- and finally, the drop position managment
  dragUpdate:SetScript("OnUpdate", function()
    if not tdlFrame:IsMouseOver() then return end

    -- cursor current pos (Y)
    widgetScale, cursorX, cursorY = draggingWidget:GetEffectiveScale(), GetCursorPosition() -- TODO redo scale later
    cursorX, cursorY = cursorX/widgetScale, cursorY/widgetScale

    if lastCursorPosY == cursorY then return end -- no need for an update
    lastCursorPosY = cursorY

    -- // let's go!
    print("ONUPDATE")

    minDist.dist = 10000 -- we reset the dist every time we want do calculate the min dist

    for _,widget in pairs(contentWidgets) do
      if widget:IsVisible() and isDropPointVisible(widget.itemDropPoint) then -- we only care about a widget if we can see it
        -- now we determine if we can use the current widget or not
        if widget.enum == enums.item then
          if (draggingWidget.itemData.favorite and widget.itemData.favorite)
          or (not draggingWidget.itemData.favorite and not widget.itemData.favorite)
          or ((not draggingWidget.itemData.favorite and widget.itemData.favorite)
          and (dataManager:GetNextFavPos(next(widget.itemData.catIDs)) == dataManager:GetPos(widget.itemID)+1)) then
            testDist(widget)
          end
        elseif widget.enum == enums.category then -- placing in first pos without other item widgets referencing the pos
          if not widget.catData.closedInTabIDs[database.ctab()] then -- if the cat is not closed
            if draggingWidget.itemData.favorite or (dataManager:GetNextFavPos(widget.catID) == 1) then -- and if we are dragging a non-fav, we also check if it is allowed in first pos
              testDist(widget)
            end
          end
        end
      end
    end

    if not minDist.widget then return end

    -- now that we have the closest widget, we update the positions, so that we are ready for the drop
    dropTargetWidget = minDist.widget

    dropLine:ClearAllPoints()
    dropLine:SetPoint("LEFT", dropTargetWidget.itemDropPoint, "CENTER")
    if dropTargetWidget.enum == enums.item then
      newPos = dataManager:GetPos(dropTargetWidget.itemID) + 1
      -- if we are planning to drop the widget further in its cat
      if next(draggingWidget.itemData.catIDs) == next(dropTargetWidget.itemData.catIDs) then
        if newPos > oldPos then
          newPos = newPos - 1 -- we remove a pos since the oldPos remove will remove a pos to everyone that's after it
        end
      end
    elseif dropTargetWidget.enum == enums.category then
      newPos = 1 -- just under a cat, so first by definition
    end
  end)
end

--/***************/ DROPPING /*****************/--

function stopCategoryDragging()
  print("DRAGSTOP1-CAT")
  if not draggingWidget or not dropTargetWidget then return end

  print("STOP_DRAG_CAT")
end

function stopItemDragging()
  print("DRAGSTOP1-ITEM")
  if not draggingWidget or not dropTargetWidget then return end

  local targetCat = (dropTargetWidget.enum == enums.category) and dropTargetWidget.catID or next(dropTargetWidget.itemData.catIDs)
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

  dragFrame:SetScript("OnDragStart", function() draggingWidget = widget end)
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

    -- drop points
    widget.categoryDropPoint = CreateFrame("Frame", nil, widget)
    widget.categoryDropPoint:SetPoint("CENTER", widget, "CENTER", 0, -11)
    widget.categoryDropPoint:SetSize(1, 1)
    widget.itemDropPoint = CreateFrame("Frame", nil, widget)
    widget.itemDropPoint:SetPoint("CENTER", widget, "CENTER", 38, -11)
    widget.itemDropPoint:SetSize(1, 1)
  elseif widget.enum == enums.item then
    dragFrame:HookScript("OnDragStart", startItemDragging)
    dragFrame:SetScript("OnDragStop", stopItemDragging)

    -- drop point
    widget.itemDropPoint = CreateFrame("Frame", nil, widget)
    widget.itemDropPoint:SetPoint("CENTER", widget, "CENTER", 26, -11)
    widget.itemDropPoint:SetSize(1, 1)
  end

  dragFrame:HookScript("OnDragStop", function()
    print("DRAGSTOP2")
    if not draggingWidget then return end

    -- we hide the dragging widget, ad well as the drop line
    draggingWidget:ClearAllPoints() draggingWidget:Hide()
    dropLine:ClearAllPoints() dropLine:Hide()

    -- we reset the alpha states
    local contentWidgets = mainFrame:GetContentWidgets()
    for _,widget in pairs(contentWidgets) do
      widget:SetAlpha(normalAlpha)
    end

    -- we reset everything
    dragUpdate:SetScript("OnUpdate", nil)
    draggingWidget, oldPos = nil, nil
    dropTargetWidget, newPos = nil, nil

    -- refresh the mainFrame
    mainFrame:Refresh()
  end)
end
