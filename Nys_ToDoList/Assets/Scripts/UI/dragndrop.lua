-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local enums = addonTable.enums
local utils = addonTable.utils
local database = addonTable.database
local dragndrop = addonTable.dragndrop
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager

-- // Variables

local dimAlpha = 0.5
local normalAlpha = 1

local draggingWidget
local targetWidget
local dragUpdate = CreateFrame("Frame", nil, UIParent)

--/***************/ DRAGGING /*****************/--

function startCategoryDragging()
  print("STARTDRAG_CAT")
  local contentWidgets = mainFrame:GetContentWidgets()
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.item then
      widget:SetAlpha(dimAlpha)
    end
  end

  dragUpdate:SetScript("OnUpdate", function()
    for _,widget in pairs(contentWidgets) do
      if widget.enum == enums.category then
        if widget.interactiveLabel.Button:IsMouseOver() and widget ~= draggingWidget then
          targetWidget = widget
          local oldPos = dataManager:GetPos(draggingWidget.catID)
          local newPos = dataManager:GetPos(targetWidget.catID)
          dataManager:MoveCategory(draggingWidget.catID, oldPos, newPos, nil, nil, database.ctab(), database.ctab())
          dragndrop:StopDragging()
        end
      end
    end
  end)
end

function startItemDragging()
  print("STARTDRAG_ITEM")
  local contentWidgets = mainFrame:GetContentWidgets()
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.category then
      widget:SetAlpha(dimAlpha)
    end
  end

  dragUpdate:SetScript("OnUpdate", function()
    for _,widget in pairs(contentWidgets) do
      if widget.enum == enums.item then
        if widget.interactiveLabel.Button:IsMouseOver() and widget ~= draggingWidget then
          targetWidget = widget
          local oldPos = dataManager:GetPos(draggingWidget.itemID)
          local newPos = dataManager:GetPos(targetWidget.itemID)
          dataManager:MoveItem(draggingWidget.itemID, oldPos, newPos, next(draggingWidget.itemData.catIDs), next(targetWidget.itemData.catIDs), database.ctab(), database.ctab())
          dragndrop:StopDragging()
        end
      end
    end
  end)
end

--/***************/ DROPPING /*****************/--

function stopCategoryDragging()
  local contentWidgets = mainFrame:GetContentWidgets()
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.item then
      widget:SetAlpha(normalAlpha)
    end
  end

  dragUpdate:SetScript("OnUpdate", nil)
  targetWidget = nil
end

function stopItemDragging()
  local contentWidgets = mainFrame:GetContentWidgets()
  for _,widget in pairs(contentWidgets) do
    if widget.enum == enums.category then
      widget:SetAlpha(normalAlpha)
    end
  end

  dragUpdate:SetScript("OnUpdate", nil)
  targetWidget = nil
end

function dragndrop:StopDragging()
  stopCategoryDragging()
  stopItemDragging()
end

--/***************/ START&STOP /*****************/--

function dragndrop:RegisterForDrag(widget)
  -- drag
  local dragFrame = widget.interactiveLabel.Button
  dragFrame:RegisterForDrag("LeftButton")
  if widget.enum == enums.category then
    dragFrame:SetScript("OnDragStart", function() draggingWidget = widget startCategoryDragging() end)
    dragFrame:SetScript("OnDragStop", function() draggingWidget = nil stopCategoryDragging() end)
  elseif widget.enum == enums.item then
    dragFrame:SetScript("OnDragStart", function() draggingWidget = widget startItemDragging() end)
    dragFrame:SetScript("OnDragStop", function() draggingWidget = nil stopItemDragging() end)
  end
end
