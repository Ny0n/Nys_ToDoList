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
dragndrop.cancelling = false

-- DRY

local normalAlpha = 1
local selectedDimAlpha = 0 -- TODO idk what is nicer here
local forbiddenDimAlpha = 0.3

local catTopPos = { 0, enums.ofsyCat/2 }
local catBottomPos = { 0, -enums.ofsyCat/2 }
local catItemPos = { 38, -enums.ofsyCatContent/2+4 }
local itemPos = { 26, -enums.ofsyContent/2+4 }
local itemCatPos = { -enums.ofsxContent, -enums.ofsyContentCat/2 }

-- drag&drop data

local draggingWidget, oldPos
local targetDropFrame, newPos

local dragUpdate = CreateFrame("Frame", nil, UIParent)
local dropLine
local minDist = 10000

local clickX, clickY -- for a clean drag&grop

local dropFrameNb = 0
local dropFramesBank = { -- IMPORTANT drop frames are basically drop points
  -- [1] = CreateDropFrame() (existing frame or new one),
  -- [2] = CreateDropFrame() (existing frame or new one),
  -- ...
}

local categoryDropFrames = {}
local favsDropFrames = {}
local itemsDropFrames = {}

-- dragUpdateFunc vars

local dropFrames
local lastCursorPosY
local tdlFrame

-- // WoW & Lua APIs

local GetCursorPosition = GetCursorPosition
local pairs, next = pairs, next
local tinsert, tremove, unpack, wipe = table.insert, table.remove, unpack, wipe
local CreateFrame, UIParent = CreateFrame, UIParent

--/***************/ MISC /*****************/--

local function testDist(dropFrame, cursorX, cursorY)
  -- we get the distance between the given drop frame and the cursor,
  -- to determine which one is the closest to it

  local dropFrameX, dropFrameY = dropFrame:GetCenter()
  local targetDropFrameDist = math.sqrt((cursorX-dropFrameX)^2+(cursorY-dropFrameY)^2) -- dist

  if targetDropFrameDist < minDist then -- new minimum?
    targetDropFrame = dropFrame
    minDist = targetDropFrameDist
  end
end

local function createDuplicate(enum, ID)
  -- first in each drag, since we are stealing the widget we are dragging from the frame,
  -- we create a new one to replace it

  local contentWidgets = mainFrame:GetContentWidgets()
  contentWidgets[ID] = nil
  mainFrame:UpdateWidget(ID, enum)
  mainFrame:Refresh() -- IMPORTANT this refresh also acts as the call to UpdateDropFrames!

  -- after this, now that we are dragging a duplicate widget, and the list looks like nothing changed,
  -- we start the real dragging work
end

local function dragUpdateFunc()
  if not tdlFrame:IsMouseOver() then return end

  -- cursor current pos (Y)
  local widgetScale, cursorX, cursorY = draggingWidget:GetEffectiveScale(), GetCursorPosition() -- TODO redo scale later
  cursorX, cursorY = cursorX/widgetScale, cursorY/widgetScale

  if lastCursorPosY == cursorY then return end -- no need for an update if we didn't move the cursor up or down
  lastCursorPosY = cursorY

  -- // let's go!

  minDist = 10000 -- we reset the dist to find the closest drop point each frame
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
end

--/***************/ DROP FRAMES /*****************/--

local function recursiveUpdate(tabID, catWidget, w)
  local catID, catData, newDropFrame = catWidget.catID, catWidget.catData
  local contentWidgets = mainFrame:GetContentWidgets()

  if not catData.closedInTabIDs[tabID] then -- if the cat is not closed
    newDropFrame = dragndrop:CreateDropFrame(catWidget, unpack(catItemPos)) -- /*item/ first item, under the cat
    dragndrop:SetDropFrameData(newDropFrame, tabID, catID, 1)

    tinsert(favsDropFrames, newDropFrame) -- favs can always be placed first
    if dataManager:GetNextFavPos(catID) == 1 then
      tinsert(itemsDropFrames, newDropFrame) -- and normal items only if there are no favs
    end

    -- content widgets loop
    for contentOrder,contentID in ipairs(catData.orderedContentIDs) do -- for everything in a base category
      local contentWidget = contentWidgets[contentID]
      w.lastWidget = contentWidget

      if not dataManager:IsHidden(contentID, tabID) then -- if it's not hidden, we show the corresponding widget
        if contentWidget.enum == enums.category then -- sub-category
          recursiveUpdate(tabID, contentWidget, w)
        elseif contentWidget.enum == enums.item then -- item
          newDropFrame = dragndrop:CreateDropFrame(contentWidget, unpack(itemPos)) -- /*item/ under each item
          dragndrop:SetDropFrameData(newDropFrame, tabID, catID, contentOrder+1)

          if contentWidget.itemData.favorite then
            tinsert(favsDropFrames, newDropFrame) -- we can always place a fav item below a fav item
            if dataManager:GetNextFavPos(catID) == contentOrder+1 then -- if it's the last fav in the cat, we can drop a normal item below it as well
              tinsert(itemsDropFrames, newDropFrame)
            end
          else
            tinsert(itemsDropFrames, newDropFrame) -- we can always place a normal item below a normal item
          end
        end
      end
    end
  end
end

function dragndrop:UpdateDropFrames()
  -- this is done once, each time we start a new drag&drop
  -- OR we are dragging&dropping and there is a frame refresh

  -- getting the data
  local tabID, tabData = database.ctab(), select(3, dataManager:Find(database.ctab()))

  -- resetting the drop frames, before updating them
  wipe(categoryDropFrames)
  wipe(favsDropFrames)
  wipe(itemsDropFrames)

  dropFrameNb = 0
  local contentWidgets = mainFrame:GetContentWidgets()
  local w = {
    lastWidget = nil,
  }

  -- // this is basically the same loop as the one in mainFrame,
  -- but instead of adding drag&drop code in that file,
  -- i prefer to put everything here

  -- i am looping on every widget in order,
  -- while figuring out every drop point, their data (pos), and UI positioning

  for catOrder,catID in ipairs(tabData.orderedCatIDs) do -- for every category
    -- // categories
    local catWidget = contentWidgets[catID]
    w.lastWidget = catWidget

    local newDropFrame = dragndrop:CreateDropFrame(catWidget, unpack(catTopPos)) -- /*cat/ over each cat
    dragndrop:SetDropFrameData(newDropFrame, tabID, nil, catOrder)
    tinsert(categoryDropFrames, newDropFrame)

    -- // content
    recursiveUpdate(tabID, catWidget, w)
  end

  -- this part is specifically for the last category drop point (under the last shown item/cat)
  if w.lastWidget then
    local offset, catID
    if w.lastWidget.enum == enums.category then
      offset = catBottomPos
      catID = w.lastWidget.catID
    elseif w.lastWidget.enum == enums.item then
      offset = itemCatPos
      catID = next(w.lastWidget.itemData.catIDs)
    end

    local newDropFrame = dragndrop:CreateDropFrame(w.lastWidget, unpack(offset)) -- /*cat/ under the last category
    dragndrop:SetDropFrameData(newDropFrame, tabID, nil, dataManager:GetPos(catID)+1)
    tinsert(categoryDropFrames, newDropFrame)
  end

  -- // debug stuff
  -- print("-----------------")
  -- print(#categoryDropFrames)
  -- print(#favsDropFrames)
  -- print(#itemsDropFrames)
  -- print(#dropFramesBank)
  -- for k,v in pairs(dropFramesBank) do
  --   local a, x, b, c, d = v:GetPoint()
  --   if x.enum == enums.category then
  --     x = x.catData.name
  --   elseif x.enum == enums.item then
  --     x = x.itemData.name
  --   end
  --   print(a, x, b, c, d)
  -- end
end

function dragndrop:CreateDropFrame(parent, ofsx, ofsy)
  -- here we get a drop frame (basically a drop point), or create one if it doesn't exist
  dropFrameNb = dropFrameNb + 1

  -- default values (just in case)
  parent = parent or UIParent
  ofsx = ofsx or 0
  ofsy = ofsy or 0

  -- create new or get next one
  local dropFrame
  if dropFramesBank[dropFrameNb] then
    dropFrame = dropFramesBank[dropFrameNb]
  else
    dropFrame = CreateFrame("Frame", nil, parent)
    dropFrame:SetSize(1, 1)
    dropFrame.dropData = {}

    tinsert(dropFramesBank, dropFrame)
  end

  dropFrame:ClearAllPoints()
  dropFrame:SetParent(parent)
  dropFrame:SetPoint("CENTER", parent, "CENTER", ofsx, ofsy)
  return dropFrame
end

function dragndrop:SetDropFrameData(frame, tab, cat, pos)
  -- each drop frame has all the data necessary to understand where it is,
  -- so that i don't have to find out the drop pos again at drop time
  if not frame or not frame.dropData then return end

  frame.dropData.tab = tab
  frame.dropData.cat = cat
  frame.dropData.pos = pos
end

--/***************/ DRAGGING /*****************/--

function initCategoryDrag()
  -- creating the duplicate, and getting the dragging's widget current position
  createDuplicate(enums.category, draggingWidget.catID)
  oldPos = dataManager:GetPos(draggingWidget.catID)

  -- this is to recolor white the cat widget, since dragging it might have turned it blue bc of the mouseover
  print("CALL leave") -- TODO NOW
  local btn = draggingWidget.interactiveLabel.Button
  btn:GetScript("OnLeave")(btn)

  -- when we are dragging a category, we dim every place we can't drag it to (for a visual feedback)
  local contentWidgets = mainFrame:GetContentWidgets()
  contentWidgets[draggingWidget.catID]:SetAlpha(selectedDimAlpha)
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.item then
      widget:SetAlpha(forbiddenDimAlpha)
    end
  end

  -- selecting the right drop frames to check
  dropFrames = categoryDropFrames
end

function initItemDrag()
  -- creating the duplicate, and getting the dragging's widget current position
  createDuplicate(enums.item, draggingWidget.itemID)
  oldPos = dataManager:GetPos(draggingWidget.itemID)

  -- when we are dragging an item, we dim every place we can't drag it to (for a visual feedback)
  local contentWidgets = mainFrame:GetContentWidgets()
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

  -- selecting the right drop frames to check
  if draggingWidget.itemData.favorite then
    dropFrames = favsDropFrames
  else
    dropFrames = itemsDropFrames
  end
end

--/***************/ DROPPING /*****************/--

function dropCategory()
  -- oldPos and newPos are constantly updated while dragging,
  -- now we do the actual moving
  if not dragndrop.dragging or dragndrop.cancelling then return end
  if not targetDropFrame then return end -- just in case we didn't find anything
  if not mainFrame:GetFrame():IsMouseOver() then return end -- we cancel the drop if we were out of the frame

  -- TODO test if same tab
  if newPos > oldPos then
    newPos = newPos - 1 -- we remove a pos since the oldPos remove will remove a pos to everyone that's after it
  end

  mainFrame:DontRefreshNextTime()
  dataManager:MoveCategory(draggingWidget.catID, oldPos, newPos, nil, nil, database.ctab(), database.ctab())
end

function dropItem()
  -- oldPos and newPos are constantly updated while dragging,
  -- now we do the actual moving
  if not dragndrop.dragging or dragndrop.cancelling then return end
  if not targetDropFrame then return end -- just in case we didn't find anything
  if not mainFrame:GetFrame():IsMouseOver() then return end -- we cancel the drop if we were out of the frame

  if next(draggingWidget.itemData.catIDs) == targetDropFrame.dropData.cat then -- if it's the same cat we're talking about
    if newPos > oldPos then
      newPos = newPos - 1 -- we remove a pos since the oldPos remove will remove a pos to everyone that's after it
    end
  end

  local targetCat = targetDropFrame.dropData.cat
  mainFrame:DontRefreshNextTime()
  dataManager:MoveItem(draggingWidget.itemID, oldPos, newPos, next(draggingWidget.itemData.catIDs), targetCat, database.ctab(), database.ctab())
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

  -- // drag scripts

  -- / register
  dragFrame:RegisterForDrag("LeftButton")

  -- / start
  dragFrame:SetScript("OnDragStart", function()
    -- drag init
    dragndrop.dragging = true

    -- vars reset & init
    dropFrames = nil
    lastCursorPosY = nil
    tdlFrame = mainFrame:GetFrame()
    draggingWidget, oldPos = widget, nil
    targetDropFrame, newPos = nil, nil
    dropLine = dropLine or CreateFrame("Frame", nil, tdlFrame.content, "NysTDL_DropLine") -- creating the drop line
    dropLine:Show()
  end)
  dragFrame:HookScript("OnDragStart", function()
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
    dragFrame:HookScript("OnDragStart", initCategoryDrag)
    dragFrame:SetScript("OnDragStop", dropCategory)
  elseif widget.enum == enums.item then
    dragFrame:HookScript("OnDragStart", initItemDrag)
    dragFrame:SetScript("OnDragStop", dropItem)
  end

  dragFrame:HookScript("OnDragStart", function()
    -- and finally, when everything is set up, we start the drop update managment
    dragUpdate:SetScript("OnUpdate", dragUpdateFunc)
  end)

  -- / stop
  dragFrame:HookScript("OnDragStop", function()
    dragndrop.dragging = false

    -- // we reset everything

    -- we reset the alpha states
    local contentWidgets = mainFrame:GetContentWidgets()
    for _,widget in pairs(contentWidgets) do
      widget:SetAlpha(normalAlpha)
    end

    -- we hide the dragging widget, as well as the drop line
    if draggingWidget then draggingWidget:ClearAllPoints() draggingWidget:Hide() end
    if dropLine then dropLine:ClearAllPoints() dropLine:Hide() end

    -- we stop the dragUpdate
    dragUpdate:SetScript("OnUpdate", nil)

    -- // refresh the mainFrame
    mainFrame:Refresh()
  end)
end

function dragndrop:CancelDragging()
  if not dragndrop.dragging then return end

  dragndrop.cancelling = true
  local dragFrame = draggingWidget.interactiveLabel.Button
  dragFrame:GetScript("OnDragStop")(dragFrame)
  dragndrop.cancelling = false
end
